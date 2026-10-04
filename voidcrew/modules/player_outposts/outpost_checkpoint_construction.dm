/**
 * # Staged ship construction
 *
 * The ship is loaded once, through the ordinary template loader, into the outpost's shipyard
 * zone (outpost_level_layout.dm), where nobody can reach it and which this job holds while it
 * runs. Its pieces then move into the permanent bay one tile visit at a time,
 * through the same per-atom shuttle move hooks a docking uses, so the finished hull is what
 * a normal landing would have left behind and departs the same way.
 *
 * Single pass: a visit is marked done before any of its pieces move, and nothing rescans
 * the bay. A piece that is removed, moved or damaged after placement stays that way.
 *
 * The source is what the job builds from and what it spends at the first piece. This type
 * rebuilds a saved checkpoint: stock is scrubbed and parts are restored in the hidden copy
 * before any of it can be reached, and the checkpoint is consumed immediately before the
 * first piece. /datum/checkpoint_construction/order (outpost_ship_orders.dm) builds a new
 * ship from the catalog instead, and charges its buyer at that point. The hooks each source
 * overrides are grouped under SOURCE below.
 */
/obj/structure/overmap/dynamic/player_outpost
	var/list/datum/checkpoint_construction/checkpoint_jobs = list()

/// One bay tile's share of one build stage.
/datum/checkpoint_visit
	var/stage
	/// Index into the paired source and bay turf lists.
	var/index
	/// This visit moves the tile's own deck or wall and its room.
	var/hull = FALSE
	var/list/datum/weakref/pieces = list()
	var/done = FALSE
	/// Distance band from the middle of the footprint; each stage grows outward.
	var/ring = 0
	var/obj/effect/checkpoint_build_drone/drone

/datum/checkpoint_construction
	var/state = CHECKPOINT_BUILD_PREPARING
	var/obj/structure/overmap/dynamic/player_outpost/home
	var/datum/outpost_berth/ship_bay/bay
	var/datum/ship_checkpoint/snapshot
	var/datum/weakref/panel_ref
	/// Only used to reapply console upgrade disks while the hidden copy is prepared.
	var/datum/weakref/operator_ref
	var/datum/weakref/original_ref
	var/captain_ckey
	var/ship_name
	/// What the hidden copy is loaded from. Checkpoints use their commissioned checkpoint
	/// template; orders a plain hull template. The ship record keeps it at handover.
	var/datum/map_template/shuttle/voidcrew/template
	/// The loaded copy. Its port joins the bay before the first piece does.
	var/obj/docking_port/mobile/voidcrew/port
	/// The outpost's shipyard zone: holds every piece that has not been placed yet.
	var/datum/outpost_zone/source_zone
	/// TRUE while the template is being written into the shipyard; nothing may wipe it then.
	var/copy_loading = FALSE
	/// Paired by index, exactly as initiate_docking() pairs a move.
	var/list/turf/source_turfs
	var/list/turf/bay_turfs
	/// Indices of every tile belonging to the saved hull.
	var/list/hull_indices = list()
	var/rotation = 0
	var/source_dir
	var/move_dir
	var/list/movement_force = list("KNOCKDOWN" = 0, "THROW" = 0)
	/// Pending visits per stage, in build order.
	var/list/stage_visits
	/// Every visit that has run, in the order it ran.
	var/list/datum/checkpoint_visit/completed_visits = list()
	/// Bay tile -> the bay room it had, for every tile a visit gave to the ship.
	/// Removal reads this rather than the port, which may already be gone.
	var/list/placed_hull_tiles = list()
	/// The bay's own room under the landing rectangle, before any piece arrived.
	var/area/bay_area
	/// Where the docking port sits in the paired turf lists.
	var/port_index = 0
	/// The saving captain's own account: refunds, and funds for a hull nobody collected.
	var/datum/weakref/captain_account_ref
	/// Handover is irreversible and must never run twice.
	var/handover_started = FALSE
	var/stage = CHECKPOINT_STAGE_DECK
	var/visit_total = 0
	var/visits_done = 0
	var/committed = FALSE
	var/frame_done = FALSE
	/// Taken from the original's account at commitment, paid to the rebuilt ship.
	var/held_balance = 0
	var/obj/structure/overmap/ship/vessel
	var/list/markers = list()
	var/list/obj/effect/checkpoint_build_drone/drones = list()
	var/next_phase_at = 0
	var/last_progress_at = 0
	var/last_reported_percent = -1
	var/error
	/// Tests place visits directly instead of waiting for drones.
	var/manual = FALSE
	/// Set when drones stop making progress; remaining visits are then placed directly.
	var/direct_placement = FALSE
	/// Admin testing: direct placement with a larger per-tick budget.
	var/rushed = FALSE
	/// Ship room -> its own base lighting, list(colour, alpha), while floodlit for the build.
	var/list/lit_rooms = list()
	/// Waiting for the shared shuttle loader. The bay stays reserved meanwhile.
	var/queued = FALSE
	/// world.time the shared loader was granted, for status and testing.
	var/load_started_at
	/// Status and log wording for this kind of build.
	var/status_verb = "Rebuilding"
	var/build_noun = "Reconstruction"

/// leave_original: an admin copy of a hull that is still in service. It is not retired and
/// keeps its money; the checkpoint is still consumed.
/datum/checkpoint_construction/New(datum/ship_checkpoint_ui/terminal, datum/ship_checkpoint/blueprint, mob/living/user, manual_drive = FALSE, leave_original = FALSE)
	panel_ref = terminal ? WEAKREF(terminal) : null
	operator_ref = WEAKREF(user)
	snapshot = blueprint
	home = blueprint.outpost
	captain_ckey = blueprint.captain_ckey
	ship_name = blueprint.ship_name
	manual = manual_drive
	var/obj/structure/overmap/ship/original = leave_original ? null : blueprint.source_ship?.resolve()
	if(original)
		original_ref = WEAKREF(original)
	// Refunds follow the checkpoint's owner, who is the operator unless an admin started it.
	var/mob/living/owner = user?.ckey == captain_ckey ? user : get_mob_by_ckey(captain_ckey)
	var/datum/bank_account/personal = istype(owner) ? owner.get_bank_account() : null
	if(personal)
		captain_account_ref = WEAKREF(personal)
	// Claim the bay before any yield, so a second request cannot reserve it too.
	bay = home.reserve_rebuild_bay(src)
	if(!bay)
		// Nothing was locked, so there is nothing for cleanup to release.
		state = CHECKPOINT_BUILD_FAILED
		return
	home.checkpoint_jobs += src
	snapshot.busy = TRUE
	if(original)
		original.checkpoint_rebuilding = TRUE
	RegisterSignal(home, COMSIG_QDELETING, PROC_REF(on_site_deleted))
	RegisterSignal(bay, COMSIG_QDELETING, PROC_REF(on_site_deleted))
	RegisterSignal(snapshot, COMSIG_QDELETING, PROC_REF(on_checkpoint_deleted))

/// Once pieces exist, only a forced deletion may stop the job; it then removes them.
/datum/checkpoint_construction/Destroy(force)
	if(state != CHECKPOINT_BUILD_COMPLETE && state != CHECKPOINT_BUILD_FAILED)
		if(committed && !force)
			return QDEL_HINT_LETMELIVE
		abort("[build_noun] was cancelled.", delete_job = FALSE)
	STOP_PROCESSING(SSfastprocess, src)
	clear_site_effects()
	restore_room_lighting()
	if(home)
		home.checkpoint_jobs -= src
		UnregisterSignal(home, COMSIG_QDELETING)
	if(bay)
		UnregisterSignal(bay, COMSIG_QDELETING)
	if(snapshot)
		UnregisterSignal(snapshot, COMSIG_QDELETING)
	home = null
	bay = null
	snapshot = null
	port = null
	vessel = null
	// A load still writing into the shipyard lets it go itself when it returns (load_source()).
	if(!copy_loading)
		source_zone = null
	source_turfs = null
	bay_turfs = null
	stage_visits = null
	QDEL_NULL(template)
	return ..()

/datum/checkpoint_construction/proc/on_site_deleted(datum/source)
	SIGNAL_HANDLER
	// Releasing reservations can yield; the removal itself finishes before the bay goes.
	INVOKE_ASYNC(src, PROC_REF(abort), "The ship bay was removed.")

