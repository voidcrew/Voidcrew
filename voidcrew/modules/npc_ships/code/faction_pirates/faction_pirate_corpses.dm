// Faction-specific pirate corpse spawners and outfits for NPC mobs
// These define the visual appearance of faction pirate troopers

// ==================== BASE FACTION CORPSE ====================
// This fixes the TG bug where skin_tone is defined but never applied after randomize_human_normie()

/obj/effect/mob_spawn/corpse/human/pirate/faction
	skin_tone = "caucasian1"
	hairstyle = "Bald"
	facial_hairstyle = "Shaved"

/obj/effect/mob_spawn/corpse/human/pirate/faction/special(mob/living/carbon/human/spawned_human)
	. = ..()
	// Fix: The base mob_spawn code doesn't apply skin_tone after randomization
	// We force it here for consistent corpse appearances
	if(skin_tone && ishuman(spawned_human))
		spawned_human.skin_tone = skin_tone
		spawned_human.update_body_parts()

// ==================== SILVERSCALE (Aristocratic Lizards) ====================

/obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale
	name = "Silverscale Pirate"
	mob_species = /datum/species/lizard/silverscale
	outfit = /datum/outfit/piratecorpse/faction/silverscale

/obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/melee
	name = "Silverscale Duelist"
	outfit = /datum/outfit/piratecorpse/faction/silverscale/melee

/obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/ranged
	name = "Silverscale Marksman"
	outfit = /datum/outfit/piratecorpse/faction/silverscale/ranged

/obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/captain
	name = "Silverscale Noble"
	outfit = /datum/outfit/piratecorpse/faction/silverscale/captain

/obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/highlord
	name = "Silverscale Highlord"
	outfit = /datum/outfit/piratecorpse/faction/silverscale/highlord

/datum/outfit/piratecorpse/faction/silverscale
	name = "Silverscale Pirate Corpse"
	uniform = /obj/item/clothing/under/syndicate/sniper
	suit = /obj/item/clothing/suit/armor/vest/alt
	glasses = /obj/item/clothing/glasses/monocle
	gloves = /obj/item/clothing/gloves/color/black
	head = /obj/item/clothing/head/collectable/tophat
	shoes = /obj/item/clothing/shoes/laceup

/datum/outfit/piratecorpse/faction/silverscale/melee
	name = "Silverscale Duelist Corpse"

/datum/outfit/piratecorpse/faction/silverscale/ranged
	name = "Silverscale Marksman Corpse"

/datum/outfit/piratecorpse/faction/silverscale/captain
	name = "Silverscale Noble Corpse"
	head = /obj/item/clothing/head/costume/crown
	mask = /obj/item/cigarette/cigar/havana

/datum/outfit/piratecorpse/faction/silverscale/highlord
	name = "Silverscale Highlord Corpse"
	head = /obj/item/clothing/head/costume/redcoat
	suit = /obj/item/clothing/suit/armor/hos/hos_formal

// ==================== SKELETON (Undead Pirates) ====================

/obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton
	name = "Skeleton Pirate"
	mob_species = /datum/species/skeleton
	outfit = /datum/outfit/piratecorpse/faction/skeleton

/obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/melee
	name = "Skeleton Swashbuckler"
	outfit = /datum/outfit/piratecorpse/faction/skeleton/melee

/obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/ranged
	name = "Skeleton Gunner"
	outfit = /datum/outfit/piratecorpse/faction/skeleton/ranged

/obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/captain
	name = "Skeleton Captain"
	outfit = /datum/outfit/piratecorpse/faction/skeleton/captain

/obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/davyjones
	name = "Davy Jones"
	outfit = /datum/outfit/piratecorpse/faction/skeleton/davyjones

/datum/outfit/piratecorpse/faction/skeleton
	name = "Skeleton Pirate Corpse"
	uniform = /obj/item/clothing/under/costume/pirate
	head = /obj/item/clothing/head/costume/pirate/bandana/armored
	shoes = /obj/item/clothing/shoes/pirate/armored

