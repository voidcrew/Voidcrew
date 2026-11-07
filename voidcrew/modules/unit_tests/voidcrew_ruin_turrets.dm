/// Exercise the wreck's real crowbar path without a timed action.
/obj/item/crowbar/ruin_turret_test
	var/salvage_uses = 0

/obj/item/crowbar/ruin_turret_test/use_tool(atom/target, mob/living/user, delay, amount = 0, volume = 0, datum/callback/extra_checks)
	salvage_uses++
	return TRUE

/datum/unit_test/voidcrew_ruin_turret_salvage/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/crowbar/ruin_turret_test/crowbar = allocate(__IMPLIED_TYPE__)
	for(var/turret_type in list(/obj/machinery/porta_turret/ruin, /obj/machinery/porta_turret/ai/ruin))
		var/obj/machinery/porta_turret/turret = allocate(turret_type, run_loc_floor_bottom_left)
		TEST_ASSERT_NULL(turret.stored_gun, "[turret_type] retained a salvageable gun")
		turret.deconstruct(TRUE)
		TEST_ASSERT(QDELETED(turret), "[turret_type] was not deconstructed")
		TEST_ASSERT_NULL(locate(/obj/item/gun) in run_loc_floor_bottom_left, "Deconstructing [turret_type] released a gun")

		turret = allocate(turret_type, run_loc_floor_bottom_left)
		turret.on = FALSE
		turret.set_machine_stat(turret.machine_stat | BROKEN)
		var/previous_uses = crowbar.salvage_uses
		turret.attackby(crowbar, user, list(), list())
		TEST_ASSERT_EQUAL(crowbar.salvage_uses, previous_uses + 1, "[turret_type] did not reach crowbar salvage")
		TEST_ASSERT(QDELETED(turret), "Salvaging [turret_type] left the wreck behind")
		TEST_ASSERT_NULL(locate(/obj/item/gun) in run_loc_floor_bottom_left, "Salvaging [turret_type] released a gun")

/datum/unit_test/voidcrew_ruin_turret_firing/Run()
	var/list/variants = list(
		/obj/machinery/porta_turret/ruin = /obj/machinery/porta_turret,
		/obj/machinery/porta_turret/ai/ruin = /obj/machinery/porta_turret/ai,
	)
	for(var/ruin_type in variants)
		var/obj/machinery/porta_turret/ruin_turret = allocate(ruin_type, run_loc_floor_bottom_left)
		var/obj/machinery/porta_turret/original_turret = allocate(variants[ruin_type], get_step(run_loc_floor_bottom_left, EAST))
		ruin_turret.on = FALSE
		original_turret.on = FALSE
		if(ruin_type == /obj/machinery/porta_turret/ruin)
			original_turret.setup(allocate(/obj/item/gun/energy/lasercannon))
		for(var/property in list("stun_projectile", "lethal_projectile", "stun_projectile_sound", "lethal_projectile_sound", "base_icon_state", "shot_delay", "reqpower", "scan_range", "turret_flags", "mode"))
			TEST_ASSERT_EQUAL(ruin_turret.vars[property], original_turret.vars[property], "[ruin_type] changed [property]")
		TEST_ASSERT(!ruin_turret.uses_stored, "[ruin_type] still requires its discarded gun to fire")
		TEST_ASSERT_NULL(ruin_turret.stored_gun, "[ruin_type] retained a physical gun after setup")
		TEST_ASSERT_NOTNULL(original_turret.stored_gun, "[variants[ruin_type]] lost its original gun")
