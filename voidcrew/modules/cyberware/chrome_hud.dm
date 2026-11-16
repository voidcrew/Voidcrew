/**
 * # Chrome on the HUD
 *
 * Chrome abilities are fired from the chrome wheel (chrome_wheel.dm), so none
 * of them gets an action button of its own. One "Chrome" button stands in for
 * all of them: it shows the pick (what Use chrome fires) with its cooldown and
 * offline state, and a click opens the wheel.
 *
 * A chrome ability is any action whose target is installed chrome (an organ
 * carrying /datum/component/cyberware), plus the wheel's own Arm chrome. Every
 * other action, printable tg implants included, keeps its button.
 *
 * Hiding is tg's own way to keep an action without a button (the ninja dash,
 * energy_katana.dm): GiveAction() does nothing for it. The action is still
 * granted, so it keeps its owner, its keydown signal, its check_flags signals,
 * its cooldown and its click intercepts, and Trigger() works as before. It
 * just never joins anyone's actions list (so the HUD, observers and riders
 * never see it) and never gets a button. Code that used to look for a chrome
 * ability in mob.actions asks get_chrome_wheel_actions() instead.
 *
 * The chips on the wheel and the Chrome button still wear each ability's own
 * button look: chrome_ability_look() builds a button that never goes on a
 * screen and copies it.
 */

/// Whether this action is a chrome ability: fired from the chrome wheel, never
/// given a button of its own.
/datum/action/proc/is_chrome_ability()
	var/obj/item/organ/ware = target
	return istype(ware) && !!ware.GetComponent(/datum/component/cyberware)

/datum/action/GiveAction(mob/viewer)
	if(is_chrome_ability())
		return
	return ..()

// GiveAction() is the only way in, but a button must never be built for one by any other road either.
/datum/action/ShowTo(mob/viewer)
	if(is_chrome_ability())
		return
	return ..()

/datum/action/Grant(mob/grant_to)
	. = ..()
	if(owner && is_chrome_ability())
		chrome_hud_sync(owner, gained = TRUE)

/datum/action/Remove(mob/remove_from)
	// Grant() hands over by setting the new owner first, then removing the old one.
	var/mob/losing = remove_from || owner
	. = ..()
	if(losing && is_chrome_ability())
		chrome_hud_sync(losing)

/// A chrome ability's button would have been redrawn (a cooldown ticking, an
/// ability armed, a stun): the Chrome button redraws instead if it shows this one.
/datum/action/build_all_button_icons(update_flags = ALL, force)
	. = ..()
	if(owner && is_chrome_ability())
		var/datum/component/chrome_wheel/wheel = owner.GetComponent(/datum/component/chrome_wheel)
		wheel?.on_ability_changed(src)

/**
 * Brings the bearer's Chrome button and Arm chrome up to date with the chrome
 * they carry. [gained] makes the wheel if the body has none yet.
 */
/proc/chrome_hud_sync(mob/living/carbon/bearer, gained = FALSE)
	if(!iscarbon(bearer) || QDELETED(bearer))
		return
	var/datum/component/chrome_wheel/wheel = gained ? get_chrome_wheel(bearer) : bearer.GetComponent(/datum/component/chrome_wheel)
	wheel?.sync_abilities()

// ---- Ability looks -----------------------------------------------------

/// The last look built for this action's chip or Chrome button, and what it was built from.
/datum/action/var/tmp/mutable_appearance/chrome_look
/datum/action/var/tmp/chrome_look_key

/// What an ability's look is built from. A change here rebuilds it.
/proc/chrome_ability_look_key(datum/action/ability)
	var/atom/thing = isatom(ability.target) ? ability.target : null
	return "[ability.button_icon]|[ability.button_icon_state]|[ability.overlay_icon_state]|[ability.name]|[thing?.icon]|[thing?.icon_state]|[length(thing?.overlays)]"

/**
 * An ability's own button look, without its background, text, tint or
 * position: built on a button that never goes on a screen, so it carries the
 * same icon and item overlay a button would. A fresh copy each call.
 */
