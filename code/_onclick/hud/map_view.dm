/**
 * A screen object, which acts as a container for turfs and other things
 * you want to show on the map, which you usually attach to "vis_contents".
 * Additionally manages the plane masters required to display said container contents
 */
INITIALIZE_IMMEDIATE(/atom/movable/screen/map_view)
/atom/movable/screen/map_view
	name = "screen"
	// Map view has to be on the lowest plane to enable proper lighting
	layer = GAME_PLANE
	plane = GAME_PLANE
	del_on_map_removal = FALSE

	// Weakrefs of all our hud viewers -> a weakref to the hud datum they last used
	var/list/datum/weakref/viewers_to_huds = list()
#ifdef CRADLE_TRACE
	/// DEBUG SCAFFOLD: world.time at which display_to_client last completed for
	/// this view, or 0 if it never has. Lets ui_data catch the case where a map
	/// key is handed to the interface for a view nobody ever registered.
	/// See voidcrew/modules/cyberware/cradle_trace.dm.
	var/cradle_displayed_at = 0
#endif

/atom/movable/screen/map_view/Destroy()
	for(var/datum/weakref/client_ref in viewers_to_huds)
		hide_from_client(client_ref.resolve())

	return ..()

/atom/movable/screen/map_view/proc/generate_view(map_key)
	// Map keys have to start and end with an A-Z character,
	// and definitely NOT with a square bracket or even a number.
	// I wasted 6 hours on this. :agony:
	// -- Stylemistake
	assigned_map = map_key
	set_position(1, 1)

/**
 * Generates and displays the map view to a client
 * Make sure you at least try to pass tgui_window if map view needed on UI,
 * so it will wait a signal from TGUI, which tells windows is fully visible.
 *
 * If you use map view not in TGUI, just call it as usualy.
 * If UI needs planes, call display_to_client.
 *
 * * show_to - Mob which needs map view
 * * window - Optional. TGUI window which needs map view
 */
/atom/movable/screen/map_view/proc/display_to(mob/show_to, datum/tgui_window/window)
#ifdef CRADLE_TRACE
	if(is_cradle_map(assigned_map))
		cradle_trace("display_to key=[assigned_map] view=[REF(src)] mob=[show_to] ([show_to?.type]) \
client=[show_to?.client ? show_to.client.ckey : "NO CLIENT"] window=[window?.id] \
window_visible=[window?.visible] window_status=[window?.status] \
BRANCH=[(window && !window.visible) ? "DEFERRED (waiting on COMSIG_TGUI_WINDOW_VISIBLE)" : "IMMEDIATE"]")
#endif
	if(window && !window.visible)
		RegisterSignal(window, COMSIG_TGUI_WINDOW_VISIBLE, PROC_REF(display_on_ui_visible))
	else
		display_to_client(show_to.client)

/atom/movable/screen/map_view/proc/display_on_ui_visible(datum/tgui_window/window, client/show_to)
	SIGNAL_HANDLER
#ifdef CRADLE_TRACE
	if(is_cradle_map(assigned_map))
		cradle_trace("SIGNAL COMSIG_TGUI_WINDOW_VISIBLE key=[assigned_map] view=[REF(src)] \
window=[window?.id] window_visible=[window?.visible] arg_is_client=[istype(show_to, /client) ? "YES" : "NO"] \
client=[show_to?.ckey] client_mob=[show_to?.mob] ([show_to?.mob?.type])")
#endif
	display_to_client(show_to)
	UnregisterSignal(window, COMSIG_TGUI_WINDOW_VISIBLE)

/atom/movable/screen/map_view/proc/display_to_client(client/show_to)
#ifdef CRADLE_TRACE
	var/cradle_traced = is_cradle_map(assigned_map)
	if(cradle_traced)
		cradle_trace("display_to_client ENTER key=[assigned_map] view=[REF(src)] client=[show_to?.ckey || "NULL CLIENT"] \
mob=[show_to?.mob] ([show_to?.mob?.type]) hud=[show_to?.mob?.hud_used ? REF(show_to.mob.hud_used) : "NULL HUD"] \
screen_maps_before=[cradle_describe_screen_maps(show_to)]")
#endif
	show_to.register_map_obj(src)
