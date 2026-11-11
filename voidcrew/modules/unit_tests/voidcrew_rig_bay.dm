// The Rig Bay (voidcrew/modules/trade/rig_bay/). Fork defines compile after the tests, so the stand states,
// trait and signal names are written out: "clamped", "sold_on_stand", "rig_bay_clamped", "mecha_try_enter".

/datum/unit_test/voidcrew_rig_bay
	parent_type = /datum/unit_test/voidcrew_zone_shops
	abstract_type = /datum/unit_test/voidcrew_rig_bay

/datum/unit_test/voidcrew_rig_bay/proc/bay_turf(dx, dy)
	var/turf/place = locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)
	TEST_ASSERT(isfloorturf(place), "The test room has no floor at +[dx],+[dy]")
	return place

/// A stand linked to `shop`, as the outpost's link sweep would, without dealing a mech yet.
/datum/unit_test/voidcrew_rig_bay/proc/make_stand(datum/outpost_shop/vendor/suit_fitter/shop, turf/place, pool, bay_number = 1)
	var/obj/structure/rig_bay_stand/stand = allocate(/obj/structure/rig_bay_stand, place)
	stand.pool = pool
	stand.bay_number = bay_number
	stand.shop = shop
	shop.attach_stand(stand)
	return stand

/// Deals and tracks a mech, so a sold one is cleaned up with the test.
/datum/unit_test/voidcrew_rig_bay/proc/deal(obj/structure/rig_bay_stand/stand)
	var/obj/vehicle/sealed/mecha/mech = stand.deal_mech(FALSE)
	TEST_ASSERT_NOTNULL(mech, "Bay [stand.bay_number] dealt no mech")
	allocated += mech
	return mech

/// Every stand mech spawns with the kit its line lists.
/datum/unit_test/voidcrew_rig_bay/roster/Run()
	var/datum/outpost_shop/vendor/suit_fitter/shop = allocate(/datum/outpost_shop/vendor/suit_fitter)
	var/obj/structure/rig_bay_stand/stand = make_stand(shop, bay_turf(1, 1), /datum/shop_rotation/rig_bay/work)
	for(var/sku_type in subtypesof(/datum/shop_sku/rig_bay_mech))
		shop.add_sku(sku_type, "core")
		var/datum/shop_sku/rig_bay_mech/sku = shop.skus[length(shop.skus)]
		var/obj/vehicle/sealed/mecha/mech = stand.receive_mech(sku, FALSE)
		TEST_ASSERT_NOTNULL(mech, "[sku_type] put no mech on the stand")
		allocated += mech
		TEST_ASSERT_EQUAL(mech.type, sku.item_path, "[sku_type] hung the wrong mech")
		for(var/kit_type in sku.spawn_kit)
			TEST_ASSERT(locate(kit_type) in mech.flat_equipment, "[sku_type] came without its [kit_type]")
		for(var/obj/item/mecha_parts/mecha_equipment/equipment as anything in mech.flat_equipment)
			TEST_ASSERT(!istype(equipment, /obj/item/mecha_parts/mecha_equipment/weapon), "[sku_type] hangs armed with [equipment.type]")
		TEST_ASSERT(is_trader_good(mech), "[sku_type] isn't marked as trader goods")
		TEST_ASSERT(mech.cell && is_trader_good(mech.cell), "[sku_type]'s cell isn't marked as trader goods")
		stand.drop_sku()
		qdel(mech)
		TEST_ASSERT_EQUAL(stand.stand_state, "empty", "Deleting the mech didn't empty the stand")

