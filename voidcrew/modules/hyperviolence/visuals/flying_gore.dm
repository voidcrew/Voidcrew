// Hyperviolence visuals: flying gore.
// 8. A severed limb or head flies the way the blow went (tg throws it in a random direction), slowly
//    enough to see: up in an arc, spinning, leaving a blood streak on each tile it crosses; it bounces
//    once where it lands, and a head rolls on.
// 9. A burst head's brain arcs out spinning and lands with a wet bounce. Its gibs arc as they fly.
// 10. A wound bleeding hard enough spurts with the heartbeat: a jet from that side of the body, two or
//     three beats between Life ticks, quicker and weaker as the blood runs out. Nothing while the heart
//     is stopped.
// In zero gravity nothing arcs or bounces: a part just turns slowly as it drifts, and leaves no streak.

/// Set while a burst head throws its gibs, so they arc.
GLOBAL_VAR_INIT(hv_vis_arcing_gibs, FALSE)

/obj/item
	/// Hyperviolence visuals: set just before a body part or organ is thrown off a body, so the throw
	/// tumbles it (HV_VIS_TUMBLE_*). Used up by the throw.
	var/hv_vis_tumble
	/// The way to fling it, in place of the throw's own target. Used up by the throw.
	var/hv_vis_fling_dir
	/// The blood it streaks along its way. Used up by the throw.
	var/list/hv_vis_tumble_dna

/obj/item/throw_at(atom/target, range, speed, mob/thrower, spin = 1, diagonals_first = 0, datum/callback/callback, force, gentle = FALSE, quickstart = TRUE, throw_type_path = /datum/thrownthing)
	if(!hv_vis_tumble)
		return ..()
	var/style = hv_vis_tumble
	var/list/blood_dna = hv_vis_tumble_dna
	var/fling_dir = hv_vis_fling_dir
	hv_vis_tumble = null
	hv_vis_tumble_dna = null
	hv_vis_fling_dir = null
	if(fling_dir)
		target = hv_vis_fling_target(target, fling_dir, style == HV_VIS_TUMBLE_SLIDE ? 1 : 0)
	speed = style == HV_VIS_TUMBLE_SLIDE ? 0.5 : min(speed, HV_VIS_TUMBLE_SPEED)
	// Our own spin replaces tg's single quick turn. No quick start: the tumble has to be listening
	// before the first step, to streak the tile the part leaves.
	. = ..(target, range, speed, thrower, FALSE, diagonals_first, callback, force, gentle, FALSE, throw_type_path)
	if(throwing && !QDELETED(src))
		AddComponent(/datum/component/hv_tumble, style, blood_dna, fling_dir || get_dir(src, target))

/// Where to fling this along `fling_dir`, as far as `original` was (or `distance` tiles): the farthest
/// open tile on the way. Stops before space, lava or a chasm, and at the first wall, as tg's own fling
/// does. Falls back to `original` if there is nowhere to go.
/obj/item/proc/hv_vis_fling_target(atom/original, fling_dir, distance = 0)
	var/turf/start = get_turf(src)
	if(!start)
		return original
	if(!distance)
		distance = max(get_dist(start, original), 2)
	var/turf/landing
	var/turf/ahead = start
	for(var/i in 1 to distance)
		ahead = get_step(ahead, fling_dir)
		if(!ahead || isgroundlessturf(ahead) || islava(ahead) || ischasm(ahead))
			break
		landing = ahead
		if(ahead.density)
			break
	return landing || original

/**
 * A part flying off a body: the arc, the spin, the blood along the way, the landing. On the thrown
 * item for the length of the throw only; gone once it lands, or after a few seconds whatever happens.
 */
/datum/component/hv_tumble
	dupe_mode = COMPONENT_DUPE_HIGHLANDER
	/// HV_VIS_TUMBLE_*
	var/style
	/// Blood it streaks along its way, or null.
	var/list/blood_dna
	/// The way it was flung.
	var/fling_dir
	/// Streaks left so far.
	var/streaks = 0
	/// Whether it was thrown where gravity pulls it down.
	var/grounded = TRUE

/datum/component/hv_tumble/Initialize(style, list/blood_dna, fling_dir)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE
	var/obj/item/part = parent
	src.style = style
	src.blood_dna = blood_dna
	src.fling_dir = fling_dir
	grounded = part.has_gravity() > 0
	addtimer(CALLBACK(src, PROC_REF(give_up)), 5 SECONDS, TIMER_DELETE_ME)
	start_flight()

