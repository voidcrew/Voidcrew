/**
 * A rhythm battle: two singers facing each other, the challenger on the right, the
 * opponent (a person, a mob nobody's playing, or an Experiment summoned for it) on the left.
 *
 * Keeping the song and the notes together:
 * - The song is sent to everyone listening paused, the moment it's picked, and again when a
 *   challenge goes out, so their game has it downloaded and ready while people decide.
 * - A countdown, four beats long and never under two seconds, gives the download more time.
 *   The song then starts for everyone at once by unpausing it, rather than being sent at start.
 * - Notes aren't timers fired off in advance. Every tick, each side works out where the song is
 *   from the start time, puts on screen whatever is due, and animates it to land on its exact
 *   time. Presses are judged against that same clock, corrected for the singer's ping.
 */
/datum/fnf_battle
	var/datum/fnf_song/song
	var/difficulty
	var/state = FNF_STATE_READY
	/// The microphone that started it.
	var/obj/item/fnf_microphone/microphone
	var/datum/fnf_side/left
	var/datum/fnf_side/right
	var/list/datum/fnf_side/sides = list()
	/// The chart: list("player", "opponent", "events", "speed").
	var/list/chart
	/// world.time (in deciseconds, fractional) when the song is at 0.
	var/start_time = 0
	/// The real time of day the music started (see get_song_time()), or null before it has.
	var/real_start
	/// And where the song was then, by world.time, in milliseconds.
	var/game_start_ms = 0
	/// How far world.time has fallen behind the music since, in milliseconds: when the server
	/// lags, world.time slows down, while everyone's music plays on in real time.
	var/lag_ms = 0
	/// How long a note takes to rise to its strum, in milliseconds.
	var/travel_ms = 1100
	/// Milliseconds per beat.
	var/crochet = 600
	/// When the last note is over, in song milliseconds.
	var/end_ms = 0
	var/health = FNF_HEALTH_MAX / 2
	var/inst_channel
	var/left_voice_channel
	var/right_voice_channel
	/// Everyone hearing the song, mob => volume multiplier. Onlookers get it quieter.
	var/list/mob/listeners = list()
	var/list/channel_volumes = list()
	var/obj/effect/abstract/fnf_hud/healthbar/healthbar
	var/tick_timer
	var/next_event = 1
	var/last_beat = -1
	/// An Experiment summoned to sing against a lone challenger. Goes away afterwards.
	var/mob/living/carbon/human/npc
	/// Where the singers' cameras look, in world pixels: between them, a little above.
	var/camera_x = 0
	var/camera_y = 0
	/// Which singer the camera leans toward, as the chart says: -1 left, 1 right, 0 neither.
	var/camera_focus = 0
	/// Weakrefs to the singers whose cameras were moved, to put them back.
	var/list/datum/weakref/panned = list()
	/// Extra time before the count in, in deciseconds, for a stage that's still fading in.
	var/lead_in = 0
	/// Everything going on around the singers: the girlfriend, lyrics, props, the song's events.
	var/datum/fnf_stage/stage
	/// A Corruption+ song's cast, playing out (see corruption.dm).
	var/datum/fnf_corruption/corruption
	/// The kind of the last note missed, if it had one: what finished someone off.
	var/last_miss_kind

/datum/fnf_battle/New(datum/fnf_song/song, difficulty, obj/item/fnf_microphone/microphone)
	src.song = song
	src.difficulty = difficulty
	src.microphone = microphone
	chart = song.load_chart(difficulty)
	travel_ms = round(1800 / clamp(chart["speed"], 0.6, 4))
	crochet = 60000 / max(song.bpm, 30)
	for(var/list/note as anything in chart["player"] + chart["opponent"])
		end_ms = max(end_ms, note[1] + note[3])
	end_ms += 1500
	// A song that plays on past its last note (Growl's flashback) runs to the end of its music.
	if(song.length_ms)
		end_ms = max(end_ms, song.length_ms)
	// Without its length, a scripted song at least plays out to a little after its last cue.
	for(var/list/cue as anything in (song.character_changes || list()) + (song.overlay_events || list()))
		end_ms = max(end_ms, cue[1] + 3000)
	inst_channel = SSsounds.reserve_sound_channel(src)
	left_voice_channel = SSsounds.reserve_sound_channel(src)
	right_voice_channel = SSsounds.reserve_sound_channel(src)
	channel_volumes = list("[inst_channel]" = 1, "[left_voice_channel]" = 1, "[right_voice_channel]" = 1)

