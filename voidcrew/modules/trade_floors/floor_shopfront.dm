/**
 * # Outpost floors: the shopfront
 *
 * Owner: P12 (spec 3b.4, L32-L34, L36). The shop is the player outposts' own (outpost_shop.dm, outpost_shop_stock.dm).
 * Its seams call three base procs on /obj/structure/overmap/dynamic/player_outpost (player_outpost.dm), which answer
 * as before floors: owns_till() (a register that is not the room's own), is_shop_hand() (may stock, serve and open or
 * shut; nothing else) and shop_state_changed() (the shop opened or shut). P12 overrides them on the host here, and
 * owns what an NPC can buy.
 *
 * One stock unit, one sale: every till and shelf sells through the stock unit's own sell(), so a card is charged
 * once, a moved price is refused and a shut shop sells nothing, wherever the buyer stands. An NPC has no card, so
 * npc_buy() pays from the floor's one NPC budget (floor_customers.dm) with the stock unit's own staging.
 */

/datum/outpost_floor
	/// world.time from which the next "is open" call may go out over the concourse speakers (A88)
	var/shop_call_ready_at = 0
	/// The stock unit whose changes this floor passes on to its tills and shelves
	var/datum/weakref/shop_watched
	/// REF(sale point) -> the listing id an NPC was offered there, so the sale is of the thing that was offered
	var/list/shop_npc_picks
	/// The shell map's signs have been looked for (shop_refresh_signs())
	var/shop_plates_found = FALSE
	/// What the signs last showed (shop_signs_state()): checked whenever the shop is busy or a sign is read
	var/shop_signs_shown

// ===== THE SHOP =====

/// The floor's Shop room, installed, or null
/datum/outpost_floor/proc/shop_room()
	var/datum/outpost_upgrade/service/shop/room = host?.service_upgrade("shop")
	return istype(room) ? room : null

/// The Shop room's stock unit, or null
/datum/outpost_floor/proc/shop_stock()
	var/datum/outpost_upgrade/service/shop/room = shop_room()
	return room?.get_stock()

/// Whether this floor has a Shop room, installed and open: it would sell to a visitor now
/datum/outpost_floor/proc/shop_open()
	var/obj/machinery/outpost_shop_stock/stock = shop_stock()
	return !!stock && !stock.closed_reason()

/// What the floor's signs call it
/datum/outpost_floor/proc/shop_sign_name()
	return floor_name || "Floor [number]"

/// What the floor's signs say of its shop: "OPEN", "SHUT", or null with no shop
/datum/outpost_floor/proc/shop_sign_status()
	if(!shop_room())
		return null
	return shop_open() ? "OPEN" : "SHUT"

/// Everything a sign shows, as one string
/datum/outpost_floor/proc/shop_signs_state()
	return "[shop_sign_name()]|[accent]|[shop_sign_status()]"

/// Redraws the signs if what they should show has changed since they were last drawn. Cheap: one string compare.
/datum/outpost_floor/proc/shop_check_signs()
	if(shop_signs_shown != shop_signs_state())
		shop_refresh_signs()

/**
 * Redraws every sign of the floor: the crew's own and the nameplate. Call it when the floor's name, colour or shop
 * changes. The first call also finds the signs the shell map hung before the floor had its ground.
 */
/datum/outpost_floor/proc/shop_refresh_signs()
	shop_signs_shown = shop_signs_state()
	if(!shop_plates_found && length(bounds) >= 5)
		shop_plates_found = TRUE
		for(var/turf/tile as anything in block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5]))
			for(var/obj/structure/sign/outpost_floor/hung in tile)
				if(!shop_fittings_has(hung))
					LAZYOR(shop_plates, WEAKREF(hung))
	for(var/obj/structure/sign/outpost_floor/hung as anything in shop_fittings_of(OUTPOST_FLOOR_FITTING_SIGN))
		hung.refresh()
	for(var/datum/weakref/plate_ref as anything in shop_plates)
		var/obj/structure/sign/outpost_floor/plate = plate_ref.resolve()
		if(plate)
			plate.refresh()
		else
			LAZYREMOVE(shop_plates, plate_ref)

/**
 * The stock unit tells its own window and its room's register when the stock changes, and nobody else. The floor
 * listens to it for the tills and shelves: anything going in or out, and every action in the stock window.
 */
/datum/outpost_floor/proc/shop_watch_stock()
	var/obj/machinery/outpost_shop_stock/stock = shop_stock()
	var/obj/machinery/outpost_shop_stock/watched = shop_watched?.resolve()
	if(stock == watched)
		return
	if(watched)
		UnregisterSignal(watched, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_UI_ACT))
	shop_watched = null
	if(!stock)
		return
	RegisterSignals(stock, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED, COMSIG_UI_ACT), PROC_REF(shop_stock_changed))
	shop_watched = WEAKREF(stock)

/// Batched like the stock unit's own push, and a little after it: a stock window action has run by then
/datum/outpost_floor/proc/shop_stock_changed(datum/source)
	SIGNAL_HANDLER
	addtimer(CALLBACK(src, PROC_REF(shop_flush)), 1 SECONDS, TIMER_UNIQUE)

