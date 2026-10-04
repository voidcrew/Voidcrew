/**
 * # Ship hull integrity accounting
 *
 * Hull integrity is derived from turf mass, which means the same measurement has to serve two
 * situations that look identical to it and are opposites in play: something blew a hole in the
 * ship, and the crew is rebuilding the ship. Every bug this file guards against came from the
 * accounting failing to tell those apart.
 *
 * The rules, in one place:
 *
 *  - max_integrity is the hull's *baseline* - how much ship there is meant to be. It rises
 *    whenever mass rises past it, and falls with mass only while the ship is parked, because
 *    that is the only time losing hull is a decision rather than an injury.
 *  - The damage bands are a latch, not a comparison. Each is entered once and announced once,
 *    and leaving one takes a different threshold than entering it did.
 *
 * The failure these replaced was quiet and cumulative: max_integrity was a pure high-water
 * mark, so building a wall raised the baseline and removing that same wall did not lower it.
 * Every build-and-undo cost the hull a permanent notch, pulling a fitted ship module dropped a
 * Goon far enough in one action to "crash" it in its berth, and with no latch on the
 * announcements a crew doing repairs near a boundary got the recovery message once per tile.
 *
 * The values below are restated rather than imported: the .dme includes the unit test block
 * well before voidcrew\_DEFINES, so nothing in voidcrew's define files is in scope here. Same
 * reason voidcrew_missions.dm spells out its quest constants. If a SHIP_INTEGRITY_* define in
 * voidcrew\_DEFINES\overmap.dm moves, these have to move with it - which is the point, because
 * the tests below pin the arithmetic those defines produce.
 */
/// Mirrors SHIP_INTEGRITY_NOMINAL.
#define INTEGRITY_NOMINAL 0
/// Mirrors SHIP_INTEGRITY_DISABLED.
#define INTEGRITY_DISABLED 2
/// Mirrors SHIP_INTEGRITY_MIN_ALLOWANCE.
#define MIN_ALLOWANCE 60
/// Mirrors SHIP_INTEGRITY_ALLOWANCE_FRACTION.
#define ALLOWANCE_FRACTION 0.5
/// Mirrors SHIP_INTEGRITY_UNDOCK_LOCKOUT.
#define UNDOCK_LOCKOUT (3 MINUTES)

/obj/structure/overmap/ship/integrity_dummy
	name = "integrity test hull"
	/// Counts of each latched transition, so a test can assert "exactly once".
	var/destroyed_calls = 0
	var/recovered_calls = 0
	var/critical_starts = 0

// The announcement procs reach for a shuttle, crew and sound channels none of which a bare
// test object has. Counting the calls is the whole assertion anyway.
/obj/structure/overmap/ship/integrity_dummy/on_ship_destroyed()
	destroyed_calls++
	has_crash_landed = TRUE

/obj/structure/overmap/ship/integrity_dummy/on_ship_recovered()
	recovered_calls++
	has_crash_landed = FALSE

/obj/structure/overmap/ship/integrity_dummy/start_critical_alert()
	critical_starts++

/obj/structure/overmap/ship/integrity_dummy/stop_critical_alert()
	return

/obj/structure/overmap/ship/integrity_dummy/update_icon_state()
	return

/// Evaluation is driven by hand here so each step is asserted at a known point.
/obj/structure/overmap/ship/integrity_dummy/queue_integrity_eval()
	return

/// An NPC hull, which must never treat its own losses as remodelling. See the boarding test.
/obj/structure/overmap/ship/npc/integrity_dummy
	name = "integrity test raider"
	// Pre-resolved so tearing the test object down cannot reach SSnpc_ships.on_pirate_resolved()
	// and credit the spawner with a raider it never sent out.
	spawner_resolved = TRUE

/obj/structure/overmap/ship/npc/integrity_dummy/on_ship_destroyed()
	has_crash_landed = TRUE

/obj/structure/overmap/ship/npc/integrity_dummy/on_ship_recovered()
	has_crash_landed = FALSE

/obj/structure/overmap/ship/npc/integrity_dummy/start_critical_alert()
	return

/obj/structure/overmap/ship/npc/integrity_dummy/stop_critical_alert()
	return

/obj/structure/overmap/ship/npc/integrity_dummy/update_icon_state()
	return

/obj/structure/overmap/ship/npc/integrity_dummy/queue_integrity_eval()
	return

/datum/unit_test/voidcrew_ship_integrity

/// Builds a hull of `baseline` mass, parked or under way, already past initialisation.
/datum/unit_test/voidcrew_ship_integrity/proc/make_hull(baseline, hull_state = "idle", hull_type = /obj/structure/overmap/ship/integrity_dummy)
	var/obj/structure/overmap/ship/hull = allocate(hull_type)
	hull.mass = baseline
	hull.max_integrity = baseline
	hull.integrity = baseline
	hull.integrity_initialized = TRUE
	hull.state = hull_state
	return hull

