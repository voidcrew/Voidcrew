/// Service ownership is physical. A docked vessel always wins over its host.
/// Keep get_ship_from_atom() ship-only; callers opt into this small service API.
/proc/get_outpost_from_atom(atom/thing)
	var/turf/location = get_turf(thing)
	if(!location)
		return null
	for(var/obj/structure/overmap/dynamic/player_outpost/site as anything in GLOB.player_outposts)
		if(!site.contains_service_turf(location))
			continue
		// Do the more expensive vessel lookup only on potential claim ground.
		// A hull being assembled also wins before its overmap ship is assigned.
		var/obj/docking_port/mobile/port = SSshuttle.get_containing_shuttle(location)
		if(istype(port, /obj/docking_port/mobile/voidcrew) || get_voidcrew_ship_for_turf(location))
			return null
		return site
	return null

/proc/get_service_site(atom/thing)
	return get_voidcrew_ship_for_turf(get_turf(thing)) || get_outpost_from_atom(thing)

/proc/same_service_site(atom/first, atom/second)
	var/turf/first_turf = get_turf(first)
	var/turf/second_turf = get_turf(second)
	if(!first_turf || !second_turf)
		return FALSE
	var/obj/structure/overmap/site = get_service_site(first)
	var/obj/structure/overmap/other = get_service_site(second)
	if(site || other)
		return site && site == other
	return is_valid_z_level(first_turf, second_turf)

/datum/outpost_berth/proc/contains_service_turf(turf/location)
	if(!reservation || !location)
		return FALSE
	var/turf/origin = reservation.bottom_left_turfs[1]
	return origin && location.z == origin.z && location.x >= origin.x && location.y >= origin.y \
		&& location.x < origin.x + reservation.width && location.y < origin.y + reservation.height

/obj/structure/overmap/dynamic/player_outpost/proc/contains_service_turf(turf/location)
	if(is_turf_buildable(location))
		return TRUE
	if(freight_berth?.contains_service_turf(location))
		return TRUE
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth?.contains_service_turf(location))
			return TRUE
	return FALSE

/obj/structure/overmap/dynamic/player_outpost
	/// Character permissions, separate from saved player-account arrival clearance.
	var/list/datum/mind/stewards = list()
	var/list/datum/mind/treasurers = list()
	var/datum/bank_account/outpost/treasury
	var/datum/voidcrew_cargo_shuttle/outpost/freight
	var/datum/outpost_berth/freight_berth
	var/list/datum/supply_order/cargo_cart = list()
	/// Set only by the founding flow, never by rebuilding a terminal.
	var/home_bundle_installed = FALSE

/obj/structure/overmap/dynamic/player_outpost/proc/can_manage(mob/user)
	return founder_ckey && (is_owner(user) || (user?.mind && user.mind in stewards))

/obj/structure/overmap/dynamic/player_outpost/proc/can_spend(mob/user)
	return founder_ckey && (is_owner(user) || (user?.mind && user.mind in treasurers))

/obj/structure/overmap/dynamic/player_outpost/proc/ensure_home_services()
	if(!treasury)
		treasury = new("[name] Treasury", player_account = FALSE)
		treasury.claim = WEAKREF(src)
	if(!freight)
		freight = new(src)

/datum/bank_account/outpost
	var/datum/weakref/claim

/datum/bank_account/outpost/adjust_money(amount, reason)
	return ..(amount, reason || "Outpost account adjustment")

/// No ID is ever rebound to this account. Deposits name both parties explicitly.
/obj/structure/overmap/dynamic/player_outpost/proc/deposit_from(mob/living/user, amount)
	var/datum/bank_account/source = user.get_idcard(TRUE)?.registered_account
	if(!source || source == treasury || !valid_cargo_order_quantity(amount, 1000000))
		return FALSE
	if(!source.adjust_money(-amount, "Deposit to [treasury.account_holder] by [user.ckey]"))
		return FALSE
	treasury.adjust_money(amount, "Deposit from [source.account_holder] by [user.ckey]")
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/proc/withdraw_to(mob/living/user, amount)
	var/datum/bank_account/recipient = user.get_idcard(TRUE)?.registered_account
	if(!can_spend(user) || !recipient || recipient == treasury || !valid_cargo_order_quantity(amount, 1000000))
		return FALSE
	if(!treasury.adjust_money(-amount, "Withdrawal to [recipient.account_holder] by [user.ckey]"))
		return FALSE
	recipient.adjust_money(amount, "Withdrawal from [treasury.account_holder] by [user.ckey]")
	return TRUE

/// A bank terminal on claim ground always represents that claim, never an inserted ID.
/obj/machinery/computer/bank_machine/proc/resolve_outpost_bank()
	var/obj/structure/overmap/dynamic/player_outpost/site = get_outpost_from_atom(src)
	if(site)
		site.ensure_home_services()
		synced_bank_account = site.treasury
	else if(istype(synced_bank_account, /datum/bank_account/outpost))
		synced_bank_account = null
	return site

/// Refuse a copied treasury link on a visiting vessel as well as unauthorized use on shore.
/obj/machinery/computer/voidcrew_cargo
	/// Presence denotes a borrowed cart, even after the claim itself has been deleted.
	var/datum/weakref/cart_outpost_ref

/obj/machinery/computer/voidcrew_cargo/proc/cargo_account()
	var/obj/structure/overmap/dynamic/player_outpost/site = get_outpost_from_atom(src)
	if(cart_outpost_ref && (!cart_outpost_ref.resolve() || cart_outpost_ref.resolve() != site))
		checkout_list = list()
		cart_outpost_ref = null
	if(site)
		site.ensure_home_services()
		if(checkout_list != site.cargo_cart)
			if(!cart_outpost_ref)
				QDEL_LIST(checkout_list)
			checkout_list = site.cargo_cart
		cart_outpost_ref = WEAKREF(site)
		return site.treasury
	if(istype(bank_account_holder?.synced_bank_account, /datum/bank_account/outpost))
		return null
	return bank_account_holder?.synced_bank_account

/obj/structure/overmap/dynamic/player_outpost/on_ship_undock_complete(obj/structure/overmap/ship/ship)
	approved_ships -= ship
	return ..()

/datum/component/remote_materials/can_use_resource(check_hold = TRUE, alist/user_data)
	if(silo && !check_z_level())
		return FALSE
	return ..()

/datum/component/remote_materials/attempt_insert(mob/living/user, obj/item/target)
	if(silo && !check_z_level())
		return ITEM_INTERACT_BLOCKING
	return ..()
