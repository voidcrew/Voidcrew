/**
 * # Outpost recovery: the state of an outpost after a massacre
 *
 * Owner: R2 (after R0's seams; spec-rehydrate.md sections 2 and 4). One /datum/outpost_recovery per trader
 * outpost (`outpost.recovery`, made by ensure_recovery() from the outpost's Initialize). It counts nothing by
 * scanning the map: deaths come in through note_death() (forwarded by the police's death hook), shops through
 * shop.is_open() (R1), stops through stop_dirty() (R4), bodies through the morgue crew's claims (R3).
 *
 * Frozen by R0: the datum's vars, the landmark types, link_rooms() and every proc name and signature below.
 * Replace the bodies; keep names, argument order and defaults. Procs owned by other packages live in their files:
 * body_free/next_body/claim_body/release_body in recovery_morgue.dm (R3), stop_dirty/mark_clean/clean_share in
 * recovery_janitor.dm (R4), staff_needed/send_staff in recovery_staff.dm (R2).
 *
 * R2 fills the state machine, the quiet clock, the crew waves and their ladder, the body cap and the corpse-sweep
 * switch (this file), and replacement staff and returning residents (recovery_staff.dm). Only the box of the
 * outpost (concourse, lobby, closets) counts; a death in a hangar or on a docked ship is left to the base sweep.
 * Nothing here runs while nobody is on the concourse. The ambient system freezes its people then (the crews with
 * them), and the recovery does not fake their work: its clocks stand still too and are moved on by as long as
 * they stood (shift_times(), on the first tick after someone comes), so every give-up timer (quiet, the 15 minute
 * cleanup, the crew grace, restaff, refill) counts only time the crews could actually work. With nobody at the
 * outpost at all (owner decision 32), the recovery finishes at once instead: recovery_offscreen.dm.
 */

/// The slow look that wakes a NORMAL outpost when a counter has lost its keeper without a death to say so
#define RECOVERY_WATCH_GAP (30 SECONDS)
/// RESTAFF gives up waiting for the last replacement after this long and lets the residents come anyway
#define RECOVERY_RESTAFF_MAX (10 MINUTES)
/// REFILL ends after this long even if a role cannot be filled
#define RECOVERY_REFILL_MAX (20 MINUTES)
/// A replacement keeper that has not reached the counter this long after arriving is put there, if nobody is watching
#define RECOVERY_POST_PATIENCE (2 MINUTES)
/// After the cleanup the crews get this long to put down what they carry, then they leave
#define RECOVERY_CREW_GRACE (2 MINUTES)
/// A back room (morgue, closet) bigger than this many tiles is a map without its door or wall
#define RECOVERY_ROOM_MAX 60
/// A wanted person off the outpost's own floor (aboard a docked ship, in a hangar) or not at the keys holds TROUBLE this long at most (abuse MF4)
#define RECOVERY_STARS_AWAY_MAX (3 MINUTES)
/// One medic comes with a wave for up to this many patients, two past it (decision 31, recovery_medic.dm)
#define RECOVERY_MEDIC_SECOND_AT 2

/obj/structure/overmap/trader_outpost
	/// This outpost's recovery (recovery_core.dm). Made by ensure_recovery(), deleted in Destroy().
	var/datum/outpost_recovery/recovery

/// Makes the recovery on first need (Initialize and the interior link both come here, as ensure_police()).
/obj/structure/overmap/trader_outpost/proc/ensure_recovery()
	if(!recovery)
		recovery = new /datum/outpost_recovery(src)
	return recovery

