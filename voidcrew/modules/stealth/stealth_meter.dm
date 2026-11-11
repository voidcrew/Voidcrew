/**
 * # Stealth guards: the mark over the head (owner decisions 24 and 27, draft D)
 *
 * - Its notice of you above 0: a "?" only you see (a client image). It fills yellow from the bottom to
 *   STEALTH_SUSPICIOUS_AT, then red rises through the yellow toward STEALTH_ALERT_AT.
 * - Alert: a solid red "!" everyone sees. Target out of sight: the red drains from the top over
 *   STEALTH_LOSE_TARGET_TIME and refills when it sees them again.
 * - Searching: a yellow "?" everyone sees, draining from the top over the search (or until calm_until
 *   after it put its target down). Empty: gone.
 * - While alert or searching, nobody sees their own "?" on that guard.
 * - Suspicious of a noise (stealth_hearing.dm): an empty grey "?" for every player near who has no fill of
 *   their own on that guard. Someone it has started to see gets their own filling "?" instead, so nothing
 *   stacks. A glance, a hold and a radio call show no mark: the turn, the raised hand and the line are the read.
 *
 * Both are drawn on the guard (vis_contents for the public mark, an image located on the guard for the
 * private one), so they show only when the guard itself is in view, never through walls; above the
 * lighting so they read in the dark. Fills round to the nearest row; drains round up, so the last row
 * stays lit until the time really runs out.
 *
 * Cost: the meter is built only while a living player is within STEALTH_METER_RANGE of a guard whose scan
 * is running (or an admin is watching its sight), updated by the guard's 1 s scan and its state changes,
 * and changes an icon_state only when the step changes. A drain steps on a timer at each row change (at
 * most STEALTH_METER_ROWS per drain); animate() is not used, because a chained icon_state animation can't
 * snap back when the target is seen again.
 *
 * The mark lives only while the scan that feeds it runs. A guard that is cuffed, held, stunned, down, asleep
 * with its level, or driven by a player has no mark, so none is ever left stale over its head.
 */
/datum/stealth_meter
	/// The guard's controller, which owns this meter
	var/datum/ai_controller/basic_controller/human_npc/stealth/controller
	var/mob/living/guard
	/// The public mark, in the guard's vis_contents while it shows
	var/obj/effect/abstract/stealth_mark/mark
	/// icon_state of the public mark, or null
	var/public_state
	/// REF(player), or "watch:ckey" for an admin watching its sight => list(image, client it was given to)
	var/list/private_marks = list()
	/// Timer for the next drain step
	var/drain_timer

/datum/stealth_meter/New(datum/ai_controller/basic_controller/human_npc/stealth/controller, mob/living/guard)
	src.controller = controller
	src.guard = guard
	RegisterSignal(guard, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_body_position))

/datum/stealth_meter/Destroy()
	if(drain_timer)
		deltimer(drain_timer)
		drain_timer = null
	set_public(null)
	for(var/key in private_marks.Copy())
		remove_private(key)
	if(guard)
		UnregisterSignal(guard, COMSIG_LIVING_SET_BODY_POSITION)
	controller = null
	guard = null
	return ..()

/// Reads the controller and shows what it says. Changes nothing that hasn't changed.
/datum/stealth_meter/proc/update()
	if(QDELETED(guard) || isnull(controller))
		return
	var/state = controller.stealth_state()
	var/new_public = stealth_meter_public_state(state, world.time, controller.lost_since, controller.blackboard[BB_STEALTH_STATE_SINCE], controller.calm_until)
	set_public(new_public)
	// Alert and searching own the mark even once it has drained: no private "?" in the moment before the scan
	// sends it back to unaware (and clears its notice).
	var/public_owned = new_public || state == STEALTH_ALERT || state == STEALTH_SEARCHING
	update_private(public_owned ? null : controller.notice_map, !public_owned && stealth_meter_heard(state, controller.suspicion_heard))
	schedule_drain()

/datum/stealth_meter/proc/set_public(new_state)
	if(new_state == public_state)
		return
	public_state = new_state
	if(isnull(new_state))
		if(mark)
			guard?.vis_contents -= mark
			QDEL_NULL(mark)
		return
	if(isnull(mark))
		mark = new
		SET_PLANE_EXPLICIT(mark, ABOVE_LIGHTING_PLANE, guard)
		mark.pixel_z = stealth_meter_offset(guard)
		guard.vis_contents += mark
	mark.icon_state = new_state

/// The players near the guard who get the empty grey "?" of a heard noise: every living player within
/// STEALTH_METER_RANGE with no fill of their own in `notice`.
/datum/stealth_meter/proc/heard_viewers(list/notice)
	. = list()
	var/turf/here = get_turf(guard)
	if(isnull(here) || here.z > length(SSmobs.clients_by_zlevel))
		return
	for(var/mob/living/viewer as anything in SSmobs.clients_by_zlevel[here.z])
		if(viewer == guard || get_dist(get_turf(viewer), here) > STEALTH_METER_RANGE)
			continue
		var/list/entry = notice?[REF(viewer)]
		if(entry && stealth_meter_notice_state(entry[STEALTH_ENTRY_NOTICE]))
			continue
		. += viewer

