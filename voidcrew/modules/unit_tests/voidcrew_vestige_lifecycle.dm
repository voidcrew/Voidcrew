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

/// An old body's claim may survive its debt and a later completion by the same soul.
/datum/unit_test/vestige_reward_generation/Run()
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	old_body.mind_initialize()
	new_body.mind_initialize()
	var/datum/mind/old_mind = old_body.mind
	var/datum/mind/new_mind = new_body.mind
	old_mind.key = "vestige-debt-generation-test"
	new_mind.key = old_mind.key
	var/list/first_pool = list(/datum/vestige_boon/unit_test_a, /datum/vestige_boon/unit_test_b)
	var/datum/vestige_trial/first = allocate(/datum/vestige_trial, old_mind, "First patron", first_pool)
	first.offer_reward(null)
	var/datum/vestige_record/record = get_vestige_record(old_mind)
	var/datum/action/vestige_reward/stale = allocate(/datum/action/vestige_reward, old_mind, record.pending_candidates.Copy(), "First patron")
	stale.Grant(old_body)
	old_mind.vestige_pending_reward = stale
	var/datum/action/vestige_reward/restored = allocate(/datum/action/vestige_reward, new_mind, record.pending_candidates.Copy(), "First patron")
	restored.Grant(new_body)
	restored.claim(new_body, new_mind, /datum/vestige_boon/unit_test_a)
	TEST_ASSERT(!length(record.pending_candidates), "The first restored payment must settle before a new debt is issued")
	var/datum/vestige_trial/second = allocate(/datum/vestige_trial, new_mind, "Second patron", list(/datum/vestige_boon/unit_test_b))
	second.offer_reward(null)
	TEST_ASSERT(/datum/vestige_boon/unit_test_b in record.pending_candidates, "A second actual reward roll must create a fresh debt")
	stale.clear_recorded_pending(old_mind)
	TEST_ASSERT(length(record.pending_candidates), "An old claim erased a later pact's debt")
	stale.claim(old_body, old_mind, /datum/vestige_boon/unit_test_b)
	TEST_ASSERT(!length(old_mind.vestige_boons), "An old claim spent a later pact's overlapping candidate")
	TEST_ASSERT(length(record.pending_candidates), "Rejecting an old claim lost the current reward")
	stale.open_reward_menu(old_body)
	TEST_ASSERT(QDELETED(stale) && !old_mind.vestige_pending_reward, "The obsolete claim blocked restoration of the new payment")
	TEST_ASSERT(length(record.pending_candidates), "Discarding the obsolete button erased the current debt")
	GLOB.vestige_records -= ckey(old_mind.key)
	qdel(record)

/// Restoring an upgraded shape changes the body before later rewards are restored.
/datum/unit_test/vestige_restore_after_unshift/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/mind/keeper = user.mind
	keeper.key = "vestige-unshift-restore-test"
	var/datum/action/cooldown/spell/shapeshift/vestige_mimic/shape_spell = allocate(/datum/action/cooldown/spell/shapeshift/vestige_mimic, keeper)
	shape_spell.Grant(user)
	var/obj/item/wrench/model = allocate(/obj/item/wrench, get_turf(user))
	TEST_ASSERT(shape_spell.PreActivate(model), "The restoration regression must start inside an actual borrowed shape")
	var/mob/living/shape = keeper.current
	TEST_ASSERT(shape != user && user.loc == shape, "The real shape must hold the original body")
	// The base is present on this mind, while its upgrade and a later item were lost on respawn.
	keeper.vestige_boons = list(/datum/vestige_boon/spell/mimic_form)
	var/datum/vestige_record/record = get_vestige_record(keeper, create = TRUE)
	record.boons = list(/datum/vestige_boon/spell/mimic_form, /datum/vestige_boon/spell/mimic_form/flawless, /datum/vestige_boon/item/master_blade)
	record.pending_candidates = list(/datum/vestige_boon/unit_test_a)
	var/mob/living/basic/vestige_patron/patron = allocate(/mob/living/basic/vestige_patron, get_turf(shape))
	TEST_ASSERT(patron.restore_lost_legacy(shape), "The patron did not restore the missing legacy")
	TEST_ASSERT(QDELETED(shape) && keeper.current == user, "Restoring the upgrade must leave the player in the surviving body")
	var/datum/vestige_boon/item/master_blade/blade_boon = /datum/vestige_boon/item/master_blade
	var/obj/item/prize = locate(initial(blade_boon.item_type)) in user.held_items
	TEST_ASSERT(prize, "The item restored after unshifting was lost in the deleted form")
	TEST_ASSERT(keeper.vestige_pending_reward?.owner == user, "The remaining reward was granted to the deleted form")
	TEST_ASSERT(keeper.vestige_pending_reward in user.actions, "The surviving body did not receive its pending claim button")
	GLOB.vestige_records -= ckey(keeper.key)
	qdel(record)

