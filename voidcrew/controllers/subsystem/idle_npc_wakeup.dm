/**
 * # Idling NPC Pool
 *
 * Wakes simple animals back out of AI_IDLE.
 *
 * SSnpcpool only ever iterates GLOB.simple_animals[AI_ON]. A hostile simple animal that
 * finds no target puts *itself* into AI_IDLE (see hostile/handle_automated_action), which
 * drops it out of that list - so the mob stops being ticked entirely and can no longer
 * notice anything. Upstream used to walk the idle list from SSidlenpcpool and call
 * consider_wakeup() on each mob, but tg #82469 deleted that subsystem when it moved
 * z-level sleeping onto basic mobs' AI controllers, and nothing was put back for simple
 * animals. Only damage escapes AI_IDLE after that (see simple_animal/damage_procs.dm).
 *
 * Upstream doesn't feel this because nearly all of their hostiles are basic mobs now. This
 * fork still maps simple animals - the wasteland hermits are all of them - and they load
 * with their ruin long before anyone lands, so every one of them went idle on its first
 * SSnpcpool tick and stood there forever.
 *
 * This restores the wakeup half only. Idle mobs deliberately do not get their wander tick
 * back: it was pure cost for mobs nobody can see, and planets can hold a lot of them.
 */
SUBSYSTEM_DEF(idlenpcpool)
	name = "Idling NPC Pool"
	ss_flags = SS_POST_FIRE_TIMING | SS_BACKGROUND | SS_NO_INIT
	priority = FIRE_PRIORITY_IDLE_NPC
	// Matches SSnpcpool, so an idle mob reacts to someone walking past it as fast as an
	// awake one would. Upstream could afford a 6-second scan because it parked mobs on
	// empty z-levels in a separate AI_Z_OFF list; we re-check the mob's own patch of the
	// world per mob instead, and that check is cheap enough (a get_turf, a list lookup and
	// at most one rectangle test per tenant) to run this often.
	wait = 2 SECONDS
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/list/currentrun = list()

	// Map packing puts up to four tenants on one z-level, which turns the per-mob "is
	// anyone on my z-level?" test into "is anyone on any of the four worlds sharing my
	// sky?" - and makes the distance loop underneath it quadratic in the packing factor
	// (four times the idle mobs each walking four crews' worth of clients). These three
	// partition the shared levels' clients by footprint once per run instead, so the per-mob
	// cost stays one rectangle test per tenant plus its own tenant's client list.
	//
	// Levels that are NOT shared appear in none of them: clients_near_turf() reads
	// SSmobs.clients_by_zlevel live for those, which is byte for byte the old behaviour and
	// costs nothing to keep.
	/// "[z]" -> the footprints registered on that z, for shared levels only.
	var/list/z_footprint_lists = list()
	/// /datum/map_footprint -> the client mobs standing inside it.
	var/list/footprint_client_pools = list()
	/// "[z]" -> client mobs on a shared level that no footprint on it claims.
	var/list/loose_client_pools = list()

/datum/controller/subsystem/idlenpcpool/stat_entry(msg)
	msg = "IdleNPCS:[length(GLOB.simple_animals[AI_IDLE])]"
	return ..()

/datum/controller/subsystem/idlenpcpool/fire(resumed = FALSE)
	if(!resumed)
		var/list/idle_list = GLOB.simple_animals[AI_IDLE]
		src.currentrun = idle_list.Copy()
		rebuild_client_pools()

	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun

	while(length(currentrun))
		var/mob/living/simple_animal/idler = currentrun[length(currentrun)]
		currentrun.len--

		if(QDELETED(idler))
			GLOB.simple_animals[AI_IDLE] -= idler
			continue

		if(!idler.ckey && idler.stat != DEAD)
			idler.consider_wakeup()

		if(MC_TICK_CHECK)
			return

/**
 * Partitions the clients on every SHARED z-level by which tenant's footprint they are
 * standing in. Run once at the top of each fire; a run that spans several ticks works off
 * the snapshot, which at a 2 second wait is as fresh as the old live read was in practice.
 *
 * Cheap by construction: it walks the z-levels that have clients at all, and for each one
 * that is shared it does at most one rectangle test per tenant per client. Unshared levels
 * are skipped entirely and keep reading SSmobs' own list.
 */
