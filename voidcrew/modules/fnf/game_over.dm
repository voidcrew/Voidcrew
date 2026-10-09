/**
 * Getting run off the health bar, Funkin' style, seen only by whoever lost.
 *
 * Everything goes black. An Experiment is left standing alone, drawn like a health doll,
 * cowering, and gets shot in the head: its head outline goes red, its head whips back, its arms
 * fling up, its knees buckle and it goes over backwards, bouncing and spraying blood, then lies
 * twitching in the spreading pool (all baked into fnf_dead.dmi, after Boyfriend's death).
 *
 * Anyone else dies like Pico does, to his game over music, acted out by their own body with the
 * rest of the world blacked out: a knife in the neck and a fountain of blood (RETRY written in the
 * blood); or, missing a shot in 2hot, the spray can blowing up in their face, leaving them charred,
 * dazed and coughing up smoke (RETRY in pink smoke); or in Blazin' a punch to the gut that folds
 * them up and drops them in their own blood (RETRY splattered under them).
 *
 * Any of them can be watched from the battle microphone's settings, without losing a song first.
 *
 * Then it waits, the game over music looping, for the singer to pick: RETRY (against the game
 * only) or GIVE UP. Until then they're down on the floor, can't touch anything, and their mic
 * stays in their hand.
 *
 * An Experiment that retries makes its last stand, as in Casualties Unknown: "Let's not give up
 * just yet." flickers over everything to a drone while the world slowly fades back in, and the
 * song counts in again as the drone ends. The new battle is set up while it's still dark, so the
 * singer is already back in their stance when the world comes back.
 *
 * The screens go through the mob's fullscreen overlays, so a HUD rebuild puts them back rather
 * than wiping them, and they land on the right plane whatever z-level the singer is on.
 */
/// Burnt black-blue, after a can goes off in your face.
#define FNF_CHARRED "#2a3470"
/// Where a prop sits to be at the neck and at the face: offsets for a 32 by 32 sprite's middle, on
/// a body a quarter bigger than a human.
#define FNF_NECK_Y 11.5
#define FNF_FACE_Y 15

/datum/fnf_game_over
	var/mob/living/singer
	var/datum/fnf_song/song
	var/difficulty
	/// Whether RETRY? starts the song again (only against the game).
	var/can_retry = FALSE
	/// Which way the fallen singer faces.
	var/facing = WEST
	/// The fullscreen categories this put up, to take down again.
	var/list/categories = list()
	var/atom/movable/screen/fullscreen/fnf/blackout
	/// The Experiment, standing, dying and then twitching.
	var/atom/movable/screen/fullscreen/fnf/figure
	var/atom/movable/screen/fullscreen/fnf/button/retry_button
	var/atom/movable/screen/fullscreen/fnf/button/give_up_button
	var/atom/movable/screen/fullscreen/fnf/laststand
	/// Held items glued to the singer's hands, as weakrefs.
	var/list/datum/weakref/stuck_items = list()
	var/music_channel
	var/retrying = FALSE
	/// How they die: "shot" (an Experiment), "knife", "explode" or "gutpunch".
	var/death = "knife"
	/// Knives, cans, blood and smoke acted out around the body, on the figure.
	var/list/obj/effect/abstract/fnf_prop/props = list()
	/// The singer's own vis_flags, while they're drawn over the blackout.
	var/old_vis_flags
	/// Whether they're still on show over the blackout.
	var/showing_body = FALSE
	/// The knife in their neck, to go down with them.
	var/obj/effect/abstract/fnf_prop/knife
	/// Where the neck is, between the bottom of the head and the top of the torso: where the knife
	/// goes in and the blood comes out. In pixels from the middle of the body, as props are placed.
	var/neck_x = 0
	var/neck_y = 0
	/// The song's own game over (Corruption+'s): list("death", "loop", "end" = file), or null for Funkin's.
	var/list/own_sounds

/**
 * * kill_kind - the kind of the note whose miss ended it, if it had one
 * * forced_death - how to die, for a preview: "shot", "knife", "explode" or "gutpunch"
 * * died_at - where in the song it ended, in milliseconds, for a song whose game over changes partway
 */
