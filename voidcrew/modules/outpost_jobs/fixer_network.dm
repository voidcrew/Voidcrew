/**
 * # Outpost jobs: the network
 *
 * Owner: P1. /datum/fixer_network (GLOB.fixer_network): every fixer's slate, trust, rest and burn (spec 3). P0 stubs
 * behave as if no fixer had any work: refusal() says "nothing", nobody is trusted, nothing is recorded.
 */

GLOBAL_DATUM_INIT(fixer_network, /datum/fixer_network, new)

/datum/fixer_network

/// The first failing check of spec 3.2 for `user` asking `fixer`, as a FIXER_LINE_* key, or null. P1.
/datum/fixer_network/proc/refusal(mob/living/user, mob/fixer)
	return FIXER_LINE_NOTHING

/// `job` was paid by `fixer` at `noise`: trust +1, rest at the paying fixer, gossip. P1.
/datum/fixer_network/proc/note_paid(datum/mission/fixer_job/job, noise, mob/fixer)
	return

/// `job` failed for `reason` (FIXER_FAIL_*): rest at the giving fixer unless spoiled or staging failed. P1.
/datum/fixer_network/proc/note_failed(datum/mission/fixer_job/job, reason)
	return

/// `offender` and their crew record are burned with every fixer for FIXER_BURN_TIME. P1.
/datum/fixer_network/proc/burn(datum/mind/offender)
	return

/// Jobs `crew` has been paid for. P1.
/datum/fixer_network/proc/trust_of(datum/voidcrew_crew_record/crew)
	return 0

/// The living fixer at `outpost`, or null. P1.
/datum/fixer_network/proc/fixer_at(obj/structure/overmap/trader_outpost/outpost)
	return null

/// Whether any fixer is alive anywhere. P1.
/datum/fixer_network/proc/any_fixer_alive()
	return TRUE

/// Admin: clears `crew`'s rest and burn everywhere. P1.
/datum/fixer_network/proc/clear_crew(datum/voidcrew_crew_record/crew)
	return

/// Admin: sets `crew`'s jobs paid to `amount`. P1.
/datum/fixer_network/proc/set_trust(datum/voidcrew_crew_record/crew, amount)
	return
