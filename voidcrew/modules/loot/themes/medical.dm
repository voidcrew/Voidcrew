// =========================================================================
// MEDICAL THEME — the CSV Meridian config (rare_hospice ruin) and every
// clinic, ward and quarantine wreck. Field medicine tiered up to the
// miracle shelf: green is the aid-station shelf (basic kits and
// consumables), yellow is the working pharmacy (advanced kits, solid chems,
// entry cybernetics), red is the cold-chain stock nobody lived to sign out
// (top kits, rare chems, tier-2 organs). Guarded by the restless dead —
// plague sites keep their patients (undead markers, themes/occult.dm).
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested. Tune against the outpost shop med prices in
// theme_skus.
// =========================================================================

/datum/loot_theme/medical
	name = "medical"
	guard_themes = list(/obj/effect/zone_mobs/undead, /obj/effect/zone_mobs/undead/boss)
	theme_skus = list(
		/datum/shop_sku/black_market/tactical_medkit,
		/datum/shop_sku/outfitter/advanced_medkit,
		/datum/shop_sku/outfitter/rare/compact_defib,
	)
	loot_green = list(
		/obj/item/storage/medkit/regular = 10,
		/obj/item/stack/medical/gauze = 10,
		/obj/item/storage/medkit/brute = 8,
		/obj/item/storage/medkit/fire = 8,
		/obj/item/storage/medkit/o2 = 8,
		/obj/item/storage/medkit/toxin = 6,
		/obj/item/stack/medical/suture = 6,
		/obj/item/stack/medical/mesh = 6,
		/obj/item/reagent_containers/hypospray/medipen = 5,
		/obj/item/storage/pill_bottle/multiver = 5,
		/obj/item/healthanalyzer = 4,
		/obj/item/reagent_containers/cup/bottle/salglu_solution = 4,
		// the ward's own enforcement locker: a quarantine that stopped
		// answering was a quarantine somebody had to hold by force
		/obj/item/gun/energy/e_gun/mini = 5,
	)
	loot_yellow = list(
		/obj/item/storage/medkit/advanced = 10,
		/obj/item/storage/medkit/surgery = 8,
		/obj/item/stack/medical/suture/medicated = 7,
		/obj/item/stack/medical/mesh/advanced = 7,
		/obj/item/storage/box/medipens = 6,
		/obj/item/reagent_containers/hypospray/medipen/ekit = 6,
		/obj/item/reagent_containers/hypospray/medipen/salacid = 5,
		/obj/item/reagent_containers/hypospray/medipen/oxandrolone = 5,
		/obj/item/reagent_containers/cup/bottle/atropine = 5,
		/obj/item/storage/pill_bottle/penacid = 5,
		/obj/item/defibrillator = 4,
		/obj/item/gun/energy/laser = 5,
		/obj/item/gun/ballistic/shotgun/riot = 4,
		/obj/item/healthanalyzer/advanced = 4,
		/obj/item/storage/medkit/tactical_lite = 4,
		/obj/item/organ/eyes/robotic/basic = 3,
		/obj/item/organ/liver/cybernetic = 3,
		/obj/item/organ/lungs/cybernetic = 3,
		/obj/item/ship_parts/science = 9,
	)
	loot_red = list(
		/obj/item/storage/medkit/advanced = 9,
		/obj/item/storage/medkit/tactical_lite = 8,
		/obj/item/reagent_containers/hypospray/medipen/atropine = 7,
		/obj/item/reagent_containers/hypospray/medipen/penthrite = 6,
		/obj/item/defibrillator/compact = 6,
		/obj/item/gun/ballistic/shotgun/automatic/combat = 5,
		/obj/item/gun/energy/laser/scatter = 4,
		/obj/item/storage/medkit/tactical = 5,
		/obj/item/reagent_containers/hypospray/medipen/survival = 5,
		/obj/item/organ/heart/cybernetic = 4,
		/obj/item/organ/eyes/robotic/shield = 4,
		/obj/item/autosurgeon/medical_hud = 4,
		/obj/item/organ/liver/cybernetic/tier2 = 3,
		/obj/item/organ/lungs/cybernetic/tier2 = 3,
		/obj/item/reagent_containers/hypospray/medipen/survival/luxury = 2,
		/obj/item/ship_parts/science = 11,
	)
	// Rare tables: surviving stock entries + this theme's uniques at ~4
	// (see voidcrew/modules/loot/uniques/medical.dm and the design doc)
	rare_loot_green = list(
		/obj/item/storage/medkit/advanced = 8,
		/obj/item/storage/medkit/surgery = 6,
		/obj/item/gun/energy/e_gun/mini = 5,
		/obj/item/clothing/neck/night_sisters_watch = 4,
		/obj/item/pen/red/triage = 4,
	)
	rare_loot_yellow = list(
		/obj/item/storage/medkit/tactical_lite = 8,
		/obj/item/defibrillator/compact = 6,
		/obj/item/gun/energy/laser = 5,
		/obj/item/meridian_drip = 4,
		/obj/item/bedsheet/medical/hospice = 4,
	)
	rare_loot_red = list(
		/obj/item/storage/medkit/tactical = 8,
		/obj/item/reagent_containers/hypospray/medipen/penthrite = 6,
		/obj/item/gun/energy/laser/scatter = 5,
		/obj/item/organ/heart/cybernetic/meridian = 4,
		/obj/item/reagent_containers/cup/tube/winterkiss = 4,
		/obj/item/reagent_containers/syringe/lazarus_line = 3,
	)

/obj/structure/closet/crate/zone_loot/medical
	name = "quarantine supply cache"
	desc = "A medical supply cache in biohazard livery. The requisition seal was never broken."
	icon_state = "medicalcrate"
	base_icon_state = "medicalcrate"
	theme = /datum/loot_theme/medical

/obj/structure/closet/crate/zone_loot/medical/rare
	name = "cold-chain pharmacy cache"
	desc = "A refrigerated pharmacy cache, still humming. The good stock was locked away from the wards."
	icon_state = "freezer"
	base_icon_state = "freezer"
	rare = TRUE
