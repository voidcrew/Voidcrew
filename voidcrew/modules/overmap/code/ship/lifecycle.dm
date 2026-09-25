///
/// Hull lifecycle.
///
/// The derelict paths: abandonment (crewless clock from the SSovermap sweep),
/// claiming an abandoned hull, force removal and derelict despawn, plus the
/// occupancy checks the sweep depends on (has_active_crew, dead-site detection).

/**
 * ##destroy_ship
 *
 * Deletes the ship, if there's no humans on.
 */
/**
 * Abandons the ship - clears ownership and makes it claimable by anyone.
 * Called when all crew die/leave and the deletion timer fires.
 * * crash - If TRUE, crash the ship if it's currently flying
 */
/obj/structure/overmap/ship/proc/abandon_ship(crash = TRUE)
	if(abandoned)
		return // Already abandoned

	abandoned = TRUE
	abandoned_at = world.time // starts the derelict-despawn clock (SSovermap.sweep_derelicts)
	joining_allowed = FALSE // Disable cryopod spawning until claimed
	// A derelict is public salvage - the old crew's lock dies with their tenure
	join_password = null
	password_cleared_ckeys = list()
	// ...and so does the crew-only airlock lock. Set directly rather than through
	// set_crew_only_airlocks(): the roster is about to be emptied, so its crew
	// announcement would reach nobody anyway.
	crew_only_airlocks = FALSE
	GLOB.crew_locked_ships -= src

	// Clear all crew members properly (removes antag datums). Snapshot the roster
	// first: the announcement at the bottom has to reach these players, and by the
	// time it runs the team is empty.
	var/list/former_members
	if(ship_team)
		former_members = ship_team.members?.Copy()
		for(var/datum/mind/member in former_members)
			ship_team.remove_member(member)

	// If flying and crash requested, trigger crash landing. Drive the latch along with it, or
	// the hull reads sound while sitting in a crash site and the next real hit is swallowed by
	// on_ship_destroyed()'s re-entry guard.
	if(crash && (state in list(OVERMAP_SHIP_FLYING, OVERMAP_SHIP_UNDOCKING, OVERMAP_SHIP_ACTING)))
		enter_integrity_failure()

	// Crash docking finishes asynchronously. Follow the shuttle itself so this link
	// still reaches the hull after it leaves the coordinates where it was abandoned.
	message_admins("\[SHUTTLE]: [name] has been abandoned and is now claimable! It will despawn in [SHIP_DERELICT_DESPAWN_TIME / 600] minutes if unclaimed. [ADMIN_FLW(shuttle)]")
	log_shuttle("[name] has been abandoned and is claimable; despawn due in [SHIP_DERELICT_DESPAWN_TIME / 600] minutes.")

	// Use the saved roster because ship_notify() would see the now-empty team.
	for(var/mob/player_mob as anything in get_abandonment_recipients(former_members))
		to_chat(player_mob, span_boldwarning("Your ship, [name], has been abandoned: it went too long with no living crew aboard. It no longer appears in the ship join list, but it is still out there - anyone who reaches it can claim it from its helm console."))
		SEND_SOUND(player_mob, sound('voidcrew/sound/warn.ogg', volume = 25))

/// Find the players still playing (or ghosting) the characters on the former roster.
/obj/structure/overmap/ship/proc/get_abandonment_recipients(list/former_members)
	var/list/recipients = list()
	for(var/datum/mind/member as anything in former_members)
		if(!member?.key)
			continue
		var/mob/player_mob = get_mob_by_ckey(ckey(member.key))
		// Old minds keep their key after respawning. An account match alone can
		// notify a different crew's character, once per old life on this roster.
		// Ghosts retain the body's mind, so this still reaches dead crewmembers.
		if(!player_mob || player_mob.mind != member)
			continue
		recipients |= player_mob
	return recipients

/**
 * Claims an abandoned ship for a new owner.
 * * claimer - The mob claiming the ship
 */
