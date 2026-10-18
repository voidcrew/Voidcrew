/// The six Voidcrew guns have no schematic, receiver, crafting result or fabrication design.
/datum/unit_test/voidcrew_blueprint_guns/Run()
	var/list/guns = list(
		/obj/item/gun/ballistic/automatic/c20r,
		/obj/item/gun/ballistic/automatic/wt550,
		/obj/item/gun/energy/laser/carbine,
		/obj/item/gun/ballistic/automatic/l6_saw,
		/obj/item/gun/ballistic/rifle/sniper_rifle,
		/obj/item/gun/ballistic/shotgun/bulldog,
	)
	for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
		var/list/results = islist(recipe.result) ? recipe.result : list(recipe.result)
		for(var/result in results)
			for(var/gun_type in guns)
				TEST_ASSERT(!ispath(result, gun_type), "[recipe.type] still crafts [result].")
	for(var/design_id in SSresearch.techweb_designs)
		var/datum/design/design = SSresearch.techweb_designs[design_id]
		for(var/gun_type in guns)
			TEST_ASSERT(!ispath(design.build_path, gun_type), "[design.type] still fabricates [design.build_path].")

	// Text paths avoid recreating the removed parents or requiring deleted defines.
	for(var/removed_parent in list("/obj/item/blueprint", "/datum/crafting_recipe/blueprint", "/obj/item/gun_part"))
		TEST_ASSERT_NULL(text2path(removed_parent), "[removed_parent] still exists.")
	var/list/node_suffixes = list("c20r", "wt550", "carbine", "l6_saw", "sniper", "bulldog")
	for(var/removed_node in node_suffixes)
		TEST_ASSERT_NULL(SSresearch.techweb_nodes["weapon_part_[removed_node]"], "Receiver node [removed_node] still exists.")
	for(var/removed_family in list("c20r", "wt550", "laser_carbine", "l6_saw", "sniper_rifle", "bulldog"))
		TEST_ASSERT_NULL(text2path("/obj/item/blueprint/gun/[removed_family]"), "[removed_family] still has a gun schematic.")
		TEST_ASSERT_NULL(text2path("/obj/item/gun_part/[removed_family]"), "[removed_family] still has a receiver item.")
		TEST_ASSERT_NULL(text2path("/datum/design/gun_part_[removed_family]"), "[removed_family] still has a receiver design type.")
		TEST_ASSERT_NULL(text2path("/datum/techweb_node/weapon_part_[removed_family]"), "[removed_family] still has a receiver node type.")
		TEST_ASSERT_NULL(SSresearch.techweb_designs["vc_gun_part_[removed_family]"], "[removed_family] still has a receiver design.")
	for(var/node_id in SSresearch.techweb_nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id]
		for(var/removed_node in node_suffixes)
			TEST_ASSERT(!("weapon_part_[removed_node]" in node.prereq_ids), "[node_id] still requires a removed receiver node.")
	var/datum/design/receiver/modular_receiver = SSresearch.techweb_designs["receiver"]
	TEST_ASSERT_NOTNULL(modular_receiver, "The unrelated TG modular receiver design disappeared.")
	TEST_ASSERT_EQUAL(modular_receiver.build_path, /obj/item/weaponcrafting/receiver, "The modular receiver design has the wrong output.")
	TEST_ASSERT_EQUAL(modular_receiver.build_type, AUTOLATHE, "The TG modular receiver lost autolathe fabrication.")
	TEST_ASSERT(RND_CATEGORY_HACKED in modular_receiver.category, "The TG modular receiver lost its hacked-autolathe gate.")

