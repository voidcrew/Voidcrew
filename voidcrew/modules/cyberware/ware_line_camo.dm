/**
 * # Camo line: the street weave
 *
 * The cheap rung under the Ghostskin Weave (ware_military_body.dm), on the same
 * skin slot, so installing one evicts the other. It reuses the whole Ghostskin
 * field, signals, break triggers and all, and only retunes the vars the parent
 * exposes: a shorter, patchier fade that fools players and never mobs.
 *
 * This file is included BEFORE ware_military_body.dm, so it cannot use the
 * CYBERWARE_GHOSTSKIN_* defines (they are defined and #undef'd over there).
 * Every number below is a plain var override instead.
 *
 * What hides_from_mobs = FALSE buys, in practice: no TRAIT_CYBER_CAMO, so
 * cyberware_stealth.dm never refuses the bearer as a target (basic mobs,
 * simple_animal hostiles, turrets and the scripted hunters it names) and
 * cyberware_scan.dm never scatters a chrome read on them. All of it is keyed
 * on that one trait.
 */

/obj/item/organ/cyberimp/cyberware/ghostskin/street
	name = "\improper Flickerskin weave"
	desc = "A budget subdermal weave of refraction cells, mostly salvage. Switched on, you go blurry at the edges, which is not the same as gone."
	icon_state = "ghostskin_street"
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	actions_types = list(/datum/action/cooldown/cyberware/ghostskin_cloak/street)
	// Roughly half faded, never a heat-shimmer. Moving flares it well above that.
	field_alpha = 110
	ripple_alpha = 170
	field_duration = 5 SECONDS
	hides_from_mobs = FALSE

/obj/item/organ/cyberimp/cyberware/ghostskin/street/engage_feedback(mob/living/carbon/wearer)
	playsound(wearer, 'voidcrew/sound/machines/cloaking/on.ogg', 35, TRUE)
	wearer.visible_message(
		span_warning("[wearer] flickers and goes patchy!"),
		span_notice("The weave stutters on and smears the light around you. Not all of it."),
	)

/datum/action/cooldown/cyberware/ghostskin_cloak/street
	desc = "Five seconds of patchy optical camo, enough to fool people and not much else. Attacking, shooting, taking a hit or an EMP drops it."
	cooldown_time = 45 SECONDS

// =========================================================================
// SPLICE SKUS
// Not listed on any vendor from here: the lead adds the path to Splice's
// sku_types and to the street doc's, and the buyback to buyback_types.
// =========================================================================

/datum/shop_sku/ripperdoc/ghostskin_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/ghostskin/street
	price_credits = 2400
	stock_min = 1
	stock_max = 2

/// Trade-in at half list, credits only, like the other street rungs.
/datum/shop_buyback/ripperdoc/ghostskin_street
	name = "Flickerskin weave (pulled)"
	desc = "A patchy camo weave you've outgrown. Worth half toward the real thing."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/ghostskin/street
	pay_credits = 1200
	demand_min = 1
	demand_max = 2
