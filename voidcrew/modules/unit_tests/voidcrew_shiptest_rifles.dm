// voidcrew/modules/shiptest_guns/rifles. Voidcrew defines are not visible here, so values are literals.

/// Every icon state these guns and their ammo draw exists: a missing overlay or magazine state is invisible, and nothing reports it.
/datum/unit_test/voidcrew_shiptest_rifles_icons
/datum/unit_test/voidcrew_shiptest_rifles_icons/Run()
	var/list/gun_states = list(
		/obj/item/gun/ballistic/automatic/woodsman = list("woodsman", "woodsman_mag"),
		/obj/item/gun/ballistic/automatic/skm = list("skm", "skm_mag_skm_mag", "skm_mag_skm_extended_mag", "skm_mag_skm_drum", "skm_suppressor"),
	)
	for(var/gun_path in gun_states)
		var/obj/item/gun/ballistic/gun = allocate(gun_path)
		var/list/known = icon_states(gun.icon)
		for(var/state in gun_states[gun_path])
			TEST_ASSERT(state in known, "[gun_path] has no icon state [state] in [gun.icon]")
		TEST_ASSERT(gun.inhand_icon_state in icon_states(gun.lefthand_file), "[gun_path] has no left hand sprite")
		TEST_ASSERT(gun.inhand_icon_state in icon_states(gun.righthand_file), "[gun_path] has no right hand sprite")
		TEST_ASSERT(gun.worn_icon_state in icon_states(gun.worn_icon), "[gun_path] has no back sprite")
	for(var/magazine_path in list(/obj/item/ammo_box/magazine/m23, /obj/item/ammo_box/magazine/skm, /obj/item/ammo_box/magazine/skm/extended, /obj/item/ammo_box/magazine/skm/drum))
		var/obj/item/ammo_box/magazine/magazine = allocate(magazine_path)
		var/list/known = icon_states(magazine.icon)
		var/base_state = initial(magazine.icon_state)
		TEST_ASSERT(base_state in known, "[magazine_path] has no icon state [base_state]")
		TEST_ASSERT("[base_state]-full" in known, "[magazine_path] has no full state")
		TEST_ASSERT("[base_state]-empty" in known, "[magazine_path] has no empty state")
		TEST_ASSERT_EQUAL(magazine.ammo_count(), magazine.max_ammo, "[magazine_path] does not start full")
		TEST_ASSERT_EQUAL(magazine.icon_state, "[base_state]-full", "A full [magazine_path] draws the wrong state")
		var/obj/item/ammo_box/magazine/spent = allocate(text2path("[magazine_path]/empty"))
		TEST_ASSERT_EQUAL(spent.ammo_count(), 0, "The empty [magazine_path] is not empty")
		TEST_ASSERT_EQUAL(spent.icon_state, "[base_state]-empty", "An empty [magazine_path] draws the wrong state")
	for(var/clip_path in list(/obj/item/ammo_box/a8x50r, /obj/item/ammo_box/a762x40))
		var/obj/item/ammo_box/clip = allocate(clip_path)
		var/list/known = icon_states(clip.icon)
		var/base_state = initial(clip.icon_state)
		for(var/rounds in 0 to clip.max_ammo)
			TEST_ASSERT("[base_state]-[rounds]" in known, "[clip_path] has no state for [rounds] rounds")
		TEST_ASSERT_EQUAL(clip.icon_state, "[base_state]-[clip.max_ammo]", "A full [clip_path] draws the wrong state")

