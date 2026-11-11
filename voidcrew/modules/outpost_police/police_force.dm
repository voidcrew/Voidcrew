/**
 * # Outpost police: force
 *
 * Owner: P4. Who officers fight and how hard: the targeting strategy, the weapon mode for the current target,
 * hold-fire and body-block rules, and looking for a suspect who got away. Spec 8. Every "does this officer
 * see that suspect" test outside the targeting strategy goes through police.perception.sees().
 */

/// Whom an officer fights. P0 stub: nobody.
/datum/targeting_strategy/basic/human_npc/outpost_police

/datum/targeting_strategy/basic/human_npc/outpost_police/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	return FALSE

/// The weapon mode for the current target, hold fire and body blocks
/datum/ai_planning_subtree/outpost_police_force

/datum/ai_planning_subtree/outpost_police_force/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	return

/// Walks to where a lost suspect was last seen and looks about
/datum/ai_planning_subtree/outpost_police_search

/datum/ai_planning_subtree/outpost_police_search/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	return

/// Baton out at ARREST, gun on disable at STUN, gun on kill at LETHAL (POLICE_FORCE_*)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/set_force(level)
	return
