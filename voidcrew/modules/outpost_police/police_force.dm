/**
 * # Outpost police: force
 *
 * Owner: P4. Who officers fight and how hard: the targeting strategy, the weapon mode for the current target,
 * hold-fire and body-block rules, and looking for a suspect who got away. Spec 8. Every "does this officer
 * see that suspect" test outside the targeting strategy goes through police.perception.sees().
 *
 * - Targeting (/datum/targeting_strategy/basic/human_npc/outpost_police): a person is a target only at STUN or
 *   LETHAL force by their warrant, and never in police custody; a stunned person is left for the cuffs. A
 *   creature by the old turret rule: xenos always, otherwise not on the outpost's side, not
 *   TRAIT_OUTPOST_RESIDENT, and is_hostile_creature(). A mech when anyone aboard is a target.
 * - Force (outpost_police_force subtree, set_force()): the baton at ARREST, the energy gun on disable at STUN
 *   and on kill at LETHAL or for a creature, switched with the gun's own select_fire(). The officer shoots
 *   through the human NPC base's shot (the real gun), but holds fire while anyone they would not shoot stands
 *   in the line (abuse M10), stepping aside instead.
 * - Body-blocking (M11): a person who stands in the line within 2 tiles of an officer firing to kill for
 *   OUTPOST_POLICE_BLOCK_TIME, or pulls an officer (police_dispatch.dm), resists, again every 5 seconds.
 * - Search (outpost_police_search subtree): an officer responding to a suspect they cannot shoot or do not see
 *   goes where the suspect was last seen, by lift if that is another sector, looks about, says so, and keeps
 *   looking nearby. At three stars a suspect seen last aboard a docked ship is waited for at its airlock.
 */

/// Where a searching officer is walking
#define BB_POLICE_DESTINATION "outpost_police_destination"
/// How long an officer looks about a spot before moving on
#define POLICE_LOOK_TIME (6 SECONDS)
/// How far from the last sighting an officer looks
#define POLICE_SEARCH_RADIUS 5

// =========================================================================
// TARGETING
// =========================================================================

/// Whom an officer fights. Policy in police_will_fight(); range, sight and the downed rule from the base.
/datum/targeting_strategy/basic/human_npc/outpost_police

/datum/targeting_strategy/basic/human_npc/outpost_police/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = living_mob
	if(!istype(officer) || !officer.police_will_fight(the_target))
		return FALSE
	return ..()

// A person shares no side with the police: their warrant decides (players' default faction is the officers' own)
/datum/targeting_strategy/basic/human_npc/outpost_police/faction_check(datum/ai_controller/controller, mob/living/living_mob, mob/living/the_target)
	if(the_target.mind || the_target.client)
		return FALSE
	return ..()

/**
 * Whether this officer would fight `target`, sight and range aside: a person by their warrant (STUN or LETHAL,
 * not in custody, not already stunned at STUN), a creature by the old turret rule, a mech by who is aboard.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_will_fight(atom/target)
	if(!police || QDELETED(target))
		return FALSE
	if(ismecha(target))
		var/obj/vehicle/sealed/mecha/mech = target
		for(var/mob/living/occupant in mech.occupants)
			if(police_will_fight(occupant))
				return TRUE
		return FALSE
	if(!isliving(target))
		return FALSE
	var/mob/living/living_target = target
	if(living_target == src || living_target.stat == DEAD)
		return FALSE
	if(istype(living_target, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
		return FALSE
	if(living_target.mind || living_target.client)
		if(police.in_custody(living_target))
			return FALSE
		var/level = police.force_level(living_target)
		if(level >= POLICE_FORCE_LETHAL)
			return TRUE
		if(level == POLICE_FORCE_STUN)
			// Down from the disabler already: the cuffs are the arrest's job
			return living_target.stat == CONSCIOUS && !HAS_TRAIT(living_target, TRAIT_INCAPACITATED) && !HAS_TRAIT(living_target, TRAIT_RESTRAINED)
		return FALSE
	// Wildlife, by the rule the outpost turrets had
	if(isalien(living_target) || istype(living_target, /mob/living/basic/alien))
		return TRUE
	if(faction_check_atom(living_target))
		return FALSE
	if(HAS_TRAIT(living_target, TRAIT_OUTPOST_RESIDENT))
		return FALSE
	return is_hostile_creature(living_target)

/// How hard they go at `target`: a person by their warrant, anything else to kill
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/force_for(atom/target)
	var/mob/living/living_target = target
	if(isliving(living_target) && (living_target.mind || living_target.client))
		return police?.force_level(living_target) || POLICE_FORCE_NONE
	return POLICE_FORCE_LETHAL

// =========================================================================
// FIRE DISCIPLINE
// =========================================================================

/**
 * The tiles a shot from `start_turf` at `end_turf` crosses. The one line helper of this module: the stealth merge swaps
 * it for human_npc_shot_path() (spec 18).
 */
