/**
 * Planet-native factions are additive, per footprint, and independent of spawn source.
 *
 * This models the reported wasteland-bar case: a mapped hermit with a `saloon` override
 * exists before its planet is registered, then a pirate is spawned there later. They must
 * retain those distinct role factions while sharing the planet alliance. A pirate born on
 * a second footprint on the same z-level must not receive the first planet's alliance.
 */
/datum/unit_test/voidcrew_planetary_factions

/// Check real death drops, including corpse equipment, rather than visual weapons.
/datum/unit_test/voidcrew_melee_death_drops/Run()
	var/list/mob_loot = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/captain = list(/obj/item/claymore/shortsword),
		/mob/living/basic/trooper/pirate/faction/lustrous/captain = list(/obj/item/claymore/shortsword),
		/mob/living/basic/trooper/pirate/faction/interdyne/captain = list(/obj/item/claymore/shortsword),
		/mob/living/basic/trooper/pirate/faction/boss/silverscale = list(
			/obj/item/clothing/suit/hooded/cloak/drake,
			/obj/item/clothing/head/hooded/cloakhood/drake,
		),
		/mob/living/basic/trooper/pirate/faction/boss/skeleton = list(/obj/item/gun/ballistic/shotgun/hook),
		/mob/living/basic/skeleton/templar = list(
			/obj/effect/decal/remains/human,
			/obj/item/clothing/suit/chaplainsuit/armor/templar,
			/obj/item/clothing/head/helmet/chaplain,
			/obj/item/hatchet,
		),
	)
	var/turf/death_turf = run_loc_floor_bottom_left
	for(var/mob_type in mob_loot)
		var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 2)
		var/mob/living/basic/victim = spawn_npc_in_zone(mob_type, death_turf, context)
		// Keep the original body to exercise the repeated-death guard safely.
		victim.basic_mob_flags &= ~DEL_ON_DEATH
		var/list/before_death = death_turf.get_all_contents()
		var/list/expected_loot = mob_loot[mob_type].Copy()
		if(istype(victim, /mob/living/basic/trooper/pirate/faction))
			expected_loot += list(/mob/living/carbon/human, /obj/item/holochip)
		victim.death()
		TEST_ASSERT_EQUAL(victim.stat, DEAD, "[mob_type] must actually die")
		var/list/drops = death_turf.contents - before_death
		for(var/drop_type in expected_loot)
			var/count = 0
			for(var/atom/movable/drop in drops)
				if(istype(drop, drop_type))
					count++
			TEST_ASSERT_EQUAL(count, 1, "[mob_type] must drop [drop_type] exactly once")

		var/expected_count = length(expected_loot)
		if(istype(victim, /mob/living/basic/trooper/pirate/faction))
			var/mob/living/basic/trooper/pirate/faction/pirate = victim
			var/is_boss = istype(pirate, /mob/living/basic/trooper/pirate/faction/boss)
			var/obj/item/holochip/payment = locate() in drops
			TEST_ASSERT_NOTNULL(payment, "[mob_type] must retain its credit drop")
			TEST_ASSERT_EQUAL(payment.credits, is_boss ? 3000 : 1000, "[mob_type] must retain its payout")
			if(!is_boss)
				var/auxiliary_count = 0
				for(var/obj/item/drop in drops)
					if(drop.type in pirate.random_loot_2)
						auxiliary_count++
				TEST_ASSERT_EQUAL(auxiliary_count, 1, "[mob_type] must retain one auxiliary drop")
				expected_count++
		TEST_ASSERT_EQUAL(length(drops), expected_count, "[mob_type] emitted extra or missing death drops")
		var/list/all_drops = death_turf.get_all_contents() - before_death
		for(var/obj/item/drop in all_drops)
			TEST_ASSERT(!istype(drop, /obj/item/claymore/cutlass), "[mob_type] still drops a cutlass")
			TEST_ASSERT(!istype(drop, /obj/item/claymore/weak), "[mob_type] still drops a holy sword")

		var/list/after_death = death_turf.get_all_contents()
		victim.death()
		TEST_ASSERT_EQUAL(length(death_turf.get_all_contents() - after_death), 0, "A repeated death call duplicated [mob_type]'s loot")
		victim.revive(ADMIN_HEAL_ALL)
		victim.death()
		TEST_ASSERT_EQUAL(length(death_turf.get_all_contents() - after_death), 0, "Reviving [mob_type] refilled its corpse or weapons")
		for(var/atom/movable/drop in drops)
			qdel(drop)
		qdel(victim)

