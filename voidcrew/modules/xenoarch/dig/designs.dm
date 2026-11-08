/**
 * # Excavation designs
 *
 * The hand kit prints on any autolathe from round start (like the R&D kit). The stabiliser and the
 * spectrometer board belong to the "Xenoarchaeology" research node; the advanced depth scanner and
 * quick brush to "Advanced Excavation". Those nodes list these ids:
 *
 * - Xenoarchaeology: "xenoarch_stabiliser", "xenoarch_spectrometer"
 * - Advanced Excavation: "xenoarch_depth_scanner_adv", "xenoarch_brush_quick"
 */

// ===== Autolathe, from round start =====

/datum/design/xenoarch_kit
	name = "Excavation Kit"
	desc = "Webbing with a rock hammer, brush, depth scanner, core sampler and a find satchel."
	id = "xenoarch_kit"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3, /datum/material/glass = SHEET_MATERIAL_AMOUNT, /datum/material/plastic = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/storage/belt/excavation/full
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_hammer
	name = "Rock Hammer"
	id = "xenoarch_hammer"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/excavation/hammer
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_brush
	name = "Excavation Brush"
	id = "xenoarch_brush"
	build_type = AUTOLATHE
	materials = list(/datum/material/plastic = SMALL_MATERIAL_AMOUNT * 2, /datum/material/iron = SMALL_MATERIAL_AMOUNT)
	build_path = /obj/item/excavation/brush
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_depth_scanner
	name = "Depth Scanner"
	id = "xenoarch_depth_scanner"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 3)
	build_path = /obj/item/excavation/depth_scanner
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_core_sampler
	name = "Core Sampler"
	id = "xenoarch_core_sampler"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 4)
	build_path = /obj/item/excavation/core_sampler
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_find_bag
	name = "Find Satchel"
	id = "xenoarch_find_bag"
	build_type = AUTOLATHE
	materials = list(/datum/material/plastic = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/storage/bag/excavation
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

// ===== Research: Xenoarchaeology =====

/datum/design/xenoarch_stabiliser
	name = "Field Stabiliser"
	desc = "A handheld projector that holds crumbling rock together while a find is freed."
	id = "xenoarch_stabiliser"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/silver = SMALL_MATERIAL_AMOUNT * 3)
	build_path = /obj/item/excavation/stabiliser
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/board/xenoarch_spectrometer
	name = "Radiocarbon Spectrometer Board"
	desc = "The circuit board for a radiocarbon spectrometer."
	id = "xenoarch_spectrometer"
	build_path = /obj/item/circuitboard/machine/xenoarch_spectrometer
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

// ===== Research: Advanced Excavation =====

/datum/design/xenoarch_depth_scanner_adv
	name = "Advanced Depth Scanner"
	desc = "Reads a find's exact depth and the field its rock needs, on site."
	id = "xenoarch_depth_scanner_adv"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 3, /datum/material/gold = SMALL_MATERIAL_AMOUNT * 2, /datum/material/uranium = SMALL_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/excavation/depth_scanner/advanced
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_brush_quick
	name = "Quick Brush"
	desc = "An excavation brush with a vibrating head."
	id = "xenoarch_brush_quick"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/plastic = SMALL_MATERIAL_AMOUNT * 2, /datum/material/iron = SMALL_MATERIAL_AMOUNT * 2, /datum/material/gold = SMALL_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/excavation/brush/quick
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO
