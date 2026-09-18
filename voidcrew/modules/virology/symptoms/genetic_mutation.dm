/**
 * # Beneficial DNA Activator
 *
 * Ported from tgstation #84356 / #89062 (hyperjll), minus its mutadone-proofing. This is the
 * beneficial mirror of /datum/symptom/genetic_mutation: instead of scrambling the host's genes it
 * wakes up dormant GOOD mutations that are already in their DNA sequence, and undoes them when
 * the virus is cured.
 *
 * ## Deliberate simplifications
 *
 * The ported version tried to make the mutations immune to mutadone at Resistance 10 and immune
 * to the cure at Resistance 16, by passing a `mutadone_proof` argument to `easy_random_mutate()`.
 * That proc has no such parameter here (code/datums/dna/dna.dm: the signature is
 * `(quality, scrambled, sequence, excluded_mutations)`), so the argument landed in
 * `excluded_mutations` and the feature never worked. The thresholds and both helper vars are
 * therefore dropped: `easy_random_mutate((POSITIVE), TRUE, TRUE)` is called directly.
 *
 * Note that this codebase DOES have a mutadone-proofing mechanism, just a different one - the
 * harmful sibling in code/datums/diseases/advance/symptoms/genetics.dm tags mutations with
 * MUTATION_SOURCE_GENE_SYMPTOM instead of MUTATION_SOURCE_ACTIVATED depending on whether the
 * host meets its threshold. `easy_random_mutate()` hardcodes MUTATION_SOURCE_ACTIVATED, so
 * restoring that behaviour would mean adding a mutation directly rather than going through that
 * helper. Not ported: one symptom's mutadone immunity is not worth that divergence from upstream,
 * and mutadone removing the mutations is a working counterplay.
 *
 * ## The cleanup is precise, not blunt
 *
 * `End()` removes mutations by SOURCE, matching the harmful sibling: the mutations this symptom
 * grants arrive tagged MUTATION_SOURCE_ACTIVATED, so injecting yourself during the infection
 * leaves your injector mutations (MUTATION_SOURCE_TIMED_INJECTOR and friends) alone. Only what
 * the symptom handed out is taken back.
 */
/datum/symptom/good_genetic_mutation
	name = "Beneficial DNA Activator"
	desc = "The virus bonds with the DNA of the host, activating random dormant beneficial mutations within their DNA to improve host survivability. When the virus is cured, the host's genetic alterations are undone."
	stealth = -4
	resistance = -3
	stage_speed = -1
	transmittable = -2
	level = 12
	base_message_chance = 50
	symptom_delay_min = 30
	symptom_delay_max = 60
	threshold_descs = list(
		"Stage Speed 10" = "The virus activates dormant mutations at a much faster rate.",
	)

/datum/symptom/good_genetic_mutation/Start(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	if(A.totalStageSpeed() >= 10)
		symptom_delay_min = 20
		symptom_delay_max = 40

/datum/symptom/good_genetic_mutation/Activate(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	var/mob/living/carbon/C = A.affected_mob
	if(!C.has_dna())
		return
	switch(A.stage)
		if(4, 5)
			to_chat(C, span_warning("[pick("Your skin feels rubbery.", "You feel a spark of energy curl up within you.")]"))
			C.easy_random_mutate((POSITIVE), TRUE, TRUE)

/datum/symptom/good_genetic_mutation/End(datum/disease/advance/A)
	. = ..()
	if(!.)
		return
	var/mob/living/carbon/M = A.affected_mob
	if(M.has_dna())
		M.dna.remove_all_mutations(list(MUTATION_SOURCE_GENE_SYMPTOM, MUTATION_SOURCE_ACTIVATED))
