/// Ordinary fauna must support funeral rites without making live animals or machines eligible.
/datum/unit_test/vestige_rites_remains/Run()
	var/datum/vestige_trial/last_breath/trial = allocate(/datum/vestige_trial/last_breath)
	var/obj/structure/vestige_rune/rune = allocate(/obj/structure/vestige_rune)
	var/mob/living/basic/carp/body = allocate(/mob/living/basic/carp)
	TEST_ASSERT(!trial.eligible_body(body), "A living animal was accepted as remains")
	body.death()
	TEST_ASSERT(trial.eligible_body(body), "An ordinary dead carp requires a player mind to give a breath")
	TEST_ASSERT(rune.eligible_offering(body), "Offering rejected substantial ordinary fauna")
	TEST_ASSERT(trial.drain(body), "A valid corpse gave no breath")
	TEST_ASSERT(!trial.drain(body), "The same corpse paid twice")
	body.mob_biotypes = MOB_ROBOTIC
	TEST_ASSERT(!trial.eligible_body(body) && !rune.eligible_offering(body), "Mechanical remains bypassed organic eligibility")
	body.mob_biotypes = MOB_ORGANIC
	body.maxHealth = 10
	TEST_ASSERT(!trial.eligible_body(body), "Small vermin passed the substantial-remains gate")

/// The geode needs a dodged, spent manifestation, real range, capacity, and a clear cooling well.
/datum/unit_test/vestige_rites_geode/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_trial/singed_hand/trial = allocate(/datum/vestige_trial/singed_hand, user.mind)
	user.mind.active_vestige_trial = trial
	trial.focus = new(get_turf(user))
	var/turf/distant = get_step(get_step(user, EAST), EAST)
	var/obj/structure/vestige_miscast/miscast = allocate(/obj/structure/vestige_miscast, distant)
	trial.manifestations += miscast
	TEST_ASSERT(!trial.catch_miscast(user, miscast), "The geode caught an unspent threat")
	miscast.spent_until = world.time + 10 SECONDS
	user.forceMove(get_step(distant, WEST))
	TEST_ASSERT(!trial.catch_miscast(user, miscast), "Point-blank catching bypassed positioning")
	user.forceMove(get_turf(trial.focus))
	TEST_ASSERT(trial.catch_miscast(user, miscast), "A spent visible threat at range could not be caught")
	var/obj/structure/vestige_miscast/blocker = allocate(/obj/structure/vestige_miscast, get_step(user, EAST))
	trial.manifestations += blocker
	TEST_ASSERT(!trial.cool(user), "The well cooled while a threat occupied its safety radius")
	blocker.forceMove(get_step(distant, EAST))
	TEST_ASSERT(trial.cool(user), "A clear well refused stored heat")
	TEST_ASSERT_EQUAL(trial.resolved, 1, "Cooling did not preserve successful work")
	trial.stored_heat = 2
	blocker.spent_until = world.time + 10 SECONDS
	TEST_ASSERT(!trial.catch_miscast(user, blocker), "A full geode absorbed another threat")
	trial.clear_lesson()
	TEST_ASSERT(!trial.stored_heat && !trial.resolved && !length(trial.manifestations), "Retry retained heat or stale threats")

