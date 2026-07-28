/**
 * # Outpost Trader NPC
 *
 * The outpost's shopkeeper in the flesh: an unkillable static mob standing
 * behind the counter. Clicking them opens a radial — Trade, Talk, and (for the
 * outpost's main trader) Contracts — which consolidates what used to be a
 * holopad, a shop terminal and a mission board into one person.
 *
 * The trade and contract radials open the same TraderShop / OutpostMissionBoard
 * tgui windows as before; the mob hosts them through two small facet datums
 * (one interface per tgui src_object) so both can be open at once.
 *
 * Unkillable AND protected: godmode makes violence pointless, and attacking a
 * trader is aggression against outpost property — embargo rules apply (unlike
 * the loiterers, who are squatters, not staff).
 *
 * Speech lines come from the outpost's shop datum, so each trader has their
 * own voice (see the trader_lines lists on the /datum/outpost_shop subtypes).
 */

#define TRADER_NPC_OPTION_TRADE "Trade"
#define TRADER_NPC_OPTION_TALK "Talk"
#define TRADER_NPC_OPTION_CONTRACTS "Contracts"

/mob/living/basic/outpost_trader
	name = "trader"
	desc = "An independent merchant. The prices aren't negotiable, and the turrets are on their side."
	icon = 'icons/mob/simple/simple_human.dmi'
	unique_name = FALSE
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	density = TRUE
	move_resist = INFINITY // nobody drags the shopkeep off their counter
	basic_mob_flags = NONE
	// The outpost turrets skip faction-mates outright, belt-and-suspenders on
	// top of aggression being per-mind (see outpost_security.dm)
	faction = list(FACTION_TURRET, FACTION_NEUTRAL)
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	/// The outpost this trader works for (set by the outpost on interior link)
	var/obj/structure/overmap/trader_outpost/outpost
	/// The shop this trader fronts: null for the outpost's main shop, or a
	/// /datum/outpost_shop typepath for a vendor stall (the bar, the clinic, ...)
	var/shop_type
	/// The resolved live shop (set by the outpost on interior link)
	var/datum/outpost_shop/shop
	/// Facet hosting the TraderShop tgui
	var/datum/outpost_trader_ui/shop_ui
	/// Facet hosting the OutpostMissionBoard tgui (main trader only in practice)
	var/datum/outpost_trader_ui/contracts_ui
	/// Whether the shop-driven name/appearance/voice have been applied
	var/shop_setup_done = FALSE
	/// Minimum delay between idle chatter lines
	COOLDOWN_DECLARE(idle_line_cooldown)
	/// Minimum delay between any spoken lines (don't spam on bulk purchases)
	COOLDOWN_DECLARE(speak_cooldown)

// Covers the roundstart pre-load path: the outpost links (and sets shop on)
// this mob before SSatoms initializes it — dressing the appearance dummy that
// early is unsafe, so the look is applied here instead. No-ops when there's no
// linked shop yet; the lazy-load path runs setup through link_interior_machinery.
/mob/living/basic/outpost_trader/Initialize(mapload)
	. = ..()
	// Godmode makes them unkillable; NOMOBSWAP stops help-intent walkers from
	// place-swapping through them (move_resist already blocks shoves/pushes).
	ADD_TRAIT(src, TRAIT_GODMODE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NOMOBSWAP, INNATE_TRAIT)
	shop_ui = new /datum/outpost_trader_ui/shop(src)
	contracts_ui = new /datum/outpost_trader_ui/contracts(src)
	setup_from_shop()

/mob/living/basic/outpost_trader/Destroy()
	QDEL_NULL(shop_ui)
	QDEL_NULL(contracts_ui)
	if(shop?.trader_npc == src)
		shop.trader_npc = null
	shop = null
	if(outpost)
		outpost.traders -= src
		if(outpost.trader == src)
			outpost.trader = null
		outpost = null
	return ..()

/**
 * Applies the shop's identity to the mob: name, dressed-human appearance and
 * bark voice. Called from Initialize (pre-load path, shop already linked) or
 * from the outpost's interior link (lazy-load path, mob already initialized).
 */
/mob/living/basic/outpost_trader/proc/setup_from_shop()
	if(shop_setup_done || !shop)
		return
	shop_setup_done = TRUE
	name = shop.trader_name
	real_name = shop.trader_name
	gender = shop.trader_gender
	apply_dynamic_human_appearance(src, outfit_path = shop.trader_outfit)
	if(shop.trader_voice_pack)
		set_bark_voice_pack(shop.trader_voice_pack)
		var/datum/atom_voice/bark_voice = get_bark_voice()
		if(bark_voice)
			bark_voice.pitch = shop.trader_voice_pitch

