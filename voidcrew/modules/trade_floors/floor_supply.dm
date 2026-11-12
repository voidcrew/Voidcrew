/**
 * # Outpost floors: supplies and the goods lift
 *
 * Owner: P13 (spec 3b.2, L30). The supply console is the old shells' (/obj/machinery/computer/voidcrew_cargo): on a
 * floor it already finds the host's freight (get_cargo_shuttle()) and pays from the host's treasury
 * (cargo_account()). A floor has no ferry and no cargo dock: its freight makes the ordered crates on the goods
 * lift's tiles (floor.goods_turfs) OUTPOST_FLOOR_GOODS_TIME after the order, OUTPOST_FLOOR_GOODS_CRATES at most, and
 * sends nothing back (A84). The fit-out supply packs live here too. The goods lift fixture is declared in floor_shell.dm.
 *
 * The freight keeps the outpost freight's bookkeeping (reserved_orders, cancel_pending(), the treasury log, the
 * metrics) and replaces everything that touches a ferry:
 * - AWAY -> ARRIVING -> AWAY. It is never DOCKED and never DEPARTING, so there is no send and no export.
 * - An order is paid for when it is placed. Only as many orders as the lift has tiles are taken; the rest stay in
 *   the cart, unpaid, for the next delivery.
 * - A delivery is refused while a crate stands on the lift, and one already on its way waits for the lift to clear.
 * - Whatever is paid for and has not come up is refunded when the floor is given up or deleted.
 */

/// How often a delivery held by a full lift looks again
#define FLOOR_GOODS_RETRY (5 SECONDS)

/datum/voidcrew_cargo_shuttle/outpost/floor
	/// What the lift last brought up, as weakrefs. A package still standing on the lift holds the next delivery.
	var/list/datum/weakref/supply_delivered = list()
	/// The console has said this delivery is waiting for the lift to be cleared: it says so once
	var/supply_hold_announced = FALSE

/// The floor this freight serves, or null
/datum/voidcrew_cargo_shuttle/outpost/floor/proc/goods_floor()
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = home
	if(!istype(host) || QDELETED(host))
		return null
	return host.floor

/// The goods lift's tiles
/datum/voidcrew_cargo_shuttle/outpost/floor/proc/goods_tiles()
	var/datum/outpost_floor/floor = goods_floor()
	return floor ? floor.goods_turfs : list()

/// Whether a crate, a locker or anything the lift brought up still stands on the goods lift
/datum/voidcrew_cargo_shuttle/outpost/floor/proc/goods_lift_blocked()
	var/list/turf/tiles = goods_tiles()
	for(var/turf/tile as anything in tiles)
		if(locate(/obj/structure/closet) in tile)
			return TRUE
	for(var/datum/weakref/delivered_ref in supply_delivered)
		var/atom/movable/package = delivered_ref.resolve()
		if(!QDELETED(package) && (package.loc in tiles))
			return TRUE
		// Carried off or gone: it never holds a delivery again
		supply_delivered -= delivered_ref
	return FALSE

/datum/voidcrew_cargo_shuttle/outpost/floor/availability_error()
	if(!home?.founder_ckey)
		return "No lease holder"
	if(!length(goods_tiles()))
		return "No goods lift"
	if(goods_lift_blocked())
		return "Clear the goods lift"
	return null

/datum/voidcrew_cargo_shuttle/outpost/floor/call_shuttle(obj/structure/overmap/ship/unused)
	return dispatch_orders()

/**
 * Takes payment for the first orders in the cart, as many as the lift has tiles, and starts the lift.
 * Nothing here yields. Returns null when the delivery is on its way, or the reason it is not.
 */
