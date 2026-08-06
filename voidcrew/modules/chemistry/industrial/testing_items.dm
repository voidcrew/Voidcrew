/*
 * Admin-spawn kit for the industrial chemistry system.
 *
 * Ported from monkestation's wiremod_chem module (testing_items.dm), extended to cover the
 * structures. There is deliberately no design, recipe or crate for this box - it exists so
 * the whole system can be stood up in one spawn while it is being playtested.
 *
 * It is also currently the ONLY way to obtain the manufacturer, the remote tanks and the
 * precursor tank: upstream never gave any of those a construction path, and inventing lathe
 * recipes and material costs for them is a balance decision, not a porting one.
 */
/obj/item/storage/box/chem_wiremod
	name = "industrial chemistry kit"
	desc = "A test kit containing everything needed to stand up an automated chemical plant."

/obj/item/storage/box/chem_wiremod/PopulateContents()
	new /obj/item/integrated_circuit/chemical(src)
	new /obj/item/multitool(src)
	new /obj/item/stock_parts/power_store/cell/high(src)

	new /obj/item/circuit_component/chem/synthesizer(src)
	new /obj/item/circuit_component/chem/synthesizer(src)
	new /obj/item/circuit_component/chem/mixer(src)
	new /obj/item/circuit_component/chem/filter(src)
	new /obj/item/circuit_component/chem/splitter(src)
	new /obj/item/circuit_component/chem/weighted_splitter(src)
	new /obj/item/circuit_component/chem/internal_tank(src)

/// Companion spawner for the structures, which do not fit in a box.
/obj/effect/spawner/chem_wiremod_plant
	name = "industrial chemistry plant spawner"
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "spawner"

/obj/effect/spawner/chem_wiremod_plant/Initialize(mapload)
	. = ..()
	var/turf/spawn_turf = get_turf(src)
	new /obj/structure/chemical_manufacturer(spawn_turf)
	new /obj/item/precursor_tank(spawn_turf)
	new /obj/structure/chemical_input(spawn_turf)
	new /obj/structure/chemical_tank(spawn_turf)
	new /obj/item/storage/box/chem_wiremod(spawn_turf)
	return INITIALIZE_HINT_QDEL
