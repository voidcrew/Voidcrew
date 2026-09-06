/// A live specimen requires actual relocation and a closed floor region, not a radius timer.
/datum/unit_test/vestige_abductor_containment/Run()
	var/turf/center = get_step(get_step(get_step(run_loc_floor_bottom_left, NORTH), NORTH), EAST)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, get_step(get_step(center, EAST), EAST))
	user.mind_initialize()
	var/datum/vestige_trial/acquisition/trial = allocate(/datum/vestige_trial/acquisition, user.mind)
	user.mind.active_vestige_trial = trial
	var/mob/living/basic/vestige_survey_specimen/specimen = allocate(/mob/living/basic/vestige_survey_specimen, center)
	trial.specimen = specimen
	specimen.trial_ref = WEAKREF(trial)
	trial.release_turf = trial.mark_turf(center)
	var/list/walls = list()
	for(var/direction in GLOB.cardinals)
		walls += allocate(/obj/structure/vestige_field_barrier, get_step(center, direction))
	TEST_ASSERT(!trial.is_contained(user), "Building a cage around the release point instantly completed Acquisition")
	trial.release_turf.forceMove(get_step(get_step(get_step(get_step(center, NORTH), NORTH), NORTH), NORTH))
	TEST_ASSERT(trial.is_contained(user), "A relocated healthy specimen in a closed enclosure was rejected")
	var/obj/structure/vestige_field_barrier/east_wall = locate() in get_step(center, EAST)
	east_wall.density = FALSE
	TEST_ASSERT(!trial.is_contained(user), "An open exit still counted as containment")
	east_wall.density = TRUE
	east_wall.anchored = FALSE
	TEST_ASSERT(!trial.is_contained(user), "A loose object counted as a reliable enclosure wall")
	east_wall.anchored = TRUE
	// A passable non-floor boundary must never substitute for a physical wall.
	east_wall.density = FALSE
	var/turf/old_east = get_step(center, EAST)
	var/old_east_type = old_east.type
	var/turf/open_boundary = old_east.ChangeTurf(/turf/open/space)
	TEST_ASSERT(trial.connected_step(center, open_boundary), "Passable space was treated as an enclosure wall")
	TEST_ASSERT(!trial.is_contained(user), "A specimen beside an open space exit was certified")
	open_boundary.ChangeTurf(old_east_type)
	east_wall.density = TRUE
	specimen.stat = UNCONSCIOUS
	TEST_ASSERT(!trial.is_contained(user), "Knocking out the specimen bypassed live containment")
	specimen.stat = CONSCIOUS
	var/obj/structure/closet/box = allocate(/obj/structure/closet, center)
	specimen.forceMove(box)
	TEST_ASSERT(!trial.is_contained(user), "A specimen inside a container passed floor containment")

/// Escape discovery follows cardinal transitions, which also cover BYOND's two-step diagonals.
/datum/unit_test/vestige_abductor_escape/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/basic/vestige_survey_specimen/specimen = allocate(/mob/living/basic/vestige_survey_specimen, center)
	var/datum/vestige_trial/acquisition/trial = allocate(/datum/vestige_trial/acquisition)
	trial.specimen = specimen
	var/turf/north = get_step(center, NORTH)
	var/turf/northeast = get_step(north, EAST)
	var/obj/structure/vestige_field_barrier/east_wall = allocate(/obj/structure/vestige_field_barrier, get_step(center, EAST))
	TEST_ASSERT(!trial.connected_step(center, get_step(center, EAST)), "A full barrier allowed direct traversal")
	TEST_ASSERT(trial.connected_step(center, north) && trial.connected_step(north, northeast), "An open diagonal escape was missed")
	var/obj/structure/vestige_field_barrier/north_wall = allocate(/obj/structure/vestige_field_barrier, north)
	TEST_ASSERT(!trial.connected_step(center, north), "The second leg's enclosure barrier was ignored")
	qdel(east_wall)
	qdel(north_wall)

