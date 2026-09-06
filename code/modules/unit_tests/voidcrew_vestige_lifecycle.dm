/// Restarting is an equipment recovery path, never a new assignment or reward.
/datum/unit_test/vestige_trial_recovery/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/mind/keeper = user.mind
	var/list/pool = list(/datum/vestige_boon/spell/armblade)
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial, keeper, "Recovery patron", pool)
	keeper.active_vestige_trial = trial
	keeper.vestige_trial_assignments = list("test patron" = /datum/vestige_trial)
	var/obj/item/storage/box/box = allocate(/obj/item/storage/box)
	var/obj/item/screwdriver/loaned_tool = allocate(/obj/item/screwdriver, box)
	trial.hand_over(user, box)
	loaned_tool.forceMove(get_turf(user))
	var/obj/item/crowbar/player_tool = allocate(/obj/item/crowbar, box)
	TEST_ASSERT(trial.restart(user), "A conscious owner could not recover a lost trial kit")
	TEST_ASSERT(QDELETED(box) && QDELETED(loaned_tool), "Restart left old equipment or extracted box contents behind")
	TEST_ASSERT(!QDELETED(player_tool), "Reclaiming the kit deleted player property added afterwards")
	TEST_ASSERT(isturf(player_tool.loc), "Player property was not returned to the floor")
	var/datum/vestige_trial/replacement = keeper.active_vestige_trial
	TEST_ASSERT(replacement && replacement != trial, "Restart failed to replace the old trial")
	TEST_ASSERT_EQUAL(replacement.patron_name, "Recovery patron", "Restart lost the patron")
	TEST_ASSERT_EQUAL(replacement.boon_pool[1], pool[1], "Restart changed the reward pool")
	TEST_ASSERT_EQUAL(keeper.vestige_trial_assignments["test patron"], /datum/vestige_trial, "Restart rerolled assignment")
	trial.complete()
	TEST_ASSERT(!length(keeper.completed_vestige_trials), "A stale callback completed the abandoned attempt")
	TEST_ASSERT(!keeper.vestige_pending_reward, "Restart paid a reward")
	qdel(replacement)

/// A deferred completion must still book one debt after the body is gone.
/datum/unit_test/vestige_deferred_completion/Run()
	var/datum/mind/keeper = allocate(/datum/mind, "vestige-deferred-unit-test")
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial, keeper, "Test patron", list(/datum/vestige_boon/spell/armblade, /datum/vestige_boon/spell/fleshmend))
	keeper.active_vestige_trial = trial
	trial.complete()
	var/datum/vestige_record/record = get_vestige_record(keeper)
	TEST_ASSERT(record, "A completion without a body lost its debt")
	TEST_ASSERT_EQUAL(length(record.completed_trials), 1, "The completion was not recorded exactly once")
	TEST_ASSERT_EQUAL(length(record.pending_candidates), 2, "The deferred reward lost its original candidate subset")
	trial.complete()
	TEST_ASSERT_EQUAL(length(record.completed_trials), 1, "A stale callback recorded a second completion")
	GLOB.vestige_records -= ckey(keeper.key)
	qdel(record)

/// Two menus can belong to the same soul after body restoration. Only one pays.
/datum/unit_test/vestige_reward_single_claim/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/mind/keeper = user.mind
	keeper.key = "vestige-claim-unit-test"
	var/datum/vestige_record/record = get_vestige_record(keeper, create = TRUE)
	var/list/candidates = list(/datum/vestige_boon/unit_test_a, /datum/vestige_boon/unit_test_b)
	record.pending_candidates = candidates.Copy()
	var/datum/action/vestige_reward/first = allocate(/datum/action/vestige_reward, keeper, candidates, "Test patron")
	var/datum/action/vestige_reward/stale = allocate(/datum/action/vestige_reward, keeper, candidates, "Test patron")
	first.Grant(user)
	stale.Grant(user)
	first.claim(user, keeper, /datum/vestige_boon/unit_test_a)
	stale.claim(user, keeper, /datum/vestige_boon/unit_test_b)
	TEST_ASSERT_EQUAL(length(keeper.vestige_boons), 1, "An already-open stale menu granted a second boon")
	TEST_ASSERT_EQUAL(length(record.boons), 1, "One trial paid two recorded rewards")
	TEST_ASSERT(!length(record.pending_candidates), "Claiming failed to settle the debt")
	GLOB.vestige_records -= ckey(keeper.key)
	qdel(record)

/datum/vestige_boon/unit_test_a
/datum/vestige_boon/unit_test_b

