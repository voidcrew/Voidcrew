/**
 * # Human NPC surrender (N2)
 *
 * Giving up is an AI choice followed by the same action a player takes (defaults 1.3, decision D3):
 * 1. The NPC weighs its odds (a /datum/human_npc_surrender on its npc_surrender: how hurt it is, how many
 *    hostiles are on it, how many friends are still standing).
 * 2. On a yes it stows the weapons in its hands in its own belt, bag, holster or suit storage. Its gear
 *    is locked (D3), so it never drops them; one with nowhere to put a gun keeps holding it, hands blocked.
 * 3. It says its surrender line and runs tg's *surrender emote, a real 20 second Paralyze. That is the
 *    cuff window: tg cuffs (4 s) work on it like on anyone.
 * 4. When the Paralyze ends and nobody cuffed it, it decides again at once: give up again, or (if its
 *    rules say so) run from the nearest hostile for a while, or fight on.
 * There is no surrender state, trait or mark: what players see and act on is tg's Paralyze and cuffs.
 *
 * A family picks the numbers with a subtype, and overrides hurt_enough(), should_consider() or odds()
 * for its own rules (the kingpin only once his crew is down; convicts the moment they are sighted, so
 * hurt_enough() is always TRUE for them). Code that wants an NPC to give up at once calls
 * npc_surrender() itself.
 */

/// A family's surrender rules. One shared instance per type (human_npc_singleton()).
/datum/human_npc_surrender
	/// Percent chance on the first roll of a fight
	var/chance = 60
	/// Percent chance on later rolls
	var/retry_chance = 25
	/// Percent taken off the chance for each friend still standing near it
	var/ally_penalty = 20
	/// It considers giving up only at or below this share of its health
	var/health_share = 0.4
	/// ...and only with at least this many hostiles near it
	var/hostiles_needed = 2
	/// How far it looks for hostiles and friends, in tiles
	var/range = 7
	/// Time between two rolls
	var/retry_delay = 5 SECONDS
	/// When a surrender's paralysis ends uncuffed and it decides not to give up again: run (TRUE), or fight on
	var/flees = TRUE
	/// How long it runs for
	var/flee_time = 20 SECONDS

/// Whether `npc` is in a bad enough way to think about giving up. Cheap: checked before it looks around.
/datum/human_npc_surrender/proc/hurt_enough(mob/living/carbon/human/npc/npc)
	return npc.health <= npc.maxHealth * health_share

/// Whether, having looked around, it thinks about giving up.
/datum/human_npc_surrender/proc/should_consider(mob/living/carbon/human/npc/npc, list/hostiles, list/allies)
	return length(hostiles) >= hostiles_needed

/// Percent chance it gives up on this roll. `first` is TRUE for its first roll of the fight.
/datum/human_npc_surrender/proc/odds(mob/living/carbon/human/npc/npc, list/hostiles, list/allies, first)
	if(!length(hostiles))
		return 0
	return clamp((first ? chance : retry_chance) - ally_penalty * length(allies), 0, 100)

/// The living hostiles near `npc` that are still in the fight and that it can see.
/datum/human_npc_surrender/proc/hostiles_near(mob/living/carbon/human/npc/npc)
	. = list()
	for(var/mob/living/other in oview(range, npc))
		if(other.faction_check_atom(npc) || human_npc_out_of_fight(other))
			continue
		if(other.client || other.ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == npc || npc.ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == other)
			. += other

/// Its friends near it that are still standing.
/datum/human_npc_surrender/proc/allies_near(mob/living/carbon/human/npc/npc)
	. = list()
	for(var/mob/living/other in oview(range, npc))
		if(other.client || !npc.faction_check_atom(other) || human_npc_out_of_fight(other))
			continue
		if(other.body_position == LYING_DOWN)
			continue
		. += other

/// The rules it surrenders by, or null if it never does.
/mob/living/carbon/human/npc/proc/npc_surrender_rules()
	if(!ispath(npc_surrender, /datum/human_npc_surrender))
		return null
	return human_npc_singleton(npc_surrender)

