/**
 * # Finishers: who does them, and the AI that picks a victim
 *
 * A mob gets a finisher with AddComponent(/datum/component/hv_finisher_user, finisher_type). The
 * component grants the mob an ability with no button (only its AI uses it), puts the ability on
 * its AI's blackboard and slots /datum/ai_planning_subtree/hv_finisher into
 * its planning, right after the subtrees that pick a target. Some Voidcrew code swaps a mob's AI
 * controller after it spawns (boarding pods hand bosses a patrolling controller); the component
 * follows the mob onto the new controller.
 *
 * The subtree only acts when the ability is off cooldown and someone valid (finisher.dm,
 * hv_finisher_valid_victim()) is down: the mob's own target within
 * [var/datum/action/cooldown/mob_cooldown/hv_finisher/seek_range] tiles, or anyone right next to
 * it. It walks over and starts the finisher, and gives up on a victim it can't reach in
 * [var/datum/action/cooldown/mob_cooldown/hv_finisher/seek_timeout].
 */

/datum/component/hv_finisher_user
	/// The finisher ability it granted
	var/datum/action/cooldown/mob_cooldown/hv_finisher/finisher_action
	/// The AI controller it set up, watched so it can follow the mob onto a replacement
	var/datum/ai_controller/watched_controller

/datum/component/hv_finisher_user/Initialize(finisher_type, cooldown)
	if(!isliving(parent) || !ispath(finisher_type, /datum/hv_finisher))
		return COMPONENT_INCOMPATIBLE
	finisher_action = new(parent)
	finisher_action.finisher_type = finisher_type
	if(isnum(cooldown))
		finisher_action.cooldown_time = cooldown
	finisher_action.Grant(parent)
	adopt_controller()

/datum/component/hv_finisher_user/Destroy(force)
	release_controller()
	QDEL_NULL(finisher_action)
	return ..()

/// Sets up the mob's current AI controller: the ability on its blackboard and the subtree in its plan
/datum/component/hv_finisher_user/proc/adopt_controller()
	var/atom/movable/pawn = parent
	var/datum/ai_controller/controller = pawn?.ai_controller
	if(QDELETED(controller) || controller == watched_controller || QDELETED(finisher_action))
		return
	release_controller()
	watched_controller = controller
	controller.set_blackboard_key(BB_HV_FINISHER_ACTION, finisher_action)
	hv_finisher_add_subtree(controller)
	RegisterSignal(controller, COMSIG_AI_CONTROLLER_UNPOSSESSED_PAWN, PROC_REF(on_controller_lost))

/datum/component/hv_finisher_user/proc/release_controller()
	if(watched_controller)
		UnregisterSignal(watched_controller, COMSIG_AI_CONTROLLER_UNPOSSESSED_PAWN)
	watched_controller = null

/// The mob's controller let go of it, usually because a replacement is being built right now
/datum/component/hv_finisher_user/proc/on_controller_lost(datum/ai_controller/source)
	SIGNAL_HANDLER
	release_controller()
	addtimer(CALLBACK(src, PROC_REF(adopt_controller)), 1)

/**
 * Puts the finisher subtree into `controller`'s plan, after the leading subtrees that escape,
 * pick or hold a target, and before any attack or ability. Does nothing if it is already there.
 * Returns TRUE if it added it.
 */
/proc/hv_finisher_add_subtree(datum/ai_controller/controller)
	var/static/list/goes_first = typecacheof(list(
		/datum/ai_planning_subtree/call_reinforcements,
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/pet_planning,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/aggressive_find_target,
	))
	var/list/new_plan = list()
	var/insert_at = 1
	for(var/datum/ai_planning_subtree/subtree in controller.planning_subtrees)
		if(istype(subtree, /datum/ai_planning_subtree/hv_finisher))
			return FALSE
		new_plan += subtree.type
		if(insert_at == length(new_plan) && is_type_in_typecache(subtree, goes_first))
			insert_at++
	new_plan.Insert(insert_at, /datum/ai_planning_subtree/hv_finisher)
	controller.replace_planning_subtrees(new_plan)
	return TRUE

// ===== The ability =====

/// Starts the mob's finisher on someone who is down next to it
/datum/action/cooldown/mob_cooldown/hv_finisher
	name = "Finish Them"
	desc = "Finish off someone who is down."
	button_icon = 'icons/mob/telegraphing/telegraph.dmi'
	button_icon_state = "skull"
	cooldown_time = 60 SECONDS
	melee_cooldown_time = 0
	// Its own clock only: a shared cooldown would put the mob's other abilities on a minute's wait
	shared_cooldown = NONE
	click_to_activate = TRUE
	// The AI's move only. A player who takes the mob over (a sentience potion, an admin) gets no
	// button, so it can never be turned on other crews.
	owner_has_control = FALSE
	/// The /datum/hv_finisher it runs
	var/finisher_type = /datum/hv_finisher
	/// The one running now
	var/datum/hv_finisher/active
	/// Cooldown when the victim was pulled clear before it got hold
	var/missed_cooldown = 15 SECONDS
	/// Cooldown when the AI tried from somewhere it couldn't reach them
	var/blocked_cooldown = 5 SECONDS
	/// How far the AI walks to finish its own target
	var/seek_range = 3
	/// How long the AI tries to reach one victim before giving up on them for [var/missed_cooldown]
	var/seek_timeout = 6 SECONDS
	/// The victim the AI is walking to, and since when
	var/datum/weakref/seek_target
	var/seek_started_at = 0

