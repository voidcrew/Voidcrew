/**
 * Voidcrew: player ships show up in the ghost orbit menu.
 *
 * Ghosts could already track a nuke disk but had no way to pick a ship to watch, which is
 * the one thing most observers actually want to do here. Ships are created and destroyed
 * all round long, so rather than registering points of interest at ship creation and
 * chasing every lifecycle edge (hull destroyed, NPC ship claimed at the helm, ship
 * abandoned), the whole set is re-synced every time the orbit menu builds its data. The
 * list is therefore always current as of the moment the ghost opened or refreshed it.
 *
 * The POI is the ship's mobile docking port rather than its overmap marker. The marker
 * lives on the overmap z-level, so orbiting it would park the ghost on a strategic map;
 * the docking port sits on the hull, so following one drops you aboard. The port carries
 * the ship's name and set_ship_name() keeps the two in sync, so renames are picked up for
 * free - get_other_pois() reads the name live.
 */
/datum/orbit_menu/ui_static_data(mob/user)
	sync_ship_points_of_interest()
	return ..()

/// Brings the registered ship points of interest in line with the ships that exist right now.
/proc/sync_ship_points_of_interest()
	// Drop any ship port we previously listed whose ship is gone or no longer qualifies.
	for(var/datum/point_of_interest/poi as anything in SSpoints_of_interest.other_points_of_interest.Copy())
		var/obj/docking_port/mobile/voidcrew/port = poi.target
		if(!istype(port))
			continue
		var/obj/structure/overmap/ship/ship = port.current_ship
		if(!QDELETED(ship) && ship.is_orbitable_by_ghosts())
			continue
		SSpoints_of_interest.remove_point_of_interest(port)

	// Add every ship that qualifies and isn't listed yet.
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship) || !ship.is_orbitable_by_ghosts())
			continue
		var/obj/docking_port/mobile/voidcrew/port = ship.shuttle
		if(QDELETED(port))
			continue
		if(SSpoints_of_interest.points_of_interest_by_target_ref[REF(port)])
			continue
		SSpoints_of_interest.make_point_of_interest(port)

/// TRUE if ghosts should be offered this ship in the orbit menu.
/obj/structure/overmap/ship/proc/is_orbitable_by_ghosts()
	return TRUE

/// NPC hulls only become interesting once players are actually flying them.
/obj/structure/overmap/ship/npc/is_orbitable_by_ghosts()
	return player_controlled

/// Labels ship entries in the Misc list so they aren't just a bare name among the anomalies.
/datum/orbit_menu/get_misc_data(atom/movable/atom_poi)
	. = ..()
	var/obj/docking_port/mobile/voidcrew/port = atom_poi
	if(!istype(port))
		return
	var/obj/structure/overmap/ship/ship = port.current_ship
	if(QDELETED(ship))
		return
	var/list/misc = .[1]
	misc["extra"] = "Ship: [length(ship.manifest)] crew"
