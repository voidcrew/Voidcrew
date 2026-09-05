/**
 * # The Wake: revenant vestige
 *
 * A hospice barge whose every passenger died on the same night, and something
 * stayed behind to grieve them. Trials are acts of mourning: gathering last
 * breaths, keeping an unbroken vigil, sitting with the badly hurt. The
 * revenant's body IS the antag (invisible, phasing, unportable), so every
 * boon here is a local human-castable port:
 * same behavior as upstream, no revenant mob, no essence economy (the
 * upstream spells stack-trace and qdel themselves when granted to a
 * non-revenant, hence the copies). Two upgrade chains, the overload and the
 * mourner's touch, plus a defile port and a short walk behind the veil.
 */

// Tuning constants for the Mourner's ports (file-local, #undef at bottom)
/// Body heat (K) one Mourner's Touch pours out of a victim
#define VESTIGE_MOURNING_CHILL 65
/// The touch never chills a victim below this, a frozen witness learns nothing
#define VESTIGE_MOURNING_CHILL_FLOOR (BODYTEMP_COLD_DAMAGE_LIMIT - 45)
/// Stamina one Mourner's Touch saps
#define VESTIGE_MOURNING_STAMINA 40
/// Last Rites cracks glass in this band, never enough to shatter a healthy pane outright
#define VESTIGE_RITES_WINDOW_DAMAGE_MIN 10
#define VESTIGE_RITES_WINDOW_DAMAGE_MAX 25

// ===== PATRON =====

/mob/living/basic/vestige_patron/mourner
	name = "the Mourner"
	desc = "A gaunt figure in funeral black, sitting beside an empty bed. It has been grieving for a very long time, and it has clearly run out of people to grieve for."
	gender = NEUTER
	outfit_path = /datum/outfit/job/chaplain
	appearance_tint = "#8ea3b0"
	trial_types = list(
		/datum/vestige_trial/last_breath,
		/datum/vestige_trial/true_vigil,
		/datum/vestige_trial/sitters_rounds,
	)
	boon_types = list(
		/datum/vestige_boon/spell/overload_lights,
		/datum/vestige_boon/spell/overload_lights/requiem,
		/datum/vestige_boon/spell/mourning_touch,
		/datum/vestige_boon/spell/mourning_touch/last_breath,
		/datum/vestige_boon/spell/last_rites,
		/datum/vestige_boon/spell/widows_walk,
	)
	idle_lines = list(
		"Forty beds, one night. I sat with every one of them. It didn't help, and I'm still here doing it.",
		"The dying always keep one breath back for the end. Nobody's ever around to hear it.",
		"You smell of the living. Don't apologize. It's almost nostalgic.",
		"The lights flicker in here because I asked them to. Steady light makes people too comfortable.",
		"The medicine was never the point. Staying was. Anyone can light a candle; almost nobody sticks around for the rest of it.",
	)
	accept_line = "Go on, then. Take what the dead were saving. They won't miss it. Probably."
	busy_line = "You're already carrying someone else's grief. One at a time."
	fulfilled_line = "You kept that vigil already. No sense keeping it twice."
	renounce_line = "Put it down now and it comes back heavier later. Your choice."
	claim_line = "You're owed something for that. Take it before you go looking for more trouble."
	exhausted_line = "I've nothing left to give you but the grief itself, and you'll come by that on your own."
	remember_line = "You died. I noticed. I notice all of them. Your things were kept safe at the foot of the bed."

// ===== VIGIL OF THE LAST BREATH =====

/datum/vestige_trial/last_breath
	name = "Vigil of the Last Breath"
	desc = "Take the lantern and gather the last breaths of three substantial dead organic creatures. Carp and larger fauna count, as do human remains; small vermin and machines do not. Hold the lantern to each body until its breath passes. Existing remains are welcome, but each body gives only one breath."
	/// Corpses already drained (weakref -> TRUE), so no body is drunk twice
	var/list/drained = list()

/datum/vestige_trial/last_breath/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_lantern(get_turf(user)))

/datum/vestige_trial/last_breath/get_progress_text()
	return "The lantern holds [length(drained)] of three last breaths. Substantial dead organic fauna count."

/datum/vestige_trial/last_breath/proc/eligible_body(mob/living/corpse)
	return !QDELETED(corpse) && corpse.stat == DEAD && (corpse.mob_biotypes & MOB_ORGANIC) && corpse.maxHealth >= 25

