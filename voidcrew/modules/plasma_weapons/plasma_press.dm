// Package: P2 guns and cartridges. Where plasma cartridges come from: printed on a protolathe, or bought.
//
// A cartridge's materials are always iron only (plasma_cartridge.dm), and a lathe never discounts the
// plasma (build_efficiency, code/modules/research/machinery/_production.dm).

/datum/design/plasma_cartridge
	name = "Plasma Cartridge"
	desc = "A glass cartridge of pressed plasma in a steel jacket."
	id = "vc_plasma_cartridge"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * PLASMA_CARTRIDGE_SHEETS,
		/datum/material/iron = PLASMA_CARTRIDGE_IRON,
	)
	build_path = /obj/item/plasma_cartridge
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/techweb_node/ballistic_ammunition/New()
	. = ..()
	design_ids += "vc_plasma_cartridge"