/proc/outpost_police_shot_line(turf/start_turf, turf/end_turf)
	return get_line(start_turf, end_turf)

/**
 * Whoever stands in this officer's line of fire at `target` and is not someone they would shoot: anyone up
 * and living (shots pass over the lying). `within` > 0 looks only that many tiles out. Null if clear.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/bystander_in_line(atom/target, within = 0)
	var/turf/from = get_turf(src)
	var/turf/end_turf = get_turf(target)
	if(!from || !end_turf)
		return null
	for(var/turf/line_turf as anything in outpost_police_shot_line(from, end_turf))
		if(line_turf == from || line_turf == end_turf)
			continue
		if(within && get_dist(from, line_turf) > within)
			continue
		for(var/mob/living/other in line_turf)
			if(other == target || other.stat == DEAD || other.body_position == LYING_DOWN)
				continue
			if(police_will_fight(other))
				continue
			return other
	return null

/**
 * Abuse M11, once a second from dispatch: a person in the line of fire within 2 tiles of an officer firing to
 * kill, for OUTPOST_POLICE_BLOCK_TIME, resists; again each OUTPOST_POLICE_BLOCK_TIME they stay.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/check_body_block()
	var/mob/living/blocker
	var/atom/target = ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(force == POLICE_FORCE_LETHAL && stat == CONSCIOUS && !QDELETED(target))
		blocker = bystander_in_line(target, 2)
		if(blocker && !blocker.mind)
			blocker = null
	if(!blocker)
		dispatch_block_ref = null
		dispatch_block_since = 0
		return
	if(dispatch_block_ref?.resolve() != blocker)
		dispatch_block_ref = WEAKREF(blocker)
		dispatch_block_since = world.time
		return
	if(world.time - dispatch_block_since >= OUTPOST_POLICE_BLOCK_TIME)
		dispatch_block_since = world.time
		police?.report_crime(blocker, OUTPOST_CRIME_RESIST, src)

// =========================================================================
// FORCE
// =========================================================================

/**
 * The weapon mode for the current target, then the shot with fire discipline. With a person of one star (no
 * target: the arrest's job) or nothing to fight, the weapons go away. With no loaded gun it leaves the target
 * to the base's arm and melee subtrees (the baton).
 */
/datum/ai_planning_subtree/outpost_police_force

/datum/ai_planning_subtree/outpost_police_force/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(officer) || !officer.police)
		return
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!isnull(target) && !officer.police_will_fight(target))
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		target = null
	if(isnull(target))
		if(officer.force != POLICE_FORCE_NONE && !officer.case && !officer.dispatch_responding())
			officer.set_force(POLICE_FORCE_NONE)
		return
	var/level = officer.force_for(target)
	if(level != officer.force)
		officer.set_force(level)
	if(level < POLICE_FORCE_STUN || HAS_TRAIT(officer, TRAIT_HANDS_BLOCKED) || LAZYLEN(officer.do_afters))
		return
	if(isnull(human_npc_loaded_gun(officer)))
		return
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	var/fire_range = controller.blackboard[BB_HUMAN_NPC_FIRE_RANGE] || 7
	if(get_dist(officer, target) <= fire_range && strategy?.can_attack(officer, target, fire_range))
		var/keep_away = controller.blackboard[BB_HUMAN_NPC_KEEP_AWAY]
		if(keep_away && get_dist(officer, target) < keep_away)
			controller.queue_behavior(/datum/ai_behavior/step_away, BB_BASIC_MOB_CURRENT_TARGET)
		controller.queue_behavior(/datum/ai_behavior/human_npc_shoot/outpost_police, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	else
		controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_BASIC_MOB_CURRENT_TARGET, fire_range)
	return SUBTREE_RETURN_FINISH_PLANNING

/// The base's shot, held while a bystander is in the line (abuse M10): a step aside instead
/datum/ai_behavior/human_npc_shoot/outpost_police

/datum/ai_behavior/human_npc_shoot/outpost_police/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	var/atom/target = controller.blackboard[target_key]
	if(istype(officer) && !QDELETED(target) && officer.bystander_in_line(target))
		human_npc_sidestep(officer, target)
		return AI_BEHAVIOR_DELAY
	return ..()

