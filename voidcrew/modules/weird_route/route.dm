/// Where the choice's options are centred and the heart starts, in pixels across the text box (the
/// game's choicer: 77.5, 243.5 and 156 of its 320, the box being 16 to 304).
#define WEIRD_ROUTE_LEFT_OPTION 96
#define WEIRD_ROUTE_RIGHT_OPTION 354
#define WEIRD_ROUTE_HEART_START 218
/// How high the middle of the options is in the box: halfway up, as the game has them.
#define WEIRD_ROUTE_OPTION_Y 56
/// How much bigger than its icon the heart's drawn, and where in its icon the heart itself is.
#define WEIRD_ROUTE_HEART_SCALE 2.5
#define WEIRD_ROUTE_HEART_MIDDLE_X 14
#define WEIRD_ROUTE_HEART_MIDDLE_Y 18.5
/// How many pixels of them the sun lights, on its side.
#define WEIRD_ROUTE_SUNLIT 3

/// Trait source for everything the Weird Route holds its player and Moffer to.
#define WEIRD_ROUTE_TRAIT "weird_route"
/// How many times they're asked: the game's endind.
#define WEIRD_ROUTE_END_INDEX 74
/// From which ask Moffer's under: the game's drownindex.
#define WEIRD_ROUTE_DROWN_INDEX 14
/// Where the pair stand when the asking starts, in the game's units (64 to a tile).
#define WEIRD_ROUTE_HANDOFF_X 370

/// Sleeps this many of the game's frames, and gives up if the route ended meanwhile.
#define WEIRD_ROUTE_WAIT(frames) sleep((frames) * WEIRD_ROUTE_FRAME); if(QDELETED(src)) { return }

/// Everyone down the Weird Route right now.
GLOBAL_LIST_EMPTY(weird_routes)

/mob/living/carbon/human
	/// The Weird Route this one's down, if any.
	var/datum/weird_route/weird_route

/**
 * One trip down the Weird Route: its player, Moffer, the lake and (if they make it) the Meat
 * Factory. The scene runs as the game's own does, frame for frame (30 to a second), with Moffer's
 * lines in Noelle's place and the player's name in Kris's.
 */
/datum/weird_route
	var/mob/living/carbon/human/player
	var/mob/living/carbon/human/moffer
	/// Where the player was, to go back to.
	var/turf/came_from
	var/datum/turf_reservation/lake
	var/datum/turf_reservation/factory
	/// The lake's bottom left turf (the game's x of 0 is WEIRD_ROUTE_LAKE_LEFT tiles east of it).
	var/turf/origin
	/// Where each of them is along the path, in the game's units, by mob.
	var/list/positions = list()
	/// Each of them against the sun, by mob (see /obj/effect/abstract/weird_route_silo).
	var/list/silos = list()
	/// Where the camera's centred, in the game's units, or null to follow the player.
	var/camera_x
	var/old_hud_version

	// The screen.
	var/atom/movable/screen/weird_route/box/box
	var/atom/movable/screen/weird_route/box/border/border
	var/atom/movable/screen/weird_route/box/portrait/portrait
	var/atom/movable/screen/weird_route/text/writing
	var/atom/movable/screen/weird_route/text/option/left_option
	var/atom/movable/screen/weird_route/text/option/right_option
	var/atom/movable/screen/weird_route/heart/heart
	/// All black, over everything but the box.
	var/atom/movable/screen/weird_route/fill/blackout
	/// The ominous fade while he remembers yesterday: the world going dark behind them but for a soft
	/// patch up top, three times over, breathing.
	var/list/atom/movable/screen/weird_route/pinwheel/clouds = list()
	/// Whether the clouds are out (the game's fadecon: 1 while they are, 2 once they've gone).
	var/clouds_state = 0
	/// White over everything when they've hesitated too long.
	var/atom/movable/screen/weird_route/fill/whiteout
	/// White behind the two of them, taking the lake away.
	var/atom/movable/screen/weird_route/fill/behind/whiteness
	/// The pinwheel (the game's _rotate_vfx): three places from life aboard, each showing through its
	/// own third of a turning wheel, over black, a silhouette of Moffer kneeling in the middle.
	var/list/atom/movable/screen/weird_route/pinwheel/memories = list()
	/// The wedges the memories show through, by memory: each one's mask (a render target).
	var/list/atom/movable/screen/weird_route/pinwheel/wedges = list()
	/// Black behind it all, under the two of them.
	var/atom/movable/screen/weird_route/fill/behind/void
	/// Moffer kneeling, a silhouette in the middle of it: a Moffer of its own, kept nowhere.
	var/atom/movable/screen/weird_route/pinwheel/silhouette
	var/mob/living/carbon/human/vision
	/// Whether it's going, and turning.
	var/pinwheel_on = FALSE
	var/pinwheel_turning = FALSE
	var/pinwheel_slowing = FALSE
	var/pinwheel_angle = 270
	/// How many degrees a frame it turns by, and how fast its ripples grow.
	var/pinwheel_turn_speed = 0
	var/pinwheel_wave_speed = 0
	var/pinwheel_wave = 0
	/// How many of the memories are fading in.
	var/pinwheel_segments = 0
	/// The ending's letters and their coloured ghosts.
	var/list/atom/movable/screen/weird_route/text/chapter_letters = list()

	// The writer.
	/// Whether a message is being typed out, waited on, or chosen from.
	var/writer_busy = FALSE
	/// Bumped to stop whatever's being typed.
	var/writer_token = 0
	var/confirm_pressed = FALSE
	var/list/choices
	/// The option the heart's beside, 1 or 2, or 0 before either's been picked (it starts between them).
	var/selected = 0
	/// Where the heart is across the box, and where it's gliding to.
	var/heart_at = WEIRD_ROUTE_HEART_START
	var/heart_target = WEIRD_ROUTE_HEART_START
	/// The option chosen, or 0 while it's not.
	var/chosen = 0
	/// How far the text jitters, in pixels.
	var/text_shake = 0
	/// Whether the voice wavers.
	var/voice_waver = FALSE
	var/border_colour = COLOR_WHITE
	/// How far the box's inside has gone from black to white, 0 to 1.
	var/inner_white = 0
	var/highlight_colour = COLOR_YELLOW

	// The sound.
	var/music_channel
	var/chant_channel
	var/static_channel

