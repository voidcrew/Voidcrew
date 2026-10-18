/**
 * # Outpost Shops
 *
 * One /datum/outpost_shop instance per trader outpost, holding the per-round
 * shared stock its trader NPC sells from. SKUs have fixed,
 * simple prices: vouchers and/or credits, or an item barter, never a mixed
 * freeform payment UI.
 *
 * Stock is built from three shelves:
 * - CORE: the sku_types list, stocked every round.
 * - ROTATING: a few picks rolled from rotating_pool each round, limited supply.
 * - RARE: 1-2 showcase picks rolled from rare_pool, single unit each.
 * - Weighted rotations (/datum/shop_rotation): small dedicated shelves with a
 *   weighted pool of their own. Every sold-out slot swaps for a different pick
 *   on convoy restock, so scarce goods never refill in place.
 * One credit-priced SKU per round also goes on special (discount_pct).
 *
 * Vouchers are deliberately the only road to the best stock ("the currency
 * that can't be farmed safely"); credits cover the mundane shelf.
 *
 * The per-shop catalogs (SKU/buyback/line definitions) live in the
 * shop_catalog_*.dm files; this file is the machinery.
 */

/**
 * The fallback look for a shop that never set trader_outfit, a nondescript
 * independent merchant. Every shipped shop names its own outfit next to its
 * catalog; this only exists so a new one that forgets doesn't inherit somebody
 * else's character.
 */
/datum/outfit/outpost_trader_generic
	name = "Outpost trader"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	suit = /obj/item/clothing/suit/apron
	shoes = /obj/item/clothing/shoes/laceup

/datum/outpost_shop
	/// Display name the outpost takes on the overmap
	var/outpost_name = "trader outpost"
	/// Overmap description
	var/outpost_desc = "An independent trade station."
	/// Name the trader NPC introduces themselves with
	var/trader_name = "Trader"
	/// Outfit the trader NPC's appearance is dressed in
	var/trader_outfit = /datum/outfit/outpost_trader_generic
	/// Pronouns for the trader NPC's emotes/examine (PLURAL = they)
	var/trader_gender = PLURAL
	/// Voice bark pack for the trader's spoken lines (see modules/voice_barks)
	var/trader_voice_pack = "goon.speak_1"
	/// Pitch multiplier for the trader's bark voice
	var/trader_voice_pitch = 1
	/// Ordered UI category tabs; categories not listed here sort after, in first-seen order
	var/list/categories = list()
	/// SKU typepaths always stocked here (the core shelf)
	var/list/sku_types = list()
	/// SKU typepaths the rotating shelf draws from each round
	var/list/rotating_pool = list()
	/// How many rotating picks go on the shelf per round
	var/rotating_picks = 3
	/// SKU typepaths the rare showcase shelf draws from each round
	var/list/rare_pool = list()
	/// Max rare picks per round (min 1 whenever the pool is non-empty)
	var/rare_picks_max = 2
	/// SKU typepaths on the reputation-gated back-room shelf, stocked every round
	/// (see trader_favor.dm, supply is per-crew, not shared)
	var/list/favor_sku_types = list()
	/// Spoken on request when this crew can order from the back room.
	var/back_room_line
	/// Chart/rumor SKU typepaths this shop's chart shelf draws from. Every
	/// outpost draws independently from the same catalog: charts are deliberately
	/// zone-mixed, so which band a tip points at has nothing to do with which
	/// band you bought it in (see shop_catalog_charts.dm).
	var/list/chart_pool = list()
	/// How many chart picks land on the shelf per round
	var/chart_picks = 3
	/// /datum/shop_rotation typepaths: dedicated weighted shelves (see below)
	var/list/rotations = list()
	/// Live rotation instances, one per entry in `rotations`
	var/list/datum/shop_rotation/live_rotations = list()
	/// Live SKU instances (hold the shared per-round stock)
	var/list/datum/shop_sku/skus = list()
	/// Buyback typepaths: what this trader buys from players (see shop_buyback.dm)
	var/list/buyback_types = list()
	/// Live buyback instances (hold the shared per-round demand)
	var/list/datum/shop_buyback/buybacks = list()
	/// The outpost this shop belongs to
	var/obj/structure/overmap/trader_outpost/outpost
	/// The trader NPC fronting this shop, if one is placed (set on interior link)
	var/mob/living/basic/outpost_trader/trader_npc
	/// Personality lines, keyed by TRADER_LINE_* category
	var/list/trader_lines = list()
	/// Supply request table for the outpost mission board: list of
	/// list("type" = path, "name" = text, "amount" = num, "difficulty" = MISSION_DIFFICULTY_*)
	var/list/mission_requests = list()
	/// Extra contract types this shop's board can post beyond the standard
	/// mix, as typepath -> weight (the general outpost's angling requests)
	var/list/extra_offer_mix = list()

