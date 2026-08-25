// =========================================================================
// OCCULT THEME: the Pilgrim's Vow Reliquary config (rare_reliquary ruin)
// and every grave, chapel and plague site. Grave-goods and occult
// curiosities: mechanically useful, none of it cult-antag power. Common is
// candlelight and pocket votives, uncommon is solid valuables and curios,
// prime is genuine prizes. Guarded by cult remnants and the restless dead.
//  - soulstone/anybody/purified is the chaplain-issue stone: anyone can use
//    it, it can't be corrupted, and without shells it only carries a willing
//    shade, a companion gimmick, not an army.
//  - coin/eldritch is a cursed curio (diamond+plasma mats, bites
//    non-heretics for 5 on a flip). Flavor tax included.
//  - knife/bloodletter came over from the retired icemoon-portal jackpot
//    (see cave_entrance.dm): a bleed-stacking knife, prime-tier by right.
//  - cyberware: one piece only, the Graverobber's Jack. A wrist spike for
//    reading what a dead skull still has on it belongs in a theme built out
//    of graves; the rest of the parlor roster does not.
//  - EXCEPTION to "no antag-tier power" (owner request, 2026-07-21): the
//    portal's wizard/demon shelf sits at the bottom of prime, His Grace
//    included. These are the rarest things the theme can pay. A green-band
//    cache can pay them. It just very rarely gets a prime draw at all, and
//    the shelf is the long tail of that draw.
// TODO: review/balance-pass all four tiers: first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/occult
	name = "occult"
	guard_themes = list(
		/obj/effect/zone_mobs/cult,
		/obj/effect/zone_mobs/cult/boss,
		/obj/effect/zone_mobs/undead,
		/obj/effect/zone_mobs/undead/boss,
	)
	theme_skus = list(
		/datum/shop_sku/ripperdoc/graverobber,
	)
	loot_common = list(
		/obj/item/storage/fancy/candle_box = 10,
		/obj/item/flashlight/flare/candle/infinite = 8,
		/obj/item/coin/silver = 8,
		/obj/item/reagent_containers/cup/glass/bottle/holywater = 6,
		/obj/item/book/bible = 6,
		/obj/item/coin/gold = 5,
		// the grave-robber's rifle: old, ugly, still kills what walks
		/obj/item/gun/ballistic/rifle/boltaction/surplus = 6,
		/obj/item/toy/cards/deck/tarot = 5,
		/obj/item/reagent_containers/cup/glass/bottle/wine = 4,
	)
	loot_uncommon = list(
		/obj/item/statuebust = 8,
		/obj/item/flashlight/lantern = 7,
		/obj/item/ectoplasm = 6,
		/obj/item/gun/energy/laser/retro = 6,
		/obj/item/clothing/suit/chaplainsuit/bishoprobe = 5,
		/obj/item/clothing/head/chaplain/bishopmitre = 5,
		/obj/item/toy/cards/deck/tarot/haunted = 4,
		/obj/item/coin/eldritch = 3,
		/obj/item/ship_parts/science = 5,
		// whoever was robbing these graves before you left their tools in
		// their arm: three seconds a body, and the skull gives up what it kept
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/graverobber = 3,
	)
	loot_prime = list(
		/obj/item/stack/sheet/mineral/diamond/five = 8,
		/obj/item/stack/sheet/mineral/gold/fifty = 6,
		/obj/item/stack/sheet/mineral/silver/fifty = 6,
		/obj/item/clothing/suit/armor/riot/knight = 5,
		/obj/item/gun/energy/laser/hellgun = 5,
		/obj/item/knife/bloodletter = 3,
		/obj/item/soulstone/anybody/purified = 3,
		// the deepest slice of the theme, previously reachable only through
		// a sealed cache: now the long tail of prime, open to any band
		/obj/item/book/granter/action/spell/sacredflame = 2,
		/obj/item/gun/magic/staff/chaos = 2,
		/obj/item/mjollnir = 2,
		/obj/item/book/granter/action/spell/fireball = 1,
		/obj/item/book/granter/action/spell/random = 1,
		/obj/item/his_grace = 1,
	)
	// One-of-a-kind authored prizes, drawn as the fourth tier from any
	// band (weight = how shallow the item used to sit: 3 was reachable
	// early, 1 was the bottom of the deepest cache).
	loot_uniques = list(
		/obj/item/clothing/gloves/color/black/pallbearer = 3,
		/obj/item/flashlight/flare/candle/widows = 3,
		/obj/item/clothing/neck/scarf/purple/confessor_stole = 2,
		/obj/item/flashlight/lantern/censer_quiet_parish = 2,
		/obj/item/cane/shepherds_crook = 1,
		/obj/item/clothing/neck/beads/vow_ring = 1,
	)

/obj/structure/closet/crate/zone_loot/occult
	name = "votive chest"
	desc = "A chest of offerings, wax-sealed and inscribed with a prayer nobody says anymore."
	icon_state = "wooden"
	base_icon_state = "wooden"
	theme = /datum/loot_theme/occult

/// Cult remnants: constructs still bound to a dead master's wards.
/obj/effect/zone_mobs/cult
	name = "zone mob spawner (cult)"
	mobs_green = list(
		/mob/living/basic/construct/proteon/hostile = 10,
	)
	mobs_yellow = list(
		/mob/living/basic/construct/proteon/hostile = 8,
		/mob/living/basic/construct/artificer/hostile = 5,
	)
	mobs_red = list(
		/mob/living/basic/construct/artificer/hostile = 6,
		/mob/living/basic/construct/wraith/hostile = 5,
		/mob/living/basic/construct/juggernaut/hostile = 4,
	)

/obj/effect/zone_mobs/cult/boss
	name = "zone mob spawner (cult boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/construct/artificer/hostile = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/construct/wraith/hostile = 1,
	)
	mobs_red = list(
		/mob/living/basic/construct/juggernaut/hostile = 1,
	)

/// The restless dead: graves, derelicts, plague sites.
/obj/effect/zone_mobs/undead
	name = "zone mob spawner (undead)"
	mobs_green = list(
		/mob/living/basic/skeleton = 10,
		/mob/living/basic/zombie = 6,
	)
	mobs_yellow = list(
		/mob/living/basic/skeleton/settler = 8,
		/mob/living/basic/zombie = 8,
		/mob/living/basic/skeleton/templar = 4,
	)
	mobs_red = list(
		/mob/living/basic/skeleton/templar = 8,
		/mob/living/basic/skeleton/plasmaminer = 6,
		/mob/living/basic/skeleton/plasmaminer/jackhammer = 4,
	)

/obj/effect/zone_mobs/undead/boss
	name = "zone mob spawner (undead boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/skeleton/templar = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/skeleton/plasmaminer = 1,
	)
	mobs_red = list(
		/mob/living/basic/skeleton/plasmaminer/jackhammer = 1,
	)
