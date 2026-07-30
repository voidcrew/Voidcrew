/datum/job
	///Whether the job is an 'Officer', the leader of the ship.
	var/officer = FALSE
	///The job category for ship role preferences (JOB_CAT_COMMAND, JOB_CAT_ENGINEERING, etc.)
	var/job_category

/**
 * Every job a roundstart ship could possibly spawn with.
 *
 * The fleet rolls its hulls, themes and modules at random every round, so the pool is
 * the union of every theme on every roundstart-eligible hull, plus every module that
 * contributes crew of its own - not the one configuration a hull happens to default to.
 *
 * Built from the theme and module registries rather than from ship templates on purpose.
 * map_check() runs during SSjob init, which is *before* SSmapping: going through the ship
 * catalog here would cache an empty catalog for the rest of the round, and instantiating
 * templates directly parses every hull's .dmm. Themes and modules are plain datums with
 * neither problem.
 */
/proc/build_roundstart_job_pool()
	ensure_ship_upgrades_initialized()

	var/list/definitions = list()

	for(var/hull_type in GLOB.ship_themes)
		if(!is_roundstart_eligible_hull_type(hull_type))
			continue
		var/list/themes = GLOB.ship_themes[hull_type]
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			if(length(theme.job_slots))
				definitions += theme.job_slots

	// Modules can bring crew of their own - a hydroponics bay's botanist, say
	for(var/hull_type in GLOB.ship_upgrade_modules)
		if(!is_roundstart_eligible_hull_type(hull_type))
			continue
		var/list/modules = GLOB.ship_upgrade_modules[hull_type]
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			if(length(module.job_slots_add))
				definitions += module.job_slots_add

	return assemble_job_slots_from_list(definitions)

/**
 * Checks this job against the pool of jobs a roundstart ship could spawn with.
 * Excludes non-player jobs (such as unassigned).
 * Will run as normal if the pool comes back empty.
 * Sets the Captain as the 'overflow' job (This does nothing in practice, as we don't expand the job slots).
 * If a job is not meant to show up in prefs menu, we remove their new player joinable flag before sending it through.
 */
/datum/job/map_check()
	//let non-player jobs function properly.
	if(!(job_flags & JOB_NEW_PLAYER_JOINABLE))
		return TRUE

	var/static/list/roundstart_ship_jobs
	if(isnull(roundstart_ship_jobs))
		roundstart_ship_jobs = build_roundstart_job_pool()
	if(!length(roundstart_ship_jobs))
		return ..()

	for(var/datum/job/job as anything in roundstart_ship_jobs)
		if(type != job.type)
			continue
		if(job.officer)
			SSjob.overflow_role = type
		return TRUE
	job_flags ^= JOB_NEW_PLAYER_JOINABLE
	return TRUE
