/**
 * # Tier 4 legend chrome + the Piledriver prototype
 *
 * Cascade Lattice, Redline Core, Governor Delete, Meteor Piledriver.
 *
 * The two OS cores share the chest OS slot, installing one evicts the
 * other, the CP2077 operating-system choice. Both are windowed powers with
 * a crash on the back end; per the design freeze the crash IS the balance,
 * because ambient EMP threat is thin. Cascade additionally treats any EMP
 * during its window as an instant crash plus a full recooldown, the
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
 * duration, no meth stacking, no sub-tick movement), melee cooldowns
 * halved, and 40% ranged dodge while moving through the shared arbiter in
 * ware_pro_combat.dm. Everyone nearby sees it: afterimages peel off every
 * step, your victim's screen never had a chance, and the activation is an
 * audible time-tear.
 *
 * Then the heat bill: six seconds of crash, heavy stamina dump, leaden
 * slowdown, zero dodge. An EMP during the window skips straight to the
 * crash and re-arms the full sixty-second cooldown.
 */
/obj/item/organ/cyberimp/cyberware/cascade
	name = "\improper Cascade lattice"
	desc = "A full-spine lattice of superconducting myelin, a real sandevistan, not one of the knockoffs. For eight seconds at a time you move and nobody else really does. Then all the heat it just made has to go somewhere, and it goes into you."
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
	desc = "Eight seconds of overwhelming speed: melee cooldowns halved, 40% chance to dodge ranged fire while moving. Then six seconds of crash. An EMP mid-window crashes you instantly."
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
	surger.apply_status_effect(/datum/status_effect/cyberware_cascade_window)
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

