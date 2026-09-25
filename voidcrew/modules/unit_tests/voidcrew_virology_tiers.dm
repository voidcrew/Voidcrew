/**
 * The ported virology re-tier holds three invariants that no single file states on its own, and
 * each of them was broken at least once by hand while the port was being written:
 *
 * 1. The symptom cap and the beneficial self-cure lever match the ported PR (8, and INFINITY).
 * 2. Every symptom sits at the level the re-tier table says. A wrong `level` is invisible in play
 *    until somebody evolves into the wrong thing, so the whole table is asserted rather than
 *    spot-checked.
 * 3. The cure ladder and the evolution path agree with each other: twelve tiers, no reagent in
 *    two tiers, one virus food per level, and the mix_virus_N numbering matching its level.
 *
 * Nothing here needs a mob; it is all compile-time data, so a failure means the port drifted.
 */
/datum/unit_test/voidcrew_virology_tiers

/// Level table from tgstation #84356 / #89062, as applied in voidcrew/edits/diseases/symptoms/.
/datum/unit_test/voidcrew_virology_tiers/proc/expected_levels()
	return list(
		/datum/symptom/choking = 2,
		/datum/symptom/asphyxiation = 9,
		/datum/symptom/fire = 8,
		/datum/symptom/alkali = 11,
		/datum/symptom/flesh_eating = 7,
		/datum/symptom/flesh_death = 10,
		/datum/symptom/genetic_mutation = 7,
		/datum/symptom/heal/starlight = 9,
		/datum/symptom/heal/chem = 10,
		/datum/symptom/heal/metabolism = 10,
		/datum/symptom/heal/darkness = 8,
		/datum/symptom/heal/coma = 11,
		/datum/symptom/heal/water = 9,
		/datum/symptom/heal/plasma = 10,
		/datum/symptom/heal/radiation = 8,
		/datum/symptom/narcolepsy = 7,
		/datum/symptom/mind_restoration = 6,
		/datum/symptom/sensory_restoration = 5,
		/datum/symptom/shedding = 3,
		/datum/symptom/polyvitiligo = 7,
		/datum/symptom/undead_adaptation = 6,
		/datum/symptom/inorganic_adaptation = 6,
		/datum/symptom/visionloss = 6,
		/datum/symptom/voice_change = 9,
		/datum/symptom/vomit = 2,
	)

/datum/unit_test/voidcrew_virology_tiers/Run()
	TEST_ASSERT_EQUAL(VIRUS_SYMPTOM_LIMIT, 8, "the ported symptom cap did not land")
	TEST_ASSERT_EQUAL(DISEASE_CYCLES_POSITIVE, INFINITY, "beneficial viruses can self-cure again")

	var/list/levels = expected_levels()
	for(var/symptom_type in levels)
		var/datum/symptom/S = symptom_type
		TEST_ASSERT_EQUAL(initial(S.level), levels[symptom_type], "[symptom_type] sits at the wrong level")

	// Necrotic Metabolism's stat buff is the only non-level change in the whole re-tier.
	var/datum/symptom/undead_adaptation/undead = /datum/symptom/undead_adaptation
	TEST_ASSERT_EQUAL(initial(undead.stealth), 1, "Necrotic Metabolism's stealth buff is missing")
	TEST_ASSERT_EQUAL(initial(undead.resistance), 1, "Necrotic Metabolism's resistance buff is missing")
	TEST_ASSERT_EQUAL(initial(undead.transmittable), 1, "Necrotic Metabolism's transmittable buff is missing")

	// The cure ladder: twelve tiers, and no reagent doing duty in two of them. `advance_cures` is
	// static, so reading it through an instance is how the game itself sees it.
	var/datum/disease/advance/disease = new()
	var/list/tiers = disease.advance_cures
	TEST_ASSERT_EQUAL(length(tiers), 12, "the cure ladder should run to twelve tiers")
	var/list/seen_reagents = list()
	for(var/level in 1 to length(tiers))
		var/list/tier = tiers[level]
		TEST_ASSERT(length(tier), "cure tier [level] is empty")
		for(var/reagent in tier)
			TEST_ASSERT(!seen_reagents[reagent], "[reagent] is a cure for tier [seen_reagents[reagent]] and tier [level]")
			seen_reagents[reagent] = level
	qdel(disease)

	// The evolution path: one food per level, and mix_virus_N's number is its level.
	var/datum/chemical_reaction/mix_virus/base = /datum/chemical_reaction/mix_virus
	TEST_ASSERT_EQUAL(initial(base.level_max), 1, "plain virus food should only be the level-1 step")
	var/list/seen_foods = list()
	for(var/level in 2 to 12)
		var/reaction_type = text2path("/datum/chemical_reaction/mix_virus/mix_virus_[level]")
		TEST_ASSERT_NOTNULL(reaction_type, "no mix_virus reaction exists for level [level]")
		var/datum/chemical_reaction/mix_virus/reaction = reaction_type
		TEST_ASSERT_EQUAL(initial(reaction.level_min), level, "mix_virus_[level] does not start at level [level]")
		TEST_ASSERT_EQUAL(initial(reaction.level_max), level, "mix_virus_[level] does not end at level [level]")
		for(var/food in initial(reaction.required_reagents))
			TEST_ASSERT(!seen_foods[food], "[food] evolves to level [seen_foods[food]] and to level [level]")
			seen_foods[food] = level
