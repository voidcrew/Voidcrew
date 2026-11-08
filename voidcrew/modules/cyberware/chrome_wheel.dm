/**
 * # Chrome wheel
 *
 * One wheel holding every ability the bearer's chrome carries, so nobody has
 * to hunt a row of action buttons mid-fight. Three keybinds drive it
 * (chrome_wheel_keybindings.dm):
 *
 * - Chrome wheel: hold it and the wheel opens at the centre of the view. Point
 *   at a chip and let go, or click one, to pick it. A quick tap leaves the
 *   wheel open for a click instead; pressing the key again shuts it.
 * - Use chrome: fires the picked ability on key down.
 * - Use OS chrome: fires the OS-slot ware's ability on key down, whatever is
 *   picked.
 *
 * A chip IS the bearer's existing /datum/action, the same one their button
 * holds, fired through the same Trigger() a button click uses. Cooldowns,
 * ORGAN_FAILING, check_flags and click-to-target modes are therefore shared
 * with the buttons, and nothing here grants, copies or replaces an ability.
 * Abilities are collected generically from every installed organ carrying
 * /datum/component/cyberware, so new ware shows up without touching this file.
 *
 * Looks: an outline of the bearer's body inside a ring cut into one arc per
 * body region. Each ware sits in a socket (chrome_wheel_socket()), a run of
 * fixed positions on its region's arc, with a leader line from the socket to
 * the part of the body it lives in. A socket's chrome changing never moves
 * another socket's chips, and an empty socket keeps a dim outline. Pointing at
 * a chip grows it and lights its arc, its leader and its body part in its
 * tier's colour, and a fixed readout under the ring names it. The pick wears
 * the chrome read's corner brackets, and its own button carries the MOD-style
 * "selected" frame on the HUD.
 *
 * Pointing is by bearing from the ring's centre, so a flick outward picks the
 * chip in that direction without landing on it. Inside the body nothing is
 * pointed at.
 *
 * Sub-options: an ability can offer choices through
 * /datum/action/proc/chrome_wheel_options(), empty by default. The wheel does
 * not show them; a pick made with select(ability, option_id) makes Use chrome
 * call the ability's use_chrome_wheel_option() with that id instead of Trigger().
 *
 * Mouse handling: BYOND only reports the mouse over things it can hit, so the
 * open wheel lays a full-view cursor catcher (tg's, as the scope uses) under
 * its mouse-transparent pieces. Every move and click lands on the catcher, and
 * the chip is worked out from where the mouse is relative to the centre.
 */

// Readout panel under the ring, in pixels from the bottom left of the centre
// tile (y up). The panel's top edge, left edge and size.
#define CHROME_WHEEL_READOUT_TOP -108
#define CHROME_WHEEL_READOUT_LEFT -66
#define CHROME_WHEEL_READOUT_WIDTH 164
#define CHROME_WHEEL_READOUT_HEIGHT 25

/// Organ slots that sort first inside their socket, in this order. Any other
/// slot follows them, alphabetically by slot name.
GLOBAL_LIST_INIT(chrome_wheel_slot_order, list(
	ORGAN_SLOT_EYES,
	ORGAN_SLOT_CYBERWARE_EARS,
	ORGAN_SLOT_CYBERWARE_RIGGER,
	ORGAN_SLOT_CYBERWARE_REGISTRY,
	ORGAN_SLOT_CYBERWARE_OS,
	ORGAN_SLOT_CYBERWARE_SKIN,
	ORGAN_SLOT_CYBERWARE_FILTER,
	ORGAN_SLOT_CYBERWARE_STASH,
	ORGAN_SLOT_CYBERWARE_LEGS,
))

/**
 * Where each socket's chips sit on the ring. "start" is the bearing of its
 * first chip in degrees clockwise from twelve o'clock, "turn" the way the rest
 * follow (1 clockwise, -1 counter-clockwise), "fits" how many its arc holds
 * before another row starts further out. "arc" is the ring arc it lights and
 * "region" the body part. The art in chrome_wheel_ring.dmi is drawn to match.
 */
GLOBAL_LIST_INIT(chrome_wheel_sockets, list(
	CHROME_WHEEL_SOCKET_EYES = list("start" = -9, "turn" = -1, "fits" = 2, "arc" = "head", "region" = "head"),
	CHROME_WHEEL_SOCKET_HEAD = list("start" = 9, "turn" = 1, "fits" = 2, "arc" = "head", "region" = "head"),
	CHROME_WHEEL_SOCKET_OS = list("start" = 47, "turn" = 1, "fits" = 2, "arc" = "os", "region" = "spine"),
	CHROME_WHEEL_SOCKET_RIGHT_ARM = list("start" = 83, "turn" = 1, "fits" = 4, "arc" = "r_arm", "region" = "r_arm"),
	CHROME_WHEEL_SOCKET_LEGS = list("start" = 180, "turn" = 1, "fits" = 3, "arc" = "legs", "region" = "legs"),
	CHROME_WHEEL_SOCKET_LEFT_ARM = list("start" = -83, "turn" = -1, "fits" = 4, "arc" = "l_arm", "region" = "l_arm"),
	CHROME_WHEEL_SOCKET_SKIN = list("start" = -47, "turn" = -1, "fits" = 2, "arc" = "skin", "region" = "torso"),
))

/// Positions a socket holds for one organ slot, filled or not, so the rest of
/// that socket never moves when the slot is filled or emptied. Socket =>
/// list(slot, positions held). The OS owns the first chip of its arc. Chrome
/// optics own the first three of theirs (their own ability, the chrome read and
/// the zoom, cyberware_zoom.dm); the third starts the eyes' second row.
GLOBAL_LIST_INIT(chrome_wheel_reserved, list(
	CHROME_WHEEL_SOCKET_OS = list(ORGAN_SLOT_CYBERWARE_OS, 1),
	CHROME_WHEEL_SOCKET_EYES = list(ORGAN_SLOT_EYES, 3),
))

// ---- Collection --------------------------------------------------------

/**
 * Every ability the bearer's installed chrome gives them a button for. Offline
 * ware stays in (it shows dark, and firing it gives the button's own
 * feedback); ware that is not in the body has no owner on its actions and
 * drops out on its own.
 */
/proc/get_chrome_wheel_actions(mob/living/carbon/bearer)
	RETURN_TYPE(/list)
	. = list()
	for(var/obj/item/organ/ware as anything in get_installed_cyberware(bearer))
		for(var/datum/action/ability in ware.actions)
			if(QDELETED(ability) || ability.owner != bearer || !ability.owner_has_control)
				continue
			. += ability

/// The ability of whatever OS-slot chrome the bearer runs, or null.
/proc/get_os_chrome_action(mob/living/carbon/bearer)
	for(var/obj/item/organ/ware as anything in get_installed_cyberware(bearer))
		if(ware.slot != ORGAN_SLOT_CYBERWARE_OS)
			continue
		for(var/datum/action/ability in ware.actions)
			if(!QDELETED(ability) && ability.owner == bearer && ability.owner_has_control)
				return ability
	return null

/// The bearer's chrome wheel, made on first use. Null for a body with no chrome
/// abilities and no wheel yet, so a plain body never grows the component.
/proc/get_chrome_wheel(mob/living/carbon/bearer)
	if(!iscarbon(bearer))
		return null
	var/datum/component/chrome_wheel/wheel = bearer.GetComponent(/datum/component/chrome_wheel)
	if(wheel || !length(get_chrome_wheel_actions(bearer)))
		return wheel
	return bearer.AddComponent(/datum/component/chrome_wheel)

// ---- Sub-option hooks --------------------------------------------------

/**
 * One choice an ability offers. [id] must stay the same between calls for the
 * same choice: the wheel remembers a pick by id and asks the ability for its
 * options again before firing it.
 */
