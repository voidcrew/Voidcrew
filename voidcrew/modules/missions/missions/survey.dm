/**
 * # Survey Mission
 *
 * Scan celestial objects with the orbital survey console. One scan objective,
 * generated off a static table of asks.
 */
/datum/mission/survey
	name = "Survey Contract"
	weight = 10

	/// The rolled ask (kept for UI keys)
	var/target_type = "any"
	var/target_name = "celestial objects"
	var/target_name_singular = "celestial object"
	var/required_amount = 3
	/// The scan objective, for UI progress keys
	var/datum/mission_objective/scan_celestial/scan

/datum/mission/survey/Destroy()
	scan = null
	return ..()

/datum/mission/survey/generate_details()
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

	var/list/ask = pick(survey_targets)
	target_type = ask["type"]
	target_name = ask["name"]
	target_name_singular = ask["name_singular"]
	required_amount = ask["amount"]
	value_min = ask["value_min"]
	value_max = ask["value_max"]
	difficulty = ask["difficulty"]

	// Assign random item reward based on difficulty
	switch(difficulty)
		if(MISSION_DIFFICULTY_MEDIUM)
			if(prob(50)) // 50% chance for item reward
				mission_reward = pick(medium_rewards)
		if(MISSION_DIFFICULTY_HARD)
			mission_reward = pick(hard_rewards) // Always get a reward for hard

/datum/mission/survey/build_objectives()
	scan = new
	scan.target_type = target_type
	scan.target_name = target_name
	scan.target_name_singular = target_name_singular
	scan.required_amount = required_amount
	add_objective(scan)

/datum/mission/survey/update_text()
	var/display_name = required_amount == 1 ? target_name_singular : target_name
	name = "Survey Contract: [display_name]"
	desc = "Use your ship's orbital survey console to scan [required_amount] [display_name] after accepting this contract. \
		Nothing to bring back - payment is settled at the mission board once the scans are logged."

/datum/mission/survey/get_ui_data()
	var/list/data = ..()
	data["target_type"] = target_type
	data["target_name"] = target_name
	data["required_amount"] = required_amount
	data["current_amount"] = scan ? scan.current_amount : 0
	return data
