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

/// Room air: a Furnace fired flat out overheats on the 6th shot, every second on the 7th and every 1.2 s on the 8th,
/// so a 20-shot cartridge takes a few vents. The Old Furnace lasts to the 10th flat out and a whole cartridge at 1.2 s.
/datum/unit_test/voidcrew_plasma_heat_air

/datum/unit_test/voidcrew_plasma_heat_air/Run()
	var/turf/open/spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	TEST_ASSERT(air.return_pressure() > 90, "The test floor has no room air ([air.return_pressure()] kPa)")
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
	var/rate = gun.heat_cool_rate()
	TEST_ASSERT(rate > 11 && rate < 12, "Room air cools a Furnace [rate] a second, not about 11.5")
	var/list/gaps = list(0.7, 1, 1.2)
	var/list/expected = list(6, 7, 8)
	for(var/i in 1 to length(gaps))
		var/obj/item/gun/energy/plasma_weapon/rifle/furnace = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
		var/shot = plasma_heat_test_burst(furnace, 20, gaps[i])
		TEST_ASSERT_EQUAL(shot, expected[i], "A Furnace in room air every [gaps[i]] s overheated on shot [shot]")
	var/list/old_expected = list(10, 14, 0)
	for(var/i in 1 to length(gaps))
		var/obj/item/gun/energy/plasma_weapon/rifle/old_furnace/old = allocate(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace, spot)
		var/shot = plasma_heat_test_burst(old, 20, gaps[i])
		TEST_ASSERT_EQUAL(shot, old_expected[i], "The Old Furnace in room air every [gaps[i]] s overheated on shot [shot]")
		if(!shot)
			TEST_ASSERT(old.heat_step >= 3, "The Old Furnace at heat [old.barrel_heat] after a careful cartridge shows coil step [old.heat_step]")

/// Vacuum only cools at the base rate: the Furnace overheats on the 5th shot flat out or at 1 s, the 6th at 1.2 s;
/// the Old Furnace on the 7th, 8th and 9th.
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
	var/list/expected = list(5, 5, 6)
	for(var/i in 1 to length(gaps))
		var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
		var/shot = plasma_heat_test_burst(gun, 20, gaps[i])
		TEST_ASSERT_EQUAL(shot, expected[i], "A Furnace in vacuum every [gaps[i]] s overheated on shot [shot]")
	var/list/old_expected = list(7, 8, 9)
	for(var/i in 1 to length(gaps))
		var/obj/item/gun/energy/plasma_weapon/rifle/old_furnace/old = allocate(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace, spot)
		var/shot = plasma_heat_test_burst(old, 20, gaps[i])
		TEST_ASSERT_EQUAL(shot, old_expected[i], "The Old Furnace in vacuum every [gaps[i]] s overheated on shot [shot]")

	// The pistol has no heat at all.
	var/obj/item/gun/energy/plasma_weapon/pistol/pistol = allocate(/obj/item/gun/energy/plasma_weapon/pistol, spot)
	pistol.add_heat(PLASMA_HEAT_MAX * 2)
	TEST_ASSERT_EQUAL(pistol.barrel_heat, 0, "The Cinder gained heat")
	TEST_ASSERT(!(pistol.datum_flags & DF_ISPROCESSING), "The Cinder started processing")

/datum/unit_test/voidcrew_plasma_heat_vacuum/Destroy()
	if(spot && saved_air)
		spot.return_air().copy_from(saved_air)
	return ..()

/// The Old Furnace: 18 heat a shot, an 8 s gold window and a 6 s lockout, as its own vars; the Furnace keeps 25, 4 s and 10 s.
/datum/unit_test/voidcrew_plasma_heat_old_furnace
	var/turf/open/spot
	var/datum/gas_mixture/saved_air

