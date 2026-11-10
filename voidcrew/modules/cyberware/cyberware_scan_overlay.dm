/**
 * # Chrome read overlay
 *
 * What a chrome read (cyberware_scan.dm) looks like to the reader. Corner
 * brackets snap onto the subject and lock while a red outline of their body
 * pulses inside them. Then a panel opens beside the subject: their visible
 * name, one socket per piece of hardware framed in its tier colour, a short
 * name list and a load bar. The outline fades, the panel holds, and the
 * brackets release as the panel fades out.
 *
 * - Street optics (silhouette resolution) fill the sockets with static and
 *   name nothing.
 * - A Ghostskin subject breaks the lock: the brackets hunt, the outline
 *   flickers into static, the header garbles and "NO LOCK" flashes before it
 *   all drops. That version stays where the lock was tried instead of
 *   following someone the optics can't hold.
 * - A body with no hardware gets the header and "no chrome".
 *
 * Every image is a client image shown to the reader alone, on
 * ABOVE_LIGHTING_PLANE: it draws over darkness, and a flash or blindfold still
 * hides it because blindness lives on FULLSCREEN_PLANE above it. The images are
 * parented to the SUBJECT, so they follow them without any server work and,
 * just like the subject, are never drawn through a wall. That is on purpose:
 * the read needs line of sight to start, and the readout must not turn into a
 * free wallhack for its whole hold. (/datum/cyberware_hud_mark is the opposite
 * case: it parks on the viewer's turf to draw THROUGH walls.)
 *
 * All motion is animate() on the reader's client. The server builds the
 * images once and runs one timer.
 */

/// Itemized optics on a body with hardware.
#define READOUT_ITEMIZED "itemized"
/// Street optics: counts and load, nothing named.
#define READOUT_SILHOUETTE "silhouette"
/// Ghostskin: the lock breaks.
#define READOUT_SCATTER "scatter"
/// Nothing on the bus.
#define READOUT_CLEAN "clean"

// Timeline, in deciseconds from the click.
/// Brackets snap (0-3) and lock (3-7) while the outline pulses; the panel opens here.
#define READOUT_LOCK_TIME 8.5
/// Header fade-in plus the panel unfolding.
#define READOUT_OPEN_TIME 4.5
#define READOUT_HOLD_TIME 60
#define READOUT_CLEAN_HOLD_TIME 30
#define READOUT_FADE_TIME 6
/// A scattered read drops at this point, without ever locking.
#define READOUT_SCATTER_DROP_AT 18
#define READOUT_SCATTER_FADE_TIME 3

// Geometry, in pixels from the subject's tile origin (y up).
/// Left edge of a panel opening on the right.
#define READOUT_PANEL_X 37
/// Top edge of the panel.
#define READOUT_PANEL_TOP 45
#define READOUT_SOCKETS_PER_ROW 6
#define READOUT_MAX_SOCKETS 18
#define READOUT_MAX_NAME_LINES 8
#define READOUT_MIN_WIDTH 108
#define READOUT_MAX_WIDTH 160
#define READOUT_BAR_SEGMENTS 20
/// The socket icon is 32 px drawn into an 18 px socket.
#define READOUT_SOCKET_ICON_SCALE 0.5625

// Colours.
/// The HUD frame: brackets, panel border, leader line.
#define READOUT_HUD_COLOR CYBERWARE_COLOR_TIER_2
/// The targeting outline. A deep crimson, kept apart from the brighter
/// red-orange of "offline" and the pink of tier 3.
#define READOUT_LOCK_COLOR "#f01d3a"
#define READOUT_LOCK_FILL_COLOR "#c8102a"
#define READOUT_PANEL_COLOR "#060e12"
#define READOUT_NAME_COLOR "#e6fbff"
#define READOUT_DIM_COLOR "#8fa1a8"
#define READOUT_OFFLINE_COLOR "#ff5a4a"
#define READOUT_OFFLINE_NAME_COLOR "#7d8a90"
#define READOUT_STATIC_FRAME_COLOR "#6c7c83"
#define READOUT_GLINT_COLOR "#e9feff"

#define READOUT_ICON 'voidcrew/modules/cyberware/icons/chrome_read.dmi'
#define READOUT_BAR_ICON 'voidcrew/modules/cyberware/icons/chrome_read_bar.dmi'

/datum/chrome_readout
	/// The only person this is drawn for.
	var/mob/living/viewer
	/// The body being read.
	var/mob/living/target
	/// The optics doing the reading. Pulling them ends the readout.
	var/obj/item/organ/optics
	/// What the images hang off: the subject, or for a scatter the turf they
	/// stood on when the lock failed.
	var/atom/anchor
	/// READOUT_* look.
	var/mode
	/// The cyberware_scan_report() being drawn. Null for a scatter.
	var/list/report
	/// Every image, in draw order.
	var/list/image/images = list()
	/// One image per socket drawn.
	var/list/image/sockets = list()
	/// One image per name line drawn, "and N more" included.
	var/list/image/name_lines = list()
	/// image -> list of what play() needs to animate it: its kind, start time,
	/// role ("lock", "panel", "socket", "name", "load") and kind-specific data.
	var/list/cues = list()
	/// The client the images went to. Held because a mob that logged out has none.
	var/client/shown_to
	/// Expiry timer.
	var/timer_id
	/// Deciseconds from creation until everything starts fading, and how long that takes.
	var/fade_at
	var/fade_time
	/// Whole lifetime, deciseconds.
	var/lifetime
	/// Panel geometry.
	var/panel_x
	var/panel_width
	var/panel_height
	/// TRUE when the panel opens on the subject's left, away from the screen edge.
	var/flipped = FALSE
	/// Pixel offset every image carries. Zero on the subject; on a turf it lines
	/// the scatter up with where the subject was drawn.
	var/base_w = 0
	var/base_z = 0