/datum/status_effect/cyberware_cascade_window/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_cascade)
	owner.add_movespeed_mod_immunities(id, /datum/movespeed_modifier/reagent)
	cyberware_register_dodge_source(owner, id, CALLBACK(src, PROC_REF(get_dodge_chance)))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_move))
	owner.add_client_colour(/datum/client_colour/cyberware_cascade, id)
	playsound(owner, 'sound/effects/magic/timeparadox2.ogg', 70, TRUE)
	owner.visible_message(
		span_boldwarning("[owner] fractures into afterimages. Something under [owner.p_their()] skin is running far too fast!"),
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

/// Signal proc for [COMSIG_MOVABLE_MOVED]: one afterimage per step, the
/// telegraph everyone in the fight can read.
/datum/status_effect/cyberware_cascade_window/proc/on_move(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	if(isturf(old_loc))
		new /obj/effect/temp_visual/decoy/fading/halfsecond(old_loc, owner)

/atom/movable/screen/alert/status_effect/cyberware_cascade
	name = "Cascade Window"
	desc = "The lattice has the world in slow motion. Make it count. Six seconds of crash follows either way."
	icon_state = "radiation_shield"

/// The bill. No dodge source, no speed, the opposite of all of it.
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
		span_userdanger("The lattice dumps its heat. Your whole body seizes up and everything slows to a crawl."),
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
 * didn't finish is now standing over you.
 */
/obj/item/organ/cyberimp/cyberware/redline
	name = "\improper Redline core"
	desc = "A combat governor rebuilt to fail open. Twelve seconds with every safety limit switched off at once, announced by a chest speaker nobody told you was in there."
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
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_redline"
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
	RegisterSignal(owner, COMSIG_LIVING_EARLY_UNARMED_ATTACK, PROC_REF(on_early_unarmed_attack))
	RegisterSignal(owner, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
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
	UnregisterSignal(owner, list(COMSIG_LIVING_EARLY_UNARMED_ATTACK, COMSIG_LIVING_UNARMED_ATTACK))
	bypassed_victim = null
	bypassed_penetration = 0
	owner.remove_client_colour(id)
	if(!QDELETED(owner) && owner.stat != DEAD)
		owner.apply_status_effect(/datum/status_effect/cyberware_redline_crash)
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

/**
 * Signal proc for [COMSIG_LIVING_EARLY_UNARMED_ATTACK]. Arms a top-up for this
 * punch and hands the chain straight back, we never cancel anything and never
 * change what the punch itself does.
 */
/datum/status_effect/cyberware_redline_window/proc/on_early_unarmed_attack(mob/living/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	bypassed_victim = null
	bypassed_penetration = 0
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
	bypassed_victim = null
	bypassed_penetration = 0
	return NONE

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
		CYBERWARE_REDLINE_MELEE_BONUS,
		BRUTE,
		target_zone,
		victim.run_armor_check(target_zone, MELEE, armour_penetration = penetration, silent = TRUE),
		wound_bonus = CANT_WOUND,
	)
	log_combat(owner, victim, "redlined a bypassed unarmed strike on", "redline core")

/atom/movable/screen/alert/status_effect/cyberware_redline
	name = "Redline Burn"
	desc = "Every safety limit off at once. Stuns don't land, hits don't hurt much, and your fists hit a great deal harder. You collapse when it ends."
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
		span_userdanger("The core slams shut and your legs go out from under you."),
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
 * generic chrome base rather than tg's brain-implant subtype, the brain
 * base answers EMP with a 200/severity stun, which on a PvP server would
 * turn a one-voucher grenade into an execution button. Here it browns out
 * and reboots like every other piece of chrome.
 */
/obj/item/organ/cyberimp/cyberware/governor_delete
	name = "\improper Governor Delete"
	desc = "A factory neural governor with the governing part surgically removed. It tells your nervous system it has six more points of headroom than it really does, and your nervous system believes it."
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
 * leg ladder. Click any visible open tile, or a person standing on one: you
 * launch, a landing shadow paints the tile for most of a second (the warframe
 * rule, telegraphed, dodgeable), and then you arrive like ordnance.
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
	desc = "Prototype launch pistons sleeved over both legs, running into a gyroscopic landing computer that aims you at the floor. Everyone underneath gets a shadow to look at before you get there."
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
	desc = "Launch onto any tile you can see, or onto somebody standing on one. A shadow warns everyone underneath first. A direct hit crushes whoever is still there: heavy brute, broken bones, flat on the deck. Everything within two tiles is knocked flat and thrown."
	button_icon = 'voidcrew/modules/cyberware/icons/cyberware.dmi'
	button_icon_state = "act_piledriver"
	cooldown_time = 60 SECONDS
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
	// exclude_mobs: a body standing there is a target, not an obstruction. This
	// is what lets you aim at a person instead of the deck beside them.
	if(destination.is_blocked_turf(exclude_mobs = TRUE) || islava(destination) || ischasm(destination))
		jumper.balloon_alert(jumper, "no landing surface!")
		return FALSE
	StartCooldown()
	// Liftoff: locked in for the whole arc, committed, like everything
	// with this much telegraph. The TILE is what gets locked, never the mob,
	// so the shadow the room is looking at is always where you actually land.
	jumper.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), REF(src))
	jumper.face_atom(destination)
	var/launch_message = "You launch. The landing computer handles the rest."
	if(isliving(target))
		launch_message = "You launch. The landing computer locks the tile [target] is standing on, if [target.p_they()] move[target.p_s()], you come down on empty deck."
	jumper.visible_message(
		span_boldwarning("[jumper]'s leg pistons CRACK the deck and [jumper.p_they()] launch[jumper.p_es()] skyward!"),
		span_warning(launch_message),
	)
	playsound(here, 'sound/effects/gravhit.ogg', 70, TRUE)
	new /obj/effect/temp_visual/mook_dust(here)
	new /obj/effect/temp_visual/cyberware_piledriver_shadow(destination)
	animate(jumper, pixel_z = 64, time = CYBERWARE_PILEDRIVER_AIRTIME * 0.5, flags = ANIMATION_RELATIVE, easing = QUAD_EASING|EASE_OUT)
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
	animate(jumper, pixel_z = -64, time = 0.1 SECONDS, flags = ANIMATION_RELATIVE)
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
	new /obj/effect/temp_visual/mook_dust(final)
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
	var/blocked = victim.run_armor_check(attack_flag = MELEE)
	if(iscarbon(victim))
		var/mob/living/carbon/carbon_victim = victim
		if(prob(CYBERWARE_PILEDRIVER_CRUSH_SPREAD_CHANCE))
			carbon_victim.apply_damage(
				CYBERWARE_PILEDRIVER_CRUSH_DAMAGE,
				BRUTE,
				blocked = blocked,
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
			blocked = blocked,
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
#undef CYBERWARE_PILEDRIVER_CRUSH_DAMAGE
#undef CYBERWARE_PILEDRIVER_CRUSH_SPREAD_CHANCE
#undef CYBERWARE_PILEDRIVER_CRUSH_WOUND
#undef CYBERWARE_PILEDRIVER_CRUSH_PARALYZE
#undef CYBERWARE_PILEDRIVER_CRUSH_SQUISH