/datum/unit_test/voidcrew_plasma_heat_old_furnace/Run()
	spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	saved_air = air.copy()
	air.remove_ratio(1) // vacuum, so nothing vented can burn
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/gun/energy/plasma_weapon/rifle/furnace = allocate(/obj/item/gun/energy/plasma_weapon/rifle, spot)
	TEST_ASSERT_EQUAL(furnace.heat_per_shot, 25, "The Furnace's heat a shot changed")
	TEST_ASSERT_EQUAL(furnace.gold_window, 4 SECONDS, "The Furnace's gold window changed")
	TEST_ASSERT_EQUAL(furnace.overheat_shutdown, 10 SECONDS, "The Furnace's lockout changed")

	var/obj/item/gun/energy/plasma_weapon/rifle/old_furnace/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace)
	user.put_in_active_hand(gun, forced = TRUE)
	TEST_ASSERT_EQUAL(gun.spread, 0, "The Old Furnace doesn't shoot straight")
	TEST_ASSERT_EQUAL(/obj/projectile/energy/plasma_bolt/heavy::damage, 30, "The Old Furnace's bolt damage changed")

	// A shot adds 18
	gun.heat_updated_at = world.time
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT_EQUAL(gun.barrel_heat, 18, "An Old Furnace shot added [gun.barrel_heat] heat, not 18")

	// A gold vent halves shot heat for 8 s
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.vent_key(user), "The Old Furnace didn't start a vent")
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(19)
	gun.heat_updated_at = world.time
	gun.vent_key(user)
	TEST_ASSERT_EQUAL(gun.gold_until, world.time + 8 SECONDS, "The Old Furnace's gold window isn't 8 s")
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT_EQUAL(gun.barrel_heat, 9, "A shot in the Old Furnace's gold window added [gun.barrel_heat], not 9")

	// An overheat locks it for 6 s, and it comes back at 6 s
	gun.barrel_heat = PLASMA_HEAT_MAX - 1
	gun.heat_updated_at = world.time
	gun.gold_until = 0
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT_EQUAL(gun.shutdown_until, world.time + 6 SECONDS, "The Old Furnace's lockout isn't 6 s")
	TEST_ASSERT(!gun.can_fire_heat(), "A locked Old Furnace can fire")
	gun.shutdown_until = world.time
	gun.end_shutdown()
	TEST_ASSERT(gun.can_fire_heat(), "The Old Furnace stayed locked past its 6 s")

/datum/unit_test/voidcrew_plasma_heat_old_furnace/Destroy()
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
	// The zones: fail 12, grace 5, gold 4, grace 5, fail 12
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
	TEST_ASSERT_EQUAL(zones, "------------yyyyyxxxxyyyyy------------", "The vent bar's zones are wrong")
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
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(19)
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
	for(var/unit in list(14, 23))
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
	for(var/unit in list(1, 33))
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

/// The vent's controls: using the Furnace in hand starts it, the next fire attempt or use in hand taps it, and the
/// unbound keybinding does both. A tap never fires a shot.
/datum/unit_test/voidcrew_plasma_heat_vent_controls
	var/turf/open/spot
	var/datum/gas_mixture/saved_air