/datum/chrome_readout/New(mob/living/new_viewer, mob/living/new_target, list/new_report, obj/item/organ/new_optics, animated = TRUE)
	. = ..()
	viewer = new_viewer
	target = new_target
	report = new_report
	optics = new_optics
	if(isnull(report))
		mode = READOUT_SCATTER
	else if(!report["count"])
		mode = READOUT_CLEAN
	else if(report["resolution"] < CYBERWARE_SCAN_ITEMIZED)
		mode = READOUT_SILHOUETTE
	else
		mode = READOUT_ITEMIZED

	if(mode == READOUT_SCATTER)
		anchor = get_turf(target)
		base_w = target.pixel_x + target.pixel_w
		base_z = target.pixel_y + target.pixel_z
	else
		anchor = target
	if(isnull(anchor))
		qdel(src)
		return

	RegisterSignals(target, list(COMSIG_QDELETING, COMSIG_MOVABLE_Z_CHANGED), PROC_REF(end_readout))
	RegisterSignal(viewer, COMSIG_MOB_LOGOUT, PROC_REF(end_readout))
	if(viewer != target)
		RegisterSignal(viewer, COMSIG_QDELETING, PROC_REF(end_readout))
	if(optics)
		RegisterSignals(optics, list(COMSIG_ORGAN_REMOVED, COMSIG_QDELETING), PROC_REF(end_readout))

	switch(mode)
		if(READOUT_SCATTER)
			fade_at = READOUT_SCATTER_DROP_AT
			fade_time = READOUT_SCATTER_FADE_TIME
		if(READOUT_CLEAN)
			fade_at = READOUT_LOCK_TIME + READOUT_OPEN_TIME + READOUT_CLEAN_HOLD_TIME
			fade_time = READOUT_FADE_TIME
		else
			fade_at = READOUT_LOCK_TIME + READOUT_OPEN_TIME + READOUT_HOLD_TIME
			fade_time = READOUT_FADE_TIME
	lifetime = fade_at + fade_time + 2

	build_lock()
	build_panel()
	if(viewer.client)
		shown_to = viewer.client
		shown_to.images += images
	// Animate only once the client holds the images, as balloon alerts and runechat do.
	if(animated)
		play()
	timer_id = addtimer(CALLBACK(src, PROC_REF(expire)), lifetime, TIMER_STOPPABLE | TIMER_CLIENT_TIME | TIMER_DELETE_ME)

/datum/chrome_readout/Destroy(force)
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	shown_to?.images -= images
	shown_to = null
	if(target)
		UnregisterSignal(target, list(COMSIG_QDELETING, COMSIG_MOVABLE_Z_CHANGED))
	if(viewer)
		UnregisterSignal(viewer, list(COMSIG_QDELETING, COMSIG_MOB_LOGOUT))
	if(optics)
		UnregisterSignal(optics, list(COMSIG_ORGAN_REMOVED, COMSIG_QDELETING))
	images.Cut()
	sockets.Cut()
	name_lines.Cut()
	cues.Cut()
	viewer = null
	target = null
	optics = null
	anchor = null
	report = null
	return ..()

/// The hold and fade ran out.
/datum/chrome_readout/proc/expire()
	timer_id = null
	qdel(src)

/**
 * Signal proc for the ways a readout ends early: the subject deleted or moved
 * to another z, the reader deleted or logged out (a new client starts with no
 * images, and a ghost must see nothing), or the optics pulled or deleted. A
 * subject who dies keeps theirs; it is a snapshot, and reading a corpse is fair.
 */
/datum/chrome_readout/proc/end_readout(datum/source)
	SIGNAL_HANDLER
	qdel(src)

// ---- Building ----------------------------------------------------------

/// A blank image on the readout's plane, filed for showing and animating.
/datum/chrome_readout/proc/add_image(icon_file, icon_state, role, kind, at = 0)
	var/image/drawn = icon_file ? image(icon_file, anchor, icon_state) : image(loc = anchor)
	drawn.layer = ABOVE_ALL_MOB_LAYER + length(images) * 0.001
	// KEEP_APART: humans are KEEP_TOGETHER, and the readout must not be pulled
	// into their group (their colour, alpha, height filters or lying turn).
	drawn.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART | PIXEL_SCALE
	// Without this a click anywhere on the panel lands on the subject.
	drawn.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	SET_PLANE_EXPLICIT(drawn, ABOVE_LIGHTING_PLANE, anchor)
	drawn.pixel_w = base_w
	drawn.pixel_z = base_z
	images += drawn
	cues[drawn] = list("role" = role, "kind" = kind, "at" = at)
	return drawn

/// A flat rectangle: the white pixel state scaled to size. x/y is the bottom left.
/datum/chrome_readout/proc/add_quad(x, y, width, height, quad_color, quad_alpha, role, kind, at = 0)
	var/image/quad = add_image(READOUT_ICON, "px", role, kind, at)
	quad.color = quad_color
	quad.alpha = quad_alpha
	quad.transform = chrome_readout_quad(x, y, width, height)
	return quad

/**
 * One line of maptext. `cap_row` is how many pixels below the panel's top edge
 * the capitals start. The box is taller than the line and vertically centred,
 * so the font's line height never shifts the text: Grand9K 6pt draws a 12 px
 * cell with caps 3 px down it, TinyUnicode 12pt a 13 px cell with caps 6 px down.
 */
