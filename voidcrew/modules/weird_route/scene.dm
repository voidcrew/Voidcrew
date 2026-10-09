// The scene itself: obj_ch5_LW20W's cutscene, then obj_ch5_LW20W_handoff's asking, then where it ends.
// Times are the game's frames (30 to a second), positions its units (64 to a tile). Where the game's
// own code wasn't to hand (its effects objects, and what it does once they're all the way in), what's
// here stands in for it and says so.

/datum/weird_route/proc/play_scene()
	// Moffer's at the water's edge, looking out over it. They come up the path behind him.
	put(player, 40)
	player.setDir(EAST)
	put(moffer, 384)
	moffer.setDir(EAST)
	against_sun(player, TRUE)
	against_sun(moffer, TRUE)
	give_shadow(player)
	give_shadow(moffer)
	play_sound("ocean.ogg", 0, 0, music_channel, TRUE)
	fade(music_channel, 0, 0.5, 30, 1)
	var/walk_time = (288 - 40) / 4
	pan(156 + 320, walk_time)
	walk_along(player, 288, walk_time, TRUE)
	if(QDELETED(src))
		return
	WEIRD_ROUTE_WAIT(60)
	say(list(
		"* (Kris.)/",
		"* (I know.)/",
		"* (I know you wanted to deny it.)/",
		"* (I did too^1, at first.)/",
		"* (But..^1. eventually...)/",
		"* (We're going to have to face the truth.)/%",
	), "snd_text.wav")
	// Remembering yesterday: the ominous fade.
	clouds_in()
	WEIRD_ROUTE_WAIT(200)
	say(list(
		"* (Yesterday^1, when..^1. everything happened...)/",
		"* (Every cell in my body was screaming at me to run away.)/",
		"* (..^1. that if I stayed by your side any longer,)/",
		"* (You were going to drag me down with you.)/",
		"* (Drag me down somewhere no one is supposed to go.)/",
		"* (...)/",
		"* (And you know what terrified me the most about that?)/%",
	), "snd_text.wav")
	clouds_out()
	// He looks back at them, his shadow shortening as he turns.
	WEIRD_ROUTE_WAIT(24)
	moffer.setDir(WEST)
	give_shadow(moffer)
	WEIRD_ROUTE_WAIT(31)
	while(clouds_state != 2)
		WEIRD_ROUTE_WAIT(1)
	clouds_hide()
	WEIRD_ROUTE_WAIT(30)
	pose(moffer, "up_head_tilt")
	say(list("* (I think...)/%"), "snd_text.wav")
	WEIRD_ROUTE_WAIT(15)
	pose(moffer, "up")
	WEIRD_ROUTE_WAIT(15)
	fade(music_channel, 0.5, 0, 30, 1)
	say(list("* I want that./%"), rate = 4)
	WEIRD_ROUTE_WAIT(90)
	animate(blackout, alpha = 255, time = 120 * WEIRD_ROUTE_FRAME)
	WEIRD_ROUTE_WAIT(180)
	blackout.alpha = 0
	pinwheel_start()
	play_sound("ch5_weird_monologue_deep.ogg", 0, 0.95, music_channel, TRUE)
	fade(music_channel, 0, 0.7, 30, 0.95)
	say(list(
		"* Since Dess left.../",
		CALLBACK(src, PROC_REF(pinwheel_segment)),
		"* All I've been doing has just been.../%",
	))
	pinwheel_segment()
	WEIRD_ROUTE_WAIT(30)
	say(list("* Marching down my path./%"))
	pinwheel_segment()
	WEIRD_ROUTE_WAIT(30)
	say(list("* Staying quiet^1. Getting good grades./%"))
	pinwheel_turn(TRUE)
	pinwheel_ripple()
	WEIRD_ROUTE_WAIT(30)
	say(list("* It feels like..^1. I've just been watching myself through glass./%"))
	WEIRD_ROUTE_WAIT(30)
	pinwheel_turn()
	pinwheel_ripple()
	say(list("* Watching someone else move me through my life./%"))
	WEIRD_ROUTE_WAIT(30)
	pinwheel_turn()
	pinwheel_ripple()
	say(list("* That's why I want..^1. to do something crazy./%"))
	WEIRD_ROUTE_WAIT(30)
	pinwheel_turn()
	pinwheel_ripple()
	say(list("* That's why I want..^1. to break free./%"))
	WEIRD_ROUTE_WAIT(30)
	play_sound("snd_noise.wav")
	pinwheel_fade()
	WEIRD_ROUTE_WAIT(30)
	pinwheel_kneel()
	say(list(
		"* But^1, I can't^1. I couldn't./",
		"* Because I'm just Noelle./",
		"* A Noelle that has to do Noelle things./%",
	))
	pinwheel_silhouette_out()
	pose(player, "head_down")
	pose(moffer, "head_down")
	put(moffer, 320)
	WEIRD_ROUTE_WAIT(90)
	blackout.alpha = 255
	pinwheel_clean_up()
	say(list("* Just like Kris has to do Kris things.../%"))
	WEIRD_ROUTE_WAIT(60)
	say(list("* But Kris..^1. you changed./%"))
	animate(blackout, alpha = 0, time = 60 * WEIRD_ROUTE_FRAME)
	WEIRD_ROUTE_WAIT(90)
	pose(moffer, "exasperated")
	say(list(
		CALLBACK(src, PROC_REF(set_waver), TRUE),
		"* Kris^1, YOU actually changed!/",
		CALLBACK(src, PROC_REF(shake), moffer),
		CALLBACK(src, PROC_REF(set_waver), FALSE),
		"* You found out how to stop being Kris!/",
		CALLBACK(src, PROC_REF(pose), moffer, "head_down", 8),
		"* And no one else has noticed.../%",
	), face = TRUE)
	WEIRD_ROUTE_WAIT(30)
	say(list(
		CALLBACK(src, PROC_REF(set_waver), TRUE),
		"* Because they don't want to!/",
		CALLBACK(src, PROC_REF(pose), moffer, "exasperated", 8),
		CALLBACK(src, PROC_REF(shake), moffer),
		"* They don't want to see how INTERESTING you are now!/",
		CALLBACK(src, PROC_REF(shake_head), moffer),
		CALLBACK(src, PROC_REF(set_waver), FALSE),
		"* They'll just keep marching down the same path.../",
		CALLBACK(src, PROC_REF(pose), moffer, "exasperated", 8),
		CALLBACK(src, PROC_REF(shake), moffer),
		CALLBACK(src, PROC_REF(set_waver), TRUE),
		"* Without even thinking where it goes!/%",
	), face = TRUE)
	WEIRD_ROUTE_WAIT(30)
	pose(moffer, "head_down")
	say(list(
		CALLBACK(src, PROC_REF(set_waver), FALSE),
		"* Kris.../",
		CALLBACK(src, PROC_REF(pose), moffer, "hands_to_chest", 30),
		"* Being around you.../%",
	), face = TRUE)
	WEIRD_ROUTE_WAIT(60)
	pose(moffer, "hands_to_chest_head_down")
	say(list("* Is changing me^1, too./%"), face = TRUE)
	WEIRD_ROUTE_WAIT(15)
	say(list(
		"* K..^1. Kris.../",
		"* Kris^1, when I cast \"Snowgrave...\"/",
		CALLBACK(src, PROC_REF(pose), moffer, "hands_to_chest_turn_head", 8),
		"* I.../",
		CALLBACK(src, PROC_REF(pose), moffer, "hands_to_chest_head_down_more", 8),
		"* I felt stronger than I have in my entire life./%",
	), face = TRUE)
	WEIRD_ROUTE_WAIT(30)
	// They look up; he drops to the ground.
	pose(player, "rest", 15)
	pose(moffer, "fall", 30)
	WEIRD_ROUTE_WAIT(20)
	shake(moffer)
	play_sound("snd_wing.wav")
	WEIRD_ROUTE_WAIT(30)
	shake_head(moffer)
	WEIRD_ROUTE_WAIT(56)
	say(list(
		CALLBACK(src, PROC_REF(set_waver), TRUE),
		"* I know..^1. it's horrible^1. It's horrible to say that^1, but.../%",
	))
	pose(moffer, "kneel", 30)
	WEIRD_ROUTE_WAIT(60)
	pose(moffer, "kneel_head_down")
	say(list(
		CALLBACK(src, PROC_REF(set_waver), FALSE),
		"* Kris./",
		CALLBACK(src, PROC_REF(pose), moffer, "kneel_head_down", 8),
		"* You..^1. if it's you telling me to^1, I can do anything./",
		"* If you tell me to^1, I can do things that are impossible./",
		CALLBACK(src, PROC_REF(pose), moffer, "kneel", 8),
		"* Things no one else can do./%",
	), face = TRUE)
	WEIRD_ROUTE_WAIT(30)
	pose(moffer, "kneel_head_up")
	say(list("* So^1, why don't we do it?/%"), face = TRUE)
	pose(moffer, "kneel_head_down")
	WEIRD_ROUTE_WAIT(30)
	say(list("* Why don't we do.../%"), face = TRUE)
	// He gets up and comes to them.
	pose(player, "head_down", 16)
	pose(moffer, "rest")
	walk_along(moffer, 309, 16, TRUE)
	if(QDELETED(src))
		return
	say(list(
		"* \"Something crazy?\"/",
		CALLBACK(src, PROC_REF(pose), moffer, "head_down", 8),
		"* Tell me./%",
	), face = TRUE)
	pose(moffer, "hands_to_chest", 30)
	WEIRD_ROUTE_WAIT(45)
	say(list(
		"* Tell me to grow wings.../",
		CALLBACK(src, PROC_REF(pose), moffer, "hands_to_side", 30),
		"* And let's fly out of this stupid town!/",
		CALLBACK(src, PROC_REF(pose), moffer, "exasperated", 8),
		CALLBACK(src, PROC_REF(shake), moffer),
		CALLBACK(src, PROC_REF(set_waver), TRUE),
		"* To somewhere no one has ever been before!/%",
	), face = TRUE)
	pose(moffer, "walk_left_hands_up")
	walk_along(moffer, 320, 30)
	WEIRD_ROUTE_WAIT(45)
	pose(moffer, "hands_to_chest_turn_up", 20)
	WEIRD_ROUTE_WAIT(26)
	// He turns back to the water.
	WEIRD_ROUTE_WAIT(12)
	moffer.setDir(EAST)
	WEIRD_ROUTE_WAIT(20)
	pose(moffer, "rest")
	set_waver(FALSE)
	say(list(
		"* .../",
		"* The other side of the lake./",
		"* We always wanted to see what was there^1, didn't we?/",
		"* The four of us^1, when we were kids.../%",
	))
	WEIRD_ROUTE_WAIT(12)
	moffer.setDir(WEST)
	WEIRD_ROUTE_WAIT(14)
	pose(moffer, "hands_to_chest_turn_up", 20)
	WEIRD_ROUTE_WAIT(35)
	pose(moffer, "hands_to_chest_head_down")
	say(list(
		"* Kris^1, let's go there./",
		CALLBACK(src, PROC_REF(pose), moffer, "walk_left_hands_up", 8),
		"* You'll tell me^1, won't you?/",
		CALLBACK(src, PROC_REF(pose), moffer, "hands_to_chest_head_down", 8),
		"* If you tell me to^1, I can do anything./%",
	), face = TRUE)
	pose(moffer, "walk_left_hands_up")
	walk_along(moffer, 305, 30, TRUE)
	if(QDELETED(src))
		return
	WEIRD_ROUTE_WAIT(30)
	// He takes their hands.
	pose(moffer, "take_hands", 30)
	pose(player, "take_hands", 30)
	WEIRD_ROUTE_WAIT(30)
	say(list("* So..^1. tell me^1, Kris./%"), face = TRUE)
	fade(music_channel, 0.7, 0, 60, 0.95)
	WEIRD_ROUTE_WAIT(30)
	// And leads them down to the water, hand in hand.
	moffer.setDir(EAST)
	player.setDir(EAST)
	pose(moffer, "lead")
	pose(player, "follow")
	pan(220 + 320, 120)
	walk_along(moffer, WEIRD_ROUTE_HANDOFF_X, 120)
	walk_along(player, WEIRD_ROUTE_HANDOFF_X - 17, 120)
	WEIRD_ROUTE_WAIT(150)
	say(list("* The words..^1. I've been waiting to hear./%"), face = TRUE)
	WEIRD_ROUTE_WAIT(60)
	ask()

