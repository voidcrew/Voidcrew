/**
 * # Tier 4 legend chrome + the Piledriver prototype
 *
 * Cascade Lattice, Redline Core, Governor Delete, Meteor Piledriver.
 *
 * The two OS cores share the chest OS slot — installing one evicts the
 * other, the CP2077 operating-system choice. Both are windowed powers with
 * a crash on the back end; per the design freeze the crash IS the balance,
 * because ambient EMP threat is thin. Cascade additionally treats any EMP
 * during its window as an instant crash plus a full recooldown — the
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

/**
 * # Cascade Lattice (T4, chest, OS slot, load 12)
 *
 * The sandevistan-class flagship. Eight seconds where the world happens at
 * your speed: a full -1 gait (with reagent-modifier immunity for the
 * duration — no meth stacking, no sub-tick movement), melee cooldowns
 * halved, and 40% ranged dodge while moving through the shared arbiter in
 * ware_pro_combat.dm. Everyone nearby sees it: afterimages peel off every
 * step, your victim's screen never had a chance, and the activation is an
 * audible time-tear.
 *
 * Then the heat bill: six seconds of crash — heavy stamina dump, leaden
 * slowdown, zero dodge. An EMP during the window skips straight to the
 * crash and re-arms the full sixty-second cooldown.
 */
/obj/item/organ/cyberimp/cyberware/cascade
	name = "\improper Cascade lattice"
	desc = "A full-spine lattice of superconducting myelin. For eight seconds at a time the rest of the galaxy is a still photograph you are walking through; then the heat bill arrives, all at once."
	icon_state = "cascade"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_OS
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 12
	tier = CYBERWARE_TIER_4
	aug_overlay = "cascade"
	emissive_overlay = TRUE
	actions_types = list(/datum/action/cooldown/cyberware/cascade_surge)

/obj/item/organ/cyberimp/cyberware/cascade/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	// Pulling the lattice mid-cycle takes its statuses with it. Removing the
	// window this way still applies the crash — the heat is already in you.
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
	to_chat(owner, span_userdanger("The pulse rips through the lattice mid-cascade — everything slams back to real time!"))
	owner.remove_status_effect(/datum/status_effect/cyberware_cascade_window) // on_remove applies the crash
	for(var/datum/action/cooldown/cyberware/cascade_surge/surge in actions)
		surge.StartCooldown()

/datum/action/cooldown/cyberware/cascade_surge
	name = "Cascade Surge"
	desc = "Eight seconds of overwhelming speed — halved melee cooldowns, 40% ranged dodge on the move — followed by six seconds of crash. EMP mid-window forces the crash instantly."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
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
	surger.apply_status_effect(/datum/status_effect/cyberware_cascade_window)
	return TRUE

/**
 * The window. All the speed lives here so one teardown path handles natural
 * expiry, EMP shutdown and chrome removal alike — and every teardown of a
 * live window on a living bearer rolls straight into the crash.
 */
/datum/status_effect/cyberware_cascade_window
	id = "cyberware_cascade_window"
	duration = CYBERWARE_CASCADE_WINDOW
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/cyberware_cascade

/datum/status_effect/cyberware_cascade_window/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_cascade)
	owner.add_movespeed_mod_immunities(id, /datum/movespeed_modifier/reagent)
	cyberware_register_dodge_source(owner, id, CALLBACK(src, PROC_REF(get_dodge_chance)))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
	owner.add_client_colour(/datum/client_colour/cyberware_cascade, id)
	playsound(owner, 'sound/effects/magic/timeparadox2.ogg', 70, TRUE)
	owner.visible_message(
		span_boldwarning("[owner] fractures into afterimages — something under [owner.p_their()] skin is running far too fast!"),
		span_boldnotice("CASCADE ONLINE. Eight seconds."),
	)
	owner.balloon_alert(owner, "cascade online")
	return TRUE

/datum/status_effect/cyberware_cascade_window/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_cascade)
	owner.remove_movespeed_mod_immunities(id, /datum/movespeed_modifier/reagent)
	cyberware_unregister_dodge_source(owner, id)
	UnregisterSignal(owner, COMSIG_MOVABLE_MOVED)
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.apply_status_effect(/datum/status_effect/cyberware_cascade_crash)
	return ..()

