/**
 * Voidcrew Store - Head Slot Clothing Items
 *
 * Permanent cosmetic items that spawn at roundstart.
 * Purchase with ship credits, own forever.
 */

/// Base type for head clothing store items
/datum/store_item/clothing/head
	category = "Head"
	one_time_buy = FALSE // Permanent unlock

/// Beret - Classic headwear
/datum/store_item/clothing/head/beret
	name = "Beret"
	item_path = /obj/item/clothing/head/beret
	item_cost = 500
	store_desc = "A stylish beret. Shows you have good taste."

/// Flatcap
/datum/store_item/clothing/head/flatcap
	name = "Flatcap"
	item_path = /obj/item/clothing/head/flatcap
	item_cost = 400
	store_desc = "A working class flatcap. Keeps your head warm."

/// Top Hat
/datum/store_item/clothing/head/tophat
	name = "Top Hat"
	item_path = /obj/item/clothing/head/hats/tophat
	item_cost = 800
	store_desc = "A distinguished top hat. For the refined spacefarer."

/// Cowboy Hat - Brown
/datum/store_item/clothing/head/cowboy_brown
	name = "Brown Cowboy Hat"
	item_path = /obj/item/clothing/head/cowboy
	item_cost = 700
	store_desc = "Yeehaw, partner. A classic brown cowboy hat."

/// Fedora
/datum/store_item/clothing/head/fedora
	name = "Fedora"
	item_path = /obj/item/clothing/head/fedora
	item_cost = 600
	store_desc = "A classic fedora. Tips included."

/// Beanie
/datum/store_item/clothing/head/beanie
	name = "Beanie"
	item_path = /obj/item/clothing/head/beanie
	item_cost = 350
	store_desc = "A cozy beanie. Keep your head warm."

/// Chef Hat
/datum/store_item/clothing/head/chef
	name = "Chef Hat"
	item_path = /obj/item/clothing/head/utility/chefhat
	item_cost = 300
	store_desc = "A tall chef's hat. Time to cook."
