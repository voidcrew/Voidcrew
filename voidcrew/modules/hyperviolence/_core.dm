// Hyperviolence core: the shared hook every gore part uses to add a line to a hit's message.
// The combined-hit-message part replaces the body of hv_add_hit_line with batching; until
// then each line is shown on its own so every part works standalone.

/// Adds a line ("An artery is torn!") to the combat message of the hit being resolved on src.
/mob/living/proc/hv_add_hit_line(text, severity = HV_LINE_BOLD)
	if(!text)
		return
	var/shown = severity >= HV_LINE_HUGE ? "<b><i>[text]</i></b>" : "<b>[text]</b>"
	visible_message(span_danger(shown), vision_distance = COMBAT_MESSAGE_RANGE)