/datum/chrome_wheel_option
	/// Stable key for this choice within its ability. Non-empty text: a false
	/// id reads as "no option" and would fire the ability itself.
	var/id
	/// What the readout calls the pick.
	var/name
	var/icon
	var/icon_state

/datum/chrome_wheel_option/New(id, name, icon, icon_state)
	src.id = id
	src.name = name
	src.icon = icon
	src.icon_state = icon_state

/**
 * Choices this ability offers on top of firing it plainly: a list of
 * /datum/chrome_wheel_option, or null for none (the default, and every ability
 * today).
 */
/datum/action/proc/chrome_wheel_options(mob/living/carbon/bearer)
	RETURN_TYPE(/list)
	return null

/**
 * Fires one of this ability's chrome wheel sub-options. The default fires the
 * ability itself; an override stashes the choice first, then calls Trigger()
 * so the button's availability checks and targeting still apply.
 */
/datum/action/proc/use_chrome_wheel_option(mob/living/carbon/bearer, option_id)
	return Trigger(bearer)

/// The option with this id that the ability offers right now, or null.
/proc/chrome_wheel_find_option(datum/action/ability, mob/living/carbon/bearer, option_id)
	for(var/datum/chrome_wheel_option/option in ability?.chrome_wheel_options(bearer))
		if(option.id == option_id)
			return option
	return null

// ---- Names -------------------------------------------------------------

/**
 * What the wheel calls this ability: its own name, or for a ware's plain
 * deploy or use button, the ware without its housing ("Mantis Blade", not
 * "Toggle Mantis Blade housing (left)"). Override for a better one.
 */
/datum/action/proc/chrome_wheel_name()
	var/obj/item/organ/ware = target
	if(istype(ware) && (istype(src, /datum/action/item_action/organ_action/toggle) || istype(src, /datum/action/item_action/organ_action/use)))
		var/static/regex/hardware = regex(@"(\s+(spool\s+)?housing|\s+drill fist)?(\s*\((left|right)\))?$", "i")
		return hardware.Replace(format_text(ware.name), "")
	return format_text(name)

/// The name of the chrome an ability lives in, or "" for one that lives in nothing.
/proc/chrome_wheel_ware_name(datum/action/ability)
	var/obj/item/organ/ware = ability?.target
	return istype(ware) ? format_text(ware.name) : ""

/// Display names, ability => text.
/proc/chrome_wheel_names(list/abilities)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/action/ability as anything in abilities)
		.[ability] = ability.chrome_wheel_name()

// ---- Layout ------------------------------------------------------------

/// Which socket an organ's abilities sit in, from its slot and the zone it lives in.
/proc/chrome_wheel_socket(obj/item/organ/ware)
	if(!istype(ware))
		return CHROME_WHEEL_SOCKET_OS
	if(ware.slot == ORGAN_SLOT_EYES || ware.zone == BODY_ZONE_PRECISE_EYES)
		return CHROME_WHEEL_SOCKET_EYES
	if(ware.slot == ORGAN_SLOT_CYBERWARE_OS)
		return CHROME_WHEEL_SOCKET_OS
	if(ware.slot == ORGAN_SLOT_CYBERWARE_SKIN)
		return CHROME_WHEEL_SOCKET_SKIN
	switch(ware.zone)
		if(BODY_ZONE_HEAD, BODY_ZONE_PRECISE_MOUTH)
			return CHROME_WHEEL_SOCKET_HEAD
		if(BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_R_HAND)
			return CHROME_WHEEL_SOCKET_RIGHT_ARM
		if(BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND)
			return CHROME_WHEEL_SOCKET_LEFT_ARM
		if(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG, BODY_ZONE_PRECISE_R_FOOT, BODY_ZONE_PRECISE_L_FOOT)
			return CHROME_WHEEL_SOCKET_LEGS
	// The chest and anything else: the OS's arc, after the OS.
	return CHROME_WHEEL_SOCKET_OS

/// Hand chrome rides its arm's socket, after the arm's own chrome, with its
/// own leader to the hand.
/proc/chrome_wheel_is_hand(obj/item/organ/ware)
	if(!istype(ware))
		return FALSE
	return ware.slot == ORGAN_SLOT_CYBERWARE_HANDS || ware.zone == BODY_ZONE_PRECISE_L_HAND || ware.zone == BODY_ZONE_PRECISE_R_HAND

/// Where an organ slot ranks inside its socket. Unlisted slots rank last.
/proc/chrome_wheel_slot_rank(obj/item/organ/ware)
	var/rank = istype(ware) ? GLOB.chrome_wheel_slot_order.Find(ware.slot) : 0
	return rank || length(GLOB.chrome_wheel_slot_order) + 1

/// Order inside a socket: hand chrome last, then ranked organ slots, other
/// slots by name, and each organ's own button order.
/proc/cmp_chrome_wheel_abilities(datum/action/first, datum/action/second)
	var/obj/item/organ/first_ware = first.target
	var/obj/item/organ/second_ware = second.target
	var/hand_gap = chrome_wheel_is_hand(first_ware) - chrome_wheel_is_hand(second_ware)
	if(hand_gap)
		return hand_gap
	var/rank_gap = chrome_wheel_slot_rank(first_ware) - chrome_wheel_slot_rank(second_ware)
	if(rank_gap)
		return rank_gap
	if(first_ware != second_ware)
		var/first_slot = istype(first_ware) ? first_ware.slot : ""
		var/second_slot = istype(second_ware) ? second_ware.slot : ""
		return sorttext(second_slot, first_slot) || sorttext(second.name, first.name)
	return LAZYFIND(first_ware.actions, first) - LAZYFIND(second_ware.actions, second)

/// How many chips the socket's arc holds before another row starts.
/proc/chrome_wheel_socket_fits(socket)
	var/list/spec = GLOB.chrome_wheel_sockets[socket]
	return spec ? spec["fits"] : 1

/**
 * Pixel offset from the centre of the view of position [index] in [socket],
 * as list(x, y). Positions run along the socket's arc CHROME_WHEEL_STEP
 * degrees apart; once the arc is full they start again a row further out.
 */
/proc/chrome_wheel_position(socket, index)
	RETURN_TYPE(/list)
	var/list/spec = GLOB.chrome_wheel_sockets[socket]
	var/fits = spec["fits"]
	var/row = round((index - 1) / fits)
	var/angle = spec["start"] + spec["turn"] * ((index - 1) % fits) * CHROME_WHEEL_STEP
	var/radius = CHROME_WHEEL_RADIUS + row * CHROME_WHEEL_ROW_GAP
	return list(round(sin(angle) * radius, 1), round(cos(angle) * radius + CHROME_WHEEL_CENTRE_Y, 1))

/**
 * Sorts the abilities into sockets: ability => list("socket", "index",
 * "hand"). Where an ability lands depends only on its own socket's chrome,
 * never on what the rest of the body carries.
 */
/proc/chrome_wheel_placements(list/abilities)
	RETURN_TYPE(/list)
	var/list/by_socket = list()
	for(var/datum/action/ability as anything in abilities)
		var/socket = chrome_wheel_socket(ability.target)
		if(!by_socket[socket])
			by_socket[socket] = list()
		var/list/members = by_socket[socket]
		members += ability
	var/list/placements = list()
	for(var/socket in by_socket)
		var/list/members = sortTim(by_socket[socket], GLOBAL_PROC_REF(cmp_chrome_wheel_abilities))
		var/list/reserved = GLOB.chrome_wheel_reserved[socket]
		var/reserved_slot = length(reserved) ? reserved[1] : null
		var/reserved_count = length(reserved) ? reserved[2] : 0
		var/next_reserved = 1
		var/next_free = reserved_count + 1
		for(var/datum/action/ability as anything in members)
			var/obj/item/organ/ware = ability.target
			var/index
			if(reserved_slot && istype(ware) && ware.slot == reserved_slot && next_reserved <= reserved_count)
				index = next_reserved++
			else
				index = next_free++
			placements[ability] = list("socket" = socket, "index" = index, "hand" = chrome_wheel_is_hand(ware))
	return placements

