/**
 * # Optics zoom
 *
 * Every set of chrome optics (/obj/item/organ/eyes/robotic/cyberware and its
 * subtypes) can zoom: one toggle button pans the bearer's camera toward the
 * cursor, using tg's scope component (code/datums/components/scope.dm), the
 * same one binoculars and rifle scopes use. How far it reaches is the optics'
 * optics_zoom, passed straight through as the scope's range_modifier; better
 * optics reach further, and the cheap ones slow their bearer while they look.
 *
 * The button rides the /datum/action/cooldown/cyberware bridge, so browned-out,
 * EMP-scrambled or failing eyes can't zoom, and the chrome wheel collects it
 * like any other chrome button.
 *
 * Zoom is look-only:
 * - A zoomed bearer can't fire a gun (COMSIG_MOB_TRYING_TO_FIRE_GUN is refused,
 *   and a burst already under autofire stops when the zoom starts).
 * - Their clicks on the zoomed view reach nothing on the map. The scope's
 *   fullscreen cursor catcher already eats them; check_click_intercept() below
 *   takes them before any click intercept or ClickOn() sees them.
 *
 * The zoom drops on its own when the eyes stop working or the bearer can't
 * look: EMP, brownout or damage failure (chrome_passives_off()), the eyes
 * coming out, blindness, a flash, a stun, knockdown or paralysis, any stat
 * change (crit, sleep, death), and everything the scope already stops for
 * (no client, climbing into a locker or a mech, the organ moving).
 */

/obj/item/organ/eyes/robotic/cyberware
	/// How far the zoom pans, as the scope's range_modifier: 1 reaches as far
	/// again as the edge of the normal view, 2 twice that. 0 means no zoom.
	var/optics_zoom = 1
	/// Slowdown while zoomed (a multiplicative_slowdown). 0 for none.
	var/zoom_walk_penalty = 1
	/// Throttles the "can't aim" balloon, so autofire and click spam don't stack it.
	COOLDOWN_DECLARE(zoom_aim_warning)
	/// Throttles the iris tell, so flicking the zoom on and off can't flood chat.
	COOLDOWN_DECLARE(zoom_tell)

/// Gives these optics their zoom: the scope that does the panning, and the
/// button. Called from Initialize() on the optics base (cyberware_base.dm).
/obj/item/organ/eyes/robotic/cyberware/proc/setup_optics_zoom()
	if(optics_zoom <= 0)
		return
	// ZOOM_METHOD_ITEM_ACTION with no item_action_type: the scope adds no button
	// and no examine line of its own, and only zooms when we tell it to.
	AddComponent(/datum/component/scope, range_modifier = optics_zoom, zoom_method = ZOOM_METHOD_ITEM_ACTION)
	add_item_action(/datum/action/cooldown/cyberware/optics_zoom)

/// Whether our bearer is looking through these optics' zoom right now.
/obj/item/organ/eyes/robotic/cyberware/proc/is_zoomed()
	return owner && HAS_TRAIT_FROM(owner, TRAIT_CYBER_ZOOMED, REF(src))

/// Starts the zoom for our bearer. Returns TRUE if they are now zoomed.
/obj/item/organ/eyes/robotic/cyberware/proc/start_zoom()
	var/mob/living/carbon/bearer = owner
	if(!iscarbon(bearer) || is_zoomed())
		return FALSE
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	var/datum/component/scope/scope = GetComponent(/datum/component/scope)
	if(!scope || !chrome?.is_running())
		return FALSE
	if(bearer.is_blind())
		bearer.balloon_alert(bearer, "optics dark!")
		return FALSE
	if(!isturf(bearer.loc))
		bearer.balloon_alert(bearer, "can't see out!")
		return FALSE
	if(HAS_TRAIT(bearer, TRAIT_INCAPACITATED))
		return FALSE
	// The scope refuses a clientless bearer and anyone already scoped (a rifle,
	// binoculars), with its own balloon for the second.
	if(!scope.zoom(bearer))
		return FALSE
	engage_zoom(bearer)
	return TRUE

/**
 * Our half of a zoom, once the scope is panning: the trait, the stop hooks,
 * the gun block and the walk penalty. Split from start_zoom() because the scope
 * needs a client, and a unit test has none.
 */