/// Gives each nearby player their own "?" for their notice entry, and takes away the rest. An admin watching
/// the guard's sight gets the fullest one, whoever it is for. `heard`: the guard is suspicious of a noise, so
/// everyone near without a fill of their own gets the empty "?".
/datum/stealth_meter/proc/update_private(list/notice, heard = FALSE)
	// key => list(icon_state, client to show it to)
	var/list/wanted = list()
	var/turf/here = get_turf(guard)
	if(heard && here)
		for(var/mob/living/viewer as anything in heard_viewers(notice))
			if(viewer.client)
				wanted[REF(viewer)] = list(STEALTH_METER_HEARD_STATE, viewer.client)
		for(var/datum/stealth_sight_overlay/overlay as anything in controller.watchers)
			var/client/admin = overlay.user_ref?.resolve()
			if(admin && !wanted[REF(admin.mob)])
				wanted["watch:[admin.ckey]"] = list(STEALTH_METER_HEARD_STATE, admin)
	if(length(notice) && here)
		var/top_state
		var/top_notice = 0
		for(var/key in notice)
			var/list/entry = notice[key]
			var/state = stealth_meter_notice_state(entry[STEALTH_ENTRY_NOTICE])
			if(isnull(state))
				continue
			if(entry[STEALTH_ENTRY_NOTICE] > top_notice)
				top_notice = entry[STEALTH_ENTRY_NOTICE]
				top_state = state
			var/mob/viewer = locate(key)
			if(!ismob(viewer) || isnull(viewer.client))
				continue
			// By its turf: someone hiding in a box has no z of their own.
			var/turf/viewer_turf = get_turf(viewer)
			if(viewer_turf?.z != here.z || get_dist(viewer_turf, here) > STEALTH_METER_RANGE)
				continue
			wanted[key] = list(state, viewer.client)
		if(top_state)
			for(var/datum/stealth_sight_overlay/overlay as anything in controller.watchers)
				var/client/admin = overlay.user_ref?.resolve()
				if(isnull(admin))
					continue
				var/list/own = wanted[REF(admin.mob)]
				if(own && own[1] != STEALTH_METER_HEARD_STATE)
					continue
				// The fullest fill takes the place of the admin's empty heard "?": one glyph at a time.
				wanted -= REF(admin.mob)
				wanted["watch:[admin.ckey]"] = list(top_state, admin)
	for(var/key in private_marks.Copy())
		var/list/held = private_marks[key]
		var/list/want = wanted[key]
		if(isnull(want) || want[2] != held[2])
			remove_private(key)
	for(var/key in wanted)
		var/list/want = wanted[key]
		var/list/held = private_marks[key]
		if(held)
			var/image/shown = held[1]
			if(shown.icon_state != want[1])
				shown.icon_state = want[1]
			continue
		var/client/viewer = want[2]
		var/image/shown = image('voidcrew/icons/effects/stealth_meter.dmi', guard, want[1])
		shown.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART
		shown.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		SET_PLANE_EXPLICIT(shown, ABOVE_LIGHTING_PLANE, guard)
		shown.pixel_z = stealth_meter_offset(guard)
		viewer.images += shown
		private_marks[key] = list(shown, viewer)

/datum/stealth_meter/proc/remove_private(key)
	var/list/held = private_marks[key]
	private_marks -= key
	if(!held)
		return
	var/image/shown = held[1]
	var/client/given_to = held[2]
	given_to?.images -= shown
	shown.loc = null

/// A draining mark steps at each row change rather than waiting for the next scan.
/datum/stealth_meter/proc/schedule_drain()
	if(drain_timer)
		deltimer(drain_timer)
		drain_timer = null
	var/delay = stealth_meter_next_step(controller.stealth_state(), world.time, controller.lost_since, controller.blackboard[BB_STEALTH_STATE_SINCE], controller.calm_until)
	if(delay > 0)
		drain_timer = addtimer(CALLBACK(src, PROC_REF(on_drain_step)), delay, TIMER_STOPPABLE)

/datum/stealth_meter/proc/on_drain_step()
	drain_timer = null
	controller?.stealth_meter_update()

/datum/stealth_meter/proc/on_body_position(datum/source)
	SIGNAL_HANDLER
	var/offset = stealth_meter_offset(guard)
	if(mark)
		mark.pixel_z = offset
	for(var/key in private_marks)
		var/list/held = private_marks[key]
		var/image/shown = held[1]
		shown.pixel_z = offset

/// The public mark. Lives only in its guard's vis_contents.
/obj/effect/abstract/stealth_mark
	name = ""
	icon = 'voidcrew/icons/effects/stealth_meter.dmi'
	icon_state = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM | KEEP_APART
	anchored = TRUE

// ===== The controller's side =====

/datum/ai_controller/basic_controller/human_npc/stealth
	/// The mark over its head while anyone is near to see it (stealth_meter.dm)
	var/datum/stealth_meter/meter