/datum/outpost_recovery
	/// The outpost it looks after
	var/obj/structure/overmap/trader_outpost/outpost
	/// OUTPOST_RECOVERY_*
	var/state = OUTPOST_RECOVERY_NORMAL
	/// world.time the state last changed
	var/state_since = 0
	/// world.time the outpost went quiet, or 0 while it is not
	var/quiet_since = 0
	/// world.time anyone with stars was last at the outpost (what the police can see of a shooting: an unseen shot
	/// gives no stars, so it only counts through last_death_at), and the last NPC death in its box
	var/last_shot_at = 0
	var/last_death_at = 0
	/// world.time the clock stopped because nobody was on the concourse, or 0 while players are there
	var/paused_at = 0
	/// Wanted people at the outpost but off its own floor or not at the keys: mind -> world.time first seen so (abuse MF4)
	var/list/stars_away = list()

	// ----- the dead (note_death(), R2) -----
	/// Weakrefs to NPC bodies at the outpost, oldest first
	var/list/datum/weakref/npc_dead = list()
	/// Weakrefs to bodies of minds that died here, until taken off the outpost or revived. Never deleted.
	var/list/datum/weakref/player_dead = list()

	// ----- the morgue crew (R3) -----
	/// Body weakref -> worker weakref: one worker per body (claim_body(), release_body())
	var/list/claims = list()
	/// Body weakref -> world.time it may be tried again (a body that was not free)
	var/list/retry_at = list()

	// ----- the janitors (R4) -----
	/// Patrol stop turfs found dirty, turf -> TRUE. A stop not in it counts as clean.
	var/list/dirty_stops = list()

	// ----- crews and waves (R2) -----
	/// Weakrefs to the living crew of the current wave (morgue and janitors) and its escort
	var/list/datum/weakref/crew = list()
	/// Crew waves lost in a row (4.2's ladder)
	var/waves_lost = 0
	/// world.time the next wave may be called
	var/next_wave_at = 0
	/// world.time the port opens again after OUTPOST_RECOVERY_LOST_SHUT waves lost, or 0
	var/port_shut_until = 0
	/// Waves called so far (a crew member's `wave`)
	var/wave_number = 0
	/// A wave is out: its crew is still to be built, or at work, and no other is called
	var/wave_active = FALSE
	/// world.time the current wave was called
	var/wave_called_at = 0
	/// Morgue workers, janitors and escort officers of the current wave not built yet
	var/wave_morgue_left = 0
	var/wave_janitors_left = 0
	var/wave_escort_left = 0
	/// How many escort officers the current wave asked for, and their POLICE_UNIT_* (wave_escort_left counts down as they are queued)
	var/wave_escort_size = 0
	var/wave_escort_kind = POLICE_UNIT_OFFICER
	/// Weakrefs to the current wave's workers (a subset of `crew`: no escort)
	var/list/datum/weakref/wave_workers = list()
	/// Weakrefs to the police waves that carry escorts (police wave datums)
	var/list/datum/weakref/escort_waves = list()
	/// REF of a worker already counted by crew_lost() -> TRUE
	var/list/lost_workers = list()
	/// world.time REFILL may bring the next arrival
	var/next_refill_at = 0
	/// world.time RESTAFF and REFILL began
	var/restaff_started_at = 0
	var/refill_started_at = 0
	/// The counters and desks that were ever kept: shop -> /datum/outpost_recovery_post (recovery_staff.dm)
	var/list/datum/outpost_recovery_post/posts = list()
	/// The slow watch (watch()), or null
	var/watch_timer

	// ----- losses (loss_room(), note_loss()) -----
	/// Credits paid out at this outpost this round by trader drops and stick-ups together
	var/losses = 0

	// ----- the rooms (link_rooms(), R0, real) -----
	/// The morgue room's floor, where its landmark was
	var/turf/morgue_turf
	/// The morgue room's trays
	var/list/obj/structure/bodycontainer/morgue/morgue_trays = list()
	/// The janitor closet's floor, where its landmark was
	var/turf/closet_turf
	/// The floor of the morgue room and the closet, up to their doors (turf = TRUE): nobody waits or idles in there
	var/list/back_rooms = list()

	/// The looping tick, or null while asleep (R2 decides when it runs)
	var/tick_timer

