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
	for(var/mob/living/rider as anything in riders)
		if(!QDELETED(rider) && get_turf(rider) != riders[rider])
			tutorial_credit(rider, TUTORIAL_STEP_TRADE_ELEVATOR)

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