/// Where each ability's chip sits: ability => list(x, y), from the centre of the view.
/proc/chrome_wheel_layout(list/abilities)
	RETURN_TYPE(/list)
	var/list/placements = chrome_wheel_placements(abilities)
	. = list()
	for(var/datum/action/ability as anything in placements)
		var/list/placement = placements[ability]
		.[ability] = chrome_wheel_position(placement["socket"], placement["index"])

// ---- Pointing ----------------------------------------------------------

/// Bearing of an offset from the centre of the view, as seen from the ring's
/// centre: degrees clockwise from twelve o'clock.
/proc/chrome_wheel_bearing(x, y)
	return delta_to_angle(x, y - CHROME_WHEEL_CENTRE_Y)

/**
 * Which of [points] (a list of list(x, y) chip centres) the mouse at offset
 * (dx, dy) means, as an index, or 0 for none. Inside the body nothing is
 * pointed at. A chip right under the mouse is the one meant; anywhere else,
 * the mouse points at the chip whose bearing from the ring's centre is
 * nearest its own, so a quick flick outward works without landing on it.
 * [on_ring], if given, says which points a bearing can pick (the first row);
 * the rest only answer the mouse right on them.
 */
/proc/chrome_wheel_pick(dx, dy, list/points, list/on_ring)
	var/ring_y = dy - CHROME_WHEEL_CENTRE_Y
	if(sqrt(dx ** 2 + ring_y ** 2) < CHROME_WHEEL_DEADZONE)
		return 0
	var/nearest = 0
	var/nearest_gap = INFINITY
	for(var/i in 1 to length(points))
		var/list/point = points[i]
		var/gap = sqrt((point[1] - dx) ** 2 + (point[2] - dy) ** 2)
		if(gap < nearest_gap)
			nearest = i
			nearest_gap = gap
	if(nearest_gap <= CHROME_WHEEL_PICK_RANGE)
		return nearest
	var/mouse_bearing = delta_to_angle(dx, ring_y)
	var/pointed = 0
	var/pointed_turn = INFINITY
	for(var/i in 1 to length(points))
		if(on_ring && !on_ring[i])
			continue
		var/list/point = points[i]
		var/turn = abs(WRAP(mouse_bearing - chrome_wheel_bearing(point[1], point[2]) + 180, 0, 360) - 180)
		if(turn < pointed_turn)
			pointed = i
			pointed_turn = turn
	return pointed_turn <= CHROME_WHEEL_POINT_TOLERANCE ? pointed : 0

/// The mouse position in a screen mouse params string, as pixels from the
/// centre of the viewer's map: list(x, y), or null if the params have none.
/proc/chrome_wheel_mouse_offset(params, client/viewer)
	if(!viewer)
		return null
	var/list/modifiers = params2list(params)
	var/screen_loc = LAZYACCESS(modifiers, SCREEN_LOC)
	if(!screen_loc)
		return null
	var/list/pixels = screen_loc_to_offset(screen_loc, viewer.view)
	var/list/view_pixels = view_to_pixels(viewer.view)
	// screen_loc_to_offset counts tiles from 1, so the first tile starts a tile in.
	return list(pixels[1] - ICON_SIZE_X - view_pixels[1] / 2, pixels[2] - ICON_SIZE_Y - view_pixels[2] / 2)

/// The key a bind sits on, without its modifiers: "ShiftV" is held while "V"
/// is. Bare modifier binds ("Alt") stay as they are.
/proc/chrome_wheel_raw_key(full_key)
	var/raw = full_key
	var/last_modifier
	for(var/modifier in list("Alt", "Ctrl", "Shift"))
		if(findtextEx(raw, modifier) == 1)
			raw = copytext(raw, length(modifier) + 1)
			last_modifier = modifier
	return raw || last_modifier

// ---- Looks -------------------------------------------------------------

/// The radial.dmi "module_selected" frame the picked ability's buttons wear, shared.
/proc/chrome_wheel_marker(frame_state)
	var/static/list/markers = list()
	if(!markers[frame_state])
		markers[frame_state] = mutable_appearance('icons/hud/radial.dmi', frame_state, FLOAT_LAYER - 0.1)
	return markers[frame_state]

/**
 * What an ability's chip shows: a copy of the bearer's own button for it,
 * minus the button background and text, so the chip carries the same icon
 * and item overlay the button does. Built from the action's vars when the
 * bearer has no button for it.
 */
/proc/chrome_wheel_ability_look(datum/action/ability, mob/viewer)
	RETURN_TYPE(/mutable_appearance)
	var/atom/movable/screen/movable/action_button/button = viewer?.hud_used ? ability.viewers[viewer.hud_used] : null
	var/mutable_appearance/look
	if(button)
		look = new(button)
		look.underlays = list()
		look.overlays -= chrome_wheel_marker("module_selected")
	else if(ability.button_icon && ability.button_icon_state)
		look = mutable_appearance(ability.button_icon, ability.button_icon_state)
	else if(isatom(ability.target))
		var/atom/thing = ability.target
		look = new(thing.appearance)
	else
		look = mutable_appearance('icons/hud/actions.dmi', "default")
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
	// Keeps its own colour, follows the chip's pop, and shrinks smoothly.
	look.appearance_flags = RESET_COLOR | NO_CLIENT_COLOR
	return look

/// Whether an ability is "on" right now: a toggled arm with its hardware out,
/// or a click-to-target ability armed and waiting for the click.
/proc/chrome_wheel_ability_active(datum/action/ability, mob/living/carbon/bearer)
	// The zoom is a toggle, not a click-to-target: it is on while the optics are zoomed.
	if(istype(ability, /datum/action/cooldown/cyberware/optics_zoom))
		var/datum/action/cooldown/cyberware/optics_zoom/zoom = ability
		var/obj/item/organ/eyes/robotic/cyberware/optics = zoom.organ
		return istype(optics) && optics.is_zoomed()
	if(istype(ability, /datum/action/cooldown))
		return bearer.click_intercept == ability
	var/obj/item/organ/cyberimp/arm/toolkit/arm = ability.target
	if(istype(arm) && istype(ability, /datum/action/item_action/organ_action/toggle))
		return arm.active_item && !(arm.active_item in arm)
	return FALSE

/// Deciseconds left on an ability's cooldown, 0 for one that has none.
/proc/chrome_wheel_cooldown_left(datum/action/ability)
	var/datum/action/cooldown/timed = ability
	return istype(timed) ? max(timed.next_use_time - world.time, 0) : 0

/// Whether the chrome an ability lives in is down: rebooting from an EMP, or
/// browned out over capacity.
/proc/chrome_wheel_offline(datum/action/ability)
	var/obj/item/organ/ware = ability.target
	var/datum/component/cyberware/chrome = istype(ware) ? ware.GetComponent(/datum/component/cyberware) : null
	return chrome && !chrome.is_running()

/// Whether an ability can't be used right now for any other reason than its
/// chrome being down or its cooldown: its button's own checks say no.
/proc/chrome_wheel_unavailable(datum/action/ability, cooldown_left)
	// On cooldown IsAvailable() is FALSE anyway; the shade shows that instead.
	return !cooldown_left && !ability.IsAvailable()

/// The tier colour of the chrome an ability lives in.
/proc/chrome_wheel_tier_color(datum/action/ability)
	var/obj/item/organ/ware = ability.target
	var/datum/component/cyberware/chrome = istype(ware) ? ware.GetComponent(/datum/component/cyberware) : null
	return chrome ? cyberware_tier_color(chrome.tier) : CHROME_WHEEL_HUD_COLOR

