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
// Target multipliers in check_value() below scale these. Fauna is graded by threat
// rather than paid a flat rate: megafauna x10, elite x3, anything with a melee
// attack /3, passive critters /6.
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
	///Research points a baseline human corpse is worth. Upgraded dissection tiers raise this.
	var/base_value = 100

// VOIDCREW EDIT: replaces upstream's flat ~10-point table with the tiered base_value.
// Humans keep upstream's species multipliers; fauna is graded by how dangerous it is,
// so the corpse is worth roughly what it cost to make.
/datum/surgery_operation/basic/dissection/check_value(mob/living/target)
	var/cost = base_value

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
	time = 1 SECONDS
	base_value = 600
