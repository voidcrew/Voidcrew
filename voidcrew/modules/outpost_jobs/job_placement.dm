/**
 * # Outpost jobs: placement
 *
 * Owner: P2. Where a job's people and things go: the ambient loiter floor of the job's outpost, out of every
 * player's view, never a doorway or a one-tile passage (spec 4.2). No map landmarks (L17). P0 stub: no room anywhere.
 */

/**
 * `count` free turfs of `kind` (FIXER_SPOT_WALL, FIXER_SPOT_OPEN or FIXER_SPOT_ARRIVE) on `outpost`'s public floor,
 * nearest `near` first when it is given, unseen by players. An empty list when there are not enough. P2.
 */
/proc/fixer_job_spot(obj/structure/overmap/trader_outpost/outpost, kind, atom/near, count = 1)
	return list()
