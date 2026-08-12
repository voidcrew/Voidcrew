/**
 * Ship-scoped port of TG's Radiation Leak (code/modules/events/radiation_leak.dm).
 *
 * A machine aboard the target ship starts venting polonium and mutagen smoke and
 * irradiating everything near it. The crew stop it by working out which tool it wants
 * (the machine's examine text says) and spending thirty seconds on it, otherwise it
 * runs for about five minutes and then settles on its own.
 *
 * The only structural change from the original is how the machine is chosen. TG scans
 * near a random entry in GLOB.generic_event_spawns, which spans every loaded z-level and
 * would happily pick a machine on a ruin, an outpost or another crew's hull. Here the
 * search runs over this ship's own machine list, preferring one near a mapper-placed
 * marker aboard when the hull has any.
 */
/datum/round_event_control/voidcrew/radiation_leak
	name = "Radiation Leak"
	typepath = /datum/round_event/voidcrew/radiation_leak
	// Admin-only. Cut from the ambient roster by design decision, not because the event is
	// badly built, it telegraphs its compartment, its examine text names the tool that
	// fixes it, and thirty seconds of work ends it early. What it does not have is a way
	// to not happen: the radiation is already in the room the crew works in, and the toxin
	// damage and mutations it hands out on the way to the fix outlast the event itself.
	weight = 0
	max_occurrences = 0
	earliest_start = 10 MINUTES
	category = EVENT_CATEGORY_ENGINEERING
	description = "A machine aboard the target ship starts leaking radiation until it is repaired."
	/// Radiation is survivable by walking away from it, and the fix takes thirty seconds
	/// standing next to the source. Both need a hull with more than one room in it.
	min_ship_mass = SHIP_MASS_SMALL
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 7

/datum/round_event_control/voidcrew/radiation_leak/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	return length(get_leak_candidates(ship)) > 0

/**
 * Machines aboard the ship that can plausibly spring a leak, using the original's filter:
 * powered, dense (or a vent/scrubber, which TG keeps because it is funny), visible, not
 * under the floor, and atmos-passable so the smoke has somewhere to go.
 */
/datum/round_event_control/voidcrew/radiation_leak/proc/get_leak_candidates(obj/structure/overmap/ship/ship)
	var/list/candidates = list()
	if(QDELETED(ship) || !ship.shuttle)
		return candidates
	for(var/obj/machinery/sick_device as anything in ship.get_ship_machines(/obj/machinery))
		if(sick_device.use_power == NO_POWER_USE)
			continue
		if(!sick_device.density && !istype(sick_device, /obj/machinery/atmospherics/components/unary))
			continue
		if(sick_device.invisibility || !sick_device.alpha || !sick_device.mouse_opacity)
			continue
		if(sick_device.IsObscured())
			continue
		if(sick_device.can_atmos_pass() != ATMOS_PASS_YES)
			continue
		candidates += sick_device
	return candidates

/datum/round_event/voidcrew/radiation_leak
	start_when = 1
	announce_when = 10
	end_when = 150
	fakeable = FALSE
	/// Weakref to the machine spitting out rads.
	var/datum/weakref/picked_machine_ref
	/// Signals added to the picked machine, cleared on end.
	var/list/signals_to_add

/datum/round_event/voidcrew/radiation_leak/setup()
	if(!target_valid())
		kill()
		return

	var/datum/round_event_control/voidcrew/radiation_leak/leak_control = control
	if(!istype(leak_control))
		kill()
		return
	var/list/candidates = leak_control.get_leak_candidates(target_ship)
	if(!length(candidates))
		kill()
		return

	// If the hull has markers, leak from something near one, that is what they are for.
	// Otherwise any eligible machine aboard will do.
	var/list/markers = target_ship.get_ship_event_spawns()
	if(length(markers))
		var/list/near_marker = list()
		for(var/obj/effect/landmark/event_spawn/marker as anything in markers)
			for(var/obj/machinery/candidate as anything in candidates)
				if(get_dist(marker, candidate) <= 3)
					near_marker += candidate
		if(length(near_marker))
			candidates = near_marker

	picked_machine_ref = WEAKREF(pick(candidates))

/datum/round_event/voidcrew/radiation_leak/announce(fake)
	if(!target_valid())
		return
	var/obj/machinery/the_source_of_our_problems = picked_machine_ref?.resolve()
	var/area/location_descriptor = the_source_of_our_problems ? get_area(the_source_of_our_problems) : null
	target_ship.ship_event_announce(
		"A radiation leak has been detected in [location_descriptor?.name || "an unknown compartment"]. \
		Clear the area. Our [pick("readings", "sensors", "diagnostics", "best guess")] say a machine in there is causing it. Repair it and the leak stops.",
		"Radiation Alert",
	)