/// [color] taken [amount] of the way to white.
/proc/chrome_wheel_lighten(color, amount)
	var/list/channels = rgb2num(color)
	return rgb(round(channels[1] + (255 - channels[1]) * amount), round(channels[2] + (255 - channels[2]) * amount), round(channels[3] + (255 - channels[3]) * amount))

/// One of the chip art states as an overlay that keeps its own colour.
/proc/chrome_wheel_chip_piece(piece_state, piece_color, piece_alpha = 255)
	var/mutable_appearance/piece = mutable_appearance(CHROME_WHEEL_ICON, piece_state, FLOAT_LAYER, appearance_flags = RESET_COLOR | NO_CLIENT_COLOR | PIXEL_SCALE)
	piece.color = piece_color
	piece.alpha = piece_alpha
	return piece

/// Sorts chips clockwise from twelve o'clock, the order they pop in.
/proc/cmp_chrome_wheel_bearing(atom/movable/screen/chrome_wheel/chip/first, atom/movable/screen/chrome_wheel/chip/second)
	return chrome_wheel_bearing(first.chip_x, first.chip_y) - chrome_wheel_bearing(second.chip_x, second.chip_y)

// ---- The wheel ---------------------------------------------------------

/datum/component/chrome_wheel
	/// The ability Use chrome fires.
	var/datum/weakref/selected_ref
	/// The id of the sub-option of that ability Use chrome fires instead, if one was picked.
	var/selected_option
	/// The ability whose buttons carry the selection frame.
	var/datum/weakref/marked_ref
	/// CHROME_WHEEL_CLOSED, CHROME_WHEEL_HELD or CHROME_WHEEL_CLICK.
	var/wheel_mode = CHROME_WHEEL_CLOSED
	/// REALTIMEOFDAY when the wheel key went down.
	var/press_time = 0
	/// The client the wheel is drawn on, so it comes off that screen even after
	/// the client has moved to another mob.
	var/client/shown_to
	/// Screen-centre object every visible part of the wheel hangs off.
	var/atom/movable/screen/chrome_wheel/hub/hub
	/// Full-view mouse tracker under the wheel.
	var/atom/movable/screen/fullscreen/cursor_catcher/chrome_wheel/catcher
	/// Every screen object the open wheel made, for teardown.
	var/list/parts
	/// One chip per ability.
	var/list/chips
	/// Leader key => list("leader", "node", "node_state", "alpha"): the line
	/// from a socket (or a hand chip) to the body, and its dot on the body.
	var/list/leaders
	/// Arc name => its piece of ring art.
	var/list/arcs
	/// The body part lit under the chip pointed at.
	var/atom/movable/screen/chrome_wheel/art/glow
	/// The chip the mouse is on.
	var/atom/movable/screen/chrome_wheel/chip/highlighted
	/// Readout lines, and the pick mark it shows when nothing is pointed at.
	var/atom/movable/screen/chrome_wheel/readout/readout_title
	var/atom/movable/screen/chrome_wheel/readout/readout_sub
	var/atom/movable/screen/chrome_wheel/readout/readout_status
	var/atom/movable/screen/chrome_wheel/readout/readout_mark
	/// What the readout last showed.
	var/readout_state
	/// First mouse position reported after opening. Nothing is pointed at until
	/// the mouse leaves it, so a cursor that was resting somewhere when the
	/// key went down picks nothing by accident.
	var/list/mouse_start
	/// Whether the mouse has left [mouse_start].
	var/mouse_moved = FALSE
	/// A closed wheel still fading out: its client, its pieces and the timer
	/// that takes them away.
	var/client/fading_client
	var/list/fading_parts
	var/fading_timer

/datum/component/chrome_wheel/Initialize()
	if(!iscarbon(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/chrome_wheel/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))
	RegisterSignal(parent, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))

/datum/component/chrome_wheel/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOB_LOGOUT, COMSIG_MOB_STATCHANGE))

/datum/component/chrome_wheel/Destroy(force)
	close_wheel()
	clear_fading()
	unmark()
	selected_ref = null
	return ..()

/datum/component/chrome_wheel/proc/on_logout(datum/source)
	SIGNAL_HANDLER
	close_wheel()
	clear_fading()

/datum/component/chrome_wheel/proc/on_stat_change(datum/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat >= UNCONSCIOUS)
		close_wheel()

/// Whether the wheel is on screen.
/datum/component/chrome_wheel/proc/is_open()
	return wheel_mode != CHROME_WHEEL_CLOSED

// ---- Keys --------------------------------------------------------------

/// Wheel key down: open the wheel, or shut one a tap left open.
/datum/component/chrome_wheel/proc/wheel_key_down()
	switch(wheel_mode)
		if(CHROME_WHEEL_CLICK)
			close_wheel()
			return
		if(CHROME_WHEEL_HELD)
			return
	if(open_wheel(CHROME_WHEEL_HELD))
		press_time = REALTIMEOFDAY

/// Wheel key up: after a tap the wheel stays open for a click; after a hold,
/// whatever the mouse is on is picked and the wheel closes.
/datum/component/chrome_wheel/proc/wheel_key_up()
	if(wheel_mode != CHROME_WHEEL_HELD)
		return
	if(REALTIMEOFDAY - press_time < CHROME_WHEEL_HOLD_TIME)
		wheel_mode = CHROME_WHEEL_CLICK
		return
	choose(highlighted)

/**
 * Whether a key the "Chrome wheel" bind sits on is still down. keyUp only
 * reaches binds by their bare key (bindings_client.dm), so a bind on a
 * modifier combo such as ShiftV never hears its own release; while the wheel
 * is held open, this poll catches it instead.
 */
/datum/component/chrome_wheel/proc/wheel_key_held()
	var/mob/living/carbon/bearer = parent
	var/client/viewer = bearer.client
	if(!viewer)
		return FALSE
	var/list/bindings = viewer.prefs?.key_bindings
	for(var/full_key in LAZYACCESS(bindings, CHROME_WHEEL_KEYBIND))
		if(viewer.keys_held[chrome_wheel_raw_key(full_key)])
			return TRUE
	return FALSE

/// Use chrome: fire the picked ability. With nothing picked, a lone ability
/// is fired; with several, the wheel opens for a click.
/datum/component/chrome_wheel/proc/use_selected()
	if(wheel_mode != CHROME_WHEEL_CLOSED)
		if(highlighted)
			select_chip(highlighted, quiet = TRUE)
		close_wheel()
	var/datum/action/ability = get_selected_ability()
	if(ability)
		return fire(ability, selected_option)
	var/mob/living/carbon/bearer = parent
	var/list/abilities = get_chrome_wheel_actions(bearer)
	switch(length(abilities))
		if(0)
			bearer.balloon_alert(bearer, "no chrome!")
		if(1)
			select(abilities[1])
			return fire(abilities[1])
		else
			open_wheel(CHROME_WHEEL_CLICK)
	return FALSE

/// Use OS chrome: fire the OS-slot ware's ability, leaving the pick alone.
/datum/component/chrome_wheel/proc/use_os()
	var/mob/living/carbon/bearer = parent
	var/datum/action/ability = get_os_chrome_action(bearer)
	if(!ability)
		bearer.balloon_alert(bearer, "no OS chrome!")
		return FALSE
	return fire(ability)

/**
 * Fires an ability exactly as its button would: Trigger() with the bearer as
 * the clicker, so availability feedback, cooldowns and targeting modes are the
 * button's own. Paced like a keybound action button (action.dm keydown()).
 */
/datum/component/chrome_wheel/proc/fire(datum/action/ability, option_id)
	var/mob/living/carbon/bearer = parent
	if(bearer.next_click > world.time)
		return FALSE
	bearer.next_click = world.time + CLICK_CD_ACTIVATE_ABILITY
	// Async because some triggers wait on the player: a multi-tool arm opens its own radial.
	if(option_id)
		INVOKE_ASYNC(ability, TYPE_PROC_REF(/datum/action, use_chrome_wheel_option), bearer, option_id)
	else
		INVOKE_ASYNC(ability, TYPE_PROC_REF(/datum/action, Trigger), bearer)
	return TRUE

