/**
 * # Outpost floors: letting, buying and the one-a-crew rule
 *
 * Owner: P1 (spec 2). A floor is sold over the trader's counter as /datum/shop_sku/outpost_floor. The order of a
 * sale (A29): the vacancy and the one-a-crew rule are checked, the floor is marked as being let, the buyer is
 * charged, the ground is reserved, the shell is loaded and linked. If the last three fail the buyer gets back
 * exactly what was paid and the floor is for sale again.
 */

/// Makes this outpost's `floor_count` floor datums, none with ground yet. Once: a floor deleted later stays gone.
/obj/structure/overmap/trader_outpost/proc/make_floors()
	if(QDELETED(src) || length(floors) >= floor_count)
		return
	floors.len = floor_count
	for(var/number in 1 to floor_count)
		if(!floors[number])
			floors[number] = new /datum/outpost_floor(src, number)
	name_tenants() // floor_life.dm: each unlet floor's tenant business

/// The lowest-numbered floor that can be sold now, or null. A floor its owner gave up is taken in person, not sold.
/obj/structure/overmap/trader_outpost/proc/floor_to_let()
	make_floors()
	for(var/datum/outpost_floor/floor in floors)
		if(floor.state == OUTPOST_FLOOR_STATE_TENANT)
			return floor
	return null

/// How many floors this outpost has left to sell
/obj/structure/overmap/trader_outpost/proc/count_floors_to_let()
	make_floors()
	. = 0
	for(var/datum/outpost_floor/floor in floors)
		if(floor.state == OUTPOST_FLOOR_STATE_TENANT)
			.++

/**
 * Why `buyer` cannot hold another floor, as text for the counter, or null when they can (A24): they, or someone
 * on a ship crew with them, hold OUTPOST_FLOORS_PER_CREW already or are buying one this moment. A claimed
 * derelict is not a floor and does not count. The same test runs on buying, claiming, being given a floor and
 * taking over a lease; `except` is the floor changing hands, which is not counted against the one taking it.
 */
/proc/floor_holder_denial(mob/buyer, datum/outpost_floor/except)
	if(!buyer)
		return null
	var/held = 0
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		for(var/datum/outpost_floor/floor in outpost.floors)
			if(floor != except && floor.held_by_crew_of(buyer))
				held++
	return held >= OUTPOST_FLOORS_PER_CREW ? "You already hold a floor." : null

/**
 * Lets this floor to `buyer`: makes its host, reserves its ground, loads its shell and links it. The floor must
 * already be marked OUTPOST_FLOOR_STATE_LETTING by whoever took the money. TRUE when the floor is the buyer's.
 * FALSE leaves it unlet, with no ground and no host; the caller refunds. Yields.
 */
/datum/outpost_floor/proc/let_to(mob/living/buyer)
	if(state != OUTPOST_FLOOR_STATE_LETTING || reservation || host || QDELETED(outpost) || !isliving(buyer))
		return FALSE
	var/datum/map_template/outpost_floor/shell_path = pick_shell_type()
	var/map_file = initial(shell_path.mappath)
	var/datum/map_template/outpost_floor/shell
	// A map that is not there needs no try round it: it never becomes a template
	if(!map_file || fexists(map_file))
		shell = new shell_path
	else
		log_mapping("OUTPOST FLOORS: no shell map at '[map_file]' for floor [number] of '[outpost]'.")
	var/obj/structure/overmap/dynamic/player_outpost/floor/new_host = new(null)
	host = new_host
	new_host.floor = src
	floor_name = default_name(buyer)
	var/let = shell && new_host.found(buyer, shell, floor_name)
	if(shell)
		qdel(shell)
	if(!let || QDELETED(src) || QDELETED(new_host) || host != new_host)
		// The host takes the ground and the lease with it (host_lost())
		if(!QDELETED(new_host))
			qdel(new_host)
		return FALSE
	state = OUTPOST_FLOOR_STATE_OWNED
	shell_lessee = null
	outpost.refresh_elevator_uis()
	on_let(buyer)
	record_floor_metric("floor_bought", src, buyer, OUTPOST_FLOOR_COST_CREDITS)
	return TRUE

// ===== THE LEASE ON THE SHELF =====

/**
 * The lease on the trader's Colonial Registry shelf. It has no item: dispense() runs the letting.
 * Its stock is the floors the outpost still has to let, counted live, and no convoy brings more.
 * P9 lists it in the three catalogues.
 */
/datum/shop_sku/outpost_floor
	name = "floor lease"
	desc = "A floor of your own, upstairs."
	category = "Colonial Registry"
	price_credits = OUTPOST_FLOOR_COST_CREDITS
	price_vouchers = OUTPOST_FLOOR_COST_VOUCHERS
	fixed_price = TRUE
	contract_reward = FALSE
	stock_min = 1
	stock_max = 1
	restock_interval = INFINITY
	icon_override = 'voidcrew/modules/player_outposts/icons/outpost.dmi'
	icon_state_override = "outpost_deed"
	/// The floor marked for the sale now running: set by try_purchase(), taken by dispense(), with no yield between
	var/datum/outpost_floor/letting

/datum/shop_sku/outpost_floor/Destroy()
	letting = null
	return ..()

/// Sets the shelf's count to the floors this outpost still has to let, and returns it
/datum/shop_sku/outpost_floor/proc/sync_stock()
	var/obj/structure/overmap/trader_outpost/outpost = shop?.outpost
	stock = QDELETED(outpost) ? 0 : outpost.count_floors_to_let()
	return stock

/// The storefront asks this for every viewer before it reads the stock, which keeps the count live
/datum/shop_sku/outpost_floor/get_denial_reason(mob/living/user)
	if(sync_stock() <= 0)
		return "No vacancies."
	var/holder_denial = floor_holder_denial(user)
	if(holder_denial)
		return holder_denial
	return ..()

/**
 * Marks the floor before the charge and before anything yields (A29): a second buyer finds one floor fewer, and
 * the buyer's own crew already counts as holding one (A24). The charge and the stock are the shelf's own; the
 * letting is dispense(). TRUE only when the floor is the buyer's.
 */
/datum/shop_sku/outpost_floor/try_purchase(mob/living/user, mob/living/carbon/human/npc/ambient_npc/outpost/trader/vendor)
	var/obj/structure/overmap/trader_outpost/outpost = shop?.outpost
	if(QDELETED(outpost) || !isliving(user) || !user.mind || !user.ckey)
		return FALSE
	if(sync_stock() <= 0 || floor_holder_denial(user))
		return FALSE
	var/datum/outpost_floor/floor = outpost.floor_to_let()
	if(!floor)
		return FALSE
	floor.state = OUTPOST_FLOOR_STATE_LETTING
	floor.shell_lessee = WEAKREF(user.mind)
	letting = floor
	. = ..()
	if(letting == floor)
		// Refused before dispense(): nothing was charged, and the floor goes back on the list
		letting = null
		if(!QDELETED(floor) && floor.state == OUTPOST_FLOOR_STATE_LETTING)
			floor.reset_lease()
	sync_stock()
	return . && !QDELETED(floor) && floor.state == OUTPOST_FLOOR_STATE_OWNED

/// The letting itself. The buyer has been charged a moment ago, with no yield since; a floor that cannot be let pays them back exactly.
/datum/shop_sku/outpost_floor/dispense(mob/living/user, mob/living/carbon/human/npc/ambient_npc/outpost/trader/vendor)
	var/datum/outpost_floor/floor = letting
	letting = null
	// Only try_purchase() marks a floor, and only it charges: with none marked nothing was paid
	if(!floor)
		return null
	// What was paid, and from where, kept for a refund: the letting yields and the buyer may change crews meanwhile
	var/obj/structure/overmap/ship/crew_ship = get_crew_ship(user)
	var/datum/bank_account/paid_from = get_account(user, crew_ship)
	var/paid_credits = get_credit_price(user, crew_ship)
	var/paid_vouchers = price_vouchers
	if(floor.let_to(user))
		vendor?.speak_line(TRADER_LINE_SALE, "Floor [convert_integer_to_words(floor.number)]'s yours. Lift's by the gate.")
		print_slip(floor, user)
		return null
	if(paid_credits > 0)
		paid_from?.adjust_money(paid_credits, "Trader Outpost: [name] refund")
	if(paid_vouchers > 0)
		var/atom/hand_back_at = (!QDELETED(user) && user.drop_location()) || vendor?.drop_location()
		if(hand_back_at)
			var/obj/item/stack/trade_voucher/handed_back = new(hand_back_at, paid_vouchers, FALSE)
			if(!QDELETED(user))
				user.put_in_hands(handed_back)
		else
			log_game("OUTPOST FLOORS: [paid_vouchers] voucher\s owed to [key_name(user)] for a floor that could not be let had nowhere to go.")
	if(vendor)
		vendor.speak_line(TRADER_LINE_REFUSAL, "Registry won't take it. Here, have it back.")
	else if(!QDELETED(user))
		to_chat(user, span_warning("The lease does not go through. You are paid back."))
	log_game("OUTPOST FLOORS: a floor at '[shop?.outpost]' could not be let to [key_name(user)]; [paid_credits] cr and [paid_vouchers] voucher\s refunded.")
	return null

/// The lease slip the buyer walks away with
/datum/shop_sku/outpost_floor/proc/print_slip(datum/outpost_floor/floor, mob/living/holder)
	if(QDELETED(holder) || QDELETED(floor) || QDELETED(floor.outpost))
		return
	var/obj/item/paper/slip = new(holder.drop_location())
	slip.name = "floor lease"
	slip.add_raw_text("LEASE. Floor [floor.number], [html_encode(floor.outpost.name)]. Holder: [html_encode(holder.real_name)].")
	slip.update_appearance()
	holder.put_in_hands(slip)
