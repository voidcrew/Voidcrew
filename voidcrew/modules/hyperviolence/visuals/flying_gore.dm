// Hyperviolence visuals: flying gore.
// 8. A severed limb or head flies the way the blow went (tg sends it off in a random direction), slowly
//    enough to see: up in an arc from where it was on the body, spinning, leaving a blood streak on each
//    tile it crosses; it bounces once where it lands, and a head rolls on.
// 9. A burst head's brain arcs out spinning and lands with a wet bounce. Its gibs arc as they fly.
// In zero gravity nothing arcs or bounces: a part just turns slowly as it goes, and leaves no streak.
//
// None of it is thrown. tg's throw hits whatever is in the way: a limb hurts whoever it lands on and
// shoves them a tile, a head can knock its own killer off the body, and anyone in throw mode catches a
// brain. A part here flies by plain steps along a path worked out as it comes off (hv_vis_fling_path()):
// it stops short of anything solid and of anyone on their feet, and touches nobody. tg's dismember()
// still asks for its throw at the end; a part marked to tumble turns that into a flight
// (/obj/item/bodypart/throw_at() below).

/// Set while a burst head throws its gibs, so they arc: where the head is drawn on its tile
/// (list(x, y) in pixels from the middle), which is where they start from.
GLOBAL_LIST(hv_vis_arcing_gibs)

/obj/item
	/// Hyperviolence visuals: set just before a body part or organ comes off a body, so it tumbles as
	/// it flies (HV_VIS_TUMBLE_*). Used up by the flight.
	var/hv_vis_tumble
	/// The way to fling it. Used up by the flight.
	var/hv_vis_fling_dir
	/// The blood it streaks along its way. Used up by the flight.
	var/list/hv_vis_tumble_dna
	/// Where on the body it was, in pixels from the middle of the tile (list(x, y)): the flight starts
	/// there. Used up by the flight.
	var/list/hv_vis_fling_from

/// Forgets a fling that was marked on this part.
/obj/item/proc/hv_vis_forget_fling()
	hv_vis_tumble = null
	hv_vis_fling_dir = null
	hv_vis_tumble_dna = null
	hv_vis_fling_from = null

/// How this kind of part tumbles when nothing marked it (HV_VIS_TUMBLE_*).
/obj/item/proc/hv_vis_tumble_style()
	return HV_VIS_TUMBLE_ORGAN

/obj/item/bodypart/hv_vis_tumble_style()
	return HV_VIS_TUMBLE_LIMB

/obj/item/bodypart/head/hv_vis_tumble_style()
	return HV_VIS_TUMBLE_HEAD

/obj/item/organ/brain/hv_vis_tumble_style()
	return HV_VIS_TUMBLE_BRAIN

/**
 * Flies this loose part up to `distance` tiles along `fling_dir`, tumbling. Not a throw (see the top of
 * this file): nothing on the way is hit. How it tumbles and the blood it streaks come from the marks
 * on it, or from what it is. `on_landed` is called when it comes to rest. The body of hv_fling()
 * (_core.dm). Returns TRUE if it took off.
 */
/obj/item/proc/hv_vis_fly(fling_dir, distance = 2, datum/callback/on_landed)
	var/style = hv_vis_tumble
	var/list/blood_dna = hv_vis_tumble_dna
	var/list/from = hv_vis_fling_from
	hv_vis_forget_fling()
	if(QDELETED(src) || !isturf(loc))
		return FALSE
	if(!style || style == HV_VIS_TUMBLE_NONE)
		style = hv_vis_tumble_style()
	if(!fling_dir)
		fling_dir = pick(GLOB.alldirs)
	var/list/turf/path = hv_vis_fling_path(loc, fling_dir, distance)
	// Where it will lie on its last tile is settled now, so nothing jumps when it lands. With nowhere to
	// go it comes down on the side of its tile it was heading for.
	if(!pixel_x && !pixel_y && !(item_flags & NO_PIXEL_RANDOM_DROP))
		if(length(path))
			pixel_x = base_pixel_x + rand(-6, 6)
			pixel_y = base_pixel_y + rand(-6, 6)
		else
			pixel_x = base_pixel_x + HV_VIS_DX(fling_dir) * 7 + rand(-3, 3)
			pixel_y = base_pixel_y + HV_VIS_DY(fling_dir) * 7 + rand(-3, 3)
	var/datum/component/hv_tumble/tumble = AddComponent(/datum/component/hv_tumble, style, blood_dna, fling_dir, path, on_landed, from)
	tumble.launch()
	return TRUE

