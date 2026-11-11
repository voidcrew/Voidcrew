/**
 * # Stealth guard admin tools: noise
 *
 * "Stealth Noise" (Debug): makes a real stealth_noise() where you stand, of any kind and reach, with or
 * without you as its maker, and says how many guards heard it. It can also switch on the noise view: for
 * STEALTH_ADMIN_OVERLAY_TIME every noise on your level is drawn for you alone, with its kind and reach at the
 * source, a ring at the edge of its reach, and over each guard what it made of it ("heard 6.5/9 -> goes",
 * "muffled 11.5/9", "deaf", "busy"). Images are built only while someone watches. Every use is logged.
 */

/// One admin's noise view. Kept in GLOB.stealth_sight_overlays under "noise:<ckey>".
/datum/stealth_noise_view
	var/datum/weakref/user_ref
	var/key

/datum/stealth_noise_view/New(client/user)
	user_ref = WEAKREF(user)
	key = "noise:[user.ckey]"
	GLOB.stealth_sight_overlays[key] = src
	QDEL_IN(src, STEALTH_ADMIN_OVERLAY_TIME)

/datum/stealth_noise_view/Destroy()
	if(GLOB.stealth_sight_overlays[key] == src)
		GLOB.stealth_sight_overlays -= key
	return ..()

/// Draws one noise for its admin: the source, its reach, and what each guard made of it (`notes`, guard => text).
/datum/stealth_noise_view/proc/show(turf/where, kind, reach, list/notes, coalesced)
	var/client/user = user_ref?.resolve()
	if(isnull(user))
		qdel(src)
		return
	var/list/images = list()
	var/image/marker = image('icons/effects/alphacolors.dmi', where, "white")
	SET_PLANE(marker, ABOVE_LIGHTING_PLANE, where)
	marker.color = coalesced ? "#888888" : "#ff66cc"
	marker.alpha = coalesced ? 60 : 140
	if(!coalesced)
		marker.maptext = MAPTEXT("[kind] [reach]")
		marker.maptext_width = 96
	images += marker
	if(!coalesced)
		for(var/turf/edge as anything in RANGE_TURFS(reach, where))
			if(get_dist(edge, where) != reach)
				continue
			var/image/tint = image('icons/effects/alphacolors.dmi', edge, "white")
			SET_PLANE(tint, ABOVE_LIGHTING_PLANE, edge)
			tint.color = "#ff66cc"
			tint.alpha = 40
			images += tint
		for(var/mob/living/guard as anything in notes)
			var/turf/guard_turf = get_turf(guard)
			if(isnull(guard_turf))
				continue
			var/image/label = new
			label.loc = guard_turf
			SET_PLANE(label, ABOVE_LIGHTING_PLANE, guard_turf)
			label.maptext = MAPTEXT("[notes[guard]]")
			label.maptext_width = 128
			label.maptext_y = 34
			images += label
	user.images |= images
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(stealth_remove_images), user_ref, images), STEALTH_NOISE_VIEW_TIME)

/// The noise views of admins standing on `z`.
/proc/stealth_noise_views(z)
	. = list()
	for(var/key in GLOB.stealth_sight_overlays)
		var/datum/stealth_noise_view/view = GLOB.stealth_sight_overlays[key]
		if(!istype(view))
			continue
		var/client/user = view.user_ref?.resolve()
		var/turf/user_turf = get_turf(user?.mob)
		if(user_turf?.z == z)
			. += view

/// Switches `user`'s noise view on or off. TRUE if now on.
/proc/stealth_toggle_noise_view(client/user)
	var/datum/stealth_noise_view/old = GLOB.stealth_sight_overlays["noise:[user.ckey]"]
	if(old)
		qdel(old)
		return FALSE
	new /datum/stealth_noise_view(user)
	return TRUE

ADMIN_VERB(stealth_make_noise, R_DEBUG, "Stealth Noise", "Make a noise stealth guards can hear at your turf, or watch the noises on your z-level.", ADMIN_CATEGORY_DEBUG)
	var/turf/here = get_turf(user.mob)
	if(isnull(here))
		to_chat(user, span_warning("You need to be standing somewhere."), confidential = TRUE)
		return
	var/view_choice = "Toggle the noise view"
	var/choice = tgui_input_list(user, "Which noise?", "Stealth Noise", list(view_choice) + STEALTH_NOISE_KINDS)
	if(isnull(choice))
		return
	if(choice == view_choice)
		var/shown = stealth_toggle_noise_view(user)
		to_chat(user, span_notice("Noise view [shown ? "on" : "off"]."), confidential = TRUE)
		stealth_admin_log(user, "[shown ? "showed" : "hid"] the noise view", here)
		return
	var/list/profile = stealth_noise_profile(choice)
	var/reach = tgui_input_number(user, "Reach in tiles (0 for its usual [profile[STEALTH_PROFILE_REACH]])", "Stealth Noise", 0, 40, 0)
	if(isnull(reach))
		return
	var/as_me = isliving(user.mob) && tgui_alert(user, "Who made it?", "Stealth Noise", list("Nobody", "Me")) == "Me"
	here = get_turf(user.mob)
	var/heard = stealth_noise(here, choice, reach || null, as_me ? user.mob : null)
	to_chat(user, span_notice("[heard] guard\s heard it."), confidential = TRUE)
	stealth_admin_log(user, "made a [choice] noise[reach ? " (reach [reach])" : ""][as_me ? " as themselves" : ""], heard by [heard]", here)
	BLACKBOX_LOG_ADMIN_VERB("Stealth Noise")

/// The radio, the call on its way out and the last thing heard, for the guard summary.
/proc/stealth_guard_hearing_summary(mob/living/carbon/human/npc/guard, datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai)
	var/radio_text = "none"
	if(guard.stealth_radio)
		var/obj/item/radio/earpiece = guard.ears
		if(!istype(earpiece))
			radio_text = "none"
		else if(!earpiece.is_on())
			radio_text = "off"
		else if(is_within_radio_jammer_range(guard))
			radio_text = "jammed"
		else
			radio_text = "ok"
	. = "radio [radio_text]"
	if(stealth_ai.pending_call)
		. += " (calling in [max(0, round((stealth_ai.pending_call[STEALTH_CALL_DUE] - world.time) / (1 SECONDS)))]s)"
	if(stealth_ai.last_heard)
		. += " | heard [stealth_ai.last_heard[1]] [round((world.time - stealth_ai.last_heard[2]) / (1 SECONDS))]s ago"

/// What `group` remembers of noises, as chat text for `user`.
/proc/stealth_show_noise_memory(client/user, datum/stealth_group/group)
	var/list/lines = list("<b>[group.id]</b>: [group.alarm_count()] alarms in memory")
	// Prunes as it counts.
	group.lure_count(group.home)
	for(var/list/lure as anything in group.lures)
		var/turf/spot = lure[1]
		lines += "lure at ([spot.x], [spot.y]), [round((world.time - lure[2]) / (1 SECONDS))]s ago, [group.lure_count(spot)] near it"
	for(var/datum/stealth_check/check as anything in group.checks)
		var/mob/living/gone = check.who?.resolve()
		lines += "out looking: [gone ? gone.real_name : "(gone)"] at ([check.where.x], [check.where.y]), missed in [round((check.due - world.time) / (1 SECONDS))]s, [length(check.waiters)] waiting"
	to_chat(user, span_notice(lines.Join("<br>")), confidential = TRUE)
