/datum/mind
	/// List of ship teams this mind belongs to (supports multiple crews)
	var/list/ship_teams

/datum/team/voidcrew
	show_roundend_report = TRUE
	var/obj/structure/overmap/ship/ship

/datum/team/voidcrew/add_member(datum/mind/new_member)
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

/datum/team/voidcrew/remove_member(datum/mind/member)
	. = ..()

	// Off the roster is off the bridge - retire any Ship Management button they held for us
	if(ship && member.current)
		remove_captain_management(member.current, ship)

	// Acting command dies with crew membership
	if(ship?.acting_captain == member)
		ship.acting_captain = null

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
	for(var/datum/mind/team_minds as anything in members)
		to_chat(team_minds, span_notice("Your faction has been disbanded! You are now alone!"))
	return ..()

///Checks the team's members to see if anyone with a client is alive. returns TRUE if active.
/datum/team/voidcrew/proc/is_active_team(obj/structure/overmap/ship/owner_ship)
	for(var/datum/mind/team_minds as anything in members)
		if(owner_ship.shuttle.z != team_minds.current.z) // different z, they don't matter anymore
			continue
		if(!team_minds.current.client)
			continue
		if(team_minds.current.stat <= HARD_CRIT)
			return TRUE
	return FALSE



