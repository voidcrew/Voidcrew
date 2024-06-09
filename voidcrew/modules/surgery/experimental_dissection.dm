/datum/surgery/advanced/experimental_dissection
	name = "Dissection"
	requires_tech = FALSE
	replaced_by = /datum/surgery/advanced/experimental_dissection/advanced

/datum/surgery/advanced/experimental_dissection/advanced
	name = "Advanced Dissection"
	requires_tech = TRUE
	replaced_by = /datum/surgery/advanced/experimental_dissection/superior
	steps = list(
		/datum/surgery_step/incise,
		/datum/surgery_step/retract_skin,
		/datum/surgery_step/experimental_dissection/advanced,
		/datum/surgery_step/close,
	)

/datum/surgery/advanced/experimental_dissection/superior
	name = "Superior Dissection"
	requires_tech = TRUE
	replaced_by = /datum/surgery/advanced/experimental_dissection/elite
	steps = list(
		/datum/surgery_step/incise,
		/datum/surgery_step/retract_skin,
		/datum/surgery_step/experimental_dissection/superior,
		/datum/surgery_step/close,
	)

/datum/surgery/advanced/experimental_dissection/elite
	name = "Elite Dissection"
	requires_tech = TRUE
	steps = list(
		/datum/surgery_step/incise,
		/datum/surgery_step/retract_skin,
		/datum/surgery_step/experimental_dissection/elite,
		/datum/surgery_step/close,
	)

/datum/surgery_step/experimental_dissection/advanced
	time = 8 SECONDS

/datum/surgery_step/experimental_dissection/advanced/check_value(mob/living/target)
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

/datum/surgery_step/experimental_dissection/superior
	time = 4 SECONDS

/datum/surgery_step/experimental_dissection/superior/check_value(mob/living/target)
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

/datum/surgery_step/experimental_dissection/elite
	time = 1 SECONDS

/datum/surgery_step/experimental_dissection/elite/check_value(mob/living/target)
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
