/**
 * # Shop Buyback: the wanted ledger
 *
 * The sell-to-trader side of an outpost shop: one entry per thing the trader
 * is buying this round. Deliberately SKU-adjacent rather than a SKU subtype.
 * Pricing runs the other direction (the trader pays out), and stock becomes
 * *demand* (how many sales the trader still wants this round).
 *
 * Selling accepts goods from anywhere in the seller's inventory (hands first),
 * one sale-unit per click or in bulk. Credits land on your ID's account;
 * voucher payouts materialize in hand.
 *
 * Balance rule: entries that pay VOUCHERS must only ever buy loot that can't
 * be manufactured aboard a ship (planet minerals, fauna harvests, ruin finds).
 * Vouchers are the currency that can't be farmed safely, and a lathe-printable
 * buyback would break that in one shift.
 */
/datum/shop_buyback
	/// Display name of what the trader wants (defaults to the item's name)
	var/name
	/// Display description / sourcing note (defaults to the item's desc)
	var/desc
	/// The item type the trader buys
	var/obj/item/item_path
	/// UI grouping label ("Exotics", "Salvage", ...)
	var/category = "General"
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
	/// Remaining demand this round (shared between everyone selling here)
	var/demand = 0
	/// Author override when the item's initial icon renders wrong in the UI
	var/icon_override
	var/icon_state_override
	/// Cached base64 icon for the UI, computed once per instance
	var/cached_icon

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
 * Base64 sprite for the ledger UI, cached per instance.
 */
/datum/shop_buyback/proc/get_ui_icon()
	if(cached_icon)
		return cached_icon
	var/obj/item/cast = item_path
	var/icon_file = icon_override || (item_path ? initial(cast.icon) : null)
	if(!icon_file)
		return null
	var/state = icon_state_override || initial(cast.icon_state)
	cached_icon = icon2base64(icon(icon_file, state, SOUTH, frame = 1))
	return cached_icon

/**
 * Whether this item counts for this ledger entry.
 */
/datum/shop_buyback/proc/matches(obj/item/offered)
	if(match_subtypes ? !istype(offered, item_path) : offered.type != item_path)
		return FALSE
	// No selling the trader a projection of the goods
	if((offered.item_flags & ABSTRACT) || (offered.flags_1 & HOLOGRAM_1))
		return FALSE
	return TRUE

/**
 * A carried item that is a SUBTYPE of the wanted goods on an exact-type ledger
 * (match_subtypes = FALSE) - close enough to name in the refusal so the player
 * learns why their crystal/ore/pelt variant doesn't count. Null when the ledger
 * accepts subtypes or nothing close is carried.
 */
/datum/shop_buyback/proc/find_refused_variant(mob/living/user)
	if(match_subtypes || !item_path)
		return null
	for(var/obj/item/offered in user.get_all_contents())
		if(istype(offered, item_path) && offered.type != item_path)
			return offered
	return null

/**
 * Every matching item on the seller, held items first so a deliberate
 * hand-off is always the thing consumed first.
 *
 * Anything the seller is currently wearing is skipped. The contents sweep goes
 * through get_all_contents(), which reaches into worn slots as readily as into
 * a backpack, so without this a salvage ledger would quietly sell the armor off
 * the seller's own back, or the MODsuit they are standing in. Held items still
 * count (that hand-off is the whole gesture), and so does anything in a bag or
 * a pocket, because carrying it there is already a decision to bring it.
 */
/datum/shop_buyback/proc/find_offered_items(mob/living/user)
	var/list/found = list()
	for(var/obj/item/held in user.held_items)
		if(matches(held))
			found += held
	var/list/worn = user.get_equipped_items()
	for(var/obj/item/offered in user.get_all_contents())
		if((offered in found) || (offered in worn))
			continue
		if(matches(offered))
			found += offered
	return found

/**
 * How many sale-units the seller is carrying (stacks divide by `amount`).
 */
/datum/shop_buyback/proc/count_carried_units(mob/living/user)
	if(!istype(user))
		return 0
	var/units = 0
	if(ispath(item_path, /obj/item/stack))
		var/total = 0
		for(var/obj/item/stack/offered as anything in find_offered_items(user))
			total += offered.amount
		units = round(total / amount)
	else
		units = length(find_offered_items(user))
	return units

/**
 * Why the user can't sell right now, shown as a tooltip / chat line.
 */