/datum/outpost_shop/New(obj/structure/overmap/trader_outpost/outpost)
	..()
	src.outpost = outpost
	for(var/sku_type in sku_types)
		add_sku(sku_type, SHELF_CORE)
	for(var/sku_type in pick_from_pool(rotating_pool, rotating_picks))
		add_sku(sku_type, SHELF_ROTATING)
	if(length(rare_pool))
		for(var/sku_type in pick_from_pool(rare_pool, rand(1, rare_picks_max)))
			add_sku(sku_type, SHELF_RARE)
	for(var/sku_type in favor_sku_types)
		add_sku(sku_type, SHELF_FAVOR)
	// Each outpost deals its own chart shelf. Separate purchases reveal fresh sites.
	for(var/sku_type in deal_chart_picks())
		add_sku(sku_type, SHELF_ROTATING)
	for(var/rotation_type in rotations)
		var/datum/shop_rotation/rotation = new rotation_type
		live_rotations += rotation
		for(var/sku_type in rotation.deal(rotation.slots))
			add_rotation_sku(rotation, sku_type)
	roll_special()
	for(var/buyback_type in buyback_types)
		buybacks += new buyback_type

/datum/outpost_shop/Destroy()
	QDEL_LIST(skus)
	QDEL_LIST(buybacks)
	QDEL_LIST(live_rotations)
	outpost = null
	trader_npc = null
	return ..()

/**
 * Draws up to `count` distinct random typepaths from a pool list.
 */
/datum/outpost_shop/proc/pick_from_pool(list/pool, count)
	var/list/picked = list()
	if(!length(pool) || count < 1)
		return picked
	var/list/candidates = pool.Copy()
	while(length(candidates) && length(picked) < count)
		var/choice = pick(candidates)
		candidates -= choice
		picked += choice
	return picked

/**
 * Deals this shop's chart shelf: up to `chart_picks` distinct typepaths out of
 * chart_pool.
 *
 * Picks are distinct within this shop, but another outpost may sell the same
 * template: every purchased ruin chart generates its own fresh encounter.
 *
 * Picks are stamped SHELF_ROTATING by the caller so the existing stock, reward
 * and UI logic keeps working without a fourth shelf constant.
 */
/datum/outpost_shop/proc/deal_chart_picks()
	return pick_from_pool(chart_pool, chart_picks)

/**
 * Instantiates a SKU onto the given shelf. Rotating stock is capped at 2,
 * rare stock is always the single showcase unit.
 */
/datum/outpost_shop/proc/add_sku(sku_type, shelf)
	var/datum/shop_sku/sku = new sku_type
	sku.shelf = shelf
	sku.shop = src
	switch(shelf)
		if(SHELF_ROTATING)
			sku.stock = clamp(sku.stock, 1, 2)
		if(SHELF_RARE)
			sku.stock = 1
		if(SHELF_FAVOR)
			// Shared stock never runs the back room dry; supply is the per-crew cap
			sku.stock = FAVOR_UNIQUE_CREW_LIMIT
	skus += sku

/**
 * Puts a SKU dealt by `rotation` on the rotating shelf and tags it, so the
 * convoy swaps it through the rotation rather than the ordinary rotating pool.
 */
/datum/outpost_shop/proc/add_rotation_sku(datum/shop_rotation/rotation, sku_type)
	add_sku(sku_type, SHELF_ROTATING)
	var/datum/shop_sku/sku = skus[length(skus)]
	sku.rotation = rotation
	return sku

/**
 * Every sold-out rotation slot is replaced with a different weighted pick from
 * the same rotation. Nothing refills in place: the shelf only ever shows what
 * the convoy happened to bring.
 */
/datum/outpost_shop/proc/restock_rotations()
	for(var/datum/shop_rotation/rotation as anything in live_rotations)
		var/list/sold_out = list()
		var/list/on_shelf = list()
		for(var/datum/shop_sku/sku as anything in skus)
			if(sku.rotation != rotation)
				continue
			on_shelf += sku.type
			if(sku.stock <= 0 && !sku.restock_interval)
				sold_out += sku
		for(var/datum/shop_sku/gone as anything in sold_out)
			skus -= gone
			qdel(gone)
			// The sold type and everything still on the shelf are held back, so
			// a slot always turns over into something different
			var/replacement = rotation.pick_one(on_shelf)
			if(!replacement)
				continue
			on_shelf += replacement
			add_rotation_sku(rotation, replacement)