/// Diagnosis selects an actual organ; insertion method, completed closure and physiology all matter.
/datum/unit_test/vestige_abductor_graft/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_trial/vivisection/trial = allocate(/datum/vestige_trial/vivisection, user.mind)
	user.mind.active_vestige_trial = trial
	var/mob/living/carbon/human/vestige_graft_patient/patient = allocate(/mob/living/carbon/human/vestige_graft_patient)
	trial.patient = patient
	patient.trial_ref = WEAKREF(trial)
	patient.waste_class = "sulfide"
	patient.setToxLoss(25)
	var/obj/item/organ/vestige_filter/wrong = allocate(/obj/item/organ/vestige_filter)
	wrong.configure("chloride", trial)
	TEST_ASSERT(wrong.pre_surgical_insertion(user, patient, BODY_ZONE_CHEST), "The patient could not receive a recoverable wrong selection")
	TEST_ASSERT(!wrong.pre_surgical_insertion(user, user, BODY_ZONE_CHEST), "A loan gland could be implanted into another body")
	wrong.Insert(patient)
	wrong.on_surgical_insertion(user, patient, BODY_ZONE_CHEST, wrong)
	TEST_ASSERT_EQUAL(patient.getToxLoss(), 25, "An incompatible gland cleared the patient's actual toxin burden")
	trial.surgical_closure = TRUE
	TEST_ASSERT(!trial.can_discharge(), "A wrong graft could be certified")
	wrong.Remove(patient)
	var/obj/item/organ/vestige_filter/correct = allocate(/obj/item/organ/vestige_filter)
	correct.configure("sulfide", trial)
	correct.Insert(patient)
	TEST_ASSERT(!trial.can_discharge(), "A direct Insert call substituted for surgical transplantation")
	correct.on_surgical_insertion(user, patient, BODY_ZONE_CHEST, correct)
	TEST_ASSERT_EQUAL(patient.getToxLoss(), 0, "A compatible surgical graft did not restore actual waste clearance")
	TEST_ASSERT(trial.can_discharge(), "A compatible surgically installed graft and closed healthy patient were rejected")
	correct.Remove(patient)
	TEST_ASSERT(!correct.surgically_installed, "An extracted gland retained proof of its old implantation")
	TEST_ASSERT(!trial.can_discharge(), "Removing the functioning filter still allowed discharge")
	user.mind.active_vestige_trial = null
	TEST_ASSERT(!correct.pre_surgical_insertion(user, patient, BODY_ZONE_CHEST), "An abandoned attempt's filter remained usable")

/// Cancellation emits the same finish signal as closure; only final stock-step advancement is evidence.
/datum/unit_test/vestige_abductor_closure/Run()
	var/datum/vestige_trial/vivisection/trial = allocate(/datum/vestige_trial/vivisection)
	var/mob/living/carbon/human/vestige_graft_patient/patient = allocate(/mob/living/carbon/human/vestige_graft_patient)
	trial.patient = patient
	var/datum/surgery/organ_manipulation/cancelled = allocate(/datum/surgery/organ_manipulation, patient, BODY_ZONE_CHEST, patient.get_bodypart(BODY_ZONE_CHEST))
	trial.on_surgery_started(patient, cancelled, BODY_ZONE_CHEST, patient.get_bodypart(BODY_ZONE_CHEST))
	qdel(cancelled)
	TEST_ASSERT(!trial.surgical_closure, "Cancelling an incision masqueraded as completing cautery")
	var/datum/surgery/organ_manipulation/finished = allocate(/datum/surgery/organ_manipulation, patient, BODY_ZONE_CHEST, patient.get_bodypart(BODY_ZONE_CHEST))
	trial.on_surgery_started(patient, finished, BODY_ZONE_CHEST, patient.get_bodypart(BODY_ZONE_CHEST))
	finished.status = length(finished.steps) + 1
	qdel(finished)
	TEST_ASSERT(trial.surgical_closure, "The final stock surgery step did not prove closure")

