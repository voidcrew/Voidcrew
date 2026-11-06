/// Backgrounds: owned by P1. See data/backgrounds/spec.md.

/// Where and how the character starts the round
/datum/preference/choiced/background
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "background"
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	can_randomize = FALSE

/datum/preference/choiced/background/init_possible_values()
	return BACKGROUND_ALL_KEYS

/datum/preference/choiced/background/create_default_value()
	return BACKGROUND_SPACEFARER

/datum/preference/choiced/background/apply_to_human(mob/living/carbon/human/target, value)
	return

/datum/preference/choiced/background/compile_constant_data()
	var/list/data = ..()
	var/list/display_names = list()
	display_names[BACKGROUND_SPACEFARER] = "Spacefarer"
	display_names[BACKGROUND_CONVICT] = "Convict"
	display_names[BACKGROUND_HOMESTEADER] = "Homesteader"
	display_names[BACKGROUND_BOUNTY_HUNTER] = "Bounty Hunter"
	display_names[BACKGROUND_PIRATE] = "Pirate"
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = display_names
	return data