/datum/fnf_game_over/New(mob/living/singer, datum/fnf_song/song, difficulty, can_retry, facing, kill_kind, forced_death, died_at = 0)
	src.singer = singer
	src.song = song
	own_sounds = song?.get_game_over_sounds(died_at)
	src.difficulty = difficulty
	src.can_retry = can_retry
	src.facing = facing
	var/client/viewer = singer.client
	RegisterSignals(singer, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT), PROC_REF(on_singer_gone))
	music_channel = SSsounds.reserve_sound_channel(src)
	animate(viewer, pixel_w = 0, pixel_z = 0, time = 3)
	// Down, and out of it: no touching the world, and the mic doesn't fall out of their hand when
	// they hit the floor.
	for(var/obj/item/held in singer.held_items)
		ADD_TRAIT(held, TRAIT_NODROP, FNF_GAME_OVER_TRAIT)
		stuck_items += WEAKREF(held)
	var/expie = is_species(singer, /datum/species/experiment)
	death = forced_death || (expie ? "shot" : (kill_kind == "weekend-1-firegun" ? "explode" : (song?.id == "blazin" ? "gutpunch" : "knife")))
	expie = death == "shot"
	// An Experiment is drawn separately, dying on the floor. Anyone else stays up to act it out.
	singer.add_traits(expie ? list(TRAIT_FLOORED, TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_UI_BLOCKED) : list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_UI_BLOCKED), FNF_GAME_OVER_TRAIT)

	blackout = add_screen("fnf_blackout", /atom/movable/screen/fullscreen/fnf)
	blackout.alpha = 0
	animate(blackout, alpha = 255, time = 6)

	if(!expie)
		show_body()
		switch(death)
			if("explode")
				SEND_SOUND(singer, sound("voidcrew/modules/fnf/sound/loss_pico_explode.ogg", volume = 60))
				addtimer(CALLBACK(src, PROC_REF(throw_can)), 4, TIMER_DELETE_ME)
				// Left standing, dazed, coughing up smoke: no falling over for this one.
				addtimer(CALLBACK(src, PROC_REF(daze)), 12, TIMER_DELETE_ME)
				addtimer(CALLBACK(src, PROC_REF(show_buttons)), 22, TIMER_DELETE_ME)
			if("gutpunch")
				SEND_SOUND(singer, sound("voidcrew/modules/fnf/sound/loss_pico_gutpunch.ogg", volume = 60))
				// A moment late: the battle puts everyone back at rest as it ends.
				addtimer(CALLBACK(src, PROC_REF(gut_punch)), 1, TIMER_DELETE_ME)
				addtimer(CALLBACK(src, PROC_REF(fall)), 8, TIMER_DELETE_ME)
				addtimer(CALLBACK(src, PROC_REF(show_buttons)), 14, TIMER_DELETE_ME)
			else
				SEND_SOUND(singer, sound(own_sounds?["death"] || "voidcrew/modules/fnf/sound/loss_pico.ogg", volume = 60))
				addtimer(CALLBACK(src, PROC_REF(throw_knife)), 3, TIMER_DELETE_ME)
				addtimer(CALLBACK(src, PROC_REF(fall)), 13, TIMER_DELETE_ME)
				addtimer(CALLBACK(src, PROC_REF(show_buttons)), 20, TIMER_DELETE_ME)
		return

	SEND_SOUND(singer, sound(own_sounds?["death"] || "voidcrew/modules/fnf/sound/loss.ogg", volume = 60))
	if(expie)
		// 160 by 96, standing on the middle of its bottom edge, drawn twice size with its feet
		// kept on the singer's tile.
		figure = add_screen("fnf_figure", /atom/movable/screen/fullscreen/fnf/figure)
		figure.dir = facing
		figure.alpha = 0
		animate(figure, alpha = 255, time = 6)
		addtimer(CALLBACK(src, PROC_REF(cock_gun)), 10, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(shoot)), 18, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(show_buttons)), 32, TIMER_DELETE_ME)

