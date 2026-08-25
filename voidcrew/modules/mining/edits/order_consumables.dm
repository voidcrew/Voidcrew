/**
 * Voidcrew: the chasm rescue rod belongs on the Mining tab.
 *
 * Upstream files it under Consumables next to the medipens and the space cash, so miners
 * looking for a way to get a crewmate back out of a tendril hole never find it. It is the
 * only tool in the game that can pull someone out of a chasm, so it lives with the rest of
 * the mining safety gear and is priced like one - alongside the survival capsule rather
 * than the kinetic crusher.
 *
 * /obj/item/fishing_rod/rescue ships with the rescue hook already fitted, so this one
 * purchase is usable on its own; no separate rod or hook is needed.
 */
/datum/orderable_item/consumables/rescue_hook
	category_index = CATEGORY_MINING
	cost_per_order = 350
