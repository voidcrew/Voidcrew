// Ship role category preferences for voidcrew
// Players set High/Medium/Low/Never for each category, and get matched to ship jobs accordingly

/datum/preferences
	/// Ship role category preferences - indexed by category name (JOB_CAT_*), value is JP_HIGH/JP_MEDIUM/JP_LOW or null (never)
	var/list/ship_category_preferences = list()

/**
 * Sets a ship role category preference level
 * Returns TRUE if successful, FALSE if invalid
 */
/datum/preferences/proc/set_ship_category_preference(category, level)
	if(!(category in GLOB.job_categories))
		return FALSE
	if(!isnull(level) && level != JP_HIGH && level != JP_MEDIUM && level != JP_LOW)
		return FALSE

	if(isnull(level))
		ship_category_preferences -= category
	else
		ship_category_preferences[category] = level

	return TRUE

/**
 * Gets a ship role category preference level
 * Returns the level (JP_HIGH/JP_MEDIUM/JP_LOW) or null if not set
 */
/datum/preferences/proc/get_ship_category_preference(category)
	return ship_category_preferences[category]

// Hook into save_character to save ship category preferences
/datum/preferences/save_character()
	. = ..()
	if(!.)
		return FALSE

	var/tree_key = "character[default_slot]"
	var/save_data = savefile.get_entry(tree_key)
	save_data["ship_category_preferences"] = ship_category_preferences
	return TRUE

// Hook into load_character to load ship category preferences
// VOIDCREW: the `slot = default_slot` default MUST be repeated here. Upstream used to
// fall back with an in-body `if(!slot) slot = default_slot`; that fallback was deleted
// and replaced by the parameter default. An override declaring plain `slot` shadows the
// default, so the two no-arg callers (preferences.dm and preferences_savefile.dm) would
// pass null, which sanitize_integer() rewrites to initial(default_slot) == 1 - loading
// slot 1 over the player's real slot and persisting that to their savefile.
/datum/preferences/load_character(slot = default_slot)
	. = ..()
	if(!.)
		return FALSE

	var/tree_key = "character[default_slot]"
	var/save_data = savefile.get_entry(tree_key)
	ship_category_preferences = SANITIZE_LIST(save_data?["ship_category_preferences"])

	// Validate category prefs
	for(var/cat in ship_category_preferences)
		if(!(cat in GLOB.job_categories))
			ship_category_preferences -= cat
			continue
		var/level = ship_category_preferences[cat]
		if(level != JP_LOW && level != JP_MEDIUM && level != JP_HIGH)
			ship_category_preferences -= cat

	return TRUE
