/**
 * # Tutorial highlights
 *
 * Points one viewer at what their open tutorial item needs next: gold outlines on things
 * nearby, an arrow at the screen edge toward a target off screen, and a pulsing outline on
 * the right button in windows that opt in (tutorial_ui_focus()).
 *
 * ## Which step is pointed at (the guide step)
 * The open item is the one selected in the panel (SSvc_tutorials.selected), else the
 * panel's suggested item. Its guide step is the first step, in panel order, that is
 * undone, not excused, and has something to point at for this viewer:
 * 1. a highlight candidate (highlight_types match or extra_targets() entry, kept by
 *    highlight_filter()) on their z-level, or
 * 2. a ui_focus entry, or
 * 3. a non-null arrow_target().
 * If no step has any of these, the guide step is the first undone, non-excused step.
 * Outlines, the arrow and window focus all follow the guide step, never a different one.
 *
 * ## Rendering
 * Outlines: one client /image per outlined atom, attached to the atom (loc = target). Objects
 * and mobs get a copy of their appearance with an outline and glow filter, a hair BELOW the
 * target's layer on its own plane, so the real sprite covers the copy and only the gold ring
 * shows. Turfs get a gold square frame just above the floor. Images go only into the
 * viewer's client.images, so nobody else sees them. They are hidden by walls like the target.
 *
 * Arrow: one /atom/movable/screen/tutorial_arrow per viewer in their client.screen, placed one
 * tile in from the edge of their view (client.view, so widescreen works) on the line toward
 * the target and turned to face it. Hidden while the target is on screen or there is none.
 *
 * ## Cost
 * Nothing runs per tick. A rebuild (step choice, scans, arrow target) happens on a refresh
 * trigger (panel open/close/select, a credit, a pref toggle, the panel's 5 s live refresh) or
 * when the viewer walks a few tiles or changes z-level, at most once per
 * TUTORIAL_HIGHLIGHT_MOVE_COOLDOWN. Between rebuilds each step the viewer takes only moves the
 * arrow (math, no scan). Ship-wide scans are cached per ship and step.
 */

/// Most atoms outlined at once.
#define TUTORIAL_HIGHLIGHT_CAP 3
/// Radius of the in-view search.
#define TUTORIAL_HIGHLIGHT_VIEW_RANGE 9
/// How far a candidate may be and still be outlined.
#define TUTORIAL_HIGHLIGHT_SHIP_RANGE 24
/// How far the default off-screen arrow will point.
#define TUTORIAL_ARROW_RANGE 60
/// Shortest gap between two movement-driven rebuilds.
#define TUTORIAL_HIGHLIGHT_MOVE_COOLDOWN (2 SECONDS)
/// Tiles walked before a movement-driven rebuild is considered.
#define TUTORIAL_HIGHLIGHT_MOVE_TILES 3
/// How long a ship-wide scan for one step stays cached.
#define TUTORIAL_HIGHLIGHT_SHIP_CACHE (10 SECONDS)
/// The outline colour the owner approved.
#define TUTORIAL_HIGHLIGHT_COLOR "#FFC83C"
/// The dim end of the outline pulse.
#define TUTORIAL_HIGHLIGHT_COLOR_DIM "#8A5A10"

/// ckey -> /datum/tutorial_highlight for every viewer that currently has one.
GLOBAL_LIST_EMPTY(tutorial_highlighters)

/**
 * Rebuilds the viewer's tutorial highlights and arrow. Called when the panel opens or closes,
 * when the viewer selects an item, when the highlight preference changes, and when a step is
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

/**
 * Forces a full refresh for one viewer: outlines, arrow, window focus and the open panel.
 * Call it after a state change that a live_line() or highlight_filter() reads, when no
 * credit follows to do it for you.
 */
/proc/tutorial_refresh(mob/user)
	if(!user)
		return
	tutorial_refresh_highlights(user)
	SStgui.try_update_ui(user, GLOB.tutorial_checklist)

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

