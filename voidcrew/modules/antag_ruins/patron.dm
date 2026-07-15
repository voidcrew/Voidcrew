/**
 * # Vestige Patron
 *
 * The remnant of a dead antagonist, mapped into its vestige ruin. Unkillable
 * and immovable, same treatment as the outpost traders: godmode makes
 * violence pointless and NOMOBSWAP stops walk-throughs.
 *
 * Clicking a patron opens a radial — Speak / Trials. The trial menu is
 * conversation-driven (radial + confirm dialogs), not tgui: patrons are
 * bargains, not shops.
 *
 * Patrons are STATELESS. The ruin interior (and this mob with it) is wiped
 * whenever everyone leaves, so everything about a supplicant's pact lives on
 * their mind (see trial.dm) and the patron rediscovers it by lookup.
 */

#define PATRON_OPTION_SPEAK "Speak"
#define PATRON_OPTION_TRIALS "Trials"

/mob/living/basic/vestige_patron
	name = "vestige"
	desc = "Something that used to be someone."
	icon = 'icons/mob/simple/simple_human.dmi'
	unique_name = FALSE
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	density = TRUE
	move_resist = INFINITY
	basic_mob_flags = NONE
	faction = list(FACTION_NEUTRAL)
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	/// Trial typepaths this patron offers, in menu order
	var/list/trial_types = list()
	/// Outfit dressed onto the appearance dummy
	var/outfit_path
	/// Color applied over the whole sprite after dressing (silhouettes, wrong pallor)
	var/appearance_tint
	/// Random lines for Speak
	var/list/idle_lines = list()
	/// Said when a pact is struck
	var/accept_line = "It is agreed."
	/// Said when the supplicant already carries a different unfinished pact
	var/busy_line = "Finish what you began, or renounce it."
	/// Said about a trial already fulfilled
	var/fulfilled_line = "That debt is paid."
	/// Said when a pact is renounced
	var/renounce_line = "Weakness."
	COOLDOWN_DECLARE(speak_cooldown)

/mob/living/basic/vestige_patron/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_GODMODE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NOMOBSWAP, INNATE_TRAIT)
	if(outfit_path)
		apply_dynamic_human_appearance(src, outfit_path = outfit_path)
	if(appearance_tint)
		color = appearance_tint

/mob/living/basic/vestige_patron/examine(mob/user)
	. = ..()
	. += span_notice("A tap on the shoulder — if you dare — opens negotiations.")
	var/datum/vestige_trial/active = user.mind?.active_vestige_trial
	if(active && (active.type in trial_types))
		. += span_boldnotice("Your pact: [active.name]. [active.get_progress_text()]")

/mob/living/basic/vestige_patron/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	// show_radial_menu sleeps; don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(open_patron_menu), user)
	return TRUE

/mob/living/basic/vestige_patron/proc/open_patron_menu(mob/living/user)
	if(!user.mind)
		to_chat(user, span_warning("[src] looks through you as if you weren't there at all."))
		return
	var/list/options = list(
		PATRON_OPTION_SPEAK = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk"),
		PATRON_OPTION_TRIALS = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_lore"),
	)
	var/choice = show_radial_menu(user, src, options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = TRUE, tooltips = TRUE)
	if(!choice || !check_menu(user))
		return
	switch(choice)
		if(PATRON_OPTION_SPEAK)
			speak_line()
		if(PATRON_OPTION_TRIALS)
			open_trial_menu(user)

/// Radial validity: supplicant still there, still conscious, still adjacent
/mob/living/basic/vestige_patron/proc/check_menu(mob/living/user)
	if(!istype(user))
		return FALSE
	if(IS_DEAD_OR_INCAP(user) || !user.Adjacent(src))
		return FALSE
	return TRUE

/// Second-level radial: one entry per offered trial
/mob/living/basic/vestige_patron/proc/open_trial_menu(mob/living/user)
	if(!user.mind || !length(trial_types))
		return
	var/list/options = list()
	var/list/by_name = list()
	for(var/datum/vestige_trial/trial_type as anything in trial_types)
		var/trial_name = initial(trial_type.name)
		options[trial_name] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_lore")
		by_name[trial_name] = trial_type
	var/choice = show_radial_menu(user, src, options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = TRUE, tooltips = TRUE)
	if(!choice || !check_menu(user))
		return
	handle_trial_choice(user, by_name[choice])

/mob/living/basic/vestige_patron/proc/handle_trial_choice(mob/living/user, trial_type)
	var/datum/mind/mind = user.mind
	if(!mind || !trial_type)
		return

	if(trial_type in mind.completed_vestige_trials)
		say(fulfilled_line)
		return

	var/datum/vestige_trial/active = mind.active_vestige_trial
	// This very trial is underway: report progress, offer renunciation
	if(active?.type == trial_type)
		var/renounce = tgui_alert(user, "[active.get_progress_text()]", active.name, list("Continue", "Renounce"))
		if(renounce == "Renounce" && check_menu(user) && mind.active_vestige_trial == active)
			qdel(active) // Destroy clears mind.active_vestige_trial
			say(renounce_line)
		return

	// A different pact is underway — one hunger at a time
	if(active)
		say(busy_line)
		return

	// Offer it
	var/datum/vestige_trial/offered = new trial_type(mind, name)
	var/accept = tgui_alert(user, offered.desc, offered.name, list("Accept", "Decline"))
	if(accept != "Accept" || !check_menu(user) || mind.active_vestige_trial)
		qdel(offered)
		return
	mind.active_vestige_trial = offered
	offered.begin(user)
	say(accept_line)
	playsound(src, 'sound/effects/magic/curse.ogg', 30, TRUE)

/mob/living/basic/vestige_patron/proc/speak_line()
	if(!length(idle_lines) || !COOLDOWN_FINISHED(src, speak_cooldown))
		return
	COOLDOWN_START(src, speak_cooldown, 3 SECONDS)
	say(pick(idle_lines))

#undef PATRON_OPTION_SPEAK
#undef PATRON_OPTION_TRIALS
