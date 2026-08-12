// =========================================================================
// EXPEDITION THEME: prospector and frontier kit (mining camps, crash
// sites, survey posts, meteor fields). Common keeps you alive, uncommon
// makes you faster, prime makes the planet regret you landed. Guarded by
// territorial fauna: wildlife on planet surfaces, the vacuum-proof asteroid
// table for airless rocks (the landable meteor storm fields in
// overmap/events.dm spawn both this theme's caches and asteroid packs at
// runtime).
// Cyberware: the mobility and prospecting half of the parlor roster, calf
// pistons and a drill fist on the way up, surveyor optics and jump pistons at
// the top. The Skyhook wrist winch is here and NOWHERE else: it is the one
// piece of chrome Splice has never had on a shelf, so a cache is the only
// place in the game it exists (the mirror of the black market's Piledriver).
// TODO: review/balance-pass all four tiers: first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/expedition
	name = "expedition"
	guard_themes = list(
		/obj/effect/zone_mobs/wildlife,
		/obj/effect/zone_mobs/wildlife/boss,
		/obj/effect/zone_mobs/asteroid,
	)
	theme_skus = list(
		/datum/shop_sku/ripperdoc/shock_coils,
		/datum/shop_sku/ripperdoc/rockjaw,
		/datum/shop_sku/ripperdoc/angler,
		/datum/shop_sku/ripperdoc/prospector,
		/datum/shop_sku/ripperdoc/hopper,
	)
	loot_common = list(
		/obj/item/clothing/suit/hooded/explorer = 10,
		/obj/item/knife/combat/survival = 9,
		/obj/item/gun/ballistic/rifle/boltaction/surplus = 8,
		/obj/item/gps/mining = 8,
		/obj/item/flashlight/flare = 8,
		/obj/item/stack/marker_beacon/thirty = 6,
		/obj/item/mining_scanner = 6,
		/obj/item/climbing_hook = 5,
		/obj/item/reagent_containers/hypospray/medipen/survival = 4,
		/obj/item/pickaxe = 4,
		// prospector's chrome, cheapest rung: pistons that get you off the
		// ground fast and hold your footing on bad decking
		/obj/item/organ/cyberimp/cyberware/shock_coils = 4,
	)
	loot_uncommon = list(
		/obj/item/gun/energy/recharge/kinetic_accelerator = 10,
		/obj/item/storage/belt/mining/alt = 8,
		/obj/item/pickaxe/diamond = 7,
		/obj/item/t_scanner/adv_mining_scanner/lesser = 6,
		/obj/item/wormhole_jaunter = 6,
		// wildlife stoppers: the KA is a mining tool first, these are not
		/obj/item/gun/ballistic/shotgun/riot = 6,
		/obj/item/gun/ballistic/rifle/boltaction = 5,
		/obj/item/survivalcapsule = 5,
		/obj/item/clothing/suit/hooded/cloak/goliath = 4,
		/obj/item/gun/energy/plasmacutter = 4,
		/obj/item/ship_parts/misc = 6,
		// working chrome for a claim: a drill that folds out of the forearm
		// and hoppers its own ore, and a harpoon winch for everything else
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/rockjaw = 4,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/angler = 3,
	)
	loot_prime = list(
		/obj/item/borg/upgrade/modkit/range = 9,
		/obj/item/clothing/shoes/bhop = 7,
		/obj/item/resonator = 7,
		/obj/item/gun/energy/plasmacutter/adv = 6,
		/obj/item/gun/ballistic/shotgun/automatic/combat = 6,
		/obj/item/gun/energy/laser = 5,
		/obj/item/kinetic_crusher = 5,
		/obj/item/clothing/glasses/heat = 4,
		/obj/item/clothing/suit/hooded/cloak/drake = 2,
		// the deepest slice of the theme, previously reachable only through
		// a sealed cache: now the long tail of prime, open to any band
		/obj/item/gun/ballistic/rifle/boltaction/prime = 5,
		// top-end survey chrome: eyes that pulse ore through rock, the wrist
		// winch that exists nowhere else, and four tiles of standing jump
		/obj/item/organ/eyes/robotic/cyberware/prospector = 3,
		/obj/item/organ/cyberimp/arm/toolkit/cyberware/skyhook = 3,
		/obj/item/organ/cyberimp/cyberware/hopper = 2,
	)
	// One-of-a-kind authored prizes, drawn as the fourth tier from any
	// band (weight = how shallow the item used to sit: 3 was reachable
	// early, 1 was the bottom of the deepest cache).
	loot_uniques = list(
		/obj/item/claim_stake = 3,
		/obj/item/pinpointer/old_hands_compass = 3,
		/obj/item/clothing/suit/hooded/explorer/second_season_duster = 2,
		/obj/item/pickaxe/divining = 2,
		/obj/item/deepwell_sampler = 1,
		/obj/item/longwalk_rig = 1,
	)