/// The tiles a part flung from `start` along `fling_dir` crosses, nearest first, up to `distance` of them.
/proc/hv_vis_fling_path(turf/start, fling_dir, distance)
	var/list/turf/path = list()
	var/turf/here = start
	for(var/i in 1 to distance)
		var/turf/next = get_step(here, fling_dir)
		if(!hv_vis_can_fly_onto(here, next))
			break
		path += next
		here = next
	return path

/// Whether a flying part can go from `here` onto `next`: open floor on the same level, not space, lava
/// or a chasm, nothing solid on it or between the two (a window, a door, a table), and nobody on their feet.
/proc/hv_vis_can_fly_onto(turf/here, turf/next)
	if(!here || !next || next.z != here.z || isgroundlessturf(next) || islava(next) || ischasm(next))
		return FALSE
	if(next.is_blocked_turf(exclude_mobs = TRUE) || !here.Adjacent(next))
		return FALSE
	for(var/mob/living/in_the_way in next)
		if(in_the_way.density)
			return FALSE
	return TRUE

/// tg's dismember() ends by throwing the limb. One marked to tumble flies instead; one marked to stay
/// put (a head that bursts where it is) goes nowhere.
/obj/item/bodypart/throw_at(atom/target, range, speed, mob/thrower, spin = 1, diagonals_first = 0, datum/callback/callback, force, gentle = FALSE, quickstart = TRUE, throw_type_path = /datum/thrownthing)
	if(!hv_vis_tumble)
		return ..()
	if(hv_vis_tumble == HV_VIS_TUMBLE_NONE)
		hv_vis_forget_fling()
		return FALSE
	var/fling_dir = hv_vis_fling_dir || get_dir(src, target) || pick(GLOB.cardinals)
	var/distance = hv_vis_tumble == HV_VIS_TUMBLE_SLIDE ? 1 : max(get_dist(src, target), 2)
	return hv_vis_fly(fling_dir, distance, callback)

/**
 * A part flying off a body: the steps along its path, the arc, the spin, the blood along the way, the
 * landing. On the part for the length of the flight only; gone once it lands, if anything else moves it
 * (someone picks it up), or after a few seconds whatever happens.
 */
/datum/component/hv_tumble
	dupe_mode = COMPONENT_DUPE_HIGHLANDER
	/// HV_VIS_TUMBLE_*
	var/style
	/// Blood it streaks along its way, or null.
	var/list/blood_dna
	/// The way it was flung.
	var/fling_dir
	/// The tiles still ahead of it, nearest first.
	var/list/turf/path
	/// Called when it comes to rest.
	var/datum/callback/on_landed
	/// Where on the body it came from, in pixels from the middle of the tile, or null.
	var/list/from
	/// How long it takes to cross a tile.
	var/step_time = HV_VIS_TUMBLE_STEP
	/// Streaks left so far.
	var/streaks = 0
	/// Whether it flies where gravity pulls it down.
	var/grounded = TRUE
	/// The timer of its next step.
	var/step_timer
	/// Set while it takes one of its own steps, to tell those from anything else moving it.
	var/stepping = FALSE
	/// The layer it had before it took off.
	var/rest_layer

/datum/component/hv_tumble/Initialize(style, list/blood_dna, fling_dir, list/turf/path, datum/callback/on_landed, list/from)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	var/obj/item/part = parent
	src.style = style
	src.blood_dna = blood_dna
	src.fling_dir = fling_dir
	src.path = path || list()
	src.on_landed = on_landed
	src.from = from
	grounded = part.has_gravity() > 0
	// A slide along the floor is slower than a flight, and so is a drift with nothing to pull it down.
	if(style == HV_VIS_TUMBLE_SLIDE)
		step_time *= 2
	else if(!grounded)
		step_time *= 3
	rest_layer = part.layer
	addtimer(CALLBACK(src, PROC_REF(give_up)), 5 SECONDS, TIMER_DELETE_ME)

/datum/component/hv_tumble/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/datum/component/hv_tumble/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_MOVED)

