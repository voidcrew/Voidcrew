/// One note on its way up, and the sprites drawing it.
/datum/fnf_note
	/// When it should be hit, in song milliseconds.
	var/time
	/// 0 to 3: left, down, up, right.
	var/lane
	/// How long it's held, in milliseconds. 0 for a tap.
	var/length = 0
	/// What the chart says happens on it besides singing ("ugh", "weekend-1-firegun"...), or null.
	var/kind
	/// Hit or missed already.
	var/judged = FALSE
	/// Being held down right now.
	var/holding = FALSE
	var/obj/effect/abstract/fnf_hud/head
	var/obj/effect/abstract/fnf_hud/body
	var/obj/effect/abstract/fnf_hud/tail

/datum/fnf_note/Destroy()
	QDEL_NULL(head)
	QDEL_NULL(body)
	QDEL_NULL(tail)
	return ..()

/**
 * One singer in a rhythm battle: their chart, their strums, their score and their input.
 *
 * Presses are judged against the song as the singer heard it. The song, the notes on screen
 * and the singer's press all take a trip over the network, so a press lands a whole round trip
 * after the moment the singer heard. The side takes the singer's ping off every press, plus
 * whatever offset they've set for their speakers.
 */
/datum/fnf_side
	var/datum/fnf_battle/battle
	var/mob/living/singer
	/// The singer's name, kept for the results if they go away.
	var/singer_name
	/// Played by the game rather than a person: an NPC, or someone who logged out mid-song.
	var/is_cpu = FALSE
	/// The challenger's side, on the right.
	var/is_right = FALSE
	/// list(time, lane, hold, kind) for every note, in order.
	var/list/chart
	/// The next note in the chart to put on screen.
	var/next_note = 1
	/// Notes on screen, not yet over with.
	var/list/datum/fnf_note/live = list()
	/// Sound channel this singer's vocals play on.
	var/voice_channel
	/// The vocals go quiet after a miss, until the next hit.
	var/voice_muted = FALSE
	/// Which arm the singer holds the mic in, RIG_L_ARM or RIG_R_ARM.
	var/mic_arm
	/// Which way the singer faces: toward the rival.
	var/facing
	/// A summoned character's own way of moving (see fnf_apply_style), or null.
	var/style
	/// Whether the singer just hangs there between notes, twitching, instead of bopping (see fnf_hang()).
	var/hanging = FALSE
	/// Held items the singer can't let go of while singing, as weakrefs.
	var/list/datum/weakref/locked_items = list()
	/// Things handed to the singer for the song (Pico's gun), taken back after.
	var/list/obj/item/props = list()
	/// The HUD style to put back afterwards, if it was hidden.
	var/old_hud_version
	/// Whether the singer's screen was zoomed in on the stage.
	var/zoomed = FALSE
	/// How far to zoom the singer's screen in once their last note's played, if at all.
	var/zoom_when_done = 0
	/// Until when (world.time) the singer is busy with a pose, and shouldn't bop to the beat.
	var/busy_until = 0

	var/obj/effect/abstract/fnf_hud/strumline
	var/list/obj/effect/abstract/fnf_hud/strums = list()
	var/obj/effect/abstract/fnf_hud/text/score_text
	var/obj/effect/abstract/fnf_hud/text/rating_text

	var/score = 0
	var/combo = 0
	var/max_combo = 0
	var/misses = 0
	/// Notes judged so far, and their accuracy summed (1 for a sick, 0 for a miss).
	var/judged_count = 0
	var/accuracy_total = 0
	var/list/ratings = list("sick" = 0, "good" = 0, "bad" = 0, "shit" = 0)

