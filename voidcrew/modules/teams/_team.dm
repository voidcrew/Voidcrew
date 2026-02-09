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

	// Remove this team from the member's list
	LAZYREMOVE(member.ship_teams, src)

	// Find and remove the specific crew antagonist for this team
	for(var/datum/antagonist/crew/crew_antag in member.antag_datums)
		if(crew_antag.crew_team == src)
			member.remove_antag_datum(crew_antag)
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