/obj/item/organ/eyes/robotic/cyberware/proc/engage_zoom(mob/living/carbon/bearer)
	ADD_TRAIT(bearer, TRAIT_CYBER_ZOOMED, REF(src))
	// The scope stops itself for a few reasons of its own (no client, the bearer
	// climbing into something); it drops TRAIT_USER_SCOPED when it does.
	RegisterSignal(bearer, SIGNAL_REMOVETRAIT(TRAIT_USER_SCOPED), PROC_REF(on_scope_lost))
	RegisterSignal(bearer, COMSIG_MOB_TRYING_TO_FIRE_GUN, PROC_REF(on_zoomed_fire))
	RegisterSignal(bearer, COMSIG_MOB_STATCHANGE, PROC_REF(on_zoomed_stat_change))
	RegisterSignal(bearer, COMSIG_MOB_FLASHED, PROC_REF(on_zoomed_flashed))
	RegisterSignal(bearer, COMSIG_LIVING_STATUS_APPLIED, PROC_REF(on_zoomed_status))
	RegisterSignals(bearer, list(COMSIG_LIVING_STATUS_STUN, COMSIG_LIVING_STATUS_KNOCKDOWN, COMSIG_LIVING_STATUS_PARALYZE), PROC_REF(on_zoomed_stunned))
	if(zoom_walk_penalty)
		bearer.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/cyberware_zoom, multiplicative_slowdown = zoom_walk_penalty)
	// Autofire fires through process_fire() and never asks the signal above, so
	// a burst already rolling when the zoom starts is stopped here instead.
	for(var/obj/item/gun/held in bearer.held_items)
		var/datum/component/automatic_fire/autofire = held.GetComponent(/datum/component/automatic_fire)
		autofire?.stop_autofiring()
	// The tell, the chrome read's pattern: only people close enough see it.
	if(COOLDOWN_FINISHED(src, zoom_tell))
		COOLDOWN_START(src, zoom_tell, 5 SECONDS)
		bearer.visible_message(span_notice("[bearer]'s irises whir and narrow."), vision_distance = 3, ignored_mobs = bearer)
	update_zoom_button()

/// Stops the zoom, scope and all. Safe to call when nothing is zoomed.
/obj/item/organ/eyes/robotic/cyberware/proc/stop_zoom(mob/living/carbon/bearer)
	if(!bearer)
		return
	var/datum/component/scope/scope = GetComponent(/datum/component/scope)
	// Only ever stop OUR scope: the fullscreen it clears is shared by every scope.
	if(scope?.tracker && HAS_TRAIT_FROM(bearer, TRAIT_USER_SCOPED, REF(scope)))
		scope.stop_zooming(bearer) // drops TRAIT_USER_SCOPED, so on_scope_lost() runs
	disengage_zoom(bearer)

/// Undoes engage_zoom(). Idempotent: the passive hook calls it on every flip.
/obj/item/organ/eyes/robotic/cyberware/proc/disengage_zoom(mob/living/carbon/bearer)
	if(!bearer)
		return
	REMOVE_TRAIT(bearer, TRAIT_CYBER_ZOOMED, REF(src))
	UnregisterSignal(bearer, list(
		SIGNAL_REMOVETRAIT(TRAIT_USER_SCOPED),
		COMSIG_MOB_TRYING_TO_FIRE_GUN,
		COMSIG_MOB_STATCHANGE,
		COMSIG_MOB_FLASHED,
		COMSIG_LIVING_STATUS_APPLIED,
		COMSIG_LIVING_STATUS_STUN,
		COMSIG_LIVING_STATUS_KNOCKDOWN,
		COMSIG_LIVING_STATUS_PARALYZE,
	))
	bearer.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_zoom)
	update_zoom_button()

/// The zoom button shows green while zoomed (the cooldown action's active look).
/obj/item/organ/eyes/robotic/cyberware/proc/update_zoom_button()
	for(var/datum/action/cooldown/cyberware/optics_zoom/zoom in actions)
		zoom.build_all_button_icons(UPDATE_BUTTON_STATUS)

/// One short balloon when a zoomed bearer tries to shoot.
/obj/item/organ/eyes/robotic/cyberware/proc/refuse_zoomed_aim(mob/living/carbon/bearer)
	if(!COOLDOWN_FINISHED(src, zoom_aim_warning))
		return
	COOLDOWN_START(src, zoom_aim_warning, 1 SECONDS)
	bearer.balloon_alert(bearer, "too zoomed in to aim!")

// ---- Stop hooks ----------------------------------------------------------

/obj/item/organ/eyes/robotic/cyberware/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	// EMP reboot, brownout, damage failure and removal all come through here.
	stop_zoom(bearer)

/obj/item/organ/eyes/robotic/cyberware/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	stop_zoom(organ_owner)
	return ..()

