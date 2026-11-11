/**
 * Outpost police tests: police_cell.dm (voidcrew/modules/outpost_police/). Owner: P6.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 *
 * The cells are built by hand on the test room (two cells, a 2x2 and a 1x2, each with its door and sign), and
 * the police is a subtype whose fine, stars and strip the test pins and whose requests it writes down.
 * Nothing waits for the one-second tick or an AI walk: a test places a prisoner (cell.admit), moves bodies
 * and calls police.tick_cells() itself.
 */

/// A police whose fine, stars and strip the test pins; it writes down what the cells ask of it
/datum/outpost_police/cell_test
	/// What charge_fine() answers
	var/fine_result = FALSE
	/// What get_stars() answers
	var/pinned_stars = 1
	/// Times charge_fine() was asked
	var/fine_tries = 0
	/// Times store_property() was asked
	var/store_calls = 0
	/// For each store_property() call: whether the prisoner's cuffs were still on
	var/list/stored_cuffed = list()
	/// close_warrant() calls: list(mind, served)
	var/list/closed = list()
	/// report_crime() calls: list(offender, crime, source)
	var/list/crimes = list()
	/// Every line the station said
	var/list/lines = list()
	/// COMSIG_OUTPOST_POLICE_BOOKED: list(suspect, jailed)
	var/list/booked = list()
	/// COMSIG_OUTPOST_POLICE_RELEASED: the mob
	var/list/released = list()

/datum/outpost_police/cell_test/New(obj/structure/overmap/trader_outpost/new_outpost)
	. = ..()
	RegisterSignal(src, "outpost_police_booked", PROC_REF(note_booked)) // COMSIG_OUTPOST_POLICE_BOOKED
	RegisterSignal(src, "outpost_police_released", PROC_REF(note_released)) // COMSIG_OUTPOST_POLICE_RELEASED

/datum/outpost_police/cell_test/proc/note_booked(datum/source, mob/living/suspect, jailed)
	SIGNAL_HANDLER
	booked += list(list(suspect, jailed))

/datum/outpost_police/cell_test/proc/note_released(datum/source, mob/living/suspect)
	SIGNAL_HANDLER
	released += suspect

/// No clock of its own: the test calls tick_cells()
/datum/outpost_police/cell_test/wake()
	return

/datum/outpost_police/cell_test/get_warrant(datum/mind/who)
	return warrants[who]

/datum/outpost_police/cell_test/get_stars(datum/mind/who)
	return pinned_stars

/datum/outpost_police/cell_test/charge_fine(datum/outpost_warrant/warrant)
	fine_tries++
	return fine_result

/datum/outpost_police/cell_test/store_property(mob/living/carbon/prisoner, mob/living/officer)
	store_calls++
	stored_cuffed += !!prisoner.handcuffed
	return TRUE

/datum/outpost_police/cell_test/close_warrant(datum/mind/who, served)
	closed += list(list(who, served))

/datum/outpost_police/cell_test/report_crime(mob/living/offender, crime, atom/victim, obj/item/source)
	crimes += list(list(offender, crime, source))
	return 3

/datum/outpost_police/cell_test/cell_station_say(line)
	lines += line

/**
 * Two cells on the test room's floor, built the way link_interior() builds them: cell "a" is 2x2 at the bottom
 * left with its door east of the bottom row (the lobby tile outside is x+3); cell "b" is 1x2, three rows up. The
 * police is made last so the teardown deletes the doors before the cells that keep them.
 */
