/**
 * # Delivery Mission
 *
 * Bring N of a listed commodity to the mission pad. One deliver objective,
 * generated off a static table of asks.
 */
/datum/mission/delivery
	name = "Delivery Contract"
	weight = 10

	/// The rolled ask (kept for UI keys)
	var/required_type = /obj/item/stack/ore/iron
	var/required_name = "iron ore"
	var/required_amount = 1

/datum/mission/delivery/generate_details()
	// Each target defines its own difficulty, amount, and value range
	var/static/list/delivery_targets = list(
		// Easy - common ores, low amounts
		list("type" = /obj/item/stack/ore/iron, "name" = "iron ore", "amount" = 10, "value_min" = 400, "value_max" = 600, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = /obj/item/stack/ore/glass, "name" = "sand", "amount" = 15, "value_min" = 300, "value_max" = 500, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = /obj/item/stack/sheet/iron, "name" = "iron sheets", "amount" = 10, "value_min" = 500, "value_max" = 700, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = /obj/item/stack/sheet/glass, "name" = "glass sheets", "amount" = 10, "value_min" = 400, "value_max" = 600, "difficulty" = MISSION_DIFFICULTY_EASY),
		// Medium - uncommon ores, moderate amounts
		list("type" = /obj/item/stack/ore/plasma, "name" = "plasma ore", "amount" = 10, "value_min" = 800, "value_max" = 1200, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/ore/silver, "name" = "silver ore", "amount" = 8, "value_min" = 700, "value_max" = 1000, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/ore/titanium, "name" = "titanium ore", "amount" = 8, "value_min" = 800, "value_max" = 1100, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/sheet/plasteel, "name" = "plasteel sheets", "amount" = 5, "value_min" = 1000, "value_max" = 1400, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		// Hard - rare ores, higher amounts
		list("type" = /obj/item/stack/ore/gold, "name" = "gold ore", "amount" = 8, "value_min" = 1200, "value_max" = 1800, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/uranium, "name" = "uranium ore", "amount" = 6, "value_min" = 1400, "value_max" = 2000, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/diamond, "name" = "diamond ore", "amount" = 4, "value_min" = 2000, "value_max" = 3000, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/bluespace_crystal, "name" = "bluespace crystals", "amount" = 2, "value_min" = 2500, "value_max" = 3500, "difficulty" = MISSION_DIFFICULTY_HARD),
	)

	var/list/ask = pick(delivery_targets)
	required_type = ask["type"]
	required_name = ask["name"]
	required_amount = ask["amount"]
	value_min = ask["value_min"]
	value_max = ask["value_max"]
	difficulty = ask["difficulty"]

/datum/mission/delivery/build_objectives()
	var/datum/mission_objective/deliver/ask = new
	ask.required_type = required_type
	ask.required_name = required_name
	ask.required_amount = required_amount
	add_objective(ask)

/datum/mission/delivery/update_text()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	var/datum/mission_objective/deliver/ask = objectives[1]
	name = "Delivery Contract: [item_text]"
	desc = "Deliver [item_text] to the mission pad to complete this contract.[ask.get_delivery_instructions()]"

/datum/mission/delivery/get_ui_data()
	var/list/data = ..()
	data["required_type"] = "[required_type]"
	data["required_name"] = required_name
	data["required_amount"] = required_amount
	return data
