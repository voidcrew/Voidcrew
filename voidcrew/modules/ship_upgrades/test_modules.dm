/**
 * # Test Ship Upgrade Modules
 *
 * Example module definitions for testing the ship upgrade system.
 * These are simple 3x3 modules with basic content.
 *
 * Modules are organized by ship - each ship class has its own subtype folder.
 */

// ============================================================================
// TEST MODULAR SHIP MODULES
// These modules are for /datum/map_template/shuttle/voidcrew/test_modular
// ============================================================================

/// Base type for all test_modular ship modules
/datum/ship_upgrade_module/test_modular
	for_ship = /datum/map_template/shuttle/voidcrew/test_modular

// ===== CARGO BAY UPGRADES =====

/// Default cargo bay - minimal storage
/datum/ship_upgrade_module/test_modular/cargo_basic
	id = "cargo_basic"
	name = "Basic Cargo Bay"
	desc = "A simple cargo storage area with a single crate."
	slot = "cargobay"
	map_file = "test_modular/cargo_basic.dmm"
	is_default = TRUE

/// Expanded cargo bay - more storage crates
/datum/ship_upgrade_module/test_modular/cargo_expanded
	id = "cargo_expanded"
	name = "Expanded Cargo Bay"
	desc = "A larger cargo area with multiple secure storage crates."
	slot = "cargobay"
	map_file = "test_modular/cargo_expanded.dmm"
	part_cost = list(PART_CLASS_TRADE = 1)

// ===== ENGINE ROOM UPGRADES =====

/// Default engine room - basic equipment
/datum/ship_upgrade_module/test_modular/engine_basic
	id = "engine_basic"
	name = "Basic Engine Room"
	desc = "A simple engine maintenance area."
	slot = "engineroom"
	map_file = "test_modular/engine_basic.dmm"
	is_default = TRUE

/// Advanced engine room - better equipment
/datum/ship_upgrade_module/test_modular/engine_advanced
	id = "engine_advanced"
	name = "Advanced Engine Room"
	desc = "An enhanced engine room with additional equipment and oxygen supply."
	slot = "engineroom"
	map_file = "test_modular/engine_advanced.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 1)
