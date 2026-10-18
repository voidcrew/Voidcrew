/// Test the finished kits, after Workshop pre_equip has replaced inherited lists.
/datum/unit_test/voidcrew_ladder_outfits/Run()
	var/list/role_outfits = list(
		/datum/outfit/job/miner,
		/datum/outfit/job/miner/equipped,
		/datum/outfit/job/miner/syndicate,
		/datum/outfit/job/miner/syndicate_cutter,
		/datum/outfit/job/miner/western,
		/datum/outfit/job/security,
		/datum/outfit/job/security/corporate,
		/datum/outfit/job/warden,
		/datum/outfit/job/hos,
		/datum/outfit/job/workshop_bogatyr_job_12,
		/datum/outfit/job/workshop_bogatyr_job_14,
		/datum/outfit/job/workshop_bogatyr_job_3,
		/datum/outfit/job/workshop_bogatyr_job_29,
		/datum/outfit/job/workshop_bogatyr_job_34,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_18,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_8,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_5,
		/datum/outfit/job/workshop_ship_nanobead_job_52,
		/datum/outfit/job/workshop_ship_nanobead_job_20,
		/datum/outfit/job/workshop_ship_nanobead_job_68,
		/datum/outfit/job/workshop_ship_nanobead_job_36,
		/datum/outfit/job/workshop_squab_job_15,
		/datum/outfit/job/workshop_squab_job_9,
		/datum/outfit/job/workshop_squab_job_19,
	)
	var/list/other_outfits = list(
		/datum/outfit/job/captain/syndicate,
		/datum/outfit/job/assistant/syndicate,
		/datum/outfit/job/bridge_assistant,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_20,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_12,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_14,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_21,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_9,
		/datum/outfit/job/workshop_hiryu_class_carrier_job_15,
		/datum/outfit/job/workshop_ship_nanobead_job_5,
		/datum/outfit/job/workshop_ship_nanobead_job_7,
	)
	for(var/outfit_type in role_outfits + other_outfits)
		var/datum/outfit/job/outfit = allocate(outfit_type)
		var/mob/living/carbon/human/consistent/wearer = allocate(__IMPLIED_TYPE__)
		outfit.equip(wearer)
		var/knives = 0
		for(var/obj/item/item in wearer.get_all_contents())
			TEST_ASSERT(!is_ladder_combat_gun(item.type), "[outfit_type] starts with [item.type].")
			TEST_ASSERT(!is_ladder_restricted_melee(item.type), "[outfit_type] starts with restricted melee [item.type].")
			TEST_ASSERT(!istype(item, /obj/item/sharpener), "[outfit_type] starts with a whetstone.")
			if(item.type == /obj/item/knife/combat/survival)
				knives++
		if(outfit_type in role_outfits)
			TEST_ASSERT_EQUAL(knives, 1, "[outfit_type] must have exactly one survival knife.")
		if(outfit_type == /datum/outfit/job/workshop_hiryu_class_carrier_job_18)
			TEST_ASSERT(locate(/obj/item/weldingtool/hugetank) in wearer.get_all_contents(), "The exosuit pilot lost their welder.")
		if(outfit_type == /datum/outfit/job/security || outfit_type == /datum/outfit/job/warden)
			TEST_ASSERT(istype(wearer.s_store, /obj/item/gun/energy/disabler), "[outfit_type] lost its disabler.")
		if(outfit_type == /datum/outfit/job/hos)
			TEST_ASSERT(locate(/obj/item/melee/baton/security/loaded/hos) in wearer.get_all_contents(), "HoS lost their control baton.")

	var/datum/voucher_set/mining/crusher_kit/voucher = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(/obj/item/gun/energy/recharge/kinetic_accelerator in voucher.set_items, "The mining voucher must offer an accelerator.")
	TEST_ASSERT(!(/obj/item/kinetic_crusher in voucher.set_items), "The starting voucher still offers a crusher.")
	var/obj/effect/mob_spawn/ghost_role/human/syndicate/battlecruiser/ghost_role = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/ghost_wearer = allocate(__IMPLIED_TYPE__)
	ghost_role.equip(ghost_wearer)
	for(var/obj/item/item in ghost_wearer.get_all_contents())
		TEST_ASSERT(!is_ladder_combat_gun(item.type), "A ghost-role outfit still starts with [item.type].")

