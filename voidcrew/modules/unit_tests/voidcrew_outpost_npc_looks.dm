/**
 * Outpost NPC looks (outpost_npc_looks.dm). Ambient NPCs are real human bodies (human NPC phase E1):
 * each rolls one face (/datum/outpost_npc_look) and wears it for life, the same person idle, holding
 * something, working and dead; what they hold is a real item in their hand. Prisoners and guards are
 * the prison's (their own tests). The dressed-appearance cache that basic mobs still copy onto
 * themselves is checked at the end.
 */
/datum/unit_test/voidcrew_outpost_npc_looks

/datum/unit_test/voidcrew_outpost_npc_looks/Run()
	// Eight people rolled are not all the same person; a woman is a woman
	var/list/faces = list()
	for(var/person_number in 1 to 8)
		var/datum/outpost_npc_look/person = new_outpost_npc_person(MALE)
		TEST_ASSERT_EQUAL(person.gender, MALE, "A man was rolled as [person.gender]")
		faces |= "[person.skin_tone]|[person.hairstyle]|[person.hair_color]|[person.facial_hairstyle]|[person.eye_color]"
	TEST_ASSERT(length(faces) >= 2, "Eight people rolled are all the same person")
	var/datum/outpost_npc_look/woman = new_outpost_npc_person(FEMALE)
	TEST_ASSERT_EQUAL(woman.gender, FEMALE, "A woman was rolled as a man")
	var/datum/outpost_npc_look/neuter = new_outpost_npc_person(NEUTER)
	TEST_ASSERT_EQUAL(neuter.gender, MALE, "Anything not female did not get a man's body")

	// An ambient NPC's body wears their face
	var/mob/living/carbon/human/npc/ambient_npc/npc = allocate(/mob/living/carbon/human/npc/ambient_npc, run_loc_floor_bottom_left)
	var/datum/outpost_npc_look/face = npc.person
	TEST_ASSERT_NOTNULL(face, "An ambient NPC has no face")
	check_wears(npc, face, "An ambient NPC")
	TEST_ASSERT_EQUAL(npc.gender, face.gender, "An ambient NPC's gender is not their face's")

	// The same person holding something, working, and dead: the face never changes
	npc.set_held(/obj/item/mop)
	check_wears(npc, face, "An ambient NPC holding a mop")
	npc.show_work_look("weld")
	check_wears(npc, face, "An ambient NPC welding")
	npc.show_work_look(null)
	npc.death()
	check_wears(npc, face, "A dead ambient NPC")

	// The same person again later (a stray coming back): a copy of the face, never the same datum
	var/list/identity = npc.ambient_identity()
	var/datum/outpost_npc_look/kept = identity["person"]
	TEST_ASSERT(kept != face, "An identity shares its face datum with the body it came from")
	var/mob/living/carbon/human/npc/ambient_npc/again = ambient_build_npc(/mob/living/carbon/human/npc/ambient_npc, run_loc_floor_top_right, null, identity)
	TEST_ASSERT_NOTNULL(again, "Nobody could be built from an identity")
	allocated += again
	check_wears(again, face, "Someone built from an identity")
	TEST_ASSERT_EQUAL(again.real_name, npc.real_name, "Someone built from an identity has another name")

/// Fails unless `body` wears `face`: skin, hair and facial hair, their colours, and eyes
/datum/unit_test/voidcrew_outpost_npc_looks/proc/check_wears(mob/living/carbon/human/body, datum/outpost_npc_look/face, who)
	TEST_ASSERT_EQUAL(body.skin_tone, face.skin_tone, "[who] has another skin tone")
	TEST_ASSERT_EQUAL(body.hairstyle, face.hairstyle, "[who] has another haircut")
	TEST_ASSERT_EQUAL(body.hair_color, face.hair_color, "[who] has another hair colour")
	TEST_ASSERT_EQUAL(body.facial_hairstyle, face.facial_hairstyle, "[who] has another beard")
	TEST_ASSERT_EQUAL(body.eye_color_left, face.eye_color, "[who] has other eyes")

