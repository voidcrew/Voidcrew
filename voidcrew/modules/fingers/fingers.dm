/**
 * Fingers.
 *
 * With the Fingers quirk (quirk.dm), every flesh-and-blood hand has five of them, and they
 * can come off. Everyone else's hands work as they always have. A hand keeps a
 * lazy list of the fingers it has lost, so a whole hand costs nothing and the list travels
 * with the arm if the arm itself is cut off and sewn back on.
 *
 * Fingers come off two ways:
 * - A severe or critical slash or pierce wound on the arm, or a critical blunt one, can
 *   take one with it.
 * - Someone takes a bladed tool to a hand on purpose (right-click, aiming at the arm,
 *   out of combat mode) and picks which finger goes.
 *
 * Losing fingers matters: a hand drops things more often the fewer it has, a hand with
 * none cannot hold anything, and snapping needs a thumb and a middle finger.
 *
 * Getting them back: a severed finger can be pressed back into its own gap, and a printed
 * prosthetic finger fits any gap. Either one sits loose until someone sutures it, and a
 * loose finger can pop off again when that arm gets hurt (attaching.dm). A full heal
 * regrows everything, and a replacement arm, organic or robotic, comes with a full set.
 * Robotic hands never lose fingers here.
 *
 * Fingers are also drawn on the mob, hanging off the bottom of each bare hand and
 * wiggling. Each one is that species' own arm sprite shrunk down to finger size, baked
 * per direction into fingers_mob.dmi so it sits on the hand whichever way the mob faces.
 * Species without their own set use the human one, tinted to the skin colour. Gloves, or
 * a suit that covers the hands, recolour the fingers to match whatever that clothing looks
 * like over the hand, so a gloved hand has gloved fingers. A hand
 * holding anything curls its fingers into a fist drawn over the held item, so they wrap
 * around the handle of whatever it is.
 */

/// On-mob finger sprites. States are "[limb_id or glove]_[l|r]_[1-5]", with "_wild" (*wiggle) and "_grip" (holding something) variants.
#define FINGER_MOB_ICON 'voidcrew/modules/fingers/icons/fingers_mob.dmi'

/// Whether an overlay is a middle finger. Only matters while a hand is flipping someone off.
/proc/is_middle_finger_overlay(image/overlay)
	return isimage(overlay) && overlay.icon == FINGER_MOB_ICON && findtext(overlay.icon_state, "_3")

/// Which hand an overlay's finger belongs to, "l" or "r", or null if it isn't one of ours.
/// The limb rig pulls fingers out of the masked body so they can move with their arm.
/proc/get_finger_overlay_side(image/overlay)
	if(!isimage(overlay) || overlay.icon != FINGER_MOB_ICON)
		return null
	return findtext(overlay.icon_state, "_l_") ? "l" : "r"

/// Every finger on a hand, in order from thumb to pinky.
GLOBAL_LIST_INIT(hand_fingers, list("thumb", "index finger", "middle finger", "ring finger", "pinky"))

/// Short labels for finger pickers, keyed by finger name.
GLOBAL_LIST_INIT(hand_finger_labels, list("thumb" = "Thumb", "index finger" = "Index", "middle finger" = "Middle", "ring finger" = "Ring", "pinky" = "Pinky"))

/// Asks the user to pick one of the given fingers, listed by short label. Returns the finger name or null.
/proc/tgui_pick_finger(mob/user, message, title, list/finger_names)
	var/list/options = list()
	for(var/finger_name in finger_names)
		options[GLOB.hand_finger_labels[finger_name] || finger_name] = finger_name
	var/picked = tgui_input_list(user, message, title, options)
	return picked ? options[picked] : null

/// Sampled when worn clothing over a hand has no pixels there to take a colour from.
#define FINGER_FALLBACK_COVERING_COLOR "#8f8f8f"
/// What printed prosthetic fingers look like on a bare hand.
#define FINGER_PROSTHETIC_COLOR "#a9afb8"
/// Gripping fingers draw just above held items, so they wrap around the handle.
#define FINGER_GRIP_LAYER (HANDS_LAYER - 0.5)
/// How long the *wiggle emote keeps the fingers going.
#define FINGER_WIGGLE_DURATION (3 SECONDS)

