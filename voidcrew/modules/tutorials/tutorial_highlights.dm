/**
 * # Tutorial highlights
 *
 * Outlines, for one viewer, the objects their open tutorial item points at.
 *
 * Inputs: SSvc_tutorials.selected[ckey] (the item open in the panel, set by its "select"
 * action, else the panel's suggested item), each step's highlight_types,
 * SSvc_tutorials.progress (done steps), and the tutorial_highlights preference.
 *
 * Rendering: one client /image per outlined atom, attached to the atom (loc = target), built
 * from a copy of the target's appearance with an outline and a soft glow filter. The copy
 * sits a hair BELOW the target's layer on the target's own plane, so the real sprite covers
 * the copy and only the green ring around the silhouette shows; a live sprite (screens,
 * blinking lights) is never covered by a stale copy. Images go only into the viewer's
 * client.images, so nobody else sees them.
 *
 * Cost: nothing runs per tick. A viewer only does work on a refresh trigger (panel open,
 * close, select, credit, pref toggle) or, while outlines are showing, when they walk a few
 * tiles or change z-level, throttled to once per TUTORIAL_HIGHLIGHT_MOVE_COOLDOWN.
 */

/// Most atoms outlined at once.
#define TUTORIAL_HIGHLIGHT_CAP 3
/// Radius of the in-view search.
#define TUTORIAL_HIGHLIGHT_VIEW_RANGE 9
/// How far aboard the viewer's ship a target may be and still be outlined.
#define TUTORIAL_HIGHLIGHT_SHIP_RANGE 24
/// Shortest gap between two movement-driven rebuilds.
#define TUTORIAL_HIGHLIGHT_MOVE_COOLDOWN (2 SECONDS)
/// Tiles walked before a movement-driven rebuild is considered.
#define TUTORIAL_HIGHLIGHT_MOVE_TILES 3
/// How long a ship-wide scan for one step stays cached.
#define TUTORIAL_HIGHLIGHT_SHIP_CACHE (10 SECONDS)
/// The outline colour the owner approved.
#define TUTORIAL_HIGHLIGHT_COLOR "#3CFF6E"

/// ckey -> /datum/tutorial_highlight for every viewer that currently has one.
GLOBAL_LIST_EMPTY(tutorial_highlighters)

/**
 * Rebuilds the viewer's tutorial highlights. Called when the panel opens or closes, when
 * the viewer selects an item, when the highlight preference changes, and when a step is
 * credited to them. Cheap and safe for any mob, including ghosts and mobs with no client.
 */
/proc/tutorial_refresh_highlights(mob/user)
	if(!user)
		return
	var/ckey = tutorial_viewer_ckey(user)
	if(!ckey)
		return
	var/datum/tutorial_highlight/highlight = GLOB.tutorial_highlighters[ckey]
	if(!highlight)
		// Only a real client gets one here; unit tests make theirs directly.
		if(!user.client || !tutorial_highlights_wanted(user))
			return
		highlight = new(user)
	highlight.rebuild(user)

/// TRUE when this viewer wants outlines: alive and in a body, the preference on, and the
/// checklist not put away (closed this round, or its spawn window turned off) unless it's open.
/proc/tutorial_highlights_wanted(mob/user)
	var/datum/preferences/prefs = user?.client?.prefs
	if(!prefs || isobserver(user) || user.stat == DEAD)
		return FALSE
	if(!prefs.read_preference(/datum/preference/toggle/tutorial_highlights))
		return FALSE
	if(SStgui.get_open_ui(user, GLOB.tutorial_checklist))
		return TRUE
	if(tutorial_viewer_ckey(user) in GLOB.tutorial_checklist_hidden)
		return FALSE
	return !!prefs.read_preference(/datum/preference/toggle/tutorial_checklist)

/// The first step of the viewer's open (or suggested) item that is neither done nor excused, or null.
/proc/tutorial_highlight_step(mob/user)
	var/ckey = tutorial_viewer_ckey(user)
	if(!ckey)
		return null
	SSvc_tutorials.build_catalog()
	var/item_id = SSvc_tutorials.selected[ckey] || SSvc_tutorials.suggested_item(ckey, user)
	if(!item_id)
		return null
	var/list/done = SSvc_tutorials.progress[ckey]
	for(var/datum/vc_tutorial/item as anything in SSvc_tutorials.items)
		if(item.id != item_id)
			continue
		for(var/datum/vc_tutorial_step/step as anything in item.steps)
			if(done?[step.key] || step.excused(user))
				continue
			return step
		return null
	return null

/**
 * One viewer's outlines: the images on their client and the atoms they outline.
 * Lives in GLOB.tutorial_highlighters under the viewer's ckey until logout, death,
 * ghosting, or the viewer no longer wanting outlines.
 */
