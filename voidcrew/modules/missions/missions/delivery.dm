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
	var/required_type = /obj/item/stack/spice_pods
	var/required_name = "spice pods"
	var/required_amount = 1
	/// Equal row weights; these asks accept stored goods and pay flat credits.
	var/static/list/delivery_asks = list(
		list("type" = /obj/item/stack/spice_pods, "amount" = 3, "difficulty" = MISSION_DIFFICULTY_EASY, "value_min" = 320, "value_max" = 400),
		list("type" = /obj/item/stack/sheet/sinew, "amount" = 2, "difficulty" = MISSION_DIFFICULTY_EASY, "value_min" = 260, "value_max" = 340),
		list("type" = /obj/item/stack/sheet/animalhide/goliath_hide, "amount" = 2, "difficulty" = MISSION_DIFFICULTY_MEDIUM, "value_min" = 400, "value_max" = 550),
		list("type" = /obj/item/stack/glacial_core, "amount" = 3, "difficulty" = MISSION_DIFFICULTY_MEDIUM, "value_min" = 550, "value_max" = 700),
		list("type" = /obj/item/stack/telecrystal_raw, "amount" = 5, "difficulty" = MISSION_DIFFICULTY_HARD, "value_min" = 1500, "value_max" = 1700),
		list("type" = /obj/item/sea_crystal, "amount" = 1, "difficulty" = MISSION_DIFFICULTY_HARD, "value_min" = 1000, "value_max" = 1200),
		list("type" = /obj/item/documents/syndicate, "amount" = 1, "difficulty" = MISSION_DIFFICULTY_HARD, "value_min" = 3000, "value_max" = 3300),
	)

/datum/mission/delivery/generate_details()
	var/list/ask = pick(delivery_asks)
	required_type = ask["type"]
	var/obj/item/goods = required_type
	required_name = initial(goods.name)
	required_amount = ask["amount"]
	difficulty = ask["difficulty"]
	value_min = ask["value_min"]
	value_max = ask["value_max"]

/datum/mission/delivery/build_objectives()
	var/datum/mission_objective/deliver/console/ask = new
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