/datum/weird_route/New(mob/living/carbon/human/player)
	. = ..()
	if(!player?.client)
		qdel(src)
		return
	src.player = player
	player.weird_route = src
	GLOB.weird_routes += src
	RegisterSignals(player, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT, COMSIG_LIVING_DEATH), PROC_REF(on_lost))
	INVOKE_ASYNC(src, PROC_REF(prepare))

/// Builds both places first (the Meat Factory takes a while), and only then takes them to the lake.
/datum/weird_route/proc/prepare()
	var/datum/turf_reservation/built_factory = weird_route_build_factory()
	var/datum/turf_reservation/built_lake = built_factory && weird_route_build_lake()
	if(QDELETED(src))
		qdel(built_factory)
		qdel(built_lake)
		return
	factory = built_factory
	lake = built_lake
	if(!lake || !player?.client)
		message_admins("The Weird Route couldn't take [key_name_admin(player)]: [lake ? "they've gone" : "there's no room for it"].")
		qdel(src)
		return
	message_admins("The Weird Route's ready: [key_name_admin(player)]'s at the lake.")
	origin = lake.bottom_left_turfs[1]
	came_from = get_turf(player)
	music_channel = SSsounds.reserve_sound_channel(src)
	chant_channel = SSsounds.reserve_sound_channel(src)
	static_channel = SSsounds.reserve_sound_channel(src)
	moffer = make_moffer()
	hold(player)
	RegisterSignal(player, COMSIG_MOB_KEYDOWN, PROC_REF(on_key))
	if(player.hud_used)
		old_hud_version = player.hud_used.hud_version
		player.hud_used.show_hud(HUD_STYLE_NOHUD)
	make_screen()
	play_scene()

