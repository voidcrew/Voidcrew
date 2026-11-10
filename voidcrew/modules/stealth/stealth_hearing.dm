/**
 * # Stealth guards: what a guard does about what it hears
 *
 * The group decides who goes (stealth_noise.dm); these are the things one guard can be told to do, the
 * shout that passes first-hand knowledge on by earshot, and the footsteps its own scan listens for.
 *
 * - stealth_go_heard(): suspicious of a noise. The same stare, walk over and look round as a sighting, with
 *   a heard line and the grey "?" (stealth_meter.dm). It never makes a guard wary by itself.
 * - stealth_glance(): turns to face a noise for a moment without leaving its state, route or post.
 * - stealth_hold(): stays where it is, wary, facing the noise.
 * - stealth_respond(): runs to a spot and searches there (an alarm, a shout, a radio call, a missing friend).
 * - stealth_shout(): calls for help. Only for what it learned first hand: a guard that came because of a
 *   shout or a call never shouts onward, so one sighting can't chain the whole den awake.
 *
 * Footsteps (owner decision 13) follow tg's own rules: walking is silent, running is heard, and anything
 * that silences a player's steps for players silences them for guards (stealth_footstep_reach()). They are
 * pulled by the guard's scan, so a walker pays nothing per step. Steps alone can make a guard turn and
 * look, never alert.
 */
/datum/ai_controller/basic_controller/human_npc/stealth
	/// Suspicious because of a noise, not a sighting: it shows the grey "?"
	var/suspicion_heard = FALSE
	/// world.time its glance at a noise ends
	var/glance_until = 0
	/// The way it glances
	var/glance_dir = SOUTH
	/// REF(mob) => the turf it stood on at the last scan, for everyone in earshot of a footstep
	var/list/heard_map
	/// REF(mob) => TRUE for everyone whose steps it heard this scan (their notice doesn't decay)
	var/list/heard_now
	/// Its radio call on the way out: list(kind, turf, world.time due, name), or null
	var/list/pending_call
	/// world.time it may next shout for help
	var/next_shout = 0
	/// world.time its search may next move to a newer noise
	var/next_recentre = 0
	/// list(noise kind, world.time) of the last thing it heard, for admins
	var/list/last_heard

/// Whether it can be sent to look at a noise: unaware, or suspicious and not yet on its way.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_can_investigate()
	switch(stealth_state())
		if(STEALTH_UNAWARE)
			return TRUE
		if(STEALTH_SUSPICIOUS)
			return !investigated && isnull(goto_dest) && goto_purpose != STEALTH_GOTO_BODY
	return FALSE

/// Heard something worth a look at `where`. Suspicious with the heard flag set: same stare, walk and look
/// round as a sighting, a heard line instead of "Hm?", and the heard mark. Already suspicious, it re-aims.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_go_heard(turf/where, again = FALSE)
	var/turf/spot = stealth_hear_spot(where, get_turf(pawn))
	if(isnull(spot) || stealth_driven())
		return
	if(stealth_state() == STEALTH_SUSPICIOUS)
		last_gain = world.time
		if(!investigated)
			stealth_aim_at(spot)
		return
	stealth_go_suspicious(spot, STEALTH_GOTO_INVESTIGATE, again ? STEALTH_BARK_HEARD_AGAIN : STEALTH_BARK_HEARD)
	suspicion_heard = TRUE
	stealth_meter_update()

