/**
 * # Tier 4 legend chrome + the Piledriver prototype
 *
 * Cascade Lattice, Redline Core, Governor Delete, Meteor Piledriver.
 *
 * The two OS cores share the chest OS slot, installing one evicts the
 * other, the CP2077 operating-system choice. Both are windowed powers with
 * a crash on the back end; per the design freeze the crash IS the balance,
 * because ambient EMP threat is thin. Both additionally treat any EMP during
 * their window as an instant crash plus a full recooldown, the
 * 1-voucher-grenade counter to an 8-voucher implant.
 */

// =========================================================================
// CASCADE LATTICE
// =========================================================================

/// The window.
#define CYBERWARE_CASCADE_WINDOW (8 SECONDS)
/// The price.
#define CYBERWARE_CASCADE_CRASH (6 SECONDS)
/// Ranged dodge chance while moving during the window (shared arbiter;
/// highest-wins with Slipwire's 15, never additive).
#define CYBERWARE_CASCADE_DODGE_CHANCE 40
/// Stamina dumped by the crash.
#define CYBERWARE_CASCADE_CRASH_STAMINA 80
/// Degrees the afterimage hue moves per step of the trail.
#define CYBERWARE_CASCADE_HUE_STEP 25
/// Melee-cooldown multiplier during the window (lower is faster).
#define CYBERWARE_CASCADE_MELEE_MULT 0.5
/// Starting opacity of a trail afterimage.
#define CYBERWARE_CASCADE_AFTERIMAGE_ALPHA 200

/**
 * # Cascade Lattice (T4, chest, OS slot, load 12)
 *
 * The sandevistan-class flagship. Eight seconds where the world happens at
 * your speed: a full -1 gait (with reagent-modifier immunity for the
 * duration, no meth stacking, no sub-tick movement), melee cooldowns
 * halved, and 40% ranged dodge while moving through the shared arbiter in
 * ware_pro_combat.dm. Everyone nearby sees it: afterimages peel off every
 * step, your victim's screen never had a chance, and the activation is an
 * audible time-tear.
 *
 * Then the heat bill: six seconds of crash, heavy stamina dump, leaden
 * slowdown, zero dodge. An EMP during the window skips straight to the
 * crash and re-arms the full sixty-second cooldown.
 *
 * Every number the window and the crash run on is a var here, so the lesser
 * models in ware_line_sandy.dm retune by setting vars and swapping the action
 * for a slower one. The status effects copy the numbers off the organ when the
 * button is pressed and hold no reference back to it.
 */
/obj/item/organ/cyberimp/cyberware/cascade
	name = "\improper Cascade lattice"
	desc = "A full-spine lattice of superconducting myelin, the real thing, not one of the knockoffs. The bill comes afterward."
	icon_state = "cascade"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_OS
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 12
	tier = CYBERWARE_TIER_4
	aug_overlay = "cascade"
	emissive_overlay = TRUE
	actions_types = list(/datum/action/cooldown/cyberware/cascade_surge)
	/// How long the window lasts.
	var/window_duration = CYBERWARE_CASCADE_WINDOW
	/// How long the crash lasts once the window ends.
	var/crash_duration = CYBERWARE_CASCADE_CRASH
	/// Stamina dumped on the bearer by the crash.
	var/crash_stamina = CYBERWARE_CASCADE_CRASH_STAMINA
	/// Ranged dodge chance while moving during the window.
	var/window_dodge = CYBERWARE_CASCADE_DODGE_CHANCE
	/// The gait the window grants.
	var/datum/movespeed_modifier/window_speed = /datum/movespeed_modifier/cyberware_cascade
	/// Melee-cooldown multiplier during the window (lower is faster).
	var/window_melee_mult = CYBERWARE_CASCADE_MELEE_MULT
	/// The bearer's screen tint during the window.
	var/datum/client_colour/window_colour = /datum/client_colour/cyberware_cascade
	/// A trail afterimage is left on every Nth step.
	var/afterimage_interval = 1
	/// Starting opacity of a trail afterimage.
	var/afterimage_alpha = CYBERWARE_CASCADE_AFTERIMAGE_ALPHA
	/// The status alert shown while the window runs.
	var/window_alert = /atom/movable/screen/alert/status_effect/cyberware_cascade
	/// What the bearer reads on activation.
	var/online_message = "CASCADE ONLINE."

/obj/item/organ/cyberimp/cyberware/cascade/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	// Pulling the lattice mid-cycle takes its statuses with it. Removing the
	// window this way still applies the crash. The heat is already in you.
	organ_owner.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	organ_owner.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/**
 * The EMP counter: a pulse during the window forces the crash immediately
 * and re-arms the full cooldown, on top of the standard chrome reboot ..()
 * already started.
 */
/obj/item/organ/cyberimp/cyberware/cascade/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	if(!owner)
		return
	var/datum/status_effect/cyberware_cascade_window/window = owner.has_status_effect(/datum/status_effect/cyberware_cascade_window)
	if(!window)
		return
	to_chat(owner, span_userdanger("The pulse rips through the lattice mid-cascade, everything slams back to real time!"))
	owner.remove_status_effect(/datum/status_effect/cyberware_cascade_window) // on_remove applies the crash
	for(var/datum/action/cooldown/cyberware/cascade_surge/surge in actions)
		surge.StartCooldown()

/datum/action/cooldown/cyberware/cascade_surge
	name = "Cascade Surge"
	desc = "Eight seconds of overwhelming speed: melee cooldowns halved, 40% chance to dodge ranged fire while moving. Then six seconds of crash."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_cascade"
	cooldown_time = 60 SECONDS
	click_to_activate = FALSE

/datum/action/cooldown/cyberware/cascade_surge/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/mob/living/surger = owner
	if(surger.has_status_effect(/datum/status_effect/cyberware_cascade_window) || surger.has_status_effect(/datum/status_effect/cyberware_cascade_crash))
		surger.balloon_alert(surger, "lattice still cycling!")
		return FALSE
	StartCooldown()
	// The lattice hands the window its numbers (an organ-less call falls back to the T4 defaults).
	surger.apply_status_effect(/datum/status_effect/cyberware_cascade_window, organ)
	return TRUE

/**
 * The window. All the speed lives here so one teardown path handles natural
 * expiry, EMP shutdown and chrome removal alike, and every teardown of a
 * live window on a living bearer rolls straight into the crash.
 */