/datum/chrome_readout/proc/add_text(html, x, cap_row, width, tiny, role, kind, at = 0)
	var/image/line = add_image(null, null, role, kind, at)
	line.maptext = html
	line.maptext_x = x
	line.maptext_width = width
	if(tiny)
		line.maptext_height = 17
		line.maptext_y = READOUT_PANEL_TOP - 9 - cap_row
	else
		line.maptext_height = 16
		line.maptext_y = READOUT_PANEL_TOP - 11 - cap_row
	return line

/// Brackets, the red outline pulse, and for a scatter the static it breaks into.
/datum/chrome_readout/proc/build_lock()
	// Draft C's reticle box: three pixels clear of a standing human sprite.
	var/left = 4
	var/right = 26
	var/top = 31
	var/bottom = -2
	if(target.body_position == LYING_DOWN)
		left = -2
		right = 33
		top = 26
		bottom = 4
	for(var/corner in list("nw", "ne", "sw", "se"))
		var/west = findtext(corner, "w")
		var/north = findtext(corner, "n")
		var/image/bracket = add_image(READOUT_ICON, "bracket_[corner]", "lock", "bracket")
		// The corner pixel sits at canvas column 1 or 30, row 30 or 1.
		bracket.pixel_w += (west ? left - 1 : right - 30)
		bracket.pixel_z += (north ? top - 30 : bottom - 1)
		bracket.color = (mode == READOUT_SCATTER) ? "#ffffff" : READOUT_HUD_COLOR
		cues[bracket]["out_w"] = west ? -1 : 1
		cues[bracket]["out_z"] = north ? 1 : -1

	// The outline pulse, taken from the subject's own look at this moment.
	var/image/fill = add_body_copy("lock", "lock_body")
	var/list/fill_rgb = rgb2num(READOUT_LOCK_FILL_COLOR)
	var/static/icon/stripes_mask = icon(READOUT_ICON, "stripes")
	apply_filters(fill, list(
		// Flat crimson at a third of the body's alpha...
		list("type" = "color", "color" = list(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, fill_rgb[1] / 255, fill_rgb[2] / 255, fill_rgb[3] / 255, 0.33, 0, 0, 0, 0)),
		// ...on every third row.
		list("type" = "alpha", "icon" = stripes_mask),
	))
	cues[fill]["roll"] = 2
	var/image/edge = add_body_copy("lock", "lock_body")
	apply_filters(edge, chrome_read_edge_filters(READOUT_LOCK_COLOR))
	edge.alpha = 230

	if(mode == READOUT_SCATTER)
		// What the outline breaks into: tg's human-shaped static and a glitch strip.
		var/image/noise = add_image('icons/effects/effects.dmi', "static", "lock", "static", 5)
		noise.dir = target.dir
		noise.transform = target.transform
		noise.color = "#a8f3fb"
		noise.alpha = 191
		cues[noise]["jitter"] = 2
		var/image/glitch = add_image('icons/effects/bitrunning.dmi', "glitch", "lock", "static", 5)
		glitch.color = CYBERWARE_COLOR_TIER_3
		cues[glitch]["jitter"] = 3
		return

	// Two echoes of the outline swell out from it while the lock holds.
	for(var/echo_at in list(3, 6))
		var/image/echo = add_body_copy("lock", "echo", echo_at)
		apply_filters(echo, chrome_read_edge_filters(READOUT_LOCK_COLOR))
		var/matrix/start = matrix(target.transform)
		var/matrix/finish = matrix(target.transform)
		finish.Scale(1.25)
		var/matrix/midway = matrix(target.transform)
		midway.Scale(1.12)
		cues[echo]["from"] = start
		cues[echo]["to"] = finish
		// Held mid-swell, so a frame captured without animation shows one.
		echo.transform = midway
		echo.alpha = 110

/// A copy of the subject's current look on the readout's plane.
/datum/chrome_readout/proc/add_body_copy(role, kind, at = 0)
	var/image/copy = chrome_read_body_copy(target, anchor)
	copy.layer = ABOVE_ALL_MOB_LAYER + length(images) * 0.001
	images += copy
	cues[copy] = list("role" = role, "kind" = kind, "at" = at)
	return copy

/// Sets an image's filters from param lists, keeping the lists for anything that inspects the readout.
/datum/chrome_readout/proc/apply_filters(image/drawn, list/specs)
	var/list/built = list()
	for(var/list/spec as anything in specs)
		built += filter(arglist(spec))
	drawn.filters = built
	cues[drawn]["filters"] = specs

