/datum/map_template/shuttle/voidcrew
	name = "ships"
	prefix = "_maps/voidcrew/ships/"
	port_id = "ship"

	///Short name of the ship
	var/short_name

	/**
	 * Class-based part requirements for unlocking this ship.
	 * Format: list("combat" = X, "science" = Y, "trade" = Z, "misc" = W)
	 * Only include classes that are required (0 values can be omitted).
	 */
	var/list/part_requirements = list()

	///List of job slots. Ensure the 'captain' is always the first entry
	var/list/job_slots = list()

	/// Ensures we dont try to spawn an abstract subtype
	var/abstract = /datum/map_template/shuttle/voidcrew

	/// Whether this ship template has modular upgrade slots
	var/has_upgrade_slots = FALSE
	/// List of upgrade slot keys this template supports (e.g., list("cargobay", "engineroom"))
	var/list/upgrade_slot_ids = list()
	/// Theme identifier for this ship variant (e.g., "pirate", "science"). Null for base/default theme.
	/// When set, the module loader will look for themed module variants (e.g., "cargo_basic_pirate.dmm")
	var/theme = null

/datum/map_template/shuttle/voidcrew/New()
	. = ..()
	// Ensure part_requirements has all classes initialized to 0 if not set
	for(var/part_class in GLOB.ship_part_classes)
		if(!(part_class in part_requirements))
			part_requirements[part_class] = 0

/datum/map_template/shuttle/voidcrew/proc/assemble_job_slots()
	var/list/job_list = list()
	for(var/list/job_definition as anything in job_slots)
		var/initial_slots = job_definition["slots"]

		var/datum/outfit/job/job_outfit = job_definition["outfit"]
		var/job_path = initial(job_outfit.jobtype)
		var/datum/job/job_slot = new job_path

		job_slot.title = job_definition["name"]
		job_slot.officer = !!job_definition["officer"]
		job_slot.outfit = job_outfit
		job_slot.job_flags = JOB_CREW_MANIFEST|JOB_EQUIP_RANK|JOB_NEW_PLAYER_JOINABLE|JOB_CREW_MEMBER|JOB_ASSIGN_QUIRKS|JOB_CAN_BE_INTERN
		job_slot.supervisors = "\the [job_slots[1]["name"]]"
		job_slot.job_category = job_definition["category"]

		job_list[job_slot] = initial_slots

	return job_list