/datum/status_effect/cyberware_cascade_window
	id = "cyberware_cascade_window"
	duration = CYBERWARE_CASCADE_WINDOW
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/cyberware_cascade
	/// Hue of the next afterimage, in degrees. Starts random so no two surges match.
	var/trail_hue = 0
	// The numbers below default to the T4 lattice and are overwritten from the
	// organ that opened the window (see on_creation). Copied, never referenced.
	/// Ranged dodge chance while the window lives.
	var/dodge_chance = CYBERWARE_CASCADE_DODGE_CHANCE
	/// The gait the window grants.
	var/datum/movespeed_modifier/speed_type = /datum/movespeed_modifier/cyberware_cascade
	/// Melee-cooldown multiplier (lower is faster).
	var/melee_mult = CYBERWARE_CASCADE_MELEE_MULT
	/// The bearer's screen tint.
	var/datum/client_colour/colour_type = /datum/client_colour/cyberware_cascade
	/// A trail afterimage is left on every Nth step.
	var/afterimage_interval = 1
	/// Starting opacity of a trail afterimage.
	var/afterimage_alpha = CYBERWARE_CASCADE_AFTERIMAGE_ALPHA
	/// What the bearer reads on activation.
	var/online_message = "CASCADE ONLINE."
	/// The crash this window rolls into.
	var/crash_duration = CYBERWARE_CASCADE_CRASH
	var/crash_stamina = CYBERWARE_CASCADE_CRASH_STAMINA
	/// Steps taken so far, for the afterimage cadence.
	var/steps_taken = 0

/// Optional second argument: the lattice whose numbers this window runs on.
/datum/status_effect/cyberware_cascade_window/on_creation(mob/living/new_owner, obj/item/organ/cyberimp/cyberware/cascade/lattice)
	if(istype(lattice))
		duration = lattice.window_duration
		alert_type = lattice.window_alert
		dodge_chance = lattice.window_dodge
		speed_type = lattice.window_speed
		melee_mult = lattice.window_melee_mult
		colour_type = lattice.window_colour
		afterimage_interval = lattice.afterimage_interval
		afterimage_alpha = lattice.afterimage_alpha
		online_message = lattice.online_message
		crash_duration = lattice.crash_duration
		crash_stamina = lattice.crash_stamina
	return ..()

/datum/status_effect/cyberware_cascade_window/on_apply()
	trail_hue = rand(0, 359)
	owner.add_movespeed_modifier(speed_type)
	owner.add_movespeed_mod_immunities(id, /datum/movespeed_modifier/reagent)
	cyberware_register_dodge_source(owner, id, CALLBACK(src, PROC_REF(get_dodge_chance)))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
	owner.add_client_colour(colour_type, id)
	playsound(owner, 'sound/effects/magic/timeparadox2.ogg', 70, TRUE)
	owner.visible_message(
		span_boldwarning("[owner] fractures into afterimages. Something under [owner.p_their()] skin is running far too fast!"),
		span_boldnotice(online_message),
	)
	owner.balloon_alert(owner, "cascade online")
	cyberware_cascade_window_fx(owner)
	return TRUE

/datum/status_effect/cyberware_cascade_window/on_remove()
	owner.remove_movespeed_modifier(speed_type)
	owner.remove_movespeed_mod_immunities(id, /datum/movespeed_modifier/reagent)
	cyberware_unregister_dodge_source(owner, id)
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.apply_status_effect(/datum/status_effect/cyberware_cascade_crash, crash_duration, crash_stamina)
	if(!QDELETED(owner))
		cyberware_cascade_window_end_fx(owner)
	return ..()

/// Melee cooldowns scaled for the window (changeNext_move multiplies these in).
/datum/status_effect/cyberware_cascade_window/nextmove_modifier()
	return melee_mult

/// Dodge-source callback for the shared arbiter: flat chance while the window
/// lives (the arbiter itself enforces moving-only and point-blank rules).
/datum/status_effect/cyberware_cascade_window/proc/get_dodge_chance()
	return dodge_chance

/// Signal proc for [COMSIG_MOVABLE_MOVED]: one afterimage per step, the
/// telegraph everyone in the fight can read. Each step shifts the hue, so the
/// trail reads as one rolling colour gradient.
/datum/status_effect/cyberware_cascade_window/proc/on_move(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(!isturf(old_loc))
		return
	steps_taken++
	if(steps_taken % afterimage_interval) // cheaper chrome leaves a sparser trail
		return
	new /obj/effect/temp_visual/decoy/fading/cascade(old_loc, owner, trail_hue, afterimage_alpha)
	trail_hue = (trail_hue + CYBERWARE_CASCADE_HUE_STEP) % 360

/// One afterimage in the Cascade trail, washed in a single hue.
/obj/effect/temp_visual/decoy/fading/cascade
	duration = 8

/obj/effect/temp_visual/decoy/fading/cascade/Initialize(mapload, atom/mimiced_atom, hue = 0, start_alpha = CYBERWARE_CASCADE_AFTERIMAGE_ALPHA)
	. = ..()
	alpha = start_alpha
	color = cascade_tint_matrix(hue)
	animate(src, alpha = 0, time = duration) // restart the parent's fade from the new alpha

/// Colour matrix that flattens the copy to luminance and paints it one hue,
/// with a lift so dark clothes still glow instead of going black.
/obj/effect/temp_visual/decoy/fading/cascade/proc/cascade_tint_matrix(hue)
	var/list/tint = rgb2num(rgb(hue, 100, 100, space = COLORSPACE_HSV))
	var/red = tint[1] / 255
	var/green = tint[2] / 255
	var/blue = tint[3] / 255
	var/gain = 0.8
	var/lift = 0.6
	return list(
		0.3 * gain * red, 0.3 * gain * green, 0.3 * gain * blue,
		0.59 * gain * red, 0.59 * gain * green, 0.59 * gain * blue,
		0.11 * gain * red, 0.11 * gain * green, 0.11 * gain * blue,
		lift * red, lift * green, lift * blue,
	)

/atom/movable/screen/alert/status_effect/cyberware_cascade
	name = "Cascade Window"
	desc = "The lattice has the world in slow motion. Make it count."
	icon_state = "radiation_shield"

/// The lesser models' alert (ware_line_sandy.dm), with no crash timer in the text.
/atom/movable/screen/alert/status_effect/cyberware_cascade/aftermarket
	name = "Reflex Window"
	desc = "The rig has the world in slow motion. Make it count."

/// The bill. No dodge source, no speed, the opposite of all of it.
/datum/status_effect/cyberware_cascade_crash
	id = "cyberware_cascade_crash"
	duration = CYBERWARE_CASCADE_CRASH
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	/// Stamina dumped on the bearer when the crash lands.
	var/crash_stamina = CYBERWARE_CASCADE_CRASH_STAMINA

/// Optional arguments: crash length and stamina dump, from the window that ended.
/datum/status_effect/cyberware_cascade_crash/on_creation(mob/living/new_owner, crash_duration, stamina_dump)
	if(isnum(crash_duration))
		duration = crash_duration
	if(isnum(stamina_dump))
		crash_stamina = stamina_dump
	return ..()

/datum/status_effect/cyberware_cascade_crash/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_cascade_crash)
	owner.adjustStaminaLoss(crash_stamina)
	owner.add_client_colour(/datum/client_colour/cyberware_cascade_crash, id)
	playsound(owner, 'sound/machines/warning-buzzer.ogg', 50, TRUE)
	owner.visible_message(
		span_warning("[owner] staggers, every movement suddenly leaden."),
		span_userdanger("The lattice dumps its heat. Your whole body seizes up and everything slows to a crawl."),
	)
	owner.balloon_alert(owner, "cascade crash!")
	cyberware_cascade_crash_fx(owner)
	return TRUE