/// A hanging mech can't be entered, opened, fitted, damaged, moved or teleported.
/datum/unit_test/voidcrew_rig_bay/clamp/Run()
	var/datum/outpost_shop/vendor/suit_fitter/shop = allocate(/datum/outpost_shop/vendor/suit_fitter)
	var/turf/place = bay_turf(1, 1)
	var/obj/structure/rig_bay_stand/stand = make_stand(shop, place, /datum/shop_rotation/rig_bay/combat, 3)
	var/obj/vehicle/sealed/mecha/mech = deal(stand)
	TEST_ASSERT_EQUAL(stand.stand_state, "clamped", "A dealt mech isn't hanging")
	TEST_ASSERT(stand.sku in shop.skus, "The stand's line isn't in the shop")
	TEST_ASSERT_EQUAL(stand.sku.stock, 1, "A hanging mech isn't in stock")
	TEST_ASSERT(findtext(stand.sku.name, ", bay 3"), "The line doesn't name its bay: [stand.sku.name]")
	TEST_ASSERT(HAS_TRAIT(mech, "rig_bay_clamped"), "A hanging mech isn't chained")
	TEST_ASSERT(mech.anchored, "A hanging mech isn't anchored")
	TEST_ASSERT(!(mech.mecha_flags & (AI_COMPATIBLE | MMI_COMPATIBLE | BEACON_CONTROLLABLE)), "A hanging mech takes remote pilots")

	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, bay_turf(1, 2))
	TEST_ASSERT(!mech.mob_try_enter(visitor), "Someone climbed into a hanging mech")
	TEST_ASSERT(!(visitor in mech.occupants), "A hanging mech took a pilot")

	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	visitor.put_in_active_hand(screwdriver)
	click_wrapper(visitor, mech)
	TEST_ASSERT(!(mech.mecha_flags & PANEL_OPEN), "A screwdriver opened a hanging mech")
	qdel(screwdriver)

	var/obj/item/mecha_parts/mecha_equipment/weapon/energy/laser/laser = allocate(/obj/item/mecha_parts/mecha_equipment/weapon/energy/laser)
	visitor.put_in_active_hand(laser)
	click_wrapper(visitor, mech)
	TEST_ASSERT(!(laser in mech.flat_equipment), "A weapon was fitted to a hanging mech")
	visitor.set_combat_mode(TRUE)
	var/integrity = mech.get_integrity()
	click_wrapper(visitor, mech)
	TEST_ASSERT_EQUAL(mech.get_integrity(), integrity, "A hanging mech took a melee hit")
	visitor.set_combat_mode(FALSE)
	qdel(laser)

	mech.take_damage(200, BRUTE, BULLET)
	TEST_ASSERT_EQUAL(mech.get_integrity(), integrity, "A hanging mech took damage")
	var/charge = mech.cell.charge
	mech.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(mech.cell.charge, charge, "An EMP drained a hanging mech")

	var/turf/next_door = bay_turf(2, 1)
	mech.Move(next_door, EAST)
	TEST_ASSERT_EQUAL(mech.loc, place, "A hanging mech moved off its stand")
	do_teleport(mech, next_door, no_effects = TRUE, channel = TELEPORT_CHANNEL_BLUESPACE, forced = TRUE)
	TEST_ASSERT_EQUAL(mech.loc, place, "A hanging mech was teleported off its stand")