/// Every till window and every shelf shows the stock as it is now
/datum/outpost_floor/proc/shop_flush()
	for(var/obj/machinery/computer/outpost_shop_register/floor_till/till as anything in shop_fittings_of(OUTPOST_FLOOR_FITTING_TILL))
		SStgui.update_uis(till)
	for(var/obj/structure/outpost_floor_shelf/shelf as anything in shop_fittings_of(OUTPOST_FLOOR_FITTING_SHELF))
		shelf.update_appearance()
	// A new name, a new colour or a Shop room placed since the signs were drawn
	shop_check_signs()

/// Marks the sale the stock unit has just written down with where it was made and whether an NPC bought (the ledger)
/datum/outpost_floor/proc/shop_note_sale(obj/machinery/outpost_shop_stock/stock, where, npc = FALSE)
	var/list/sales_log = stock?.sales_log
	if(!length(sales_log))
		return
	var/list/entry = sales_log[length(sales_log)]
	entry["where"] = where
	entry["npc"] = !!npc

/**
 * "[name], floor [n], is open." over the concourse speakers: an Open floor whose shop is open, once in
 * OUTPOST_FLOOR_OPEN_CALL_EVERY by a stored time, so flipping the shop open and shut fills nobody's chat (A88).
 * It says the floor's cleaned name and its number and nothing else. TRUE when the call went out.
 */
/datum/outpost_floor/proc/shop_opening_call()
	if(entry_policy != OUTPOST_FLOOR_ENTRY_OPEN || world.time < shop_call_ready_at || !outpost || !shop_open())
		return FALSE
	shop_call_ready_at = world.time + OUTPOST_FLOOR_OPEN_CALL_EVERY
	// The floor's name is cleaned where it is typed (set_name(), reject_bad_text()): it holds no markup
	var/call_line = span_notice("The speakers chime: \"[shop_sign_name()], floor [number], is open.\"")
	for(var/mob/listener as anything in GLOB.player_list)
		var/turf/where = get_turf(listener)
		// The outpost's own ground, downstairs: not this floor or any other
		if(!where || get_outpost_floor_for_turf(where) || get_trader_outpost_for_turf(where) != outpost)
			continue
		to_chat(listener, call_line)
		listener.playsound_local(where, 'sound/machines/ding.ogg', 20, FALSE)
	return TRUE

// ===== THE HOST'S ANSWERS TO THE SHOP =====

/// A till of this floor sells from its Shop room's stock
/obj/structure/overmap/dynamic/player_outpost/floor/owns_till(obj/machinery/computer/outpost_shop_register/register)
	return istype(register, /obj/machinery/computer/outpost_shop_register/floor_till) && !!floor?.contains_turf(get_turf(register))

/// A hired hand, in their own body, on a floor that has an owner. They stock, serve, open and shut, and pass
/// Staff doors; the shop's own code gives a stocker nothing else (no price, no eject, no free stock: A80).
/obj/structure/overmap/dynamic/player_outpost/floor/is_shop_hand(mob/user)
	var/mob/living/hand = user
	if(!floor || !founder_ckey || !istype(hand) || !hand.mind || hand.mind.current != hand)
		return FALSE
	return floor.is_hand(hand) || (hand.mind in floor.hands)

/// The shop opened or shut: the signs, the tills, and on opening the call downstairs. Never the lift or the law (L34).
/obj/structure/overmap/dynamic/player_outpost/floor/shop_state_changed(datum/outpost_upgrade/service/shop/shop, mob/user)
	if(!floor)
		return
	floor.shop_watch_stock()
	floor.shop_refresh_signs()
	floor.shop_flush()
	if(shop?.is_open)
		floor.shop_opening_call()

// ===== NPC CUSTOM (for floor_customers.dm) =====

/// Whether an NPC could buy one of `listing` now: for sale, in stock and no dearer than OUTPOST_FLOOR_NPC_ITEM_MAX
/datum/outpost_floor/proc/shop_npc_buyable(datum/outpost_shop_listing/listing)
	return !QDELETED(listing) && listing.price > 0 && listing.price <= OUTPOST_FLOOR_NPC_ITEM_MAX && listing.unit_count() > 0

/// Where a sale at `point` is written down as made
/datum/outpost_floor/proc/shop_point_kind(atom/point)
	if(istype(point, /obj/structure/outpost_floor_shelf))
		return OUTPOST_FLOOR_FITTING_SHELF
	if(istype(point, /obj/machinery/computer/outpost_shop_register/floor_till))
		return OUTPOST_FLOOR_FITTING_TILL
	return OUTPOST_FLOOR_SALE_REGISTER

/**
 * The listing an NPC would buy at `point`, or null. A shelf sells the one thing on it. A register or till sells
 * anything cheap enough, and keeps to what it last offered there while that is still to be had.
 */
