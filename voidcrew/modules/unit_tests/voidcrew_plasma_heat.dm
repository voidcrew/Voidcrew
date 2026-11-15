// Package: P3 heat. Unit tests for voidcrew/modules/plasma_weapons/.
// Shots are simulated with add_heat(heat_per_shot) and cool(gap) between them: 0.7 s is the rifle's fire delay,
// 1 s a steady pace and 1.2 s a careful one. heat_updated_at is pinned to now before each shot so a tick passing
// mid-test adds no cooling of its own.

/// Fires `shots` simulated shots, cooling `gap` seconds after each. Returns the shot number that overheated, or 0.
/proc/plasma_heat_test_burst(obj/item/gun/energy/plasma_weapon/gun, shots, gap)
	for(var/shot in 1 to shots)
		gun.heat_updated_at = world.time
		gun.add_heat(gun.heat_per_shot)
		if(gun.shutdown_until)
			return shot
		gun.cool(gap)
	return 0

/// Plasma mol in `air`
/proc/plasma_heat_test_plasma(datum/gas_mixture/air)
	var/list/plasma = air.gases[/datum/gas/plasma]
	return plasma ? plasma[MOLES] : 0

/// Deciseconds into a vent's sweep at the middle of bar unit `unit` (0 to PLASMA_VENT_UNITS - 1)
/proc/plasma_heat_test_unit_time(unit)
	return (unit + 0.5) * PLASMA_VENT_SWEEP / PLASMA_VENT_UNITS

/// Room air: a careful 1.2 s pace never overheats a cartridge; 1 s overheats on the 11th; flat out on the 8th.
/datum/unit_test/voidcrew_plasma_heat_air

/datum/unit_test/voidcrew_plasma_heat_air/Run()
	var/turf/open/spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	TEST_ASSERT(air.return_pressure() > 90, "The test floor has no room air ([air.return_pressure()] kPa)")
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
	var/rate = gun.heat_cool_rate()
	TEST_ASSERT(rate > 11 && rate < 12, "Room air cools a Furnace [rate] a second, not about 11.5")
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(gun, 12, 0.7), 8, "A Furnace fired flat out in room air did not overheat on the 8th shot")
	var/obj/item/gun/energy/plasma_weapon/rifle/steady = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(steady, 12, 1), 11, "A Furnace fired every second in room air did not overheat on the 11th shot")
	var/obj/item/gun/energy/plasma_weapon/rifle/careful = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(careful, 12, 1.2), 0, "A Furnace fired every 1.2 s in room air overheated within a cartridge")
	TEST_ASSERT(careful.heat_step >= 2, "A Furnace at heat [careful.barrel_heat] after a careful cartridge shows coil step [careful.heat_step]")

	var/obj/item/gun/energy/plasma_weapon/rifle/old_furnace/old = allocate(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace, spot)
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(old, 12, 0.7), 10, "The Old Furnace fired flat out in room air did not overheat on the 10th shot")
	var/obj/item/gun/energy/plasma_weapon/rifle/old_furnace/old_steady = allocate(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace, spot)
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(old_steady, 12, 1), 0, "The Old Furnace fired every second in room air overheated within a cartridge")

/// Vacuum only cools at the base rate: the 7th shot flat out or at 1 s, the 8th at 1.2 s.
/datum/unit_test/voidcrew_plasma_heat_vacuum
	var/turf/open/spot
	var/datum/gas_mixture/saved_air

/datum/unit_test/voidcrew_plasma_heat_vacuum/Run()
	spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	saved_air = air.copy()
	air.remove_ratio(1)
	TEST_ASSERT(air.return_pressure() < 1, "Emptying the test floor's air left [air.return_pressure()] kPa")
	var/list/gaps = list(0.7, 1, 1.2)
	var/list/expected = list(7, 7, 8)
	for(var/i in 1 to length(gaps))
		var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
		var/shot = plasma_heat_test_burst(gun, 12, gaps[i])
		TEST_ASSERT_EQUAL(shot, expected[i], "A Furnace in vacuum every [gaps[i]] s overheated on shot [shot]")
	var/obj/item/gun/energy/plasma_weapon/rifle/old_furnace/old = allocate(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace, spot)
	TEST_ASSERT_EQUAL(plasma_heat_test_burst(old, 12, 1.2), 9, "The Old Furnace in vacuum every 1.2 s did not overheat on the 9th shot")

	// The pistol has no heat at all.
	var/obj/item/gun/energy/plasma_weapon/pistol/pistol = allocate(/obj/item/gun/energy/plasma_weapon/pistol, spot)
	pistol.add_heat(PLASMA_HEAT_MAX * 2)
	TEST_ASSERT_EQUAL(pistol.barrel_heat, 0, "The Cinder gained heat")
	TEST_ASSERT(!(pistol.datum_flags & DF_ISPROCESSING), "The Cinder started processing")

