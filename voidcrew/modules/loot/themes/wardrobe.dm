// =========================================================================
// WARDROBE THEME — identity loot: clothes and character pieces so crews
// stop looking like quintuplets. Green is thrift-store, yellow is
// somebody's good coat, red is armored fashion you'll be recognized by.
// Liner wrecks keep their passengers: guarded by the restless dead
// (undead markers, themes/occult.dm).
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/wardrobe
	name = "wardrobe"
	guard_themes = list(/obj/effect/zone_mobs/undead, /obj/effect/zone_mobs/undead/boss)
	loot_green = list(
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
	)
	loot_yellow = list(
		/obj/item/clothing/suit/jacket/leather/biker = 10,
		/obj/item/clothing/suit/armor/vest/leather = 8,
		/obj/item/clothing/head/cowboy/black = 7,
		/obj/item/clothing/head/hats/warden/police = 6,
		/obj/item/clothing/under/costume/soviet = 6,
		/obj/item/clothing/suit/costume/judgerobe = 5,
		/obj/item/clothing/gloves/tackler/combat = 5,
		/obj/item/clothing/under/rank/prisoner = 4,
		/obj/item/clothing/mask/gas/sechailer/swat = 4,
		/obj/item/ship_parts/trade = 6,
	)
	loot_red = list(
		/obj/item/clothing/head/cowboy/bounty = 9,
		/obj/item/clothing/suit/armor/vest/warden/alt = 8,
		/obj/item/clothing/head/helmet/knight = 7,
		/obj/item/clothing/head/cowboy/black/syndicate = 6,
		/obj/item/clothing/suit/hooded/berserker = 4,
		/obj/item/clothing/head/hooded/berserker = 4,
		/obj/item/ship_parts/trade = 6,
	)
	// Rare tables: surviving stock entries + this theme's uniques at ~4
	// (see voidcrew/modules/loot/uniques/wardrobe.dm and the design doc).
	// The clown line (weights 1-2) is the retired icemoon-portal "clown
	// hell" kit, rehomed here by owner request — identity loot at its most
	// committed. The honkrender is a trap-toy: it cuts a tear that spawns
	// hostile clowns. Caveat emptor.
	rare_loot_green = list(
		/obj/item/clothing/suit/jacket/leather/biker = 8,
		/obj/item/clothing/head/cowboy/black = 6,
		/obj/item/clothing/shoes/laceup/winters_loafers = 4,
		/obj/item/megaphone/clown = 2,
	)
	rare_loot_yellow = list(
		/obj/item/clothing/head/cowboy/bounty = 8,
		/obj/item/clothing/suit/armor/vest/warden/alt = 6,
		/obj/item/clothing/head/stage_presence = 4,
		/obj/item/third_hand_kit = 4,
		/obj/item/clothing/shoes/clown_shoes/banana_shoes/combat = 2,
	)
	rare_loot_red = list(
		/obj/item/clothing/head/cowboy/bounty = 6,
		/obj/item/clothing/suit/hooded/berserker = 5,
		/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat = 4,
		/obj/item/clothing/suit/the_occasion = 4,
		/obj/item/gun/magic/staff/honk = 2,
		/obj/item/veilrender/honkrender = 1,
	)

/obj/structure/closet/crate/zone_loot/wardrobe
	name = "lost luggage cache"
	desc = "A dented luggage container from a liner that stopped existing. The name tags have all faded."
	icon_state = "cargo"
	base_icon_state = "cargo"
	theme = /datum/loot_theme/wardrobe

/obj/structure/closet/crate/zone_loot/wardrobe/rare
	name = "couturier's trunk"
	desc = "A tailor's traveling trunk, latches polished by use. Somebody's entire wardrobe is packed in here."
	rare = TRUE