/datum/fnf_game_over/Destroy()
	if(singer)
		UnregisterSignal(singer, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT, COMSIG_LIVING_POST_UPDATE_TRANSFORM))
		release_singer()
		for(var/category in categories)
			singer.clear_fullscreen(category, FALSE)
		SEND_SOUND(singer, sound(null, channel = music_channel))
	categories.Cut()
	QDEL_LIST(props)
	knife = null
	blackout = null
	figure = null
	retry_button = null
	give_up_button = null
	laststand = null
	SSsounds.free_datum_channels(src)
	singer = null
	return ..()

/// Lets the singer up and gives them their hands back.
/datum/fnf_game_over/proc/release_singer()
	hide_body()
	singer.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, FNF_CHARRED)
	// Stop swaying about dazed.
	singer.fnf_rest()
	singer.remove_traits(list(TRAIT_FLOORED, TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_UI_BLOCKED), FNF_GAME_OVER_TRAIT)
	for(var/datum/weakref/item_ref as anything in stuck_items)
		var/obj/item/held = item_ref.resolve()
		if(held)
			REMOVE_TRAIT(held, TRAIT_NODROP, FNF_GAME_OVER_TRAIT)
	stuck_items.Cut()

/datum/fnf_game_over/proc/add_screen(category, type)
	categories += category
	return singer.overlay_fullscreen(category, type)

/datum/fnf_game_over/proc/on_singer_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/**
 * Draws the singer themselves over the blackout, right where they stand on screen, and twice the
 * size: the figure holds them, and they draw on its plane for as long as it does.
 */
/datum/fnf_game_over/proc/show_body()
	figure = add_screen("fnf_figure", /atom/movable/screen/fullscreen/fnf/body)
	old_vis_flags = singer.vis_flags
	singer.vis_flags |= VIS_INHERIT_PLANE|VIS_INHERIT_LAYER
	figure.vis_contents += singer
	showing_body = TRUE

/datum/fnf_game_over/proc/hide_body()
	if(!showing_body)
		return
	showing_body = FALSE
	figure?.vis_contents -= singer
	singer.vis_flags = old_vis_flags

/// Something acted out around the body: a knife, a can, blood, smoke. In pixels from the singer's feet.
/datum/fnf_game_over/proc/add_prop(icon_file, state, x_offset, y_offset, prop_layer = 52)
	var/obj/effect/abstract/fnf_prop/prop = new
	prop.icon = icon_file
	prop.icon_state = state
	prop.pixel_w = x_offset
	prop.pixel_z = y_offset
	prop.layer = prop_layer
	figure?.vis_contents += prop
	props += prop
	return prop

/// Which way is toward the rival, as a sign for pixel offsets.
/datum/fnf_game_over/proc/ahead()
	return facing == EAST ? 1 : -1

/// The usual Pico death: a knife flies in and sticks in their head, and the blood goes everywhere.
/datum/fnf_game_over/proc/throw_knife()
	// Thrown from in front, so the blade points back into the neck and the handle sticks out front.
	knife = add_prop('icons/mob/inhands/equipment/kitchen_righthand.dmi', "knife", ahead() * 90, 0)
	knife.dir = facing == EAST ? WEST : EAST
	neck_x = ahead() * 2
	neck_y = FNF_NECK_Y
	var/list/blade = knife_blade_offset()
	knife.pixel_z = neck_y - blade[2] + 8
	animate(knife, pixel_w = neck_x - blade[1], pixel_z = neck_y - blade[2], transform = turn(matrix(), 720), time = 2.5, easing = LINEAR_EASING)
	addtimer(CALLBACK(src, PROC_REF(knife_hits)), 2.5, TIMER_DELETE_ME)

/// Where the in-hand knife sprite's blade sits, from the middle of its 32 by 32 icon.
/datum/fnf_game_over/proc/knife_blade_offset()
	return knife.dir == WEST ? list(-6.5, -2.5) : list(1.5, -2.5)

