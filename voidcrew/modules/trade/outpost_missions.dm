/**
 * # Outpost Mission Board
 *
 * The shop-specific mission loop: each trader outpost posts a couple of
 * supply requests ("bring me X"), and the pay is a FREE ITEM off the shop's
 * own shelves rather than credits. Gives a ship a reason to detour to an
 * outpost even with empty pockets.
 *
 * Wiring rides the existing mission pipeline end to end: accepting at the
 * outpost board puts the mission in the ship's active list, and turn-in
 * happens back at the ship's own mission board + pad, where the reward item
 * spawns exactly like voucher/item rewards already do.
 */

/// How many supply requests an outpost keeps posted at once
#define OUTPOST_SHOP_OFFER_COUNT 2

/**
 * # Outpost Supply Mission
 *
 * Delivery-style: haul the asked goods to your ship's mission pad. Pays no
 * credits — the reward is one free item rolled off the posting shop's SKU
 * list at creation time.
 */
/datum/mission/outpost_supply
	name = "Supply Request: %ITEM_NAME%"
	desc = "%AUTHOR% is paying in kit: deliver %ITEM_NAME% to your ship's mission pad and a %REWARD% comes off the shelf, free."
	weight = 0 // never rolled by the mission subsystem; outposts post these themselves
	requires_item = TRUE
	value_min = 0
	value_max = 0
	duration = 40 MINUTES

	/// The shop that posted this request (source of author, wants and reward)
	var/datum/outpost_shop/shop
	/// The type of item required for delivery
	var/required_type
	/// Display name for the required item
	var/required_name
	/// Amount required (for stacks)
	var/required_amount = 1

/datum/mission/outpost_supply/New(datum/outpost_shop/shop)
	src.shop = shop
	..()

/datum/mission/outpost_supply/Destroy()
	shop = null
	return ..()

/datum/mission/outpost_supply/generate_mission_details()
	if(!shop)
		generation_failed = TRUE
		return
	author = shop.trader_name

	var/list/request = length(shop.mission_requests) ? pick(shop.mission_requests) : null
	if(!request)
		generation_failed = TRUE
		return
	required_type = request["type"]
	required_name = request["name"]
	required_amount = request["amount"] || 1
	difficulty = request["difficulty"] || MISSION_DIFFICULTY_MEDIUM

	// The pay: one free item off the shelf. Rolled from the SKU list so the
	// reward is always something the shop actually sells.
	var/list/reward_pool = list()
	for(var/datum/shop_sku/sku as anything in shop.skus)
		if(sku.item_path)
			reward_pool += sku.item_path
	if(!length(reward_pool))
		generation_failed = TRUE
		return
	mission_reward = pick(reward_pool)

	. = ..()

/datum/mission/outpost_supply/apply_text_substitutions()
	. = ..()
	var/item_text = required_amount > 1 ? "[required_amount] [required_name]" : required_name
	name = replacetext(name, "%ITEM_NAME%", item_text)
	desc = replacetext(desc, "%ITEM_NAME%", item_text)

/datum/mission/outpost_supply/can_turn_in(obj/item/item)
	if(!item || !istype(item, required_type))
		return FALSE
	if(istype(item, /obj/item/stack))
		var/obj/item/stack/stack = item
		if(stack.amount < required_amount)
			return FALSE
	return TRUE

/datum/mission/outpost_supply/get_failure_reason(obj/item/item)
	if(!item)
		return "No item provided."
	if(!istype(item, required_type))
		return "Wrong item type."
	if(istype(item, /obj/item/stack))
		var/obj/item/stack/stack = item
		if(stack.amount < required_amount)
			return "Need [required_amount], only have [stack.amount]."
	return ..()

/datum/mission/outpost_supply/consume_turned_in_item(obj/item/item)
	if(istype(item, /obj/item/stack))
		var/obj/item/stack/stack = item
		stack.use(required_amount)
	else
		qdel(item)

/datum/mission/outpost_supply/get_progress_string()
	return "Deliver [required_amount > 1 ? "[required_amount] " : ""][required_name]"

// ===== OFFER MANAGEMENT (lives on the outpost) =====

/**
 * Keeps the outpost's posted supply requests topped up. Discards failed rolls.
 */
/obj/structure/overmap/trader_outpost/proc/ensure_shop_offers()
	if(!shop)
		return
	var/safety = 10
	while(length(shop_offers) < OUTPOST_SHOP_OFFER_COUNT && safety-- > 0)
		var/datum/mission/outpost_supply/offer = new(shop)
		if(offer.generation_failed)
			qdel(offer)
			continue
		shop_offers += offer

