/// Pins the restored per-second magnitudes of the fork's REM-derived reagent effects.
/// Every site in voidcrew/modules/chemistry/ was authored against the pre-upgrade REM
/// (0.5) and silently became 5x when upstream redefined REM to 2.5. Nothing about that
/// change was a compile error, which is why this test exists.
/datum/unit_test/voidcrew_rem_restoration

/// Mirrors /datum/reagents/proc/metabolize_reagent's ratio math exactly.
/datum/unit_test/voidcrew_rem_restoration/proc/holder_ratio(rate_multiplier, seconds_per_tick)
	return REM * (REAGENTS_METABOLISM * rate_multiplier) * seconds_per_tick

/datum/unit_test/voidcrew_rem_restoration/Run()
	// ---- SENTINEL: pin the defines. BOTH drift directions are silent breakage. ----
	// If REM GROWS: every `X * metabolization_ratio * spt` site below gets stronger with no
	//   error. This is precisely the 2026-08 regression - REM went 0.5 -> 2.5 and quintupled
	//   nine fork reagent effects across three files.
	// If REM SHRINKS (e.g. back toward 0.5): metabolization_ratio collapses toward 0.2 while
	//   the coefficients stay put, and the same nine effects go quietly WEAK instead.
	// Either way: do NOT edit code/__DEFINES/mobs.dm to make this pass - that define is
	// upstream's and rescales every upstream reagent. Re-derive the fork coefficients in
	// voidcrew/modules/chemistry/ against the new REM and update the expectations here.
	TEST_ASSERT(abs(REM - 2.5) < 0.001, "REM is [REM], expected 2.5 - fork chem coefficients must be re-derived")
	TEST_ASSERT(abs(REAGENTS_METABOLISM - 0.2) < 0.001, "REAGENTS_METABOLISM is [REAGENTS_METABOLISM], expected 0.2")
	TEST_ASSERT(abs(SSMOBS_DT - 2) < 0.001, "SSMOBS_DT is [SSMOBS_DT], expected 2 - the 2s-tick derivations in voidcrew/modules/chemistry/ are now stale")

	var/spt = 2
	var/mob/living/carbon/human/consistent/subject = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(abs(subject.metabolism_efficiency - 1) < 0.001, "test subject metabolism_efficiency is not 1; ratios below will not hold")

	// ---- Prove the ratio we feed in is the one the holder actually computes. ----
	var/datum/reagent/acetone_oxide/probe = new()
	probe.volume = 100
	var/computed = probe.compute_metabolization(subject, spt)
	TEST_ASSERT(abs(computed - 0.4) < 0.001, "compute_metabolization returned [computed], expected 0.4")
	TEST_ASSERT(abs((REM * computed) - 1) < 0.001, "default-rate metabolization_ratio is not 1.0 at a 2s tick")

	// ---- Site: reagents_other.dm - acetone_oxide, default rate, ratio 1.0. ----
	// Production (REM 0.5): 2 * 0.5 * 2 == 2.0 organ damage per 2s tick == 1.0/s.
	var/datum/reagent/acetone_oxide/dose = new()
	var/stomach_before = subject.get_organ_loss(ORGAN_SLOT_STOMACH)
	var/eyes_before = subject.get_organ_loss(ORGAN_SLOT_EYES)
	dose.on_mob_life(subject, spt, holder_ratio(1, spt))
	var/stomach_dealt = subject.get_organ_loss(ORGAN_SLOT_STOMACH) - stomach_before
	var/eyes_dealt = subject.get_organ_loss(ORGAN_SLOT_EYES) - eyes_before
	TEST_ASSERT(abs(stomach_dealt - 2) < 0.01, "acetone_oxide stomach: expected 2.0 per 2s tick (1.0/s), got [stomach_dealt]")
	TEST_ASSERT(abs(eyes_dealt - 2) < 0.01, "acetone_oxide eyes: expected 2.0 per 2s tick (1.0/s), got [eyes_dealt]")

	// ---- Site: reagents_fun.dm:102 - liquid_justice, 1.5x rate, ratio 1.5. ----
	// The one most likely to be got wrong: a naive halve-the-coefficient migration ships
	// 1.5x production here, because the ratio idiom folds metabolization_rate in.
	// Production: 2 * 0.5 * 2 == 2.0 fire stacks per 2s tick == 1.0/s (double phlogiston).
	var/mob/living/carbon/human/consistent/burner = allocate(/mob/living/carbon/human/consistent)
	burner.fire_stacks = 0
	var/datum/reagent/liquid_justice/justice = new()
	justice.on_mob_life(burner, spt, holder_ratio(1.5, spt))
	TEST_ASSERT(abs(burner.fire_stacks - 2) < 0.01, "liquid_justice: expected 2.0 fire stacks per 2s tick (1.0/s), got [burner.fire_stacks]")

	// Design invariant from reagents_fun.dm: exactly double phlogiston. Guards the
	// relationship even if both reagents are rescaled together later.
	var/mob/living/carbon/human/consistent/phlog_target = allocate(/mob/living/carbon/human/consistent)
	phlog_target.fire_stacks = 0
	var/datum/reagent/phlogiston/phlog = new()
	phlog.on_mob_life(phlog_target, spt, holder_ratio(1, spt))
	TEST_ASSERT(abs(burner.fire_stacks - (2 * phlog_target.fire_stacks)) < 0.02, "liquid_justice should be exactly double phlogiston: [burner.fire_stacks] vs [phlog_target.fire_stacks]")

	// ---- Site: reagents_drinks.dm:15 - sunset_sarsaparilla, consumable, ratio 1.0. ----
	// Production: 1.5 * 0.5 * 2 == 1.5 brute AND 1.5 burn healed per 2s tick (0.75/s each).
	// ratvander (:42/:43) is deliberately unasserted: 6 SECONDS/tick against a 6 SECONDS
	// cap saturates in one tick, so a per-tick assert cannot tell correct from 5x. The
	// define sentinel above plus the site comments are the guard there.
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	patient.take_bodypart_damage(brute = 20, burn = 20)
	var/brute_before = patient.get_brute_loss()
	var/datum/reagent/consumable/sunset_sarsaparilla/soda = new()
	soda.on_mob_life(patient, spt, holder_ratio(1, spt))
	var/healed = brute_before - patient.get_brute_loss()
	TEST_ASSERT(abs(healed - 1.5) < 0.01, "sunset_sarsaparilla brute: expected 1.5 per 2s tick (0.75/s), got [healed]")
