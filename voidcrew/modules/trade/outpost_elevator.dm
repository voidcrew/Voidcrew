/**
 * # Outpost Hangar Elevator
 *
 * Wall panel serving the outpost's "floors": the concourse (floor 0) and one
 * floor per occupied hangar berth. Berths are independent turf reservations at
 * arbitrary coordinates, so the "elevator" is a teleport: after a short travel
 * delay everything standing in this floor's 3x3 alcove is moved to the
 * destination floor's alcove, tile-for-tile.
 *
 * Each floor's panel is its own independent car, concurrent rides from
 * different floors are fine, they're pure teleports.
 *
 * The floor list marks which floor the viewer's own ship is on, computed live
 * from user.mind.ship_teams, so crew swaps update it with no extra plumbing,
 * and a mind on several crews gets several starred floors.
 */
/obj/machinery/outpost_elevator
	name = "hangar elevator panel"
	desc = "Controls the outpost's hangar elevator. Step into the alcove, pick a floor, mind the gap."
	icon = 'icons/obj/wallmounts.dmi'
	icon_state = "elevpanel0"
	density = FALSE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	mouse_over_pointer = MOUSE_HAND_POINTER

	/// Berth host whose floors we serve (wired by the lobby/berth load scans, or
	/// by the player-outpost construction console when it places an elevator)
	var/obj/structure/overmap/outpost
	/// The berth we sit in, or null for the concourse panel
	var/datum/outpost_berth/berth
	/// Whether this is the concourse (floor 0) panel
	var/is_lobby = FALSE
	/// Mid-ride?
	var/moving = FALSE
	/// Timer for the fake travel delay (TIMER_STOPPABLE)
	var/move_timer

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/outpost_elevator, 32)

/obj/machinery/outpost_elevator/Destroy()
	if(move_timer)
		deltimer(move_timer)
		move_timer = null
	if(berth?.panel == src)
		berth.panel = null
	berth = null
	if(outpost)
		outpost.lobby_panels -= src
		outpost = null
	return ..()

// Attacking the elevator panel is aggression, matching the outpost's other
// indestructible service machinery.
/obj/machinery/outpost_elevator/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/outpost_elevator/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

/// The floor this panel is on: 0 = concourse, 1..N = berth number, -1 = unlinked.
/obj/machinery/outpost_elevator/proc/get_current_floor()
	if(berth)
		return berth.berth_number
	if(is_lobby)
		return 0
	return -1

/// The alcove turfs this panel teleports from.
/obj/machinery/outpost_elevator/proc/get_own_alcove()
	if(berth)
		return berth.alcove_turfs
	if(is_lobby)
		return outpost?.lobby_alcove_turfs
	return null

/obj/machinery/outpost_elevator/examine(mob/user)
	. = ..()
	var/floor_id = get_current_floor()
	if(floor_id > 0)
		. += span_notice("The floor indicator reads: BERTH [floor_id].")
	else if(floor_id == 0)
		. += span_notice("The floor indicator reads: CONCOURSE.")

/obj/machinery/outpost_elevator/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostElevator", name)
		ui.open()

/obj/machinery/outpost_elevator/ui_data(mob/user)
	var/list/data = list()
	data["current_floor"] = get_current_floor()
	data["moving"] = moving
	data["linked"] = !!(outpost && get_current_floor() != -1)

	var/list/floors = list()
	if(outpost)
		floors += list(list(
			"id" = 0,
			"name" = "Concourse: [outpost.name]",
			"occupied" = length(outpost.lobby_alcove_turfs) > 0,
			"your_ship" = FALSE,
		))
		for(var/i in 1 to OUTPOST_MAX_BERTHS)
			// berths stays null on hosts that haven't berthed a ship yet
			var/datum/outpost_berth/slot = LAZYACCESS(outpost.berths, i)
			var/is_yours = FALSE
			if(slot?.ship?.ship_team && user?.mind?.ship_teams)
				is_yours = (slot.ship.ship_team in user.mind.ship_teams)
			floors += list(list(
				"id" = i,
				"name" = slot ? "Berth [i]: [slot.ship ? slot.ship.name : "reserved"]" : "Berth [i]: vacant",
				"occupied" = !!slot,
				"your_ship" = is_yours,
			))
	data["floors"] = floors
	return data

/obj/machinery/outpost_elevator/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action != "goto")
		return
	if(moving || !outpost)
		return TRUE
	var/floor_id = text2num(params["id"])
	if(isnull(floor_id) || floor_id == get_current_floor())
		return TRUE
	var/list/turf/own_alcove = get_own_alcove()
	if(!own_alcove)
		return TRUE
	if(!outpost.get_floor_alcove(floor_id))
		balloon_alert(ui.user, "floor unavailable!")
		return TRUE
	if(!(get_turf(ui.user) in own_alcove))
		balloon_alert(ui.user, "step into the elevator first!")
		return TRUE
	moving = TRUE
	playsound(src, 'sound/machines/chime.ogg', 50, TRUE)
	move_timer = addtimer(CALLBACK(src, PROC_REF(complete_ride), floor_id), OUTPOST_ELEVATOR_TRAVEL_TIME, TIMER_STOPPABLE)
	SStgui.update_uis(src)
	return TRUE

/**
 * The actual "ride": re-validates the destination (a berth can be torn down
 * during the travel delay), then moves the alcove's contents tile-for-tile.
 */
/obj/machinery/outpost_elevator/proc/complete_ride(floor_id)
	move_timer = null
	moving = FALSE
	if(QDELETED(src) || !outpost)
		return
	var/list/turf/own_alcove = get_own_alcove()
	if(!own_alcove)
		return
	var/list/turf/destination = outpost.get_floor_alcove(floor_id)
	if(!destination)
		playsound(src, 'sound/machines/buzz/buzz-two.ogg', 50, TRUE)
		say("Destination no longer available.")
		SStgui.update_uis(src)
		return
	for(var/i in 1 to length(own_alcove))
		var/turf/source_turf = own_alcove[i]
		var/turf/target_turf = destination[min(i, length(destination))]
		for(var/atom/movable/passenger as anything in source_turf.contents.Copy())
			if(passenger.anchored)
				continue
			if(isobserver(passenger))
				continue
			if(ismob(passenger))
				var/mob/mob_passenger = passenger
				if(mob_passenger.buckled)
					continue // travels with whatever it's buckled to
			else if(istype(passenger, /obj/effect))
				continue // decals, markers and other non-things stay put
			passenger.forceMove(target_turf)
	playsound(destination[1], 'sound/machines/ding.ogg', 50, TRUE)
	SStgui.update_uis(src)
