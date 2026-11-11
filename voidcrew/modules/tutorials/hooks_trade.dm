// Tutorial checklist hooks. Part B: outpost elevator, shop purchase and buyback hooks.
// Every override calls the parent with its exact argument list and returns its value.
// The barter, chart and rumor SKUs replace try_purchase without calling the base, so
// each is covered on its own.

/obj/machinery/outpost_elevator/complete_ride(floor_id, datum/weakref/rider_ref)
	var/list/riders
	var/list/turf/own_alcove = get_own_alcove()
	for(var/turf/alcove_turf as anything in own_alcove)
		for(var/mob/living/rider in alcove_turf)
			if(rider.ckey)
				LAZYSET(riders, rider, alcove_turf)
	. = ..()
	// Riding a trader outpost's elevator also means the ship got there: crew who joined
	// after it berthed never saw the dock.
	var/at_trader = istype(outpost, /obj/structure/overmap/trader_outpost)
	for(var/mob/living/rider as anything in riders)
		if(!QDELETED(rider) && get_turf(rider) != riders[rider])
			tutorial_credit(rider, TUTORIAL_STEP_TRADE_ELEVATOR)
			if(at_trader)
				tutorial_credit(rider, TUTORIAL_STEP_TRADE_TRAVEL)

/// Credits a finished purchase: every buy counts for trade, chrome also for cyberware.
/proc/tutorial_credit_purchase(mob/living/user, datum/shop_sku/sku)
	if(!user || !sku)
		return
	tutorial_credit(user, TUTORIAL_STEP_TRADE_BUY)
	var/bought = sku.item_path
	if(tutorial_is_chrome_path(bought))
		tutorial_credit(user, TUTORIAL_STEP_CHROME_BUY)

/datum/shop_sku/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	if(. == TRUE)
		tutorial_credit_purchase(user, src)

/datum/shop_sku/barter/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	if(. == TRUE)
		tutorial_credit_purchase(user, src)

/datum/shop_sku/anomaly_chart/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	if(. == TRUE)
		tutorial_credit_purchase(user, src)

/datum/shop_sku/ruin_chart/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	if(. == TRUE)
		tutorial_credit_purchase(user, src)

/datum/shop_sku/rumor/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	if(. == TRUE)
		tutorial_credit_purchase(user, src)

/datum/shop_buyback/try_sell(mob/living/user, mob/living/basic/outpost_trader/vendor, quiet = FALSE)
	. = ..()
	if(. == TRUE)
		tutorial_credit(user, TUTORIAL_STEP_TRADE_SELL)

/datum/shop_buyback/try_sell_bulk(mob/living/user, mob/living/basic/outpost_trader/vendor)
	. = ..()
	if(. > 0)
		tutorial_credit(user, TUTORIAL_STEP_TRADE_SELL)

// ---------------------------------------------------------------------------
// Step pointers and live lines (contract-trade)
// ---------------------------------------------------------------------------

/// The trader outpost the viewer's crew ship is berthed at, or null.
/proc/tutorial_docked_outpost(mob/user)
	var/obj/structure/overmap/trader_outpost/outpost = get_crew_ship(user)?.docked
	return istype(outpost) && !QDELETED(outpost) ? outpost : null

/// A trader who runs a shop. Checkpoint guards are traders by type but sell nothing.
/proc/tutorial_is_shopkeeper(atom/candidate)
	if(!istype(candidate, /mob/living/basic/outpost_trader) || istype(candidate, /mob/living/basic/outpost_trader/checkpoint_guard))
		return FALSE
	var/mob/living/basic/outpost_trader/trader = candidate
	return !isnull(trader.shop)

/datum/vc_tutorial_step/trade_travel/live_line(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	var/list/here = ship?.get_relative_overmap_coords()
	if(!here)
		return null
	var/obj/structure/overmap/trader_outpost/nearest
	var/best_dist
	var/best_dx
	var/best_dy
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(QDELETED(outpost))
			continue
		var/list/there = outpost.get_relative_overmap_coords()
		if(!there)
			continue
		var/dx = there[1] - here[1]
		var/dy = there[2] - here[2]
		var/dist = max(abs(dx), abs(dy))
		if(!nearest || dist < best_dist)
			nearest = outpost
			best_dist = dist
			best_dx = dx
			best_dy = dy
	if(!nearest)
		return null
	if(!best_dist)
		return ship.is_still() ? "[nearest.name] is here." : "[nearest.name] is here. Slow down to dock."
	return "Nearest outpost: [nearest.name], [best_dist] tiles [overmap_delta_to_compass(best_dx, best_dy)]."

/// The elevator panel in this crew's berth (a fixed wall panel, off the ship).
/datum/vc_tutorial_step/trade_elevator/extra_targets(mob/user)
	var/obj/structure/overmap/trader_outpost/outpost = tutorial_docked_outpost(user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!outpost || !ship)
		return list()
	for(var/datum/outpost_berth/berth as anything in outpost.berths)
		if(berth?.ship == ship && !QDELETED(berth.panel))
			return list(berth.panel)
	return list()

/// Only this crew's berth panel or the concourse panels: other berths are crew only.
/datum/vc_tutorial_step/trade_elevator/highlight_filter(mob/user, atom/candidate)
	if(!istype(candidate, /obj/machinery/outpost_elevator))
		return TRUE
	var/obj/machinery/outpost_elevator/panel = candidate
	if(panel.is_lobby || !panel.berth)
		return FALSE
	return panel.berth.ship == get_crew_ship(user)

/datum/vc_tutorial_step/trade_buy/highlight_filter(mob/user, atom/candidate)
	return !istype(candidate, /mob/living/basic/outpost_trader) || tutorial_is_shopkeeper(candidate)

/// A whole credit amount with thousands commas: 12500 -> "12,500".
/proc/tutorial_credits_text(amount)
	var/digits = num2text(abs(round(amount)), 12)
	var/out = ""
	while(length(digits) > 3)
		out = ",[copytext(digits, -3)][out]"
		digits = copytext(digits, 1, -3)
	return "[round(amount) < 0 ? "-" : ""][digits][out]"

/datum/vc_tutorial_step/trade_buy/live_line(mob/user)
	var/datum/bank_account/account = get_crew_ship(user)?.ship_account
	if(!account)
		return null
	return "Ship account: [tutorial_credits_text(account.account_balance)] cr."

/// Only traders with a wanted list buy anything.
/datum/vc_tutorial_step/trade_sell/highlight_filter(mob/user, atom/candidate)
	if(!istype(candidate, /mob/living/basic/outpost_trader))
		return TRUE
	if(!tutorial_is_shopkeeper(candidate))
		return FALSE
	var/mob/living/basic/outpost_trader/trader = candidate
	return length(trader.shop.buybacks) > 0
