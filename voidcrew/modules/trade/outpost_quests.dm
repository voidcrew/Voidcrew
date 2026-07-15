/**
 * # Outpost Contracts — the trader-authored quest archetypes
 *
 * The contract board's real content (outpost_missions.dm holds the board
 * machinery and the procurement/supply archetype). Everything here is
 * shop-authored: weight = 0 (never rolled by SSmissions), posted by an
 * outpost, and speaking in its trader's voice.
 *
 * - Salvage Order  — recovery contract on a ruin, trader flavor
 * - Kill Contract  — proof-of-kill on a named ruin target, trader flavor
 * - Courier Run    — haul a sealed freight pod to ANOTHER outpost; the pod
 *   only unloads at its destination trader (piracy bait by design)
 *
 * Hard contracts can roll the shop's exclusive_rewards — items no shelf sells.
 */

// ===== SALVAGE ORDER (outpost-authored recovery) =====

/datum/mission/recovery/outpost
	weight = 0 // board-posted only
	mission_limit = 0

/datum/mission/recovery/outpost/generate_mission_details()
	if(!shop)
		generation_failed = TRUE
		return
	author = shop.trader_name
	. = ..()
	if(generation_failed)
		return
	// Board contracts pay in goods, not money — the open market covers credits/vouchers
	value = 0
	value_min = 0
	value_max = 0
	voucher_count = 0
	if(!shop.roll_contract_reward(src))
		generation_failed = TRUE
		return
	update_text()

/datum/mission/recovery/outpost/update_text()
	var/reward_name = get_reward_summary()
	name = "Salvage Order: [objective_name]"
	desc = "[author] of [shop?.outpost_name || "the outpost"] is paying for the [objective_name] out at ([target_x], [target_y]) in the [target_zone_name]. \
		Deliver it to any outpost trader or your own mission pad. \
		Pays in kit — [reward_name], no credits changing hands. \
		Tap a GPS unit on a mission board to receive the objective's beacon ([gps_tag])."

/datum/mission/recovery/outpost/get_archetype()
	return "salvage"

// ===== KILL CONTRACT (outpost-authored proof-of-kill) =====

/datum/mission/recovery/kill/outpost
	weight = 0
	mission_limit = 0

/datum/mission/recovery/kill/outpost/generate_mission_details()
	if(!shop)
		generation_failed = TRUE
		return
	author = shop.trader_name
	. = ..()
	if(generation_failed)
		return
	// Board contracts pay in goods, not money — the open market covers credits/vouchers
	value = 0
	value_min = 0
	value_max = 0
	voucher_count = 0
	if(!shop.roll_contract_reward(src))
		generation_failed = TRUE
		return
	update_text()

/datum/mission/recovery/kill/outpost/update_text()
	var/reward_name = get_reward_summary()
	name = "Kill Contract: [objective_name]"
	desc = "[author] of [shop?.outpost_name || "the outpost"] wants [objective_name] gone — holed up at ([target_x], [target_y]) in the [target_zone_name]. \
		Bring the identification tag to any outpost trader or your own mission pad. \
		Pays in goods — [reward_name], settled on delivery. \
		Tap a GPS unit on a mission board for the target's transponder ([gps_tag])."

/datum/mission/recovery/kill/outpost/get_archetype()
	return "bounty"

// ===== COURIER RUN =====

/datum/mission/outpost_courier
	name = "Courier Run"
	desc = "Haul a sealed pod between outposts."
	weight = 0
	requires_item = TRUE
	duration = 35 MINUTES

	/// Where the pod must go
	var/obj/structure/overmap/trader_outpost/destination
	/// Relative overmap coordinates of the destination (cached for display)
	var/target_x = 0
	var/target_y = 0
	/// Display name of the destination's zone at generation time
	var/target_zone_name = "Unknown Zone"
	/// The sealed pod being hauled (spawned on accept)
	var/obj/item/freight_pod/pod

/datum/mission/outpost_courier/Destroy()
	if(pod)
		UnregisterSignal(pod, COMSIG_QDELETING)
		pod = null
	destination = null
	return ..()

/datum/mission/outpost_courier/generate_mission_details()
	if(!shop?.outpost)
		generation_failed = TRUE
		return
	author = shop.trader_name

	var/list/candidates = list()
	for(var/obj/structure/overmap/trader_outpost/other as anything in GLOB.trader_outposts)
		if(QDELETED(other) || other == shop.outpost)
			continue
		candidates += other
	if(!length(candidates))
		generation_failed = TRUE
		return
	destination = pick(candidates)
	target_x = destination.x
	target_y = destination.y - OVERMAP_SOUTH_SIDE_COORD + 1

	// Difficulty follows the destination's zone — deeper runs pay richer goods
	var/zone_type = SSovermap_zones?.get_zone_type(get_turf(destination)) || ZONE_GREEN
	switch(zone_type)
		if(ZONE_GREEN)
			target_zone_name = ZONE_NAME_GREEN
			difficulty = MISSION_DIFFICULTY_EASY
		if(ZONE_YELLOW)
			target_zone_name = ZONE_NAME_YELLOW
			difficulty = MISSION_DIFFICULTY_MEDIUM
		if(ZONE_RED)
			target_zone_name = ZONE_NAME_RED
			difficulty = MISSION_DIFFICULTY_HARD

	// Board contracts pay in goods, not money — the open market covers credits/vouchers
	value_min = 0
	value_max = 0
	voucher_count = 0
	if(!shop.roll_contract_reward(src))
		generation_failed = TRUE
		return

	. = ..()
	var/reward_name = get_reward_summary()
	name = "Courier Run: [destination.name]"
	desc = "[author] needs a sealed freight pod hauled to [destination.name] at ([target_x], [target_y]) in the [target_zone_name]. \
		The pod's seals only release at the destination's trader — and every pirate on the lane knows what a courier pod looks like. \
		Pays in kit on delivery: [reward_name]."

