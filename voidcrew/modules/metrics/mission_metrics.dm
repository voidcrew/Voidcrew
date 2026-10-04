// Round metrics for the mission board and outpost contracts.
// See voidcrew/modules/metrics/metrics_helpers.dm for record_metric() and tally_metric().
//
// Every row here is category METRIC_MISSION. Unless an entry says otherwise, `subject` is the
// mission's typepath, `zone` is the zone of the mission's target (the ruin, planet, coordinates
// or destination outpost; null for missions with no target), and the ship is the crew that took
// the job. Outpost contracts are /datum/mission subtypes too, so they share these events; their
// rows carry board = "outpost" plus the outpost and trader names.
//
// EVENT CATALOG
//
// mission_accepted - a crew takes a mission from its board, or a contract from an outpost
//     trader. Hook: /datum/mission/start_mission().
//     ckey: the player who accepted. details: board ("ship" or "outpost"), difficulty,
//     archetype, offer (credits offered), vouchers, research, item_value (outpost contracts),
//     outpost, trader, limit_s (the time limit in seconds).
// mission_completed - the mission paid out. Hook: /datum/mission/finish_mission().
//     ckey: the player who turned it in. credits: paid into the ship account. vouchers: trade
//     vouchers paid. points: research points on the dossier paid. quantity: item rewards
//     spawned. details: board, difficulty, archetype, seconds (accept to finish), accepted_by
//     (when someone else accepted), items (typepath -> units), ship_parts (typepath -> count,
//     prospect stakes), item_value (outpost contracts: what the item bundle sells for at the
//     posting shop), total_value (credits + item_value + vouchers at VOUCHER_CREDIT_VALUE;
//     research and favor not included), favor (standing gained with the posting trader),
//     outpost, trader, retargets (used), purity (drug runs).
// mission_failed - the mission failed: its objective was lost, destroyed or stranded, or the
//     contract was voided. Hook: /datum/mission/fail(). ckey: the player who accepted it.
//     details: board, difficulty, archetype, seconds, reason.
// mission_expired - the mission's time limit ran out. Same hook and columns as mission_failed,
//     without a reason.
// mission_dropped - an accepted mission was deleted without finishing, almost always because
//     the crew's ship was destroyed or despawned. Hook: /datum/mission/Destroy(). The ship
//     columns are the ones it had when the mission was accepted. ckey: the player who accepted
//     it. details: board, difficulty, archetype, seconds.
// mission_offered (tally) - offers rolled onto a ship's mission board. ship: the board's ship.
//     quantity: offers. Hooks: SSmissions.refresh_ship_missions() and
//     ensure_safe_exploration_offer().
// mission_offer_expired (tally) - board offers nobody took, rotated off after
//     MISSION_BOARD_EXPIRY. ship: the board's ship. quantity: offers.
// contract_offered (tally) - contracts posted on an outpost trader's board, including the
//     refill after one is taken. No ship. quantity: offers.
//     Hook: /obj/structure/overmap/trader_outpost/ensure_shop_offers().
// board_refreshed - a crew rerolled its mission board. ckey, ship. quantity: offers thrown
//     away. Hook: the mission board's "refresh" action.
// pirate_bounty_accepted - a crew took a bounty on an NPC pirate ship from its mission board.
//     ckey, ship. subject: the pirate ship's typepath. zone: where the pirate is.
//     details: reward, heavy.
// pirate_bounty_cancelled - a crew gave up a pirate bounty. Same columns.
// pirate_bounty_completed - a crew turned in the pirate's key. credits: paid (after the
//     tracking cut). zone: the pirate's, while its ship still exists. details: reward (before
//     the cut), tracked, heavy.
// player_bounty_posted - a crew posted a bounty for other crews. ckey, ship: the poster.
//     credits: minus the reward, held in escrow. details: name.
// player_bounty_paid - the poster approved an offer and paid. ship: the crew that was paid.
//     other_ckey: the player who approved. credits: the reward. quantity: items delivered.
//     details: name, poster_ship.
// player_bounty_cancelled - a posted player bounty was withdrawn, or dropped because its
//     poster's ship is gone. ship: the poster. credits: the refund, if one was paid.
//     details: name.

