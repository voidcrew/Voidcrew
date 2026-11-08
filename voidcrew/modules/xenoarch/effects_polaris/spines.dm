// Artifact effect: spines.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/indiscriminate_spines.dm.
// Voidcrew: it bristles for a second (a rattle and a visible shiver, time to duck behind cover),
// then looses a ring of bone spines evenly around itself, eight or twelve by strength. A hand on
// it is spared: no spine flies toward the person touching it, as in Polaris. Half as likely in the
// green zone (design catalogue). Polaris' spore variant is not ported. Not harvestable; logged.

/// How long it bristles before it fires
#define ARTIFACT_SPINES_WINDUP (1 SECONDS)

/datum/artifact_effect/spines
	label_name = "Fires spines"
	log_name = "Spines"
	tier = ARTIFACT_TIER_EXTREME
	harvestable = FALSE
	harmful = TRUE
	green_weight = 0.5
	possible_kinds = list(ARTIFACT_ENERGY_ORGANIC)
	allowed_release_methods = list(ARTIFACT_RELEASE_TOUCH, ARTIFACT_RELEASE_PULSE)
	/// Spines in one volley
	var/volley = 8
	/// A volley is being readied
	var/bristling = FALSE

/datum/artifact_effect/spines/setup()
	volley = (strength == ARTIFACT_STRENGTH_LARGE) ? 12 : 8
	// A volley needs a good part of the store; a hand can't set one off every few seconds.
	touch_cost = max(touch_cost, round(maximum_charges / 2))

/datum/artifact_effect/spines/copy_settings_to(datum/artifact_effect/spines/copy)
	copy.volley = volley

/datum/artifact_effect/spines/do_effect_touch(mob/living/user)
	bristle(user)

/datum/artifact_effect/spines/do_effect_pulse(power)
	bristle()

/datum/artifact_effect/spines/do_effect_destroy()
	fire_volley()

/// The warning: it shivers and rattles, then fires. `spared` is the person touching it.
/datum/artifact_effect/spines/proc/bristle(mob/living/spared)
	var/turf/center = source_turf()
	if(bristling || !center)
		return FALSE
	bristling = TRUE
	center.visible_message(span_danger("[holder] bristles with sharp bone!"))
	playsound(center, 'sound/effects/blob/blobattack.ogg', 50, TRUE)
	var/atom/movable/shaker = artifact_effect_visible_source(holder)
	if(shaker)
		shaker.Shake(1, 1, ARTIFACT_SPINES_WINDUP)
	addtimer(CALLBACK(src, PROC_REF(fire_volley), spared ? WEAKREF(spared) : null), ARTIFACT_SPINES_WINDUP, TIMER_DELETE_ME)
	return TRUE

/// Looses one ring of spines. Skips the direction of whoever `spared_ref` points to.
/datum/artifact_effect/spines/proc/fire_volley(datum/weakref/spared_ref)
	bristling = FALSE
	var/obj/machinery/artifact/artifact = holder
	if(istype(artifact) && artifact.suppressed)
		return 0
	var/turf/center = source_turf()
	if(!center)
		return 0
	var/mob/living/spared = spared_ref?.resolve()
	var/spared_angle = (spared && get_dist(center, spared) <= 1 && spared.loc != center) ? get_angle(center, spared) : null
	var/atom/movable/launcher = artifact_effect_visible_source(holder)
	var/step = 360 / volley
	var/offset = rand(0, step - 1)
	var/fired = 0
	for(var/i in 0 to volley - 1)
		var/angle = (offset + i * step) % 360
		if(!isnull(spared_angle) && abs(closer_angle_difference(angle, spared_angle)) < step * 0.75)
			continue
		var/obj/projectile/artifact_spine/spine = new(center)
		spine.firer = launcher
		spine.fired_from = launcher
		spine.range = range + 2
		spine.fire(angle)
		fired++
	playsound(center, 'sound/items/weapons/pierce.ogg', 60, TRUE)
	for(var/mob/living/target in living_in_range(2))
		if(target != spared)
			log_harm(target)
	return fired

/// A bone spine.
/obj/projectile/artifact_spine
	name = "bone spine"
	icon_state = "magspear"
	color = "#efe2c4"
	damage = 10
	damage_type = BRUTE
	armor_flag = BULLET
	sharpness = SHARP_POINTY
	hit_prone_targets = TRUE
	hitsound = 'sound/items/weapons/pierce.ogg'

#undef ARTIFACT_SPINES_WINDUP
