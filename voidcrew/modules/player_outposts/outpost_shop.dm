/**
 * # Owner shop
 *
 * A service room (outpost_service_rooms.dm) with a shop front, a counter and a staff room. The
 * stock machine in the staff room holds the goods (outpost_shop_stock.dm). Customers buy at the
 * register on the counter.
 *
 * Visitors and ordinary members pay the listed price into the treasury. Managers and pricing
 * users take stock free (R1). An ownerless outpost's shop is closed.
 */

/datum/map_template/outpost_upgrade/shop
	name = "Outpost Shop"

/datum/map_template/outpost_upgrade/shop/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_shop_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/shop/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_shop_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/outpost_upgrade/service/shop
	id = "shop"
	name = "Shop"
	desc = "A shop front with a counter and a register, and a stock room."
	price = OUTPOST_SHOP_COST
	template_type = /datum/map_template/outpost_upgrade/shop
	area_type = /area/voidcrew/player_outpost/service_room/shop
	/// Closed shops sell nothing, to anyone
	var/is_open = TRUE
	var/datum/weakref/stock_ref
	var/datum/weakref/register_ref

/datum/outpost_upgrade/service/shop/Destroy()
	stock_ref = null
	register_ref = null
	return ..()

/datum/outpost_upgrade/service/shop/on_service_installed(mob/user)
	var/obj/machinery/outpost_shop_stock/stock
	var/obj/machinery/computer/outpost_shop_register/register
	for(var/turf/tile as anything in room_turfs())
		stock = stock || (locate(/obj/machinery/outpost_shop_stock) in tile)
		register = register || (locate(/obj/machinery/computer/outpost_shop_register) in tile)
	if(!stock || !register)
		log_mapping("OUTPOST SHOP: the shop at '[outpost?.name]' loaded without its [!stock ? "stock unit" : "register"]")
	stock_ref = stock ? WEAKREF(stock) : null
	register_ref = register ? WEAKREF(register) : null
	stock?.mark_dirty()

/datum/outpost_upgrade/service/shop/proc/get_stock()
	var/obj/machinery/outpost_shop_stock/stock = stock_ref?.resolve()
	return QDELETED(stock) ? null : stock

/// Staff (management or pricing) open or close the shop. Null when done, else a refusal.
/datum/outpost_upgrade/service/shop/proc/set_open(mob/living/user, open)
	if(QDELETED(outpost) || !(outpost.is_current_management_user(user) || outpost.is_current_pricing_user(user)))
		return "Staff only."
	open = !!open
	if(open == is_open)
		return null
	is_open = open
	log_game("PLAYER OUTPOST: [key_name(user)] [open ? "opened" : "closed"] the shop at '[outpost.name]'")
	get_stock()?.mark_dirty()
	return null

/datum/outpost_upgrade/service/shop/service_ui_data(mob/user)
	return list(
		"kind" = "shop",
		"open" = is_open,
		"can_toggle" = !QDELETED(outpost) && (outpost.is_current_management_user(user) || outpost.is_current_pricing_user(user)),
	)

/datum/outpost_upgrade/service/shop/service_ui_act(mob/user, action, list/params)
	if(action != "toggle_open")
		return FALSE
	var/refusal = set_open(user, !is_open)
	if(refusal && user)
		to_chat(user, span_warning(refusal))
	return TRUE

// ===== REGISTER =====

/**
 * The counter terminal customers buy at. It hosts the buyer window (OutpostShop) and needs no
 * power, so pulling the outpost's power never stops sales or changes anything.
 */
/obj/machinery/computer/outpost_shop_register
	name = "shop register"
	desc = "The outpost shop's register."
	icon_screen = "request"
	icon_keyboard = "generic_key"
	circuit = null
	use_power = NO_POWER_USE
	density = TRUE
	interaction_flags_machine = INTERACT_MACHINE_OPEN | INTERACT_MACHINE_OFFLINE | INTERACT_MACHINE_ALLOW_SILICON
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Ckey -> world.time of their last Inspect
	var/list/inspect_times = list()

/obj/machinery/computer/outpost_shop_register/singularity_act()
	return 0

/obj/machinery/computer/outpost_shop_register/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/computer/outpost_shop_register/proc/get_shop()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	var/datum/outpost_upgrade/service/shop/shop = home?.service_upgrade("shop")
	if(!istype(shop) || shop.register_ref?.resolve() != src)
		return null
	return shop

/obj/machinery/computer/outpost_shop_register/proc/get_stock()
	var/datum/outpost_upgrade/service/shop/shop = get_shop()
	return shop?.get_stock()

/obj/machinery/computer/outpost_shop_register/examine(mob/user)
	. = ..()
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	var/closed = stock ? stock.closed_reason() : "Shop not installed."
	. += span_notice((closed ? "The screen reads: [closed]" : "The shop is open."))

/obj/machinery/computer/outpost_shop_register/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostShop", name)
		ui.set_autoupdate(FALSE)
		ui.open()

/obj/machinery/computer/outpost_shop_register/ui_data(mob/user)
	var/obj/machinery/outpost_shop_stock/stock = get_stock()
	if(stock)
		return stock.buyer_ui_data(user)
	return list(
		"shop_name" = "Shop",
		"open" = FALSE,
		"closed_reason" = "Shop not installed.",
		"free_take" = FALSE,
		"account_credits" = null,
		"confirm_total" = OUTPOST_SHOP_CONFIRM_TOTAL,
		"categories" = list(),
		"listings" = list(),
	)

/obj/machinery/computer/outpost_shop_register/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	switch(action)
		if("buy")
			buy(user, params["id"], params["quantity"], params["price"])
			return TRUE
		if("inspect")
			var/id = params["id"]
			var/obj/machinery/outpost_shop_stock/stock = get_stock()
			if(!istext(id) || !stock || !user?.ckey)
				return FALSE
			var/last = inspect_times[user.ckey]
			if(last && world.time < last + OUTPOST_SHOP_INSPECT_COOLDOWN)
				return FALSE
			inspect_times[user.ckey] = world.time
			stock.inspect_listing(stock.listings_by_id[id], user)
			return FALSE
	return FALSE

/// One purchase from the buyer window. Returns null when sold, else the refusal shown.
/obj/machinery/computer/outpost_shop_register/proc/buy(mob/living/user, id, quantity, shown_unit_price)
	var/datum/outpost_upgrade/service/shop/shop = get_shop()
	var/obj/machinery/outpost_shop_stock/stock = shop?.get_stock()
	var/refusal
	if(!stock)
		refusal = "Shop not installed."
	else if(!istext(id))
		refusal = "That listing is gone."
	else
		refusal = stock.sell(stock.listings_by_id[id], quantity, shown_unit_price, user, src)
	if(refusal)
		balloon_alert(user, LOWER_TEXT(refusal))
		to_chat(user, span_warning(refusal))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		return refusal
	playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	return null