/datum/mission
	/// ckey of the player who accepted this mission
	var/metric_accepted_by
	/// ship_id, ship_name and ship_class when the mission was accepted, for rows written while
	/// the ship itself is being deleted
	var/list/metric_ship_fields
	/// Outpost contracts: what the item bundle sells for at the posting shop, priced when the
	/// contract was posted. The shelves rotate, so pricing it later can miss.
	var/metric_item_value = 0
	/// Ship parts paid on completion, typepath -> count
	var/list/metric_ship_parts

/datum/player_bounty
	/// TRUE once player_bounty_posted was written, so a bounty whose setup failed and was
	/// refunded straight away writes neither the post nor the refund
	var/metric_posted = FALSE

/// The ckey of the player whose action is running this proc chain. Only trust it on paths that
/// start with a player's click or UI action; timers and subsystems have no usr.
/proc/metric_acting_ckey()
	return ismob(usr) ? metric_ckey(usr) : null

/// The zone name of an overmap object's tile (a ship, planet or outpost token), or null.
/proc/metric_overmap_tile_zone(atom/movable/overmap_object)
	if(!overmap_object)
		return null
	return metric_zone_name(SSovermap_zones?.get_zone_type(get_turf(overmap_object)))

/// The zone name of this mission's target, or null when it has none.
/datum/mission/proc/metric_target_zone()
	var/zone_type = target?.get_zone_type()
	if(!isnull(zone_type))
		return metric_zone_name(zone_type)
	switch(target_zone_name)
		if(ZONE_NAME_GREEN)
			return "green"
		if(ZONE_NAME_YELLOW)
			return "yellow"
		if(ZONE_NAME_RED)
			return "red"
	return null

/// Seconds since the mission was accepted, or null if it never was.
/datum/mission/proc/metric_seconds_active()
	if(!time_started)
		return null
	return round((world.time - time_started) / 10)

/// Details every lifecycle row shares.
/datum/mission/proc/metric_base_details()
	var/list/details = list(
		"board" = shop ? "outpost" : "ship",
		"difficulty" = get_difficulty_name(),
		"archetype" = get_archetype(),
	)
	if(shop)
		details["outpost"] = shop.outpost_name
		details["trader"] = shop.trader_name
	return details

/// Extra details for a completed mission of this type. Subtypes add their own.
/datum/mission/proc/metric_completion_details(list/details)
	return

/datum/mission/drug_run/metric_completion_details(list/details)
	details["purity"] = purity_tier

/**
 * Queues one METRIC_MISSION row about this mission. Rows written while the ship is being
 * deleted keep the ship columns from when the mission was accepted, so they still join
 * against that ship's other rows.
 */
/datum/mission/proc/record_mission_metric(event, ckey, credits = 0, vouchers = 0, points = 0, quantity = 0, list/details)
	if(!SSmetrics.accepting)
		return
	var/obj/structure/overmap/ship/ship = QDELETED(servant) ? null : servant
	var/list/row = SSmetrics.build_row(METRIC_MISSION, event, ckey, null, ship, metric_target_zone(), type, credits, vouchers, points, quantity, details)
	if(!ship && metric_ship_fields)
		row["ship_id"] = metric_ship_fields["ship_id"]
		row["ship_name"] = metric_ship_fields["ship_name"]
		row["ship_class"] = metric_ship_fields["ship_class"]
	SSmetrics.queue_row(row)

/**
 * Prices an outpost contract's item bundle at its posting shop the way
 * /datum/outpost_shop/proc/roll_contract_reward() priced it: each shelf item at its SKU value,
 * a back-room prize at CONTRACT_EXCLUSIVE_VALUE. Called once, when the contract is generated.
 */
/datum/mission/proc/note_metric_item_value()
	if(!shop || !SSmetrics.accepting)
		return
	var/list/reward_types = get_reward_types()
	if(!length(reward_types))
		return
	var/list/sku_values = list()
	for(var/datum/shop_sku/sku as anything in shop.skus)
		if(!sku.item_path || sku.shelf == SHELF_FAVOR)
			continue
		sku_values[sku.item_path] = shop.get_sku_value(sku)
	var/total = 0
	for(var/reward_type in reward_types)
		if(reward_type in rare_reward_types)
			total += CONTRACT_EXCLUSIVE_VALUE
		else
			total += sku_values[reward_type] || 0
	metric_item_value = total