/// Buying hands over that exact mech; a second buyer is refused; a vanished mech refunds.
/datum/unit_test/voidcrew_rig_bay/purchase/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/crew = record_for(ship)
	var/mob/living/carbon/human/buyer = make_member()
	ship.enlist_crewmember(buyer)
	var/datum/bank_account/account = fund(buyer, 40000)
	var/datum/outpost_shop/vendor/suit_fitter/shop = allocate(/datum/outpost_shop/vendor/suit_fitter)
	var/obj/structure/rig_bay_stand/stand = make_stand(shop, bay_turf(1, 1), /datum/shop_rotation/rig_bay/work)
	var/obj/vehicle/sealed/mecha/mech = deal(stand)
	var/datum/shop_sku/rig_bay_mech/sku = stand.sku
	var/price = sku.price_credits

	TEST_ASSERT(sku.try_purchase(buyer, null), "The buyer couldn't buy the hanging mech")
	TEST_ASSERT_EQUAL(account.account_balance, 40000 - price, "The mech cost the wrong amount")
	TEST_ASSERT_EQUAL(sku.stock, 0, "A sold mech stayed in stock")
	TEST_ASSERT_EQUAL(stand.held_mech, mech, "The sale swapped the mech")
	TEST_ASSERT(stand.stand_state == "releasing" || stand.stand_state == "sold_on_stand", "The stand didn't lower the sold mech ([stand.stand_state])")
	TEST_ASSERT(!HAS_TRAIT(mech, "rig_bay_clamped"), "A sold mech is still chained")
	TEST_ASSERT_NOTNULL(mech.GetComponent(/datum/component/rig_bay_hold), "A sold mech has no hold for its buyer")

	TEST_ASSERT(!sku.try_purchase(buyer, null), "The same mech sold twice")
	TEST_ASSERT_EQUAL(sku.get_denial_reason(buyer), "Out of stock.", "A sold mech didn't say it's out of stock")
	TEST_ASSERT_EQUAL(account.account_balance, 40000 - price, "A refused second sale took money")

	// The refund: the mech is gone between the charge and the hand-over
	set_permission(crew, 2)
	mech.forceMove(bay_turf(2, 2))
	TEST_ASSERT_EQUAL(stand.stand_state, "empty", "Driving the sold mech off didn't empty the stand")
	stand.drop_sku()
	shop.add_sku(/datum/shop_sku/rig_bay_mech/durand, "core")
	var/datum/shop_sku/rig_bay_mech/durand = shop.skus[length(shop.skus)]
	var/obj/vehicle/sealed/mecha/durand_mech = stand.receive_mech(durand, FALSE)
	allocated += durand_mech
	var/balance = account.account_balance
	TEST_ASSERT(crew.claim_purchase(durand.type, durand.crew_limit), "Couldn't claim the Durand cap")
	TEST_ASSERT(account.adjust_money(-durand.price_credits, "test charge"), "Couldn't charge for the Durand")
	TEST_ASSERT(consume_trade_vouchers(buyer, durand.price_vouchers), "Couldn't take the Durand vouchers")
	qdel(durand_mech)
	TEST_ASSERT_NULL(durand.dispense(buyer, null), "A vanished mech was handed over")
	TEST_ASSERT_EQUAL(account.account_balance, balance, "The refund missed credits")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 20, "The refund missed vouchers")
	TEST_ASSERT_EQUAL(crew.favor_unique_purchases[durand.type] || 0, 0, "The refund kept the crew cap")

/// A test hold that is told where it stands, since the test room isn't an outpost.
/datum/component/rig_bay_hold/unit_test
	var/test_on_ground = TRUE
	var/test_secured = TRUE

/datum/component/rig_bay_hold/unit_test/on_outpost_ground()
	return test_on_ground

/datum/component/rig_bay_hold/unit_test/on_secured_ground()
	return test_on_ground && test_secured

/// The hold lets the buyer's crew in and nobody else, drops protection when armed, and ends off outpost ground.
/datum/unit_test/voidcrew_rig_bay/hold/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/crew = record_for(ship)
	var/mob/living/carbon/human/buyer = make_member()
	ship.enlist_crewmember(buyer)
	var/obj/structure/overmap/ship/other_ship = make_ship()
	record_for(other_ship)
	var/mob/living/carbon/human/stranger = make_member("rigbay_stranger")
	other_ship.enlist_crewmember(stranger)

	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, bay_turf(1, 1))
	var/initial_flags = mech.resistance_flags
	mech.AddComponent(/datum/component/rig_bay_hold/unit_test, crew)
	var/datum/component/rig_bay_hold/unit_test/hold = mech.GetComponent(/datum/component/rig_bay_hold)
	TEST_ASSERT_NOTNULL(hold, "The hold didn't attach")

	TEST_ASSERT(!mech.mob_try_enter(stranger), "Another crew climbed into a sold mech")
	TEST_ASSERT(!(stranger in mech.occupants), "A sold mech took another crew's pilot")
	TEST_ASSERT(!(SEND_SIGNAL(mech, "mecha_try_enter", buyer) & 1), "The hold refused the buyer's own crew")
	TEST_ASSERT(mech.resistance_flags & INDESTRUCTIBLE, "An empty sold mech past the checkpoint isn't protected")

	var/obj/item/mecha_parts/mecha_equipment/weapon/energy/laser/laser = new(mech.loc)
	laser.attach(mech)
	TEST_ASSERT(!(mech.resistance_flags & INDESTRUCTIBLE), "An armed sold mech stayed protected")

	hold.test_on_ground = FALSE
	mech.forceMove(bay_turf(1, 2))
	TEST_ASSERT_NULL(mech.GetComponent(/datum/component/rig_bay_hold), "The hold outlived outpost ground")
	TEST_ASSERT_EQUAL(mech.resistance_flags, initial_flags, "The hold left its flags behind")
	TEST_ASSERT(!(SEND_SIGNAL(mech, "mecha_try_enter", stranger) & 1), "The lock outlived the hold")