/datum/unit_test/proc/police_cells_fixture()
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	var/list/landmarks = list()
	var/list/doors = list()
	var/list/signs = list()
	for(var/list/spot in list(list(0, 0, "a"), list(1, 0, "a"), list(0, 1, "a"), list(1, 1, "a"), list(0, 3, "b"), list(1, 3, "b")))
		var/obj/effect/landmark/outpost_police_cell/mark = allocate(/obj/effect/landmark/outpost_police_cell, locate(x0 + spot[1], y0 + spot[2], z0))
		mark.cell_id = spot[3]
		landmarks += mark
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door_a = allocate(/obj/machinery/door/airlock/outpost/glass/police_cell, locate(x0 + 2, y0, z0))
	door_a.cell_id = "a"
	doors += door_a
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door_b = allocate(/obj/machinery/door/airlock/outpost/glass/police_cell, locate(x0 + 2, y0 + 3, z0))
	door_b.cell_id = "b"
	doors += door_b
	var/obj/machinery/status_display/outpost_berth/police_cell/sign_a = allocate(/obj/machinery/status_display/outpost_berth/police_cell, locate(x0 + 2, y0 + 1, z0))
	sign_a.cell_id = "a"
	signs += sign_a
	var/obj/machinery/status_display/outpost_berth/police_cell/sign_b = allocate(/obj/machinery/status_display/outpost_berth/police_cell, locate(x0 + 2, y0 + 4, z0))
	sign_b.cell_id = "b"
	signs += sign_b
	var/datum/outpost_police/cell_test/police = allocate(/datum/outpost_police/cell_test)
	police.build_cells(landmarks, doors, signs)
	return police

/// The cell of `police` with this id
/datum/unit_test/proc/police_cell_named(datum/outpost_police/police, cell_id)
	for(var/datum/outpost_police_cell/cell in police.cells)
		if(cell.cell_id == cell_id)
			return cell
	return null

/// A human with a mind at `where`
/datum/unit_test/proc/police_cell_person(turf/where)
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent, where)
	person.mind_initialize()
	return person

/// Police cuffs on `suspect`, put there by `officer` with an officer's own pair (it puts a used pair on them; a used pair cuffs nobody)
/datum/unit_test/proc/police_cell_cuff(mob/living/carbon/human/suspect, mob/living/officer)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police)
	cuffs.apply_cuffs(suspect, officer, TRUE)
	return suspect.handcuffed

/// The last report_crime() call: list(offender, crime, source), or null
/datum/unit_test/proc/police_last_crime(datum/outpost_police/cell_test/police)
	if(!length(police.crimes))
		return null
	return police.crimes[length(police.crimes)]

/**
 * Books a cuffed suspect through `police.book()` with the pinned answers. Returns list(suspect, officer, cell,
 * time the booking began), or null (and the test failed) if the booking did not leave them held. The suspect
 * and officer start on the lobby tile outside the cell that will take them.
 */
/datum/unit_test/proc/police_test_book(datum/outpost_police/cell_test/police, stars, paid)
	police.pinned_stars = stars
	police.fine_result = paid
	var/datum/outpost_police_cell/cell = police.cell_best()
	TEST_ASSERT_NOTNULL(cell, "No cell to book into")
	var/mob/living/carbon/human/suspect = police_cell_person(cell.outside_turf)
	var/mob/living/carbon/human/officer = police_cell_person(get_step(cell.outside_turf, NORTH))
	police_pin_warrant(police, suspect.mind, 12)
	TEST_ASSERT_NOTNULL(police_cell_cuff(suspect, officer), "Setup: the suspect did not get cuffed")
	var/started = world.time
	TEST_ASSERT(police.book(suspect, officer), "book() did not take a cuffed suspect with a warrant")
	TEST_ASSERT(!QDELETED(cell.door) && cell.door.density, "The cell door is open after the booking")
	TEST_ASSERT(get_turf(suspect) in cell.tiles, "The suspect is not on a cell tile after the booking")
	TEST_ASSERT_EQUAL(get_turf(officer), cell.outside_turf, "The officer did not step back out")
	TEST_ASSERT_NULL(suspect.handcuffed, "The suspect is still cuffed after the booking")
	TEST_ASSERT(suspect.mind in cell.prisoners, "The suspect is not a prisoner of the cell")
	return list(suspect, officer, cell, started)

/// A cell is built from its landmarks, door and sign, with the lobby tile outside each door
/datum/unit_test/voidcrew_outpost_police_cell_assemble

