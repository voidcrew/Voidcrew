/**
 * The outpost's takings (outpost_market.dm): a charge, the prison wing's pay and cargo exports all
 * land in the ledger and the totals by source, and the last hour adds them up. Voidcrew defines are
 * not visible from test files, so the source keys are spelled out.
 */
/datum/unit_test/voidcrew_outpost_income
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_income/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(__IMPLIED_TYPE__)
	home.founder_ckey = "incomeowner"
	home.ensure_home_services()
	var/mob/living/carbon/human/owner = make_player(run_loc_floor_bottom_left, "incomeowner")

	// Already in the treasury: the takings only record them
	home.record_income("prison", "Prison wing stipend", 120) // OUTPOST_INCOME_PRISON
	home.record_income("exports", "Exports: 3 crates", 45) // OUTPOST_INCOME_EXPORTS
	home.record_income("prison", "Prison release", 30)
	home.record_income("prison", "Nothing", 0)

	var/list/pricing = home.pricing_ui_data(owner, TRUE)
	TEST_ASSERT_EQUAL(pricing["last_hour"], 195, "The last hour does not add up every kind of income")
	var/prison_total = 0
	var/exports_total = 0
	for(var/list/total as anything in pricing["totals"])
		if(total["label"] == "Prison wing")
			prison_total = total["total"]
		else if(total["label"] == "Exports")
			exports_total = total["total"]
	TEST_ASSERT_EQUAL(prison_total, 150, "The prison wing's pay is not in the takings")
	TEST_ASSERT_EQUAL(exports_total, 45, "Exports are not in the takings")
	TEST_ASSERT_EQUAL(length(pricing["ledger"]), 3, "The ledger does not hold each payment once")

	// Income from over an hour ago leaves the last hour, not the totals
	home.recent_income.Insert(1, null)
	home.recent_income[1] = list(world.time - 61 MINUTES, 1000)
	TEST_ASSERT_EQUAL(home.recent_income_total(), 195, "Income from over an hour ago still counts in the last hour")

	TEST_ASSERT_NULL(home.pricing_ui_data(owner, FALSE)["last_hour"], "The last hour is shown without income access")