/datum/outpost_recovery/New(obj/structure/overmap/trader_outpost/new_outpost)
	. = ..()
	outpost = new_outpost
	state_since = world.time
	watch_timer = addtimer(CALLBACK(src, PROC_REF(watch)), RECOVERY_WATCH_GAP, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/datum/outpost_recovery/Destroy()
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	if(watch_timer)
		deltimer(watch_timer)
		watch_timer = null
	QDEL_LIST_ASSOC_VAL(posts)
	wave_workers.Cut()
	escort_waves.Cut()
	lost_workers.Cut()
	npc_dead.Cut()
	player_dead.Cut()
	stars_away.Cut()
	claims.Cut()
	retry_at.Cut()
	patient_claims.Cut()
	patient_retry.Cut()
	dirty_stops.Cut()
	crew.Cut()
	morgue_trays.Cut()
	morgue_turf = null
	closet_turf = null
	outpost = null
	return ..()

// =========================================================================
// THE ROOMS (R0, real; placed by R5)
// =========================================================================

/// The morgue room's floor (spec-rehydrate 5). Its trays are found within OUTPOST_RECOVERY_MORGUE_REACH. Consumed at link.
/obj/effect/landmark/outpost_morgue
	name = "outpost morgue"

/// The janitor closet's floor (spec-rehydrate 5). Consumed at link.
/obj/effect/landmark/outpost_janitor_closet
	name = "outpost janitor closet"

/**
 * The outpost's interior link hands over the recovery landmarks it found (outpost.dm, link_interior()). Records
 * the morgue room, its trays and the closet, then deletes the landmarks. One of each per outpost; a second is
 * ignored with a stack trace (a map error).
 */
/datum/outpost_recovery/proc/link_rooms(list/obj/effect/landmark/landmarks)
	for(var/obj/effect/landmark/mark as anything in landmarks)
		var/turf/where = get_turf(mark)
		if(istype(mark, /obj/effect/landmark/outpost_morgue))
			if(morgue_turf)
				stack_trace("[outpost] has a second morgue landmark at [AREACOORD(where)]")
			else
				morgue_turf = where
				for(var/obj/structure/bodycontainer/morgue/tray in range(OUTPOST_RECOVERY_MORGUE_REACH, where))
					morgue_trays += tray
		else if(istype(mark, /obj/effect/landmark/outpost_janitor_closet))
			if(closet_turf)
				stack_trace("[outpost] has a second janitor closet landmark at [AREACOORD(where)]")
			else
				closet_turf = where
		qdel(mark)
	for(var/turf/room as anything in list(morgue_turf, closet_turf))
		back_rooms |= room_floor(room)
	// Once the interior has finished loading (its spawners included), what lies about is the map's own
	addtimer(CALLBACK(src, PROC_REF(mark_decor)), 1 SECONDS, TIMER_DELETE_ME)

/**
 * The floor of the room `start` stands in: open tiles reached without passing a wall, a door, a window or a grille
 * (turf = TRUE). Read from the map's objects, so it works before the atoms initialise. A room bigger than
 * RECOVERY_ROOM_MAX is no back room (a missing door or wall on the map): empty, and a game log line (not
 * log_mapping(): a test floor with hand-placed landmarks is one open room).
 */
/datum/outpost_recovery/proc/room_floor(turf/start)
	. = list()
	if(!start)
		return
	var/list/floor = list()
	floor[start] = TRUE
	var/list/queue = list(start)
	while(length(queue))
		var/turf/tile = queue[length(queue)]
		queue.len--
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(tile, direction)
			if(!next || floor[next] || !room_step_open(tile, next, direction))
				continue
			floor[next] = TRUE
			queue += next
			if(length(floor) > RECOVERY_ROOM_MAX)
				log_game("OUTPOST RECOVERY: [outpost] has no closed room round [AREACOORD(start)]")
				return
	return floor

/// Whether a walk from `tile` to `next` (one step `direction`) stays in the room
/datum/outpost_recovery/proc/room_step_open(turf/tile, turf/next, direction)
	if(isclosedturf(next) || isspaceturf(next))
		return FALSE
	for(var/atom/thing as anything in next)
		if(istype(thing, /obj/machinery/door) || istype(thing, /obj/structure/grille) || istype(thing, /obj/effect/spawner/structure/window))
			return FALSE
		if(istype(thing, /obj/structure/window))
			var/obj/structure/window/pane = thing
			if(pane.fulltile || pane.dir == REVERSE_DIR(direction))
				return FALSE
	for(var/obj/structure/window/pane in tile)
		if(!pane.fulltile && pane.dir == direction)
			return FALSE
	return TRUE

/**
 * Marks the mess and litter the map placed (and its spawners made) as decor, so no crew ever washes or bags it:
 * TRAIT_AMBIENT_OUTPOST_DECOR (ambient_npcs/outpost_patrons.dm, written out: the define is not kept), read by
 * recovery_is_mess(), recovery_is_litter() and the ambient janitor. The whole interior, lobby and closets too.
 * Mess made after this is the crews' to clean.
 */
/datum/outpost_recovery/proc/mark_decor()
	if(QDELETED(outpost) || !outpost.template_bottom_left || !outpost.outpost_template?.width || !outpost.outpost_template?.height)
		return
	var/turf/bottom_left = outpost.template_bottom_left
	var/turf/top_right = locate(bottom_left.x + outpost.outpost_template.width - 1, bottom_left.y + outpost.outpost_template.height - 1, bottom_left.z)
	if(!top_right)
		return
	// The ambient janitor's own marking (ambient_outpost_mark_decor()) would come later and take fresh mess as decor
	var/list/notes = ambient_outpost_notes(outpost)
	notes["decor marked"] = TRUE
	for(var/turf/tile as anything in block(bottom_left, top_right))
		for(var/obj/effect/decal/cleanable/decal in tile)
			ADD_TRAIT(decal, "ambient_outpost_decor", "ambient_outpost")
		for(var/obj/item/thing in tile)
			if(recovery_is_litter(thing))
				ADD_TRAIT(thing, "ambient_outpost_decor", "ambient_outpost")

// =========================================================================
// STATE AND PACE (R2; spec-rehydrate.md 2 and 4)
// =========================================================================

/// Whether anyone is on the outpost's concourse. Its people hold still while nobody is (ambient system), and so does
/// this clock: a recovery that ran on with nobody there would finish before anyone came to see it.
/datum/outpost_recovery/proc/outpost_occupied()
	var/datum/ambient_place/outpost/place = recovery_place()
	return !!place?.occupied

/// The outpost's ambient place, or null before the ambient system has seen it
/datum/outpost_recovery/proc/recovery_place()
	return outpost ? SSambient_npcs.outposts[outpost] : null

/// Starts the one-second tick if it is not running. Safe from signal handlers: it never sleeps.
/datum/outpost_recovery/proc/wake()
	if(tick_timer || QDELETED(src))
		return
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), 1 SECONDS, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/// Stops the tick (TIMER_DELETE_ME: this may run from the timer's own callback)
/datum/outpost_recovery/proc/sleep_tick()
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null

/// The state changes. NORMAL puts the tick to sleep; every other state wakes it.
/datum/outpost_recovery/proc/set_state(new_state)
	if(state == new_state)
		return
	state = new_state
	state_since = world.time
	if(new_state == OUTPOST_RECOVERY_NORMAL)
		finish_recovery()
		sleep_tick()
	else
		wake()

/// A death or a vanished keeper opens the books: TROUBLE from NORMAL, and from any later state a new incident restarts the quiet
/datum/outpost_recovery/proc/begin_trouble()
	// While the keepers' bodies are still there: the counters a replacement will have to fill
	register_posts()
	quiet_since = 0
	set_state(OUTPOST_RECOVERY_TROUBLE)
	wake()

/**
 * Whether anyone with stars is at the outpost and up: a dead holder's stars fade within seconds (police_wanted.dm).
 * One sitting aboard their docked ship or in a hangar, or logged off, holds it for RECOVERY_STARS_AWAY_MAX at most,
 * so a wanted crew shut in its ship never keeps the shops shut for good (abuse MF4); on the outpost's own floor
 * with a player at the keys, they hold it as long as they stay.
 */
