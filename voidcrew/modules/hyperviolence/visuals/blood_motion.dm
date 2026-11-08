// Hyperviolence visuals: blood that moves.
// 11. A spray paints in along the floor: each tile's streak or splash grows out from the side the
//     blood came from, a moment after the tile before it.
// 12. A smear on a wall lands short and runs down the wall to its full length over a few seconds.
// 13. A pool that grows to its next size spreads out to it over a couple of seconds, and the end of a
//     big pool running onto the next tile flows out from the pool's side.
// 14. In zero gravity, blood leaving a wound drifts away from it turning over, and some of it splits
//     off into a smaller bead that floats off and fades.
// tg restarts a blood decal's animations whenever its blood or colour changes (update_blood_color()),
// so any of these is cut short by more blood landing on the same decal: it just shows at once.

/// The turf a spray is being thrown from, while hv_blood_throw() runs, so its decals know their order.
GLOBAL_VAR(hv_vis_spray_origin)

/mob/living/hv_blood_throw(spray_dir, strength = 3)
	var/turf/previous_origin = GLOB.hv_vis_spray_origin
	GLOB.hv_vis_spray_origin = get_turf(src)
	. = ..()
	GLOB.hv_vis_spray_origin = previous_origin

/obj/effect/decal/cleanable/blood/hv_spray
	/// Set on a decal just made, until hv_aim() turns it the way the blood flew and paints it in.
	var/hv_vis_fresh = FALSE
	/// How many tiles past the first the spray had come when it made this, for the order tiles paint in.
	var/hv_vis_spray_step = 0

/obj/effect/decal/cleanable/blood/hv_spray/Initialize(mapload, list/datum/disease/diseases, list/blood_or_dna = get_default_blood_type())
	. = ..()
	if(mapload || . == INITIALIZE_HINT_QDEL)
		return
	hv_vis_fresh = TRUE
	var/turf/origin = GLOB.hv_vis_spray_origin
	if(origin && origin.z == z)
		hv_vis_spray_step = max(get_dist(origin, src) - 1, 0)

/obj/effect/decal/cleanable/blood/hv_spray/hv_aim(spray_dir)
	. = ..()
	if(!hv_vis_fresh || istype(src, /obj/effect/decal/cleanable/blood/hv_spray/wall))
		return
	hv_vis_fresh = FALSE
	hv_vis_paint_in(spray_dir)

/// Grows the decal out along the floor from the side the blood came from, after the tiles before it.
/obj/effect/decal/cleanable/blood/hv_spray/proc/hv_vis_paint_in(spray_dir)
	var/dx = HV_VIS_DX(spray_dir)
	var/dy = HV_VIS_DY(spray_dir)
	var/full_alpha = alpha
	var/matrix/base = matrix(transform)
	var/matrix/start
	if(dx || dy)
		// Squeezed against the edge the blood came in over.
		start = hv_vis_local(base, dx ? 0.3 : 1, dy ? 0.3 : 1, 0, -dx * 16 * 0.7, -dy * 16 * 0.7)
	else
		start = hv_vis_local(base, 0.3, 0.3)
	animate(src, alpha = 0, transform = start, time = 0, tag = HV_VIS_TAG_PAINT)
	animate(alpha = 0, transform = start, time = hv_vis_spray_step * HV_VIS_SPRAY_STEP)
	animate(alpha = full_alpha, transform = base, time = HV_VIS_SPRAY_PAINT, easing = QUAD_EASING|EASE_OUT)

/obj/effect/decal/cleanable/blood/hv_spray/wall/hv_aim(spray_dir)
	. = ..()
	if(!hv_vis_fresh)
		return
	hv_vis_fresh = FALSE
	hv_vis_drip()

/// The smear lands short, hanging from its top edge, and runs down the wall to its full length.
/obj/effect/decal/cleanable/blood/hv_spray/wall/proc/hv_vis_drip()
	var/full_alpha = alpha
	var/matrix/base = matrix(transform)
	// Shortened from the top edge, which stays where it is.
	var/matrix/splash = hv_vis_local(base, 1, 0.5, 0, 0, 16 * 0.5)
	var/matrix/running = hv_vis_local(base, 1, 0.72, 0, 0, 16 * 0.28)
	animate(src, alpha = 0, transform = splash, time = 0, tag = HV_VIS_TAG_PAINT)
	animate(alpha = 0, transform = splash, time = (hv_vis_spray_step + 1) * HV_VIS_SPRAY_STEP)
	animate(alpha = full_alpha, transform = running, time = 1.5, easing = QUAD_EASING|EASE_OUT)
	animate(alpha = full_alpha, transform = base, time = HV_VIS_DRIP_TIME, easing = SINE_EASING|EASE_IN)

// ---- Pools ----

/// How big each pool size is drawn, by its longest reach from the middle, for spreading from one to the next.
GLOBAL_LIST_INIT(hv_vis_pool_reach, list(10, 15, 26, 29))

