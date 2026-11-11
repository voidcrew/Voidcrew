/**
 * Outpost recovery tests: spec-rehydrate.md 1 (traders become people). Owner: R1.
 *
 * Every purchase path refuses with the keeper dead and works again with a replacement at the counter; a first
 * keeper drops one item at or under 750 cr and its SKU's stock falls by one; a drop past the 1 500 cr outpost cap
 * does not happen; a replacement drops nothing; a guard's death leaves the checkpoint scanning; KILL_STAFF floors at
 * 4 stars.
 *
 * Defines are included after the tests: values are written out with a comment naming the define. Police helpers:
 * voidcrew_outpost_police_helpers.dm; wanted_outpost() and friends: voidcrew_outpost_police_wanted.dm. Tests are
 * written, not run, by the package; the lead runs them once at integration.
 */

/// The recovery's loss cap with R2's arithmetic pinned here, so the drop tests don't wait on R2
/datum/outpost_recovery/r1_drop_test

/datum/outpost_recovery/r1_drop_test/loss_room()
	return max(0, 1500 - losses) // OUTPOST_RECOVERY_LOSS_CAP

/datum/outpost_recovery/r1_drop_test/note_loss(amount)
	losses += amount

/// A keeper for `shop` at `where`, linked the way the outpost links a mapped one
/datum/unit_test/proc/r1_keeper(datum/outpost_shop/shop, turf/where, keeper_type = /mob/living/carbon/human/npc/ambient_npc/outpost/trader)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/keeper = allocate(keeper_type, where)
	shop.set_keeper(keeper)
	return keeper

/// Stands in for a loaded outpost's reservation over the test room: it answers contains_turf() and claims or frees nothing
/datum/turf_reservation/r1_room

/datum/turf_reservation/r1_room/New()
	return

/datum/turf_reservation/r1_room/Release()
	return

/// The test room as `outpost`'s site, as a loaded outpost's reservation makes its interior (a trader trades only on its site)
/datum/unit_test/proc/r1_site(obj/structure/overmap/trader_outpost/outpost)
	var/datum/turf_reservation/r1_room/room = new
	room.bottom_left_turfs = list(run_loc_floor_bottom_left)
	room.top_right_turfs = list(run_loc_floor_top_right)
	outpost.reservation = room

/// Kills `victim` of its wounds
/datum/unit_test/proc/r1_kill(mob/living/victim)
	victim.apply_damage(victim.maxHealth * 2, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)

/// Leaves one SKU of `shop` on the shelf (two of it; the rest emptied): a plain credit-priced item at or under `cap`, or null
/datum/unit_test/proc/r1_one_sku(datum/outpost_shop/shop, cap = 750)
	var/datum/shop_sku/kept
	for(var/datum/shop_sku/sku as anything in shop.skus)
		var/price = sku.get_credit_price()
		var/plain = !kept && sku.shelf != "favor" && !sku.price_vouchers && !sku.is_chart && !istype(sku, /datum/shop_sku/barter) && ispath(sku.item_path, /obj/item) && price > 0 && price <= cap // SHELF_FAVOR
		if(plain)
			kept = sku
			sku.stock = 2
		else
			sku.stock = 0
	return kept

/// The shop is open only with its keeper up at the counter; every way to buy, sell or open its windows follows it
/datum/unit_test/voidcrew_outpost_recovery_trader_open

