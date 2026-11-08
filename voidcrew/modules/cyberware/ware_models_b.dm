/**
 * # Street and service models, set B
 *
 * Cheaper and sideways models of the plating, frame, seal, nervous and ear
 * wares. Every one is a subtype of the ware it undercuts and sits in the same
 * slot, so fitting one evicts the other. The parents keep their numbers; the
 * models only set the vars the parents expose.
 *
 *   model               parent          slot     load  tier  sold for
 *   Hardweave plating   Dermal Mesh     dermal   3     T2    3,000 cr   (yellow)
 *   Strut frame         Atlas Frame     frame    2     T2    1,500 cr   (yellow)
 *   Deep-lung bladder   Second Wind     seal     2     T2    1,800 cr
 *   Heat-sink lining    Coolant Loops   seal     1     T1    1,500 cr
 *   Frostline lining    (new)           seal     1     T1    1,500 cr
 *   Twitchwire          Slipwire        nervous  2     T1    1,800 cr   (yellow)
 *   Weaver shunt        Slipwire        nervous  5     T3    3 vouchers (advanced)
 *   Thumper ear         Heartbeat Dop.  ears     1     T1    1,500 cr   (yellow)
 *
 * The seal slot now holds five choices (Second Wind, Deep-lung, Heat-sink,
 * Frostline, Coolant). It stays a single slot, so none of them combine: an
 * air bladder and a cold lining never share a body.
 *
 * Dodge goes through the shared arbiter (ware_pro_combat.dm), which rolls the
 * single highest live source, so the Twitchwire and the Weaver shunt can never
 * stack with a Cascade window or each other.
 *
 * Splice's shelf, the street doc's shelf, and the zone loot tables are wired
 * in the integration pass, not here. The SKUs and ledger entries below exist
 * so the cradle can quote a price and so that pass has something to list.
 */

// =========================================================================
// HARDWEAVE PLATING (T2): the middle of the dermal ladder
// =========================================================================

/// Between the Mesh and the Slabskin Plate: more of the same, none of the
/// plate's bomb, fire and acid cover.
/datum/armor/cyberware_hardweave
	melee = 20
	bullet = 20
	laser = 15
	energy = 10
	wound = 10

/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave
	name = "\improper Hardweave plating"
	desc = "Layered polymer weave sewn in under the skin, a size up from the usual mesh. The scarring is the part nobody mentions."
	icon_state = "dermal_mesh_hardweave"
	aug_overlay = "dermal_mesh_hardweave"
	chrome_load = 3
	tier = CYBERWARE_TIER_2
	mesh_armor = /datum/armor/cyberware_hardweave

// =========================================================================
// STRUT FRAME (T2): the bones and nothing else
// =========================================================================

/obj/item/organ/cyberimp/cyberware/atlas/street
	name = "\improper Strut frame"
	desc = "Steel struts bolted along the long bones. It holds you together and has no opinion about the rest."
	icon_state = "atlas_street"
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	// Bones only: limbs can still come off, throws are plain, and a shove
	// carries you as far as it carries anyone.
	organ_traits = list(TRAIT_CYBERWARE_UNBREAKABLE_BONES)
	throw_range_bonus = 0
	throw_speed_bonus = 0
	resists_knockback = FALSE
	frame_examine = null

// =========================================================================
// DEEP-LUNG BLADDER (T2): a longer breath
// =========================================================================

/obj/item/organ/cyberimp/cyberware/second_wind/deep
	name = "\improper Deep-lung bladder"
	desc = "An oversized air bladder packed in around the ribs, for people who spend their shifts on the wrong side of an airlock."
	icon_state = "second_wind_deep"
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	reserve = 360 SECONDS
	max_reserve = 360 SECONDS
	refill_rate = 24 SECONDS

// =========================================================================
// HEAT-SINK LINING (T1): the heat half of Coolant Loops
// =========================================================================

/obj/item/organ/cyberimp/cyberware/coolant/street
	name = "\improper Heat-sink lining"
	desc = "A lining of finned aluminium stitched in under the ribs, so the heat has somewhere to go. It ticks as it cools."
	icon_state = "coolant_street"
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	// Heat exposure and the fire scrub stay; burns land at full strength.
	burn_mult = 1

// =========================================================================
// FROSTLINE LINING (T1): the cold twin
// =========================================================================

/**
 * # Frostline lining (T1, chest, seal slot, load 1)
 *
 * The mirror of the Coolant Loops' heat immunity: the cold stops hurting and
 * nothing else changes. It does not breathe for you, so vacuum still kills
 * through low pressure, and as the seal slot is single it never sits beside
 * an air bladder.
 */
/obj/item/organ/cyberimp/cyberware/frostline
	name = "\improper Frostline lining"
	desc = "A quilted heating lining stitched in under the ribs, for work on planets that never get warm."
	icon_state = "frostline"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_SEAL
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_RESISTCOLD)

// =========================================================================
// TWITCHWIRE (T1) and WEAVER SHUNT (T3): the rungs around the Slipwire
// =========================================================================

