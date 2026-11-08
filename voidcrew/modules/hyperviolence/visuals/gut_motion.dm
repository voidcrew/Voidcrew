// Hyperviolence visuals: guts.
// 15. Spilled intestines come out of the body: they start small at the body, spill along the floor to
//     where they lie and flop down, and the strand to the body (braingut/gut_tether.dm) only appears
//     once they are out.
// 16. Guts dragged along the floor, by someone pulling them or by the strand, slither as they go.

/// How long the guts take to come out of the body.
#define HV_VIS_UNSPOOL_TIME (0.7 SECONDS)

/obj/item/hv_intestines
	/// World time the guts are all the way out of the body; the strand waits for it.
	var/hv_vis_unspooled_at = 0

/obj/item/bodypart/chest/hv_drop_intestines(attack_direction)
	var/mob/living/carbon/victim = owner
	. = ..()
	var/obj/item/hv_intestines/guts = .
	if(istype(guts) && victim && isturf(guts.loc))
		guts.hv_vis_unspool_from(victim)

/// Comes out of `body`: from small at the body to full size where the guts lie, and a flop.
/obj/item/hv_intestines/proc/hv_vis_unspool_from(atom/body)
	var/turf/from = get_turf(body)
	var/turf/here = get_turf(src)
	if(!from || !here || from.z != here.z)
		return
	hv_vis_unspooled_at = world.time + HV_VIS_UNSPOOL_TIME
	var/off_w = (from.x - here.x) * ICON_SIZE_X - pixel_x
	var/off_z = (from.y - here.y) * ICON_SIZE_Y - pixel_y
	var/matrix/base = matrix(transform)
	var/twist = pick(-1, 1)
	hv_vis_play(HV_VIS_TAG_ARC, list(
		list(pixel_w + off_w, pixel_z + off_z, hv_vis_local(base, 0.25, 0.25, twist * -60), 0, LINEAR_EASING),
		list(pixel_w + round(off_w * 0.45), pixel_z + round(off_z * 0.45) - 2, hv_vis_local(base, 0.65, 0.5, twist * 35), HV_VIS_UNSPOOL_TIME * 0.5, SINE_EASING),
		list(pixel_w, pixel_z, hv_vis_local(base, 1.12, 0.84, twist * -8), HV_VIS_UNSPOOL_TIME * 0.3, QUAD_EASING|EASE_OUT),
		list(pixel_w, pixel_z, base, HV_VIS_UNSPOOL_TIME * 0.2 + 2, ELASTIC_EASING),
	))

/// The strand to the body waits until the guts are out.
/datum/hv_gut_tether/refresh()
	if(!strand && guts && world.time < guts.hv_vis_unspooled_at)
		addtimer(CALLBACK(src, PROC_REF(refresh)), guts.hv_vis_unspooled_at - world.time, TIMER_UNIQUE|TIMER_DELETE_ME)
		return
	return ..()

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

#undef HV_VIS_UNSPOOL_TIME
