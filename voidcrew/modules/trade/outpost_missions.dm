/**
 * # Outpost Supply Contracts
 *
 * The shop-specific mission loop: each trader outpost posts a couple of
 * supply requests ("bring me X"), and the pay is a FREE ITEM off the shop's
 * own shelves rather than credits. Gives a ship a reason to detour to an
 * outpost even with empty pockets.
 *
 * The player-facing side is the trader NPC's Contracts radial (see
 * trader_npc.dm). Wiring rides the existing mission pipeline end to end:
 * accepting at the trader puts the mission in the ship's active list, and
 * turn-in happens at the trader or back at the ship's own mission board +
 * pad, where the reward item spawns exactly like voucher/item rewards do.
 */

/// How many contracts an outpost keeps posted at once
#define OUTPOST_SHOP_OFFER_COUNT 4

/**
 * # Outpost Supply Mission
 *
 * Delivery-style: haul the asked goods to your ship's mission pad or any
 * trader. Pays no credits. The reward is one free item rolled off the
 * posting shop's SKU list at creation time.
 */
/datum/mission/outpost_supply
	name = "Supply Request"
	weight = 0 // never rolled by the mission subsystem; outposts post these themselves
	value_min = 0
	value_max = 0
	duration = 40 MINUTES

	/// The rolled ask
	var/required_type
	var/required_name
	var/required_amount = 1

/datum/mission/outpost_supply/get_archetype()
	return "procurement"

/datum/mission/outpost_supply/generate_details()
	if(!shop)
		generation_failed = TRUE
		return
	author = shop.trader_name

	pick_request()
	if(generation_failed)
		return

	// The pay: kit off the shelf, assembled to the difficulty band and floored
	// by what the ask itself fetches at this trader's own buyback window. A
	// contract for five glacial cores has to beat carrying those same cores
	// twenty steps to the counter, or there is no reason to take it.
	voucher_count = 0
	if(!shop.roll_contract_reward(src, shop.get_counter_value(required_type, required_amount)))
		generation_failed = TRUE

/// Rolls the ask off the shop's request table. Override for themed asks.
/datum/mission/outpost_supply/proc/pick_request()
	var/list/request = length(shop.mission_requests) ? pick(shop.mission_requests) : null
	if(!request)
		generation_failed = TRUE
		return
	required_type = request["type"]
	required_name = request["name"]
	required_amount = request["amount"] || 1
	difficulty = request["difficulty"] || MISSION_DIFFICULTY_MEDIUM

/datum/mission/outpost_supply/build_objectives()
	var/datum/mission_objective/deliver/ask = new
	ask.required_type = required_type
	ask.required_name = required_name
	ask.required_amount = required_amount
	add_objective(ask)

/datum/mission/outpost_supply/update_text()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	name = "Supply Request: [item_text]"
	desc = "[author] is paying in kit: deliver [item_text] to your ship's mission pad or any outpost trader. \
		Pays [get_contract_pay_summary()], straight off the shelf."

/**
 * # Angler's Request
 *
 * "Pike at the general outpost wants three unusual fish. Yes, really.
 * Bring a rod."
 *
 * A fish-shaped supply request posted only by outposts that actually run a
 * fishing stall (see the shop's extra_offer_mix). Same goods-for-goods deal;
 * trophy asks reach the exclusive shelf like any hard contract.
 */
/datum/mission/outpost_supply/angler
	/// Trophy gate in grams (0 = any fish)
	var/min_fish_weight = 0

/datum/mission/outpost_supply/angler/get_archetype()
	return "angling"