/// Chance per missing finger that picking something up with that hand fumbles it.
#define FINGER_FUMBLE_CHANCE_PER_MISSING 6
/// Chance that a severe slash or pierce wound on an arm takes a finger with it.
#define FINGER_WOUND_LOSS_CHANCE_SEVERE 20
/// Chance that a critical slash or pierce wound on an arm takes a finger with it.
#define FINGER_WOUND_LOSS_CHANCE_CRITICAL 40
/// Chance that a critical blunt wound on an arm crushes a finger off.
#define FINGER_WOUND_LOSS_CHANCE_CRUSH 15
/// How long it takes to cut a finger off someone else.
#define FINGER_CUT_TIME (6 SECONDS)
/// How long it takes to cut off one of your own fingers. Hesitation, mostly.
#define FINGER_CUT_TIME_SELF (9 SECONDS)
/// Brute damage dealt to the hand when a finger is cut off on purpose.
#define FINGER_CUT_DAMAGE 8

/obj/item/bodypart/arm
	/// Names of the fingers this hand has lost, from GLOB.hand_fingers. Null on a whole hand.
	var/list/missing_fingers
	/// Fingers that were put back on but not sutured yet. They can fall off again.
	var/list/loose_fingers
	/// Fingers that are printed prosthetics rather than flesh.
	var/list/prosthetic_fingers
	/// Whether the fingers are currently doing the big *wiggle instead of the idle one.
	var/fingers_wiggling = FALSE
	/// Whether this hand is holding something, so its fingers curl around it.
	var/fingers_gripping = FALSE
	/// Whether this hand is a fist with the middle finger up.
	var/fingers_bird = FALSE
	/// Colour of the glove or suit worn over this hand, or null when it's bare. Kept by the owner.
	var/finger_covering_color
	/// Whether this hand has individual fingers at all. Set by the Fingers quirk (quirk.dm).
	var/fingered = FALSE

/// Whether this hand has fingers that can be lost. Only hands from someone with the Fingers quirk
/// do. Robotic hands don't bleed and don't come apart, and xenomorph claws are their own business.
/obj/item/bodypart/arm/proc/can_have_fingers()
	return fingered && IS_ORGANIC_LIMB(src) && !(bodytype & BODYTYPE_ALIEN)

/// The fingers this hand still has, thumb first.
/obj/item/bodypart/arm/proc/get_remaining_fingers()
	if(!can_have_fingers())
		return GLOB.hand_fingers.Copy()
	return GLOB.hand_fingers - missing_fingers

/// How many fingers this hand still has.
/obj/item/bodypart/arm/proc/get_finger_count()
	if(!can_have_fingers())
		return length(GLOB.hand_fingers)
	return length(GLOB.hand_fingers) - LAZYLEN(missing_fingers)

/// Whether this hand still has the named finger.
/obj/item/bodypart/arm/proc/has_finger(finger_name)
	return !can_have_fingers() || !(finger_name in missing_fingers)

/// "left" or "right", for naming fingers.
/obj/item/bodypart/arm/proc/get_hand_side()
	return body_zone == BODY_ZONE_L_ARM ? "left" : "right"

/**
 * Removes a finger from this hand and drops it.
 *
 * * finger_name - the finger to remove. Picks a random remaining one if null.
 * * drop_loc - where the severed finger lands. Defaults to the hand's turf.
 *
 * Returns the severed finger, or null if there was nothing to remove.
 */
/obj/item/bodypart/arm/proc/lose_finger(finger_name, atom/drop_loc)
	if(!can_have_fingers())
		return null
	var/list/remaining = get_remaining_fingers()
	if(!length(remaining))
		return null
	if(isnull(finger_name))
		finger_name = pick(remaining)
	else if(!(finger_name in remaining))
		return null

	LAZYADD(missing_fingers, finger_name)
	LAZYREMOVE(loose_fingers, finger_name)
	var/obj/item/severed
	if(finger_name in prosthetic_fingers)
		LAZYREMOVE(prosthetic_fingers, finger_name)
		severed = new /obj/item/prosthetic_finger(drop_loc || get_turf(src))
	else
		var/obj/item/food/finger/flesh = new(drop_loc || get_turf(src))
		flesh.take_appearance_from(src, finger_name)
		severed = flesh
	on_fingers_changed()
	owner?.on_finger_lost(src)
	return severed

