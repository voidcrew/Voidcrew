/**
 * # Wasteland hermits and poacher squads (AM-9, AM-3)
 *
 * The wild-eyed people of the sandworlds, in their tattered survival gear (the wasteland corpse outfits,
 * voidcrew/modules/mob_spawn/corpses/wasteland_corpses.dm): wanderers who fight with their fists or a
 * knife, hunters with a .38 revolver and speedloaders, and soldiers with a WT-550 and spare magazines.
 * They spawn from the wasteland biomes, wasteland ruins and the poacher bust contract, which renames them.
 *
 * Their survival suits keep the cold off their bodies; on a cold site the cold layer adds a hat, scarf and
 * winter boots (a poacher camp on an ice planet), and a bad-air site a mask and tank. Nothing makes them
 * immune to the weather: a storm that hurts a player hurts them.
 */

/datum/human_npc_voice/ruin_hermit
	lines = list(
		RUIN_NPC_BARK_SPOT = list(
			"The sun... The sun...",
			"You'll do...",
			"All mine...",
			"Gg..free..",
			"Drink.. need drink...",
			"I can smell... you..",
			"G-g...",
			"Taste..the salt.",
		),
		HUMAN_NPC_BARK_DOWNED = list("G-g...", "The sun..."),
		HUMAN_NPC_BARK_PLEAD = list("Drink... need drink..."),
	)
	emotes = list(
		HUMAN_NPC_BARK_DOWNED = list("collapses."),
	)
	chances = list(RUIN_NPC_BARK_SPOT = 50)

/datum/outfit/hermit/survivor/knife
	name = "Wasteland Survivor (knife)"
	r_hand = /obj/item/knife/combat/survival

/datum/outfit/hermit/survivor/knife/red
	name = "Wasteland Survivor (knife, red zone)"
	l_pocket = /obj/item/reagent_containers/hypospray/medipen

/// A .38 revolver and two speedloaders.
/datum/outfit/hermit/survivor/hunter/armed
	name = "Wasteland Hunter (armed)"
	r_hand = /obj/item/gun/ballistic/revolver/c38
	backpack_contents = list(/obj/item/ammo_box/c38 = 2)

/datum/outfit/hermit/survivor/hunter/armed/red
	name = "Wasteland Hunter (armed, red zone)"
	backpack_contents = list(/obj/item/ammo_box/c38 = 2, /obj/item/reagent_containers/hypospray/medipen = 1)

/// A WT-550 and two spare magazines.
/datum/outfit/hermit/survivor/gunslinger/armed
	name = "Wasteland Gunslinger (armed)"
	r_hand = /obj/item/gun/ballistic/automatic/wt550
	backpack_contents = list(/obj/item/ammo_box/magazine/wt550m9 = 2)

/datum/outfit/hermit/survivor/gunslinger/armed/red
	name = "Wasteland Gunslinger (armed, red zone)"
	backpack_contents = list(/obj/item/ammo_box/magazine/wt550m9 = 2, /obj/item/reagent_containers/hypospray/medipen = 1)

/datum/human_npc_outfit_table/ruin/hermit
	green = list(/datum/outfit/hermit/survivor = 1)
	yellow = list(/datum/outfit/hermit/survivor/knife = 1)
	red = list(/datum/outfit/hermit/survivor/knife/red = 1)

/datum/human_npc_outfit_table/ruin/hermit/hunter
	green = list(/datum/outfit/hermit/survivor/hunter/armed = 1)
	yellow = list(/datum/outfit/hermit/survivor/hunter/armed = 1)
	red = list(/datum/outfit/hermit/survivor/hunter/armed/red = 1)

/datum/human_npc_outfit_table/ruin/hermit/gunslinger
	green = list(/datum/outfit/hermit/survivor/gunslinger/armed = 1)
	yellow = list(/datum/outfit/hermit/survivor/gunslinger/armed = 1)
	red = list(/datum/outfit/hermit/survivor/gunslinger/armed/red = 1)

/mob/living/carbon/human/npc/ruin/hermit
	npc_name = "Hermit Wanderer"
	faction = list("hermit", FACTION_WASTELAND)
	npc_voice = /datum/human_npc_voice/ruin_hermit
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/hermit

/mob/living/carbon/human/npc/ruin/hermit/hunter
	npc_name = "Hermit Hunter"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/hermit/hunter

/mob/living/carbon/human/npc/ruin/hermit/gunslinger
	npc_name = "Hermit Soldier"
	npc_outfit_table = /datum/human_npc_outfit_table/ruin/hermit/gunslinger
