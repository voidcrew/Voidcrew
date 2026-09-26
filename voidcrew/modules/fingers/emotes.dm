/// Wiggle your fingers. How it reads depends on how many you have left.
/datum/emote/living/carbon/wiggle
	key = "wiggle"
	key_third_person = "wiggles"
	message = "wiggles their fingers."
	hands_use_check = TRUE
	cooldown = 3 SECONDS

/datum/emote/living/carbon/wiggle/select_message_type(mob/user, msg, intentional)
	. = ..()
	var/mob/living/carbon/carbon_user = user
	if(!istype(carbon_user))
		return
	var/fingers = 0
	for(var/obj/item/bodypart/arm/hand in carbon_user.bodyparts)
		fingers += hand.get_finger_count()
	if(fingers <= 0)
		return "waves their fingerless stumps around."
	if(fingers == 1)
		return "wiggles their one remaining finger."
	if(fingers < 10)
		return "wiggles their [fingers] remaining fingers."

/datum/emote/living/carbon/wiggle/run_emote(mob/user, params, type_override, intentional)
	. = ..()
	var/mob/living/carbon/carbon_user = user
	if(istype(carbon_user))
		carbon_user.wiggle_fingers()

/// Snapping takes a thumb and a middle finger on the same hand.
/datum/emote/living/carbon/snap/can_run_emote(mob/user, status_check = TRUE, intentional = FALSE, params)
	. = ..()
	if(!. || !iscarbon(user))
		return
	var/mob/living/carbon/carbon_user = user
	for(var/obj/item/bodypart/arm/hand in carbon_user.bodyparts)
		if(hand.has_finger("thumb") && hand.has_finger("middle finger"))
			return TRUE
	if(intentional)
		to_chat(user, span_warning("You need a thumb and a middle finger on the same hand to snap."))
	return FALSE
