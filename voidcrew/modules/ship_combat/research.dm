// Ship Combat Research Integration
// Techweb nodes and designs for ship combat equipment

// ========== TECHWEB NODES ==========

/datum/techweb_node/ship_combat
	id = TECHWEB_NODE_SHIP_COMBAT
	display_name = "Ship Combat Systems"
	description = "Basic ship-to-ship combat technology including missile launchers and light ordnance."
	prereq_ids = list(TECHWEB_NODE_BASIC_SHUTTLE)
	design_ids = list(
		"ship_combat_console",
		"ship_missile_launcher",
		"ship_missile_frame",
		"ship_missile_tracking",
		"ship_missile_warhead_light",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/ship_combat_ordnance
	id = TECHWEB_NODE_SHIP_COMBAT_ORDNANCE
	display_name = "Ship Ordnance"
	description = "Standard and specialized missile warheads for ship combat."
	prereq_ids = list(TECHWEB_NODE_SHIP_COMBAT)
	design_ids = list(
		"ship_missile_warhead_standard",
		"ship_missile_warhead_emp",
		"ship_missile_warhead_chemical",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/ship_combat_advanced
	id = TECHWEB_NODE_SHIP_COMBAT_ADVANCED
	display_name = "Advanced Ship Combat"
	description = "Advanced ship combat technology including cloaking devices and heavy ordnance."
	prereq_ids = list(TECHWEB_NODE_SHIP_COMBAT_ORDNANCE)
	design_ids = list(
		"ship_cloak_device",
		"ship_missile_warhead_heavy",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/ship_combat_interdictor
	id = TECHWEB_NODE_SHIP_COMBAT_INTERDICTOR
	display_name = "Ship Interdiction Systems"
	description = "Advanced interdiction technology that allows disabling enemy ship engines and forcing them to dock. Requires linking the combat console to the research network."
	prereq_ids = list(TECHWEB_NODE_SHIP_COMBAT_ADVANCED)
	design_ids = list()
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

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

/datum/design/board/ship_cloak_device
	name = "Cloaking Device Board"
	desc = "Allows for the construction of a ship cloaking device."
	id = "ship_cloak_device"
	build_path = /obj/item/circuitboard/machine/ship_combat/cloak_device
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

// ========== MISSILE FRAME DESIGN ==========

/datum/design/ship_missile_frame
	name = "Missile Frame"
	desc = "A missile body that requires wiring, a tracking circuit, and a warhead to arm. Too heavy to carry - must be dragged."
	id = "ship_missile_frame"
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/structure/ship_missile
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 5,
	)
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING

// ========== MISSILE TRACKING CIRCUIT DESIGN ==========

/datum/design/ship_missile_tracking
	name = "Missile Tracking Circuit"
	desc = "A guidance system circuit for ship missiles. Required component for missile construction."
	id = "ship_missile_tracking"
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/item/electronics/ship_missile_tracking
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 1,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING

// ========== MISSILE WARHEAD DESIGNS (BOMB CORES) ==========

/datum/design/ship_missile_warhead
	name = "Standard Missile Warhead"
	desc = "A standard warhead for ship missiles with moderate damage."
	id = "ship_missile_warhead_standard"
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/item/bombcore/missile
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 35,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 20,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 5,
	)
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/ship_missile_warhead/light
	name = "Light Missile Warhead"
	desc = "A lightweight warhead for ship missiles. Less damage but cheaper."
	id = "ship_missile_warhead_light"
	build_path = /obj/item/bombcore/missile/light
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 15,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 10,
	)

/datum/design/ship_missile_warhead/heavy
	name = "Heavy Missile Warhead"
	desc = "A heavy warhead for ship missiles with devastating damage."
	id = "ship_missile_warhead_heavy"
	build_path = /obj/item/bombcore/missile/heavy
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 50,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 20,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 15,
	)

/datum/design/ship_missile_warhead/emp
	name = "EMP Missile Warhead"
	desc = "An electromagnetic pulse warhead that disables electronics."
	id = "ship_missile_warhead_emp"
	build_path = /obj/item/bombcore/missile/emp
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 25,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 20,
	)

/datum/design/ship_missile_warhead/chemical
	name = "Chemical Missile Warhead"
	desc = "An empty warhead casing that accepts beakers. Fill with reagents and they'll splash on impact."
	id = "ship_missile_warhead_chemical"
	build_path = /obj/item/bombcore/missile/chemical
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 15,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 30,
	)
