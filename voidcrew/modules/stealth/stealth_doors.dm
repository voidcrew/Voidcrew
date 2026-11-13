/**
 * # Stealth guards: doors (owner decision 37)
 *
 * Every door a player opens or shuts makes a small noise (STEALTH_NOISE_DOOR: those who hear it glance), and a
 * guard who sees one move in its cone is suspicious and goes to look. The door's own movement is the cue, so it
 * works without seeing who moved it.
 *
 * Doors: airlocks, windoors, shutters and blast doors (every /obj/machinery/door through tg's run_animation()),
 * and mineral and wooden doors (their Open() and Close()). Firelocks are left out: they move by themselves on
 * every air alarm, and tg plays no sound for them.
 *
 * Their own doors: a door that moves with one of the group beside it is theirs, and so is its next close within
 * STEALTH_DOOR_GUARD_MEMORY (an airlock a guard walked through shuts itself 6 s later, when it is far off).
 *
 * In the dark a guard sees a door move out to its dark sight range, in the light out to its full sight range:
 * a door is no easier to make out in the dark than a person.
 *
 * Throttle: a door that sent someone to look only gets glances for STEALTH_DOOR_CUE_COOLDOWN, and after
 * STEALTH_DOOR_CUE_MAX looks within STEALTH_DOOR_CUE_MEMORY it is ignored for the rest of that time, so a door
 * cycling by itself can't keep a guard walking back and forth. The noise is coalesced as any noise is.
 *
 * Cost: one length() check while no stealth group is alive; otherwise one look per guard of a group on that level.
 */

/datum/stealth_group
	/// REF(door) => world.time one of the group was beside it when it moved
	var/list/door_guard_used = list()
	/// REF(door) => list of world.time it sent someone to look
	var/list/door_cues = list()

// Opening and closing, on every machinery door. Firelocks excepted (see above).
/obj/machinery/door/run_animation(animation, force_type = DEFAULT_DOOR_CHECKS)
	. = ..()
	if(!length(GLOB.stealth_groups) || istype(src, /obj/machinery/door/firedoor))
		return
	if(animation != DOOR_OPENING_ANIMATION && animation != DOOR_CLOSING_ANIMATION)
		return
	// Forced open with a crowbar or the like: that is already a bash (stealth_noise_sources.dm).
	stealth_door_moved(src, animation == DOOR_OPENING_ANIMATION, force_type != BYPASS_DOOR_CHECKS)

/obj/structure/mineral_door/Open()
	if(length(GLOB.stealth_groups) && !door_opened)
		stealth_door_moved(src, TRUE)
	return ..()

/obj/structure/mineral_door/Close()
	// tg's Close() does nothing while it is moving, already shut, or someone stands in the doorway.
	if(length(GLOB.stealth_groups) && !isSwitchingStates && door_opened && !(locate(/mob/living) in get_turf(src)))
		stealth_door_moved(src, FALSE)
	return ..()

/**
 * `door` began to open (`opening`) or close. Its noise (unless `noisy` is off), then the guards that see it.
 * Returns the number of guards sent to look (tests).
 */
/proc/stealth_door_moved(atom/door, opening, noisy = TRUE)
	. = 0
	if(!length(GLOB.stealth_groups))
		return
	var/turf/where = get_turf(door)
	if(isnull(where))
		return
	// Nobody to play for: guards sleep with their level.
	if(where.z > length(SSmobs.clients_by_zlevel) || !length(SSmobs.clients_by_zlevel[where.z]))
		return
	var/key = REF(door)
	for(var/datum/stealth_group/group as anything in GLOB.stealth_groups.Copy())
		if(QDELETED(group) || group.home?.z != where.z || !group.region_matches(where))
			continue
		if(group.door_is_theirs(key, where, opening))
			continue
		if(noisy)
			stealth_noise(door, STEALTH_NOISE_DOOR, null, null, group)
		. += group.door_seen(key, where)