/datum/checkpoint_construction/proc/on_checkpoint_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(snapshot, COMSIG_QDELETING)
	snapshot = null
	if(!committed)
		INVOKE_ASYNC(src, PROC_REF(abort), "This checkpoint is no longer available.")

// ===== PREPARATION =====

/// Loads and plans the hidden copy. Returns TRUE once the survey markers are down.
/datum/checkpoint_construction/proc/prepare()
	if(!bay)
		error = "The ship bay is occupied or reserved."
		return FALSE
	// The shared loader is held only for the load itself, never for the build. A rebuild waits
	// its turn behind purchases and earlier rebuilds, keeping its bay, rather than giving up.
	queued = TRUE
	update_bay_status()
	var/loaded = SSshuttle.run_template_load(CALLBACK(src, PROC_REF(load_source)), background = TRUE, keep_waiting = CALLBACK(src, PROC_REF(still_queued)))
	queued = FALSE
	if(QDELETED(src) || state != CHECKPOINT_BUILD_PREPARING)
		return FALSE
	if(!loaded || !plan())
		abort(error || "Construction failed. [unspent_note()]")
		return FALSE
	begin_marking()
	return TRUE

/// Runs while this job owns SSshuttle's template load. Every reference is rechecked after it yields.
/datum/checkpoint_construction/proc/load_source(datum/shuttle_template_load/load_owner)
	queued = FALSE
	if(QDELETED(src) || state != CHECKPOINT_BUILD_PREPARING)
		return FALSE
	load_started_at = world.time
	update_bay_status()
	error = build_denial()
	if(error)
		return FALSE
	template = create_template()
	if(!template)
		error ||= "The hull could not be loaded. [unspent_note()]"
		return FALSE
	SSair.can_fire = FALSE
	var/obj/docking_port/mobile/voidcrew/loaded_port = load_copy(load_owner)
	if(QDELETED(src) || state != CHECKPOINT_BUILD_PREPARING)
		// Stopped while the copy loaded: nothing could clear the shipyard under the loader.
		discard_copy(loaded_port)
		return FALSE
	port = loaded_port
	if(!istype(port) || QDELETED(port) || !has_source_ground())
		error = "The hull could not be loaded. [unspent_note()]"
		return FALSE
	RegisterSignal(port, COMSIG_QDELETING, PROC_REF(on_port_deleted))
	error = build_denial()
	if(error)
		return FALSE
	// Atmos stays paused while this job holds the loader, so the copy can be frozen tile by tile
	// across ticks. The copy is still exactly as loaded here.
	for(var/turf/tile as anything in port.return_turfs())
		if(TICK_CHECK)
			stoplag()
			// Only this job can end it early; it then discards the copy itself.
			if(!source_still_loading())
				return FALSE
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		// The copy loses its windows and doors long before its floors. Frozen, it cannot
		// vent, trip firelocks or blow unplaced fittings off their tiles.
		tile.blocks_air = TRUE
		tile.air_update_turf(TRUE, TRUE)
		// Player ships carry no door access. Clear it before anyone can reach a door.
		for(var/obj/machinery/door/door in tile)
			door.req_access = null
			door.req_one_access = null
	mark_phase("freeze")
	prepare_copy()
	return TRUE

/// Whether a queued job still wants the shared loader. Anything that ended it already
/// released its bay and kept its checkpoint.
/datum/checkpoint_construction/proc/still_queued()
	return !QDELETED(src) && state == CHECKPOINT_BUILD_PREPARING

/// Rechecked after every pause while the hidden copy is prepared.
/datum/checkpoint_construction/proc/source_still_loading()
	return !QDELETED(src) && state == CHECKPOINT_BUILD_PREPARING && !QDELETED(port) && has_source_ground()

/// Whether the hidden copy still holds its ground: the shipyard zone, claimed and not given back.
/datum/checkpoint_construction/proc/has_source_ground()
	return !isnull(source_zone) && source_zone.is_held_by(src)

/// Every turf of the hidden copy's ground in block() order; empty once it is given back.
/datum/checkpoint_construction/proc/get_source_block()
	if(!has_source_ground())
		return list()
	return source_zone.get_block()

/// Shared checks before any piece exists.
/datum/checkpoint_construction/proc/build_denial()
	if(QDELETED(home) || QDELETED(bay) || !IS_WEAKREF_OF(src, bay.rebuild_owner) || QDELETED(bay.dock) || !bay.has_ground())
		return "The ship bay is no longer reserved."
	if(bay.ship || (bay.dock.get_docked() && (!port || bay.dock.get_docked() != port)))
		return "The ship bay is occupied."
	return source_denial()

// ===== SOURCE =====
// A checkpoint rebuild. /datum/checkpoint_construction/order overrides these.

/// Why the source can no longer be built, or null.
/datum/checkpoint_construction/proc/source_denial()
	if(QDELETED(snapshot) || snapshot.outpost != home || !(snapshot in home.checkpoints))
		return "This checkpoint is no longer available."
	var/obj/structure/overmap/ship/original = original_ref?.resolve()
	if(original)
		if(original.retired_by_checkpoint)
			return "The original hull has already been replaced."
		if(!QDELETED(original.shuttle) && !original.abandoned)
			return "The original hull must be lost or abandoned."
	return null

/// Added to every refusal made before the first piece.
/datum/checkpoint_construction/proc/unspent_note()
	return "Your checkpoint is still available."

/// The template the hidden copy is loaded from.
/datum/checkpoint_construction/proc/create_template()
	return new /datum/map_template/shuttle/voidcrew/commissioned/checkpoint(snapshot)

/// Loads the template into the shipyard while this job owns the loader. Returns the copy's port.
/datum/checkpoint_construction/proc/load_copy(datum/shuttle_template_load/load_owner)
	return load_hidden_copy(load_owner)

/**
 * Loads the template a tile in from the shipyard zone's corner, the way SSshuttle.load_template()
 * loads a preview but without reserving turfs: the zone is the outpost's own. Must run while this
 * job owns SSshuttle's template load. Returns the unregistered port, or null.
 */
/datum/checkpoint_construction/proc/load_hidden_copy(datum/shuttle_template_load/load_owner)
	var/datum/outpost_zone/yard = home?.level_zone(OUTPOST_ZONE_YARD)
	if(!yard || !template?.width || !template?.height)
		return null
	if(template.width > yard.get_width() - 2 || template.height > yard.get_height() - 2)
		log_mapping("OUTPOST SHIPYARD: [template.name] ([template.width]x[template.height]) does not fit the [yard.get_width()]x[yard.get_height()] shipyard at [home].")
		return null
	// The last build's copy may still be being wiped away.
	if(yard.state == OUTPOST_ZONE_WIPING)
		var/deadline = world.time + 30 SECONDS
		UNTIL(yard.state != OUTPOST_ZONE_WIPING || world.time > deadline)
	if(QDELETED(src) || state != CHECKPOINT_BUILD_PREPARING || !yard.claim(src))
		return null
	source_zone = yard
	copy_loading = TRUE
	var/obj/docking_port/mobile/loaded_port = load_shuttle_template_at(template, locate(yard.low_x + 1, yard.low_y + 1, yard.z_value))
	copy_loading = FALSE
	yard.occupy()
	return loaded_port

/// Runs once on the loaded, frozen copy, before anyone could reach any of it.
/datum/checkpoint_construction/proc/prepare_copy()
	// Scrubbing and restoring stay in one tick: a machine processed in between would run with
	// its stock gone and its parts not yet restored (an APC without its cell, for one).
	// Initialization may stock lockers or engine tanks even though no items were saved.
	clear_stock(port)
	var/mob/living/operator = operator_ref?.resolve()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/machinery/machine in tile)
			restore_machine(machine, operator)
	mark_phase("scrub_and_restore")

/**
 * Spends the source immediately before the first piece, and sets committed. From here the
 * job only moves forward: partial output is never rolled back into a fresh checkpoint.
 * Returns FALSE, with error set, when it cannot be spent; nothing is spent then.
 */
/datum/checkpoint_construction/proc/consume_source()
	committed = TRUE
	UnregisterSignal(snapshot, COMSIG_QDELETING)
	var/datum/ship_checkpoint/consumed = snapshot
	snapshot = null
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/checkpoint_template = template
	checkpoint_template.blueprint = null
	qdel(consumed)
	var/obj/structure/overmap/ship/original = original_ref?.resolve()
	if(original)
		original.retired_by_checkpoint = TRUE
		original.checkpoint_rebuilding = FALSE
		var/balance = original.ship_account?.account_balance
		if(balance > 0 && original.ship_account.adjust_money(-balance, "Checkpoint recovery"))
			held_balance = balance
		if(QDELETED(original.shuttle))
			qdel(original)
	log_game("Checkpoint for [ship_name] ([captain_ckey]) at [home.name] was consumed by its reconstruction.")
	return TRUE

