/*
 * Recipes for the two gas/reagent conversion machines.
 *
 * Ported from monkestation's factory_type_beat atmos_chem module.
 *
 * These are deliberately not /datum/chemical_reaction: they need a gas mixture or a
 * pressure to be present, which the normal reaction system has no way to express.
 */

/// A reagent mix that becomes another reagent mix when the right gas is present.
/datum/chemical_infuser_recipe
	var/name = "Test"
	/// reagent type -> units produced
	var/list/outputs = list()
	/// gas type -> moles consumed
	var/list/required_gases = list()
	/// reagent type -> units consumed
	var/list/required_reagents = list()

/// A reagent mix that becomes another reagent mix when held under enough pressure.
/datum/pressurized_reaction
	var/name = "Test"
	/// reagent type -> units produced
	var/list/outputs = list()
	/// kPa in the machine's gas mixture needed to run
	var/required_pressure = 0
	/// reagent type -> units consumed
	var/list/required_reagents = list()

/*
 * The sulfur chain, the one worked example monkestation shipped:
 *   gunpowder + O2      -> sulfur          (infuser)
 *   sulfur, 300 kPa     -> sulfur dioxide  (pressure chamber)
 *   dioxide + O2        -> trioxide        (infuser)
 *   trioxide + O2       -> sulfuric acid   (infuser)
 */

/datum/chemical_infuser_recipe/sulfur
	name = "Sulfur"
	required_reagents = list(/datum/reagent/gunpowder = 5)
	required_gases = list(/datum/gas/oxygen = 5)
	outputs = list(/datum/reagent/sulfur = 50)

/datum/chemical_infuser_recipe/sulfur_trioxide
	name = "Sulfur Trioxide"
	required_reagents = list(/datum/reagent/sulfur/dioxide = 5)
	required_gases = list(/datum/gas/oxygen = 5)
	outputs = list(/datum/reagent/sulfur/trioxide = 10)

/datum/chemical_infuser_recipe/sulfuric_acid
	name = "Sulfuric Acid"
	required_reagents = list(/datum/reagent/sulfur/trioxide = 5)
	required_gases = list(/datum/gas/oxygen = 5)
	outputs = list(/datum/reagent/toxin/acid = 10)

/datum/pressurized_reaction/sulfur_dioxide
	name = "Sulfur Dioxide"
	required_pressure = 300
	required_reagents = list(/datum/reagent/sulfur = 50)
	outputs = list(/datum/reagent/sulfur/dioxide = 50)

/*
 * The two intermediate reagents. Upstream declared these with nothing but a name, which
 * left them inheriting sulfur's description and colour and made them indistinguishable in
 * a beaker. Given a description and colour here; everything else is inherited from sulfur
 * on purpose, since they behave the same when drunk.
 */
/datum/reagent/sulfur/dioxide
	name = "Sulfur Dioxide"
	description = "A sharp, choking industrial gas dissolved into solution. An intermediate on the way to sulfuric acid."
	color = "#DFDFAF"

/datum/reagent/sulfur/trioxide
	name = "Sulfur Trioxide"
	description = "Sulfur burned twice over. Combine with more oxygen to finish the acid."
	color = "#EFEFCF"
