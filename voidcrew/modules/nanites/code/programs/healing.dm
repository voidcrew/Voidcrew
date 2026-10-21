//Programs that heal the host in some way.

/datum/nanite_program/regenerative
	name = "Accelerated Regeneration"
	desc = "The nanites boost the host's natural regeneration, increasing their healing speed. Does not consume nanites if the host is unharmed."
	use_rate = 0.5
	rogue_types = list(/datum/nanite_program/necrotic)

/datum/nanite_program/regenerative/check_conditions()
	if(!host_mob.getBruteLoss() && !host_mob.getFireLoss())
		return FALSE
	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		var/list/parts = C.get_damaged_bodyparts(brute = TRUE, burn = TRUE, required_bodytype = BODYTYPE_ORGANIC)
		if(!parts.len)
			return FALSE
	return ..()

/datum/nanite_program/regenerative/active_effect()
	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		var/list/parts = C.get_damaged_bodyparts(brute = TRUE, burn = TRUE, required_bodytype = BODYTYPE_ORGANIC)
		if(!parts.len)
			return
		for(var/obj/item/bodypart/L in parts)
			if(L.heal_damage(0.5 / parts.len, 0.5 / parts.len, null, BODYTYPE_ORGANIC))
				host_mob.update_damage_overlays()
	else
		host_mob.adjustBruteLoss(-0.5, TRUE)
		host_mob.adjustFireLoss(-0.5, TRUE)

/datum/nanite_program/temperature
	name = "Temperature Adjustment"
	desc = "The nanites adjust the host's internal temperature to an ideal level."
	use_rate = 3.5
	rogue_types = list(/datum/nanite_program/skin_decay)

/datum/nanite_program/temperature/check_conditions()
	if(host_mob.bodytemperature > (host_mob.get_body_temp_normal(apply_change=FALSE) - 30) && host_mob.bodytemperature < (host_mob.get_body_temp_normal(apply_change=FALSE) + 30))
		return FALSE
	return ..()

/datum/nanite_program/temperature/active_effect()
	if(host_mob.bodytemperature > host_mob.get_body_temp_normal(apply_change=FALSE))
		host_mob.adjust_bodytemperature(-40 * TEMPERATURE_DAMAGE_COEFFICIENT, host_mob.get_body_temp_normal(apply_change=FALSE))
	else if(host_mob.bodytemperature < (host_mob.get_body_temp_normal(apply_change=FALSE) + 1))
		host_mob.adjust_bodytemperature(40 * TEMPERATURE_DAMAGE_COEFFICIENT, 0, host_mob.get_body_temp_normal(apply_change=FALSE))

/datum/nanite_program/purging
	name = "Blood Purification"
	desc = "The nanites purge toxins and chemicals from the host's bloodstream."
	use_rate = 1
	rogue_types = list(/datum/nanite_program/suffocating, /datum/nanite_program/necrotic)

/datum/nanite_program/purging/check_conditions()
	var/foreign_reagent = length(host_mob.reagents?.reagent_list)
	if(!host_mob.getToxLoss() && !foreign_reagent)
		return FALSE
	return ..()

/datum/nanite_program/purging/active_effect()
	host_mob.adjustToxLoss(-1)
	for(var/datum/reagent/R in host_mob.reagents.reagent_list)
		host_mob.reagents.remove_reagent(R.type,1)

/datum/nanite_program/brain_heal
	name = "Neural Regeneration"
	desc = "The nanites fix neural connections in the host's brain, reversing brain damage and minor traumas."
	use_rate = 1.5
	rogue_types = list(/datum/nanite_program/brain_decay)

/datum/nanite_program/brain_heal/check_conditions()
	var/problems = FALSE
	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		if(length(C.get_traumas()))
			problems = TRUE
	if(host_mob.get_organ_loss(ORGAN_SLOT_BRAIN) > 0)
		problems = TRUE
	return problems ? ..() : FALSE

/datum/nanite_program/brain_heal/active_effect()
	host_mob.adjustOrganLoss(ORGAN_SLOT_BRAIN, -1)
	if(iscarbon(host_mob) && prob(10))
		var/mob/living/carbon/C = host_mob
		C.cure_trauma_type(resilience = TRAUMA_RESILIENCE_BASIC)

/datum/nanite_program/blood_restoring
	name = "Blood Regeneration"
	desc = "The nanites stimulate and boost blood cell production in the host."
	use_rate = 1
	rogue_types = list(/datum/nanite_program/suffocating)