/// Signal proc for [SIGNAL_REMOVETRAIT] of TRAIT_USER_SCOPED: the scope stopped.
/obj/item/organ/eyes/robotic/cyberware/proc/on_scope_lost(mob/living/carbon/source)
	SIGNAL_HANDLER
	disengage_zoom(source)

/// Signal proc for [COMSIG_MOB_TRYING_TO_FIRE_GUN]: no shooting through the zoom.
/obj/item/organ/eyes/robotic/cyberware/proc/on_zoomed_fire(mob/living/carbon/source, obj/item/gun/gun, atom/target, flag, params)
	SIGNAL_HANDLER
	refuse_zoomed_aim(source)
	return COMPONENT_CANCEL_GUN_FIRE

/// Signal proc for [COMSIG_MOB_STATCHANGE]: crit, sleep and death end the zoom.
/obj/item/organ/eyes/robotic/cyberware/proc/on_zoomed_stat_change(mob/living/carbon/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat != CONSCIOUS)
		stop_zoom(source)

/// Signal proc for [COMSIG_MOB_FLASHED].
/obj/item/organ/eyes/robotic/cyberware/proc/on_zoomed_flashed(mob/living/carbon/source)
	SIGNAL_HANDLER
	stop_zoom(source)

/// Signal proc for [COMSIG_LIVING_STATUS_APPLIED]: going blind ends the zoom.
/obj/item/organ/eyes/robotic/cyberware/proc/on_zoomed_status(mob/living/carbon/source, datum/status_effect/effect)
	SIGNAL_HANDLER
	if(istype(effect, /datum/status_effect/grouped/blindness))
		stop_zoom(source)

/// Signal proc for stun, knockdown and paralysis. Mirrors the scope's own check.
/obj/item/organ/eyes/robotic/cyberware/proc/on_zoomed_stunned(mob/living/carbon/source, amount = 0, ignore_canstun = FALSE)
	SIGNAL_HANDLER
	if(amount > 0)
		stop_zoom(source)

// ---- Clicking through the zoom -------------------------------------------

/**
 * A click on the zoomed view, swallowed. Returns FALSE only for a click that
 * isn't on our zoom, which the caller then handles as normal.
 */
/obj/item/organ/eyes/robotic/cyberware/proc/zoom_click(mob/living/carbon/bearer, atom/movable/screen/fullscreen/cursor_catcher/scope/tracker)
	var/datum/component/scope/scope = GetComponent(/datum/component/scope)
	if(!is_zoomed() || !scope || scope.tracker != tracker)
		return FALSE
	if(isgun(bearer.get_active_held_item()))
		refuse_zoomed_aim(bearer)
	return TRUE

/**
 * Zoomed clicks go to zoom_click() before the client's and the mob's click
 * intercepts, so an armed ability never receives the scope's screen object as
 * its target. The trait check keeps this to one lookup for everyone else.
 */
/mob/living/carbon/check_click_intercept(params, atom/A)
	if(HAS_TRAIT(src, TRAIT_CYBER_ZOOMED) && istype(A, /atom/movable/screen/fullscreen/cursor_catcher/scope))
		var/obj/item/organ/eyes/robotic/cyberware/optics = get_organ_slot(ORGAN_SLOT_EYES)
		if(istype(optics) && optics.zoom_click(src, A))
			return TRUE
	return ..()

// ---- The button -----------------------------------------------------------

/datum/action/cooldown/cyberware/optics_zoom
	name = "Optic Zoom"
	desc = "Focus your optics on something far off."
	// tg's binoculars: reads as "look far", and stays clear of the Deadeye's crosshair.
	button_icon = 'icons/obj/devices/tool.dmi'
	button_icon_state = "binoculars"

/datum/action/cooldown/cyberware/optics_zoom/chrome_wheel_name()
	return "Zoom"

/datum/action/cooldown/cyberware/optics_zoom/Activate(atom/target)
	var/obj/item/organ/eyes/robotic/cyberware/optics = organ
	if(!istype(optics) || !optics.owner)
		return FALSE
	if(optics.is_zoomed())
		optics.stop_zoom(optics.owner)
		return TRUE
	return optics.start_zoom()

/datum/action/cooldown/cyberware/optics_zoom/is_action_active(atom/movable/screen/movable/action_button/current_button)
	var/obj/item/organ/eyes/robotic/cyberware/optics = organ
	return istype(optics) && optics.is_zoomed()

/// The walk tax on cheap optics while they're zoomed. Strength set per optics.
/datum/movespeed_modifier/cyberware_zoom
	variable = TRUE
