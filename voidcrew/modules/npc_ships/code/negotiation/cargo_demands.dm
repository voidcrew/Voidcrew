/**
 * Pirate Cargo Demands
 *
 * Defines the list of items that pirates will accept as tribute payment
 * and their associated credit values.
 */

/// Global list mapping item types to their tribute value per unit
/// Holochips and spacecash use face value instead of this list
GLOBAL_LIST_INIT(pirate_cargo_demands, list(
	// === PRECIOUS MINERALS ===
	/obj/item/stack/sheet/mineral/gold = 200,
	/obj/item/stack/sheet/mineral/silver = 100,
	/obj/item/stack/sheet/mineral/diamond = 500,
	/obj/item/stack/sheet/mineral/uranium = 150,
	/obj/item/stack/sheet/mineral/plasma = 100,
	/obj/item/stack/sheet/mineral/titanium = 80,
	/obj/item/stack/sheet/mineral/bananium = 300,
	/obj/item/stack/sheet/mineral/adamantine = 400,

	// === PROCESSED MATERIALS ===
	/obj/item/stack/sheet/plasteel = 50,
	/obj/item/stack/sheet/mineral/plastitanium = 75,
	/obj/item/stack/sheet/rglass = 30,
	/obj/item/stack/sheet/plasmarglass = 60,

	// === BLUESPACE ===
	/obj/item/stack/sheet/bluespace_crystal = 400,
	/obj/item/stack/ore/bluespace_crystal = 200,

	// === WEAPONS ===
	/obj/item/gun/energy = 300,
	/obj/item/gun/ballistic = 250,
	/obj/item/melee/energy = 200,
	/obj/item/melee/baton = 150,

	// === MEDICAL ===
	/obj/item/storage/medkit = 100,
	/obj/item/reagent_containers/hypospray/medipen = 50,
	/obj/item/defibrillator = 200,

	// === VALUABLE ITEMS ===
	/obj/item/stack/spacecash = 1,  // Face value (per unit in stack)
	/obj/item/clothing/suit/armor = 150,
	/obj/item/clothing/head/helmet = 100,

	// === RESEARCH ===
	/obj/item/disk/tech_disk = 200,
	/obj/item/disk/design_disk = 150,
))

/**
 * Get the tribute value of an item.
 * Returns 0 if the item is not accepted.
 */
/proc/get_pirate_tribute_value(obj/item/item)
	if(!istype(item))
		return 0

	// Holochips have face value
	if(istype(item, /obj/item/holochip))
		var/obj/item/holochip/chip = item
		return chip.credits

	// Spacecash has face value (amount * denomination)
	if(istype(item, /obj/item/stack/spacecash))
		var/obj/item/stack/spacecash/cash = item
		return cash.get_item_credit_value()

	// Check against our accepted items list
	for(var/item_type in GLOB.pirate_cargo_demands)
		if(istype(item, item_type))
			var/base_value = GLOB.pirate_cargo_demands[item_type]

			// Stacks multiply by amount
			if(isstack(item))
				var/obj/item/stack/stack = item
				return base_value * stack.amount

			return base_value

	return 0

/**
 * Check if an item type is accepted as tribute.
 */
/proc/is_pirate_tribute_accepted(obj/item/item)
	if(!istype(item))
		return FALSE

	// Holochips always accepted
	if(istype(item, /obj/item/holochip))
		return TRUE

	// Check against our list
	for(var/item_type in GLOB.pirate_cargo_demands)
		if(istype(item, item_type))
			return TRUE

	return FALSE

/**
 * Get a human-readable list of accepted tribute categories.
 */
/proc/get_pirate_tribute_categories()
	return list(
		"Precious minerals (gold, silver, diamond, uranium, plasma)",
		"Processed alloys (plasteel, plastitanium)",
		"Bluespace crystals",
		"Weapons (energy guns, ballistic guns, melee weapons)",
		"Medical supplies (medkits, medipens, defibrillators)",
		"Armor and protective gear",
		"Research disks",
		"Credit holochips (face value)",
	)
