/datum/design/board/engine
	name = "Machine Design (Ion Thruster Board)"
	desc = "The circuit board for an ion thruster."
	id = "engine_ion"
	build_path = /obj/item/circuitboard/machine/engine/electric
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/engine/void
	name = "Machine Design (Void Thruster Board)"
	desc = "The circuit board for a void thruster."
	id = "engine_void"
	build_path = /obj/item/circuitboard/machine/engine/void

/datum/design/board/engine/plasma
	name = "Machine Design (Plasma Thruster Board)"
	desc = "The circuit board for a plasma thruster."
	id = "engine_plasma"
	build_path = /obj/item/circuitboard/machine/engine/plasma

/datum/design/board/engine/expulsion
	name = "Machine Design (Expulsion Thruster Board)"
	desc = "The circuit board for an expulsion thruster."
	id = "engine_expulsion"
	build_path = /obj/item/circuitboard/machine/engine/expulsion

/datum/design/board/shuttle/heater
	name = "Machine Design (Fueled Engine Heater Board)"
	desc = "The circuit board for a fueled engine heater."
	id = "shuttle_heater"
	build_path = /obj/item/circuitboard/machine/shuttle/heater
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/shuttle/shuttle_helm
	name = "Computer Design (Shuttle Helm Console)"
	desc = "Allows for the construction of circuit boards used to pilot a spacecraft."
	id = "shuttle_helm"
	build_path = /obj/item/circuitboard/computer/shuttle/helm
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/shuttle/ship_construction
	name = "Computer Design (Ship Construction Console)"
	desc = "Allows for the construction of circuit boards used for ship modifications."
	id = "ship_construction"
	build_path = /obj/item/circuitboard/computer/ship_construction
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

// Ship Construction Console Upgrades

/datum/design/ship_construction_upgrade_tray
	name = "Ship Construction Upgrade: T-Ray Scanner"
	desc = "An upgrade disk that adds T-ray scanning functionality to the ship construction console."
	id = "ship_construction_upgrade_tray"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/gold = SMALL_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/ship_construction_upgrade/tray
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/ship_construction_upgrade_rtd
	name = "Ship Construction Upgrade: Rapid Tiling"
	desc = "An upgrade disk that adds rapid tiling functionality to the ship construction console."
	id = "ship_construction_upgrade_rtd"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/ship_construction_upgrade/rtd
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/ship_construction_upgrade_rpd
	name = "Ship Construction Upgrade: Rapid Piping"
	desc = "An upgrade disk that adds rapid piping functionality to the ship construction console."
	id = "ship_construction_upgrade_rpd"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/plastic = SMALL_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/ship_construction_upgrade/rpd
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/ship_construction_upgrade_rld
	name = "Ship Construction Upgrade: Rapid Lighting"
	desc = "An upgrade disk that adds rapid lighting functionality to the ship construction console."
	id = "ship_construction_upgrade_rld"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/ship_construction_upgrade/rld
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING
