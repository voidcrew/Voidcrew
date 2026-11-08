/**
 * # Human NPC ship crews
 *
 * The crews of NPC pirate hulls and the boarders they send are real human NPCs
 * (voidcrew/modules/human_npcs/): real bodies with real crit, stamina, wounds, cuffs, bleeding and
 * revival, holding the real weapons they fight with (human NPC migration, phase B). Their AI is PR #500's
 * pirate crew on the human base (pirate_crew_human.dm). The basic-mob faction pirates in
 * faction_pirate_mobs.dm stay for ruins, planets and missions until phase C moves those.
 *
 * Every faction keeps its PR #500 look, lines and guns:
 * - the look (species, hair, skin) comes from today's faction corpse spawner (npc_look), the clothes and
 *   weapons from the faction's outfit table (human_npc_outfits_pirates.dm), picked by crew_role and rank;
 * - a crewman holds the gun or blade its outfit gives it, with its spare magazines, shells or a knife;
 * - boarders cross space, so they are dressed from the faction's boarding table, which adds a sealed suit
 *   and air (bosses only take a mask and a tank: they keep their look and suffer a vented room as a player
 *   would);
 * - toughness comes from what they wear plus npc_damage_taken by rank (captains 0.8, bosses 0.6), never
 *   from a health pool;
 * - captains and bosses carry a real stimulant and inject it when their fight starts (the old stun
 *   immunity), Davy Jones drinks from a flask of cursed grog (his old regeneration), the Black Knight has
 *   tg's hulk and gigantism (his size and his shrugging off batons), the Radiant One is a real ethereal;
 * - medieval footsoldiers, the warlord and the Black Knight refuse guns (TRAIT_NOGUNS), as before;
 * - the designed loot rolls (the zone ladder, the red-zone 25% weapon, boss uniques, the plunder of 300,
 *   1000 or 3000 credits) drop once at death. What they wear and hold is locked to the body (D3) and
 *   never loot. The captain's ship key is not gear: it drops when he dies.
 *
 * Their ID card carries their name, so a crewman whose helmet hides his face is still "Silverscale
 * Duelist" and not "Unknown". It is locked gear like the rest and opens nothing.
 */

/// What a pirate ship crewman says when things happen to its body (human_npc_barks.dm)
/datum/human_npc_voice/pirate
	lines = list(
		HUMAN_NPC_BARK_DOWNED = list("I'm hit!", "Agh! Man down!", "Not like this..."),
		HUMAN_NPC_BARK_PLEAD = list("Don't... don't.", "Quarter... give quarter..."),
		HUMAN_NPC_BARK_RECOVER = list("Still breathing.", "Back on my feet."),
		HUMAN_NPC_BARK_CUFFED = list("Get these off me!", "You'll hang for this."),
		HUMAN_NPC_BARK_SLIPPING = list("Almost..."),
		HUMAN_NPC_BARK_PULLED_FREE = list("Hands off!"),
	)
	emotes = list(
		"stimulant" = list("jabs a needle into their neck."),
		"drink" = list("takes a long pull from a battered flask."),
	)

