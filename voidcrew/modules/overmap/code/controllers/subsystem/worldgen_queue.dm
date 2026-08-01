/**
 * # Worldgen queue
 *
 * A global, FIFO, reentrant lock around **planet terrain builds and planet teardowns**,
 * and nothing else.
 *
 * A planet lays down, populates, ruins and cordons ~16k turfs of generated terrain; a
 * teardown qdels every atom standing on them in a sweep that deliberately never yields
 * (see /datum/space_level/clear_reservation). Two of those at once will not deadlock -
 * they interleave, which is worse. Both take proportionally longer, the tick budget
 * stays pinned for the sum of their runtimes instead of each in turn, and every player
 * on every ship feels it. So: one at a time, in the order people asked.
 *
 * ## What is deliberately NOT queued
 *
 * Ruin reservations, meteor fields, empty space, player and trader outposts, the
 * colosseum. They stamp a template into a reservation or fill a flat level - real work,
 * but nothing like a terrain build, and every one of them is on a path where a wait
 * would be worse than the lag it avoids. Empty space is the clearest case: it is stood
 * up for routine ship-to-ship and cargo docking, and making that queue behind somebody
 * else's planet would break ordinary docking to fix a stutter nobody reported.
 *
 * Nor are they *throttled* while a planet happens to be building: their loops pass
 * throttled = FALSE to worldgen_yield() and run at plain CHECK_TICK speed. Design rule:
 * a survey may never slow a ruin or empty-space dock, in any amount. The cost is that
 * generation work briefly stacks when an encounter loads mid-survey; the queue's budget
 * only ever governed the queued job itself.
 *
 * ## The mapzone race is fixed at the source, not here
 *
 * find_free_mapzone() is a check-then-act over a global list, and its claim
 * (mapzone.taken = TRUE) used to land only after add_new_zlevel() had had a chance to
 * sleep on its own spinlock - so two encounters could be handed the same map zone and
 * later wipe each other's live surface. Both call sites (build_planet() and
 * spawn_dynamic_encounter()) now claim the zone before anything can yield, which is the
 * actual fix. Do not reintroduce the gap on the assumption that this queue covers it:
 * it only ever covered the planet half.
 *
 * ## Using it
 *
 * This is a lock, not a job runner - the caller still executes its own work:
 *
 *   if(!SSovermap.worldgen_claim(src, "planet build ([name])", user))
 *       return "..."                      // queue gave up; abort cleanly
 *   ...expensive work...
 *   SSovermap.worldgen_release(src)
 *
 * Two rules:
 *
 * 1. Every path out of the critical section must release. There is no finally block in
 *    DM, so early returns need an explicit release on the way out.
 * 2. Re-check your preconditions *after* the claim returns. Claiming can sleep for
 *    minutes, and the world moves while you are in line - a ship may have docked, or
 *    another caller may have already built what you were about to build.
 *
 * A job that dies without releasing is caught by the watchdog in SSovermap.fire(), which
 * force-releases the queue and calls on_worldgen_timeout() on the owner so it can unstick
 * its own state rather than sitting bricked for the rest of the round.
 *
 * Claims are reentrant by owner and refcounted, so a subtype that claims and then calls a
 * parent proc which claims again gets one lock and one wait rather than a deadlock. None
 * of the current call sites nest, but the load paths override each other freely enough
 * that one eventually will.
 */

/// How long a caller waits in line before giving up and telling the player to retry.
#define WORLDGEN_QUEUE_TIMEOUT (4 MINUTES)
/// How long one job may hold the queue before the watchdog assumes it died mid-build.
#define WORLDGEN_JOB_TIMEOUT (5 MINUTES)
/// Poll interval for waiters. Scaled by server load, like every other stoplag caller.
#define WORLDGEN_QUEUE_POLL 5
/// How often a waiting player is reminded where it stands, in deciseconds.
#define WORLDGEN_QUEUE_UPDATE_INTERVAL (30 SECONDS)

/**
 * Share of a single tick a worldgen job may burn before it hands the rest back.
 *
 * This is the whole lever on generation lag. CHECK_TICK yields at
 * Master.current_ticklimit, and TICK_LIMIT_RUNNING floors that at 70 - so a build
 * calling it on every turf is still entitled to seventy-odd percent of every tick for
 * as long as it runs. It yields constantly and the server is still on its knees, which
 * is why "one planet loading" reads as a freeze rather than as a slowdown.
 *
 * Lowering this makes builds take proportionally longer in wall-clock and leaves
 * correspondingly more of each tick for everyone not currently landing on a planet.
 * At 25 a build runs roughly a third of the speed it used to and costs about a quarter
 * of the server instead of three quarters. Raise it if landings feel too slow, lower it
 * if the rest of the round still stutters through them.
 */
#define WORLDGEN_TICK_BUDGET 25