/datum/status_effect/cyberware_cascade_crash/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_cascade_crash)
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.balloon_alert(owner, "systems restabilized")
	if(!QDELETED(owner))
		cyberware_cascade_crash_end_fx(owner)
	return ..()

/datum/movespeed_modifier/cyberware_cascade
	multiplicative_slowdown = -1

/datum/movespeed_modifier/cyberware_cascade_crash
	multiplicative_slowdown = 1.5

/// The window's screen: cool, oversharp, edges pulled toward violet.
/datum/client_colour/cyberware_cascade
	priority = CLIENT_COLOR_ORGAN_PRIORITY
	color = list(1.1, 0, 0.08, 0.05, 1.05, 0.1, 0.1, 0, 1.2)
	fade_in = 3
	fade_out = 3

/// The crash's screen: drained and gray-brown.
/datum/client_colour/cyberware_cascade_crash
	priority = CLIENT_COLOR_ORGAN_PRIORITY
	color = list(0.55, 0.3, 0.25, 0.35, 0.55, 0.25, 0.25, 0.25, 0.5)
	fade_in = 3
	fade_out = 5

// =========================================================================
// REDLINE CORE
// =========================================================================

/// The window.
#define CYBERWARE_REDLINE_WINDOW (12 SECONDS)
/// Incoming brute/burn multiplier during the window (-40%).
#define CYBERWARE_REDLINE_DAMAGE_MULT 0.6
/// Flat bonus to unarmed strikes during the window.
#define CYBERWARE_REDLINE_MELEE_BONUS 8
/// Roar reach in tiles.
#define CYBERWARE_REDLINE_ROAR_RANGE 5
/// Stamina dumped by the crash.
#define CYBERWARE_REDLINE_CRASH_STAMINA 100
/// Crash slowdown duration.
#define CYBERWARE_REDLINE_CRASH (5 SECONDS)
/// The outline a bearer wears through the window.
#define CYBERWARE_REDLINE_OUTLINE_COLOR "#ff2a2a"

/**
 * # Redline Core (T4, chest, OS slot, load 10)
 *
 * The rage OS to Cascade's speed OS. Same slot, pick one. Twelve seconds:
 * stun immunity (anti-stun buff pattern), 40% less brute and burn, +8 on
 * every unarmed strike, and an opening roar that staggers everything
 * hostile nearby, mobs whose AI carries the flee subtree genuinely run;
 * everything else just stumbles. Your screen slams red and stays there,
 * and everyone else gets a mob that visibly is not stopping.
 *
 * The +8 is meant to land on EVERY punch, including the ones arm chrome
 * takes over (see [/datum/status_effect/cyberware_redline_window] for how)
 * the window reaches punches that never touch the standard attack chain.
 *
 * Then the collapse: a hundred stamina, leaden legs, and whatever you
 * didn't finish is now standing over you. An EMP during the window skips
 * straight to that collapse and re-arms the full ninety-second cooldown.
 */
/obj/item/organ/cyberimp/cyberware/redline
	name = "\improper Redline core"
	desc = "A combat governor rebuilt to fail open, announced by a chest speaker nobody told you was in there."
	icon_state = "redline"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_OS
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 10
	tier = CYBERWARE_TIER_4
	aug_overlay = "redline"
	emissive_overlay = TRUE
	actions_types = list(/datum/action/cooldown/cyberware/redline_burn)
	// The burn's tuning lives on the organ so a cheaper or rougher model (see
	// ware_line_berserk.dm) retunes it by setting vars. The defaults below ARE
	// the Redline core's numbers. The defines stay as those defaults.
	/// Length of the burn window.
	var/burn_window = CYBERWARE_REDLINE_WINDOW
	/// Incoming brute/burn multiplier during the window.
	var/burn_damage_mult = CYBERWARE_REDLINE_DAMAGE_MULT
	/// Flat bonus to unarmed strikes during the window.
	var/burn_melee_bonus = CYBERWARE_REDLINE_MELEE_BONUS
	/// Whether the window grants stun and baton immunity.
	var/burn_stun_immune = TRUE
	/// Roar reach in tiles. 0 keeps the announcement but staggers nobody.
	var/burn_roar_range = CYBERWARE_REDLINE_ROAR_RANGE
	/// Crash slowdown duration.
	var/burn_crash = CYBERWARE_REDLINE_CRASH
	/// Stamina dumped by the crash.
	var/burn_crash_stamina = CYBERWARE_REDLINE_CRASH_STAMINA
	/// Cooldown on the Redline Burn button.
	var/burn_cooldown = 90 SECONDS
	/// Button tooltip. Null keeps the Redline Burn action's own text.
	var/burn_action_desc
	/// Status alert text while the window is open. Null keeps the alert's own text.
	var/burn_alert_desc

/obj/item/organ/cyberimp/cyberware/redline/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	organ_owner.remove_status_effect(/datum/status_effect/cyberware_redline_window)
	organ_owner.remove_status_effect(/datum/status_effect/cyberware_redline_crash)

/**
 * The EMP counter, Cascade parity (BAL-4): a pulse during the window forces
 * the crash immediately and re-arms the full cooldown, on top of the standard
 * chrome reboot ..() already started. Before this, Cascade carried the
 * mid-window EMP collapse and Redline quietly didn't, so the 12 seconds of
 * stun immunity and 40% resist rode straight through the one thing that is
 * supposed to answer them. Applying the same rule to both OS cores is the
 * conservative reading; not separately playtested.
 */
/obj/item/organ/cyberimp/cyberware/redline/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	if(!owner)
		return
	var/datum/status_effect/cyberware_redline_window/window = owner.has_status_effect(/datum/status_effect/cyberware_redline_window)
	if(!window)
		return
	to_chat(owner, span_userdanger("The pulse scrambles the core mid-burn and the strength drops out of you all at once!"))
	owner.remove_status_effect(/datum/status_effect/cyberware_redline_window) // on_remove applies the crash
	for(var/datum/action/cooldown/cyberware/redline_burn/burn in actions)
		burn.StartCooldown()

