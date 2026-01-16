/**
 * Pirate Hologram
 *
 * A specialized hologram that represents a pirate captain during negotiations.
 * Players click on it to open a radial menu with payment options.
 */
/obj/effect/overlay/holo_pad_hologram/pirate
	name = "pirate transmission"
	desc = "A holographic transmission from a pirate vessel. Click to interact."
	/// The negotiation this hologram is part of
	var/datum/pirate_negotiation/negotiation
	/// The faction type for appearance
	var/pirate_faction
	/// Whether the pirate is currently speaking
	var/speaking = FALSE

/obj/effect/overlay/holo_pad_hologram/pirate/Initialize(mapload)
	. = ..()
	// Make clickable
	mouse_opacity = MOUSE_OPACITY_ICON

/obj/effect/overlay/holo_pad_hologram/pirate/Destroy()
	negotiation = null
	return ..()

/obj/effect/overlay/holo_pad_hologram/pirate/examine(mob/user)
	. = ..()
	if(negotiation)
		. += span_notice("They are demanding [negotiation.demanded_credits] credits.")
		if(negotiation.demanded_item_type)
			. += span_notice("OR [negotiation.demanded_item_quantity] [negotiation.demanded_item_name].")
		if(negotiation.items_received > 0)
			. += span_notice("Items delivered: [negotiation.items_received]/[negotiation.demanded_item_quantity]")
		. += span_notice("Click to respond.")

/**
 * Set the hologram appearance based on faction.
 * Uses preset holoimages to create faction-appropriate captain appearances.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/set_faction_appearance(faction)
	pirate_faction = faction

	// Get the appropriate preset holoimage for this faction
	var/datum/preset_holoimage/preset = get_faction_holoimage(faction)
	if(preset)
		var/image/captain_image = preset.build_image()
		if(captain_image)
			icon = captain_image.icon
			icon_state = captain_image.icon_state
			copy_overlays(captain_image, TRUE)
			// Apply holographic effect
			makeHologram()

	// Set proper visual properties
	mouse_opacity = MOUSE_OPACITY_ICON
	layer = FLY_LAYER
	anchored = TRUE

	// Update name based on faction dialog
	if(negotiation?.dialog)
		name = "[negotiation.dialog.faction_name] Captain (Hologram)"

/**
 * Get the appropriate preset holoimage type for a faction.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/get_faction_holoimage(faction)
	switch(faction)
		if("rogues")
			return new /datum/preset_holoimage/pirate_captain/rogues()
		if("irs")
			return new /datum/preset_holoimage/pirate_captain/irs()
		if("skeleton")
			return new /datum/preset_holoimage/pirate_captain/skeleton()
		if("grey")
			return new /datum/preset_holoimage/pirate_captain/greytide()
		if("medieval")
			return new /datum/preset_holoimage/pirate_captain/medieval()
		if("silverscale")
			return new /datum/preset_holoimage/pirate_captain/silverscale()
		if("interdyne")
			return new /datum/preset_holoimage/pirate_captain/interdyne()
		if("lustrous")
			return new /datum/preset_holoimage/pirate_captain/lustrous()
	// Default to generic pirate
	return new /datum/preset_holoimage/pirate_captain()

/**
 * Handle clicking on the hologram - show radial menu.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(!negotiation)
		return

	if(negotiation.negotiation_state != NEGOTIATION_ACTIVE && negotiation.negotiation_state != NEGOTIATION_PAYING)
		to_chat(user, span_warning("The transmission is no longer active."))
		return

	show_negotiation_radial(user)

/**
 * Show the negotiation radial menu - simple: pay credits, give items, or refuse.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/show_negotiation_radial(mob/user)
	if(!negotiation)
		return

	// Build choices list - just credits, items, and refuse
	var/list/choices = list()

	// Pay credits option
	choices["Pay [negotiation.demanded_credits] cr"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_yes")

	// Give items option (if item demand exists)
	if(negotiation.demanded_item_type)
		var/remaining = negotiation.get_remaining_items()
		choices["Give [remaining] [negotiation.demanded_item_name]"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_buying")

	// Refuse
	choices["Refuse"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_no")

	// Show radial menu
	var/choice = show_radial_menu(user, src, choices, tooltips = TRUE, require_near = TRUE)

	if(!choice || !negotiation)
		return

	handle_radial_choice(choice, user)

/**
 * Handle the player's radial menu choice.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/handle_radial_choice(choice, mob/user)
	if(!negotiation)
		return

	// Parse the choice
	if(findtext(choice, "Pay"))
		handle_pay_choice(user)
	else if(findtext(choice, "Give"))
		handle_give_items(user)
	else if(choice == "Refuse")
		handle_refuse(user)

/**
 * Handle pay choice - transfer credits.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/handle_pay_choice(mob/user)
	if(!negotiation)
		return

	// Check if player ship has enough
	var/available = negotiation.player_ship?.ship_account?.account_balance || 0
	if(available < negotiation.demanded_credits)
		to_chat(user, span_warning("Insufficient funds! You have [available] credits but need [negotiation.demanded_credits]."))
		if(negotiation.demanded_item_type)
			pirate_say("You don't have enough credits. Bring me [negotiation.demanded_item_quantity] [negotiation.demanded_item_name] instead!")
		return

	// Process payment
	if(negotiation.process_credit_payment())
		to_chat(user, span_notice("Payment of [negotiation.demanded_credits] credits transferred."))
	else
		to_chat(user, span_warning("Payment failed!"))

/**
 * Handle give items - explain how to use mission pad.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/handle_give_items(mob/user)
	if(!negotiation)
		return

	if(!negotiation.tribute_pad)
		to_chat(user, span_warning("No mission pad found on your ship! You'll need to pay with credits."))
		return

	var/remaining = negotiation.get_remaining_items()
	to_chat(user, span_notice("Place [remaining] [negotiation.demanded_item_name] on the mission pad."))
	to_chat(user, span_notice("The mission pad is linked and ready to receive items."))

	negotiation.negotiation_state = NEGOTIATION_PAYING

/**
 * Handle refuse - end negotiation and resume combat.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/handle_refuse(mob/user)
	if(!negotiation)
		return

	to_chat(user, span_boldwarning("You refuse to pay. Combat will resume!"))
	negotiation.end_negotiation(success = FALSE, reason = "refused")

/**
 * Make the pirate hologram speak.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/pirate_say(message)
	if(!message)
		return

	// Visual speech
	speaking = TRUE
	visible_message(span_bold("[src]") + " says, \"[message]\"")

	// Could add speech animation here
	addtimer(VARSET_CALLBACK(src, speaking, FALSE), 2 SECONDS)

// ========== PRESET HOLOIMAGES FOR PIRATE CAPTAINS ==========

/**
 * Base pirate captain holoimage - generic pirate outfit.
 */