/// Ordinary saw, clamp and cautery effects must leave the supplied patient alive and able to recover.
/datum/unit_test/vestige_abductor_surgical_recovery/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	user.mind_initialize()
	var/datum/vestige_trial/vivisection/trial = allocate(/datum/vestige_trial/vivisection, user.mind)
	user.mind.active_vestige_trial = trial
	var/mob/living/carbon/human/vestige_graft_patient/patient = allocate(/mob/living/carbon/human/vestige_graft_patient)
	trial.patient = patient
	patient.trial_ref = WEAKREF(trial)
	patient.waste_class = "chloride"
	patient.setToxLoss(35)
	var/obj/item/bodypart/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	var/datum/surgery/organ_manipulation/operation = allocate(/datum/surgery/organ_manipulation, patient, BODY_ZONE_CHEST, chest)
	trial.on_surgery_started(patient, operation, BODY_ZONE_CHEST, chest)
	var/list/tools = list(
		allocate(/obj/item/scalpel),
		allocate(/obj/item/retractor),
		allocate(/obj/item/circular_saw),
		allocate(/obj/item/hemostat),
		allocate(/obj/item/scalpel),
	)
	for(var/index in 1 to 5)
		var/datum/surgery_step/step = GLOB.surgery_steps[operation.steps[index]]
		TEST_ASSERT(step.success(user, patient, BODY_ZONE_CHEST, tools[index], operation, FALSE), "Stock opening step [index] failed")
		operation.status++
		if(index == 3)
			TEST_ASSERT_EQUAL(chest.brute_dam, 50, "The ordinary saw step did not inflict its expected surgical trauma")
			TEST_ASSERT(patient.health > patient.crit_threshold, "The supplied patient entered critical health during a correct opening")
		if(index == 4)
			TEST_ASSERT_EQUAL(chest.brute_dam, 30, "Stock clamping did not repair part of the saw trauma")
	var/obj/item/organ/vestige_filter/filter = allocate(/obj/item/organ/vestige_filter)
	filter.configure("chloride", trial)
	filter.Insert(patient)
	filter.on_surgical_insertion(user, patient, BODY_ZONE_CHEST, filter)
	TEST_ASSERT(!trial.can_discharge(), "An open operation was certified immediately after organ insertion")
	operation.status = length(operation.steps)
	var/datum/surgery_step/close/closure = GLOB.surgery_steps[/datum/surgery_step/close]
	var/obj/item/cautery/cautery = allocate(/obj/item/cautery)
	TEST_ASSERT(closure.success(user, patient, BODY_ZONE_CHEST, cautery, operation, FALSE), "Stock cautery failed")
	TEST_ASSERT_EQUAL(chest.brute_dam, 0, "Stock final cautery did not repair the surgical trauma")
	operation.status++
	operation.complete(user)
	TEST_ASSERT(trial.can_discharge(), "The real stock operation could not leave a recovered certifiable patient")