/// Applies a mass change and evaluates it, the way a real tick would.
/datum/unit_test/voidcrew_ship_integrity/proc/step_mass(obj/structure/overmap/ship/hull, delta)
	hull.apply_mass_delta(delta)
	hull.evaluate_integrity()

/datum/unit_test/voidcrew_ship_integrity/Run()
	test_build_and_undo_is_free()
	test_docked_deconstruction_is_not_damage()
	test_flight_damage_survives_docking()
	test_destruction_and_recovery_announce_once()
	test_hysteresis_holds_the_band()
	test_small_hulls_get_an_absolute_allowance()
	test_npc_hulls_never_rebaseline()
	test_failure_locks_the_clamps_past_the_repair()

/**
 * Building a wall and taking it back out has to leave the hull exactly where it started.
 *
 * This is the regression that made every other symptom possible. A high-water baseline moved
 * up on the build and stayed there on the removal, so an afternoon of trial-and-error mapping
 * ground a ship's health down two mass at a time with nothing on screen to explain it.
 */
/datum/unit_test/voidcrew_ship_integrity/proc/test_build_and_undo_is_free()
	var/obj/structure/overmap/ship/integrity_dummy/hull = make_hull(223)

	step_mass(hull, 2) // put a wall up
	TEST_ASSERT_EQUAL(hull.max_integrity, 225, "building a wall should raise the hull's baseline with it")
	TEST_ASSERT_EQUAL(hull.get_integrity_percent(), 100, "a hull that just gained a wall is not damaged")

	step_mass(hull, -2) // take the same wall back out
	TEST_ASSERT_EQUAL(hull.mass, 223, "removing the wall should return the hull to its original mass")
	TEST_ASSERT_EQUAL(hull.max_integrity, 223, "removing a wall the crew just built must take the baseline back down with it")
	TEST_ASSERT_EQUAL(hull.get_integrity_percent(), 100, "build-and-undo must not cost the hull any integrity")

/**
 * A parked crew stripping out a whole section is remodelling, not sinking.
 *
 * Pulling a fitted ship module is a single action worth tens of mass. Against a frozen
 * baseline that read as catastrophic damage and dropped the ship straight into the crashed
 * state while it sat safely in a berth.
 */
/datum/unit_test/voidcrew_ship_integrity/proc/test_docked_deconstruction_is_not_damage()
	var/obj/structure/overmap/ship/integrity_dummy/hull = make_hull(223)

	step_mass(hull, -90) // gut a third of the ship at the drydock

	TEST_ASSERT_EQUAL(hull.mass, 133, "deconstruction should still lower the hull's mass")
	TEST_ASSERT_EQUAL(hull.max_integrity, 133, "a parked hull's baseline follows what the crew removes")
	TEST_ASSERT_EQUAL(hull.get_integrity_percent(), 100, "a deliberately smaller ship is a whole ship, not a damaged one")
	TEST_ASSERT_EQUAL(hull.integrity_state, INTEGRITY_NOMINAL, "working on a docked hull must never trip the damage alarm")
	TEST_ASSERT_EQUAL(hull.destroyed_calls, 0, "a docked hull under the welder must not crash")

/**
 * The other half of the rule: docking must not launder damage away.
 *
 * The baseline only moves when mass moves, so arriving at a berth changes nothing and the
 * crew still has to actually patch the hole before the ship reads whole.
 */
/datum/unit_test/voidcrew_ship_integrity/proc/test_flight_damage_survives_docking()
	var/obj/structure/overmap/ship/integrity_dummy/hull = make_hull(223, "flying")

	step_mass(hull, -40) // a meteor takes a bite out of the hull
	TEST_ASSERT_EQUAL(hull.max_integrity, 223, "damage taken under way must not move the baseline")
	TEST_ASSERT_EQUAL(hull.integrity, 183, "the hull should be reading its lost mass as damage")

	hull.state = "idle" // limp into a berth
	hull.evaluate_integrity()
	TEST_ASSERT_EQUAL(hull.max_integrity, 223, "docking must not write the damage off")
	TEST_ASSERT_EQUAL(hull.integrity, 183, "a docked ship is still as damaged as it was when it arrived")

	step_mass(hull, 40) // weld the hole shut
	TEST_ASSERT_EQUAL(hull.max_integrity, 223, "repairs close the gap to the baseline without raising it")
	TEST_ASSERT_EQUAL(hull.get_integrity_percent(), 100, "a fully patched hull reads whole again")

	// And deconstructing while still damaged carries the deficit across rather than erasing it.
	step_mass(hull, -20)
	step_mass(hull, 0)
	hull.state = "flying"
	step_mass(hull, -30)
	TEST_ASSERT_EQUAL(hull.max_integrity, 203, "the baseline should have followed only the parked removal")
	TEST_ASSERT_EQUAL(hull.integrity, 173, "damage taken after remodelling still counts in full")

