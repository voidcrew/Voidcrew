/// Round metrics queue rows in memory with the table's columns, fold tallies into one row per key,
/// and drop the oldest rows past the cap. No database is involved: the test world has none.
/// Categories are written as strings: unit tests are included before voidcrew/_DEFINES/metrics.dm.
/datum/unit_test/voidcrew_round_metrics
	var/was_accepting
	var/was_max_pending
	var/list/old_pending
	var/list/old_tallies

/datum/unit_test/voidcrew_round_metrics/Run()
	was_accepting = SSmetrics.accepting
	was_max_pending = SSmetrics.max_pending
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = TRUE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

	record_metric("trade", "test_purchase", ckey = "tester", other_ckey = "seller", zone = "red", subject = /obj/item/gun, credits = -500, vouchers = -2, quantity = 1, details = list("shop" = "Test Shop"))
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "record_metric should queue exactly one row")
	var/list/row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["category"], "trade", "category column")
	TEST_ASSERT_EQUAL(row["event"], "test_purchase", "event column")
	TEST_ASSERT_EQUAL(row["ckey"], "tester", "ckey column")
	TEST_ASSERT_EQUAL(row["other_ckey"], "seller", "other_ckey column")
	TEST_ASSERT_EQUAL(row["zone"], "red", "zone column")
	TEST_ASSERT_EQUAL(row["subject"], "/obj/item/gun", "typepath subjects are stored as text")
	TEST_ASSERT_EQUAL(row["credits"], -500, "spending is negative credits")
	TEST_ASSERT_EQUAL(row["vouchers"], -2, "vouchers column")
	TEST_ASSERT_EQUAL(row["details"], json_encode(list("shop" = "Test Shop")), "details are stored as JSON")
	TEST_ASSERT_NULL(row["ship_id"], "no ship was given")

	for(var/i in 1 to 3)
		tally_metric("combat", "test_hit", ckey = "a", other_ckey = "b", zone = "yellow", subject = "laser", points = 10)
	tally_metric("combat", "test_hit", ckey = "a", other_ckey = "c", zone = "yellow", subject = "laser", points = 10)
	TEST_ASSERT_EQUAL(length(SSmetrics.tallies), 2, "tallies with different players are kept apart")
	SSmetrics.fold_tallies()
	TEST_ASSERT_EQUAL(length(SSmetrics.tallies), 0, "folding clears the running totals")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 3, "each tally key becomes one row")
	var/list/folded = SSmetrics.pending[2]
	TEST_ASSERT_EQUAL(folded["quantity"], 3, "tally quantity is summed")
	TEST_ASSERT_EQUAL(folded["points"], 30, "tally points are summed")

	SSmetrics.pending = list()
	SSmetrics.max_pending = 3
	var/dropped_before = SSmetrics.rows_dropped
	for(var/i in 1 to 5)
		record_metric("economy", "test_cap", quantity = i)
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 3, "the queue holds at most max_pending rows")
	TEST_ASSERT_EQUAL(SSmetrics.rows_dropped - dropped_before, 2, "overflow counts as dropped")
	var/list/oldest_kept = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(oldest_kept["quantity"], 3, "the oldest rows are the ones dropped")

	SSmetrics.accepting = FALSE
	SSmetrics.pending = list()
	record_metric("economy", "test_off")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 0, "nothing is queued while metrics are off")

/datum/unit_test/voidcrew_round_metrics/Destroy()
	SSmetrics.accepting = was_accepting
	SSmetrics.max_pending = was_max_pending
	SSmetrics.pending = old_pending
	SSmetrics.tallies = old_tallies
	return ..()