/// Ordinary weapon recipes remain available, including learned and stack recipes.
/datum/unit_test/voidcrew_ladder_recipe_registration/Run()
	var/list/expected_recipes = list(
		/datum/crafting_recipe/strobeshield = FALSE,
		/datum/crafting_recipe/moonflowershield = FALSE,
		/datum/crafting_recipe/chainsaw = FALSE,
		/datum/crafting_recipe/boneaxe = FALSE,
		/datum/crafting_recipe/house_edge = FALSE,
		/datum/crafting_recipe/giant_wrench = FALSE,
		/datum/crafting_recipe/singulo_hammer = FALSE,
		/datum/crafting_recipe/sm_sword = FALSE,
		/datum/crafting_recipe/boneshovel = FALSE,
		/datum/crafting_recipe/pipegun = FALSE,
		/datum/crafting_recipe/receiver = FALSE,
		/datum/crafting_recipe/pipepistol = FALSE,
		/datum/crafting_recipe/rebarxbow = FALSE,
		/datum/crafting_recipe/rebarxbowforced = FALSE,
		/datum/crafting_recipe/pipe_organ_gun = FALSE,
		/datum/crafting_recipe/laser_musket = FALSE,
		/datum/crafting_recipe/shortbow = FALSE,
		/datum/crafting_recipe/pipegun_prime = FALSE,
		/datum/crafting_recipe/laser_musket_prime = FALSE,
		/datum/crafting_recipe/deagle_prime = FALSE,
		/datum/crafting_recipe/sks = FALSE,
		/datum/crafting_recipe/hellgun = FALSE,
		/datum/crafting_recipe/advancedegun = FALSE,
		/datum/crafting_recipe/tempgun = FALSE,
		/datum/crafting_recipe/xraylaser = FALSE,
		/datum/crafting_recipe/ioncarbine = FALSE,
		/datum/crafting_recipe/teslacannon = FALSE,
		/datum/crafting_recipe/photoncannon = FALSE,
		/datum/crafting_recipe/ebow = FALSE,
		/datum/crafting_recipe/beam_rifle = FALSE,
		/datum/crafting_recipe/riflestock = FALSE,
		/datum/crafting_recipe/spear = FALSE,
		/datum/crafting_recipe/bonespear = FALSE,
		/datum/crafting_recipe/bonedagger = FALSE,
		/datum/crafting_recipe/smoothbore_disabler = FALSE,
		/datum/crafting_recipe/smoothbore_disabler_prime = FALSE,
	)
	var/list/expected_stacks = list(
		/obj/item/shield/buckler = FALSE,
		/obj/item/gun/syringe/blowgun = FALSE,
		/obj/structure/closet/crate/coffin = FALSE,
	)
	for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
		if(recipe.type in expected_recipes)
			TEST_ASSERT_EQUAL(!!recipe.non_craftable, expected_recipes[recipe.type], "[recipe.type] registered with the wrong availability")
			expected_recipes -= recipe.type
		if(istype(recipe, /datum/crafting_recipe/stack) && (recipe.result in expected_stacks))
			TEST_ASSERT_EQUAL(!!recipe.non_craftable, expected_stacks[recipe.result], "Stack result [recipe.result] registered with the wrong availability")
			expected_stacks -= recipe.result
	TEST_ASSERT_EQUAL(length(expected_recipes), 0, "Recipe registration missed [english_list(expected_recipes)]")
	TEST_ASSERT_EQUAL(length(expected_stacks), 0, "Stack recipe registration missed [english_list(expected_stacks)]")

