/**
 * # Chrome Cradle preview trace — TEMPORARY DEBUG SCAFFOLD
 *
 * Everything in this file is compiled out unless `CRADLE_TRACE` is defined in
 * code/_compile_options.dm. It exists to answer one question in a single round
 * of play: when the cradle's body preview renders as a pure black panel, which
 * link of the map_view chain is actually broken?
 *
 * The chain, for reference:
 *
 *   1. ensure_preview_mirror()  mints a map_view and calls generate_view(key),
 *      which sets assigned_map = key and screen_loc = "key:1:0,1:0".
 *   2. ui_data() ships that key to the interface as `preview_view`.
 *   3. <ByondUi params={{id: key, type: 'map'}}> winsets a native map control
 *      NAMED key, parented to the tgui window, sized from its measured rect.
 *   4. display_to() -> display_to_client() registers the screen object into
 *      client.screen + client.screen_maps[key], and builds a popup plane
 *      master group whose masters all carry assigned_map = key.
 *
 * A break at any link produces the same symptom — black — so the trace records
 * each link separately rather than trying to be clever. See INTERPRETATION.md.
 *
 * Read the result with:  type data\cradle_trace.log
 */

#ifdef CRADLE_TRACE

/// Bumped per line so interleaved events keep their true order even inside one
/// world.time tick — most of this chain fires several times per tick.
GLOBAL_VAR_INIT(cradle_trace_seq, 0)

/// One line into data/cradle_trace.log.
/proc/cradle_trace(text)
	GLOB.cradle_trace_seq++
	WRITE_LOG(CRADLE_TRACE_FILE, "#[GLOB.cradle_trace_seq] t=[world.time] [text]")

/// TRUE for map keys this scaffold cares about, so the hooks living in shared
/// upstream code (map_view.dm) stay silent for cameras, mechs and prefs.
/proc/is_cradle_map(map_key)
	return map_key && findtext(map_key, "chrome_mirror_") == 1

/**
 * Everything about a screen object that could plausibly render it invisible,
 * on one line. Deliberately includes the vars an `appearance = X` assignment
 * overwrites, since that is how the mannequin's look reaches the mirror.
 */
/proc/cradle_describe_screen_obj(atom/movable/screen/thing)
	if(isnull(thing))
		return "NULL"
	if(QDELETED(thing))
		return "QDELETED ref=[REF(thing)]"
	var/list/overlay_list = thing.overlays
	var/list/underlay_list = thing.underlays
	var/list/filter_list = thing.filters
	return "[thing.type] ref=[REF(thing)] map=[thing.assigned_map || "NONE"] loc=[thing.screen_loc || "NONE"] \
icon=[thing.icon || "NONE"] state=[thing.icon_state || "NONE"] overlays=[length(overlay_list)] \
underlays=[length(underlay_list)] alpha=[thing.alpha] plane=[thing.plane] layer=[thing.layer] dir=[thing.dir] \
invis=[thing.invisibility] aflags=[thing.appearance_flags] blend=[thing.blend_mode] color=[thing.color || "none"] \
filters=[length(filter_list)] rtarget=[thing.render_target || "none"] rsource=[thing.render_source || "none"] \
vis_contents=[length(thing.vis_contents)] transform=[isnull(thing.transform) ? "null" : "set"] \
del_on_removal=[thing.del_on_map_removal] mouse_op=[thing.mouse_opacity]"

/// client.screen_maps as one line: every registered map key and how many screen
/// objects sit under it.
/proc/cradle_describe_screen_maps(client/viewer)
	if(isnull(viewer))
		return "NO CLIENT"
	var/list/parts = list()
	for(var/map_key in viewer.screen_maps)
		var/list/objects = viewer.screen_maps[map_key]
		parts += "[map_key]=[length(objects)]"
	if(!length(parts))
		return "EMPTY"
	return jointext(parts, " ")

/**
 * The whole popup plane master group for one mirror, from the point of view of
 * one client. This is the probe that separates "the atoms never arrived" from
 * "the atoms arrived and BYOND still drew nothing".
 *
 * verbose = TRUE dumps every plane master (~40 per z offset). FALSE dumps the
 * summary plus only the planes that can single-handedly black the panel: the
 * one matching the mirror's own plane, and every rendering plate at offset 0.
 */
