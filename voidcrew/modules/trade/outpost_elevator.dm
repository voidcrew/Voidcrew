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
 *
 * Standard berths are crew-only (/datum/outpost_berth/proc/allows_entry): only
 * the berthed ship's crew can send the car there, and they must still be in it
 * when it leaves. Anyone riding with them comes along as a guest.
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
	// OUTPOST FLOORS seam (voidcrew/modules/trade_floors)
	/// The leased floor this panel is on, or null
	var/datum/outpost_floor/floor
	/// world.time until which this panel sends the car to any floor (it was forced); written by floor_lift.dm
	var/forced_until = 0
	/// world.time before which forcing this panel again does nothing; written by floor_lift.dm
	var/force_ready_at = 0

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/outpost_elevator, 32)

/obj/machinery/outpost_elevator/Destroy()
	if(move_timer)
		deltimer(move_timer)
		move_timer = null
	if(berth?.panel == src)
		berth.panel = null
	berth = null
	if(floor?.panel == src) // OUTPOST FLOORS seam
		floor.panel = null
	floor = null
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
	if(floor) // OUTPOST FLOORS seam: a leased floor's id is 101 and up
		return floor.lift_id()
	if(berth)
		return berth.berth_number
	if(is_lobby)
		return 0
	return -1

/// The alcove turfs this panel teleports from.
/obj/machinery/outpost_elevator/proc/get_own_alcove()
	if(floor) // OUTPOST FLOORS seam
		return floor.alcove_turfs
	if(berth)
		return berth.alcove_turfs
	if(is_lobby)
		return outpost?.lobby_alcove_turfs
	return null

/obj/machinery/outpost_elevator/examine(mob/user)
	. = ..()
	if(floor) // OUTPOST FLOORS seam
		. += span_notice("The floor indicator reads: FLOOR [floor.number].")
		return
	var/floor_id = get_current_floor()
	if(istype(berth, /datum/outpost_berth/ship_bay))
		var/datum/outpost_berth/ship_bay/bay = berth
		. += span_notice("The floor indicator reads: SHIP BAY [bay.bay_number].")
	else if(floor_id > 0)
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
		for(var/i in 1 to outpost.berth_capacity())
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
				"locked" = !!(slot && !slot.allows_entry(user)),
			))
		var/obj/structure/overmap/dynamic/player_outpost/home = astype(outpost)
		if(home?.ship_bay_installed)
			for(var/i in 1 to length(home.bay_berths))
				var/datum/outpost_berth/ship_bay/bay = home.bay_berths[i]
				floors += list(list(
					// Negative IDs are display-only vacancies, never visit destinations.
					"id" = bay ? bay.berth_number : -i - 1,
					"name" = "Ship Bay [i]: [bay ? (bay.ship?.name || bay.status_text()) : "preparing"]",
					"occupied" = bay && length(bay.alcove_turfs) > 0,
					"your_ship" = !!(bay?.ship?.ship_team in user?.mind?.ship_teams),
				))
	// OUTPOST FLOORS seam: the leased floors this rider may visit, and no others (trade_floors/floor_lift.dm)
	if(outpost)
		floors += outpost.extra_floor_rows(user)
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
	if(!may_ride_to(floor_id, ui.user))
		balloon_alert(ui.user, outpost.lift_refusal_text(floor_id)) // OUTPOST FLOORS seam
		return TRUE
	moving = TRUE
	playsound(src, 'sound/machines/chime.ogg', 50, TRUE)
	move_timer = addtimer(CALLBACK(src, PROC_REF(complete_ride), floor_id, WEAKREF(ui.user)), OUTPOST_ELEVATOR_TRAVEL_TIME, TIMER_STOPPABLE)
	SStgui.update_uis(src)
	return TRUE

/// Whether this rider may send the car to the floor. Only a standard berth's own crew may go down to it.
/obj/machinery/outpost_elevator/proc/may_ride_to(floor_id, mob/rider)
	// OUTPOST FLOORS seam: the host decides (the berth rule is /obj/structure/overmap/proc/may_enter_floor())
	return outpost ? outpost.may_enter_floor(floor_id, rider) : TRUE

/**
 * The actual "ride": re-validates the destination (a berth can be torn down
 * during the travel delay), then moves the alcove's contents tile-for-tile.
 *
 * The rider who sent the car must still be in it and awake. Otherwise a stranger
 * could step in after a crew member pressed the button and ride down alone.
 */
/obj/machinery/outpost_elevator/proc/complete_ride(floor_id, datum/weakref/rider_ref)
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
	var/mob/living/rider = rider_ref?.resolve()
	if(!istype(rider) || rider.stat != CONSCIOUS || !(get_turf(rider) in own_alcove))
		rider = null
	if(!may_ride_to(floor_id, rider))
		playsound(src, 'sound/machines/buzz/buzz-two.ogg', 50, TRUE)
		say(outpost.lift_refusal_text(floor_id, TRUE)) // OUTPOST FLOORS seam (positional: an override may name it differently)
		SStgui.update_uis(src)
		return
	var/list/atom/movable/riders = list() // OUTPOST FLOORS seam: who rode, for on_lift_ride()
	for(var/i in 1 to length(own_alcove))
		var/turf/source_turf = own_alcove[i]
		var/turf/target_turf = destination[min(i, length(destination))]
		for(var/atom/movable/passenger as anything in source_turf.contents.Copy())
			if(passenger.anchored)
				continue
			if(outpost.lift_leaves_behind(passenger, floor_id, rider)) // OUTPOST FLOORS seam
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
			riders += passenger
	playsound(destination[1], 'sound/machines/ding.ogg', 50, TRUE)
	SStgui.update_uis(src)
	outpost.on_lift_ride(src, floor_id, rider, riders) // OUTPOST FLOORS seam

/// OUTPOST FLOORS seam: forcing the lift (trade_floors/floor_lift.dm). The host decides what an emag does;
/// on a host with no floors it does nothing.
/obj/machinery/outpost_elevator/emag_act(mob/user, obj/item/card/emag/emag_card)
	. = ..()
	if(outpost?.on_lift_emagged(src, user))
		return TRUE
