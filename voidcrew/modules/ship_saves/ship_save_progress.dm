/**
 * What a paid-for save keeps beyond the hull: the stock parts in upgraded machines on the price table, and one
 * R&D server's research. The carried funds are in the payload too, but nothing has to be done to the hull
 * for those. Everything here is what the map text can't say, stored as text so saves outlive code changes.
 */

/// Power parts a priced machine can come back with. Exact types: no unique, rigged or self-charging cell.
GLOBAL_LIST_INIT(ship_save_kept_power_parts, typecacheof(list(
	/obj/item/stock_parts/power_store/cell,
	/obj/item/stock_parts/power_store/cell/empty,
	/obj/item/stock_parts/power_store/cell/upgraded,
	/obj/item/stock_parts/power_store/cell/upgraded/plus,
	/obj/item/stock_parts/power_store/cell/high,
	/obj/item/stock_parts/power_store/cell/high/empty,
	/obj/item/stock_parts/power_store/cell/super,
	/obj/item/stock_parts/power_store/cell/super/empty,
	/obj/item/stock_parts/power_store/cell/hyper,
	/obj/item/stock_parts/power_store/cell/hyper/empty,
	/obj/item/stock_parts/power_store/cell/bluespace,
	/obj/item/stock_parts/power_store/cell/bluespace/empty,
	/obj/item/stock_parts/power_store/battery,
	/obj/item/stock_parts/power_store/battery/empty,
	/obj/item/stock_parts/power_store/battery/upgraded,
	/obj/item/stock_parts/power_store/battery/high,
	/obj/item/stock_parts/power_store/battery/high/empty,
	/obj/item/stock_parts/power_store/battery/super,
	/obj/item/stock_parts/power_store/battery/super/empty,
	/obj/item/stock_parts/power_store/battery/hyper,
	/obj/item/stock_parts/power_store/battery/hyper/empty,
	/obj/item/stock_parts/power_store/battery/bluespace,
	/obj/item/stock_parts/power_store/battery/bluespace/empty,
), only_root_path = TRUE))

/**
 * Whether a machine holds a stock part above tier 1, or a kept cell that holds more than the one its board
 * comes with. Only these are charged for and only these carry their parts, so a stock machine saves for
 * free and comes back the same.
 */
/proc/ship_save_machine_upgraded(obj/machinery/machine)
	SHOULD_NOT_SLEEP(TRUE)
	for(var/part in machine.component_parts)
		if(istype(part, /datum/stock_part))
			var/datum/stock_part/stock_part = part
			if(stock_part.tier > 1)
				return TRUE
		else if(istype(part, /obj/item/stock_parts/power_store))
			var/obj/item/stock_parts/power_store/power_part = part
			if(GLOB.ship_save_kept_power_parts[power_part.type] && power_part.maxcharge > ship_save_default_charge(machine, power_part))
				return TRUE
	return FALSE

/// How much the cell a machine's board puts in this power part's slot holds.
/proc/ship_save_default_charge(obj/machinery/machine, obj/item/stock_parts/power_store/power_part)
	SHOULD_NOT_SLEEP(TRUE)
	var/obj/item/stock_parts/power_store/default_type = istype(power_part, /obj/item/stock_parts/power_store/battery) ? /obj/item/stock_parts/power_store/battery : /obj/item/stock_parts/power_store/cell
	var/obj/item/circuitboard/machine/board = machine.circuit
	if(istype(board))
		for(var/slot_type in board.req_components)
			if(ispath(slot_type, /obj/item/stock_parts/power_store) && istype(power_part, slot_type))
				default_type = board.def_components?[slot_type] || slot_type
				break
	return initial(default_type.maxcharge)

/// Researched nodes a fresh web doesn't start with, if this server's disk is really installed. Else 0.
/obj/machinery/rnd/server/ship/proc/saved_research_count()
	SHOULD_NOT_SLEEP(TRUE)
	if(QDELETED(source_code_hdd) || source_code_hdd.loc != src || stored_research != source_code_hdd.stored_research)
		return 0
	. = 0
	for(var/node_id in stored_research.researched_nodes)
		if(!SSresearch.techweb_nodes_starting[node_id])
			.++

/// A priced machine's stock parts as text. Board stacks and other contents aren't parts of its progress.
/proc/ship_save_part_paths(obj/machinery/machine)
	SHOULD_NOT_SLEEP(TRUE)
	var/list/paths = list()
	for(var/part in machine.component_parts)
		if(istype(part, /datum/stock_part))
			var/datum/stock_part/stock_part = part
			paths += "[stock_part.type]"
		else if(isitem(part))
			var/obj/item/item_part = part
			if(GLOB.ship_save_kept_power_parts[item_part.type])
				paths += "[item_part.type]"
	return paths