/// Whether a door moving at `where` is one of their own going through: one of them beside it, or the close
/// that follows such an opening. Remembers the opening.
/datum/stealth_group/proc/door_is_theirs(key, turf/where, opening)
	for(var/stamped in door_guard_used)
		if(world.time - door_guard_used[stamped] > STEALTH_DOOR_GUARD_MEMORY)
			door_guard_used -= stamped
	if(member_beside(where, living_members()))
		door_guard_used[key] = world.time
		return TRUE
	if(!opening && door_guard_used[key])
		door_guard_used -= key
		return TRUE
	return FALSE

/**
 * The guards who see a door move at `where`: the nearest one free to look goes (suspicious, as at a sighting),
 * a searching one moves its search there, the rest of the unaware ones glance. Returns how many went.
 */
/datum/stealth_group/proc/door_seen(key, turf/where)
	. = 0
	var/list/stamps = door_cues[key]
	if(stamps)
		for(var/index in length(stamps) to 1 step -1)
			if(world.time - stamps[index] > STEALTH_DOOR_CUE_MEMORY)
				stamps.Cut(index, index + 1)
		if(!length(stamps))
			door_cues -= key
			stamps = null
	var/throttled = length(stamps) && (length(stamps) >= STEALTH_DOOR_CUE_MAX || world.time - stamps[length(stamps)] < STEALTH_DOOR_CUE_COOLDOWN)
	// Nearest first.
	var/list/seers = list()
	for(var/mob/living/carbon/human/npc/guard as anything in living_members())
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		if(!istype(guard_ai) || !guard_ai.stealth_sees_door(where))
			continue
		var/dist = get_dist(guard, where)
		var/index = 1
		while(index <= length(seers) && get_dist(seers[index], where) <= dist)
			index++
		seers.Insert(index, guard)
	var/went = FALSE
	for(var/mob/living/carbon/human/npc/guard as anything in seers)
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		var/turf/spot = stealth_hear_spot(where, get_turf(guard))
		if(!throttled && !went && guard_ai.stealth_can_investigate())
			went = TRUE
			guard_ai.stealth_door_look(spot)
			.++
			continue
		switch(guard_ai.stealth_state())
			if(STEALTH_UNAWARE)
				guard_ai.stealth_glance(spot)
			if(STEALTH_SEARCHING)
				if(!throttled && guard_ai.stealth_respond(spot))
					went = TRUE
					.++
	if(went)
		LAZYADDASSOCLIST(door_cues, key, world.time)

/// Whether it sees a door move at `where` now: awake, its eyes open, not fighting, in its cone, in view, and
/// within its sight range onto that spot (shorter in the dark).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_sees_door(turf/where)
	var/mob/living/guard = pawn
	if(QDELETED(guard) || guard.stat != CONSCIOUS || guard.client || ai_status == AI_STATUS_OFF)
		return FALSE
	if(!isturf(guard.loc) || stealth_captive() || blackboard_key_exists(BB_HUMAN_NPC_EXIT))
		return FALSE
	if(!stealth_ready || stealth_state() == STEALTH_ALERT || !stealth_eyes_open())
		return FALSE
	var/dist = get_dist(guard, where)
	if(dist < 1 || dist > stealth_range_onto(where))
		return FALSE
	if(!stealth_in_cone(guard, where, stealth_half_angle()))
		return FALSE
	return can_see(guard, where, stealth_skill().sight_range)

/// It saw a door move: suspicious of `spot`, the side of the door it is on, as at a sighting. Already
/// suspicious and not yet on its way, it turns there instead.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_door_look(turf/spot)
	if(isnull(spot) || stealth_driven())
		return
	if(stealth_state() == STEALTH_SUSPICIOUS)
		last_gain = world.time
		if(!investigated)
			stealth_aim_at(spot)
		return
	stealth_go_suspicious(spot)
