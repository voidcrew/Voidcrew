// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_ship_courage_job_1
	parent_type = /datum/outfit/job/captain
	name = "SYN-C Courage — Syndicate Officer"
	uniform = /obj/item/clothing/under/syndicate/combat
	suit = /obj/item/clothing/suit/armor/vest/capcarapace/syndicate
	head = /obj/item/clothing/head/helmet/swat
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/sunglasses
	ears = /obj/item/radio/headset/syndicate/alt/leader
	shoes = /obj/item/clothing/shoes/combat/coldres
	belt = /obj/item/modular_computer/pda/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command/captain_id
	suit_store = /obj/item/gun/ballistic/rifle/sks/empty
	l_pocket = /obj/item/gun/ballistic/automatic/pistol/aps
	r_pocket = /obj/item/ammo_box/magazine/m9mm_aps
	accessory = null

/datum/outfit/job/workshop_ship_courage_job_1/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate/combat
	suit = /obj/item/clothing/suit/armor/vest/capcarapace/syndicate
	head = /obj/item/clothing/head/helmet/swat
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/sunglasses
	ears = /obj/item/radio/headset/syndicate/alt/leader
	shoes = /obj/item/clothing/shoes/combat/coldres
	belt = /obj/item/modular_computer/pda/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command/captain_id
	suit_store = /obj/item/gun/ballistic/rifle/sks/empty
	l_pocket = /obj/item/gun/ballistic/automatic/pistol/aps
	r_pocket = /obj/item/ammo_box/magazine/m9mm_aps
	accessory = null

/datum/outfit/job/workshop_ship_courage_job_2
	parent_type = /datum/outfit/job/security
	name = "SYN-C Courage — Syndicate Operative"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/hos/trenchcoat
	head = /obj/item/clothing/head/helmet/swat
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/sunglasses
	ears = /obj/item/radio/headset/syndicate/alt
	shoes = /obj/item/clothing/shoes/combat/coldres
	belt = /obj/item/modular_computer/pda/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command
	suit_store = /obj/item/gun/ballistic/automatic/laser
	l_pocket = /obj/item/gun/ballistic/automatic/pistol/aps
	r_pocket = /obj/item/ammo_box/magazine/m9mm_aps
	backpack_contents = list()

/datum/outfit/job/workshop_ship_courage_job_2/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/hos/trenchcoat
	head = /obj/item/clothing/head/helmet/swat
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/sunglasses
	ears = /obj/item/radio/headset/syndicate/alt
	shoes = /obj/item/clothing/shoes/combat/coldres
	belt = /obj/item/modular_computer/pda/syndicate
	id = /obj/item/card/id/advanced/black/syndicate_command
	suit_store = /obj/item/gun/ballistic/automatic/laser
	l_pocket = /obj/item/gun/ballistic/automatic/pistol/aps
	r_pocket = /obj/item/ammo_box/magazine/m9mm_aps
	backpack_contents = list()

/datum/outfit/job/workshop_ship_courage_job_3
	parent_type = /datum/outfit/job/paramedic/syndicate/gorlex
	name = "SYN-C Courage — Syndicate Combat Medic"
	head = /obj/item/clothing/head/helmet/swat
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/sunglasses
	ears = /obj/item/radio/headset/syndicate/alt
	shoes = /obj/item/clothing/shoes/combat/coldres
	r_hand = /obj/item/storage/medkit/regular

/datum/outfit/job/workshop_ship_courage_job_3/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	head = /obj/item/clothing/head/helmet/swat
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/sunglasses
	ears = /obj/item/radio/headset/syndicate/alt
	shoes = /obj/item/clothing/shoes/combat/coldres
	r_hand = /obj/item/storage/medkit/regular

/datum/outfit/job/workshop_ship_courage_job_4
	parent_type = /datum/outfit/job/engineer/syndicate
	name = "SYN-C Courage — Syndicate Engineer"
	suit = /obj/item/clothing/suit/jacket/miljacket
	head = /obj/item/clothing/head/helmet/swat
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/sunglasses
	ears = /obj/item/radio/headset/syndicate/alt
	gloves = /obj/item/clothing/gloves/color/yellow
	shoes = /obj/item/clothing/shoes/combat/coldres
	belt = /obj/item/storage/belt/utility/syndicate
	r_pocket = null

/datum/outfit/job/workshop_ship_courage_job_4/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	suit = /obj/item/clothing/suit/jacket/miljacket
	head = /obj/item/clothing/head/helmet/swat
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/sunglasses
	ears = /obj/item/radio/headset/syndicate/alt
	gloves = /obj/item/clothing/gloves/color/yellow
	shoes = /obj/item/clothing/shoes/combat/coldres
	belt = /obj/item/storage/belt/utility/syndicate
	r_pocket = null

/datum/outfit/job/workshop_ship_courage_job_5
	parent_type = /datum/outfit/job/miner/equipped/combat
	name = "SYN-C Courage — Syndicate Prospector"
	uniform = /obj/item/clothing/under/syndicate/combat
	suit = /obj/item/clothing/suit/hooded/explorer/syndicate
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/meson/night
	belt = /obj/item/storage/belt/military
	l_pocket = /obj/item/modular_computer/pda/syndicate
	backpack_contents = list(/obj/item/gun/energy/recharge/kinetic_accelerator = 1, /obj/item/t_scanner/adv_mining_scanner/lesser = 1)

/datum/outfit/job/workshop_ship_courage_job_5/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate/combat
	suit = /obj/item/clothing/suit/hooded/explorer/syndicate
	mask = /obj/item/clothing/mask/gas/syndicate
	glasses = /obj/item/clothing/glasses/meson/night
	belt = /obj/item/storage/belt/military
	l_pocket = /obj/item/modular_computer/pda/syndicate
	backpack_contents = list(/obj/item/gun/energy/recharge/kinetic_accelerator = 1, /obj/item/t_scanner/adv_mining_scanner/lesser = 1)