/// Remembers the ship parts in a prize crate this mission just paid.
/datum/mission/proc/note_metric_ship_parts(obj/structure/closet/crate/prize)
	if(!prize || !SSmetrics.accepting)
		return
	for(var/obj/item/ship_parts/part in prize)
		LAZYINITLIST(metric_ship_parts)
		metric_ship_parts["[part.type]"] += 1

/// mission_accepted. Called from start_mission() once the mission is live.
/datum/mission/proc/record_metric_accepted()
	if(!SSmetrics.accepting)
		return
	metric_accepted_by = metric_acting_ckey()
	if(servant)
		var/list/ship_row = SSmetrics.build_row(METRIC_MISSION, null, null, null, servant, null, null, 0, 0, 0, 0, null)
		metric_ship_fields = list(
			"ship_id" = ship_row["ship_id"],
			"ship_name" = ship_row["ship_name"],
			"ship_class" = ship_row["ship_class"],
		)
	var/list/details = metric_base_details()
	details["offer"] = value
	details["limit_s"] = round(duration / 10)
	if(voucher_count > 0)
		details["vouchers"] = voucher_count
	if(research_reward > 0)
		details["research"] = research_reward
	if(metric_item_value > 0)
		details["item_value"] = metric_item_value
	record_mission_metric("mission_accepted", metric_accepted_by, details = details)

/**
 * mission_completed. Called from finish_mission() after the rewards are paid, so it reads
 * what was actually paid (an escort's unharmed bonus, a drug run's purity) rather than the
 * offer. Mirrors distribute_rewards(): no ship means nothing is paid, and goods only spawn
 * where the turn-in point has a turf.
 */
/datum/mission/proc/record_metric_completed(atom/reward_anchor, favor_gain)
	if(!SSmetrics.accepting)
		return
	var/paid_goods = servant && get_turf(reward_anchor)
	var/paid_credits = (servant?.ship_account && value > 0) ? value : 0
	var/paid_vouchers = (paid_goods && voucher_count > 0) ? voucher_count : 0
	var/paid_points = (paid_goods && research_reward > 0) ? research_reward : 0
	var/favor = (favor_gain > 0 && servant && shop) ? favor_gain : 0

	var/list/items
	var/item_count = 0
	if(paid_goods)
		for(var/reward_type in get_reward_types())
			var/units = 1
			var/stack_amount = LAZYACCESS(reward_amounts, reward_type)
			if(stack_amount > 1 && ispath(reward_type, /obj/item/stack))
				units = stack_amount
			LAZYINITLIST(items)
			items["[reward_type]"] += units
			item_count++

	var/list/details = metric_base_details()
	details["seconds"] = metric_seconds_active()
	var/turned_in_by = metric_acting_ckey() || metric_accepted_by
	if(metric_accepted_by && metric_accepted_by != turned_in_by)
		details["accepted_by"] = metric_accepted_by
	if(items)
		details["items"] = items
	if(metric_ship_parts)
		details["ship_parts"] = metric_ship_parts
	var/item_value = paid_goods ? metric_item_value : 0
	if(item_value > 0)
		details["item_value"] = item_value
	details["total_value"] = paid_credits + item_value + paid_vouchers * VOUCHER_CREDIT_VALUE
	if(favor)
		details["favor"] = favor
	var/retargets_used = MAX_MISSION_RETARGETS - retargets_left
	if(retargets_used > 0)
		details["retargets"] = retargets_used
	metric_completion_details(details)
	record_mission_metric("mission_completed", turned_in_by, paid_credits, paid_vouchers, paid_points, item_count, details)

/**
 * mission_failed or mission_expired. Called from fail() before any state changes. Offers that
 * die on the board were never accepted and write nothing. on_timeout() clears timeout_timer
 * before it calls fail(), and nothing else leaves it empty on a live mission, which is how a
 * timeout is told apart from any other failure.
 */