/// Every ordinary faction/style uses one pinned weapon draw and one corpse.
/datum/unit_test/voidcrew_pirate_ladder_drops/Run()
	var/list/green = list(/obj/item/knife/combat/survival, /obj/item/spear, /obj/item/melee/baseball_bat)
	var/list/yellow = npc_ladder_yellow_melee()
	for(var/family in list("grey", "skeleton", "silverscale", "lustrous", "interdyne", "irs", "medieval"))
		for(var/style in list("melee", "ranged"))
			var/mob_type = text2path("/mob/living/basic/trooper/pirate/faction/[family]/[style]")
			TEST_ASSERT_NOTNULL(mob_type, "Missing faction/style [family]/[style]")
			for(var/zone in 1 to 3)
				var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, zone)
				var/mob/living/basic/trooper/pirate/faction/pirate = spawn_npc_in_zone(mob_type, run_loc_floor_top_right, context)
				TEST_ASSERT(pirate.basic_mob_flags & DEL_ON_DEATH, "[mob_type] lost deletion on death")
				pirate.basic_mob_flags &= ~DEL_ON_DEATH
				pirate.forceMove(run_loc_floor_bottom_left)
				var/list/before = run_loc_floor_bottom_left.get_all_contents()
				pirate.death()
				var/list/drops = run_loc_floor_bottom_left.get_all_contents() - before
				var/weapons = 0
				var/corpses = 0
				for(var/atom/drop in drops)
					if(ishuman(drop))
						corpses++
					if(!isitem(drop))
						continue
					if(drop.type in (zone == 1 ? green : yellow))
						weapons++
					else if(istype(drop, /obj/item/gun))
						weapons++
						var/expected_gun = zone == 2 ? /obj/item/gun/energy/laser : /obj/item/gun/ballistic/automatic/c20r/unrestricted
						TEST_ASSERT(zone != 1 && drop.type == expected_gun, "[mob_type]/[zone] emitted a gun outside its spawn-zone pool")
					TEST_ASSERT(!istype(drop, /obj/item/claymore/cutlass) && !istype(drop, /obj/item/melee/energy/sword) && !istype(drop, /obj/item/switchblade) && !istype(drop, /obj/item/pen/edagger), "[mob_type] emitted a former weapon or corpse duplicate")
				TEST_ASSERT_EQUAL(weapons, 1, "[mob_type]/[zone] must pay exactly one weapon including corpse equipment")
				TEST_ASSERT_EQUAL(corpses, 1, "[mob_type] must leave exactly one corpse")
				var/list/after = run_loc_floor_bottom_left.get_all_contents()
				pirate.revive(ADMIN_HEAL_ALL)
				pirate.death(TRUE)
				TEST_ASSERT_EQUAL(length(run_loc_floor_bottom_left.get_all_contents() - after), 0, "Revival/gibbing duplicated [mob_type]'s payout")
				for(var/atom/movable/drop in run_loc_floor_bottom_left.contents - before)
					qdel(drop)
				qdel(pirate)

/// Enumerate the Bernoulli inputs, avoiding statistical rate assertions.
/datum/unit_test/voidcrew_pirate_ladder_odds/Run()
	var/mob/living/basic/trooper/pirate/faction/pirate = allocate(/mob/living/basic/trooper/pirate/faction)
	var/list/green_counts = list()
	var/yellow_guns = 0
	var/red_guns = 0
	var/red_prizes = 0
	for(var/roll in 1 to 100)
		var/green_type = pirate.roll_ladder_weapon(1, roll)
		green_counts[green_type]++
		var/yellow_type = pirate.roll_ladder_weapon(2, roll)
		var/red_type = pirate.roll_ladder_weapon(3, roll)
		if(ispath(yellow_type, /obj/item/gun))
			yellow_guns++
			TEST_ASSERT_EQUAL(yellow_type, /obj/item/gun/energy/laser, "Yellow pirates must roll a laser")
		else
			TEST_ASSERT(yellow_type in npc_ladder_yellow_melee(), "Yellow pirate drew non-ladder melee")
		if(ispath(red_type, /obj/item/gun))
			red_guns++
			TEST_ASSERT_EQUAL(red_type, /obj/item/gun/ballistic/automatic/c20r/unrestricted, "Red pirates must roll an unrestricted C20r")
		else
			TEST_ASSERT(red_type in npc_ladder_yellow_melee(), "Red pirate drew non-ladder melee")
		red_prizes += npc_ladder_red_drop(roll)
	TEST_ASSERT_EQUAL(green_counts[/obj/item/knife/combat/survival], 50, "Green survival knife chance changed")
	TEST_ASSERT_EQUAL(green_counts[/obj/item/spear], 25, "Green spear chance changed")
	TEST_ASSERT_EQUAL(green_counts[/obj/item/melee/baseball_bat], 25, "Green bat chance changed")
	TEST_ASSERT_EQUAL(yellow_guns, 5, "Yellow pirate gun chance changed")
	TEST_ASSERT_EQUAL(red_guns, 10, "Red pirate gun chance changed")
	TEST_ASSERT_EQUAL(red_prizes, 25, "Physical red boss weapons must roll at 25 percent")

