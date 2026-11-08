/**
 * # Faction pirates in ruins and kill contracts
 *
 * The faction pirate crews (Silverscale, the skeletons, the grey tide, the Lustrous, Interdyne) that the
 * pirate zone markers (voidcrew/modules/loot/themes/plunder.dm) scatter through ruins, and that kill
 * contracts (voidcrew/modules/missions/missions/recovery.dm) name as targets and guards. They wear the
 * faction looks and weapons of the pirate outfit tables (human_npc_outfits_pirates.dm) on the faction's
 * own species. NPC-ship crews and boarders are phase B's (voidcrew/modules/npc_ships/); these are the
 * same people met on the ground, without a ship's crew AI.
 *
 * Ranks: crew are regulars, captains elites (they take a fifth less brute and burn, and land aimed hits),
 * the faction leaders bosses (two fifths less). Designed drops are the basic mobs' (faction_pirate_mobs.dm,
 * faction_pirate_bosses.dm), rolled the same way: a captain's or boss's fixed pieces, its rare piece at 25%
 * rolled when it is made, the zone's ladder weapon for the rank and file, a captain's zone blade, one
 * odds-and-ends item, and the cash. A kill contract's target pays its cash once (npc_payout_mission).
 */

/datum/human_npc_voice/ruin_faction_pirate
	lines = list(
		RUIN_NPC_BARK_SPOT = list("There!", "Over here!", "Found one!", "Contact!"),
		HUMAN_NPC_BARK_DOWNED = list("I'm hit!", "Not like this..."),
		HUMAN_NPC_BARK_RECOVER = list("Still breathing."),
		HUMAN_NPC_BARK_CUFFED = list("The captain will hear of this."),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
	)
	chances = list(RUIN_NPC_BARK_SPOT = 60)

/datum/human_npc_voice/ruin_faction_pirate/skeleton
	lines = list(
		RUIN_NPC_BARK_SPOT = list("There ye are!", "I see ye!", "Over here, lads!"),
		HUMAN_NPC_BARK_DOWNED = list("Back to the deep..."),
		HUMAN_NPC_BARK_RECOVER = list("The dead don't stay down."),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("clatters to the floor."),
	)

/datum/human_npc_voice/ruin_faction_pirate/grey
	lines = list(
		RUIN_NPC_BARK_SPOT = list("Get 'em!", "That one, there!", "Over here!"),
		HUMAN_NPC_BARK_DOWNED = list("I want my toolbox..."),
		HUMAN_NPC_BARK_RECOVER = list("Robust!"),
		HUMAN_NPC_BARK_CUFFED = list("I didn't take nothing!"),
	)

/mob/living/carbon/human/npc/ruin/faction_pirate
	name = "pirate"
	faction = list(FACTION_PIRATE)
	npc_voice = /datum/human_npc_voice/ruin_faction_pirate
	npc_death_cash = 25
	/// Death loot it always carries (the basic mob's loot_pool)
	var/list/npc_loot_always
	/// Each piece rolled once at 25% when it is made (rare_loot_pool)
	var/list/npc_loot_rare
	/// What the rare roll gave it
	var/list/npc_loot_rolled
	/// Rolls the zone's ladder weapon on death (rank and file; captains and bosses don't)
	var/npc_loot_ladder = TRUE
	/// Rolls an odds-and-ends item on death (random_loot_2; bosses don't)
	var/npc_loot_extra = TRUE
	/// The faction's outfit table (human_npc_outfits_pirates.dm), whose space suit it wears in vacuum
	var/datum/human_npc_outfit_table/npc_site_table = /datum/human_npc_outfit_table/pirate

/mob/living/carbon/human/npc/ruin/faction_pirate/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	npc_loot_rolled = list()
	for(var/item_type in npc_loot_rare)
		if(npc_ladder_red_drop())
			npc_loot_rolled += item_type

// Dressed for vacuum in the faction's own space suit, whatever outfit it wears.
/mob/living/carbon/human/npc/ruin/faction_pirate/npc_fit_outfit_to_site(outfit, datum/human_npc_outfit_table/table)
	return ..(outfit, table || human_npc_singleton(npc_site_table))

