/**
 * # Voidcrew virology: Regenerative Coma, retuned
 *
 * Level 8 -> 11 comes from the ported re-tier (voidcrew/edits/diseases/symptoms/heal.dm). THIS
 * file is the behavioural half: what the symptom actually does when it fires.
 *
 * ## The problem with upstream's trigger
 *
 * `CanHeal()` heals while you are down (UNCONSCIOUS/HARD_CRIT get `power * 0.9`, SOFT_CRIT gets
 * `power * 0.5`) and only *then* checked whether to put you in the coma - so the arming clause
 * could only ever run while the host was still fully CONSCIOUS, since every other state had
 * already returned. Combined with its `brute + burn >= 70` gate, the effect was: you are standing,
 * you take about seventy damage, and six seconds later you are in a thirty second `fakedeath`
 * coma that heals you back up. Trying to run from someone stabbing you was a great way to get
 * immobilised while they finished the job. That is the "universally hated" part the ported PR's
 * own description complains about.
 *
 * ## What it does now
 *
 * The coma arms when the host has actually gone down, not at a damage figure:
 *   - SOFT_CRIT arms it, and the two second delay (COMA_TRIGGER_DELAY) means you fight on, or get
 *     dragged, or get healed out of it before the coma takes hold.
 *   - HARD_CRIT arms it too, because a single large hit can skip soft crit entirely.
 *   - UNCONSCIOUS deliberately does NOT arm it. Being stunned or knocked out while healthy is not
 *     a reason to hand someone a thirty second resurrection coma.
 *
 * If the host is healed clear of crit during the arming delay the coma is simply cancelled - the
 * rescue is no longer needed - and `End()` now actually ends the fakedeath (see the bug note below).
 *
 * ## TRAIT_NOHARDCRIT replaces the ported PR's orphan reagent
 *
 * The PR shipped `/datum/reagent/antihardcrit` ("Conscience Stabilizers"), whose only effect was
 * to grant TRAIT_NOHARDCRIT, and nothing in the game ever created it. Its effect was worth
 * keeping, so it is granted here instead - in the same `on_stage_change()` that already grades
 * TRAIT_NOCRITDAMAGE at the Resistance 4 threshold, and removed in the same places. While the
 * host is at stage 4+ with that threshold met, being critically injured keeps them in soft crit
 * rather than tipping into hard crit - which matters here specifically because Voidcrew lets crew
 * act, crawl and use items in soft crit (see the ported MonkeStation soft-crit item use), so this
 * is the difference between "wrecked but still playing" and "helpless".
 *
 * ## Bug fixed on the way in
 *
 * Upstream's `End()` called `uncoma()` with no argument while the proc is
 * `uncoma(mob/living/M)` - the missing arg is null, `uncoma()` bails out on `QDELETED(M)` and
 * returns BEFORE clearing `active_coma`, so curing a comatose host left them in a permanent
 * fakedeath. The call now passes the affected mob.
 *
 * ## Override syntax, for whoever edits this next
 *
 * `arm_coma` is a NEW proc, so it is declared as `/datum/symptom/heal/coma/proc/arm_coma()`. The
 * other four REPLACE upstream procs, so they are written without the `/proc/` segment -
 * `/datum/symptom/heal/coma/coma()`. BYOND treats `Type/proc/name()` as a declaration (which
 * errors with "duplicate definition" if the proc already exists) and `Type/name()` as an
 * override. Same rule for vars: overriding an inherited var means a bare `name = value` with no
 * `var/`. This is the convention the rest of voidcrew/edits/ follows, and it is not optional.
 *
 * Everything else - heal amount, the 30 second duration, the Stealth 2 deathgasp and the
 * Stage Speed 7 power bonus - is upstream's, unchanged.
 */
#define COMA_TRIGGER_DELAY (2 SECONDS)
#define REGENERATIVE_COMA_DURATION (30 SECONDS)

/datum/symptom/heal/coma
	threshold_descs = list(
		"Stealth 2" = "Host appears to die when falling into a coma.",
		"Resistance 4" = "The virus also stabilizes the host while they are in critical condition, and keeps them out of hard crit.",
		"Stage Speed 7" = "Increases healing speed.",
	)

/// Puts the host into a regenerative coma after a short delay, unless they are already in one or
/// cannot enter soft crit at all. Returns TRUE if this call armed the timer.
/datum/symptom/heal/coma/proc/arm_coma(mob/living/M)
	if(active_coma || HAS_TRAIT(M, TRAIT_NOSOFTCRIT))
		return FALSE
	to_chat(M, span_warning("You feel yourself slip into a regenerative coma..."))
	active_coma = TRUE
	addtimer(CALLBACK(src, PROC_REF(coma), M), COMA_TRIGGER_DELAY)
	return TRUE

/datum/symptom/heal/coma/CanHeal(datum/disease/advance/A)
	var/mob/living/M = A.affected_mob
	if(HAS_TRAIT(M, TRAIT_DEATHCOMA))
		return power
	if(M.IsSleeping())
		return power * 0.25 //Voluntary unconsciousness yields lower healing.
	switch(M.stat)
		if(UNCONSCIOUS)
			return power * 0.9
		if(HARD_CRIT)
			arm_coma(M)
			return power * 0.9
		if(SOFT_CRIT)
			arm_coma(M)
			return power * 0.5

/datum/symptom/heal/coma/coma(mob/living/M)
	if(QDELETED(M) || M.stat == DEAD)
		return
	if(M.stat == CONSCIOUS)
		// Healed clear of crit during the arming delay, so the rescue is moot - and starting a
		// thirty second fakedeath on a healthy crew member would be its own kind of griefing.
		active_coma = FALSE
		return
	M.fakedeath("regenerative_coma", !deathgasp)
	addtimer(CALLBACK(src, PROC_REF(uncoma), M), REGENERATIVE_COMA_DURATION)

/datum/symptom/heal/coma/on_stage_change(datum/disease/advance/A)
	. = ..()
	if(!.)
		return FALSE
	if(A.stage >= 4 && stabilize)
		ADD_TRAIT(A.affected_mob, TRAIT_NOCRITDAMAGE, DISEASE_TRAIT)
		ADD_TRAIT(A.affected_mob, TRAIT_NOHARDCRIT, DISEASE_TRAIT)
	else
		REMOVE_TRAIT(A.affected_mob, TRAIT_NOCRITDAMAGE, DISEASE_TRAIT)
		REMOVE_TRAIT(A.affected_mob, TRAIT_NOHARDCRIT, DISEASE_TRAIT)
	return TRUE

/datum/symptom/heal/coma/End(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	if(active_coma)
		uncoma(A.affected_mob) //passed explicitly: upstream's no-arg call was a silent no-op
	REMOVE_TRAIT(A.affected_mob, TRAIT_NOCRITDAMAGE, DISEASE_TRAIT)
	REMOVE_TRAIT(A.affected_mob, TRAIT_NOHARDCRIT, DISEASE_TRAIT)

#undef COMA_TRIGGER_DELAY
#undef REGENERATIVE_COMA_DURATION
