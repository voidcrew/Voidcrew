/// Backgrounds: owned by P3.

// ===== RECOGNITION [MP-1, MP-2, MP-3] =====
// Who a person is, for the counters and the warrant trade: the mind when the face shows, the ID's name
// only when the face is hidden. Never a crew record and never its wanted status (the HUD can lie).

/// Whether this person's face is hidden (a mask, a helmet, a ruined head)
/proc/background_face_hidden(mob/living/carbon/human/person)
	if(!ishuman(person))
		return FALSE
	// "", not null: a null argument takes the proc's default, "Unknown"
	return !length(person.get_face_name(""))

/// Whether this person shows neither a face nor an ID name: "no face, no papers"
/proc/background_no_papers(mob/living/carbon/human/person)
	if(!background_face_hidden(person))
		return FALSE
	return !length(person.get_id_name(""))

/**
 * The active mind of background `key` (any background when null) that this person is recognised as,
 * or null. A visible face is the person's own mind and nothing else, whatever the card says. A hidden
 * face is whoever the ID names.
 */
/proc/background_recognised_mind(mob/living/carbon/human/person, key)
	if(!ishuman(person))
		return null
	if(!background_face_hidden(person))
		var/datum/mind/mind = person.mind
		var/datum/background_state/state = mind?.background_state
		if(!state || state.ended || (key && state.key != key))
			return null
		return mind
	var/id_name = person.get_id_name("")
	if(!length(id_name))
		return null
	for(var/datum/mind/candidate in background_active_minds(key))
		if(candidate.background_state?.character_name == id_name)
			return candidate
	return null

// ===== LAST SEEN [PERF-3] =====
// A warrant target counts as seen when a Marshal hull's sensors reach the place the target is in:
// its ship, or the planet, ruin or outpost whose interior holds it. Sensors buy reach, not sight, and
// the card keeps the last reading when nothing reaches.

/// "Last seen at <site>", or null
/datum/background_state/proc/last_seen_text()
	if(!last_seen_site_name)
		return null
	return "Last seen at [last_seen_site_name]"

/// The ZONE_* band this state's target was last seen in, or null
/datum/background_state/proc/last_seen_zone()
	return last_seen_zone_value

/**
 * Takes a sensor reading on this state's target, at most once every BACKGROUND_LAST_SEEN_INTERVAL.
 * `watchers` are the hulls looking (every live Marshal hull when null). Returns TRUE if it looked.
 */
/datum/background_state/proc/update_last_seen(list/watchers)
	var/last_check = extra["p3_last_check"]
	if(!isnull(last_check) && world.time - last_check < BACKGROUND_LAST_SEEN_INTERVAL)
		return FALSE
	extra["p3_last_check"] = world.time
	var/datum/mind/mind = mind_ref?.resolve()
	var/obj/structure/overmap/holder = last_seen_holder(mind?.current)
	if(!holder)
		return TRUE
	if(isnull(watchers))
		watchers = background_hunter_hulls()
	for(var/obj/structure/overmap/ship/watcher in watchers)
		if(!background_sensors_reach(watcher, holder))
			continue
		last_seen_site_name = watcher.get_contact_name(holder)
		var/turf/holder_turf = get_turf(holder)
		last_seen_zone_value = holder_turf ? SSovermap_zones.resolve_zone_for_overmap_turf(holder_turf) : null
		last_seen_at = world.time
		break
	return TRUE

/// The overmap object the target's body is in: its ship, else the site whose interior holds it
/datum/background_state/proc/last_seen_holder(atom/body)
	if(!body)
		return null
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(body)
	if(ship)
		return ship
	var/turf/body_turf = get_turf(body)
	if(!body_turf)
		return null
	return SSovermap_zones.get_overmap_object_for_turf(body_turf)

/// Every live hunter hull
/proc/background_hunter_hulls()
	var/list/hulls = list()
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		if(!QDELETED(ship) && ship.background_key() == BACKGROUND_BOUNTY_HUNTER)
			hulls += ship
	return hulls

/// Whether `watcher`'s sensors reach `holder` on the overmap. Vessels need the tracking radar past the view ring, as on the helm.
/proc/background_sensors_reach(obj/structure/overmap/ship/watcher, obj/structure/overmap/holder)
	if(QDELETED(watcher) || QDELETED(holder))
		return FALSE
	if(watcher == holder)
		return TRUE
	var/turf/watcher_turf = get_turf(watcher)
	var/turf/holder_turf = get_turf(holder)
	if(!watcher_turf || !holder_turf || watcher_turf.z != holder_turf.z)
		return FALSE
	var/reach = watcher.get_sensor_range()
	if(istype(holder, /obj/structure/overmap/ship) && !watcher.can_scan_ships())
		reach = SHIP_VIEW_RANGE
	var/dx = overmap_wrapped_delta(holder_turf.x - watcher_turf.x, OVERMAP_SIZE - 2)
	var/dy = overmap_wrapped_delta(holder_turf.y - watcher_turf.y, OVERMAP_SIZE - 2)
	return dx * dx + dy * dy <= reach * reach

// ===== RECORDS [MP-3] =====
// The sec HUD shows a warrant target as wanted. Advisory only: anyone with a records console can
// change it, so pay and recognition never read it; the watch just puts it back.

/// The crew record that belongs to this mind (bound through its locked record), or null. Never a namesake's.
/proc/background_crew_record(datum/mind/mind, record_name)
	if(!mind || !length(record_name) || !GLOB.manifest)
		return null
	for(var/datum/record/locked/lock in GLOB.manifest.locked)
		if(lock.name != record_name || lock.mind_ref?.resolve() != mind)
			continue
		var/lock_id = REF(lock)
		for(var/datum/record/crew/record in GLOB.manifest.general)
			if(record.lock_ref == lock_id)
				return record
	return null