/// Fixed captain and boss prizes cannot also hide weapons in corpse slots.
/datum/unit_test/voidcrew_pirate_fixed_ladder/Run()
	var/list/prizes = list(
		/mob/living/basic/trooper/pirate/faction/skeleton/captain = /obj/item/gun/energy/laser,
		/mob/living/basic/trooper/pirate/faction/irs/captain = /obj/item/gun/energy/laser,
		/mob/living/basic/trooper/pirate/faction/medieval/captain = /obj/item/fireaxe,
		/mob/living/basic/trooper/pirate/faction/boss/irs = /obj/item/gun/energy/laser,
		/mob/living/basic/trooper/pirate/faction/boss/medieval = /obj/item/claymore/shortsword,
		/mob/living/basic/trooper/pirate/faction/boss/interdyne = /obj/item/gun/syringe/syndicate,
		/mob/living/basic/trooper/pirate/faction/boss/grey = /obj/item/storage/toolbox/mechanical/old/clean,
		/mob/living/basic/trooper/pirate/faction/boss/lustrous = /obj/item/cain_and_abel,
	)
	var/turf/floor = run_loc_floor_bottom_left
	for(var/mob_type in prizes)
		var/datum/npc_spawn_context/context = allocate(/datum/npc_spawn_context, src, 3)
		var/mob/living/basic/trooper/pirate/faction/pirate = spawn_npc_in_zone(mob_type, floor, context)
		var/expected = length(pirate.rare_loot_pool) ? (prizes[mob_type] in pirate.rolled_rare_loot) : 1
		var/list/before = floor.get_all_contents()
		pirate.death(TRUE)
		var/count = 0
		for(var/obj/item/drop in floor.get_all_contents() - before)
			if(drop.type == prizes[mob_type])
				count++
			TEST_ASSERT(!istype(drop, /obj/item/fireaxe/boardingaxe) && !istype(drop, /obj/item/gun/magic/midas_hand) && !istype(drop, /obj/item/gun/energy/e_gun/nuclear), "[mob_type] retained an obsolete corpse/boss weapon")
		TEST_ASSERT_EQUAL(count, expected, "[mob_type] emitted the wrong number of its fixed/rolled prize")
		for(var/atom/movable/drop in floor.contents - before)
			qdel(drop)