/datum/weird_route/proc/set_waver(on)
	voice_waver = on
	text_shake = on ? 1 : 0
	if(on)
		INVOKE_ASYNC(src, PROC_REF(shake_text))

/// Jitters the text a pixel either way while his voice wavers (the asking shakes it itself).
/datum/weird_route/proc/shake_text()
	while(voice_waver && !QDELETED(src))
		writing.pixel_x = rand(-1, 1)
		writing.pixel_y = rand(-1, 1)
		sleep(2 * WEIRD_ROUTE_FRAME)
	if(!QDELETED(src))
		writing.pixel_x = 0
		writing.pixel_y = 0

/// Shakes his head, twice.
/datum/weird_route/proc/shake_head(mob/living/carbon/who)
	set waitfor = FALSE
	for(var/i in 1 to 2)
		who.limb_rig?.play(list(
			list(list(RIG_HEAD = list("nod" = 20, "tilt" = 14)), 2),
			list(list(RIG_HEAD = list("nod" = 20, "tilt" = -14)), 2),
		), settle_after = FALSE)
		sleep(16 * WEIRD_ROUTE_FRAME)
		if(QDELETED(src))
			return

/// Fades a looping sound from one volume to another over this many frames (the game's mus_volume()).
/datum/weird_route/proc/fade(channel, from, target, frames, pitch)
	set waitfor = FALSE
	var/started = world.time
	var/took = frames * WEIRD_ROUTE_FRAME
	while(world.time < started + took)
		tune(channel, from + (target - from) * (world.time - started) / took, pitch)
		sleep(world.tick_lag)
		if(QDELETED(src))
			return
	tune(channel, target, pitch)
	if(!target)
		SEND_SOUND(player, sound(null, channel = channel))

// The ominous fade (the game's obj_ch5_LW20W_vfx): three of its sprite, black all over but for a soft
// patch near the top, behind the two of them, each fading in slower than the last and breathing.

/datum/weird_route/proc/clouds_in()
	clouds_state = 1
	shape_clouds(0)
	var/list/fade_times = list(300, 360, 420)
	for(var/number in 1 to 3)
		var/atom/movable/screen/weird_route/pinwheel/cloud = clouds[number]
		cloud.alpha = 0
		animate(cloud, alpha = 255, time = fade_times[number] * WEIRD_ROUTE_FRAME)
	INVOKE_ASYNC(src, PROC_REF(clouds_breathe))

/datum/weird_route/proc/clouds_breathe()
	var/started = world.time
	while(clouds_state == 1 && !QDELETED(src))
		shape_clouds((world.time - started) / WEIRD_ROUTE_FRAME)
		sleep(world.tick_lag)

/**
 * Sizes the clouds to the player's screen as the game's are to its own 320x240 (the sprite drawn at
 * 0.85 to 0.9, about the middle of its soft patch, which sits a third of the way down the screen),
 * breathing a frame's worth in. Each axis the game leaves alone stays at 1.
 */
/datum/weird_route/proc/shape_clouds(breath)
	var/list/screen_size = view_pixels()
	// Our icon is 96px for the sprite's 380.
	var/across = screen_size[1] / 320 * 380 / 96
	var/down = screen_size[2] / 240 * 380 / 96
	var/list/breaths = list(
		list(1, abs(sin(breath / 60 * 180 / PI) * 0.05) + 0.85),
		list(abs(sin(breath / 90 * 180 / PI) * 0.05) + 0.85, 1),
		list(abs(sin(breath / 90 * 180 / PI) * 0.05) + 0.85, abs(cos(breath / 90 * 180 / PI) * 0.05) + 0.85),
	)
	for(var/number in 1 to 3)
		var/list/scale = breaths[number]
		var/x_scale = across * scale[1]
		var/y_scale = down * scale[2]
		var/matrix/shape = matrix()
		shape.Scale(x_scale, y_scale)
		// Its middle to the screen's (it's placed by its bottom left corner on the middle tile), then up
		// so the soft patch (20 of its 96px above its middle) is a third of the way down.
		shape.Translate(-32, -32 + screen_size[2] / 6 - (190 - 110) * 96 / 380 * y_scale)
		var/atom/movable/screen/weird_route/pinwheel/cloud = clouds[number]
		cloud.transform = shape

/// The player's view, in pixels: list(width, height).
/datum/weird_route/proc/view_pixels()
	var/list/size = getviewsize(player?.client?.view || world.view)
	return list(size[1] * 32, size[2] * 32)

/datum/weird_route/proc/clouds_out()
	set waitfor = FALSE
	var/list/fade_times = list(120, 180, 240)
	for(var/number in 1 to 3)
		animate(clouds[number], alpha = 0, time = fade_times[number] * WEIRD_ROUTE_FRAME)
	sleep(240 * WEIRD_ROUTE_FRAME)
	if(!QDELETED(src))
		clouds_state = 2

/datum/weird_route/proc/clouds_hide()
	clouds_state = 0
	for(var/atom/movable/screen/weird_route/pinwheel/cloud as anything in clouds)
		cloud.alpha = 0

// The pinwheel (the game's obj_ch5_LW20W_rotate). The game shows Dess's room, Noelle's house and the
// school, caught on the way here; these are a bridge, an engine room and a medbay, off the server.

/datum/weird_route/proc/pinwheel_start()
	pinwheel_on = TRUE
	void.alpha = 255
	vision = make_moffer()
	vision.moveToNullspace()
	// Facing out at whoever's watching.
	vision.setDir(SOUTH)
	vision.limb_rig?.set_seated("crouch")
	// The memories filling the screen, whatever its size.
	var/list/screen_size = view_pixels()
	for(var/atom/movable/screen/weird_route/pinwheel/place as anything in memories)
		place.transform = matrix(screen_size[1] / 480, 0, 0, 0, screen_size[2] / 480, 0)
	silhouette.vis_contents += vision
	silhouette.alpha = 0
	animate(silhouette, alpha = 255, time = 60 * WEIRD_ROUTE_FRAME)
	INVOKE_ASYNC(src, PROC_REF(pinwheel_process))

/// Turns it, fades its memories in and ripples them, a frame at a time, as the game's step does.
/datum/weird_route/proc/pinwheel_process()
	var/last = world.time
	var/list/screen_size = view_pixels()
	var/wedge_scale = max(screen_size[1], screen_size[2]) / 480
	while(pinwheel_on && !QDELETED(src))
		var/frames = (world.time - last) / WEIRD_ROUTE_FRAME
		last = world.time
		if(pinwheel_turning)
			if(!pinwheel_slowing || pinwheel_angle > 270 || pinwheel_angle < 180)
				pinwheel_angle += pinwheel_turn_speed * frames
			else
				pinwheel_angle += (270 - pinwheel_angle) * (1 - 0.95 ** frames)
			if(pinwheel_angle > 360)
				pinwheel_angle -= 360
		for(var/number in 1 to 3)
			var/atom/movable/screen/weird_route/pinwheel/wedge = wedges[number]
			var/matrix/turned = turn(matrix(), pinwheel_angle - 270 + (number - 1) * 120)
			turned.Scale(wedge_scale, wedge_scale)
			wedge.transform = turned
			var/atom/movable/screen/weird_route/pinwheel/place = memories[number]
			if(pinwheel_segments >= number)
				place.alpha = min(place.alpha + 0.02 * 255 * frames, 255)
		pinwheel_wave = min(pinwheel_wave + pinwheel_wave_speed * frames, 1)
		if(pinwheel_wave > 0)
			for(var/atom/movable/screen/weird_route/pinwheel/place as anything in memories)
				if(!place.get_filter("weird_route_wave"))
					place.add_filter("weird_route_wave", 2, wave_filter(x = 16, size = 0))
					animate(place.get_filter("weird_route_wave"), offset = 1, time = 20, loop = -1)
					animate(offset = 0, time = 0)
				place.modify_filter("weird_route_wave", list("size" = pinwheel_wave * 6))
		sleep(world.tick_lag)

/datum/weird_route/proc/pinwheel_segment()
	pinwheel_segments++

/// Sets it turning, or turning faster: a fifth of a degree a frame more each time, eased in over a second.
/datum/weird_route/proc/pinwheel_turn(start = FALSE)
	set waitfor = FALSE
	pinwheel_turning = TRUE
	var/from = pinwheel_turn_speed
	for(var/frame in 1 to 30)
		pinwheel_turn_speed = from + 0.2 * frame / 30
		sleep(WEIRD_ROUTE_FRAME)
		if(QDELETED(src))
			return

/datum/weird_route/proc/pinwheel_ripple()
	set waitfor = FALSE
	var/from = pinwheel_wave_speed
	for(var/frame in 1 to 30)
		pinwheel_wave_speed = from + 0.01 * frame / 30
		sleep(WEIRD_ROUTE_FRAME)
		if(QDELETED(src))
			return

/// The memories gone, all at once.
/datum/weird_route/proc/pinwheel_fade()
	pinwheel_segments = 0
	for(var/atom/movable/screen/weird_route/pinwheel/place as anything in memories)
		place.alpha = 0

/datum/weird_route/proc/pinwheel_kneel()
	if(vision?.limb_rig)
		vision.limb_rig.play(list(list(weird_route_pose("kneel"), 0.5)), settle_after = FALSE)

/datum/weird_route/proc/pinwheel_silhouette_out()
	animate(silhouette, alpha = 0, time = 60 * WEIRD_ROUTE_FRAME)

/datum/weird_route/proc/pinwheel_clean_up()
	pinwheel_on = FALSE
	pinwheel_fade()
	void.alpha = 0
	silhouette.alpha = 0
	silhouette.vis_contents.Cut()
	QDEL_NULL(vision)

// The asking: obj_ch5_LW20W_handoff.

/// What Moffer says with each "Proceed", or null where he says nothing.
GLOBAL_LIST_INIT(weird_route_proceed_lines, list(
	null,
	null,
	"* The water's..^1. nice^1, isn't it^1, Kris?/",
	null,
	"* Kris^1, don't hesitate./",
	null,
	"* Haha..^1. it's..^1. colder than I thought./",
	null,
	list("* Kris^1, don't let go of my hands./", "* Just keep walking./"),
	"* Kris^1, just..^1. keep walking./",
	"* Kris.../",
	"* Kris....../",
	"* .../",
	"* .../",
	null,
	null,
	"* (Kris^1, you can still hear me^1, can't you!?)/",
	null,
	"* (Kris..^1. keep..^1. saying it...!)/",
	null,
	"* (K..^1. Kris...!)/",
	null,
	null,
	"* (KRIS!!!)/",
	null,
	null,
	null,
	null,
	"* (SAY IT!!!!!!)/",
	null,
	null,
	null,
	null,
	null,
	"* (KRIS!!!!!!!!!)/",
	null,
))

