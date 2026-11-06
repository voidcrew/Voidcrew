/// Backgrounds: owned by P1.

/// TRUE once every standing goal has been judged for the round-end report
GLOBAL_VAR_INIT(backgrounds_judged, FALSE)

/// The common round-end report gains a Backgrounds section
/datum/controller/subsystem/ticker/build_roundend_report()
	judge_background_states()
	. = ..()
	var/section = background_roundend_section()
	if(section)
		. += section

/// Each player's own report says who they were and how it went
/datum/controller/subsystem/ticker/personal_report(client/C, popcount)
	. = ..()
	var/line = background_personal_line(C?.ckey)
	if(line)
		. += "<div class='panel stationborder'>[line]</div>"

/// Settles every standing goal once, just before the report is built, and records the ones still open
/proc/judge_background_states()
	if(GLOB.backgrounds_judged)
		return
	GLOB.backgrounds_judged = TRUE
	for(var/datum/background_state/state as anything in GLOB.background_states)
		if(state.ended)
			continue
		state.get_background()?.judge(state)
		state.record_outcome()

/// The round-end line for one state, or null when it is not listed
/proc/background_state_report_line(datum/background_state/state)
	var/datum/background/background = state?.get_background()
	if(!background || state.key == BACKGROUND_SPACEFARER)
		return null
	var/outcome = background.outcome_line(state)
	return outcome ? "[state.character_name], [background.name]: [outcome]" : "[state.character_name], [background.name]"

/// The Backgrounds section of the common report, one line per state, or null when nobody played one
/proc/background_roundend_section()
	var/list/lines = list()
	for(var/datum/background_state/state as anything in GLOB.background_states)
		var/line = background_state_report_line(state)
		if(line)
			lines += line
	if(!length(lines))
		return null
	return "<div class='panel stationborder'><span class='header'>Backgrounds</span><br>[jointext(lines, "<br>")]</div>"

/// "You were <name>, <background>. <outcome>" for this ckey's latest state, or null
/proc/background_personal_line(player_ckey)
	var/datum/background_state/state = background_latest_state(player_ckey)
	var/datum/background/background = state?.get_background()
	if(!background || state.key == BACKGROUND_SPACEFARER)
		return null
	var/outcome = background.outcome_line(state)
	return "You were [state.character_name], [background.name].[outcome ? " [outcome]" : ""]"