/mob/living/carbon/human/npc/ship_crew
	name = "spacer"
	faction = list(FACTION_PIRATE)
	ai_controller = /datum/ai_controller/basic_controller/pirate_crew/human
	npc_voice = /datum/human_npc_voice/pirate
	npc_target_stat = HUMAN_NPC_FINISHES_DOWNED
	/// SHIP_CREW_ROLE_MELEE or SHIP_CREW_ROLE_GUNNER: which of its faction's outfits a regular wears
	var/crew_role
	/// Its faction's table with a sealed suit added, for boarders (an outfit table typepath)
	var/datum/human_npc_outfit_table/boarding_outfit_table
	/// One line about it on examine, in character
	var/crew_desc
	/// What this faction shouts when its ship's crew goes on alert (pirate_crew.dm). Null: the generic lines.
	var/list/crew_alert_lines
	/// What it shouts when it spots someone. Null: the generic lines.
	var/list/crew_spot_lines

	// ===== Designed loot, as the basic faction pirates roll it (faction_pirate_mobs.dm) =====
	/// Always dropped
	var/list/loot_pool
	/// Each rolled once at spawn against npc_ladder_red_drop()
	var/list/rare_loot_pool
	/// What the rare roll gave
	var/list/rolled_rare_loot
	/// With any of these set, it drops one zone-laddered weapon (pirate_roll_ladder_weapon())
	var/list/random_loot = list(
		/obj/item/knife/combat/survival,
		/obj/item/spear,
		/obj/item/melee/baseball_bat,
	)
	/// One of these is always dropped
	var/list/random_loot_2 = list(
		/obj/item/storage/medkit/regular,
		/obj/item/storage/toolbox/mechanical,
		/obj/item/flashlight/seclite,
		/obj/item/reagent_containers/hypospray/medipen,
		/obj/item/stack/telecrystal,
	)
	/// A captain whose zone ladder drops a melee weapon (Silverscale, Lustrous and Interdyne captains)
	var/captain_ladder_melee = FALSE
	/// A named mission target pays its cash once, however often it dies
	var/datum/weakref/mission_payout_ref

	// ===== Elites and bosses =====
	/// The medipen it injects when its fight starts, or null. Elites and bosses get one by rank.
	var/obj/item/reagent_containers/hypospray/medipen/stimulant_type
	/// The NPC hull this is the boarding boss of; killing or taking it disables the hull
	var/obj/structure/overmap/ship/npc/pirate/parent_ship

/mob/living/carbon/human/npc/ship_crew/Initialize(mapload, datum/human_npc_order/order)
	switch(npc_rank)
		if(HUMAN_NPC_RANK_ELITE)
			// A type that sets its own toughness keeps it
			if(npc_damage_taken == 1)
				npc_damage_taken = SHIP_CREW_ELITE_DAMAGE_TAKEN
			stimulant_type ||= /obj/item/reagent_containers/hypospray/medipen/stimpack/traitor
		if(HUMAN_NPC_RANK_BOSS)
			if(npc_damage_taken == 1)
				npc_damage_taken = SHIP_CREW_BOSS_DAMAGE_TAKEN
	. = ..()
	rolled_rare_loot = list()
	for(var/item_type in rare_loot_pool)
		if(npc_ladder_red_drop())
			rolled_rare_loot += item_type
	crew_issue_id()
	if(stimulant_type)
		var/obj/item/stimulant = new stimulant_type(src)
		if(!crew_give(stimulant))
			qdel(stimulant)

/mob/living/carbon/human/npc/ship_crew/Destroy()
	parent_ship = null
	mission_payout_ref = null
	return ..()

/mob/living/carbon/human/npc/ship_crew/examine(mob/user)
	. = ..()
	if(crew_desc && stat != DEAD)
		. += span_notice(crew_desc)

/// An ID card with its name on it, so a helmet that hides its face doesn't make it "Unknown".
/mob/living/carbon/human/npc/ship_crew/proc/crew_issue_id()
	if(wear_id)
		return
	var/obj/item/card/id/advanced/black/card = new(src)
	card.registered_name = real_name
	card.assignment = real_name
	card.update_label()
	if(!equip_to_slot_if_possible(card, ITEM_SLOT_ID, disable_warning = TRUE))
		qdel(card)
		return
	npc_lock_item(card)

/**
 * Puts `thing` somewhere on its body it can take it from: a free pocket, else its backpack or belt.
 * Locks or issues it by the gear rules (a ship key isn't gear, a medipen is a consumable). Returns TRUE
 * if it is on the body; FALSE leaves it where it was, for the caller to deal with.
 */