/// Turns to face `where` for `time` without leaving its state, route or post. No line: the turn is the read.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_glance(turf/where, time = STEALTH_GLANCE_TIME)
	var/mob/living/guard = pawn
	if(isnull(where) || stealth_driven() || get_turf(guard) == where)
		return
	glance_dir = stealth_dir_to(guard, where)
	glance_until = max(glance_until, world.time + time)
	if(stealth_state() == STEALTH_UNAWARE && !blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		stealth_drop_walk()
		guard.setDir(glance_dir)

/// Stays where it is, wary, facing `where` (sentries, and guards past the responder cap).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_hold(turf/where)
	if(stealth_driven())
		return
	stealth_set_wary()
	if(stealth_state() != STEALTH_UNAWARE)
		return
	stealth_glance(where, STEALTH_HOLD_TIME)
	stealth_bark(STEALTH_BARK_HOLD)

/**
 * Runs to `where` and searches there: an alarm, a friend's shout, a radio call, a missing friend. Wary.
 * Not while it fights. Already searching, it moves its search there only if that is somewhere else, and at
 * most once per STEALTH_RECENTRE_COOLDOWN. Returns TRUE if it is now searching at or near `where`.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_respond(turf/where)
	var/mob/living/guard = pawn
	if(isnull(where) || QDELETED(guard) || guard.stat != CONSCIOUS || stealth_driven())
		return FALSE
	if(stealth_state() == STEALTH_ALERT || blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return FALSE
	var/turf/spot = stealth_hear_spot(where, get_turf(guard))
	if(stealth_state() == STEALTH_SEARCHING && !calm_until)
		if(search_center && get_dist(search_center, spot) <= STEALTH_SEARCH_RADIUS)
			return TRUE
		if(world.time < next_recentre)
			return FALSE
	next_recentre = world.time + STEALTH_RECENTRE_COOLDOWN
	stealth_go_searching(spot)
	return TRUE

/// Calls for help: a noise its own group hears. It has to be able to speak (tg's can_speak()), so a muted
/// or muzzled guard calls nobody. At most once per STEALTH_SHOUT_INTERVAL.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_shout()
	var/mob/living/guard = pawn
	if(world.time < next_shout || QDELETED(guard) || stealth_driven() || !human_npc_can_talk(guard))
		return FALSE
	next_shout = world.time + STEALTH_SHOUT_INTERVAL
	stealth_noise(guard, STEALTH_NOISE_SHOUT, null, guard)
	return TRUE

/// It has just learned something first hand at `where` (a sighting, a touch, a hit from nowhere, a body):
/// it shouts, and calls it in if it carries a radio.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_first_hand(turf/where)
	var/mob/living/carbon/human/npc/guard = pawn
	if(QDELETED(guard) || guard.stat != CONSCIOUS || stealth_driven() || !stealth_ready)
		return
	stealth_shout()
	if(ishumannpc(guard) && guard.stealth_radio)
		stealth_start_call(STEALTH_CALL_ALARM, where || get_turf(guard))

// ===== Footsteps =====

/**
 * How far `walker`'s last step carried to a guard, in tiles, by tg's own footstep rules (the footstep
 * element's prepare_step() and play_humanstep()). 0 for silent: walking, silent shoes or any other source of
 * TRAIT_SILENT_FOOTSTEPS, in a box, a locker or a mech, buckled, thrown, flying, crawling in a vent, held
 * still, or on a turf with no footstep sound.
 *
 * A running step on plain floor in shoes carries STEALTH_FOOTSTEP_RANGE. Any other floor or footwear scales
 * that by how far tg plays its sound to players compared with the plain one (tg's own tables: plating and
 * wood ring a little further, bare feet on carpet and the Light Step quirk a little less). A living mob that
 * is not a carbon counts as running whenever it moves.
 */
/proc/stealth_footstep_reach(mob/living/walker)
	if(SHOULD_DISABLE_FOOTSTEPS(walker))
		return 0
	var/turf/open/ground = walker.loc
	if(!istype(ground) || isnull(ground.footstep))
		return 0
	if(walker.buckled || walker.throwing || (walker.movement_type & (VENTCRAWLING | FLYING)) || HAS_TRAIT(walker, TRAIT_IMMOBILIZED))
		return 0
	if(walker.body_position == LYING_DOWN)
		return STEALTH_FOOTSTEP_CRAWL_RANGE
	if(!iscarbon(walker))
		return STEALTH_FOOTSTEP_RANGE
	if(walker.move_intent == MOVE_INTENT_WALK)
		return 0
	if(!ishuman(walker))
		return STEALTH_FOOTSTEP_RANGE
	var/mob/living/carbon/human/person = walker
	// The sound tg plays for this floor and what is on its feet: list(sounds, volume, extra range).
	var/list/step_sound
	if((person.wear_suit?.body_parts_covered | person.w_uniform?.body_parts_covered | person.shoes?.body_parts_covered) & FEET)
		step_sound = GLOB.footstep[ground.footstep]
	else
		var/obj/item/bodypart/leg/leg = person.get_bodypart(BODY_ZONE_R_LEG) || person.get_bodypart(BODY_ZONE_L_LEG)
		switch(leg?.footstep_type)
			if(FOOTSTEP_MOB_CLAW)
				step_sound = GLOB.clawfootstep[ground.clawfootstep]
			if(FOOTSTEP_MOB_BAREFOOT)
				step_sound = GLOB.barefootstep[ground.barefootstep]
			if(FOOTSTEP_MOB_HEAVY)
				step_sound = GLOB.heavyfootstep[ground.heavyfootstep]
			if(FOOTSTEP_MOB_SHOE)
				step_sound = GLOB.footstep[ground.footstep]
	if(length(step_sound) < 3)
		return 0
	var/volume = step_sound[2]
	// The human footstep element plays at -6 range (human.dm).
	var/sound_range = SOUND_RANGE + step_sound[3] - 6
	if(HAS_TRAIT(person, TRAIT_LIGHT_STEP))
		volume *= 0.6
		sound_range -= 2
	if(volume <= SOUND_AUDIBLE_VOLUME_MIN || sound_range <= 1)
		return 0
	var/audible = CALCULATE_MAX_SOUND_AUDIBLE_DISTANCE(volume, sound_range, 1, SOUND_FALLOFF_EXPONENT)
	return clamp(round(STEALTH_FOOTSTEP_RANGE * audible / STEALTH_FOOTSTEP_PLAYER_RANGE, 1), 0, STEALTH_FOOTSTEP_MAX_RANGE)

/**
 * The scan's ear for footsteps, before it looks. Everyone near whose turf changed since the last scan and
 * whose step carries this far (walls and doors muffle it) is heard: no line of sight needed.
 * - Unaware or suspicious: their notice gains STEALTH_FOOTSTEP_NOTICE, never past STEALTH_SUSPICIOUS_AT; at
 *   its shoulder it jumps there at once. At that level it turns to the steps and goes to look. From there
 *   sight decides: steps alone never make it alert.
 * - Searching: the search moves to the steps. Someone hunted who runs is followed by ear; one who walks isn't.
 * Footsteps are its own senses, not a dispatch: they open no check and count as no lure.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_hear_footsteps()
	heard_now = null
	var/mob/living/carbon/human/guard = pawn
	var/state = stealth_state()
	if(state == STEALTH_ALERT || !isturf(guard.loc) || !guard.can_hear())
		heard_map = null
		return
	var/turf/here = guard.loc
	var/list/was = heard_map
	var/list/now = list()
	var/list/notice = notice_map
	for(var/mob/living/walker as anything in stealth_candidates(guard, STEALTH_FOOTSTEP_MAX_RANGE))
		var/key = REF(walker)
		var/turf/where = get_turf(walker)
		now[key] = where
		var/turf/stood = was?[key]
		if(isnull(stood) || stood == where)
			continue
		var/reach = stealth_footstep_reach(walker)
		if(!reach || get_dist(here, where) > reach || stealth_muffled_dist(where, here) > reach)
			continue
		LAZYSET(heard_now, key, TRUE)
		last_heard = list("footsteps", world.time)
		if(state == STEALTH_SEARCHING)
			if(!calm_until && world.time >= next_recentre && get_dist(search_center, where) > 1)
				next_recentre = world.time + STEALTH_RECENTRE_COOLDOWN
				stealth_go_searching(where)
				state = stealth_state()
			continue
		var/list/entry = notice[key]
		if(isnull(entry))
			entry = list(0, where, 0)
			notice[key] = entry
		if(entry[STEALTH_ENTRY_NOTICE] < STEALTH_SUSPICIOUS_AT)
			var/gained = get_dist(here, where) <= STEALTH_CLOSE_RANGE ? STEALTH_SUSPICIOUS_AT : entry[STEALTH_ENTRY_NOTICE] + STEALTH_FOOTSTEP_NOTICE
			entry[STEALTH_ENTRY_NOTICE] = min(gained, STEALTH_SUSPICIOUS_AT)
		entry[STEALTH_ENTRY_SEEN_AT] = world.time
		if(blackboard[BB_STEALTH_WARY])
			wary_at = world.time
		if(entry[STEALTH_ENTRY_NOTICE] >= STEALTH_SUSPICIOUS_AT)
			stealth_go_heard(where)
			if(state == STEALTH_SUSPICIOUS && investigated && where != here)
				// Looking round already: it turns to the steps.
				stand_dir = stealth_dir_to(guard, where)
				guard.setDir(stand_dir)
			state = stealth_state()
	heard_map = now