/datum/fnf_battle/Destroy()
	deltimer(tick_timer)
	reset_cameras()
	for(var/mob/listener as anything in listeners)
		for(var/list/track as anything in get_tracks())
			SEND_SOUND(listener, sound(null, channel = track[2]))
		UnregisterSignal(listener, COMSIG_QDELETING)
	listeners.Cut()
	QDEL_NULL(left)
	QDEL_NULL(right)
	sides.Cut()
	QDEL_NULL(healthbar)
	QDEL_NULL(corruption)
	QDEL_NULL(stage)
	if(npc && !QDELETED(npc))
		do_sparks(3, FALSE, npc)
		npc.visible_message(span_notice("[npc] bows, and is gone."))
		qdel(npc)
	npc = null
	SSsounds.free_datum_channels(src)
	if(microphone?.battle == src)
		microphone.battle = null
	microphone = null
	return ..()

/// The arrows this song's notes are drawn with: its own skin (Corruption+'s tainted ones), or ours.
/datum/fnf_battle/proc/get_note_icon()
	switch(song.note_skin)
		if("kapi")
			return 'voidcrew/modules/fnf/icons/fnf_notes_kapi.dmi'
		if("skarlet")
			return 'voidcrew/modules/fnf/icons/fnf_notes_skarlet.dmi'
	return 'voidcrew/modules/fnf/icons/fnf.dmi'

/// The song position right now, in milliseconds. Negative during the countdown.
/datum/fnf_battle/proc/get_song_time()
	return (FNF_NOW - start_time) * 100 + lag_ms

/**
 * Catches the song's clock up with the music after the server's lagged. The real clock only counts
 * tenths of a second, so it isn't the clock itself: world.time is, and this is how far behind the
 * real one it's fallen, smoothed out (and jumped to when it's a long way out).
 */
/datum/fnf_battle/proc/catch_up_with_music()
	if(isnull(real_start))
		return
	var/real_ms = (REALTIMEOFDAY - real_start) * 100 + game_start_ms
	var/behind = max(real_ms - (world.time - start_time) * 100, 0)
	if(abs(behind - lag_ms) > 150)
		lag_ms = behind
	else
		lag_ms += (behind - lag_ms) * 0.05

/// list(file, channel) for everything that plays: the backing track and both singers' vocals.
/datum/fnf_battle/proc/get_tracks()
	. = list(list(song.inst_file, inst_channel))
	if(song.player_voice_file)
		. += list(list(song.player_voice_file, right_voice_channel))
	if(song.opponent_voice_file)
		. += list(list(song.opponent_voice_file, left_voice_channel))

/datum/fnf_battle/proc/get_volume(mob/listener, channel)
	var/pref = listener.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_jukebox)
	if(isnull(pref))
		pref = 100
	return 85 * pref / 100 * (listeners[listener] || 1) * (channel_volumes["[channel]"] || 0)

/// Sends someone the song, paused, so it's downloaded by the time it starts.
/datum/fnf_battle/proc/preload(mob/listener, volume = 1)
	if(!listener?.client)
		return
	if(!listeners[listener])
		RegisterSignal(listener, COMSIG_QDELETING, PROC_REF(on_listener_deleted))
	listeners[listener] = volume
	for(var/list/track as anything in get_tracks())
		var/sound/music = sound(file(track[1]), repeat = FALSE, wait = FALSE, channel = track[2], volume = get_volume(listener, track[2]))
		music.status = SOUND_PAUSED
		SEND_SOUND(listener, music)

/datum/fnf_battle/proc/on_listener_deleted(mob/source)
	SIGNAL_HANDLER
	listeners -= source

/// Starts the paused song for everyone at once.
/datum/fnf_battle/proc/unpause_song()
	for(var/mob/listener as anything in listeners)
		for(var/list/track as anything in get_tracks())
			var/sound/update = sound(null, repeat = FALSE, wait = FALSE, channel = track[2], volume = get_volume(listener, track[2]))
			update.status = SOUND_UPDATE
			SEND_SOUND(listener, update)

/datum/fnf_battle/proc/set_channel_volume(channel, multiplier)
	if(channel_volumes["[channel]"] == multiplier)
		return
	channel_volumes["[channel]"] = multiplier
	if(state != FNF_STATE_PLAYING && state != FNF_STATE_OVER)
		return
	for(var/mob/listener as anything in listeners)
		var/sound/update = sound(null, repeat = FALSE, wait = FALSE, channel = channel, volume = get_volume(listener, channel))
		update.status = SOUND_UPDATE
		SEND_SOUND(listener, update)

