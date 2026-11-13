// Stealth step 4: the scav den (voidcrew/modules/stealth/scav_den.dm, scav_camera.dm). Unit tests compile before
// voidcrew/_DEFINES, so values are written out: ACCESS_SCAV_VAULT "scav_vault", ZONE_GREEN/YELLOW/RED 1/2/3, camera
// states SCAN 1, TRACK 2, ALARM 3, OFF 4.

/// Den guards carry a person's name, their pass is in it, and their friends can call them by it. The boss's pass opens the vault.
/datum/unit_test/voidcrew_stealth_den_names

/datum/unit_test/voidcrew_stealth_den_names/Run()
	for(var/guard_type in list(/mob/living/carbon/human/npc/ruin/trooper/scav/den, /mob/living/carbon/human/npc/ruin/trooper/scav/gunner/den, /mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den))
		var/mob/living/carbon/human/npc/guard = allocate(guard_type, run_loc_floor_bottom_left)
		TEST_ASSERT(guard.real_name && guard.real_name != "Scav Guard" && guard.real_name != "Scav Lookout", "[guard_type] has no name of its own ([guard.real_name])")
		TEST_ASSERT_NOTNULL(stealth_first_name(guard), "[guard_type]'s friends can't call it by name")
		var/obj/item/card/id/card = guard.wear_id?.GetID()
		TEST_ASSERT(istype(card, /obj/item/card/id/advanced/black/scav), "[guard_type] has no scav pass")
		TEST_ASSERT_EQUAL(card.registered_name, guard.real_name, "[guard_type]'s pass is in someone else's name")
	var/mob/living/carbon/human/npc/boss = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den/boss, run_loc_floor_bottom_left)
	var/obj/item/card/id/boss_card = boss.wear_id?.GetID()
	TEST_ASSERT(istype(boss_card, /obj/item/card/id/advanced/black/scav/vault), "The den boss has no vault pass")
	TEST_ASSERT(("scav_vault" in boss_card.access) && ("scav" in boss_card.access), "The vault pass doesn't open the vault and the den")
	TEST_ASSERT_EQUAL(boss_card.registered_name, boss.real_name, "The boss's pass is in someone else's name")
	TEST_ASSERT(boss.stealth_radio, "The den boss has no radio")

/// The vault rolls cyberware by zone, never the same piece twice, plus one piece of stealth gear from its hook.
/datum/unit_test/voidcrew_stealth_den_vault

/datum/unit_test/voidcrew_stealth_den_vault/Run()
	var/list/expected = list(2, 3, 4)
	for(var/zone in 1 to 3)
		var/obj/structure/closet/crate/secure/scav_vault/crate = allocate(/obj/structure/closet/crate/secure/scav_vault, run_loc_floor_bottom_left)
		var/list/made = crate.scav_vault_roll(zone)
		TEST_ASSERT_EQUAL(length(made), expected[zone] + 1, "A zone [zone] vault paid the wrong number of pieces")
		var/list/seen = list()
		var/stealth_pieces = 0
		for(var/obj/item/piece as anything in made)
			if(crate.scav_vault_stealth_loot()[piece.type])
				stealth_pieces++
				continue
			TEST_ASSERT(istype(piece, /obj/item/organ), "A vault paid [piece.type], which isn't chrome")
			TEST_ASSERT(!seen[piece.type], "A vault paid [piece.type] twice")
			seen[piece.type] = TRUE
			TEST_ASSERT_EQUAL(piece.loc, crate, "A vault piece landed outside the crate")
		TEST_ASSERT_EQUAL(stealth_pieces, 1, "A vault didn't pay one piece of stealth gear")
	var/obj/structure/closet/crate/secure/scav_vault/locked = allocate(/obj/structure/closet/crate/secure/scav_vault, run_loc_floor_bottom_left)
	TEST_ASSERT(locked.locked, "The vault crate isn't locked")
	TEST_ASSERT("scav_vault" in locked.req_access, "The vault crate doesn't want the vault pass")

/// The tip points at a registered den in the contested lanes, and a sealed den chart won't open while a den is out there.
/datum/unit_test/voidcrew_stealth_den_chart

