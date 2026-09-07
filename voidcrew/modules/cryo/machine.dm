//Cryopods themselves.
/obj/machinery/cryopod
	name = "cryogenic freezer"
	desc = "Suited for Cyborgs and Humanoids, the pod is a safe place for personnel affected by the Space Sleep Disorder to get some rest."
	icon = 'voidcrew/modules/cryo/icons/cryogenic.dmi'
	icon_state = "cryopod-open"
	density = TRUE
	anchored = TRUE
	state_open = TRUE
	resistance_flags = INDESTRUCTIBLE|LAVA_PROOF|FIRE_PROOF|UNACIDABLE|ACID_PROOF
	// Leaving the round cannot depend on the hull still having power - a crew stranded on a
	// dead ship is exactly who needs the pod. See voidcrew/modules/cryo/despawn.dm.
	interaction_flags_machine = parent_type::interaction_flags_machine | INTERACT_MACHINE_OFFLINE

	///The icon state while the machine is closed.
	var/close_state = "cryopod"

	///The ship we're connected to.
	var/obj/docking_port/mobile/voidcrew/linked_ship

/obj/machinery/cryopod/Initialize(mapload)
	. = ..()
	// Pods created after their ship has finished loading (admin-spawned, etc.) never
	// get connect_to_shuttle(), so resolve our ship from the area we're standing in.
	if(!mapload && !linked_ship)
		relink_to_ship()

/obj/machinery/cryopod/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	. = ..()
	if(!istype(port))
		return FALSE
	if(linked_ship && linked_ship != port)
		linked_ship.spawn_points -= src
	if(linked_outpost)
		linked_outpost.resident_pods -= src
		linked_outpost = null
	linked_ship = port
	linked_ship.spawn_points |= src

/obj/machinery/cryopod/Destroy()
	if(linked_outpost)
		linked_outpost.resident_pods -= src
		linked_outpost = null
	if(linked_ship)
		linked_ship.spawn_points -= src
		linked_ship = null
	return ..()

/**
 * Swaps our spawn-point registration to the ship we're currently standing on,
 * or drops it entirely if we're not on a voidcrew ship.
 */
/obj/machinery/cryopod/proc/relink_to_ship()
	var/area/shuttle/voidcrew/current_area = get_area(src)
	var/obj/docking_port/mobile/voidcrew/new_ship = istype(current_area) ? current_area.shuttle_port : null
	var/obj/structure/overmap/dynamic/player_outpost/new_outpost = new_ship ? null : get_outpost_from_atom(src)
	if(linked_outpost != new_outpost)
		if(linked_outpost)
			linked_outpost.resident_pods -= src
		linked_outpost = new_outpost
		if(linked_outpost)
			linked_outpost.resident_pods |= src
	if(new_ship == linked_ship)
		return
	if(linked_ship)
		linked_ship.spawn_points -= src
	linked_ship = null
	if(new_ship)
		linked_ship = new_ship
		linked_ship.spawn_points |= src

/obj/machinery/cryopod/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	// Keep the registration pointed at whatever ship we're actually on, so a pod dragged
	// off-ship stops spawning joiners for its old ship. Safe mid-shuttle-move: turfs are
	// transferred into the ship's area before their contents move, so get_area() stays accurate.
	relink_to_ship()

/obj/machinery/cryopod/examine(mob/user)
	. = ..()
	. += span_notice("Its floor bolts can be [anchored ? "loosened" : "tightened"] with a wrench.")
	. += span_notice("Climbing back in - click it, or drag yourself onto it - puts you back into cryosleep and ends your round. Everything you are carrying is stored with you.")

/obj/machinery/cryopod/wrench_act(mob/living/user, obj/item/tool)
	if(occupant || arrival_reserved)
		balloon_alert(user, "someone inside!")
		return ITEM_INTERACT_BLOCKING
	if(!crew_can_modify(user))
		balloon_alert(user, "ship crew only!")
		return ITEM_INTERACT_BLOCKING
	if(default_unfasten_wrench(user, tool) == SUCCESSFUL_UNFASTEN)
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/**
 * Whether the given mob may bolt or unbolt this pod. Restricted to the crew of
 * the ship the pod belongs to; pods with no linked ship (dragged onto a planet,
 * etc.) or on abandoned ships are fair game for anyone.
 */
/obj/machinery/cryopod/proc/crew_can_modify(mob/living/user)
	relink_to_ship()
	if(linked_outpost)
		return linked_outpost.is_resident(user) || linked_outpost.can_build(user)
	var/obj/structure/overmap/ship/owner = linked_ship?.current_ship
	if(!owner || owner.abandoned)
		return TRUE
	if(!user.mind)
		return FALSE
	return (user.mind in owner.ship_team?.members)

/obj/machinery/cryopod/JoinPlayerHere(mob/joining_mob, buckle)
	. = ..()
	close_machine(joining_mob)

/obj/machinery/cryopod/open_machine(drop = TRUE, density_to_set = FALSE)
	icon_state = initial(icon_state)
	// Crew are equipped by their job while still sealed in here, so nothing they are
	// carrying can see a turf and every light they own resolves its holder to null.
	// That gear doesn't move when they climb out, so give it its bearings on the way.
	var/atom/movable/waking = occupant
	. = ..()
	waking?.recheck_contained_lights()

/obj/machinery/cryopod/close_machine(mob/living/carbon/user, density_to_set = TRUE)
	to_chat(user, span_boldnotice("You begin to wake from cryosleep..."))
	icon_state = close_state
	user.SetStun(5 SECONDS)
	return ..()

/obj/machinery/cryopod/container_resist_act(mob/living/user)
	visible_message(
		span_notice("[occupant] emerges from [src]!"),
		span_notice("You climb out of [src]!"),
	)
	open_machine()

/obj/machinery/cryopod/relaymove(mob/user)
	container_resist_act(user)