/mob/living/carbon/human/npc/ship_crew/proc/crew_give(obj/item/thing)
	if(QDELETED(thing))
		return FALSE
	if(equip_to_slot_if_possible(thing, ITEM_SLOT_LPOCKET, disable_warning = TRUE) || equip_to_slot_if_possible(thing, ITEM_SLOT_RPOCKET, disable_warning = TRUE))
		npc_lock_item(thing)
		return TRUE
	for(var/obj/item/container in list(back, belt))
		if(container.atom_storage?.attempt_insert(thing, src, override = TRUE, messages = FALSE))
			npc_lock_item(thing)
			return TRUE
	return FALSE

// ===== Death and its designed drops =====

/mob/living/carbon/human/npc/ship_crew/npc_roll_death_loot()
	var/zone = npc_spawn_zone()
	. = list()
	if(length(loot_pool))
		. += loot_pool
	if(length(rolled_rare_loot))
		. += rolled_rare_loot
	if(length(random_loot))
		. += pirate_roll_ladder_weapon(zone)
	if(captain_ladder_melee)
		if(zone == ZONE_YELLOW)
			. += /obj/item/claymore/shortsword
		else if(zone == ZONE_RED)
			. += pick(npc_ladder_yellow_melee())
	if(length(random_loot_2))
		. += pick(random_loot_2)

/mob/living/carbon/human/npc/ship_crew/npc_drop_death_loot()
	// A named mission target pays its cash once for the mission, however many bodies it takes
	if(!npc_loot_dropped && npc_death_cash > 0 && mission_payout_ref)
		var/datum/mission/mission = mission_payout_ref.resolve()
		if(!mission?.claim_boss_cash())
			npc_death_cash = 0
	return ..()

/mob/living/carbon/human/npc/ship_crew/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(was_alive && stat == DEAD)
		crew_report_boss_down()

/// The hull this boarded for hears its boss is down (PI-22: the boss's fall disables the hull).
/mob/living/carbon/human/npc/ship_crew/proc/crew_report_boss_down()
	var/datum/ai_controller/npc_ship/controller = parent_ship?.ai_controller
	if(istype(controller))
		SEND_SIGNAL(controller, COMSIG_BOARDING_BOSS_KILLED, src)

// ===== The factions =====

// ----- Silverscale (aristocratic lizards) -----

/mob/living/carbon/human/npc/ship_crew/pirate
	name = "pirate"

/mob/living/carbon/human/npc/ship_crew/pirate/silverscale
	npc_name = "Silverscale Pirate"
	crew_desc = "An aristocratic lizard pirate demanding tribute from lesser beings."
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/silverscale
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/silverscale/boarding

/mob/living/carbon/human/npc/ship_crew/pirate/silverscale/Initialize(mapload, datum/human_npc_order/order)
	// The rank and file may be carrying a fish (as the basic duelists and marksmen do)
	if(crew_role)
		random_loot_2 = list(/obj/item/storage/medkit/regular, /obj/item/storage/toolbox/mechanical, random_fish_type())
	return ..()

/mob/living/carbon/human/npc/ship_crew/pirate/silverscale/melee
	npc_name = "Silverscale Duelist"
	crew_desc = "A noble lizard trained in the art of the blade."
	crew_role = SHIP_CREW_ROLE_MELEE
	npc_death_cash = 300

/mob/living/carbon/human/npc/ship_crew/pirate/silverscale/ranged
	npc_name = "Silverscale Marksman"
	crew_desc = "A noble lizard with impeccable aim."
	crew_role = SHIP_CREW_ROLE_GUNNER
	npc_death_cash = 25

/mob/living/carbon/human/npc/ship_crew/pirate/silverscale/captain
	npc_name = "Silverscale Noble"
	crew_desc = "A high-born lizard of impeccable breeding and ruthless ambition."
	npc_rank = HUMAN_NPC_RANK_ELITE
	random_loot = null
	captain_ladder_melee = TRUE
	npc_death_cash = 1000

