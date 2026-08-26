/**
 * # Site-to-ship transponder
 *
 * The half of the transporter you carry. Paired to a specific pad by touching it to
 * one, after which the console upstairs can see where it is and pull it home, and the
 * person holding it can ask to be pulled home without needing anyone at the console.
 *
 * It is not a teleporter. All it does is talk to the pad, so it's dead weight if the
 * pad loses power, is mid-cycle, is still recharging, or has been quietly emagged.
 */
/obj/item/transporter_transponder
	name = "site-to-ship transponder"
	desc = "A palm-sized bluespace beacon keyed to one transporter pad. Squeeze it and the ship above knows where you are and that you want to stop being there."
	icon = 'voidcrew/modules/transporter/icons/transporter.dmi'
	icon_state = "transponder"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_TINY
	slot_flags = ITEM_SLOT_POCKETS | ITEM_SLOT_BELT
	obj_flags = UNIQUE_RENAME
	light_color = COLOR_CYAN
	// Mirrors /datum/design/transporter_transponder in transporter_designs.dm. The old list was a
	// tenth of what the design charges and left out the silver entirely.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/bluespace = HALF_SHEET_MATERIAL_AMOUNT,
	)

	/// The pad this transponder answers to.
	var/obj/machinery/transporter_pad/paired_pad

	/// Stops the button being mashed while the pad works out its answer.
	COOLDOWN_DECLARE(request_cooldown)

/obj/item/transporter_transponder/Destroy()
	unpair()
	return ..()

/obj/item/transporter_transponder/examine(mob/user)
	. = ..()
	if(!paired_pad)
		. += span_warning("It isn't paired to anything. Touch it to a transporter pad.")
		return
	. += span_notice("Paired to [paired_pad]. Squeeze it in your hand to request a beam-up.")
	if(!paired_pad.linked_console)
		. += span_warning("The paired pad has no control console. Nothing is listening.")

/obj/item/transporter_transponder/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	request_pickup(user)
	return TRUE

/// Pairs to a pad, dropping any previous pairing.
/obj/item/transporter_transponder/proc/pair_to_pad(obj/machinery/transporter_pad/pad, mob/user)
	if(QDELETED(pad))
		return
	if(paired_pad == pad)
		balloon_alert(user, "already paired")
		return

	unpair()
	paired_pad = pad
	pad.paired_transponders |= src
	if(user)
		name = "[initial(name)] ([user.real_name])"
		balloon_alert(user, "paired to pad")
	playsound(src, 'sound/machines/ping.ogg', 30, TRUE)

/obj/item/transporter_transponder/proc/unpair()
	if(!paired_pad)
		return
	paired_pad.paired_transponders -= src
	paired_pad = null

/// Asks the paired pad's console to bring the holder up.
/obj/item/transporter_transponder/proc/request_pickup(mob/user)
	if(!paired_pad)
		balloon_alert(user, "not paired to a pad!")
		return
	if(!COOLDOWN_FINISHED(src, request_cooldown))
		balloon_alert(user, "still handshaking")
		return

	var/obj/machinery/computer/transporter/console = paired_pad.linked_console
	if(!console)
		balloon_alert(user, "pad has no console!")
		playsound(src, 'sound/machines/buzz/buzz-two.ogg', 30, TRUE)
		return

	COOLDOWN_START(src, request_cooldown, 5 SECONDS)
	playsound(src, 'sound/machines/terminal/terminal_prompt.ogg', 30, TRUE)
	balloon_alert(user, "requesting beam-up")

	var/failure = console.request_beam_up(src, user)
	if(failure)
		to_chat(user, span_warning("[src] buzzes: \"[failure].\""))
		playsound(src, 'sound/machines/buzz/buzz-two.ogg', 30, TRUE)
		return

	to_chat(user, span_notice("[src] goes warm in your hand as the pad takes your pattern."))