/// Grows a flesh finger back in place, fully attached. Returns TRUE if it was missing.
/obj/item/bodypart/arm/proc/regrow_finger(finger_name)
	if(!(finger_name in missing_fingers))
		return FALSE
	LAZYREMOVE(missing_fingers, finger_name)
	LAZYREMOVE(loose_fingers, finger_name)
	LAZYREMOVE(prosthetic_fingers, finger_name)
	on_fingers_changed()
	return TRUE

/// Grows back every missing finger and settles any loose ones. Prosthetics stay.
/obj/item/bodypart/arm/proc/regrow_all_fingers()
	if(!missing_fingers && !loose_fingers)
		return
	for(var/finger_name in missing_fingers)
		LAZYREMOVE(prosthetic_fingers, finger_name)
	missing_fingers = null
	loose_fingers = null
	on_fingers_changed()

/// Redraws the hand after its fingers change.
/obj/item/bodypart/arm/proc/on_fingers_changed()
	if(owner)
		owner.update_body_parts()
	else
		update_icon_dropped()

/// Starts or stops the big wiggle on this hand's fingers.
/obj/item/bodypart/arm/proc/set_fingers_wiggling(wiggling)
	if(fingers_wiggling == wiggling)
		return
	fingers_wiggling = wiggling
	on_fingers_changed()

/// Makes this hand a fist with the middle finger up, or puts it back.
/obj/item/bodypart/arm/proc/set_fingers_bird(bird)
	if(fingers_bird == bird)
		return
	fingers_bird = bird
	on_fingers_changed()

/// Which pose the fingers are in: "" for the idle dangle, "_wild" or "_grip".
/obj/item/bodypart/arm/proc/get_finger_pose()
	if(fingers_wiggling)
		return "_wild"
	if(fingers_gripping && owner)
		return "_grip"
	return ""

/// Whether this is a visible, human-shaped flesh hand that fingers could be drawn on.
/obj/item/bodypart/arm/proc/has_drawable_hand()
	if(!IS_ORGANIC_LIMB(src) || (bodytype & BODYTYPE_ALIEN) || is_invisible || is_husked || !(bodyshape & BODYSHAPE_HUMANOID))
		return FALSE
	// Arms that shift their gloves around per direction (monkeys) don't have a human-shaped hand.
	return isnull(worn_glove_offset)

/// Whether this hand's fingers should be drawn at all right now.
/obj/item/bodypart/arm/proc/should_draw_fingers()
	return fingered && has_drawable_hand() && get_finger_count() > 0

/// A hand without the Fingers quirk still grows a middle finger to flip someone off with, and
/// only that one.
/obj/item/bodypart/arm/proc/should_draw_lone_bird()
	return fingers_bird && !fingered && has_drawable_hand()

/// The colour of whatever is worn over this hand, or null if it's bare.
/obj/item/bodypart/arm/proc/get_finger_covering_color()
	return owner ? finger_covering_color : null

/obj/item/bodypart/arm/generate_icon_key()
	RETURN_TYPE(/list)
	. = ..()
	if(should_draw_lone_bird())
		. += "-lonebird[get_finger_covering_color()]"
		return
	if(!should_draw_fingers())
		return
	var/finger_key = ""
	for(var/finger_name in GLOB.hand_fingers)
		if(finger_name in missing_fingers)
			finger_key += "0"
		else
			finger_key += (finger_name in prosthetic_fingers) ? "p" : "1"
	. += "-fingers[finger_key][get_finger_pose()][fingers_bird ? "bird" : ""][get_finger_covering_color()]"

/obj/item/bodypart/arm/get_limb_icon(dropped, mob/living/carbon/update_on)
	. = ..()
	var/lone_bird = should_draw_lone_bird()
	if(!lone_bird && !should_draw_fingers())
		return
	var/covering_color = get_finger_covering_color()
	// Gloved fingers use a pale set the glove colour can tint without darkening it.
	var/sprite_set = covering_color ? "glove" : (icon_exists(FINGER_MOB_ICON, "[limb_id]_l_1") ? limb_id : "human")
	var/finger_color = covering_color || draw_color
	var/side = body_zone == BODY_ZONE_L_ARM ? "l" : "r"
	var/pose = get_finger_pose()
	var/finger_layer = pose == "_grip" ? -FINGER_GRIP_LAYER : -aux_layer
	if(fingers_bird)
		finger_layer = -FINGER_GRIP_LAYER
	for(var/finger_index in 1 to length(GLOB.hand_fingers))
		var/finger_name = GLOB.hand_fingers[finger_index]
		if(lone_bird ? finger_index != 3 : (finger_name in missing_fingers))
			continue
		// Flipping the bird: a fist, with the middle finger held straight.
		var/finger_pose = fingers_bird ? (finger_index == 3 ? "" : "_grip") : pose
		var/image/finger
		if(!covering_color && (finger_name in prosthetic_fingers))
			finger = image(FINGER_MOB_ICON, "glove_[side]_[finger_index][finger_pose]", finger_layer)
			finger.color = FINGER_PROSTHETIC_COLOR
		else
			finger = image(FINGER_MOB_ICON, "[sprite_set]_[side]_[finger_index][finger_pose]", finger_layer)
			if(finger_color)
				finger.color = "[finger_color]"
		// Keeps one-pixel fingers crisp under any transform (dancing, resizing) instead of blurring.
		finger.appearance_flags |= PIXEL_SCALE
		. += finger