// ---- Selection ---------------------------------------------------------

/datum/component/chrome_wheel/proc/select(datum/action/ability, option_id)
	selected_ref = WEAKREF(ability)
	selected_option = option_id
	mark(ability)
	for(var/atom/movable/screen/chrome_wheel/chip/chip as anything in chips)
		draw_chip(chip)
	update_readout()

/datum/component/chrome_wheel/proc/deselect()
	selected_ref = null
	selected_option = null
	unmark()

/// The picked ability, while it is still chrome in this body and its picked
/// option is still on offer. A pick that went stale is dropped.
/datum/component/chrome_wheel/proc/get_selected_ability()
	var/datum/action/ability = selected_ref?.resolve()
	if(!ability)
		if(selected_ref)
			deselect()
		return null
	var/mob/living/carbon/bearer = parent
	if(!(ability in get_chrome_wheel_actions(bearer)) || (selected_option && !chrome_wheel_find_option(ability, bearer, selected_option)))
		deselect()
		return null
	return ability

/// Frames the picked ability's buttons, now and whenever they are rebuilt.
/datum/component/chrome_wheel/proc/mark(datum/action/ability)
	if(marked_ref?.resolve() == ability)
		return
	unmark()
	marked_ref = WEAKREF(ability)
	RegisterSignal(ability, COMSIG_ACTION_OVERLAY_APPLY, PROC_REF(on_marked_overlays))
	RegisterSignal(ability, COMSIG_ACTION_REMOVED, PROC_REF(on_marked_removed))
	var/mutable_appearance/frame = chrome_wheel_marker("module_selected")
	for(var/datum/hud/viewing_hud as anything in ability.viewers)
		var/atom/movable/screen/movable/action_button/button = ability.viewers[viewing_hud]
		button?.cut_overlay(frame)
		button?.add_overlay(frame)

/datum/component/chrome_wheel/proc/unmark()
	var/datum/action/marked = marked_ref?.resolve()
	marked_ref = null
	if(!marked)
		return
	UnregisterSignal(marked, list(COMSIG_ACTION_OVERLAY_APPLY, COMSIG_ACTION_REMOVED))
	var/mutable_appearance/frame = chrome_wheel_marker("module_selected")
	for(var/datum/hud/viewing_hud as anything in marked.viewers)
		var/atom/movable/screen/movable/action_button/button = marked.viewers[viewing_hud]
		button?.cut_overlay(frame)

/// A button for the marked ability was built or rebuilt; put the frame back on.
/datum/component/chrome_wheel/proc/on_marked_overlays(datum/action/source, atom/movable/screen/movable/action_button/button, force)
	SIGNAL_HANDLER
	var/mutable_appearance/frame = chrome_wheel_marker("module_selected")
	button.cut_overlay(frame)
	button.add_overlay(frame)

/// The picked ability left this body (the ware was cut out, or moved to someone
/// else): drop the pick now, so its frame never follows it into another body.
/datum/component/chrome_wheel/proc/on_marked_removed(datum/action/source, mob/old_owner)
	SIGNAL_HANDLER
	if(old_owner == parent)
		deselect()

/// Picks the ability on [chip] while it is still chrome in this body. Returns
/// whether it did: a ware cut out while the wheel was held open drops out here,
/// so its chip can't be picked and the pick can't follow it into someone else.
/datum/component/chrome_wheel/proc/select_chip(atom/movable/screen/chrome_wheel/chip/chip, quiet = FALSE)
	var/datum/action/ability = chip?.ability_ref?.resolve()
	if(!ability || !(ability in get_chrome_wheel_actions(parent)))
		return FALSE
	select(ability)
	if(!quiet)
		var/mob/living/carbon/bearer = parent
		bearer.balloon_alert(bearer, lowertext(chip.name))
	return TRUE

/// Pick [chip] (or nothing, for null) and close the wheel. The pick lands at
/// once; the wheel stays up a moment longer for the lock and the fade.
/datum/component/chrome_wheel/proc/choose(atom/movable/screen/chrome_wheel/chip/chip)
	var/picked = chip && select_chip(chip)
	close_wheel(linger = TRUE, chosen = picked ? chip : null)

// ---- Opening and closing -----------------------------------------------

/datum/component/chrome_wheel/proc/open_wheel(mode)
	var/mob/living/carbon/bearer = parent
	var/client/viewer = bearer.client
	if(wheel_mode != CHROME_WHEEL_CLOSED || !viewer || bearer.stat >= UNCONSCIOUS)
		return FALSE
	var/list/abilities = get_chrome_wheel_actions(bearer)
	if(!length(abilities))
		bearer.balloon_alert(bearer, "no chrome!")
		return FALSE
	clear_fading()
	build_wheel(abilities)

	catcher = new
	catcher.wheel = src
	catcher.assign_to_mob(bearer)
	catcher.update_for_view(viewer.view)
	shown_to = viewer
	viewer.screen += catcher
	viewer.screen += hub
	play_open()

	wheel_mode = mode
	mouse_start = null
	mouse_moved = FALSE
	START_PROCESSING(SSfastprocess, src)
	return TRUE

/**
 * Makes every piece of the wheel for [abilities] and hangs it off a new hub,
 * without putting anything on a screen.
 */
/datum/component/chrome_wheel/proc/build_wheel(list/abilities)
	var/list/placements = chrome_wheel_placements(abilities)
	var/list/names = chrome_wheel_names(abilities)
	parts = list()
	chips = list()
	leaders = list()
	arcs = list()
	readout_state = null
	hub = new
	parts += hub
	add_piece(/atom/movable/screen/chrome_wheel/art/backdrop)
	add_piece(/atom/movable/screen/chrome_wheel/art, "body")
	glow = add_piece(/atom/movable/screen/chrome_wheel/art, null, 2.2)
	glow.alpha = 0
	var/list/arc_names = list()
	for(var/socket in GLOB.chrome_wheel_sockets)
		arc_names |= GLOB.chrome_wheel_sockets[socket]["arc"]
	for(var/arc_name in arc_names)
		arcs[arc_name] = add_piece(/atom/movable/screen/chrome_wheel/art, "arc_[arc_name]", 2.25)

	// Which sockets hold chrome of their own, and which positions are taken.
	var/list/occupied = list()
	var/list/taken = list()
	for(var/datum/action/ability as anything in placements)
		var/list/placement = placements[ability]
		taken["[placement["socket"]]|[placement["index"]]"] = TRUE
		if(!placement["hand"])
			occupied[placement["socket"]] = TRUE
	for(var/socket in GLOB.chrome_wheel_sockets)
		add_leader(socket, socket, occupied[socket])
		if(!taken["[socket]|1"])
			var/list/point = chrome_wheel_position(socket, 1)
			var/atom/movable/screen/chrome_wheel/empty_socket/outline = add_piece(/atom/movable/screen/chrome_wheel/empty_socket)
			outline.pixel_x = point[1]
			outline.pixel_y = point[2]

	for(var/datum/action/ability as anything in abilities)
		var/list/placement = placements[ability]
		var/socket = placement["socket"]
		var/list/point = chrome_wheel_position(socket, placement["index"])
		var/atom/movable/screen/chrome_wheel/chip/chip = add_piece(/atom/movable/screen/chrome_wheel/chip)
		chip.ability_ref = WEAKREF(ability)
		chip.name = names[ability]
		chip.socket = socket
		chip.index = placement["index"]
		chip.leader_key = socket
		chip.region = GLOB.chrome_wheel_sockets[socket]["region"]
		if(placement["hand"])
			var/hand = (socket == CHROME_WHEEL_SOCKET_LEFT_ARM) ? "l_hand" : "r_hand"
			chip.region = hand
			// The ring art has a run to the hand from each first-row position.
			if(chip.index <= chrome_wheel_socket_fits(socket))
				chip.leader_key = "[hand]_[chip.index]"
				add_leader(chip.leader_key, hand, TRUE)
		chip.chip_x = point[1]
		chip.chip_y = point[2]
		chip.pixel_x = point[1]
		chip.pixel_y = point[2]
		chips += chip
		draw_chip(chip)
	build_readout()
	update_readout()