/// The panel: frame, leader, header, sockets, names and load bar.
/datum/chrome_readout/proc/build_panel()
	var/static/datum/font/header_font = new /datum/font/grand9k/size_6pt()
	var/static/datum/font/list_font = new /datum/font/tiny_unicode/size_12pt()
	var/open_at = (mode == READOUT_SCATTER) ? 5 : READOUT_LOCK_TIME
	var/top = READOUT_PANEL_TOP

	// What goes in it.
	var/list/entries = list()
	var/socket_count = 0
	if(mode == READOUT_ITEMIZED)
		entries = sort_entries(report["entries"])
		socket_count = min(length(entries), READOUT_MAX_SOCKETS)
	else if(mode == READOUT_SILHOUETTE)
		socket_count = min(report["count"], READOUT_MAX_SOCKETS)
	var/rows = CEILING(socket_count / READOUT_SOCKETS_PER_ROW, 1)

	var/list/lines = list()
	if(mode == READOUT_ITEMIZED)
		var/shown = length(entries)
		if(shown > READOUT_MAX_NAME_LINES)
			shown = READOUT_MAX_NAME_LINES - 1
		for(var/i in 1 to shown)
			var/list/entry = entries[i]
			lines += list(list("label" = entry["label"], "color" = entry["color"], "offline" = entry["offline"]))
		if(shown < length(entries))
			lines += list(list("label" = "and [length(entries) - shown] more", "color" = null, "offline" = FALSE))

	var/list/noise
	var/header_text
	if(mode == READOUT_SCATTER)
		var/visible_name = ishuman(target) ? target.get_visible_name() : target.name
		noise = list()
		for(var/i in 1 to 8)
			noise += chrome_readout_noise(clamp(length_char(visible_name), 6, 16))
		header_text = noise[1]
	else
		header_text = report["name"]

	// Width from the real glyph metrics, never the client's MeasureText().
	var/status_width = 0
	if(mode == READOUT_CLEAN)
		status_width = list_font.get_metrics("no chrome") + 8
	else if(mode == READOUT_SCATTER)
		status_width = header_font.get_metrics("NO LOCK") + 8
	var/width = 5 + header_font.get_metrics(header_text) + 6 + status_width
	if(socket_count)
		width = max(width, min(socket_count, READOUT_SOCKETS_PER_ROW) * 24 + 2, 22 + READOUT_BAR_SEGMENTS * 4 + 5)
	// A name line starts 9 px in and needs 4 px clear of the right border,
	// counting the text outline.
	var/offline_width = list_font.get_metrics(" offline")
	for(var/list/line as anything in lines)
		width = max(width, 9 + list_font.get_metrics(line["label"]) + (line["offline"] ? offline_width : 0) + 4)
	width = clamp(width, READOUT_MIN_WIDTH, READOUT_MAX_WIDTH)
	if(mode != READOUT_SCATTER)
		header_text = chrome_readout_fit(header_text, header_font, width - 11 - status_width)
	for(var/list/line as anything in lines)
		line["label"] = chrome_readout_fit(line["label"], list_font, width - 13 - (line["offline"] ? offline_width : 0))

	var/height = 13
	switch(mode)
		if(READOUT_ITEMIZED)
			height = 21 + 24 * rows + 7 * length(lines)
		if(READOUT_SILHOUETTE)
			height = 20 + 24 * rows

	// Open away from the edge of the reader's screen.
	var/turf/viewer_turf = get_turf(viewer)
	var/turf/target_turf = get_turf(target)
	flipped = viewer_turf && target_turf && (target_turf.x - viewer_turf.x >= 2)
	panel_x = flipped ? (-5 - width) : READOUT_PANEL_X
	panel_width = width
	panel_height = height

	// Frame. The back and sides unfold down from the header.
	var/image/back = add_quad(panel_x, top - height, width, height, READOUT_PANEL_COLOR, 205, "panel", "unfold", open_at)
	cues[back]["from"] = chrome_readout_quad(panel_x, top - 11, width, 11)
	add_quad(panel_x, top - 1, width, 1, READOUT_HUD_COLOR, 120, "panel", "fade", open_at)
	var/image/border_bottom = add_quad(panel_x, top - height, width, 1, READOUT_HUD_COLOR, 120, "panel", "unfold", open_at)
	cues[border_bottom]["from"] = chrome_readout_quad(panel_x, top - 11, width, 1)
	var/image/border_left = add_quad(panel_x, top - height, 1, height, READOUT_HUD_COLOR, 120, "panel", "unfold", open_at)
	cues[border_left]["from"] = chrome_readout_quad(panel_x, top - 11, 1, 11)
	var/image/border_right = add_quad(panel_x + width - 1, top - height, 1, height, READOUT_HUD_COLOR, 120, "panel", "unfold", open_at)
	cues[border_right]["from"] = chrome_readout_quad(panel_x + width - 1, top - 11, 1, 11)
	add_quad(panel_x, top - 11, 2, 11, READOUT_HUD_COLOR, 255, "panel", "fade", open_at)
	var/image/leader = add_image(READOUT_ICON, flipped ? "leader_flip" : "leader", "panel", "fade", open_at)
	leader.pixel_w += flipped ? -5 : 5
	leader.pixel_z += 10

	// Header: whatever name the body shows.
	if(mode == READOUT_SCATTER)
		var/image/garbled = add_text(chrome_readout_header_html(html_encode(header_text), "#9fb7bd"), panel_x + 5, 2, width - 9, FALSE, "panel", "noise", open_at)
		var/list/noise_html = list()
		for(var/noise_text in noise)
			noise_html += chrome_readout_header_html(html_encode(noise_text), "#9fb7bd")
		cues[garbled]["noise"] = noise_html
		add_text(chrome_readout_header_html("NO LOCK", CYBERWARE_COLOR_TIER_3, "right"), panel_x + 5, 2, width - 9, FALSE, "panel", "blink", open_at + 1.5)
		return
	add_text(chrome_readout_header_html(html_encode(header_text), READOUT_NAME_COLOR), panel_x + 5, 2, width - 9, FALSE, "panel", "fade", open_at)
	if(mode == READOUT_CLEAN)
		add_text(chrome_readout_tiny_html("<span style='color:[READOUT_DIM_COLOR]'>no chrome</span>", "right"), panel_x + 5, 2, width - 9, TRUE, "panel", "fade", open_at + 1)
		return

	// Sockets, wrapping six to a row.
	for(var/i in 1 to socket_count)
		var/column = (i - 1) % READOUT_SOCKETS_PER_ROW
		var/row = round((i - 1) / READOUT_SOCKETS_PER_ROW)
		var/image/socket
		var/mutable_appearance/inlay
		if(mode == READOUT_ITEMIZED)
			var/list/entry = entries[i]
			socket = add_image(READOUT_ICON, entry["offline"] ? "chip_blink" : "chip", "socket", "socket", open_at + 1.8 + (i - 1) * 0.5)
			socket.color = entry["offline"] ? READOUT_OFFLINE_COLOR : entry["color"]
			// Smoothly downscaled, so no PIXEL_SCALE on the ware itself.
			inlay = mutable_appearance(entry["icon"], entry["icon_state"], appearance_flags = RESET_COLOR)
			if(entry["offline"])
				inlay.color = list(0.29, 0.29, 0.29, 0.56, 0.56, 0.56, 0.11, 0.11, 0.11)
		else
			socket = add_image(READOUT_ICON, "chip", "socket", "socket", open_at + 1.8 + (i - 1) * 0.5)
			socket.color = READOUT_STATIC_FRAME_COLOR
			inlay = mutable_appearance('icons/effects/effects.dmi', "static_base", alpha = 110, appearance_flags = RESET_COLOR | PIXEL_SCALE)
			inlay.color = "#bfbfbf"
		inlay.transform = matrix(READOUT_SOCKET_ICON_SCALE, 0, 0, 0, READOUT_SOCKET_ICON_SCALE, 0)
		socket.overlays += inlay
		// The chip state's 20 px socket starts six pixels into its canvas.
		socket.pixel_w += panel_x + 3 + column * 24 - 6
		socket.pixel_z += top - 33 - row * 24 - 6
		sockets += socket

	// Names, each with its tier as a small swatch.
	var/names_top = 12 + 24 * rows
	for(var/i in 1 to length(lines))
		var/list/line = lines[i]
		var/cap_row = names_top + 7 * (i - 1)
		var/inner
		if(isnull(line["color"]))
			inner = "<span style='color:[READOUT_DIM_COLOR]'>[html_encode(line["label"])]</span>"
		else if(line["offline"])
			inner = "<span style='color:[READOUT_OFFLINE_NAME_COLOR]'>[html_encode(line["label"])]</span> <span style='color:[READOUT_OFFLINE_COLOR]'>offline</span>"
		else
			inner = "<span style='color:[line["color"]]'>[html_encode(line["label"])]</span>"
		var/image/name_line = add_text(chrome_readout_tiny_html(inner), panel_x + 9, cap_row, width - 10, TRUE, "name", "fade", open_at + 2.6 + (i - 1) * 0.5)
		if(!isnull(line["color"]))
			var/mutable_appearance/swatch = mutable_appearance(READOUT_ICON, "bullet", appearance_flags = RESET_COLOR)
			swatch.color = line["color"]
			swatch.pixel_w = panel_x + 4
			swatch.pixel_z = top - 4 - cap_row
			name_line.overlays += swatch
		name_lines += name_line

	// Load, as a bar. Over the ceiling it pins full in the offline colour.
	var/bar_row = names_top + (length(lines) ? 7 * length(lines) + 2 : 0)
	var/load = report["load"]
	var/capacity = max(report["capacity"], 1)
	var/over = load > capacity
	var/filled = over ? READOUT_BAR_SEGMENTS : clamp(round(load / capacity * READOUT_BAR_SEGMENTS), 0, READOUT_BAR_SEGMENTS)
	var/image/bar = add_image(READOUT_BAR_ICON, "fill_[filled]", "load", "bar", open_at + 3.5)
	bar.color = over ? READOUT_OFFLINE_COLOR : READOUT_HUD_COLOR
	bar.underlays += mutable_appearance(READOUT_BAR_ICON, "track", appearance_flags = RESET_COLOR)
	bar.pixel_w += panel_x + 22
	bar.pixel_z += top - 3 - bar_row
	bar.maptext = chrome_readout_tiny_html("<span style='color:[READOUT_DIM_COLOR]'>load</span>")
	bar.maptext_x = -18
	bar.maptext_y = -5
	bar.maptext_width = 20
	bar.maptext_height = 17
	cues[bar]["fill"] = filled

