/**
 * Regression cover for the two symptoms whose retune is about WHEN and WHETHER they apply, rather
 * than what numbers they carry. Both bugs this guards against were live in the code before the
 * retune:
 *
 * - Regenerative Coma armed itself from a raw damage figure, and because every other `stat` case
 *   returned early it could only ever fire on a host who was still fully CONSCIOUS. The test
 *   asserts the opposite: a conscious host with heavy damage is NOT put in a coma, and a host who
 *   has actually gone down IS.
 * - Insomnia granted TRAIT_SLEEPIMMUNE in `on_stage_change()` and never removed it, so curing the
 *   virus left a permanently un-sleepable crew member. The test asserts the trait is gone after
 *   `End()`.
 *
 * Plus the trait pair on the coma (TRAIT_NOCRITDAMAGE + TRAIT_NOHARDCRIT, which replaced the
 * ported PR's orphan "Conscience Stabilizers" reagent) and Muscular Dexterity's modifier/trait
 * cleanup, which is the most stateful thing the port adds.
 *
 * The symptom procs are driven directly against a hand-built disease instead of through
 * `infect()`, so nothing here depends on spread, viability or the disease subsystem ticking.
 */
/datum/unit_test/voidcrew_virology_symptoms

/datum/unit_test/voidcrew_virology_symptoms/proc/attach(datum/disease/advance/disease, mob/living/carbon/human/patient, datum/symptom/symptom, stage = 4)
	disease.affected_mob = patient
	disease.symptoms = list(symptom)
	disease.stage = stage
	return symptom

/datum/unit_test/voidcrew_virology_symptoms/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)

	// ---- Regenerative Coma -------------------------------------------------------------------
	var/datum/disease/advance/coma_disease = new()
	var/datum/symptom/heal/coma/coma = attach(coma_disease, patient, new /datum/symptom/heal/coma())

	// The ported bug: a conscious host at a damage figure used to be dropped into a 30s fakedeath.
	patient.stat = CONSCIOUS
	patient.adjustBruteLoss(120, updating_health = FALSE)
	TEST_ASSERT_EQUAL(patient.stat, CONSCIOUS, "the test host should still be conscious")
	coma.CanHeal(coma_disease)
	TEST_ASSERT(!coma.active_coma, "a conscious host must not be put into a regenerative coma")

	// Having actually gone down is what arms it.
	patient.stat = SOFT_CRIT
	coma.CanHeal(coma_disease)
	TEST_ASSERT(coma.active_coma, "a host in soft crit should arm the regenerative coma")

	// Stabilization: the Resistance 4 threshold grants both crit traits, and End() clears both.
	coma.stabilize = TRUE
	coma.on_stage_change(coma_disease)
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_NOCRITDAMAGE), "the coma should stop crit damage once stabilized")
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_NOHARDCRIT), "the coma should keep a stabilized host out of hard crit")
	coma.End(coma_disease)
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_NOCRITDAMAGE), "crit damage immunity leaked past the coma's End()")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_NOHARDCRIT), "hard crit immunity leaked past the coma's End()")

	// ---- Insomnia ---------------------------------------------------------------------------
	var/datum/disease/advance/insomnia_disease = new()
	var/datum/symptom/insomnia/insomnia = attach(insomnia_disease, patient, new /datum/symptom/insomnia())

	insomnia.on_stage_change(insomnia_disease)
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_SLEEPIMMUNE), "Insomnia at stage 4 should make the host un-sleepable")
	insomnia.End(insomnia_disease)
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_SLEEPIMMUNE), "sleep immunity leaked past Insomnia's End()")

	// ---- Muscular Dexterity -----------------------------------------------------------------
	var/datum/disease/advance/dexterity_disease = new()
	var/datum/symptom/actionspd/dexterity = attach(dexterity_disease, patient, new /datum/symptom/actionspd())
	// Thresholds are met as if the disease had been built for them; the grant/cleanup path is what
	// is under test here, not the property arithmetic.
	dexterity.buffed = TRUE
	dexterity.bodycarryspd = TRUE
	dexterity.surgeryspd = TRUE
	dexterity.constructspd = TRUE

	dexterity.on_stage_change(dexterity_disease)
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_QUICKER_CARRY), "Muscular Dexterity should speed up carrying")
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_FASTMED), "Muscular Dexterity should speed up surgery")
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_QUICK_BUILD), "Muscular Dexterity should speed up construction")
	TEST_ASSERT(patient.has_movespeed_modifier(/datum/movespeed_modifier/viro_dexterity), "Muscular Dexterity should grant its movement buff")
	TEST_ASSERT(!patient.has_actionspeed_modifier(/datum/actionspeed_modifier/diseasestim), "the unbuffed action speed modifier should not be applied when the repair threshold is met")
	TEST_ASSERT(patient.has_actionspeed_modifier(/datum/actionspeed_modifier/diseasestimbuffed), "the buffed action speed modifier is missing")

	dexterity.End(dexterity_disease)
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_QUICKER_CARRY), "carry speed leaked past Muscular Dexterity's End()")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_FASTMED), "surgery speed leaked past Muscular Dexterity's End()")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_QUICK_BUILD), "construction speed leaked past Muscular Dexterity's End()")
	TEST_ASSERT(!patient.has_movespeed_modifier(/datum/movespeed_modifier/viro_dexterity), "the movement buff leaked past Muscular Dexterity's End()")
	TEST_ASSERT(!patient.has_actionspeed_modifier(/datum/actionspeed_modifier/diseasestimbuffed), "the buffed action speed modifier leaked past Muscular Dexterity's End()")

	// ---- Beneficial DNA Activator ------------------------------------------------------------
	// Its End() undoes the mutations it handed out; the port dropped the PR's mutadone-proofing,
	// so this asserts the plain call still runs without erroring on the local signature.
	var/datum/disease/advance/mutation_disease = new()
	var/datum/symptom/good_genetic_mutation/mutation = attach(mutation_disease, patient, new /datum/symptom/good_genetic_mutation())
	mutation.Activate(mutation_disease)
	mutation.End(mutation_disease)
	TEST_ASSERT(patient.has_dna(), "the mutant test host should still have DNA after the mutation symptom ended")
