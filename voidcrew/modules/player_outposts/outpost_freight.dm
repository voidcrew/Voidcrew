/// The claim owns orders and reservations. Consoles are replaceable views.
/datum/voidcrew_cargo_shuttle/outpost
	var/obj/structure/overmap/dynamic/player_outpost/home
	var/list/datum/supply_order/reserved_orders = list()
	var/busy = FALSE
	var/last_error

/datum/voidcrew_cargo_shuttle/outpost/New(obj/structure/overmap/dynamic/player_outpost/site)
	home = site

/datum/voidcrew_cargo_shuttle/outpost/Destroy()
	cancel_pending()
	. = ..()
	home = null

/datum/voidcrew_cargo_shuttle/outpost/proc/availability_error()
	if(!home?.founder_ckey)
		return "Claim has no owner; freight is suspended"
	if(!home.has_hangar_elevator() || !home.freight_berth?.panel || !home.freight_berth?.dock)
		return "No freight receiver or elevator connection; repair the receiving facility"
	return null

/datum/voidcrew_cargo_shuttle/outpost/call_shuttle(obj/structure/overmap/ship/unused)
	if(state != CARGO_SHUTTLE_AWAY || busy || load_pending)
		return "Freight is already dispatched"
	// Keep a normal proc boundary around map loading. A broad catch makes BYOND
	// unwind past the map reader's cleanup on an otherwise recoverable map error.
	. = dispatch_orders()
	if(!busy)
		return
	// An aborted dispatch did not reach its normal completion/rollback path.
	last_error = "Freight preparation interrupted; reservations refunded"
	busy = FALSE
	cleanup_shuttle()
	return last_error

/datum/voidcrew_cargo_shuttle/outpost/proc/dispatch_orders()
	if(state != CARGO_SHUTTLE_AWAY || busy)
		return "Freight is already dispatched"
	var/error = availability_error()
	if(error)
		return error
	state = CARGO_SHUTTLE_ARRIVING
	busy = TRUE
	last_error = null
	// Reserve payment and finite market stock together, before any yielding work.
	for(var/datum/supply_order/order as anything in home.cargo_cart)
		if(!order.settle_ship_order(home.treasury))
			last_error = order.ship_settlement_error
			cancel_pending()
			busy = FALSE
			state = CARGO_SHUTTLE_AWAY
			return last_error
		reserved_orders += order
		home.treasury.add_log_to_history(0, "Reserved order #[order.id]: [order.pack.name], [order.ship_paid_cost] cr to cargo registry, authorized by [order.orderer_ckey]")
	if(!spawn_shuttle())
		last_error = "Unable to prepare freight vessel"
	if(last_error || QDELETED(home) || availability_error())
		last_error ||= "Receiver became unavailable"
		busy = FALSE
		cleanup_shuttle()
		return last_error
	var/list/floors = get_cargo_bay_turfs()
	if(length(reserved_orders) > length(floors))
		last_error = "Shipment exceeds freight capacity ([length(floors)] packages); reduce the cart"
		busy = FALSE
		cleanup_shuttle()
		return last_error
	warmup_started = world.time
	stall_deadline = world.time + CARGO_SHUTTLE_WARMUP + CARGO_SHUTTLE_STALL_GRACE
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), CARGO_SHUTTLE_WARMUP, TIMER_STOPPABLE)
	busy = FALSE
	return null

/// Refunding a cancelled reservation does not create new market stock or a second payment.
/datum/voidcrew_cargo_shuttle/outpost/proc/cancel_pending()
	for(var/datum/supply_order/order as anything in reserved_orders)
		if(isnull(order.ship_paid_cost))
			continue
		home.treasury.adjust_money(order.ship_paid_cost, "Refund of undelivered cargo order #[order.id]")
		var/datum/supply_pack/custom/minerals/materials = astype(order.pack)
		if(materials)
			for(var/obj/item/stack/sheet/sheet_type as anything in materials.contains)
				SSstock_market.adjust_material_quantity(initial(sheet_type.material_type), materials.contains[sheet_type])
		order.ship_paid_cost = null
	reserved_orders.Cut()