/datum/voidcrew_cargo_shuttle/outpost/floor/dispatch_orders()
	if(state != CARGO_SHUTTLE_AWAY || busy)
		return "A delivery is already on its way"
	var/error = availability_error()
	if(error)
		return error
	var/room = min(OUTPOST_FLOOR_GOODS_CRATES, length(goods_tiles()))
	delivery_generation++
	last_error = null
	for(var/datum/supply_order/order in home.cargo_cart)
		if(length(reserved_orders) >= room)
			break
		if(!order.settle_ship_order(home.treasury))
			last_error = order.ship_settlement_error
			cancel_pending()
			return last_error
		reserved_orders += order
		home.treasury.add_log_to_history(0, "Reserved order #[order.id]: [order.pack.name], [order.ship_paid_cost] cr to cargo registry, authorized by [order.orderer_ckey]")
	if(!length(reserved_orders))
		return "No orders in cart"
	state = CARGO_SHUTTLE_ARRIVING
	supply_hold_announced = FALSE
	warmup_started = world.time
	stall_deadline = world.time + OUTPOST_FLOOR_GOODS_TIME + CARGO_SHUTTLE_STALL_GRACE
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), OUTPOST_FLOOR_GOODS_TIME, TIMER_STOPPABLE)
	return null

/// Refunds what was paid for and has not come up. With the floor's treasury already gone there is nobody to refund.
/datum/voidcrew_cargo_shuttle/outpost/floor/cancel_pending()
	if(!home?.treasury)
		reserved_orders.Cut()
		return
	return ..()

/// Seconds until the lift comes up, for the console
/datum/voidcrew_cargo_shuttle/outpost/floor/get_remaining_time()
	if(state != CARGO_SHUTTLE_ARRIVING || !warmup_started)
		return 0
	return round(max(0, OUTPOST_FLOOR_GOODS_TIME - (world.time - warmup_started)) / 10)

/// Timer callback: the lift comes up
/datum/voidcrew_cargo_shuttle/outpost/floor/complete_arrival()
	if(state != CARGO_SHUTTLE_ARRIVING || busy)
		return FALSE
	warmup_timer = null
	var/arrival_generation = delivery_generation
	. = deliver_orders()
	if(QDELETED(src) || arrival_generation != delivery_generation || !busy)
		return
	// deliver_orders() was cut short with a package half made. What has landed stays; the rest is refunded.
	last_error = "Delivery interrupted; undelivered orders refunded"
	busy = FALSE
	cleanup_shuttle()
	return FALSE

/**
 * Makes each paid order's crate on a tile of the goods lift. Returns TRUE when something came up.
 * The packing follows the outpost freight's (outpost_freight.dm): each package is made off the map first, so a
 * failed generator leaves no paid fragments on the deck and its order stays in the cart, refunded.
 */
