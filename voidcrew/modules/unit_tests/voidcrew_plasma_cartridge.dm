// Package: P2 guns and cartridges. Unit tests for voidcrew/modules/plasma_weapons/.

/// Plasma a gun and its seated or loose cartridge hold together
/proc/plasma_test_total(obj/item/gun/energy/plasma_weapon/gun, obj/item/plasma_cartridge/cartridge)
	return gun.chamber_mol() + (cartridge ? cartridge.stored : 0)

/// Spawn fills: new cartridges, shop guns and the Old Furnace come full, loot guns one shot to half full
/datum/unit_test/voidcrew_plasma_spawn_fill/Run()
	var/obj/item/plasma_cartridge/fresh = allocate(/obj/item/plasma_cartridge)
	TEST_ASSERT_EQUAL(fresh.stored, PLASMA_CARTRIDGE_CAPACITY, "A new cartridge isn't full")
	TEST_ASSERT_EQUAL(fresh.icon_state, "cartridge_3", "A new cartridge doesn't look full")
	for(var/gun_type in list(/obj/item/gun/energy/plasma_weapon/pistol, /obj/item/gun/energy/plasma_weapon/rifle, /obj/item/gun/energy/plasma_weapon/rifle/old_furnace))
		var/obj/item/gun/energy/plasma_weapon/gun = allocate(gun_type)
		TEST_ASSERT_NOTNULL(gun.cartridge, "[gun_type] spawned without a cartridge")
		TEST_ASSERT_EQUAL(gun.chamber_mol(), PLASMA_CARTRIDGE_CAPACITY, "[gun_type] did not spawn full")
		TEST_ASSERT_EQUAL(gun.cartridge.stored, 0, "[gun_type]'s seated cartridge still holds plasma")
	for(var/gun_type in list(/obj/item/gun/energy/plasma_weapon/pistol/loot, /obj/item/gun/energy/plasma_weapon/rifle/loot))
		var/obj/item/gun/energy/plasma_weapon/gun = allocate(gun_type)
		TEST_ASSERT_NOTNULL(gun.cartridge, "[gun_type] spawned without a cartridge")
		var/obj/item/ammo_casing/energy/shot = gun.ammo_type[gun.select]
		for(var/roll in 1 to 50)
			var/fill = gun.loot_fill()
			TEST_ASSERT(fill >= shot.e_cost && fill <= PLASMA_CARTRIDGE_CAPACITY / 2, "[gun_type] rolled a loot fill of [fill] mol")
			TEST_ASSERT_EQUAL(fill % shot.e_cost, 0, "[gun_type] rolled a loot fill of [fill] mol, not whole shots")
		TEST_ASSERT(gun.chamber_mol() >= shot.e_cost && gun.chamber_mol() <= PLASMA_CARTRIDGE_CAPACITY / 2, "[gun_type] spawned with [gun.chamber_mol()] mol")
		TEST_ASSERT(gun.can_shoot(), "[gun_type] spawned unable to fire")

/// Loading and unloading 100 times never changes the plasma a gun and its cartridge hold
/datum/unit_test/voidcrew_plasma_cartridge_invariant/Run()
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	gun.take_mol(17)
	var/obj/item/plasma_cartridge/cartridge = gun.cartridge
	var/total = plasma_test_total(gun, null)
	TEST_ASSERT_EQUAL(total, PLASMA_CARTRIDGE_CAPACITY - 17, "take_mol took the wrong amount")
	for(var/i in 1 to 100)
		TEST_ASSERT_EQUAL(gun.unload_cartridge(null), cartridge, "unload_cartridge didn't return the cartridge")
		TEST_ASSERT_NULL(gun.cartridge, "cartridge still seated after unloading")
		TEST_ASSERT_EQUAL(gun.chamber_mol(), 0, "chamber kept plasma after unloading")
		TEST_ASSERT_EQUAL(plasma_test_total(gun, cartridge), total, "plasma changed on unload [i]")
		TEST_ASSERT(gun.load_cartridge(cartridge, null), "load_cartridge failed on loop [i]")
		TEST_ASSERT_EQUAL(plasma_test_total(gun, null), total, "plasma changed on load [i]")
	// Loading a second cartridge pushes the first one out with its plasma
	var/obj/item/plasma_cartridge/second = allocate(/obj/item/plasma_cartridge)
	second.stored = 20
	TEST_ASSERT(gun.load_cartridge(second, null), "couldn't swap cartridges")
	TEST_ASSERT_EQUAL(gun.cartridge, second, "second cartridge not seated")
	TEST_ASSERT_EQUAL(cartridge.stored, total, "first cartridge lost plasma on the swap")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 20, "chamber didn't take the second cartridge's plasma")

