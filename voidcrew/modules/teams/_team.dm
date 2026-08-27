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
	// on_removal() + qdel() is the pair remove_antag_datum() runs, and both halves matter:
	// on_removal() alone takes the datum off the mind but leaves it alive, and the FRND
	// marker only dies in /datum/antagonist/Destroy() (QDEL_NULL(team_hud_ref)). Without
	// the qdel a kicked crewman stays green to the crew forever and his orphaned HUD sits
	// in GLOB.has_antagonist_huds getting re-offered to everyone who joins after him.
	for(var/datum/antagonist/crew/crew_antag in member.antag_datums)
		if(crew_antag.crew_team == src)
			crew_antag.on_removal()
			qdel(crew_antag)
			break

/datum/team/voidcrew/Destroy(force, ...)
	for(var/datum/mind/team_minds as anything in members)
		to_chat(team_minds, span_notice("Your faction has been disbanded! You are now alone!"))
	// Every membership leaves two back-references to this team behind: the mind's
	// ship_teams entry and its crew antag datum's crew_team var. /datum/team/Destroy()
	// only drops `members`, so a disbanded team with anyone still on the roster stayed
	// pinned by both and hard-deleted (create_and_destroy, 2026-08-25). remove_member()
	// is the one place that unwinds both, so disbanding runs it over the whole roster.
	// Copy first - remove_member() mutates `members` through /datum/team/remove_member().
	for(var/datum/mind/leaving as anything in members?.Copy())
		remove_member(leaving)
	return ..()

///Checks the team's members to see if anyone with a client is alive. returns TRUE if active.
// is_active_team() lived here: a same-z liveness check over the roster, called from
// exactly one place - the death-triggered ten-minute abandonment timer on
// /obj/structure/overmap/ship, now retired. Its job belongs to
// /obj/structure/overmap/ship/proc/has_active_crew(), which asks the same question
// without dereferencing a null mind.current and reads mobs through get_turf() so a
// crewman in a locker or a mech does not answer z 0.



