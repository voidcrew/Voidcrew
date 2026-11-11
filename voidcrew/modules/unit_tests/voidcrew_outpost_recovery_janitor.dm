/**
 * Outpost recovery tests: spec-rehydrate.md 3.2 and 3.3. Owner: R4.
 *
 * A bloodied tile is clean after the mop step, and it is tg's cleaner that did it (the mop's water goes down); the
 * map's own `old` decals are left; a gun on the floor is never picked up and the bag takes litter by type alone
 * (M34); the mop, the bag and the headset are locked gear (M33); a dry mop is dipped in a sink with a right click;
 * patrol stops are dirty and clean by what is in sight of them; the crew has lines in every zone. The morgue crew's
 * bag and bed (spec acceptance for R4 names them) are R3's items, tested in voidcrew_outpost_recovery_morgue.dm.
 *
 * Defines are included after the tests: write values out with a comment naming the define (OUTPOST_TRADER_MOB is
 * /mob/living/basic/outpost_trader until R1 renames it). Police helpers: voidcrew_outpost_police_helpers.dm; the
 * ambient test room and its outpost: voidcrew_ambient_outposts.dm and voidcrew_ambient_core.dm.
 * Tests are written, not run, by the package; the lead runs them once at integration.
 */

/// A recovery janitor at `where`, in `place`
/datum/unit_test/proc/recovery_janitor_at(datum/ambient_place/outpost/place, turf/where)
	return pa_npc(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor, where, place)

/// Carries `janitor`'s activity on a second at a time until it is done: TRUE if it finished within 15 seconds
/datum/unit_test/proc/recovery_run_activity(mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor)
	for(var/step in 1 to 15)
		if(janitor.activity_step(1) == 2) // AMBIENT_STEP_DONE
			return TRUE
		sleep(1 SECONDS)
	return FALSE

/// Blood, gibs and a vomit stain on one tile are gone after the janitor's strokes, the mop's water went into it, and the map's own `old` blood is still there
/datum/unit_test/voidcrew_outpost_recovery_janitor_mop

/datum/unit_test/voidcrew_outpost_recovery_janitor_mop/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor = recovery_janitor_at(place, pa_tile(0, 0))
	TEST_ASSERT_NOTNULL(janitor.crew_mop, "The janitor has no mop")
	TEST_ASSERT_NOTNULL(janitor.crew_bag, "The janitor has no trash bag")
	TEST_ASSERT(!janitor.mop_wet(), "The janitor's mop starts wet")

	var/turf/mess_tile = pa_tile(2, 2)
	var/obj/effect/decal/cleanable/blood/blood = allocate(/obj/effect/decal/cleanable/blood, mess_tile)
	var/obj/effect/decal/cleanable/blood/gibs/gibs = allocate(/obj/effect/decal/cleanable/blood/gibs, mess_tile)
	var/obj/effect/decal/cleanable/vomit/vomit = allocate(/obj/effect/decal/cleanable/vomit, mess_tile)
	var/obj/effect/decal/cleanable/blood/old/decor = allocate(/obj/effect/decal/cleanable/blood/old, pa_tile(0, 4))
	var/obj/effect/decal/cleanable/dirt/dirt = allocate(/obj/effect/decal/cleanable/dirt, pa_tile(1, 4))
	TEST_ASSERT(recovery_is_mess(blood) && recovery_is_mess(gibs) && recovery_is_mess(vomit), "A fight's blood, gibs or vomit is not mess to a crew")
	TEST_ASSERT(!recovery_is_mess(decor), "A crew would wash the map's own `old` blood")
	TEST_ASSERT(!recovery_is_mess(dirt), "A crew would wash the map's dirt")

	janitor.crew_mop.reagents.add_reagent(/datum/reagent/water, 15)
	var/water_before = janitor.crew_mop.reagents.total_volume
	var/datum/ambient_activity/recovery_clean/clean = janitor.start_activity(new /datum/ambient_activity/recovery_clean(janitor))
	TEST_ASSERT_NOTNULL(clean, "The janitor found no mess to wash")
	TEST_ASSERT_EQUAL(clean.work_tile, mess_tile, "The janitor went for the wrong tile")
	TEST_ASSERT_EQUAL(clean.task, 2, "The janitor with a wet mop did not mop") // RECOVERY_TASK_MOP
	TEST_ASSERT(get_dist(clean.spot, mess_tile) <= 1, "The janitor mops from too far away")
	janitor.forceMove(clean.spot)
	TEST_ASSERT(recovery_run_activity(janitor), "The janitor never finished mopping")
	TEST_ASSERT(QDELETED(blood), "The blood is still there after the mop")
	TEST_ASSERT(QDELETED(gibs), "The gibs are still there after the mop")
	TEST_ASSERT(QDELETED(vomit), "The vomit is still there after the mop")
	TEST_ASSERT(janitor.crew_mop.reagents.total_volume < water_before, "The tile was cleared without a stroke of the mop: no water went into it")
	TEST_ASSERT(!QDELETED(decor), "The janitor washed the map's `old` blood")
	TEST_ASSERT(!QDELETED(dirt), "The janitor washed the map's dirt")
	janitor.end_activity()