/// Crusher and ordinary lists share the original rare roll and keep utility loot.
/datum/unit_test/voidcrew_megafauna_ladder/Run()
	var/list/weapons = list(
		/mob/living/simple_animal/hostile/megafauna/blood_drunk_miner = /obj/item/melee/cleaving_saw,
		/mob/living/simple_animal/hostile/megafauna/hierophant = /obj/item/hierophant_club,
	)
	for(var/mob_type in weapons)
		var/mob/living/simple_animal/hostile/megafauna/boss = allocate(mob_type)
		var/weapon_type = weapons[mob_type]
		TEST_ASSERT_EQUAL((weapon_type in boss.loot), boss.npc_red_weapon_drop, "Ordinary list ignored the original boss roll")
		TEST_ASSERT_EQUAL((weapon_type in boss.crusher_loot), boss.npc_red_weapon_drop, "Crusher list rerolled the boss weapon")
		if(istype(boss, /mob/living/simple_animal/hostile/megafauna/blood_drunk_miner))
			TEST_ASSERT(/obj/item/gun/energy/recharge/kinetic_accelerator in boss.loot, "Miner lost its guaranteed work tool")
			TEST_ASSERT(/obj/item/crusher_trophy/miner_eye in boss.crusher_loot, "Miner lost its crusher trophy")
		else
			TEST_ASSERT(/obj/item/crusher_trophy/vortex_talisman in boss.crusher_loot, "Hierophant lost its crusher trophy")
		qdel(boss)
	for(var/weapon_drop in list(FALSE, TRUE))
		for(var/crusher in list(FALSE, TRUE))
			var/turf/floor = run_loc_floor_bottom_left
			var/mob/living/simple_animal/hostile/megafauna/colossus/boss = allocate(/mob/living/simple_animal/hostile/megafauna/colossus, floor)
			boss.npc_red_weapon_drop = weapon_drop
			boss.true_spawn = FALSE
			boss.del_on_death = FALSE
			if(crusher)
				boss.spawn_crusher_loot()
			var/list/before = floor.get_all_contents()
			boss.health = 0
			boss.death()
			var/obj/structure/closet/crate/necropolis/colossus/chest = locate() in floor
			TEST_ASSERT_NOTNULL(chest, "Colossus death did not create a chest")
			TEST_ASSERT_EQUAL(chest.ladder_weapon_drop, weapon_drop, "Chest lost its original boss's roll")
			chest.open(null, TRUE, FALSE)
			TEST_ASSERT_EQUAL(length(floor.get_all_contents_type(/obj/item/cain_and_abel)), weapon_drop, "Colossus chest ignored its pinned weapon roll")
			TEST_ASSERT_EQUAL(length(floor.get_all_contents_type(/obj/item/crusher_trophy/blaster_tubes)), crusher, "Colossus chest lost or added a crusher trophy")
			var/list/after = floor.get_all_contents()
			boss.revive(ADMIN_HEAL_ALL)
			boss.health = 0
			boss.death()
			TEST_ASSERT_EQUAL(length(floor.get_all_contents() - after), 0, "Revived Colossus printed another chest")
			for(var/atom/movable/drop in floor.contents - before)
				qdel(drop)
			qdel(boss)

/// The hoard keeps its nonweapon payout and consumes its original staff roll once.
/datum/unit_test/voidcrew_lich_ladder_hoard
	var/saved_hoard_spent
	var/obj/structure/overmap/space_ruin/lich_lair/saved_site
	var/state_saved = FALSE

/datum/unit_test/voidcrew_lich_ladder_hoard/Destroy()
	if(state_saved)
		GLOB.lich_hoard_dropped = saved_hoard_spent
		GLOB.lich_lair = saved_site
	saved_site = null
	return ..()

/datum/unit_test/voidcrew_lich_ladder_hoard/Run()
	saved_hoard_spent = GLOB.lich_hoard_dropped
	saved_site = GLOB.lich_lair
	state_saved = TRUE
	GLOB.lich_lair = null
	var/turf/floor = run_loc_floor_bottom_left
	var/mob/living/basic/lich/lich = allocate(/mob/living/basic/lich, floor)
	for(var/weapon_drop in list(FALSE, TRUE))
		GLOB.lich_hoard_dropped = FALSE
		lich.npc_red_weapon_drop = weapon_drop
		var/list/before = list()
		for(var/turf/tile in range(1, floor))
			before |= tile.get_all_contents()
		TEST_ASSERT_NOTNULL(drop_lich_hoard(lich), "Lich did not pay its hoard")
		var/list/after = list()
		for(var/turf/tile in range(1, floor))
			after |= tile.get_all_contents()
		var/staves = 0
		var/items = 0
		for(var/obj/item/drop in after - before)
			items++
			if(istype(drop, /obj/item/melee/verdigris_staff))
				staves++
		TEST_ASSERT_EQUAL(staves, weapon_drop, "Lich hoard ignored its original staff roll")
		TEST_ASSERT_EQUAL(items, length(GLOB.lich_hoard_contents) - 1 + weapon_drop, "Lich lost a nonweapon hoard item")
		TEST_ASSERT_NULL(drop_lich_hoard(lich), "A repeated lich payout rerolled its staff or hoard")
		for(var/atom/movable/drop in after - before)
			qdel(drop)

