/**
 * # Test Ship Upgrade Modules
 *
 * Example module definitions for testing the ship upgrade system.
 * These are simple 3x3 modules with basic content.
 */

// ===== CARGO BAY UPGRADES =====

/// Default cargo bay - minimal storage
/datum/ship_upgrade_module/cargo_basic
	id = "cargo_basic"
	name = "Basic Cargo Bay"
	desc = "A simple cargo storage area with a single crate."
	slot = "cargobay"
	map_file = "cargo_basic.dmm"
	is_default = TRUE

/// Expanded cargo bay - more storage crates
/datum/ship_upgrade_module/cargo_expanded
	id = "cargo_expanded"
	name = "Expanded Cargo Bay"
	desc = "A larger cargo area with multiple secure storage crates."
	slot = "cargobay"
	map_file = "cargo_expanded.dmm"
	part_cost = list(PART_CLASS_TRADE = 1)

// ===== ENGINE ROOM UPGRADES =====

/// Default engine room - basic equipment
/datum/ship_upgrade_module/engine_basic
	id = "engine_basic"
	name = "Basic Engine Room"
	desc = "A simple engine maintenance area."
	slot = "engineroom"
	map_file = "engine_basic.dmm"
	is_default = TRUE

/// Advanced engine room - better equipment
/datum/ship_upgrade_module/engine_advanced
	id = "engine_advanced"
	name = "Advanced Engine Room"
	desc = "An enhanced engine room with additional equipment and oxygen supply."
	slot = "engineroom"
	map_file = "engine_advanced.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 1)