/// Each rifle is the right kind of gun for feel purposes, takes its own magazines, fires its own round and keeps its built-in parts.
/datum/unit_test/voidcrew_shiptest_rifles_setup
/datum/unit_test/voidcrew_shiptest_rifles_setup/Run()
	var/obj/item/gun/ballistic/automatic/woodsman/woodsman = allocate(/obj/item/gun/ballistic/automatic/woodsman)
	woodsman.gun_feel_resolve()
	TEST_ASSERT_EQUAL(woodsman.gun_feel_class, "marksman", "The Woodsman should kick like a marksman rifle")
	TEST_ASSERT_EQUAL(woodsman.magazine.type, /obj/item/ammo_box/magazine/m23, "The Woodsman spawned with the wrong magazine")
	TEST_ASSERT_EQUAL(woodsman.magazine.max_ammo, 5, "The Woodsman magazine is the wrong size")
	TEST_ASSERT_EQUAL(woodsman.chambered?.type, /obj/item/ammo_casing/a8x50r, "The Woodsman fires the wrong round")
	TEST_ASSERT(woodsman.semi_auto, "The Woodsman should load itself")
	TEST_ASSERT_NULL(woodsman.GetComponent(/datum/component/automatic_fire), "The Woodsman is semi-automatic")
	TEST_ASSERT(!length(woodsman.actions_types), "The Woodsman should have no action buttons")
	TEST_ASSERT(!woodsman.can_suppress, "The Woodsman has no threaded barrel")
	var/datum/component/scope/scope = woodsman.GetComponent(/datum/component/scope)
	TEST_ASSERT_NOTNULL(scope, "The Woodsman lost its scope")
	TEST_ASSERT_EQUAL(scope.zoom_method, ZOOM_METHOD_RIGHT_CLICK, "The Woodsman's scope should work on right-click")
	TEST_ASSERT_NOTNULL(woodsman.GetComponent(/datum/component/bayonet_attachable), "The Woodsman should take a bayonet")
	var/obj/projectile/bullet/a8x50r/rifle_round = allocate(/obj/projectile/bullet/a8x50r)
	TEST_ASSERT(rifle_round.armour_penetration >= 30, "8x50mmR should go through a vest")

	var/obj/item/gun/ballistic/automatic/skm/skm = allocate(/obj/item/gun/ballistic/automatic/skm)
	skm.gun_feel_resolve()
	TEST_ASSERT_EQUAL(skm.gun_feel_class, "rifle", "The SKM should kick like a rifle")
	TEST_ASSERT_EQUAL(skm.magazine.type, /obj/item/ammo_box/magazine/skm, "The SKM spawned with the wrong magazine")
	TEST_ASSERT_EQUAL(skm.magazine.max_ammo, 20, "The SKM magazine is the wrong size")
	TEST_ASSERT_EQUAL(skm.chambered?.type, /obj/item/ammo_casing/a762x40, "The SKM fires the wrong round")
	TEST_ASSERT_NOTNULL(skm.GetComponent(/datum/component/automatic_fire), "The SKM should fire automatically")
	TEST_ASSERT(!length(skm.actions_types), "The SKM should have no action buttons")
	TEST_ASSERT_EQUAL("[skm.fire_sound]", "voidcrew/modules/shiptest_guns/rifles/sound/skm.ogg", "Gun feel swapped the SKM's own shot")
	TEST_ASSERT_NOTNULL(skm.GetComponent(/datum/component/bayonet_attachable), "The SKM should take a bayonet")
	for(var/magazine_path in list(/obj/item/ammo_box/magazine/skm/extended, /obj/item/ammo_box/magazine/skm/drum))
		TEST_ASSERT(ispath(magazine_path, skm.accepted_magazine_type), "The SKM does not take [magazine_path]")
	TEST_ASSERT(!ispath(/obj/item/ammo_box/magazine/m23, skm.accepted_magazine_type), "The SKM takes a Woodsman magazine")
	TEST_ASSERT(skm.can_suppress, "The SKM should take a suppressor")
	var/obj/item/suppressor/suppressor = allocate(/obj/item/suppressor)
	skm.install_suppressor(suppressor)
	TEST_ASSERT_EQUAL(skm.suppressed, suppressor, "The suppressor did not fit the SKM")

/// A stripper clip of each caliber refills its rifle's magazine, and only its own.
/datum/unit_test/voidcrew_shiptest_rifles_reload
/datum/unit_test/voidcrew_shiptest_rifles_reload/Run()
	var/mob/living/carbon/human/consistent/loader = allocate(/mob/living/carbon/human/consistent)
	var/list/pairs = list(
		/obj/item/ammo_box/magazine/m23/empty = /obj/item/ammo_box/a8x50r,
		/obj/item/ammo_box/magazine/skm/empty = /obj/item/ammo_box/a762x40,
	)
	for(var/magazine_path in pairs)
		var/obj/item/ammo_box/magazine/magazine = allocate(magazine_path)
		var/obj/item/ammo_box/clip = allocate(pairs[magazine_path])
		magazine.attackby(clip, loader, null, TRUE)
		TEST_ASSERT_EQUAL(magazine.ammo_count(), 5, "A stripper clip did not fill [magazine_path]")
		TEST_ASSERT_EQUAL(length(clip.stored_ammo), 0, "The stripper clip kept its rounds after loading [magazine_path]")
	var/obj/item/ammo_box/magazine/m23/empty/wrong = allocate(/obj/item/ammo_box/magazine/m23/empty)
	var/obj/item/ammo_box/a762x40/skm_clip = allocate(/obj/item/ammo_box/a762x40)
	wrong.attackby(skm_clip, loader, null, TRUE)
	TEST_ASSERT_EQUAL(wrong.ammo_count(), 0, "7.62x40mm went into a Woodsman magazine")