/// Culture chemistry must be inferable, harmful outside its window, washable and actually consumed.
/datum/unit_test/vestige_abductor_culture/Run()
	var/obj/structure/vestige_tissue_culture/culture = allocate(/obj/structure/vestige_tissue_culture)
	culture.uptake_coefficient = 1.5
	culture.buffer_coefficient = 2
	culture.target_energy = 15
	var/obj/item/reagent_containers/syringe/vestige_precision/syringe = allocate(/obj/item/reagent_containers/syringe/vestige_precision)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(culture.is_injectable(), "The culture cannot receive an ordinary syringe dose")
	syringe.reagents.add_reagent(/datum/reagent/vestige_culture_nutrient, 1)
	TEST_ASSERT_EQUAL(syringe.interact_with_atom(culture, user, list()), ITEM_INTERACT_SUCCESS, "Actual syringe injection dispatch failed")
	culture.assay()
	TEST_ASSERT_EQUAL(culture.energy(), 1.5, "The actual syringe dose did not reveal nutrient uptake")
	TEST_ASSERT_EQUAL(culture.stress(), 1.5, "Nutrient failed to raise membrane stress")
	culture.reagents.add_reagent(/datum/reagent/vestige_culture_buffer, 1)
	culture.assay()
	TEST_ASSERT_EQUAL(culture.stress(), -0.5, "An isolated buffer dose did not reveal its distinct response")
	culture.reagents.add_reagent(/datum/reagent/vestige_culture_nutrient, 9)
	culture.reagents.add_reagent(/datum/reagent/vestige_culture_buffer, 6.5)
	TEST_ASSERT(culture.viable(), "A preparation calculated from both measured slopes was rejected")
	culture.reagents.add_reagent(/datum/reagent/vestige_culture_nutrient, 10)
	TEST_ASSERT(!culture.viable(), "Harvest used an old assay instead of current concentrations")
	culture.assay()
	TEST_ASSERT_EQUAL(culture.viability, 45, "A gross overdose had no additional tissue consequence")
	culture.reagents.add_reagent(/datum/reagent/water, 10)
	TEST_ASSERT_EQUAL(culture.reagents.total_volume, 0, "Washing left old medium in the reservoir")
	TEST_ASSERT_EQUAL(culture.viability, 100, "Washing did not recover the culture")
	TEST_ASSERT_EQUAL(culture.uptake_coefficient, 1.5, "Washing rerolled the measured biology")
	TEST_ASSERT(!culture.assayed, "Washing retained evidence for an old preparation")
	culture.reagents.add_reagent(/datum/reagent/vestige_culture_nutrient, 10)
	culture.reagents.add_reagent(/datum/reagent/vestige_culture_buffer, 7.5)
	culture.assay()
	TEST_ASSERT(culture.harvest(), "A recovered, balanced culture could not yield a sample")
	TEST_ASSERT_EQUAL(culture.reagents.total_volume, 0, "Harvest did not consume the actual preparation")
	TEST_ASSERT(!culture.harvest(), "An empty culture paid for a second sample")

/// Every variant can be solved from two measured responses with supplied syringe increments and volumes.
/datum/unit_test/vestige_abductor_culture_strategy/Run()
	var/obj/structure/vestige_tissue_culture/culture = allocate(/obj/structure/vestige_tissue_culture)
	for(var/uptake in list(1, 1.5, 2))
		for(var/response in list(1, 1.5, 2))
			for(var/target in list(12, 15, 18))
				culture.reagents.clear_reagents()
				culture.viability = 100
				culture.uptake_coefficient = uptake
				culture.buffer_coefficient = response
				culture.target_energy = target
				culture.reagents.add_reagent(/datum/reagent/vestige_culture_nutrient, 1)
				culture.assay()
				var/observed_uptake = culture.energy()
				culture.reagents.add_reagent(/datum/reagent/vestige_culture_buffer, 1)
				culture.assay()
				var/observed_buffer = culture.energy() - culture.stress()
				var/nutrient_dose = target / observed_uptake
				var/buffer_dose = target / observed_buffer
				TEST_ASSERT(nutrient_dose <= 50 && buffer_dose <= 50, "A measured solution exceeded the supplied reagent bottles")
				TEST_ASSERT_EQUAL(nutrient_dose * 2, round(nutrient_dose * 2), "A nutrient solution required unavailable syringe precision")
				TEST_ASSERT_EQUAL(buffer_dose * 2, round(buffer_dose * 2), "A buffer solution required unavailable syringe precision")
				culture.reagents.add_reagent(/datum/reagent/vestige_culture_nutrient, nutrient_dose - 1)
				culture.reagents.add_reagent(/datum/reagent/vestige_culture_buffer, buffer_dose - 1)
				culture.assay()
				TEST_ASSERT(culture.viable(), "Measured titration failed for uptake [uptake], buffer [response], target [target]")
				TEST_ASSERT_EQUAL(culture.viability, 70, "The three-assay solution consumed its margin for recovery")
	culture.reagents.clear_reagents()
	culture.viability = 100
	for(var/index in 1 to 5)
		culture.reagents.add_reagent(/datum/reagent/vestige_culture_nutrient, 0.5)
		culture.assay()
	TEST_ASSERT(culture.viability < 60, "Repeated tiny-dose assays retained enough tissue for harvesting")

