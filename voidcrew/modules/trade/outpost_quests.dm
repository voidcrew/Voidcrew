/**
 * # Outpost Contracts: the trader-authored quest archetypes
 *
 * The contract board's real content (outpost_missions.dm holds the board
 * machinery and the procurement/supply archetype). Everything here is
 * shop-authored: weight = 0 (never rolled by SSmissions), posted by an
 * outpost, and speaking in its trader's voice.
 *
 * - Salvage Order: recovery contract on a ruin, trader flavor
 * - Kill Contract: proof-of-kill on a named ruin target, trader flavor
 * - Courier Run: haul a sealed freight pod to ANOTHER outpost; the pod
 *   only unloads at its destination trader (piracy bait by design)
 *
 * Hard contracts can roll the shop's exclusive_rewards. Items no shelf sells.
 */

// ===== SALVAGE ORDER (outpost-authored recovery) =====

/datum/mission/recovery/outpost
	weight = 0 // board-posted only
	mission_limit = 0
	contract_pay_mult = 1.25 // a run out to a ruin and back

/datum/mission/recovery/outpost/generate_details()
	if(!shop)
		generation_failed = TRUE
		return
	author = shop.trader_name
	..()
	// Board contracts pay in goods, not money. The open market covers credits/vouchers
	value = 0
	value_min = 0
	value_max = 0
	voucher_count = 0
	if(!shop.roll_contract_reward(src))
		generation_failed = TRUE

/datum/mission/recovery/outpost/update_text()
	var/reward_name = get_contract_pay_summary()
	name = "Salvage Order: [objective_name]"
	desc = "[author] of [shop?.outpost_name || "the outpost"] is paying for the [objective_name] out at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		Deliver it to any outpost trader or your own mission pad. \
		Pays in kit, [reward_name], no credits changing hands. \
		Tap a GPS unit on a mission board to receive the objective's beacon ([gps_tag])."

/datum/mission/recovery/outpost/get_archetype()
	return "salvage"

// ===== KILL CONTRACT (outpost-authored proof-of-kill) =====

/datum/mission/recovery/kill/outpost
	weight = 0
	mission_limit = 0
	contract_pay_mult = 1.5 // find a named boss at a hostile site and put it down

/datum/mission/recovery/kill/outpost/generate_details()
	if(!shop)
		generation_failed = TRUE
		return
	author = shop.trader_name
	..()
	// Board contracts pay in goods, not money. The open market covers credits/vouchers
	value = 0
	value_min = 0
	value_max = 0
	voucher_count = 0
	if(!shop.roll_contract_reward(src))
		generation_failed = TRUE

/datum/mission/recovery/kill/outpost/update_text()
	var/reward_name = get_contract_pay_summary()
	name = "Kill Contract: [objective_name]"
	desc = "[author] of [shop?.outpost_name || "the outpost"] wants [objective_name] gone, holed up at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		Bring the identification tag to any outpost trader or your own mission pad. \
		Pays in goods, [reward_name], settled on delivery. \
		Tap a GPS unit on a mission board for the target's transponder ([gps_tag])."

/datum/mission/recovery/kill/outpost/get_archetype()
	return "bounty"

// ===== COURIER RUN =====

/datum/mission/outpost_courier
	name = "Courier Run"
	weight = 0
	duration = 35 MINUTES
	value_min = 0
	value_max = 0
	contract_pay_mult = 1.3 // a long haul across the lanes, and pirates know the pod
	quest_lost_policy = MISSION_QUEST_LOST_FAIL // pod destroyed = contract void

	/// The pod-delivery objective (holds the live pod)
	var/datum/mission_objective/deliver/courier_pod/haul

/datum/mission/outpost_courier/Destroy()
	haul = null
	return ..()

/datum/mission/outpost_courier/get_archetype()
	return "courier"

/datum/mission/outpost_courier/setup_target()
	if(!shop?.outpost)
		return FALSE
	var/datum/mission_target/outpost/destination = new(src)
	destination.exclude = shop.outpost
	if(!destination.resolve())
		qdel(destination)
		return FALSE
	target = destination
	return TRUE

/datum/mission/outpost_courier/generate_details()
	author = shop.trader_name
	// Board contracts pay in goods, not money
	voucher_count = 0
	if(!shop.roll_contract_reward(src))
		generation_failed = TRUE

/datum/mission/outpost_courier/build_objectives()
	haul = new
	add_objective(haul)

/// The destination outpost overmap object, or null
/datum/mission/outpost_courier/proc/get_destination()
	var/datum/mission_target/outpost/destination = target
	return istype(destination) ? destination.outpost : null

/datum/mission/outpost_courier/update_text()
	var/reward_name = get_contract_pay_summary()
	var/obj/structure/overmap/trader_outpost/destination = get_destination()
	name = "Courier Run: [destination?.name || "lost destination"]"
	desc = "[author] needs a sealed freight pod hauled to [destination?.name || "its destination"] at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		Collect the pod beside [author] when you accept. \
		The pod's seals only release at the destination's trader, and every pirate on the lane knows what a courier pod looks like. \
		Pays in kit on delivery: [reward_name]."