/datum/outpost_recovery/proc/stars_present()
	. = FALSE
	var/datum/outpost_police/police = outpost?.police
	if(!police)
		stars_away.Cut()
		return
	var/list/still_away = list()
	for(var/datum/outpost_warrant/warrant as anything in police.suspects_at_outpost())
		var/mob/living/holder = warrant.mind?.current
		if(!isliving(holder) || holder.stat == DEAD)
			continue
		var/turf/where = get_turf(holder)
		if(where && police.dispatch_in_box(where) && (holder.client || !warrant.mind.key))
			. = TRUE
			continue
		var/since = stars_away[warrant.mind] || world.time
		still_away[warrant.mind] = since
		if(world.time - since < RECOVERY_STARS_AWAY_MAX)
			. = TRUE
	stars_away = still_away

/// Whether the outpost is quiet: nobody at it has stars and no NPC died here for OUTPOST_RECOVERY_QUIET_TIME
/datum/outpost_recovery/proc/is_quiet()
	if(stars_present())
		return FALSE
	return world.time - max(last_death_at, last_shot_at) >= OUTPOST_RECOVERY_QUIET_TIME

/// The NPC bodies still lying at the outpost, oldest first
/datum/outpost_recovery/proc/npc_bodies()
	. = list()
	for(var/datum/weakref/ref as anything in npc_dead)
		var/mob/living/carbon/human/npc/body = ref.resolve()
		if(!QDELETED(body))
			. += body

/// The bodies of minds that died here and still lie here
/datum/outpost_recovery/proc/player_bodies()
	. = list()
	for(var/datum/weakref/ref as anything in player_dead)
		var/mob/living/body = ref.resolve()
		if(!QDELETED(body))
			. += body

/// Whether there is anything for a crew to do: a body, a dirty stop, or someone down for the medics
/datum/outpost_recovery/proc/has_cleanup_work()
	return length(npc_bodies()) || length(player_bodies()) || dirty_count() || length(patients_due())

/// How many patrol stops are found dirty (R4 may leave a cleaned stop in the list as FALSE)
/datum/outpost_recovery/proc/dirty_count()
	. = 0
	for(var/turf/stop as anything in dirty_stops)
		if(dirty_stops[stop])
			.++

/**
 * Someone died somewhere. Called for EVERY mob death in the world by every outpost's police death hook
 * (police_wanted.dm on_wanted_death()), so check the turf first. Tracks NPC and player dead at this outpost,
 * applies the body cap (never to a player) and the corpse-sweep switch. Runs in a signal handler: never sleeps.
 *
 * Only the outpost's own box counts for the state (the concourse, the lobby and the closets): a death in a hangar
 * or on a docked ship is the ship's trouble, and its NPC bodies stay with the base corpse sweep.
 */
/datum/outpost_recovery/proc/note_death(mob/living/dead)
	SHOULD_NOT_SLEEP(TRUE)
	if(QDELETED(src) || QDELETED(outpost) || !istype(dead))
		return
	var/turf/where = get_turf(dead)
	if(!where || get_trader_outpost_for_turf(where) != outpost)
		return
	var/in_box = !!outpost.police?.dispatch_in_box(where)
	// A player in an NPC body (a brain transplant) is a person: never on the NPC list, never collected (abuse SF3)
	if(ishumannpc(dead) && morgue_npc_body(dead))
		var/mob/living/carbon/human/npc/body = dead
		// A crew member down is the crews' own trouble (4.2), not the outpost's: the ladder counts it, wherever it fell here
		var/is_crew = istype(body, /mob/living/carbon/human/npc/ambient_npc/outpost/recovery)
		if(is_crew)
			crew_lost(body)
		// A body its own system cleans up (a bounty target, a rescued survivor) is not ours
		if(!in_box || body.npc_corpse_lifetime <= 0)
			if(is_crew)
				wake()
			return
		// The 10 minute corpse sweep is off for the outpost's dead: the crews do it. The documented
		// performance exception (spec 2): hand_back_bodies() gives a body back to the sweep after
		// OUTPOST_RECOVERY_SWEEP_FALLBACK. Set here, inside death(): the base tracks the corpse only after this signal.
		body.npc_corpse_lifetime = 0
		var/datum/weakref/body_ref = WEAKREF(body)
		npc_dead -= body_ref
		npc_dead += body_ref
		mark_dirty_near(where)
		if(is_crew)
			wake()
			return
		last_death_at = world.time
		begin_trouble()
		return
	if(!dead.mind)
		return
	var/datum/weakref/dead_ref = WEAKREF(dead)
	if(!(dead_ref in player_dead))
		player_dead += dead_ref
	if(in_box)
		mark_dirty_near(where)
		last_death_at = world.time
		begin_trouble()

/// The patrol stops within OUTPOST_RECOVERY_STOP_RANGE of `where` are dirty now (R4's janitors clear them)
/datum/outpost_recovery/proc/mark_dirty_near(turf/where)
	for(var/turf/stop as anything in outpost?.police?.stop_activities)
		if(stop.z == where.z && get_dist(stop, where) <= OUTPOST_RECOVERY_STOP_RANGE)
			dirty_stops[stop] = TRUE