/// A sliding inscription must be solvable, sufficiently displaced, and reject non-adjacent moves.
/datum/unit_test/vestige_rites_inscription/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST))
	user.mind_initialize()
	var/datum/vestige_trial/swallowed_word/trial = allocate(/datum/vestige_trial/swallowed_word, user.mind)
	user.mind.active_vestige_trial = trial
	trial.unfold(user)
	TEST_ASSERT_EQUAL(length(trial.syllables), 9, "The complete inscription did not deploy")
	var/obj/structure/vestige_silent_glyph/gap = trial.syllables[9]
	var/distance = 0
	var/list/reading = list()
	for(var/dy = 1; dy >= -1; dy--)
		for(var/dx in -1 to 1)
			var/turf/slot = locate(user.x + dx, user.y + dy, user.z)
			var/obj/structure/vestige_silent_glyph/glyph = locate() in slot
			TEST_ASSERT(glyph, "A sliding inscription slot was empty")
			if(glyph.number != 9)
				reading += glyph.number
			distance += abs(glyph.x - glyph.home.x) + abs(glyph.y - glyph.home.y)
	var/inversions = 0
	for(var/left in 1 to length(reading))
		for(var/right = left + 1; right <= length(reading); right++)
			if(reading[left] > reading[right])
				inversions++
	TEST_ASSERT(!(inversions % 2), "The inscription has an unreachable permutation")
	TEST_ASSERT(distance >= 10, "The inscription began nearly solved")
	for(var/obj/structure/vestige_silent_glyph/glyph as anything in trial.syllables)
		if(abs(glyph.x - gap.x) + abs(glyph.y - gap.y) > 1)
			TEST_ASSERT(!trial.touch_glyph(glyph), "A distant glyph teleported into the gap")
			break
	trial.moves = 4
	trial.on_spoken(user, list())
	TEST_ASSERT_EQUAL(trial.moves, 0, "Speech did not replace the unfinished inscription")

/// Different tools trade lock forces; unlimited crowbar use must jam and a retry must not consume tools.
/datum/unit_test/vestige_rites_toll/Run()
	var/obj/item/vestige_toll_casket/casket = allocate(/obj/item/vestige_toll_casket)
	casket.pressure = 3
	casket.tension = 3
	TEST_ASSERT(casket.work_lock(TOOL_WRENCH), "A wrench failed to vent the casket")
	TEST_ASSERT_EQUAL(casket.tension, 4, "Venting removed its tension tradeoff")
	casket.work_lock(TOOL_SCREWDRIVER)
	casket.work_lock(TOOL_CROWBAR)
	casket.work_lock(TOOL_CROWBAR)
	TEST_ASSERT(!casket.pressure && !casket.tension && casket.strain < 4, "A balanced mixed-tool solution was rejected")
	casket.pressure = 1
	casket.tension = 0
	casket.work_lock(TOOL_WRENCH)
	TEST_ASSERT(!casket.pressure && !casket.tension, "The final payment was forced to be a crowbar")
	casket.pressure = 6
	casket.tension = 6
	casket.strain = 0
	for(var/index in 1 to 4)
		casket.work_lock(TOOL_CROWBAR)
	TEST_ASSERT(!casket.work_lock(TOOL_CROWBAR), "A jammed casket allowed unlimited brute-force solving")
	casket.reset_lock()
	TEST_ASSERT(!casket.strain && isnull(casket.last_tool), "Retry kept the old jam or payment identity")