/datum/action/cooldown/cyberware/redline_burn
	name = "Redline Burn"
	desc = "Twelve seconds of stun immunity, 40% damage resistance and harder fists, opened with a staggering roar. Ends in a collapse."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_redline"
	cooldown_time = 90 SECONDS
	click_to_activate = FALSE

/datum/action/cooldown/cyberware/redline_burn/New(Target, original = TRUE)
	. = ..()
	// The core this button belongs to sets its own cooldown and tooltip.
	var/obj/item/organ/cyberimp/cyberware/redline/core = organ
	if(!istype(core))
		return
	cooldown_time = core.burn_cooldown
	if(core.burn_action_desc)
		desc = core.burn_action_desc

/datum/action/cooldown/cyberware/redline_burn/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/mob/living/burner = owner
	if(burner.has_status_effect(/datum/status_effect/cyberware_redline_window) || burner.has_status_effect(/datum/status_effect/cyberware_redline_crash))
		burner.balloon_alert(burner, "core still venting!")
		return FALSE
	StartCooldown()
	burner.apply_status_effect(/datum/status_effect/cyberware_redline_window, organ)
	return TRUE

/**
 * The window.
 *
 * The +8 rides the arm bodyparts' unarmed_damage_low/high, which is what the
 * species punch path actually rolls (_species.dm), so a normal punch gets the
 * bonus folded into its own roll, its own miss chance and its own armour
 * check. That is the right home for it and it stays there.
 *
 * It is not, however, where arm chrome reads from. Gorilla Arms
 * (ware_military_arms.dm) hooks [COMSIG_LIVING_EARLY_UNARMED_ATTACK], lands one
 * flat damage line of its own and returns COMPONENT_CANCEL_ATTACK_CHAIN, so the
 * species path never runs and the bodypart bonus never gets rolled. That is why
 * Redline and Gorilla did not stack.
 *
 * We cannot reach into that damage line: it takes no modifier, and signal
 * handlers fire in registration order, so a window opened by a button press
 * always runs AFTER chrome that registered at install time. What we can do is
 * watch the chain instead of the puncher. An early unarmed attack that never
 * reaches [COMSIG_LIVING_UNARMED_ATTACK] was taken over by something upstream,
 * and the window pays the +8 by hand on the next tick. A punch that does reach
 * the late signal stands the top-up down, so it can never pay twice.
 *
 * Deliberately written against the chain, not against Gorilla, any future
 * ware that swallows the punch chain gets the bonus for free.
 *
 * The one hole in "never reached the late signal means never paid" (D5): a
 * ware can swallow the chain AND still roll the bodypart itself. tg's
 * Strong-Arm implant and our own Scrapper's Knuckles both do exactly that,
 * their damage lines read unarmed_damage_low/high, which already carries the
 * +8, and then cancel the chain, so the top-up used to pay a second time on
 * top (Strong-Arm doubles its roll, so that hit was landing roughly +24
 * instead of +8). Those wares call cyberware_unarmed_roll_paid() to stand the
 * top-up down themselves. Gorilla Arms deliberately does not: its line is
 * flat and never reads the bodypart, so the top-up is the only way it sees
 * the bonus at all.
 */
/datum/status_effect/cyberware_redline_window
	id = "cyberware_redline_window"
	duration = CYBERWARE_REDLINE_WINDOW
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/cyberware_redline
	/// Arm bodyparts we buffed, so the teardown only unbuffs what we touched.
	var/list/buffed_parts = list()
	/// Victim of a punch that looks like it bypassed the standard attack chain.
	/// Cleared the moment the chain proves it survived.
	var/datum/weakref/bypassed_victim
	/// Armour penetration of the hand that threw that punch, so the top-up is
	/// blunted by armour exactly as much as the strike it belongs to.
	var/bypassed_penetration = 0
	/// One-shot: a ware has already paid this punch's arm bonus inside its own
	/// roll, so the next arming is skipped. See suppress_topup() for why this
	/// can't just clear the armed state.
	var/topup_suppressed = FALSE
	// Tuning. The defaults are the Redline core's own numbers; on_creation()
	// replaces them with the installed core's when one is passed in.
	/// Incoming brute/burn multiplier.
	var/damage_mult = CYBERWARE_REDLINE_DAMAGE_MULT
	/// Flat bonus to unarmed strikes.
	var/melee_bonus = CYBERWARE_REDLINE_MELEE_BONUS
	/// Whether the window grants stun and baton immunity.
	var/stun_immune = TRUE
	/// Roar reach in tiles, 0 for the announcement only.
	var/roar_range = CYBERWARE_REDLINE_ROAR_RANGE
	/// Handed to the crash this window rolls into.
	var/crash_duration = CYBERWARE_REDLINE_CRASH
	var/crash_stamina = CYBERWARE_REDLINE_CRASH_STAMINA
	/// Replaces the alert's description, if set.
	var/alert_desc

/// Pass the core whose numbers this burn runs on. Without one the window uses
/// the Redline core's own.
/datum/status_effect/cyberware_redline_window/on_creation(mob/living/new_owner, obj/item/organ/cyberimp/cyberware/redline/core)
	if(istype(core))
		duration = core.burn_window
		damage_mult = core.burn_damage_mult
		melee_bonus = core.burn_melee_bonus
		stun_immune = core.burn_stun_immune
		roar_range = core.burn_roar_range
		crash_duration = core.burn_crash
		crash_stamina = core.burn_crash_stamina
		alert_desc = core.burn_alert_desc
	. = ..()
	if(. && linked_alert && alert_desc)
		linked_alert.desc = alert_desc

/datum/status_effect/cyberware_redline_window/on_apply()
	// The anti-stun implant's buff pattern: traits plus damage-slowdown immunity.
	if(stun_immune)
		owner.add_traits(list(TRAIT_STUNIMMUNE, TRAIT_BATON_RESISTANCE), id)
	owner.add_movespeed_mod_immunities(id, /datum/movespeed_modifier/damage_slowdown)
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.physiology.brute_mod *= damage_mult
		human_owner.physiology.burn_mod *= damage_mult
	if(iscarbon(owner))
		var/mob/living/carbon/carbon_owner = owner
		for(var/obj/item/bodypart/arm/limb in carbon_owner.bodyparts)
			limb.unarmed_damage_low += melee_bonus
			limb.unarmed_damage_high += melee_bonus
			buffed_parts += limb
	RegisterSignal(owner, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_early_unarmed_attack))
	RegisterSignal(owner, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
	owner.add_client_colour(/datum/client_colour/cyberware_redline, id)
	// Everyone can see a bearer is burning: a red outline for the whole window, gone when it ends or they die
	owner.add_filter(id, 2, outline_filter(1, CYBERWARE_REDLINE_OUTLINE_COLOR))
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_bearer_death))
	owner.balloon_alert(owner, "REDLINE")
	INVOKE_ASYNC(src, PROC_REF(roar))
	// Red-hot nodes, red eyes, a red light (cyberware_anim2.dm).
	cyberware_redline_window_fx(owner)
	return TRUE

