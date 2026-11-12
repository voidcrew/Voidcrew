/**
 * # Outpost floors: the floor datum
 *
 * Owner: P1 (build plan, "P1 Floor core"). The shared vars and the geometry procs are in _floor_types.dm (P0, frozen).
 *
 * A floor datum lives as long as its trader outpost. It has ground and a host only while it is let: both go
 * together (leave_ground(), host_lost()), and a floor left without them is an unlet floor again.
 */

/datum/outpost_floor
	/// The shell map type this floor loads when it is let; null takes its outpost's style (pick_shell_type()). Tests set it.
	var/shell_type
	/// The mind buying this floor, from the moment it is marked to the moment it is theirs or the sale falls through (A24, A29)
	var/datum/weakref/shell_lessee

/datum/outpost_floor/New(obj/structure/overmap/trader_outpost/new_outpost, new_number)
	..()
	outpost = new_outpost
	number = new_number
	accent = default_accent()

/**
 * Off the lift first, then everyone on the floor to the lobby and the ground given back (A10), then the host.
 * Both ends of every ref are cleared (A36). A floor that dies under warrant takes its two police flags with it
 * (A51); what the police keep of their own they drop on COMSIG_QDELETING.
 */
/datum/outpost_floor/Destroy()
	if(outpost?.floors)
		var/slot = outpost.floors.Find(src)
		if(slot)
			outpost.floors[slot] = null
	leave_ground()
	var/obj/structure/overmap/dynamic/player_outpost/floor/old_host = host
	host = null
	if(old_host)
		if(old_host.floor == src)
			old_host.floor = null
		if(!QDELETED(old_host))
			qdel(old_host)
	guests.Cut()
	barred.Cut()
	hands.Cut()
	shell_lessee = null
	outpost = null
	return ..()

/// The colour a floor starts with: neighbours differ
/datum/outpost_floor/proc/default_accent()
	var/list/ids = OUTPOST_FLOOR_ACCENTS
	return ids[((max(number, 1) - 1) % length(ids)) + 1]

/// The colour to draw this floor's accent in
/datum/outpost_floor/proc/accent_colour()
	var/list/ids = OUTPOST_FLOOR_ACCENTS
	return ids[accent] || ids[OUTPOST_FLOOR_ACCENT_AMBER]

/// Whether `person` is one of the floor's own people: the owner, a resident, or on a crew the owner is on. Not a guest, not a hand.
/// Nobody is while the floor has no owner.
/datum/outpost_floor/proc/is_member(mob/person)
	if(!person || QDELETED(host) || !host.founder_ckey)
		return FALSE
	return !!host.is_outpost_member(person)

/// The name shown under the floor's: the owner's ship, or the owner where there is none
/datum/outpost_floor/proc/crew_name()
	if(QDELETED(host) || !host.founder_ckey)
		return ""
	var/obj/structure/overmap/ship/owner_ship = host.get_owner_ship()
	return owner_ship?.name || host.founder_name || ""

/// The name a floor starts with: the buyer's ship, cut to fit. Ship names are cleaned where they are typed; this is cleaned again for the cut.
/datum/outpost_floor/proc/default_name(mob/living/buyer)
	var/obj/structure/overmap/ship/buyer_ship = get_crew_ship(buyer)
	var/picked = buyer_ship ? reject_bad_text(trim(copytext_char(buyer_ship.name, 1, OUTPOST_FLOOR_NAME_MAX + 1)), OUTPOST_FLOOR_NAME_MAX) : null
	return picked || "Floor [number]"

/// Whether `person`, or anyone on a ship crew with them, holds this floor or is buying it this moment (A24)
/datum/outpost_floor/proc/held_by_crew_of(mob/person)
	if(!person)
		return FALSE
	var/datum/mind/holder
	switch(state)
		if(OUTPOST_FLOOR_STATE_LETTING)
			holder = shell_lessee?.resolve()
		if(OUTPOST_FLOOR_STATE_OWNED)
			if(QDELETED(host) || !host.founder_ckey)
				return FALSE
			if(host.is_owner(person))
				return TRUE
			holder = host.founder_mind?.resolve()
		else
			return FALSE
	if(!holder || !person.mind)
		return FALSE
	if(holder == person.mind)
		return TRUE
	for(var/datum/team/voidcrew/team as anything in person.mind.ship_teams)
		if(team in holder.ship_teams)
			return TRUE
	return FALSE

/**
 * Sees everyone on the floor down to the outpost's lobby, with anything they are riding or shut inside. The
 * ground's release deletes what is left on it, so this runs first. As a berth clears itself
 * (/datum/outpost_berth/proc/eject_occupants()); someone inside a fixture that stays is taken out of it.
 */
/datum/outpost_floor/proc/evict_occupants()
	if(length(bounds) < 5 || QDELETED(outpost))
		return
	var/list/turf/lobby = outpost.get_floor_alcove(0)
	var/turf/fallback = outpost.template_bottom_left
	if(!length(lobby) && !fallback)
		return
	for(var/turf/tile as anything in block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5]))
		for(var/atom/movable/occupant as anything in tile.contents.Copy())
			var/list/atom/movable/leaving
			if(ismob(occupant))
				// Observers pass through the wipe unharmed
				if(isobserver(occupant))
					continue
				leaving = list(occupant)
			else if(length(occupant.contents))
				var/list/mob/living/inside = list()
				for(var/mob/living/person in occupant.get_all_contents())
					inside += person
				if(!length(inside))
					continue
				// A mech or a locker travels whole; a pod bolted to the deck lets its patient go
				leaving = occupant.anchored ? inside : list(occupant)
			else
				continue
			for(var/atom/movable/goer as anything in leaving)
				goer.forceMove(length(lobby) ? pick(lobby) : fallback)
				for(var/mob/living/person in (ismob(goer) ? list(goer) : goer.get_all_contents()))
					to_chat(person, span_warning("Floor [number] is cleared. Outpost staff see you down to the concourse."))

/**
 * Gives the floor's ground back: everyone off it, the lift panel, the landing and the goods lift forgotten, the
 * floor out of every lookup and the reservation freed. With take_ground() (P0) this is all that writes
 * GLOB.outpost_floors_on_ground. A floor with no ground is no ground of the law either, so the two police flags go.
 */
/datum/outpost_floor/proc/leave_ground()
	evict_occupants()
	GLOB.outpost_floors_on_ground -= src
	if(panel?.floor == src)
		panel.floor = null
	panel = null
	alcove_turfs = list()
	goods_turfs = list()
	landing_bounds = null
	warrant_in_force = FALSE
	public_ground = FALSE
	if(reservation)
		if(host?.loading)
			// The map loader is still writing into these turfs: free them once it must be done
			QDEL_IN(reservation, 30 SECONDS)
		else
			qdel(reservation)
		reservation = null
	bounds = null

/// An unlet floor again: nothing of the last owner's settings, lists or name is left on it
/datum/outpost_floor/proc/reset_lease()
	state = OUTPOST_FLOOR_STATE_TENANT
	shell_lessee = null
	floor_name = null
	board_line = ""
	accent = default_accent()
	entry_policy = OUTPOST_FLOOR_ENTRY_CREW
	guests.Cut()
	barred.Cut()
	hands.Cut()

/// The floor's host is going (an admin delete, a sale that fell through): the ground goes with it and the floor is unlet (A10).
/// Called by the host's Destroy() while the two are still linked.
/datum/outpost_floor/proc/host_lost()
	leave_ground()
	reset_lease()
