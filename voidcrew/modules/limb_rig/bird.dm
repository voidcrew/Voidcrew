/**
 * Flipping the bird.
 *
 * *bird makes a fist with the active hand and raises the middle finger. *crankbird raises the
 * fist first, then the other hand cranks an invisible lever while the middle finger slowly
 * unfurls. The fist-and-finger is on the hand sprite itself, so any carbon with fingers does
 * it. Hands without the Fingers quirk sprout just the middle finger for the occasion. An
 * Overanimated body also acts it out with its arms (see /datum/limb_rig/proc/play_bird()).
 */
/datum/emote/living/carbon/bird
	key = "bird"
	key_third_person = "birds"
	message = "flips the bird."
	hands_use_check = TRUE
	cooldown = 3 SECONDS
	/// How long the hand stays a fist with the finger up, matching the rig's animation.
	var/hold_time = 1.7 SECONDS

/datum/emote/living/carbon/bird/run_emote(mob/user, params, type_override, intentional)
	. = ..()
	var/mob/living/carbon/carbon_user = user
	if(!istype(carbon_user))
		return
	var/obj/item/bodypart/arm/hand = carbon_user.get_active_hand()
	if(!istype(hand))
		return
	hand.set_fingers_bird(TRUE)
	addtimer(CALLBACK(hand, TYPE_PROC_REF(/obj/item/bodypart/arm, set_fingers_bird), FALSE), hold_time, TIMER_UNIQUE|TIMER_OVERRIDE)

/datum/emote/living/carbon/bird/crank
	key = "crankbird"
	key_third_person = "crankbirds"
	message = "cranks out a slow middle finger."
	cooldown = 6 SECONDS
	hold_time = 3.5 SECONDS