/obj/structure/closet/crate/zone_loot/expedition
	name = "expedition supply cache"
	desc = "A trail-battered supply cache plastered in claim stickers. The last crew never came back for it."
	icon_state = "mining"
	base_icon_state = "mining"
	theme = /datum/loot_theme/expedition

/// Planet fauna: territorial wildlife around and inside surface ruins.
/obj/effect/zone_mobs/wildlife
	name = "zone mob spawner (wildlife)"
	mobs_green = list(
		/mob/living/basic/mining/bileworm = 8,
		/mob/living/basic/mining/lobstrosity = 6,
		/mob/living/basic/mining/goldgrub = 3,
	)
	mobs_yellow = list(
		/mob/living/basic/mining/goliath = 8,
		/mob/living/basic/mining/watcher = 6,
		/mob/living/basic/mining/brimdemon = 5,
	)
	mobs_red = list(
		/mob/living/basic/mining/goliath = 8,
		/mob/living/basic/mining/watcher = 6,
		/mob/living/basic/mining/legion = 5,
		/mob/living/basic/mining/goliath/ancient = 3,
	)

/// The wildlife setpiece. Red rolls a lavaland ELITE, the "harder version
/// of a normal mob" tier (elite goliath/watcher/legion/hivelord), the
/// design ceiling for ruin guards. NEVER megafauna: the old lesser ash
/// drake here was a mistake the loot audit test now guards against.
/// Standalone elites have no tumor, so they fight as NPCs and drop no
/// tendril chest, the cache they guard is the prize.
/obj/effect/zone_mobs/wildlife/boss
	name = "zone mob spawner (wildlife boss)"
	count_green = list(1, 1)
	count_yellow = list(1, 1)
	count_red = list(1, 1)
	mobs_green = list(
		/mob/living/basic/mining/goliath = 1,
	)
	mobs_yellow = list(
		/mob/living/basic/mining/goliath/ancient = 1,
	)
	mobs_red = list(
		/mob/living/simple_animal/hostile/asteroid/elite/broodmother = 1,
		/mob/living/simple_animal/hostile/asteroid/elite/herald = 1,
		/mob/living/simple_animal/hostile/asteroid/elite/legionnaire = 1,
		/mob/living/simple_animal/hostile/asteroid/elite/pandora = 1,
	)

/// Airless rock fauna: mining wildlife that shrugs off vacuum. Used by the
/// landable meteor storm fields (overmap/events.dm) and fits any airless
/// asteroid ruin, everything in these tables survives space.
/obj/effect/zone_mobs/asteroid
	name = "zone mob spawner (asteroid)"
	mobs_green = list(
		/mob/living/basic/mining/goldgrub = 8,
		/mob/living/basic/mining/hivelord = 6,
	)
	mobs_yellow = list(
		/mob/living/basic/mining/basilisk = 8,
		/mob/living/basic/mining/hivelord = 6,
		/mob/living/basic/mining/goliath = 4,
	)
	mobs_red = list(
		/mob/living/basic/mining/basilisk = 8,
		/mob/living/basic/mining/goliath/ancient = 6,
		/mob/living/basic/mining/legion = 4,
	)
