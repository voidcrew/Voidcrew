// Hyperviolence visuals: guts.
// 16. Guts dragged along the floor, by someone pulling them or by the strand, slither as they go.

/obj/item/hv_intestines/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(!isturf(loc) || !isturf(old_loc) || throwing)
		return
	hv_vis_slither(movement_dir || get_dir(old_loc, loc))

/// One slither along the floor: a wiggle from side to side across the way it is going.
/obj/item/hv_intestines/proc/hv_vis_slither(going)
	// Across the way it moves: east-west movement wiggles north-south, and the other way round.
	var/side_w = HV_VIS_DY(going) ? 2 : 0
	var/side_z = HV_VIS_DX(going) ? 2 : 0
	if(!side_w && !side_z)
		side_w = 2
	var/matrix/base = matrix(transform)
	hv_vis_play(HV_VIS_TAG_SHAKE, list(
		list(pixel_w + side_w, pixel_z + side_z, hv_vis_local(base, 1.1, 0.9, 12), 1, SINE_EASING),
		list(pixel_w - side_w, pixel_z - side_z, hv_vis_local(base, 0.92, 1.06, -12), 1.2, SINE_EASING),
		list(pixel_w + round(side_w / 2), pixel_z + round(side_z / 2), hv_vis_local(base, 1.04, 0.97, 6), 1, SINE_EASING),
		list(pixel_w, pixel_z, base, 1, SINE_EASING),
	))

