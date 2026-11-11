// The Rig Bay stand's look: an overhead gantry with two chains that hold the display mech up, the release
// (chains lower the mech, then wind up) and the beam-in (a blue-white column, the mech fades in, the chains
// come down and hoist it). Logic lives in rig_bay_stand.dm; this file only draws and plays sounds.
//
// Draw order on the stand's tile (all on one turf, so they sort by layer; everything moves by pixel_z/pixel_w,
// never pixel_y, so nothing changes rows):
//   stand pad (2.9) < chains (RIG_BAY_CHAIN_LAYER) < gantry + post lamps (RIG_BAY_GANTRY_LAYER)
//   < beam column (RIG_BAY_BEAM_LAYER) < mech (VEHICLE_LAYER) < flash, sparks (RIG_BAY_FRONT_LAYER) < mobs
// The chains sit behind the mech, so their shackles tuck behind its shoulders, and behind the gantry bar, so
// their tops tuck into it. The flash and sparks sit just in front of the mech and still behind anyone
// standing on the stand's own tile row.

/// Chains hang behind the gantry and the mech.
#define RIG_BAY_CHAIN_LAYER 3.86
/// The gantry posts, bar and lamps: in front of the chains, behind the beam and the mech.
#define RIG_BAY_GANTRY_LAYER 3.87
/// The beam-in column: in front of the gantry, behind the mech.
#define RIG_BAY_BEAM_LAYER 3.88
/// The arrival flash and the sparks at the mech's feet: in front of the mech, behind mobs.
#define RIG_BAY_FRONT_LAYER 3.93
/// pixel_z of a chain frame whose top row sits at the top of the gantry bar (26 px above the tile).
#define RIG_BAY_CHAIN_TOP 26
/// Rows in a stowed chain: only its shackle shows under the bar.
#define RIG_BAY_CHAIN_STOWED 5
/// Column of a chain frame's centre line (frames are 9 px wide: outline, 7 px of links, outline).
#define RIG_BAY_CHAIN_HALF 4
/// Longest chain_N state in the stand's DMI.
#define RIG_BAY_CHAIN_MAX 32
/// Volume of the stand's sounds. It's a shop floor: keep it low.
#define RIG_BAY_SOUND_VOLUME 30
/// Tint a beamed-in mech starts with, fading to its own colours.
#define RIG_BAY_BEAM_TINT "#7fa8ff"

/obj/structure/rig_bay_stand
	/// The two chains hanging from the gantry, left then right (screen space).
	var/list/obj/effect/rig_bay_chain/chains
	/// Colour of the lamps on the gantry posts: "red" (held), "amber" (working), "green" (released), "grey" (empty).
	var/lamp = "grey"

/obj/structure/rig_bay_stand/Initialize(mapload)
	. = ..()
	ensure_chains()
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/rig_bay_stand/Destroy()
	// The parent forgets the mech first; forget_mech() below leaves the chains alone while the stand is going.
	. = ..()
	QDEL_LIST(chains)

/// Makes sure both chains exist and stand on the stand's tile. Rebuilds any that were deleted or moved off.
/obj/structure/rig_bay_stand/proc/ensure_chains()
	LAZYINITLIST(chains)
	for(var/obj/effect/rig_bay_chain/chain as anything in chains.Copy())
		if(QDELETED(chain) || chain.loc != loc)
			chains -= chain
			if(!QDELETED(chain))
				qdel(chain)
	var/static/list/default_anchors = list(7, 24)
	while(length(chains) < 2)
		var/obj/effect/rig_bay_chain/chain = new(loc)
		chain.set_pose(default_anchors[length(chains) + 1], RIG_BAY_CHAIN_STOWED, RIG_BAY_CHAIN_TOP - RIG_BAY_HANG_LIFT)
		chains += chain

/obj/structure/rig_bay_stand/update_overlays()
	. = ..()
	var/icon_file = 'voidcrew/modules/trade/icons/rig_bay_stand.dmi'
	// The gantry is 3 tiles wide and 2 tall: posts in the side tiles, bar across the tile above.
	var/static/list/pieces = list(
		"gantry_nw" = list(-32, 32), "gantry_n" = list(0, 32), "gantry_ne" = list(32, 32),
		"gantry_w" = list(-32, 0), "gantry_e" = list(32, 0),
	)
	for(var/piece in pieces)
		var/mutable_appearance/part = mutable_appearance(icon_file, piece, RIG_BAY_GANTRY_LAYER, src)
		var/list/offset = pieces[piece]
		part.pixel_w = offset[1]
		part.pixel_z = offset[2]
		. += part
	// A lamp on each post, just under the bar.
	for(var/lamp_x in list(-5, 35))
		var/mutable_appearance/light = mutable_appearance(icon_file, "lamp_[lamp]", RIG_BAY_GANTRY_LAYER, src)
		light.pixel_w = lamp_x
		light.pixel_z = 20
		. += light
		if(lamp == "grey")
			continue
		var/mutable_appearance/glow = emissive_appearance(icon_file, "lamp_[lamp]", src, RIG_BAY_GANTRY_LAYER)
		glow.pixel_w = lamp_x
		glow.pixel_z = 20
		. += glow

