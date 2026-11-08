/**
 * # The Governor line
 *
 * Two cheaper rungs under Governor Delete (ware_legend.dm), so a crew can buy
 * a little headroom early and climb to the real thing. All three sit in the
 * chest OS slot, so fitting one evicts another, and they evict Cascade and
 * Redline too: the cost of headroom is the operating-system slot, same as the
 * parent. Load is 0 on every rung.
 *
 * The parent already reads its bonus from `chrome_capacity_bonus`, so the
 * rungs only retune that var and `tier`; there is no behaviour of their own.
 * Delete has no downside beyond the slot, so there is none to scale down.
 *
 * Swapping down is safe by construction. The install gate nets the evicted
 * governor's bonus out (installed_capacity_check), so a swap that would leave
 * the body over its new ceiling is refused up front with the incumbent still
 * online. Pulling a governor out is never blocked: whatever is then over the
 * ceiling browns out until load drops, like any other capacity loss.
 *
 * Rung      bonus   limit   load   tier
 * Patch       +5     25      0     T2   (street, sold for credits)
 * Bypass     +10     30      0     T3   (military, sold for vouchers)
 * Delete     +15     35      0     T4   (ware_legend.dm)
 */

/// T2: a hand-fitted patch over the limiter instead of a clean removal.
/obj/item/organ/cyberimp/cyberware/governor_delete/street
	name = "\improper Governor Patch"
	desc = "A neural governor with the limiter taped over rather than removed. The tape has seen some things."
	icon_state = "governor_delete_street"
	chrome_load = 0
	chrome_capacity_bonus = 5
	tier = CYBERWARE_TIER_2

/// T3: the limiter jumpered out of the circuit, surplus-grade work.
/obj/item/organ/cyberimp/cyberware/governor_delete/milspec
	name = "\improper Governor Bypass"
	desc = "A neural governor with its limiter jumpered out of the circuit. The surplus stencil is still on the casing."
	icon_state = "governor_delete_milspec"
	chrome_load = 0
	chrome_capacity_bonus = 10
	tier = CYBERWARE_TIER_3

// =========================================================================
// SPLICE SKUS: not listed on any vendor yet, the integration pass adds them
// to the Chop Shop's sku_types (and the street doc's, for the Patch).
// =========================================================================

/datum/shop_sku/ripperdoc/governor_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/governor_delete/street
	price_credits = 2500

/datum/shop_sku/ripperdoc/governor_milspec
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/governor_delete/milspec
	price_vouchers = 3

// =========================================================================
// TRADE-IN: the Patch is the rung a customer outgrows, half list in credits.
// Not listed on any buyback_types yet, same integration pass as above. The
// Bypass costs vouchers, which can't be refunded, so it has no entry.
// =========================================================================

/datum/shop_buyback/ripperdoc/governor_street
	name = "Governor Patch (pulled)"
	desc = "A taped-over governor, pulled. Credit toward a cleaner cut."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/governor_delete/street
	match_subtypes = FALSE
	pay_credits = 1250
	demand_min = 1
	demand_max = 2