/datum/weird_route/Destroy()
	GLOB.weird_routes -= src
	writer_token++
	QDEL_LIST_ASSOC_VAL(silos)
	sun_whitens(0)
	if(player)
		UnregisterSignal(player, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT, COMSIG_LIVING_DEATH))
	// Only once they've been taken (until then it's still building).
	if(player && came_from)
		UnregisterSignal(player, COMSIG_MOB_KEYDOWN)
		let_go(player)
		for(var/channel in list(music_channel, chant_channel, static_channel))
			SEND_SOUND(player, sound(null, channel = channel))
		if(player.client)
			player.client.screen -= get_screen()
			player.client.pixel_x = 0
			player.client.pixel_y = 0
		if(old_hud_version)
			player.hud_used?.show_hud(old_hud_version)
		player.hud_used?.plane_master_controllers[PLANE_MASTERS_GAME]?.remove_filter(list("weird_route_blur", "weird_route_soften"))
		if(!QDELETED(player))
			player.forceMove(came_from)
	if(player)
		player.weird_route = null
	player = null
	if(moffer)
		walk(moffer, 0)
	QDEL_NULL(moffer)
	QDEL_NULL(vision)
	for(var/atom/movable/screen/part as anything in get_screen())
		qdel(part)
	SSsounds.free_datum_channels(src)
	// Giving the ground back deletes whatever's on it: anyone who followed them in goes back too.
	var/turf/way_out = came_from || get_safe_random_station_turf()
	for(var/datum/turf_reservation/place as anything in list(lake, factory))
		for(var/turf/spot as anything in place?.reserved_turfs)
			for(var/mob/left in spot)
				left.forceMove(way_out)
	QDEL_NULL(lake)
	QDEL_NULL(factory)
	return ..()

/datum/weird_route/proc/on_lost(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Holds someone to the scene: nowhere to go, nothing in their hands, nothing to hurt them.
/datum/weird_route/proc/hold(mob/living/carbon/human/who)
	who.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_GODMODE), WEIRD_ROUTE_TRAIT)

/datum/weird_route/proc/let_go(mob/living/carbon/human/who)
	who.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_GODMODE), WEIRD_ROUTE_TRAIT)
	who.remove_filter("weird_route_sink")
	who.underlays.Cut()
	who.pixel_w = who.base_pixel_w
	who.pixel_z = who.base_pixel_z
	who.limb_rig?.set_seated(null)

/**
 * Someone against the sun, low over the far side of the lake (the game's "silo" sprites): dark red
 * all over but for the few pixels on the sun's side, which it lights as they are. Drawn over them,
 * as a copy of them with a dark copy of them laid in on top, shifted away from the sun.
 */
/obj/effect/abstract/weird_route_silo
	appearance_flags = KEEP_TOGETHER | PIXEL_SCALE
	layer = MOB_LAYER + 0.01
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/obj/effect/abstract/weird_route_silo/shade/shade

/obj/effect/abstract/weird_route_silo/Initialize(mapload, mob/living/who)
	. = ..()
	if(!who)
		return
	shade = new(null)
	shade.vis_contents += who
	vis_contents += list(who, shade)

/obj/effect/abstract/weird_route_silo/Destroy()
	vis_contents.Cut()
	QDEL_NULL(shade)
	return ..()

/// The dark copy: only drawn where they are.
/obj/effect/abstract/weird_route_silo/shade
	blend_mode = BLEND_INSET_OVERLAY
	vis_flags = VIS_INHERIT_PLANE
	layer = MOB_LAYER + 0.02
	pixel_w = -WEIRD_ROUTE_SUNLIT

/obj/effect/abstract/weird_route_silo/shade/Initialize(mapload, mob/living/who)
	. = ..()
	// The game's silhouettes' dark red, a little of what's underneath showing through.
	add_filter("weird_route_silo", 1, color_matrix_filter(list(0.06, 0.02, 0.01, 0.04, 0.02, 0.01, 0.02, 0.01, 0.01, 0.24, 0.05, 0.03)))

/// Puts someone against the sun, or (dark FALSE) back in the light.
/datum/weird_route/proc/against_sun(mob/living/who, dark)
	qdel(silos[who])
	silos -= who
	if(dark)
		silos[who] = new /obj/effect/abstract/weird_route_silo(get_turf(who), who)

/// The lake's light going from the sunset's to white with the white behind them, 0 to 1.
/datum/weird_route/proc/sun_whitens(amount)
	var/area/lake_area = origin && get_area(origin)
	lake_area?.set_base_lighting(weird_route_blend("#ffb486", COLOR_WHITE, round(amount, 1 / 32)))

