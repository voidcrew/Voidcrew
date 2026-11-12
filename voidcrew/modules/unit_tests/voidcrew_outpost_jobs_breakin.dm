/**
 * Outpost jobs tests: break-ins (voidcrew/modules/outpost_jobs/). Owner: P5.
 * Helpers are in voidcrew_outpost_jobs_helpers.dm. Fork defines are included after the tests: use literal values
 * with a comment naming the define.
 *
 * No test waits on an AI walk: the clerk is made in place and his behaviours are called on him.
 */

/// The two numbers on a slip, or null
/datum/unit_test/proc/breakin_slip_numbers(obj/item/paper/fixer_slip/slip)
	var/datum/paper_input/written = LAZYACCESS(slip.raw_text_inputs, 1)
	if(!written)
		return null
	var/regex/parse = regex(@"^L (\d+)\s+R (\d+)$")
	if(!parse.Find(written.raw_text))
		return null
	return list(text2num(parse.group[1]), text2num(parse.group[2]))

/// Presses one of the safe's buttons as `user`, through an open (interactive) window: tgui's ui_act() refuses a null one
/datum/unit_test/proc/breakin_press(obj/structure/safe/fixer/safe, mob/living/carbon/human/user, action, list/params)
	var/datum/tgui/safe_ui = allocate(/datum/tgui, user, safe, "Safe")
	world.push_usr(user, CALLBACK(safe, TYPE_PROC_REF(/datum, ui_act), action, params || list(), safe_ui))

/// Turns the safe's dial as `user` does from the buttons: `left` is the "Left" button (its action is named the other way round)
/datum/unit_test/proc/breakin_turn(obj/structure/safe/fixer/safe, mob/living/carbon/human/user, left, ticks)
	breakin_press(safe, user, left ? "turnright" : "turnleft", list("num" = ticks))

/// The slip's numbers are the safe's tumblers, in the order the dial takes them, and turning the dial as it says opens the safe
/datum/unit_test/voidcrew_outpost_jobs_breakin_slip_opens_safe

/datum/unit_test/voidcrew_outpost_jobs_breakin_slip_opens_safe/Run()
	var/obj/structure/safe/fixer/safe = allocate(/obj/structure/safe/fixer, jobs_spot(1, 1))
	var/obj/item/paper/fixer_slip/slip = allocate(/obj/item/paper/fixer_slip, jobs_spot(2, 2))
	TEST_ASSERT_EQUAL(length(safe.tumblers), 2, "The job's safe does not have two tumblers")
	slip.write_for(safe)
	var/list/numbers = breakin_slip_numbers(slip)
	TEST_ASSERT_NOTNULL(numbers, "The slip does not read as 'L number R number'")
	TEST_ASSERT_EQUAL(numbers[1], safe.tumblers[1], "The slip's first number is not the first tumbler")
	TEST_ASSERT_EQUAL(numbers[2], safe.tumblers[2], "The slip's second number is not the second tumbler")

	// The dial starts at 0. "Left" counts down to the first number, "Right" counts up to the second.
	var/mob/living/carbon/human/user = jobs_person(jobs_spot(0, 1))
	var/left_ticks = (100 - numbers[1]) % 100
	if(!left_ticks)
		left_ticks = 100
	var/right_ticks = (numbers[2] - numbers[1] + 100) % 100
	if(!right_ticks)
		right_ticks = 100
	TEST_ASSERT(safe.locked, "Setup: the safe is not locked")
	breakin_turn(safe, user, TRUE, left_ticks)
	TEST_ASSERT(safe.locked, "One number opened the safe")
	breakin_turn(safe, user, FALSE, right_ticks)
	TEST_ASSERT(!safe.locked, "Turning the dial as the slip says did not unlock the safe")
	breakin_press(safe, user, "open")
	TEST_ASSERT(safe.open, "The unlocked safe would not open")

/// Opening the safe and taking the ledger out are each a locker theft, once per person
/datum/unit_test/voidcrew_outpost_jobs_breakin_theft_once