/// What he says when they say "Stop": the first time, the second, and so on.
GLOBAL_LIST_INIT(weird_route_stop_lines, list(
	list("* No.../", "* You're supposed to say \"Proceed,^1\" right?/", "* Just like all the other times./%"),
	list("* Stop pretending./", "* I know you remember^1, too!/%"),
	list("* Why..^1. are your hands trembling...?/", "* Kris^1, you're the one that wanted this^1, aren't you?/%"),
	list("* Stop pretending you're still the old Kris./", "* You can't even say \"stop\" like you used to./%"),
	list("* Proceed./%"),
))

/// How far along textind is from a to b, 0 to 1: the game's wprog().
/datum/weird_route/proc/progress(textind, from, target)
	if(target == from)
		return textind >= from ? 1 : 0
	return clamp((textind - from) / (target - from), 0, 1)

/// Puts the two of them, hand in hand, at x: Moffer leading, the player a step behind.
/datum/weird_route/proc/put_pair(x)
	put(moffer, x)
	put(player, x - 17)
	camera_x = x + 170
	update_camera()
	// Into the water to their knees, then their waists, then their chins, as the game's submerge
	// object steps through its 47 frames of them going under between 240 and 928; then the tops of
	// their heads, gone a couple of steps on.
	var/going = weird_route_submerged(x)
	var/depth = going * 22 + clamp((x - 928) / (1024 - 928), 0, 1) * 12
	// Their shadow (one between them, from him) shrinking as there's less of them above the water.
	var/shadow_left = going >= 1 ? 22 + round(clamp((x - 928) / (1066 - 928), 0, 1) * 7) : round(going * 47 / 2)
	give_shadow(moffer, shadow_length = floor(58 * (1 - clamp(shadow_left / 33, 0, 1))))
	player.underlays.Cut()
	for(var/mob/living/who as anything in list(moffer, player))
		var/list/sink = who.get_filter("weird_route_sink")
		if(!sink)
			who.add_filter("weird_route_sink", 1, alpha_mask_filter(y = 32 + depth, icon = icon('voidcrew/modules/weird_route/icons/weird_route_mask.dmi', "mask")))
		else
			who.modify_filter("weird_route_sink", list("y" = 32 + depth))

/// How far under they are at x, 0 to 1: the game's mix of an ease-in-back and an ease-in-cubic.
/proc/weird_route_submerged(x)
	var/progress = max((x - 240) / (928 - 240), 0)
	var/overshoot = 1.70158
	var/back = progress * progress * ((overshoot + 1) * progress - overshoot)
	var/cubic = progress ** 3
	return clamp(back + (cubic - back) * 2 / 3, 0, 1)

/// Plays one of the asking's layered sounds at volume (the game's 0 to 1), if it's loud enough to hear.
/datum/weird_route/proc/play_layer(name, volume, pitch = 1)
	if(volume > 0)
		play_sound(name, volume * 60, pitch == 1 ? 0 : pitch)

