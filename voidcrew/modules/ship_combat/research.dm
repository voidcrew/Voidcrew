// Ship Combat Research Integration
// Techweb nodes and designs for ship combat equipment

// ========== TECHWEB NODES ==========

/datum/techweb_node/ship_combat
	id = TECHWEB_NODE_SHIP_COMBAT
	display_name = "Ship Combat Systems"
	description = "Basic ship-to-ship combat technology including missile launchers and defensive shields."
	prereq_ids = list(TECHWEB_NODE_BASIC_SHUTTLE)
	design_ids = list(
		"ship_combat_console",
		"ship_missile_launcher",
		"ship_missile_standard",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/ship_combat_advanced
	id = TECHWEB_NODE_SHIP_COMBAT_ADVANCED
	display_name = "Advanced Ship Combat"
	description = "Advanced ship combat technology including cloaking devices, multi-missile launchers, interdictors, and heavy ordnance."
	prereq_ids = list(TECHWEB_NODE_SHIP_COMBAT)
	design_ids = list(
		"ship_cloak_device",
		"ship_hellfire_launcher",
		"ship_interdictor",
		"ship_missile_heavy",
		"ship_missile_emp",
		"ship_missile_incendiary",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

// ========== COMPUTER BOARD DESIGNS ==========

/datum/design/board/ship_combat_console
	name = "Ship Combat Console Board"
	desc = "Allows for the construction of a ship combat console for tactical warfare."
	id = "ship_combat_console"
	build_path = /obj/item/circuitboard/computer/ship_combat_console
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY

// ========== MACHINE BOARD DESIGNS ==========

/datum/design/board/ship_missile_launcher
	name = "Missile Launcher Board"
	desc = "Allows for the construction of a ship-mounted missile launcher."
	id = "ship_missile_launcher"
	build_path = /obj/item/circuitboard/machine/ship_combat/missile_launcher
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY

/datum/design/board/ship_hellfire_launcher
	name = "Hellfire Missile Launcher Board"
	desc = "Allows for the construction of an advanced multi-missile launcher system capable of devastating barrages."
	id = "ship_hellfire_launcher"
	build_path = /obj/item/circuitboard/machine/ship_combat/missile_launcher/hellfire
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/ship_cloak_device
	name = "Cloaking Device Board"
	desc = "Allows for the construction of a ship cloaking device."
	id = "ship_cloak_device"
	build_path = /obj/item/circuitboard/machine/ship_combat/cloak_device
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/ship_interdictor
	name = "Ship Interdictor Board"
	desc = "Allows for the construction of a ship interdictor that can force nearby ships to dock."
	id = "ship_interdictor"
	build_path = /obj/item/circuitboard/machine/ship_combat/interdictor
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_SECURITY

// ========== MISSILE DESIGNS ==========

/datum/design/ship_missile
	name = "Standard Ship Missile"
	desc = "A standard ship-to-ship missile with moderate damage."
	id = "ship_missile_standard"
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/item/ship_combat_missile
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT,
	)
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/ship_missile/heavy
	name = "Heavy Ship Missile"
	desc = "A heavy warhead missile with devastating damage."
	id = "ship_missile_heavy"
	build_path = /obj/item/ship_combat_missile/heavy
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT,
	)

/datum/design/ship_missile/emp
	name = "EMP Ship Missile"
	desc = "An electromagnetic pulse missile that disables electronics."
	id = "ship_missile_emp"
	build_path = /obj/item/ship_combat_missile/emp
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 2,
	)

/datum/design/ship_missile/incendiary
	name = "Incendiary Ship Missile"
	desc = "A missile with an incendiary payload that sets the target ablaze."
	id = "ship_missile_incendiary"
	build_path = /obj/item/ship_combat_missile/incendiary
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 3,
	)
