/obj/structure/table/bronze
	icon = 'voidcrew/icons/obj/smooth_structures/brass_table.dmi'

/obj/structure/table/reinforced/wood
	name = "reinforced wooden table"
	desc = "A reinforced version of the wooden table."
	icon = 'voidcrew/icons/obj/smooth_structures/reinforced_wood_table.dmi'
	icon_state = "reinforced_wood_table-0"
	base_icon_state = "reinforced_wood_table"
	custom_materials = list(/datum/material/wood =SHEET_MATERIAL_AMOUNT, /datum/material/iron =SHEET_MATERIAL_AMOUNT)
	buildstack = /obj/item/stack/sheet/mineral/wood
	max_integrity = 150