/// Destroying the loan operating table returns attached player equipment instead of deleting it.
/datum/unit_test/vestige_abductor_operating_table/Run()
	var/obj/structure/table/optable/vestige_graft_table/table = allocate(/obj/structure/table/optable/vestige_graft_table)
	var/turf/drop_turf = get_turf(table)
	var/obj/item/tank/internals/oxygen/tank = allocate(/obj/item/tank/internals/oxygen, table)
	var/obj/item/clothing/mask/breath/mask = allocate(/obj/item/clothing/mask/breath, table)
	table.air_tank = tank
	table.breath_mask = mask
	qdel(table)
	TEST_ASSERT(!QDELETED(tank) && tank.loc == drop_turf, "The operating table reclaimed a player-added tank")
	TEST_ASSERT(!QDELETED(mask) && mask.loc == drop_turf, "The operating table reclaimed a player-added mask")

/// Sentience and ordinary brain transplantation must not turn player bodies into recalled specimens.
/datum/unit_test/vestige_abductor_occupied_specimens/Run()
	var/turf/center = get_step(get_step(run_loc_floor_bottom_left, NORTH), EAST)
	var/mob/living/carbon/human/researcher = allocate(/mob/living/carbon/human/consistent, get_step(get_step(center, EAST), EAST))
	researcher.mind_initialize()
	var/datum/vestige_trial/acquisition/acquisition = allocate(/datum/vestige_trial/acquisition, researcher.mind)
	researcher.mind.active_vestige_trial = acquisition
	var/mob/living/basic/vestige_survey_specimen/specimen = allocate(/mob/living/basic/vestige_survey_specimen, center)
	acquisition.specimen = specimen
	acquisition.release_turf = acquisition.mark_turf(get_step(get_step(get_step(get_step(center, NORTH), NORTH), NORTH), NORTH))
	for(var/direction in GLOB.cardinals)
		allocate(/obj/structure/vestige_field_barrier, get_step(center, direction))
	TEST_ASSERT(acquisition.is_contained(researcher), "The closed relocated cage must certify before its subject gains a mind.")
	TEST_ASSERT_EQUAL(specimen.sentience_type, NONE, "An issued survey specimen must not accept ordinary sentience potions.")
	specimen.mind_initialize()
	TEST_ASSERT(!acquisition.is_contained(researcher), "A player occupying the specimen must prevent destructive certification.")
	var/datum/vestige_trial/vivisection/graft = allocate(/datum/vestige_trial/vivisection, researcher.mind)
	researcher.mind.active_vestige_trial = graft
	var/mob/living/carbon/human/vestige_graft_patient/patient = allocate(/mob/living/carbon/human/vestige_graft_patient)
	graft.patient = patient
	patient.trial_ref = WEAKREF(graft)
	var/obj/item/organ/vestige_filter/filter = allocate(/obj/item/organ/vestige_filter)
	filter.configure(patient.waste_class, graft)
	filter.Insert(patient)
	filter.on_surgical_insertion(researcher, patient, BODY_ZONE_CHEST, filter)
	graft.surgical_closure = TRUE
	TEST_ASSERT(graft.can_discharge(), "The healthy compatible graft must certify before brain transplantation.")
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.mind_initialize()
	var/datum/mind/donor_mind = donor.mind
	var/obj/item/organ/brain/donor_brain = donor.get_organ_slot(ORGAN_SLOT_BRAIN)
	donor_brain.Remove(donor, special = TRUE)
	TEST_ASSERT_EQUAL(donor_mind.current, donor_brain.brainmob, "Ordinary donor extraction must move the mind into its real brainmob.")
	donor_brain.Insert(patient)
	TEST_ASSERT_EQUAL(donor_mind.current, patient, "The stock brain insertion hook must actually transfer the donor into the loan patient.")
	TEST_ASSERT(!graft.can_discharge(), "The dossier must not recall a patient now controlled by a transplanted player mind.")