/**
 * Each band announces exactly once, however much the hull is worked on afterwards.
 *
 * The reported symptom was a dozen stacked "Hull integrity restored" messages. There were two
 * causes and this covers both: the recovery threshold was re-derived from the last two mass
 * readings rather than latched, and on_ship_recovered() never cleared has_crash_landed, so the
 * ship stayed flagged as a wreck and every later crossing re-announced.
 */
/datum/unit_test/voidcrew_ship_integrity/proc/test_destruction_and_recovery_announce_once()
	var/obj/structure/overmap/ship/integrity_dummy/hull = make_hull(223, "flying")

	step_mass(hull, -120) // through the floor in one bad fight
	TEST_ASSERT_EQUAL(hull.integrity_state, INTEGRITY_DISABLED, "losing more than the damage allowance should disable the hull")
	TEST_ASSERT_EQUAL(hull.destroyed_calls, 1, "the hull should be lost exactly once")

	step_mass(hull, -20) // keep taking hits while down
	TEST_ASSERT_EQUAL(hull.destroyed_calls, 1, "further damage to an already disabled hull must not re-announce")

	// Crawl back up past the recovery threshold, one tile at a time.
	for(var/i in 1 to 100)
		step_mass(hull, 2)
	TEST_ASSERT_EQUAL(hull.integrity_state, INTEGRITY_NOMINAL, "a hull repaired past its recovery threshold should come back online")
	TEST_ASSERT_EQUAL(hull.recovered_calls, 1, "recovery must announce exactly once no matter how many tiles the repair took")
	TEST_ASSERT_EQUAL(hull.has_crash_landed, FALSE, "recovery must clear the crashed flag, or the ship can never be lost again")

	// Now work right on the boundary, which is exactly where a repairing crew spends its time.
	for(var/i in 1 to 12)
		step_mass(hull, -2)
		step_mass(hull, 2)
	TEST_ASSERT_EQUAL(hull.recovered_calls, 1, "welding on and off the boundary must not re-announce recovery")
	TEST_ASSERT_EQUAL(hull.destroyed_calls, 1, "welding on and off the boundary must not re-crash the ship")

/**
 * The tile that trips an alarm must not also be the tile that clears it.
 *
 * Without separate entry and exit thresholds a hull sitting on the boundary flips band on
 * every single tile, which is what turned an ordinary repair into a stream of notifications.
 */
/datum/unit_test/voidcrew_ship_integrity/proc/test_hysteresis_holds_the_band()
	var/obj/structure/overmap/ship/integrity_dummy/hull = make_hull(200, "flying")
	// allowance = max(60, 100) = 100. disabled at 100, recovery at 200 - 70 = 130.

	step_mass(hull, -100)
	TEST_ASSERT_EQUAL(hull.integrity_state, INTEGRITY_DISABLED, "the hull should be disabled at its allowance")

	step_mass(hull, 25) // repaired above the disable line, but not to the recovery line
	TEST_ASSERT_EQUAL(hull.integrity_state, INTEGRITY_DISABLED, "clearing the disable line must not be enough to come back online")
	TEST_ASSERT_EQUAL(hull.recovered_calls, 0, "a partial repair must not announce recovery")

	step_mass(hull, 5) // and now onto the recovery line
	TEST_ASSERT_EQUAL(hull.integrity_state, INTEGRITY_NOMINAL, "reaching the recovery threshold should bring the hull back")
	TEST_ASSERT_EQUAL(hull.recovered_calls, 1, "recovery announces on the transition")

/**
 * Very small hulls get an absolute allowance instead of a percentage.
 *
 * A survey-commissioned hull can be a sealed shack massing under thirty. Half of that is
 * inside a single explosion and a couple of welded walls, which made the percentage bands
 * meaningless at that scale - the ship was hair-trigger in exactly the way the report
 * described. Below roughly 120 mass the floor takes over; no shipped hull is that small.
 */