/// Lets go of the source when the job stops. Before the first piece it stays spendable.
/datum/checkpoint_construction/proc/release_source()
	var/obj/structure/overmap/ship/original = original_ref?.resolve()
	if(committed)
		// Everything placed is gone with the bay, so the old hull is no longer replaced.
		if(original)
			original.retired_by_checkpoint = FALSE
			original.checkpoint_rebuilding = FALSE
		return_held_balance(original)
		return
	if(!QDELETED(snapshot))
		snapshot.busy = FALSE
	if(original)
		original.checkpoint_rebuilding = FALSE

/// Which stage places a loose item or creature, or null when it stays with the hidden copy.
/datum/checkpoint_construction/proc/cargo_stage(atom/movable/thing)
	return null

/// The ship record for the finished hull, set up from the template but not yet placed.
/datum/checkpoint_construction/proc/create_vessel()
	var/obj/structure/overmap/ship/record = new(get_turf(home))
	record.starting_credits = 0
	if(!record.setup_from_template(template))
		qdel(record)
		return null
	return record

/// Names the record and its hull. A rebuild keeps the saved ship's name.
/datum/checkpoint_construction/proc/name_vessel()
	vessel.name = ship_name
	vessel.display_name = ship_name
	port.name = ship_name
	vessel.ship_team.name = ship_name
	vessel.ship_account.account_holder = ship_name

/// Runs after the finished hull's SHIP_LOADED signal, before anyone is handed it.
/datum/checkpoint_construction/proc/after_ship_loaded()
	return

/// For the handover log.
/datum/checkpoint_construction/proc/finished_text()
	return "rebuilt from its checkpoint"

/// Records the template's timing phases; only a checkpoint template keeps them.
/datum/checkpoint_construction/proc/mark_phase(phase)
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/checkpoint_template = template
	if(istype(checkpoint_template))
		checkpoint_template.mark_phase(phase)

// ===== PLANNING =====

/// Pairs every saved tile with its bay tile and queues the visits.
/datum/checkpoint_construction/proc/plan()
	error = build_denial()
	if(error || QDELETED(port) || !has_source_ground())
		error ||= "The hull could not be loaded. [unspent_note()]"
		return FALSE
	var/obj/docking_port/stationary/dock = bay.dock
	adjust_reserve_dock_to_shuttle(dock, port)
	if(!port_fits(dock))
		error = "This hull does not fit the ship bay. [unspent_note()]"
		return FALSE
	bay_area = get_area(dock)
	source_dir = port.dir
	move_dir = REVERSE_DIR(port.preferred_direction)
	if(dock.dir != port.dir)
		rotation = dir2angle(dock.dir) - dir2angle(port.dir)
		if((rotation % 90) != 0)
			rotation += (rotation % 90)
		rotation = SIMPLIFY_DEGREES(rotation)
	var/list/source_order = port.return_ordered_turfs(port.x, port.y, port.z, port.dir)
	var/list/bay_order = port.return_ordered_turfs(dock.x, dock.y, dock.z, dock.dir)
	source_turfs = list()
	bay_turfs = list()
	for(var/i in 1 to length(source_order))
		source_turfs += source_order[i]
		bay_turfs += bay_order[i]
	port_index = source_turfs.Find(get_turf(port))
	if(!port_index || bay_turfs[port_index] != get_turf(dock))
		error = "The hull could not be loaded. [unspent_note()]"
		return FALSE
	stage_visits = list()
	for(var/i in 1 to CHECKPOINT_STAGE_COUNT)
		stage_visits += list(list())
	var/list/by_tile_stage = list()
	var/center_x = 0
	var/center_y = 0
	for(var/i in 1 to length(source_turfs))
		var/turf/source = source_turfs[i]
		if(!source || !port.shuttle_areas[source.loc])
			continue
		var/turf/target = bay_turfs[i]
		if(!target || !bay.contains_turf(target))
			error = "This hull does not fit the ship bay. [unspent_note()]"
			return FALSE
		hull_indices += i
		center_x += target.x
		center_y += target.y
		var/hull_stage = isclosedturf(source) ? CHECKPOINT_STAGE_HULL : CHECKPOINT_STAGE_DECK
		var/datum/checkpoint_visit/hull_visit = add_visit(by_tile_stage, i, hull_stage)
		hull_visit.hull = TRUE
		// A real landing carries a tile's contents only when preflight would. Anything it
		// would leave behind stays with the hidden copy and is discarded.
		var/tile_mode = source.loc.beforeShuttleMove(port.shuttle_areas)
		for(var/atom/movable/thing as anything in source.contents)
			if(thing.loc == source)
				tile_mode = thing.hypotheticalShuttleMove(rotation, tile_mode, port)
		tile_mode = source.fromShuttleMove(target, tile_mode)
		if(!(tile_mode & MOVE_CONTENTS))
			continue
		// Machines land before cables: a cable only honours an SMES/terminal pairing when
		// that machine is already on its tile as it relinks.
		var/list/obj/machinery/machines_first = list()
		var/list/atom/movable/everything_else = list()
		// Pipe connectors a machine made for itself travel with it, not as pieces of their own.
		var/list/obj/machinery/atmospherics/riders = list()
		for(var/obj/machinery/machine in source.contents)
			riders |= machine.checkpoint_atmos_parts()
		for(var/atom/movable/thing as anything in source.contents)
			// Some fittings delete or replace themselves after loading; WEAKREF() of one is null.
			if(thing.loc != source || thing == port || QDELETED(thing) || (thing in riders))
				continue
			if(ismachinery(thing))
				machines_first += thing
			else
				everything_else += thing
		for(var/atom/movable/thing as anything in machines_first + everything_else)
			var/piece_stage = piece_stage(thing, hull_stage)
			if(!piece_stage)
				continue
			var/datum/checkpoint_visit/visit = add_visit(by_tile_stage, i, piece_stage)
			visit.pieces += WEAKREF(thing)
	if(!length(hull_indices))
		error = "The hull is empty. [unspent_note()]"
		return FALSE
	center_x = round(center_x / length(hull_indices))
	center_y = round(center_y / length(hull_indices))
	// Each stage grows outward from the middle of the footprint.
	for(var/stage_number in 1 to CHECKPOINT_STAGE_COUNT)
		var/list/by_ring = list()
		for(var/datum/checkpoint_visit/visit as anything in stage_visits[stage_number])
			var/turf/target = bay_turfs[visit.index]
			visit.ring = max(abs(target.x - center_x), abs(target.y - center_y)) + 1
			if(length(by_ring) < visit.ring)
				by_ring.len = visit.ring
			if(!by_ring[visit.ring])
				by_ring[visit.ring] = list()
			by_ring[visit.ring] += visit
		var/list/ordered = list()
		for(var/list/ring_visits in by_ring)
			ordered += ring_visits
		stage_visits[stage_number] = ordered
		visit_total += length(ordered)
	return TRUE

/datum/checkpoint_construction/proc/add_visit(list/by_tile_stage, index, visit_stage)
	var/key = "[index]:[visit_stage]"
	var/datum/checkpoint_visit/visit = by_tile_stage[key]
	if(visit)
		return visit
	visit = new
	visit.index = index
	visit.stage = visit_stage
	by_tile_stage[key] = visit
	var/list/queue = stage_visits[visit_stage]
	queue += visit
	return visit

/// The ordinary loader's fit test, without asking the dock, which is reserved for us.
/datum/checkpoint_construction/proc/port_fits(obj/docking_port/stationary/dock)
	if(port.dwidth > dock.dwidth || port.width - port.dwidth > dock.width - dock.dwidth)
		return FALSE
	if(port.dheight > dock.dheight || port.height - port.dheight > dock.height - dock.dheight)
		return FALSE
	return TRUE