/datum/tutorial_highlight
	/// The ckey this belongs to.
	var/ckey
	/// The body we're watching. Cleared when it logs out, dies, ghosts or is deleted.
	var/mob/viewer
	/// The client the images were pushed to, kept so they can be taken back off it.
	var/client/shown_client
	/// target atom -> its /image
	var/list/images = list()
	/// When non-null, used instead of tutorial_highlights_wanted(). Unit tests set it.
	var/wanted_override
	/// world.time of the last movement-driven rebuild.
	var/last_move_rebuild = 0
	/// Turf of the last rebuild, for the "walked a few tiles" check.
	var/turf/last_turf
	/// Key of the step currently outlined, or null.
	var/step_key
	/// "[REF(ship)]|[step key]" of the cached ship scan.
	var/ship_cache_key
	/// world.time the ship scan was cached.
	var/ship_cache_time = 0
	/// Cached ship scan results, as weakrefs.
	var/list/datum/weakref/ship_cache = list()

/datum/tutorial_highlight/New(mob/user)
	. = ..()
	ckey = tutorial_viewer_ckey(user)
	GLOB.tutorial_highlighters[ckey] = src
	watch(user)

/datum/tutorial_highlight/Destroy()
	clear_images()
	unwatch()
	shown_client = null
	last_turf = null
	if(GLOB.tutorial_highlighters[ckey] == src)
		GLOB.tutorial_highlighters -= ckey
	ship_cache = null
	return ..()

/// Starts listening to a body for the events that move or end the outlines.
/datum/tutorial_highlight/proc/watch(mob/user)
	if(viewer == user)
		return
	unwatch()
	viewer = user
	RegisterSignals(user, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_MOB_GHOSTIZED), PROC_REF(on_viewer_gone))

/datum/tutorial_highlight/proc/unwatch()
	if(!viewer)
		return
	UnregisterSignal(viewer, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING, COMSIG_LIVING_DEATH, COMSIG_MOB_GHOSTIZED, COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_Z_CHANGED))
	viewer = null

/// Recomputes the step and targets and swaps the images.
/datum/tutorial_highlight/proc/rebuild(mob/user)
	if(QDELETED(src))
		return
	user ||= viewer
	if(!user || QDELETED(user))
		qdel(src)
		return
	var/wanted = isnull(wanted_override) ? tutorial_highlights_wanted(user) : wanted_override
	if(!wanted && isnull(wanted_override))
		qdel(src)
		return
	watch(user)
	last_turf = get_turf(user)
	var/datum/vc_tutorial_step/step = wanted ? tutorial_highlight_step(user) : null
	if(!step || !length(step.highlight_types))
		step_key = null
		set_targets(list())
		stop_tracking_movement()
		return
	if(step.key != step_key)
		step_key = step.key
		ship_cache_key = null
	set_targets(find_targets(user, step))
	if(length(images))
		start_tracking_movement()
	else
		stop_tracking_movement()

/// The nearest matching objects in view or aboard the viewer's ship, nearest first, at most TUTORIAL_HIGHLIGHT_CAP.
/datum/tutorial_highlight/proc/find_targets(mob/user, datum/vc_tutorial_step/step)
	var/turf/center = get_turf(user)
	if(!center)
		return list()
	var/list/types = step.highlight_types
	var/list/found = list()
	for(var/obj/thing in view(TUTORIAL_HIGHLIGHT_VIEW_RANGE, user))
		if(isturf(thing.loc) && is_type_in_list(thing, types))
			found[thing] = TRUE
	if(length(found) < TUTORIAL_HIGHLIGHT_CAP)
		var/obj/structure/overmap/ship/ship = get_ship_from_atom(user)
		if(ship)
			for(var/obj/thing as anything in ship_targets(ship, step))
				if(thing.z == center.z && get_dist(center, thing) <= TUTORIAL_HIGHLIGHT_SHIP_RANGE)
					found[thing] = TRUE
	for(var/obj/thing as anything in found)
		found[thing] = get_dist_euclidean(center, thing.loc)
	sortTim(found, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE)
	var/list/result = list()
	for(var/obj/thing as anything in found)
		result += thing
		if(length(result) >= TUTORIAL_HIGHLIGHT_CAP)
			break
	return result

/// Matching objects lying aboard the ship, cached per ship and step because it walks every ship area.
/datum/tutorial_highlight/proc/ship_targets(obj/structure/overmap/ship/ship, datum/vc_tutorial_step/step)
	var/key = "[REF(ship)]|[step.key]"
	var/list/result = list()
	if(key == ship_cache_key && world.time < ship_cache_time + TUTORIAL_HIGHLIGHT_SHIP_CACHE)
		for(var/datum/weakref/ref as anything in ship_cache)
			var/obj/thing = ref.resolve()
			if(thing && isturf(thing.loc))
				result += thing
		return result
	ship_cache = list()
	ship_cache_key = key
	ship_cache_time = world.time
	if(!ship.shuttle?.shuttle_areas)
		return result
	var/list/types = step.highlight_types
	for(var/area/ship_area as anything in ship.shuttle.shuttle_areas)
		for(var/obj/thing in ship_area)
			if(isturf(thing.loc) && is_type_in_list(thing, types))
				result += thing
				ship_cache += WEAKREF(thing)
	return result

