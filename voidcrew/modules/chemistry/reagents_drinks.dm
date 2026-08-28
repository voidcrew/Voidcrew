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

/datum/reagent/consumable/sunset_sarsaparilla/on_mob_life(mob/living/carbon/drinker, seconds_per_tick, metabolization_ratio)
	// REM RESTORATION: was 1.5 * REM(0.5) * spt == 1.5 brute AND 1.5 burn healed per 2s tick (0.75/s each).
	// REM is now 2.5, which made it 5x. /datum/reagent/consumable keeps the default metabolization_rate
	// (0.2) and sets REAGENT_UNAFFECTED_BY_METABOLISM, so metabolization_ratio == 1.0 at a normal 2s tick
	// regardless of the drinker's metabolism_efficiency; the coefficient halves: 0.75 * 1.0 * 2 == 1.5.
	var/heal_amt = 0.75 * metabolization_ratio * seconds_per_tick
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

/datum/reagent/consumable/ethanol/ratvander/on_mob_life(mob/living/carbon/drinker, seconds_per_tick, metabolization_ratio)
	// REM RESTORATION: both were 6 SECONDS * REM(0.5) * spt == 6 SECONDS of duration added per 2s tick
	// (3 SECONDS/s), which saturates the 6 SECONDS cap in a single tick. REM is now 2.5, which made it
	// 30 SECONDS per tick - hidden by the cap, but wrong, so it is restored anyway. Ethanol's
	// metabolization_rate is 0.5x default, so metabolization_ratio == 0.5 at a normal 2s tick and
	// 6 SECONDS / (2 * 0.5) == 6 SECONDS: the coefficient is unchanged and only the idiom moves.
	// 6 SECONDS * 0.5 * 2 == 6 SECONDS added per tick, as shipped.
	drinker.adjust_timed_status_effect(6 SECONDS * metabolization_ratio * seconds_per_tick, /datum/status_effect/speech/slurring/cult, max_duration = 6 SECONDS)
	drinker.adjust_stutter_up_to(6 SECONDS * metabolization_ratio * seconds_per_tick, 6 SECONDS)
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