/datum/outfit/piratecorpse/faction/skeleton/melee
	name = "Skeleton Swashbuckler Corpse"

/datum/outfit/piratecorpse/faction/skeleton/ranged
	name = "Skeleton Gunner Corpse"

/datum/outfit/piratecorpse/faction/skeleton/captain
	name = "Skeleton Captain Corpse"
	head = /obj/item/clothing/head/costume/crown
	suit = /obj/item/clothing/suit/costume/pirate/armored
	belt = /obj/item/gun/magic/midas_hand
	glasses = /obj/item/clothing/glasses/eyepatch
	l_pocket = /obj/item/coin/gold/doubloon

/datum/outfit/piratecorpse/faction/skeleton/davyjones
	name = "Davy Jones Corpse"
	head = /obj/item/clothing/head/costume/pirate/armored
	suit = /obj/item/clothing/suit/costume/pirate/captain/armored
	belt = /obj/item/gun/magic/midas_hand
	glasses = /obj/item/clothing/glasses/eyepatch
	l_pocket = /obj/item/coin/gold/doubloon

// ==================== GREY TIDE (Rogue Assistants) ====================

/obj/effect/mob_spawn/corpse/human/pirate/faction/grey
	name = "Grey Tide Pirate"
	outfit = /datum/outfit/piratecorpse/faction/grey

/obj/effect/mob_spawn/corpse/human/pirate/faction/grey/melee
	name = "Grey Tider"
	outfit = /datum/outfit/piratecorpse/faction/grey/melee

/obj/effect/mob_spawn/corpse/human/pirate/faction/grey/ranged
	name = "Grey Tider Gunner"
	outfit = /datum/outfit/piratecorpse/faction/grey/ranged

/obj/effect/mob_spawn/corpse/human/pirate/faction/grey/captain
	name = "Tidemaster"
	outfit = /datum/outfit/piratecorpse/faction/grey/captain

/obj/effect/mob_spawn/corpse/human/pirate/faction/grey/robust
	name = "The Robust One"
	outfit = /datum/outfit/piratecorpse/faction/grey/robust

/datum/outfit/piratecorpse/faction/grey
	name = "Grey Tide Pirate Corpse"
	uniform = /obj/item/clothing/under/color/grey/ancient
	mask = /obj/item/clothing/mask/chameleon
	shoes = /obj/item/clothing/shoes/sneakers/black
	back = /obj/item/storage/backpack/satchel

/datum/outfit/piratecorpse/faction/grey/melee
	name = "Grey Tider Corpse"

/datum/outfit/piratecorpse/faction/grey/ranged
	name = "Grey Tider Gunner Corpse"

/datum/outfit/piratecorpse/faction/grey/captain
	name = "Tidemaster Corpse"
	head = /obj/item/clothing/head/collectable/captain

/datum/outfit/piratecorpse/faction/grey/robust
	name = "The Robust One Corpse"
	head = /obj/item/reagent_containers/cup/bucket
	neck = /obj/item/bedsheet/cosmos/double

// ==================== LUSTROUS (Mutated Ethereals) ====================

/obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous
	name = "Lustrous Pirate"
	mob_species = /datum/species/ethereal/lustrous
	outfit = /datum/outfit/piratecorpse/faction/lustrous

/obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/melee
	name = "Lustrous Scintillant"
	outfit = /datum/outfit/piratecorpse/faction/lustrous/melee

/obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/ranged
	name = "Lustrous Coruscant"
	outfit = /datum/outfit/piratecorpse/faction/lustrous/ranged

/obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/captain
	name = "Lustrous Radiant"
	outfit = /datum/outfit/piratecorpse/faction/lustrous/captain

/obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/radiant
	name = "The Radiant One"
	outfit = /datum/outfit/piratecorpse/faction/lustrous/radiant

