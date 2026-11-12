// voidcrew/modules/shiptest_guns/shotguns. Voidcrew defines are not visible here, so values are literals.

/// Every sprite the guns and the Slammer magazine draw exists, in hand, on the back and sawn off.
/datum/unit_test/voidcrew_shiptest_shotguns_icons
/datum/unit_test/voidcrew_shiptest_shotguns_icons/Run()
	var/list/guns = list(
		/obj/item/gun/ballistic/shotgun/brimstone = TRUE,
		/obj/item/gun/ballistic/shotgun/flaming_arrow = TRUE,
		/obj/item/gun/ballistic/shotgun/flaming_arrow/absolution = TRUE,
		/obj/item/gun/ballistic/shotgun/flaming_arrow/conflagration = TRUE,
		/obj/item/gun/ballistic/shotgun/slammer = FALSE,
	)
	for(var/gun_path in guns)
		var/obj/item/gun/ballistic/gun = allocate(gun_path)
		var/list/states = list(gun.base_icon_state)
		if(guns[gun_path])
			TEST_ASSERT(gun.can_be_sawn_off, "[gun_path] should saw off")
			states += "[gun.base_icon_state]_sawn"
		for(var/state in states)
			TEST_ASSERT(state in icon_states(gun.icon), "[gun_path] has no icon state [state]")
			TEST_ASSERT(state in icon_states(gun.lefthand_file), "[gun_path] has no left hand state [state]")
			TEST_ASSERT(state in icon_states(gun.righthand_file), "[gun_path] has no right hand state [state]")
			TEST_ASSERT(state in icon_states(gun.worn_icon), "[gun_path] has no worn state [state]")
	TEST_ASSERT("slammer_mag" in icon_states('voidcrew/modules/shiptest_guns/shotguns/icons/shotguns.dmi'), "The Slammer has no magazine overlay")
	var/obj/item/ammo_box/magazine/m12g_slammer/full = allocate(/obj/item/ammo_box/magazine/m12g_slammer)
	TEST_ASSERT_EQUAL(full.icon_state, "slammer_mag-full", "A full Slammer magazine draws the wrong state")
	TEST_ASSERT(full.icon_state in icon_states(full.icon), "The full Slammer magazine sprite is missing")
	var/obj/item/ammo_box/magazine/m12g_slammer/empty/empty = allocate(/obj/item/ammo_box/magazine/m12g_slammer/empty)
	TEST_ASSERT_EQUAL(empty.ammo_count(), 0, "The empty Slammer magazine is not empty")
	TEST_ASSERT_EQUAL(empty.icon_state, "slammer_mag-empty", "An empty Slammer magazine draws the wrong state")
	TEST_ASSERT(empty.icon_state in icon_states(empty.icon), "The empty Slammer magazine sprite is missing")

/// Each gun kicks like what it is, holds the right rounds and keeps lever wording off the pumps.
/datum/unit_test/voidcrew_shiptest_shotguns_setup
/datum/unit_test/voidcrew_shiptest_shotguns_setup/Run()
	// path = list(feel class, chambered round type, rounds in the tube or magazine, action wording)
	var/list/expected = list(
		/obj/item/gun/ballistic/shotgun/brimstone = list("shotgun", /obj/item/ammo_casing/shotgun/buckshot, 4, "pump"),
		/obj/item/gun/ballistic/shotgun/slammer = list("shotgun", /obj/item/ammo_casing/shotgun/buckshot, 5, "pump"),
		/obj/item/gun/ballistic/shotgun/flaming_arrow = list("rifle", /obj/item/ammo_casing/c38, 17, "lever"),
		/obj/item/gun/ballistic/shotgun/flaming_arrow/absolution = list("rifle", /obj/item/ammo_casing/c357, 7, "lever"),
		/obj/item/gun/ballistic/shotgun/flaming_arrow/conflagration = list("shotgun", /obj/item/ammo_casing/shotgun/buckshot, 5, "lever"),
	)
	for(var/gun_path in expected)
		var/list/row = expected[gun_path]
		var/obj/item/gun/ballistic/gun = allocate(gun_path)
		gun.gun_feel_resolve()
		TEST_ASSERT_EQUAL(gun.gun_feel_class, row[1], "[gun_path] has the wrong feel class")
		TEST_ASSERT_EQUAL(gun.chambered?.type, row[2], "[gun_path] chambers the wrong round")
		TEST_ASSERT_EQUAL(gun.magazine.ammo_count(), row[3], "[gun_path] holds the wrong number of rounds")
		TEST_ASSERT_EQUAL(gun.bolt_wording, row[4], "[gun_path] has the wrong action wording")
		TEST_ASSERT(!length(gun.actions_types), "[gun_path] has an action button")
	// The .38 and .357 rifles don't shove point-blank like a shotgun does.
	for(var/rifle_path in list(/obj/item/gun/ballistic/shotgun/flaming_arrow, /obj/item/gun/ballistic/shotgun/flaming_arrow/absolution))
		var/obj/item/gun/ballistic/rifle = allocate(rifle_path)
		TEST_ASSERT_EQUAL(rifle.pb_knockback, 0, "[rifle_path] shoves point-blank like a shotgun")
		TEST_ASSERT_EQUAL(rifle.cartridge_wording, "bullet", "[rifle_path] calls its rounds shells")