/// The burn's outline goes out with its bearer
/datum/status_effect/cyberware_redline_window/proc/on_bearer_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	source.remove_filter(id)

/datum/status_effect/cyberware_redline_window/on_remove()
	if(stun_immune)
		owner.remove_traits(list(TRAIT_STUNIMMUNE, TRAIT_BATON_RESISTANCE), id)
	owner.remove_movespeed_mod_immunities(id, /datum/movespeed_modifier/damage_slowdown)
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.physiology.brute_mod /= damage_mult
		human_owner.physiology.burn_mod /= damage_mult
	for(var/obj/item/bodypart/arm/limb as anything in buffed_parts)
		if(QDELETED(limb))
			continue
		limb.unarmed_damage_low -= melee_bonus
		limb.unarmed_damage_high -= melee_bonus
	buffed_parts.Cut()
	UnregisterSignal(owner, list(COMSIG_LIVING_EARLY_UNARMED_ATTACK, COMSIG_LIVING_UNARMED_ATTACK, COMSIG_LIVING_DEATH))
	owner.remove_filter(id)
	bypassed_victim = null
	bypassed_penetration = 0
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.apply_status_effect(/datum/status_effect/cyberware_redline_crash, crash_duration, crash_stamina)
	if(!QDELETED(owner))
		cyberware_redline_window_end_fx(owner)
	return ..()

/**
 * The opening roar: an AOE stagger for everything hostile in reach, plus a
 * genuine rout for any mob whose AI planner carries the flee-target subtree
 * (setting the blackboard key on anything else is a harmless no-op, we
 * promise flight only where the AI can deliver it).
 */
/datum/status_effect/cyberware_redline_window/proc/roar()
	if(QDELETED(owner))
		return
	playsound(owner, 'sound/effects/magic/demon_attack1.ogg', 90, TRUE)
	playsound(owner, 'sound/effects/magic/repulse.ogg', 60, TRUE)
	if(roar_range <= 0)
		// A core with no roar behind it still announces itself, just doesn't shake anything.
		owner.visible_message(
			span_boldwarning("[owner]'s eyes flood red and the speaker in [owner.p_their()] chest blares!"),
			span_boldwarning("Your chest speaker blares."),
		)
		return
	owner.visible_message(
		span_boldwarning("[owner]'s eyes flood red and a speaker-drone ROAR shakes the deck!"),
		span_boldwarning("You ROAR."),
	)
	cyberware_redline_roar_fx(owner, roar_range)
	for(var/mob/living/victim in oview(roar_range, owner))
		if(victim.stat == DEAD)
			continue
		if(cyberware_is_ally(owner, victim))
			continue
		victim.apply_status_effect(/datum/status_effect/staggered, 4 SECONDS)
		shake_camera(victim, 3, 1)
		victim.ai_controller?.set_blackboard_key(BB_BASIC_MOB_FLEE_TARGET, owner)
		to_chat(victim, span_userdanger("The roar hits like a physical wall!"))

/**
 * Signal proc for [COMSIG_LIVING_EARLY_UNARMED_ATTACK]. Arms a top-up for this
 * punch and hands the chain straight back, we never cancel anything and never
 * change what the punch itself does.
 */
