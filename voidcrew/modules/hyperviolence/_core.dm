// Hyperviolence core: the shared hooks every gore part uses.
// hv_add_hit_line() (a line added to the combat message of the hit being resolved on a mob) lives
// in hitlines/hit_lines.dm, which batches the lines into the attack message.

/// Sprays blood from src toward spray_dir. The blood part replaces this with directional spray
/// decals that paint walls and drench bystanders; the stub uses tg's flying splatter.
/mob/living/proc/hv_blood_spray(spray_dir, strength = 3)
	return

/mob/living/carbon/hv_blood_spray(spray_dir, strength = 3)
	spray_blood(spray_dir || pick(GLOB.alldirs), strength)

/// Bursts src's head: it comes off in pieces rather than dropping whole. burst_dir is the way the
/// shot or blow travelled. The brain-and-guts part replaces this to fling the brain out intact.
/// Returns TRUE if the head was burst.
/mob/living/carbon/proc/hv_burst_head(burst_dir)
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(!head || !head.can_dismember())
		return FALSE
	hv_blood_spray(burst_dir, 4)
	if(!head.dismember(BRUTE, silent = TRUE))
		return FALSE
	head.drop_organs(null, TRUE)
	qdel(head)
	new /obj/effect/gibspawner/generic(get_turf(src), src)
	hv_add_hit_line("[src]'s head bursts apart!", HV_LINE_HUGE)
	return TRUE
