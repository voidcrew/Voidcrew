/**
 * # Troopers as human NPCs: pirates, Syndicate operatives, Nanotrasen security, Russian mobsters
 *
 * The human versions of tg's /mob/living/basic/trooper families placed in Voidcrew ruins, ruin shuttles,
 * beaches and zone markers. Each keeps its trooper's name, faction and look (today's corpse outfits),
 * holds the weapon the trooper only drew, and carries real spare ammunition.
 *
 * Zones (/datum/human_npc_outfit_table/ruin): green wears what the trooper wore; yellow adds armour; red
 * adds a helmet and a medipen. The trooper weapon ladder (voidcrew/edits/mobs/weapon_drops.dm) lives in
 * the tables: Syndicate SMGs and shotguns, and the Nanotrasen guns, are pistols outside the red zone, and
 * the Syndicate sword guard has only a knife in the green.
 *
 * Designed drops stay as the troopers had them: only the Russians carried any (a kitchen knife, a Nagant
 * revolver). Their clothes and guns are gear (decision D3) and never loot. The pirates' coin-snatching
 * hits are gone: an NPC hits like a person.
 */

// ===== VOICES =====

/datum/human_npc_voice/ruin_pirate
	lines = list(
		RUIN_NPC_BARK_SPOT = list("Yarr! Fresh meat!", "Ahoy, landlubber!", "Cut 'em down!", "Avast!"),
		HUMAN_NPC_BARK_DOWNED = list("Arr... me guts...", "Not like this..."),
		HUMAN_NPC_BARK_RECOVER = list("Still breathin'!", "That all ye got?"),
		HUMAN_NPC_BARK_PLEAD = list("Mercy, matey..."),
		HUMAN_NPC_BARK_CUFFED = list("Ye'll hang for this."),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
	)
	chances = list(RUIN_NPC_BARK_SPOT = 60)

/datum/human_npc_voice/ruin_syndicate
	lines = list(
		RUIN_NPC_BARK_SPOT = list("Contact!", "Hostile sighted.", "Engaging.", "Death to Nanotrasen!"),
		HUMAN_NPC_BARK_DOWNED = list("Man down...", "I'm hit..."),
		HUMAN_NPC_BARK_RECOVER = list("Back in it.", "Still in the fight."),
		HUMAN_NPC_BARK_CUFFED = list("I'm not telling you anything."),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
	)
	chances = list(RUIN_NPC_BARK_SPOT = 50)

/datum/human_npc_voice/ruin_nanotrasen
	lines = list(
		RUIN_NPC_BARK_SPOT = list("Halt! Private security!", "Hostile in sight.", "Stop right there!"),
		HUMAN_NPC_BARK_DOWNED = list("Officer down...", "Need a medic..."),
		HUMAN_NPC_BARK_RECOVER = list("Still standing."),
		HUMAN_NPC_BARK_CUFFED = list("You'll answer to Central for this."),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
	)
	chances = list(RUIN_NPC_BARK_SPOT = 50)

/datum/human_npc_voice/ruin_russian
	lines = list(
		RUIN_NPC_BARK_SPOT = list("Hey! You!", "Who let you in?", "For the Motherland!"),
		HUMAN_NPC_BARK_DOWNED = list("Ugh... not good...", "Someone... help..."),
		HUMAN_NPC_BARK_RECOVER = list("Is that all?"),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
	)
	chances = list(RUIN_NPC_BARK_SPOT = 50)

// ===== FAMILY ROOT =====

/mob/living/carbon/human/npc/ruin/trooper
	name = "trooper"

// ===== SPACE PIRATES (tg's pirate troopers) =====

/datum/outfit/ruin_npc
	name = "Ruin NPC"

/// The swashbuckler: a pirate's rags, an eyepatch and an energy cutlass.
/datum/outfit/ruin_npc/pirate
	name = "Ruin NPC: pirate swashbuckler"
	uniform = /obj/item/clothing/under/costume/pirate
	shoes = /obj/item/clothing/shoes/jackboots
	glasses = /obj/item/clothing/glasses/eyepatch
	head = /obj/item/clothing/head/costume/pirate/bandana/armored
	r_hand = /obj/item/melee/energy/sword/pirate

/datum/outfit/ruin_npc/pirate/coat
	name = "Ruin NPC: pirate swashbuckler in a coat"
	suit = /obj/item/clothing/suit/costume/pirate/armored

