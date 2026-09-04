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
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "datadisk3"
	w_class = WEIGHT_CLASS_SMALL
	/// Bitflags for what this upgrade provides
	var/upgrade_flags = NONE
	/// Bitflags that must ALL already be installed on the console before this disk will take
	var/required_upgrades = NONE

/// RTD upgrade - allows placing and removing floor tiles
/obj/item/ship_construction_upgrade/rtd
	name = "ship construction upgrade: rapid tiling"
	desc = "Adds rapid tiling functionality to the ship construction console, allowing placement and removal of various floor tiles."
	icon_state = "datadisk6"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_RTD

/// RPD upgrade - allows placing atmos and disposal pipes
/obj/item/ship_construction_upgrade/rpd
	name = "ship construction upgrade: rapid piping"
	desc = "Adds rapid piping functionality to the ship construction console, allowing placement of atmospheric and disposal pipes."
	icon_state = "datadisk4"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_RPD

/// RLD upgrade - allows placing and removing lights
/obj/item/ship_construction_upgrade/rld
	name = "ship construction upgrade: rapid lighting"
	desc = "Adds rapid lighting functionality to the ship construction console, allowing placement and removal of light fixtures and floor lights."
	icon_state = "datadisk5"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_RLD

/// T-ray upgrade - allows seeing underfloor objects like pipes and cables
/obj/item/ship_construction_upgrade/tray
	name = "ship construction upgrade: T-ray scanner"
	desc = "Adds T-ray scanner functionality to the ship construction console, allowing the drone to see underfloor objects such as cables and pipes. Includes pipe connection and thermal imaging modes."
	icon_state = "datadisk1"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_TRAY

/// Fabrication servo upgrade - tier 1, cuts drone build times by 25%
/obj/item/ship_construction_upgrade/servo
	name = "ship construction upgrade: fabrication servos"
	desc = "Retunes the construction drone's matter assembler and actuators. Cuts a quarter off the time it spends on every job, from walls and floors to airlocks and cameras."
	icon_state = "datadisk2"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_SERVO

/// Fabrication servo upgrade - tier 2, cuts drone build times by 50%. Needs tier 1 first.
/obj/item/ship_construction_upgrade/servo/mk2
	name = "ship construction upgrade: fabrication servos mk2"
	desc = "A second-generation servo package for the construction drone, halving the time it spends on every job. Requires the first-generation servos to already be installed."
	icon_state = "datadisk7"
	upgrade_flags = SHIP_CONSTRUCTION_UPGRADE_SERVO_MK2
	required_upgrades = SHIP_CONSTRUCTION_UPGRADE_SERVO
