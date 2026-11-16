/**
 * Dock terminal CREWS payload (voidcrew/modules/lobby_terminal/lobby_crews.dm).
 *
 * The list never carries who is aboard; the roster goes out only for the ship whose record
 * is open, and only while that ship is still listed. The memo is cut to what a screen draws.
 */

/// A terminal with no client or window that lists only the ships the test gives it.
/datum/lobby_terminal/crews_test
	var/list/test_ships = list()

/datum/lobby_terminal/crews_test/New()
	return // No client: skip the window and signal setup.

/datum/lobby_terminal/crews_test/crew_ships()
	return test_ships

/datum/unit_test/lobby_crews_payload

/datum/unit_test/lobby_crews_payload/Run()
	var/datum/lobby_terminal/crews_test/terminal = new
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/obj/structure/overmap/ship/other = allocate(/obj/structure/overmap/ship)
	ship.job_slots = list()
	other.job_slots = list()
	ship.manifest = list("Mara Voss" = null, "Hal Okafor" = null)
	ship.memo = ""
	for(var/i in 1 to 500)
		ship.memo += "x"
	terminal.test_ships = list(ship, other)

	var/list/data = terminal.crews_data(null)
	var/list/crews = data["crews"]
	TEST_ASSERT_EQUAL(length(crews), 2, "Both test ships should be listed")
	for(var/list/entry as anything in crews)
		TEST_ASSERT(!("aboard" in entry), "A list entry still carries who is aboard")
		TEST_ASSERT("mine" in entry, "A list entry lacks the own-crew flag")
		TEST_ASSERT(length(entry["memo"]) <= 260, "The memo was not cut to 260 characters")
	TEST_ASSERT_NULL(data["roster"], "A roster was sent with no record open")

	TEST_ASSERT(terminal.crew_set_open(REF(ship)), "Opening a listed ship should update the page")
	TEST_ASSERT(!terminal.crew_set_open(REF(ship)), "Opening the same ship again should not")
	data = terminal.crews_data(null)
	var/list/roster = data["roster"]
	TEST_ASSERT(islist(roster), "No roster after opening a record")
	TEST_ASSERT_EQUAL(roster["ref"], REF(ship), "The roster is for the wrong ship")
	TEST_ASSERT_EQUAL(length(roster["names"]), 2, "The roster should name both crew")
	TEST_ASSERT_EQUAL(roster["more"], 0, "Nobody should be left over")

	// A ship that is no longer listed has no roster, and a forged ref clears the open record.
	terminal.test_ships = list(other)
	data = terminal.crews_data(null)
	TEST_ASSERT_NULL(data["roster"], "A roster was sent for a ship that has left")
	terminal.test_ships = list(ship, other)
	terminal.crew_set_open("\[0xdeadbeef]")
	TEST_ASSERT_NULL(terminal.crew_open_ref, "A bad ref did not clear the open record")

	terminal.crew_set_open(REF(other))
	terminal.crew_set_open(null)
	data = terminal.crews_data(null)
	TEST_ASSERT_NULL(data["roster"], "A roster was sent after the record closed")
	qdel(terminal)