/datum/mission/proc/record_metric_failed(reason)
	if(!SSmetrics.accepting || !time_started)
		return
	var/timed_out = active && isnull(timeout_timer)
	var/list/details = metric_base_details()
	details["seconds"] = metric_seconds_active()
	if(!timed_out)
		details["reason"] = reason
	record_mission_metric(timed_out ? "mission_expired" : "mission_failed", metric_accepted_by, details = details)

/// mission_dropped. Called from Destroy(); only an accepted mission that never finished counts.
/datum/mission/proc/record_metric_dropped()
	if(!SSmetrics.accepting || !active || failed || completed)
		return
	var/list/details = metric_base_details()
	details["seconds"] = metric_seconds_active()
	record_mission_metric("mission_dropped", metric_accepted_by, details = details)

/**
 * Counts an offer posted to (or rotated off) a board: one tally row per type, zone and board
 * a minute. `ship` is the board's ship, or null for an outpost trader's board.
 */
/proc/tally_mission_offer(datum/mission/offer, obj/structure/overmap/ship/ship, event)
	if(!SSmetrics.accepting || QDELETED(offer))
		return
	tally_metric(METRIC_MISSION, event, ship = ship, zone = offer.metric_target_zone(), subject = offer.type)

/// board_refreshed. Called before the board is cleared, so the count is what was thrown away.
/proc/record_mission_board_refreshed(obj/structure/overmap/ship/ship, mob/user)
	if(!SSmetrics.accepting || !ship)
		return
	record_metric(METRIC_MISSION, "board_refreshed", ship = ship, quantity = length(ship.available_missions), actor = user)

/// pirate_bounty_accepted, pirate_bounty_cancelled and pirate_bounty_completed.
/proc/record_pirate_bounty_metric(event, datum/pirate_bounty/bounty, obj/structure/overmap/ship/ship, mob/user, paid = 0)
	if(!SSmetrics.accepting || !bounty)
		return
	var/list/details = list("reward" = bounty.reward)
	if(bounty.is_heavy_bounty)
		details["heavy"] = TRUE
	if(paid > 0 && paid < bounty.reward)
		details["tracked"] = TRUE
	// The zone is the pirate's, not the crew's. A dead pirate has none.
	record_metric(METRIC_MISSION, event, ckey = metric_ckey(user), ship = ship, zone = metric_overmap_tile_zone(bounty.get_target_ship()), subject = bounty.ship_type_path, credits = paid, details = details)

/// player_bounty_posted. Called once the bounty is set up; the reward has already left the
/// poster's account for escrow.
/proc/record_player_bounty_posted(datum/player_bounty/bounty, obj/structure/overmap/ship/ship, mob/user)
	if(!SSmetrics.accepting || !bounty)
		return
	bounty.metric_posted = TRUE
	record_metric(METRIC_MISSION, "player_bounty_posted", ship = ship, credits = -bounty.reward, details = list("name" = bounty.name), actor = user)

/// player_bounty_paid. Called from approve_offer() once the reward is paid.
/datum/player_bounty/proc/record_metric_paid(obj/structure/overmap/ship/paid_ship, items_sent)
	if(!SSmetrics.accepting)
		return
	var/obj/structure/overmap/ship/poster = get_creator_ship()
	var/list/details = list("name" = name)
	if(poster)
		details["poster_ship"] = poster.name
	record_metric(METRIC_MISSION, "player_bounty_paid", other_ckey = metric_acting_ckey(), ship = paid_ship, zone = metric_overmap_tile_zone(paid_ship), credits = reward, quantity = items_sent, details = details)

/// player_bounty_cancelled. Called from cancel() before the status changes, so it knows
/// whether the reward goes back. No ckey: the board's UI refresh also cancels bounties whose
/// poster is gone, with whoever happened to be looking as usr.
/datum/player_bounty/proc/record_metric_cancelled()
	if(!SSmetrics.accepting || !metric_posted || status != "available")
		return
	var/obj/structure/overmap/ship/poster = get_creator_ship()
	record_metric(METRIC_MISSION, "player_bounty_cancelled", ship = poster, zone = metric_overmap_tile_zone(poster), credits = poster ? reward : 0, details = list("name" = name))