/**
 * # Outpost Mission Board Terminal
 *
 * The posting side of the loop. Indestructible like everything else here;
 * attacking it is aggression like everything else here.
 */
/obj/machinery/computer/outpost_mission_board
	name = "supply request board"
	desc = "A contract board listing what the trader wants hauled in. Payment is store credit in its most literal form."
	icon_screen = "mission"
	icon_keyboard = "rd_key"
	circuit = null
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	light_color = COLOR_BRIGHT_ORANGE

	/// The outpost this board posts for (set by the outpost on interior load)
	var/obj/structure/overmap/trader_outpost/outpost

/obj/machinery/computer/outpost_mission_board/Destroy()
	if(outpost)
		outpost.mission_boards -= src
		outpost = null
	return ..()

/obj/machinery/computer/outpost_mission_board/examine(mob/user)
	. = ..()
	if(outpost?.is_user_barred(user))
		. += span_warning("The screen shows a red banner: TRADE EMBARGO IN EFFECT.")

// Attacking the board is aggression
/obj/machinery/computer/outpost_mission_board/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/computer/outpost_mission_board/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

/**
 * The ship this user crews for (first team with a live ship). Same mapping
 * the embargo uses in the other direction.
 */
/obj/machinery/computer/outpost_mission_board/proc/get_user_ship(mob/user)
	if(!user?.mind)
		return null
	for(var/datum/team/voidcrew/team as anything in user.mind.ship_teams)
		if(team.ship)
			return team.ship
	return null

/obj/machinery/computer/outpost_mission_board/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	outpost?.ensure_shop_offers()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostMissionBoard", name)
		ui.open()

/obj/machinery/computer/outpost_mission_board/ui_data(mob/user)
	var/list/data = list()

	var/datum/outpost_shop/shop = outpost?.shop
	data["shop_name"] = shop ? shop.outpost_name : "OFFLINE"
	data["trader_name"] = shop ? shop.trader_name : ""
	data["barred"] = outpost ? outpost.is_user_barred(user) : FALSE

	var/obj/structure/overmap/ship/ship = get_user_ship(user)
	data["ship_name"] = ship ? ship.name : null
	data["ship_mission_slots_free"] = ship ? (ship.max_missions - length(ship.active_missions)) : 0

	var/list/offers = list()
	if(outpost)
		for(var/datum/mission/outpost_supply/offer as anything in outpost.shop_offers)
			if(QDELETED(offer))
				continue
			var/list/offer_data = offer.get_ui_data()
			offer_data["wanted_text"] = offer.get_progress_string()
			offers += list(offer_data)
	data["offers"] = offers

	// Which of this ship's active missions came from this outpost (so the
	// board can show "you're already on it")
	var/list/accepted = list()
	if(ship && outpost)
		for(var/datum/mission/outpost_supply/mission in ship.active_missions)
			if(mission.shop == outpost.shop)
				accepted += list(mission.get_ui_data())
	data["accepted"] = accepted

	return data

/obj/machinery/computer/outpost_mission_board/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/living/user = ui.user
	if(!istype(user) || !outpost?.shop)
		return

	switch(action)
		if("accept")
			if(outpost.is_user_barred(user))
				outpost.trader?.speak_line(TRADER_LINE_REFUSAL)
				to_chat(user, span_warning("Trade embargo in effect. Service refused."))
				return TRUE
			var/obj/structure/overmap/ship/ship = get_user_ship(user)
			if(!ship)
				balloon_alert(user, "you have no ship!")
				return TRUE
			var/datum/mission/outpost_supply/offer = locate(params["ref"]) in outpost.shop_offers
			if(!offer || QDELETED(offer))
				balloon_alert(user, "offer no longer posted!")
				return TRUE

			// Ride the standard accept path so limits/bookkeeping all apply
			ship.available_missions += offer
			var/result = ship.accept_mission(offer)
			if(result != TRUE)
				ship.available_missions -= offer
				balloon_alert(user, "[result]")
				playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
				return TRUE

			outpost.shop_offers -= offer
			outpost.ensure_shop_offers()
			balloon_alert(user, "request accepted!")
			playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			outpost.trader?.speak_line(TRADER_LINE_GREETING)
			return TRUE

#undef OUTPOST_SHOP_OFFER_COUNT