/datum/unit_test/voidcrew_plasma_heat_vacuum/Destroy()
	if(spot && saved_air)
		spot.return_air().copy_from(saved_air)
	return ..()

/// An overheat shuts the gun down for 10 s: no firing, no venting, no heat, no damage and no gas. Then it comes back low.
/datum/unit_test/voidcrew_plasma_heat_shutdown

/datum/unit_test/voidcrew_plasma_heat_shutdown/Run()
	var/turf/open/spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	user.put_in_active_hand(gun, forced = TRUE)
	var/chamber_before = gun.chamber_mol()
	var/plasma_before = plasma_heat_test_plasma(air)
	gun.barrel_heat = PLASMA_HEAT_MAX - 1
	gun.heat_updated_at = world.time
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT_EQUAL(gun.shutdown_until, world.time + PLASMA_OVERHEAT_SHUTDOWN, "An overheat didn't shut the Furnace down for 10 s")
	TEST_ASSERT_EQUAL(gun.barrel_heat, PLASMA_HEAT_MAX, "An overheated Furnace sits at heat [gun.barrel_heat]")
	TEST_ASSERT_EQUAL(gun.heat_step, 3, "An overheated Furnace's coils show step [gun.heat_step], not full glow")
	TEST_ASSERT_EQUAL(gun.get_integrity(), gun.max_integrity, "An overheat damaged the Furnace")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), chamber_before, "An overheat took plasma from the chamber")
	TEST_ASSERT_EQUAL(plasma_heat_test_plasma(air), plasma_before, "An overheat put plasma on the turf")
	TEST_ASSERT(!gun.can_fire_heat(), "A shut-down Furnace can fire")
	TEST_ASSERT(!gun.can_shoot(), "can_shoot ignores the shutdown")
	TEST_ASSERT(!gun.vent_key(user), "A shut-down Furnace started a vent")
	TEST_ASSERT(!gun.vent_started_at, "A shut-down Furnace is venting")
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT_EQUAL(gun.barrel_heat, PLASMA_HEAT_MAX, "A shut-down Furnace's heat moved")
	gun.cool(30)
	TEST_ASSERT_EQUAL(gun.barrel_heat, PLASMA_HEAT_MAX, "A shut-down Furnace cooled")
	// Ten seconds on: the deadline passes and the gun comes back on its own
	gun.shutdown_until = world.time
	TEST_ASSERT(gun.can_fire_heat(), "The Furnace was still shut down after its 10 s")
	TEST_ASSERT_EQUAL(gun.barrel_heat, PLASMA_OVERHEAT_END_HEAT, "A Furnace came back from an overheat at heat [gun.barrel_heat]")
	TEST_ASSERT_EQUAL(gun.heat_step, 0, "A Furnace back from an overheat still glows at step [gun.heat_step]")

/// The bar's zones, the vent's start rules and the heat each result leaves
/datum/unit_test/voidcrew_plasma_heat_vent
	var/turf/open/spot
	var/datum/gas_mixture/saved_air