/datum/shop_buyback/proc/get_denial_reason(mob/living/user)
	if(demand <= 0)
		return "Not buying any more this shift."
	if(count_carried_units(user) < 1)
		// Exact-type ledgers (match_subtypes = FALSE) refuse processed/lab-made
		// variants of the wanted goods. Without this, a player holding a refined
		// bluespace crystal at the "natural bluespace crystals" window just got
		// "carrying none of the goods" and read it as a bug (rounds 14/15).
		var/obj/item/near_miss = find_refused_variant(user)
		if(near_miss)
			return "Won't take [near_miss.name] - only [name], nothing processed or lab-made."
		return "Carrying none of the goods: [get_wanted_text()]."
	if(pay_credits > 0)
		var/obj/item/card/id/id_card = user.get_idcard(TRUE)
		if(!id_card?.registered_account)
			return "No bank account on your ID to pay into."
	return null

/**
 * Sells one sale-unit: validates, consumes the goods, decrements demand and
 * pays out over the counter. Returns TRUE on success.
 * * quiet - suppress the per-sale chat line (bulk mode prints its own total)
 */
/datum/shop_buyback/proc/try_sell(mob/living/user, mob/living/basic/outpost_trader/vendor, quiet = FALSE)
	if(demand <= 0)
		return FALSE

	// Credits need a live account before we consume anything
	var/datum/bank_account/account
	if(pay_credits > 0)
		var/obj/item/card/id/id_card = user.get_idcard(TRUE)
		account = id_card?.registered_account
		if(!account)
			return FALSE

	// Consume one sale-unit
	if(ispath(item_path, /obj/item/stack))
		var/remaining = amount
		for(var/obj/item/stack/offered as anything in find_offered_items(user))
			var/take = min(remaining, offered.amount)
			if(!offered.use(take))
				continue
			remaining -= take
			if(remaining <= 0)
				break
		if(remaining > 0) // couldn't cover a full unit; partial stacks were small, bail without pay
			return FALSE
	else
		var/list/found = find_offered_items(user)
		if(!length(found))
			return FALSE
		qdel(found[1])

	demand--

	// Pay out
	if(pay_credits > 0)
		account.adjust_money(pay_credits, "Trader Outpost: sold [name]")
	if(pay_vouchers > 0)
		var/atom/drop_loc = user.drop_location() || vendor?.drop_location()
		var/obj/item/stack/trade_voucher/payout = new(drop_loc, pay_vouchers)
		if(!user.put_in_hands(payout) && !quiet)
			to_chat(user, span_notice("Your voucher payout lands at your feet."))
	if(!quiet)
		to_chat(user, span_notice("Sold: [get_wanted_text()] ([get_payment_text()])."))
	return TRUE

/**
 * # Exotic gas buyback
 *
 * A ledger entry that buys gas rather than a specific item type: any carried
 * tank holding at least required_moles of gas_type counts. The tank is
 * consumed with its contents, so the gas actually leaves the economy.
 *
 * The intended source is deep-band nebula scooping (fill a tank off the
 * scooped pipenet at a connector port). The gases bought are the red-zone
 * nebula exotics, so the voucher payout is danger-gated by supply.
 */
/datum/shop_buyback/exotic_gas
	item_path = /obj/item/tank
	category = "Nebula Exotics"
	/// The /datum/gas typepath the tank must carry
	var/gas_type
	/// Minimum moles of that gas in one tank for it to count as a sale-unit
	var/required_moles = 200

/datum/shop_buyback/exotic_gas/matches(obj/item/offered)
	if(!..())
		return FALSE
	var/obj/item/tank/tank = offered
	var/datum/gas_mixture/mix = tank.return_air()
	if(!mix || !(gas_type in mix.gases))
		return FALSE
	return mix.gases[gas_type][MOLES] >= required_moles

/datum/shop_buyback/exotic_gas/get_wanted_text()
	return "[name] ([required_moles]+ mol in one tank)"

/**
 * Sells as many sale-units as demand and the seller's carry allow.
 * Returns how many units were sold.
 */
/datum/shop_buyback/proc/try_sell_bulk(mob/living/user, mob/living/basic/outpost_trader/vendor)
	var/sold = 0
	var/safety = 50
	while(demand > 0 && safety-- > 0)
		if(!try_sell(user, vendor, quiet = TRUE))
			break
		sold++
	if(sold > 0)
		var/list/payout = list()
		if(pay_vouchers > 0)
			payout += "[pay_vouchers * sold] voucher[pay_vouchers * sold > 1 ? "s" : ""]"
		if(pay_credits > 0)
			payout += "[pay_credits * sold] cr"
		to_chat(user, span_notice("Sold [sold]x [get_wanted_text()] ([payout.Join(" + ")])."))
	return sold
