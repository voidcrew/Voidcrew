/**
 * # Chrome wheel
 *
 * One radial holding every ability the bearer's chrome carries, so nobody has
 * to hunt a row of action buttons mid-fight. Three keybinds drive it
 * (chrome_wheel_keybindings.dm):
 *
 * - Chrome wheel: hold it and the wheel opens at the centre of the view. Point
 *   at a slice and let go, or click one, to pick it. A quick tap leaves the
 *   wheel open for a click instead; pressing the key again shuts it.
 * - Use chrome: fires the picked ability on key down.
 * - Use OS chrome: fires the OS-slot ware's ability on key down, whatever is
 *   picked.
 *
 * A slice IS the bearer's existing /datum/action, the same one their button
 * holds, fired through the same Trigger() a button click uses. Cooldowns,
 * ORGAN_FAILING, check_flags and click-to-target modes are therefore shared
 * with the buttons, and nothing here grants, copies or replaces an ability.
 * Abilities are collected generically from every installed organ carrying
 * /datum/component/cyberware, so new ware shows up without touching this file.
 *
 * Layout is fixed by body region (chrome_wheel_layout()): head at the top,
 * right arm on the right, legs at the bottom, left arm on the left, torso on a
 * ring around the centre with the OS at its top. A region's chrome changing
 * never moves another region's slices, and an empty region keeps a dim slice
 * where it would be. The centre shows what Use chrome will fire, and that
 * ability's own button carries the MOD-style "selected" frame on the HUD.
 *
 * Sub-options: an ability can hand the wheel an outer ring of choices through
 * /datum/action/proc/chrome_wheel_options(), empty by default. Pointing at that
 * ability opens the ring outside the wheel; picking one makes Use chrome call
 * the ability's use_chrome_wheel_option() with its id instead of Trigger().
 *
 * Mouse handling: BYOND only reports the mouse over things it can hit, so the
 * open wheel lays a full-view cursor catcher (tg's, as the scope uses) under
 * its mouse-transparent slices. Every move and click lands on the catcher, and
 * the slice is worked out from where the mouse is relative to the centre.
 */

/// Organ slots that sort first inside their wheel region, in this order. Any
/// other slot follows them, alphabetically by slot name.
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