/// Restock fills only empty stands; the combat stand waits for every second convoy.
/datum/unit_test/voidcrew_rig_bay/restock/Run()
	var/datum/outpost_shop/vendor/suit_fitter/shop = allocate(/datum/outpost_shop/vendor/suit_fitter)
	var/obj/structure/rig_bay_stand/work = make_stand(shop, bay_turf(1, 1), /datum/shop_rotation/rig_bay/work, 1)
	var/obj/structure/rig_bay_stand/parked = make_stand(shop, bay_turf(2, 1), /datum/shop_rotation/rig_bay/work, 2)
	var/obj/structure/rig_bay_stand/combat = make_stand(shop, bay_turf(3, 1), /datum/shop_rotation/rig_bay/combat, 3)
	var/mob/living/carbon/human/consistent/buyer = allocate(/mob/living/carbon/human/consistent, bay_turf(1, 3))
	var/obj/vehicle/sealed/mecha/work_mech = deal(work)
	var/obj/vehicle/sealed/mecha/parked_mech = deal(parked)
	var/obj/vehicle/sealed/mecha/combat_mech = deal(combat)

	// A hanging mech stays put through a convoy
	shop.convoy_restock()
	TEST_ASSERT_EQUAL(work.held_mech, work_mech, "A convoy replaced a mech nobody bought")

	for(var/obj/structure/rig_bay_stand/stand as anything in list(work, parked, combat))
		TEST_ASSERT(stand.release_mech(buyer), "Bay [stand.bay_number] wouldn't release its mech")
		TEST_ASSERT_EQUAL(stand.stand_state, "sold_on_stand", "Bay [stand.bay_number] didn't finish lowering")
	work_mech.forceMove(bay_turf(1, 2))
	combat_mech.forceMove(bay_turf(3, 2))
	TEST_ASSERT_EQUAL(work.stand_state, "empty", "Driving off didn't empty bay 1")
	TEST_ASSERT_EQUAL(combat.stand_state, "empty", "Driving off didn't empty bay 3")

	shop.convoy_restock()
	TEST_ASSERT_EQUAL(work.stand_state, "clamped", "The work stand didn't refill on the convoy")
	TEST_ASSERT_EQUAL(work.sku?.stock, 1, "The refilled work stand isn't in stock")
	TEST_ASSERT(work.sku in shop.skus, "The refilled line isn't in the shop")
	allocated += work.held_mech
	TEST_ASSERT_EQUAL(parked.held_mech, parked_mech, "A sold mech left on its stand was replaced")
	TEST_ASSERT_EQUAL(parked.stand_state, "sold_on_stand", "A stand with a sold mech on it took a new one")
	TEST_ASSERT_EQUAL(combat.stand_state, "empty", "The combat stand refilled on the first convoy")
	var/rig_bay_lines = 0
	for(var/datum/shop_sku/rig_bay_mech/line in shop.skus)
		rig_bay_lines++
	TEST_ASSERT_EQUAL(rig_bay_lines, 3, "The shop lists the wrong number of stand lines")

	shop.convoy_restock()
	TEST_ASSERT_EQUAL(combat.stand_state, "clamped", "The combat stand didn't refill on the second convoy")
	allocated += combat.held_mech
	TEST_ASSERT(ispath(combat.sku?.item_path, /obj/vehicle/sealed/mecha/gygax) || ispath(combat.sku?.item_path, /obj/vehicle/sealed/mecha/durand), "The combat stand dealt a work mech")

/// Ship saves never keep a stand or a mech.
/datum/unit_test/voidcrew_rig_bay/saves/Run()
	var/obj/structure/rig_bay_stand/stand = allocate(/obj/structure/rig_bay_stand, bay_turf(1, 1))
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, bay_turf(2, 1))
	TEST_ASSERT(!outpost_checkpoint_saves(stand), "Ship saves keep Rig Bay stands")
	TEST_ASSERT(!outpost_checkpoint_saves(mech), "Ship saves keep mechs")