/// Forgets bodies that are gone or alive again, and player bodies taken off the outpost
/datum/outpost_recovery/proc/prune_dead()
	for(var/datum/weakref/ref as anything in npc_dead.Copy())
		var/mob/living/body = ref.resolve()
		if(QDELETED(body) || body.stat != DEAD)
			npc_dead -= ref
			claims -= ref
			retry_at -= ref
			// Alive again: killed once more, it is the base sweep's if its own death() does not set a timer
			if(!QDELETED(body) && ishumannpc(body))
				var/mob/living/carbon/human/npc/revived = body
				revived.npc_corpse_lifetime = HUMAN_NPC_CORPSE_LIFETIME
	for(var/datum/weakref/ref as anything in player_dead.Copy())
		var/mob/living/body = ref.resolve()
		if(QDELETED(body) || body.stat != DEAD)
			player_dead -= ref
			continue
		var/turf/where = get_turf(body)
		if(!where || get_trader_outpost_for_turf(where) != outpost)
			player_dead -= ref

/**
 * More than OUTPOST_RECOVERY_BODY_CAP NPC bodies (officers' included): the oldest is collected (deleted) even if
 * someone is watching, with the limbs lying near it. A documented performance exception (spec 2). Player bodies
 * are not in this list and are never touched.
 */
/datum/outpost_recovery/proc/enforce_body_cap()
	while(length(npc_dead) > OUTPOST_RECOVERY_BODY_CAP)
		var/datum/weakref/oldest_ref = npc_dead[1]
		npc_dead.Cut(1, 2)
		claims -= oldest_ref
		retry_at -= oldest_ref
		var/mob/living/carbon/human/npc/oldest = oldest_ref.resolve()
		// Never a body a player has been in since it died (abuse SF3)
		if(!QDELETED(oldest) && morgue_npc_body(oldest))
			oldest.npc_fade()

/**
 * Bodies the crews have not carried off go back to the base corpse sweep: all of them once the outpost is back to
 * normal, and any of them OUTPOST_RECOVERY_SWEEP_FALLBACK after it went quiet (a body somebody guards for ever).
 */
/datum/outpost_recovery/proc/hand_back_bodies(force = FALSE)
	if(!force && (!quiet_since || world.time - quiet_since < OUTPOST_RECOVERY_SWEEP_FALLBACK))
		return
	for(var/datum/weakref/ref as anything in npc_dead.Copy())
		npc_dead -= ref
		claims -= ref
		retry_at -= ref
		var/mob/living/carbon/human/npc/body = ref.resolve()
		if(QDELETED(body) || body.stat != DEAD)
			continue
		body.npc_corpse_lifetime = HUMAN_NPC_CORPSE_LIFETIME
		SShuman_npcs.track_corpse(body)

/// Credits still allowed out by drops and stick-ups at this outpost this round (R1 and R7 ask before paying)
/datum/outpost_recovery/proc/loss_room()
	return max(0, OUTPOST_RECOVERY_LOSS_CAP - losses)

/// `amount` credits went out by a drop or a stick-up (R1 and R7 call this after paying)
/datum/outpost_recovery/proc/note_loss(amount)
	if(amount > 0)
		losses += amount

/// Nobody was on the concourse for `delay`: every time this waits for moves on by as much (ambient_shifted()), so it carries on where it stopped
/datum/outpost_recovery/proc/shift_times(delay)
	if(delay <= 0)
		return
	state_since = ambient_shifted(state_since, delay)
	quiet_since = ambient_shifted(quiet_since, delay)
	last_death_at = ambient_shifted(last_death_at, delay)
	last_shot_at = ambient_shifted(last_shot_at, delay)
	next_wave_at = ambient_shifted(next_wave_at, delay)
	port_shut_until = ambient_shifted(port_shut_until, delay)
	next_refill_at = ambient_shifted(next_refill_at, delay)
	restaff_started_at = ambient_shifted(restaff_started_at, delay)
	refill_started_at = ambient_shifted(refill_started_at, delay)
	wave_called_at = ambient_shifted(wave_called_at, delay)
	for(var/datum/mind/away as anything in stars_away)
		stars_away[away] = ambient_shifted(stars_away[away], delay)
	for(var/datum/weakref/ref as anything in retry_at)
		retry_at[ref] = ambient_shifted(retry_at[ref], delay)
	for(var/datum/outpost_shop/shop as anything in posts)
		var/datum/outpost_recovery_post/post = posts[shop]
		if(post)
			post.replacement_at = ambient_shifted(post.replacement_at, delay)
			post.away_since = ambient_shifted(post.away_since, delay)

/**
 * Once a second while there is work (wake() and sleep_tick()); a slow watch (watch()) wakes it from NORMAL. Nothing
 * runs while nobody is on the concourse; the clocks are shifted on the first tick after (shift_times()). With nobody
 * at the outpost at all (its hangars and docked ships included) for a short while, the recovery is finished at once
 * instead (finish_unseen(), recovery_offscreen.dm).
 */