/// On a swap a part-used cartridge comes back to the hand and a spent one drops at the shooter's feet
/datum/unit_test/voidcrew_plasma_cartridge_swap/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/energy/plasma_weapon/pistol/gun = allocate(/obj/item/gun/energy/plasma_weapon/pistol)
	shooter.put_in_hands(gun)
	gun.take_mol(8)
	var/obj/item/plasma_cartridge/part_used = gun.unload_cartridge(shooter, drop_if_spent = TRUE)
	TEST_ASSERT(shooter.is_holding(part_used), "a part-used cartridge didn't come back to the hand")
	TEST_ASSERT_EQUAL(part_used.stored, PLASMA_CARTRIDGE_CAPACITY - 8, "the part-used cartridge has the wrong fill")
	shooter.dropItemToGround(part_used)
	TEST_ASSERT(gun.load_cartridge(part_used, null), "couldn't reseat the part-used cartridge")
	gun.take_mol(gun.chamber_mol())
	var/obj/item/plasma_cartridge/spent = gun.unload_cartridge(shooter, drop_if_spent = TRUE)
	TEST_ASSERT(!shooter.is_holding(spent), "a spent cartridge came back to the hand on a swap")
	TEST_ASSERT_EQUAL(spent.loc, get_turf(shooter), "a spent cartridge didn't drop at the shooter's feet")
	TEST_ASSERT_EQUAL(spent.stored, 0, "a spent cartridge holds plasma")
	TEST_ASSERT_EQUAL(spent.icon_state, "cartridge_0", "a spent cartridge doesn't look spent")
	// A spent cartridge won't go back in
	TEST_ASSERT(!gun.load_cartridge(spent, null), "a spent cartridge was loaded")
	TEST_ASSERT_NULL(gun.cartridge, "a spent cartridge was seated")

/// A seated cartridge that leaves any other way still takes the chamber's plasma with it
/datum/unit_test/voidcrew_plasma_cartridge_writeback/Run()
	var/obj/item/gun/energy/plasma_weapon/pistol/gun = allocate(/obj/item/gun/energy/plasma_weapon/pistol)
	gun.take_mol(12)
	var/obj/item/plasma_cartridge/cartridge = gun.cartridge
	var/turf/elsewhere = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	cartridge.forceMove(elsewhere)
	TEST_ASSERT_NULL(gun.cartridge, "gun still thinks the cartridge is seated")
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 0, "chamber kept plasma after the cartridge left")
	TEST_ASSERT_EQUAL(cartridge.stored, PLASMA_CARTRIDGE_CAPACITY - 12, "cartridge didn't get the chamber's plasma")
	TEST_ASSERT(!gun.can_shoot(), "gun can still fire with no cartridge")

	// Destroying the gun drops the cartridge with its plasma
	TEST_ASSERT(gun.load_cartridge(cartridge, null), "couldn't reseat the cartridge")
	gun.take_mol(4)
	qdel(gun)
	TEST_ASSERT(isturf(cartridge.loc), "cartridge didn't drop when the gun was destroyed")
	TEST_ASSERT_EQUAL(cartridge.stored, PLASMA_CARTRIDGE_CAPACITY - 16, "cartridge lost plasma when the gun was destroyed")
	qdel(cartridge)

/// A cartridge's plasma only ever falls: nothing fed to a cartridge or a gun puts plasma in
/datum/unit_test/voidcrew_plasma_cartridge_only_falls/Run()
	var/mob/living/carbon/human/consistent/holder = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/plasma_cartridge/cartridge = allocate(/obj/item/plasma_cartridge)
	cartridge.stored = 10
	var/obj/item/gun/energy/plasma_weapon/pistol/gun = allocate(/obj/item/gun/energy/plasma_weapon/pistol)
	gun.take_mol(30)
	var/obj/item/plasma_cartridge/other = allocate(/obj/item/plasma_cartridge)
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	beaker.reagents.add_reagent(/datum/reagent/toxin/plasma, 50)
	var/list/feeds = list(
		allocate(/obj/item/stack/sheet/mineral/plasma, null, 5),
		allocate(/obj/item/stack/ore/plasma, null, 5),
		beaker,
		other,
	)
	for(var/obj/item/feed as anything in feeds)
		holder.put_in_hands(feed)
		cartridge.item_interaction(holder, feed)
		TEST_ASSERT_EQUAL(cartridge.stored, 10, "[feed.type] put plasma into a cartridge")
		if(feed != other)
			gun.item_interaction(holder, feed)
			TEST_ASSERT_EQUAL(gun.chamber_mol(), 30, "[feed.type] put plasma into a gun")
		holder.dropItemToGround(feed)
	TEST_ASSERT_EQUAL(other.stored, PLASMA_CARTRIDGE_CAPACITY, "a cartridge poured into another")
	TEST_ASSERT_EQUAL(beaker.reagents.total_volume, 50, "the beaker lost plasma")
	for(var/obj/item/stack/stack in feeds)
		TEST_ASSERT_EQUAL(stack.get_amount(), 5, "[stack.type] was used up on a cartridge or gun")