/mob/living/basic/outpost_trader/examine(mob/user)
	. = ..()
	if(shop)
		. += span_notice("[name] runs the counter at [shop.outpost_name]. Tap them on the shoulder to do business.")
	if(outpost?.is_user_barred(user))
		. += span_warning("[name] is pointedly ignoring you.")

// ===== INTERACTION =====

/mob/living/basic/outpost_trader/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(user.combat_mode)
		. = ..()
		outpost?.register_aggression(user)
		return
	// show_radial_menu sleeps; don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(open_trader_menu), user)
	return TRUE

/**
 * The Trade / Talk / Contracts radial. Contracts only shows on the outpost's
 * main trader — vendor stalls don't post work. Barred customers get refused
 * before the menu even opens.
 */
/mob/living/basic/outpost_trader/proc/open_trader_menu(mob/living/user)
	// outpost may legitimately be null: standalone stalls (the colosseum's
	// lanista) run a shop with no station behind it
	if(!shop)
		return
	if(outpost?.is_user_barred(user))
		speak_line(TRADER_LINE_REFUSAL)
		return
	var/list/options = list(
		TRADER_NPC_OPTION_TRADE = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_buy"),
		TRADER_NPC_OPTION_TALK = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk"),
	)
	if(isnull(shop_type)) // the main trader also runs the contract ledger
		options[TRADER_NPC_OPTION_CONTRACTS] = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_quest")
	var/choice = show_radial_menu(user, src, options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = TRUE, tooltips = TRUE)
	if(!choice || !check_menu(user))
		return
	switch(choice)
		if(TRADER_NPC_OPTION_TRADE)
			shop_ui.ui_interact(user)
		if(TRADER_NPC_OPTION_TALK)
			speak_line(TRADER_LINE_IDLE)
		if(TRADER_NPC_OPTION_CONTRACTS)
			outpost.ensure_shop_offers()
			contracts_ui.ui_interact(user)

/// Radial validity: customer still there, still conscious, still adjacent
/mob/living/basic/outpost_trader/proc/check_menu(mob/living/user)
	if(!istype(user))
		return FALSE
	if(IS_DEAD_OR_INCAP(user) || !user.Adjacent(src))
		return FALSE
	return TRUE

/**
 * Says a random personality line from the given TRADER_LINE_* category.
 * Rate-limited except for aggression lines, which always go through. Barks
 * fire automatically through the mob's say() (see modules/voice_barks).
 */
/mob/living/basic/outpost_trader/proc/speak_line(category)
	if(!shop)
		return
	if(category != TRADER_LINE_AGGRESSION && !COOLDOWN_FINISHED(src, speak_cooldown))
		return
	var/line = shop.get_line(category)
	if(!line)
		return
	COOLDOWN_START(src, speak_cooldown, 3 SECONDS)
	say(line)

// Idle chatter on the mob's life tick, roughly once every few minutes
/mob/living/basic/outpost_trader/Life(seconds_per_tick, times_fired)
	. = ..()
	if(!shop || !COOLDOWN_FINISHED(src, idle_line_cooldown))
		return
	if(!prob(15))
		return
	// Only chatter when someone's around to hear it
	var/audience = FALSE
	for(var/mob/living/visitor in view(7, src))
		if(visitor.client)
			audience = TRUE
			break
	if(!audience)
		return
	COOLDOWN_START(src, idle_line_cooldown, 2 MINUTES)
	speak_line(TRADER_LINE_IDLE)

/// The polite "no" noise for refused purchases and sales
/mob/living/basic/outpost_trader/proc/play_denial()
	playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)

// ===== AGGRESSION =====
// Swinging at the staff is aggression like attacking anything else here; the
// blow itself bounces off godmode.

/mob/living/basic/outpost_trader/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/mob/living/basic/outpost_trader/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE, blocked = 0)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

// ===== VENDOR STALL VARIANTS (the outposts' side businesses) =====

// The Undertow's stalls (shop_catalog_black_market_vendors.dm)

/mob/living/basic/outpost_trader/dregs_barkeep
	shop_type = /datum/outpost_shop/vendor/dregs_bar

/mob/living/basic/outpost_trader/clinic_doctor
	shop_type = /datum/outpost_shop/vendor/patchup_clinic

// Halcyon's stalls (shop_catalog_general_vendors.dm)

/mob/living/basic/outpost_trader/potting_shed
	shop_type = /datum/outpost_shop/vendor/potting_shed

/mob/living/basic/outpost_trader/bait_shop
	shop_type = /datum/outpost_shop/vendor/bait_shop

// The Quartermain's stalls (shop_catalog_outfitter_vendors.dm,
// shop_catalog_suit_vendor.dm)

