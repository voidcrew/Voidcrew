/**
 * Bounty hunting's seams (P0): the shared types come up and go away with no arguments, as
 * create_and_destroy makes them, and the prison's bounty hooks leave an ordinary prisoner exactly
 * as they were. Both stay true after every package lands.
 *
 * Owner: P0 seams (frozen); only the integration lead edits this file. Fork defines are included
 * after the tests, so the values here are literals.
 */
/datum/unit_test/voidcrew_bounty_seams

/datum/unit_test/voidcrew_bounty_seams/Run()
	// Every criminal, decoy, companion and bounty object, made with no arguments.
	for(var/type in typesof(/mob/living/basic/bounty_criminal, /mob/living/basic/bounty_companion, /obj/effect/bounty_sighting, /obj/item/paper/bounty_warrant, /obj/structure/bounty_wanted_board))
		var/atom/thing = allocate(type)
		TEST_ASSERT(!QDELETED(thing), "[type] was deleted as it was made")

	// Records get their own ids; postings start open.
	var/datum/bounty_record/first = new
	var/datum/bounty_record/second = new
	TEST_ASSERT(first.id && first.id != second.id, "Two records share the id [first.id]")
	TEST_ASSERT_EQUAL(first.status, "wanted", "A new record is [first.status], not wanted") // BOUNTY_RECORD_WANTED
	var/datum/criminal_bounty/posting = new
	TEST_ASSERT_EQUAL(posting.status, "open", "A new posting is [posting.status], not open") // BOUNTY_POSTING_OPEN

	// An ordinary prisoner: no record, and every bounty helper neutral.
	var/mob/living/basic/outpost_prisoner/prisoner = allocate(/mob/living/basic/outpost_prisoner)
	TEST_ASSERT_NULL(prisoner.bounty_record, "An ordinary prisoner has a bounty record")
	TEST_ASSERT_EQUAL(prisoner.bounty_damage_mult(), 1, "An ordinary prisoner's blows are scaled")
	TEST_ASSERT_EQUAL(prisoner.bounty_mood_scale(), 1, "An ordinary prisoner's mood losses are scaled")
	TEST_ASSERT_EQUAL(prisoner.bounty_threat_bonus(), 0, "An ordinary prisoner's threat line is moved")
	TEST_ASSERT_EQUAL(prisoner.bounty_riot_bonus(), 0, "An ordinary prisoner's riot line is moved")
	TEST_ASSERT_EQUAL(prisoner.bounty_breakout_mult(), 1, "An ordinary prisoner's breakout blows are scaled")
	TEST_ASSERT_EQUAL(prisoner.bounty_cuff_mult(), 1, "Cuffing an ordinary prisoner takes longer or shorter")
	TEST_ASSERT_NULL(bounty_experiment_refusal(prisoner), "Kessler refuses an ordinary prisoner")

	// A prisoner made from a record keeps it.
	var/datum/bounty_record/record = new
	record.name = "Test Criminal"
	record.gender = MALE
	var/mob/living/basic/outpost_prisoner/caught = allocate(/mob/living/basic/outpost_prisoner, null, record)
	TEST_ASSERT_EQUAL(caught.bounty_record, record, "A prisoner made from a record did not keep it")
