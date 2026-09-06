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

/// Reviving a defeated clot must not let one participant satisfy all three deaths.
/datum/unit_test/vestige_rites_blood_vigil/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST))
	user.mind_initialize()
	var/datum/vestige_trial/vigil/trial = allocate(/datum/vestige_trial/vigil, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	trial.unfold(user)
	TEST_ASSERT_EQUAL(length(trial.clots), 3, "The blood votive did not create its three participants")
	var/mob/living/basic/carp/vestige_clot/first = trial.clots[1]
	first.death()
	TEST_ASSERT_EQUAL(trial.slain, 1, "The first clot's death did not progress the vigil")
	first.revive(ADMIN_HEAL_ALL)
	first.death()
	TEST_ASSERT_EQUAL(trial.slain, 1, "A revived clot paid for a second participant")
	TEST_ASSERT(!trial.fulfilled, "One revived clot completed the three-clot vigil")

/// A scripted attacker which becomes a person's body cannot be reclaimed as disposable encounter state.
/datum/unit_test/vestige_rites_occupied_clot/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/vigil/trial = allocate(/datum/vestige_trial/vigil, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	trial.unfold(user)
	TEST_ASSERT_EQUAL(length(trial.clots), 3, "The fixture must create the actual three-clot encounter.")
	var/mob/living/basic/carp/vestige_clot/occupied = trial.clots[1]
	var/mob/living/basic/carp/vestige_clot/unoccupied = trial.clots[2]
	TEST_ASSERT(!occupied.compare_sentience_type(SENTIENCE_ORGANIC), "Ordinary sentience and transfer potions must not recruit the scripted attackers.")
	var/mob/living/carbon/human/consistent/donor = allocate(/mob/living/carbon/human/consistent, center)
	donor.mind_initialize()
	var/datum/mind/occupant = donor.mind
	occupant.transfer_to(occupied)
	occupied.death()
	TEST_ASSERT_EQUAL(trial.slain, 0, "The death of an occupied participant must not pay the blood rite.")
	TEST_ASSERT(!trial.running, "An occupied participant must invalidate the current encounter.")
	trial.reset_rite()
	TEST_ASSERT(!QDELETED(occupied), "Packing a rite must preserve an occupied clot, including its recoverable corpse.")
	TEST_ASSERT_EQUAL(occupant.current, occupied, "Packing must not delete or evict the transferred mind.")
	TEST_ASSERT(QDELETED(unoccupied), "Packing must still reclaim the ordinary unoccupied attackers.")
	qdel(trial)
	TEST_ASSERT(!QDELETED(occupied), "Later trial destruction must not recapture the released occupied participant.")
	qdel(occupied)

/datum/unit_test/vestige_rites_occupied_guardian/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/rite_of_rust/trial = allocate(/datum/vestige_trial/rite_of_rust, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	trial.starting_side = trial.mark_turf(center)
	trial.release_guardian()
	var/mob/living/basic/hivebot/vestige_threshold_guardian/guardian = trial.guardian
	TEST_ASSERT(!guardian.compare_sentience_type(SENTIENCE_ORGANIC), "The temporary guardian must reject organic sentience potions despite its inherited basic-mob setting.")
	var/mob/living/carbon/human/consistent/donor = allocate(/mob/living/carbon/human/consistent, center)
	donor.mind_initialize()
	var/datum/mind/occupant = donor.mind
	occupant.transfer_to(guardian)
	qdel(trial)
	TEST_ASSERT(!QDELETED(guardian), "The guardian must pass through shared occupied-loan preservation on trial destruction.")
	TEST_ASSERT_EQUAL(occupant.current, guardian, "Guardian cleanup must preserve the actual transferred occupant.")
	qdel(guardian)

/datum/unit_test/vestige_rites_concurrent_chalk
	var/turf/site
	var/obj/structure/vestige_rune/competing_rune

/datum/unit_test/vestige_rites_concurrent_chalk/proc/on_scribing_began(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_DO_AFTER_BEGAN)
	// A second scribe finishes while the first still watches the same floor tile.
	competing_rune = allocate(/obj/structure/vestige_rune, site)

/datum/unit_test/vestige_rites_concurrent_chalk/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/offering/trial = allocate(/datum/vestige_trial/offering, user.mind)
	user.mind.active_vestige_trial = trial
	var/obj/item/vestige_chalk/chalk = allocate(/obj/item/vestige_chalk, center)
	user.put_in_hands(chalk)
	site = get_step(center, EAST)
	RegisterSignal(user, COMSIG_DO_AFTER_BEGAN, PROC_REF(on_scribing_began))
	var/result = site.base_item_interaction(user, chalk, list())
	TEST_ASSERT(competing_rune, "The real chalk interaction must reach its actual scribing channel.")
	TEST_ASSERT(result & ITEM_INTERACT_BLOCKING, "A rune created during the channel must prevent a second overlapping rune.")
	TEST_ASSERT(!trial.rune_scribed, "Losing the scribing race must not claim another player's completed rune.")
	var/rune_count = 0
	for(var/obj/structure/vestige_rune/rune in site)
		rune_count++
	TEST_ASSERT_EQUAL(rune_count, 1, "The final site must contain only the rune which won the actual channel race.")

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

/// External deletion must clear the inscription before speech or tracker callbacks use it.
/datum/unit_test/vestige_rites_inscription_deletion/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/swallowed_word/trial = allocate(/datum/vestige_trial/swallowed_word, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	var/obj/item/vestige_syllable/phial = locate() in user.held_items
	TEST_ASSERT(phial, "The inscription did not issue its deployment tool")
	phial.attack_self(user)
	TEST_ASSERT_EQUAL(length(trial.syllables), 9, "The inscription did not deploy through its tool")
	var/list/old_parts = trial.syllables.Copy()
	for(var/obj/structure/vestige_silent_glyph/glyph as anything in trial.syllables)
		old_parts += glyph.home
	trial.moves = 7
	qdel(trial.syllables[1])
	TEST_ASSERT(!length(trial.syllables) && !trial.moves, "External glyph deletion retained an incomplete board")
	for(var/atom/movable/part as anything in old_parts)
		TEST_ASSERT(QDELETED(part), "Deleting a glyph left another glyph or its goal behind")
	SEND_SIGNAL(user, COMSIG_MOB_SAY, list())
	TEST_ASSERT(findtext(trial.get_progress_text(), "Use the phial"), "The tracker did not offer recovery after a glyph vanished")
	phial.attack_self(user)
	TEST_ASSERT_EQUAL(length(trial.syllables), 9, "A lost glyph prevented redeployment")
	var/obj/structure/vestige_silent_glyph/first = trial.syllables[1]
	qdel(first.home)
	TEST_ASSERT(!length(trial.syllables), "External goal deletion retained a board with a missing goal")
	SEND_SIGNAL(user, COMSIG_MOB_SAY, list())
	phial.attack_self(user)
	TEST_ASSERT_EQUAL(length(trial.syllables), 9, "A lost goal prevented redeployment")
	TEST_ASSERT(!trial.fulfilled, "Deleting and redeploying an inscription paid its reward")
	phial.attack_self(user)
	TEST_ASSERT(!length(trial.syllables), "Normal packing recursively retained an inscription")

/// Ship movement and rotation must carry the puzzle's goal, not only its visible pieces.
/datum/unit_test/vestige_rites_shipboard_inscription/Run()
	var/turf/origin = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, origin)
	user.mind_initialize()
	var/datum/vestige_trial/swallowed_word/trial = allocate(/datum/vestige_trial/swallowed_word, user.mind)
	user.mind.active_vestige_trial = trial
	trial.unfold(user)
	TEST_ASSERT_EQUAL(length(trial.syllables), 9, "The inscription did not deploy")
	var/turf/destination = locate(origin.x + 4, origin.y + 4, origin.z)
	var/list/moved = trial.syllables.Copy()
	for(var/obj/structure/vestige_silent_glyph/glyph as anything in trial.syllables)
		moved += glyph.home
	var/list/old_turfs = list()
	var/list/new_turfs = list()
	for(var/atom/movable/part as anything in moved)
		old_turfs[part] = get_turf(part)
		// A half-turn around the new center, as a shuttle docking rotation applies.
		new_turfs[part] = locate(destination.x - (part.x - origin.x), destination.y - (part.y - origin.y), destination.z)
	for(var/atom/movable/part as anything in moved)
		part.beforeShuttleMove(new_turfs[part], 180, MOVE_CONTENTS)
		part.onShuttleMove(new_turfs[part], old_turfs[part], list(), NORTH)
		part.afterShuttleMove(old_turfs[part], list(), SOUTH, NORTH, NORTH, 180)
	var/obj/structure/vestige_silent_glyph/first = trial.syllables[1]
	var/obj/structure/vestige_silent_glyph/second = trial.syllables[2]
	var/obj/structure/vestige_silent_glyph/next_row = trial.syllables[4]
	TEST_ASSERT_EQUAL(get_dir(first.home, second.home), WEST, "The board's reading axis did not rotate with its ship")
	TEST_ASSERT_EQUAL(get_dir(first.home, next_row.home), NORTH, "The board's row axis did not rotate with its ship")
	TEST_ASSERT(findtext(trial.get_progress_text(), "west") && findtext(trial.get_progress_text(), "north"), "The tracker kept the old reading directions after a rotation")
	trial.on_spoken(user, list())
	for(var/obj/structure/vestige_silent_glyph/glyph as anything in trial.syllables)
		TEST_ASSERT(get_dist(glyph, destination) <= 1, "Speech sent a syllable back to the departed berth")
		TEST_ASSERT(get_dist(glyph.home, destination) <= 1, "A goal stayed at the departed berth")
		glyph.forceMove(get_turf(glyph.home))
	var/obj/structure/vestige_silent_glyph/eighth = trial.syllables[8]
	TEST_ASSERT(trial.slide(eighth), "The rotated board's last legal move was rejected")
	TEST_ASSERT(trial.touch_glyph(eighth), "The rotated board could not be solved")
	TEST_ASSERT(QDELETED(trial), "Solving the moved board did not complete its trial")
	for(var/atom/movable/part as anything in moved)
		TEST_ASSERT(QDELETED(part), "Completing the board left a piece or invisible goal behind")

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
	var/obj/item/stack/medical/bruise_pack/ordinary_dressing = allocate(/obj/item/stack/medical/bruise_pack)
	TEST_ASSERT(!dressing.can_merge(ordinary_dressing, inhand = TRUE), "Loan dressings could be converted into unrestricted medicine by merging")
	TEST_ASSERT(!ordinary_dressing.can_merge(dressing, inhand = TRUE), "Ordinary medicine could be absorbed into a loan stack")
	TEST_ASSERT(!length(dressing.grind_results), "Patient-only dressings could be ground into unrestricted medicine")
	var/obj/item/stack/medical/ointment/vestige_sitter/ointment = allocate(/obj/item/stack/medical/ointment/vestige_sitter, get_turf(user), 10)
	var/obj/item/stack/medical/ointment/ordinary_ointment = allocate(/obj/item/stack/medical/ointment)
	TEST_ASSERT_EQUAL(ointment.get_amount(), 10, "Issuing ten dressings created an untracked overflow stack")
	TEST_ASSERT(!ointment.can_merge(ordinary_ointment, inhand = TRUE) && !ordinary_ointment.can_merge(ointment, inhand = TRUE), "Patient-only burn dressings merged with ordinary ointment")
	TEST_ASSERT(!length(ointment.grind_results), "Patient-only burn dressings could be ground into unrestricted medicine")

/// The guardian must actually threaten the weight through the normal basic-mob attack path.
/datum/unit_test/vestige_rites_guardian/Run()
	var/obj/item/vestige_threshold_weight/weight = allocate(/obj/item/vestige_threshold_weight)
	var/mob/living/basic/hivebot/vestige_threshold_guardian/guardian = allocate(/mob/living/basic/hivebot/vestige_threshold_guardian, get_step(weight, NORTH))
	var/before = weight.get_integrity()
	TEST_ASSERT(guardian.melee_attack(weight, ignore_cooldown = TRUE), "The guardian could not attack its threshold weight")
	TEST_ASSERT_EQUAL(weight.get_integrity(), before - guardian.obj_damage, "The threshold weight ignored the guardian's ordinary attacks")

/// Reaching the far-side tile by another route must not count as transporting the weight through the breach.
/datum/unit_test/vestige_rites_crossings/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_trial/rite_of_rust/trial = allocate(/datum/vestige_trial/rite_of_rust, user.mind)
	user.mind.active_vestige_trial = trial
	trial.weight = allocate(/obj/item/vestige_threshold_weight)
	trial.weight.keeper = user.mind
	trial.passage = trial.mark_turf(get_step(user, EAST))
	trial.destination = trial.mark_turf(get_step(trial.passage, EAST))
	trial.opened = TRUE
	trial.weight.forceMove(get_turf(trial.destination))
	TEST_ASSERT(!trial.crossed, "Moving around the wall counted as crossing its breach")
	trial.weight.forceMove(get_turf(trial.passage))
	trial.weight.forceMove(get_turf(trial.destination))
	TEST_ASSERT(trial.crossed, "Moving through the breach to the far side was not recorded")
	trial.process(1)
	TEST_ASSERT(!QDELETED(trial), "An unsealed breach completed the extraction")
	var/turf/passage = get_turf(trial.passage)
	var/original_type = passage.type
	passage = passage.ChangeTurf(/turf/closed/wall)
	var/turf/destination = get_turf(trial.destination)
	var/datum/gas_mixture/air = destination.return_air()
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

/// A destroyed cot cannot satisfy the discharge gate through null == null.
/datum/unit_test/vestige_rites_destroyed_cot/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_trial/sitters_rounds/trial = allocate(/datum/vestige_trial/sitters_rounds, user.mind)
	user.mind.active_vestige_trial = trial
	trial.patient = allocate(/mob/living/carbon/human/vestige_patient, get_turf(user))
	trial.patient.caregiver = user.mind
	trial.patient.comforted = TRUE
	trial.cot = allocate(/obj/structure/bed/vestige_patient_cot, get_turf(user))
	trial.cot.buckle_mob(trial.patient, force = TRUE)
	TEST_ASSERT(trial.ready_for_discharge(), "A healthy, comforted patient on the original cot must be eligible.")
	QDEL_NULL(trial.cot)
	TEST_ASSERT_NULL(trial.patient.buckled, "Destroying the actual cot must release its patient.")
	TEST_ASSERT(!trial.ready_for_discharge(), "A missing cot must not satisfy the resting requirement through two null references.")
	TEST_ASSERT(findtext(trial.get_progress_text(), "Resting: no"), "The tracker must not claim an unbuckled patient is resting on a destroyed cot.")
	var/obj/item/vestige_cloth/cloth = allocate(/obj/item/vestige_cloth, get_turf(user))
	user.put_in_hands(cloth)
	cloth.interact_with_atom(trial.patient, user, list())
	TEST_ASSERT(!QDELETED(trial) && !trial.fulfilled, "The cloth must not discharge a patient after the cot is lost.")

/// Flares target their moving visible warning, never an abandoned berth or expired tell.
/datum/unit_test/vestige_rites_miscast_warning/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/singed_hand/trial = allocate(/datum/vestige_trial/singed_hand, user.mind)
	user.mind.active_vestige_trial = trial
	trial.focus = new(center)
	var/obj/structure/vestige_miscast/miscast = allocate(/obj/structure/vestige_miscast, get_step(get_step(center, EAST), EAST))
	miscast.student = user.mind
	trial.manifestations += miscast
	miscast.process(2)
	TEST_ASSERT(!QDELETED(miscast.warning), "A nearby active miscast must mark the student's current tile.")
	for(var/atom/movable/moving in list(user, trial.focus, miscast, miscast.warning))
		var/turf/previous = get_turf(moving)
		moving.onShuttleMove(get_step(previous, NORTH), previous, list(), NORTH, null, null)
	miscast.strike_at = world.time
	miscast.process(2)
	TEST_ASSERT_EQUAL(user.getStaminaLoss(), 18, "Standing in the warning on a moved ship must still take the announced flare.")
	miscast.spent_until = 0
	miscast.process(2)
	TEST_ASSERT(!QDELETED(miscast.warning), "The next exchange must create another visible warning.")
	QDEL_NULL(miscast.warning)
	miscast.strike_at = world.time
	miscast.process(2)
	TEST_ASSERT_EQUAL(user.getStaminaLoss(), 18, "A warning that expired while processing was paused must not deliver an invisible delayed hit.")

/// A vanished well or manifestation must allow a fresh, complete lesson.
/datum/unit_test/vestige_rites_lesson_deletion/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	for(var/trial_type in list(/datum/vestige_trial/singed_hand, /datum/vestige_trial/steady_tongue))
		var/datum/vestige_trial/wizard_lesson/trial = allocate(trial_type, user.mind)
		user.mind.active_vestige_trial = trial
		TEST_ASSERT(trial.set_up(user), "[trial_type] must deploy the complete lesson.")
		var/list/old_parts = trial.manifestations.Copy()
		old_parts += trial.focus
		qdel(trial.focus)
		TEST_ASSERT_NULL(trial.focus, "[trial_type] must release a deleted focus.")
		TEST_ASSERT_EQUAL(length(trial.manifestations), 0, "[trial_type] must remove the manifestations belonging to a lost focus.")
		for(var/atom/part as anything in old_parts)
			TEST_ASSERT(QDELETED(part), "[trial_type] left part of its old lesson active after its well was deleted.")
		TEST_ASSERT(trial.set_up(user), "[trial_type] must accept a fresh deployment immediately after losing the well.")
		qdel(trial.manifestations[1])
		TEST_ASSERT(!trial.focus && !length(trial.manifestations), "[trial_type] must also reset after losing a manifestation.")
		TEST_ASSERT(!trial.resolved && !trial.fulfilled, "Losing the lesson must never grant progress.")
		qdel(trial)

/// Expected rift closure preserves the attempt; an externally lost part cancels it.
/datum/unit_test/vestige_rites_rift_deletion/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/true_vigil/trial = allocate(/datum/vestige_trial/true_vigil, user.mind)
	user.mind.active_vestige_trial = trial
	var/mob/living/basic/carp/body = allocate(/mob/living/basic/carp, center)
	body.death()
	TEST_ASSERT(trial.start_vigil(body, user), "The vigil must deploy its three rifts.")
	var/obj/structure/vestige_mourning_rift/closed = trial.rifts[1]
	trial.rifts -= closed
	qdel(closed)
	TEST_ASSERT_EQUAL(trial.watched, body, "Removing a successfully closed rift from the tracked list before deletion must preserve the vigil.")
	TEST_ASSERT_EQUAL(length(trial.rifts), 2, "Expected closure must leave the other rifts active.")
	qdel(trial.rifts[1])
	TEST_ASSERT(!trial.watched && !length(trial.rifts), "External rift deletion must cancel the incomplete vigil.")
	TEST_ASSERT(!QDELETED(body), "Losing a rift must preserve the sourced remains.")
	TEST_ASSERT(trial.start_vigil(body, user), "The same remains must support a fresh attempt after a rift is lost.")
	qdel(body)
	TEST_ASSERT(!trial.watched && !length(trial.rifts), "Deleting the watched body must immediately reclaim its rifts.")

/// Every affected boon must remove only its own rematerialization restraint.
/datum/unit_test/vestige_rites_jaunt_removal/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	for(var/spell_type in list(/datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash/vestige, /datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash/long/vestige, /datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk))
		var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, center)
		user.mind_initialize()
		var/datum/action/cooldown/spell/jaunt/ethereal_jaunt/spell = allocate(spell_type, user.mind)
		spell.Grant(user)
		spell.jaunt_duration = 1 MINUTES
		spell.do_jaunt(user)
		var/obj/effect/dummy/phased_mob/spell_jaunt/holder = user.loc
		TEST_ASSERT(istype(holder), "[spell_type] must enter its actual phased holder.")
		spell.stop_jaunt(user, holder, center)
		TEST_ASSERT(HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, REF(spell)), "[spell_type] must begin its real rematerialization restraint.")
		ADD_TRAIT(user, TRAIT_IMMOBILIZED, "independent restraint")
		spell.Remove(user)
		TEST_ASSERT(isturf(user.loc) && QDELETED(holder), "Removing [spell_type] must eject its original caster.")
		TEST_ASSERT(!HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, REF(spell)), "Removing [spell_type] during rematerialization must release its own restraint.")
		TEST_ASSERT(HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, "independent restraint"), "Jaunt cleanup must preserve an unrelated source of immobilization.")
		REMOVE_TRAIT(user, TRAIT_IMMOBILIZED, "independent restraint")
		qdel(spell)
		qdel(user)