/datum/outpost_recovery/proc/tick()
	if(QDELETED(src) || QDELETED(outpost))
		return
	// Nobody at the outpost for a while: done at once, without the crews (decision 32, recovery_offscreen.dm)
	if(unseen_ready())
		finish_unseen()
		return
	if(!outpost_occupied())
		if(!paused_at)
			paused_at = max(world.time, 1)
		return
	if(paused_at)
		shift_times(world.time - paused_at)
		paused_at = 0
	prune_dead()
	enforce_body_cap()
	prune_crew()
	var/stars = stars_present()
	if(stars)
		last_shot_at = world.time
	switch(state)
		if(OUTPOST_RECOVERY_NORMAL)
			sleep_tick()
		if(OUTPOST_RECOVERY_TROUBLE)
			if(!stars && is_quiet())
				enter_cleanup()
		if(OUTPOST_RECOVERY_CLEANUP)
			if(stars)
				begin_trouble()
			else
				tick_cleanup()
		if(OUTPOST_RECOVERY_RESTAFF)
			if(stars)
				begin_trouble()
			else
				tick_restaff()
		if(OUTPOST_RECOVERY_REFILL)
			if(stars)
				begin_trouble()
			else
				tick_refill()
	hand_back_bodies()

/// A slow look, every RECOVERY_WATCH_GAP: learns the counters, and finds a keeper that has gone without dying
/datum/outpost_recovery/proc/watch()
	if(QDELETED(src) || QDELETED(outpost) || !outpost.loaded)
		return
	register_posts()
	// A counter with nobody at it, or someone of the outpost's down and nobody coming for them (decision 31)
	if(state == OUTPOST_RECOVERY_NORMAL && (length(vacant_posts()) || length(patients_due())))
		begin_trouble()

// ----- TROUBLE to CLEANUP -----

/// The outpost went quiet: the recovery call goes out and the first crew is due in a minute
/datum/outpost_recovery/proc/enter_cleanup()
	quiet_since = world.time
	set_state(OUTPOST_RECOVERY_CLEANUP)
	if(has_cleanup_work())
		say_recovery_call()

/// The desk calls for the crews on the police radio, if anyone there is alive to call
/datum/outpost_recovery/proc/say_recovery_call()
	var/datum/outpost_police/police = outpost?.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/speaker = police?.life_dispatcher()
	if(!speaker)
		return
	var/list/lines = ambient_dialogue_lines(AMBIENT_STRINGS_RECOVERY, police.profile?.voice_section || "halcyon", RECOVERY_LINE_CALL)
	var/text = outpost_police_pick_line(lines, list())
	if(text)
		speaker.life_speak(text, TRUE)

/// One second of CLEANUP: the first wave a minute after quiet, then until the bodies are gone and most stops clean, or the time is up
/datum/outpost_recovery/proc/tick_cleanup()
	if(world.time - quiet_since >= OUTPOST_RECOVERY_CLEANUP_MAX)
		finish_cleanup()
		return
	if(!length(npc_bodies()) && !length(patients_due()) && clean_share() * 100 >= OUTPOST_RECOVERY_CLEAN_SHARE)
		finish_cleanup()
		return
	if(wave_active)
		build_pending()
	else if(world.time >= quiet_since + OUTPOST_RECOVERY_FIRST_WAVE)
		call_wave()

/// CLEANUP is over: the staff walk in. A wave still about at the end did its job, so the ladder starts again.
/datum/outpost_recovery/proc/finish_cleanup()
	if(wave_active)
		waves_lost = 0
	wave_active = FALSE
	// Whoever was not built yet is not coming
	wave_morgue_left = 0
	wave_janitors_left = 0
	wave_medics_left = 0
	wave_escort_left = 0
	restaff_started_at = world.time
	set_state(OUTPOST_RECOVERY_RESTAFF)
	send_staff()

/// One second of RESTAFF: replacements walk in; once every counter and post is kept (or the time is up) the residents come back
/datum/outpost_recovery/proc/tick_restaff()
	// The crews leave when their work is done: at once if nobody holds a body, else after a short grace
	if(length(crew) && (!crew_busy() || world.time - restaff_started_at >= RECOVERY_CREW_GRACE))
		retire_crew()
	send_staff()
	turn_round_replacements()
	if(!length(staff_needed()) || world.time - restaff_started_at >= RECOVERY_RESTAFF_MAX)
		refill_started_at = world.time
		next_refill_at = world.time
		set_state(OUTPOST_RECOVERY_REFILL)
		var/datum/ambient_place/outpost/place = recovery_place()
		if(place)
			place.needs_settling = TRUE

/// One second of REFILL: one arrival every OUTPOST_RECOVERY_REFILL_GAP_MIN to _MAX (the ambient roles ask roles_may_fill()), NORMAL when every role is filled
/datum/outpost_recovery/proc/tick_refill()
	if(length(crew))
		retire_crew()
	var/datum/ambient_place/outpost/place = recovery_place()
	if(place && world.time >= next_refill_at)
		place.needs_settling = TRUE
	if(refill_complete() || world.time - refill_started_at >= RECOVERY_REFILL_MAX)
		set_state(OUTPOST_RECOVERY_NORMAL)

/// Whether every ambient role that applies here has all the people it wants (the police roles included)
/datum/outpost_recovery/proc/refill_complete()
	var/datum/ambient_place/outpost/place = recovery_place()
	if(!place || QDELETED(outpost))
		return TRUE
	for(var/datum/ambient_outpost_role/role as anything in SSambient_npcs.get_outpost_roles())
		if(!role.npc_type || !role.applies_to(outpost))
			continue
		if(role.wanted(place) - place.count_role(role.type) > 0)
			return FALSE
	return TRUE