/// Highest tier first, unrated last; ties keep organ order.
/datum/chrome_readout/proc/sort_entries(list/entries)
	var/list/sorted = list()
	for(var/rank in list(CYBERWARE_TIER_4, CYBERWARE_TIER_3, CYBERWARE_TIER_2, CYBERWARE_TIER_1, 0))
		for(var/list/entry as anything in entries)
			if(entry["tier"] == rank)
				sorted += list(entry)
	return sorted

// ---- Animation ---------------------------------------------------------

/// Hands every image its timeline. Called once, after the client has them.
/datum/chrome_readout/proc/play()
	for(var/image/drawn as anything in images)
		var/list/cue = cues[drawn]
		switch(cue["kind"])
			if("fade")
				play_fade(drawn, cue["at"])
			if("unfold")
				play_unfold(drawn, cue)
			if("socket")
				play_socket(drawn, cue["at"])
			if("bar")
				play_bar(drawn, cue)
			if("bracket")
				play_bracket(drawn, cue)
			if("lock_body")
				play_lock_body(drawn, cue)
			if("echo")
				play_echo(drawn, cue)
			if("static")
				play_static(drawn, cue)
			if("noise")
				play_noise(drawn, cue)
			if("blink")
				play_blink(drawn, cue["at"])

/datum/chrome_readout/proc/play_fade(image/drawn, at, fade_in = 0.8)
	var/hold_alpha = drawn.alpha
	drawn.alpha = 0
	animate(drawn, alpha = 0, time = at)
	animate(alpha = hold_alpha, time = fade_in)
	animate(alpha = hold_alpha, time = max(fade_at - at - fade_in, 0))
	animate(alpha = 0, time = fade_time)

