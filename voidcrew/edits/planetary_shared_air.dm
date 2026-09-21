/**
 * # Shared planetary turf air
 *
 * A planetary_atmos turf is defined as air that reverts toward its initial_gas_mix, and
 * on a generated planet almost every one of them holds exactly that mix for the whole
 * round. Giving each of them its own /datum/gas_mixture/turf (gases list, one sublist per
 * gas, reaction_results list) is what put ~95k mixtures on the heap in round 79.
 *
 * Instead, a freshly created planetary turf points `air` at ONE shared mixture per gas
 * string (a /datum/gas_mixture/immutable/planetary/shared_turf) and only takes a private
 * /datum/gas_mixture/turf the first time anything would write to it. Reads see the planet
 * mix either way, so nothing that only looks at a turf's air can tell the difference.
 *
 * The boundary is "any write materializes":
 * - return_air() hands out a private mix, because most callers write to what they get
 *   (canisters, vents, breathing, fires). Pure readers on hot paths use
 *   return_air_readonly() and never materialize (mob Life, sounds, speech).
 * - assume_air, remove_air, copy_air, copy_air_with_tile, atmos_spawn_air, TakeTemperature,
 *   Assimilate_Air and ChangeTurf(CHANGETURF_INHERIT_AIR) materialize before writing.
 * - LINDA materializes BOTH turfs before any share() (neighbour, space run_later, and the
 *   "atmosphere above" share), and both before superconduction temperature_share()s. Two
 *   turfs on the same shared mix never pass compare(), so an untouched planet never
 *   materializes anything on its own.
 *
 * A turf never returns to the shared mix once it has a private one. The excited-group
 * breakdown copies the planet mix back into it, so it behaves as before; it just costs
 * memory again. That is deliberate: reverting would have to prove nothing still holds a
 * reference to the private mix, and nothing here needs it.
 *
 * Defense in depth: the shared type is immutable, so a write that slips past the
 * boundary is swallowed or undone by the next garbage_collect() rather than bleeding into
 * every turf on the planet, and remove()/copy() hand back real mutable mixtures so a
 * breath taken off a shared mix is still a breath.
 */

GLOBAL_LIST_EMPTY(planetary_shared_turf_air)

/// Read-only view of the air at this atom. Same result as return_air() for everything
/// except a planetary turf still on its shared mix, which return_air() would materialize.
/// Never write to what this returns.
/atom/proc/return_air_readonly()
	return return_air()

/turf/open/return_air_readonly()
	return air

/// Whether planetary turfs are handed the shared mix at all (compile-time switch).
/proc/planetary_atmos_shared_mix_enabled()
#ifdef PLANETARY_ATMOS_SHARED_MIX
	return TRUE
#else
	return FALSE
#endif

/**
 * The one mixture every untouched planetary turf with the same initial_gas_mix shares as
 * its `air`. Immutable: garbage_collect() restores the parsed mix, merge()/copy_from()/
 * react() refuse, and anything removed or copied out of it is a real mutable
 * /datum/gas_mixture/turf so callers downstream never hold an immutable by accident.
 *
 * Distinct from SSair.planetary[gas_string], the "atmosphere above" a planetary turf
 * shares with in process_cell(): that one keeps the bare immutable heat capacity (0 for a
 * vacuum) and its share semantics must not change.
 */
/datum/gas_mixture/immutable/planetary/shared_turf

/// Matches /turf/proc/create_gas_mixture(): a gas string without TEMP is room temperature.
/datum/gas_mixture/immutable/planetary/shared_turf/parse_string_immutable(gas_string)
	. = ..()
	if(isnull(initial_temperature))
		initial_temperature = T20C
		temperature = T20C
		temperature_archived = T20C

/// Same as /datum/gas_mixture/turf/heat_capacity(): a vacuum on a turf conducts like space.
/datum/gas_mixture/immutable/planetary/shared_turf/heat_capacity(data = MOLES)
	var/list/cached_gases = gases
	. = 0
	for(var/id in cached_gases)
		var/gas_data = cached_gases[id]
		. += gas_data[data] * gas_data[GAS_META][META_GAS_SPECIFIC_HEAT]
	if(!.)
		. += HEAT_CAPACITY_VACUUM

/// A mutable turf mixture with our contents, never another immutable.
/datum/gas_mixture/immutable/planetary/shared_turf/copy()
	var/datum/gas_mixture/turf/copy = new(volume)
	copy.copy_from(src)
	return copy

// The parent remove procs build the removed portion as `new type`, which here would be an
// immutable that empties itself on its first garbage_collect(). Take it off a mutable copy
// instead; the shared mix itself is left untouched, an atmosphere is not drained by a breath.
/datum/gas_mixture/immutable/planetary/shared_turf/remove(amount)
	var/datum/gas_mixture/copied = copy()
	return copied.remove(amount)

/datum/gas_mixture/immutable/planetary/shared_turf/remove_ratio(ratio)
	var/datum/gas_mixture/copied = copy()
	return copied.remove_ratio(ratio)

/datum/gas_mixture/immutable/planetary/shared_turf/remove_specific(gas_id, amount)
	var/datum/gas_mixture/copied = copy()
	return copied.remove_specific(gas_id, amount)

/datum/gas_mixture/immutable/planetary/shared_turf/remove_specific_ratio(gas_id, ratio)
	var/datum/gas_mixture/copied = copy()
	return copied.remove_specific_ratio(gas_id, ratio)

/**
 * The shared mix this turf can use as its air, or null when it must own a private one.
 *
 * create_gas_mixture() stamps a turf type's own `temperature` onto the mix when it differs
 * from the default; a turf whose type does that can only share when the string's
 * temperature happens to match, or its air would start out different from before.
 */
/turf/open/proc/planetary_shared_air()
#ifndef PLANETARY_ATMOS_SHARED_MIX
	return null
#else
	var/datum/gas_mixture/immutable/planetary/shared_turf/shared = GLOB.planetary_shared_turf_air[initial_gas_mix]
	if(!shared)
		shared = new
		shared.parse_string_immutable(initial_gas_mix)
		GLOB.planetary_shared_turf_air[initial_gas_mix] = shared
	var/turf/parent = parent_type
	if((temperature != initial(temperature) || temperature != initial(parent.temperature)) && temperature != shared.temperature)
		return null
	return shared
#endif

/// TRUE while this turf's air is still the shared planetary mix. Always FALSE when the
/// switch is off: nothing then ever hands the type out.
/turf/open/proc/has_shared_planet_air()
	return istype(air, /datum/gas_mixture/immutable/planetary/shared_turf)

/**
 * Gives this turf a private mixture if it is still on the shared one, and returns `air`
 * either way. Call before any write to `air`. The copy is archived so a share() that runs
 * in the same cycle sees the same archived state the shared mix was presenting.
 */
/turf/open/proc/materialize_planet_air()
	if(!istype(air, /datum/gas_mixture/immutable/planetary/shared_turf))
		return air
	var/datum/gas_mixture/turf/private_air = new
	private_air.copy_from(air)
	private_air.archive()
	air = private_air
	return private_air