/// Melee cooldowns halved for the window (changeNext_move multiplies these in).
/datum/status_effect/cyberware_cascade_window/nextmove_modifier()
	return 0.5

/// Dodge-source callback for the shared arbiter: flat 40 while the window
/// lives (the arbiter itself enforces moving-only and point-blank rules).
/datum/status_effect/cyberware_cascade_window/proc/get_dodge_chance()
	return CYBERWARE_CASCADE_DODGE_CHANCE

/// Signal proc for [COMSIG_MOVABLE_MOVED]: one afterimage per step — the
/// telegraph everyone in the fight can read.
/datum/status_effect/cyberware_cascade_window/proc/on_move(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(isturf(old_loc))
		new /obj/effect/temp_visual/decoy/fading/halfsecond(old_loc, owner)

/atom/movable/screen/alert/status_effect/cyberware_cascade
	name = "Cascade Window"
	desc = "The lattice is running the world in slow motion. Spend it well — the crash is already scheduled."
	icon_state = "radiation_shield"

/// The bill. No dodge source, no speed — the opposite of all of it.
/datum/status_effect/cyberware_cascade_crash
	id = "cyberware_cascade_crash"
	duration = CYBERWARE_CASCADE_CRASH
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/cyberware_cascade_crash/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_cascade_crash)
	owner.adjustStaminaLoss(CYBERWARE_CASCADE_CRASH_STAMINA)
	owner.add_client_colour(/datum/client_colour/cyberware_cascade_crash, id)
	playsound(owner, 'sound/machines/warning-buzzer.ogg', 50, TRUE)
	owner.visible_message(
		span_warning("[owner] staggers, every movement suddenly leaden."),
		span_userdanger("The lattice dumps its heat. Your whole body drops into treacle."),
	)
	owner.balloon_alert(owner, "cascade crash!")
	return TRUE

/datum/status_effect/cyberware_cascade_crash/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_cascade_crash)
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.balloon_alert(owner, "systems restabilized")
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

/**
 * # Redline Core (T4, chest, OS slot, load 10)
 *
 * The rage OS to Cascade's speed OS — same slot, pick one. Twelve seconds:
 * stun immunity (anti-stun buff pattern), 40% less brute and burn, +8 on
 * every unarmed strike, and an opening roar that staggers everything
 * hostile nearby — mobs whose AI carries the flee subtree genuinely run;
 * everything else just stumbles. Your screen slams red and stays there,
 * and everyone else gets a mob that visibly is not stopping.
 *
 * Then the collapse: a hundred stamina, leaden legs, and whatever you
 * didn't finish is now standing over you.
 */
/obj/item/organ/cyberimp/cyberware/redline
	name = "\improper Redline core"
	desc = "A combat governor rebuilt to fail open. Twelve seconds of every safety margin spent at once, opened with a roar from a speaker you didn't know they installed."
	icon_state = "redline"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_OS
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 10
	tier = CYBERWARE_TIER_4
	aug_overlay = "redline"
	emissive_overlay = TRUE
	actions_types = list(/datum/action/cooldown/cyberware/redline_burn)

/obj/item/organ/cyberimp/cyberware/redline/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	organ_owner.remove_status_effect(/datum/status_effect/cyberware_redline_window)
	organ_owner.remove_status_effect(/datum/status_effect/cyberware_redline_crash)

/datum/action/cooldown/cyberware/redline_burn
	name = "Redline Burn"
	desc = "Twelve seconds of stun immunity, 40% damage resistance and harder fists, opened with a staggering roar. Ends in a stamina collapse."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	cooldown_time = 90 SECONDS
	click_to_activate = FALSE

/datum/action/cooldown/cyberware/redline_burn/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/mob/living/burner = owner
	if(burner.has_status_effect(/datum/status_effect/cyberware_redline_window) || burner.has_status_effect(/datum/status_effect/cyberware_redline_crash))
		burner.balloon_alert(burner, "core still venting!")
		return FALSE
	StartCooldown()
	burner.apply_status_effect(/datum/status_effect/cyberware_redline_window)
	return TRUE