/datum/unit_test/voidcrew_outpost_police_cell_assemble/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	TEST_ASSERT_EQUAL(length(police.cells), 2, "Two cells were mapped and [length(police.cells)] were built")
	var/datum/outpost_police_cell/cell_a = police_cell_named(police, "a")
	var/datum/outpost_police_cell/cell_b = police_cell_named(police, "b")
	TEST_ASSERT_NOTNULL(cell_a, "Cell a was not built")
	TEST_ASSERT_NOTNULL(cell_b, "Cell b was not built")
	TEST_ASSERT_EQUAL(length(cell_a.tiles), 4, "Cell a is a 2x2")
	TEST_ASSERT_EQUAL(length(cell_b.tiles), 2, "Cell b is a 1x2")
	TEST_ASSERT_EQUAL(cell_a.door.holding_cell, cell_a, "Cell a's door does not know its cell")
	TEST_ASSERT_EQUAL(cell_b.door.holding_cell, cell_b, "Cell b's door does not know its cell")
	TEST_ASSERT_EQUAL(cell_a.sign.cell_id, "a", "Cell a has another cell's sign")
	TEST_ASSERT_EQUAL(cell_b.sign.cell_id, "b", "Cell b has another cell's sign")
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	TEST_ASSERT_EQUAL(cell_a.outside_turf, locate(x0 + 3, y0, z0), "Cell a's lobby tile is not across its door")
	TEST_ASSERT_EQUAL(cell_b.outside_turf, locate(x0 + 3, y0 + 3, z0), "Cell b's lobby tile is not across its door")
	TEST_ASSERT(cell_a.usable() && cell_b.usable(), "A built cell is not usable")
	TEST_ASSERT_NOTNULL(police.cell_door_turf(), "No lobby tile to walk a suspect to")
	TEST_ASSERT(police.cell_door_turf() in list(cell_a.outside_turf, cell_b.outside_turf), "cell_door_turf() is not outside a cell door")
	TEST_ASSERT_EQUAL(cell_a.sign.message1, "CELL", "A cell's sign does not say CELL")
	// Building again replaces the cells rather than doubling them, and opens nothing
	var/list/landmarks = list()
	for(var/turf/spot in block(run_loc_floor_bottom_left, locate(x0 + 1, y0 + 3, z0)))
		for(var/obj/effect/landmark/outpost_police_cell/mark in spot)
			landmarks += mark
	police.build_cells(landmarks, list(cell_a.door, cell_b.door), list(cell_a.sign, cell_b.sign))
	TEST_ASSERT_EQUAL(length(police.cells), 2, "Building the cells twice left [length(police.cells)] of them")
	var/datum/outpost_police_cell/rebuilt = police_cell_named(police, "a")
	TEST_ASSERT_NOTNULL(rebuilt, "Cell a is gone after a rebuild")
	TEST_ASSERT(rebuilt != cell_a, "A rebuild kept the old cell")
	sleep(2 SECONDS)
	TEST_ASSERT(rebuilt.door.density, "A rebuild opened a cell door")

/// Nothing but the cell opens a cell door; an emag does nothing to it or to a police door; a crowbar on an empty cell does nothing
/datum/unit_test/voidcrew_outpost_police_cell_doors

/datum/unit_test/voidcrew_outpost_police_cell_doors/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door = cell.door
	var/mob/living/carbon/human/person = police_cell_person(cell.outside_turf)
	TEST_ASSERT(door.density, "A cell door starts open")
	TEST_ASSERT(!door.open(), "A cell door opened with no permission from its cell")
	door.bumpopen(person)
	door.try_to_activate_door(person)
	door.try_to_crowbar(null, person, TRUE)
	sleep(1 SECONDS)
	TEST_ASSERT(door.density, "A bump or a click opened a cell door")

	var/obj/item/card/emag/emag = allocate(/obj/item/card/emag)
	TEST_ASSERT(!door.emag_act(person, emag), "An emag was accepted by a cell door")
	TEST_ASSERT(!(door.obj_flags & EMAGGED), "An emag broke a cell door")
	var/obj/machinery/door/airlock/outpost/police/lift_door = allocate(/obj/machinery/door/airlock/outpost/police, locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z))
	TEST_ASSERT(!lift_door.emag_act(person, emag), "An emag was accepted by a police door")
	TEST_ASSERT(!(lift_door.obj_flags & EMAGGED), "An emag broke a police door")
	TEST_ASSERT(lift_door.density, "An emag opened a police door")

	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	TEST_ASSERT_EQUAL(door.crowbar_act(person, crowbar), ITEM_INTERACT_BLOCKING, "A crowbar started on the door of an empty cell")
	TEST_ASSERT(!cell.forcing, "An empty cell's door is being forced")

	// The cell's own permission opens it, once, and it shuts again
	TEST_ASSERT(cell.open_door(10 SECONDS, TRUE), "The cell could not open its own door")
	TEST_ASSERT(!door.density, "The door did not open")
	TEST_ASSERT(cell.shut_door(TRUE), "The cell could not shut its own door")
	TEST_ASSERT(door.density, "The door did not shut")
	TEST_ASSERT(!door.open(), "The permission outlived its opening")

