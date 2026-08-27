// Shuttle Warfare Research Integration
// Techweb nodes and designs for Shuttle Warfare equipment

// ========== TECHWEB NODES ==========

// Base warfare node - just the combat console
/datum/techweb_node/ship_combat
	display_name = "Shuttle Warfare Systems"
	description = "Basic technology for shuttle-to-shuttle warfare. Unlocks the weapons console for coordinating combat systems."
	prerequisite_nodes = list(/datum/techweb_node/basic_shuttle_tech)
	unlocked_designs = list(
		/datum/design/board/ship_combat_console,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

// Missile systems - launcher, frame, tracking, light warhead
/datum/techweb_node/ship_combat_missiles
	display_name = "Missile Ordnance"
	description = "Missile launcher systems and light warheads for shuttle warfare. Chemical missiles can be created by inserting grenades into missile frames."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat)
	unlocked_designs = list(
		/datum/design/board/ship_missile_launcher,
		/datum/design/ship_missile_frame,
		/datum/design/ship_missile_tracking,
		/datum/design/ship_missile_warhead/light,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

// Standard warhead
/datum/techweb_node/ship_combat_ordnance_standard
	display_name = "Standard Ordnance"
	description = "Standard missile warheads with moderate explosive yield."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat_missiles)
	unlocked_designs = list(
		/datum/design/ship_missile_warhead,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

// Heavy warhead
/datum/techweb_node/ship_combat_ordnance_heavy
	display_name = "Heavy Ordnance"
	description = "Devastating heavy warheads for maximum destructive capability."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat_ordnance_standard)
	unlocked_designs = list(
		/datum/design/ship_missile_warhead/heavy,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

// Cloaking device
/datum/techweb_node/ship_combat_cloak
	display_name = "Shuttle Cloaking Systems"
	description = "Cloaking technology that renders shuttles invisible to sensors and visual detection. Power requirements scale with shuttle size."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat)
	unlocked_designs = list(
		/datum/design/board/ship_cloak_device,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

// Shield generator
/datum/techweb_node/ship_combat_shields
	display_name = "Shuttle Shield Systems"
	description = "Deflector shield technology that protects shuttles and outpost claims from attackers. Power requirements scale with shuttle size."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat)
	unlocked_designs = list(
		/datum/design/board/ship_shield_generator,
		/datum/design/board/outpost_shield_generator, // player outposts (see player_outposts/outpost_shield.dm)
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

// Laser turret
/datum/techweb_node/ship_combat_lasers
	display_name = "Shuttle Laser Systems"
	description = "Directed energy weapons that are highly effective against shields. Power level can be adjusted via the weapons system."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat)
	unlocked_designs = list(
		/datum/design/board/ship_laser_turret,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

// Interdictor
/datum/techweb_node/ship_combat_interdictor
	display_name = "Shuttle Interdiction Systems"
	description = "Advanced interdiction technology that slows enemy shuttles, enables force docking, and prevents cloaking. Power level determines effectiveness."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat)
	unlocked_designs = list(
		/datum/design/board/ship_interdictor,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

// Data Siphon
/datum/techweb_node/ship_combat_siphon
	display_name = "Ship Data Siphon"
	description = "Sophisticated data siphon technology that drains credits from targeted ship accounts. Requires weapons lock to operate."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat)
	unlocked_designs = list(
		/datum/design/board/ship_data_siphon,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

// Assault pods - the boarding half of ship combat. Pods used to be a crafted
// closet gated behind the survey tree; they belong here, with the tube that
// throws them and the guns that have to bring the shields down first.
/datum/techweb_node/ship_combat_assault_pods
	display_name = "Assault Pods"
	description = "Hull-mounted tubes that fire a crewed drop pod at another vessel. The pod cuts its own entry hole through the plating - provided the target's shields are already down."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat)
	unlocked_designs = list(
		/datum/design/board/ship_pod_launcher,
		/datum/design/ship_assault_pod,
		/datum/design/ship_assault_pod/advanced,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

// Electronic warfare: the suite plus the basic exploit software. Stronger
// exploit tiers are never researchable; the black market is the only source.
/datum/techweb_node/ship_combat_ew
	display_name = "Electronic Warfare Systems"
	description = "Intrusion hardware for shuttle warfare. Unlocks the electronic warfare suite and basic exploit software for disrupting a targeted ship's systems. Requires weapons lock to operate."
	prerequisite_nodes = list(/datum/techweb_node/ship_combat)
	unlocked_designs = list(
		/datum/design/board/ew_suite,
		/datum/design/ew_exploit_lights_out,
		/datum/design/ew_exploit_phantom_klaxons,
		/datum/design/ew_exploit_door_seize,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

// ========== SHIP READINESS QUERIES ==========
// Everything above is gated behind one node, which makes that node a clean
// stand-in for "this crew can defend itself": no ship_combat, no console, no
// shields, no guns, no interdictor. The mission boards and the zone advisory
// both read it to decide how much hand-holding a ship still needs.

/**
 * Whether this ship has researched Shuttle Warfare Systems.
 *
 * Deliberately the gate node rather than a specific weapon: researching it is
 * the point at which a crew can start building any of this, and a crew that has
 * it has stopped being a target that cannot answer. Note this reads the techweb
 * on the ship's own R&D server, so a hull that has not had its server powered
 * and linked yet reads as unresearched - which is the right answer for a warning
 * about whether the crew can actually put shields up.
 */
/obj/structure/overmap/ship/proc/has_ship_combat_research()
	var/datum/techweb/web = get_research_web()
	if(!web)
		return FALSE
	return !!web.researched_nodes[/datum/techweb_node/ship_combat]

// ========== COMPUTER BOARD DESIGNS ==========

/datum/design/board/ship_combat_console
	name = "Weapons System Board"
	desc = "Allows for the construction of a shuttle weapons system for tactical warfare."
	build_path = /obj/item/circuitboard/computer/ship_combat_console
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

// ========== MACHINE BOARD DESIGNS ==========

/datum/design/board/ship_missile_launcher
	name = "Missile Launcher Board"
	desc = "Allows for the construction of a ship-mounted missile launcher."
	build_path = /obj/item/circuitboard/machine/ship_combat/missile_launcher
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/ship_cloak_device
	name = "Cloaking Device Board"
	desc = "Allows for the construction of a shuttle cloaking device."
	build_path = /obj/item/circuitboard/machine/ship_combat/cloak_device
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/ship_shield_generator
	name = "Shield Generator Board"
	desc = "Allows for the construction of a shuttle shield generator."
	research_icon = 'icons/obj/machines/shield_generator.dmi'
	research_icon_state = "shield_wall_gen"
	build_path = /obj/item/circuitboard/machine/ship_combat/shield_generator
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/ship_laser_turret
	name = "Laser Turret Board"
	desc = "Allows for the construction of a ship-mounted laser turret. Highly effective against shields."
	build_path = /obj/item/circuitboard/machine/ship_combat/laser_turret
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/ship_interdictor
	name = "Interdictor Board"
	desc = "Allows for the construction of a ship interdiction system. Slows enemy ships and prevents cloaking."
	build_path = /obj/item/circuitboard/machine/ship_combat/interdictor
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/ship_data_siphon
	name = "Data Siphon Board"
	desc = "Allows for the construction of a ship data siphon. Drains credits from targeted ship accounts."
	build_path = /obj/item/circuitboard/machine/ship_combat/data_siphon
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/ship_pod_launcher
	name = "Assault Pod Tube Board"
	desc = "Allows for the construction of a hull-mounted assault pod tube."
	build_path = /obj/item/circuitboard/machine/ship_combat/pod_launcher
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/ew_suite
	name = "Electronic Warfare Suite Board"
	desc = "Allows for the construction of an electronic warfare suite. Executes exploit software against targeted ships."
	build_path = /obj/item/circuitboard/machine/ship_combat/ew_suite
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

// ========== MISSILE FRAME DESIGN ==========

/datum/design/ship_missile_frame
	name = "Missile Frame"
	desc = "A missile body that requires wiring, a tracking circuit, and a warhead to arm. Too heavy to carry - must be dragged."
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/structure/ship_missile
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 5,
	)
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE
	research_icon = 'voidcrew/icons/obj/supplypods.dmi'
	research_icon_state = "missile_nowire"

// ========== ASSAULT POD DESIGNS ==========

/datum/design/ship_assault_pod
	name = "Orbital Drop Pod"
	desc = "A one-shot pod for riding down to a celestial body, or for being fired through somebody else's hull out of an assault pod tube. Too heavy to carry - must be dragged."
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/structure/closet/supplypod/drop_pod
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 15,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 5,
	)
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE
	research_icon = 'voidcrew/icons/obj/supplypods.dmi'
	research_icon_state = "darkpod"