/mob/living/carbon/human/npc/ruin/faction_pirate/npc_roll_death_loot()
	var/zone = npc_home_zone()
	. = list()
	if(length(npc_loot_always))
		. += npc_loot_always
	if(length(npc_loot_rolled))
		. += npc_loot_rolled
	if(npc_loot_ladder)
		. += ruin_pirate_ladder_weapon(zone)
	var/zone_blade = npc_zone_blade(zone)
	if(zone_blade)
		. += zone_blade
	if(npc_loot_extra)
		var/list/extras = npc_extra_loot_pool()
		if(length(extras))
			. += pick(extras)

/// The odds-and-ends pool one item is picked from on death.
/mob/living/carbon/human/npc/ruin/faction_pirate/proc/npc_extra_loot_pool()
	return list(
		/obj/item/storage/medkit/regular,
		/obj/item/storage/toolbox/mechanical,
		/obj/item/flashlight/seclite,
		/obj/item/reagent_containers/hypospray/medipen,
		/obj/item/stack/telecrystal,
	)

/// A blade some captains carry by zone, or null.
/mob/living/carbon/human/npc/ruin/faction_pirate/proc/npc_zone_blade(zone)
	return null

/// The ladder weapon a faction pirate drops for its zone (the basic mob's roll_ladder_weapon()).
/proc/ruin_pirate_ladder_weapon(zone, roll = rand(1, 100))
	switch(zone)
		if(ZONE_YELLOW)
			return roll <= 5 ? /obj/item/gun/energy/laser : pick(npc_ladder_yellow_melee())
		if(ZONE_RED)
			return roll <= 10 ? /obj/item/gun/ballistic/automatic/c20r/unrestricted : pick(npc_ladder_yellow_melee())
	if(roll <= 50)
		return /obj/item/knife/combat/survival
	return roll <= 75 ? /obj/item/spear : /obj/item/melee/baseball_bat

/// Captains: elites with a fixed purse and no ladder weapon.
/mob/living/carbon/human/npc/ruin/faction_pirate/captain
	npc_rank = HUMAN_NPC_RANK_ELITE
	npc_damage_taken = 0.8
	npc_death_cash = 1000
	npc_loot_ladder = FALSE

/// The captains of Silverscale, the Lustrous and Interdyne carry a better blade in harder zones.
/mob/living/carbon/human/npc/ruin/faction_pirate/captain/proc/zone_blade_for(zone)
	if(zone == ZONE_YELLOW)
		return /obj/item/claymore/shortsword
	if(zone == ZONE_RED)
		return pick(npc_ladder_yellow_melee())
	return null

/// Faction leaders: bosses with their faction's prize and the big purse.
/mob/living/carbon/human/npc/ruin/faction_pirate/boss
	npc_rank = HUMAN_NPC_RANK_BOSS
	npc_damage_taken = 0.6
	npc_death_cash = 3000
	npc_loot_ladder = FALSE
	npc_loot_extra = FALSE

// ===== SILVERSCALE =====

/mob/living/carbon/human/npc/ruin/faction_pirate/silverscale
	npc_name = "Silverscale Duelist"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/melee
	npc_site_table = /datum/human_npc_outfit_table/pirate/silverscale
	npc_outfit = /datum/outfit/piratecorpse/faction/silverscale/melee/armed
	npc_death_cash = 300

/mob/living/carbon/human/npc/ruin/faction_pirate/silverscale/npc_extra_loot_pool()
	return list(/obj/item/storage/medkit/regular, /obj/item/storage/toolbox/mechanical, random_fish_type())

/mob/living/carbon/human/npc/ruin/faction_pirate/silverscale/gunner
	npc_name = "Silverscale Marksman"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/ranged
	npc_site_table = /datum/human_npc_outfit_table/pirate/silverscale
	npc_outfit = null
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/silverscale/gunners
	npc_death_cash = 25

/mob/living/carbon/human/npc/ruin/faction_pirate/captain/silverscale
	npc_name = "Silverscale Noble"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/captain
	npc_site_table = /datum/human_npc_outfit_table/pirate/silverscale
	npc_outfit = /datum/outfit/piratecorpse/faction/silverscale/captain/armed

