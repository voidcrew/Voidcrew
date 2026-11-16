/**
 * Voidcrew: no roundstart threat advisory.
 *
 * Upstream sends a station-wide "Security level elevated" / "Security Report" announcement
 * with the CentCom sound a few minutes in, raises the global security level to blue and
 * prints a threat advisory to every communications console. None of that means anything with
 * no station and no antagonists, so the whole broadcast is dropped.
 *
 * Deliberately no ..(): this replaces the upstream body. The only part kept is the silent
 * station goal roll, because a goal's on_report() is what unlocks its supply crates
 * (DNA vault, shield satellites); see voidcrew/edits/subsystem/station.dm for the goal filter.
 */
/datum/communciations_controller/send_roundstart_report(greenshift)
	if(block_command_report)
		addtimer(CALLBACK(src, PROC_REF(send_roundstart_report), greenshift), 10 SECONDS)
		return

	SSstation.generate_station_goals(CONFIG_GET(number/station_goal_budget))
	for(var/datum/station_goal/station_goal as anything in SSstation.get_station_goals())
		station_goal.on_report()
