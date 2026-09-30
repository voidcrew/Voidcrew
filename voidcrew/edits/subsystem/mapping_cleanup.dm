/datum/controller/subsystem/mapping
	// Voidcrew: one-shot latch for the dead-area recovery in fire() below.
	/// Whether we have already reported a reservation turf found sitting in a destroyed area.
	var/warned_about_dead_reservation_area = FALSE
	// Voidcrew: released reservation turfs whose starlight has been switched
	/// off and which still have to be taken out of GLOB.starlight. Assoc turf -> TRUE so the
	/// compaction below is a membership test rather than a search. See release_reservation_starlight().
	var/list/starlight_release_queue
	// Voidcrew: world.time the next used_turfs orphan sweep may run at.
	/// Rate limit for reconcile_used_turfs(), which walks all of used_turfs.
	var/next_used_turf_reconcile = 0

/**
 * Voidcrew: takes the turfs darkened by the reservation drain out of
 * GLOB.starlight, in one linear pass over the list rather than one linear scan per turf.
 *
 * `GLOB.starlight -= turf` inside the drain loop is the obvious spelling and it is
 * quadratic: the loop runs once per released turf and the list can hold as many entries
 * again, which on a large release is a multi-second world freeze. Rebuilding the list once
 * against an assoc membership set is O(len(GLOB.starlight)) no matter how many turfs were
 * released, and the drain only pays it once per REBUILD_STARLIGHT_AFTER turfs plus once at
 * the end of each fire.
 *
 * Leaving the entries in place instead is not an option: enable_starlight() only appends
 * when `!light_on`, so a member whose light we switched off would be appended a SECOND
 * time the next time that ground is lit, and BYOND's Remove() only ever drops one of them.
 * That trades a bounded datum leak for an unbounded list leak.
 *
 * A turf that was re-lit between being queued and being flushed is kept: the queue is a
 * request to drop the entry, `light_on` is the ground truth about whether it still belongs.
 */
/// Turfs the reservation drain may darken before the GLOB.starlight compaction is worth a pass.
#define REBUILD_STARLIGHT_AFTER 1000

/datum/controller/subsystem/mapping/proc/release_reservation_starlight(force = FALSE)
	var/list/released = starlight_release_queue
	if(!length(released))
		return
	if(!force && length(released) < REBUILD_STARLIGHT_AFTER)
		return
	starlight_release_queue = null

	var/list/kept = list()
	for(var/turf/open/space/lit as anything in GLOB.starlight)
		// `as anything`, so this also drops the nulls a hard delete leaves in place and
		// anything a raw turf swap retargeted into something that is no longer space.
		if(isnull(lit))
			continue
		if(released[lit] && !lit.light_on)
			continue
		kept += lit
	GLOB.starlight = kept

#undef REBUILD_STARLIGHT_AFTER

// Voidcrew: how often the used_turfs orphan sweep below may run.
#define USED_TURF_RECONCILE_INTERVAL (2 MINUTES)
// Voidcrew: how many orphans one sweep may hand back, so a pathological
// backlog is drained over several passes instead of in one unbounded release.
#define USED_TURF_RECONCILE_MAX_RECLAIM 5000

/**
 * Voidcrew: self-healing sweep for SSmapping.used_turfs.
 *
 * used_turfs maps turf -> the /datum/turf_reservation that claimed it, and the only thing
 * that ever removes an entry is that reservation's Release(). An entry whose reservation
 * is gone is therefore ground that is claimed forever: it keeps RESERVATION_TURF, never
 * goes back into unused_turfs, and _reserve_area() will never hand it out again. Enough of
 * those and request_turf_block_reservation() cannot fit a block on any existing reservation
 * z-level and mints a permanent new 255x255 one (~65k turfs, ~48 MB) per shortfall.
 *
 * Release() is the fix for the known way that happened (see the note there); this is the
 * net for any path that is still missed, and it also cleans up entries stranded before this
 * code existed. It is deliberately narrow: an entry is only dropped when nothing live owns
 * it - a null value (the reservation hard deleted, which nulls the ref in place) or a
 * QDELETED one. A reservation that still exists is never touched, so this cannot race a
 * live claim, and turfs claimed but not yet published are impossible because _reserve_area()
 * writes used_turfs[T] and the datum ref in the same unyielding pass.
 *
 * O(length(used_turfs)) with no sleeps, capped and rate limited.
 */
/datum/controller/subsystem/mapping/proc/reconcile_used_turfs()
	if(!initialized || clearing_reserved_turfs)
		return
	if(world.time < next_used_turf_reconcile)
		return
	next_used_turf_reconcile = world.time + USED_TURF_RECONCILE_INTERVAL

	var/list/orphans = list()
	// `as anything` - a hard delete can null a key in place, and those are skipped rather
	// than reclaimed: there is no turf left to hand back.
	for(var/turf/claimed as anything in used_turfs)
		if(isnull(claimed))
			continue
		var/datum/turf_reservation/holder = used_turfs[claimed]
		if(!QDELETED(holder))
			continue
		orphans += claimed
		if(length(orphans) >= USED_TURF_RECONCILE_MAX_RECLAIM)
			break

	if(!length(orphans))
		return

	used_turfs -= orphans
	log_mapping("SSmapping: reconciled [length(orphans)] used_turfs entr[length(orphans) == 1 ? "y" : "ies"] whose \
		reservation no longer exists - the ground was claimed with nothing left to release it. Handing it back.")
	reserve_turfs(orphans)

#undef USED_TURF_RECONCILE_INTERVAL
#undef USED_TURF_RECONCILE_MAX_RECLAIM