/datum/component/hv_tumble/Destroy(force)
	if(step_timer)
		deltimer(step_timer)
		step_timer = null
	var/obj/item/part = parent
	if(!QDELETED(part) && !isnull(rest_layer) && part.layer == HV_VIS_TUMBLE_LAYER)
		part.layer = rest_layer
	blood_dna = null
	path = null
	on_landed = null
	from = null
	return ..()

/// How long the whole flight takes: the moment it hangs where it came off, then its steps. With nowhere
/// to go (someone or something right in its way) it only drops where the body stands.
/datum/component/hv_tumble/proc/flight_time()
	return length(path) ? world.tick_lag + length(path) * step_time : HV_VIS_TUMBLE_DROP

/// How high it rises on the way. A part that only drops barely rises at all.
/datum/component/hv_tumble/proc/arc_height()
	var/height = 0
	switch(style)
		if(HV_VIS_TUMBLE_HEAD)
			height = 12
		if(HV_VIS_TUMBLE_BRAIN)
			height = 14
		if(HV_VIS_TUMBLE_LIMB)
			height = 10
		if(HV_VIS_TUMBLE_ORGAN)
			height = 7
	return length(path) ? height : round(height * 0.3)

/// Takes off: starts the arc and the spin, and takes the first step a tick later. A part stepped in the
/// tick it comes off is first seen a whole tile from the body, already on its way; one that waits a tick
/// is seen where it was on the body first, and glides out from there. With nowhere to go it comes down
/// where it is once it has dropped.
/datum/component/hv_tumble/proc/launch()
	start_flight()
	step_timer = addtimer(CALLBACK(src, PROC_REF(take_step)), length(path) ? world.tick_lag : flight_time(), TIMER_STOPPABLE|TIMER_DELETE_ME)

/datum/component/hv_tumble/proc/start_flight()
	var/obj/item/part = parent
	var/matrix/base = matrix(part.transform)
	var/time = flight_time()
	// Where it was on the body, from where it will lie on its tile.
	var/from_w = from ? from[1] - (part.pixel_x - part.base_pixel_x) : 0
	var/from_z = from ? from[2] - (part.pixel_y - part.base_pixel_y) : 0
	if(style == HV_VIS_TUMBLE_SLIDE)
		// The legs of a body cut in half: a slide across the floor from where they were, with a slight turn.
		var/turn = pick(-1, 1) * 20
		var/list/pivot = part.hv_vis_spin_pivot()
		part.hv_vis_play(HV_VIS_TAG_SPIN, list(
			list(part.pixel_w + from_w, part.pixel_z + from_z, base, 0, LINEAR_EASING),
			list(part.pixel_w, part.pixel_z, hv_vis_turned(base, turn, pivot[2], pivot[1]), time, CUBIC_EASING|EASE_OUT),
			list(part.pixel_w, part.pixel_z, base, 4, SINE_EASING),
		))
		return
	if(!grounded)
		// Nothing to pull it down: it drifts straight out from where it was, turning slowly.
		if(from_w || from_z)
			part.hv_vis_play(HV_VIS_TAG_ARC, list(
				list(part.pixel_w + from_w, part.pixel_z + from_z, base, 0, LINEAR_EASING),
				list(part.pixel_w, part.pixel_z, base, time, LINEAR_EASING),
			))
		part.hv_vis_play(HV_VIS_TAG_SPIN, hv_vis_spin_steps(part, 2, 30, pick(-1, 1)))
		return
	// In the air it passes over bodies on the floor and behind anyone standing. A part tg already draws
	// over everyone (a brain, so it can be found) keeps its own layer.
	if(part.layer < HV_VIS_TUMBLE_LAYER)
		part.layer = HV_VIS_TUMBLE_LAYER
	var/height = arc_height()
	// From where it was on the body, over the top of the arc, down onto its own spot on the last tile.
	part.hv_vis_play(HV_VIS_TAG_ARC, list(
		list(part.pixel_w + from_w, part.pixel_z + from_z, base, 0, LINEAR_EASING),
		list(part.pixel_w + from_w / 2, part.pixel_z + from_z / 2 + height, base, time / 2, QUAD_EASING|EASE_OUT),
		list(part.pixel_w, part.pixel_z, base, time / 2, QUAD_EASING|EASE_IN),
	))
	// It tumbles as it flies; a part that only drops keeps the way it lies.
	if(!length(path))
		return
	var/turns = style == HV_VIS_TUMBLE_ORGAN ? 1 : 2
	part.hv_vis_play(HV_VIS_TAG_SPIN, hv_vis_spin_steps(part, turns, time, HV_VIS_DX(fling_dir) || pick(-1, 1)))