/// Marks this record wanted and refreshes the HUDs that show it. TRUE if it changed.
/proc/background_mark_record(datum/record/crew/record, status)
	if(!record || record.wanted_status == status)
		return FALSE
	record.wanted_status = status
	update_matching_security_huds(record.name)
	return TRUE

// ===== THE WATCH =====

/// Ticks the ever-crew list, last-seen readings and wanted records
GLOBAL_DATUM_INIT(background_hunter_watch, /datum/background_hunter_watch, new)

/datum/background_hunter_watch
	/// Weakrefs to crew records the watch marked wanted, so it can clear them once the warrant closes
	var/list/marked_records = list()
	COOLDOWN_DECLARE(sweep_cooldown)
	COOLDOWN_DECLARE(record_cooldown)

/datum/background_hunter_watch/New()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_CREWMEMBER_JOINED, PROC_REF(on_crewmember_joined))
	START_PROCESSING(SSprocessing, src)

/datum/background_hunter_watch/process(seconds_per_tick)
	if(COOLDOWN_FINISHED(src, sweep_cooldown))
		COOLDOWN_START(src, sweep_cooldown, BACKGROUND_LAST_SEEN_INTERVAL)
		sweep()
	if(COOLDOWN_FINISHED(src, record_cooldown))
		COOLDOWN_START(src, record_cooldown, BACKGROUND_RECORD_REASSERT)
		reassert_records(warrant_targets())

/// A character joined: the hull they arrived on keeps their ckey
/datum/background_hunter_watch/proc/on_crewmember_joined(datum/source, mob/living/character, rank)
	SIGNAL_HANDLER
	if(!character?.ckey)
		return
	background_note_ever_crew(get_ship_from_atom(character), character.ckey)

/// Convict and pirate minds still playing their background
/datum/background_hunter_watch/proc/watched_minds()
	return background_active_minds(BACKGROUND_CONVICT) + background_active_minds(BACKGROUND_PIRATE)

/// Watched minds with an open warrant
/datum/background_hunter_watch/proc/warrant_targets()
	var/list/targets = list()
	for(var/datum/mind/mind in watched_minds())
		if(background_warrant_for_mind(mind))
			targets += mind
	return targets

/// Every BACKGROUND_LAST_SEEN_INTERVAL: rosters into the ever-crew lists, free convicts and pirates aboard a hull, sensor readings
/datum/background_hunter_watch/proc/sweep()
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		note_roster(ship)
	var/list/hulls = background_hunter_hulls()
	for(var/datum/mind/mind in watched_minds())
		note_if_aboard(mind)
		if(background_warrant_for_mind(mind))
			mind.background_state?.update_last_seen(hulls)

/// Everyone on this hull's roster goes on its ever-crew list
/datum/background_hunter_watch/proc/note_roster(obj/structure/overmap/ship/ship)
	if(QDELETED(ship) || !ship.ship_team)
		return
	for(var/datum/mind/member in ship.ship_team.members)
		background_note_ever_crew(ship, member.key)

/// Where a convict or pirate is, for the ever-crew list
/datum/background_hunter_watch/proc/note_if_aboard(datum/mind/mind)
	var/mob/living/body = mind?.current
	note_aboard(mind, body ? get_ship_from_atom(body) : null)

/**
 * A convict or pirate standing free on a hull goes on its ever-crew list. One the hull brought aboard
 * downed or cuffed is its prisoner until he leaves it: a captive let out of his cuffs in a cell, or one
 * who breaks out, is still theirs to turn in.
 */
/datum/background_hunter_watch/proc/note_aboard(datum/mind/mind, obj/structure/overmap/ship/aboard)
	var/datum/background_state/state = mind?.background_state
	if(!state)
		return
	if(QDELETED(aboard))
		state.extra -= "p3_held_by"
		return
	if(!background_is_free(mind.current))
		state.extra["p3_held_by"] = WEAKREF(aboard)
		return
	var/datum/weakref/held_by = state.extra["p3_held_by"]
	if(held_by?.resolve() == aboard)
		return
	background_note_ever_crew(aboard, mind.key)

/// Marks every target's own record wanted, and clears the mark from records whose warrant has closed
/datum/background_hunter_watch/proc/reassert_records(list/targets)
	var/list/still_wanted = list()
	for(var/datum/mind/mind in targets)
		var/datum/record/crew/record = background_crew_record(mind, mind.background_state?.character_name)
		if(!record)
			continue
		still_wanted[record] = TRUE
		background_mark_record(record, WANTED_ARREST)
		var/datum/criminal_bounty/warrant/warrant = background_warrant_for_mind(mind)
		if(warrant)
			RegisterSignal(warrant, COMSIG_BOUNTY_POSTING_CLOSED, PROC_REF(on_warrant_closed), override = TRUE)
		var/datum/weakref/record_ref = WEAKREF(record)
		if(!(record_ref in marked_records))
			marked_records += record_ref
	for(var/datum/weakref/record_ref as anything in marked_records.Copy())
		var/datum/record/crew/record = record_ref.resolve()
		if(record && still_wanted[record])
			continue
		marked_records -= record_ref
		// Captured (Incarcerated) or edited by hand: not ours to touch
		if(record?.wanted_status == WANTED_ARREST)
			background_mark_record(record, WANTED_NONE)

/// A warrant closed: clear its target's record on the next tick instead of waiting out the re-assert interval
/datum/background_hunter_watch/proc/on_warrant_closed(datum/criminal_bounty/warrant/source, reason, winner)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_BOUNTY_POSTING_CLOSED)
	COOLDOWN_RESET(src, record_cooldown)
