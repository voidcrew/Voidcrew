/datum/map_template/shuttle/voidcrew
	name = "ships"
	prefix = "_maps/voidcrew/ships/"
	port_id = "ship"

	///Short name of the ship
	var/short_name

	/// Player-facing summary shown on the hull shelf in the shipyard and in the ship
	/// catalog. A sentence or three on what the hull is and how it plays, so someone
	/// can tell it apart from the rest of the shelf before spending parts on it.
	/// Falls back to a generated "N-class with capacity for N crew" line when unset.
	var/catalog_desc

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
	/// Note: Themes can override this with their own upgrade_slot_ids
	var/list/upgrade_slot_ids = list()
	/// Theme identifier for this ship variant (e.g., "pirate", "science"). Null for base/default theme.
	/// When set, the module loader will look for themed module variants (e.g., "cargo_basic_pirate.dmm")
	/// Note: This is set at spawn time based on selected theme, not hardcoded.
	var/theme = null
	/// List of available theme IDs for this ship class (e.g., list("medical", "syndicate", "mining"))
	/// If set, ship has selectable themes. If empty/null, ship has no theme selection.
	var/list/available_themes
	/// Keeps a hull out of every player-facing list (dev/test hulls). Admins can still
	/// spawn it with Spawn Specific Ship. See is_player_purchasable_ship().
	var/player_hidden = FALSE
	/// Puts a non-modular hull on the shelf despite the modular-only rule (curated
	/// joke/legacy hulls like the pills). See is_player_purchasable_ship().
	var/force_purchasable = FALSE

/datum/map_template/shuttle/voidcrew/New()
	. = ..()
	// Ensure part_requirements has all classes initialized to 0 if not set
	for(var/part_class in GLOB.ship_part_classes)
		if(!(part_class in part_requirements))
			part_requirements[part_class] = 0

/// How long a hull waits for its upgrade modules to finish reading before initializing anyway.
#define SHIP_MODULE_READ_TIMEOUT (2 MINUTES)

/**
 * Initialize the hull only once every upgrade module inside it has been read.
 *
 * Module maps leave their atoms for this pass (see /datum/map_template/map_module/ship_upgrade),
 * so hull and modules initialize together in one pass over the whole ship. Before this the hull
 * initialized while its modules were still being read, which let hull pipes connect to module
 * vents and pumps that had not run Initialize() (null nodes, "Nonexistent machinery gasmix"),
 * let hull walls and tables smooth against module atoms whose smoothing groups were still
 * unparsed ("bad index"), and let a module's own pass start on hull areas the hull was still
 * working through ("initialized multiple times").
 */
/datum/map_template/shuttle/voidcrew/initTemplateBounds(list/bounds)
	if(bounds)
		wait_for_upgrade_modules(block(
			bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ],
			bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ]
		))
	return ..()

/// Sleeps until no /obj/modular_map_root is left on the given turfs. Each marker deletes itself
/// once its module has been read.
/datum/map_template/shuttle/voidcrew/proc/wait_for_upgrade_modules(list/turfs)
	var/give_up_at = world.time + SHIP_MODULE_READ_TIMEOUT
	while(TRUE)
		var/obj/modular_map_root/pending
		for(var/turf/place as anything in turfs)
			pending = locate() in place
			if(pending)
				break
		if(!pending)
			return
		if(world.time > give_up_at)
			stack_trace("[name] gave up waiting for upgrade module '[pending.key]' at [AREACOORD(pending)]")
			// The hull initializes without them now, so late modules must initialize themselves
			for(var/turf/place as anything in turfs)
				for(var/obj/modular_map_root/ship_upgrade/late in place)
					late.defer_to_hull = FALSE
			return
		sleep(1)

#undef SHIP_MODULE_READ_TIMEOUT

/**
 * Upgrade modules load asynchronously - /obj/modular_map_root fires its map load from an
 * INVOKE_ASYNC while the hull is still being read, so a module's cables can be created after
 * /datum/map_template/load() has already run its setup_template_powernets() pass. Those cables
 * still link to their neighbours (Connect_cable() runs on Initialize, so the icons join up
 * normally), but nothing ever propagates a powernet through them - the module's APC then sits
 * dead on a wire that looks perfectly connected.
 *
 * dispatch() waits out every marker before returning, so it is the first point where the whole
 * ship - hull and modules - is on the map. Rebuild the powernets from scratch here.
 */
