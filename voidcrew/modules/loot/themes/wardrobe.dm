// =========================================================================
// WARDROBE THEME: identity loot: clothes and character pieces so crews
// stop looking like quintuplets. Common is thrift-store, uncommon is
// somebody's good coat, prime is armored fashion you'll be recognized by.
// Liner wrecks keep their passengers: guarded by the restless dead
// (undead markers, themes/occult.dm).
// Cyberware: the two pieces of the parlor roster that are a look before
// they're a tool. Programmable ink and matte black eyes. Both draw on the
// body, which is exactly what this theme is for.
// TODO: review/balance-pass all four tiers: first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/wardrobe
	name = "wardrobe"
	guard_themes = list(/obj/effect/zone_mobs/undead, /obj/effect/zone_mobs/undead/boss)
	theme_skus = list(
		/datum/shop_sku/ripperdoc/chromatic_dermis,
		/datum/shop_sku/ripperdoc/nightshade,
	)
	loot_common = list(
		/obj/item/clothing/suit/jacket/leather = 10,
		/obj/item/clothing/suit/jacket/bomber = 8,
		/obj/item/clothing/head/beret = 8,
		/obj/item/clothing/under/pants/jeans = 7,
		/obj/item/clothing/suit/costume/poncho = 7,
		/obj/item/clothing/head/cowboy/brown = 6,
		/obj/item/clothing/mask/bandana/skull = 6,
		/obj/item/clothing/head/costume/ushanka = 5,
		/obj/item/clothing/suit/hooded/wintercoat = 5,
		/obj/item/clothing/suit/costume/hawaiian = 4,
		/obj/item/clothing/neck/scarf/red = 4,
		// what was in the coat pocket when the liner went down
		/obj/item/gun/ballistic/revolver/c38/detective = 5,
		// somebody's unused parlor appointment: tattoo ink you wear under
		// the skin, colour and pattern set at a Cradle
		/obj/item/organ/cyberimp/cyberware/chromatic_dermis = 4,
	)
	loot_uncommon = list(
		/obj/item/clothing/suit/jacket/leather/biker = 10,
		/obj/item/clothing/suit/armor/vest/leather = 8,
		/obj/item/clothing/head/cowboy/black = 7,
		/obj/item/clothing/head/hats/warden/police = 6,
		/obj/item/clothing/under/costume/soviet = 6,
		/obj/item/clothing/suit/costume/judgerobe = 5,
		/obj/item/clothing/gloves/tackler/combat = 5,
		/obj/item/gun/ballistic/automatic/pistol/m1911 = 5,
		/obj/item/gun/ballistic/automatic/tommygun = 4,
		/obj/item/clothing/under/rank/prisoner = 4,
		/obj/item/clothing/mask/gas/sechailer/swat = 4,
		/obj/item/ship_parts/trade = 6,
		// black eyes that see in the dark. Half the reason anyone buys them
		// is that everyone can tell you have them
		/obj/item/organ/eyes/robotic/cyberware/nightshade = 3,
	)
	loot_prime = list(
		/obj/item/clothing/head/cowboy/bounty = 9,
		/obj/item/clothing/suit/armor/vest/warden/alt = 8,
		/obj/item/clothing/head/helmet/knight = 7,
		/obj/item/clothing/head/cowboy/black/syndicate = 6,
		/obj/item/gun/ballistic/automatic/pistol/deagle = 5,
		/obj/item/clothing/suit/hooded/berserker = 4,
		/obj/item/clothing/head/hooded/berserker = 4,
		// the deepest slice of the theme, previously reachable only through
		// a sealed cache: now the long tail of prime, open to any band
		/obj/item/clothing/shoes/clown_shoes/banana_shoes/combat = 2,
		/obj/item/gun/magic/staff/honk = 2,
		/obj/item/megaphone/clown = 2,
		/obj/item/veilrender/honkrender = 1,
	)
	// One-of-a-kind authored prizes, drawn as the fourth tier from any
	// band (weight = how shallow the item used to sit: 3 was reachable
	// early, 1 was the bottom of the deepest cache).
	loot_uniques = list(
		/obj/item/clothing/shoes/laceup/winters_loafers = 3,
		/obj/item/clothing/head/stage_presence = 2,
		/obj/item/third_hand_kit = 2,
		/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat = 1,
		/obj/item/clothing/suit/the_occasion = 1,
	)

/obj/structure/closet/crate/zone_loot/wardrobe
	name = "lost luggage cache"
	desc = "A dented luggage container from a liner that stopped existing. The name tags have all faded."
	icon_state = "cargo"
	base_icon_state = "cargo"
	theme = /datum/loot_theme/wardrobe