/datum/fnf_game_over/proc/knife_hits()
	SEND_SOUND(singer, sound('sound/items/weapons/bladeslice.ogg', volume = 60))
	singer.fnf_act("hit_high", singer.fnf_mic_arm(facing), facing, null, 6)
	animate(blackout, color = "#5a0000", time = 0)
	animate(color = "#000000", time = 3)
	var/obj/effect/abstract/fnf_prop/pool = add_prop('icons/effects/blood.dmi', "floor[rand(1, 7)]", ahead() * -8, -6, 50.5)
	pool.color = get_blood_colour()
	pool.alpha = 0
	pool.transform = matrix() * 0.3
	animate(pool, alpha = 255, transform = matrix() * 1.4, time = 25, delay = 8, easing = SINE_EASING)
	gush()

/// The fountain: blood gushing up out of the neck and raining back down, on and on until they pick.
/datum/fnf_game_over/proc/gush()
	if(retrying || !figure || !knife)
		return
	var/blood_colour = get_blood_colour()
	for(var/i in 1 to 3)
		var/obj/effect/abstract/fnf_prop/drop = add_prop('icons/effects/blood.dmi', "drip[rand(1, 5)]", neck_x, neck_y)
		drop.color = blood_colour
		var/drift = rand(-22, 22)
		animate(drop, pixel_w = neck_x + drift * 0.4, pixel_z = neck_y + rand(24, 44), time = 3 + i, easing = SINE_EASING|EASE_OUT)
		animate(pixel_w = neck_x + drift, pixel_z = rand(-14, -10), alpha = 160, time = 5, easing = QUAD_EASING|EASE_IN)
		QDEL_IN(drop, 12)
		addtimer(CALLBACK(src, PROC_REF(forget_prop), drop), 11, TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(gush)), 2, TIMER_DELETE_ME)

/// 2hot's: the can Pico should have shot comes down on them and goes off in their face.
/datum/fnf_game_over/proc/throw_can()
	var/obj/effect/abstract/fnf_prop/can = add_prop('icons/obj/art/crayons.dmi', "spraycan", ahead() * 60, FNF_FACE_Y + 30)
	animate(can, pixel_w = ahead() * 4, pixel_z = FNF_FACE_Y, transform = turn(matrix(), 540), time = 3, easing = QUAD_EASING|EASE_IN)
	addtimer(CALLBACK(src, PROC_REF(can_explodes), can), 3, TIMER_DELETE_ME)

/datum/fnf_game_over/proc/can_explodes(obj/effect/abstract/fnf_prop/can)
	props -= can
	qdel(can)
	var/obj/effect/abstract/fnf_prop/bang = add_prop('icons/effects/96x96.dmi', "explosionfast", ahead() * 4 - 32, FNF_FACE_Y - 32)
	bang.transform = matrix() * 0.7
	QDEL_IN(bang, 12)
	animate(blackout, color = "#ffffff", time = 0)
	animate(color = "#000000", time = 4)
	// Burnt to a crisp, and a pink plume of spray paint going up.
	singer.add_atom_colour(FNF_CHARRED, TEMPORARY_COLOUR_PRIORITY)
	singer.fnf_act("hit_high", singer.fnf_mic_arm(facing), facing, null, 8)
	for(var/i in 1 to 6)
		var/obj/effect/abstract/fnf_prop/puff = add_prop('icons/effects/effects.dmi', "smoke", rand(-10, 10), FNF_FACE_Y)
		puff.color = "#ff5ac8"
		puff.alpha = 220
		puff.transform = matrix() * 0.5
		animate(puff, pixel_w = rand(-24, 24), pixel_z = FNF_FACE_Y + 14 + i * 8, transform = matrix() * (1.2 + i * 0.2), alpha = 0, time = 20 + i * 3, easing = SINE_EASING|EASE_OUT)