/// Scrap guns, melee weapons and researched conversion kits use real ingredients and tools.
/datum/unit_test/voidcrew_ladder_manufacture/Run()
	for(var/recipe_type in list(/datum/crafting_recipe/pipegun, /datum/crafting_recipe/chainsaw, /datum/crafting_recipe/xraylaser))
		craft_recipe(recipe_type)
	TEST_ASSERT(!is_ladder_restricted_production(/obj/item/shovel/serrated/dull), "The green dull bone shovel became restricted.")
	for(var/design_type in list(/datum/design/plasmacutter, /datum/design/plasmacutter_adv, /datum/design/flora_gun, /datum/design/gun_shell))
		var/datum/design/design_path = design_type
		var/datum/design/design = SSresearch.techweb_designs[initial(design_path.id)]
		TEST_ASSERT_NOTNULL(design, "Missing green tool [design_type].")
		TEST_ASSERT(design.build_type, "Green tool [design_type] lost fabrication.")

/datum/unit_test/voidcrew_ladder_manufacture/proc/craft_recipe(recipe_type)
	var/atom/movable/crafter = allocate(__IMPLIED_TYPE__)
	var/datum/component/personal_crafting/crafting = crafter.AddComponent(__IMPLIED_TYPE__)
	crafting.ignored_flags = CRAFT_IGNORE_DO_AFTER
	var/datum/crafting_recipe/recipe = allocate(recipe_type)
	TEST_ASSERT(!recipe.non_craftable, "[recipe_type] is absent from the crafting menu.")
	TEST_ASSERT_EQUAL(crafting.construct_item(crafter, recipe), ", missing component.", "[recipe_type] bypassed its ingredient requirements.")
	var/list/ingredients = list()
	for(var/ingredient_type in recipe.reqs)
		var/amount = recipe.reqs[ingredient_type]
		if(ispath(ingredient_type, /obj/item/stack))
			ingredients += allocate(ingredient_type, crafter.loc, amount, FALSE)
		else
			for(var/index in 1 to amount)
				ingredients += allocate(ingredient_type)
	var/obj/item/screwdriver/screwdriver = allocate(__IMPLIED_TYPE__)
	var/obj/item/weldingtool/welder = allocate(__IMPLIED_TYPE__)
	var/atom/result = crafting.construct_item(crafter, recipe)
	TEST_ASSERT(istype(result, recipe.result), "[recipe_type] failed to craft its weapon: [result].")
	for(var/obj/item/ingredient as anything in ingredients)
		TEST_ASSERT(QDELETED(ingredient), "[recipe_type] did not consume [ingredient.type].")
	TEST_ASSERT(!QDELETED(screwdriver) && !QDELETED(welder), "[recipe_type] consumed a tool.")
	qdel(result)
	qdel(screwdriver)
	qdel(welder)