/datum/round_event/voidcrew/radiation_leak/start()
	if(!target_valid())
		return
	var/obj/machinery/the_source_of_our_problems = picked_machine_ref?.resolve()
	// The machine can be deconstructed, destroyed or carried off between setup and now.
	if(QDELETED(the_source_of_our_problems) || !target_ship.is_aboard(the_source_of_our_problems))
		kill()
		return

	var/list/how_do_we_fix_it = list(
		"wrenching a few valves" = TOOL_WRENCH,
		"tightening its bolts" = TOOL_WRENCH,
		"crowbaring its panel [pick("down", "up")]" = TOOL_CROWBAR,
		"tightening some screws" = TOOL_SCREWDRIVER,
		"checking its [pick("wires", "circuits")]" = TOOL_MULTITOOL,
		"welding its panel [pick("open", "shut")]" = TOOL_WELDER,
		"analyzing its readings" = TOOL_ANALYZER,
		"cutting some excess wires" = TOOL_WIRECUTTER,
	)
	var/list/fix_it_keys = assoc_to_keys(how_do_we_fix_it)
	var/list/methods_to_fix = list()
	for(var/i in 1 to rand(1, 3))
		methods_to_fix += pick_n_take(fix_it_keys)

	signals_to_add = list()
	for(var/tool_method in methods_to_fix)
		signals_to_add += COMSIG_ATOM_TOOL_ACT(how_do_we_fix_it[tool_method])

	the_source_of_our_problems.visible_message(span_danger("[the_source_of_our_problems] starts to emanate a horrible green gas!"))
	the_source_of_our_problems.AddComponent(
		/datum/component/radioactive_emitter, \
		cooldown_time = 2 SECONDS, \
		range = 5, \
		threshold = RAD_MEDIUM_INSULATION, \
		examine_text = span_green("<i>It's emanating a green gas... You could probably stop it by [english_list(methods_to_fix, and_text = " or ")].</i>"), \
	)
	if(length(signals_to_add))
		RegisterSignals(the_source_of_our_problems, signals_to_add, PROC_REF(on_machine_tooled))

	puff_some_smoke(the_source_of_our_problems)
	announce_to_ghosts(the_source_of_our_problems)

/datum/round_event/voidcrew/radiation_leak/tick()
	if(activeFor % (end_when / 3) != 0)
		return
	var/obj/machinery/impromptu_smoke_machine = picked_machine_ref?.resolve()
	if(QDELETED(impromptu_smoke_machine))
		return
	puff_some_smoke(impromptu_smoke_machine)

/**
 * Cleanup runs whether or not the ship is still alive, the component and the signals
 * live on the machine, and a leak left running on a hull that outlived this event would
 * irradiate its crew forever with nothing to switch it off.
 */
/datum/round_event/voidcrew/radiation_leak/end()
	var/obj/machinery/the_end_of_our_problems = picked_machine_ref?.resolve()
	if(QDELETED(the_end_of_our_problems))
		picked_machine_ref = null
		signals_to_add = null
		return

	the_end_of_our_problems.visible_message(span_notice("The gas emanating from [the_end_of_our_problems] dissipates."))
	qdel(the_end_of_our_problems.GetComponent(/datum/component/radioactive_emitter))
	if(length(signals_to_add))
		UnregisterSignal(the_end_of_our_problems, signals_to_add)
	picked_machine_ref = null
	signals_to_add = null

/// Shoots polonium/mutagen smoke into the air around the leaking machine.
/datum/round_event/voidcrew/radiation_leak/proc/puff_some_smoke(atom/where)
	var/turf/below_where = get_turf(where)
	if(!below_where)
		return
	var/datum/effect_system/fluid_spread/smoke/chem/gross_smoke = new()
	gross_smoke.chemholder.add_reagent(/datum/reagent/toxin/polonium, 10)
	gross_smoke.chemholder.add_reagent(/datum/reagent/toxin/mutagen, 10)
	gross_smoke.attach(below_where)
	gross_smoke.set_up(2, holder = where, location = below_where, silent = TRUE)
	gross_smoke.start()
	playsound(below_where, 'sound/effects/smoke.ogg', 50, vary = TRUE)

/// Signal catcher for the tool interactions that can cure the leak.
/datum/round_event/voidcrew/radiation_leak/proc/on_machine_tooled(obj/machinery/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(try_remove_radiation), source, user, tool)
	return ITEM_INTERACT_BLOCKING

/// Thirty seconds of work next to a radiation source ends the event early.
/datum/round_event/voidcrew/radiation_leak/proc/try_remove_radiation(obj/machinery/source, mob/living/user, obj/item/tool)
	source.balloon_alert(user, "fixing leak...")
	if(!tool.use_tool(source, user, 30 SECONDS, amount = (tool.tool_behaviour == TOOL_WELDER ? 2 : 0), volume = 50))
		source.balloon_alert(user, "interrupted!")
		return
	source.balloon_alert(user, "leak repaired")
	processing = FALSE
	end()
	kill()
