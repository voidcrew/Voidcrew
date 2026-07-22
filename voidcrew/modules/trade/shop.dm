/**
 * # Outpost Shops
 *
 * One /datum/outpost_shop instance per trader outpost, holding the per-round
 * shared stock its trader NPC sells from. SKUs have fixed,
 * simple prices: vouchers and/or credits, or an item barter — never a mixed
 * freeform payment UI.
 *
 * Stock is built from three shelves:
 * - CORE: the sku_types list, stocked every round.
 * - ROTATING: a few picks rolled from rotating_pool each round, limited supply.
 * - RARE: 1-2 showcase picks rolled from rare_pool, single unit each.
 * One credit-priced SKU per round also goes on special (discount_pct).
 *
 * Vouchers are deliberately the only road to the best stock ("the currency
 * that can't be farmed safely"); credits cover the mundane shelf.
 *
 * The per-shop catalogs (SKU/buyback/line definitions) live in the
 * shop_catalog_*.dm files; this file is the machinery.
 */
/datum/outpost_shop
	/// Display name the outpost takes on the overmap
	var/outpost_name = "trader outpost"
	/// Overmap description
	var/outpost_desc = "An independent trade station."
	/// Name the trader NPC introduces themselves with
	var/trader_name = "Trader"
	/// Outfit the trader NPC's appearance is dressed in
	var/trader_outfit = /datum/outfit/job/curator
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
	/// Live SKU instances (hold the shared per-round stock)
	var/list/datum/shop_sku/skus = list()
	/// Buyback typepaths — what this trader buys from players (see shop_buyback.dm)
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
	/// Items only ever awarded by this shop's hard contracts — never sold on
	/// any shelf. The depth hook: chasing the trader's board is the sole road
	/// to these.
	var/list/exclusive_rewards = list()
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
	roll_special()
	for(var/buyback_type in buyback_types)
		buybacks += new buyback_type

/datum/outpost_shop/Destroy()
	QDEL_LIST(skus)
	QDEL_LIST(buybacks)
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
 * Instantiates a SKU onto the given shelf. Rotating stock is capped at 2,
 * rare stock is always the single showcase unit.
 */
/datum/outpost_shop/proc/add_sku(sku_type, shelf)
	var/datum/shop_sku/sku = new sku_type
	sku.shelf = shelf
	switch(shelf)
		if(SHELF_ROTATING)
			sku.stock = clamp(sku.stock, 1, 2)
		if(SHELF_RARE)
			sku.stock = 1
	skus += sku

/**
 * Puts one random credit-priced SKU on special for the round (15-30% off).
 */
/datum/outpost_shop/proc/roll_special()
	var/list/eligible = list()
	for(var/datum/shop_sku/sku as anything in skus)
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
		if(sku.shelf == SHELF_CORE && sku.stock < sku.stock_max)
			sku.stock = min(sku.stock_max, sku.stock + max(1, round(sku.stock_max / 2)))

	// One sold-out rotating slot gets replaced with something new off the manifest
	var/list/depleted = list()
	for(var/datum/shop_sku/sku as anything in skus)
		if(sku.shelf == SHELF_ROTATING && sku.stock <= 0)
			depleted += sku
	if(length(depleted))
		var/datum/shop_sku/gone = pick(depleted)
		var/list/unstocked = rotating_pool.Copy()
		for(var/datum/shop_sku/sku as anything in skus)
			unstocked -= sku.type
		skus -= gone
		qdel(gone)
		add_sku(length(unstocked) ? pick(unstocked) : pick(rotating_pool), SHELF_ROTATING)

	// Yesterday's special is over; roll a new one
	for(var/datum/shop_sku/sku as anything in skus)
		sku.discount_pct = initial(sku.discount_pct)
	roll_special()

	// The trader found room in the warehouse for a bit more of everything
	for(var/datum/shop_buyback/buyback as anything in buybacks)
		if(buyback.demand < buyback.demand_max)
			buyback.demand = min(buyback.demand_max, buyback.demand + max(1, round(buyback.demand_max / 2)))