/mob/living/carbon/human/npc/ship_crew/pirate/silverscale/boss
	npc_name = "Silverscale Highlord"
	crew_desc = "The supreme ruler of the Silverscale noble house. A master duelist who has slain countless challengers."
	npc_rank = HUMAN_NPC_RANK_BOSS
	npc_always_site = HUMAN_NPC_SITE_BAD_AIR
	stimulant_type = /obj/item/reagent_containers/hypospray/medipen/stimulants
	random_loot = null
	random_loot_2 = null
	loot_pool = list(/obj/item/clothing/suit/hooded/cloak/drake, /obj/item/clothing/head/hooded/cloakhood/drake)
	npc_death_cash = 3000

// ----- Skeleton (the Flying Dutchman) -----

/mob/living/carbon/human/npc/ship_crew/pirate/skeleton
	npc_name = "Skeleton Pirate"
	crew_desc = "Yarr! An undead scourge of the space lanes."
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/skeleton
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/skeleton/boarding
	crew_alert_lines = list(
		"All hands! Boarders!",
		"Fresh crew coming aboard!",
		"They'll fit right in. Eventually.",
	)
	crew_spot_lines = list(
		"There ye are!",
		"I see ye!",
		"Over here, lads!",
	)

/mob/living/carbon/human/npc/ship_crew/pirate/skeleton/melee
	npc_name = "Skeleton Swashbuckler"
	crew_desc = "A skeletal swordsman that refuses to stay dead."
	crew_role = SHIP_CREW_ROLE_MELEE
	npc_death_cash = 300

/mob/living/carbon/human/npc/ship_crew/pirate/skeleton/ranged
	npc_name = "Skeleton Gunner"
	crew_desc = "A skeletal marksman with hollow eyes."
	crew_role = SHIP_CREW_ROLE_GUNNER
	npc_death_cash = 25

/mob/living/carbon/human/npc/ship_crew/pirate/skeleton/captain
	npc_name = "Skeleton Captain"
	crew_desc = "The terrifying undead commander of the Flying Dutchman."
	npc_rank = HUMAN_NPC_RANK_ELITE
	loot_pool = list(/obj/item/gun/energy/laser)
	random_loot = null
	npc_death_cash = 1000

/// Davy Jones drinks cursed grog from the flask in his pocket when he is hurt (his old regeneration,
/// defaults PI-5).
/mob/living/carbon/human/npc/ship_crew/pirate/skeleton/boss
	npc_name = "Davy Jones"
	crew_desc = "Captain of the Flying Dutchman. His cursed compass always points to the greatest treasure... or the nearest victim."
	npc_rank = HUMAN_NPC_RANK_BOSS
	npc_always_site = HUMAN_NPC_SITE_BAD_AIR
	stimulant_type = /obj/item/reagent_containers/hypospray/medipen/stimulants
	random_loot = null
	random_loot_2 = null
	loot_pool = list(/obj/item/gun/ballistic/shotgun/hook)
	npc_death_cash = 3000

// ----- Grey Tide (rogue assistants) -----

/mob/living/carbon/human/npc/ship_crew/pirate/grey
	npc_name = "Grey Tider"
	crew_desc = "A former assistant turned space pirate. Robust."
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/grey
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/grey/boarding
	crew_alert_lines = list(
		"Someone's on the ship!",
		"Who let them in?",
		"They're after our stuff!",
	)
	crew_spot_lines = list(
		"Get 'em!",
		"That one, there!",
		"Over here!",
	)

/mob/living/carbon/human/npc/ship_crew/pirate/grey/melee
	crew_desc = "Armed with a toolbox and bad intentions."
	crew_role = SHIP_CREW_ROLE_MELEE
	npc_death_cash = 300

/mob/living/carbon/human/npc/ship_crew/pirate/grey/ranged
	npc_name = "Grey Tider Gunner"
	crew_desc = "An assistant with a gun. Uh oh."
	crew_role = SHIP_CREW_ROLE_GUNNER
	npc_death_cash = 25

/mob/living/carbon/human/npc/ship_crew/pirate/grey/captain
	npc_name = "Tidemaster"
	crew_desc = "If he's on your shift, the Captain does not have his spare."
	npc_rank = HUMAN_NPC_RANK_ELITE
	loot_pool = list(/obj/item/storage/toolbox/syndicate)
	random_loot = null
	npc_death_cash = 1000

