/**
 * Voidcrew: fulton recovery beacons belong to the crew that deployed them.
 *
 * Upstream puts every beacon in the game on one global list and lets any pack on a
 * matching network lock onto any of them, which on a multi-ship server means you can
 * quietly route someone else's salvage onto your own deck. Beacons now remember the
 * crew that unfolded them and refuse packs held by anyone else, unless the owner
 * deliberately opens them up.
 */
/obj/structure/extraction_point
	/// Weakref to the /datum/team/voidcrew that owns this beacon. Null means nobody ever claimed it.
	var/datum/weakref/owner_team_ref
	/// Weakref to the mind that unfolded this beacon, so a crewless deployer can still use their own gear.
	var/datum/weakref/owner_mind_ref
	/// While TRUE, only the owning crew can link a pack to this beacon.
	var/beacon_locked = TRUE

/**
 * Records who this beacon answers to. Called once, right after the beacon is unfolded.
 *
 * If the deployer is standing on a ship they crew, that ship's team owns the beacon, so a
 * beacon dropped on your own deck stays with the deck rather than with whoever happened to
 * carry the kit. Otherwise it falls back to the deployer's own crew.
 */
/obj/structure/extraction_point/proc/set_beacon_owner(mob/deployer)
	var/datum/mind/deployer_mind = deployer?.mind
	if(isnull(deployer_mind))
		return
	owner_mind_ref = WEAKREF(deployer_mind)

	var/datum/team/voidcrew/owner_team
	var/obj/structure/overmap/ship/local_ship = get_ship_from_atom(src)
	if(local_ship?.ship_team && (deployer_mind in local_ship.ship_team.members))
		owner_team = local_ship.ship_team
	else
		for(var/datum/team/voidcrew/team as anything in deployer_mind.ship_teams)
			owner_team = team
			break

	if(owner_team)
		owner_team_ref = WEAKREF(owner_team)

/// TRUE if [user] owns this beacon, and so may flip its transponder either way.
/obj/structure/extraction_point/proc/can_configure(mob/user)
	var/datum/team/voidcrew/owner_team = owner_team_ref?.resolve()
	var/datum/mind/owner_mind = owner_mind_ref?.resolve()
	// Never claimed by anyone (mapped in, admin spawned, owner's crew is long gone) - up for grabs.
	if(isnull(owner_team) && isnull(owner_mind))
		return TRUE

	var/datum/mind/user_mind = user?.mind
	if(isnull(user_mind))
		return FALSE
	if(owner_mind && user_mind == owner_mind)
		return TRUE
	return owner_team && (user_mind in owner_team.members)

/// TRUE if [user] is allowed to link a pack to this beacon and fire things at it.
/obj/structure/extraction_point/proc/can_crew_use(mob/user)
	if(!beacon_locked)
		return TRUE
	return can_configure(user)

/obj/structure/extraction_point/examine(mob/user)
	. = ..()
	var/datum/team/voidcrew/owner_team = owner_team_ref?.resolve()
	if(!beacon_locked)
		. += span_notice("Its transponder is <b>open</b> - any recovery pack can lock onto it.")
	else if(owner_team)
		. += span_notice("Its transponder is keyed to the <b>[owner_team.name]</b> crew.")
	else
		. += span_notice("Its transponder is keyed to whoever deployed it.")

	if(can_crew_use(user))
		. += span_notice("Right-click to switch its transponder between crew-only and open.")

/obj/structure/extraction_point/attack_hand_secondary(mob/user, list/modifiers)
	if(!can_crew_use(user))
		balloon_alert(user, "transponder locked!")
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	beacon_locked = !beacon_locked
	balloon_alert(user, beacon_locked ? "crew only" : "open to all")
	// A beacon that has been opened up and re-locked should belong to whoever locked it.
	if(beacon_locked && isnull(owner_mind_ref?.resolve()) && isnull(owner_team_ref?.resolve()))
		set_beacon_owner(user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/**
 * Replaces the upstream deploy so the fresh beacon learns who put it down.
 * Deliberately does not call parent - the parent builds an unowned beacon.
 */
/obj/item/fulton_core/attack_self(mob/user)
	var/area/user_area = get_area(user)
	if(user_area.area_flags & NOTELEPORT)
		balloon_alert(user, "unable to deploy!")
		return

	if(!do_after(user, 1.5 SECONDS, target = user) || QDELETED(src))
		return

	var/obj/structure/extraction_point/beacon = new(get_turf(user))
	beacon.set_beacon_owner(user)
	playsound(src, 'sound/items/deconstruct.ogg', vol = 50, vary = TRUE, extrarange = MEDIUM_RANGE_SOUND_EXTRARANGE)
	qdel(src)

/**
 * Replaces the upstream link menu so locked beacons never show up in the list.
 * Deliberately does not call parent - the parent offers every beacon on the network.
 */
/obj/item/extraction_pack/attack_self(mob/user)
	var/list/possible_beacons = list()
	var/blocked_beacons = 0
	for(var/datum/weakref/point_ref as anything in GLOB.total_extraction_beacons)
		var/obj/structure/extraction_point/extraction_point = point_ref.resolve()
		if(isnull(extraction_point))
			GLOB.total_extraction_beacons.Remove(point_ref)
			continue
		if(!(extraction_point.beacon_network in beacon_networks))
			continue
		if(!extraction_point.can_crew_use(user))
			blocked_beacons++
			continue
		possible_beacons += extraction_point

	if(!length(possible_beacons))
		balloon_alert(user, blocked_beacons ? "beacons locked!" : "no beacons")
		return

	var/chosen_beacon = tgui_input_list(user, "Beacon to connect to", "Balloon Extraction Pack", sort_names(possible_beacons))
	if(isnull(chosen_beacon))
		return

	beacon_ref = WEAKREF(chosen_beacon)
	balloon_alert(user, "linked!")

/// Catches a pack that was linked by a crewmate and then handed off to an outsider.
/obj/item/extraction_pack/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ismovable(interacting_with) || !isturf(interacting_with.loc))
		return ..()

	var/obj/structure/extraction_point/beacon = beacon_ref?.resolve()
	if(beacon && !beacon.can_crew_use(user))
		balloon_alert(user, "beacon locked!")
		return ITEM_INTERACT_BLOCKING

	return ..()
