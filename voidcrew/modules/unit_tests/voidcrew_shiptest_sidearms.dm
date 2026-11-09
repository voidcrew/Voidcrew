// voidcrew/modules/shiptest_guns/sidearms. Voidcrew defines are not visible here, so values are literals.

/// Every icon state these guns and magazines draw exists: a missing overlay or magazine state is invisible, and nothing reports it.
/datum/unit_test/voidcrew_shiptest_sidearms_icons
/datum/unit_test/voidcrew_shiptest_sidearms_icons/Run()
	var/list/gun_states = list(
		/obj/item/gun/ballistic/automatic/pistol/rattlesnake = list("rattlesnake", "rattlesnake_mag", "rattlesnake_bolt", "rattlesnake_bolt_locked", "rattlesnake_suppressor"),
		/obj/item/gun/ballistic/automatic/resolution = list("resolution", "resolution_nomag", "resolution_stock_folded", "resolution_stock_extended", "resolution_suppressor", "resolution_nomag_suppressor"),
	)
	for(var/gun_path in gun_states)
		var/obj/item/gun/ballistic/gun = allocate(gun_path)
		var/list/known = icon_states(gun.icon)
		for(var/state in gun_states[gun_path])
			TEST_ASSERT(state in known, "[gun_path] has no icon state [state] in [gun.icon]")
		TEST_ASSERT(gun.inhand_icon_state in icon_states(gun.lefthand_file), "[gun_path] has no left hand sprite")
		TEST_ASSERT(gun.inhand_icon_state in icon_states(gun.righthand_file), "[gun_path] has no right hand sprite")

	var/obj/item/ammo_box/magazine/m9mm_rattlesnake/snake_mag = allocate(/obj/item/ammo_box/magazine/m9mm_rattlesnake)
	var/list/mag_states = icon_states(snake_mag.icon)
	TEST_ASSERT_EQUAL(snake_mag.ammo_count(), 18, "The MP-84 magazine does not start full")
	TEST_ASSERT_EQUAL(snake_mag.icon_state, "rattlesnake_mag_18", "A full MP-84 magazine draws the wrong state")
	for(var/rounds in 0 to 18)
		var/state = "rattlesnake_mag_[rounds == 1 ? 1 : round(rounds, 3)]"
		TEST_ASSERT(state in mag_states, "An MP-84 magazine with [rounds] rounds would draw the missing state [state]")
	var/obj/item/ammo_box/magazine/m9mm_rattlesnake/snake_spent = allocate(/obj/item/ammo_box/magazine/m9mm_rattlesnake/empty)
	TEST_ASSERT_EQUAL(snake_spent.icon_state, "rattlesnake_mag_0", "An empty MP-84 magazine draws the wrong state")

	var/obj/item/ammo_box/magazine/resolution/pd_mag = allocate(/obj/item/ammo_box/magazine/resolution)
	TEST_ASSERT("resolution_mag" in mag_states, "The PD46 magazine has no base state")
	TEST_ASSERT_EQUAL(pd_mag.ammo_count(), 30, "The PD46 magazine does not start full")
	TEST_ASSERT_EQUAL(pd_mag.icon_state, "resolution_mag-full", "A full PD46 magazine draws the wrong state")
	var/obj/item/ammo_box/magazine/resolution/pd_spent = allocate(/obj/item/ammo_box/magazine/resolution/empty)
	TEST_ASSERT_EQUAL(pd_spent.icon_state, "resolution_mag-empty", "An empty PD46 magazine draws the wrong state")

