/**
 * # Outpost police on the stealth layer
 *
 * Owner: P13 (spec-stealth.md, owner decisions 12 and 19). Officers are stealth guards: they walk stealth patrol
 * routes, see with stealth sight, hear stealth noises and call on stealth radios. What is theirs is here.
 *
 * Why this file is not in voidcrew/modules/outpost_police/: that module is included before
 * voidcrew/modules/stealth/, and an override of a proc first declared in a later file is dead code (the compiler
 * only warns override_before_def). Every override of a stealth proc lives here, after stealth.
 *
 * - The brain: /datum/ai_controller/basic_controller/human_npc/stealth/outpost_police, planning in the order of
 *   spec-stealth 1.2. The stealth scan finds people through the police targeting strategy (police_force.dm), so a
 *   clean visitor is never noticed.
 * - Beats are routes of /obj/effect/landmark/stealth_patrol/police. At a stop, an unaware officer with nothing to
 *   do does that stop's `police_activity` with the ambient routine runner (outpost_police_stop below); the
 *   sergeant does the desk at its post.
 * - Stealth's barks are police lines (stealth_bark() below, contexts "stealth_*" in AMBIENT_STRINGS_POLICE).
 * - Overrides: the leash (anywhere at the outpost), the walk (another sector goes by the police lift), becoming a
 *   sentry (a route is taken back on return), the radio call (it makes the officer's waiting reports), setup (on
 *   the roster), a seat of its own is not captivity, and the alert (who the police set it on).
 * - Someone the police have in hand (has_in_hand(): cuffed, in a cell, or down with an arrest on them) is no part of
 *   the stealth play: nobody loses, searches for, goes on alert over or calls an alarm about them, their noise brings
 *   nobody, and an officer on an arrest is not drawn off by a noise (owner decision 58).
 * - In hand is not yet held. Someone down with the cuffs still to come (has_down()) is fought by nobody, but the
 *   officers who were on them, and any who see them lying there, stay by them (outpost_police_cover) and are on them
 *   at once if they get up first. The squad stands down as one only when the last wanted person is held: in cuffs
 *   or in a cell (has_secured(), stealth_all_clear()).
 * - A colleague awake on the floor is nobody's body (stealth_fallen()): what put them there is a crime against an
 *   officer, and the police answer that.
 * - Someone the police are already after (an arrest open on them, or units sent after them: is_after()), or wanted
 *   and fresh from going for somebody, gets no second look: an officer that takes notice of them in plain view is on
 *   them at once, with no "what's that" (police_knows_on_sight()). Getting past an officer unnoticed is as it was,
 *   and so is everyone else's second look.
 * - One of the outpost's people held at gunpoint: every officer that sees it holds fire and stands off, as stealth's
 *   guards do (stealth_hostage.dm), ahead of the arrest and the use of force. Told to drop it, only an officer caught
 *   cold puts its weapon down: one already on a hunt or a search keeps it (owner decision 68). They hold fire for
 *   OUTPOST_POLICE_STANDOFF_MAX in all, counted for the whole squad from the first of them to do it, and then shoot
 *   (owner decision 70).
 */

// =========================================================================
// THE MAP KIT
// =========================================================================

/**
 * A stop on an officer's beat. Placed by the maps (P7): `route`, `order`, `wait`, `chatter`, `route_mode` and `dir`
 * as any stealth patrol point; `police_activity` is what the officer does while it waits here:
 * "shopfront", "coffee", "chat", "bench", "bar", "cells" or "desk" (spec-stealth 1.5).
 */
/obj/effect/landmark/stealth_patrol/police
	name = "police patrol point"
	/// What an officer does at this stop (see above), or null to stand and look about
	var/police_activity

/obj/effect/landmark/stealth_patrol/police/Initialize(mapload)
	if(!facing && mapload)
		facing = dir
	return ..()

// =========================================================================
// THE BRAIN
// =========================================================================

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/human_npc/outpost_police,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = HUMAN_NPC_SIGHT_RANGE,
		BB_HUMAN_NPC_SHOT_DELAY = 3 SECONDS,
		BB_HUMAN_NPC_FIRE_RANGE = 7,
		BB_HUMAN_NPC_KEEP_AWAY = 2,
		BB_STEALTH_STATE = STEALTH_UNAWARE,
	)
	planning_subtrees = list(
		/datum/ai_planning_subtree/stealth_perception,
		/datum/ai_planning_subtree/human_npc_soft_crit,
		/datum/ai_planning_subtree/ambient_escape,
		/datum/ai_planning_subtree/human_npc_walk_out,
		// Ahead of the arrest and the use of force, which plan for any target they will fight: after them, as
		// stealth's own list has it, an officer never held fire for a hostage (decision 68)
		/datum/ai_planning_subtree/stealth_hostage,
		/datum/ai_planning_subtree/outpost_police_case,
		/datum/ai_planning_subtree/outpost_police_cover,
		/datum/ai_planning_subtree/stealth_react,
		/datum/ai_planning_subtree/outpost_police_force,
		/datum/ai_planning_subtree/npc_combat_sense,
		/datum/ai_planning_subtree/human_npc_arm,
		/datum/ai_planning_subtree/stealth_closet,
		/datum/ai_planning_subtree/human_npc_shoot,
		/datum/ai_planning_subtree/human_npc_melee,
		/datum/ai_planning_subtree/outpost_police_stop,
		/datum/ai_planning_subtree/stealth_patrol,
	)
	/// The route it walked before it was carried off its region (a berth, a ship): taken back when it is home again
	var/police_lost_route
	/// The stop visit (its wait_until) whose activity already ran, so a finished one is not started again there
	var/police_stop_visit = 0
	/// Weakref to the mind the police set it on (dispatch, a crime it saw, its own alert on a wanted person)
	var/datum/weakref/police_hunt
	/// world.time it may next be sent to look for its suspect again (OUTPOST_POLICE_RESEARCH_GAP)
	var/police_research_at = 0
	/// world.time it may try a lift ride again after one failed
	var/police_ride_retry_at = 0
	/// world.time it last went on a hunt or a search from being unaware, or 0 while it is unaware
	var/police_onto_at = 0
	/// Whether the standoff it is in found it off its guard (police_caught_cold()): only then does it drop its weapon when told to
	var/standoff_cold = FALSE
	/// Weakref to the mind of someone down with an arrest on them, the cuffs still to come, whom it stands over (police_cover())
	var/datum/weakref/police_cover_ref
	/// world.time someone the police hold last laid a hand on it: put on the floor by that, it gets up without a search
	var/police_held_touch_at = 0
	/// Set while police_search_for() starts a search: its place is one the police dealt it (police_search.dm)
	var/police_dealing = FALSE
	/// Whether the search it is on is of a place the police dealt it: looked at from where it stands, and no more
	var/police_dealt = FALSE
	/// How often the search it is on has asked for its spots: more than once, and they have all been looked at
	var/police_spots_asked = 0
	/// Whether it has looked at every spot of the search it is on: the police have its next place (stealth_search_on())
	var/police_looked = FALSE
	/// The sighting (the warrant's last_seen_at) it was last sent to look from
	var/police_search_stamp = 0
	/// world.time it may next be turned, mid-search, to a fresher sighting
	var/police_redirect_at = 0

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/UnpossessPawn(destroy)
	police_hunt = null
	police_cover_ref = null
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/SelectBehaviors(seconds_per_tick)
	police_clear_for_duty()
	return ..()

/// Ends a stop or desk activity (standing up from a bench or desk chair) and sets a drink down once on police business
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_clear_for_duty()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer) || officer.stat != CONSCIOUS)
		return
	if(stealth_state() == STEALTH_UNAWARE && !blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) && !officer.case && !officer.npc_exit && !officer.dispatch_riding && !officer.dispatch_responding() && isnull(police_cover_ref))
		return
	if(officer.activity)
		officer.end_activity()
	if(officer.buckled && officer.own_buckle(officer.buckled))
		officer.stand_up()
	if(officer.held_item)
		officer.put_drink_down(null)

