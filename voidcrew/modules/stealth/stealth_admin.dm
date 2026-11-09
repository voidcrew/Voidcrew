/**
 * # Stealth guard admin tools
 *
 * "Stealth Guards" (Debug): lists every stealth guard on your z-level, shows and forces its awareness,
 * shows its sight to you alone, and acts on whole groups. Every action is logged (abuse review P16).
 *
 * The AI sleeps unless a living player is on the level. An admin watching as a ghost needs
 * "Force Z-Level Active" (npc_ships/code/admin_verbs.dm).
 */

/// The stealth guards on `z`, by group.
/proc/stealth_guards_on_level(z)
	. = list()
	for(var/datum/stealth_group/group as anything in GLOB.stealth_groups)
		for(var/mob/living/guard as anything in group.living_members())
			var/turf/where = get_turf(guard)
			if(where?.z == z)
				. += guard

/// One line about `guard`, for admins.
/proc/stealth_guard_summary(mob/living/carbon/human/npc/guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	if(!istype(stealth_ai))
		return "[guard] (no stealth AI)"
	var/atom/focus = stealth_ai.blackboard[BB_STEALTH_FOCUS]
	var/focus_text = "none"
	if(focus)
		var/list/entry = stealth_ai.blackboard[BB_STEALTH_NOTICE]?[REF(focus)]
		focus_text = "[focus] [entry ? round(entry[STEALTH_ENTRY_NOTICE], 0.01) : "-"]"
	var/since = round((world.time - stealth_ai.blackboard[BB_STEALTH_STATE_SINCE]) / (1 SECONDS))
	var/route_text = stealth_ai.route_id ? "route [stealth_ai.route_id] stop [stealth_ai.route_index]" : "sentry"
	var/status_text = list("[AI_STATUS_ON]" = "on", "[AI_STATUS_IDLE]" = "idle", "[AI_STATUS_OFF]" = "off")["[stealth_ai.ai_status]"] || "off"
	return "[guard.real_name] [REF(guard)] | [stealth_ai.group?.id || "no group"] | [stealth_ai.stealth_state()] [since]s | focus [focus_text] | [stealth_ai.blackboard[BB_STEALTH_WARY] ? "wary" : "calm"] | [route_text] | AI [status_text]"

ADMIN_VERB(stealth_guards, R_DEBUG, "Stealth Guards", "View and force the awareness of stealth guards on your z-level.", ADMIN_CATEGORY_DEBUG)
	var/turf/here = get_turf(user.mob)
	if(isnull(here))
		to_chat(user, span_warning("You need to be standing somewhere."), confidential = TRUE)
		return
	var/list/choices = list()
	var/list/groups = list()
	for(var/mob/living/carbon/human/npc/guard as anything in stealth_guards_on_level(here.z))
		choices[stealth_guard_summary(guard)] = guard
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
		if(stealth_ai.group)
			groups["Whole group: [stealth_ai.group.id]"] = stealth_ai.group
	if(!length(choices))
		to_chat(user, span_notice("No stealth guards on this z-level."), confidential = TRUE)
		return
	var/list/all_choices = sort_list(choices) + sort_list(groups)
	var/choice = tgui_input_list(user, "Which guard or group?", "Stealth Guards", all_choices)
	if(isnull(choice))
		return
	if(groups[choice])
		stealth_admin_group(user, groups[choice])
	else if(choices[choice])
		stealth_admin_guard(user, choices[choice])
	BLACKBOX_LOG_ADMIN_VERB("Stealth Guards")

/proc/stealth_admin_log(client/user, text, atom/where)
	log_admin("[key_name(user)] stealth guards: [text][where ? " at [AREACOORD(where)]" : ""]")
	message_admins("[key_name_admin(user)] stealth guards: [text][where ? " at [ADMIN_VERBOSEJMP(where)]" : ""]")

/proc/stealth_admin_guard(client/user, mob/living/carbon/human/npc/guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	if(QDELETED(guard) || !istype(stealth_ai))
		return
	var/list/actions = list("Force Unaware", "Force Suspicious at my turf", "Force Alert on me", "Force Alert on a mob I pick", "Force Searching at my turf", "Toggle Wary", "Show its sight", "Jump to it", "Next stop")
	var/action = tgui_input_list(user, stealth_guard_summary(guard), "Stealth Guard", actions)
	if(isnull(action) || QDELETED(guard))
		return
	var/turf/here = get_turf(user.mob)
	switch(action)
		if("Force Unaware")
			stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
			stealth_ai.stealth_go_unaware()
		if("Force Suspicious at my turf")
			stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
			stealth_ai.stealth_go_suspicious(here)
		if("Force Alert on me")
			if(!isliving(user.mob))
				to_chat(user, span_warning("You need a living body for that."), confidential = TRUE)
				return
			stealth_ai.stealth_go_alert(user.mob)
		if("Force Alert on a mob I pick")
			var/list/mobs = list()
			for(var/mob/living/someone in range(HUMAN_NPC_SIGHT_RANGE * 2, guard))
				if(someone != guard)
					mobs["[someone] ([REF(someone)])"] = someone
			var/picked = tgui_input_list(user, "Alert on whom?", "Stealth Guard", sort_list(mobs))
			if(isnull(picked) || QDELETED(mobs[picked]))
				return
			stealth_ai.stealth_go_alert(mobs[picked])
		if("Force Searching at my turf")
			stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
			stealth_ai.stealth_go_searching(here)
		if("Toggle Wary")
			stealth_ai.blackboard[BB_STEALTH_WARY] = !stealth_ai.blackboard[BB_STEALTH_WARY]
		if("Show its sight")
			stealth_toggle_sight_overlay(user, guard)
		if("Jump to it")
			user.mob.forceMove(get_turf(guard))
		if("Next stop")
			var/next = stealth_ai.stealth_next_index()
			if(next)
				stealth_ai.stealth_drop_walk()
				stealth_ai.at_stop = FALSE
				stealth_ai.route_index = next
	stealth_admin_log(user, "[action] on [key_name(guard)]", guard)

/proc/stealth_admin_group(client/user, datum/stealth_group/group)
	var/list/actions = list("Calm all", "Clear wary", "Alert all on me", "Search all at my turf", "Show every route")
	var/action = tgui_input_list(user, "[group.id]: [length(group.living_members())] guards", "Stealth Group", actions)
	if(isnull(action) || QDELETED(group))
		return
	var/turf/here = get_turf(user.mob)
	if(action == "Show every route")
		stealth_show_routes(user, group)
	else
		for(var/mob/living/guard as anything in group.living_members())
			var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
			if(!istype(stealth_ai) || guard.stat == DEAD)
				continue
			switch(action)
				if("Calm all")
					stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
					stealth_ai.stealth_go_unaware()
				if("Clear wary")
					stealth_ai.blackboard[BB_STEALTH_WARY] = FALSE
				if("Alert all on me")
					if(isliving(user.mob))
						stealth_ai.stealth_go_alert(user.mob)
				if("Search all at my turf")
					stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
					stealth_ai.stealth_go_searching(here)
	stealth_admin_log(user, "[action] on [group.id]", group.home)

/// Numbered markers on every stop of every route in `group`, for `user` alone, for a minute.
/proc/stealth_show_routes(client/user, datum/stealth_group/group)
	var/list/images = list()
	for(var/route in group.routes)
		var/list/stops = group.routes[route]
		for(var/index in 1 to length(stops))
			var/datum/stealth_stop/stop = stops[index]
			var/image/marker = image('icons/effects/alphacolors.dmi', stop.spot, "white")
			SET_PLANE(marker, ABOVE_LIGHTING_PLANE, stop.spot)
			marker.color = stop.chatter ? "#ffaa00" : "#00aaff"
			marker.alpha = 110
			marker.maptext = MAPTEXT("[route][index]")
			images += marker
	user.images |= images
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(stealth_remove_images), WEAKREF(user), images), 60 SECONDS)

