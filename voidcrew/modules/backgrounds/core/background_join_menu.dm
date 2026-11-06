/// Backgrounds: owned by P1. See data/backgrounds/spec.md.

/// The join menu's "Other starts" entries for this player
/datum/ship_join_menu/proc/background_starts_data(mob/dead/new_player/user)
	return list()

/// Handles a background join menu action. TRUE when handled.
/datum/ship_join_menu/proc/background_join_act(action, list/params)
	return FALSE
