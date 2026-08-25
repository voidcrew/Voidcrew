/**
 * # Recovery Mission
 *
 * Targets a live space ruin: the bound quest item spawns inside when the
 * interior loads, and comes home to the mission pad. Objectives:
 * [plant the quest item] -> [carry it home].
 *
 * Ruin lifetime handling (retargets, stranding) lives on the mission shell
 * and the space_ruin target datum; this file is generation and flavor.
 */
/datum/mission/recovery
	name = "Recovery Contract"
	weight = 10
	mission_limit = 3
	voucher_count = 1
	quest_lost_policy = MISSION_QUEST_LOST_RETARGET
	gps_tag_prefix = "RCVRY"
	// Green-band pay; the zone table scales it up
	value_min = 700
	value_max = 1000

/datum/mission/recovery/setup_target()
	var/datum/mission_target/space_ruin/ruin_target = new(src)
	if(!ruin_target.resolve())
		qdel(ruin_target)
		return FALSE
	target = ruin_target
	return TRUE

/datum/mission/recovery/generate_details()
	var/static/list/recovery_items = list(
		"flight recorder",
		"encrypted data core",
		"sealed sample crate",
		"prototype targeting module",
		"salvaged ship ledger",
	)
	objective_name = pick(recovery_items)

/datum/mission/recovery/build_objectives()
	add_objective(new /datum/mission_objective/field/plant_quest)
	add_objective(new /datum/mission_objective/deliver/bound)

/datum/mission/recovery/update_text()
	name = "Recovery Contract: [objective_name]"
	desc = "Recover the [objective_name] from the signal at ([target.target_x], [target.target_y]) in the [target_zone_name], and return it to the mission pad. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive the objective's beacon ([gps_tag])."

/datum/mission/recovery/waypoint_label()
	return "Recovery: [objective_name]"

/datum/mission/recovery/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target.target_x
	data["target_y"] = target.target_y
	return data

/**
 * # Proof-of-Kill Mission
 *
 * Recovery variant: a named target mob is spawned in the ruin; killing it
 * drops an identification tag, which is the turn-in item. Objectives:
 * [eliminate the name] -> [carry the tag home].
 */
/datum/mission/recovery/kill
	name = "Kill Contract"
	weight = 8
	mission_limit = 2
	gps_tag_prefix = "HUNT"

	/// Mob type pools per difficulty (space-capable faction pirates).
	/// Hard pool is the real faction bosses. Red-zone bounties are the
	/// named monsters of the sector, not just another captain.
	var/static/list/easy_targets = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/melee,
		/mob/living/basic/trooper/pirate/faction/skeleton/melee,
		/mob/living/basic/trooper/pirate/faction/grey/melee,
	)
	var/static/list/medium_targets = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/ranged,
		/mob/living/basic/trooper/pirate/faction/skeleton/ranged,
		/mob/living/basic/trooper/pirate/faction/lustrous/ranged,
		/mob/living/basic/trooper/pirate/faction/grey/captain,
	)
	var/static/list/hard_targets = list(
		/mob/living/basic/trooper/pirate/faction/boss/silverscale,
		/mob/living/basic/trooper/pirate/faction/boss/skeleton,
		/mob/living/basic/trooper/pirate/faction/boss/grey,
		/mob/living/basic/trooper/pirate/faction/boss/lustrous,
		/mob/living/basic/trooper/pirate/faction/boss/interdyne,
		/mob/living/basic/trooper/pirate/faction/boss/medieval,
	)
	/// Entourage pools: bounty targets above easy keep hired muscle around
	var/static/list/medium_guards = list(
		/mob/living/basic/trooper/pirate/faction/grey/melee,
		/mob/living/basic/trooper/pirate/faction/skeleton/melee,
		/mob/living/basic/trooper/pirate/faction/silverscale/melee,
	)
	var/static/list/hard_guards = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/ranged,
		/mob/living/basic/trooper/pirate/faction/skeleton/ranged,
		/mob/living/basic/trooper/pirate/faction/lustrous/ranged,
		/mob/living/basic/trooper/pirate/faction/interdyne/ranged,
	)

/datum/mission/recovery/kill/generate_details()
	var/static/list/target_titles = list("Dread Captain", "Warlord", "Butcher", "Reaver-Lord", "Hexmaster", "Iron Boss")
	var/static/list/target_names = list("Vask", "Korr", "Mirelle", "Ozym", "Sundance", "Grell", "Halix", "Renn")
	objective_name = "[pick(target_titles)] [pick(target_names)]"

/datum/mission/recovery/kill/build_objectives()
	var/datum/mission_objective/field/kill_named/hunt = new
	switch(difficulty)
		if(MISSION_DIFFICULTY_EASY)
			hunt.target_mob_type = pick(easy_targets)
		if(MISSION_DIFFICULTY_MEDIUM)
			hunt.target_mob_type = pick(medium_targets)
			hunt.guard_types = list(pick(medium_guards))
		else
			hunt.target_mob_type = pick(hard_targets)
			hunt.guard_types = list(pick(hard_guards), pick(hard_guards))
	add_objective(hunt)
	add_objective(new /datum/mission_objective/deliver/bound)

/datum/mission/recovery/kill/update_text()
	name = "Kill Contract: [objective_name]"
	desc = "Hunt down [objective_name], holed up at the signal at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		Return their identification tag to the mission pad. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive the target's transponder beacon ([gps_tag])."

/datum/mission/recovery/kill/waypoint_label()
	return "Hunt: [objective_name]"

/**
 * # Mission Recovery Item
 *
 * The physical objective for recovery-family missions. Bound to its mission;
 * the mission pad only accepts it for the contract (and retarget era) that
 * spawned it.
 */
/obj/item/mission_recovery
	name = "recovery objective"
	desc = "Salvage flagged for recovery under a standing contract. The mission pad will accept it."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "recovery"
	inhand_icon_state = "recovery"
	lefthand_file = 'voidcrew/modules/missions/icons/recovery_lefthand.dmi'
	righthand_file = 'voidcrew/modules/missions/icons/recovery_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL

	/// Weakref to the mission this item satisfies
	var/datum/weakref/mission_ref
	/// The mission's retarget era this item was bound in; stale eras don't match
	var/binding_serial = 0

/obj/item/mission_recovery/examine(mob/user)
	. = ..()
	var/datum/mission/mission = mission_ref?.resolve()
	if(mission && !mission.failed && !mission.completed && mission.binding_serial == binding_serial)
		. += span_notice("Tagged for contract: <b>[mission.name]</b>.")
		// Sites get shared, so somebody else's objective can end up in your hands.
		// Say whose it is rather than letting the pad refuse it with no explanation.
		if(mission.servant)
			. += span_notice("Filed to the [mission.servant.name]. Only that vessel's pad will take it.")
	else
		. += span_warning("The contract this was tagged for has expired.")

/obj/item/mission_recovery/proof
	name = "identification tag"
	desc = "Proof that somebody's career ended violently. The mission pad will accept it."
	icon_state = "recovery_proof"
	inhand_icon_state = null
	w_class = WEIGHT_CLASS_TINY