/datum/preset_holoimage/pirate_captain
	outfit_type = /datum/outfit/job/captain/pirate

/**
 * Rogue Raiders - Classic pirate captain.
 */
/datum/preset_holoimage/pirate_captain/rogues
	outfit_type = /datum/outfit/job/captain/pirate

/**
 * IRS - Tax enforcement agent in a suit.
 */
/datum/preset_holoimage/pirate_captain/irs
	outfit_type = /datum/outfit/job/captain/irs

/**
 * Skeleton/Flying Dutchman - Undead captain.
 * Uses a skeleton mob instead of human.
 */
/datum/preset_holoimage/pirate_captain/skeleton
	nonhuman_mobtype = /mob/living/basic/skeleton

/**
 * Grey Tide - Chaotic assistant captain.
 */
/datum/preset_holoimage/pirate_captain/greytide
	outfit_type = /datum/outfit/job/captain/greytide

/**
 * Medieval/Order of the Void - Armored knight captain.
 */
/datum/preset_holoimage/pirate_captain/medieval
	outfit_type = /datum/outfit/job/captain/medieval

/**
 * Silverscale Dynasty - Aristocratic lizard captain.
 */
/datum/preset_holoimage/pirate_captain/silverscale
	outfit_type = /datum/outfit/job/captain/silverscale
	species_type = /datum/species/lizard

/**
 * Interdyne Pharmaceutics - Corporate medical captain.
 */
/datum/preset_holoimage/pirate_captain/interdyne
	outfit_type = /datum/outfit/job/captain/interdyne

/**
 * Lustrous Collective - Ethereal captain.
 */
/datum/preset_holoimage/pirate_captain/lustrous
	outfit_type = /datum/outfit/job/captain/lustrous
	species_type = /datum/species/ethereal
