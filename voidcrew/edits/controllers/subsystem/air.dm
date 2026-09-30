// Voidcrew extensions to code/controllers/subsystem/air.dm.

/**
 * VOIDCREW ADDITION: deletes the member-less pipelines expand_pipeline() had to park.
 *
 * Runs before the drain rather than inside it: /datum/pipeline/Destroy() calls
 * remove_from_expansion(), which edits the very list expand_pipeline() walks. By the time
 * we get here that drain has finished (or has not started), so the edit is safe.
 *
 * A husk is only deleted once `building` has cleared - while it is set the pipeline is
 * still queued for expansion and may legitimately pick members back up.
 */
/datum/controller/subsystem/air/proc/reap_pipeline_husks()
	if(!length(pipeline_husks))
		return
	for(var/datum/pipeline/husk as anything in pipeline_husks.Copy())
		if(QDELETED(husk))
			pipeline_husks -= husk
			continue
		if(husk.building)
			continue
		pipeline_husks -= husk
		// VOIDCREW EDIT: has_live_members() rather than length(). A husk that was holding
		// a machine which then hard deleted reads as length 1 with a null inside, and the
		// old length test let it walk away as if it were still in use.
		if(husk.has_live_members())
			continue
		qdel(husk)

/**
 * VOIDCREW ADDITION: reaps member-less pipelines that never went through the husk list.
 *
 * `reap_pipeline_husks()` only ever sees pipelines parked by the pipe-steal branch of
 * `expand_pipeline()`. The other way a pipeline ends up empty in `SSair.networks` is a
 * machine that was already dying when something queued it for a rebuild: `rebuild_pipes()`
 * mints a fresh `/datum/pipeline` for it, the machine's `Destroy()` has already run its
 * `QDEL_NULL(parent)`, and so nothing is ever going to delete that pipeline again. It sits
 * in `networks` being processed every fire for the rest of the round, and it holds a hard
 * ref to the dead machine while it is at it. The source guards below stop new ones being
 * made; this sweep clears any that still get through.
 *
 * Two details this has to get right:
 * * `length(members)` is not the test. A hard-deleted machine leaves a null entry in the
 *   list rather than shortening it, so a leaked pipeline reads as `members = list(null)` -
 *   length 1, live members 0. `has_live_members()` counts what is actually there.
 * * `/datum/pipeline/Destroy()` edits `networks`, `expansion_queue` and `pipeline_husks`.
 *   So: walk a copy, collect, and qdel only after the walk is over - and run outside the
 *   expansion drain, the same placement `reap_pipeline_husks()` already uses.
 */
/datum/controller/subsystem/air/proc/reap_orphan_pipelines()
	if(world.time < next_orphan_sweep)
		return
	next_orphan_sweep = world.time + orphan_sweep_interval
	var/list/datum/pipeline/doomed = list()
	for(var/datum/pipeline/net as anything in networks.Copy())
		if(isnull(net) || QDELETED(net))
			continue
		// Still queued for expansion - it is allowed to be empty and may pick members up.
		if(net.building)
			net.orphan_strikes = 0
			continue
		if(net.has_live_members())
			net.orphan_strikes = 0
			continue
		net.orphan_strikes++
		if(net.orphan_strikes < orphan_pipeline_strikes)
			continue
		doomed += net
	if(!length(doomed))
		return
	orphan_pipelines_reaped += length(doomed)
	for(var/datum/pipeline/net as anything in doomed)
		qdel(net)

/datum/controller/subsystem/air
	/// VOIDCREW ADDITION: pipelines that lost their last member to a pipe steal in
	/// expand_pipeline() while they were still flagged `building`. That call site cannot
	/// qdel one on the spot - /datum/pipeline/Destroy() edits expansion_queue, which is the
	/// list that drain is walking - so the husk is parked here and reaped on a later fire,
	/// once `building` has cleared and it is provably still empty. Without this a
	/// stacked-pipe map (every voidcrew hull has some) leaks one member-less pipeline into
	/// SSair.networks per site build, processed every tick for the rest of the round.
	var/list/datum/pipeline/pipeline_husks = list()
	/// VOIDCREW ADDITION: how many consecutive orphan sweeps a pipeline has to be found
	/// empty on before it is reaped. build_pipeline() legitimately leaves a pipeline with
	/// no members for the window between `new /datum/pipeline` and its queued expansion,
	/// so one strike is not proof of a leak - two separate sweeps is.
	var/orphan_pipeline_strikes = 2
	/// VOIDCREW ADDITION: world.time the next orphan-pipeline sweep may run. The sweep is
	/// O(networks * members) and nothing it catches is urgent, so it is rate limited.
	var/next_orphan_sweep = 0
	/// VOIDCREW ADDITION: how long between orphan-pipeline sweeps. Short on purpose: two
	/// strikes at this interval is how long an orphan can survive, and the churn soak
	/// samples 20 seconds after a teardown. At 5 seconds an orphan made during teardown is
	/// always gone before the sample, so `pipelines_orphan` reads a real state rather than
	/// whatever happened to be in flight. Sweeping ~70 networks costs nothing.
	var/orphan_sweep_interval = 5 SECONDS
	/// VOIDCREW ADDITION: running total of pipelines the orphan sweep has reaped, for the
	/// churn-soak harness and for `SSair` debug output.
	var/orphan_pipelines_reaped = 0
