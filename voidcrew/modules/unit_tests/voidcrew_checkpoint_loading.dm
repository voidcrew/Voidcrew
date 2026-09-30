/// Samples how long the server's ticks really take while something loads.
/datum/checkpoint_tick_sampler
	var/running = TRUE
	var/timer_id
	/// Longest wall time between two consecutive ticks, in milliseconds.
	var/max_gap_ms = 0
	var/samples = 0
	var/started_ms = 0
	/// Optional load whose current phase is recorded for the longest tick.
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/watched
	var/max_gap_phase
	/// Every tick longer than 100 ms, as "ms (phase)".
	var/list/slow_ticks = list()

/datum/checkpoint_tick_sampler/New()
	timer_id = "checkpoint_sampler_[REF(src)]"
	rustg_time_reset(timer_id)
	INVOKE_ASYNC(src, PROC_REF(sample))

/datum/checkpoint_tick_sampler/proc/sample()
	var/last = rustg_time_milliseconds(timer_id)
	while(running)
		sleep(world.tick_lag)
		var/now = rustg_time_milliseconds(timer_id)
		if(now - last > 100)
			slow_ticks += "[now - last][watched ? " ([watched.current_phase || "reserve"])" : ""]"
		if(now - last > max_gap_ms)
			max_gap_ms = now - last
			max_gap_phase = watched?.current_phase || (watched ? "reserve" : null)
		samples++
		last = now

/datum/checkpoint_tick_sampler/proc/elapsed_ms()
	return rustg_time_milliseconds(timer_id)

/datum/checkpoint_tick_sampler/proc/summary()
	running = FALSE
	return "[elapsed_ms()] ms over [samples] ticks, longest tick [max_gap_ms] ms[max_gap_phase ? " ([max_gap_phase])" : ""], ticks over 100 ms: [length(slow_ticks) ? slow_ticks.Join(", ") : "none"]"

/// A loaded hidden copy, outside any rebuild job.
/datum/checkpoint_loaded_copy
	var/obj/docking_port/mobile/voidcrew/port
	var/datum/turf_reservation/reservation
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/template
	var/load_summary
	var/pipe_caps = 0
	/// Air on the hull, compared as a total: tiles next to each other trade gas while loading.
	var/total_moles = 0

/datum/checkpoint_loaded_copy/Destroy()
	if(!QDELETED(port))
		var/list/rooms = port.shuttle_areas?.Copy()
		port.jumpToNullSpace()
		for(var/area/room as anything in rooms)
			if(!QDELETED(room) && !room.has_contained_turfs())
				qdel(room)
	port = null
	QDEL_NULL(reservation)
	QDEL_NULL(template)
	return ..()

/**
 * Spread loading is equivalent to the stock all-at-once load: for every purchasable class, the
 * same checkpoint is loaded both ways and compared tile by tile and network by network.
 */
/datum/unit_test/voidcrew_checkpoints/spread_load
	var/list/timings = list()

/datum/unit_test/voidcrew_checkpoints/spread_load/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "spreadloadfounder"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/mob/living/carbon/human/captain = make_player(run_loc_floor_bottom_left, "spreadloadcaptain")
	// How long ticks run with nothing loading, for comparison.
	var/datum/checkpoint_tick_sampler/idle = new
	sleep(5 SECONDS)
	var/list/report = list("idle: [idle.summary()]")
	qdel(idle)
	for(var/label in SSmapping.ship_purchase_list)
		var/template_type = SSmapping.ship_purchase_list[label]
		var/datum/map_template/shuttle/voidcrew/template_path = template_type
		if(initial(template_path.abstract) == template_type || ispath(template_type, /datum/map_template/shuttle/voidcrew/commissioned))
			continue
		log_world("CHECKPOINT_LOAD class [template_type]")
		report += "[template_type]: [compare_class(home, captain, template_type)]"
	log_test("Spread against stock checkpoint loads:\n[report.Join("\n")]")

