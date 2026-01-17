// Intent system preferences
// Toggle to enable classic SS13 intents instead of combat mode toggle

/// Player preference to use classic intent system instead of combat mode toggle
/datum/preference/toggle/use_intents
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "use_intent_system"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/datum/preference/toggle/use_intents/apply_to_client(client/user, value)
	// Apply immediately if the client has a human mob
	var/mob/living/carbon/human/H = user?.mob
	if(!istype(H))
		return
	if(value)
		H.enable_intent_system()
	else
		H.disable_intent_system()
