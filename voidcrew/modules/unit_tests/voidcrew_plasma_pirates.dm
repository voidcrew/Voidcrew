// Package: P6 NPCs. Unit tests for voidcrew/modules/plasma_weapons/.
//
// Fork defines are included after the tests, so zones appear as their literal numbers
// (1 is ZONE_GREEN, 2 is ZONE_YELLOW, 3 is ZONE_RED).

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_plasma_pirates
	abstract_type = /datum/unit_test/voidcrew_plasma_pirates
	/// Mobs a test spawned through spawn_npc_in_zone(), deleted when it ends
	var/list/spawned = list()

/datum/unit_test/voidcrew_plasma_pirates/Destroy()
	QDEL_LIST(spawned)
	return ..()

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner (the room is 5x5)
/datum/unit_test/voidcrew_plasma_pirates/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A `mob_type` spawned for `zone`, as a ship or ruin spawns it
/datum/unit_test/voidcrew_plasma_pirates/proc/spawn_in_zone(mob_type, zone, turf/where)
	var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, zone)
	var/mob/living/spawned_mob = spawn_npc_in_zone(mob_type, where, context)
	spawned += spawned_mob
	return spawned_mob

/// A gunner handed a plasma loadout fires real plasma bolts, and its magazine is the loadout's
/datum/unit_test/voidcrew_plasma_pirates/loadouts

/datum/unit_test/voidcrew_plasma_pirates/loadouts/Run()
	var/datum/pirate_gun_loadout/pistol_loadout = GLOB.pirate_gun_loadouts[/datum/pirate_gun_loadout/plasma_pistol]
	var/datum/pirate_gun_loadout/rifle_loadout = GLOB.pirate_gun_loadouts[/datum/pirate_gun_loadout/plasma_rifle]
	TEST_ASSERT_NOTNULL(pistol_loadout, "The plasma pistol loadout has no shared copy")
	TEST_ASSERT_NOTNULL(rifle_loadout, "The plasma rifle loadout has no shared copy")
	TEST_ASSERT_EQUAL(pistol_loadout.magazine_size(), 15, "A plasma pistol cartridge isn't 15 shots")
	TEST_ASSERT_EQUAL(rifle_loadout.magazine_size(), 12, "A plasma rifle cartridge isn't 12 shots")
	var/obj/projectile/heavy = rifle_loadout.make_projectile(spot(4, 4))
	TEST_ASSERT(istype(heavy, /obj/projectile/energy/plasma_bolt/heavy), "The plasma rifle loadout fires [heavy?.type], not a heavy plasma bolt")
	qdel(heavy)

	var/mob/living/basic/trooper/pirate/ranged/gunner = allocate(/mob/living/basic/trooper/pirate/ranged, spot(0, 2))
	TEST_ASSERT_EQUAL(pirate_crew_arm(gunner, /datum/pirate_gun_loadout/plasma_pistol), pistol_loadout, "A gunner couldn't be handed a plasma pistol")
	var/datum/component/pirate_gun/gun = pirate_gun_of(gunner)
	TEST_ASSERT_NOTNULL(gun, "A gunner handed a plasma pistol has no gun")
	TEST_ASSERT_NULL(gunner.GetComponent(/datum/component/ranged_attacks), "A plasma gunner kept its stock shot")
	TEST_ASSERT_EQUAL(gunner.r_hand, /obj/item/gun/energy/plasma_weapon/pistol, "A plasma gunner holds a different gun")
	var/mob/living/carbon/human/consistent/mark = allocate(/mob/living/carbon/human/consistent, spot(4, 2))
	gun.aim_ref = WEAKREF(mark)
	var/obj/projectile/shot = gun.shoot_once(gun.serial)
	TEST_ASSERT(istype(shot, /obj/projectile/energy/plasma_bolt), "A plasma gunner fired [shot?.type], not a plasma bolt")
	TEST_ASSERT_EQUAL(shot.firer, gunner, "A plasma bolt doesn't know who fired it")
	qdel(shot)
	var/full = gun.ammo
	TEST_ASSERT(gun.try_fire(mark), "A loaded plasma pistol wouldn't fire")
	TEST_ASSERT_EQUAL(gun.ammo, full - 2, "A plasma pistol pair didn't use two shots")

/// Green-zone pirates never roll plasma; yellow adds the pistol; red adds both. The faction's own list is untouched.
/datum/unit_test/voidcrew_plasma_pirates/zone_weights

