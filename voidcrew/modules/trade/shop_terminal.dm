/**
 * # Outpost Shop Terminal
 *
 * Storefront console inside a trader outpost. Multiple terminals sell against
 * the outpost's single shared /datum/outpost_shop stock, so several crews can
 * shop at once.
 *
 * Payment is stateless — nothing is inserted or escrowed. At purchase time the
 * terminal checks the buyer's hands for vouchers / barter goods and their ID's
 * bank account for credits, then charges and dispenses.
 */
/obj/machinery/computer/outpost_shop_terminal
	name = "shop terminal"
	desc = "A storefront terminal wired into the outpost's stock ledger. Prices are fixed and the warranty is a laugh track."
	icon_screen = "request"
	icon_keyboard = "generic_key"
	circuit = null
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	light_color = COLOR_BRIGHT_ORANGE

	/// The outpost this terminal sells for (set by the outpost on interior load)
	var/obj/structure/overmap/trader_outpost/outpost

/obj/machinery/computer/outpost_shop_terminal/Destroy()
	if(outpost)
		outpost.terminals -= src
		outpost = null
	return ..()

/obj/machinery/computer/outpost_shop_terminal/examine(mob/user)
	. = ..()
	if(outpost?.is_user_barred(user))
		. += span_warning("The screen shows a red banner: TRADE EMBARGO IN EFFECT.")

// Attacking the storefront is aggression
/obj/machinery/computer/outpost_shop_terminal/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/computer/outpost_shop_terminal/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

/obj/machinery/computer/outpost_shop_terminal/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TraderShop", name)
		ui.open()

/// The full catalog: everything that doesn't change between purchases.
/// Volatile state (stock, wallet, denials) rides ui_data and joins by ref.
/obj/machinery/computer/outpost_shop_terminal/ui_static_data(mob/user)
	var/list/data = list()

	var/datum/outpost_shop/shop = outpost?.shop
	data["shop_name"] = shop ? shop.outpost_name : "OFFLINE"
	data["trader_name"] = shop ? shop.trader_name : ""
	data["categories"] = shop ? shop.categories : list()

	var/list/catalog = list()
	if(shop)
		for(var/datum/shop_sku/sku as anything in shop.skus)
			catalog += list(list(
				"ref" = REF(sku),
				"name" = sku.name,
				"desc" = sku.desc,
				"category" = sku.category,
				"shelf" = sku.shelf,
				"icon" = sku.get_ui_icon(),
				"price_credits" = sku.price_credits,
				"final_credits" = sku.get_credit_price(),
				"price_vouchers" = sku.price_vouchers,
				"discount_pct" = sku.discount_pct,
				"price_text" = sku.get_price_text(),
				"barter" = istype(sku, /datum/shop_sku/barter),
			))
	data["catalog"] = catalog

	// The wanted ledger: what the trader buys (volatile half in ui_data)
	var/list/ledger = list()
	if(shop)
		for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
			ledger += list(list(
				"ref" = REF(buyback),
				"name" = buyback.name,
				"desc" = buyback.desc,
				"category" = buyback.category,
				"icon" = buyback.get_ui_icon(),
				"wanted_text" = buyback.get_wanted_text(),
				"payment_text" = buyback.get_payment_text(),
				"pays_vouchers" = buyback.pay_vouchers > 0,
			))
	data["ledger"] = ledger

	return data

/obj/machinery/computer/outpost_shop_terminal/ui_data(mob/user)
	var/list/data = list()

	var/datum/outpost_shop/shop = outpost?.shop
	data["barred"] = outpost ? outpost.is_user_barred(user) : FALSE

	// Buyer's wallet snapshot, for the header — vouchers count from the whole
	// inventory, same as payment accepts them
	data["held_vouchers"] = isliving(user) ? count_trade_vouchers(user) : 0
	var/obj/item/card/id/id_card
	if(isliving(user))
		var/mob/living/living_user = user
		id_card = living_user.get_idcard(TRUE)
	data["account_credits"] = id_card?.registered_account ? id_card.registered_account.account_balance : null

	var/list/stock_states = list()
	if(shop)
		for(var/datum/shop_sku/sku as anything in shop.skus)
			var/denial = isliving(user) ? sku.get_denial_reason(user) : "Unavailable."
			stock_states += list(list(
				"ref" = REF(sku),
				"stock" = sku.stock,
				"can_buy" = !data["barred"] && sku.stock > 0 && isnull(denial),
				"denial" = denial,
			))
	data["stock_states"] = stock_states

	// Sell side volatile state: demand, what the seller is carrying, denials
	var/list/ledger_states = list()
	if(shop)
		for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
			var/denial = isliving(user) ? buyback.get_denial_reason(user) : "Unavailable."
			ledger_states += list(list(
				"ref" = REF(buyback),
				"demand" = buyback.demand,
				"carrying" = isliving(user) ? buyback.count_carried_units(user) : 0,
				"can_sell" = !data["barred"] && buyback.demand > 0 && isnull(denial),
				"denial" = denial,
			))
	data["ledger_states"] = ledger_states

	return data

/obj/machinery/computer/outpost_shop_terminal/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/living/user = ui.user
	if(!istype(user) || !outpost?.shop)
		return

	switch(action)
		if("buy")
			if(outpost.is_user_barred(user))
				outpost.trader?.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				play_denial()
				return TRUE
			var/datum/shop_sku/sku = locate(params["ref"]) in outpost.shop.skus
			if(!sku)
				return TRUE
			if(sku.stock <= 0)
				to_chat(user, span_warning("Out of stock."))
				play_denial()
				return TRUE
			var/denial = sku.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				play_denial()
				return TRUE
			if(sku.try_purchase(user, src))
				playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
				outpost.trader?.speak_line(TRADER_LINE_SALE)
			return TRUE
		if("sell")
			if(outpost.is_user_barred(user))
				outpost.trader?.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				play_denial()
				return TRUE
			var/datum/shop_buyback/buyback = locate(params["ref"]) in outpost.shop.buybacks
			if(!buyback)
				return TRUE
			if(buyback.demand <= 0)
				to_chat(user, span_warning("Not buying any more this shift."))
				play_denial()
				return TRUE
			var/denial = buyback.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				play_denial()
				return TRUE
			if(buyback.try_sell(user, src))
				playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
				outpost.trader?.speak_line(TRADER_LINE_SALE)
			return TRUE
		if("sell_all")
			if(outpost.is_user_barred(user))
				outpost.trader?.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				play_denial()
				return TRUE
			var/datum/shop_buyback/buyback = locate(params["ref"]) in outpost.shop.buybacks
			if(!buyback)
				return TRUE
			var/denial = buyback.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				play_denial()
				return TRUE
			if(buyback.try_sell_bulk(user, src) > 0)
				playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
				outpost.trader?.speak_line(TRADER_LINE_SALE)
			else
				play_denial()
			return TRUE

/// The polite "no" noise for refused purchases and sales
/obj/machinery/computer/outpost_shop_terminal/proc/play_denial()
	playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