/// The supplied dressings cannot farm healing outside their patient, and comfort alone cannot discharge wounds.
/datum/unit_test/vestige_rites_patient/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_trial/sitters_rounds/trial = allocate(/datum/vestige_trial/sitters_rounds, user.mind)
	user.mind.active_vestige_trial = trial
	var/mob/living/carbon/human/vestige_patient/patient = allocate(/mob/living/carbon/human/vestige_patient)
	trial.patient = patient
	patient.caregiver = user.mind
	trial.cot = allocate(/obj/structure/bed/vestige_patient_cot)
	trial.cot.buckle_mob(patient, force = TRUE, check_loc = FALSE)
	patient.apply_damage(30, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	patient.comforted = TRUE
	TEST_ASSERT(!trial.ready_for_discharge(), "Comfort discharged an untreated patient")
	var/obj/item/stack/medical/bruise_pack/vestige_sitter/dressing = allocate(/obj/item/stack/medical/bruise_pack/vestige_sitter)
	user.apply_damage(30, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(!dressing.try_heal_checks(user, user, BODY_ZONE_CHEST, silent = TRUE), "Loaned medicine treated its owner")
	TEST_ASSERT(dressing.try_heal_checks(patient, user, BODY_ZONE_CHEST, silent = TRUE), "Loaned medicine refused its intended patient")
	patient.heal_overall_damage(30, 0)
	TEST_ASSERT(trial.ready_for_discharge(), "A treated, warm, resting patient could not be discharged")

/// Reaching the far-side tile by another route must not count as transporting the weight through the breach.
/datum/unit_test/vestige_rites_crossings/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_trial/rite_of_rust/trial = allocate(/datum/vestige_trial/rite_of_rust, user.mind)
	user.mind.active_vestige_trial = trial
	trial.weight = allocate(/obj/item/vestige_threshold_weight)
	trial.weight.keeper = user.mind
	trial.passage = get_step(user, EAST)
	trial.destination = get_step(trial.passage, EAST)
	trial.opened = TRUE
	trial.weight.forceMove(trial.destination)
	TEST_ASSERT(!trial.crossed, "Moving around the wall counted as crossing its breach")
	trial.weight.forceMove(trial.passage)
	trial.weight.forceMove(trial.destination)
	TEST_ASSERT(trial.crossed, "Moving through the breach to the far side was not recorded")
	trial.process(1)
	TEST_ASSERT(!QDELETED(trial), "An unsealed breach completed the extraction")
	var/turf/passage = trial.passage
	var/original_type = passage.type
	passage = passage.ChangeTurf(/turf/closed/wall)
	trial.passage = passage
	var/datum/gas_mixture/air = trial.destination.return_air()
	var/datum/gas_mixture/saved_air = new
	saved_air.copy_from(air)
	var/datum/gas_mixture/removed_air = air.remove_ratio(1)
	qdel(removed_air)
	trial.process(1)
	var/completed = QDELETED(trial)
	air.copy_from(saved_air)
	qdel(saved_air)
	passage.ChangeTurf(original_type)
	TEST_ASSERT(completed, "A crossed and rebuilt breach was stranded by an unrelated pressure requirement")
	var/obj/item/vestige_quill/quill = allocate(/obj/item/vestige_quill)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock)
	door.req_access = list()
	door.req_one_access = list()
	door.locked = FALSE
	door.density = TRUE
	TEST_ASSERT(!quill.has_sentence(door, user), "An ordinary accessible door supplied a refusal")
	door.locked = TRUE
	TEST_ASSERT(quill.has_sentence(door, user), "Bolts were ignored when judging a refusal")
	door.density = FALSE
	TEST_ASSERT(!quill.has_sentence(door, user), "An open door supplied a refusal")

/// Losing a mourning rift attempt preserves its corpse and resets the encounter, rather than paying passive progress.
/datum/unit_test/vestige_rites_vigil/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST))
	user.mind_initialize()
	var/datum/vestige_trial/true_vigil/trial = allocate(/datum/vestige_trial/true_vigil, user.mind)
	user.mind.active_vestige_trial = trial
	var/mob/living/basic/carp/body = allocate(/mob/living/basic/carp, get_turf(user))
	TEST_ASSERT(!trial.start_vigil(body, user), "The candle began a vigil for a live animal")
	body.death()
	TEST_ASSERT(trial.start_vigil(body, user), "A valid solo corpse could not begin a vigil")
	var/turf/original = get_turf(body)
	trial.process(1)
	TEST_ASSERT(get_turf(body) != original, "The mourning rifts did not exert their announced pull")
	var/obj/structure/vestige_mourning_rift/rift = trial.rifts[1]
	body.forceMove(get_turf(rift))
	trial.process(1)
	TEST_ASSERT(!trial.watched && !length(trial.rifts), "A failed attempt kept stale rifts or corpse state")
	TEST_ASSERT(!QDELETED(body), "Failure destroyed the sourced remains")
	body.forceMove(original)
	TEST_ASSERT(trial.start_vigil(body, user), "The same preserved corpse could not retry the vigil")
