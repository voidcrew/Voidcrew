GLOBAL_LIST_EMPTY(voidcrew_crew_records)
GLOBAL_LIST_EMPTY(voidcrew_crew_roster)
GLOBAL_VAR_INIT(voidcrew_crew_serial, 0)

/** Round-only identity. The registry owns its lifetime, including after all hulls are lost.
 * Jobs and criminals claim immutable receipt keys here before any yielding payout.
 * Shops, contracts and research consume get_zone_permission(); imported knowledge never changes it.
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
	/// Back-room units bought this round. Keys are SKU typepaths.
	var/list/favor_unique_purchases = list()
	/// The crew's one number. It never spends or decays, and it is never copied to another crew.
	var/reputation = 0
	/// Immutable job and criminal receipt keys, shared by aliases of one settlement.
	var/list/settlement_claims = list()
	/// One suit and one gadget across all of the crew's hulls this round.
	var/mission_suit_paid = FALSE
	var/mission_gadget_paid = FALSE
	/// Experiment grants shared by every source disk, server and hull in this crew.
	var/list/research_reward_ledger = list()

/datum/voidcrew_crew_record/New()
	crew_id = ++GLOB.voidcrew_crew_serial
	GLOB.voidcrew_crew_records += src
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
				break
		break // Without a captain on the oldest hull, fall back to member join order.
	if(!leader && length(leadership_members))
		leader = leadership_members[1]
	if(leader && !QDELETED(src))
		var/leader_name = leader.current?.real_name || leader.name
		for(var/datum/mind/crewmate in minds)
			to_chat(crewmate.current, span_notice("[leader_name] now leads the crew."))

/// Round cleanup/admin disposal, not hull teardown. Never serialize these records.
/proc/clear_voidcrew_crew_records()
	for(var/datum/voidcrew_crew_record/record in GLOB.voidcrew_crew_records.Copy())
		qdel(record)
	GLOB.voidcrew_crew_roster.Cut()

/// Easy, medium and hard work pay the same on every board, repeated or not. Safe work pays as easy (safe_work).
/proc/zone_work_reward(difficulty)
	switch(difficulty)
		if(MISSION_DIFFICULTY_HARD)
			return REPUTATION_GAIN_HARD
		if(MISSION_DIFFICULTY_MEDIUM)
			return REPUTATION_GAIN_MEDIUM
	return REPUTATION_GAIN_EASY

/// The most work in this band can raise a crew to. Red has no ceiling; unknown bands earn nothing.
/proc/zone_reputation_ceiling(band)
	switch(band)
		if(ZONE_GREEN)
			return REPUTATION_STEP_YELLOW
		if(ZONE_YELLOW)
			return REPUTATION_STEP_ADVANCED
		if(ZONE_RED)
			return INFINITY
	return 0

/// The reputation a permission needs: the number in "Needs 11 reputation."
/proc/zone_permission_reputation(permission)
	switch(permission)
		if(ZONE_PERMISSION_YELLOW)
			return REPUTATION_STEP_YELLOW
		if(ZONE_PERMISSION_ADVANCED)
			return REPUTATION_STEP_ADVANCED
		if(ZONE_PERMISSION_ELITE)
			return REPUTATION_STEP_ELITE
	return 0

/// What the board headers show: the total and the next step, or null without a crew.
/proc/reputation_ui_data(datum/voidcrew_crew_record/crew)
	if(QDELETED(crew))
		return null
	return list("total" = crew.reputation, "next" = crew.next_reputation_step())

/// What a job of this band and difficulty would add right now. The one place the ceilings apply.
/datum/voidcrew_crew_record/proc/reputation_worth(band, difficulty)
	return max(0, min(zone_work_reward(difficulty), zone_reputation_ceiling(band) - reputation))

/// The next step to reach, or null past the last.
/datum/voidcrew_crew_record/proc/next_reputation_step()
	for(var/step in list(REPUTATION_STEP_YELLOW, REPUTATION_STEP_ADVANCED, REPUTATION_STEP_ELITE))
		if(reputation < step)
			return step
	return null

/// Returns credited points, claiming even work that earned nothing. Caller validates successful work.
/// No yield: simultaneous aliases cannot both claim. Never pass a proof object's ref as key.
/datum/voidcrew_crew_record/proc/claim_zone_work(band, difficulty, receipt_key)
	if(!(band in list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)) || !(difficulty in list(MISSION_DIFFICULTY_EASY, MISSION_DIFFICULTY_MEDIUM, MISSION_DIFFICULTY_HARD)) \
		|| !istext(receipt_key) || !length(receipt_key) || settlement_claims[receipt_key])
		return 0
	settlement_claims[receipt_key] = TRUE
	var/permission_before = get_zone_permission()
	var/gain = reputation_worth(band, difficulty)
	reputation += gain
	if(get_zone_permission() > permission_before)
		for(var/datum/mind/member in minds)
			to_chat(member.current, span_notice("Word's out about your crew. Better work is open to you."))
	return gain

/datum/voidcrew_crew_record/proc/get_zone_permission()
	if(reputation < REPUTATION_STEP_YELLOW)
		return ZONE_PERMISSION_PUBLIC
	if(reputation < REPUTATION_STEP_ADVANCED)
		return ZONE_PERMISSION_YELLOW
	if(reputation < REPUTATION_STEP_ELITE)
		return ZONE_PERMISSION_ADVANCED
	return ZONE_PERMISSION_ELITE

/datum/voidcrew_crew_record/proc/has_zone_permission(required_permission)
	return isnum(required_permission) && required_permission >= ZONE_PERMISSION_PUBLIC && required_permission <= get_zone_permission()

/// Unknown targeted bands fail closed. Targetless work never asks.
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
	return !length(teams) && !length(minds) && !length(ckeys) && !length(favor_unique_purchases) && !length(settlement_claims) \
		&& !reputation && !mission_suit_paid && !mission_gadget_paid && !length(research_reward_ledger)

/// How many units of `sku_type` this crew has bought off the back-room shelf
/datum/outpost_shop/proc/get_crew_purchases(obj/structure/overmap/ship/crew_ship, sku_type)
	var/datum/voidcrew_crew_record/record = crew_ship?.get_crew_record()
	return record?.favor_unique_purchases[sku_type] || 0

/**
 * # Back-room SKU base
 *
 * The back-room line item: gated by crew reputation, supplied per crew
 * rather than per shelf. Catalog files subtype this next to their other SKUs.
 */
/datum/shop_sku/favor
	category = "Back Room"
	crew_limit = FAVOR_UNIQUE_CREW_LIMIT
