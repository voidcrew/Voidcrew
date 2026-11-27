// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_gemogee_job_1
	parent_type = /datum/outfit/job/captain
	name = "Gemogee-Class Runner — Captain"
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/marine/sulaco
	head = /obj/item/clothing/head/beret/cargo
	mask = /obj/item/clothing/mask/gas/sechailer/swat/spacepol
	glasses = /obj/item/clothing/glasses/thermal/eyepatch
	neck = /obj/item/clothing/neck/scarf/black
	gloves = /obj/item/clothing/gloves/color/light_brown
	shoes = /obj/item/clothing/shoes/jackboots
	accessory = /obj/item/clothing/accessory/waistcoat

/datum/outfit/job/workshop_gemogee_job_1/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/syndicate
	suit = /obj/item/clothing/suit/armor/vest/marine/sulaco
	head = /obj/item/clothing/head/beret/cargo
	mask = /obj/item/clothing/mask/gas/sechailer/swat/spacepol
	glasses = /obj/item/clothing/glasses/thermal/eyepatch
	neck = /obj/item/clothing/neck/scarf/black
	gloves = /obj/item/clothing/gloves/color/light_brown
	shoes = /obj/item/clothing/shoes/jackboots
	accessory = /obj/item/clothing/accessory/waistcoat

/datum/outfit/job/workshop_gemogee_job_2
	parent_type = /datum/outfit/job/assistant
	name = "Gemogee-Class Runner — Crew"
	uniform = /obj/item/clothing/under/chameleon
	suit = /obj/item/clothing/suit/armor/vest/old
	head = /obj/item/clothing/head/beret/sec/navyofficer
	mask = /obj/item/clothing/mask/russian_balaclava
	glasses = /obj/item/clothing/glasses/hud/spacecop
	gloves = /obj/item/clothing/gloves/color/plasmaman/black
	shoes = /obj/item/clothing/shoes/jackboots
	accessory = /obj/item/clothing/accessory/armband

/datum/outfit/job/workshop_gemogee_job_2/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/chameleon
	suit = /obj/item/clothing/suit/armor/vest/old
	head = /obj/item/clothing/head/beret/sec/navyofficer
	mask = /obj/item/clothing/mask/russian_balaclava
	glasses = /obj/item/clothing/glasses/hud/spacecop
	gloves = /obj/item/clothing/gloves/color/plasmaman/black
	shoes = /obj/item/clothing/shoes/jackboots
	accessory = /obj/item/clothing/accessory/armband

/datum/outfit/job/workshop_gemogee_job_3
	parent_type = /datum/outfit/job/assistant
	name = "Gemogee-Class Runner — Paramedic"
	uniform = /obj/item/clothing/under/color/blue
	suit = /obj/item/clothing/suit/armor/vest/old
	head = /obj/item/clothing/head/beret/medical
	mask = /obj/item/clothing/mask/balaclava
	glasses = /obj/item/clothing/glasses/hud/health/sunglasses
	gloves = /obj/item/clothing/gloves/color/white
	shoes = /obj/item/clothing/shoes/jackboots
	l_hand = /obj/item/storage/medkit/surgery

/datum/outfit/job/workshop_gemogee_job_3/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/color/blue
	suit = /obj/item/clothing/suit/armor/vest/old
	head = /obj/item/clothing/head/beret/medical
	mask = /obj/item/clothing/mask/balaclava
	glasses = /obj/item/clothing/glasses/hud/health/sunglasses
	gloves = /obj/item/clothing/gloves/color/white
	shoes = /obj/item/clothing/shoes/jackboots
	l_hand = /obj/item/storage/medkit/surgery

/datum/outfit/job/workshop_gemogee_job_4
	parent_type = /datum/outfit/job/assistant
	name = "Gemogee-Class Runner — Technician"
	uniform = /obj/item/clothing/under/color/brown
	suit = /obj/item/clothing/suit/armor/vest/old
	head = /obj/item/clothing/head/beanie/orange
	mask = /obj/item/clothing/mask/balaclava
	glasses = /obj/item/clothing/glasses/meson/engine
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/jackboots
	belt = /obj/item/storage/belt/utility/full
	accessory = /obj/item/clothing/accessory/armband/engine

/datum/outfit/job/workshop_gemogee_job_4/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/color/brown
	suit = /obj/item/clothing/suit/armor/vest/old
	head = /obj/item/clothing/head/beanie/orange
	mask = /obj/item/clothing/mask/balaclava
	glasses = /obj/item/clothing/glasses/meson/engine
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/jackboots
	belt = /obj/item/storage/belt/utility/full
	accessory = /obj/item/clothing/accessory/armband/engine
