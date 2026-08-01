/**
 * Pirate Item Demands
 *
 * Defines specific item demands that pirates can request as alternative to credits.
 * Each demand specifies an item type, quantity, and display name.
 */

/// List of possible item demands pirates can make
/// Format: list(item_type, quantity, display_name)
GLOBAL_LIST_INIT(pirate_item_demands, list(
	// Precious minerals - expensive quantities
	list(/obj/item/stack/sheet/mineral/gold, 20, "gold sheets"),
	list(/obj/item/stack/sheet/mineral/silver, 30, "silver sheets"),
	list(/obj/item/stack/sheet/mineral/diamond, 10, "diamonds"),
	list(/obj/item/stack/sheet/mineral/uranium, 25, "uranium sheets"),
	list(/obj/item/stack/sheet/mineral/plasma, 30, "plasma sheets"),
	list(/obj/item/stack/sheet/mineral/bananium, 15, "bananium sheets"),

	// Bluespace - rare and valuable
	list(/obj/item/stack/sheet/bluespace_crystal, 10, "bluespace polycrystals"),

	// Processed materials - large quantities
	list(/obj/item/stack/sheet/plasteel, 40, "plasteel sheets"),
	list(/obj/item/stack/sheet/mineral/plastitanium, 30, "plastitanium sheets"),

	// Weapons
	list(/obj/item/gun/energy, 3, "energy weapons"),
	list(/obj/item/gun/ballistic, 4, "ballistic weapons"),

	// Medical - bulk supplies
	list(/obj/item/storage/medkit, 5, "medkits"),
	list(/obj/item/reagent_containers/hypospray/medipen, 15, "medipens"),

	// Trade vouchers - small counts, they don't come cheap
	list(/obj/item/stack/trade_voucher, 3, "trade vouchers"),
))

/**
 * Pick a random item demand for a pirate negotiation.
 * Returns list(item_type, quantity, display_name) or null if list is empty.
 */
/proc/pick_pirate_item_demand()
	if(!length(GLOB.pirate_item_demands))
		return null
	return pick(GLOB.pirate_item_demands)

/**
 * Check if an item matches the demanded type.
 */
/proc/item_matches_demand(obj/item/item, demanded_type)
	if(!istype(item))
		return FALSE
	return istype(item, demanded_type)

/**
 * Get the stack amount of an item (or 1 for non-stacks).
 */
/proc/get_item_stack_amount(obj/item/item)
	if(isstack(item))
		var/obj/item/stack/stack = item
		return stack.amount
	return 1