/**
 * Puts one random credit-priced SKU on special for the round (15-30% off).
 */
/datum/outpost_shop/proc/roll_special()
	var/list/eligible = list()
	for(var/datum/shop_sku/sku as anything in skus)
		// Back-room prices use only the crew's ordinary credit discount.
		if(sku.shelf == SHELF_FAVOR)
			continue
		if(sku.fixed_price)
			continue
		if(sku.price_credits > 0 && !sku.discount_pct)
			eligible += sku
	if(!length(eligible))
		return
	var/datum/shop_sku/special = pick(eligible)
	special.discount_pct = pick(15, 20, 25, 30)

/**
 * The supply convoy came through: tops core stock back up, swaps one sold-out
 * rotating slot for a fresh pool pick, rerolls the special and softens the
 * buyback demand caps. Driven by the outpost's restock timer.
 */
/datum/outpost_shop/proc/convoy_restock()
	// Core shelves creep back toward full
	for(var/datum/shop_sku/sku as anything in skus)
		// Timed stock has its own clock; INFINITY keeps a finite shelf exhausted.
		if(sku.restock_interval)
			continue
		if(sku.shelf == SHELF_CORE && sku.stock < sku.stock_max - sku.reserved_stock)
			sku.stock = min(sku.stock_max - sku.reserved_stock, sku.stock + max(1, round(sku.stock_max / 2)))
		// A new paid chart creates a fresh ruin, so named tips can be sold again.
		else if(istype(sku, /datum/shop_sku/ruin_chart) && sku.stock < sku.stock_max)
			sku.stock = sku.stock_max

	// One sold-out rotating slot gets replaced with something new off the manifest.
	// Chart picks are deliberately excluded: they ride the rotating shelf but came
	// from chart_pool, so a replacement from rotating_pool would silently swap
	// a sold tip for an unrelated good. Named tips replenish separately above.
	var/list/depleted = list()
	for(var/datum/shop_sku/sku as anything in skus)
		if(sku.shelf == SHELF_ROTATING && !sku.is_chart && !sku.rotation && !sku.restock_interval && sku.stock <= 0)
			depleted += sku
	if(length(depleted))
		var/datum/shop_sku/gone = pick(depleted)
		var/list/unstocked = rotating_pool.Copy()
		for(var/datum/shop_sku/sku as anything in skus)
			unstocked -= sku.type
		skus -= gone
		qdel(gone)
		add_sku(length(unstocked) ? pick(unstocked) : pick(rotating_pool), SHELF_ROTATING)

	// Weighted rotations turn their sold-out slots over
	restock_rotations()

	// Yesterday's special is over; roll a new one
	for(var/datum/shop_sku/sku as anything in skus)
		sku.discount_pct = initial(sku.discount_pct)
	roll_special()

	// The trader found room in the warehouse for a bit more of everything
	for(var/datum/shop_buyback/buyback as anything in buybacks)
		if(buyback.demand < buyback.demand_max)
			buyback.demand = min(buyback.demand_max, buyback.demand + max(1, round(buyback.demand_max / 2)))

/**
 * Credit-equivalent worth of a SKU, folding its voucher price in. A lot of the
 * best stock is priced in vouchers with price_credits left at 0, and reading
 * credits alone values those at nothing.
 */
/datum/outpost_shop/proc/get_sku_value(datum/shop_sku/sku)
	if(!sku)
		return 0
	return sku.price_credits + (sku.price_vouchers * VOUCHER_CREDIT_VALUE)

/**
 * What `amount` units of `item_type` would fetch at this shop's own buyback
 * window, in credits. This is the floor a delivery contract has to clear: if
 * carrying the goods twenty steps to the counter pays better than the contract
 * asking for them, the contract is dead content. 0 when the trader doesn't buy
 * the good at all, which leaves the difficulty band to set the pay alone.
 */
/datum/outpost_shop/proc/get_counter_value(item_type, amount = 1)
	if(!ispath(item_type))
		return 0
	for(var/datum/shop_buyback/buyback as anything in buybacks)
		if(!buyback.item_path)
			continue
		if(buyback.match_subtypes ? !ispath(item_type, buyback.item_path) : (item_type != buyback.item_path))
			continue
		var/per_sale = buyback.pay_credits + (buyback.pay_vouchers * VOUCHER_CREDIT_VALUE)
		return round(per_sale * amount / max(1, buyback.amount))
	return 0

