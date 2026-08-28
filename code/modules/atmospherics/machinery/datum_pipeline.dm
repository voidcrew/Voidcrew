/datum/pipeline
	/// The gases contained within this pipeline
	var/datum/gas_mixture/air
	/// The gas_mixtures of objects directly connected to this pipeline
	var/list/datum/gas_mixture/other_airs

	var/list/obj/machinery/atmospherics/pipe/members
	var/list/obj/machinery/atmospherics/components/other_atmos_machines
	/// List of other_atmos_machines that have custom_reconcilation set
	/// We're essentially caching this to avoid needing to filter over it when processing our machines
	var/list/obj/machinery/atmospherics/components/require_custom_reconcilation

	/// The weighted color blend of the gas mixture in this pipeline
	var/gasmix_color
	/// A named list of icon_file:overlay_object that gets automatically colored when the gasmix_color updates
	var/list/gas_visuals

	///Should we equalize air amoung all our members?
	var/update = TRUE
	///Is this pipeline being reconstructed?
	var/building = FALSE
	/// VOIDCREW ADDITION: consecutive orphan sweeps this pipeline has been found with no
	/// live members on. Reset the moment it has any. See SSair.reap_orphan_pipelines().
	var/orphan_strikes = 0

/**
 * VOIDCREW ADDITION: TRUE if anything real is still attached to this pipeline.
 *
 * Not the same question as `length(members)`. When a machine is hard deleted its entries
 * in these lists are nulled in place rather than removed, so a pipeline that has lost
 * everything still reads as length 1 with a null inside. `as anything` is deliberate for
 * exactly that reason - a typed loop would silently filter the nulls out and hide the
 * distinction we are trying to measure.
 */
/datum/pipeline/proc/has_live_members()
	for(var/obj/machinery/atmospherics/member as anything in members)
		if(!isnull(member) && !QDELETED(member))
			return TRUE
	for(var/obj/machinery/atmospherics/machine as anything in other_atmos_machines)
		if(!isnull(machine) && !QDELETED(machine))
			return TRUE
	return FALSE

/datum/pipeline/New()
	other_airs = list()
	members = list()
	other_atmos_machines = list()
	require_custom_reconcilation = list()
	gas_visuals = list()
	SSair.networks += src

/datum/pipeline/Destroy()
	SSair.networks -= src
	// VOIDCREW EDIT: never leave a destroyed pipeline parked in the husk reaper's list.
	SSair.pipeline_husks -= src
	if(building)
		SSair.remove_from_expansion(src)
	if(air?.volume)
		temporarily_store_air()
	// VOIDCREW EDIT: both loops below run cleanup that prunes the very list being
	// walked (replace_pipenet() drops the pipe from our members, nullify_pipenet()
	// removes the component from other_atmos_machines) - a for-in over the live list
	// skips every other entry when the current one is removed. Detach the lists first.
	var/list/dying_members = members
	members = list()
	for(var/obj/machinery/atmospherics/pipe/considered_pipe in dying_members)
		// Only sever pipes that are still ours: a pipe already rebuilt into a LIVE
		// pipeline (the build_pipeline steal) must not have its new parent nulled -
		// the old code passed considered_pipe.parent here and did exactly that,
		// leaving the live pipeline holding a pipe that no longer pointed back.
		if(considered_pipe.parent == src)
			considered_pipe.replace_pipenet(src, null)
		if(QDELETED(considered_pipe))
			continue
		SSair.add_to_rebuild_queue(considered_pipe)
	var/list/dying_machines = other_atmos_machines
	other_atmos_machines = list()
	for(var/obj/machinery/atmospherics/components/considered_component in dying_machines)
		considered_component.nullify_pipenet(src)
	other_airs.Cut()
	require_custom_reconcilation.Cut()
	// Every dead pipeline otherwise leaks its gas overlay objects, each holding a live
	// animate() color filter; qdel'ing them also detaches them from any pipe
	// vis_contents still showing them
	QDEL_LIST_ASSOC_VAL(gas_visuals)
	return ..()

