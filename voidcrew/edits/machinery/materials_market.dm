/**
 * VOIDCREW EDIT: the Galactic Materials Market, aboard a ship.
 *
 * The stock machine is a fixture of a station cargo department: it quotes against
 * ACCOUNT_CAR or the buyer's own ID, gates the budget on ACCESS_CARGO, and files its
 * finished /datum/supply_order into SSshuttle.shopping_list for the station's supply
 * shuttle to ship. None of those three things exist here.
 *
 * - There is no station and no ACCOUNT_CAR to spend; ships bank through their own
 *   /obj/machinery/computer/bank_machine.
 * - Ship crews are issued no ACCESS_CARGO at all (see the airlock unlock in
 *   /datum/voidcrew_cargo_shuttle/spawn_shuttle), so every buyer was forced into private
 *   mode and quoted against their personal wallet.
 * - Nothing in this fork ever reads SSshuttle.shopping_list. Deliveries come off the
 *   per-ship cargo console's own `checkout_list`, shipped by purchasing.dm's buy() when
 *   the ferry docks. The bitrunning vendor already ran into this and went express-only
 *   (code/modules/bitrunning/objects/vendor.dm).
 *
 * So a purchase here charged nothing, shipped nothing and told the buyer it was on its
 * way (issue #255). This files it with the ship's cargo console instead, on the same
 * terms as everything else in that cart: paid by the ship's account when the ferry docks,
 * crate open to the whole crew.
 *
 * A market that is not aboard a ship at all (an admin spawn, a ruin) refuses outright
 * rather than quietly filing into SSshuttle.shopping_list and never delivering.
 */

/// How long a resolved cargo console is trusted before we go looking again. ui_data() asks
/// several of these seams every tick and get_containing_shuttle() walks every mobile port
/// in the world, so this is not a lookup to repeat four times a tick per viewer.
#define MARKET_CONSOLE_CACHE_TIME (10 SECONDS)

/obj/machinery/materials_market
	/// Cached result of find_ship_cargo_console(), see MARKET_CONSOLE_CACHE_TIME.
	var/datum/weakref/cached_cargo_console
	/// world.time the cache above was last filled. 0 means "never resolved".
	var/cached_console_time = 0

/**
 * The cargo console this market files its orders with, or null when it is not aboard a ship.
 *
 * `checkout_list` is per-console rather than per-ship, and complete_arrival() ships the cart
 * belonging to `cargo_shuttle.linked_console` - the console the crew last pressed Send on -
 * so that one is preferred. Falling back to the first console on the hull covers the common
 * case of a ship that has one console and has not called the ferry yet; pressing Send on any
 * console re-points linked_console at itself, so a single-console hull always agrees.
 */
/obj/machinery/materials_market/proc/find_ship_cargo_console()
	var/obj/machinery/computer/voidcrew_cargo/cached = cached_cargo_console?.resolve()
	if(cached && (world.time - cached_console_time) < MARKET_CONSOLE_CACHE_TIME)
		return cached

	var/obj/machinery/computer/voidcrew_cargo/found
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	// Deliberately the raw var, not get_cargo_shuttle(): that one lazily constructs the
	// datum, and a market sitting in a ruin has no business creating one.
	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = ship?.cargo_shuttle
	var/obj/machinery/computer/voidcrew_cargo/dispatcher = cargo_shuttle?.linked_console
	if(!QDELETED(dispatcher))
		found = dispatcher
	else if(ship?.shuttle)
		for(var/area/shuttle_area as anything in ship.shuttle.shuttle_areas)
			for(var/obj/machinery/computer/voidcrew_cargo/candidate in shuttle_area)
				found = candidate
				break
			if(found)
				break

	cached_cargo_console = found ? WEAKREF(found) : null
	cached_console_time = world.time
	return found

/**
 * Why this market cannot file an order right now, as a line to say to the buyer, or null
 * when it can.
 *
 * get_order_list() speaks it at whoever actually clicks buy; ui_data() hands the same string
 * to the interface so the refusal is on screen before they spend the click.
 */
/obj/machinery/materials_market/proc/order_refusal_reason()
	var/obj/machinery/computer/voidcrew_cargo/console = find_ship_cargo_console()
	if(!console)
		// Stock falls back to SSshuttle.shopping_list here. Nothing in this fork ever reads
		// that list, so the order would be taken, confirmed, charged nothing and then lost -
		// the original #255 symptom. There is no cargo network off a hull, so say so.
		if(isnull(get_ship_from_atom(src)))
			return "Error: no cargo network here. This market only works aboard a ship."
		return "Error: no cargo console aboard to file this order with."

	// The cart is the manifest of an in-flight delivery once the ferry has been called -
	// buy() does not charge until it docks, so appending here would grow a shipment that was
	// announced and credit-checked without these sheets. The console refuses its own cart
	// edits for the same reason; match it.
	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = console.get_cargo_shuttle()
	if(cargo_shuttle && cargo_shuttle.state != CARGO_SHUTTLE_AWAY)
		return "Error: the cargo shuttle is already out. Wait for it to return."

	return null

/obj/machinery/materials_market/get_order_list(announce_refusal = FALSE)
	var/refusal = order_refusal_reason()
	if(refusal)
		if(announce_refusal)
			say(refusal)
		return null

	// No refusal means find_ship_cargo_console() resolved a console, and it caches for
	// MARKET_CONSOLE_CACHE_TIME, so this is the same one order_refusal_reason() just checked.
	return find_ship_cargo_console().checkout_list

/// Puts the refusal on screen, so a market that cannot order says so before the click.
/obj/machinery/materials_market/ui_data(mob/user)
	. = ..()
	.["orderRefusal"] = order_refusal_reason()

/obj/machinery/materials_market/can_order_on_budget(obj/item/card/id/id_card)
	if(find_ship_cargo_console())
		return FALSE // the ship's account is the only account here - there is nothing to toggle
	return ..()

/obj/machinery/materials_market/ordering_privately(obj/item/card/id/id_card)
	if(find_ship_cargo_console())
		// Ship-paid, like every other order in that console's cart. Private orders would be
		// billed to the ship by buy() anyway and then arrive as a crate only the buyer's ID
		// opens, which is the worst of both.
		return FALSE
	return ..()

/obj/machinery/materials_market/market_account(obj/item/card/id/id_card, is_ordering_private)
	var/obj/machinery/computer/voidcrew_cargo/console = find_ship_cargo_console()
	if(!console)
		return ..()
	return console.bank_account_holder?.synced_bank_account

#undef MARKET_CONSOLE_CACHE_TIME
