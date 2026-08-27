// Voidcrew retiers experimental dissection into a research-gated ladder. The payout
// curve is deliberately shallow: the basic tier has to be worth doing on its own, and
// the top tier is a steady improvement rather than a jackpot.
//
// Baseline human corpse, by tier:
//   Dissection          100  (no tech required)
//   Advanced Dissection 200
//   Superior Dissection 400
//   Elite Dissection    600
//
// A body is not consumed forever by the tier that opened it: dissection_points_paid below
// records what has been extracted so far, and a higher tier can reopen the body for the
// difference. Before this, a corpse dissected at a low tier was permanently dead to the
// higher tiers, so researching a better dissection punished crews for every body they had
// already processed - playtest crews were told to stop researching so as not to "waste"
// corpses.

/mob/living
	/// Research points already paid out by experimental dissection on this body.
	/// A higher dissection tier can reopen the body and collect the difference.
	var/dissection_points_paid = 0

/datum/surgery_operation/basic/dissection
	// VOIDCREW EDIT: the fork's base dissection needs no research (old API: requires_tech = FALSE).
	// This is upstream's flag set minus OPERATION_LOCKED - resync if upstream changes the base flags.
	operation_flags = OPERATION_ALWAYS_FAILABLE | OPERATION_MORBID | OPERATION_IGNORE_CLOTHES
	replaced_by = /datum/surgery_operation/basic/dissection/advanced
	///Research points a baseline human corpse is worth. Upgraded dissection tiers raise this.
	var/base_value = 100

/**
 * Research points this tier could still pull out of a body that was already opened at some
 * lower tier. Zero means this tier has nothing new to say about it.
 *
 * The old API needed a spare /datum/surgery_step instance to price a body without running
 * the surgery; check_value() is a proc on the operation itself now, so the tier prices its
 * own work directly.
 */
/datum/surgery_operation/basic/dissection/proc/dissection_value_remaining(mob/living/target)
	return max(check_value(target) - target.dissection_points_paid, 0)

/// VOIDCREW EDIT: upstream refuses a body that carries TRAIT_DISSECTED at all. A tier that
/// is worth more than what has already been paid out may reopen it for the difference.
/datum/surgery_operation/basic/dissection/state_check(mob/living/patient)
	if(patient.stat != DEAD)
		return FALSE
	if(!HAS_TRAIT_FROM(patient, TRAIT_DISSECTED, EXPERIMENTAL_SURGERY_TRAIT))
		return TRUE
	return dissection_value_remaining(patient) > 0

// VOIDCREW EDIT: replaces upstream's flat ~10-point table with the tiered base_value.
// Humans keep upstream's species multipliers; fauna is graded by how dangerous it is,
// so the corpse is worth roughly what it cost to make.
/datum/surgery_operation/basic/dissection/check_value(mob/living/target)
	var/cost = base_value

	if(ishuman(target))
		var/mob/living/carbon/human/human_target = target
		if(human_target.dna?.species)
			if(HAS_TRAIT(human_target, TRAIT_LESSER_HUMANOID)) // VOIDCREW note: was ismonkey(); upstream widened its own check (operation_dissection.dm) to the trait, follow suit
				cost /= 5
			else if(isabductor(human_target))
				cost *= 4
			else if(isgolem(human_target) || human_target.has_status_effect(/datum/status_effect/zombie))
				cost *= 3
			else if(isjellyperson(human_target) || ispodperson(human_target))
				cost *= 2
	else if(isalienroyal(target))
		cost *= 10
	else if(isalienadult(target))
		cost *= 5
	// melee_damage_upper lives on /mob/living, so this reads correctly on both basic and simple mobs.
	else if(ismegafauna(target))
		cost *= 10
	else if(istype(target, /mob/living/simple_animal/hostile/asteroid/elite))
		cost *= 3
	else if(target.melee_damage_upper > 0)
		cost /= 3
	else
		cost /= 6

	return max(round(cost), 1)

