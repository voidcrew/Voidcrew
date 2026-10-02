// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_ship_nanopill_job_1
	parent_type = /datum/outfit/job/captain/corporate
	name = "NT-C Nanopill — First Officer"
	uniform = /obj/item/clothing/under/rank/security/officer/spacepol
	suit = /obj/item/clothing/suit/armor/vest/capcarapace/captains_formal
	head = /obj/item/clothing/head/helmet/marine/security
	mask = /obj/item/clothing/mask/gas/sechailer/swat
	gloves = /obj/item/clothing/gloves/captain
	shoes = /obj/item/clothing/shoes/jackboots/sec
	suit_store = /obj/item/gun/ballistic/automatic/ar
	r_pocket = /obj/item/gun/ballistic/automatic/pistol/m1911

/datum/outfit/job/workshop_ship_nanopill_job_1/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/security/officer/spacepol
	suit = /obj/item/clothing/suit/armor/vest/capcarapace/captains_formal
	head = /obj/item/clothing/head/helmet/marine/security
	mask = /obj/item/clothing/mask/gas/sechailer/swat
	gloves = /obj/item/clothing/gloves/captain
	shoes = /obj/item/clothing/shoes/jackboots/sec
	suit_store = /obj/item/gun/ballistic/automatic/ar
	r_pocket = /obj/item/gun/ballistic/automatic/pistol/m1911

/datum/outfit/job/workshop_ship_nanopill_job_2
	parent_type = /datum/outfit/job/security/corporate
	name = "NT-C Nanopill — Heavy Infantry"
	uniform = /obj/item/clothing/under/rank/security/officer/beatcop
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/helmet/marine/security
	mask = /obj/item/clothing/mask/gas/sechailer/swat
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses
	suit_store = /obj/item/gun/ballistic/automatic/ar
	r_pocket = /obj/item/gun/ballistic/automatic/pistol/m1911
	backpack_contents = list()

/datum/outfit/job/workshop_ship_nanopill_job_2/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/security/officer/beatcop
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/helmet/marine/security
	mask = /obj/item/clothing/mask/gas/sechailer/swat
	glasses = /obj/item/clothing/glasses/hud/security/sunglasses
	suit_store = /obj/item/gun/ballistic/automatic/ar
	r_pocket = /obj/item/gun/ballistic/automatic/pistol/m1911
	backpack_contents = list()

/datum/outfit/job/workshop_ship_nanopill_job_3
	parent_type = /datum/outfit/job/paramedic/syndicate
	name = "NT-C Nanopill — Marine Medic"
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/helmet/marine/medic
	glasses = /obj/item/clothing/glasses/hud/health/sunglasses
	suit_store = null
	r_hand = /obj/item/storage/medkit/regular

/datum/outfit/job/workshop_ship_nanopill_job_3/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/helmet/marine/medic
	glasses = /obj/item/clothing/glasses/hud/health/sunglasses
	suit_store = null
	r_hand = /obj/item/storage/medkit/regular

/datum/outfit/job/workshop_ship_nanopill_job_4
	parent_type = /datum/outfit/job/engineer/corporate
	name = "NT-C Nanopill — Marine Engineer"
	uniform = /obj/item/clothing/under/rank/centcom/military/eng
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/helmet/marine/engineer
	gloves = /obj/item/clothing/gloves/color/yellow
	belt = /obj/item/storage/belt/utility/full/engi

/datum/outfit/job/workshop_ship_nanopill_job_4/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/centcom/military/eng
	suit = /obj/item/clothing/suit/armor/bulletproof
	head = /obj/item/clothing/head/helmet/marine/engineer
	gloves = /obj/item/clothing/gloves/color/yellow
	belt = /obj/item/storage/belt/utility/full/engi
