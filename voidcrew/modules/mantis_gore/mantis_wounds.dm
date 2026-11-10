// The torn limb artery the Mantis line leaves. A sibling of #509's slit throat
// (voidcrew/modules/hyperviolence/crits/crit_wounds.dm): the same clamp, then sutures or cautery, the same
// heavy bleed that never clots, but on an arm or a leg, with no gargle, and it pumps the way the cut went.
// Like the crit wounds, nothing in tg's random wound roll makes it; only the Mantis cut count does.

/datum/wound/slash/flesh/critical/hv_carotid/limb
	name = "Torn Artery"
	undiagnosed_name = "Torn Artery"
	desc = "Patient's limb is cut open through a major artery. Blood loss will kill within minutes."
	treat_text = "Clamp the artery with a hemostat, then suture or cauterize the wound. Transfuse blood."
	treat_text_short = "Clamp with a hemostat, then suture or cauterize."
	simple_desc = "Patient's limb is cut open and pumping blood."
	simple_treat_text = "<b>Clamp</b> the artery with a <b>hemostat</b>, then <b>suture</b> or <b>cauterize</b> it."
	homemade_treat_text = "Tie it off tight above the cut and keep them still."
	examine_desc = "is cut open to the artery, pumping out blood"
	occur_text = "is cut open to the artery"
	initial_flow = 3.5
	/// The way the cut travelled. The artery pumps along it.
	var/spurt_dir
	/// How far each pulse throws blood, in tiles.
	var/spurt_strength = 2
	/// world.time of the next pulse.
	var/next_pulse = 0

/datum/wound/slash/flesh/critical/hv_carotid/limb/wound_injury(datum/wound/old_wound = null, attack_direction = null)
	. = ..()
	spurt_dir = attack_direction || pick(GLOB.alldirs)
	next_pulse = world.time + rand(2 SECONDS, 3 SECONDS)
	// The throat's own pulse throws blood every which way. This one has its own, along the cut.
	next_spurt = INFINITY

// An arm or a leg doesn't drown the voice.
/datum/wound/slash/flesh/critical/hv_carotid/limb/gargle_speech(datum/source, list/message_args)
	return

/datum/wound/slash/flesh/critical/hv_carotid/limb/handle_process(seconds_per_tick, times_fired)
	. = ..()
	if(QDELETED(src) || !victim || !limb || victim.stat == DEAD || HAS_TRAIT(victim, TRAIT_STASIS))
		return
	if(clamped || blood_flow < MANTIS_ARTERY_OPEN_FLOW || world.time < next_pulse || !limb.can_bleed())
		return
	next_pulse = world.time + rand(2 SECONDS, 3 SECONDS)
	pulse()

/// One heartbeat out of the open artery.
/datum/wound/slash/flesh/critical/hv_carotid/limb/proc/pulse()
	mantis_spurt_fx(victim, limb.body_zone, spurt_dir, spurt_strength < 2)

/datum/wound/slash/flesh/critical/hv_carotid/limb/clamp_artery(obj/item/tool, mob/user)
	if(clamped)
		to_chat(user, span_warning("The artery is already clamped."))
		return TRUE
	var/whose = (user == victim) ? "your" : "[victim]'s"
	user.visible_message(span_danger("[user] reaches into the cut on [victim]'s [limb.plaintext_zone] with [tool]..."), span_warning("You reach into the cut on [whose] [limb.plaintext_zone] with [tool]..."))
	if(!do_after(user, base_treat_time * (user == victim ? 2 : 1.5), target = victim, extra_checks = CALLBACK(src, PROC_REF(still_exists))))
		return TRUE
	clamped = TRUE
	user.visible_message(span_green("[user] clamps the artery in [victim]'s [limb.plaintext_zone]."), span_green("You clamp the artery in [whose] [limb.plaintext_zone]."))
	adjust_blood_flow(-2.5)
	return TRUE

/datum/wound_pregen_data/flesh_slash/hv_limb_artery
	abstract = FALSE
	wound_path_to_generate = /datum/wound/slash/flesh/critical/hv_carotid/limb
	wound_series = WOUND_SERIES_HV_LIMB_ARTERY
	required_limb_biostate = (BIO_FLESH|BIO_BLOODED)
	ignore_cannot_bleed = FALSE
	viable_zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	can_be_randomly_generated = FALSE
	threshold_minimum = 80

/**
 * The Scorch's tear: the heat closes part of it as it cuts. It bleeds less, pumps weaker, and clots
 * shut on its own in under a minute instead of killing.
 */
/datum/wound/slash/flesh/critical/hv_carotid/limb/seared
	name = "Seared Artery"
	undiagnosed_name = "Seared Artery"
	desc = "Patient's limb is burned open to a major artery. The heat has partly closed it."
	simple_desc = "Patient's limb is burned open and bleeding."
	examine_desc = "is burned open to the artery, oozing blood"
	occur_text = "is seared open to the artery"
	initial_flow = 2
	clot_rate = 0.04
	spurt_strength = 1

/datum/wound_pregen_data/flesh_slash/hv_limb_artery/seared
	wound_path_to_generate = /datum/wound/slash/flesh/critical/hv_carotid/limb/seared
