// voidcrew/modules/shiptest_guns/scorcher: the Heater, the Scorcher and 5.7x39mm.
// Voidcrew defines are not visible here, so values are literals.

/// Every icon state these guns draw exists: a missing overlay or magazine state is invisible, and nothing reports it.
/datum/unit_test/voidcrew_scorcher_icons
/datum/unit_test/voidcrew_scorcher_icons/Run()
	for(var/gun_path in list(/obj/item/gun/ballistic/automatic/heater, /obj/item/gun/ballistic/automatic/heater/scorcher))
		var/obj/item/gun/ballistic/gun = allocate(gun_path)
		var/list/known = icon_states(gun.icon)
		TEST_ASSERT(gun.icon_state in known, "[gun_path] has no icon state [gun.icon_state]")
		TEST_ASSERT("[gun.icon_state]_mag" in known, "[gun_path] has no magazine overlay")
		TEST_ASSERT(gun.inhand_icon_state in icon_states(gun.lefthand_file), "[gun_path] has no left hand sprite")
		TEST_ASSERT(gun.inhand_icon_state in icon_states(gun.righthand_file), "[gun_path] has no right hand sprite")
		TEST_ASSERT(gun.worn_icon_state in icon_states(gun.worn_icon), "[gun_path] has no worn sprite")
	var/obj/item/ammo_box/magazine/heater/magazine = allocate(/obj/item/ammo_box/magazine/heater)
	var/list/known = icon_states(magazine.icon)
	TEST_ASSERT("heater_mag-full" in known, "The Heater magazine has no full state")
	TEST_ASSERT("heater_mag-empty" in known, "The Heater magazine has no empty state")
	TEST_ASSERT_EQUAL(magazine.ammo_count(), 30, "The Heater magazine does not start full")
	TEST_ASSERT_EQUAL(magazine.icon_state, "heater_mag-full", "A full Heater magazine draws the wrong state")
	var/obj/item/ammo_box/magazine/heater/empty/spent = allocate(/obj/item/ammo_box/magazine/heater/empty)
	TEST_ASSERT_EQUAL(spent.ammo_count(), 0, "The empty Heater magazine is not empty")
	TEST_ASSERT_EQUAL(spent.icon_state, "heater_mag-empty", "An empty Heater magazine draws the wrong state")

/// Both guns are SMGs for feel purposes, fire automatically, take the 5.7 magazine and fire 5.7 rounds.
/datum/unit_test/voidcrew_scorcher_setup
/datum/unit_test/voidcrew_scorcher_setup/Run()
	for(var/gun_path in list(/obj/item/gun/ballistic/automatic/heater, /obj/item/gun/ballistic/automatic/heater/scorcher))
		var/obj/item/gun/ballistic/automatic/gun = allocate(gun_path)
		gun.gun_feel_resolve()
		TEST_ASSERT_EQUAL(gun.gun_feel_class, "smg", "[gun_path] should kick like an SMG")
		TEST_ASSERT_EQUAL(gun.magazine.type, /obj/item/ammo_box/magazine/heater, "[gun_path] spawned with the wrong magazine")
		TEST_ASSERT_EQUAL(gun.magazine.max_ammo, 30, "[gun_path] holds the wrong number of rounds")
		TEST_ASSERT_EQUAL(gun.chambered?.type, /obj/item/ammo_casing/c57x39mm, "[gun_path] fires the wrong round")
		TEST_ASSERT_NOTNULL(gun.GetComponent(/datum/component/automatic_fire), "[gun_path] should fire automatically")
		TEST_ASSERT(!length(gun.actions_types), "[gun_path] should have no action buttons")
		var/obj/item/ammo_box/magazine/heater/spare = allocate(/obj/item/ammo_box/magazine/heater)
		TEST_ASSERT(gun.magazine.caliber == spare.caliber, "A spare magazine does not fit [gun_path]")
	var/obj/item/gun/ballistic/automatic/heater/heater = allocate(/obj/item/gun/ballistic/automatic/heater)
	var/obj/item/gun/ballistic/automatic/heater/scorcher/scorcher = allocate(/obj/item/gun/ballistic/automatic/heater/scorcher)
	TEST_ASSERT(heater.w_class < scorcher.w_class, "The stocked Scorcher should be bigger than the Heater")

