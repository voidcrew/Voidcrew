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
	// Keep the count in sync with VESTIGE_LANTERN_CORPSES_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the lantern. The dead keep one last breath back, and the lantern is thirsty for it. Hold it to the lips of five different corpses. They won't miss it."
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
	desc = "A lantern that doesn't put out any light you could actually read by. Something inside it is breathing in, very slowly, and never out."
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
		balloon_alert(user, "the lantern stays dark")
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
		span_danger("[src] flares cold blue, and something leaves [corpse] with a sigh."),
		)
	playsound(corpse, 'sound/effects/ghost2.ogg', 30, TRUE)
	return ITEM_INTERACT_SUCCESS

// ===== THE TRUE VIGIL =====

/datum/vestige_trial/true_vigil
	name = "The True Vigil"
	// Keep the duration in sync with VESTIGE_TRUE_VIGIL_DURATION
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the candle. Find a body, anyone's, light the candle beside it, and then stay put. Four unbroken minutes within arm's reach, with the candle standing on the floor the whole time. If the flame goes out the clock starts over."
	/// Unbroken vigil time so far (deciseconds), zeroed whenever the flame goes out
	var/kept_time = 0
	/// The loaned kit item, reclaimed (deleted) the moment the pact ends
	var/obj/item/vestige_candle/candle

/datum/vestige_trial/true_vigil/on_accepted(mob/living/user)
	candle = hand_over(user, new /obj/item/vestige_candle(get_turf(user)))
	to_chat(user, span_notice("The candle is cold, slightly damp, and heavier than it looks."))

/datum/vestige_trial/true_vigil/Destroy()
	QDEL_NULL(candle)
	return ..()

/datum/vestige_trial/true_vigil/get_progress_text()
	return kept_time ? "You have kept the vigil [DisplayTimeText(kept_time)] of [DisplayTimeText(VESTIGE_TRUE_VIGIL_DURATION)], unbroken." : "The candle still needs lighting beside a body."

/// Accrues unbroken vigil time. May complete (and delete) the trial.
/datum/vestige_trial/true_vigil/proc/keep(deciseconds)
	kept_time += deciseconds
	refresh_tracker()
	if(kept_time < VESTIGE_TRUE_VIGIL_DURATION)
		return
	candle.visible_message(span_boldnotice("[candle]'s flame goes perfectly still for a moment, then puts itself out. The vigil is kept."))
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
	desc = "A stub of grey tallow candle. The wick won't catch at all unless you're lighting it beside a body."
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
	/// Whether the flame guttered last tick, one warning tick of grace before it goes out
	var/guttering = FALSE

/obj/item/vestige_candle/Destroy()
	STOP_PROCESSING(SSobj, src)
	keeper = null
	watched = null
	return ..()

/obj/item/vestige_candle/examine(mob/user)
	. = ..()
	. += span_notice("Light it beside a dead humanoid to start a vigil: [DisplayTimeText(VESTIGE_TRUE_VIGIL_DURATION)] unbroken, with you, the candle and the body all within arm's reach. It only burns while standing on the floor.")

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
		span_notice("The wick catches with a pale flame. Stay within arm's reach of [body]. If you wander off, it goes out."),
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
			visible_message(span_notice("[src]'s flame leans over toward [watched]."))
		trial.keep(seconds_per_tick * (1 SECONDS)) // may complete the pact, deleting the trial and us with it
		return
	if(!guttering)
		guttering = TRUE
		visible_message(span_warning("[src]'s flame gutters wildly!"))
		if(keeper?.current)
			to_chat(keeper.current, span_warning("The vigil is faltering! Get back within arm's reach of the body."))
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
	if(!istype(keeper_body) || keeper_body.stat != STABLE)
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
		visible_message(span_notice("[src] goes out on its own, gently. No sense keeping a vigil for someone who got back up."))
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
	desc = "Take the cloth. Find people who are badly hurt, the shaking kind, and do what I did forty times over: kneel down, take their hand, and stay until the shaking stops. Three of them, three different people. Don't promise them anything."
	/// Patients already sat with (weakref -> TRUE), so the same brow never counts twice
	var/list/tended = list()

/datum/vestige_trial/sitters_rounds/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_cloth(get_turf(user)))

/datum/vestige_trial/sitters_rounds/get_progress_text()
	return "You have sat with [length(tended)] of [VESTIGE_TENDED_NEEDED] of the badly hurt."

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
	desc = "A square of linen, always cool and slightly damp. It has wiped a great many brows."
	icon = 'icons/obj/toys/toy.dmi'
	icon_state = "rag"
	w_class = WEIGHT_CLASS_TINY
	color = "#b8cdd8"

/obj/item/vestige_cloth/examine(mob/user)
	. = ..()
	. += span_notice("Press it to someone badly hurt but still alive to sit with them until the shaking stops. The same person never counts twice.")

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
		balloon_alert(user, "not hurt badly enough!")
		return ITEM_INTERACT_BLOCKING
	if(trial.tended[WEAKREF(patient)])
		balloon_alert(user, "already sat with!")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_warning("[user] kneels beside [patient], presses a cool cloth to [patient.p_their()] brow, and takes [patient.p_their()] hand."),
		span_notice("You kneel, press the cloth to [patient]'s brow, and take [patient.p_their()] hand. Now stay put."),
	)
	to_chat(patient, span_notice("Someone kneels down and takes your hand. They don't say anything. They just stay."))
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
	patient.adjust_stamina_loss(-VESTIGE_TENDED_STAMINA_HEAL)
	patient.adjust_jitter(-1 MINUTES)
	patient.adjust_dizzy(-1 MINUTES)
	patient.add_mood_event("vestige_tended", /datum/mood_event/vestige_tended)
	patient.visible_message(
		span_notice("[patient]'s shaking slows, and stops."),
		span_boldnotice("The shaking stops. Someone stayed with you, and it helped."),
	)
	playsound(patient, 'sound/effects/ghost2.ogg', 20, TRUE)
	trial.tend(patient) // may complete (and delete) the trial, nothing touches it after this
	return ITEM_INTERACT_SUCCESS

/// Everything that hurts, totaled: the cloth answers to pain of every kind
/obj/item/vestige_cloth/proc/get_suffering(mob/living/patient)
	return patient.get_brute_loss() + patient.get_fire_loss() + patient.get_tox_loss() + patient.get_oxy_loss() + patient.get_stamina_loss()

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
		// spark_spread moved under effect_system/basic and swapped set_up() for
		// constructor args: (location, amount, cardinals_only).
		var/datum/effect_system/basic/spark_spread/light_sparks = new(get_turf(light), 4, FALSE)
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
	// Upstream #97204 turned blessing from an /obj/effect into a trait + element pair, so the
	// dispel is a trait check and a RemoveElement instead of a qdel - see the same block in
	// /datum/action/cooldown/spell/aoe/revenant/defile (revenant_abilities.dm).
	if(HAS_TRAIT(victim, TRAIT_TURF_BLESSED))
		victim.RemoveElement(/datum/element/blessed_turf)
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
#undef VESTIGE_TRUE_VIGIL_DURATION
#undef VESTIGE_TENDED_NEEDED
#undef VESTIGE_TENDED_MIN_DAMAGE
#undef VESTIGE_TENDED_STAMINA_HEAL
