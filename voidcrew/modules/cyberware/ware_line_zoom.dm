/**
 * # The optics line: zoom by tier
 *
 * Every chrome optic zooms (cyberware_zoom.dm). Reach climbs with the tier, and
 * the dedicated scout optics reach half a step further than combat or survey
 * optics of the same tier. The cheap ones slow their bearer while zoomed.
 *
 *   model            tier  load  zoom  walk tax  read          other
 *   Spyglass         1     1     1.0   1.0       silhouette    nothing
 *   Assay            1     1     1.0   1.0       silhouette    short ore pulse, no caches
 *   Nightshade       1     1     1.0   1.0       silhouette    unchanged
 *   Prospector       2     2     1.5   0.5       itemized      unchanged
 *   Deadeye          2     3     1.5   0.5       itemized      unchanged
 *   Longsight        2     2     2.0   none      itemized, 9   nothing
 *   Marksman link    3     4     2.0   none      itemized      4 tracked shots, 10 tiles, 18 s
 *   Lookout          3     3     2.5   none      itemized, 11  8 s read, low-light
 *
 * Binoculars (4) stay the reach ceiling, since they cost both hands. All of
 * these ride ORGAN_SLOT_EYES, so installing one replaces whatever eyes the
 * bearer had. Spyglass, Longsight and Lookout are their own types on the optics
 * base; Assay optics subtype the Prospector and the Marksman link the Deadeye,
 * so they keep their parents' ability code.
 */

// =========================================================================
// SPYGLASS OPTICS (T1)
// =========================================================================

/obj/item/organ/eyes/robotic/cyberware/spyglass
	name = "spyglass optics"
	desc = "Cheap chrome eyes with a telescoping lens behind each iris. They see a long way and not much else."
	icon_state = "spyglass"
	eye_color_left = "#7a6a4f"
	eye_color_right = "#7a6a4f"
	iris_overlay = null
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	chrome_scan_resolution = CYBERWARE_SCAN_SILHOUETTE
	optics_zoom = 1
	zoom_walk_penalty = 1

// =========================================================================
// ASSAY OPTICS (T1), the Prospector's street model
// =========================================================================

/obj/item/organ/eyes/robotic/cyberware/prospector/street
	name = "assay optics"
	desc = "Surveyor eyes off a mining co-op's bargain shelf. The pulse is short and the lenses are scratched, but ore still lights up through the rock."
	icon_state = "prospector_street"
	eye_color_left = "#8a6a1f"
	eye_color_right = "#8a6a1f"
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	chrome_scan_resolution = CYBERWARE_SCAN_SILHOUETTE
	actions_types = list(
		/datum/action/cooldown/cyberware/prospector_pulse/assay,
		/datum/action/cooldown/cyberware/chrome_read,
	)
	optics_zoom = 1
	zoom_walk_penalty = 1
	pulse_range = 5
	pulse_marks_caches = FALSE

/datum/action/cooldown/cyberware/prospector_pulse/assay
	desc = "Ping ore veins through rock."
	cooldown_time = 15 SECONDS

// =========================================================================
// LONGSIGHT OPTICS (T2 scout)
// =========================================================================

/obj/item/organ/eyes/robotic/cyberware/longsight
	name = "longsight optics"
	desc = "Scout optics with a long lens stack behind each iris. They pick out a face across a hangar bay."
	icon_state = "longsight"
	eye_color_left = "#3f6f8f"
	eye_color_right = "#3f6f8f"
	iris_overlay = null
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	optics_zoom = 2
	zoom_walk_penalty = 0
	chrome_read_range = 9

// =========================================================================
// MARKSMAN LINK (T3), the Deadeye's service model
// =========================================================================

/obj/item/organ/eyes/robotic/cyberware/deadeye/milspec
	name = "marksman link"
	desc = "Service-grade targeting optics, the unit stencil still on the housing. The coprocessor is a generation newer than the Deadeye's."
	icon_state = "deadeye_milspec"
	chrome_load = 4
	tier = CYBERWARE_TIER_3
	actions_types = list(
		/datum/action/cooldown/cyberware/deadeye_tag/marksman,
		/datum/action/cooldown/cyberware/chrome_read,
	)
	optics_zoom = 2
	zoom_walk_penalty = 0
	tag_range = 10
	tag_shots = 4
	tag_duration = 15 SECONDS

