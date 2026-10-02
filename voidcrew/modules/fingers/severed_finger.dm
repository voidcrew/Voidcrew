/// How many times a fresh finger twitches before it gives up.
#define SEVERED_FINGER_TWITCHES 6

/**
 * A finger that is no longer attached to anything.
 *
 * It is meat, so it can be eaten, grilled or used as bait. It twitches for a little while
 * after coming off. It can be pressed back onto a hand that is missing the same finger,
 * on a person or on a loose arm, and then needs suturing in (attaching.dm).
 */
/obj/item/food/finger
	name = "severed finger"
	desc = "A severed finger. It's a bit hairy around the knuckle."
	icon = 'voidcrew/modules/fingers/icons/fingers.dmi'
	icon_state = "finger"
	color = "#ffd9c4"
	w_class = WEIGHT_CLASS_TINY
	bite_consumption = 2
	food_reagents = list(/datum/reagent/consumable/nutriment/protein = 1)
	tastes = list("meat" = 1, "regret" = 1)
	foodtypes = MEAT | RAW | GORE
	eatverbs = list("gnaw", "nibble", "crunch")
	/// Which finger this was, from GLOB.hand_fingers. Decides which gap it fits back into.
	var/finger_name = "index finger"
	/// "left" or "right"
	var/hand_side = "right"
	/// Twitches left before it goes still.
	var/twitches_left = 0

/obj/item/food/finger/Initialize(mapload)
	. = ..()
	appearance_flags |= PIXEL_SCALE // It twitches by rotating, and blurs without this.
	update_appearance(UPDATE_OVERLAYS)

/obj/item/food/finger/update_overlays()
	. = ..()
	// The nail, the knuckle hair and the bloody end stay their own colour whatever the skin is.
	var/mutable_appearance/detail = mutable_appearance(icon, "finger_detail", appearance_flags = RESET_COLOR)
	. += detail

/// Makes this finger look like it came off the given hand.
/obj/item/food/finger/proc/take_appearance_from(obj/item/bodypart/arm/hand, finger_name)
	src.finger_name = finger_name
	hand_side = hand.get_hand_side()
	name = "severed [hand_side] [finger_name]"
	desc = "A [finger_name] from someone's [hand_side] [hand.appendage_noun]. It's a bit hairy around the knuckle."
	if(hand.draw_color)
		color = hand.draw_color
	else if(hand.species_color)
		color = hand.species_color
	twitches_left = SEVERED_FINGER_TWITCHES
	addtimer(CALLBACK(src, PROC_REF(twitch)), rand(2 SECONDS, 5 SECONDS))

/// A fresh finger keeps moving for a bit.
/obj/item/food/finger/proc/twitch()
	if(twitches_left <= 0)
		return
	twitches_left--
	if(isturf(loc))
		var/angle = pick(-25, -15, 15, 25)
		animate(src, transform = turn(matrix(), angle), time = 0.2 SECONDS)
		animate(transform = matrix(), time = 0.3 SECONDS)
		if(prob(40))
			visible_message(span_notice("[src] twitches."), vision_distance = 3)
	if(twitches_left > 0)
		addtimer(CALLBACK(src, PROC_REF(twitch)), rand(3 SECONDS, 8 SECONDS))

/obj/item/food/finger/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	user.visible_message(
		span_notice("[user] waggles [src] around."),
		span_notice("You waggle [src] around. It's worse than you'd think."),
	)
	animate(src, transform = turn(matrix(), 20), time = 0.1 SECONDS, loop = 2)
	animate(transform = turn(matrix(), -20), time = 0.1 SECONDS)
	animate(transform = matrix(), time = 0.1 SECONDS)
	return TRUE

/obj/item/food/finger/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/obj/item/bodypart/arm/hand = get_finger_target_hand(interacting_with, user)
	if(!hand)
		return NONE // Aimed anywhere but an arm, it's food like any other.
	if(!can_press_finger_on(user, hand))
		return ITEM_INTERACT_BLOCKING
	if(!(finger_name in hand.missing_fingers))
		to_chat(user, span_warning("That [hand.appendage_noun] already has a [finger_name]."))
		return ITEM_INTERACT_BLOCKING
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(press_finger_on), user, src, hand, finger_name, FALSE)
	return ITEM_INTERACT_SUCCESS

#undef SEVERED_FINGER_TWITCHES