/mob/living/carbon/human/npc/ship_crew/pirate/grey/boss
	npc_name = "The Robust One"
	crew_desc = "The ultimate assistant. The greyest tider to ever live. Their toolbox has seen things."
	npc_rank = HUMAN_NPC_RANK_BOSS
	npc_always_site = HUMAN_NPC_SITE_BAD_AIR
	stimulant_type = /obj/item/reagent_containers/hypospray/medipen/stimulants
	random_loot = null
	random_loot_2 = null
	loot_pool = list(/obj/item/stack/telecrystal/five)
	rare_loot_pool = list(/obj/item/storage/toolbox/mechanical/old/clean)
	npc_death_cash = 3000

/mob/living/carbon/human/npc/ship_crew/pirate/grey/boss/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	AddComponent(/datum/component/hv_finisher_user, /datum/hv_finisher/robust_one)

// ----- Lustrous (mutated ethereals) -----

// Real ethereals: they glow by their species, and a dead one's heart crystallises and revives it as a
// player's does, unless the crystal is broken (defaults PI-6).
/mob/living/carbon/human/npc/ship_crew/pirate/lustrous
	npc_name = "Lustrous Pirate"
	crew_desc = "A mutated ethereal obsessed with bluespace crystals."
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/lustrous
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/lustrous/boarding

/mob/living/carbon/human/npc/ship_crew/pirate/lustrous/melee
	npc_name = "Lustrous Scintillant"
	crew_desc = "A crystalline being with a sharp blade."
	crew_role = SHIP_CREW_ROLE_MELEE
	npc_death_cash = 300

/mob/living/carbon/human/npc/ship_crew/pirate/lustrous/ranged
	npc_name = "Lustrous Coruscant"
	crew_desc = "A crystalline being channeling energy through strange weapons."
	crew_role = SHIP_CREW_ROLE_GUNNER
	npc_death_cash = 25

/mob/living/carbon/human/npc/ship_crew/pirate/lustrous/captain
	npc_name = "Lustrous Radiant"
	crew_desc = "A blindingly bright ethereal, the leader of their crystalline kind."
	npc_rank = HUMAN_NPC_RANK_ELITE
	random_loot = null
	captain_ladder_melee = TRUE
	npc_death_cash = 1000

/mob/living/carbon/human/npc/ship_crew/pirate/lustrous/boss
	npc_name = "The Radiant One"
	crew_desc = "A blindingly luminous ethereal. The crystalline matrix of their body phases in and out of realspace."
	npc_rank = HUMAN_NPC_RANK_BOSS
	npc_always_site = HUMAN_NPC_SITE_BAD_AIR
	stimulant_type = /obj/item/reagent_containers/hypospray/medipen/stimulants
	random_loot = null
	random_loot_2 = null
	loot_pool = list(/obj/item/grenade/gas_crystal/nitrous_oxide_crystal)
	rare_loot_pool = list(/obj/item/cain_and_abel)
	npc_death_cash = 3000

// ----- Interdyne (ex-pharmacists) -----

/mob/living/carbon/human/npc/ship_crew/pirate/interdyne
	npc_name = "Interdyne Pirate"
	crew_desc = "A former pharmaceutical employee turned bioterrorist."
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/interdyne
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/interdyne/boarding

/mob/living/carbon/human/npc/ship_crew/pirate/interdyne/melee
	npc_name = "Interdyne Enforcer"
	crew_desc = "Enforces pharmaceutical compliance with surgical precision."
	crew_role = SHIP_CREW_ROLE_MELEE
	npc_death_cash = 300

/mob/living/carbon/human/npc/ship_crew/pirate/interdyne/ranged
	npc_name = "Interdyne Pharmacist"
	crew_desc = "Dispenses death instead of medicine."
	crew_role = SHIP_CREW_ROLE_GUNNER
	npc_death_cash = 25

