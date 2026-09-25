/**
 * # Voidcrew virology: the bottles the fridge and the counter hand out
 *
 * Ported from tgstation #84356 / #89062 (hyperjll), which parked all of these in
 * code/modules/reagents/reagent_containers/cups/bottle.dm. They exist so that a doctor standing
 * at a stocked fridge can walk the whole virus-food ladder (see
 * voidcrew/edits/reagents/recipes.dm) without waiting on chemistry, a miner or a xenobiologist
 * for one specific reagent.
 *
 * `random_symptom` is the odd one out: instead of a reagent it carries a disease, via the
 * `spawned_disease` var that the existing virology bottles already use
 * (`/obj/item/reagent_containers/cup/bottle/random_virus` is its sibling, an experimental
 * multi-symptom virus). The bottle contains a one-symptom virus; culture it in a disease machine
 * and you can pull that symptom out. See voidcrew/modules/virology/isolated_symptom.dm for what
 * decides which symptom you get.
 *
 * `/obj/item/reagent_containers/cup/bottle/uranium` is a plain reagent bottle rather than a
 * virus food: uranium is a level-9 ladder step, and there was no bottle of it to stock.
 */
/obj/item/reagent_containers/cup/bottle/random_symptom
	name = "Isolated symptom culture bottle"
	desc = "A small bottle. Contains an unknown isolated symptom."
	spawned_disease = /datum/disease/advance/isolatedsymptom

/obj/item/reagent_containers/cup/bottle/uranium
	name = "liquid uranium bottle"
	list_reagents = list(/datum/reagent/uranium = 30)

/obj/item/reagent_containers/cup/bottle/mutagenvirusfood
	name = "mutagenic agar bottle"
	list_reagents = list(/datum/reagent/toxin/mutagen/mutagenvirusfood = 30)

/obj/item/reagent_containers/cup/bottle/mutagenvirusfoodsugar
	name = "sucrose agar bottle"
	list_reagents = list(/datum/reagent/toxin/mutagen/mutagenvirusfood/sugar = 30)

/obj/item/reagent_containers/cup/bottle/plasmavirusfoodweak
	name = "weakened virus plasma bottle"
	list_reagents = list(/datum/reagent/toxin/plasma/plasmavirusfood/weak = 30)

/obj/item/reagent_containers/cup/bottle/plasmavirusfood
	name = "virus plasma bottle"
	list_reagents = list(/datum/reagent/toxin/plasma/plasmavirusfood = 30)

/obj/item/reagent_containers/cup/bottle/synaptizinevirusfood
	name = "virus rations bottle"
	list_reagents = list(/datum/reagent/medicine/synaptizine/synaptizinevirusfood = 30)

/obj/item/reagent_containers/cup/bottle/uraniumvirusfood
	name = "decaying uranium gel bottle"
	list_reagents = list(/datum/reagent/uranium/uraniumvirusfood = 30)

/obj/item/reagent_containers/cup/bottle/uraniumvirusfoodunstable
	name = "unstable uranium gel bottle"
	list_reagents = list(/datum/reagent/uranium/uraniumvirusfood/unstable = 30)

/obj/item/reagent_containers/cup/bottle/uraniumvirusfoodstable
	name = "stable uranium gel bottle"
	list_reagents = list(/datum/reagent/uranium/uraniumvirusfood/stable = 30)