/// The MP-84 is a pistol for feel, fires 9mm from its own magazine, and right-click walks the selector through its three modes.
/datum/unit_test/voidcrew_shiptest_sidearms_rattlesnake
/datum/unit_test/voidcrew_shiptest_sidearms_rattlesnake/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/automatic/pistol/rattlesnake/snake = allocate(/obj/item/gun/ballistic/automatic/pistol/rattlesnake)
	snake.gun_feel_resolve()
	TEST_ASSERT_EQUAL(snake.gun_feel_class, "pistol", "The MP-84 should kick like a pistol")
	TEST_ASSERT_EQUAL(snake.magazine.type, /obj/item/ammo_box/magazine/m9mm_rattlesnake, "The MP-84 spawned with the wrong magazine")
	TEST_ASSERT_EQUAL(snake.chambered?.type, /obj/item/ammo_casing/c9mm, "The MP-84 fires the wrong round")
	TEST_ASSERT(!length(snake.actions_types), "The MP-84 should have no action button")
	TEST_ASSERT_EQUAL("[snake.fire_sound]", "voidcrew/modules/shiptest_guns/sidearms/sound/rattlesnake.ogg", "Gun feel swapped the MP-84's own shot")
	var/datum/component/automatic_fire/autofire = snake.GetComponent(/datum/component/automatic_fire)
	TEST_ASSERT_NOTNULL(autofire, "The MP-84 has no full auto")
	TEST_ASSERT_EQUAL(autofire.autofire_shot_delay, 0.1 SECONDS, "The MP-84 fires at the wrong rate")
	TEST_ASSERT(snake.can_suppress, "The MP-84 should take a suppressor")
	var/obj/item/ammo_box/magazine/m9mm_aps/stechkin_mag = allocate(/obj/item/ammo_box/magazine/m9mm_aps)
	TEST_ASSERT(!is_type_in_typecache(stechkin_mag, typecacheof(snake.accepted_magazine_type)), "The MP-84 takes Stechkin magazines")

	TEST_ASSERT(shooter.put_in_hands(snake), "The shooter could not hold the MP-84")
	TEST_ASSERT_EQUAL(snake.fire_select, 1, "The MP-84 should start on single shots")
	TEST_ASSERT_EQUAL(snake.burst_size, 1, "Single shots fire more than one round")
	TEST_ASSERT_EQUAL(snake.autofire_bypass_check(null, null), COMPONENT_AUTOFIRE_ONMOUSEDOWN_BYPASS, "Single shots let full auto take the mouse")
	snake.attack_self_secondary(shooter)
	TEST_ASSERT_EQUAL(snake.fire_select, 2, "Right-click did not move the MP-84 to burst")
	TEST_ASSERT_EQUAL(snake.burst_size, 3, "Burst does not fire three rounds")
	TEST_ASSERT_EQUAL(snake.autofire_bypass_check(null, null), COMPONENT_AUTOFIRE_ONMOUSEDOWN_BYPASS, "Burst let full auto take the mouse")
	snake.attack_self_secondary(shooter)
	TEST_ASSERT_EQUAL(snake.fire_select, 3, "Right-click did not move the MP-84 to full auto")
	TEST_ASSERT_EQUAL(snake.burst_size, 1, "Full auto fires bursts")
	snake.attack_self_secondary(shooter)
	TEST_ASSERT_EQUAL(snake.fire_select, 1, "Right-click did not move the MP-84 back to single shots")

	// Burst mode fires three rounds from one pull.
	snake.set_fire_select(2)
	var/start = snake.get_ammo(TRUE)
	snake.fire_cd = FALSE
	snake.fire_gun(run_loc_floor_top_right, shooter, FALSE, null)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(snake.get_ammo(TRUE), start - 3, "A burst did not fire three rounds")

/// The PD46 is an SMG for feel, takes its own 30-round magazine, and right-click folds and unfolds its stock.
/datum/unit_test/voidcrew_shiptest_sidearms_resolution
/datum/unit_test/voidcrew_shiptest_sidearms_resolution/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/automatic/resolution/pdw = allocate(/obj/item/gun/ballistic/automatic/resolution)
	pdw.gun_feel_resolve()
	TEST_ASSERT_EQUAL(pdw.gun_feel_class, "smg", "The PD46 should kick like an SMG, not a rifle")
	TEST_ASSERT_EQUAL(pdw.magazine.type, /obj/item/ammo_box/magazine/resolution, "The PD46 spawned with the wrong magazine")
	TEST_ASSERT_EQUAL(pdw.magazine.max_ammo, 30, "The PD46 magazine is the wrong size")
	TEST_ASSERT_EQUAL(pdw.chambered?.type, /obj/item/ammo_casing/c46x30mm, "The PD46 fires the wrong round")
	TEST_ASSERT(!length(pdw.actions_types), "The PD46 should have no action button")
	TEST_ASSERT_EQUAL("[pdw.fire_sound]", "voidcrew/modules/shiptest_guns/sidearms/sound/resolution.ogg", "Gun feel swapped the PD46's own shot")
	var/datum/component/automatic_fire/autofire = pdw.GetComponent(/datum/component/automatic_fire)
	TEST_ASSERT_NOTNULL(autofire, "The PD46 has no full auto")
	TEST_ASSERT_EQUAL(autofire.autofire_shot_delay, 0.15 SECONDS, "The PD46 fires at the wrong rate")

	TEST_ASSERT(user.put_in_hands(pdw), "The user could not hold the PD46")
	TEST_ASSERT(!pdw.stock_extended, "The PD46 should start with its stock folded")
	TEST_ASSERT_EQUAL(pdw.w_class, WEIGHT_CLASS_NORMAL, "A folded PD46 is the wrong size")
	var/folded_spread = pdw.spread
	pdw.attack_self_secondary(user)
	TEST_ASSERT(pdw.stock_extended, "Right-click did not extend the stock")
	TEST_ASSERT_EQUAL(pdw.w_class, WEIGHT_CLASS_BULKY, "An extended PD46 should be bulky")
	TEST_ASSERT(pdw.spread < folded_spread, "Extending the stock did not steady the PD46")
	TEST_ASSERT(pdw.recoil < initial(pdw.recoil), "Extending the stock did not soften the kick")
	pdw.attack_self_secondary(user)
	TEST_ASSERT(!pdw.stock_extended, "Right-click did not fold the stock")
	TEST_ASSERT_EQUAL(pdw.w_class, WEIGHT_CLASS_NORMAL, "Folding the stock did not shrink the PD46")
	TEST_ASSERT_EQUAL(pdw.spread, folded_spread, "Folding the stock did not restore its spread")

	// With a suppressor on, the stock still moves the size by one step each way.
	var/obj/item/suppressor/suppressor = allocate(/obj/item/suppressor)
	pdw.install_suppressor(suppressor)
	TEST_ASSERT_EQUAL(pdw.suppressed, suppressor, "The suppressor did not fit the PD46")
	var/suppressed_size = pdw.w_class
	pdw.attack_self_secondary(user)
	TEST_ASSERT_EQUAL(pdw.w_class, suppressed_size + 1, "Extending the stock under a suppressor gave the wrong size")
	pdw.attack_self_secondary(user)
	TEST_ASSERT_EQUAL(pdw.w_class, suppressed_size, "Folding the stock under a suppressor gave the wrong size")

	// The magazine-less sprite takes over when the magazine comes out.
	pdw.eject_magazine(user)
	TEST_ASSERT_EQUAL(pdw.icon_state, "resolution_nomag", "An empty PD46 draws the loaded sprite")