/datum/controller/subsystem/overmap
	/// The overmap object currently allowed to build or tear down its interior.
	var/obj/structure/overmap/worldgen_owner
	/// Reentrancy depth of worldgen_owner's claim. The queue frees at zero.
	var/worldgen_depth = 0
	/// world.time the active claim was granted, for the watchdog.
	var/worldgen_claimed_at = 0
	/// What the active claim said it was doing. Logs and the MC stat panel.
	var/worldgen_label
	/// FIFO of ticket numbers waiting their turn. Position 1 goes next.
	var/list/worldgen_tickets = list()
	/// Monotonic ticket counter, so waiters are served in the order they arrived.
	var/worldgen_next_ticket = 1
	/// Jobs completed since roundstart, for the stat line.
	var/worldgen_jobs_run = 0
	/// TICK_USAGE at which the running job must give the rest of the tick back.
	var/worldgen_slice_limit = 0
	/// Whether the running job is being throttled at all. Set per claim.
	var/worldgen_throttled = FALSE

/**
 * Takes the worldgen queue, sleeping until it is this caller's turn.
 *
 * Returns TRUE once the caller holds the queue and may begin - it must then call
 * worldgen_release() on every exit path. Returns FALSE if the wait timed out or the
 * requester was deleted while queued, in which case nothing was claimed and the caller
 * should abort.
 *
 * Arguments:
 * * requester - the overmap object whose interior is being built or torn down. Doubles
 *   as the reentrancy key, so nested claims from the same object are free.
 * * label - short description of the job, for logs and the stat panel.
 * * waiter - optional mob to tell about its place in line, once, if it has to wait.
 * * timeout - how long to stay in line before giving up. Null takes the default;
 *   WORLDGEN_QUEUE_NO_WAIT means take the queue only if it is free this instant,
 *   which is what UI paths want rather than holding an interface open for minutes.
 */
/datum/controller/subsystem/overmap/proc/worldgen_claim(obj/structure/overmap/requester, label, mob/waiter, timeout)
	if(QDELETED(requester))
		return FALSE

	// Written out rather than left as an argument default: callers thread this down
	// through their own optional parameters, and an explicit null passed into a
	// defaulted argument stays null in DM.
	if(isnull(timeout))
		timeout = WORLDGEN_QUEUE_TIMEOUT

	// Already ours - a claim nested inside a claim, e.g. an overridden load_level()
	// that claims and then calls parent. Refcount it and let it through.
	if(worldgen_owner == requester)
		worldgen_depth++
		return TRUE

	var/ticket = worldgen_next_ticket++
	worldgen_tickets += ticket
	var/deadline = world.time + timeout
	var/warned_waiter = FALSE
	var/next_waiter_update = 0

	// Being at the head of the queue with nobody holding it is the only way through.
	// Nothing sleeps between that test failing and the assignment below, so the grant
	// is atomic even though every waiter is polling the same two variables.
	while(worldgen_owner || worldgen_tickets[1] != ticket)
		// Tested inclusively so WORLDGEN_QUEUE_NO_WAIT gives up here on the first pass
		// instead of sleeping once first.
		if(world.time >= deadline)
			worldgen_tickets -= ticket
			// A no-wait caller bailing is the system working, not an event; only a real
			// wait that ran out is worth a line in the log.
			if(timeout)
				log_mapping("SSovermap: worldgen queue timeout - '[label]' gave up after [timeout / 10]s waiting behind '[worldgen_label]'")
			return FALSE
		if(QDELETED(requester))
			worldgen_tickets -= ticket
			return FALSE
		// Repeated rather than said once: the hold can run for minutes with the helm
		// locked, and a single line at the start is indistinguishable from a hang.
		if(waiter && world.time >= next_waiter_update)
			next_waiter_update = world.time + WORLDGEN_QUEUE_UPDATE_INTERVAL
			var/ahead = worldgen_tickets.Find(ticket) - 1
			if(worldgen_owner)
				ahead++
			if(warned_waiter)
				to_chat(waiter, span_notice("Still holding. [ahead] survey operation[ahead == 1 ? "" : "s"] ahead of us."))
			else
				warned_waiter = TRUE
				to_chat(waiter, span_notice("Another survey is already underway in this sector. Holding position - [ahead] operation[ahead == 1 ? "" : "s"] ahead of us."))
		stoplag(WORLDGEN_QUEUE_POLL)

	worldgen_tickets -= ticket
	worldgen_owner = requester
	worldgen_depth = 1
	worldgen_claimed_at = world.time
	worldgen_label = label

	// Nothing is playing yet during the lobby prebuild, so there is no lag to spread and
	// throttling would only push back the round start that the prebuild is already
	// holding open. Decided per claim rather than per yield - it cannot change mid-job.
	worldgen_throttled = SSticker?.HasRoundStarted()
	worldgen_slice_limit = TICK_USAGE + WORLDGEN_TICK_BUDGET

	if(warned_waiter && waiter)
		to_chat(waiter, span_notice("The sector is clear. Beginning survey."))
	return TRUE

