/// Everything a rhythm battle draws over the stage. It sits above the lighting, so a battle in
/// a dark corridor can still be played.
/obj/effect/abstract/fnf_hud
	name = ""
	icon = 'voidcrew/modules/fnf/icons/fnf.dmi'
	icon_state = null
	plane = ABOVE_LIGHTING_PLANE
	layer = ABOVE_ALL_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = RESET_COLOR|RESET_TRANSFORM|RESET_ALPHA|PIXEL_SCALE|KEEP_APART
	vis_flags = VIS_INHERIT_PLANE

/obj/effect/abstract/fnf_hud/text
	maptext_width = 160
	maptext_height = 32
	maptext_x = -64

/**
 * The health bar, strung between the two singers: the opponent's colour from the left, the
 * challenger's from the right, meeting where the battle stands.
 */
/obj/effect/abstract/fnf_hud/healthbar
	/// Where the middle of the bar is, in pixels from this tile's bottom left.
	var/center_x = 16
	var/center_y = 16
	var/obj/effect/abstract/fnf_hud/frame
	var/obj/effect/abstract/fnf_hud/left_bar
	var/obj/effect/abstract/fnf_hud/right_bar
	/// The singers' heads, facing each other on either side of where the colours meet.
	var/obj/effect/abstract/fnf_hud/portrait/left_portrait
	var/obj/effect/abstract/fnf_hud/portrait/right_portrait
	/// Big text in the middle, for the countdown.
	var/obj/effect/abstract/fnf_hud/text/announcer
	/// A frame of the song's own instead of the plain one (see set_frame()), and the colours filling
	/// its opening, the challenger's cut off where the colours meet.
	var/obj/effect/abstract/fnf_hud/shaped_frame
	var/obj/effect/abstract/fnf_hud/shaped_left
	var/obj/effect/abstract/fnf_hud/shaped_right
	/// The health it was last shown at.
	var/shown_health = FNF_HEALTH_MAX / 2
	/// Colours the heads are drawn in for now (silhouettes, while the song blacks the stage out),
	/// list(left, right), each a colour or colour matrix; null for their own.
	var/list/portrait_tints

/obj/effect/abstract/fnf_hud/healthbar/Initialize(mapload, center_x, center_y, mob/living/left_mob, mob/living/right_mob)
	. = ..()
	src.center_x = center_x
	src.center_y = center_y
	frame = make_bar("#000000", FNF_BAR_WIDTH + 4, FNF_BAR_HEIGHT + 4, 0.01)
	left_bar = make_bar("#e0453a", FNF_BAR_WIDTH, FNF_BAR_HEIGHT, 0.02)
	right_bar = make_bar("#5de83a", FNF_BAR_WIDTH, FNF_BAR_HEIGHT, 0.03)
	announcer = new
	announcer.layer = ABOVE_ALL_MOB_LAYER + 0.05
	announcer.pixel_w = center_x - 16
	announcer.pixel_z = center_y + 8
	vis_contents += announcer
	if(left_mob)
		left_portrait = new(null, left_mob, EAST)
		vis_contents += left_portrait
	if(right_mob)
		right_portrait = new(null, right_mob, WEST)
		vis_contents += right_portrait
	update(FNF_HEALTH_MAX / 2, instant = TRUE)

/obj/effect/abstract/fnf_hud/healthbar/Destroy()
	vis_contents.Cut()
	QDEL_NULL(frame)
	QDEL_NULL(left_bar)
	QDEL_NULL(right_bar)
	QDEL_NULL(left_portrait)
	QDEL_NULL(right_portrait)
	QDEL_NULL(announcer)
	QDEL_NULL(shaped_frame)
	QDEL_NULL(shaped_left)
	QDEL_NULL(shaped_right)
	return ..()

/obj/effect/abstract/fnf_hud/healthbar/proc/make_bar(colour, width, height, layer_offset)
	var/obj/effect/abstract/fnf_hud/bar = new
	bar.icon_state = "bar"
	bar.color = colour
	bar.layer = ABOVE_ALL_MOB_LAYER + layer_offset
	bar.pixel_w = center_x - 16
	bar.pixel_z = center_y - 16
	bar.transform = matrix(width / 32, 0, 0, 0, height / 32, 0)
	vis_contents += bar
	return bar

/**
 * Puts the bar in a frame of its own (Corruption+'s tainted one), the plain one gone: an icon of
 * FNF_HUD_FRAME_WIDTH by 32 pixels, centred on the bar, with states "frame", "hole" (its opening,
 * which the colours fill, whatever its shape) and "block" (solid, to cut the challenger's colour off
 * with). The singers' heads stay in front of it.
 */