/// Baton out at ARREST, gun on disable at STUN, gun on kill at LETHAL (POLICE_FORCE_*); both put away at NONE
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/set_force(level)
	force = level
	var/obj/item/baton = get_baton()
	var/obj/item/gun/energy/gun = get_sidearm()
	// The tactical officer's and the marshal's ballistic long gun (police_units.dm): theirs to kill with
	var/obj/item/gun/longgun = get_longgun()
	switch(level)
		if(POLICE_FORCE_ARREST)
			if(gun && is_holding(gun))
				gun.equip_to_best_slot(src)
			if(baton && police_draw(baton, longgun))
				human_npc_ready_weapon(src, baton)
		if(POLICE_FORCE_STUN)
			if(gun)
				outpost_police_set_gun_mode(gun, lethal = FALSE)
				police_draw(gun, longgun || baton)
				if(baton && is_holding(baton))
					baton.equip_to_best_slot(src)
		if(POLICE_FORCE_LETHAL)
			if(longgun)
				police_draw(longgun, gun || baton)
				for(var/obj/item/sidearm in list(gun, baton))
					if(is_holding(sidearm))
						sidearm.equip_to_best_slot(src)
			else if(gun)
				outpost_police_set_gun_mode(gun, lethal = TRUE)
				police_draw(gun, baton)
		else
			for(var/obj/item/weapon in list(gun, baton))
				if(is_holding(weapon))
					weapon.equip_to_best_slot(src)

/**
 * Takes `weapon` in hand, making room first: a routine's prop goes, then `stow` (the other weapon) goes back on
 * the belt. Returns TRUE if it is in hand.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_draw(obj/item/weapon, obj/item/stow)
	if(QDELETED(weapon))
		return FALSE
	if(is_holding(weapon))
		return TRUE
	if(!length(get_empty_held_indexes()))
		put_away_prop()
	if(!length(get_empty_held_indexes()) && stow && is_holding(stow))
		stow.equip_to_best_slot(src)
	if(!length(get_empty_held_indexes()))
		for(var/obj/item/held in held_items)
			if(held == weapon || held == stow)
				continue
			if(HAS_TRAIT(held, TRAIT_AMBIENT_PROP))
				qdel(held)
			else
				held.equip_to_best_slot(src)
			break
	return human_npc_take_in_hand(src, weapon)

/// Switches `gun` with its own select_fire() to its first disabling (`lethal` FALSE) or killing mode
/proc/outpost_police_set_gun_mode(obj/item/gun/energy/gun, lethal)
	if(!istype(gun) || length(gun.ammo_type) < 2)
		return
	for(var/i in 1 to length(gun.ammo_type))
		if(outpost_police_mode_lethal(gun) == lethal)
			return
		gun.select_fire(null)

/// Whether `gun`'s selected mode kills (brute or burn) rather than disables (stamina)
/proc/outpost_police_mode_lethal(obj/item/gun/energy/gun)
	var/obj/item/ammo_casing/energy/shot = gun.ammo_type[gun.select]
	var/obj/projectile/projectile_type = ispath(shot) ? initial(shot.projectile_type) : shot.projectile_type
	if(!ispath(projectile_type, /obj/projectile))
		return FALSE
	return initial(projectile_type.damage_type) != STAMINA && initial(projectile_type.damage) > 0

// =========================================================================
// SEARCH
// =========================================================================

/**
 * An officer responding to a suspect (dispatch_mind) with nothing to fight: to the suspect if they see them,
 * else to where they were last seen (at three stars aboard a docked ship, the ship's airlock), by lift when
 * that is another sector; there, they look about, say they lost them, and look again nearby.
 */
/datum/ai_planning_subtree/outpost_police_search

