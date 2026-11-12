/**
 * Outpost jobs tests: assassination (voidcrew/modules/outpost_jobs/). Owner: P6.
 * Helpers are in voidcrew_outpost_jobs_helpers.dm. Fork defines are included after the tests: use literal values
 * with a comment naming the define.
 *
 * Every test makes the mark with make_mark() at a test-room tile, so none waits on staging, a lift or an AI walk.
 */

/// A hit job at a fake outpost, and its mark at the test room's tile `dx`, `dy`. The mark is cleaned up after the job.
/datum/unit_test/proc/jobs_hit_setup(obj/structure/overmap/trader_outpost/outpost, dx = 2, dy = 2)
	var/datum/mission/fixer_job/hit/job = allocate(/datum/mission/fixer_job/hit)
	job.job_outpost = outpost
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = job.make_mark(jobs_spot(dx, dy))
	if(!mark)
		TEST_FAIL("make_mark() made no mark")
		return null
	allocated += mark
	return job

/// The mark's proof, wherever it is in his things, or null
/datum/unit_test/proc/jobs_hit_proof(mob/living/mark)
	for(var/obj/item/mission_recovery/fixer_goods/proof/proof in mark.get_all_contents())
		return proof
	return null

/// He is in his outpost's ambient place, and a player's blow on him reaches register_aggression() as a crime against a townsperson
/datum/unit_test/voidcrew_outpost_jobs_hit_place