/proc/cradle_dump_planes(client/viewer, atom/movable/screen/map_view/mirror, prefix = "PLANES", verbose = FALSE)
	if(isnull(viewer))
		cradle_trace("[prefix] ABORT no client")
		return
	if(QDELETED(mirror))
		cradle_trace("[prefix] ABORT no mirror")
		return

	// Cheap membership test against client.screen, which is a big special list.
	var/list/on_screen = list()
	for(var/atom/movable/thing in viewer.screen)
		on_screen[thing] = TRUE

	var/mob/viewer_mob = viewer.mob
	var/datum/hud/our_hud = viewer_mob?.hud_used
	cradle_trace("[prefix] client=[viewer.ckey] mob=[viewer_mob] ([viewer_mob?.type]) hud=[our_hud ? REF(our_hud) : "NULL"] \
hud_mymob=[our_hud?.mymob] hud_offset=[our_hud?.current_plane_offset] max_plane_offset=[SSmapping.max_plane_offset] \
screen_total=[length(on_screen)] screen_maps=[cradle_describe_screen_maps(viewer)]")
	cradle_trace("[prefix] mirror=[cradle_describe_screen_obj(mirror)] mirror_on_screen=[on_screen[mirror] ? "YES" : "NO"] \
mirror_in_screen_maps=[(mirror in viewer.screen_maps[mirror.assigned_map]) ? "YES" : "NO"]")

	if(isnull(our_hud))
		cradle_trace("[prefix] ABORT viewer mob has no hud_used — no plane group can exist")
		return

	var/group_key = PLANE_GROUP_POPUP_WINDOW(mirror)
	var/list/group_keys = list()
	for(var/existing_key in our_hud.master_groups)
		group_keys += existing_key
	var/datum/plane_master_group/group = our_hud.master_groups[group_key]
	cradle_trace("[prefix] want_group=[group_key] found=[group ? "YES" : "NO"] all_hud_groups=[jointext(group_keys, ",")]")
	if(isnull(group))
		return

	cradle_trace("[prefix] group map=[group.map || "NONE"] active_offset=[group.active_offset] relay_loc=[group.relay_loc] \
plane_count=[length(group.plane_masters)] group_hud=[group.our_hud ? REF(group.our_hud) : "NULL"]")

	var/masters_on = 0
	var/masters_off = 0
	var/relays_total = 0
	var/relays_on = 0
	var/hidden_count = 0
	var/oob_count = 0
	var/zero_alpha = 0
	var/list/missing_names = list()
	var/mirror_plane_master_found = FALSE
	var/mirror_plane_master_on = FALSE

	for(var/plane_key in group.plane_masters)
		var/atom/movable/screen/plane_master/plane = group.plane_masters[plane_key]
		if(QDELETED(plane))
			missing_names += "[plane_key](QDELETED)"
			continue
		var/present = on_screen[plane] ? TRUE : FALSE
		if(present)
			masters_on++
		else
			masters_off++
			if(length(missing_names) < 30)
				missing_names += "[plane.name]#[plane.plane]"
		if(plane.force_hidden)
			hidden_count++
		if(plane.is_outside_bounds)
			oob_count++
		if(plane.alpha == 0)
			zero_alpha++

		var/local_relays_on = 0
		for(var/atom/movable/relay as anything in plane.relays)
			relays_total++
			if(on_screen[relay])
				relays_on++
				local_relays_on++

		var/is_mirror_plane = (plane.plane == mirror.plane)
		if(is_mirror_plane)
			mirror_plane_master_found = TRUE
			mirror_plane_master_on = present

		// Rendering plates are the ones that can black the whole map on their
		// own (the lighting plate multiplies, the master plate is the output).
		var/is_plate = istype(plane, /atom/movable/screen/plane_master/rendering_plate)
		if(!verbose && !is_mirror_plane && !(is_plate && plane.offset == 0))
			continue

		var/list/plane_filters = plane.filters
		var/list/relay_planes = plane.render_relay_planes
		cradle_trace("[prefix] PLANE [plane.name] plane=[plane.plane] real=[plane.real_plane] off=[plane.offset] \
map=[plane.assigned_map || "NONE"] loc=[plane.screen_loc || "NONE"] on_screen=[present ? "YES" : "NO"] \
alpha=[plane.alpha] true_alpha=[plane.true_alpha] alpha_en=[plane.alpha_enabled] hidden=[plane.force_hidden] \
oob=[plane.is_outside_bounds] crit=[plane.critical] blend=[plane.blend_mode] mz_scaled=[plane.multiz_scaled] \
rtarget=[plane.render_target || "none"] filters=[length(plane_filters)] \
relays=[length(plane.relays)]/on=[local_relays_on] relay_planes=[jointext(relay_planes, "|")]")

	cradle_trace("[prefix] TOTALS masters_on=[masters_on] masters_off=[masters_off] relays=[relays_total] \
relays_on=[relays_on] force_hidden=[hidden_count] outside_bounds=[oob_count] alpha0=[zero_alpha] \
mirror_plane=[mirror.plane] master_for_mirror_plane=[mirror_plane_master_found ? "YES" : "NO"] \
that_master_on_screen=[mirror_plane_master_on ? "YES" : "NO"]")
	if(length(missing_names))
		cradle_trace("[prefix] NOT_ON_SCREEN [jointext(missing_names, ", ")]")

	// The lighting plate is BLEND_MULTIPLY. It needs a backdrop drawn on the
	// SAME map to have anything to brighten; a backdrop that landed on the main
	// map instead leaves the popup multiplying against nothing.
	for(var/plane_key in group.plane_masters)
		var/atom/movable/screen/plane_master/plane = group.plane_masters[plane_key]
		if(!istype(plane, /atom/movable/screen/plane_master/rendering_plate/lighting))
			continue
		for(var/suffix in list("lit", "unlit"))
			var/category = "lighting_backdrop_[suffix]_[group.key]#[plane.offset]"
			var/atom/movable/screen/backdrop = viewer_mob.screens?[category]
			if(isnull(backdrop))
				cradle_trace("[prefix] BACKDROP [category] MISSING")
				continue
			cradle_trace("[prefix] BACKDROP [category] map=[backdrop.assigned_map || "NONE"] \
loc=[backdrop.screen_loc || "NONE"] plane=[backdrop.plane] alpha=[backdrop.alpha] \
on_screen=[on_screen[backdrop] ? "YES" : "NO"] icon=[backdrop.icon || "none"] state=[backdrop.icon_state || "none"]")

