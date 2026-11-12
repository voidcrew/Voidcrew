/**
 * # Outpost jobs: the ledger
 *
 * Owner: P2. /datum/fixer_ledger: one per job, from accept to pay, listening on the police of the job's outpost (and,
 * for a smuggle, the far end) for COMSIG_OUTPOST_POLICE_CRIME and COMSIG_OUTPOST_POLICE_STARS. It keeps spec 5.2's
 * three readings; /datum/mission/fixer_job/proc/noise() turns them into the job's noise.
 *
 * - Crew: the highest stars any roster mind (on_roster(): on the crew at accept, or on its record at the time of the
 *   crime) held after a counted crime there.
 * - Scene: the highest stars anyone held after a counted crime against a job atom (track(thing, scene = TRUE)), or of
 *   one of the job's `scene_crimes`.
 * - Port: the alert level where the deed was done, at the deed or the highest it was in the FIXER_PORT_WINDOW before
 *   (the level in force when the window opened counts too); at least FIXER_PORT_SHOOTOUT while the kingpin's crew is
 *   fighting there (abuse J15).
 *
 * The stars of a counted crime are never forgotten: heat draining away afterwards changes nothing. Reports still
 * waiting on a witness (pending()) count as made. Nothing here ticks: every reading is a signal handler or a read.
 */

/// The port reads at least this loud while the kingpin's crew is fighting at the outpost (spec 5.2)
#define FIXER_PORT_SHOOTOUT 2
/// Lines report() keeps
#define FIXER_LEDGER_LINES 40

/datum/fixer_ledger
	/// The job this ledger reads for
	var/datum/weakref/job_ref
	/// The police it listens on
	var/list/datum/outpost_police/watched = list()
	/// Spec 5.2's readings, in stars
	var/crew_reading = 0
	var/scene_reading = 0
	var/port_reading = 0
	/// Any crew or scene crime was counted
	var/counted = FALSE
	/// The port reading has been taken (at the deed)
	var/port_taken = FALSE
	/// Police -> list of list(world.time, alert level), each change of level since the window before last
	var/list/level_changes = list()
	/// Admin lines: every counted crime it took
	var/list/heard = list()
#ifdef UNIT_TESTS
	/// Tests: the port level every reading sees, or null for the real one
	var/test_port_level
#endif

/datum/fixer_ledger/New(datum/mission/fixer_job/job)
	. = ..()
	job_ref = WEAKREF(job)

/datum/fixer_ledger/Destroy()
	for(var/datum/outpost_police/police as anything in watched)
		UnregisterSignal(police, list(COMSIG_OUTPOST_POLICE_CRIME, COMSIG_OUTPOST_POLICE_STARS, COMSIG_QDELETING))
	watched.Cut()
	level_changes = null
	job_ref = null
	return ..()

/// Starts listening on `police` (COMSIG_OUTPOST_POLICE_CRIME, COMSIG_OUTPOST_POLICE_STARS)
/datum/fixer_ledger/proc/watch(datum/outpost_police/police)
	if(QDELETED(police) || QDELETED(src) || (police in watched))
		return
	watched += police
	RegisterSignal(police, COMSIG_OUTPOST_POLICE_CRIME, PROC_REF(on_crime))
	RegisterSignal(police, COMSIG_OUTPOST_POLICE_STARS, PROC_REF(on_stars))
	RegisterSignal(police, COMSIG_QDELETING, PROC_REF(on_police_deleted))
	note_level(police)

/// A counted crime at a watched outpost
/datum/fixer_ledger/proc/on_crime(datum/outpost_police/police, datum/mind/mind, crime, atom/victim, stars_after, derived)
	SIGNAL_HANDLER
	var/datum/mission/fixer_job/job = job_ref?.resolve()
	if(QDELETED(job) || job.failed || job.completed)
		return
	var/crew = job.on_roster(mind)
	var/scene = job.is_scene_victim(victim) || (crime in job.scene_crimes)
	if(!crew && !scene)
		return
	counted = TRUE
	if(crew)
		crew_reading = max(crew_reading, stars_after)
	if(scene)
		scene_reading = max(scene_reading, stars_after)
	heard += "[station_time_timestamp("hh:mm:ss")] [html_encode(mind?.name || "someone")] ([mind?.key || "no key"]): [crime][victim ? " against [html_encode("[victim]")]" : ""] at [police.outpost], [stars_after] stars[derived ? ", derived" : ""] ([crew ? "crew" : ""][crew && scene ? ", " : ""][scene ? "scene" : ""])"
	if(length(heard) > FIXER_LEDGER_LINES)
		heard.Cut(1, 2)

