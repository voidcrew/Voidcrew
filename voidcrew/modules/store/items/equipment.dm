/**
 * Voidcrew Store - One-Time Equipment Items
 *
 * Consumable items that are purchased and spawned immediately.
 * These do NOT persist across rounds - one purchase = one item.
 */

/// Base type for equipment store items
/datum/store_item/equipment
	category = "Equipment"
	one_time_buy = TRUE // Consumable, spawns once

/// Emergency Oxygen Tank
/datum/store_item/equipment/emergency_oxy
	name = "Emergency Oxygen Tank"
	item_path = /obj/item/tank/internals/emergency_oxygen
	item_cost = 100
	store_desc = "A small emergency oxygen tank. Good for quick trips."

/// Flashlight
/datum/store_item/equipment/flashlight
	name = "Flashlight"
	item_path = /obj/item/flashlight
	item_cost = 50
	store_desc = "A standard flashlight. Illuminate the darkness."

/// Pocket Flashlight
/datum/store_item/equipment/penlight
	name = "Penlight"
	item_path = /obj/item/flashlight/pen
	item_cost = 75
	store_desc = "A compact pen-sized flashlight. Fits in your pocket."

/// First Aid Kit
/datum/store_item/equipment/firstaid
	name = "First Aid Kit"
	item_path = /obj/item/storage/medkit/regular
	item_cost = 500
	store_desc = "A basic first aid kit. Contains essential medical supplies."

/// Tool Belt
/datum/store_item/equipment/toolbelt
	name = "Tool Belt"
	item_path = /obj/item/storage/belt/utility
	item_cost = 300
	store_desc = "A utility belt for carrying tools. Essential for engineers."

/// Multitool
/datum/store_item/equipment/multitool
	name = "Multitool"
	item_path = /obj/item/multitool
	item_cost = 200
	store_desc = "A handy multitool. Has many uses for electronics work."

/// Cigarettes
/datum/store_item/equipment/cigarettes
	name = "Pack of Cigarettes"
	item_path = /obj/item/storage/fancy/cigarettes
	item_cost = 50
	store_desc = "A pack of space cigarettes. Bad for your health, good for stress."

/// Lighter
/datum/store_item/equipment/lighter
	name = "Lighter"
	item_path = /obj/item/lighter
	item_cost = 25
	store_desc = "A cheap lighter. Produces flame."

/// Playing Cards
/datum/store_item/equipment/cards
	name = "Deck of Cards"
	item_path = /obj/item/toy/cards/deck
	item_cost = 75
	store_desc = "A standard deck of playing cards. Good for passing time."

/// Crayons
/datum/store_item/equipment/crayons
	name = "Box of Crayons"
	item_path = /obj/item/storage/crayons
	item_cost = 50
	store_desc = "A box of colorful crayons. Express yourself."