/datum/chrome_readout/proc/play_unfold(image/drawn, list/cue)
	var/at = cue["at"]
	var/hold_alpha = drawn.alpha
	var/matrix/full = drawn.transform
	drawn.alpha = 0
	drawn.transform = cue["from"]
	animate(drawn, alpha = 0, time = at)
	animate(alpha = hold_alpha, time = 0.8)
	animate(transform = full, time = 2.2, easing = CUBIC_EASING | EASE_OUT)
	animate(alpha = hold_alpha, time = max(fade_at - at - 3, 0))
	animate(alpha = 0, time = fade_time)

/// Sockets land white and settle into their tier colour.
/datum/chrome_readout/proc/play_socket(image/drawn, at)
	var/hold_color = drawn.color
	drawn.alpha = 0
	drawn.color = "#ffffff"
	animate(drawn, alpha = 0, time = at)
	animate(alpha = 255, time = 0.6)
	animate(color = hold_color, time = 1)
	animate(alpha = 255, time = max(fade_at - at - 1.6, 0))
	animate(alpha = 0, time = fade_time)

/// The bar fills a segment at a time.
/datum/chrome_readout/proc/play_bar(image/drawn, list/cue)
	var/at = cue["at"]
	var/filled = cue["fill"]
	drawn.alpha = 0
	drawn.icon_state = "fill_0"
	animate(drawn, alpha = 0, time = at)
	animate(alpha = 255, time = 1)
	for(var/step in 1 to filled)
		animate(icon_state = "fill_[step]", time = 4 / filled)
	animate(alpha = 255, time = max(fade_at - at - 1 - (filled ? 4 : 0), 0))
	animate(alpha = 0, time = fade_time)

/// Snap in from wide with an overshoot, flash through the lock, hold, then
/// release outward as everything fades. A scatter never locks: the brackets hunt.
/datum/chrome_readout/proc/play_bracket(image/drawn, list/cue)
	var/final_w = drawn.pixel_w
	var/final_z = drawn.pixel_z
	var/out_w = cue["out_w"]
	var/out_z = cue["out_z"]
	var/hold_color = drawn.color
	drawn.pixel_w = final_w + out_w * 16
	drawn.pixel_z = final_z + out_z * 16
	drawn.alpha = 0
	drawn.color = "#ffffff"
	animate(drawn, pixel_w = final_w, pixel_z = final_z, alpha = 255, time = 3, easing = BACK_EASING | EASE_OUT)
	if(mode == READOUT_SCATTER)
		var/elapsed = 3
		while(elapsed < fade_at)
			var/step = min(1, fade_at - elapsed)
			animate(pixel_w = final_w + rand(-3, 3), pixel_z = final_z + rand(-3, 3), alpha = pick(255, 255, 120), time = step, easing = JUMP_EASING | EASE_IN)
			elapsed += step
	else
		for(var/flash in 1 to 6)
			animate(color = ISODD(flash) ? hold_color : "#ffffff", time = 4 / 6, easing = JUMP_EASING | EASE_IN)
		animate(color = hold_color, time = max(fade_at - 7, 0), easing = JUMP_EASING | EASE_IN)
	animate(pixel_w = final_w + out_w * 10, pixel_z = final_z + out_z * 10, alpha = 0, time = fade_time, easing = CUBIC_EASING | EASE_IN)

/// The red outline: in as the brackets land, held through the lock, out as the
/// panel opens. On a scatter it flickers and slips instead, then gives way to static.
/datum/chrome_readout/proc/play_lock_body(image/drawn, list/cue)
	var/hold_alpha = drawn.alpha
	var/base = drawn.pixel_w
	drawn.alpha = 0
	animate(drawn, alpha = 0, time = 2)
	animate(alpha = hold_alpha, time = 2)
	if(mode == READOUT_SCATTER)
		for(var/flicker in 1 to 8)
			animate(alpha = pick(hold_alpha, hold_alpha, round(hold_alpha * 0.3), 0), pixel_w = base + rand(-2, 2), time = 0.5, easing = JUMP_EASING | EASE_IN)
		animate(alpha = 0, pixel_w = base, time = 2)
	else
		animate(alpha = hold_alpha, time = READOUT_LOCK_TIME - 4)
		animate(alpha = 0, time = 4.5)
	if(cue["roll"])
		// The stripes crawl down the body, a row at a time.
		animate(drawn.filters[cue["roll"]], y = -1, time = 0.8, loop = -1, easing = JUMP_EASING | EASE_IN, flags = ANIMATION_PARALLEL)
		animate(y = -2, time = 0.8, easing = JUMP_EASING | EASE_IN)
		animate(y = 0, time = 0.8, easing = JUMP_EASING | EASE_IN)

/// One outline echo swelling out and fading.
/datum/chrome_readout/proc/play_echo(image/drawn, list/cue)
	drawn.alpha = 0
	drawn.transform = cue["from"]
	animate(drawn, alpha = 0, time = cue["at"])
	animate(alpha = 204, time = 0)
	animate(alpha = 0, transform = cue["to"], time = 5.5, easing = CUBIC_EASING | EASE_OUT)

