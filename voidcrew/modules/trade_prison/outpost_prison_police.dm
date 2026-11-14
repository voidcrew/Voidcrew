/**
 * # Outpost lockup: the police
 *
 * Models a trader outpost's lockup (/datum/outpost_prison) as a police sector, following
 * voidcrew/modules/trade_floors/police_floors.dm: the sector is the /datum/outpost_prison itself, its lift tiles are
 * its 3x3 alcove (alcove_turfs), its elevator floor id is OUTPOST_LIFT_LOCKUP, and its lift panel is a witness camera.
 *
 * When a prisoner goes loose while a player is at the outpost (has_audience()), the wing orders one response unit to
 * its sector through order_unit(), at most once per riot. While a loose prisoner is still on their feet, dispatch
 * keeps that unit on scene and sends it searching for them; once none remain, dispatch stands it down through the
 * alcove as usual.
 */

/datum/outpost_prison
	/// Whether this riot or breakout has already ordered a police unit
	var/riot_police_called = FALSE

/// Clears the one-call-per-riot latch once no riot is on and nobody is loose
/datum/outpost_prison/proc/clear_riot_police_call()
	if(!riot_active && !loose_count())
		riot_police_called = FALSE

/// Orders one police officer to this lockup when a prisoner goes loose with an audience, at most once per riot
/datum/outpost_prison/proc/maybe_call_riot_police()
	if(riot_police_called || !has_audience() || !outpost?.police)
		return null
	riot_police_called = TRUE
	return outpost.police.order_unit(POLICE_UNIT_OFFICER, src)

// =========================================================================
// SECTORS, CAMERAS AND BREAKOUT RESPONSE
// =========================================================================

/// The lockup sector `where` is in (the /datum/outpost_prison) when it lies in this outpost's wing and has an alcove, else null
/datum/outpost_police/proc/lockup_sector_of(turf/where)
	var/datum/outpost_prison/lockup = outpost?.prison
	if(!lockup || !length(lockup.alcove_turfs) || !lockup.contains_turf(get_turf(where)))
		return null
	return lockup

/// The lift tiles of a lockup sector: its alcove
/datum/outpost_police/proc/lockup_lift_tiles(sector)
	var/datum/outpost_prison/lockup = sector
	if(!istype(lockup) || lockup != outpost?.prison)
		return list()
	return lockup.alcove_turfs || list()

/// Whether `where` is a lift tile of this outpost's lockup
/datum/outpost_police/proc/lockup_is_lift_tile(turf/where)
	var/datum/outpost_prison/lockup = outpost?.prison
	return !!(lockup && (where in lockup.alcove_turfs))

/// The lockup's lift panel, watched like the lobby's and a berth's
/datum/outpost_police/proc/lockup_cameras()
	var/obj/machinery/outpost_elevator/lockup/panel = outpost?.prison?.lift_panel
	if(QDELETED(panel))
		return list()
	return list(panel)

/// A loose prisoner of this outpost's lockup who is still conscious, out of crit and unrestrained (police_runner_target()), nearest `from` when given, or null
/datum/outpost_police/proc/lockup_loose_target(atom/from)
	var/datum/outpost_prison/lockup = outpost?.prison
	if(!lockup)
		return null
	var/turf/from_turf = get_turf(from)
	var/mob/living/carbon/human/npc/outpost_prisoner/best
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in lockup.prisoners)
		if(QDELETED(prisoner) || !prisoner.police_runner_target())
			continue
		if(!from_turf)
			return prisoner
		var/turf/where = get_turf(prisoner)
		var/distance = (where && where.z == from_turf.z) ? get_dist(from_turf, where) : 1000
		if(!best || distance < best_distance)
			best = prisoner
			best_distance = distance
	return best

/// Whether a pending spawn `order` was queued for the lockup while a loose prisoner is still up
/datum/outpost_police/proc/lockup_keeps_order(datum/human_npc_order/order)
	var/datum/outpost_prison/lockup = outpost?.prison
	if(!lockup || !order || !lockup_loose_target())
		return FALSE
	for(var/datum/outpost_police_wave/wave as anything in dispatch_waves)
		if(wave?.sector == lockup && (order in wave.orders))
			return TRUE
	return FALSE

/// Whether `officer` is a response unit working a loose prisoner in this outpost's lockup
/datum/outpost_police/proc/lockup_keeps_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/outpost_prison/lockup = outpost?.prison
	if(!lockup || QDELETED(officer) || !dispatch_is_response_unit(officer) || !lockup_loose_target())
		return FALSE
	return officer.dispatch_wave?.sector == lockup || lockup.contains_turf(get_turf(officer))

