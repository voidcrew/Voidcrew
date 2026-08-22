// Harmonic Dampening Array
//
// Progression-gated counter to ion and electrical overmap storms.
//
// Asteroid storms already have a full mitigator: the shield generator spawns physical
// shield walls that intercept the meteor before it reaches the hull. This is the
// ion/electrical equivalent and deliberately follows the same shape - a techweb-gated
// circuit board, RPED-upgradeable stock parts, one ship-scoped machine that resolves
// its ship by shuttle area - but it works by intercepting individual storm surges as
// the storm rolls them out instead of by putting a wall in front of them.
//
// While anchored, powered and closed up, the array sinks incoming surges into the hull
// grounding grid. Every surge it catches costs a large jolt of energy out of the local
// APC (grid surplus first, then the APC cell), so an under-generated ship cannot idle
// its way through a storm. It also saturates: only so many surges per window, no matter
// how good the capacitors are.

/obj/machinery/ship_combat/storm_dampener
	name = "harmonic dampening array"
	desc = "A bank of grounding rods wired into the hull. It bleeds ion surges and lightning discharges out of the ship before they reach anything delicate, at the cost of a heavy jolt of power for every surge it catches. Bolt it down and keep the panel shut."
	icon = 'icons/obj/machines/engine/tesla_coil.dmi'
	icon_state = "grounding_rod1"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/storm_dampener
	/// Constant standby draw - the array is always listening
	idle_power_usage = STORM_DAMPENER_IDLE_POWER
	max_integrity = 300

	// Stock part integration
	// Capacitors: +6.5% catch chance per tier (capped at 90%)
	// Scanning modules: +2 surges per saturation window per tier
	// Servos: -15% energy cost per caught surge per tier

	/// Chance to catch any single incoming storm surge
	var/absorb_chance = STORM_DAMPENER_BASE_CHANCE
	/// Energy pulled from the local APC for each caught surge
	var/surge_cost = STORM_DAMPENER_BASE_SURGE
	/// How many surges can be caught inside one saturation window
	var/surge_capacity = STORM_DAMPENER_BASE_CAPACITY
	/// Surges caught inside the window that is currently open
	var/surges_this_window = 0
	/// world.time at which the current saturation window closes
	var/window_end = 0
	/// Lifetime count of caught surges, shown on examine
	var/total_surges_caught = 0
	/// Reference to the ship this array is installed on
	var/datum/weakref/linked_ship_ref
	/// Throttles the discharge/brownout audio during heavy storms
	COOLDOWN_DECLARE(feedback_cooldown)

/obj/machinery/ship_combat/storm_dampener/Initialize(mapload)
	. = ..()
	// Ships aren't resolvable the instant a mapped machine initializes
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/storm_dampener/Destroy()
	unlink_ship()
	return ..()

/obj/machinery/ship_combat/storm_dampener/RefreshParts()
	. = ..()

	absorb_chance = STORM_DAMPENER_BASE_CHANCE
	surge_capacity = STORM_DAMPENER_BASE_CAPACITY
	var/efficiency = 1

	for(var/datum/stock_part/capacitor/cap in component_parts)
		absorb_chance += STORM_DAMPENER_CAPACITOR_CHANCE * (cap.tier - 1)

	for(var/datum/stock_part/scanning_module/scanner in component_parts)
		surge_capacity += STORM_DAMPENER_SCANNER_CAPACITY * (scanner.tier - 1)

	for(var/datum/stock_part/servo/servo in component_parts)
		efficiency -= STORM_DAMPENER_SERVO_EFFICIENCY * (servo.tier - 1)

	absorb_chance = min(absorb_chance, STORM_DAMPENER_MAX_CHANCE)
	surge_cost = STORM_DAMPENER_BASE_SURGE * max(efficiency, STORM_DAMPENER_MIN_EFFICIENCY)

/obj/machinery/ship_combat/storm_dampener/examine(mob/user)
	. = ..()
	if(!anchored)
		. += span_warning("It has to be bolted to the deck before it can ground anything.")
	else if(panel_open)
		. += span_warning("The maintenance panel is open - the grounding path is broken.")
	else if(machine_stat & EMPED)
		. += span_warning("The control electronics are scrambled. It will come back on its own.")
	else if(!is_operational)
		. += span_warning("It is unpowered or broken.")
	else
		. += span_notice("Status: ONLINE.")

	. += span_notice("Surge interception: [round(absorb_chance)]% per incoming surge.")
	. += span_notice("Saturation limit: [surge_capacity] surges per [DisplayTimeText(STORM_DAMPENER_WINDOW)].")
	. += span_notice("Discharge cost: [display_energy(surge_cost)] per surge grounded.")
	var/reserve = available_energy()
	. += span_notice("Grid reserve available: [reserve == INFINITY ? "unmetered" : display_energy(reserve)].")
	. += span_notice("Surges grounded since installation: [total_surges_caught].")

	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		. += span_notice("Bonded to the hull grid of [ship].")
	else
		. += span_warning("Not bonded to a hull grid - it is not aboard a ship.")

/obj/machinery/ship_combat/storm_dampener/update_icon_state()
	if(panel_open)
		icon_state = "grounding_rod_open[anchored]"
	else
		icon_state = "grounding_rod[anchored]"
	return ..()

// ========== SHIP LINKING ==========

/// Finds the ship this array sits on and registers with it
/obj/machinery/ship_combat/storm_dampener/proc/attempt_auto_link()
	if(linked_ship_ref?.resolve())
		return

	var/area/our_area = get_area(src)
	if(!our_area)
		return

	for(var/obj/structure/overmap/ship/candidate as anything in SSovermap.simulated_ships)
		if(QDELETED(candidate) || !candidate.shuttle)
			continue
		if(our_area in candidate.shuttle.shuttle_areas)
			link_ship(candidate)
			return

