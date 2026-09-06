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
	trial.release_turf = center
	var/list/walls = list()
	for(var/direction in GLOB.cardinals)
		walls += allocate(/obj/structure/vestige_field_barrier, get_step(center, direction))
	TEST_ASSERT(!trial.is_contained(user), "Building a cage around the release point instantly completed Acquisition")
	trial.release_turf = get_step(get_step(get_step(get_step(center, NORTH), NORTH), NORTH), NORTH)
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