/datum/outfit/piratecorpse/faction/lustrous
	name = "Lustrous Pirate Corpse"
	uniform = /obj/item/clothing/under/ethereal_tunic
	suit = /obj/item/clothing/suit/hooded/ethereal_raincoat
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/bhop
	back = /obj/item/storage/backpack/satchel

/datum/outfit/piratecorpse/faction/lustrous/melee
	name = "Lustrous Scintillant Corpse"

/datum/outfit/piratecorpse/faction/lustrous/ranged
	name = "Lustrous Coruscant Corpse"

/datum/outfit/piratecorpse/faction/lustrous/captain
	name = "Lustrous Radiant Corpse"
	suit = /obj/item/clothing/suit/jacket/oversized
	head = /obj/item/clothing/head/costume/crown

/datum/outfit/piratecorpse/faction/lustrous/radiant
	name = "The Radiant One Corpse"
	suit = /obj/item/clothing/suit/hooded/ethereal_raincoat/trailwarden
	head = /obj/item/clothing/head/hooded/ethereal_rainhood/trailwarden
	uniform = /obj/item/clothing/under/ethereal_tunic/trailwarden

// ==================== INTERDYNE (Ex-Pharmacists) ====================

/obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne
	name = "Interdyne Pirate"
	outfit = /datum/outfit/piratecorpse/faction/interdyne

/obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/melee
	name = "Interdyne Enforcer"
	outfit = /datum/outfit/piratecorpse/faction/interdyne/melee

/obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/ranged
	name = "Interdyne Pharmacist"
	outfit = /datum/outfit/piratecorpse/faction/interdyne/ranged

/obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/captain
	name = "Interdyne Director"
	outfit = /datum/outfit/piratecorpse/faction/interdyne/captain

/obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/prime
	name = "Interdyne Director Prime"
	outfit = /datum/outfit/piratecorpse/faction/interdyne/prime

/datum/outfit/piratecorpse/faction/interdyne
	name = "Interdyne Pirate Corpse"
	uniform = /obj/item/clothing/under/rank/medical/scrubs/coroner
	suit = /obj/item/clothing/suit/toggle/labcoat
	glasses = /obj/item/clothing/glasses/hud/health/night
	gloves = /obj/item/clothing/gloves/color/black
	head = /obj/item/clothing/head/utility/surgerycap/black
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/satchel/med

/datum/outfit/piratecorpse/faction/interdyne/melee
	name = "Interdyne Enforcer Corpse"

/datum/outfit/piratecorpse/faction/interdyne/ranged
	name = "Interdyne Pharmacist Corpse"

/datum/outfit/piratecorpse/faction/interdyne/captain
	name = "Interdyne Director Corpse"
	suit = /obj/item/clothing/suit/toggle/labcoat/cmo

/datum/outfit/piratecorpse/faction/interdyne/prime
	name = "Interdyne Director Prime Corpse"
	suit = /obj/item/clothing/suit/bio_suit/cmo
	head = /obj/item/clothing/head/bio_hood/cmo

// ==================== IRS (Tax Collectors) ====================

/obj/effect/mob_spawn/corpse/human/pirate/faction/irs
	name = "IRS Agent"
	outfit = /datum/outfit/piratecorpse/faction/irs

/obj/effect/mob_spawn/corpse/human/pirate/faction/irs/melee
	name = "IRS Enforcer"
	outfit = /datum/outfit/piratecorpse/faction/irs/melee

/obj/effect/mob_spawn/corpse/human/pirate/faction/irs/ranged
	name = "IRS Agent"
	outfit = /datum/outfit/piratecorpse/faction/irs/ranged

/obj/effect/mob_spawn/corpse/human/pirate/faction/irs/captain
	name = "IRS Head Auditor"
	outfit = /datum/outfit/piratecorpse/faction/irs/captain