/// Makes the outlined set exactly new_targets, reusing images for targets that stay.
/datum/tutorial_highlight/proc/set_targets(list/new_targets)
	for(var/atom/old_target as anything in images.Copy())
		if(!(old_target in new_targets))
			remove_target(old_target)
	for(var/atom/movable/target as anything in new_targets)
		if(!images[target])
			add_target(target)
	sync_client()

/datum/tutorial_highlight/proc/add_target(atom/movable/target)
	images[target] = make_image(target)
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_target_deleted))
	RegisterSignals(target, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_DIR_CHANGE), PROC_REF(on_target_look_changed))

/datum/tutorial_highlight/proc/remove_target(atom/target)
	var/image/old_image = images[target]
	images -= target
	UnregisterSignal(target, list(COMSIG_QDELETING, COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_DIR_CHANGE))
	if(old_image)
		shown_client?.images -= old_image

/// A copy of the target's look, outlined and glowing, sat just under the target.
/datum/tutorial_highlight/proc/make_image(atom/movable/target)
	var/image/outline = new
	outline.appearance = target.appearance
	outline.loc = target
	// An attached image already draws at the target, so the copied offsets and transform
	// would be applied twice.
	outline.pixel_x = 0
	outline.pixel_y = 0
	outline.pixel_w = 0
	outline.pixel_z = 0
	outline.transform = null
	outline.layer = target.layer - 0.001
	outline.plane = target.plane
	outline.appearance_flags |= KEEP_TOGETHER
	outline.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	outline.alpha = 255
	outline.filters = list(
		filter(type = "outline", size = 1, color = TUTORIAL_HIGHLIGHT_COLOR),
		filter(type = "drop_shadow", x = 0, y = 0, size = 3, offset = 1, color = "[TUTORIAL_HIGHLIGHT_COLOR]90"),
	)
	animate(outline, alpha = 140, time = 0.8 SECONDS, loop = -1, easing = SINE_EASING)
	animate(alpha = 255, time = 0.8 SECONDS, easing = SINE_EASING)
	return outline

/// Puts the current images on the viewer's client and takes them off any old client.
/datum/tutorial_highlight/proc/sync_client()
	var/client/current = viewer?.client
	if(shown_client && shown_client != current)
		for(var/atom/target as anything in images)
			shown_client.images -= images[target]
	shown_client = current
	if(!shown_client)
		return
	for(var/atom/target as anything in images)
		shown_client.images |= images[target]

/// Removes every image and forgets every target.
/datum/tutorial_highlight/proc/clear_images()
	for(var/atom/target as anything in images.Copy())
		remove_target(target)
	images.Cut()

/datum/tutorial_highlight/proc/start_tracking_movement()
	if(!viewer)
		return
	RegisterSignal(viewer, COMSIG_MOVABLE_MOVED, PROC_REF(on_viewer_moved), override = TRUE)
	RegisterSignal(viewer, COMSIG_MOVABLE_Z_CHANGED, PROC_REF(on_viewer_z_changed), override = TRUE)

/datum/tutorial_highlight/proc/stop_tracking_movement()
	if(!viewer)
		return
	UnregisterSignal(viewer, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_Z_CHANGED))

/datum/tutorial_highlight/proc/on_viewer_moved(mob/source)
	SIGNAL_HANDLER
	if(world.time < last_move_rebuild + TUTORIAL_HIGHLIGHT_MOVE_COOLDOWN)
		return
	var/turf/here = get_turf(source)
	if(last_turf && here && here.z == last_turf.z && get_dist(here, last_turf) < TUTORIAL_HIGHLIGHT_MOVE_TILES)
		return
	last_move_rebuild = world.time
	INVOKE_ASYNC(src, PROC_REF(rebuild), source)

/datum/tutorial_highlight/proc/on_viewer_z_changed(mob/source)
	SIGNAL_HANDLER
	last_move_rebuild = world.time
	INVOKE_ASYNC(src, PROC_REF(rebuild), source)

/datum/tutorial_highlight/proc/on_target_deleted(atom/source)
	SIGNAL_HANDLER
	remove_target(source)

/// The target changed its look; rebuild its copy so the outline still hugs it.
/datum/tutorial_highlight/proc/on_target_look_changed(atom/movable/source)
	SIGNAL_HANDLER
	var/image/old_image = images[source]
	if(!old_image)
		return
	shown_client?.images -= old_image
	images[source] = make_image(source)
	shown_client?.images |= images[source]

/// Logout, death, ghosting or deletion: drop the outlines. A later refresh (the panel, a
/// credit) brings them back if the viewer still wants them.
/datum/tutorial_highlight/proc/on_viewer_gone(mob/source)
	SIGNAL_HANDLER
	qdel(src)

#undef TUTORIAL_HIGHLIGHT_CAP
#undef TUTORIAL_HIGHLIGHT_VIEW_RANGE
#undef TUTORIAL_HIGHLIGHT_SHIP_RANGE
#undef TUTORIAL_HIGHLIGHT_MOVE_COOLDOWN
#undef TUTORIAL_HIGHLIGHT_MOVE_TILES
#undef TUTORIAL_HIGHLIGHT_SHIP_CACHE
#undef TUTORIAL_HIGHLIGHT_COLOR
