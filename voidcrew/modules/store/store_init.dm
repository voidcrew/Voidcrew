/**
 * Voidcrew Player Shop System - Initialization
 *
 * Handles initializing store item lists from subtypes.
 * Called during world startup to populate the global store lists.
 */

/// Initialize all store items during startup
/proc/initialize_voidcrew_store()
	// Generate items for each category from their subtypes
	GLOB.store_clothing_head = generate_store_items(/datum/store_item/clothing/head)
	GLOB.store_clothing_suit = generate_store_items(/datum/store_item/clothing/suit)
	GLOB.store_clothing_uniform = generate_store_items(/datum/store_item/clothing/uniform)
	GLOB.store_equipment = generate_store_items(/datum/store_item/equipment)

	var/total_items = length(GLOB.store_clothing_head) + length(GLOB.store_clothing_suit) + length(GLOB.store_clothing_uniform) + length(GLOB.store_equipment)
	log_game("VOIDCREW_STORE: Initialized with [total_items] items ([length(GLOB.store_clothing_head)] head, [length(GLOB.store_clothing_suit)] suit, [length(GLOB.store_clothing_uniform)] uniform, [length(GLOB.store_equipment)] equipment)")

// Hook into world initialization
SUBSYSTEM_DEF(voidcrew_store)
	name = "Voidcrew Store"
	flags = SS_NO_FIRE

/datum/controller/subsystem/voidcrew_store/Initialize()
	initialize_voidcrew_store()
	return SS_INIT_SUCCESS