/datum/status_effect/cyberware_redline_window
	id = "cyberware_redline_window"
	duration = CYBERWARE_REDLINE_WINDOW
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/cyberware_redline
	/// Arm bodyparts we buffed, so the teardown only unbuffs what we touched.
	var/list/buffed_parts = list()

/datum/status_effect/cyberware_redline_window/on_apply()
	// The anti-stun implant's buff pattern: traits plus damage-slowdown immunity.
	owner.add_traits(list(TRAIT_STUNIMMUNE, TRAIT_BATON_RESISTANCE), id)
	owner.add_movespeed_mod_immunities(id, /datum/movespeed_modifier/damage_slowdown)
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.physiology.brute_mod *= CYBERWARE_REDLINE_DAMAGE_MULT
		human_owner.physiology.burn_mod *= CYBERWARE_REDLINE_DAMAGE_MULT
	if(iscarbon(owner))
		var/mob/living/carbon/carbon_owner = owner
		for(var/obj/item/bodypart/arm/limb in carbon_owner.bodyparts)
			limb.unarmed_damage_low += CYBERWARE_REDLINE_MELEE_BONUS
			limb.unarmed_damage_high += CYBERWARE_REDLINE_MELEE_BONUS
			buffed_parts += limb
	owner.add_client_colour(/datum/client_colour/cyberware_redline, id)
	owner.balloon_alert(owner, "REDLINE")
	INVOKE_ASYNC(src, PROC_REF(roar))
	return TRUE

/datum/status_effect/cyberware_redline_window/on_remove()
	owner.remove_traits(list(TRAIT_STUNIMMUNE, TRAIT_BATON_RESISTANCE), id)
	owner.remove_movespeed_mod_immunities(id, /datum/movespeed_modifier/damage_slowdown)
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.physiology.brute_mod /= CYBERWARE_REDLINE_DAMAGE_MULT
		human_owner.physiology.burn_mod /= CYBERWARE_REDLINE_DAMAGE_MULT
	for(var/obj/item/bodypart/arm/limb as anything in buffed_parts)
		if(QDELETED(limb))
			continue
		limb.unarmed_damage_low -= CYBERWARE_REDLINE_MELEE_BONUS
		limb.unarmed_damage_high -= CYBERWARE_REDLINE_MELEE_BONUS
	buffed_parts.Cut()
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.apply_status_effect(/datum/status_effect/cyberware_redline_crash)
	return ..()

/**
 * The opening roar: an AOE stagger for everything hostile in reach, plus a
 * genuine rout for any mob whose AI planner carries the flee-target subtree
 * (setting the blackboard key on anything else is a harmless no-op — we
 * promise flight only where the AI can deliver it).
 */
/datum/status_effect/cyberware_redline_window/proc/roar()
	if(QDELETED(owner))
		return
	playsound(owner, 'sound/effects/magic/demon_attack1.ogg', 90, TRUE)
	playsound(owner, 'sound/effects/magic/repulse.ogg', 60, TRUE)
	owner.visible_message(
		span_boldwarning("[owner]'s eyes flood red and a speaker-drone ROAR shakes the deck!"),
		span_boldwarning("You ROAR."),
	)
	for(var/mob/living/victim in oview(CYBERWARE_REDLINE_ROAR_RANGE, owner))
		if(victim.stat == DEAD)
			continue
		if(cyberware_is_ally(owner, victim))
			continue
		victim.apply_status_effect(/datum/status_effect/staggered, 4 SECONDS)
		shake_camera(victim, 3, 1)
		victim.ai_controller?.set_blackboard_key(BB_BASIC_MOB_FLEE_TARGET, owner)
		to_chat(victim, span_userdanger("The roar hits like a physical wall!"))

/atom/movable/screen/alert/status_effect/cyberware_redline
	name = "Redline Burn"
	desc = "Every safety margin, spent at once. Stuns bounce off, hits land soft, your fists don't. The collapse is already scheduled."
	icon_state = "radiation_shield"