/datum/unit_test/voidcrew_outpost_jobs_hit_place/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/mission/fixer_job/hit/job = jobs_hit_setup(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = job?.get_mark()
	TEST_ASSERT_NOTNULL(mark, "The job does not know its mark")
	TEST_ASSERT_EQUAL(mark.place, SSambient_npcs.outpost_place(outpost), "The mark is not in his outpost's ambient place")
	TEST_ASSERT_NULL(mark.role, "The mark came with a role, so his death would empty a slot")
	TEST_ASSERT_EQUAL(mark.real_name, job.mark_name, "The mark is not the man the offer named")
	TEST_ASSERT(istype(mark.w_uniform, /obj/item/clothing/under), "The mark wears no clothes")
	TEST_ASSERT(istype(mark.ears, /obj/item/radio/headset), "The mark has no headset for his calls")

	var/datum/jobs_test_listener/listener = allocate(/datum/jobs_test_listener)
	listener.listen(outpost.police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME
	var/mob/living/carbon/human/attacker = jobs_person(jobs_spot(3, 2))
	mark.on_attacked(mark, attacker, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "A seen blow on the mark was not counted as a crime")
	var/list/crime = listener.last()
	TEST_ASSERT_EQUAL(crime[1], attacker.mind, "The crime was put on the wrong mind")
	TEST_ASSERT_EQUAL(crime[2], "civilian", "A blow on the mark was not assault on a townsperson") // OUTPOST_CRIME_ASSAULT_CIVILIAN
	TEST_ASSERT_EQUAL(crime[3], mark, "The crime's victim is not the mark")
	TEST_ASSERT_EQUAL(mark.death_hand(), attacker, "The mark does not remember the player who hit him")

/// His proof is in his pocket, falls at his feet when he dies, and a second death gives none and no second deed
/datum/unit_test/voidcrew_outpost_jobs_hit_proof

/datum/unit_test/voidcrew_outpost_jobs_hit_proof/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/mission/fixer_job/hit/job = jobs_hit_setup(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = job?.get_mark()
	TEST_ASSERT_NOTNULL(mark, "No mark")
	var/obj/item/mission_recovery/fixer_goods/proof/proof = jobs_hit_proof(mark)
	TEST_ASSERT_NOTNULL(proof, "The mark carries no proof")
	TEST_ASSERT(findtext(proof.name, mark.real_name), "The proof does not carry his name")

	mark.death()
	TEST_ASSERT(isturf(proof.loc), "His proof did not fall when he died")
	TEST_ASSERT_EQUAL(get_turf(proof), get_turf(mark), "His proof did not fall at his feet")
	mark.settle_death()
	TEST_ASSERT(job.deed_done, "His death was not the deed")

	// Brought back and killed again: no second proof, no second deed
	job.deed_done = FALSE
	mark.revive(ADMIN_HEAL_ALL)
	TEST_ASSERT_EQUAL(mark.stat, CONSCIOUS, "Setup: the mark did not come back")
	TEST_ASSERT_NULL(jobs_hit_proof(mark), "A revived mark carries a proof again")
	mark.death()
	mark.settle_death()
	TEST_ASSERT_NULL(jobs_hit_proof(mark), "A second death made a proof")
	var/proofs = 0
	for(var/obj/item/mission_recovery/fixer_goods/proof/found in range(2, mark))
		proofs++
	TEST_ASSERT_EQUAL(proofs, 1, "There is not exactly one proof after two deaths")
	TEST_ASSERT(!job.deed_done, "A second death was sent to the job as the deed")

/// A kill by a player off the crew spoils the job; a death with no player's hand (an officer, a fall) does not
/datum/unit_test/voidcrew_outpost_jobs_hit_hands

/datum/unit_test/voidcrew_outpost_jobs_hit_hands/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()

	// No player's hand: the death is the crew's
	var/datum/mission/fixer_job/hit/clean_job = jobs_hit_setup(outpost, 2, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/first = clean_job?.get_mark()
	TEST_ASSERT_NOTNULL(first, "No first mark")
	// Someone with no mind: an officer's stray round, a guard
	var/mob/living/carbon/human/stray_round = allocate(/mob/living/carbon/human/consistent, jobs_spot(3, 3))
	first.note_hit(stray_round)
	TEST_ASSERT_NULL(first.death_hand(), "A blow from an NPC counted as a player's hand")
	first.death()
	first.settle_death()
	TEST_ASSERT(clean_job.deed_done, "A death with no player's hand was not the deed")
	TEST_ASSERT(!clean_job.failed, "A death with no player's hand spoiled the job")

	// A player off the crew: spoiled
	var/datum/mission/fixer_job/hit/stolen_job = jobs_hit_setup(outpost, 6, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/second = stolen_job?.get_mark()
	TEST_ASSERT_NOTNULL(second, "No second mark")
	var/mob/living/carbon/human/outsider = jobs_person(jobs_spot(7, 2))
	second.note_hit(outsider)
	TEST_ASSERT_EQUAL(second.death_hand(), outsider, "Setup: the outsider's blow was not remembered")
	second.death()
	second.settle_death()
	TEST_ASSERT(stolen_job.failed, "An outsider's kill did not end the job")
	TEST_ASSERT_EQUAL(stolen_job.fail_reason, "spoiled", "An outsider's kill was not a spoiled job") // FIXER_FAIL_SPOILED

	// A blow older than the hand window is nobody's
	var/datum/mission/fixer_job/hit/late_job = jobs_hit_setup(outpost, 10, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/third = late_job?.get_mark()
	TEST_ASSERT_NOTNULL(third, "No third mark")
	third.note_hit(outsider)
	third.last_hit_at = world.time - 31 SECONDS // FIXER_HAND_WINDOW is 30 seconds
	TEST_ASSERT_NULL(third.death_hand(), "A blow from before the hand window still counted")

/// The deadline with him alive: he heads for the lift and the job fails
/datum/unit_test/voidcrew_outpost_jobs_hit_deadline

/datum/unit_test/voidcrew_outpost_jobs_hit_deadline/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/mission/fixer_job/hit/job = jobs_hit_setup(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = job?.get_mark()
	TEST_ASSERT_NOTNULL(mark, "No mark")
	job.on_deadline()
	TEST_ASSERT(job.failed, "The deadline did not fail the job")
	TEST_ASSERT_EQUAL(job.fail_reason, "deadline", "The deadline failed the job for another reason") // FIXER_FAIL_DEADLINE
	TEST_ASSERT(QDELETED(mark) || istype(mark.activity, /datum/ambient_activity/leave), "At the deadline the mark did not head for the lift")
	TEST_ASSERT(QDELETED(mark) || isnull(mark.live_job()), "The mark still works for a failed job")

	// His clock alone sends him off too
	var/datum/mission/fixer_job/hit/late_job = jobs_hit_setup(outpost, 6, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/late = late_job?.get_mark()
	TEST_ASSERT_NOTNULL(late, "No second mark")
	late.end_activity()
	late.leave_at = world.time - 1
	late.pick_activity()
	TEST_ASSERT(istype(late.activity, /datum/ambient_activity/leave), "At his clock the mark did not head for the lift")

/// A drink handed to him is turned down, poisoned or not, and nothing of it gets into him
/datum/unit_test/voidcrew_outpost_jobs_hit_drink

/datum/unit_test/voidcrew_outpost_jobs_hit_drink/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/mission/fixer_job/hit/job = jobs_hit_setup(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/job_mark/mark = job?.get_mark()
	TEST_ASSERT_NOTNULL(mark, "No mark")
	var/mob/living/carbon/human/giver = jobs_person(jobs_spot(3, 2))
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass, jobs_spot(3, 2))
	glass.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, 20)
	glass.reagents.add_reagent(/datum/reagent/toxin, 5)
	giver.put_in_active_hand(glass)
	giver.set_combat_mode(FALSE)
	glass.melee_attack_chain(giver, mark)
	TEST_ASSERT_EQUAL(glass.reagents.total_volume, 25, "The mark drank from a handed glass")
	TEST_ASSERT(!mark.reagents.has_reagent(/datum/reagent/toxin), "Poison from a handed glass got into the mark")
	TEST_ASSERT(giver.is_holding(glass), "The handed glass left the giver's hand")

/// The offer's words and the note's lines keep to their bounds, and every look the fixer can name fits
/datum/unit_test/voidcrew_outpost_jobs_hit_words

/datum/unit_test/voidcrew_outpost_jobs_hit_words/Run()
	for(var/kit_type in subtypesof(/datum/outfit/fixer_mark))
		var/datum/outfit/fixer_mark/kit = kit_type
		TEST_ASSERT(length_char(initial(kit.look_words)) <= 32, "[kit_type]'s look is over the look bound") // FIXER_BOUND_LOOK
	TEST_ASSERT(length(subtypesof(/datum/outfit/fixer_mark)) >= 4, "Fewer than four looks for the mark")

	var/datum/mission/fixer_job/hit/job = allocate(/datum/mission/fixer_job/hit)
	job.mark_name = "Bartholomew Montgomery-Fitzgerald the Third"
	var/list/tokens = job.offer_tokens()
	TEST_ASSERT(length_char(html_decode(tokens["{name}"])) <= 28, "The name token is over its bound") // FIXER_TOKEN_NAME, FIXER_BOUND_NAME
	TEST_ASSERT(length_char(html_decode(tokens["{look}"])) <= 32, "The look token is over its bound") // FIXER_TOKEN_LOOK, FIXER_BOUND_LOOK
	TEST_ASSERT(findtext(tokens["{clock}"], regex(@"^\d\d:\d\d$")), "The clock token is not a station time") // FIXER_TOKEN_CLOCK
	var/list/lines = job.note_lines()
	TEST_ASSERT(length(lines) && length(lines) <= 3, "The note has [length(lines)] lines") // FIXER_NOTE_LINES
	for(var/line in lines)
		TEST_ASSERT(length_char(html_decode(line)) <= 64, "A note line is over its bound: [line]") // FIXER_BOUND_NOTE_LINE

/// His strings: every line within the spoken bound, none naming a rule
/datum/unit_test/voidcrew_outpost_jobs_hit_strings

/datum/unit_test/voidcrew_outpost_jobs_hit_strings/Run()
	var/list/data = json_load("voidcrew/modules/outpost_jobs/strings/job_hit.json") // FIXER_STRINGS_DIR, FIXER_STRINGS_HIT
	var/list/section = data?["mark"]
	TEST_ASSERT(islist(section), "job_hit.json has no mark section")
	for(var/context in list("idle", "talk", "order", "refuse", "call", "attacked", "gun", "safe", "leave"))
		TEST_ASSERT(length(section[context]), "The mark has no [context] lines")
	var/static/list/banned = list("bonus", "clean", "stars", "witness", "noise", "grade", "tier", "trust", "cooldown", "mission")
	for(var/context in section)
		var/list/lines = list()
		if(context == "conversations")
			for(var/list/exchange in section[context])
				lines += exchange["opener"]
				lines += exchange["replies"]
		else
			lines = section[context]
		for(var/line in lines)
			TEST_ASSERT(length_char(line) <= 140, "A mark line is over 140 characters: [line]") // FIXER_BOUND_LINE
			for(var/word in banned)
				TEST_ASSERT(!findtext(line, word), "A mark line says '[word]': [line]")
