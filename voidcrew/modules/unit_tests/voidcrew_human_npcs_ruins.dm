// Ruin, planet and mission human NPCs, phase C (voidcrew/modules/human_npcs/ruins/). Unit tests compile
// before voidcrew/_DEFINES, so values from there are written out: zones 1 green, 2 yellow, 3 red; ranks
// 0 regular, 1 elite, 2 boss; the spot bark kind is "spot".

/// The ruin families' own abstract types, which no spawner or list places.
/datum/unit_test/proc/ruin_npc_abstract_types()
	return list(
		/mob/living/carbon/human/npc/ruin,
		/mob/living/carbon/human/npc/ruin/trooper,
		/mob/living/carbon/human/npc/ruin/faction_pirate,
		/mob/living/carbon/human/npc/ruin/faction_pirate/captain,
		/mob/living/carbon/human/npc/ruin/faction_pirate/boss,
	)

/**
 * Every ruin NPC type dresses in every zone, fights with something it holds (a green-zone wanderer with
 * its fists), carries spare ammunition for a magazine gun, wears locked gear, and keeps its side.
 */
/datum/unit_test/voidcrew_ruin_npc_families

/datum/unit_test/voidcrew_ruin_npc_families/Run()
	var/list/abstract = ruin_npc_abstract_types()
	for(var/npc_type in subtypesof(/mob/living/carbon/human/npc/ruin) - abstract)
		var/mob/living/carbon/human/npc/ruin/prototype = npc_type
		var/list/sides = initial(prototype.faction)
		for(var/zone in 1 to 3)
			var/mob/living/carbon/human/npc/ruin/npc = human_npc_build_in_zone(npc_type, zone)
			TEST_ASSERT_NOTNULL(npc, "[npc_type] wasn't built in zone [zone]")
			if(isnull(npc))
				continue
			TEST_ASSERT_NOTNULL(npc.w_uniform, "[npc_type] has no clothes in zone [zone]")
			TEST_ASSERT(human_npc_gear_locked(npc.w_uniform), "[npc_type]'s clothes aren't locked to it in zone [zone]")
			var/obj/item/gun/gun = human_npc_held_gun(npc)
			var/unarmed_ok = npc_type == /mob/living/carbon/human/npc/ruin/hermit && zone == 1
			if(!unarmed_ok)
				TEST_ASSERT(gun || human_npc_held_melee_weapon(npc), "[npc_type] holds no weapon in zone [zone]")
			if(istype(gun, /obj/item/gun/ballistic))
				TEST_ASSERT_NOTNULL(human_npc_find_ammo(npc, gun), "[npc_type] carries no spare ammunition for its [gun] in zone [zone]")
			for(var/side in sides)
				TEST_ASSERT(side in npc.faction, "[npc_type] lost its [side] faction")
			TEST_ASSERT(npc.should_inherit_planetary_faction(), "[npc_type] doesn't join its planet's natives")
			TEST_ASSERT_EQUAL(npc.maxHealth, 100, "[npc_type]'s max health isn't a person's")
			qdel(npc)

/// The trooper weapon ladder and the zone armour live in the outfit tables.
/datum/unit_test/voidcrew_ruin_npc_zone_ladder

