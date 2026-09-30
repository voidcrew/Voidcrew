/atom/movable/screen/screentip
	/// Weak reference so hovering cannot keep a deleted target alive.
	var/datum/weakref/hovered_atom_ref
	/// Invalidates text measurements that finish after the pointer has moved on.
	var/hover_version = 0
	var/showing_hover = FALSE
	/// Refreshed separately from mouse events, including while our ship is moving.
	var/fallback_maptext = ""

/**
 * Takes the health doll off the client's screen and puts it straight back, so the client
 * re-establishes the doll's visual contents.
 *
 * The doll draws each limb as a separate screen object in its own vis_contents
 * (/atom/movable/screen/healthdoll/human/update_body_zones in screen_objects.dm), because
 * upstream wants per-limb outline filters it can animate. On a z change - which here is
 * every single dock and undock - the BYOND client drops those children and never gets
 * them back. This is a known client-side bug class, not a DM one: BYOND id:2303806
 * ("Visual contents were not taken into account by the client-side garbage collector...
 * The objects still exist, just aren't visible unless you change an appearance var to
 * bring them back into the view") and id:2359025 ("visual contents no longer showed up
 * after changing Z levels"). Server side the limbs stay alive with correct icon_states
 * throughout - there are no runtimes for them in any round log, and nothing in DM touches
 * the doll on a z change.
 *
 * vis_contents is not part of an atom's appearance, and the doll has no icon_state and no
 * overlays of its own, so its appearance never changes for its entire life and the client
 * is never told about it a second time. That leaves a limb's own icon_state as the only
 * thing that can bring it back, which is exactly what players reported ("get damage on
 * that limb and heal it to fix it") and why the limbs surviving a dock were always the
 * ones that had taken or healed damage since.
 *
 * Re-adding the doll to client.screen re-sends it and its children. This is the same
 * treatment the parallax backdrop already gets by accident: it is the only other screen
 * object built on vis_contents, and update_parallax_pref() above tears its holder off the
 * screen and adds it back (remove_parallax/create_parallax in parallax.dm) on every z
 * change, which is why parallax does not rot the way the doll did.
 *
 * Do not "simplify" this into update_appearance() or update_body_zones(). The first
 * changes nothing about the doll's appearance so nothing is sent; the second rebuilds six
 * screen objects to repair a link that was never broken server side.
 */
/datum/hud/proc/resend_healthdoll()
	var/client/our_client = mymob?.client
	if(isnull(our_client) || isnull(healthdoll))
		return
	// Hud hidden with F12? The doll is deliberately off the screen, leave it off.
	if(!(healthdoll in our_client.screen))
		return
	our_client.screen -= healthdoll
	our_client.screen += healthdoll

/atom/movable/screen/skills/Click()
	usr.view_skills()
	return TRUE

/// Shortcut to the same personal skill report provided by the View Skills verb.
/atom/movable/screen/skills
	name = "view skills and experience"
	icon = 'icons/hud/screen_midnight.dmi'
	icon_state = "skills"
	mouse_over_pointer = MOUSE_HAND_POINTER

/// Reapply a changed preference even when the pointer stays still.
/atom/movable/screen/screentip/proc/refresh_hover()
	update_fallback()
	var/atom/target = hovered_atom_ref?.resolve()
	if(target && hud?.mymob?.client)
		target.on_mouse_enter(hud.mymob.client)
	else
		clear_hover()

/// Reused HUDs must not retain a hover from the previous connection.
/atom/movable/screen/screentip/proc/on_connection_changed(datum/source)
	SIGNAL_HANDLER
	update_fallback()
	clear_hover()

/atom/movable/screen/screentip/proc/update_fallback()
	fallback_maptext = hud?.screentips_enabled == SCREENTIP_PREFERENCE_DISABLED ? "" : get_fallback_maptext()
	if(!showing_hover)
		show_fallback()

/atom/movable/screen/screentip/proc/show_fallback()
	maptext = hud?.screentips_enabled == SCREENTIP_PREFERENCE_DISABLED ? "" : fallback_maptext
	maptext_y = 10

/// Empty or suppressed hover text gives the fallback its turn.
/atom/movable/screen/screentip/proc/set_hover_text(new_maptext, text_y = 10)
	showing_hover = length(new_maptext) > 0
	if(showing_hover)
		maptext = new_maptext
		maptext_y = text_y
	else
		show_fallback()

/// An exit from an older target must not clear a more recent hover.
/atom/movable/screen/screentip/proc/clear_hover(atom/target)
	if(target && !IS_WEAKREF_OF(target, hovered_atom_ref))
		return
	hovered_atom_ref = null
	hover_version++
	set_hover_text("")

/// Starts a hover and returns the version to use for asynchronous text measurement.
/atom/movable/screen/screentip/proc/begin_hover(atom/target)
	hovered_atom_ref = WEAKREF(target)
	return ++hover_version

/atom/movable/screen/screentip/process(seconds_per_tick)
	if(!hud?.mymob?.client)
		return
	if(hovered_atom_ref && !hovered_atom_ref.resolve())
		clear_hover()
	update_fallback()

/atom/movable/screen/screentip/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	hovered_atom_ref = null
	return ..()