/// Everyone nearby gets the song too, a little quieter.
/datum/fnf_battle/proc/preload_onlookers(atom/center)
	for(var/mob/onlooker in hearers(7, center))
		if(onlooker.client && !listeners[onlooker])
			preload(onlooker, 0.6)

/**
 * Sets the stage and counts in.
 *
 * * challenger - sings the player's part, on the right
 * * opponent - sings the other part, on the left. Nobody means an Experiment is summoned.
 */
/datum/fnf_battle/proc/start(mob/living/challenger, mob/living/opponent)
	var/turf/right_turf = get_turf(challenger)
	var/turf/left_turf = find_opponent_spot(right_turf, opponent)
	if(!opponent)
		opponent = summon_opponent(left_turf || right_turf)
	else if(left_turf && get_turf(opponent) != left_turf)
		opponent.forceMove(left_turf)
	left_turf = get_turf(opponent)

	right = new(src, challenger, TRUE, chart["player"], right_voice_channel)
	left = new(src, opponent, FALSE, chart["opponent"], left_voice_channel)
	if(opponent == npc)
		left.style = song.opponent_character
		left.is_cpu = TRUE
		// By name, even with Tankman's face covered.
		left.singer_name = opponent.real_name
		left.update_score_text()
	// Singing as someone other than Boyfriend (Pico, in a Pico mix): moving like them, and holding
	// what they hold. Nobody brings a gun to a fistfight, though.
	if(song.player_character && song.player_character != "bf")
		right.style = song.player_character
		// Corrupted, Pico hunches over his gun, held out one-handed.
		if(song.corruption && song.player_character == "pico")
			right.style = "cpico"
		if(GLOB.fnf_opponents[song.player_character]?["gun"] && !is_fight())
			right.give_prop(/obj/item/toy/fnf_gun)
	sides = list(left, right)
	// Up close in a fight, the two sets of arrows would sit on top of each other. Like Funkin', only
	// the player's show.
	if(is_fight())
		// Everything on the strumline ignores its alpha, so hide the lot outright.
		left.strumline.invisibility = INVISIBILITY_ABSTRACT

	// The bar hangs between the two, above their strums.
	var/center_x = 16 + (left_turf.x - right_turf.x) * world.icon_size / 2
	var/center_y = 16 + (left_turf.y - right_turf.y) * world.icon_size / 2 + FNF_STRUM_Y + 44
	healthbar = new(right_turf, center_x, center_y, opponent, challenger)
	camera_x = (left_turf.x + right_turf.x) * world.icon_size / 2 + 16
	camera_y = (left_turf.y + right_turf.y) * world.icon_size / 2 + 16 + 36
	pan_cameras()

	preload(challenger)
	preload(opponent)
	preload_onlookers(right_turf)
	// After the listeners are in: the stage plays its intro to them.
	stage = new(src, left_turf, right_turf)
	if(song.corruption)
		corruption = new(src)

	state = FNF_STATE_COUNTDOWN
	challenger.visible_message(span_boldnotice("[challenger] and [opponent] square up for a rhythm battle: [song.name]!"))
	INVOKE_ASYNC(src, PROC_REF(await_downloads))

/**
 * Makes sure both singers' games have the song before counting in. The files go over with
 * browse_rsc, then a ping goes after them: when it comes back, everything sent before it has
 * arrived. Without this a big song can still be downloading when it's meant to start, and starts
 * late against the notes. Gives up waiting on someone after about fifteen seconds.
 */
/datum/fnf_battle/proc/await_downloads()
	var/list/tracks = get_tracks()
	var/waiting = FALSE
	for(var/datum/fnf_side/side as anything in sides)
		var/client/viewer = side.singer?.client
		if(!viewer)
			continue
		if(!waiting)
			healthbar?.announce("Loading...")
			waiting = TRUE
		for(var/i in 1 to length(tracks))
			var/list/track = tracks[i]
			viewer << browse_rsc(file(track[1]), "fnf_[song.id]_[i].ogg")
		viewer.browse_queue_flush(300)
		if(QDELETED(src) || state != FNF_STATE_COUNTDOWN)
			return
	begin_countdown()

