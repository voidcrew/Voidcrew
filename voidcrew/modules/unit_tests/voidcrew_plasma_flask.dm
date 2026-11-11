// Package: P2 guns and flask. Unit tests for voidcrew/modules/plasma_weapons/.

/// Plasma a gun and its seated or loose flask hold together
/proc/plasma_test_total(obj/item/gun/energy/plasma_weapon/gun, obj/item/plasma_flask/flask)
	return gun.chamber_mol() + (flask ? flask.stored : 0)

/// Spawn fills: shop guns and the Old Furnace come full, loot guns at most half full
/datum/unit_test/voidcrew_plasma_spawn_fill/Run()
	for(var/gun_type in list(/obj/item/gun/energy/plasma_weapon/pistol, /obj/item/gun/energy/plasma_weapon/rifle, /obj/item/gun/energy/plasma_weapon/rifle/old_furnace))
		var/obj/item/gun/energy/plasma_weapon/gun = allocate(gun_type)
		TEST_ASSERT_NOTNULL(gun.flask, "[gun_type] spawned without a flask")
		TEST_ASSERT_EQUAL(gun.chamber_mol(), PLASMA_FLASK_CAPACITY, "[gun_type] did not spawn full")
		TEST_ASSERT_EQUAL(gun.flask.stored, 0, "[gun_type]'s seated flask still holds plasma")
	for(var/gun_type in list(/obj/item/gun/energy/plasma_weapon/pistol/loot, /obj/item/gun/energy/plasma_weapon/rifle/loot))
		var/obj/item/gun/energy/plasma_weapon/gun = allocate(gun_type)
		TEST_ASSERT_NOTNULL(gun.flask, "[gun_type] spawned without a flask")
		TEST_ASSERT(gun.chamber_mol() >= 0 && gun.chamber_mol() <= PLASMA_FLASK_CAPACITY / 2, "[gun_type] spawned with [gun.chamber_mol()] mol")

/// Loading and unloading 100 times never changes the plasma a gun and its flask hold
/datum/unit_test/voidcrew_plasma_flask_invariant/Run()
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	gun.take_mol(17)
	var/obj/item/plasma_flask/flask = gun.flask
	var/total = plasma_test_total(gun, null)
	TEST_ASSERT_EQUAL(total, PLASMA_FLASK_CAPACITY - 17, "take_mol took the wrong amount")
	for(var/i in 1 to 100)
		TEST_ASSERT_EQUAL(gun.unload_flask(null), flask, "unload_flask didn't return the flask")
		TEST_ASSERT_NULL(gun.flask, "flask still seated after unloading")
		TEST_ASSERT_EQUAL(gun.chamber_mol(), 0, "chamber kept plasma after unloading")
		TEST_ASSERT_EQUAL(plasma_test_total(gun, flask), total, "plasma changed on unload [i]")
		TEST_ASSERT(gun.load_flask(flask, null), "load_flask failed on loop [i]")
		TEST_ASSERT_EQUAL(plasma_test_total(gun, null), total, "plasma changed on load [i]")
	// Loading a second flask pushes the first one out with its plasma
	var/obj/item/plasma_flask/second = allocate(/obj/item/plasma_flask)
	second.stored = 20
	TEST_ASSERT(gun.load_flask(second, null), "couldn't swap flasks")
	TEST_ASSERT_EQUAL(gun.flask, second, "second flask not seated")
	TEST_ASSERT_EQUAL(flask.stored, total, "first flask lost plasma on the swap")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 20, "chamber didn't take the second flask's plasma")

/// A seated flask that leaves any other way still takes the chamber's plasma with it
/datum/unit_test/voidcrew_plasma_flask_writeback/Run()
	var/obj/item/gun/energy/plasma_weapon/pistol/gun = allocate(/obj/item/gun/energy/plasma_weapon/pistol)
	gun.take_mol(12)
	var/obj/item/plasma_flask/flask = gun.flask
	var/turf/elsewhere = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	flask.forceMove(elsewhere)
	TEST_ASSERT_NULL(gun.flask, "gun still thinks the flask is seated")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 0, "chamber kept plasma after the flask left")
	TEST_ASSERT_EQUAL(flask.stored, PLASMA_FLASK_CAPACITY - 12, "flask didn't get the chamber's plasma")
	TEST_ASSERT(!gun.can_shoot(), "gun can still fire with no flask")

	// Destroying the gun drops the flask with its plasma
	TEST_ASSERT(gun.load_flask(flask, null), "couldn't reseat the flask")
	gun.take_mol(4)
	qdel(gun)
	TEST_ASSERT(isturf(flask.loc), "flask didn't drop when the gun was destroyed")
	TEST_ASSERT_EQUAL(flask.stored, PLASMA_FLASK_CAPACITY - 16, "flask lost plasma when the gun was destroyed")
	qdel(flask)

