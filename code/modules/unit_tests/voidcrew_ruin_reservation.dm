/**
 * # Voidcrew ruin reservation-fit test
 *
 * A space ruin is boarded by reserving a turf block big enough for the ruin plus
 * a maximum-size docking berth on two opposite sides. That block has a hard
 * ceiling: only the band inset by SHUTTLE_TRANSIT_BORDER is ever reservable, and
 * the cordon ring costs another turf at each end.
 *
 * A template over that ceiling is not merely rare. It is *unboardable forever*.
 * Worse, it fails in the most expensive way available: request_turf_block_reservation()
 * reads "no room" as "this z-level is full", allocates a brand new 255x255
 * reservation z-level, fails on that too, and returns null while keeping the level.
 * Every dock attempt on such a ruin leaks another z-level, and the player only sees
 * "Failed to load the location."
 *
 * This is exactly how oldstation.dmm (112x64, needing 230x150 against a 222x222
 * ceiling) shipped: nothing in the spawn path checks size, so it surfaced as a
 * normal signal that silently refused every boarding attempt.
 */
/datum/unit_test/voidcrew_ruin_reservation_fit

/datum/unit_test/voidcrew_ruin_reservation_fit/Run()
	var/max_width = world.maxx - (SHUTTLE_TRANSIT_BORDER * 2) - 1
	var/max_height = world.maxy - (SHUTTLE_TRANSIT_BORDER * 2) - 1

	// Mirrors load_level()'s sizing (voidcrew/modules/overmap/.../space_ruin.dm).
	// Literals rather than the RESERVE_DOCK_* defines: unit tests compile before
	// voidcrew/_DEFINES, same reason voidcrew_loot.dm spells out its zone bands.
	var/dock_long = 56 // RESERVE_DOCK_MAX_SIZE_LONG
	var/dock_short = 40 // RESERVE_DOCK_MAX_SIZE_SHORT
	var/padding = 3 // RESERVE_DOCK_DEFAULT_PADDING

	var/checked = 0
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/ruin = SSmapping.space_ruins_templates[template_name]
		if(!istype(ruin))
			continue
		// unpickable templates never reach the overmap on their own, they are
		// surfaced deliberately by a chart, mission or admin, and oversized ones are
		// parked here on purpose (see /datum/map_template/ruin/space/oldstation)
		if(ruin.unpickable)
			continue

		var/map_path = ruin.mappath
		if(!map_path && ruin.prefix && ruin.suffix)
			map_path = ruin.prefix + ruin.suffix
		if(!map_path)
			TEST_FAIL("Space ruin template '[template_name]' ([ruin.type]) has no resolvable map path, so its size can never be read and it can never load")
			continue

		// cache = FALSE deliberately: we only want the bounds. Caching would hold a
		// fully parsed copy of every space ruin map in memory for the rest of the run.
		ruin.preload_size(map_path, FALSE)
		if(!ruin.width || !ruin.height)
			TEST_FAIL("Space ruin template '[template_name]' ([map_path]) reports no dimensions, preload_size() could not read it")
			continue

		checked++
		var/reserve_width = ruin.width + (dock_long * 2) + (padding * 2)
		var/reserve_height = ruin.height + (dock_short * 2) + (padding * 2)

		if(reserve_width > max_width || reserve_height > max_height)
			TEST_FAIL("Space ruin '[template_name]' ([map_path]) is [ruin.width]x[ruin.height], needing a \
				[reserve_width]x[reserve_height] reservation, over the [max_width]x[max_height] ceiling. It would spawn on \
				the overmap as a signal that fails every docking attempt and leaks a reservation z-level each time. \
				Shrink the map, or set unpickable = TRUE to keep it out of the spawn pools.")

	if(!checked)
		TEST_FAIL("No space ruin templates were checked. SSmapping.space_ruins_templates is empty, so this test is not guarding anything")