/// A deterministic channel seam exercises the same reentrant Trigger and mind-transfer callbacks as a yielded wind-up.
/datum/action/cooldown/spell/vestige_recall_anchor/vestige_channel_test
	var/mob/living/replacement_body
	var/nested_result
	var/nested_planting

/datum/action/cooldown/spell/vestige_recall_anchor/vestige_channel_test/channel_pull(mob/living/user)
	channelling = TRUE
	if(replacement_body)
		user.mind.transfer_to(replacement_body)
	else
		nested_result = Trigger(user, TRIGGER_SECONDARY_ACTION)
		nested_planting = planting_this_cast
	channelling = FALSE
	return TRUE

/datum/unit_test/vestige_abductor_anchor_channel/Run()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent)
	keeper.mind_initialize()
	var/datum/action/cooldown/spell/vestige_recall_anchor/vestige_channel_test/anchor_spell = allocate(/datum/action/cooldown/spell/vestige_recall_anchor/vestige_channel_test, keeper.mind)
	anchor_spell.Grant(keeper)
	anchor_spell.anchor = allocate(/obj/effect/vestige_anchor_tag, get_step(keeper, NORTH))
	var/turf/original_anchor = get_turf(anchor_spell.anchor)
	var/result = anchor_spell.before_cast(keeper)
	TEST_ASSERT(!(result & SPELL_CANCEL_CAST), "An uninterrupted original pull should remain eligible to cast.")
	TEST_ASSERT(!anchor_spell.nested_result, "Right-clicking during a pull must not start a reentrant planting cast.")
	TEST_ASSERT(!anchor_spell.nested_planting, "A rejected replant must not change the original pull's intent.")
	TEST_ASSERT_EQUAL(get_turf(anchor_spell.anchor), original_anchor, "A rejected concurrent replant must leave the destination alone.")
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	anchor_spell.replacement_body = new_body
	result = anchor_spell.before_cast(keeper)
	TEST_ASSERT_EQUAL(anchor_spell.owner, new_body, "The real mind transfer must migrate the boon to the replacement body.")
	TEST_ASSERT(result & SPELL_CANCEL_CAST, "A pull prepared by the old body must cancel after its owner's mind transfers.")

/// The other surgeon cancels their real extraction menu while our real graft insertion is in its do_after.
/datum/unit_test/vestige_abductor_parallel_surgery
	var/mob/living/carbon/human/other_surgeon
	var/datum/surgery/organ_manipulation/other_operation
	var/interleaved = FALSE
	var/datum/surgery_step/finished_step

