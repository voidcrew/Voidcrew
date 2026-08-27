SUBSYSTEM_DEF(air)
	name = "Atmospherics"
	dependencies = list(
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/atoms,
	)
	priority = FIRE_PRIORITY_AIR
	wait = 0.5 SECONDS
	ss_flags = SS_BACKGROUND
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/cached_cost = 0

	var/cost_atoms = 0
	var/cost_turfs = 0
	var/cost_hotspots = 0
	var/cost_groups = 0
	var/cost_highpressure = 0
	var/cost_superconductivity = 0
	var/cost_pipenets = 0
	var/cost_atmos_machinery = 0
	var/cost_rebuilds = 0
	var/cost_adjacent = 0

	var/list/excited_groups = list()
	var/list/active_turfs = list()
	var/list/hotspots = list()
	var/list/networks = list()
	var/list/rebuild_queue = list()
	//Subservient to rebuild queue
	var/list/expansion_queue = list()
	/// VOIDCREW ADDITION: pipelines that lost their last member to a pipe steal in
	/// expand_pipeline() while they were still flagged `building`. That call site cannot
	/// qdel one on the spot - /datum/pipeline/Destroy() edits expansion_queue, which is the
	/// list that drain is walking - so the husk is parked here and reaped on a later fire,
	/// once `building` has cleared and it is provably still empty. Without this a
	/// stacked-pipe map (every voidcrew hull has some) leaks one member-less pipeline into
	/// SSair.networks per site build, processed every tick for the rest of the round.
	var/list/datum/pipeline/pipeline_husks = list()
	/// VOIDCREW ADDITION: how many consecutive orphan sweeps a pipeline has to be found
	/// empty on before it is reaped. build_pipeline() legitimately leaves a pipeline with
	/// no members for the window between `new /datum/pipeline` and its queued expansion,
	/// so one strike is not proof of a leak - two separate sweeps is.
	var/orphan_pipeline_strikes = 2
	/// VOIDCREW ADDITION: world.time the next orphan-pipeline sweep may run. The sweep is
	/// O(networks * members) and nothing it catches is urgent, so it is rate limited.
	var/next_orphan_sweep = 0
	/// VOIDCREW ADDITION: how long between orphan-pipeline sweeps. Short on purpose: two
	/// strikes at this interval is how long an orphan can survive, and the churn soak
	/// samples 20 seconds after a teardown. At 5 seconds an orphan made during teardown is
	/// always gone before the sample, so `pipelines_orphan` reads a real state rather than
	/// whatever happened to be in flight. Sweeping ~70 networks costs nothing.
	var/orphan_sweep_interval = 5 SECONDS
	/// VOIDCREW ADDITION: running total of pipelines the orphan sweep has reaped, for the
	/// churn-soak harness and for `SSair` debug output.
	var/orphan_pipelines_reaped = 0
	/// List of turfs to recalculate adjacent turfs on before processing
	var/list/adjacent_rebuild = list()
	/// A list of machines that will be processed when currentpart == SSAIR_ATMOSMACHINERY. Use SSair.begin_processing_machine and SSair.stop_processing_machine to add and remove machines.
	var/list/obj/machinery/atmos_machinery = list()

	var/list/pipe_init_dirs_cache = list()
	//atmos singletons
	var/list/gas_reactions = list()
	var/list/atmos_gen
	var/list/planetary = list() //Lets cache static planetary mixes
	/// List of gas string -> canonical gas mixture
	var/list/strings_to_mix = list()


	//Special functions lists
	var/list/turf/active_super_conductivity = list()
	var/list/turf/open/high_pressure_delta = list()
	var/list/atom_process = list()
	/// Reactions which will contribute to a hotspot's size.
	var/list/hotspot_reactions

	/// A cache of objects that perisists between processing runs when resumed == TRUE. Dangerous, qdel'd objects not cleared from this may cause runtimes on processing.
	var/list/currentrun = list()
	var/currentpart = SSAIR_PIPENETS

	var/map_loading = TRUE
	var/list/queued_for_activation
	var/display_all_groups = FALSE

	var/list/reaction_handbook
	var/list/gas_handbook


/datum/controller/subsystem/air/stat_entry(msg)
	msg += "\n  Cost:{"
	msg += "AT:[round(cost_turfs,1)]|"
	msg += "HS:[round(cost_hotspots,1)]|"
	msg += "EG:[round(cost_groups,1)]|"
	msg += "HP:[round(cost_highpressure,1)]|"
	msg += "SC:[round(cost_superconductivity,1)]|"
	msg += "PN:[round(cost_pipenets,1)]|"
	msg += "AM:[round(cost_atmos_machinery,1)]|"
	msg += "AO:[round(cost_atoms, 1)]|"
	msg += "RB:[round(cost_rebuilds,1)]|"
	msg += "AJ:[round(cost_adjacent,1)]|"
	msg += "} "
	msg += "\n  Count:{AT:[active_turfs.len]|"
	msg += "HS:[hotspots.len]|"
	msg += "EG:[excited_groups.len]|"
	msg += "HP:[high_pressure_delta.len]|"
	msg += "SC:[active_super_conductivity.len]|"
	msg += "PN:[networks.len]|"
	msg += "AM:[atmos_machinery.len]|"
	msg += "AO:[atom_process.len]|"
	msg += "RB:[rebuild_queue.len]|"
	msg += "EP:[expansion_queue.len]|"
	msg += "AJ:[adjacent_rebuild.len]|"
	msg += "AT/MS:[round((cost ? active_turfs.len/cost : 0),0.1)]"
	msg += "}"
	return ..()


/datum/controller/subsystem/air/Initialize()
	map_loading = FALSE
	gas_reactions = init_gas_reactions()
	hotspot_reactions = init_hotspot_reactions()

	setup_allturfs()
	setup_atmos_machinery()
	setup_pipenets()
	setup_turf_visuals()
	process_adjacent_rebuild()
	atmos_handbooks_init()
	return SS_INIT_SUCCESS