/datum/voidcrew_cargo_shuttle/outpost/cleanup_shuttle()
	cancel_pending()
	return ..()

/datum/voidcrew_cargo_shuttle/outpost/check_stalled()
	if(busy)
		return
	return ..()

/datum/voidcrew_cargo_shuttle/outpost/complete_arrival()
	if(state != CARGO_SHUTTLE_ARRIVING || busy)
		return FALSE
	. = deliver_orders()
	if(!busy)
		return
	last_error = "Freight arrival interrupted; undelivered reservations refunded"
	busy = FALSE
	cancel_pending()
	// Preserve already delivered goods if an unrelated failure interrupted a
	// later package. The physical deck remains accessible for unloading.
	if(shuttle_port && home?.freight_berth?.dock && shuttle_port.get_docked() == home.freight_berth.dock)
		state = CARGO_SHUTTLE_DOCKED
		stall_deadline = 0
	else
		cleanup_shuttle()
	return FALSE

/datum/voidcrew_cargo_shuttle/outpost/proc/deliver_orders()
	if(state != CARGO_SHUTTLE_ARRIVING || busy)
		return FALSE
	warmup_timer = null
	busy = TRUE
	var/error = availability_error()
	if(!error && shuttle_port && !home.freight_berth.dock.get_docked())
		adjust_reserve_dock_to_shuttle(home.freight_berth.dock, shuttle_port)
		if(shuttle_port.initiate_docking(home.freight_berth.dock) != DOCKING_SUCCESS)
			error = "Freight berth is obstructed; clear the landing pad and retry"
	else
		error ||= "Freight receiver unavailable"
	if(!error)
		error = availability_error()
	if(error)
		last_error = error
		busy = FALSE
		cleanup_shuttle()
		return FALSE
	var/list/turf/available = list()
	for(var/turf/open/floor/location in get_cargo_bay_turfs())
		if(!location.is_blocked_turf())
			available += location
	if(length(available) < length(reserved_orders))
		last_error = "Freight deck is blocked; reservations refunded"
		busy = FALSE
		cleanup_shuttle()
		return FALSE
	for(var/datum/supply_order/order as anything in reserved_orders.Copy())
		// Stage each complete package off-map. A failed generator cannot leave paid
		// fragments on the deck, and the cart survives for retry after its refund.
		var/obj/effect/staging = new(null)
		var/obj/package
		try
			if(order.pack.goody)
				package = new /obj/item/storage/box(staging)
				package.name = "goody package - [order.pack.name]"
				ADD_TRAIT(package, TRAIT_NO_MISSING_ITEM_ERROR, TRAIT_GENERIC)
				ADD_TRAIT(package, TRAIT_NO_MANIFEST_CONTENTS_ERROR, TRAIT_GENERIC)
				order.pack.fill(package)
				order.generateManifest(package, home.name, order.pack, order.ship_paid_cost)
			else
				package = order.generate(staging)
		catch(var/exception/generation_error)
			log_shuttle("OUTPOST FREIGHT: order #[order.id] generation failed: [generation_error]")
			package = null
		if(QDELETED(package))
			qdel(staging)
			last_error = "An order could not be packed; undelivered orders refunded"
			break
		var/obj/structure/closet/crate/crate = astype(package)
		if(crate)
			crate.locked = FALSE
			crate.update_appearance()
		package.forceMove(available[1])
		available.Cut(1, 2)
		qdel(staging)
		reserved_orders -= order
		home.cargo_cart -= order
		record_transaction("buy", order.pack.name, 1, order.ship_paid_cost)
		home.treasury.add_log_to_history(0, "Delivered order #[order.id] from cargo registry: [order.ship_paid_cost] cr")
		SSeconomy.track_purchase(home.treasury, order.ship_paid_cost, order.pack.name)
		SSeconomy.import_total += order.ship_paid_cost
		qdel(order)
	cancel_pending()
	state = CARGO_SHUTTLE_DOCKED
	stall_deadline = 0
	busy = FALSE
	home.ship_notify("Freight has arrived. Take the elevator to Freight Receiving.", "CARGO")
	return TRUE