/// The original nodes and fabrication channels still grant all ordinary weapon designs.
/datum/unit_test/voidcrew_ladder_weapon_designs/Run()
	var/list/node_designs = list(
		TECHWEB_NODE_ELECTRIC_WEAPONS = list("stunrevolver", "ioncarbine", "temp_gun"),
		TECHWEB_NODE_BEAM_WEAPONS = list("nuclear_gun", "xray_laser"),
		TECHWEB_NODE_SYNDICATE_BASIC = list("largecrossbow", "rapidsyringe"),
		TECHWEB_NODE_UNREGULATED_BLUESPACE = list("beamrifle", "desynchronizer"),
		TECHWEB_NODE_LIGHT_APPS = list("photon_cannon"),
		TECHWEB_NODE_ANOMALY_SHELLS = list("gravitygun", "wormholeprojector"),
		TECHWEB_NODE_RIOT_SUPRESSION = list("tele_shield"),
	)
	for(var/node_id in node_designs)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id]
		TEST_ASSERT_NOTNULL(node, "Missing weapon research node [node_id].")
		for(var/design_id in node_designs[node_id])
			TEST_ASSERT(design_id in node.design_ids, "[node_id] lost weapon design [design_id].")
			var/datum/design/design = SSresearch.techweb_designs[design_id]
			TEST_ASSERT_NOTNULL(design, "Missing weapon design [design_id].")
			var/expected_channels = (design_id in list("wormholeprojector", "desynchronizer")) ? PROTOLATHE : (PROTOLATHE | AWAY_LATHE)
			TEST_ASSERT_EQUAL(design.build_type, expected_channels, "[design_id] lost its original fabrication channels.")
	for(var/design_id in list("cleric_mace", "liberator_gun"))
		var/datum/design/design = SSresearch.techweb_designs[design_id]
		TEST_ASSERT_NOTNULL(design, "Missing autolathe weapon design [design_id].")
		TEST_ASSERT_EQUAL(design.build_type, AUTOLATHE, "[design_id] lost autolathe fabrication.")
	var/datum/design/rapidsyringe/syringe_gun = SSresearch.techweb_designs["rapidsyringe"]
	TEST_ASSERT_EQUAL(syringe_gun.name, "Rapid Syringe Gun", "The rapid syringe design has the wrong name.")
	TEST_ASSERT_EQUAL(syringe_gun.build_path, /obj/item/gun/syringe/rapidsyringe, "Rapid syringe research must produce the rapid syringe gun.")
	var/datum/design/xray/xray_kit = SSresearch.techweb_designs["xray_laser"]
	TEST_ASSERT_EQUAL(xray_kit.build_path, /obj/item/weaponcrafting/gunkit/xray, "X-ray research must print its conversion kit.")
	var/datum/design/beamrifle/beam_kit = SSresearch.techweb_designs["beamrifle"]
	TEST_ASSERT_EQUAL(beam_kit.build_path, /obj/item/weaponcrafting/gunkit/beam_rifle, "Event Horizon research must print its kit.")
	var/obj/machinery/rnd/production/protolathe/launch_fabrication_test/lathe = allocate(__IMPLIED_TYPE__)
	var/datum/techweb/web = allocate(__IMPLIED_TYPE__)
	lathe.connect_techweb(web)
	lathe.set_machine_stat(NONE)
	lathe.materials.set_local_size(1000 * SHEET_MATERIAL_AMOUNT)
	for(var/node_id in list(TECHWEB_NODE_BEAM_WEAPONS, TECHWEB_NODE_SYNDICATE_BASIC))
		TEST_ASSERT(web.research_node_id(node_id, TRUE, FALSE, FALSE), "Could not unlock [node_id] for fabrication.")
	lathe.update_designs()
	for(var/datum/design/design as anything in list(xray_kit, syringe_gun))
		TEST_ASSERT(design in lathe.cached_designs, "The researched [design.id] is absent from the protolathe.")
		var/list/stock_before = list()
		for(var/material in design.materials)
			lathe.materials.mat_container.insert_amount_mat(10000, material)
			stock_before[material] = lathe.materials.mat_container.materials[material]
		lathe.print_test_design(design, 1)
		var/obj/item/product = locate(design.build_path) in run_loc_floor_bottom_left
		TEST_ASSERT_NOTNULL(product, "The protolathe failed to print [design.id].")
		TEST_ASSERT_EQUAL(product.type, design.build_path, "The protolathe printed the wrong [design.id] output.")
		for(var/material in stock_before)
			TEST_ASSERT(lathe.materials.mat_container.materials[material] < stock_before[material], "Printing [design.id] did not consume [material].")
		qdel(product)

/// Parts and convertible guns retain their original slapcraft recipe lists.
/datum/unit_test/voidcrew_ladder_slapcraft/Run()
	var/list/expected_recipes = list(
		/obj/item/weaponcrafting/receiver = list(/datum/crafting_recipe/pipegun),
		/obj/item/weaponcrafting/stock = list(/datum/crafting_recipe/smoothbore_disabler, /datum/crafting_recipe/laser_musket),
		/obj/item/weaponcrafting/giant_wrench = list(/datum/crafting_recipe/giant_wrench),
		/obj/item/gun/energy/laser = list(/datum/crafting_recipe/xraylaser, /datum/crafting_recipe/hellgun, /datum/crafting_recipe/ioncarbine),
		/obj/item/gun/energy/e_gun = list(/datum/crafting_recipe/advancedegun, /datum/crafting_recipe/tempgun, /datum/crafting_recipe/beam_rifle),
		/obj/item/gun/energy/recharge/kinetic_accelerator = list(/datum/crafting_recipe/ebow),
	)
	for(var/item_type in expected_recipes)
		var/obj/item/item = allocate(item_type)
		var/list/actual_recipes = list()
		var/listeners = item._listen_lookup?[COMSIG_ATOM_ATTACKBY]
		if(!islist(listeners))
			listeners = list(listeners)
		for(var/datum/element/slapcrafting/element in listeners)
			actual_recipes |= element.slapcraft_recipes
		var/list/expected = expected_recipes[item_type]
		TEST_ASSERT_EQUAL(length(actual_recipes), length(expected), "[item_type] has the wrong slapcraft recipes.")
		TEST_ASSERT_EQUAL(length(expected - actual_recipes), 0, "[item_type] lost an original slapcraft recipe.")

