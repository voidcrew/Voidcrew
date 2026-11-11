// Package: P3 heat. Unit tests for voidcrew/modules/plasma_weapons/.
// Shots are simulated with add_heat(heat_per_shot) and 0.7 s of process() between them, the pace the
// balance sim fires at. A boil shows as lost integrity, so these pass with or without P2's take_mol.

// The unit tests are included before voidcrew/_DEFINES/, so the PLASMA_* values are copied here.
#define PLASMA_TEST_HEAT_BOIL 100
#define PLASMA_TEST_BOIL_INTEGRITY 10
#define PLASMA_TEST_FLASK_CAPACITY 60
#define PLASMA_TEST_VENT_MOL 5
#define PLASMA_TEST_VENT_COOL 50
#define PLASMA_TEST_BOIL_MOL 5

/// Fires `shots` simulated rifle shots, cooling 0.7 s after each. Returns the shot number of the first boil, or 0.
/proc/plasma_heat_test_burst(obj/item/gun/energy/plasma_weapon/gun, shots)
	for(var/shot in 1 to shots)
		var/integrity_before = gun.get_integrity()
		gun.add_heat(gun.heat_per_shot)
		if(gun.get_integrity() < integrity_before)
			return shot
		gun.process(0.7)
	return 0

/// Plasma mol in `air`
/proc/plasma_heat_test_plasma(datum/gas_mixture/air)
	var/list/plasma = air.gases[/datum/gas/plasma]
	return plasma ? plasma[MOLES] : 0

/// A full flask fired flat out in room air never boils.
/datum/unit_test/voidcrew_plasma_heat_air

/datum/unit_test/voidcrew_plasma_heat_air/Run()
	var/turf/open/spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	TEST_ASSERT(air.return_pressure() > 90, "The test floor has no room air ([air.return_pressure()] kPa)")
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(gun, 12), 0, "A Furnace boiled within 12 shots in room air")
	TEST_ASSERT(gun.barrel_heat > 0 && gun.barrel_heat < PLASMA_TEST_HEAT_BOIL, "A Furnace ended 12 shots at heat [gun.barrel_heat]")
	TEST_ASSERT_EQUAL(gun.heat_step, 2, "A Furnace at heat [gun.barrel_heat] shows coil step [gun.heat_step]")

/// In vacuum the rifle only cools by its base rate and boils on the 9th shot.
/datum/unit_test/voidcrew_plasma_heat_vacuum
	var/turf/open/spot
	var/datum/gas_mixture/saved_air

/datum/unit_test/voidcrew_plasma_heat_vacuum/Run()
	spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	saved_air = air.copy()
	air.remove_ratio(1)
	TEST_ASSERT(air.return_pressure() < 1, "Emptying the test floor's air left [air.return_pressure()] kPa")
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
	gun.cell.charge = 0 // a boil with plasma would leave hot gas on the tile and change the cooling
	// 13.5 + 11.75 per shot after the first: 95.75 after the 8th, 107.5 after the 9th
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(gun, 12), 9, "A Furnace in vacuum did not first boil on the 9th shot")
	TEST_ASSERT_EQUAL(gun.get_integrity(), gun.max_integrity - PLASMA_TEST_BOIL_INTEGRITY, "One boil did not cost [PLASMA_TEST_BOIL_INTEGRITY] integrity")
	TEST_ASSERT(gun.barrel_heat < PLASMA_TEST_HEAT_BOIL, "A boil left the Furnace at heat [gun.barrel_heat]")

	// The Old Furnace runs cooler: 10 + 8.25 per shot after the first, so 10 shots stay under the boil.
	air.remove_ratio(1)
	var/obj/item/gun/energy/plasma_weapon/rifle/old_furnace/old = allocate(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace, spot)
	old.cell.charge = 0
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(old, 10), 0, "The Old Furnace boiled within 10 shots in vacuum")

	// The pistol has no heat at all.
	var/obj/item/gun/energy/plasma_weapon/pistol/pistol = allocate(/obj/item/gun/energy/plasma_weapon/pistol, spot)
	pistol.add_heat(PLASMA_TEST_HEAT_BOIL * 2)
	TEST_ASSERT_EQUAL(pistol.barrel_heat, 0, "The Cinder gained heat")
	TEST_ASSERT(!(pistol.datum_flags & DF_ISPROCESSING), "The Cinder started processing")

/datum/unit_test/voidcrew_plasma_heat_vacuum/Destroy()
	if(spot && saved_air)
		spot.return_air().copy_from(saved_air)
	return ..()

/// Every mole a vent puts on the turf left the chamber, a vent locks firing, and the cooldown holds.
/datum/unit_test/voidcrew_plasma_heat_vent
	var/turf/open/spot
	var/datum/gas_mixture/saved_air

