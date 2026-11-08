/// A piece for the tests only: weight 0, so it never rolls. It counts the hooks it gets.
/datum/bounty_chrome/unit_test
	key = "unit_test"
	name = "test chrome"
	weight = 0
	organ_looks = list(/obj/item/organ/cyberimp/cyberware/cascade)
	examine_text = "%THEIR test chrome hums."
	var/fights = 0
	var/ticks = 0
	var/emps = 0
	var/reboots = 0

/datum/bounty_chrome/unit_test/on_fight_start(atom/target)
	fights++

/datum/bounty_chrome/unit_test/on_tick(seconds_per_tick, fighting)
	ticks++

/datum/bounty_chrome/unit_test/on_emp(severity)
	emps++

/datum/bounty_chrome/unit_test/on_reboot()
	reboots++

/// The chrome framework: rolling, installing, the hooks, an EMP, examine, and the worn look on the dummy
/datum/unit_test/voidcrew_bounty_chrome

/datum/unit_test/voidcrew_bounty_chrome/Run()
	// Rolling: every key a roll gives is a real piece; nobody gets a piece that doesn't suit them
	for(var/i in 1 to 50)
		for(var/key in bounty_roll_chrome(3, "normal", "pistol", null)) // BOUNTY_TIER_MOST_WANTED, BOUNTY_ARCHETYPE_NORMAL
			var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos[key]
			TEST_ASSERT_NOTNULL(proto, "A roll gave the unknown chrome [key]")
			TEST_ASSERT(proto.can_roll(3, "normal", "pistol", null, list()), "A roll gave [key], which doesn't suit a pistol criminal")
	var/datum/bounty_chrome/test_proto = GLOB.bounty_chrome_protos["unit_test"]
	TEST_ASSERT_NOTNULL(test_proto, "The test piece has no prototype")
	for(var/i in 1 to 20)
		TEST_ASSERT(!("unit_test" in bounty_roll_chrome(3, "normal", "brawler", null)), "A weight 0 piece rolled")

	// Installing, and the hooks
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, run_loc_floor_bottom_left)
	var/datum/component/bounty_chrome/chrome = bounty_chrome_install(criminal, list("unit_test"))
	TEST_ASSERT_NOTNULL(chrome, "Installing chrome gave no component")
	var/datum/bounty_chrome/unit_test/piece = bounty_chrome_piece(criminal, "unit_test")
	TEST_ASSERT_NOTNULL(piece, "The installed piece can't be found")
	TEST_ASSERT_EQUAL(piece.owner, criminal, "The piece isn't in its criminal")
	bounty_chrome_install(criminal, list("unit_test"))
	TEST_ASSERT_EQUAL(length(chrome.pieces), 1, "Installing the same piece twice gave two")
	chrome.fight_started(null)
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.fights, 1, "The piece didn't hear the fight start")
	TEST_ASSERT_EQUAL(piece.ticks, 1, "The piece didn't tick")

	// An EMP knocks it out, and it comes back
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.emps, 1, "An EMP didn't reach the piece")
	TEST_ASSERT(!piece.online(), "The piece works through an EMP")
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.ticks, 1, "A piece down from an EMP still ticks")
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.emps, 1, "A second EMP hit a piece already down")
	piece.offline_until = world.time
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.reboots, 1, "The piece never came back from the EMP")
	TEST_ASSERT(piece.online(), "The piece is still down after its reboot")

	// Examining shows it
	var/list/examined = criminal.examine(criminal)
	var/found = FALSE
	for(var/line in examined)
		if(findtext(line, "test chrome hums"))
			found = TRUE
	TEST_ASSERT(found, "Examining them doesn't show their chrome")

	// The worn look: the implant goes into the look dummy
	var/datum/bounty_look/look = bounty_roll_look(/datum/species/human, MALE)
	var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, null, null, chrome_organs = bounty_chrome_organ_looks(list("unit_test")))
	TEST_ASSERT_NOTNULL(dummy, "The look dummy failed with chrome")
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/cascade) in dummy.organs, "The chrome's implant isn't in the look dummy")
	qdel(dummy)

	// Gone with the component, and no hooks after death
	qdel(chrome)
	TEST_ASSERT_NULL(piece.owner, "A removed piece kept its owner")