/datum/outfit/ruin_npc/pirate/coat/red
	name = "Ruin NPC: pirate swashbuckler, red zone"
	gloves = /obj/item/clothing/gloves/color/black
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// The gunner: a laser gun and the armoured captain's hat.
/datum/outfit/ruin_npc/pirate/gunner
	name = "Ruin NPC: pirate gunner"
	head = /obj/item/clothing/head/costume/pirate/armored
	r_hand = /obj/item/gun/energy/laser

/datum/outfit/ruin_npc/pirate/gunner/coat
	name = "Ruin NPC: pirate gunner in a coat"
	suit = /obj/item/clothing/suit/costume/pirate/armored

/datum/outfit/ruin_npc/pirate/gunner/coat/red
	name = "Ruin NPC: pirate gunner, red zone"
	gloves = /obj/item/clothing/gloves/color/black
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// Space pirates fight in breached hulls: the pirate space suit and its own air.
/datum/outfit/ruin_npc/pirate/space
	name = "Ruin NPC: space pirate swashbuckler"
	suit = /obj/item/clothing/suit/space/pirate
	head = /obj/item/clothing/head/helmet/space/pirate/bandana
	gloves = /obj/item/clothing/gloves/color/black
	suit_store = /obj/item/tank/internals/oxygen
	internals_slot = ITEM_SLOT_SUITSTORE

/datum/outfit/ruin_npc/pirate/space/red
	name = "Ruin NPC: space pirate swashbuckler, red zone"
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/datum/outfit/ruin_npc/pirate/space/gunner
	name = "Ruin NPC: space pirate gunner"
	head = /obj/item/clothing/head/helmet/space/pirate
	r_hand = /obj/item/gun/energy/e_gun/lethal

/datum/outfit/ruin_npc/pirate/space/gunner/red
	name = "Ruin NPC: space pirate gunner, red zone"
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// Timothy, the pirate cosplayer locked in the Hightide's kitchen: the costume, not the armour.
/datum/outfit/ruin_npc/pirate/cosplayer
	name = "Ruin NPC: pirate cosplayer"
	head = /obj/item/clothing/head/costume/pirate
	suit = /obj/item/clothing/suit/costume/pirate
	shoes = /obj/item/clothing/shoes/sneakers/black
	r_hand = /obj/item/gun/energy/laser

/datum/human_npc_outfit_table/ruin/pirate
	vacuum_layer = /datum/human_npc_layer/eva/pirate
	green = list(/datum/outfit/ruin_npc/pirate = 1)
	yellow = list(/datum/outfit/ruin_npc/pirate/coat = 1)
	red = list(/datum/outfit/ruin_npc/pirate/coat/red = 1)

/datum/human_npc_outfit_table/ruin/pirate/gunner
	green = list(/datum/outfit/ruin_npc/pirate/gunner = 1)
	yellow = list(/datum/outfit/ruin_npc/pirate/gunner/coat = 1)
	red = list(/datum/outfit/ruin_npc/pirate/gunner/coat/red = 1)

/datum/human_npc_outfit_table/ruin/pirate/space
	green = list(/datum/outfit/ruin_npc/pirate/space = 1)
	yellow = list(/datum/outfit/ruin_npc/pirate/space = 1)
	red = list(/datum/outfit/ruin_npc/pirate/space/red = 1)

/datum/human_npc_outfit_table/ruin/pirate/space/gunner
	green = list(/datum/outfit/ruin_npc/pirate/space/gunner = 1)
	yellow = list(/datum/outfit/ruin_npc/pirate/space/gunner = 1)
	red = list(/datum/outfit/ruin_npc/pirate/space/gunner/red = 1)

/mob/living/carbon/human/npc/ruin/trooper/pirate
	npc_name = "Pirate Swashbuckler"
	faction = list(FACTION_PIRATE)
	npc_voice = /datum/human_npc_voice/ruin_pirate
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/pirate

/mob/living/carbon/human/npc/ruin/trooper/pirate/gunner
	npc_name = "Pirate Gunner"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/pirate/gunner

/mob/living/carbon/human/npc/ruin/trooper/pirate/space
	npc_name = "Space Pirate Swashbuckler"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/pirate/space

/mob/living/carbon/human/npc/ruin/trooper/pirate/space/gunner
	npc_name = "Space Pirate Gunner"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/pirate/space/gunner