/datum/unit_test/voidcrew_outpost_jobs_breakin_theft_once/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/jobs_test_listener/listener = allocate(/datum/jobs_test_listener)
	listener.listen(outpost.police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME
	var/obj/structure/safe/fixer/safe = allocate(/obj/structure/safe/fixer, jobs_spot(1, 1))
	var/mob/living/carbon/human/first = jobs_person(jobs_spot(0, 1))
	var/mob/living/carbon/human/second = jobs_person(jobs_spot(0, 2))

	safe.report_theft(first)
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "Opening the safe was not a counted theft")
	var/list/crime = listener.last()
	TEST_ASSERT_EQUAL(crime[1], first.mind, "The theft named the wrong person")
	TEST_ASSERT_EQUAL(crime[2], "locker_theft", "The theft was not a locker theft") // OUTPOST_CRIME_LOCKER_THEFT
	TEST_ASSERT_EQUAL(crime[3], safe, "The theft did not name the safe")

	safe.report_theft(first)
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "The same person was reported twice")
	safe.report_theft(second)
	TEST_ASSERT_EQUAL(length(listener.heard), 2, "A second person was not reported")

	// The dial alone is nothing
	var/mob/living/carbon/human/dialler = jobs_person(jobs_spot(0, 0))
	breakin_turn(safe, dialler, TRUE, 5)
	TEST_ASSERT_EQUAL(length(listener.heard), 2, "Standing at the dial was reported")

/// A job's ledger leaving the safe in a hand is the deed: it is a theft, and the deed is marked
/datum/unit_test/voidcrew_outpost_jobs_breakin_ledger_taken

/datum/unit_test/voidcrew_outpost_jobs_breakin_ledger_taken/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/jobs_test_listener/listener = allocate(/datum/jobs_test_listener)
	listener.listen(outpost.police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME
	var/mob/living/carbon/human/thief = jobs_person(jobs_spot(0, 1))
	var/datum/mission/fixer_job/breakin/job = allocate(/datum/mission/fixer_job/breakin)
	job.job_outpost = outpost
	job.active = TRUE // accepted: the shell's deed and hands rules only run on a live job
	job.roster = list(WEAKREF(thief.mind))
	var/obj/structure/safe/fixer/safe = job.place_safe(jobs_spot(1, 1))
	TEST_ASSERT_NOTNULL(safe, "The job built no safe")
	var/obj/item/ledger = job.watched_ref?.resolve()
	TEST_ASSERT(istype(ledger, /obj/item/mission_recovery/fixer_goods/ledger), "The safe holds no ledger")
	TEST_ASSERT_EQUAL(ledger.loc, safe, "The ledger is not in the safe")
	TEST_ASSERT(!job.deed_done, "The deed was done before anyone touched the ledger")

	TEST_ASSERT(thief.put_in_hands(ledger), "Setup: the thief could not take the ledger")
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "Taking the ledger out was not a counted theft")
	TEST_ASSERT(job.deed_done, "The ledger in a crewmate's hands did not mark the deed")

	job.unstage()
	TEST_ASSERT(QDELETED(safe), "The safe stayed after the job")
	TEST_ASSERT(QDELETED(ledger), "The ledger stayed after the job")

/// Whatever a crew put in the safe is set on the floor before the safe goes
/datum/unit_test/voidcrew_outpost_jobs_breakin_contents_ejected

/datum/unit_test/voidcrew_outpost_jobs_breakin_contents_ejected/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/mission/fixer_job/breakin/job = allocate(/datum/mission/fixer_job/breakin)
	job.job_outpost = outpost
	var/turf/where = jobs_spot(1, 1)
	var/obj/structure/safe/fixer/safe = job.place_safe(where)
	TEST_ASSERT_NOTNULL(safe, "The job built no safe")
	var/obj/item/crowbar = allocate(/obj/item/crowbar)
	crowbar.forceMove(safe)
	var/obj/item/mission_recovery/fixer_goods/ledger/ledger = job.watched_ref?.resolve()
	job.unstage()
	TEST_ASSERT(QDELETED(safe), "The safe stayed after the job")
	TEST_ASSERT(QDELETED(ledger), "The ledger stayed after the job")
	TEST_ASSERT(!QDELETED(crowbar), "What a crew put in the safe went with it")
	TEST_ASSERT_EQUAL(crowbar.loc, where, "What a crew put in the safe was not set on the floor")

