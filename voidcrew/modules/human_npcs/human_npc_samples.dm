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
