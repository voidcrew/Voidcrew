/**
 * # Cheaper and harder models of six wares
 *
 * Seven new models, each a subtype of the ware it sits under in the same slot,
 * so fitting one evicts the other. The parent's tuning lives in vars (the Hopper
 * leap, the Gorilla punches, the Fixer's tool-speed modifier), and a model
 * retunes by setting them.
 *
 *   model               parent           tier  load       price               where
 *   Spring calves       Hopper pistons   T1    2          1,800 cr            yellow
 *   Vaulter pistons     Hopper pistons   T3    4          3 vouchers          advanced
 *   Brawler myomers     Gorilla Arms     T2    2 per arm  2,400 cr the pair   yellow
 *   Tinker's fingers    Fixer's Fingers  T1    1          700 cr              public
 *   Deepcore drill fist Rockjaw          T2    3          2,400 cr            public
 *   Holdout housing     Popup Ronin      T2    3          2,400 cr            yellow
 *
 * Leg ladder: Shock Coils, Spring calves, Hopper, Vaulter, Meteor Piledriver.
 * The Vaulter carries the Coils' soft landing and dry footing, which the Hopper
 * itself never had, so stepping up to it costs no safety.
 *
 * Sold at Splice's counter, and the credit-priced ones at the street doc's.
 * The integration pass wires the SKUs and ledger entries below into the vendors
 * and the zone loot tables.
 */

// =========================================================================
// SPRING CALVES (street Hopper)
// =========================================================================

/**
 * # Spring calves (T1, legs, load 2)
 *
 * The cheap way into a jump: coil springs on the calves instead of pistons. A
 * short hop that takes a while to wind back up. Nothing else.
 */
/obj/item/organ/cyberimp/cyberware/hopper/street
	name = "\improper Spring calves"
	desc = "Industrial coil springs sleeved over both calves and bolted straight to the shin. They squeak."
	icon_state = "hopper_street"
	chrome_load = 2
	tier = CYBERWARE_TIER_1
	aug_overlay = "hopper_street"
	leap_range = 3
	leap_cooldown = 14 SECONDS
	leap_action_desc = "Leap up to three tiles over gaps, tables and people, onto any open floor you can see with a clear lane to it. Walls, windows and shut doors stop the jump."

// =========================================================================
// VAULTER PISTONS (milspec Hopper)
// =========================================================================

/**
 * # Vaulter pistons (T3, legs, load 4)
 *
 * Military leg pistons: a longer jump on a shorter clock, with shock plates
 * under the heel. Keeps the Shock Coils' soft landing and dry footing, minus the
 * Coils' knockdown and stun trims, which stay with the Coils.
 */
/obj/item/organ/cyberimp/cyberware/hopper/milspec
	name = "\improper Vaulter pistons"
	desc = "Decommissioned military leg pistons, shock-plated at the heel. Somebody ground the serial number off and left the warning stencil."
	icon_state = "hopper_milspec"
	chrome_load = 4
	tier = CYBERWARE_TIER_3
	aug_overlay = "hopper_milspec"
	organ_traits = list(TRAIT_NO_SLIP_WATER)
	leap_range = 5
	leap_cooldown = 6 SECONDS
	leap_action_desc = "Leap up to five tiles over gaps, tables and people, onto any open floor you can see with a clear lane to it. Walls, windows and shut doors stop the jump."

/obj/item/organ/cyberimp/cyberware/hopper/milspec/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_LIVING_Z_IMPACT, PROC_REF(on_z_impact))

/obj/item/organ/cyberimp/cyberware/hopper/milspec/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_LIVING_Z_IMPACT)

/// Signal proc for [COMSIG_LIVING_Z_IMPACT]: the Shock Coils' soft landing. Big
/// multi-level drops still stagger.
/obj/item/organ/cyberimp/cyberware/hopper/milspec/proc/on_z_impact(datum/source, levels, turf/fell_on)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING)
		return NONE
	new /obj/effect/temp_visual/mook_dust(fell_on)
	cyberware_ink_pulse(owner, CYBERWARE_INK_SOFT)
	if(levels >= 2)
		owner.adjust_staggered_up_to(STAGGERED_SLOWDOWN_LENGTH * levels, 10 SECONDS)
	owner.visible_message(
		span_notice("[owner] lands on [fell_on] with a piston hiss."),
		span_notice("Your heel plates soak up the impact."),
	)
	return ZIMPACT_CANCEL_DAMAGE | ZIMPACT_NO_MESSAGE | ZIMPACT_NO_SPIN

// =========================================================================
// BRAWLER MYOMERS (street Gorilla Arms)
// =========================================================================

/**
 * # Brawler myomers (T2, arms, arm hardware slots, load 2 per arm / 4 the pair)
 *
 * Gorilla Arms bought cheap: lighter punches, slower, a lighter smash on
 * structures. Rock still breaks, and a grabbed victim takes the ordinary slam,
 * not a throw across the room. The pair never pries a door: the set bonus is
 * never attached, so even one of these beside a real Gorilla arm gets nothing.
 */