/**
 * Rolls a shop-exclusive item onto a freshly generated hard contract.
 * The exclusive replaces any generic item reward; vouchers/credits stay.
 */
/datum/outpost_shop/proc/maybe_attach_exclusive(datum/mission/mission, chance = 60)
	if(mission.difficulty != MISSION_DIFFICULTY_HARD || !length(exclusive_rewards))
		return
	if(!prob(chance))
		return
	mission.mission_reward = pick(exclusive_rewards)
	// Exclusives always read as rare in the reward UI
	LAZYADD(mission.rare_reward_types, mission.mission_reward)

/**
 * Assigns a difficulty-scaled item reward to an outpost-board contract, drawn
 * from this shop's own stock. Payment on these contracts is goods, not money —
 * credits and vouchers come from open-market missions instead, so the reward
 * item IS the pay and must always be set.
 *
 * Quality follows difficulty by reaching deeper shelves: easy contracts pay off
 * the core shelf, medium off the rotating stock, and the hardest pay the
 * back-room exclusives no shelf sells (falling back down the shelves if the
 * shop happens to have none). Returns FALSE only if the shop has no stock at
 * all, so the caller can discard an unfundable contract.
 */
/datum/outpost_shop/proc/roll_contract_reward(datum/mission/mission)
	var/list/core = list()
	var/list/rotating = list()
	var/list/rare = list()
	var/list/all_stock = list()
	for(var/datum/shop_sku/sku as anything in skus)
		if(!sku.item_path)
			continue
		all_stock += sku.item_path
		switch(sku.shelf)
			if(SHELF_RARE)
				rare += sku.item_path
			if(SHELF_ROTATING)
				rotating += sku.item_path
			else
				core += sku.item_path

	// The everyday goods; the fallback whenever a specific shelf is thin
	var/list/non_rare = core + rotating
	if(!length(non_rare))
		non_rare = all_stock

	var/list/rewards = list()
	var/list/rare_rewards = list()

	switch(mission.difficulty)
		if(MISSION_DIFFICULTY_HARD)
			// One back-room prize (exclusive, else a rare-shelf pick) plus a
			// couple of everyday goods — the "1 rare + 2 common" bundle.
			var/prize = length(exclusive_rewards) ? pick(exclusive_rewards) : (length(rare) ? pick(rare) : null)
			if(prize)
				rewards += prize
				rare_rewards += prize
			rewards += pick_rewards(length(rotating) ? rotating : non_rare, 2)
		if(MISSION_DIFFICULTY_MEDIUM)
			// A rotating pick and a staple
			rewards += pick_rewards(length(rotating) ? rotating : non_rare, 1)
			rewards += pick_rewards(length(core) ? core : non_rare, 1)
		else
			// One staple, sometimes two
			rewards += pick_rewards(length(core) ? core : non_rare, prob(35) ? 2 : 1)

	rewards -= null
	// Guarantee at least one item so the contract is fundable
	if(!length(rewards))
		rewards += pick_rewards(all_stock, 1)
		rewards -= null
	if(!length(rewards))
		return FALSE

	mission.mission_rewards = rewards
	mission.rare_reward_types = rare_rewards
	return TRUE

/**
 * Draws `count` reward typepaths from a pool, preferring distinct picks but
 * repeating once the pool is exhausted (so a one-item pool yields duplicates
 * rather than coming up short).
 */
/datum/outpost_shop/proc/pick_rewards(list/pool, count)
	var/list/picked = list()
	if(!length(pool) || count < 1)
		return picked
	var/list/bag = pool.Copy()
	for(var/i in 1 to count)
		if(!length(bag))
			bag = pool.Copy()
		var/choice = pick(bag)
		bag -= choice
		picked += choice
	return picked

