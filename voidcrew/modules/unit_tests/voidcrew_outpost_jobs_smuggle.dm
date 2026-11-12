/**
 * Outpost jobs tests: smuggle (voidcrew/modules/outpost_jobs/). Owner: P4.
 * Helpers are in voidcrew_outpost_jobs_helpers.dm. Fork defines are included after the tests: use literal values
 * with a comment naming the define.
 *
 * Written against the P0 stubs plus P4's own code. Where a test leans on another package (P1's fixer_at(), P2's
 * bind_job() watch and mark_deed()) the test says so.
 */

/// A smuggle run that generates nothing, so a test can make one with no fixer slate behind it
/datum/mission/fixer_job/smuggle/outpost_jobs_test

/datum/mission/fixer_job/smuggle/outpost_jobs_test/generate_mission_details()
	return

// ===== THE CASE IS CONTRABAND ONLY WHILE ITS RUN IS LIVE =====

/datum/unit_test/voidcrew_outpost_jobs_smuggle_contraband

/datum/unit_test/voidcrew_outpost_jobs_smuggle_contraband/Run()
	var/obj/item/mission_recovery/fixer_goods/case/case = allocate(/obj/item/mission_recovery/fixer_goods/case)
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/job = new
	TEST_ASSERT(!fixer_is_contraband(case), "A case no run is bound to was refused")
	TEST_ASSERT(!fixer_is_contraband(allocate(/obj/item/folder)), "An ordinary folder was refused as cargo")
	TEST_ASSERT(!fixer_is_contraband(null), "Nothing was refused as cargo")
	job.bind_item(case)
	TEST_ASSERT(fixer_is_contraband(case), "The case of a live run was not refused")
	job.deed_done = TRUE
	TEST_ASSERT(!fixer_is_contraband(case), "A delivered case is still refused")
	job.deed_done = FALSE
	job.failed = TRUE
	TEST_ASSERT(!fixer_is_contraband(case), "The case of a failed run is still refused")
	job.failed = FALSE
	job.completed = TRUE
	TEST_ASSERT(!fixer_is_contraband(case), "The case of a finished run is still refused")
	job.completed = FALSE
	TEST_ASSERT(fixer_is_contraband(case), "Setup: the case was not refused again with its run live")
	qdel(job)
	TEST_ASSERT(!fixer_is_contraband(case), "The case of a deleted run is still refused")

/// The run's own constants: what it is, what its case is, and the crimes at the gate that count against it
/datum/unit_test/voidcrew_outpost_jobs_smuggle_basics

/datum/unit_test/voidcrew_outpost_jobs_smuggle_basics/Run()
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/job = new
	TEST_ASSERT_EQUAL(job.job_kind, "smuggle", "The run is not the smuggle kind") // FIXER_JOB_SMUGGLE
	TEST_ASSERT_EQUAL(job.goods_type, /obj/item/mission_recovery/fixer_goods/case, "The run carries something other than the case")
	TEST_ASSERT("gate_tamper" in job.scene_crimes, "A tampered gate is not part of the scene") // OUTPOST_CRIME_GATE_TAMPER
	TEST_ASSERT("breach" in job.scene_crimes, "A breached gate is not part of the scene") // OUTPOST_CRIME_CHECKPOINT_BREACH
	var/obj/item/mission_recovery/fixer_goods/case/case = allocate(/obj/item/mission_recovery/fixer_goods/case)
	TEST_ASSERT_EQUAL(case.w_class, WEIGHT_CLASS_NORMAL, "The case is not the size a satchel and a hand take")
	TEST_ASSERT(length(case.desc) && length(case.name), "The case has no name or look")
	qdel(job)

// ===== THE SCANNER =====

/// Real scan chamber: the live case is refused loose on the floor and in a hand, passes inside shielded storage, and is waved through once its run ends
/datum/unit_test/voidcrew_trader_checkpoint/outpost_jobs_smuggle_scan