/**
 * Whether the ambient roles may bring `role`'s people back now: always at NORMAL; never while the outpost is in
 * trouble, being cleaned or restaffed (the staff come in RESTAFF by send_staff(), the residents later); in REFILL
 * one arrival per OUTPOST_RECOVERY_REFILL_GAP_MIN to _MAX. Read by the outpost place's open_slots() (recovery_staff.dm).
 */
/datum/outpost_recovery/proc/roles_may_fill(datum/ambient_outpost_role/role)
	switch(state)
		if(OUTPOST_RECOVERY_NORMAL)
			return TRUE
		if(OUTPOST_RECOVERY_REFILL)
			// Nobody on the concourse: the pace stands still with everything else
			return !paused_at && world.time >= next_refill_at
	return FALSE

/// Someone joined the outpost's place. In REFILL an ambient arrival (not an officer or a crew member) sets the gap before the next.
/datum/outpost_recovery/proc/note_arrival(mob/living/carbon/human/npc/ambient_npc/npc)
	if(state != OUTPOST_RECOVERY_REFILL)
		return
	if(istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/police) || istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/recovery))
		return
	next_refill_at = world.time + rand(OUTPOST_RECOVERY_REFILL_GAP_MIN, OUTPOST_RECOVERY_REFILL_GAP_MAX)

/// The outpost is NORMAL again: the leftover bodies go back to the base sweep, the escorts are released and the crews go
/datum/outpost_recovery/proc/finish_recovery()
	quiet_since = 0
	wave_active = FALSE
	if(port_shut_until <= world.time)
		waves_lost = 0
	lost_workers.Cut()
	hand_back_bodies(force = TRUE)
	release_escorts()
	retire_crew()

// =========================================================================
// THE CREW WAVES (spec-rehydrate 4.1 and 4.2)
// =========================================================================

/// Drops weakrefs of crew that are gone (deleted or faded out)
/datum/outpost_recovery/proc/prune_crew()
	for(var/datum/weakref/ref as anything in crew.Copy())
		var/mob/living/who = ref.resolve()
		if(QDELETED(who))
			crew -= ref
			wave_workers -= ref
	for(var/datum/weakref/ref as anything in wave_workers.Copy())
		var/mob/living/who = ref.resolve()
		if(QDELETED(who))
			wave_workers -= ref

/// The wave's workers (morgue and janitors) that are alive
/datum/outpost_recovery/proc/live_wave_workers()
	. = list()
	for(var/datum/weakref/ref as anything in wave_workers)
		var/mob/living/who = ref.resolve()
		if(!QDELETED(who) && who.stat != DEAD)
			. += who

/// Whether any officer of this outpost's roster is alive (the escort rule asks)
/datum/outpost_recovery/proc/officers_alive()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in outpost?.police?.officers)
		if(!QDELETED(officer) && officer.stat != DEAD && !officer.fading)
			return TRUE
	return FALSE

/**
 * Orders the next crew wave by 4.2's ladder, or does nothing while the port is shut, a wave is still about, or
 * there is nothing to do. 2 morgue workers and 2 janitors (4 and 4 past OUTPOST_RECOVERY_BIG_WAVE_BODIES bodies) with
 * an escort of 2 officers if none is alive; after crews were lost the escort grows and the wave waits (LOST_DELAYS).
 * The crews are built a few at a time by build_pending(), as the lift allows.
 */
/datum/outpost_recovery/proc/call_wave()
	if(QDELETED(outpost) || world.time < port_shut_until || world.time < next_wave_at || wave_active)
		return
	prune_crew()
	if(length(live_wave_workers()))
		return
	var/bodies = length(npc_bodies())
	var/need_morgue = bodies || length(player_bodies())
	var/need_janitors = bodies || dirty_count()
	var/hurt = length(patients_due())
	if(!need_morgue && !need_janitors && !hurt)
		return
	var/each = bodies > OUTPOST_RECOVERY_BIG_WAVE_BODIES ? OUTPOST_RECOVERY_CREW_BIG : OUTPOST_RECOVERY_CREW_SMALL
	var/escort = officers_alive() ? 0 : OUTPOST_RECOVERY_ESCORT
	var/escort_kind = POLICE_UNIT_OFFICER
	if(waves_lost > 0)
		var/list/escorts = OUTPOST_RECOVERY_LOST_ESCORTS
		escort = max(escort, escorts[min(waves_lost, length(escorts))])
		if(waves_lost >= length(escorts))
			escort_kind = POLICE_UNIT_TACTICAL
	wave_number++
	wave_active = TRUE
	wave_called_at = world.time
	wave_morgue_left = need_morgue ? each : 0
	wave_janitors_left = need_janitors ? each : 0
	wave_medics_left = hurt ? (hurt > RECOVERY_MEDIC_SECOND_AT ? 2 : 1) : 0
	wave_escort_left = escort
	wave_escort_size = escort
	wave_escort_kind = escort_kind
	wave_workers = list()
	build_pending()

/// Builds the wave's crew that is still to come, as many as the lift has room for now; the rest next second
/datum/outpost_recovery/proc/build_pending()
	while(wave_morgue_left > 0 && make_crew(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue))
		wave_morgue_left--
	while(wave_janitors_left > 0 && make_crew(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor))
		wave_janitors_left--
	while(wave_medics_left > 0 && make_crew(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic))
		wave_medics_left--
	if(wave_escort_left > 0)
		send_escort()