/datum/weird_route/proc/ask()
	var/textind = 0
	var/stops = 0
	var/state = "ask"
	var/timer = 0
	var/actor_x = WEIRD_ROUTE_HANDOFF_X
	var/start_x = actor_x
	var/end_x = actor_x
	var/move_time = 1
	var/pause_time = 0
	var/move_started = FALSE
	var/noelle_water_sound = FALSE
	var/kris_water_sound = FALSE
	var/music_started = FALSE
	var/music_pitch = 0.6
	var/music_volume = 0
	var/submerged = FALSE
	var/fail_timer = 0
	var/fail_limit = 240
	var/whiteout_alpha = 0
	var/whiteness_alpha = 0
	var/blur = 0
	var/blur_flicker = 0
	var/hurt_timer = 0
	var/hurt_timer_2 = 0
	var/static_started = FALSE
	var/static_pitch = 0.7
	var/static_volume = 0
	var/last = world.time
	put_pair(actor_x)
	while(!QDELETED(src))
		var/frames = (world.time - last) / WEIRD_ROUTE_FRAME
		last = world.time
		switch(state)
			if("ask")
				var/line = GLOB.weird_route_proceed_lines[min(textind + 1, length(GLOB.weird_route_proceed_lines))]
				textind++
				var/list/options = list(textind >= 7 ? "Proceed" : "Stop", "Proceed")
				INVOKE_ASYNC(src, PROC_REF(write), line ? (islist(line) ? line : list(line)) : list(), "snd_txtnoe.wav", !!line, 2, options)
				state = "choosing"
			if("choosing")
				if(chosen)
					// Under it all, three dooms one over another, the deeper ones taking over.
					var/volume_1 = textind > 34 ? 0.7 - progress(textind, 34, 37) * 0.7 : 1 - progress(textind, 19, 34) * 0.3
					var/volume_2 = textind > 34 ? (1 - progress(textind, 34, 58)) * 0.8 : progress(textind, 19, 34)
					play_layer("snd_ominous.wav", volume_1)
					play_layer("snd_ominous_hell.wav", volume_2)
					play_layer("snd_ominous_hell_super.wav", progress(textind, 34, 54), 1 + 0.6 * progress(textind, 54, 74))
					state = chosen == 1 && textind < 7 ? "stopped" : "walk_wait"
					timer = 0
					if(textind >= WEIRD_ROUTE_END_INDEX)
						state = "end"
			if("stopped")
				timer += frames
				if(timer >= 2)
					INVOKE_ASYNC(src, PROC_REF(write), GLOB.weird_route_stop_lines[min(stops + 1, length(GLOB.weird_route_stop_lines))], "snd_txtnoe.wav", TRUE, 2)
					stops++
					state = "walk_wait"
					timer = 0
			if("walk_wait")
				if(!writer_busy)
					timer += frames
					if(timer >= 2)
						timer = 0
						state = "walk"
						move_started = FALSE
			if("walk")
				if(!move_started)
					move_started = TRUE
					var/amount = max(2, round(LERP(51, 20, progress(textind, 0, 54))))
					if(textind > 28)
						amount = round(LERP(15, 4, progress(textind, 28, 54)))
					if(textind > WEIRD_ROUTE_DROWN_INDEX)
						amount = round(amount / 2)
					var/speed = LERP(1.5, 2, clamp(textind / 20, 0, 1))
					start_x = actor_x
					end_x = actor_x + amount
					move_time = max(1, round(amount * speed))
				var/before = actor_x
				timer += frames
				actor_x = round(LERP(start_x, end_x, min(1, timer / move_time)))
				put_pair(actor_x)
				// Wading: with each other step while it's shallow, and every step from when it isn't.
				var/splash = textind < 13 && round(before / 16) != round(actor_x / 16)
				if(actor_x < 420)
					splash = FALSE
				if(!noelle_water_sound)
					splash = FALSE
					if(actor_x >= 400)
						noelle_water_sound = TRUE
						splash = TRUE
				if(!kris_water_sound && before < 419 && actor_x >= 419)
					splash = TRUE
					kris_water_sound = TRUE
				if(splash)
					var/volume_1 = textind > 34 ? 0.7 - progress(textind, 34, 37) * 0.7 : 1 - progress(textind, 19, 34) * 0.3
					var/volume_2 = textind > 34 ? (1 - progress(textind, 34, 54)) * 0.8 : progress(textind, 19, 34)
					play_layer("snd_wading.wav", volume_1)
					play_layer("snd_wading_type2.wav", volume_2)
					play_layer("snd_wading_type3_deep.wav", progress(textind, 34, 54))
				if(textind >= 13 && timer <= frames)
					play_layer("snd_wading_type2.wav", 1 - progress(textind, 13, 54))
					play_layer("snd_wading_type3_deep.wav", progress(textind, 34, 54))
				if(timer >= move_time)
					actor_x = end_x
					put_pair(actor_x)
					timer = 0
					pause_time = LERP(30, -1, progress(textind, 0, 12))
					state = "pause"
			if("pause")
				timer += frames
				if(timer >= pause_time)
					timer = 0
					state = "ask"
					if(!music_started)
						music_started = TRUE
						music_pitch = 0.35
						play_sound("ch5_inversion_lake_chant.ogg", 0, music_pitch, chant_channel, TRUE)
			if("end")
				timer += frames
				if(timer >= 300)
					stop_sounds()
					INVOKE_ASYNC(src, PROC_REF(insert_chapter))
					return
		if(QDELETED(src))
			return

		// The box going red, then back to white; the white over everything takes the rest.
		var/border_progress = progress(textind, 22, 23) * 0.5
		if(textind > 23)
			border_progress = progress(textind, 23, 28) * 0.5 + 0.5
		if(textind > 28)
			border_progress = 1 - progress(textind, 28, 44)
		border_colour = weird_route_blend(COLOR_WHITE, COLOR_RED, border_progress)
		inner_white = progress(textind, 28, 44)
		highlight_colour = weird_route_blend(COLOR_YELLOW, COLOR_WHITE, inner_white)
		colour_box()
		// The lake going white behind them, its light with it (or the sunset's would tint the white).
		whiteness_alpha += (progress(textind, 19, 28) - whiteness_alpha) * (1 - (1 - 1 / 120) ** frames)
		whiteness.alpha = whiteness_alpha * 255
		sun_whitens(whiteness_alpha)

		// Once he's under, they can't hesitate long.
		var/fail_progress = 0
		if(textind >= WEIRD_ROUTE_DROWN_INDEX)
			fail_limit = 450
			if(textind > 22)
				fail_limit = LERP(150, 30, progress(textind, 23, 40))
			if(textind in list(35, 29, 24, 17, 15))
				fail_limit += 45
			if(writer_busy && state != "end")
				fail_timer += frames
				if(fail_timer >= fail_limit)
					fail()
					return
			else
				fail_timer = 0
			fail_progress = fail_timer / (fail_limit * 0.4)
			whiteout_alpha += (fail_progress - whiteout_alpha) * (1 - (1 - 1 / 30) ** frames)
			whiteout.alpha = clamp(whiteout_alpha, 0, 1) * 255

		// Blurring as they go deeper (the game's blur2): a sideways smear and a soft blur, flickering
		// every other frame somewhere between its base and up to twice that.
		blur += ((actor_x - 940) / (1453 - 940) - blur) * (1 - (1 - 1 / 60) ** frames)
		blur_flicker += frames
		var/atom/movable/plane_master_controller/game = player.hud_used?.plane_master_controllers[PLANE_MASTERS_GAME]
		if(game && blur > 0 && blur_flicker >= 2)
			blur_flicker = 0
			var/base = 3 * (1 - (1 - min(blur, 1)) ** 3) + fail_progress
			var/amount = base + rand() * (base * LERP(1, 2, min(blur, 1)) - base)
			var/smear = amount / 5 * 2
			var/soft = 2 ** (10 * min(amount / 5, 1) - 10) * 2
			if(!game.get_filter("weird_route_blur"))
				game.add_filter("weird_route_blur", 1, motion_blur_filter(smear, 0))
				game.add_filter("weird_route_soften", 2, gauss_blur_filter(soft))
			else
				game.modify_filter("weird_route_blur", list("x" = smear))
				game.modify_filter("weird_route_soften", list("size" = soft))
			blur_box(smear, soft)

		// The chant: rising out of nothing, then deep and loud under the water, then sinking and climbing.
		if(music_started)
			var/base_pitch = 0.4
			var/target_pitch = progress(textind, 0, WEIRD_ROUTE_DROWN_INDEX) * base_pitch
			if(submerged && textind < 17)
				music_pitch = base_pitch
				target_pitch = music_pitch
			if(textind >= 17 && textind < 30)
				music_pitch = base_pitch * 0.98 ** (textind - 16)
				target_pitch = music_pitch
			if(textind >= 30)
				music_pitch = base_pitch * 0.98 ** (30 - 1 - 16) * 1.05 ** (textind - 29)
			music_pitch += (target_pitch - music_pitch) * (1 - (1 - 0.025) ** frames)
			var/target_volume = LERP(0, 0.6, progress(textind, 0, WEIRD_ROUTE_DROWN_INDEX))
			if(submerged)
				target_volume = 3
			if(textind >= WEIRD_ROUTE_END_INDEX - 20)
				target_volume = LERP(3, 0, progress(textind, WEIRD_ROUTE_END_INDEX - 19, WEIRD_ROUTE_END_INDEX))
			music_volume += (target_volume - music_volume) * (1 - (1 - 1 / 30) ** frames)
			if(!submerged && weird_route_submerged(actor_x) >= 1)
				music_volume = 3
				music_pitch = 0.4
				submerged = TRUE
			tune(chant_channel, music_volume, music_pitch)

		// Their breath running out: the screen jolting, faster and faster.
		if(textind >= WEIRD_ROUTE_DROWN_INDEX && state != "end")
			var/drowning = progress(textind, WEIRD_ROUTE_DROWN_INDEX - 1, WEIRD_ROUTE_END_INDEX - 20)
			var/hurt_every = round(LERP(60, 2, drowning))
			var/dampen = 1 - progress(textind, 20, WEIRD_ROUTE_END_INDEX) * 0.9
			hurt_timer += frames
			if(textind >= 28)
				hurt_timer_2 += frames
				if(hurt_timer_2 >= hurt_every)
					hurt_timer_2 = 0
					play_layer("snd_hurt_muffled_2x.wav", LERP(0.3, 0.8, progress(textind, 28, 44)) * dampen, LERP(0.9, 0.3, drowning) + rand() * (LERP(1, 1.2, drowning) - LERP(0.9, 0.3, drowning)))
			if(hurt_timer >= hurt_every)
				hurt_timer = 0
				shake_screen()
				play_layer("snd_hurt_muffled_2x.wav", LERP(0.5, 1, progress(textind, WEIRD_ROUTE_DROWN_INDEX - 1, 44)) * dampen)
			// And static, louder the longer they wait.
			if(!static_started)
				static_started = TRUE
				play_sound("snd_static_loop.wav", 0, 0.7, static_channel, TRUE)
			var/waiting = fail_timer / (fail_limit * 0.4)
			static_pitch += (LERP(0.2, 0.7, 1 - (1 - min(waiting, 1)) ** 3) - static_pitch) * (1 - (1 - 0.125) ** frames)
			static_volume += (LERP(0, 0.7, 1 - (1 - min(waiting, 1)) ** 5) - static_volume) * (1 - (1 - 0.1) ** frames)
			tune(static_channel, static_volume, static_pitch)

		// The text shaking harder.
		text_shake = textind >= WEIRD_ROUTE_DROWN_INDEX ? LERP(0.26, 3, progress(textind, WEIRD_ROUTE_DROWN_INDEX, 34)) : 0
		if(text_shake >= 1)
			var/most = round(text_shake)
			writing.pixel_x = rand(-most, most)
			writing.pixel_y = rand(-most, most)
		else
			writing.pixel_x = 0
			writing.pixel_y = 0
		sleep(world.tick_lag)

