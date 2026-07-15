/**
 * # The Aperture — voidwalker vestige
 *
 * A hull section that is mostly windows, all of them facing nothing. The
 * voidwalker's body is the antag (space-native, unportable), so the patron is
 * what watches through the glass, the trial is an introduction to the void,
 * and the boon is a human-tuned subtype of the generic charge action the
 * voidwalker dashes with (the component never checks mob type — verified).
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/watcher
	name = "the Watcher Behind Glass"
	desc = "A tall silhouette standing at the window — or in it, or just past it; the pane never quite agrees. It watches you the way you watch an aquarium."
	gender = NEUTER
	outfit_path = /datum/outfit/job/assistant
	appearance_tint = "#141428"
	trial_types = list(
		/datum/vestige_trial/long_dark,
	)
	boon_types = list(
		/datum/vestige_boon/spell/cosmic_dash,
	)
	idle_lines = list(
		"You call it nothing. It is not nothing. It is everything, minus the parts you were told to look at.",
		"Glass is the politest kind of lie: both sides get to believe they are the ones inside.",
		"Your ship is a held breath. One day every ship exhales. I simply prefer not to wait indoors.",
		"The void has never killed anyone. The vacuum does that. The void just watches, like me.",
	)
	accept_line = "Good. Step outside. I will make the introductions."
	busy_line = "Something else already holds your leash. I do not share windows."
	fulfilled_line = "You have already been introduced. It remembers you."
	renounce_line = "Back behind the glass, then. It suits you."
	claim_line = "Something was set aside for you out there. Take it before you ask for more."
	exhausted_line = "I have shown you everything visible from this window. The rest you would have to see from the other side."
	remember_line = "You stopped. The void did not — it kept your things exactly where you dropped them."

// ===== TRIAL OF THE LONG DARK =====

/datum/vestige_trial/long_dark
	name = "Trial of the Long Dark"
	// Keep the count in sync with VESTIGE_VOID_SECONDS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the shard. Carry it out into the nothing between hulls and stay — five minutes, all told, alive, with the shard on your person. The void does not want you dead. It wants you introduced."
	/// Cumulative seconds spent in hard vacuum with the shard
	var/seconds_in_void = 0

/datum/vestige_trial/long_dark/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_shard(get_turf(user)))

/datum/vestige_trial/long_dark/get_progress_text()
	return "The shard has soaked [round(seconds_in_void)] of [VESTIGE_VOID_SECONDS_NEEDED] seconds of void."

/// May complete (and delete) the trial
/datum/vestige_trial/long_dark/proc/soak(seconds)
	seconds_in_void += seconds
	refresh_tracker()
	if(seconds_in_void >= VESTIGE_VOID_SECONDS_NEEDED)
		complete()

/obj/item/vestige_shard
	name = "void shard"
	desc = "A splinter of crystal that is a slightly deeper black than whatever is behind it. Held to your ear, it sounds like a window being looked through."
	icon = 'icons/obj/ore.dmi'
	icon_state = "bluespace_crystal"
	color = "#3c1a5c"
	w_class = WEIGHT_CLASS_SMALL
	light_range = 1.4
	light_power = 0.4
	light_color = "#6633aa"

/obj/item/vestige_shard/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/item/vestige_shard/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

// Credits void-time while carried on someone's person (loc == mob covers
// hands, pockets and worn slots; a backpack's insides don't count as "held")
/obj/item/vestige_shard/process(seconds_per_tick)
	var/mob/living/holder = loc
	if(!istype(holder) || holder.stat == DEAD)
		return
	var/datum/vestige_trial/long_dark/trial = holder.mind?.active_vestige_trial
	if(!istype(trial))
		return
	var/turf/here = get_turf(holder)
	if(!here)
		return
	if(!isspaceturf(here))
		var/datum/gas_mixture/air = here.return_air()
		if(air && air.return_pressure() >= HAZARD_LOW_PRESSURE)
			return
	if(prob(6))
		to_chat(holder, span_notice("The shard hums against you, pleased with the company."))
	trial.soak(seconds_per_tick)

// ===== BOONS =====

/datum/vestige_boon/spell/cosmic_dash
	name = "Cosmic Dash"
	desc = "Hurl yourself across a gap like something the void spat out — anyone standing where you land will wish they hadn't been."
	grant_text = "Distance quietly stops feeling like your problem."
	spell_type = /datum/action/cooldown/mob_cooldown/charge/vestige_dash

// Human-tuned subtype of the generic charge action (the component only ever
// touches owner, so a mind-targeted grant to a plain human is safe)
/datum/action/cooldown/mob_cooldown/charge/vestige_dash
	name = "Cosmic Dash"
	desc = "Hurl yourself at a target, trampling whatever you connect with."
	button_icon = 'icons/mob/actions/actions_voidwalker.dmi'
	button_icon_state = "void_dash"
	cooldown_time = 20 SECONDS
	charge_distance = 8
	charge_damage = 15
	charge_past = 0
	destroy_objects = FALSE

/datum/action/cooldown/mob_cooldown/charge/vestige_dash/do_charge_indicator(atom/charger, atom/charge_target)
	playsound(owner, 'sound/effects/curse/curse1.ogg', 60)