/// Real movement callbacks may remove the action or transform its caster mid-stop.
/datum/unit_test/vestige_rites_jaunt_stop_interruption
	var/datum/action/cooldown/spell/jaunt/ethereal_jaunt/spell
	var/mob/living/carbon/human/user
	var/mob/living/replacement
	var/delete_action = FALSE

/datum/unit_test/vestige_rites_jaunt_stop_interruption/proc/interrupt_stop(atom/movable/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_MOVABLE_MOVED)
	if(delete_action)
		qdel(spell)
	else
		replacement.apply_status_effect(/datum/status_effect/shapechange_mob, user)

/datum/unit_test/vestige_rites_jaunt_stop_interruption/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	for(var/should_delete in list(TRUE, FALSE))
		delete_action = should_delete
		user = allocate(/mob/living/carbon/human/consistent, center)
		user.mind_initialize()
		spell = allocate(/datum/action/cooldown/spell/jaunt/ethereal_jaunt/ash/vestige, user.mind)
		spell.Grant(user)
		spell.jaunt_duration = 1 MINUTES
		var/jaunt_trait_source = REF(spell)
		spell.do_jaunt(user)
		var/obj/effect/dummy/phased_mob/spell_jaunt/holder = user.loc
		if(!delete_action)
			replacement = allocate(/mob/living/basic/pet/dog/corgi, center)
		RegisterSignal(holder, COMSIG_MOVABLE_MOVED, PROC_REF(interrupt_stop))
		spell.stop_jaunt(user, holder, center)
		TEST_ASSERT(QDELETED(holder), "An interruption during the final placement must eject and reclaim the old holder.")
		TEST_ASSERT(!HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, jaunt_trait_source), "stop_jaunt must not add a permanent restraint after movement callbacks eject the old caster.")
		if(delete_action)
			TEST_ASSERT(QDELETED(spell) && isturf(user.loc), "The action-deletion case must perform real action removal and preserve its caster.")
		else
			TEST_ASSERT_EQUAL(spell.owner, replacement, "The shapechange status must perform a real mind transfer of the jaunt action.")
			TEST_ASSERT_EQUAL(user.loc, replacement, "The actual shapechange must retain the original body inside the new shape.")
			replacement.remove_status_effect(/datum/status_effect/shapechange_mob)
			TEST_ASSERT(isturf(user.loc), "Removing the shapechange must restore the original caster.")
			TEST_ASSERT(!HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, jaunt_trait_source), "The restored body must remain free of the interrupted jaunt's restraint.")
			qdel(spell)
		qdel(user)