/datum/unit_test/voidcrew_stealth_den_chart/Run()
	var/datum/map_template/ruin/space/template
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[template_name]
		if(candidate.type == /datum/map_template/ruin/space/rare/scav_den)
			template = candidate
	TEST_ASSERT_NOTNULL(template, "The scav den template isn't registered")
	TEST_ASSERT(template.width && template.height, "The scav den map didn't load its size")
	TEST_ASSERT(template.unpickable, "The scav den can seed by itself")
	TEST_ASSERT_EQUAL(/datum/shop_sku/ruin_chart/scav_den::spawn_zone, 2, "The den tip doesn't point at the contested lanes")
	TEST_ASSERT_EQUAL(/datum/shop_sku/ruin_chart/scav_den::chart_type, /datum/rumor_chart/scav_den, "The den tip uploads a chart that ignores the one-den rule")
	TEST_ASSERT_NULL(scav_den_on_map(), "A den is on the map before any was revealed")
	var/obj/structure/overmap/space_ruin/den = allocate(/obj/structure/overmap/space_ruin, run_loc_floor_bottom_left)
	den.set_ruin_template(template)
	TEST_ASSERT_EQUAL(scav_den_on_map(), den, "A den on the map isn't found")
	var/datum/rumor_chart/scav_den/chart = allocate(/datum/rumor_chart/scav_den)
	chart.ruin_template_path = /datum/map_template/ruin/space/rare/scav_den
	chart.spawn_zone = 2
	TEST_ASSERT_NULL(chart.reveal(null), "A second den opened while one was out there")
	TEST_ASSERT(!chart.revealed, "A refused den chart was used up")
	// A revealed den is never a contract's site (a held den would rebuild with a fresh vault).
	scav_den_claim(den)
	TEST_ASSERT(den.mission_exclusive, "A revealed den can be held by a contract")
	// Nobody docked within the hour: it leaves and frees the slot.
	scav_den_move_on(WEAKREF(den))
	TEST_ASSERT(QDELETED(den), "An unvisited den stayed on the overmap")
	TEST_ASSERT_NULL(scav_den_on_map(), "A den that moved on still holds the slot")

/// The camera sees a person in its cone in light, not in the dark, not out of its cone, not through a wall, and lets a
/// scav disguise by; held on someone long enough it sounds the alarm, and the den's guard goes to look.
/datum/unit_test/voidcrew_stealth_live/den_camera

/datum/unit_test/voidcrew_stealth_live/den_camera/Run()
	TEST_ASSERT(make_room(11, 9), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 0))
	// Hung on the north wall, looking south.
	var/obj/machinery/scav_camera/camera = allocate(/obj/machinery/scav_camera/directional/north, at(5, 8))
	var/turf/eye = get_turf(camera)
	TEST_ASSERT_EQUAL(camera.aim, 180, "A camera hung on the north wall doesn't look south")
	var/mob/living/carbon/human/person = person_at(5, 4)
	TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera doesn't see a person in front of it")
	GLOB.stealth_test_dark_turfs[get_turf(person)] = TRUE
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "The camera sees a person standing in the dark")
	GLOB.stealth_test_dark_turfs[get_turf(person)] = FALSE
	person.forceMove(at(10, 7))
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "The camera sees a person off to its side")
	person.forceMove(at(5, 4))
	var/turf/wall_spot = at(5, 6)
	wall_spot.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "The camera sees through a wall")
	wall_spot.ChangeTurf(/turf/open/floor/iron)
	GLOB.stealth_test_dark_turfs[wall_spot] = FALSE
	var/obj/item/clothing/under/syndicate/scav/fatigues = allocate(/obj/item/clothing/under/syndicate/scav)
	var/obj/item/clothing/mask/balaclava/scav/mask = allocate(/obj/item/clothing/mask/balaclava/scav)
	var/obj/item/clothing/under/own_clothes = person.w_uniform
	if(own_clothes)
		person.temporarilyRemoveItemFromInventory(own_clothes, force = TRUE)
	person.equip_to_slot_if_possible(fatigues, ITEM_SLOT_ICLOTHING, disable_warning = TRUE)
	person.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK, disable_warning = TRUE)
	var/datum/component/stealth_disguise/cache = stealth_disguise_cache(person)
	cache.refresh()
	TEST_ASSERT(!camera.scav_cam_sees(person, eye), "The camera doesn't let a scav disguise by")
	person.temporarilyRemoveItemFromInventory(mask, force = TRUE)
	cache.refresh()
	TEST_ASSERT(camera.scav_cam_sees(person, eye), "The camera lets fatigues alone by")

	// The alarm.
	var/mob/living/carbon/human/npc/guard = guard_at(1, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = wake(guard)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "The guard isn't unaware before the alarm")
	person.forceMove(at(5, 4))
	for(var/tick in 1 to 15)
		camera.process(0.2)
		if(camera.cam_state == 3)
			break
	TEST_ASSERT_EQUAL(camera.cam_state, 3, "Two seconds in plain view didn't sound the camera's alarm")
	var/deadline = world.time + 5 SECONDS
	while(guard_ai.stealth_state() == "unaware" && world.time < deadline)
		sleep(1)
	TEST_ASSERT(guard_ai.stealth_state() != "unaware", "The den's guard didn't answer the camera's alarm")

	// An EMP shuts it off and hides its cone.
	camera.emp_act(EMP_LIGHT)
	TEST_ASSERT_EQUAL(camera.cam_state, 4, "An EMP didn't shut the camera off")
	TEST_ASSERT_EQUAL(camera.cone.alpha, 0, "An EMP'd camera still shows its cone")