/datum/map_template/shuttle/voidcrew/dispatch(list/turfs, register = TRUE)
	. = ..()
	rebuild_ship_powernets(turfs)

/// Rebuilds every powernet touching the given turfs as one pass. See dispatch() for why.
/datum/map_template/shuttle/voidcrew/proc/rebuild_ship_powernets(list/turfs)
	var/list/cables = list()
	for(var/turf/place as anything in turfs)
		for(var/obj/structure/cable/cable in place)
			cables += cable

	if(!length(cables))
		return

	// Drop the nets these cables ended up on first. A module that raced the hull's pass can
	// leave an entire run sitting on its own sourceless powernet, and setup_template_powernets()
	// only ever touches cables that have none - so without this the orphan net survives.
	// Destroying a powernet nulls the reference on every cable in it, so nets shared between
	// several of our cables are only torn down once.
	for(var/obj/structure/cable/cable as anything in cables)
		if(cable.powernet)
			qdel(cable.powernet)

	// Propagation walks the full linked-cable graph, so this pulls the hull and every module
	// back together into a single net and reconnects the machines hanging off it.
	SSmachines.setup_template_powernets(cables)

/datum/map_template/shuttle/voidcrew/proc/assemble_job_slots()
	// Themed ships keep their jobs on the default theme, not the template
	if(!length(job_slots) && length(available_themes))
		var/datum/ship_theme/default_theme = get_default_theme_for_ship(type)
		if(default_theme?.job_slots)
			return assemble_job_slots_from_list(default_theme.job_slots)
	return assemble_job_slots_from_list(job_slots)

/**
 * Assemble job datums from a list of job slot definitions
 * Can be used with template.job_slots or theme.job_slots
 */
/proc/assemble_job_slots_from_list(list/job_slot_definitions)
	if(!length(job_slot_definitions))
		return list()

	// The rest of the crew answers to the ship's officer - the captain-tier slot. Found by
	// flag rather than by position: modules append slots of their own, and the roundstart
	// job pool splices several themes together, so index 1 is not reliably the captain.
	var/supervisor_name
	for(var/list/job_definition as anything in job_slot_definitions)
		if(islist(job_definition) && job_definition["officer"])
			supervisor_name = job_definition["name"]
			break
	if(!supervisor_name)
		var/list/first_definition = job_slot_definitions[1]
		if(islist(first_definition))
			supervisor_name = first_definition["name"]

	var/list/job_list = list()
	for(var/list/job_definition as anything in job_slot_definitions)
		// Skip malformed job definitions
		if(!islist(job_definition))
			continue

		var/definition_error = ship_job_definition_error(job_definition)
		if(definition_error)
			stack_trace(definition_error)
			continue
		var/datum/outfit/job/job_outfit = job_definition["outfit"]
		var/role = job_definition["role"] || "crew"
		var/job_path
		switch(role)
			if("ai")
				job_path = /datum/job/ai
			if("cyborg")
				job_path = /datum/job/cyborg
			else
				job_path = initial(job_outfit.jobtype)

		var/datum/job/job_slot = new job_path

		job_slot.title = job_definition["name"] || "Unknown"
		job_slot.officer = !!job_definition["officer"]
		job_slot.outfit = job_outfit
		job_slot.ship_role = role
		job_slot.ship_borg_model = job_definition["borg_model"]
		if(role == "crew")
			job_slot.job_flags = JOB_CREW_MANIFEST|JOB_EQUIP_RANK|JOB_NEW_PLAYER_JOINABLE|JOB_CREW_MEMBER|JOB_ASSIGN_QUIRKS|JOB_CAN_BE_INTERN
		else
			job_slot.job_flags |= JOB_CREW_MEMBER
		// A captain-tier job sits at the top of the ship's chain of command and answers to
		// nobody. Null supervisors makes get_spawn_message_information() drop the "you answer
		// directly to ..." line rather than pointing the officer at themselves.
		// The title check covers definitions that never set the flag: get_captain_job() falls
		// back to the first slot, so the first slot is captain-tier there too.
		var/is_captain_tier = job_slot.officer || (supervisor_name && job_slot.title == supervisor_name)
		if(role == "crew")
			job_slot.supervisors = is_captain_tier ? null : "\the [supervisor_name || "Captain"]"
		job_slot.job_category = job_definition["category"]

		var/initial_slots = job_definition["slots"] || 1
		job_list[job_slot] = initial_slots

	return job_list
