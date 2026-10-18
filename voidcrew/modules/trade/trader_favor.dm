GLOBAL_LIST_EMPTY(voidcrew_crew_records)
GLOBAL_LIST_EMPTY(voidcrew_crew_roster)
GLOBAL_VAR_INIT(voidcrew_crew_serial, 0)

/** Round-only identity. The registry owns its lifetime, including after all hulls are lost.
 * Z2 claims immutable encounter/family receipt keys here before any yielding payout.
 * Z3/Z4 consume get_zone_permission(); neither favor nor imported knowledge changes it.
 */
/datum/voidcrew_crew_record
	var/crew_id
	var/list/teams = list()
	var/list/minds = list()
	var/list/ckeys = list()
	/// The founder, then the oldest surviving hull's captain or earliest remaining member.
	var/datum/mind/leader
	/// Join order for current characters. Cryo keeps affiliation but relinquishes leadership.
	var/list/leadership_members = list()
	/// Trader keys are main-shop typepaths; SKU keys are SKU typepaths.
	var/list/trader_favor = list()
	var/list/favor_unique_purchases = list()
	/// Band keys are strings because numeric ZONE_* values are list indices in DM.
	var/list/zone_totals = list("1" = 0, "2" = 0, "3" = 0)
	var/list/zone_families = list()
	/// Immutable encounter/family serial strings, shared by aliases of one settlement.
	var/list/settlement_claims = list()

/datum/voidcrew_crew_record/New()
	crew_id = ++GLOB.voidcrew_crew_serial
	GLOB.voidcrew_crew_records += src
	for(var/band in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED))
		var/list/families = list()
		for(var/family in zone_reputation_families())
			families[family] = 0
		zone_families["[band]"] = families
	return ..()

/datum/voidcrew_crew_record/Destroy()
	GLOB.voidcrew_crew_records -= src
	for(var/rostered_ckey in ckeys)
		if(GLOB.voidcrew_crew_roster[rostered_ckey] == src)
			GLOB.voidcrew_crew_roster -= rostered_ckey
	for(var/datum/team/voidcrew/team in teams.Copy())
		team.crew_record = null
	for(var/datum/mind/member in minds.Copy())
		member.leave_reputation_crew()
	teams.Cut()
	minds.Cut()
	ckeys.Cut()
	leader = null
	leadership_members.Cut()
	return ..()

/datum/voidcrew_crew_record/proc/join_leadership_roster(datum/mind/member)
	leadership_members |= member
	if(!leader)
		leader = member

/datum/voidcrew_crew_record/proc/leave_leadership_roster(datum/mind/member)
	leadership_members -= member
	if(leader != member)
		return
	leader = null
	// teams retain hull enrollment order, including when several were built in one tick.
	for(var/datum/team/voidcrew/team in teams)
		var/obj/structure/overmap/ship/ship = team.ship
		if(QDELETED(ship) || ship.abandoned || ship.retired_by_checkpoint)
			continue
		for(var/datum/mind/candidate in leadership_members)
			if(ship.is_ship_captain_mind(candidate))
				leader = candidate
				return
		break // Without a captain on the oldest hull, fall back to member join order.
	for(var/datum/mind/candidate in leadership_members)
		leader = candidate
		return

/// Round cleanup/admin disposal, not hull teardown. Never serialize these records.
/proc/clear_voidcrew_crew_records()
	for(var/datum/voidcrew_crew_record/record in GLOB.voidcrew_crew_records.Copy())
		qdel(record)
	GLOB.voidcrew_crew_roster.Cut()

/proc/zone_reputation_families()
	return list(ZONE_FAMILY_NAMED_KILL, ZONE_FAMILY_HUNT, ZONE_FAMILY_CAPTURE, ZONE_FAMILY_POACHERS, ZONE_FAMILY_PYLONS, ZONE_FAMILY_EXTRACTION, ZONE_FAMILY_CRIMINAL_BOUNTY, ZONE_FAMILY_LAIR)

/// Mission subtype map: ordinary surveys, stakes and suppression are excluded. Bounties and lairs settle separately.
/proc/zone_reputation_family(mission_type)
	if(ispath(mission_type, /datum/mission/recovery/kill))
		return ZONE_FAMILY_NAMED_KILL
	if(ispath(mission_type, /datum/mission/big_game_hunt))
		return ZONE_FAMILY_HUNT
	if(ispath(mission_type, /datum/mission/live_capture))
		return ZONE_FAMILY_CAPTURE
	if(ispath(mission_type, /datum/mission/poacher_bust))
		return ZONE_FAMILY_POACHERS
	if(ispath(mission_type, /datum/mission/recovery/survey) || ispath(mission_type, /datum/mission/research/core_sample))
		return ZONE_FAMILY_PYLONS
	if(ispath(mission_type, /datum/mission/recovery/extraction))
		return ZONE_FAMILY_EXTRACTION
	return null

