/**
 * # Cargo dock
 *
 * The free outpost upgrade that outpost freight (outpost_freight.dm) lands on. The room holds a
 * landing pad sized to the cargo ferry (/datum/map_template/shuttle/cargo/box) with deck round
 * it. The ferry docks on the pad's stationary port with its doors toward the room's entrance.
 * Until a claim places one, its cargo console refuses to order.
 */

/// Each placement loads its own instance (the parent has no UNIQUE_AREA), with its own APC.
/area/voidcrew/player_outpost/cargo_dock
	name = "\improper Cargo Dock"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "cargo_bay"

/**
 * The landing pad. The mapped values are the cargo ferry's own mobile port: the box ferry is
 * 7x12 with its port on an airlock in the middle of its long side, facing inboard. The map puts
 * this port on the pad's edge beside the apron, facing into the pad, so the ferry lands with that
 * airlock row on the apron side.
 */
/obj/docking_port/stationary/outpost_cargo_dock
	name = "cargo dock pad"
	shuttle_id = "outpost_cargo_dock"
	dir = NORTH
	width = 12
	height = 7
	dwidth = 5
	dheight = 0

/**
 * Docking ports ignore shuttleRotate(), so a rotated upgrade load would leave the pad facing the
 * way it was drawn. width, height, dwidth and dheight are all measured along dir, so turning dir
 * about the port tile turns the whole landing rectangle with the room.
 */
/obj/docking_port/stationary/outpost_cargo_dock/template_load_rotate(rotation)
	setDir(angle2dir(rotation + dir2angle(dir)))

/**
 * What the ferry would crush if it landed now. A landing gibs every mob on its turfs and
 * deletes every anchored object there (/turf/proc/toShuttleMove()). Freight lands anyway; the
 * room contract uses this so a new pad never comes with anything on it:
 * - a mob, alive or dead, or anything holding one (a person in a crate, locker, mech or body bag);
 * - anything anchored or dense.
 * Docking ports, effects and landmarks never count, nor does anything the crush spares
 * (incorporeal mobs, SHUTTLE_CRUSH_PROOF). Loose items are pushed off the pad by the landing.
 *
 * Returns the thing as it stands on the pad (the crate, not the person inside), or null.
 * Only meaningful while nothing is docked here.
 */
/obj/docking_port/stationary/outpost_cargo_dock/proc/pad_obstruction()
	for(var/turf/tile as anything in return_turfs())
		for(var/atom/movable/thing as anything in tile)
			if(istype(thing, /obj/docking_port) || (thing.resistance_flags & SHUTTLE_CRUSH_PROOF))
				continue
			for(var/mob/living/occupant as anything in thing.get_all_contents_type(/mob/living))
				if(!occupant.incorporeal_move)
					return thing
			if(isobj(thing) && !iseffect(thing) && (thing.anchored || thing.density))
				return thing
	return null

/// The middle of the landing rectangle.
/obj/docking_port/stationary/outpost_cargo_dock/proc/pad_center()
	var/list/coords = return_coords()
	return locate(round((coords[1] + coords[3]) / 2), round((coords[2] + coords[4]) / 2), z)

/// The last warning before the ferry lands: an alarm and a message for everyone who can see the pad.
/obj/docking_port/stationary/outpost_cargo_dock/proc/warn_landing(seconds)
	var/turf/center = pad_center()
	if(!center)
		return FALSE
	playsound(center, 'sound/machines/warning-buzzer.ogg', 60, FALSE)
	center.visible_message(span_boldwarning("Warning lights flash around the landing pad. The cargo ferry lands in [seconds] seconds."), \
		blind_message = span_warning("You hear a landing alarm."), vision_distance = 9)
	return TRUE

/// Authored with its entrance on the south edge; placement rotates it.
/datum/map_template/outpost_upgrade/cargo_dock
	name = "Outpost Cargo Dock"

/datum/map_template/outpost_upgrade/cargo_dock/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_cargo_dock_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/cargo_dock/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_cargo_dock_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/outpost_upgrade/cargo_dock
	id = "cargo_dock"
	name = "Cargo Dock"
	desc = "A landing pad for freight deliveries."
	price = 0
	template_type = /datum/map_template/outpost_upgrade/cargo_dock
	area_type = /area/voidcrew/player_outpost/cargo_dock
	entrance_side = SOUTH
	/// The pad's docking port, once placement has finished
	var/obj/docking_port/stationary/outpost_cargo_dock/pad

/datum/outpost_upgrade/cargo_dock/Destroy()
	if(pad)
		UnregisterSignal(pad, COMSIG_QDELETING)
		qdel(pad, TRUE) // docking ports refuse a plain qdel
		pad = null
	return ..()

/datum/outpost_upgrade/cargo_dock/on_installed(mob/user)
	if(pad || !footprint_bounds)
		return
	var/z = footprint_bounds[5]
	for(var/turf/tile as anything in block(footprint_bounds[1], footprint_bounds[2], z, footprint_bounds[3], footprint_bounds[4], z))
		pad = locate() in tile
		if(pad)
			break
	if(!pad)
		log_mapping("PLAYER OUTPOST: the cargo dock at '[outpost]' loaded without its landing pad port.")
		return
	pad.name = "[outpost.name] Cargo Dock"
	RegisterSignal(pad, COMSIG_QDELETING, PROC_REF(on_pad_deleted))

/**
 * A level teardown force-deletes every port on it, ours included. Plain qdel() calls also send
 * this signal but leave the port standing (QDEL_HINT_LETMELIVE), and every ferry landing and
 * departure makes one on the pad's tile, so only a forced delete loses the pad.
 */
/datum/outpost_upgrade/cargo_dock/proc/on_pad_deleted(datum/source, force)
	SIGNAL_HANDLER
	if(force)
		pad = null

/// The placed cargo dock's landing pad, or null when the claim has none.
/obj/structure/overmap/dynamic/player_outpost/proc/cargo_dock_port()
	var/datum/outpost_upgrade/cargo_dock/dock = outpost_upgrades["cargo_dock"]
	if(!istype(dock) || !dock.installed || QDELETED(dock.pad))
		return null
	return dock.pad

/// Whether the cargo ferry is docked at this claim and covers the turf.
/obj/structure/overmap/dynamic/player_outpost/proc/cargo_ferry_covers(turf/tile)
	var/obj/docking_port/mobile/ferry = freight?.shuttle_port
	var/obj/docking_port/stationary/pad = cargo_dock_port()
	if(QDELETED(ferry) || !pad || ferry.get_docked() != pad)
		return FALSE
	return ferry.is_in_shuttle_bounds_geometric(tile)