/// The flamethrower burns a unit of fuel a puff with no wait between puffs, and only takes welding fuel.
/datum/unit_test/voidcrew_scorcher_flamer
/datum/unit_test/voidcrew_scorcher_flamer/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/automatic/heater/scorcher/scorcher = allocate(/obj/item/gun/ballistic/automatic/heater/scorcher)
	TEST_ASSERT(shooter.put_in_hands(scorcher), "The shooter could not hold the Scorcher")
	TEST_ASSERT_EQUAL(scorcher.fuel, 40, "The Scorcher should start with a full tank")
	TEST_ASSERT(scorcher.spray_fire(run_loc_floor_top_right, shooter), "A puff did not fire")
	TEST_ASSERT_EQUAL(scorcher.fuel, 39, "A puff should burn one unit of fuel")
	TEST_ASSERT(scorcher.spray_fire(run_loc_floor_top_right, shooter), "A second puff right after the first did not fire")
	TEST_ASSERT_EQUAL(scorcher.fuel, 38, "A second puff should burn another unit")
	scorcher.fuel = 0
	TEST_ASSERT(!scorcher.spray_fire(run_loc_floor_top_right, shooter), "A dry tank still sprayed")
	TEST_ASSERT_EQUAL(scorcher.fuel, 0, "A dry tank went below empty")

	var/obj/item/reagent_containers/cup/beaker/large/beaker = allocate(/obj/item/reagent_containers/cup/beaker/large)
	beaker.reagents.add_reagent(/datum/reagent/water, 30)
	beaker.reagents.add_reagent(/datum/reagent/fuel/oil, 30)
	scorcher.draw_fuel(beaker, shooter)
	TEST_ASSERT_EQUAL(scorcher.fuel, 0, "The tank took something that isn't welding fuel")
	// A large beaker holds 100, so this fills it.
	beaker.reagents.add_reagent(/datum/reagent/fuel, 40)
	scorcher.draw_fuel(beaker, shooter)
	TEST_ASSERT_EQUAL(scorcher.fuel, 40, "The tank did not fill from a beaker of fuel")
	TEST_ASSERT_EQUAL(beaker.reagents.get_reagent_amount(/datum/reagent/fuel), 0, "The tank took more fuel than it holds")
	TEST_ASSERT_EQUAL(beaker.reagents.get_reagent_amount(/datum/reagent/water), 30, "Refuelling took water out of the beaker")