/datum/fnf_battle/proc/begin_countdown()
	var/countdown_ds = max(4 * crochet, 2000) / 100
	// Line the start up with a tick, so the song starts on exactly the tick it's meant to.
	start_time = world.time + CEILING(10 + lead_in + countdown_ds, world.tick_lag)
	var/static/list/counts = list("3", "2", "1", "GO!")
	for(var/i in 1 to 4)
		addtimer(CALLBACK(src, PROC_REF(count_in), i, counts[i]), start_time - world.time - (5 - i) * crochet / 100, TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(begin_song)), start_time - world.time, TIMER_DELETE_ME)
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), world.tick_lag, TIMER_LOOP|TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Swings both singers' cameras onto the stage, leaning toward whoever the chart is focused on.
/datum/fnf_battle/proc/pan_cameras(time = 10)
	for(var/datum/fnf_side/side as anything in sides)
		var/mob/living/singer = side.singer
		var/client/viewer = singer?.client
		if(!viewer)
			continue
		var/turf/singer_turf = get_turf(singer)
		var/look_x = camera_x + camera_focus * 24 - (singer_turf.x * world.icon_size + 16)
		var/look_y = camera_y - (singer_turf.y * world.icon_size + 16)
		animate(viewer, pixel_w = look_x, pixel_z = look_y, time = time, easing = SINE_EASING)
		panned |= WEAKREF(singer)

/datum/fnf_battle/proc/reset_cameras()
	for(var/datum/weakref/singer_ref as anything in panned)
		var/mob/living/singer = singer_ref.resolve()
		if(singer?.client)
			animate(singer.client, pixel_w = 0, pixel_z = 0, time = 10, easing = SINE_EASING)
	panned.Cut()

/// Three tiles to the challenger's left is the opponent's spot, or as close as there's room.
/// Whether this song is a fistfight rather than a sing-off (Blazin'), and they need to be close.
/datum/fnf_battle/proc/is_fight()
	return song.id == "blazin"

/datum/fnf_battle/proc/find_opponent_spot(turf/right_turf, mob/living/opponent)
	// Four tiles apart, so both singers' arrows and scores have room. Nose to nose for a fight.
	for(var/distance in (is_fight() ? list(1, 2) : list(4, 3, 5)))
		var/turf/spot = locate(right_turf.x - distance, right_turf.y, right_turf.z)
		if(!spot)
			continue
		if(opponent && get_turf(opponent) == spot)
			return spot
		if(!spot.is_blocked_turf(exclude_mobs = FALSE))
			return spot
	return null

/datum/fnf_battle/proc/summon_opponent(turf/spot)
	npc = fnf_summon_opponent(song.opponent_character, spot, song.player_character == "pico" ? /datum/species/experiment/milkie : /datum/species/experiment)
	npc.setDir(EAST)
	do_sparks(3, FALSE, npc)
	npc.visible_message(span_notice("[npc] steps out of nowhere, ready to sing."))
	return npc

/datum/fnf_battle/proc/count_in(number, text)
	if(state == FNF_STATE_OVER)
		return
	healthbar?.announce(text, number == 4 ? "#ffe066" : "#ffffff")
	var/sound_file = number == 4 ? "voidcrew/modules/fnf/sound/countgo.ogg" : "voidcrew/modules/fnf/sound/count[4 - number].ogg"
	for(var/mob/listener as anything in listeners)
		SEND_SOUND(listener, sound(sound_file, volume = 50 * (listeners[listener] || 1)))
	for(var/datum/fnf_side/side as anything in sides)
		side.bop(crochet / 100)

/datum/fnf_battle/proc/begin_song()
	if(state != FNF_STATE_COUNTDOWN)
		return
	state = FNF_STATE_PLAYING
	real_start = REALTIMEOFDAY
	game_start_ms = (world.time - start_time) * 100
	unpause_song()

/datum/fnf_battle/proc/tick()
	if(state == FNF_STATE_OVER)
		return
	catch_up_with_music()
	var/now = get_song_time()
	for(var/datum/fnf_side/side as anything in sides)
		side.process_notes(now)
		if(state == FNF_STATE_OVER)
			return
	var/beat = floor(now / crochet)
	if(beat > last_beat && beat >= 0)
		last_beat = beat
		healthbar?.bop()
		for(var/datum/fnf_side/side as anything in sides)
			side.bop(crochet / 100)
		stage?.bop(crochet / 100)
	stage?.tick(now)
	corruption?.tick(now)
	var/list/events = chart["events"]
	while(next_event <= length(events))
		var/list/event = events[next_event]
		if(event["t"] > now)
			break
		next_event++
		run_event(event)
	if(state == FNF_STATE_PLAYING && now >= end_ms)
		finish()