/datum/ai_planning_subtree/outpost_police_search/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(officer) || !officer.police || officer.case || officer.dispatch_riding || officer.npc_exit)
		return
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) || LAZYLEN(officer.do_afters))
		return
	var/datum/mind/mind = officer.dispatch_mind?.resolve()
	var/datum/outpost_police/police = officer.police
	var/datum/outpost_warrant/warrant = mind ? police.get_warrant(mind) : null
	if(!warrant)
		return
	var/mob/living/suspect = mind.current
	var/seen = isliving(suspect) && police.perception.sees(officer, suspect)
	var/turf/goal
	var/goal_distance = 1
	if(seen)
		goal = get_turf(suspect)
		goal_distance = 2
		officer.dispatch_search_from = null
		officer.dispatch_post = null
		officer.dispatch_search_until = 0
		officer.dispatch_lost_ref = null
	else
		var/list/held = police.dispatch_holds[mind]
		if(held && police.get_stars(mind) >= 3)
			goal = held[2]
		else
			goal = warrant.last_seen_turf
			if(goal && goal != officer.dispatch_search_from)
				officer.dispatch_search_from = goal
				officer.dispatch_post = null
				officer.dispatch_search_until = 0
			goal = officer.dispatch_post || goal
	if(!goal)
		return
	// Another sector: the lift
	var/my_sector = police.sector_of(officer)
	var/goal_sector = police.sector_of(goal)
	if(goal_sector != my_sector && goal_sector != POLICE_SECTOR_OUTSIDE)
		var/turf/lift = police.dispatch_nearest_lift_point(my_sector, officer)
		if(!lift)
			return
		if(get_turf(officer) == lift)
			controller.queue_behavior(/datum/ai_behavior/outpost_police_ride, goal_sector)
			return SUBTREE_RETURN_FINISH_PLANNING
		controller.set_blackboard_key(BB_POLICE_DESTINATION, lift)
		controller.queue_behavior(/datum/ai_behavior/travel_towards/outpost_police, BB_POLICE_DESTINATION)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(get_dist(officer, goal) > goal_distance)
		controller.set_blackboard_key(BB_POLICE_DESTINATION, goal)
		controller.queue_behavior(goal_distance > 1 ? /datum/ai_behavior/travel_towards/outpost_police/near : /datum/ai_behavior/travel_towards/outpost_police, BB_POLICE_DESTINATION)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(seen)
		return SUBTREE_RETURN_FINISH_PLANNING
	// There, and no sign of them: look about, then try somewhere close by
	if(!officer.dispatch_search_until)
		officer.dispatch_search_until = world.time + POLICE_LOOK_TIME
		if(officer.dispatch_lost_ref?.resolve() != mind)
			officer.dispatch_lost_ref = WEAKREF(mind)
			INVOKE_ASYNC(officer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), POLICE_LINE_LOST, null, FALSE)
	if(world.time < officer.dispatch_search_until)
		controller.queue_behavior(/datum/ai_behavior/outpost_police_look_about)
		return SUBTREE_RETURN_FINISH_PLANNING
	officer.dispatch_search_until = 0
	officer.dispatch_post = police_search_spot(police, officer.dispatch_search_from || goal, my_sector)
	return SUBTREE_RETURN_FINISH_PLANNING

/// A free tile of `sector` within POLICE_SEARCH_RADIUS of `around` to look from next, or null
/proc/police_search_spot(datum/outpost_police/police, turf/around, sector)
	if(!around)
		return null
	for(var/turf/spot as anything in shuffle(RANGE_TURFS(POLICE_SEARCH_RADIUS, around)))
		if(!isopenturf(spot) || isspaceturf(spot) || spot.is_blocked_turf() || police.sector_of(spot) != sector)
			continue
		return spot
	return null

/// Walks to the spot in the blackboard key; planning goes on meanwhile
/datum/ai_behavior/travel_towards/outpost_police
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION | AI_BEHAVIOR_MOVE_AND_PERFORM

/datum/ai_behavior/travel_towards/outpost_police/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target) || controller.current_movement_target != target)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	if(get_dist(controller.pawn, target) <= required_distance)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/// The same, stopping a couple of tiles short (closing on someone they can see)
/datum/ai_behavior/travel_towards/outpost_police/near
	required_distance = 2

/// Takes the lift they stand on to a sector (police.ride(), which sleeps, so it runs on its own)
/datum/ai_behavior/outpost_police_ride
	action_cooldown = 1 SECONDS

/datum/ai_behavior/outpost_police_ride/perform(seconds_per_tick, datum/ai_controller/controller, sector)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(officer) || !officer.police || officer.dispatch_riding)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	INVOKE_ASYNC(officer.police, TYPE_PROC_REF(/datum/outpost_police, ride), officer, sector)
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/// Turns to look one way and another
/datum/ai_behavior/outpost_police_look_about
	action_cooldown = 1.5 SECONDS

/datum/ai_behavior/outpost_police_look_about/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/officer = controller.pawn
	officer.setDir(pick(GLOB.cardinals))
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

#undef BB_POLICE_DESTINATION
#undef POLICE_LOOK_TIME
#undef POLICE_SEARCH_RADIUS