/// Build a fixed quote. Only available, credit-priced core stock can form its package.
/datum/outpost_shop/proc/roll_contract_reward(datum/mission/mission, ask_value = 0)
	if(QDELETED(mission))
		return FALSE
	if(!isnull(mission.contract_quote))
		return TRUE // Reopening or retargeting cannot reroll an existing quote.
	var/band
	var/service
	switch(mission.difficulty)
		if(MISSION_DIFFICULTY_HARD)
			band = rand(CONTRACT_PAY_HARD_MIN, CONTRACT_PAY_HARD_MAX)
			service = CONTRACT_SERVICE_HARD
		if(MISSION_DIFFICULTY_MEDIUM)
			band = rand(CONTRACT_PAY_MEDIUM_MIN, CONTRACT_PAY_MEDIUM_MAX)
			service = CONTRACT_SERVICE_MEDIUM
		else
			band = rand(CONTRACT_PAY_EASY_MIN, CONTRACT_PAY_EASY_MAX)
			service = CONTRACT_SERVICE_EASY
	var/target = floor(band * mission.contract_pay_mult)
	mission.contract_no_vouchers = mission.is_routine_contract()
	if(istype(mission, /datum/mission/outpost_supply))
		var/datum/mission/outpost_supply/supply = mission
		if(supply.request_pay_min)
			target = rand(supply.request_pay_min, supply.request_pay_max)
		if(mission.contract_no_vouchers)
			target = max(CEILING(ask_value * CONTRACT_EXCEPTION_PREMIUM, 1), min(floor(band * CONTRACT_EXCEPTION_MULT), service))
		else
			target = max(CEILING(ask_value * CONTRACT_ASK_PREMIUM, 1), min(target, ask_value + service))
	else if(istype(mission, /datum/mission/outpost_courier))
		var/datum/mission/outpost_courier/courier = mission
		var/obj/structure/overmap/trader_outpost/destination = courier.get_destination()
		if(!outpost || !destination)
			return FALSE
		target = min(target, CONTRACT_COURIER_DISTANCE_PAY * max(abs(outpost.x - destination.x), abs(outpost.y - destination.y)))

	mission.contract_quote = target
	mission.contract_reward_shop = src
	mission.mission_reward = null
	mission.mission_rewards = list()
	mission.rare_reward_types = null
	mission.reward_amounts = list()
	mission.contract_stock = list()
	mission.contract_item_values = list()
	var/list/valued = list()
	var/list/stock_by_path = list()
	for(var/datum/shop_sku/sku as anything in skus)
		if(!sku.item_path || sku.shelf != SHELF_CORE || !sku.contract_reward || sku.stock <= 0)
			continue
		if(sku.price_credits <= 0 || sku.price_vouchers > 0 || istype(sku, /datum/shop_sku/barter))
			continue
		valued[sku.item_path] = sku.price_credits
		stock_by_path[sku.item_path] = sku
	var/package_value = 0
	var/budget = floor(target * CONTRACT_SHELF_SHARE)
	while(length(mission.mission_rewards) < CONTRACT_MAX_REWARD_ITEMS)
		var/item_path = pick_valued_reward(valued, budget - package_value)
		if(!item_path)
			break
		var/datum/shop_sku/sku = stock_by_path[item_path]
		mission.mission_rewards += item_path
		mission.contract_stock[item_path] = sku
		mission.contract_item_values[item_path] = valued[item_path]
		mission.reward_amounts[item_path] = sku.dispense_amount
		package_value += valued[item_path]
		valued -= item_path
	mission.metric_item_value = package_value
	mission.set_contract_currency(target - package_value)
	return TRUE

/// Prefer the upper end of the affordable range, with no overshoot or fallback.
/datum/outpost_shop/proc/pick_valued_reward(list/valued, budget)
	var/best = 0
	for(var/item_path in valued)
		if(valued[item_path] <= budget)
			best = max(best, valued[item_path])
	if(!best)
		return null
	var/list/contenders = list()
	for(var/item_path in valued)
		if(valued[item_path] <= budget && valued[item_path] >= best * 0.6)
			contenders += item_path
	return pick(contenders)

/**
 * Returns a random personality line for the given TRADER_LINE_* category.
 */
/datum/outpost_shop/proc/get_line(category)
	var/list/lines = trader_lines[category]
	if(!length(lines))
		return null
	return pick(lines)

