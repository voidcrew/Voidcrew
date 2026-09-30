/**
 * # Voidcrew drug recipe tests
 *
 * The smuggling lab rebuilds its minigame charts from the recipe seed on
 * demand (server and TGUI client both), so the recipe's private PRNG must be
 * fully deterministic and the charts must honor the timing contracts the JS
 * clients assume. Locks down:
 *
 * 1. Determinism: same seed + same biome list => identical ingredients,
 *    mixer sequences, catalyst chart and crystallizer table, including
 *    re-deriving a chart twice from the same recipe.
 * 2. Distinctness: a generated recipe spans 3 distinct biomes and 3 distinct
 *    ingredient types.
 * 3. Chart contracts: note counts, lane/column ranges, ascending times,
 *    minimum gaps (overall and per-lane), exact pure/tainted split.
 * 4. Graceful failure: generate() returns FALSE with too few biomes present.
 */
/datum/unit_test/voidcrew_drug_recipe

/datum/unit_test/voidcrew_drug_recipe/Run()
	var/list/all_biomes = list(
		/datum/overmap/planet/jungle,
		/datum/overmap/planet/lava,
		/datum/overmap/planet/ice,
		/datum/overmap/planet/beach,
		/datum/overmap/planet/wasteland,
	)

	// graceful failure: two biomes can't source a three-part formula
	var/datum/drug_recipe/starved = new
	TEST_ASSERT(!starved.generate(list(/datum/overmap/planet/jungle, /datum/overmap/planet/lava)), "generate() with only 2 biomes present should return FALSE")
	qdel(starved)

	// determinism: same seed, same biome list => identical everything
	var/datum/drug_recipe/alpha = new
	var/datum/drug_recipe/beta = new
	alpha.seed = 24601
	beta.seed = 24601
	alpha.roll_recipe(all_biomes)
	beta.roll_recipe(all_biomes)
	TEST_ASSERT_EQUAL(alpha.street_name, beta.street_name, "same seed produced different street names")
	TEST_ASSERT_EQUAL(json_encode(alpha.ingredients), json_encode(beta.ingredients), "same seed produced different ingredient sets")
	TEST_ASSERT_EQUAL(json_encode(alpha.build_catalyst_chart()), json_encode(beta.build_catalyst_chart()), "same seed produced different catalyst charts")
	TEST_ASSERT_EQUAL(json_encode(alpha.build_crystallizer_table()), json_encode(beta.build_crystallizer_table()), "same seed produced different crystallizer tables")
	// charts must also be stable when re-derived from the same recipe
	TEST_ASSERT_EQUAL(json_encode(alpha.build_catalyst_chart()), json_encode(alpha.build_catalyst_chart()), "re-derived catalyst chart differs from itself")

	// mixer sequences: deterministic, correct length, hoppers in range
	for(var/round_num in 1 to 5)
		var/list/sequence = alpha.build_mixer_sequence(round_num)
		TEST_ASSERT_EQUAL(json_encode(sequence), json_encode(beta.build_mixer_sequence(round_num)), "same seed produced different mixer sequences (round [round_num])")
		TEST_ASSERT_EQUAL(length(sequence), 3 + round_num, "mixer round [round_num] sequence has the wrong length")
		for(var/hopper in sequence)
			// Literal 4 = DRUG_MIXER_HOPPER_COUNT; unit tests compile before voidcrew/_DEFINES
			TEST_ASSERT(hopper >= 1 && hopper <= 4, "mixer round [round_num] rolled out-of-range hopper [hopper]")

	// catalyst chart contract
	var/list/chart = alpha.build_catalyst_chart()
	TEST_ASSERT(length(chart) >= 40 && length(chart) <= 60, "catalyst chart has [length(chart)] notes, expected 40-60")
	var/last_note_t = -1
	var/list/lane_last = list(-1000, -1000, -1000, -1000)
	for(var/list/note in chart)
		var/lane = note["lane"]
		var/note_t = note["t"]
		// Literal 4 = DRUG_CATALYST_LANE_COUNT; unit tests compile before voidcrew/_DEFINES
		TEST_ASSERT(lane >= 1 && lane <= 4, "catalyst note has out-of-range lane [lane]")
		if(last_note_t >= 0)
			TEST_ASSERT(note_t - last_note_t >= 120, "catalyst notes at [last_note_t]ms and [note_t]ms are closer than 120ms")
		TEST_ASSERT(note_t - lane_last[lane] >= 350, "catalyst lane [lane] notes at [lane_last[lane]]ms and [note_t]ms are closer than 350ms")
		lane_last[lane] = note_t
		last_note_t = note_t

	// crystallizer table contract
	var/list/table = alpha.build_crystallizer_table()
	var/pure_count = 0
	var/tainted_count = 0
	var/last_entry_t = -1
	for(var/list/entry in table)
		var/col = entry["col"]
		var/entry_t = entry["t"]
		// Literal 5 = DRUG_CRYSTALLIZER_COL_COUNT; unit tests compile before voidcrew/_DEFINES
		TEST_ASSERT(col >= 1 && col <= 5, "crystallizer entry has out-of-range column [col]")
		if(last_entry_t >= 0)
			TEST_ASSERT(entry_t - last_entry_t >= 250, "crystallizer entries at [last_entry_t]ms and [entry_t]ms are closer than 250ms")
		last_entry_t = entry_t
		if(entry["tainted"])
			tainted_count++
		else
			pure_count++
	TEST_ASSERT_EQUAL(pure_count, 35, "crystallizer table pure count is off")
	TEST_ASSERT_EQUAL(tainted_count, 15, "crystallizer table tainted count is off")
	qdel(alpha)
	qdel(beta)

	// distinctness: a full generate() must span 3 different biomes/ingredients
	var/datum/drug_recipe/rolled = new
	TEST_ASSERT(rolled.generate(all_biomes), "generate() with all 5 biomes present should succeed")
	TEST_ASSERT_EQUAL(length(rolled.ingredients), 3, "generated recipe has the wrong ingredient count")
	var/list/seen_biomes = list()
	var/list/seen_types = list()
	for(var/list/ingredient in rolled.ingredients)
		TEST_ASSERT(ispath(ingredient["type"], /obj/item/drug_ingredient), "generated ingredient [ingredient["type"]] is not a drug ingredient path")
		seen_biomes |= ingredient["biome"]
		seen_types |= ingredient["type"]
	TEST_ASSERT_EQUAL(length(seen_biomes), 3, "generated recipe repeated a biome")
	TEST_ASSERT_EQUAL(length(seen_types), 3, "generated recipe repeated an ingredient type")
	qdel(rolled)
