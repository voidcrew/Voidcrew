/**
 * # Shipyards at berth hosts
 *
 * The shipyard console (/obj/machinery/computer/ship_checkpoint, outpost_checkpoints.dm) saves a
 * docked ship and builds saved ships and new hulls. It runs at two kinds of host:
 *
 * - a player outpost's permanent ship bay (outpost_ship_bay.dm): saves are made in the bay, and
 *   builds load their hidden copy into the level's yard zone and deliver into the bay;
 * - a trader outpost, where every standard hangar berth carries a console (outpost_berth_strip.dmm).
 *   A save is made from the berth the ship is docked in. A build takes a fresh berth of its own:
 *   reserve_rebuild_bay() claims the slot at once, the hidden copy loads into a temporary turf
 *   reservation, and prepare_rebuild_bay() then builds the berth sized to the loaded hull, the
 *   same as a docking ship's. The finished hull keeps that berth until it undocks.
 *
 * Player outposts and the Colosseum use the same berth map but are not shipyards: their berth
 * loses its console as it loads (link_hangar_contents()).
 */

// ===== HOST INTERFACE =====

/obj/structure/overmap
	/// Ship builds under way at this host
	var/list/datum/checkpoint_construction/checkpoint_jobs = list()

/// Whether this host's shipyard consoles work right now.
/obj/structure/overmap/proc/shipyard_open()
	return FALSE

/// Whether every standard berth here keeps its shipyard console.
/obj/structure/overmap/proc/berth_shipyards()
	return FALSE

/// The berths a docked ship can be saved from.
/obj/structure/overmap/proc/shipyard_berths()
	return list()

/// Whether a build could reserve somewhere to deliver its ship right now. Reads only, never claims.
/obj/structure/overmap/proc/available_ship_bay()
	return null

/// Why a build can't start here for want of room, or null.
/obj/structure/overmap/proc/rebuild_bay_denial()
	return available_ship_bay() ? null : "No berth is free."

/// Claims a berth for `owner` (a /datum/checkpoint_construction) with no yield, or returns null.
/obj/structure/overmap/proc/reserve_rebuild_bay(datum/owner)
	return null

/// Gets a reserved berth ready for the loaded hidden copy `port`. May yield. FALSE when it can't be.
/obj/structure/overmap/proc/prepare_rebuild_bay(datum/outpost_berth/bay, obj/docking_port/mobile/port)
	return !QDELETED(bay) && bay.has_ground()

/// The zone on this host's own level that holds a build's hidden copy, or null for a turf reservation.
/obj/structure/overmap/proc/shipyard_source_zone()
	return null

/// Why this host won't serve `user` with `ship` (either may be null), or null.
/obj/structure/overmap/proc/shipyard_refusal(mob/living/user, obj/structure/overmap/ship/ship)
	return null

/// The host whose shipyard a console at `thing` belongs to: a player outpost, or the trader outpost
/// whose berth it stands in. Never a docked hull's own deck.
/proc/get_shipyard_host(atom/thing)
	var/obj/structure/overmap/home = get_outpost_from_atom(thing)
	if(home)
		return home
	var/turf/location = get_turf(thing)
	if(!location || SSshuttle.get_containing_shuttle(location) || get_voidcrew_ship_for_turf(location))
		return null
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		for(var/datum/outpost_berth/berth as anything in outpost.berths)
			if(berth?.contains_turf(location))
				return outpost
	return null

// ===== BERTH INTERFACE =====
// What a build needs from the berth it delivers into. The ship bay overrides what differs.

/// Whether the shipyard console mapped into this berth stays when the berth loads.
/datum/outpost_berth/proc/keeps_shipyard_console()
	return !!outpost?.berth_shipyards()

/// A player outpost's ship bay is its shipyard.
/datum/outpost_berth/ship_bay/keeps_shipyard_console()
	return TRUE

/datum/outpost_berth/proc/is_ship_present()
	return !QDELETED(outpost) && !QDELETED(ship) && !QDELETED(ship.shuttle) && ship.docked == outpost && ship.state == OVERMAP_SHIP_IDLE && dock?.get_docked() == ship.shuttle

/// Whether a build's deck may still be laid here: the ground is held, or is built once the hull loads.
/datum/outpost_berth/proc/has_build_ground()
	return ground_on_build || (!QDELETED(dock) && has_ground())

/// The berth's name in messages to its ship.
/datum/outpost_berth/proc/berth_label()
	return "Berth [berth_number]"

/// Where build drones fly out from when the hangar has no drone bays.
/datum/outpost_berth/proc/drone_launch_turf()
	if(shipyard)
		return get_turf(shipyard)
	return length(alcove_turfs) ? alcove_turfs[1] : get_turf(dock)

/datum/outpost_berth/proc/update_status()
	var/datum/checkpoint_construction/build = rebuild_owner?.resolve()
	var/bottom_line = ship?.name || (istype(build) ? build.bay_status() : "FREIGHT")
	for(var/obj/machinery/status_display/outpost_berth/sign as anything in status_signs)
		sign.set_messages("BERTH [berth_number]", bottom_line)
	outpost?.refresh_elevator_uis()

/// The build is over without a ship handed over: a berth held only for it goes.
/datum/outpost_berth/proc/finish_rebuild(datum/owner)
	if(!IS_WEAKREF_OF(owner, rebuild_owner))
		return
	rebuild_owner = null
	ground_on_build = FALSE
	if(!ship)
		release()
		return
	update_status()