/// Chart events: the camera turning to whoever's singing, and anyone on stage doing something.
/datum/fnf_battle/proc/run_event(list/event)
	if(event["e"] == "FocusCamera")
		// 0 is the player, 1 the opponent, 2 the girlfriend in the middle.
		var/focus = event["v"]
		if(islist(focus))
			var/list/focus_data = focus
			focus = focus_data["char"]
		camera_focus = focus == 0 ? 1 : (focus == 1 ? -1 : 0)
		pan_cameras(6)
		return
	if(event["e"] != "PlayAnimation")
		return
	var/list/value = event["v"]
	if(islist(value))
		stage?.play_animation(value["target"], value["anim"])

/// Pushes the health toward whoever did well (or away from whoever did badly).
/datum/fnf_battle/proc/adjust_health(amount, datum/fnf_side/side)
	if(state == FNF_STATE_OVER)
		return
	// Between two people nobody's run off the bar: it's settled at the end, by the bar and then the score.
	var/edge = is_pvp() ? 1 : 0
	health = clamp(health + (side == right ? amount : -amount), edge, FNF_HEALTH_MAX - edge)
	healthbar?.update(health)
	if(health <= 0)
		finish(left, right)
	else if(health >= FNF_HEALTH_MAX && !left.is_cpu)
		// Against a person, running them off the bar wins outright. The CPU can't be beaten early.
		finish(right, left)

/// Whether it's two people singing, not someone against the CPU.
/datum/fnf_battle/proc/is_pvp()
	return !left.is_cpu && !right.is_cpu

/datum/fnf_battle/proc/forfeit(datum/fnf_side/quitter, reason)
	if(state == FNF_STATE_OVER)
		return
	var/datum/fnf_side/other = quitter == left ? right : left
	for(var/mob/listener as anything in listeners)
		to_chat(listener, span_warning("[quitter.singer_name] [reason], and forfeits!"))
	finish(other, null)

/**
 * Ends the battle.
 *
 * * winner - who won, or null to go by the health bar and then the score
 * * knocked_out - whoever was run off the health bar, who takes it badly
 */
/datum/fnf_battle/proc/finish(datum/fnf_side/winner, datum/fnf_side/knocked_out)
	if(state == FNF_STATE_OVER)
		return
	state = FNF_STATE_OVER
	deltimer(tick_timer)
	tick_timer = null
	if(!winner)
		if(health != FNF_HEALTH_MAX / 2)
			winner = health > FNF_HEALTH_MAX / 2 ? right : left
		else if(left.score != right.score)
			winner = left.score > right.score ? left : right
	var/datum/fnf_side/loser = winner ? (winner == left ? right : left) : null

	var/list/lines = list("<b>[song.name]</b> ([difficulty])")
	lines += winner ? "<b>[winner.singer_name] wins!</b>" : "<b>It's a draw!</b>"
	lines += right.get_results()
	lines += left.get_results()
	var/message = boxed_message(jointext(lines, "<br>"))
	for(var/mob/listener as anything in listeners)
		to_chat(listener, message)
	healthbar?.announce(winner ? "[winner.singer_name] wins!" : "Draw!", "#ffe066")

	winner?.hey()
	reset_cameras()
	// The game over goes up before anyone lets go of anything, so the loser's mic stays in their hand.
	if(loser?.singer && !QDELETED(loser.singer))
		if(loser == knocked_out && loser.singer.client)
			new /datum/fnf_game_over(loser.singer, song, difficulty, loser == right && left.singer == npc, loser.facing, last_miss_kind, null, get_song_time())
		loser.singer.fnf_lose(loser == knocked_out)
	for(var/datum/fnf_side/side as anything in sides)
		side.unlock()

	// Fade the song out rather than cutting it dead.
	for(var/step in 1 to 4)
		addtimer(CALLBACK(src, PROC_REF(fade_step), 1 - step / 4), step * 5, TIMER_DELETE_ME)
	QDEL_IN(src, 3 SECONDS)

/datum/fnf_battle/proc/fade_step(multiplier)
	for(var/list/track as anything in get_tracks())
		var/channel = track[2]
		if(channel_volumes["[channel]"])
			set_channel_volume(channel, multiplier)