#ifdef CRADLE_TRACE
	if(cradle_traced)
		var/list/registered = show_to.screen_maps[assigned_map]
		cradle_trace("display_to_client REGISTERED key=[assigned_map] objects_under_key=[length(registered)] \
we_are_in_it=[(src in registered) ? "YES" : "NO"] in_client_screen=[(src in show_to.screen) ? "YES" : "NO"] \
screen_maps_after=[cradle_describe_screen_maps(show_to)]")
#endif
	// We need to add planesmasters to the popup, otherwise
	// blending fucks up massively. Any planesmaster on the main screen does
	// NOT apply to map popups. If there's ever a way to make planesmasters
	// omnipresent, then this wouldn't be needed.
	// We lazy load this because there's no point creating all these if none's gonna see em

	// Store this info in a client -> hud pattern, so ghosts closing the window nukes the right group
	var/datum/weakref/client_ref = WEAKREF(show_to)

	var/datum/weakref/hud_ref = viewers_to_huds[client_ref]
	var/datum/hud/our_hud = hud_ref?.resolve()
	if(our_hud)
#ifdef CRADLE_TRACE
		if(cradle_traced)
			var/datum/plane_master_group/existing = our_hud.get_plane_group(PLANE_GROUP_POPUP_WINDOW(src))
			cradle_trace("display_to_client EARLY-RETURN key=[assigned_map] — this client already had a hud on \
record, so NO plane masters are (re)attached by this call. recorded_hud=[REF(our_hud)] \
current_hud=[show_to.mob?.hud_used ? REF(show_to.mob.hud_used) : "NULL"] \
SAME_HUD=[(our_hud == show_to.mob?.hud_used) ? "YES" : "NO — group is on a stale hud"] \
existing_group=[existing ? REF(existing) : "MISSING — nothing will render"]")
			cradle_dump_planes(show_to, src, "AFTER-EARLY-RETURN")
			cradle_displayed_at = world.time
#endif
		return our_hud.get_plane_group(PLANE_GROUP_POPUP_WINDOW(src))

	// Generate a new plane group for this case
	var/datum/plane_master_group/popup/pop_planes = new(PLANE_GROUP_POPUP_WINDOW(src), assigned_map)
	viewers_to_huds[client_ref] = WEAKREF(show_to.mob.hud_used)
	pop_planes.attach_to(show_to.mob.hud_used)
#ifdef CRADLE_TRACE
	if(cradle_traced)
		cradle_trace("display_to_client NEW-GROUP key=[assigned_map] group=[REF(pop_planes)] \
group_key=[pop_planes.key] group_map=[pop_planes.map] \
attached_hud=[show_to.mob?.hud_used ? REF(show_to.mob.hud_used) : "NULL HUD"] \
group_our_hud=[pop_planes.our_hud ? REF(pop_planes.our_hud) : "NULL — attach_to bailed on a duplicate key"]")
		cradle_dump_planes(show_to, src, "AFTER-ATTACH")
		cradle_displayed_at = world.time
#endif

	return pop_planes

/atom/movable/screen/map_view/proc/hide_from(mob/hide_from)
	hide_from_client(hide_from?.canon_client)

/atom/movable/screen/map_view/proc/hide_from_client(client/hide_from)
	if(!hide_from)
		return
#ifdef CRADLE_TRACE
	if(is_cradle_map(assigned_map))
		cradle_trace("hide_from_client key=[assigned_map] view=[REF(src)] client=[hide_from.ckey] \
displayed_at=[cradle_displayed_at] \
alive_for=[cradle_displayed_at ? world.time - cradle_displayed_at : "NEVER DISPLAYED"] \
— the map registration and popup plane group are being torn down now")
#endif
	hide_from.clear_map(assigned_map)

	var/datum/weakref/client_ref = WEAKREF(hide_from)
	// Make sure we clear the *right* hud
	var/datum/weakref/hud_ref = viewers_to_huds[client_ref]
	viewers_to_huds -= client_ref

	var/datum/hud/clear_from = hud_ref?.resolve()
	if(!clear_from)
		return

	var/datum/plane_master_group/popup/pop_planes = clear_from.get_plane_group(PLANE_GROUP_POPUP_WINDOW(src))
	qdel(pop_planes)