/// Blurs the text box with the rest of the screen (its planes aren't the world's), or stops (0, 0).
/datum/weird_route/proc/blur_box(smear, soft)
	for(var/atom/movable/screen/part as anything in list(box, border, portrait, writing, left_option, right_option, heart))
		if(!smear && !soft)
			part.remove_filter(list("weird_route_blur", "weird_route_soften"))
		else if(!part.get_filter("weird_route_blur"))
			part.add_filter("weird_route_blur", 1, motion_blur_filter(smear, 0))
			part.add_filter("weird_route_soften", 2, gauss_blur_filter(soft))
		else
			part.modify_filter("weird_route_blur", list("x" = smear))
			part.modify_filter("weird_route_soften", list("size" = soft))

/// Colours the box as it is now.
/datum/weird_route/proc/colour_box()
	border.color = border_colour
	// Its inside stays black: it's the white over the screen and the blur that take it.
	box.color = COLOR_BLACK
	if(choices)
		update_choices()

/// They hesitated too long: white, going to black, and then he's wrong about it all.
/datum/weird_route/proc/fail()
	stop_writing()
	blur_box(0, 0)
	player.hud_used?.plane_master_controllers[PLANE_MASTERS_GAME]?.remove_filter(list("weird_route_blur", "weird_route_soften"))
	whiteout.alpha = 255
	whiteout.color = COLOR_WHITE
	animate(whiteout, color = COLOR_BLACK, time = 60 * WEIRD_ROUTE_FRAME, easing = CUBIC_EASING | EASE_IN | EASE_OUT)
	WEIRD_ROUTE_WAIT(90)
	stop_sounds()
	// Up over the black, not in the box.
	writing.screen_loc = "WEST:40,NORTH:-170"
	writing.maptext_x = 0
	writing.maptext_y = -92
	writing.maptext_width = 560
	writing.layer = 6
	writing.plane = ABOVE_HUD_PLANE
	write(list(
		"* I was wrong./",
		"* The dream never happened./",
		"* Kris hadn't changed./",
		"* I hadn't changed./",
		"* I had simply^2&gotten carried away./%",
	), "snd_txtnoe.wav", FALSE, 2, null, FALSE)
	qdel(src)

