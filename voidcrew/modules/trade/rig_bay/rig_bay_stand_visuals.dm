// The Rig Bay stand's look: an overhead gantry with two chains that hold the display mech up, the release
// (chains lower the mech, then wind up) and the beam-in (a blue-white column, the mech fades in, the chains
// come down and hoist it). Logic lives in rig_bay_stand.dm; this file only draws.
//
// Draw order on the stand's tile (all on one turf, so they sort by layer; everything moves by pixel_z/pixel_w,
// never pixel_y, so nothing changes rows):
//   stand pad (2.9) < chains (RIG_BAY_CHAIN_LAYER) < gantry (RIG_BAY_GANTRY_LAYER) < beam column (RIG_BAY_BEAM_LAYER) < mech (VEHICLE_LAYER)
// The chains sit behind the mech, so their shackles tuck behind its shoulders, and behind the gantry bar, so
// their tops tuck into it.

/// Chains hang behind the gantry and the mech.
#define RIG_BAY_CHAIN_LAYER 3.86
/// The gantry posts and bar: in front of the chains, behind the beam and the mech.
#define RIG_BAY_GANTRY_LAYER 3.87
/// The beam-in column: in front of the gantry, behind the mech.
#define RIG_BAY_BEAM_LAYER 3.88
/// pixel_z of a chain frame whose top row sits at the top of the gantry bar (26 px above the tile).
#define RIG_BAY_CHAIN_TOP 26
/// Rows in a stowed chain: only its shackle shows under the bar.
#define RIG_BAY_CHAIN_STOWED 5
/// Half the chain sprite's width; chain frames are drawn from column 0.
#define RIG_BAY_CHAIN_HALF 3
/// Longest chain_N state in the stand's DMI.
#define RIG_BAY_CHAIN_MAX 32

/obj/structure/rig_bay_stand
	/// The two chains hanging from the gantry, left then right (screen space).
	var/list/obj/effect/rig_bay_chain/chains

/obj/structure/rig_bay_stand/Initialize(mapload)
	. = ..()
	chains = list()
	for(var/anchor_x in list(7, 24))
		var/obj/effect/rig_bay_chain/chain = new(loc)
		chain.set_pose(anchor_x, RIG_BAY_CHAIN_STOWED, RIG_BAY_CHAIN_TOP - RIG_BAY_HANG_LIFT)
		chains += chain
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/rig_bay_stand/Destroy()
	QDEL_LIST(chains)
	return ..()

/obj/structure/rig_bay_stand/update_overlays()
	. = ..()
	// The gantry is 3 tiles wide and 2 tall: posts in the side tiles, bar across the tile above.
	var/static/list/pieces = list(
		"gantry_nw" = list(-32, 32), "gantry_n" = list(0, 32), "gantry_ne" = list(32, 32),
		"gantry_w" = list(-32, 0), "gantry_e" = list(32, 0),
	)
	for(var/piece in pieces)
		var/mutable_appearance/part = mutable_appearance('voidcrew/modules/trade/icons/rig_bay_stand.dmi', piece, RIG_BAY_GANTRY_LAYER, src)
		var/list/offset = pieces[piece]
		part.pixel_w = offset[1]
		part.pixel_z = offset[2]
		. += part

/// A mech that leaves (driven off, deleted) takes nothing with it: the chains go back up to the bar.
/obj/structure/rig_bay_stand/forget_mech()
	..()
	for(var/obj/effect/rig_bay_chain/chain as anything in chains)
		chain.set_pose(chain.anchor_x, RIG_BAY_CHAIN_STOWED, RIG_BAY_CHAIN_TOP - RIG_BAY_HANG_LIFT)

/// Idle look: the mech hangs RIG_BAY_HANG_LIFT px up with both chains hooked onto its shoulders.
/obj/structure/rig_bay_stand/apply_hang_pose(obj/vehicle/sealed/mecha/mech)
	mech.alpha = 255
	mech.pixel_z = RIG_BAY_HANG_LIFT
	var/list/anchors = chain_anchors(mech)
	for(var/i in 1 to length(chains))
		var/obj/effect/rig_bay_chain/chain = chains[i]
		var/list/anchor = anchors[i]
		chain.set_pose(anchor[1], hang_length(anchor[2]), RIG_BAY_CHAIN_TOP)

/**
 * Release, 1.1 s. 0-3 ds the chains hold; 3-7 the chains pay out and the mech lowers 4 px to the floor
 * (mech and chains move together); 7-11 the shackles let go and the chains wind up into the bar.
 * pixel_z is 0 from the 7 ds mark; on_done fires once at 11 ds.
 */
/obj/structure/rig_bay_stand/animate_release(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
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

/// Release end: makes sure the mech is on the floor, then hands over.
/obj/structure/rig_bay_stand/proc/end_release(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	if(!QDELETED(mech))
		mech.pixel_z = 0
	on_done?.Invoke()

/**
 * Beam-in, 3.0 s. A blue-white column builds on the pad (0-14 ds), the mech fades in on the floor inside it
 * (14-20) while the stowed chains slide along the bar over its shoulders, the column fades (20-24), the chains
 * come down to the shoulders (20-26) and hoist the mech 4 px (26-30). on_done fires once at 30 ds.
 */
/obj/structure/rig_bay_stand/animate_beam_in(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	mech.pixel_z = 0
	mech.alpha = 0
	var/obj/effect/rig_bay_beam_column/column = new(loc)
	animate(column, alpha = 77, time = 10)
	animate(alpha = 140, time = 4)
	animate(alpha = 115, time = 6)
	animate(alpha = 0, time = 4)
	QDEL_IN(column, 2.5 SECONDS)

	animate(mech, time = 14)
	animate(alpha = 255, time = 6)
	animate(time = 6)
	animate(pixel_z = RIG_BAY_HANG_LIFT, time = 4)

	var/list/anchors = chain_anchors(mech)
	for(var/i in 1 to length(chains))
		var/obj/effect/rig_bay_chain/chain = chains[i]
		var/list/anchor = anchors[i]
		var/hang = hang_length(anchor[2])
		var/low_top = RIG_BAY_CHAIN_TOP - RIG_BAY_HANG_LIFT
		chain.pixel_z = low_top
		chain.icon_state = "chain_[RIG_BAY_CHAIN_STOWED]"
		animate(chain, time = 14)
		animate(pixel_w = anchor[1] - RIG_BAY_CHAIN_HALF, time = 6)
		chain.queue_length_steps(RIG_BAY_CHAIN_STOWED, hang, 6)
		animate(pixel_z = RIG_BAY_CHAIN_TOP, time = 4)
		chain.anchor_x = anchor[1]
		chain.length = hang
	addtimer(CALLBACK(src, PROC_REF(end_beam_in), mech, on_done), 3 SECONDS)

/// Beam-in end: settles the hang pose, then hands over.
/obj/structure/rig_bay_stand/proc/end_beam_in(obj/vehicle/sealed/mecha/mech, datum/callback/on_done)
	if(!QDELETED(mech) && mech == held_mech)
		apply_hang_pose(mech)
	on_done?.Invoke()

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

/// One chain hanging from a Rig Bay gantry. Pure visual; the stand owns it.
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

#undef RIG_BAY_CHAIN_LAYER
#undef RIG_BAY_GANTRY_LAYER
#undef RIG_BAY_BEAM_LAYER
#undef RIG_BAY_CHAIN_TOP
#undef RIG_BAY_CHAIN_STOWED
#undef RIG_BAY_CHAIN_HALF
#undef RIG_BAY_CHAIN_MAX