/// Lifting the slip from the clerk awake is a locker theft with him as the victim; asleep, out cold or dead it is nothing
/datum/unit_test/voidcrew_outpost_jobs_breakin_slip_lift

/datum/unit_test/voidcrew_outpost_jobs_breakin_slip_lift/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/jobs_test_listener/listener = allocate(/datum/jobs_test_listener)
	listener.listen(outpost.police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME
	var/obj/structure/safe/fixer/safe = allocate(/obj/structure/safe/fixer, jobs_spot(4, 4))
	var/mob/living/carbon/human/thief = jobs_person(jobs_spot(2, 2))

	// Awake
	var/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/awake = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk, jobs_spot(1, 2))
	var/obj/item/paper/fixer_slip/awake_slip = allocate(/obj/item/paper/fixer_slip, jobs_spot(1, 2))
	awake_slip.write_for(safe)
	TEST_ASSERT(awake.carry_slip(awake_slip), "The clerk has no pocket for the slip")
	TEST_ASSERT_EQUAL(awake_slip.loc, awake, "The slip is not on the clerk")
	TEST_ASSERT_EQUAL(awake.stat, CONSCIOUS, "Setup: the clerk is not awake")
	TEST_ASSERT(awake_slip.doStrip(thief, awake), "The slip would not come out of his pocket")
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "Lifting the slip from an awake clerk was not a counted theft")
	var/list/crime = listener.last()
	TEST_ASSERT_EQUAL(crime[1], thief.mind, "The theft named the wrong person")
	TEST_ASSERT_EQUAL(crime[2], "locker_theft", "The theft was not a locker theft") // OUTPOST_CRIME_LOCKER_THEFT
	TEST_ASSERT_EQUAL(crime[3], awake, "The clerk was not the victim")

	// Asleep
	var/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/asleep = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk, jobs_spot(1, 3))
	var/obj/item/paper/fixer_slip/asleep_slip = allocate(/obj/item/paper/fixer_slip, jobs_spot(1, 3))
	asleep_slip.write_for(safe)
	TEST_ASSERT(asleep.carry_slip(asleep_slip), "The sleeping clerk has no pocket for the slip")
	asleep.Sleeping(1 MINUTES)
	asleep.update_stat()
	TEST_ASSERT(asleep.stat != CONSCIOUS, "Setup: the clerk is not asleep")
	TEST_ASSERT(asleep_slip.doStrip(thief, asleep), "The slip would not come out of the sleeper's pocket")
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "Lifting the slip from a sleeping clerk was reported")

	// Dead: the slip falls where he lies, like any paper
	var/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/dead = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk, jobs_spot(2, 3))
	var/obj/item/paper/fixer_slip/dead_slip = allocate(/obj/item/paper/fixer_slip, jobs_spot(2, 3))
	dead_slip.write_for(safe)
	TEST_ASSERT(dead.carry_slip(dead_slip), "The clerk has no pocket for the slip")
	dead.death()
	TEST_ASSERT_EQUAL(dead.stat, DEAD, "Setup: the clerk did not die")
	TEST_ASSERT_EQUAL(dead_slip.loc, get_turf(dead), "The dead clerk kept the slip")
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "A dead clerk's slip was reported")

	// Leaving alive, he takes it with him
	var/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/leaving = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk, jobs_spot(3, 3))
	var/obj/item/paper/fixer_slip/leaving_slip = allocate(/obj/item/paper/fixer_slip, jobs_spot(3, 3))
	leaving_slip.write_for(safe)
	TEST_ASSERT(leaving.carry_slip(leaving_slip), "The clerk has no pocket for the slip")
	leaving.npc_drop_not_gear()
	TEST_ASSERT(QDELETED(leaving_slip), "A clerk walking out left the combination on the floor")

