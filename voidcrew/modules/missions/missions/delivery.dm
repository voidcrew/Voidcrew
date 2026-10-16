/**
 * # Delivery Mission
 *
 * Bring N of a listed commodity to the mission pad. One deliver objective,
 * generated off a static table of asks.
 */
/datum/mission/delivery
	name = "Delivery Contract"
	weight = 0

	/// The rolled ask (kept for UI keys)
	var/required_type = /obj/item/stack/ore/iron
	var/required_name = "iron ore"
	var/required_amount = 1

/datum/mission/delivery/generate_details()
	// Suspended until compliant replacement rows receive their own reward design.
	generation_failed = TRUE

/datum/mission/delivery/build_objectives()
	var/datum/mission_objective/deliver/ask = new
	ask.required_type = required_type
	ask.required_name = required_name
	ask.required_amount = required_amount
	add_objective(ask)

/datum/mission/delivery/update_text()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	name = "Delivery Contract: [item_text]"
	desc = "[author] wants [item_text]."

/datum/mission/delivery/get_ui_data()
	var/list/data = ..()
	data["required_type"] = "[required_type]"
	data["required_name"] = required_name
	data["required_amount"] = required_amount
	return data
