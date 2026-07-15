/**
 * # The Gloaming — nightmare vestige
 *
 * A freighter that went dark mid-burn, in every sense. The map itself is the
 * hazard: bring a light, and know the patron wants it gone. The trial is a
 * campaign against light itself; the boon is the nightmare's own jaunt
 * (already standalone — spell_requirements = NONE upstream).
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/stranger
	name = "the Stranger"
	desc = "A silhouette with its proportions slightly off, pinned under a dead floodlight like a moth. It is only visible because it is darker than the dark behind it."
	gender = NEUTER
	outfit_path = /datum/outfit/job/assistant
	appearance_tint = "#151515"
	trial_types = list(
		/datum/vestige_trial/snuffed_flame,
	)
	idle_lines = list(
		"You brought a light. They always bring a light. Put it out and we can talk properly.",
		"There were four hundred lights on this ship. I remember every one of them going out.",
		"The dark is not empty. The dark is full. The light is what's empty.",
		"I am not trapped under this lamp. The lamp is trapped over me.",
	)
	accept_line = "Good. Start with the one in your pocket."
	busy_line = "One debt. Then another. Not both at once."
	fulfilled_line = "You have already learned to see."
	renounce_line = "Then keep squinting."

// ===== TRIAL OF THE SNUFFED FLAME =====

/datum/vestige_trial/snuffed_flame
	name = "Trial of the Snuffed Flame"
	// Keep the count in sync with VESTIGE_FLAME_LIGHTS_NEEDED
	// (initial values must be constant, so no define interpolation here)
	desc = "Take the censer. Feed it twenty-five burning lights — fixtures, lanterns, flares, it is not picky. Lights snatched out of someone's living grip taste twice as sweet. When it is sated, you will not need eyes the way you do now."
	boon_type = /datum/vestige_boon/spell/shadow_walk
	/// Devour points so far (a light in someone else's grip counts double)
	var/lights_eaten = 0

/datum/vestige_trial/snuffed_flame/on_accepted(mob/living/user)
	hand_over(user, new /obj/item/vestige_censer(get_turf(user)))

/datum/vestige_trial/snuffed_flame/get_progress_text()
	return "The censer has eaten [lights_eaten] of [VESTIGE_FLAME_LIGHTS_NEEDED] lights."

/// May complete (and delete) the trial
/datum/vestige_trial/snuffed_flame/proc/feed(points)
	lights_eaten += points
	refresh_tracker()
	if(lights_eaten >= VESTIGE_FLAME_LIGHTS_NEEDED)
		complete()

/obj/item/vestige_censer
	name = "darklight censer"
	desc = "A lantern that burns backwards. Whatever light it touches goes somewhere else, and does not come back."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "syndilantern"
	w_class = WEIGHT_CLASS_SMALL
	force = 5

/obj/item/vestige_censer/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!devour_lights(interacting_with, user))
		return NONE
	user.do_attack_animation(interacting_with)
	user.changeNext_move(CLICK_CD_MELEE)
	return ITEM_INTERACT_SUCCESS

// Combat-mode swings still feed the censer (plus the bonk)
/obj/item/vestige_censer/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	devour_lights(target, user)

/**
 * Eats every light attached to the target, permanently. Mirrors
 * /datum/element/light_eater's devour rules, but counts morsels for the
 * wielder's trial — the shared element signals on the element instance, which
 * is useless for per-item credit, hence the local copy.
 *
 * Returns the devour points scored (held lights are worth double).
 */
/obj/item/vestige_censer/proc/devour_lights(atom/food, mob/living/user)
	var/list/buffet = list()
	SEND_SIGNAL(food, COMSIG_LIGHT_EATER_QUEUE, buffet, src)
	for(var/datum/light_source/morsel_source as anything in food.light_sources)
		buffet[morsel_source.source_atom] = TRUE
	if(!length(buffet))
		return 0

	var/points = 0
	for(var/atom/morsel as anything in buffet)
		if(morsel == src)
			continue
		if(istype(morsel, /turf/open/space) || istype(morsel, /turf/open/lava))
			continue
		if(istransparentturf(morsel))
			continue
		if(morsel.light_power <= 0 || morsel.light_range <= 0 || !morsel.light_on)
			continue
		if(SEND_SIGNAL(morsel, COMSIG_LIGHT_EATER_ACT, src) & COMPONENT_BLOCK_LIGHT_EATER)
			continue
		morsel.AddElement(/datum/element/light_eaten)
		points += (ismob(morsel.loc) && morsel.loc != user) ? 2 : 1

	if(!points)
		return 0
	food.visible_message(
		span_danger("The dark inside [src] lashes out at [food], and the light goes with it!"),
		span_userdanger("Something hungry snuffs your light out from inside [src]!"),
	)
	playsound(src, 'sound/effects/magic/blind.ogg', 40, TRUE)
	var/datum/vestige_trial/snuffed_flame/trial = user?.mind?.active_vestige_trial
	if(istype(trial))
		trial.feed(points)
	return points

// ===== BOONS =====

// The nightmare's jaunt, granted as-is: upstream ships it with
// spell_requirements = NONE, and light already polices it.
/datum/vestige_boon/spell/shadow_walk
	name = "Shadow Walk"
	grant_text = "The dark stops being a place and starts being a door."
	spell_type = /datum/action/cooldown/spell/jaunt/shadow_walk
