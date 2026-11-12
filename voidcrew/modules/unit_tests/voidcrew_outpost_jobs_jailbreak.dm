/**
 * Outpost jobs tests: jailbreak (voidcrew/modules/outpost_jobs/). Owner: P7.
 * Helpers are in voidcrew_outpost_jobs_helpers.dm. Fork defines are included after the tests: use literal values
 * with a comment naming the define.
 *
 * The ward's states are the private WARD_* defines of job_jailbreak.dm: "held", "out", "aboard", "taken", "gone".
 * Every test calls the ward's procs with him already in place; only the forced-door test waits (the crowbar's 12 s).
 * Test humans have no client, so a roster member aboard is found as the ward's leader.
 */

/// A ship's deckhand place whose "aboard" is a rectangle of the test room: a bare ship has no hull to be aboard
/datum/ambient_place/ship/jailbreak_test
	/// What counts as aboard, list(min x, min y, max x, max y, z)
	var/list/test_bounds

/datum/ambient_place/ship/jailbreak_test/aboard(turf/tile)
	return ambient_in_bounds(get_turf(tile), test_bounds)

/// Gives `ship` a deckhand place whose aboard is the test room tiles from `dx1`, `dy1` to `dx2`, `dy2`
/datum/unit_test/proc/jailbreak_deck(obj/structure/overmap/ship/ship, dx1, dy1, dx2, dy2)
	var/turf/low = jobs_spot(dx1, dy1)
	var/turf/high = jobs_spot(dx2, dy2)
	var/datum/ambient_place/ship/jailbreak_test/deck = new(ship)
	deck.test_bounds = list(low.x, low.y, high.x, high.y, low.z)
	GLOB.ambient_ship_places[REF(ship)] = deck
	return deck

/**
 * A staged jailbreak at a fake outpost with two cells: list("outpost", "police", "cell", "crew", "ship", "job", "ward").
 * `crew` stands outside the ward's cell door, on the job's roster and on the job's ship.
 */
/datum/unit_test/proc/jailbreak_fixture()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_police_cell/cell = jobs_cells(police)
	if(!cell)
		return null
	var/mob/living/carbon/human/crew = jobs_person(cell.outside_turf)
	var/obj/structure/overmap/ship/ship = jobs_ship(list(crew))
	var/datum/mission/fixer_job/jailbreak/job = allocate(/datum/mission/fixer_job/jailbreak)
	job.job_outpost = outpost
	job.servant = ship
	job.accepting_crew = ship.get_crew_record()
	job.roster += WEAKREF(crew.mind)
	if(!job.stage())
		TEST_FAIL("A jailbreak would not stage at an outpost with two empty cells")
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = job.ward()
	if(!ward)
		TEST_FAIL("A staged jailbreak has no prisoner")
		return null
	allocated += ward
	return list("outpost" = outpost, "police" = police, "cell" = cell, "crew" = crew, "ship" = ship, "job" = job, "ward" = ward)

/// Staging: the prisoner is built in the emptiest cell, on its ward list, behind a shut door; no cell, no job
/datum/unit_test/voidcrew_outpost_jobs_jailbreak_staging

/datum/unit_test/voidcrew_outpost_jobs_jailbreak_staging/Run()
	var/list/fixture = jailbreak_fixture()
	if(!fixture)
		return
	var/datum/outpost_police/police = fixture["police"]
	var/datum/outpost_police_cell/cell = fixture["cell"]
	var/datum/mission/fixer_job/jailbreak/job = fixture["job"]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = fixture["ward"]

	TEST_ASSERT_EQUAL(police.cell_of_ward(ward), cell, "The prisoner is not on the emptiest cell's ward list")
	TEST_ASSERT(get_turf(ward) in cell.tiles, "The prisoner was not put on his cell's floor")
	TEST_ASSERT(cell.door.density, "The prisoner's cell door is open")
	TEST_ASSERT_EQUAL(ward.ward_state, "held", "A staged prisoner is not held") // WARD_HELD
	TEST_ASSERT_NOTNULL(ward.place, "A staged prisoner belongs to no place")
	TEST_ASSERT(!ward.leash_ok(cell.outside_turf), "A held prisoner may walk out of his cell")
	TEST_ASSERT(ward.leash_ok(cell.tiles[1]), "A held prisoner may not stand in his own cell")

	// The offer and the note name the man who was built, within their bounds
	var/list/tokens = job.offer_tokens()
	TEST_ASSERT(length_char(tokens["{name}"]) <= 28, "The prisoner's name runs past its bound") // FIXER_TOKEN_NAME, FIXER_BOUND_NAME
	TEST_ASSERT(length_char(tokens["{look}"]) <= 32, "The prisoner's look runs past its bound") // FIXER_TOKEN_LOOK, FIXER_BOUND_LOOK
	TEST_ASSERT(findtext(tokens["{clock}"], ":"), "The transfer clock is not a time") // FIXER_TOKEN_CLOCK
	TEST_ASSERT_EQUAL(ward.real_name, job.ward_identity["name"], "The prisoner is not the man the offer named")
	var/list/note = job.note_lines()
	TEST_ASSERT(length(note) <= 3, "The note has more than three lines") // FIXER_NOTE_LINES
	for(var/line in note)
		TEST_ASSERT(length_char(line) <= 64, "A note line runs past its bound: [line]") // FIXER_BOUND_NOTE_LINE

	// An outpost with no cell offers no jailbreak and cannot stage one
	var/obj/structure/overmap/trader_outpost/bare = jobs_outpost()
	var/datum/mission/fixer_job/jailbreak/nowhere = allocate(/datum/mission/fixer_job/jailbreak)
	nowhere.job_outpost = bare
	TEST_ASSERT(!nowhere.allowed_at(bare, null), "A jailbreak is offered at an outpost with no cell")
	TEST_ASSERT(!nowhere.stage(), "A jailbreak staged at an outpost with no cell")

	jobs_cleanup(list(fixture["ship"]))