/datum/nanite_program/blood_restoring/check_conditions()
	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		if(C.blood_volume >= BLOOD_VOLUME_SAFE)
			return FALSE
	else
		return FALSE
	return ..()

/datum/nanite_program/blood_restoring/active_effect()
	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		C.blood_volume += 2

/datum/nanite_program/repairing
	name = "Mechanical Repair"
	desc = "The nanites fix damage in the host's mechanical limbs."
	use_rate = 0.5
	rogue_types = list(/datum/nanite_program/necrotic)

/datum/nanite_program/repairing/check_conditions()
	if(!host_mob.getBruteLoss() && !host_mob.getFireLoss())
		return FALSE

	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		var/list/parts = C.get_damaged_bodyparts(brute = TRUE, burn = TRUE, required_bodytype = BODYTYPE_ROBOTIC)
		if(!parts.len)
			return FALSE
	else
		if(!(host_mob.mob_biotypes & MOB_ROBOTIC))
			return FALSE
	return ..()

/datum/nanite_program/repairing/active_effect(mob/living/M)
	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		var/list/parts = C.get_damaged_bodyparts(brute = TRUE, burn = TRUE, required_bodytype = BODYTYPE_ROBOTIC)
		if(!parts.len)
			return
		var/update = FALSE
		for(var/obj/item/bodypart/L in parts)
			if(L.heal_damage(1.5 / parts.len, 1.5 / parts.len, null, BODYTYPE_ROBOTIC)) //much faster than organic healing
				update = TRUE
		if(update)
			host_mob.update_damage_overlays()
	else
		host_mob.adjustBruteLoss(-1.5, TRUE)
		host_mob.adjustFireLoss(-1.5, TRUE)

/datum/nanite_program/purging_advanced
	name = "Selective Blood Purification"
	desc = "The nanites purge toxins and dangerous chemicals from the host's bloodstream, while ignoring beneficial chemicals. \
			The added processing power required to analyze the chemicals severely increases the nanite consumption rate."
	use_rate = 2
	rogue_types = list(/datum/nanite_program/suffocating, /datum/nanite_program/necrotic)

/datum/nanite_program/purging_advanced/check_conditions()
	var/foreign_reagent = FALSE
	for(var/datum/reagent/toxin/R in host_mob.reagents.reagent_list)
		foreign_reagent = TRUE
		break
	if(!host_mob.getToxLoss() && !foreign_reagent)
		return FALSE
	return ..()

/datum/nanite_program/purging_advanced/active_effect()
	host_mob.adjustToxLoss(-1)
	for(var/datum/reagent/toxin/R in host_mob.reagents.reagent_list)
		host_mob.reagents.remove_reagent(R.type,1)

/datum/nanite_program/regenerative_advanced
	name = "Bio-Reconstruction"
	desc = "The nanites manually repair and replace organic cells, acting much faster than normal regeneration. \
			However, this program cannot detect the difference between harmed and unharmed, causing it to consume nanites even if it has no effect."
	use_rate = 5.5
	rogue_types = list(/datum/nanite_program/suffocating, /datum/nanite_program/necrotic)

/datum/nanite_program/regenerative_advanced/active_effect()
	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		var/list/parts = C.get_damaged_bodyparts(brute = TRUE, burn = TRUE, required_bodytype = BODYTYPE_ORGANIC)
		if(!parts.len)
			return
		var/update = FALSE
		for(var/obj/item/bodypart/L in parts)
			if(L.heal_damage(3 / parts.len, 3 / parts.len, null, BODYTYPE_ORGANIC))
				update = TRUE
		if(update)
			host_mob.update_damage_overlays()
	else
		host_mob.adjustBruteLoss(-3, TRUE)
		host_mob.adjustFireLoss(-3, TRUE)

/datum/nanite_program/brain_heal_advanced
	name = "Neural Reimaging"
	desc = "The nanites are able to backup and restore the host's neural connections, potentially replacing entire chunks of missing or damaged brain matter."
	use_rate = 3
	rogue_types = list(/datum/nanite_program/brain_decay, /datum/nanite_program/brain_misfire)

/datum/nanite_program/brain_heal_advanced/check_conditions()
	var/problems = FALSE
	if(iscarbon(host_mob))
		var/mob/living/carbon/C = host_mob
		if(length(C.get_traumas()))
			problems = TRUE
	if(host_mob.get_organ_loss(ORGAN_SLOT_BRAIN) > 0)
		problems = TRUE
	return problems ? ..() : FALSE