/// Examine lines about this hand's fingers, with "The" or a possessive already in front.
/obj/item/bodypart/arm/proc/get_finger_status_lines(whose)
	. = list()
	if(!can_have_fingers())
		return
	var/list/lost = missing_fingers
	if(length(lost) >= length(GLOB.hand_fingers))
		. += span_warning("[whose] [appendage_noun] has no fingers left, just stumps!")
	else if(length(lost))
		. += span_warning("[whose] [appendage_noun] is missing its [english_list(lost)].")
	if(length(prosthetic_fingers))
		. += span_notice("[whose] [appendage_noun] has a prosthetic [english_list(prosthetic_fingers)].")
	if(length(loose_fingers))
		. += span_warning("[whose] [english_list(loose_fingers)] [length(loose_fingers) > 1 ? "are" : "is"] hanging on loosely, not stitched in.")

/obj/item/bodypart/arm/examine(mob/user)
	. = ..()
	. += get_finger_status_lines("The")

/mob/living/carbon/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_CARBON_GAIN_WOUND, PROC_REF(roll_finger_wound_loss))
	RegisterSignal(src, COMSIG_ATOM_ITEM_INTERACTION_SECONDARY, PROC_REF(try_cut_off_finger))
	RegisterSignal(src, COMSIG_LIVING_POST_FULLY_HEAL, PROC_REF(regrow_fingers_on_heal))
	RegisterSignal(src, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(try_suture_finger))
	RegisterSignal(src, COMSIG_CARBON_LIMB_DAMAGED, PROC_REF(shake_loose_fingers))

/**
 * The worn item that shows over this carbon's hands, if any.
 *
 * A suit that covers the hands wins over gloves, and gloves hidden under something or
 * drawn with no worn sprite don't count. MODsuit gauntlets are gloves like any other.
 */
/mob/living/carbon/proc/get_hand_covering()
	var/obj/item/suit = get_item_by_slot(ITEM_SLOT_OCLOTHING)
	if(suit && (suit.body_parts_covered & HANDS) && !HAS_TRAIT(suit, TRAIT_NO_WORN_ICON))
		return suit
	if(!gloves || HAS_TRAIT(gloves, TRAIT_NO_WORN_ICON) || (check_obscured_slots() & ITEM_SLOT_GLOVES))
		return null
	return gloves

/// Rechecks what is worn over each hand and redraws the hands if any of it changed colour.
/mob/living/carbon/proc/update_finger_coverings()
	var/obj/item/covering = get_hand_covering()
	var/changed = FALSE
	for(var/obj/item/bodypart/arm/hand in bodyparts)
		var/new_color = covering ? get_worn_hand_color(covering, hand.body_zone == BODY_ZONE_L_ARM) : null
		if(hand.finger_covering_color == new_color)
			continue
		hand.finger_covering_color = new_color
		// Only a hand that draws its fingers needs redrawing. The colour is still kept for the rest,
		// for the middle finger a *bird grows.
		if(hand.fingered)
			changed = TRUE
	if(changed)
		update_body_parts()

// Gloves going on or off, MODsuit gauntlets sealing, and suits covering the hands all end in
// one of these two redraws, after the slot has already changed.
/mob/living/carbon/human/update_worn_gloves(update_obscured = TRUE)
	. = ..()
	update_finger_coverings()

/mob/living/carbon/human/update_worn_oversuit(update_obscured = TRUE)
	. = ..()
	update_finger_coverings()