/// Sets the post lamps.
/obj/structure/rig_bay_stand/proc/set_lamp(new_lamp)
	if(lamp == new_lamp)
		return
	lamp = new_lamp
	update_appearance(UPDATE_OVERLAYS)

/// A mech that leaves (driven off, deleted) takes nothing with it: the chains go back up to the bar.
/obj/structure/rig_bay_stand/forget_mech()
	..()
	if(QDELING(src))
		return
	ensure_chains()
	for(var/obj/effect/rig_bay_chain/chain as anything in chains)
		chain.set_pose(chain.anchor_x, RIG_BAY_CHAIN_STOWED, RIG_BAY_CHAIN_TOP - RIG_BAY_HANG_LIFT)
	set_lamp("grey")

/// Idle look: the mech hangs RIG_BAY_HANG_LIFT px up with both chains hooked onto its shoulders.
/obj/structure/rig_bay_stand/apply_hang_pose(obj/vehicle/sealed/mecha/mech)
	mech.alpha = 255
	mech.pixel_z = RIG_BAY_HANG_LIFT
	ensure_chains()
	var/list/anchors = chain_anchors(mech)
	for(var/i in 1 to length(chains))
		var/obj/effect/rig_bay_chain/chain = chains[i]
		var/list/anchor = anchors[i]
		chain.set_pose(anchor[1], hang_length(anchor[2]), RIG_BAY_CHAIN_TOP)
	set_lamp("red")

/**
 * Release, 1.1 s. 0-3 ds the bolts let go (lamps amber); 3-7 the chains pay out and the mech lowers 4 px to
 * the floor (mech and chains move together); 7-11 the shackles let go and the chains wind up into the bar.
 * Lamps go green at 11. pixel_z is 0 from the 7 ds mark; on_done fires once at 11 ds.
 */
/obj/structure/rig_bay_stand/animate_release(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	ensure_chains()
	set_lamp("amber")
	playsound(src, 'sound/machines/airlock/boltsup.ogg', RIG_BAY_SOUND_VOLUME, FALSE, SHORT_RANGE_SOUND_EXTRARANGE)
	addtimer(CALLBACK(src, PROC_REF(stand_sound), 'sound/vehicles/mecha/hydraulic.ogg'), 0.3 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(stand_sound), 'sound/vehicles/mecha/mechstep.ogg'), 0.7 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(stand_sound), SFX_REEL), 0.7 SECONDS)
	var/lift = mech.pixel_z
	animate(mech, time = 3)
	animate(pixel_z = 0, time = 4)
	for(var/obj/effect/rig_bay_chain/chain as anything in chains)
		var/length = chain.length
		var/top = chain.pixel_z
		animate(chain, time = 3)
		animate(pixel_z = top - lift, time = 4)
		chain.queue_length_steps(length, RIG_BAY_CHAIN_STOWED, 4)
		chain.length = RIG_BAY_CHAIN_STOWED
	addtimer(CALLBACK(src, PROC_REF(end_release), mech, on_done), 1.1 SECONDS)

