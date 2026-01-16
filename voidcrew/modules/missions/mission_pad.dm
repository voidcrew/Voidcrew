/**
 * # Mission Pad
 *
 * A teleportation pad used for mission item turn-in and reward dispensing.
 * Place items on the pad to turn them in for delivery missions.
 * Item rewards spawn on the pad when missions are completed.
 */
/obj/machinery/mission_pad
	name = "mission pad"
	desc = "A teleportation pad used for mission logistics. Place items here for turn-in, and collect your rewards."
	icon = 'icons/obj/machines/telepad.dmi'
	icon_state = "lpad-idle"
	base_icon_state = "lpad-idle"
	density = FALSE
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.5
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION
	circuit = /obj/item/circuitboard/machine/mission_pad

	/// Linked mission board console
	var/obj/machinery/computer/mission_board/linked_console
	/// Active pirate negotiation using this pad for tribute (if any)
	var/datum/pirate_negotiation/tribute_negotiation

/obj/machinery/mission_pad/Initialize(mapload)
	. = ..()
	// Try to find a linked console nearby
	find_linked_console()

/obj/machinery/mission_pad/Destroy()
	if(linked_console)
		linked_console.linked_pad = null
		linked_console = null
	if(tribute_negotiation)
		tribute_negotiation.tribute_pad = null
		tribute_negotiation = null
	return ..()

/**
 * Searches for a mission board console within range and links to it.
 */
/obj/machinery/mission_pad/proc/find_linked_console()
	for(var/obj/machinery/computer/mission_board/console in range(3, src))
		if(!console.linked_pad)
			link_to_console(console)
			return

/**
 * Links this pad to a mission board console.
 * * console - The console to link to
 */
/obj/machinery/mission_pad/proc/link_to_console(obj/machinery/computer/mission_board/console)
	if(!console)
		return
	if(linked_console)
		linked_console.linked_pad = null
	linked_console = console
	console.linked_pad = src

/**
 * Returns a list of items currently on the pad.
 */
/obj/machinery/mission_pad/proc/get_items_on_pad()
	var/list/items = list()
	for(var/obj/item/item in loc)
		items += item
	return items

/**
 * Checks if a specific item type is on the pad.
 * * item_type - The type path to check for
 * Returns the first matching item, or null if not found.
 */
/obj/machinery/mission_pad/proc/get_item_of_type(item_type)
	for(var/obj/item/item in loc)
		if(istype(item, item_type))
			return item
	return null

/**
 * Performs a teleport visual effect on the pad.
 * Called when items are teleported in (rewards) or out (turn-ins).
 */
/obj/machinery/mission_pad/proc/do_teleport_effect()
	// Visual effect
	flick("lpad-idle", src)

	// Spark effect
	var/datum/effect_system/spark_spread/sparks = new
	sparks.set_up(5, 1, loc)
	sparks.start()

	// Sound effect
	playsound(src, 'sound/effects/magic/teleport_diss.ogg', 50, TRUE)

/**
 * Handle items being placed on the pad.
 * If we're linked to a tribute negotiation, check if the item is valid tribute.
 */
/obj/machinery/mission_pad/Crossed(atom/movable/crossed, oldloc)
	. = ..()
	// Check for tribute processing
	if(tribute_negotiation && isitem(crossed))
		process_tribute_item(crossed)

/**
 * Process an item as potential tribute for an active negotiation.
 */
/obj/machinery/mission_pad/proc/process_tribute_item(obj/item/item)
	if(!tribute_negotiation)
		return

	// Check if this item is accepted as tribute
	if(tribute_negotiation.process_item_payment(item))
		visible_message(span_notice("The [item.name] is teleported away as tribute!"))

/obj/machinery/mission_pad/examine(mob/user)
	. = ..()
	if(tribute_negotiation)
		. += span_warning("This pad is linked to an active pirate negotiation!")
		var/remaining = tribute_negotiation.get_remaining_items()
		if(remaining > 0)
			. += span_notice("Place [remaining] more [tribute_negotiation.demanded_item_name] here to pay tribute.")

/**
 * Circuit board for the mission pad.
 */
/obj/item/circuitboard/machine/mission_pad
	name = "mission pad"
	greyscale_colors = CIRCUIT_COLOR_SUPPLY
	build_path = /obj/machinery/mission_pad
	req_components = list(
		/datum/stock_part/micro_laser = 1,
		/datum/stock_part/capacitor = 1,
	)