/datum/outpost_shop/proc/get_back_room_line(mob/user)
	var/datum/voidcrew_crew_record/crew = get_crew_ship(user)?.get_crew_record()
	if(!crew || !back_room_line)
		return null
	for(var/datum/shop_sku/sku in skus)
		if(sku.shelf == SHELF_FAVOR && sku.has_zone_permission(crew))
			return back_room_line
	return null

/**
 * # Shop SKU
 *
 * One purchasable line item. Stock is rolled once on creation and shared
 * between everyone shopping at the outpost.
 */
/datum/shop_sku
	/// Display name (defaults to the item's name)
	var/name
	/// Display description (defaults to the item's desc)
	var/desc
	/// What you get, any movable atom (crates and machines dispense at the terminal's feet)
	var/atom/movable/item_path
	/// UI category tab this SKU lists under
	var/category = "General"
	/// Which shelf this SKU landed on (stamped by the shop; drives UI styling + supply caps)
	var/shelf = SHELF_CORE
	/// The shop stocking this SKU (stamped by add_sku; favor pricing/gating read it)
	var/datum/outpost_shop/shop
	/// Continuing crew permission required by every occurrence of this SKU.
	var/zone_permission = ZONE_PERMISSION_PUBLIC
	/// Max units one crew may buy per round (0 = uncapped; favor uniques cap at
	/// FAVOR_UNIQUE_CREW_LIMIT). Enforced on the continuing crew record.
	var/crew_limit = 0
	/// TRUE on the intel SKUs (star charts, ruin charts, rumor tips). Whenever
	/// one of these lands on the rotating shelf, convoy_restock must never
	/// refill its slot from rotating_pool, see the comment there.
	var/is_chart = FALSE
	/// Price in credits (0 = credits play no part)
	var/price_credits = 0
	/// Price in trade vouchers (0 = vouchers play no part)
	var/price_vouchers = 0
	/// Percent off the credit price this round (set by the shop's special roll, or authored)
	var/discount_pct = 0
	/// For stack-type goods: units per purchase (1 leaves the stack's own default)
	var/dispense_amount = 1
	/// Per-round stock roll bounds
	var/stock_min = 2
	var/stock_max = 4
	/// Remaining stock this round
	var/stock = 0
	/// Units held for accepted board contracts, excluded from the sellable stock.
	var/reserved_stock = 0
	/// Author override when the item's initial icon renders wrong in the UI (GAGS etc.)
	var/icon_override
	var/icon_state_override
	/// Cached base64 icon for the UI, computed once per instance
	var/cached_icon
	/// The weighted rotation that dealt this SKU, if any (see /datum/shop_rotation)
	var/datum/shop_rotation/rotation
	/// Ignores specials and crew favor discounts: the price on the tag is the price
	var/fixed_price = FALSE
	/// Whether outpost contracts may pay this out as part of a reward bundle
	var/contract_reward = TRUE
	/// 0 uses convoys; a positive interval returns one unit; INFINITY never refills.
	var/restock_interval = 0
	/// Independent of convoy arrivals, visits, specials and crew ownership.
	var/restock_timer

/datum/shop_sku/New()
	..()
	stock = rand(stock_min, stock_max)
	if(restock_interval > 0 && restock_interval < INFINITY)
		restock_timer = addtimer(CALLBACK(src, PROC_REF(restock_unit)), restock_interval, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)
	if(item_path)
		var/atom/movable/cast = item_path
		if(!name)
			name = initial(cast.name)
		if(!desc)
			desc = initial(cast.desc)

/datum/shop_sku/Destroy()
	if(restock_timer)
		deltimer(restock_timer)
		restock_timer = null
	shop = null
	rotation = null
	return ..()

/// Never bank missed deliveries while full, or replenish a reserved contract unit.
/datum/shop_sku/proc/restock_unit()
	stock = min(max(0, stock_max - reserved_stock), stock + 1)

/**
 * The credit price after discounts, rounded down to a clean 5. With a buyer,
 * their crew's favor discount competes with the special: the better of the two
 * applies (max, not stacked. Favor shouldn't turn a 30%-off special into 45%).
 * Without a buyer (catalog/static contexts) only the authored special shows.
 */
/datum/shop_sku/proc/get_credit_price(mob/living/user, obj/structure/overmap/ship/crew_ship = get_crew_ship(user))
	if(price_credits <= 0 || fixed_price)
		return price_credits
	var/pct = discount_pct
	if(user && shop)
		pct = max(pct, shop.get_discount_pct(crew_ship))
	if(!pct)
		return price_credits
	return max(5, round(price_credits * (100 - pct) / 100, 5))