/// The hand press and the lathe: the right inputs, and three sheets always make one full cartridge
/datum/unit_test/voidcrew_plasma_cartridge_making/Run()
	var/datum/crafting_recipe/plasma_cartridge/by_sheet = new
	TEST_ASSERT_EQUAL(by_sheet.result, /obj/item/plasma_cartridge, "the press recipe makes the wrong thing")
	TEST_ASSERT_EQUAL(by_sheet.reqs[/obj/item/stack/sheet/mineral/plasma], 3, "the press recipe doesn't take three plasma sheets")
	TEST_ASSERT_EQUAL(by_sheet.reqs[/obj/item/stack/sheet/iron], 1, "the press recipe doesn't take one iron sheet")
	TEST_ASSERT_EQUAL(length(by_sheet.reqs), 2, "the press recipe takes something extra")
	TEST_ASSERT_EQUAL(by_sheet.time, 3 SECONDS, "pressing by hand doesn't take 3 seconds")
	TEST_ASSERT(!length(by_sheet.tool_behaviors) && !length(by_sheet.tool_paths), "pressing by hand needs a tool")
	qdel(by_sheet)
	var/datum/crafting_recipe/plasma_cartridge/ore/by_ore = new
	TEST_ASSERT_EQUAL(by_ore.reqs[/obj/item/stack/ore/plasma], 6, "the ore recipe doesn't take six plasma ore")
	TEST_ASSERT_EQUAL(by_ore.reqs[/obj/item/stack/sheet/iron], 1, "the ore recipe doesn't take one iron sheet")
	TEST_ASSERT_EQUAL(length(by_ore.reqs), 2, "the ore recipe takes something extra")
	qdel(by_ore)

	var/datum/design/design = SSresearch.techweb_design_by_id("vc_plasma_cartridge")
	TEST_ASSERT_NOTNULL(design, "no plasma cartridge design")
	// Node ids are fork defines, which compile after the tests: find the node by its design
	var/datum/techweb_node/node
	for(var/id in SSresearch.techweb_nodes)
		var/datum/techweb_node/candidate = SSresearch.techweb_nodes[id]
		if("vc_plasma_cartridge" in candidate.design_ids)
			node = candidate
			break
	TEST_ASSERT(istype(node, /datum/techweb_node/ballistic_ammunition), "the cartridge design isn't in the ballistic ammunition node")
	TEST_ASSERT(!node.zone_permission, "the cartridge's node is behind reputation")

	// A fully upgraded lathe still takes three whole sheets for a full cartridge
	var/obj/machinery/rnd/production/protolathe/launch_fabrication_test/lathe = allocate(/obj/machinery/rnd/production/protolathe/launch_fabrication_test)
	var/datum/techweb/web = allocate(/datum/techweb)
	lathe.connect_techweb(web)
	lathe.set_machine_stat(NONE)
	lathe.efficiency_coeff = 0.4
	lathe.materials.set_local_size(1000 * SHEET_MATERIAL_AMOUNT)
	web.add_design(design)
	var/datum/component/material_container/container = lathe.materials.mat_container
	var/datum/material/plasma = GET_MATERIAL_REF(/datum/material/plasma)
	var/datum/material/iron = GET_MATERIAL_REF(/datum/material/iron)
	container.insert_amount_mat(100 * SHEET_MATERIAL_AMOUNT, plasma)
	container.insert_amount_mat(100 * SHEET_MATERIAL_AMOUNT, iron)
	var/plasma_before = container.materials[plasma]
	var/iron_before = container.materials[iron]
	lathe.print_test_design(design, 1)
	TEST_ASSERT_EQUAL(plasma_before - container.materials[plasma], 3 * SHEET_MATERIAL_AMOUNT, "an upgraded lathe didn't take three sheets of plasma")
	var/obj/item/plasma_cartridge/printed = locate() in get_turf(lathe)
	TEST_ASSERT_NOTNULL(printed, "the lathe didn't print a cartridge")
	TEST_ASSERT_EQUAL(printed.stored, PLASMA_CARTRIDGE_CAPACITY, "a printed cartridge isn't full")

	// Printed or pressed, it is iron only: a recycled cartridge gives back no plasma
	TEST_ASSERT_EQUAL(length(printed.custom_materials), 1, "a printed cartridge is made of more than iron")
	TEST_ASSERT_EQUAL(printed.custom_materials[iron], PLASMA_CARTRIDGE_IRON, "a printed cartridge has the wrong iron")
	var/obj/item/plasma_cartridge/pressed = allocate(/obj/item/plasma_cartridge)
	pressed.set_custom_materials(list(/datum/material/plasma = 3 * SHEET_MATERIAL_AMOUNT, /datum/material/iron = SHEET_MATERIAL_AMOUNT))
	TEST_ASSERT_EQUAL(length(pressed.custom_materials), 1, "a crafted cartridge is made of more than iron")
	TEST_ASSERT_EQUAL(pressed.custom_materials[iron], PLASMA_CARTRIDGE_IRON, "a crafted cartridge has the wrong iron")
	var/plasma_after_print = container.materials[plasma]
	printed.stored = 0
	TEST_ASSERT(container.insert_item(printed) > 0, "a spent cartridge wasn't taken for scrap")
	TEST_ASSERT_EQUAL(container.materials[plasma], plasma_after_print, "a spent cartridge recycled into plasma")
	TEST_ASSERT(container.materials[iron] <= iron_before, "printing and recycling a cartridge made iron")