/// Both rifles and their ammo can be got: guns from the Undertow Exchange and cache loot, magazines from the outfitter,
/// the drum only with advanced standing, stripper clips from research.
/datum/unit_test/voidcrew_shiptest_rifles_routes
/datum/unit_test/voidcrew_shiptest_rifles_routes/Run()
	var/datum/outpost_shop/black_market = allocate(/datum/outpost_shop/black_market)
	var/datum/outpost_shop/outfitter = allocate(/datum/outpost_shop/outfitter)
	var/list/routes = list(
		/datum/shop_sku/black_market/woodsman = list(black_market, /obj/item/gun/ballistic/automatic/woodsman, 1),
		/datum/shop_sku/black_market/skm = list(black_market, /obj/item/gun/ballistic/automatic/skm, 1),
		/datum/shop_sku/black_market/skm_drum = list(black_market, /obj/item/ammo_box/magazine/skm/drum, 2),
		/datum/shop_sku/outfitter/woodsman_mag = list(outfitter, /obj/item/ammo_box/magazine/m23, 1),
		/datum/shop_sku/outfitter/skm_mag = list(outfitter, /obj/item/ammo_box/magazine/skm, 1),
		/datum/shop_sku/outfitter/skm_extended_mag = list(outfitter, /obj/item/ammo_box/magazine/skm/extended, 1),
	)
	for(var/datum/shop_sku/sku_type as anything in routes)
		var/list/route = routes[sku_type]
		var/datum/outpost_shop/shop = route[1]
		TEST_ASSERT(sku_type in shop.sku_types, "[shop.type] does not stock [sku_type]")
		TEST_ASSERT_EQUAL(initial(sku_type.item_path), route[2], "[sku_type] sells the wrong thing")
		TEST_ASSERT_EQUAL(initial(sku_type.zone_permission), route[3], "[sku_type] has the wrong standing gate")
	var/datum/shop_sku/drum = allocate(/datum/shop_sku/black_market/skm_drum)
	TEST_ASSERT(!drum.contract_reward, "A contract can pay out the SKM drum")

	TEST_ASSERT_EQUAL(GLOB.loot_gun_pools["armory"]["2"][/obj/item/gun/ballistic/automatic/woodsman], 10, "The Woodsman left the armory cache pool")
	TEST_ASSERT_EQUAL(GLOB.loot_gun_pools["plunder"]["2"][/obj/item/gun/ballistic/automatic/skm], 10, "The SKM left the plunder cache pool")
	TEST_ASSERT_EQUAL(GLOB.loot_gun_spare_ammo[/obj/item/gun/ballistic/automatic/woodsman], /obj/item/ammo_box/magazine/m23, "A looted Woodsman comes with no spare magazine")
	TEST_ASSERT_EQUAL(GLOB.loot_gun_spare_ammo[/obj/item/gun/ballistic/automatic/skm], /obj/item/ammo_box/magazine/skm, "A looted SKM comes with no spare magazine")

	var/datum/techweb_node/node = SSresearch.techweb_nodes["automatic_ammo"]
	TEST_ASSERT_NOTNULL(node, "Missing research node automatic_ammo")
	var/list/printed = list("vc_ammo_a8x50r_clip" = /obj/item/ammo_box/a8x50r, "vc_ammo_a762x40_clip" = /obj/item/ammo_box/a762x40)
	for(var/design_id in printed)
		TEST_ASSERT(design_id in node.design_ids, "automatic_ammo lost [design_id]")
		var/datum/design/design = SSresearch.techweb_designs[design_id]
		TEST_ASSERT_NOTNULL(design, "Missing design [design_id]")
		TEST_ASSERT_EQUAL(design.build_path, printed[design_id], "[design_id] prints the wrong thing")
		for(var/datum/outpost_shop/shop as anything in list(black_market, outfitter))
			for(var/datum/shop_sku/sku_type as anything in shop.sku_types + shop.rotating_pool + shop.rare_pool + shop.favor_sku_types)
				TEST_ASSERT(initial(sku_type.item_path) != design.build_path, "[shop.type] sells [design.build_path], which ships can print")
