/*
 * Drinks ported from monkestation.
 */

/// Wasteland sarsaparilla. Slowly patches you up as you sip it.
/datum/reagent/consumable/sunset_sarsaparilla
	name = "Sunset Sarsaparilla"
	description = "Build mass with sass!"
	color = "#633504" // rgb: 99, 53, 4
	quality = DRINK_VERYGOOD
	taste_description = "the wild west"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED

/datum/reagent/consumable/sunset_sarsaparilla/on_mob_life(mob/living/carbon/drinker, seconds_per_tick, times_fired)
	var/heal_amt = 1.5 * REM * seconds_per_tick
	drinker.heal_bodypart_damage(brute = heal_amt, burn = heal_amt, updating_health = FALSE)
	drinker.updatehealth()
	return ..()

/datum/glass_style/drinking_glass/sunset_sarsaparilla
	required_drink_type = /datum/reagent/consumable/sunset_sarsaparilla
	name = "glass of Sunset Sarsaparilla"
	desc = "Locally sourced from your nearest nuclear wasteland."
	icon = 'icons/obj/drinks/soda.dmi'
	icon_state = "sunset_sarsparillaglass"

/*
 * Rat'vander Cocktail. Monkestation's version leans on clockcult, which this
 * fork's upstream removed - LIGHT_COLOR_CLOCKWORK and the /clock slurring
 * status effect are both gone, so it uses a brass colour and the cult slur.
 */
/datum/reagent/consumable/ethanol/ratvander
	name = "Rat'vander Cocktail"
	description = "Side effects include hoarding brass and a hatred of blood."
	color = "#bd8f4a" // brass
	boozepwr = 10
	quality = DRINK_FANTASTIC
	taste_description = "sweet brass"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED

/datum/reagent/consumable/ethanol/ratvander/on_mob_life(mob/living/carbon/drinker, seconds_per_tick, times_fired)
	drinker.adjust_timed_status_effect(6 SECONDS * REM * seconds_per_tick, /datum/status_effect/speech/slurring/cult, max_duration = 6 SECONDS)
	drinker.adjust_stutter_up_to(6 SECONDS * REM * seconds_per_tick, 6 SECONDS)
	return ..()

/datum/glass_style/drinking_glass/ratvander
	required_drink_type = /datum/reagent/consumable/ethanol/ratvander
	name = "Rat'vander Cocktail"
	desc = "A cocktail originally mixed by TRNE Corp. Said to be imbued with eldritch magic."
	icon = 'icons/obj/drinks/mixed_drinks.dmi'
	icon_state = "ratvander"

/// Upstream leaves eggnog on the fallback glass sprite; monkestation gives it one.
/datum/glass_style/has_foodtype/drinking_glass/eggnog
	icon = 'icons/obj/drinks/mixed_drinks.dmi'
	icon_state = "eggnog"
