/// Exercise the actual crafting pipeline: schematics must not supply free ammunition.
/datum/unit_test/voidcrew_blueprint_guns/Run()
	var/mob/living/carbon/human/crafter = allocate(__IMPLIED_TYPE__)
	var/datum/component/personal_crafting/unit_test/crafting = crafter.AddComponent(__IMPLIED_TYPE__)
	allocate(/obj/item/screwdriver, crafter.loc)
	allocate(/obj/item/wrench, crafter.loc)
	var/recipes_checked = 0
	for(var/datum/crafting_recipe/blueprint/gun/recipe in GLOB.crafting_recipes)
		if(!ispath(recipe.result, /obj/item/gun))
			continue
		recipes_checked++
		check_recipe(crafter, crafting, recipe)
	TEST_ASSERT(recipes_checked > 0, "No blueprint gun recipes were tested.")

/datum/unit_test/voidcrew_blueprint_guns/proc/check_recipe(mob/living/carbon/human/crafter, datum/component/personal_crafting/unit_test/crafting, datum/crafting_recipe/recipe)
	for(var/requirement in recipe.reqs)
		if(ispath(requirement, /obj/item/stack))
			allocate(requirement, crafter.loc, recipe.reqs[requirement], FALSE)
		else
			for(var/index in 1 to recipe.reqs[requirement])
				allocate(requirement, crafter.loc)
	var/obj/item/gun/gun = crafting.construct_item(crafter, recipe)
	TEST_ASSERT(istype(gun), "[recipe.type] failed to craft: [gun]")
	allocated += gun
	TEST_ASSERT(gun.pin?.type == /obj/item/firing_pin, "[recipe.type] did not install a usable standard firing pin.")
	if(istype(gun, /obj/item/gun/energy))
		var/obj/item/gun/energy/energy_gun = gun
		TEST_ASSERT(energy_gun.cell?.charge > 0, "[recipe.type] lost its rechargeable power supply.")
		qdel(gun)
		return
	var/obj/item/gun/ballistic/ballistic = gun
	TEST_ASSERT_EQUAL(ballistic.get_ammo(), 0, "[recipe.type] provided free ammunition.")
	TEST_ASSERT_NULL(ballistic.chambered, "[recipe.type] left a chambered round.")
	TEST_ASSERT_NULL(ballistic.magazine, "[recipe.type] provided a free detachable magazine.")
	// Deleting the default magazine must not eject it onto the ground instead.
	for(var/obj/item/ammo_box/magazine/leaked in crafter.loc)
		TEST_FAIL("[recipe.type] left a free magazine on the ground: [leaked.type].")
	for(var/obj/item/ammo_casing/leaked in crafter.loc)
		TEST_FAIL("[recipe.type] left a free round on the ground: [leaked.type].")

	// A separately supplied magazine must restore a working weapon, including open bolts.
	var/obj/item/ammo_box/magazine/reload = allocate(ballistic.spawn_magazine_type)
	TEST_ASSERT(crafter.put_in_hands(reload), "Could not hold the reload for [recipe.type].")
	TEST_ASSERT(ballistic.insert_magazine(crafter, reload, FALSE), "[recipe.type] rejected its normal magazine.")
	ballistic.drop_bolt()
	TEST_ASSERT(ballistic.chambered?.loaded_projectile, "[recipe.type] could not chamber separately supplied ammunition.")
	qdel(gun)

/// Preserve internal tubes and cylinder slots when a future schematic uses them.
/datum/unit_test/voidcrew_blueprint_internal_magazines/Run()
	var/datum/crafting_recipe/blueprint/gun/recipe = allocate(__IMPLIED_TYPE__)
	for(var/gun_type in list(/obj/item/gun/ballistic/shotgun, /obj/item/gun/ballistic/revolver))
		var/obj/item/gun/ballistic/gun = allocate(gun_type)
		var/obj/item/ammo_box/magazine/original_magazine = gun.magazine
		gun.on_craft_completion(list(), recipe, null)
		TEST_ASSERT_EQUAL(gun.magazine, original_magazine, "[gun_type] lost its internal magazine.")
		TEST_ASSERT_EQUAL(gun.get_ammo(), 0, "[gun_type] retained free ammunition.")
		TEST_ASSERT_NULL(gun.chambered, "[gun_type] retained a chambered round.")
		var/obj/item/ammo_casing/reload = allocate(gun.magazine.ammo_type)
		TEST_ASSERT(gun.magazine.give_round(reload), "[gun_type] could not reload its emptied internal magazine.")
		TEST_ASSERT_EQUAL(gun.get_ammo(), 1, "[gun_type] did not retain its separately supplied round.")
		qdel(gun)

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