/// Unguarded cave weapons keep exactly their old combined weights.
/datum/unit_test/voidcrew_cave_ladder_pools/Run()
	for(var/cave_type in list(/obj/structure/spawner/cave, /obj/structure/spawner/cave/beach))
		var/obj/structure/spawner/cave/cave = allocate(cave_type)
		TEST_ASSERT_EQUAL(cave.caveloot["green_melee"], istype(cave, /obj/structure/spawner/cave/beach) ? 35 : 38, "Cave weapon substitution changed its combined weight")
		for(var/entry in cave.caveloot)
			if(ispath(entry))
				TEST_ASSERT(!ispath(entry, /obj/item/gun) && !ispath(entry, /obj/item/kinetic_crusher) && !ispath(entry, /obj/item/spear/explosive) && !ispath(entry, /obj/item/melee/greykingsword) && !ispath(entry, /obj/item/melee/energy/sword), "Cave retained a former weapon payout")

/datum/unit_test/voidcrew_planetary_factions/Run()
	var/datum/space_level/test_level = SSmapping.z_list[run_loc_floor_bottom_left.z]
	if(!test_level)
		TEST_FAIL("The unit-test z-level has no /datum/space_level to attach footprints to")
		return

	// String literals because voidcrew defines are included after the unit-test files in
	// the DME. set_rect() reduces each temporary planet to one unambiguous test tile.
	var/datum/map_footprint/bar_planet = allocate(/datum/map_footprint, null, "planet", 1)
	bar_planet.attach_level(test_level)
	bar_planet.set_rect(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y, 1, 1)

	var/datum/map_footprint/distant_planet = allocate(/datum/map_footprint, null, "planet", 2)
	distant_planet.attach_level(test_level)
	distant_planet.set_rect(run_loc_floor_top_right.x, run_loc_floor_top_right.y, 1, 1)
	distant_planet.enable_planetary_faction()

	// This represents a mob already initialized from a preloaded ruin before the planet's
	// footprint was enabled. The mapped override replaces its normal type factions.
	var/mob/living/simple_animal/hostile/asteroid/hermit/survivor/mapped_hermit = allocate(
		/mob/living/simple_animal/hostile/asteroid/hermit/survivor,
		run_loc_floor_bottom_left,
	)
	mapped_hermit.faction = list("saloon", "[REF(mapped_hermit)]")

	bar_planet.enable_planetary_faction()
	bar_planet.add_planetary_faction_to_existing_mobs()

	// These two go through /mob/living/Initialize after both footprint factions exist.
	var/mob/living/basic/trooper/pirate/melee/local_pirate = allocate(
		/mob/living/basic/trooper/pirate/melee,
		run_loc_floor_bottom_left,
	)
	var/mob/living/basic/trooper/pirate/melee/distant_pirate = allocate(
		/mob/living/basic/trooper/pirate/melee,
		run_loc_floor_top_right,
	)

	TEST_ASSERT(bar_planet.planetary_faction != distant_planet.planetary_faction, \
		"Two planetary footprints generated the same native faction token")
	TEST_ASSERT("saloon" in mapped_hermit.faction, \
		"The preloaded hermit's mapped saloon faction was replaced by the planet faction")
	TEST_ASSERT("pirate" in local_pirate.faction, \
		"The dynamically spawned pirate lost its pirate role faction")
	TEST_ASSERT(bar_planet.planetary_faction in mapped_hermit.faction, \
		"The preloaded hermit did not receive its footprint's planet faction")
	TEST_ASSERT(bar_planet.planetary_faction in local_pirate.faction, \
		"A mob created on the bar planet did not inherit its footprint faction")
	TEST_ASSERT(distant_planet.planetary_faction in distant_pirate.faction, \
		"A mob created on the second planet did not inherit that footprint's faction")
	TEST_ASSERT(!(bar_planet.planetary_faction in distant_pirate.faction), \
		"A mob on the second footprint inherited the neighbouring planet's faction")
	TEST_ASSERT(mapped_hermit.faction_check_atom(local_pirate), \
		"The saloon hermit and dynamically spawned pirate on one planet still consider each other hostile")
	TEST_ASSERT(!mapped_hermit.faction_check_atom(distant_pirate), \
		"The saloon hermit became friendly with a mob on a different planetary footprint")

