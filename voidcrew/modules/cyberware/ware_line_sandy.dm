/**
 * # The Cascade line: street and service-grade reflex rigs
 *
 * Two cheaper ways into the chest OS slot's speed core, both subtypes of the
 * Cascade Lattice (ware_legend.dm) so they share its slot, its EMP rule, its
 * crash-on-removal rule and its window code. Installing any of the three
 * evicts the other two, and the Redline family sits in the same slot, so a
 * crew climbs this ladder by swapping in the next rung.
 *
 * Each rung trades window strength for a worse bill: the lower the model, the
 * slower the gait, the thinner the dodge and the melee boost, and the longer
 * and nastier the crash. Window length stays nearly flat. The telegraphs are
 * the same at every rung (the activation, the afterimages, the crash), just
 * duller and sparser on the cheap chrome.
 *
 *   model        window  gait   dodge  crit  melee  crash  stamina  cooldown  load
 *   street       6 s     -0.5   30     +9    x0.75  8 s    90       120 s     6
 *   service      7 s     -0.75  45     +14   x0.6   7 s    90       90 s      9
 *   Cascade T4   8 s     -1     60     +18   x0.5   6 s    80       60 s      12
 *
 * The dodge covers ranged fire while moving and blows whether moving or not
 * (the shared arbiter in ware_pro_combat.dm). The crit column is added to the
 * aimed-crit roll of the bearer's own hits (crit_roll.dm): on a 25+ damage
 * hit's 1 to 90 roll that is about +10, +15 and +20 points of chance.
 *
 * Sold at Splice's counter. The street model is credits, behind the yellow
 * step, and trades in at the Intake ledger; the service model is vouchers
 * behind the advanced step.
 */

// =========================================================================
// STREET MODEL (T2)
// =========================================================================

/obj/item/organ/cyberimp/cyberware/cascade/street
	name = "spliced reflex rig"
	desc = "A spinal reflex rig cobbled together from salvaged parts and a lot of tape. The scorch marks came with it."
	icon_state = "cascade_street"
	chrome_load = 6
	tier = CYBERWARE_TIER_2
	aug_overlay = "cascade_street"
	actions_types = list(/datum/action/cooldown/cyberware/cascade_surge/street)
	window_duration = 6 SECONDS
	crash_duration = 8 SECONDS
	crash_stamina = 90
	window_dodge = 30
	window_crit_bonus = 9
	window_speed = /datum/movespeed_modifier/cyberware_cascade/street
	window_melee_mult = 0.75
	window_colour = /datum/client_colour/cyberware_cascade/street
	afterimage_interval = 3
	afterimage_alpha = 120
	window_alert = /atom/movable/screen/alert/status_effect/cyberware_cascade/aftermarket
	online_message = "REFLEX RIG ONLINE."
	dilation_freeze = 0
	dilation_time = 2 SECONDS
	dilation_scale = 0.5
	time_multiplier = 2

/datum/action/cooldown/cyberware/cascade_surge/street
	name = "Reflex Surge"
	desc = "Six seconds of speed: melee cooldowns cut by a quarter, hits land harder, and a 30% chance to dodge blows, or ranged fire on the move. Then eight seconds of crash."
	cooldown_time = 120 SECONDS

/datum/movespeed_modifier/cyberware_cascade/street
	multiplicative_slowdown = -0.5

/// The street rig's screen: the lattice's tint, a quarter as strong.
/datum/client_colour/cyberware_cascade/street
	color = list(1.025, 0, 0.02, 0.0125, 1.0125, 0.025, 0.025, 0, 1.05)

// =========================================================================
// SERVICE MODEL (T3)
// =========================================================================

/obj/item/organ/cyberimp/cyberware/cascade/milspec
	name = "service reflex lattice"
	desc = "A decommissioned military reflex lattice. The serial plate has been ground off, but the stencilling on the casing is still there."
	icon_state = "cascade_milspec"
	chrome_load = 9
	tier = CYBERWARE_TIER_3
	aug_overlay = "cascade_milspec"
	actions_types = list(/datum/action/cooldown/cyberware/cascade_surge/milspec)
	window_duration = 7 SECONDS
	crash_duration = 7 SECONDS
	crash_stamina = 90
	window_dodge = 45
	window_crit_bonus = 14
	window_speed = /datum/movespeed_modifier/cyberware_cascade/milspec
	window_melee_mult = 0.6
	window_colour = /datum/client_colour/cyberware_cascade/milspec
	afterimage_interval = 2
	afterimage_alpha = 160
	window_alert = /atom/movable/screen/alert/status_effect/cyberware_cascade/aftermarket
	online_message = "LATTICE ONLINE."
	dilation_freeze = 0
	dilation_time = 3 SECONDS
	dilation_scale = 0.35
	time_multiplier = 1 / 0.35

/datum/action/cooldown/cyberware/cascade_surge/milspec
	name = "Reflex Surge"
	desc = "Seven seconds of speed: melee cooldowns cut by 40%, hits land harder, and a 45% chance to dodge blows, or ranged fire on the move. Then seven seconds of crash."
	cooldown_time = 90 SECONDS

/datum/movespeed_modifier/cyberware_cascade/milspec
	multiplicative_slowdown = -0.75

/// The service lattice's screen: the lattice's tint, half as strong.
/datum/client_colour/cyberware_cascade/milspec
	color = list(1.05, 0, 0.04, 0.025, 1.025, 0.05, 0.05, 0, 1.1)

// =========================================================================
// SPLICE SKUs and INTAKE LEDGER
// The lead wires these into /datum/outpost_shop/vendor/ripperdoc (sku_types,
// buyback_types) and the zone loot tables at integration.
// =========================================================================

/datum/shop_sku/ripperdoc/cascade_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/cascade/street
	price_credits = 3600

/datum/shop_sku/ripperdoc/cascade_milspec
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/cascade/milspec
	price_vouchers = 4

/// Half list, credits only, like the rest of the ladder's street rungs.
/datum/shop_buyback/ripperdoc/cascade_street
	name = "Spliced Reflex Rig (pulled)"
	desc = "A taped-together spinal rig. Splice strips it for parts toward a proper lattice."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/cascade/street
	match_subtypes = FALSE
	pay_credits = 1800
	demand_min = 1
	demand_max = 2
