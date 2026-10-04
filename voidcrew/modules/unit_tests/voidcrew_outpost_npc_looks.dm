/**
 * Outpost NPCs in one outfit are different people (outpost_npc_looks.dm). tg's cached human looks
 * put everyone in the same outfit on one bald, pale, male body; these must vary the person, give a
 * woman a woman's body, and dress the mob the way tg's looks do.
 *
 * Fork defines are included after the tests: each outfit has 8 looks per gender
 * (OUTPOST_NPC_LOOK_COUNT).
 */
/datum/unit_test/voidcrew_outpost_npc_looks

/datum/unit_test/voidcrew_outpost_npc_looks/Run()
	// Eight people in one outfit are not all the same person.
	var/list/signatures = list()
	for(var/look_number in 1 to 8)
		var/look = get_outpost_npc_look(/datum/outfit/outpost_prisoner, MALE, look_number)
		TEST_ASSERT_NOTNULL(look, "Look [look_number] of the prisoner outfit was not built")
		signatures |= look_signature(look)
	TEST_ASSERT(length(signatures) >= 2, "All eight looks of the prisoner outfit are the same person")
	TEST_ASSERT(get_outpost_npc_look(/datum/outfit/outpost_prisoner, MALE, 1) == GLOB.outpost_npc_looks[outpost_npc_look_key(/datum/outfit/outpost_prisoner, MALE, 1)], "A built look was not cached")
	TEST_ASSERT(has_state(get_outpost_npc_look(/datum/outfit/outpost_prisoner, MALE, 1), "_chest_m"), "A man's look has no male chest")
	TEST_ASSERT(has_state(get_outpost_npc_look(/datum/outfit/outpost_prisoner, FEMALE, 1), "_chest_f"), "A woman's look has no female chest")

	// A prisoner wears their own look, keyed by their gender.
	var/mob/living/basic/outpost_prisoner/prisoner = allocate(/mob/living/basic/outpost_prisoner)
	var/deadline = world.time + 5 SECONDS
	// Let the look Initialize() started finish first, so it cannot land on top of this one.
	UNTIL(prisoner.icon == 'icons/mob/human/human.dmi' || world.time > deadline)
	TEST_ASSERT(prisoner.look_number >= 1 && prisoner.look_number <= 8, "A prisoner got look number [prisoner.look_number]")
	prisoner.gender = FEMALE
	prisoner.look_number = 3
	prisoner.build_look()
	TEST_ASSERT_NOTNULL(GLOB.outpost_npc_looks[outpost_npc_look_key(prisoner.outfit_path, FEMALE, 3)], "A woman's look was not cached under her gender")
	TEST_ASSERT_EQUAL(prisoner.icon, 'icons/mob/human/human.dmi', "A prisoner's look did not set the human icon")
	TEST_ASSERT_EQUAL(prisoner.icon_state, "", "A prisoner's look left an icon state")
	TEST_ASSERT(prisoner.appearance_flags & KEEP_TOGETHER, "A prisoner's look did not keep its overlays together")
	TEST_ASSERT(has_state(prisoner, "_chest_f"), "A woman prisoner does not have a woman's body")

	// Anything that is not female gets a male body.
	TEST_ASSERT_EQUAL(outpost_npc_look_key(/datum/outfit/outpost_prisoner, NEUTER, 2), outpost_npc_look_key(/datum/outfit/outpost_prisoner, MALE, 2), "A neuter look is not the male one")

/// What a look is drawn from: every overlay's icon, state and colour
/datum/unit_test/voidcrew_outpost_npc_looks/proc/look_signature(mutable_appearance/look)
	var/list/parts = list()
	for(var/mutable_appearance/overlay as anything in look.overlays)
		parts += "[overlay.icon]:[overlay.icon_state]:[overlay.color]"
	return jointext(parts, "|")

/// Whether any overlay of `thing` (an atom or an appearance) has an icon state containing `fragment`
/datum/unit_test/voidcrew_outpost_npc_looks/proc/has_state(thing, fragment)
	var/mutable_appearance/look = thing
	for(var/mutable_appearance/overlay as anything in look.overlays)
		if(findtext(overlay.icon_state, fragment))
			return TRUE
	return FALSE

/**
 * Ambient NPCs hold what they carry the way a player does: a dummy in the NPC's outfit with a real
 * item in hand, cached (outpost_npc_looks.dm), applied as the NPC's whole look (ambient_npc.dm),
 * instead of the old pasted-icon vis_contents effect.
 */
