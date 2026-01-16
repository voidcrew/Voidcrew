/**
 * Pirate Hologram
 *
 * A specialized hologram that represents a pirate captain during negotiations.
 * Players click on it to open a radial menu with negotiation options.
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
		var/remaining = negotiation.get_remaining_demand()
		if(remaining < negotiation.demanded_credits)
			. += span_notice("You have paid [negotiation.demanded_credits - remaining] credits so far.")
			. += span_notice("Remaining: [remaining] credits.")
		. += span_notice("Click to negotiate.")

/**
 * Set the hologram appearance based on faction.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/set_faction_appearance(faction)
	pirate_faction = faction
	// Use a generic holographic pirate appearance
	// Could be enhanced with faction-specific sprites later
	icon = 'icons/mob/simple/simple_human.dmi'
	icon_state = "pirate_greyscale"
	// Apply holographic blue tint
	color = "#77bbff"
	alpha = 200
	// Update name based on faction dialog
	if(negotiation?.dialog)
		name = "[negotiation.dialog.faction_name] transmission"

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

/obj/effect/overlay/holo_pad_hologram/pirate/attackby(obj/item/I, mob/living/user, params)
	// Clicking with an item - check if it's tribute
	if(!negotiation)
		return ..()

	if(is_pirate_tribute_accepted(I))
		to_chat(user, span_notice("Place tribute items on the mission pad to deliver them."))
		return TRUE

	return ..()

/**
 * Show the negotiation radial menu.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/show_negotiation_radial(mob/user)
	if(!negotiation)
		return

	var/remaining = negotiation.get_remaining_demand()

	// Build choices list
	var/list/choices = list()

	// Pay full amount (or remaining amount if partial payment made)
	var/pay_label = remaining < negotiation.demanded_credits ? "Pay Remaining ([remaining] cr)" : "Pay ([remaining] cr)"
	choices[pay_label] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_pay")

	// Counter-offer (only if faction accepts it)
	if(negotiation.dialog?.accepts_counter_offer)
		choices["Counter-Offer"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk")

	// Offer cargo (only if faction accepts it)
	if(negotiation.dialog?.accepts_cargo)
		choices["Offer Cargo"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_cargo")

	// Refuse
	choices["Refuse"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_refuse")

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
	else if(choice == "Counter-Offer")
		handle_counter_offer(user)
	else if(choice == "Offer Cargo")
		handle_offer_cargo(user)
	else if(choice == "Refuse")
		handle_refuse(user)

/**
 * Handle pay choice - transfer credits.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/handle_pay_choice(mob/user)
	if(!negotiation)
		return

	var/remaining = negotiation.get_remaining_demand()

	// Check if player ship has enough
	var/available = negotiation.player_ship?.ship_account?.account_balance || 0
	if(available < remaining)
		to_chat(user, span_warning("Insufficient funds! You have [available] credits but need [remaining]."))
		pirate_say(negotiation.dialog.get_counter_rejection_line())
		return

	// Process payment
	if(negotiation.process_credit_payment(remaining))
		to_chat(user, span_notice("Payment of [remaining] credits transferred."))
	else
		to_chat(user, span_warning("Payment failed!"))

/**
 * Handle counter-offer - let player input an amount.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/handle_counter_offer(mob/user)
	if(!negotiation)
		return

	var/offer = tgui_input_number(user, "Enter your counter-offer in credits:", "Counter-Offer", default = round(negotiation.demanded_credits * 0.7), min_value = 1, max_value = negotiation.demanded_credits)

	if(!offer || !negotiation)
		return

	// Check if player can afford their own offer
	var/available = negotiation.player_ship?.ship_account?.account_balance || 0
	if(available < offer)
		to_chat(user, span_warning("You don't have [offer] credits to offer!"))
		return

	// Submit counter-offer
	if(negotiation.accept_counter_offer(offer))
		to_chat(user, span_notice("The pirate accepts your offer of [offer] credits."))
		// Show menu again for payment
		show_negotiation_radial(user)
	else
		to_chat(user, span_warning("The pirate rejected your offer but made a counter: [negotiation.demanded_credits] credits."))

/**
 * Handle offer cargo - explain how to use mission pad.
 */
/obj/effect/overlay/holo_pad_hologram/pirate/proc/handle_offer_cargo(mob/user)
	if(!negotiation)
		return

	// Link mission pad if not already linked
	if(!negotiation.tribute_pad)
		// Find mission pad on player ship by checking shuttle areas
		var/obj/structure/overmap/ship/player_ship = negotiation.player_ship
		if(player_ship?.shuttle?.shuttle_areas)
			for(var/obj/machinery/mission_pad/found_pad as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/mission_pad))
				var/area/pad_area = get_area(found_pad)
				if(pad_area in player_ship.shuttle.shuttle_areas)
					negotiation.link_mission_pad(found_pad)
					break

	if(!negotiation.tribute_pad)
		to_chat(user, span_warning("No mission pad found on your ship! You'll need to pay with credits."))
		return

	to_chat(user, span_notice("Place valuable items on the mission pad to offer as tribute."))
	to_chat(user, span_notice("Accepted items include:"))
	for(var/category in get_pirate_tribute_categories())
		to_chat(user, span_notice("- [category]"))
	to_chat(user, span_notice("Remaining tribute needed: [negotiation.get_remaining_demand()] credits worth."))

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
