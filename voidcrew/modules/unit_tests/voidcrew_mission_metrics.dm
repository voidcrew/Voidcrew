/// Mission metrics (voidcrew/modules/metrics/mission_metrics.dm): a timeout is told apart from
/// any other failure, offers nobody accepted write nothing, a mission deleted mid-run is
/// recorded as dropped, and board offers are tallied. Rows stay in memory; no database.
/// Unit tests are included before voidcrew/_DEFINES, so METRIC_MISSION and ZONE_NAME_RED are
/// written out as their values.
/datum/unit_test/voidcrew_mission_metrics
	var/was_accepting
	var/list/old_pending
	var/list/old_tallies

/datum/unit_test/voidcrew_mission_metrics/Run()
	was_accepting = SSmetrics.accepting
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = TRUE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

	// An offer that dies on the board was never taken
	var/datum/mission/offer = new
	offer.fail("Target lost.")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 0, "An offer that was never accepted should write no row")

	// The time limit running out
	var/datum/mission/expired = new
	expired.active = TRUE
	expired.time_started = world.time
	expired.metric_accepted_by = "accepter"
	expired.target_zone_name = "Lawless Zone" // ZONE_NAME_RED
	expired.on_timeout()
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "A timed-out mission should write one row")
	var/list/row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["category"], "mission", "Mission rows use the mission category")
	TEST_ASSERT_EQUAL(row["event"], "mission_expired", "A timeout should be recorded as expired")
	TEST_ASSERT_EQUAL(row["ckey"], "accepter", "A failure is credited to the player who accepted")
	TEST_ASSERT_EQUAL(row["zone"], "red", "With no live target the zone comes from the target's zone name")
	TEST_ASSERT_EQUAL(row["subject"], "[/datum/mission]", "The subject is the mission type")

	// Any other failure
	SSmetrics.pending = list()
	var/datum/mission/failed_run = new
	failed_run.active = TRUE
	failed_run.time_started = world.time
	failed_run.timeout_timer = addtimer(CALLBACK(failed_run, TYPE_PROC_REF(/datum/mission, on_timeout)), 10 MINUTES, TIMER_STOPPABLE)
	failed_run.fail("Objective lost.")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "A failed mission should write one row")
	row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["event"], "mission_failed", "A failure with time left should be recorded as failed")
	var/list/details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["reason"], "Objective lost.", "The failure reason should be kept")

	// Deleted while running, as when the crew's ship is destroyed
	SSmetrics.pending = list()
	var/datum/mission/dropped = new
	dropped.active = TRUE
	dropped.time_started = world.time
	qdel(dropped)
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "A running mission deleted without finishing should write one row")
	row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["event"], "mission_dropped", "It should be recorded as dropped")

	// Finished with no ship pays nothing, and says so
	SSmetrics.pending = list()
	var/datum/mission/unpaid = new
	unpaid.active = TRUE
	unpaid.time_started = world.time
	unpaid.value = 1000
	unpaid.voucher_count = 2
	unpaid.finish_mission(null)
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "A finished mission should write exactly one row")
	row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["event"], "mission_completed", "It should be recorded as completed")
	TEST_ASSERT_EQUAL(row["credits"], 0, "Nothing is paid without a ship")
	TEST_ASSERT_EQUAL(row["vouchers"], 0, "Nothing is paid without a ship")

	// Offers are tallied, one row per type and board a minute
	SSmetrics.pending = list()
	var/datum/mission/posted = allocate(/datum/mission)
	tally_mission_offer(posted, null, "contract_offered")
	tally_mission_offer(posted, null, "contract_offered")
	TEST_ASSERT_EQUAL(length(SSmetrics.tallies), 1, "Offers of one type on one board share a tally")
	SSmetrics.fold_tallies()
	row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["quantity"], 2, "The tally counts every offer")

/datum/unit_test/voidcrew_mission_metrics/Destroy()
	SSmetrics.accepting = was_accepting
	SSmetrics.pending = old_pending
	SSmetrics.tallies = old_tallies
	return ..()
