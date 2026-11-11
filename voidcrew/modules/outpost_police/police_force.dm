/**
 * # Outpost police: force
 *
 * Owner: P4. Who officers fight and how hard: the targeting strategy, the weapon mode for the current target,
 * hold-fire and body-block rules, and looking for a suspect who got away. Spec 8. Every "does this officer
 * see that suspect" test outside the targeting strategy goes through police.perception.sees().
 *
 * - Targeting (/datum/targeting_strategy/basic/human_npc/outpost_police): a person is a target at ARREST, STUN or
 *   LETHAL force by their warrant, or by what this officer saw and has not yet got out on the radio
 *   (force_level(target, officer)), and never in police custody; a stunned person is left for the cuffs. The
 *   stealth scan judges only those (spec-stealth 1.3), so a clean visitor is never noticed. A creature by the old
 *   turret rule: xenos always, otherwise not on the outpost's side, not TRAIT_OUTPOST_RESIDENT, and
 *   is_hostile_creature(). A mech when anyone aboard is a target.
 * - Force (outpost_police_force subtree, set_force()): the baton at ARREST, the energy gun on disable at STUN
 *   and on kill at LETHAL or for a creature, switched with the gun's own select_fire(). At ARREST an officer
 *   with no case on that person stands and watches them: the arrest is the case's job. The officer shoots
 *   through the human NPC base's shot (the real gun), but holds fire while anyone they would not shoot stands
 *   in the line (abuse M10), stepping aside instead.
 * - Body-blocking (M11): a person who stands in the line within 2 tiles of an officer firing to kill for
 *   OUTPOST_POLICE_BLOCK_TIME, or pulls an officer (police_dispatch.dm), resists, again every 5 seconds.
 * - Looking for someone is stealth's searching state (stealth_ai.dm); dispatch sends officers to search
 *   (police_dispatch.dm) and the lift is taken inside the walk (police_stealth.dm, stealth_walk()).
 */

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
		var/level = police.force_level(living_target, src)
		if(level >= POLICE_FORCE_LETHAL)
			return TRUE
		if(level == POLICE_FORCE_STUN)
			// Down from the disabler already: the cuffs are the arrest's job
			return living_target.stat == CONSCIOUS && !HAS_TRAIT(living_target, TRAIT_INCAPACITATED) && !HAS_TRAIT(living_target, TRAIT_RESTRAINED)
		// One star: noticed, watched and arrested, never fought (the force subtree holds)
		return level == POLICE_FORCE_ARREST && !HAS_TRAIT(living_target, TRAIT_RESTRAINED)
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
		return police?.force_level(living_target, src) || POLICE_FORCE_NONE
	return POLICE_FORCE_LETHAL

// =========================================================================
// FIRE DISCIPLINE
// =========================================================================

/// The tiles a shot from `start_turf` at `end_turf` crosses: the human NPC base's own line (human_npc_ai.dm)
/proc/outpost_police_shot_line(turf/start_turf, turf/end_turf)
	return human_npc_shot_path(start_turf, end_turf)

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
 * kill, for OUTPOST_POLICE_BLOCK_TIME, resists; again each OUTPOST_POLICE_BLOCK_TIME they stay. Someone who cannot
 * move away (stunned, tied up, dragged, carried, logged off) never does (abuse SF2).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/check_body_block()
	var/mob/living/blocker
	var/atom/target = ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(force == POLICE_FORCE_LETHAL && stat == CONSCIOUS && !QDELETED(target))
		blocker = bystander_in_line(target, 2)
		if(blocker && !blocker.mind)
			blocker = null
		// Abuse SF2: only someone who chose to stand there resists, never the stunned, the tied up, the dragged or the logged off
		if(blocker && (blocker.incapacitated || HAS_TRAIT(blocker, TRAIT_RESTRAINED) || blocker.pulledby || blocker.buckled || (blocker.mind.key && !blocker.client)))
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
 * The weapon mode for the current target, then the shot with fire discipline. With nothing to fight the weapons go
 * away. A person of one star is the arrest's job: an officer with no case on them, baton out, stands and watches
 * (spec-stealth 1.3). With no loaded gun it leaves the target to the base's arm and melee subtrees (the baton).
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
	if(level == POLICE_FORCE_ARREST && !officer.case)
		if(!HAS_TRAIT(officer, TRAIT_HANDS_BLOCKED) && !LAZYLEN(officer.do_afters))
			officer.face_atom(target)
		controller.queue_behavior(/datum/ai_behavior/outpost_police_watch)
		return SUBTREE_RETURN_FINISH_PLANNING
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

/// Stands and keeps its eyes on its target: a one-star suspect it has no case on
/datum/ai_behavior/outpost_police_watch
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/outpost_police_watch/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/officer = controller.pawn
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(target) && officer.stat == CONSCIOUS && isturf(officer.loc) && !HAS_TRAIT(officer, TRAIT_HANDS_BLOCKED))
		officer.face_atom(target)
	return AI_BEHAVIOR_DELAY
