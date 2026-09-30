/// Saves, deletes and rebuilds every purchasable ship class in a real bay. A class that loses
/// fittings or rebuilds with free supplies fails here; engine fuel is reported, not enforced.
/datum/unit_test/voidcrew_checkpoints/every_ship

/datum/unit_test/voidcrew_checkpoints/every_ship/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "everyshipfounder"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/mob/living/carbon/human/captain = make_player(run_loc_floor_bottom_left, "everyshipcaptain")
	var/list/report = list()
	var/position = 0
	for(var/label in SSmapping.ship_purchase_list)
		var/template_type = SSmapping.ship_purchase_list[label]
		var/datum/map_template/shuttle/voidcrew/template_path = template_type
		if(initial(template_path.abstract) == template_type || ispath(template_type, /datum/map_template/shuttle/voidcrew/commissioned))
			continue
		if(!voidcrew_test_shard_takes(++position))
			continue
		log_world("EVERY_SHIP begin [template_type]")
		report += "[template_type]: [check_ship(home, captain, template_type)]"
		log_world("EVERY_SHIP end [template_type]")
	log_test("Checkpoint round trip of every ship class:\n[report.Join("\n")]")

/// Returns a one-line summary; problems that break the no-free-supplies rule fail the test.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/check_ship(obj/structure/overmap/dynamic/player_outpost/registry_test/home, mob/living/carbon/human/captain, template_type, list/selections, datum/ship_theme/theme)
	var/obj/structure/overmap/ship/original = SSshuttle.create_ship(template_type, selections, theme)
	if(!original)
		TEST_FAIL("[template_type] could not be spawned")
		return "could not spawn"
	test_ships += original
	original.enlist_crewmember(captain)
	original.claimed_captain = captain.mind
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(original)
	if(!bay)
		qdel(original)
		return "skipped: no bay could take it"
	adjust_reserve_dock_to_shuttle(bay.dock, original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	var/docked = original.shuttle.initiate_docking(bay.dock)
	original.shuttle.mode = SHUTTLE_IDLE
	if(docked != DOCKING_SUCCESS)
		home.on_ship_undock_complete(original)
		qdel(original)
		return "skipped: does not fit the bay ([docked])"
	original.docked = home
	original.forceMove(home)
	original.state = "idle"
	bay.on_ship_docked(original)
	var/datum/ship_checkpoint/snapshot = new
	var/denial = snapshot.capture(original, captain)
	if(denial)
		qdel(snapshot)
		original.shuttle.admin_delete_shuttle()
		return "not saved: [denial]"
	snapshot.outpost = home
	home.checkpoints += snapshot
	original.checkpoint_ref = WEAKREF(snapshot)
	var/list/before_counts = count_hull(original.shuttle)
	var/list/dropped = list()
	var/list/without_board = list()
	for(var/turf/tile as anything in original.shuttle.return_turfs())
		if(!(get_area(tile) in original.shuttle.shuttle_areas))
			continue
		for(var/obj/object in tile)
			if(!outpost_checkpoint_saves(object))
				if(ismachinery(object) || isstructure(object))
					dropped["[object.type]"]++
			else if(ismachinery(object))
				var/obj/machinery/machine = object
				if(machine.checkpoint_type() == machine.type && !istype(machine.circuit) && !is_type_in_typecache(machine, GLOB.outpost_checkpoint_infrastructure))
					without_board["[machine.type]"] = TRUE
	settle_networks()
	var/list/before_plumbing = plumbing_state(original.shuttle)
	var/list/before_atmos = atmos_problems(original.shuttle)
	// Lose the original away from the bay, as a real one is. Deleting it on the pad would leave
	// what its fittings drop on deletion (duct stacks, crate tanks) under the rebuilt hull.
	if(!leave_bay(original, home, template_type))
		return "the original could not leave the bay"
	log_world("EVERY_SHIP rebuild [template_type]")
	var/datum/checkpoint_construction/job = new(null, snapshot, captain, TRUE)
	if(!job.prepare())
		TEST_FAIL("[template_type]: the rebuild did not start: [job.error]")
		return "rebuild failed: [job.error]"
	job.fast_forward()
	if(!QDELETED(job))
		job.hand_over_now()
	var/obj/structure/overmap/ship/rebuilt = bay.ship
	if(!QDELETED(job) || !rebuilt)
		TEST_FAIL("[template_type]: the rebuild was not handed over")
		return "not handed over"
	test_ships += rebuilt
	var/list/after_counts = count_hull(rebuilt.shuttle)
	for(var/type_name in (before_counts | after_counts))
		if(before_counts[type_name] != after_counts[type_name])
			TEST_FAIL("[template_type]: [type_name] expected [before_counts[type_name]], rebuilt [after_counts[type_name]]")
	log_world("EVERY_SHIP check [template_type]")
	// Pipe gas is judged at handover, before atmos runs: after that, siphons and outlets
	// legitimately draw room and hangar air into their networks.
	for(var/problem in pipe_gas_at_handover(rebuilt.shuttle))
		TEST_FAIL("[template_type]: [problem]")
	settle_networks()
	// The rebuild must leave pipes and ducts joined up exactly as well as the original had them.
	var/list/after_plumbing = plumbing_state(rebuilt.shuttle)
	for(var/key in (before_plumbing | after_plumbing))
		if(before_plumbing[key] != after_plumbing[key])
			TEST_FAIL("[template_type]: plumbing [key] was [before_plumbing[key] || 0], rebuilt [after_plumbing[key] || 0]")
	var/list/after_atmos = atmos_problems(rebuilt.shuttle)
	if(length(after_atmos) > length(before_atmos))
		TEST_FAIL("[template_type]: the rebuild broke pipe connections ([length(before_atmos)] problems before, [length(after_atmos)] after): [after_atmos.Join("; ")]")
	for(var/problem in stock_problems(rebuilt.shuttle))
		TEST_FAIL("[template_type]: [problem]")
	var/engines = 0
	var/list/unfuelled = list()
	for(var/obj/machinery/power/shuttle_engine/ship/engine in rebuilt.shuttle.engine_list)
		engines++
		if((istype(engine, /obj/machinery/power/shuttle_engine/ship/fueled) || istype(engine, /obj/machinery/power/shuttle_engine/ship/liquid)) && !engine_is_full(engine))
			unfuelled["[engine.type]"]++
			TEST_FAIL("[template_type]: [engine.type] came back with [engine.return_fuel()] fuel, not full")
	var/list/summary = list("rebuilt, [engines] engine(s)")
	if(length(unfuelled))
		summary += "NO FUEL: [list_counts(unfuelled)]"
	if(length(dropped))
		summary += "left out: [list_counts(dropped)]"
	if(length(without_board))
		var/list/names = list()
		for(var/type_name in without_board)
			names += type_name
		summary += "saved without a board: [names.Join(", ")]"
	leave_bay(rebuilt, home, template_type)
	return summary.Join("; ")


/datum/unit_test/voidcrew_checkpoints/every_ship/proc/list_counts(list/counts)
	var/list/parts = list()
	for(var/key in counts)
		parts += "[key] x[counts[key]]"
	return parts.Join(", ")

/// Everything a rebuild must not hand out for free.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/stock_problems(obj/docking_port/mobile/port)
	. = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/item/item in tile.get_all_contents())
			if(ismachinery(item.loc))
				var/obj/machinery/machine = item.loc
				if((item in machine.component_parts) || item == machine.circuit || istype(item, /obj/item/radio))
					continue
				if(istype(machine, /obj/machinery/power/apc))
					var/obj/machinery/power/apc/controller = machine
					if(item == controller.cell)
						continue
				if(istype(machine, /obj/machinery/atmospherics/components/unary/shuttle/heater))
					var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = machine
					if(item == heater.fuel_tank)
						continue
				if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship))
					continue
			if(istype(item, /obj/item/encryptionkey) && istype(item.loc, /obj/item/radio))
				continue
			. += "free item [item.type] in [item.loc?.type]"
		for(var/obj/object in tile)
			// Engine fuel and the basics (fuel and water tanks, plumbing) are restocked on purpose.
			if(object.reagents?.total_volume && !is_type_in_typecache(object, GLOB.outpost_checkpoint_restocked) && !istype(object, /obj/machinery/power/shuttle_engine))
				. += "[object.type] holds [object.reagents.total_volume] units of reagents"
			var/datum/component/material_container/materials = object.GetComponent(/datum/component/material_container)
			if(materials?.total_amount())
				. += "[object.type] holds [materials.total_amount()] units of materials"
			if(istype(object, /obj/machinery/atmospherics/components/tank) && !is_type_in_typecache(object, GLOB.outpost_checkpoint_restocked))
				var/obj/machinery/atmospherics/components/tank/stored = object
				if(stored.air_contents?.total_moles())
					. += "[object.type] holds [stored.air_contents.total_moles()] moles"
			if(istype(object, /obj/machinery/vending))
				var/obj/machinery/vending/vendor = object
				for(var/datum/data/vending_product/product as anything in vendor.product_records + vendor.hidden_records + vendor.coin_records)
					if(product.amount)
						. += "[object.type] stocks [product.amount] [product.name]"
						break