// Anywhere at the outpost is in reach: an officer searches its whole station, not 24 tiles round its last stop
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_leash(turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(where && istype(officer) && officer.police?.dispatch_at_outpost(where))
		return where
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_walk_arrived(turf/dest)
	if(goto_dest == dest && goto_result == "arrived" && police_cross_sector_lift_walk(dest))
		return FALSE
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_walk_over(turf/dest)
	if(goto_dest == dest && goto_result == "arrived" && police_cross_sector_lift_walk(dest))
		return FALSE
	return ..()

/// Whether walking from where the pawn stands to `dest` still needs a lift ride between sectors
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_cross_sector_lift_walk(turf/dest)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/datum/outpost_police/police = istype(officer) ? officer.police : null
	var/turf/here = get_turf(officer)
	if(!police || !dest || !here || here == dest)
		return FALSE
	var/from_sector = police.sector_of(here)
	var/to_sector = police.sector_of(dest)
	if(from_sector == to_sector || from_sector == POLICE_SECTOR_OUTSIDE || to_sector == POLICE_SECTOR_OUTSIDE)
		return FALSE
	var/next_ride_sector = police.next_elevator_sector(from_sector, to_sector)
	if(!next_ride_sector)
		return FALSE
	var/board_sector = police.elevator_board_sector(from_sector)
	return length(police.dispatch_elevator_tiles(board_sector)) > 0 && length(police.dispatch_elevator_tiles(next_ride_sector)) > 0

/**
 * A walk into another sector goes on foot between concourse and lobby (exit gate one way, checkpoint the other)
 * and by the hangar elevator between the lobby and a hangar berth. A beat officer is never taken to a hangar
 * (spec-stealth 1.5): that walk is over at once, as a walk the pathfinder gave up on.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_walk(turf/dest, purpose)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/datum/outpost_police/police = istype(officer) ? officer.police : null
	var/turf/here = get_turf(officer)
	if(!police || !dest || !here)
		police?.clear_checkpoint_crossing(officer)
		return ..()
	var/from_sector = police.sector_of(here)
	var/to_sector = police.sector_of(dest)
	if(from_sector == to_sector || from_sector == POLICE_SECTOR_OUTSIDE || to_sector == POLICE_SECTOR_OUTSIDE)
		police.clear_checkpoint_crossing(officer)
		return ..()
	if(istype(to_sector, /datum/outpost_berth) && !police.dispatch_is_response_unit(officer))
		police.clear_checkpoint_crossing(officer)
		if(goto_dest != dest)
			stealth_drop_walk()
			goto_dest = dest
		goto_purpose = purpose
		if(goto_result != "failed")
			goto_result = "failed"
			stealth_walk_failed()
		return
	if(officer.dispatch_riding)
		return
	if(from_sector == POLICE_SECTOR_LOBBY && to_sector == POLICE_SECTOR_CONCOURSE)
		var/turf/gate_step = police.checkpoint_step_to_concourse(officer)
		if(gate_step)
			if(gate_step == here)
				stealth_drop_walk()
				queue_behavior(/datum/ai_behavior/stealth_stand)
				return
			if(goto_dest == gate_step && goto_result == "arrived")
				goto_result = null
				goto_turf = null
			return ..(gate_step, purpose)
	else
		police.clear_checkpoint_crossing(officer)
	var/next_ride_sector = police.next_elevator_sector(from_sector, to_sector)
	if(!next_ride_sector)
		if(here.z == dest.z)
			return ..()
		if(goto_dest != dest)
			stealth_drop_walk()
			goto_dest = dest
		goto_purpose = purpose
		if(goto_result != "failed")
			goto_result = "failed"
			stealth_walk_failed()
		return
	var/board_sector = police.elevator_board_sector(from_sector)
	var/list/turf/board_tiles = police.dispatch_elevator_tiles(board_sector)
	if(!length(board_tiles) || !length(police.dispatch_elevator_tiles(next_ride_sector)))
		if(goto_dest != dest)
			stealth_drop_walk()
			goto_dest = dest
		goto_purpose = purpose
		if(goto_result != "failed")
			goto_result = "failed"
			stealth_walk_failed()
		return
	if(goto_dest != dest)
		stealth_drop_walk()
		goto_dest = dest
	goto_purpose = purpose
	if(goto_result == "failed")
		return
	if(!(here in board_tiles))
		var/turf/lift = police.dispatch_nearest_elevator_point(board_sector, officer, officer) || police.dispatch_nearest_lift_point(board_sector, officer)
		if(!lift)
			goto_result = "failed"
			stealth_walk_failed()
			return
		goto_result = null
		if(isnull(goto_turf) || goto_turf == goto_dest || (police.dispatch_is_lift_tile(goto_turf) && goto_turf != lift))
			goto_turf = stealth_next_leg(lift)
		queue_behavior(/datum/ai_behavior/stealth_goto)
		return
	if(world.time < police_ride_retry_at)
		queue_behavior(/datum/ai_behavior/stealth_stand)
		return
	police_ride_retry_at = world.time + 3 SECONDS
	stealth_drop_walk()
	INVOKE_ASYNC(police, TYPE_PROC_REF(/datum/outpost_police, ride), officer, next_ride_sector)

/// Carried off (abuse M29): it holds where it is, as stealth has it, but remembers its route for when it is back
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_become_sentry(turf/where)
	if(route_id)
		police_lost_route = route_id
	return ..()

/// Back in its group's region with a route it was carried off: it walks that route again, unless someone took it
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_take_route_back()
	if(isnull(police_lost_route) || route_id || isnull(group))
		return
	var/turf/here = get_turf(pawn)
	if(!here || here.z != group.home?.z || !group.region_matches(here))
		return
	var/lost = police_lost_route
	police_lost_route = null
	if(!length(group.routes[lost]) || outpost_police_route_taken(group, lost, pawn))
		return
	route_id = lost
	stealth_rejoin_route()

/// Its call went out: the reports it was waiting to make count now (spec-stealth 2.3)
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_deliver_call()
	var/list/call_made = pending_call
	var/due = !isnull(call_made) && world.time >= call_made[STEALTH_CALL_DUE] && world.time <= call_made[STEALTH_CALL_DUE] + STEALTH_RADIO_CALL_STALE
	. = ..()
	if(!due)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer) || officer.stat != CONSCIOUS || HAS_TRAIT(officer, TRAIT_INCAPACITATED) || !human_npc_can_talk(officer) || !officer.stealth_radio_ready())
		return
	officer.police?.confirm_reports(officer)

/// Its first plan: on the roster of the outpost it stands at
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_setup()
	var/was_ready = stealth_ready
	. = ..()
	if(was_ready || !stealth_ready)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer))
		return
	officer.home_police()?.add_officer(officer)
	// Only beat officers walk beat routes: the sergeant's post is the desk, and response units never hold a beat stop
	var/turf/desk = officer.police?.desk_turf
	var/turf/here = get_turf(officer)
	if(officer.unit_kind != POLICE_UNIT_BEAT)
		route_id = null
		at_stop = FALSE
		home_retry_at = 0
		home_turf = (officer.unit_kind == POLICE_UNIT_SERGEANT && desk && here && desk.z == here.z) ? desk : here
	else if(route_id && group && outpost_police_route_taken(group, route_id, officer))
		route_id = null
		at_stop = FALSE
		home_retry_at = 0
		home_turf = here
		officer.police_claim_route()
	// Off a police lift, no stop of the beat within reach: it takes a free route now. The police's tick does that too
	// (stealth_tick_officer()), but it sleeps while nobody is wanted, and the officer stood in its lift until the next
	// crime woke it (owner playtest 4).
	else if(isnull(route_id))
		officer.police_claim_route()

// Its own seat (the desk chair, a bench at a stop) is not being held: it still looks about and can report
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_captive()
	var/mob/living/carbon/human/npc/ambient_npc/officer = pawn
	if(istype(officer) && officer.buckled && officer.own_buckle(officer.buckled) && isturf(officer.loc) && !HAS_TRAIT(officer, TRAIT_RESTRAINED))
		var/mob/living/holder = officer.pulledby
		return istype(holder) && holder.grab_state > GRAB_PASSIVE
	return ..()

// An arresting officer keeps its pathfinding when it goes alert: it walks the suspect to the desk on it
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_set_state(new_state)
	. = ..()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer))
		return
	if(new_state != STEALTH_UNAWARE)
		police_clear_for_duty()
	if(new_state == STEALTH_UNAWARE)
		police_onto_at = 0
	else if(new_state != STEALTH_SUSPICIOUS && !police_onto_at)
		police_onto_at = world.time
	// Its pathfinder always, alert or not. Stealth's guards chase in a straight line, which in a checkpoint lobby
	// left an officer pushing at the queue rails and the lockers (owner playtest 3).
	human_npc_set_ai_movement(src, /datum/ai_movement/jps/stealth)

// ----- the search (police_search.dm) -----

// Every search starts with its spots still to look at
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_go_searching(turf/where)
	police_dealt = police_dealing
	police_spots_asked = 0
	police_looked = FALSE
	return ..()

/**
 * A place the police dealt it is looked at from where it stands: the places round it are other officers', or its own
 * next. Asked a second time in one search (the first is stealth_go_searching()'s), every spot has been looked at.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_search_spots(turf/center)
	police_spots_asked++
	if(police_spots_asked > 1)
		police_looked = TRUE
	if(police_dealt && center)
		return list(center)
	return ..()

// ----- hostages (owner decision 68) -----

/// Whether a standoff starting now finds it off its guard: it was on no hunt and no search until a moment ago
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_caught_cold()
	return police_onto_at && world.time - police_onto_at <= OUTPOST_POLICE_STANDOFF_COLD

/**
 * Only for the outpost's own people (its residents, staff and officers), awake: not a pet or a stranger brought in to
 * hide behind, and not a body. Someone awake struggles and gets loose in the end (ambient_escape); someone out cold
 * never would, and a wanted person could walk out behind them past every officer (abuse review, decision 68).
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_standoff_with(mob/living/holder, mob/living/hostage)
	if(!istype(hostage, /mob/living/carbon/human/npc/ambient_npc/outpost) || hostage.stat != CONSCIOUS)
		return FALSE
	if(police_standoff_left(holder) <= 0)
		return FALSE
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_standoff_start(mob/living/holder, mob/living/hostage)
	var/news = standoff_holder?.resolve() != holder || standoff_hostage?.resolve() != hostage
	. = ..()
	if(news)
		standoff_cold = police_caught_cold()
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
		if(istype(officer))
			officer.police?.standoff_begin(holder)

/// How long the squad still holds fire for `holder` (/datum/outpost_police/proc/standoff_left())
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_standoff_left(mob/living/holder)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer) || !officer.police)
		return OUTPOST_POLICE_STANDOFF_MAX
	return officer.police.standoff_left(holder)

// The minute ran out with the hostage still held: it says so as it stops holding fire
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_standoff_end(line)
	var/mob/living/holder = standoff_holder?.resolve()
	if(!line && holder && police_standoff_left(holder) <= 0 && stealth_hostage_of(holder))
		line = POLICE_LINE_HOSTAGE_TIMEOUT
	return ..()

/**
 * The first officer holds fire for `holder`: the squad's minute with them starts (OUTPOST_POLICE_STANDOFF_MAX). One
 * clock for the outpost, so the next officer to arrive, another hostage, or letting go and taking hold again buys
 * no more time (abuse review, decision 70).
 */
/datum/outpost_police/proc/standoff_begin(mob/living/holder)
	var/datum/mind/mind = holder?.mind
	if(!mind)
		return
	var/datum/weakref/mind_ref = WEAKREF(mind)
	if(!standoff_until[mind_ref])
		standoff_until[mind_ref] = world.time + OUTPOST_POLICE_STANDOFF_MAX

/// How long officers still hold fire for `holder`: all of it before any of them has, 0 once it has run out
/datum/outpost_police/proc/standoff_left(mob/living/holder)
	var/datum/mind/mind = holder?.mind
	if(!mind)
		return OUTPOST_POLICE_STANDOFF_MAX
	var/until = standoff_until[WEAKREF(mind)]
	return until ? max(0, until - world.time) : OUTPOST_POLICE_STANDOFF_MAX

/// Forgets the clock of someone no longer wanted here, a while after it ran out: wanted again, they get a new one
/datum/outpost_police/proc/prune_standoffs()
	for(var/datum/weakref/mind_ref as anything in standoff_until)
		var/datum/mind/mind = mind_ref.resolve()
		if(!mind || (world.time >= standoff_until[mind_ref] + OUTPOST_POLICE_STANDOFF_MAX && get_stars(mind) < 1))
			standoff_until -= mind_ref

// Its weapon goes down only for someone who caught it cold. Already after them, or looking for them, it keeps it and says so.
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_standoff_drop()
	if(standoff_cold)
		return ..()
	stealth_bark(POLICE_LINE_HOSTAGE_REFUSE)

// ----- no second look at someone the police are after (owner playtest 5) -----
// Stealth's guards take a second look at a stranger ("?", and a line for it) before they go for them. An officer said
// "Just a moment. What's that?" to someone it then batoned a second later: someone two stars up, with an arrest open
// on them, shoving its colleague in front of it.

/// Whether the police are already after `person`: an arrest is open on them, or units have been sent after them
/datum/outpost_police/proc/is_after(mob/living/person)
	if(!isliving(person) || !person.mind)
		return FALSE
	if(arrest_on(person))
		return TRUE
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat != DEAD && officer.dispatch_mind?.resolve() == person.mind)
			return TRUE
	return FALSE

