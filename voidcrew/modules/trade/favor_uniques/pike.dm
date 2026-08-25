/**
 * # Waystation Halcyon: favor uniques
 *
 * The general outpost's back-room rewards: three field tools for crews that
 * ran enough of the waystation's board to earn the good shelf. Each one takes
 * a counter service crews normally fly home for, the buyback window, the
 * contract board, the shop shelf, and puts a portable version of it in a
 * pocket. None of them mint money: the ledger still obeys the counter's
 * demand caps, the pad only settles contracts the crew already earned, and
 * the beacon spends credits at full shelf price.
 *
 * All three resolve the live general shop at use time by walking
 * GLOB.trader_outposts, and all three honor the outpost embargo
 * (is_user_barred), earning the back room doesn't launder an embargo.
 *
 * This file defines only the items. Their /datum/shop_sku favor-shelf
 * entries live in the shop catalog.
 */

/// How long the field contract pad needs between settlement sweeps
#define CONTRACT_PAD_COOLDOWN (5 SECONDS) // PROVISIONAL BALANCE
/// Drop charges a freight beacon ships with
#define FREIGHT_BEACON_USES 3
/// Flight time between paying for a freight drop and the pod's arrival
#define FREIGHT_BEACON_DELAY (20 SECONDS) // PROVISIONAL BALANCE

/**
 * The live general outpost (Waystation Halcyon) this round, or null when no
 * general outpost exists. istype runs on the shop INSTANCE, outposts carry
 * their shop as a live datum, and matching the instance is what tells the
 * main counter apart from the vendor stalls.
 */
/proc/get_general_trader_outpost()
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(istype(outpost.shop, /datum/outpost_shop/general))
			return outpost
	return null

// =========================================================================
// PIKE'S LEDGER: the buyback window, carried
// =========================================================================

/**
 * # Pike's ledger
 *
 * A handheld remote-buyback terminal. Used in hand, it lists every line of
 * Halcyon's wanted ledger the holder is carrying sellable units of and sells
 * them exactly as the counter would. Same prices, same shared demand caps,
 * same payout channels (credits to the ID's account, vouchers into hand).
 * Refuses embargoed crews and goes quiet when no general outpost exists.
 */
/obj/item/pike_ledger
	name = "Pike's ledger"
	desc = "A waterproofed copy of Waystation Halcyon's wanted ledger, kept current in Pike's handwriting. Barnaby had a transmitter fitted into the spine for his best customers: mark a line while carrying the goods and the waystation's till settles the sale wherever you're standing. The counter's demand limits still apply."
	icon = 'voidcrew/icons/obj/favor_uniques.dmi'
	icon_state = "pike_ledger"
	worn_icon_state = "electronic"
	inhand_icon_state = "export_scanner"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	item_flags = NOBLUDGEON

/obj/item/pike_ledger/examine(mob/user)
	. = ..()
	. += span_notice("Use it in hand while carrying goods off Halcyon's wanted list to sell them on the spot.")

/obj/item/pike_ledger/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	// The radial and the follow-up prompt both sleep; don't hold the click chain
	INVOKE_ASYNC(src, PROC_REF(open_ledger), user)
	return TRUE

/// Radial validity: still alive, still holding the ledger
/obj/item/pike_ledger/proc/ledger_radial_check(mob/living/user)
	// The 2026 upstream merge deleted IS_DEAD_OR_INCAP(); this is its old body.
	if(!istype(user) || user.incapacitated || user.stat)
		return FALSE
	if(loc != user)
		return FALSE
	return TRUE

/**
 * The whole flow: resolve Halcyon, list the carried buyback lines, sell the
 * picked one through the counter's own try_sell / try_sell_bulk.
 */