/// Builds, updates or drops the mark. Nothing while its scan isn't running (stealth_scanning()), or with no
/// living player near and no admin watching its sight.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_meter_update()
	var/mob/living/guard = pawn
	if(!stealth_scanning() || (!length(watchers) && !stealth_meter_viewers_near(guard)))
		QDEL_NULL(meter)
		return
	if(isnull(meter))
		meter = new(src, guard)
	meter.update()

/// Whether a living player is close enough to the guard to see its mark.
/proc/stealth_meter_viewers_near(mob/living/guard)
	var/turf/here = get_turf(guard)
	if(isnull(here) || here.z > length(SSmobs.clients_by_zlevel))
		return FALSE
	for(var/mob/viewer as anything in SSmobs.clients_by_zlevel[here.z])
		if(get_dist(viewer, here) <= STEALTH_METER_RANGE)
			return TRUE
	return FALSE

/// pixel_z for the glyph's bottom over `guard`: clear of its head, lower when it lies down.
/proc/stealth_meter_offset(mob/living/guard)
	if(guard.body_position == LYING_DOWN)
		return STEALTH_METER_LYING_Z
	. = STEALTH_METER_HEAD_Z
	if(ishuman(guard))
		var/mob/living/carbon/human/person = guard
		// The head rides the upper body offset (measured in a live client: a dwarf's head sits 5 px lower, not 9).
		var/list/offsets = GLOB.human_heights_to_offsets["[person.mob_height]"]
		if(length(offsets))
			. += offsets[1]

// ===== Pure: state to icon_state =====

/// Whether a guard in `state` shows the heard "?".
/proc/stealth_meter_heard(state, suspicion_heard)
	return suspicion_heard && state == STEALTH_SUSPICIOUS

/// The private "?" for a notice level, or null for none. Fills round to the nearest row.
/proc/stealth_meter_notice_state(notice)
	if(!(notice > 0))
		return null
	if(notice < STEALTH_SUSPICIOUS_AT)
		return "q_y[clamp(round(notice / STEALTH_SUSPICIOUS_AT * STEALTH_METER_ROWS, 1), 0, STEALTH_METER_ROWS)]"
	var/red = clamp(round((notice - STEALTH_SUSPICIOUS_AT) / (STEALTH_ALERT_AT - STEALTH_SUSPICIOUS_AT) * STEALTH_METER_ROWS, 1), 0, STEALTH_METER_ROWS)
	return red ? "q_r[red]" : "q_y[STEALTH_METER_ROWS]"

/// Rows still lit with `time_left` of `total`: rounded up, 0 once the time is up.
/proc/stealth_meter_drain_rows(time_left, total)
	if(total <= 0 || time_left <= 0)
		return 0
	return clamp(CEILING(time_left / total * STEALTH_METER_ROWS - 0.001, 1), 0, STEALTH_METER_ROWS)

/// When a public drain ends and how long it lasts, as list(end, total), or null when nothing drains.
/proc/stealth_meter_drain_span(state, lost_since, state_since, calm_until)
	switch(state)
		if(STEALTH_ALERT)
			if(lost_since)
				return list(lost_since + STEALTH_LOSE_TARGET_TIME, STEALTH_LOSE_TARGET_TIME)
		if(STEALTH_SEARCHING)
			var/end = calm_until || (state_since + STEALTH_SEARCH_TIME)
			return list(end, end - state_since)
	return null

/// The public mark for a guard's state, or null for none.
/proc/stealth_meter_public_state(state, now, lost_since, state_since, calm_until)
	switch(state)
		if(STEALTH_ALERT)
			if(!lost_since)
				return "ex_r[STEALTH_METER_ROWS]"
			var/list/span = stealth_meter_drain_span(state, lost_since, state_since, calm_until)
			var/rows = stealth_meter_drain_rows(span[1] - now, span[2])
			// Drained: the full searching "?" it is about to become.
			return rows ? "ex_r[rows]" : "q_y[STEALTH_METER_ROWS]"
		if(STEALTH_SEARCHING)
			var/list/span = stealth_meter_drain_span(state, lost_since, state_since, calm_until)
			var/rows = stealth_meter_drain_rows(span[1] - now, span[2])
			return rows ? "q_y[rows]" : null
	return null

/// Deciseconds until a draining public mark loses its next row, or 0 when nothing drains.
/proc/stealth_meter_next_step(state, now, lost_since, state_since, calm_until)
	var/list/span = stealth_meter_drain_span(state, lost_since, state_since, calm_until)
	if(isnull(span) || span[2] <= 0)
		return 0
	var/time_left = span[1] - now
	var/rows = stealth_meter_drain_rows(time_left, span[2])
	if(rows <= 0)
		return 0
	// The row goes when the time left reaches (rows - 1) sevenths; a tick later to land past it.
	return max(world.tick_lag, time_left - (rows - 1) * span[2] / STEALTH_METER_ROWS + world.tick_lag)
