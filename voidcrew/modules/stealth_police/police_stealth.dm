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
		/datum/ai_planning_subtree/outpost_police_case,
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

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/UnpossessPawn(destroy)
	police_hunt = null
	return ..()

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
	return length(police.dispatch_lift_tiles(from_sector)) > 0 && length(police.dispatch_lift_tiles(to_sector)) > 0

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
	if(!length(police.dispatch_lift_tiles(from_sector)) || !length(police.dispatch_lift_tiles(to_sector)))
		if(here.z == dest.z && !istype(from_sector, /datum/outpost_berth) && !istype(to_sector, /datum/outpost_berth))
			return ..()
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
			return ..(gate_step, purpose)
	else
		police.clear_checkpoint_crossing(officer)
	var/next_ride_sector = police.next_elevator_sector(from_sector, to_sector)
	if(!next_ride_sector)
		return ..()
	var/board_sector = police.elevator_board_sector(from_sector)
	var/turf/lift = police.dispatch_nearest_elevator_point(board_sector, officer, officer)
	if(!lift)
		return ..()
	if(here != lift)
		if(isnull(goto_turf) || (police.dispatch_is_lift_tile(goto_turf) && goto_turf != lift))
			goto_turf = stealth_next_leg(lift)
		queue_behavior(/datum/ai_behavior/stealth_goto)
		return
	if(world.time < police_ride_retry_at)
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
	if(new_state != STEALTH_UNAWARE && officer.held_item)
		officer.put_drink_down(null)
	if(officer.case)
		human_npc_set_ai_movement(src, /datum/ai_movement/jps/stealth)

// Alert on a wanted person: that is who it is hunting until the police stand it down
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/stealth_go_alert(atom/target)
	. = ..()
	var/mob/living/person = ismecha(target) ? bounty_ai_pilot_of(target) : target
	if(isliving(person) && person.mind)
		police_hunt = WEAKREF(person.mind)

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/on_target_set(datum/source)
	SIGNAL_HANDLER
	..()
	var/atom/target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	var/mob/living/person = ismecha(target) ? bounty_ai_pilot_of(target) : target
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
	if(officer.stat != CONSCIOUS || officer.client)
		return FALSE
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
	if(!officer.police.arrest_downed(fallen, officer) && !(isliving(fallen) && fallen.stat != DEAD && officer.police.in_custody(fallen)))
		return ..()
	notice_map -= REF(fallen)
	clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	clear_blackboard_key(BB_STEALTH_FOCUS)
	// The arrest drives the officer on it; anyone else is back to its beat. Nobody stays on alert over them.
	police_hunt = null
	stealth_go_unaware()

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
	if(!(flags & STEALTH_NOISE_GROUP_ONLY) && outpost_police_everyday_noise(kind))
		var/datum/outpost_police/police = outpost_police()
		if(police && (isnull(actor) || !outpost_police_group_has_business(police, actor)))
			return 0
	return ..()

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

/// Nothing to fight or look for any more: back to unaware and its beat, as stealth has it (wary a while yet)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_stand_easy()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = ai_controller
	if(!istype(brain) || QDELETED(src) || stat == DEAD)
		return
	brain.police_hunt = null
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	if(brain.stealth_state() != STEALTH_UNAWARE)
		brain.stealth_go_unaware()

/**
 * Sends this officer to look for `mind` where the police last saw them (spec-stealth 1.4: arriving units, and a
 * search that ran out while the warrant still has stars). TRUE if it went.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_search_for(datum/mind/mind)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = ai_controller
	if(!istype(brain) || !mind || stat != CONSCIOUS || client || case || npc_exit)
		return FALSE
	var/datum/outpost_warrant/warrant = police?.get_warrant(mind)
	var/turf/where = warrant?.last_seen_turf || get_turf(mind.current)
	if(!where)
		return FALSE
	brain.police_hunt = WEAKREF(mind)
	brain.police_research_at = world.time + OUTPOST_POLICE_RESEARCH_GAP
	brain.stealth_go_searching(where)
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
		var/obj/effect/landmark/stealth_patrol/police/point = locate() in spot
		if(point)
			stop_activities[spot] = point.police_activity || ""

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
		// Close enough that the spot beside them is still within the stop's reach
		var/mob/living/carbon/human/sleeper = officer.life_sleeper_near(OUTPOST_POLICE_STOP_REACH - 1)
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
			var/obj/machinery/vending/coffee/machine = locate() in range(OUTPOST_POLICE_STOP_REACH, officer)
			if(machine)
				return new /datum/ambient_activity/police_coffee(officer, machine)
			// No machine at hand (Halcyon's diner stop has a coffee maker on its counter): a cup at the counter
			var/obj/structure/table/coffee_counter = locate() in range(OUTPOST_POLICE_STOP_REACH, officer)
			if(coffee_counter)
				return new /datum/ambient_activity/drink/police(officer, coffee_counter)
		if("bar")
			var/obj/structure/table/counter = locate() in range(OUTPOST_POLICE_STOP_REACH, officer)
			if(counter)
				return new /datum/ambient_activity/drink/police(officer, counter)
		if("chat")
			var/mob/living/partner = officer.police_chat_partner()
			if(partner)
				return new /datum/ambient_activity/chat(officer, partner)
		if("bench")
			for(var/obj/structure/chair/seat in range(OUTPOST_POLICE_STOP_REACH, officer))
				if(officer.seat_usable(seat))
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

/// Someone at hand to talk to at a chat stop: a townsperson, or an officer idling at a stop of its own
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_chat_partner()
	for(var/mob/living/carbon/human/npc/ambient_npc/other in range(OUTPOST_POLICE_STOP_REACH, src))
		if(other == src || other.stat != CONSCIOUS || other.fading || other.client)
			continue
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = other
		if(istype(colleague))
			var/datum/ai_controller/basic_controller/human_npc/stealth/colleague_ai = colleague.ai_controller
			if(!istype(colleague_ai) || colleague_ai.stealth_state() != STEALTH_UNAWARE || !colleague_ai.at_stop || colleague.case)
				continue
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
		if(get_turf(officer) == desk || (istype(officer.activity, /datum/ambient_activity/police_coffee) && get_dist(officer, desk) <= OUTPOST_POLICE_STOP_REACH + 2))
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
		if(!spot || get_dist(spot, officer) > OUTPOST_POLICE_STOP_REACH)
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
		var/mob/living/target_mob = ismecha(target) ? bounty_ai_pilot_of(target) : target
		if(brain.stealth_state() != STEALTH_UNAWARE && (isnull(target) || (isliving(target_mob) && target_mob.mind == hunted)))
			brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
			brain.stealth_go_unaware()
	var/datum/mind/assigned = officer.dispatch_mind?.resolve()
	// Someone down or in custody is the arrest's: nobody goes looking for them (owner decision 37)
	var/mob/living/assigned_body = assigned?.current
	if(isliving(assigned_body) && ((police_suspect_down(assigned_body) && !finishes_downed(assigned_body, officer)) || in_custody(assigned_body)))
		assigned = null
	if(assigned && get_stars(assigned) >= 1 && brain.stealth_state() == STEALTH_UNAWARE && !brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) && world.time >= brain.police_research_at)
		officer.police_search_for(assigned)
	if(officer.unit_kind == POLICE_UNIT_BEAT && !assigned && isnull(brain.route_id) && brain.stealth_state() == STEALTH_UNAWARE)
		officer.police_claim_route()