/// The build has landed its hull here; the berth now belongs to the new ship, as if it had docked.
/datum/outpost_berth/proc/complete_rebuild(obj/structure/overmap/ship/rebuilt, datum/owner)
	if(QDELETED(src) || !IS_WEAKREF_OF(owner, rebuild_owner) || ship || QDELETED(rebuilt) || QDELETED(rebuilt.shuttle) || dock?.get_docked() != rebuilt.shuttle)
		return FALSE
	ship = rebuilt
	arrived = TRUE
	release_retries = 0
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_ship_docked))
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))
	rebuild_owner = null
	update_status()
	return TRUE

/// The hangar keeps its own atmosphere. A departing hull leaves its own air on the pad, vacuum
/// from its outer plating included, and the sealed hangar would spend the next few minutes (and
/// a lot of atmos time) evening that out, drawing its pressure down for good. Every hangar
/// tile not under a ship goes back to the hangar's own air instead, already settled.
/datum/outpost_berth/proc/refresh_hangar_air()
	for(var/turf/open/tile in get_block())
		if(!tile.air || tile.blocks_air || istype(tile.loc, /area/shuttle))
			continue
		tile.air.copy_from(tile.create_gas_mixture())
		SSair.remove_from_active(tile)

/datum/outpost_berth/ship_bay/has_build_ground()
	return !QDELETED(dock) && has_ground()

/datum/outpost_berth/ship_bay/berth_label()
	return "Ship Bay [bay_number]"

/datum/outpost_berth/ship_bay/drone_launch_turf()
	if(console)
		return get_turf(console)
	return ..()

// ===== PLAYER OUTPOSTS =====

/obj/structure/overmap/dynamic/player_outpost/shipyard_open()
	return ship_bay_installed

/obj/structure/overmap/dynamic/player_outpost/shipyard_berths()
	return bay_berths

/obj/structure/overmap/dynamic/player_outpost/rebuild_bay_denial()
	return available_ship_bay() ? null : "The ship bay is occupied."

/obj/structure/overmap/dynamic/player_outpost/shipyard_source_zone()
	return level_zone(OUTPOST_ZONE_YARD)

// ===== TRADER OUTPOSTS =====

/obj/structure/overmap/trader_outpost/shipyard_open()
	return loaded && !loading

/obj/structure/overmap/trader_outpost/berth_shipyards()
	return TRUE

/obj/structure/overmap/trader_outpost/shipyard_berths()
	. = list()
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth)
			. += berth

/// The lowest berth slot nobody holds, or 0.
/obj/structure/overmap/trader_outpost/proc/free_berth_slot()
	if(!shipyard_open())
		return 0
	if(!berths)
		berths = new /list(OUTPOST_MAX_BERTHS)
	for(var/i in 1 to min(berth_capacity(), length(berths)))
		if(!berths[i])
			return i
	return 0

/obj/structure/overmap/trader_outpost/available_ship_bay()
	return free_berth_slot() > 0

/obj/structure/overmap/trader_outpost/rebuild_bay_denial()
	return available_ship_bay() ? null : "Every berth is taken."

/// The slot is claimed now; the hangar is built once the hull is loaded and its size known.
/obj/structure/overmap/trader_outpost/reserve_rebuild_bay(datum/owner)
	var/slot = free_berth_slot()
	if(!slot || QDELETED(owner))
		return null
	var/datum/outpost_berth/berth = new(src, slot, null)
	berth.rebuild_owner = WEAKREF(owner)
	berth.ground_on_build = TRUE
	berths[slot] = berth
	refresh_elevator_uis()
	return berth

/obj/structure/overmap/trader_outpost/prepare_rebuild_bay(datum/outpost_berth/bay, obj/docking_port/mobile/port)
	if(QDELETED(bay) || bay.outpost != src || QDELETED(port))
		return FALSE
	if(!bay.ground_on_build)
		return bay.has_build_ground()
	var/list/pad_size = outpost_berth_pad_size(port)
	var/datum/map_template/outpost_berth_strip/strip = get_outpost_berth_strip()
	if(!pad_size || !strip.width || !strip.height)
		return FALSE
	var/datum/outpost_berth_layout/layout = new(pad_size[1], pad_size[2], strip.width, strip.height)
	var/built = bay.build_standard_hangar(layout, strip)
	if(QDELETED(src) || QDELETED(bay))
		return FALSE
	bay.ground_on_build = FALSE
	if(!built)
		return FALSE
	bay.update_status()
	return TRUE

/obj/structure/overmap/trader_outpost/shipyard_refusal(mob/living/user, obj/structure/overmap/ship/ship)
	if(ship && is_ship_embargoed(ship))
		return "[name] won't deal with your ship."
	if(user?.mind && is_marked_aggressor(user.mind))
		return "[name] won't deal with you."
	return null

/// Whether `location` is in a trader outpost build's hidden copy, which nobody may teleport into.
/proc/in_shipyard_copy(turf/location)
	if(!location)
		return FALSE
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		for(var/datum/checkpoint_construction/build as anything in outpost.checkpoint_jobs)
			var/datum/turf_reservation/copy = build.source_reservation
			if(QDELETED(copy) || !length(copy.bottom_left_turfs) || !length(copy.top_right_turfs))
				continue
			var/turf/low = copy.bottom_left_turfs[1]
			var/turf/high = copy.top_right_turfs[1]
			if(location.z == low.z && location.x >= low.x && location.x <= high.x && location.y >= low.y && location.y <= high.y)
				return TRUE
	return FALSE
