/**
 * A printed finger. Fits any gap on a flesh hand; press it on while aiming at the arm or
 * hand, then suture it in. Printable at the autolathe, protolathe and exosuit fabricator.
 */
/obj/item/prosthetic_finger
	name = "prosthetic finger"
	desc = "A jointed metal finger with a socket at one end. It clicks when bent."
	icon = 'voidcrew/modules/fingers/icons/fingers.dmi'
	icon_state = "prosthetic"
	w_class = WEIGHT_CLASS_TINY
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 5)

/obj/item/prosthetic_finger/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/obj/item/bodypart/arm/hand = get_finger_target_hand(interacting_with, user)
	if(!hand)
		return NONE
	if(!can_press_finger_on(user, hand))
		return ITEM_INTERACT_BLOCKING
	INVOKE_ASYNC(src, PROC_REF(fit_to), user, hand)
	return ITEM_INTERACT_SUCCESS

/// Asks which gap to fill if there's more than one, then presses the finger on.
/obj/item/prosthetic_finger/proc/fit_to(mob/living/user, obj/item/bodypart/arm/hand)
	var/list/gaps = list()
	for(var/finger_name in GLOB.hand_fingers)
		if(finger_name in hand.missing_fingers)
			gaps += finger_name
	var/finger_name = length(gaps) == 1 ? gaps[1] : tgui_pick_finger(user, "Which finger on the [hand.get_hand_side()] [hand.appendage_noun] is it replacing?", "Prosthetic finger", gaps)
	if(!finger_name || QDELETED(src) || QDELETED(hand) || !user.is_holding(src))
		return
	press_finger_on(user, src, hand, finger_name, prosthetic = TRUE)

/datum/design/prosthetic_finger
	name = "Prosthetic Finger"
	desc = "A jointed metal finger for a hand that's missing one."
	id = "prosthetic_finger"
	build_type = AUTOLATHE | PROTOLATHE | AWAY_LATHE | MECHFAB
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 5)
	build_path = /obj/item/prosthetic_finger
	construction_time = 5 SECONDS
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MEDICAL,
		RND_CATEGORY_MECHFAB_CYBORG + RND_SUBCATEGORY_MECHFAB_CYBORG_CHASSIS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_MEDICAL | DEPARTMENT_BITFLAG_SCIENCE

// Augmentation is a starting node, so the protolathe and exosuit fabricator have the
// finger from roundstart. The autolathe gets it from RND_CATEGORY_INITIAL.
/datum/techweb_node/augmentation/New()
	. = ..()
	design_ids += list(
		"prosthetic_finger",
	)