/// Ammunition remains connected to the research tree, including specialist loads.
/datum/unit_test/voidcrew_gun_ammo_research/Run()
	var/list/reachable = list()
	var/previous_count = -1
	while(length(reachable) != previous_count)
		previous_count = length(reachable)
		for(var/node_id in SSresearch.techweb_nodes)
			var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id]
			if(!(node_id in reachable) && !length(node.prereq_ids - reachable))
				reachable += node_id
	var/list/ammo_prereqs = list(
		"weapon_ammo_c20r" = list(TECHWEB_NODE_RIOT_SUPRESSION),
		"weapon_ammo_wt550" = list(TECHWEB_NODE_RIOT_SUPRESSION),
		"weapon_ammo_sniper" = list(TECHWEB_NODE_EXOTIC_AMMO),
		"weapon_ammo_bulldog" = list(TECHWEB_NODE_EXOTIC_AMMO),
		"weapon_ammo_l6_saw" = list(TECHWEB_NODE_EXOTIC_AMMO, "automatic_ammo"),
	)
	var/list/ammo_designs = list(
		"weapon_ammo_c20r" = list("vc_ammo_smgm45"),
		"weapon_ammo_wt550" = list("vc_ammo_wt550"),
		"weapon_ammo_sniper" = list("vc_ammo_sniper_rounds"),
		"weapon_ammo_bulldog" = list("vc_ammo_m12g", "vc_ammo_m12g_slug"),
		"weapon_ammo_l6_saw" = list("vc_ammo_m7mm"),
	)
	for(var/node_id in ammo_prereqs)
		TEST_ASSERT(node_id in reachable, "Ammunition node [node_id] is unreachable.")
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id]
		TEST_ASSERT_NOTNULL(node, "Missing ammunition node [node_id].")
		var/list/expected_prereqs = ammo_prereqs[node_id]
		TEST_ASSERT_EQUAL(length(node.prereq_ids), length(expected_prereqs), "[node_id] has unexpected prerequisites.")
		TEST_ASSERT_EQUAL(length(expected_prereqs - node.prereq_ids), 0, "[node_id] lost an intended prerequisite.")
		for(var/design_id in ammo_designs[node_id])
			TEST_ASSERT(design_id in node.design_ids, "[node_id] lost ammunition design [design_id].")
			var/datum/design/design = SSresearch.techweb_designs[design_id]
			TEST_ASSERT_NOTNULL(design, "Missing ammunition design [design_id].")
			TEST_ASSERT_EQUAL(design.build_type, PROTOLATHE | AWAY_LATHE, "[design_id] lost its lathe channels.")
	for(var/node_id in list("bulldog_special_ammo", "l6_special_ammo", "sniper_special_ammo"))
		TEST_ASSERT(node_id in reachable, "Specialist ammunition node [node_id] is unreachable.")

	var/datum/design/pin_testing/pin = SSresearch.techweb_designs["pin_testing"]
	TEST_ASSERT_NOTNULL(pin, "The upstream test-range pin design must remain defined.")
	TEST_ASSERT_EQUAL(pin.build_type, PROTOLATHE | AWAY_LATHE, "Test-range pins lost their lathe channels.")
	var/datum/techweb_node/riot_supression/riot = SSresearch.techweb_nodes[TECHWEB_NODE_RIOT_SUPRESSION]
	TEST_ASSERT_NOTNULL(riot, "Riot Suppression must remain available.")
	TEST_ASSERT("pin_testing" in riot.design_ids, "Riot Suppression must unlock test-range pins.")
	TEST_ASSERT("clown_firing_pin" in riot.design_ids, "Riot Suppression lost another firing pin design.")

/// No Quarter's heavy cartridges are ordinary crafting recipes with the original cost.
/datum/unit_test/voidcrew_no_quarter_cartridge/Run()
	var/mob/living/carbon/human/consistent/crafter = allocate(__IMPLIED_TYPE__)
	var/datum/component/personal_crafting/crafting = crafter.AddComponent(__IMPLIED_TYPE__)
	crafting.ignored_flags = CRAFT_IGNORE_DO_AFTER
	var/datum/crafting_recipe/no_quarter_cartridge/recipe = locate(/datum/crafting_recipe/no_quarter_cartridge) in GLOB.crafting_recipes
	TEST_ASSERT_NOTNULL(recipe, "The No Quarter cartridge recipe disappeared.")
	TEST_ASSERT(!recipe.non_craftable, "The heavy cartridge is absent from the crafting menu.")
	TEST_ASSERT(crafting.is_recipe_available(recipe, crafter), "The heavy cartridge must be available without a schematic or imprint.")
	TEST_ASSERT_EQUAL(recipe.time, 3 SECONDS, "The heavy cartridge crafting time changed.")
	TEST_ASSERT(recipe.mass_craftable, "The heavy cartridge lost batch crafting.")
	TEST_ASSERT_EQUAL(crafting.construct_item(crafter, recipe), ", missing component.", "The heavy cartridge bypassed its ingredient cost.")
	var/obj/item/stack/sheet/iron/iron = allocate(__IMPLIED_TYPE__, crafter.loc, 2, FALSE)
	var/obj/item/paper/paper = allocate(__IMPLIED_TYPE__, crafter.loc)
	var/atom/result = crafting.construct_item(crafter, recipe)
	TEST_ASSERT(istype(result, /obj/item/ammo_casing/shotgun/no_quarter), "The heavy cartridge failed to craft without a schematic: [result].")
	TEST_ASSERT(QDELETED(iron) && QDELETED(paper), "Crafting a heavy cartridge did not consume two iron sheets and one paper.")
	qdel(result)

/// Map/loot guns and unrelated crafting recipes retain their ordinary loaded state.
/datum/unit_test/voidcrew_blueprint_ammo_scope/Run()
	var/obj/item/gun/ballistic/automatic/l6_saw/gun = allocate(__IMPLIED_TYPE__)
	var/obj/item/ammo_box/magazine/original_magazine = gun.magazine
	var/obj/item/ammo_casing/original_chamber = gun.chambered
	var/original_ammo = gun.get_ammo()
	TEST_ASSERT(original_ammo > 0, "An ordinary spawned L6 should still contain ammunition.")
	var/datum/crafting_recipe/unrelated_recipe = allocate(__IMPLIED_TYPE__)
	gun.on_craft_completion(list(), unrelated_recipe, null)
	TEST_ASSERT_EQUAL(gun.magazine, original_magazine, "An unrelated recipe lost its magazine.")
	TEST_ASSERT_EQUAL(gun.chambered, original_chamber, "An unrelated recipe lost its chambered round.")
	TEST_ASSERT_EQUAL(gun.get_ammo(), original_ammo, "An unrelated recipe lost ammunition.")
