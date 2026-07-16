/**
 * # The Wake — revenant vestige
 *
 * A hospice barge whose every passenger died on the same night, and something
 * stayed behind to grieve them. Trials are acts of mourning: gathering last
 * breaths, keeping an unbroken vigil, sitting with the badly hurt. The
 * revenant's body IS the antag (invisible, phasing — unportable), so every
 * boon here is a local human-castable port:
 * same behavior as upstream, no revenant mob, no essence economy (the
 * upstream spells stack-trace and qdel themselves when granted to a
 * non-revenant, hence the copies). Two upgrade chains — the overload and the
 * mourner's touch — plus a defile port and a short walk behind the veil.
 */

// Tuning constants for the Mourner's ports (file-local, #undef at bottom)
/// Body heat (K) one Mourner's Touch pours out of a victim
#define VESTIGE_MOURNING_CHILL 65
/// The touch never chills a victim below this — a frozen witness learns nothing
#define VESTIGE_MOURNING_CHILL_FLOOR (BODYTEMP_COLD_DAMAGE_LIMIT - 45)
/// Stamina one Mourner's Touch saps
#define VESTIGE_MOURNING_STAMINA 40
/// Last Rites cracks glass in this band — never enough to shatter a healthy pane outright
#define VESTIGE_RITES_WINDOW_DAMAGE_MIN 10
#define VESTIGE_RITES_WINDOW_DAMAGE_MAX 25

// Tuning constants for the Mourner's trials (file-local, #undef at bottom)
/// How long the True Vigil must stand unbroken (keeper, candle and body all at arm's reach)
#define VESTIGE_TRUE_VIGIL_DURATION (4 MINUTES)
/// Distinct badly hurt people the Sitter's Rounds demands
#define VESTIGE_TENDED_NEEDED 3
/// Total damage, of every kind at once, before someone counts as needing a sitter
#define VESTIGE_TENDED_MIN_DAMAGE 40
/// Stamina damage a sitting soothes away from the patient
#define VESTIGE_TENDED_STAMINA_HEAL 60

// ===== PATRON =====

/mob/living/basic/vestige_patron/mourner
	name = "the Mourner"
	desc = "A gaunt figure in funeral black, seated beside an empty bed. Its grief has outlived everyone it was for, and has had to find new work."
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
		"Forty beds. One night. I sat with each of them, and I was not enough, and here I still am. Grief keeps terrible hours.",
		"The dying save one breath for the end. Nobody hears it. That is what it is FOR.",
		"You smell of the living. Don't apologize — it's almost nostalgic.",
		"The lights in this place flicker because I asked them to. Steady light is a lie told to the frightened.",
		"The work was never the medicine. The work was the staying. Anyone can light a candle. Almost no one stays.",
	)
	accept_line = "Go, then. Gather what the dead were saving. They will not miss it. Probably."
	busy_line = "You already grieve for someone else's cause. One mourning at a time."
	fulfilled_line = "That vigil is kept. It does not need keeping twice."
	renounce_line = "Grief you put down early always finds its way back heavier."
	claim_line = "You are owed a consolation. Take it before you take on more sorrow."
	exhausted_line = "I have nothing left to give but the grief itself, and that one you'll earn on your own."
	remember_line = "You died. I noticed — I notice all of them. What you had gathered was kept safe at the foot of your bed."

// ===== VIGIL OF THE LAST BREATH =====

/datum/vestige_trial/last_breath
	name = "Vigil of the Last Breath"
	// Keep the count in sync with VESTIGE_LANTERN_CORPSES_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the lantern. The dead hold one breath back — the last one, the one nobody hears. Hold the lantern to five different corpses and let it drink what they were saving. They will not miss it. Probably."
	/// Corpses already drained (weakref -> TRUE), so no body is drunk twice
	var/list/drained = list()

/datum/vestige_trial/last_breath/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_lantern(get_turf(user)))

/datum/vestige_trial/last_breath/get_progress_text()
	return "The lantern holds [length(drained)] of [VESTIGE_LANTERN_CORPSES_NEEDED] last breaths."

