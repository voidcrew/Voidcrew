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
//
// A body is not consumed forever by the tier that opened it: dissection_points_paid
// below records what has been extracted so far, and a higher tier can reopen the
// body for the difference (can_start() in the upstream file consults
// dissection_value_remaining()). Before this, a corpse dissected at a low tier was
// permanently dead to the higher tiers, so researching a better dissection punished
// crews for every body they had already processed - playtest crews were told to
// stop researching so as not to "waste" corpses.

/mob/living
	/// Research points already paid out by experimental dissection on this body.
	/// A higher dissection tier can reopen the body and collect the difference.
	var/dissection_points_paid = 0

/datum/surgery/advanced/experimental_dissection
	name = "Dissection"
	requires_tech = FALSE
	replaced_by = /datum/surgery/advanced/experimental_dissection/advanced
	/// Spare instance of our own dissection step, kept only to price a body without
	/// running the surgery. can_start() is called on every surgery in GLOB.surgeries_list
	/// each time somebody clicks a corpse with a scalpel, so this is built once per tier
	/// rather than made and thrown away on every click.
	var/datum/surgery_step/experimental_dissection/pricing_step

/**
 * Research points this surgery's dissection tier could still pull out of a body that
 * was already opened at some lower tier. Zero means this tier has nothing new to say.
 */
/datum/surgery/advanced/experimental_dissection/proc/dissection_value_remaining(mob/living/target)
	if(isnull(pricing_step))
		for(var/step_type in steps)
			if(!ispath(step_type, /datum/surgery_step/experimental_dissection))
				continue
			pricing_step = new step_type
			break
	if(isnull(pricing_step))
		return 0
	return max(pricing_step.check_value(target) - target.dissection_points_paid, 0)

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
	// The base tier above sets replaced_by to the advanced tier, and every subtype inherits
	// it. This tier is the top of the ladder and must clear it: with it inherited, the
	// operating computer knowing Advanced Dissection made Elite hide itself (it looked
	// "replaced" by the advanced tier) while Elite's presence still hid Superior, so a crew
	// that researched Elite lost every dissection at once.
	replaced_by = null
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