/datum/unit_test/voidcrew_trader_checkpoint/outpost_jobs_smuggle_scan/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	var/obj/item/mission_recovery/fixer_goods/case/case = allocate(/obj/item/mission_recovery/fixer_goods/case, chamber[2])
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/job = new
	TEST_ASSERT(!length(checkpoint.inspect_chamber()), "Setup: a case with no run was refused")
	job.bind_item(case)
	var/list/refused = checkpoint.inspect_chamber()
	TEST_ASSERT_EQUAL(refused[case], "checkpoint_cargo", "A live case loose on the chamber floor passed the scan") // CHECKPOINT_LINE_CARGO

	person.put_in_hands(case)
	TEST_ASSERT(person.is_holding(case), "Setup: the visitor did not take the case")
	refused = checkpoint.inspect_chamber()
	TEST_ASSERT_EQUAL(refused[person], "checkpoint_cargo", "A live case in a hand passed the scan") // CHECKPOINT_LINE_CARGO

	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, person)
	ADD_TRAIT(bag, TRAIT_CONTRABAND_BLOCKER, TRAIT_GENERIC)
	case.forceMove(bag)
	TEST_ASSERT(!length(checkpoint.inspect_chamber()), "Contraband-shielded storage did not hide the case")

	person.put_in_hands(case)
	TEST_ASSERT_EQUAL(checkpoint.inspect_chamber()[person], "checkpoint_cargo", "Setup: the case was not refused again once out of the bag") // CHECKPOINT_LINE_CARGO
	job.failed = TRUE
	TEST_ASSERT(!length(checkpoint.inspect_chamber()), "The case of a failed run was still refused")
	job.failed = FALSE
	qdel(job)

// ===== THE DELIVERY: ONLY THE DESTINATION FIXER, AND THE DEED IS THE HANDING OVER =====

/datum/unit_test/voidcrew_outpost_jobs_smuggle_delivery

/datum/unit_test/voidcrew_outpost_jobs_smuggle_delivery/Run()
	var/obj/structure/overmap/trader_outpost/far = jobs_outpost(3) // covers room offsets 0-2
	var/mob/living/carbon/human/runner = jobs_person(jobs_spot(1, 1))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill/right = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill, jobs_spot(2, 2))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/nan/wrong = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/nan, jobs_spot(4, 4))
	var/obj/item/mission_recovery/fixer_goods/case/case = allocate(/obj/item/mission_recovery/fixer_goods/case, jobs_spot(0, 1))
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/job = new
	job.pay_outpost = far
	job.active = TRUE // accepted: the shell's deed and hands rules only run on a live job
	job.roster = list(WEAKREF(runner.mind))
	job.bind_item(case)
	job.case_ref = WEAKREF(case)

	TEST_ASSERT(job.is_destination_fixer(right), "The fixer at the destination was not taken for the destination fixer")
	TEST_ASSERT(!job.is_destination_fixer(wrong), "A fixer outside the destination outpost was taken for its fixer")
	TEST_ASSERT(!job.is_destination_fixer(runner), "A passer-by was taken for the destination fixer")
	TEST_ASSERT(job.can_turn_in_at(right), "The destination fixer would not take the turn-in")
	TEST_ASSERT(!job.can_turn_in_at(wrong), "Another outpost's fixer would take the turn-in")

	// The wrong fixer, with the case in hand
	runner.put_in_hands(case)
	TEST_ASSERT_EQUAL(job.can_pay(runner, wrong), "wrong_fixer", "A fixer away from the destination would pay for the case") // FIXER_LINE_WRONG_FIXER
	TEST_ASSERT(!job.deed_done, "Handing the case to the wrong fixer counted as the deed")

	// The right fixer, with no case in hand
	runner.dropItemToGround(case)
	TEST_ASSERT(!isnull(job.can_pay(runner, right)), "The destination fixer would pay with no case in hand")
	TEST_ASSERT(!job.deed_done, "Asking with no case in hand counted as the deed")

	// The right fixer, with the case in hand: the deed is taken, and the case is nobody's cargo any more
	runner.put_in_hands(case)
	TEST_ASSERT_NOTEQUAL(job.can_pay(runner, right), "wrong_fixer", "The destination fixer was refused as the wrong one") // FIXER_LINE_WRONG_FIXER
	TEST_ASSERT(job.deed_done, "Handing the case to the destination fixer was not the deed")
	TEST_ASSERT(!fixer_is_contraband(case), "A delivered case is still refused at the gate")
	qdel(job)

/// A case taken up by someone off the roster ends the run (needs P2's bind_job() watch on goods)
/datum/unit_test/voidcrew_outpost_jobs_smuggle_outsider

/datum/unit_test/voidcrew_outpost_jobs_smuggle_outsider/Run()
	var/mob/living/carbon/human/runner = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/outsider = jobs_person(jobs_spot(1, 0))
	var/obj/item/mission_recovery/fixer_goods/case/case = allocate(/obj/item/mission_recovery/fixer_goods/case, jobs_spot(0, 1))
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/job = new
	job.active = TRUE // accepted: the shell's deed and hands rules only run on a live job
	job.roster = list(WEAKREF(runner.mind))
	job.bind_item(case)
	case.bind_job(job)
	job.case_ref = WEAKREF(case)
	runner.put_in_hands(case)
	TEST_ASSERT(!job.failed && !QDELETED(job), "A crewmate's hands on the case ended the run")
	runner.dropItemToGround(case)
	outsider.put_in_hands(case)
	TEST_ASSERT(job.failed || QDELETED(job), "A stranger took the case and the run went on")
	if(!QDELETED(job))
		qdel(job)

