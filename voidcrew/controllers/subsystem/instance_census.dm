/// Periodically walks the world and logs per-type instance counts, so that
/// memory growth between two points in a round can be attributed to specific
/// types instead of guessed at. Written for the 2026-08 OOM investigation:
/// 32-bit DreamDaemon hits its ~4 GB address ceiling 2-3 hours into populated
/// rounds, and nothing on the server recorded what was actually growing.
///
/// Output: one JSON object per line (NDJSON) appended to
/// [log_directory]/instance_census.ndjson. Diff two snapshots with
/// tools/instance_census/census_diff.py to rank types by growth.
SUBSYSTEM_DEF(instance_census)
	name = "Instance Census"
	wait = 30 MINUTES
	flags = SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT

	/// Monotonic snapshot counter for this round.
	var/census_number = 0
	/// TRUE while a walk is in progress - fires that land mid-walk are skipped.
	var/walk_in_progress = FALSE
	/// Set TRUE (VV or proccall) to make the next snapshot also enumerate every
	/// datum. The datum pass cannot yield, so it blocks the world for a few
	/// seconds on a mature round - the baseline snapshot does it once while the
	/// world is still small and calm.
	var/include_datums_next_fire = FALSE

/datum/controller/subsystem/instance_census/Initialize()
	INVOKE_ASYNC(src, PROC_REF(take_baseline_census))
	return SS_INIT_SUCCESS

/// Baseline snapshot shortly after init: the number the round-9 memory
/// investigation was missing. Includes the blocking datum pass while it is
/// still cheap. Not an addtimer: timers that come due while the MC is still
/// initializing are silently dropped, and a slow init could eat the baseline
/// that way.
/datum/controller/subsystem/instance_census/proc/take_baseline_census()
	UNTIL(SSticker.current_state >= GAME_STATE_PREGAME)
	sleep(3 MINUTES)
	take_census(include_datums = TRUE)

/datum/controller/subsystem/instance_census/fire()
	if(walk_in_progress)
		return
	INVOKE_ASYNC(src, PROC_REF(take_census), include_datums_next_fire)
	include_datums_next_fire = FALSE

/datum/controller/subsystem/instance_census/proc/take_census(include_datums = FALSE)
	if(walk_in_progress)
		return
	walk_in_progress = TRUE
	census_number++
	var/start_realtime = REALTIMEOFDAY

	var/list/type_counts = list()
	var/list/movables_by_z = list()
	var/atoms_total = 0
	for(var/atom/thing in world)
		atoms_total++
		type_counts[thing.type]++
		if(ismovable(thing))
			movables_by_z["[thing.z]"]++ // z 0 = contained in something, or in nullspace
		CHECK_TICK

	var/list/entry = list(
		"census" = census_number,
		"world_time" = world.time,
		"realtime" = time_stamp(),
		"atom_walk_seconds" = (REALTIMEOFDAY - start_realtime) * 0.1,
		"atoms_total" = atoms_total,
		"maxz" = world.maxz,
		"clients" = length(GLOB.clients),
		"map_zones" = length(SSovermap.map_zones),
		"simulated_ships" = length(SSovermap.simulated_ships),
		"movables_by_z" = movables_by_z,
		"types" = type_counts,
	)

	if(include_datums)
		var/datum_walk_start = REALTIMEOFDAY
		// Reuses the admin verb's helper. Unlike the world iteration above, the
		// bare all-datums iterator's tolerance of create/delete while yielded is
		// unknown, so this pass runs without CHECK_TICK and blocks; that is why
		// it is opt-in rather than part of every snapshot.
		var/list/datum_counts = count_datums()
		entry["datums_total"] = counts_total(datum_counts)
		entry["datum_walk_seconds"] = (REALTIMEOFDAY - datum_walk_start) * 0.1
		entry["datum_types"] = datum_counts

	rustg_file_append(json_encode(entry) + "\n", "[GLOB.log_directory]/instance_census.ndjson")
	log_world("Instance census #[census_number]: [atoms_total] atoms across [length(type_counts)] types, maxz [world.maxz], [length(SSovermap.map_zones)] map zones, walk took [(REALTIMEOFDAY - start_realtime) * 0.1]s")
	walk_in_progress = FALSE

/datum/controller/subsystem/instance_census/proc/counts_total(list/counts)
	. = 0
	for(var/key in counts)
		. += counts[key]