/// Which stage places this atom, or null when it is discarded with the hidden copy.
/datum/checkpoint_construction/proc/piece_stage(atom/movable/thing, hull_stage)
	if(istype(thing, /obj/docking_port))
		return null
	if(isitem(thing) || ismob(thing))
		return cargo_stage(thing)
	if(iseffect(thing))
		return hull_stage
	if(istype(thing, /obj/structure/lattice))
		return CHECKPOINT_STAGE_DECK
	if(istype(thing, /obj/structure/grille) || istype(thing, /obj/structure/window) || istype(thing, /obj/structure/falsewall) || istype(thing, /obj/machinery/door))
		return CHECKPOINT_STAGE_HULL
	if(istype(thing, /obj/machinery/cryopod) || istype(thing, /obj/machinery/shower) || istype(thing, /obj/machinery/iv_drip) || istype(thing, /obj/machinery/defibrillator_mount))
		return CHECKPOINT_STAGE_MACHINERY
	if(istype(thing, /obj/structure/cable) || istype(thing, /obj/structure/disposalpipe) || istype(thing, /obj/machinery/power/smes) || is_type_in_typecache(thing, GLOB.outpost_checkpoint_infrastructure))
		return CHECKPOINT_STAGE_SYSTEMS
	if(ismachinery(thing))
		return CHECKPOINT_STAGE_MACHINERY
	return CHECKPOINT_STAGE_FITTINGS

/datum/checkpoint_construction/proc/begin_marking()
	state = CHECKPOINT_BUILD_MARKING
	// New deck takes the air on its spot, so start from a settled hangar.
	bay.refresh_hangar_air()
	for(var/index in hull_indices)
		var/turf/target = bay_turfs[index]
		markers[target] = new /obj/effect/checkpoint_build_marker(target)
	next_phase_at = world.time + CHECKPOINT_BUILD_SURVEY_TIME
	if(!manual)
		spawn_drones()
		START_PROCESSING(SSfastprocess, src)
	update_bay_status()
	log_game("[build_noun] of [ship_name] for [captain_ckey] started at [home.name] ([visit_total] visits).")

// ===== CONTROLLER =====

/datum/checkpoint_construction/process(seconds_per_tick)
	SHOULD_NOT_SLEEP(TRUE)
	switch(state)
		if(CHECKPOINT_BUILD_MARKING)
			var/denial = build_denial()
			if(denial)
				abort(denial)
				return PROCESS_KILL
			if(world.time >= next_phase_at)
				begin_building()
		if(CHECKPOINT_BUILD_BUILDING)
			if(!committed)
				var/denial = build_denial()
				if(denial)
					abort(denial)
					return PROCESS_KILL
			if(direct_placement)
				fast_forward(rushed ? CHECKPOINT_BUILD_RUSH_BUDGET : CHECKPOINT_BUILD_VISIT_BUDGET)
				return
			run_drones()
			if(state == CHECKPOINT_BUILD_BUILDING && world.time - last_progress_at > CHECKPOINT_BUILD_STALL_TIME)
				// Never wait forever on a lost drone: place the rest of the queue directly, in order.
				log_game("[build_noun] of [ship_name] stalled; placing its remaining pieces directly.")
				direct_placement = TRUE
		if(CHECKPOINT_BUILD_COMMISSIONING)
			try_commission()
		else
			return PROCESS_KILL

/datum/checkpoint_construction/proc/begin_building()
	if(state != CHECKPOINT_BUILD_MARKING)
		return
	state = CHECKPOINT_BUILD_BUILDING
	last_progress_at = world.time
	launch_drones()
	advance_stage()
	update_bay_status()

/// Drones launch from the bay's corner drone bays, shared out evenly, each keeping its own.
/datum/checkpoint_construction/proc/spawn_drones()
	var/list/obj/structure/checkpoint_drone_bay/cradles = list()
	for(var/turf/tile as anything in bay.get_block())
		for(var/obj/structure/checkpoint_drone_bay/cradle in tile)
			cradles += cradle
	// Maps without drone bays launch from the bay console instead.
	var/obj/machinery/computer/console = bay.console
	var/turf/fallback = console ? get_turf(console) : (length(bay.alcove_turfs) ? bay.alcove_turfs[1] : get_turf(bay.dock))
	var/count = clamp(CEILING(visit_total / CHECKPOINT_BUILD_VISITS_PER_DRONE, 1), CHECKPOINT_BUILD_MIN_DRONES, CHECKPOINT_BUILD_MAX_DRONES)
	for(var/i in 1 to count)
		var/obj/structure/checkpoint_drone_bay/cradle = length(cradles) ? cradles[(i - 1) % length(cradles) + 1] : null
		drones += new /obj/effect/checkpoint_build_drone(cradle ? get_turf(cradle) : fallback, cradle)

/// The survey is over: the drones leave their bays.
/datum/checkpoint_construction/proc/launch_drones()
	if(!length(drones))
		return
	var/list/obj/structure/checkpoint_drone_bay/launched = list()
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones)
		if(QDELETED(drone))
			continue
		var/obj/structure/checkpoint_drone_bay/cradle = drone.cradle_ref?.resolve()
		if(cradle && !(cradle in launched))
			launched += cradle
			cradle.launch()
	play_to_checkpoint_yard(bay, CHECKPOINT_YARD_LAUNCH_SOUND)

/// One bounded pass over the drones: travel, finish work, or take the next visit.
/datum/checkpoint_construction/proc/run_drones()
	var/budget = CHECKPOINT_BUILD_VISIT_BUDGET
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones.Copy())
		if(QDELETED(drone))
			drones -= drone
			var/datum/checkpoint_visit/lost_visit = drone?.visit
			if(drone)
				drone.visit = null
			requeue(lost_visit)
			continue
		var/datum/checkpoint_visit/visit = drone.visit
		if(visit?.done)
			drone.finish_work()
			visit = null
		if(visit)
			if(drone.work_until)
				if(world.time < drone.work_until || budget <= 0)
					continue
				budget--
				// Free the drone first, so a runtime while placing cannot strand it.
				drone.finish_work()
				execute_visit(visit)
				if(QDELETED(src) || state != CHECKPOINT_BUILD_BUILDING)
					return
				continue
			var/turf/target = bay_turfs[visit.index]
			if(drone.fly_towards(target))
				drone.start_work(target, visit_preview(visit))
			continue
		var/datum/checkpoint_visit/next = next_visit()
		if(next)
			next.drone = drone
			drone.visit = next
			drone.fly_towards(bay_turfs[next.index])
		// With nothing left in this stage, a drone waits where it is for the stragglers.
	advance_stage()

/datum/checkpoint_construction/proc/next_visit()
	if(stage > CHECKPOINT_STAGE_COUNT)
		return null
	var/list/queue = stage_visits[stage]
	while(length(queue))
		var/datum/checkpoint_visit/visit = queue[1]
		queue.Cut(1, 2)
		if(!visit.done)
			return visit
	return null

/// A lost drone's unfinished visit goes back to the front of its stage.
/datum/checkpoint_construction/proc/requeue(datum/checkpoint_visit/visit)
	if(!visit || visit.done)
		return
	visit.drone = null
	var/list/queue = stage_visits[visit.stage]
	queue.Insert(1, visit)

/datum/checkpoint_construction/proc/stage_finished()
	if(length(stage_visits[stage]))
		return FALSE
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones)
		if(drone?.visit?.stage == stage && !drone.visit.done)
			return FALSE
	return TRUE

/// Stages finish in order; the last one hands over to commissioning.
/datum/checkpoint_construction/proc/advance_stage()
	if(state != CHECKPOINT_BUILD_BUILDING)
		return
	while(stage <= CHECKPOINT_STAGE_COUNT && stage_finished())
		stage++
	if(stage > CHECKPOINT_STAGE_COUNT)
		begin_commissioning()

/// Places queued visits immediately and in order. Tests and stalled builds use this.
/datum/checkpoint_construction/proc/fast_forward(limit = INFINITY)
	if(state == CHECKPOINT_BUILD_MARKING)
		begin_building()
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones)
		if(drone?.visit)
			requeue(drone.visit)
			drone.finish_work()
	while(limit > 0 && state == CHECKPOINT_BUILD_BUILDING)
		var/datum/checkpoint_visit/visit = next_visit()
		if(!visit)
			var/stage_before = stage
			advance_stage()
			if(state != CHECKPOINT_BUILD_BUILDING || stage == stage_before)
				break
			continue
		limit--
		execute_visit(visit)
		// A finished stage hands over at once, before any piece of the next one.
		advance_stage()
	return visits_done

