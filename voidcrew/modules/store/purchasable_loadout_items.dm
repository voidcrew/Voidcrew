/**
 * Voidcrew Store - Purchasable Loadout Items
 *
 * These loadout items require purchase with ship credits before they can be used.
 * They integrate with the existing loadout category system.
 *
 * To add new purchasable items:
 * 1. Create a subtype of the appropriate /datum/loadout_item category
 * 2. Set requires_purchase = TRUE
 * 3. Set purchase_cost to the credit amount
 */

// ==================== HEAD SLOT PREMIUM ITEMS ====================

/// Premium head items that require purchase
/datum/loadout_item/head/premium
	abstract_type = /datum/loadout_item/head/premium
	requires_purchase = TRUE
	group = "Premium"

/datum/loadout_item/head/premium/cowboy_brown
	name = "Sheriff Hat (Brown)"
	item_path = /obj/item/clothing/head/cowboy/brown
	purchase_cost = 700

/datum/loadout_item/head/premium/cowboy_black
	name = "Desperado Hat (Black)"
	item_path = /obj/item/clothing/head/cowboy/black
	purchase_cost = 700

/datum/loadout_item/head/premium/cowboy_white
	name = "Ten-Gallon Hat (White)"
	item_path = /obj/item/clothing/head/cowboy/white
	purchase_cost = 700

/datum/loadout_item/head/premium/cowboy_grey
	name = "Drifter Hat (Grey)"
	item_path = /obj/item/clothing/head/cowboy/grey
	purchase_cost = 700

/datum/loadout_item/head/premium/cowboy_red
	name = "Deputy Hat (Red)"
	item_path = /obj/item/clothing/head/cowboy/red
	purchase_cost = 700

/datum/loadout_item/head/premium/pirate_captain
	name = "Captain's Bicorne"
	item_path = /obj/item/clothing/head/costume/pirate/captain
	purchase_cost = 1000

/datum/loadout_item/head/premium/chef
	name = "Chef's Hat"
	item_path = /obj/item/clothing/head/utility/chefhat
	purchase_cost = 300

// ==================== NECK SLOT PREMIUM ITEMS ====================

/datum/loadout_item/neck/premium
	abstract_type = /datum/loadout_item/neck/premium
	requires_purchase = TRUE
	group = "Premium"

/datum/loadout_item/neck/premium/cloak_void
	name = "Void Cloak"
	item_path = /obj/item/clothing/neck/cloak
	purchase_cost = 1500

// ==================== GLASSES PREMIUM ITEMS ====================

/datum/loadout_item/glasses/premium
	abstract_type = /datum/loadout_item/glasses/premium
	requires_purchase = TRUE
	group = "Premium"

/datum/loadout_item/glasses/premium/phantom
	name = "Phantom Glasses"
	item_path = /obj/item/clothing/glasses/phantom
	purchase_cost = 800

// ==================== ACCESSORY PREMIUM ITEMS ====================

/datum/loadout_item/accessory/premium
	abstract_type = /datum/loadout_item/accessory/premium
	requires_purchase = TRUE
	group = "Premium"

/datum/loadout_item/accessory/premium/medal_gold
	name = "Gold Medal"
	item_path = /obj/item/clothing/accessory/medal/gold
	purchase_cost = 2000

/datum/loadout_item/accessory/premium/medal_silver
	name = "Silver Medal"
	item_path = /obj/item/clothing/accessory/medal/silver
	purchase_cost = 1000

/datum/loadout_item/accessory/premium/medal_bronze_heart
	name = "Bronze Heart Medal"
	item_path = /obj/item/clothing/accessory/medal/bronze_heart
	purchase_cost = 500

/datum/loadout_item/accessory/premium/medal_conduct
	name = "Conduct Medal"
	item_path = /obj/item/clothing/accessory/medal/conduct
	purchase_cost = 400
