/**
 * # Outpost jobs: the ledger
 *
 * Owner: P2. /datum/fixer_ledger: one per job, listening on the police of the job's outpost (and, for a smuggle,
 * the far end) for COMSIG_OUTPOST_POLICE_CRIME and COMSIG_OUTPOST_POLICE_STARS, and keeping the crew, scene and port
 * readings of spec 5. P0 stubs: it hears nothing.
 */

/datum/fixer_ledger

/// Starts listening on `police` (COMSIG_OUTPOST_POLICE_CRIME, COMSIG_OUTPOST_POLICE_STARS). P2.
/datum/fixer_ledger/proc/watch(datum/outpost_police/police)
	return

/// Admin text: every counted crime this ledger heard. P2.
/datum/fixer_ledger/proc/report()
	return ""