/datum/fnf_side/New(datum/fnf_battle/battle, mob/living/singer, is_right, list/chart, voice_channel)
	src.battle = battle
	src.singer = singer
	singer_name = singer.name
	src.is_right = is_right
	src.chart = chart
	src.voice_channel = voice_channel
	is_cpu = !singer.client

	strumline = new(get_turf(singer))
	for(var/lane in 0 to 3)
		var/obj/effect/abstract/fnf_hud/strum = new
		strum.icon = battle.get_note_icon()
		strum.icon_state = "strum_[lane]"
		strum.pixel_w = lane_x(lane)
		strum.pixel_z = FNF_STRUM_Y
		strum.layer = ABOVE_ALL_MOB_LAYER + 0.01
		strumline.vis_contents += strum
		strums += strum
	score_text = new
	score_text.pixel_z = FNF_STRUM_Y + 24
	score_text.layer = ABOVE_ALL_MOB_LAYER + 0.05
	strumline.vis_contents += score_text
	rating_text = new
	rating_text.layer = ABOVE_ALL_MOB_LAYER + 0.06
	rating_text.alpha = 0
	strumline.vis_contents += rating_text
	update_score_text()

	facing = is_right ? WEST : EAST
	singer.setDir(facing)
	mic_arm = singer.fnf_mic_arm(facing)
	RegisterSignal(singer, COMSIG_MOB_KEYDOWN, PROC_REF(on_key))
	RegisterSignal(singer, COMSIG_MOB_CLIENT_PRE_MOVE, PROC_REF(on_try_move))
	RegisterSignal(singer, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(singer, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))
	RegisterSignal(singer, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))
	RegisterSignal(singer, COMSIG_MOB_LOGIN, PROC_REF(on_login))
	RegisterSignal(singer, COMSIG_QDELETING, PROC_REF(on_singer_deleted))
	lock_in()

/datum/fnf_side/Destroy()
	release_singer()
	QDEL_LIST(live)
	strumline?.vis_contents.Cut()
	QDEL_LIST(strums)
	QDEL_NULL(score_text)
	QDEL_NULL(rating_text)
	QDEL_NULL(strumline)
	battle = null
	return ..()

/datum/fnf_side/proc/release_singer()
	if(!singer)
		return
	unlock()
	singer.fnf_rest()
	UnregisterSignal(singer, list(
		COMSIG_MOB_KEYDOWN,
		COMSIG_MOB_CLIENT_PRE_MOVE,
		COMSIG_MOVABLE_MOVED,
		COMSIG_MOB_STATCHANGE,
		COMSIG_MOB_LOGOUT,
		COMSIG_MOB_LOGIN,
		COMSIG_QDELETING,
	))
	singer = null

/**
 * While singing, a player is all in: hands busy (nothing picked up, dropped or used), facing their
 * rival whatever they click on, the HUD hidden and the screen zoomed in on the stage.
 */
/datum/fnf_side/proc/lock_in()
	if(is_cpu)
		return
	// Glue their hands shut first: blocking hands drops whatever they're holding.
	for(var/obj/item/held in singer.held_items)
		ADD_TRAIT(held, TRAIT_NODROP, FNF_BATTLE_TRAIT)
		locked_items += WEAKREF(held)
	ADD_TRAIT(singer, TRAIT_HANDS_BLOCKED, FNF_BATTLE_TRAIT)
	RegisterSignal(singer, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(on_turned))
	var/client/viewer = singer.client
	if(!viewer)
		return
	if(singer.hud_used)
		old_hud_version = singer.hud_used.hud_version
		singer.hud_used.show_hud(HUD_STYLE_NOHUD)
	if(!GLOB.fnf_no_zoom[viewer.ckey])
		zoom_screen(FNF_ZOOM)
		zoomed = TRUE

/**
 * Puts a prop for the song (Pico's gun) in the singer's hand nearer the crowd, where it can be
 * seen, moving whatever's there (the mic) to the other hand. The far hand is behind the body.
 */