/datum/unit_test/voidcrew_ruin_npc_zone_ladder/Run()
	// Syndicate SMG gunners carry a pistol outside the red zone, and the C-20r in it.
	var/mob/living/carbon/human/npc/smg_green = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/smg, 1)
	TEST_ASSERT_NOTNULL(locate(/obj/item/gun/ballistic/automatic/pistol) in smg_green?.held_items, "A green-zone Syndicate SMG gunner doesn't hold the ladder pistol")
	TEST_ASSERT(!istype(smg_green?.wear_suit, /obj/item/clothing/suit/armor), "A green-zone Syndicate gunner wears armour")
	var/mob/living/carbon/human/npc/smg_yellow = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/smg, 2)
	TEST_ASSERT_NOTNULL(locate(/obj/item/gun/ballistic/automatic/pistol) in smg_yellow?.held_items, "A yellow-zone Syndicate SMG gunner doesn't hold the ladder pistol")
	TEST_ASSERT(istype(smg_yellow?.wear_suit, /obj/item/clothing/suit/armor/vest), "A yellow-zone Syndicate gunner wears no vest")
	var/mob/living/carbon/human/npc/smg_red = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/smg, 3)
	TEST_ASSERT_NOTNULL(locate(/obj/item/gun/ballistic/automatic/c20r) in smg_red?.held_items, "A red-zone Syndicate SMG gunner holds no C-20r")
	TEST_ASSERT(istype(smg_red?.head, /obj/item/clothing/head/helmet), "A red-zone Syndicate gunner wears no helmet")
	TEST_ASSERT_NOTNULL(locate(/obj/item/reagent_containers/hypospray/medipen) in smg_red?.get_all_contents(), "A red-zone Syndicate gunner carries no medipen")
	// The sword guard only has a knife in the green zone.
	var/mob/living/carbon/human/npc/sword_green = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate/sword, 1)
	TEST_ASSERT_NULL(locate(/obj/item/melee/energy/sword) in sword_green?.held_items, "A green-zone Syndicate sword guard holds an energy sword")
	var/mob/living/carbon/human/npc/sword_yellow = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate/sword, 2)
	TEST_ASSERT_NOTNULL(locate(/obj/item/melee/energy/sword) in sword_yellow?.held_items, "A yellow-zone Syndicate sword guard holds no energy sword")
	// Stormtroopers are elites and still follow the ladder.
	var/mob/living/carbon/human/npc/storm_green = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate/stormtrooper, 1)
	TEST_ASSERT_EQUAL(storm_green?.npc_rank, 1, "A stormtrooper isn't an elite")
	TEST_ASSERT_NOTNULL(locate(/obj/item/gun/ballistic/automatic/pistol) in storm_green?.held_items, "A green-zone stormtrooper doesn't hold the ladder pistol")
	var/mob/living/carbon/human/npc/storm_yellow = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate/stormtrooper, 2)
	TEST_ASSERT_NOTNULL(locate(/obj/item/gun/ballistic/automatic/c20r) in storm_yellow?.held_items, "A yellow-zone stormtrooper holds no C-20r")
	// Space kit is sealed and breathes from its own tank.
	var/mob/living/carbon/human/npc/commando = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate/commando/gunner, 1)
	TEST_ASSERT(istype(commando?.wear_suit, /obj/item/clothing/suit/space/syndicate), "A Syndicate commando wears no space suit")
	TEST_ASSERT_NOTNULL(commando?.internal, "A Syndicate commando isn't breathing from its tank")

/// Faction pirates drop what the basic mobs dropped: fixed pieces, a captain's zone blade, the ladder weapon, cash.
/datum/unit_test/voidcrew_ruin_npc_faction_pirate_loot

