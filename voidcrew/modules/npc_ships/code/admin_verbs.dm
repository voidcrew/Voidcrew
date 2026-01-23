/**
 * Admin verbs for NPC pirate mob spawning
 */

/// Mapping of faction names to their mob types
GLOBAL_LIST_INIT(npc_pirate_factions, list(
	"Silverscale" = list(
		"Melee (Duelist)" = /mob/living/basic/trooper/pirate/faction/silverscale/melee,
		"Ranged (Marksman)" = /mob/living/basic/trooper/pirate/faction/silverscale/ranged,
		"Captain (Noble)" = /mob/living/basic/trooper/pirate/faction/silverscale/captain,
		"Boss (Highlord)" = /mob/living/basic/trooper/pirate/faction/boss/silverscale,
	),
	"Skeleton" = list(
		"Melee (Swashbuckler)" = /mob/living/basic/trooper/pirate/faction/skeleton/melee,
		"Ranged (Gunner)" = /mob/living/basic/trooper/pirate/faction/skeleton/ranged,
		"Captain" = /mob/living/basic/trooper/pirate/faction/skeleton/captain,
		"Boss (Davy Jones)" = /mob/living/basic/trooper/pirate/faction/boss/skeleton,
	),
	"Grey Tide" = list(
		"Melee (Grey Tider)" = /mob/living/basic/trooper/pirate/faction/grey/melee,
		"Ranged (Gunner)" = /mob/living/basic/trooper/pirate/faction/grey/ranged,
		"Captain (Tidemaster)" = /mob/living/basic/trooper/pirate/faction/grey/captain,
		"Boss (The Robust One)" = /mob/living/basic/trooper/pirate/faction/boss/grey,
	),
	"Lustrous" = list(
		"Melee (Scintillant)" = /mob/living/basic/trooper/pirate/faction/lustrous/melee,
		"Ranged (Coruscant)" = /mob/living/basic/trooper/pirate/faction/lustrous/ranged,
		"Captain (Radiant)" = /mob/living/basic/trooper/pirate/faction/lustrous/captain,
		"Boss (The Radiant One)" = /mob/living/basic/trooper/pirate/faction/boss/lustrous,
	),
	"Interdyne" = list(
		"Melee (Enforcer)" = /mob/living/basic/trooper/pirate/faction/interdyne/melee,
		"Ranged (Pharmacist)" = /mob/living/basic/trooper/pirate/faction/interdyne/ranged,
		"Captain (Director)" = /mob/living/basic/trooper/pirate/faction/interdyne/captain,
		"Boss (Director Prime)" = /mob/living/basic/trooper/pirate/faction/boss/interdyne,
	),
	"IRS" = list(
		"Melee (Enforcer)" = /mob/living/basic/trooper/pirate/faction/irs/melee,
		"Ranged (Agent)" = /mob/living/basic/trooper/pirate/faction/irs/ranged,
		"Captain (Head Auditor)" = /mob/living/basic/trooper/pirate/faction/irs/captain,
		"Boss (Chief Auditor)" = /mob/living/basic/trooper/pirate/faction/boss/irs,
	),
	"Medieval" = list(
		"Melee (Footsoldier)" = /mob/living/basic/trooper/pirate/faction/medieval/melee,
		"Ranged (Crossbowman)" = /mob/living/basic/trooper/pirate/faction/medieval/ranged,
		"Captain (Warlord)" = /mob/living/basic/trooper/pirate/faction/medieval/captain,
		"Boss (The Black Knight)" = /mob/living/basic/trooper/pirate/faction/boss/medieval,
	),
	"Rogues" = list(
		"Boss (Dread Pirate Roberts)" = /mob/living/basic/trooper/pirate/faction/boss/rogues,
	),
))