/datum/action/cooldown/cyberware/deadeye_tag/marksman
	name = "Marksman Tag"
	desc = "Tag a hostile in view. Your next four shots track them automatically. The tag refuses to take a crewmate."
	cooldown_time = 18 SECONDS

// =========================================================================
// LOOKOUT OPTICS (T3 scout)
// =========================================================================

/obj/item/organ/eyes/robotic/cyberware/lookout
	name = "lookout optics"
	desc = "Military spotter eyes with a low-light amplifier. Made for lying on a ridge and watching a camp for hours."
	icon_state = "lookout"
	eye_color_left = "#2d4a2a"
	eye_color_right = "#2d4a2a"
	iris_overlay = null
	// The Nightshade's dark floor, without its green.
	lighting_cutoff = LIGHTING_CUTOFF_MEDIUM
	chrome_load = 3
	tier = CYBERWARE_TIER_3
	optics_zoom = 2.5
	zoom_walk_penalty = 0
	chrome_read_range = 11
	chrome_read_cooldown = 8 SECONDS

// =========================================================================
// SPLICE SKUs and INTAKE LEDGER
// Listed on /datum/outpost_shop/vendor/ripperdoc (sku_types, buyback_types)
// and on the street doc's lists (the credit-priced three and their
// /street_doc trade-ins). The optics also ride the zone loot tables.
// =========================================================================

/datum/shop_sku/ripperdoc/spyglass
	category = "Street Chrome"
	desc = "A pair of chrome telescoping optics."
	item_path = /obj/item/organ/eyes/robotic/cyberware/spyglass
	price_credits = 400
	stock_min = 1
	stock_max = 3

/datum/shop_sku/ripperdoc/assay_optics
	category = "Street Chrome"
	desc = "A pair of budget surveyor optics."
	item_path = /obj/item/organ/eyes/robotic/cyberware/prospector/street
	price_credits = 900

/datum/shop_sku/ripperdoc/longsight
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	desc = "A pair of long-lens scout optics."
	item_path = /obj/item/organ/eyes/robotic/cyberware/longsight
	price_credits = 2400

/datum/shop_sku/ripperdoc/deadeye_milspec
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/eyes/robotic/cyberware/deadeye/milspec
	price_vouchers = 3

/datum/shop_sku/ripperdoc/lookout
	zone_permission = ZONE_PERMISSION_ADVANCED
	category = "Military Chrome"
	item_path = /obj/item/organ/eyes/robotic/cyberware/lookout
	price_vouchers = 3

/// Half list, credits only, like the rest of the ladder's credit rungs.
/datum/shop_buyback/ripperdoc/spyglass
	name = "Spyglass Optics (pulled)"
	desc = "Cheap zoom eyes. Splice takes them toward a better pair."
	category = "Trade-In"
	item_path = /obj/item/organ/eyes/robotic/cyberware/spyglass
	match_subtypes = FALSE
	pay_credits = 200
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/assay_optics
	name = "Assay Optics (pulled)"
	desc = "Budget surveyor eyes. Worth half toward the full suite."
	category = "Trade-In"
	item_path = /obj/item/organ/eyes/robotic/cyberware/prospector/street
	match_subtypes = FALSE
	pay_credits = 450
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/longsight
	name = "Longsight Optics (pulled)"
	desc = "Scout eyes, lenses intact. Splice strips the glass for a spotter rig."
	category = "Trade-In"
	item_path = /obj/item/organ/eyes/robotic/cyberware/longsight
	match_subtypes = FALSE
	pay_credits = 1200
	demand_min = 1
	demand_max = 2

// Ratchet's ledger: the same entries in his words, same pay.

/datum/shop_buyback/ripperdoc/spyglass/street_doc
	desc = "Used zoom eyes."

/datum/shop_buyback/ripperdoc/assay_optics/street_doc
	desc = "Used survey eyes. Scratched, like they all are."

/datum/shop_buyback/ripperdoc/longsight/street_doc
	desc = "Used scout eyes."