/// One tile further along its path, or down if there is no more of it or something got in the way.
/datum/component/hv_tumble/proc/take_step()
	step_timer = null
	var/obj/item/part = parent
	if(QDELETED(part) || !isturf(part.loc))
		give_up()
		return
	var/turf/next = length(path) ? path[1] : null
	if(!next || !hv_vis_can_fly_onto(part.loc, next))
		land()
		return
	path.Cut(1, 2)
	stepping = TRUE
	part.set_glide_size(DELAY_TO_GLIDE_SIZE(step_time))
	part.forceMove(next)
	stepping = FALSE
	if(QDELETED(src))
		return
	step_timer = addtimer(CALLBACK(src, PROC_REF(take_step)), step_time, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Blood on each tile it crosses. Anything else moving it (a hand, a conveyor) ends the flight.
/datum/component/hv_tumble/proc/on_moved(obj/item/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(!stepping)
		give_up()
		return
	if(!grounded || !length(blood_dna) || streaks >= HV_VIS_TUMBLE_MAX_STREAKS)
		return
	var/turf/crossed = old_loc
	if(!isturf(crossed) || isgroundlessturf(crossed) || crossed.has_gravity() <= 0)
		return
	streaks++
	// A few drops under it as it passes, not a line.
	var/obj/effect/decal/cleanable/blood/hv_spray/streak/trail = hv_blood_lay_spray(crossed, /obj/effect/decal/cleanable/blood/hv_spray/streak/drops, fling_dir, blood_dna)
	if(istype(trail))
		trail.hv_set_look(TRUE, rand(-3, 3))

/// It comes down: the bounce, a head's roll, and whoever asked to know.
/datum/component/hv_tumble/proc/land()
	var/obj/item/part = parent
	if(part.layer == HV_VIS_TUMBLE_LAYER)
		part.layer = rest_layer
	if(grounded && isturf(part.loc))
		switch(style)
			if(HV_VIS_TUMBLE_HEAD)
				part.hv_vis_play(HV_VIS_TAG_ARC, hv_vis_bounce_steps(part, 4))
				hv_vis_roll(part, fling_dir)
			if(HV_VIS_TUMBLE_BRAIN)
				part.hv_vis_play(HV_VIS_TAG_ARC, hv_vis_wet_bounce_steps(part))
			if(HV_VIS_TUMBLE_LIMB)
				part.hv_vis_play(HV_VIS_TAG_ARC, hv_vis_bounce_steps(part, 4))
			if(HV_VIS_TUMBLE_ORGAN)
				part.hv_vis_play(HV_VIS_TAG_ARC, hv_vis_bounce_steps(part, 2))
	var/datum/callback/landed = on_landed
	on_landed = null
	qdel(src)
	landed?.Invoke()

/// Something else has the part now, or the flight never ended: let it go as it is.
/datum/component/hv_tumble/proc/give_up()
	var/obj/item/part = parent
	if(!QDELETED(part))
		part.hv_vis_stop(list(HV_VIS_TAG_ARC, HV_VIS_TAG_SPIN))
	qdel(src)

/// Where this thing's picture sits inside its icon, in pixels from the middle: list(x, y). A turn has to be
/// about that point, or the picture swings round the middle of the icon instead of turning on the spot.
/atom/movable/proc/hv_vis_spin_pivot()
	return list(0, 0)

/// tg draws a severed limb shifted (px_x, px_y) so that it sits on the middle of its tile: the limb
/// itself is drawn that far the other way inside its icon.
/obj/item/bodypart/hv_vis_spin_pivot()
	return list(-px_x, -px_y)

/// `turns` whole turns over `time`, clockwise for `spin_sign` 1, ending where the part started.
/proc/hv_vis_spin_steps(atom/movable/part, turns, time, spin_sign = 1)
	var/matrix/base = matrix(part.transform)
	var/list/pivot = part.hv_vis_spin_pivot()
	var/list/steps = list()
	var/segments = max(3, turns * 3)
	for(var/i in 1 to segments)
		var/matrix/turned = i == segments ? matrix(base) : hv_vis_turned(base, spin_sign * 120 * i, pivot[2], pivot[1])
		steps += list(list(part.pixel_w, part.pixel_z, turned, time / segments, LINEAR_EASING))
	return steps

/// One bounce off the floor, `height` pixels.
/proc/hv_vis_bounce_steps(atom/movable/part, height)
	var/matrix/base = matrix(part.transform)
	return list(
		list(part.pixel_w, part.pixel_z + height, base, 1, QUAD_EASING|EASE_OUT),
		list(part.pixel_w, part.pixel_z, base, 1.5, BOUNCE_EASING),
	)

/// A brain hitting the floor: it squashes flat, springs up, squashes again and wobbles still.
/proc/hv_vis_wet_bounce_steps(atom/movable/part)
	var/matrix/base = matrix(part.transform)
	// Squashed from the bottom edge, so it spreads on the floor rather than sinking into it.
	var/matrix/flat = hv_vis_local(base, 1.3, 0.7, 0, 0, -16 * 0.3)
	var/matrix/tall = hv_vis_local(base, 0.85, 1.15, 0, 0, 16 * 0.15)
	var/matrix/settle = hv_vis_local(base, 1.12, 0.88, 0, 0, -16 * 0.12)
	return list(
		list(part.pixel_w, part.pixel_z, flat, 0.5, QUAD_EASING|EASE_OUT),
		list(part.pixel_w, part.pixel_z + 4, tall, 1.5, QUAD_EASING|EASE_OUT),
		list(part.pixel_w, part.pixel_z, settle, 1.5, QUAD_EASING|EASE_IN),
		list(part.pixel_w, part.pixel_z, base, 2, ELASTIC_EASING),
	)

/// A head rolling on after it lands: one turn, a few pixels further along. It keeps its new spot on
/// the tile, as any dropped item does.
/proc/hv_vis_roll(obj/item/part, roll_dir)
	var/dx = HV_VIS_DX(roll_dir)
	var/dy = HV_VIS_DY(roll_dir)
	var/spin = dx || pick(-1, 1)
	var/end_x = clamp(part.pixel_x + dx * 6, -12, 12)
	var/end_y = clamp(part.pixel_y + dy * 6, -12, 12)
	var/matrix/base = matrix(part.transform)
	var/list/pivot = part.hv_vis_spin_pivot()
	var/start_x = part.pixel_x
	var/start_y = part.pixel_y
	animate(part, pixel_x = start_x, pixel_y = start_y, transform = base, time = 2.5, tag = HV_VIS_TAG_SPIN)
	animate(pixel_x = start_x + (end_x - start_x) / 3, pixel_y = start_y + (end_y - start_y) / 3, transform = hv_vis_turned(base, spin * 120, pivot[2], pivot[1]), time = 1.5, easing = LINEAR_EASING)
	animate(pixel_x = start_x + (end_x - start_x) * 2 / 3, pixel_y = start_y + (end_y - start_y) * 2 / 3, transform = hv_vis_turned(base, spin * 240, pivot[2], pivot[1]), time = 2, easing = LINEAR_EASING)
	animate(pixel_x = end_x, pixel_y = end_y, transform = base, time = 3, easing = QUAD_EASING|EASE_OUT)

// ---- Limbs and heads coming off ----

/// Whether this part, coming off, stays where the body is rather than flying.
/obj/item/bodypart/proc/hv_vis_stays_put()
	return FALSE

/// A head that bursts comes apart where it is (braingut/brain_burst.dm).
/obj/item/bodypart/head/hv_vis_stays_put()
	return hv_bursting

/// A limb or head taken off whole flies the way the blow went, tumbling. Burned-off parts and the
/// chest (which spills, braingut/gut_spill.dm) are left to tg.
/obj/item/bodypart/dismember(dam_type = BRUTE, silent = TRUE, wounding_type)
	var/mob/living/carbon/limb_owner = owner
	var/marked = FALSE
	if(limb_owner && dam_type != BURN && body_zone != BODY_ZONE_CHEST)
		marked = TRUE
		if(hv_vis_stays_put())
			hv_vis_tumble = HV_VIS_TUMBLE_NONE
		else if(!hv_vis_tumble)
			hv_vis_tumble = hv_vis_tumble_style()
		if(!hv_vis_fling_dir)
			hv_vis_fling_dir = limb_owner.hv_blood_recent_hit_dir()
		if(!hv_vis_tumble_dna && can_bleed())
			hv_vis_tumble_dna = limb_owner.get_blood_dna_list()
		if(!hv_vis_fling_from)
			hv_vis_fling_from = limb_owner.hv_vis_part_offset(body_zone)
	. = ..()
	// Not sent flying after all (it burned away, or it was never let go): forget the fling.
	if(marked && !QDELETED(src))
		hv_vis_forget_fling()

/**
 * Where the part at `zone` is drawn on this body as it faces and lies now, in pixels from the middle of
 * its tile: list(x, y). Left and right swap on screen when a body turns, a body seen side-on has both
 * arms and legs on its middle line, and a body on the floor is turned onto its side.
 */
/mob/living/carbon/proc/hv_vis_part_offset(zone)
	var/x = 0
	var/y = 0
	var/side = hv_vis_zone_side(zone)
	// Measured off the human body sprites (icons/mob/human/bodyparts_greyscale.dmi), each facing.
	switch(zone)
		if(BODY_ZONE_HEAD)
			y = 9
		if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
			// Side-on, the arm we can see hangs a little behind the middle of the body.
			x = side ? side * 6 : -HV_VIS_DX(dir) * 3
			y = 1
		if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			x = side * 3
			y = -12
	// tg lays a body down by turning it clockwise.
	switch(lying_angle)
		if(90)
			. = list(y, -x)
		if(270)
			. = list(-y, x)
		else
			. = list(x, y)
	.[2] += pixel_y - base_pixel_y

// ---- Burst heads ----

/// The brain and the other loose organs of a burst head tumble out, the gibs arc, and the blow gets a hit-stop.
/mob/living/carbon/hv_burst_head_apart(burst_dir, announce = TRUE)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	var/list/obj/item/organ/marked = list()
	if(head?.can_dismember() && !HAS_TRAIT(src, TRAIT_GODMODE))
		var/list/blood_dna = can_bleed() ? get_blood_dna_list() : null
		// Everything comes out of the head, wherever that is on a body standing or lying.
		var/list/head_at = hv_vis_part_offset(BODY_ZONE_HEAD)
		for(var/obj/item/organ/organ in head)
			organ.hv_vis_tumble = organ.hv_vis_tumble_style()
			organ.hv_vis_tumble_dna = blood_dna
			organ.hv_vis_fling_from = head_at
			marked += organ
		GLOB.hv_vis_arcing_gibs = head_at
		// Before the burst, so the death it causes sees the blow was a big one.
		hv_vis_big_hit(burst_dir)
	. = ..()
	GLOB.hv_vis_arcing_gibs = null
	for(var/obj/item/organ/organ as anything in marked)
		if(!QDELETED(organ))
			organ.hv_vis_forget_fling()

/// Gibs thrown by a burst head leave from the head, rise and fall as they fly, and turn over once.
/obj/effect/decal/cleanable/blood/gibs/streak(list/directions, mapload = FALSE)
	var/list/head_at = mapload ? null : GLOB.hv_vis_arcing_gibs
	var/turf/thrown_from = head_at ? get_turf(src) : null
	. = ..()
	if(head_at && !QDELETED(src) && isturf(loc) && has_gravity() > 0)
		var/matrix/base = matrix(transform)
		var/height = rand(8, 14)
		// tg steps a gib off its tile the moment it is made, so it is first seen on the next one: the arc
		// starts back at the head it came out of.
		var/from_w = head_at[1] + (thrown_from ? (thrown_from.x - x) * ICON_SIZE_X : 0)
		var/from_z = head_at[2] + (thrown_from ? (thrown_from.y - y) * ICON_SIZE_Y : 0)
		hv_vis_play(HV_VIS_TAG_ARC, list(
			list(pixel_w + from_w, pixel_z + from_z, base, 0, LINEAR_EASING),
			list(pixel_w + from_w / 2, pixel_z + from_z / 2 + height, base, 2, QUAD_EASING|EASE_OUT),
			list(pixel_w, pixel_z, base, 2.5, QUAD_EASING|EASE_IN),
			list(pixel_w, pixel_z + 2, base, 0.7, QUAD_EASING|EASE_OUT),
			list(pixel_w, pixel_z, base, 1.5, BOUNCE_EASING),
		))
		// One whole turn over the flight, so it lands as it lies: no turning back at the end.
		hv_vis_play(HV_VIS_TAG_SPIN, hv_vis_spin_steps(src, 1, 4.5, pick(-1, 1)))