/// A gun on the floor is not litter and is not picked up; spent casings, an empty magazine, an empty bottle and a wrapper are; the bag refuses a gun by type even set to take everything
/datum/unit_test/voidcrew_outpost_recovery_janitor_litter

/datum/unit_test/voidcrew_outpost_recovery_janitor_litter/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor = recovery_janitor_at(place, pa_tile(0, 0))
	var/turf/litter_tile = pa_tile(2, 2)

	var/obj/item/gun/energy/e_gun/mini/gun = allocate(/obj/item/gun/energy/e_gun/mini, litter_tile)
	var/obj/item/ammo_casing/c9mm/live = allocate(/obj/item/ammo_casing/c9mm, litter_tile)
	var/obj/item/ammo_casing/c9mm/spent = allocate(/obj/item/ammo_casing/c9mm, litter_tile)
	QDEL_NULL(spent.loaded_projectile)
	var/obj/item/ammo_box/magazine/m9mm/full_magazine = allocate(/obj/item/ammo_box/magazine/m9mm, litter_tile)
	var/obj/item/ammo_box/magazine/m9mm/empty_magazine = allocate(/obj/item/ammo_box/magazine/m9mm, litter_tile)
	empty_magazine.stored_ammo.Cut()
	var/obj/item/reagent_containers/cup/glass/bottle/full_bottle = allocate(/obj/item/reagent_containers/cup/glass/bottle, litter_tile)
	full_bottle.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, 30)
	var/obj/item/reagent_containers/cup/glass/bottle/empty_bottle = allocate(/obj/item/reagent_containers/cup/glass/bottle, litter_tile)
	empty_bottle.reagents.clear_reagents()
	var/obj/item/trash/chips/wrapper = allocate(/obj/item/trash/chips, litter_tile)

	TEST_ASSERT(!recovery_is_litter(gun), "A gun on the floor is litter")
	TEST_ASSERT(!recovery_is_litter(live), "A live round on the floor is litter")
	TEST_ASSERT(recovery_is_litter(spent), "A spent casing is not litter")
	TEST_ASSERT(!recovery_is_litter(full_magazine), "A loaded magazine is litter")
	TEST_ASSERT(recovery_is_litter(empty_magazine), "A magazine with nothing in it is not litter")
	TEST_ASSERT(!recovery_is_litter(full_bottle), "A full bottle is litter")
	TEST_ASSERT(recovery_is_litter(empty_bottle), "An empty bottle is not litter")
	TEST_ASSERT(recovery_is_litter(wrapper), "A wrapper is not litter")

	// The bag takes a thing at a click, litter by type: set to take everything, it still refuses the gun
	TEST_ASSERT_EQUAL(janitor.crew_bag.atom_storage.collection_mode, COLLECT_ONE, "The janitor's bag takes everything on a tile at a click")
	janitor.crew_bag.atom_storage.collection_mode = COLLECT_EVERYTHING
	TEST_ASSERT(!janitor.crew_bag.atom_storage.can_insert(gun, janitor, FALSE), "The janitor's bag takes a gun")
	TEST_ASSERT(janitor.crew_bag.atom_storage.can_insert(spent, janitor, FALSE), "The janitor's bag will not take a spent casing")
	janitor.crew_bag.atom_storage.collection_mode = COLLECT_ONE

	// The work: litter first, a click on each thing, the gun and the live round left where they lie
	var/datum/ambient_activity/recovery_clean/clean = janitor.start_activity(new /datum/ambient_activity/recovery_clean(janitor))
	TEST_ASSERT_NOTNULL(clean, "The janitor found no litter to bag")
	TEST_ASSERT_EQUAL(clean.work_tile, litter_tile, "The janitor went for the wrong tile")
	TEST_ASSERT_EQUAL(clean.task, 3, "The janitor did not bag the litter") // RECOVERY_TASK_PICK
	janitor.forceMove(clean.spot)
	TEST_ASSERT(recovery_run_activity(janitor), "The janitor never finished bagging")
	TEST_ASSERT_EQUAL(spent.loc, janitor.crew_bag, "The spent casing was left on the floor")
	TEST_ASSERT_EQUAL(empty_magazine.loc, janitor.crew_bag, "The empty magazine was left on the floor")
	TEST_ASSERT_EQUAL(empty_bottle.loc, janitor.crew_bag, "The empty bottle was left on the floor")
	TEST_ASSERT_EQUAL(wrapper.loc, janitor.crew_bag, "The wrapper was left on the floor")
	TEST_ASSERT_EQUAL(gun.loc, litter_tile, "The janitor picked up a gun")
	TEST_ASSERT_EQUAL(live.loc, litter_tile, "The janitor picked up a live round")
	TEST_ASSERT_EQUAL(full_magazine.loc, litter_tile, "The janitor picked up a loaded magazine")
	TEST_ASSERT_EQUAL(full_bottle.loc, litter_tile, "The janitor picked up a full bottle")
	janitor.end_activity()

