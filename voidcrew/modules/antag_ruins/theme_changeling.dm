/**
 * # The Chrysalis: changeling vestige
 *
 * A medical frigate the hive ate from the inside; what's left of the hive
 * still wants to hear new life. Trials revolve around birth and stolen faces;
 * boons are hive-flesh tricks reimplemented without the changeling datum
 * (cooldowns instead of a chem pool).
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/chrysalis
	name = "the Vestige of Hive Wren"
	desc = "Something wearing a ship doctor's uniform and most of a face. The parts that fit together fit too well. The rest never settled on a shape."
	gender = NEUTER
	outfit_path = /datum/outfit/job/doctor
	appearance_tint = "#d8cfe0"
	trial_types = list(
		/datum/vestige_trial/birth,
		/datum/vestige_trial/faces,
	)
	boon_types = list(
		/datum/vestige_boon/spell/armblade,
		/datum/vestige_boon/spell/armblade/perfected,
		/datum/vestige_boon/spell/fleshmend,
		/datum/vestige_boon/spell/fleshmend/deep,
	)
	idle_lines = list(
		"We were a crew of thirty. Then a crew of one. The arithmetic of it still delights us.",
		"You wear one face your whole life and call US the horror.",
		"The hive is quiet now. Help us remember the noise.",
		"Flesh remembers everything. Yours could too, if you let it.",
	)
	accept_line = "Yes. Yes-yes-yes. Go."
	busy_line = "One hunger at a time."
	fulfilled_line = "We've already sung together. Let the others have their turn."
	renounce_line = "The flesh forgets you. It won't offer so kindly next time."
	claim_line = "Take-take-take. THEN we talk about more."
	exhausted_line = "We've folded everything we remember into you. There's nothing left."
	remember_line = "New skin! Same song. We remember every note we taught you."

// ===== TRIAL OF BIRTH =====

/datum/vestige_trial/birth
	name = "Trial of Birth"
	desc = "Take the egg and plant it in the skull of a dead humanoid. Then guard the body for three minutes while the child wakes up. The corpse won't lie quietly about it."
	/// Whether the egg has been sown and is incubating
	var/incubating = FALSE

/datum/vestige_trial/birth/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_egg(get_turf(user)))
	to_chat(user, span_notice("The egg settles into your palm, warm and wrong."))

/datum/vestige_trial/birth/get_progress_text()
	return incubating ? "The child is stirring. Guard the body until it wakes." : "The egg is asleep. It needs a cradle - the skull of a dead humanoid."

/obj/item/vestige_egg
	name = "chrysalis egg"
	desc = "A glistening ovoid of meat that is only pretending to sleep."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "innards"
	w_class = WEIGHT_CLASS_SMALL
	/// Mind of whoever sowed the egg (credited when the child wakes)
	var/datum/mind/sower
	/// The corpse this egg is incubating in, once sown
	var/mob/living/carbon/human/cradle
	/// When the current sowing is due to hatch (stale timers from re-sowings check against this)
	var/hatch_at = 0

/obj/item/vestige_egg/Destroy()
	sower = null
	cradle = null
	return ..()

/obj/item/vestige_egg/examine(mob/user)
	. = ..()
	. += span_notice("Use it on a dead humanoid and it burrows in and starts waking up. It needs [DisplayTimeText(VESTIGE_EGG_INCUBATION)] in the body, and the body makes noise the whole time.")

/obj/item/vestige_egg/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ishuman(target))
		return ..()
	if(target.stat != DEAD)
		balloon_alert(user, "the cradle must be dead!")
		return
	user.visible_message(
		span_warning("[user] presses [src] against [target]'s head..."),
		span_notice("You press [src] against [target]'s head and it begins to burrow."),
	)
	if(!do_after(user, 5 SECONDS, target = target))
		return
	if(target.stat != DEAD || !user.is_holding(src))
		return
	sow(target, user)

/obj/item/vestige_egg/proc/sow(mob/living/carbon/human/target, mob/living/user)
	sower = user?.mind
	cradle = target
	hatch_at = world.time + VESTIGE_EGG_INCUBATION
	forceMove(target)
	target.visible_message(span_danger("[src] burrows into [target]'s skull!"))
	playsound(target, 'sound/effects/magic/demon_consume.ogg', 40, TRUE)
	var/datum/vestige_trial/birth/trial = get_sower_trial()
	if(trial)
		trial.incubating = TRUE
		trial.refresh_tracker()
	// The incubation is loud on purpose: warding the body IS the trial
	addtimer(CALLBACK(src, PROC_REF(twitch)), VESTIGE_EGG_INCUBATION / 3)
	addtimer(CALLBACK(src, PROC_REF(twitch)), (VESTIGE_EGG_INCUBATION / 3) * 2)
	addtimer(CALLBACK(src, PROC_REF(hatch)), VESTIGE_EGG_INCUBATION)

/obj/item/vestige_egg/proc/twitch()
	if(cradle && loc == cradle)
		cradle.visible_message(span_warning("[cradle] twitches."))

/obj/item/vestige_egg/proc/hatch()
	if(QDELETED(src) || world.time < hatch_at)
		return
	// Pulled from its cradle mid-incubation: goes dormant, can be re-sown
	if(!cradle || QDELETED(cradle) || loc != cradle)
		visible_message(span_warning("[src] shudders once and goes still."))
		var/datum/vestige_trial/birth/cold_trial = get_sower_trial()
		if(cold_trial)
			cold_trial.incubating = FALSE
			cold_trial.refresh_tracker()
		cradle = null
		return
	var/turf/burst_turf = get_turf(cradle)
	cradle.visible_message(span_bolddanger("[cradle]'s skull splits open and something slick pulls itself out!"))
	playsound(burst_turf, 'sound/effects/magic/demon_consume.ogg', 60, TRUE)
	cradle.apply_damage(60, BRUTE, BODY_ZONE_HEAD)
	forceMove(burst_turf)
	new /mob/living/basic/headslug(burst_turf)
	var/datum/vestige_trial/birth/trial = get_sower_trial()
	if(trial)
		trial.complete()
	qdel(src)

/// The sower's active birth trial, if they still have one
/obj/item/vestige_egg/proc/get_sower_trial()
	var/datum/vestige_trial/birth/trial = sower?.active_vestige_trial
	if(istype(trial))
		return trial
	return null

// ===== TRIAL OF FACES =====

/datum/vestige_trial/faces
	name = "Trial of Faces"
	// Keep the numbers in sync with VESTIGE_FACES_SAMPLES_NEEDED / _LIVING_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Our proboscis, on loan. Let it taste five different faces, at least two of them still alive. The dead hold still. The living remember you."
	/// Assoc list of unique enzymes already tasted
	var/list/sampled = list()
	/// How many samples came from living targets
	var/living_samples = 0
	/// The loaned kit item, reclaimed (deleted) the moment the pact ends
	var/obj/item/vestige_proboscis/proboscis

/datum/vestige_trial/faces/on_accepted(mob/living/user)
	proboscis = hand_over(user, new /obj/item/vestige_proboscis(get_turf(user)))

/datum/vestige_trial/faces/Destroy()
	QDEL_NULL(proboscis)
	return ..()

/datum/vestige_trial/faces/get_progress_text()
	return "[length(sampled)]/[VESTIGE_FACES_SAMPLES_NEEDED] faces tasted; [min(living_samples, VESTIGE_FACES_LIVING_NEEDED)]/[VESTIGE_FACES_LIVING_NEEDED] living."

/// Returns TRUE if this was a new face. May complete (and delete) the trial.
/datum/vestige_trial/faces/proc/add_sample(mob/living/carbon/human/target)
	var/key = target.dna?.unique_enzymes
	if(!key || sampled[key])
		return FALSE
	sampled[key] = TRUE
	if(target.stat != DEAD)
		living_samples++
	refresh_tracker()
	if(length(sampled) >= VESTIGE_FACES_SAMPLES_NEEDED && living_samples >= VESTIGE_FACES_LIVING_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_proboscis
	name = "borrowed proboscis"
	desc = "A coil of somebody else's flesh that twitches toward faces."
	icon = 'icons/obj/weapons/changeling_items.dmi'
	icon_state = "tentacle"
	w_class = WEIGHT_CLASS_SMALL
	force = 0

/obj/item/vestige_proboscis/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ishuman(target))
		return ..()
	var/datum/vestige_trial/faces/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "it lies limp in your grip!")
		return
	var/mob/living/carbon/human/victim = target
	// The living get counterplay: a visible channel before the taste lands
	if(victim.stat != DEAD)
		to_chat(victim, span_userdanger("[user] presses something fleshy against your skin!"))
	if(!do_after(user, 2 SECONDS, target = victim))
		return
	if(!user.is_holding(src))
		return
	// Re-resolve; the pact may have been renounced mid-channel
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "it lies limp in your grip!")
		return
	var/was_alive = victim.stat != DEAD
	if(!trial.add_sample(victim))
		balloon_alert(user, "already tasted!")
		return
	balloon_alert(user, "tasted")
	playsound(src, 'sound/effects/magic/enter_blood.ogg', 30, TRUE)
	if(was_alive)
		victim.apply_damage(10, STAMINA)
		to_chat(victim, span_danger("A needle-sharp sting! Something just took a taste of you."))

// ===== BOONS =====

/datum/vestige_boon/spell/armblade
	name = "Armblade"
	desc = "Reshape your arm into a blade of bone and flesh, and fold it away when you are done with it."
	grant_text = "Your right arm itches, deep in the bone. There's something new folded in there."
	spell_type = /datum/action/cooldown/spell/vestige_armblade

/datum/vestige_boon/spell/armblade/perfected
	name = "Perfected Armblade"
	desc = "A longer, denser blade that cuts through armor, and it forms a lot faster than the first one."
	grant_text = "The thing folded into your arm reshapes itself one final time. This time it gets it right."
	upgrades_from = /datum/vestige_boon/spell/armblade
	spell_type = /datum/action/cooldown/spell/vestige_armblade/perfected

/datum/vestige_boon/spell/fleshmend
	name = "Fleshmend"
	desc = "Knit your wounds closed. Useless while you are on fire."
	grant_text = "Your flesh learns the old hive trick of forgetting its injuries."
	spell_type = /datum/action/cooldown/spell/vestige_fleshmend

/datum/vestige_boon/spell/fleshmend/deep
	name = "Deep Fleshmend"
	desc = "The same mending, ready twice as often. Still useless while you are on fire."
	grant_text = "The hive's trick sinks deeper, past flesh and into the bone."
	upgrades_from = /datum/vestige_boon/spell/fleshmend
	spell_type = /datum/action/cooldown/spell/vestige_fleshmend/deep

/datum/action/cooldown/spell/vestige_armblade
	name = "Form Armblade"
	desc = "Turn your arm into a blade of bone and flesh. Use again to put it away."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "armblade"
	school = SCHOOL_TRANSMUTATION
	cooldown_time = 10 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// The blade this spell forms
	var/blade_type = /obj/item/melee/arm_blade

/datum/action/cooldown/spell/vestige_armblade/perfected
	name = "Form Perfected Armblade"
	desc = "Turn your arm into a stronger blade of bone and flesh. Use again to put it away."
	cooldown_time = 6 SECONDS
	blade_type = /obj/item/melee/arm_blade/vestige_perfected

/obj/item/melee/arm_blade/vestige_perfected
	name = "perfected arm blade"
	desc = "A grotesque blade of bone and flesh, refined by a dead hive into something better than the living ones ever managed."
	force = 30
	armour_penetration = 20

/datum/action/cooldown/spell/vestige_armblade/is_valid_target(atom/cast_on)
	return iscarbon(cast_on)

// The cancel lives here: no blade to fold and no hand to grow one in means the
// cast never happens and the cooldown is never paid, this fork's Activate()
// ignores cast()'s return value, so an in-cast reset_spell_cooldown() is dead code
/datum/action/cooldown/spell/vestige_armblade/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	var/mob/living/carbon/carbon_cast_on = cast_on
	if(locate(/obj/item/melee/arm_blade) in carbon_cast_on.held_items)
		return
	if(!length(carbon_cast_on.get_empty_held_indexes()))
		carbon_cast_on.balloon_alert(carbon_cast_on, "no free hand!")
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/vestige_armblade/cast(mob/living/carbon/cast_on)
	. = ..()
	var/obj/item/melee/arm_blade/held = locate(/obj/item/melee/arm_blade) in cast_on.held_items
	if(held)
		var/outdated = held.type != blade_type
		qdel(held)
		if(!outdated)
			cast_on.visible_message(
				span_warning("[cast_on]'s blade melts back into [cast_on.p_their()] arm!"),
				span_notice("You fold the blade away."),
			)
			playsound(cast_on, 'sound/effects/splat.ogg', 50, TRUE)
			return
		// An old model from before the upgrade: the blade is NODROP, so an
		// upgrade claimed mid-form must reshape it in place or strand it forever
	// The blade announces its own arrival (arm_blade's Initialize prints the
	// visible message), but it does it silently. The noise is ours to make
	playsound(cast_on, 'sound/effects/blob/blobattack.ogg', 60, TRUE)
	var/obj/item/new_blade = new blade_type(cast_on)
	if(!cast_on.put_in_hands(new_blade))
		if(!QDELETED(new_blade)) // DROPDEL usually beat us to it
			qdel(new_blade)
		cast_on.balloon_alert(cast_on, "no free hand!")

/datum/action/cooldown/spell/vestige_fleshmend
	name = "Fleshmend"
	desc = "Heal your wounds. Won't work while you're on fire."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "fleshmend"
	school = SCHOOL_TRANSMUTATION
	cooldown_time = 2 MINUTES
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE

/datum/action/cooldown/spell/vestige_fleshmend/deep
	name = "Deep Fleshmend"
	cooldown_time = 1 MINUTES

/datum/action/cooldown/spell/vestige_fleshmend/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/living_owner = owner
	if(istype(living_owner) && living_owner.on_fire)
		if(feedback)
			living_owner.balloon_alert(living_owner, "not while burning!")
		return FALSE
	return TRUE

/datum/action/cooldown/spell/vestige_fleshmend/cast(mob/living/cast_on)
	. = ..()
	cast_on.apply_status_effect(/datum/status_effect/fleshmend)
	cast_on.visible_message(
		span_warning("[cast_on]'s wounds begin to close with a wet, roiling sound!"),
		span_notice("Your flesh remembers being whole."),
	)