/// A paid fine holds the suspect 30 s at one star and 60 s at two, and never strips them
/datum/unit_test/voidcrew_outpost_police_cell_book_paid

/datum/unit_test/voidcrew_outpost_police_cell_book_paid/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/list/hold_for = list(300, 600) // OUTPOST_POLICE_HOLDS: 30 SECONDS and 60 SECONDS
	for(var/stars in 1 to 2)
		var/list/result = police_test_book(police, stars, TRUE)
		TEST_ASSERT_NOTNULL(result, "The [stars] star booking did not finish")
		var/mob/living/carbon/human/suspect = result[1]
		var/datum/outpost_police_cell/cell = result[3]
		var/started = result[4]
		var/held_until = cell.prisoners[suspect.mind]
		TEST_ASSERT(held_until >= started + hold_for[stars], "[stars] star(s) paid: held until [held_until - started] ticks after the booking began, under [hold_for[stars]]")
		TEST_ASSERT(held_until <= world.time + hold_for[stars], "[stars] star(s) paid: held longer than [hold_for[stars]] ticks from the booking's end")
		TEST_ASSERT(!(suspect.mind in cell.jailed), "A paid fine is a jail term")
		TEST_ASSERT_EQUAL(police.store_calls, 0, "A paid fine stripped the suspect")
		TEST_ASSERT_EQUAL(police.fine_tries, stars, "The fine was tried [police.fine_tries] times for [stars] booking(s)")
		var/list/booking = police.booked[length(police.booked)]
		TEST_ASSERT_EQUAL(booking[1], suspect, "The booking signal named another suspect")
		TEST_ASSERT(!booking[2], "The booking signal said a paid fine was jail")

/// An unpaid fine strips the suspect before the cuffs come off, and holds them 3 min at one star and 6 at two
/datum/unit_test/voidcrew_outpost_police_cell_book_jail

/datum/unit_test/voidcrew_outpost_police_cell_book_jail/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/list/term_for = list(1800, 3600) // OUTPOST_POLICE_JAIL: 3 MINUTES and 6 MINUTES
	for(var/stars in 1 to 2)
		var/list/result = police_test_book(police, stars, FALSE)
		TEST_ASSERT_NOTNULL(result, "The [stars] star booking did not finish")
		var/mob/living/carbon/human/suspect = result[1]
		var/datum/outpost_police_cell/cell = result[3]
		var/started = result[4]
		var/held_until = cell.prisoners[suspect.mind]
		TEST_ASSERT(held_until >= started + term_for[stars], "[stars] star(s) unpaid: held until [held_until - started] ticks after the booking began, under [term_for[stars]]")
		TEST_ASSERT(held_until <= world.time + term_for[stars], "[stars] star(s) unpaid: held longer than [term_for[stars]] ticks from the booking's end")
		TEST_ASSERT(cell.jailed[suspect.mind], "An unpaid fine is not marked as a jail term")
		TEST_ASSERT_EQUAL(police.store_calls, stars, "The strip was asked for [police.store_calls] times for [stars] booking(s)")
		TEST_ASSERT(police.stored_cuffed[stars], "The gear was stored after the cuffs came off")
		TEST_ASSERT(!isnull(cell.bail_due[suspect.mind]), "A jailed prisoner has no bail retry")
		var/list/booking = police.booked[length(police.booked)]
		TEST_ASSERT(booking[2], "The booking signal said a jail term was a paid fine")

/// A booking with no warrant, a downed suspect or an already held one takes nothing and moves nobody
/datum/unit_test/voidcrew_outpost_police_cell_book_refused