/datum/design/ship_assault_pod/advanced
	name = "Advanced Orbital Drop Pod"
	desc = "An armoured drop pod, insulated against whatever it lands in. It doesn't pop its own hatch on arrival."
	build_path = /obj/structure/closet/supplypod/drop_pod/advanced
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 15,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 15,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 5,
	)

// ========== MISSILE TRACKING CIRCUIT DESIGN ==========

/datum/design/ship_missile_tracking
	name = "Missile Tracking Circuit"
	desc = "A guidance system circuit for ship missiles. Required component for missile construction."
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
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

// ========== MISSILE WARHEAD DESIGNS (BOMB CORES) ==========

/datum/design/ship_missile_warhead
	name = "Standard Missile Warhead"
	desc = "A standard warhead for ship missiles with moderate damage."
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
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE
	research_icon = 'voidcrew/icons/obj/devices/assemblies.dmi'
	research_icon_state = "bombcore"

/datum/design/ship_missile_warhead/light
	name = "Light Missile Warhead"
	desc = "A lightweight warhead for ship missiles. Less damage but cheaper."
	research_icon_state = "bombcore_light"
	build_path = /obj/item/bombcore/missile/light
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 15,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 10,
	)

/datum/design/ship_missile_warhead/heavy
	name = "Heavy Missile Warhead"
	desc = "A heavy warhead for shuttle missiles with devastating damage."
	research_icon_state = "bombcore_heavy"
	build_path = /obj/item/bombcore/missile/heavy
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 50,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 20,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 15,
	)

// Chemical missiles use standard chemical grenades or crafted chemical payload cores
// (/obj/item/bombcore/chemical) inserted into missile frames. No separate warhead
// design is needed - players build the payload and insert it directly.

// ========== EW EXPLOIT CARTRIDGE DESIGNS ==========
// Tier 1 software only. Every stronger exploit is black-market stock and has
// no design on purpose - the Undertow Exchange is the sole supplier.

/datum/design/ew_exploit_lights_out
	name = "Exploit Cartridge (Blackout)"
	desc = "Exploit software that drops every light on a targeted ship until the payload expires."
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/item/ew_exploit/lights_out
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 1,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/ew_exploit_phantom_klaxons
	name = "Exploit Cartridge (Phantom Klaxons)"
	desc = "Exploit software that sets off a targeted ship's fire alarms and drops its firelocks shipwide."
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/item/ew_exploit/phantom_klaxons
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 1,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/ew_exploit_door_seize
	name = "Exploit Cartridge (Bolt Override)"
	desc = "Exploit software that takes over a targeted ship's airlock bolts, dropping them all or throwing them all open."
	build_type = PROTOLATHE | AWAY_LATHE
	build_path = /obj/item/ew_exploit/door_seize
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 1,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE
