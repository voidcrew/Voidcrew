/**
 * # Outpost Supply Contracts
 *
 * The shop-specific mission loop: each trader outpost posts a couple of
 * supply requests with fixed packages and currency settlements.
 *
 * The player-facing side is the trader NPC's Contracts radial (see
 * trader_npc.dm). Wiring rides the existing mission pipeline end to end:
 * accepting at the trader puts the mission in the ship's active list, and
 * turn-in happens at the trader or back at the ship's own mission board +
 * pad, where the reward item spawns exactly like voucher/item rewards do.
 */

/// Exact request types; fish and bear hides are deliberate owner exceptions.
/proc/is_outpost_procurement_type(item_type)
	var/static/list/eligible_types = list(
		/obj/item/fish,
		/obj/item/stack/sheet/animalhide/bear,
		/obj/item/stack/sheet/animalhide/goliath_hide,
		/obj/item/stack/sheet/sinew,
		/obj/item/stack/spice_pods,
		/obj/item/sea_crystal,
		/obj/item/stack/telecrystal_raw,
		/obj/item/organ/monster_core/regenerative_core/legion,
		/obj/item/stack/glacial_core,
		// Salvaged suit goods; module matching stays exact at handover.
		/obj/item/mod/construction/broken_core,
		/obj/item/mod/control/pre_equipped,
		/obj/item/mod/module/springlock,
		/obj/item/mod/module/visor/rave,
		/obj/item/mod/module/balloon,
		/obj/item/mod/module/stamp,
	)
	return item_type in eligible_types

/// Fail closed on unsupported types or incomplete request rows.
/datum/outpost_shop/proc/get_procurement_requests()
	var/list/eligible_requests = list()
	for(var/list/request as anything in mission_requests)
		if(!islist(request) || !is_outpost_procurement_type(request["type"]))
			continue
		if(!istext(request["name"]) || !length(request["name"]))
			continue
		var/amount = request["amount"]
		if(!isnum(amount) || amount < 1 || amount != round(amount))
			continue
		if(!(request["difficulty"] in list(MISSION_DIFFICULTY_EASY, MISSION_DIFFICULTY_MEDIUM, MISSION_DIFFICULTY_HARD)))
			continue
		if(ispath(request["type"], /obj/item/stack))
			var/obj/item/stack/stack_type = request["type"]
			if(amount > initial(stack_type.max_amount))
				continue
		eligible_requests += list(request)
	return eligible_requests

/// Procurement validates the configured ask again when goods are handed over.
/datum/mission_objective/deliver/procurement

/datum/mission_objective/deliver/procurement/matches_ask(obj/item/item)
	if(QDELETED(item) || !is_outpost_procurement_type(required_type) || !..())
		return FALSE
	if(istype(item, /obj/item/mod/control/pre_equipped))
		var/obj/item/mod/control/pre_equipped/control = item
		return isnull(control.wearer)
	// A loot module's descendants may be manufactured or have different sources.
	if(istype(item, /obj/item/mod/module))
		return item.type == required_type
	return TRUE

/datum/mission_objective/deliver/procurement/can_turn_in(obj/item/item)
	if(completed || !matches_ask(item))
		return FALSE
	return ..()

/datum/mission_objective/deliver/procurement/accept_item(obj/item/item, atom/reward_anchor)
	if(!can_turn_in(item))
		return MISSION_ITEM_REFUSED
	// The parent forgets the quest atom before consuming stacks or loose goods.
	return ..()

/**
 * # Outpost Supply Mission
 *
 * Delivery-style: haul the asked goods to your ship's mission pad or any
 * trader. The package and currency quote are fixed at posting.
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
	/// Optional fixed target band for recovered suit goods.
	var/request_pay_min
	var/request_pay_max

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

	var/datum/outpost_shop/reward_shop = contract_reward_shop || shop
	var/ask_value = reward_shop.get_counter_value(required_type, required_amount)
	if(ispath(required_type, /obj/item/mod/module))
		ask_value = 250 * required_amount // Reference only; never a buyback.
	if(!reward_shop.roll_contract_reward(src, ask_value))
		generation_failed = TRUE

/// Rolls the ask off the shop's request table. Override for themed asks.
/datum/mission/outpost_supply/proc/pick_request()
	var/list/eligible_requests = shop.get_procurement_requests()
	var/list/request = length(eligible_requests) ? pick(eligible_requests) : null
	if(!request)
		generation_failed = TRUE
		return
	required_type = request["type"]
	required_name = request["name"]
	required_amount = request["amount"]
	difficulty = request["difficulty"]
	request_pay_min = request["pay_min"]
	request_pay_max = request["pay_max"]
	if(request["reward_shop"])
		contract_reward_shop = shop.type == request["reward_shop"] ? shop : shop.outpost?.get_shop(request["reward_shop"])
		if(!contract_reward_shop)
			generation_failed = TRUE

/datum/mission/outpost_supply/build_objectives()
	var/datum/mission_objective/deliver/procurement/ask = new
	ask.required_type = required_type
	ask.required_name = required_name
	ask.required_amount = required_amount
	add_objective(ask)

/datum/mission/outpost_supply/update_text()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	name = "Supply Request: [item_text]"
	desc = "[author] wants [item_text]."

/**
 * # Angler's Request
 *
 * "Pike at the general outpost wants three unusual fish. Yes, really.
 * Bring a rod."
 *
 * A fish-shaped supply request posted only by outposts that actually run a
 * fishing stall (see the shop's extra_offer_mix).
 */