// ===== THE DEADLINE WAITS FOR THE DESTINATION =====

/datum/unit_test/voidcrew_outpost_jobs_smuggle_deadline

/datum/unit_test/voidcrew_outpost_jobs_smuggle_deadline/Run()
	var/obj/structure/overmap/trader_outpost/far = jobs_outpost(3)
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/job = new
	job.pay_outpost = far
	TEST_ASSERT(job.destination_unmanned(), "A destination with no fixer was taken for a manned one")
	TEST_ASSERT(job.hold_deadline(), "The deadline fell while nobody was there to take the case")
	TEST_ASSERT_NOTNULL(job.timeout_timer, "The put-off deadline was not set to come round again")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill/fixer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill, jobs_spot(1, 1))
	if(GLOB.fixer_network.fixer_at(far)) // P1's network knows a fixer there: the destination is manned
		TEST_ASSERT(!job.destination_unmanned(), "A destination with a living fixer was taken for an empty one")
	TEST_ASSERT(fixer, "Setup: the fixer was not made")
	// A run that is over has no deadline to put off
	job.failed = TRUE
	TEST_ASSERT(!job.hold_deadline(), "A failed run put its deadline off")
	job.failed = FALSE
	qdel(job)

// ===== THE SLATE: THE FAR ZONE =====

/// Three outposts on three overmap tiles in the three zones, and crews of three standings
/datum/unit_test/voidcrew_outpost_jobs_smuggle_zones
	var/list/saved_outposts
	/// list(turf now there, type it was) for each tile made an overmap tile
	var/list/restore = list()
	var/old_accepting

/datum/unit_test/voidcrew_outpost_jobs_smuggle_zones/Destroy()
	. = ..()
	SSmetrics.accepting = old_accepting
	for(var/list/pair as anything in restore)
		var/turf/tile = pair[1]
		tile.ChangeTurf(pair[2])
	restore = null
	if(saved_outposts)
		GLOB.trader_outposts = saved_outposts

/// A trader outpost of `outpost_type` on its own overmap tile in zone `zone`
/datum/unit_test/voidcrew_outpost_jobs_smuggle_zones/proc/zone_outpost(outpost_type, dx, dy, zone)
	var/turf/spot = jobs_spot(dx, dy)
	var/original = spot.type
	var/turf/open/overmap/tile = spot.ChangeTurf(/turf/open/overmap)
	restore += list(list(tile, original))
	tile.current_zone = allocate(/datum/overmap_zone, zone)
	return allocate(outpost_type, tile)

