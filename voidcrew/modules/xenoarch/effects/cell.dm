// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/cellcharge.dm and celldrain.dm.
// Voidcrew: no free power. Charging works on at most two ordinary power cells at a time, no
// faster than a tier-1 recharger (the cell's own charge rate, capped at a standard cell's), and
// never on APCs, SMES units, megacells or any machine. Nova gave 125 kW to everything in range
// and a billion joules to every cell when smashed. Draining reaches the same cells.

/datum/artifact_effect/cell
	tier = ARTIFACT_TIER_UNCOMMON
	minor = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ELECTROMAGNETIC)
	/// Cells it works on at once
	var/cell_limit = 2

/// Seconds of recharger-rate charge for this cell, capped at a standard cell's rate.
/datum/artifact_effect/cell/proc/charge_for(obj/item/stock_parts/power_store/cell/cell, seconds)
	return min(cell.chargerate, STANDARD_CELL_RATE) * seconds

/// Ordinary power cells carried by `holder_atom` (itself, or anything inside it).
/datum/artifact_effect/cell/proc/cells_in(atom/holder_atom)
	return holder_atom.get_all_contents_type(/obj/item/stock_parts/power_store/cell)

/// Cells in range, loose or carried, never inside a machine. `want_room` picks cells that are
/// not full; otherwise cells that are not empty.
/datum/artifact_effect/cell/proc/cells_nearby(want_room)
	. = list()
	var/turf/center = source_turf()
	if(!center)
		return
	for(var/atom/movable/thing in range(range, center))
		if(!isitem(thing) && !isliving(thing))
			continue
		for(var/obj/item/stock_parts/power_store/cell/cell as anything in cells_in(thing))
			if(want_room ? cell.charge < cell.maxcharge : cell.charge > 0)
				. += cell
				if(length(.) >= cell_limit)
					return

/datum/artifact_effect/cell/proc/after_change(obj/item/stock_parts/power_store/cell/cell)
	cell.update_appearance()
	if(isatom(cell.loc))
		var/atom/cell_holder = cell.loc
		cell_holder.update_appearance()

/datum/artifact_effect/cell/charge
	label_name = "Charges cells"
	log_name = "Cell charge"
	helpful = TRUE

/datum/artifact_effect/cell/charge/do_effect_touch(mob/living/user)
	var/charged = 0
	for(var/obj/item/stock_parts/power_store/cell/cell as anything in cells_in(user))
		if(charged >= cell_limit)
			break
		if(cell.charge >= cell.maxcharge)
			continue
		cell.give(charge_for(cell, 5))
		after_change(cell)
		charged++
	if(charged && issilicon(user))
		to_chat(user, span_notice("Your cell takes a charge."))

/datum/artifact_effect/cell/charge/do_effect_aura(seconds_per_tick)
	for(var/obj/item/stock_parts/power_store/cell/cell as anything in cells_nearby(want_room = TRUE))
		cell.give(charge_for(cell, seconds_per_tick))
		after_change(cell)

/datum/artifact_effect/cell/charge/do_effect_pulse(power)
	for(var/obj/item/stock_parts/power_store/cell/cell as anything in cells_nearby(want_room = TRUE))
		cell.give(charge_for(cell, 10))
		after_change(cell)

/datum/artifact_effect/cell/drain
	label_name = "Drains cells"
	log_name = "Cell drain"
	harmful = TRUE

/datum/artifact_effect/cell/drain/do_effect_touch(mob/living/user)
	var/drained = 0
	for(var/obj/item/stock_parts/power_store/cell/cell as anything in cells_in(user))
		if(drained >= cell_limit)
			break
		if(cell.charge <= 0)
			continue
		cell.use(charge_for(cell, 30), force = TRUE)
		after_change(cell)
		drained++
	if(drained)
		log_harm(user)
		if(issilicon(user))
			to_chat(user, span_warning("Your cell is draining fast!"))

/datum/artifact_effect/cell/drain/do_effect_aura(seconds_per_tick)
	drain_nearby(charge_seconds = seconds_per_tick * 2)

/datum/artifact_effect/cell/drain/do_effect_pulse(power)
	drain_nearby(charge_seconds = 20)

/datum/artifact_effect/cell/drain/proc/drain_nearby(charge_seconds)
	for(var/obj/item/stock_parts/power_store/cell/cell as anything in cells_nearby(want_room = FALSE))
		cell.use(charge_for(cell, charge_seconds), force = TRUE)
		after_change(cell)
		var/mob/living/carrier = get(cell, /mob/living)
		if(carrier)
			log_harm(carrier)
