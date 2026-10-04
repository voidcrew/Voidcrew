/**
 * A hull defense turret bolted to a player outpost answers to the outpost's members. A visitor
 * cannot switch it off, change its targeting, save it to a multitool, unbolt it or scrap it; a
 * member can work it. On a hull docked at the outpost it still answers to that ship's crew only.
 */
/datum/unit_test/voidcrew_outpost_turret_access
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_turret_access/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("turretowner")
	TEST_ASSERT_NOTNULL(home, "The turret test outpost did not load")
	var/turf/floor = get_turf(home.management_console)
	TEST_ASSERT_EQUAL(get_outpost_from_atom(floor), home, "The test turret's tile is not on the claim")
	var/mob/living/carbon/human/owner = make_player(floor, "turretowner")
	var/mob/living/carbon/human/visitor = make_player(floor, "turretvisitor")
	var/mob/living/carbon/human/resident = make_player(floor, "turretresident")
	home.residents |= resident.mind
	var/obj/machinery/porta_turret/ship_defense/turret = allocate(/obj/machinery/porta_turret/ship_defense, floor)
	TEST_ASSERT(turret.on && turret.anchored, "The test turret did not start switched on and bolted")
	// A coverless turret pops up just after it is built; switching it off mid-animation would leave it raised.
	var/deadline = world.time + 5 SECONDS
	UNTIL(!turret.raising || world.time > deadline)

	// A visitor can work none of it.
	TEST_ASSERT(!turret.allowed_operator(visitor), "A visitor may work an outpost's turret")
	turret.interact(visitor)
	TEST_ASSERT(turret.on, "A visitor switched an outpost's turret off")
	turret.click_alt(visitor)
	TEST_ASSERT(turret.target_wildlife, "A visitor changed an outpost turret's targeting")
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)
	turret.multitool_act(visitor, multitool)
	TEST_ASSERT_NULL(multitool.buffer, "A visitor saved an outpost's turret to a multitool")

	// Members can: a resident switches it off and retargets it, the owner unbolts it.
	TEST_ASSERT(turret.allowed_operator(owner), "The owner may not work their outpost's turret")
	turret.interact(resident)
	TEST_ASSERT(!turret.on, "A resident could not switch the outpost's turret off")
	turret.click_alt(resident)
	TEST_ASSERT(!turret.target_wildlife, "A resident could not change the outpost turret's targeting")
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	turret.attackby(wrench, visitor)
	TEST_ASSERT(turret.anchored, "A visitor unbolted an outpost's switched-off turret")
	turret.attackby(wrench, owner)
	TEST_ASSERT(!turret.anchored, "The owner could not unbolt their outpost's switched-off turret")
	turret.attackby(wrench, owner)
	TEST_ASSERT(turret.anchored, "The owner could not bolt their turret back down")

	// A wreck is scrapped by members only.
	turret.atom_break()
	TEST_ASSERT(turret.machine_stat & BROKEN, "The test turret did not break")
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	turret.attackby(crowbar, visitor)
	TEST_ASSERT(!QDELETED(turret), "A visitor scrapped an outpost's wrecked turret")

	// A claim nobody holds is nobody's lock, like a derelict.
	home.founder_ckey = null
	TEST_ASSERT(turret.allowed_operator(visitor), "A turret on a vacant claim is still locked")
	home.founder_ckey = "turretowner"

	// On a hull docked at the outpost, the ship's crew work its turret and the outpost's owner does not.
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.ship_team = new /datum/team/voidcrew
	visitor_port = new(run_loc_floor_bottom_left)
	visitor_port.width = 1
	visitor_port.height = 1
	visitor_port.dwidth = 0
	visitor_port.dheight = 0
	visitor_port.current_ship = ship
	ship.shuttle = visitor_port
	visitor_turf = get_step(floor, NORTH)
	original_visitor_area = get_area(visitor_turf)
	visitor_area = new
	visitor_turf.change_area(original_visitor_area, visitor_area)
	visitor_port.forceMove(visitor_turf)
	visitor_port.shuttle_areas = list()
	visitor_port.shuttle_areas[visitor_area] = TRUE
	visitor_area.shuttle_port = visitor_port
	var/obj/machinery/porta_turret/ship_defense/hull_turret = allocate(/obj/machinery/porta_turret/ship_defense, visitor_turf)
	var/mob/living/carbon/human/sailor = make_player(floor, "turretsailor")
	ship.ship_team.add_member(sailor.mind)
	TEST_ASSERT(hull_turret.allowed_operator(sailor), "A ship's crew could not work their hull's turret while docked at an outpost")
	TEST_ASSERT(!hull_turret.allowed_operator(owner), "The outpost's owner could work a docked ship's turret")
	TEST_ASSERT(!hull_turret.allowed_operator(visitor), "A stranger could work a docked ship's turret")
	ship.ship_team.remove_member(sailor.mind)