/// Moffer, in Noelle's place: a bald moth, as he is aboard.
/datum/weird_route/proc/make_moffer()
	var/mob/living/carbon/human/npc = new(origin)
	npc.dna.features[FEATURE_MOTH_WINGS] = "Deathshead"
	npc.dna.features[FEATURE_MOTH_ANTENNAE] = "Deathshead"
	npc.dna.features[FEATURE_MOTH_MARKINGS] = "Deathshead"
	npc.set_species(/datum/species/moth)
	npc.gender = MALE
	npc.physique = MALE
	npc.age = 27
	npc.fully_replace_character_name(npc.real_name, "Moffer")
	npc.set_hairstyle("Bald", update = FALSE)
	npc.set_facial_hairstyle("Shaved", update = FALSE)
	npc.set_eye_color("#554422")
	npc.update_body(is_creating = TRUE)
	npc.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(npc), ITEM_SLOT_ICLOTHING)
	npc.equip_to_slot_or_del(new /obj/item/clothing/shoes/sneakers/black(npc), ITEM_SLOT_FEET)
	if(!npc.dna.species.limb_rig_shape?["always"])
		npc.add_quirk(/datum/quirk/overanimated)
	hold(npc)
	return npc

/datum/weird_route/proc/get_screen()
	. = list()
	for(var/atom/movable/screen/part as anything in list(box, border, portrait, writing, left_option, right_option, heart, blackout, whiteout, whiteness, void, silhouette) + clouds + memories + wedges + chapter_letters)
		if(part)
			. += part

/datum/weird_route/proc/make_screen()
	box = new(null, null, src)
	border = new(null, null, src)
	portrait = new(null, null, src)
	writing = new(null, null, src)
	left_option = new(null, null, src)
	left_option.index = 1
	left_option.maptext_x = WEIRD_ROUTE_LEFT_OPTION - 70
	right_option = new(null, null, src)
	right_option.index = 2
	right_option.maptext_x = WEIRD_ROUTE_RIGHT_OPTION - 70
	heart = new(null, null, src)
	blackout = new(null, null, src)
	blackout.color = COLOR_BLACK
	whiteout = new(null, null, src)
	// Over the box as well: hesitating whites all of it out.
	whiteout.plane = ABOVE_HUD_PLANE
	whiteness = new(null, null, src)
	for(var/number in 1 to 3)
		var/atom/movable/screen/weird_route/pinwheel/cloud = new(null, null, src)
		cloud.icon = 'voidcrew/modules/weird_route/icons/weird_route_fade.dmi'
		cloud.icon_state = "fade"
		// Small, inside the view, and scaled up (see /datum/weird_route/proc/shape_clouds()).
		cloud.screen_loc = "CENTER,CENTER"
		clouds += cloud
		var/atom/movable/screen/weird_route/pinwheel/wedge = new(null, null, src)
		wedge.icon_state = "wedge"
		wedge.alpha = 255
		wedge.render_target = "*weird_route_wedge_[number]"
		wedges += wedge
		var/atom/movable/screen/weird_route/pinwheel/place = new(null, null, src)
		place.icon_state = "memory[number]"
		place.add_filter("weird_route_wedge", 1, alpha_mask_filter(render_source = "*weird_route_wedge_[number]"))
		memories += place
	void = new(null, null, src)
	void.color = COLOR_BLACK
	void.layer = MOB_LAYER - 0.35
	silhouette = new(null, null, src)
	silhouette.icon = null
	silhouette.screen_loc = "CENTER,CENTER:28"
	silhouette.layer = MOB_LAYER - 0.25
	silhouette.appearance_flags |= KEEP_TOGETHER
	silhouette.add_filter("weird_route_silhouette", 1, color_matrix_filter(list(0, 0, 0, 0, 0, 0, 0, 0, 0, 0.35, 0.9, 1)))
	show_box(FALSE)
	show_choices(FALSE)
	player.client.screen += get_screen()

// Input.

/datum/weird_route/proc/on_key(mob/source, key, client/user, full_key)
	SIGNAL_HANDLER
	var/direction = user?.movement_keys[key]
	if(choices && (direction == WEST || direction == EAST))
		var/now = direction == WEST ? 1 : 2
		if(now != selected)
			selected = now
			play_sound("snd_menumove.wav")
			update_choices()
		return
	if(uppertext(key) in list("Z", "SPACE", "RETURN", "ENTER"))
		confirm()

/// A confirm press: moves the text on, or takes the picked option.
/datum/weird_route/proc/confirm()
	if(choices)
		if(selected)
			choose(selected)
		return
	confirm_pressed = TRUE

/datum/weird_route/proc/choose(index)
	if(!choices || chosen)
		return
	selected = index
	chosen = index
	play_sound("snd_select.wav")