/**
 * Returns a random personality line for the given TRADER_LINE_* category.
 */
/datum/outpost_shop/proc/get_line(category)
	var/list/lines = trader_lines[category]
	if(!length(lines))
		return null
	return pick(lines)

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
	/// What you get — any movable atom (crates and machines dispense at the terminal's feet)
	var/atom/movable/item_path
	/// UI category tab this SKU lists under
	var/category = "General"
	/// Which shelf this SKU landed on (stamped by the shop; drives UI styling + supply caps)
	var/shelf = SHELF_CORE
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
	/// Author override when the item's initial icon renders wrong in the UI (GAGS etc.)
	var/icon_override
	var/icon_state_override
	/// Cached base64 icon for the UI, computed once per instance
	var/cached_icon

/datum/shop_sku/New()
	..()
	stock = rand(stock_min, stock_max)
	if(item_path)
		var/atom/movable/cast = item_path
		if(!name)
			name = initial(cast.name)
		if(!desc)
			desc = initial(cast.desc)

/**
 * The credit price after any special discount, rounded down to a clean 5.
 */
/datum/shop_sku/proc/get_credit_price()
	if(!discount_pct || price_credits <= 0)
		return price_credits
	return max(5, round(price_credits * (100 - discount_pct) / 100, 5))

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
	if(price_vouchers > 0 && count_trade_vouchers(user) < price_vouchers)
		return FALSE
	if(get_credit_price() > 0)
		var/datum/bank_account/account = get_account(user)
		if(!account || !account.has_money(get_credit_price()))
			return FALSE
	return TRUE

/**
 * Why the user can't buy — shown as a tooltip / chat line.
 */
/datum/shop_sku/proc/get_denial_reason(mob/living/user)
	if(stock <= 0)
		return "Out of stock."
	if(price_vouchers > 0)
		var/carrying = count_trade_vouchers(user)
		if(carrying < price_vouchers)
			return "Need [price_vouchers] trade voucher[price_vouchers > 1 ? "s" : ""] (carrying [carrying])."
	if(get_credit_price() > 0)
		var/datum/bank_account/account = get_account(user)
		if(!account)
			return "No bank account on your ID."
		if(!account.has_money(get_credit_price()))
			return "Insufficient credits ([get_credit_price()] cr needed)."
	return null

/**
 * Attempts the purchase: validates, charges, decrements stock and dispenses
 * over the counter. Returns TRUE on success.
 */
/datum/shop_sku/proc/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(stock <= 0)
		return FALSE

	// Validate the credit half before consuming any vouchers
	var/credit_price = get_credit_price()
	var/datum/bank_account/account
	if(credit_price > 0)
		account = get_account(user)
		if(!account || !account.has_money(credit_price))
			return FALSE

	if(price_vouchers > 0 && !consume_trade_vouchers(user, price_vouchers))
		return FALSE
	if(credit_price > 0 && !account.adjust_money(-credit_price, "Trader Outpost: [name]"))
		return FALSE

	stock--
	dispense(user, vendor)
	return TRUE

/**
 * Hands the goods over the counter. Items go to hand when possible; anything
 * bigger (crates, machines) lands at the buyer's feet.
 */
/datum/shop_sku/proc/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	var/atom/drop_loc = user.drop_location() || vendor?.drop_location()
	var/atom/movable/goods
	if(dispense_amount > 1 && ispath(item_path, /obj/item/stack))
		goods = new item_path(drop_loc, dispense_amount)
	else
		goods = new item_path(drop_loc)
	if(isitem(goods) && user.put_in_hands(goods))
		to_chat(user, span_notice("You receive [goods]."))
	else
		to_chat(user, span_notice("[goods] is set down at your feet."))

/**
 * The bank account on the user's ID card.
 */
/datum/shop_sku/proc/get_account(mob/living/user)
	var/obj/item/card/id/id_card = user.get_idcard(TRUE)
	return id_card?.registered_account