/obj/effect/abstract/fnf_hud/healthbar/proc/set_frame(frame_icon)
	for(var/obj/effect/abstract/fnf_hud/plain as anything in list(frame, left_bar, right_bar))
		plain.alpha = 0
	shaped_left = make_shaped(frame_icon, "hole", left_bar.color, 0.02)
	shaped_right = make_shaped(frame_icon, "hole", right_bar.color, 0.03)
	shaped_right.add_filter("split", 1, alpha_mask_filter(icon = icon(frame_icon, "block")))
	shaped_frame = make_shaped(frame_icon, "frame", null, 0.035)
	update(shown_health, instant = TRUE)

/obj/effect/abstract/fnf_hud/healthbar/proc/make_shaped(frame_icon, state, colour, layer_offset)
	var/obj/effect/abstract/fnf_hud/shaped = new
	shaped.icon = frame_icon
	shaped.icon_state = state
	shaped.color = colour
	shaped.layer = ABOVE_ALL_MOB_LAYER + layer_offset
	shaped.pixel_w = center_x - FNF_HUD_FRAME_WIDTH / 2
	shaped.pixel_z = center_y - 16
	vis_contents += shaped
	return shaped

/// Draws the heads in other colours for now (see portrait_tints), or (with nothing) their own.
/obj/effect/abstract/fnf_hud/healthbar/proc/set_portrait_tints(left_tint, right_tint)
	portrait_tints = (left_tint || right_tint) ? list(left_tint, right_tint) : null
	update(shown_health, instant = TRUE)

/// Hides a singer's head, or shows it again.
/obj/effect/abstract/fnf_hud/healthbar/proc/show_portrait(mob/living/singer, shown)
	for(var/obj/effect/abstract/fnf_hud/portrait/portrait as anything in list(left_portrait, right_portrait))
		if(portrait?.singer == singer)
			portrait.alpha = shown ? 255 : 0

/// Colours the bar: the opponent's side and the challenger's.
/obj/effect/abstract/fnf_hud/healthbar/proc/set_colours(left_colour, right_colour)
	if(left_colour)
		left_bar.color = left_colour
		shaped_left?.color = left_colour
	if(right_colour)
		right_bar.color = right_colour
		shaped_right?.color = right_colour

/// Moves the split to match the health, which is how much of the bar is the challenger's.
/obj/effect/abstract/fnf_hud/healthbar/proc/update(health, instant = FALSE)
	shown_health = health
	var/width = max(FNF_BAR_WIDTH * health / FNF_HEALTH_MAX, 0.5)
	var/time = instant ? 0 : 1
	animate(right_bar, transform = matrix(width / 32, 0, (FNF_BAR_WIDTH - width) / 2, 0, FNF_BAR_HEIGHT / 32, 0), time = time)
	// Where the colours meet, from the bar's middle.
	var/split = FNF_BAR_WIDTH / 2 - width
	// In a frame of its own, the challenger's colour starts there.
	if(shaped_right)
		shaped_right.transition_filter("split", list("x" = FNF_HUD_FRAME_WIDTH / 2 + split), time)
	for(var/obj/effect/abstract/fnf_hud/portrait/portrait as anything in list(left_portrait, right_portrait))
		if(!portrait)
			continue
		var/side_offset = portrait == left_portrait ? -13 : 13
		animate(portrait, pixel_w = center_x - 16 + split + side_offset, pixel_z = center_y - 16, time = time)
	// Whoever's losing badly goes pale.
	left_portrait?.color = portrait_tints?[1] || (health > 80 ? "#8888ff" : null)
	right_portrait?.color = portrait_tints?[2] || (health < 20 ? "#8888ff" : null)

/// Both portraits bob to the beat.
/obj/effect/abstract/fnf_hud/healthbar/proc/bop()
	for(var/obj/effect/abstract/fnf_hud/portrait/portrait as anything in list(left_portrait, right_portrait))
		if(!portrait)
			continue
		portrait.refresh()
		animate(portrait, transform = portrait.get_matrix(1.2), time = 0)
		animate(transform = portrait.get_matrix(1), time = 2, easing = CUBIC_EASING|EASE_OUT)

/// Takes a singer's portrait down, when the singer is going away.
/obj/effect/abstract/fnf_hud/healthbar/proc/drop_portrait(mob/living/singer)
	if(left_portrait?.singer == singer)
		QDEL_NULL(left_portrait)
	if(right_portrait?.singer == singer)
		QDEL_NULL(right_portrait)