/datum/status_effect/cyberware_redline_window/proc/on_early_unarmed_attack(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	bypassed_victim = null
	bypassed_penetration = 0
	// Consumed unconditionally, and this handler runs on every unarmed swing
	// the window sees, so a suppression raised by a ware whose own guards then
	// bailed can never outlive one punch.
	var/suppressed = topup_suppressed
	topup_suppressed = FALSE
	if(suppressed)
		return NONE
	// Harm punches on a living body only. Help intent, right-click, ranged
	// clicks and punching the scenery are none of our business.
	if(!proximity || !source.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		return NONE
	if(!isliving(target) || target == source)
		return NONE
	var/mob/living/victim = target
	if(victim.stat == DEAD)
		return NONE
	// UnarmedAttack() sends this signal BEFORE can_unarmed_attack() runs, so a
	// punch thrown with no usable hand never reaches the late signal either and
	// would otherwise read as a bypass.
	if(HAS_TRAIT(source, TRAIT_HANDS_BLOCKED) || !source.has_active_hand())
		return NONE
	if(iscarbon(source))
		var/mob/living/carbon/carbon_source = source
		var/obj/item/bodypart/active_hand = carbon_source.get_active_hand()
		bypassed_penetration = active_hand ? active_hand.unarmed_effectiveness : 0
	bypassed_victim = WEAKREF(victim)
	// Nothing runs synchronously after the whole attack chain, so settle up on
	// the next tick, by then on_unarmed_attack() has either stood us down or
	// stayed silent, and silence means something upstream ate the punch.
	addtimer(CALLBACK(src, PROC_REF(pay_bypassed_bonus)), 0)
	return NONE

/**
 * Signal proc for [COMSIG_LIVING_UNARMED_ATTACK]. Getting this far means
 * nothing upstream cancelled the punch, so the species attack path is about to
 * roll the arm bonus itself. Stand the top-up down.
 */
/datum/status_effect/cyberware_redline_window/proc/on_unarmed_attack(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	stand_down_topup()
	return NONE

/// Cancels the top-up armed by this punch's early signal.
/datum/status_effect/cyberware_redline_window/proc/stand_down_topup()
	bypassed_victim = null
	bypassed_penetration = 0

/**
 * A ware standing this punch's top-up down because its own roll already paid
 * the arm bonus (D5).
 *
 * Timing is the whole reason this isn't just stand_down_topup(). Handlers fire
 * in registration order, and a window opened by a button press registers AFTER
 * chrome that registered at install time, so the ware almost always calls this
 * BEFORE on_early_unarmed_attack() has armed anything, and there is nothing to
 * clear yet. Raising a one-shot the arming consumes covers that. Chrome
 * installed during a live window registers after us and hits the other order,
 * where clearing the armed state is the correct move; both are handled.
 */
/datum/status_effect/cyberware_redline_window/proc/suppress_topup()
	if(bypassed_victim)
		stand_down_topup()
		return
	topup_suppressed = TRUE

/**
 * "My damage line already rolled this hand's unarmed_damage_low/high."
 *
 * Punch-swallowing chrome calls this once it commits to taking a swing over.
 * Redline's arm bonus lives inside that roll, so the strike has already been
 * paid and must not also collect the bypass top-up. Safe to call from anyone,
 * any time; it is a no-op on a bearer with no Redline window open.
 */
/proc/cyberware_unarmed_roll_paid(mob/living/puncher)
	var/datum/status_effect/cyberware_redline_window/window = puncher?.has_status_effect(/datum/status_effect/cyberware_redline_window)
	window?.suppress_topup()

/**
 * The top-up, one tick after a punch that never reached the standard attack
 * chain, a Gorilla Arms piston punch, most of the time. CANT_WOUND on purpose:
 * the strike this belongs to already rolled its own wound, and one punch should
 * not get two.
 */
/datum/status_effect/cyberware_redline_window/proc/pay_bypassed_bonus()
	var/mob/living/victim = bypassed_victim?.resolve()
	var/penetration = bypassed_penetration
	bypassed_victim = null
	bypassed_penetration = 0
	if(QDELETED(victim) || QDELETED(owner))
		return
	var/target_zone = victim.get_random_valid_zone(owner.zone_selected)
	victim.apply_damage(
		melee_bonus,
		BRUTE,
		target_zone,
		victim.run_armor_check(target_zone, MELEE, armour_penetration = penetration, silent = TRUE),
		wound_bonus = CANT_WOUND,
	)
	log_combat(owner, victim, "redlined a bypassed unarmed strike on", "redline core")

/atom/movable/screen/alert/status_effect/cyberware_redline
	name = "Redline Burn"
	desc = "Every safety limit is off at once."
	icon_state = "radiation_shield"

/datum/status_effect/cyberware_redline_crash
	id = "cyberware_redline_crash"
	duration = CYBERWARE_REDLINE_CRASH
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null
	/// Stamina dumped on apply.
	var/stamina_dump = CYBERWARE_REDLINE_CRASH_STAMINA

/// The window hands over its core's crash length and stamina dump. Without
/// them the crash is the Redline core's own.
/datum/status_effect/cyberware_redline_crash/on_creation(mob/living/new_owner, new_duration, new_stamina_dump)
	if(!isnull(new_duration))
		duration = new_duration
	if(!isnull(new_stamina_dump))
		stamina_dump = new_stamina_dump
	return ..()

/datum/status_effect/cyberware_redline_crash/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash)
	owner.adjustStaminaLoss(stamina_dump)
	owner.add_client_colour(/datum/client_colour/cyberware_redline_crash, id)
	owner.visible_message(
		span_warning("[owner] sags as the red drains out of [owner.p_their()] eyes."),
		span_userdanger("The core slams shut and your legs go out from under you."),
	)
	owner.balloon_alert(owner, "redline collapse!")
	// The outline gutters out, the charge earths through the deck, the nodes cool, the body slumps (cyberware_anim2.dm).
	cyberware_redline_crash_fx(owner)
	return TRUE

/datum/status_effect/cyberware_redline_crash/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash)
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.balloon_alert(owner, "core recovered")
	if(!QDELETED(owner))
		cyberware_redline_crash_end_fx(owner)
	return ..()

/datum/movespeed_modifier/cyberware_redline_crash
	multiplicative_slowdown = 1.5

/// The window's screen: the red slam, bloodlust-pattern ease-in.
/datum/client_colour/cyberware_redline
	priority = CLIENT_COLOR_IMPORTANT_PRIORITY
	color = list(1, 0, 0, 0.55, 0.5, 0, 0.55, 0, 0.5)
	fade_in = 2
	fade_out = 10

/// The crash's screen: burnt out, brown-gray.
/datum/client_colour/cyberware_redline_crash
	priority = CLIENT_COLOR_ORGAN_PRIORITY
	color = list(0.6, 0.35, 0.3, 0.3, 0.5, 0.25, 0.25, 0.25, 0.45)
	fade_in = 3
	fade_out = 5

// =========================================================================
// GOVERNOR DELETE
// =========================================================================

/**
 * # Governor Delete (T4, chest OS, load 0, +15 capacity)
 *
 * The enabler: a neural governor with its limiter firmware deleted, worth
 * fifteen points of capacity and nothing else. Deliberately built on the
 * generic chrome base rather than tg's brain-implant subtype, the brain
 * base answers EMP with a stun. Here it browns out and reboots like every
 * other piece of chrome.
 */
/obj/item/organ/cyberimp/cyberware/governor_delete
	name = "\improper Governor Delete"
	desc = "A factory neural governor with its limiter firmware stripped out."
	icon_state = "governor_delete"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_OS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 0
	chrome_capacity_bonus = 15
	tier = CYBERWARE_TIER_4

// =========================================================================
// METEOR PILEDRIVER (contract-exclusive prototype)
// =========================================================================

/// Leap reach in tiles ("any visible tile", a full view ring).
#define CYBERWARE_PILEDRIVER_RANGE 8
/// Time between liftoff and impact: the dodge window under the shadow.
#define CYBERWARE_PILEDRIVER_AIRTIME (0.8 SECONDS)
/// Impact radius around the landing tile.
#define CYBERWARE_PILEDRIVER_IMPACT_RANGE 2
/// Brute dealt to everything in the impact ring.
#define CYBERWARE_PILEDRIVER_DAMAGE 20
/// How far victims are hurled from the impact point.
#define CYBERWARE_PILEDRIVER_THROW 2
/// Brute dealt to whoever is standing on the tile itself. tg's tipped vendor
/// deals 75 (/obj/machinery/vending.squish_damage); this sits a notch under it,
/// because unlike a vending machine this one paints the tile first.
#define CYBERWARE_PILEDRIVER_CRUSH_DAMAGE 60
/// Chance the crush spreads across the whole body instead of hammering limbs.
/// Tg's prob(30) in [/atom/movable/proc/fall_and_crush], and the roll that
/// decides whether your skeleton survives being landed on.
#define CYBERWARE_PILEDRIVER_CRUSH_SPREAD_CHANCE 30
/// Wound bonus on each limb hit. tg's crush uses 5, which is what actually
/// produces the blunt bone wounds.
#define CYBERWARE_PILEDRIVER_CRUSH_WOUND 5
/// How long a direct hit leaves you on the deck.
#define CYBERWARE_PILEDRIVER_CRUSH_PARALYZE (3 SECONDS)
/// How long the flattened sprite sticks around afterward.
#define CYBERWARE_PILEDRIVER_CRUSH_SQUISH (30 SECONDS)

/**
 * # Meteor Piledriver (prototype, legs, load 8, never sold)
 *
 * Vex's hard-contract exclusive, and the top of the Shock Coils -> Hopper
 * leg ladder. Click any open tile you can see and reach in a straight line, or
 * a person standing on one: you launch, a landing shadow paints the tile for
 * most of a second (the warframe rule, telegraphed, dodgeable), and then you
 * arrive like ordnance. The arc clears tables, railings and crates; it does
 * not cross walls, windows, grilles or shut doors, see
 * [/datum/action/cooldown/cyberware/proc/arc_blocker].
 *
 * Whoever is still standing on the marked tile when the boots arrive gets
 * crushed, on tg's tipped-vending-machine pattern: heavy brute driven into
 * random limbs, which is what snaps bone, plus a paralyze and the flattened
 * sprite. Everything in the two tiles around them only catches the shockwave,
 * 20 brute, knocked flat through stun resistance, hurled clear, and every
 * screen in view shakes.
 *
 * The tile is locked in at liftoff, not at landing, so the shadow never lies:
 * step off it and the boots come down on empty deck. The shockwave does not
 * discriminate either, crewmates under the shadow have most of a second to be
 * somewhere else.
 */
/obj/item/organ/cyberimp/cyberware/piledriver
	name = "\improper Meteor Piledriver frame"
	desc = "Prototype launch pistons sleeved over both legs, running into a gyroscopic landing computer that aims you at the floor."
	icon_state = "piledriver"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_CYBERWARE_LEGS
	// Either calf is a valid incision site; see the Shock Coils for the why.
	valid_zones = list(
		BODY_ZONE_L_LEG = ORGAN_SLOT_CYBERWARE_LEGS,
		BODY_ZONE_R_LEG = ORGAN_SLOT_CYBERWARE_LEGS,
	)
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 8
	tier = CYBERWARE_TIER_4
	aug_overlay = "piledriver"
	actions_types = list(/datum/action/cooldown/cyberware/piledriver_leap)

/// The landing shadow: the skyfall indicator pattern, sized for our impact
/// ring. Fades in over the airtime so the warning grows as the boots close.
/obj/effect/temp_visual/cyberware_piledriver_shadow
	name = "looming shadow"
	desc = "Something very heavy is about to land on this exact spot."
	icon = 'icons/mob/telegraphing/telegraph_96x96.dmi'
	icon_state = "target_largebox"
	// Painted on the floor: under whoever stands in it, on every row it covers.
	plane = FLOOR_PLANE
	layer = LOWER_RUNE_LAYER
	pixel_x = -32
	pixel_y = -32
	alpha = 0
	duration = CYBERWARE_PILEDRIVER_AIRTIME

/obj/effect/temp_visual/cyberware_piledriver_shadow/Initialize(mapload)
	. = ..()
	animate(src, alpha = 255, time = duration, easing = CIRCULAR_EASING|EASE_OUT)

/datum/action/cooldown/cyberware/piledriver_leap
	name = "Meteor Leap"
	desc = "Launch onto a tile you can see, or onto somebody standing on one. A direct hit crushes whoever is still there, and everything within two tiles is knocked flat."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_piledriver"
	cooldown_time = 60 SECONDS
	click_to_activate = TRUE
	// A stunned, paralysed or bound body does not get to leap out of it.
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_IMMOBILE

/datum/action/cooldown/cyberware/piledriver_leap/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/mob/living/jumper = owner
	var/turf/destination = get_turf(target)
	var/turf/here = get_turf(jumper)
	if(isnull(destination) || isnull(here) || destination == here)
		return FALSE
	// The landing crushes whoever is under it, so it is not for a pacifist.
	if(HAS_TRAIT(jumper, TRAIT_PACIFISM))
		to_chat(jumper, span_warning("You don't want to harm other living beings!"))
		return FALSE
	if(jumper.buckled || !isturf(jumper.loc))
		jumper.balloon_alert(jumper, "can't launch from here!")
		return FALSE
	if(get_dist(here, destination) > CYBERWARE_PILEDRIVER_RANGE)
		jumper.balloon_alert(jumper, "too far!")
		return FALSE
	if(!can_see(jumper, destination, CYBERWARE_PILEDRIVER_RANGE))
		jumper.balloon_alert(jumper, "no line of sight!")
		return FALSE
	// exclude_mobs: a body standing there is a target, not an obstruction. This
	// is what lets you aim at a person instead of the deck beside them.
	if(destination.is_blocked_turf(exclude_mobs = TRUE) || islava(destination) || ischasm(destination))
		jumper.balloon_alert(jumper, "no landing surface!")
		return FALSE
	if(arc_blocker(here, destination))
		jumper.balloon_alert(jumper, "no room for the arc!")
		return FALSE
	// The shadow goes down and the landing hurts someone.
	cyberware_camo_drop(jumper)
	StartCooldown()
	// Liftoff: locked in for the whole arc, committed, like everything
	// with this much telegraph. The TILE is what gets locked, never the mob,
	// so the shadow the room is looking at is always where you actually land.
	jumper.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), REF(src))
	jumper.face_atom(destination)
	var/launch_message = "You launch. The landing computer handles the rest."
	if(isliving(target))
		launch_message = "You launch. The landing computer locks onto [target]."
	jumper.visible_message(
		span_boldwarning("[jumper]'s leg pistons CRACK the deck and [jumper.p_they()] launch[jumper.p_es()] skyward!"),
		span_warning(launch_message),
	)
	playsound(here, 'sound/effects/gravhit.ogg', 70, TRUE)
	new /obj/effect/temp_visual/cyberware_piledriver_shadow(destination)
	// Up off the deck and over to the mark; the body stays on its tile until it lands (cyberware_anim2.dm).
	cyberware_leap_takeoff_fx(jumper, here, destination, CYBERWARE_PILEDRIVER_AIRTIME, 64, 64)
	addtimer(CALLBACK(src, PROC_REF(land), destination), CYBERWARE_PILEDRIVER_AIRTIME)
	return TRUE

