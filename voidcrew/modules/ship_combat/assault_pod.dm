// Assault Pods - boarding by way of somebody else's hull
//
// An orbital drop pod loaded into a launch tube stops being transport and starts
// being a weapon. The weapons officer aims the targeting camera at a tile on the
// enemy vessel and fires; the pod crosses the gap like a missile, cuts a hole
// through the plating and puts whoever is strapped inside on the far side of it.
//
// It is not ordnance. A pod that meets a live shield is a pod that dies against
// it - shields are the reason boarding parties wait for the guns to finish.
//
// Flow:
// 1. Drag a drop pod onto an assault pod tube (must be on the ship's exterior)
// 2. Boarders drag themselves onto the tube to climb in through the open hatch,
//    then seal it (pod interface, or a crowbar on the tube). Moving climbs back
//    out while the hatch is open. Sealing a crewed pod first and loading it
//    whole still works.
// 3. Tube is multitool-linked to the weapons system, same as a missile launcher
// 4. Operator enters the targeting camera, aims at the target hull, launches.
//    A tube only fires a sealed pod.

// ========== FLYING POD ==========

/// Global proc to create an assault pod in flight (called via timer from the tube)
/proc/create_assault_pod(turf/spawn_turf, turf/target, obj/structure/overmap/target_ship, obj/structure/overmap/ship/source_ship, obj/structure/closet/supplypod/drop_pod/pod)
	if(!spawn_turf || !target || QDELETED(pod))
		return
	new /obj/effect/ship_missile/assault_pod(
		spawn_turf,
		target,
		target_ship,
		source_ship,
		ASSAULT_POD_SHIELD_DAMAGE,
		0, // devastation
		0, // heavy
		ASSAULT_POD_IMPACT_LIGHT,
		0, // flame
		null, // icon state comes from the pod's own style
		pod,
	)

/**
 * A drop pod in flight between two ships.
 *
 * Rides the missile framework so it inherits everything that already knows how
 * to cross a reservation: hyperspace traits, the move loop, shield wall
 * interception, outpost shield envelopes. What it does on arrival is entirely
 * different - it cuts a doorway instead of making a crater.
 */
/obj/effect/ship_missile/assault_pod
	name = "assault pod"
	desc = "A boarding pod under power, crossing open space toward a hull."
	icon = 'voidcrew/icons/obj/supplypods.dmi'
	icon_state = "darkpod"
	pixel_x = -16 // 2x2 sprite
	pixel_y = -16
	impact_sound = 'sound/effects/explosion/explosion1.ogg'
	/// The pod we're carrying, riders and all
	var/obj/structure/closet/supplypod/drop_pod/pod
	/// Direction of travel, used to decide which way the breach cuts
	var/travel_dir

/obj/effect/ship_missile/assault_pod/Initialize(mapload, turf/target, obj/structure/overmap/target_ship_ref, obj/structure/overmap/ship/source_ship_ref, missile_damage, dev_range, heavy_range, light_range, flame_range, missile_icon, obj/structure/closet/supplypod/drop_pod/carried_pod)
	. = ..()

	travel_dir = dir

	// The pod sprite is a single-direction 64x64 pointing north, so it needs a
	// real rotation rather than the missile's directional icon states.
	if(target_turf)
		transform = matrix().Turn(get_angle(get_turf(src), target_turf))

	if(QDELETED(carried_pod))
		return
	pod = carried_pod
	pod.forceMove(src)
	// Riders watch the approach instead of the inside of a closet. get_riders()
	// rather than a contents loop so a mech pilot is a rider too - see drop_pod.dm.
	for(var/mob/living/rider in pod.get_riders())
		rider.reset_perspective(src)

/obj/effect/ship_missile/assault_pod/Destroy()
	// Never let riders die in nullspace because a timer or an admin deleted us.
	// This is the abnormal path, so the pod is set down rather than landed - the
	// landing sequence can sleep and Destroy() may not.
	if(!QDELETED(pod))
		var/turf/here = get_turf(src)
		if(here)
			var/list/riders = pod.get_riders()
			pod.forceMove(here)
			pod.set_anchored(TRUE)
			for(var/mob/living/rider in riders)
				rider.reset_perspective(null)
		else
			QDEL_NULL(pod)
	pod = null
	return ..()