/mob/living/carbon/human/npc/ship_crew/pirate/interdyne/captain
	npc_name = "Interdyne Director"
	crew_desc = "The head of this rogue pharmaceutical operation."
	npc_rank = HUMAN_NPC_RANK_ELITE
	random_loot = null
	captain_ladder_melee = TRUE
	npc_death_cash = 1000

/mob/living/carbon/human/npc/ship_crew/pirate/interdyne/boss
	npc_name = "Director Prime"
	crew_desc = "The head of all Interdyne black site operations. Their hypospray contains experimental compounds."
	npc_rank = HUMAN_NPC_RANK_BOSS
	npc_always_site = HUMAN_NPC_SITE_BAD_AIR
	stimulant_type = /obj/item/reagent_containers/hypospray/medipen/stimulants
	random_loot = null
	random_loot_2 = null
	loot_pool = list(/obj/item/reagent_containers/hypospray/combat, /obj/item/gun/syringe/syndicate, /obj/item/grenade/gluon)
	npc_death_cash = 3000

// ----- IRS (tax collectors) -----

/mob/living/carbon/human/npc/ship_crew/pirate/irs
	npc_name = "IRS Agent"
	crew_desc = "The only thing certain in life is death and taxes. They're here for both."
	faction = list(FACTION_PIRATE, FACTION_IRS)
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/irs
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/irs/boarding
	crew_alert_lines = list(
		"Unscheduled visitors. Begin the audit.",
		"Everyone aboard is now under review.",
		"Intruders on deck. Find them.",
	)
	crew_spot_lines = list(
		"There's the taxpayer!",
		"Stop right there.",
		"You're overdue.",
	)

/mob/living/carbon/human/npc/ship_crew/pirate/irs/melee
	npc_name = "IRS Enforcer"
	crew_desc = "Collects taxes the hard way."
	crew_role = SHIP_CREW_ROLE_MELEE
	npc_death_cash = 300

/mob/living/carbon/human/npc/ship_crew/pirate/irs/ranged
	crew_desc = "Armed and ready to collect."
	crew_role = SHIP_CREW_ROLE_GUNNER
	npc_death_cash = 25

/mob/living/carbon/human/npc/ship_crew/pirate/irs/captain
	npc_name = "IRS Head Auditor"
	crew_desc = "The head of tax enforcement. Nobody escapes their audits."
	npc_rank = HUMAN_NPC_RANK_ELITE
	loot_pool = list(/obj/item/gun/energy/laser)
	random_loot = null
	npc_death_cash = 1000

/mob/living/carbon/human/npc/ship_crew/pirate/irs/boss
	npc_name = "Chief Auditor"
	crew_desc = "The supreme authority of the Space IRS. No one escapes their audits. NO ONE."
	npc_rank = HUMAN_NPC_RANK_BOSS
	npc_always_site = HUMAN_NPC_SITE_BAD_AIR
	// Carried in the outfit: the chief has no bag to put one in
	stimulant_type = null
	random_loot = null
	random_loot_2 = null
	loot_pool = list(/obj/item/gun/energy/laser, /obj/item/storage/bag/money/dutchmen)
	npc_death_cash = 3000

// ----- Medieval (space warmongers) -----

/mob/living/carbon/human/npc/ship_crew/pirate/medieval
	npc_name = "Medieval Pirate"
	crew_desc = "A space-faring knight who somehow operates a starship."
	npc_look = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval
	npc_outfit_table = /datum/human_npc_outfit_table/pirate/medieval
	boarding_outfit_table = /datum/human_npc_outfit_table/pirate/medieval/boarding
	crew_alert_lines = list(
		"To arms! Intruders!",
		"Who dares board us?",
		"Defend the ship!",
	)
	crew_spot_lines = list(
		"Have at thee!",
		"There, the coward!",
		"Halt!",
	)
	/// Hates guns and throws them hard (footsoldiers, the warlord and the Black Knight; not the crossbowmen)
	var/refuses_guns = FALSE

