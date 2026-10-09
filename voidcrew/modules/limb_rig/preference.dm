/// Whether a player's own character is drawn on the generated, animated body, off unless they turn it
/// on. Species that only look right rigged (Experiments, Milkies) are rigged either way, as is anyone
/// with the Overanimated quirk; bodies nobody plays (rhythm battle opponents, the gags' extras) are too.
/datum/preference/toggle/limb_rig
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "limb_rig"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE

/datum/preference/toggle/limb_rig/apply_to_client(client/client, value)
	var/mob/living/carbon/human/body = client?.mob
	if(istype(body))
		body.set_limb_rig_wanted(value)

/mob/living/carbon/human
	/// Whether whoever plays this body wants it rigged (see /datum/preference/toggle/limb_rig), and so
	/// whether it is until someone does. Kept after they leave it.
	var/limb_rig_wanted = TRUE

/mob/living/carbon/human/Login()
	. = ..()
	if(. && client?.prefs)
		set_limb_rig_wanted(client.prefs.read_preference(/datum/preference/toggle/limb_rig))

/mob/living/carbon/human/proc/set_limb_rig_wanted(wanted)
	if(limb_rig_wanted == wanted)
		return
	limb_rig_wanted = wanted
	update_limb_rig()