/// The beach's own pirates, sided with the shore's wildlife: the barrel spawners' crews, and the boat
/// pirates of the deep water, who now wade (the old boat sprite was this same costume in a boat).
/mob/living/carbon/human/npc/ruin/trooper/pirate/beach
	faction = list(FACTION_BEACH)

/mob/living/carbon/human/npc/ruin/trooper/pirate/beach/gunner
	npc_name = "Pirate Gunner"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/pirate/gunner

/// Timothy. He survived on the rats, which shows: he goes down twice as fast as anyone else.
/mob/living/carbon/human/npc/ruin/trooper/pirate/cosplayer
	npc_name = "Timothy"
	npc_outfit_table = null
	npc_outfit = /datum/outfit/ruin_npc/pirate/cosplayer
	npc_damage_taken = 2

// ===== SYNDICATE OPERATIVES =====

/// A Syndicate operative with a knife.
/datum/outfit/ruin_npc/syndicate
	name = "Ruin NPC: Syndicate operative"
	uniform = /obj/item/clothing/under/syndicate
	shoes = /obj/item/clothing/shoes/combat
	gloves = /obj/item/clothing/gloves/combat
	r_hand = /obj/item/knife/combat/survival

/datum/outfit/ruin_npc/syndicate/vest
	name = "Ruin NPC: Syndicate operative in a vest"
	suit = /obj/item/clothing/suit/armor/vest

/datum/outfit/ruin_npc/syndicate/vest/helmet
	name = "Ruin NPC: Syndicate operative, red zone"
	head = /obj/item/clothing/head/helmet/swat
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// The sword guard: an energy sword and an energy shield.
/datum/outfit/ruin_npc/syndicate/vest/sword
	name = "Ruin NPC: Syndicate sword guard"
	r_hand = /obj/item/melee/energy/sword/saber/red
	l_hand = /obj/item/shield/energy

/datum/outfit/ruin_npc/syndicate/vest/sword/helmet
	name = "Ruin NPC: Syndicate sword guard, red zone"
	head = /obj/item/clothing/head/helmet/swat
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// A Makarov and two spare magazines.
/datum/outfit/ruin_npc/syndicate/pistol
	name = "Ruin NPC: Syndicate gunner"
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/ruin_npc/syndicate/pistol/vest
	name = "Ruin NPC: Syndicate gunner in a vest"
	suit = /obj/item/clothing/suit/armor/vest

/datum/outfit/ruin_npc/syndicate/pistol/vest/helmet
	name = "Ruin NPC: Syndicate gunner, red zone"
	head = /obj/item/clothing/head/helmet/swat
	belt = /obj/item/storage/belt/military
	belt_contents = list(/obj/item/reagent_containers/hypospray/medipen = 1)

/// The C-20r, in the red zone only.
/datum/outfit/ruin_npc/syndicate/pistol/vest/helmet/smg
	name = "Ruin NPC: Syndicate SMG gunner"
	r_hand = /obj/item/gun/ballistic/automatic/c20r/unrestricted
	l_pocket = /obj/item/ammo_box/magazine/smgm45
	r_pocket = /obj/item/ammo_box/magazine/smgm45

/// The Bulldog, in the red zone only.
/datum/outfit/ruin_npc/syndicate/pistol/vest/helmet/shotgun
	name = "Ruin NPC: Syndicate shotgunner"
	r_hand = /obj/item/gun/ballistic/shotgun/bulldog/unrestricted
	l_pocket = /obj/item/ammo_box/magazine/m12g
	r_pocket = /obj/item/ammo_box/magazine/m12g

/// The salvage pilots of the caravan ambush: flight scarf and goggles over the armour.
/datum/outfit/ruin_npc/syndicate/pistol/pilot
	name = "Ruin NPC: Syndicate salvage pilot"
	suit = /obj/item/clothing/suit/armor/vest/alt
	neck = /obj/item/clothing/neck/large_scarf/syndie
	glasses = /obj/item/clothing/glasses/cold

/datum/outfit/ruin_npc/syndicate/pistol/pilot/smg
	name = "Ruin NPC: Syndicate salvage pilot, red zone"
	head = /obj/item/clothing/head/helmet/swat
	r_hand = /obj/item/gun/ballistic/automatic/c20r/unrestricted
	l_pocket = /obj/item/ammo_box/magazine/smgm45
	r_pocket = /obj/item/ammo_box/magazine/smgm45