/datum/outpost_floor/proc/shop_npc_listing(atom/point)
	var/obj/machinery/outpost_shop_stock/stock = shop_stock()
	if(QDELETED(point) || !stock || stock.closed_reason() || !contains_turf(get_turf(point)))
		return null
	if(istype(point, /obj/structure/outpost_floor_shelf))
		var/obj/structure/outpost_floor_shelf/shelf = point
		var/datum/outpost_shop_listing/on_show = shelf.shown_listing()
		return shop_npc_buyable(on_show) ? on_show : null
	var/obj/machinery/computer/outpost_shop_register/register = point
	if(!istype(register) || register.get_stock() != stock)
		return null
	var/point_ref = REF(point)
	var/picked_id = LAZYACCESS(shop_npc_picks, point_ref)
	var/datum/outpost_shop_listing/picked = picked_id ? stock.listings_by_id[picked_id] : null
	if(shop_npc_buyable(picked))
		return picked
	LAZYREMOVE(shop_npc_picks, point_ref)
	var/list/datum/outpost_shop_listing/choices = list()
	for(var/id in stock.listings_by_id)
		var/datum/outpost_shop_listing/listing = stock.listings_by_id[id]
		if(shop_npc_buyable(listing))
			choices += listing
	if(!length(choices))
		return null
	picked = pick(choices)
	// One entry a sale point at most, and a floor has twenty-one of them
	LAZYSET(shop_npc_picks, point_ref, picked.id)
	return picked

/// The places an NPC could buy at now: the register, tills and shelves with something an NPC would buy. Whether a
/// customer can walk to one is the customer's to find out (floor_customers.dm).
/datum/outpost_floor/proc/npc_sale_points()
	. = list()
	if(!shop_open())
		return
	var/datum/outpost_upgrade/service/shop/room = shop_room()
	var/list/points = list()
	var/obj/machinery/computer/outpost_shop_register/counter = room.register_ref?.resolve()
	if(!QDELETED(counter))
		points += counter
	points += shop_fittings_of(OUTPOST_FLOOR_FITTING_TILL)
	points += shop_fittings_of(OUTPOST_FLOOR_FITTING_SHELF)
	for(var/atom/point as anything in points)
		if(shop_npc_listing(point))
			. += point

/// What an NPC would buy at `point`: list("name" = , "price" = , "consumable" = TRUE/FALSE), or null for nothing.
/// Only a listing priced at or under OUTPOST_FLOOR_NPC_ITEM_MAX.
/datum/outpost_floor/proc/npc_offer(atom/point)
	var/datum/outpost_shop_listing/listing = shop_npc_listing(point)
	if(!listing)
		return null
	var/obj/item/unit = listing.next_unit()
	// Food, or a drink in a glass, a bottle or a can
	var/consumable = !!unit && (IS_EDIBLE(unit) || istype(unit, /obj/item/reagent_containers/cup/glass) || istype(unit, /obj/item/reagent_containers/cup/soda_cans))
	return list("name" = listing.name, "price" = listing.price, "consumable" = consumable)

/**
 * `npc` buys one thing at `point`: the budget pays (npc_budget_spend(), P11), the treasury is credited, the stock
 * really goes and the item is handed over. Returns the item, or null when nothing was sold. Never sleeps.
 *
 * The goods are staged out of the stock unit first and put back if the budget says no, as a card sale does when the
 * payment fails. The budget is the only purse: a sale it does not cover does not happen (A64, A76).
 */
/datum/outpost_floor/proc/npc_buy(mob/living/npc, atom/point)
	if(!isliving(npc) || npc.stat == DEAD || QDELETED(point) || !host || !npc.Adjacent(point))
		return null
	var/datum/outpost_shop_listing/listing = shop_npc_listing(point)
	if(!listing)
		return null
	var/obj/machinery/outpost_shop_stock/stock = shop_stock()
	var/price = listing.price
	var/listing_name = listing.name
	if(npc_budget_left() < price)
		return null
	var/list/goods = stock.stage_units(listing, 1)
	if(!length(goods))
		return null
	if(!npc_budget_spend(price))
		stock.restore_units(goods, listing)
		return null
	LAZYREMOVE(shop_npc_picks, REF(point))
	// Booked as a card sale is (take_payment()), less the same fee
	var/fee = round(price * OUTPOST_SHOP_SALE_FEE_PCT / 100)
	if(price - fee > 0)
		host.receive_payment(price - fee, OUTPOST_SERVICE_SHOP, "Shop: 1x [listing_name]", npc.real_name, "cash")
	var/obj/item/good = goods[1]
	for(var/obj/item/part as anything in good.get_all_contents_type(/obj/item))
		sever_magic_recall(part)
	if(!npc.put_in_hands(good))
		good.forceMove(npc.drop_location())
	stock.record_sale(npc, listing_name, 1, price, FALSE)
	shop_note_sale(stock, shop_point_kind(point), TRUE)
	log_game("OUTPOST FLOOR: [npc] bought 1x [listing_name] for [price] cr at [point] on floor [number] of '[outpost?.name]'")
	stock.mark_dirty()
	return good