/datum/unit_test/voidcrew_outpost_recovery_trader_open/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	r1_site(outpost)
	var/datum/outpost_shop/shop = outpost.ensure_main_shop()
	var/turf/counter = wanted_spot(2, 2)
	TEST_ASSERT(shop.is_open(), "A shop that never had a keeper is shut")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/keeper = r1_keeper(shop, counter)
	var/mob/living/carbon/human/buyer = wanted_person(wanted_spot(2, 1))
	// tg closes every window on a mob with no client; the buyer stands in for a player at the counter
	ADD_TRAIT(buyer, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, TRAIT_GENERIC)
	TEST_ASSERT_EQUAL(shop.keeper?.resolve(), keeper, "The keeper was not set")
	TEST_ASSERT_EQUAL(shop.counter_turf, counter, "The counter is not the first keeper's spot")
	TEST_ASSERT_EQUAL(keeper.home, counter, "The keeper's home is not their counter")
	TEST_ASSERT_EQUAL(keeper.outpost, outpost, "The keeper does not know their outpost")
	TEST_ASSERT_EQUAL(outpost.trader, keeper, "The main shop's keeper is not the outpost's trader")
	TEST_ASSERT(keeper.first_keeper, "The counter's first keeper is not marked first")
	TEST_ASSERT_EQUAL(keeper.real_name, shop.trader_name, "The first keeper is not the shop's named trader")
	TEST_ASSERT(!HAS_TRAIT(keeper, TRAIT_GODMODE), "A trader cannot be hurt")
	var/datum/shop_sku/sku = r1_one_sku(shop)
	TEST_ASSERT_NOTNULL(sku, "The main shop has no plain item to test with")
	TEST_ASSERT(shop.is_open(), "The shop is shut with its keeper at the counter")
	TEST_ASSERT(keeper.check_menu(buyer), "A customer at the counter can't be served")
	TEST_ASSERT(sku.can_trade(buyer, keeper), "A customer at the counter can't trade (keeper's shop [keeper.shop == shop ? "this one" : keeper.shop], buyer barred [outpost.is_user_barred(buyer)], keeper on the site [outpost.contains_site_turf(get_turf(keeper))], keeper's outpost [keeper.outpost == outpost ? "this one" : keeper.outpost])")
	TEST_ASSERT(GLOB.trader_counter_state.can_use_topic(keeper, buyer) > UI_CLOSE, "The storefront closed with the keeper at the counter")

	// Held up: shut while it lasts
	keeper.apply_status_effect(/datum/status_effect/grouped/heldup, REF(buyer))
	TEST_ASSERT(!shop.is_open(), "The shop trades while its keeper is held up")
	keeper.remove_status_effect(/datum/status_effect/grouped/heldup, REF(buyer))
	TEST_ASSERT(shop.is_open(), "The shop stayed shut after the hold-up")

	// Off the counter: shut
	keeper.forceMove(wanted_spot(2, 5))
	TEST_ASSERT(!shop.is_open(), "The shop trades with its keeper away from the counter")
	keeper.forceMove(counter)

	// Dead: every path refuses and the windows close
	r1_kill(keeper)
	TEST_ASSERT_EQUAL(keeper.stat, DEAD, "A trader did not die of their wounds")
	TEST_ASSERT(!shop.is_open(), "The shop trades with its keeper dead")
	TEST_ASSERT(!sku.can_trade(buyer, keeper), "A dead keeper's shop sold an item")
	TEST_ASSERT(!sku.can_trade(buyer, null), "A dead keeper's shop sold an item with no one at the counter")
	TEST_ASSERT(!keeper.check_menu(buyer), "A dead keeper's radial is still good")
	TEST_ASSERT_EQUAL(GLOB.trader_counter_state.can_use_topic(keeper, buyer), UI_CLOSE, "A dead keeper's storefront stayed open")
	TEST_ASSERT(!HAS_TRAIT_FROM(keeper, "no_containment", "outpost_trader_alive"), "A dead trader can't be bagged") // TRAIT_NO_CONTAINMENT, TRADER_ALIVE_TRAIT

	// A replacement walks in: shut until they reach the counter, then open, and a new face
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/replacement = r1_keeper(shop, wanted_spot(6, 6))
	TEST_ASSERT_EQUAL(shop.keeper?.resolve(), replacement, "The replacement did not take the counter")
	TEST_ASSERT_EQUAL(replacement.home, counter, "The replacement's home is not the counter")
	TEST_ASSERT(!replacement.first_keeper, "A replacement counts as the first keeper")
	TEST_ASSERT(!shop.is_open(), "The shop opened before the replacement reached the counter")
	replacement.forceMove(wanted_spot(2, 3))
	TEST_ASSERT(shop.is_open(), "The shop stayed shut with the replacement beside the counter")
	TEST_ASSERT(replacement.check_menu(buyer), "The replacement can't serve a customer")
	TEST_ASSERT(sku.can_trade(buyer, replacement), "The replacement can't trade")
	TEST_ASSERT(!keeper.check_menu(buyer), "The old keeper's body serves customers")

/// A first keeper drops one item off their own shelf, once; nothing for a replacement, a robbed till or past the cap
/datum/unit_test/voidcrew_outpost_recovery_trader_drop