/// He goes to the safe first, once, and then drinks like any drinker
/datum/unit_test/voidcrew_outpost_jobs_breakin_clerk_routine

/datum/unit_test/voidcrew_outpost_jobs_breakin_clerk_routine/Run()
	var/obj/structure/safe/fixer/safe = allocate(/obj/structure/safe/fixer, jobs_spot(1, 1))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk/clerk = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/drinker/job_clerk, jobs_spot(3, 3))
	// With no safe to mind he is any drinker
	clerk.pick_activity()
	TEST_ASSERT(!istype(clerk.activity, /datum/ambient_activity/clerk_check), "A clerk with no safe went to check one")
	clerk.end_activity()
	TEST_ASSERT(!clerk.checked, "A clerk who never saw a safe says he has checked it")
	clerk.safe_ref = WEAKREF(safe)
	var/datum/ambient_activity/check = clerk.pick_activity()
	TEST_ASSERT(istype(check, /datum/ambient_activity/clerk_check), "A clerk with a safe did not start with it")
	TEST_ASSERT(clerk.checked, "The clerk did not remember he had checked")
	// At the safe he holds a book; putting it away leaves his hands empty
	clerk.forceMove(check.spot)
	check.arrived = TRUE
	check.arrive()
	TEST_ASSERT_NOTNULL(clerk.held_prop, "The clerk holds no book at the safe")
	TEST_ASSERT(istype(clerk.held_prop, /obj/item/clipboard), "The clerk's book is not a clipboard")
	clerk.end_activity()
	TEST_ASSERT_NULL(clerk.held_prop, "The clerk kept his book after the check")
	// Only once
	clerk.pick_activity()
	TEST_ASSERT(!istype(clerk.activity, /datum/ambient_activity/clerk_check), "The clerk went back to the safe")

/// The evidence job: no locker, no job; with one, a sealed bag goes in, the locker reports whoever takes it (the lock broken or not), and the deed is marked
/datum/unit_test/voidcrew_outpost_jobs_breakin_evidence

/datum/unit_test/voidcrew_outpost_jobs_breakin_evidence/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/mission/fixer_job/breakin/evidence/job = allocate(/datum/mission/fixer_job/breakin/evidence)
	job.job_outpost = outpost
	job.active = TRUE // accepted: the shell's deed and hands rules only run on a live job

	// No locker: not offered, and staging fails
	police.evidence_locker = null
	police.evidence_locker_search_at = world.time + 1 HOURS
	TEST_ASSERT(!job.allowed_at(outpost, null), "The evidence job was offered at an outpost with no evidence locker")
	TEST_ASSERT(!job.stage(), "The evidence job staged with no evidence locker")
	TEST_ASSERT_NULL(job.watched_ref, "The evidence job watched a bag it never made")

	// A locker: the bag goes in
	var/obj/structure/closet/secure_closet/outpost_evidence/locker = allocate(/obj/structure/closet/secure_closet/outpost_evidence, jobs_spot(1, 1))
	police.evidence_locker = locker
	TEST_ASSERT(job.allowed_at(outpost, null), "The evidence job was not offered at an outpost with an evidence locker")
	TEST_ASSERT(job.stage(), "The evidence job would not stage with an evidence locker")
	var/obj/item/mission_recovery/fixer_goods/evidence/bag = job.watched_ref?.resolve()
	TEST_ASSERT_NOTNULL(bag, "The evidence job made no bag")
	TEST_ASSERT_EQUAL(bag.loc, locker, "The bag is not in the evidence locker")

	// The lock is broken; someone's hand takes it out all the same
	locker.broken = TRUE
	locker.locked = FALSE
	var/datum/jobs_test_listener/listener = allocate(/datum/jobs_test_listener)
	listener.listen(police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME
	var/mob/living/carbon/human/thief = jobs_person(jobs_spot(0, 1))
	job.roster = list(WEAKREF(thief.mind))
	TEST_ASSERT(thief.put_in_hands(bag), "Setup: the thief could not take the bag")
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "Taking the bag out of a broken locker was not reported")
	var/list/crime = listener.last()
	TEST_ASSERT_EQUAL(crime[1], thief.mind, "The bag theft named the wrong person")
	TEST_ASSERT_EQUAL(crime[2], "locker_theft", "The bag theft was not a locker theft") // OUTPOST_CRIME_LOCKER_THEFT
	TEST_ASSERT(job.deed_done, "The bag in a crewmate's hands did not mark the deed")

	job.unstage()
	TEST_ASSERT(QDELETED(bag), "The bag stayed after the job")

