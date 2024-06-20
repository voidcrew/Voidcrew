
/obj/item/disk/survey_data_disk
	name = "survey information disk"
	desc = "A disk for storing survey information like planetary information. Can be shared with other survey computers."
	icon_state = "datadisk5"
	custom_materials = list(/datum/material/iron=SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass=SMALL_MATERIAL_AMOUNT)
	var/list/surveyed_planets = list()
	var/list/surveyed_planets_data = list()

