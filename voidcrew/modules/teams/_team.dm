/datum/mind
	/// Hull HUD rosters. All actual enrollment belongs to one continuing crew.
	var/list/ship_teams
	var/datum/voidcrew_crew_record/reputation_crew
	/// Explicit hull context when several ships share this crew (selected by service UIs).
	var/datum/weakref/crew_service_ship_ref

/// Current affiliation only. Historical password clearance never grants services.
/datum/mind/proc/get_reputation_crew()
	if(QDELETED(reputation_crew))
		return null
	var/player_ckey = ckey(key)
	if(player_ckey && GLOB.voidcrew_crew_roster[player_ckey] != reputation_crew)
		return null
	return reputation_crew

/// For commissioning/respawn only: recover the round roster without enlisting or mutating it.
/datum/mind/proc/recover_reputation_crew()
	var/player_ckey = ckey(key)
	return get_reputation_crew() || (player_ckey ? GLOB.voidcrew_crew_roster[player_ckey] : null)

/// The only affiliation switch. A new life evicts the old keyed mind, even in the same crew.
/// No balances move; same-crew hull memberships survive. Call before adding the hull HUD.
/datum/mind/proc/join_reputation_crew(datum/voidcrew_crew_record/record)
	if(QDELETED(record))
		return FALSE
	var/player_ckey = ckey(key)
	var/datum/voidcrew_crew_record/previous = reputation_crew
	var/datum/voidcrew_crew_record/rostered = player_ckey ? GLOB.voidcrew_crew_roster[player_ckey] : null
	if(player_ckey && rostered)
		for(var/datum/mind/old_life in rostered.minds.Copy())
			if(old_life != src && ckey(old_life.key) == player_ckey)
				old_life.leave_reputation_crew()
	for(var/datum/team/voidcrew/team in ship_teams?.Copy())
		if(team.crew_record != record)
			team.remove_member(src)
	previous?.minds.Remove(src)
	if(player_ckey)
		previous?.ckeys.Remove(player_ckey)
		rostered?.ckeys.Remove(player_ckey)
		GLOB.voidcrew_crew_roster[player_ckey] = record
		record.ckeys |= player_ckey
	reputation_crew = record
	record.minds |= src
	crew_service_ship_ref = null
	return TRUE

/// Explicit departure/kick. Cryo, abandonment and hull deletion only remove HUD teams.
/datum/mind/proc/leave_reputation_crew()
	var/datum/voidcrew_crew_record/previous = reputation_crew
	for(var/datum/team/voidcrew/team in ship_teams?.Copy())
		team.remove_member(src)
	var/player_ckey = ckey(key)
	if(previous)
		previous.minds -= src
		previous.ckeys -= player_ckey
	if(player_ckey && GLOB.voidcrew_crew_roster[player_ckey] == previous)
		GLOB.voidcrew_crew_roster -= player_ckey
	reputation_crew = null
	crew_service_ship_ref = null

/datum/mind/Destroy()
	// Keep the ckey roster for a replacement mind, but release all world references.
	for(var/datum/team/voidcrew/team in ship_teams?.Copy())
		team.remove_member(src)
	reputation_crew?.minds.Remove(src)
	ship_teams = null
	reputation_crew = null
	crew_service_ship_ref = null
	return ..()

/datum/team/voidcrew
	show_roundend_report = TRUE
	var/obj/structure/overmap/ship/ship
	var/datum/voidcrew_crew_record/crew_record

/datum/team/voidcrew/proc/ensure_crew_record()
	if(QDELETED(crew_record))
		if(length(members))
			return null
		set_crew_record(new /datum/voidcrew_crew_record())
	return crew_record

