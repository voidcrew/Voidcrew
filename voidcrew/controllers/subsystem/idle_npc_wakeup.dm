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
	// empty z-levels in a separate AI_Z_OFF list; we re-check the z-level per mob instead,
	// and that check is cheap enough (a get_turf and a list length) to run this often.
	wait = 2 SECONDS
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/list/currentrun = list()

/datum/controller/subsystem/idlenpcpool/stat_entry(msg)
	msg = "IdleNPCS:[length(GLOB.simple_animals[AI_IDLE])]"
	return ..()

/datum/controller/subsystem/idlenpcpool/fire(resumed = FALSE)
	if(!resumed)
		var/list/idle_list = GLOB.simple_animals[AI_IDLE]
		src.currentrun = idle_list.Copy()

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

	// Dynamically created z-levels (planets, encounters) can outrun SSmobs' resize.
	if(our_turf.z > length(SSmobs.clients_by_zlevel))
		return

	// Nobody on this z-level can be attacked by us, so there is nothing to wake up for.
	// This is what keeps unvisited planets and ruins free.
	var/list/players_here = SSmobs.clients_by_zlevel[our_turf.z]
	if(!length(players_here))
		return

	// Cheap distance pre-filter so we only pay for a real target search when someone is
	// plausibly close. Floored at MAX_SIMPLEMOB_WAKEUP_RANGE because mining-type mobs have
	// a vision_range of 2 and we want the search itself, not this filter, to make the call.
	var/wake_range = max(vision_range, MAX_SIMPLEMOB_WAKEUP_RANGE)
	var/someone_close = FALSE
	for(var/mob/player as anything in players_here)
		if(get_dist(src, player) <= wake_range)
			someone_close = TRUE
			break
	if(!someone_close)
		return

	if(FindTarget())
		toggle_ai(AI_ON)