/datum/surgery_operation/basic/dissection/advanced
	name = "advanced dissection"
	rnd_name = "Advanced Experimental Dissection"
	rnd_desc = "An advanced form of experimental dissection that generates a higher level of research points at R&D consoles."
	operation_flags = parent_type::operation_flags | OPERATION_LOCKED
	replaced_by = /datum/surgery_operation/basic/dissection/superior
	time = 8 SECONDS
	base_value = 200

/datum/surgery_operation/basic/dissection/superior
	name = "superior dissection"
	rnd_name = "Superior Experimental Dissection"
	rnd_desc = "An advanced form of experimental dissection that generates a higher level of research points at R&D consoles."
	operation_flags = parent_type::operation_flags | OPERATION_LOCKED
	replaced_by = /datum/surgery_operation/basic/dissection/elite
	time = 4 SECONDS
	base_value = 400

/datum/surgery_operation/basic/dissection/elite
	name = "elite dissection"
	rnd_name = "Elite Experimental Dissection"
	rnd_desc = "An advanced form of experimental dissection that generates a higher level of research points at R&D consoles."
	operation_flags = parent_type::operation_flags | OPERATION_LOCKED
	// MUST be set explicitly. The four tiers are SIBLINGS under /basic/dissection, not a
	// chain of subtypes, so leaving replaced_by unset here does not mean "nothing replaces
	// me" - it INHERITS the base tier's value and points straight back at /advanced. That
	// closes the ladder into a ring (advanced -> superior -> elite -> advanced), and
	// is_replaced() walks replaced_by recursively with only a self-reference guard, so the
	// walk never terminates. Every one of those three is OPERATION_LOCKED, so the "is my
	// replacement in the pool?" early-out never fires either on the default unlocked pool.
	// Unguarded that wedged the entire world on the first get_available_operations() call
	// (any surgery, any limb examine_more, any operating computer) with no runtime and no
	// log line, because world.loop_checks is FALSE. It also meant elite dissection was
	// filtered out as "replaced by advanced" and could never appear even once researched.
	replaced_by = null
	time = 1 SECONDS
	base_value = 600

/**
 * VOIDCREW EDIT: pay out only what this tier is worth ON TOP of whatever an earlier tier
 * already took, and bank the total. Upstream hands over the full check_value() every time,
 * which with reopening allowed would let a crew farm one corpse up the tier ladder.
 *
 * A botch consumes the whole remaining value for one percent of it, exactly as upstream's
 * failure path burns the body for a token payout.
 */
/datum/surgery_operation/basic/dissection/on_success(mob/living/patient, mob/living/surgeon, tool, list/operation_args)
	var/points_earned = dissection_value_remaining(patient)
	patient.dissection_points_paid += points_earned
	display_results(
		surgeon,
		patient,
		span_warning("You dissect [patient], discovering [points_earned] point\s of data!"),
		span_warning("[surgeon] dissects [patient]."),
		span_warning("[surgeon] dissects [patient]."),
	)
	if(points_earned > 0)
		give_paper(surgeon, points_earned)
	patient.apply_damage(80, BRUTE, BODY_ZONE_CHEST)
	ADD_TRAIT(patient, TRAIT_DISSECTED, EXPERIMENTAL_SURGERY_TRAIT)

/datum/surgery_operation/basic/dissection/on_failure(mob/living/patient, mob/living/surgeon, tool, list/operation_args)
	var/remaining_value = dissection_value_remaining(patient)
	var/points_earned = round(remaining_value * 0.01)
	patient.dissection_points_paid += remaining_value
	display_results(
		surgeon,
		patient,
		span_warning("You dissect [patient], but don't find anything particularly interesting."),
		span_warning("[surgeon] dissects [patient]."),
		span_warning("[surgeon] dissects [patient]."),
	)
	if(points_earned > 0)
		give_paper(surgeon, points_earned)
	patient.apply_damage(80, BRUTE, BODY_ZONE_CHEST)
	ADD_TRAIT(patient, TRAIT_DISSECTED, EXPERIMENTAL_SURGERY_TRAIT)