/// The Slammer takes its box magazine, still has to be pumped and swaps magazines in one go.
/datum/unit_test/voidcrew_shiptest_slammer
/datum/unit_test/voidcrew_shiptest_slammer/Run()
	var/obj/item/gun/ballistic/shotgun/slammer/slammer = allocate(/obj/item/gun/ballistic/shotgun/slammer)
	TEST_ASSERT(!slammer.internal_magazine, "The Slammer should take a detachable magazine")
	TEST_ASSERT(!slammer.semi_auto, "The Slammer should be pumped between shots")
	TEST_ASSERT(slammer.tac_reloads, "The Slammer should swap magazines in one go")
	TEST_ASSERT_EQUAL(slammer.magazine.type, /obj/item/ammo_box/magazine/m12g_slammer, "The Slammer spawned with the wrong magazine")
	TEST_ASSERT_EQUAL(slammer.magazine.max_ammo, 6, "The Slammer magazine is the wrong size")
	TEST_ASSERT(istype(allocate(/obj/item/ammo_box/magazine/m12g_slammer), slammer.accepted_magazine_type), "The Slammer refuses its own magazine")
	TEST_ASSERT(!slammer.can_be_sawn_off, "The Slammer should not saw off")

/// Slamfire: with the trigger held, the Brimstone waits on the pump instead of letting go, and fires once racked.
/datum/unit_test/voidcrew_shiptest_brimstone_slamfire
/datum/unit_test/voidcrew_shiptest_brimstone_slamfire/Run()
	var/mob/living/carbon/human/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/shotgun/brimstone/brimstone = allocate(/obj/item/gun/ballistic/shotgun/brimstone)
	TEST_ASSERT_NOTNULL(brimstone.GetComponent(/datum/component/automatic_fire), "The Brimstone has no held-trigger fire")
	shooter.put_in_active_hand(brimstone)
	var/turf/target = locate(shooter.x + 3, shooter.y, shooter.z)
	// Spend the chambered shell the way a shot would, but leave the tube loaded.
	var/obj/item/ammo_casing/spent = brimstone.chambered
	brimstone.chambered = null
	qdel(spent)
	TEST_ASSERT(brimstone.waiting_on_pump(), "An empty chamber with shells in the tube should wait on the pump")
	TEST_ASSERT(brimstone.on_autofire_start(shooter), "Holding the trigger on a spent chamber should start waiting")
	TEST_ASSERT_EQUAL(brimstone.do_autofire(null, target, shooter, FALSE, null), COMPONENT_AUTOFIRE_SHOT_SUCCESS, "The held trigger let go while waiting on the pump")
	brimstone.rack(shooter)
	TEST_ASSERT(brimstone.can_shoot(), "Pumping did not chamber a live shell")
	TEST_ASSERT(!brimstone.waiting_on_pump(), "A live shell should fire, not wait")
	// Nothing left anywhere: it lets go of the trigger like any empty automatic.
	brimstone.magazine.stored_ammo.Cut()
	spent = brimstone.chambered
	brimstone.chambered = null
	qdel(spent)
	TEST_ASSERT(!brimstone.waiting_on_pump(), "An empty gun should not wait on the pump")
	TEST_ASSERT_EQUAL(brimstone.do_autofire(null, target, shooter, FALSE, null), NONE, "An empty Brimstone kept the trigger held")

/// Every gun has a way into a crew's hands and a spare reload in caches; the Slammer magazine is sold.
/datum/unit_test/voidcrew_shiptest_shotguns_routes
/datum/unit_test/voidcrew_shiptest_shotguns_routes/Run()
	// gun = list(black market SKU, loot pool, loot class)
	var/list/routes = list(
		/obj/item/gun/ballistic/shotgun/brimstone = list(/datum/shop_sku/black_market/brimstone, "plunder", "1"),
		/obj/item/gun/ballistic/shotgun/flaming_arrow = list(/datum/shop_sku/black_market/flaming_arrow, "plunder", "1"),
		/obj/item/gun/ballistic/shotgun/flaming_arrow/absolution = list(/datum/shop_sku/black_market/absolution, "plunder", "2"),
		/obj/item/gun/ballistic/shotgun/flaming_arrow/conflagration = list(/datum/shop_sku/black_market/conflagration, "plunder", "2"),
		/obj/item/gun/ballistic/shotgun/slammer = list(/datum/shop_sku/black_market/slammer, "syndicate", "2"),
	)
	var/datum/outpost_shop/black_market = allocate(/datum/outpost_shop/black_market)
	for(var/gun_path in routes)
		var/list/row = routes[gun_path]
		TEST_ASSERT(row[1] in black_market.sku_types, "[gun_path] is not on the black market shelf")
		var/datum/shop_sku/sku = allocate(row[1])
		TEST_ASSERT_EQUAL(sku.item_path, gun_path, "[row[1]] sells the wrong gun")
		var/list/pool = GLOB.loot_gun_pools[row[2]][row[3]]
		TEST_ASSERT(gun_path in pool, "[gun_path] is missing from the [row[2]] loot class [row[3]]")
		TEST_ASSERT_NOTNULL(GLOB.loot_gun_spare_ammo[gun_path], "[gun_path] has no spare reload in caches")
	TEST_ASSERT_EQUAL(GLOB.loot_gun_spare_ammo[/obj/item/gun/ballistic/shotgun/slammer], /obj/item/ammo_box/magazine/m12g_slammer, "A cached Slammer should come with a spare magazine")
	var/datum/outpost_shop/outfitter = allocate(/datum/outpost_shop/outfitter)
	TEST_ASSERT(/datum/shop_sku/outfitter/slammer_mag in outfitter.sku_types, "The outfitter does not stock Slammer magazines")
	var/datum/shop_sku/mag_sku = allocate(/datum/shop_sku/outfitter/slammer_mag)
	TEST_ASSERT_EQUAL(mag_sku.item_path, /obj/item/ammo_box/magazine/m12g_slammer, "The Slammer magazine shelf sells the wrong thing")