/datum/unit_test/voidcrew_outpost_jobs_smuggle_zones/Run()
	old_accepting = SSmetrics.accepting
	SSmetrics.accepting = FALSE // a deleted live run would otherwise write a metric row
	saved_outposts = GLOB.trader_outposts
	GLOB.trader_outposts = list()
	var/obj/structure/overmap/trader_outpost/green = zone_outpost(/obj/structure/overmap/trader_outpost/general, 0, 0, 1) // ZONE_GREEN
	var/obj/structure/overmap/trader_outpost/yellow = zone_outpost(/obj/structure/overmap/trader_outpost/outfitter, 2, 2, 2) // ZONE_YELLOW
	var/obj/structure/overmap/trader_outpost/red = zone_outpost(/obj/structure/overmap/trader_outpost/black_market, 4, 4, 3) // ZONE_RED
	var/datum/voidcrew_crew_record/newcomers = allocate(/datum/voidcrew_crew_record)
	var/datum/voidcrew_crew_record/known = allocate(/datum/voidcrew_crew_record)
	known.reputation = 4 // REPUTATION_STEP_YELLOW
	var/datum/voidcrew_crew_record/trusted = allocate(/datum/voidcrew_crew_record)
	trusted.reputation = 11 // REPUTATION_STEP_ADVANCED
	TEST_ASSERT_EQUAL(length(GLOB.trader_outposts), 3, "Setup: the three outposts are not the whole market")

	// A crew that may work only in the green zone has no far zone to run to from the green outpost
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/run_a = new
	TEST_ASSERT(!run_a.allowed_at(green, newcomers), "A crew limited to the green zone was offered a run to a zone it cannot work in")
	TEST_ASSERT_NULL(run_a.pay_outpost, "A refused ask still fixed the run's end")
	// With no crew in mind the entry stands, but is not tied to any crew's zones
	TEST_ASSERT(run_a.allowed_at(green, null), "A slate entry with no crew asking was refused")
	TEST_ASSERT_NULL(run_a.pay_outpost, "An ask with no crew fixed the run's end")
	// A crew allowed into the yellow zone runs from green to yellow
	TEST_ASSERT(run_a.allowed_at(green, known), "A crew allowed into the yellow zone was not offered a run from the green outpost")
	TEST_ASSERT_EQUAL(run_a.pay_outpost, yellow, "The run did not head for the only far zone the crew may work in")
	// The fixed end stands against a crew that cannot work there, and the run never ends where it began
	TEST_ASSERT(!run_a.allowed_at(green, newcomers), "A run fixed to a yellow outpost was offered to a green-only crew")
	TEST_ASSERT(!run_a.allowed_at(yellow, known), "A run was offered from the outpost it was heading for")

	// From the yellow outpost the green one is open to anyone
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/run_b = new
	TEST_ASSERT(run_b.allowed_at(yellow, newcomers), "A green-only crew was not offered a run from the yellow outpost to the green one")
	TEST_ASSERT_EQUAL(run_b.pay_outpost, green, "A green-only crew's run did not head for the green outpost")

	// A crew allowed into the red zone may run to either of the others
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/run_c = new
	TEST_ASSERT(run_c.allowed_at(green, trusted), "A crew allowed into the red zone was not offered a run")
	TEST_ASSERT(run_c.pay_outpost == yellow || run_c.pay_outpost == red, "The run headed somewhere other than the far outposts")

	// One live run to a pair
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/live = new
	live.job_outpost = green
	live.pay_outpost = yellow
	live.active = TRUE
	SSmissions.all_active_missions += live
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/run_d = new
	TEST_ASSERT(!run_d.allowed_at(green, known), "A second run was offered between the same two outposts")
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/run_e = new
	TEST_ASSERT(!run_e.allowed_at(yellow, newcomers), "A second run was offered between the same two outposts the other way round")
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/run_f = new
	TEST_ASSERT(run_f.allowed_at(green, trusted), "A crew allowed into the red zone was refused the free pair")
	TEST_ASSERT_EQUAL(run_f.pay_outpost, red, "The free pair was not the one chosen")
	qdel(live)
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/run_g = new
	TEST_ASSERT(run_g.allowed_at(green, known), "The pair stayed taken after its run was deleted")
	qdel(run_a)
	qdel(run_b)
	qdel(run_c)
	qdel(run_d)
	qdel(run_e)
	qdel(run_f)
	qdel(run_g)

// ===== STAGING: THE CASE LANDS IN THE CREW'S HANDS =====

/datum/unit_test/voidcrew_outpost_jobs_smuggle_stage

/datum/unit_test/voidcrew_outpost_jobs_smuggle_stage/Run()
	var/obj/structure/overmap/trader_outpost/near = jobs_outpost(3)
	var/obj/structure/overmap/trader_outpost/far = allocate(/obj/structure/overmap/trader_outpost/black_market)
	var/mob/living/carbon/human/runner = jobs_person(jobs_spot(1, 1))
	var/mob/living/carbon/human/stranger = jobs_person(jobs_spot(4, 4))
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/job = new
	job.job_outpost = near
	job.pay_outpost = far

	// No one on the roster to hand it to
	TEST_ASSERT(!job.stage(), "A run with no one to carry the case was staged")
	TEST_ASSERT_NULL(job.case_ref, "A run that could not be staged still made a case")
	job.roster = list(WEAKREF(stranger.mind), WEAKREF(runner.mind))
	// The roster member at the giving outpost gets it, not the one in the far corner of the room
	TEST_ASSERT(job.stage(), "A run with a crew to carry the case was not staged")
	var/obj/item/mission_recovery/fixer_goods/case/case = job.case_ref?.resolve()
	TEST_ASSERT_NOTNULL(case, "Staging made no case")
	TEST_ASSERT(runner.is_holding(case), "The case did not go into the hands of the crewmate at the giving outpost")
	TEST_ASSERT(!stranger.is_holding(case), "The case went to a crewmate who was not at the giving outpost")
	TEST_ASSERT(fixer_is_contraband(case), "The staged case is not refused at the gate")

	// The run ending takes the case with it, wherever it is
	job.unstage()
	TEST_ASSERT(QDELETED(case), "The case outlived its run")
	TEST_ASSERT_NULL(job.case_ref, "The run kept hold of a deleted case")
	qdel(job)

	// A crewmate who is dead is not handed a case
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/second = new
	second.job_outpost = near
	second.pay_outpost = far
	second.roster = list(WEAKREF(runner.mind))
	runner.death()
	TEST_ASSERT(!second.stage(), "A case was handed to a dead crewmate")
	qdel(second)

