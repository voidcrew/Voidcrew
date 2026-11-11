/**
 * Police cutter: the template datum for the outpost police's pursuit ship (voidcrew/modules/outpost_police/police_cutter.dm).
 * Owner: P9, who declares /datum/map_template/shuttle/voidcrew/police_cutter here, mirroring nt_patrol.dm.
 *
 * The hull is a stripped copy of the customs corvette (_maps/voidcrew/ships/ship_police_cutter.dmm): the same
 * rooms and machines, no loose items, no stocked lockers, no stocked tank dispenser. It is only ever flown by
 * the police cutter ship (/obj/structure/overmap/ship/npc/pirate/nt_patrol/police), dispatched by
 * start_pursuit(), so it is kept off every list a player or a test walks to find hulls: not on the shelf, not in
 * the Ship Workshop, not in the checkpoint round-trip tests (see `abstract` and `player_hidden` below).
 */
/datum/map_template/shuttle/voidcrew/police_cutter
	name = "Port Authority Cutter"
	suffix = "police_cutter"
	short_name = "Cutter"
	/// Never offered to players: the shelf, the roundstart fleet, ship orders and the Voidworks hull list all skip it.
	player_hidden = TRUE
	/// The loops over every template (the catalog and the checkpoint tests) skip a template whose abstract is
	/// its own type; nothing else reads this var, so the NPC spawn path is not affected.
	abstract = /datum/map_template/shuttle/voidcrew/police_cutter

	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Duty Sergeant",
			outfit = /datum/outfit/job/hos,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Patrol Officer",
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
			name = "Cadet",
			outfit = /datum/outfit/job/assistant,
			category = JOB_CAT_ASSISTANT,
			slots = 2,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/police_cutter
	name = "Port Authority Cutter"
	area_type = /area/shuttle/voidcrew/police_cutter
	port_direction = 2
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/police_cutter
	name = "Port Authority Cutter"
	// The corvette's map set this on every tile; here it is the type's own
	requires_power = FALSE

/// MAP OBJECTS ///

/// The cutter's bunk lockers: the personal closet's look without the backpack and headset it stocks itself with
/// (a stripped hull holds nothing a boarder could carry off)
/obj/structure/closet/secure_closet/personal/police_cutter

/obj/structure/closet/secure_closet/personal/police_cutter/PopulateContents()
	return
