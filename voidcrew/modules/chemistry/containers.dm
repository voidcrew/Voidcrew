/*
 * Prefilled containers ported from monkestation.
 *
 * Deliberately NOT ported: the /datum/element/trash_if_empty attachments
 * monkestation puts on cups and condiment packs. That element needs
 * TRAIT_TRASH_ITEM and the COMSIG_REAGENTS_NEW/ADD/DEL/REM_REAGENT signals,
 * none of which exist in this fork's upstream, and nothing here consumes the
 * trait, so it would attach and do nothing.
 */

/obj/item/reagent_containers/cup/glass/drinkingglass/filled/sunset_sarsaparilla
	name = "Sunset Sarsaparilla"
	list_reagents = list(/datum/reagent/consumable/sunset_sarsaparilla = 50)

/obj/item/reagent_containers/cup/beaker/large/synthflesh
	name = "large synthflesh beaker"
	list_reagents = list(/datum/reagent/medicine/c2/synthflesh = 100)

/obj/item/reagent_containers/cup/beaker/large/plasma
	name = "large plasma beaker"
	list_reagents = list(/datum/reagent/toxin/plasma = 100)
