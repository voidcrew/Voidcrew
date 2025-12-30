// Ship Combat Shield Generator
// A modified version of the standard shieldgen for ship combat
// Has a long cooldown before shields can be reactivated after being turned off

/obj/machinery/shieldgen/ship
	name = "ship shield projector"
	desc = "A ship-mounted shield generator. Creates emergency shields around the ship. Warning: Requires a significant cooldown period before reactivation after deactivation."

	/// Cooldown before shields can be reactivated
	COOLDOWN_DECLARE(reactivation_cooldown)

/obj/machinery/shieldgen/ship/interact(mob/user)
	if(locked && !HAS_SILICON_ACCESS(user))
		to_chat(user, span_warning("The machine is locked, you are unable to use it!"))
		return
	if(panel_open)
		to_chat(user, span_warning("The panel must be closed before operating this machine!"))
		return

	if(active)
		user.visible_message(span_notice("[user] deactivated \the [src]."), \
			span_notice("You deactivate \the [src]."), \
			span_hear("You hear heavy droning fade out."))
		shields_down()
		// Start the reactivation cooldown when shields go down
		COOLDOWN_START(src, reactivation_cooldown, SHIP_SHIELD_REACTIVATION_COOLDOWN)
		to_chat(user, span_warning("Shield capacitors discharging. Reactivation available in [DisplayTimeText(SHIP_SHIELD_REACTIVATION_COOLDOWN)]."))
	else
		if(!anchored)
			to_chat(user, span_warning("The device must first be secured to the floor!"))
			return
		// Check reactivation cooldown
		if(!COOLDOWN_FINISHED(src, reactivation_cooldown))
			to_chat(user, span_warning("Shield capacitors still recharging! Available in [DisplayTimeText(COOLDOWN_TIMELEFT(src, reactivation_cooldown))]."))
			return
		user.visible_message(span_notice("[user] activated \the [src]."), \
			span_notice("You activate \the [src]."), \
			span_hear("You hear heavy droning."))
		shields_up()

/obj/machinery/shieldgen/ship/examine(mob/user)
	. = ..()
	if(active)
		. += span_notice("The shields are [span_green("active")].")
	else if(!COOLDOWN_FINISHED(src, reactivation_cooldown))
		. += span_warning("Shield capacitors recharging: [DisplayTimeText(COOLDOWN_TIMELEFT(src, reactivation_cooldown))] remaining.")
	else
		. += span_notice("The shields are ready to activate.")