/// Fixed spawners cannot smuggle weapons through nested contraband or maintenance rolls.
/datum/unit_test/voidcrew_ladder_fixed_sources/Run()
	var/turf/destination = run_loc_floor_bottom_left
	for(var/source_type in list(/obj/effect/spawner/random/armory/laser_gun, /obj/effect/spawner/random/contraband/armory, /obj/effect/spawner/random/exotic/antag_gear, /obj/effect/spawner/random/maintenance))
		var/obj/effect/spawner/random/source = allocate(source_type)
		for(var/item_type in list(/obj/item/gun/energy/laser, /obj/item/knife/combat, /obj/item/katana, /obj/item/weaponcrafting/receiver, /obj/item/spear/grey_tide, /obj/item/shovel/serrated))
			var/obj/item/result = source.make_item(destination, item_type)
			TEST_ASSERT(!is_ladder_restricted_production(result.type), "[source_type] spawned [result.type].")
			if(item_type == /obj/item/spear/grey_tide || item_type == /obj/item/shovel/serrated)
				TEST_ASSERT_EQUAL(result.type, /obj/item/knife/combat/survival, "[source_type] did not replace yellow melee [item_type] with a survival knife.")
			qdel(result)
		var/obj/item/shovel/serrated/dull/green_shovel = source.make_item(destination, /obj/item/shovel/serrated/dull)
		TEST_ASSERT(istype(green_shovel), "[source_type] removed the green dull bone shovel.")
		qdel(green_shovel)
		var/obj/item/gun/energy/disabler/control = source.make_item(destination, /obj/item/gun/energy/disabler)
		TEST_ASSERT(istype(control), "[source_type] removed a disabler.")
		qdel(control)
	for(var/vendor_type in typesof(/obj/machinery/vending/security/marine))
		var/obj/machinery/vending/security/marine/vendor = allocate(vendor_type)
		for(var/item_type in vendor.products + vendor.contraband + vendor.premium)
			TEST_ASSERT(!is_ladder_restricted_production(item_type), "[vendor_type] starts or refills with [item_type].")
		for(var/choice in vendor.voucher_items)
			TEST_ASSERT(!is_ladder_combat_gun(vendor.voucher_items[choice]), "[vendor_type] vouchers produce a combat gun.")
	for(var/datum/market_item/entry_type as anything in subtypesof(/datum/market_item))
		if(is_ladder_restricted_production(initial(entry_type.item)))
			TEST_ASSERT_EQUAL(initial(entry_type.availability_prob), 0, "[entry_type] can still enter or restock on the cargo market.")
	var/previous_holy_weapon = GLOB.holy_weapon_type
	GLOB.holy_weapon_type = null
	var/obj/item/nullrod/rod = allocate(__IMPLIED_TYPE__)
	GLOB.holy_weapon_type = previous_holy_weapon
	var/datum/component/subtype_picker/picker = rod.GetComponent(/datum/component/subtype_picker)
	TEST_ASSERT_NOTNULL(picker, "The green nullrod picker disappeared.")
	for(var/choice in picker.subtype2descriptions)
		TEST_ASSERT(!ispath(choice, /obj/item/nullrod/claymore) && !ispath(choice, /obj/item/nullrod/vibro) && choice != /obj/item/nullrod/hypertool && !ispath(choice, /obj/item/gun), "The free picker offers [choice].")