/// May complete (and delete) the trial. Returns FALSE if this corpse was already drained.
/datum/vestige_trial/last_breath/proc/drain(mob/living/corpse)
	var/datum/weakref/key = WEAKREF(corpse)
	if(drained[key])
		return FALSE
	drained[key] = TRUE
	refresh_tracker()
	if(length(drained) >= VESTIGE_LANTERN_CORPSES_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_lantern
	name = "pale lantern"
	desc = "A lantern that gives no light a living eye can use. Something inside it inhales, very slowly, and never breathes out."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "lantern"
	color = "#b8cdd8"
	w_class = WEIGHT_CLASS_SMALL

/obj/item/vestige_lantern/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ishuman(interacting_with))
		return NONE
	var/mob/living/carbon/human/corpse = interacting_with
	if(corpse.stat != DEAD)
		balloon_alert(user, "still breathing!")
		return ITEM_INTERACT_BLOCKING
	var/datum/vestige_trial/last_breath/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the lantern is dark and disinterested")
		return ITEM_INTERACT_BLOCKING
	if(trial.drained[WEAKREF(corpse)])
		balloon_alert(user, "already drunk dry!")
		return ITEM_INTERACT_BLOCKING
	corpse.visible_message(span_warning("[user] holds [src] to [corpse]'s lips."))
	if(!do_after(user, 3 SECONDS, corpse))
		return ITEM_INTERACT_BLOCKING
	if(!trial.drain(corpse))
		return ITEM_INTERACT_BLOCKING
	corpse.visible_message(
		span_danger("[src] flares a cold blue, and something leaves [corpse] with a sound like a sigh."),
		)
	playsound(corpse, 'sound/effects/ghost2.ogg', 30, TRUE)
	return ITEM_INTERACT_SUCCESS

// ===== THE TRUE VIGIL =====

/datum/vestige_trial/true_vigil
	name = "The True Vigil"
	// Keep the duration in sync with VESTIGE_TRUE_VIGIL_DURATION
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the candle. Find one of the dead — anyone's dead — and light it beside them, and then do the hard part: stay. Four unbroken minutes within arm's reach, and the candle must stand on the floor the whole while. If the flame goes out, you were not truly there. Begin again until you are."
	/// Unbroken vigil time so far (deciseconds), zeroed whenever the flame goes out
	var/kept_time = 0
	/// The loaned kit item, reclaimed (deleted) the moment the pact ends
	var/obj/item/vestige_candle/candle

/datum/vestige_trial/true_vigil/on_accepted(mob/living/user)
	candle = hand_over(user, new /obj/item/vestige_candle(get_turf(user)))
	to_chat(user, span_notice("The candle is cold, and slightly damp, and certain you will not last the vigil."))

/datum/vestige_trial/true_vigil/Destroy()
	QDEL_NULL(candle)
	return ..()

/datum/vestige_trial/true_vigil/get_progress_text()
	return kept_time ? "The vigil stands at [DisplayTimeText(kept_time)] of [DisplayTimeText(VESTIGE_TRUE_VIGIL_DURATION)], unbroken." : "The candle waits to be lit beside one of the dead."

/// Accrues unbroken vigil time. May complete (and delete) the trial.
/datum/vestige_trial/true_vigil/proc/keep(deciseconds)
	kept_time += deciseconds
	refresh_tracker()
	if(kept_time < VESTIGE_TRUE_VIGIL_DURATION)
		return
	candle.visible_message(span_boldnotice("[candle]'s flame stands perfectly still for a moment, then bows out on its own. The vigil is kept."))
	playsound(candle, 'sound/effects/ghost2.ogg', 40, TRUE)
	complete()

/// Zeroes the unbroken time when the flame goes out
/datum/vestige_trial/true_vigil/proc/break_vigil()
	if(!kept_time)
		return
	kept_time = 0
	refresh_tracker()

/obj/item/vestige_candle
	name = "wake-candle"
	desc = "A tallow candle the color of a waiting room. It will not burn for the living — only beside them, for someone who cannot see it anymore."
	icon = 'icons/obj/candle.dmi'
	icon_state = "candle1"
	inhand_icon_state = "candle"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	w_class = WEIGHT_CLASS_TINY
	color = "#b8cdd8"
	/// Mind of the vigil-keeper (the same exception vestige_egg carves out for its sower)
	var/datum/mind/keeper
	/// The body being sat with
	var/mob/living/carbon/human/watched
	/// Whether the flame guttered last tick — one warning tick of grace before it goes out
	var/guttering = FALSE

/obj/item/vestige_candle/Destroy()
	STOP_PROCESSING(SSobj, src)
	keeper = null
	watched = null
	return ..()