/datum/mission/outpost_supply/angler
	/// Trophy gate in grams (0 = any fish)
	var/min_fish_weight = 0

/datum/mission/outpost_supply/angler/get_archetype()
	return "angling"

/datum/mission/outpost_supply/angler/pick_request()
	var/static/list/fish_asks = list(
		list("name" = "fish", "amount" = 2, "min_weight" = 0, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("name" = "fish", "amount" = 3, "min_weight" = 0, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("name" = "a keeper of at least 1.5 kg", "amount" = 1, "min_weight" = 1500, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("name" = "keepers of at least 1.5 kg each", "amount" = 2, "min_weight" = 1500, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("name" = "a trophy catch of at least 2.5 kg", "amount" = 1, "min_weight" = 2500, "difficulty" = MISSION_DIFFICULTY_HARD),
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
	desc = "[author] wants [item_text]."

/**
 * # Kitchen Order
 *
 * "Roux at the diner is short-handed and the counter case is empty. Cook."
 *
 * A cooking-shaped supply request posted only by outposts that run a kitchen
 * stall (see the general shop's extra_offer_mix). The ask is real cooking:
 * dishes only count when a player's own hands made them (TRAIT_FOOD_CHEF_MADE
 * from a grill, oven, fryer or the crafting menu) at the ordered recipe depth.
 * Factory food is refused, and so are plates bought off the diner's own
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
	desc = "[author] at the diner wants [item_text]."

// ===== OFFER MANAGEMENT (lives on the outpost) =====

/**
 * Keeps the outpost's posted contracts topped up with a mixed archetype
 * spread. Procurement stays the bread and butter; the rest is rolled, with
 * the shop's own extra_offer_mix (the general outpost's angling requests)
 * folded in. Discards failed rolls (e.g. courier with no second outpost).
 */
/obj/structure/overmap/trader_outpost/proc/ensure_shop_offers()
	if(!shop || world.time < next_contract_refill)
		return
	// Keep the original cadence if a visit beats a delayed timer callback.
	if(!next_contract_refill)
		next_contract_refill = world.time + OUTPOST_CONTRACT_REFILL_INTERVAL
	else
		next_contract_refill += (floor((world.time - next_contract_refill) / OUTPOST_CONTRACT_REFILL_INTERVAL) + 1) * OUTPOST_CONTRACT_REFILL_INTERVAL
	var/static/list/offer_mix = list(
		/datum/mission/outpost_supply = 40,
		/datum/mission/recovery/kill/outpost = 25,
		/datum/mission/recovery/outpost = 20,
		/datum/mission/outpost_courier = 15,
	)
	var/list/mix = offer_mix.Copy()
	if(length(shop.extra_offer_mix))
		for(var/offer_type in shop.extra_offer_mix)
			mix[offer_type] = shop.extra_offer_mix[offer_type]
	var/has_procurement = length(shop.get_procurement_requests()) > 0
	if(!has_procurement)
		mix -= /datum/mission/outpost_supply
	// Prune offers that died on the board (e.g. their pinned target vanished
	// before anyone accepted) so they don't hold a slot or count against caps
	for(var/datum/mission/posted as anything in shop_offers.Copy())
		if(QDELETED(posted))
			shop_offers -= posted
		else if(posted.failed || posted.completed || world.time - posted.posted_at >= OUTPOST_CONTRACT_EXPIRY)
			shop_offers -= posted
			tally_mission_offer(posted, null, "contract_offer_expired")
			qdel(posted)
	var/safety = 12
	while(length(shop_offers) < OUTPOST_SHOP_OFFER_COUNT && safety-- > 0)
		// Keep a plain supply request on the board only when its pool is eligible.
		var/offer_type = /datum/mission/outpost_supply
		if(!has_procurement || has_posted_offer_type(/datum/mission/outpost_supply))
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
		tally_mission_offer(offer, null, "contract_offered") // round metrics, voidcrew/modules/metrics/mission_metrics.dm

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
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		for(var/datum/mission/offer in ship.available_missions)
			if(!QDELETED(offer) && offer.type == mission_type && offer != excluding)
				count++
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		for(var/datum/mission/offer as anything in outpost.shop_offers)
			if(!QDELETED(offer) && offer.type == mission_type && offer != excluding)
				count++
	return count < limit


// ===== BOARD QUOTES AND SETTLEMENT =====
// Shared shell hooks live here so both trader and ship-pad handovers use them.

/// Filter a view without deleting offers that another crew can still accept.
/obj/structure/overmap/trader_outpost/proc/get_contract_offers_for(obj/structure/overmap/ship/ship)
	var/list/offers = list()
	if(QDELETED(ship))
		return offers
	for(var/datum/mission/offer in shop_offers)
		if(offer.can_accept_work(ship))
			offers += offer
	return offers

/datum/mission
	/// Total value, fixed at posting; null on work outside this reward channel.
	var/contract_quote
	var/contract_no_vouchers = FALSE
	/// May be the fitter while shop remains the outfitter that receives favor.
	var/datum/outpost_shop/contract_reward_shop
	/// Quoted item path -> live core SKU and its fixed value.
	var/list/contract_stock
	var/list/contract_item_values
	var/contract_stock_reserved = FALSE
	var/contract_settled = FALSE
	var/contract_turning_in = FALSE
	/// Shared crew purchase slots held by this package, keyed by quoted item path.
	var/list/contract_purchase_claims = list()

/datum/mission/proc/is_routine_contract()
	if(!istype(src, /datum/mission/outpost_supply))
		return FALSE
	var/datum/mission/outpost_supply/supply = src
	return istype(src, /datum/mission/outpost_supply/cook) || istype(src, /datum/mission/outpost_supply/angler) \
		|| supply.required_type == /obj/item/fish || supply.required_type == /obj/item/stack/sheet/animalhide/bear

/// Set both bounds: the shell rolls value after generate_details().
/datum/mission/proc/set_contract_currency(remainder)
	voucher_count = contract_no_vouchers ? 0 : floor(remainder / VOUCHER_CREDIT_VALUE)
	value = remainder - voucher_count * VOUCHER_CREDIT_VALUE
	value_min = value
	value_max = value

/// Admission and caps use the same record as the accepted receipt, never a helper's crew.
/datum/mission/proc/contract_line_allowed(datum/shop_sku/sku, datum/voidcrew_crew_record/record, reserved = FALSE)
	if(QDELETED(record))
		record = null
	if(QDELETED(sku) || (!reserved && sku.stock <= 0))
		return FALSE
	if(!isnum(sku.zone_permission) || sku.zone_permission < ZONE_PERMISSION_PUBLIC \
		|| (record ? !record.has_zone_permission(sku.zone_permission) : sku.zone_permission != ZONE_PERMISSION_PUBLIC))
		return FALSE
	if(!reserved && sku.crew_limit > 0 && (!record || (record.favor_unique_purchases[sku.type] || 0) >= sku.crew_limit))
		return FALSE
	return TRUE

/// Pure viewer projection: it cannot reserve stock or rewrite the shared quote.
/datum/mission/proc/get_effective_contract_package(datum/voidcrew_crew_record/record)
	if(isnull(contract_quote))
		return null
	var/list/items = list()
	var/package_value = 0
	for(var/item_path in contract_stock)
		var/datum/shop_sku/sku = contract_stock[item_path]
		if(!contract_line_allowed(sku, record, contract_stock_reserved))
			continue
		items += item_path
		package_value += contract_item_values[item_path]
	var/remainder = contract_quote - package_value
	var/vouchers = contract_no_vouchers ? 0 : floor(remainder / VOUCHER_CREDIT_VALUE)
	return list("items" = items, "item_value" = package_value, "vouchers" = vouchers, "credits" = remainder - vouchers * VOUCHER_CREDIT_VALUE)

/// Return one held line and its purchase slot to the original crew.
/datum/mission/proc/drop_contract_line(item_path)
	var/datum/shop_sku/sku = contract_stock[item_path]
	if(contract_stock_reserved && !QDELETED(sku))
		sku.reserved_stock--
		sku.stock++
	var/purchase_type = contract_purchase_claims[item_path]
	if(purchase_type)
		accepting_crew?.release_purchase(purchase_type)
		contract_purchase_claims -= item_path
	contract_stock -= item_path
	mission_rewards -= item_path
	reward_amounts -= item_path

/// Live permission loss converts held goods to their exact quoted currency value.
/datum/mission/proc/revalidate_contract_package()
	if(isnull(contract_quote) || !contract_stock_reserved || contract_settled)
		return
	var/package_value = 0
	for(var/item_path in contract_stock.Copy())
		if(!contract_line_allowed(contract_stock[item_path], accepting_crew, TRUE))
			drop_contract_line(item_path)
			continue
		package_value += contract_item_values[item_path]
	metric_item_value = package_value
	set_contract_currency(contract_quote - package_value)

/// No yields between checking and claiming stock. Lost shelf objects become currency.
/datum/mission/proc/reserve_contract_stock()
	if(isnull(contract_quote) || contract_stock_reserved || contract_settled)
		return
	contract_stock_reserved = TRUE
	var/package_value = 0
	for(var/item_path in contract_stock.Copy())
		var/datum/shop_sku/sku = contract_stock[item_path]
		if(!contract_line_allowed(sku, accepting_crew))
			contract_stock -= item_path
			mission_rewards -= item_path
			reward_amounts -= item_path
			continue
		if(sku.crew_limit > 0)
			if(!accepting_crew.claim_purchase(sku.type, sku.crew_limit))
				contract_stock -= item_path
				mission_rewards -= item_path
				reward_amounts -= item_path
				continue
			contract_purchase_claims[item_path] = sku.type
		sku.stock--
		sku.reserved_stock++
		package_value += contract_item_values[item_path]
	metric_item_value = package_value
	set_contract_currency(contract_quote - package_value)

/// Completion consumes the hold; every other deletion releases it, once.
/datum/mission/proc/release_contract_stock(consumed = FALSE)
	if(!contract_stock_reserved)
		return
	contract_stock_reserved = FALSE
	if(!consumed)
		for(var/item_path in contract_purchase_claims)
			accepting_crew?.release_purchase(contract_purchase_claims[item_path])
	contract_purchase_claims.Cut()
	for(var/item_path in contract_stock)
		var/datum/shop_sku/sku = contract_stock[item_path]
		if(QDELETED(sku))
			continue
		sku.reserved_stock--
		if(!consumed)
			sku.stock++

/datum/mission/start_mission(obj/structure/overmap/ship/ship)
	if(shop || !isnull(contract_quote))
		if(QDELETED(src) || active || failed || completed || QDELETED(ship) || QDELETED(ship.ship_account))
			return FALSE
		if(!can_accept_work(ship))
			return FALSE
		accepting_crew = ship.get_crew_record()
		reserve_contract_stock()
	. = ..()
	if(!. && !QDELETED(src))
		release_contract_stock()

/datum/mission/turn_in(atom/reward_anchor, obj/item/turned_in_item, force = FALSE)
	if(shop || !isnull(contract_quote))
		if(QDELETED(src) || !active || failed || completed || contract_turning_in || QDELETED(servant) || QDELETED(servant.ship_account))
			return FALSE
		if(!get_turf(reward_anchor) || !can_turn_in_at(reward_anchor))
			return FALSE
		contract_turning_in = TRUE
	. = ..()
	contract_turning_in = FALSE

/datum/mission/distribute_rewards(atom/reward_anchor)
	if(!isnull(contract_quote))
		if(contract_settled)
			return
		revalidate_contract_package()
		contract_settled = TRUE
		release_contract_stock(consumed = TRUE)
	return ..()

/datum/mission/Destroy()
	shop?.outpost?.shop_offers -= src
	release_contract_stock()
	contract_reward_shop = null
	contract_stock = null
	contract_item_values = null
	contract_purchase_claims = null
	return ..()

/datum/mission/get_contract_pay_summary()
	var/list/parts = list()
	if(length(get_reward_types()))
		parts += get_reward_summary()
	if(voucher_count > 0)
		parts += "[voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]"
	if(value > 0)
		parts += "[value] cr"
	return parts.Join(" + ")

/// The fixed package may come from the fitter rather than the posting counter.
/datum/mission/note_metric_item_value()
	if(!isnull(contract_quote))
		return // roll_contract_reward and acceptance track the actual reserved package.
	return ..()

/datum/mission/finish_mission(atom/reward_anchor)
	if((shop || !isnull(contract_quote)) && (QDELETED(src) || !active || failed || completed || QDELETED(servant) || QDELETED(servant.ship_account) || !get_turf(reward_anchor)))
		return
	return ..()

/datum/mission/get_reward_summary()
	if(shop && !length(get_reward_types()))
		return ""
	return ..()