/**
 * Impact. Two separate things happen here.
 *
 * Anyone still standing on the marked tile is a direct hit and gets crushed,
 * see [proc/crush_victim]. Everyone ELSE within two tiles catches the shockwave
 * on the warframe ground-slam pattern: damage, named-argument knockdown through
 * stun resistance, hurl, and a camera quake for the room. Nobody eats both for
 * one landing.
 */
/datum/action/cooldown/cyberware/piledriver_leap/proc/land(turf/destination)
	var/mob/living/jumper = owner
	if(QDELETED(jumper))
		return
	jumper.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), REF(src))
	cyberware_leap_touchdown_fx(jumper)
	if(jumper.stat == DEAD)
		return
	// The marked tile can stop existing mid-flight (someone blows the floor out
	// from under the shadow), and a deleted turf has no coordinates left to
	// search around, bail rather than hunt from a dead reference.
	var/turf/final = destination
	if(QDELETED(final))
		jumper.balloon_alert(jumper, "landing fouled!")
		return
	// exclude_mobs again: a body on the tile is the point of the landing, not a
	// reason to shunt us onto the tile next door.
	if(final.is_blocked_turf(exclude_mobs = TRUE))
		final = null
		for(var/turf/candidate in shuffle(RANGE_TURFS(1, destination)))
			if(!candidate.is_blocked_turf(exclude_mobs = TRUE) && !islava(candidate) && !ischasm(candidate))
				final = candidate
				break
	if(!final)
		jumper.balloon_alert(jumper, "landing fouled!")
		return
	// Snapshot the tile's occupants before we move onto it.
	var/list/mob/living/crushed = list()
	for(var/mob/living/pinned in final)
		if(pinned == jumper || pinned.stat == DEAD)
			continue
		crushed += pinned
	jumper.forceMove(final)
	playsound(final, 'sound/effects/meteorimpact.ogg', 90, TRUE)
	cyberware_grey_dust(final)
	cyberware_piledriver_impact_fx(final, CYBERWARE_PILEDRIVER_IMPACT_RANGE)
	for(var/mob/living/victim as anything in crushed)
		crush_victim(jumper, victim)
	for(var/mob/living/victim in oview(CYBERWARE_PILEDRIVER_IMPACT_RANGE, final))
		if(victim == jumper || victim.stat == DEAD || (victim in crushed))
			continue
		victim.apply_damage(CYBERWARE_PILEDRIVER_DAMAGE, BRUTE, spread_damage = TRUE)
		victim.Knockdown(1.5 SECONDS, ignore_canstun = TRUE)
		var/throw_dir = get_dir(final, victim) || pick(GLOB.cardinals)
		var/atom/landing_edge = get_edge_target_turf(victim, throw_dir)
		victim.safe_throw_at(landing_edge, CYBERWARE_PILEDRIVER_THROW, 2, jumper)
		victim.visible_message(
			span_boldwarning("The shockwave takes [victim] off [victim.p_their()] feet!"),
			span_userdanger("[jumper] lands like ordnance and the shockwave hurls you flat!"),
		)
	for(var/mob/living/witness in view(7, final))
		shake_camera(witness, 6, 2)
	jumper.visible_message(
		span_boldwarning("[jumper] lands like a meteor, the deck jumps!"),
		span_notice("You land. The deck takes most of it."),
	)

