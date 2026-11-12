// Package: P6 NPCs. Unit tests for voidcrew/modules/plasma_weapons/plasma_pirates.dm (human NPC pirates, PR #512).
//
// Fork defines are included after the tests, so their values are written out: zones 1 (green), 2 (yellow)
// and 3 (red); ranks HUMAN_NPC_RANK_BOSS 2; blackboard keys by their strings.

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_plasma_pirates
	abstract_type = /datum/unit_test/voidcrew_plasma_pirates
	/// Turfs a test changed, put back to plain floor when it ends
	var/list/turf/changed_turfs = list()

/datum/unit_test/voidcrew_plasma_pirates/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	return ..()

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner (the room is 5x5)
/datum/unit_test/voidcrew_plasma_pirates/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A human NPC built now at `where`, dressed in `outfit`
/datum/unit_test/voidcrew_plasma_pirates/proc/build_npc(npc_type, turf/where, outfit)
	var/datum/human_npc_order/order = spawn_human_npc(npc_type, where, outfit = outfit, immediate = TRUE)
	var/mob/living/carbon/human/npc/npc = order?.spawned_ref?.resolve()
	if(npc)
		allocated += npc
	return npc

/// The Cinder and the Furnace have their own handling; the Old Furnace is handled as a Furnace.
/datum/unit_test/voidcrew_plasma_pirates/handling

/datum/unit_test/voidcrew_plasma_pirates/handling/Run()
	var/list/expected = list(
		/obj/item/gun/energy/plasma_weapon/pistol = /datum/pirate_gun_handling/plasma,
		/obj/item/gun/energy/plasma_weapon/rifle = /datum/pirate_gun_handling/plasma/rifle,
		/obj/item/gun/energy/plasma_weapon/rifle/old_furnace = /datum/pirate_gun_handling/plasma/rifle,
	)
	for(var/gun_type in expected)
		var/obj/item/gun/gun = allocate(gun_type, spot(4, 4))
		var/datum/pirate_gun_handling/handling = pirate_gun_handling_for(gun)
		TEST_ASSERT_EQUAL(handling.type, expected[gun_type], "[gun_type] is handled as [handling.type]")

/// Green-zone pirates never carry plasma; yellow adds the Cinder; red adds both. The faction's own lists are untouched.
/datum/unit_test/voidcrew_plasma_pirates/zone_outfits

/datum/unit_test/voidcrew_plasma_pirates/zone_outfits/Run()
	for(var/faction in list("silverscale", "skeleton", "grey", "lustrous", "interdyne", "irs"))
		var/datum/human_npc_outfit_table/pirate/table = human_npc_singleton(text2path("/datum/human_npc_outfit_table/pirate/[faction]"))
		TEST_ASSERT_NOTNULL(table.plasma_pistol_outfit, "[faction] has no Cinder gunner")
		TEST_ASSERT_NOTNULL(table.plasma_rifle_outfit, "[faction] has no Furnace gunner")
		var/list/green_before = table.green.Copy()
		for(var/zone in 1 to 3)
			var/list/choices = table.outfits_for(null, zone)
			TEST_ASSERT_EQUAL(!!choices[table.plasma_pistol_outfit], zone >= 2, "A zone [zone] [faction] crew's Cinder gunner is wrong")
			TEST_ASSERT_EQUAL(!!choices[table.plasma_rifle_outfit], zone == 3, "A zone [zone] [faction] crew's Furnace gunner is wrong")
			for(var/outfit_type in green_before)
				TEST_ASSERT_EQUAL(choices[outfit_type], green_before[outfit_type], "A zone [zone] [faction] crew's weight for [outfit_type] changed")
		TEST_ASSERT_EQUAL(length(table.green), length(green_before), "Plasma gunners were written into [faction]'s own list")
		TEST_ASSERT_NULL(table.gunners[table.plasma_pistol_outfit], "Plasma gunners were written into [faction]'s gunners")
	for(var/table_type in list(/datum/human_npc_outfit_table/pirate/medieval, /datum/human_npc_outfit_table/pirate/nt_customs))
		var/datum/human_npc_outfit_table/pirate/table = human_npc_singleton(table_type)
		TEST_ASSERT_NULL(table.plasma_pistol_outfit, "[table_type] carries plasma")

/// Every plasma outfit holds its gun, loaded, with a full spare flask it can reach.
/datum/unit_test/voidcrew_plasma_pirates/dressed

