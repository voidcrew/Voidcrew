/obj/item/organ/cyberimp/chest/reviver
	desc = "A small implant with a faint, steady buzz."
	/// Removing an active implant must not erase healing it has already paid for.
	var/resume_healing_cost = FALSE
	/// Invalidates callbacks when an activation ends, including removal and reinsertion.
	var/activation_generation = 0
	var/implantation_generation = 0
	var/heal_generation = 0
	var/heal_timer
	var/heal_due = 0

/// Replaces the upstream activation and healing bodies; do not call their parent.
/obj/item/organ/cyberimp/chest/reviver/try_heal()
	if(QDELETED(src) || QDELETED(owner))
		return
	if(reviving)
		if(owner.stat == CONSCIOUS)
			reviver_cooldown = reviver_time() + revive_cost
			cancel_activation()
			to_chat(owner, span_notice("Your reviver implant falls silent."))
		else if(!heal_timer)
			queue_heal(3 SECONDS)
		return

	if(reviver_time() < reviver_cooldown || HAS_TRAIT(owner, TRAIT_SUICIDED))
		return

	if(owner.stat != CONSCIOUS)
		if(!resume_healing_cost)
			revive_cost = 0
		resume_healing_cost = FALSE
		reviving = TRUE
		activation_generation++
		to_chat(owner, span_notice("You feel a faint buzzing as your reviver implant starts patching your wounds..."))
		defib_cooldown = reviver_time() + 8 SECONDS // 5 seconds after heal proc delay

/// Overridden by the clock-controlled regression scenario.
/obj/item/organ/cyberimp/chest/reviver/proc/reviver_time()
	return world.time

/obj/item/organ/cyberimp/chest/reviver/proc/queue_heal(delay)
	if(heal_timer || !reviving || QDELETED(src) || QDELETED(owner))
		return
	heal_generation++
	heal_due = reviver_time() + delay
	heal_timer = addtimer(CALLBACK(src, PROC_REF(heal), WEAKREF(owner), activation_generation, heal_generation), delay, TIMER_STOPPABLE | TIMER_DELETE_ME)

/obj/item/organ/cyberimp/chest/reviver/proc/cancel_activation()
	activation_generation++
	reviving = FALSE
	heal_due = 0
	if(heal_timer)
		deltimer(heal_timer)
		heal_timer = null

/obj/item/organ/cyberimp/chest/reviver/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	implantation_generation++
	if(reviving)
		resume_healing_cost = TRUE
	cancel_activation()
	return ..()

/obj/item/organ/cyberimp/chest/reviver/Destroy()
	cancel_activation()
	return ..()

/obj/item/organ/cyberimp/chest/reviver/heal(datum/weakref/intended_owner, generation, callback_generation)
	if(QDELETED(src) || QDELETED(owner) || !reviving || generation != activation_generation || callback_generation != heal_generation || intended_owner?.resolve() != owner || !heal_timer)
		return
	var/mob/living/carbon/patient = owner
	deltimer(heal_timer)
	heal_timer = null
	heal_due = 0
	if(owner.stat == CONSCIOUS)
		try_heal()
		return

	/// boolean that stands for if PHYSICAL damage being patched
	var/body_damage_patched = FALSE
	var/need_mob_update = FALSE
	if(patient.getOxyLoss())
		need_mob_update += patient.adjustOxyLoss(-5, updating_health = FALSE)
		revive_cost += 5
	if(patient.getBruteLoss())
		need_mob_update += patient.adjustBruteLoss(-2, updating_health = FALSE)
		revive_cost += 40
		body_damage_patched = TRUE
	if(patient.getFireLoss())
		need_mob_update += patient.adjustFireLoss(-2, updating_health = FALSE)
		revive_cost += 40
		body_damage_patched = TRUE
	if(patient.getToxLoss())
		need_mob_update += patient.adjustToxLoss(-1, updating_health = FALSE)
		revive_cost += 40
	if(need_mob_update)
		patient.updatehealth()
	if(QDELETED(src) || QDELETED(patient) || owner != patient || generation != activation_generation || !reviving)
		return

	if(body_damage_patched && prob(35)) // healing is called every few seconds, not every tick
		patient.visible_message(span_warning("[patient]'s body twitches a bit."), span_notice("You feel like something is patching your injured body."))

	revive_dead()
	// Previously each mob tick queued a delayed heal. Preserve that cadence without overlap.
	if(!QDELETED(src) && !QDELETED(patient) && owner == patient && generation == activation_generation && reviving)
		queue_heal(SSmobs.wait)

/obj/item/organ/cyberimp/chest/reviver/revive_dead()
	if(QDELETED(src) || QDELETED(owner) || !reviving || reviver_time() < defib_cooldown || owner.stat != DEAD || owner.health <= owner.hardcrit_threshold || owner.can_defib() != DEFIB_POSSIBLE)
		return FALSE
	var/mob/living/carbon/patient = owner
	var/healing_cost = revive_cost
	var/generation = activation_generation
	patient.notify_revival("You are being revived by [src]!")
	patient.grab_ghost()
	if(QDELETED(src) || QDELETED(patient) || owner != patient || generation != activation_generation || !reviving)
		return FALSE

	defib_cooldown += 16 SECONDS // delay so it doesn't spam

	patient.set_heartattack(FALSE)
	if(!patient.revive_from("reviver_implant"))
		return FALSE
	if(QDELETED(src))
		return TRUE
	revive_cost = healing_cost + 10 MINUTES
	reviver_cooldown = reviver_time() + revive_cost
	cancel_activation()
	if(!QDELETED(patient))
		patient.visible_message(span_warning("[patient]'s body convulses a bit."))
		playsound(patient, SFX_BODYFALL, 50, TRUE)
		playsound(patient, 'sound/machines/defib/defib_zap.ogg', 75, TRUE, -1)
		patient.emote("gasp")
		patient.set_jitter_if_lower(200 SECONDS)
		SEND_SIGNAL(patient, COMSIG_LIVING_MINOR_SHOCK)
		log_game("[patient] been revived by [src]")
	return TRUE


/obj/item/organ/cyberimp/chest/reviver/undo_heart_attack(datum/weakref/intended_owner, generation)
	var/mob/living/carbon/human/human_owner = intended_owner?.resolve()
	if(QDELETED(src) || QDELETED(human_owner) || owner != human_owner || generation != implantation_generation)
		return
	human_owner.set_heartattack(FALSE)
	if(human_owner.stat == CONSCIOUS)
		to_chat(human_owner, span_notice("You feel your heart beating again!"))