/obj/item/vestige_candle/examine(mob/user)
	. = ..()
	. += span_notice("Lit beside a dead humanoid, it begins a vigil: [DisplayTimeText(VESTIGE_TRUE_VIGIL_DURATION)], unbroken, with keeper and candle and body all within arm's reach. It only burns standing on the floor.")

/obj/item/vestige_candle/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ishuman(interacting_with))
		return NONE
	var/mob/living/carbon/human/body = interacting_with
	if(body.stat != DEAD)
		balloon_alert(user, "they can still see it!")
		return ITEM_INTERACT_BLOCKING
	var/datum/vestige_trial/true_vigil/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "the wick refuses to catch!")
		return ITEM_INTERACT_BLOCKING
	if(keeper)
		balloon_alert(user, "already keeping a vigil!")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "cupping the flame...")
	if(!do_after(user, 3 SECONDS, body))
		return ITEM_INTERACT_BLOCKING
	// Re-resolve; the pact may have been renounced mid-lighting
	trial = user.mind?.active_vestige_trial
	if(!istype(trial) || body.stat != DEAD)
		return ITEM_INTERACT_BLOCKING
	plant(user, body)
	return ITEM_INTERACT_SUCCESS

/// Sets the candle down at the body and starts the vigil clock
/obj/item/vestige_candle/proc/plant(mob/living/user, mob/living/carbon/human/body)
	keeper = user.mind
	watched = body
	guttering = FALSE
	forceMove(get_turf(body))
	icon_state = "candle1_lit"
	set_light(2, 0.8, "#b8cdd8", l_on = TRUE)
	playsound(src, 'sound/items/match_strike.ogg', 20, TRUE)
	user.visible_message(
		span_warning("[user] lights a pale candle beside [body] and settles in to keep a vigil."),
		span_notice("The wick catches — a pale, patient flame. Stay within arm's reach of [body]. The flame will know if you leave."),
	)
	START_PROCESSING(SSobj, src)

// A stolen candle is a broken vigil, immediately and audibly
/obj/item/vestige_candle/pickup(mob/user)
	. = ..()
	snuff()

/obj/item/vestige_candle/process(seconds_per_tick)
	var/datum/vestige_trial/true_vigil/trial = keeper?.active_vestige_trial
	if(!istype(trial)) // pact ended out from under us; the trial reclaims the candle on its way out
		snuff()
		return
	if(vigil_holds())
		guttering = FALSE
		if(SPT_PROB(2, seconds_per_tick))
			visible_message(span_notice("[src]'s pale flame bends toward [watched], as if listening."))
		trial.keep(seconds_per_tick * (1 SECONDS)) // may complete the pact, deleting the trial and us with it
		return
	if(!guttering)
		guttering = TRUE
		visible_message(span_warning("[src]'s flame gutters wildly!"))
		if(keeper?.current)
			to_chat(keeper.current, span_warning("The vigil is faltering — the flame needs you within arm's reach of the dead!"))
		return
	snuff()

/// TRUE while every term of the vigil holds: candle standing on the floor, body dead and present, keeper conscious at arm's reach
/obj/item/vestige_candle/proc/vigil_holds()
	if(!isturf(loc))
		return FALSE
	if(QDELETED(watched) || watched.stat != DEAD)
		return FALSE
	var/turf/here = loc
	var/turf/body_turf = get_turf(watched)
	if(!body_turf || body_turf.z != here.z || get_dist(here, body_turf) > 1)
		return FALSE
	var/mob/living/keeper_body = keeper?.current
	if(!istype(keeper_body) || keeper_body.stat != CONSCIOUS)
		return FALSE
	var/turf/keeper_turf = get_turf(keeper_body)
	if(!keeper_turf || keeper_turf.z != here.z || get_dist(here, keeper_turf) > 1)
		return FALSE
	return TRUE

/// Puts the flame out and zeroes the vigil. Safe to call when already out.
/obj/item/vestige_candle/proc/snuff()
	if(!keeper)
		return
	STOP_PROCESSING(SSobj, src)
	if(!QDELETED(watched) && watched.stat != DEAD)
		visible_message(span_notice("[src] goes out on its own, gently. Some vigils end the good way."))
	else
		visible_message(span_warning("[src] goes out."))
		playsound(src, 'sound/effects/extinguish.ogg', 20, TRUE)
	var/datum/vestige_trial/true_vigil/trial = keeper.active_vestige_trial
	if(istype(trial))
		trial.break_vigil()
	keeper = null
	watched = null
	guttering = FALSE
	icon_state = "candle1"
	set_light(l_on = FALSE)