/// Something to stand an ambient NPC up in with a pickaxe on the belt
/datum/outfit/ambient_looks_test
	name = "Ambient looks test: belt pickaxe"
	uniform = /obj/item/clothing/under/color/grey
	belt = /obj/item/pickaxe

/mob/living/carbon/human/npc/ambient_npc/looks_test
	outfit = /datum/outfit/ambient_looks_test

/**
 * Ambient NPCs hold what they carry as a real item in hand: a prop locked to them for show (a mop, a
 * parcel), or something of their own taken off their belt and put back. Work puts a lit welder (with
 * the visor down), a wrench or a parcel in hand. What ambient_held_look_type() stands in for is a
 * real item a person can hold.
 */
/datum/unit_test/voidcrew_ambient_held_looks

/datum/unit_test/voidcrew_ambient_held_looks/Run()
	// What ambient_held_look_type() stands a held thing in for
	TEST_ASSERT_EQUAL(ambient_held_look_type(/obj/structure/closet/crate), /obj/item/delivery/big, "A crate held look is not a big parcel")
	TEST_ASSERT_EQUAL(ambient_held_look_type(/obj/item/storage/box/papersack), /obj/item/delivery/small, "A papersack held look is not a small parcel")
	TEST_ASSERT_EQUAL(ambient_held_look_type(/obj/item/storage/bag/tray), /obj/item/reagent_containers/cup/bucket, "A tray held look is not a bucket")
	TEST_ASSERT_EQUAL(ambient_held_look_type(/obj/item/reagent_containers/cup/glass/flask), /obj/item/reagent_containers/cup/glass/bottle/holywater, "A flask held look is not a metal flask")
	TEST_ASSERT_NULL(ambient_held_look_type(/obj/item/stack/ore/iron), "Ore is held with nothing to draw it")
	TEST_ASSERT_NULL(ambient_held_look_type(/obj/item/food/meat/slab), "A meat slab is held with nothing to draw it")
	TEST_ASSERT_NULL(ambient_held_look_type(/obj/item/food/meat/steak/plain/human), "A steak is held with nothing to draw it")

	// A prop in hand: real, locked to them, gone when they let go
	var/mob/living/carbon/human/npc/ambient_npc/npc = allocate(/mob/living/carbon/human/npc/ambient_npc, run_loc_floor_bottom_left)
	npc.set_held(/obj/item/mop)
	var/obj/item/mop/mop = locate() in npc.held_items
	TEST_ASSERT_NOTNULL(mop, "Holding a mop put no mop in their hand")
	TEST_ASSERT_EQUAL(npc.held_visual, /obj/item/mop, "Holding a mop did not set held_visual")
	TEST_ASSERT(HAS_TRAIT(mop, "human_npc_gear"), "A held mop is loot") // TRAIT_HUMAN_NPC_GEAR
	npc.set_held(null)
	TEST_ASSERT(QDELETED(mop), "Letting go of a prop mop left it about")
	TEST_ASSERT_NULL(npc.held_visual, "Letting go did not clear held_visual")
	TEST_ASSERT_NULL(npc.get_active_held_item(), "Letting go left something in their hand")

	// Their own tool comes off the belt and goes back on it
	var/mob/living/carbon/human/npc/ambient_npc/looks_test/miner = allocate(/mob/living/carbon/human/npc/ambient_npc/looks_test, run_loc_floor_bottom_left)
	var/obj/item/pickaxe/pick = miner.belt
	TEST_ASSERT(istype(pick), "The test miner wears no pickaxe on the belt")
	miner.set_held(/obj/item/pickaxe)
	TEST_ASSERT(miner.is_holding(pick), "A miner did not take their own pickaxe off the belt")
	miner.set_held(null)
	TEST_ASSERT(!QDELETED(pick) && miner.belt == pick, "A miner's own pickaxe did not go back on the belt")

	// Work: a lit welder with the visor down, then a wrench, then empty hands
	var/obj/item/clothing/head/utility/welding/visor = allocate(/obj/item/clothing/head/utility/welding)
	npc.equip_to_slot_or_del(visor, ITEM_SLOT_HEAD)
	npc.show_work_look("weld")
	var/obj/item/weldingtool/welder = locate() in npc.held_items
	TEST_ASSERT_NOTNULL(welder, "Welding put no welder in their hand")
	TEST_ASSERT(welder?.welding, "A welder held for welding is not lit")
	TEST_ASSERT(!visor.up, "Someone welds with the visor up")
	npc.show_work_look("tool")
	TEST_ASSERT(QDELETED(welder), "The welder stayed about after the work changed")
	TEST_ASSERT(locate(/obj/item/wrench) in npc.held_items, "Tool work put no wrench in their hand")
	TEST_ASSERT(visor.up, "Someone walks about with the visor down")
	npc.show_work_look(null)
	TEST_ASSERT_NULL(locate(/obj/item/wrench) in npc.held_items, "The wrench stayed in hand after the work")

	// The work loop: a droid keeps its box overlay; a person carries a real parcel instead
	var/obj/structure/outpost_yard_droid/droid = allocate(/obj/structure/outpost_yard_droid)
	var/datum/component/outpost_ambient_worker/droid_worker = droid.GetComponent(/datum/component/outpost_ambient_worker)
	TEST_ASSERT_NOTNULL(droid_worker, "A yard droid has no work component")
	droid_worker.set_carried(TRUE)
	TEST_ASSERT_NOTNULL(droid_worker.carried, "A carrying droid has no box overlay")

	var/mob/living/carbon/human/npc/ambient_npc/hauler = allocate(/mob/living/carbon/human/npc/ambient_npc, run_loc_floor_top_right)
	var/datum/component/outpost_ambient_worker/hauler_worker = hauler.AddComponent(/datum/component/outpost_ambient_worker, list(), FALSE, CALLBACK(hauler, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc, show_work_look)))
	hauler_worker.set_carried(TRUE)
	TEST_ASSERT_EQUAL(hauler.work_look, "carry", "A carrying person's work_look was not set to carry")
	TEST_ASSERT(locate(/obj/item/delivery/big) in hauler.held_items, "A carrying person has no parcel in hand")
	TEST_ASSERT_NULL(hauler_worker.carried, "A carrying person got a box overlay like a droid")
	hauler_worker.set_carried(FALSE)
	TEST_ASSERT_NULL(hauler.work_look, "Putting it down left the carry look on")
	TEST_ASSERT_NULL(locate(/obj/item/delivery/big) in hauler.held_items, "Putting it down left the parcel in hand")

	// The held-look cache the basic mobs still use is bounded: only the newest entries survive
	var/bare_look = get_outpost_npc_look(/datum/outfit/ambient_customer, MALE, 1)
	outpost_npc_held_look_cache_add("held_test_1", bare_look, 3)
	outpost_npc_held_look_cache_add("held_test_2", bare_look, 3)
	outpost_npc_held_look_cache_add("held_test_3", bare_look, 3)
	outpost_npc_held_look_cache_add("held_test_4", bare_look, 3)
	outpost_npc_held_look_cache_add("held_test_5", bare_look, 3)
	TEST_ASSERT_EQUAL(length(GLOB.outpost_npc_held_look_keys), 3, "The bounded held-look cache did not stay at 3 keys")
	TEST_ASSERT_EQUAL(GLOB.outpost_npc_held_look_keys[1], "held_test_3", "The bounded held-look cache dropped the wrong entry")
	TEST_ASSERT_NULL(GLOB.outpost_npc_looks["held_test_1"], "An evicted held look was not dropped")
	TEST_ASSERT_NOTNULL(GLOB.outpost_npc_looks["held_test_5"], "A kept held look was dropped")
	for(var/leftover_key in list("held_test_3", "held_test_4", "held_test_5"))
		GLOB.outpost_npc_looks -= leftover_key
		GLOB.outpost_npc_held_look_keys -= leftover_key
