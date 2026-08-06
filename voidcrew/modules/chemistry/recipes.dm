/*
 * Reactions for the reagents ported from monkestation.
 *
 * Deliberately NOT ported: monkestation's liquid_solder and system_cleaner
 * recipes. Both produce IPC repair medicines from their smithing/ipcs module,
 * which this fork does not have, so the reactions would have no product.
 */

/datum/chemical_reaction/australium
	results = list(/datum/reagent/australium = 3)
	required_reagents = list(
		/datum/reagent/mercury = 1,
		/datum/reagent/drug/happiness = 1,
		/datum/reagent/toxin/acid = 1,
	)
	reaction_tags = REACTION_TAG_EASY | REACTION_TAG_UNIQUE

/datum/chemical_reaction/shakeium
	results = list(/datum/reagent/shakeium = 5)
	required_reagents = list(
		/datum/reagent/consumable/vanillashake = 1,
		/datum/reagent/consumable/corn_syrup = 1,
		/datum/reagent/consumable/pwr_game = 3,
	)
	reaction_tags = REACTION_TAG_MODERATE | REACTION_TAG_DRINK

/datum/chemical_reaction/drink/sunset_sarsaparilla
	results = list(/datum/reagent/consumable/sunset_sarsaparilla = 5)
	required_reagents = list(
		/datum/reagent/ash = 1,
		/datum/reagent/consumable/sodawater = 1,
		/datum/reagent/uranium = 1,
	)
	reaction_tags = REACTION_TAG_HARD | REACTION_TAG_DRINK

/datum/chemical_reaction/drink/ratvander
	results = list(/datum/reagent/consumable/ethanol/ratvander = 10)
	required_reagents = list(
		/datum/reagent/consumable/ethanol/wine = 5,
		/datum/reagent/consumable/ethanol/triple_sec = 5,
		/datum/reagent/consumable/sugar = 1,
		/datum/reagent/iron = 1,
		/datum/reagent/copper = 0.6,
	)
	mix_message = "The mixture develops a golden glow."
	// monkestation uses sound/magic/clockwork/scripture_tier_up.ogg, which this
	// fork's upstream does not have; the clockwork sounds moved and that one was
	// dropped, so this is the nearest surviving equivalent.
	mix_sound = 'sound/effects/magic/clockwork/invoke_general.ogg'
	reaction_tags = REACTION_TAG_DRINK | REACTION_TAG_EASY | REACTION_TAG_OTHER

/// Mixing the two cult cocktails is a bad idea.
/datum/chemical_reaction/reagent_explosion/cults_explosion
	required_reagents = list(
		/datum/reagent/consumable/ethanol/ratvander = 1,
		/datum/reagent/consumable/ethanol/narsour = 1,
	)
	strengthdiv = 10

/*
 * Mob-spawning reactions are barred from running inside grown food, so plant
 * chemistry can't be used to mass-produce them.
 */

/datum/chemical_reaction/life
	reaction_flags = parent_type::reaction_flags | REACTION_NOT_IN_PLANTS

/datum/chemical_reaction/life_friendly
	reaction_flags = parent_type::reaction_flags | REACTION_NOT_IN_PLANTS

/datum/chemical_reaction/corgium
	reaction_flags = parent_type::reaction_flags | REACTION_NOT_IN_PLANTS

/datum/chemical_reaction/monkey
	reaction_flags = parent_type::reaction_flags | REACTION_NOT_IN_PLANTS

/datum/chemical_reaction/butterflium
	reaction_flags = parent_type::reaction_flags | REACTION_NOT_IN_PLANTS

/datum/chemical_reaction/ant_slurry
	reaction_flags = parent_type::reaction_flags | REACTION_NOT_IN_PLANTS