/datum/unit_test/voidcrew_outpost_police_cell_book_refused/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/suspect = police_cell_person(cell.outside_turf)
	var/mob/living/carbon/human/officer = police_cell_person(get_step(cell.outside_turf, NORTH))
	police.fine_result = TRUE
	TEST_ASSERT(!police.book(suspect, officer), "A suspect with no warrant was booked")
	police_pin_warrant(police, suspect.mind, 12)
	ADD_TRAIT(suspect, TRAIT_CRITICAL_CONDITION, "outpost_police_test")
	TEST_ASSERT(!police.book(suspect, officer), "A suspect in crit was booked")
	REMOVE_TRAIT(suspect, TRAIT_CRITICAL_CONDITION, "outpost_police_test")
	cell.admit(suspect, world.time + 300)
	TEST_ASSERT(!police.book(suspect, officer), "A suspect already held was booked again")
	TEST_ASSERT_EQUAL(police.fine_tries, 0, "A refused booking tried the fine")
	TEST_ASSERT_EQUAL(get_turf(suspect), cell.outside_turf, "A refused booking moved the suspect")

/// An outpost with no cell tries the fine on the spot, takes the cuffs off and lets the suspect go
/datum/unit_test/voidcrew_outpost_police_cell_no_cell

/datum/unit_test/voidcrew_outpost_police_cell_no_cell/Run()
	var/datum/outpost_police/cell_test/police = allocate(/datum/outpost_police/cell_test)
	var/mob/living/carbon/human/suspect = police_cell_person(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/officer = police_cell_person(get_step(run_loc_floor_bottom_left, NORTH))
	police_pin_warrant(police, suspect.mind, 12)
	TEST_ASSERT_NOTNULL(police_cell_cuff(suspect, officer), "Setup: the suspect did not get cuffed")
	TEST_ASSERT_NULL(police.cell_door_turf(), "A police with no cell has a cell door")
	TEST_ASSERT(police.book(suspect, officer), "book() with no cell did not let the suspect go")
	TEST_ASSERT_EQUAL(police.fine_tries, 1, "The fine was not tried on the spot")
	TEST_ASSERT_EQUAL(police.store_calls, 0, "A booking with no cell stripped the suspect")
	TEST_ASSERT_NULL(suspect.handcuffed, "The suspect is still cuffed")
	TEST_ASSERT_EQUAL(length(police.closed), 1, "The warrant was not closed")
	TEST_ASSERT_EQUAL(police.closed[1][1], suspect.mind, "Another warrant was closed")
	TEST_ASSERT(!police.in_custody(suspect), "A suspect let go is still in custody")

/// A jailed prisoner's fine is tried every 30 s, and the moment it pays they are let out
/datum/unit_test/voidcrew_outpost_police_cell_bail

/datum/unit_test/voidcrew_outpost_police_cell_bail/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 1800, TRUE) // a jail term: OUTPOST_POLICE_JAIL, 3 MINUTES
	police.tick_cells()
	TEST_ASSERT_EQUAL(police.fine_tries, 0, "The fine was tried before the retry was due")
	TEST_ASSERT(cell.bail_due[prisoner.mind] >= world.time + 250, "The first retry is not about 30 seconds off") // OUTPOST_POLICE_BAIL_RETRY, 30 SECONDS
	cell.bail_due[prisoner.mind] = world.time
	police.tick_cells()
	TEST_ASSERT_EQUAL(police.fine_tries, 1, "The retry did not try the fine")
	TEST_ASSERT(prisoner.mind in cell.prisoners, "A prisoner whose fine is still short was let out")
	cell.bail_due[prisoner.mind] = world.time
	police.fine_result = TRUE
	police.tick_cells()
	TEST_ASSERT(!(prisoner.mind in cell.prisoners), "A prisoner whose fine paid is still held")
	TEST_ASSERT_EQUAL(length(police.closed), 1, "Bail did not close the warrant once")
	TEST_ASSERT(police.closed[1][2], "Bail closed the warrant as not served")
	TEST_ASSERT("bail" in police.lines, "The sergeant did not say the bail line") // POLICE_LINE_BAIL
	TEST_ASSERT(prisoner in police.released, "Bail sent no release signal")
	TEST_ASSERT(!police.in_custody(prisoner), "A prisoner let out on bail is still in custody")

/// A term that ends opens the door, closes the warrant, clears the prisoner, and the door shuts again
/datum/unit_test/voidcrew_outpost_police_cell_release