ADMIN_VERB(spawn_npc_pirate, R_SPAWN|R_DEBUG, "Spawn NPC Pirate", "Spawn an NPC pirate mob with patrol AI.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	if(!admin_mob)
		to_chat(user, span_warning("You need a mob to spawn pirates."))
		return

	var/turf/spawn_turf = get_turf(admin_mob)
	if(!spawn_turf)
		to_chat(user, span_warning("Could not find a valid turf to spawn on."))
		return

	// Step 1: Select faction
	var/list/faction_names = list()
	for(var/faction_name in GLOB.npc_pirate_factions)
		faction_names += faction_name

	var/selected_faction = tgui_input_list(user, "Select a pirate faction:", "Spawn NPC Pirate", faction_names)
	if(!selected_faction)
		return

	// Step 2: Select pirate type from that faction
	var/list/pirate_types = GLOB.npc_pirate_factions[selected_faction]
	if(!length(pirate_types))
		to_chat(user, span_warning("No pirate types found for faction [selected_faction]."))
		return

	var/list/type_names = list()
	for(var/type_name in pirate_types)
		type_names += type_name

	var/selected_type = tgui_input_list(user, "Select a pirate type:", "Spawn NPC Pirate - [selected_faction]", type_names)
	if(!selected_type)
		return

	var/mob_path = pirate_types[selected_type]
	if(!mob_path)
		to_chat(user, span_warning("Invalid pirate type selected."))
		return

	// Step 3: Ask about patrol AI setup
	var/setup_patrol = tgui_alert(user, "Set up door-to-door patrol AI? (Requires being on a ship)", "Patrol AI", list("Yes", "No"))

	// Spawn the pirate
	var/mob/living/basic/trooper/pirate/spawned_pirate = new mob_path(spawn_turf)
	if(!spawned_pirate)
		to_chat(user, span_warning("Failed to spawn pirate."))
		return

	// Set up patrol AI if requested
	if(setup_patrol == "Yes")
		// Find the ship we're on
		var/area/current_area = get_area(spawn_turf)
		var/obj/structure/overmap/ship/found_ship = null

		if(current_area)
			for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
				if(!S.shuttle?.shuttle_areas)
					continue
				if(current_area in S.shuttle.shuttle_areas)
					found_ship = S
					break

		if(found_ship)
			// Swap to patrolling AI controller
			var/is_ranged = istype(spawned_pirate.ai_controller, /datum/ai_controller/basic_controller/trooper/ranged)
			var/is_boss = istype(spawned_pirate, /mob/living/basic/trooper/pirate/faction/boss)

			var/new_controller_type
			if(is_boss)
				if(is_ranged)
					new_controller_type = /datum/ai_controller/basic_controller/trooper/ranged/patrolling/boss
				else
					new_controller_type = /datum/ai_controller/basic_controller/trooper/patrolling/boss
			else
				if(is_ranged)
					new_controller_type = /datum/ai_controller/basic_controller/trooper/ranged/patrolling
				else
					new_controller_type = /datum/ai_controller/basic_controller/trooper/patrolling

			// Replace the AI controller
			if(spawned_pirate.ai_controller)
				QDEL_NULL(spawned_pirate.ai_controller)
			spawned_pirate.ai_controller = new new_controller_type(spawned_pirate)

			// Assign patrol path
			if(assign_mob_to_patrol(spawned_pirate, found_ship))
				to_chat(user, span_notice("Spawned [spawned_pirate.name] ([selected_faction] - [selected_type]) with patrol AI on [found_ship.name]."))
			else
				to_chat(user, span_warning("Spawned [spawned_pirate.name] but failed to assign patrol path. Ship may not have enough doors."))
		else
			to_chat(user, span_warning("Spawned [spawned_pirate.name] but could not find a ship to patrol. Standing on a ship area is required for patrol AI."))
	else
		to_chat(user, span_notice("Spawned [spawned_pirate.name] ([selected_faction] - [selected_type]) without patrol AI."))

	message_admins("[key_name_admin(user)] spawned NPC pirate: [spawned_pirate.name] ([selected_faction] - [selected_type]) at [AREACOORD(spawn_turf)]")
	log_admin("[key_name(user)] spawned NPC pirate: [spawned_pirate.name] ([selected_faction] - [selected_type]) at [AREACOORD(spawn_turf)]")
	BLACKBOX_LOG_ADMIN_VERB("Spawn NPC Pirate")

/// Global list of dummy mobs keeping z-levels active for debugging
GLOBAL_LIST_EMPTY(z_level_activator_dummies)

ADMIN_VERB(force_z_level_active, R_DEBUG, "Force Z-Level Active", "Keep a z-level active for AI even while ghosted.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	var/turf/admin_turf = get_turf(admin_mob)
	var/current_z = admin_turf ? admin_turf.z : null

	var/z_level = input(user, "Which z-level? (Current: [current_z || "none"])", "Force Z-Level Active", current_z) as num|null
	if(!z_level)
		return

	// Check if already active
	var/mob/living/existing = GLOB.z_level_activator_dummies["[z_level]"]
	if(existing)
		// Toggle off
		SSmobs.clients_by_zlevel[z_level] -= existing
		qdel(existing)
		GLOB.z_level_activator_dummies -= "[z_level]"
		to_chat(user, span_adminnotice("Z-level [z_level] no longer forced active."))
		// Put AI back to sleep
		for(var/datum/ai_controller/controller as anything in GLOB.ai_controllers_by_zlevel[z_level])
			controller.set_ai_status(controller.get_expected_ai_status())
		return

	// Create dummy mob to trick the system
	var/turf/target_turf = locate(1, 1, z_level)
	if(!target_turf)
		to_chat(user, span_warning("Invalid z-level."))
		return

	var/mob/living/dummy = new(target_turf)
	dummy.name = "Z-Level Activator (z[z_level])"
	dummy.invisibility = INVISIBILITY_ABSTRACT
	ADD_TRAIT(dummy, TRAIT_NO_TRANSFORM, ADMIN_TRAIT)

	GLOB.z_level_activator_dummies["[z_level]"] = dummy
	SSmobs.clients_by_zlevel[z_level] += dummy

	// Wake up all AI on that z-level
	for(var/datum/ai_controller/controller as anything in GLOB.ai_controllers_by_zlevel[z_level])
		controller.set_ai_status(controller.get_expected_ai_status())

	to_chat(user, span_adminnotice("Z-level [z_level] forced active. Run verb again to deactivate."))
	message_admins("[key_name_admin(user)] forced z-level [z_level] active for AI debugging.")
	BLACKBOX_LOG_ADMIN_VERB("Force Z-Level Active")