/mob/living/basic/outpost_trader/skunkworks
	shop_type = /datum/outpost_shop/vendor/skunkworks

/mob/living/basic/outpost_trader/suit_fitter
	shop_type = /datum/outpost_shop/vendor/suit_fitter

// =========================================================================
// UI FACETS
// =========================================================================

/**
 * # Trader UI facet
 *
 * tgui allows one interface per (user, src_object) pair, so the trader hosts
 * each of its two windows on a small datum facet. The facet delegates
 * physicality to the mob via ui_host — distance checks run against the trader.
 */
/datum/outpost_trader_ui
	/// The trader this facet fronts for
	var/mob/living/basic/outpost_trader/npc

/datum/outpost_trader_ui/New(mob/living/basic/outpost_trader/npc)
	..()
	src.npc = npc

/datum/outpost_trader_ui/Destroy()
	SStgui.close_uis(src)
	npc = null
	return ..()

/datum/outpost_trader_ui/ui_host()
	return npc

/datum/outpost_trader_ui/ui_state(mob/user)
	return GLOB.physical_state

/**
 * # The storefront window
 *
 * The buy/sell tgui, sold against the outpost's shared /datum/outpost_shop
 * stock. Payment is stateless — nothing is inserted or escrowed. At purchase
 * time it checks the buyer's hands for vouchers / barter goods and their ID's
 * bank account for credits, then charges and dispenses.
 */
/datum/outpost_trader_ui/shop/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TraderShop", npc.shop ? npc.shop.outpost_name : npc.name)
		ui.open()

/// The full catalog: everything that doesn't change between purchases.
/// Volatile state (stock, wallet, denials) rides ui_data and joins by ref.
/datum/outpost_trader_ui/shop/ui_static_data(mob/user)
	var/list/data = list()
	var/datum/outpost_shop/shop = npc.shop

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

/datum/outpost_trader_ui/shop/ui_data(mob/user)
	var/list/data = list()
	var/datum/outpost_shop/shop = npc.shop

	data["barred"] = npc.outpost ? npc.outpost.is_user_barred(user) : FALSE

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