/obj/item/pike_ledger/proc/open_ledger(mob/living/user)
	var/obj/structure/overmap/trader_outpost/outpost = get_general_trader_outpost()
	if(!outpost?.shop)
		to_chat(user, span_warning("The ledger pings for Waystation Halcyon and gets no answer. There's no general outpost on the lanes this shift."))
		return
	if(outpost.is_user_barred(user))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		to_chat(user, span_warning("Halcyon's till refuses the connection: your crew is under trade embargo."))
		return

	var/datum/outpost_shop/shop = outpost.shop
	// Only lines the holder can actually sell right now make the menu
	var/list/choices = list()
	var/list/lookup = list()
	for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
		if(QDELETED(buyback) || !buyback.item_path)
			continue
		var/units = buyback.count_carried_units(user)
		if(units < 1)
			continue
		var/key = "[buyback.name] ([units] to sell, [buyback.get_payment_text()])"
		var/obj/item/cast = buyback.item_path
		choices[key] = image(icon = buyback.icon_override || initial(cast.icon), icon_state = buyback.icon_state_override || initial(cast.icon_state))
		lookup[key] = buyback
	if(!length(choices))
		to_chat(user, span_warning("You leaf through the ledger, but you're not carrying anything on Halcyon's wanted list."))
		return

	var/choice = show_radial_menu(user, src, choices, custom_check = CALLBACK(src, PROC_REF(ledger_radial_check), user), tooltips = TRUE)
	if(!choice || !ledger_radial_check(user))
		return
	var/datum/shop_buyback/buyback = lookup[choice]
	if(QDELETED(buyback))
		return

	var/mode = tgui_alert(user, "[buyback.get_wanted_text()]: [buyback.get_payment_text()]. Halcyon will take [buyback.demand] more sale\s this shift.", name, list("Sell one", "Sell all", "Cancel"))
	if(mode != "Sell one" && mode != "Sell all")
		return
	if(!ledger_radial_check(user) || QDELETED(buyback) || QDELETED(outpost))
		return
	// The menus sleep; the embargo may have landed while they were open
	if(outpost.is_user_barred(user))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		to_chat(user, span_warning("Halcyon's till refuses the connection: your crew is under trade embargo."))
		return

	// try_sell prints its own receipts; the vendor arg is only a payout drop
	// fallback and try_sell handles it being null (interior not loaded yet)
	var/mob/living/basic/outpost_trader/vendor = shop.trader_npc
	var/sold = FALSE
	if(mode == "Sell one")
		sold = buyback.try_sell(user, vendor)
	else
		sold = buyback.try_sell_bulk(user, vendor) > 0
	if(sold)
		playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	else
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		to_chat(user, span_warning(buyback.get_denial_reason(user) || "The sale fell through."))

// =========================================================================
// FIELD CONTRACT PAD: the contract board, carried
// =========================================================================

/**
 * # Field contract pad
 *
 * A portable mission turn-in point. Used in hand, it sweeps the crew ship's
 * active contracts and settles every one that's ready: item contracts take
 * whatever qualifying goods the holder has in hand, finished non-item
 * contracts collect outright. Everything routes through the ship's own
 * complete_mission, the same location gating, item validation and refusal
 * strings the trader counter and board console use, and rewards spawn at
 * the pad's turf via the standard turn-in flow. Couriered freight still
 * refuses anywhere but its destination outpost.
 */
/obj/item/field_contract_pad
	name = "field contract pad"
	desc = "A ruggedized terminal slaved to Waystation Halcyon's contract board. It reads your ship's open contracts and settles any that are ready where you stand: hold the contracted goods and thumb the plate, and the pay is dropped at your feet. Couriered freight still has to be handed over at its destination."
	icon = 'voidcrew/icons/obj/favor_uniques.dmi'
	icon_state = "contract_pad"
	worn_icon_state = "electronic"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	item_flags = NOBLUDGEON
	/// Minimum delay between settlement sweeps
	COOLDOWN_DECLARE(sweep_cooldown)

/obj/item/field_contract_pad/examine(mob/user)
	. = ..()
	. += span_notice("Use it in hand to settle your ship's contracts in the field. Hold an item contract's goods to turn them in.")

