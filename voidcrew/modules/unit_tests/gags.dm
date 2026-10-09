/// The gags have what they need: their maps, the icon states they draw, and timings in order.
/datum/unit_test/gags

/datum/unit_test/gags/Run()
	for(var/map_name in list("stairs.dmm", "trains.dmm", "tram.dmm"))
		TEST_ASSERT(fexists("_maps/voidcrew/templates/gags/[map_name]"), "The gags' [map_name] is missing.")
	TEST_ASSERT("skibidi" in icon_states('voidcrew/modules/gags/icons/gags_face.dmi'), "The skibidi face is missing.")
	TEST_ASSERT("head_only" in icon_states('voidcrew/modules/gags/icons/gags_mask.dmi'), "The skibidi mask is missing.")
	TEST_ASSERT("toilet10" in icon_states('icons/obj/watercloset.dmi'), "The skibidi toilet is missing.")
	// What the maps draw as scenery, in place of the things that run the tram.
	TEST_ASSERT("subfloor" in icon_states('icons/obj/tram/tram_structure.dmi'), "The tram's subfloor is missing.")
	TEST_ASSERT("closed" in icon_states('icons/obj/doors/airlocks/tram/tram.dmi'), "The tram's doors are missing.")
	TEST_ASSERT("desto_blank" in icon_states('icons/obj/tram/tram_display.dmi'), "The tram's displays are missing.")
	TEST_ASSERT("tram_controls" in icon_states('icons/obj/machines/computer.dmi'), "The tram's controls are missing.")
	TEST_ASSERT("stairs_wood" in icon_states('icons/obj/stairs.dmi'), "The stairs are missing.")
	// The trip, seventeen steps, and the floor: one for each of the eighteen steps and one more.
	TEST_ASSERT_EQUAL(length(GLOB.gag_stairs_hits), 19, "The fall down the stairs hits the wrong number of things.")
	TEST_ASSERT(sorted(GLOB.gag_stairs_hits), "The fall down the stairs' hits are out of order.")
	TEST_ASSERT(sorted(GLOB.gag_springlock_crunches), "The springlocks' crunches are out of order.")
	for(var/spill in GLOB.gag_springlock_spills)
		TEST_ASSERT(spill in GLOB.gag_springlock_crunches, "The springlocks spill an organ at [spill], which isn't a crunch.")

/datum/unit_test/gags/proc/sorted(list/times)
	for(var/index in 2 to length(times))
		if(times[index] <= times[index - 1])
			return FALSE
	return TRUE
