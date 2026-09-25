/**
 * # Voidcrew virology: the smartfridges the port restocks
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). Two `initial_contents` lists change:
 *
 * - The chemistry fridge gains spaceacillin pills, so the counterplay pill is not only in
 *   survival boxes and vendors.
 * - The virology fridge goes from "a couple of reagent bottles and hope" to the full virus-food
 *   ladder plus ten isolated-symptom bottles and three experimental diseases. This is the single
 *   biggest quality-of-life change in the port: walking the twelve-step evolution path documented
 *   in voidcrew/edits/reagents/recipes.dm previously meant begging chemistry, mining or
 *   xenobiology for one specific food at a time, and the fridge now stocks every rung of it.
 *
 * ## These are whole-list replacements
 *
 * `initial_contents` is a var, so re-declaring it here replaces upstream's list outright - there
 * is no way to append to it the way the vendors in voidcrew/edits/vending/ do via `products +=`.
 * If upstream adds or removes a bottle from either fridge, this file has to be re-synced by hand
 * or the change will vanish silently. It is written out in full, deliberately, so that it is
 * obvious at review time what was replaced.
 *
 * ## Path rebase
 *
 * The ported PR lists `/obj/item/reagent_containers/pill/antiviral`; pills in this codebase live
 * under `/obj/item/reagent_containers/applicator/pill`. Every other entry is unchanged, and every
 * type in both lists was verified to resolve, including the two bottles this port adds
 * (`random_symptom` and the uranium/virus-food bottles in voidcrew/modules/virology/bottles.dm).
 */
/obj/machinery/smartfridge/chemistry/preloaded
	initial_contents = list(
		/obj/item/reagent_containers/applicator/pill/epinephrine = 12,
		/obj/item/reagent_containers/applicator/pill/multiver = 5,
		/obj/item/reagent_containers/applicator/pill/antiviral = 3,
		/obj/item/reagent_containers/cup/bottle/epinephrine = 1,
		/obj/item/reagent_containers/cup/bottle/multiver = 1)

/obj/machinery/smartfridge/chemistry/virology/preloaded
	initial_contents = list(
		/obj/item/storage/pill_bottle/sansufentanyl = 2,
		/obj/item/reagent_containers/syringe/antiviral = 4,
		/obj/item/reagent_containers/cup/bottle/sugar = 1,
		/obj/item/reagent_containers/cup/bottle/synaptizinevirusfood = 1,
		/obj/item/reagent_containers/cup/bottle/mutagenvirusfood = 1,
		/obj/item/reagent_containers/cup/bottle/mutagen = 1,
		/obj/item/reagent_containers/cup/bottle/mutagenvirusfoodsugar = 1,
		/obj/item/reagent_containers/cup/bottle/plasmavirusfoodweak = 1,
		/obj/item/reagent_containers/cup/bottle/plasma = 1,
		/obj/item/reagent_containers/cup/bottle/plasmavirusfood = 1,
		/obj/item/reagent_containers/cup/bottle/uranium = 1,
		/obj/item/reagent_containers/cup/bottle/uraniumvirusfoodunstable = 1,
		/obj/item/reagent_containers/cup/bottle/uraniumvirusfood = 1,
		/obj/item/reagent_containers/cup/bottle/uraniumvirusfoodstable = 1,
		/obj/item/reagent_containers/cup/bottle/synaptizine = 2,
		/obj/item/reagent_containers/cup/bottle/formaldehyde = 2,
		/obj/item/reagent_containers/cup/bottle/random_symptom = 10,
		/obj/item/reagent_containers/cup/bottle/random_virus = 3,
		/obj/item/reagent_containers/cup/bottle/cold = 1,
		/obj/item/reagent_containers/cup/bottle/flu_virion = 1)