/// What the fixer is told fits its bounds, and what is said is escaped
/datum/unit_test/voidcrew_outpost_jobs_breakin_offer_text

/datum/unit_test/voidcrew_outpost_jobs_breakin_offer_text/Run()
	for(var/job_type in list(/datum/mission/fixer_job/breakin, /datum/mission/fixer_job/breakin/evidence))
		for(var/name in list("Bartholomew Thistlethwaite-Fernsby of the Long Names", "O'Neil <b>x</b> &"))
			var/datum/mission/fixer_job/breakin/job = allocate(job_type)
			if(istype(job, /datum/mission/fixer_job/breakin/evidence))
				var/datum/mission/fixer_job/breakin/evidence/evidence_job = job
				evidence_job.case_number = 4471
			job.clerk_name = name
			var/list/tokens = job.offer_tokens()
			// FIXER_TOKEN_NAME, _LOOK, _CLOCK and _PLACE, cut to FIXER_BOUND_NAME 28, _LOOK 32, _PLACE 24
			var/list/bounds = list("{name}" = 28, "{look}" = 32, "{clock}" = 5, "{place}" = 24)
			for(var/token in bounds)
				var/value = tokens[token]
				TEST_ASSERT(istext(value) && length(value), "[job_type]: no [token] in the offer")
				TEST_ASSERT(length_char(html_decode(value)) <= bounds[token], "[job_type]: [token] is over [bounds[token]] characters")
				TEST_ASSERT(!findtext(value, "<") && !findtext(value, ">"), "[job_type]: [token] is not escaped")
			var/list/lines = job.note_lines()
			TEST_ASSERT(length(lines) && length(lines) <= 3, "[job_type]: the note has [length(lines)] lines") // FIXER_NOTE_LINES
			for(var/line in lines)
				TEST_ASSERT(length_char(html_decode(line)) <= 64, "[job_type]: a note line is over 64 characters") // FIXER_BOUND_NOTE_LINE
				TEST_ASSERT(!findtext(line, "<") && !findtext(line, ">"), "[job_type]: a note line is not escaped")

/// The clerk's lines are all there, within the bound, and say nothing about how the game works
/datum/unit_test/voidcrew_outpost_jobs_breakin_strings

/datum/unit_test/voidcrew_outpost_jobs_breakin_strings/Run()
	load_strings_file("job_breakin.json", "voidcrew/modules/outpost_jobs/strings") // FIXER_STRINGS_BREAKIN, FIXER_STRINGS_DIR
	var/list/cache = GLOB.string_cache["job_breakin.json"]
	TEST_ASSERT(islist(cache), "job_breakin.json did not load")
	var/list/clerk = cache["clerk"]
	TEST_ASSERT(islist(clerk), "job_breakin.json has no clerk section")
	// The words a player is never told (spec 11)
	var/list/banned = list("bonus", "clean", "stars", "witness", "noise", "grade", "tier", "trust", "cooldown", "mission", "fixer")
	for(var/moment in list("check", "write", "slip_taken", "empty"))
		var/list/lines = clerk[moment]
		TEST_ASSERT(islist(lines) && length(lines) >= 2, "The clerk has fewer than two lines for '[moment]'")
		for(var/line in lines)
			TEST_ASSERT(istext(line), "The clerk has a line for '[moment]' that is not text")
			TEST_ASSERT(length_char(line) <= 140, "The clerk's line '[line]' is over 140 characters") // FIXER_BOUND_LINE
			for(var/word in banned)
				TEST_ASSERT(!findtext(lowertext(line), word), "The clerk's line '[line]' says '[word]'")
