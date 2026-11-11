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
 * Behaviour at R0: none. The state stays NORMAL, nothing is tracked, no crew comes.
 */

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
	/// world.time of the last shot fired at the outpost, and of the last NPC death there
	var/last_shot_at = 0
	var/last_death_at = 0

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

	/// The looping tick, or null while asleep (R2 decides when it runs)
	var/tick_timer

/datum/outpost_recovery/New(obj/structure/overmap/trader_outpost/new_outpost)
	. = ..()
	outpost = new_outpost
	state_since = world.time

/datum/outpost_recovery/Destroy()
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	npc_dead.Cut()
	player_dead.Cut()
	claims.Cut()
	retry_at.Cut()
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

// =========================================================================
// STATE AND PACE (R2)
// =========================================================================

/// Whether the outpost is quiet: nobody at it has stars and no NPC died here for OUTPOST_RECOVERY_QUIET_TIME
/datum/outpost_recovery/proc/is_quiet()
	return FALSE

/**
 * Someone died somewhere. Called for EVERY mob death in the world by every outpost's police death hook
 * (police_wanted.dm on_wanted_death()), so check the turf first. Tracks NPC and player dead at this outpost,
 * applies the body cap (never to a player) and the corpse-sweep switch. Runs in a signal handler: never sleeps.
 */
/datum/outpost_recovery/proc/note_death(mob/living/dead)
	SHOULD_NOT_SLEEP(TRUE)
	return

/// Orders the next crew wave by 4.2's ladder, or does nothing while the port is shut
/datum/outpost_recovery/proc/call_wave()
	return

/// A crew member was killed or lost: counts toward 4.2's ladder (R3 and R4 call this)
/datum/outpost_recovery/proc/crew_lost(mob/living/worker)
	return

/// Credits still allowed out by drops and stick-ups at this outpost this round (R1 and R7 ask before paying)
/datum/outpost_recovery/proc/loss_room()
	return 0

/// `amount` credits went out by a drop or a stick-up (R1 and R7 call this after paying)
/datum/outpost_recovery/proc/note_loss(amount)
	return

/// Once a second while there is work (R2 starts and stops it)
/datum/outpost_recovery/proc/tick()
	return