/datum/unit_test/voidcrew_plasma_pirates/zone_weights/Run()
	// By zone: green, yellow, red
	var/list/expected = list(
		list(),
		list(/datum/pirate_gun_loadout/plasma_pistol),
		list(/datum/pirate_gun_loadout/plasma_pistol, /datum/pirate_gun_loadout/plasma_rifle),
	)
	var/list/plasma_types = list(/datum/pirate_gun_loadout/plasma_pistol, /datum/pirate_gun_loadout/plasma_rifle)
	for(var/zone in 1 to 3)
		var/mob/living/basic/trooper/pirate/faction/irs/ranged/gunner = spawn_in_zone(/mob/living/basic/trooper/pirate/faction/irs/ranged, zone, spot(0, zone))
		var/list/weights = pirate_gun_weights_for(gunner)
		TEST_ASSERT(length(weights), "A zone [zone] IRS gunner has no gun weights")
		for(var/plasma_type in plasma_types)
			var/wanted = (plasma_type in expected[zone])
			TEST_ASSERT_EQUAL(!!weights[plasma_type], wanted, "A zone [zone] gunner's weights [wanted ? "lack" : "include"] [plasma_type]")
		for(var/stock_type in gunner.crew_gun_weights)
			TEST_ASSERT_EQUAL(weights[stock_type], gunner.crew_gun_weights[stock_type], "A zone [zone] gunner's weight for [stock_type] changed")
		TEST_ASSERT_NULL(gunner.crew_gun_weights[/datum/pirate_gun_loadout/plasma_pistol], "Plasma weights were written into the IRS faction's own list")
		var/mob/living/basic/trooper/pirate/ranged/generic = spawn_in_zone(/mob/living/basic/trooper/pirate/ranged, zone, spot(1, zone))
		var/list/generic_weights = pirate_gun_weights_for(generic)
		TEST_ASSERT_EQUAL(!!generic_weights[/datum/pirate_gun_loadout/plasma_pistol], zone != 1, "A plain zone [zone] pirate's plasma pistol weight is wrong")
	TEST_ASSERT_NULL(GLOB.pirate_gun_default_weights[/datum/pirate_gun_loadout/plasma_pistol], "Plasma weights were written into the default list")
	var/mob/living/basic/trooper/pirate/faction/medieval/ranged/archer = spawn_in_zone(/mob/living/basic/trooper/pirate/faction/medieval/ranged, 3, spot(2, 1))
	TEST_ASSERT_NULL(pirate_gun_weights_for(archer), "A red-zone crossbowman would trade his crossbow for a gun")

/// The red-zone Director Prime and Chief Auditor carry a Furnace; elsewhere they keep their stock shot. Both can drop the Old Furnace.
/datum/unit_test/voidcrew_plasma_pirates/bosses

/datum/unit_test/voidcrew_plasma_pirates/bosses/Run()
	var/list/boss_types = list(/mob/living/basic/trooper/pirate/faction/boss/interdyne, /mob/living/basic/trooper/pirate/faction/boss/irs)
	var/row = 0
	for(var/boss_type in boss_types)
		for(var/zone in 1 to 3)
			var/mob/living/basic/trooper/pirate/faction/boss/boss = spawn_in_zone(boss_type, zone, spot(row, zone))
			var/datum/component/pirate_gun/gun = pirate_gun_of(boss)
			TEST_ASSERT(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace in boss.rare_loot_pool, "[boss_type] can't drop the Old Furnace")
			if(zone == 3)
				TEST_ASSERT_NOTNULL(gun, "A red-zone [boss_type] carries no Furnace")
				TEST_ASSERT_EQUAL(gun.loadout.type, /datum/pirate_gun_loadout/plasma_rifle, "A red-zone [boss_type] carries [gun.loadout.type]")
				TEST_ASSERT_NULL(boss.GetComponent(/datum/component/ranged_attacks), "A red-zone [boss_type] kept its stock shot as well as its Furnace")
				TEST_ASSERT_EQUAL(boss.r_hand, /obj/item/gun/energy/plasma_weapon/rifle, "A red-zone [boss_type] holds a different gun from its Furnace")
				boss.apply_npc_weapon_ladder()
				TEST_ASSERT_EQUAL(pirate_gun_of(boss), gun, "A red-zone [boss_type] was armed twice")
			else
				TEST_ASSERT(!(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace in boss.rolled_rare_loot), "A zone [zone] [boss_type] kept an Old Furnace roll")
				TEST_ASSERT_NULL(gun, "A zone [zone] [boss_type] carries a pirate gun")
				TEST_ASSERT_NOTNULL(boss.GetComponent(/datum/component/ranged_attacks), "A zone [zone] [boss_type] lost its stock shot")
		row++

	// The roll itself: kept by a red-zone boss, dropped by any other
	for(var/zone in 1 to 3)
		var/mob/living/basic/trooper/pirate/faction/boss/irs/roller = allocate(/mob/living/basic/trooper/pirate/faction/boss/irs, spot(4, zone))
		roller.rolled_rare_loot = list(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace)
		roller.weapon_loot_initialized = FALSE
		roller.initialize_weapon_loot(zone)
		TEST_ASSERT_EQUAL((/obj/item/gun/energy/plasma_weapon/rifle/old_furnace in roller.rolled_rare_loot), zone == 3, "A zone [zone] boss's Old Furnace roll was [zone == 3 ? "dropped" : "kept"]")