/// A new piece of the wheel on the hub. [art_state] sets its icon state and
/// [piece_layer] its layer, when given.
/datum/component/chrome_wheel/proc/add_piece(piece_type, art_state, piece_layer)
	var/atom/movable/screen/chrome_wheel/piece = new piece_type
	if(art_state)
		piece.icon_state = art_state
	if(piece_layer)
		piece.layer = piece_layer
	parts += piece
	hub.vis_contents += piece
	return piece

/// The leader for [key] and the dot where it meets the body, from the ring art.
/datum/component/chrome_wheel/proc/add_leader(key, art_key, filled)
	if(leaders[key])
		return
	var/atom/movable/screen/chrome_wheel/art/line = add_piece(/atom/movable/screen/chrome_wheel/art, "leader_[key]", 2.3)
	var/atom/movable/screen/chrome_wheel/art/dot = add_piece(/atom/movable/screen/chrome_wheel/art, "node_[art_key]", 2.4)
	leaders[key] = list("leader" = line, "node" = dot, "node_state" = "node_[art_key]", "alpha" = filled ? 100 : 40)
	style_leader(key, null)

/// The readout panel's frame and its empty text lines.
/datum/component/chrome_wheel/proc/build_readout()
	var/left = CHROME_WHEEL_READOUT_LEFT
	var/top = CHROME_WHEEL_READOUT_TOP
	var/width = CHROME_WHEEL_READOUT_WIDTH
	var/height = CHROME_WHEEL_READOUT_HEIGHT
	add_readout_block(left, top - height, width, height, CHROME_WHEEL_PANEL_COLOR, 205, 4)
	add_readout_block(left, top - 1, width, 1, CHROME_WHEEL_HUD_COLOR, 120, 4.1)
	add_readout_block(left, top - height, width, 1, CHROME_WHEEL_HUD_COLOR, 120, 4.1)
	add_readout_block(left, top - height, 1, height, CHROME_WHEEL_HUD_COLOR, 120, 4.1)
	add_readout_block(left + width - 1, top - height, 1, height, CHROME_WHEEL_HUD_COLOR, 120, 4.1)
	add_readout_block(left, top - 12, 2, 12, CHROME_WHEEL_HUD_COLOR, 255, 4.1)
	// Text boxes are taller than their line and centred on it, as the chrome
	// read sets them: Grand9K caps start 5 px under a 16 px box's top,
	// TinyUnicode caps 8 px under a 17 px one.
	readout_title = add_readout_text(left + 5, top - 11 - 2, width - 9, 16)
	readout_sub = add_readout_text(left + 5, top - 9 - 13, width - 9, 17)
	readout_status = add_readout_text(left + 5, top - 11 - 3, width - 10, 16)
	readout_mark = add_piece(/atom/movable/screen/chrome_wheel/readout, "pick_glyph", 4.3)
	readout_mark.color = CHROME_WHEEL_PICKED_COLOR
	readout_mark.alpha = 0
	readout_mark.pixel_x = left + 140
	readout_mark.pixel_y = top - 22

/datum/component/chrome_wheel/proc/add_readout_block(x, y, width, height, block_color, block_alpha, block_layer)
	var/atom/movable/screen/chrome_wheel/readout/block = add_piece(/atom/movable/screen/chrome_wheel/readout, null, block_layer)
	block.color = block_color
	block.alpha = block_alpha
	block.transform = chrome_readout_quad(x, y, width, height)
	return block

/datum/component/chrome_wheel/proc/add_readout_text(x, y, width, height)
	var/atom/movable/screen/chrome_wheel/readout/line = add_piece(/atom/movable/screen/chrome_wheel/readout, null, 4.2)
	line.icon_state = null
	line.maptext_x = x
	line.maptext_y = y
	line.maptext_width = width
	line.maptext_height = height
	return line

/// Fades the wheel in and pops the chips out one after another, clockwise from the top.
/datum/component/chrome_wheel/proc/play_open()
	hub.alpha = 0
	animate(hub, alpha = 255, time = 1)
	var/list/order = sortTim(chips.Copy(), GLOBAL_PROC_REF(cmp_chrome_wheel_bearing))
	for(var/i in 1 to length(order))
		var/atom/movable/screen/chrome_wheel/chip/chip = order[i]
		var/matrix/small = matrix(0.6, 0, 0, 0, 0.6, 0)
		chip.transform = small
		animate(chip, transform = small, time = (i - 1) * 0.08)
		animate(transform = matrix(), time = 0.8, easing = BACK_EASING | EASE_OUT)

/**
 * Shuts the wheel and gives the mouse back to the world. With [linger] the
 * pieces stay on screen a moment to fade, after [chosen] locks.
 */
/datum/component/chrome_wheel/proc/close_wheel(linger = FALSE, atom/movable/screen/chrome_wheel/chip/chosen)
	STOP_PROCESSING(SSfastprocess, src)
	wheel_mode = CHROME_WHEEL_CLOSED
	if(shown_to)
		shown_to.screen -= catcher
	QDEL_NULL(catcher)
	if(linger && shown_to && hub)
		clear_fading()
		fading_client = shown_to
		fading_parts = parts
		if(chosen)
			play_lock(chosen)
		animate(hub, alpha = hub.alpha, time = chosen ? 1 : 0)
		animate(alpha = 0, time = 1)
		fading_timer = addtimer(CALLBACK(src, PROC_REF(fade_done)), CHROME_WHEEL_LINGER_TIME, TIMER_STOPPABLE | TIMER_CLIENT_TIME | TIMER_DELETE_ME)
	else
		shown_to?.screen -= hub
		QDEL_LIST(parts)
	shown_to = null
	hub = null
	parts = null
	chips = null
	leaders = null
	arcs = null
	glow = null
	highlighted = null
	readout_title = null
	readout_sub = null
	readout_status = null
	readout_mark = null
	readout_state = null
	mouse_start = null
	mouse_moved = FALSE

/datum/component/chrome_wheel/proc/fade_done()
	fading_timer = null
	clear_fading()

/// Takes a fading wheel off its screen now.
/datum/component/chrome_wheel/proc/clear_fading()
	if(fading_timer)
		deltimer(fading_timer)
		fading_timer = null
	if(fading_client && length(fading_parts))
		fading_client.screen -= fading_parts[1]
	fading_client = null
	QDEL_LIST(fading_parts)

/// The pick locking on: its frame flashes white and the brackets snap in.
/datum/component/chrome_wheel/proc/play_lock(atom/movable/screen/chrome_wheel/chip/chip)
	var/settled = chip.color
	chip.color = "#ffffff"
	animate(chip, color = "#ffffff", time = 0.5)
	animate(color = settled, time = 0)
	for(var/atom/movable/screen/chrome_wheel/bracket/corner as anything in chip.brackets)
		if(!corner.alpha)
			continue
		var/final_x = corner.pixel_x
		var/final_y = corner.pixel_y
		corner.pixel_x = final_x + corner.out_x * 7
		corner.pixel_y = final_y + corner.out_y * 7
		corner.color = "#ffffff"
		animate(corner, pixel_x = final_x, pixel_y = final_y, time = 1, easing = BACK_EASING | EASE_OUT)
		animate(corner, color = "#ffffff", time = 0.5, flags = ANIMATION_PARALLEL)
		animate(color = CHROME_WHEEL_PICKED_COLOR, time = 0)

