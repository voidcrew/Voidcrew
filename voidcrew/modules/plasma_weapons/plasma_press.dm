// Package: P2 guns and cartridges. Where plasma cartridges come from: pressed by hand, or printed.
//
// Pressing by hand needs nothing but plasma and iron, so a looted gun can be loaded in any zone.
// Ore counts half a sheet. A cartridge's materials are always iron only (plasma_cartridge.dm), and
// a lathe never discounts the plasma (build_efficiency, code/modules/research/machinery/_production.dm).

/datum/crafting_recipe/plasma_cartridge
	name = "plasma cartridge"
	result = /obj/item/plasma_cartridge
	reqs = list(
		/obj/item/stack/sheet/mineral/plasma = PLASMA_CARTRIDGE_SHEETS,
		/obj/item/stack/sheet/iron = 1,
	)
	time = PLASMA_PRESS_TIME
	category = CAT_WEAPON_AMMO

/datum/crafting_recipe/plasma_cartridge/ore
	name = "plasma cartridge (ore)"
	reqs = list(
		/obj/item/stack/ore/plasma = PLASMA_CARTRIDGE_SHEETS * 2,
		/obj/item/stack/sheet/iron = 1,
	)

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