/// May complete (and delete) the trial. Returns FALSE if this corpse was already drained.
/datum/vestige_trial/last_breath/proc/drain(mob/living/corpse)
	if(!eligible_body(corpse))
		return FALSE
	var/datum/weakref/key = WEAKREF(corpse)
	if(drained[key])
		return FALSE
	drained[key] = TRUE
	refresh_tracker()
	if(length(drained) >= 3)
		complete()
	return TRUE

/obj/item/vestige_lantern
	name = "pale lantern"
	desc = "A lantern that doesn't put out any light you could actually read by. Something inside it is breathing in, very slowly, and never out."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "lantern"
	color = "#b8cdd8"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_lantern/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with))
		return NONE
	var/mob/living/corpse = interacting_with
	if(corpse.stat != DEAD)
		balloon_alert(user, "still breathing!")
		return ITEM_INTERACT_BLOCKING
	var/datum/vestige_trial/last_breath/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the lantern stays dark")
		return ITEM_INTERACT_BLOCKING
	if(!trial.eligible_body(corpse))
		balloon_alert(user, "needs substantial organic remains!")
		return ITEM_INTERACT_BLOCKING
	if(trial.drained[WEAKREF(corpse)])
		balloon_alert(user, "already drunk dry!")
		return ITEM_INTERACT_BLOCKING
	corpse.visible_message(span_warning("[user] holds [src] to [corpse]'s lips."))
	if(!do_after(user, 3 SECONDS, corpse))
		return ITEM_INTERACT_BLOCKING
	if(user.mind?.active_vestige_trial != trial || !user.is_holding(src) || !trial.eligible_body(corpse))
		return ITEM_INTERACT_BLOCKING
	if(!trial.drain(corpse))
		return ITEM_INTERACT_BLOCKING
	corpse.visible_message(
		span_danger("[src] flares cold blue, and something leaves [corpse] with a sigh."),
		)
	playsound(corpse, 'sound/effects/ghost2.ogg', 30, TRUE)
	return ITEM_INTERACT_SUCCESS

// ===== THE TRUE VIGIL =====

/datum/vestige_trial/true_vigil
	name = "The True Vigil"
	desc = "Touch the candle to substantial organic remains on open floor. Three mourning rifts will try to drag the body away. Pull the body clear, carry the candle to each rift, and extinguish it while the body is at least three paces from that rift. Each extinguishing takes three seconds; the other rifts keep pulling. Let the body reach a rift and the attempt fails, leaving the remains intact for a retry. Carp and larger fauna are suitable."
	var/obj/item/vestige_candle/candle
	var/mob/living/watched
	var/list/rifts = list()
	var/closed_rifts = 0

/datum/vestige_trial/true_vigil/on_accepted(mob/living/user)
	candle = hand_over(user, new /obj/item/vestige_candle(get_turf(user)))

/datum/vestige_trial/true_vigil/Destroy()
	end_vigil()
	return ..()

/datum/vestige_trial/true_vigil/proc/end_vigil()
	STOP_PROCESSING(SSobj, src)
	QDEL_LIST(rifts)
	rifts = list()
	watched = null
	closed_rifts = 0

/datum/vestige_trial/true_vigil/get_progress_text()
	return watched ? "[closed_rifts] of three mourning rifts closed. Keep the body three paces clear of the rift you are extinguishing." : "Touch the candle to substantial organic remains in an open room."

/datum/vestige_trial/true_vigil/proc/start_vigil(mob/living/body, mob/living/user)
	if(watched || body.stat != DEAD || !(body.mob_biotypes & MOB_ORGANIC) || body.maxHealth < 25 || !isturf(body.loc))
		return FALSE
	var/list/places = list()
	for(var/turf/open/place in view(3, body))
		if(get_dist(place, body) == 3 && !isspaceturf(place) && !place.is_blocked_turf(exclude_mobs = FALSE))
			places += place
	if(length(places) < 3)
		to_chat(user, span_warning("The body needs open floor with at least three clear tiles three paces away."))
		return FALSE
	watched = body
	for(var/index in 1 to 3)
		var/obj/structure/vestige_mourning_rift/rift = new(pick_n_take(places))
		rifts += rift
	START_PROCESSING(SSobj, src)
	refresh_tracker()
	return TRUE

