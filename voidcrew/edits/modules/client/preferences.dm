// Voidcrew extensions to code/modules/client/preferences.dm.

/**
 * Returns the character preview, rebuilding it if it went missing.
 *
 * Callers reach this from inside get_payload(), where a runtime costs the whole half of
 * the payload it is building. See create_character_preview_view() for how the view gets
 * destroyed mid-flight.
 */
/datum/preferences/proc/get_character_preview_view(mob/user)
	if(isnull(character_preview_view))
		create_character_preview_view(user)
	return character_preview_view
