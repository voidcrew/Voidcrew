/**
 * Modular fix for upstream TG power leak bug
 *
 * Problem: When machinery moves between areas (e.g., shuttle transit),
 * on_exit_area() calls unset_static_power() which uses get_area(src).
 * But by the time on_exit_area is called, the machine has already moved
 * to the new area, so get_area(src) returns the NEW area, not the OLD
 * area where power was registered. This causes phantom power drain that
 * persists even after the machinery is deleted.
 *
 * Fix: Use the area passed to on_exit_area (the correct old area) instead
 * of calling get_area(src).
 */
/obj/machinery/on_exit_area(datum/source, area/area_to_unregister)
	SIGNAL_HANDLER
	if(always_area_sensitive && use_power == NO_POWER_USE)
		return
	// FIX: Remove power from the PASSED area (old area), not get_area(src) (new area)
	if(area_to_unregister && static_power_usage)
		area_to_unregister.removeStaticPower(static_power_usage, DYNAMIC_TO_STATIC_CHANNEL(power_channel))
		static_power_usage = 0
	UnregisterSignal(area_to_unregister, COMSIG_AREA_POWER_CHANGE)

/**
 * Ion storms drain the SMES but leave its input/output configuration alone.
 *
 * Upstream's emp_act rolls `output_attempt = rand(0, 1)` and randomises both power
 * levels, so half of all EMPs simply switch the ship's powernet off. Nothing resets
 * it: the APC blackout expires on its own after a minute, but a SMES that rolled
 * output off stays off until a crew member walks to it and flips the switch. On a
 * ship that reads as total, permanent, causeless power death - the helm is unusable
 * (can_interact refuses on NOPOWER), electric engines go with it
 * (thruster_active = !!powernet), and nothing on any console says why.
 *
 * A storm should cost the crew their charge, which is legible and recoverable, not
 * their switchgear. Everything else in the burst radius takes the EMP normally; this
 * is the one machine spared, and only for storms - a syndicate EMP grenade or a
 * malfunctioning cell still scrambles the SMES the way upstream intends.
 *
 * The flag is set around the pulse loop in apply_ion_storm_damage() (ship_damage.dm).
 */
/obj/machinery/power/smes/emp_act(severity)
	if(!GLOB.ion_storm_pulse_active)
		return ..()

	// Run the whole upstream chain - the charge drain, the generic machine EMP and
	// the COMSIG_ATOM_EMP_ACT signal all still fire, so anything hardening a SMES
	// keeps working - then put the switchgear back exactly as it was. Restoring is
	// what keeps this in step with upstream: a future change to how much a hit
	// drains carries over untouched, because only these six vars are reverted.
	var/was_input_attempt = input_attempt
	var/was_output_attempt = output_attempt
	var/was_input_level = input_level
	var/was_output_level = output_level
	var/was_inputting = inputting
	var/was_outputting = outputting

	. = ..()

	input_attempt = was_input_attempt
	output_attempt = was_output_attempt
	input_level = was_input_level
	output_level = was_output_level
	inputting = was_inputting
	outputting = was_outputting
	update_appearance(UPDATE_OVERLAYS)
	// Parent already logged the scrambled values; log again so the engine record
	// shows what the SMES is actually left set to.
	log_smes()

/**
 * RTGs are the fuel-free generator, and upstream priced them for a station that
 * only ever used them as derelict set dressing.
 *
 * A mapped advanced RTG runs on default T1 parts, so it made 2.5 kW; the goon RTG
 * Bank module fits three of them for 7.5 kW total, against the free default PACMAN
 * Bay's two generators at up to 80 kW. On a ship that is not a tradeoff - an ion
 * thruster alone wants 50 kJ off the wire for one full burn (electric.dm), so the
 * bank could not feed a single engine and only trickled into the SMES. Raising the
 * base output to 5 kW / 6 kW puts the bank at 36 kW: still under a fuelled PACMAN
 * pair, but it actually runs a hull with no fuel line, which is what both the
 * module's description and its 4-science-part price already claimed it did.
 */
/obj/machinery/power/rtg
	power_gen = 5000 // 5 kW on T1 parts, 30 kW on T4.

/obj/machinery/power/rtg/advanced
	power_gen = 6000 // Two parts, so 12 kW on T1, 72 kW on T4.

/**
 * Output multiplier one stock part contributes at the given tier.
 *
 * Upstream summed the raw tiers, which makes a T4 capacitor worth exactly four T1s -
 * a linear return on a part that costs bluespace research, so nobody ever fitted one
 * and RTGs were a fit-and-forget machine. Weighting the top tiers turns an RTG into
 * something engineering can invest in: the PACMAN's output is flat and ignores its
 * parts entirely, so scaling with parts is the RTG's half of the trade.
 */
/obj/machinery/power/rtg/proc/part_output_weight(tier)
	switch(tier)
		if(1)
			return 1
		if(2)
			return 2
		if(3)
			return 4
		if(4 to INFINITY)
			return 6
		else
			return 0

/// The Void Core is abductor loot, not ship engineering - it keeps upstream's flat sum.
/obj/machinery/power/rtg/abductor/part_output_weight(tier)
	return tier

/obj/machinery/power/rtg/RefreshParts()
	. = ..() // Upstream sets power_gen off the flat tier sum; recompute over the weights.
	// Upstream's escape hatch for RTGs whose stock parts don't affect output (the debug RTG).
	// ..() has already set power_gen from get_base_power_gen(); there is nothing to weight.
	if(!affected_by_parts)
		return

	var/scale = 0
	for(var/datum/stock_part/stock_part in component_parts)
		scale += part_output_weight(stock_part.tier)

	// base_power_gen rather than initial(power_gen) so a mapper's or an admin's edit to
	// power_gen is the number that gets scaled, and upstream's `|| 1` fallback so the
	// circuit-less subtypes (lavaland, old_station, and any board-less mapped RTG) hold
	// their base output instead of dropping to zero for want of a stock part to weigh.
	power_gen = base_power_gen * (scale || 1)

/**
 * VOIDCREW EDIT (upstream bug, candidate to report): APC pixel offsets are owned by
 * setDir() - it derives them from the new facing. The base shuttleRotate() then rotates
 * the offsets AGAIN, and on a 90-degree turn the old facing's offset also survives on
 * the now-perpendicular axis. Net effect: every APC on a rotated ship probed the wrong
 * tile for its wall support (180 degrees = the opposite tile, 90 = a diagonal), failing
 * the atom_mounted attach on load. Clear the old facing's offset up front and strip
 * ROTATE_OFFSET so setDir()'s answer is final (this also keeps the malf HUD image,
 * rebuilt inside setDir(), at the right offset).
 */
/obj/machinery/power/apc/shuttleRotate(rotation, params)
	if(dir & (NORTH|SOUTH))
		pixel_y = 0
	else
		pixel_x = 0
	return ..(rotation, params & ~ROTATE_OFFSET)

/**
 * Tops every cell in this SMES up to capacity. Returns the energy added.
 *
 * Lives here rather than at the call site because both the capacity var and
 * total_charge() are protected to the SMES type, so nothing outside it can
 * work out how much charge is missing.
 */
/obj/machinery/power/smes/proc/fill_charge()
	var/missing = total_capacity - total_charge()
	if(missing <= 0)
		return 0
	. = adjust_charge(missing)
	update_appearance(UPDATE_OVERLAYS)