/datum/pipeline/process()
	if(!update || building)
		return
	reconcile_air()
	//Only react if the mix has changed, and don't keep updating if it hasn't
	update = air.react(src)
	CalculateGasmixColor(air)

/datum/pipeline/proc/set_air(datum/gas_mixture/new_air)
	if(new_air == air)
		return
	air = new_air
	CalculateGasmixColor(air)

///Preps a pipeline for rebuilding, insterts it into the rebuild queue
/datum/pipeline/proc/build_pipeline(obj/machinery/atmospherics/base)
	building = TRUE
	var/volume = 0
	if(istype(base, /obj/machinery/atmospherics/pipe))
		var/obj/machinery/atmospherics/pipe/considered_pipe = base
		volume = considered_pipe.volume
		members += considered_pipe
		if(considered_pipe.air_temporary)
			set_air(considered_pipe.air_temporary)
			considered_pipe.air_temporary = null
	else
		add_machinery_member(base)

	if(!air)
		set_air(new /datum/gas_mixture)

	air.volume = volume
	SSair.add_to_expansion(src, base)

///Has the same effect as build_pipeline(), but this doesn't queue its work, so overrun abounds. It's useful for the pregame
/datum/pipeline/proc/build_pipeline_blocking(obj/machinery/atmospherics/base)
	var/volume = 0
	if(istype(base, /obj/machinery/atmospherics/pipe))
		var/obj/machinery/atmospherics/pipe/considered_pipe = base
		volume = considered_pipe.volume
		members += considered_pipe
		if(considered_pipe.air_temporary)
			set_air(considered_pipe.air_temporary)
			considered_pipe.air_temporary = null
	else
		add_machinery_member(base)

	if(!air)
		set_air(new /datum/gas_mixture)
	var/list/possible_expansions = list(base)
	while(possible_expansions.len)
		for(var/obj/machinery/atmospherics/borderline in possible_expansions)
			var/list/result = borderline.pipeline_expansion(src)
			if(!result?.len)
				possible_expansions -= borderline
				continue
			for(var/obj/machinery/atmospherics/considered_device in result)
				if(!istype(considered_device, /obj/machinery/atmospherics/pipe))
					// VOIDCREW EDIT: only register what actually attached. set_pipenet()
					// refuses a one-way node link, and registering anyway put a component
					// in other_atmos_machines with no matching air in other_airs - which
					// add_machinery_member() below then stack_traces about.
					if(considered_device.set_pipenet(src, borderline))
						add_machinery_member(considered_device)
					continue
				var/obj/machinery/atmospherics/pipe/item = considered_device
				if(members.Find(item))
					continue
				if(item.parent)
					var/static/pipenetwarnings = 10
					if(pipenetwarnings > 0)
						var/area/our_area = get_area(borderline)
						log_mapping("build_pipeline(): [item.type] added to a pipenet while still having one. (pipes leading to the same spot stacking in one turf) around [AREACOORD(item)] in [our_area.type].")
						pipenetwarnings--
						if(pipenetwarnings == 0)
							log_mapping("build_pipeline(): further messages about pipenets will be suppressed")

				members += item
				possible_expansions += item

				volume += item.volume
				item.replace_pipenet(item.parent, src)

				if(item.air_temporary)
					air.merge(item.air_temporary)
					item.air_temporary = null

			possible_expansions -= borderline

	air.volume = volume

	/**
	 *  For a machine to properly "connect" to a pipeline and share gases,
	 *  the pipeline needs to acknowledge a gas mixture as its member.
	 *  This is currently handled by the other_airs list in the pipeline datum.
	 *
	 *	Other_airs itself is populated by gas mixtures through the parents list that each machineries have.
	 *	This parents list is populated when a machinery calls update_parents and is then added into the queue by the controller.
	 */