/// Resolves our ship, retrying the lookup if we've never linked
/obj/machinery/ship_combat/storm_dampener/proc/get_linked_ship()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		return ship
	attempt_auto_link()
	return linked_ship_ref?.resolve()

/// Registers this array with a ship's dampener list
/obj/machinery/ship_combat/storm_dampener/proc/link_ship(obj/structure/overmap/ship/ship)
	if(!ship)
		return FALSE
	unlink_ship()
	linked_ship_ref = WEAKREF(ship)
	ship.linked_storm_dampeners |= src
	return TRUE

/// Drops this array off its ship's dampener list
/obj/machinery/ship_combat/storm_dampener/proc/unlink_ship()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		ship.linked_storm_dampeners -= src
	linked_ship_ref = null

// ========== SURGE INTERCEPTION ==========

/// TRUE if the array is in a state where it can ground surges
/obj/machinery/ship_combat/storm_dampener/proc/is_dampening()
	if(!anchored || panel_open)
		return FALSE
	if(!is_operational)
		return FALSE
	if(machine_stat & EMPED)
		return FALSE
	return TRUE

/**
 * Tries to ground one incoming storm surge.
 *
 * Rolls the catch chance, checks the saturation window, then pays for the catch out
 * of the local APC. If the ship can't cover the jolt the surge lands anyway - the
 * array is not a free pass for an under-generated hull.
 *
 * * origin - the turf the surge was about to hit, used for the discharge beam.
 *
 * Returns TRUE if the surge was grounded and the caller should skip its effect.
 */
/obj/machinery/ship_combat/storm_dampener/proc/try_absorb_surge(turf/origin)
	if(!is_dampening())
		return FALSE

	// Open a fresh saturation window if the last one has expired
	if(world.time > window_end)
		window_end = world.time + STORM_DAMPENER_WINDOW
		surges_this_window = 0

	if(surges_this_window >= surge_capacity)
		return FALSE

	if(!prob(absorb_chance))
		return FALSE

	// Grounding a surge is a big jolt, not a trickle
	if(available_energy() < surge_cost)
		on_brownout()
		return FALSE

	use_energy(surge_cost)
	surges_this_window++
	total_surges_caught++
	do_discharge_effect(origin)
	return TRUE

/// Visible/audible reaction to catching a surge
/obj/machinery/ship_combat/storm_dampener/proc/do_discharge_effect(turf/origin)
	flick("grounding_rodhit", src)
	do_sparks(3, FALSE, src)

	if(origin && origin.z == z)
		Beam(origin, icon_state = "lightning[rand(1, 12)]", time = 0.4 SECONDS)

	if(COOLDOWN_FINISHED(src, feedback_cooldown))
		COOLDOWN_START(src, feedback_cooldown, STORM_DAMPENER_FEEDBACK_COOLDOWN)
		playsound(src, 'sound/effects/magic/lightningshock.ogg', 45, TRUE)
		visible_message(span_notice("[src] cracks and dumps a surge into the deck."))

/// Reaction to failing a catch because the grid couldn't pay for it
/obj/machinery/ship_combat/storm_dampener/proc/on_brownout()
	if(!COOLDOWN_FINISHED(src, feedback_cooldown))
		return
	COOLDOWN_START(src, feedback_cooldown, STORM_DAMPENER_FEEDBACK_COOLDOWN)
	do_sparks(2, FALSE, src)
	playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 40, TRUE)
	visible_message(span_warning("[src] winds up and dies back down - there isn't enough power in the grid to sink the surge."))

// ========== TOOL INTERACTIONS ==========

/obj/machinery/ship_combat/storm_dampener/attackby(obj/item/weapon, mob/user, list/modifiers, list/attack_modifiers)
	if(default_deconstruction_screwdriver(user, "grounding_rod_open[anchored]", "grounding_rod[anchored]", weapon))
		return
	if(default_deconstruction_crowbar(weapon))
		return
	return ..()

/obj/machinery/ship_combat/storm_dampener/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	default_unfasten_wrench(user, tool)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

// ========== SHIP INTEGRATION ==========

/obj/structure/overmap/ship
	/// Harmonic dampening arrays installed aboard this ship
	var/list/linked_storm_dampeners = list()

/**
 * Returns the best usable dampening array aboard this ship, or null if there isn't one.
 *
 * Only one array ever protects the ship - a second one is redundancy, not a stacking
 * bonus - so the strongest operational array wins.
 */
/obj/structure/overmap/ship/proc/get_storm_dampener()
	var/obj/machinery/ship_combat/storm_dampener/best
	for(var/obj/machinery/ship_combat/storm_dampener/dampener as anything in linked_storm_dampeners)
		if(QDELETED(dampener))
			continue
		if(!dampener.is_dampening())
			continue
		if(!best || dampener.absorb_chance > best.absorb_chance)
			best = dampener
	return best

/// Announces how much of a storm the dampening array managed to ground
/obj/structure/overmap/ship/proc/notify_surges_grounded(grounded, total)
	if(grounded <= 0)
		return
	ship_notify("Dampening array grounded [grounded] of [total] incoming surges.", "SYSTEMS", SHIP_NOTIFY_NOTICE)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/storm_dampener
	name = "Harmonic Dampening Array"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/ship_combat/storm_dampener
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/scanning_module = 1,
		/datum/stock_part/servo = 1,
	)
