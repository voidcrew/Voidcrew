// The Rig Bay's goods: whole exosuits sold off stands, and the pools each stand deals from.
// Prices and gates come from data/rig-bay/spec.md section 3. Tiers are in tools/gear_catalog/ratings/.

// ===== STAND POOLS =====

/**
 * The mechs one kind of stand can show. Listed in the suit fitter's `rotations` so the gear
 * catalog sees every mech a stand can roll; `slots = 0` keeps the base shop from dealing them
 * as loose shelf lines. Each /obj/structure/rig_bay_stand deals its own pick with pick_one().
 */
/datum/shop_rotation/rig_bay
	slots = 0
	/// Convoys an empty stand of this pool waits before it takes a new mech. 1 refills on every convoy.
	var/convoys_per_refill = 1

/// Working mechs. Refills every convoy.
/datum/shop_rotation/rig_bay/work
	pool = list(
		/datum/shop_sku/rig_bay_mech/ripley = 4,
		/datum/shop_sku/rig_bay_mech/clarke = 3,
		/datum/shop_sku/rig_bay_mech/odysseus = 2,
		/datum/shop_sku/rig_bay_mech/ripley_mk2 = 2,
	)

/// Combat mechs. Refills every second convoy.
/datum/shop_rotation/rig_bay/combat
	convoys_per_refill = 2
	pool = list(
		/datum/shop_sku/rig_bay_mech/gygax = 3,
		/datum/shop_sku/rig_bay_mech/durand = 1,
	)

/// Yellow exosuit arms: four of the pool on the shelf at once, one each. P1 fills the pool (spec section 4).
/datum/shop_rotation/rig_bay_arms
	slots = 4
	pool = list()

// ===== WHOLE MECHS =====

/**
 * One mech hanging on one stand. The stand creates the SKU, owns its stock (1 while the mech
 * hangs there, 0 otherwise) and hands the mech over on purchase. Never refilled by the convoy
 * top-up, never a contract reward and never discounted.
 */
/datum/shop_sku/rig_bay_mech
	category = "Exosuits"
	shelf = SHELF_CORE
	restock_interval = INFINITY
	contract_reward = FALSE
	fixed_price = TRUE
	stock_min = 0
	stock_max = 1
	/// The stand this mech hangs on. Cleared when either side is deleted.
	var/obj/structure/rig_bay_stand/stand
	/// Equipment typepaths attached to the mech when the stand spawns it, on top of its tg default kit.
	var/list/spawn_kit = list()

/datum/shop_sku/rig_bay_mech/Destroy()
	if(stand?.sku == src)
		stand.sku = null
	stand = null
	return ..()

/datum/shop_sku/rig_bay_mech/ripley
	item_path = /obj/vehicle/sealed/mecha/ripley
	price_credits = 4000
	spawn_kit = list(
		/obj/item/mecha_parts/mecha_equipment/hydraulic_clamp,
		/obj/item/mecha_parts/mecha_equipment/drill,
	)

/datum/shop_sku/rig_bay_mech/clarke
	item_path = /obj/vehicle/sealed/mecha/clarke
	price_credits = 5500
	spawn_kit = list(
		/obj/item/mecha_parts/mecha_equipment/drill,
		/obj/item/mecha_parts/mecha_equipment/mining_scanner,
	)

/datum/shop_sku/rig_bay_mech/odysseus
	item_path = /obj/vehicle/sealed/mecha/odysseus
	price_credits = 4500
	spawn_kit = list(
		/obj/item/mecha_parts/mecha_equipment/sleeper/medical,
	)

/datum/shop_sku/rig_bay_mech/ripley_mk2
	item_path = /obj/vehicle/sealed/mecha/ripley/mk2
	price_credits = 6500
	spawn_kit = list(
		/obj/item/mecha_parts/mecha_equipment/hydraulic_clamp,
		/obj/item/mecha_parts/mecha_equipment/drill,
	)

/datum/shop_sku/rig_bay_mech/gygax
	item_path = /obj/vehicle/sealed/mecha/gygax
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 11000
	crew_limit = 2

/datum/shop_sku/rig_bay_mech/durand
	item_path = /obj/vehicle/sealed/mecha/durand
	zone_permission = ZONE_PERMISSION_ADVANCED
	price_credits = 18000
	price_vouchers = 3
	crew_limit = 1

// ===== ARMS, AMMO AND FITTINGS =====

/// Base for the ordinary exosuit gear lines (Exosuit Arms, Ammo and Fittings tabs). P1 adds the subtypes (spec section 4).
/datum/shop_sku/rig_bay_gear
	category = "Exosuit Fittings"