/datum/mission/outpost_courier/get_archetype()
	return "courier"

/datum/mission/outpost_courier/get_waypoint_info()
	return list("Courier: [destination?.name || "lost destination"]", target_x, target_y)

/datum/mission/outpost_courier/start_mission(obj/structure/overmap/ship/ship)
	if(QDELETED(destination))
		return FALSE
	. = ..()
	if(!.)
		return FALSE
	// The pod materializes at the posting trader's feet — you accepted in person
	var/turf/pod_turf
	if(shop?.outpost?.trader)
		pod_turf = get_turf(shop.outpost.trader)
	if(!pod_turf)
		pod_turf = get_turf(ship.shuttle) // desperation fallback; should not happen
	if(!pod_turf)
		fail("Freight pod could not be dispensed.")
		return FALSE
	pod = new(pod_turf)
	pod.name = "sealed freight pod ([shop.outpost_name] → [destination.name])"
	pod.mission_ref = WEAKREF(src)
	RegisterSignal(pod, COMSIG_QDELETING, PROC_REF(on_pod_destroyed))
	servant?.ship_notify("Freight pod handed over at [shop.outpost_name]. Deliver it to [destination.name] ([target_x], [target_y]).", "COURIER RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	return TRUE

/datum/mission/outpost_courier/proc/on_pod_destroyed(datum/source)
	SIGNAL_HANDLER
	pod = null
	if(completed || failed)
		return
	fail("Freight pod destroyed — contract void.")

/datum/mission/outpost_courier/can_turn_in(obj/item/item)
	if(failed || completed)
		return FALSE
	if(!istype(item, /obj/item/freight_pod))
		return FALSE
	var/obj/item/freight_pod/offered = item
	return offered.mission_ref?.resolve() == src

/datum/mission/outpost_courier/can_turn_in_at(atom/reward_anchor)
	if(!istype(reward_anchor, /mob/living/basic/outpost_trader))
		return FALSE
	var/mob/living/basic/outpost_trader/npc = reward_anchor
	return npc.outpost == destination

/datum/mission/outpost_courier/get_wrong_location_reason(atom/reward_anchor)
	return "The pod's seals only release at [destination?.name || "its destination"]'s trader."

/datum/mission/outpost_courier/get_failure_reason(obj/item/item)
	if(failed)
		return "Mission already failed."
	if(completed)
		return "Mission already completed."
	if(!item)
		return "No item provided."
	if(!istype(item, /obj/item/freight_pod))
		return "Wrong item type."
	var/obj/item/freight_pod/offered = item
	if(offered.mission_ref?.resolve() != src)
		return "That pod belongs to a different contract."
	return ..()

/datum/mission/outpost_courier/consume_turned_in_item(obj/item/item)
	if(item == pod)
		UnregisterSignal(pod, COMSIG_QDELETING)
		pod = null
	return ..()

/datum/mission/outpost_courier/get_progress_string()
	if(!pod)
		return "Pod waiting with the posting trader"
	return "Deliver the pod to [destination?.name || "the destination"] ([target_x], [target_y])"

/**
 * # Sealed Freight Pod
 *
 * The courier cargo: too big for a bag, visibly a courier pod, and worth
 * vouchers to whoever delivers it — the mission doesn't care who's carrying.
 */
/obj/item/freight_pod
	name = "sealed freight pod"
	desc = "A tamper-sealed courier pod, bonded and manifest-locked. The seals only release at its destination outpost's contract board."
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "blackcube"
	inhand_icon_state = "blackcube"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	color = "#c9a54a" // bonded-courier gold, until it gets its own sprite
	w_class = WEIGHT_CLASS_HUGE // never disappears into a backpack
	throw_range = 3
	throw_speed = 1

	/// Weakref to the courier mission this pod satisfies
	var/datum/weakref/mission_ref

/obj/item/freight_pod/examine(mob/user)
	. = ..()
	var/datum/mission/outpost_courier/mission = mission_ref?.resolve()
	if(mission && !mission.failed && !mission.completed)
		. += span_notice("The manifest reads: deliver to <b>[mission.destination?.name || "unknown"]</b>. Whoever delivers it, gets paid.")
	else
		. += span_warning("Its contract has lapsed; the seals will never release.")
