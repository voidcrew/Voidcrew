/**
 * World-generation timing probes.
 *
 * One probe spans one generation event - a planet build, a ruin stamp, a ship load -
 * and writes a BEGIN line when taken and an END line when released to worldgen.log
 * (declared in code/_globalvars/logging.dm). Every line carries wt=<world.time>, which
 * is column 1 of the perf CSV SStime_track writes every 10 seconds, so generation
 * events can be joined against the time-dilation/cpu curves in perf-*.csv; the
 * tdil/cpu readings on the BEGIN and END lines bracket the event directly.
 *
 * A BEGIN with no matching END means the generating proc runtimed or was killed
 * mid-event - the timestamp marks where it died, the same way the worldgen watchdog
 * reads a wedged queue claim.
 */
/datum/worldgen_probe
	/// Pairing id from GLOB.worldgen_event_seq; the END line references it.
	var/id
	/// Event class: planet-load, planet-build, stage, planet-teardown, ruin, asteroid, ship, ship-npc, template.
	var/event_type
	/// Human-readable name written to both lines (planet/ruin/ship/template name).
	var/label
	/// Probe id of the enclosing event, 0 for top-level.
	var/parent_id
	/// REALTIMEOFDAY at begin, for the duration on the END line.
	var/start_rtod
	/// Time dilation when the event began.
	var/start_tdil

GLOBAL_VAR_INIT(worldgen_event_seq, 0)
GLOBAL_PROTECT(worldgen_event_seq)

/**
 * Begins a worldgen event and writes its BEGIN line. Returns the probe; every exit
 * path of the wrapped code must hand it to worldgen_end().
 *
 * Arguments:
 * * event_type - short class name (planet-load, ruin, asteroid, ship, template, ...)
 * * label - what is being generated, quoted in the log
 * * parent_id - id of the enclosing probe, so nested events (stages of a planet
 *   build, template stamps inside a ruin load) can be attributed to their parent
 */
/proc/worldgen_begin(event_type, label, parent_id = 0)
	var/datum/worldgen_probe/probe = new
	GLOB.worldgen_event_seq += 1
	probe.id = GLOB.worldgen_event_seq
	probe.event_type = event_type
	probe.label = label
	probe.parent_id = parent_id
	probe.start_rtod = REALTIMEOFDAY
	probe.start_tdil = SStime_track ? SStime_track.time_dilation_current : 0
	WRITE_LOG(GLOB.worldgen_log, "BEGIN wt=[world.time] id=[probe.id][parent_id ? " parent=[parent_id]" : ""] type=[event_type] label=\"[label]\" tdil=[round(probe.start_tdil, 0.1)] cpu=[world.cpu]")
	return probe

/**
 * Closes a worldgen event and writes its END line with the duration and end-of-event
 * lag readings. Null-safe: failure paths can end a probe that never began.
 *
 * Arguments:
 * * probe - the probe from worldgen_begin(), qdel'd here
 * * note - optional outcome marker ("failed", "queue-timeout", ...); empty on success
 */
/proc/worldgen_end(datum/worldgen_probe/probe, note = "")
	if(!probe)
		return
	var/duration = (REALTIMEOFDAY - probe.start_rtod) / 10
	var/tdil = SStime_track ? SStime_track.time_dilation_current : 0
	WRITE_LOG(GLOB.worldgen_log, "END wt=[world.time] id=[probe.id] type=[probe.event_type] dur=[round(duration, 0.01)]s tdil=[round(tdil, 0.1)] cpu=[world.cpu] mtick=[MAPTICK_LAST_INTERNAL_TICK_USAGE][note ? " note=\"[note]\"" : ""] label=\"[probe.label]\"")
	qdel(probe)