/obj/effect/abstract/fnf_hud/healthbar/proc/announce(text, colour = "#ffffff")
	announcer.maptext = MAPTEXT("<span style='text-align:center;font-size:12pt;color:[colour];-dm-text-outline:1px #000000'><b>[text]</b></span>")
	animate(announcer, alpha = 255, transform = matrix() * 1.4, time = 0)
	animate(transform = matrix(), time = 1.5, easing = BACK_EASING|EASE_OUT)
	animate(alpha = 0, time = 3, delay = 1)

/**
 * A singer's head beside the health bar, facing their rival, like Funkin's health icons. For a
 * rigged singer it's the rig's own head pieces, so it nods and sings along; for anyone else, a
 * picture of them taken at the start.
 */
/obj/effect/abstract/fnf_hud/portrait
	layer = ABOVE_ALL_MOB_LAYER + 0.04
	appearance_flags = RESET_COLOR|RESET_ALPHA|PIXEL_SCALE|KEEP_TOGETHER|KEEP_APART
	var/mob/living/singer
	/// Where the middle of the head is on the singer's tile, in pixels, and how much to blow it up.
	var/head_x = 16
	var/head_y = 16
	var/head_scale = 1
	var/list/obj/effect/abstract/limb_rig_part/pieces = list()

/obj/effect/abstract/fnf_hud/portrait/Initialize(mapload, mob/living/singer, facing)
	. = ..()
	src.singer = singer
	dir = facing
	refresh()

/// Puts the singer's head up. A singer summoned for the battle only gets its rig a moment after
/// it appears, and a rig can be rebuilt mid-song, so this is checked again on every beat.
/obj/effect/abstract/fnf_hud/portrait/proc/refresh()
	if(length(pieces))
		return
	var/mob/living/carbon/carbon_singer = singer
	var/datum/limb_rig/rig = istype(carbon_singer) ? carbon_singer.limb_rig : null
	cut_overlays()
	if(rig)
		var/list/head = rig.get_portrait_head(dir)
		head_x = head[1]
		head_y = head[2]
		head_scale = head[3]
		for(var/obj/effect/abstract/limb_rig_part/piece as anything in rig.get_head_pieces())
			if(!piece)
				continue
			pieces += piece
			vis_contents += piece
			RegisterSignal(piece, COMSIG_QDELETING, PROC_REF(on_piece_deleted))
	else if(singer)
		var/mutable_appearance/look = new(singer)
		look.dir = dir
		look.plane = FLOAT_PLANE
		look.layer = FLOAT_LAYER
		add_overlay(look)
		head_x = 16
		head_y = 20
		head_scale = 0.8
	transform = get_matrix(1)

/obj/effect/abstract/fnf_hud/portrait/Destroy()
	for(var/obj/effect/abstract/limb_rig_part/piece as anything in pieces)
		UnregisterSignal(piece, COMSIG_QDELETING)
	pieces.Cut()
	vis_contents.Cut()
	cut_overlays()
	singer = null
	return ..()

/obj/effect/abstract/fnf_hud/portrait/proc/on_piece_deleted(datum/source)
	SIGNAL_HANDLER
	pieces -= source
	vis_contents -= source

/// Centres the head and scales it, times bop for bobbing to the beat.
/obj/effect/abstract/fnf_hud/portrait/proc/get_matrix(bop = 1)
	var/matrix/centred = matrix()
	centred.Translate(16 - head_x, 16 - head_y)
	centred.Scale(head_scale * bop)
	return centred

/// The pieces that draw the head, for showing it somewhere else.
/datum/limb_rig/proc/get_head_pieces()
	return list(parts[RIG_HEAD])

/// list(x, y, scale): where the middle of the head is on the tile, and how much to scale it by
/// for a health bar portrait.
/datum/limb_rig/proc/get_portrait_head(facing)
	var/list/neck = get_rig_joint(RIG_HEAD, facing)
	return list(neck[1], neck[2] + 4, 1.6)

/datum/limb_rig/sprites/get_head_pieces()
	return list(parts[RIG_HEAD], cloth_parts[RIG_HEAD], face_part)

/datum/limb_rig/sprites/get_portrait_head(facing)
	var/list/bones = skeleton[dir2text(facing)]
	var/list/neck = bones[RIG_HEAD]
	var/list/crown = bones["crown"] || list(neck[1], neck[2] + 14)
	return list(neck[1], neck[2] * 0.7 + crown[2] * 0.3, 1)

/// A species' own head on the generated body is a human head drawn a quarter bigger: smaller
/// than an Experiment's, so it's framed closer.
/datum/limb_rig/sprites/humanoid/get_portrait_head(facing)
	var/list/bones = skeleton[dir2text(facing)]
	var/list/neck = bones[RIG_HEAD]
	var/list/crown = bones["crown"]
	return list(neck[1], (neck[2] + crown[2]) / 2, 1.4)