/// Fresh refills cannot restore a combat gun when a games vendor is built or restocked.
/datum/unit_test/voidcrew_ladder_games_vendor/Run()
	var/obj/item/circuitboard/machine/vendor/board = allocate(__IMPLIED_TYPE__)
	board.set_type(/obj/machinery/vending/games)
	var/obj/item/vending_refill/games/installed_refill = allocate(__IMPLIED_TYPE__)
	board.replacement_parts = list(installed_refill)
	var/obj/machinery/vending/games/vendor = allocate(board.build_path, run_loc_floor_bottom_left, board)
	TEST_ASSERT(installed_refill in vendor.component_parts, "The games vendor was not built with the supplied refill.")
	for(var/item_type in vendor.products + vendor.contraband + vendor.premium)
		TEST_ASSERT(!is_ladder_combat_gun(item_type), "A newly built games vendor offers [item_type].")
	for(var/restock_pass in 1 to 2)
		if(restock_pass == 2)
			for(var/datum/data/vending_product/record in vendor.hidden_records)
				record.amount = 0
			var/obj/item/vending_refill/games/fresh_refill = allocate(__IMPLIED_TYPE__)
			TEST_ASSERT(vendor.restock(fresh_refill) > 0, "The games vendor did not accept a fresh refill.")
		var/found_bat = FALSE
		for(var/datum/data/vending_product/record in vendor.product_records + vendor.hidden_records + vendor.coin_records)
			TEST_ASSERT(!is_ladder_combat_gun(record.product_path), "A built or restocked games vendor stocks [record.product_path].")
			if(record.product_path == /obj/item/melee/baseball_bat)
				found_bat = TRUE
				TEST_ASSERT_EQUAL(record.amount, 1, "The games vendor lost its replacement bat.")
		TEST_ASSERT(found_bat, "The games vendor's contraband inventory was not populated.")

/// Loan packs bypass ordering, so inspect the actual generated crate as well.
/datum/unit_test/voidcrew_ladder_loans/Run()
	var/datum/voidcrew_shuttle_loan/loan = allocate(__IMPLIED_TYPE__)
	var/datum/supply_pack/imports/specialops/pack = allocate(__IMPLIED_TYPE__)
	for(var/repeat in 1 to 2)
		var/obj/structure/closet/crate/delivery = loan.spawn_supply_pack(pack, run_loc_floor_bottom_left)
		for(var/obj/item/item in delivery.get_all_contents())
			TEST_ASSERT(!is_ladder_restricted_production(item.type), "A loan delivered [item.type].")
		TEST_ASSERT(locate(/obj/item/clothing/under/chameleon) in delivery, "Cleaning the loan removed unrelated supplies.")
		qdel(delivery)

/// Fixed shelf prices stay above maximum salvage even after demand recovers.
/datum/unit_test/voidcrew_ladder_export_loop/Run()
	var/list/purchase_prices = list(
		/datum/export/weapon/laser = 1500,
		/datum/export/weapon/energy_gun = 2400,
		/datum/export/weapon/wt550 = 4200,
	)
	for(var/export_type in purchase_prices)
		var/datum/export/export = allocate(export_type)
		var/purchase_price = purchase_prices[export_type]
		TEST_ASSERT(export.init_cost <= purchase_price * 0.25, "[export_type] exceeds one quarter of its fixed shelf price.")
		for(var/recovered_demand in list(FALSE, TRUE))
			export.cost = export.init_cost
			var/datum/export_report/report = allocate(__IMPLIED_TYPE__)
			for(var/cycle in 1 to 100)
				if(recovered_demand)
					export.cost = export.init_cost
				var/obj/item/gun/gun = allocate(export.export_types[1])
				export.sell_object(gun, report, FALSE)
				qdel(gun)
			TEST_ASSERT(report.total_value[export] < purchase_price * 100, "Repeated purchase/export of [export_type] is profitable.")