/datum/unit_test/voidcrew_plasma_pirates/dressed/Run()
	var/list/outfits = list()
	for(var/faction in list("silverscale", "skeleton", "grey", "lustrous", "interdyne", "irs"))
		var/datum/human_npc_outfit_table/pirate/table = human_npc_singleton(text2path("/datum/human_npc_outfit_table/pirate/[faction]"))
		outfits += table.plasma_pistol_outfit
		outfits += table.plasma_rifle_outfit
		for(var/outfit_type in table.red_boss)
			outfits += outfit_type
	for(var/outfit_type in outfits)
		var/mob/living/carbon/human/npc/pirate = build_npc(/mob/living/carbon/human/npc/sample, run_loc_floor_bottom_left, outfit_type)
		TEST_ASSERT_NOTNULL(pirate, "[outfit_type] built nobody")
		var/obj/item/gun/energy/plasma_weapon/gun = pirate_plasma_held_gun(pirate)
		TEST_ASSERT_NOTNULL(gun, "[outfit_type] holds no plasma gun")
		TEST_ASSERT(gun.can_shoot(), "[outfit_type]'s gun isn't loaded")
		var/obj/item/plasma_flask/spare = pirate_plasma_spare_flask(pirate, gun)
		TEST_ASSERT_NOTNULL(spare, "[outfit_type] carries no spare flask it can reach")
		TEST_ASSERT_EQUAL(spare.stored, PLASMA_FLASK_CAPACITY, "[outfit_type]'s spare flask isn't full")
		qdel(pirate)

/// The red-zone Director Prime and Chief Auditor carry a Furnace, elsewhere their laser; both can drop the
/// Old Furnace, but only in a red zone.
/datum/unit_test/voidcrew_plasma_pirates/bosses

/datum/unit_test/voidcrew_plasma_pirates/bosses/Run()
	var/list/boss_types = list(
		/mob/living/carbon/human/npc/faction_pirate/interdyne/boss = /datum/human_npc_outfit_table/pirate/interdyne,
		/mob/living/carbon/human/npc/faction_pirate/irs/boss = /datum/human_npc_outfit_table/pirate/irs,
	)
	for(var/boss_type in boss_types)
		var/datum/human_npc_outfit_table/pirate/table = human_npc_singleton(boss_types[boss_type])
		var/mob/living/carbon/human/npc/faction_pirate/boss = build_npc(boss_type, spot(1, 1), table.boss[1])
		TEST_ASSERT_NOTNULL(boss, "[boss_type] built nobody")
		TEST_ASSERT_EQUAL(boss.npc_rank, 2, "Test fixture: [boss_type] isn't a boss")
		TEST_ASSERT(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace in boss.rare_loot_pool, "[boss_type] can't drop the Old Furnace")
		for(var/zone in 1 to 3)
			var/list/choices = table.outfits_for(boss, zone)
			var/carries_furnace = FALSE
			for(var/outfit_type in choices)
				var/datum/outfit/outfit = outfit_type
				if(ispath(initial(outfit.r_hand), /obj/item/gun/energy/plasma_weapon/rifle))
					carries_furnace = TRUE
			TEST_ASSERT_EQUAL(carries_furnace, zone == 3, "A zone [zone] [boss_type] [zone == 3 ? "carries no" : "carries a"] Furnace")
			boss.rolled_rare_loot = list(/obj/item/gun/energy/plasma_weapon/rifle/old_furnace)
			boss.npc_dressed_zone = zone
			var/list/drops = boss.npc_roll_death_loot()
			if(boss.npc_home_zone() == zone)
				TEST_ASSERT_EQUAL((/obj/item/gun/energy/plasma_weapon/rifle/old_furnace in drops), zone == 3, "A zone [zone] [boss_type]'s Old Furnace roll was [zone == 3 ? "dropped" : "kept"]")
		qdel(boss)

/// A dry gunner with a spare changes flasks.
/datum/unit_test/voidcrew_plasma_pirates/flask_change