/datum/unit_test/voidcrew_ruin_npc_faction_pirate_loot/Run()
	var/mob/living/carbon/human/npc/ruin/faction_pirate/captain/silverscale/noble = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/faction_pirate/captain/silverscale, 2)
	TEST_ASSERT_EQUAL(noble?.npc_rank, 1, "A faction captain isn't an elite")
	TEST_ASSERT(/obj/item/claymore/shortsword in noble?.npc_roll_death_loot(), "A yellow-zone Silverscale noble doesn't carry the zone's shortsword")
	var/mob/living/carbon/human/npc/ruin/faction_pirate/boss/skeleton/davy = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/faction_pirate/boss/skeleton, 3)
	TEST_ASSERT_EQUAL(davy?.npc_rank, 2, "A faction leader isn't a boss")
	var/list/davy_loot = davy?.npc_roll_death_loot()
	TEST_ASSERT(/obj/item/gun/ballistic/shotgun/hook in davy_loot, "Davy Jones lost his hook shotgun")
	TEST_ASSERT_EQUAL(length(davy_loot), 1, "Davy Jones rolls loot a boss doesn't")
	var/mob/living/carbon/human/npc/ruin/faction_pirate/grey/tider = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/faction_pirate/grey, 1)
	TEST_ASSERT_EQUAL(length(tider?.npc_roll_death_loot()), 2, "A grey tider doesn't roll a ladder weapon and one odds-and-ends item")
	// The designed drops and the cash land once, however often it dies.
	var/turf/drop_turf = tider.drop_location()
	var/list/before = drop_turf.contents.Copy()
	tider.death()
	var/obj/item/holochip/chip = locate() in (drop_turf.contents - before)
	TEST_ASSERT_NOTNULL(chip, "A grey tider dropped no cash")
	TEST_ASSERT_EQUAL(chip?.credits, 300, "A grey tider's cash changed")
	var/list/after_first = drop_turf.contents.Copy()
	tider.revive(ADMIN_HEAL_ALL)
	tider.death()
	TEST_ASSERT_NULL(locate(/obj/item/holochip) in (drop_turf.contents - after_first), "A revived grey tider paid its cash twice")
	for(var/atom/movable/dropped in drop_turf.contents - before)
		if(dropped != tider)
			qdel(dropped)

/// Mapped NPCs: a placed spawner queues its NPC with the map's name and side; the family's own spawner places nothing.
/obj/effect/spawner/human_npc/ruin/hermit/unit_test
	npc_name = "Test Hermit"
	npc_faction = list("saloon")

/datum/unit_test/voidcrew_ruin_npc_spawners

/datum/unit_test/voidcrew_ruin_npc_spawners/Run()
	var/queued_before = length(SShuman_npcs.queue)
	new /obj/effect/spawner/human_npc/ruin(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(SShuman_npcs.queue), queued_before, "The ruin family's own spawner queued an NPC")
	new /obj/effect/spawner/human_npc/ruin/hermit/unit_test(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(SShuman_npcs.queue), queued_before + 1, "A placed hermit spawner queued nothing")
	var/datum/human_npc_order/order = SShuman_npcs.queue[length(SShuman_npcs.queue)]
	order.zone = 1
	var/mob/living/carbon/human/npc/ruin/hermit/hermit = order.fulfil()
	qdel(order)
	TEST_ASSERT_NOTNULL(hermit, "The placed hermit wasn't built")
	if(isnull(hermit))
		return
	allocated += hermit
	TEST_ASSERT_EQUAL(hermit.real_name, "Test Hermit", "The map's name didn't reach the hermit")
	TEST_ASSERT("saloon" in hermit.faction, "The map's faction didn't reach the hermit")
	TEST_ASSERT(!("hermit" in hermit.faction), "The map's faction didn't replace the hermit's own")
	// Lists that roll many mobs queue human types instead of building them.
	var/datum/npc_spawn_context/context = new /datum/npc_spawn_context(run_loc_floor_bottom_left, 1)
	var/datum/human_npc_order/queued = spawn_npc_in_zone_or_queue(/mob/living/carbon/human/npc/ruin/hermit, run_loc_floor_bottom_left, context)
	TEST_ASSERT(istype(queued, /datum/human_npc_order), "A human NPC from a spawn list was built on the spot")
	qdel(queued)
	var/mob/living/basic/mouse/mouse = spawn_npc_in_zone_or_queue(/mob/living/basic/mouse, run_loc_floor_bottom_left, new /datum/npc_spawn_context(run_loc_floor_bottom_left, 1))
	allocated += mouse
	TEST_ASSERT(istype(mouse, /mob/living/basic/mouse), "A basic mob from a spawn list wasn't built at once")

/// Suppression counts human pirates, each body once, and never another side's NPCs.
/datum/mission_objective/kill_count/unit_test

/datum/mission_objective/kill_count/unit_test/kill_zone_counts(turf/where)
	return TRUE

/datum/mission_objective/kill_count/unit_test/kill_attributable_to_crew(mob/living/victim, turf/where)
	return TRUE

/datum/unit_test/voidcrew_ruin_npc_suppression_counts