/// After the bang: swaying on the spot, stars round the head, coughing up smoke until they choose.
/datum/fnf_game_over/proc/daze()
	if(!figure)
		return
	// Drawn round a human's head: lifted up to this one's.
	var/obj/effect/abstract/fnf_prop/stars = add_prop('icons/effects/effects.dmi', "dazed", 0, 6)
	stars.alpha = 0
	animate(stars, alpha = 255, time = 3)
	var/mic_arm = singer.fnf_mic_arm(facing)
	var/mob/living/carbon/rigged = singer
	if(istype(rigged) && rigged.limb_rig)
		var/list/rest = fnf_pose("rest", mic_arm, facing, null)
		var/list/sway_left = fnf_nudge_pose(fnf_nudge_pose(rest, RIG_HEAD, "tilt", 14), RIG_CHEST, "lean", 5)
		var/list/sway_right = fnf_nudge_pose(fnf_nudge_pose(rest, RIG_HEAD, "tilt", -14), RIG_CHEST, "lean", -5)
		sway_left = fnf_nudge_pose(sway_left, RIG_HEAD, "nod", 12)
		sway_right = fnf_nudge_pose(sway_right, RIG_HEAD, "nod", 12)
		rigged.limb_rig.play(list(list(sway_left, 8, SINE_EASING), list(sway_right, 8, SINE_EASING)), loop = -1, settle_after = FALSE)
	cough()

/datum/fnf_game_over/proc/cough()
	if(retrying || !figure)
		return
	var/sound_file = "sound/mobs/humanoids/human/cough/[singer.gender == FEMALE ? "female_cough[rand(1, 6)]" : "male_cough[rand(1, 4)]"].ogg"
	SEND_SOUND(singer, sound(sound_file, volume = 45))
	for(var/i in 1 to 3)
		var/obj/effect/abstract/fnf_prop/puff = add_prop('icons/effects/effects.dmi', "smoke", ahead() * 6, FNF_FACE_Y - 2)
		puff.color = pick("#3a3a3a", "#ff5ac8")
		puff.transform = matrix() * 0.25
		animate(puff, pixel_w = ahead() * (14 + i * 6), pixel_z = FNF_FACE_Y + 4 + i * 3, transform = matrix() * 0.7, alpha = 0, time = 10 + i * 2, easing = SINE_EASING|EASE_OUT)
		QDEL_IN(puff, 16)
		addtimer(CALLBACK(src, PROC_REF(forget_prop), puff), 15, TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(cough)), rand(20, 35), TIMER_DELETE_ME)

/datum/fnf_game_over/proc/forget_prop(obj/effect/abstract/fnf_prop/prop)
	props -= prop

/// Blazin's: folded in half by a punch to the gut.
/datum/fnf_game_over/proc/gut_punch()
	SEND_SOUND(singer, sound("sound/items/weapons/punch[rand(1, 4)].ogg", volume = 70))
	singer.fnf_act("hit_low", singer.fnf_mic_arm(facing), facing, null, 6)

/// The colour of the singer's blood, to bleed with.
/datum/fnf_game_over/proc/get_blood_colour()
	return singer.get_bloodtype()?.get_damage_color(singer) || "#a10808"

/// Down they go, and the blood spreads out under them.
/datum/fnf_game_over/proc/fall()
	singer.add_traits(list(TRAIT_FLOORED), FNF_GAME_OVER_TRAIT)
	if(knife)
		// Lying down turns them to face the viewer, so the neck is dead centre, then the whole body
		// turns onto its side: the knife goes with it.
		RegisterSignal(singer, COMSIG_LIVING_POST_UPDATE_TRANSFORM, PROC_REF(on_body_turned))
	if(death == "gutpunch")
		// Keeled over in their own blood, coughed up with the punch.
		var/obj/effect/abstract/fnf_prop/pool = add_prop('icons/effects/blood.dmi', "floor[rand(1, 7)]", ahead() * 6, -8, 50.5)
		pool.color = get_blood_colour()
		pool.alpha = 0
		pool.transform = matrix() * 0.4
		animate(pool, alpha = 255, transform = matrix() * 1.3, time = 18, easing = SINE_EASING)

/datum/fnf_game_over/proc/on_body_turned(mob/living/source, resize, lying_angle, is_opposite_angle)
	SIGNAL_HANDLER
	UnregisterSignal(singer, COMSIG_LIVING_POST_UPDATE_TRANSFORM)
	if(lying_angle)
		knife_follows(lying_angle)