/obj/effect/ship_missile/assault_pod/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	if(movement_dir)
		travel_dir = movement_dir
	return ..()

/// Pods are heavier and slower than ordnance - you can see one coming
/obj/effect/ship_missile/assault_pod/chase_target(atom/chasing)
	if(!isatom(chasing))
		return
	var/datum/move_loop/new_loop = GLOB.move_manager.move_towards(src, chasing, ASSAULT_POD_SPEED, FALSE, lifetime)
	if(new_loop)
		RegisterSignal(new_loop, COMSIG_MOVELOOP_STOP, PROC_REF(on_loop_stopped))

/obj/effect/ship_missile/assault_pod/impact()
	if(exploded)
		return

	// Outpost shield envelopes stop pods exactly like they stop ordnance
	if(try_outpost_shield_intercept(get_turf(src)))
		return

	var/turf/impact_turf = get_turf(src)
	if(!impact_turf)
		exploded = TRUE
		qdel(src)
		return

	exploded = TRUE

	playsound_ship(impact_turf, impact_sound, 80, TRUE, 12, target_ship)

	// Cut the hole deliberately rather than blasting one. An explosion large
	// enough to reliably open a hull is also large enough to kill everything
	// behind it, and the boarders have to be able to walk through what's left.
	var/turf/landing_turf = breach_hull(impact_turf)

	// Set the pod down before the shock goes off. Supplypods ignore explosions
	// and shield their contents, so landing first is what keeps the riders safe -
	// and it means nothing can delete us out from under the landing.
	var/obj/structure/closet/supplypod/drop_pod/landed_pod = pod
	land_pod(landing_turf)

	// The shock of the hit. Small on purpose: the hole is the damage.
	explosion(
		impact_turf,
		devastation_range = 0,
		heavy_impact_range = 0,
		light_impact_range = ASSAULT_POD_IMPACT_LIGHT,
		flame_range = 0,
		flash_range = ASSAULT_POD_IMPACT_LIGHT + 1,
		adminlog = TRUE,
		ignorecap = TRUE,
		silent = TRUE,
		explosion_cause = src,
	)

	ship_explosion_effects(impact_turf, target_ship)
	shake_camera_ship(impact_turf, 7, 3, 2, target_ship)

	if(target_ship)
		SEND_SIGNAL(target_ship, COMSIG_SHIP_HULL_HIT, impact_turf)
		// Turfs were destroyed, so NPC hulls need their mass recalculated
		SEND_SIGNAL(target_ship, COMSIG_SHIP_EXPLOSIVE_DAMAGE, impact_turf)
		SEND_SIGNAL(target_ship, COMSIG_SHIP_BOARDED, landed_pod, source_ship)
		var/obj/structure/overmap/ship/hit_vessel = target_ship
		if(istype(hit_vessel))
			hit_vessel.interrupt_autopilot("boarding pod impact")
			hit_vessel.ship_notify("HULL BREACH - boarding pod impact detected", "DAMAGE CONTROL", SHIP_NOTIFY_DANGER, 'voidcrew/sound/notify.ogg', 70)

	qdel(src)

/**
 * Cuts a hole from the impact point along the flight path.
 *
 * Returns the turf the pod comes to rest on: the first tile along the path it
 * can actually sit in. Walks at most ASSAULT_POD_BREACH_DEPTH blocked tiles, so
 * a double hull still lets the pod through and a warren of internal walls does
 * not turn one pod into a tunnelling machine.
 */
/obj/effect/ship_missile/assault_pod/proc/breach_hull(turf/impact_turf)
	var/breach_dir = travel_dir || dir
	var/turf/current = impact_turf

	for(var/depth in 1 to ASSAULT_POD_BREACH_DEPTH + 1)
		if(!is_pod_blocked(current))
			return current
		if(depth > ASSAULT_POD_BREACH_DEPTH)
			break
		if(!breach_turf(current))
			break // armour we can't cut
		var/turf/next_turf = get_step(current, breach_dir)
		if(!next_turf)
			return current
		current = next_turf

	// Out of bite, or something refused to open. Settle for the deepest tile we
	// managed to open, then the impact tile, then the space we flew in from -
	// anything rather than dropping riders inside a wall.
	for(var/turf/candidate in list(current, impact_turf, get_step(impact_turf, REVERSE_DIR(breach_dir))))
		if(!is_pod_blocked(candidate))
			return candidate
	return impact_turf

