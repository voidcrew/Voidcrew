/**
 * # Outpost shop catalog integrity
 *
 * ~370 stocked SKUs across ten shelves, and the one thing that decides whether
 * a SKU is ever visible is a hand-typed string: `category` has to match an
 * entry in its shop's `categories` list or the storefront never renders it.
 * A SKU that misses is fully authored, priced, stocked and invisible, the
 * same failure mode voidcrew_loot.dm's reachability test was written to catch,
 * one layer up. shop_catalog_job_packs.dm's own header warns about it in prose.
 *
 * The other half is the shop's own tables: pools that must hold real SKU paths,
 * SKUs that must dispense a real movable, and buybacks/exclusive rewards that
 * must be real types.
 */

/datum/unit_test/voidcrew_shop_catalog/Run()
	var/shops_checked = 0
	var/skus_checked = 0
	for(var/shop_type in subtypesof(/datum/outpost_shop))
		var/datum/outpost_shop/shop = new shop_type(null)
		// Abstract parents carry no shelf of their own.
		if(!length(shop.categories))
			qdel(shop)
			continue
		shops_checked++
		var/list/every_sku = shop.sku_types + shop.rotating_pool + shop.rare_pool + shop.chart_pool
		for(var/datum/shop_sku/sku_type as anything in every_sku)
			if(!ispath(sku_type, /datum/shop_sku))
				TEST_FAIL("[shop_type] lists [sku_type], which is not a /datum/shop_sku")
				continue
			skus_checked++
			var/category = initial(sku_type.category)
			if(!(category in shop.categories))
				TEST_FAIL("[shop_type] stocks [sku_type] under category '[category]', which is not in that shop's categories list. The SKU is priced and stocked and the storefront never renders it. Nobody can buy it.")
			if(initial(sku_type.is_chart))
				continue // intel SKUs legitimately dispense nothing
			var/item_path = initial(sku_type.item_path)
			if(!ispath(item_path, /atom/movable))
				TEST_FAIL("[sku_type] has item_path [item_path], which is not a spawnable movable, buying it hands over nothing")
			if(initial(sku_type.price_credits) < 0 || initial(sku_type.price_vouchers) < 0)
				TEST_FAIL("[sku_type] has a negative price")
			if(initial(sku_type.stock_min) > initial(sku_type.stock_max))
				TEST_FAIL("[sku_type] has stock_min above stock_max, so its per-round stock roll is inverted")
		for(var/datum/shop_buyback/buyback_type as anything in shop.buyback_types)
			if(!ispath(buyback_type, /datum/shop_buyback))
				TEST_FAIL("[shop_type] lists [buyback_type] as a buyback, which is not a /datum/shop_buyback")
		for(var/reward in shop.exclusive_rewards)
			if(!ispath(reward, /atom/movable))
				TEST_FAIL("[shop_type] lists exclusive reward [reward], which is not a spawnable movable. The contract that pays it out gives nothing")
		for(var/list/request as anything in shop.mission_requests)
			if(!islist(request))
				TEST_FAIL("[shop_type] has a malformed mission_requests row")
				continue
			if(!ispath(request["type"], /atom/movable))
				TEST_FAIL("[shop_type] requests [request["type"]], which is not a spawnable movable")
			if((request["amount"] || 0) < 1)
				TEST_FAIL("[shop_type] requests [request["amount"]] of [request["type"]]")
			// A stack ask is settled off ONE stack (deliver/can_turn_in), so an
			// amount above that stack's max_amount is unpayable: the contract
			// posts, accepts, and then refuses every hand-over forever. The
			// outfitter shipped a 60-coil ask against MAXCOIL 30 this way.
			if(ispath(request["type"], /obj/item/stack))
				var/obj/item/stack/asked = request["type"]
				var/ceiling = initial(asked.max_amount)
				if(request["amount"] > ceiling)
					TEST_FAIL("[shop_type] requests [request["amount"]] of [request["type"]], but that stack caps at [ceiling] - the contract can never be turned in")
		qdel(shop)

	TEST_ASSERT(shops_checked >= 5, "only [shops_checked] shops with a category list were checked")
	TEST_ASSERT(skus_checked >= 100, "only [skus_checked] SKUs were checked. The catalog walk is not seeing the shelves")