/**
 * A direct hit: the boots come down on a tile somebody is still standing on.
 *
 * Lifted from tg's tipped vending machine ([/atom/movable/proc/fall_and_crush],
 * code/modules/vending/_vending.dm) because that is exactly the feeling asked
 * for. The important part is the split: most of the time the damage goes into
 * two random limbs, which is what actually produces blunt bone wounds
 * (/datum/wound/blunt/bone); the rest of the time it spreads over the whole
 * body, hurts just as much, and the skeleton comes out intact. Then the
 * paralyze, the flattened sprite and the scream, same as the vendor.
 *
 * Crushed victims are excluded from the shockwave pass in [proc/land], one
 * landing, one helping.
 */
/datum/action/cooldown/cyberware/piledriver_leap/proc/crush_victim(mob/living/jumper, mob/living/victim)
	if(QDELETED(victim) || QDELETED(jumper))
		return
	if(iscarbon(victim))
		var/mob/living/carbon/carbon_victim = victim
		if(should_spread_crush_damage())
			carbon_victim.apply_damage(
				CYBERWARE_PILEDRIVER_CRUSH_DAMAGE,
				BRUTE,
				blocked = 0, // Forced damage bypasses armor, including nanite armor accounting.
				forced = TRUE,
				spread_damage = TRUE,
				attack_direction = jumper.dir,
			)
		else
			var/half = CYBERWARE_PILEDRIVER_CRUSH_DAMAGE * 0.5
			carbon_victim.take_bodypart_damage(half, 0, check_armor = TRUE, wound_bonus = CYBERWARE_PILEDRIVER_CRUSH_WOUND)
			carbon_victim.take_bodypart_damage(half, 0, check_armor = TRUE, wound_bonus = CYBERWARE_PILEDRIVER_CRUSH_WOUND)
		carbon_victim.AddElement(/datum/element/squish, CYBERWARE_PILEDRIVER_CRUSH_SQUISH)
	else
		victim.apply_damage(
			CYBERWARE_PILEDRIVER_CRUSH_DAMAGE,
			BRUTE,
			blocked = 0,
			forced = TRUE,
			attack_direction = jumper.dir,
		)
	victim.Paralyze(CYBERWARE_PILEDRIVER_CRUSH_PARALYZE, ignore_canstun = TRUE)
	victim.emote("scream")
	playsound(victim, 'sound/effects/blob/blobattack.ogg', 40, TRUE)
	playsound(victim, 'sound/effects/splat.ogg', 50, TRUE)
	victim.visible_message(
		span_boldwarning("[jumper] comes down square on top of [victim]. You hear something inside [victim.p_them()] go!"),
		span_userdanger("[jumper] lands on you with the whole weight of the frame behind [jumper.p_them()]. Things break."),
	)
	log_combat(jumper, victim, "crushed with a Meteor Piledriver landing")

/datum/action/cooldown/cyberware/piledriver_leap/proc/should_spread_crush_damage()
	return prob(CYBERWARE_PILEDRIVER_CRUSH_SPREAD_CHANCE)

#undef CYBERWARE_CASCADE_WINDOW
#undef CYBERWARE_CASCADE_CRASH
#undef CYBERWARE_CASCADE_DODGE_CHANCE
#undef CYBERWARE_CASCADE_CRASH_STAMINA
#undef CYBERWARE_CASCADE_HUE_STEP
#undef CYBERWARE_REDLINE_WINDOW
#undef CYBERWARE_REDLINE_DAMAGE_MULT
#undef CYBERWARE_REDLINE_MELEE_BONUS
#undef CYBERWARE_REDLINE_ROAR_RANGE
#undef CYBERWARE_REDLINE_CRASH_STAMINA
#undef CYBERWARE_REDLINE_CRASH
#undef CYBERWARE_REDLINE_OUTLINE_COLOR
#undef CYBERWARE_PILEDRIVER_RANGE
#undef CYBERWARE_PILEDRIVER_AIRTIME
#undef CYBERWARE_PILEDRIVER_IMPACT_RANGE
#undef CYBERWARE_PILEDRIVER_DAMAGE
#undef CYBERWARE_PILEDRIVER_THROW
#undef CYBERWARE_PILEDRIVER_CRUSH_DAMAGE
#undef CYBERWARE_PILEDRIVER_CRUSH_SPREAD_CHANCE
#undef CYBERWARE_PILEDRIVER_CRUSH_WOUND
#undef CYBERWARE_PILEDRIVER_CRUSH_PARALYZE
#undef CYBERWARE_PILEDRIVER_CRUSH_SQUISH