/datum/nanite_program/brain_heal_advanced/active_effect()
	host_mob.adjustOrganLoss(ORGAN_SLOT_BRAIN, -2)
	if(iscarbon(host_mob) && prob(10))
		var/mob/living/carbon/C = host_mob
		C.cure_trauma_type(resilience = TRAUMA_RESILIENCE_LOBOTOMY)

/datum/nanite_program/defib
	name = "Defibrillation"
	desc = "The nanites deliver a pulse to the host's heart."
	can_trigger = TRUE
	trigger_cost = 25
	trigger_cooldown = 120
	rogue_types = list(/datum/nanite_program/shocking)

/datum/nanite_program/defib/on_trigger(comm_message)
	if(!check_revivable())
		return
	var/mob/living/carbon/patient = host_mob
	patient.notify_revival("Your heart is being defibrillated by nanites.")
	if(patient.can_defib() == DEFIB_POSSIBLE)
		patient.grab_ghost()
	addtimer(CALLBACK(src, PROC_REF(zap), WEAKREF(patient)), 5 SECONDS)

/datum/nanite_program/defib/proc/check_revivable()
	if(QDELETED(src) || QDELETED(host_mob) || !iscarbon(host_mob) || host_mob.stat != DEAD)
		return FALSE
	var/mob/living/carbon/C = host_mob
	var/defib_result = C.can_defib()
	return defib_result == DEFIB_POSSIBLE || defib_result == DEFIB_NOGRAB_AGHOST

/datum/nanite_program/defib/proc/zap(datum/weakref/intended_host)
	var/mob/living/carbon/patient = intended_host?.resolve()
	if(QDELETED(patient) || host_mob != patient || !check_revivable() || capacity_blocked())
		return
	playsound(patient, 'sound/machines/defib/defib_charge.ogg', 50, FALSE)
	sleep(3 SECONDS)
	if(QDELETED(src) || QDELETED(patient) || host_mob != patient || capacity_blocked())
		return
	playsound(patient, 'sound/machines/defib/defib_zap.ogg', 50, FALSE)
	if(!defibrillate() && !capacity_blocked())
		playsound(patient, 'sound/machines/defib/defib_failed.ogg', 50, FALSE)

/// Rechecked after the windup, immediately before healing and revival.
/datum/nanite_program/defib/proc/defibrillate()
	if(!check_revivable() || capacity_blocked())
		return FALSE
	var/mob/living/carbon/C = host_mob
	C.heal_for_defib()
	C.set_heartattack(FALSE)
	if(capacity_blocked() || !C.revive_from("nanites"))
		return FALSE
	playsound(C, 'sound/machines/defib/defib_success.ogg', 50, FALSE)
	C.emote("gasp")
	C.set_timed_status_effect(10 SECONDS, /datum/status_effect/jitter, only_if_higher = TRUE)
	SEND_SIGNAL(C, COMSIG_LIVING_MINOR_SHOCK)
	log_game("[C] has been successfully defibrillated by nanites.")
	return TRUE

/// The paddles' damage redistribution, shared with nanites. Leaves unrelated injuries alone.
/mob/living/carbon/proc/heal_for_defib()
	var/target_health = -50
	var/need_mob_update = FALSE
	if(health > target_health)
		need_mob_update += adjustOxyLoss(health - target_health, updating_health = FALSE)
	else
		// Limb damage has different health weights. Heal the same fraction of each
		// limb's injuries, rather than selecting random limbs for an aggregate heal.
		var/overall_damage = maxHealth - health
		if(overall_damage <= 0)
			return
		var/healing_fraction = (target_health - health) / overall_damage
		need_mob_update += adjustOxyLoss(-getOxyLoss() * healing_fraction, updating_health = FALSE)
		need_mob_update += adjustToxLoss(-getToxLoss() * healing_fraction, updating_health = FALSE, forced = TRUE)
		var/brute_fraction = can_adjust_brute_loss(-getBruteLoss() * healing_fraction, FALSE, null) ? healing_fraction : 0
		var/burn_fraction = can_adjust_fire_loss(-getFireLoss() * healing_fraction, FALSE, null) ? healing_fraction : 0
		var/update_overlays = FALSE
		for(var/obj/item/bodypart/part as anything in bodyparts)
			var/brute_heal = part.brute_dam * brute_fraction
			var/burn_heal = part.burn_dam * burn_fraction
			if(!brute_heal && !burn_heal)
				continue
			update_overlays |= part.heal_damage(brute_heal, burn_heal, updating_health = FALSE)
			need_mob_update = TRUE
		if(update_overlays)
			update_damage_overlays()
	if(need_mob_update)
		updatehealth()