/**
 * They made it all the way in: the game's ending (obj_ch5_LW20W_end). Black, a sound looping, then
 * "INSERT CHAPTER 7" a letter at a time; a pause; and where the game spells out " SIDE B", slower,
 * this spells out where they're really going. Then the Meat Factory, rather than the game restarting.
 */
/datum/weird_route/proc/insert_chapter()
	stop_writing()
	whiteness.alpha = 0
	whiteout.alpha = 0
	blackout.alpha = 255
	blackout.plane = ABOVE_HUD_PLANE
	player.hud_used?.plane_master_controllers[PLANE_MASTERS_GAME]?.remove_filter(list("weird_route_blur", "weird_route_soften"))
	play_sound("snd_next.wav", 100, 0, music_channel, TRUE)
	// The letters, white, with red and blue ghosts of them either side (the game's aberration shader).
	for(var/ghost in list("#ff3030", "#30a0ff", COLOR_WHITE))
		var/atom/movable/screen/weird_route/text/letters = new(null, null, src)
		letters.screen_loc = "CENTER-7:16,NORTH-3"
		letters.plane = ABOVE_HUD_PLANE
		letters.layer = 10
		letters.maptext_x = 0
		letters.maptext_width = 448
		letters.maptext_height = 40
		if(ghost != COLOR_WHITE)
			letters.blend_mode = BLEND_ADD
			letters.pixel_x = ghost == "#ff3030" ? -1 : 1
			// Swimming in and out every four seconds.
			animate(letters, alpha = 0, time = 20, loop = -1, easing = SINE_EASING)
			animate(alpha = 255, time = 20, easing = SINE_EASING)
		letters.color = ghost
		chapter_letters += letters
		player.client?.screen += letters
	var/shown = ""
	var/list/reveal_at = list()
	// "INSERT CHAPTER 7": a letter every third of a second.
	for(var/i in 0 to 15)
		reveal_at += round((i + 1) / 3 * 30)
	// Then, four seconds on, slower.
	for(var/i in 15 to 15 + length(WEIRD_ROUTE_DESTINATION) - 1)
		reveal_at += round((i / 3 * 1.4 + 4) * 30)
	var/full = "INSERT CHAPTER 7" + WEIRD_ROUTE_DESTINATION
	WEIRD_ROUTE_WAIT(151)
	var/timer = 0
	for(var/index in 1 to length(full))
		WEIRD_ROUTE_WAIT(reveal_at[index] - timer)
		timer = reveal_at[index]
		shown = copytext(full, 1, index + 1)
		for(var/atom/movable/screen/weird_route/text/letters as anything in chapter_letters)
			letters.maptext = "<span style='font-family: \"VCR OSD Mono\"; font-size: 18pt; color: #ffffff; text-align: center'>[html_encode(copytext(shown, 1, 17))]<br>[html_encode(copytext(shown, 17))]</span>"
	// Ten seconds of it, then ten more, or until they press something.
	WEIRD_ROUTE_WAIT(300)
	confirm_pressed = FALSE
	var/until = world.time + 10 SECONDS
	while(!confirm_pressed && world.time < until)
		sleep(world.tick_lag)
		if(QDELETED(src))
			return
	stop_sounds()
	for(var/atom/movable/screen/part as anything in chapter_letters)
		player.client?.screen -= part
		qdel(part)
	chapter_letters.Cut()
	blackout.plane = FULLSCREEN_PLANE
	whiteout.color = COLOR_WHITE
	whiteout.alpha = 255
	blackout.alpha = 0
	meat_factory()

/// They come out in the Meat Factory.
/datum/weird_route/proc/meat_factory()
	sun_whitens(0)
	player.hud_used?.plane_master_controllers[PLANE_MASTERS_GAME]?.remove_filter(list("weird_route_blur", "weird_route_soften"))
	blur_box(0, 0)
	var/turf/factory_origin = factory.bottom_left_turfs[1]
	var/turf/arrival = locate(factory_origin.x + round(WEIRD_ROUTE_FACTORY_WIDTH / 2), factory_origin.y + round(WEIRD_ROUTE_FACTORY_HEIGHT / 2), factory_origin.z)
	for(var/mob/living/carbon/human/who as anything in list(player, moffer))
		who.remove_filter("weird_route_sink")
		// Out of the sunset: lit by the white.
		against_sun(who, FALSE)
		who.pixel_w = who.base_pixel_w
		who.limb_rig?.set_seated(null)
		who.limb_rig?.play(list(list(list(), 1)))
		give_shadow(who, EAST, "#9a9a9a")
	player.forceMove(arrival)
	moffer.forceMove(get_step(arrival, EAST))
	player.setDir(SOUTH)
	moffer.setDir(SOUTH)
	camera_x = null
	player.client?.pixel_x = 0
	whiteness.alpha = 0
	text_shake = 0
	inner_white = 0
	border_colour = COLOR_WHITE
	colour_box()
	animate(whiteout, alpha = 0, time = 60 * WEIRD_ROUTE_FRAME)
	play_sound("meat_factory.ogg", 60, 0, music_channel, TRUE)
	// They're free to look around. Nobody comes to get them; an admin can.
	player.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), WEIRD_ROUTE_TRAIT)
	UnregisterSignal(player, COMSIG_MOB_KEYDOWN)
	if(old_hud_version)
		player.hud_used?.show_hud(old_hud_version)
		old_hud_version = null
	// Moffer comes along, a step behind them wherever they go.
	moffer.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), WEIRD_ROUTE_TRAIT)
	walk_to(moffer, player, 1, 3)
