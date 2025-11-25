/**
 * Voidcrew Store - Suit Slot Clothing Items
 *
 * Permanent cosmetic items that spawn at roundstart.
 * Purchase with ship credits, own forever.
 */

/// Base type for suit clothing store items
/datum/store_item/clothing/suit
	category = "Suit"
	one_time_buy = FALSE // Permanent unlock

/// Leather Jacket
/datum/store_item/clothing/suit/leather_jacket
	name = "Leather Jacket"
	item_path = /obj/item/clothing/suit/jacket/leather
	item_cost = 800
	store_desc = "A classic leather jacket. Looks cool, feels cooler."

/// Bomber Jacket
/datum/store_item/clothing/suit/bomber
	name = "Bomber Jacket"
	item_path = /obj/item/clothing/suit/jacket/bomber
	item_cost = 700
	store_desc = "A classic bomber jacket. Great for pilots."

/// Labcoat
/datum/store_item/clothing/suit/labcoat
	name = "Labcoat"
	item_path = /obj/item/clothing/suit/toggle/labcoat
	item_cost = 400
	store_desc = "A white labcoat. Science awaits."

/// Winter Coat
/datum/store_item/clothing/suit/wintercoat
	name = "Winter Coat"
	item_path = /obj/item/clothing/suit/hooded/wintercoat
	item_cost = 500
	store_desc = "A warm winter coat with hood. Stay toasty."

/// Suit Jacket
/datum/store_item/clothing/suit/suitjacket
	name = "Suit Jacket"
	item_path = /obj/item/clothing/suit/toggle/lawyer/black
	item_cost = 600
	store_desc = "A formal black suit jacket. Business casual."

/// Chef Apron
/datum/store_item/clothing/suit/apron
	name = "Chef Apron"
	item_path = /obj/item/clothing/suit/apron/chef
	item_cost = 350
	store_desc = "A kitchen apron. Keep your clothes clean while cooking."