/mob/living/carbon/human/npc/ship_crew/pirate/medieval/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	if(refuses_guns)
		add_traits(list(TRAIT_NOGUNS, TRAIT_TOSS_GUN_HARD), INNATE_TRAIT)

/mob/living/carbon/human/npc/ship_crew/pirate/medieval/melee
	npc_name = "Medieval Footsoldier"
	crew_desc = "A knight who refuses to use guns. Honorable."
	crew_role = SHIP_CREW_ROLE_MELEE
	refuses_guns = TRUE
	npc_death_cash = 300

/mob/living/carbon/human/npc/ship_crew/pirate/medieval/ranged
	npc_name = "Medieval Crossbowman"
	crew_desc = "At least crossbows are period-appropriate. Sort of."
	crew_role = SHIP_CREW_ROLE_GUNNER
	npc_death_cash = 25

/// The warlord: plate armour and a stimulant where the basic mob had stun immunity (defaults PI-4).
/mob/living/carbon/human/npc/ship_crew/pirate/medieval/captain
	npc_name = "Medieval Warlord"
	crew_desc = "A hulking brute of a knight. Massive, and very angry."
	npc_rank = HUMAN_NPC_RANK_ELITE
	refuses_guns = TRUE
	stimulant_type = /obj/item/reagent_containers/hypospray/medipen/stimulants
	loot_pool = list(/obj/item/fireaxe)
	random_loot = null
	npc_death_cash = 1000

/// The Black Knight: tg's hulk (stun and shove immune until he drops into crit) and gigantism (his size).
/mob/living/carbon/human/npc/ship_crew/pirate/medieval/boss
	npc_name = "The Black Knight"
	crew_desc = "A massive armored warrior. 'Tis but a scratch!' No really, they refuse to die."
	npc_rank = HUMAN_NPC_RANK_BOSS
	npc_damage_taken = 0.5
	npc_always_site = HUMAN_NPC_SITE_BAD_AIR
	refuses_guns = TRUE
	random_loot = null
	random_loot_2 = null
	loot_pool = list(/obj/item/claymore/shortsword, /obj/item/shield/kite)
	npc_death_cash = 3000

/mob/living/carbon/human/npc/ship_crew/pirate/medieval/boss/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	dna.add_mutation(/datum/mutation/hulk, MUTATION_SOURCE_MUTATOR)
	dna.add_mutation(/datum/mutation/gigantism, MUTATION_SOURCE_MUTATOR)
	AddComponent(/datum/component/hv_finisher_user, /datum/hv_finisher/black_knight)

// ===== Boss kit =====

/// Davy Jones's flask. Locked to him like the rest of his kit (D3).
/obj/item/reagent_containers/cup/glass/flask/davy_jones
	name = "battered flask"
	desc = "A dented pewter flask. Whatever is in it smells of the deep."
	list_reagents = list(/datum/reagent/medicine/omnizine/cursed_grog = 40)

/**
 * Cursed grog: knits flesh while it is in the blood, with a cold blue glow. Never synthesised, never
 * overdosed. Like any reagent it can be purged, and the flask runs dry.
 */
/datum/reagent/medicine/omnizine/cursed_grog
	name = "Cursed Grog"
	description = "Sea water and something older. It knits flesh back together while it lasts."
	color = "#2a4a7a"
	taste_description = "brine and old rum"
	healing = 3
	overdose_threshold = 0
	chemical_flags = NONE

/datum/reagent/medicine/omnizine/cursed_grog/on_mob_metabolize(mob/living/affected_mob)
	. = ..()
	affected_mob.add_filter("cursed_grog", 2, outline_filter(1, "#4488FF"))

/datum/reagent/medicine/omnizine/cursed_grog/on_mob_end_metabolize(mob/living/affected_mob)
	. = ..()
	affected_mob.remove_filter("cursed_grog")

/// The Robust One's toolbox: the old blue toolbox, with the telecrystals inside that make it hit harder.
/obj/item/storage/toolbox/mechanical/old/clean/robust_one
	attack_verb_continuous = list("ROBUSTS")
	attack_verb_simple = list("ROBUST")