/obj/item/field_contract_pad/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	if(!COOLDOWN_FINISHED(src, sweep_cooldown))
		balloon_alert(user, "still transmitting!")
		return TRUE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		to_chat(user, span_warning("The pad finds no crew registration under your name, no ship, no contracts."))
		return TRUE
	if(!length(ship.active_missions))
		to_chat(user, span_notice("[ship]'s contract ledger is empty. Nothing to settle."))
		return TRUE
	COOLDOWN_START(src, sweep_cooldown, CONTRACT_PAD_COOLDOWN)

	to_chat(user, span_notice("[src] links to [ship]'s contract ledger:"))
	var/settled = 0
	// Copy: a successful turn-in removes the mission from active_missions mid-walk
	for(var/datum/mission/mission as anything in ship.active_missions.Copy())
		if(QDELETED(mission))
			continue
		var/mission_name = mission.name
		// The near-miss comes back too, so a refusal names the real shortfall
		// ("Need 30, only have 12"). Same trick the trader counter uses
		var/obj/item/offered = mission.requires_item ? mission.pick_offered_item(user) : null
		// complete_mission runs can_turn_in_at / can_turn_in / can_complete and
		// hands back get_wrong_location_reason / get_failure_reason on refusal
		var/result = ship.complete_mission(mission, src, offered)
		if(result == TRUE)
			settled++
			if(QDELETED(mission))
				to_chat(user, span_notice("• [mission_name], contract settled. Pay delivered to your position."))
			else
				to_chat(user, span_notice("• [mission_name], goods received; the contract continues."))
		else
			to_chat(user, span_warning("• [mission_name], [result]"))
	if(settled)
		playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	else
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
	return TRUE

// =========================================================================
// FREIGHT BEACON: the shop shelf, delivered
// =========================================================================

/**
 * # Freight beacon
 *
 * Remote purchase with pod delivery. Used in hand, it lists Halcyon's core
 * shelf (credit-priced lines only, no voucher stock, no intel, no barter)
 * and sells at the counter's own price, favor discount included. The goods
 * arrive by supply pod on the beacon's position after a short flight instead
 * of over the counter, stock decrements like any sale, and the beacon burns
 * out after three drops. Works anywhere with a floor: ship decks, planets,
 * ruins.
 */
/obj/item/freight_beacon
	name = "freight beacon"
	desc = "A drop beacon keyed to Waystation Halcyon's stockroom. Pick a line off the shelf list and pay the shelf price, and the waystation fires the goods down to the beacon's position in a supply pod. The charge pack is good for three drops, and the till still refuses embargoed crews."
	icon = 'voidcrew/icons/obj/favor_uniques.dmi'
	icon_state = "freight_beacon"
	worn_icon_state = "electronic"
	inhand_icon_state = "radio"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	item_flags = NOBLUDGEON
	/// Drop charges remaining before the beacon burns out
	var/uses_left = FREIGHT_BEACON_USES
	/// Reentrancy guard: one order flow at a time
	var/ordering = FALSE

/obj/item/freight_beacon/examine(mob/user)
	. = ..()
	. += span_notice("It has [uses_left] drop charge\s remaining. Use it in hand to order off Halcyon's core shelf.")

/obj/item/freight_beacon/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!isliving(user))
		return
	if(ordering)
		balloon_alert(user, "already ordering!")
		return TRUE
	// The list prompt and the confirm both sleep; don't hold the click chain
	INVOKE_ASYNC(src, PROC_REF(open_freight_menu), user)
	return TRUE

/// Order validity between the sleeping prompts: alive, still holding the beacon
/obj/item/freight_beacon/proc/freight_user_check(mob/living/user)
	// The 2026 upstream merge deleted IS_DEAD_OR_INCAP(); this is its old body.
	if(!istype(user) || user.incapacitated || user.stat)
		return FALSE
	if(loc != user)
		return FALSE
	return TRUE

/obj/item/freight_beacon/proc/open_freight_menu(mob/living/user)
	ordering = TRUE
	run_freight_order(user)
	ordering = FALSE

/**
 * The whole order flow: resolve Halcyon, list the eligible shelf, confirm,
 * charge like the counter, then schedule the drop.
 */
