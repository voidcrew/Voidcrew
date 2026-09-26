/**
 * Putting fingers back on.
 *
 * A severed finger goes back into its own gap; a printed prosthetic fits any gap. Either
 * is pressed onto the hand (aim at the arm or the hand) and sits loose until someone runs a
 * suture through it. A loose finger works like any other, but when that arm gets hurt it
 * can pop right off again.
 */

/// How long it takes to press a finger onto someone else's hand.
#define FINGER_PRESS_TIME (3 SECONDS)
/// How long it takes to press a finger onto your own hand, one-handed.
#define FINGER_PRESS_TIME_SELF (5 SECONDS)
/// How long it takes to suture a loose finger on someone else.
#define FINGER_SUTURE_TIME (4 SECONDS)
/// How long it takes to suture one of your own loose fingers.
#define FINGER_SUTURE_TIME_SELF (6 SECONDS)
/// Hits on the arm weaker than this never shake a loose finger off.
#define FINGER_LOOSE_MIN_DAMAGE 5
/// Chance per point of damage that a hit on the arm knocks each loose finger off.
#define FINGER_LOOSE_CHANCE_PER_DAMAGE 4
/// The most likely a single hit is to knock off a loose finger.
#define FINGER_LOOSE_MAX_CHANCE 60

/// Puts a finger into an empty gap, loose. Returns TRUE if the gap was empty.
/obj/item/bodypart/arm/proc/attach_loose_finger(finger_name, prosthetic = FALSE)
	if(!can_have_fingers() || !(finger_name in missing_fingers))
		return FALSE
	LAZYREMOVE(missing_fingers, finger_name)
	LAZYOR(loose_fingers, finger_name)
	if(prosthetic)
		LAZYOR(prosthetic_fingers, finger_name)
	else
		LAZYREMOVE(prosthetic_fingers, finger_name)
	on_fingers_changed()
	return TRUE

/// Stitches a loose finger in for good. Returns TRUE if it was loose.
/obj/item/bodypart/arm/proc/secure_finger(finger_name)
	if(!(finger_name in loose_fingers))
		return FALSE
	LAZYREMOVE(loose_fingers, finger_name)
	return TRUE

/**
 * Works out which hand a finger is being put on from what was clicked.
 *
 * A loose arm is used directly. On a carbon, the user has to be aiming at an arm or a hand.
 * Returns null otherwise, so food fingers can still be fed to people.
 */
/proc/get_finger_target_hand(atom/target, mob/living/user)
	if(istype(target, /obj/item/bodypart/arm))
		return target
	if(!iscarbon(target))
		return null
	var/static/list/hand_zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND)
	if(!(user.zone_selected in hand_zones))
		return null
	var/mob/living/carbon/patient = target
	var/obj/item/bodypart/arm/hand = patient.get_bodypart(check_zone(user.zone_selected))
	return istype(hand) ? hand : null

/// Checks that a finger can go on a hand at all right now, and tells the user why not.
/proc/can_press_finger_on(mob/living/user, obj/item/bodypart/arm/hand)
	if(!hand.can_have_fingers())
		to_chat(user, span_warning("A finger won't take on \a [hand.plaintext_zone] like that."))
		return FALSE
	if(!LAZYLEN(hand.missing_fingers))
		to_chat(user, span_warning("That [hand.appendage_noun] isn't missing any fingers."))
		return FALSE
	var/mob/living/carbon/patient = hand.owner
	if(patient?.get_hand_covering())
		to_chat(user, span_warning("Get [patient == user ? "your" : "[patient.p_their()]"] hand uncovered first."))
		return FALSE
	return TRUE

/**
 * Presses a finger onto a hand. The finger item is used up, and the finger is loose.
 *
 * * user - who is pressing it on
 * * finger_item - the severed or printed finger, deleted on success
 * * hand - the hand getting it
 * * finger_name - which gap it goes in
 * * prosthetic - whether it's a printed one
 */