/// Nothing charges the chamber except plasma
/datum/unit_test/voidcrew_plasma_chamber_sealed/Run()
	var/obj/item/gun/energy/plasma_weapon/rifle/gun = allocate(/obj/item/gun/energy/plasma_weapon/rifle)
	gun.take_mol(40)
	var/obj/item/stock_parts/power_store/cell/plasma_chamber/chamber = gun.cell
	TEST_ASSERT(istype(chamber), "the rifle's cell isn't a plasma chamber")
	TEST_ASSERT_EQUAL(chamber.give(1000), 0, "give() reported charge")
	TEST_ASSERT_EQUAL(chamber.change(1000), 0, "change() reported charge")
	chamber.on_magic_charge(chamber, null, null)
	SEND_SIGNAL(gun, COMSIG_ITEM_RECHARGED)
	chamber.corrupt(TRUE)
	chamber.explode()
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 20, "the chamber gained or lost plasma")
	TEST_ASSERT_EQUAL(chamber.maxcharge, PLASMA_CARTRIDGE_CAPACITY, "corrupt() shrank the chamber")
	TEST_ASSERT(!chamber.rigged, "the chamber got rigged")
	TEST_ASSERT_NULL(chamber.reagents, "the chamber has a reagent holder")
	TEST_ASSERT(!QDELETED(chamber), "the chamber exploded")

	// Code that tops up every cell a mob carries must not find the chamber
	var/mob/living/carbon/human/consistent/holder = allocate(/mob/living/carbon/human/consistent)
	holder.put_in_hands(gun)
	TEST_ASSERT(!(chamber in holder.get_all_contents()), "the chamber is reachable through its holder's contents")
	TEST_ASSERT_EQUAL(gun.cell, chamber, "the gun lost its chamber")

	// No recharger
	TEST_ASSERT(!gun.can_charge, "plasma guns can be recharged")
	var/obj/machinery/recharger/recharger = allocate(/obj/machinery/recharger)
	recharger.attackby(gun, holder)
	TEST_ASSERT(gun.loc != recharger, "a recharger took a plasma gun")

	// EMP leaves the plasma alone
	gun.emp_act(EMP_HEAVY)
	chamber.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(gun.chamber_mol(), 20, "an EMP drained the chamber")

	// No turret or emitter fires plasma bolts off the power grid
	for(var/obj/item/gun/energy/plasma_weapon/gun_type as anything in subtypesof(/obj/item/gun/energy/plasma_weapon))
		TEST_ASSERT(initial(gun_type.gun_flags) & TURRET_INCOMPATIBLE, "[gun_type] can be built into a turret")

/// The world sprite shows empty once the chamber holds less than one shot
/datum/unit_test/voidcrew_plasma_empty_sprite/Run()
	var/obj/item/gun/energy/plasma_weapon/pistol/gun = allocate(/obj/item/gun/energy/plasma_weapon/pistol)
	var/obj/item/ammo_casing/energy/shot = gun.ammo_type[gun.select]
	TEST_ASSERT_EQUAL(gun.icon_state, "cinder", "a full Cinder shows the wrong state")
	gun.take_mol(gun.chamber_mol() - shot.e_cost + 1)
	TEST_ASSERT_EQUAL(gun.icon_state, "cinder_empty", "a Cinder short of one shot isn't shown empty")
	TEST_ASSERT(!gun.can_shoot(), "a Cinder short of one shot can fire")
