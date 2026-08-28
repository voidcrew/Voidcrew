SUBSYSTEM_DEF(icon_smooth)
	name = "Icon Smoothing"
	dependencies = list(
		/datum/controller/subsystem/atoms,
	)
	wait = 1
	priority = FIRE_PRIORITY_SMOOTHING
	ss_flags = SS_TICKER

	///Blueprints assemble an image of what pipes/manifolds/wires look like on initialization, and thus should be taken after everything's been smoothed
	var/list/blueprint_queue = list()
	var/list/smooth_queue = list()
	var/list/deferred = list()
	var/list/deferred_by_source = list()
	/// Atoms that have asked us to stay quiet while they load a run of overlapping maps.
	/// See hold_smoothing(); anything in here blocks fire() outright.
	var/list/smoothing_holds = list()

/datum/controller/subsystem/icon_smooth/fire()
	// We do not want to smooth icons of atoms whose neighbors are not initialized yet,
	// this causes runtimes.
	// Icon smoothing SS runs after atoms, so this only happens for something like shuttles.
	// This kind of map loading shouldn't take too long, so the delay is not a problem.
	if (SSatoms.initializing_something())
		return

	// initializing_something() cannot see a load that is *between* ticks: both
	// MAPLOADING_CHECK_TICK (code/modules/mapping/reader.dm) and CreateAtoms() pop their
	// SSatoms source immediately before they stoplag() and push it back afterwards, so at the
	// exact moment the MC gets to run us the depth reads as zero. That is harmless for a single
	// map, because everything it queues is parked in deferred_by_source until it finishes - but
	// not for a run of maps loaded back-to-back into the same tiles, where map N's turfs have
	// already been released into smooth_queue while map N+1 is still laying down its own
	// half-built, unparsed neighbours. Loaders in that position take a hold instead.
	if (length(smoothing_holds))
		// Self-healing: a holder that got deleted without releasing (a runtime out of its load
		// proc) must not silence smoothing for the rest of the round.
		for (var/datum/holder as anything in smoothing_holds)
			if (QDELETED(holder))
				smoothing_holds -= holder
		if (length(smoothing_holds))
			return

	var/list/smooth_queue_cache = smooth_queue
	while(length(smooth_queue_cache))
		var/atom/smoothing_atom = smooth_queue_cache[length(smooth_queue_cache)]
		smooth_queue_cache.len--
		if(QDELETED(smoothing_atom) || !(smoothing_atom.smoothing_flags & SMOOTH_QUEUED))
			continue
		if(smoothing_atom.flags_1 & INITIALIZED_1)
			smoothing_atom.smooth_icon()
		else
			deferred += smoothing_atom
		if (MC_TICK_CHECK)
			return

	if (!length(smooth_queue_cache))
		if (deferred.len)
			smooth_queue = deferred
			deferred = smooth_queue_cache
		else
			can_fire = FALSE

/datum/controller/subsystem/icon_smooth/Initialize()
	var/list/queue = smooth_queue
	smooth_queue = list()

	while(length(queue))
		var/atom/smoothing_atom = queue[length(queue)]
		queue.len--
		if(QDELETED(smoothing_atom) || !(smoothing_atom.smoothing_flags & SMOOTH_QUEUED) || !smoothing_atom.z)
			continue
		smoothing_atom.smooth_icon()
		CHECK_TICK

	queue = blueprint_queue
	blueprint_queue = null

	for(var/atom/movable/movable_item as anything in queue)
		if(!isturf(movable_item.loc))
			continue
		var/turf/item_loc = movable_item.loc
		item_loc.add_blueprints(movable_item)

	return SS_INIT_SUCCESS

/**
 * Stop smoothing anything at all until every holder has released.
 *
 * For loaders that lay down several maps back-to-back into the same tiles. The per-source
 * deferral above only protects one map at a time: the moment map N's InitializeAtoms() finishes,
 * free_deferred() releases its turfs into smooth_queue, and if map N+1 is already being parsed
 * those turfs will smooth against its half-built neighbours - whose smoothing_groups are still
 * the raw comma-string SETUP_SMOOTHING() has not parsed yet, which is a "bad index" runtime in
 * SMOOTH_AGAINST() and leaves the tile stuck on its "-0" icon state for the rest of the round.
 *
 * `holder` is only ever compared by identity, and fire() drops holders that get deleted without
 * releasing, so a runtime out of a load proc costs a late smooth rather than a dead subsystem.
 */
/datum/controller/subsystem/icon_smooth/proc/hold_smoothing(datum/holder)
	smoothing_holds |= holder

/// Releases a hold taken by hold_smoothing(). Safe to call when no hold is held.
/datum/controller/subsystem/icon_smooth/proc/release_smoothing(datum/holder)
	smoothing_holds -= holder
	if(!can_fire && length(smooth_queue))
		can_fire = TRUE

/// Releases a pool of delayed smooth attempts from a particular source
/datum/controller/subsystem/icon_smooth/proc/free_deferred(source_to_free)
	smooth_queue += deferred_by_source[source_to_free]
	deferred_by_source -= source_to_free
	if(!can_fire)
		can_fire = TRUE

/datum/controller/subsystem/icon_smooth/proc/add_to_queue(atom/thing)
	if(thing.smoothing_flags & SMOOTH_QUEUED)
		return
	thing.smoothing_flags |= SMOOTH_QUEUED
	// If we're currently locked into mapload BY something
	// Then put us in a deferred list that we release when this mapload run is finished
	if(initialized && length(SSatoms.initialized_state) && SSatoms.initialized == INITIALIZATION_INNEW_MAPLOAD)
		var/source = SSatoms.get_initialized_source()
		LAZYADD(deferred_by_source[source], thing)
		return
	smooth_queue += thing
	if(!can_fire)
		can_fire = TRUE

/datum/controller/subsystem/icon_smooth/proc/remove_from_queues(atom/thing)
	// Lack of removal from deferred_by_source is safe because the lack of SMOOTH_QUEUED will just free it anyway
	// Hopefully this'll never cause a harddel (dies)
	thing.smoothing_flags &= ~SMOOTH_QUEUED
	smooth_queue -= thing
	if(blueprint_queue)
		blueprint_queue -= thing
	deferred -= thing
