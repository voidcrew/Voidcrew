/datum/map_template/shuttle/voidcrew
	/// The ship's account starts empty rather than with the usual commissioning funds.
	var/no_starting_funds = FALSE

/// Runs in create_ship() on the loaded ship, with atmos still paused. Must not sleep.
/datum/map_template/shuttle/voidcrew/proc/finish_loaded_copy(obj/docking_port/mobile/voidcrew/loaded)
	return

/datum/map_template/shuttle/voidcrew/commissioned/checkpoint
	no_starting_funds = TRUE

/// What a console rebuild does to its hidden copy, for a saved ship loaded whole from the lobby. It
/// stays in one tick, for the reason given at /datum/checkpoint_construction/proc/prepare_copy().
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/finish_loaded_copy(obj/docking_port/mobile/voidcrew/loaded)
	if(!blueprint)
		return
	// A saved port stores no name, and create_ship() names the ship after its port.
	loaded.name = name
	checkpoint_clear_stock(loaded, ship_save_restocked())
	for(var/turf/tile as anything in loaded.return_turfs())
		if(!(get_area(tile) in loaded.shuttle_areas))
			continue
		for(var/obj/machinery/machine in tile)
			checkpoint_restore_machine(machine)
			checkpoint_provision_machine(machine)
			// Player ships carry no door access.
			if(istype(machine, /obj/machinery/door))
				var/obj/machinery/door/door = machine
				door.req_access = null
				door.req_one_access = null
	blueprint = null

/**
 * Loads a saved ship and seats the player on it, the way buying a hull does. The save is spent once the
 * ship has loaded. Sleeps at the read and in the shipyard's queue, and the player can leave during either:
 * this runs here rather than on their mob, which a logout deletes, so nothing stops it before the spend.
 */
/datum/ship_saves/proc/launch(mob/dead/new_player/player, slot)
	if(QDELETED(player) || !player.ckey)
		return
	if(!SSticker?.IsRoundInProgress())
		to_chat(player, span_danger("The round is either not ready, or has already finished..."))
		return
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		alert(player, "An administrator has disabled late join spawning.")
		if(!QDELETED(player))
			player.select_ship()
		return
	// Prevent double-click spawning
	if(player.spawning_ship)
		to_chat(player, span_warning("Your ship is already being prepared. Please wait..."))
		return
	var/player_ckey = player.ckey
	var/denial = retrieve_denial(player_ckey, slot)
	if(denial)
		to_chat(player, span_warning(denial))
		return player.select_ship()
	if(!begin_retrieval(player_ckey, slot))
		to_chat(player, span_warning("Already under way."))
		return player.select_ship()
	player.spawning_ship = TRUE

	var/datum/ship_checkpoint/snapshot = read_save(player_ckey, slot)
	if(istext(snapshot) || QDELETED(player))
		cancel_retrieval(player_ckey, slot)
		if(QDELETED(player))
			if(!istext(snapshot))
				qdel(snapshot)
			return
		player.spawning_ship = FALSE
		to_chat(player, span_warning(snapshot))
		return player.select_ship()

	to_chat(player, span_notice("[snapshot.ship_name] is being prepared. Please be patient!"))
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/template = new(snapshot)
	var/obj/structure/overmap/ship/target = SSshuttle.create_ship(template)
	qdel(snapshot)
	if(!istype(target))
		qdel(template)
		cancel_retrieval(player_ckey, slot)
		if(QDELETED(player))
			return
		player.spawning_ship = FALSE
		// A refusal at the map-volume ceiling is transient, as in spawn_ship_with_upgrades().
		if(SSmapping.at_z_level_ceiling())
			to_chat(player, span_warning("The shipyard is congested right now - hull assembly space frees up as ships move. Try again in a minute."))
		else
			to_chat(player, span_danger("There was an error loading the ship. Please contact admins!"))
		return player.select_ship()

	// The ship exists now, whether or not its captain stayed to board it. Left, they can join it from the menu.
	spend(player_ckey, slot)
	log_game("[player_ckey] launched [target.name] from ship save slot [slot].")
	target.password_cleared_ckeys[player_ckey] = TRUE
	if(QDELETED(player))
		return
	ship_metric_purchased(target, player)
	if(!player.AttemptSpawnOnShip(target.job_slots[1], target))
		if(QDELETED(player))
			return
		to_chat(player, span_danger("Ship spawned, but you were unable to be spawned. You can likely try to spawn in the ship through joining normally, but if not, please contact an admin."))
		player.spawning_ship = FALSE
		player.select_ship()