/datum/mission/outpost_courier/waypoint_label()
	var/obj/structure/overmap/trader_outpost/destination = get_destination()
	return "Courier: [destination?.name || "lost destination"]"

/datum/mission/outpost_courier/on_mission_started()
	// The pod materializes at the posting trader's feet, you accepted in person
	var/turf/pod_turf
	if(shop?.outpost?.trader)
		pod_turf = get_turf(shop.outpost.trader)
	if(!pod_turf)
		pod_turf = get_turf(servant.shuttle) // desperation fallback; should not happen
	if(!pod_turf)
		fail("Freight pod could not be dispensed.")
		return
	var/obj/structure/overmap/trader_outpost/destination = get_destination()
	var/obj/item/freight_pod/pod = new(pod_turf)
	pod.name = "sealed freight pod ([shop.outpost_name] → [destination?.name || "unknown"])"
	bind_item(pod)
	register_quest_atom(pod)
	haul.pod = pod
	servant?.ship_notify("Freight pod handed over at [shop.outpost_name]. Deliver it to [destination?.name || "the destination"] ([target.target_x], [target.target_y]).", "COURIER RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/datum/mission/outpost_courier/handle_quest_loss(reason)
	return ..("Freight pod destroyed, contract void.")

/datum/mission/outpost_courier/can_turn_in_at(atom/reward_anchor)
	if(!istype(reward_anchor, /mob/living/basic/outpost_trader))
		return FALSE
	var/mob/living/basic/outpost_trader/npc = reward_anchor
	return npc.outpost == get_destination()

/datum/mission/outpost_courier/get_wrong_location_reason(atom/reward_anchor)
	var/obj/structure/overmap/trader_outpost/destination = get_destination()
	return "The pod's seals only release at [destination?.name || "its destination"]'s trader."

/**
 * # Courier Pod Objective
 *
 * The deliver step for courier runs: only this run's bound pod counts, and
 * the mission's can_turn_in_at() already gates WHERE it opens.
 */
/datum/mission_objective/deliver/courier_pod
	required_name = "the sealed freight pod"
	/// The live pod (spawned by the mission at start)
	var/obj/item/freight_pod/pod

/datum/mission_objective/deliver/courier_pod/deactivate()
	pod = null
	return ..()

/datum/mission_objective/deliver/courier_pod/can_turn_in(obj/item/item)
	if(!istype(item, /obj/item/freight_pod))
		return FALSE
	var/obj/item/freight_pod/offered = item
	return offered.mission_ref?.resolve() == mission

/datum/mission_objective/deliver/courier_pod/matches_ask(obj/item/item)
	return istype(item, /obj/item/freight_pod)

/datum/mission_objective/deliver/courier_pod/describe_turn_in_failure(obj/item/item)
	if(!item)
		return "No item provided."
	if(!istype(item, /obj/item/freight_pod))
		return "Wrong item type."
	var/obj/item/freight_pod/offered = item
	if(offered.mission_ref?.resolve() != mission)
		return "That pod belongs to a different contract."
	return ..()

/datum/mission_objective/deliver/courier_pod/accept_item(obj/item/item, atom/reward_anchor)
	if(item == pod)
		mission.forget_quest_atom(item) // consuming the pod isn't losing it
		pod = null
	return ..()

/datum/mission_objective/deliver/courier_pod/get_progress_string()
	if(!pod)
		return "Pod waiting with the posting trader"
	var/datum/mission_target/target = mission?.target
	return "Deliver the pod to its destination ([target?.target_x], [target?.target_y])"

/**
 * # Sealed Freight Pod
 *
 * The courier cargo: too big for a bag, visibly a courier pod, and worth
 * goods to whoever delivers it. The mission doesn't care who's carrying.
 */
/obj/item/freight_pod
	name = "sealed freight pod"
	desc = "A tamper-sealed courier pod, bonded and manifest-locked. The seals only release at its destination outpost's contract board."
	icon = 'voidcrew/modules/trade/icons/trade.dmi'
	icon_state = "freight_pod"
	inhand_icon_state = "freight_pod"
	lefthand_file = 'voidcrew/modules/trade/icons/freight_lefthand.dmi'
	righthand_file = 'voidcrew/modules/trade/icons/freight_righthand.dmi'
	w_class = WEIGHT_CLASS_HUGE // never disappears into a backpack
	throw_range = 3
	throw_speed = 1

	/// Weakref to the courier mission this pod satisfies
	var/datum/weakref/mission_ref

/obj/item/freight_pod/examine(mob/user)
	. = ..()
	var/datum/mission/outpost_courier/mission = mission_ref?.resolve()
	if(istype(mission) && !mission.failed && !mission.completed)
		var/obj/structure/overmap/trader_outpost/destination = mission.get_destination()
		. += span_notice("The manifest reads: deliver to <b>[destination?.name || "unknown"]</b>. Whoever hands it over gets paid.")
	else
		. += span_warning("Its contract has lapsed; the seals will never release.")