/// Admin testing: skips the survey and the drones. Visits still run once and in order, within a
/// per-tick budget, so a large hull cannot stall the server.
/datum/checkpoint_construction/proc/rush()
	if(manual)
		return FALSE
	if(state == CHECKPOINT_BUILD_MARKING)
		begin_building()
	if(state != CHECKPOINT_BUILD_BUILDING)
		return FALSE
	direct_placement = TRUE
	rushed = TRUE
	return TRUE

/// Hands a finished hull over if it has not been already. It normally goes the moment it is finished.
/datum/checkpoint_construction/proc/hand_over_now()
	return try_commission()

// ===== PLACEMENT =====

/**
 * Runs one visit exactly once. The visit is recorded as done before anything moves: a
 * runtime part way through leaves the rest of that tile unbuilt rather than repeating it.
 */
/datum/checkpoint_construction/proc/execute_visit(datum/checkpoint_visit/visit)
	if(!visit || visit.done || QDELETED(src) || state != CHECKPOINT_BUILD_BUILDING)
		return FALSE
	if(!committed && !commit())
		return FALSE
	visit.done = TRUE
	visit.drone = null
	completed_visits += visit
	visits_done++
	last_progress_at = world.time
	var/turf/source = source_turfs[visit.index]
	var/turf/target = bay_turfs[visit.index]
	if(visit.hull)
		place_hull(source, target)
	for(var/datum/weakref/piece_ref as anything in visit.pieces)
		var/atom/movable/piece = piece_ref?.resolve()
		if(piece)
			place_piece(piece, source, target)
	report_progress()
	return TRUE

/// Spends the source immediately before the first piece, then moves the frame into the bay.
/datum/checkpoint_construction/proc/commit()
	var/denial = build_denial()
	if(!denial && (QDELETED(port) || !has_source_ground()))
		denial = "The hull could not be loaded. [unspent_note()]"
	if(denial)
		abort(denial)
		return FALSE
	if(!consume_source())
		abort(error)
		return FALSE
	place_frame()
	return TRUE

/// Moves the port into the bay and registers it, as a landing would, before the first piece.
/datum/checkpoint_construction/proc/place_frame()
	if(frame_done || QDELETED(port) || QDELETED(bay?.dock))
		return frame_done
	var/turf/port_source = source_turfs[port_index]
	var/turf/port_target = bay_turfs[port_index]
	frame_done = TRUE
	port.checkpoint_construction = TRUE
	port.onShuttleMove(port_target, port_source, movement_force, move_dir, null, port)
	port.setDir(bay.dock.dir)
	port.unlink_from_z_level()
	port.link_to_z_level()
	port.recalculate_shuttle_areas()
	for(var/area/room as anything in port.shuttle_areas)
		room.afterShuttleMove(0)
	if(!port.registered)
		port.register()
		port.postregister()
	port.mode = SHUTTLE_IDLE
	port.timer = 0
	return TRUE

/// The deck or wall of one tile, and its room. The hidden source tile is left intact.
/datum/checkpoint_construction/proc/place_hull(turf/source, turf/target)
	var/area/room = source.loc
	if(QDELETED(port) || !port.shuttle_areas[room])
		return
	clear_marker(target)
	var/area/site_area = target.loc
	var/move_mode = room.beforeShuttleMove(port.shuttle_areas)
	move_mode = source.fromShuttleMove(target, move_mode)
	// A new tile keeps the hangar air already on its spot. Carrying the saved air would drop
	// vacuum pockets (airless exterior plating) into a pressurised bay and blow people around.
	var/datum/gas_mixture/bay_air
	if(isopenturf(target))
		var/turf/open/open_target = target
		bay_air = open_target.air?.copy()
	if(move_mode & MOVE_TURF)
		// Bay grime is under the new deck. Players and whatever they brought stay put.
		for(var/obj/effect/decal/cleanable/grime in target)
			qdel(grime)
		source.onShuttleMove(target, movement_force, move_dir, TRUE)
	if(site_area != room)
		target.change_area(site_area, room)
		port.underlying_areas_by_turf[target] = site_area
		placed_hull_tiles[target] = site_area
		floodlight_room(room, site_area)
	if(!(move_mode & MOVE_TURF))
		return
	source.TransferComponents(target)
	SSexplosions.wipe_turf(target)
	if(rotation)
		target.shuttleRotate(rotation)
	SEND_SIGNAL(target, COMSIG_TURF_AFTER_SHUTTLE_MOVE, source)
	target.lateShuttleMove(source)
	if(bay_air && isopenturf(target))
		var/turf/open/open_deck = target
		open_deck.air?.copy_from(bay_air)
		open_deck.air_update_turf(TRUE, FALSE)
	// lateShuttleMove() reopened the hidden tile; keep the copy sealed.
	source.blocks_air = TRUE
	source.air_update_turf(TRUE, TRUE)
	port.record_checkpoint_hull_turf(target)

/// Moves one initialized piece with the hooks a shuttle move uses, then tops it up.
/datum/checkpoint_construction/proc/place_piece(atom/movable/piece, turf/source, turf/target)
	if(QDELETED(piece) || piece.loc != source || QDELETED(port))
		return FALSE
	var/obj/machinery/power/power_machine = piece
	if(istype(power_machine))
		power_machine.disconnect_from_network()
	var/obj/machinery/duct/duct = piece
	if(istype(duct))
		detach_duct(duct)
	if(istype(piece, /obj/machinery/atmospherics))
		detach_atmos(piece)
	// A machine's own pipe connector (a cryo cell's) is carried by the machine when it moves.
	var/list/obj/machinery/atmospherics/riders = list()
	if(ismachinery(piece))
		var/obj/machinery/machine = piece
		riders = machine.checkpoint_atmos_parts()
	for(var/obj/machinery/atmospherics/rider as anything in riders)
		detach_atmos(rider)
		rider.beforeShuttleMove(target, rotation, MOVE_AREA | MOVE_TURF | MOVE_CONTENTS, port)
	var/list/merge_groups = detach_mergers(piece)
	piece.beforeShuttleMove(target, rotation, MOVE_AREA | MOVE_TURF | MOVE_CONTENTS, port)
	if(!piece.onShuttleMove(target, source, movement_force, move_dir, null, port) || piece.loc != target)
		return FALSE
	// Riders turn first: their machine's own after-move hook may then line them up with it.
	for(var/obj/machinery/atmospherics/rider as anything in riders)
		if(rider.loc != target)
			rider.abstract_move(target)
		rider.afterShuttleMove(source, movement_force, source_dir, port.preferred_direction, move_dir, rotation)
	piece.afterShuttleMove(source, movement_force, source_dir, port.preferred_direction, move_dir, rotation)
	if(istype(piece, /obj/machinery/atmospherics))
		attach_atmos(piece, source)
	else if(istype(duct))
		attach_duct(duct, source)
	else
		piece.lateShuttleMove(source, movement_force, move_dir)
	for(var/obj/machinery/atmospherics/rider as anything in riders)
		attach_atmos(rider, source)
	if(istype(power_machine))
		power_machine.connect_to_network()
	attach_mergers(piece, merge_groups)
	// Plumbing reconnects after a move only if it was connected when it left, and the hidden
	// copy's load can leave an anchored machine switched off. Anchored plumbing is always on.
	for(var/datum/component/plumbing/plumber as anything in piece.GetComponents(/datum/component/plumbing))
		if(!plumber.active && piece.anchored)
			plumber.enable()
	// Smoothing is worked out from neighbours, and most of this piece's arrive after it.
	if(piece.smoothing_flags & USES_SMOOTHING)
		QUEUE_SMOOTH(piece)
		QUEUE_SMOOTH_NEIGHBORS(piece)
	if(ismachinery(piece))
		provision_machine(piece)
	return TRUE

/**
 * Firelocks and stationary tanks share state with the like atoms beside them through a
 * /datum/merger. A whole-ship move carries a group at once; one tile at a time, a moved member
 * would stay listed in a group whose other members are still in the hidden copy, and the
 * group's next refresh drops it without a group of its own. Leave the group before moving, the
 * way the group itself hands a leaving member its share.
 * Returns merger id -> list(allowed types, the group left behind).
 */
/datum/checkpoint_construction/proc/detach_mergers(atom/movable/piece)
	var/list/rejoin = list()
	for(var/id in piece.mergers?.Copy())
		var/datum/merger/group = piece.mergers[id]
		group.RemoveMember(piece)
		if(!length(group.members))
			rejoin[id] = list(group.merged_typecache, null)
			qdel(group)
			continue
		rejoin[id] = list(group.merged_typecache, group)
		// Handlers (tanks splitting their shared air) act on members leaving through a refresh.
		SEND_SIGNAL(group, COMSIG_MERGER_REFRESH_COMPLETE, list(piece), list())
	return rejoin

