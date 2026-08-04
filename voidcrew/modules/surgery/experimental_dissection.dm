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
// Target multipliers in /datum/surgery_step/experimental_dissection/check_value()
// scale these. Fauna is graded by threat rather than paid a flat rate:
//   megafauna x10, elite x3, anything with a melee attack /3, passive critters /6.

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
	base_value = 200

/datum/surgery_step/experimental_dissection/superior
	time = 4 SECONDS
	base_value = 400

/datum/surgery_step/experimental_dissection/elite
	time = 1 SECONDS
	base_value = 600
