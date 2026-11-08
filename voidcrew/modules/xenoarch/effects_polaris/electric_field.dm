// Artifact effect: electric field.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/electric_field.dm,
// also in VOREStation (9335d66b9fdf). Voidcrew: arcs only find robots, prosthetic-bodied mobs and
// people holding something metal, so it can be read and avoided (empty hands, insulated gloves);
// Polaris shocked everyone in range for up to 40 burn. Field arcs never stun, bursts only knock
// down briefly, and every arc is logged. A hand on it grounds the toucher: the charge leaps to
// everyone else nearby instead, as in Polaris. Lights in range flicker as it charges. Run from a
// carried battery, it never arcs to its carrier.

/// Lights one charge can flicker, so a room full of lamps costs no more than a few
#define ARTIFACT_FIELD_MAX_FLICKERS 6

/datum/artifact_effect/electric_field
	label_name = "Shocks"
	log_name = "Electric field"
	tier = ARTIFACT_TIER_UNCOMMON
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ELECTROMAGNETIC, ARTIFACT_ENERGY_CONCENTRATED)

/datum/artifact_effect/electric_field/do_effect_touch(mob/living/user)
	flicker_lights()
	var/arcs = 0
	for(var/mob/living/target in living_in_range())
		if(target == user)
			continue
		if(arc_to(target, rand(10, 15), knockdown = FALSE))
			arcs++
	if(arcs)
		to_chat(user, span_warning("A charge runs up your arm, through you, and leaps away."))
		playsound(source_turf(), 'sound/effects/magic/lightningshock.ogg', 35, TRUE)
	else
		to_chat(user, span_notice("The hair on your arm stands up, then settles."))

/datum/artifact_effect/electric_field/do_effect_aura(seconds_per_tick)
	if(SPT_PROB(15, seconds_per_tick))
		flicker_lights(2)
	for(var/mob/living/target in living_in_range())
		if(SPT_PROB(10, seconds_per_tick))
			arc_to(target, rand(3, 6), knockdown = FALSE)

/datum/artifact_effect/electric_field/do_effect_pulse(power)
	var/turf/center = source_turf()
	if(!center)
		return
	flicker_lights()
	playsound(center, 'sound/effects/magic/lightningshock.ogg', 50, TRUE)
	new /obj/effect/temp_visual/electricity(center)
	for(var/mob/living/target in living_in_range())
		arc_to(target, clamp(power * 0.4, 6, 18), knockdown = power >= 25)

/**
 * Arcs to `target` if it is a machine or holds something metal. Returns TRUE if the shock took.
 * Insulated gloves and a suit's insulation work as they do against any shock.
 */
/datum/artifact_effect/electric_field/proc/arc_to(mob/living/target, damage, knockdown)
	var/atom/source = artifact_effect_visible_source(holder)
	if(target.stat == DEAD || target == source || !conducts(target))
		return FALSE
	damage *= artifact_exposure(target)
	if(damage < 1)
		return FALSE
	var/flags = SHOCK_SUPPRESS_MESSAGE | (knockdown ? SHOCK_KNOCKDOWN : SHOCK_NOSTUN)
	// Positional on purpose: only the carbon override has the jitter, stutter and stun arguments.
	if(!target.electrocute_act(damage, holder, 1, flags, 4 SECONDS, 2 SECONDS, 1 SECONDS))
		return FALSE
	source?.Beam(target, icon_state = "lightning[rand(1, 12)]", time = 0.5 SECONDS)
	if(issilicon(target) || (target.mob_biotypes & MOB_ROBOTIC))
		to_chat(target, span_danger("ERROR: Electrical fault detected!"))
		target.adjust_stutter(3 SECONDS)
	else
		to_chat(target, span_danger("A spark leaps from [source] to you!"))
	log_harm(target)
	return TRUE

/// Robots and anything with metal in hand make a path for the charge.
/datum/artifact_effect/electric_field/proc/conducts(mob/living/target)
	if(issilicon(target) || (target.mob_biotypes & MOB_ROBOTIC))
		return TRUE
	for(var/obj/item/held in target.held_items)
		if(held.obj_flags & CONDUCTS_ELECTRICITY)
			return TRUE
	return FALSE

/// Makes a few lights in range stutter.
/datum/artifact_effect/electric_field/proc/flicker_lights(limit = ARTIFACT_FIELD_MAX_FLICKERS)
	var/turf/center = source_turf()
	if(!center)
		return
	var/flickered = 0
	for(var/obj/machinery/light/light in range(range, center))
		if(flickered >= limit)
			return
		if(light.flicker(rand(3, 6)))
			flickered++

#undef ARTIFACT_FIELD_MAX_FLICKERS