/datum/controller/subsystem/idlenpcpool/proc/rebuild_client_pools()
	z_footprint_lists = list()
	footprint_client_pools = list()
	loose_client_pools = list()

	var/list/clients_by_zlevel = SSmobs.clients_by_zlevel
	if(!islist(clients_by_zlevel))
		return
	var/list/z_list = SSmapping.z_list
	for(var/z_value in 1 to length(clients_by_zlevel))
		var/list/clients_here = clients_by_zlevel[z_value]
		if(!length(clients_here))
			continue
		if(z_value > length(z_list))
			continue
		var/datum/space_level/level = z_list[z_value]
		var/list/footprints = level?.footprints
		// One tenant (or none) means the level's clients are all "ours" whoever asks - the
		// pre-packing case, left out of the partition on purpose.
		if(length(footprints) < 2)
			continue

		var/z_key = "[z_value]"
		z_footprint_lists[z_key] = footprints
		var/list/unclaimed = list()
		for(var/mob/player as anything in clients_here)
			if(QDELETED(player))
				continue
			// get_turf() rather than the mob's own z: a player inside a locker, a mech or a
			// bodybag reads z 0 off the mob itself.
			var/turf/player_turf = get_turf(player)
			var/claimed = FALSE
			for(var/datum/map_footprint/footprint as anything in footprints)
				if(!footprint?.contains_turf(player_turf))
					continue
				var/list/pool = footprint_client_pools[footprint]
				if(!pool)
					pool = list()
					footprint_client_pools[footprint] = pool
				pool += player
				claimed = TRUE
				break
			if(!claimed)
				unclaimed += player
		loose_client_pools[z_key] = unclaimed

/**
 * The client mobs an idle NPC standing on `our_turf` could plausibly have business with.
 *
 * On an unshared level this is the z-level's client list, read live - unchanged behaviour,
 * and also what the unit test and any caller that pokes consider_wakeup() outside a fire
 * gets. On a shared level it is the list for the tenant whose footprint holds the turf.
 */
/datum/controller/subsystem/idlenpcpool/proc/clients_near_turf(turf/our_turf)
	if(!our_turf)
		return null
	var/z_value = our_turf.z
	// Dynamically created z-levels (planets, encounters) can outrun SSmobs' resize.
	if(z_value < 1 || z_value > length(SSmobs.clients_by_zlevel))
		return null
	var/z_key = "[z_value]"
	var/list/footprints = z_footprint_lists[z_key]
	if(!length(footprints))
		return SSmobs.clients_by_zlevel[z_value]
	for(var/datum/map_footprint/footprint as anything in footprints)
		if(footprint?.contains_turf(our_turf))
			return footprint_client_pools[footprint]
	// Between the tenants - the cordon band. Nothing lives there, but answer with the
	// clients nobody claimed rather than with the whole level.
	return loose_client_pools[z_key]

/**
 * Called on AI_IDLE simple animals by SSidlenpcpool.
 *
 * Anything that can go idle should override this and return itself to AI_ON when there is
 * once again a reason to be awake, otherwise it will sleep for the rest of the round.
 */
/mob/living/simple_animal/proc/consider_wakeup()
	return

/mob/living/simple_animal/hostile/consider_wakeup()
	if(AIStatus != AI_IDLE)
		return

	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return

	// Nobody we could attack is on our patch of the world, so there is nothing to wake up
	// for. This is what keeps unvisited planets and ruins free. Scoped to the map tenant
	// whose footprint holds us where a level is shared - a crew landing on the planet next
	// door across an indestructible cordon is not a reason for us to start thinking - and
	// to the whole z-level, exactly as before, where it is not.
	var/list/players_here = SSidlenpcpool.clients_near_turf(our_turf)
	if(!length(players_here))
		return

	// Cheap distance pre-filter so we only pay for a real target search when someone is
	// plausibly close. Floored at MAX_SIMPLEMOB_WAKEUP_RANGE because mining-type mobs have
	// a vision_range of 2 and we want the search itself, not this filter, to make the call.
	var/wake_range = max(vision_range, MAX_SIMPLEMOB_WAKEUP_RANGE)
	var/someone_close = FALSE
	for(var/mob/player as anything in players_here)
		// The pool is a snapshot taken at the top of the run; a hard delete nulls list
		// entries in place, so an `as anything` loop has to check.
		if(QDELETED(player))
			continue
		if(get_dist(src, player) <= wake_range)
			someone_close = TRUE
			break
	if(!someone_close)
		return

	if(FindTarget())
		toggle_ai(AI_ON)