/**
 * Whether `seen` is someone it goes for on sight: the police are already after them, or they are wanted and went for
 * somebody a moment ago (a colleague, a townsperson: OUTPOST_POLICE_FRESH_FIGHT); it has taken notice of them (the
 * same notice a second look would have started on); and it sees them plainly now: in its cone, in light it can use,
 * and not keeping still in cover.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_knows_on_sight(mob/living/seen)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer) || !isliving(seen) || QDELETED(seen) || !officer.police)
		return FALSE
	if(!officer.police.is_after(seen) && !officer.police.fought_within(seen, OUTPOST_POLICE_FRESH_FIGHT))
		return FALSE
	var/list/entry = notice_map[REF(seen)]
	if(isnull(entry) || entry[STEALTH_ENTRY_NOTICE] < STEALTH_SUSPICIOUS_AT)
		return FALSE
	var/turf/where = seen.loc
	return isturf(where) && stealth_sees(seen) && !stealth_covered(seen, where, get_dist(officer, where))

// The second look at a sighting: not for someone the police are after. A noise, a light on its back, a door or a
// body is looked into as before.
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_go_suspicious(turf/where, purpose = STEALTH_GOTO_INVESTIGATE, line = null)
	if(purpose == STEALTH_GOTO_INVESTIGATE && isnull(line))
		var/mob/living/seen = blackboard[BB_STEALTH_FOCUS]
		if(isliving(seen) && get_turf(seen) == where && police_knows_on_sight(seen))
			stealth_go_alert(seen)
			if(stealth_state() == STEALTH_ALERT)
				return
	return ..()

// Already looking into something (a noise, a glimpse) when someone the police are after comes into plain view: on
// them, without waiting for the second look to fill
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_look()
	. = ..()
	if(stealth_state() != STEALTH_SUSPICIOUS)
		return
	var/mob/living/seen = blackboard[BB_STEALTH_FOCUS]
	if(police_knows_on_sight(seen))
		stealth_go_alert(seen)

// Alert on a wanted person: that is who it is hunting until the police stand it down. Never on someone in hand.
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_go_alert(atom/target, named = TRUE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/mob/living/person = istype(officer) ? officer.police_mech_suspect(target) : (ismecha(target) ? bounty_ai_pilot_of(target) : target)
	if(istype(officer) && isliving(person) && officer.police?.has_in_hand(person, officer))
		return
	. = ..()
	if(isliving(person) && person.mind)
		police_hunt = WEAKREF(person.mind)

// Someone in hand is never a target, whoever set them: a blow from the cuffs makes the base's retaliation pick them
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/on_target_set(datum/source)
	SIGNAL_HANDLER
	var/atom/target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/mob/living/person = istype(officer) ? officer.police_mech_suspect(target) : (ismecha(target) ? bounty_ai_pilot_of(target) : target)
	if(istype(officer) && isliving(person) && officer.police?.has_in_hand(person, officer))
		clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		return
	..()
	police_clear_for_duty()
	if(isliving(person) && person.mind)
		police_hunt = WEAKREF(person.mind)

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_try_closet()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/obj/structure/closet/box = shut_in
	if(!istype(officer) || QDELETED(box))
		return ..()
	if(officer.force < POLICE_FORCE_LETHAL)
		closet_stuck = FALSE
		if(!officer.Adjacent(box) || HAS_TRAIT(officer, TRAIT_HANDS_BLOCKED) || officer.incapacitated)
			return
		var/mob/living/who = shut_who?.resolve()
		officer.face_atom(box)
		if(box.open(officer))
			stealth_drop_closet()
			stealth_bark(STEALTH_BARK_CLOSET_OPEN)
			if(isliving(who) && !QDELETED(who))
				if(isturf(who.loc))
					target_free_seen_at = world.time
					lost_since = 0
				else
					stealth_closet_alerted(who)
		return
	if(!officer.Adjacent(box) && officer.bystander_in_line(box))
		human_npc_sidestep(officer, box)
		return
	return ..()

/**
 * Stealth's lines are police lines: the same kind, as a context of AMBIENT_STRINGS_POLICE (outpost_police_stealth_line()),
 * said with police_say() and its gaps. A call to the others goes over the radio. `about` names the nearest shop.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_bark(kind, turf/about, name, always = FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer))
		return ..()
	if(officer.stat != CONSCIOUS || officer.client || officer.mind)
		return FALSE
	// Dispatch still has it after someone at large: the police send it on to look again, so it has not given up
	if(kind == STEALTH_BARK_GIVE_UP)
		var/datum/mind/sought = officer.dispatch_mind?.resolve()
		if(sought && officer.police?.get_stars(sought) >= 1 && !officer.police.has_in_hand(sought.current, officer))
			return FALSE
	// The last of the squad's minute with a hostage-taker: it says so (decision 70)
	if(kind == STEALTH_BARK_HOSTAGE)
		var/mob/living/holder = standoff_holder?.resolve()
		if(holder && police_standoff_left(holder) <= OUTPOST_POLICE_STANDOFF_WARNING)
			kind = POLICE_LINE_HOSTAGE_LAST
	if(!always && world.time < bark_ready_at[kind])
		return FALSE
	var/list/values = list()
	if(about)
		values["place"] = officer.police?.life_nearest_shop_name(about)
	if(name)
		values["name"] = name
	var/radio = (kind == STEALTH_BARK_RADIO_REPORT || kind == STEALTH_BARK_RADIO_ALARM || kind == STEALTH_BARK_RADIO_MISSING || kind == STEALTH_BARK_COPY)
	. = !isnull(officer.police_say(outpost_police_stealth_line(kind), values, radio))
	if(.)
		bark_ready_at[kind] = world.time + STEALTH_BARK_KIND_COOLDOWN

/// The police line context for stealth bark `kind`: the kind itself, but "lost" is the line the police already had
/proc/outpost_police_stealth_line(kind)
	if(kind == STEALTH_BARK_LOST)
		return POLICE_LINE_LOST
	return kind

/**
 * Its target went down (owner decisions 34 and 37): a wanted person down and alive, at any stars, is an arrest made
 * where they lie by the case (police_arrest.dm), by the nearest free stun officer or else by this one; one already in
 * our cuffs is someone else's arrest. Never stealth's "stay down" and a walk away. Anyone else down is stealth's as before.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_target_downed(mob/living/fallen)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer) || !officer.police)
		return ..()
	if(!officer.police.arrest_downed(fallen, officer) && !officer.police.has_in_hand(fallen, officer))
		return ..()
	// The cuffs are still to come: it stays by them until they are on
	if(officer.police.has_down(fallen, officer))
		police_cover(fallen)
		return
	police_let_go(fallen)

// ----- in hand (owner decision 58) -----
// Once the police have someone (cuffed, in a cell, or down with an arrest on them) the stealth play over them is
// done. Without these an officer went on losing them, searching for them, looking into the noise they made and
// calling alarms about them while a colleague walked them to the desk, and for a minute after they were in a cell.

/// Drops `who` as its target, focus and quarry and goes back to its beat without a word
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_let_go(mob/living/who)
	clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	clear_blackboard_key(BB_STEALTH_FOCUS)
	// The arrest drives the officer on it; anyone else is back to its beat. Nobody stays on alert over them.
	police_hunt = null
	police_drop_cover()
	stealth_go_unaware()

// ----- down, the cuffs still to come (owner decisions 34, 37 and 58) -----
// Someone down with an arrest on them is in hand, so nobody fights them, shouts about them or goes to look at the
// noise of their fall. But they are not held yet, and stamina comes back in seconds. Letting them go here sent every
// officer but the arresting one back to its beat, still on edge, and when the cuffing failed nobody was left on them.

/**
 * `who` is down with an arrest on them and the cuffs are still to come: it takes its aim off them but stays by them
 * (the outpost_police_cover subtree), and is on them at once if they get up first. Nobody goes on alert over someone
 * lying there (owner decision 37): it is unaware, and they are the one it stands over.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_cover(mob/living/who)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer) || !isliving(who) || !who.mind)
		return
	var/news = police_cover_ref?.resolve() != who.mind
	clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	clear_blackboard_key(BB_STEALTH_FOCUS)
	if(stealth_state() != STEALTH_UNAWARE)
		stealth_go_unaware()
	police_hunt = WEAKREF(who.mind)
	police_cover_ref = WEAKREF(who.mind)
	if(officer.police?.perception?.sees(officer, who))
		last_seen_turf = get_turf(who)
	if(news)
		stealth_bark(STEALTH_BARK_DOWNED)

/// Whoever it stands over, while they are still down with the cuffs to come; null once they are held, up or gone
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_covered()
	var/datum/mind/mind = police_cover_ref?.resolve()
	var/mob/living/who = mind?.current
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(isliving(who) && istype(officer) && officer.police?.has_down(who, officer))
		return who
	return null

/// It stands over nobody any more
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_drop_cover()
	police_cover_ref = null
	clear_blackboard_key(BB_OUTPOST_POLICE_COVER)

/**
 * Stands the officer over whoever it covers (police_cover()): within OUTPOST_POLICE_COVER_RANGE and in sight of
 * them, facing them, its weapon still in its hand, until the cuffs go on. With no sight of them it goes to where
 * the police last saw them, never to where they are (owner decision 52). The arrest's own officers are the case's
 * to move, and a fight or a search for someone else comes first. Up again before the cuffs, it is on them at once:
 * no second look and no search for someone it was standing over.
 */