/datum/unit_test/voidcrew_plasma_heat_vent/Run()
	// The zones: ----yyyyxxxyyyy----
	var/zones = ""
	for(var/unit in 0 to PLASMA_VENT_UNITS - 1)
		switch(plasma_vent_zone(plasma_heat_test_unit_time(unit)))
			if(PLASMA_VENT_RESULT_GOLD)
				zones += "x"
			if(PLASMA_VENT_RESULT_GRACE)
				zones += "y"
			if(PLASMA_VENT_RESULT_FAIL)
				zones += "-"
			else
				zones += "?"
	TEST_ASSERT_EQUAL(zones, "----yyyyxxxyyyy----", "The vent bar's zones are wrong")
	TEST_ASSERT_EQUAL(plasma_vent_zone(PLASMA_VENT_SWEEP), PLASMA_VENT_RESULT_NONE, "A tap at the sweep's end still counts")

	spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	saved_air = air.copy()
	air.remove_ratio(1) // vacuum, so the vented plasma can't burn
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	user.put_in_active_hand(gun, forced = TRUE)

	// Too cool to glow: nothing happens
	gun.barrel_heat = PLASMA_HEAT_STEP_1 - 1
	gun.heat_updated_at = world.time
	TEST_ASSERT(!gun.vent_key(user), "A Furnace too cool to glow started a vent")

	// A vent blocks firing until it ends
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.vent_key(user), "A glowing Furnace in the active hand didn't start a vent")
	TEST_ASSERT(!gun.can_fire_heat(), "A venting Furnace can fire")
	TEST_ASSERT_NOTNULL(gun.vent_bar, "A vent made no bar")
	TEST_ASSERT_EQUAL(gun.vent_bar.loc, user, "The vent bar isn't drawn on the venter")
	TEST_ASSERT(gun.vent_marker.appearance_flags & RESET_TRANSFORM, "The vent marker turns with the venter's body")
	TEST_ASSERT(gun.vent_bar.pixel_z >= ICON_SIZE_Y - 4, "The vent bar sits at [gun.vent_bar.pixel_z], inside the venter's body")

	// Gold: all the heat off, and the next shots add half heat for a while
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(9)
	gun.heat_updated_at = world.time
	gun.vent_key(user)
	TEST_ASSERT(!gun.vent_started_at, "A gold tap didn't end the vent")
	TEST_ASSERT_EQUAL(gun.barrel_heat, 0, "A gold vent left heat [gun.barrel_heat]")
	TEST_ASSERT(gun.can_fire_heat(), "A gold vent locked the trigger")
	TEST_ASSERT_NULL(gun.vent_bar, "A gold vent left its bar")
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT_EQUAL(gun.barrel_heat, gun.heat_per_shot * PLASMA_VENT_GOLD_HEAT_MULT, "A shot after a gold vent added [gun.barrel_heat] heat, not half")
	gun.gold_until = world.time
	gun.barrel_heat = 0
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT_EQUAL(gun.barrel_heat, gun.heat_per_shot, "A shot after the gold window still added half heat")

	// Grace, early and late: a large fixed cut, and the trigger free at once
	for(var/unit in list(6, 13))
		gun.barrel_heat = 90
		gun.heat_updated_at = world.time
		gun.vent_lock_until = 0
		TEST_ASSERT(gun.vent_key(user), "A vent didn't start for the grace test")
		gun.vent_started_at = world.time - plasma_heat_test_unit_time(unit)
		gun.heat_updated_at = world.time
		gun.vent_key(user)
		TEST_ASSERT_EQUAL(gun.barrel_heat, 90 - PLASMA_VENT_COOL, "A grace tap at unit [unit] left heat [gun.barrel_heat]")
		TEST_ASSERT(gun.can_fire_heat(), "A grace vent locked the trigger")

	// No tap: the same cut when the sweep ends, then a moment more of venting with the trigger locked
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.vent_key(user), "A vent didn't start for the no-tap test")
	gun.vent_started_at = world.time - PLASMA_VENT_SWEEP
	gun.vent_key(user) // a tap past the end changes nothing
	TEST_ASSERT(gun.vent_started_at, "A tap past the sweep's end settled the vent")
	gun.heat_updated_at = world.time
	gun.finish_vent_sweep()
	TEST_ASSERT(!gun.vent_started_at, "The sweep's end didn't end the vent")
	TEST_ASSERT_EQUAL(gun.barrel_heat, 90 - PLASMA_VENT_COOL, "A vent left to run out left heat [gun.barrel_heat]")
	TEST_ASSERT_EQUAL(gun.vent_lock_until, world.time + PLASMA_VENT_NONE_LOCK, "A vent left to run out didn't lock the trigger for a moment")
	TEST_ASSERT(!gun.can_fire_heat(), "A Furnace fires while it finishes venting")
	TEST_ASSERT(!gun.vent_key(user), "A new vent started while the last one finished")

	// Fail, early and late: the old plasma vent, below ignition, plus the cut and a lock
	for(var/unit in list(1, 17))
		gun.vent_lock_until = 0
		gun.cell.charge = PLASMA_CARTRIDGE_CAPACITY
		gun.chamber_changed()
		gun.barrel_heat = 99
		gun.heat_updated_at = world.time
		TEST_ASSERT(gun.vent_key(user), "A vent didn't start for the fail test")
		var/chamber_before = gun.chamber_mol()
		var/turf_before = plasma_heat_test_plasma(air)
		gun.vent_started_at = world.time - plasma_heat_test_unit_time(unit)
		gun.heat_updated_at = world.time
		gun.vent_key(user)
		var/lost = chamber_before - gun.chamber_mol()
		var/gained = plasma_heat_test_plasma(air) - turf_before
		TEST_ASSERT_EQUAL(lost, PLASMA_VENT_MOL, "A fail tap at unit [unit] took [lost] mol from a full chamber")
		TEST_ASSERT_EQUAL(gained, lost, "A fail vent put [gained] mol on the turf but took [lost] mol from the chamber")
		TEST_ASSERT(air.return_temperature() < PLASMA_MINIMUM_BURN_TEMPERATURE, "A fail vent from a hot barrel left gas at [air.return_temperature()] K, hot enough to light")
		TEST_ASSERT_EQUAL(gun.barrel_heat, 99 - PLASMA_VENT_COOL, "A fail vent left heat [gun.barrel_heat]")
		TEST_ASSERT_EQUAL(gun.vent_lock_until, world.time + PLASMA_VENT_FAIL_LOCK, "A fail vent didn't lock the trigger")
		air.remove_ratio(1)

