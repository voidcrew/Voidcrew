/datum/antagonist/crew
	name = "\improper Ship Crewmember"
	hud_icon = 'voidcrew/icons/mob/huds/faction_hud.dmi'
	antag_hud_name = "FRND"
	show_in_roundend = FALSE
	show_in_antagpanel = FALSE
	silent = TRUE
	ui_name = null // No objectives button for regular crew
	/// The specific ship team this antagonist datum is for (supports multi-crew)
	var/datum/team/voidcrew/crew_team

/datum/antagonist/crew/get_team()
	return crew_team

/datum/antagonist/crew/apply_innate_effects(mob/living/mob_override)
	add_team_hud(mob_override || owner.current)