/// The viewer's open item: the one selected in the panel, else the suggested one. Null if none.
/proc/tutorial_open_item(mob/user)
	var/ckey = tutorial_viewer_ckey(user)
	if(!ckey)
		return null
	SSvc_tutorials.build_catalog()
	var/item_id = SSvc_tutorials.selected[ckey] || SSvc_tutorials.suggested_item(ckey, user)
	if(!item_id)
		return null
	for(var/datum/vc_tutorial/item as anything in SSvc_tutorials.items)
		if(item.id == item_id)
			return item
	return null

/// The viewer's guide step (see the file header), or null.
/proc/tutorial_highlight_step(mob/user)
	return tutorial_pick_guide_step(user, tutorial_open_item(user))

/// The guide step of one item for this viewer (see the file header), or null.
/proc/tutorial_pick_guide_step(mob/user, datum/vc_tutorial/item)
	var/ckey = tutorial_viewer_ckey(user)
	if(!ckey || !item)
		return null
	var/list/done = SSvc_tutorials.progress[ckey]
	var/datum/vc_tutorial_step/first
	for(var/datum/vc_tutorial_step/step as anything in item.steps)
		if(done?[step.key] || step.excused(user))
			continue
		first ||= step
		if(length(tutorial_step_candidates(user, step)) || length(step.ui_focus) || step.arrow_target(user))
			return step
	return first

/**
 * The focus key for one window, or null. A window sends it from ui_data as "tutorial_focus"
 * and wraps its buttons in <TutorialFocus id="...">. It reads the viewer's last guide step, so
 * it is a few list lookups and safe in ui_data. Null unless the viewer has the checklist on
 * and the highlight preference on (only then do they have a highlighter).
 */
/proc/tutorial_ui_focus(mob/user, window_id)
	if(!user || !window_id)
		return null
	var/datum/tutorial_highlight/highlight = GLOB.tutorial_highlighters[tutorial_viewer_ckey(user)]
	if(!highlight || highlight.viewer != user || !highlight.step_key)
		return null
	var/datum/vc_tutorial_step/step = SSvc_tutorials.steps_by_key?[highlight.step_key]
	return step?.ui_focus?[window_id]

/**
 * Every highlight candidate for one step and viewer, unsorted: highlight_types matches in
 * view, object and turf matches aboard their ship, plus extra_targets(), all on the viewer's
 * z-level and kept by highlight_filter(). Held items and anything inside something else are
 * skipped. The viewer is never a candidate. Memoised per step while a rebuild runs.
 */
/proc/tutorial_step_candidates(mob/user, datum/vc_tutorial_step/step)
	var/turf/center = get_turf(user)
	if(!center || !step)
		return list()
	var/datum/tutorial_highlight/highlight = GLOB.tutorial_highlighters[tutorial_viewer_ckey(user)]
	if(highlight?.viewer != user)
		highlight = null
	var/list/memo = highlight?.candidate_memo
	if(memo && memo[step.key])
		return memo[step.key]
	var/list/found = list()
	var/list/types = step.highlight_types
	if(length(types))
		var/wants_turfs = FALSE
		for(var/type in types)
			if(ispath(type, /turf))
				wants_turfs = TRUE
				break
		var/list/seen = memo ? highlight.view_memo : null
		if(!seen)
			seen = view(TUTORIAL_HIGHLIGHT_VIEW_RANGE, user)
			if(memo)
				highlight.view_memo = seen
		for(var/atom/thing in seen)
			if(thing == user || isarea(thing))
				continue
			if(isturf(thing))
				if(!wants_turfs)
					continue
			else if(!isturf(thing.loc))
				continue
			if(is_type_in_list(thing, types))
				found[thing] = TRUE
		var/obj/structure/overmap/ship/ship = get_ship_from_atom(user)
		if(ship)
			for(var/atom/thing as anything in tutorial_ship_candidates(ship, step, highlight, wants_turfs))
				if(thing != user && thing.z == center.z)
					found[thing] = TRUE
	for(var/atom/extra as anything in step.extra_targets(user))
		if(QDELETED(extra) || extra == user)
			continue
		var/turf/extra_turf = get_turf(extra)
		if(extra_turf?.z == center.z)
			found[extra] = TRUE
	var/list/result = list()
	for(var/atom/thing as anything in found)
		if(step.highlight_filter(user, thing))
			result += thing
	if(memo)
		memo[step.key] = result
	return result

