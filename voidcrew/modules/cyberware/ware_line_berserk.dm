/**
 * # The Berserk line: cheaper cores for the Redline slot
 *
 * Two earlier models of the Redline core. Same chest OS slot as the Redline
 * (and Cascade), so fitting one evicts the other. Same burn, retuned: every
 * number lives in a var on /obj/item/organ/cyberimp/cyberware/redline
 * (ware_legend.dm) and a model sets its own here.
 *
 * | | window | damage | punch | stun immune | roar | crash | cooldown | load |
 * |---|---|---|---|---|---|---|---|---|
 * | street | 8 s | x0.8 | +3 | no | none | 6 s | 120 s | 5 |
 * | milspec | 10 s | x0.7 | +5 | yes | 4 tiles | 5 s | 105 s | 8 |
 * | Redline | 12 s | x0.6 | +8 | yes | 5 tiles | 5 s | 90 s | 10 |
 *
 * The chest speaker announcement stays on every model: it is the telegraph.
 * The street core has no roar to follow it, so it announces and staggers
 * nobody. Crash stamina stays at the Redline's 100 on all three.
 */

/// Street: bench-built, sold for credits. Burns for less time, softens less and
/// does not hold off stuns.
/obj/item/organ/cyberimp/cyberware/redline/street
	name = "\improper Hothead core"
	desc = "A combat governor soldered together on a back-room bench out of parts from two others. The chest speaker rattles when it runs."
	icon_state = "redline_street"
	chrome_load = 5
	tier = CYBERWARE_TIER_2
	aug_overlay = "redline_street"
	burn_window = 8 SECONDS
	burn_damage_mult = 0.8
	burn_melee_bonus = 3
	burn_stun_immune = FALSE
	burn_roar_range = 0
	burn_crash = 6 SECONDS
	burn_cooldown = 120 SECONDS
	burn_action_desc = "Eight seconds of damage resistance and harder fists, announced by the chest speaker. Ends in a collapse."
	burn_alert_desc = "The safeties are loosened, not gone."

/// Milspec: surplus assault issue. Close to the Redline, a size smaller.
/obj/item/organ/cyberimp/cyberware/redline/milspec
	name = "\improper Vanguard core"
	desc = "A surplus assault governor, still stencilled with someone else's unit number. The chest speaker is military grade, which means loud."
	icon_state = "redline_milspec"
	chrome_load = 8
	tier = CYBERWARE_TIER_3
	aug_overlay = "redline_milspec"
	burn_window = 10 SECONDS
	burn_damage_mult = 0.7
	burn_melee_bonus = 5
	burn_stun_immune = TRUE
	burn_roar_range = 4
	burn_crash = 5 SECONDS
	burn_cooldown = 105 SECONDS
	burn_action_desc = "Ten seconds of stun immunity, 30% damage resistance and harder fists, opened with a staggering roar. Ends in a collapse."
	burn_alert_desc = "The safeties are off."

// =========================================================================
// SPLICE SKUs (wired into the vendors at integration, not here)
// =========================================================================

/datum/shop_sku/ripperdoc/redline_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/redline/street
	price_credits = 3000

/datum/shop_sku/ripperdoc/redline_milspec
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/redline/milspec
	price_vouchers = 4

// =========================================================================
// TRADE-IN: the street model only
// Half list, credits only, exact type. The milspec core is paid for in
// vouchers and is never bought back.
// =========================================================================

/datum/shop_buyback/ripperdoc/redline_street
	name = "Hothead Core (pulled)"
	desc = "A pulled rage governor, scorched where the safeties used to be."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/redline/street
	match_subtypes = FALSE
	pay_credits = 1500
	demand_min = 1
	demand_max = 2