/// Whether a pod could come to rest on this tile
/obj/effect/ship_missile/assault_pod/proc/is_pod_blocked(turf/checked)
	if(isnull(checked))
		return TRUE
	if(checked.density)
		return TRUE
	for(var/obj/blocker in checked)
		if(!blocker.density)
			continue
		// Ordnance in flight is dense but doesn't obstruct a landing - and one of
		// the tiles we consider is the one we're standing on
		if(istype(blocker, /obj/effect/ship_missile))
			continue
		return TRUE
	return FALSE

/**
 * Opens a single blocked tile. Returns TRUE if the pod can pass through it now.
 *
 * Indestructible plating (trader outposts, admin structures) refuses outright -
 * the pod stops on the outside face rather than quietly ignoring the flag.
 */
/obj/effect/ship_missile/assault_pod/proc/breach_turf(turf/target)
	if(isnull(target))
		return FALSE
	if(target.resistance_flags & INDESTRUCTIBLE)
		return FALSE

	// Windows, grilles, airlocks, anything dense standing in the doorway
	for(var/obj/blocker in target)
		if(!blocker.density)
			continue
		if(blocker.resistance_flags & INDESTRUCTIBLE)
			return FALSE
		blocker.take_damage(ASSAULT_POD_BREACH_DAMAGE, BRUTE, BOMB)

	if(iswallturf(target))
		var/turf/closed/wall/hull = target
		hull.dismantle_wall(TRUE, TRUE)
	else if(target.density)
		target.ScrapeAway()

	return !is_pod_blocked(target)

/// Sets the pod down and hands it back to the normal supplypod landing sequence
/obj/effect/ship_missile/assault_pod/proc/land_pod(turf/landing_turf)
	if(QDELETED(pod))
		return
	// Deleting the pod strands its riders in the contents of a deleted object, which
	// is nullspace with extra steps. Anywhere real beats that, so fall back to the
	// tile we are standing on before giving up.
	if(!landing_turf)
		landing_turf = get_turf(src)
	if(!landing_turf)
		stack_trace("assault pod tried to land with no turf anywhere; riders left aboard")
		return

	var/list/riders = pod.get_riders()
	pod.forceMove(landing_turf)
	pod.set_anchored(TRUE)
	for(var/mob/living/rider in riders)
		rider.reset_perspective(null)

	// The armoured pod's whole selling point is that it doesn't pop its own hatch
	// on arrival - you choose when to be seen.
	if(istype(pod, /obj/structure/closet/supplypod/drop_pod/advanced))
		var/obj/structure/closet/supplypod/drop_pod/advanced/armoured = pod
		armoured.ignore_next_open = TRUE

	pod.preOpen()
	pod = null

/// A shield stops the pod dead. Everyone strapped in dies with it.
/obj/effect/ship_missile/assault_pod/shield_impact()
	if(exploded)
		return

	var/turf/impact_loc = get_turf(src)
	exploded = TRUE

	playsound_ship(impact_loc, impact_sound, 80, TRUE, 12, target_ship)

	if(!QDELETED(pod))
		// Everyone aboard, mech pilots and locker stowaways included - a shield does
		// not care which box inside the pod you were sitting in.
		for(var/mob/living/rider in pod.get_riders())
			rider.reset_perspective(null)
			rider.investigate_log("was killed by an assault pod striking [target_ship?.name || "a"] shield.", INVESTIGATE_DEATHS)
			if(impact_loc)
				rider.forceMove(impact_loc)
			rider.gib(DROP_ALL_REMAINS)
		QDEL_NULL(pod)

	explosion(
		impact_loc,
		devastation_range = 0,
		heavy_impact_range = 0,
		light_impact_range = 2,
		flame_range = 0,
		flash_range = 4,
		adminlog = TRUE,
		ignorecap = TRUE,
		silent = TRUE,
		explosion_cause = src,
	)

	ship_explosion_effects(impact_loc, target_ship)
	shake_camera_ship(impact_loc, 7, 3, 2, target_ship)

	qdel(src)

// ========== LAUNCH TUBE ==========

