// =========================================================================
// MEDICAL THEME: the CSV Meridian config (rare_hospice ruin) and every
// clinic, ward and quarantine wreck. Field medicine tiered up to the
// miracle shelf: common is the aid-station shelf (basic kits and
// consumables), uncommon is the working pharmacy (advanced kits, solid
// chems, entry cybernetics), prime is the cold-chain stock nobody lived to
// sign out (top kits, rare chems, tier-2 organs). Guarded by the dead.
// Plague sites keep their patients (undead markers, themes/occult.dm).
// Cyberware: the surgical end of the parlor roster, a digester, an air
// bladder, a dialysis loop, and on the cold shelf the two pieces a clinic
// would only ever have fitted under anaesthetic (pain editor, Lazarus node).
// TODO: review/balance-pass all four tiers: first-draft weights and
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
		/datum/shop_sku/ripperdoc/gastro,
		/datum/shop_sku/ripperdoc/second_wind,
		/datum/shop_sku/ripperdoc/hemoglass,
		/datum/shop_sku/ripperdoc/dead_channel,
		/datum/shop_sku/ripperdoc/lazarus,
	)
	loot_common = list(
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
		// cheapest thing on the parlor's shelf and the one piece of chrome a
		// clinic would actually stock: it replaces a stomach
		/obj/item/organ/cyberimp/cyberware/gastro = 4,
	)
	loot_uncommon = list(
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
		// street and pro chrome on the ward's own terms: an emergency air
		// reserve and a blood filter, both things a med bay would have fitted
		/obj/item/organ/cyberimp/cyberware/second_wind = 4,
		/obj/item/organ/cyberimp/cyberware/hemoglass = 3,
	)
	loot_prime = list(
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
		// the cold shelf: a pain editor nobody signed for, and the military
		// node that restarts a heart on its own (4 vouchers over the counter)
		/obj/item/organ/cyberimp/cyberware/dead_channel = 3,
		/obj/item/organ/cyberimp/cyberware/lazarus = 2,
	)
	// One-of-a-kind authored prizes, drawn as the fourth tier from any
	// band (weight = how shallow the item used to sit: 3 was reachable
	// early, 1 was the bottom of the deepest cache).
	loot_uniques = list(
		/obj/item/clothing/neck/night_sisters_watch = 3,
		/obj/item/pen/red/triage = 3,
		/obj/item/bedsheet/medical/hospice = 2,
		/obj/item/meridian_drip = 2,
		/obj/item/organ/heart/cybernetic/meridian = 1,
		/obj/item/reagent_containers/cup/tube/winterkiss = 1,
		/obj/item/reagent_containers/syringe/lazarus_line = 1,
	)

/obj/structure/closet/crate/zone_loot/medical
	name = "quarantine supply cache"
	desc = "A medical supply cache in biohazard livery. The requisition seal was never broken."
	icon_state = "medicalcrate"
	base_icon_state = "medicalcrate"
	theme = /datum/loot_theme/medical