/// Sends an idle response unit in the lockup searching toward a loose prisoner
/datum/outpost_police/proc/lockup_direct_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(!lockup_keeps_officer(officer))
		return FALSE
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	if(!istype(brain) || officer.stat != CONSCIOUS || officer.client || officer.case || officer.npc_exit || officer.dispatch_riding)
		return FALSE
	if(brain.stealth_state() != STEALTH_UNAWARE || brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) || world.time < brain.police_research_at)
		return FALSE
	var/mob/living/carbon/human/npc/outpost_prisoner/runner = lockup_loose_target(officer)
	var/turf/where = get_turf(runner)
	if(!where)
		return FALSE
	brain.police_research_at = world.time + OUTPOST_POLICE_RESEARCH_GAP
	brain.stealth_go_searching(where)
	return TRUE

// Loose prisoners share FACTION_NEUTRAL with officers, so stealth's scan and police_will_fight() must not pass them over as allies.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/faction_check_atom(atom/movable/target, exact_match)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = target
	if(istype(prisoner) && prisoner.turret_target())
		return FALSE
	return ..()

// =========================================================================
// CROSSING PROCESSING AND YARD PARTITIONS
// =========================================================================

#define BB_LOCKUP_STEP_TURF "BB_lockup_step_turf"

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police
	/// Set when this controller switched to JPS pathfinding to cross Processing or an interior lockup door under alert
	var/lockup_paths = FALSE

/// Restores alert chase movement once no lockup door crossing needs JPS pathfinding
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/lockup_give_back_paths()
	clear_blackboard_key(BB_LOCKUP_STEP_TURF)
	if(!lockup_paths)
		return
	lockup_paths = FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(stealth_state() == STEALTH_ALERT && !breach_paths && !(istype(officer) && officer.case))
		human_npc_set_ai_movement(src, /datum/ai_movement/basic_avoidance/stealth)

/// Ensures JPS movement while stepping through a lockup door
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/lockup_use_paths()
	if(!istype(ai_movement, /datum/ai_movement/jps))
		lockup_paths = TRUE
		human_npc_set_ai_movement(src, /datum/ai_movement/jps/stealth)

/// Next step turf inside the lockup when an arresting `officer` must cross Processing to reach `dest` (null when leaving the lockup sector), or null
/datum/outpost_police/proc/lockup_case_step(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, turf/dest)
	var/datum/outpost_prison/lockup = outpost?.prison
	var/turf/here = get_turf(officer)
	if(QDELETED(officer) || officer.stat != CONSCIOUS || !lockup?.contains_turf(here) || !lockup.has_processing())
		return null
	if(dest && lockup.in_processing(dest))
		if(lockup.in_processing(here))
			return null
		var/obj/machinery/door/airlock/security/prison_staff/inner = lockup.processing_door(TRUE)
		var/obj/machinery/door/airlock/security/prison_staff/outer = lockup.processing_door(FALSE)
		var/from_front = lockup.in_front_room(here) || here == get_turf(outer)
		if(!from_front && inner && inner.lockup_breached() && !inner.density)
			return null
		return lockup.processing_step_through(officer, from_front)
	var/dest_in_front = !dest || !lockup.contains_turf(dest) || lockup.in_front_room(dest)
	return lockup.processing_step_through(officer, !dest_in_front)

