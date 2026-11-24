// Artifact effect: gravity wave.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/gravitational_waves.dm,
// also in VOREStation (9335d66b9fdf). Voidcrew: one huge knockback ring instead of Polaris'
// singularity pull. It draws the air in for a moment first (a shimmer closing on it, a rising
// hum), so anyone watching has time to brace or back off; then everything loose in reach is
// flung outward and people are knocked down, hardest near the middle. Anchored things stay put,
// and nobody is thrown into lava, a chasm, open air or space.
// Smashing it lets the wave go at once. Not harvestable; logged.

/// How long it gathers before the wave
#define ARTIFACT_WAVE_WINDUP (1.5 SECONDS)
/// Furthest it ever reaches
#define ARTIFACT_WAVE_MAX_RANGE 7
/// Loose objects one wave can fling (people always feel it), so a junk pile can't lag the server
#define ARTIFACT_WAVE_MAX_OBJECTS 40

/datum/artifact_effect/gravity_wave
	label_name = "Shockwave"
	log_name = "Gravity wave"
	tier = ARTIFACT_TIER_EXTREME
	harvestable = FALSE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_BLUESPACE, ARTIFACT_ENERGY_CONCENTRATED, ARTIFACT_ENERGY_PSIONIC)
	allowed_release_methods = list(ARTIFACT_RELEASE_TOUCH, ARTIFACT_RELEASE_PULSE)
	/// A wave is gathering
	var/gathering = FALSE

/datum/artifact_effect/gravity_wave/setup()
	range = clamp(range, 3, ARTIFACT_WAVE_MAX_RANGE)
	// A wave needs a good part of the store; a hand can't set one off every few seconds.
	touch_cost = max(touch_cost, round(maximum_charges / 2))

/datum/artifact_effect/gravity_wave/do_effect_touch(mob/living/user)
	to_chat(user, span_warning("[holder] hums under your hand, louder and louder."))
	gather()

/datum/artifact_effect/gravity_wave/do_effect_pulse(power)
	gather()

/datum/artifact_effect/gravity_wave/do_effect_destroy()
	release_wave()

/// The warning: the air draws in toward it, then the wave goes.
/datum/artifact_effect/gravity_wave/proc/gather()
	var/turf/center = source_turf()
	if(gathering || !center)
		return FALSE
	gathering = TRUE
	center.visible_message(span_danger("The air around [holder] bends and draws in toward it."))
	playsound(center, 'sound/effects/magic/cosmic_expansion.ogg', 50, TRUE)
	new /obj/effect/temp_visual/artifact_wave_gather(center, range)
	addtimer(CALLBACK(src, PROC_REF(release_wave)), ARTIFACT_WAVE_WINDUP, TIMER_DELETE_ME)
	return TRUE

/// Flings everything loose in reach outward. Does nothing if it was crated or put to sleep meanwhile.
/datum/artifact_effect/gravity_wave/proc/release_wave()
	gathering = FALSE
	var/obj/machinery/artifact/artifact = holder
	if(istype(artifact) && artifact.suppressed)
		return
	var/turf/center = source_turf()
	if(!center)
		return
	new /obj/effect/temp_visual/circle_wave/artifact_ring/gravity_wave(center, range)
	playsound(center, 'sound/effects/gravhit.ogg', 70, TRUE, extrarange = 4)
	playsound(center, 'sound/effects/magic/repulse.ogg', 60, TRUE)
	var/atom/movable/carrier = artifact_effect_visible_source(holder)
	var/objects_flung = 0
	for(var/atom/movable/thing in range(range, center))
		if(thing == holder || thing == carrier || !can_fling(thing))
			continue
		if(!isliving(thing))
			if(objects_flung >= ARTIFACT_WAVE_MAX_OBJECTS)
				continue
			objects_flung++
		fling(thing, center)

/// Loose items, unanchored structures and the living; nothing anchored or immovable.
/datum/artifact_effect/gravity_wave/proc/can_fling(atom/movable/thing)
	if(thing.anchored || thing.move_resist > MOVE_FORCE_STRONG || !isturf(thing.loc))
		return FALSE
	if(isliving(thing))
		var/mob/living/victim = thing
		return !victim.buckled
	return isitem(thing) || isstructure(thing)

/// Throws `thing` directly away from `center`, harder the closer it stood.
/datum/artifact_effect/gravity_wave/proc/fling(atom/movable/thing, turf/center)
	var/distance = get_dist(center, thing)
	var/exposure = isliving(thing) ? artifact_exposure(thing) : 1
	var/throw_range = round(clamp(range - distance + 2, 2, 6) * exposure)
	if(throw_range < 1)
		return
	var/direction = (distance > 0) ? get_dir(center, thing) : pick(GLOB.alldirs)
	if(isliving(thing))
		var/mob/living/victim = thing
		throw_range = safe_distance(victim, direction, throw_range)
		shake_camera(victim, 3, 2)
		victim.Knockdown(2 SECONDS * exposure)
		to_chat(victim, span_userdanger("A wall of force hits you and [throw_range ? "lifts you off your feet" : "slams you to the ground"]!"))
		log_harm(victim)
	if(throw_range < 1)
		return
	var/turf/landing = get_ranged_target_turf(thing, direction, throw_range)
	if(landing)
		// Positional: some throw_at() overrides rename their arguments.
		thing.throw_at(landing, throw_range, 2)

/**
 * How far `thing` can be thrown toward `direction`, up to `limit`, without crossing lava, a chasm,
 * open air or space. A wave knocks people over; it never throws them off a ledge or out an airlock.
 */
/datum/artifact_effect/gravity_wave/proc/safe_distance(atom/movable/thing, direction, limit)
	var/turf/spot = get_turf(thing)
	for(var/step in 1 to limit)
		spot = get_step(spot, direction)
		if(!spot || isspaceturf(spot) || isgroundlessturf(spot) || islava(spot) || ischasm(spot))
			return step - 1
	return limit

/// A shimmer closing in on the artifact before the wave.
/obj/effect/temp_visual/artifact_wave_gather
	icon = 'icons/effects/64x64.dmi'
	icon_state = "circle_wave"
	pixel_x = -16
	pixel_y = -16
	color = "#d8c3ff"
	alpha = 0
	duration = ARTIFACT_WAVE_WINDUP

/obj/effect/temp_visual/artifact_wave_gather/Initialize(mapload, reach = 4)
	. = ..()
	transform = matrix().Scale(max(reach, 1))
	animate(src, transform = matrix().Scale(0.1), time = duration, easing = SINE_EASING | EASE_IN, flags = ANIMATION_PARALLEL)
	animate(src, alpha = 160, time = duration * 0.5, flags = ANIMATION_PARALLEL)
	animate(alpha = 220, time = duration * 0.5)

/// The wave itself.
/obj/effect/temp_visual/circle_wave/artifact_ring/gravity_wave
	color = "#d8c3ff"
	max_alpha = 230
	duration = 0.6 SECONDS

#undef ARTIFACT_WAVE_WINDUP
#undef ARTIFACT_WAVE_MAX_RANGE
#undef ARTIFACT_WAVE_MAX_OBJECTS
