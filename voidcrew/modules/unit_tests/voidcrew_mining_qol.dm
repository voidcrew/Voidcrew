/// Regression guards for the mining quality-of-life changes.

/datum/unit_test/voidcrew_orm_claims_without_silo

/datum/unit_test/voidcrew_orm_claims_without_silo/Run()
	var/obj/machinery/mineral/ore_redemption/orm_type = /obj/machinery/mineral/ore_redemption
	TEST_ASSERT(!initial(orm_type.requires_silo), "An ORM must pay out mining points without an ore silo.")

/datum/unit_test/voidcrew_mining_console_quotes_its_price

/datum/unit_test/voidcrew_mining_console_quotes_its_price/Run()
	var/obj/machinery/computer/order_console/mining/console_type = /obj/machinery/computer/order_console/mining
	TEST_ASSERT_EQUAL(initial(console_type.cargo_cost_multiplier), initial(console_type.express_cost_multiplier), "The mining console must quote the price it charges.")
