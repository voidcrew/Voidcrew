
/obj/item/disk/survey_data_disk
	name = "survey data storage disk"
	desc = "A disk for storing data captured during surveys. Can be shared with other survey computers."
	icon_state = "datadisk5"
	custom_materials = list(/datum/material/iron=SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass=SMALL_MATERIAL_AMOUNT)
	var/datum/survey_research/data

/obj/item/disk/survey_data_disk/Initialize(mapload)
	. = ..()
	data = new()

/obj/item/disk/survey_data_disk/Destroy()
	. = ..()
	data = null
