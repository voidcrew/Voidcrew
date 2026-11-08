// Sample human NPCs: the reference kit for the base (admin spawns, tests, the measurement harness).
// Phases B-E make their own types (pirate factions, troopers, hermits, criminals) and replace these.
// The ranged samples carry their spare ammunition, and the spacer its own air: no NPC refills from
// nothing or breathes vacuum.

/datum/outfit/human_npc
	name = "Human NPC"

/datum/outfit/human_npc/pirate_gunner
	name = "Human NPC: pirate gunner"
	uniform = /obj/item/clothing/under/costume/pirate
	suit = /obj/item/clothing/suit/costume/pirate/armored
	head = /obj/item/clothing/head/costume/pirate/armored
	glasses = /obj/item/clothing/glasses/eyepatch
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots
	belt = /obj/item/storage/belt/military
	belt_contents = list(
		/obj/item/ammo_box/magazine/m9mm = 2,
		/obj/item/knife/combat/survival = 1,
	)
	r_hand = /obj/item/gun/ballistic/automatic/pistol

/datum/outfit/human_npc/pirate_laser
	name = "Human NPC: pirate laser gunner"
	uniform = /obj/item/clothing/under/costume/pirate
	suit = /obj/item/clothing/suit/costume/pirate/armored
	head = /obj/item/clothing/head/costume/pirate/armored
	glasses = /obj/item/clothing/glasses/eyepatch
	shoes = /obj/item/clothing/shoes/jackboots
	belt = /obj/item/storage/belt/military
	belt_contents = list(/obj/item/knife/combat/survival = 1)
	r_hand = /obj/item/gun/energy/laser

/datum/outfit/human_npc/pirate_swashbuckler
	name = "Human NPC: pirate swashbuckler"
	uniform = /obj/item/clothing/under/costume/pirate
	head = /obj/item/clothing/head/costume/pirate/bandana/armored
	glasses = /obj/item/clothing/glasses/eyepatch
	shoes = /obj/item/clothing/shoes/jackboots
	r_hand = /obj/item/melee/energy/sword/pirate

/// For hulls and ruins open to space: a sealed suit and its own air.
/datum/outfit/human_npc/pirate_spacer
	name = "Human NPC: pirate spacer"
	uniform = /obj/item/clothing/under/costume/pirate
	suit = /obj/item/clothing/suit/space/pirate
	head = /obj/item/clothing/head/helmet/space/pirate
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/jackboots
	suit_store = /obj/item/tank/internals/oxygen
	internals_slot = ITEM_SLOT_SUITSTORE
	belt = /obj/item/storage/belt/military
	belt_contents = list(/obj/item/knife/combat/survival = 1)
	r_hand = /obj/item/gun/energy/laser

/mob/living/carbon/human/npc/sample
	faction = list(FACTION_PIRATE)
	npc_name = "Pirate"

/mob/living/carbon/human/npc/sample/gunner
	npc_name = "Pirate Gunner"
	npc_outfit = /datum/outfit/human_npc/pirate_gunner
	npc_death_cash = 100

/mob/living/carbon/human/npc/sample/laser
	npc_name = "Pirate Gunner"
	npc_outfit = /datum/outfit/human_npc/pirate_laser
	npc_death_cash = 100

/mob/living/carbon/human/npc/sample/swashbuckler
	npc_name = "Pirate Swashbuckler"
	npc_outfit = /datum/outfit/human_npc/pirate_swashbuckler
	npc_death_cash = 100

/mob/living/carbon/human/npc/sample/spacer
	npc_name = "Pirate Spacer"
	npc_outfit = /datum/outfit/human_npc/pirate_spacer
	npc_death_cash = 100

/// An elite: lands aimed crits and executions, and takes a quarter less brute and burn.
/mob/living/carbon/human/npc/sample/elite
	npc_name = "Pirate Bosun"
	npc_outfit = /datum/outfit/human_npc/pirate_gunner
	npc_rank = HUMAN_NPC_RANK_ELITE
	npc_damage_taken = 0.75
	npc_death_cash = 300

// ===== Phase A2 samples: a voice, surrender rules and a zone table, for tests and admin spawns =====

/datum/human_npc_voice/sample
	lines = list(
		HUMAN_NPC_BARK_DOWNED = list("I'm hit! I'm hit!", "Not like this..."),
		HUMAN_NPC_BARK_RECOVER = list("Still breathing.", "That all you've got?"),
		HUMAN_NPC_BARK_PLEAD = list("Please... don't.", "I give, I give..."),
		HUMAN_NPC_BARK_CUFFED = list("These are too tight."),
		HUMAN_NPC_BARK_SLIPPING = list("Almost got it..."),
		HUMAN_NPC_BARK_UNCUFFED = list("Hands free."),
		HUMAN_NPC_BARK_PULLED_FREE = list("Hands off!"),
		HUMAN_NPC_BARK_SURRENDER = list("Alright! I give up!", "Don't shoot!"),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
	)

/datum/human_npc_surrender/sample

/mob/living/carbon/human/npc/sample
	npc_voice = /datum/human_npc_voice/sample

/// Gives up when it is losing, and stops shooting anyone already down: the shape of a criminal.
/mob/living/carbon/human/npc/sample/thug
	npc_name = "Thug"
	npc_outfit = /datum/outfit/human_npc/thug
	npc_surrender = /datum/human_npc_surrender/sample
	npc_target_stat = HUMAN_NPC_SPARES_DOWNED
	npc_death_cash = 100

/// Dressed by zone: rags in green, a vest in yellow, a vest, helmet and SMG in red.
/mob/living/carbon/human/npc/sample/raider
	npc_name = "Raider"
	npc_outfit_table = /datum/human_npc_outfit_table/sample_raiders
	npc_death_cash = 100

/datum/human_npc_outfit_table/sample_raiders
	green = list(/datum/outfit/human_npc/raider = 1)
	yellow = list(/datum/outfit/human_npc/raider/vest = 1)
	red = list(/datum/outfit/human_npc/raider/armoured = 1)
	elite = list(/datum/outfit/human_npc/pirate_gunner = 1)
	vacuum_layer = /datum/human_npc_layer/eva/pirate

/datum/outfit/human_npc/raider
	name = "Human NPC: raider"
	uniform = /obj/item/clothing/under/costume/pirate
	head = /obj/item/clothing/head/costume/pirate/bandana/armored
	shoes = /obj/item/clothing/shoes/jackboots
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/human_npc/raider/vest
	name = "Human NPC: raider in a vest"
	suit = /obj/item/clothing/suit/armor/vest
	r_pocket = /obj/item/ammo_box/magazine/m9mm

/datum/outfit/human_npc/raider/armoured
	name = "Human NPC: armoured raider"
	suit = /obj/item/clothing/suit/armor/vest
	head = /obj/item/clothing/head/helmet
	r_hand = /obj/item/gun/ballistic/automatic/mini_uzi
	l_pocket = /obj/item/ammo_box/magazine/uzim9mm
	r_pocket = /obj/item/ammo_box/magazine/uzim9mm

/// A pistol and somewhere to holster it, so it has somewhere to put the gun when it gives up.
/datum/outfit/human_npc/thug
	name = "Human NPC: thug"
	uniform = /obj/item/clothing/under/costume/pirate
	shoes = /obj/item/clothing/shoes/jackboots
	gloves = /obj/item/clothing/gloves/color/black
	belt = /obj/item/storage/belt/holster
	r_hand = /obj/item/gun/ballistic/automatic/pistol
	l_pocket = /obj/item/ammo_box/magazine/m9mm
	r_pocket = /obj/item/reagent_containers/hypospray/medipen
