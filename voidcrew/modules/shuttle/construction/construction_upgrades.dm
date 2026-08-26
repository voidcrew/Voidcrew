/**
 * Ship Construction Console Upgrades
 *
 * Upgrade disks that can be inserted into the ship construction console
 * to add new capabilities beyond basic RCD functionality.
 *
 * Upgrade flag / tray mode defines live in voidcrew/_DEFINES/ship_construction.dm.
 */

/// Base upgrade disk for ship construction consoles
/obj/item/ship_construction_upgrade
	name = "ship construction upgrade disk"
	desc = "An upgrade disk for ship construction consoles."
	icon = 'icons/obj/devices/floppy_disks.dmi'
	icon_state = "datadisk3"
	w_class = WEIGHT_CLASS_SMALL
	/// Bitflags for what this upgrade provides
	var/upgrade_flags = NONE

/// RTD upgrade - allows placing and removing floor tiles
/obj/item/ship_construction_upgrade/rtd
	name = "ship construction upgrade: rapid tiling"
	desc = "Adds rapid tiling functionality to the ship construction console, allowing placement and removal of various floor tiles."
	icon_state = "datadisk6"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_RTD
	// Mirrors /datum/design/ship_construction_upgrade_rtd (voidcrew/modules/shuttle/design.dm).
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT,
	)

/// RPD upgrade - allows placing atmos and disposal pipes
/obj/item/ship_construction_upgrade/rpd
	name = "ship construction upgrade: rapid piping"
	desc = "Adds rapid piping functionality to the ship construction console, allowing placement of atmospheric and disposal pipes."
	icon_state = "datadisk4"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_RPD
	// Mirrors /datum/design/ship_construction_upgrade_rpd.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/plastic = SMALL_MATERIAL_AMOUNT * 2,
	)

/// RLD upgrade - allows placing and removing lights
/obj/item/ship_construction_upgrade/rld
	name = "ship construction upgrade: rapid lighting"
	desc = "Adds rapid lighting functionality to the ship construction console, allowing placement and removal of light fixtures and floor lights."
	icon_state = "datadisk5"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_RLD
	// Mirrors /datum/design/ship_construction_upgrade_rld.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
	)

/// T-ray upgrade - allows seeing underfloor objects like pipes and cables
/obj/item/ship_construction_upgrade/tray
	name = "ship construction upgrade: T-ray scanner"
	desc = "Adds T-ray scanner functionality to the ship construction console, allowing the drone to see underfloor objects such as cables and pipes. Includes pipe connection and thermal imaging modes."
	icon_state = "datadisk1"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_TRAY
	// Mirrors /datum/design/ship_construction_upgrade_tray.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = SMALL_MATERIAL_AMOUNT * 2,
	)
