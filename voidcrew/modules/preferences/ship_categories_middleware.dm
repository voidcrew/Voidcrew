// Middleware for ship role category preferences
// This handles the TGUI interaction for setting category preferences

/datum/preference_middleware/ship_categories
	action_delegations = list(
		"set_ship_category_preference" = PROC_REF(set_ship_category_preference),
	)

/datum/preference_middleware/ship_categories/proc/set_ship_category_preference(list/params, mob/user)
	var/category = params["category"]
	var/level = params["level"]

	if(!category)
		return FALSE

	if(level != null && level != JP_LOW && level != JP_MEDIUM && level != JP_HIGH)
		return FALSE

	if(!preferences.set_ship_category_preference(category, level))
		return FALSE

	return TRUE

/datum/preference_middleware/ship_categories/get_constant_data()
	var/list/data = list()

	// Send the list of available categories
	var/list/categories = list()
	for(var/category in GLOB.job_categories)
		categories += category

	data["ship_categories"] = categories

	return data

/datum/preference_middleware/ship_categories/get_ui_data(mob/user)
	var/list/data = list()

	data["ship_category_preferences"] = preferences.ship_category_preferences

	return data