/datum/action/cooldown/mob_cooldown/hv_finisher/Destroy()
	if(active)
		var/datum/hv_finisher/finisher = active
		active = null
		finisher.on_end = null
		finisher.stop(HV_FINISHER_ATTACKER_DOWN)
		qdel(finisher)
	seek_target = null
	return ..()

/datum/action/cooldown/mob_cooldown/hv_finisher/IsAvailable(feedback = FALSE)
	return ..() && isnull(active)

/datum/action/cooldown/mob_cooldown/hv_finisher/Activate(atom/target)
	var/mob/living/living_owner = owner
	if(!isliving(living_owner) || !hv_finisher_valid_victim(living_owner, target))
		return FALSE
	if(get_dist(living_owner, target) > 1 || !living_owner.Adjacent(target))
		// Something is between them. The AI tries again shortly rather than standing there.
		StartCooldown(blocked_cooldown)
		return FALSE
	var/datum/hv_finisher/finisher = new finisher_type(living_owner, target, CALLBACK(src, PROC_REF(finisher_ended)))
	active = finisher
	// Unavailable for the whole move; finisher_ended() sets the real cooldown when it ends
	StartCooldown(cooldown_time + finisher.longest_duration())
	seek_target = null
	if(!finisher.start())
		active = null
		qdel(finisher)
		StartCooldown(blocked_cooldown)
		return FALSE
	return TRUE

/// The finisher ended. A miss before the grip costs a short wait, anything else the full cooldown from now.
/datum/action/cooldown/mob_cooldown/hv_finisher/proc/finisher_ended(datum/hv_finisher/finisher, result)
	if(active == finisher)
		active = null
	if(result == HV_FINISHER_LOST_GRIP && !finisher.ever_gripped)
		StartCooldown(missed_cooldown)
	else
		StartCooldown()
	qdel(finisher)

/**
 * The victim for the AI, or null: whoever it was already after, else its current target if they
 * are down within [var/seek_range], else anyone down right next to it. It never walks to a
 * stranger: someone lying behind glass a few tiles off would otherwise stall it. Gives up on a
 * victim it has chased for [var/seek_timeout].
 */
/datum/action/cooldown/mob_cooldown/hv_finisher/proc/find_victim(datum/ai_controller/controller)
	var/mob/living/pawn = owner
	if(!isliving(pawn))
		return null
	var/mob/living/carbon/victim
	var/mob/living/carbon/chased = controller.blackboard[BB_HV_FINISHER_VICTIM]
	if(reachable_victim(chased))
		victim = chased
	if(isnull(victim))
		var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
		if(reachable_victim(target))
			victim = target
	var/turf/here = get_turf(pawn)
	if(isnull(victim) && here)
		for(var/mob/living/carbon/candidate in orange(1, here))
			if(pawn.Adjacent(candidate) && hv_finisher_valid_victim(pawn, candidate))
				victim = candidate
				break
	if(isnull(victim))
		seek_target = null
		return null
	if(seek_target?.resolve() != victim)
		seek_target = WEAKREF(victim)
		seek_started_at = world.time
	else if(world.time - seek_started_at > seek_timeout)
		seek_target = null
		StartCooldown(missed_cooldown)
		return null
	return victim

/// Whether `candidate` is a valid victim within [var/seek_range]
/datum/action/cooldown/mob_cooldown/hv_finisher/proc/reachable_victim(atom/candidate)
	if(!iscarbon(candidate) || get_dist(owner, candidate) > seek_range)
		return FALSE
	return hv_finisher_valid_victim(owner, candidate)

// ===== The AI =====

/// Walks to someone who is down and finishes them, when the finisher is ready
/datum/ai_planning_subtree/hv_finisher

/datum/ai_planning_subtree/hv_finisher/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/action/cooldown/mob_cooldown/hv_finisher/finisher = controller.blackboard[BB_HV_FINISHER_ACTION]
	if(QDELETED(finisher))
		return
	var/mob/living/pawn = controller.pawn
	if(!isliving(pawn) || pawn.stat != CONSCIOUS)
		return
	if(finisher.active)
		return SUBTREE_RETURN_FINISH_PLANNING
	// Planted for another move, or simply not ready
	if(HAS_TRAIT(pawn, TRAIT_IMMOBILIZED) || !finisher.IsAvailable())
		return
	var/mob/living/carbon/victim = finisher.find_victim(controller)
	if(isnull(victim))
		controller.clear_blackboard_key(BB_HV_FINISHER_VICTIM)
		return
	controller.set_blackboard_key(BB_HV_FINISHER_VICTIM, victim)
	controller.queue_behavior(/datum/ai_behavior/targeted_mob_ability/min_range/hv_finisher, BB_HV_FINISHER_ACTION, BB_HV_FINISHER_VICTIM)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Walks next to the victim, then uses the finisher on them
/datum/ai_behavior/targeted_mob_ability/min_range/hv_finisher
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION
	required_distance = 1

/datum/ai_behavior/targeted_mob_ability/min_range/hv_finisher/finish_action(datum/ai_controller/controller, succeeded, ability_key, target_key)
	. = ..()
	controller.clear_blackboard_key(target_key)