/// Scatter static: shivers in place until the read drops.
/datum/chrome_readout/proc/play_static(image/drawn, list/cue)
	var/at = cue["at"]
	var/jitter = cue["jitter"]
	var/hold_alpha = drawn.alpha
	var/base = drawn.pixel_w
	drawn.alpha = 0
	animate(drawn, alpha = 0, time = at)
	animate(alpha = hold_alpha, time = 1.5)
	var/elapsed = at + 1.5
	while(elapsed < fade_at)
		var/step = min(0.5, fade_at - elapsed)
		animate(alpha = hold_alpha, pixel_w = base + rand(-jitter, jitter), time = step, easing = JUMP_EASING | EASE_IN)
		elapsed += step
	animate(alpha = 0, time = fade_time)

/// Scatter header: the name never resolves.
/datum/chrome_readout/proc/play_noise(image/drawn, list/cue)
	var/at = cue["at"]
	var/list/noise_html = cue["noise"]
	drawn.alpha = 0
	animate(drawn, alpha = 0, time = at)
	animate(alpha = 255, time = 0.8)
	var/elapsed = at + 0.8
	var/frame = 0
	while(elapsed < fade_at)
		var/step = min(1, fade_at - elapsed)
		animate(maptext = noise_html[(frame % length(noise_html)) + 1], time = step)
		elapsed += step
		frame++
	animate(alpha = 0, time = fade_time)

/// "NO LOCK", three beats on and one off.
/datum/chrome_readout/proc/play_blink(image/drawn, at)
	drawn.alpha = 0
	animate(drawn, alpha = 0, time = at)
	var/elapsed = at
	while(elapsed + 2 <= fade_at)
		animate(alpha = 255, time = 1.5, easing = JUMP_EASING | EASE_IN)
		animate(alpha = 0, time = 0.5, easing = JUMP_EASING | EASE_IN)
		elapsed += 2
	animate(alpha = 255, time = max(fade_at - elapsed, 0), easing = JUMP_EASING | EASE_IN)
	animate(alpha = 0, time = fade_time)

// ---- Helpers -----------------------------------------------------------

/// Transform that draws the 32 px white state as a rectangle with its bottom left at x, y.
/proc/chrome_readout_quad(x, y, width, height)
	return matrix(width / 32, 0, x + width / 2 - 16, 0, height / 32, y + height / 2 - 16)

/// Grand9K header line (the map's default maptext font).
/proc/chrome_readout_header_html(text, text_color, align = "left")
	return MAPTEXT("<div align='[align]' valign='middle' style='white-space:nowrap;color:[text_color]'>[text]</div>")

/// TinyUnicode list line. `inner` is already HTML.
/proc/chrome_readout_tiny_html(inner, align = "left")
	return MAPTEXT_TINY_UNICODE("<div align='[align]' valign='middle' style='white-space:nowrap'>[inner]</div>")

/// Garbage of the given length for a header that won't resolve. Plain text; encode it for maptext.
/proc/chrome_readout_noise(length)
	var/static/list/glyphs = list("#", "%", "&", "@", "$", "/", "\\", "|", "<", ">", "*")
	var/garbage = ""
	for(var/i in 1 to length)
		garbage += pick(glyphs)
	return garbage

/// Trims text to fit max_width pixels in the given font, marking the cut.
/proc/chrome_readout_fit(text, datum/font/font, max_width)
	if(font.get_metrics(text) <= max_width)
		return text
	var/trimmed = text
	while(length_char(trimmed) > 1 && font.get_metrics("[trimmed]..") > max_width)
		trimmed = copytext_char(trimmed, 1, length_char(trimmed))
	return "[trimmed].."

/**
 * Filter chain that turns a copy of a body into just its one-pixel outline in
 * `edge_color`. The body goes black, gains a white outline, and a colour matrix
 * then keys alpha off red: the white ring stays, the black body vanishes, and
 * nothing is added where the image was already clear.
 */
/proc/chrome_read_edge_filters(edge_color)
	var/list/edge_rgb = rgb2num(edge_color)
	return list(
		list("type" = "color", "color" = list(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0)),
		list("type" = "outline", "size" = 1, "color" = "#ffffff", "flags" = OUTLINE_SHARP | OUTLINE_SQUARE),
		list("type" = "color", "color" = list(edge_rgb[1] / 255, edge_rgb[2] / 255, edge_rgb[3] / 255, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
	)

/**
 * A client image wearing `body`'s current look, hung on `attach_to`, flattened
 * out of everything that would tie it to the body's own rendering: no colour,
 * alpha or filters of theirs, and on the readout's plane. Parented to the body
 * itself it takes no pixel offset of its own (it inherits theirs); parked on a
 * turf it keeps theirs so it lines up.
 *
 * Emissive overlays inside the copy keep their own plane and land exactly on
 * the body's own emissives.
 */
/proc/chrome_read_body_copy(mob/living/body, atom/attach_to = body)
	var/image/copy = image(loc = attach_to)
	copy.appearance = body.appearance
	copy.appearance_flags = KEEP_TOGETHER | KEEP_APART | RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | PIXEL_SCALE
	copy.color = null
	copy.alpha = 255
	copy.filters = null
	copy.blend_mode = BLEND_DEFAULT
	copy.render_target = null
	copy.render_source = null
	copy.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	if(attach_to == body)
		copy.pixel_x = 0
		copy.pixel_y = 0
		copy.pixel_w = 0
		copy.pixel_z = 0
	copy.layer = ABOVE_ALL_MOB_LAYER
	SET_PLANE_EXPLICIT(copy, ABOVE_LIGHTING_PLANE, attach_to)
	return copy

// ---- The subject and the bystanders ------------------------------------

/**
 * The subject's own warning: their body flinches red twice, on their screen
 * only. The chat line naming the reader is sent by the action.
 */
/proc/chrome_read_flinch(mob/living/subject)
	var/client/subject_client = subject?.client
	if(!subject_client)
		return
	var/image/flinch = chrome_read_flinch_image(subject)
	subject_client.images += flinch
	animate(flinch, alpha = 0, time = 1)
	animate(alpha = 255, time = 0)
	animate(alpha = 255, time = 1)
	animate(alpha = 0, time = 0.6)
	animate(alpha = 0, time = 0.4)
	animate(alpha = 200, time = 0)
	animate(alpha = 200, time = 0.8)
	animate(alpha = 0, time = 1.5)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(remove_image_from_client), flinch, subject_client), 1 SECONDS, TIMER_CLIENT_TIME)

