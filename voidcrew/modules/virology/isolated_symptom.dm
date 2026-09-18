/**
 * # Isolated Symptom
 *
 * Ported from tgstation #84356 / #89062 (hyperjll). The payload of
 * `/obj/item/reagent_containers/cup/bottle/random_symptom` (voidcrew/modules/virology/bottles.dm):
 * a virus carrying one randomly chosen symptom, which a doctor cultures and then strips for parts.
 * It is the rework's answer to "the ladder is a slot machine" - a free roll on the symptom table
 * that costs fridge access or a vendor trip instead of a chemistry chain.
 *
 * ## What it rolls
 *
 * Candidates are every `/datum/symptom` subtype that is actually obtainable (level > 0) and within
 * `max_level`, which defaults to 12 - i.e. everything, including the level-12 symptoms this port
 * adds. One symptom per bottle, because the point is an isolated symptom, not a random virus
 * (that already exists as `/datum/disease/advance/random`, the "experimental disease" bottle).
 *
 * ## Deviations from the ported copy
 *
 * 1. The ported `New()` defaulted `max_symptoms` with `rand(1, 1)`, which is always 1. It is a
 *    plain `1` here. Same behaviour, just not written as a no-op range.
 * 2. The ported copy filtered on `initial(S.naturally_occuring)` and never consulted
 *    `can_generate_randomly()`, the hook whose entire purpose is letting a symptom opt out of
 *    random generation in a specific round context - `heal/radiation` uses it to exclude itself
 *    during a radioactive nebula, a round type where a radiation-healing virus would quietly
 *    defuse the station trait. Upstream's sibling preset (`/datum/disease/advance/random`) skips
 *    the hook too, so this is a deliberate divergence from BOTH, not a fix carried over: a bottle
 *    bought from a vendor should respect the same exclusions as any other random generation.
 *
 * The filtering therefore instantiates each candidate, asks it, and keeps the instance rather
 * than discarding and re-creating it; anything left unpicked is qdeleted so a bottle cannot leak
 * symptom datums. `/datum/symptom/New()` assigns each symptom its subsystem ID and CRASHes if the
 * type is unknown, so every candidate must come from `subtypesof()` (which is exactly what
 * `SSdisease.list_symptoms` is built from).
 */
/datum/disease/advance/isolatedsymptom
	name = "Isolated Symptom"
	copy_type = /datum/disease/advance

/datum/disease/advance/isolatedsymptom/New(max_symptoms = 1, max_level = 12)
	if(!max_symptoms)
		max_symptoms = 1
	var/list/datum/symptom/possible_symptoms = list()
	for(var/symptom in subtypesof(/datum/symptom))
		var/datum/symptom/candidate = symptom
		if(initial(candidate.level) > max_level)
			continue
		if(initial(candidate.level) <= 0) //unobtainable symptoms
			continue
		var/datum/symptom/instantiated = new symptom
		if(!instantiated.can_generate_randomly())
			qdel(instantiated)
			continue
		possible_symptoms += instantiated
	for(var/i in 1 to max_symptoms)
		var/datum/symptom/chosen_symptom = pick_n_take(possible_symptoms)
		if(chosen_symptom)
			symptoms += chosen_symptom
	for(var/datum/symptom/unchosen in possible_symptoms)
		qdel(unchosen)
	Refresh()

	name = "Isolated Symptom #[rand(1,100)]"