/datum/vestige_trial/true_vigil/process(seconds_per_tick)
	if(!watched || watched.stat != DEAD || !isturf(watched.loc) || !length(rifts))
		end_vigil()
		refresh_tracker()
		return
	var/obj/structure/vestige_mourning_rift/nearest
	for(var/obj/structure/vestige_mourning_rift/rift as anything in rifts)
		if(!nearest || get_dist(watched, rift) < get_dist(watched, nearest))
			nearest = rift
	if(get_dist(watched, nearest) == 0)
		to_chat(owner.current, span_warning("A rift caught the body. The candle closes the torn vigil before it can take the remains. Reposition them and retry."))
		end_vigil()
		refresh_tracker()
		return
	if(world.time < nearest.next_pull)
		return
	for(var/obj/structure/vestige_mourning_rift/rift as anything in rifts)
		rift.next_pull = world.time + 3 SECONDS
	var/turf/destination = get_step_towards(watched, nearest)
	if(isopenturf(destination) && !isspaceturf(destination) && !destination.is_blocked_turf(exclude_mobs = TRUE))
		watched.forceMove(destination)
		to_chat(owner.current, span_warning("The mourning rifts tug [watched] toward [nearest]!"))

/obj/item/vestige_candle
	name = "wake-candle"
	desc = "Touch substantial organic remains to begin. Pull the body away from the rifts, then use this candle on each rift from arm's reach while the body is at least three paces away."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle1_lit"
	w_class = WEIGHT_CLASS_TINY
	color = "#b8cdd8"
	var/working = FALSE

/obj/item/vestige_candle/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/true_vigil/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || trial.candle != src || working || !user.is_holding(src))
		return NONE
	if(isliving(interacting_with))
		if(!trial.start_vigil(interacting_with, user))
			balloon_alert(user, "needs substantial remains and open floor!")
		return ITEM_INTERACT_BLOCKING
	if(!(interacting_with in trial.rifts))
		return NONE
	if(get_dist(trial.watched, interacting_with) < 3)
		balloon_alert(user, "pull the body three paces clear first!")
		return ITEM_INTERACT_BLOCKING
	working = TRUE
	var/finished = do_after(user, 3 SECONDS, target = interacting_with)
	working = FALSE
	if(!finished || user.mind?.active_vestige_trial != trial || !(interacting_with in trial.rifts) || !user.is_holding(src))
		return ITEM_INTERACT_BLOCKING
	if(!trial.watched || get_dist(trial.watched, interacting_with) < 3)
		balloon_alert(user, "the body is too close!")
		return ITEM_INTERACT_BLOCKING
	trial.rifts -= interacting_with
	qdel(interacting_with)
	trial.closed_rifts++
	trial.refresh_tracker()
	if(trial.closed_rifts == 3)
		trial.complete()
	return ITEM_INTERACT_SUCCESS

/obj/structure/vestige_mourning_rift
	name = "mourning rift"
	desc = "A grief that wants the body back. Pull the remains at least three tiles away, then extinguish this with the wake-candle."
	icon = 'icons/obj/antags/cult/rune.dmi'
	icon_state = "1"
	color = "#b8cdd8"
	density = FALSE
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE
	var/next_pull = 0

// ===== THE SITTER'S ROUNDS =====

/datum/vestige_trial/sitters_rounds
	name = "The Sitter's Rounds"
	desc = "Use the cloth in hand to call a stranded patient and unfold a cot on safe floor. Examine and scan them: their injuries vary. Buckle them to the cot, settle their shaking with the cloth, and use the supplied dressings on their actual injuries. The cloth comforts; it does not heal wounds. When they are resting, warm, and have at most ten total injury, use the cloth once more to discharge them. Helpers can treat them; the supplied medicine only works on this patient."
	var/mob/living/carbon/human/vestige_patient/patient
	var/obj/structure/bed/cot

/datum/vestige_trial/sitters_rounds/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_cloth(get_turf(user)))
	hand_over(user, new /obj/item/stack/medical/bruise_pack/vestige_sitter(get_turf(user), 10))
	hand_over(user, new /obj/item/stack/medical/ointment/vestige_sitter(get_turf(user), 10))
	hand_over(user, new /obj/item/healthanalyzer(get_turf(user)))

/datum/vestige_trial/sitters_rounds/Destroy()
	patient = null
	cot = null
	return ..()

/datum/vestige_trial/sitters_rounds/get_progress_text()
	if(!patient)
		return "Use the cloth in hand on safe floor to call the patient and cot."
	return "Patient injury: [round(patient.getBruteLoss())] brute, [round(patient.getFireLoss())] burn. Resting: [patient.buckled == cot ? "yes" : "no"]. Settle their shaking, treat the injuries, then use the cloth to discharge."