/datum/unit_test/voidcrew_ship_integrity/proc/test_small_hulls_get_an_absolute_allowance()
	var/obj/structure/overmap/ship/integrity_dummy/shack = make_hull(30, "flying")
	TEST_ASSERT_EQUAL(shack.integrity_damage_allowance(), MIN_ALLOWANCE, "a tiny hull's allowance should come from the floor, not the fraction")

	step_mass(shack, -16) // over half the shack
	TEST_ASSERT_EQUAL(shack.integrity_state, INTEGRITY_NOMINAL, "a hull small enough to be under the floor must not be disabled by half of itself")

	// The floor must not bind on real hulls - the smallest shipped one, the medieval sloop,
	// masses 127, and the Goon 223. Both should still be on the fraction.
	var/obj/structure/overmap/ship/integrity_dummy/sloop = make_hull(127, "flying")
	TEST_ASSERT_EQUAL(sloop.integrity_damage_allowance(), 127 * ALLOWANCE_FRACTION, "shipped hulls should still use the percentage band")

	var/obj/structure/overmap/ship/integrity_dummy/goon = make_hull(223, "flying")
	TEST_ASSERT_EQUAL(goon.integrity_disabled_threshold(), 223 * ALLOWANCE_FRACTION, "a Goon should still be disabled at half its hull")

/**
 * An NPC raider must not heal as it is taken apart.
 *
 * Interdicting a pirate leaves it docked and idle - which is precisely the state a boarding
 * party wrecks it in. If the parked-hull rule applied, its baseline would track the breaches
 * down, it would read 100% throughout, and update_boarding_state() would pull can_board back
 * to FALSE with the boarders already inside.
 */
/datum/unit_test/voidcrew_ship_integrity/proc/test_npc_hulls_never_rebaseline()
	var/obj/structure/overmap/ship/npc/integrity_dummy/raider = make_hull(300, "idle", /obj/structure/overmap/ship/npc/integrity_dummy)

	TEST_ASSERT(!raider.hull_baseline_follows_losses(), "an NPC hull must never treat its losses as remodelling")

	step_mass(raider, -80) // boarders blowing through bulkheads
	TEST_ASSERT_EQUAL(raider.max_integrity, 300, "a docked raider's baseline must hold while it is being breached")
	TEST_ASSERT_EQUAL(raider.integrity, 220, "the raider should read as damaged, not remodelled")

/**
 * A hull that fails is grounded for a fixed period, and repairing it does not buy that back.
 *
 * The whole point of the lockout is that it survives the repair: a crew that patches the last
 * breach gets a ship reading 100% with the clamps still on. Nothing else in the integrity
 * system behaves that way - every other consequence of damage is undone by fixing the damage -
 * so it is exactly the kind of rule a later refactor tidies away by hanging the cooldown off
 * the alarm state instead of off the failure.
 *
 * The clock runs from the failure, not from the repair, which is what makes a long rebuild
 * cost nothing extra.
 */
/datum/unit_test/voidcrew_ship_integrity/proc/test_failure_locks_the_clamps_past_the_repair()
	var/obj/structure/overmap/ship/integrity_dummy/hull = make_hull(200, "flying")
	// allowance = max(60, 100) = 100. disabled at 100, recovery at 200 - 70 = 130.

	TEST_ASSERT(COOLDOWN_FINISHED(hull, integrity_undock_lockout), "an undamaged hull must not be holding an undock lockout")

	step_mass(hull, -100)
	TEST_ASSERT_EQUAL(hull.integrity_state, INTEGRITY_DISABLED, "the hull should be disabled at its allowance")
	TEST_ASSERT(!COOLDOWN_FINISHED(hull, integrity_undock_lockout), "a hull failure must arm the undock lockout")

	// The clock is armed by the failure, so the whole lockout is still ahead of the ship.
	TEST_ASSERT(COOLDOWN_TIMELEFT(hull, integrity_undock_lockout) > UNDOCK_LOCKOUT - (5 SECONDS), "the lockout should run its full length from the moment of failure")

	// Weld it back to whole, the way a fast crew with a stack of rods would.
	step_mass(hull, 100)
	TEST_ASSERT_EQUAL(hull.integrity_state, INTEGRITY_NOMINAL, "a fully repaired hull should be back in the nominal band")
	TEST_ASSERT_EQUAL(hull.get_integrity_percent(), 100, "the repair should have closed the gap to the baseline")
	TEST_ASSERT(!COOLDOWN_FINISHED(hull, integrity_undock_lockout), "repairing the hull must not clear the post-failure lockout")

	// A second failure re-arms from scratch rather than serving out what was left of the first.
	// Wound the clock down by hand first - nothing sleeps in here, so an untouched cooldown
	// would read full length either way and the assertion would prove nothing.
	COOLDOWN_START(hull, integrity_undock_lockout, 1 SECONDS)
	step_mass(hull, -100)
	TEST_ASSERT(COOLDOWN_TIMELEFT(hull, integrity_undock_lockout) > UNDOCK_LOCKOUT - (5 SECONDS), "a fresh failure should restart the lockout, not inherit what was left of the last one")

#undef INTEGRITY_NOMINAL
#undef INTEGRITY_DISABLED
#undef MIN_ALLOWANCE
#undef ALLOWANCE_FRACTION
#undef UNDOCK_LOCKOUT