/**
 * The verb the player runs while staring at the black panel.
 *
 * winget() and winexists() both sleep — they round-trip to the client — which
 * is exactly why this lives in a verb and not in ui_data or a signal handler.
 */
/client/verb/cradle_debug_dump()
	set name = "Cradle Debug Dump"
	set category = "Debug"
	set desc = "Dump the Chrome Cradle preview pipeline to chat and data/cradle_trace.log."

	cradle_trace("========== MANUAL DUMP BEGIN ckey=[ckey] ==========")
	to_chat(src, "<b>Cradle debug dump running — this takes a second (it queries your skin).</b>")

	var/mob/our_mob = mob
	cradle_trace("DUMP mob=[our_mob] type=[our_mob?.type] loc=[our_mob?.loc] z=[our_mob?.z] \
hud=[our_mob?.hud_used ? REF(our_mob.hud_used) : "NULL"] hud_offset=[our_mob?.hud_used?.current_plane_offset] \
max_plane_offset=[SSmapping.max_plane_offset] view=[view]")
	cradle_trace("DUMP screen_maps=[cradle_describe_screen_maps(src)]")

	// ---- 1. every open cradle UI, and the key ui_data is currently sending --
	var/list/cradle_map_keys = list()
	var/list/window_ids = list()
	for(var/datum/tgui/ui in our_mob?.tgui_open_uis)
		if(!istype(ui.src_object, /obj/machinery/chrome_cradle))
			continue
		var/obj/machinery/chrome_cradle/cradle = ui.src_object
		var/atom/movable/screen/map_view/mirror = cradle.viewer_mirrors[our_mob]
		var/datum/tgui_window/window = ui.window
		cradle_trace("DUMP UI cradle=[REF(cradle)] interface=[ui.interface] status=[ui.status] \
window_id=[window?.id] window_visible=[window?.visible] window_status=[window?.status] \
window_is_browser=[window?.is_browser] window_locked=[window?.locked] \
mirror=[mirror ? REF(mirror) : "NONE-FOR-THIS-MOB"] mirror_key=[mirror?.assigned_map || "NONE"] \
occupant=[cradle.occupant] viewer_mirror_count=[length(cradle.viewer_mirrors)]")
		if(mirror)
			cradle_map_keys |= mirror.assigned_map
		if(window?.id)
			window_ids |= window.id

	// Also catch mirrors that are registered on the client but no longer owned
	// by any open UI — that mismatch is itself a finding.
	for(var/map_key in screen_maps)
		if(is_cradle_map(map_key))
			cradle_map_keys |= map_key

	if(!length(cradle_map_keys))
		cradle_trace("DUMP NO CRADLE MAP KEYS — neither an open cradle UI nor a registered chrome_mirror_* map")
		to_chat(src, "<b>No cradle map found.</b> Open the Chrome Cradle first, then run this while the panel is black.")

	// ---- 2. server-side state of each cradle map ---------------------------
	for(var/map_key in cradle_map_keys)
		var/list/registered = screen_maps[map_key]
		cradle_trace("DUMP MAP [map_key] registered_objects=[length(registered)]")
		if(!length(registered))
			cradle_trace("DUMP MAP [map_key] NOTHING REGISTERED — display_to_client never ran for this key")
		for(var/atom/movable/screen/screen_obj in registered)
			cradle_trace("DUMP MAP [map_key] OBJ [cradle_describe_screen_obj(screen_obj)]")
			if(istype(screen_obj, /atom/movable/screen/map_view))
				cradle_dump_planes(src, screen_obj, "DUMP", verbose = TRUE)

	// ---- 3. what the skin thinks exists ------------------------------------
	// Client-wide specials. hwmode matters: software rendering changes how
	// plane masters and render targets composite.
	var/client_wide = winget(src, null, "windows;panes;focus;hwmode;url")
	cradle_trace("DUMP WINGET client-wide: [client_wide]")

	for(var/window_id in window_ids)
		var/exists = winexists(src, window_id)
		cradle_trace("DUMP WINGET window [window_id] winexists=[exists || "EMPTY(does not exist)"]")
		// Wildcard form: every control belonging to this window, plus the
		// window itself. This is the only way to learn whether a control with
		// our map key exists AT ALL from the skin's point of view.
		var/children = winget(src, "[window_id].*", "type;pos;size;parent;is-visible;is-disabled;anchor1;anchor2")
		cradle_trace("DUMP WINGET children of [window_id]: [children || "EMPTY"]")

	// Every registered map, not just the cradle's — a records or prefs preview
	// open at dump time gives a side-by-side of a correctly-framed control's
	// zoom/view-size against the cradle's, which is the whole framing question.
	var/list/geometry_keys = cradle_map_keys.Copy()
	for(var/map_key in screen_maps)
		geometry_keys |= map_key
	for(var/map_key in geometry_keys)
		var/exists = winexists(src, map_key)
		cradle_trace("DUMP WINGET control [map_key] winexists=[exists || "EMPTY(does not exist)"]")
		if(!exists)
			continue
		var/geometry = winget(src, map_key, "type;parent;pos;size;is-visible;is-disabled;icon-size;zoom;letterbox;view-size;style")
		cradle_trace("DUMP WINGET control [map_key] geometry: [geometry]")
		var/list/registered_objects = screen_maps[map_key]
		for(var/atom/movable/screen/screen_obj in registered_objects)
			cradle_trace("DUMP WINGET control [map_key] OBJ loc=[screen_obj.screen_loc] [screen_obj.type]")

	cradle_trace("========== MANUAL DUMP END ==========")
	to_chat(src, "<b>Cradle debug dump written to data/cradle_trace.log</b> (last [GLOB.cradle_trace_seq] lines are the whole trace).")

#endif
