// Round metrics for selling finds. Digging, analysing and harvesting record their own events
// (XENOARCH_METRIC_DUG/LOST/ANALYSED/HARVESTED) where they happen; curios sold over the counter use
// the ordinary "shop_buyback" event.

/// A large find sold at an outpost. Call before the find is deleted. `zone` is the band it was dug in.
/proc/metric_artifact_sold(obj/machinery/artifact/find, mob/living/seller, credits, vouchers, datum/outpost_shop/shop)
	if(!SSmetrics.accepting || QDELETED(find))
		return
	var/list/details = list(
		"serial" = find.serial,
		"accuracy" = round(find.label_accuracy(), 0.01),
		"labelled" = !!find.label,
		"tier" = find.main_effect ? artifact_price_tier(find) : null,
		"effect_tier" = find.main_effect?.tier,
		"spent" = !!find.main_effect?.is_spent(),
		"band" = xenoarch_band_name(find.origin_band),
		"harvests" = find.harvests_taken(),
		"damaged" = !!find.damaged,
		"crated" = !isturf(find.loc),
	)
	if(shop)
		details["buyer"] = shop.trader_name
		details["shop"] = "[shop.type]"
	record_metric(METRIC_TRADE, XENOARCH_METRIC_SOLD, zone = xenoarch_band_name(find.origin_band), subject = find.main_effect?.type || find.type, credits = credits, vouchers = vouchers, quantity = 1, details = details, actor = seller)
