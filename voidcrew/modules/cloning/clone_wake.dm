/**
 * # Waking in a clone (ghost side)
 *
 * A dead player may own grown clones in several vats: their ship's, and outpost cloning bays.
 * Instead of one short-lived toast per vat, the ghost gets:
 * * a "Wake in a Clone" action button, granted when the ghost HUD is made and whenever a vat
 *   has a ready clone for them;
 * * one "Clone Ready" alert that stays until they have no ready clone left;
 * * a small menu (CloneWake.tsx) listing every clone they own, ready ones first, with a Wake
 *   button each. The button is the consent: there is no second prompt.
 *
 * Vats are found through GLOB.imprinted_vats_by_ckey (cloning_vat.dm), never by walking every
 * machine. Every wake runs the vat's own claim_denial() with no sleep before claim().
 */

/// The alert category of the one "Clone Ready" alert a ghost can have
#define CLONE_READY_ALERT "clone_ready"

/// Every vat holding a clone this ghost may wake in, ready or not
/proc/get_owned_cloning_vats(mob/dead/observer/ghost)
	. = list()
	if(!isobserver(ghost) || !ghost.ckey)
		return
	var/list/indexed = LAZYACCESS(GLOB.imprinted_vats_by_ckey, ghost.ckey)
	if(!length(indexed))
		return
	// validate_imprint() may expire an imprint, which edits the index
	for(var/obj/machinery/cloning_vat/vat as anything in indexed.Copy())
		if(QDELETED(vat))
			continue
		var/datum/mind/mind = vat.validate_imprint()
		if(mind && vat.holder_matches(ghost, mind))
			. += vat

/// Whether the body this ghost belongs to is still alive (an admin ghost, or a ghost that may re-enter)
/proc/clone_holder_alive(mob/dead/observer/ghost)
	var/mob/living/body = ghost?.mind?.current
	return !!(body && body.stat != DEAD)

/// Gives the ghost the action button, if it does not have one
/proc/grant_clone_wake(mob/dead/observer/ghost)
	if(!isobserver(ghost))
		return null
	var/datum/action/clone_wake/button = locate() in ghost.actions
	if(!button)
		button = new(ghost)
		button.Grant(ghost)
	return button

/// A vat has a ready clone for this ghost: the button and the one persistent alert
/proc/notify_clone_holder(mob/dead/observer/ghost)
	if(!isobserver(ghost))
		return
	grant_clone_wake(ghost)
	ghost.throw_alert(CLONE_READY_ALERT, /atom/movable/screen/alert/notify_action/clone_ready)

/// Clears the ghost's alert once it has no ready clone left
/proc/refresh_clone_ready_alert(mob/dead/observer/ghost)
	if(!isobserver(ghost) || !ghost.alerts[CLONE_READY_ALERT])
		return
	for(var/obj/machinery/cloning_vat/vat as anything in get_owned_cloning_vats(ghost))
		if(vat.body_ready)
			return
	ghost.clear_alert(CLONE_READY_ALERT)

/// Opens the ghost's clone menu
/proc/open_clone_wake_menu(mob/dead/observer/ghost)
	var/datum/action/clone_wake/button = grant_clone_wake(ghost)
	button?.open_menu()

/// Called when a ghost's HUD is made (ghost_respawn.dm): the button if they own a clone, the alert if one is ready
/proc/setup_clone_wake(mob/dead/observer/ghost)
	var/list/vats = get_owned_cloning_vats(ghost)
	if(!length(vats))
		return
	grant_clone_wake(ghost)
	for(var/obj/machinery/cloning_vat/vat as anything in vats)
		if(vat.body_ready)
			notify_clone_holder(ghost)
			return

// ===== WHERE A VAT IS =====

/// Where this vat stands, for players: the ship or outpost, else the area
/obj/machinery/cloning_vat/proc/clone_site_name()
	var/obj/structure/overmap/ship/ship = get_voidcrew_ship_for_turf(get_turf(src))
	if(ship)
		return ship.name
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(home)
		return home.name
	return get_area_name(src, format_text = TRUE) || "an unknown place"

/// Whether a claim uses the clone up instead of regrowing it
/obj/machinery/cloning_vat/proc/is_single_use()
	return FALSE