/datum/ai_planning_subtree/outpost_police_cover

/datum/ai_planning_subtree/outpost_police_cover/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/controller, seconds_per_tick)
	if(!istype(controller))
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(officer) || officer.stat != CONSCIOUS || !officer.police)
		return
	// Whoever it was fighting has just gone down: what its next scan would do about that (stealth_keep_target()), now,
	// before the force subtree finds it with nobody to fight and puts its weapon away
	if(isnull(controller.police_cover_ref) && !officer.case && controller.stealth_state() == STEALTH_ALERT && controller.stealth_scanning())
		var/atom/remembered = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] || controller.blackboard[BB_STEALTH_FOCUS]
		var/mob/living/person = QDELETED(remembered) ? null : officer.police_mech_suspect(remembered)
		if(isliving(person) && person.mind && person.stat != DEAD && police_suspect_down(person) && !officer.police.finishes_downed(person, officer))
			controller.stealth_keep_target()
	if(isnull(controller.police_cover_ref))
		return
	var/mob/living/who = controller.police_covered()
	if(isnull(who))
		var/datum/mind/mind = controller.police_cover_ref.resolve()
		who = mind?.current
		controller.police_drop_cover()
		// Up again before the cuffs: in its sight it is on them; out of it, it looks where they were last seen
		if(isliving(who) && officer.police_will_fight(who))
			if(controller.stealth_has_in_view(who))
				officer.police_alert_on(who)
			else if(!officer.case && controller.stealth_state() == STEALTH_UNAWARE && !controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
				officer.police_search_for(who.mind)
		return
	if(officer.case || controller.stealth_state() != STEALTH_UNAWARE || controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	// On edge until the cuffs are on: it is not over yet (the all clear calms it)
	controller.stealth_set_wary()
	// All round, as for someone it is after (stealth_has_in_view()): standing over them, it does not need them in its cone
	var/seen = isturf(who.loc) && controller.stealth_alert_lit(who) && can_see(officer, who, HUMAN_NPC_SIGHT_RANGE)
	if(!seen)
		var/turf/known = officer.police.get_warrant(who.mind)?.last_seen_turf || controller.last_seen_turf
		if(known && !controller.stealth_walk_over(known))
			controller.stealth_walk(known, STEALTH_GOTO_SEARCH)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.last_seen_turf = get_turf(who)
	if(get_dist(officer, who) > OUTPOST_POLICE_COVER_RANGE)
		controller.stealth_drop_walk()
		controller.set_blackboard_key(BB_OUTPOST_POLICE_COVER, who)
		controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_OUTPOST_POLICE_COVER, OUTPOST_POLICE_COVER_RANGE)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.stealth_drop_walk()
	if(!HAS_TRAIT(officer, TRAIT_HANDS_BLOCKED) && !LAZYLEN(officer.do_afters) && isturf(officer.loc))
		officer.face_atom(who)
	return SUBTREE_RETURN_FINISH_PLANNING

/// On an arrest, leaving or riding a lift: nothing it hears sends it anywhere
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_busy()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	return istype(officer) && (officer.case || officer.npc_exit || officer.dispatch_riding)

/**
 * Someone in hand is nobody's target: it lets them go, whether or not it can see them. Someone a colleague has eyes
 * on is not lost either: it keeps closing in on them, with no "lost them" and no search of where it last saw them.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_keep_target()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/datum/outpost_police/police = istype(officer) ? officer.police : null
	var/atom/remembered = blackboard[BB_BASIC_MOB_CURRENT_TARGET] || blackboard[BB_STEALTH_FOCUS]
	var/mob/living/person = (police && !QDELETED(remembered)) ? officer.police_mech_suspect(remembered) : null
	if(!isliving(person) || !person.mind)
		return ..()
	if(police.has_in_hand(person, officer))
		// Held, it lets them go. Only down, the cuffs still to come, it stays by them.
		if(police.has_down(person, officer))
			police_cover(person)
		else
			police_let_go(person)
		return
	var/datum/outpost_warrant/warrant = police.get_warrant(person.mind)
	if(warrant?.last_seen_turf && !warrant.unseen_since && officer.police_will_fight(remembered) && !stealth_has_in_view(remembered))
		lost_since = 0
		last_seen_turf = warrant.last_seen_turf
		blackboard[BB_STEALTH_LAST_SEEN_AT] = world.time
		if(!blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
			set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, remembered)
		return
	return ..()

// A shove from the cuffs, a kick in the cell: the charge is the arrest's (police_arrest.dm). Nobody searches for, or
// shouts about, someone they are holding.
// Someone it has nothing on, right there in front of it (a shove, a fist, a thrown cup): a word to their face. What
// they did is the police's to count (a blow on an officer is a crime, and counted, it sets the officer on them);
// stealth's answer to a hand out of the dark was to search for someone it was looking at (owner decision 66).
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_touched(atom/source)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/mob/living/person = source
	// Anyone else's hand on it since is not explained by the one it holds
	police_held_touch_at = 0
	if(!istype(officer) || !officer.police || !isliving(person) || !(person.mind || person.client))
		return ..()
	if(officer.police.has_in_hand(person, officer))
		explained_at = world.time
		police_held_touch_at = world.time
		return FALSE
	if(!officer.police_will_fight(person) && officer.stat == CONSCIOUS && !officer.client && (get_dist(officer, person) <= 1 || officer.police.perception?.sees(officer, person)))
		explained_at = world.time
		if(!officer.buckled && !officer.case && isturf(officer.loc))
			officer.face_atom(person)
		officer.police_say(POLICE_LINE_KNOCK)
		return FALSE
	return ..()

// Put on the floor by someone the police hold (a shove from the cuffs, or in the cell): it knows who did it and where
// they are. It gets up without stealth's search for whoever did it (owner decision 58).
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_came_round()
	if(police_held_touch_at && world.time - police_held_touch_at <= OUTPOST_POLICE_HELD_TOUCH_MEMORY)
		return
	return ..()

// A colleague awake on the floor (shoved over, stunned, out of stamina, lying down) is not found as the fallen are:
// what put them there is a crime against an officer, and the police answer that (police_witness_saw()). Out cold or
// dead they are a body; awake in cuffs, someone to see to.
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_fallen(mob/living/member)
	. = ..()
	if(. == STEALTH_FALLEN_HELPLESS && !HAS_TRAIT(member, TRAIT_RESTRAINED))
		return null

// A gun aimed at an officer is no hold-up. Stealth's guards put their hands up when caught alone and unaware; an
// officer never does, and the aim is a crime of its own, so it turns on whoever holds the gun (owner decision 66).
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_holdup_refusal(mob/living/shooter)
	return "security"

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_held_up(mob/living/shooter)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(istype(officer) && isliving(shooter) && shooter.mind && officer.stat == CONSCIOUS && !officer.client && !holdup_aimer && !officer.police?.has_in_hand(shooter, officer))
		var/obj/item/gun/aimed = shooter.get_active_held_item()
		officer.police?.report_crime(shooter, OUTPOST_CRIME_THREATEN_OFFICER, officer, istype(aimed) ? aimed : null)
	return ..()

// Scav colours are the dens' disguise, not security's: nobody in them is taken for one of the squad
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_fooled(mob/living/who)
	return NONE

// On an arrest it walks past the fallen without starting a search of its own
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_check_bodies()
	if(police_busy())
		next_body_scan = world.time + STEALTH_BODY_SCAN_INTERVAL
		return
	police_know_cell_fallen()
	return ..()

/**
 * A colleague down on the floor or in the doorway of a cell that holds someone is no mystery: whoever did it is
 * locked in there. It is known to it, so it is not found as a body, searched over or called in (owner decision 58:
 * nobody goes on alert over someone in hand). The officer struck answers for itself (police_cell.dm struck_officer()).
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_know_cell_fallen()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/list/seen = blackboard[BB_STEALTH_BODIES_SEEN]
	if(isnull(group) || !islist(seen) || !istype(officer) || !length(officer.police?.cells))
		return
	for(var/mob/living/member as anything in group.living_members())
		if(member == officer || !isturf(member.loc))
			continue
		var/datum/outpost_police_cell/cell = officer.police.cell_at(member.loc)
		if(!cell || !length(cell.prisoners))
			continue
		var/key = REF(member)
		seen |= key
		group.reported_bodies |= key

/// The fallen of trouble that is over are known to it: it does not find them afresh and search for whoever did it
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_know_fallen()
	var/list/seen = blackboard[BB_STEALTH_BODIES_SEEN]
	if(isnull(group) || !islist(seen))
		return
	var/mob/living/officer = pawn
	for(var/mob/living/member as anything in group.living_members())
		if(member == officer)
			continue
		if(stealth_fallen(member))
			var/key = REF(member)
			seen |= key
			group.reported_bodies |= key

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_can_investigate()
	if(police_busy())
		return FALSE
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_go_heard(turf/where, again = FALSE)
	if(police_busy())
		return
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_glance(turf/where, time = STEALTH_GLANCE_TIME)
	if(police_busy())
		return
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_hold(turf/where)
	if(police_busy())
		return
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_respond(turf/where)
	if(police_busy())
		return FALSE
	return ..()

// ----- the public (owner decision 35) -----
// The concourse is a public place. Stealth's guards treat anyone they are not allied with as a stranger to look
// into; officers do not share a side with anyone (police_units.dm faction_check_atom()), so without these a
// visitor who only walks past makes them suspicious. Sight already goes through the police targeting strategy;
// these do the same for footsteps, everyday noises, doors and bumps. Loud trouble (gunfire, blasts, breaking glass,
// bashing, screams) still brings them to look, whoever made it.

/// Steps of someone the police have nothing on are not heard: their last-seen tile is kept current, so they never moved
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_hear_footsteps()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(istype(officer) && officer.police && length(heard_map))
		for(var/key in heard_map)
			var/mob/living/walker = locate(key)
			if(isliving(walker) && !officer.police_has_business(walker))
				heard_map[key] = get_turf(walker)
	return ..()

// Someone it has nothing on walking into it, or riding/pushing something into it, is no stranger in the dark: it's a crowd
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/on_bumped(atom/source, atom/movable/bumper)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!istype(officer))
		return ..()
	if(isliving(bumper))
		if(!officer.police_has_business(bumper))
			return
		return ..()
	if(!ismovable(bumper))
		return
	for(var/mob/living/inside in bumper.get_all_contents())
		if(officer.police_has_business(inside))
			stealth_touched(inside)
			return

// A brief passive pull in a crowd is no ambush (dispatch_check_pull() charges prolonged pulling); an aggressive grab still is
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/on_pulled(mob/living/source, atom/movable/puller)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/mob/living/living_puller = puller
	if(istype(officer) && isliving(living_puller) && living_puller.grab_state <= GRAB_PASSIVE && !officer.police_has_business(living_puller))
		return
	return ..()

// A friendly hand (a shake, a pat on the back) from someone it has nothing on; a hand in combat mode is still felt
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/on_handled(mob/living/source, mob/living/toucher)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(isliving(toucher) && !toucher.combat_mode && istype(officer) && !officer.police_has_business(toucher))
		return
	return ..()

/// The police of the outpost this group patrols, or null for any other stealth group
/datum/stealth_group/proc/outpost_police()
	return home ? get_trader_outpost_for_turf(home)?.police : null

// The outpost's doors are the public's: one moving is nobody's business (a forced door is a bash, and still heard)
/datum/stealth_group/door_is_theirs(key, turf/where, opening)
	if(outpost_police())
		return TRUE
	return ..()

/// Noises of everyday life at an outpost: nothing an officer looks into from someone they have nothing on
/proc/outpost_police_everyday_noise(kind)
	var/static/list/everyday = list(
		STEALTH_NOISE_DOOR = TRUE,
		STEALTH_NOISE_VOICE = TRUE,
		STEALTH_NOISE_KNOCK = TRUE,
		STEALTH_NOISE_THUD = TRUE,
		STEALTH_NOISE_CRUNCH = TRUE,
		STEALTH_NOISE_THROWN = TRUE,
	)
	return everyday[kind]

/// Whether `police` has any business with `actor` for group-wide everyday noise checks
/proc/outpost_police_group_has_business(datum/outpost_police/police, mob/living/actor)
	if(!isliving(actor) || !police)
		return FALSE
	if(actor.mind || actor.client)
		return police.force_level(actor) != POLICE_FORCE_NONE
	if(istype(actor, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		return FALSE
	if(isalien(actor) || istype(actor, /mob/living/basic/alien))
		return TRUE
	if(HAS_TRAIT(actor, TRAIT_OUTPOST_RESIDENT) || (FACTION_TURRET in actor.faction))
		return FALSE
	return is_hostile_creature(actor)

/datum/stealth_group/hear(turf/where, kind, reach, level, flags, mob/living/actor, door = FALSE)
	var/datum/outpost_police/police = (flags & STEALTH_NOISE_GROUP_ONLY) ? null : outpost_police()
	if(police)
		// A cell working its own door, and anything someone in hand does (a fall under the baton, a scream from the
		// cuffs, a fist on the cell glass): no officer goes to look (owner decision 58)
		var/obj/machinery/door/airlock/outpost/glass/police_cell/cell_door = door
		if(istype(cell_door) && cell_door.holding_cell?.driving_door)
			return 0
		if(isliving(actor) && police.has_in_hand(actor))
			return 0
		if(outpost_police_everyday_noise(kind) && (isnull(actor) || !outpost_police_group_has_business(police, actor)))
			return 0
	return ..()

/**
 * The turf to walk to now on the way to `dest`. Stealth walks to a tile beside `dest` when anything dense is on it;
 * a rail along a tile's edge is dense and in nobody's way, and the tile in front of Quartermain's and the Undertow's
 * checkpoint doors has two. Sent to it, an officer went and stood on the far side of the rail, one tile from the door
 * and nowhere near it, for good. A tile with nothing on it but rails is walked to itself.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_next_leg(turf/dest)
	. = ..()
	var/turf/here = get_turf(pawn)
	if(. == dest || isnull(here) || isnull(dest) || here.z != dest.z || get_dist(here, dest) > STEALTH_WALK_LEG || !isopenturf(dest))
		return
	for(var/atom/movable/thing as anything in dest)
		if(thing.density && !ismob(thing) && !(thing.flags_1 & ON_BORDER_1))
			return
	return dest

// =========================================================================
// ON THE OFFICER
// =========================================================================

/**
 * Whether this officer has any business with `who`: a person by their warrant or by a crime it saw itself; anyone
 * else (a creature, a resident) by whether the officer would fight them. A clean visitor or peaceful NPC is none of its business.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_has_business(mob/living/who)
	if(!isliving(who) || !police)
		return TRUE
	if(who.mind || who.client)
		return police.force_level(who, src) != POLICE_FORCE_NONE
	return police_will_fight(who)

/**
 * This officer saw `offender` commit a crime whose report waits on its call (police_wanted.dm queue_report()): it
 * acts on it now, alert on them at the force the crime gives (officer_knows()), and gets its call going.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_witness_saw(mob/living/offender)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = ai_controller
	if(!istype(brain) || !police || QDELETED(offender) || stat != CONSCIOUS || client)
		return
	brain.stealth_setup()
	// Someone in hand: the report is passed on quietly (police_perception.dm nudge_witness()), with no alert and no alarm
	if(police.has_in_hand(offender, src))
		return
	var/atom/fighting = brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(brain.stealth_state() == STEALTH_ALERT && !QDELETED(fighting))
		// Already fighting someone: it knows, and turns on them by stealth's own rules
		if(fighting != offender)
			brain.stealth_remember(offender)
	else if(!police_suspect_down(offender) || police.finishes_downed(offender, src))
		brain.stealth_go_alert(offender)
	if(offender.mind)
		brain.police_hunt = WEAKREF(offender.mind)
	if(stealth_radio_ready())
		brain.stealth_start_call(STEALTH_CALL_ALARM, get_turf(offender))

/// An arrest puts this officer on `suspect` (spec-stealth P5): alert on them, unless it is on them already
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_alert_on(mob/living/suspect)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = ai_controller
	if(!istype(brain) || QDELETED(suspect) || stat != CONSCIOUS || client)
		return
	// Someone down is cuffed, never fought: no alert over them (owner decision 37), unless the zone finishes them (39)
	if(isliving(suspect) && police_suspect_down(suspect) && !police?.finishes_downed(suspect, src))
		return
	if(brain.stealth_state() == STEALTH_ALERT && brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == suspect)
		return
	brain.stealth_setup()
	brain.stealth_go_alert(suspect)

/**
 * Nothing to fight or look for any more: back to unaware and its beat, as stealth has it (wary a while yet).
 * `calm`: the trouble is over for everyone (the all clear, the cuffs going on its own arrest). It is not left wary,
 * and a call it had its hand up for is not made; what it was waiting to report still counts.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_stand_easy(calm = FALSE)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = ai_controller
	if(!istype(brain) || QDELETED(src) || stat == DEAD)
		return
	brain.police_hunt = null
	brain.police_drop_cover()
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	if(brain.stealth_state() != STEALTH_UNAWARE)
		brain.stealth_go_unaware()
	if(!calm)
		return
	brain.clear_blackboard_key(BB_STEALTH_FOCUS)
	brain.notice_map?.Cut()
	brain.glance_until = 0
	if(brain.pending_call)
		brain.stealth_drop_call()
		if(stat == CONSCIOUS && !HAS_TRAIT(src, TRAIT_INCAPACITATED) && human_npc_can_talk(src) && stealth_radio_ready())
			police?.confirm_reports(src)
	brain.stealth_clear_wary()
	brain.stealth_meter_update()

/// A stood-down unit walking to a lift stands easy, holsters its weapons and keeps stealth's 60-step pathfinder
/mob/living/carbon/human/npc/ambient_npc/outpost/police/npc_walk_out(atom/exit, datum/callback/on_left)
	police_stand_easy()
	if(force != POLICE_FORCE_NONE)
		set_force(POLICE_FORCE_NONE)
	. = ..()
	if(.)
		var/datum/ai_controller/basic_controller/human_npc/stealth/brain = ai_controller
		if(istype(brain))
			QDEL_NULL(brain.meter)
			human_npc_set_ai_movement(brain, /datum/ai_movement/jps/stealth)

/**
 * Sends this officer to look for `mind` where the police last saw them (spec-stealth 1.4: arriving units, and a
 * search that ran out while the warrant still has stars). TRUE if it went.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_search_for(datum/mind/mind)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = ai_controller
	if(!istype(brain) || !mind || stat != CONSCIOUS || client || case || npc_exit)
		return FALSE
	var/datum/outpost_warrant/warrant = police?.get_warrant(mind)
	// The floor is still being read (the first second of the first hunt): asked again at the police's next tick
	if(police?.search_pending(warrant?.last_seen_turf, src))
		return FALSE
	// Only from where the police last saw them, or were told they were: never where they are now (owner decision 52).
	// From there the search works outward, a place to each officer (police_search.dm).
	var/turf/where = police?.search_place(warrant, src)
	if(!where)
		return FALSE
	brain.police_hunt = WEAKREF(mind)
	brain.police_research_at = world.time + OUTPOST_POLICE_RESEARCH_GAP
	brain.police_search_stamp = warrant.last_seen_at
	// The next place of a search already going is no new search: its lines keep their own time
	var/next_bark = brain.stealth_state() == STEALTH_SEARCHING ? brain.next_search_bark : 0
	brain.police_dealing = TRUE
	brain.stealth_go_searching(where)
	brain.police_dealing = FALSE
	if(next_bark)
		brain.next_search_bark = next_bark
	return TRUE

/// A beat officer with no route takes a free one: it walks to its first stop and claims it there
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_claim_route()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = ai_controller
	if(!istype(brain) || !brain.stealth_ready || brain.route_id || isnull(brain.group))
		return FALSE
	var/route = police?.free_route(brain.group)
	if(isnull(route))
		return FALSE
	var/datum/stealth_stop/first = brain.group.routes[route][1]
	brain.route_id = route
	brain.route_index = 1
	brain.route_step = 1
	brain.at_stop = FALSE
	brain.stop_fails.Cut()
	brain.stop_skip_until.Cut()
	brain.police_lost_route = null
	brain.home_turf = first.spot
	brain.stealth_drop_walk()
	return TRUE

// =========================================================================
// ROUTES AND STOPS (on the police)
// =========================================================================

/datum/outpost_police
	/// Patrol stop turf -> its police_activity tag ("" for none), read from the map's police patrol points
	var/list/stop_activities = list()

/// This outpost's patrol group, or null where the map has none
/datum/outpost_police/proc/patrol_group()
	var/turf/inside = desk_turf
	if(!inside && outpost?.template_bottom_left && outpost.outpost_template)
		var/turf/corner = outpost.template_bottom_left
		inside = locate(corner.x + round(outpost.outpost_template.width / 2), corner.y + round(outpost.outpost_template.height / 2), corner.z)
	return inside ? stealth_group_for(inside) : null

/// A route of `group` no living officer walks, or null
/datum/outpost_police/proc/free_route(datum/stealth_group/group)
	if(isnull(group))
		return null
	for(var/route in group.routes)
		if(length(group.routes[route]) && !outpost_police_route_taken(group, route))
			return route
	return null

/// The first stop of a route no living officer walks, or null (the beat role makes its officers there)
/datum/outpost_police/proc/free_route_start()
	var/datum/stealth_group/group = patrol_group()
	var/route = free_route(group)
	if(isnull(route))
		return null
	var/datum/stealth_stop/first = group.routes[route][1]
	return first.spot

/// Reads what is done at each of the outpost's patrol stops (from link_interior()); stop_tag() reads any it missed
/datum/outpost_police/proc/read_stop_tags()
	var/turf/corner = outpost?.template_bottom_left
	if(!corner || !outpost.outpost_template)
		return
	var/turf/far = locate(corner.x + outpost.outpost_template.width - 1, corner.y + outpost.outpost_template.height - 1, corner.z)
	if(!far)
		return
	for(var/turf/spot as anything in block(corner, far))
		// The map's box has corners the outpost does not fill. A patrol point lying out there on bare space was left by
		// whatever stood in this ground before (clearing reserved ground spares landmarks): it is no stop of this beat.
		if(isspaceturf(spot))
			continue
		var/obj/effect/landmark/stealth_patrol/police/point = locate() in spot
		if(point)
			stop_activities[spot] = point.police_activity || ""

/// The police go with their outpost, and so do their beat's stops: left behind, the points would outlive the ground
/// being cleared and turn up in whatever is built there next
/datum/outpost_police/Destroy()
	for(var/turf/spot as anything in stop_activities)
		for(var/obj/effect/landmark/stealth_patrol/police/point in spot)
			qdel(point)
	return ..()

/// The police_activity tag of the stop at `spot`, or null
/datum/outpost_police/proc/stop_tag(turf/spot)
	if(!spot)
		return null
	if(!(spot in stop_activities))
		var/obj/effect/landmark/stealth_patrol/police/point = locate() in spot
		stop_activities[spot] = point?.police_activity || ""
	var/tag = stop_activities[spot]
	return length(tag) ? tag : null

/// Whether a living member of `group` other than `except` walks `route`
/proc/outpost_police_route_taken(datum/stealth_group/group, route, mob/living/except)
	for(var/mob/living/member as anything in group.living_members())
		if(member == except || member.stat == DEAD)
			continue
		var/datum/ai_controller/basic_controller/human_npc/stealth/member_ai = member.ai_controller
		if(istype(member_ai) && member_ai.route_id == route)
			return TRUE
	return FALSE

/**
 * What `officer` does at a stop tagged `tag`, or null to stand: a word at a shop front, a coffee at the machine, a
 * chat with someone at hand, a seat on a bench, a look at the cells, the desk. "watch" (an untagged stop) is the
 * look in on a sleeper, which any stop but the desk does first, or else now and then a radio check-in.
 */
/datum/outpost_police/proc/stop_activity_for(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, tag)
	// Someone asleep on the floor nearby comes first: a look and a word to move along (police_life.dm), never at the desk
	if(tag != "desk")
		// Close enough that the spot beside them is reachable within the stop's reach
		var/mob/living/carbon/human/sleeper = officer.police_stop_sleeper()
		if(sleeper)
			return new /datum/ambient_activity/police_check(officer, sleeper)
		// Then a body on the floor in sight: called in to the desk, once a body
		var/mob/living/carbon/human/body = officer.life_body_near()
		if(body)
			return new /datum/ambient_activity/police_body(officer, body)
	switch(tag)
		if("shopfront")
			return new /datum/ambient_activity/police_shopfront(officer)
		if("coffee")
			var/obj/machinery/vending/coffee/machine = officer.police_stop_coffee_machine()
			if(machine)
				return new /datum/ambient_activity/police_coffee(officer, machine)
			// No machine at hand (Halcyon's diner stop has a coffee maker on its counter): a cup at the counter
			var/obj/structure/table/coffee_counter = officer.police_stop_counter()
			if(coffee_counter)
				return new /datum/ambient_activity/drink/police(officer, coffee_counter)
		if("bar")
			var/obj/structure/table/counter = officer.police_stop_counter()
			if(counter)
				return new /datum/ambient_activity/drink/police(officer, counter)
		if("chat")
			var/mob/living/partner = officer.police_chat_partner()
			if(partner)
				return new /datum/ambient_activity/chat(officer, partner)
		if("bench")
			for(var/obj/structure/chair/seat in range(OUTPOST_POLICE_STOP_REACH, officer))
				if(seat.z == officer.z && get_dist(seat, officer) <= OUTPOST_POLICE_STOP_REACH && officer.seat_usable(seat) && can_see(officer, seat, OUTPOST_POLICE_STOP_REACH + 1))
					return new /datum/ambient_activity/sit(officer, seat)
		if("cells")
			return new /datum/ambient_activity/police_cells(officer)
		if("desk")
			// Now and then a coffee from the machine by the desk, brought back to it
			var/obj/machinery/vending/coffee/desk_machine = world.time >= officer.next_desk_coffee ? officer.life_desk_coffee() : null
			if(desk_machine)
				officer.next_desk_coffee = world.time + rand(5 MINUTES, 10 MINUTES)
				return new /datum/ambient_activity/police_coffee(officer, desk_machine)
			return new /datum/ambient_activity/police_desk(officer)
		if("watch")
			// A plain stop on the beat: a sip of the coffee they carry, and now and then a word to the desk over the radio (police_life.dm)
			if(officer.held_item)
				outpost_police_sip(officer)
			officer.life_check_in()
	return null

/// A coffee at a counter on the beat, at a "bar" stop or a "coffee" stop with no machine: never a drink on duty
/datum/ambient_activity/drink/police
	name = "having a coffee at the bar"
	reagent_type = /datum/reagent/consumable/coffee
	duration_low = 20 SECONDS
	duration_high = 40 SECONDS

/datum/ambient_activity/drink/police/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = doer
	var/obj/structure/table/counter = anchor()
	if(!istype(officer) || !istype(counter))
		return FALSE
	var/obj/structure/chair/seat = officer.police_counter_seat(counter, failed_spots)
	if(seat)
		seat_ref = WEAKREF(seat)
		go_to(get_turf(seat))
	else
		var/turf/stand = officer.free_tile_beside(counter, 1, failed_spots)
		if(!stand || stand.z != officer.z || get_dist(stand, officer) > OUTPOST_POLICE_STOP_REACH)
			return FALSE
		go_to(stand)
	table_ref = WEAKREF(counter)
	set_duration()
	return TRUE

/// A sleeper near a beat stop with a free tile beside them inside `OUTPOST_POLICE_STOP_REACH`, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_stop_sleeper()
	for(var/mob/living/carbon/human/candidate in range(OUTPOST_POLICE_STOP_REACH - 1, src))
		if(!life_is_sleeper(candidate))
			continue
		if(LAZYACCESS(reaction_cooldowns, "check [REF(candidate)]") > world.time)
			continue
		if(!police?.perception?.sees(src, candidate))
			continue
		var/turf/stand = free_tile_beside(candidate, 1, null, TRUE)
		if(stand && stand.z == z && get_dist(stand, src) <= OUTPOST_POLICE_STOP_REACH)
			return candidate
	return null

/// A visible coffee machine within stop reach that has a standable spot inside stop reach, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_stop_coffee_machine()
	for(var/obj/machinery/vending/coffee/machine in range(OUTPOST_POLICE_STOP_REACH, src))
		if(!can_see(src, machine, OUTPOST_POLICE_STOP_REACH + 1))
			continue
		var/turf/stand = free_tile_beside(machine, 1)
		if(stand && stand.z == z && get_dist(stand, src) <= OUTPOST_POLICE_STOP_REACH)
			return machine
	return null

/// A usable seat right at `counter` within stop reach, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_counter_seat(obj/structure/table/counter, list/avoid)
	var/turf/center = get_turf(counter)
	if(!center)
		return null
	for(var/turf/tile as anything in RANGE_TURFS(1, center))
		if(tile.z != z || get_dist(tile, src) > OUTPOST_POLICE_STOP_REACH)
			continue
		for(var/obj/structure/chair/seat in tile)
			if(seat_usable(seat, avoid) && can_see(src, seat, OUTPOST_POLICE_STOP_REACH + 1))
				return seat
	return null

/// A visible counter table within stop reach with a seat or standing spot at hand, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_stop_counter()
	for(var/obj/structure/table/counter in range(OUTPOST_POLICE_STOP_REACH, src))
		if(!can_see(src, counter, OUTPOST_POLICE_STOP_REACH + 1))
			continue
		if(police_counter_seat(counter))
			return counter
		var/turf/stand = free_tile_beside(counter, 1)
		if(stand && stand.z == z && get_dist(stand, src) <= OUTPOST_POLICE_STOP_REACH)
			return counter
	return null

/// Someone at hand to talk to at a chat stop: a free townsperson in sight, or an officer idling at a stop of its own
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_chat_partner()
	for(var/mob/living/carbon/human/npc/ambient_npc/other in range(OUTPOST_POLICE_STOP_REACH, src))
		if(other == src || other.client || other.mind || !other.can_act() || HAS_TRAIT(other, TRAIT_AI_PAUSED))
			continue
		if(istype(other, /mob/living/carbon/human/npc/ambient_npc/outpost/trader) || istype(other, /mob/living/carbon/human/npc/ambient_npc/outpost/recovery))
			continue
		if(other.activity && !other.activity.accepts_company)
			continue
		if(!can_see(src, other, OUTPOST_POLICE_STOP_REACH + 1))
			continue
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = other
		if(istype(colleague))
			var/datum/ai_controller/basic_controller/human_npc/stealth/colleague_ai = colleague.ai_controller
			if(!istype(colleague_ai) || colleague_ai.stealth_state() != STEALTH_UNAWARE || !colleague_ai.at_stop || colleague.case || colleague.npc_exit || colleague.dispatch_riding || colleague.dispatch_responding())
				continue
		if(other.z == z && get_dist(src, other) <= 1 && Adjacent(other))
			return other
		var/turf/other_turf = get_turf(other)
		if(!other_turf)
			continue
		for(var/turf/tile as anything in RANGE_TURFS(1, other_turf))
			if(tile == other_turf || tile.z != z || get_dist(src, tile) > OUTPOST_POLICE_STOP_REACH)
				continue
			if(tile.Adjacent(other) && loiter_spot_ok(tile, null, other))
				return other
	return null

/// What a stop asks of it now: its tag while it waits at a stop, unaware with nothing else to do; "desk" for the sergeant at its post
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/police_stop_tag_now()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(!officer.police || stealth_state() != STEALTH_UNAWARE || blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return null
	if(officer.case || officer.npc_exit || officer.dispatch_riding || officer.dispatch_responding() || world.time < glance_until)
		return null
	if(route_id)
		if(!at_stop || world.time >= wait_until)
			return null
		// An untagged stop is watched from where they stand, unless someone sleeps nearby
		return officer.police.stop_tag(home_turf) || "watch"
	var/turf/desk = officer.police.desk_turf
	if(officer.unit_kind == POLICE_UNIT_SERGEANT && desk)
		// At the desk, or stepped over to the coffee machine beside it
		if(get_turf(officer) == desk || (istype(officer.activity, /datum/ambient_activity/police_coffee) && officer.z == desk.z && get_dist(officer, desk) <= OUTPOST_POLICE_STOP_REACH + 2))
			return "desk"
		// Gone over to a cell door to see a prisoner (police_bribe.dm)
		if(istype(officer.activity, /datum/ambient_activity/warden_bribe))
			return "desk"
	return null

/**
 * The life at a stop (spec-stealth 1.5): while it waits at a tagged stop, unaware and with nothing to do, the
 * stop's ambient activity runs with the ambient runner; when the wait ends the activity ends and the patrol walks
 * on. Anything else it is doing ends whatever activity it had.
 */
/datum/ai_planning_subtree/outpost_police_stop

/datum/ai_planning_subtree/outpost_police_stop/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(controller) || !istype(officer) || officer.stat != CONSCIOUS)
		return
	controller.police_take_route_back()
	var/tag = controller.police_stop_tag_now()
	if(isnull(tag))
		if(officer.activity)
			officer.end_activity()
		if(officer.buckled && officer.own_buckle(officer.buckled))
			officer.stand_up()
		if(officer.held_item && (controller.stealth_state() != STEALTH_UNAWARE || controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) || officer.case || officer.npc_exit || officer.dispatch_riding || officer.dispatch_responding()))
			officer.put_drink_down(null)
		return
	if(!officer.activity)
		// A stop's activity runs once a visit (a sentry's desk starts again when it ends)
		if(controller.route_id && controller.police_stop_visit == controller.wait_until)
			return
		controller.police_stop_visit = controller.wait_until
		officer.start_activity(officer.police.stop_activity_for(officer, tag))
		if(!officer.activity)
			return
	var/datum/ambient_activity/current = officer.activity
	if(!current.at_spot())
		var/turf/spot = get_turf(current.spot)
		// The walk to a cell door from the desk is longer than a stop's reach (police_bribe.dm)
		var/reach = istype(current, /datum/ambient_activity/warden_bribe) ? OUTPOST_POLICE_BRIBE_WALK_REACH : OUTPOST_POLICE_STOP_REACH
		if(!spot || spot.z != officer.z || get_dist(spot, officer) > reach)
			officer.end_activity()
			return
		controller.set_blackboard_key(BB_AMBIENT_DESTINATION, current.spot)
		controller.queue_behavior(current.spot_distance ? /datum/ai_behavior/travel_towards/ambient/adjacent : /datum/ai_behavior/travel_towards/ambient, BB_AMBIENT_DESTINATION)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.queue_behavior(/datum/ai_behavior/ambient_activity)
	return SUBTREE_RETURN_FINISH_PLANNING