/datum/status_effect/cyberware_redline_crash
	id = "cyberware_redline_crash"
	duration = CYBERWARE_REDLINE_CRASH
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/cyberware_redline_crash/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash)
	owner.adjustStaminaLoss(CYBERWARE_REDLINE_CRASH_STAMINA)
	owner.add_client_colour(/datum/client_colour/cyberware_redline_crash, id)
	owner.visible_message(
		span_warning("[owner] sags as the red drains out of [owner.p_their()] eyes."),
		span_userdanger("The core slams shut and your legs stop being yours."),
	)
	owner.balloon_alert(owner, "redline collapse!")
	return TRUE

/datum/status_effect/cyberware_redline_crash/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_redline_crash)
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.balloon_alert(owner, "core recovered")
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
 * # Governor Delete (T4, head, governor slot, load 0, +6 capacity)
 *
 * The enabler: a neural governor with its limiter firmware deleted, worth
 * six points of chrome capacity and nothing else. Deliberately built on the
 * generic chrome base rather than tg's brain-implant subtype — the brain
 * base answers EMP with a 200/severity stun, which on a PvP server would
 * turn a one-voucher grenade into an execution button. Here it browns out
 * and reboots like every other piece of chrome.
 */
/obj/item/organ/cyberimp/cyberware/governor_delete
	name = "\improper Governor Delete"
	desc = "A factory neural governor with the governing surgically absent. The little sticker where the safety certification used to be just says sorry."
	icon_state = "governor_delete"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_GOVERNOR
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 0
	chrome_capacity_bonus = 6
	tier = CYBERWARE_TIER_4

// =========================================================================
// METEOR PILEDRIVER (contract-exclusive prototype)
// =========================================================================

/// Leap reach in tiles ("any visible tile" — a full view ring).
#define CYBERWARE_PILEDRIVER_RANGE 8
/// Time between liftoff and impact — the dodge window under the shadow.
#define CYBERWARE_PILEDRIVER_AIRTIME (0.8 SECONDS)
/// Impact radius around the landing tile.
#define CYBERWARE_PILEDRIVER_IMPACT_RANGE 2
/// Brute dealt to everything in the impact ring.
#define CYBERWARE_PILEDRIVER_DAMAGE 20
/// How far victims are hurled from the impact point.
#define CYBERWARE_PILEDRIVER_THROW 2

/**
 * # Meteor Piledriver (prototype, legs, load 8 — never sold)
 *
 * Vex's hard-contract exclusive, and the top of the Shock Coils -> Hopper
 * leg ladder. Click any visible open tile: you launch, a landing shadow
 * paints the tile for most of a second (the warframe rule — telegraphed,
 * dodgeable), and then you arrive like ordnance. Everything in two tiles
 * takes 20 brute, gets knocked flat through stun resistance, and is hurled
 * clear; every screen in view shakes. The shockwave does not discriminate —
 * crewmates under the shadow have most of a second to be elsewhere.
 */
/obj/item/organ/cyberimp/cyberware/piledriver
	name = "\improper Meteor Piledriver frame"
	desc = "Prototype launch pistons sleeved over both legs, mated to a gyroscopic landing computer that treats the floor as a target. The shadow arrives first, as a courtesy."
	icon_state = "piledriver"
	zone = BODY_ZONE_L_LEG
	slot = ORGAN_SLOT_CYBERWARE_LEGS
	w_class = WEIGHT_CLASS_NORMAL
	chrome_load = 8
	tier = CYBERWARE_TIER_4
	aug_overlay = "piledriver"
	actions_types = list(/datum/action/cooldown/cyberware/piledriver_leap)

/// The landing shadow: the skyfall indicator pattern, sized for our impact
/// ring. Fades in over the airtime so the warning grows as the boots close.
/obj/effect/temp_visual/cyberware_piledriver_shadow
	name = "looming shadow"
	desc = "Something with a lot of momentum has opinions about this exact spot."
	icon = 'icons/mob/telegraphing/telegraph_96x96.dmi'
	icon_state = "target_largebox"
	layer = BELOW_MOB_LAYER
	pixel_x = -32
	pixel_y = -32
	alpha = 0
	duration = CYBERWARE_PILEDRIVER_AIRTIME

/obj/effect/temp_visual/cyberware_piledriver_shadow/Initialize(mapload)
	. = ..()
	animate(src, alpha = 255, time = duration, easing = CIRCULAR_EASING|EASE_OUT)