/mob/living/carbon/human/npc/ruin/faction_pirate/captain/silverscale/npc_zone_blade(zone)
	return zone_blade_for(zone)

/mob/living/carbon/human/npc/ruin/faction_pirate/boss/silverscale
	npc_name = "Silverscale Highlord"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/highlord
	npc_site_table = /datum/human_npc_outfit_table/pirate/silverscale
	npc_outfit = /datum/outfit/piratecorpse/faction/silverscale/highlord/armed
	npc_loot_always = list(/obj/item/clothing/suit/hooded/cloak/drake, /obj/item/clothing/head/hooded/cloakhood/drake)

// ===== SKELETONS =====

/mob/living/carbon/human/npc/ruin/faction_pirate/skeleton
	npc_name = "Skeleton Swashbuckler"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/melee
	npc_site_table = /datum/human_npc_outfit_table/pirate/skeleton
	npc_outfit = /datum/outfit/piratecorpse/faction/skeleton/melee/armed
	npc_voice = /datum/human_npc_voice/ruin_faction_pirate/skeleton
	npc_death_cash = 300

/mob/living/carbon/human/npc/ruin/faction_pirate/skeleton/gunner
	npc_name = "Skeleton Gunner"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/ranged
	npc_site_table = /datum/human_npc_outfit_table/pirate/skeleton
	npc_outfit = null
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/skeleton/gunners
	npc_death_cash = 25

/mob/living/carbon/human/npc/ruin/faction_pirate/captain/skeleton
	npc_name = "Skeleton Captain"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/captain
	npc_site_table = /datum/human_npc_outfit_table/pirate/skeleton
	npc_outfit = /datum/outfit/piratecorpse/faction/skeleton/captain/armed
	npc_voice = /datum/human_npc_voice/ruin_faction_pirate/skeleton
	npc_loot_always = list(/obj/item/gun/energy/laser)

/mob/living/carbon/human/npc/ruin/faction_pirate/boss/skeleton
	npc_name = "Davy Jones"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/davyjones
	npc_site_table = /datum/human_npc_outfit_table/pirate/skeleton
	npc_outfit = /datum/outfit/piratecorpse/faction/skeleton/davyjones/armed
	npc_voice = /datum/human_npc_voice/ruin_faction_pirate/skeleton
	npc_loot_always = list(/obj/item/gun/ballistic/shotgun/hook)

// ===== GREY TIDE =====

/mob/living/carbon/human/npc/ruin/faction_pirate/grey
	npc_name = "Grey Tider"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/melee
	npc_site_table = /datum/human_npc_outfit_table/pirate/grey
	npc_outfit = /datum/outfit/piratecorpse/faction/grey/melee/armed
	npc_voice = /datum/human_npc_voice/ruin_faction_pirate/grey
	npc_death_cash = 300

/mob/living/carbon/human/npc/ruin/faction_pirate/grey/gunner
	npc_name = "Grey Tider Gunner"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/ranged
	npc_site_table = /datum/human_npc_outfit_table/pirate/grey
	npc_outfit = null
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/grey/gunners
	npc_death_cash = 25

/mob/living/carbon/human/npc/ruin/faction_pirate/captain/grey
	npc_name = "Tidemaster"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/captain
	npc_site_table = /datum/human_npc_outfit_table/pirate/grey
	npc_outfit = /datum/outfit/piratecorpse/faction/grey/captain/armed
	npc_voice = /datum/human_npc_voice/ruin_faction_pirate/grey
	npc_loot_always = list(/obj/item/storage/toolbox/syndicate)

/mob/living/carbon/human/npc/ruin/faction_pirate/boss/grey
	npc_name = "The Robust One"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/robust
	npc_site_table = /datum/human_npc_outfit_table/pirate/grey
	npc_outfit = /datum/outfit/piratecorpse/faction/grey/robust/armed
	npc_voice = /datum/human_npc_voice/ruin_faction_pirate/grey
	npc_loot_always = list(/obj/item/stack/telecrystal/five)
	npc_loot_rare = list(/obj/item/storage/toolbox/mechanical/old/clean)

