// Hyperviolence core: the shared hook every gore part uses to add a line to a hit's message.
// The combined-hit-message part replaces the body of hv_add_hit_line with batching; until
// then each line is shown on its own so every part works standalone.

/// Adds a line ("An artery is torn!") to the combat message of the hit being resolved on src.
/mob/living/proc/hv_add_hit_line(text, severity = HV_LINE_BOLD)
	if(!text)
		return
	var/shown = severity >= HV_LINE_HUGE ? "<b><i>[text]</i></b>" : "<b>[text]</b>"
	visible_message(span_danger(shown), vision_distance = COMBAT_MESSAGE_RANGE)

/// Sprays blood from src toward spray_dir. The blood part replaces this with directional spray
/// decals that paint walls and drench bystanders; the stub uses tg's flying splatter.
/mob/living/proc/hv_blood_spray(spray_dir, strength = 3)
	return

/mob/living/carbon/hv_blood_spray(spray_dir, strength = 3)
	spray_blood(spray_dir || pick(GLOB.alldirs), strength)

/// Bursts src's head: it comes apart in gibs and the brain is thrown out intact. burst_dir is the way
/// the shot or blow travelled. The body is in braingut/brain_burst.dm.
/// Returns TRUE if the head was burst.
/mob/living/carbon/proc/hv_burst_head(burst_dir)
	return hv_burst_head_apart(burst_dir)