/// A change of stars at a watched outpost: the port's level may have moved
/datum/fixer_ledger/proc/on_stars(datum/outpost_police/police, datum/mind/mind, old_stars, new_stars)
	SIGNAL_HANDLER
	note_level(police)

/datum/fixer_ledger/proc/on_police_deleted(datum/outpost_police/police)
	SIGNAL_HANDLER
	UnregisterSignal(police, list(COMSIG_OUTPOST_POLICE_CRIME, COMSIG_OUTPOST_POLICE_STARS, COMSIG_QDELETING))
	watched -= police
	level_changes -= police

/// The port's level at `police`'s outpost now: its alert level, raised by a kingpin shootout there
/datum/fixer_ledger/proc/port_level(datum/outpost_police/police)
#ifdef UNIT_TESTS
	if(!isnull(test_port_level))
		return test_port_level
#endif
	if(QDELETED(police))
		return 0
	. = police.alert_level()
	if(ambient_kingpin_fight_center(police.outpost))
		. = max(., FIXER_PORT_SHOOTOUT)

/// Writes down `police`'s level if it changed, keeping only what the port window can still need
/datum/fixer_ledger/proc/note_level(datum/outpost_police/police)
	if(QDELETED(police) || port_taken)
		return
	var/level = port_level(police)
	var/list/changes = level_changes[police]
	if(!changes)
		changes = list()
		level_changes[police] = changes
	if(length(changes))
		var/list/last = changes[length(changes)]
		if(last[2] == level)
			return
	changes += list(list(world.time, level))
	// Of the changes before the window, only the newest still matters (the level in force when it opened)
	var/window_start = world.time - FIXER_PORT_WINDOW
	while(length(changes) >= 2)
		var/list/second = changes[2]
		if(second[1] > window_start)
			break
		changes.Cut(1, 2)

/**
 * The port reading, taken once at the deed at `police`'s outpost (the first watched if null): the level now, or the
 * highest it was in the FIXER_PORT_WINDOW before.
 */
/datum/fixer_ledger/proc/take_port_reading(datum/outpost_police/police)
	if(port_taken)
		return port_reading
	if(QDELETED(police) || !(police in watched))
		police = length(watched) ? watched[1] : null
	var/level = port_level(police)
	var/window_start = world.time - FIXER_PORT_WINDOW
	var/list/changes = police ? level_changes[police] : null
	for(var/index in 1 to length(changes))
		var/list/change = changes[index]
		var/list/next = index < length(changes) ? changes[index + 1] : null
		// A level counts if it was in force at any time in the window: set in it, or not yet replaced when it opened
		if(!next || next[1] > window_start)
			level = max(level, change[2])
	port_reading = level
	port_taken = TRUE
	level_changes.Cut()
	heard += "[station_time_timestamp("hh:mm:ss")] the deed: the port read [port_reading]"
	return port_reading

/// Stars the reports still waiting on a witness would give the crew or against the job's atoms, at any watched outpost
/datum/fixer_ledger/proc/pending()
	var/datum/mission/fixer_job/job = job_ref?.resolve()
	if(QDELETED(job) || !length(watched))
		return 0
	var/list/minds = job.roster_minds()
	var/list/atoms = job.scene_atoms()
	. = 0
	for(var/datum/outpost_police/police as anything in watched)
		if(!QDELETED(police))
			. = max(., police.pending_noise(minds, atoms))

/// Admin text: every counted crime this ledger heard, and the readings. Names in it are already html_encode()d.
/datum/fixer_ledger/proc/report()
	var/datum/mission/fixer_job/job = job_ref?.resolve()
	var/list/lines = list("Crew [crew_reading], scene [scene_reading], port [port_taken ? port_reading : "not taken"], waiting [pending()], noise [job ? job.noise() : "?"].")
	lines += length(heard) ? heard : list("Nothing counted.")
	return lines.Join("\n")

#undef FIXER_PORT_SHOOTOUT
#undef FIXER_LEDGER_LINES