/obj/machinery/ship_combat/pod_launcher
	name = "assault pod tube"
	desc = "A hull-mounted tube for throwing a crewed drop pod at somebody else's ship. Drag a pod onto it to load, drag yourself onto it to climb in. Link it to a weapons system with a multitool. Use a wrench to secure or unsecure, or unwrench it and drag it onto a hull wall to sink it into the plating."
	icon = 'voidcrew/icons/obj/machines/pod_launcher.dmi'
	icon_state = "unloaded"
	density = TRUE
	anchored = TRUE
	dir = 4
	drag_slowdown = 2 // Heavy machinery
	power_channel = AREA_USAGE_EQUIP
	idle_power_usage = 0
	circuit = /obj/item/circuitboard/machine/ship_combat/pod_launcher
	pixel_x = -16
	pixel_y = -16
	// A tube has to sit against the outside of the hull, and on most ships the only
	// tile that qualifies is one you'd have to breach your own compartment to make.
	// The other two mounts solve that by going into the plating; so does this one.
	// Everything that hands something back out of the tube goes through
	// get_disembark_turf() so it lands on a deck tile rather than inside the wall.
	wall_mountable = TRUE
	/// The pod currently in the tube
	var/obj/structure/closet/supplypod/drop_pod/loaded_pod
	/// Reference to our linked combat console
	var/datum/weakref/linked_console_ref
	/// Our unique ID for console linking
	var/tube_id
	/// Trigger pulled, pod not yet handed to the flight object. The pod is still
	/// racked for this window; the tube just can't be fired again during it.
	var/launching = FALSE

/obj/machinery/ship_combat/pod_launcher/Initialize(mapload)
	. = ..()
	tube_id = "[rand(1000, 9999)]"
	name = "[initial(name)] ([tube_id])"
	// Try to auto-link to a combat console on the same ship after a short delay
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/pod_launcher/Destroy()
	// A tube being taken apart with somebody inside spits the pod out rather
	// than deleting them with it. Forced: there is no "leave it racked" option left
	// once the machine is going away.
	eject_pod(force = TRUE)
	loaded_pod = null
	unlink_console()
	return ..()

// Override shuttle rotation to prevent pixel offset rotation
// For centered 64x64 sprites, offset should always be -16, -16
/obj/machinery/ship_combat/pod_launcher/shuttleRotate(rotation, params)
	params &= ~ROTATE_OFFSET
	return ..()

/obj/machinery/ship_combat/pod_launcher/examine(mob/user)
	. = ..()
	. += span_notice("Tube ID: [tube_id]")
	if(loaded_pod)
		. += span_notice("Loaded: [loaded_pod.name] - hatch [loaded_pod.opened ? "open" : "sealed"].")
		var/rider_count = length(loaded_pod.get_riders())
		if(rider_count)
			. += span_warning("Occupancy: [rider_count].")
		if(loaded_pod.opened)
			. += span_notice("Drag yourself onto the tube to climb into the pod. Crowbar the tube to seal the hatch. It only fires sealed.")
		else
			. += span_notice("Crowbar the tube to open the pod's hatch. Alt-click to access the pod's interface.")
	else
		. += span_warning("Empty. Drag a drop pod onto the tube to load it.")
	if(!is_on_exterior())
		. += span_warning("NOT ON EXTERIOR - must be against the outside of the hull to launch!")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a weapons system. Use a multitool to link.")

/obj/machinery/ship_combat/pod_launcher/update_icon_state()
	. = ..()
	if(!loaded_pod)
		icon_state = "unloaded"
	else
		icon_state = loaded_pod.opened ? "loaded_open" : "loaded"

// ========== LOADING ==========

