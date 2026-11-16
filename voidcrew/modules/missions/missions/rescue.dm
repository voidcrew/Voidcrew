/**
 * # Rescue & Repatriation
 *
 * "A survivor's beacon is still pinging inside that wreck. Bring them home alive."
 *
 * Recovery variant where the objective breathes: a survivor NPC hides in the
 * target ruin, follows whoever asks, and the mission turns in while they're
 * alive beside the ship's mission pad. Survivor death burns a retarget
 * ("another beacon"). The non-gunner's recovery mission. The survivor
 * themselves are in rescue_survivor.dm.
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
