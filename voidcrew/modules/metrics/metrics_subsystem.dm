/// Round metrics. Game code queues rows with record_metric() and tally_metric(); this subsystem
/// writes them to the `round_metric` table in batches, off the main tick, once a minute.
/// Nothing on the calling side touches the database, so recording is safe on hot paths.
///
/// Recording switches itself off for the round when metrics are disabled in config, the
/// database is disabled, or the table is missing (run SQL/migrations/voidcrew_round_metrics.sql).
SUBSYSTEM_DEF(metrics)
	name = "Round Metrics"
	wait = 1 MINUTES
	flags = SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT

	/// FALSE once rows can't be stored this round. record_metric() checks this first.
	var/accepting = TRUE
	/// Why recording stopped, for the MC tab.
	var/stop_reason
	/// Rows waiting for the next flush.
	var/list/pending = list()
	/// Running totals from tally_metric(), keyed by their identifying fields. Folded into
	/// pending rows on every fire.
	var/list/tallies = list()
	/// Cap on pending rows. A var so tests can lower it.
	var/max_pending = METRIC_MAX_PENDING
	/// TRUE while a flush is writing.
	var/flushing = FALSE
	/// TRUE once the table has answered a query this round.
	var/table_ready = FALSE
	/// Flushes in a row that failed to write.
	var/failed_flushes = 0
	var/rows_written = 0
	var/rows_dropped = 0

/datum/controller/subsystem/metrics/Initialize()
	if(!CONFIG_GET(flag/round_metrics))
		stop_accepting("switched off in config")
		return SS_INIT_NO_NEED
	if(!CONFIG_GET(flag/sql_enabled))
		stop_accepting("the database is disabled")
		return SS_INIT_NO_NEED
	SSticker.OnRoundend(CALLBACK(src, PROC_REF(on_round_end)))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/metrics/stat_entry(msg)
	if(!accepting)
		msg = "Off: [stop_reason]"
	else
		msg = "Queued:[length(pending)] Tallies:[length(tallies)] Written:[rows_written] Dropped:[rows_dropped]"
	return ..()

/datum/controller/subsystem/metrics/fire(resumed)
	if(!accepting)
		return
	fold_tallies()
	if(!length(pending) || flushing)
		return
	INVOKE_ASYNC(src, PROC_REF(flush))

/datum/controller/subsystem/metrics/Shutdown()
	if(!accepting || flushing)
		return
	fold_tallies()
	// Reboot: the world is going away, so a blocking write is fine and nothing else runs after it.
	flush(sync = TRUE)

/datum/controller/subsystem/metrics/proc/on_round_end()
	if(!accepting)
		return
	fold_tallies()
	flush()

/// Stops recording for the rest of the round and frees what was held.
/datum/controller/subsystem/metrics/proc/stop_accepting(reason)
	accepting = FALSE
	stop_reason = reason
	pending = list()
	tallies = list()
	log_world("Round metrics are off this round: [reason].")

/// Queues a finished row. Use record_metric(), which fills the row from its arguments.
/datum/controller/subsystem/metrics/proc/queue_row(list/row)
	pending += list(row)
	var/overflow = length(pending) - max_pending
	if(overflow > 0)
		pending.Cut(1, overflow + 1)
		rows_dropped += overflow

/// Adds to a running total, written once a minute as one row per distinct key.
/datum/controller/subsystem/metrics/proc/add_tally(category, event, ckey, other_ckey, obj/structure/overmap/ship/ship, zone, subject, quantity, points, credits)
	var/list/key_parts = list(category, event, ckey, other_ckey, ship ? REF(ship) : null, zone, subject)
	var/key = jointext(key_parts, "|")
	var/list/tally = tallies[key]
	if(!tally)
		tally = build_row(category, event, ckey, other_ckey, ship, zone, subject, 0, 0, 0, 0, null)
		tallies[key] = tally
	tally["quantity"] += quantity
	tally["points"] += points
	tally["credits"] += credits

