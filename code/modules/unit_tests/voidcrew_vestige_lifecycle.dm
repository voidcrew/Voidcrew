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