/obj/structure/overmap/ship/proc/claim_abandoned_ship(mob/living/claimer)
	if(!abandoned)
		return FALSE
	if(!claimer?.mind)
		return FALSE

	// Reset abandoned state, stopping the derelict-despawn clock
	abandoned = FALSE
	abandoned_at = 0
	crewless_since = 0
	joining_allowed = TRUE // Re-enable cryopod spawning

	// Create new ship team or use existing (cleared) one
	if(!ship_team)
		ship_team = new /datum/team/voidcrew()
		ship_team.name = name
		ship_team.ship = src

	// Add claimer to ship team. Every crew-adding path also clears the ckey through
	// the join password gate - the claimer must never be locked out of the hull they
	// now command if they die and respawn through the lobby.
	ship_team.add_member(claimer.mind)
	if(claimer.ckey)
		password_cleared_ckeys[claimer.ckey] = TRUE

	// Set the claimer as captain
	claimed_captain = claimer.mind

	// A claimed captain supersedes any acting command
	clear_acting_captain(claimer)

	// Grant the Captain Management action button
	grant_captain_management(claimer, src)

	// Announce
	ship_notify("NOTICE: Command authorization restored. New commanding officer: [claimer.real_name].", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	to_chat(claimer, span_notice("You have claimed command of [name]!"))
	log_game("[key_name(claimer)] claimed abandoned ship [name] at [AREACOORD(src)]")

	return TRUE

/**
 * Removes the ship from the round.
 *
 * force = TRUE deletes the hull outright; otherwise the ship is left behind as an
 * abandoned derelict for someone else to claim.
 *
 * ignore_crew exists for the bluespace jump, which is meant to take the crew with
 * it - the helm asks for confirmation first, and extraction runs before the call.
 * Without it the crew check below rejected every jump ever attempted, silently:
 * anyone flying the ship is by definition standing on it, and do_jump() is the
 * only caller there has ever been.
 */
/obj/structure/overmap/ship/proc/destroy_ship(force, ignore_crew = FALSE)
	// For backward compatibility, redirect to abandon_ship unless forced
	if(force)
		if(!ignore_crew && length(shuttle?.get_all_humans()) > 0)
			return FALSE
		message_admins("\[SHUTTLE]: [shuttle?.name] has been FORCE deleted!")
		log_shuttle("[shuttle?.name] has been force deleted!")
		var/obj/docking_port/mobile/owned_shuttle = detach_shuttle()
		owned_shuttle?.jumpToNullSpace()
		qdel(src)
		return TRUE

	// Normal case: abandon instead of delete
	abandon_ship()
	return TRUE

/**
 * Deletes a derelict hull and releases everything it was pinning: the berth flags at
 * whatever it is docked to (which is what lets that site's own unload machinery tear
 * down its map zone - a derelict never undocks, so without this every abandoned ship
 * pinned a zone and eventually a whole z-level for the rest of the round), its transit
 * reservation, and its overmap datum.
 *
 * Called only by SSovermap.sweep_derelicts() once the claim window is over. Anyone
 * physically aboard aborts the teardown; the sweep simply tries again a minute later.
 */
/obj/structure/overmap/ship/proc/despawn_derelict()
	if(QDELETED(src))
		return FALSE
	// Any connected player physically aboard holds the teardown - dead ones too,
	// deliberately: a body with a player behind it may be mid-rescue, and unlike the
	// abandonment clock this check costs nothing to be generous with.
	for(var/mob/player as anything in GLOB.player_list)
		if(isliving(player) && is_aboard(player))
			return FALSE
	// A ship docked to us ship-to-ship parks its overmap token in our contents.
	// Deleting the host would strand the guest inside a deleted loc.
	for(var/obj/structure/overmap/ship/guest in src)
		if(!QDELETED(guest))
			return FALSE

	log_shuttle("[name]: derelict despawned (abandoned [(world.time - abandoned_at) / 600] minutes ago).")
	message_admins("\[SHUTTLE]: Derelict [name] has despawned. [ADMIN_COORDJMP(shuttle?.loc)]")

	// Hand our berth back before the hull goes - the subset of complete_dock()'s
	// undocking branch that releases the site. can_release_interior() reads these
	// flags, and a deleted ship never runs the undock path that clears them.
	var/obj/structure/overmap/site = docked
	if(site)
		if(istype(site, /obj/structure/overmap/ship))
			var/obj/structure/overmap/ship/host = site
			if(host.shuttle && shuttle && host.shuttle != shuttle)
				host.shuttle.shuttle_areas -= shuttle.shuttle_areas
			SEND_SIGNAL(host, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY, src)
		release_berth_flags(site)
		site.on_ship_undock_complete(src) // frees hangar berths at outposts; no-op elsewhere
		if(istype(site, /obj/structure/overmap/space_ruin))
			addtimer(CALLBACK(site, TYPE_PROC_REF(/obj/structure/overmap/space_ruin, check_start_despawn)), 5 SECONDS)
		else if(istype(site, /obj/structure/overmap/event/meteor))
			addtimer(CALLBACK(site, TYPE_PROC_REF(/obj/structure/overmap/event/meteor, unload_level)), 5 SECONDS)
		// Planets and empty-space placeholders (crash sites included) registered
		// on_ship_undocked() on us when we entered; this is what schedules their own
		// unload once the hull is gone.
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_UNDOCKED)
		docked = null

	// Drop the hard refs other ships hold on us. A stale entry keeps the datum from
	// garbage collecting and hands SSgarbage an expensive hard delete instead.
	for(var/obj/structure/overmap/ship/other as anything in SSovermap.simulated_ships)
		if(other == src)
			continue
		LAZYREMOVE(other.close_overmap_objects, src)
		if(other.pending_dock_target == src)
			other.pending_dock_target = null

	// intoTheSunset() rather than a bare jumpToNullSpace(): it ghostizes every mob aboard
	// first, corpses included. A mind-holding corpse left on the site's turfs would fail
	// get_mind_mobs() and pin the map zone anyway. It ends in jumpToNullSpace(), which
	// frees the transit reservation and the port.
	//
	// But it moves those mobs to NULLSPACE rather than deleting them, and it does so
	// BEFORE jumpToNullSpace()'s per-turf empty() pass - so every mob aboard survives the
	// teardown in GLOB.mob_list/mob_living_list for the rest of the round. That is correct
	// for the round-end escape shuttle it was written for (those mobs are still players
	// being scored) and a straight leak here: 3-6 pirates or a dead crew per despawned
	// hull. Clear them out ourselves first. Nothing with a connected player behind it can
	// be here - the guard at the top of this proc already refused - so this is NPCs,
	// corpses, and the bodies of crew who logged off, which ARE the abandoned ship.
	if(shuttle)
		for(var/turf/hull_turf as anything in shuttle.return_turfs())
			if(!hull_turf)
				continue
			for(var/mob/living/aboard in hull_turf.get_all_contents())
				if(QDELETED(aboard))
					continue
				aboard.ghostize(FALSE) // a disconnected player's body still holds their key
				qdel(aboard)
		var/obj/docking_port/mobile/owned_shuttle = detach_shuttle()
		owned_shuttle.intoTheSunset()
	qdel(src)
	return TRUE