/datum/unit_test/voidcrew_outpost_police_cell_release/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 300) // processing: OUTPOST_POLICE_HOLDS, 30 SECONDS
	police.tick_cells()
	TEST_ASSERT(prisoner.mind in cell.prisoners, "A prisoner was let out before their time was up")
	TEST_ASSERT(cell.door.density, "The door opened before anyone's time was up")
	TEST_ASSERT(police.in_custody(prisoner), "A prisoner in a cell is not in custody")
	cell.prisoners[prisoner.mind] = world.time
	police.tick_cells()
	TEST_ASSERT(!(prisoner.mind in cell.prisoners), "A prisoner whose time was up is still held")
	TEST_ASSERT_EQUAL(length(police.closed), 1, "The release did not close the warrant once")
	TEST_ASSERT_EQUAL(police.closed[1][1], prisoner.mind, "The release closed another warrant")
	TEST_ASSERT(police.closed[1][2], "The release closed the warrant as not served")
	TEST_ASSERT("release" in police.lines, "The sergeant did not say the release line") // POLICE_LINE_RELEASE
	TEST_ASSERT(prisoner in police.released, "The release sent no signal")
	TEST_ASSERT_EQUAL(length(police.crimes), 0, "A release reported a crime")
	sleep(2 SECONDS)
	TEST_ASSERT(!cell.door.density, "The door did not open on release")
	TEST_ASSERT(cell.open_until > world.time, "The door is not held open for the prisoner to leave")
	cell.open_until = 0
	cell.close_check()
	TEST_ASSERT(cell.door.density, "The door did not shut once its time was up")

/// A prisoner who walks out before their time is up is a jailbreak, and is no longer held
/datum/unit_test/voidcrew_outpost_police_cell_jailbreak

/datum/unit_test/voidcrew_outpost_police_cell_jailbreak/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 1800, TRUE)
	police.tick_cells()
	TEST_ASSERT_EQUAL(length(police.crimes), 0, "A prisoner standing in the cell was reported")
	prisoner.forceMove(cell.outside_turf)
	police.tick_cells()
	var/list/crime = police_last_crime(police)
	TEST_ASSERT_NOTNULL(crime, "A prisoner outside the cell was not reported")
	TEST_ASSERT_EQUAL(crime[1], prisoner, "The jailbreak was pinned on another")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "The crime was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT(!(prisoner.mind in cell.prisoners), "A prisoner who walked out is still held")
	TEST_ASSERT(!police.in_custody(prisoner), "A prisoner who walked out is still in custody")
	TEST_ASSERT_EQUAL(length(police.closed), 0, "A jailbreak closed the warrant")
	TEST_ASSERT_EQUAL(length(police.released), 0, "A jailbreak sent a release signal")

/// Abuse M4: a prisoner pulled out is not the escaper. The puller is, the prisoner's clock waits, and they may walk back in
/datum/unit_test/voidcrew_outpost_police_cell_pulled_out