/datum/unit_test/voidcrew_plasma_heat_vent/Run()
	spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	saved_air = air.copy()
	air.remove_ratio(1) // vacuum, so the hot puff can't burn and eat the plasma we count
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)

	// A full chamber
	gun.cell.charge = PLASMA_TEST_FLASK_CAPACITY
	gun.barrel_heat = 80
	var/chamber_before = gun.chamber_mol()
	var/turf_before = plasma_heat_test_plasma(air)
	gun.attack_self(user)
	var/lost = chamber_before - gun.chamber_mol()
	var/gained = plasma_heat_test_plasma(air) - turf_before
	TEST_ASSERT_EQUAL(gained, lost, "A vent put [gained] mol on the turf but took [lost] mol from the chamber")
	TEST_ASSERT(lost == 0 || lost == PLASMA_TEST_VENT_MOL, "A vent from a full chamber took [lost] mol")
	if(lost)
		TEST_ASSERT_EQUAL(gun.barrel_heat, 80 - PLASMA_TEST_VENT_COOL, "A vent did not cool the barrel by [PLASMA_TEST_VENT_COOL]")
		TEST_ASSERT(!gun.can_fire_heat(), "The Furnace can fire straight after a vent")
		TEST_ASSERT(!gun.can_shoot(), "can_shoot ignores the vent lock")
		var/chamber_mid = gun.chamber_mol()
		gun.attack_self(user)
		TEST_ASSERT_EQUAL(gun.chamber_mol(), chamber_mid, "A second vent inside the cooldown took plasma")
		gun.vent_lock_until = world.time
		TEST_ASSERT(gun.can_fire_heat(), "The vent lock outlived vent_lock_until")

	// A chamber short of a full vent gives up what it has, no more, and the turf gets exactly that.
	gun.next_vent_at = 0
	gun.cell.charge = 3
	chamber_before = gun.chamber_mol()
	turf_before = plasma_heat_test_plasma(air)
	gun.attack_self(user)
	lost = chamber_before - gun.chamber_mol()
	gained = plasma_heat_test_plasma(air) - turf_before
	TEST_ASSERT_EQUAL(gained, lost, "A short vent put [gained] mol on the turf but took [lost] mol from the chamber")
	TEST_ASSERT(lost >= 0 && lost <= 3, "A vent from a 3 mol chamber took [lost] mol")

	// A boil conserves the same way.
	gun.cell.charge = PLASMA_TEST_FLASK_CAPACITY
	chamber_before = gun.chamber_mol()
	turf_before = plasma_heat_test_plasma(air)
	gun.barrel_heat = PLASMA_TEST_HEAT_BOIL
	gun.add_heat(0)
	lost = chamber_before - gun.chamber_mol()
	gained = plasma_heat_test_plasma(air) - turf_before
	TEST_ASSERT_EQUAL(gained, lost, "A boil put [gained] mol on the turf but took [lost] mol from the chamber")
	TEST_ASSERT(lost == 0 || lost == PLASMA_TEST_BOIL_MOL, "A boil from a full chamber took [lost] mol")

/datum/unit_test/voidcrew_plasma_heat_vent/Destroy()
	if(spot && saved_air)
		spot.return_air().copy_from(saved_air)
	return ..()

/// A hot gun processes on SSobj and stops once it has cooled.
/datum/unit_test/voidcrew_plasma_heat_processing

/datum/unit_test/voidcrew_plasma_heat_processing/Run()
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, run_loc_floor_bottom_left)
	TEST_ASSERT(!(gun.datum_flags & DF_ISPROCESSING), "A cold Furnace is processing")
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT(gun.datum_flags & DF_ISPROCESSING, "A hot Furnace did not start processing")
	gun.process(100)
	TEST_ASSERT_EQUAL(gun.barrel_heat, 0, "A Furnace did not cool in 100 s of room air")
	TEST_ASSERT(!(gun.datum_flags & DF_ISPROCESSING), "A cooled Furnace kept processing")
	TEST_ASSERT_EQUAL(gun.heat_step, 0, "A cooled Furnace still shows coil step [gun.heat_step]")

/// Twenty boils break the gun, chamber empty or not.
/datum/unit_test/voidcrew_plasma_heat_breaks

/datum/unit_test/voidcrew_plasma_heat_breaks/Run()
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, run_loc_floor_bottom_left)
	gun.cell.charge = 0 // nothing to vent, so no hot plasma lights the test room
	var/boils = gun.max_integrity / PLASMA_TEST_BOIL_INTEGRITY
	TEST_ASSERT_EQUAL(boils, 20, "A Furnace takes [boils] boils to break, not 20")
	for(var/boil in 1 to boils - 1)
		gun.barrel_heat = PLASMA_TEST_HEAT_BOIL
		gun.add_heat(0)
	TEST_ASSERT(!QDELETED(gun), "A Furnace broke before its 20th boil")
	TEST_ASSERT_EQUAL(gun.get_integrity(), PLASMA_TEST_BOIL_INTEGRITY, "19 boils left the Furnace at [gun.get_integrity()] integrity")
	gun.barrel_heat = PLASMA_TEST_HEAT_BOIL
	gun.add_heat(0)
	TEST_ASSERT(QDELETED(gun), "A Furnace survived 20 boils")

#undef PLASMA_TEST_HEAT_BOIL
#undef PLASMA_TEST_BOIL_INTEGRITY
#undef PLASMA_TEST_FLASK_CAPACITY
#undef PLASMA_TEST_VENT_MOL
#undef PLASMA_TEST_VENT_COOL
#undef PLASMA_TEST_BOIL_MOL
