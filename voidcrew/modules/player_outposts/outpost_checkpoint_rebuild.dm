/datum/ship_checkpoint_ui/proc/rebuild_denial(mob/living/user, datum/ship_checkpoint/snapshot, allow_busy = FALSE)
	if(QDELETED(src) || ui_status(user, GLOB.always_state) != UI_INTERACTIVE)
		return "Checkpoint console unavailable."
	if(QDELETED(snapshot) || snapshot.outpost != outpost || !(snapshot in outpost.checkpoints))
		return "This checkpoint is no longer available."
	if(user.ckey != snapshot.captain_ckey)
		return "Only the captain who saved this hull can rebuild it."
	if(snapshot.busy && !allow_busy)
		return "This hull is already being rebuilt."
	var/obj/structure/overmap/ship/original = snapshot.source_ship?.resolve()
	if(original)
		if(original.retired_by_checkpoint)
			return "The original hull has already been replaced."
		if(original.checkpoint_rebuilding && !allow_busy)
			return "Recovery is already in progress."
		// A deleted physical hull can leave an overmap record behind. Its crew
		// roster alone must not prevent recovery of a ship that no longer exists.
		if(!QDELETED(original.shuttle) && !original.abandoned)
			return "The original hull must be lost or abandoned."
	if(!allow_busy && !outpost.available_ship_bay())
		return "The ship bay is occupied or reserved."
	return null

/// Starts staged reconstruction. Returns TRUE once the hidden copy is loaded and marked out.
/datum/ship_checkpoint_ui/proc/rebuild(mob/living/user, datum/ship_checkpoint/snapshot)
	error = rebuild_denial(user, snapshot)
	if(error || working)
		return FALSE
	notice = null
	working = TRUE
	// The job claims the bay and both hulls before waiting for the shared shuttle loader.
	var/datum/checkpoint_construction/job = create_rebuild_job(user, snapshot)
	var/started = FALSE
	if(job.bay)
		started = job.prepare()
	else
		job.error = "The ship bay is occupied or reserved."
		qdel(job)
	if(!QDELETED(src))
		working = FALSE
		if(started)
			error = null
			notice = "Reconstruction started."
		else
			error = job.error || "Rebuild failed. Your checkpoint is still available."
	return started

/datum/ship_checkpoint_ui/proc/create_rebuild_job(mob/living/user, datum/ship_checkpoint/snapshot)
	return new /datum/checkpoint_construction(src, snapshot, user)

/// Basics a rebuilt ship keeps as they load, full: breathable air and engine plasma tanks,
/// welding fuel and water tanks, and plumbing water. Every other supply is scrubbed.
GLOBAL_LIST_INIT(outpost_checkpoint_restocked, typecacheof(list(
	/obj/machinery/atmospherics/components/tank/air,
	/obj/machinery/atmospherics/components/tank/oxygen,
	/obj/machinery/atmospherics/components/tank/nitrogen,
	/obj/machinery/atmospherics/components/tank/plasma,
	/obj/structure/reagent_dispensers/fueltank,
	/obj/structure/reagent_dispensers/watertank,
	/obj/machinery/shower,
	/obj/structure/sink,
)))

/datum/checkpoint_construction/proc/clear_stock(obj/docking_port/mobile/voidcrew/source_port)
	for(var/turf/tile as anything in source_port.return_turfs())
		if(!(get_area(tile) in source_port.shuttle_areas))
			continue
		for(var/atom/movable/object as anything in tile.get_all_contents())
			if(QDELETED(object))
				continue
			var/restocked = is_type_in_typecache(object, GLOB.outpost_checkpoint_restocked)
			if(!restocked)
				object.reagents?.clear_reagents()
			if(isitem(object) && is_machine_fitting(object))
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