/// Where a machine is on its hull, whichever bay or shipyard the hull is in, and what it comes back as.
/datum/ship_checkpoint/proc/machine_key(obj/machinery/machine, obj/docking_port/mobile/port, saved_type)
	return "[machine.x - port.x + port_x],[machine.y - port.y + port_y],[saved_type]"

/// The parts and research this hull holds now. Doesn't sleep, so it can be read twice and compared.
/datum/ship_checkpoint/proc/read_progress(obj/docking_port/mobile/voidcrew/port)
	SHOULD_NOT_SLEEP(TRUE)
	var/list/parts = list()
	var/obj/machinery/rnd/server/ship/best_server
	var/best_count = 0
	var/list/rooms_here = list()
	for(var/area/room as anything in hull_owned_areas(port))
		rooms_here[room] = TRUE
	for(var/turf/tile as anything in port.return_turfs())
		if(!rooms_here[tile.loc])
			continue
		for(var/obj/machinery/machine in tile)
			if(!ship_save_keeps_object(machine))
				continue
			var/saved_type = machine.checkpoint_type()
			if(GLOB.ship_save_priced_machines[saved_type] && ship_save_machine_upgraded(machine))
				var/list/part_paths = ship_save_part_paths(machine)
				if(length(part_paths))
					var/key = machine_key(machine, port, saved_type)
					if(!parts[key])
						parts[key] = list()
					parts[key] += list(part_paths)
			if(istype(machine, /obj/machinery/rnd/server/ship))
				var/obj/machinery/rnd/server/ship/server = machine
				var/count = server.saved_research_count()
				if(count > best_count)
					best_count = count
					best_server = server
	return list("parts" = parts, "research" = best_server ? ship_save_read_research(best_server, port, src) : null)

/proc/ship_save_read_research(obj/machinery/rnd/server/ship/server, obj/docking_port/mobile/port, datum/ship_checkpoint/snapshot)
	SHOULD_NOT_SLEEP(TRUE)
	var/datum/techweb/web = server.stored_research
	var/list/nodes = list()
	for(var/node_id in web.researched_nodes)
		if(!SSresearch.techweb_nodes_starting[node_id])
			nodes += node_id
	var/list/experiments = list()
	for(var/experiment_type in web.completed_experiments)
		experiments += "[experiment_type]"
	return list(
		"x" = server.x - port.x + snapshot.port_x,
		"y" = server.y - port.y + snapshot.port_y,
		"nodes" = nodes,
		"experiments" = experiments,
	)

/// Takes down what read_progress() sees, and remembers it for progress_changed().
/datum/ship_checkpoint/proc/capture_progress(obj/docking_port/mobile/voidcrew/port)
	var/list/progress = read_progress(port)
	machine_parts = progress["parts"]
	research = progress["research"]
	progress_print = json_encode(progress)

/// Whether the parts or research aboard differ from what this snapshot took down and priced.
/datum/ship_checkpoint/proc/progress_changed(obj/docking_port/mobile/voidcrew/port)
	if(QDELETED(port))
		return TRUE
	return json_encode(read_progress(port)) != progress_print

/**
 * Puts the saved parts and research into a freshly loaded, scrubbed copy of the hull. In one tick, like the
 * scrubbing before it. A machine that no longer matches stays at its defaults: nothing here is worth failing
 * a load over, and the save is already paid for.
 */
/datum/ship_checkpoint/proc/restore_progress(obj/docking_port/mobile/voidcrew/port)
	SHOULD_NOT_SLEEP(TRUE)
	var/restored_parts = 0
	var/missed_parts = 0
	var/obj/machinery/rnd/server/ship/research_server
	var/obj/machinery/rnd/server/ship/any_server
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/machinery/machine in tile)
			if(length(machine_parts))
				var/list/waiting = machine_parts[machine_key(machine, port, machine.type)]
				if(length(waiting))
					ship_save_restore_parts(machine, waiting[1])
					waiting.Cut(1, 2)
					restored_parts++
			if(research && istype(machine, /obj/machinery/rnd/server/ship))
				any_server = any_server || machine
				if(machine.x - port.x + port_x == research["x"] && machine.y - port.y + port_y == research["y"])
					research_server = machine
	for(var/key in machine_parts)
		var/list/waiting = machine_parts[key]
		missed_parts += length(waiting)
	if(research)
		research_server = research_server || any_server
		if(research_server)
			research_server.restore_saved_research(research)
		else
			log_game("Ship save [ship_name] holds research, but its hull has no R&D server to put it in.")
	if(missed_parts)
		log_game("Ship save [ship_name]: [missed_parts] of [restored_parts + missed_parts] machines came back without their saved parts.")