/// The naturally expired cloak must recover for one third of its full duration.
/datum/unit_test/vestige_cloak_timeout/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/spell/shadow_cloak/cloak = allocate(/datum/action/cooldown/spell/shadow_cloak)
	cloak.Grant(user)
	cloak.cast(user)
	TEST_ASSERT(cloak.active_cloak && HAS_TRAIT(user, TRAIT_UNKNOWN), "The cloak did not apply its identity concealment")
	cloak.timed_uncloak(user)
	TEST_ASSERT(!cloak.active_cloak && !HAS_TRAIT(user, TRAIT_UNKNOWN), "Natural timeout did not remove the cloak")
	TEST_ASSERT_EQUAL(cloak.next_use_time - world.time, cloak.uncloak_time / 3, "Natural expiration used the cleared timer ID and allowed immediate recasting")

/// A second pact dialog must not reopen completed work or follow a different soul.
/datum/unit_test/vestige_pact_stale_offer/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/mind/keeper = user.mind
	keeper.key = "vestige-offer-unit-test"
	var/mob/living/basic/vestige_patron/patron = allocate(/mob/living/basic/vestige_patron, get_turf(user))
	var/datum/vestige_trial/offered = allocate(/datum/vestige_trial, keeper, "Test patron", list(/datum/vestige_boon/unit_test_a))
	TEST_ASSERT(patron.can_accept_pact(user, offered), "A fresh offer should be acceptable")
	var/datum/vestige_record/record = get_vestige_record(keeper, create = TRUE)
	record.pending_candidates = list(/datum/vestige_boon/unit_test_a)
	TEST_ASSERT(!patron.can_accept_pact(user, offered), "An old dialog can accept work while the soul holds an unclaimed reward")
	record.pending_candidates = null
	record.completed_trials += offered.type
	TEST_ASSERT(!patron.can_accept_pact(user, offered), "An old dialog can reopen a completed trial")
	record.completed_trials.Cut()
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent, get_turf(user))
	keeper.transfer_to(new_body)
	user.mind_initialize()
	TEST_ASSERT(!patron.can_accept_pact(user, offered), "An old body's dialog can start a pact for the departed mind")
	GLOB.vestige_records -= ckey(keeper.key)
	qdel(record)

/// Splitting and merging must preserve the boundary between loans and player supplies.
/datum/unit_test/vestige_trial_stack_custody/Run()
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial)
	var/obj/item/stack/sheet/iron/loan = allocate(/obj/item/stack/sheet/iron, run_loc_floor_bottom_left, 10, FALSE)
	var/obj/item/stack/sheet/iron/player_stack = allocate(/obj/item/stack/sheet/iron, run_loc_floor_bottom_left, 3, FALSE)
	trial.register_loan(loan)
	var/obj/item/stack/sheet/iron/split = loan.split_stack(2)
	// Keep it separate: moving back onto the source automatically merges it.
	split.forceMove(get_step(run_loc_floor_bottom_left, EAST))
	TEST_ASSERT(!loan.can_merge(player_stack), "Loaned iron can be merged into permanent player supplies")
	TEST_ASSERT(!player_stack.can_merge(loan), "Player supplies can be merged into a loan and later deleted")
	TEST_ASSERT(split.can_merge(loan), "Splits belonging to the same trial should remain mergeable")
	qdel(trial)
	TEST_ASSERT(QDELETED(loan) && QDELETED(split), "Splitting let part of the loan escape reclamation")
	TEST_ASSERT(!QDELETED(player_stack) && player_stack.amount == 3, "Reclaiming a loan affected the player's original iron")