/// Commandos: the black Syndicate space suit and its own air.
/datum/outfit/ruin_npc/syndicate/commando
	name = "Ruin NPC: Syndicate commando"
	suit = /obj/item/clothing/suit/space/syndicate/black
	head = /obj/item/clothing/head/helmet/space/syndicate/black
	suit_store = /obj/item/tank/internals/oxygen
	internals_slot = ITEM_SLOT_SUITSTORE

/datum/outfit/ruin_npc/syndicate/commando/red
	name = "Ruin NPC: Syndicate commando, red zone"
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/datum/outfit/ruin_npc/syndicate/commando/pistol
	name = "Ruin NPC: Syndicate commando gunner"
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/ruin_npc/syndicate/commando/pistol/red
	name = "Ruin NPC: Syndicate commando gunner, red zone"
	belt = /obj/item/storage/belt/military
	belt_contents = list(/obj/item/reagent_containers/hypospray/medipen = 1)

/datum/outfit/ruin_npc/syndicate/commando/pistol/red/smg
	name = "Ruin NPC: Syndicate commando SMG gunner"
	r_hand = /obj/item/gun/ballistic/automatic/c20r/unrestricted
	l_pocket = /obj/item/ammo_box/magazine/smgm45
	r_pocket = /obj/item/ammo_box/magazine/smgm45

/datum/outfit/ruin_npc/syndicate/commando/pistol/red/shotgun
	name = "Ruin NPC: Syndicate commando shotgunner"
	r_hand = /obj/item/gun/ballistic/shotgun/bulldog/unrestricted
	l_pocket = /obj/item/ammo_box/magazine/m12g
	r_pocket = /obj/item/ammo_box/magazine/m12g

/datum/outfit/ruin_npc/syndicate/commando/sword
	name = "Ruin NPC: Syndicate commando sword guard"
	r_hand = /obj/item/melee/energy/sword/saber/red
	l_hand = /obj/item/shield/energy

/// Stormtroopers: the blood-red Syndicate space suit.
/datum/outfit/ruin_npc/syndicate/commando/stormtrooper
	name = "Ruin NPC: Syndicate stormtrooper"
	suit = /obj/item/clothing/suit/space/syndicate/black/red
	head = /obj/item/clothing/head/helmet/space/syndicate/black/red
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/smg
	name = "Ruin NPC: Syndicate stormtrooper SMG gunner"
	r_hand = /obj/item/gun/ballistic/automatic/c20r/unrestricted
	l_pocket = /obj/item/ammo_box/magazine/smgm45
	r_pocket = /obj/item/ammo_box/magazine/smgm45
	belt = /obj/item/storage/belt/military
	belt_contents = list(/obj/item/reagent_containers/hypospray/medipen = 1)

/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/shotgun
	name = "Ruin NPC: Syndicate stormtrooper shotgunner"
	r_hand = /obj/item/gun/ballistic/shotgun/bulldog/unrestricted
	l_pocket = /obj/item/ammo_box/magazine/m12g
	r_pocket = /obj/item/ammo_box/magazine/m12g
	belt = /obj/item/storage/belt/military
	belt_contents = list(/obj/item/reagent_containers/hypospray/medipen = 1)

/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/sword
	name = "Ruin NPC: Syndicate stormtrooper sword guard"
	r_hand = /obj/item/melee/energy/sword/saber/red
	l_hand = /obj/item/shield/energy
	l_pocket = /obj/item/reagent_containers/hypospray/medipen
	r_pocket = null

/// Operatives on the ice wear the Syndicate's armoured explorer suit over their kit.
/datum/human_npc_layer/cold/coat/syndicate
	suit = /obj/item/clothing/suit/hooded/explorer/syndicate

/datum/human_npc_outfit_table/ruin/syndicate
	vacuum_layer = /datum/human_npc_layer/eva/syndicate
	cold_layer = /datum/human_npc_layer/cold/coat/syndicate
	green = list(/datum/outfit/ruin_npc/syndicate = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/vest = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/vest/helmet = 1)

/// The sword guard has only a knife in the green zone (the trooper weapon ladder).
/datum/human_npc_outfit_table/ruin/syndicate/sword
	green = list(/datum/outfit/ruin_npc/syndicate = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/vest/sword = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/vest/sword/helmet = 1)

/datum/human_npc_outfit_table/ruin/syndicate/pistol
	green = list(/datum/outfit/ruin_npc/syndicate/pistol = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/pistol/vest = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/pistol/vest/helmet = 1)

