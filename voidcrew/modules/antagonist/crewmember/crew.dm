/datum/antagonist/crew
	name = "\improper Ship Crewmember"
	hud_icon = 'voidcrew/icons/mob/huds/faction_hud.dmi'
	antag_hud_name = "FRND"
	show_in_roundend = FALSE
	show_in_antagpanel = FALSE
	silent = TRUE
	/// This is a faction/HUD marker handed to every member of a ship team, not a real antag role.
	/// Without these flags every crewmember counts as an antagonist to is_antag() and the global antag lists.
	antag_flags = ANTAG_FAKE|ANTAG_SKIP_GLOBAL_LIST
	ui_name = null // No objectives button for regular crew
	/// The specific ship team this antagonist datum is for (supports multi-crew)
	var/datum/team/voidcrew/crew_team

/datum/antagonist/crew/get_team()
	return crew_team

/datum/antagonist/crew/Destroy()
	// Leaked crew datums otherwise pin their team: /datum/antagonist/Destroy knows
	// nothing about this var
	crew_team = null
	return ..()

/datum/antagonist/crew/apply_innate_effects(mob/living/mob_override)
	var/mob/living/crew_mob = mob_override || owner.current
	add_team_hud(crew_mob)
	// override: a re-apply on the same body (mind transfer bookkeeping) must not runtime
	RegisterSignal(crew_mob, COMSIG_ATOM_EXAMINE, PROC_REF(on_examined), override = TRUE)

/datum/antagonist/crew/remove_innate_effects(mob/living/mob_override)
	UnregisterSignal(mob_override || owner.current, COMSIG_ATOM_EXAMINE)
	return ..()

/// The green box the team HUD draws over crewmates has no explanation anywhere
/// in game - players repeatedly asked what it was. Spell it out on examine, only
/// to the people who can actually see the marker (fellow team members).
/datum/antagonist/crew/proc/on_examined(mob/living/source, mob/examiner, list/examine_list)
	SIGNAL_HANDLER
	if(examiner == source || !examiner?.mind || !crew_team)
		return
	if(!(examiner.mind in crew_team.members))
		return
	examine_list += span_notice("The green marker over [source.p_them()] means [source.p_they()] [source.p_are()] part of your ship's crew.")


/// The same marker, but each crewmember can turn it off for themselves (see toggle_crew_markers()).
/datum/antagonist/crew/add_team_hud(mob/target, antag_to_check)
	QDEL_NULL(team_hud_ref)
	team_hud_ref = WEAKREF(target.add_alt_appearance(
		/datum/atom_hud/alternate_appearance/basic/has_antagonist/crew,
		"antag_team_hud_[REF(src)]",
		hud_image_on(target),
		antag_to_check || type,
		get_team() && WEAKREF(get_team()),
	))
	for(var/datum/atom_hud/alternate_appearance/basic/has_antagonist/antag_hud as anything in GLOB.has_antagonist_huds)
		antag_hud.apply_to_new_mob(owner.current)

/datum/atom_hud/alternate_appearance/basic/has_antagonist/crew

/datum/atom_hud/alternate_appearance/basic/has_antagonist/crew/mobShouldSee(mob/viewer)
	return !viewer.mind?.crew_markers_hidden && ..()

/datum/mind
	/// Whether this one's turned off the green markers over their crewmates.
	var/crew_markers_hidden = FALSE

/mob/living/verb/toggle_crew_markers()
	set name = "Toggle Crew Markers"
	set category = "IC"
	set desc = "Show or hide the green marker over your crewmates."
	if(!mind)
		return
	mind.crew_markers_hidden = !mind.crew_markers_hidden
	for(var/datum/atom_hud/alternate_appearance/basic/has_antagonist/crew/marker in GLOB.has_antagonist_huds)
		if(mind.crew_markers_hidden)
			marker.hide_from(src, absolute = TRUE)
		else
			marker.apply_to_new_mob(src)
	to_chat(src, span_notice("Crew markers [mind.crew_markers_hidden ? "hidden" : "shown"]."))