/datum/pipeline/proc/add_machinery_member(obj/machinery/atmospherics/components/considered_component)
	other_atmos_machines |= considered_component
	if(considered_component.custom_reconcilation)
		require_custom_reconcilation |= considered_component
	var/list/returned_airs = considered_component.return_pipenet_airs(src)
	if (!length(returned_airs) || (null in returned_airs))
		stack_trace("addMachineryMember: Nonexistent (empty list) or null machinery gasmix added to pipeline datum from [considered_component] \
		which is of type [considered_component.type]. Nearby: ([considered_component.x], [considered_component.y], [considered_component.z])")
		// VOIDCREW EDIT: and then DROP the nulls instead of carrying them in. Upstream warned
		// and merged anyway, which parks a null in other_airs permanently - reconcile_air()
		// walks that list every time the pipenet processes and reads gas_mixture.pipeline_cycle
		// off it, so one bad attach is a runtime per pipeline per tick for the rest of the round.
		list_clear_nulls(returned_airs)
	other_airs |= returned_airs

/datum/pipeline/proc/add_member(obj/machinery/atmospherics/reference_device, obj/machinery/atmospherics/device_to_add)
	if(!istype(reference_device, /obj/machinery/atmospherics/pipe))
		// VOIDCREW EDIT: honour a refused attach, same as build_pipeline_blocking() above.
		if(reference_device.set_pipenet(src, device_to_add))
			add_machinery_member(reference_device)
	else
		var/obj/machinery/atmospherics/pipe/reference_pipe = reference_device
		if(reference_pipe.parent)
			merge(reference_pipe.parent)
		reference_pipe.replace_pipenet(reference_pipe.parent, src)
		var/list/adjacent = reference_pipe.pipeline_expansion()
		for(var/obj/machinery/atmospherics/pipe/adjacent_pipe in adjacent)
			if(adjacent_pipe.parent == src)
				continue
			var/datum/pipeline/parent_pipeline = adjacent_pipe.parent
			merge(parent_pipeline)
		if(!members.Find(reference_pipe))
			members += reference_pipe
			air.volume += reference_pipe.volume

/datum/pipeline/proc/merge(datum/pipeline/parent_pipeline)
	if(parent_pipeline == src)
		return
	air.volume += parent_pipeline.air.volume
	// VOIDCREW EDIT: detach before iterating - replace_pipenet() now prunes the pipe
	// out of its old pipeline's members in place, which would skip entries walking the
	// live list. |= rather than Add(): a build_pipeline steal can leave a pipe listed
	// in both pipelines at once, and concatenating duplicated the shared pipes into
	// the survivor's members (each duplicate = one permanent GC-blocking ref).
	var/list/merged_members = parent_pipeline.members
	parent_pipeline.members = list()
	members |= merged_members
	for(var/obj/machinery/atmospherics/pipe/reference_pipe in merged_members)
		reference_pipe.replace_pipenet(reference_pipe.parent, src)
	air.merge(parent_pipeline.air)
	// VOIDCREW EDIT: honour a refused re-parent, same contract as set_pipenet()/add_member()
	// above. A component that was never actually on parent_pipeline must not be carried
	// into our other_atmos_machines - it would sit there registered with no matching
	// gasmix in other_airs, which is exactly the inconsistency add_machinery_member()
	// stack_traces about. A component that is ALREADY ours is unaffected: |= never removes.
	// Iterate `as anything` and type-check inside, so non-component members - gas miners
	// are /obj/machinery/atmospherics direct subtypes, not /components - are still carried
	// across untouched, exactly as the old blanket |= did.
	for(var/obj/machinery/atmospherics/machine as anything in parent_pipeline.other_atmos_machines)
		var/obj/machinery/atmospherics/components/reference_component = machine
		if(istype(reference_component))
			if(!reference_component.replace_pipenet(parent_pipeline, src))
				continue
			if(reference_component.custom_reconcilation)
				require_custom_reconcilation |= reference_component
		other_atmos_machines |= machine
	other_airs |= parent_pipeline.other_airs
	parent_pipeline.other_atmos_machines.Cut()
	parent_pipeline.require_custom_reconcilation.Cut()
	update = TRUE
	qdel(parent_pipeline)

/obj/machinery/atmospherics/proc/add_member(obj/machinery/atmospherics/considered_device)
	return

/obj/machinery/atmospherics/pipe/add_member(obj/machinery/atmospherics/considered_device)
	parent.add_member(considered_device, src)