/datum/unit_test/voidcrew_ambient_held_looks

/datum/unit_test/voidcrew_ambient_held_looks/Run()
	var/static/list/held_item_types = list(
		/obj/item/mop,
		/obj/item/reagent_containers/cup/watering_can,
		/obj/item/fishing_rod,
		/obj/item/fish/goldfish,
		/obj/item/spear/bamboospear,
		/obj/item/knife/butcher,
		/obj/item/pickaxe,
		/obj/item/melee/baseball_bat,
		/obj/item/reagent_containers/cup/bucket/wooden,
		/obj/item/reagent_containers/cup/bucket,
		/obj/item/delivery/small,
		/obj/item/delivery/big,
		/obj/item/reagent_containers/cup/glass/bottle/beer,
		/obj/item/reagent_containers/cup/glass/mug,
		/obj/item/reagent_containers/cup/glass/bottle/holywater,
	)
	var/bare_look = get_outpost_npc_look(/datum/outfit/ambient_customer, MALE, 1)
	for(var/held_type in held_item_types)
		var/obj/item/held_type_instance = held_type
		var/look = get_outpost_held_look(/datum/outfit/ambient_customer, MALE, 1, held_type)
		TEST_ASSERT_NOTNULL(look, "No held look was built for [held_type]")
		TEST_ASSERT(look != bare_look, "The held look for [held_type] is no different from an empty-handed look")
		TEST_ASSERT(held_look_has_icon(look, initial(held_type_instance.righthand_file)), "The held look for [held_type] has no overlay from its right-hand file")
		var/second = get_outpost_held_look(/datum/outfit/ambient_customer, MALE, 1, held_type)
		TEST_ASSERT_EQUAL(look, second, "A second call rebuilt [held_type]'s held look instead of reusing the cache")

	// What ambient_held_look_type() stands a held thing in for
	TEST_ASSERT_EQUAL(ambient_held_look_type(/obj/structure/closet/crate), /obj/item/delivery/big, "A crate held look is not a big parcel")
	TEST_ASSERT_EQUAL(ambient_held_look_type(/obj/item/storage/box/papersack), /obj/item/delivery/small, "A papersack held look is not a small parcel")
	TEST_ASSERT_EQUAL(ambient_held_look_type(/obj/item/storage/bag/tray), /obj/item/reagent_containers/cup/bucket, "A tray held look is not a bucket")
	TEST_ASSERT_EQUAL(ambient_held_look_type(/obj/item/reagent_containers/cup/glass/flask), /obj/item/reagent_containers/cup/glass/bottle/holywater, "A flask held look is not a metal flask")
	TEST_ASSERT_NULL(ambient_held_look_type(/obj/item/stack/ore/iron), "Ore is held with nothing to draw it")
	TEST_ASSERT_NULL(ambient_held_look_type(/obj/item/food/meat/slab), "A meat slab is held with nothing to draw it")
	TEST_ASSERT_NULL(ambient_held_look_type(/obj/item/food/meat/steak/plain/human), "A steak is held with nothing to draw it")

	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = new(null)
	glass.reagents.add_reagent(/datum/reagent/consumable/ethanol/beer, 25)
	TEST_ASSERT_EQUAL(ambient_held_look_type(glass), /obj/item/reagent_containers/cup/glass/bottle/beer, "A glass of beer is not held as a beer bottle")
	glass.reagents.clear_reagents()
	glass.reagents.add_reagent(/datum/reagent/consumable/coffee, 25)
	TEST_ASSERT_EQUAL(ambient_held_look_type(glass), /obj/item/reagent_containers/cup/glass/mug, "A glass of coffee is not held as a mug")
	qdel(glass)

	// An ambient NPC's own overlays follow set_held()
	var/mob/living/basic/ambient_npc/npc = allocate(/mob/living/basic/ambient_npc)
	var/deadline = world.time + 5 SECONDS
	UNTIL(npc.icon == 'icons/mob/human/human.dmi' || world.time > deadline)
	npc.set_held(/obj/item/mop)
	deadline = world.time + 5 SECONDS
	var/obj/item/mop/mop_type = /obj/item/mop
	UNTIL(held_look_has_icon(npc, initial(mop_type.righthand_file)) || world.time > deadline)
	TEST_ASSERT_EQUAL(npc.held_visual, /obj/item/mop, "Holding a mop did not set held_visual")
	TEST_ASSERT(held_look_has_icon(npc, initial(mop_type.righthand_file)), "Holding a mop left no custodial right-hand overlay")
	TEST_ASSERT_NULL(locate(/obj/effect/abstract/bounty_held) in npc.vis_contents, "An ambient NPC still carries the old pasted-icon holder")
	npc.set_held(null)
	deadline = world.time + 5 SECONDS
	UNTIL(!held_look_has_icon(npc, initial(mop_type.righthand_file)) || world.time > deadline)
	TEST_ASSERT_NULL(npc.held_visual, "Letting go did not clear held_visual")
	TEST_ASSERT(!held_look_has_icon(npc, initial(mop_type.righthand_file)), "Letting go of the mop left its right-hand overlay")

	// The held-look cache is bounded: only the newest entries survive
	outpost_npc_held_look_cache_add("held_test_1", bare_look, 3)
	outpost_npc_held_look_cache_add("held_test_2", bare_look, 3)
	outpost_npc_held_look_cache_add("held_test_3", bare_look, 3)
	outpost_npc_held_look_cache_add("held_test_4", bare_look, 3)
	outpost_npc_held_look_cache_add("held_test_5", bare_look, 3)
	TEST_ASSERT_EQUAL(length(GLOB.outpost_npc_held_look_keys), 3, "The bounded held-look cache did not stay at 3 keys")
	TEST_ASSERT_EQUAL(GLOB.outpost_npc_held_look_keys[1], "held_test_3", "The bounded held-look cache dropped the wrong entry")
	TEST_ASSERT_EQUAL(GLOB.outpost_npc_held_look_keys[2], "held_test_4", "The bounded held-look cache dropped the wrong entry")
	TEST_ASSERT_EQUAL(GLOB.outpost_npc_held_look_keys[3], "held_test_5", "The bounded held-look cache dropped the wrong entry")
	TEST_ASSERT_NULL(GLOB.outpost_npc_looks["held_test_1"], "An evicted held look was not dropped")
	TEST_ASSERT_NOTNULL(GLOB.outpost_npc_looks["held_test_5"], "A kept held look was dropped")
	for(var/leftover_key in list("held_test_3", "held_test_4", "held_test_5"))
		GLOB.outpost_npc_looks -= leftover_key
		GLOB.outpost_npc_held_look_keys -= leftover_key

	// The work loop: a droid keeps its box overlay; a person shows a "carry" look in hand instead
	var/obj/structure/outpost_yard_droid/droid = allocate(/obj/structure/outpost_yard_droid)
	var/datum/component/outpost_ambient_worker/droid_worker = droid.GetComponent(/datum/component/outpost_ambient_worker)
	TEST_ASSERT_NOTNULL(droid_worker, "A yard droid has no work component")
	droid_worker.set_carried(TRUE)
	TEST_ASSERT_NOTNULL(droid_worker.carried, "A carrying droid has no box overlay")

	var/mob/living/basic/ambient_npc/hauler = allocate(/mob/living/basic/ambient_npc)
	deadline = world.time + 5 SECONDS
	UNTIL(hauler.icon == 'icons/mob/human/human.dmi' || world.time > deadline)
	var/datum/component/outpost_ambient_worker/hauler_worker = hauler.AddComponent(/datum/component/outpost_ambient_worker, list(), FALSE, CALLBACK(hauler, TYPE_PROC_REF(/mob/living/basic/ambient_npc, show_work_look)))
	hauler_worker.set_carried(TRUE)
	deadline = world.time + 5 SECONDS
	UNTIL(hauler.work_look == "carry" || world.time > deadline)
	TEST_ASSERT_EQUAL(hauler.work_look, "carry", "A carrying person's work_look was not set to carry")
	TEST_ASSERT_NULL(hauler_worker.carried, "A carrying person got a box overlay like a droid")
	hauler_worker.set_carried(FALSE)
	deadline = world.time + 5 SECONDS
	UNTIL(isnull(hauler.work_look) || world.time > deadline)
	TEST_ASSERT_NULL(hauler.work_look, "Putting it down left the carry look on")

/// Whether any overlay of `thing` (an atom or an appearance), or one of that overlay's own overlays, uses icon `icon_file`
/datum/unit_test/voidcrew_ambient_held_looks/proc/held_look_has_icon(thing, icon_file, depth = 2)
	var/mutable_appearance/look = thing
	for(var/mutable_appearance/overlay as anything in look.overlays)
		if(overlay.icon == icon_file)
			return TRUE
		if(depth > 1 && held_look_has_icon(overlay, icon_file, depth - 1))
			return TRUE
	return FALSE