/datum/unit_test/voidcrew_plasma_pirates/flask_change/Run()
	var/mob/living/carbon/human/npc/faction_pirate/gunner = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/ranged, spot(0, 0), /datum/outfit/piratecorpse/faction/irs/ranged/cinder)
	var/obj/item/gun/energy/plasma_weapon/gun = pirate_plasma_held_gun(gunner)
	TEST_ASSERT_NOTNULL(gun, "Test fixture: the gunner holds no Cinder")
	gun.cell.charge = 0
	gun.chamber_changed()
	TEST_ASSERT(!gun.can_shoot(), "Test fixture: an empty Cinder still fires")
	var/datum/ai_controller/controller = gunner.ai_controller
	controller.set_blackboard_key("human_npc_arming_retry_at", 0)
	var/datum/ai_planning_subtree/arm = GLOB.ai_subtrees[/datum/ai_planning_subtree/human_npc_arm/pirate_crew]
	TEST_ASSERT_NOTNULL(arm, "Test fixture: no pirate arming subtree")
	controller.planned_behaviors = list()
	TEST_ASSERT_EQUAL(arm.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A dry plasma gunner with a spare did nothing")
	TEST_ASSERT(controller.planned_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/pirate_plasma_reload)], "A dry plasma gunner with a spare didn't change flasks")
	var/datum/ai_behavior/pirate_plasma_reload/reload = GET_AI_BEHAVIOR(/datum/ai_behavior/pirate_plasma_reload)
	var/obj/item/plasma_flask/spare = pirate_plasma_spare_flask(gunner, gun)
	reload.perform(1, controller)
	TEST_ASSERT(gunner.is_holding(spare), "The gunner didn't take its spare flask in hand")
	TEST_ASSERT(gun.load_flask(spare, null), "The spare flask wouldn't go in")
	TEST_ASSERT(gun.can_shoot(), "A changed flask didn't load the Cinder")

/// A hot Furnace in air: it holds fire and backs off until the coils cool, and never vents. In vacuum it vents.
/datum/unit_test/voidcrew_plasma_pirates/heat

/datum/unit_test/voidcrew_plasma_pirates/heat/Run()
	var/mob/living/carbon/human/npc/faction_pirate/gunner = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/ranged, spot(1, 1), /datum/outfit/piratecorpse/faction/irs/ranged/furnace)
	var/obj/item/gun/energy/plasma_weapon/gun = pirate_plasma_held_gun(gunner)
	TEST_ASSERT(gun?.uses_heat, "Test fixture: the gunner holds no Furnace")
	var/mob/living/carbon/human/consistent/mark = allocate(/mob/living/carbon/human/consistent, spot(3, 1))
	var/datum/ai_controller/controller = gunner.ai_controller
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, mark)
	var/datum/ai_planning_subtree/arm = GLOB.ai_subtrees[/datum/ai_planning_subtree/human_npc_arm/pirate_crew]
	TEST_ASSERT(!pirate_plasma_safe_to_vent(get_turf(gunner)), "Plasma vented in a room's air would be safe")
	var/mol = gun.chamber_mol()
	gun.barrel_heat = 85
	controller.planned_behaviors = list()
	TEST_ASSERT_EQUAL(arm.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A gunner with a hot Furnace kept firing")
	TEST_ASSERT(controller.blackboard["pirate_plasma_cooling"], "A gunner with a hot Furnace isn't waiting for it to cool")
	TEST_ASSERT(!controller.planned_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/pirate_plasma_vent)], "A gunner vented its Furnace indoors")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), mol, "Plasma left the Furnace indoors")
	gun.barrel_heat = 60
	controller.planned_behaviors = list()
	TEST_ASSERT_EQUAL(arm.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A gunner went back to firing before its Furnace cooled")
	gun.barrel_heat = 35
	controller.planned_behaviors = list()
	arm.SelectBehaviors(controller, 1)
	TEST_ASSERT(!controller.blackboard["pirate_plasma_cooling"], "A gunner kept waiting on a cool Furnace")

	// Where there is next to no air it vents by hand
	var/turf/airless = spot(1, 3)
	changed_turfs |= airless
	airless.ChangeTurf(/turf/open/floor/iron/airless)
	gunner.forceMove(airless)
	TEST_ASSERT(pirate_plasma_safe_to_vent(airless), "Plasma vented on an airless floor would catch")
	gun.barrel_heat = 70
	gun.next_vent_at = 0
	controller.planned_behaviors = list()
	TEST_ASSERT_EQUAL(arm.SelectBehaviors(controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A gunner with a warm Furnace in vacuum did nothing")
	TEST_ASSERT(controller.planned_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/pirate_plasma_vent)], "A gunner in vacuum didn't vent its warm Furnace")
	var/datum/ai_behavior/pirate_plasma_vent/vent = GET_AI_BEHAVIOR(/datum/ai_behavior/pirate_plasma_vent)
	vent.perform(1, controller)
	TEST_ASSERT(gun.barrel_heat < 70, "Venting didn't cool the Furnace")
	TEST_ASSERT(gun.chamber_mol() < mol, "Venting released no plasma")