/// Deleting a mind must reclaim its equipment and stop its attempt.
/datum/unit_test/vestige_trial_owner_deleted/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial, user.mind)
	user.mind.active_vestige_trial = trial
	var/obj/item/storage/box/loan = allocate(/obj/item/storage/box, get_turf(user))
	trial.register_loan(loan)
	var/obj/item/crowbar/player_tool = allocate(/obj/item/crowbar, loan)
	qdel(user.mind)
	TEST_ASSERT(QDELETED(trial) && QDELETED(loan), "Deleting the mind orphaned its trial or equipment")
	TEST_ASSERT(!QDELETED(player_tool) && isturf(player_tool.loc), "Mind deletion did not return player property")

/// Returning from a shape deletes that shape; it must not end the current body's run.
/datum/unit_test/vestige_ascension_body_tracking/Run()
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	old_body.mind_initialize()
	var/datum/mind/keeper = old_body.mind
	var/datum/vestige_ascension/offer = allocate(/datum/vestige_ascension/oracle)
	var/datum/vestige_ascension_run/run = allocate(/datum/vestige_ascension_run, offer, old_body)
	keeper.active_ascension_run = run
	run.watch_supplicant(old_body)
	keeper.transfer_to(new_body)
	qdel(old_body)
	TEST_ASSERT(!QDELETED(run), "Deleting an abandoned shape ended the keeper's ascension")
	TEST_ASSERT_EQUAL(run.watched_supplicant, new_body, "The arena did not follow the keeper's new body")
	new_body.death()
	TEST_ASSERT(QDELETED(run) && !keeper.active_ascension_run, "Death in the new body did not end the ascension")
	TEST_ASSERT(QDELETED(new_body), "The new body's death bypassed the arena's consumption rule")

/// Several arenas and unrelated reservations can share one z-level.
/datum/unit_test/vestige_ascension_bounds/Run()
	var/turf/inside = run_loc_floor_bottom_left
	var/turf/outside = get_step(inside, EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, inside)
	var/datum/turf_reservation/reservation = allocate(/datum/turf_reservation)
	reservation.bottom_left_turfs = list(inside)
	reservation.top_right_turfs = list(inside)
	var/datum/vestige_ascension_run/run = allocate(/datum/vestige_ascension_run)
	run.reservation = reservation
	run.arena_bottom_left = inside
	TEST_ASSERT(run.in_arena(user), "The arena rejected its own turf")
	user.forceMove(outside)
	var/accepted_outside = run.in_arena(user)
	// These are test-room bounds, not a real reservation; never release those turfs.
	reservation.bottom_left_turfs.Cut()
	reservation.top_right_turfs.Cut()
	TEST_ASSERT(!accepted_outside, "The arena treats every other reservation on its z-level as its own")

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

/// Taking over a supplied body through actual brain surgery must survive pact cleanup.
/datum/unit_test/vestige_occupied_loan_body/Run()
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	trial.register_loan(patient)
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.mind_initialize()
	var/datum/mind/occupant = donor.mind
	var/obj/item/organ/brain/player_brain = donor.get_organ_slot(ORGAN_SLOT_BRAIN)
	player_brain.Remove(donor, special = TRUE)
	player_brain.Insert(patient)
	TEST_ASSERT_EQUAL(occupant.current, patient, "Ordinary transplantation must put the donor in the supplied body")
	var/list/anatomy = patient.bodyparts.Copy() + patient.organs.Copy()
	var/obj/item/knife/kitchen/loan_knife = allocate(/obj/item/knife/kitchen, patient)
	trial.register_loan(loan_knife)
	var/obj/item/crowbar/player_tool = allocate(/obj/item/crowbar, patient)
	qdel(trial)
	TEST_ASSERT(!QDELETED(patient) && occupant.current == patient, "Pact cleanup deleted a person occupying its supplied body")
	for(var/obj/item/part as anything in anatomy)
		TEST_ASSERT(!QDELETED(part), "Pact cleanup reclaimed anatomy from the occupied body: [part.type]")
	TEST_ASSERT_EQUAL(player_brain.owner, patient, "Cleanup detached the transplanted player's brain")
	TEST_ASSERT(!QDELETED(player_tool) && player_tool.loc == patient, "Cleanup stripped the occupied body's player property")
	TEST_ASSERT(QDELETED(loan_knife), "Protecting a body should still reclaim ordinary loan tools")