/// While open: catch a modifier bind's release, and keep the chips current.
/datum/component/chrome_wheel/process(seconds_per_tick)
	if(wheel_mode == CHROME_WHEEL_CLOSED)
		return PROCESS_KILL
	if(wheel_mode == CHROME_WHEEL_HELD && !wheel_key_held())
		wheel_key_up()
		if(wheel_mode == CHROME_WHEEL_CLOSED)
			return PROCESS_KILL
	for(var/atom/movable/screen/chrome_wheel/chip/chip as anything in chips)
		draw_chip(chip)
	update_readout()

// ---- Drawing -----------------------------------------------------------

/**
 * Brings a chip up to date: its frame in its tier colour (blinking red while
 * the chrome is down), the ability's icon, the green inner line while it is
 * deployed or armed, the pick's brackets, and a draining shade with seconds
 * while it cools down. Bigger and brighter while pointed at. Redraws only on
 * change.
 */
/datum/component/chrome_wheel/proc/draw_chip(atom/movable/screen/chrome_wheel/chip/chip)
	var/mob/living/carbon/bearer = parent
	var/datum/action/ability = chip.ability_ref?.resolve()
	if(!ability)
		if(chip.drawn_state != "gone")
			chip.drawn_state = "gone"
			chip.cut_overlays()
			chip.underlays.Cut()
			chip.alpha = 70
		return
	var/datum/action/cooldown/timed = istype(ability, /datum/action/cooldown) ? ability : null
	var/cooldown_left = timed ? max(timed.next_use_time - world.time, 0) : 0
	var/offline = chrome_wheel_offline(ability)
	var/unavailable = !offline && chrome_wheel_unavailable(ability, cooldown_left)
	var/hovered = (chip == highlighted)
	var/picked = (selected_ref?.resolve() == ability)
	var/active = chrome_wheel_ability_active(ability, bearer)
	var/atom/movable/screen/movable/action_button/button = bearer.hud_used ? ability.viewers[bearer.hud_used] : null
	var/state = "[offline]|[unavailable]|[hovered]|[picked]|[active]|[timed?.next_use_time]|[!!cooldown_left]|[button?.icon_state]|[ability.button_icon_state]"
	if(state != chip.drawn_state)
		chip.drawn_state = state
		paint_chip(chip, ability, offline, unavailable, hovered, picked, active)
		update_shade(chip, cooldown_left, timed ? max(timed.cooldown_time, cooldown_left) : 0)
		if(hovered)
			light_up(chip)
	update_count(chip, cooldown_left)

/datum/component/chrome_wheel/proc/paint_chip(atom/movable/screen/chrome_wheel/chip/chip, datum/action/ability, offline, unavailable, hovered, picked, active)
	var/size = hovered ? 26 : 22
	chip.size = size
	var/base_color = offline ? CHROME_WHEEL_OFFLINE_COLOR : chrome_wheel_tier_color(ability)
	chip.icon_state = "frame_[size][offline ? "_blink" : ""]"
	chip.color = hovered ? chrome_wheel_lighten(base_color, 0.35) : base_color
	chip.alpha = 255
	chip.cut_overlays()
	chip.underlays.Cut()
	chip.underlays += chrome_wheel_chip_piece("fill_[size]")
	if(hovered)
		chip.add_overlay(chrome_wheel_chip_piece("halo_26", base_color, 90))
	var/mutable_appearance/look = chrome_wheel_ability_look(ability, parent)
	// The icon fills the chip but for a pixel all round.
	var/scale = (size - 2) / ICON_SIZE_X
	look.transform = matrix(scale, 0, 0, 0, scale, 0)
	// Red like its button when it can't be used.
	if(offline || unavailable)
		look.color = ability.transparent_when_unavailable ? rgb(128, 0, 0, 128) : rgb(128, 0, 0)
	chip.add_overlay(look)
	if(active)
		chip.add_overlay(chrome_wheel_chip_piece("deployed_[size]"))
	draw_brackets(chip, picked)

/// The pick's corner brackets, a couple of pixels clear of the chip's corners.
/datum/component/chrome_wheel/proc/draw_brackets(atom/movable/screen/chrome_wheel/chip/chip, picked)
	if(!picked)
		for(var/atom/movable/screen/chrome_wheel/bracket/corner as anything in chip.brackets)
			corner.alpha = 0
		return
	if(!chip.brackets)
		chip.brackets = list()
		for(var/corner_name in list("nw", "ne", "sw", "se"))
			var/atom/movable/screen/chrome_wheel/bracket/corner = new
			corner.icon_state = "bracket_[corner_name]"
			corner.out_x = findtext(corner_name, "w") ? -1 : 1
			corner.out_y = findtext(corner_name, "n") ? 1 : -1
			chip.brackets += corner
			chip.vis_contents += corner
	// The bracket art has its corner pixel one in from the edge of its tile; a
	// chip's brackets sit two pixels outside its corners.
	var/reach = chip.size / 2 + 2 - 15
	for(var/atom/movable/screen/chrome_wheel/bracket/corner as anything in chip.brackets)
		animate(corner)
		corner.alpha = 255
		corner.color = CHROME_WHEEL_PICKED_COLOR
		corner.pixel_x = corner.out_x * reach
		corner.pixel_y = corner.out_y * reach

/// The cooldown wipe: a dark block over the chip's inside that drains downward
/// to nothing as the cooldown runs out, with a faint line along its top.
/// Animated on the client, so it costs no ticks.
/datum/component/chrome_wheel/proc/update_shade(atom/movable/screen/chrome_wheel/chip/chip, cooldown_left, cooldown_total)
	if(!cooldown_left)
		for(var/atom/movable/screen/chrome_wheel/chip_part/part in list(chip.shade, chip.shade_edge))
			animate(part)
			part.alpha = 0
		return
	if(!chip.shade)
		chip.shade = new
		chip.shade.color = COLOR_BLACK
		chip.shade_edge = new
		chip.shade_edge.layer = 3.2
		chip.vis_contents += list(chip.shade, chip.shade_edge)
	var/list/start = chrome_wheel_shade_shape(chip.size, cooldown_left / max(cooldown_total, 1))
	var/list/finish = chrome_wheel_shade_shape(chip.size, 0)
	chip.shade.alpha = 185
	chip.shade.transform = start[1]
	animate(chip.shade, transform = finish[1], time = cooldown_left)
	chip.shade_edge.alpha = 110
	chip.shade_edge.transform = start[2]
	animate(chip.shade_edge, transform = finish[2], time = cooldown_left)

/**
 * The cooldown wipe's shape on a chip of [size] with [fraction] of its
 * cooldown left: list(shade transform, edge transform). The px state is a
 * full tile, squashed to the chip's inside and sitting on its floor; the edge
 * is the wipe's top row.
 */
/proc/chrome_wheel_shade_shape(size, fraction)
	RETURN_TYPE(/list)
	var/inside = size - 2
	var/height = max(inside * min(fraction, 1), 0.3)
	return list(
		matrix(inside / 32, 0, 0, 0, height / 32, -(inside - height) / 2),
		matrix(inside / 32, 0, 0, 0, 1 / 32, max(height, 1) - inside / 2 - 0.5),
	)

