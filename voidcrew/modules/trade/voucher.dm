/**
 * # Trade Voucher
 *
 * The currency that can't be farmed safely. Earned from ruin recovery missions
 * (and other dangerous content), never purchasable with credits, and spent at
 * trader outposts for high-tier goods. Vendor-agnostic: any trader honors it.
 *
 * Deliberately a physical item: stealable, ransomable, demandable as pirate
 * tribute. Stacks like cash.
 */
/obj/item/stack/trade_voucher
	name = "trade voucher"
	singular_name = "trade voucher"
	desc = "A tamper-sealed hard-light chit, exchangeable for restricted goods at any trader outpost. No credit value. No refunds."
	icon = 'voidcrew/icons/obj/vouchers.dmi'
	icon_state = "void-voucher"
	amount = 1
	max_amount = INFINITY
	merge_type = /obj/item/stack/trade_voucher
	w_class = WEIGHT_CLASS_TINY
	full_w_class = WEIGHT_CLASS_TINY
	throwforce = 0
	throw_speed = 2
	throw_range = 2

/obj/item/stack/trade_voucher/update_icon_state()
	. = ..()
	icon_state = amount > 1 ? "void-vouchers" : "void-voucher"

/**
 * Total trade vouchers anywhere in the mob's inventory, hands, bags, pockets.
 * Payment is stateless, but nobody enjoys fishing chits out of a backpack.
 */
/proc/count_trade_vouchers(mob/living/user)
	. = 0
	if(!istype(user))
		return
	for(var/obj/item/stack/trade_voucher/vouchers in user.get_all_contents())
		if((vouchers.item_flags & ABSTRACT) || (vouchers.flags_1 & HOLOGRAM_1))
			continue
		. += vouchers.amount

/**
 * Consumes `amount` vouchers from anywhere in the mob's inventory.
 * All-or-nothing: consumes none unless the full amount is covered.
 * Returns TRUE on success.
 */
/proc/consume_trade_vouchers(mob/living/user, amount)
	if(amount <= 0)
		return TRUE
	if(count_trade_vouchers(user) < amount)
		return FALSE
	var/remaining = amount
	for(var/obj/item/stack/trade_voucher/vouchers in user.get_all_contents())
		if((vouchers.item_flags & ABSTRACT) || (vouchers.flags_1 & HOLOGRAM_1))
			continue
		var/take = min(remaining, vouchers.amount)
		if(!vouchers.use(take))
			continue
		remaining -= take
		if(remaining <= 0)
			return TRUE
	// Shouldn't happen after the upfront count, but never eat a partial payment silently
	stack_trace("consume_trade_vouchers came up [remaining] short after a successful count")
	return FALSE