/obj/item/organ/cyberimp/cyberware/gorilla_arms/street
	name = "\improper Brawler myomers (right)"
	desc = "Off-the-shelf myomer strips grafted along the forearm. You don't look any stronger for it. You just stop losing arm wrestles."
	icon_state = "gorilla_street"
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	aug_overlay = "gorilla_street_right"
	punch_damage = 14
	structure_damage = 20
	punch_cooldown_time = 6 SECONDS
	smash_cooldown_time = 1.5 SECONDS
	hurl_range = 0
	pries_doors = FALSE

/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left
	name = "\improper Brawler myomers (left)"
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG
	aug_overlay = "gorilla_street_left"

/obj/item/cyberware_pair_case/gorilla_arms/street
	name = "\improper Brawler myomers case"
	desc = "A scuffed clamshell case with two bundles of myomer strips zip-tied into the foam."
	ware_types = list(
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/street,
		/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left,
	)

// =========================================================================
// TINKER'S FINGERS (street Fixer's Fingers)
// =========================================================================

/// Tinker's fingers' servo speed-up: a tenth off every timed action, to the
/// Fixer's quarter. Its own key, so it never replaces the Fixer's.
/datum/actionspeed_modifier/cyberware_fixers/street
	multiplicative_slowdown = -0.1

/**
 * # Tinker's fingers (T1, arm aug, load 1)
 *
 * The same three tools in the knuckles and cheaper servos behind them. A green
 * crew's way into the arm slot the Fixer's Fingers hold at yellow.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/street
	name = "\improper Tinker's fingers"
	desc = "A fingertip tool suite in a housing that has been opened and closed more times than the warranty allows. Driver, wrench and cutters, all slightly loose."
	icon_state = "fixers_street"
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	speed_modifier = /datum/actionspeed_modifier/cyberware_fixers/street

// =========================================================================
// DEEPCORE DRILL FIST (heavy Rockjaw)
// =========================================================================

/// The Deepcore's drill: between the Rockjaw's drill (0.5) and the diamond
/// drill (0.2).
/obj/item/pickaxe/drill/cyberware/deepcore
	name = "deepcore drill"
	desc = "A long drill bit with a diamond collar, wired straight into the forearm. It isn't coming off without a surgeon."
	toolspeed = 0.3

/**
 * # Deepcore drill fist (T2, arm aug, load 3)
 *
 * The Rockjaw with a heavier drill on the arm. The ore hopper and its button
 * are the Rockjaw's own.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/deepcore
	name = "\improper Deepcore drill fist"
	desc = "A heavy drill folded into the forearm, built for rock the usual drills give up on."
	icon_state = "rockjaw_deepcore"
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	items_to_create = list(/obj/item/pickaxe/drill/cyberware/deepcore)

// =========================================================================
// HOLDOUT HOUSING (street Popup Ronin)
// =========================================================================

/**
 * The holdout's cylinder: six chambers of ordinary .38, thumbed in one round at
 * a time. A speedloader feeds it a round per click, not the whole cylinder.
 */
/obj/item/ammo_box/magazine/internal/cylinder/rev38/cyberware_holdout
	name = "holdout cylinder"
	multiload = FALSE

/**
 * The gun the housing unfolds: a snub-nosed revolver on the stock chassis. NODROP
 * while deployed comes from the toolkit Extend, so it can't be disarmed; Retract
 * and EMP stow it. It leaves the shop loaded, and every reload after that is by
 * hand, round by round.
 */
/obj/item/gun/ballistic/revolver/cyberware_holdout
	name = "holdout revolver"
	desc = "A snub-nosed revolver small enough to fold into a forearm. Uses .38 Special rounds."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_weapons.dmi'
	icon_state = "ronin_holdout"
	inhand_icon_state = "ronin_holdout"
	lefthand_file = 'voidcrew/modules/cyberware/icons/cyberware_lefthand.dmi'
	righthand_file = 'voidcrew/modules/cyberware/icons/cyberware_righthand.dmi'
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/cylinder/rev38/cyberware_holdout
	fire_sound = 'sound/items/weapons/gun/revolver/shot.ogg'
	fire_delay = 0.4 SECONDS
	/// How long each round takes to thumb into the cylinder.
	var/reload_time = 1 SECONDS

/// TRUE when a chamber is empty or holds a spent casing, so a round can go in.
/obj/item/gun/ballistic/revolver/cyberware_holdout/proc/cylinder_has_room()
	if(!magazine)
		return FALSE
	for(var/slot in magazine.stored_ammo)
		if(isnull(slot))
			return TRUE
		// A path is a round the cylinder hasn't spawned yet, which is a live one.
		if(!istype(slot, /obj/item/ammo_casing))
			continue
		var/obj/item/ammo_casing/casing = slot
		if(!casing.loaded_projectile)
			return TRUE
	return FALSE