// Sound.

/// Plays one of the route's sounds to its player, if it's there (see WEIRD_ROUTE_SOUNDS).
/datum/weird_route/proc/play_sound(name, volume = 100, frequency = 0, channel = 0, repeat = FALSE)
	if(!player || !fexists(WEIRD_ROUTE_SOUNDS + name))
		return
	var/sound/played = sound(file(WEIRD_ROUTE_SOUNDS + name), repeat = repeat, channel = channel, volume = volume)
	played.frequency = frequency
	SEND_SOUND(player, played)

/// Changes how loud and how fast a looping sound plays. Volume's the game's (1 is as made, 3 the loudest).
/datum/weird_route/proc/tune(channel, volume, pitch)
	// Only the looping sounds are tuned: an update without repeat would stop them looping.
	var/sound/update = sound(null, repeat = TRUE, channel = channel, volume = clamp(volume * 40, 0, 100))
	update.frequency = max(pitch, 0.05)
	update.status = SOUND_UPDATE
	SEND_SOUND(player, update)

/datum/weird_route/proc/stop_sounds()
	for(var/channel in list(music_channel, chant_channel, static_channel))
		SEND_SOUND(player, sound(null, channel = channel))

// Where they stand, and the camera.

/// Puts someone at x along the path, in the game's units (see WEIRD_ROUTE_SCALE).
/datum/weird_route/proc/put(mob/living/who, x, row = WEIRD_ROUTE_LAKE_ROW)
	positions[who] = x
	var/pixels = x * WEIRD_ROUTE_SCALE
	var/turf/spot = locate(origin.x + WEIRD_ROUTE_LAKE_LEFT + floor(pixels / 32), origin.y + row - 1, origin.z)
	if(spot && who.loc != spot)
		who.forceMove(spot)
	var/obj/effect/abstract/weird_route_silo/silo = silos[who]
	if(spot && silo && silo.loc != spot)
		silo.forceMove(spot)
	who.pixel_w = who.base_pixel_w + pixels - floor(pixels / 32) * 32 - 16
	if(who == player)
		update_camera()

/// Walks someone to x over this many frames (without waiting, unless wait).
/datum/weird_route/proc/walk_along(mob/living/who, to_x, frames, wait = FALSE)
	if(!wait)
		INVOKE_ASYNC(src, PROC_REF(walk_along), who, to_x, frames, TRUE)
		return
	var/from_x = positions[who]
	var/started = world.time
	var/took = frames * WEIRD_ROUTE_FRAME
	while(world.time < started + took)
		put(who, from_x + (to_x - from_x) * (world.time - started) / took)
		sleep(world.tick_lag)
		if(QDELETED(src) || QDELETED(who))
			return
	put(who, to_x)

/// Pans the camera to centre on x over this many frames.
/datum/weird_route/proc/pan(to_x, frames)
	set waitfor = FALSE
	var/from_x = isnull(camera_x) ? positions[player] : camera_x
	var/started = world.time
	var/took = max(frames * WEIRD_ROUTE_FRAME, world.tick_lag)
	while(world.time < started + took)
		camera_x = from_x + (to_x - from_x) * (world.time - started) / took
		update_camera()
		sleep(world.tick_lag)
		if(QDELETED(src))
			return
	camera_x = to_x
	update_camera()

/datum/weird_route/proc/update_camera()
	var/client/viewer = player?.client
	if(!viewer || !origin)
		return
	var/centre = isnull(camera_x) ? positions[player] : camera_x
	viewer.pixel_x = round(centre * WEIRD_ROUTE_SCALE - ((player.x - origin.x - WEIRD_ROUTE_LAKE_LEFT) * 32 + 16))

/// The screen shaking, up and down (the pans have the sideways).
/datum/weird_route/proc/shake_screen()
	var/client/viewer = player?.client
	if(!viewer)
		return
	animate(viewer, pixel_y = rand(-4, 4), time = 0.5)
	animate(pixel_y = rand(-3, 3), time = 0.5)
	animate(pixel_y = 0, time = 0.5)

