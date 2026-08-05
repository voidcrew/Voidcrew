/**
 * Admin / debug verbs for the electronic warfare (ship hacking) system.
 *
 * Two jobs: get the gear into the world (a loaded suite, individual cartridges,
 * the circuit board), and drive payloads directly for testing without the full
 * acquisition -> multitool link -> weapons lock -> warmup loop. "Apply EW Payload
 * to Ship" is the fast path - it instantiates a payload straight onto any ship so
 * you can watch its effect land and auto-revert in isolation.
 *
 * All choice lists are built from the live roster (subtypesof + prototype
 * metadata), so a new payload or chip shows up here with no edits to this file.
 */

// ========== SHARED CHOICE BUILDERS ==========

/// "Payload Name (Tn)" -> /datum/ew_payload subtype, from the prototype metadata.
/proc/ew_debug_payload_choices()
	var/list/choices = list()
	for(var/payload_type in subtypesof(/datum/ew_payload))
		var/datum/ew_payload/proto = get_ew_payload_prototype(payload_type)
		if(!proto)
			continue
		choices["[proto.name] (T[proto.tier])"] = payload_type
	return choices

/// A numbered, always-unique label -> ship, over every simulated ship.
/proc/ew_debug_ship_choices()
	var/list/choices = list()
	var/i = 0
	for(var/obj/structure/overmap/ship/candidate in SSovermap.simulated_ships)
		choices["[++i]. [candidate.display_name] ([candidate.type])"] = candidate
	return choices

// ========== SPAWNING ==========

