/**
 * # Delivery Mission
 *
 * A mission that requires delivering a specific item type to the mission pad.
 * The item is consumed upon turn-in.
 */
/datum/mission/delivery
	name = "Delivery Contract"
	desc = "Deliver %ITEM_NAME% to the mission pad to complete this contract."
	value = 1000
	weight = 10
	duration = DEFAULT_MISSION_DURATION

	/// The type of item required for delivery
	var/required_type = /obj/item/stack/ore/iron
	/// Display name for the required item
	var/required_name = "iron ore"
	/// Amount required (for stacks)
	var/required_amount = 1

/datum/mission/delivery/generate_mission_details()
	// Pick a random delivery target from a predefined list
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
		list("type" = /obj/item/stack/ore/diamond, "name" = "diamonds", "amount" = 4, "value_min" = 2000, "value_max" = 3000, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/bluespace_crystal, "name" = "bluespace crystals", "amount" = 2, "value_min" = 2500, "value_max" = 3500, "difficulty" = MISSION_DIFFICULTY_HARD),
	)

	var/list/target = pick(delivery_targets)
	required_type = target["type"]
	required_name = target["name"]
	required_amount = target["amount"]
	value_min = target["value_min"]
	value_max = target["value_max"]
	difficulty = target["difficulty"]

	// Call parent to randomize value and generate author
	. = ..()

/datum/mission/delivery/apply_text_substitutions()
	. = ..()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	name = replacetext(name, "%ITEM_NAME%", item_text)
	desc = replacetext(desc, "%ITEM_NAME%", item_text)

/datum/mission/delivery/can_complete()
	// Delivery missions can only be completed via can_turn_in
	return FALSE

/datum/mission/delivery/can_turn_in(obj/item/item)
	if(!item)
		return FALSE
	if(!istype(item, required_type))
		return FALSE

	// Check stack amount if applicable
	if(istype(item, /obj/item/stack))
		var/obj/item/stack/stack = item
		if(stack.amount < required_amount)
			return FALSE

	return TRUE

/// Returns a detailed reason why an item can't be turned in (for debugging)
/datum/mission/delivery/proc/get_turn_in_failure_reason(obj/item/item)
	if(!item)
		return "No item provided"
	if(!istype(item, required_type))
		return "Wrong type: need [required_type], got [item.type]"
	if(istype(item, /obj/item/stack))
		var/obj/item/stack/stack = item
		if(stack.amount < required_amount)
			return "Need [required_amount], only have [stack.amount]"
	return "Unknown"

/datum/mission/delivery/turn_in(obj/machinery/mission_pad/pad, obj/item/turned_in_item)
	if(!can_turn_in(turned_in_item))
		return FALSE

	completed = TRUE
	active = FALSE

	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null

	// Consume the required amount from stack, or the whole item
	if(istype(turned_in_item, /obj/item/stack))
		var/obj/item/stack/stack = turned_in_item
		stack.use(required_amount)
	else
		qdel(turned_in_item)

	// Distribute rewards
	distribute_rewards(pad)

	// Notify ship
	if(servant)
		servant.ship_announce("[name] completed! Reward: [value] credits[mission_reward ? " + item reward" : ""]", "Mission Complete")
		servant.active_missions -= src

	// Remove from subsystem tracking
	SSmissions.all_active_missions -= src

	SEND_SIGNAL(src, COMSIG_MISSION_COMPLETED)

	qdel(src)
	return TRUE

/datum/mission/delivery/get_progress_string()
	return "Deliver [required_amount] [required_name]"

/datum/mission/delivery/get_ui_data()
	var/list/data = ..()
	data["required_type"] = "[required_type]"
	data["required_name"] = required_name
	data["required_amount"] = required_amount
	data["requires_item"] = TRUE
	return data