/// Moves every running total into the pending rows and starts new totals.
/datum/controller/subsystem/metrics/proc/fold_tallies()
	if(!length(tallies))
		return
	var/now = metric_round_seconds()
	for(var/key in tallies)
		var/list/row = tallies[key]
		row["round_seconds"] = now
		queue_row(row)
	tallies = list()

/// Builds a row in the table's column layout. Strings are cut to their column widths.
/datum/controller/subsystem/metrics/proc/build_row(category, event, ckey, other_ckey, obj/structure/overmap/ship/ship, zone, subject, credits, vouchers, points, quantity, list/details)
	var/list/row = list(
		"round_id" = GLOB.round_id,
		"round_seconds" = metric_round_seconds(),
		"category" = copytext("[category]", 1, 33),
		"event" = copytext("[event]", 1, 65),
		"ckey" = ckey ? copytext(ckey, 1, 33) : null,
		"other_ckey" = other_ckey ? copytext(other_ckey, 1, 33) : null,
		"ship_id" = null,
		"ship_name" = null,
		"ship_class" = null,
		"zone" = zone,
		"subject" = isnull(subject) ? null : copytext("[subject]", 1, 256),
		"credits" = round(credits || 0),
		"vouchers" = round(vouchers || 0),
		"points" = round(points || 0),
		"quantity" = round(quantity || 0),
		"details" = length(details) ? json_encode(details) : null,
	)
	if(ship)
		row["ship_id"] = copytext(metric_ship_id(ship), 1, 65)
		row["ship_name"] = copytext(ship.name, 1, 129)
		row["ship_class"] = copytext(ship.source_template?.name || "[ship.type]", 1, 129)
	return row

/**
 * Writes pending rows. Async callers yield on the query and never block a tick.
 * Rows that fail to write go back in the queue; after METRIC_MAX_FAILED_FLUSHES failures in a
 * row they are dropped, so a bad statement can't hold memory forever.
 */
/datum/controller/subsystem/metrics/proc/flush(sync = FALSE)
	if(flushing || !length(pending) || !SSdbcore.IsConnected())
		return
	flushing = TRUE
	if(!table_ready && !check_table(sync))
		flushing = FALSE
		return
	var/list/rows = pending
	pending = list()
	var/table = format_table_name("round_metric")
	var/list/special_columns = list("datetime" = "NOW()")
	var/list/unsent = list()
	for(var/start in 1 to length(rows) step METRIC_BATCH_SIZE)
		var/list/batch = rows.Copy(start, min(start + METRIC_BATCH_SIZE, length(rows) + 1))
		if(length(unsent))
			unsent += batch
			continue
		if(SSdbcore.MassInsert(table, batch, ignore_errors = TRUE, async = !sync, special_columns = special_columns))
			rows_written += length(batch)
		else
			unsent += batch
	if(length(unsent))
		failed_flushes++
		if(failed_flushes >= METRIC_MAX_FAILED_FLUSHES)
			rows_dropped += length(unsent)
			failed_flushes = 0
			log_world("Round metrics dropped [length(unsent)] rows after repeated write failures.")
		else
			pending = unsent + pending
			var/overflow = length(pending) - max_pending
			if(overflow > 0)
				pending.Cut(1, overflow + 1)
				rows_dropped += overflow
	else
		failed_flushes = 0
	flushing = FALSE

/// Confirms the table exists. A missing table turns recording off for the round.
/datum/controller/subsystem/metrics/proc/check_table(sync = FALSE)
	var/datum/db_query/probe = SSdbcore.NewQuery("SELECT 1 FROM [format_table_name("round_metric")] LIMIT 1")
	var/worked = probe.Execute(async = !sync, log_error = FALSE)
	var/error = probe.ErrorMsg()
	qdel(probe)
	if(worked)
		table_ready = TRUE
		return TRUE
	if(findtext(error, "doesn't exist"))
		stop_accepting("the round_metric table is missing, run SQL/migrations/voidcrew_round_metrics.sql")
	return FALSE