/// Shared E/M/H weight for existing board favor and Z2's console/board receipts.
/proc/zone_work_reward(difficulty)
	switch(difficulty)
		if(MISSION_DIFFICULTY_HARD)
			return FAVOR_GAIN_HARD
		if(MISSION_DIFFICULTY_MEDIUM)
			return FAVOR_GAIN_MEDIUM
	return FAVOR_GAIN_EASY

/// Returns credited points, claiming even a capped receipt. Caller validates successful work.
/// No yield: simultaneous aliases cannot both claim. Never pass a proof object's ref as key.
/datum/voidcrew_crew_record/proc/claim_zone_work(family, band, difficulty, receipt_key)
	var/list/families = zone_families["[band]"]
	if(!families || !(family in families) || !(difficulty in list(MISSION_DIFFICULTY_EASY, MISSION_DIFFICULTY_MEDIUM, MISSION_DIFFICULTY_HARD)) \
		|| !istext(receipt_key) || !length(receipt_key) || settlement_claims[receipt_key])
		return 0
	settlement_claims[receipt_key] = TRUE
	var/cap = band == ZONE_GREEN ? ZONE_REPUTATION_GREEN_FAMILY_CAP : ZONE_REPUTATION_DANGER_FAMILY_CAP
	var/gain = min(zone_work_reward(difficulty), max(0, cap - families[family]))
	families[family] += gain
	zone_totals["[band]"] += gain
	return gain

/datum/voidcrew_crew_record/proc/get_zone_permission()
	if(zone_totals["[ZONE_GREEN]"] < ZONE_REPUTATION_GREEN_REQUIRED)
		return ZONE_PERMISSION_PUBLIC
	if(zone_totals["[ZONE_YELLOW]"] < ZONE_REPUTATION_YELLOW_REQUIRED)
		return ZONE_PERMISSION_YELLOW
	if(zone_totals["[ZONE_RED]"] < ZONE_REPUTATION_RED_REQUIRED)
		return ZONE_PERMISSION_ADVANCED
	return ZONE_PERMISSION_ELITE

/datum/voidcrew_crew_record/proc/has_zone_permission(required_permission)
	return isnum(required_permission) && required_permission >= ZONE_PERMISSION_PUBLIC && required_permission <= get_zone_permission()

/// Targetless routine asks are Public; unknown targeted bands fail closed.
/datum/voidcrew_crew_record/proc/can_work_in_zone(band)
	switch(band)
		if(ZONE_GREEN)
			return TRUE
		if(ZONE_YELLOW)
			return has_zone_permission(ZONE_PERMISSION_YELLOW)
		if(ZONE_RED)
			return has_zone_permission(ZONE_PERMISSION_ADVANCED)
	return FALSE

/// Atomic shared-cap reservation for Z3. Call before payment/grant; release on failure.
/datum/voidcrew_crew_record/proc/claim_purchase(sku_type, limit = FAVOR_UNIQUE_CREW_LIMIT)
	var/bought = favor_unique_purchases[sku_type] || 0
	if(limit <= 0 || bought >= limit)
		return FALSE
	favor_unique_purchases[sku_type] = bought + 1
	return TRUE

/datum/voidcrew_crew_record/proc/release_purchase(sku_type)
	var/bought = favor_unique_purchases[sku_type] || 0
	if(bought > 0)
		favor_unique_purchases[sku_type] = bought - 1

/// Only never-used provisional identities may be discarded before round cleanup.
/datum/voidcrew_crew_record/proc/is_unfounded()
	return !length(teams) && !length(minds) && !length(ckeys) && !length(trader_favor) && !length(favor_unique_purchases) && !length(settlement_claims) \
		&& !zone_totals["[ZONE_GREEN]"] && !zone_totals["[ZONE_YELLOW]"] && !zone_totals["[ZONE_RED]"]

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
	var/datum/voidcrew_crew_record/record = crew_ship?.get_crew_record()
	return record?.trader_favor[favor_key()] || 0

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

/// Credits trader favor without exposing internal standing to players.
/datum/outpost_shop/proc/grant_favor(obj/structure/overmap/ship/crew_ship, amount)
	var/datum/voidcrew_crew_record/record = crew_ship?.get_crew_record()
	if(!record || amount <= 0)
		return
	record.trader_favor[favor_key()] = get_favor(crew_ship) + amount

/// How many units of `sku_type` this crew has bought off the favor shelf
/datum/outpost_shop/proc/get_crew_purchases(obj/structure/overmap/ship/crew_ship, sku_type)
	var/datum/voidcrew_crew_record/record = crew_ship?.get_crew_record()
	return record?.favor_unique_purchases[sku_type] || 0

/// Records a favor-shelf purchase against the crew's per-round cap
/datum/outpost_shop/proc/record_crew_purchase(obj/structure/overmap/ship/crew_ship, sku_type)
	var/datum/voidcrew_crew_record/record = crew_ship?.get_crew_record()
	if(!record)
		return
	return record.claim_purchase(sku_type)

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
	if(is_routine_contract())
		return FAVOR_GAIN_EASY
	return zone_work_reward(difficulty)