/datum/unit_test/voidcrew_outpost_police_cell_pulled_out/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	var/mob/living/carbon/human/puller = police_cell_person(cell.outside_turf)
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 1800, TRUE)
	// What a drag leaves behind: the puller on the prisoner as they cross the line
	prisoner.pulledby = puller
	prisoner.forceMove(cell.outside_turf)
	police.tick_cells()
	var/list/crime = police_last_crime(police)
	TEST_ASSERT_NOTNULL(crime, "Pulling a prisoner out reported nobody")
	TEST_ASSERT_EQUAL(crime[1], puller, "The jailbreak was pinned on the prisoner, not the one who pulled them")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "The crime was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT(prisoner.mind in cell.prisoners, "A prisoner who was pulled out was let go")
	TEST_ASSERT(prisoner.mind in cell.return_by, "A prisoner who was pulled out has no time to come back")
	TEST_ASSERT(abs(cell.time_left[prisoner.mind] - 1800) <= 20, "The clock did not keep their time: [cell.time_left[prisoner.mind]] left of 1800")
	TEST_ASSERT(police.in_custody(prisoner), "A prisoner who was pulled out is out of custody")
	var/crimes_before = length(police.crimes)
	police.tick_cells()
	TEST_ASSERT_EQUAL(length(police.crimes), crimes_before, "The same drag was reported again")
	// They walk back in: the clock runs on from where it stopped
	prisoner.pulledby = null
	prisoner.forceMove(cell.tiles[1])
	police.tick_cells()
	TEST_ASSERT(!(prisoner.mind in cell.return_by), "A prisoner who came back is still on the way back")
	TEST_ASSERT(abs(cell.prisoners[prisoner.mind] - (world.time + 1800)) <= 40, "A prisoner who came back lost or gained time")
	TEST_ASSERT(cell.jailed[prisoner.mind], "A prisoner who came back lost their jail term")
	// Pulled out again and left there past the time to return, with nobody pulling now: their own doing
	prisoner.pulledby = puller
	prisoner.forceMove(cell.outside_turf)
	police.tick_cells()
	TEST_ASSERT(prisoner.mind in cell.return_by, "A prisoner pulled out a second time has no time to come back")
	prisoner.pulledby = null
	cell.return_by[prisoner.mind] = world.time - 1
	police.tick_cells()
	crime = police_last_crime(police)
	TEST_ASSERT_EQUAL(crime[1], prisoner, "A prisoner who never came back was not reported")
	TEST_ASSERT(!(prisoner.mind in cell.prisoners), "A prisoner who never came back is still held")

/// A prisoner in crit or dead in the cell: the door opens at once and is held for a medic, the term is over, the warrant closed
/datum/unit_test/voidcrew_outpost_police_cell_downed

/datum/unit_test/voidcrew_outpost_police_cell_downed/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 1800, TRUE)
	ADD_TRAIT(prisoner, TRAIT_CRITICAL_CONDITION, "outpost_police_test")
	police.tick_cells()
	TEST_ASSERT(!(prisoner.mind in cell.prisoners), "A prisoner in crit is still serving a term")
	TEST_ASSERT_EQUAL(length(police.closed), 1, "A prisoner in crit did not get their warrant closed")
	TEST_ASSERT(prisoner in police.released, "A prisoner in crit was not let out")
	TEST_ASSERT("medic" in police.lines, "Nobody called a medic") // POLICE_LINE_MEDIC
	TEST_ASSERT(cell.medic_until >= world.time + 1100, "The door is not held open for about two minutes") // OUTPOST_POLICE_CELL_MEDIC_OPEN, 2 MINUTES
	sleep(2 SECONDS)
	TEST_ASSERT(!cell.door.density, "The door did not open for a prisoner in crit")
	cell.close_check()
	TEST_ASSERT(!cell.door.density, "The door shut on a body still in the cell")
	prisoner.forceMove(cell.outside_turf) // the medics take them out
	cell.close_check()
	TEST_ASSERT(cell.door.density, "The door stayed open after the body was out")

	// Dead, in the other cell
	var/datum/outpost_police_cell/cell_b = police_cell_named(police, "b")
	var/mob/living/carbon/human/corpse = police_cell_person(cell_b.tiles[1])
	police_pin_warrant(police, corpse.mind, 12)
	cell_b.admit(corpse, world.time + 300)
	corpse.death()
	police.tick_cells()
	TEST_ASSERT(!(corpse.mind in cell_b.prisoners), "A dead prisoner is still serving a term")
	TEST_ASSERT_EQUAL(length(police.closed), 2, "A dead prisoner did not get their warrant closed")
	sleep(2 SECONDS)
	TEST_ASSERT(!cell_b.door.density, "The door did not open for a dead prisoner")

/// Forcing the door with a crowbar while somebody is held: 12 s, a buzzer and a shout, then the door gives and the forcer is a jailbreak with the tool as the source
/datum/unit_test/voidcrew_outpost_police_cell_forcing