/// Whether someone waking naked on this tile would choke, freeze or burn. Indestructible floors
/// are not /turf/open/floor, so is_safe_turf() cannot be used; these are its gas limits.
/proc/clone_wake_air_unsafe(turf/tile)
	if(!isopenturf(tile))
		return TRUE
	var/turf/open/open_tile = tile
	var/datum/gas_mixture/air = open_tile.return_air()
	if(!air)
		return TRUE
	var/static/list/gases_to_check = list(
		/datum/gas/oxygen = list(16, 100),
		/datum/gas/nitrogen,
		/datum/gas/carbon_dioxide = list(0, 10),
	)
	if(!check_gases(air.gases, gases_to_check))
		return TRUE
	if(air.temperature <= 270 || air.temperature >= 360)
		return TRUE
	var/pressure = air.return_pressure()
	return pressure <= 20 || pressure >= 550

/// One row of the menu
/obj/machinery/cloning_vat/proc/clone_wake_row(mob/dead/observer/ghost)
	var/datum/mind/mind = imprint_mind_ref?.resolve()
	return list(
		"ref" = REF(src),
		"site" = clone_site_name(),
		"ready" = body_ready,
		"offline" = !is_operational || !anchored,
		"percent" = get_growth_percent(),
		"unsafe_air" = clone_wake_air_unsafe(get_turf(src)),
		"denial" = claim_denial(ghost, mind),
		"warning" = claim_warning(ghost),
	)

// ===== BUTTON, ALERT, MENU =====

/datum/action/clone_wake
	name = "Wake in a Clone"
	desc = "Your clones."
	button_icon = 'voidcrew/icons/obj/machines/cloning_vat.dmi'
	button_icon_state = "pod_ready"
	check_flags = NONE
	// A ghost watching another ghost has no business with their clones
	show_to_observers = FALSE
	var/datum/clone_wake_menu/menu

/datum/action/clone_wake/Destroy()
	QDEL_NULL(menu)
	return ..()

/datum/action/clone_wake/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return FALSE
	if(clone_holder_alive(owner))
		if(feedback)
			to_chat(owner, span_warning("You are still alive."))
		return FALSE
	return TRUE

/datum/action/clone_wake/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return FALSE
	open_menu()
	return TRUE

/datum/action/clone_wake/proc/open_menu()
	if(!isobserver(owner))
		return
	if(!menu)
		menu = new(owner)
	menu.ui_interact(owner)

/atom/movable/screen/alert/notify_action/clone_ready
	name = "Clone Ready"
	desc = "A clone of you is fully grown."
	timeout = 0

/atom/movable/screen/alert/notify_action/clone_ready/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	add_overlay(mutable_appearance('voidcrew/icons/obj/machines/cloning_vat.dmi', "pod_ready", appearance_flags = TILE_BOUND))

/atom/movable/screen/alert/notify_action/clone_ready/Click(location, control, params)
	. = ..()
	if(!.)
		return
	open_clone_wake_menu(owner)

/// One ghost's clone list
/datum/clone_wake_menu
	var/mob/dead/observer/owner

/datum/clone_wake_menu/New(mob/dead/observer/new_owner)
	. = ..()
	owner = new_owner

/datum/clone_wake_menu/Destroy()
	owner = null
	return ..()

/datum/clone_wake_menu/ui_state(mob/user)
	return GLOB.observer_state

/datum/clone_wake_menu/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CloneWake")
		ui.open()

/datum/clone_wake_menu/ui_data(mob/user)
	var/list/ready = list()
	var/list/waiting = list()
	for(var/obj/machinery/cloning_vat/vat as anything in get_owned_cloning_vats(user))
		if(vat.body_ready)
			ready += list(vat.clone_wake_row(user))
		else
			waiting += list(vat.clone_wake_row(user))
	return list(
		"alive" = clone_holder_alive(user),
		"clones" = ready + waiting,
	)

/datum/clone_wake_menu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/dead/observer/ghost = ui?.user
	if(!isobserver(ghost) || !istext(params["ref"]))
		return
	var/obj/machinery/cloning_vat/vat = locate(params["ref"]) in get_owned_cloning_vats(ghost)
	if(!vat)
		to_chat(ghost, span_warning("That clone is gone."))
		return TRUE
	switch(action)
		if("view")
			ghost.observer_view(vat)
			return TRUE
		if("wake")
			var/datum/mind/mind = vat.imprint_mind_ref?.resolve()
			var/denial = vat.claim_denial(ghost, mind)
			if(denial)
				to_chat(ghost, span_warning(denial))
				return TRUE
			vat.claim(ghost, mind)
			return TRUE

#undef CLONE_READY_ALERT
