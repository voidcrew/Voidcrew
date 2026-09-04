/**
 * Radioactive nebula shielding, aboard a ship.
 *
 * Upstream this machine exists for one station trait: a radioactive nebula parked over the
 * station, with /datum/station_trait/nebula/hostile counting shielders by z-level. None of
 * that runs here - FORBID_STATION_TRAITS is set in config, so SSstation.station_traits is
 * empty and the machine's Initialize() registration quietly no-ops - and a z-level check
 * would be the wrong test anyway, since every ship z is a station level and a docked
 * neighbour's shielder would end up covering us.
 *
 * So the ship pulls rather than the nebula pushing: a hull standing in a tritium cloud asks
 * its own areas what shielding is aboard (get_nebula_shielding_level(), ship_damage.dm).
 * Everything the machine itself does - the panel/broken/powered gate, the power it draws
 * per block, the tritium it vents while working - is upstream's and is kept as is.
 */

/obj/machinery/nebula_shielding/radiation
	desc = "A field emitter built around a shielded core. Anchored and powered aboard a ship, \
		it keeps the radiation of a tritium nebula off the crew."

/// An emitter that has been unbolted has nothing to brace its field against. Scoped to the
/// radiation subtype on purpose: the emergency shielder upstream is deliberately unanchored.
/obj/machinery/nebula_shielding/radiation/get_nebula_shielding()
	if(!anchored)
		return 0
	return ..()

/obj/machinery/nebula_shielding/radiation/examine(mob/user)
	. = ..()
	. += span_notice("One working unit covers the whole hull, including while a ram scoop is drawing gas out of a tritium cloud.")
	. += span_notice("It does nothing about ion fronts, electrical storms or asteroids. Radiation only.")

/**
 * Upstream's board wants an engineering MODsuit radiation protection module, which is a
 * mechfab print (/datum/design/module, build_type MECHFAB) and no ship carries a mechfab -
 * the board would have been researchable and the machine still unbuildable. Uranium is what
 * that module is made of, and it comes out of the same asteroid fields a crew is already
 * mining, so the swap keeps the cost and puts it on a hull's own lathe.
 */
/obj/item/circuitboard/machine/radioactive_nebula_shielding
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/obj/item/stack/sheet/mineral/uranium = 3,
		/obj/item/stack/sheet/plasteel = 2,
	)
