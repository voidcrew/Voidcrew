// Plasma weapons on #512's human NPCs: the same wounds, melts and limps a player gets.

/// A rifle bolt on a human NPC's bare arm leaves a plasma burn, as on a player.
/datum/unit_test/voidcrew_plasma_human_npc_wound

/datum/unit_test/voidcrew_plasma_human_npc_wound/Run()
	var/turf/from = run_loc_floor_bottom_left
	var/turf/where = locate(from.x + 2, from.y, from.z)
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner, where)
	var/obj/projectile/energy/plasma_bolt/heavy/bolt = allocate(/obj/projectile/energy/plasma_bolt/heavy, from)
	bolt.starting = from
	bolt.def_zone = BODY_ZONE_L_ARM
	npc.bullet_act(bolt, BODY_ZONE_L_ARM)
	var/obj/item/bodypart/arm = npc.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(arm, "One rifle bolt melted an NPC's unhurt arm")
	TEST_ASSERT_NOTNULL(arm.get_wound_type(/datum/wound/burn/flesh/plasma), "A rifle bolt on an NPC's arm left no plasma burn")

/// A melted NPC hand lets its locked gun fall as an untouchable look-alike; the stump is seared, not wet,
/// on the flesh path and on the dry (robot limb) path.
/datum/unit_test/voidcrew_plasma_human_npc_melt

/datum/unit_test/voidcrew_plasma_human_npc_melt/Run()
	var/mob/living/carbon/human/npc/sample/gunner/npc = allocate(/mob/living/carbon/human/npc/sample/gunner)
	var/turf/where = get_turf(npc)
	var/obj/item/gun/gun = locate() in npc.held_items
	TEST_ASSERT_NOTNULL(gun, "Test fixture: the gunner holds no gun")
	// "human_npc_gear" is TRAIT_HUMAN_NPC_GEAR: voidcrew defines load after the unit tests
	TEST_ASSERT(HAS_TRAIT(gun, "human_npc_gear"), "Test fixture: the gunner's gun is not locked to it")
	var/obj/item/bodypart/arm = npc.get_bodypart(IS_LEFT_INDEX(npc.get_held_index_of_item(gun)) ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM)
	var/zone = arm.body_zone
	TEST_ASSERT(plasma_melt_limb(arm, SOUTH), "An NPC's gun arm did not melt off")
	TEST_ASSERT_NULL(npc.get_bodypart(zone), "The melted NPC arm is still attached")
	TEST_ASSERT(LAZYACCESS(npc.hv_stump_burnt, zone), "A melted NPC arm left an unseared stump")
	TEST_ASSERT(!LAZYACCESS(npc.hv_stump_torn_at, zone), "A melted NPC arm left a wet stump")
	var/obj/item/plasma_melt_lost_gear/look = locate() in where
	TEST_ASSERT_NOTNULL(look, "No look-alike of the NPC's gun falls out of the melt")
	TEST_ASSERT_EQUAL(look.mouse_opacity, MOUSE_OPACITY_TRANSPARENT, "The gun's look-alike can be clicked")
	TEST_ASSERT(look.anchored, "The gun's look-alike can be moved")
	qdel(look)

	var/obj/item/bodypart/leg/left/robot/robot_leg = new
	robot_leg.replace_limb(npc, TRUE)
	TEST_ASSERT_EQUAL(npc.get_bodypart(BODY_ZONE_L_LEG), robot_leg, "Test fixture: could not fit a robot leg")
	TEST_ASSERT(plasma_melt_limb(robot_leg, SOUTH), "An NPC's robot leg did not melt off")
	TEST_ASSERT_NULL(npc.get_bodypart(BODY_ZONE_L_LEG), "The melted robot leg is still attached")
	TEST_ASSERT(LAZYACCESS(npc.hv_stump_burnt, BODY_ZONE_L_LEG), "A dry melt left an unseared stump")
	TEST_ASSERT(!LAZYACCESS(npc.hv_stump_torn_at, BODY_ZONE_L_LEG), "A dry melt left a wet stump")
	TEST_ASSERT(isnull(npc.hv_sever_spray), "A dry melt left the body's spray held back")
	for(var/obj/effect/decal/cleanable/leftover in where)
		qdel(leftover)

