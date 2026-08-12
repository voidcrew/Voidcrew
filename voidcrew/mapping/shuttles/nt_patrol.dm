/**
 * NT Customs Patrol Corvette - Vigilant-class
 * Reskin of the Rogue-class pirate vessel for Nanotrasen customs enforcement.
 * Dispatched by mission code (e.g. drug smuggling customs patrols), see
 * voidcrew/modules/npc_ships/code/faction_pirates/nt_patrol.dm
 */
/datum/map_template/shuttle/voidcrew/nt_patrol
	name = "Vigilant-class Customs Corvette"
	suffix = "nt_patrol"
	short_name = "Vigilant-class"
	part_requirements = list(PART_CLASS_COMBAT = 1)

	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Compliance Officer",
			outfit = /datum/outfit/job/hos,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Customs Agent",
			outfit = /datum/outfit/job/security,
			category = JOB_CAT_SECURITY,
			slots = 2,
		),
		list(
			name = "Systems Technician",
			outfit = /datum/outfit/job/engineer,
			category = JOB_CAT_ENGINEERING,
			slots = 1,
		),
		list(
			name = "Junior Associate",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/nt_patrol
	name = "Vigilant-class Customs Corvette"
	area_type = /area/shuttle/voidcrew/nt_patrol
	port_direction = 2
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/nt_patrol
	name = "Vigilant-class Customs Corvette"