/// Joins the like atoms already in the bay, or starts a group of its own.
/datum/checkpoint_construction/proc/attach_mergers(atom/movable/piece, list/rejoin)
	for(var/id in rejoin)
		var/list/typecache = rejoin[id][1]
		var/datum/merger/left_behind = rejoin[id][2]
		// Now that the piece is gone, the group finds out whether it only held two halves together.
		if(left_behind && !QDELETED(left_behind))
			left_behind.Refresh()
		if(!QDELETED(piece))
			piece.GetMergeGroup(id, typecache)

/**
 * A whole-ship move keeps every pipe beside its neighbours. One tile at a time does not, and
 * lateShuttleMove() would nullify each distant node, which for a component also deletes that
 * port's gas mix. Leave the hidden copy's network first; the move then reconnects in the bay.
 */
/datum/checkpoint_construction/proc/detach_atmos(obj/machinery/atmospherics/device)
	var/list/obj/machinery/atmospherics/left_behind = list()
	for(var/obj/machinery/atmospherics/node as anything in device.nodes)
		if(node)
			left_behind |= node
	// A neighbour can hold a link the device does not return (stacked or mismatched pipes in
	// the saved layout). Left alone it would reach into the bay once the device is there.
	var/list/turf/nearby_turfs = list(get_turf(device))
	for(var/direction in GLOB.cardinals)
		nearby_turfs += get_step(device, direction)
	for(var/turf/nearby as anything in nearby_turfs)
		for(var/obj/machinery/atmospherics/other in nearby)
			if(other != device && (device in other.nodes))
				left_behind |= other
	if(istype(device, /obj/machinery/atmospherics/components))
		var/obj/machinery/atmospherics/components/component = device
		component.disconnect_nodes()
	else
		// Not device_type: a layer manifold keeps a variable node list and has no fixed count.
		for(var/i in 1 to length(device.nodes))
			var/obj/machinery/atmospherics/node = device.nodes[i]
			if(!node)
				continue
			if(device in node.nodes)
				node.disconnect(device)
			device.nodes[i] = null
		device.destroy_network()
	for(var/obj/machinery/atmospherics/node as anything in left_behind)
		if(device in node.nodes)
			node.disconnect(device)
		SSair.add_to_rebuild_queue(node)

/**
 * Replaces the atmospherics lateShuttleMove() relink. That merges straight into the
 * neighbours' pipelines, which fails when a neighbour placed moments earlier is still
 * waiting for its own. Link both ways here and let SSair rebuild the joined network.
 */
/datum/checkpoint_construction/proc/attach_atmos(obj/machinery/atmospherics/device, turf/source)
	SEND_SIGNAL(device, COMSIG_ATOM_LATE_SHUTTLE_MOVE, source, movement_force, move_dir)
	if(device.pipe_vision_img)
		device.pipe_vision_img.loc = device.loc
	device.atmos_init()
	var/list/obj/machinery/atmospherics/neighbours = list()
	for(var/obj/machinery/atmospherics/node as anything in device.nodes)
		if(node)
			neighbours |= node
	for(var/obj/machinery/atmospherics/node as anything in neighbours)
		node.atmos_init()
		if(!(device in node.nodes))
			// The neighbour will not take the link back (its port is already used). A one-way
			// link makes the rebuild runtime and leaves this port without a gas mix.
			device.disconnect(node)
			continue
		if(istype(node, /obj/machinery/atmospherics/components))
			// The port facing us was built into a network of its own while it had nothing to
			// join. Release it, or the old network lingers once ours takes the port.
			var/obj/machinery/atmospherics/components/component = node
			var/port_index = component.nodes.Find(device)
			var/datum/pipeline/lonely = component.parents[port_index]
			if(lonely)
				component.nullify_pipenet(lonely)
		else
			node.destroy_network()
		SSair.add_to_rebuild_queue(node)
	SSair.add_to_rebuild_queue(device)

/**
 * Plumbing ducts remember their neighbours, and their lateShuttleMove() treats one that is
 * not beside them yet as lost. Tile by tile that is true of every neighbour until the last
 * arrives, so a duct whose neighbours all landed first never looks around again. Leave the
 * hidden copy's ductnet cleanly instead; attach_duct() connects to whatever is in the bay.
 */
/datum/checkpoint_construction/proc/detach_duct(obj/machinery/duct/duct)
	if(duct.duct)
		duct.duct.remove_duct(duct)
	for(var/obj/machinery/duct/other in duct.neighbours)
		other.neighbours -= duct
		other.generate_connects()
	duct.neighbours = list()

/// Joins the bay's ducts and plumbed machines, as a newly laid duct would.
/datum/checkpoint_construction/proc/attach_duct(obj/machinery/duct/duct, turf/source)
	SEND_SIGNAL(duct, COMSIG_ATOM_LATE_SHUTTLE_MOVE, source, movement_force, move_dir)
	// A dumb duct's connects are its saved, rotated shape; a smart one works them out again.
	if(!duct.dumb)
		duct.reset_connects()
	duct.attempt_connect()

/// New decks join the ship's unpowered rooms, so they would lose the hangar's ambient light.
/// Each room borrows it until the build ends.
/datum/checkpoint_construction/proc/floodlight_room(area/room, area/site_area)
	if(lit_rooms[room])
		return
	lit_rooms[room] = list(room.base_lighting_color, room.base_lighting_alpha)
	var/alpha = max(site_area.base_lighting_alpha, CHECKPOINT_BUILD_FLOODLIGHT_ALPHA)
	room.set_base_lighting(site_area.base_lighting_alpha ? site_area.base_lighting_color : CHECKPOINT_BUILD_FLOODLIGHT_COLOR, alpha)

/datum/checkpoint_construction/proc/restore_room_lighting()
	for(var/area/room as anything in lit_rooms)
		if(QDELETED(room))
			continue
		var/list/original = lit_rooms[room]
		room.set_base_lighting(original[1], original[2])
	lit_rooms.Cut()

/datum/checkpoint_construction/proc/visit_preview(datum/checkpoint_visit/visit)
	if(visit.hull)
		var/turf/source = source_turfs[visit.index]
		if(!isspaceturf(source))
			return source
	for(var/datum/weakref/piece_ref as anything in visit.pieces)
		var/atom/movable/piece = piece_ref?.resolve()
		if(piece && !iseffect(piece) && piece.invisibility < INVISIBILITY_ABSTRACT)
			return piece
	return null

// ===== COMMISSIONING =====

/datum/checkpoint_construction/proc/begin_commissioning()
	state = CHECKPOINT_BUILD_COMMISSIONING
	// Every visit has run; nothing more is needed from the hidden copy.
	discard_source()
	// The drones go home and the floodlights go off now; the ship is handed over straight after.
	clear_site_effects()
	restore_room_lighting()
	update_bay_status()
	try_commission()

/// A living mob with the saving captain's key, wherever they are.
/datum/checkpoint_construction/proc/find_captain()
	var/mob/living/candidate = get_mob_by_ckey(captain_ckey)
	if(!istype(candidate) || candidate.stat == DEAD || !candidate.mind)
		return null
	return candidate

/// The saving captain's mind wherever they are: in a body, dead, ghosted or logged out. Null when nobody holds their key.
/datum/checkpoint_construction/proc/captain_mind()
	var/mob/living/captain = find_captain()
	if(captain)
		return captain.mind
	var/mob/somewhere = get_mob_by_ckey(captain_ckey)
	return somewhere?.mind

/// Hands the finished hull over at once: to its captain wherever they are, or claimable at its helm when nobody holds their key.
/datum/checkpoint_construction/proc/try_commission()
	if(state != CHECKPOINT_BUILD_COMMISSIONING)
		return FALSE
	return commission(find_captain())

/// Makes `command` the finished ship's captain, and gives their body, if they have one, the ship's management button
/datum/checkpoint_construction/proc/enlist_captain(datum/mind/command)
	if(!command || !vessel?.ship_team)
		return FALSE
	var/mob/living/body = command.current
	if(isliving(body) && body.mind == command)
		vessel.enlist_crewmember(body)
		grant_captain_management(body, vessel)
	else
		vessel.ship_team.add_member(command)
		if(!(command.name in vessel.manifest))
			vessel.manifest += command.name
		if(captain_ckey)
			vessel.password_cleared_ckeys[captain_ckey] = TRUE
	vessel.claimed_captain = command
	return TRUE