/**
 * # Barter SKU
 *
 * Item-for-item trade as its own SKU type: hand over the asked item, get the
 * goods. No vouchers or credits involved. Barter goods stay hold-in-hand on
 * purpose — you slap the trade on the counter.
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
	return !!find_barter_item(user)

/datum/shop_sku/barter/get_denial_reason(mob/living/user)
	if(stock <= 0)
		return "Out of stock."
	if(!find_barter_item(user))
		return "Hold the asked item in hand: [get_price_text()]."
	return null

/datum/shop_sku/barter/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(stock <= 0)
		return FALSE
	var/obj/item/offered = find_barter_item(user)
	if(!offered)
		return FALSE
	if(isstack(offered))
		var/obj/item/stack/offered_stack = offered
		if(!offered_stack.use(barter_amount))
			return FALSE
	else
		qdel(offered)
	stock--
	dispense(user, vendor)
	return TRUE

/**
 * The first ship this user crews for (first team with a live ship) — the same
 * mind-to-ship mapping the embargo and the contract board use.
 */
/proc/get_crew_ship(mob/user)
	if(!user?.mind)
		return null
	for(var/datum/team/voidcrew/team as anything in user.mind.ship_teams)
		if(team.ship)
			return team.ship
	return null

/**
 * # Rumor SKU
 *
 * Intel over the counter: no goods change hands — the trader marks one
 * uncharted ruin signal from their own zone band straight onto the buyer
 * ship's helm readout, under a "Rumors" category. The certainty ladder's
 * cheapest rung: below star charts, above flying blind.
 */
/datum/shop_sku/rumor
	name = "word on the lanes"
	desc = "The trader knows where something interesting is parked. For a price, so do you: one uncharted signal from this zone band, marked on your helm."
	category = "Intel & Charts"
	icon_override = 'icons/obj/scrolls.dmi'
	icon_state_override = "blueprints"
	stock_min = 2
	stock_max = 4

/datum/shop_sku/rumor/proc/find_rumor_target(obj/structure/overmap/ship/ship, datum/outpost_shop/shop)
	var/outpost_zone = SSovermap_zones?.get_zone_type(get_turf(shop?.outpost))
	var/list/candidates = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(QDELETED(ruin) || !istype(get_turf(ruin), /turf/open/overmap))
			continue
		if(SSovermap_zones?.get_zone_type(get_turf(ruin)) != outpost_zone)
			continue
		if(ship.get_waypoint(REF(ruin)) || ship.get_waypoint("rumor_[REF(ruin)]"))
			continue
		candidates += ruin
	if(!length(candidates))
		return null
	return pick(candidates)

/datum/shop_sku/rumor/get_denial_reason(mob/living/user)
	. = ..()
	if(.)
		return
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return "No crew registration — you need a ship to chart the tip onto."

/datum/shop_sku/rumor/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(stock <= 0)
		return FALSE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return FALSE
	var/datum/outpost_shop/shop = vendor?.shop
	var/obj/structure/overmap/space_ruin/target = find_rumor_target(ship, shop)
	if(!target)
		to_chat(user, span_warning("The lanes are quiet — no fresh rumors this shift."))
		return FALSE

	var/credit_price = get_credit_price()
	var/datum/bank_account/account
	if(credit_price > 0)
		account = get_account(user)
		if(!account || !account.adjust_money(-credit_price, "Trader Outpost: [name]"))
			return FALSE
	if(price_vouchers > 0 && !consume_trade_vouchers(user, price_vouchers))
		return FALSE

	stock--
	var/list/coords = target.get_relative_overmap_coords()
	ship.add_waypoint("rumor_[REF(target)]", "[shop?.trader_name || "Trader"]'s tip: unknown signal", coords[1], coords[2], "Rumors")
	to_chat(user, span_notice("A new mark lands on [ship]'s helm readout: unknown signal at ([coords[1]], [coords[2]])."))
	return TRUE