/datum/unit_test/voidcrew_outpost_police_cell_forcing/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	var/mob/living/carbon/human/breaker = police_cell_person(cell.outside_turf)
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 1800, TRUE)
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	TEST_ASSERT_EQUAL(cell.door.crowbar_act(breaker, crowbar), ITEM_INTERACT_SUCCESS, "A crowbar on the door of an occupied cell did not start")
	TEST_ASSERT(cell.forcing, "The cell is not being forced")
	TEST_ASSERT_EQUAL(cell.door.crowbar_act(breaker, crowbar), ITEM_INTERACT_BLOCKING, "A second pry started while one was running")
	TEST_ASSERT("cell_alarm" in police.lines, "Nobody shouted") // POLICE_LINE_CELL_ALARM
	sleep(5 SECONDS)
	TEST_ASSERT(cell.door.density, "The door gave in under 12 seconds") // OUTPOST_POLICE_CELL_FORCE_TIME
	TEST_ASSERT_EQUAL(length(police.crimes), 0, "The forcer was reported before the door gave")
	sleep(9 SECONDS)
	TEST_ASSERT(!cell.forcing, "The cell is still being forced after the door gave")
	TEST_ASSERT(!cell.door.density, "The forced door did not open")
	var/list/crime = police_last_crime(police)
	TEST_ASSERT_NOTNULL(crime, "Forcing the door reported nobody")
	TEST_ASSERT_EQUAL(crime[1], breaker, "The forcer was not the one reported")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "Forcing the door was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT_EQUAL(crime[3], crowbar, "The crowbar was not the evidence")
	TEST_ASSERT(prisoner.mind in cell.prisoners, "Forcing the door let the prisoner go")

/// The wall clock: "CELL" and the time to the next release, two short lines
/datum/unit_test/voidcrew_outpost_police_cell_sign

/datum/unit_test/voidcrew_outpost_police_cell_sign/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	var/mob/living/carbon/human/other = police_cell_person(cell.tiles[2])
	police_pin_warrant(police, prisoner.mind, 12)
	police_pin_warrant(police, other.mind, 12)
	police.tick_cells()
	TEST_ASSERT_EQUAL(cell.sign.message1, "CELL", "An empty cell's sign does not say CELL")
	TEST_ASSERT_EQUAL(cell.sign.message2, "", "An empty cell's sign shows a clock")
	cell.admit(prisoner, world.time + 900) // 90 seconds
	police.tick_cells()
	TEST_ASSERT_EQUAL(cell.sign.message2, "1:30", "A prisoner with 90 seconds left shows [cell.sign.message2]")
	// The next release is the one shown
	cell.admit(other, world.time + 2100)
	police.tick_cells()
	TEST_ASSERT_EQUAL(cell.sign.message2, "1:30", "The sign does not show the nearer release")
	cell.prisoners[prisoner.mind] = world.time + 3600 // six minutes, OUTPOST_POLICE_JAIL at two stars
	cell.prisoners[other.mind] = world.time + 3700
	police.tick_cells()
	TEST_ASSERT_EQUAL(cell.sign.message2, "6:00", "A six minute term shows [cell.sign.message2]")
	cell.prisoners[prisoner.mind] = world.time + 5
	police.tick_cells()
	TEST_ASSERT_EQUAL(cell.sign.message2, "0:01", "Under a second left shows [cell.sign.message2]")
	for(var/datum/outpost_police_cell/each in police.cells)
		TEST_ASSERT(length(each.sign.message1) <= 8 && length(each.sign.message2) <= 8, "A cell sign has a line over 8 characters: '[each.sign.message1]' / '[each.sign.message2]'")

/// Custody runs from police cuffs on to release
/datum/unit_test/voidcrew_outpost_police_cell_custody

/datum/unit_test/voidcrew_outpost_police_cell_custody/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/person = police_cell_person(cell.outside_turf)
	var/mob/living/carbon/human/officer = police_cell_person(get_step(cell.outside_turf, NORTH))
	TEST_ASSERT(!police.in_custody(person), "Somebody walking about is in custody")
	TEST_ASSERT(!police.in_custody(null), "Nobody is in custody")
	TEST_ASSERT_NOTNULL(police_cell_cuff(person, officer), "Setup: the person did not get cuffed")
	TEST_ASSERT(police.in_custody(person), "Somebody in police cuffs is not in custody")
	person.uncuff()
	TEST_ASSERT(!police.in_custody(person), "Somebody with the cuffs off and no cell is in custody")
	cell.admit(person, world.time + 300)
	TEST_ASSERT(police.in_custody(person), "A prisoner is not in custody")
	TEST_ASSERT_EQUAL(police.cell_best(), police_cell_named(police, "b"), "The next booking does not go to the empty cell")