/// Ownership exists only from here: nobody can join, claim or fly an unfinished hull.
/datum/checkpoint_construction/proc/commission(mob/living/captain)
	if(state != CHECKPOINT_BUILD_COMMISSIONING || handover_started || QDELETED(bay) || QDELETED(home))
		return FALSE
	handover_started = TRUE
	STOP_PROCESSING(SSfastprocess, src)
	place_frame()
	clear_site_effects()
	discard_source()
	if(QDELETED(port) || port.get_docked() != bay.dock || bay.ship || !IS_WEAKREF_OF(src, bay.rebuild_owner))
		stack_trace("[build_noun] of [ship_name] finished without a docked hull it could hand over.")
		abort("The finished hull could not be commissioned.")
		return FALSE
	vessel = create_vessel()
	if(!vessel)
		stack_trace("[build_noun] of [ship_name] could not create its ship record.")
		abort("The finished hull could not be commissioned.")
		return FALSE
	// The ship record keeps its source template; the job must not delete it.
	template = null
	port.current_ship = vessel
	vessel.shuttle = port
	vessel.docked = home
	vessel.forceMove(home)
	vessel.state = OVERMAP_SHIP_IDLE
	name_vessel()
	// Door access was cleared on the hidden copy, so doors reconfigured during the build keep it.
	vessel.calculate_mass()
	vessel.update_flight_parallax()
	port.checkpoint_construction = FALSE
	SEND_SIGNAL(port, COMSIG_VOIDCREW_SHIP_LOADED)
	after_ship_loaded()
	// Registration linked the helms before a ship record existed. Fueled thrusters find their
	// heater lazily, and a thruster placed before its heater would otherwise report no fuel.
	for(var/area/room as anything in port.shuttle_areas)
		for(var/obj/machinery/computer/helm/helm in room)
			helm.attempt_ship_connection()
		for(var/obj/machinery/power/shuttle_engine/ship/fueled/thruster in room)
			thruster.set_heater()
	if(enlist_captain(captain?.mind || captain_mind()))
		if(held_balance > 0)
			vessel.ship_account.adjust_money(held_balance, "Recovered ship account")
			held_balance = 0
	else
		// Nobody holds the captain's key: the finished hull can be claimed at its helm, but
		// the old ship's money goes back to the captain rather than to whoever claims it.
		vessel.abandon_ship(crash = FALSE)
		return_held_balance(null)
	if(!bay.complete_rebuild(vessel, src))
		stack_trace("[build_noun] of [ship_name] could not hand its bay to the finished ship.")
		bay.finish_rebuild(src)
	state = CHECKPOINT_BUILD_COMPLETE
	SEND_SIGNAL(vessel, COMSIG_VOIDCREW_SHIP_DOCKED)
	home.refresh_elevator_uis()
	log_game("[captain ? key_name(captain) : captain_ckey] received [vessel.name], [finished_text()] at [home.name].")
	if(captain)
		to_chat(captain, span_notice("[vessel.name] is ready in Ship Bay [bay.bay_number]."))
	var/datum/ship_checkpoint_ui/panel = panel_ref?.resolve()
	if(panel)
		panel.notice = "[vessel.name] is ready."
		panel.error = null
	qdel(src)
	return TRUE

// ===== FAILURE AND TERMINATION =====

/**
 * Before the first piece: release everything and keep the checkpoint.
 * After it: remove what was placed and release the bay. The checkpoint stays consumed.
 */
/datum/checkpoint_construction/proc/abort(reason, delete_job = TRUE)
	if(state == CHECKPOINT_BUILD_COMPLETE || state == CHECKPOINT_BUILD_FAILED)
		return
	state = CHECKPOINT_BUILD_FAILED
	error = reason || "Construction failed. [unspent_note()]"
	STOP_PROCESSING(SSfastprocess, src)
	clear_site_effects()
	if(committed)
		remove_partial_hull()
		discard_source()
		release_source()
		log_game("[build_noun] of [ship_name] for [captain_ckey] was terminated after its first piece: [error]")
	else
		discard_source()
		release_source()
		log_game("[build_noun] of [ship_name] for [captain_ckey] stopped before its first piece: [error]")
	if(!QDELETED(bay))
		bay.finish_rebuild(src)
	report_failure()
	if(delete_job)
		qdel(src)

/// Discards whatever is still hidden; before the frame moves that is the whole copy.
/datum/checkpoint_construction/proc/discard_source()
	if(!frame_done && !QDELETED(port))
		var/obj/docking_port/mobile/voidcrew/discarded = port
		var/list/rooms = discarded.shuttle_areas?.Copy()
		UnregisterSignal(discarded, COMSIG_QDELETING)
		port = null
		discarded.jumpToNullSpace()
		for(var/area/room as anything in rooms)
			if(!QDELETED(room) && !room.has_contained_turfs())
				qdel(room)
	else
		clear_source_tiles()
	release_source_zone()

/// Gives the shipyard back once the hidden copy is done with; the zone's wipe clears what is left.
/datum/checkpoint_construction/proc/release_source_zone()
	var/datum/outpost_zone/yard = source_zone
	// A load in progress is still writing into the shipyard; load_source() lets it go on return.
	if(!yard || copy_loading)
		return
	source_zone = null
	if(yard.is_held_by(src))
		yard.release()

/**
 * Objects mapped around the hull but outside its rooms are what a landing leaves behind. A
 * saved checkpoint has none; a ship map can (signs on the outer face of a wall). Nobody can
 * reach them here, so shipyard orders delete them rather than leave them to the shipyard's wipe.
 */
/datum/checkpoint_construction/proc/clear_off_hull()
	var/list/turf/copy_ground = get_source_block()
	if(!length(copy_ground))
		return
	var/list/rooms = QDELETED(port) ? null : port.shuttle_areas
	var/list/hull_tiles = list()
	for(var/index in hull_indices)
		hull_tiles[source_turfs[index]] = TRUE
	for(var/turf/tile as anything in copy_ground)
		if(hull_tiles[tile] || rooms?[tile.loc])
			continue
		for(var/obj/thing in tile)
			if(thing != port && !istype(thing, /obj/docking_port))
				qdel(thing)

/// Used when the job is stopped during its own load, before it took the copy.
/datum/checkpoint_construction/proc/discard_copy(obj/docking_port/mobile/voidcrew/loaded_port)
	if(!QDELETED(loaded_port))
		var/list/rooms = loaded_port.shuttle_areas?.Copy()
		loaded_port.jumpToNullSpace()
		for(var/area/room as anything in rooms)
			if(!QDELETED(room) && !room.has_contained_turfs())
				qdel(room)
	release_source_zone()

/**
 * Loads a shuttle template with its bottom-left corner on `bottom_left`: what
 * SSshuttle.load_template_impl() does for a preview, on ground the caller already holds instead
 * of a new turf reservation. Run it while holding SSshuttle's template load. Returns the
 * template's one mobile port, registered only when `register` is set, or null; the loaded turfs
 * are then the caller's to clear.
 */
/proc/load_shuttle_template_at(datum/map_template/shuttle/loading_template, turf/bottom_left, register = FALSE)
	if(!bottom_left || !loading_template)
		return null
	// No try/catch round the load: it would swallow a partial stamp and leave a dead map.
	loading_template.load(bottom_left, centered = FALSE, register = register)
	var/obj/docking_port/mobile/found_port
	for(var/turf/tile as anything in loading_template.get_affected_turfs(bottom_left, centered = FALSE))
		for(var/obj/docking_port/port in tile)
			if(istype(port, /obj/docking_port/mobile))
				if(found_port)
					log_mapping("Shuttle template [loading_template.mappath] has multiple mobile docking ports.")
					qdel(port, force = TRUE)
				else
					found_port = port
			else if(istype(port, /obj/docking_port/stationary))
				log_mapping("Shuttle template [loading_template.mappath] has a stationary docking port.")
	if(!found_port)
		log_mapping("Shuttle template [loading_template.mappath] loaded without a mobile docking port.")
		return null
	loading_template.post_load(found_port)
	return found_port