/datum/component/hv_tumble/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_MOVABLE_THROW_LANDED, PROC_REF(on_landed))

/datum/component/hv_tumble/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_THROW_LANDED))

/datum/component/hv_tumble/Destroy(force)
	blood_dna = null
	return ..()

/// How long the flight should take, from the throw under way.
/datum/component/hv_tumble/proc/flight_time()
	var/obj/item/part = parent
	var/datum/thrownthing/flight = part.throwing
	if(!flight)
		return 2
	var/distance = max(get_dist(part, flight.target_turf), 1)
	return max(distance / max(flight.speed, 0.5), 1.5)

/// How high it rises on the way.
/datum/component/hv_tumble/proc/arc_height()
	switch(style)
		if(HV_VIS_TUMBLE_HEAD)
			return 12
		if(HV_VIS_TUMBLE_BRAIN)
			return 14
		if(HV_VIS_TUMBLE_LIMB)
			return 10
		if(HV_VIS_TUMBLE_ORGAN)
			return 7
	return 0

/datum/component/hv_tumble/proc/start_flight()
	var/obj/item/part = parent
	var/matrix/base = matrix(part.transform)
	var/time = flight_time()
	if(style == HV_VIS_TUMBLE_SLIDE)
		// The legs of a body cut in half: a slide across the floor with a slight turn.
		var/turn = pick(-1, 1) * 20
		part.hv_vis_play(HV_VIS_TAG_SPIN, list(
			list(part.pixel_w, part.pixel_z, hv_vis_turned(base, turn), time, CUBIC_EASING|EASE_OUT),
			list(part.pixel_w, part.pixel_z, base, 4, SINE_EASING),
		))
		return
	if(!grounded)
		part.hv_vis_play(HV_VIS_TAG_SPIN, hv_vis_spin_steps(part, 2, 30, pick(-1, 1)))
		return
	var/height = arc_height()
	part.hv_vis_play(HV_VIS_TAG_ARC, list(
		list(part.pixel_w, part.pixel_z + height, base, time / 2, QUAD_EASING|EASE_OUT),
		list(part.pixel_w, part.pixel_z, base, time / 2, QUAD_EASING|EASE_IN),
	))
	var/turns = style == HV_VIS_TUMBLE_ORGAN ? 1 : 2
	part.hv_vis_play(HV_VIS_TAG_SPIN, hv_vis_spin_steps(part, turns, time + 1, HV_VIS_DX(fling_dir) || pick(-1, 1)))

