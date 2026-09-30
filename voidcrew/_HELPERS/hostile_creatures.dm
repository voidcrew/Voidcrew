/**
 * Shared "would this creature start a fight" classification for automated defenses
 * (hull defense turrets, outpost enforcement turrets). Reads the creature's own AI
 * rather than its type or faction, so livestock, pets and passive fauna are left
 * alone while anything that goes looking for a target is treated as hostile.
 */

/// Planning subtrees that mean "this creature goes looking for something to attack".
GLOBAL_LIST_INIT(turret_aggressive_subtrees, typecacheof(list(
	/datum/ai_planning_subtree/simple_find_target,
	/datum/ai_planning_subtree/simple_find_wounded_target,
	/datum/ai_planning_subtree/find_target_prioritize_traits,
	/datum/ai_planning_subtree/aggressive_find_target,
)))

/// Subtrees that pick a target only to run away from it. Checked first, because
/// simple_find_target/to_flee is a subtype of an aggressive one and typecacheof()
/// covers subtypes.
GLOBAL_LIST_INIT(turret_fleeing_subtrees, typecacheof(list(
	/datum/ai_planning_subtree/simple_find_target/to_flee,
	/datum/ai_planning_subtree/simple_find_nearest_target_to_flee,
	/datum/ai_planning_subtree/find_nearest_thing_which_attacked_me_to_flee,
)))

/// Subtrees that only pick a fight once something has already picked one with them.
GLOBAL_LIST_INIT(turret_retaliating_subtrees, typecacheof(list(
	/datum/ai_planning_subtree/target_retaliate,
	/datum/ai_planning_subtree/capricious_retaliate,
)))

/**
 * Would this creature's own targeting strategy ever pick a person-sized mob?
 *
 * Stoats and crabs hunt, but only things strictly smaller than themselves - mice, roaches.
 * They cannot lay a finger on a person and are not what a turret is out here for. This
 * mirrors /datum/targeting_strategy/basic/of_size/can_attack() with the target's size
 * pinned to a person's, so it stays honest if that strategy gains more variants.
 */
/proc/creature_threatens_people(mob/living/creature)
	// No strategy to look up without a running controller: none at all, or a mob that has not
	// initialized yet, whose ai_controller is still a type path (a trader outpost's crew while
	// the outpost loads, with its turrets already scanning).
	var/datum/ai_controller/controller = creature.ai_controller
	var/strategy_type = istype(controller) ? controller.blackboard[BB_TARGETING_STRATEGY] : null
	var/datum/targeting_strategy/basic/of_size/sizer = strategy_type ? GET_TARGETING_STRATEGY(strategy_type) : null
	if(!istype(sizer)) // Anything not size-gated will take a swing at whatever it can reach.
		return TRUE
	if(sizer.inclusive && creature.mob_size == MOB_SIZE_HUMAN)
		return TRUE
	if(creature.mob_size > MOB_SIZE_HUMAN)
		return sizer.find_smaller
	return !sizer.find_smaller

/**
 * Would this creature start a fight on its own?
 *
 * A goat, a goose, an ant or a stoat has teeth and will use them if you shove it, but it
 * is not a threat and a turret has no business shooting it. What makes something a
 * threat is how its AI picks targets, not how hard it hits - a ranged trooper with no
 * melee attack at all is exactly what these are for.
 *
 * Read off the live planning subtrees rather than the mob's type, so a controller that
 * inherits its planning_subtrees from a parent (the viscerator, most of the trooper tree)
 * still classifies correctly. Subtree instances are shared singletons out of
 * GLOB.ai_subtrees, so this is a handful of list lookups.
 */
/proc/is_hostile_creature(mob/living/creature)
	// Outpost prisoners (outpost_prison_*.dm): left alone inside their wing, rioting or not;
	// once loose outside it they are fair game. Turrets players build use outpost_prison_security.dm instead.
	if(istype(creature, /mob/living/basic/outpost_prisoner))
		return is_loose_outpost_prisoner(creature)
	// Prison experiment creatures (outpost_prison_creatures.dm): fair game anywhere, like the
	// headslug, whose stock AI already reads as hostile. Their custom AI does not.
	if(istype(creature, /mob/living/basic/outpost_experiment))
		return is_outpost_experiment_turret_target(creature)
	// Bounty criminals, decoys and companions (voidcrew/modules/bounties/bounty_criminal.dm): trader-outpost
	// turrets leave them to the hunters, and no turret shoots a criminal already down, stunned or cuffed.
	if(istype(creature, /mob/living/basic/bounty_criminal) || istype(creature, /mob/living/basic/bounty_companion))
		if(bounty_turret_ignores(creature, istype(get_area(creature), /area/voidcrew/trader_outpost)))
			return FALSE
	// Bees from an outpost's own apiary never sting anyone (outpost_apiary.dm), but their
	// stock AI still carries the hunting subtree.
	if(istype(creature, /mob/living/basic/bee))
		var/mob/living/basic/bee/bee = creature
		if(bee.is_outpost_bee())
			return FALSE

	// The /hostile branch of the old simple animal tree is aggressive by definition; its
	// retaliate-only subtypes were all moved over to /mob/living/basic long ago.
	if(istype(creature, /mob/living/simple_animal/hostile))
		return TRUE

	// Somebody's pet, whatever its AI says. Cats and foxes both carry a full hunting
	// subtree - the cat's is for squabbling over territory with other cats - and would
	// otherwise read as aggressive.
	if(istype(creature, /mob/living/basic/pet))
		return FALSE

	if(!creature_threatens_people(creature))
		return FALSE

	var/datum/ai_controller/controller = creature.ai_controller
	if(!istype(controller)) // no AI, or not started yet (still a type path)
		return FALSE

	var/provoked = FALSE
	var/skittish = FALSE
	for(var/datum/ai_planning_subtree/subtree as anything in controller.planning_subtrees)
		if(GLOB.turret_fleeing_subtrees[subtree.type])
			skittish = TRUE
			continue
		if(GLOB.turret_aggressive_subtrees[subtree.type])
			return TRUE
		if(GLOB.turret_retaliating_subtrees[subtree.type])
			provoked = TRUE

	// Retaliators are left alone until they have actually settled on someone to maul, at
	// which point they are as much of a problem as anything else out there. Skittish mobs
	// are excluded because some of them park what they are running away from in the same
	// blackboard key an attacker would go in.
	return provoked && !skittish && !isnull(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET])
