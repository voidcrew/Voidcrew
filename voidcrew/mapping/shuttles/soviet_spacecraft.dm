/datum/map_template/shuttle/voidcrew/soviet_spacecraft
	name = "Soviet spacecraft"
	catalog_desc = "A battered Soyuz T spacecraft dating back to 1986, assembled from the wreckage of similar models drifting in the asteroid belt. A section from one of the lost modules of the Mir-2 space station has been crudely attached to the craft. Most of the components are held together by adhesive tape and blue electrical tape."
	suffix = "soviet_spacecraft_soyuz"
	short_name = "Soviet spacecraft"
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("solars", "docking_module", "living_module", "engineering_module")
	player_hidden = FALSE
	job_slots = list(
		list(name = "Captain", officer = TRUE, outfit = /datum/outfit/job/captain, category = JOB_CAT_COMMAND, slots = 1),
		list(name = "Crew", outfit = /datum/outfit/job/assistant, category = JOB_CAT_ASSISTANT, slots = 3),
	)
	available_themes = list("standard")

/obj/docking_port/mobile/voidcrew/soviet_spacecraft
	name = "Soviet spacecraft"
	area_type = /area/shuttle/voidcrew/soviet_spacecraft
	port_direction = 2
	preferred_direction = NORTH

/area/shuttle/voidcrew/soviet_spacecraft
	name = "Soviet spacecraft"
	icon_state = "station"
