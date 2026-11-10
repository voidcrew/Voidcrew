// Ship research prints the loose-round reloads for the Woodsman and the SKM-24. Their magazines are
// sold, not printed. Unlocked by Automatic Ammunition (voidcrew/modules/research/techweb_nodes.dm).

/datum/design/vc_ammo/a8x50r_clip
	name = "Stripper Clip (8x50mmR)"
	desc = "Five rounds of 8x50mmR on a stripper clip."
	id = "vc_ammo_a8x50r_clip"
	build_path = /obj/item/ammo_box/a8x50r
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/vc_ammo/a762x40_clip
	name = "Stripper Clip (7.62x40mm)"
	desc = "Five rounds of 7.62x40mm on a stripper clip."
	id = "vc_ammo_a762x40_clip"
	build_path = /obj/item/ammo_box/a762x40
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
	)