/datum/unit_test/voidcrew_plasma_heat_vent_controls/Run()
	spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	saved_air = air.copy()
	air.remove_ratio(1) // vacuum, so nothing vented can burn
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	user.put_in_active_hand(gun, forced = TRUE)
	var/turf/far = locate(spot.x + 3, spot.y, spot.z)

	var/datum/keybinding/living/plasma_vent/binding = new
	TEST_ASSERT_EQUAL(binding.hotkey_keys[1], "Unbound", "The vent keybinding has a default key")
	TEST_ASSERT(!length(binding.classic_keys) || binding.classic_keys[1] == "Unbound", "The vent keybinding has a default classic key")
	qdel(binding)

	// In hand: starts a vent, and the pistol, which doesn't heat up, never vents
	var/obj/item/gun/energy/plasma_weapon/pistol/pistol = allocate(/obj/item/gun/energy/plasma_weapon/pistol)
	pistol.barrel_heat = 90
	pistol.attack_self(user)
	TEST_ASSERT(!pistol.vent_started_at, "Using a Cinder in hand started a vent")
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	gun.attack_self(user)
	TEST_ASSERT(gun.vent_started_at, "Using a glowing Furnace in hand didn't start a vent")
	TEST_ASSERT_NOTNULL(gun.vent_bar, "A vent started in hand made no bar")

	// A fire attempt on the gold is the tap: all the heat off, and nothing fired
	var/chamber_before = gun.chamber_mol()
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(19)
	gun.heat_updated_at = world.time
	TEST_ASSERT(gun.try_fire_gun(far, user, ""), "A fire attempt during a vent wasn't taken as the tap")
	TEST_ASSERT(!gun.vent_started_at, "A fire attempt on the gold didn't end the vent")
	TEST_ASSERT_EQUAL(gun.barrel_heat, 0, "A fire attempt on the gold left heat [gun.barrel_heat]")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), chamber_before, "The tap fired a shot")
	TEST_ASSERT_NULL(locate(/obj/projectile) in range(4, spot), "The tap fired a projectile")

	// The same attempt with no vent running does fire, so the check above means something
	gun.gold_until = 0
	gun.try_fire_gun(far, user, "")
	TEST_ASSERT(gun.chamber_mol() < chamber_before, "A Furnace with no vent running didn't fire")
	chamber_before = gun.chamber_mol()

	// A fire attempt on the dark end is a fumble, still without a shot
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	gun.attack_self(user)
	TEST_ASSERT(gun.vent_started_at, "A vent didn't start for the fumble test")
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(1)
	gun.heat_updated_at = world.time
	var/projectiles_before = 0
	for(var/obj/projectile/bolt in range(4, spot))
		projectiles_before++
	gun.try_fire_gun(far, user, "")
	TEST_ASSERT_EQUAL(gun.vent_lock_until, world.time + PLASMA_VENT_FAIL_LOCK, "A fire attempt on the dark end didn't fumble the vent")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), chamber_before - PLASMA_VENT_MOL, "A fumbled tap took [chamber_before - gun.chamber_mol()] mol, not the vent's spit")
	var/projectiles_after = 0
	for(var/obj/projectile/bolt in range(4, spot))
		projectiles_after++
	TEST_ASSERT_EQUAL(projectiles_after, projectiles_before, "A fumbled tap fired a projectile")
	gun.vent_lock_until = 0
	air.remove_ratio(1)

	// Using it in hand again during the bar taps too
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	gun.attack_self(user)
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(14)
	gun.heat_updated_at = world.time
	gun.attack_self(user)
	TEST_ASSERT(!gun.vent_started_at, "Using the Furnace in hand during the bar didn't tap")
	TEST_ASSERT_EQUAL(gun.barrel_heat, 90 - PLASMA_VENT_COOL, "An in-hand tap on the amber left heat [gun.barrel_heat]")

	// The keybinding's path starts and taps the same way
	gun.barrel_heat = 90
	gun.heat_updated_at = world.time
	TEST_ASSERT(plasma_vent_held_gun(user), "The vent keybinding didn't start a vent")
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(19)
	gun.heat_updated_at = world.time
	TEST_ASSERT(plasma_vent_held_gun(user), "The vent keybinding didn't tap")
	TEST_ASSERT_EQUAL(gun.barrel_heat, 0, "A keybinding tap on the gold left heat [gun.barrel_heat]")

/datum/unit_test/voidcrew_plasma_heat_vent_controls/Destroy()
	if(spot && saved_air)
		spot.return_air().copy_from(saved_air)
	return ..()

/// An overheat in a player's hand brings the vent bar up. Gold ends the lockout cold, amber vents most of the heat and
/// cuts the lockout to 2 s, a miss leaves all of it, and a fumble leaves all of it and spits gas. Dropping the gun takes
/// the bar away and leaves the lockout. With no player holding it, an overheat brings no bar.
/datum/unit_test/voidcrew_plasma_heat_overheat_vent
	var/turf/open/spot
	var/datum/gas_mixture/saved_air

/// Overheats `gun` with a shot, then brings the bar up as overheat() does for a player (test mobs have no client).
/// TRUE if the shot locked the gun and the bar came up.
/datum/unit_test/voidcrew_plasma_heat_overheat_vent/proc/overheat_with_bar(obj/item/gun/energy/plasma_weapon/gun, mob/living/user)
	gun.vent_lock_until = 0
	gun.shutdown_until = 0
	gun.gold_until = 0
	gun.barrel_heat = PLASMA_HEAT_MAX - 1
	gun.heat_updated_at = world.time
	gun.add_heat(gun.heat_per_shot)
	if(!gun.is_shut_down() || gun.vent_started_at)
		return FALSE
	return gun.start_overheat_vent(user) && gun.vent_overheat && gun.vent_bar

