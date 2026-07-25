/**
 * # Hoarfrost Matriarch - AI
 *
 * The megafauna attack rotation ported into the modern basic-mob framework, the
 * same way `code/modules/mob/living/basic/boss/thing/thing_ai.dm` does it: pick
 * one ability at random from the pool, never repeat the one used last, drop
 * anything that is not currently available, then optionally chain a follow-up.
 *
 * Everything else about her is deliberately ordinary - she walks up to you and
 * bites, which is what makes the telegraphed abilities read as events rather
 * than as background noise.
 *
 * The blackboard key strings live in this file and nowhere else. Her Initialize
 * hands the kit over through [/datum/ai_controller/basic_controller/hoarfrost_matriarch/proc/register_kit]
 * rather than setting keys itself, so the defines never have to be visible to
 * another file and the include order in the .dme cannot break anything.
 */

#define BB_HOARFROST_RIMEBREATH "BB_hoarfrost_rimebreath"
#define BB_HOARFROST_KILLING_COLD "BB_hoarfrost_killing_cold"
#define BB_HOARFROST_AVALANCHE "BB_hoarfrost_avalanche"
/// Key of the last ability used, excluded from the next roll.
#define BB_HOARFROST_LAST_ABILITY "BB_hoarfrost_last_ability"

/datum/ai_controller/basic_controller/hoarfrost_matriarch
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
		BB_AGGRO_RANGE = 9,
		BB_HOARFROST_LAST_ABILITY = null,
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/hoarfrost_rotation,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree/hoarfrost,
	)

/**
 * Publishes her kit onto the blackboard.
 *
 * Called from her Initialize, because the controller is built inside
 * /atom/Initialize - i.e. before she has created or granted a single action -
 * so the keys cannot simply be seeded in the `blackboard` list above.
 */
/datum/ai_controller/basic_controller/hoarfrost_matriarch/proc/register_kit(
	datum/action/cooldown/rimebreath,
	datum/action/cooldown/killing_cold,
	datum/action/cooldown/avalanche,
)
	set_blackboard_key(BB_HOARFROST_RIMEBREATH, rimebreath)
	set_blackboard_key(BB_HOARFROST_KILLING_COLD, killing_cold)
	set_blackboard_key(BB_HOARFROST_AVALANCHE, avalanche)

/**
 * The rotation. One ability per plan at most, never the same one twice running,
 * and nothing at all while she is planted for Killing Cold.
 */
/datum/ai_planning_subtree/hoarfrost_rotation
	/// She will not spend a cooldown on someone this far away - Rimebreath
	/// would fall short and the two self-centred abilities would simply be
	/// walked out of.
	var/engagement_range = 8

/datum/ai_planning_subtree/hoarfrost_rotation/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/hoarfrost_matriarch/matriarch = controller.pawn
	if(!istype(matriarch))
		return
	if(matriarch.inert)
		// Planted. No casting, no swinging, no shuffling - that is the whole
		// bargain that makes standing next to her a safe place to be.
		return SUBTREE_RETURN_FINISH_PLANNING
	if(matriarch.stat != CONSCIOUS)
		return

	var/atom/quarry = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(QDELETED(quarry))
		return
	if(isliving(quarry))
		var/mob/living/living_quarry = quarry
		if(living_quarry.stat == DEAD)
			return
	if(get_dist(matriarch, quarry) > engagement_range)
		return

	// Built fresh rather than filtered in place: removing from the list you are
	// iterating skips entries in DM, and the pool is three long anyway.
	var/static/list/kit = list(BB_HOARFROST_RIMEBREATH, BB_HOARFROST_KILLING_COLD, BB_HOARFROST_AVALANCHE)
	var/last_used = controller.blackboard[BB_HOARFROST_LAST_ABILITY]
	var/list/options = list()
	for(var/ability_key as anything in kit)
		if(ability_key == last_used)
			continue
		var/datum/action/cooldown/ability = controller.blackboard[ability_key]
		if(!ability?.IsAvailable())
			continue
		options += ability_key
	if(!length(options))
		return

	var/chosen_key = pick(options)
	controller.set_blackboard_key(BB_HOARFROST_LAST_ABILITY, chosen_key)
	controller.queue_behavior(/datum/ai_behavior/targeted_mob_ability, chosen_key, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/// She does not swing while she is planted.
/datum/ai_planning_subtree/basic_melee_attack_subtree/hoarfrost

/datum/ai_planning_subtree/basic_melee_attack_subtree/hoarfrost/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/hoarfrost_matriarch/matriarch = controller.pawn
	if(istype(matriarch) && matriarch.inert)
		return
	return ..()

#undef BB_HOARFROST_RIMEBREATH
#undef BB_HOARFROST_KILLING_COLD
#undef BB_HOARFROST_AVALANCHE
#undef BB_HOARFROST_LAST_ABILITY
