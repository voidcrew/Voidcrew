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
	/**
	 * VOIDCREW: the old `planning_subtrees` list, as a behavior tree. Mapping:
	 * `escape_captivity` keeps its name; `target_retaliate` and `simple_find_target`
	 * both fold into the `acquire_target/update_combat_targets` leaf; the rotation is
	 * the subtree below; `attack_obstacle_in_path` is the `attack_obstructions` leaf;
	 * `basic_melee_attack_subtree/hoarfrost` is the melee leaf's subtype below; and
	 * `idle_behavior = /datum/idle_behavior/idle_random_walk` is the `random_walk`
	 * subtree, whose default walk chance of 25 is the value that idle behavior had.
	 */
	behavior_tree_json = "voidcrew/modules/mob/living/basic/hoarfrost/hoarfrost_matriarch.bt.json"

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
 *
 * VOIDCREW: this was `/datum/ai_planning_subtree/hoarfrost_rotation`. The pick itself is
 * unchanged; only the way it gets spent moved. `queue_behavior()` has no successor - a
 * leaf performs its own action now - so the roll writes the winner to BB_GENERIC_ACTION
 * and then hands the tick to [root], a `targeted_mob_ability` leaf built from the DM
 * descriptor below. The old returns map straight across:
 *
 *   bare `return`                          -> BT_FAILURE (fall through to the leaves behind us)
 *   `return SUBTREE_RETURN_FINISH_PLANNING` -> BT_RUNNING (nothing else happens this tick)
 */
/datum/bt_node/subtree/hoarfrost_rotation
	/// Spends whatever the rotation picked. resolve_node_children() builds `root` from this.
	behavior_nodes = list(
		BT_DESC_TYPE = /datum/bt_node/ai_behavior/targeted_mob_ability,
		"ability_key" = BB_GENERIC_ACTION,
		"target_key" = BB_CURRENT_TARGET,
	)
	/// She will not spend a cooldown on someone this far away - Rimebreath
	/// would fall short and the two self-centred abilities would simply be
	/// walked out of.
	var/engagement_range = 8

/datum/bt_node/subtree/hoarfrost_rotation/tick(datum/ai_controller/controller, seconds_per_tick)
	if(isnull(root))
		return BT_FAILURE
	// Mid-cast: the leaf casts asynchronously, so let it finish and keep everything
	// else off the tick until it does.
	if(root.has_active_descendants())
		return fire(controller, seconds_per_tick)

	var/mob/living/basic/hoarfrost_matriarch/matriarch = controller.pawn
	if(!istype(matriarch))
		return BT_FAILURE
	if(matriarch.inert)
		// Planted. No casting, no swinging, no shuffling - that is the whole
		// bargain that makes standing next to her a safe place to be.
		return BT_RUNNING
	if(IS_UNCONSCIOUS_OR_CRIT(matriarch))
		return BT_FAILURE

	var/atom/quarry = controller.blackboard[BB_CURRENT_TARGET]
	if(QDELETED(quarry))
		return BT_FAILURE
	if(isliving(quarry))
		var/mob/living/living_quarry = quarry
		if(living_quarry.stat == DEAD)
			return BT_FAILURE
	if(get_dist(matriarch, quarry) > engagement_range)
		return BT_FAILURE

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
		return BT_FAILURE

	var/chosen_key = pick(options)
	controller.set_blackboard_key(BB_HOARFROST_LAST_ABILITY, chosen_key)
	controller.set_blackboard_key(BB_GENERIC_ACTION, controller.blackboard[chosen_key])
	return fire(controller, seconds_per_tick)

/**
 * Runs the cast leaf. Anything short of an outright refusal ends the tick the way the
 * old FINISH_PLANNING did; a refusal falls through so the obstruction and melee leaves
 * behind us still get their turn, which is what the old bare `return` bought.
 */
/datum/bt_node/subtree/hoarfrost_rotation/proc/fire(datum/ai_controller/controller, seconds_per_tick)
	return (root.tick(controller, seconds_per_tick) == BT_FAILURE) ? BT_FAILURE : BT_RUNNING

/// She does not swing while she is planted.
/datum/bt_node/ai_behavior/basic_melee_attack/hoarfrost

/datum/bt_node/ai_behavior/basic_melee_attack/hoarfrost/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/hoarfrost_matriarch/matriarch = controller.pawn
	if(istype(matriarch) && matriarch.inert)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	return ..()

/**
 * ...and she does not shuffle towards you either.
 *
 * VOIDCREW: movement used to ride inside the melee subtree, so the rotation's
 * FINISH_PLANNING froze it for free. It is a parallel sibling of the attack branch now,
 * ticked every cycle regardless, so the planted check has to be repeated here. Holding
 * the tick (bare INSTANT) rather than failing is deliberate: a failure would fail the
 * whole combat branch and drop her into the idle wander branch instead.
 */
/datum/bt_node/ai_behavior/move_to_target/hoarfrost

/datum/bt_node/ai_behavior/move_to_target/hoarfrost/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/hoarfrost_matriarch/matriarch = controller.pawn
	if(istype(matriarch) && matriarch.inert)
		return AI_BEHAVIOR_INSTANT
	return ..()

#undef BB_HOARFROST_RIMEBREATH
#undef BB_HOARFROST_KILLING_COLD
#undef BB_HOARFROST_AVALANCHE
#undef BB_HOARFROST_LAST_ABILITY
