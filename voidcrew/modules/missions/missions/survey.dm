/**
 * # Survey Mission
 *
 * A mission that requires surveying celestial objects using the survey console.
 * Tracks surveys via the COMSIG_VOIDCREW_SURVEY_COMPLETED signal.
 */
/datum/mission/survey
	name = "Survey Contract"
	desc = "Use the orbital survey console to scan %AMOUNT% %TARGET_NAME%."
	weight = 10

	/// Type key of celestial objects to survey (e.g., "planets", "asteroids", or "any")
	var/target_type = "any"
	/// Display name for the target type (plural)
	var/target_name = "celestial objects"
	/// Display name for the target type (singular)
	var/target_name_singular = "celestial object"
	/// Number of objects required to survey
	var/required_amount = 3
	/// Current progress
	var/current_amount = 0

/datum/mission/survey/generate_mission_details()
	// Define survey targets with their properties
	// Types match the keys from survey_research.survey_objects_by_type
	var/static/list/survey_targets = list(
		// Easy - common, easy to find objects
		list("type" = "any", "name" = "celestial objects", "name_singular" = "celestial object", "amount" = 3, "value_min" = 400, "value_max" = 600, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = "nebulas", "name" = "nebulas", "name_singular" = "nebula", "amount" = 2, "value_min" = 300, "value_max" = 500, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = "asteroids", "name" = "asteroid fields", "name_singular" = "asteroid field", "amount" = 2, "value_min" = 400, "value_max" = 600, "difficulty" = MISSION_DIFFICULTY_EASY),
		// Medium - require more exploration or specific types
		list("type" = "planets", "name" = "planets", "name_singular" = "planet", "amount" = 2, "value_min" = 700, "value_max" = 1000, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = "electric_storms", "name" = "electrical storms", "name_singular" = "electrical storm", "amount" = 2, "value_min" = 600, "value_max" = 900, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = "space_ruins", "name" = "space ruins", "name_singular" = "space ruin", "amount" = 2, "value_min" = 700, "value_max" = 1000, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		// Hard - rare or dangerous objects
		list("type" = "stars", "name" = "stars", "name_singular" = "star", "amount" = 1, "value_min" = 1200, "value_max" = 1800, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = "emp_storms", "name" = "EMP storms", "name_singular" = "EMP storm", "amount" = 2, "value_min" = 1000, "value_max" = 1500, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = "planets", "name" = "planets", "name_singular" = "planet", "amount" = 4, "value_min" = 1400, "value_max" = 2000, "difficulty" = MISSION_DIFFICULTY_HARD),
	)

	// Possible item rewards by difficulty
	var/static/list/medium_rewards = list(
		/obj/item/gun/ballistic/automatic/pistol,
		/obj/item/gun/energy/laser/retro,
		/obj/item/gun/ballistic/revolver,
	)
	var/static/list/hard_rewards = list(
		/obj/item/gun/energy/laser,
		/obj/item/gun/energy/laser/carbine,
		/obj/item/gun/ballistic/shotgun/riot,
		/obj/item/gun/ballistic/automatic/wt550,
	)

	var/list/target = pick(survey_targets)
	target_type = target["type"]
	target_name = target["name"]
	target_name_singular = target["name_singular"]
	required_amount = target["amount"]
	value_min = target["value_min"]
	value_max = target["value_max"]
	difficulty = target["difficulty"]

	// Assign random item reward based on difficulty
	switch(difficulty)
		if(MISSION_DIFFICULTY_MEDIUM)
			if(prob(50)) // 50% chance for item reward
				mission_reward = pick(medium_rewards)
		if(MISSION_DIFFICULTY_HARD)
			mission_reward = pick(hard_rewards) // Always get a reward for hard

	// Call parent to randomize value and generate author
	. = ..()

/datum/mission/survey/apply_text_substitutions()
	. = ..()
	var/display_name = required_amount == 1 ? target_name_singular : target_name
	name = replacetext(name, "%AMOUNT%", "[required_amount]")
	name = replacetext(name, "%TARGET_NAME%", display_name)
	desc = replacetext(desc, "%AMOUNT%", "[required_amount]")
	desc = replacetext(desc, "%TARGET_NAME%", display_name)

/datum/mission/survey/start_mission(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE

	// Register for survey completion signals
	RegisterSignal(ship, COMSIG_VOIDCREW_SURVEY_COMPLETED, PROC_REF(on_survey_completed))
	return TRUE

/datum/mission/survey/Destroy()
	if(servant)
		UnregisterSignal(servant, COMSIG_VOIDCREW_SURVEY_COMPLETED)
	return ..()

/**
 * Called when the ship completes a survey.
 * * source - The ship that completed the survey
 * * celestial_type - The type key of the surveyed object (e.g., "planets", "asteroids")
 */
/datum/mission/survey/proc/on_survey_completed(datum/source, celestial_type)
	SIGNAL_HANDLER

	if(failed || completed)
		return

	// Check if this survey counts toward our goal
	if(target_type == "any" || celestial_type == target_type)
		current_amount++

		// Notify crew of progress
		if(servant && current_amount < required_amount)
			var/display_name = required_amount == 1 ? target_name_singular : target_name
			servant.ship_notify("Surveyed [current_amount]/[required_amount] [display_name].", "MISSION PROGRESS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)

/datum/mission/survey/can_complete()
	if(failed || completed)
		return FALSE
	return current_amount >= required_amount

/datum/mission/survey/get_progress_string()
	var/display_name = required_amount == 1 ? target_name_singular : target_name
	return "[current_amount]/[required_amount] [display_name]"

/datum/mission/survey/get_failure_reason(obj/item/item)
	if(failed)
		return "Mission already failed."
	if(completed)
		return "Mission already completed."
	if(current_amount < required_amount)
		var/remaining = required_amount - current_amount
		var/display_name = remaining == 1 ? target_name_singular : target_name
		return "Need to survey [remaining] more [display_name]."
	return ..()

/datum/mission/survey/get_ui_data()
	var/list/data = ..()
	data["target_type"] = target_type
	data["target_name"] = target_name
	data["required_amount"] = required_amount
	data["current_amount"] = current_amount
	return data
