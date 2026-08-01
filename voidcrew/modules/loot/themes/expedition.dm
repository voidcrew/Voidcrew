// =========================================================================
// EXPEDITION THEME — prospector and frontier kit (mining camps, crash
// sites, survey posts, meteor fields). Green keeps you alive, yellow makes
// you faster, red makes the planet regret you landed. Guarded by
// territorial fauna: wildlife on planet surfaces, the vacuum-proof asteroid
// table for airless rocks (the landable meteor storm fields in
// overmap/events.dm spawn both this theme's caches and asteroid packs at
// runtime).
// TODO: review/balance-pass all six tables — first-draft weights and
// contents, never playtested.
// =========================================================================

/datum/loot_theme/expedition
	name = "expedition"
	guard_themes = list(
		/obj/effect/zone_mobs/wildlife,
		/obj/effect/zone_mobs/wildlife/boss,
		/obj/effect/zone_mobs/asteroid,
	)
	loot_green = list(
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
	)
	loot_yellow = list(
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
	)
	loot_red = list(
		/obj/item/borg/upgrade/modkit/range = 9,
		/obj/item/clothing/shoes/bhop = 7,
		/obj/item/resonator = 7,
		/obj/item/gun/energy/plasmacutter/adv = 6,
		/obj/item/gun/ballistic/shotgun/automatic/combat = 6,
		/obj/item/gun/energy/laser = 5,
		/obj/item/kinetic_crusher = 5,
		/obj/item/clothing/glasses/heat = 4,
		/obj/item/clothing/suit/hooded/cloak/drake = 2,
		/obj/item/ship_parts/misc = 6,
	)
	// Rare tables: surviving stock entries + this theme's uniques at ~4
	// (see voidcrew/modules/loot/uniques/expedition.dm and the design doc)
	rare_loot_green = list(
		/obj/item/gun/energy/recharge/kinetic_accelerator = 8,
		/obj/item/storage/belt/mining/alt = 6,
		/obj/item/gun/ballistic/rifle/boltaction/surplus = 6,
		/obj/item/pinpointer/old_hands_compass = 4,
		/obj/item/claim_stake = 4,
	)
	rare_loot_yellow = list(
		/obj/item/borg/upgrade/modkit/range = 8,
		/obj/item/resonator = 6,
		/obj/item/gun/ballistic/shotgun/riot = 5,
		/obj/item/clothing/suit/hooded/explorer/second_season_duster = 4,
		/obj/item/pickaxe/divining = 4,
	)
	rare_loot_red = list(
		/obj/item/kinetic_crusher = 8,
		/obj/item/gun/ballistic/rifle/boltaction/prime = 5,
		/obj/item/clothing/suit/hooded/cloak/drake = 5,
		/obj/item/deepwell_sampler = 4,
		/obj/item/longwalk_rig = 4,
	)

/obj/structure/closet/crate/zone_loot/expedition
	name = "expedition supply cache"
	desc = "A trail-battered supply cache plastered in claim stickers. The last crew never came back for it."
	icon_state = "mining"
	base_icon_state = "mining"
	theme = /datum/loot_theme/expedition

/obj/structure/closet/crate/zone_loot/expedition/rare
	name = "prospector's claim chest"
	desc = "A claim chest with the assay office's wax still on it. Whoever staked this claim struck something."
	rare = TRUE

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

/// The wildlife setpiece. Red rolls a lavaland ELITE — the "harder version
/// of a normal mob" tier (elite goliath/watcher/legion/hivelord), the
/// design ceiling for ruin guards. NEVER megafauna: the old lesser ash
/// drake here was a mistake the loot audit test now guards against.
/// Standalone elites have no tumor, so they fight as NPCs and drop no
/// tendril chest — the cache they guard is the prize.
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
/// asteroid ruin — everything in these tables survives space.
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
