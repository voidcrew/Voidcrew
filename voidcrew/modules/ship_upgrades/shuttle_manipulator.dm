/datum/controller/subsystem/shuttle

	//VOID EDIT - Modular ship configuration for shuttle manipulator
	/// Pending upgrade module selections (slot_key -> module_id) for shuttle manipulator
	var/list/pending_upgrade_selections = list()
	/// Pending theme selection (theme_id) for shuttle manipulator
	var/pending_theme_id
	//END VOID EDIT

/**
 * Build UI data for modular ship configuration in shuttle manipulator
 *
 * Returns a list with:
 * - themes: list of available themes with id, name, desc, is_default, jobs
 * - has_themes: boolean if there are themes to choose from
 * - slots: list of upgrade slots with their available modules
 * - selected_theme: currently selected theme id (from pending_theme_id)
 * - selected_upgrades: currently selected modules (from pending_upgrade_selections)
 */
/datum/controller/subsystem/shuttle/proc/build_modular_ui_data(datum/map_template/shuttle/voidcrew/template)
	ensure_ship_upgrades_initialized()

	var/list/data = list()

	// Get themes for this ship
	var/list/ship_themes = get_themes_for_ship(template.type)
	var/list/themes_data = list()

	for(var/theme_id in ship_themes)
		var/datum/ship_theme/theme = ship_themes[theme_id]
		var/list/theme_info = list()
		theme_info["id"] = theme.id
		theme_info["name"] = theme.name
		theme_info["desc"] = theme.desc
		theme_info["is_default"] = theme.is_default

		// Include job slots for preview
		if(theme.job_slots)
			var/list/jobs = list()
			for(var/list/job_data in theme.job_slots)
				jobs += list(list(
					"name" = job_data["name"],
					"slots" = job_data["slots"],
					"officer" = job_data["officer"]
				))
			theme_info["jobs"] = jobs

		themes_data += list(theme_info)

	data["themes"] = themes_data
	data["has_themes"] = length(themes_data) > 0

	// Determine selected theme - use pending selection or find default
	var/effective_theme_id = pending_theme_id
	if(!effective_theme_id && length(themes_data))
		var/datum/ship_theme/default_theme = get_default_theme_for_ship(template.type)
		if(default_theme)
			effective_theme_id = default_theme.id

	data["selected_theme"] = effective_theme_id

	// Get upgrade slots - from theme if selected, otherwise from template
	var/list/upgrade_slot_ids = template.upgrade_slot_ids
	if(effective_theme_id)
		var/datum/ship_theme/selected_theme = ship_themes[effective_theme_id]
		if(selected_theme?.upgrade_slot_ids)
			upgrade_slot_ids = selected_theme.upgrade_slot_ids

	// Get modules filtered by theme
	var/list/all_modules = get_modules_for_ship_theme(template.type, effective_theme_id)

	// Organize modules by slot
	var/list/slots_data = list()
	for(var/slot_key in upgrade_slot_ids)
		var/list/slot_info = list()
		slot_info["key"] = slot_key
		// Generate display name from slot key (capitalize, replace underscores)
		slot_info["display_name"] = capitalize(replacetext(slot_key, "_", " "))

		var/list/slot_modules = list()
		for(var/module_id in all_modules)
			var/datum/ship_upgrade_module/module = all_modules[module_id]
			if(module.slot != slot_key)
				continue

			var/list/module_info = list()
			module_info["id"] = module.id
			module_info["name"] = module.name
			module_info["desc"] = module.desc
			module_info["is_default"] = module.is_default

			slot_modules += list(module_info)

		slot_info["modules"] = slot_modules
		slots_data += list(slot_info)

	data["slots"] = slots_data

	// Include current pending selections
	data["selected_upgrades"] = pending_upgrade_selections.Copy()

	return data