/obj/machinery/atmospherics/components/add_member(obj/machinery/atmospherics/considered_device)
	var/datum/pipeline/device_pipeline = return_pipenet(considered_device)
	// VOIDCREW EDIT: refuse rather than CRASH. return_pipenet() answers null when we hold no
	// port facing considered_device - the one-way node link two pipes stacked on one turf
	// produce, and the pre-init window this fork opens by docking ships before SSatoms runs.
	// A CRASH() here is a runtime like any other: it unwinds the whole stack, which in every
	// logged case was a hull's lateShuttleMove() rebuilding its pipes, so one badly stacked
	// pipe took the rest of that ship's pipe graph down with it. Every caller of add_member()
	// (on_construction(), connect_nodes(), the shuttle-move reconnect in components_base.dm)
	// queues a rebuild straight afterwards; queue one here too, so the paths that do not still
	// get a second chance once the node graph is finished.
	if(!device_pipeline)
		SSair.add_to_rebuild_queue(src)
		return
	device_pipeline.add_member(considered_device, src)


/datum/pipeline/proc/temporarily_store_air()
	//Update individual gas_mixtures by volume ratio

	for(var/obj/machinery/atmospherics/pipe/member in members)
		member.air_temporary = new
		member.air_temporary.volume = member.volume
		member.air_temporary.copy_from_ratio(air, member.volume / air.volume)

		member.air_temporary.temperature = air.temperature

/datum/pipeline/proc/temperature_interact(turf/target, share_volume, thermal_conductivity)
	var/total_heat_capacity = air.heat_capacity()
	var/partial_heat_capacity = total_heat_capacity * (share_volume / air.volume)

	var/turf_temperature = target.GetTemperature()
	var/turf_heat_capacity = target.GetHeatCapacity()

	if(turf_heat_capacity <= 0 || partial_heat_capacity <= 0)
		return TRUE

	var/delta_temperature = turf_temperature - air.temperature

	var/heat = thermal_conductivity * CALCULATE_CONDUCTION_ENERGY(delta_temperature, partial_heat_capacity, turf_heat_capacity)
	air.temperature += heat / total_heat_capacity
	target.TakeTemperature(-1 * heat / turf_heat_capacity)

	if(target.blocks_air)
		target.temperature_expose(air, target.temperature)
	update = TRUE

/datum/pipeline/proc/return_air()
	. = other_airs + air
	if(list_clear_nulls(.))
		stack_trace("[src] has one or more null gas mixtures, which may cause bugs. Null mixtures will not be considered in reconcile_air().")

/// Called when the pipenet needs to update and mix together all the air mixes
/datum/pipeline/proc/reconcile_air()
	var/list/datum/gas_mixture/gas_mixture_list = list()
	var/list/datum/pipeline/pipeline_list = list()
	pipeline_list += src

	for(var/i = 1; i <= pipeline_list.len; i++) //can't do a for-each here because we may add to the list within the loop
		var/datum/pipeline/pipeline = pipeline_list[i]
		if(!pipeline)
			continue
		gas_mixture_list += pipeline.other_airs
		gas_mixture_list += pipeline.air
		for(var/obj/machinery/atmospherics/components/atmos_machine as anything in pipeline.require_custom_reconcilation)
			pipeline_list |= atmos_machine.return_pipenets_for_reconcilation(src)
			gas_mixture_list += atmos_machine.return_airs_for_reconcilation(src)

	var/total_thermal_energy = 0
	var/total_heat_capacity = 0

	var/volume_sum = 0

	// VOIDCREW EDIT ADDITION: a null in here is fatal to the loop below ("Cannot read
	// null.pipeline_cycle"), and three of the four sources can supply one: other_airs on any
	// pipeline in the chain, a pipeline whose own air has not been minted yet, and whatever a
	// custom-reconcilation machine hands back. return_air() already sanitises the same pair
	// for its own callers; do it once here for the whole gathered set instead of null-checking
	// inside the hot loop.
	list_clear_nulls(gas_mixture_list)

	var/static/process_id = 0
	process_id = WRAP_UID(process_id + 1)
	var/datum/gas_mixture/total_gas_mixture = new
	var/list/total_cached_moles = total_gas_mixture.moles
	var/list/cached_specific_heat = GAS_META[META_GAS_SPECIFIC_HEAT]

	for(var/datum/gas_mixture/gas_mixture as anything in gas_mixture_list)
		// Ensure we never walk the same mix twice
		if(gas_mixture.pipeline_cycle == process_id)
			gas_mixture_list -= gas_mixture
			continue
		gas_mixture.pipeline_cycle = process_id
		volume_sum += gas_mixture.volume

		// This is sort of a combined merge + heat_capacity calculation

		var/list/giver_cached_moles = gas_mixture.moles
		var/heat_capacity = values_dot(giver_cached_moles, cached_specific_heat)
		//gas transfer
		for(var/gas_id, amount in giver_cached_moles)
			total_cached_moles[gas_id] += amount

		total_heat_capacity += heat_capacity
		total_thermal_energy += gas_mixture.temperature * heat_capacity

	if(volume_sum == 0)
		return

	total_gas_mixture.volume = volume_sum
	total_gas_mixture.temperature = total_heat_capacity ? (total_thermal_energy / total_heat_capacity) : 0
	total_gas_mixture.garbage_collect()

	//Update individual gas_mixtures by volume ratio
	for(var/datum/gas_mixture/gas_mixture as anything in gas_mixture_list)
		gas_mixture.copy_from_ratio(total_gas_mixture, gas_mixture.volume / volume_sum)