/datum/unit_test/voidcrew_plasma_heat_vent/Destroy()
	if(spot && saved_air)
		spot.return_air().copy_from(saved_air)
	return ..()

/// The vent bar goes away when the gun leaves the hand, the hands swap, or the gun is deleted
/datum/unit_test/voidcrew_plasma_heat_vent_cleanup

/datum/unit_test/voidcrew_plasma_heat_vent_cleanup/Run()
	var/turf/open/spot = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	user.put_in_active_hand(gun, forced = TRUE)

	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.vent_key(user), "A vent didn't start for the drop test")
	var/standing_height = gun.vent_bar.pixel_z
	user.dropItemToGround(gun)
	TEST_ASSERT(!gun.vent_started_at, "Dropping the Furnace didn't end its vent")
	TEST_ASSERT(isnull(gun.vent_bar) && isnull(gun.vent_marker), "Dropping the Furnace left its vent bar")
	TEST_ASSERT_NULL(gun.vent_user, "Dropping the Furnace kept its venter")
	TEST_ASSERT(gun.can_fire_heat(), "A vent ended by a drop locked the trigger")

	user.put_in_active_hand(gun, forced = TRUE)
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.vent_key(user), "A vent didn't start for the swap test")
	user.swap_hand()
	TEST_ASSERT(!gun.vent_started_at, "Swapping hands didn't end the vent")
	TEST_ASSERT_NULL(gun.vent_bar, "Swapping hands left the vent bar")
	user.swap_hand()

	// A do_after bar on the venter pushes the vent bar up over it, and lying down brings it back to the body
	var/datum/progressbar/self_bar = new(user, 10, user)
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.vent_key(user), "A vent didn't start for the stacking test")
	TEST_ASSERT(gun.vent_bar.pixel_z > standing_height, "The vent bar at [gun.vent_bar.pixel_z] overlaps a do_after bar")
	qdel(self_bar)
	user.set_body_position(LYING_DOWN)
	TEST_ASSERT(gun.vent_started_at, "Lying down ended the vent")
	TEST_ASSERT(gun.vent_marker.pixel_z < standing_height, "The vent bar didn't drop when its venter lay down")
	user.set_body_position(STANDING_UP)
	gun.cancel_vent()
	TEST_ASSERT_NULL(gun.vent_bar, "Cancelling the vent left its bar")
	gun.vent_lock_until = 0

	// A sweep whose timer was lost still ends the next time the gun is asked to fire
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.vent_key(user), "A vent didn't start for the lost-timer test")
	gun.vent_started_at = world.time - PLASMA_VENT_SWEEP
	gun.can_fire_heat()
	TEST_ASSERT(!gun.vent_started_at, "A vent past the end of its sweep kept running")
	gun.vent_lock_until = 0

	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.vent_key(user), "A vent didn't start for the delete test")
	qdel(gun)
	TEST_ASSERT(isnull(gun.vent_bar) && isnull(gun.vent_marker), "Deleting the Furnace left its vent bar")