/// Swaps a default machine's parts for the saved ones, category by category.
/proc/ship_save_restore_parts(obj/machinery/machine, list/part_paths)
	var/list/available = machine.component_parts.Copy()
	for(var/path_text in part_paths)
		var/part_path = text2path(path_text)
		if(ispath(part_path, /datum/stock_part))
			var/datum/stock_part/saved_part = GLOB.stock_part_datums[part_path]
			if(!saved_part)
				continue
			for(var/datum/stock_part/current in available)
				if(current.physical_object_base_type != saved_part.physical_object_base_type)
					continue
				available -= current
				machine.component_parts[machine.component_parts.Find(current)] = saved_part
				break
		else if(ispath(part_path, /obj/item/stock_parts/power_store) && GLOB.ship_save_kept_power_parts[part_path])
			var/power_base = ispath(part_path, /obj/item/stock_parts/power_store/battery) ? /obj/item/stock_parts/power_store/battery : /obj/item/stock_parts/power_store/cell
			for(var/obj/item/stock_parts/power_store/current in available)
				if(!istype(current, power_base))
					continue
				available -= current
				var/obj/item/stock_parts/power_store/saved_power = new part_path(machine)
				checkpoint_scrub_part(saved_power)
				// Recycling one must not hand back what the cell was made of.
				saved_power.set_custom_materials(null)
				machine.component_parts[machine.component_parts.Find(current)] = saved_power
				qdel(current)
				break
	machine.RefreshParts()
	machine.update_appearance()

/**
 * Gives a loaded server a new disk holding the saved web. Nodes are forced, so nothing is paid and no gate
 * applies, and experiments are marked done without running their completion, which is what pays out. Links
 * wait for settle_saved_research(), when the hull is somewhere it can link from.
 */
/obj/machinery/rnd/server/ship/proc/restore_saved_research(list/saved)
	SHOULD_NOT_SLEEP(TRUE)
	var/obj/item/computer_disk/ship_disk/disk = new(src)
	adopt_source_disk(disk)
	var/datum/techweb/web = stored_research
	// First, so researching the nodes below doesn't offer them again.
	for(var/type_text in saved["experiments"])
		var/experiment_type = text2path(type_text)
		if(!ispath(experiment_type, /datum/experiment) || web.completed_experiments[experiment_type])
			continue
		var/datum/experiment/done
		for(var/datum/experiment/offered as anything in web.available_experiments)
			if(offered.type == experiment_type)
				done = offered
				break
		web.available_experiments -= done
		web.completed_experiments[experiment_type] = done || new experiment_type(web)
		web.local_experiment_reward_ledger[experiment_type] = TRUE
	for(var/node_id in saved["nodes"])
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id]
		if(!node)
			continue
		web.hidden_nodes -= node_id
		web.research_node(node, TRUE, FALSE, FALSE)

/**
 * Once a loaded hull has its crew and its place: its machines get the links they had to be multitooled to,
 * and its crew has already been paid for what the saved web completed, so a second disk can't earn it again.
 */
/obj/structure/overmap/ship/proc/settle_saved_research()
	if(QDELETED(shuttle))
		return
	var/datum/voidcrew_crew_record/crew = get_crew_record()
	for(var/obj/machinery/rnd/server/ship/server as anything in GLOB.ship_research_servers)
		if(QDELETED(server) || !server.stored_research || !(get_area(server) in shuttle.shuttle_areas))
			continue
		var/datum/techweb/web = server.stored_research
		if(!QDELETED(crew))
			for(var/experiment_type in web.completed_experiments)
				crew.research_reward_ledger[experiment_type] = TRUE
		for(var/area/room as anything in shuttle.shuttle_areas)
			for(var/obj/machinery/machine in room)
				if(machine == server)
					continue
				if(istype(machine, /obj/machinery/rnd))
					var/obj/machinery/rnd/lab_machine = machine
					if(!lab_machine.stored_research)
						lab_machine.connect_techweb(web)
				else if(istype(machine, /obj/machinery/mecha_part_fabricator))
					var/obj/machinery/mecha_part_fabricator/fabricator = machine
					if(!fabricator.stored_research)
						fabricator.connect_techweb(web)
				else if(istype(machine, /obj/machinery/component_printer))
					var/obj/machinery/component_printer/printer = machine
					if(!printer.techweb)
						printer.connect_techweb(web)
				else if(istype(machine, /obj/machinery/computer/rdconsole))
					var/obj/machinery/computer/rdconsole/console = machine
					if(!console.stored_research)
						console.stored_research = web
						web.connected_machines |= console
						web.consoles_accessing |= console
		server.claim_unlinked_experiment_handlers()
		server.claim_unlinked_survey_console()
		return