/obj/item/storage/toolbox/mechanical/old/clean/robust_one/PopulateContents()
	. = ..()
	new /obj/item/stack/telecrystal(src, 6)

/// Davy Jones's cutlass.
/obj/item/claymore/cutlass/davy_jones
	attack_verb_continuous = list("curses", "slashes", "cuts")
	attack_verb_simple = list("curse", "slash", "cut")

/// The Black Knight's claymore.
/obj/item/claymore/black_knight
	attack_verb_continuous = list("smites", "cleaves", "hews")
	attack_verb_simple = list("smite", "cleave", "hew")

/// The warlord's boarding axe.
/obj/item/fireaxe/boardingaxe/warlord
	attack_verb_continuous = list("crushes", "cleaves", "hacks")
	attack_verb_simple = list("crush", "cleave", "hack")

/// An energy cutlass with a boss's own attack verbs.
/obj/item/melee/energy/sword/pirate/boss
	/// Verbs while lit
	var/list/boss_verbs_continuous = list("eviscerates")
	var/list/boss_verbs_simple = list("eviscerate")

/obj/item/melee/energy/sword/pirate/boss/make_transformable()
	AddComponent( \
		/datum/component/transforming, \
		force_on = active_force, \
		throwforce_on = active_throwforce, \
		throw_speed_on = 4, \
		sharpness_on = active_sharpness, \
		hitsound_on = active_hitsound, \
		w_class_on = active_w_class, \
		attack_verb_continuous_on = boss_verbs_continuous, \
		attack_verb_simple_on = boss_verbs_simple, \
	)
	RegisterSignal(src, COMSIG_TRANSFORMING_ON_TRANSFORM, PROC_REF(on_transform))

/// The Radiant One's cutlass.
/obj/item/melee/energy/sword/pirate/boss/radiant
	boss_verbs_continuous = list("phases through", "slashes")
	boss_verbs_simple = list("phase through", "slash")

// ===== Dressing by role, and for boarding =====

// A crewman of the rank and file wears its role's outfits from its faction's table
// (voidcrew/modules/human_npcs/human_npc_outfits_pirates.dm): a duelist the faction's blades, a marksman
// its guns in PR #500's gun weights. Captains and bosses wear their own.
/datum/human_npc_outfit_table/pirate/outfits_for(mob/living/carbon/human/npc/npc, zone)
	var/mob/living/carbon/human/npc/ship_crew/crewman = npc
	if(istype(crewman) && crewman.npc_rank == HUMAN_NPC_RANK_REGULAR)
		switch(crewman.crew_role)
			if(SHIP_CREW_ROLE_MELEE)
				if(length(melee) && !gunners_only)
					return melee
			if(SHIP_CREW_ROLE_GUNNER)
				if(length(gunners))
					return gunners
	return ..()

// Boarders cross space and may land in a vented room, so they wear a sealed suit and carry air
// (always_site, human_npc_outfits.dm). Skeletons need neither and are left as they are.
/datum/human_npc_outfit_table/pirate/silverscale/boarding
	always_site = HUMAN_NPC_SITE_VACUUM

/datum/human_npc_outfit_table/pirate/skeleton/boarding
	always_site = HUMAN_NPC_SITE_VACUUM

/datum/human_npc_outfit_table/pirate/grey/boarding
	always_site = HUMAN_NPC_SITE_VACUUM

/datum/human_npc_outfit_table/pirate/lustrous/boarding
	always_site = HUMAN_NPC_SITE_VACUUM

/datum/human_npc_outfit_table/pirate/interdyne/boarding
	always_site = HUMAN_NPC_SITE_VACUUM

/datum/human_npc_outfit_table/pirate/irs/boarding
	always_site = HUMAN_NPC_SITE_VACUUM

/datum/human_npc_outfit_table/pirate/medieval/boarding
	always_site = HUMAN_NPC_SITE_VACUUM