/// Spawns, docks and saves one class. Returns the checkpoint, or text explaining why not.
/datum/unit_test/voidcrew_checkpoints/proc/save_class(obj/structure/overmap/dynamic/player_outpost/home, mob/living/carbon/human/captain, template_type)
	var/obj/structure/overmap/ship/original = SSshuttle.create_ship(template_type)
	if(!original)
		return "could not spawn"
	test_ships += original
	original.enlist_crewmember(captain)
	original.claimed_captain = captain.mind
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(original)
	if(!bay)
		qdel(original)
		return "no bay could take it"
	adjust_reserve_dock_to_shuttle(bay.dock, original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	var/docked = original.shuttle.initiate_docking(bay.dock)
	original.shuttle.mode = SHUTTLE_IDLE
	if(docked != DOCKING_SUCCESS)
		home.on_ship_undock_complete(original)
		qdel(original)
		return "does not fit the bay ([docked])"
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
	return snapshot

/// Moves the saved original off its bay and deletes it, as a lost hull would be.
/datum/unit_test/voidcrew_checkpoints/proc/lose_original(obj/structure/overmap/dynamic/player_outpost/home, obj/structure/overmap/ship/original)
	var/obj/docking_port/stationary/transit/transit = original.shuttle.assigned_transit || SSshuttle.generate_transit_dock(original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	. = original.shuttle.initiate_docking(transit) == DOCKING_SUCCESS
	original.shuttle.mode = SHUTTLE_IDLE
	original.docked = null
	original.forceMove(get_turf(home))
	original.state = "flying"
	home.on_ship_undock_complete(original)
	. = original.shuttle.admin_delete_shuttle() && .

/datum/unit_test/voidcrew_checkpoints/spread_load/proc/compare_class(obj/structure/overmap/dynamic/player_outpost/home, mob/living/carbon/human/captain, template_type)
	var/datum/ship_checkpoint/snapshot = save_class(home, captain, template_type)
	if(!istype(snapshot))
		return "skipped: [snapshot]"
	var/obj/structure/overmap/ship/original = snapshot.source_ship?.resolve()
	// Each copy is read in the tick its load finishes, before atmos can run on it.
	var/datum/checkpoint_loaded_copy/stock = load_copy(snapshot, FALSE)
	var/list/stock_lines = stock?.port ? fingerprint(stock) : null
	var/datum/checkpoint_loaded_copy/spread = load_copy(snapshot, TRUE)
	var/list/spread_lines = spread?.port ? fingerprint(spread) : null
	. = "[snapshot.width]x[snapshot.height]"
	if(!stock_lines || !spread_lines)
		TEST_FAIL("[template_type]: a copy did not load (stock [!!stock_lines], spread [!!spread_lines])")
		. += " load failed"
	else
		var/list/differences = list()
		for(var/i in 1 to max(length(stock_lines), length(spread_lines)))
			var/stock_line = i <= length(stock_lines) ? stock_lines[i] : "(none)"
			var/spread_line = i <= length(spread_lines) ? spread_lines[i] : "(none)"
			if(stock_line != spread_line)
				differences += "stock [stock_line]\n  spread [spread_line]"
		var/moles_scale = max(stock.total_moles, spread.total_moles, 1)
		if(abs(stock.total_moles - spread.total_moles) > moles_scale * 0.01)
			differences += "hull air: stock [round(stock.total_moles, 0.1)] moles, spread [round(spread.total_moles, 0.1)] moles"
		if(stock.pipe_caps != spread.pipe_caps)
			. += " (pipe cap visuals: stock [stock.pipe_caps], spread [spread.pipe_caps])"
		if(length(differences))
			TEST_FAIL("[template_type]: spread load differs from stock load in [length(differences)] of [length(stock_lines)] lines, first:\n  [differences.Copy(1, min(6, length(differences) + 1)).Join("\n  ")]")
			. += " DIFFERS ([length(differences)] lines)"
		else
			. += " identical ([length(stock_lines)] lines)"
		. += "\n    stock:  [stock.load_summary]\n    spread: [spread.load_summary]"
	qdel(stock)
	qdel(spread)
	home.checkpoints -= snapshot
	qdel(snapshot)
	if(original && !QDELETED(original.shuttle))
		original.shuttle.admin_delete_shuttle()

/// Loads a checkpoint's hidden copy the way a rebuild job does, holding the shared loader.
/datum/unit_test/voidcrew_checkpoints/proc/load_copy(datum/ship_checkpoint/snapshot, spread)
	var/datum/checkpoint_loaded_copy/copy = new
	copy.template = new(snapshot)
	copy.template.spread_load = spread
	var/datum/checkpoint_tick_sampler/sampler = new
	sampler.watched = copy.template
	var/started = world.time
	log_world("CHECKPOINT_LOAD [spread ? "spread" : "stock"] [snapshot.ship_name] begin")
	SSshuttle.run_template_load(CALLBACK(src, PROC_REF(take_preview), copy))
	log_world("CHECKPOINT_LOAD [spread ? "spread" : "stock"] [snapshot.ship_name] end")
	copy.load_summary = "[sampler.summary()], [(world.time - started) / world.tick_lag] game ticks; phases [phase_text(copy.template.phase_ms)]"
	qdel(sampler)
	return copy

/datum/unit_test/voidcrew_checkpoints/proc/take_preview(datum/checkpoint_loaded_copy/copy, datum/shuttle_template_load/load_owner)
	SSair.can_fire = FALSE
	SSshuttle.load_template(copy.template, load_owner)
	copy.port = SSshuttle.preview_shuttle
	copy.reservation = SSshuttle.preview_reservation
	SSshuttle.preview_shuttle = null
	SSshuttle.preview_template = null
	SSshuttle.preview_reservation = null

/datum/unit_test/voidcrew_checkpoints/proc/phase_text(list/phases)
	var/list/parts = list()
	for(var/phase in phases)
		parts += "[phase] [phases[phase]]"
	return parts.Join(", ")

/// Everything the equivalence check compares, one sorted line per item, in local coordinates.
/datum/unit_test/voidcrew_checkpoints/spread_load/proc/fingerprint(datum/checkpoint_loaded_copy/copy)
	var/list/lines = list()
	var/turf/origin = copy.reservation.bottom_left_turfs[1]
	var/obj/docking_port/mobile/voidcrew/port = copy.port
	lines += "port [port.x - origin.x],[port.y - origin.y] dir [port.dir] [port.width]x[port.height] offset [port.dwidth],[port.dheight] rooms [length(port.shuttle_areas)] registered [port.registered]"
	var/list/area_ids = list()
	var/list/pipenet_ids = list()
	var/list/powernet_ids = list()
	for(var/turf/tile as anything in CORNER_BLOCK(origin, copy.template.width, copy.template.height))
		var/local = "[tile.x - origin.x],[tile.y - origin.y]"
		var/area/room = tile.loc
		if(!area_ids[room])
			area_ids[room] = length(area_ids) + 1
		var/datum/gas_mixture/air = tile.return_air()
		copy.total_moles += air?.total_moles()
		lines += "[local] [tile.type] [room.type]#[area_ids[room]] blocks_air [tile.blocks_air] baseturfs [tile.baseturfs ? (islist(tile.baseturfs) ? jointext(tile.baseturfs, "+") : "[tile.baseturfs]") : "none"] air [air ? "yes" : "none"] light [!!tile.lighting_object]"
		var/list/things = list()
		for(var/atom/movable/thing as anything in tile.get_all_contents() - tile)
			// Stored items are stock the rebuild scrubs, and some are rolled at random on
			// Initialize (maintenance loot, gun casing facings). Pipe caps are a visual whose
			// presence depends on the order neighbours were redrawn; counted separately.
			if(thing.loc != tile && isitem(thing))
				continue
			// Mobs are scrubbed like stock, and some spawn at random (vendor pests, pets).
			if(ismob(thing))
				continue
			if(istype(thing, /obj/effect/overlay/cap_visual))
				copy.pipe_caps++
				continue
			things += "[thing.type][thing.loc == tile ? "" : " in [thing.loc.type]"] dir [thing.dir]"
		sortTim(things, GLOBAL_PROC_REF(cmp_text_asc))
		lines += "[local] holds [things.Join("; ")]"
		for(var/obj/machinery/machine in tile)
			var/list/parts = list()
			for(var/datum/part as anything in machine.component_parts)
				parts += "[part.type]"
			sortTim(parts, GLOBAL_PROC_REF(cmp_text_asc))
			lines += "[local] [machine.type] parts [parts.Join(",")] board [machine.circuit?.type] area #[area_ids[get_area(machine)] || "?"]"
			if(istype(machine, /obj/machinery/power/apc))
				var/obj/machinery/power/apc/controller = machine
				lines += "[local] apc room #[area_ids[controller.area] || "?"] linked [controller.area?.apc == controller] terminal [!!controller.terminal] net [net_id(powernet_ids, controller.terminal?.powernet, origin)]"
			else if(istype(machine, /obj/machinery/power))
				var/obj/machinery/power/power_machine = machine
				lines += "[local] [machine.type] net [net_id(powernet_ids, power_machine.powernet, origin)]"
			if(istype(machine, /obj/machinery/atmospherics))
				var/obj/machinery/atmospherics/device = machine
				var/list/nets = list()
				for(var/datum/pipeline/network as anything in device.return_pipenets())
					nets += pipe_id(pipenet_ids, network, origin)
				var/list/nodes = list()
				for(var/obj/machinery/atmospherics/node as anything in device.nodes)
					nodes += node ? "[node.x - origin.x],[node.y - origin.y]" : "-"
				lines += "[local] [device.type] layer [device.piping_layer] nodes [nodes.Join(",")] nets [nets.Join(",")]"
		for(var/obj/structure/cable/cable in tile)
			lines += "[local] cable layer [cable.cable_layer] [cable.icon_state] net [net_id(powernet_ids, cable.powernet, origin)]"
	return lines

/// A network's identity is the sorted list of its members, so the same wiring compares equal.
/datum/unit_test/voidcrew_checkpoints/spread_load/proc/net_id(list/known, datum/powernet/network, turf/origin)
	if(!network)
		return "none"
	if(known[network])
		return known[network]
	var/list/members = list()
	for(var/obj/structure/cable/cable as anything in network.cables)
		members += "c[cable.x - origin.x],[cable.y - origin.y],[cable.cable_layer]"
	for(var/obj/machinery/power/node as anything in network.nodes)
		members += "m[node.x - origin.x],[node.y - origin.y],[node.type]"
	sortTim(members, GLOBAL_PROC_REF(cmp_text_asc))
	known[network] = "[length(network.cables)]c/[length(network.nodes)]n/[md5(members.Join(";"))]"
	return known[network]

/datum/unit_test/voidcrew_checkpoints/spread_load/proc/pipe_id(list/known, datum/pipeline/network, turf/origin)
	if(!network)
		return "none"
	if(known[network])
		return known[network]
	var/list/members = list()
	for(var/obj/machinery/atmospherics/member as anything in network.members + network.other_atmos_machines)
		members += "[member.x - origin.x],[member.y - origin.y],[member.type],[member.piping_layer]"
	sortTim(members, GLOBAL_PROC_REF(cmp_text_asc))
	known[network] = "[length(members)]/[md5(members.Join(";"))]"
	return known[network]

/**
 * Five of the largest classes rebuild at once in five outposts, with the real controller, and a
 * ship purchase lands in the middle of them. Every rebuild must queue, finish and match its hull.
 */
/datum/unit_test/voidcrew_checkpoints/concurrent_rebuilds
	var/list/job_results = list()
	var/purchase_done = FALSE
	var/purchase_ms = 0
	var/purchase_finished_at
	var/obj/structure/overmap/ship/purchased

/datum/unit_test/voidcrew_checkpoints/concurrent_rebuilds/Run()
	// Largest hulls first.
	var/list/sizes = list()
	for(var/label in SSmapping.ship_purchase_list)
		var/template_type = SSmapping.ship_purchase_list[label]
		var/datum/map_template/shuttle/voidcrew/template_path = template_type
		if(initial(template_path.abstract) == template_type || ispath(template_type, /datum/map_template/shuttle/voidcrew/commissioned))
			continue
		var/datum/map_template/shuttle/voidcrew/measured = new template_type()
		sizes[template_type] = measured.width * measured.height
		qdel(measured)
	sortTim(sizes, GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)
	var/list/homes = list()
	var/list/snapshots = list()
	var/list/before = list()
	var/list/bays = list()
	var/list/labels = list()
	var/index = 0
	for(var/template_type in sizes)
		if(length(snapshots) >= 5)
			break
		if(length(homes) <= length(snapshots))
			index++
			var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
			home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
			home.founder_ckey = "stressfounder[index]"
			TEST_ASSERT(home.load_level(), "Outpost [index] did not load")
			TEST_ASSERT_NULL(home.enable_ship_bays(), "Outpost [index] has no ship bay")
			homes += home
		var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = homes[length(snapshots) + 1]
		var/mob/living/carbon/human/captain = make_player(run_loc_floor_bottom_left, "stresscaptain[length(snapshots) + 1]")
		var/datum/ship_checkpoint/snapshot = save_class(home, captain, template_type)
		if(!istype(snapshot))
			log_test("Stress: [template_type] skipped: [snapshot]")
			continue
		var/obj/structure/overmap/ship/original = snapshot.source_ship.resolve()
		before += list(count_hull(original.shuttle))
		bays += home.bay_berths[1]
		TEST_ASSERT(lose_original(home, original), "[template_type]: the original could not be removed")
		snapshots += snapshot
		labels += "[template_type] [snapshot.width]x[snapshot.height] ([sizes[template_type]] tiles)"
	TEST_ASSERT_EQUAL(length(snapshots), 5, "Fewer than five large classes could be saved")

	var/datum/checkpoint_tick_sampler/sampler = new
	var/list/datum/checkpoint_construction/jobs = list()
	for(var/i in 1 to length(snapshots))
		var/datum/ship_checkpoint/snapshot = snapshots[i]
		var/datum/checkpoint_construction/job = new(null, snapshot, get_mob_by_ckey(snapshot.captain_ckey), FALSE)
		TEST_ASSERT(job.bay, "[labels[i]]: the job could not reserve its bay")
		jobs += job
		job_results[job] = list("label" = labels[i], "started" = world.time)
		INVOKE_ASYNC(src, PROC_REF(run_job), job)
	// The first job holds the loader; the rest wait for it with their bays reserved.
	var/waiting = 0
	for(var/datum/checkpoint_construction/job as anything in jobs)
		if(job.queued)
			waiting++
			TEST_ASSERT_EQUAL(job.status_line(), "Waiting for the shipyard", "A queued rebuild reported the wrong status")
			TEST_ASSERT_EQUAL(job.bay.status_text(), "Queued", "A queued rebuild's bay sign is wrong")
			TEST_ASSERT(!job.bay.is_available(), "A queued rebuild released its bay")
	TEST_ASSERT(waiting >= 3, "Only [waiting] rebuilds queued behind the first")
	// A purchase in the middle of the queue goes ahead of the rebuilds still waiting.
	INVOKE_ASYNC(src, PROC_REF(purchase), sizes[length(sizes)])
	var/deadline = world.time + 15 MINUTES
	while(world.time < deadline)
		var/pending = !purchase_done
		for(var/datum/checkpoint_construction/job as anything in jobs)
			if(!QDELETED(job) && job.state != "commissioning" && job.state != "failed")
				pending = TRUE
		if(!pending)
			break
		sleep(1 SECONDS)
	var/sampled = sampler.summary()
	qdel(sampler)
	TEST_ASSERT(purchase_done && purchased, "The purchase made during the rebuilds did not finish")
	if(purchased)
		test_ships += purchased
	var/list/report = list("five concurrent rebuilds: [sampled]", "purchase during the queue: [purchase_ms] ms")
	var/loaded_after_purchase = 0
	for(var/datum/checkpoint_construction/job as anything in jobs)
		var/list/result = job_results[job]
		if(result["load_started_at"] >= purchase_finished_at)
			loaded_after_purchase++
	TEST_ASSERT(loaded_after_purchase >= 1, "The purchase waited behind every queued rebuild")
	for(var/i in 1 to length(jobs))
		var/datum/checkpoint_construction/job = jobs[i]
		var/list/result = job_results[job]
		var/datum/outpost_berth/ship_bay/bay = bays[i]
		// A present captain is handed the hull by the controller itself.
		if(!QDELETED(job))
			TEST_ASSERT_EQUAL(job.state, "commissioning", "[result["label"]]: did not finish building ([job.error])")
			job.hand_over_now()
		var/obj/structure/overmap/ship/rebuilt = bay.ship
		TEST_ASSERT(QDELETED(job) && rebuilt, "[result["label"]]: the rebuild was not handed over ([result["error"]])")
		test_ships += rebuilt
		var/list/before_counts = before[i]
		var/list/after_counts = count_hull(rebuilt.shuttle)
		for(var/type_name in (before_counts | after_counts))
			if(before_counts[type_name] != after_counts[type_name])
				TEST_FAIL("[result["label"]]: [type_name] expected [before_counts[type_name]], rebuilt [after_counts[type_name]]")
		report += "[result["label"]]: waited [result["waited"]] ds for the loader, loaded in [result["loaded"]] ds, built by [result["built"]] ds; phases [result["phases"]]"
	log_test("Concurrent rebuild stress:\n[report.Join("\n")]")

/datum/unit_test/voidcrew_checkpoints/concurrent_rebuilds/proc/run_job(datum/checkpoint_construction/job)
	var/list/result = job_results[job]
	var/started = world.time
	var/prepared = job.prepare()
	result["load_started_at"] = job.load_started_at
	result["waited"] = (job.load_started_at || world.time) - started
	result["loaded"] = world.time - (job.load_started_at || started)
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/loaded = job.template
	result["phases"] = phase_text(loaded?.phase_ms)
	if(!prepared)
		result["error"] = job.error
		return
	job.rush()
	UNTIL(QDELETED(job) || job.state != "building")
	result["built"] = world.time - started

/datum/unit_test/voidcrew_checkpoints/concurrent_rebuilds/proc/purchase(template_type)
	var/timer = "checkpoint_purchase_[REF(src)]"
	rustg_time_reset(timer)
	purchased = SSshuttle.create_ship(template_type)
	purchase_ms = rustg_time_milliseconds(timer)
	purchase_finished_at = world.time
	purchase_done = TRUE

/**
 * A rebuild that cannot get the shared loader waits for it, well past the old 30 second limit,
 * keeping its bay. One deleted while it waits releases everything and keeps its checkpoint.
 */
/datum/unit_test/voidcrew_checkpoints/queued_rebuild
	var/datum/shuttle_template_load/held
	var/list/prepared = list()

/datum/unit_test/voidcrew_checkpoints/queued_rebuild/Destroy()
	if(held)
		SSshuttle.release_template_load(held)
	return ..()

/datum/unit_test/voidcrew_checkpoints/queued_rebuild/Run()
	var/smallest
	var/smallest_size = INFINITY
	for(var/label in SSmapping.ship_purchase_list)
		var/template_type = SSmapping.ship_purchase_list[label]
		var/datum/map_template/shuttle/voidcrew/template_path = template_type
		if(initial(template_path.abstract) == template_type || ispath(template_type, /datum/map_template/shuttle/voidcrew/commissioned))
			continue
		var/datum/map_template/shuttle/voidcrew/measured = new template_type()
		if(measured.width * measured.height < smallest_size)
			smallest_size = measured.width * measured.height
			smallest = template_type
		qdel(measured)
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "queuedfounder"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/mob/living/carbon/human/captain = make_player(run_loc_floor_bottom_left, "queuedcaptain")
	var/datum/ship_checkpoint/snapshot = save_class(home, captain, smallest)
	TEST_ASSERT(istype(snapshot), "[smallest] could not be saved: [snapshot]")
	TEST_ASSERT(lose_original(home, snapshot.source_ship.resolve()), "The original could not be removed")
	var/datum/outpost_berth/ship_bay/bay = home.bay_berths[1]

	// Deleted while waiting: nothing is kept but the checkpoint.
	held = SSshuttle.acquire_template_load()
	var/datum/checkpoint_construction/cancelled = new(null, snapshot, captain, TRUE)
	INVOKE_ASYNC(src, PROC_REF(prepare_job), cancelled)
	TEST_ASSERT(cancelled.queued, "The rebuild did not wait for the busy loader")
	TEST_ASSERT_EQUAL(cancelled.status_line(), "Waiting for the shipyard", "A waiting rebuild reported the wrong status")
	TEST_ASSERT_EQUAL(bay.status_text(), "Queued", "A waiting rebuild's bay sign is wrong")
	TEST_ASSERT(!bay.is_available(), "A waiting rebuild released its bay")
	TEST_ASSERT(snapshot.busy, "A waiting rebuild left its checkpoint free for another")
	qdel(cancelled)
	var/deadline = world.time + 10 SECONDS
	UNTIL(!length(SSshuttle.background_template_waiters) || world.time > deadline)
	TEST_ASSERT(!length(SSshuttle.background_template_waiters), "A deleted rebuild stayed in the loader queue")
	TEST_ASSERT(bay.is_available(), "A deleted rebuild kept its bay")
	TEST_ASSERT(!QDELETED(snapshot) && (snapshot in home.checkpoints) && !snapshot.busy, "A deleted rebuild lost or held its checkpoint")
	TEST_ASSERT_EQUAL(SSshuttle.active_template_load, held, "A deleted rebuild disturbed the loader's owner")

	// Waits as long as it takes, then starts.
	var/datum/checkpoint_construction/patient = new(null, snapshot, captain, TRUE)
	INVOKE_ASYNC(src, PROC_REF(prepare_job), patient)
	TEST_ASSERT(patient.queued, "The second rebuild did not wait for the busy loader")
	sleep(35 SECONDS)
	TEST_ASSERT(!QDELETED(patient) && patient.queued && patient.state == "preparing", "A rebuild gave up waiting ([patient.state]: [patient.error])")
	SSshuttle.release_template_load(held)
	held = null
	deadline = world.time + 2 MINUTES
	UNTIL(prepared[patient] || world.time > deadline)
	TEST_ASSERT_EQUAL(prepared[patient], "started", "The waiting rebuild did not start once the loader was free: [patient.error]")
	TEST_ASSERT_NULL(SSshuttle.active_template_load, "A started rebuild kept the loader")
	// Stopped before its first piece: the checkpoint survives.
	patient.abort("Test cancelled.")
	TEST_ASSERT(!QDELETED(snapshot) && (snapshot in home.checkpoints) && !snapshot.busy, "A rebuild stopped before its first piece lost its checkpoint")
	TEST_ASSERT(bay.is_available(), "A stopped rebuild kept its bay")

/datum/unit_test/voidcrew_checkpoints/queued_rebuild/proc/prepare_job(datum/checkpoint_construction/job)
	prepared[job] = job.prepare() ? "started" : "stopped"