// =========================================================================
// STARS DRIVE THE STATES (the police tick; spec-stealth 1.4)
// =========================================================================

/datum/outpost_police
	/// Whether anyone wanted was at large at the last tick: the tick that ends on is the all clear (stealth_tick_squad())
	var/stealth_trouble = FALSE

/**
 * Whether the police have `who` in hand: in custody (an arrest's cuffs or grip, or a cell), or with an arrest on them
 * and down or restrained, at the stars `officer` knows of. The exact cases police_will_fight() never fights a person in.
 * Nobody uses force on them, searches for them, goes on alert over them or looks into the noise they make. Whether the
 * trouble with them is over is has_secured(): someone only down (has_down()) can be up again in seconds.
 */
/datum/outpost_police/proc/has_in_hand(mob/living/who, mob/living/officer)
	if(!isliving(who) || !who.mind || who.stat == DEAD)
		return FALSE
	if(in_custody(who))
		return TRUE
	if(!arrest_on(who))
		return FALSE
	if(police_suspect_down(who))
		return !finishes_downed(who, officer)
	return HAS_TRAIT(who, TRAIT_RESTRAINED) && force_level(who, officer) < POLICE_FORCE_LETHAL

/**
 * Whether the police hold `who`: in custody (an arrest's cuffs or grip, or a cell), or tied up with an arrest on them.
 * The trouble with them is over: this, never a fall, is what the all clear waits for.
 */
