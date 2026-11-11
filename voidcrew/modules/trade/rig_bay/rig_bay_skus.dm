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

/// Yellow exosuit arms: four of the pool on the shelf at once, one each.
/datum/shop_rotation/rig_bay_arms
	slots = 4
	pool = list(
		/datum/shop_sku/rig_bay_gear/arm/lmg = 3,
		/datum/shop_sku/rig_bay_gear/arm/laser = 3,
		/datum/shop_sku/rig_bay_gear/arm/laser_heavy = 2,
		/datum/shop_sku/rig_bay_gear/arm/scattershot = 2,
		/datum/shop_sku/rig_bay_gear/arm/carbine = 2,
		/datum/shop_sku/rig_bay_gear/arm/ion = 1,
		/datum/shop_sku/rig_bay_gear/arm/tesla = 1,
		/datum/shop_sku/rig_bay_gear/arm/flashbang_launcher = 1,
	)

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

/// TRUE while this line's mech hangs on its stand, ready to hand over.
/datum/shop_sku/rig_bay_mech/proc/mech_ready()
	return !QDELETED(stand) && stand.sku == src && stand.stand_state == RIG_BAY_STAND_CLAMPED && !QDELETED(stand.held_mech)

/datum/shop_sku/rig_bay_mech/get_denial_reason(mob/living/user)
	if(!mech_ready())
		return "Out of stock."
	return ..()

/datum/shop_sku/rig_bay_mech/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(!mech_ready())
		return FALSE
	return ..()

/// No crate over the counter: the stand lowers this exact mech for the buyer's crew.
/datum/shop_sku/rig_bay_mech/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	var/obj/vehicle/sealed/mecha/mech = stand?.held_mech
	if(mech_ready() && stand.release_mech(user))
		return mech
	refund(user)
	return null

/// The mech vanished between the charge and the hand-over: give back exactly what was taken.
/datum/shop_sku/rig_bay_mech/proc/refund(mob/living/user)
	var/obj/structure/overmap/ship/crew_ship = get_crew_ship(user)
	var/credit_price = get_credit_price(user, crew_ship)
	if(credit_price > 0)
		var/datum/bank_account/account = get_account(user, crew_ship)
		account?.adjust_money(credit_price, "Trader Outpost: [name] refund")
	if(price_vouchers > 0)
		var/obj/item/stack/trade_voucher/vouchers = new(user.drop_location(), price_vouchers)
		user.put_in_hands(vouchers)
	if(crew_limit > 0)
		crew_ship?.get_crew_record()?.release_purchase(type)
	to_chat(user, span_warning("Something's wrong with that one. Your money's back."))

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

/// Base for the ordinary exosuit gear lines (Exosuit Arms, Ammo and Fittings tabs).
/datum/shop_sku/rig_bay_gear
	category = "Exosuit Fittings"
	stock_min = 1
	stock_max = 3

// Exosuit Arms. The green arms and the missile rack sit on the core shelf; the yellow arms
// come through /datum/shop_rotation/rig_bay_arms, one of each.

/datum/shop_sku/rig_bay_gear/arm
	category = "Exosuit Arms"
	stock_min = 1
	stock_max = 2

/datum/shop_sku/rig_bay_gear/arm/kinetic
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/energy/mecha_kineticgun
	price_credits = 600

/datum/shop_sku/rig_bay_gear/arm/plasma_cutter
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/energy/plasma
	price_credits = 500

/datum/shop_sku/rig_bay_gear/arm/disabler
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/energy/disabler
	price_credits = 900

/datum/shop_sku/rig_bay_gear/arm/missile_rack
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/missile_rack/breaching
	zone_permission = ZONE_PERMISSION_ADVANCED
	price_credits = 4000
	price_vouchers = 2
	stock_min = 1
	stock_max = 1
	convoys_per_unit = 3

/datum/shop_sku/rig_bay_gear/arm/lmg
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 4000
	stock_max = 1

/datum/shop_sku/rig_bay_gear/arm/laser
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/energy/laser
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 2500
	stock_max = 1

/datum/shop_sku/rig_bay_gear/arm/laser_heavy
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/energy/laser/heavy
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 3000
	stock_max = 1

/datum/shop_sku/rig_bay_gear/arm/scattershot
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/scattershot
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 3000
	stock_max = 1

/datum/shop_sku/rig_bay_gear/arm/carbine
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/carbine
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 3500
	stock_max = 1

/datum/shop_sku/rig_bay_gear/arm/ion
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/energy/ion
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 3500
	stock_max = 1

/datum/shop_sku/rig_bay_gear/arm/tesla
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/energy/tesla
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 2500
	stock_max = 1

/datum/shop_sku/rig_bay_gear/arm/flashbang_launcher
	item_path = /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/flashbang
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 3000
	stock_max = 1

// Exosuit Ammo

/datum/shop_sku/rig_bay_gear/ammo
	category = "Exosuit Ammo"
	stock_min = 4
	stock_max = 6

/datum/shop_sku/rig_bay_gear/ammo/lmg
	item_path = /obj/item/mecha_ammo/lmg
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 150

/datum/shop_sku/rig_bay_gear/ammo/scattershot
	item_path = /obj/item/mecha_ammo/scattershot
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 150

/datum/shop_sku/rig_bay_gear/ammo/incendiary
	item_path = /obj/item/mecha_ammo/incendiary
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 250

/datum/shop_sku/rig_bay_gear/ammo/flashbang
	item_path = /obj/item/mecha_ammo/flashbang
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 300

/datum/shop_sku/rig_bay_gear/ammo/missiles
	item_path = /obj/item/mecha_ammo/missiles_pep
	zone_permission = ZONE_PERMISSION_ADVANCED
	price_credits = 800

// Exosuit Fittings

/datum/shop_sku/rig_bay_gear/projectile_shielding
	item_path = /obj/item/mecha_parts/mecha_equipment/armor/antiproj_armor_booster
	zone_permission = ZONE_PERMISSION_YELLOW
	price_credits = 2500

/datum/shop_sku/rig_bay_gear/impact_plates
	item_path = /obj/item/mecha_parts/mecha_equipment/armor/anticcw_armor_booster
	price_credits = 900

/datum/shop_sku/rig_bay_gear/ablative_insulation
	item_path = /obj/item/mecha_parts/mecha_equipment/armor/antiemp_armor_booster
	price_credits = 1200

/datum/shop_sku/rig_bay_gear/drill
	item_path = /obj/item/mecha_parts/mecha_equipment/drill
	price_credits = 300

/datum/shop_sku/rig_bay_gear/hydraulic_clamp
	item_path = /obj/item/mecha_parts/mecha_equipment/hydraulic_clamp
	price_credits = 300

/datum/shop_sku/rig_bay_gear/repair_droid
	item_path = /obj/item/mecha_parts/mecha_equipment/repair_droid
	price_credits = 1200
