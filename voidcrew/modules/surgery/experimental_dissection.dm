// VOIDCREW ADDITION: researched upgrade tiers for upstream's experimental dissection.
// Each tier is faster than the last and yields far more research points.
//
// Ported from the pre-2026 surgery API (/datum/surgery + /datum/surgery_step) to the
// operation API (/datum/surgery_operation). Old -> new mapping used here:
//   requires_tech = TRUE   -> operation_flags | OPERATION_LOCKED
//   requires_tech = FALSE  -> operation_flags without OPERATION_LOCKED
//   replaced_by            -> replaced_by (unchanged, same semantics)
//   steps + step time      -> the operation's own time (the step list is gone)

/datum/surgery_operation/basic/dissection
	// VOIDCREW EDIT: the fork's base dissection needs no research (old API: requires_tech = FALSE).
	// This is upstream's flag set minus OPERATION_LOCKED - resync if upstream changes the base flags.
	operation_flags = OPERATION_ALWAYS_FAILABLE | OPERATION_MORBID | OPERATION_IGNORE_CLOTHES
	replaced_by = /datum/surgery_operation/basic/dissection/advanced

/datum/surgery_operation/basic/dissection/advanced
	name = "advanced dissection"
	rnd_name = "Advanced Experimental Dissection"
	rnd_desc = "An advanced form of experimental dissection that generates a higher level of research points at R&D consoles."
	operation_flags = parent_type::operation_flags | OPERATION_LOCKED
	replaced_by = /datum/surgery_operation/basic/dissection/superior
	time = 8 SECONDS

/datum/surgery_operation/basic/dissection/advanced/check_value(mob/living/target)
	var/cost = 1000

	if(ishuman(target))
		var/mob/living/carbon/human/human_target = target
		if(human_target.dna?.species)
			if(ismonkey(human_target))
				cost /= 5
			else if(isabductor(human_target))
				cost *= 4
			else if(isgolem(human_target) || iszombie(human_target))
				cost *= 3
			else if(isjellyperson(human_target) || ispodperson(human_target))
				cost *= 2
	else if(isalienroyal(target))
		cost *= 10
	else if(isalienadult(target))
		cost *= 5
	else
		cost /= 6

	return cost

/datum/surgery_operation/basic/dissection/superior
	name = "superior dissection"
	rnd_name = "Superior Experimental Dissection"
	rnd_desc = "An advanced form of experimental dissection that generates a higher level of research points at R&D consoles."
	operation_flags = parent_type::operation_flags | OPERATION_LOCKED
	replaced_by = /datum/surgery_operation/basic/dissection/elite
	time = 4 SECONDS

/datum/surgery_operation/basic/dissection/superior/check_value(mob/living/target)
	var/cost = 1500

	if(ishuman(target))
		var/mob/living/carbon/human/human_target = target
		if(human_target.dna?.species)
			if(ismonkey(human_target))
				cost /= 5
			else if(isabductor(human_target))
				cost *= 4
			else if(isgolem(human_target) || iszombie(human_target))
				cost *= 3
			else if(isjellyperson(human_target) || ispodperson(human_target))
				cost *= 2
	else if(isalienroyal(target))
		cost *= 10
	else if(isalienadult(target))
		cost *= 5
	else
		cost /= 6

	return cost

/datum/surgery_operation/basic/dissection/elite
	name = "elite dissection"
	rnd_name = "Elite Experimental Dissection"
	rnd_desc = "An advanced form of experimental dissection that generates a higher level of research points at R&D consoles."
	operation_flags = parent_type::operation_flags | OPERATION_LOCKED
	time = 1 SECONDS

/datum/surgery_operation/basic/dissection/elite/check_value(mob/living/target)
	var/cost = 2000

	if(ishuman(target))
		var/mob/living/carbon/human/human_target = target
		if(human_target.dna?.species)
			if(ismonkey(human_target))
				cost /= 5
			else if(isabductor(human_target))
				cost *= 4
			else if(isgolem(human_target) || iszombie(human_target))
				cost *= 3
			else if(isjellyperson(human_target) || ispodperson(human_target))
				cost *= 2
	else if(isalienroyal(target))
		cost *= 10
	else if(isalienadult(target))
		cost *= 5
	else
		cost /= 6

	return cost