/**
 * Yield point for world generation loops, used instead of CHECK_TICK.
 *
 * CHECK_TICK asks "is the tick nearly full?", which lets a build keep taking whatever
 * is left of every tick until it finishes - it yields thousands of times and still
 * starves everything else, because seventy percent of every tick is a lot to lose for
 * twenty seconds straight. This asks a different question: "have I had my share of this
 * tick?" - and if so it sleeps out the remainder whether the tick is full or not.
 *
 * The accounting lives on the subsystem rather than in each loop, which is exact for
 * the planet build holding the queue.
 *
 * `throttled` says whether this loop belongs to (or is willing to wait behind) the
 * queued job. Unqueued encounter work - a ruin, empty space, an outpost - passes FALSE
 * and always gets plain CHECK_TICK: by design rule, a planetary build or survey may
 * never slow the loading of a ruin or empty space. Only the queued job's own loops
 * leave it TRUE and share the budget.
 *
 * Falls back to plain CHECK_TICK when no planet is building and before the round
 * starts, so an unqueued build on a quiet server is as fast as it ever was.
 */
/datum/controller/subsystem/overmap/proc/worldgen_yield(throttled = TRUE)
	if(!throttled || !worldgen_throttled || !worldgen_owner)
		CHECK_TICK
		return

	// Second clause covers the tick being full of somebody else's work before we even
	// got our slice - taking our share on top of that would blow the tick regardless.
	if(TICK_USAGE < worldgen_slice_limit && !TICK_CHECK)
		return

	sleep(world.tick_lag)
	worldgen_slice_limit = TICK_USAGE + WORLDGEN_TICK_BUDGET

/// Releases a claim taken by worldgen_claim(). Safe to call when the watchdog already
/// force-released underneath us; it will not steal the queue from whoever holds it now.
/datum/controller/subsystem/overmap/proc/worldgen_release(obj/structure/overmap/requester)
	if(worldgen_owner != requester)
		// A null owner means the watchdog already tore this claim down and said so
		// loudly. Anything else is a caller releasing a queue it never held.
		if(worldgen_owner)
			stack_trace("worldgen_release() by [requester?.type || "null"], which does not hold the queue (held by [worldgen_owner.type] for '[worldgen_label]')")
		return
	worldgen_depth--
	if(worldgen_depth > 0)
		return
	worldgen_jobs_run++
	worldgen_clear()

/// Drops the active claim without touching the waiting list. The next waiter's poll
/// picks the queue up on its own.
/datum/controller/subsystem/overmap/proc/worldgen_clear()
	worldgen_owner = null
	worldgen_depth = 0
	worldgen_claimed_at = 0
	worldgen_label = null
	worldgen_throttled = FALSE
	worldgen_slice_limit = 0

/**
 * Breaks a claim that is never going to be released.
 *
 * Two ways that happens: the job runtimed partway through (DM unwinds the proc without
 * running anything on the way out, so the release is simply skipped), or the object that
 * owned it was deleted mid-job. Either way the queue would otherwise be held forever and
 * every planet in the sector would stop loading.
 *
 * Force-releasing a job that is merely slow rather than dead lets a second job start
 * alongside it, which is exactly what this system exists to prevent - hence a timeout
 * generous enough that reaching it means something is genuinely wrong, and a loud
 * complaint when it happens.
 */
/datum/controller/subsystem/overmap/proc/worldgen_watchdog()
	if(!worldgen_owner)
		return

	if(QDELETED(worldgen_owner))
		log_mapping("SSovermap: worldgen queue was held by a deleted object ('[worldgen_label]') - releasing")
		worldgen_clear()
		return

	if(world.time - worldgen_claimed_at <= WORLDGEN_JOB_TIMEOUT)
		return

	var/obj/structure/overmap/stuck = worldgen_owner
	var/stuck_label = worldgen_label
	log_mapping("SSovermap: worldgen job '[stuck_label]' ([stuck.type]) held the queue for over [WORLDGEN_JOB_TIMEOUT / 600] minutes - force-releasing")
	message_admins("Worldgen queue: '[stuck_label]' ran over [WORLDGEN_JOB_TIMEOUT / 600] minutes and was force-released so other locations can load. That location may be in a broken state.")
	worldgen_clear()
	stuck.on_worldgen_timeout()

/// Number of jobs queued behind the running one. Zero when the queue is idle.
/datum/controller/subsystem/overmap/proc/worldgen_queue_length()
	return length(worldgen_tickets)

/datum/controller/subsystem/overmap/stat_entry(msg)
	if(worldgen_owner)
		msg = "Worldgen: [worldgen_label] ([(world.time - worldgen_claimed_at) / 10]s[worldgen_throttled ? ", throttled" : ""]) Q:[length(worldgen_tickets)]"
	else
		msg = "Worldgen: idle ([worldgen_jobs_run] run)"
	return ..()

/**
 * Called when the watchdog force-releases a job this object was holding, meaning its
 * build or teardown wedged partway through. Reset whatever would otherwise leave the
 * object permanently unusable - the in-progress flags that gate every entry point are
 * the usual culprits. Base: nothing to undo.
 */
/obj/structure/overmap/proc/on_worldgen_timeout()
	return

#undef WORLDGEN_QUEUE_TIMEOUT
#undef WORLDGEN_JOB_TIMEOUT
#undef WORLDGEN_QUEUE_POLL
#undef WORLDGEN_QUEUE_UPDATE_INTERVAL
#undef WORLDGEN_TICK_BUDGET