/// A dormant NPC's slag neither cools nor cooks; when it wakes it goes on at the normal rate, with no catch-up.
/datum/unit_test/voidcrew_plasma_human_npc_dormant_cooling

/datum/unit_test/voidcrew_plasma_human_npc_dormant_cooling/Run()
	var/mob/living/carbon/human/npc/sample/swashbuckler/npc = allocate(/mob/living/carbon/human/npc/sample/swashbuckler)
	var/turf/here = get_turf(npc)
	TEST_ASSERT(!length(SSmobs.clients_by_zlevel[here.z]), "Test fixture: a client is on the test z-level")
	var/obj/item/bodypart/chest = npc.get_bodypart(BODY_ZONE_CHEST)
	chest.force_wound_upwards(/datum/wound/burn/flesh/plasma/severe)
	var/datum/wound/burn/flesh/plasma/burn = chest.get_wound_type(/datum/wound/burn/flesh/plasma)
	TEST_ASSERT_NOTNULL(burn, "Test fixture: no severe plasma burn on the NPC")
	var/start_heat = burn.heat
	var/start_burn = chest.burn_dam
	TEST_ASSERT(start_heat > 2, "Test fixture: a fresh severe plasma burn is not hot")

	for(var/tick in 1 to 5)
		npc.Life(SSMOBS_DT, tick)
	TEST_ASSERT_EQUAL(burn.heat, start_heat, "A dormant NPC's slag cooled")
	TEST_ASSERT_EQUAL(chest.burn_dam, start_burn, "A dormant NPC's slag kept cooking")

	// It slept a long while; a player arrives for one Life()
	burn.last_tick_at = world.time - 10 MINUTES
	SSmobs.clients_by_zlevel[here.z] += npc
	npc.Life(SSMOBS_DT, 6)
	SSmobs.clients_by_zlevel[here.z] -= npc
	TEST_ASSERT(!QDELETED(burn), "The plasma burn closed when the NPC woke")
	var/cooled = start_heat - burn.heat
	TEST_ASSERT(cooled > 0, "An awake NPC's slag did not cool")
	TEST_ASSERT(cooled <= SSMOBS_DT * 2, "A waking NPC's slag cooled [cooled] in one tick: it caught up the time it slept")
	TEST_ASSERT_EQUAL(burn.last_tick_at, world.time, "The burn did not note its tick")

/// A limp slows an AI-driven NPC's next step, as it slows a player's
/datum/unit_test/voidcrew_plasma_human_npc_limp

/datum/unit_test/voidcrew_plasma_human_npc_limp/Run()
	var/mob/living/carbon/human/npc/sample/swashbuckler/npc = allocate(/mob/living/carbon/human/npc/sample/swashbuckler)
	TEST_ASSERT_NOTNULL(npc.ai_controller, "Test fixture: the NPC has no AI")
	var/obj/item/bodypart/leg = npc.get_bodypart(BODY_ZONE_L_LEG)
	leg.force_wound_upwards(/datum/wound/burn/flesh/plasma/critical)
	var/datum/status_effect/limp/limp = npc.has_status_effect(/datum/status_effect/limp)
	TEST_ASSERT_NOTNULL(limp, "A critical plasma burn on an NPC's leg did not make it limp")
	TEST_ASSERT(limp.slowdown_left > 0, "The NPC's limp has no slowdown on the burnt leg")
	limp.limp_chance_left = 100
	limp.next_leg = limp.left
	limp.check_step(npc, null, NORTH, FALSE)
	TEST_ASSERT(npc.has_movespeed_modifier(/datum/movespeed_modifier/npc_limp), "A limping step did not slow the NPC")
	// The next step is on the good leg: the slowdown goes
	limp.check_step(npc, null, NORTH, FALSE)
	TEST_ASSERT(!npc.has_movespeed_modifier(/datum/movespeed_modifier/npc_limp), "A step on the good leg kept the NPC slowed")
	npc.remove_status_effect(/datum/status_effect/limp)
	TEST_ASSERT(!npc.has_movespeed_modifier(/datum/movespeed_modifier/npc_limp), "The limp's slowdown outlived the limp")