/// Forcing his cell is the police's jailbreak; he follows a forcer on the roster, and walking out through that door is no second crime
/datum/unit_test/voidcrew_outpost_jobs_jailbreak_forced

/datum/unit_test/voidcrew_outpost_jobs_jailbreak_forced/Run()
	var/list/fixture = jailbreak_fixture()
	if(!fixture)
		return
	var/datum/outpost_police/police = fixture["police"]
	var/datum/outpost_police_cell/cell = fixture["cell"]
	var/mob/living/carbon/human/crew = fixture["crew"]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = fixture["ward"]
	var/datum/jobs_test_listener/crimes = allocate(/datum/jobs_test_listener)
	crimes.listen(police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME

	TEST_ASSERT(cell.still_forceable(), "A crowbar does not work on the prisoner's cell")
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	TEST_ASSERT_EQUAL(cell.door.crowbar_act(crew, crowbar), ITEM_INTERACT_SUCCESS, "A crowbar on the prisoner's cell door did not start")
	sleep(14 SECONDS) // OUTPOST_POLICE_CELL_FORCE_TIME is 12 s
	TEST_ASSERT(!cell.door.density, "The forced door did not open")
	var/list/crime = crimes.last()
	TEST_ASSERT_NOTNULL(crime, "Forcing the prisoner's cell counted no crime")
	TEST_ASSERT_EQUAL(crime[1], crew.mind, "The jailbreak was pinned on another")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "Forcing the prisoner's cell was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT(ward.ward_following(), "The prisoner does not follow the crew member who forced his door")
	TEST_ASSERT_EQUAL(ward.ward_leader(), crew, "The prisoner follows someone else")

	// Out through the forced door: no second jailbreak
	var/counted = length(crimes.heard)
	ward.forceMove(jobs_spot(4, 0))
	TEST_ASSERT_EQUAL(ward.ward_state, "out", "A prisoner out of his cell is not out") // WARD_OUT
	TEST_ASSERT_EQUAL(cell.ward_count(), 0, "A prisoner out of his cell is still on its list")
	TEST_ASSERT_EQUAL(length(crimes.heard), counted, "Walking out through a forced door was counted again")

	jobs_cleanup(list(fixture["ship"]))

/// He ignores anyone off the roster: their forcing and their word move him nowhere; the roster's word does, once the door is open
/datum/unit_test/voidcrew_outpost_jobs_jailbreak_outsider

/datum/unit_test/voidcrew_outpost_jobs_jailbreak_outsider/Run()
	var/list/fixture = jailbreak_fixture()
	if(!fixture)
		return
	var/datum/outpost_police/police = fixture["police"]
	var/datum/outpost_police_cell/cell = fixture["cell"]
	var/mob/living/carbon/human/crew = fixture["crew"]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = fixture["ward"]
	var/mob/living/carbon/human/outsider = jobs_person(jobs_spot(4, 1))

	ward.on_cell_forced(police, cell, outsider)
	TEST_ASSERT(!ward.ward_following(), "The prisoner follows an outsider who forced his door")
	ward.talked_to(outsider)
	TEST_ASSERT(!ward.ward_following(), "The prisoner follows an outsider who asked")

	// The roster's word behind a shut door is not enough
	ward.forced_at = 0
	TEST_ASSERT(cell.door.density, "Setup: the prisoner's door is open")
	ward.talked_to(crew)
	TEST_ASSERT(!ward.ward_following(), "The prisoner walked through a shut door")

	cell.open_door(30 SECONDS, wait = TRUE)
	TEST_ASSERT(!cell.door.density, "Setup: the prisoner's door would not open")
	ward.talk_cooldowns = null
	ward.talked_to(crew)
	TEST_ASSERT(ward.ward_following(), "The prisoner does not come when the crew asks at an open door")
	TEST_ASSERT_EQUAL(ward.ward_leader(), crew, "The prisoner follows someone else")

	jobs_cleanup(list(fixture["ship"]))

/// Led out through a door opened for another reason (a release), the leader is reported for the jailbreak (abuse J10)
/datum/unit_test/voidcrew_outpost_jobs_jailbreak_led_out

/datum/unit_test/voidcrew_outpost_jobs_jailbreak_led_out/Run()
	var/list/fixture = jailbreak_fixture()
	if(!fixture)
		return
	var/datum/outpost_police/police = fixture["police"]
	var/datum/outpost_police_cell/cell = fixture["cell"]
	var/mob/living/carbon/human/crew = fixture["crew"]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = fixture["ward"]
	var/datum/jobs_test_listener/crimes = allocate(/datum/jobs_test_listener)
	crimes.listen(police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME

	cell.open_door(30 SECONDS, wait = TRUE)
	TEST_ASSERT(!cell.door.density, "Setup: the prisoner's door would not open")
	TEST_ASSERT(ward.ward_follow(crew), "The prisoner would not follow the crew")
	ward.forceMove(jobs_spot(4, 0))
	var/list/crime = crimes.last()
	TEST_ASSERT_NOTNULL(crime, "Leading the prisoner out of an open cell counted no crime")
	TEST_ASSERT_EQUAL(crime[1], crew.mind, "The jailbreak was pinned on another than his leader")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "Leading the prisoner out was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT_EQUAL(ward.ward_state, "out", "A prisoner led out is not out") // WARD_OUT
	TEST_ASSERT_EQUAL(cell.ward_count(), 0, "A prisoner led out is still on his cell's list")

	jobs_cleanup(list(fixture["ship"]))

/// Aboard the job's ship with the roster is the deed; aboard another ship, or with nobody of the roster, it is not. He never counts as a recruit.
/datum/unit_test/voidcrew_outpost_jobs_jailbreak_aboard

/datum/unit_test/voidcrew_outpost_jobs_jailbreak_aboard/Run()
	var/list/fixture = jailbreak_fixture()
	if(!fixture)
		return
	var/datum/outpost_police_cell/cell = fixture["cell"]
	var/mob/living/carbon/human/crew = fixture["crew"]
	var/obj/structure/overmap/ship/ship = fixture["ship"]
	var/datum/mission/fixer_job/jailbreak/job = fixture["job"]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = fixture["ward"]
	var/datum/ambient_place/ship/deck = jailbreak_deck(ship, 3, 3, 4, 3)
	var/obj/structure/overmap/ship/other_ship = allocate(/obj/structure/overmap/ship)
	jailbreak_deck(other_ship, 3, 1, 4, 1)

	// Out of his cell through a forced door, following the crew
	ward.forced_at = world.time
	ward.ward_left_cell(cell)
	TEST_ASSERT_EQUAL(ward.ward_state, "out", "Setup: the prisoner is not out") // WARD_OUT
	ward.ward_follow(crew)

	// Aboard another ship, with the crew: nothing
	ward.forceMove(jobs_spot(4, 1))
	crew.forceMove(jobs_spot(3, 1))
	TEST_ASSERT(!ward.check_aboard(), "Boarding another ship did the job")
	TEST_ASSERT(!job.deed_done, "Boarding another ship did the job")

	// Aboard the job's ship with his leader still off it: nothing yet
	ward.forceMove(jobs_spot(4, 3))
	TEST_ASSERT(!ward.check_aboard(), "The prisoner aboard with nobody of the crew counted")
	TEST_ASSERT(!job.deed_done, "The prisoner aboard with nobody of the crew counted")

	// With his leader aboard: the deed, and a passenger
	crew.forceMove(jobs_spot(3, 3))
	TEST_ASSERT(ward.check_aboard(), "The prisoner aboard the job's ship with the crew did not count")
	TEST_ASSERT(job.deed_done, "The prisoner aboard the job's ship did not do the job")
	TEST_ASSERT_EQUAL(ward.ward_state, "aboard", "The prisoner aboard is not a passenger") // WARD_ABOARD
	TEST_ASSERT_EQUAL(ward.place, deck, "The passenger does not belong to the ship")
	TEST_ASSERT(!ward.ward_following(), "The passenger is still following")

	// Never a recruit
	TEST_ASSERT_EQUAL(deck.taken, 0, "The passenger counted as a recruit")
	TEST_ASSERT_NULL(deck.pending(), "The passenger holds the ship's recruit place")
	TEST_ASSERT(ambient_ship_can_take(ship), "The passenger stopped the ship taking a stray")

	jobs_cleanup(list(ship))

/// Out with no leader for FIXER_WARD_LOST_TIME, he gives up and the job fails; with a leader at hand, he does not
/datum/unit_test/voidcrew_outpost_jobs_jailbreak_lost

/datum/unit_test/voidcrew_outpost_jobs_jailbreak_lost/Run()
	var/list/fixture = jailbreak_fixture()
	if(!fixture)
		return
	var/datum/outpost_police_cell/cell = fixture["cell"]
	var/mob/living/carbon/human/crew = fixture["crew"]
	var/datum/mission/fixer_job/jailbreak/job = fixture["job"]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = fixture["ward"]

	ward.forced_at = world.time
	ward.ward_left_cell(cell)
	ward.forceMove(jobs_spot(4, 1))

	// A leader at hand: never lost
	ward.ward_follow(crew)
	ward.lost_since = world.time - 60 SECONDS
	ward.ward_tick()
	TEST_ASSERT_EQUAL(ward.lost_since, 0, "The prisoner is lost with his leader beside him")
	TEST_ASSERT_EQUAL(ward.ward_state, "out", "The prisoner gave up with his leader beside him") // WARD_OUT

	// His leader in cuffs: lost, but not at once
	crew.set_handcuffed(new /obj/item/restraints/handcuffs(crew))
	ward.ward_tick()
	TEST_ASSERT(ward.lost_since, "A cuffed leader still counts")
	TEST_ASSERT_EQUAL(ward.ward_state, "out", "The prisoner gave up at once") // WARD_OUT
	TEST_ASSERT(!job.failed, "The job failed at once")

	// 30 s on: he gives up, and the job fails
	ward.lost_since = world.time - 31 SECONDS // FIXER_WARD_LOST_TIME is 30 s
	ward.ward_tick()
	TEST_ASSERT_EQUAL(ward.ward_state, "taken", "The prisoner did not give up when lost") // WARD_TAKEN
	TEST_ASSERT(QDELETED(job) || job.failed, "A lost prisoner did not fail the job")

	jobs_cleanup(list(fixture["ship"]))

/// Dead in his cell, the job fails and the cell lets go of him; at the deadline he is gone once nobody is looking
/datum/unit_test/voidcrew_outpost_jobs_jailbreak_ends

/datum/unit_test/voidcrew_outpost_jobs_jailbreak_ends/Run()
	var/list/fixture = jailbreak_fixture()
	if(!fixture)
		return
	var/datum/outpost_police_cell/cell = fixture["cell"]
	var/datum/mission/fixer_job/jailbreak/job = fixture["job"]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_ward/ward = fixture["ward"]

	// The deadline: he stays in his cell, then goes unseen
	job.on_deadline()
	TEST_ASSERT(QDELETED(job) || job.failed, "The deadline did not fail the job")
	TEST_ASSERT_EQUAL(ward.ward_state, "gone", "The prisoner is not done with at the deadline") // WARD_GONE
	TEST_ASSERT_EQUAL(cell.ward_count(), 1, "The prisoner left his cell's list before he was moved")
	ward.ward_tick()
	TEST_ASSERT(QDELETED(ward), "Nobody watching, the prisoner was not moved at the deadline")
	TEST_ASSERT_EQUAL(cell.ward_count(), 0, "A prisoner moved away is still on the cell's list")
	jobs_cleanup(list(fixture["ship"]))

	// Dead in his cell: the job fails, and he is a body like anyone's
	fixture = jailbreak_fixture()
	if(!fixture)
		return
	cell = fixture["cell"]
	job = fixture["job"]
	ward = fixture["ward"]
	ward.death()
	TEST_ASSERT(QDELETED(job) || job.failed, "The prisoner's death did not fail the job")
	TEST_ASSERT_EQUAL(cell.ward_count(), 0, "A dead prisoner is still held")
	TEST_ASSERT(!QDELETED(ward), "The prisoner's body was taken away")
	jobs_cleanup(list(fixture["ship"]))
