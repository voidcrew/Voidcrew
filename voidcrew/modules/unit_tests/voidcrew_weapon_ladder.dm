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

/// Registered recipes must agree with the ladder even before static initialization.
/datum/unit_test/voidcrew_ladder_recipe_registration/Run()
	var/list/expected_recipes = list(
		/datum/crafting_recipe/strobeshield = TRUE,
		/datum/crafting_recipe/moonflowershield = TRUE,
		/datum/crafting_recipe/chainsaw = TRUE,
		/datum/crafting_recipe/boneaxe = TRUE,
		/datum/crafting_recipe/house_edge = TRUE,
		/datum/crafting_recipe/giant_wrench = TRUE,
		/datum/crafting_recipe/singulo_hammer = TRUE,
		/datum/crafting_recipe/sm_sword = TRUE,
		/datum/crafting_recipe/boneshovel = TRUE,
		/datum/crafting_recipe/pipegun = TRUE,
		/datum/crafting_recipe/receiver = TRUE,
		/datum/crafting_recipe/spear = FALSE,
		/datum/crafting_recipe/bonespear = FALSE,
		/datum/crafting_recipe/bonedagger = FALSE,
		/datum/crafting_recipe/smoothbore_disabler = FALSE,
		/datum/crafting_recipe/smoothbore_disabler_prime = FALSE,
	)
	var/list/expected_stacks = list(
		/obj/item/shield/buckler = TRUE,
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

/// Learned recipes, stock slapcrafting and a carried upgrade kit cannot bypass scarcity.
/datum/unit_test/voidcrew_ladder_manufacture/Run()
	var/atom/movable/crafter = allocate(__IMPLIED_TYPE__)
	var/datum/component/personal_crafting/crafting = crafter.AddComponent(__IMPLIED_TYPE__)
	var/blocked = 0
	for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
		if(!recipe.ladder_restricted())
			continue
		blocked++
		TEST_ASSERT(recipe.non_craftable, "[recipe.type] remains in the crafting menu.")
		TEST_ASSERT_EQUAL(crafting.construct_item(crafter, recipe), "Unavailable.", "[recipe.type] can still execute directly.")
	TEST_ASSERT(blocked >= 20, "The recipe audit missed combat guns or melee recipes.")
	var/datum/crafting_recipe/boneshovel/bone_shovel = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(bone_shovel.ladder_restricted(), "The learned bone-shovel recipe bypasses the melee ladder.")
	TEST_ASSERT(bone_shovel.non_craftable, "The learned bone-shovel recipe remains in the crafting menu.")
	TEST_ASSERT_EQUAL(crafting.construct_item(crafter, bone_shovel), "Unavailable.", "The learned bone-shovel recipe can still execute directly.")
	TEST_ASSERT(!is_ladder_restricted_production(/obj/item/shovel/serrated/dull), "The green dull bone shovel became restricted.")
	for(var/recipe_type in list(/datum/crafting_recipe/spear, /datum/crafting_recipe/bonespear, /datum/crafting_recipe/bonedagger, /datum/crafting_recipe/smoothbore_disabler))
		var/datum/crafting_recipe/recipe = allocate(recipe_type)
		TEST_ASSERT(!recipe.non_craftable, "Green recipe [recipe_type] became unavailable.")
	for(var/design_id in SSresearch.techweb_designs)
		var/datum/design/design = SSresearch.techweb_designs[design_id]
		if(is_ladder_restricted_production(design.build_path))
			TEST_ASSERT_EQUAL(design.build_type, NONE, "[design.type] still fabricates [design.build_path].")
	var/datum/design/rapidsyringe/syringe_gun = SSresearch.techweb_designs["rapidsyringe"]
	TEST_ASSERT_EQUAL(syringe_gun.build_path, /obj/item/gun/syringe, "Syringe-tool research must produce the green tool.")
	TEST_ASSERT(syringe_gun.build_type & PROTOLATHE, "The syringe tool lost fabrication.")
	for(var/design_type in list(/datum/design/plasmacutter, /datum/design/plasmacutter_adv, /datum/design/flora_gun, /datum/design/gun_shell))
		var/datum/design/design_path = design_type
		var/datum/design/design = SSresearch.techweb_designs[initial(design_path.id)]
		TEST_ASSERT_NOTNULL(design, "Missing green tool [design_type].")
		TEST_ASSERT(design.build_type, "Green tool [design_type] lost fabrication.")

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