/datum/voidcrew_cargo_shuttle/outpost/floor/deliver_orders()
	if(state != CARGO_SHUTTLE_ARRIVING || busy)
		return FALSE
	var/datum/outpost_floor/floor = goods_floor()
	// The floor went first, was given up, or its orders were already refunded: nothing comes up
	if(!floor || !home.founder_ckey || !length(floor.goods_turfs) || !length(reserved_orders))
		cleanup_shuttle()
		return FALSE
	// A crate still stands on the lift: the delivery waits for it, paid for and untouched (A84)
	if(goods_lift_blocked())
		warmup_started = null
		stall_deadline = world.time + FLOOR_GOODS_RETRY + CARGO_SHUTTLE_STALL_GRACE
		warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), FLOOR_GOODS_RETRY, TIMER_STOPPABLE)
		if(!supply_hold_announced)
			supply_hold_announced = TRUE
			linked_console?.say("Clear the goods lift.")
		return FALSE
	busy = TRUE
	var/operation_generation = delivery_generation
	var/list/turf/free_tiles = floor.goods_turfs.Copy()
	var/list/turf/landed_on = list()
	for(var/datum/supply_order/order in reserved_orders.Copy())
		if(!length(free_tiles))
			break
		if(QDELETED(home) || state != CARGO_SHUTTLE_ARRIVING || !(order in reserved_orders) || isnull(order.ship_paid_cost))
			return FALSE
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
			log_shuttle("OUTPOST FLOOR GOODS: order #[order.id] generation failed: [generation_error]")
			package = null
		// A generator may give the floor up or delete it. Check that before looking at what it made.
		if(QDELETED(src) || operation_generation != delivery_generation)
			qdel(package)
			qdel(staging)
			return FALSE
		if(QDELETED(home) || state != CARGO_SHUTTLE_ARRIVING || !(order in reserved_orders) || isnull(order.ship_paid_cost))
			qdel(package)
			qdel(staging)
			return FALSE
		if(QDELETED(package))
			qdel(staging)
			last_error = "An order could not be packed; undelivered orders refunded"
			break
		var/obj/structure/closet/crate/crate = astype(package)
		if(crate)
			crate.locked = FALSE
			crate.update_appearance()
		var/turf/tile = free_tiles[1]
		free_tiles.Cut(1, 2)
		package.forceMove(tile)
		// Landed means delivered: off the books before anything else can go wrong and refund it
		reserved_orders -= order
		home.cargo_cart -= order
		qdel(staging)
		landed_on += tile
		supply_delivered += WEAKREF(package)
		record_transaction("buy", order.pack.name, 1, order.ship_paid_cost)
		home.treasury.add_log_to_history(0, "Delivered order #[order.id] from cargo registry: [order.ship_paid_cost] cr")
		SSeconomy.track_purchase(home.treasury, order.ship_paid_cost, order.pack.name)
		SSeconomy.import_total += order.ship_paid_cost
		metric_outpost_cargo_order(home, order)
		record_floor_metric("floor_supply_order", floor, null, order.ship_paid_cost)
		qdel(order)
	// Whatever could not be packed is refunded and stays in the cart
	cancel_pending()
	state = CARGO_SHUTTLE_AWAY
	stall_deadline = 0
	warmup_started = null
	busy = FALSE
	if(!length(landed_on))
		return FALSE
	announce_delivery(landed_on)
	return TRUE

/// The chime, and the hatch says so. With no hatch mapped the floor's people are told instead.
/datum/voidcrew_cargo_shuttle/outpost/floor/proc/announce_delivery(list/turf/landed_on)
	playsound(landed_on[1], 'sound/machines/chime.ogg', 50, FALSE)
	for(var/turf/tile as anything in landed_on)
		var/obj/structure/outpost_goods_lift/hatch = locate() in tile
		if(hatch)
			hatch.say("Delivery.")
			return
	home.ship_notify("Goods lift: delivery.", "CARGO")

// A floor has no ferry: nothing is ever made, parked, sent away or sold (A84).

/datum/voidcrew_cargo_shuttle/outpost/floor/spawn_shuttle()
	return FALSE

/datum/voidcrew_cargo_shuttle/outpost/floor/claim_parking(datum/map_template/shuttle/template)
	return null

/datum/voidcrew_cargo_shuttle/outpost/floor/send_shuttle()
	return FALSE

/datum/voidcrew_cargo_shuttle/outpost/floor/complete_departure()
	return FALSE

/datum/voidcrew_cargo_shuttle/outpost/floor/Destroy()
	supply_delivered.Cut()
	return ..()

// The console's words for the goods lift (the seam in cargo_shuttle.dm)
/datum/voidcrew_cargo_shuttle/outpost/floor/freight_name()
	return "Goods Lift"

/datum/voidcrew_cargo_shuttle/outpost/floor/freight_call_text()
	return "Call lift"

/datum/voidcrew_cargo_shuttle/outpost/floor/freight_called_text()
	return "Goods lift called."

/// A call pays for the first orders in the cart, as many as the lift takes (dispatch_orders()); the rest wait
/datum/voidcrew_cargo_shuttle/outpost/floor/call_cost(list/datum/supply_order/orders)
	. = 0
	var/room = min(OUTPOST_FLOOR_GOODS_CRATES, length(goods_tiles()))
	for(var/datum/supply_order/order as anything in orders)
		if(room-- <= 0)
			break
		. += order.get_final_cost()

#undef FLOOR_GOODS_RETRY

// ===== THE GOODS LIFT =====