/// A transplant out of a loan patient must not disappear from the receiving player.
/datum/unit_test/vestige_loan_transplant_custody/Run()
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	trial.register_loan(patient)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.mind_initialize()
	var/obj/item/organ/liver/transplant = patient.get_organ_slot(ORGAN_SLOT_LIVER)
	transplant.Remove(patient, special = TRUE)
	transplant.Insert(recipient, special = TRUE)
	var/obj/item/bodypart/arm/right/arm = patient.get_bodypart(BODY_ZONE_R_ARM)
	arm.drop_limb(special = TRUE)
	arm.replace_limb(recipient)
	qdel(trial)
	TEST_ASSERT(QDELETED(patient), "The unoccupied donor body should still be reclaimed")
	TEST_ASSERT(!QDELETED(transplant) && transplant.owner == recipient, "Pact cleanup removed a liver transplanted into a player")
	TEST_ASSERT(!QDELETED(arm) && arm.owner == recipient, "Pact cleanup removed a limb transplanted onto a player")

/// Extracting an adopted loan brain stores a real mind in a cached brainmob.
/datum/unit_test/vestige_loan_brain_custody/Run()
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	trial.register_loan(patient)
	var/obj/item/organ/brain/loan_brain = patient.get_organ_slot(ORGAN_SLOT_BRAIN)
	loan_brain.Remove(patient, special = TRUE)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	loan_brain.Insert(recipient, special = TRUE)
	// Possess the body after its empty replacement brain is installed. Replacing
	// an occupied original brain would correctly take that mind out with it.
	recipient.mind_initialize()
	var/datum/mind/occupant = recipient.mind
	loan_brain.Remove(recipient, special = TRUE)
	var/mob/living/brain/stored_body = loan_brain.brainmob
	TEST_ASSERT(stored_body && occupant.current == stored_body, "Actual brain extraction must store the recipient's mind")
	qdel(trial)
	TEST_ASSERT(!QDELETED(loan_brain) && !QDELETED(stored_body), "Reclaiming a loan brain deleted its new occupant")
	TEST_ASSERT_EQUAL(occupant.current, stored_body, "Loan cleanup displaced the mind stored in the brain")
	TEST_ASSERT_EQUAL(stored_body.loc, loan_brain, "The preserved brainmob must remain in its intact brain organ")

/// A shapeshift or cyborg body must reach the same patron conversation as a human.
/datum/unit_test/vestige_patron_body_interaction/Run()
	var/turf/patron_floor = run_loc_floor_bottom_left
	var/mob/living/basic/vestige_patron/unit_test_menu/patron = allocate(/mob/living/basic/vestige_patron/unit_test_menu, patron_floor)
	for(var/body_type in list(/mob/living/carbon/human/consistent, /mob/living/basic/carp, /mob/living/carbon/human/species/monkey, /mob/living/silicon/robot, /mob/living/carbon/alien/larva, /mob/living/basic/drone))
		var/mob/living/user = allocate(body_type, get_step(patron_floor, EAST))
		user.mind_initialize()
		user.set_combat_mode(FALSE)
		patron.last_supplicant = null
		user.UnarmedAttack(patron, TRUE, list())
		TEST_ASSERT_EQUAL(patron.last_supplicant, user, "[body_type]'s real unarmed interaction did not reach the patron conversation")
		patron.last_supplicant = null
		user.set_stat(UNCONSCIOUS)
		user.UnarmedAttack(patron, TRUE, list())
		TEST_ASSERT(!patron.last_supplicant, "An unconscious [body_type] opened a patron conversation")
		user.set_stat(CONSCIOUS)
		user.forceMove(get_step(get_step(patron_floor, EAST), EAST))
		if(iscyborg(user))
			patron.attack_robot(user, list())
		else
			patron.try_open_patron_menu(user)
		TEST_ASSERT(!patron.last_supplicant, "A distant [body_type] opened a touch-only patron conversation")
		qdel(user)