/// Blood on each tile it crosses, until it lands.
/datum/component/hv_tumble/proc/on_moved(obj/item/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(!grounded || !length(blood_dna) || streaks >= HV_VIS_TUMBLE_MAX_STREAKS || !source.throwing)
		return
	var/turf/crossed = old_loc
	if(!isturf(crossed) || isgroundlessturf(crossed) || crossed.has_gravity() <= 0)
		return
	streaks++
	hv_blood_lay_spray(crossed, /obj/effect/decal/cleanable/blood/hv_spray/streak, movement_dir || fling_dir, blood_dna)

/datum/component/hv_tumble/proc/on_landed(obj/item/source, datum/thrownthing/flight)
	SIGNAL_HANDLER
	if(grounded && isturf(source.loc))
		switch(style)
			if(HV_VIS_TUMBLE_HEAD)
				source.hv_vis_play(HV_VIS_TAG_ARC, hv_vis_bounce_steps(source, 4))
				hv_vis_roll(source, fling_dir)
			if(HV_VIS_TUMBLE_BRAIN)
				source.hv_vis_play(HV_VIS_TAG_ARC, hv_vis_wet_bounce_steps(source))
			if(HV_VIS_TUMBLE_LIMB)
				source.hv_vis_play(HV_VIS_TAG_ARC, hv_vis_bounce_steps(source, 4))
			if(HV_VIS_TUMBLE_ORGAN)
				source.hv_vis_play(HV_VIS_TAG_ARC, hv_vis_bounce_steps(source, 2))
	qdel(src)

/datum/component/hv_tumble/proc/give_up()
	qdel(src)

/// `turns` whole turns over `time`, clockwise for `spin_sign` 1, ending where the part started.
/proc/hv_vis_spin_steps(atom/movable/part, turns, time, spin_sign = 1)
	var/matrix/base = matrix(part.transform)
	var/list/steps = list()
	var/segments = max(3, turns * 3)
	for(var/i in 1 to segments)
		var/matrix/turned = i == segments ? matrix(base) : hv_vis_turned(base, spin_sign * 120 * i)
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
	var/start_x = part.pixel_x
	var/start_y = part.pixel_y
	animate(part, pixel_x = start_x, pixel_y = start_y, transform = base, time = 2.5, tag = HV_VIS_TAG_SPIN)
	animate(pixel_x = start_x + (end_x - start_x) / 3, pixel_y = start_y + (end_y - start_y) / 3, transform = hv_vis_turned(base, spin * 120), time = 1.5, easing = LINEAR_EASING)
	animate(pixel_x = start_x + (end_x - start_x) * 2 / 3, pixel_y = start_y + (end_y - start_y) * 2 / 3, transform = hv_vis_turned(base, spin * 240), time = 2, easing = LINEAR_EASING)
	animate(pixel_x = end_x, pixel_y = end_y, transform = base, time = 3, easing = QUAD_EASING|EASE_OUT)

// ---- Limbs and heads coming off ----

/// A limb or head taken off whole flies the way the blow went, tumbling. Burned-off parts and the
/// chest (which spills, braingut/gut_spill.dm) are left to tg.
/obj/item/bodypart/dismember(dam_type = BRUTE, silent = TRUE, wounding_type)
	var/mob/living/carbon/limb_owner = owner
	var/marked = FALSE
	if(limb_owner && dam_type != BURN && body_zone != BODY_ZONE_CHEST)
		marked = TRUE
		if(!hv_vis_tumble)
			hv_vis_tumble = body_zone == BODY_ZONE_HEAD ? HV_VIS_TUMBLE_HEAD : HV_VIS_TUMBLE_LIMB
		if(!hv_vis_fling_dir)
			hv_vis_fling_dir = limb_owner.hv_blood_recent_hit_dir()
		if(!hv_vis_tumble_dna && can_bleed())
			hv_vis_tumble_dna = limb_owner.get_blood_dna_list()
	. = ..()
	// Not thrown after all (it burned away, or it was never let go): forget the fling.
	if(marked && !QDELETED(src) && !throwing)
		hv_vis_tumble = null
		hv_vis_fling_dir = null
		hv_vis_tumble_dna = null

// ---- Burst heads ----

/// The brain and the other loose organs of a burst head tumble out, the gibs arc, and the blow gets a hit-stop.
/mob/living/carbon/hv_burst_head_apart(burst_dir, announce = TRUE)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	var/list/obj/item/organ/marked = list()
	if(head?.can_dismember() && !HAS_TRAIT(src, TRAIT_GODMODE))
		var/list/blood_dna = can_bleed() ? get_blood_dna_list() : null
		for(var/obj/item/organ/organ in head)
			organ.hv_vis_tumble = istype(organ, /obj/item/organ/brain) ? HV_VIS_TUMBLE_BRAIN : HV_VIS_TUMBLE_ORGAN
			organ.hv_vis_tumble_dna = blood_dna
			marked += organ
		// Before the burst, so the death it causes sees the blow was a big one.
		hv_vis_big_hit(burst_dir)
	GLOB.hv_vis_arcing_gibs = TRUE
	. = ..()
	GLOB.hv_vis_arcing_gibs = FALSE
	for(var/obj/item/organ/organ as anything in marked)
		if(!QDELETED(organ) && !organ.throwing)
			organ.hv_vis_tumble = null
			organ.hv_vis_tumble_dna = null

/// Gibs thrown by a burst head rise and fall as they fly, turning over.
/obj/effect/decal/cleanable/blood/gibs/streak(list/directions, mapload = FALSE)
	var/arcing = GLOB.hv_vis_arcing_gibs && !mapload
	. = ..()
	if(arcing && !QDELETED(src) && isturf(loc) && has_gravity() > 0)
		var/matrix/base = matrix(transform)
		var/height = rand(8, 14)
		var/turn = pick(-1, 1) * rand(90, 200)
		hv_vis_play(HV_VIS_TAG_ARC, list(
			list(pixel_w, pixel_z + height, hv_vis_turned(base, turn / 2), 2, QUAD_EASING|EASE_OUT),
			list(pixel_w, pixel_z, hv_vis_turned(base, turn), 2.5, QUAD_EASING|EASE_IN),
			list(pixel_w, pixel_z + 2, hv_vis_turned(base, turn), 0.7, QUAD_EASING|EASE_OUT),
			list(pixel_w, pixel_z, base, 1.5, BOUNCE_EASING),
		))

// ---- Arterial spurts ----

/mob/living/carbon
	/// World time before which this body does not spurt again.
	var/hv_vis_next_spurt = 0

/mob/living/carbon/human/bleed(amt)
	. = ..()
	hv_vis_arterial_spurt()

/// The wound bleeding hard enough to spurt, the worst if several, or null.
/mob/living/carbon/proc/hv_vis_arterial_wound()
	var/datum/wound/worst
	for(var/datum/wound/wound as anything in all_wounds)
		if(wound.blood_flow < HV_VIS_ARTERIAL_FLOW || !wound.limb)
			continue
		if(!worst || wound.blood_flow > worst.blood_flow)
			worst = wound
	return worst

/// A spurt from the worst wound, beating with the heart, at most once per Life tick.
/mob/living/carbon/proc/hv_vis_arterial_spurt()
	if(world.time < hv_vis_next_spurt || stat == DEAD || !isturf(loc))
		return
	var/datum/wound/artery = hv_vis_arterial_wound()
	if(!artery || can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	var/obj/item/organ/heart/heart = get_organ_slot(ORGAN_SLOT_HEART)
	if(!heart?.is_beating())
		return
	hv_vis_next_spurt = world.time + HV_VIS_SPURT_COOLDOWN
	var/beat = HV_VIS_BEAT_RESTING
	if(blood_volume < BLOOD_VOLUME_BAD)
		beat = HV_VIS_BEAT_RACING
	else if(blood_volume < BLOOD_VOLUME_OKAY)
		beat = HV_VIS_BEAT_FAST
	var/strength = clamp(blood_volume / BLOOD_VOLUME_NORMAL, 0.25, 1)
	var/pulses = max(1, round(HV_VIS_SPURT_COOLDOWN / beat))
	new /obj/effect/temp_visual/hv_arterial_spurt(loc, hv_vis_spurt_dir(artery.limb.body_zone), get_bloodtype()?.get_color(), strength, beat, pulses)

/// Which way a wound on `zone` spurts: out to the side for limbs, forward for the head and chest.
/mob/living/carbon/proc/hv_vis_spurt_dir(zone)
	switch(zone)
		if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
			var/side = hv_vis_zone_side(zone)
			return side > 0 ? EAST : (side < 0 ? WEST : dir)
		if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			var/side = hv_vis_zone_side(zone)
			return side > 0 ? SOUTHEAST : (side < 0 ? SOUTHWEST : turn(dir, 180))
	return dir

/// A jet of blood from a body, pulsing `pulses` times one `beat` apart. Thinner and shorter for a
/// body low on blood.
/obj/effect/temp_visual/hv_arterial_spurt
	name = "blood"
	icon = HV_BLOOD_SPRAY_ICON
	icon_state = "squirt_greyscale"
	plane = GAME_PLANE
	layer = ABOVE_MOB_LAYER
	randomdir = FALSE
	duration = 2 SECONDS

/obj/effect/temp_visual/hv_arterial_spurt/Initialize(mapload, spurt_dir, blood_color, strength = 1, beat = HV_VIS_BEAT_RESTING, pulses = 2)
	duration = beat * pulses + 1
	. = ..()
	setDir(spurt_dir || SOUTH)
	if(blood_color)
		color = blood_color
	var/dx = HV_VIS_DX(dir)
	var/dy = HV_VIS_DY(dir)
	// The art is a line through the whole tile; shrunk and moved out so it starts at the body.
	var/reach = 0.25 + 0.35 * strength
	var/matrix/start = matrix()
	start.Scale(0.1)
	start.Translate(dx * 2, dy * 2)
	var/matrix/out = matrix()
	out.Scale(reach)
	out.Translate(dx * 16 * reach, dy * 16 * reach)
	var/matrix/spent = matrix()
	spent.Scale(reach * 1.1)
	spent.Translate(dx * 18 * reach, dy * 18 * reach)
	alpha = 0
	animate(src, alpha = 235, transform = start, time = 0, loop = pulses)
	animate(alpha = 235, transform = out, time = beat * 0.35, easing = CUBIC_EASING|EASE_OUT)
	animate(alpha = 0, transform = spent, time = beat * 0.4, easing = LINEAR_EASING)
	animate(alpha = 0, transform = spent, time = beat * 0.25, easing = LINEAR_EASING)