/datum/vestige_trial/sitters_rounds/proc/call_patient(mob/living/user)
	if(patient)
		to_chat(user, span_notice("Your patient is already here. The pact tracker can restart the case if they were lost."))
		return
	var/turf/open/here = get_turf(user)
	if(!isopenturf(here) || isspaceturf(here) || here.return_air()?.return_pressure() < 80)
		to_chat(user, span_warning("The patient needs a pressurized room."))
		return
	cot = register_loan(new /obj/structure/bed/vestige_patient_cot(here))
	patient = register_loan(new /mob/living/carbon/human/vestige_patient(here))
	patient.caregiver = owner
	var/bruised_zone = pick(BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
	var/burnt_zone = pick(BODY_ZONE_HEAD, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	patient.apply_damage(rand(25, 35), BRUTE, bruised_zone, wound_bonus = CANT_WOUND)
	patient.apply_damage(rand(25, 35), BURN, burnt_zone, wound_bonus = CANT_WOUND)
	patient.adjustStaminaLoss(60)
	patient.adjust_jitter(1 MINUTES)
	patient.set_resting(TRUE)
	to_chat(user, span_notice("The Wake's patient folds out of the cloth beside a cot. Scan their injuries, buckle them in, and settle their shaking."))
	refresh_tracker()

/datum/vestige_trial/sitters_rounds/proc/ready_for_discharge()
	if(!patient || patient.stat == DEAD || patient.buckled != cot || !patient.comforted)
		return FALSE
	return patient.getBruteLoss() + patient.getFireLoss() + patient.getToxLoss() + patient.getOxyLoss() <= 10 && patient.bodytemperature >= BODYTEMP_COLD_DAMAGE_LIMIT && patient.bodytemperature <= BODYTEMP_HEAT_DAMAGE_LIMIT

/mob/living/carbon/human/vestige_patient
	name = "stranded patient"
	real_name = "stranded patient"
	var/datum/mind/caregiver
	var/comforted = FALSE

/mob/living/carbon/human/vestige_patient/examine(mob/user)
	. = ..()
	. += span_notice("A Wake patient awaiting care. A health analyzer identifies the injuries; a cot and the sitter's cloth help them rest. Dressings treat their actual body parts.")

/obj/structure/bed/vestige_patient_cot
	name = "Wake cot"
	can_deconstruct = FALSE
	build_stack_amount = 0

/obj/item/stack/medical/bruise_pack/vestige_sitter
	name = "Wake bruise dressings"
	desc = "Dressings bound to the Wake's stranded patient. Their medicine evaporates on anyone else."

/obj/item/stack/medical/bruise_pack/vestige_sitter/try_heal_checks(mob/living/patient, mob/living/user, healed_zone, silent = FALSE)
	if(!istype(patient, /mob/living/carbon/human/vestige_patient))
		return FALSE
	var/mob/living/carbon/human/vestige_patient/subject = patient
	var/datum/vestige_trial/sitters_rounds/trial = subject.caregiver?.active_vestige_trial
	if(!istype(trial) || trial.patient != patient)
		return FALSE
	return ..()

/obj/item/stack/medical/ointment/vestige_sitter
	name = "Wake burn dressings"
	desc = "Dressings bound to the Wake's stranded patient. Their medicine evaporates on anyone else."

/obj/item/stack/medical/ointment/vestige_sitter/try_heal_checks(mob/living/patient, mob/living/user, healed_zone, silent = FALSE)
	if(!istype(patient, /mob/living/carbon/human/vestige_patient))
		return FALSE
	var/mob/living/carbon/human/vestige_patient/subject = patient
	var/datum/vestige_trial/sitters_rounds/trial = subject.caregiver?.active_vestige_trial
	if(!istype(trial) || trial.patient != patient)
		return FALSE
	return ..()

/obj/item/vestige_cloth
	name = "sitter's cloth"
	desc = "Use in hand to call the Wake's patient and cot. Use on the patient to comfort them, then again after treatment to discharge them."
	icon = 'icons/obj/toys/toy.dmi'
	icon_state = "rag"
	w_class = WEIGHT_CLASS_TINY
	color = "#b8cdd8"
	var/working = FALSE

/obj/item/vestige_cloth/attack_self(mob/living/user, modifiers)
	var/datum/vestige_trial/sitters_rounds/trial = user.mind?.active_vestige_trial
	if(istype(trial))
		trial.call_patient(user)
	return TRUE

/obj/item/vestige_cloth/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/datum/vestige_trial/sitters_rounds/trial = user.mind?.active_vestige_trial
	if(!istype(trial) || interacting_with != trial.patient || !trial.patient || working)
		return NONE
	var/mob/living/carbon/human/vestige_patient/patient = trial.patient
	if(patient.stat == DEAD || patient.buckled != trial.cot)
		balloon_alert(user, "they need to rest alive on the cot!")
		return ITEM_INTERACT_BLOCKING
	working = TRUE
	var/finished = do_after(user, 3 SECONDS, target = patient)
	working = FALSE
	if(!finished || user.mind?.active_vestige_trial != trial || !user.is_holding(src) || patient.stat == DEAD || patient.buckled != trial.cot)
		return ITEM_INTERACT_BLOCKING
	patient.comforted = TRUE
	patient.adjustStaminaLoss(-60)
	patient.adjust_jitter(-1 MINUTES)
	if(trial.ready_for_discharge())
		patient.visible_message(span_notice("[patient] relaxes. The Wake has a bed ready for them now."))
		trial.complete()
	else
		to_chat(user, span_notice("Their shaking settles. The cloth cannot close their injuries: examine or scan them and apply the appropriate dressings."))
		trial.refresh_tracker()
	return ITEM_INTERACT_SUCCESS

/datum/mood_event/vestige_tended
	description = "Someone stayed until the shaking stopped."
	mood_change = 4
	timeout = 5 MINUTES

// ===== BOONS =====

/datum/vestige_boon/spell/overload_lights
	name = "Overload Lights"
	desc = "Overload every powered light around you. They flare up, spark, and shock anyone standing close to them."
	grant_text = "The nearest light fixture dims for a second."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_overload

/datum/vestige_boon/spell/overload_lights/requiem
	name = "Extinguish the Lie"
	desc = "The same overload, but it comes back faster, and every light it blows stays dark until someone fits a new tube."
	grant_text = "The nearest light fixture goes out entirely, and stays out."
	upgrades_from = /datum/vestige_boon/spell/overload_lights
	spell_type = /datum/action/cooldown/spell/aoe/vestige_overload/requiem

/datum/vestige_boon/spell/mourning_touch
	name = "Mourner's Touch"
	desc = "Touch a living person with a bare palm to chill them to the bone and take the strength out of their legs. They warm back up on their own."
	grant_text = "Your palm goes cold, and stays cold."
	spell_type = /datum/action/cooldown/spell/touch/vestige_mourning_touch

/datum/vestige_boon/spell/mourning_touch/last_breath
	name = "Steal the Last Breath"
	desc = "The same touch, and it takes the breath they were saving with it. They're left gasping and unable to make a sound for a few seconds."
	grant_text = "Something settles into your palm alongside the cold, and holds its breath."
	upgrades_from = /datum/vestige_boon/spell/mourning_touch
	spell_type = /datum/action/cooldown/spell/touch/vestige_mourning_touch/last_breath

/datum/vestige_boon/spell/last_rites
	name = "Last Rites"
	desc = "Trash the mood of a whole room at once. Cabinets and morgue trays swing open, glass cracks, floor tiles pop loose and every light flickers. Nothing is actually destroyed. It just all looks terrible."
	grant_text = "Somewhere nearby, a cabinet swings quietly open on its own."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_last_rites

/datum/vestige_boon/spell/widows_walk
	name = "Widow's Walk"
	desc = "Phase out of the world and walk through walls. You can only start the walk standing within arm's reach of a corpse, holy ground blocks it, and coming back is slow and loud."
	grant_text = "For a second you can't feel the floor under you at all."
	spell_type = /datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk

/**
 * The revenant's overload-lights curse, ported for a human caster. Local copy
 * of /datum/action/cooldown/spell/aoe/revenant/overload's cast behavior: the
 * upstream spell stack-traces and qdels itself in New() for any non-revenant
 * owner and spends essence in before_cast, so it can't be granted directly.
 */
/datum/action/cooldown/spell/aoe/vestige_overload
	name = "Overcharge the Lights"
	desc = "Overload every light nearby, making them flare and shock anyone standing close."
	button_icon = 'icons/mob/actions/actions_revenant.dmi'
	button_icon_state = "overload_lights"
	background_icon_state = "bg_revenant"
	overlay_icon_state = "bg_revenant_border"
	cooldown_time = 45 SECONDS
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE_HOLY
	aoe_radius = 5
	/// The range the shocks from the lights reach
	var/shock_range = 2
	/// The damage the shocks from the lights do
	var/shock_damage = 10

/datum/action/cooldown/spell/aoe/vestige_overload/get_things_to_cast_on(atom/center)
	return RANGE_TURFS(aoe_radius, center)

/datum/action/cooldown/spell/aoe/vestige_overload/cast_on_thing_in_aoe(turf/victim, mob/living/caster)
	for(var/obj/machinery/light/light in victim)
		if(!light.on)
			continue
		light.visible_message(span_boldwarning("[light] suddenly flares brightly and begins to spark!"))
		var/datum/effect_system/spark_spread/light_sparks = new /datum/effect_system/spark_spread()
		light_sparks.set_up(4, 0, light)
		light_sparks.start()
		new /obj/effect/temp_visual/revenant(get_turf(light))
		addtimer(CALLBACK(src, PROC_REF(overload_shock), light, caster), 2 SECONDS)

/datum/action/cooldown/spell/aoe/vestige_overload/proc/overload_shock(obj/machinery/light/to_shock, mob/living/caster)
	if(QDELETED(to_shock))
		return
	flick("[to_shock.base_state]2", to_shock)
	for(var/mob/living/carbon/human/human_mob in view(shock_range, to_shock))
		if(human_mob == caster)
			continue
		to_shock.Beam(human_mob, icon_state = "purple_lightning", time = 0.5 SECONDS)
		if(!human_mob.can_block_magic(antimagic_flags))
			human_mob.electrocute_act(shock_damage, to_shock, flags = SHOCK_NOGLOVES)
		do_sparks(4, FALSE, human_mob)
		playsound(human_mob, 'sound/machines/defib/defib_zap.ogg', 50, TRUE, -1)

/**
 * The overload mastered: the same port with a shorter mourning period, and
 * every light it shocks through is broken afterward (break_light_tube), so
 * the flare leaves honest dark behind. A replacement tube undoes it, the
 * upgrade's twist is darkness, not bigger numbers.
 */
/datum/action/cooldown/spell/aoe/vestige_overload/requiem
	name = "Extinguish the Lie"
	desc = "Overload every light nearby, making them flare and shock anyone standing close. The ones that burst stay dark until someone fits a new tube."
	cooldown_time = 30 SECONDS

/datum/action/cooldown/spell/aoe/vestige_overload/requiem/overload_shock(obj/machinery/light/to_shock, mob/living/caster)
	..()
	if(QDELETED(to_shock))
		return
	to_shock.break_light_tube()

/**
 * A grief-touch in the revenant's register, built on the standard touch-spell
 * chassis (see the shock-touch mutation) rather than on revenant code, the
 * revenant keeps its draining inside the harvest cycle, which can't leave the
 * antag datum. One bare palm, one living victim: a vigil's worth of cold and
 * weariness. The chill obeys a hard floor, so it slows and shakes but never
 * freezer-locks; the victim warms back up on their own.
 */
/datum/action/cooldown/spell/touch/vestige_mourning_touch
	name = "Mourner's Touch"
	desc = "Touch someone bare-handed to drain their stamina and chill them. The cold slows them down, but won't freeze them."
	button_icon = 'icons/mob/actions/actions_revenant.dmi'
	button_icon_state = "blight"
	background_icon_state = "bg_revenant"
	overlay_icon_state = "bg_revenant_border"
	sound = 'sound/effects/ghost2.ogg'
	invocation_type = INVOCATION_NONE
	cooldown_time = 30 SECONDS
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE_HOLY
	hand_path = /obj/item/melee/touch_attack/vestige_mourning
	draw_message = span_notice("Cold gathers in your palm.")
	drop_message = span_notice("You let the borrowed cold seep away.")

/datum/action/cooldown/spell/touch/vestige_mourning_touch/is_valid_target(atom/cast_on)
	return iscarbon(cast_on)

/datum/action/cooldown/spell/touch/vestige_mourning_touch/cast_on_hand_hit(obj/item/melee/touch_attack/hand, mob/living/carbon/victim, mob/living/carbon/caster)
	if(victim.stat == DEAD)
		caster.balloon_alert(caster, "already past grieving!")
		return FALSE
	victim.apply_damage(VESTIGE_MOURNING_STAMINA, STAMINA)
	victim.adjust_bodytemperature(-VESTIGE_MOURNING_CHILL, min_temp = VESTIGE_MOURNING_CHILL_FLOOR)
	victim.visible_message(
		span_danger("[victim] goes grey around the lips as [caster]'s touch pulls the warmth out of [victim.p_them()]!"),
		span_userdanger("[caster]'s touch floods you with cold, and the strength goes out of your legs!"),
	)
	victim.emote("shiver")
	playsound(victim, 'sound/effects/ghost2.ogg', 30, TRUE)
	return TRUE

/obj/item/melee/touch_attack/vestige_mourning
	name = "\improper mourner's touch"
	desc = "A palmful of deathbed cold, looking for somewhere warm to put itself down."
	icon = 'icons/obj/weapons/hand.dmi'
	icon_state = "disintegrate"
	inhand_icon_state = "disintegrate"
	color = "#b8cdd8"

/**
 * The touch mastered: the same cold, and it also takes the breath the victim
 * was keeping for the end, a few missed breaths and a short silence. They
 * keep their legs and their radio keys; they just can't shout about it yet.
 */
/datum/action/cooldown/spell/touch/vestige_mourning_touch/last_breath
	name = "Steal the Last Breath"
	desc = "Touch someone bare-handed to chill them, drop them off their feet, and leave them gasping and unable to speak for a few seconds."
	cooldown_time = 20 SECONDS
	draw_message = span_notice("Cold gathers in your palm, and something in it holds its breath.")

/datum/action/cooldown/spell/touch/vestige_mourning_touch/last_breath/cast_on_hand_hit(obj/item/melee/touch_attack/hand, mob/living/carbon/victim, mob/living/carbon/caster)
	. = ..()
	if(!.)
		return
	victim.losebreath += 4 // a few missed breaths: gasping and a little oxy, not a chokehold
	victim.adjust_silence(8 SECONDS)
	to_chat(victim, span_userdanger("Every bit of air goes out of you at once!"))

/**
 * The revenant's Defile, ported for a human caster and re-fitted for someone
 * who has to live on the ship they cast it in: local copy of
 * /datum/action/cooldown/spell/aoe/revenant/defile's cast behavior, minus the
 * essence economy and the self-reveal. Radius trimmed from 4 to 3, window
 * damage roughly halved, reinforced walls no longer rust, and cursed showers
 * keep their water reclaimers so the blood eventually rinses through.
 * Everything it does is dishevelment: tiles pop loose intact, cabinets open,
 * nothing is destroyed outright.
 */
/datum/action/cooldown/spell/aoe/vestige_last_rites
	name = "Last Rites"
	desc = "Throws the room around: cabinets and morgue trays swing open, glass cracks, floor tiles lift, and every light flickers."
	button_icon = 'icons/mob/actions/actions_revenant.dmi'
	button_icon_state = "defile"
	background_icon_state = "bg_revenant"
	overlay_icon_state = "bg_revenant_border"
	sound = 'sound/effects/ghost2.ogg'
	cooldown_time = 40 SECONDS
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE_HOLY
	aoe_radius = 3

/datum/action/cooldown/spell/aoe/vestige_last_rites/get_things_to_cast_on(atom/center)
	return RANGE_TURFS(aoe_radius, center)

/datum/action/cooldown/spell/aoe/vestige_last_rites/after_cast(atom/cast_on)
	. = ..()
	cast_on.visible_message(
		span_boldwarning("The room shudders like something just walked through it!"),
		span_notice("You let it out, and the room takes it badly."),
	)

/datum/action/cooldown/spell/aoe/vestige_last_rites/cast_on_thing_in_aoe(turf/victim, mob/living/caster)
	for(var/obj/effect/blessing/blessing in victim)
		qdel(blessing)
		new /obj/effect/temp_visual/revenant(victim)
	// Tiles lift loose but survive: dishevelment, not demolition
	if(!isplatingturf(victim) && !istype(victim, /turf/open/floor/engine/cult) && isfloorturf(victim) && prob(10))
		var/turf/open/floor/floor = victim
		if(floor.overfloor_placed && floor.floor_tile)
			new floor.floor_tile(floor)
		floor.broken = 0
		floor.burnt = 0
		floor.make_plating(TRUE)
	if(victim.type == /turf/closed/wall && prob(8) && !HAS_TRAIT(victim, TRAIT_RUSTY))
		new /obj/effect/temp_visual/revenant(victim)
		victim.AddElement(/datum/element/rust)
	for(var/obj/machinery/shower/mourning_shower in victim)
		new /obj/effect/temp_visual/revenant(victim)
		mourning_shower.reagents.remove_all(1, relative = TRUE)
		mourning_shower.reagents.add_reagent(/datum/reagent/blood, initial(mourning_shower.reagent_capacity))
		if(prob(50))
			mourning_shower.intended_on = TRUE
			mourning_shower.update_actually_on(TRUE)
	for(var/obj/effect/decal/cleanable/food/salt/salt in victim)
		new /obj/effect/temp_visual/revenant(victim)
		qdel(salt)
	for(var/obj/structure/closet/closet in victim.contents)
		closet.open()
	for(var/obj/structure/bodycontainer/corpseholder in victim)
		if(corpseholder.connected && corpseholder.connected.loc == corpseholder)
			corpseholder.open()
	for(var/obj/machinery/dna_scannernew/dna in victim)
		dna.open_machine()
	for(var/obj/structure/window/window in victim)
		if(window.get_integrity() > VESTIGE_RITES_WINDOW_DAMAGE_MAX)
			window.take_damage(rand(VESTIGE_RITES_WINDOW_DAMAGE_MIN, VESTIGE_RITES_WINDOW_DAMAGE_MAX))
		if(window.fulltile)
			new /obj/effect/temp_visual/revenant/cracks(window.loc)
	for(var/obj/machinery/light/light in victim)
		light.flicker(20) // spooky

/**
 * A sliver of the revenant's incorporeality, worn secondhand: an ethereal
 * jaunt on the standard wizard chassis (no revenant code involved) with
 * revenant dressing, and the Wake's own gate: the walk only BEGINS within
 * arm's reach of the dead. Every other phase in the module has a gate
 * (darkness, blood pools, glass, ash's short leash); this one's is grief.
 * In exchange the walk itself is generous, five seconds behind the veil,
 * and the slow, audible materialization the jaunt chassis enforces still
 * makes arriving the loud part. Blessed ground blocks the walk, as it should.
 * The gate is checked in can_cast_spell so a refused walk never pays the
 * cooldown; a walker already behind the veil is never gated (belt and
 * suspenders, the ethereal jaunt times out on its own).
 */
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk
	name = "Widow's Walk"
	desc = "Phase out of the world and walk through walls. You have to start next to a corpse, and coming back is slow and loud."
	background_icon_state = "bg_revenant"
	overlay_icon_state = "bg_revenant_border"
	sound = 'sound/effects/ghost2.ogg'
	exit_jaunt_sound = 'sound/effects/ghost2.ogg'
	cooldown_time = 35 SECONDS
	cooldown_reduction_per_rank = 0 SECONDS
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE_HOLY
	jaunt_duration = 5 SECONDS
	jaunt_in_time = 0.6 SECONDS
	jaunt_in_type = /obj/effect/temp_visual/dir_setting/wraith
	jaunt_out_type = /obj/effect/temp_visual/dir_setting/wraith/out

/**
 * The gate moves with the caster, so the button has to be told to re-read it.
 * Action buttons only re-evaluate IsAvailable() when something rebuilds them,
 * and nothing does that for "am I standing next to a corpse", so the button
 * sat bright and ready in an empty corridor and dark next to a body. Every step
 * re-checks it now. A corpse that appears (or is dragged off) while the caster
 * stands still is the one case this misses, and the next step fixes that.
 */
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk/Grant(mob/grant_to)
	. = ..()
	if(owner)
		// override: Grant returns early when re-granted to the same owner, and
		// this line runs anyway. The base uses the same guard for its own hooks
		RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(update_status_on_signal), override = TRUE)

/datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk/Remove(mob/remove_from)
	if(remove_from)
		UnregisterSignal(remove_from, COMSIG_MOVABLE_MOVED)
	return ..()

/datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	if(is_jaunting(owner)) // leaving the veil is never gated
		return TRUE
	for(var/mob/living/departed in range(1, owner))
		if(departed.stat == DEAD)
			return TRUE
	if(feedback)
		to_chat(owner, span_warning("You can only start the walk standing next to a corpse."))
	return FALSE

/datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk/do_steam_effects(turf/loc)
	return

#undef VESTIGE_MOURNING_CHILL
#undef VESTIGE_MOURNING_CHILL_FLOOR
#undef VESTIGE_MOURNING_STAMINA
#undef VESTIGE_RITES_WINDOW_DAMAGE_MIN
#undef VESTIGE_RITES_WINDOW_DAMAGE_MAX