//--------------------
// GAS VISUALS STUFF
//
// Gas visuals use direct color + alpha on the gas_visual object rather than
// a color filter + KEEP_APART.
// Color filters are expensive.
// KEEP_APART forces a separate render.

/**
 * Used to create and/or get the gas visual overlay created using the given icon file.
 * The color is automatically kept up to date and expected to be used as a vis_contents object.
 */
/datum/pipeline/proc/GetGasVisual(icon/icon_file)
	if(gas_visuals[icon_file])
		return gas_visuals[icon_file]

	var/obj/effect/abstract/gas_visual/new_overlay = new
	new_overlay.icon = icon_file
	new_overlay.ChangeColor(gasmix_color)

	gas_visuals[icon_file] = new_overlay
	return new_overlay

/// Called when the gasmix color has changed and the gas visuals need to be updated.
/datum/pipeline/proc/UpdateGasVisuals()
	for(var/icon/source as anything in gas_visuals)
		var/obj/effect/abstract/gas_visual/overlay = gas_visuals[source]
		overlay.ChangeColor(gasmix_color)

/// After updating, this proc handles looking at the new gas mixture and blends the colors together according to percentage of the gas mix.
/datum/pipeline/proc/CalculateGasmixColor(datum/gas_mixture/source)
	SIGNAL_HANDLER

	var/current_weight = 0
	var/current_color
	for(var/datum/gas/gas_path as anything in air.moles)
		var/gas_weight = air.moles[gas_path]
		if(!gas_weight)
			continue
		var/gas_color = initial(gas_path.primary_color)
		current_weight += gas_weight
		if(!current_color)
			current_color = gas_color
		else
			current_color = BlendHSV(current_color, gas_color, gas_weight / current_weight)

	if(!current_color)
		current_color = COLOR_BLACK
	else
		// Empty weight is prety much arbitrary, just tuned to make the color change from black reasonably quickly without hitting max color immediately
		var/empty_weight = (air.volume * 1.5 - current_weight) / 10
		if(empty_weight > 0)
			current_color = BlendHSV(COLOR_BLACK, current_color, current_weight / (empty_weight + current_weight))

	if(gasmix_color != current_color)
		gasmix_color = current_color
		UpdateGasVisuals()

/obj/effect/abstract/gas_visual
	appearance_flags = RESET_COLOR
	vis_flags = VIS_INHERIT_ICON_STATE | VIS_INHERIT_LAYER | VIS_INHERIT_PLANE | VIS_INHERIT_ID
	color = COLOR_BLACK

/obj/effect/abstract/gas_visual/proc/ChangeColor(new_color)
	if(!new_color)
		new_color = COLOR_BLACK
	animate(src, color = new_color, time = 0.5 SECONDS)
