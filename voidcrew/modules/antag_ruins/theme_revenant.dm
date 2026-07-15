/**
 * # The Wake — revenant vestige
 *
 * A hospice barge whose every passenger died on the same night, and something
 * stayed behind to grieve them. The revenant's body IS the antag (invisible,
 * phasing — unportable), so the boon is a local human-castable port of its
 * overload-lights curse: same behavior as upstream, no revenant mob, no
 * essence economy (the upstream spell qdels itself when granted to a
 * non-revenant, hence the copy).
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/mourner
	name = "the Mourner"
	desc = "A gaunt figure in funeral black, seated beside an empty bed. Its grief has outlived everyone it was for, and has had to find new work."
	gender = NEUTER
	outfit_path = /datum/outfit/job/chaplain
	appearance_tint = "#8ea3b0"
	trial_types = list(
		/datum/vestige_trial/last_breath,
	)
	boon_types = list(
		/datum/vestige_boon/spell/overload_lights,
	)
	idle_lines = list(
		"Forty beds. One night. I sat with each of them, and I was not enough, and here I still am. Grief keeps terrible hours.",
		"The dying save one breath for the end. Nobody hears it. That is what it is FOR.",
		"You smell of the living. Don't apologize — it's almost nostalgic.",
		"The lights in this place flicker because I asked them to. Steady light is a lie told to the frightened.",
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

// ===== BOONS =====

/datum/vestige_boon/spell/overload_lights
	name = "Overload Lights"
	desc = "Push your grief into every powered light nearby until they flare, burst, and bite anyone standing close. Steady light is a lie told to the frightened."
	grant_text = "The nearest light fixture dims, deferentially."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_overload

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