/**
 * Human-readable price tag, e.g. "3 vouchers + 500 cr".
 */
/datum/shop_sku/proc/get_price_text()
	var/list/parts = list()
	if(price_vouchers > 0)
		parts += "[price_vouchers] voucher[price_vouchers > 1 ? "s" : ""]"
	if(price_credits > 0)
		parts += "[get_credit_price()] cr"
	if(!length(parts))
		return "free"
	return parts.Join(" + ")

/**
 * Base64 sprite for the storefront UI, cached per instance.
 */
/datum/shop_sku/proc/get_ui_icon()
	if(cached_icon)
		return cached_icon
	var/atom/movable/cast = item_path
	var/icon_file = icon_override || (item_path ? initial(cast.icon) : null)
	if(!icon_file)
		return null
	var/state = icon_state_override || initial(cast.icon_state)
	cached_icon = icon2base64(icon(icon_file, state, SOUTH, frame = 1))
	return cached_icon

/**
 * Whether the user can pay right now (does not charge).
 */
/datum/shop_sku/proc/can_afford(mob/living/user)
	var/obj/structure/overmap/ship/crew_ship = get_crew_ship(user)
	if(get_favor_denial(user, crew_ship))
		return FALSE
	if(price_vouchers > 0 && count_trade_vouchers(user) < price_vouchers)
		return FALSE
	var/credit_price = get_credit_price(user, crew_ship)
	if(credit_price > 0)
		var/datum/bank_account/account = get_account(user, crew_ship)
		if(!account || !account.has_money(credit_price))
			return FALSE
	return TRUE

/// Shared by retail and contract packages; missing crew context has Public access.
/datum/shop_sku/proc/has_zone_permission(datum/voidcrew_crew_record/crew)
	if(zone_permission == ZONE_PERMISSION_PUBLIC)
		return TRUE
	return !QDELETED(crew) && crew.has_zone_permission(zone_permission)

/// Legacy proc name retained for callers; trader favor no longer admits a buyer.
/datum/shop_sku/proc/get_favor_denial(mob/living/user, obj/structure/overmap/ship/crew_ship = get_crew_ship(user))
	if(crew_ship && get_crew_ship(user, crew_ship) != crew_ship)
		return "I can't clear that shipment."
	var/datum/voidcrew_crew_record/crew = crew_ship?.get_crew_record()
	if(!has_zone_permission(crew) || (crew_limit > 0 && !crew))
		return "Your crew isn't cleared for that yet."
	if(crew_limit > 0 && (crew.favor_unique_purchases[type] || 0) >= crew_limit)
		return "I've filled that order already."
	return null