/datum/controller/subsystem/air/fire(resumed = FALSE)
	var/timer = TICK_USAGE_REAL

	//Rebuilds can happen at any time, so this needs to be done outside of the normal system
	cost_rebuilds = 0
	cost_adjacent = 0

	// We need to have a solid setup for turfs before fire, otherwise we'll get massive runtimes and strange behavior
	if(length(adjacent_rebuild))
		timer = TICK_USAGE_REAL
		process_adjacent_rebuild()
		//This does mean that the apperent rebuild costs fluctuate very quickly, this is just the cost of having them always process, no matter what
		cost_adjacent = TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return

	// VOIDCREW ADDITION: rate-limited sweep for member-less pipelines. Deliberately here,
	// outside process_rebuilds() - that block only runs when a queue is non-empty, and an
	// orphan by definition is not in any queue. Runs before the drain so it can never be
	// editing networks/expansion_queue while expand_pipeline() is walking them.
	reap_orphan_pipelines()

	// Every time we fire, we want to make sure pipenets are rebuilt. The game state could have changed between each fire() proc call
	// and anything missing a pipenet can lead to unintended behaviour at worse and various runtimes at best.
	// VOIDCREW EDIT: pipeline_husks in the condition too - a husk parked by
	// expand_pipeline() is usually the LAST thing that drain produces, so by the time it
	// can be reaped both queues are empty again and process_rebuilds() would never run.
	if(length(rebuild_queue) || length(expansion_queue) || length(pipeline_husks))
		timer = TICK_USAGE_REAL
		process_rebuilds()
		//This does mean that the apperent rebuild costs fluctuate very quickly, this is just the cost of having them always process, no matter what
		cost_rebuilds = TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return

	if(currentpart == SSAIR_PIPENETS || !resumed)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_pipenets(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_pipenets = MC_AVERAGE(cost_pipenets, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_ATMOSMACHINERY

	if(currentpart == SSAIR_ATMOSMACHINERY)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_atmos_machinery(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_atmos_machinery = MC_AVERAGE(cost_atmos_machinery, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_ACTIVETURFS

	if(currentpart == SSAIR_ACTIVETURFS)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_active_turfs(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_turfs = MC_AVERAGE(cost_turfs, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_HOTSPOTS

	if(currentpart == SSAIR_HOTSPOTS) //We do this before excited groups to allow breakdowns to be independent of adding turfs while still *mostly preventing mass fires
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_hotspots(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_hotspots = MC_AVERAGE(cost_hotspots, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_EXCITEDGROUPS

	if(currentpart == SSAIR_EXCITEDGROUPS)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_excited_groups(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_groups = MC_AVERAGE(cost_groups, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_HIGHPRESSURE

	if(currentpart == SSAIR_HIGHPRESSURE)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_high_pressure_delta(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_highpressure = MC_AVERAGE(cost_highpressure, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_SUPERCONDUCTIVITY

	if(currentpart == SSAIR_SUPERCONDUCTIVITY)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_super_conductivity(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_superconductivity = MC_AVERAGE(cost_superconductivity, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		currentpart = SSAIR_PROCESS_ATOMS

	if(currentpart == SSAIR_PROCESS_ATOMS)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
		process_atoms(resumed)
		cached_cost += TICK_USAGE_REAL - timer
		if(state != SS_RUNNING)
			return
		cost_atoms = MC_AVERAGE(cost_atoms, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE


	currentpart = SSAIR_PIPENETS
	SStgui.update_uis(SSair) //Lightning fast debugging motherfucker

/datum/controller/subsystem/air/Recover()
	excited_groups = SSair.excited_groups
	active_turfs = SSair.active_turfs
	hotspots = SSair.hotspots
	networks = SSair.networks
	rebuild_queue = SSair.rebuild_queue
	expansion_queue = SSair.expansion_queue
	adjacent_rebuild = SSair.adjacent_rebuild
	atmos_machinery = SSair.atmos_machinery
	pipe_init_dirs_cache = SSair.pipe_init_dirs_cache
	gas_reactions = SSair.gas_reactions
	atmos_gen = SSair.atmos_gen
	planetary = SSair.planetary
	active_super_conductivity = SSair.active_super_conductivity
	high_pressure_delta = SSair.high_pressure_delta
	atom_process = SSair.atom_process
	currentrun = SSair.currentrun
	queued_for_activation = SSair.queued_for_activation

/datum/controller/subsystem/air/proc/process_adjacent_rebuild(init = FALSE)
	var/list/queue = adjacent_rebuild

	while (length(queue))
		var/turf/currT = queue[1]
		var/goal = queue[currT]
		queue.Cut(1,2)

		currT.immediate_calculate_adjacent_turfs()
		if(goal == MAKE_ACTIVE)
			add_to_active(currT)
		else if(goal == KILL_EXCITED)
			add_to_active(currT, TRUE)

		if(init)
			CHECK_TICK
		else
			if(MC_TICK_CHECK)
				break

/datum/controller/subsystem/air/proc/process_pipenets(resumed = FALSE)
	if (!resumed)
		src.currentrun = networks.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/datum/thing = currentrun[currentrun.len]
		currentrun.len--
		if(thing)
			thing.process()
		else
			networks.Remove(thing)
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/add_to_rebuild_queue(obj/machinery/atmospherics/atmos_machine)
	// VOIDCREW EDIT: never queue a machine that is already dying. Its Destroy() has run (or
	// is running) its own pipenet teardown, so a rebuild can only mint a pipeline that
	// nothing will ever delete - see reap_orphan_pipelines(). Site teardown reaches this
	// constantly: pipe/nullify_node() queues the neighbour it just disconnected from, and
	// during a mass deletion that neighbour is very often already in the qdel queue.
	if(QDELETED(atmos_machine))
		return
	if(istype(atmos_machine, /obj/machinery/atmospherics) && !atmos_machine.rebuilding)
		rebuild_queue += atmos_machine
		atmos_machine.rebuilding = TRUE

/datum/controller/subsystem/air/proc/add_to_expansion(datum/pipeline/line, starting_point)
	var/list/new_packet = new(SSAIR_REBUILD_QUEUE)
	new_packet[SSAIR_REBUILD_PIPELINE] = line
	new_packet[SSAIR_REBUILD_QUEUE] = list(starting_point)
	expansion_queue += list(new_packet)

/datum/controller/subsystem/air/proc/remove_from_expansion(datum/pipeline/line)
	// VOIDCREW EDIT: remove every packet for this pipeline, not just the first, and
	// iterate a copy so the removal can't skip entries in the live list
	for(var/list/packet in expansion_queue.Copy())
		if(packet[SSAIR_REBUILD_PIPELINE] == line)
			expansion_queue -= packet

/datum/controller/subsystem/air/proc/process_atoms(resumed = FALSE)
	if(!resumed)
		src.currentrun = atom_process.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/atom/talk_to = currentrun[currentrun.len]
		currentrun.len--
		if(!talk_to)
			return
		talk_to.process_exposure()
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_atmos_machinery(resumed = FALSE)
	if (!resumed)
		src.currentrun = atmos_machinery.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/obj/machinery/M = currentrun[currentrun.len]
		currentrun.len--
		if(!M)
			atmos_machinery -= M
			// VOIDCREW EDIT: this branch used to fall straight through into
			// M.process_atmos() on the null it had just pruned.
			continue
		// VOIDCREW EDIT: a machine that is not plumbed yet does not run this tick. See
		// /obj/machinery/proc/atmos_plumbing_ready() below for why the gap exists at all.
		// The ismachinery() test is not decoration: this list is duck-typed on
		// process_atmos() and /datum/component/gas_leaker registers ITSELF in it, so the
		// readiness question can only be put to things that are really machinery.
		if(ismachinery(M) && !M.atmos_plumbing_ready())
			continue
		if(M.process_atmos(wait * 0.1) == PROCESS_KILL)
			stop_processing_machine(M)
		if(MC_TICK_CHECK)
			return

/**
 * VOIDCREW ADDITION: TRUE once this machine's atmos plumbing exists, so process_atmos() is
 * safe to run on it.
 *
 * An atmos machine joins SSair.atmos_machinery in its own Initialize() - see
 * /obj/machinery/atmospherics/Initialize()'s start_processing_machine() call - but its
 * pipenets are built much later, by whichever of setup_pipenets(), setup_template_machinery()
 * or the rebuild queue owns the thing that made it. At roundstart that ordering is invisible:
 * SSair.Initialize() runs both passes before fire() ever runs, so nothing processes unplumbed.
 *
 * Every LATE load reverses it. /datum/map_template/initTemplateBounds() initializes the atoms
 * first (SSatoms.InitializeAtoms yields), then builds the pipenets in
 * SSair.setup_template_machinery() - which CHECK_TICKs between machines - and for a modular
 * hull /datum/map_template/shuttle/dispatch() sleeps in half-second slices on top of that
 * while the modules load. SSair fires many times in every one of those gaps, against machines
 * whose `parents`/`parent` are still null. That is the whole "Cannot read null.air" family:
 * a mapped `on = 1` gas pump reads parents[2].air (pump.dm), a gas flow meter asks its pipe
 * for return_air() and the pipe reads parent.air (pipes.dm). It also made the noise that
 * followed - update_parents() warning "Component is missing a pipenet! Rebuilding..." and
 * queueing a rebuild that then floods a half-atmos_init()ed node graph.
 *
 * Skipping rather than guarding each process_atmos() is deliberate: there is nothing sensible
 * for an unplumbed machine to do, and the states are transient by construction - the loader
 * that created the machine finishes wiring it a few ticks later. Losing a pipenet while alive
 * (a neighbour deconstructed) is handled where it happens, in nullify_pipenet(), which queues
 * the rebuild.
 */
/obj/machinery/proc/atmos_plumbing_ready()
	return TRUE

/obj/machinery/atmospherics/components/atmos_plumbing_ready()
	// Both lists are minted once, as new(device_type), so unequal lengths means the component
	// is still part-built - which is a state to sit out, not to index into.
	if(isnull(parents) || isnull(airs) || length(parents) != length(airs))
		return FALSE
	for(var/i in 1 to length(parents))
		if(isnull(parents[i]) || isnull(airs[i]))
			return FALSE
	return TRUE

/obj/machinery/atmospherics/pipe/atmos_plumbing_ready()
	return !isnull(parent)

/// The meter reads its pipe's mixture, so it is the pipe's plumbing that has to be up.
/obj/machinery/meter/atmos_plumbing_ready()
	return isnull(target) || !isnull(target.parent)

/datum/controller/subsystem/air/proc/process_super_conductivity(resumed = FALSE)
	if (!resumed)
		src.currentrun = active_super_conductivity.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/turf/T = currentrun[currentrun.len]
		currentrun.len--
		T.super_conduct()
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_hotspots(resumed = FALSE)
	if (!resumed)
		src.currentrun = hotspots.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/obj/effect/hotspot/H = currentrun[currentrun.len]
		currentrun.len--
		if (H)
			H.process()
		else
			hotspots -= H
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_high_pressure_delta(resumed = FALSE)
	while (high_pressure_delta.len)
		var/turf/open/T = high_pressure_delta[high_pressure_delta.len]
		high_pressure_delta.len--
		T.high_pressure_movements()
		T.pressure_difference = 0
		if(MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_active_turfs(resumed = FALSE)
	//cache for sanic speed
	var/fire_count = times_fired
	if (!resumed)
		src.currentrun = active_turfs.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/turf/open/T = currentrun[currentrun.len]
		currentrun.len--
		if (T)
			T.process_cell(fire_count)
		if (MC_TICK_CHECK)
			return

/datum/controller/subsystem/air/proc/process_excited_groups(resumed = FALSE)
	if (!resumed)
		src.currentrun = excited_groups.Copy()
	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun
	while(currentrun.len)
		var/datum/excited_group/EG = currentrun[currentrun.len]
		currentrun.len--
		var/volatile_reaction = EG.turf_reactions & VOLATILE_REACTION
		EG.breakdown_cooldown++
		if(!volatile_reaction)
			EG.dismantle_cooldown++
		if(EG.breakdown_cooldown >= EXCITED_GROUP_BREAKDOWN_CYCLES && !volatile_reaction)
			EG.self_breakdown(poke_turfs = TRUE)
		else if(EG.dismantle_cooldown >= EXCITED_GROUP_DISMANTLE_CYCLES && !(EG.turf_reactions & (REACTING | STOP_REACTIONS)))
			EG.dismantle()
		EG.turf_reactions = NONE
		if (MC_TICK_CHECK)
			return

/**
 * VOIDCREW ADDITION: deletes the member-less pipelines expand_pipeline() had to park.
 *
 * Runs before the drain rather than inside it: /datum/pipeline/Destroy() calls
 * remove_from_expansion(), which edits the very list expand_pipeline() walks. By the time
 * we get here that drain has finished (or has not started), so the edit is safe.
 *
 * A husk is only deleted once `building` has cleared - while it is set the pipeline is
 * still queued for expansion and may legitimately pick members back up.
 */
/datum/controller/subsystem/air/proc/reap_pipeline_husks()
	if(!length(pipeline_husks))
		return
	for(var/datum/pipeline/husk as anything in pipeline_husks.Copy())
		if(QDELETED(husk))
			pipeline_husks -= husk
			continue
		if(husk.building)
			continue
		pipeline_husks -= husk
		// VOIDCREW EDIT: has_live_members() rather than length(). A husk that was holding
		// a machine which then hard deleted reads as length 1 with a null inside, and the
		// old length test let it walk away as if it were still in use.
		if(husk.has_live_members())
			continue
		qdel(husk)

/**
 * VOIDCREW ADDITION: reaps member-less pipelines that never went through the husk list.
 *
 * `reap_pipeline_husks()` only ever sees pipelines parked by the pipe-steal branch of
 * `expand_pipeline()`. The other way a pipeline ends up empty in `SSair.networks` is a
 * machine that was already dying when something queued it for a rebuild: `rebuild_pipes()`
 * mints a fresh `/datum/pipeline` for it, the machine's `Destroy()` has already run its
 * `QDEL_NULL(parent)`, and so nothing is ever going to delete that pipeline again. It sits
 * in `networks` being processed every fire for the rest of the round, and it holds a hard
 * ref to the dead machine while it is at it. The source guards below stop new ones being
 * made; this sweep clears any that still get through.
 *
 * Two details this has to get right:
 * * `length(members)` is not the test. A hard-deleted machine leaves a null entry in the
 *   list rather than shortening it, so a leaked pipeline reads as `members = list(null)` -
 *   length 1, live members 0. `has_live_members()` counts what is actually there.
 * * `/datum/pipeline/Destroy()` edits `networks`, `expansion_queue` and `pipeline_husks`.
 *   So: walk a copy, collect, and qdel only after the walk is over - and run outside the
 *   expansion drain, the same placement `reap_pipeline_husks()` already uses.
 */
/datum/controller/subsystem/air/proc/reap_orphan_pipelines()
	if(world.time < next_orphan_sweep)
		return
	next_orphan_sweep = world.time + orphan_sweep_interval
	var/list/datum/pipeline/doomed = list()
	for(var/datum/pipeline/net as anything in networks.Copy())
		if(isnull(net) || QDELETED(net))
			continue
		// Still queued for expansion - it is allowed to be empty and may pick members up.
		if(net.building)
			net.orphan_strikes = 0
			continue
		if(net.has_live_members())
			net.orphan_strikes = 0
			continue
		net.orphan_strikes++
		if(net.orphan_strikes < orphan_pipeline_strikes)
			continue
		doomed += net
	if(!length(doomed))
		return
	orphan_pipelines_reaped += length(doomed)
	for(var/datum/pipeline/net as anything in doomed)
		qdel(net)

/datum/controller/subsystem/air/proc/process_rebuilds()
	reap_pipeline_husks()
	//Yes this does mean rebuilding pipenets can freeze up the subsystem forever, but if we're in that situation something else is very wrong
	var/list/currentrun = rebuild_queue
	while(currentrun.len || length(expansion_queue))
		while(currentrun.len && !length(expansion_queue)) //If we found anything, process that first
			var/obj/machinery/atmospherics/remake = currentrun[currentrun.len]
			currentrun.len--
			// VOIDCREW EDIT: QDELETED, not just null. A machine queued while alive can be
			// deleted before the drain reaches it, and the old null check does not see
			// that - a queued-for-deletion machine is still a live ref. Rebuilding one
			// mints a pipeline its Destroy() has already stopped being able to clean up.
			if (!remake || QDELETED(remake))
				continue
			remake.rebuild_pipes()
			if (MC_TICK_CHECK)
				return

		var/list/queue = expansion_queue
		while(queue.len)
			var/list/pack = queue[queue.len]
			//We operate directly with the pipeline like this because we can trust any rebuilds to remake it properly
			var/datum/pipeline/linepipe = pack[SSAIR_REBUILD_PIPELINE]
			var/list/border = pack[SSAIR_REBUILD_QUEUE]
			expand_pipeline(linepipe, border)
			if(state != SS_RUNNING) //expand_pipeline can fail a tick check, we shouldn't let things get too fucky here
				return

			linepipe.building = FALSE
			queue.len--
			if (MC_TICK_CHECK)
				return

///Rebuilds a pipeline by expanding outwards, while yielding when sane
/datum/controller/subsystem/air/proc/expand_pipeline(datum/pipeline/net, list/border)
	while(border.len)
		var/obj/machinery/atmospherics/borderline = border[border.len]
		border.len--

		var/list/result = borderline.pipeline_expansion(net)
		if(!length(result))
			continue
		for(var/obj/machinery/atmospherics/considered_device in result)
			if(!istype(considered_device, /obj/machinery/atmospherics/pipe))
				// VOIDCREW EDIT: only register what actually attached - see
				// /obj/machinery/atmospherics/components/set_pipenet(). A one-way node link
				// (two same-layer pipes stacked on one turf) reaches here constantly on this
				// fork's hulls, and registering a component the pipeline could not attach is
				// what produced datum_pipeline.dm's "Nonexistent (empty list) ... gasmix".
				if(considered_device.set_pipenet(net, borderline))
					net.add_machinery_member(considered_device)
				continue
			var/obj/machinery/atmospherics/pipe/item = considered_device
			if(net.members.Find(item))
				continue
			if(item.parent)
				var/static/pipenetwarnings = 10
				if(pipenetwarnings > 0)
					log_mapping("build_pipeline(): [item.type] added to a pipenet while still having one. (pipes leading to the same spot stacking in one turf) around [AREACOORD(item)].")
					pipenetwarnings--
					if(pipenetwarnings == 0)
						log_mapping("build_pipeline(): further messages about pipenets will be suppressed")

			net.members += item
			border += item

			net.air.volume += item.volume
			// VOIDCREW EDIT: this is the one place a pipe is taken off a LIVE pipeline
			// without that pipeline being merged or destroyed - see the warning logged
			// above, which is exactly the case that reaches it. replace_pipenet() now
			// prunes the pipe out of its old pipeline's members, so stealing the last one
			// leaves a husk with no members and no machines that nothing but
			// SSair.networks points at: never garbage collected, and processed every
			// SSair tick for the rest of the round. Delete it, guarded the same way
			// components already guard theirs in nullify_pipenet(). Deliberately NOT done
			// inside replace_pipenet() itself - merge() calls that with a pipeline whose
			// members it has already detached and whose air it has not yet taken, so a
			// qdel there would drop the merged gas on the floor.
			var/datum/pipeline/stolen_from = item.parent
			item.replace_pipenet(item.parent, net)
			// A `building` husk cannot be deleted here: its Destroy() would edit
			// expansion_queue, which is the list this very drain is walking. Park it and
			// let reap_pipeline_husks() take it on a later fire - leaving it was a
			// permanent member-less pipeline in SSair.networks, one per site build.
			if(stolen_from && stolen_from != net && !QDELETED(stolen_from) && !length(stolen_from.members) && !length(stolen_from.other_atmos_machines))
				if(stolen_from.building)
					pipeline_husks |= stolen_from
				else
					qdel(stolen_from)

			if(item.air_temporary)
				net.air.merge(item.air_temporary)
				item.air_temporary = null

		if (MC_TICK_CHECK)
			return

///Removes a turf from processing, and causes its excited group to clean up so things properly adapt to the change
/datum/controller/subsystem/air/proc/remove_from_active(turf/open/T)
	active_turfs -= T
	if(currentpart == SSAIR_ACTIVETURFS)
		currentrun -= T
	#ifdef VISUALIZE_ACTIVE_TURFS //Use this when you want details about how the turfs are moving, display_all_groups should work for normal operation
	T.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, COLOR_VIBRANT_LIME)
	#endif
	if(istype(T))
		T.excited = FALSE
		if(T.excited_group)
			//If this fires during active turfs it'll cause a slight removal of active turfs, as they breakdown if they have no excited group
			//The group also expands by a tile per rebuild on each edge, suffering
			T.excited_group.garbage_collect() //Kill the excited group, it'll reform on its own later

///Puts an active turf to sleep so it doesn't process. Do this without cleaning up its excited group.
/datum/controller/subsystem/air/proc/sleep_active_turf(turf/open/T)
	active_turfs -= T
	if(currentpart == SSAIR_ACTIVETURFS)
		currentrun -= T
	#ifdef VISUALIZE_ACTIVE_TURFS
	T.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, COLOR_VIBRANT_LIME)
	#endif
	if(istype(T))
		T.excited = FALSE

///Adds a turf to active processing, handles duplicates. Call this with blockchanges == TRUE if you want to nuke the assoc excited group
/datum/controller/subsystem/air/proc/add_to_active(turf/open/activate, blockchanges = FALSE)
	if(istype(activate) && activate.air)
		activate.significant_share_ticker = 0
		if(blockchanges && activate.excited_group) //This is used almost exclusivly for shuttles, so the excited group doesn't stay behind
			activate.excited_group.garbage_collect() //Nuke it
		if(activate.excited) //Don't keep doing it if there's no point
			return
		#ifdef VISUALIZE_ACTIVE_TURFS
		activate.add_atom_colour(COLOR_VIBRANT_LIME, TEMPORARY_COLOUR_PRIORITY)
		#endif
		activate.excited = TRUE
		active_turfs += activate
	else if(activate.flags_1 & INITIALIZED_1)
		for(var/turf/neighbor as anything in activate.atmos_adjacent_turfs)
			add_to_active(neighbor, TRUE)
	else if(map_loading)
		if(queued_for_activation)
			queued_for_activation[activate] = activate
	else
		activate.requires_activation = TRUE

/datum/controller/subsystem/air/StartLoadingMap()
	LAZYINITLIST(queued_for_activation)
	map_loading = TRUE

/datum/controller/subsystem/air/StopLoadingMap()
	map_loading = FALSE
	for(var/T in queued_for_activation)
		add_to_active(T, TRUE)
	queued_for_activation.Cut()

/datum/controller/subsystem/air/proc/setup_allturfs()
	var/list/active_turfs = src.active_turfs
	times_fired++

	// Clear active turfs - faster than removing every single turf in the world
	// one-by-one, and Initalize_Atmos only ever adds `src` back in.
	#ifdef VISUALIZE_ACTIVE_TURFS
	for(var/jumpy in active_turfs)
		var/turf/active = jumpy
		active.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, COLOR_VIBRANT_LIME)
	#endif
	active_turfs.Cut()
	// We compare this against turf.current cycle using <= to ensure O(n)
	// It defaults to 0, so we start at -1
	var/time = -1

	var/list/turf/open/difference_check = list()
	for(var/turf/setup as anything in ALL_TURFS())
		if (!setup.init_air)
			continue
		// We pass the tick as the current step so if we sleep the step changes
		// This way we can make setting up adjacent turfs O(n) rather then O(n^2)
		setup.Initalize_Atmos(time)
		// We assert that we'll only get open turfs here
		difference_check += setup
		if(CHECK_TICK)
			time--

	// Now we're gonna compare for differences
	// Taking advantage of current cycle being set to negative before this run to do A->B B->A prevention
	for(var/turf/open/potential_diff as anything in difference_check)
		// I can't use 0 here, so we're gonna do this instead. If it ever breaks I'll eat my shoe
		potential_diff.current_cycle = -INFINITY
		for(var/turf/open/enemy_tile as anything in potential_diff.atmos_adjacent_turfs)
			// If it's already been processed, then it's already talked to us
			if(enemy_tile.current_cycle == -INFINITY)
				continue
			// .air instead of .return_air() because we can guarantee that the proc won't do anything
			if(potential_diff.air.compare(enemy_tile.air, FALSE))
				if(!potential_diff.excited)
					potential_diff.excited = TRUE
					SSair.active_turfs += potential_diff
				if(!enemy_tile.excited)
					enemy_tile.excited = TRUE
					SSair.active_turfs += enemy_tile
				// No sense continuing to iterate
				break
		CHECK_TICK

	if(active_turfs.len)
		var/starting_ats = active_turfs.len
		sleep(world.tick_lag)
		var/timer = world.timeofday

		log_mapping("There are [starting_ats] active turfs at roundstart caused by a difference of the air between the adjacent turfs. \
		To locate these active turfs, go into the \"Debug\" tab of your stat-panel. Then hit the verb that says \"Mapping Verbs - Enable\". \
		Now, you can see all of the associated coordinates using \"Mapping -> Show roundstart AT list\" verb.")

		for(var/turf/T in active_turfs)
			GLOB.active_turfs_startlist += T

		//now lets clear out these active turfs
		var/list/turfs_to_check = active_turfs.Copy()
		do
			var/list/new_turfs_to_check = list()
			for(var/turf/open/T in turfs_to_check)
				new_turfs_to_check += T.resolve_active_graph()
			CHECK_TICK

			active_turfs += new_turfs_to_check
			turfs_to_check = new_turfs_to_check
		while (turfs_to_check.len)

		var/ending_ats = active_turfs.len
		for(var/thing in excited_groups)
			var/datum/excited_group/EG = thing
			EG.self_breakdown(roundstart = TRUE)
			EG.dismantle()
			CHECK_TICK

		log_active_turfs() // invoke this here so we can count the time it takes to run this proc as "wasted time", quite simple honestly.

		var/msg = "HEY! LISTEN! [DisplayTimeText(world.timeofday - timer, 0.00001)] were wasted processing [starting_ats] turf(s) (connected to [ending_ats - starting_ats] other turfs) with atmos differences at round start."
		to_chat(world, span_boldannounce("[msg]"))
		warning(msg)

/// Logs all active turfs at roundstart to the mapping log so it can be readily accessed.
/datum/controller/subsystem/air/proc/log_active_turfs()
// sadly this has to be here because we can't realistically expect that all active turfs will be resolved in every possible situation when running through CI.
// In an ideal world, we would have absolutely zero active turfs 99.99% of the time, but that's not the case. `log_mapping()` during world initialize triggers a CI fail.
#ifdef UNIT_TESTS
	return
#else
	// Associated lists, left-hand-side is the z-level or z-trait, right-hand-side is the number of active turfs associated with that.
	var/list/tally_by_level = list()
	// Discriminate for certain z-traits, stuff like "Linkage" is not helpful.
	var/list/tally_by_level_trait = list(
		ZTRAIT_AWAY = 0,
		ZTRAIT_CENTCOM = 0,
		ZTRAIT_ICE_RUINS = 0,
		ZTRAIT_ICE_RUINS_UNDERGROUND  = 0,
		ZTRAIT_ISOLATED_RUINS = 0,
		ZTRAIT_LAVA_RUINS = 0,
		ZTRAIT_MINING = 0,
		ZTRAIT_RESERVED = 0,
		ZTRAIT_SPACE_RUINS = 0,
		ZTRAIT_STATION = 0,
	)

	var/list/message_to_log = list()

	message_to_log += "\nAll that follows is a turf with an active air difference at roundstart. To clear this, make sure that all of the turfs listed below are connected to a turf with the same air contents.\n\
		In an ideal world, this list should have enough information to help you locate the active turf(s) in question. Unfortunately, this might not be an ideal world.\n\
		If the round is still ongoing, you can use the \"Mapping -> Show roundstart AT list\" verb to see exactly what active turfs were detected. Otherwise, good luck."

	for(var/turf/active_turf as anything in GLOB.active_turfs_startlist)
		var/turf_z = active_turf.z
		var/datum/space_level/level = SSmapping.z_list[turf_z]
		var/list/level_traits = list()
		for(var/trait in level.traits)
			if(!isnull(tally_by_level_trait[trait]))
				level_traits += trait
				tally_by_level_trait[trait]++

		// so we can pass along the area type for the log, making it much easier to locate the active turf for a mapper assuming all area types are unique. This is only really a problem for stuff like ruin areas.
		var/area/turf_area = get_area(active_turf)
		message_to_log += "Active turf: [AREACOORD(active_turf)] ([turf_area.type]). Turf type: [active_turf.type]. Relevant Z-Trait(s): [english_list(level_traits)]."

		tally_by_level["[turf_z]"]++

	// Following is so we can detect which rounds were "problematic" as far as active turfs go.
	SSblackbox.record_feedback("amount", "overall_roundstart_active_turfs", length(GLOB.active_turfs_startlist))

	for(var/z_level in tally_by_level)
		var/level_turf_count = tally_by_level[z_level]
		if(level_turf_count == 0) // no point logging it
			continue
		message_to_log += "Z-Level [z_level] has [level_turf_count] active turf(s)."
		SSblackbox.record_feedback("tally", "roundstart_active_turfs_per_z", level_turf_count, z_level)

	for(var/z_trait in tally_by_level_trait)
		var/trait_turf_count = tally_by_level_trait[z_trait]
		if(trait_turf_count == 0)
			continue
		message_to_log += "Z-Level trait [z_trait] has [trait_turf_count] active turf(s)."
		SSblackbox.record_feedback("amount", "roundstart_active_turfs_for_trait_[z_trait]", trait_turf_count)

	message_to_log += "End of active turf list."
	log_mapping(message_to_log.Join("\n"))
#endif

/turf/open/proc/resolve_active_graph()
	. = list()
	var/datum/excited_group/EG = excited_group
	if (blocks_air || !air)
		return
	if (!EG)
		EG = new
		EG.add_turf(src)

	for (var/turf/open/ET in atmos_adjacent_turfs)
		if (ET.blocks_air || !ET.air)
			continue

		var/ET_EG = ET.excited_group
		if (ET_EG)
			if (ET_EG != EG)
				EG.merge_groups(ET_EG)
				EG = excited_group //merge_groups() may decide to replace our current EG
		else
			EG.add_turf(ET)
		if (!ET.excited)
			ET.excited = TRUE
			. += ET

/turf/open/space/resolve_active_graph()
	return list()

/datum/controller/subsystem/air/proc/setup_atmos_machinery()
	for (var/obj/machinery/atmospherics/AM in atmos_machinery)
		AM.atmos_init()
		CHECK_TICK

//this can't be done with setup_atmos_machinery() because
// all atmos machinery has to initialize before the first
// pipenet can be built.
/datum/controller/subsystem/air/proc/setup_pipenets()
	for (var/obj/machinery/atmospherics/AM in atmos_machinery)
		// VOIDCREW EDIT: same reason as rebuild_pipes() - get_rebuild_targets() mints a
		// pipeline into SSair.networks, and a machine that deleted itself during its own
		// Initialize() will never delete that pipeline again.
		if(QDELETED(AM))
			continue
		var/list/targets = AM.get_rebuild_targets()
		for(var/datum/pipeline/build_off as anything in targets)
			build_off.build_pipeline_blocking(AM)
		CHECK_TICK

GLOBAL_LIST_EMPTY(colored_turfs)
GLOBAL_LIST_EMPTY(colored_images)
/datum/controller/subsystem/air/proc/setup_turf_visuals()
	for(var/sharp_color in GLOB.contrast_colors)
		var/list/add_to = list()
		GLOB.colored_turfs += list(add_to)
		for(var/offset in 0 to SSmapping.max_plane_offset)
			var/obj/effect/overlay/atmos_excited/suger_high = new()
			SET_PLANE_W_SCALAR(suger_high, HIGH_GAME_PLANE, offset)
			add_to += suger_high
			var/image/shiny = new('icons/effects/effects.dmi', suger_high, "atmos_top")
			SET_PLANE_W_SCALAR(shiny, HIGH_GAME_PLANE, offset)
			shiny.color = sharp_color
			GLOB.colored_images += shiny

/datum/controller/subsystem/air/proc/setup_template_machinery(list/atmos_machines)
	var/obj/machinery/atmospherics/AM
	for(var/A in 1 to atmos_machines.len)
		AM = atmos_machines[A]
		AM.atmos_init()
		CHECK_TICK

	for(var/A in 1 to atmos_machines.len)
		AM = atmos_machines[A]
		// VOIDCREW EDIT: a template's atmos machine can delete itself during atmos_init()
		// (stacked pipes on one turf, which every voidcrew hull has some of). Minting a
		// pipeline for it leaks one per template load, and this soak loads constantly.
		if(QDELETED(AM))
			continue
		var/list/targets = AM.get_rebuild_targets()
		for(var/datum/pipeline/build_off as anything in targets)
			build_off.build_pipeline_blocking(AM)
		CHECK_TICK


/datum/controller/subsystem/air/proc/get_init_dirs(type, dir, init_dir)

	if(!pipe_init_dirs_cache[type])
		pipe_init_dirs_cache[type] = list()

	if(!pipe_init_dirs_cache[type]["[init_dir]"])
		pipe_init_dirs_cache[type]["[init_dir]"] = list()

	if(!pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"])
		var/obj/machinery/atmospherics/temp = new type(null, FALSE, dir, init_dir)
		pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"] = temp.get_init_directions()
		qdel(temp)

	return pipe_init_dirs_cache[type]["[init_dir]"]["[dir]"]

/datum/controller/subsystem/air/proc/generate_atmos()
	atmos_gen = list()
	for(var/T in subtypesof(/datum/atmosphere))
		var/datum/atmosphere/atmostype = T
		atmos_gen[initial(atmostype.id)] = new atmostype

/// Takes a gas string, returns the matching mutable gas_mixture
/datum/controller/subsystem/air/proc/parse_gas_string(gas_string, gastype = /datum/gas_mixture)
	var/datum/gas_mixture/cached = strings_to_mix["[gas_string]-[gastype]"]

	if(cached)
		if(istype(cached, /datum/gas_mixture/immutable))
			return cached
		return cached.copy()

	var/datum/gas_mixture/canonical_mix = new gastype()
	// We set here so any future key changes don't fuck us
	strings_to_mix["[gas_string]-[gastype]"] = canonical_mix
	gas_string = preprocess_gas_string(gas_string)

	var/list/gas = params2list(gas_string)
	if(gas["TEMP"])
		canonical_mix.temperature = text2num(gas["TEMP"])
		canonical_mix.temperature_archived = canonical_mix.temperature
		gas -= "TEMP"
	else // if we do not have a temp in the new gas mix lets assume room temp.
		canonical_mix.temperature = T20C
	var/list/cached_moles = canonical_mix.moles
	for(var/id in gas)
		var/path = id
		if(!ispath(path))
			path = gas_id2path(path) //a lot of these strings can't have embedded expressions (especially for mappers), so support for IDs needs to stick around
		// VOIDCREW EDIT: an unknown id (a mapper typo, or a gas string from another
		// codebase that was never ported - "ws_atmos") resolves to "" here, and the
		// assignment below would then key the mix on null once per turf that uses the
		// string. Warn once for the mix instead and leave that component out.
		if(!ispath(path))
			stack_trace("parse_gas_string(): unknown gas id \"[id]\" in gas string \"[gas_string]\" - ignoring it.")
			continue
		cached_moles[path] = text2num(gas[id])

	if(istype(canonical_mix, /datum/gas_mixture/immutable))
		return canonical_mix
	return canonical_mix.copy()

/datum/controller/subsystem/air/proc/preprocess_gas_string(gas_string)
	if(!atmos_gen)
		generate_atmos()
	if(!atmos_gen[gas_string])
		return gas_string
	var/datum/atmosphere/mix = atmos_gen[gas_string]
	return mix.gas_string

/**
 * Adds a given machine to the processing system for SSAIR_ATMOSMACHINERY processing.
 *
 * Arguments:
 * * machine - The machine to start processing. Can be any /obj/machinery.
 */
/datum/controller/subsystem/air/proc/start_processing_machine(obj/machinery/machine)
	if(machine.atmos_processing)
		return
	if(QDELETED(machine))
		stack_trace("We tried to add a garbage collecting machine to SSair. Don't")
		return
	machine.atmos_processing = TRUE
	atmos_machinery += machine

/**
 * Removes a given machine to the processing system for SSAIR_ATMOSMACHINERY processing.
 *
 * Arguments:
 * * machine - The machine to stop processing.
 */
/datum/controller/subsystem/air/proc/stop_processing_machine(obj/machinery/machine)
	if(!machine.atmos_processing)
		return
	machine.atmos_processing = FALSE
	atmos_machinery -= machine

	// If we're currently processing atmos machines, there's a chance this machine is in
	// the currentrun list, which is a cache of atmos_machinery. Remove it from that list
	// as well to prevent processing qdeleted objects in the cache.
	if(currentpart == SSAIR_ATMOSMACHINERY)
		currentrun -= machine

/datum/controller/subsystem/air/ui_state(mob/user)
	return ADMIN_STATE(R_DEBUG)

/datum/controller/subsystem/air/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosControlPanel")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/controller/subsystem/air/ui_data(mob/user)
	var/list/data = list()
	data["excited_groups"] = list()
	for(var/datum/excited_group/group in excited_groups)
		var/turf/T = group.turf_list[1]
		var/area/target = get_area(T)
		var/max = 0
		#ifdef TRACK_MAX_SHARE
		for(var/who in group.turf_list)
			var/turf/open/lad = who
			max = max(lad.max_share, max)
		#endif
		data["excited_groups"] += list(list(
			"jump_to" = REF(T), //Just go to the first turf
			"group" = REF(group),
			"area" = target.name,
			"breakdown" = group.breakdown_cooldown,
			"dismantle" = group.dismantle_cooldown,
			"size" = group.turf_list.len,
			"should_show" = group.should_display,
			"max_share" = max
		))
	data["active_size"] = active_turfs.len
	data["hotspots_size"] = hotspots.len
	data["excited_size"] = excited_groups.len
	data["conducting_size"] = active_super_conductivity.len
	data["frozen"] = can_fire
	data["show_all"] = display_all_groups
	data["fire_count"] = times_fired
	#ifdef TRACK_MAX_SHARE
	data["display_max"] = TRUE
	#else
	data["display_max"] = FALSE
	#endif
	data["showing_user"] = user.hud_used.atmos_debug_overlays
	return data

/datum/controller/subsystem/air/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !check_rights_for(usr.client, R_DEBUG))
		return
	switch(action)
		if("move-to-target")
			var/turf/target = locate(params["spot"])
			if(!target)
				return
			usr.forceMove(target)
		if("toggle-freeze")
			can_fire = !can_fire
			return TRUE
		if("toggle_show_group")
			var/datum/excited_group/group = locate(params["group"])
			if(!group)
				return
			group.should_display = !group.should_display
			if(display_all_groups)
				return TRUE
			if(group.should_display)
				group.display_turfs()
			else
				group.hide_turfs()
			return TRUE
		if("toggle_show_all")
			display_all_groups = !display_all_groups
			for(var/datum/excited_group/group in excited_groups)
				if(display_all_groups)
					group.display_turfs()
				else if(!group.should_display) //Don't flicker yeah?
					group.hide_turfs()
			return TRUE
		if("toggle_user_display")
			var/mob/user = ui.user
			user.hud_used.atmos_debug_overlays = !user.hud_used.atmos_debug_overlays
			if(user.hud_used.atmos_debug_overlays)
				user.client.images += GLOB.colored_images
			else
				user.client.images -= GLOB.colored_images
			return TRUE