/// The same physical body can remain at a patron after its original soul leaves.
/datum/unit_test/vestige_patron_menu_identity/Run()
	var/mob/living/basic/vestige_patron/patron = allocate(/mob/living/basic/vestige_patron, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, NORTH))
	old_body.mind_initialize()
	var/datum/mind/opening_mind = old_body.mind
	TEST_ASSERT(patron.check_menu(old_body, opening_mind), "The original adjacent conscious supplicant should own its menu")
	opening_mind.transfer_to(new_body)
	TEST_ASSERT(!patron.check_menu(old_body, opening_mind), "A departed soul's stale menu remained valid on its abandoned body")
	old_body.mind_initialize()
	TEST_ASSERT(!patron.check_menu(old_body, opening_mind), "A new occupant inherited the previous soul's pending patron choice")
	TEST_ASSERT(patron.check_menu(new_body, opening_mind), "The current body could not start a fresh patron conversation")
	qdel(patron)
	TEST_ASSERT(!patron.check_menu(new_body, opening_mind), "An unloaded patron kept its old conversation valid")

/mob/living/basic/vestige_patron/unit_test_menu
	var/mob/living/last_supplicant

/mob/living/basic/vestige_patron/unit_test_menu/open_patron_menu(mob/living/user)
	last_supplicant = user

/// Persistent overmap signals can receive a second ship's departure callback after unloading.
/datum/unit_test/vestige_unloaded_signal_retry/Run()
	var/obj/structure/overmap/space_ruin/vestige/signal = allocate(/obj/structure/overmap/space_ruin/vestige)
	signal.check_and_respawn()
	signal.check_and_respawn()
	TEST_ASSERT(!length(signal._active_timers), "An already unloaded Vestige signal armed endless teardown retries")
	// A still-loading site must retain the normal retry: its slot may not exist yet.
	signal.loading = TRUE
	signal.check_and_respawn()
	TEST_ASSERT_EQUAL(length(signal._active_timers), 1, "A transient load must still schedule a later teardown check")

/// A real old-body hatch must not overwrite payment for a different replacement-body trial.
/datum/unit_test/vestige_rewards_after_respawn/Run()
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	old_body.mind_initialize()
	new_body.mind_initialize()
	var/datum/mind/old_mind = old_body.mind
	var/datum/mind/new_mind = new_body.mind
	old_mind.key = "vestige-reward-backlog-test"
	new_mind.key = old_mind.key
	var/datum/vestige_trial/warm_season/old_trial = allocate(/datum/vestige_trial/warm_season, old_mind, "Old patron", list(/datum/vestige_boon/unit_test_a))
	var/datum/vestige_trial/vigil/new_trial = allocate(/datum/vestige_trial/vigil, new_mind, "New patron", list(/datum/vestige_boon/unit_test_b))
	old_mind.active_vestige_trial = old_trial
	new_mind.active_vestige_trial = new_trial
	var/obj/structure/vestige_comb_egg/egg = allocate(/obj/structure/vestige_comb_egg, run_loc_floor_bottom_left)
	egg.bound_mind = old_mind
	old_trial.egg_structure = egg
	old_trial.register_loan(egg)
	old_body.death()
	egg.hatch()
	var/datum/vestige_record/record = get_vestige_record(new_mind)
	TEST_ASSERT(record && /datum/vestige_boon/unit_test_a in record.pending_candidates, "The departed body's actual hatch must leave its payment")
	var/datum/action/vestige_reward/old_button = old_mind.vestige_pending_reward
	new_trial.complete()
	TEST_ASSERT(/datum/vestige_boon/unit_test_a in record.pending_candidates, "The newer trial overwrote the first unpaid roll")
	TEST_ASSERT_EQUAL(record.pending_patron_name, "Old patron", "The first debt lost its patron")
	TEST_ASSERT_EQUAL(length(record.queued_rewards), 1, "The second completed trial did not retain its own payment")
	var/datum/action/vestige_reward/first = new_mind.vestige_pending_reward
	TEST_ASSERT(first && /datum/vestige_boon/unit_test_a in first.candidates, "The current body's button must settle the oldest debt first")
	first.claim(new_body, new_mind, /datum/vestige_boon/unit_test_a)
	var/datum/action/vestige_reward/second = new_mind.vestige_pending_reward
	TEST_ASSERT(second && second != first && /datum/vestige_boon/unit_test_b in second.candidates, "Settling the first debt did not expose the second payment")
	TEST_ASSERT_EQUAL(second.patron_name, "New patron", "The queued payment lost its own patron")
	old_button.clear_recorded_pending(old_mind)
	old_button.claim(old_body, old_mind, /datum/vestige_boon/unit_test_a)
	TEST_ASSERT(!length(old_mind.vestige_boons), "The abandoned body's old button paid the first reward twice")
	TEST_ASSERT(/datum/vestige_boon/unit_test_b in record.pending_candidates, "A stale old-body button erased the promoted debt")
	second.claim(new_body, new_mind, /datum/vestige_boon/unit_test_b)
	TEST_ASSERT_EQUAL(length(record.boons), 2, "Two different completed pacts must pay exactly two recorded boons")
	TEST_ASSERT_EQUAL(length(record.completed_trials), 2, "Both actual completion paths must remain booked")
	TEST_ASSERT(!length(record.pending_candidates) && !length(record.queued_rewards) && !new_mind.vestige_pending_reward, "The paid backlog left an outstanding debt or button")
	GLOB.vestige_records -= ckey(new_mind.key)
	qdel(record)