/obj/machinery/ship_combat/pod_launcher/mouse_drop_receive(atom/dropped, mob/user, params)
	if(isliving(dropped))
		try_board(dropped, user)
		return
	var/obj/structure/closet/supplypod/drop_pod/pod = dropped
	if(!istype(pod))
		return
	if(!Adjacent(user) || !user.Adjacent(pod))
		to_chat(user, span_warning("You need to be next to both the pod and the tube!"))
		return
	if(machine_stat & BROKEN)
		to_chat(user, span_warning("[src] is broken!"))
		return
	if(!anchored)
		to_chat(user, span_warning("[src] isn't secured to the deck!"))
		return
	if(loaded_pod)
		to_chat(user, span_warning("[src] already has a pod loaded!"))
		return
	if(pod.used)
		to_chat(user, span_warning("[pod] has already been fired - its drive is spent."))
		return

	to_chat(user, span_notice("You begin loading [pod] into [src]..."))
	playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, TRUE)

	if(!do_after(user, ASSAULT_POD_LOAD_TIME, src))
		to_chat(user, span_warning("You stop loading the pod."))
		return

	// Verify everything is still valid
	if(QDELETED(pod) || !Adjacent(user) || !user.Adjacent(pod))
		return
	if(loaded_pod || pod.used)
		return

	pod.set_anchored(FALSE)
	pod.forceMove(src)
	loaded_pod = pod
	// A pod destroyed in the rack has to clear the tube, or it reports itself
	// loaded with nothing in it until the reference is collected
	RegisterSignal(pod, COMSIG_QDELETING, PROC_REF(on_pod_deleted))

	user.visible_message(
		span_notice("[user] loads [pod] into [src]."),
		span_notice("You load [pod] into [src]."),
	)
	for(var/mob/living/rider in pod)
		to_chat(rider, span_userdanger("The pod slides into a launch tube and locks. You are now ordnance."))
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)
	update_appearance()

// ========== BOARDING ==========

/**
 * Drag a mob onto the tube to put them in the loaded pod through its open hatch.
 *
 * This is the normal way aboard: rack an open pod, climb in, seal up. It beats
 * the old dance of sealing people into a pod on the deck and then dragging the
 * whole thing into the tube with them rattling around inside.
 */
/obj/machinery/ship_combat/pod_launcher/proc/try_board(mob/living/target, mob/living/user)
	if(!istype(user) || !user.can_perform_action(src))
		return
	if(machine_stat & BROKEN)
		to_chat(user, span_warning("[src] is broken!"))
		return
	if(!loaded_pod)
		to_chat(user, span_warning("There's no pod in the tube to climb into!"))
		return
	if(!loaded_pod.opened)
		to_chat(user, span_warning("The pod's hatch is sealed! Crowbar the tube or use the pod's interface to open it."))
		return
	var/self_boarding = (target == user)
	if(!self_boarding && !target.Adjacent(src))
		to_chat(user, span_warning("[target] needs to be next to the tube!"))
		return
	if(!loaded_pod.insertion_allowed(target))
		to_chat(user, span_warning("[target] won't fit in the pod."))
		return

	to_chat(user, self_boarding ? span_notice("You start climbing into [loaded_pod]...") : span_notice("You start stuffing [target] into [loaded_pod]..."))
	if(!do_after(user, loaded_pod.enter_time, src))
		return
	// The pod may have been sealed, fired or ejected during the climb
	if(QDELETED(loaded_pod) || !loaded_pod.opened || !user.Adjacent(src))
		return
	if(!self_boarding && !target.Adjacent(src))
		return
	if(!loaded_pod.insertion_allowed(target))
		return

	if(!isnull(target.buckled))
		target.buckled.unbuckle_mob(target, force = TRUE)
	target.forceMove(loaded_pod)
	user.visible_message(
		span_notice("[user] [self_boarding ? "climbs into" : "stuffs [target] into"] [src]."),
		span_notice("You [self_boarding ? "climb into" : "stuff [target] into"] [src]."),
	)
	if(!self_boarding)
		log_combat(user, target, "stuffed", addition = "inside of [src]")
	to_chat(target, span_notice("You're in the pod. Seal the hatch through the pod's interface, or move to climb back out."))
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)

// ========== UNLOADING ==========

/obj/machinery/ship_combat/pod_launcher/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return

	if(!loaded_pod)
		to_chat(user, span_warning("The tube is empty."))
		return

	to_chat(user, span_notice("You begin unloading the pod from [src]..."))
	if(!do_after(user, ASSAULT_POD_LOAD_TIME, src))
		return
	if(!loaded_pod)
		return

	if(!eject_pod())
		to_chat(user, span_warning("There's no clear tile beside [src] to set the pod down on."))
		return
	user.visible_message(
		span_notice("[user] unloads a pod from [src]."),
		span_notice("You unload the pod from [src]."),
	)