/// Sends a ship to transit and deletes it there, so nothing its fittings drop lands in the bay.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/leave_bay(obj/structure/overmap/ship/ship, obj/structure/overmap/dynamic/player_outpost/registry_test/home, template_type)
	var/obj/docking_port/stationary/transit/transit = ship.shuttle.assigned_transit || SSshuttle.generate_transit_dock(ship.shuttle)
	ship.shuttle.mode = SHUTTLE_PREARRIVAL
	var/left = ship.shuttle.initiate_docking(transit)
	ship.shuttle.mode = SHUTTLE_IDLE
	if(left != DOCKING_SUCCESS)
		TEST_FAIL("[template_type]: [ship] could not leave the bay ([left])")
		return FALSE
	ship.docked = null
	ship.forceMove(get_turf(home))
	ship.state = "flying"
	home.on_ship_undock_complete(ship)
	if(!ship.shuttle.admin_delete_shuttle())
		TEST_FAIL("[template_type]: [ship] could not be removed")
		return FALSE
	return TRUE

/// Lets atmospherics finish rebuilding pipe networks, and ducts their queued connections.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/settle_networks()
	var/deadline = world.time + 10 SECONDS
	while((length(SSair.rebuild_queue) || length(SSair.expansion_queue)) && world.time < deadline)
		sleep(1)
	sleep(2)