/proc/stealth_remove_images(datum/weakref/user_ref, list/images)
	var/client/user = user_ref?.resolve()
	user?.images -= images

// ===== Sight overlay =====

/// Admins watching one guard's sight: admin ckey => overlay
GLOBAL_LIST_EMPTY(stealth_sight_overlays)

/proc/stealth_toggle_sight_overlay(client/user, mob/living/carbon/human/npc/guard)
	var/datum/stealth_sight_overlay/old = GLOB.stealth_sight_overlays[user.ckey]
	var/same = old?.guard_ref?.resolve() == guard
	if(old)
		qdel(old)
	if(same)
		return
	new /datum/stealth_sight_overlay(user, guard)

/**
 * The tiles one guard sees, shown to one admin: green for its lit cone, blue for how far it sees into
 * the dark, yellow for the close radius it feels all round. Rebuilt each scan while watched; ends when
 * the guard dies, on a second toggle, or after STEALTH_ADMIN_OVERLAY_TIME.
 */
/datum/stealth_sight_overlay
	var/datum/weakref/user_ref
	var/datum/weakref/guard_ref
	var/ckey
	var/list/image/images = list()

/datum/stealth_sight_overlay/New(client/user, mob/living/carbon/human/npc/guard)
	user_ref = WEAKREF(user)
	guard_ref = WEAKREF(guard)
	ckey = user.ckey
	GLOB.stealth_sight_overlays[ckey] = src
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	LAZYADD(stealth_ai.watchers, src)
	RegisterSignal(guard, COMSIG_LIVING_DEATH, PROC_REF(on_guard_gone))
	RegisterSignal(guard, COMSIG_QDELETING, PROC_REF(on_guard_gone))
	QDEL_IN(src, STEALTH_ADMIN_OVERLAY_TIME)
	refresh()