/// The Twitchwire's dodge: a flinch more than a sidestep.
/obj/item/organ/cyberimp/cyberware/slipwire/street
	name = "\improper Twitchwire"
	desc = "A cheap reflex splice into the spinal trunk. Your legs flinch a little before you tell them to."
	icon_state = "slipwire_street"
	chrome_load = 2
	tier = CYBERWARE_TIER_1
	dodge_chance = 8
	gait_modifier = null

/obj/item/organ/cyberimp/cyberware/slipwire/milspec
	name = "\improper Weaver shunt"
	desc = "A military reflex shunt wired the length of the spine. It was built for people who get shot at for a living."
	icon_state = "slipwire_milspec"
	chrome_load = 5
	tier = CYBERWARE_TIER_3
	dodge_chance = 20
	gait_modifier = /datum/movespeed_modifier/cyberware_slipwire/weaver

/datum/movespeed_modifier/cyberware_slipwire/weaver
	multiplicative_slowdown = -0.15

// =========================================================================
// THUMPER EAR (T1): short, loud sonar
// =========================================================================

/obj/item/organ/cyberimp/cyberware/doppler/street
	name = "\improper Thumper ear"
	desc = "A budget sonar transceiver socketed in behind the ear. It thumps like a bass drum from the inside."
	icon_state = "doppler_street"
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	sonar_range = 5
	contact_fade = 3 SECONDS
	ping_volume_bonus = 10

// =========================================================================
// SPLICE SKUS: not listed on any vendor yet, the integration pass adds them
// to the Chop Shop's sku_types (and the street doc's, for the credit ones).
// =========================================================================

/datum/shop_sku/ripperdoc/hardweave
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave
	price_credits = 3000

/datum/shop_sku/ripperdoc/atlas_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/atlas/street
	price_credits = 1500

/datum/shop_sku/ripperdoc/second_wind_deep
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/second_wind/deep
	price_credits = 1800

/datum/shop_sku/ripperdoc/coolant_street
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/coolant/street
	price_credits = 1500

/datum/shop_sku/ripperdoc/frostline
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/frostline
	price_credits = 1500

/datum/shop_sku/ripperdoc/slipwire_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/slipwire/street
	price_credits = 1800

/datum/shop_sku/ripperdoc/slipwire_milspec
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/slipwire/milspec
	price_vouchers = 3

/datum/shop_sku/ripperdoc/doppler_street
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/doppler/street
	price_credits = 1500

// =========================================================================
// TRADE-IN: half list, credits only, exact type. The Weaver shunt costs
// vouchers, which can't be refunded, so it has no entry. Not listed on any
// buyback_types yet, same integration pass as above. Each entry also has the
// street doc's own wording below.
//
// Names stay siblings of the parent entries (second_wind_deep, not
// second_wind/deep) so a model never inherits its parent's price. The
// parent's own entries (second_wind, dermal_mesh) still match these models
// through match_subtypes, at the parent's lower rate.
// =========================================================================

/datum/shop_buyback/ripperdoc/hardweave
	name = "Hardweave Plating (pulled)"
	desc = "Heavy weave, cut out. Splice recycles it toward the plate."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave
	match_subtypes = FALSE
	pay_credits = 1500
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/atlas_street
	name = "Strut Frame (pulled)"
	desc = "A bolted-in bone frame, pulled. Splice strips it for the full truss."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/atlas/street
	match_subtypes = FALSE
	pay_credits = 750
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/second_wind_deep
	name = "Deep-Lung Bladder (pulled)"
	desc = "A big air bladder, used. Splice patches and resells."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/second_wind/deep
	match_subtypes = FALSE
	pay_credits = 900
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/coolant_street
	name = "Heat-Sink Lining (pulled)"
	desc = "A finned lining, pulled. Splice melts it down toward the full loop."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/coolant/street
	match_subtypes = FALSE
	pay_credits = 750
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/frostline
	name = "Frostline Lining (pulled)"
	desc = "A quilted heater lining, pulled. Splice resells these to the ice crews."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/frostline
	match_subtypes = FALSE
	pay_credits = 750
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/slipwire_street
	name = "Twitchwire (pulled)"
	desc = "A cheap reflex splice, pulled. Splice trades it up toward the real shunt."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/slipwire/street
	match_subtypes = FALSE
	pay_credits = 900
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/doppler_street
	name = "Thumper Ear (pulled)"
	desc = "A loud little sonar, pulled. Splice takes it toward a quieter one."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/doppler/street
	match_subtypes = FALSE
	pay_credits = 750
	demand_min = 1
	demand_max = 2

// ---- Ratchet's wording ----------------------------------------------------

/datum/shop_buyback/ripperdoc/hardweave/street_doc
	desc = "Used armour weave. Heavy."

/datum/shop_buyback/ripperdoc/atlas_street/street_doc
	desc = "A used bone frame. Still rattles."

/datum/shop_buyback/ripperdoc/second_wind_deep/street_doc
	desc = "A used big air bladder."

/datum/shop_buyback/ripperdoc/coolant_street/street_doc
	desc = "A used heat-sink lining. Still warm."

/datum/shop_buyback/ripperdoc/frostline/street_doc
	desc = "A used heater lining."

/datum/shop_buyback/ripperdoc/slipwire_street/street_doc
	desc = "A used reflex splice. Twitchy."

/datum/shop_buyback/ripperdoc/doppler_street/street_doc
	desc = "A used sonar ear. Loud."