/// Positions a region holds for one organ slot, filled or not, so the rest of
/// that region never moves when the slot is filled or emptied. Region =>
/// list(slot, positions held). The OS owns the top of the torso ring; chrome
/// optics (their ability plus the chrome read) own the top two head positions.
GLOBAL_LIST_INIT(chrome_wheel_reserved, list(
	CHROME_WHEEL_TORSO = list(ORGAN_SLOT_CYBERWARE_OS, 1),
	CHROME_WHEEL_HEAD = list(ORGAN_SLOT_EYES, 2),
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
 * One entry on an ability's outer ring. [id] must stay the same between calls
 * for the same choice: the wheel remembers a pick by id and asks the ability
 * for its options again before firing it.
 */
/datum/chrome_wheel_option
	/// Stable key for this choice within its ability. Non-empty text: a false
	/// id reads as "no option" and would fire the ability itself.
	var/id
	/// Shown under the wheel while the slice is pointed at.
	var/name
	var/icon
	var/icon_state

/datum/chrome_wheel_option/New(id, name, icon, icon_state)
	src.id = id
	src.name = name
	src.icon = icon
	src.icon_state = icon_state

/**
 * Sub-options this ability shows on an outer ring of the chrome wheel while it
 * is pointed at: a list of /datum/chrome_wheel_option, or null for none (the
 * default, and every ability today). A cyberdeck's hacks belong here.
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

// ---- Layout ------------------------------------------------------------

/// Which wheel region an organ's abilities sit in, from the zone it lives in.
/proc/chrome_wheel_region(obj/item/organ/ware)
	if(!istype(ware))
		return CHROME_WHEEL_TORSO
	switch(ware.zone)
		if(BODY_ZONE_HEAD, BODY_ZONE_PRECISE_EYES, BODY_ZONE_PRECISE_MOUTH)
			return CHROME_WHEEL_HEAD
		if(BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_R_HAND)
			return CHROME_WHEEL_RIGHT_ARM
		if(BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND)
			return CHROME_WHEEL_LEFT_ARM
		if(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG, BODY_ZONE_PRECISE_R_FOOT, BODY_ZONE_PRECISE_L_FOOT)
			return CHROME_WHEEL_LEGS
	return CHROME_WHEEL_TORSO

/// Where an organ slot ranks inside its region. Unlisted slots rank last.
/proc/chrome_wheel_slot_rank(obj/item/organ/ware)
	var/rank = istype(ware) ? GLOB.chrome_wheel_slot_order.Find(ware.slot) : 0
	return rank || length(GLOB.chrome_wheel_slot_order) + 1

/// Order inside a region: ranked organ slots, then other slots by name, then
/// each organ's own button order.
/proc/cmp_chrome_wheel_abilities(datum/action/first, datum/action/second)
	var/obj/item/organ/first_ware = first.target
	var/obj/item/organ/second_ware = second.target
	var/rank_gap = chrome_wheel_slot_rank(first_ware) - chrome_wheel_slot_rank(second_ware)
	if(rank_gap)
		return rank_gap
	if(first_ware != second_ware)
		var/first_slot = istype(first_ware) ? first_ware.slot : ""
		var/second_slot = istype(second_ware) ? second_ware.slot : ""
		return sorttext(second_slot, first_slot) || sorttext(second.name, first.name)
	return LAZYFIND(first_ware.actions, first) - LAZYFIND(second_ware.actions, second)

/**
 * Pixel offset from the wheel centre of position [index] in [region], as
 * list(x, y). The four limb regions own a 90 degree arc of the outer ring
 * each: position 1 on the compass point, 2 and 3 thirty degrees either side
 * (mirrored so both arms' second slice hangs low), 4 and on a row further out.
 * The torso gets the inner ring, starting at the top.
 */
/proc/chrome_wheel_position(region, index)
	RETURN_TYPE(/list)
	var/angle = 0
	var/radius = 0
	if(region == CHROME_WHEEL_TORSO)
		var/static/list/torso_angles = list(0, 60, 300, 120, 240, 180)
		angle = torso_angles[((index - 1) % length(torso_angles)) + 1]
		// Six torso abilities is more than any body can carry today; extras
		// stack outward rather than reflowing anything.
		var/row = round((index - 1) / length(torso_angles))
		radius = row ? CHROME_WHEEL_OUTER_RADIUS + row * CHROME_WHEEL_ROW_GAP : CHROME_WHEEL_INNER_RADIUS
	else
		var/base_angle = 0
		var/turn = 30
		switch(region)
			if(CHROME_WHEEL_RIGHT_ARM)
				base_angle = 90
			if(CHROME_WHEEL_LEGS)
				base_angle = 180
				turn = -30
			if(CHROME_WHEEL_LEFT_ARM)
				base_angle = 270
				turn = -30
		var/static/list/steps = list(0, 1, -1)
		angle = base_angle + turn * steps[((index - 1) % length(steps)) + 1]
		radius = CHROME_WHEEL_OUTER_RADIUS + round((index - 1) / length(steps)) * CHROME_WHEEL_ROW_GAP
	return list(round(sin(angle) * radius, 1), round(cos(angle) * radius, 1))

/**
 * Lays the abilities out by region: an associative list of ability =>
 * list(x, y). Positions depend only on each ability's own region, slot and
 * button order, never on what the rest of the body carries.
 */
/proc/chrome_wheel_layout(list/abilities)
	RETURN_TYPE(/list)
	var/list/by_region = list()
	for(var/datum/action/ability as anything in abilities)
		var/region = chrome_wheel_region(ability.target)
		if(!by_region[region])
			by_region[region] = list()
		var/list/members = by_region[region]
		members += ability
	var/list/positions = list()
	for(var/region in by_region)
		var/list/members = sortTim(by_region[region], GLOBAL_PROC_REF(cmp_chrome_wheel_abilities))
		var/list/reserved = GLOB.chrome_wheel_reserved[region]
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
			positions[ability] = chrome_wheel_position(region, index)
	return positions

/// Positions of [count] sub-option slices on a ring outside [ring_radius],
/// centred on the direction of their parent slice at (parent_x, parent_y).
/proc/chrome_wheel_sub_positions(parent_x, parent_y, count, ring_radius)
	RETURN_TYPE(/list)
	. = list()
	var/angle = delta_to_angle(parent_x, parent_y)
	var/radius = ring_radius + CHROME_WHEEL_ROW_GAP
	var/step = TODEGREES(CHROME_WHEEL_SLICE_SPACING / radius)
	for(var/i in 1 to count)
		// 0, +1, -1, +2, -2 steps: the first option sits straight out from its parent.
		var/slice_angle = angle + round(i / 2) * step * ((i % 2) ? -1 : 1)
		. += list(list(round(sin(slice_angle) * radius, 1), round(cos(slice_angle) * radius, 1)))

/// Display names, with the body side added where two slices would read the
/// same (a pair of Mantis housings gives two Mantis Lunges).
/proc/chrome_wheel_names(list/abilities)
	RETURN_TYPE(/list)
	var/list/names = list()
	var/list/counts = list()
	for(var/datum/action/ability as anything in abilities)
		var/name = format_text(ability.name)
		names[ability] = name
		counts[name] += 1
	for(var/datum/action/ability as anything in abilities)
		var/obj/item/organ/ware = ability.target
		if(counts[names[ability]] > 1 && istype(ware))
			names[ability] = "[names[ability]] ([parse_zone(ware.zone)])"
	return names

// ---- Pointing ----------------------------------------------------------

/**
 * Which of [points] (a list of list(x, y) offsets) the mouse at offset
 * (dx, dy) means, as an index, or 0 for none. A slice within reach of the
 * mouse is the one under it; past the slices, the mouse points at the slice
 * in its direction, so a quick flick outward works without landing on it.
 * Empty regions point at nothing.
 */
/proc/chrome_wheel_pick(dx, dy, list/points)
	var/distance = sqrt(dx ** 2 + dy ** 2)
	if(distance < CHROME_WHEEL_DEADZONE)
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
	var/mouse_angle = delta_to_angle(dx, dy)
	var/pointed = 0
	var/pointed_turn = 0
	var/pointed_radius = 0
	for(var/i in 1 to length(points))
		var/list/point = points[i]
		var/radius = sqrt(point[1] ** 2 + point[2] ** 2)
		if(radius >= distance)
			continue
		var/turn = abs(WRAP(mouse_angle - delta_to_angle(point[1], point[2]) + 180, 0, 360) - 180)
		if(turn > CHROME_WHEEL_POINT_TOLERANCE)
			continue
		// Ties on direction go to the slice further out: further means deeper.
		if(!pointed || turn < pointed_turn - 2 || (turn <= pointed_turn + 2 && radius > pointed_radius))
			pointed = i
			pointed_turn = turn
			pointed_radius = radius
	return pointed

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

/// A radial.dmi frame for a slice or button, shared: "module_selected" (cyan,
/// what Use chrome fires) or "module_active" (green, deployed or armed).
/proc/chrome_wheel_marker(frame_state)
	var/static/list/markers = list()
	if(!markers[frame_state])
		markers[frame_state] = mutable_appearance('icons/hud/radial.dmi', frame_state, FLOAT_LAYER - 0.1)
	return markers[frame_state]

/**
 * What an ability's slice shows: a copy of the bearer's own button for it,
 * minus the button background, so the slice carries the same icon, item
 * overlay and cooldown seconds the button does. Built from the action's vars
 * when the bearer has no button for it.
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
	look.color = null
	look.alpha = 255
	look.transform = matrix()
	// A copied button keeps APPEARANCE_UI; let the icon grow with its slice when pointed at.
	look.appearance_flags &= ~RESET_TRANSFORM
	return look

/proc/chrome_wheel_option_look(datum/chrome_wheel_option/option)
	RETURN_TYPE(/mutable_appearance)
	if(option?.icon && option.icon_state)
		return mutable_appearance(option.icon, option.icon_state)
	return mutable_appearance('icons/hud/actions.dmi', "default")

/// Whether an ability is "on" right now: a toggled arm with its hardware out,
/// or a click-to-target ability armed and waiting for the click.
/proc/chrome_wheel_ability_active(datum/action/ability, mob/living/carbon/bearer)
	if(istype(ability, /datum/action/cooldown))
		return bearer.click_intercept == ability
	var/obj/item/organ/cyberimp/arm/toolkit/arm = ability.target
	if(istype(arm) && istype(ability, /datum/action/item_action/organ_action/toggle))
		return arm.active_item && !(arm.active_item in arm)
	return FALSE

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
	/// Full-view mouse tracker under the slices.
	var/atom/movable/screen/fullscreen/cursor_catcher/chrome_wheel/catcher
	/// Screen objects the open wheel made, except sub-option slices, for teardown.
	var/list/parts
	/// Ability slices that can be pointed at, one per ability.
	var/list/main_slices
	/// Sub-option slices on show, all belonging to [sub_parent].
	var/list/sub_slices
	/// The ability slice whose sub-option ring is open.
	var/atom/movable/screen/chrome_wheel/slice/sub_parent
	/// The slice the mouse is on.
	var/atom/movable/screen/chrome_wheel/slice/highlighted
	/// Shows what Use chrome fires.
	var/atom/movable/screen/chrome_wheel/slice/centre
	/// Name of the slice the mouse is on.
	var/atom/movable/screen/chrome_wheel/label/label
	/// Furthest ability slice from the centre; the sub-option ring goes outside it.
	var/outer_radius = 0
	/// First mouse position reported after opening. Nothing is pointed at until
	/// the mouse leaves it, so a cursor that was resting somewhere when the
	/// key went down picks nothing by accident.
	var/list/mouse_start
	/// Whether the mouse has left [mouse_start].
	var/mouse_moved = FALSE

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
	unmark()
	selected_ref = null
	return ..()

/datum/component/chrome_wheel/proc/on_logout(datum/source)
	SIGNAL_HANDLER
	close_wheel()

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
			select_slice(highlighted, quiet = TRUE)
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
	if(wheel_mode != CHROME_WHEEL_CLOSED)
		draw_centre()

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

/datum/component/chrome_wheel/proc/select_slice(atom/movable/screen/chrome_wheel/slice/slice, quiet = FALSE)
	var/datum/action/ability = slice?.ability_ref?.resolve()
	if(!ability)
		return
	select(ability, slice.option_id)
	if(!quiet)
		var/mob/living/carbon/bearer = parent
		bearer.balloon_alert(bearer, lowertext(slice.name))

/// Pick [slice] (or nothing, for null) and close the wheel.
/datum/component/chrome_wheel/proc/choose(atom/movable/screen/chrome_wheel/slice/slice)
	if(slice)
		select_slice(slice)
	close_wheel()

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
	var/list/positions = chrome_wheel_layout(abilities)
	var/list/names = chrome_wheel_names(abilities)
	parts = list()
	main_slices = list()
	sub_slices = list()
	outer_radius = 0
	hub = new
	parts += hub
	var/list/taken = list()
	for(var/datum/action/ability as anything in abilities)
		var/list/point = positions[ability]
		var/atom/movable/screen/chrome_wheel/slice/slice = new_slice(point[1], point[2])
		slice.ability_ref = WEAKREF(ability)
		slice.name = names[ability]
		main_slices += slice
		taken["[point[1]],[point[2]]"] = TRUE
		outer_radius = max(outer_radius, sqrt(point[1] ** 2 + point[2] ** 2))
		draw_slice(slice)
	// Regions with nothing on their first position keep a dim slice there, so
	// the wheel always has the same shape.
	for(var/region in list(CHROME_WHEEL_HEAD, CHROME_WHEEL_RIGHT_ARM, CHROME_WHEEL_LEGS, CHROME_WHEEL_LEFT_ARM, CHROME_WHEEL_TORSO))
		var/list/point = chrome_wheel_position(region, 1)
		if(taken["[point[1]],[point[2]]"])
			continue
		var/atom/movable/screen/chrome_wheel/slice/placeholder = new_slice(point[1], point[2])
		placeholder.alpha = 70
	centre = new_slice(0, 0)
	draw_centre()
	label = new
	label.pixel_y = -(CHROME_WHEEL_OUTER_RADIUS + 34)
	parts += label
	hub.vis_contents += label

	catcher = new
	catcher.wheel = src
	catcher.assign_to_mob(bearer)
	catcher.update_for_view(viewer.view)
	shown_to = viewer
	viewer.screen += catcher
	viewer.screen += hub
	hub.alpha = 0
	animate(hub, alpha = 255, time = 0.1 SECONDS)

	wheel_mode = mode
	mouse_start = null
	mouse_moved = FALSE
	START_PROCESSING(SSfastprocess, src)
	return TRUE

/datum/component/chrome_wheel/proc/new_slice(x, y)
	var/atom/movable/screen/chrome_wheel/slice/slice = new
	slice.pixel_x = x
	slice.pixel_y = y
	slice.slice_x = x
	slice.slice_y = y
	parts += slice
	hub.vis_contents += slice
	return slice

/datum/component/chrome_wheel/proc/close_wheel()
	STOP_PROCESSING(SSfastprocess, src)
	wheel_mode = CHROME_WHEEL_CLOSED
	if(shown_to)
		shown_to.screen -= catcher
		shown_to.screen -= hub
	shown_to = null
	hide_sub_ring()
	highlighted = null
	hub?.vis_contents.Cut()
	QDEL_LIST(parts)
	QDEL_NULL(catcher)
	hub = null
	centre = null
	label = null
	parts = null
	main_slices = null
	sub_slices = null
	mouse_start = null
	mouse_moved = FALSE

/// While open: catch a modifier bind's release, and keep the slices current.
/datum/component/chrome_wheel/process(seconds_per_tick)
	if(wheel_mode == CHROME_WHEEL_CLOSED)
		return PROCESS_KILL
	if(wheel_mode == CHROME_WHEEL_HELD && !wheel_key_held())
		wheel_key_up()
		if(wheel_mode == CHROME_WHEEL_CLOSED)
			return PROCESS_KILL
	for(var/atom/movable/screen/chrome_wheel/slice/slice in main_slices + sub_slices)
		draw_slice(slice)

// ---- Drawing -----------------------------------------------------------

/**
 * Brings a slice up to date: the ability's look, red when it cannot be used
 * (the button's own tint), a draining shade while it cools down, and a frame
 * when it is picked (cyan) or deployed/armed (green). Redraws only on change.
 */
/datum/component/chrome_wheel/proc/draw_slice(atom/movable/screen/chrome_wheel/slice/slice)
	var/mob/living/carbon/bearer = parent
	var/datum/action/ability = slice.ability_ref?.resolve()
	if(!ability)
		if(slice.drawn_state)
			slice.cut_overlays()
			slice.drawn_state = null
			slice.alpha = 70
		return
	var/datum/action/cooldown/timed = istype(ability, /datum/action/cooldown) ? ability : null
	var/cooldown_left = timed ? max(timed.next_use_time - world.time, 0) : 0
	var/obj/item/organ/ware = ability.target
	var/datum/component/cyberware/chrome = istype(ware) ? ware.GetComponent(/datum/component/cyberware) : null
	var/offline = chrome ? !chrome.is_running() : FALSE
	// On cooldown IsAvailable() is FALSE anyway; the shade shows that instead.
	if(!offline && !cooldown_left && !ability.IsAvailable())
		offline = TRUE
	var/frame
	if(selected_ref?.resolve() == ability && (!slice.option_id || slice.option_id == selected_option))
		frame = "module_selected"
	else if(!slice.option_id && chrome_wheel_ability_active(ability, bearer))
		frame = "module_active"
	var/atom/movable/screen/movable/action_button/button = bearer.hud_used ? ability.viewers[bearer.hud_used] : null
	var/state = "[offline]|[frame]|[timed?.next_use_time]|[!!cooldown_left]|[button?.maptext]|[button?.icon_state]"
	if(state == slice.drawn_state)
		return
	slice.drawn_state = state
	slice.cut_overlays()
	if(frame)
		slice.add_overlay(chrome_wheel_marker(frame))
	var/mutable_appearance/look = slice.option_look ? new /mutable_appearance(slice.option_look) : chrome_wheel_ability_look(ability, bearer)
	if(offline)
		look.color = ability.transparent_when_unavailable ? rgb(128, 0, 0, 128) : rgb(128, 0, 0)
	slice.add_overlay(look)
	update_shade(slice, cooldown_left, timed ? max(timed.cooldown_time, cooldown_left) : 0, timed?.next_use_time)

/// The cooldown wipe: a dark copy of the slice that drains downward to nothing
/// as the cooldown runs out. Animated on the client, so it costs no ticks.
/datum/component/chrome_wheel/proc/update_shade(atom/movable/screen/chrome_wheel/slice/slice, cooldown_left, cooldown_total, cooldown_until)
	if(!cooldown_left)
		if(slice.shade)
			animate(slice.shade)
			slice.shade.alpha = 0
		slice.cooldown_until = 0
		return
	if(slice.cooldown_until == cooldown_until)
		return
	slice.cooldown_until = cooldown_until
	if(!slice.shade)
		slice.shade = new
		slice.vis_contents += slice.shade
	var/atom/movable/screen/chrome_wheel/shade/shade = slice.shade
	var/fraction = clamp(cooldown_left / max(cooldown_total, 1), 0.01, 1)
	// The slice graphic is 26 pixels tall around the icon's centre, so a shade
	// squashed to [fraction] sits on the bottom edge when dropped by 13 * (1 - fraction).
	shade.alpha = 255
	shade.transform = matrix(1, 0, 0, 0, fraction, -13 * (1 - fraction))
	animate(shade, transform = matrix(1, 0, 0, 0, 0.01, -13 * 0.99), time = cooldown_left)

/// The centre shows what Use chrome fires, dim when nothing is picked.
/datum/component/chrome_wheel/proc/draw_centre()
	if(!centre)
		return
	centre.cut_overlays()
	var/mob/living/carbon/bearer = parent
	var/datum/action/ability = get_selected_ability()
	if(!ability)
		centre.alpha = 70
		return
	centre.alpha = 255
	centre.add_overlay(chrome_wheel_marker("module_selected"))
	if(selected_option)
		centre.add_overlay(chrome_wheel_option_look(chrome_wheel_find_option(ability, bearer, selected_option)))
	else
		centre.add_overlay(chrome_wheel_ability_look(ability, bearer))

/datum/component/chrome_wheel/proc/draw_label()
	if(!label)
		return
	label.maptext = highlighted ? MAPTEXT("<div align='center'>[html_encode(highlighted.name)]</div>") : null

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
	var/list/candidates = list()
	var/list/points = list()
	for(var/atom/movable/screen/chrome_wheel/slice/slice in main_slices + sub_slices)
		candidates += slice
		points += list(list(slice.slice_x, slice.slice_y))
	var/index = chrome_wheel_pick(offset[1], offset[2], points)
	set_highlight(index ? candidates[index] : null, sqrt(offset[1] ** 2 + offset[2] ** 2) < CHROME_WHEEL_DEADZONE)

/**
 * Moves the highlight. An ability slice opens its sub-option ring, if it has
 * one. The ring stays open while the mouse crosses the gap out to it, and
 * closes when another ability slice is highlighted or the mouse comes home.
 */
/datum/component/chrome_wheel/proc/set_highlight(atom/movable/screen/chrome_wheel/slice/slice, back_in_centre = FALSE)
	if(slice == highlighted)
		return
	if(highlighted)
		highlighted.icon_state = "radial_slice"
		highlighted.transform = null
	highlighted = slice
	if(slice)
		// The focus state alone is a faint border; the size change is what reads mid-fight.
		slice.icon_state = "radial_slice_focus"
		slice.transform = matrix(1.25, 0, 0, 0, 1.25, 0)
		if(!slice.option_id && slice != sub_parent)
			show_sub_ring(slice)
	else if(back_in_centre)
		hide_sub_ring()
	draw_label()

/datum/component/chrome_wheel/proc/show_sub_ring(atom/movable/screen/chrome_wheel/slice/parent_slice)
	hide_sub_ring()
	var/datum/action/ability = parent_slice.ability_ref?.resolve()
	var/list/options = ability?.chrome_wheel_options(parent)
	if(!length(options))
		return
	sub_parent = parent_slice
	var/list/points = chrome_wheel_sub_positions(parent_slice.slice_x, parent_slice.slice_y, length(options), outer_radius)
	for(var/i in 1 to length(options))
		var/datum/chrome_wheel_option/option = options[i]
		if(!istype(option))
			continue
		var/list/point = points[i]
		var/atom/movable/screen/chrome_wheel/slice/sub = new
		sub.pixel_x = point[1]
		sub.pixel_y = point[2]
		sub.slice_x = point[1]
		sub.slice_y = point[2]
		sub.ability_ref = parent_slice.ability_ref
		sub.option_id = option.id
		sub.name = option.name
		sub.option_look = chrome_wheel_option_look(option)
		sub_slices += sub
		hub.vis_contents += sub
		draw_slice(sub)

/datum/component/chrome_wheel/proc/hide_sub_ring()
	sub_parent = null
	if(!length(sub_slices))
		return
	if(highlighted in sub_slices)
		highlighted = null
	for(var/atom/movable/screen/chrome_wheel/slice/sub in sub_slices)
		hub?.vis_contents -= sub
		qdel(sub)
	sub_slices.Cut()