/// Keeps the knife in the neck as the body turns onto its side.
/datum/fnf_game_over/proc/knife_follows(angle)
	if(!knife)
		return
	// The neck, from the middle of the body (dead centre now they face the viewer), turned the way
	// the body turned. The fountain carries on from there.
	neck_x = FNF_NECK_Y * sin(angle)
	neck_y = FNF_NECK_Y * cos(angle) + PIXEL_Y_OFFSET_LYING
	var/list/blade = knife_blade_offset()
	animate(knife, pixel_w = neck_x - blade[1], pixel_z = neck_y - blade[2], transform = turn(matrix(), angle), time = UPDATE_TRANSFORM_ANIMATION_TIME, easing = EASE_IN|EASE_OUT)

/datum/fnf_game_over/proc/cock_gun()
	SEND_SOUND(singer, sound("voidcrew/modules/fnf/sound/gun_cock.ogg", volume = 60))

/// Bang. The death plays through once, then it lies there twitching.
/datum/fnf_game_over/proc/shoot()
	SEND_SOUND(singer, sound("voidcrew/modules/fnf/sound/shot[rand(1, 4)].ogg", volume = 70))
	animate(blackout, color = "#ffffff", time = 0)
	animate(color = "#000000", time = 2)
	// A kick of recoil on the whole figure, on top of what the frames do.
	var/back = facing == EAST ? -1 : 1
	animate(figure, transform = matrix(2, 0, back * 6, 0, 2, 48), time = 0.5, easing = CUBIC_EASING|EASE_OUT)
	animate(transform = matrix(2, 0, 0, 0, 2, 48), time = 2)
	figure.icon_state = "expie_death"
	// 31 frames at half a decisecond each.
	addtimer(CALLBACK(src, PROC_REF(twitch)), 15.5, TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(yelp)), 1, TIMER_DELETE_ME)

/datum/fnf_game_over/proc/twitch()
	figure.icon_state = "expie_twitch"

/datum/fnf_game_over/proc/yelp()
	SEND_SOUND(singer, sound(get_expie_death_sound(), volume = 50))

/datum/fnf_game_over/proc/show_buttons()
	if(retrying)
		return
	var/music_file = own_sounds?["loop"] || (death == "shot" ? "voidcrew/modules/fnf/sound/gameover_loop.ogg" : "voidcrew/modules/fnf/sound/gameover_loop_pico.ogg")
	SEND_SOUND(singer, sound(music_file, repeat = TRUE, channel = music_channel, volume = 45))
	if(can_retry)
		retry_button = add_screen("fnf_retry", /atom/movable/screen/fullscreen/fnf/button/retry)
		retry_button.game_over = src
		var/static/list/retry_styles = list("knife" = "retry_blood", "explode" = "retry_smoke", "gutpunch" = "retry_splat")
		retry_button.base_state = retry_styles[death] || "retry"
		retry_button.icon_state = retry_button.base_state
		retry_button.pop_in()
	give_up_button = add_screen("fnf_give_up", /atom/movable/screen/fullscreen/fnf/button/give_up)
	give_up_button.game_over = src
	give_up_button.pop_in()

/// Clicked RETRY: an Experiment makes its last stand, anyone else hears the jingle; then the song
/// starts again.
/datum/fnf_game_over/proc/retry()
	if(retrying || !can_retry)
		return
	retrying = TRUE
	SEND_SOUND(singer, sound(null, channel = music_channel))
	retry_button.confirm()
	animate(give_up_button, alpha = 0, time = 3)
	if(death == "shot")
		last_stand()
		return
	SEND_SOUND(singer, sound(own_sounds?["end"] || (death == "shot" ? "voidcrew/modules/fnf/sound/gameover_retry.ogg" : "voidcrew/modules/fnf/sound/gameover_retry_pico.ogg"), volume = 60))
	// The body goes back into the dark with everything else, to be set up again.
	if(figure)
		animate(figure, alpha = 0, time = 12)
	for(var/obj/effect/abstract/fnf_prop/prop as anything in props)
		animate(prop, alpha = 0, time = 12)
	animate(blackout, alpha = 255, time = 15)
	addtimer(CALLBACK(src, PROC_REF(sing_again), 0, 20), 25, TIMER_DELETE_ME)
	// Back into the light as the count in starts.
	animate(blackout, alpha = 255, time = 25)
	animate(alpha = 0, time = 20, easing = SINE_EASING)