/**
 * Drops the loaded pod back out of the tube. Returns TRUE if the rack is now empty.
 *
 * A tube sunk into hull plating sits on a closed turf, so the pod cannot simply go
 * to drop_location() - that would shove it, and anyone aboard, into the wall.
 * `force` is for the paths that have no way to back out (deconstruction, Destroy):
 * they fall back to the tube's own tile, which is at least a real turf.
 */
/obj/machinery/ship_combat/pod_launcher/proc/eject_pod(force = FALSE)
	if(QDELETED(loaded_pod))
		loaded_pod = null
		update_appearance()
		return TRUE
	var/turf/rack_exit = get_disembark_turf(loaded_pod)
	if(!rack_exit && force)
		rack_exit = get_turf(src)
	if(!rack_exit)
		return FALSE
	release_pod().forceMove(rack_exit)
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)
	update_appearance()
	return TRUE

/// Hands the loaded pod back to the caller and empties the rack
/obj/machinery/ship_combat/pod_launcher/proc/release_pod()
	var/obj/structure/closet/supplypod/drop_pod/released = loaded_pod
	if(released)
		UnregisterSignal(released, COMSIG_QDELETING)
	loaded_pod = null
	return released

/obj/machinery/ship_combat/pod_launcher/proc/on_pod_deleted(datum/source)
	SIGNAL_HANDLER
	loaded_pod = null
	update_appearance()

// Wrench to anchor/unanchor
/obj/machinery/ship_combat/pod_launcher/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	if(loaded_pod)
		to_chat(user, span_warning("Unload the pod first!"))
		return
	default_unfasten_wrench(user, tool)
	invalidate_exterior_cache() // Position may have changed
	eject_from_wall(user) // Loose inside hull plating is a dead end - pop it onto the deck
	return ITEM_INTERACT_SUCCESS

/obj/machinery/ship_combat/pod_launcher/after_wall_mount(mob/user)
	attempt_auto_link()

// Alt+click: pod interface when a pod is racked, rotate when unwrenched
/obj/machinery/ship_combat/pod_launcher/click_alt(mob/user)
	if(!user.can_perform_action(src, NEED_HANDS))
		return CLICK_ACTION_BLOCKING
	if(anchored)
		if(launching)
			balloon_alert(user, "launch in progress")
			return CLICK_ACTION_BLOCKING
		if(loaded_pod)
			// The racked pod can't be clicked directly, so the tube hands its
			// interface through
			loaded_pod.ui_interact(user)
			return CLICK_ACTION_SUCCESS
		to_chat(user, span_warning("Unwrench [src] first to rotate it!"))
		return CLICK_ACTION_BLOCKING
	if(loaded_pod)
		to_chat(user, span_warning("Unload the pod first!"))
		return CLICK_ACTION_BLOCKING
	setDir(turn(dir, -90))
	balloon_alert(user, "rotated [dir2text(dir)]")
	return CLICK_ACTION_SUCCESS

/obj/machinery/ship_combat/pod_launcher/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	// Multitool linking - store self in buffer
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.buffer = src
		balloon_alert(user, "tube buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a weapons system to link."))
		return TRUE

	// Crowbar works the loaded pod's hatch - the pod itself is out of reach
	// inside the machine, so the tube proxies it. Panel open falls through to
	// deconstruction as usual (which is blocked while loaded anyway).
	if(W.tool_behaviour == TOOL_CROWBAR && loaded_pod && !panel_open)
		if(launching)
			balloon_alert(user, "launch in progress")
			return TRUE
		if(loaded_pod.opened)
			loaded_pod.setClosed()
			balloon_alert(user, "hatch sealed")
		else
			loaded_pod.open_pod(loaded_pod)
			balloon_alert(user, "hatch opened")
		return TRUE

	// Standard deconstruction - only allow if empty
	if(!loaded_pod)
		if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
			return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

/obj/machinery/ship_combat/pod_launcher/on_deconstruction(disassembled)
	// The machine is going away either way, so take the tube's own tile over leaving
	// the pod inside a frame that is about to be dumped.
	eject_pod(force = TRUE)

// ========== CONSOLE LINKING ==========

/// Links this tube to a combat console
/obj/machinery/ship_combat/pod_launcher/proc/link_console(obj/machinery/computer/camera_advanced/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))
	return TRUE