/proc/chrome_ability_look(datum/action/ability)
	RETURN_TYPE(/mutable_appearance)
	var/key = chrome_ability_look_key(ability)
	if(!ability.chrome_look || ability.chrome_look_key != key)
		var/atom/movable/screen/movable/action_button/button = ability.create_button()
		var/mutable_appearance/look = new(button)
		qdel(button)
		look.underlays = list()
		look.plane = FLOAT_PLANE
		look.layer = FLOAT_LAYER
		look.pixel_x = 0
		look.pixel_y = 0
		look.pixel_w = 0
		look.pixel_z = 0
		look.screen_loc = null
		look.maptext = null
		look.color = null
		look.alpha = 255
		look.transform = matrix()
		look.appearance_flags = NONE
		ability.chrome_look = look
		ability.chrome_look_key = key
	return new /mutable_appearance(ability.chrome_look)

// ---- The Chrome button -------------------------------------------------

/// The pick's look, frame and anything else the Chrome button laid over itself.
/atom/movable/screen/movable/action_button/var/list/chrome_overlays

/**
 * The one HUD button chrome gets. Shows the wheel's pick framed in cyan, or
 * the wheel itself with no pick; red like the pick's own button when it can't
 * be used, with its cooldown in seconds and a lit background while it is out
 * or armed. A click opens the wheel, and a chip clicked there is picked and fired.
 */
/datum/action/chrome_button
	name = "Chrome"
	button_icon = CHROME_HUD_ICON
	button_icon_state = "chrome"
	background_icon_state = "bg_tech_blue"
	default_button_position = SCRN_OBJ_INSERT_FIRST

/datum/action/chrome_button/proc/get_wheel()
	RETURN_TYPE(/datum/component/chrome_wheel)
	var/datum/component/chrome_wheel/wheel = target
	return istype(wheel) ? wheel : null

/// The ability the button shows, or null.
/datum/action/chrome_button/proc/get_pick()
	return get_wheel()?.get_button_pick()

/datum/action/chrome_button/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return FALSE
	if(clicker && clicker != owner)
		return FALSE
	var/datum/component/chrome_wheel/wheel = get_wheel()
	if(!wheel)
		return FALSE
	wheel.button_clicked()
	return TRUE

/datum/action/chrome_button/create_button()
	var/atom/movable/screen/movable/action_button/button = ..()
	// Placed like a cooldown button's count.
	button.maptext_x = 4
	button.maptext_y = 2
	button.maptext_width = 32
	button.maptext_height = 16
	return button

/datum/action/chrome_button/is_action_active(atom/movable/screen/movable/action_button/current_button)
	var/datum/action/pick = get_pick()
	return pick && chrome_wheel_ability_active(pick, owner)

/datum/action/chrome_button/apply_button_background(atom/movable/screen/movable/action_button/current_button, force)
	// Lit while the pick is out or armed.
	background_icon_state = is_action_active(current_button) ? "bg_tech_blue_active" : "bg_tech_blue"
	return ..()

/datum/action/chrome_button/apply_button_icon(atom/movable/screen/movable/action_button/current_button, force)
	// With a pick, the pick's own look is laid over an empty button instead.
	current_button.icon = get_pick() ? null : button_icon
	current_button.icon_state = button_icon_state

/datum/action/chrome_button/apply_button_overlay(atom/movable/screen/movable/action_button/current_button, force)
	. = ..()
	if(current_button.chrome_overlays)
		current_button.cut_overlay(current_button.chrome_overlays)
		current_button.chrome_overlays = null
	var/datum/action/pick = get_pick()
	if(!pick)
		return
	// No RESET_COLOR: the button's red goes over the pick, as it did on the pick's own button.
	var/list/laid = list(chrome_ability_look(pick), chrome_wheel_marker("module_selected"))
	current_button.add_overlay(laid)
	current_button.chrome_overlays = laid

/datum/action/chrome_button/update_button_status(atom/movable/screen/movable/action_button/current_button, force)
	. = ..()
	current_button.maptext = ""
	var/datum/action/pick = get_pick()
	if(!pick)
		return
	var/cooldown_left = chrome_wheel_cooldown_left(pick)
	if(cooldown_left)
		current_button.maptext = MAPTEXT_TINY_UNICODE("[CEILING(cooldown_left / 10, 1)]")
	if(chrome_wheel_offline(pick) || !pick.IsAvailable())
		current_button.color = pick.transparent_when_unavailable ? rgb(128, 0, 0, 128) : rgb(128, 0, 0)