// ===== THE SITTER'S ROUNDS =====

/datum/vestige_trial/sitters_rounds
	name = "The Sitter's Rounds"
	// Keep the numbers in sync with VESTIGE_TENDED_NEEDED / VESTIGE_TENDED_MIN_DAMAGE
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the cloth. Find the hurt — really hurt, the kind who shake — and do what I did for forty beds: kneel, take their hand, and stay until the shaking stops. Three of them, each their own person. Do not promise them it will be all right. Stay anyway."
	/// Patients already sat with (weakref -> TRUE), so the same brow never counts twice
	var/list/tended = list()

/datum/vestige_trial/sitters_rounds/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_cloth(get_turf(user)))

/datum/vestige_trial/sitters_rounds/get_progress_text()
	return "[length(tended)] of [VESTIGE_TENDED_NEEDED] of the hurt have been sat with."

/// May complete (and delete) the trial. Returns FALSE if this patient was already tended.
/datum/vestige_trial/sitters_rounds/proc/tend(mob/living/patient)
	var/datum/weakref/key = WEAKREF(patient)
	if(tended[key])
		return FALSE
	tended[key] = TRUE
	refresh_tracker()
	if(length(tended) >= VESTIGE_TENDED_NEEDED)
		complete()
	return TRUE

/obj/item/vestige_cloth
	name = "sitter's cloth"
	desc = "A square of linen that is always cool and slightly damp. It has wiped a great many brows, and it is not finished."
	icon = 'icons/obj/toys/toy.dmi'
	icon_state = "rag"
	w_class = WEIGHT_CLASS_TINY
	color = "#b8cdd8"

/obj/item/vestige_cloth/examine(mob/user)
	. = ..()
	. += span_notice("Pressed to someone badly hurt and still living, it begins a sitting: kneel with them, hand in hand, until the shaking stops. The same brow never counts twice.")

/obj/item/vestige_cloth/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!ishuman(interacting_with))
		return NONE
	var/mob/living/carbon/human/patient = interacting_with
	var/datum/vestige_trial/sitters_rounds/trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		balloon_alert(user, "just a damp cloth!")
		return ITEM_INTERACT_BLOCKING
	if(patient == user)
		balloon_alert(user, "someone else must sit with you!")
		return ITEM_INTERACT_BLOCKING
	if(patient.stat == DEAD)
		balloon_alert(user, "past comforting!")
		return ITEM_INTERACT_BLOCKING
	if(get_suffering(patient) < VESTIGE_TENDED_MIN_DAMAGE)
		balloon_alert(user, "not shaken enough to need a sitter!")
		return ITEM_INTERACT_BLOCKING
	if(trial.tended[WEAKREF(patient)])
		balloon_alert(user, "already sat with!")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_warning("[user] kneels beside [patient], presses a cool cloth to [patient.p_their()] brow, and takes [patient.p_their()] hand."),
		span_notice("You kneel, press the cloth to [patient]'s brow, and take [patient.p_their()] hand. Now stay."),
	)
	to_chat(patient, span_notice("Someone is holding your hand. They do not tell you it will be all right. They stay anyway."))
	if(!do_after(user, 8 SECONDS, target = patient))
		balloon_alert(user, "the sitting was cut short!")
		return ITEM_INTERACT_BLOCKING
	// Re-resolve; the pact may have been renounced mid-sitting
	trial = user.mind?.active_vestige_trial
	if(!istype(trial))
		return ITEM_INTERACT_BLOCKING
	if(patient.stat == DEAD) // they slipped away mid-sitting; that grief belongs to the lantern now
		balloon_alert(user, "they slipped away...")
		return ITEM_INTERACT_BLOCKING
	patient.adjustStaminaLoss(-VESTIGE_TENDED_STAMINA_HEAL)
	patient.adjust_jitter(-1 MINUTES)
	patient.adjust_dizzy(-1 MINUTES)
	patient.add_mood_event("vestige_tended", /datum/mood_event/vestige_tended)
	patient.visible_message(
		span_notice("[patient]'s shaking slows, and stops."),
		span_boldnotice("The shaking stops. Not because it will be all right — because someone stayed."),
	)
	playsound(patient, 'sound/effects/ghost2.ogg', 20, TRUE)
	trial.tend(patient) // may complete (and delete) the trial — nothing touches it after this
	return ITEM_INTERACT_SUCCESS