/datum/unit_test/voidcrew_outpost_recovery_trader_drop/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	qdel(outpost.recovery)
	outpost.recovery = new /datum/outpost_recovery/r1_drop_test(outpost)
	var/datum/outpost_shop/shop = outpost.ensure_main_shop()
	var/datum/shop_sku/sku = r1_one_sku(shop)
	TEST_ASSERT_NOTNULL(sku, "The main shop has no plain item to test with")
	var/price = sku.get_credit_price()

	// The first keeper drops it, its stock falls by one, the cap counts it
	var/turf/counter = wanted_spot(2, 2)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/keeper = r1_keeper(shop, counter)
	r1_kill(keeper)
	var/dropped = 0
	for(var/obj/item/thing in counter)
		if(istype(thing, sku.item_path))
			dropped++
	TEST_ASSERT_EQUAL(dropped, 1, "A first keeper dropped [dropped] of their shelf item, not one")
	TEST_ASSERT_EQUAL(sku.stock, 1, "The dropped item's stock did not fall by one")
	TEST_ASSERT_EQUAL(outpost.recovery.losses, price, "The drop was not counted against the outpost's cap")
	TEST_ASSERT(price <= 750, "The drop was worth [price] cr, over the 750 cr cap") // OUTPOST_TRADER_DROP_CAP
	TEST_ASSERT(shop.drop_spent, "The counter's drop is not spent")

	// Revived and killed again: nothing
	keeper.revive(ADMIN_HEAL_ALL)
	r1_kill(keeper)
	TEST_ASSERT_EQUAL(sku.stock, 1, "A revived keeper dropped again")

	// A replacement: nothing
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/replacement = r1_keeper(shop, counter)
	r1_kill(replacement)
	TEST_ASSERT_EQUAL(sku.stock, 1, "A replacement dropped a shelf item")

	// Past the outpost cap: nothing, even for a first keeper
	var/datum/outpost_shop/stall = outpost.get_shop(/datum/outpost_shop/vendor/bait_shop)
	var/datum/shop_sku/stall_sku = r1_one_sku(stall)
	TEST_ASSERT_NOTNULL(stall_sku, "The bait shop has no plain item to test with")
	outpost.recovery.losses = 1500 // OUTPOST_RECOVERY_LOSS_CAP
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/angler = r1_keeper(stall, wanted_spot(5, 2))
	r1_kill(angler)
	TEST_ASSERT_EQUAL(stall_sku.stock, 2, "A drop went past the outpost's 1 500 cr cap")

	// A robbed till: nothing
	var/datum/outpost_shop/bar = outpost.get_shop(/datum/outpost_shop/vendor/dregs_bar)
	var/datum/shop_sku/bar_sku = r1_one_sku(bar)
	TEST_ASSERT_NOTNULL(bar_sku, "The bar has no plain item to test with")
	outpost.recovery.losses = 0
	var/mob/living/carbon/human/robber = wanted_person(wanted_spot(8, 1))
	bar.till_robbed_by = WEAKREF(robber.mind)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/barkeep = r1_keeper(bar, wanted_spot(8, 2))
	r1_kill(barkeep)
	TEST_ASSERT_EQUAL(bar_sku.stock, 2, "A robbed keeper dropped a shelf item")
	TEST_ASSERT_EQUAL(outpost.recovery.losses, 0, "A robbed keeper's death counted a loss")

/// Hitting a trader is counted with the trader as the victim; killing one right after is KILL_STAFF, 4 stars at least
/datum/unit_test/voidcrew_outpost_recovery_trader_kill

/datum/unit_test/voidcrew_outpost_recovery_trader_kill/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_shop/shop = outpost.ensure_main_shop()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/keeper = r1_keeper(shop, wanted_spot(2, 2))
	var/mob/living/carbon/human/killer = wanted_person(wanted_spot(2, 1))
	var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen, wanted_spot(2, 1))
	keeper.attacked_by(knife, killer)
	var/datum/outpost_warrant/warrant = police.warrants[killer.mind]
	TEST_ASSERT_NOTNULL(warrant, "Knifing a trader in plain sight gave no warrant")
	TEST_ASSERT(keeper.getBruteLoss() > 0, "The trader took no harm from a knife")
	TEST_ASSERT(warrant.recent_victims?[WEAKREF(keeper)], "The hit on the trader was not counted with the trader as the victim")
	r1_kill(keeper)
	police.on_wanted_death(null, keeper, FALSE)
	TEST_ASSERT(police.get_stars(killer.mind) >= 4, "Killing a trader is [police.get_stars(killer.mind)] stars, not 4 or more") // OUTPOST_CRIME_KILL_STAFF floor

/// The gate guard dies: his desk shuts, he drops nothing, and the checkpoint scans on through its wall scanner
/datum/unit_test/voidcrew_trader_checkpoint/guard_killed

/datum/unit_test/voidcrew_trader_checkpoint/guard_killed/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/datum/outpost_shop/desk = guard.shop
	TEST_ASSERT_NOTNULL(desk, "The guard has no desk")
	TEST_ASSERT(desk.is_open(), "The permit desk is shut with the guard in his booth")
	r1_kill(guard)
	TEST_ASSERT_EQUAL(guard.stat, DEAD, "The guard did not die of his wounds")
	TEST_ASSERT(!desk.is_open(), "The permit desk trades with its guard dead")
	TEST_ASSERT(!(locate(/obj/item) in get_turf(guard)), "A dead guard dropped something")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	TEST_ASSERT(scan_now(person), "The checkpoint would not scan with its guard dead")
	TEST_ASSERT_EQUAL(checkpoint.state, "passing", "A clean visitor was refused with the guard dead") // CHECKPOINT_PASSING
