/**
 * # Rescue & Repatriation
 *
 * "A survivor's beacon is still pinging inside that wreck. Bring them home alive."
 *
 * Recovery variant where the objective breathes: a survivor NPC spawns in
 * the target ruin, follows whoever asks (or rides a fireman carry), and the
 * mission turns in while they're alive beside the ship's mission pad.
 * Survivor death burns a retarget ("another beacon"). The non-gunner's
 * recovery mission.
 */
/datum/mission/rescue
	name = "Rescue Contract"
	weight = 8
	mission_limit = 2
	voucher_count = 0
	quest_lost_policy = MISSION_QUEST_LOST_RETARGET
	gps_tag_prefix = "RESQ"
	// The survivor cannot defend themselves, so this contract does not share a
	// wreck with a bounty's entourage or anybody else's spawns
	exclusive_site = TRUE
	// Green-band base pay
	value_min = 650
	value_max = 850

/datum/mission/rescue/setup_target()
	var/datum/mission_target/space_ruin/ruin_target = new(src)
	if(!ruin_target.resolve())
		qdel(ruin_target)
		return FALSE
	target = ruin_target
	return TRUE

/datum/mission/rescue/generate_details()
	var/static/list/survivor_stories = list(
		"salvage tech",
		"stranded courier",
		"survey intern",
		"claims adjuster",
		"freighter deckhand",
	)
	objective_name = pick(survivor_stories)

/datum/mission/rescue/build_objectives()
	add_objective(new /datum/mission_objective/field/escort)

/datum/mission/rescue/update_text()
	name = "Rescue Contract: [objective_name]"
	desc = "Bring [objective_name] home. Last signal at ([target.target_x], [target.target_y]) in the [target_zone_name]."

/datum/mission/rescue/waypoint_label()
	return "Rescue: [objective_name]"

/// Blackboard: who a rescue survivor follows
#define BB_MISSION_SURVIVOR_LEADER "mission_survivor_leader"

/**
 * # Mission Survivor
 *
 * The living objective: friendly, fragile, and clingy on request. A real human body (the human NPC
 * base, voidcrew/modules/human_npcs/): wounds, bleeding, crit, death and revival are a person's, and a
 * crew can fireman-carry, drag, bag or treat them like anyone. An empty hand while they are up and
 * about toggles follow; down, asleep or on fire it is tg's help (CPR, shaking awake, patting out
 * flames). They never fight back.
 *
 * The contract puts them inside wrecks, which are airless and near absolute zero: they have been
 * living in their emergency softsuit, helmet on and a tank on their back, and breathe from the tank
 * when the air is bad, as a person does. Their body is the mission's: the corpse cleanup never takes
 * it, since a dead survivor can still be brought back (the escort objective's revival window).
 */
/mob/living/carbon/human/npc/mission_survivor
	name = "survivor"
	desc = "Somebody who has had a very long week and would love to see a ship interior again. Their emergency softsuit is patched in three places and still holding."
	faction = list(FACTION_NEUTRAL)
	ai_controller = /datum/ai_controller/basic_controller/mission_survivor
	npc_outfit = /datum/outfit/mission_survivor
	npc_target_stat = HUMAN_NPC_SPARES_DOWNED
	npc_corpse_lifetime = 0
	/// Who the survivor is currently following, if anyone
	var/datum/weakref/following_ref

/// A freighter hand who has been living in the emergency softsuit from the wreck's locker
/datum/outfit/mission_survivor
	name = "Rescue survivor"
	uniform = /obj/item/clothing/under/color/grey
	suit = /obj/item/clothing/suit/space/fragile
	head = /obj/item/clothing/head/helmet/space/fragile
	mask = /obj/item/clothing/mask/breath
	back = /obj/item/tank/internals/oxygen
	shoes = /obj/item/clothing/shoes/sneakers/black
	internals_slot = ITEM_SLOT_BACK

/mob/living/carbon/human/npc/mission_survivor/Initialize(mapload, datum/human_npc_order/order)
	var/static/list/survivor_names = list("Adler", "Bex", "Cato", "Dova", "Emin", "Farrow", "Ines", "Jun", "Kest", "Loami")
	npc_name = "survivor ([pick(survivor_names)])"
	return ..()

/mob/living/carbon/human/npc/mission_survivor/Destroy()
	following_ref = null
	return ..()

// A dry, worn-out voice
/mob/living/carbon/human/npc/mission_survivor/get_default_say_verb()
	return "croaks"

/mob/living/carbon/human/npc/mission_survivor/examine(mob/user)
	. = ..()
	if(stat == DEAD)
		return
	var/mob/following = following_ref?.resolve()
	if(following)
		. += span_notice("They're sticking close to [following].")
	else
		. += span_notice("They look lost.")

/mob/living/carbon/human/npc/mission_survivor/attack_hand(mob/living/user, list/modifiers)
	if(user.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK) || stat != CONSCIOUS || on_fire || body_position != STANDING_UP || HAS_TRAIT(src, TRAIT_INCAPACITATED))
		return ..()
	var/mob/following = following_ref?.resolve()
	if(following == user)
		stop_following()
		balloon_alert(user, "waiting here")
		say("I'll... wait right here.")
	else
		start_following(user)
		balloon_alert(user, "following you")
		say("Right behind you. Please don't be wrong about the way out.")
	return TRUE

/mob/living/carbon/human/npc/mission_survivor/proc/start_following(mob/living/leader)
	following_ref = WEAKREF(leader)
	ai_controller?.set_blackboard_key(BB_MISSION_SURVIVOR_LEADER, leader)

/mob/living/carbon/human/npc/mission_survivor/proc/stop_following()
	following_ref = null
	ai_controller?.clear_blackboard_key(BB_MISSION_SURVIVOR_LEADER)

/mob/living/carbon/human/npc/mission_survivor/death(gibbed)
	stop_following()
	return ..()

/**
 * The survivor's brain: keeps up with whoever they follow, on their own feet. tg's basic controller
 * already stops it while they are down, stunned, asleep or carried, so a survivor in crit is a body
 * to carry, not one dragged along by a script.
 */
/datum/ai_controller/basic_controller/mission_survivor
	blackboard = list()
	ai_traits = PASSIVE_AI_FLAGS
	ai_movement = /datum/ai_movement/jps
	idle_behavior = null
	planning_subtrees = list(/datum/ai_planning_subtree/mission_survivor_follow)

/// Walks after their leader when more than a step behind, while the leader is near enough to follow
/datum/ai_planning_subtree/mission_survivor_follow

/datum/ai_planning_subtree/mission_survivor_follow/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/survivor = controller.pawn
	var/mob/living/leader = controller.blackboard[BB_MISSION_SURVIVOR_LEADER]
	if(QDELETED(leader) || leader.z != survivor.z || get_dist(survivor, leader) <= 1 || get_dist(survivor, leader) > 12)
		return
	controller.queue_behavior(/datum/ai_behavior/travel_towards/stop_on_arrival, BB_MISSION_SURVIVOR_LEADER)
	return SUBTREE_RETURN_FINISH_PLANNING

#undef BB_MISSION_SURVIVOR_LEADER
