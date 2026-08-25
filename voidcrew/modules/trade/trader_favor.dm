/**
 * # Trader Favor
 *
 * Standing a crew earns with a trader by completing that trader's board
 * contracts. Favor buys nothing by itself: it discounts credit prices by tier
 * and, at the top tier, unlocks the trader's back-room shelf (SHELF_FAVOR) of
 * bespoke uniques, each capped at FAVOR_UNIQUE_CREW_LIMIT per crew per round.
 *
 * "Per crew" means the ship, same as the embargo and the contract board
 * (get_crew_ship). The ledger lives on the ship datum and dies with the hull
 * on purpose, a crew that loses its ship starts over with every trader.
 *
 * Favor is keyed by the outpost's MAIN shop type, not the shop instance:
 * a trader is a character (every general outpost is Barnaby's waystation),
 * and the vendor stalls on an outpost honor the host trader's standing rather
 * than running ledgers of their own. Voucher prices are never discounted.
 * Contracts pay vouchers, so a voucher discount would double-dip.
 */

/obj/structure/overmap/ship
	/// Favor points this crew holds per trader, keyed by the outpost's main
	/// shop typepath (see /datum/outpost_shop/proc/favor_key)
	var/list/trader_favor
	/// Units of each favor-shelf unique this crew has bought, keyed by SKU type
	var/list/favor_unique_purchases

/// The key a shop's standing is stored under: its outpost's main shop type.
/// Falls back to our own type for shops with no outpost (shouldn't happen).
/datum/outpost_shop/proc/favor_key()
	var/datum/outpost_shop/main = outpost?.shop || src
	return main.type

/// The trader standing with this shop is credited to (the outpost's face)
/datum/outpost_shop/proc/favor_trader_name()
	var/datum/outpost_shop/main = outpost?.shop || src
	return main.trader_name

/// Favor points `crew_ship` holds with this shop's trader
/datum/outpost_shop/proc/get_favor(obj/structure/overmap/ship/crew_ship)
	if(!crew_ship || !crew_ship.trader_favor)
		return 0
	return crew_ship.trader_favor[favor_key()] || 0

/// Favor tier for `crew_ship`: 0 stranger, 1 regular, 2 partner, 3 trusted
/datum/outpost_shop/proc/get_favor_tier(obj/structure/overmap/ship/crew_ship)
	var/favor = get_favor(crew_ship)
	if(favor >= FAVOR_TIER_TRUSTED)
		return 3
	if(favor >= FAVOR_TIER_PARTNER)
		return 2
	if(favor >= FAVOR_TIER_REGULAR)
		return 1
	return 0

/// Display name of a favor tier index
/datum/outpost_shop/proc/get_favor_tier_name(tier)
	switch(tier)
		if(3)
			return "Trusted"
		if(2)
			return "Partner"
		if(1)
			return "Regular"
	return "Stranger"

/// Credit-price discount (percent) `crew_ship`'s standing earns at this shop
/datum/outpost_shop/proc/get_discount_pct(obj/structure/overmap/ship/crew_ship)
	switch(get_favor_tier(crew_ship))
		if(3)
			return FAVOR_DISCOUNT_TRUSTED
		if(2)
			return FAVOR_DISCOUNT_PARTNER
		if(1)
			return FAVOR_DISCOUNT_REGULAR
	return 0

/// Points needed for the next tier, or 0 when already Trusted
/datum/outpost_shop/proc/get_next_tier_threshold(obj/structure/overmap/ship/crew_ship)
	switch(get_favor_tier(crew_ship))
		if(0)
			return FAVOR_TIER_REGULAR
		if(1)
			return FAVOR_TIER_PARTNER
		if(2)
			return FAVOR_TIER_TRUSTED
	return 0

/**
 * Credits `amount` favor to `crew_ship` and announces tier crossings. The
 * routine +N line rides the mission-complete toast (finish_mission), so this
 * only speaks up when a threshold is actually crossed.
 */
/datum/outpost_shop/proc/grant_favor(obj/structure/overmap/ship/crew_ship, amount)
	if(!crew_ship || amount <= 0)
		return
	var/old_tier = get_favor_tier(crew_ship)
	LAZYSET(crew_ship.trader_favor, favor_key(), get_favor(crew_ship) + amount)
	var/new_tier = get_favor_tier(crew_ship)
	if(new_tier <= old_tier)
		return
	var/perk_text
	switch(new_tier)
		if(3)
			perk_text = "[FAVOR_DISCOUNT_TRUSTED]% off credit prices, and the back-room shelf is open to your crew."
		if(2)
			perk_text = "[FAVOR_DISCOUNT_PARTNER]% off credit prices."
		else
			perk_text = "[FAVOR_DISCOUNT_REGULAR]% off credit prices."
	crew_ship.ship_notify("[favor_trader_name()] now counts your crew as [LOWER_TEXT(get_favor_tier_name(new_tier))]: [perk_text]", \
		"TRADER STANDING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/// How many units of `sku_type` this crew has bought off the favor shelf
/datum/outpost_shop/proc/get_crew_purchases(obj/structure/overmap/ship/crew_ship, sku_type)
	if(!crew_ship || !crew_ship.favor_unique_purchases)
		return 0
	return crew_ship.favor_unique_purchases[sku_type] || 0

/// Records a favor-shelf purchase against the crew's per-round cap
/datum/outpost_shop/proc/record_crew_purchase(obj/structure/overmap/ship/crew_ship, sku_type)
	if(!crew_ship)
		return
	LAZYSET(crew_ship.favor_unique_purchases, sku_type, get_crew_purchases(crew_ship, sku_type) + 1)

/**
 * # Back-room SKU base
 *
 * The favor-shelf line item: standing-gated behind Trusted, supplied per crew
 * rather than per shelf. Catalog files subtype this next to their other SKUs.
 */
/datum/shop_sku/favor
	category = "Back Room"
	favor_required = FAVOR_TIER_TRUSTED
	crew_limit = FAVOR_UNIQUE_CREW_LIMIT

/// Favor this mission pays its posting trader on completion (0 off-board)
/datum/mission/proc/get_favor_reward()
	if(!shop)
		return 0
	switch(difficulty)
		if(MISSION_DIFFICULTY_HARD)
			return FAVOR_GAIN_HARD
		if(MISSION_DIFFICULTY_MEDIUM)
			return FAVOR_GAIN_MEDIUM
	return FAVOR_GAIN_EASY
