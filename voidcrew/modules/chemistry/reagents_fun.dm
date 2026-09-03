/*
 * Novelty reagents ported from monkestation.
 */

/// Flips the drinker upside down, and inverts every invertible chem it shares a
/// container with.
/datum/reagent/australium
	name = "Australium"
	description = "Turns people upside down. Has interesting effects on other chemicals, too."
	color = "#9b9924"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED|REAGENT_CLEANS
	taste_description = "spiders"
	requires_process = TRUE

/datum/reagent/australium/on_mob_add(mob/living/affected_mob, amount)
	. = ..()
	var/matrix/flipped = matrix(affected_mob.transform)
	flipped.Turn(180)
	animate(affected_mob, transform = flipped, time = 3)

/datum/reagent/australium/on_mob_delete(mob/living/affected_mob)
	. = ..()
	var/matrix/flipped = matrix(affected_mob.transform)
	flipped.Turn(180)
	animate(affected_mob, transform = flipped, time = 3)

/datum/reagent/australium/reagent_fire(obj/item/reagent_containers/host)
	var/datum/reagents/holder = host.reagents
	if(isnull(holder))
		return
	var/list/protected_reagents = reactants_of_running_australium_reactions(holder)
	for(var/datum/reagent/listed_reagent as anything in holder.reagent_list.Copy())
		if(isnull(listed_reagent))
			continue
		// /datum/reagent/inverse is the generic fallback every reagent carries by
		// default - only convert chems that name a real inverse of their own.
		if(isnull(listed_reagent.inverse_chem) || listed_reagent.inverse_chem == /datum/reagent/inverse)
			continue
		// A reaction that is busy making Australium keeps its own reactants and catalysts.
		// Australium's recipe needs Happiness, which inverts into Sadness, so without this
		// the first unit produced ate the ingredient list and the reaction starved partway
		// through.
		if(protected_reagents[listed_reagent.type])
			continue
		var/listed_volume = listed_reagent.volume
		var/inverse_type = listed_reagent.inverse_chem
		holder.remove_reagent(listed_reagent.type, listed_volume)
		holder.add_reagent(inverse_type, listed_volume)

/**
 * Every reagent path that an in-progress reaction in holder needs in order to keep producing
 * us, as an assoc set. Only reactions currently running (holder.reaction_list) count - once
 * the batch is done the leftovers are fair game for inversion like anything else.
 *
 * Catalysts count as much as reactants do. They are never consumed, but check_reagents()
 * re-verifies every one of them each step (code/modules/reagents/chemistry/equilibrium.dm:143)
 * and ends the equilibrium the moment one is missing, so inverting a catalyst stalls the
 * reaction exactly the way inverting a reactant did.
 */
/datum/reagent/australium/proc/reactants_of_running_australium_reactions(datum/reagents/holder)
	var/list/protected_reagents = list()
	for(var/datum/equilibrium/equilibrium as anything in holder.reaction_list)
		var/datum/chemical_reaction/reaction = equilibrium?.reaction
		if(isnull(reaction) || !(type in reaction.results))
			continue
		for(var/reagent_path in reaction.required_reagents)
			protected_reagents[reagent_path] = TRUE
		for(var/reagent_path in reaction.required_catalysts)
			protected_reagents[reagent_path] = TRUE
	return protected_reagents

/// Shakes the drinker harder and harder. Overdosing eventually rattles them apart.
/datum/reagent/shakeium
	name = "Shakeium"
	description = "Causes violent shaking in consumers."
	color = "#6fda28"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED|REAGENT_CLEANS
	taste_description = "milkshakes"
	overdose_threshold = 25
	/// Grows every life tick, driving how far the mob is shaken.
	var/intensity = 1
	/// Brute per overdose tick. Climbs once the shaking gets bad enough.
	var/damage_amount = 3
	/// Set once the limb-loss timers have been queued, so they only fire once.
	var/triggered_breakdown = FALSE

/datum/reagent/shakeium/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, times_fired)
	. = ..()
	var/pixel_shift = (1 + (intensity / 10))
	affected_mob.Shake(pixel_shift, pixel_shift)
	intensity += seconds_per_tick

/datum/reagent/shakeium/overdose_start(mob/living/affected_mob)
	. = ..()
	to_chat(affected_mob, span_warning("You're vibrating too hard. Your body can't take much more of this."))

/datum/reagent/shakeium/overdose_process(mob/living/affected_mob, seconds_per_tick, times_fired)
	. = ..()
	var/need_mob_update = affected_mob.adjustBruteLoss(damage_amount * REM * seconds_per_tick, updating_health = FALSE)
	if(intensity > 15)
		intensity += seconds_per_tick
		damage_amount += seconds_per_tick
	if(damage_amount > 10)
		to_chat(affected_mob, span_warning("Your brain is rattling around inside your skull. You need a doctor."))
		need_mob_update += affected_mob.adjustOrganLoss(ORGAN_SLOT_BRAIN, 3 * REM * seconds_per_tick, required_organ_flag = affected_organ_flags)
	if(damage_amount > 20 && !triggered_breakdown && iscarbon(affected_mob))
		to_chat(affected_mob, span_userdanger("You can't hold yourself together any longer!"))
		triggered_breakdown = TRUE
		var/mob/living/carbon/carbon_target = affected_mob
		var/timer = 15 SECONDS
		for(var/obj/item/bodypart/limb as anything in carbon_target.bodyparts)
			if(limb.body_part == HEAD || limb.body_part == CHEST)
				continue
			addtimer(CALLBACK(limb, TYPE_PROC_REF(/obj/item/bodypart, dismember)), timer)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), carbon_target, 'sound/effects/cartoon_sfx/cartoon_pop.ogg', 70), timer)
			timer += 15 SECONDS
	if(need_mob_update)
		return UPDATE_MOB_HEALTH

/// Sets you on fire unless you have a lawman's liver.
/datum/reagent/liquid_justice
	name = "Liquid Justice"
	description = "Rumour has it only the truly robust can process this safely."
	color = "#00ffff" // rgb: 0, 255, 255
	metabolization_rate = 1.5 * REAGENTS_METABOLISM
	ph = 0

// Metabolises 50% faster than phlogiston and gives double fire stacks, but deals
// no direct burn damage of its own.
/datum/reagent/liquid_justice/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, times_fired)
	. = ..()
	var/obj/item/organ/liver/liver = affected_mob.get_organ_slot(ORGAN_SLOT_LIVER)
	if(!liver || !HAS_TRAIT(liver, TRAIT_LAW_ENFORCEMENT_METABOLISM))
		affected_mob.adjust_fire_stacks(2 * REM * seconds_per_tick)
		affected_mob.ignite_mob()