/// The hatch over the goods lift. One a tile or one for the lot: the freight only reads floor.goods_turfs.
/obj/structure/outpost_goods_lift
	desc = "A hatch in the deck, over the outpost's goods lift."
	icon = 'icons/turf/floors.dmi'
	icon_state = "elevatorshaft"
	density = FALSE
	plane = FLOOR_PLANE
	layer = CATWALK_LAYER
	obj_flags = NONE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	move_resist = INFINITY

/obj/structure/outpost_goods_lift/Initialize(mapload)
	. = ..()
	// Outpost ground like the landing: no tool, blast or singularity takes it (the element is idempotent)
	AddElement(/datum/element/outpost_property)
	ADD_TRAIT(src, TRAIT_SINGULARITY_IMMUNE, INNATE_TRAIT)
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/outpost_goods_lift/update_overlays()
	. = ..()
	. += mutable_appearance('icons/turf/decals.dmi', "bot")

// ===== FIT-OUT SUPPLY PACKS (spec 3b.2, 3b.4) =====
// On every supply console, a ship's too: a crew may order aboard and carry the crate up the lift. A fitting kit only
// deploys on a floor's deck (floor_fittings.dm). Nothing here has an export value, so a crate is worth its box.

/datum/supply_pack/outpost_fitout
	group = "Fit-Out"
	crate_type = /obj/structure/closet/crate

/datum/supply_pack/outpost_fitout/decorator
	name = "Decorator's Crate"
	desc = "Paint, spraycans, a decal painter, an airlock painter and spare toner."
	cost = 500
	contains = list(
		/obj/item/airlock_painter/decal = 1,
		/obj/item/airlock_painter = 1,
		/obj/item/toner = 2,
		/obj/item/paint/anycolor = 2,
		/obj/item/toy/crayon/spraycan = 2,
	)
	crate_name = "decorator's crate"

/datum/supply_pack/outpost_fitout/lighting
	name = "Lighting Crate"
	desc = "Light fixtures, switches, and a mixed box of tubes and bulbs."
	cost = 400
	contains = list(
		/obj/item/wallframe/light_fixture = 6,
		/obj/item/wallframe/light_fixture/small = 4,
		/obj/item/wallframe/light_switch = 2,
		/obj/item/storage/box/lights/mixed = 2,
	)
	crate_name = "lighting crate"

/datum/supply_pack/outpost_fitout/signwriter
	name = "Signwriter's Crate"
	desc = "Sign backings, picture frames, a bar sign frame and a fountain pen."
	cost = 350
	contains = list(
		/obj/item/sign = 4,
		/obj/item/wallframe/picture = 4,
		/obj/item/wallframe/barsign = 1,
		/obj/item/pen/fountain = 1,
	)
	crate_name = "signwriter's crate"

/datum/supply_pack/outpost_fitout/shop_fittings
	name = "Shop Fittings Crate"
	desc = "A till, four sale shelves and a floor sign, boxed."
	cost = 1000
	contains = list(
		/obj/item/outpost_floor_kit/till = 1,
		/obj/item/outpost_floor_kit/shelf = 4,
		/obj/item/outpost_floor_kit/sign = 1,
	)
	crate_name = "shop fittings crate"

/datum/supply_pack/outpost_fitout/till
	name = "Till Crate"
	desc = "A till, boxed."
	cost = 400
	contains = list(/obj/item/outpost_floor_kit/till = 1)
	crate_name = "till crate"

/datum/supply_pack/outpost_fitout/shelves
	name = "Sale Shelf Crate"
	desc = "Four sale shelves, boxed."
	cost = 600
	contains = list(/obj/item/outpost_floor_kit/shelf = 4)
	crate_name = "sale shelf crate"

/datum/supply_pack/outpost_fitout/signs
	name = "Floor Sign Crate"
	desc = "Two floor signs, boxed."
	cost = 300
	contains = list(/obj/item/outpost_floor_kit/sign = 2)
	crate_name = "floor sign crate"