/datum/unit_test/voidcrew_ruin_npc_suppression_counts/Run()
	var/datum/mission_objective/kill_count/unit_test/counter = allocate(/datum/mission_objective/kill_count/unit_test)
	counter.required_kills = 10
	var/mob/living/carbon/human/npc/pirate = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/pirate, 2)
	counter.on_any_death(null, pirate, FALSE)
	TEST_ASSERT_EQUAL(counter.kill_count, 1, "A dead human pirate wasn't counted")
	counter.on_any_death(null, pirate, FALSE)
	TEST_ASSERT_EQUAL(counter.kill_count, 1, "A human pirate revived and killed again counted twice")
	var/mob/living/carbon/human/npc/captain = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/faction_pirate/captain/grey, 2)
	counter.on_any_death(null, captain, FALSE)
	TEST_ASSERT_EQUAL(counter.kill_count, 2, "A dead faction pirate captain wasn't counted")
	var/mob/living/carbon/human/npc/boater = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/pirate/beach, 2)
	var/mob/living/carbon/human/npc/operative = human_npc_build_in_zone(/mob/living/carbon/human/npc/ruin/trooper/syndicate, 2)
	counter.on_any_death(null, boater, FALSE)
	counter.on_any_death(null, operative, FALSE)
	TEST_ASSERT_EQUAL(counter.kill_count, 2, "Beach pirates or Syndicate operatives counted as pirates")

/// Kill contracts queue a human target, track it once it is built, and pay its cash once per contract.
/datum/unit_test/voidcrew_ruin_npc_kill_contract

/datum/unit_test/voidcrew_ruin_npc_kill_contract/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/datum/mission/mission = allocate(/datum/mission/npc_zone_test)
	mission.objective_name = "Test Captain"
	var/datum/mission_target/npc_zone_test/site = allocate(/datum/mission_target/npc_zone_test, mission)
	site.band = 2
	mission.target = site
	var/datum/mission_objective/field/kill_named/hunt = allocate(/datum/mission_objective/field/kill_named)
	hunt.mission = mission
	hunt.active = TRUE
	hunt.target_mob_type = /mob/living/carbon/human/npc/ruin/faction_pirate/captain/grey
	hunt.spawn_field_objects(location)
	TEST_ASSERT_NULL(hunt.target_mob, "A human target was built on the spot instead of queued")
	TEST_ASSERT_NOTNULL(hunt.quarry_order, "A human target wasn't queued")
	var/datum/human_npc_order/order = hunt.quarry_order
	var/mob/living/carbon/human/npc/ruin/quarry = order?.fulfil()
	TEST_ASSERT_NOTNULL(quarry, "The queued target wasn't built")
	if(isnull(quarry))
		return
	allocated += quarry
	TEST_ASSERT_EQUAL(hunt.target_mob, quarry, "The built target isn't tracked")
	TEST_ASSERT_EQUAL(quarry.real_name, "Test Captain", "The target doesn't carry the contract's name")
	TEST_ASSERT_EQUAL(quarry.npc_payout_mission?.resolve(), mission, "The target isn't tied to its contract's cash")
	// A contract that has already paid its cash leaves the body without any.
	mission.boss_cash_issued = TRUE
	var/list/before = location.contents.Copy()
	mission.forget_quest_atom(quarry)
	hunt.deactivate()
	quarry.death()
	TEST_ASSERT_NULL(locate(/obj/item/holochip) in (location.contents - before), "A target paid cash its contract had already paid")
	for(var/atom/movable/dropped in location.contents - before)
		if(dropped != quarry)
			qdel(dropped)
	// A cancelled contract never builds a target still in the queue.
	hunt.active = TRUE
	hunt.spawn_field_objects(location)
	var/datum/human_npc_order/cancelled = hunt.quarry_order
	hunt.deactivate()
	TEST_ASSERT(QDELETED(cancelled), "A deactivated contract left its target in the spawn queue")