/// Only plasma sheets and ore go in, a whole unit at a time, and only with room for all of it
/datum/unit_test/voidcrew_plasma_flask_feeding/Run()
	var/obj/item/plasma_flask/flask = allocate(/obj/item/plasma_flask)
	var/obj/item/stack/sheet/mineral/plasma/sheets = allocate(/obj/item/stack/sheet/mineral/plasma, null, 5)
	var/obj/item/stack/ore/plasma/ore = allocate(/obj/item/stack/ore/plasma, null, 5)

	flask.stored = 59
	TEST_ASSERT_EQUAL(flask.feed(sheets, null), 0, "a sheet went into a flask with 1 mol of room")
	TEST_ASSERT_EQUAL(sheets.get_amount(), 5, "a refused sheet was used up")
	TEST_ASSERT_EQUAL(flask.stored, 59, "a refused sheet changed the flask")

	flask.stored = 50
	TEST_ASSERT_EQUAL(flask.feed(ore, null), plasma_fuel_mol_per_unit(ore), "ore didn't fill the last 10 mol")
	TEST_ASSERT_EQUAL(flask.stored, PLASMA_FLASK_CAPACITY, "flask not full after the ore")
	TEST_ASSERT_EQUAL(ore.get_amount(), 4, "feeding took the wrong amount of ore")

	flask.stored = 0
	TEST_ASSERT_EQUAL(flask.feed(sheets, null), PLASMA_FLASK_CAPACITY, "three sheets didn't fill an empty flask")
	TEST_ASSERT_EQUAL(sheets.get_amount(), 2, "feeding took the wrong number of sheets")

	// Nothing else goes in: liquid plasma, glass, other flasks
	flask.stored = 0
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	beaker.reagents.add_reagent(/datum/reagent/toxin/plasma, 50)
	flask.item_interaction(null, beaker)
	TEST_ASSERT_EQUAL(flask.stored, 0, "liquid plasma went into a flask")
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 50, "the beaker lost plasma to a flask")
	var/obj/item/stack/sheet/glass/glass = allocate(/obj/item/stack/sheet/glass, null, 5)
	TEST_ASSERT_EQUAL(flask.feed(glass, null), 0, "glass went into a flask")
	var/obj/item/plasma_flask/other = allocate(/obj/item/plasma_flask)
	other.stored = 40
	flask.item_interaction(null, other)
	TEST_ASSERT_EQUAL(flask.stored, 0, "a flask poured into another flask")
	TEST_ASSERT_EQUAL(other.stored, 40, "a flask lost plasma to another flask")

	// Feeding a gun goes straight into its chamber, and needs a seated flask
	var/obj/item/gun/energy/plasma_weapon/pistol/gun = allocate(/obj/item/gun/energy/plasma_weapon/pistol)
	gun.take_mol(30)
	TEST_ASSERT_EQUAL(gun.feed_plasma(sheets, null), plasma_fuel_mol_per_unit(sheets), "a gun with 30 mol of room took the wrong amount")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 50, "feeding a gun didn't reach its chamber")
	TEST_ASSERT_EQUAL(gun.feed_plasma(sheets, null), 0, "a sheet went into a gun with 10 mol of room")
	var/obj/item/plasma_flask/taken = gun.unload_flask(null)
	TEST_ASSERT_EQUAL(gun.feed_plasma(sheets, null), 0, "a gun with no flask took plasma")
	TEST_ASSERT_EQUAL(taken.stored, 50, "unloaded flask has the wrong fill")
	qdel(taken)

/// Nothing charges the chamber except plasma
/datum/unit_test/voidcrew_plasma_chamber_sealed/Run()
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	gun.take_mol(40)
	var/obj/item/stock_parts/power_store/cell/plasma_chamber/chamber = gun.cell
	TEST_ASSERT(istype(chamber), "the rifle's cell isn't a plasma chamber")
	TEST_ASSERT_EQUAL(chamber.give(1000), 0, "give() reported charge")
	TEST_ASSERT_EQUAL(chamber.change(1000), 0, "change() reported charge")
	chamber.on_magic_charge(chamber, null, null)
	SEND_SIGNAL(gun, COMSIG_ITEM_RECHARGED)
	chamber.corrupt(TRUE)
	chamber.explode()
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 20, "the chamber gained or lost plasma without feeding")
	TEST_ASSERT_EQUAL(chamber.maxcharge, PLASMA_FLASK_CAPACITY, "corrupt() shrank the chamber")
	TEST_ASSERT(!chamber.rigged, "the chamber got rigged")
	TEST_ASSERT_NULL(chamber.reagents, "the chamber has a reagent holder")
	TEST_ASSERT(!QDELETED(chamber), "the chamber exploded")

	// Code that tops up every cell a mob carries must not find the chamber
	var/mob/living/carbon/human/consistent/holder = allocate(/mob/living/carbon/human/consistent)
	holder.put_in_hands(gun)
	TEST_ASSERT(!(chamber in holder.get_all_contents()), "the chamber is reachable through its holder's contents")
	TEST_ASSERT_EQUAL(gun.cell, chamber, "the gun lost its chamber")

	// No recharger
	TEST_ASSERT(!gun.can_charge, "plasma guns can be recharged")
	var/obj/machinery/recharger/recharger = allocate(/obj/machinery/recharger)
	recharger.attackby(gun, holder)
	TEST_ASSERT(gun.loc != recharger, "a recharger took a plasma gun")

	// EMP leaves the plasma alone
	gun.emp_act(EMP_HEAVY)
	chamber.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 20, "an EMP drained the chamber")

/// The world sprite shows empty once the chamber holds less than one shot
/datum/unit_test/voidcrew_plasma_empty_sprite/Run()
	var/obj/item/gun/energy/plasma_weapon/pistol/gun = allocate(/obj/item/gun/energy/plasma_weapon/pistol)
	var/obj/item/ammo_casing/energy/shot = gun.ammo_type[gun.select]
	TEST_ASSERT_EQUAL(gun.icon_state, "cinder", "a full Cinder shows the wrong state")
	gun.take_mol(gun.chamber_mol() - shot.e_cost + 1)
	TEST_ASSERT_EQUAL(gun.icon_state, "cinder_empty", "a Cinder short of one shot isn't shown empty")
	TEST_ASSERT(!gun.can_shoot(), "a Cinder short of one shot can fire")
