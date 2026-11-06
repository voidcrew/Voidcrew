/// Backgrounds: owned by P1. See data/backgrounds/spec.md.

/*
 * EVENT CATALOG (category METRIC_BACKGROUND). Every row passes `ship` itself, null for a shipless
 * background, because metric_crew_ship() would otherwise fall back to the hull a mob stands on.
 *
 * background_chosen       subject = key; details: crime, scenario, roundstart (P1, background_begin())
 * background_overflow     subject = key; over the roundstart share, shipped out with a crew (P1)
 * background_start_failed subject = key; details: reason (P1)
 * background_outcome      subject = key; details: outcome, line. One row per state: when the goal is
 *                         settled, when the state ends, or at round end while still ongoing (P1)
 * warrant_minted          ckey = target (P2)
 * warrant_paid            ckey = hunter, other_ckey = target, credits; details: minutes_at_large, state (P2)
 * clean_slate             credits (P2)
 * siphon_goal             quantity = progress after the take (P4)
 * hauler_robbed           ship = robber, credits; details: how (P5)
 * pod_launched            (P2)
 * homestead_raid          (P6)
 * family_death            other_ckey = attacker (P6)
 */

/**
 * Writes one METRIC_BACKGROUND row about a mind's background.
 *
 * * event - an event from the catalog above
 * * mind - whose background it is; gives the ckey
 * * details - small assoc list stored as JSON
 * * ship - the hull the row is about, or null
 * * state - the state the row is about, when it is not the mind's current one
 * * background_key - the background, for players who have no state yet (overflow, failed starts)
 */
/proc/background_metric(event, datum/mind/mind, list/details, obj/structure/overmap/ship/ship, datum/background_state/state, background_key)
	if(!SSmetrics.accepting)
		return
	state = state || mind?.background_state
	var/player_ckey = state?.ckey || (mind?.key ? ckey(mind.key) : null)
	record_metric(METRIC_BACKGROUND, event, ckey = player_ckey, ship = ship, subject = background_key || state?.key, details = details)