/// A long shadow behind someone, the sun low over the water (the game's sunset shadows: 62 of its
/// pixels, dark red-brown), or in the Meat Factory off the white. Length in the game's pixels.
/datum/weird_route/proc/give_shadow(mob/living/who, toward = WEST, colour = "#490b01", shadow_length = 62)
	who.underlays.Cut()
	if(shadow_length <= 0)
		return
	var/image/shadow = image('voidcrew/modules/weird_route/icons/weird_route.dmi', "shadow")
	var/pixels = shadow_length * WEIRD_ROUTE_SCALE
	var/matrix/stretch = matrix()
	stretch.Scale(pixels / 32, 1)
	// From their back foot, out the way the sun throws it.
	stretch.Translate((toward == WEST ? -1 : 1) * (pixels / 2 - 4), 0)
	shadow.transform = stretch
	shadow.pixel_z = 1
	shadow.color = colour
	shadow.appearance_flags = RESET_COLOR | RESET_TRANSFORM | KEEP_APART
	who.underlays += shadow

/// A pose for Moffer or the player (see /proc/weird_route_pose()), eased into over this many frames.
/datum/weird_route/proc/pose(mob/living/carbon/who, kind, frames = 8)
	if(!who?.limb_rig)
		return
	who.limb_rig.set_seated(kind == "kneel" || kind == "kneel_head_down" || kind == "kneel_head_up" || kind == "fall" ? "crouch" : null)
	who.limb_rig.play(list(list(weird_route_pose(kind), max(frames * WEIRD_ROUTE_FRAME, 0.5), SINE_EASING)), settle_after = FALSE)

/// Shakes someone where they stand, a few times.
/datum/weird_route/proc/shake(mob/living/who)
	var/home = who.pixel_w
	animate(who, pixel_w = home + 2, time = 0.5)
	for(var/i in 1 to 3)
		animate(pixel_w = home - 2, time = 0.5)
		animate(pixel_w = home + 2, time = 0.5)
	animate(pixel_w = home, time = 0.5)

/**
 * The poses standing in for Noelle's and Kris's sprites in this scene ("spr_noelle_silo_..."): the
 * names are theirs, without the prefix.
 */
/proc/weird_route_pose(kind)
	. = list()
	switch(kind)
		if("head_down")
			.[RIG_HEAD] = list("nod" = 28)
		if("up_head_tilt")
			.[RIG_HEAD] = list("nod" = -18, "tilt" = 12)
		if("up")
			.[RIG_HEAD] = list("nod" = -25)
		if("exasperated")
			.[RIG_CHEST] = list("bend" = -8)
			.[RIG_HEAD] = list("nod" = -10)
			.[RIG_L_ARM] = list("swing" = 50, "raise" = 45, "elbow" = 25)
			.[RIG_R_ARM] = list("swing" = 50, "raise" = 45, "elbow" = 25)
		if("hands_to_chest", "hands_to_chest_head_down", "hands_to_chest_head_down_more", "hands_to_chest_turn_head", "hands_to_chest_turn_up")
			.[RIG_L_ARM] = list("swing" = 35, "raise" = 15, "elbow" = 120)
			.[RIG_R_ARM] = list("swing" = 35, "raise" = 15, "elbow" = 120)
			switch(kind)
				if("hands_to_chest_head_down")
					.[RIG_HEAD] = list("nod" = 22)
				if("hands_to_chest_head_down_more")
					.[RIG_HEAD] = list("nod" = 34)
					.[RIG_CHEST] = list("bend" = 10)
				if("hands_to_chest_turn_head")
					.[RIG_HEAD] = list("nod" = 10, "tilt" = 10)
				if("hands_to_chest_turn_up")
					.[RIG_HEAD] = list("nod" = -20)
		if("hands_to_side")
			.[RIG_L_ARM] = list("swing" = -10, "raise" = 35)
			.[RIG_R_ARM] = list("swing" = -10, "raise" = 35)
		if("walk_left_hands_up")
			.[RIG_L_ARM] = list("swing" = 120, "raise" = 15, "elbow" = 20)
			.[RIG_R_ARM] = list("swing" = 120, "raise" = 15, "elbow" = 20)
		if("fall")
			.[RIG_CHEST] = list("bend" = 30)
			.[RIG_HEAD] = list("nod" = 30)
			.[RIG_L_ARM] = list("swing" = 20, "raise" = 10)
			.[RIG_R_ARM] = list("swing" = 20, "raise" = 10)
		if("kneel", "kneel_head_down")
			.[RIG_HEAD] = list("nod" = 26)
			.[RIG_L_ARM] = list("swing" = 15, "raise" = 10)
			.[RIG_R_ARM] = list("swing" = 15, "raise" = 10)
		if("kneel_head_up")
			.[RIG_HEAD] = list("nod" = -12)
		if("take_hands")
			.[RIG_L_ARM] = list("swing" = 70, "raise" = 5, "elbow" = 10)
			.[RIG_R_ARM] = list("swing" = 70, "raise" = 5, "elbow" = 10)
		// Leading, a hand held out behind for the one following.
		if("lead")
			.[RIG_L_ARM] = list("swing" = -45, "raise" = 10)
			.[RIG_R_ARM] = list("swing" = -45, "raise" = 10)
		// Following, a hand held out ahead.
		if("follow")
			.[RIG_L_ARM] = list("swing" = 45, "raise" = 10)
			.[RIG_R_ARM] = list("swing" = 45, "raise" = 10)