/// highlight_types object and turf matches aboard a ship (mobs come only from view(), so
/// nobody is tracked through walls). Cached on the highlighter (if given) per ship and step,
/// because it walks every ship area.
/proc/tutorial_ship_candidates(obj/structure/overmap/ship/ship, datum/vc_tutorial_step/step, datum/tutorial_highlight/highlight, wants_turfs)
	var/list/result = list()
	if(highlight)
		var/ship_ref = REF(ship)
		if(highlight.ship_cache_ship != ship_ref)
			highlight.ship_cache = list()
			highlight.ship_cache_ship = ship_ref
		var/list/cached = highlight.ship_cache[step.key]
		if(cached && world.time < cached[1] + TUTORIAL_HIGHLIGHT_SHIP_CACHE)
			for(var/datum/weakref/ref as anything in cached[2])
				var/atom/thing = ref.resolve()
				if(thing && (isturf(thing) || isturf(thing.loc)))
					result += thing
			return result
	if(!ship.shuttle?.shuttle_areas)
		return result
	var/list/types = step.highlight_types
	var/list/refs = list()
	for(var/area/ship_area as anything in ship.shuttle.shuttle_areas)
		// Objects only: a ship-wide mob match would track people through walls.
		for(var/obj/thing in ship_area)
			if(isturf(thing.loc) && is_type_in_list(thing, types))
				result += thing
				refs += WEAKREF(thing)
		if(!wants_turfs)
			continue
		for(var/turf/floor in ship_area)
			if(is_type_in_list(floor, types))
				result += floor
				refs += WEAKREF(floor)
	if(highlight)
		highlight.ship_cache[step.key] = list(world.time, refs)
	return result

/**
 * The default arrow target: null while any candidate is on the viewer's screen, else the
 * nearest candidate on their z-level within TUTORIAL_ARROW_RANGE tiles.
 */
/proc/tutorial_default_arrow_target(mob/user, list/candidates)
	var/turf/center = tutorial_screen_center(user)
	if(!center || !length(candidates))
		return null
	var/list/view_size = getviewsize(user.client ? user.client.view : world.view)
	var/atom/nearest
	var/nearest_dist
	for(var/atom/thing as anything in candidates)
		var/turf/spot = get_turf(thing)
		if(!spot || spot.z != center.z)
			continue
		if(tutorial_on_screen(center, spot, view_size))
			return null
		var/dist = get_dist(center, spot)
		if(dist > TUTORIAL_ARROW_RANGE)
			continue
		if(!nearest || dist < nearest_dist)
			nearest = thing
			nearest_dist = dist
	return nearest

/// The turf the viewer's screen is centred on.
/proc/tutorial_screen_center(mob/user)
	return get_turf(user?.client?.eye || user)

/// TRUE when spot is inside the screen centred on center, for a getviewsize() list.
/proc/tutorial_on_screen(turf/center, turf/spot, list/view_size)
	if(!center || !spot || center.z != spot.z)
		return FALSE
	return abs(spot.x - center.x) <= (view_size[1] - 1) / 2 && abs(spot.y - center.y) <= (view_size[2] - 1) / 2

/**
 * One viewer's outlines and arrow. Lives in GLOB.tutorial_highlighters under the viewer's
 * ckey until logout, death, ghosting, or the viewer no longer wanting outlines.
 */
/datum/tutorial_highlight
	/// The ckey this belongs to.
	var/ckey
	/// The body we're watching. Cleared when it logs out, dies, ghosts or is deleted.
	var/mob/viewer
	/// The client the images and arrow were pushed to, kept so they can be taken back off it.
	var/client/shown_client
	/// target atom -> its /image
	var/list/images = list()
	/// When non-null, used instead of tutorial_highlights_wanted(). Unit tests set it.
	var/wanted_override
	/// world.time of the last movement-driven rebuild.
	var/last_move_rebuild = 0
	/// Turf of the last rebuild, for the "walked a few tiles" check.
	var/turf/last_turf
	/// Key of the current guide step, or null. tutorial_ui_focus() reads it.
	var/step_key
	/// REF() of the ship the cache below is for.
	var/ship_cache_ship
	/// step key -> list(world.time, list of weakrefs) of ship-wide scan results.
	var/list/ship_cache = list()
	/// step key -> candidate list, only while a rebuild runs (so no hard refs outlive it).
	var/list/candidate_memo
	/// The viewer's view() list, only while a rebuild runs.
	var/list/view_memo
	/// The off-screen arrow, made on first use.
	var/atom/movable/screen/tutorial_arrow/arrow
	/// What the arrow points at.
	var/datum/weakref/arrow_target_ref