/// A departed mind's late reward roll must respect powers its replacement already earned.
/datum/unit_test/vestige_late_reward_eligibility/Run()
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	old_body.mind_initialize()
	new_body.mind_initialize()
	var/datum/mind/old_mind = old_body.mind
	var/datum/mind/new_mind = new_body.mind
	old_mind.key = "vestige-late-eligibility-test"
	new_mind.key = old_mind.key
	var/datum/vestige_trial/first = allocate(/datum/vestige_trial, new_mind, "First patron", list(/datum/vestige_boon/spell/armblade))
	first.offer_reward(new_body)
	new_mind.vestige_pending_reward.claim(new_body, new_mind, /datum/vestige_boon/spell/armblade)
	TEST_ASSERT(!length(old_mind.vestige_boons), "The abandoned mind must still be behind its replacement's ledger")
	var/datum/vestige_trial/late = allocate(/datum/vestige_trial, old_mind, "Late patron", list(/datum/vestige_boon/spell/armblade, /datum/vestige_boon/spell/armblade/perfected))
	late.offer_reward(old_body)
	var/datum/action/vestige_reward/reward = old_mind.vestige_pending_reward
	TEST_ASSERT_EQUAL(length(reward.candidates), 1, "The stale mind rerolled an already recorded base boon")
	TEST_ASSERT(/datum/vestige_boon/spell/armblade/perfected in reward.candidates, "The soul's earned prerequisite did not unlock its upgrade")
	reward.claim(old_body, old_mind, /datum/vestige_boon/spell/armblade/perfected)
	var/mob/living/basic/vestige_patron/patron = allocate(/mob/living/basic/vestige_patron)
	patron.restore_lost_legacy(old_body)
	var/blades = 0
	for(var/datum/action/cooldown/spell/vestige_armblade/blade in old_body.actions)
		blades++
		TEST_ASSERT(istype(blade, /datum/action/cooldown/spell/vestige_armblade/perfected), "Restoring the legacy reintroduced a superseded base action")
	TEST_ASSERT_EQUAL(blades, 1, "A late upgrade must leave exactly its upgraded ability after restoration")
	var/datum/vestige_record/record = get_vestige_record(old_mind)
	TEST_ASSERT_EQUAL(length(record.boons), 2, "The soul must own one base and its one upgrade")
	GLOB.vestige_records -= ckey(old_mind.key)
	qdel(record)