/// Hands the hidden source tiles back from the ship's rooms once the port has left them.
/// Releasing the shipyard then empties and resets them over later ticks.
/datum/checkpoint_construction/proc/clear_source_tiles()
	if(!source_turfs)
		return
	var/area/fallback = GLOB.areas_by_type[SHUTTLE_DEFAULT_UNDERLYING_AREA] || new SHUTTLE_DEFAULT_UNDERLYING_AREA(null)
	var/list/rooms = list()
	for(var/index in hull_indices)
		var/turf/source = source_turfs[index]
		if(!source || !istype(source.loc, /area/shuttle))
			continue
		evacuate(source)
		rooms |= source.loc
		source.change_area(source.loc, fallback)
	for(var/area/room as anything in rooms)
		if(!room.has_contained_turfs() && (QDELETED(port) || !port.shuttle_areas?[room]))
			qdel(room)

/// Removes placed pieces from a bay that is being released or deleted. Works from this
/// job's own records, so it still cleans up after the port has been deleted elsewhere.
/datum/checkpoint_construction/proc/remove_partial_hull()
	var/list/rooms = list()
	for(var/turf/target as anything in placed_hull_tiles)
		evacuate(target)
	for(var/datum/checkpoint_visit/visit as anything in completed_visits)
		remove_visit_pieces(visit)
	for(var/turf/target as anything in placed_hull_tiles)
		var/area/underlying = placed_hull_tiles[target]
		var/area/room = target.loc
		if(room != underlying && !QDELETED(underlying))
			rooms |= room
			target.change_area(room, underlying)
		if(!QDELETED(port))
			port.underlying_areas_by_turf -= target
		var/depth = target.depth_to_find_baseturf(/turf/baseturf_skipover/shuttle)
		if(!isnull(depth))
			target.ScrapeAway(depth)
	placed_hull_tiles.Cut()
	if(frame_done && !QDELETED(port))
		var/obj/docking_port/mobile/voidcrew/removed = port
		UnregisterSignal(removed, COMSIG_QDELETING)
		port = null
		qdel(removed, force = TRUE)
	for(var/area/room as anything in rooms)
		if(istype(room, /area/shuttle) && !room.has_contained_turfs())
			qdel(room)

/datum/checkpoint_construction/proc/remove_visit_pieces(datum/checkpoint_visit/visit)
	var/turf/target = bay_turfs[visit.index]
	for(var/datum/weakref/piece_ref as anything in visit.pieces)
		var/atom/movable/piece = piece_ref?.resolve()
		// Only what this job placed and is still standing where it was put.
		if(piece && get_turf(piece) == target)
			qdel(piece)

/// Moves living occupants off a tile before it is emptied, as bay teardown does.
/datum/checkpoint_construction/proc/evacuate(turf/location)
	var/list/turf/refuge = home?.get_floor_alcove(0) || bay?.alcove_turfs
	if(!length(refuge))
		return
	for(var/atom/movable/occupant as anything in location.contents.Copy())
		if(ismob(occupant))
			if(!isobserver(occupant))
				occupant.forceMove(pick(refuge))
			continue
		if(!length(occupant.contents) || !(locate(/mob/living) in occupant.get_all_contents()))
			continue
		if(!occupant.anchored)
			occupant.forceMove(pick(refuge))
			continue
		for(var/mob/living/rider in occupant.get_all_contents())
			rider.forceMove(pick(refuge))

/// Funds taken at commitment follow the old hull back, or its captain when it is gone.
/datum/checkpoint_construction/proc/return_held_balance(obj/structure/overmap/ship/original)
	if(held_balance <= 0)
		return
	var/datum/bank_account/account = original?.ship_account
	if(QDELETED(account))
		account = captain_account_ref?.resolve()
	if(QDELETED(account))
		var/mob/living/captain = get_mob_by_ckey(captain_ckey)
		account = istype(captain) ? captain.get_bank_account() : null
	if(account)
		account.adjust_money(held_balance, "Checkpoint recovery refund")
	else
		log_game("Checkpoint reconstruction of [ship_name] could not return [held_balance] credits: no account remains.")
	held_balance = 0

/datum/checkpoint_construction/proc/on_port_deleted(datum/source)
	SIGNAL_HANDLER
	if(source != port)
		return
	port = null
	if(state == CHECKPOINT_BUILD_COMPLETE || state == CHECKPOINT_BUILD_FAILED)
		return
	INVOKE_ASYNC(src, PROC_REF(abort), "The rebuilt hull was removed.")

// ===== STATUS =====

/datum/checkpoint_construction/proc/stage_name()
	switch(stage)
		if(CHECKPOINT_STAGE_DECK)
			return "Deck"
		if(CHECKPOINT_STAGE_HULL)
			return "Hull"
		if(CHECKPOINT_STAGE_SYSTEMS)
			return "Systems"
		if(CHECKPOINT_STAGE_MACHINERY)
			return "Machinery"
		if(CHECKPOINT_STAGE_FITTINGS)
			return "Fittings"
	return "Commissioning"

/datum/checkpoint_construction/proc/progress_percent()
	if(!visit_total)
		return 0
	return round(100 * visits_done / visit_total)

/datum/checkpoint_construction/proc/status_line()
	switch(state)
		if(CHECKPOINT_BUILD_PREPARING)
			return queued ? "Waiting for the shipyard" : "Preparing"
		if(CHECKPOINT_BUILD_MARKING)
			return "Marking construction area"
		if(CHECKPOINT_BUILD_BUILDING)
			return "Stage [min(stage, CHECKPOINT_STAGE_COUNT)]/[CHECKPOINT_STAGE_COUNT]: [stage_name()]"
		if(CHECKPOINT_BUILD_COMMISSIONING)
			return "Commissioning"
		if(CHECKPOINT_BUILD_COMPLETE)
			return "Complete"
	return error || "Stopped"

/// Short enough for the bay signs and elevator.
/datum/checkpoint_construction/proc/bay_status()
	if(state == CHECKPOINT_BUILD_BUILDING)
		return "[status_verb] [progress_percent()]%"
	if(state == CHECKPOINT_BUILD_COMMISSIONING)
		return "Commissioning"
	if(state == CHECKPOINT_BUILD_PREPARING && queued)
		return "Queued"
	return status_verb

/datum/checkpoint_construction/proc/rebuild_ui_data()
	return list(
		"ref" = REF(src),
		"name" = ship_name,
		"status" = status_line(),
		"progress" = state == CHECKPOINT_BUILD_COMMISSIONING ? 100 : progress_percent(),
	)

/datum/checkpoint_construction/proc/report_progress()
	var/percent = progress_percent()
	if(percent - last_reported_percent < 5 && percent < 100)
		return
	last_reported_percent = percent
	update_bay_status()

/datum/checkpoint_construction/proc/update_bay_status()
	if(!QDELETED(bay))
		bay.update_status()

/datum/checkpoint_construction/proc/report_failure()
	var/datum/ship_checkpoint_ui/panel = panel_ref?.resolve()
	if(panel)
		panel.error = error
		panel.notice = null
	var/mob/living/captain = get_mob_by_ckey(captain_ckey)
	if(istype(captain) && state == CHECKPOINT_BUILD_FAILED)
		to_chat(captain, span_warning("[build_noun] of [ship_name] stopped: [error]"))

/datum/checkpoint_construction/proc/clear_marker(turf/target)
	var/obj/effect/checkpoint_build_marker/marker = markers[target]
	markers -= target
	if(marker)
		qdel(marker)

/// Removes the markers and lets the drones go. They fly back to their drone bays on their
/// own, unless the bay itself is going away.
/datum/checkpoint_construction/proc/clear_site_effects()
	for(var/turf/marked as anything in markers)
		qdel(markers[marked])
	markers.Cut()
	var/site_remains = !QDELETED(bay) && !QDELETED(home)
	var/datum/checkpoint_drone_flock/flock = site_remains && length(drones) ? new(bay) : null
	for(var/obj/effect/checkpoint_build_drone/drone as anything in drones)
		if(drone?.visit)
			drone.visit.drone = null
			drone.visit = null
		if(QDELETED(drone))
			continue
		if(site_remains)
			drone.return_home(flock)
		else
			qdel(drone)
	drones.Cut()

/obj/docking_port/mobile/voidcrew
	/// Set while a staged rebuild owns this port and its ship record does not exist yet.
	var/checkpoint_construction = FALSE

/// Keeps the landing census the next departure's pre-move audit reads.
/obj/docking_port/mobile/voidcrew/proc/record_checkpoint_hull_turf(turf/landed)
	LAZYSET(carried_hull_types, landed, landed.type)