/mob/living/carbon/update_held_items()
	. = ..()
	update_finger_grips()

/// Curls the fingers of every hand that is holding something, and uncurls the rest.
/mob/living/carbon/proc/update_finger_grips()
	var/changed = FALSE
	for(var/obj/item/bodypart/arm/hand in bodyparts)
		if(!hand.fingered)
			continue // No fingers to curl, so nothing to redraw.
		var/obj/item/held = hand.held_index ? get_item_for_held_index(hand.held_index) : null
		var/gripping = !isnull(held) && !(held.item_flags & HAND_ITEM)
		if(hand.fingers_gripping == gripping)
			continue
		hand.fingers_gripping = gripping
		changed = TRUE
	if(changed)
		update_body_parts()

/// Sets the fingers on both hands going for a few seconds.
/mob/living/carbon/proc/wiggle_fingers()
	for(var/obj/item/bodypart/arm/hand in bodyparts)
		hand.set_fingers_wiggling(TRUE)
	addtimer(CALLBACK(src, PROC_REF(stop_wiggling_fingers)), FINGER_WIGGLE_DURATION, TIMER_UNIQUE|TIMER_OVERRIDE)

/mob/living/carbon/proc/stop_wiggling_fingers()
	for(var/obj/item/bodypart/arm/hand in bodyparts)
		hand.set_fingers_wiggling(FALSE)

/// Returns the hand this carbon uses for the given held index, or null.
/mob/living/carbon/proc/get_hand_for_held_index(hand_index)
	if(hand_index < 1 || hand_index > length(hand_bodyparts))
		return null
	return hand_bodyparts[hand_index]

/// Called by a hand after it loses a finger. A hand that just lost its last finger lets go.
/mob/living/carbon/proc/on_finger_lost(obj/item/bodypart/arm/hand)
	if(hand.get_finger_count() > 0 || !hand.held_index)
		return
	var/obj/item/held = get_item_for_held_index(hand.held_index)
	if(held && dropItemToGround(held))
		to_chat(src, span_userdanger("[held] slips out of your fingerless [hand.appendage_noun]!"))

/// A hand with no fingers left cannot hold anything.
/mob/living/carbon/can_put_in_hand(I, hand_index)
	. = ..()
	if(!.)
		return
	var/obj/item/bodypart/arm/hand = get_hand_for_held_index(hand_index)
	if(hand && hand.get_finger_count() <= 0)
		return FALSE

/// A hand missing fingers sometimes drops what it was just given.
/mob/living/carbon/put_in_hand(obj/item/I, hand_index, forced = FALSE, ignore_anim = TRUE, visuals_only = FALSE)
	. = ..()
	if(!. || forced || visuals_only || (I.item_flags & (ABSTRACT|HAND_ITEM)))
		return
	var/obj/item/bodypart/arm/hand = get_hand_for_held_index(hand_index)
	if(!hand)
		return
	var/missing = length(GLOB.hand_fingers) - hand.get_finger_count()
	if(missing > 0 && prob(missing * FINGER_FUMBLE_CHANCE_PER_MISSING))
		// Let whatever put it there finish first, then drop it.
		addtimer(CALLBACK(src, PROC_REF(finger_fumble), I, hand_index), 0.1 SECONDS)

/// Drops an item that a fingerless-ish hand failed to keep hold of.
/mob/living/carbon/proc/finger_fumble(obj/item/fumbled, hand_index)
	if(QDELETED(fumbled) || get_item_for_held_index(hand_index) != fumbled)
		return
	if(HAS_TRAIT(fumbled, TRAIT_NODROP) || !dropItemToGround(fumbled))
		return
	visible_message(
		span_warning("[src] fumbles [fumbled] with [p_their()] missing fingers."),
		span_warning("You fumble [fumbled]. There aren't enough fingers on that hand to hold it properly."),
	)