/**
 * "Let's not give up just yet." Eight seconds of drone, the screen flickering through its three
 * grainy takes, fading back slowly to the world as it ends. Once it's fully dark the new battle is
 * set up, counting in two seconds late, as the drone runs out.
 */
/datum/fnf_game_over/proc/last_stand()
	SEND_SOUND(singer, sound("voidcrew/modules/fnf/sound/laststand_drone.ogg", volume = 70))
	laststand = add_screen("fnf_laststand", /atom/movable/screen/fullscreen/fnf/laststand)
	laststand.alpha = 0
	// In over the dead body, held a while, then eased away as the world comes back.
	animate(laststand, alpha = 255, time = 8)
	animate(alpha = 255, time = 14)
	animate(alpha = 0, time = 50, easing = SINE_EASING)
	animate(figure, alpha = 0, time = 8)
	animate(retry_button, alpha = 0, time = 10, delay = 5)
	animate(blackout, alpha = 255, time = 30)
	animate(alpha = 0, time = 50, easing = SINE_EASING)
	addtimer(CALLBACK(src, PROC_REF(sing_again), 2 SECONDS, 50), 30, TIMER_DELETE_ME)

/**
 * Starts the song again, straight from the floor into the new battle so they never stand around
 * in between.
 *
 * * lead_in - extra deciseconds before the count in
 * * linger - deciseconds to leave the game over screens up, to finish fading
 */
/datum/fnf_game_over/proc/sing_again(lead_in = 0, linger = 0)
	var/mob/living/again = singer
	var/datum/fnf_song/song_again = song
	var/difficulty_again = difficulty
	if(linger)
		QDEL_IN(src, linger)
	else
		qdel(src)
	if(QDELETED(again) || again.stat != CONSCIOUS)
		return
	var/obj/item/fnf_microphone/microphone = locate() in again.held_items
	if(microphone?.battle)
		if(microphone.battle.state != FNF_STATE_OVER)
			return
		microphone.battle = null
	var/datum/fnf_battle/battle = new(song_again, difficulty_again, microphone)
	battle.lead_in = lead_in
	if(microphone)
		microphone.battle = battle
	battle.preload(again)
	battle.start(again, null)
	// Only now let go, so they go from lying down straight into their stance.
	if(!QDELETED(src))
		release_singer()

/// Clicked GIVE UP: everything fades out and the singer gets up.
/datum/fnf_game_over/proc/give_up()
	if(retrying)
		return
	retrying = TRUE
	SEND_SOUND(singer, sound(null, channel = music_channel))
	for(var/atom/movable/screen/fullscreen/fnf/screen as anything in list(blackout, figure, retry_button, give_up_button))
		if(screen)
			animate(screen, alpha = 0, time = 10)
	for(var/obj/effect/abstract/fnf_prop/prop as anything in props)
		animate(prop, alpha = 0, time = 10)
	QDEL_IN(src, 10)

/// The black that covers everything.
/atom/movable/screen/fullscreen/fnf
	icon = 'voidcrew/modules/fnf/icons/fnf.dmi'
	icon_state = "bar"
	color = "#000000"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	layer = 50
	appearance_flags = PIXEL_SCALE|KEEP_TOGETHER
	show_when_dead = TRUE

/// The fallen Experiment. 160 by 96, standing on the middle of its bottom edge, drawn twice size
/// with its feet kept on the singer's tile.
/atom/movable/screen/fullscreen/fnf/figure
	icon = 'voidcrew/modules/fnf/icons/fnf_dead.dmi'
	icon_state = "expie_doomed"
	color = null
	screen_loc = "CENTER:-64,CENTER"
	layer = 51

