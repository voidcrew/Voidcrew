/**
 * Voidcrew Store - Uniform Slot Clothing Items
 *
 * Permanent cosmetic items that spawn at roundstart.
 * Purchase with ship credits, own forever.
 */

/// Base type for uniform clothing store items
/datum/store_item/clothing/uniform
	category = "Uniform"
	one_time_buy = FALSE // Permanent unlock

/// Jeans
/datum/store_item/clothing/uniform/jeans
	name = "Blue Jeans"
	item_path = /obj/item/clothing/under/pants/jeans
	item_cost = 300
	store_desc = "Classic blue jeans."

/// Black Pants
/datum/store_item/clothing/uniform/blackpants
	name = "Black Pants"
	item_path = /obj/item/clothing/under/pants
	item_cost = 250
	store_desc = "Simple black pants. Goes with everything."

/// Formal Suit - Black
/datum/store_item/clothing/uniform/suit_black
	name = "Black Formal Suit"
	item_path = /obj/item/clothing/under/suit/black
	item_cost = 1200
	store_desc = "A sharp black formal suit. Dress to impress."

/// Formal Suit - Navy
/datum/store_item/clothing/uniform/suit_navy
	name = "Navy Formal Suit"
	item_path = /obj/item/clothing/under/suit/navy
	item_cost = 1200
	store_desc = "A professional navy blue suit. Business ready."

/// Casual Dress
/datum/store_item/clothing/uniform/dress
	name = "Casual Dress"
	item_path = /obj/item/clothing/under/dress/sundress
	item_cost = 600
	store_desc = "A simple sundress. Comfortable elegance."

/// Kilt
/datum/store_item/clothing/uniform/kilt
	name = "Kilt"
	item_path = /obj/item/clothing/under/costume/kilt
	item_cost = 500
	store_desc = "A traditional kilt. Show your heritage."

/// Shorts
/datum/store_item/clothing/uniform/shorts
	name = "Shorts"
	item_path = /obj/item/clothing/under/shorts
	item_cost = 200
	store_desc = "Comfortable shorts. Great for warm climates."