/// Only an empty hull may change identity. Occupied hulls never merge crews.
/datum/team/voidcrew/proc/set_crew_record(datum/voidcrew_crew_record/record)
	if(length(members) || QDELETED(record))
		return FALSE
	var/datum/voidcrew_crew_record/previous = crew_record
	previous?.teams.Remove(src)
	crew_record = record
	record.teams |= src
	// setup_from_template makes a provisional empty record. Rebinding must not
	// leave thousands of unused placeholders in the round registry.
	if(previous && previous != record && previous.is_unfounded())
		qdel(previous)
	return TRUE

/// All job, invitation, admin and claim routes enter here.
/datum/team/voidcrew/proc/join_member(datum/mind/new_member)
	if(!new_member?.join_reputation_crew(ensure_crew_record()))
		return FALSE
	add_member(new_member)
	return new_member in members

/datum/team/voidcrew/add_member(datum/mind/new_member)
	if(!new_member)
		return
	var/datum/voidcrew_crew_record/record = ensure_crew_record()
	// Low-level HUD enrollment cannot switch an already affiliated player.
	var/datum/voidcrew_crew_record/existing = new_member.recover_reputation_crew()
	if(existing && existing != record)
		return
	if(!new_member.get_reputation_crew())
		new_member.join_reputation_crew(record)
	if(new_member.get_reputation_crew() != record)
		return
	// Check if already a member of this team (use LAZYFIND for null-safety)
	if(LAZYFIND(new_member.ship_teams, src))
		return

	. = ..()

	// Initialize list if needed and add this team
	LAZYADD(new_member.ship_teams, src)

	// Add crew antagonist datum linked to this specific team
	var/datum/antagonist/crew/crew_antag = new()
	crew_antag.crew_team = src
	new_member.add_antag_datum(crew_antag)
	ship_metric_crew_changed(src, new_member, joined = TRUE)

/datum/team/voidcrew/remove_member(datum/mind/member)
	if(!member)
		return
	. = ..()
	if(member.current)
		ship?.manifest.Remove(member.current.real_name)

	// Off the roster is off the bridge - retire any Ship Management button they held for us
	if(ship && member.current)
		remove_captain_management(member.current, ship)

	// Acting command dies with crew membership
	if(ship?.acting_captain == member)
		ship.acting_captain = null

	// So does held command. is_ship_captain() treats a set claimed_captain as
	// exclusive, so a captain who is kicked or cryos out has to release it or the
	// hull is left with a captain nobody can reach and nobody able to replace them.
	if(ship?.claimed_captain == member)
		ship.claimed_captain = null

	// Whoever holds command now, holds the button. Unconditional rather than folded
	// into the branch above because the cryopod clears claimed_captain itself before
	// calling this, and because releasing an exclusive claim promotes the hull's
	// officer back into command - they need their Ship Management button back, and
	// nothing else would ever give it to them.
	ship?.refresh_command_buttons()
	ship_metric_crew_changed(src, member, joined = FALSE)

	// Remove this team from the member's list
	LAZYREMOVE(member.ship_teams, src)

	// Find and remove the specific crew antagonist for this team.
	// Not remove_antag_datum(): that resolves BY TYPE via has_antag_datum(), so on a
	// multi-crew mind it removed whichever ship's crew datum happened to sit first in
	// antag_datums - stranding this team's datum in the list forever.
	for(var/datum/antagonist/crew/crew_antag in member.antag_datums)
		if(crew_antag.crew_team == src)
			crew_antag.on_removal()
			break

/datum/team/voidcrew/Destroy(force, ...)
	for(var/datum/mind/team_minds in members.Copy())
		remove_member(team_minds)
	crew_record?.teams.Remove(src)
	crew_record = null
	ship = null
	return ..()

///Checks the team's members to see if anyone with a client is alive. returns TRUE if active.
// is_active_team() lived here: a same-z liveness check over the roster, called from
// exactly one place - the death-triggered ten-minute abandonment timer on
// /obj/structure/overmap/ship, now retired. Its job belongs to
// /obj/structure/overmap/ship/proc/has_active_crew(), which asks the same question
// without dereferencing a null mind.current and reads mobs through get_turf() so a
// crewman in a locker or a mech does not answer z 0.