/// The den's harvester gang: every outfit keeps the disguise set reachable (scav fatigues showing, the mask slot free for
/// the balaclava, its suit read as a guard's own), and no den guard carries Syndicate kit. Their fatigues are loot, the
/// rest stays locked. They have red chrome eyes, and a harvester's apron, gloves and blade are bloodied.
/datum/unit_test/voidcrew_stealth_den_look

/datum/unit_test/voidcrew_stealth_den_look/Run()
	var/list/suits = stealth_guard_suits()
	for(var/table_type in list(/datum/human_npc_outfit_table/ruin/scav_den, /datum/human_npc_outfit_table/ruin/scav_den/gunner, /datum/human_npc_outfit_table/ruin/scav_den/boss))
		var/datum/human_npc_outfit_table/table = human_npc_singleton(table_type)
		for(var/list/outfits in list(table.green, table.yellow, table.red))
			for(var/datum/outfit/outfit as anything in outfits)
				TEST_ASSERT_NULL(initial(outfit.mask), "[outfit] takes the mask slot the balaclava needs")
				var/obj/item/clothing/suit/suit = initial(outfit.suit)
				if(suit)
					TEST_ASSERT(!(initial(suit.flags_inv) & HIDEJUMPSUIT), "[outfit]'s suit hides the fatigues")
					TEST_ASSERT(suits[suit], "[outfit]'s suit isn't read as a guard's own")
				for(var/hand in list(initial(outfit.r_hand), initial(outfit.l_hand)))
					TEST_ASSERT(!ispath(hand, /obj/item/melee/energy) && !ispath(hand, /obj/item/shield/energy), "[outfit] still carries Syndicate kit")
	for(var/guard_type in list(/mob/living/carbon/human/npc/ruin/trooper/scav/den, /mob/living/carbon/human/npc/ruin/trooper/scav/gunner/den, /mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den, /mob/living/carbon/human/npc/ruin/trooper/scav/lookout/den/boss))
		var/mob/living/carbon/human/npc/guard = allocate(guard_type, run_loc_floor_bottom_left)
		TEST_ASSERT(istype(guard.w_uniform, /obj/item/clothing/under/syndicate/scav), "[guard_type] isn't in scav fatigues")
		TEST_ASSERT(!HAS_TRAIT(guard.w_uniform, TRAIT_NO_STRIP), "[guard_type]'s fatigues are locked to it")
		if(guard.wear_suit)
			TEST_ASSERT(HAS_TRAIT(guard.wear_suit, TRAIT_NO_STRIP), "[guard_type]'s [guard.wear_suit] can be looted")
		var/obj/item/organ/eyes/eyes = guard.get_organ_slot(ORGAN_SLOT_EYES)
		TEST_ASSERT(istype(eyes, /obj/item/organ/eyes/robotic), "[guard_type] has no chrome eyes")
		TEST_ASSERT_EQUAL(eyes.eye_color_left, "#ff2a1a", "[guard_type]'s chrome eyes aren't red")
	var/mob/living/carbon/human/consistent/butcher = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	butcher.equipOutfit(/datum/outfit/ruin_npc/scav_den/butcher/saw)
	TEST_ASSERT(istype(butcher.wear_suit, /obj/item/clothing/suit/apron/waders), "The harvester has no waders")
	TEST_ASSERT(GET_ATOM_BLOOD_DNA_LENGTH(butcher.wear_suit), "The harvester's apron is clean")
	TEST_ASSERT(GET_ATOM_BLOOD_DNA_LENGTH(butcher.gloves), "The harvester's gloves are clean")
	var/obj/item/circular_saw/cruel/saw = locate() in butcher.held_items
	TEST_ASSERT_NOTNULL(saw, "The harvester has no saw")
	TEST_ASSERT(GET_ATOM_BLOOD_DNA_LENGTH(saw), "The harvester's saw is clean")