/datum/tutorial_highlight/New(mob/user)
	. = ..()
	ckey = tutorial_viewer_ckey(user)
	GLOB.tutorial_highlighters[ckey] = src
	watch(user)

/datum/tutorial_highlight/Destroy()
	clear_images()
	hide_arrow()
	QDEL_NULL(arrow)
	arrow_target_ref = null
	unwatch()
	shown_client = null
	last_turf = null
	candidate_memo = null
	view_memo = null
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

/// Recomputes the guide step, outlines and arrow target.
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
	candidate_memo = list()
	var/datum/vc_tutorial_step/step = wanted ? tutorial_highlight_step(user) : null
	step_key = step?.key
	if(!step)
		candidate_memo = null
		view_memo = null
		set_targets(list())
		set_arrow_target(null)
		stop_tracking_movement()
		return
	set_targets(pick_outlined(user, tutorial_step_candidates(user, step)))
	set_arrow_target(step.arrow_target(user))
	candidate_memo = null
	view_memo = null
	start_tracking_movement()

/// The nearest candidates within TUTORIAL_HIGHLIGHT_SHIP_RANGE, at most TUTORIAL_HIGHLIGHT_CAP.
/datum/tutorial_highlight/proc/pick_outlined(mob/user, list/candidates)
	var/turf/center = get_turf(user)
	var/list/by_distance = list()
	if(!center)
		return by_distance
	for(var/atom/thing as anything in candidates)
		var/turf/spot = get_turf(thing)
		if(!spot || spot.z != center.z || get_dist(center, spot) > TUTORIAL_HIGHLIGHT_SHIP_RANGE)
			continue
		by_distance[thing] = get_dist_euclidean(center, spot)
	sortTim(by_distance, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE)
	var/list/result = list()
	for(var/atom/thing as anything in by_distance)
		result += thing
		if(length(result) >= TUTORIAL_HIGHLIGHT_CAP)
			break
	return result

/// Makes the outlined set exactly new_targets, reusing images for targets that stay.
/datum/tutorial_highlight/proc/set_targets(list/new_targets)
	for(var/atom/old_target as anything in images.Copy())
		if(!(old_target in new_targets))
			remove_target(old_target)
	for(var/atom/target as anything in new_targets)
		if(!images[target])
			add_target(target)
	sync_client()

/datum/tutorial_highlight/proc/add_target(atom/target)
	images[target] = make_image(target)
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_target_deleted))
	RegisterSignals(target, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_POST_DIR_CHANGE), PROC_REF(on_target_look_changed))

/datum/tutorial_highlight/proc/remove_target(atom/target)
	var/image/old_image = images[target]
	images -= target
	UnregisterSignal(target, list(COMSIG_QDELETING, COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_POST_DIR_CHANGE))
	if(old_image)
		shown_client?.images -= old_image

/// The outline image for one target.
/datum/tutorial_highlight/proc/make_image(atom/target)
	if(isturf(target))
		return make_turf_image(target)
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
	// KEEP_APART: a KEEP_TOGETHER target (humans) would otherwise tint and filter the outline with itself.
	outline.appearance_flags |= KEEP_TOGETHER | RESET_COLOR | KEEP_APART
	outline.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	outline.alpha = 255
	// A tinted target (atom colour or a colour matrix) would tint the gold outline too.
	outline.color = null
	outline.filters = list(
		filter(type = "outline", size = 1, color = TUTORIAL_HIGHLIGHT_COLOR),
		filter(type = "drop_shadow", x = 0, y = 0, size = 2, offset = 1, color = "[TUTORIAL_HIGHLIGHT_COLOR]90"),
	)
	pulse(outline)
	pulse_filters(outline.filters[1], outline.filters[2])
	return outline