/// Respawning before a deferred completion cannot mint a second debt for the same trial.
/datum/unit_test/vestige_completion_across_minds/Run()
	var/datum/mind/old_keeper = allocate(/datum/mind, "vestige-respawn-unit-test")
	var/datum/mind/new_keeper = allocate(/datum/mind, "vestige-respawn-unit-test")
	var/list/pool = list(/datum/vestige_boon/unit_test_a)
	var/datum/vestige_trial/old_attempt = allocate(/datum/vestige_trial, old_keeper, "Test patron", pool)
	var/datum/vestige_trial/new_attempt = allocate(/datum/vestige_trial, new_keeper, "Test patron", pool)
	old_keeper.active_vestige_trial = old_attempt
	new_keeper.active_vestige_trial = new_attempt
	old_attempt.complete()
	var/datum/vestige_record/record = get_vestige_record(old_keeper)
	TEST_ASSERT(record && length(record.pending_candidates), "First attempt lost its debt")
	record.pending_candidates = null // The first debt was paid before the replacement attempt finished.
	new_attempt.complete()
	TEST_ASSERT(!length(record.pending_candidates), "A second mind minted a second debt for an already completed trial")
	TEST_ASSERT(QDELETED(new_attempt) && !new_keeper.active_vestige_trial, "The stale replacement attempt was not cleaned up")
	GLOB.vestige_records -= ckey(old_keeper.key)
	qdel(record)

/// Speech and movement constraints must follow the mind that owns the pact.
/datum/unit_test/vestige_rites_body_tracking/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent, center)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent, center)
	old_body.mind_initialize()
	var/datum/mind/keeper = old_body.mind
	var/datum/vestige_trial/swallowed_word/word = allocate(/datum/vestige_trial/swallowed_word, keeper)
	keeper.active_vestige_trial = word
	word.on_accepted(old_body)
	word.unfold(old_body)
	keeper.transfer_to(new_body)
	TEST_ASSERT_EQUAL(word.listener, new_body, "The silence constraint stayed attached to the old body")
	word.moves = 5
	SEND_SIGNAL(old_body, COMSIG_MOB_SAY, list())
	TEST_ASSERT_EQUAL(word.moves, 5, "Speech from the abandoned body reshuffled the keeper's puzzle")
	SEND_SIGNAL(new_body, COMSIG_MOB_SAY, list())
	TEST_ASSERT_EQUAL(word.moves, 0, "The current keeper could speak without reshuffling")
	qdel(word)
	var/datum/vestige_trial/rite_of_transcription/door_trial = allocate(/datum/vestige_trial/rite_of_transcription, keeper)
	keeper.active_vestige_trial = door_trial
	door_trial.on_accepted(new_body)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, get_step(center, NORTH))
	door.density = FALSE
	door_trial.threshold = door
	door_trial.breached = TRUE
	keeper.transfer_to(old_body)
	TEST_ASSERT_EQUAL(door_trial.walker, old_body, "The crossing listener did not follow the mind")
	new_body.forceMove(get_turf(door))
	TEST_ASSERT(!door_trial.crossed, "The abandoned body could establish the keeper's crossing")
	old_body.forceMove(get_turf(door))
	TEST_ASSERT(door_trial.crossed, "The current body could not establish a real crossing")

/// Implanted player property must be detached before the loan patient is reclaimed.
/datum/unit_test/vestige_patient_property_recovery/Run()
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/turf/floor = get_turf(patient)
	trial.register_loan(patient)
	var/obj/item/organ/liver/player_liver = allocate(/obj/item/organ/liver)
	player_liver.Insert(patient, special = TRUE)
	var/obj/item/bodypart/head/player_head = allocate(/obj/item/bodypart/head)
	player_head.replace_limb(patient)
	var/obj/item/organ/eyes/player_eyes = allocate(/obj/item/organ/eyes)
	player_eyes.Insert(patient, special = TRUE)
	var/obj/item/bodypart/head/loose_head = allocate(/obj/item/bodypart/head, patient)
	var/obj/item/bodypart/chest/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	var/obj/item/crowbar/player_tool = allocate(/obj/item/crowbar, chest)
	chest.cavity_item = player_tool
	TEST_ASSERT_EQUAL(player_liver.owner, patient, "The test must install actual player-supplied anatomy")
	TEST_ASSERT_EQUAL(player_eyes.bodypart_owner, player_head, "The test must install player organs in a player-supplied limb")
	qdel(trial)
	TEST_ASSERT(QDELETED(patient), "The loan patient survived reclaim")
	TEST_ASSERT(!QDELETED(player_liver), "Reclaim deleted a player-supplied transplant")
	TEST_ASSERT(!player_liver.owner && !player_liver.bodypart_owner, "The returned organ retained a deleted anatomy owner")
	TEST_ASSERT_EQUAL(player_liver.loc, floor, "Organ movement callbacks stranded the returned transplant in nullspace")
	TEST_ASSERT(!QDELETED(player_tool) && player_tool.loc == floor, "Chest cleanup deleted the returned cavity item through a cached reference")
	TEST_ASSERT(!QDELETED(player_head) && player_head.loc == floor && !player_head.owner, "The transplanted player limb was lost or retained its deleted owner")
	TEST_ASSERT(!QDELETED(player_eyes) && player_eyes.loc == floor && !player_eyes.owner, "Organs in a returned player limb remained in the patient's deletion registry")
	TEST_ASSERT(!QDELETED(loose_head) && loose_head.loc == floor, "A loose player head could not be returned without an anatomy owner")
