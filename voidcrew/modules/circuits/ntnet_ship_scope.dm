/**
 * # NTNet, scoped to ships
 *
 * Upstream NTNet is switched on by a single global question: does an operational
 * /obj/machinery/ntnet_relay exist anywhere in the world (find_functional_ntnet_relay()).
 * On tg that relay lives on the station map. This fork never loads a station map at all -
 * SSmapping.loadWorld() is fully overridden in voidcrew/mapping/_mapping.dm - and not one
 * ship, shuttle or ruin in _maps/voidcrew places a relay. So the answer is always "no", and
 * NTNet has been dead fork-wide for every round: no PDA or tablet has ever had a signal, and
 * the NTNet circuit components refuse to transmit or receive.
 *
 * Ships are the infrastructure here, so a ship carries its own NTNet node. Every ship z level
 * is registered as a station level by /obj/docking_port/mobile/voidcrew/link_to_z_level(), and
 * nothing else in this fork is a station level, so "on a station level" is an O(1) test for
 * "aboard a ship" - cheap enough for the per-process-tick callers.
 *
 * Reach is deliberately asymmetric: a ship can put data on NTNet, but only receivers on the
 * same ship pick it up. Nothing here opens a galaxy-wide circuit bus between unrelated crews.
 */

/// TRUE if `context` can reach an NTNet node. Ships are their own node.
/proc/ntnet_reachable_from(atom/context)
	var/turf/context_turf = get_turf(context)
	if(context_turf && is_station_level(context_turf.z))
		return TRUE
	return find_functional_ntnet_relay()

/**
 * Where a circuit physically is.
 *
 * A circuit in a shell flagged SHELL_FLAG_CIRCUIT_UNREMOVABLE lives in nullspace - bots and
 * drones are built that way - so get_turf() on the circuit itself returns null for them.
 * Always locate through the shell when there is one.
 */
/proc/get_circuit_turf(obj/item/integrated_circuit/circuit)
	if(isnull(circuit))
		return null
	return get_turf(circuit.shell || circuit)

/**
 * TRUE if two atoms sit on the same ship-local wireless network.
 *
 * The z comparison is a cheap reject that covers almost every call and keeps the expensive
 * lookup off the hot path: ships occupy one z level each, and get_ship_from_atom() walks every
 * mobile docking port doing bounds maths. A matching z is not proof on its own - two ships
 * share a z level while docked to each other - so it is confirmed against the ship each atom
 * actually belongs to. Anything not aboard a ship is never "on a ship network".
 */
/proc/on_same_ship_network(atom/first, atom/second)
	var/turf/first_turf = get_turf(first)
	var/turf/second_turf = get_turf(second)
	if(isnull(first_turf) || isnull(second_turf))
		return FALSE
	if(first_turf.z != second_turf.z)
		return FALSE

	var/obj/structure/overmap/ship/first_ship = get_ship_from_atom(first)
	if(isnull(first_ship))
		return FALSE
	return first_ship == get_ship_from_atom(second)

/**
 * Restores a signal to tablets and PDAs aboard a ship.
 *
 * The upstream implementation bails at NTNET_NO_SIGNAL on find_functional_ntnet_relay() before
 * it ever reaches its own is_station_level() branch, so every handheld in the fork reported no
 * signal and every PROGRAM_REQUIRES_NTNET app refused to launch. Only the branch that upstream
 * could not reach is filled in here; anything it does answer is left alone, including the
 * silicon PDA overrides that deny a signal on lockdown or a flat cell.
 */
/obj/item/modular_computer/get_ntnet_status()
	. = ..()
	if(. != NTNET_NO_SIGNAL)
		return .

	if(!ntnet_reachable_from(src))
		return .

	if(hardware_flag & PROGRAM_LAPTOP)
		return NTNET_ETHERNET_SIGNAL
	return NTNET_GOOD_SIGNAL
