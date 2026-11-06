/// Backgrounds: owned by P5. See data/backgrounds/spec.md.

/*
 * The hauler's brain: the stock NPC ship controller and movement subtree, with no combat
 * subtree and no target. A hauler never fights. A ship that starts a lock on it makes it run
 * for a while, away from that ship and toward the trader outpost of its band; a hauler that
 * has given up, is held by an interdictor or is leaving holds still. Everything else (the
 * patrol circuit, parking, undock recovery, the zone fence) is npc_ship_movement's.
 */

/// The ship it is running from
#define BB_HAULER_FLEE_FROM "hauler_flee_from"
/// world.time the run ends
#define BB_HAULER_FLEE_UNTIL "hauler_flee_until"
/// How long one scare keeps it running
#define HAULER_FLEE_TIME (2 MINUTES)

/datum/ai_controller/npc_ship/hauler
	planning_subtrees = list(
		/datum/ai_planning_subtree/hauler_flight,
		/datum/ai_planning_subtree/npc_ship_movement,
	)

// A lock starting on it: no target, no combat state, no warning back. It runs.
/datum/ai_controller/npc_ship/hauler/on_being_targeted_by_player(datum/source, obj/structure/overmap/ship/aggressor)
	npc_metric_player_aggression(get_ship(), aggressor, "targeting")
	start_flight(aggressor)

// A finished lock: the same. The parent would make the aggressor its target and chase it.
/datum/ai_controller/npc_ship/hauler/on_weapons_locked_by_player(datum/source, obj/structure/overmap/ship/aggressor)
	npc_metric_player_aggression(get_ship(), aggressor, "weapons_lock")
	start_flight(aggressor)

/// Runs from `aggressor` for HAULER_FLEE_TIME, unless it is holding still. Never sleeps.
/datum/ai_controller/npc_ship/hauler/proc/start_flight(obj/structure/overmap/ship/aggressor)
	var/obj/structure/overmap/ship/npc/hauler/ship = get_ship()
	if(!istype(ship) || QDELETED(aggressor) || aggressor == ship)
		return FALSE
	if(ship.is_holding_still())
		return FALSE
	set_blackboard_key(BB_HAULER_FLEE_FROM, aggressor)
	set_blackboard_key(BB_HAULER_FLEE_UNTIL, world.time + HAULER_FLEE_TIME)
	return TRUE

/// Stops running
/datum/ai_controller/npc_ship/hauler/proc/stop_flight()
	clear_blackboard_key(BB_HAULER_FLEE_FROM)
	clear_blackboard_key(BB_HAULER_FLEE_UNTIL)

/// The ship it is running from, while the run lasts, or null
/datum/ai_controller/npc_ship/hauler/proc/flight_threat()
	if(world.time >= (blackboard[BB_HAULER_FLEE_UNTIL] || 0))
		return null
	var/obj/structure/overmap/ship/threat = blackboard[BB_HAULER_FLEE_FROM]
	return QDELETED(threat) ? null : threat

/**
 * Ahead of the stock movement subtree: holds still (nothing else plans) while the hauler has
 * given up, is interdicted or is leaving; queues the run while it is scared; otherwise lets
 * npc_ship_movement patrol, park and recover as for any NPC hull.
 */
/datum/ai_planning_subtree/hauler_flight

/datum/ai_planning_subtree/hauler_flight/SelectBehaviors(datum/ai_controller/npc_ship/hauler/controller, seconds_per_tick)
	if(!istype(controller))
		return
	var/obj/structure/overmap/ship/npc/hauler/ship = controller.pawn
	if(!istype(ship))
		return
	if(ship.is_holding_still())
		return SUBTREE_RETURN_FINISH_PLANNING
	// Parked, mid-manoeuvre or dead in the water: npc_ship_movement handles all of those
	if(ship.state != OVERMAP_SHIP_FLYING || !ship.can_move_under_own_power())
		return
	if(!controller.flight_threat())
		return
	controller.queue_behavior(/datum/ai_behavior/npc_ship/hauler_flee)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * One tile per step, at the retreat's pace: the legal step (no obstacle, still in its band)
 * that best opens distance from the threat, leaning toward its band's trader outpost.
 */
/datum/ai_behavior/npc_ship/hauler_flee
	action_cooldown = 2 SECONDS

/datum/ai_behavior/npc_ship/hauler_flee/perform(seconds_per_tick, datum/ai_controller/npc_ship/hauler/controller)
	. = ..()
	var/obj/structure/overmap/ship/npc/hauler/ship = get_ship(controller)
	if(!istype(ship) || ship.state != OVERMAP_SHIP_FLYING || !ship.can_thrust())
		return AI_BEHAVIOR_DELAY
	var/obj/structure/overmap/ship/threat = controller.flight_threat()
	var/turf/here = get_turf(ship)
	var/turf/threat_turf = get_turf(threat)
	if(!here || !threat_turf)
		return AI_BEHAVIOR_DELAY
	// BB_NPC_SPAWN_ZONE: npc_ships/code/_defines.dm compiles after this module, so its key is spelt out
	var/datum/overmap_zone/spawn_zone = controller.blackboard["npc_spawn_zone"]
	var/turf/haven_turf = get_turf(ship.flight_haven())
	var/best_dir = 0
	var/best_score
	for(var/candidate_dir in GLOB.alldirs)
		if(direction_has_obstacle(here, candidate_dir) || !direction_stays_in_zone(here, candidate_dir, spawn_zone))
			continue
		var/turf/step_turf = get_step(here, candidate_dir)
		if(!step_turf)
			continue
		var/score = get_dist(step_turf, threat_turf) * 2
		if(haven_turf)
			score -= get_dist(step_turf, haven_turf)
		if(isnull(best_score) || score > best_score)
			best_score = score
			best_dir = candidate_dir
	if(!best_dir || !ship.consume_thrust_step())
		return AI_BEHAVIOR_DELAY
	ship.dir = best_dir
	ship.forceMove(get_step(here, best_dir))
	return AI_BEHAVIOR_DELAY

#undef BB_HAULER_FLEE_FROM
#undef BB_HAULER_FLEE_UNTIL
#undef HAULER_FLEE_TIME