/datum/unit_test/voidcrew_plasma_heat_overheat_vent/Run()
	spot = run_loc_floor_bottom_left
	var/datum/gas_mixture/air = spot.return_air()
	saved_air = air.copy()
	air.remove_ratio(1) // vacuum, so nothing vented can burn
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	user.put_in_active_hand(gun, forced = TRUE)
	var/turf/far = locate(spot.x + 3, spot.y, spot.z)

	// No player holding it: the lockout runs with no bar, and a bar never comes up outside a lockout
	gun.barrel_heat = PLASMA_HEAT_MAX - 1
	gun.heat_updated_at = world.time
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT(gun.is_shut_down(), "The test shot didn't overheat the Furnace")
	TEST_ASSERT(!gun.vent_started_at, "An overheat with no player holding the Furnace brought the bar up")
	gun.shutdown_until = 0
	gun.barrel_heat = 90
	TEST_ASSERT(!gun.start_overheat_vent(user), "The overheat bar came up on a Furnace that isn't locked")

	// Gold: the lockout ends at once, the coils go cold, and the next shots add half heat. Nothing fires.
	TEST_ASSERT(overheat_with_bar(gun, user), "An overheat didn't bring the bar up for the gold test")
	var/chamber_before = gun.chamber_mol()
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(19)
	TEST_ASSERT(gun.try_fire_gun(far, user, ""), "A fire attempt on the overheat bar wasn't taken as the tap")
	TEST_ASSERT(!gun.vent_started_at, "A gold tap didn't end the overheat bar")
	TEST_ASSERT_NULL(gun.vent_bar, "A gold tap left the overheat bar")
	TEST_ASSERT(!gun.is_shut_down(), "A gold tap on the overheat bar left the lockout")
	TEST_ASSERT(gun.can_fire_heat(), "A Furnace can't fire after a gold tap on the overheat bar")
	TEST_ASSERT_EQUAL(gun.barrel_heat, 0, "A gold tap on the overheat bar left heat [gun.barrel_heat]")
	TEST_ASSERT_EQUAL(gun.gold_until, world.time + gun.gold_window, "A gold tap on the overheat bar gave no gold window")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), chamber_before, "The tap on the overheat bar fired a shot")

	// Amber: most of the heat vented and the lockout cut to 2 s from the overheat
	TEST_ASSERT(overheat_with_bar(gun, user), "An overheat didn't bring the bar up for the amber test")
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(14)
	var/expected_end = gun.vent_started_at + PLASMA_OVERHEAT_GRACE_LOCK
	gun.attack_self(user)
	TEST_ASSERT(!gun.vent_started_at, "An in-hand tap didn't end the overheat bar")
	TEST_ASSERT_EQUAL(gun.shutdown_until, expected_end, "An amber tap left the lockout ending at [gun.shutdown_until], not [expected_end]")
	TEST_ASSERT(gun.is_shut_down(), "An amber tap ended the lockout at once")
	TEST_ASSERT_EQUAL(gun.barrel_heat, PLASMA_HEAT_MAX - PLASMA_VENT_COOL, "An amber tap on the overheat bar left heat [gun.barrel_heat]")
	gun.shutdown_until = world.time
	TEST_ASSERT(gun.can_fire_heat(), "The Furnace stayed locked past an amber tap's 2 s")
	TEST_ASSERT_EQUAL(gun.barrel_heat, PLASMA_HEAT_MAX - PLASMA_VENT_COOL, "The lockout's end after an amber tap moved the heat to [gun.barrel_heat]")

	// No tap: the whole lockout
	TEST_ASSERT(overheat_with_bar(gun, user), "An overheat didn't bring the bar up for the no-tap test")
	gun.vent_started_at = world.time - PLASMA_VENT_SWEEP
	gun.finish_vent_sweep()
	TEST_ASSERT(!gun.vent_started_at, "The overheat bar's sweep end didn't end it")
	TEST_ASSERT_EQUAL(gun.shutdown_until, world.time + gun.overheat_shutdown, "A missed overheat bar changed the lockout")
	TEST_ASSERT_EQUAL(gun.barrel_heat, PLASMA_HEAT_MAX, "A missed overheat bar vented heat")
	TEST_ASSERT_EQUAL(gun.vent_lock_until, 0, "A missed overheat bar added a vent lock")

	// Dark red: the whole lockout, and the fumble's gas below ignition
	gun.cell.charge = PLASMA_CARTRIDGE_CAPACITY
	gun.chamber_changed()
	TEST_ASSERT(overheat_with_bar(gun, user), "An overheat didn't bring the bar up for the fumble test")
	chamber_before = gun.chamber_mol()
	var/turf_before = plasma_heat_test_plasma(air)
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(1)
	gun.try_fire_gun(far, user, "")
	var/lost = chamber_before - gun.chamber_mol()
	var/gained = plasma_heat_test_plasma(air) - turf_before
	TEST_ASSERT(!gun.vent_started_at, "A fumbled tap didn't end the overheat bar")
	TEST_ASSERT_EQUAL(gun.shutdown_until, world.time + gun.overheat_shutdown, "A fumbled overheat bar changed the lockout")
	TEST_ASSERT_EQUAL(lost, PLASMA_VENT_MOL, "A fumbled overheat bar took [lost] mol from a full chamber")
	TEST_ASSERT_EQUAL(gained, lost, "A fumbled overheat bar put [gained] mol on the turf but took [lost] mol from the chamber")
	TEST_ASSERT(air.return_temperature() < PLASMA_MINIMUM_BURN_TEMPERATURE, "A fumbled overheat bar left gas at [air.return_temperature()] K, hot enough to light")
	air.remove_ratio(1)

	// Dropping the gun takes the bar away and leaves the whole lockout
	TEST_ASSERT(overheat_with_bar(gun, user), "An overheat didn't bring the bar up for the drop test")
	user.dropItemToGround(gun)
	TEST_ASSERT(!gun.vent_started_at, "Dropping the Furnace didn't end the overheat bar")
	TEST_ASSERT(isnull(gun.vent_bar) && isnull(gun.vent_marker), "Dropping the Furnace left the overheat bar")
	TEST_ASSERT(!gun.vent_overheat, "Dropping the Furnace left it marked as venting an overheat")
	TEST_ASSERT_EQUAL(gun.shutdown_until, world.time + gun.overheat_shutdown, "Dropping the Furnace changed the lockout")
	user.put_in_active_hand(gun, forced = TRUE)
	TEST_ASSERT(!gun.vent_key(user), "A Furnace picked back up during its lockout started a vent")

	// Swapping hands does the same
	gun.shutdown_until = 0
	TEST_ASSERT(overheat_with_bar(gun, user), "An overheat didn't bring the bar up for the swap test")
	user.swap_hand()
	TEST_ASSERT(!gun.vent_started_at, "Swapping hands didn't end the overheat bar")
	TEST_ASSERT_EQUAL(gun.shutdown_until, world.time + gun.overheat_shutdown, "Swapping hands changed the lockout")
	user.swap_hand()