/// Mop, bag and headset are locked to the janitor and cannot be dropped; the headset is on the police frequency; the voice has lines
/datum/unit_test/voidcrew_outpost_recovery_janitor_kit

/datum/unit_test/voidcrew_outpost_recovery_janitor_kit/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor = recovery_janitor_at(place, pa_tile(0, 0))
	TEST_ASSERT(human_npc_gear_locked(janitor.crew_mop), "A janitor's mop is not locked gear")
	TEST_ASSERT(human_npc_gear_locked(janitor.crew_bag), "A janitor's trash bag is not locked gear")
	var/obj/item/radio/headset = janitor.ears
	TEST_ASSERT(istype(headset), "A janitor wears no headset")
	TEST_ASSERT(human_npc_gear_locked(headset), "A janitor's headset can be taken")
	TEST_ASSERT_EQUAL(headset.frequency, 1473, "A janitor's headset is not on the police frequency") // OUTPOST_POLICE_RADIO_FREQ
	var/obj/item/card/id/card = janitor.get_idcard()
	TEST_ASSERT(card && ("outpost_police" in card.GetAccess()), "A janitor's ID does not open the police lift doors") // ACCESS_OUTPOST_POLICE
	TEST_ASSERT(human_npc_gear_locked(card), "A janitor's ID can be taken")

	// Nobody can make them put the mop or the bag down
	janitor.dropItemToGround(janitor.crew_mop)
	janitor.dropItemToGround(janitor.crew_bag)
	TEST_ASSERT(janitor.is_holding(janitor.crew_mop), "A janitor dropped the mop")
	TEST_ASSERT(janitor.is_holding(janitor.crew_bag), "A janitor dropped the bag")

	// Their voice is their outpost's: lines for the kinds they say, in every zone
	for(var/section in list("halcyon", "quartermain", "undertow"))
		janitor.dialogue_section = section
		for(var/context in list("mess", "mind_floor", "lift", "first_body"))
			TEST_ASSERT(length(janitor.get_lines(context)), "A janitor at [section] has no [context] lines")

/// A dry mop is dipped in a sink on its own side with a right click, as a player wets one; then it washes
/datum/unit_test/voidcrew_outpost_recovery_janitor_water

/datum/unit_test/voidcrew_outpost_recovery_janitor_water/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/obj/structure/sink/directional/west/sink = allocate(/obj/structure/sink/directional/west, pa_tile(3, 0))
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor = recovery_janitor_at(place, pa_tile(1, 0))
	var/turf/mess_tile = pa_tile(0, 3)
	var/obj/effect/decal/cleanable/blood/blood = allocate(/obj/effect/decal/cleanable/blood, mess_tile)
	TEST_ASSERT(!janitor.mop_wet(), "The janitor's mop starts wet")
	var/list/water = janitor.find_water()
	TEST_ASSERT_NOTNULL(water, "The janitor found no sink to dip the mop in")
	TEST_ASSERT_EQUAL(water[1], sink, "The janitor found the wrong water")

	// A dry mop and mess to wash: the dip comes first
	var/datum/ambient_activity/recovery_clean/clean = janitor.start_activity(new /datum/ambient_activity/recovery_clean(janitor))
	TEST_ASSERT_NOTNULL(clean, "The janitor found no work")
	TEST_ASSERT_EQUAL(clean.task, 1, "The janitor with a dry mop did not go to the sink") // RECOVERY_TASK_WET
	janitor.forceMove(clean.spot)
	TEST_ASSERT(recovery_run_activity(janitor), "The janitor never finished dipping the mop")
	TEST_ASSERT(janitor.mop_wet(), "The mop is dry after the dip")
	janitor.end_activity()

	// Then the stroke
	clean = janitor.start_activity(new /datum/ambient_activity/recovery_clean(janitor))
	TEST_ASSERT_NOTNULL(clean, "The janitor found no work with a wet mop")
	TEST_ASSERT_EQUAL(clean.task, 2, "The janitor with a wet mop did not mop") // RECOVERY_TASK_MOP
	janitor.forceMove(clean.spot)
	TEST_ASSERT(recovery_run_activity(janitor), "The janitor never finished mopping")
	TEST_ASSERT(QDELETED(blood), "The blood is still there after the dip and the stroke")
	janitor.end_activity()