/datum/action/cooldown/cyberware/piledriver_leap
	name = "Meteor Leap"
	desc = "Launch to any visible open tile. The landing shadow warns everyone underneath; the landing knocks flat, hurls, and shakes everything for two tiles."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "sniper_zoom"
	cooldown_time = 25 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/cyberware/piledriver_leap/Activate(atom/target)
	if(!isliving(owner))
		return FALSE
	var/mob/living/jumper = owner
	var/turf/destination = get_turf(target)
	var/turf/here = get_turf(jumper)
	if(isnull(destination) || isnull(here) || destination == here)
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
	if(destination.is_blocked_turf() || islava(destination) || ischasm(destination))
		jumper.balloon_alert(jumper, "no landing surface!")
		return FALSE
	StartCooldown()
	// Liftoff: locked in for the whole arc — committed, like everything
	// with this much telegraph.
	jumper.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), REF(src))
	jumper.face_atom(destination)
	jumper.visible_message(
		span_boldwarning("[jumper]'s leg pistons CRACK the deck and [jumper.p_they()] launch[jumper.p_es()] skyward!"),
		span_warning("You launch. The floor picks where you stop."),
	)
	playsound(here, 'sound/effects/gravhit.ogg', 70, TRUE)
	new /obj/effect/temp_visual/mook_dust(here)
	new /obj/effect/temp_visual/cyberware_piledriver_shadow(destination)
	animate(jumper, pixel_z = 64, time = CYBERWARE_PILEDRIVER_AIRTIME * 0.5, flags = ANIMATION_RELATIVE, easing = QUAD_EASING|EASE_OUT)
	addtimer(CALLBACK(src, PROC_REF(land), destination), CYBERWARE_PILEDRIVER_AIRTIME)
	return TRUE

/// Impact. The warframe ground-slam pattern: damage, named-argument
/// knockdown through stun resistance, hurl, and a camera quake for the room.
/datum/action/cooldown/cyberware/piledriver_leap/proc/land(turf/destination)
	var/mob/living/jumper = owner
	if(QDELETED(jumper))
		return
	jumper.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), REF(src))
	animate(jumper, pixel_z = -64, time = 0.1 SECONDS, flags = ANIMATION_RELATIVE)
	if(jumper.stat == DEAD)
		return
	var/turf/final = destination
	if(QDELETED(final) || final.is_blocked_turf())
		final = null
		for(var/turf/candidate in shuffle(RANGE_TURFS(1, destination)))
			if(!candidate.is_blocked_turf() && !islava(candidate) && !ischasm(candidate))
				final = candidate
				break
	if(!final)
		jumper.balloon_alert(jumper, "landing fouled!")
		return
	jumper.forceMove(final)
	playsound(final, 'sound/effects/meteorimpact.ogg', 90, TRUE)
	new /obj/effect/temp_visual/mook_dust(final)
	for(var/mob/living/victim in oview(CYBERWARE_PILEDRIVER_IMPACT_RANGE, final))
		if(victim == jumper || victim.stat == DEAD)
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
		span_boldwarning("[jumper] lands like a meteor — the deck jumps!"),
		span_notice("You arrive. The floor files a complaint."),
	)

#undef CYBERWARE_CASCADE_WINDOW
#undef CYBERWARE_CASCADE_CRASH
#undef CYBERWARE_CASCADE_DODGE_CHANCE
#undef CYBERWARE_CASCADE_CRASH_STAMINA
#undef CYBERWARE_REDLINE_WINDOW
#undef CYBERWARE_REDLINE_DAMAGE_MULT
#undef CYBERWARE_REDLINE_MELEE_BONUS
#undef CYBERWARE_REDLINE_ROAR_RANGE
#undef CYBERWARE_REDLINE_CRASH_STAMINA
#undef CYBERWARE_REDLINE_CRASH
#undef CYBERWARE_PILEDRIVER_RANGE
#undef CYBERWARE_PILEDRIVER_AIRTIME
#undef CYBERWARE_PILEDRIVER_IMPACT_RANGE
#undef CYBERWARE_PILEDRIVER_DAMAGE
#undef CYBERWARE_PILEDRIVER_THROW
