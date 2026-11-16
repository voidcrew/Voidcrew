/**
 * Trader outpost berths are shipyards (outpost_shipyard.dm).
 *
 * A build claims a free berth slot at once and builds the hangar when the hull is known. That hangar
 * keeps its shipyard console, protected like the rest of the berth. Only the builder may ride down
 * to it, every slot counts toward the cap, and an abandoned build gives its slot back.
 */
/datum/unit_test/voidcrew_trader_shipyard_berths
	/// Bare mobile port standing in for a loaded hull; docking ports only delete when forced.
	var/obj/docking_port/mobile/voidcrew/fake_port
	var/list/datum/outpost_berth/held = list()
	/// Keyed test mobs; their keys go before they are deleted.
	var/list/mob/living/keyed = list()

/datum/unit_test/voidcrew_trader_shipyard_berths/Destroy()
	for(var/mob/living/person as anything in keyed)
		if(!QDELETED(person))
			person.ckey = null
	keyed = null
	for(var/datum/outpost_berth/berth as anything in held)
		if(!QDELETED(berth))
			qdel(berth)
	held = null
	if(fake_port && !QDELETED(fake_port))
		qdel(fake_port, force = TRUE)
	fake_port = null
	return ..()

/// Stands in for the build that owns a berth.
/datum/trader_shipyard_test_build
	parent_type = /datum/checkpoint_construction

/datum/trader_shipyard_test_build/New(owner_ckey)
	captain_ckey = owner_ckey

/datum/trader_shipyard_test_build/Destroy(force)
	state = "failed" // CHECKPOINT_BUILD_FAILED: voidcrew defines load after the unit tests
	return ..()

/datum/unit_test/voidcrew_trader_shipyard_berths/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost/general)
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	outpost.template_bottom_left = run_loc_floor_bottom_left
	TEST_ASSERT(!outpost.available_ship_bay(), "An unloaded trader outpost offered a berth to build in")
	outpost.loaded = TRUE
	TEST_ASSERT(outpost.shipyard_open(), "A loaded trader outpost's shipyard is closed")
	TEST_ASSERT(outpost.available_ship_bay(), "An empty trader outpost has no berth to build in")

	var/datum/trader_shipyard_test_build/build = allocate(/datum/trader_shipyard_test_build, "tradershipyardcaptain")
	var/datum/outpost_berth/berth = outpost.reserve_rebuild_bay(build)
	TEST_ASSERT_NOTNULL(berth, "No berth was reserved for a build")
	held += berth
	TEST_ASSERT_EQUAL(outpost.berths[berth.berth_number], berth, "The reserved berth does not hold its slot")
	TEST_ASSERT(!berth.has_ground() && berth.has_build_ground(), "A reserved berth built its hangar before the hull was known")

	var/mob/living/carbon/human/captain = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	captain.ckey = "tradershipyardcaptain"
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	stranger.ckey = "tradershipyardstranger"
	keyed += list(captain, stranger)
	TEST_ASSERT(berth.allows_entry(captain), "The builder cannot ride down to their own build")
	TEST_ASSERT(!berth.allows_entry(stranger), "A stranger can ride down to someone else's build")

	fake_port = new(run_loc_floor_bottom_left)
	fake_port.width = 5
	fake_port.height = 7
	fake_port.dwidth = 2
	fake_port.dheight = 0
	fake_port.port_direction = NORTH
	TEST_ASSERT(outpost.prepare_rebuild_bay(berth, fake_port), "The reserved berth's hangar could not be built")
	TEST_ASSERT(berth.has_ground() && !berth.ground_on_build, "The built berth holds no ground")
	TEST_ASSERT_NOTNULL(berth.shipyard, "The trader berth has no shipyard console")
	TEST_ASSERT(berth.contains_turf(get_turf(berth.shipyard)), "The shipyard console is outside its berth")
	TEST_ASSERT(HAS_TRAIT(berth.shipyard, "outpost_property"), "The berth's shipyard console is not outpost property")
	TEST_ASSERT_EQUAL(get_shipyard_host(berth.shipyard), outpost, "The berth's console does not serve its outpost")
	TEST_ASSERT(berth in outpost.shipyard_berths(), "A trader berth is not a shipyard berth")

	// The rest of the slots fill up, and then nothing more can be built.
	for(var/i in 2 to outpost.berth_capacity())
		var/datum/outpost_berth/filler = outpost.reserve_rebuild_bay(allocate(/datum/trader_shipyard_test_build, "tradershipyardfiller[i]"))
		TEST_ASSERT_NOTNULL(filler, "Berth slot [i] could not be reserved")
		held += filler
	TEST_ASSERT(!outpost.available_ship_bay(), "A full trader outpost still offers a berth")
	TEST_ASSERT_NOTNULL(outpost.rebuild_bay_denial(), "A full trader outpost does not refuse builds")
	TEST_ASSERT_NULL(outpost.reserve_rebuild_bay(allocate(/datum/trader_shipyard_test_build, "tradershipyardextra")), "A seventh berth was reserved")

	// A build that ends without a ship gives its slot back.
	var/datum/outpost_berth/filler = held[2]
	var/filler_slot = filler.berth_number
	filler.finish_rebuild(filler.rebuild_owner.resolve())
	TEST_ASSERT(QDELETED(filler), "An abandoned build kept its berth")
	TEST_ASSERT_NULL(outpost.berths[filler_slot], "An abandoned build kept its berth slot")
	TEST_ASSERT(outpost.available_ship_bay(), "A freed slot is not offered again")