/datum/mission/outpost_supply/angler/pick_request()
	var/static/list/fish_asks = list(
		list("name" = "fresh fish", "amount" = 2, "min_weight" = 0, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("name" = "fresh fish", "amount" = 3, "min_weight" = 0, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("name" = "a keeper over 1.5 kg", "amount" = 1, "min_weight" = 1500, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("name" = "keepers over 1.5 kg", "amount" = 2, "min_weight" = 1500, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("name" = "a trophy catch over 2.5 kg", "amount" = 1, "min_weight" = 2500, "difficulty" = MISSION_DIFFICULTY_HARD),
	)
	var/list/ask = pick(fish_asks)
	required_type = /obj/item/fish
	required_name = ask["name"]
	required_amount = ask["amount"]
	difficulty = ask["difficulty"]
	min_fish_weight = ask["min_weight"]

/datum/mission/outpost_supply/angler/build_objectives()
	var/datum/mission_objective/deliver/fish/ask = new
	ask.required_name = required_name
	ask.required_amount = required_amount
	ask.min_weight = min_fish_weight
	add_objective(ask)

/datum/mission/outpost_supply/angler/update_text()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	name = "Angler's Request: [item_text]"
	desc = "[author] wants [item_text], line-caught and fresh. Bring a rod. \
		Hand the catch to any outpost trader or your own mission pad. Pays [get_contract_pay_summary()], off the shelf."

/**
 * # Kitchen Order
 *
 * "Roux at the diner is short-handed and the counter case is empty. Cook."
 *
 * A cooking-shaped supply request posted only by outposts that run a kitchen
 * stall (see the general shop's extra_offer_mix). The ask is real cooking:
 * dishes only count when a player's own hands made them (TRAIT_HANDMADE
 * from a grill, oven, fryer or the crafting menu) at the ordered recipe depth —
 * factory food is refused, and so are plates bought off the diner's own
 * counter (see deliver/cooked and TRAIT_SOURCE_OUTPOST_KITCHEN).
 */
/datum/mission/outpost_supply/cook
	/// Minimum crafting_complexity (FOOD_COMPLEXITY_*) for a dish to count
	var/min_complexity = FOOD_COMPLEXITY_2

/datum/mission/outpost_supply/cook/get_archetype()
	return "cooking"

/datum/mission/outpost_supply/cook/generate_details()
	..()
	if(generation_failed)
		return
	// Barnaby hosts the board, but the order sheet is signed by the cook next door
	var/datum/outpost_shop/vendor/diner/stall_type = /datum/outpost_shop/vendor/diner
	author = initial(stall_type.trader_name)

/datum/mission/outpost_supply/cook/pick_request()
	var/static/list/cook_asks = list(
		list("name" = "hot meals for the counter", "amount" = 2, "min_complexity" = FOOD_COMPLEXITY_2, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("name" = "hot meals for the counter", "amount" = 3, "min_complexity" = FOOD_COMPLEXITY_2, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("name" = "proper dinners for the evening rush", "amount" = 2, "min_complexity" = FOOD_COMPLEXITY_3, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("name" = "proper dinners for the evening rush", "amount" = 3, "min_complexity" = FOOD_COMPLEXITY_3, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("name" = "a showstopper dish for the window case", "amount" = 1, "min_complexity" = FOOD_COMPLEXITY_4, "difficulty" = MISSION_DIFFICULTY_HARD),
	)
	var/list/ask = pick(cook_asks)
	required_type = /obj/item/food
	required_name = ask["name"]
	required_amount = ask["amount"]
	difficulty = ask["difficulty"]
	min_complexity = ask["min_complexity"]

/datum/mission/outpost_supply/cook/build_objectives()
	var/datum/mission_objective/deliver/cooked/ask = new
	ask.required_name = required_name
	ask.required_amount = required_amount
	ask.min_complexity = min_complexity
	add_objective(ask)

/datum/mission/outpost_supply/cook/update_text()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	name = "Kitchen Order: [item_text]"
	desc = "[author] at the diner is buying [item_text], cooked by an actual person, \
		[min_complexity >= FOOD_COMPLEXITY_4 ? "and it had better be worth the window" : "no factory food"]. \
		Hand the plates to any outpost trader or your own mission pad. Pays [get_contract_pay_summary()], off the shelf."

// ===== OFFER MANAGEMENT (lives on the outpost) =====

/**
 * Keeps the outpost's posted contracts topped up with a mixed archetype
 * spread. Procurement stays the bread and butter; the rest is rolled, with
 * the shop's own extra_offer_mix (the general outpost's angling requests)
 * folded in. Discards failed rolls (e.g. courier with no second outpost).
 */
/obj/structure/overmap/trader_outpost/proc/ensure_shop_offers()
	if(!shop)
		return
	var/static/list/offer_mix = list(
		/datum/mission/outpost_supply = 40,
		/datum/mission/recovery/kill/outpost = 25,
		/datum/mission/recovery/outpost = 20,
		/datum/mission/outpost_courier = 15,
	)
	var/list/mix = offer_mix
	if(length(shop.extra_offer_mix))
		mix = offer_mix.Copy()
		for(var/offer_type in shop.extra_offer_mix)
			mix[offer_type] = shop.extra_offer_mix[offer_type]
	// Prune offers that died on the board (e.g. their pinned target vanished
	// before anyone accepted) so they don't hold a slot or count against caps
	for(var/datum/mission/posted as anything in shop_offers.Copy())
		if(QDELETED(posted))
			shop_offers -= posted
	var/safety = 12
	while(length(shop_offers) < OUTPOST_SHOP_OFFER_COUNT && safety-- > 0)
		// Always keep at least one plain supply request on the board
		var/offer_type = /datum/mission/outpost_supply
		if(has_posted_offer_type(/datum/mission/outpost_supply))
			offer_type = pick_weight(mix)
		// Capped types (drug runs) count live missions AND posted offers; the
		// ship-board roll enforces this in SSmissions, boards must match
		if(!mission_type_within_limit(offer_type))
			continue
		var/datum/mission/offer = new offer_type(shop)
		if(offer.generation_failed)
			qdel(offer)
			continue
		shop_offers += offer

/// Whether an offer of the exact given type is currently posted
/obj/structure/overmap/trader_outpost/proc/has_posted_offer_type(offer_type)
	for(var/datum/mission/offer as anything in shop_offers)
		if(offer.type == offer_type)
			return TRUE
	return FALSE

/**
 * Whether another mission of this type may exist right now, per its
 * mission_limit: counts live accepted missions plus every outpost board's
 * unaccepted offers, so a capped contract can't be double-posted (or posted
 * while one is already being run). Limit 0 = uncapped.
 * * excluding - a mission datum that shouldn't count against itself, so the
 *   accept-time check can be run on an offer that is still sitting on a board.
 */
/proc/mission_type_within_limit(mission_type, datum/mission/excluding)
	var/datum/mission/mission_cast = mission_type
	var/limit = initial(mission_cast.mission_limit)
	if(limit <= 0)
		return TRUE
	var/count = 0
	for(var/datum/mission/active as anything in SSmissions.all_active_missions)
		if(active.type == mission_type && active != excluding)
			count++
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		for(var/datum/mission/offer as anything in outpost.shop_offers)
			if(!QDELETED(offer) && offer.type == mission_type && offer != excluding)
				count++
	return count < limit

#undef OUTPOST_SHOP_OFFER_COUNT