/// SMGs and shotguns are pistols outside the red zone (the trooper weapon ladder).
/datum/human_npc_outfit_table/ruin/syndicate/pistol/smg
	red = list(/datum/outfit/ruin_npc/syndicate/pistol/vest/helmet/smg = 1)

/datum/human_npc_outfit_table/ruin/syndicate/pistol/shotgun
	red = list(/datum/outfit/ruin_npc/syndicate/pistol/vest/helmet/shotgun = 1)

/datum/human_npc_outfit_table/ruin/syndicate/pilot
	green = list(/datum/outfit/ruin_npc/syndicate/pistol/pilot = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/pistol/pilot = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/pistol/pilot/smg = 1)

/datum/human_npc_outfit_table/ruin/syndicate/commando
	green = list(/datum/outfit/ruin_npc/syndicate/commando = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/commando = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/commando/red = 1)

/datum/human_npc_outfit_table/ruin/syndicate/commando/pistol
	green = list(/datum/outfit/ruin_npc/syndicate/commando/pistol = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/commando/pistol = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/commando/pistol/red = 1)

/datum/human_npc_outfit_table/ruin/syndicate/commando/smg
	green = list(/datum/outfit/ruin_npc/syndicate/commando/pistol = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/commando/pistol = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/commando/pistol/red/smg = 1)

/// Stormtroopers are elites but follow the zone ladder like the regulars, so their tables pick by zone
/// alone: SMG stormtroopers carry pistols in the green zone, shotgunners outside the red.
/datum/human_npc_outfit_table/ruin/syndicate/stormtrooper

/datum/human_npc_outfit_table/ruin/syndicate/stormtrooper/outfits_for(mob/living/carbon/human/npc/npc, zone)
	if(zone == ZONE_RED && length(red))
		return red
	if(zone >= ZONE_YELLOW && length(yellow))
		return yellow
	return green

/datum/human_npc_outfit_table/ruin/syndicate/stormtrooper/smg
	green = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/smg = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/smg = 1)

/datum/human_npc_outfit_table/ruin/syndicate/stormtrooper/shotgun
	green = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/shotgun = 1)

/datum/human_npc_outfit_table/ruin/syndicate/stormtrooper/sword
	green = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/sword = 1)
	yellow = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/sword = 1)
	red = list(/datum/outfit/ruin_npc/syndicate/commando/stormtrooper/sword = 1)

/// Space Syndicate kit: the black suit.
/datum/human_npc_layer/eva/syndicate
	suit = /obj/item/clothing/suit/space/syndicate/black
	head = /obj/item/clothing/head/helmet/space/syndicate/black

/mob/living/carbon/human/npc/ruin/trooper/syndicate
	npc_name = "Syndicate Operative"
	faction = list(ROLE_SYNDICATE)
	npc_voice = /datum/human_npc_voice/ruin_syndicate
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate

/mob/living/carbon/human/npc/ruin/trooper/syndicate/sword
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/sword

/mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/pistol

/mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/smg
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/pistol/smg

/mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/shotgun
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/pistol/shotgun

/mob/living/carbon/human/npc/ruin/trooper/syndicate/gunner/pilot
	npc_name = "Syndicate Salvage Pilot"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/pilot

/mob/living/carbon/human/npc/ruin/trooper/syndicate/commando
	npc_name = "Syndicate Commando"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/commando

/mob/living/carbon/human/npc/ruin/trooper/syndicate/commando/gunner
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/commando/pistol

/mob/living/carbon/human/npc/ruin/trooper/syndicate/commando/smg
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/commando/smg

/// Stormtroopers: elites in the blood-red suit. They take a fifth less brute and burn, and land aimed hits.
/mob/living/carbon/human/npc/ruin/trooper/syndicate/stormtrooper
	npc_name = "Syndicate Stormtrooper"
	npc_rank = HUMAN_NPC_RANK_ELITE
	npc_damage_taken = 0.8
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/stormtrooper/smg

/mob/living/carbon/human/npc/ruin/trooper/syndicate/stormtrooper/shotgun
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/stormtrooper/shotgun

/mob/living/carbon/human/npc/ruin/trooper/syndicate/stormtrooper/sword
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/syndicate/stormtrooper/sword

// ===== NANOTRASEN PRIVATE SECURITY =====