/// Release end: makes sure the mech is on the floor, lamps green, then hands over.
/obj/structure/rig_bay_stand/proc/end_release(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	if(!QDELETED(mech))
		mech.pixel_z = 0
	if(mech == held_mech)
		set_lamp("green")
	on_done?.Invoke()

/**
 * Beam-in, 3.0 s. Lamps amber and the pad charges (0-10 ds) while a blue-white column builds; a flash at 10;
 * the mech fades in on the floor inside the column, tinted blue and clearing (14-20) while the stowed chains
 * slide along the bar over its shoulders; sparks at its feet and the column fades (20-24); the chains come
 * down to the shoulders (20-26) and hoist the mech 4 px (26-30). Lamps red and on_done once at 30 ds.
 */
/obj/structure/rig_bay_stand/animate_beam_in(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	ensure_chains()
	set_lamp("amber")
	flick("mechpad-launch", src)
	playsound(src, 'sound/machines/beep/triple_beep.ogg', RIG_BAY_SOUND_VOLUME, FALSE, SHORT_RANGE_SOUND_EXTRARANGE)
	addtimer(CALLBACK(src, PROC_REF(stand_sound), 'sound/effects/phasein.ogg'), 1 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(stand_sound), SFX_SPARKS), 2 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(stand_sound), SFX_REEL), 2 SECONDS)
	// The flash and sparks are made now and switched on by animate(), so they keep time with the column and
	// the mech on the client even when the server lags.
	var/obj/effect/temp_visual/rig_bay_phase/flash = new(loc)
	animate(flash, time = 10)
	animate(icon_state = "phasein", time = 5)
	for(var/foot_x in list(-8, 8))
		var/obj/effect/temp_visual/rig_bay_spark/spark = new(loc)
		spark.pixel_w = foot_x
		animate(spark, time = 20)
		animate(icon_state = "sparks", time = 7)
	addtimer(CALLBACK(src, PROC_REF(stand_sound), 'sound/vehicles/mecha/hydraulic.ogg'), 2.6 SECONDS)

	mech.pixel_z = 0
	mech.alpha = 0
	mech.color = RIG_BAY_BEAM_TINT
	var/obj/effect/rig_bay_beam_column/column = new(loc)
	animate(column, alpha = 77, time = 10)
	animate(alpha = 140, time = 4)
	animate(alpha = 115, time = 6)
	animate(alpha = 0, time = 4)
	QDEL_IN(column, 2.5 SECONDS)

	animate(mech, time = 14)
	animate(alpha = 255, color = "#ffffff", time = 6)
	animate(time = 6)
	animate(pixel_z = RIG_BAY_HANG_LIFT, time = 4)

	var/list/anchors = chain_anchors(mech)
	for(var/i in 1 to length(chains))
		var/obj/effect/rig_bay_chain/chain = chains[i]
		var/list/anchor = anchors[i]
		var/hang = hang_length(anchor[2])
		chain.pixel_z = RIG_BAY_CHAIN_TOP - RIG_BAY_HANG_LIFT
		chain.icon_state = "chain_[RIG_BAY_CHAIN_STOWED]"
		animate(chain, time = 14)
		animate(pixel_w = anchor[1] - RIG_BAY_CHAIN_HALF, time = 6)
		chain.queue_length_steps(RIG_BAY_CHAIN_STOWED, hang, 6)
		animate(pixel_z = RIG_BAY_CHAIN_TOP, time = 4)
		chain.anchor_x = anchor[1]
		chain.length = hang
	addtimer(CALLBACK(src, PROC_REF(end_beam_in), mech, on_done), 3 SECONDS)