/// Whole seconds left on the cooldown, in the chip's bottom left corner.
/datum/component/chrome_wheel/proc/update_count(atom/movable/screen/chrome_wheel/chip/chip, cooldown_left)
	var/seconds = cooldown_left ? CEILING(cooldown_left / 10, 1) : 0
	var/state = "[seconds]|[chip.size]"
	if(state == chip.count_state)
		return
	chip.count_state = state
	if(!seconds)
		if(chip.count)
			chip.count.maptext = null
		return
	if(!chip.count)
		chip.count = new
		chip.count.icon_state = null
		chip.count.layer = 3.3
		chip.count.maptext_width = 32
		chip.count.maptext_height = 17
		chip.vis_contents += chip.count
	// Box centred like the readout's lines (caps 8 px under a 17 px box's top),
	// putting the number three pixels in from the chip's bottom left corner.
	chip.count.maptext = chrome_readout_tiny_html("[seconds]")
	chip.count.maptext_x = 16 - chip.size / 2 + 3
	chip.count.maptext_y = 18 - chip.size / 2

/// Sets a leader and its node to [lit_color], or back to the dim HUD colour for null.
/datum/component/chrome_wheel/proc/style_leader(key, lit_color)
	var/list/leader = leaders?[key]
	if(!leader)
		return
	var/atom/movable/screen/chrome_wheel/art/line = leader["leader"]
	var/atom/movable/screen/chrome_wheel/art/dot = leader["node"]
	if(lit_color)
		line.color = lit_color
		line.alpha = 235
		dot.icon_state = "[leader["node_state"]]_lit"
		dot.color = chrome_wheel_lighten(lit_color, 0.6)
		dot.alpha = 255
		return
	line.color = CHROME_WHEEL_HUD_COLOR
	line.alpha = leader["alpha"]
	dot.icon_state = leader["node_state"]
	dot.color = CHROME_WHEEL_HUD_COLOR
	dot.alpha = min(255, leader["alpha"] + 60)

/// Lights the arc, leader and body part of [chip] in its colour, and puts
/// everything else back. Null lights nothing.
/datum/component/chrome_wheel/proc/light_up(atom/movable/screen/chrome_wheel/chip/chip)
	var/datum/action/ability = chip?.ability_ref?.resolve()
	var/lit_color
	if(ability)
		lit_color = chrome_wheel_offline(ability) ? CHROME_WHEEL_OFFLINE_COLOR : chrome_wheel_tier_color(ability)
	for(var/key in leaders)
		style_leader(key, (lit_color && key == chip.leader_key) ? lit_color : null)
	var/lit_arc = lit_color ? GLOB.chrome_wheel_sockets[chip.socket]["arc"] : null
	for(var/arc_name in arcs)
		var/atom/movable/screen/chrome_wheel/art/arc = arcs[arc_name]
		var/lit = (arc_name == lit_arc)
		arc.color = lit ? lit_color : CHROME_WHEEL_HUD_COLOR
		arc.alpha = lit ? 200 : 80
	if(!glow)
		return
	if(!lit_color)
		glow.alpha = 0
		return
	glow.icon_state = "glow_[chip.region]"
	glow.color = lit_color
	glow.alpha = 255

/**
 * The readout under the ring: the chip pointed at, the chrome it lives in in
 * its tier colour, and on the right how it stands ("14s", "offline", "out").
 * With nothing pointed at it shows the pick, dim, with a small bracket mark.
 */
/datum/component/chrome_wheel/proc/update_readout()
	if(!readout_title)
		return
	var/mob/living/carbon/bearer = parent
	var/atom/movable/screen/chrome_wheel/chip/shown = highlighted
	var/datum/action/ability = shown?.ability_ref?.resolve()
	var/idle = !ability
	var/title
	if(idle)
		ability = get_selected_ability()
		if(ability)
			var/datum/chrome_wheel_option/option = selected_option ? chrome_wheel_find_option(ability, bearer, selected_option) : null
			title = option ? option.name : ability.chrome_wheel_name()
	else
		title = shown.name
	var/sub = ability ? chrome_wheel_ware_name(ability) : ""
	var/sub_color = CHROME_WHEEL_DIM_COLOR
	var/title_color = CHROME_WHEEL_DIM_COLOR
	var/status
	var/status_color
	if(ability && !idle)
		title_color = CHROME_WHEEL_NAME_COLOR
		var/datum/action/cooldown/timed = istype(ability, /datum/action/cooldown) ? ability : null
		var/cooldown_left = timed ? max(timed.next_use_time - world.time, 0) : 0
		if(chrome_wheel_offline(ability))
			status = "offline"
			status_color = CHROME_WHEEL_OFFLINE_COLOR
			sub_color = CHROME_WHEEL_OFFLINE_NAME_COLOR
		else
			sub_color = chrome_wheel_tier_color(ability)
			if(chrome_wheel_ability_active(ability, bearer))
				status = timed ? "armed" : "out"
				status_color = CHROME_WHEEL_DEPLOYED_COLOR
			else if(cooldown_left)
				status = "[CEILING(cooldown_left / 10, 1)]s"
				status_color = "#ffffff"
	var/state = "[idle]|[title]|[title_color]|[sub]|[sub_color]|[status]"
	if(state == readout_state)
		return
	readout_state = state
	var/static/datum/font/header_font = new /datum/font/grand9k/size_6pt()
	var/static/datum/font/list_font = new /datum/font/tiny_unicode/size_12pt()
	var/status_width = status ? header_font.get_metrics(status) + 6 : 0
	if(title)
		title = chrome_readout_fit(title, header_font, CHROME_WHEEL_READOUT_WIDTH - 10 - status_width)
		readout_title.maptext = chrome_readout_header_html(html_encode(title), title_color)
	else
		readout_title.maptext = null
	if(sub)
		sub = chrome_readout_fit(sub, list_font, CHROME_WHEEL_READOUT_WIDTH - 10)
		readout_sub.maptext = chrome_readout_tiny_html("<span style='color:[sub_color]'>[html_encode(sub)]</span>")
	else
		readout_sub.maptext = null
	readout_status.maptext = status ? chrome_readout_header_html(status, status_color, "right") : null
	readout_mark.alpha = (idle && ability) ? 200 : 0

// ---- Mouse -------------------------------------------------------------

/datum/component/chrome_wheel/proc/mouse_moved(params)
	if(wheel_mode == CHROME_WHEEL_CLOSED)
		return
	var/list/offset = chrome_wheel_mouse_offset(params, shown_to)
	if(!offset)
		return
	if(!mouse_moved)
		if(!mouse_start)
			mouse_start = offset
			return
		if(abs(offset[1] - mouse_start[1]) + abs(offset[2] - mouse_start[2]) < 4)
			return
		mouse_moved = TRUE
	point_at(offset)

/datum/component/chrome_wheel/proc/mouse_clicked(params)
	if(wheel_mode == CHROME_WHEEL_CLOSED)
		return
	var/list/offset = chrome_wheel_mouse_offset(params, shown_to)
	if(!offset)
		close_wheel()
		return
	point_at(offset)
	choose(highlighted)

/// Highlights whatever the mouse at [offset] points at.
/datum/component/chrome_wheel/proc/point_at(list/offset)
	var/list/points = list()
	var/list/on_ring = list()
	for(var/atom/movable/screen/chrome_wheel/chip/chip as anything in chips)
		points += list(list(chip.chip_x, chip.chip_y))
		on_ring += chip.index <= chrome_wheel_socket_fits(chip.socket)
	var/index = chrome_wheel_pick(offset[1], offset[2], points, on_ring)
	set_highlight(index ? chips[index] : null)

/// Moves the highlight: the old chip shrinks back, the new one grows and lights its part of the body.
/datum/component/chrome_wheel/proc/set_highlight(atom/movable/screen/chrome_wheel/chip/chip)
	if(chip == highlighted)
		return
	var/atom/movable/screen/chrome_wheel/chip/old = highlighted
	highlighted = chip
	if(old)
		draw_chip(old)
	if(chip)
		draw_chip(chip)
	else
		light_up(null)
	update_readout()

#undef CHROME_WHEEL_READOUT_TOP
#undef CHROME_WHEEL_READOUT_LEFT
#undef CHROME_WHEEL_READOUT_WIDTH
#undef CHROME_WHEEL_READOUT_HEIGHT