/// A gold square frame on a turf, just above the floor and under anything standing on it.
/// (A copy of the turf would sit under its neighbours, which would hide the ring.)
/datum/tutorial_highlight/proc/make_turf_image(turf/target)
	var/image/frame = image('icons/hud/screen_gen.dmi', target, "selector")
	frame.plane = target.plane
	frame.layer = isopenturf(target) ? ABOVE_OPEN_TURF_LAYER : target.layer + 0.001
	frame.color = TUTORIAL_HIGHLIGHT_COLOR
	frame.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART
	frame.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	frame.filters = filter(type = "drop_shadow", x = 0, y = 0, size = 2, offset = 0, color = "[TUTORIAL_HIGHLIGHT_COLOR]90")
	pulse(frame)
	pulse_filters(null, frame.filters[1])
	return frame

/// The shared slow alpha pulse.
/datum/tutorial_highlight/proc/pulse(image/target_image)
	animate(target_image, alpha = 110, time = 0.8 SECONDS, loop = -1, easing = SINE_EASING)
	animate(alpha = 255, time = 0.8 SECONDS, easing = SINE_EASING)

/// Breathes the outline between bright and dark gold and the glow in and out, in step with pulse().
/datum/tutorial_highlight/proc/pulse_filters(outline_filter, glow_filter)
	if(outline_filter)
		animate(outline_filter, color = TUTORIAL_HIGHLIGHT_COLOR_DIM, time = 0.8 SECONDS, loop = -1, easing = SINE_EASING)
		animate(color = TUTORIAL_HIGHLIGHT_COLOR, time = 0.8 SECONDS, easing = SINE_EASING)
	if(glow_filter)
		animate(glow_filter, size = 0, time = 0.8 SECONDS, loop = -1, easing = SINE_EASING)
		animate(size = 4, time = 0.8 SECONDS, easing = SINE_EASING)

/// Puts the current images on the viewer's client and takes images and arrow off any old client.
/datum/tutorial_highlight/proc/sync_client()
	var/client/current = viewer?.client
	if(shown_client && shown_client != current)
		for(var/atom/target as anything in images)
			shown_client.images -= images[target]
		if(arrow)
			shown_client.screen -= arrow
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

/datum/tutorial_highlight/proc/set_arrow_target(atom/target)
	arrow_target_ref = target ? WEAKREF(target) : null
	update_arrow()

/**
 * Places the arrow toward its target, one tile in from the edge of the viewer's screen, or
 * hides it when the target is gone, on another z-level, or on screen. Math only, no scan:
 * it runs on every step the viewer takes.
 */
/datum/tutorial_highlight/proc/update_arrow()
	var/atom/target = arrow_target_ref?.resolve()
	var/client/current = viewer?.client
	var/turf/center = tutorial_screen_center(viewer)
	var/turf/spot = get_turf(target)
	if(!target || !current || !center || !spot || spot.z != center.z)
		hide_arrow()
		return
	var/list/view_size = getviewsize(current.view)
	if(tutorial_on_screen(center, spot, view_size))
		hide_arrow()
		return
	if(!arrow)
		arrow = new
	arrow.point(spot.x - center.x, spot.y - center.y, view_size)
	if(shown_client != current)
		sync_client()
	current.screen |= arrow

/// TRUE while the arrow is on the viewer's screen. For unit tests and debugging.
/datum/tutorial_highlight/proc/arrow_shown()
	return !!(arrow && viewer?.client && (arrow in viewer.client.screen))

/datum/tutorial_highlight/proc/hide_arrow()
	if(!arrow)
		return
	shown_client?.screen -= arrow
	viewer?.client?.screen -= arrow

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
	update_arrow()
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
/datum/tutorial_highlight/proc/on_target_look_changed(atom/source)
	SIGNAL_HANDLER
	var/image/old_image = images[source]
	if(!old_image)
		return
	shown_client?.images -= old_image
	images[source] = make_image(source)
	shown_client?.images |= images[source]