/datum/fnf_side/proc/give_prop(prop_type)
	if(!singer)
		return
	// Side-on, the left hand is the near one facing west, the right facing east.
	var/near_index = facing == WEST ? 1 : 2
	var/far_index = facing == WEST ? 2 : 1
	var/obj/item/in_near_hand = singer.get_item_for_held_index(near_index)
	if(in_near_hand)
		if(singer.get_item_for_held_index(far_index))
			return
		singer.temporarilyRemoveItemFromInventory(in_near_hand, force = TRUE)
		singer.put_in_hand(in_near_hand, far_index, forced = TRUE)
	var/obj/item/prop = new prop_type(singer.drop_location())
	if(!singer.put_in_hand(prop, near_index, forced = TRUE))
		qdel(prop)
		return
	ADD_TRAIT(prop, TRAIT_NODROP, FNF_BATTLE_TRAIT)
	props += prop
	mic_arm = singer.fnf_mic_arm(facing)

/// Gives back everything lock_in() took. Safe to call more than once.
/datum/fnf_side/proc/unlock()
	QDEL_LIST(props)
	if(!singer)
		return
	REMOVE_TRAIT(singer, TRAIT_HANDS_BLOCKED, FNF_BATTLE_TRAIT)
	for(var/datum/weakref/item_ref as anything in locked_items)
		var/obj/item/held = item_ref.resolve()
		if(held)
			REMOVE_TRAIT(held, TRAIT_NODROP, FNF_BATTLE_TRAIT)
	locked_items.Cut()
	UnregisterSignal(singer, COMSIG_ATOM_POST_DIR_CHANGE)
	if(zoomed)
		zoom_screen(1)
		zoomed = FALSE
	if(old_hud_version)
		singer.hud_used?.show_hud(old_hud_version)
		old_hud_version = null

/**
 * Zooms the singer's screen in by scaling what's already drawn, like a camera, rather than
 * changing how much they can see: the view size is left alone, so lighting, fullscreen effects and
 * the rest of the screen's layout don't change underneath. The camera is already centred on the
 * stage, so this zooms straight into the battle.
 */
/datum/fnf_side/proc/zoom_screen(scale)
	var/atom/movable/plane_master_controller/screen = singer?.hud_used?.plane_master_controllers[PLANE_MASTERS_NON_MASTER]
	if(!screen)
		return
	for(var/atom/movable/screen/plane_master/plate as anything in screen.get_planes())
		// Whole-number zoom, pixels scaled as blocks: anything else smears them.
		if(scale == 1)
			plate.appearance_flags = (plate.appearance_flags & ~PIXEL_SCALE) | (initial(plate.appearance_flags) & PIXEL_SCALE)
		else
			plate.appearance_flags |= PIXEL_SCALE
		animate(plate, transform = matrix() * scale, time = 10, easing = SINE_EASING)