/// Planned hull removal must release both ownership links before the port's Destroy().
/// Otherwise its unexpected-deletion stack trace aborts callers inside try/catch,
/// leaving a hull-less overmap ship behind that continues to pin its landing site.
/obj/structure/overmap/ship/proc/detach_shuttle()
	var/obj/docking_port/mobile/voidcrew/owned_shuttle = shuttle
	shuttle = null
	if(owned_shuttle?.current_ship == src)
		owned_shuttle.current_ship = null
	return owned_shuttle

/**
 * The dynamic encounter this hull should be force-undocked from, or null if it should
 * stay where it is.
 *
 * Only called for hulls SSovermap's sweep has already found crewless, so "no active crew"
 * is a given here and is deliberately not re-tested - has_active_crew() walks the player
 * list and this hull's roster, and the sweep has just paid for it. Note that clears the
 * away-team case on its own: a hull berthed at a site its crew is exploring shares that
 * site's z, so the crew hold it and this never runs against them.
 *
 * Restricted to the encounters that mint an interior and cannot give it back while a hull
 * sits in their contents. Trader outposts, player outposts and the colosseum are permanent
 * fixtures with nothing to free, and a ship-to-ship dock is two crews' business rather
 * than a pinned site.
 */
/obj/structure/overmap/ship/proc/get_dead_site_undock_target()
	// Cheap checks first: this runs once a minute for every crewless hull in the fleet,
	// and the site-wide player scan below is the only part that costs anything.
	if(QDELETED(src) || !shuttle)
		return null
	// Anything other than IDLE is a hull in flight, mid-dock or already undocking.
	if(state != OVERMAP_SHIP_IDLE)
		return null
	var/obj/structure/overmap/site = docked
	if(!site || QDELETED(site))
		return null
	// Never while the site is busy with its own load or teardown - `concerned` is the
	// shared latch, the rest are per-family and each of the three declares its own.
	if(site.concerned)
		return null
	if(istype(site, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet_site = site
		if(planet_site.loading || planet_site.unloading)
			return null
	else if(istype(site, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin_site = site
		if(ruin_site.loading)
			return null
	else if(istype(site, /obj/structure/overmap/event/meteor))
		var/obj/structure/overmap/event/meteor/field_site = site
		if(field_site.loading)
			return null
	else
		return null // outpost, colosseum, another ship: nothing pinned, nothing to do

	// Two hulls sharing an empty-space encounter are berthed to a /planet/empty and pass
	// the gate above, so this has to be asked even though a ship is never `docked` to
	// another ship's type here. A rendezvous is the two crews' business, not ours.
	if(is_in_ship_to_ship_dock())
		return null

	// An NPC hull whose own crew is still alive keeps its "board it and finish the job"
	// window, however dead the hull is - the pirate pool frees its slot on a crew wipe or
	// on the key, never on a hull kill, and towing the wreck out of its crash site would
	// take the fight with it.
	var/obj/structure/overmap/ship/npc/npc_self = src
	if(istype(npc_self) && npc_self.count_live_crew_aboard())
		return null

	if(site_has_living_players(site))
		return null
	return site

/**
 * Whether anyone still counts as manning this hull, for the derelict clocks in
 * SSovermap.sweep_derelicts(). TRUE keeps both clocks rewound.
 *
 * Two ways to qualify, and both want a living, client-connected player:
 *
 * 1. Physically aboard - get_event_crew(), any player at all, roster or not. Someone
 *    standing in the engine room is someone the hull is not empty of, and a boarder
 *    who has taken up residence is a crew as far as the teardown is concerned.
 * 2. On this hull's roster and still at its docked site, including the concourse,
 *    elevator-connected hangars and other interior floors. Facilities with hangars
 *    span several z-levels, and visiting their interior must not abandon the ship.
 *    Outside hangar facilities, the hull's own z-level still counts for away teams.
 *
 * The roster scoping in 2 is load-bearing, not decoration. Ship z-levels are shared:
 * a flying hull sits on a transit level with every other hull in flight, and a berthed
 * one sits on an encounter level packed with up to three neighbouring sites. A bare
 * "is any player on this z" test reads the crew of the ship parked next door as ours
 * and no hull in a busy round would ever go derelict. ship_team.members is the only
 * list that says whose crew this is.
 *
 * Deliberately unchanged: crews that are dead, ghosted, cryoed out or logged off do
 * not count under either clause, which is the whole point of the sweep. Cryo takes the
 * mind off the roster on despawn (detach_from_crews()), so a pod full of logged-off
 * crew empties the hull exactly as it should.
 *
 * Not folded into get_event_crew(): that answers "who is inside this ship" for dynamic
 * events, which need mobs they can actually afflict, not a headcount of the away team.
 */
/obj/structure/overmap/ship/proc/has_active_crew()
	if(length(get_event_crew()))
		return TRUE
	if(!LAZYLEN(ship_team?.members))
		return FALSE
	// The hull's own z, not the overmap token's. get_turf() rather than shuttle.z so a
	// port mid-transit or with no loc reads as "no answer" instead of z 0, which would
	// match every mob that is also nowhere.
	var/turf/hull_turf = get_turf(shuttle)
	if(!hull_turf)
		return FALSE
	for(var/datum/mind/member as anything in ship_team.members)
		// `as anything` skips the istype filter, and a hard-deleted mind is nulled in
		// place in this list rather than removed from it.
		var/mob/living/body = member?.current
		if(QDELETED(body) || !isliving(body))
			continue
		// A ghosted player's mind still points at the body they left, so DEAD covers
		// the corpse and the client check covers everyone who logged off or aghosted.
		if(body.stat == DEAD || !GET_CLIENT(body))
			continue
		// get_turf() again: a player inside a locker, a mech or a bodybag reads z 0 off
		// the mob itself.
		var/turf/body_turf = get_turf(body)
		if(docked?.contains_site_turf(body_turf))
			return TRUE
		// Hangars from different facilities can occupy the same reservation level.
		// Their elevator host, not their z, determines whether the crew is still here.
		if(length(docked?.berths))
			continue
		if(body_turf?.z == hull_turf.z)
			return TRUE
	return FALSE

/**
 * Whether any living, connected player is standing anywhere inside `site`'s interior.
 *
 * Every site with an interior is scoped to a rectangle: a map footprint, one slot of up to
 * four on a shared z-level. A bare z match reads the neighbouring encounter's away team as
 * ours (the same reasoning as turf_footprint_has_players()). Only a site allocated outside
 * the slot register falls back to matching its map zone's whole level, which is what it
 * always did.
 *
 * GLOB.player_list is connected players only and runs a few dozen entries at most, so one
 * pass over it beats walking either interior. get_turf() rather than the mob's own z: a
 * player inside a locker, a mech or a bodybag reads z 0 off the mob.
 */
/obj/structure/overmap/ship/proc/site_has_living_players(obj/structure/overmap/site)
	var/list/site_z_values
	// Rectangle bounds, when the site is scoped to one. Every site with an interior now
	// answers with a map footprint (get_interior_footprint()) - a slot on a level it shares
	// with up to three neighbours, so the bare z match this used to do on some branches
	// reads a neighbour's crew as ours.
	var/min_x = 0
	var/min_y = 0
	var/max_x = 0
	var/max_y = 0
	var/bounded = FALSE
	var/datum/map_footprint/site_footprint = site?.get_interior_footprint()
	if(site_footprint && !isnull(site_footprint.low_x) && site_footprint.z_value)
		min_x = site_footprint.low_x
		min_y = site_footprint.low_y
		max_x = site_footprint.high_x
		max_y = site_footprint.high_y
		site_z_values = list(site_footprint.z_value)
		bounded = TRUE
	else if(istype(site, /obj/structure/overmap/planet))
		// A site with a map zone but no footprint: allocated outside the slot register, so
		// the whole level is the answer, exactly as it was before packing.
		var/obj/structure/overmap/planet/planet_site = site
		if(planet_site.mapzone)
			site_z_values = list()
			for(var/datum/space_level/zlevel as anything in planet_site.mapzone.z_levels)
				site_z_values += zlevel.z_value

	// No interior to stand in. A hull berthed at a site that has nothing loaded is exactly
	// the stranded case this exists for, so read it as empty rather than as blocking.
	if(!length(site_z_values))
		return FALSE

	for(var/mob/player as anything in GLOB.player_list)
		if(!isliving(player))
			continue
		var/mob/living/living_player = player
		if(living_player.stat == DEAD)
			continue
		var/turf/player_turf = get_turf(living_player)
		if(!player_turf)
			continue
		if(!(player_turf.z in site_z_values))
			continue
		if(bounded && (player_turf.x < min_x || player_turf.x > max_x || player_turf.y < min_y || player_turf.y > max_y))
			continue
		return TRUE
	return FALSE

/**
 * Runs the SHIP_SITE_DEAD_UNDOCK_TIME clock and force-undocks when it runs out.
 *
 * Called once a minute from SSovermap.sweep_derelicts(), for crewless hulls only. Returns
 * TRUE only when an undock was actually started.
 *
 * The undock goes through the ordinary undock() - warmup, state machine, and on completion
 * the same COMSIG_VOIDCREW_SHIP_UNDOCKED that releases the site when a crew leaves under
 * its own power. Nothing here is special-cased past the trigger.
 */
/obj/structure/overmap/ship/proc/check_dead_site_undock()
	var/obj/structure/overmap/site = get_dead_site_undock_target()
	if(!site)
		site_dead_since = 0
		site_dead_undock_refused = FALSE
		return FALSE
	if(!site_dead_since)
		site_dead_since = world.time
		return FALSE
	if(world.time - site_dead_since < SHIP_SITE_DEAD_UNDOCK_TIME)
		return FALSE

	var/refusal = undock()
	if(refusal)
		// Every refusal undock() can give here either expires on its own (the post-dock
		// stabilization cooldown, an interdiction lockout, the structural recertification
		// a failed hull is held for) or needs a crew that isn't here (a hull built out past
		// its docking port with no door to reseat to). Keep the stamp and try again next
		// sweep; say why once per streak rather than once a minute for as long as it runs.
		if(!site_dead_undock_refused)
			site_dead_undock_refused = TRUE
			log_shuttle("[name]: force-undock from [site] refused - [refusal] Retrying each sweep.")
		return FALSE

	log_shuttle("[name]: force-undocking from [site] - no living crew at the site for [(world.time - site_dead_since) / 600] minutes.")
	site_dead_since = 0
	site_dead_undock_refused = FALSE
	return TRUE