/// Everything that hurts, totaled — the cloth answers to pain of every kind
/obj/item/vestige_cloth/proc/get_suffering(mob/living/patient)
	return patient.getBruteLoss() + patient.getFireLoss() + patient.getToxLoss() + patient.getOxyLoss() + patient.getStaminaLoss()

/datum/mood_event/vestige_tended
	description = "Someone stayed until the shaking stopped."
	mood_change = 4
	timeout = 5 MINUTES

// ===== BOONS =====

/datum/vestige_boon/spell/overload_lights
	name = "Overload Lights"
	desc = "Push your grief into every powered light nearby until they flare, burst, and bite anyone standing close. Steady light is a lie told to the frightened."
	grant_text = "The nearest light fixture dims, deferentially."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_overload

/datum/vestige_boon/spell/overload_lights/requiem
	name = "Extinguish the Lie"
	desc = "The overload, mastered: it answers faster, and the lights it bursts stay dark. Steady light is a lie told to the frightened — this is the correction, and the correction holds."
	grant_text = "The nearest light fixture goes out entirely. It does not come back on."
	upgrades_from = /datum/vestige_boon/spell/overload_lights
	spell_type = /datum/action/cooldown/spell/aoe/vestige_overload/requiem

/datum/vestige_boon/spell/mourning_touch
	name = "Mourner's Touch"
	desc = "Lay a bare palm on the living and share what a vigil feels like from the inside: the cold, the weight, the wanting to sit down. It passes. Eventually. Grief is generous that way."
	grant_text = "Your palm goes cold and stays cold. It is not your cold. You are only holding it for someone."
	spell_type = /datum/action/cooldown/spell/touch/vestige_mourning_touch

/datum/vestige_boon/spell/mourning_touch/last_breath
	name = "Steal the Last Breath"
	desc = "The touch, refined at forty bedsides: take the breath they were keeping for the end. For a little while they will have nothing to shout with. The dead save one breath back. The living never think to."
	grant_text = "Something patient settles into your palm alongside the cold, and waits to be given a mouth."
	upgrades_from = /datum/vestige_boon/spell/mourning_touch
	spell_type = /datum/action/cooldown/spell/touch/vestige_mourning_touch/last_breath

/datum/vestige_boon/spell/last_rites
	name = "Last Rites"
	desc = "Dress a room for grief in one gesture: cabinets swing open, glass cracks, tiles lift from the deck, and every light flickers its honest flicker. Nothing is destroyed. Everything is disturbed."
	grant_text = "Somewhere nearby, a cabinet swings quietly open on its own."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_last_rites

/datum/vestige_boon/spell/widows_walk
	name = "Widow's Walk"
	desc = "Step out of the world of the living for the space of one held breath. Walls are a concern for people with bodies. Blessed ground refuses you, and coming back is slow, and loud."
	grant_text = "For one heartbeat you cannot feel the floor. It is fairly sure it cannot feel you either."
	spell_type = /datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk

/**
 * The revenant's overload-lights curse, ported for a human caster. Local copy
 * of /datum/action/cooldown/spell/aoe/revenant/overload's cast behavior: the
 * upstream spell stack-traces and qdels itself in New() for any non-revenant
 * owner and spends essence in before_cast, so it can't be granted directly.
 */
/datum/action/cooldown/spell/aoe/vestige_overload
	name = "Overload Lights"
	desc = "Overloads all lights nearby, making them flare and shock anyone close to them."
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
 * the flare leaves honest dark behind. A replacement tube undoes it — the
 * upgrade's twist is darkness, not bigger numbers.
 */
/datum/action/cooldown/spell/aoe/vestige_overload/requiem
	name = "Extinguish the Lie"
	desc = "Overloads all lights nearby, making them flare and shock anyone close — and the lights it bursts stay dark until someone fits a new tube."
	cooldown_time = 30 SECONDS

/datum/action/cooldown/spell/aoe/vestige_overload/requiem/overload_shock(obj/machinery/light/to_shock, mob/living/caster)
	..()
	if(QDELETED(to_shock))
		return
	to_shock.break_light_tube()