/proc/press_finger_on(mob/living/user, obj/item/finger_item, obj/item/bodypart/arm/hand, finger_name, prosthetic)
	var/mob/living/carbon/patient = hand.owner
	var/self = (user == patient)
	var/whose = self ? "your" : (patient ? "[patient]'s" : "the")
	user.visible_message(
		span_notice("[user] starts pressing [finger_item] onto [self ? user.p_their() : whose] [hand.plaintext_zone]..."),
		span_notice("You start pressing [finger_item] onto [whose] [hand.plaintext_zone]..."),
	)
	if(!do_after(user, self ? FINGER_PRESS_TIME_SELF : FINGER_PRESS_TIME, patient || hand))
		return FALSE
	if(QDELETED(finger_item) || QDELETED(hand) || hand.owner != patient)
		return FALSE
	if(!hand.attach_loose_finger(finger_name, prosthetic))
		to_chat(user, span_warning("Something already filled that gap."))
		return FALSE
	user.visible_message(
		span_notice("[user] presses [finger_item] onto [self ? user.p_their() : whose] [hand.plaintext_zone]. It wobbles."),
		span_notice("You press [finger_item] on as the [finger_name]. It wobbles. It needs stitching before it'll stay put."),
	)
	qdel(finger_item)
	return TRUE

/// Clicking an arm or hand with loose fingers using a suture stitches one of them in.
/mob/living/carbon/proc/try_suture_finger(mob/living/carbon/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(tool, /obj/item/stack/medical/suture))
		return NONE
	var/obj/item/bodypart/arm/hand = get_finger_target_hand(src, user)
	if(!hand || !LAZYLEN(hand.loose_fingers))
		return NONE // Nothing to stitch in, so it's ordinary suturing.
	INVOKE_ASYNC(src, PROC_REF(suture_finger), user, tool, hand)
	return ITEM_INTERACT_SUCCESS

/mob/living/carbon/proc/suture_finger(mob/living/user, obj/item/stack/medical/suture/suture, obj/item/bodypart/arm/hand)
	var/finger_name = hand.loose_fingers[1]
	var/self = (user == src)
	user.visible_message(
		span_notice("[user] starts stitching [self ? user.p_their() : "[src]'s"] loose [finger_name] in place..."),
		span_notice("You start stitching [self ? "your" : "[src]'s"] loose [finger_name] in place..."),
	)
	if(!do_after(user, self ? FINGER_SUTURE_TIME_SELF : FINGER_SUTURE_TIME, src))
		return
	if(QDELETED(suture) || hand.owner != src || !(finger_name in hand.loose_fingers))
		return
	if(!suture.use(1))
		return
	hand.secure_finger(finger_name)
	user.visible_message(
		span_notice("[user] stitches [self ? user.p_their() : "[src]'s"] [finger_name] in place."),
		span_notice("You stitch [self ? "your" : "[src]'s"] [finger_name] in place. It's staying put now."),
	)

/// A hit on an arm can knock its loose fingers off.
/mob/living/carbon/proc/shake_loose_fingers(mob/living/carbon/source, obj/item/bodypart/limb, brute, burn)
	SIGNAL_HANDLER
	var/obj/item/bodypart/arm/hand = limb
	if(!istype(hand) || !LAZYLEN(hand.loose_fingers))
		return NONE
	var/damage = brute + burn
	if(damage < FINGER_LOOSE_MIN_DAMAGE)
		return NONE
	var/chance = min(damage * FINGER_LOOSE_CHANCE_PER_DAMAGE, FINGER_LOOSE_MAX_CHANCE)
	for(var/finger_name in hand.loose_fingers.Copy())
		if(!prob(chance) || !hand.lose_finger(finger_name))
			continue
		visible_message(
			span_danger("[src]'s loose [finger_name] pops right off!"),
			span_userdanger("Your loose [finger_name] pops right off!"),
		)
	return NONE

#undef FINGER_PRESS_TIME
#undef FINGER_PRESS_TIME_SELF
#undef FINGER_SUTURE_TIME
#undef FINGER_SUTURE_TIME_SELF
#undef FINGER_LOOSE_MIN_DAMAGE
#undef FINGER_LOOSE_CHANCE_PER_DAMAGE
#undef FINGER_LOOSE_MAX_CHANCE