/datum/outpost_trader_ui/shop/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/living/user = ui.user
	var/datum/outpost_shop/shop = npc.shop
	if(!istype(user) || !shop)
		return

	switch(action)
		if("buy")
			if(npc.outpost?.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				npc.play_denial()
				return TRUE
			var/datum/shop_sku/sku = locate(params["ref"]) in shop.skus
			if(!sku)
				return TRUE
			if(sku.stock <= 0)
				to_chat(user, span_warning("Out of stock."))
				npc.play_denial()
				return TRUE
			var/denial = sku.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				npc.play_denial()
				return TRUE
			if(sku.try_purchase(user, npc))
				playsound(npc, 'sound/effects/cashregister.ogg', 40, TRUE)
				npc.speak_line(TRADER_LINE_SALE)
			return TRUE
		if("sell")
			if(npc.outpost?.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				npc.play_denial()
				return TRUE
			var/datum/shop_buyback/buyback = locate(params["ref"]) in shop.buybacks
			if(!buyback)
				return TRUE
			if(buyback.demand <= 0)
				to_chat(user, span_warning("Not buying any more this shift."))
				npc.play_denial()
				return TRUE
			var/denial = buyback.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				npc.play_denial()
				return TRUE
			if(buyback.try_sell(user, npc))
				playsound(npc, 'sound/effects/cashregister.ogg', 40, TRUE)
				npc.speak_line(TRADER_LINE_SALE)
			return TRUE
		if("sell_all")
			if(npc.outpost?.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				npc.play_denial()
				return TRUE
			var/datum/shop_buyback/buyback = locate(params["ref"]) in shop.buybacks
			if(!buyback)
				return TRUE
			var/denial = buyback.get_denial_reason(user)
			if(denial)
				to_chat(user, span_warning(denial))
				npc.play_denial()
				return TRUE
			if(buyback.try_sell_bulk(user, npc) > 0)
				playsound(npc, 'sound/effects/cashregister.ogg', 40, TRUE)
				npc.speak_line(TRADER_LINE_SALE)
			else
				npc.play_denial()
			return TRUE

/**
 * # The contract ledger window
 *
 * The posting side of the outpost mission loop (see outpost_missions.dm for
 * the offers themselves). Accepting puts the contract in the ship's active
 * list; item contracts can also be turned in right here, at the trader.
 */
/datum/outpost_trader_ui/contracts/ui_interact(mob/user, datum/tgui/ui)
	npc.outpost?.ensure_shop_offers()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostMissionBoard", "[npc.name]'s contracts")
		ui.open()

/datum/outpost_trader_ui/contracts/ui_data(mob/user)
	var/list/data = list()
	var/obj/structure/overmap/trader_outpost/outpost = npc.outpost

	var/datum/outpost_shop/shop = outpost?.shop
	data["shop_name"] = shop ? shop.outpost_name : "OFFLINE"
	data["trader_name"] = shop ? shop.trader_name : ""
	data["barred"] = outpost ? outpost.is_user_barred(user) : FALSE

	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	data["ship_name"] = ship ? ship.name : null
	data["ship_mission_slots_free"] = ship ? (ship.max_missions - length(ship.active_missions)) : 0

	var/list/offers = list()
	if(outpost)
		for(var/datum/mission/offer as anything in outpost.shop_offers)
			if(QDELETED(offer))
				continue
			var/list/offer_data = offer.get_ui_data()
			offer_data["wanted_text"] = offer.get_progress_string()
			offers += list(offer_data)
	data["offers"] = offers

	// The ship's active contracts, with per-contract turn-in readiness at
	// THIS trader — any item mission can be turned in here (couriers only at
	// their destination), so crews can settle up without flying home
	var/list/ship_missions = list()
	if(ship)
		for(var/datum/mission/mission as anything in ship.active_missions)
			if(QDELETED(mission))
				continue
			var/list/mission_data = mission.get_ui_data()
			mission_data["from_this_shop"] = (mission.shop == outpost?.shop)
			var/location_ok = mission.can_turn_in_at(npc)
			mission_data["location_ok"] = location_ok
			var/obj/item/match
			if(isliving(user) && mission.requires_item)
				for(var/obj/item/held in user.held_items)
					if(mission.can_turn_in(held))
						match = held
						break
			mission_data["holding_valid_item"] = !!match
			var/turn_in_hint
			if(!mission.requires_item)
				turn_in_hint = "Not an item contract."
			else if(!location_ok)
				turn_in_hint = mission.get_wrong_location_reason(npc)
			else if(!match)
				turn_in_hint = "Hold the contract goods in hand."
			mission_data["turn_in_hint"] = turn_in_hint
			ship_missions += list(mission_data)
	data["ship_missions"] = ship_missions

	return data

/datum/outpost_trader_ui/contracts/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/living/user = ui.user
	var/obj/structure/overmap/trader_outpost/outpost = npc.outpost
	if(!istype(user) || !outpost?.shop)
		return

	switch(action)
		if("accept")
			if(outpost.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				return TRUE
			var/obj/structure/overmap/ship/ship = get_crew_ship(user)
			if(!ship)
				npc.balloon_alert(user, "you have no ship!")
				return TRUE
			var/datum/mission/offer = locate(params["ref"]) in outpost.shop_offers
			if(!offer || QDELETED(offer))
				npc.balloon_alert(user, "offer no longer posted!")
				return TRUE

			// Ride the standard accept path so limits/bookkeeping all apply
			ship.available_missions += offer
			var/result = ship.accept_mission(offer)
			if(result != TRUE)
				ship.available_missions -= offer
				npc.balloon_alert(user, "[result]")
				npc.play_denial()
				return TRUE

			outpost.shop_offers -= offer
			outpost.ensure_shop_offers()
			npc.balloon_alert(user, "contract accepted!")
			playsound(npc, 'sound/machines/ding.ogg', 50, TRUE)
			npc.speak_line(TRADER_LINE_GREETING)
			return TRUE

		if("turn_in")
			if(outpost.is_user_barred(user))
				npc.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				return TRUE
			var/obj/structure/overmap/ship/ship = get_crew_ship(user)
			if(!ship)
				npc.balloon_alert(user, "you have no ship!")
				return TRUE
			var/datum/mission/mission = locate(params["ref"]) in ship.active_missions
			if(!mission || QDELETED(mission))
				npc.balloon_alert(user, "contract not found!")
				return TRUE
			var/obj/item/offered
			for(var/obj/item/held in user.held_items)
				if(mission.can_turn_in(held))
					offered = held
					break
			var/result = ship.complete_mission(mission, npc, offered)
			if(result != TRUE)
				npc.balloon_alert(user, "[result]")
				npc.play_denial()
				return TRUE
			// Counted hand-overs accept the item but keep the contract open
			npc.balloon_alert(user, QDELETED(mission) ? "contract fulfilled!" : "goods received!")
			playsound(npc, 'sound/effects/cashregister.ogg', 50, TRUE)
			npc.speak_line(TRADER_LINE_SALE)
			return TRUE

#undef TRADER_NPC_OPTION_TRADE
#undef TRADER_NPC_OPTION_TALK
#undef TRADER_NPC_OPTION_CONTRACTS
