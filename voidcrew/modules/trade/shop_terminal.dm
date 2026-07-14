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

/obj/machinery/computer/outpost_shop_terminal/ui_data(mob/user)
	var/list/data = list()

	var/datum/outpost_shop/shop = outpost?.shop
	data["shop_name"] = shop ? shop.outpost_name : "OFFLINE"
	data["trader_name"] = shop ? shop.trader_name : ""
	data["barred"] = outpost ? outpost.is_user_barred(user) : FALSE

	// Buyer's wallet snapshot, for the header
	var/voucher_count = 0
	if(isliving(user))
		var/mob/living/buyer = user
		for(var/obj/item/stack/trade_voucher/vouchers in buyer.held_items)
			voucher_count += vouchers.amount
	data["held_vouchers"] = voucher_count
	var/obj/item/card/id/id_card
	if(isliving(user))
		var/mob/living/living_user = user
		id_card = living_user.get_idcard(TRUE)
	data["account_credits"] = id_card?.registered_account ? id_card.registered_account.account_balance : null

	var/list/skus = list()
	if(shop)
		for(var/datum/shop_sku/sku as anything in shop.skus)
			var/denial = isliving(user) ? sku.get_denial_reason(user) : "Unavailable."
			skus += list(list(
				"ref" = REF(sku),
				"name" = sku.name,
				"desc" = sku.desc,
				"price_text" = sku.get_price_text(),
				"stock" = sku.stock,
				"can_buy" = !data["barred"] && sku.stock > 0 && isnull(denial),
				"denial" = denial,
			))
	data["skus"] = skus

	// Sell side: what the trader is buying this round
	var/list/buybacks = list()
	if(shop)
		for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
			var/denial = isliving(user) ? buyback.get_denial_reason(user) : "Unavailable."
			buybacks += list(list(
				"ref" = REF(buyback),
				"name" = buyback.name,
				"desc" = buyback.desc,
				"wanted_text" = buyback.get_wanted_text(),
				"payment_text" = buyback.get_payment_text(),
				"demand" = buyback.demand,
				"can_sell" = !data["barred"] && buyback.demand > 0 && isnull(denial),
				"denial" = denial,
			))
	data["buybacks"] = buybacks

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
				return TRUE
			var/datum/shop_sku/sku = locate(params["ref"]) in outpost.shop.skus
			if(!sku)
				return TRUE
			if(sku.stock <= 0)
				to_chat(user, span_warning("Out of stock."))
				return TRUE
			var/denial = sku.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				return TRUE
			if(sku.try_purchase(user, src))
				playsound(src, 'sound/machines/ping.ogg', 40, TRUE)
				outpost.trader?.speak_line(TRADER_LINE_SALE)
			return TRUE
		if("sell")
			if(outpost.is_user_barred(user))
				outpost.trader?.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				return TRUE
			var/datum/shop_buyback/buyback = locate(params["ref"]) in outpost.shop.buybacks
			if(!buyback)
				return TRUE
			if(buyback.demand <= 0)
				to_chat(user, span_warning("Not buying any more this shift."))
				return TRUE
			var/denial = buyback.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				return TRUE
			if(buyback.try_sell(user, src))
				playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
				outpost.trader?.speak_line(TRADER_LINE_SALE)
			return TRUE