/datum/stealth_sight_overlay/Destroy()
	clear()
	if(GLOB.stealth_sight_overlays[ckey] == src)
		GLOB.stealth_sight_overlays -= ckey
	var/mob/living/carbon/human/npc/guard = guard_ref?.resolve()
	if(guard)
		UnregisterSignal(guard, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
		if(istype(stealth_ai))
			LAZYREMOVE(stealth_ai.watchers, src)
	return ..()

/datum/stealth_sight_overlay/proc/on_guard_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/stealth_sight_overlay/proc/clear()
	var/client/user = user_ref?.resolve()
	user?.images -= images
	images.Cut()

/datum/stealth_sight_overlay/proc/refresh()
	clear()
	var/client/user = user_ref?.resolve()
	var/mob/living/carbon/human/npc/guard = guard_ref?.resolve()
	if(isnull(user) || QDELETED(guard))
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	if(!istype(stealth_ai))
		return
	var/turf/center = get_turf(guard)
	if(isnull(center))
		return
	var/eyes = stealth_ai.stealth_eyes_open()
	var/half_angle = stealth_ai.stealth_half_angle()
	var/night = HAS_TRAIT(guard, TRAIT_NIGHT_VISION)
	for(var/turf/tile as anything in RANGE_TURFS(STEALTH_SIGHT_RANGE, center))
		var/dist = get_dist(center, tile)
		var/colour
		if(eyes && stealth_in_cone(guard, tile, half_angle) && can_see(center, tile, STEALTH_SIGHT_RANGE))
			if(dist <= STEALTH_DARK_SIGHT_RANGE || night)
				colour = "#3399ff"
			else
				colour = "#33cc33"
		if(dist <= STEALTH_CLOSE_RANGE)
			colour = colour || "#ffcc00"
		if(isnull(colour))
			continue
		var/image/marker = image('icons/effects/alphacolors.dmi', tile, "white")
		SET_PLANE(marker, ABOVE_LIGHTING_PLANE, tile)
		marker.color = colour
		marker.alpha = 70
		images += marker
	user.images |= images
