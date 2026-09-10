// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_superpill_job_3
	parent_type = /datum/outfit/job/ce
	name = "Power-class Climate Destroyer — Chief Engineer"
	head = /obj/item/clothing/head/utility/hardhat/welding/white
	gloves = /obj/item/clothing/gloves/chief_engineer
	shoes = /obj/item/clothing/shoes/magboots/advance

/datum/outfit/job/workshop_superpill_job_3/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	head = /obj/item/clothing/head/utility/hardhat/welding/white
	gloves = /obj/item/clothing/gloves/chief_engineer
	shoes = /obj/item/clothing/shoes/magboots/advance

/datum/outfit/job/workshop_superpill_job_4
	parent_type = /datum/outfit/job/engineer
	name = "Power-class Climate Destroyer — Engineer"
	head = /obj/item/clothing/head/utility/hardhat/welding
	gloves = /obj/item/clothing/gloves/color/yellow

/datum/outfit/job/workshop_superpill_job_4/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	head = /obj/item/clothing/head/utility/hardhat/welding
	gloves = /obj/item/clothing/gloves/color/yellow