/// A surface cloning vat must not make its player kin to every local hunting target.
/datum/unit_test/voidcrew_planetary_factions_clone/Run()
	var/turf/surface = run_loc_floor_bottom_left
	var/datum/map_footprint/planet = allocate(/datum/map_footprint, null, "planet", 1)
	planet.attach_level(SSmapping.z_list[surface.z])
	planet.set_rect(surface.x, surface.y, 2, 1)
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent, surface)
	donor.mind_initialize()
	planet.enable_planetary_faction()
	planet.add_planetary_faction_to_existing_mobs()
	TEST_ASSERT(!(planet.planetary_faction in donor.faction), "Registering a planet must not ally an existing player body with its wildlife.")
	var/obj/machinery/cloning_vat/vat = allocate(/obj/machinery/cloning_vat, surface)
	vat.do_imprint(donor)
	var/mob/living/carbon/human/clone = vat.create_clone_body()
	allocated += clone
	TEST_ASSERT_NULL(clone.mind, "The fresh clone must be checked before the player's mind arrives.")
	TEST_ASSERT(!(planet.planetary_faction in clone.faction), "A fresh clone inside a surface vat must not inherit the planet's faction.")
	donor.mind.transfer_to(clone)
	clone.forceMove(surface)
	planet.add_planetary_faction_to_existing_mobs()
	TEST_ASSERT(!(planet.planetary_faction in clone.faction), "A planet's later faction pass must also exclude the claimed clone.")
	TEST_ASSERT(REF(clone) in clone.faction, "The clone must retain its own faction identity.")
	var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(surface, EAST))
	TEST_ASSERT(planet.planetary_faction in quarry.faction, "The same planet must still ally its native wildlife.")
	var/list/quarry_gates = list(
		/proc/vestige_is_wild_quarry,
		/proc/vestige_comb_quarry,
		/proc/vestige_loom_is_wild_quarry,
		/proc/vestige_is_shambles_quarry,
		/proc/vestige_chrysalis_fauna,
	)
	for(var/quarry_gate in quarry_gates)
		TEST_ASSERT(call(quarry_gate)(quarry, clone), "[quarry_gate] must accept local wildlife for a planet-born clone.")
	quarry.befriend(clone)
	for(var/quarry_gate in quarry_gates)
		TEST_ASSERT(!call(quarry_gate)(quarry, clone), "[quarry_gate] must still reject the clone's own pet.")

/// The Broodwatch reward belongs to its keeper, not the planet where it hatches.
/datum/unit_test/voidcrew_planetary_factions_dragonet/Run()
	var/turf/nest = run_loc_floor_bottom_left
	var/datum/map_footprint/planet = allocate(/datum/map_footprint, null, "planet", 1)
	planet.attach_level(SSmapping.z_list[nest.z])
	planet.set_rect(nest.x, nest.y, 2, 2)
	planet.enable_planetary_faction()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, get_step(nest, NORTH))
	var/mob/living/basic/carp/pet/vestige_hatchling/dragonet = allocate(/mob/living/basic/carp/pet/vestige_hatchling, nest, keeper)
	var/mob/living/basic/carp/native = allocate(/mob/living/basic/carp, get_step(nest, EAST))
	TEST_ASSERT(!(planet.planetary_faction in dragonet.faction), "A dragonet must not join the planet's native alliance at birth.")
	planet.add_planetary_faction_to_existing_mobs()
	TEST_ASSERT(!(planet.planetary_faction in dragonet.faction), "A later faction pass must not absorb the dragonet into the native alliance.")
	TEST_ASSERT(dragonet.faction_check_atom(keeper), "The constructor must still befriend the dragonet's keeper.")
	var/datum/targeting_strategy/native_strategy = GET_TARGETING_STRATEGY(native.ai_controller.blackboard[BB_TARGETING_STRATEGY])
	TEST_ASSERT(native_strategy.can_attack(native, dragonet), "Native wildlife must still recognize the dragonet as an enemy.")
	var/datum/targeting_strategy/pet_strategy = GET_TARGETING_STRATEGY(dragonet.ai_controller.blackboard[BB_PET_TARGETING_STRATEGY])
	TEST_ASSERT(pet_strategy.can_attack(dragonet, native), "The dragonet must accept attack commands against local wildlife.")
	TEST_ASSERT(!pet_strategy.can_attack(dragonet, keeper), "The dragonet must refuse attack commands against its keeper.")
