// Package: P4 frontier lasers. Unit tests for voidcrew/modules/plasma_weapons/.

/// The Kestrel and Hornet fire the right projectiles; the Hornet's is a light laser, not the stock one.
/datum/unit_test/voidcrew_frontier_laser_projectiles/Run()
	var/obj/item/ammo_casing/energy/pistol_casing = /obj/item/ammo_casing/energy/frontier_laser
	TEST_ASSERT_EQUAL(initial(pistol_casing.projectile_type), /obj/projectile/beam/laser/frontier_pistol, "The Kestrel casing fires the wrong projectile")
	var/obj/projectile/pistol_beam = /obj/projectile/beam/laser/frontier_pistol
	TEST_ASSERT_EQUAL(initial(pistol_beam.damage), 20, "The Kestrel beam does not do 20 damage")

	var/obj/item/ammo_casing/energy/smg_casing = /obj/item/ammo_casing/energy/lasergun/frontier_smg
	TEST_ASSERT_EQUAL(initial(smg_casing.projectile_type), /obj/projectile/beam/laser/frontier_smg, "The Hornet casing fires the wrong projectile")
	TEST_ASSERT_EQUAL(/obj/projectile/beam/laser/frontier_smg::damage, 10, "The Hornet beam does not do 10 damage")
	TEST_ASSERT_EQUAL(/obj/projectile/beam/laser::damage, 25, "The stock laser's damage changed")
	TEST_ASSERT(/obj/projectile/beam/laser/frontier_smg::hitscan, "The Hornet beam is not hitscan")

	var/obj/item/gun/energy/pistol = allocate(/obj/item/gun/energy/frontier_laser/pistol)
	var/obj/item/ammo_casing/energy/pistol_shot = pistol.ammo_type[1]
	TEST_ASSERT_EQUAL(pistol_shot.type, /obj/item/ammo_casing/energy/frontier_laser, "The Kestrel loads the wrong casing")
	TEST_ASSERT_EQUAL(pistol.fire_delay, 5, "The Kestrel does not fire every 0.5 seconds")

	var/obj/item/gun/energy/smg = allocate(/obj/item/gun/energy/frontier_laser/smg)
	var/obj/item/ammo_casing/energy/smg_shot = smg.ammo_type[1]
	TEST_ASSERT_EQUAL(smg_shot.type, /obj/item/ammo_casing/energy/lasergun/frontier_smg, "The Hornet loads the wrong casing")
	var/datum/component/automatic_fire/autofire = smg.GetComponent(/datum/component/automatic_fire)
	TEST_ASSERT_NOTNULL(autofire, "The Hornet is not automatic")
	TEST_ASSERT_EQUAL(autofire.autofire_shot_delay, 0.15 SECONDS, "The Hornet does not fire every 0.15 seconds")
	TEST_ASSERT_EQUAL(smg.fire_delay, 0, "The Hornet's fire delay would hold its automatic fire back")
	TEST_ASSERT_EQUAL(smg.spread, 20, "The Hornet's spread is not 20")

	for(var/obj/item/gun/energy/gun as anything in list(pistol, smg))
		TEST_ASSERT(!istype(gun, /obj/item/gun/energy/laser), "[gun.type] is a laser gun subtype, so the laser export and slapcraft would take it")

/// A full standard cell gives the Kestrel exactly 20 shots and the Hornet 40.
/datum/unit_test/voidcrew_frontier_laser_shots/Run()
	var/list/shots_by_gun = list(/obj/item/gun/energy/frontier_laser/pistol = 20, /obj/item/gun/energy/frontier_laser/smg = 40)
	for(var/gun_type in shots_by_gun)
		var/obj/item/gun/energy/gun = allocate(gun_type)
		var/obj/item/ammo_casing/energy/shot = gun.ammo_type[1]
		TEST_ASSERT_EQUAL(gun.cell.charge, gun.cell.maxcharge, "[gun_type] did not spawn with a full cell")
		TEST_ASSERT_EQUAL(round(gun.cell.maxcharge / shot.e_cost), shots_by_gun[gun_type], "[gun_type] does not hold [shots_by_gun[gun_type]] shots")

/// Both guns go into a recharger and charge there.
/datum/unit_test/voidcrew_frontier_laser_recharge/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/machinery/recharger/charger = allocate(/obj/machinery/recharger, run_loc_floor_bottom_left)
	for(var/gun_type in list(/obj/item/gun/energy/frontier_laser/pistol, /obj/item/gun/energy/frontier_laser/smg))
		var/obj/item/gun/energy/gun = allocate(gun_type)
		TEST_ASSERT(gun.can_charge, "[gun_type] refuses rechargers")
		gun.cell.charge = 0
		TEST_ASSERT(user.put_in_active_hand(gun), "The user could not hold [gun_type]")
		charger.attackby(gun, user)
		TEST_ASSERT_EQUAL(charger.charging, gun, "The recharger did not take [gun_type]")
		charger.process(10)
		TEST_ASSERT(gun.cell.charge > 0, "The recharger did not charge [gun_type]")
		gun.forceMove(run_loc_floor_bottom_left)
		TEST_ASSERT_NULL(charger.charging, "The recharger still holds [gun_type] after it left")