/// Beam-in end: settles the hang pose (lamps red), then hands over.
/obj/structure/rig_bay_stand/proc/end_beam_in(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	if(!QDELETED(mech))
		mech.update_atom_colour()
		if(mech == held_mech)
			apply_hang_pose(mech)
			stand_sound('sound/machines/airlock/boltsdown.ogg')
	on_done?.Invoke()

/// Plays one of the stand's sounds at shop volume.
/obj/structure/rig_bay_stand/proc/stand_sound(sound_file)
	playsound(src, sound_file, RIG_BAY_SOUND_VOLUME, FALSE, SHORT_RANGE_SOUND_EXTRARANGE)

/// Rows a chain needs to reach a shackle row `attach_row` (tile-local, y down) with its top in the bar.
/obj/structure/rig_bay_stand/proc/hang_length(attach_row)
	return clamp(attach_row - RIG_BAY_HANG_LIFT + RIG_BAY_CHAIN_TOP + 1, RIG_BAY_CHAIN_STOWED, RIG_BAY_CHAIN_MAX)

/**
 * Where the two chains hook onto `mech`, from its sprite's top edge: list(list(x, row), list(x, row)), left
 * then right. x is the shackle's centre column, row is the shackle's last row with the mech on the floor:
 * one row inside the mech's silhouette under all three shackle columns, so it tucks behind the shoulder.
 */
/obj/structure/rig_bay_stand/proc/chain_anchors(obj/vehicle/sealed/mecha/mech)
	var/list/profile = mech_top_profile(mech)
	var/left = 1
	var/right = 32
	while(left < 32 && isnull(profile[left]))
		left++
	while(right > 1 && isnull(profile[right]))
		right--
	var/width = right - left + 1
	var/inset = round(width * 0.22)
	var/list/anchors = list()
	for(var/column in list(left + inset, right - inset)) // 1-based icon columns
		column = clamp(column, 2, 31)
		var/row = 0
		for(var/c in column - 1 to column + 1)
			row = max(row, profile[c] || 0)
		anchors += list(list(column - 1, row + 1))
	return anchors

/// For each of a mech sprite's 32 columns, the first opaque row from the top (0-based), or null. Cached.
/obj/structure/rig_bay_stand/proc/mech_top_profile(obj/vehicle/sealed/mecha/mech)
	var/static/list/cache = list()
	var/key = "[mech.icon]|[mech.icon_state]|[mech.dir]"
	if(cache[key])
		return cache[key]
	var/list/profile = scan_profile(icon(mech.icon, mech.icon_state, mech.dir, 1))
	if(!profile)
		profile = scan_profile(icon(mech.icon, mech.icon_state, SOUTH, 1)) // single-dir states
	if(!profile)
		profile = new /list(32)
		for(var/i in 1 to 32)
			profile[i] = 0
	cache[key] = profile
	return profile

/// Top-edge scan of a 32x32 icon; null if it is empty.
/obj/structure/rig_bay_stand/proc/scan_profile(icon/sprite)
	var/list/profile = new /list(32)
	var/found = FALSE
	for(var/x in 1 to 32)
		for(var/row in 0 to 31)
			if(sprite.GetPixel(x, 32 - row))
				profile[x] = row
				found = TRUE
				break
	return found ? profile : null

/// One chain hanging from a Rig Bay gantry. Pure visual; the stand owns it and rebuilds it if it goes missing.
/obj/effect/rig_bay_chain
	name = "chain"
	icon = 'voidcrew/modules/trade/icons/rig_bay_stand.dmi'
	icon_state = "chain_5"
	layer = RIG_BAY_CHAIN_LAYER
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	/// Tile-local x of the shackle's centre.
	var/anchor_x = 7
	/// Rows in the current chain_N state.
	var/length = RIG_BAY_CHAIN_STOWED

/// Snaps the chain to a pose, no animation.
/obj/effect/rig_bay_chain/proc/set_pose(new_anchor_x, new_length, new_top)
	anchor_x = new_anchor_x
	length = new_length
	pixel_w = anchor_x - RIG_BAY_CHAIN_HALF
	pixel_z = new_top
	icon_state = "chain_[length]"

/// Queues animate() steps that change the chain's length from `from_length` to `to_length` over `time` ds (top stays put).
/obj/effect/rig_bay_chain/proc/queue_length_steps(from_length, to_length, time)
	var/steps = max(1, round(time / 0.5))
	for(var/step in 1 to steps)
		animate(icon_state = "chain_[round(from_length + (to_length - from_length) * step / steps)]", time = time / steps)

/// The blue-white column a restocked mech beams in through: 1.5 tiles wide, 3 tall, standing on the pad.
/// Sorts on the pad's row (pixel_z only), so it stays behind the mech and anything south of the stand.
/obj/effect/rig_bay_beam_column
	name = "beam"
	icon = 'icons/effects/beam.dmi'
	icon_state = "bsa_beam"
	layer = RIG_BAY_BEAM_LAYER
	anchored = TRUE
	alpha = 0
	pixel_z = 32
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE

/obj/effect/rig_bay_beam_column/Initialize(mapload)
	. = ..()
	transform = matrix(1.5, 0, 0, 0, 3, 0)
	// A beam of light glows in a dim room; the glow follows the column's own fade.
	add_overlay(emissive_appearance(icon, icon_state, src))

/// The flash where a beamed-in mech appears: in front of the mech, behind mobs. Blank until the stand's
/// animate() switches it to "phasein" 1 s into the beam-in.
/obj/effect/temp_visual/rig_bay_phase
	icon = 'icons/effects/effects.dmi'
	icon_state = "nothing"
	layer = RIG_BAY_FRONT_LAYER
	color = "#cfe4ff"
	pixel_z = 2
	duration = 2 SECONDS
	randomdir = FALSE

/// Picture-only sparks at a beamed-in mech's feet (no heat: these never light anything). Blank until the
/// stand's animate() switches them on 2 s into the beam-in. Shrunk and dropped so they burst at foot level.
/obj/effect/temp_visual/rig_bay_spark
	icon = 'icons/effects/effects.dmi'
	icon_state = "nothing"
	layer = RIG_BAY_FRONT_LAYER
	pixel_z = -6
	duration = 3 SECONDS

/obj/effect/temp_visual/rig_bay_spark/Initialize(mapload)
	. = ..()
	transform = matrix(0.6, 0, 0, 0, 0.6, 0)

#undef RIG_BAY_CHAIN_LAYER
#undef RIG_BAY_GANTRY_LAYER
#undef RIG_BAY_BEAM_LAYER
#undef RIG_BAY_FRONT_LAYER
#undef RIG_BAY_CHAIN_TOP
#undef RIG_BAY_CHAIN_STOWED
#undef RIG_BAY_CHAIN_HALF
#undef RIG_BAY_CHAIN_MAX
#undef RIG_BAY_SOUND_VOLUME
#undef RIG_BAY_BEAM_TINT
