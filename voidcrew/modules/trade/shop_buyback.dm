/**
 * # Shop Buyback
 *
 * The sell-to-trader side of an outpost shop: one entry per thing the trader
 * is buying this round. Deliberately SKU-adjacent rather than a SKU subtype —
 * pricing runs the other direction (the trader pays out), and stock becomes
 * *demand* (how many the trader still wants this round).
 *
 * Same stateless payment philosophy as the buy side: hold the goods in hand,
 * click sell. Credits land on your ID's account; voucher payouts materialize
 * as a voucher stack in your hand.
 *
 * Balance note: entries that pay VOUCHERS must only ever buy loot that can't
 * be manufactured aboard a ship (mined ore, ruin finds) — vouchers are the
 * currency that can't be farmed safely, and a lathe-printable buyback would
 * break that in one shift.
 */
/datum/shop_buyback
	/// Display name of what the trader wants (defaults to the item's name)
	var/name
	/// Display description / sourcing note (defaults to the item's desc)
	var/desc
	/// The item type the trader buys
	var/obj/item/item_path
	/// Whether subtypes of item_path are accepted (turn off when a subtype is farmable)
	var/match_subtypes = TRUE
	/// Units consumed per sale (only meaningful for stack types)
	var/amount = 1
	/// Payout in credits (0 = none)
	var/pay_credits = 0
	/// Payout in trade vouchers (0 = none)
	var/pay_vouchers = 0
	/// Per-round demand roll bounds (how many sales the trader will take)
	var/demand_min = 2
	var/demand_max = 4
	/// Remaining demand this round (shared between the outpost's terminals)
	var/demand = 0

/datum/shop_buyback/New()
	..()
	demand = rand(demand_min, demand_max)
	if(item_path)
		var/obj/item/cast = item_path
		if(!name)
			name = initial(cast.name)
		if(!desc)
			desc = initial(cast.desc)

/**
 * Human-readable payout tag, e.g. "pays 2 vouchers" / "pays 300 cr".
 */
/datum/shop_buyback/proc/get_payment_text()
	var/list/parts = list()
	if(pay_vouchers > 0)
		parts += "[pay_vouchers] voucher[pay_vouchers > 1 ? "s" : ""]"
	if(pay_credits > 0)
		parts += "[pay_credits] cr"
	if(!length(parts))
		return "pays nothing"
	return "pays [parts.Join(" + ")]"

/**
 * What the trader is asking for, e.g. "10x plasma ore".
 */
/datum/shop_buyback/proc/get_wanted_text()
	if(amount > 1)
		return "[amount]x [name]"
	return name

/**
 * Finds a matching item in the seller's hands, or null.
 */
/datum/shop_buyback/proc/find_offered_item(mob/living/user)
	for(var/obj/item/offered in user.held_items)
		if(match_subtypes ? !istype(offered, item_path) : offered.type != item_path)
			continue
		// No selling the trader a projection of the goods
		if((offered.item_flags & ABSTRACT) || (offered.flags_1 & HOLOGRAM_1))
			continue
		if(isstack(offered))
			var/obj/item/stack/offered_stack = offered
			if(offered_stack.amount < amount)
				continue
		return offered
	return null

/**
 * Why the user can't sell right now — shown as a tooltip / chat line.
 */
/datum/shop_buyback/proc/get_denial_reason(mob/living/user)
	if(demand <= 0)
		return "Not buying any more this shift."
	if(!find_offered_item(user))
		return "Hold the goods in hand: [get_wanted_text()]."
	if(pay_credits > 0)
		var/obj/item/card/id/id_card = user.get_idcard(TRUE)
		if(!id_card?.registered_account)
			return "No bank account on your ID to pay into."
	return null

/**
 * Attempts the sale: validates, consumes the goods, decrements demand and
 * pays out at the terminal. Returns TRUE on success.
 */
/datum/shop_buyback/proc/try_sell(mob/living/user, obj/machinery/computer/outpost_shop_terminal/terminal)
	if(demand <= 0)
		return FALSE
	var/obj/item/offered = find_offered_item(user)
	if(!offered)
		return FALSE

	// Credits need a live account before we consume anything
	var/datum/bank_account/account
	if(pay_credits > 0)
		var/obj/item/card/id/id_card = user.get_idcard(TRUE)
		account = id_card?.registered_account
		if(!account)
			return FALSE

	// Consume the goods
	if(isstack(offered))
		var/obj/item/stack/offered_stack = offered
		if(!offered_stack.use(amount))
			return FALSE
	else
		qdel(offered)

	demand--

	// Pay out
	if(pay_credits > 0)
		account.adjust_money(pay_credits, "Trader Outpost: sold [name]")
	if(pay_vouchers > 0)
		var/atom/drop_loc = terminal?.drop_location() || user.drop_location()
		var/obj/item/stack/trade_voucher/payout = new(drop_loc, pay_vouchers)
		if(user.put_in_hands(payout))
			to_chat(user, span_notice("You receive [pay_vouchers] trade voucher[pay_vouchers > 1 ? "s" : ""]."))
		else
			to_chat(user, span_notice("Your voucher payout lands at your feet."))
	to_chat(user, span_notice("Sold: [get_wanted_text()] ([get_payment_text()])."))
	return TRUE
