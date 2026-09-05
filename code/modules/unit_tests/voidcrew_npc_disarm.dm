/// Minimal hulls exercise the real retirement and derelict sweep without loading maps.
/obj/structure/overmap/ship/npc/disarm_test
	name = "disarm test pirate"
	var/test_occupied = FALSE

/obj/structure/overmap/ship/npc/disarm_test/has_active_crew()
	return test_occupied

/datum/npc_combat_interface/disarm_test
	ever_had_weapons = TRUE
	var/test_intact = TRUE

/datum/npc_combat_interface/disarm_test/has_intact_weapons()
	return test_intact

/datum/unit_test/voidcrew_npc_disarm

/datum/unit_test/voidcrew_npc_disarm/proc/make_pirate()
	var/obj/structure/overmap/ship/npc/disarm_test/ship = allocate(/obj/structure/overmap/ship/npc/disarm_test)
	ship.combat_interface = new /datum/npc_combat_interface/disarm_test()
	return ship

/// Isolate the real sweep from the round's ships; restore its roster before assertions.
/datum/unit_test/voidcrew_npc_disarm/proc/sweep(list/ships)
	var/list/saved_ships = SSovermap.simulated_ships
	SSovermap.simulated_ships = ships.Copy()
	SSovermap.sweep_derelicts()
	for(var/obj/structure/overmap/ship/ship as anything in ships)
		if(QDELETED(ship))
			saved_ships -= ship
	SSovermap.simulated_ships = saved_ships

/datum/unit_test/voidcrew_npc_disarm/Run()
	var/obj/structure/overmap/ship/npc/disarm_test/ship = make_pirate()
	var/datum/npc_combat_interface/disarm_test/combat = ship.combat_interface
	TEST_ASSERT(!ship.resolve_disarmed(), "Intact weapons must not retire a pirate just because they cannot fire")
	TEST_ASSERT(isnull(ship.disarmed_despawn_at), "An armed pirate must not have a cleanup deadline")

	combat.test_intact = FALSE
	combat.ever_had_weapons = FALSE
	TEST_ASSERT(!ship.resolve_disarmed(), "A template that never had weapons must not churn the pirate pool")
	combat.ever_had_weapons = TRUE
	ship.retreat_without_weapons = FALSE
	TEST_ASSERT(!ship.resolve_disarmed(), "A pirate configured to fight without guns must not retire")
	ship.retreat_without_weapons = TRUE
	TEST_ASSERT(ship.resolve_disarmed("disarmed (reconcile)"), "A physically disarmed pirate must retire")
	TEST_ASSERT(ship.spawner_resolved, "Disarming must still release the pirate's pool slot")
	TEST_ASSERT(ship.disarmed_despawn_at > world.time, "Retirement must grant time to salvage the hull")
	var/deadline = ship.disarmed_despawn_at
	TEST_ASSERT(!ship.resolve_disarmed(), "Repeated disarm checks must not resolve a second time")
	TEST_ASSERT_EQUAL(ship.disarmed_despawn_at, deadline, "Repeated checks must not extend the salvage window")

	sweep(list(ship))
	TEST_ASSERT(!QDELETED(ship), "The sweep must preserve a disarmed pirate during its salvage window")
	ship.disarmed_despawn_at = world.time - 1
	ship.test_occupied = TRUE
	sweep(list(ship))
	TEST_ASSERT(!QDELETED(ship), "Players aboard must postpone expired pirate cleanup")
	ship.test_occupied = FALSE

	// A guest overmap token in the host's contents represents ship-to-ship docking.
	var/obj/structure/overmap/ship/guest = allocate(/obj/structure/overmap/ship/integrity_dummy)
	guest.forceMove(ship)
	sweep(list(ship))
	TEST_ASSERT(!QDELETED(ship), "A docked guest ship must prevent its host from being deleted")
	guest.forceMove(run_loc_floor_bottom_left)
	sweep(list(ship))
	TEST_ASSERT(QDELETED(ship), "An expired, unclaimed pirate must be removed once boarding ends")

	var/obj/structure/overmap/ship/npc/disarm_test/claimed = make_pirate()
	claimed.player_controlled = TRUE
	claimed.disarmed_despawn_at = world.time - 1
	claimed.crewless_since = world.time
	TEST_ASSERT(!claimed.resolve_disarmed(), "A captured pirate must never be retired by disarm checks")
	TEST_ASSERT(!claimed.despawn_disarmed(), "The direct cleanup entry point must protect captured ships")
	sweep(list(claimed))
	TEST_ASSERT(!QDELETED(claimed), "Claiming a hull must exempt it from its old disarm deadline")

	var/obj/structure/overmap/ship/npc/disarm_test/first = make_pirate()
	var/obj/structure/overmap/ship/npc/disarm_test/second = make_pirate()
	first.disarmed_despawn_at = world.time - 1
	second.disarmed_despawn_at = world.time - 1
	sweep(list(first, second))
	TEST_ASSERT(QDELETED(first), "The first expired pirate should be removed")
	TEST_ASSERT(!QDELETED(second), "Expensive hull cleanup must remain limited to one per sweep")
	sweep(list(second))
	TEST_ASSERT(QDELETED(second), "The next sweep must continue cleaning expired pirates")
