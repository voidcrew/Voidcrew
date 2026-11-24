/**
 * Outpost police tests: a prisoner who breaks their own cell door, and a booking whose outpost goes while its door
 * shuts (police_cell.dm). Uses the cell fixture of voidcrew_outpost_police_cell.dm.
 */

/// A prisoner who breaks their own cell door is charged with it, as anyone opening a held cell is, and stays held while they stay on the cell floor
/datum/unit_test/voidcrew_outpost_police_cell_own_door

/datum/unit_test/voidcrew_outpost_police_cell_own_door/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 10 MINUTES, TRUE)
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	prisoner.put_in_hands(crowbar)
	// The door tells its cell who opened it (police_cell.dm, the cell door's open())
	cell.door_opened(prisoner, crowbar)
	var/list/crime = police_last_crime(police)
	TEST_ASSERT_NOTNULL(crime, "A prisoner breaking their own cell door was no crime")
	TEST_ASSERT_EQUAL(crime?[1], prisoner, "The charge for breaking the door went to [crime?[1]], not the prisoner who broke it")
	TEST_ASSERT_EQUAL(crime?[2], "jailbreak", "Breaking their own cell door was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT_EQUAL(crime?[3], crowbar, "The crowbar was not the evidence")
	TEST_ASSERT("cell_alarm" in police.lines, "Nobody raised the alarm") // POLICE_LINE_CELL_ALARM
	// Still on the cell floor: still a prisoner, and nobody fires on someone in a cell
	police.tick_cells()
	TEST_ASSERT(prisoner.mind in cell.prisoners, "A prisoner who broke the door but stayed inside was let go")
	TEST_ASSERT(police.in_custody(prisoner), "A prisoner who broke the door but stayed inside is out of custody")

/// A booking whose police are torn down while the door shuts on the prisoner ends quietly (the old SEND_SIGNAL on a null police)
/datum/unit_test/voidcrew_outpost_police_cell_book_torn_down
	var/datum/outpost_police/cell_test/watched_police
	var/datum/outpost_police_cell/watched_cell
	var/datum/mind/watched_mind
	var/torn_down = FALSE

/datum/unit_test/voidcrew_outpost_police_cell_book_torn_down/proc/note_close(datum/source, forced)
	SIGNAL_HANDLER
	// Only the last shut, once the prisoner is held and their booking is over
	if(torn_down || QDELETED(watched_cell) || !(watched_mind in watched_cell.prisoners) || !isnull(watched_cell.booking[watched_mind]))
		return
	torn_down = TRUE
	qdel(watched_police)

/datum/unit_test/voidcrew_outpost_police_cell_book_torn_down/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	police.pinned_stars = 1
	police.fine_result = TRUE
	var/datum/outpost_police_cell/cell = police.cell_best()
	TEST_ASSERT_NOTNULL(cell, "No cell to book into")
	var/mob/living/carbon/human/suspect = police_cell_person(cell.outside_turf)
	var/mob/living/carbon/human/officer = police_cell_person(get_step(cell.outside_turf, NORTH))
	police_pin_warrant(police, suspect.mind, 12)
	TEST_ASSERT_NOTNULL(police_cell_cuff(suspect, officer), "Setup: the suspect did not get cuffed")
	watched_police = police
	watched_cell = cell
	watched_mind = suspect.mind
	RegisterSignal(cell.door, COMSIG_AIRLOCK_CLOSE, PROC_REF(note_close))
	var/result = police.book(suspect, officer)
	TEST_ASSERT(torn_down, "Setup: the police were never torn down as the door shut")
	TEST_ASSERT(!isnull(result), "book() did not return after its police were torn down")
	TEST_ASSERT(!result, "book() said the booking went through for police that are gone")

/datum/unit_test/voidcrew_outpost_police_cell_book_torn_down/Destroy()
	watched_police = null
	watched_cell = null
	watched_mind = null
	return ..()