/// Contents may hold a passenger inside a crate or mech, not just on a floor.
/datum/voidcrew_cargo_shuttle/outpost/has_living_mobs()
	if(!shuttle_port)
		return FALSE
	for(var/mob/living/passenger as anything in GLOB.alive_mob_list)
		if(shuttle_port.is_in_shuttle_bounds(passenger))
			return TRUE
	return FALSE

/datum/voidcrew_cargo_shuttle/outpost/complete_departure()
	if(state != CARGO_SHUTTLE_DEPARTING || busy)
		return FALSE
	warmup_timer = null
	if(has_living_mobs())
		state = CARGO_SHUTTLE_DOCKED
		stall_deadline = 0
		last_error = "Departure cancelled: remove living passengers from the freight vessel"
		return FALSE
	busy = TRUE
	if(!length(GLOB.exports_list))
		setupExports()
	var/datum/export_report/report = new
	for(var/turf/location as anything in get_cargo_bay_turfs())
		for(var/atom/movable/goods in location)
			if(goods.anchored || ismob(goods) || istype(goods, /obj/docking_port) || istype(goods, /obj/effect/landmark))
				continue
			export_item_and_contents(goods, dry_run = FALSE, external_report = report)
	for(var/datum/export/export as anything in report.total_amount)
		var/value = report.total_value[export]
		home.treasury.adjust_money(value, "Export to cargo registry: [report.total_amount[export]] [export.unit_name]")
		record_transaction("sell", export.unit_name || "goods", report.total_amount[export], value)
		SSeconomy.export_total += value
	qdel(report)
	destroy_shuttle()
	busy = FALSE
	state = CARGO_SHUTTLE_AWAY
	stall_deadline = 0
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/proc/install_freight_receiver()
	if(freight_berth)
		return TRUE
	if(!GLOB.outpost_hangar_template)
		GLOB.outpost_hangar_template = new
	var/datum/map_template/outpost_hangar/template = GLOB.outpost_hangar_template
	var/datum/turf_reservation/reservation = SSmapping.request_turf_block_reservation(template.width, template.height, 1)
	if(!reservation)
		return FALSE
	var/datum/outpost_berth/berth = new(src, OUTPOST_MAX_BERTHS + 1, null)
	berth.reservation = reservation
	berth.hangar_bottom_left = reservation.bottom_left_turfs[1]
	if(!template.load(berth.hangar_bottom_left) || !berth.link_hangar_contents())
		qdel(berth)
		return FALSE
	freight_berth = berth
	for(var/obj/machinery/status_display/outpost_berth/sign as anything in berth.status_signs)
		sign.set_messages("FREIGHT", "RECEIVING")
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/get_floor_alcove(floor_id)
	if(floor_id == OUTPOST_MAX_BERTHS + 1)
		return freight_berth?.alcove_turfs
	return ..()

/obj/structure/overmap/dynamic/player_outpost/proc/install_home_bundle()
	if(home_bundle_installed)
		return TRUE
	if(!outpost_area || !management_console || !construction_console || !has_hangar_elevator() || !arrival_turf)
		return FALSE
	if(!install_freight_receiver())
		return FALSE
	// Use actual free habitat floors, leaving elevator alcoves and door approaches clear.
	var/list/turf/locations = list()
	for(var/turf/open/floor/location in outpost_area)
		if(location == arrival_turf || location in lobby_alcove_turfs || length(location.contents))
			continue
		var/near_door = FALSE
		for(var/obj/machinery/door/door in range(1, location))
			near_door = TRUE
		if(!near_door)
			locations += location
	if(length(locations) < 3)
		return FALSE
	new /obj/machinery/computer/voidcrew_cargo(locations[1])
	new /obj/machinery/computer/bank_machine(locations[2])
	var/obj/machinery/cryopod/pod = new(locations[3])
	pod.relink_to_ship()
	home_bundle_installed = TRUE
	return TRUE
