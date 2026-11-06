/// Backgrounds: owned by P4.

/// Black Ledger missions. Abstract; weight stays 0 so the ordinary pool never rolls them.
/datum/mission/criminal
	name = "Job"
	desc = "Work off the books."
	weight = 0

/// Nobody signs their name on the Black Ledger: the board shows no "From:" line for an empty author
/datum/mission/criminal/generate_mission_author()
	return ""

/**
 * # Shakedown
 *
 * Take N credits off other ships. Any take completes it, but only what came off NPC hulls is
 * paid for (ECO-9): robbing a friend and handing the chips back must not mint a reward.
 */
/datum/mission/criminal/shakedown
	name = "Shakedown"
	desc = "Take credits off other ships."
	value_min = 900
	value_max = 1300
	/// Credits to take
	var/take_target = 0

/datum/mission/criminal/shakedown/start_mission(obj/structure/overmap/ship/ship)
	// One at a time: every live Shakedown hears the same take, so holding several would pay one take several times
	for(var/datum/mission/criminal/shakedown/running in ship?.active_missions)
		if(running != src && !QDELETED(running))
			return FALSE
	return ..()

/datum/mission/criminal/shakedown/generate_details()
	take_target = round(rand(BACKGROUND_SHAKEDOWN_TARGET_MIN, BACKGROUND_SHAKEDOWN_TARGET_MAX), 100)
	// No overmap target: the band the offer was posted in sets the pay (refresh_criminal_missions())
	apply_zone_scaling(preferred_zone || ZONE_YELLOW)

/datum/mission/criminal/shakedown/build_objectives()
	var/datum/mission_objective/background_take/take = new
	take.target_amount = take_target
	add_objective(take)

/datum/mission/criminal/shakedown/update_text()
	desc = "Take [pirate_credits_text(take_target)] cr off other ships."

/**
 * # Hijack
 *
 * A hauler carries a case marked for this job (hauler_mark_case(), the hauler package). Bring
 * that case to the pad. Honest work for a pirate: normal pay, scaled by the hauler's band.
 */
/datum/mission/criminal/hijack
	name = "Hijack"
	desc = "A Mule-class freighter is carrying a marked case. Bring it to your pad."
	objective_name = "marked case"
	gps_tag_prefix = "MULE"
	/// The case this job wants
	var/datum/weakref/marked_case_ref

/datum/mission/criminal/hijack/setup_target()
	var/obj/item/marked = hauler_mark_case(src)
	if(QDELETED(marked))
		return FALSE
	marked_case_ref = WEAKREF(marked)
	// Watched from the moment it is offered: a case lost with its hauler takes the job with it
	register_quest_atom(marked)
	return TRUE

/datum/mission/criminal/hijack/generate_details()
	var/obj/item/marked = marked_case_ref?.resolve()
	var/obj/structure/overmap/ship/carrier = marked ? get_ship_from_atom(marked) : null
	var/carrier_zone = carrier ? SSovermap_zones?.get_zone_type(get_turf(carrier)) : null
	apply_zone_scaling(carrier_zone || preferred_zone || ZONE_YELLOW)

/datum/mission/criminal/hijack/build_objectives()
	var/datum/mission_objective/deliver/bound/hijack/haul = new
	haul.case_ref = marked_case_ref
	add_objective(haul)

// =========================================================================
// OBJECTIVES
// =========================================================================

/**
 * Take credits off other ships, counted from COMSIG_BACKGROUND_CREDITS_TAKEN on the accepting ship
 * while this step is live. NPC and player takes are kept apart; both complete it, only NPC takes pay.
 */
/datum/mission_objective/background_take
	/// Credits to take
	var/target_amount = 0
	/// Taken off NPC hulls: this pays
	var/npc_taken = 0
	/// Taken off player hulls (or a hull that was gone before the link closed): completes, pays nothing
	var/player_taken = 0
	/// The ship listened on while live
	var/datum/weakref/watched_ref

/datum/mission_objective/background_take/generate()
	return target_amount > 0

/datum/mission_objective/background_take/activate()
	. = ..()
	var/obj/structure/overmap/ship/servant = get_servant()
	if(!servant)
		return
	watched_ref = WEAKREF(servant)
	RegisterSignal(servant, COMSIG_BACKGROUND_CREDITS_TAKEN, PROC_REF(on_credits_taken), override = TRUE)

/datum/mission_objective/background_take/deactivate()
	var/obj/structure/overmap/ship/watched = watched_ref?.resolve()
	if(watched)
		UnregisterSignal(watched, COMSIG_BACKGROUND_CREDITS_TAKEN)
	watched_ref = null
	return ..()

/datum/mission_objective/background_take/reset()
	. = ..()
	npc_taken = 0
	player_taken = 0

/datum/mission_objective/background_take/proc/on_credits_taken(obj/structure/overmap/ship/taker, obj/structure/overmap/ship/target, amount, source)
	SIGNAL_HANDLER
	if(completed || !isnum(amount) || amount <= 0)
		return
	if(istype(target, /obj/structure/overmap/ship/npc))
		npc_taken += amount
	else
		player_taken += amount
	if(npc_taken + player_taken >= target_amount)
		complete()

/datum/mission_objective/background_take/get_progress_string()
	return "Taken [pirate_credits_text(min(npc_taken + player_taken, target_amount))] of [pirate_credits_text(target_amount)] cr"

/// ECO-9: the pay is the share of the take that came off NPC hulls
/datum/mission_objective/background_take/on_turn_in_finalized(atom/reward_anchor)
	if(!mission || target_amount <= 0)
		return
	mission.value = round(mission.value * min(1, npc_taken / target_amount))

/// The one case a Hijack was posted for
/datum/mission_objective/deliver/bound/hijack
	required_name = "marked case"
	/// The case
	var/datum/weakref/case_ref

/datum/mission_objective/deliver/bound/hijack/describe_ask()
	return required_name

/datum/mission_objective/deliver/bound/hijack/get_progress_string()
	return "Bring the marked case to the pad"

/datum/mission_objective/deliver/bound/hijack/can_turn_in(obj/item/item)
	return !isnull(item) && item == case_ref?.resolve()

/datum/mission_objective/deliver/bound/hijack/matches_ask(obj/item/item)
	return can_turn_in(item)

/datum/mission_objective/deliver/bound/hijack/describe_turn_in_failure(obj/item/item)
	if(!item)
		return "No item provided."
	return "That isn't the marked case."