// Thumbing a round in takes a moment. A full cylinder is refused without a wait.
/obj/item/gun/ballistic/revolver/cyberware_holdout/load_gun(obj/item/ammo, mob/living/user)
	if(user && cylinder_has_room() && !do_after(user, reload_time, target = src))
		return FALSE
	return ..()

/**
 * # Holdout housing (T2, one arm, aug slot, load 3)
 *
 * A fold-out forearm revolver for the yellow zone: six shots of ordinary .38,
 * loaded by hand. Anyone who looks at the bearer sees the housing in the arm.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout
	name = "\improper Holdout housing"
	desc = "A forearm housing with a snub-nosed revolver folded inside. Not much to look at, which is the idea."
	icon_state = "ronin_holdout"
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	aug_overlay = "ronin_holdout"
	items_to_create = list(/obj/item/gun/ballistic/revolver/cyberware_holdout)

/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout/on_mob_insert(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(arm_owner, COMSIG_ATOM_EXAMINE, PROC_REF(on_owner_examined))

/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout/on_mob_remove(mob/living/carbon/arm_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(arm_owner, COMSIG_ATOM_EXAMINE)

/// Signal proc for [COMSIG_ATOM_EXAMINE] on the bearer: the housing shows in the
/// arm to anyone who looks, suit or no suit.
/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout/proc/on_owner_examined(mob/living/carbon/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_notice("[source.p_They()] [source.p_have()] a revolver housing set into [source.p_their()] [parse_zone(zone)].")

// =========================================================================
// SPLICE SKUS: on the Chop Shop's sku_types (ripperdoc_catalog.dm), and the
// credit-priced ones on the Back Bay's too (street_doc_catalog.dm).
// =========================================================================

/datum/shop_sku/ripperdoc/hopper_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/hopper/street
	price_credits = 1800

/datum/shop_sku/ripperdoc/hopper_milspec
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/hopper/milspec
	price_vouchers = 3

/datum/shop_sku/ripperdoc/gorilla_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	name = "Brawler Myomers (pair)"
	desc = "A cased pair of cheap myomer forearms."
	item_path = /obj/item/cyberware_pair_case/gorilla_arms/street
	price_credits = 2400
	stock_min = 1
	stock_max = 2
	fixed_price = TRUE
	contract_reward = FALSE

/datum/shop_sku/ripperdoc/fixers_street
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/street
	price_credits = 700

/datum/shop_sku/ripperdoc/rockjaw_deepcore
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/deepcore
	price_credits = 2400

/datum/shop_sku/ripperdoc/ronin_holdout
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	desc = "A snub-nosed revolver folded into a chrome forearm."
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout
	price_credits = 2400
	stock_min = 1
	stock_max = 2
	fixed_price = TRUE
	contract_reward = FALSE

// =========================================================================
// INTAKE LEDGERS: half the shelf price, credits only, like the other street
// rungs. The Vaulter costs vouchers, which can't be refunded, so it has no
// entry. Ratchet's subtypes carry his wording and are listed beside Splice's.
// =========================================================================

/datum/shop_buyback/ripperdoc/hopper_street
	name = "Spring calves (pulled)"
	desc = "Used calf springs. They squeak."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/hopper/street
	match_subtypes = FALSE
	pay_credits = 900
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/hopper_street/street_doc
	desc = "A used pair of calf springs."

/datum/shop_buyback/ripperdoc/gorilla_street
	name = "Brawler myomers (pulled)"
	desc = "One myomer arm, either side."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/gorilla_arms/street
	match_subtypes = TRUE
	pay_credits = 600
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/ripperdoc/gorilla_street/street_doc
	desc = "One used myomer arm, either side."

/datum/shop_buyback/ripperdoc/fixers_street
	name = "Tinker's fingers (pulled)"
	desc = "A used fingertip tool suite."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/fixers/street
	match_subtypes = FALSE
	pay_credits = 350
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/fixers_street/street_doc
	desc = "A used set of fingertip tools, a bit loose."

/datum/shop_buyback/ripperdoc/rockjaw_deepcore
	name = "Deepcore drill fist (pulled)"
	desc = "A used drill fist. The bit's still sharp."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw/deepcore
	match_subtypes = FALSE
	pay_credits = 1200
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/rockjaw_deepcore/street_doc
	desc = "A used drill fist, ore hopper and all."

/datum/shop_buyback/ripperdoc/ronin_holdout
	name = "Holdout housing (pulled)"
	desc = "A used revolver housing."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin/holdout
	match_subtypes = FALSE
	pay_credits = 1200
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/ronin_holdout/street_doc
	desc = "A used revolver housing, cylinder and all."