/// Both guns and both magazines can be got: shops, loot pools, spare loot magazines and the research print.
/datum/unit_test/voidcrew_shiptest_sidearms_routes
/datum/unit_test/voidcrew_shiptest_sidearms_routes/Run()
	var/list/pools = GLOB.loot_gun_pools
	TEST_ASSERT(pools["syndicate"]["3"][/obj/item/gun/ballistic/automatic/pistol/rattlesnake], "The MP-84 is not in the red syndicate gun pool")
	TEST_ASSERT(pools["armory"]["2"][/obj/item/gun/ballistic/automatic/resolution], "The PD46 is not in the yellow armory gun pool")
	TEST_ASSERT_EQUAL(GLOB.loot_gun_spare_ammo[/obj/item/gun/ballistic/automatic/pistol/rattlesnake], /obj/item/ammo_box/magazine/m9mm_rattlesnake, "A looted MP-84 carries no spare magazine")
	TEST_ASSERT_EQUAL(GLOB.loot_gun_spare_ammo[/obj/item/gun/ballistic/automatic/resolution], /obj/item/ammo_box/magazine/resolution, "A looted PD46 carries no spare magazine")

	var/datum/shop_sku/black_market/rattlesnake/snake_sku = /datum/shop_sku/black_market/rattlesnake
	TEST_ASSERT_EQUAL(initial(snake_sku.zone_permission), 2, "The MP-84 should need advanced reputation")
	var/datum/shop_sku/black_market/resolution/pdw_sku = /datum/shop_sku/black_market/resolution
	TEST_ASSERT_EQUAL(initial(pdw_sku.zone_permission), 1, "The PD46 should need yellow reputation")
	var/datum/shop_sku/outfitter/resolution_mag/mag_sku = /datum/shop_sku/outfitter/resolution_mag
	TEST_ASSERT_EQUAL(initial(mag_sku.zone_permission), 1, "PD46 magazines should need yellow reputation")
	var/datum/outpost_shop/black_market/market = allocate(/datum/outpost_shop/black_market)
	TEST_ASSERT(/datum/shop_sku/black_market/rattlesnake in market.sku_types, "The black market does not stock the MP-84")
	TEST_ASSERT(/datum/shop_sku/black_market/resolution in market.sku_types, "The black market does not stock the PD46")
	var/datum/outpost_shop/outfitter/outfitter = allocate(/datum/outpost_shop/outfitter)
	TEST_ASSERT(/datum/shop_sku/outfitter/resolution_mag in outfitter.sku_types, "The outfitter does not stock PD46 magazines")

	var/datum/design/print = SSresearch.techweb_designs["vc_mag_m9mm_rattlesnake"]
	TEST_ASSERT_NOTNULL(print, "The MP-84 magazine has no design")
	TEST_ASSERT_EQUAL(print.build_path, /obj/item/ammo_box/magazine/m9mm_rattlesnake, "The MP-84 magazine design builds the wrong thing")
	var/datum/techweb_node/node = SSresearch.techweb_nodes["automatic_ammo"]
	TEST_ASSERT("vc_mag_m9mm_rattlesnake" in node.design_ids, "Automatic Ammunition does not print MP-84 magazines")
