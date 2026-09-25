/**
 * # Voidcrew space-ruin size-gate test
 *
 * A space ruin is boarded by standing its interior up inside a MAP ZONE SLOT: a 123x123
 * cell of the fixed 2x2 lattice, four to a z-level, with the bottom rows of the cell
 * spent on two 56x40 reserve berths laid side by side. What is left for the template is
 * 119x74, and SSovermap.ruin_fits_in_slot() is the gate that decides it.
 *
 * A template over that gate is not a failure - it takes MAP_TENANT_CLASS_SOLO, a whole
 * z-level, which is exactly what every space ruin cost before packing. What IS a failure
 * is a template too big even for a whole level's build region, because nothing can place
 * it: the site claims a slot, the stamp is refused, the ground is handed back and the
 * signal sits on the chart failing every boarding attempt.
 *
 * This used to guard the old turf-reservation ceiling instead. A ruin asked for
 * template + 118 x template + 86 - two maximum-size berths' worth of padding on BOTH sides
 * of BOTH axes - against a 222x222 reservation z-level, and a template over that ceiling
 * leaked a fresh 255x255 z-level on every dock attempt. That is exactly how oldstation.dmm
 * (112x64, needing 230x150) shipped. Neither the ceiling nor the leak exists any more:
 * ruins are map-zone tenants and the arithmetic that produced them is gone.
 *
 * Both gates are asked through SSovermap rather than restated here, so the test and the
 * live classification can never drift apart. voidcrew_map_packing.dm's
 * test_ruin_slot_placement() is the other half: it proves the gate agrees with the
 * placement region measured off real berths.
 */
/datum/unit_test/voidcrew_ruin_reservation_fit

/datum/unit_test/voidcrew_ruin_reservation_fit/Run()
	var/checked = 0
	var/packs = 0
	var/solo = 0

	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/ruin = SSmapping.space_ruins_templates[template_name]
		if(!istype(ruin))
			continue
		// unpickable templates never reach the overmap on their own, they are
		// surfaced deliberately by a chart, mission or admin - but they still have to be
		// placeable when something does surface them, so they are checked too.

		var/map_path = ruin.mappath
		if(!map_path && ruin.prefix && ruin.suffix)
			map_path = ruin.prefix + ruin.suffix
		if(!map_path)
			TEST_FAIL("Space ruin template '[template_name]' ([ruin.type]) has no resolvable map path, so its size can never be read and it can never load")
			continue

		if(!ruin.width || !ruin.height)
			// /datum/map_template/New() preloads bounds; re-read only if something skipped
			// it. cache = FALSE deliberately: we only want the bounds, and caching would
			// hold a fully parsed copy of every space ruin map for the rest of the run.
			ruin.preload_size(map_path, FALSE)
		if(!ruin.width || !ruin.height)
			TEST_FAIL("Space ruin template '[template_name]' ([map_path]) reports no dimensions, preload_size() could not read it")
			continue

		checked++

		if(SSovermap.ruin_fits_in_slot(ruin))
			packs++
			continue
		solo++

		if(!SSovermap.ruin_fits_in_level(ruin))
			TEST_FAIL("Space ruin '[template_name]' ([map_path]) is [ruin.width]x[ruin.height], which does not fit even a WHOLE z-level's build region. \
				It would spawn on the overmap as a signal that claims a map slot, fails to place its template and hands the ground straight back, \
				failing every docking attempt. Shrink the map, or set unpickable = TRUE and keep it out of the spawn pools.")

	if(!checked)
		TEST_FAIL("No space ruin templates were checked. SSmapping.space_ruins_templates is empty, so this test is not guarding anything")
		return

	// The whole point of packing is that the overwhelming majority of the pool shares
	// z-levels. If a geometry change ever pushed most of it onto whole levels the win
	// would be silently gone, and nothing else in the tree would notice.
	if(packs * 2 < checked)
		TEST_FAIL("Only [packs] of [checked] space ruin templates fit a lattice slot ([solo] would take a whole z-level each). \
			Packing has stopped paying for itself - check MAP_SLOT_RUIN_REGION_WIDTH/HEIGHT in voidcrew/_DEFINES/planet_defines.dm \
			and the berth placement in spawn_dynamic_encounter().")