/// The flinch image: the body in tier-three pink, a faint fill under a hard outline.
/proc/chrome_read_flinch_image(mob/living/subject)
	var/image/flinch = chrome_read_body_copy(subject)
	var/list/flinch_rgb = rgb2num(CYBERWARE_COLOR_TIER_3)
	var/list/specs = chrome_read_edge_filters(CYBERWARE_COLOR_TIER_3)
	// Same outline, but the body keeps a faint fill: alpha is 0.27 inside and
	// 0.95 on the ring.
	specs[3] = list("type" = "color", "color" = list(0, 0, 0, 0.68, 0, 0, 0, 0, 0, 0, 0, 0, flinch_rgb[1] / 255, flinch_rgb[2] / 255, flinch_rgb[3] / 255, 0.27, 0, 0, 0, 0))
	var/list/built = list()
	for(var/list/spec as anything in specs)
		built += filter(arglist(spec))
	flinch.filters = built
	return flinch

/**
 * The tell anyone looking at the reader can see: their eyes flicker. It rides
 * the reader through vis_contents, so it shows to whoever sees them.
 */
/proc/chrome_read_eye_glint(mob/living/carbon/reader)
	var/mutable_appearance/glint = chrome_read_glint_appearance(reader)
	if(!glint)
		return
	var/atom/movable/visual = reader.flick_overlay_view(glint, 0.5 SECONDS)
	if(!visual)
		return
	visual.vis_flags |= VIS_INHERIT_DIR
	animate(visual, alpha = 255, time = 1)
	animate(alpha = 0, time = 0.5, easing = JUMP_EASING | EASE_IN)
	animate(alpha = 255, time = 1, easing = JUMP_EASING | EASE_IN)
	animate(alpha = 0, time = 0.5, easing = JUMP_EASING | EASE_IN)
	animate(alpha = 255, time = 1, easing = JUMP_EASING | EASE_IN)
	animate(alpha = 0, time = 1)

/// The reader's eyes, lit. Null when there are no eyes to light or something covers them.
/proc/chrome_read_glint_appearance(mob/living/carbon/reader)
	if(!ishuman(reader))
		return null
	var/mob/living/carbon/human/human_reader = reader
	var/obj/item/organ/eyes/eyes = human_reader.get_organ_slot(ORGAN_SLOT_EYES)
	if(isnull(eyes?.eye_icon_state))
		return null
	if(human_reader.check_obscured_slots() & ITEM_SLOT_EYES)
		return null
	var/eye_state = eyes.eye_icon_state
	var/mutable_appearance/glint = mutable_appearance('icons/mob/human/human_face.dmi', "[eye_state]_l")
	glint.overlays += mutable_appearance('icons/mob/human/human_face.dmi', "[eye_state]_r")
	glint.overlays += emissive_appearance('icons/mob/human/human_face.dmi', "[eye_state]_l", reader)
	glint.overlays += emissive_appearance('icons/mob/human/human_face.dmi', "[eye_state]_r", reader)
	glint.color = READOUT_GLINT_COLOR
	glint.dir = reader.dir
	var/obj/item/bodypart/head/head = human_reader.get_bodypart(BODY_ZONE_HEAD)
	head?.worn_face_offset?.apply_offset(glint)
	return glint

#undef READOUT_ITEMIZED
#undef READOUT_SILHOUETTE
#undef READOUT_SCATTER
#undef READOUT_CLEAN
#undef READOUT_LOCK_TIME
#undef READOUT_OPEN_TIME
#undef READOUT_HOLD_TIME
#undef READOUT_CLEAN_HOLD_TIME
#undef READOUT_FADE_TIME
#undef READOUT_SCATTER_DROP_AT
#undef READOUT_SCATTER_FADE_TIME
#undef READOUT_PANEL_X
#undef READOUT_PANEL_TOP
#undef READOUT_SOCKETS_PER_ROW
#undef READOUT_MAX_SOCKETS
#undef READOUT_MAX_NAME_LINES
#undef READOUT_MIN_WIDTH
#undef READOUT_MAX_WIDTH
#undef READOUT_BAR_SEGMENTS
#undef READOUT_SOCKET_ICON_SCALE
#undef READOUT_HUD_COLOR
#undef READOUT_LOCK_COLOR
#undef READOUT_LOCK_FILL_COLOR
#undef READOUT_PANEL_COLOR
#undef READOUT_NAME_COLOR
#undef READOUT_DIM_COLOR
#undef READOUT_OFFLINE_COLOR
#undef READOUT_OFFLINE_NAME_COLOR
#undef READOUT_STATIC_FRAME_COLOR
#undef READOUT_GLINT_COLOR
#undef READOUT_ICON
#undef READOUT_BAR_ICON