/// Recheck the live counter even when the caller has a stale interactive UI.
/datum/shop_sku/proc/can_trade(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(QDELETED(src) || QDELETED(user))
		return FALSE
	if(shop && (QDELETED(shop) || !(src in shop.skus)))
		return FALSE
	if(vendor && (QDELETED(vendor) || vendor.shop != shop || !vendor.check_menu(user)))
		return FALSE
	var/obj/structure/overmap/trader_outpost/outpost = shop?.outpost
	if(outpost && (QDELETED(outpost) || outpost.is_user_barred(user) || (vendor && (vendor.outpost != outpost || !outpost.contains_site_turf(get_turf(vendor))))))
		return FALSE
	return TRUE

/**
 * Why the user can't buy, shown as a tooltip / chat line.
 */
/datum/shop_sku/proc/get_denial_reason(mob/living/user)
	if(stock <= 0 && shelf != SHELF_FAVOR)
		return "Out of stock."
	var/obj/structure/overmap/ship/crew_ship = get_crew_ship(user)
	var/favor_denial = get_favor_denial(user, crew_ship)
	if(favor_denial)
		return favor_denial
	if(price_vouchers > 0)
		var/carrying = count_trade_vouchers(user)
		if(carrying < price_vouchers)
			return "Insufficient vouchers."
	var/credit_price = get_credit_price(user, crew_ship)
	if(credit_price > 0)
		var/datum/bank_account/account = get_account(user, crew_ship)
		if(!account)
			return "No ship account."
		if(!account.has_money(credit_price))
			return "Insufficient credits."
	return null

/**
 * Attempts the purchase: validates, charges, decrements stock and dispenses
 * over the counter. Returns TRUE on success.
 */
/datum/shop_sku/proc/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(!can_trade(user, vendor))
		return FALSE
	if(stock <= 0 && shelf != SHELF_FAVOR)
		return FALSE
	var/obj/structure/overmap/ship/crew_ship = get_crew_ship(user)
	if(get_favor_denial(user, crew_ship))
		return FALSE

	// Validate the credit half before consuming any vouchers
	var/credit_price = get_credit_price(user, crew_ship)
	var/datum/bank_account/account
	if(credit_price > 0)
		account = get_account(user, crew_ship)
		if(!account || !account.has_money(credit_price))
			return FALSE
	if(price_vouchers > 0 && count_trade_vouchers(user) < price_vouchers)
		return FALSE

	// Reserve on the same continuing record before any debit or item creation.
	var/datum/voidcrew_crew_record/capped_crew
	if(crew_limit > 0)
		capped_crew = crew_ship?.get_crew_record()
		if(!capped_crew?.claim_purchase(type, crew_limit))
			return FALSE
	if(credit_price > 0 && !account.adjust_money(-credit_price, "Trader Outpost: [name]"))
		capped_crew?.release_purchase(type)
		return FALSE
	if(price_vouchers > 0 && !consume_trade_vouchers(user, price_vouchers))
		if(credit_price > 0)
			account.adjust_money(credit_price, "Trader Outpost: [name] refund")
		capped_crew?.release_purchase(type)
		return FALSE

	if(shelf != SHELF_FAVOR)
		stock--
	dispense(user, vendor)
	metric_shop_purchase(src, user, credit_price, price_vouchers)
	return TRUE

/**
 * Hands the goods over the counter. Items go to hand when possible; anything
 * bigger (crates, machines) lands at the buyer's feet.
 */
/datum/shop_sku/proc/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	var/atom/drop_loc = user.drop_location() || vendor?.drop_location()
	var/atom/movable/goods = create_trader_goods(item_path, drop_loc, dispense_amount)
	// Past a trader outpost's checkpoint a gun is handed over sealed (outpost_trespass.dm)
	var/atom/movable/handed = outpost_seal_goods(goods)
	mark_trader_goods(handed)
	if(isitem(handed) && user.put_in_hands(handed))
		to_chat(user, span_notice("You receive [handed]."))
	else
		to_chat(user, span_notice("[handed] is set down at your feet."))
	// Returned so SKU subtypes can stamp what they hand over (the diner's
	// plated shelf adds TRAIT_FOOD_CHEF_MADE here, see shop_catalog_diner.dm)
	return goods

/**
 * The selected ship's account, revalidated against the user's current crew.
 */
/datum/shop_sku/proc/get_account(mob/living/user, obj/structure/overmap/ship/crew_ship = get_crew_ship(user))
	if(!crew_ship || get_crew_ship(user, crew_ship) != crew_ship)
		return null
	return crew_ship.ship_account

/**
 * # Barter SKU
 *
 * Item-for-item trade as its own SKU type: hand over the asked item, get the
 * goods. No vouchers or credits involved. Barter goods stay hold-in-hand on
 * purpose, you slap the trade on the counter.
 */
/datum/shop_sku/barter
	category = "Barter Deals"
	/// The item the trader wants
	var/obj/item/barter_path
	/// How many (only meaningful when barter_path is a stack type)
	var/barter_amount = 1
	/// Display name of the wanted item (defaults to the item's name)
	var/barter_name

/datum/shop_sku/barter/New()
	. = ..()
	if(barter_path && !barter_name)
		var/obj/item/cast = barter_path
		barter_name = initial(cast.name)

/datum/shop_sku/barter/get_price_text()
	if(barter_amount > 1)
		return "barter: [barter_amount]x [barter_name]"
	return "barter: [barter_name]"

/datum/shop_sku/barter/proc/find_barter_item(mob/living/user)
	for(var/obj/item/offered in user.held_items)
		if(!istype(offered, barter_path))
			continue
		if(isstack(offered))
			var/obj/item/stack/offered_stack = offered
			if(offered_stack.amount < barter_amount)
				continue
		return offered
	return null

/datum/shop_sku/barter/can_afford(mob/living/user)
	return !get_favor_denial(user) && !!find_barter_item(user)

/datum/shop_sku/barter/get_denial_reason(mob/living/user)
	if(stock <= 0 && shelf != SHELF_FAVOR)
		return "Out of stock."
	var/favor_denial = get_favor_denial(user)
	if(favor_denial)
		return favor_denial
	if(!find_barter_item(user))
		return "That isn't what I asked for."
	return null

/datum/shop_sku/barter/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(!can_trade(user, vendor))
		return FALSE
	if(stock <= 0 && shelf != SHELF_FAVOR)
		return FALSE
	var/obj/structure/overmap/ship/crew_ship = get_crew_ship(user)
	if(get_favor_denial(user, crew_ship))
		return FALSE
	var/obj/item/offered = find_barter_item(user)
	if(!offered)
		return FALSE
	var/datum/voidcrew_crew_record/capped_crew
	if(crew_limit > 0)
		capped_crew = crew_ship?.get_crew_record()
		if(!capped_crew?.claim_purchase(type, crew_limit))
			return FALSE
	if(isstack(offered))
		var/obj/item/stack/offered_stack = offered
		if(!offered_stack.use(barter_amount))
			capped_crew?.release_purchase(type)
			return FALSE
	else
		qdel(offered)
	if(shelf != SHELF_FAVOR)
		stock--
	dispense(user, vendor)
	metric_shop_purchase(src, user)
	return TRUE

/// Eligible hull contexts for the current crew. Roster order never chooses an account.
/proc/get_crew_ships(mob/user)
	var/list/ships = list()
	var/datum/voidcrew_crew_record/record = user?.mind?.get_reputation_crew()
	if(!record || !(user.mind in record.minds))
		return ships
	for(var/datum/team/voidcrew/team in record.teams)
		var/obj/structure/overmap/ship/ship = team.ship
		if(!QDELETED(ship) && ship.ship_team == team && team.crew_record == record && !ship.abandoned && !ship.retired_by_checkpoint && !ship.checkpoint_rebuilding)
			ships |= ship
	return ships

/// Z3/Z5 may pass an explicit hull or persist it through select_crew_service_ship().
/// Prefer a validated selection, then the hull aboard/alone at this site.
/proc/get_crew_ship(mob/user, obj/structure/overmap/ship/requested_ship)
	var/list/ships = get_crew_ships(user)
	if(!length(ships))
		return null
	if(requested_ship)
		return (requested_ship in ships) ? requested_ship : null
	var/obj/structure/overmap/ship/selected = user.mind.crew_service_ship_ref?.resolve()
	if(selected in ships)
		return selected
	var/obj/structure/overmap/ship/aboard = get_ship_from_atom(user)
	if(aboard in ships)
		return aboard
	var/obj/structure/overmap/site = SSovermap_zones.get_overmap_object_for_turf(get_turf(user))
	var/list/berthed = list()
	if(site)
		for(var/obj/structure/overmap/ship/ship in ships)
			if(ship.docked == site)
				berthed += ship
	if(length(berthed) == 1)
		return berthed[1]
	if(length(ships) == 1)
		return ships[1]
	return null

/// Revalidated on every subsequent action; membership switches clear the selection.
/datum/mind/proc/select_crew_service_ship(obj/structure/overmap/ship/ship)
	if(!current || !(ship in get_crew_ships(current)))
		return FALSE
	crew_service_ship_ref = WEAKREF(ship)
	return TRUE

/**
 * # Shop rotation
 *
 * A small dedicated shelf with its own weighted pool, for stock that should be
 * scarce and changing rather than always on hand. `slots` distinct picks go up
 * when the shop opens, each with whatever stock its SKU rolls (keep those at
 * 1 for one-off goods). On every convoy restock each sold-out slot swaps for a
 * different weighted pick (see /datum/outpost_shop/proc/restock_rotations).
 *
 * Kept apart from rotating_pool so a shop's ordinary rotating shelf is never
 * diluted by it. A shop lists rotation typepaths in its `rotations` var.
 */
/datum/shop_rotation
	/// SKU typepath -> weight. Higher weight turns up more often.
	var/list/pool = list()
	/// How many picks sit on the shelf at once
	var/slots = 2

/**
 * Up to `count` distinct weighted picks from the pool.
 */
/datum/shop_rotation/proc/deal(count)
	var/list/picked = list()
	for(var/_ in 1 to count)
		var/choice = pick_one(picked)
		if(!choice)
			break
		picked += choice
	return picked

/**
 * One weighted pick, skipping anything in `exclude`. Null when nothing is left.
 */
/datum/shop_rotation/proc/pick_one(list/exclude)
	var/list/candidates = list()
	for(var/sku_type in pool)
		if(exclude && (sku_type in exclude))
			continue
		candidates[sku_type] = max(1, pool[sku_type])
	if(!length(candidates))
		return null
	return pick_weight(candidates)

// The rumor SKU and every other chart line now live in shop_catalog_charts.dm,
// keeping this file to machinery as its header describes.