/obj/effect/decal/cleanable/blood/hv_pool_show(state)
	var/old_tier = icon == HV_BLOOD_POOL_ICON ? hv_vis_pool_state_tier(icon_state) : 0
	// A pool is shown again every time more blood lands on it; only a picture that changed animates.
	var/was_shown = icon == HV_BLOOD_POOL_ICON && icon_state == state
	var/was_lobe = icon == HV_BLOOD_POOL_ICON && findtext(icon_state, "lobe") == 1
	. = ..()
	if(QDELETED(src) || dried || was_shown)
		return
	if(findtext(state, "lobe") == 1)
		// Only a lobe that is new on this tile flows out; a bigger lobe replacing a smaller one just shows.
		if(was_lobe || old_tier)
			return
		hv_vis_lobe_creep()
		return
	var/new_tier = hv_vis_pool_state_tier(state)
	if(!new_tier || new_tier <= old_tier)
		return
	// A plain splatter reaches about as far as the smallest pool's middle.
	var/old_reach = old_tier ? GLOB.hv_vis_pool_reach[old_tier] : 7
	hv_vis_pool_creep(old_reach / GLOB.hv_vis_pool_reach[new_tier])

/// The pool size a pool_art state shows, or 0.
/proc/hv_vis_pool_state_tier(state)
	if(!istext(state) || findtext(state, "pool") != 1)
		return 0
	return clamp(text2num(copytext(state, 5, 6)) || 0, 0, length(GLOB.hv_vis_pool_reach))

/// Spreads the pool out from `start_scale` of its size.
/obj/effect/decal/cleanable/blood/proc/hv_vis_pool_creep(start_scale)
	var/matrix/base = matrix(transform)
	animate(src, transform = hv_vis_local(base, start_scale, start_scale), time = 0, tag = HV_VIS_TAG_PAINT)
	animate(transform = base, time = HV_VIS_POOL_CREEP, easing = SINE_EASING|EASE_OUT)

/// The end of a pool running onto this tile flows out from the pool's side.
/obj/effect/decal/cleanable/blood/proc/hv_vis_lobe_creep()
	if(!hv_pool_lobe_dir)
		return
	// The pool's middle, from this tile's.
	var/from_x = -HV_VIS_DX(hv_pool_lobe_dir) * 32
	var/from_y = -HV_VIS_DY(hv_pool_lobe_dir) * 32
	var/scale = 0.3
	var/matrix/base = matrix(transform)
	var/matrix/start = hv_vis_local(base, scale, scale, 0, from_x * (1 - scale), from_y * (1 - scale))
	var/full_alpha = alpha
	animate(src, transform = start, alpha = 0, time = 0, tag = HV_VIS_TAG_PAINT)
	animate(transform = start, alpha = 0, time = HV_VIS_POOL_CREEP * 0.5)
	animate(transform = base, alpha = full_alpha, time = HV_VIS_LOBE_CREEP, easing = SINE_EASING|EASE_OUT)

// ---- Zero gravity ----

/obj/effect/decal/cleanable/blood/hv_blood_float_begin()
	var/was_floating = hv_floating
	. = ..()
	if(!was_floating && hv_floating && !QDELETED(src))
		hv_vis_drift()

/// Drifts off the wound in some direction, turning over once, and sometimes sheds a smaller bead.
/// The drift stays: floating blood hangs wherever it drifted to, until it lands.
/obj/effect/decal/cleanable/blood/proc/hv_vis_drift()
	var/angle = rand(0, 359)
	var/distance = rand(HV_VIS_DRIFT_MIN, HV_VIS_DRIFT_MAX)
	var/end_w = round(distance * sin(angle))
	var/end_z = round(distance * cos(angle))
	animate(src, pixel_w = end_w, pixel_z = end_z, time = 2 SECONDS, easing = SINE_EASING|EASE_OUT, tag = HV_VIS_TAG_DRIFT)
	hv_vis_play(HV_VIS_TAG_SPIN, hv_vis_spin_steps(src, 1, 2 SECONDS, pick(-1, 1)))
	if(prob(50))
		new /obj/effect/temp_visual/hv_blood_bead(loc, icon_state, color, end_w, end_z)

/obj/effect/decal/cleanable/blood/hv_blood_land()
	if(hv_floating)
		hv_vis_stop(list(HV_VIS_TAG_DRIFT, HV_VIS_TAG_SPIN))
		pixel_w = 0
		pixel_z = 0
	return ..()

/// A small bead of blood split off a floating globule, drifting the other way as it fades. away_w and
/// away_z are the way the globule drifts.
/obj/effect/temp_visual/hv_blood_bead
	name = "blood"
	icon = HV_BLOOD_FLOAT_ICON
	icon_state = "float1"
	plane = GAME_PLANE
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 2 SECONDS

/obj/effect/temp_visual/hv_blood_bead/Initialize(mapload, state, bead_color, away_w = 0, away_z = 0)
	. = ..()
	if(state)
		icon_state = state
	if(bead_color && !islist(bead_color))
		color = bead_color
	var/matrix/small = matrix()
	small.Scale(0.5)
	transform = small
	var/matrix/gone = matrix()
	gone.Scale(0.3)
	gone.Turn(pick(-1, 1) * 160)
	// Off the other way from the globule it split from.
	animate(src, pixel_w = -round(away_w * 0.8) + rand(-2, 2), pixel_z = -round(away_z * 0.8) + rand(-2, 2), transform = gone, alpha = 0, time = duration, easing = SINE_EASING|EASE_OUT)