/atom/movable/screen/fullscreen/fnf/figure/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	transform = matrix(2, 0, 0, 0, 2, 48)

/// Holds the singer themselves over the blackout, right where they are on screen, twice the size
/// with their feet kept where they stand.
/atom/movable/screen/fullscreen/fnf/body
	icon = null
	icon_state = null
	color = null
	screen_loc = "CENTER,CENTER"
	layer = 51
	appearance_flags = PIXEL_SCALE

/atom/movable/screen/fullscreen/fnf/body/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	transform = matrix(2, 0, 0, 0, 2, 16)

/// A knife, a can, a drop of blood or a puff of smoke, drawn with the body over the blackout.
/obj/effect/abstract/fnf_prop
	name = ""
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = PIXEL_SCALE
	vis_flags = VIS_INHERIT_PLANE

/// "Let's not give up just yet.", 640 by 360, centred and blown up to cover the screen.
/atom/movable/screen/fullscreen/fnf/laststand
	icon = 'voidcrew/modules/fnf/icons/laststand.dmi'
	icon_state = "laststand"
	color = null
	screen_loc = "CENTER-9:-16,CENTER-5:-4"
	layer = 55

/atom/movable/screen/fullscreen/fnf/laststand/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	transform = matrix() * 1.4

/**
 * A game over button. These sit on the HUD plane: the fullscreen plane doesn't take clicks at all.
 * They light up under the mouse.
 */
/atom/movable/screen/fullscreen/fnf/button
	icon = 'voidcrew/modules/fnf/icons/fnf_buttons.dmi'
	color = null
	plane = HUD_PLANE
	layer = 60
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	appearance_flags = PIXEL_SCALE
	var/datum/fnf_game_over/game_over
	/// Whether it's been clicked, and stays lit.
	var/pressed = FALSE
	/// The icon state it shows unlit: the RETRY styles differ with how you died.
	var/base_state

/atom/movable/screen/fullscreen/fnf/button/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	base_state = icon_state

/atom/movable/screen/fullscreen/fnf/button/Destroy()
	game_over = null
	return ..()

/atom/movable/screen/fullscreen/fnf/button/proc/pop_in()
	transform = matrix() * 1.8
	alpha = 0
	animate(src, transform = matrix(), alpha = 255, time = 3, easing = BACK_EASING|EASE_OUT)

/atom/movable/screen/fullscreen/fnf/button/MouseEntered(location, control, params)
	. = ..()
	if(!pressed)
		icon_state = "[base_state]_lit"

/atom/movable/screen/fullscreen/fnf/button/MouseExited(location, control, params)
	. = ..()
	if(!pressed)
		icon_state = base_state

/atom/movable/screen/fullscreen/fnf/button/proc/confirm()
	pressed = TRUE
	icon_state = "[base_state]_lit"
	animate(src, transform = matrix() * 1.3, time = 1)
	animate(transform = matrix() * 1.1, time = 3)

/// RETRY, throbbing gently until it's clicked.
/atom/movable/screen/fullscreen/fnf/button/retry
	icon_state = "retry"
	screen_loc = "CENTER:-80,CENTER+3"

/atom/movable/screen/fullscreen/fnf/button/retry/pop_in()
	transform = matrix() * 1.8
	alpha = 0
	animate(src, transform = matrix(), alpha = 255, time = 3, easing = BACK_EASING|EASE_OUT)
	animate(transform = matrix() * 0.94, time = 6, loop = -1, easing = SINE_EASING)
	animate(transform = matrix() * 1.04, time = 6, easing = SINE_EASING)

/atom/movable/screen/fullscreen/fnf/button/retry/Click(location, control, params)
	if(usr == game_over?.singer)
		game_over.retry()

/atom/movable/screen/fullscreen/fnf/button/give_up
	icon_state = "giveup"
	screen_loc = "CENTER:-80,CENTER-3"

/atom/movable/screen/fullscreen/fnf/button/give_up/Click(location, control, params)
	if(usr == game_over?.singer)
		game_over.give_up()

#undef FNF_CHARRED
#undef FNF_NECK_Y
#undef FNF_FACE_Y