/obj/item/freight_beacon/proc/run_freight_order(mob/living/user)
	var/obj/structure/overmap/trader_outpost/outpost = get_general_trader_outpost()
	if(!outpost?.shop)
		to_chat(user, span_warning("The beacon pings for Waystation Halcyon and gets no answer. There's no general outpost on the lanes this shift."))
		return
	if(outpost.is_user_barred(user))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		to_chat(user, span_warning("Halcyon's stockroom refuses the order: your crew is under trade embargo."))
		return

	var/datum/outpost_shop/shop = outpost.shop
	// The core shelf, plain credit-priced goods only. Vouchers never spend
	// remotely, and the intel/registry lines have counter-only purchase flows
	// (a rumor charts the buyer's helm, a deed binds to the buyer's name) that
	// a pod can't reproduce.
	var/list/entries = list()
	var/list/lookup = list()
	for(var/datum/shop_sku/sku as anything in shop.skus)
		if(QDELETED(sku) || sku.shelf != SHELF_CORE)
			continue
		if(sku.price_vouchers != 0 || sku.price_credits <= 0)
			continue
		if(sku.is_chart || istype(sku, /datum/shop_sku/barter) || istype(sku, /datum/shop_sku/outpost_deed))
			continue
		if(!sku.item_path || sku.stock <= 0)
			continue
		var/entry = "[sku.name]: [sku.get_credit_price(user)] cr ([sku.stock] in stock)"
		entries += entry
		lookup[entry] = sku
	if(!length(entries))
		to_chat(user, span_warning("Halcyon's core shelf is picked clean. Wait for the supply convoy."))
		return

	var/choice = tgui_input_list(user, "Halcyon core shelf, shelf price, delivered by drop pod. [uses_left] charge\s left.", name, entries)
	if(!choice || !freight_user_check(user))
		return
	var/datum/shop_sku/sku = lookup[choice]
	if(QDELETED(sku) || QDELETED(outpost))
		return

	var/confirm = tgui_alert(user, "Order [sku.name] for [sku.get_credit_price(user)] cr? The pod drops on the beacon's position in about [FREIGHT_BEACON_DELAY / 10] seconds.", name, list("Order", "Cancel"))
	if(confirm != "Order" || !freight_user_check(user) || QDELETED(sku) || QDELETED(outpost))
		return
	// The prompts sleep; re-check everything the counter would
	if(outpost.is_user_barred(user))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		to_chat(user, span_warning("Halcyon's stockroom refuses the order: your crew is under trade embargo."))
		return
	if(uses_left <= 0)
		return
	var/denial = sku.get_denial_reason(user)
	if(denial)
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
		to_chat(user, span_warning(denial))
		return

	// Charge exactly like the counter (try_purchase minus the over-the-counter
	// dispense): validate the account, take the money, decrement shared stock.
	// Favor discounts apply through get_credit_price(user), same as the shelf.
	var/credit_price = sku.get_credit_price(user)
	var/datum/bank_account/account
	if(credit_price > 0)
		account = sku.get_account(user)
		if(!account || !account.has_money(credit_price))
			to_chat(user, span_warning("Insufficient credits ([credit_price] cr needed)."))
			return
		if(!account.adjust_money(-credit_price, "Trader Outpost: [sku.name]"))
			to_chat(user, span_warning("The payment bounced."))
			return
	sku.stock--
	uses_left--

	playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	to_chat(user, span_notice("Order confirmed: [sku.name]. Supply pod inbound to the beacon's position."))
	balloon_alert(user, "pod inbound!")
	// A global-proc callback, so a spent (deleted) beacon can't strand a paid
	// order. The fallback turf is where the order was placed.
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(halcyon_freight_drop), WEAKREF(src), get_turf(user), sku.item_path, sku.dispense_amount), FREIGHT_BEACON_DELAY)

	if(uses_left <= 0)
		to_chat(user, span_warning("That was [src]'s last drop charge. The transmitter burns out and the casing comes apart in your hand."))
		qdel(src)

/**
 * Delivers a paid freight order: launches a standard cargo pod (no explosion,
 * pod cleans itself up after opening) carrying the goods. Lands on the
 * beacon's current turf so a planted beacon marks the drop point, falling
 * back to where the order was placed if the beacon is gone.
 */
/proc/halcyon_freight_drop(datum/weakref/beacon_ref, turf/fallback_turf, item_path, dispense_amount = 1)
	var/obj/item/freight_beacon/beacon = beacon_ref?.resolve()
	var/turf/landing
	if(beacon && !QDELETED(beacon))
		landing = get_turf(beacon)
	if(!landing)
		landing = fallback_turf
	if(!landing || !ispath(item_path))
		return
	var/obj/structure/closet/supplypod/pod = podspawn(list(
		"target" = landing,
	))
	// Stacks carry their bundled count, matching what the shelf sells
	if(dispense_amount > 1 && ispath(item_path, /obj/item/stack))
		new item_path(pod, dispense_amount)
	else
		new item_path(pod)

#undef CONTRACT_PAD_COOLDOWN
#undef FREIGHT_BEACON_USES
#undef FREIGHT_BEACON_DELAY