/datum/fnf_side/proc/on_turned(mob/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(new_dir != facing && battle.state != FNF_STATE_OVER)
		source.setDir(facing)

/// Where a lane sits across the strumline, in pixels from the middle of the singer's tile.
/proc/fnf_lane_x(lane)
	return round((lane - 1.5) * FNF_LANE_GAP)

/datum/fnf_side/proc/lane_x(lane)
	return fnf_lane_x(lane)

/// Whether this side's notes hit themselves: the CPU's, or a player's with botplay on.
/datum/fnf_side/proc/is_bot()
	return is_cpu || (singer?.ckey && GLOB.fnf_botplay[singer.ckey])

/// How late this singer's presses arrive after they heard the note, in milliseconds.
/datum/fnf_side/proc/get_latency()
	var/client/user = singer?.client
	if(!user || is_bot())
		return 0
	return clamp(user.avgping, 0, 400) + (GLOB.fnf_offsets[user.ckey] || 0)

/// Which lane a key plays, from the player's own movement keys: left, down, up or right.
/proc/fnf_key_lane(client/user, key)
	switch(user?.movement_keys[key])
		if(WEST)
			return 0
		if(SOUTH)
			return 1
		if(NORTH)
			return 2
		if(EAST)
			return 3
	return null

/datum/fnf_side/proc/is_lane_held(lane)
	var/client/user = singer?.client
	if(!user)
		return TRUE
	for(var/key in user.keys_held)
		if(fnf_key_lane(user, key) == lane)
			return TRUE
	return FALSE

/// Called every tick with where the song is.
/datum/fnf_side/proc/process_notes(now)
	var/pixels_per_ms = FNF_TRAVEL_PX / battle.travel_ms
	while(next_note <= length(chart))
		var/list/entry = chart[next_note]
		if(entry[1] - now > battle.travel_ms)
			break
		next_note++
		spawn_note(entry, now, pixels_per_ms)

	var/heard = now - get_latency()
	var/bot = is_bot()
	for(var/datum/fnf_note/note as anything in live.Copy())
		if(!note.judged)
			if(bot)
				if(now >= note.time)
					hit(note, 0, now)
			else if(heard - note.time > FNF_WINDOW_SHIT)
				miss(note)
			continue
		if(!note.holding)
			continue
		var/hold_end = note.time + note.length
		if((bot ? now : heard) >= hold_end)
			finish_hold(note)
		else if(!bot && !is_lane_held(note.lane) && hold_end - heard > FNF_HOLD_GRACE)
			drop_hold(note)
		else
			score += round(250 * world.tick_lag / 10)
			if(!is_cpu)
				battle.adjust_health(0.1, src)
	if(zoom_when_done && next_note > length(chart) && !length(live))
		zoom_screen(zoom_when_done)
		zoom_when_done = 0

/datum/fnf_side/proc/spawn_note(list/entry, now, pixels_per_ms)
	var/datum/fnf_note/note = new
	note.time = entry[1]
	note.lane = entry[2]
	note.length = entry[3]
	if(length(entry) >= 4)
		note.kind = entry[4]
	live += note
	// Notes rise from below at a steady speed and cross the strums right on their time.
	var/until = max(note.time - now, 0)
	var/start_y = FNF_STRUM_Y - until * pixels_per_ms
	var/overshoot = 250 * pixels_per_ms

	var/note_icon = battle.get_note_icon()
	note.head = new
	note.head.icon = note_icon
	note.head.icon_state = "note_[note.lane]"
	note.head.pixel_w = lane_x(note.lane)
	note.head.pixel_z = start_y
	note.head.layer = ABOVE_ALL_MOB_LAYER + 0.03
	strumline.vis_contents += note.head
	animate(note.head, pixel_z = FNF_STRUM_Y, time = until / 100)
	animate(pixel_z = FNF_STRUM_Y + overshoot, alpha = 0, time = 2.5)

	if(note.length <= 0)
		return
	// A long note trails a stretched body below its head, capped with a rounded tail.
	var/length_px = note.length * pixels_per_ms
	note.body = new
	note.body.icon = note_icon
	note.body.icon_state = "hold_[note.lane]"
	note.body.pixel_w = lane_x(note.lane)
	note.body.pixel_z = start_y - length_px / 2
	note.body.transform = matrix(1, 0, 0, 0, length_px / 32, 0)
	note.body.layer = ABOVE_ALL_MOB_LAYER + 0.02
	note.tail = new
	note.tail.icon = note_icon
	note.tail.icon_state = "holdend_[note.lane]"
	note.tail.pixel_w = lane_x(note.lane)
	note.tail.pixel_z = start_y - length_px
	note.tail.layer = ABOVE_ALL_MOB_LAYER + 0.02
	strumline.vis_contents += note.body
	strumline.vis_contents += note.tail
	var/pass_time = (note.length + 250) / 100
	animate(note.body, pixel_z = FNF_STRUM_Y - length_px / 2, time = until / 100)
	animate(pixel_z = FNF_STRUM_Y - length_px / 2 + length_px + overshoot, alpha = 0, time = pass_time)
	animate(note.tail, pixel_z = FNF_STRUM_Y - length_px, time = until / 100)
	animate(pixel_z = FNF_STRUM_Y + overshoot, alpha = 0, time = pass_time)

/datum/fnf_side/proc/on_key(mob/source, key, client/user, full_key)
	SIGNAL_HANDLER
	if(is_bot() || battle.state == FNF_STATE_OVER || battle.state == FNF_STATE_READY)
		return
	var/lane = fnf_key_lane(user, key)
	if(isnull(lane))
		return
	press(lane, battle.get_song_time() - get_latency())

/// A press on a lane, at a song time already corrected for the singer's lag.
/datum/fnf_side/proc/press(lane, time)
	var/datum/fnf_note/best
	var/best_delta = INFINITY
	for(var/datum/fnf_note/note as anything in live)
		if(note.lane != lane || note.judged)
			continue
		var/delta = abs(note.time - time)
		if(delta <= FNF_WINDOW_SHIT && delta < best_delta)
			best = note
			best_delta = delta
	if(!best)
		// Pressing with nothing there is free. The strum just flinches.
		light_strum(lane, "press", 1.5)
		return
	hit(best, time - best.time, battle.get_song_time())

/datum/fnf_side/proc/hit(datum/fnf_note/note, delta, now)
	note.judged = TRUE
	var/off_by = abs(delta)
	var/rating
	var/weight
	var/points
	var/health
	if(off_by <= FNF_WINDOW_SICK)
		rating = "sick"
		weight = 1
		points = 350
		health = 2.3
	else if(off_by <= FNF_WINDOW_GOOD)
		rating = "good"
		weight = 0.75
		points = 200
		health = 2
	else if(off_by <= FNF_WINDOW_BAD)
		rating = "bad"
		weight = 0.4
		points = 100
		health = 0.5
	else
		rating = "shit"
		weight = 0.1
		points = 50
		health = -0.5
	ratings[rating]++
	judged_count++
	accuracy_total += weight
	score += points
	combo++
	max_combo = max(max_combo, combo)
	if(voice_muted)
		set_voice(TRUE)
	// The CPU doesn't push the health bar, or it would win just by existing.
	if(!is_cpu)
		battle.adjust_health(health, src)
		show_rating(rating)
	// Corruption+'s songs drain the player as the opponent sings, and some pay the player back.
	if(src == battle.left)
		battle.corruption?.opponent_hit(note.length)
	else
		battle.corruption?.player_hit(note.length)

	QDEL_NULL(note.head)
	var/hold_left = note.length > 0 ? max(note.time + note.length - now, 0) : 0
	light_strum(note.lane, "confirm", hold_left ? hold_left / 100 + 1 : 1.5)
	if(rating == "sick")
		splash(note.lane)
	var/hold_time = max(hold_left / 100, 2)
	busy_until = world.time + hold_time + 1.5
	// Some notes are a move rather than a line ("ugh!", a punch, a gunshot): the stage acts those out.
	if(!battle.stage?.note_hit(src, note))
		singer?.fnf_sing(note.lane, hold_time, mic_arm, facing, style)
		// Kapi's pad lights up where he steps.
		battle.stage?.step_on_pad(singer, note.lane)
	if(!hold_left)
		live -= note
		qdel(note)
		update_score_text()
		return
	// Held: the body now shrinks into the strum for as long as it lasts.
	note.holding = TRUE
	var/pixels_per_ms = FNF_TRAVEL_PX / battle.travel_ms
	var/left_px = max(hold_left * pixels_per_ms, 0.5)
	animate(note.body, pixel_z = FNF_STRUM_Y - left_px / 2, transform = matrix(1, 0, 0, 0, left_px / 32, 0), alpha = 255, time = 0)
	animate(pixel_z = FNF_STRUM_Y, transform = matrix(1, 0, 0, 0, 0.01, 0), time = hold_left / 100)
	animate(note.tail, pixel_z = FNF_STRUM_Y - left_px, alpha = 255, time = 0)
	animate(pixel_z = FNF_STRUM_Y - 8, time = hold_left / 100)
	update_score_text()

/datum/fnf_side/proc/finish_hold(datum/fnf_note/note)
	light_strum(note.lane, "strum", 0)
	live -= note
	qdel(note)
	update_score_text()

/// Let go of a long note too early.
/datum/fnf_side/proc/drop_hold(datum/fnf_note/note)
	note.holding = FALSE
	live -= note
	combo = 0
	set_voice(FALSE)
	light_strum(note.lane, "strum", 0)
	battle.adjust_health(-2, src)
	show_rating("miss")
	fade_out(note)
	update_score_text()

/datum/fnf_side/proc/miss(datum/fnf_note/note)
	note.judged = TRUE
	live -= note
	misses++
	judged_count++
	combo = 0
	score -= 10
	set_voice(FALSE)
	// What the killing blow was decides how they die: a missed shot in 2hot blows up in their face.
	battle.last_miss_kind = note.kind
	battle.adjust_health(-4, src)
	show_rating("miss")
	fade_out(note)
	if(singer)
		SEND_SOUND(singer, sound("voidcrew/modules/fnf/sound/miss[rand(1, 3)].ogg", volume = 45))
		busy_until = world.time + 3
		if(!battle.stage?.note_missed(src, note))
			singer.fnf_miss(mic_arm, facing, style)
	if(src == battle.right)
		battle.corruption?.player_missed()
	update_score_text()

/// Lets a note that's no longer in play keep drifting up, greyed out, and then go.
/datum/fnf_side/proc/fade_out(datum/fnf_note/note)
	for(var/obj/effect/abstract/fnf_hud/sprite as anything in list(note.head, note.body, note.tail))
		if(sprite)
			animate(sprite, alpha = 70, time = 1, flags = ANIMATION_PARALLEL)
	QDEL_IN(note, 5)

/datum/fnf_side/proc/light_strum(lane, state, duration)
	var/obj/effect/abstract/fnf_hud/strum = strums[lane + 1]
	strum.icon_state = "[state]_[lane]"
	if(duration)
		addtimer(CALLBACK(src, PROC_REF(light_strum), lane, "strum", 0), duration, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_DELETE_ME)

/datum/fnf_side/proc/splash(lane)
	var/obj/effect/abstract/fnf_hud/splash = new
	splash.icon = battle.get_note_icon()
	splash.icon_state = "splash_[lane]"
	splash.pixel_w = lane_x(lane)
	splash.pixel_z = FNF_STRUM_Y
	splash.layer = ABOVE_ALL_MOB_LAYER + 0.04
	strumline.vis_contents += splash
	QDEL_IN(splash, 2)

/datum/fnf_side/proc/show_rating(rating)
	var/static/list/colours = list("sick" = "#7dfcff", "good" = "#8cff5a", "bad" = "#ffd24a", "shit" = "#c9864f", "miss" = "#ff4f4f")
	var/static/list/words = list("sick" = "SICK!!", "good" = "Good!", "bad" = "Bad", "shit" = "Shit", "miss" = "Miss")
	var/combo_text = combo >= 10 ? "<br><span style='font-size:6pt'>[combo]</span>" : ""
	rating_text.maptext = MAPTEXT("<span style='text-align:center;color:[colours[rating]];-dm-text-outline:1px #000000'><b>[words[rating]]</b>[combo_text]</span>")
	rating_text.pixel_z = FNF_STRUM_Y - 30
	animate(rating_text, alpha = 255, pixel_z = FNF_STRUM_Y - 30, time = 0)
	animate(pixel_z = FNF_STRUM_Y - 24, time = 2, easing = CUBIC_EASING|EASE_OUT)
	animate(alpha = 0, time = 3, delay = 2)

/// On every beat: bop along, unless busy singing.
/datum/fnf_side/proc/bop(beat_time)
	if(world.time < busy_until)
		return
	if(hanging)
		singer?.fnf_hang(beat_time, mic_arm, facing, style)
	else
		singer?.fnf_bop(beat_time, mic_arm, facing, style)

/datum/fnf_side/proc/hey()
	busy_until = world.time + 8
	singer?.fnf_hey(mic_arm, facing, style)

/datum/fnf_side/proc/scream()
	busy_until = world.time + 8
	singer?.fnf_scream(mic_arm, facing, style)

/// Acts out a one-off move (see fnf_pose()), and keeps the beat from interrupting it.
/datum/fnf_side/proc/act(kind, hold = 3)
	busy_until = world.time + hold + 2
	singer?.fnf_act(kind, mic_arm, facing, style, hold)

/datum/fnf_side/proc/get_accuracy()
	return judged_count ? accuracy_total / judged_count * 100 : 100

/datum/fnf_side/proc/update_score_text()
	var/cpu = is_cpu ? " (CPU)" : (is_bot() ? " (BOT)" : "")
	score_text.maptext = MAPTEXT("<span style='text-align:center;-dm-text-outline:1px #000000'>[singer_name][cpu]<br>[score] · [misses] miss · [round(get_accuracy(), 0.1)]%</span>")

/// A letter grade from accuracy, and how clean the run was.
/datum/fnf_side/proc/get_grade()
	var/accuracy = get_accuracy()
	var/letter = "F"
	if(!misses && accuracy >= 99.9)
		letter = "S+"
	else if(accuracy >= 95)
		letter = "S"
	else if(accuracy >= 90)
		letter = "A"
	else if(accuracy >= 80)
		letter = "B"
	else if(accuracy >= 70)
		letter = "C"
	else if(accuracy >= 60)
		letter = "D"
	var/clear
	if(!misses)
		if(!ratings["good"] && !ratings["bad"] && !ratings["shit"])
			clear = "Sick Full Combo"
		else if(!ratings["bad"] && !ratings["shit"])
			clear = "Good Full Combo"
		else
			clear = "Full Combo"
	else if(misses < 10)
		clear = "Single Digit Combo Breaks"
	else
		clear = "Clear"
	return "[letter], [clear]"

/datum/fnf_side/proc/get_results()
	return "[singer_name]: [score] points, [round(get_accuracy(), 0.01)]% ([get_grade()]). \
		[ratings["sick"]] sick, [ratings["good"]] good, [ratings["bad"]] bad, [ratings["shit"]] shit, [misses] missed, best combo [max_combo]."

/// The singer's vocals drop out on a miss and come back on the next hit.
/datum/fnf_side/proc/set_voice(on)
	// One recording for both: cutting it out on a miss would silence the other singer too.
	if(!on && battle.song.shared_voices)
		return
	voice_muted = !on
	battle.set_channel_volume(voice_channel, on ? 1 : 0)

/datum/fnf_side/proc/on_try_move(mob/source, list/move_args)
	SIGNAL_HANDLER
	if(battle.state == FNF_STATE_OVER)
		return NONE
	return COMSIG_MOB_CLIENT_BLOCK_PRE_MOVE

/datum/fnf_side/proc/on_moved(mob/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	if(get_turf(source) == strumline.loc)
		return
	battle.forfeit(src, "was knocked off the stage")

/datum/fnf_side/proc/on_stat_change(mob/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat >= UNCONSCIOUS)
		battle.forfeit(src, new_stat == DEAD ? "died mid-song" : "passed out mid-song")

/datum/fnf_side/proc/on_logout(mob/source)
	SIGNAL_HANDLER
	is_cpu = TRUE
	update_score_text()

/datum/fnf_side/proc/on_login(mob/source)
	SIGNAL_HANDLER
	if(battle.npc == singer)
		return
	is_cpu = FALSE
	update_score_text()

/datum/fnf_side/proc/on_singer_deleted(mob/source)
	SIGNAL_HANDLER
	battle.healthbar?.drop_portrait(singer)
	release_singer()
	battle.forfeit(src, "vanished")