/// Logout, death, ghosting or deletion: drop the outlines and arrow. A later refresh (the
/// panel, a credit) brings them back if the viewer still wants them.
/datum/tutorial_highlight/proc/on_viewer_gone(mob/source)
	SIGNAL_HANDLER
	qdel(src)

/**
 * The tutorial's off-screen arrow. One per viewer, owned by their /datum/tutorial_highlight;
 * it only ever sits in that viewer's client.screen.
 */
/atom/movable/screen/tutorial_arrow
	name = ""
	icon = 'voidcrew/icons/hud/tutorial_arrow.dmi'
	icon_state = "arrow"
	color = TUTORIAL_HIGHLIGHT_COLOR
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	animate_movement = NO_STEPS
	screen_loc = "CENTER,CENTER"

/atom/movable/screen/tutorial_arrow/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	add_filter("tutorial_arrow_glow", 1, drop_shadow_filter(x = 0, y = 0, size = 3, offset = 0, color = "[TUTORIAL_HIGHLIGHT_COLOR]90"))
	animate(src, alpha = 150, time = 0.8 SECONDS, loop = -1, easing = SINE_EASING)
	animate(alpha = 255, time = 0.8 SECONDS, easing = SINE_EASING)

/**
 * Places the arrow on the line from the screen centre toward a target dx, dy tiles away,
 * one tile in from the screen edge, and turns it to face the target.
 *
 * The facing snaps to the nearest of eight directions. Cardinals use the straight sprite and
 * diagonals a hand-drawn 45 degree one, each only ever turned by whole right angles, so the
 * pixel art is never resampled (a free rotation renders jagged).
 */
/atom/movable/screen/tutorial_arrow/proc/point(dx, dy, list/view_size)
	var/edge_x = max((view_size[1] - 1) / 2 - 1, 0)
	var/edge_y = max((view_size[2] - 1) / 2 - 1, 0)
	// The bottom row of the screen holds the HUD buttons, so a downward arrow stays one tile higher.
	if(dy < 0)
		edge_y = max(edge_y - 1, 0)
	var/scale = 0
	if(dx && dy)
		scale = min(edge_x / abs(dx), edge_y / abs(dy))
	else if(dx)
		scale = edge_x / abs(dx)
	else if(dy)
		scale = edge_y / abs(dy)
	var/offset_x = round(dx * scale * ICON_SIZE_X)
	var/offset_y = round(dy * scale * ICON_SIZE_Y)
	screen_loc = "CENTER[screen_offset_text(offset_x, ICON_SIZE_X)],CENTER[screen_offset_text(offset_y, ICON_SIZE_Y)]"
	// delta_to_angle() is clockwise from north. "arrow" points south (180), "arrow_diagonal"
	// south-east (135).
	var/sector = round(delta_to_angle(dx, dy) / 45, 1) % 8
	icon_state = ISODD(sector) ? "arrow_diagonal" : "arrow"
	var/matrix/turned = matrix()
	turned.Turn(sector * 45 - (ISODD(sector) ? 135 : 180))
	transform = turned

/// "+tiles:pixels" or "-tiles:pixels" for a pixel offset from a screen anchor, pixels 0 to tile_size - 1.
/atom/movable/screen/tutorial_arrow/proc/screen_offset_text(pixels, tile_size)
	var/tiles = round(pixels / tile_size)
	var/remainder = pixels - tiles * tile_size
	return "[tiles >= 0 ? "+" : ""][tiles]:[remainder]"

#undef TUTORIAL_HIGHLIGHT_CAP
#undef TUTORIAL_HIGHLIGHT_VIEW_RANGE
#undef TUTORIAL_HIGHLIGHT_SHIP_RANGE
#undef TUTORIAL_ARROW_RANGE
#undef TUTORIAL_HIGHLIGHT_MOVE_COOLDOWN
#undef TUTORIAL_HIGHLIGHT_MOVE_TILES
#undef TUTORIAL_HIGHLIGHT_SHIP_CACHE
#undef TUTORIAL_HIGHLIGHT_COLOR
#undef TUTORIAL_HIGHLIGHT_COLOR_DIM