// ===== LUSTROUS =====

/mob/living/carbon/human/npc/ruin/faction_pirate/lustrous
	npc_name = "Lustrous Scintillant"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/melee
	npc_site_table = /datum/human_npc_outfit_table/pirate/lustrous
	npc_outfit = /datum/outfit/piratecorpse/faction/lustrous/melee/armed
	npc_death_cash = 300

/mob/living/carbon/human/npc/ruin/faction_pirate/lustrous/gunner
	npc_name = "Lustrous Coruscant"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/ranged
	npc_site_table = /datum/human_npc_outfit_table/pirate/lustrous
	npc_outfit = null
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/lustrous/gunners
	npc_death_cash = 25

/mob/living/carbon/human/npc/ruin/faction_pirate/captain/lustrous
	npc_name = "Lustrous Radiant"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/captain
	npc_site_table = /datum/human_npc_outfit_table/pirate/lustrous
	npc_outfit = /datum/outfit/piratecorpse/faction/lustrous/captain/armed

/mob/living/carbon/human/npc/ruin/faction_pirate/captain/lustrous/npc_zone_blade(zone)
	return zone_blade_for(zone)

/mob/living/carbon/human/npc/ruin/faction_pirate/boss/lustrous
	npc_name = "The Radiant One"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/radiant
	npc_site_table = /datum/human_npc_outfit_table/pirate/lustrous
	npc_outfit = /datum/outfit/piratecorpse/faction/lustrous/radiant/armed
	npc_loot_always = list(/obj/item/grenade/gas_crystal/nitrous_oxide_crystal)
	npc_loot_rare = list(/obj/item/cain_and_abel)

// ===== INTERDYNE =====

/mob/living/carbon/human/npc/ruin/faction_pirate/interdyne
	npc_name = "Interdyne Enforcer"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/melee
	npc_site_table = /datum/human_npc_outfit_table/pirate/interdyne
	npc_outfit = /datum/outfit/piratecorpse/faction/interdyne/melee/armed
	npc_death_cash = 300

/mob/living/carbon/human/npc/ruin/faction_pirate/interdyne/gunner
	npc_name = "Interdyne Pharmacist"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/ranged
	npc_site_table = /datum/human_npc_outfit_table/pirate/interdyne
	npc_outfit = null
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/interdyne/gunners
	npc_death_cash = 25

/mob/living/carbon/human/npc/ruin/faction_pirate/captain/interdyne
	npc_name = "Interdyne Director"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/captain
	npc_site_table = /datum/human_npc_outfit_table/pirate/interdyne
	npc_outfit = /datum/outfit/piratecorpse/faction/interdyne/captain/armed

/mob/living/carbon/human/npc/ruin/faction_pirate/captain/interdyne/npc_zone_blade(zone)
	return zone_blade_for(zone)

/mob/living/carbon/human/npc/ruin/faction_pirate/boss/interdyne
	npc_name = "Director Prime"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/prime
	npc_site_table = /datum/human_npc_outfit_table/pirate/interdyne
	npc_outfit = /datum/outfit/piratecorpse/faction/interdyne/prime/armed
	npc_loot_always = list(/obj/item/reagent_containers/hypospray/combat, /obj/item/gun/syringe/syndicate, /obj/item/grenade/gluon)

// ===== THE BLACK KNIGHT =====

/// Hates guns, as the basic mob did (tg's traits: he can't fire one, and throws them hard).
/mob/living/carbon/human/npc/ruin/faction_pirate/boss/medieval
	npc_name = "The Black Knight"
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/blackknight
	npc_site_table = /datum/human_npc_outfit_table/pirate/medieval
	npc_outfit = /datum/outfit/piratecorpse/faction/medieval/blackknight/armed
	npc_loot_always = list(/obj/item/claymore/shortsword, /obj/item/shield/kite)

/mob/living/carbon/human/npc/ruin/faction_pirate/boss/medieval/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	ADD_TRAIT(src, TRAIT_NOGUNS, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_TOSS_GUN_HARD, INNATE_TRAIT)