/// A Furnace pirate runs the same heat: it vents near the top and never times it, and every block runs out
/datum/unit_test/voidcrew_plasma_heat_npc

/datum/unit_test/voidcrew_plasma_heat_npc/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/turf/target = locate(start.x + 4, start.y + 4, start.z)
	var/mob/living/basic/trooper/pirate/ranged/gunner = allocate(/mob/living/basic/trooper/pirate/ranged, locate(start.x, start.y + 2, start.z))
	pirate_crew_arm(gunner, /datum/pirate_gun_loadout/plasma_rifle)
	var/datum/component/pirate_gun/gun = pirate_gun_of(gunner)
	TEST_ASSERT_NOTNULL(gun, "A gunner handed a plasma rifle has no gun")
	TEST_ASSERT_EQUAL(gun.plasma_heat_per_shot(), PLASMA_HEAT_PER_SHOT, "A Furnace pirate's shots heat [gun.plasma_heat_per_shot()], not a Furnace's")

	// An ordinary shot heats it like a Furnace
	TEST_ASSERT(gun.try_fire(target), "A cool Furnace pirate wouldn't fire")
	TEST_ASSERT_EQUAL(gun.plasma_heat, PLASMA_HEAT_PER_SHOT, "A Furnace pirate's shot left heat [gun.plasma_heat]")

	// White-hot: it vents instead of firing, and can't fire until the vent is done
	gun.next_fire_at = 0
	gun.plasma_heat = PLASMA_HEAT_STEP_3 + 5
	gun.plasma_heat_at = world.time
	TEST_ASSERT(!gun.try_fire(target), "A white-hot Furnace pirate fired instead of venting")
	TEST_ASSERT_EQUAL(gun.plasma_vent_until, world.time + PLASMA_VENT_SWEEP + PLASMA_VENT_NONE_LOCK, "A Furnace pirate's vent isn't a vent left to run out")
	gun.next_fire_at = 0
	TEST_ASSERT(!gun.try_fire(target), "A venting Furnace pirate fired")
	// The vent runs out on its own deadline
	gun.plasma_vent_done_at = world.time
	gun.plasma_vent_until = world.time
	gun.plasma_heat_at = world.time
	gun.plasma_heat_update()
	TEST_ASSERT_EQUAL(gun.plasma_heat, PLASMA_HEAT_STEP_3 + 5 - PLASMA_VENT_COOL, "A Furnace pirate's vent left heat [gun.plasma_heat]")
	gun.next_fire_at = 0
	TEST_ASSERT(gun.try_fire(target), "A Furnace pirate couldn't fire after its vent")

	// A shot to the max shuts it down; the shutdown runs out on its own deadline
	gun.plasma_heat = PLASMA_HEAT_MAX - 1
	gun.plasma_heat_at = world.time
	gun.plasma_heat_shot()
	TEST_ASSERT_EQUAL(gun.plasma_shutdown_until, world.time + PLASMA_OVERHEAT_SHUTDOWN, "An overheated Furnace pirate isn't shut down for 10 s")
	gun.next_fire_at = 0
	TEST_ASSERT(!gun.try_fire(target), "A shut-down Furnace pirate fired")
	gun.plasma_shutdown_until = world.time
	gun.next_fire_at = 0
	TEST_ASSERT(gun.try_fire(target), "A Furnace pirate stayed shut down past its 10 s")
	TEST_ASSERT(!gun.plasma_shutdown_until, "A Furnace pirate's shutdown didn't clear")
	TEST_ASSERT_EQUAL(gun.plasma_heat, PLASMA_OVERHEAT_END_HEAT + PLASMA_HEAT_PER_SHOT, "A Furnace pirate back from an overheat fired at heat [gun.plasma_heat]")
