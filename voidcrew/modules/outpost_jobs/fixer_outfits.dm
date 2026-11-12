/**
 * # Outpost jobs: the fixers' outfits
 *
 * Owner: P1. Plain clothes from the existing wardrobe (L17): nothing worth stripping, no armor, no ID, no bag. Every
 * ambient NPC's kit is locked to them, so none of it becomes loot. What they hold at their seat (a book, a clipboard,
 * a deck of cards) is put in their hand by their haunt (fixer_npc.dm), not by the outfit.
 */

/// Nan Tolliver: somebody's grandmother. A cardigan over a dark skirt, reading glasses, sensible shoes.
/datum/outfit/outpost_fixer_nan
	name = "Fixer: Nan Tolliver"
	uniform = /obj/item/clothing/under/dress/skirt
	glasses = /obj/item/clothing/glasses/regular
	shoes = /obj/item/clothing/shoes/laceup

/// Lot Brannigan: a freight clerk. A brown work shirt and slacks, a flat cap, work boots, the pen behind his ear.
/datum/outfit/outpost_fixer_lot
	name = "Fixer: Lot Brannigan"
	uniform = /obj/item/clothing/under/rank/cargo/qm
	head = /obj/item/clothing/head/flatcap
	ears = /obj/item/pen
	shoes = /obj/item/clothing/shoes/workboots

/// Mister Quill: a thin man in a black suit and good shoes, and nothing else on him.
/datum/outfit/outpost_fixer_quill
	name = "Fixer: Mister Quill"
	uniform = /obj/item/clothing/under/suit/black_really
	shoes = /obj/item/clothing/shoes/laceup
