/// Called right before the shuttle physically moves - suppress atmosphere checks
/obj/machinery/door/firedoor/proc/on_shuttle_move_start(datum/source, turf/new_turf, rotation, move_mode, obj/docking_port/mobile/moving_dock)
	SIGNAL_HANDLER
	ignore_alarms = TRUE

/// Called after shuttle move completes - re-enable checks and verify atmosphere
/obj/machinery/door/firedoor/proc/on_shuttle_move_complete(datum/source, turf/old_turf)
	SIGNAL_HANDLER
	ignore_alarms = FALSE
	// Re-check atmosphere after it stabilizes to catch any real hazards
	addtimer(CALLBACK(src, PROC_REF(post_shuttle_move_check)), 0.5 SECONDS)

/// Re-evaluate atmospheric conditions after a shuttle move to catch real hazards
/obj/machinery/door/firedoor/proc/post_shuttle_move_check()
	if(QDELETED(src))
		return
	for(var/dir in GLOB.cardinals)
		var/turf/checked_turf = get_step(get_turf(src), dir)
		if(!checked_turf || !isopenturf(checked_turf))
			continue
		process_results(checked_turf)