/**
 * Gives up now, the way a player does: weapons stowed, its surrender line, tg's *surrender (a 20 second
 * Paralyze). Returns TRUE if it is lying there with its hands on its head.
 */
/mob/living/carbon/human/npc/proc/npc_surrender()
	if(stat != CONSCIOUS || HAS_TRAIT(src, TRAIT_RESTRAINED) || npc_surrendering)
		return FALSE
	npc_stow_weapons()
	npc_bark(HUMAN_NPC_BARK_SURRENDER, force = TRUE)
	npc_surrendering = TRUE
	emote("surrender", intentional = TRUE)
	if(!IsParalyzed())
		npc_surrendering = FALSE
		return FALSE
	npc_surrender_count++
	SEND_SIGNAL(src, COMSIG_HUMAN_NPC_SURRENDERED)
	return TRUE

/// Puts the weapons in its hands away on its body. D3: never on the floor.
/mob/living/carbon/human/npc/proc/npc_stow_weapons()
	for(var/obj/item/held in held_items)
		if(isgun(held) || human_npc_is_melee_weapon(held))
			held.equip_to_best_slot(src)

/// Its surrender's paralysis is over. Cuffed: taken, nothing to decide. Otherwise it decides again.
/mob/living/carbon/human/npc/proc/npc_surrender_ended()
	if(IsParalyzed())
		return
	npc_surrendering = FALSE
	if(stat != CONSCIOUS || HAS_TRAIT(src, TRAIT_RESTRAINED))
		return
	npc_surrender_redecide = TRUE
	SEND_SIGNAL(src, COMSIG_HUMAN_NPC_SURRENDER_ENDED)

/**
 * Rolls to give up when its rules say it is losing, and decides again straight after a surrender
 * nobody took. Put it after escape_captivity and before targeting in any controller whose pawn is a
 * human NPC.
 */
/datum/ai_planning_subtree/human_npc_surrender

/datum/ai_planning_subtree/human_npc_surrender/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/npc = controller.pawn
	if(!ishumannpc(npc) || npc.stat != CONSCIOUS || HAS_TRAIT(npc, TRAIT_RESTRAINED))
		return
	var/datum/human_npc_surrender/rules = npc.npc_surrender_rules()
	if(isnull(rules))
		return
	// Running after walking away from a surrender.
	if(world.time < controller.blackboard[BB_HUMAN_NPC_FLEE_UNTIL] && controller.blackboard_key_exists(BB_HUMAN_NPC_FLEE_FROM))
		controller.queue_behavior(/datum/ai_behavior/run_away_from_target, BB_HUMAN_NPC_FLEE_FROM)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/redecide = npc.npc_surrender_redecide
	if(!redecide && (world.time < npc.npc_next_surrender_roll || !rules.hurt_enough(npc)))
		return
	// Looking around costs, so it looks at most once per retry_delay.
	npc.npc_next_surrender_roll = world.time + rules.retry_delay
	npc.npc_surrender_redecide = FALSE
	var/list/hostiles = rules.hostiles_near(npc)
	var/list/allies = rules.allies_near(npc)
	if(!redecide && !rules.should_consider(npc, hostiles, allies))
		return
	var/first = !npc.npc_surrender_rolls
	npc.npc_surrender_rolls++
	if(prob(rules.odds(npc, hostiles, allies, first)))
		controller.queue_behavior(/datum/ai_behavior/human_npc_surrender)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(redecide && rules.flees && length(hostiles))
		controller.set_blackboard_key(BB_HUMAN_NPC_FLEE_FROM, get_closest_atom(/mob/living, hostiles, npc))
		controller.set_blackboard_key(BB_HUMAN_NPC_FLEE_UNTIL, world.time + rules.flee_time)
		controller.queue_behavior(/datum/ai_behavior/run_away_from_target, BB_HUMAN_NPC_FLEE_FROM)
		return SUBTREE_RETURN_FINISH_PLANNING

/// Gives up (npc_surrender()).
/datum/ai_behavior/human_npc_surrender

/datum/ai_behavior/human_npc_surrender/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/carbon/human/npc/npc = controller.pawn
	if(!ishumannpc(npc) || !npc.npc_surrender())
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