/// Poacher squads of human hermits are queued, counted from the start and named when built.
/datum/unit_test/voidcrew_ruin_npc_poacher_squad

/datum/unit_test/voidcrew_ruin_npc_poacher_squad/Run()
	var/turf/location = run_loc_floor_bottom_left
	var/datum/mission/mission = allocate(/datum/mission/npc_zone_test)
	mission.objective_name = "the Test Outfit"
	var/datum/mission_target/npc_zone_test/site = allocate(/datum/mission_target/npc_zone_test, mission)
	mission.target = site
	var/datum/mission_objective/field/wipe_camp/camp = allocate(/datum/mission_objective/field/wipe_camp)
	camp.mission = mission
	camp.active = TRUE
	camp.squad_types = list(/mob/living/carbon/human/npc/ruin/hermit/hunter, /mob/living/carbon/human/npc/ruin/hermit)
	camp.squad_names = list("'Snares' Okafor", "'Tallow' Vance")
	camp.spawn_field_objects(location)
	TEST_ASSERT_EQUAL(camp.squad_size, 2, "The squad's head count didn't include the queued poachers")
	TEST_ASSERT_EQUAL(length(camp.pending_poachers), 2, "The human poachers weren't queued")
	for(var/datum/human_npc_order/order as anything in camp.pending_poachers.Copy())
		order.fulfil()
	TEST_ASSERT_EQUAL(length(camp.squad), 2, "The built poachers didn't join the squad")
	TEST_ASSERT_EQUAL(length(camp.pending_poachers), 0, "Built poachers are still pending")
	var/list/names = list()
	for(var/mob/living/carbon/human/npc/poacher in camp.squad)
		names += poacher.real_name
		allocated += poacher
	TEST_ASSERT("'Snares' Okafor" in names, "The trailboss lost the contract's name")
	mission.forget_quest_atom(mission.quest_atom)
	camp.deactivate()
	for(var/obj/thing in range(3, location))
		if(!isturf(thing) && !istype(thing, /obj/effect/landmark))
			qdel(thing)

/// No Voidcrew map places a trooper or hermit basic mob any more, and the derelict shuttles inside ruins load
/// their Voidcrew copies (the bounty lair's mafia is another phase's).
/datum/unit_test/voidcrew_ruin_npc_maps

/datum/unit_test/voidcrew_ruin_npc_maps/Run()
	var/list/maps = list()
	ruin_npc_collect_maps("_maps/voidcrew/", maps)
	TEST_ASSERT(length(maps) > 100, "The Voidcrew map scan found only [length(maps)] maps")
	for(var/map_path in maps)
		if(findtext(map_path, "bounty_lair_mafia_club.dmm"))
			continue
		var/text = maps[map_path]
		TEST_ASSERT(!findtext(text, "/mob/living/basic/trooper"), "[map_path] still places a trooper basic mob")
		TEST_ASSERT(!findtext(text, "/mob/living/simple_animal/hostile/asteroid/hermit"), "[map_path] still places a hermit simple mob")
	for(var/template_type in list(
		/datum/map_template/shuttle/ruin/caravan_victim,
		/datum/map_template/shuttle/ruin/pirate_cutter,
		/datum/map_template/shuttle/ruin/syndicate_dropship,
		/datum/map_template/shuttle/ruin/syndicate_fighter_shiv,
	))
		var/datum/map_template/shuttle/template = new template_type()
		TEST_ASSERT(findtext(template.mappath, "_maps/voidcrew/shuttles/") == 1, "[template_type] loads [template.mappath], not its Voidcrew copy")
		TEST_ASSERT(fexists(template.mappath), "[template_type]'s map [template.mappath] is missing")
		qdel(template)

/datum/unit_test/voidcrew_ruin_npc_maps/proc/ruin_npc_collect_maps(root, list/out)
	for(var/entry in flist(root))
		if(copytext(entry, -1) == "/")
			ruin_npc_collect_maps("[root][entry]", out)
		else if(copytext(entry, -4) == ".dmm")
			out["[root][entry]"] = file2text("[root][entry]")
