/**
 * # Voidcrew drug lab validator tests
 *
 * The catalyst and crystallizer minigames are CLIENT-RUN: the TGUI window
 * plays the chart in real time and reports totals, and the server's only
 * defense is the pure validators in lab_session.dm, so those must reject
 * every implausible report shape. Locks down, against a fixed-seed recipe's
 * real charts:
 *
 * 1. Legit results pass and score correctly (perfect run = 100, all-goods
 *    catalyst = 60, full pure catch = 100, tainted penalty math).
 * 2. Count tampering is rejected: totals not matching the chart, negative
 *    counts, non-integers, malformed (null) counts, catches exceeding what
 *    the table actually spawned.
 * 3. The wall-time floor holds: a finish reported faster than the chart
 *    could physically play out (started_at = now) is rejected.
 */
/datum/unit_test/voidcrew_drug_lab

/datum/unit_test/voidcrew_drug_lab/Run()
	var/datum/drug_recipe/recipe = new
	recipe.seed = 24601
	var/list/chart = recipe.build_catalyst_chart()
	var/list/table = recipe.build_crystallizer_table()
	var/note_count = length(chart)
	// Comfortably past any chart's span (~48s), so only the shape checks bite
	var/started_long_ago = world.time - (10 MINUTES)

	// --- Catalyst: legit results and score math ---
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, note_count, 0, 0, started_long_ago), 100, "all-perfect catalyst run should validate at 100")
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, 0, note_count, 0, started_long_ago), 60, "all-goods catalyst run should validate at 60")
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, 0, 0, note_count, started_long_ago), 0, "all-miss catalyst run should validate at 0")

	// --- Catalyst: tampering rejected ---
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, note_count, 1, 0, started_long_ago), -1, "catalyst count total exceeding the chart should be rejected")
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, note_count - 1, 0, 0, started_long_ago), -1, "catalyst count total under the chart should be rejected")
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, note_count + 1, 0, -1, started_long_ago), -1, "negative catalyst miss count should be rejected")
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, note_count - 0.5, 0.5, 0, started_long_ago), -1, "non-integer catalyst counts should be rejected")
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, null, null, null, started_long_ago), -1, "null catalyst counts should be rejected")
	TEST_ASSERT_EQUAL(validate_catalyst_result(list(), note_count, 0, 0, started_long_ago), -1, "empty catalyst chart should be rejected")

	// --- Catalyst: wall-time floor ---
	TEST_ASSERT_EQUAL(validate_catalyst_result(chart, note_count, 0, 0, world.time), -1, "catalyst finish reported instantly should be rejected")

	// --- Crystallizer: legit results and score math (table is 35 pure / 15 tainted) ---
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 35, 0, 0, started_long_ago), 100, "full pure catch with no tainted should validate at 100")
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 35, 2, 0, started_long_ago), 80, "full pure catch with 2 tainted should validate at 80")
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 0, 0, 35, started_long_ago), 0, "catching nothing should validate at 0")
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 1, 15, 34, started_long_ago), 0, "tainted penalty must clamp the score at 0, not go negative")

	// --- Crystallizer: tampering rejected ---
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 36, 0, 0, started_long_ago), -1, "caught_pure over the table's pure count should be rejected")
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 35, 0, 1, started_long_ago), -1, "pure totals over the table's pure count should be rejected")
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 36, 0, -1, started_long_ago), -1, "negative missed_pure should be rejected")
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 35, 16, 0, started_long_ago), -1, "caught_tainted over the table's tainted count should be rejected")
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, null, null, null, started_long_ago), -1, "null crystallizer counts should be rejected")

	// --- Crystallizer: wall-time floor ---
	TEST_ASSERT_EQUAL(validate_crystallizer_result(table, 35, 0, 0, world.time), -1, "crystallizer finish reported instantly should be rejected")

	qdel(recipe)