/mob/living/carbon/proc/roll_finger_wound_loss(mob/living/carbon/source, datum/wound/wound, obj/item/bodypart/limb)
	SIGNAL_HANDLER
	var/obj/item/bodypart/arm/hand = limb
	if(!istype(hand) || !hand.can_have_fingers() || hand.get_finger_count() <= 0)
		return
	if(wound.severity >= WOUND_SEVERITY_LOSS)
		return // The whole arm is coming off. The fingers are going with it.

	var/list/wounding_types = wound.get_pregen_data().required_wounding_types
	var/loss_chance = 0
	if((WOUND_SLASH in wounding_types) || (WOUND_PIERCE in wounding_types))
		if(wound.severity >= WOUND_SEVERITY_CRITICAL)
			loss_chance = FINGER_WOUND_LOSS_CHANCE_CRITICAL
		else if(wound.severity >= WOUND_SEVERITY_SEVERE)
			loss_chance = FINGER_WOUND_LOSS_CHANCE_SEVERE
	else if((WOUND_BLUNT in wounding_types) && wound.severity >= WOUND_SEVERITY_CRITICAL)
		loss_chance = FINGER_WOUND_LOSS_CHANCE_CRUSH
	if(!prob(loss_chance))
		return

	var/finger_name = pick(hand.get_remaining_fingers())
	if(!hand.lose_finger(finger_name))
		return
	visible_message(
		span_danger("[src]'s [finger_name] comes clean off [p_their()] [hand.plaintext_zone]!"),
		span_userdanger("Your [finger_name] comes clean off!"),
	)