/// How the hull's ducts and plumbed machines are joined up.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/plumbing_state(obj/docking_port/mobile/port)
	var/list/state = list()
	var/list/datum/ductnet/nets = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/machinery/duct/duct in tile)
			state["ducts"]++
			if(duct.duct)
				nets |= duct.duct
			else
				state["ducts outside any network"]++
		for(var/obj/machinery/machine in tile)
			for(var/datum/component/plumbing/plumber as anything in machine.GetComponents(/datum/component/plumbing))
				state["plumbed machines"]++
				// A mapped machine switches its plumbing on even when loose; a rebuilt one only
				// reconnects once anchored, as in play. Only anchored machines must match.
				if(!machine.anchored)
					state["unanchored plumbed machines"]++
					continue
				if(!plumber.active)
					state["inactive plumbed machines"]++
					state["inactive [machine.type]"]++
				for(var/direction in plumber.ducts)
					state["machine connections"]++
					nets |= plumber.ducts[direction]
	if(length(nets))
		state["duct networks"] = length(nets)
	return state

/// Every one-way pipe link, and every connected port or pipe left without a network.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/atmos_problems(obj/docking_port/mobile/port)
	var/list/problems = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/machinery/machine in tile)
			for(var/obj/machinery/atmospherics/connector as anything in machine.checkpoint_atmos_parts())
				if(connector.loc != tile)
					problems += "[machine.type] at [COORD(machine)] lost its pipe connector to [COORD(connector)]"
		for(var/obj/machinery/atmospherics/device in tile)
			for(var/obj/machinery/atmospherics/node as anything in device.nodes)
				if(node && !(device in node.nodes))
					problems += "[device.type] at [COORD(device)] links one way to [node.type] at [COORD(node)]"
			if(istype(device, /obj/machinery/atmospherics/components))
				var/obj/machinery/atmospherics/components/component = device
				for(var/i in 1 to component.device_type)
					if(!component.nodes[i])
						continue
					var/datum/pipeline/net = component.parents[i]
					if(!net || !(component.airs[i] in net.other_airs))
						problems += "[device.type] at [COORD(device)] port [i] has no network"
			else if(istype(device, /obj/machinery/atmospherics/pipe))
				var/obj/machinery/atmospherics/pipe/pipe = device
				if(!pipe.parent || !(pipe in pipe.parent.members))
					problems += "[device.type] at [COORD(device)] has no network"
	return problems