/// Where a crew member steps off the lift: a free tile behind a staff door, else the public lift's alcove; null if both are taken
/datum/outpost_recovery/proc/crew_arrival_turf()
	var/turf/lift = outpost?.police?.life_free_lift_turf()
	return lift || SSambient_npcs.lift_arrival_turf(outpost)

/// One crew member of `crew_type` off the lift, in the outpost's place; null if there is no room for them now
/datum/outpost_recovery/proc/make_crew(crew_type)
	var/datum/ambient_place/outpost/place = recovery_place()
	var/turf/where = crew_arrival_turf()
	if(!place || !where)
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker = new crew_type(where)
	worker.outpost_recovery = src
	worker.wave = wave_number
	worker.dialogue_section = outpost.police?.profile?.voice_section || "halcyon"
	worker.set_place(place)
	worker.fade_in()
	var/datum/weakref/worker_ref = WEAKREF(worker)
	crew += worker_ref
	wave_workers += worker_ref
	return worker

/**
 * The wave's escort: officers who stand watch while the crews work. Built through the police's own dispatch (one
 * wave, one lift point) and marked in dispatch_unit_built() below so the stand-down at zero stars leaves them be.
 * Best effort: one try per wave.
 */
/datum/outpost_recovery/proc/send_escort()
	var/count = wave_escort_left
	wave_escort_left = 0
	var/datum/outpost_police/police = outpost?.police
	if(!police || count <= 0)
		return
	var/datum/outpost_police_wave/wave = police.dispatch_new_wave(POLICE_SECTOR_CONCOURSE, police.lift_point(POLICE_SECTOR_CONCOURSE))
	var/datum/weakref/wave_ref = WEAKREF(wave)
	escort_waves += wave_ref
	for(var/i in 1 to count)
		if(!police.dispatch_queue_unit(wave_escort_kind, wave))
			break
	if(!length(wave.orders) && !length(wave.members))
		escort_waves -= wave_ref
		police.dispatch_waves -= wave
		qdel(wave)

/// Whether `wave` is one of this recovery's escort waves
/datum/outpost_recovery/proc/is_escort_wave(datum/outpost_police_wave/wave)
	return !!wave && (WEAKREF(wave) in escort_waves)

/// An escort officer is built: marked, and counted with the crew
/datum/outpost_police/dispatch_unit_built(datum/outpost_police_wave/wave, datum/weakref/mind_ref, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	. = ..()
	var/datum/outpost_recovery/recovery = outpost?.recovery
	if(QDELETED(officer) || !recovery?.is_escort_wave(wave))
		return
	officer.recovery_escort = TRUE
	recovery.crew += WEAKREF(officer)

/// An escort is not a response unit: dispatch's stand-down at zero stars and its empty-outpost recall leave them at their watch
/datum/outpost_police/dispatch_is_response_unit(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	. = ..()
	if(. && officer.recovery_escort)
		return FALSE

/// A police officer who came with a crew wave to stand watch (recovery_core.dm)
/mob/living/carbon/human/npc/ambient_npc/outpost/police
	var/recovery_escort = FALSE

/// The escorts go back to being response units, which dispatch stands down by the lift
/datum/outpost_recovery/proc/release_escorts()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in outpost?.police?.officers)
		officer.recovery_escort = FALSE
	escort_waves.Cut()

/// Whether a worker still holds a body (R3's claims) or a patient: the crews do not leave a bagged body or a patient half way
/datum/outpost_recovery/proc/crew_busy()
	return (length(claims) || length(patient_claims)) && length(live_wave_workers())

/// The crews that are still about go: they slip away by the lift. The escorts are not crew in this sense (release_escorts()).
/datum/outpost_recovery/proc/retire_crew()
	for(var/datum/weakref/ref as anything in crew.Copy())
		var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker = ref.resolve()
		if(istype(worker) && !QDELETED(worker) && worker.stat != DEAD)
			worker.fade_out()
	crew.Cut()
	wave_workers.Cut()

/**
 * A crew member was killed or lost: counts toward 4.2's ladder (R3, R4 and note_death() call this; once per worker).
 * When the last worker of a wave is down the wave is lost: the next one waits 2, 4 or 8 minutes and brings a bigger
 * escort; the fourth shuts the port for OUTPOST_RECOVERY_PORT_SHUT_TIME and the ladder starts again at its first row.
 */
/datum/outpost_recovery/proc/crew_lost(mob/living/worker)
	if(QDELETED(src) || !istype(worker, /mob/living/carbon/human/npc/ambient_npc/outpost/recovery))
		return
	var/key = REF(worker)
	if(lost_workers[key])
		return
	lost_workers[key] = TRUE
	var/datum/weakref/worker_ref = WEAKREF(worker)
	crew -= worker_ref
	if(!wave_active || wave_morgue_left > 0 || wave_janitors_left > 0 || wave_medics_left > 0)
		return
	for(var/mob/living/who as anything in live_wave_workers())
		if(who != worker)
			return
	wave_active = FALSE
	waves_lost++
	var/list/delays = OUTPOST_RECOVERY_LOST_DELAYS
	if(waves_lost >= OUTPOST_RECOVERY_LOST_SHUT)
		port_shut_until = world.time + OUTPOST_RECOVERY_PORT_SHUT_TIME
		waves_lost = 1
		next_wave_at = port_shut_until + delays[1]
	else
		next_wave_at = world.time + delays[min(waves_lost, length(delays))]
	wake()
