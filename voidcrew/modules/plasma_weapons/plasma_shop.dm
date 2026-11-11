// Package: P5 supply. Shop SKU datums for the outfitter and black market.
// Names are set here because the guns' names carry \improper, which a shop window would print.

// ===== Quartermain outfitter =====

/datum/shop_sku/outfitter/kestrel
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Firearms & Ammo"
	name = "Kestrel laser pistol"
	item_path = /obj/item/gun/energy/frontier_laser/pistol
	price_credits = 900
	stock_min = 2
	stock_max = 2
	restock_interval = 1 HOURS
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/outfitter/cinder
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Firearms & Ammo"
	name = "Cinder plasma pistol"
	item_path = /obj/item/gun/energy/plasma_weapon/pistol
	price_credits = 2000
	stock_min = 1
	stock_max = 1
	restock_interval = 1 HOURS
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/outfitter/plasma_flask
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Firearms & Ammo"
	item_path = /obj/item/plasma_flask
	price_credits = 150
	stock_min = 4
	stock_max = 4
	restock_interval = 1 HOURS

// ===== Undertow Exchange black market =====

/datum/shop_sku/black_market/hornet
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Weapons"
	name = "Hornet laser SMG"
	item_path = /obj/item/gun/energy/frontier_laser/smg
	price_credits = 3500
	stock_min = 1
	stock_max = 1
	restock_interval = 1 HOURS
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/black_market/rotating/furnace
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Weapons"
	name = "Furnace plasma rifle"
	item_path = /obj/item/gun/energy/plasma_weapon/rifle
	price_vouchers = 1
	price_credits = 5000
	stock_min = 1
	stock_max = 1
	restock_interval = 1 HOURS
	fixed_price = TRUE
	contract_reward = FALSE