/// A stop is dirty while a body, a mess or litter is in sight of it and clean after; the map's decor is no mess; no stops means clean
/datum/unit_test/voidcrew_outpost_recovery_janitor_stops

/datum/unit_test/voidcrew_outpost_recovery_janitor_stops/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	TEST_ASSERT_NOTNULL(recovery, "The outpost has no recovery")
	var/turf/stop = pa_tile(2, 2)
	TEST_ASSERT(!recovery.stop_dirty(stop), "A bare stop is dirty")
	TEST_ASSERT_EQUAL(recovery.clean_share(), 1, "An outpost with no patrol stops is not all clean")

	allocate(/obj/effect/decal/cleanable/blood/old, pa_tile(1, 1))
	recovery.stop_looked.Cut()
	TEST_ASSERT(!recovery.stop_dirty(stop), "The map's own `old` blood makes a stop dirty")

	var/obj/effect/decal/cleanable/blood/blood = allocate(/obj/effect/decal/cleanable/blood, pa_tile(0, 0))
	recovery.stop_looked.Cut()
	TEST_ASSERT(recovery.stop_dirty(stop), "Blood in sight of a stop does not make it dirty")
	TEST_ASSERT(recovery.dirty_stops[stop], "A dirty stop is not recorded")
	// A look is kept a moment: the blood going does not show until the next
	qdel(blood)
	TEST_ASSERT(recovery.stop_dirty(stop), "A stop looked at a moment ago was looked at again")
	recovery.mark_clean(stop)
	TEST_ASSERT(!recovery.stop_dirty(stop), "A stop a worker marked clean is dirty")
	TEST_ASSERT(!recovery.dirty_stops[stop], "A clean stop is still recorded as dirty")

	var/obj/item/ammo_casing/c9mm/casing = allocate(/obj/item/ammo_casing/c9mm, pa_tile(4, 0))
	QDEL_NULL(casing.loaded_projectile)
	recovery.stop_looked.Cut()
	TEST_ASSERT(recovery.stop_dirty(stop), "A spent casing in sight does not make a stop dirty")
	qdel(casing)

	var/mob/living/carbon/human/consistent/corpse = allocate(/mob/living/carbon/human/consistent, pa_tile(3, 3))
	corpse.death()
	recovery.stop_looked.Cut()
	TEST_ASSERT(recovery.stop_dirty(stop), "A body in sight does not make a stop dirty")

/// With nothing to do a janitor waits, then takes the lift out; with mess about it does not
/datum/unit_test/voidcrew_outpost_recovery_janitor_leave

/datum/unit_test/voidcrew_outpost_recovery_janitor_leave/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = pa_place(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor/janitor = recovery_janitor_at(place, pa_tile(0, 0))

	var/obj/effect/decal/cleanable/blood/blood = allocate(/obj/effect/decal/cleanable/blood, pa_tile(2, 2))
	janitor.idle_since = world.time - 10 MINUTES
	janitor.pick_activity()
	TEST_ASSERT(istype(janitor.activity, /datum/ambient_activity/recovery_clean), "A janitor with mess about did not clean it ([janitor.activity?.type])")
	janitor.end_activity()
	qdel(blood)

	janitor.idle_since = world.time - 10 MINUTES
	janitor.pick_activity()
	TEST_ASSERT(istype(janitor.activity, /datum/ambient_activity/leave), "A janitor with nothing left to clean stayed on ([janitor.activity?.type])")
	janitor.end_activity()

/// Every zone's file has lines for every kind the crews say (the morgue worker's first_body, officer_body, bagged, tray and lift included), short ones, with no placeholder left in them
/datum/unit_test/voidcrew_outpost_recovery_janitor_lines

/datum/unit_test/voidcrew_outpost_recovery_janitor_lines/Run()
	var/file = "outpost_recovery.json" // AMBIENT_STRINGS_RECOVERY
	var/list/kinds = list("call", "first_body", "officer_body", "bagged", "tray", "lift", "mess", "mind_floor", "idle", "talk", "work", "chat", "reply", "attacked", "violence", "leave")
	for(var/section in list("halcyon", "quartermain", "undertow"))
		for(var/kind in kinds)
			var/list/lines = ambient_dialogue_lines(file, section, kind)
			TEST_ASSERT(length(lines) >= 2, "[section] has fewer than two [kind] lines")
			for(var/line in lines)
				TEST_ASSERT(istext(line) && length(line) <= 72, "[section] [kind] has a line that is not text or runs past 72 characters: [line]")
				TEST_ASSERT(!findtext(line, "%"), "[section] [kind] has a placeholder that is not filled: [line]")
		var/list/entry = ambient_dialogue_section(file, section)
		TEST_ASSERT(length(entry["conversations"]), "[section] has no conversations")
