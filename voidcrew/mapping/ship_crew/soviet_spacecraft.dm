// Ship Workshop crew outfits. Edit these through the crew editor.

/datum/outfit/job/workshop_soviet_spacecraft_job_1
	parent_type = /datum/outfit/job/captain
	name = "Soviet spacecraft — Commander"
	uniform = /obj/item/clothing/under/costume/russian_officer
	suit = null
	head = /obj/item/clothing/head/helmet/rus_ushanka
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/russian
	l_pocket = /obj/item/reagent_containers/hypospray/medipen/salbutamol
	r_pocket = /obj/item/reagent_containers/hypospray/medipen/penacid
	r_hand = /obj/item/clipboard

/datum/outfit/job/workshop_soviet_spacecraft_job_1/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/costume/russian_officer
	suit = null
	head = /obj/item/clothing/head/helmet/rus_ushanka
	gloves = /obj/item/clothing/gloves/combat
	shoes = /obj/item/clothing/shoes/russian
	l_pocket = /obj/item/reagent_containers/hypospray/medipen/salbutamol
	r_pocket = /obj/item/reagent_containers/hypospray/medipen/penacid
	r_hand = /obj/item/clipboard

/datum/outfit/job/workshop_soviet_spacecraft_job_2
	parent_type = /datum/outfit/job/engineer
	name = "Soviet spacecraft — Flight Engineer"
	uniform = /obj/item/clothing/under/rank/centcom/military/eng
	head = /obj/item/clothing/head/costume/ushanka
	backpack_contents = list(/obj/item/construction/rcd/loaded = 1, /obj/item/reagent_containers/cup/glass/bottle/vodka = 1)

/datum/outfit/job/workshop_soviet_spacecraft_job_2/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/rank/centcom/military/eng
	head = /obj/item/clothing/head/costume/ushanka
	backpack_contents = list(/obj/item/construction/rcd/loaded = 1, /obj/item/reagent_containers/cup/glass/bottle/vodka = 1)

/datum/outfit/job/workshop_soviet_spacecraft_job_3
	parent_type = /datum/outfit/job/assistant
	name = "Soviet spacecraft — Spaceflight Participant"
	uniform = /obj/item/clothing/under/color/brown
	head = /obj/item/clothing/head/beanie/black/dboy
	l_pocket = /obj/item/food/grown/citrus/lemon
	r_pocket = /obj/item/food/grown/citrus/lime
	l_hand = /obj/item/crowbar

/datum/outfit/job/workshop_soviet_spacecraft_job_3/pre_equip(mob/living/carbon/human/H, visuals_only = FALSE)
	. = ..()
	uniform = /obj/item/clothing/under/color/brown
	head = /obj/item/clothing/head/beanie/black/dboy
	l_pocket = /obj/item/food/grown/citrus/lemon
	r_pocket = /obj/item/food/grown/citrus/lime
	l_hand = /obj/item/crowbar