/// Every theme of every modular hull, and within each theme every module it can take, so each
/// themed module file is saved and rebuilt at least once. Slow: about one round trip per option.
/datum/unit_test/voidcrew_checkpoints/every_ship/every_variant

/datum/unit_test/voidcrew_checkpoints/every_ship/every_variant/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "everyvariantfounder"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/mob/living/carbon/human/captain = make_player(run_loc_floor_bottom_left, "everyvariantcaptain")
	var/list/report = list()
	var/position = 0
	for(var/label in SSmapping.ship_purchase_list)
		var/template_type = SSmapping.ship_purchase_list[label]
		var/datum/map_template/shuttle/voidcrew/template_path = template_type
		if(initial(template_path.abstract) == template_type || ispath(template_type, /datum/map_template/shuttle/voidcrew/commissioned))
			continue
		var/list/themes = get_themes_for_ship(template_type)
		// A hull with modules but no themes still gets its modules covered, themeless.
		var/list/theme_ids = length(themes) ? themes : list(null)
		for(var/theme_id in theme_ids)
			var/datum/ship_theme/theme = theme_id ? themes[theme_id] : null
			var/list/by_slot = list()
			var/list/modules = get_modules_for_ship_theme(template_type, theme_id)
			for(var/module_id in modules)
				var/datum/ship_upgrade_module/module = modules[module_id]
				LAZYADD(by_slot[module.slot], module)
			var/configurations = 1
			for(var/slot_key in by_slot)
				configurations = max(configurations, length(by_slot[slot_key]))
			for(var/configuration in 1 to configurations)
				var/list/selections = list()
				for(var/slot_key in by_slot)
					var/list/options = by_slot[slot_key]
					selections[slot_key] = options[(configuration - 1) % length(options) + 1]
				if(!voidcrew_test_shard_takes(++position))
					continue
				var/variant = "[template_type] theme [theme_id] #[configuration]"
				log_world("EVERY_SHIP begin [variant]")
				report += "[variant]: [check_ship(home, captain, template_type, selections, theme)]"
				log_world("EVERY_SHIP end [variant]")
	log_test("Checkpoint round trip of every theme and module:\n[report.Join("\n")]")

/// Gas anywhere in the rebuilt pipes the moment the hull is handed over. Restocked tanks keep
/// their own gas; nothing has run yet to share it.
/datum/unit_test/voidcrew_checkpoints/every_ship/proc/pipe_gas_at_handover(obj/docking_port/mobile/port)
	. = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/machinery/atmospherics/machine in tile)
			if(is_type_in_typecache(machine, GLOB.outpost_checkpoint_restocked))
				continue
			var/moles = 0
			if(istype(machine, /obj/machinery/atmospherics/pipe))
				var/obj/machinery/atmospherics/pipe/pipe = machine
				moles += pipe.air_temporary?.total_moles()
			if(istype(machine, /obj/machinery/atmospherics/components))
				var/obj/machinery/atmospherics/components/component = machine
				for(var/datum/gas_mixture/mix as anything in component.airs)
					moles += mix?.total_moles()
			for(var/datum/pipeline/network as anything in machine.return_pipenets())
				moles += network?.air?.total_moles()
			if(moles > 0)
				. += "[machine.type] holds [moles] moles of gas at handover"
