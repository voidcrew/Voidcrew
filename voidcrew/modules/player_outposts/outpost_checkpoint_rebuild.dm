/datum/checkpoint_construction/proc/clear_stock(obj/docking_port/mobile/voidcrew/source_port)
	checkpoint_clear_stock(source_port, ship_save_restocked())

/// Empties a loaded copy of everything but its fittings. Types in `restocked_types` keep what they loaded with.
/proc/checkpoint_clear_stock(obj/docking_port/mobile/voidcrew/source_port, list/restocked_types)
	for(var/turf/tile as anything in source_port.return_turfs())
		if(!(get_area(tile) in source_port.shuttle_areas))
			continue
		for(var/atom/movable/object as anything in tile.get_all_contents())
			if(QDELETED(object))
				continue
			var/restocked = is_type_in_typecache(object, restocked_types)
			if(!restocked)
				object.reagents?.clear_reagents()
			if(isitem(object) && checkpoint_is_machine_fitting(object))
				continue
			if(isitem(object) || ismob(object) || istype(object, /obj/structure/disposalholder))
				qdel(object)
				continue
			var/datum/component/material_container/materials = object.GetComponent(/datum/component/material_container)
			for(var/material in materials?.materials)
				materials.use_amount_mat(materials.materials[material], material)
			if(istype(object, /obj/machinery/atmospherics))
				var/obj/machinery/atmospherics/machine = object
				for(var/datum/pipeline/network as anything in machine.return_pipenets())
					network?.air?.gases.Cut()
				if(!restocked && istype(machine, /obj/machinery/atmospherics/components))
					var/obj/machinery/atmospherics/components/component = machine
					for(var/datum/gas_mixture/mix as anything in component.airs)
						mix?.gases.Cut()
					// Tanks keep their gas outside airs, and gas-typed tanks refill on Initialize.
					var/list/stored = component.return_airs_for_reconcilation(null)
					if(!islist(stored))
						stored = list(stored)
					for(var/datum/gas_mixture/mix as anything in stored)
						mix?.gases.Cut()
			// Stock kept outside contents or in counters rather than as items.
			if(istype(object, /obj/structure/closet/crate/critter))
				var/obj/structure/closet/crate/critter/crate = object
				QDEL_NULL(crate.tank)
			if(istype(object, /obj/structure/tank_dispenser))
				var/obj/structure/tank_dispenser/dispenser = object
				dispenser.oxygentanks = 0
				dispenser.plasmatanks = 0
				dispenser.update_appearance()
			if(istype(object, /obj/machinery/power/port_gen/pacman))
				var/obj/machinery/power/port_gen/pacman/generator = object
				generator.sheets = 0
				generator.sheet_left = 0
			if(istype(object, /obj/structure/bedsheetbin))
				var/obj/structure/bedsheetbin/bin = object
				bin.amount = 0
				bin.update_appearance()
			if(istype(object, /obj/structure/filingcabinet/medical))
				var/obj/structure/filingcabinet/medical/records = object
				records.virgin = FALSE
			if(istype(object, /obj/machinery/disposal))
				var/obj/machinery/disposal/disposal = object
				disposal.air_contents?.gases.Cut()
			if(istype(object, /obj/machinery/power/apc))
				var/obj/machinery/power/apc/controller = object
				controller.cell = null
			if(istype(object, /obj/machinery/atmospherics/components/unary/shuttle/heater))
				var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = object
				heater.fuel_tank = null