/datum/unit_test/voidcrew_plasma_heat_overheat_vent/Destroy()
	if(spot && saved_air)
		spot.return_air().copy_from(saved_air)
	return ..()

/// A Furnace locked from an overheat won't take a new cartridge or give up its own, by hand or not. A gold tap on the
/// overheat bar ends the lockout, and the cartridges change at once.
/datum/unit_test/voidcrew_plasma_heat_reload_lockout

/datum/unit_test/voidcrew_plasma_heat_reload_lockout/Run()
	var/turf/open/spot = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	var/obj/item/plasma_cartridge/fresh = allocate(/obj/item/plasma_cartridge)
	user.put_in_active_hand(gun, forced = TRUE)
	user.put_in_inactive_hand(fresh)
	TEST_ASSERT(user.is_holding(fresh), "Test fixture: the user isn't holding the spare cartridge")
	gun.cartridge_load_delay = 0
	var/obj/item/plasma_cartridge/seated = gun.cartridge

	gun.barrel_heat = PLASMA_HEAT_MAX - 1
	gun.heat_updated_at = world.time
	gun.add_heat(gun.heat_per_shot)
	TEST_ASSERT(gun.is_shut_down(), "Test fixture: the Furnace didn't overheat")
	TEST_ASSERT(!gun.load_cartridge(fresh, user), "A locked Furnace took a new cartridge")
	TEST_ASSERT(!gun.load_cartridge(fresh, null), "A locked Furnace took a new cartridge with no one loading it")
	TEST_ASSERT_EQUAL(gun.cartridge, seated, "A locked Furnace's cartridge changed")
	TEST_ASSERT(user.is_holding(fresh), "A refused cartridge left the user's hand")
	TEST_ASSERT_EQUAL(gun.click_alt(user), CLICK_ACTION_BLOCKING, "A locked Furnace let its cartridge out")
	TEST_ASSERT_EQUAL(gun.cartridge, seated, "A locked Furnace's cartridge came out")

	// Gold on the overheat bar: the lockout ends and the seat opens
	TEST_ASSERT(gun.start_overheat_vent(user), "The overheat bar didn't come up")
	gun.vent_started_at = world.time - plasma_heat_test_unit_time(19)
	gun.attack_self(user)
	TEST_ASSERT(!gun.is_shut_down(), "A gold tap on the overheat bar left the lockout")
	TEST_ASSERT_EQUAL(gun.click_alt(user), CLICK_ACTION_SUCCESS, "A Furnace after a gold tap wouldn't let its cartridge out")
	TEST_ASSERT_NULL(gun.cartridge, "The cartridge stayed seated after unloading")
	TEST_ASSERT(gun.load_cartridge(fresh, user), "A Furnace after a gold tap wouldn't take a new cartridge")
	TEST_ASSERT_EQUAL(gun.cartridge, fresh, "The new cartridge isn't seated")