/datum/outpost_police/proc/has_secured(mob/living/who, mob/living/officer)
	if(!isliving(who) || !who.mind || who.stat == DEAD)
		return FALSE
	if(in_custody(who))
		return TRUE
	return arrest_on(who) && HAS_TRAIT(who, TRAIT_RESTRAINED) && force_level(who, officer) < POLICE_FORCE_LETHAL

/// Whether `who` is in hand only because they are down (crit, stamina crit, a stun) with an arrest on them: the cuffs
/// are still to come, and until they are on the officers by them stay by them (police_cover())
/datum/outpost_police/proc/has_down(mob/living/who, mob/living/officer)
	return has_in_hand(who, officer) && !has_secured(who, officer)

/// Someone down with an arrest on them, the cuffs still to come, whom `officer` sees; or null
/datum/outpost_police/proc/stealth_down_seen(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	for(var/datum/mind/who in cases)
		var/mob/living/body = who.current
		if(has_down(body, officer) && perception?.sees(officer, body))
			return body
	return null

/// Whether anyone wanted at the outpost is still at large: not held (someone down with no cuffs on is not held yet)
/datum/outpost_police/proc/stealth_anyone_at_large()
	for(var/datum/outpost_warrant/warrant as anything in suspects_at_outpost())
		var/mob/living/body = warrant.mind?.current
		if(isliving(body) && body.stat != DEAD && !has_secured(body))
			return TRUE
	return FALSE

/// Once a second, before the officers (police_dispatch.dm tick_dispatch()): the tick the last wanted person at the
/// outpost is held (in cuffs or a cell), dead, gone or faded is the all clear
/datum/outpost_police/proc/stealth_tick_squad()
	prune_stances()
	var/trouble = stealth_anyone_at_large()
	if(stealth_trouble && !trouble)
		stealth_all_clear()
	stealth_trouble = trouble

/**
 * The all clear (owner decision 58): nobody wanted is at large any more (each is held, dead, gone or faded; one who
 * is only down is still at large, stealth_anyone_at_large()), so every officer stands down at once and
 * calm, whatever brought it (a colleague's shout, a radio call, a townsperson's scream, a search of its own), and the
 * noises of the trouble are forgotten, so the next one is a first noise again. An officer still fighting something,
 * or after someone only it knows of (a crime it saw and has not called in), is left to it.
 */
/datum/outpost_police/proc/stealth_all_clear()
	var/kept = FALSE
	var/list/datum/stealth_group/groups = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
		if(!istype(brain) || officer.stat == DEAD || officer.client)
			continue
		if(brain.group)
			groups |= brain.group
		var/atom/target = brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
		if(!QDELETED(target) && officer.police_will_fight(target))
			kept = TRUE
			continue
		var/datum/mind/hunted = brain.police_hunt?.resolve()
		var/mob/living/quarry = hunted?.current
		if(isliving(quarry) && force_level(quarry, officer) != POLICE_FORCE_NONE && !has_secured(quarry, officer))
			kept = TRUE
			continue
		officer.police_stand_easy(TRUE)
		brain.police_know_fallen()
	if(kept)
		return
	for(var/datum/stealth_group/group as anything in groups)
		group.forget_noises()

/**
 * Once a second for each officer (police_dispatch.dm tick_dispatch()): one the police set on someone with no stars
 * left (faded, booked, lifted) stands down to its beat; one sent after a wanted person whose search ran out looks
 * again, at most every OUTPOST_POLICE_RESEARCH_GAP; a beat officer with no route takes a free one.
 */
/datum/outpost_police/proc/stealth_tick_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	if(!istype(brain) || officer.stat != CONSCIOUS || officer.client || officer.case || officer.npc_exit || officer.dispatch_riding || officer.fading)
		return
	var/datum/mind/hunted = brain.police_hunt?.resolve()
	if(brain.police_hunt && (!hunted || force_level(hunted.current, officer) == POLICE_FORCE_NONE))
		brain.police_hunt = null
		var/atom/target = brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
		if(!QDELETED(target) && officer.police_will_fight(target))
			var/mob/living/next_suspect = officer.police_mech_suspect(target)
			if(isliving(next_suspect) && next_suspect.mind)
				brain.police_hunt = WEAKREF(next_suspect.mind)
		else if(brain.stealth_state() != STEALTH_UNAWARE)
			var/mob/living/target_mob = ismecha(target) ? bounty_ai_pilot_of(target) : target
			if(isnull(target) || ismecha(target) || (isliving(target_mob) && target_mob.mind == hunted))
				brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
				brain.stealth_go_unaware()
	// Someone down with an arrest on them, in its sight, the cuffs still to come: it stays by them with the rest
	if(isnull(brain.police_cover_ref) && !brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		var/mob/living/fallen = stealth_down_seen(officer)
		if(fallen)
			brain.police_cover(fallen)
		// Out of its sight, a search for them is over all the same: nobody looks for someone in hand (owner decision 58)
		else if(brain.stealth_state() == STEALTH_SEARCHING || brain.stealth_state() == STEALTH_SUSPICIOUS)
			var/mob/living/quarry = hunted?.current
			if(isliving(quarry) && has_down(quarry, officer))
				brain.police_let_go(quarry)
	var/datum/mind/assigned = officer.dispatch_mind?.resolve()
	// Someone down or in custody is the arrest's: nobody goes looking for them (owner decision 37)
	var/mob/living/assigned_body = assigned?.current
	if(isliving(assigned_body) && ((police_suspect_down(assigned_body) && !finishes_downed(assigned_body, officer)) || in_custody(assigned_body) || (HAS_TRAIT(assigned_body, TRAIT_RESTRAINED) && arrest_on(assigned_body) && force_level(assigned_body, officer) < POLICE_FORCE_LETHAL)))
		assigned = null
	if(assigned && get_stars(assigned) >= 1 && brain.stealth_state() == STEALTH_UNAWARE && !brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) && world.time >= brain.police_research_at)
		officer.police_search_for(assigned)
	else if(assigned && get_stars(assigned) >= 1)
		stealth_search_on(officer, brain, assigned)
	if(officer.unit_kind == POLICE_UNIT_BEAT && !assigned && isnull(brain.route_id) && brain.stealth_state() == STEALTH_UNAWARE)
		officer.police_claim_route()

/**
 * `officer` is searching for `sought`, whom dispatch has it after. With every spot of its search looked at, it is
 * dealt the next place (police_search.dm). A sighting fresher than the one it was sent from turns it to that. And on
 * its way to a place the police dealt it, its search does not run out. So the search widens until the stars are gone:
 * it used to be forty seconds within five tiles of one spot, a walk back to its post, and the same spot again.
 */
/datum/outpost_police/proc/stealth_search_on(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain, datum/mind/sought)
	if(brain.stealth_state() != STEALTH_SEARCHING || brain.calm_until || brain.search_for_body || brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	var/datum/outpost_warrant/warrant = get_warrant(sought)
	if(!warrant?.last_seen_turf)
		return
	if(brain.police_looked)
		// From where it stood to look: a place it could not get to was not looked round
		search_looked(warrant, officer, get_turf(officer))
		officer.police_search_for(sought)
		return
	if(warrant.last_seen_at > brain.police_search_stamp && world.time >= brain.police_redirect_at)
		// Lost again since: the search starts over from there. In someone's sight still: only if that is somewhere else.
		if(warrant.unseen_since || get_dist(search_start(warrant.last_seen_turf, officer), brain.search_center) > STEALTH_SEARCH_RADIUS)
			brain.police_redirect_at = world.time + 3 SECONDS
			officer.police_search_for(sought)
			return
	if(brain.police_dealt && world.time - brain.blackboard[BB_STEALTH_STATE_SINCE] > brain.stealth_skill().search_time - 5 SECONDS)
		brain.blackboard[BB_STEALTH_STATE_SINCE] = world.time