// The writer.

/// The player's first name, for Kris's.
/datum/weird_route/proc/get_kris()
	return first_name(player?.real_name) || "Kris"

/datum/weird_route/proc/show_box(shown, with_portrait = FALSE)
	box.alpha = shown ? 255 : 0
	border.alpha = shown ? 255 : 0
	portrait.alpha = shown && with_portrait ? 255 : 0
	writing.maptext_x = with_portrait ? 112 : 18
	writing.maptext_width = with_portrait ? 322 : 410
	if(!shown)
		writing.maptext = null

/datum/weird_route/proc/show_choices(shown)
	left_option.alpha = shown ? 255 : 0
	right_option.alpha = shown ? 255 : 0
	heart.alpha = shown ? 255 : 0
	if(shown)
		// Each time, between the two.
		heart_at = WEIRD_ROUTE_HEART_START
		heart_target = WEIRD_ROUTE_HEART_START
		place_heart()
		update_choices()

/datum/weird_route/proc/update_choices()
	if(!choices)
		return
	left_option.maptext = weird_route_text(choices[1], selected == 1 ? highlight_colour : COLOR_WHITE, TRUE)
	right_option.maptext = weird_route_text(choices[2], selected == 2 ? highlight_colour : COLOR_WHITE, TRUE)
	// Beside the picked option's text, or between the two until one is; gliding over.
	var/target = WEIRD_ROUTE_HEART_START
	if(selected)
		var/centre = selected == 1 ? WEIRD_ROUTE_LEFT_OPTION : WEIRD_ROUTE_RIGHT_OPTION
		target = centre - length(choices[selected]) * 5 - 24
	if(target == heart_target && heart_at == target)
		return
	var/already_gliding = heart_at != heart_target
	heart_target = target
	if(!already_gliding)
		INVOKE_ASYNC(src, PROC_REF(glide_heart))

/// Moves the heart most of the way to where it's going each frame, until it's there.
/datum/weird_route/proc/glide_heart()
	while(heart_at != heart_target && !QDELETED(src))
		heart_at += (heart_target - heart_at) * 0.5
		if(abs(heart_target - heart_at) < 1)
			heart_at = heart_target
		place_heart()
		sleep(WEIRD_ROUTE_FRAME)

/datum/weird_route/proc/place_heart()
	// Scaled about its icon's middle, which isn't the heart's.
	var/offset_x = round(heart_at - 16 - (WEIRD_ROUTE_HEART_MIDDLE_X - 16) * WEIRD_ROUTE_HEART_SCALE)
	var/offset_y = round(WEIRD_ROUTE_OPTION_Y - 16 - (WEIRD_ROUTE_HEART_MIDDLE_Y - 16) * WEIRD_ROUTE_HEART_SCALE)
	heart.screen_loc = "CENTER-7:[16 + offset_x],SOUTH:[6 + offset_y]"

/// The text's colour. White, always, as the game's text style 63 is: even once the box has gone white.
/datum/weird_route/proc/text_colour()
	return COLOR_WHITE

/// One colour going over to another, 0 to 1 of the way: the game's merge_color().
/proc/weird_route_blend(from, target, amount)
	var/list/a = rgb2num(from)
	var/list/b = rgb2num(target)
	amount = clamp(amount, 0, 1)
	return rgb(a[1] + (b[1] - a[1]) * amount, a[2] + (b[2] - a[2]) * amount, a[3] + (b[3] - a[3]) * amount)

