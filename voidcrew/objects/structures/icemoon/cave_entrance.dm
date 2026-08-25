/obj/structure/spawner/ice_moon/demonic_portal/blobspore
	mob_types = list(/mob/living/basic/blob_minion/spore/wasteland)
	spawn_time = 300
	faction = list(FACTION_WASTELAND)

/obj/structure/spawner/ice_moon/demonic_portal/hivebot
	mob_types = list(/mob/living/basic/hivebot/rapid/wasteland)
	spawn_time = 300
	faction = list(FACTION_WASTELAND)

/**
 * Portal payout: zone-aware.
 *
 * The old ~850-line jackpot switch (clown hell, the wizard shelf, god-loot
 * at flat odds on any planet the portal touched) is gone. Destroying a
 * portal now pays through the zone loot system: one themed cache rolled
 * against the zone the planet actually occupies. Deep-space worlds pay
 * red-table prizes, safe-ring worlds pay green, plus a themed guard wave
 * with a guaranteed presence in any zone, so the payout is never free.
 *
 * Where the old drops went: everything necropolis-tier still exists in the
 * tendril chest (necropolis tendrils, elite tumors and ruin fishing all
 * spawn it, see mining/lavaland/edits/necropolis_chests.dm); the
 * bloodletter knife and plant flamethrower moved into the occult/industrial
 * theme tables; the wizard shelf, His Grace and the clown kit live on at
 * low weight in the occult/research/wardrobe RARE tables (all in
 * modules/loot/themes/, by owner request). The doom blood-drunk miner is
 * gone for good, megafauna are banned from loot payouts; arenas built FOR
 * them are the only exception.
 */
/obj/effect/collapsing_demonic_portal/drop_loot()
	visible_message(span_warning("Something slips out of [src]!"))
	// One themed cache. There is no separate jackpot variant any more: what
	// makes a portal cache good is the band the portal collapsed in, same as
	// every other cache in the game.
	var/static/list/crate_weights = list(
		/obj/structure/closet/crate/zone_loot/expedition = 20,
		/obj/structure/closet/crate/zone_loot/industrial = 14,
		/obj/structure/closet/crate/zone_loot/occult = 13,
		/obj/structure/closet/crate/zone_loot/research = 13,
		/obj/structure/closet/crate/zone_loot/medical = 11,
		/obj/structure/closet/crate/zone_loot/plunder = 9,
		/obj/structure/closet/crate/zone_loot/armory = 8,
		/obj/structure/closet/crate/zone_loot/wardrobe = 8,
		/obj/structure/closet/crate/zone_loot/syndicate = 6,
	)
	// cache theme -> the guard wave that fits it (same pairings as the
	// guard_themes lists on the loot theme datums)
	var/static/list/wave_by_crate = list(
		/obj/structure/closet/crate/zone_loot/expedition = /obj/effect/zone_mobs/wildlife,
		/obj/structure/closet/crate/zone_loot/industrial = /obj/effect/zone_mobs/robot,
		/obj/structure/closet/crate/zone_loot/occult = /obj/effect/zone_mobs/undead,
		/obj/structure/closet/crate/zone_loot/research = /obj/effect/zone_mobs/bug,
		/obj/structure/closet/crate/zone_loot/medical = /obj/effect/zone_mobs/undead,
		/obj/structure/closet/crate/zone_loot/plunder = /obj/effect/zone_mobs/pirate,
		/obj/structure/closet/crate/zone_loot/armory = /obj/effect/zone_mobs/robot,
		/obj/structure/closet/crate/zone_loot/wardrobe = /obj/effect/zone_mobs/undead,
		/obj/structure/closet/crate/zone_loot/syndicate = /obj/effect/zone_mobs/syndicate,
	)
	var/crate_path = pick_weight(crate_weights)
	new crate_path(loc)
	// VOIDCREW EDIT: upstream deleted /proc/type2parent; voidcrew_type2parent() is its restored
	// body (voidcrew/modules/ship_upgrades/_ship_upgrades.dm).
	var/wave_path = wave_by_crate[crate_path] || wave_by_crate[voidcrew_type2parent(crate_path)]
	if(!wave_path)
		return
	// guaranteed escort even in green; the marker scales the wave by band
	new wave_path(loc, list(1, 2))