/// Holding the trigger starts a processing spray that puffs at once, and stopping, dropping or deleting the gun cleans it all up.
/datum/unit_test/voidcrew_scorcher_held_spray
/datum/unit_test/voidcrew_scorcher_held_spray/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/automatic/heater/scorcher/scorcher = allocate(/obj/item/gun/ballistic/automatic/heater/scorcher)
	TEST_ASSERT(shooter.put_in_hands(scorcher), "The shooter could not hold the Scorcher")
	TEST_ASSERT_EQUAL(scorcher.spray_holder, shooter, "Holding the Scorcher did not start watching the holder")

	scorcher.start_spraying(run_loc_floor_top_right)
	TEST_ASSERT(scorcher.spraying, "The spray did not start")
	TEST_ASSERT(scorcher.datum_flags & DF_ISPROCESSING, "The spray is not processing")
	TEST_ASSERT_EQUAL(scorcher.fuel, 39, "The spray's first puff did not go off at once")
	TEST_ASSERT(scorcher.spray_puff(), "A held puff did not fire")
	TEST_ASSERT_EQUAL(scorcher.fuel, 38, "A held puff should burn one unit of fuel")
	scorcher.stop_spraying()
	TEST_ASSERT(!scorcher.spraying, "The spray did not stop")
	TEST_ASSERT(!(scorcher.datum_flags & DF_ISPROCESSING), "The stopped spray is still processing")
	TEST_ASSERT_NULL(scorcher.spray_target, "The stopped spray kept its target")

	scorcher.fuel = 0
	scorcher.start_spraying(run_loc_floor_top_right)
	TEST_ASSERT(!scorcher.spraying, "A dry tank started spraying")
	TEST_ASSERT(!(scorcher.datum_flags & DF_ISPROCESSING), "A dry tank left the spray processing")

	scorcher.fuel = 40
	scorcher.start_spraying(run_loc_floor_top_right)
	TEST_ASSERT(scorcher.spraying, "The refuelled spray did not start")
	shooter.dropItemToGround(scorcher)
	TEST_ASSERT(!scorcher.spraying, "Dropping the Scorcher did not stop the spray")
	TEST_ASSERT(!(scorcher.datum_flags & DF_ISPROCESSING), "The dropped Scorcher is still processing")
	TEST_ASSERT_NULL(scorcher.spray_holder, "The dropped Scorcher kept its holder")

	TEST_ASSERT(shooter.put_in_hands(scorcher), "The shooter could not pick the Scorcher back up")
	scorcher.start_spraying(run_loc_floor_top_right)
	TEST_ASSERT(scorcher.spraying, "The spray did not start again")
	qdel(scorcher)
	TEST_ASSERT(!(scorcher.datum_flags & DF_ISPROCESSING), "A deleted Scorcher is still processing")
	TEST_ASSERT_NULL(scorcher.spray_holder, "A deleted Scorcher kept its holder")

/// Each gun can be bought at its tier and found in plunder, with a spare magazine, and its magazine is sold.
/datum/unit_test/voidcrew_scorcher_routes
/datum/unit_test/voidcrew_scorcher_routes/Run()
	var/datum/outpost_shop/black_market/black_market = allocate(/datum/outpost_shop/black_market)
	TEST_ASSERT(/datum/shop_sku/black_market/heater in black_market.sku_types, "The Undertow Exchange does not sell the Heater")
	TEST_ASSERT(/datum/shop_sku/black_market/scorcher in black_market.sku_types, "The Undertow Exchange does not sell the Scorcher")
	var/datum/shop_sku/heater_sku = allocate(/datum/shop_sku/black_market/heater)
	var/datum/shop_sku/scorcher_sku = allocate(/datum/shop_sku/black_market/scorcher)
	TEST_ASSERT_EQUAL(heater_sku.zone_permission, 1, "The Heater should need yellow standing")
	TEST_ASSERT_EQUAL(scorcher_sku.zone_permission, 2, "The Scorcher should need advanced standing")
	var/datum/outpost_shop/outfitter/outfitter = allocate(/datum/outpost_shop/outfitter)
	TEST_ASSERT(/datum/shop_sku/outfitter/heater_mag in outfitter.sku_types, "Quartermain does not sell Heater magazines")
	TEST_ASSERT(/obj/item/gun/ballistic/automatic/heater in GLOB.loot_gun_pools["plunder"]["2"], "The Heater is not yellow plunder")
	TEST_ASSERT(/obj/item/gun/ballistic/automatic/heater/scorcher in GLOB.loot_gun_pools["plunder"]["3"], "The Scorcher is not red plunder")
	for(var/gun_path in list(/obj/item/gun/ballistic/automatic/heater, /obj/item/gun/ballistic/automatic/heater/scorcher))
		TEST_ASSERT_EQUAL(GLOB.loot_gun_spare_ammo[gun_path], /obj/item/ammo_box/magazine/heater, "[gun_path] is found without a spare magazine")