/**
 * A grief-touch in the revenant's register, built on the standard touch-spell
 * chassis (see the shock-touch mutation) rather than on revenant code — the
 * revenant keeps its draining inside the harvest cycle, which can't leave the
 * antag datum. One bare palm, one living victim: a vigil's worth of cold and
 * weariness. The chill obeys a hard floor, so it slows and shakes but never
 * freezer-locks; the victim warms back up on their own.
 */
/datum/action/cooldown/spell/touch/vestige_mourning_touch
	name = "Mourner's Touch"
	desc = "Pour a vigil's worth of cold and weariness into one living target through a bare palm."
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
	draw_message = span_notice("Cold gathers in your palm. It is not your cold — you are only holding it.")
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
		span_userdanger("[caster]'s touch pours a deathbed's cold into you, and your legs remember every hour of the vigil!"),
	)
	victim.emote("shiver")
	playsound(victim, 'sound/effects/ghost2.ogg', 30, TRUE)
	return TRUE

/obj/item/melee/touch_attack/vestige_mourning
	name = "\improper mourner's touch"
	desc = "A palmful of the cold that waits at the foot of a deathbed, looking for somewhere warm to be put down."
	icon = 'icons/obj/weapons/hand.dmi'
	icon_state = "disintegrate"
	inhand_icon_state = "disintegrate"
	color = "#b8cdd8"

/**
 * The touch mastered: the same cold, and it also takes the breath the victim
 * was keeping for the end — a few missed breaths and a short silence. They
 * keep their legs and their radio keys; they just can't shout about it yet.
 */
/datum/action/cooldown/spell/touch/vestige_mourning_touch/last_breath
	name = "Steal the Last Breath"
	desc = "Pour the vigil's cold into one living target and take the breath they were saving, leaving them briefly voiceless."
	cooldown_time = 20 SECONDS
	draw_message = span_notice("Cold gathers in your palm, patient as a held breath.")

/datum/action/cooldown/spell/touch/vestige_mourning_touch/last_breath/cast_on_hand_hit(obj/item/melee/touch_attack/hand, mob/living/carbon/victim, mob/living/carbon/caster)
	. = ..()
	if(!.)
		return
	victim.losebreath += 4 // a few missed breaths: gasping and a little oxy, not a chokehold
	victim.adjust_silence(8 SECONDS)
	to_chat(victim, span_userdanger("Your breath leaves you — all of it, even the one you were saving!"))

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
	desc = "Dishevels the area around you: cabinets and morgue trays swing open, glass cracks, floor tiles lift, and every light flickers."
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
		span_boldwarning("The room shudders, as if something just walked through it grieving!"),
		span_notice("You let the grief out. The room takes it badly."),
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
 * A sliver of the revenant's incorporeality, worn secondhand: a short
 * ethereal jaunt on the standard wizard chassis (no revenant code involved)
 * with revenant dressing. Two seconds of phasing, then a slow, audible
 * materialization the jaunt chassis enforces — arriving somewhere is the
 * loud part. Blessed ground blocks the walk, as it should.
 */
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk
	name = "Widow's Walk"
	desc = "Step out of the world of the living for the space of one held breath, passing through walls as rumor. Coming back is slow, and loud."
	background_icon_state = "bg_revenant"
	overlay_icon_state = "bg_revenant_border"
	sound = 'sound/effects/ghost2.ogg'
	exit_jaunt_sound = 'sound/effects/ghost2.ogg'
	cooldown_time = 45 SECONDS
	cooldown_reduction_per_rank = 0 SECONDS
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC
	antimagic_flags = MAGIC_RESISTANCE_HOLY
	jaunt_duration = 2 SECONDS
	jaunt_in_time = 0.6 SECONDS
	jaunt_in_type = /obj/effect/temp_visual/dir_setting/wraith
	jaunt_out_type = /obj/effect/temp_visual/dir_setting/wraith/out

/datum/action/cooldown/spell/jaunt/ethereal_jaunt/vestige_widows_walk/do_steam_effects(turf/loc)
	return

#undef VESTIGE_MOURNING_CHILL
#undef VESTIGE_MOURNING_CHILL_FLOOR
#undef VESTIGE_MOURNING_STAMINA
#undef VESTIGE_RITES_WINDOW_DAMAGE_MIN
#undef VESTIGE_RITES_WINDOW_DAMAGE_MAX
#undef VESTIGE_TRUE_VIGIL_DURATION
#undef VESTIGE_TENDED_NEEDED
#undef VESTIGE_TENDED_MIN_DAMAGE
#undef VESTIGE_TENDED_STAMINA_HEAL