// ===== WHAT THE OFFER AND THE NOTE SAY =====

/datum/unit_test/voidcrew_outpost_jobs_smuggle_words

/datum/unit_test/voidcrew_outpost_jobs_smuggle_words/Run()
	var/obj/structure/overmap/trader_outpost/black_market/far = allocate(/obj/structure/overmap/trader_outpost/black_market)
	var/datum/mission/fixer_job/smuggle/outpost_jobs_test/job = new
	job.pay_outpost = far
	var/list/tokens = job.offer_tokens()
	var/list/bounds = list("{name}" = 28, "{look}" = 32, "{clock}" = 5, "{place}" = 24, "{to}" = 24) // FIXER_TOKEN_*, FIXER_BOUND_*
	for(var/token in bounds)
		TEST_ASSERT(length_char(tokens[token]) > 0, "The offer has no [token]")
		TEST_ASSERT(length_char(tokens[token]) <= bounds[token], "The offer's [token] is over its bound")
	TEST_ASSERT_EQUAL(tokens["{to}"], "Mister Quill", "The offer does not name the destination's fixer") // FIXER_TOKEN_TO
	TEST_ASSERT_EQUAL(tokens["{place}"], "the Undertow", "The offer does not name the destination") // FIXER_TOKEN_PLACE
	var/list/note = job.note_lines()
	TEST_ASSERT(length(note) in 1 to 3, "The note has [length(note)] lines") // FIXER_NOTE_LINES
	for(var/line in note)
		TEST_ASSERT(length_char(line) <= 64, "A note line is over its bound: [line]") // FIXER_BOUND_NOTE_LINE
	TEST_ASSERT(findtext(note.Join(" "), "Mister Quill") && findtext(note.Join(" "), "the Undertow"), "The note does not say where the case goes")
	// The cutting helper keeps its bound and marks the cut
	TEST_ASSERT_EQUAL(fixer_smuggle_cut("short", 10), "short", "A short text was cut")
	TEST_ASSERT_EQUAL(fixer_smuggle_cut("0123456789ABCDEF", 10), "0123456...", "A long text was not cut to its bound with an ellipsis")
	qdel(job)

/datum/unit_test/voidcrew_outpost_jobs_smuggle_strings
	/// Words the fixers never say (spec 11)
	var/static/list/banned = list("bonus", "clean", "stars", "witness", "noise", "grade", "tier", "trust", "cooldown", "mission")

/datum/unit_test/voidcrew_outpost_jobs_smuggle_strings/Run()
	var/file_name = "job_smuggle.json" // FIXER_STRINGS_SMUGGLE
	load_strings_file(file_name, "voidcrew/modules/outpost_jobs/strings") // FIXER_STRINGS_DIR
	var/list/table = GLOB.string_cache[file_name]
	TEST_ASSERT(length(table), "The smuggle strings did not load")
	var/longest_name = "123456789012345678901234567X" // 28 characters: FIXER_BOUND_NAME
	for(var/speaker in list("nan", "lot", "quill", "stand_in")) // FIXER_VOICE_*
		var/list/section = table[speaker]
		TEST_ASSERT(length(section), "The smuggle strings have nothing for [speaker]")
		for(var/moment in list("look", "stow"))
			var/list/lines = section[moment]
			TEST_ASSERT(length(lines) >= 2, "[speaker] has fewer than two '[moment]' lines")
			for(var/line in lines)
				TEST_ASSERT(istext(line), "[speaker] '[moment]' has a line that is not text")
				var/said = replacetext(line, "{fixer}", longest_name)
				TEST_ASSERT(length_char(said) <= 140, "[speaker] '[moment]' line is over 140 characters: [line]") // FIXER_BOUND_LINE
				TEST_ASSERT(findtext(line, "{fixer}"), "[speaker] '[moment]' line never names the fixer: [line]")
				for(var/word in banned)
					TEST_ASSERT(!findtext(lowertext(line), word), "[speaker] '[moment]' line says '[word]': [line]")
	// A voice with no section of its own falls back to the stand-in
	TEST_ASSERT(length(fixer_smuggle_lines("nobody", "look")), "A speaker with no lines of its own has no fallback")
	TEST_ASSERT(!length(fixer_smuggle_lines("nan", "nothing_here")), "A moment with no lines gave some")