/// The destination turf `pawn` is currently trying to reach inside or out of `lockup`, or null
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/lockup_cross_dest(datum/outpost_prison/lockup)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/turf/here = get_turf(officer)
	if(blackboard_key_exists(BB_HUMAN_NPC_EXIT))
		return get_turf(blackboard[BB_HUMAN_NPC_EXIT])
	if(blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return get_turf(blackboard[BB_BASIC_MOB_CURRENT_TARGET])
	if(officer.case && officer.case.arresting() != officer)
		return get_turf(officer.case.arresting() || officer.case.get_suspect())
	switch(stealth_state())
		if(STEALTH_SEARCHING)
			if(calm_until)
				return null
			var/center_yard = lockup.processing_on_yard_side(search_center)
			var/here_yard = lockup.processing_on_yard_side(here)
			if(search_center && center_yard == here_yard && !lockup.in_processing(here))
				while(length(search_queue) && lockup.processing_on_yard_side(search_queue[1]) != here_yard)
					search_queue.Cut(1, 2)
			return length(search_queue) ? search_queue[1] : search_center
		if(STEALTH_SUSPICIOUS)
			if(!investigated && world.time >= blackboard[BB_STEALTH_STATE_SINCE] + stealth_skill().reaction_delay)
				return investigate_turf
	if(lockup.in_processing(here))
		var/mob/living/runner = officer.police?.lockup_loose_target(officer)
		if(runner)
			return get_turf(runner)
		return length(lockup.alcove_turfs) ? lockup.alcove_turfs[1] : null
	return null

/// Whether at least one staff door between the office and yard can open for an officer
/proc/outpost_lockup_office_door_usable(datum/outpost_prison/lockup)
	for(var/turf/door_tile as anything in lockup.guard_yard_doors())
		var/obj/machinery/door/airlock/door = locate() in door_tile
		if(!door)
			return TRUE
		if(!door.welded && (!door.density || (!door.locked && door.hasPower())))
			return TRUE
	return FALSE

/// Whether a glass wall, hatch or closed door blocks shots between `from` and `to_turf`
/proc/outpost_lockup_shot_blocked(turf/from, turf/to_turf)
	if(!from || !to_turf || from == to_turf)
		return FALSE
	for(var/turf/line_turf as anything in outpost_police_shot_line(from, to_turf))
		if(line_turf == from || line_turf == to_turf)
			continue
		if(isclosedturf(line_turf))
			return TRUE
		for(var/obj/machinery/door/blocker in line_turf)
			if(blocker.density)
				return TRUE
	return FALSE

/**
 * Steps an officer inside a lockup through Processing (one door at a time) when its goal lies on the other side, and
 * paths an alert officer through the office staff door rather than firing into a serving hatch or glass wall.
 */
/datum/ai_planning_subtree/outpost_police_lockup_cross

/datum/ai_planning_subtree/outpost_police_lockup_cross/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(controller) || !istype(officer))
		return
	var/datum/outpost_prison/lockup = officer.police?.outpost?.prison
	var/turf/here = get_turf(officer)
	if(officer.stat != CONSCIOUS || officer.client || officer.pulledby || officer.dispatch_riding || (officer.case && officer.case.arresting() == officer) || LAZYLEN(officer.do_afters) || !lockup?.contains_turf(here) || !lockup.has_processing())
		controller.lockup_give_back_paths()
		return
	var/turf/dest = controller.lockup_cross_dest(lockup)
	if(!dest || dest == here)
		controller.lockup_give_back_paths()
		return
	var/turf/step_turf
	if(lockup.in_processing(dest))
		if(!lockup.in_processing(here))
			var/obj/machinery/door/airlock/security/prison_staff/inner = lockup.processing_door(TRUE)
			var/obj/machinery/door/airlock/security/prison_staff/outer = lockup.processing_door(FALSE)
			var/from_front = lockup.in_front_room(here) || here == get_turf(outer)
			if(from_front || !(inner && inner.lockup_breached() && !inner.density))
				step_turf = lockup.processing_step_through(officer, from_front)
	else
		var/dest_in_front = !lockup.contains_turf(dest) || lockup.in_front_room(dest)
		step_turf = lockup.processing_step_through(officer, !dest_in_front)
	if(!step_turf && controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
		var/mob/living/person = officer.police_mech_suspect(target)
		if(officer.force_for(target) >= POLICE_FORCE_STUN && !(isliving(person) && officer.police?.order_pending(person)))
			if(lockup.in_cell_block(here) != lockup.in_cell_block(dest) && outpost_lockup_shot_blocked(here, dest) && outpost_lockup_office_door_usable(lockup))
				step_turf = dest
	if(!step_turf)
		controller.lockup_give_back_paths()
		return
	controller.stealth_drop_walk()
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
		if(officer.force_for(target) >= POLICE_FORCE_STUN)
			officer.sync_force(officer.force_for(target))
		if(controller.lost_since)
			controller.lost_since = world.time
	if(step_turf == here)
		if(controller.ai_movement?.moving_controllers[controller])
			controller.ai_movement.stop_moving_towards(controller)
		controller.clear_blackboard_key(BB_LOCKUP_STEP_TURF)
		var/obj/machinery/door/airlock/face_door = lockup.in_processing(here) ? (lockup.processing_entry_ref?.resolve() == lockup.processing_door(TRUE) ? lockup.processing_door(FALSE) : lockup.processing_door(TRUE)) : (lockup.in_front_room(here) ? lockup.processing_door(FALSE) : lockup.processing_door(TRUE))
		if(face_door && get_turf(face_door) != here)
			controller.stand_dir = stealth_dir_to(officer, face_door)
			officer.setDir(controller.stand_dir)
		controller.queue_behavior(/datum/ai_behavior/stealth_stand)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.lockup_use_paths()
	controller.set_blackboard_key(BB_LOCKUP_STEP_TURF, step_turf)
	controller.queue_behavior(/datum/ai_behavior/outpost_police_lockup_step)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Walks to `BB_LOCKUP_STEP_TURF` with JPS pathfinding while crossing Processing or an interior lockup door
/datum/ai_behavior/outpost_police_lockup_step
	required_distance = 0
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/outpost_police_lockup_step/setup(datum/ai_controller/controller)
	. = ..()
	var/turf/goal = controller.blackboard[BB_LOCKUP_STEP_TURF]
	if(!isturf(goal))
		return FALSE
	set_movement_target(controller, goal)
	return TRUE

/datum/ai_behavior/outpost_police_lockup_step/perform(seconds_per_tick, datum/ai_controller/controller)
	var/turf/goal = controller.blackboard[BB_LOCKUP_STEP_TURF]
	if(!isturf(goal))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(get_turf(controller.pawn) == goal)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

#undef BB_LOCKUP_STEP_TURF