/// Right-clicking an arm with a bladed tool, out of combat mode, starts cutting a finger off.
/// The zone selector has no hand zones, so aiming at the arm is how you aim at its hand.
/mob/living/carbon/proc/try_cut_off_finger(mob/living/carbon/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(user.combat_mode || !(tool.get_sharpness() & SHARP_EDGED))
		return NONE
	if(length(surgeries))
		return NONE // Don't get in the way of an operation in progress.
	var/obj/item/bodypart/arm/hand = get_finger_target_hand(src, user)
	if(!hand || !hand.can_have_fingers() || hand.get_finger_count() <= 0)
		return NONE
	INVOKE_ASYNC(src, PROC_REF(cut_off_finger), user, tool, hand)
	return ITEM_INTERACT_SUCCESS

/mob/living/carbon/proc/cut_off_finger(mob/living/user, obj/item/tool, obj/item/bodypart/arm/hand)
	var/finger_name = tgui_pick_finger(user, "Which finger on the [hand.get_hand_side()] [hand.appendage_noun]?", "Cut off a finger", hand.get_remaining_fingers())
	if(!finger_name || hand.owner != src || !hand.has_finger(finger_name))
		return
	if(!user.can_perform_action(src) || user.get_active_held_item() != tool)
		return

	var/self = (user == src)
	if(self)
		user.visible_message(
			span_danger("[user] presses [tool] against [user.p_their()] own [finger_name]..."),
			span_danger("You press [tool] against your [finger_name]..."),
		)
	else
		user.visible_message(
			span_danger("[user] starts cutting off [src]'s [finger_name] with [tool]!"),
			span_danger("You start cutting off [src]'s [finger_name] with [tool]..."),
			ignored_mobs = src,
		)
		to_chat(src, span_userdanger("[user] starts cutting off your [finger_name] with [tool]!"))

	if(!do_after(user, self ? FINGER_CUT_TIME_SELF : FINGER_CUT_TIME, src))
		return
	if(hand.owner != src || !hand.has_finger(finger_name))
		return

	if(!hand.lose_finger(finger_name))
		return
	playsound(src, 'sound/items/weapons/bladeslice.ogg', 50, TRUE)
	hand.receive_damage(brute = FINGER_CUT_DAMAGE, wound_bonus = CANT_WOUND, damage_source = tool)
	add_splatter_floor(get_turf(src), small_drip = TRUE)
	visible_message(
		span_danger("[user] cuts off [self ? user.p_their() : "[src]'s"] [finger_name] with [tool]!"),
		span_userdanger("Your [finger_name] comes off!"),
	)
	if(stat == CONSCIOUS && !HAS_TRAIT(src, TRAIT_ANALGESIA))
		INVOKE_ASYNC(src, TYPE_PROC_REF(/mob, emote), "scream")
	log_combat(user, src, "cut off the [hand.get_hand_side()] [finger_name] of", tool)

/mob/living/carbon/proc/regrow_fingers_on_heal(mob/living/carbon/source, heal_flags)
	SIGNAL_HANDLER
	if(!(heal_flags & HEAL_LIMBS))
		return
	for(var/obj/item/bodypart/arm/hand in bodyparts)
		hand.regrow_all_fingers()

/// What others see about this carbon's fingers. Gloves hide the damage.
/mob/living/carbon/proc/get_finger_examine()
	if(get_hand_covering())
		return null
	var/list/lines = list()
	for(var/obj/item/bodypart/arm/hand in bodyparts)
		lines += hand.get_finger_status_lines("[p_Their()] [hand.get_hand_side()]")
	return lines

/mob/living/carbon/examine(mob/user)
	. = ..()
	if(HAS_TRAIT(src, TRAIT_UNKNOWN))
		return
	var/list/finger_lines = get_finger_examine()
	if(length(finger_lines))
		. += finger_lines

/**
 * The colour of the part of a worn item's sprite that sits over a hand.
 *
 * Tinted and greyscale items give their colour directly, as do a few two-tone gloves listed
 * below. Anything else is sampled from its south-facing worn sprite over the hand, once per
 * sprite, and cached.
 */
/proc/get_worn_hand_color(obj/item/covering, left_hand)
	if(istext(covering.color))
		return covering.color
	// Two-tone gloves whose trim covers most of the hand, so sampling it gets the trim's colour.
	var/static/list/trimmed_gloves = list(
		/obj/item/clothing/gloves/captain = "#3d4379",
	)
	for(var/glove_type in trimmed_gloves)
		if(istype(covering, glove_type))
			return trimmed_gloves[glove_type]
	if(covering.greyscale_colors)
		var/list/colors = splittext(covering.greyscale_colors, "#")
		for(var/color_part in colors)
			if(color_part)
				return "#[color_part]"
	var/default_file = (covering.slot_flags & ITEM_SLOT_GLOVES) ? 'icons/mob/clothing/hands.dmi' : DEFAULT_SUIT_FILE
	var/icon_file = covering.worn_icon || default_file
	var/icon_state = covering.worn_icon_state || covering.icon_state
	var/static/list/sampled_colors = list()
	var/cache_key = "[icon_file]-[icon_state]-[left_hand]"
	if(!(cache_key in sampled_colors))
		sampled_colors[cache_key] = sample_hand_color(icon_file, icon_state, left_hand)
	return sampled_colors[cache_key]

/**
 * The lit colour of a worn sprite over the hand, facing south.
 *
 * The most common pixel is usually a shadow tone, which turns yellow gloves orange once it
 * is multiplied onto the fingers. The pixel three quarters of the way up the brightness
 * range is the colour the glove actually reads as.
 */
/proc/sample_hand_color(icon_file, icon_state, left_hand)
	if(!icon_exists(icon_file, icon_state))
		return FINGER_FALLBACK_COVERING_COLOR
	var/icon/sprite = icon(icon_file, icon_state, SOUTH, 1)
	// The hands sit 4x4 pixels at x 8-11 (right) and 21-24 (left), y 11-14, facing south.
	var/x_start = left_hand ? 21 : 8
	var/list/pixels = list()
	var/list/brightness = list()
	for(var/x in x_start to x_start + 3)
		for(var/y in 11 to 14)
			var/pixel = sprite.GetPixel(x, y)
			if(!pixel)
				continue
			pixel = copytext(pixel, 1, 8)
			var/list/rgb = rgb2num(pixel)
			var/lum = rgb[1] * 0.299 + rgb[2] * 0.587 + rgb[3] * 0.114
			// Insertion sort, darkest first. Sixteen pixels at most.
			var/insert_at = length(pixels) + 1
			for(var/i in 1 to length(pixels))
				if(lum < brightness[i])
					insert_at = i
					break
			pixels.Insert(insert_at, pixel)
			brightness.Insert(insert_at, lum)
	if(!length(pixels))
		return FINGER_FALLBACK_COVERING_COLOR
	return pixels[round((length(pixels) - 1) * 0.75) + 1]

#undef FINGER_MOB_ICON
#undef FINGER_PROSTHETIC_COLOR
#undef FINGER_FALLBACK_COVERING_COLOR
#undef FINGER_GRIP_LAYER
#undef FINGER_WIGGLE_DURATION
#undef FINGER_FUMBLE_CHANCE_PER_MISSING
#undef FINGER_WOUND_LOSS_CHANCE_SEVERE
#undef FINGER_WOUND_LOSS_CHANCE_CRITICAL
#undef FINGER_WOUND_LOSS_CHANCE_CRUSH
#undef FINGER_CUT_TIME
#undef FINGER_CUT_TIME_SELF
#undef FINGER_CUT_DAMAGE