/datum/unit_test/vestige_abductor_parallel_surgery/Run()
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	surgeon.mind_initialize()
	var/datum/vestige_trial/vivisection/trial = allocate(/datum/vestige_trial/vivisection, surgeon.mind)
	surgeon.mind.active_vestige_trial = trial
	var/mob/living/carbon/human/vestige_graft_patient/patient = allocate(/mob/living/carbon/human/vestige_graft_patient)
	trial.patient = patient
	patient.SetSleeping(1 MINUTES)
	allocate(/obj/structure/table/optable/vestige_graft_table, get_turf(patient))
	var/obj/item/organ/vestige_filter/filter = allocate(/obj/item/organ/vestige_filter)
	filter.configure(patient.waste_class, trial)
	surgeon.put_in_active_hand(filter)
	surgeon.zone_selected = BODY_ZONE_CHEST
	var/datum/surgery/organ_manipulation/operation = allocate(/datum/surgery/organ_manipulation, patient, BODY_ZONE_CHEST, patient.get_bodypart(BODY_ZONE_CHEST))
	operation.status = 6 // The stock repeatable organ manipulation step after opening.
	operation.speed_modifier = 0.01 // Keep the actual do_after and its signal, without a long test delay.
	other_surgeon = allocate(/mob/living/carbon/human/consistent)
	other_surgeon.zone_selected = BODY_ZONE_CHEST
	other_surgeon.put_in_active_hand(allocate(/obj/item/hemostat))
	var/mob/living/carbon/human/other_patient = allocate(/mob/living/carbon/human/consistent)
	other_operation = allocate(/datum/surgery/organ_manipulation, other_patient, BODY_ZONE_CHEST, other_patient.get_bodypart(BODY_ZONE_CHEST))
	other_operation.status = 6
	RegisterSignal(surgeon, COMSIG_DO_AFTER_BEGAN, PROC_REF(on_insertion_began))
	RegisterSignal(surgeon, COMSIG_MOB_SURGERY_STEP_SUCCESS, PROC_REF(on_step_finished))
	TEST_ASSERT(operation.next_step(surgeon, list()), "The real stock surgery must accept the compatible held filter.")
	TEST_ASSERT(interleaved, "The second surgery must actually run inside the insertion's channel.")
	TEST_ASSERT_EQUAL(filter.owner, patient, "Another surgeon cancelling extraction must not erase our in-flight graft insertion.")
	TEST_ASSERT(filter.surgically_installed, "The successful independent insertion must execute the real graft hook.")
	TEST_ASSERT(finished_step && QDELETED(finished_step), "The completed invocation must reclaim its private execution state.")
	TEST_ASSERT(!QDELETED(GLOB.surgery_steps[/datum/surgery_step/manipulate_organs/internal]), "Introspection must retain the shared surgery prototype.")
	surgeon.put_in_active_hand(allocate(/obj/item/cautery))
	finished_step = null
	TEST_ASSERT(operation.next_step(surgeon, list()), "Cautery must leave the repeatable insertion step and run the stock closure.")
	TEST_ASSERT(QDELETED(operation), "The final closure must complete the operation.")
	TEST_ASSERT(finished_step && QDELETED(finished_step), "The repeatable fallback must reclaim its temporary closure step too.")
	UnregisterSignal(surgeon, COMSIG_MOB_SURGERY_STEP_SUCCESS)

/datum/unit_test/vestige_abductor_parallel_surgery/proc/on_insertion_began(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_DO_AFTER_BEGAN)
	interleaved = TRUE
	// A clientless surgeon closes the normal selection with null, the same result as Cancel.
	other_operation.next_step(other_surgeon, list())

/datum/unit_test/vestige_abductor_parallel_surgery/proc/on_step_finished(mob/living/source, datum/surgery_step/step)
	SIGNAL_HANDLER
	finished_step = step