/// An M1911 and two spare magazines, in security blues.
/datum/outfit/ruin_npc/nanotrasen
	name = "Ruin NPC: Nanotrasen security officer"
	uniform = /obj/item/clothing/under/rank/security/officer
	shoes = /obj/item/clothing/shoes/combat
	gloves = /obj/item/clothing/gloves/combat
	back = /obj/item/storage/backpack/security
	r_hand = /obj/item/gun/ballistic/automatic/pistol/m1911
	l_pocket = /obj/item/ammo_box/magazine/m45
	r_pocket = /obj/item/ammo_box/magazine/m45

/datum/outfit/ruin_npc/nanotrasen/vest
	name = "Ruin NPC: Nanotrasen security officer in a vest"
	suit = /obj/item/clothing/suit/armor/vest

/datum/outfit/ruin_npc/nanotrasen/vest/helmet
	name = "Ruin NPC: Nanotrasen security officer, red zone"
	head = /obj/item/clothing/head/helmet/swat/nanotrasen
	backpack_contents = list(/obj/item/reagent_containers/hypospray/medipen = 1)

/datum/human_npc_outfit_table/ruin/nanotrasen
	green = list(/datum/outfit/ruin_npc/nanotrasen = 1)
	yellow = list(/datum/outfit/ruin_npc/nanotrasen/vest = 1)
	red = list(/datum/outfit/ruin_npc/nanotrasen/vest/helmet = 1)

/mob/living/carbon/human/npc/ruin/trooper/nanotrasen
	npc_name = "Nanotrasen Private Security Officer"
	faction = list(ROLE_DEATHSQUAD)
	npc_voice = /datum/human_npc_voice/ruin_nanotrasen
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/nanotrasen

// ===== RUSSIAN MOBSTERS =====

/// A soviet uniform, a bear pelt and a kitchen knife.
/datum/outfit/ruin_npc/russian
	name = "Ruin NPC: Russian mobster"
	uniform = /obj/item/clothing/under/costume/soviet
	shoes = /obj/item/clothing/shoes/jackboots
	head = /obj/item/clothing/head/costume/bearpelt
	gloves = /obj/item/clothing/gloves/color/black
	r_hand = /obj/item/knife/kitchen

/datum/outfit/ruin_npc/russian/vest
	name = "Ruin NPC: Russian mobster in a vest"
	suit = /obj/item/clothing/suit/armor/vest

/// The red zone's Russians are troopers: camo, a bulletproof vest and a helmet.
/datum/outfit/ruin_npc/russian/trooper
	name = "Ruin NPC: Russian trooper"
	uniform = /obj/item/clothing/under/syndicate/camo
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/helmet/alt
	shoes = /obj/item/clothing/shoes/combat
	gloves = /obj/item/clothing/gloves/combat
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// A Makarov and two spare magazines, under an ushanka.
/datum/outfit/ruin_npc/russian/gunner
	name = "Ruin NPC: Russian gunner"
	head = /obj/item/clothing/head/costume/ushanka
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/ruin_npc/russian/gunner/vest
	name = "Ruin NPC: Russian gunner in a vest"
	suit = /obj/item/clothing/suit/armor/vest

/datum/outfit/ruin_npc/russian/gunner/trooper
	name = "Ruin NPC: Russian trooper gunner"
	uniform = /obj/item/clothing/under/syndicate/camo
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/helmet/alt
	shoes = /obj/item/clothing/shoes/combat
	gloves = /obj/item/clothing/gloves/combat
	belt = /obj/item/storage/belt/military
	belt_contents = list(/obj/item/reagent_containers/hypospray/medipen = 1)

/datum/human_npc_outfit_table/ruin/russian
	green = list(/datum/outfit/ruin_npc/russian = 1)
	yellow = list(/datum/outfit/ruin_npc/russian/vest = 1)
	red = list(/datum/outfit/ruin_npc/russian/trooper = 1)

/datum/human_npc_outfit_table/ruin/russian/gunner
	green = list(/datum/outfit/ruin_npc/russian/gunner = 1)
	yellow = list(/datum/outfit/ruin_npc/russian/gunner/vest = 1)
	red = list(/datum/outfit/ruin_npc/russian/gunner/trooper = 1)

/mob/living/carbon/human/npc/ruin/trooper/russian
	npc_name = "Russian Mobster"
	faction = list(FACTION_RUSSIAN)
	npc_voice = /datum/human_npc_voice/ruin_russian
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/russian
	npc_death_loot = list(/obj/item/knife/kitchen)

/mob/living/carbon/human/npc/ruin/trooper/russian/gunner
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/russian/gunner
	npc_death_loot = list(/obj/item/gun/ballistic/revolver/nagant)
