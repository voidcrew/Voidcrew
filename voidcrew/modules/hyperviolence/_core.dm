// Hyperviolence core: the shared hooks every gore part uses.
// hv_add_hit_line() (a line added to the combat message of the hit being resolved on a mob) lives
// in hitlines/hit_lines.dm, which batches the lines into the attack message.

/// Sprays blood from src toward spray_dir: streaks and a splash on the floor, a smear on the first
/// wall in the way, and anyone standing in the line is drenched. The body lives in the blood part
/// (blood/blood_spray.dm).
/mob/living/proc/hv_blood_spray(spray_dir, strength = 3)
	return hv_blood_throw(spray_dir, strength)

/// Bursts src's head: it comes apart in gibs and the brain is thrown out intact. burst_dir is the way
/// the shot or blow travelled. The body is in braingut/brain_burst.dm.
/// Returns TRUE if the head was burst.
/mob/living/carbon/proc/hv_burst_head(burst_dir)
	return hv_burst_head_apart(burst_dir)