/// Some text in the box's font.
/proc/weird_route_text(message, colour, centred = FALSE)
	return "<span style='font-family: \"Pixellari\"; font-size: 16pt; line-height: 1.3; vertical-align: top; color: [colour];[centred ? " text-align: center;" : ""]'>[message]</span>"

/**
 * Types out messages in the box, one at a time, each waiting on a press: lines are the game's own,
 * with "^1" a pause, "&" a new line, and a trailing "/" or "/%". A callback among them runs when the
 * box gets to it (the game's c_wait_box()). With choices (two options), the last message waits on a
 * choice instead, and chosen is set. Out of the box (in_box FALSE), the text's wherever it's been put.
 *
 * * voice - "snd_txtnoe.wav" for Moffer (his own snd_moffer.ogg if it's there), "snd_text.wav" for
 *   nobody in particular
 * * rate - frames a letter: this scene's is 2 (its slow text, and text style 63), 4 slower still
 */
/datum/weird_route/proc/write(list/lines, voice = "snd_txtnoe.wav", with_portrait = FALSE, rate = 2, list/choice_options, in_box = TRUE)
	var/token = ++writer_token
	writer_busy = TRUE
	// Moffer's own voice, if it's there (the Minecraft port's proceed_text), else Noelle's.
	if(voice == "snd_txtnoe.wav" && fexists(WEIRD_ROUTE_SOUNDS + "snd_moffer.ogg"))
		voice = "snd_moffer.ogg"
	chosen = 0
	selected = 0
	if(in_box)
		show_box(TRUE, with_portrait)
	var/list/entries = lines.Copy()
	var/messages = 0
	for(var/entry in entries)
		if(!istype(entry, /datum/callback))
			messages++
	if(!messages && choice_options)
		entries += ""
		messages = 1
	var/typed = 0
	for(var/entry in entries)
		if(istype(entry, /datum/callback))
			var/datum/callback/at_box = entry
			at_box.Invoke()
			continue
		typed++
		type_message(entry, voice, rate, token)
		if(token != writer_token)
			return
		if(choice_options && typed == messages)
			// Once the choice is up, it's all there is in the box: the two options and the heart.
			writing.maptext = null
			portrait.alpha = 0
			choices = choice_options
			show_choices(TRUE)
			while(!chosen)
				sleep(world.tick_lag)
				if(token != writer_token)
					return
			choices = null
			show_choices(FALSE)
		else
			confirm_pressed = FALSE
			while(!confirm_pressed)
				sleep(world.tick_lag)
				if(token != writer_token)
					return
	if(in_box)
		show_box(FALSE)
	writer_busy = FALSE

/// Types one message out, a letter at a time with the voice.
/datum/weird_route/proc/type_message(message, voice, rate, token)
	message = replacetext(message, "/%", "")
	message = replacetext(message, "/", "")
	message = replacetext(message, "%", "")
	message = replacetext(message, "Kris", get_kris())
	message = replacetext(message, "Noelle", "Moffer")
	var/shown = ""
	var/owed = 0
	var/last_voice = 0
	var/message_length = length(message)
	var/index = 1
	while(index <= message_length)
		var/letter = message[index]
		index++
		if(letter == "^" && index <= message_length && text2num(message[index]))
			owed += text2num(message[index]) * 10 * WEIRD_ROUTE_FRAME
			index++
			continue
		if(letter == "&")
			shown += "<br>"
			continue
		shown += html_encode(letter)
		owed += rate * WEIRD_ROUTE_FRAME
		if(!(letter in list(" ", ".", ",", "!", "?", "*", "(", ")", "\"")) && world.time > last_voice)
			last_voice = world.time
			play_sound(voice, 60, voice_waver ? 0.8 + rand() * 0.4 : 0)
		if(owed >= world.tick_lag)
			writing.maptext = weird_route_text(shown, text_colour())
			sleep(owed)
			owed = 0
			if(token != writer_token)
				return
	writing.maptext = weird_route_text(shown, text_colour())

/// Stops whatever's being typed or chosen, and puts the box away.
/datum/weird_route/proc/stop_writing()
	writer_token++
	writer_busy = FALSE
	choices = null
	show_choices(FALSE)
	show_box(FALSE)

/// Writes and waits for it to finish: the game's c_talk_wait().
/datum/weird_route/proc/say(list/lines, voice = "snd_txtnoe.wav", rate = 2, face = FALSE)
	write(lines, voice, face, rate)
