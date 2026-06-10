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