/// Exercise the callbacks actually scheduled by the Gift, including removal and reimplantation.
/datum/unit_test/vestige_abductor_gift_delayed_healing/Run()
	for(var/scenario in list("uninterrupted", "removed", "other recipient", "same recipient", "gland deleted", "recipient deleted"))
		var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
		var/datum/vestige_boon/gland_graft/boon = allocate(/datum/vestige_boon/gland_graft)
		boon.grant(recipient, recipient.mind)
		var/obj/item/organ/heart/gland/heal/gland = recipient.get_organ_slot(ORGAN_SLOT_HEART)
		TEST_ASSERT(istype(gland) && gland.active, "The Gift must implant and activate its real heal gland.")
		gland.replace_eyes(recipient.get_organ_slot(ORGAN_SLOT_EYES))
		gland.replace_limb(BODY_ZONE_R_ARM, recipient.get_bodypart(BODY_ZONE_R_ARM))
		recipient.setToxLoss(60)
		gland.replace_blood()
		TEST_ASSERT(!recipient.get_organ_slot(ORGAN_SLOT_EYES) && !recipient.get_bodypart(BODY_ZONE_R_ARM), "The real operations must first remove the damaged anatomy.")
		TEST_ASSERT_EQUAL(recipient.getToxLoss(), 45, "Blood replacement must start once before scheduling its continuation.")
		var/list/pending = accelerate_healing(gland)
		TEST_ASSERT_EQUAL(length(pending), 3, "The actual gland must schedule eyes, limb and blood continuations.")
		var/mob/living/carbon/human/other
		var/obj/item/organ/eyes/other_eyes
		if(scenario in list("removed", "other recipient", "same recipient"))
			gland.Remove(recipient, special = TRUE)
		if(scenario == "other recipient")
			other = allocate(/mob/living/carbon/human/consistent)
			other_eyes = other.get_organ_slot(ORGAN_SLOT_EYES)
			var/obj/item/bodypart/other_arm = other.get_bodypart(BODY_ZONE_R_ARM)
			other_arm.drop_limb()
			other.setToxLoss(45)
			gland.Insert(other)
		else if(scenario == "same recipient")
			gland.Insert(recipient)
		else if(scenario == "gland deleted")
			qdel(gland)
		else if(scenario == "recipient deleted")
			qdel(recipient)
		var/deadline = world.time + 5 SECONDS
		while(callbacks_pending(pending) && world.time < deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(!callbacks_pending(pending), "The real timer subsystem did not finish or cancel the accelerated [scenario] callbacks.")
		if(scenario == "recipient deleted")
			TEST_ASSERT(QDELETED(gland), "Deleting the recipient must reclaim its gland and its remaining timers.")
		else if(scenario == "uninterrupted")
			TEST_ASSERT(recipient.get_organ_slot(ORGAN_SLOT_EYES) && recipient.get_bodypart(BODY_ZONE_R_ARM), "Uninterrupted delayed healing must restore the original recipient's anatomy.")
			TEST_ASSERT_EQUAL(recipient.getToxLoss(), 30, "The uninterrupted scheduled blood continuation must heal another fifteen toxin damage.")
		else
			TEST_ASSERT(!recipient.get_organ_slot(ORGAN_SLOT_EYES) && !recipient.get_bodypart(BODY_ZONE_R_ARM), "The [scenario] operation must not continue after its implantation ends.")
			TEST_ASSERT_EQUAL(recipient.getToxLoss(), 45, "The [scenario] operation must not continue its old blood treatment.")
		if(other)
			TEST_ASSERT_EQUAL(other.get_organ_slot(ORGAN_SLOT_EYES), other_eyes, "An earlier recipient's pending eyes must not replace the new recipient's healthy eyes.")
			TEST_ASSERT(!other.get_bodypart(BODY_ZONE_R_ARM), "Pending regrowth must not migrate to the new recipient.")
			TEST_ASSERT_EQUAL(other.getToxLoss(), 45, "The old blood continuation must not treat the new recipient.")
		if(!QDELETED(gland))
			qdel(gland)

/// Retain each real callback and its captured arguments; shorten only its timer delay.
/datum/unit_test/vestige_abductor_gift_delayed_healing/proc/accelerate_healing(obj/item/organ/heart/gland/heal/gland)
	var/list/pending = list()
	var/list/healing_procs = list(
		TYPE_PROC_REF(/obj/item/organ/heart/gland/heal, finish_replace_eyes),
		TYPE_PROC_REF(/obj/item/organ/heart/gland/heal, finish_replace_limb),
		TYPE_PROC_REF(/obj/item/organ/heart/gland/heal, keep_replacing_blood),
	)
	for(var/datum/timedevent/scheduled as anything in gland._active_timers?.Copy())
		if(!(scheduled.callBack?.delegate in healing_procs))
			continue
		var/datum/callback/healing = scheduled.callBack
		qdel(scheduled)
		var/timer_id = addtimer(healing, 1, TIMER_STOPPABLE)
		pending += SStimer.timer_id_dict[timer_id]
	return pending

/datum/unit_test/vestige_abductor_gift_delayed_healing/proc/callbacks_pending(list/pending)
	for(var/datum/timedevent/scheduled as anything in pending)
		if(!QDELETED(scheduled))
			return TRUE
	return FALSE
