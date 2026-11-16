/// Opens the tutorial checklist by itself after every spawn. Progress is tracked
/// either way; this only controls the automatic window (tutorial_panel.dm).
/datum/preference/toggle/tutorial_checklist
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tutorial_checklist"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = TRUE

/// Outlines the objects the open tutorial item points at (tutorial_highlights.dm).
/datum/preference/toggle/tutorial_highlights
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "tutorial_highlights"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = TRUE