ADMIN_VERB(spawn_ew_suite, R_SPAWN|R_DEBUG, "Spawn EW Suite", "Spawn an electronic warfare suite - loaded with one of every exploit cartridge, or just the circuit board.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	var/turf/spawn_turf = get_turf(admin_mob)
	if(!spawn_turf)
		to_chat(user, span_warning("You need a mob on a turf to spawn the suite."))
		return

	var/what = tgui_alert(user, "Spawn what?", "Spawn EW Suite", list("Loaded suite", "Circuit board", "Cancel"))
	if(!what || what == "Cancel")
		return

	if(what == "Circuit board")
		var/obj/item/circuitboard/machine/ship_combat/ew_suite/board = new(spawn_turf)
		admin_mob.put_in_hands(board)
		to_chat(user, span_notice("Spawned an [board.name]."))
		message_admins("[key_name_admin(user)] spawned an EW suite circuit board at [AREACOORD(spawn_turf)].")
		log_admin("[key_name(user)] spawned an EW suite circuit board at [AREACOORD(spawn_turf)].")
		BLACKBOX_LOG_ADMIN_VERB("Spawn EW Suite")
		return

	var/obj/machinery/ship_combat/ew_suite/suite = new(spawn_turf)
	var/loaded = 0
	for(var/chip_type in subtypesof(/obj/item/ew_exploit))
		new chip_type(suite) // Entered() files it into loaded_chips
		loaded++
	// Link to a weapons console on this ship if we're standing on one
	suite.attempt_auto_link()
	var/linked = !!suite.linked_console_ref?.resolve()
	to_chat(user, span_notice("Spawned [suite.name] loaded with [loaded] cartridge(s)[linked ? ", auto-linked to a weapons system" : " (no console found to auto-link; multitool it to a weapons system)"]."))
	message_admins("[key_name_admin(user)] spawned a loaded EW suite at [AREACOORD(spawn_turf)].")
	log_admin("[key_name(user)] spawned a loaded EW suite at [AREACOORD(spawn_turf)].")
	BLACKBOX_LOG_ADMIN_VERB("Spawn EW Suite")

ADMIN_VERB(spawn_ew_cartridge, R_SPAWN|R_DEBUG, "Spawn EW Cartridge", "Spawn one exploit cartridge (or one of every kind) into your hands.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	var/turf/spawn_turf = get_turf(admin_mob)
	if(!spawn_turf)
		to_chat(user, span_warning("You need a mob on a turf to spawn cartridges."))
		return

	var/all_label = "-- One of every cartridge --"
	var/list/chip_choices = list()
	chip_choices[all_label] = null
	// initial() reads the declared type, not the subtype held in a typepath var,
	// so read each cartridge's real name off a throwaway instance
	for(var/chip_type in subtypesof(/obj/item/ew_exploit))
		var/obj/item/ew_exploit/sample = new chip_type()
		chip_choices[sample.name] = chip_type
		qdel(sample)

	var/choice = tgui_input_list(user, "Which exploit cartridge?", "Spawn EW Cartridge", chip_choices)
	if(!choice)
		return

	if(choice == all_label)
		var/count = 0
		for(var/chip_type in subtypesof(/obj/item/ew_exploit))
			new chip_type(spawn_turf)
			count++
		to_chat(user, span_notice("Spawned one of every cartridge ([count]) at your feet."))
	else
		var/chip_type = chip_choices[choice]
		var/obj/item/ew_exploit/chip = new chip_type(spawn_turf)
		admin_mob.put_in_hands(chip)
		to_chat(user, span_notice("Spawned [chip.name]."))
	message_admins("[key_name_admin(user)] spawned EW cartridge(s): [choice] at [AREACOORD(spawn_turf)].")
	log_admin("[key_name(user)] spawned EW cartridge(s): [choice] at [AREACOORD(spawn_turf)].")
	BLACKBOX_LOG_ADMIN_VERB("Spawn EW Cartridge")

// ========== DIRECT PAYLOAD CONTROL ==========

ADMIN_VERB(apply_ew_payload, R_DEBUG, "Apply EW Payload to Ship", "Instantly apply an EW payload to a target ship, skipping the suite, weapons lock and warmup.", ADMIN_CATEGORY_DEBUG)
	var/list/payload_choices = ew_debug_payload_choices()
	if(!length(payload_choices))
		to_chat(user, span_warning("No EW payloads are defined."))
		return
	var/payload_choice = tgui_input_list(user, "Which payload?", "Apply EW Payload", payload_choices)
	if(!payload_choice)
		return
	var/payload_type = payload_choices[payload_choice]

	var/list/ship_choices = ew_debug_ship_choices()
	if(!length(ship_choices))
		to_chat(user, span_warning("No simulated ships to target."))
		return
	var/ship_choice = tgui_input_list(user, "Apply to which ship?", "Apply EW Payload", ship_choices)
	if(!ship_choice)
		return
	var/obj/structure/overmap/ship/target = ship_choices[ship_choice]
	if(QDELETED(target))
		to_chat(user, span_warning("That ship is gone."))
		return

	// Mode-bearing payloads (e.g. Bolt Override) ask which mode to run
	var/mode = null
	var/datum/ew_payload/proto = get_ew_payload_prototype(payload_type)
	if(proto?.modes)
		mode = tgui_input_list(user, "Which mode?", "Apply EW Payload", proto.modes)
		if(!mode)
			return

	// Attacker is your own ship if you're on one - otherwise the payload runs
	// ownerless, which the payloads tolerate (they null-check the attacker)
	var/obj/structure/overmap/ship/attacker = get_ship_from_atom(user.mob)
	new payload_type(target, attacker, mode)
	to_chat(user, span_notice("Applied [proto?.name || payload_type] to [target.display_name][mode ? " (mode: [mode])" : ""]. It will auto-revert after [proto ? round(proto.duration / 10) : "?"]s."))
	message_admins("[key_name_admin(user)] applied EW payload [proto?.name || payload_type] to [target.display_name].")
	log_admin("[key_name(user)] applied EW payload [proto?.name || payload_type] to [target.display_name].")
	BLACKBOX_LOG_ADMIN_VERB("Apply EW Payload to Ship")

ADMIN_VERB(clear_ew_effects, R_DEBUG, "Clear EW Effects on Ship", "End every active EW payload on a ship and wipe any lingering hack state (no firewall harden).", ADMIN_CATEGORY_DEBUG)
	var/list/ship_choices = ew_debug_ship_choices()
	if(!length(ship_choices))
		to_chat(user, span_warning("No simulated ships."))
		return
	var/ship_choice = tgui_input_list(user, "Clear EW effects on which ship?", "Clear EW Effects", ship_choices)
	if(!ship_choice)
		return
	var/obj/structure/overmap/ship/target = ship_choices[ship_choice]
	if(QDELETED(target))
		to_chat(user, span_warning("That ship is gone."))
		return

	// Deleting the component runs each payload's expire() (restoring target
	// state) with no harden window - cleaner than purge() for a debug reset
	var/datum/component/ship_ew_intrusion/intrusion = target.GetComponent(/datum/component/ship_ew_intrusion)
	if(intrusion)
		qdel(intrusion)

	// Belt-and-braces: clear the deadline vars and injected state directly, in
	// case a payload's restore was interrupted and left a value stuck on
	target.ew_drive_locked_until = 0
	target.ew_forced_burn_until = 0
	target.ew_forced_burn_dir = NONE
	target.ew_fire_control_locked_until = 0
	if(target.ew_phantom_contacts)
		target.ew_phantom_contacts = null
		target.contact_snapshot_time = 0
	if(target.shuttle)
		GLOB.ew_jammed_comms_nets -= "ship_[REF(target.shuttle)]"

	to_chat(user, span_notice("Cleared all EW effects and lingering hack state on [target.display_name]."))
	message_admins("[key_name_admin(user)] cleared EW effects on [target.display_name].")
	log_admin("[key_name(user)] cleared EW effects on [target.display_name].")
	BLACKBOX_LOG_ADMIN_VERB("Clear EW Effects on Ship")