/// Unlinks from the current console
/obj/machinery/ship_combat/pod_launcher/proc/unlink_console()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		UnregisterSignal(console, COMSIG_QDELETING)
	linked_console_ref = null

/obj/machinery/ship_combat/pod_launcher/proc/on_console_deleted(datum/source)
	SIGNAL_HANDLER
	linked_console_ref = null

/// Attempts to auto-link to a combat console on the same ship
/obj/machinery/ship_combat/pod_launcher/proc/attempt_auto_link()
	if(!SSovermap?.initialized)
		return
	if(linked_console_ref?.resolve())
		return
	if(!is_on_exterior())
		return

	var/area/our_area = get_area(src)
	if(!our_area)
		return

	var/obj/structure/overmap/ship/our_ship
	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		if(our_area in S.shuttle.shuttle_areas)
			our_ship = S
			break

	if(!our_ship)
		return

	for(var/area/ship_area in our_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			if(!link_console(console))
				continue
			var/already_linked = FALSE
			for(var/datum/weakref/ref in console.linked_pod_tubes)
				if(ref.resolve() == src)
					already_linked = TRUE
					break
			if(!already_linked)
				console.linked_pod_tubes += WEAKREF(src)
			return

// ========== FIRING ==========

/// Whether the tube can launch. Pass the console's locked target so the
/// yellow-zone siege exception can be evaluated the same way missiles do it.
/obj/machinery/ship_combat/pod_launcher/proc/can_fire(obj/structure/overmap/locked_target = null)
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	// Already firing: the pod is still racked for the launch delay, and firing the
	// same tube twice in that window would put two flight objects on one pod.
	if(launching)
		return FALSE
	if(QDELETED(loaded_pod))
		return FALSE
	// A pod that got opened in the tube isn't going anywhere sealed
	if(loaded_pod.opened)
		return FALSE
	// One-shot drives. A spent pod is cargo, not ordnance.
	if(loaded_pod.used)
		return FALSE
	if(!is_on_exterior())
		return FALSE
	if(!SSovermap_zones.weapons_allowed_at(src) && !is_siege_shot_allowed(locked_target))
		return FALSE
	return TRUE

/// Boarding a raidable player outpost is allowed outside the red zone, on the
/// same terms as a siege missile. See missile_launcher.dm for the reasoning.
/obj/machinery/ship_combat/pod_launcher/proc/is_siege_shot_allowed(obj/structure/overmap/locked_target)
#ifdef PLAYER_OUTPOST_YELLOW_SIEGE_ENABLED
	if(!istype(locked_target, /obj/structure/overmap/dynamic/player_outpost))
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/outpost = locked_target
	if(!outpost.raidable)
		return FALSE
	var/obj/structure/overmap/ship/our_ship = get_ship_from_atom(src)
	if(!our_ship)
		return FALSE
	var/zone_type = SSovermap_zones.get_zone_type(get_turf(our_ship))
	return zone_type == ZONE_YELLOW || zone_type == ZONE_RED
#else
	return FALSE
#endif

/**
 * Throws the loaded pod at the target turf.
 *
 * Mirrors the missile launcher: work out where on the target's reservation the
 * pod should enter from, play the launch out of this tube, then put the real
 * object in flight once the visual has cleared the screen.
 */
/obj/machinery/ship_combat/pod_launcher/proc/fire(turf/target, obj/structure/overmap/target_ship, obj/structure/overmap/ship/source_ship, mob/user, approach_dir = null)
	if(!can_fire(target_ship))
		return FALSE

	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Where the pod enters the target's reservation from. A missile that can't work
	// this out falls back to spawning on top of the target turf; a crewed pod must
	// not, because that pod never flies - it sits inside the enemy hull for its whole
	// 30-second lifetime with the boarding party locked in it. Refuse instead.
	var/turf/spawn_turf = get_missile_spawn_turf(target, target_ship, approach_dir)
	if(!spawn_turf || spawn_turf == target)
		if(user)
			to_chat(user, span_warning("No approach lane onto [target_ship ? target_ship.name : "the target"] - the pod has nowhere to launch from. Pick another approach direction or another aim point."))
		return FALSE

	// The pod stays racked, on a real turf, until complete_launch() hands it to the
	// flight object. It used to spend this window in nullspace, and /mob/living/Life()
	// teleports any client mob it finds without a turf into the CentCom error room -
	// which is where boarding parties were arriving instead of on the target hull.
	var/obj/structure/closet/supplypod/drop_pod/launching_pod = loaded_pod
	launching = TRUE

	use_energy(ASSAULT_POD_LAUNCH_POWER)

	playsound(src, 'voidcrew/sound/machines/rocket/rocket_launch.ogg', 100, TRUE, extrarange = 20, pressure_affected = FALSE)

	// Launch visual out of the tube, same offsets the missile launcher uses
	var/offset_x = -16
	var/offset_y = -16
	switch(dir)
		if(NORTH)
			offset_x = -16
			offset_y = 0
		if(SOUTH)
			offset_x = -16
			offset_y = -32
		if(EAST)
			offset_x = 0
			offset_y = -16
		if(WEST)
			offset_x = -32
			offset_y = -16
	new /obj/effect/temp_visual/missile_launch_visual(get_turf(src), dir, offset_x, offset_y)

	visible_message(span_danger("[src] launches [launching_pod]!"))
	for(var/mob/living/rider in launching_pod.get_riders())
		to_chat(rider, span_userdanger("The tube fires. The hull drops away behind you."))
	if(user)
		to_chat(user, span_notice("Pod away! Target: [target_ship ? target_ship.name : "unknown"]"))

	addtimer(CALLBACK(src, PROC_REF(complete_launch), spawn_turf, target, target_ship, source_ship), ASSAULT_POD_LAUNCH_DELAY)

	update_appearance()
	return TRUE

/**
 * Second half of a launch: the pod leaves the tube and goes into flight here.
 *
 * Split from fire() so that the pod - and everyone strapped into it - keeps a turf
 * for the whole launch animation. Anything living that spends a mob tick with no
 * turf is picked up by /mob/living/Life() and teleported to the CentCom error room,
 * so nullspace transit is never an option for a crewed object.
 */
/obj/machinery/ship_combat/pod_launcher/proc/complete_launch(turf/spawn_turf, turf/target, obj/structure/overmap/target_ship, obj/structure/overmap/ship/source_ship)
	launching = FALSE
	if(QDELETED(loaded_pod))
		update_appearance()
		return

	var/obj/structure/closet/supplypod/drop_pod/launched = release_pod()
	launched.used = TRUE
	create_assault_pod(spawn_turf, target, target_ship, source_ship, launched)

	// The flight object pulls the pod into its own contents on creation. If it never
	// got made - target gone, spawn turf gone - the pod is still sitting in the tube,
	// and a sealed pod inside a machine that now reports itself empty is a coffin.
	if(!QDELETED(launched) && launched.loc == src)
		launched.used = FALSE
		// get_turf(src) as the last resort: a wall-sunk tube with nothing open around
		// it is still better than nullspace, which is what sent riders to the error room.
		launched.forceMove(get_disembark_turf(launched) || get_turf(src))
		visible_message(span_warning("[src] loses the firing solution and cycles [launched] back out."))
		for(var/mob/living/rider in launched.get_riders())
			to_chat(rider, span_warning("The launch aborts. The tube spits the pod back onto the deck."))

	update_appearance()

/// Returns status info for the combat console UI
/obj/machinery/ship_combat/pod_launcher/proc/get_status(obj/structure/overmap/locked_target = null)
	var/on_ext = is_on_exterior()
	var/riders = loaded_pod ? length(loaded_pod.get_riders()) : 0
	return list(
		"id" = tube_id,
		"name" = name,
		"loaded" = loaded_pod ? 1 : 0,
		"pod_name" = loaded_pod ? loaded_pod.name : null,
		"occupants" = riders,
		"sealed" = (loaded_pod && !loaded_pod.opened) ? 1 : 0,
		"ready" = can_fire(locked_target),
		"on_exterior" = on_ext,
		"enabled" = on_ext && anchored && !(machine_stat & (BROKEN|NOPOWER)),
	)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/pod_launcher
	name = "Assault Pod Tube"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/ship_combat/pod_launcher
	req_components = list(
		/datum/stock_part/servo = 2,
		/datum/stock_part/capacitor = 1,
	)