/datum/outfit/piratecorpse/faction/irs
	name = "IRS Agent Corpse"
	uniform = /obj/item/clothing/under/costume/buttondown/slacks
	suit = /obj/item/clothing/suit/costume/irs
	glasses = /obj/item/clothing/glasses/sunglasses
	head = /obj/item/clothing/head/costume/irs
	shoes = /obj/item/clothing/shoes/laceup

/datum/outfit/piratecorpse/faction/irs/melee
	name = "IRS Enforcer Corpse"

/datum/outfit/piratecorpse/faction/irs/ranged
	name = "IRS Agent Corpse"

/datum/outfit/piratecorpse/faction/irs/captain
	name = "IRS Head Auditor Corpse"
	uniform = /obj/item/clothing/under/suit/charcoal
	neck = /obj/item/clothing/neck/tie/red/tied
	suit = null
	head = null
	belt = /obj/item/storage/belt/holster/detective/full/ert

/datum/outfit/piratecorpse/faction/irs/chief
	name = "IRS Head Auditor Corpse"
	uniform = /obj/item/clothing/under/suit/charcoal
	neck = /obj/item/clothing/neck/tie/red/tied
	suit = null
	head = /obj/item/clothing/head/costume/constable
	belt = /obj/item/storage/belt/holster/detective/full/ert

// ==================== MEDIEVAL (Space Warmongers) ====================

/obj/effect/mob_spawn/corpse/human/pirate/faction/medieval
	name = "Medieval Pirate"
	outfit = /datum/outfit/piratecorpse/faction/medieval

/obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/melee
	name = "Medieval Footsoldier"
	outfit = /datum/outfit/piratecorpse/faction/medieval/melee

/obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/ranged
	name = "Medieval Crossbowman"
	outfit = /datum/outfit/piratecorpse/faction/medieval/ranged

/obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/captain
	name = "Medieval Warlord"
	outfit = /datum/outfit/piratecorpse/faction/medieval/captain

/obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/blackknight
	name = "The Black Knight"
	outfit = /datum/outfit/piratecorpse/faction/medieval/blackknight

/datum/outfit/piratecorpse/faction/medieval
	name = "Medieval Pirate Corpse"
	uniform = /obj/item/clothing/under/costume/gamberson/military
	suit = /obj/item/clothing/suit/armor/vest/military
	gloves = /obj/item/clothing/gloves/color/brown
	head = /obj/item/clothing/head/helmet/military
	mask = /obj/item/clothing/mask/balaclava
	shoes = /obj/item/clothing/shoes/workboots
	back = /obj/item/storage/backpack/satchel/leather

/datum/outfit/piratecorpse/faction/medieval/melee
	name = "Medieval Footsoldier Corpse"
	belt = /obj/item/claymore/shortsword

/datum/outfit/piratecorpse/faction/medieval/ranged
	name = "Medieval Crossbowman Corpse"

/datum/outfit/piratecorpse/faction/medieval/captain
	name = "Medieval Warlord Corpse"
	neck = /obj/item/bedsheet/pirate
	suit = /obj/item/clothing/suit/armor/riot/knight/warlord
	gloves = /obj/item/clothing/gloves/combat
	head = /obj/item/clothing/head/helmet/knight/warlord
	mask = /obj/item/clothing/mask/breath
	shoes = /obj/item/clothing/shoes/bronze
	back = /obj/item/fireaxe/boardingaxe

/datum/outfit/piratecorpse/faction/medieval/blackknight
	name = "The Black Knight Corpse"
	neck = /obj/item/bedsheet/pirate
	suit = /obj/item/clothing/suit/hooded/cloak/godslayer
	gloves = /obj/item/clothing/gloves/combat
	head = /obj/item/clothing/head/hooded/cloakhood/godslayer
	mask = /obj/item/clothing/mask/breath
	shoes = /obj/item/clothing/shoes/bronze
	back = /obj/item/fireaxe/boardingaxe
