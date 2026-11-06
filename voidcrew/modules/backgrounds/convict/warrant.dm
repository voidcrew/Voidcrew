/**
 * # Warrants
 *
 * A hunter-only posting on a player: a convict, or a pirate. A /datum/criminal_bounty subtype for
 * the card, the printed warrant and the turn-in, but held in GLOB.background_warrants alone, never
 * in GLOB.criminal_bounties: nothing ticks it, no public cap counts it and the concourse board
 * never lists it. It never spawns anything, never touches a body on closing and never
 * enters the prisoner pool.
 *
 * Value grows with time at large, from a quarter at posting to the full value after
 * BACKGROUND_WARRANT_FULL_TIME, in the zone fixed at posting; the crime moves it a tenth either way.
 * Each new life of a convict or pirate opens a new warrant, closing the old, until someone
 * has been paid for that ckey this round. Pay never reads wanted_status.
 */

/// Every warrant this round. Never in GLOB.criminal_bounties.
GLOBAL_LIST_EMPTY(background_warrants)

/datum/criminal_bounty/warrant
	board_vouchers = 0
	expires_at = INFINITY
	/// The mind it is for
	var/datum/weakref/target_mind
	var/target_ckey
	/// BACKGROUND_CONVICT or BACKGROUND_PIRATE
	var/kind
	/// world.time it was posted; its value grows from here
	var/posted_at = 0
	/// The zone band its value is fixed in: the Penitentiary's for convicts, the hull's for pirates
	var/posted_zone = ZONE_YELLOW
	/// Crime tier, 1 to 3
	var/tier = BOUNTY_TIER_WANTED

/datum/criminal_bounty/warrant/New(datum/mind/target, kind)
	. = ..()
	src.kind = kind
	posted_at = world.time
	board_posted_at = world.time
	if(target)
		target_mind = WEAKREF(target)
		target_ckey = target.key ? ckey(target.key) : null
		posted_zone = background_warrant_zone(target, kind)
		record = background_warrant_record(target, kind)
		tier = clamp(record?.tier || BOUNTY_TIER_WANTED, BOUNTY_TIER_PETTY, BOUNTY_TIER_MOST_WANTED)
	board_zone = posted_zone
	update_value()
	GLOB.background_warrants += src

/datum/criminal_bounty/warrant/Destroy()
	GLOB.background_warrants -= src
	var/datum/mind/mind = target_mind?.resolve()
	if(mind?.background_state?.warrant_ref?.resolve() == src)
		mind.background_state.warrant_ref = null
	target_mind = null
	return ..()

/// The mind it is for, if it still exists
/datum/criminal_bounty/warrant/proc/target()
	return target_mind?.resolve()

/// The value it pays at full share right now
/datum/criminal_bounty/warrant/proc/current_value()
	var/elapsed = max(0, world.time - posted_at)
	var/time_share = BACKGROUND_WARRANT_FRESH_SHARE + (1 - BACKGROUND_WARRANT_FRESH_SHARE) * min(1, elapsed / BACKGROUND_WARRANT_FULL_TIME)
	var/tier_mult = 1 + (clamp(tier, BOUNTY_TIER_PETTY, BOUNTY_TIER_MOST_WANTED) - BOUNTY_TIER_WANTED) * BACKGROUND_WARRANT_TIER_SWING
	return round(BACKGROUND_WARRANT_BASE * SScriminal_bounties.board_zone_mult(posted_zone) * time_share * tier_mult, 10)

/datum/criminal_bounty/warrant/proc/update_value()
	value = current_value()
	return value

// ===== THE BOARD'S PROCS: a warrant does none of the posting's work =====

/datum/criminal_bounty/warrant/close(reason, obj/structure/overmap/ship/winner)
	GLOB.background_warrants -= src
	return ..()

/datum/criminal_bounty/warrant/board_arm()
	return FALSE

/datum/criminal_bounty/warrant/board_process(elapsed)
	if(is_open())
		update_value()

/datum/criminal_bounty/warrant/relist(reason)
	return FALSE

/datum/criminal_bounty/warrant/board_check_unreachable()
	return FALSE

/datum/criminal_bounty/warrant/board_move_sighting(force = FALSE)
	return

/// Never on an ordinary board; the warrant console lists warrants itself
/datum/criminal_bounty/warrant/board_visible_to(obj/structure/overmap/ship/ship)
	return FALSE

/datum/criminal_bounty/warrant/board_terms()
	return "Wanted alive"

/datum/criminal_bounty/warrant/board_time_left()
	return 0

/// Its target's state, if the mind and state still exist
/datum/criminal_bounty/warrant/proc/target_state()
	RETURN_TYPE(/datum/background_state)
	var/datum/mind/mind = target()
	return mind?.background_state

/datum/criminal_bounty/warrant/board_place_text()
	return target_state()?.last_seen_text()

/datum/criminal_bounty/warrant/board_zone_name()
	switch(target_state()?.last_seen_zone())
		if(ZONE_GREEN)
			return ZONE_NAME_GREEN
		if(ZONE_YELLOW)
			return ZONE_NAME_YELLOW
		if(ZONE_RED)
			return ZONE_NAME_RED
	return "Unknown Zone"

/datum/criminal_bounty/warrant/board_zone_color()
	switch(target_state()?.last_seen_zone())
		if(ZONE_GREEN)
			return "good"
		if(ZONE_YELLOW)
			return "average"
		if(ZONE_RED)
			return "bad"
	return "label"

/// Charts the last site the target was seen at, if there is one
/datum/criminal_bounty/warrant/board_push_waypoint(obj/structure/overmap/ship/ship)
	var/datum/background_state/state = target_state()
	if(!ship || !state?.last_seen_site_name)
		return FALSE
	for(var/obj/structure/overmap/where as anything in GLOB.overmap_objects)
		if(QDELETED(where) || where.name != state.last_seen_site_name)
			continue
		var/list/coords = where.get_relative_overmap_coords()
		if(!coords)
			return FALSE
		ship.add_waypoint(board_waypoint_key(), "Wanted: [record?.name || "fugitive"]", coords[1], coords[2], "Bounties", where)
		return TRUE
	return FALSE

/// A warrant never removes a body, a companion or a decoy: there are none, and the target is a player
/datum/criminal_bounty/warrant/board_remove_mobs(reason, relisting = FALSE)
	return

/datum/criminal_bounty/warrant/board_ui_entry(obj/structure/overmap/ship/ship, obj/machinery/mission_pad/pad)
	update_value()
	var/list/entry = ..()
	entry["warrant"] = 1
	entry["alias"] = null
	entry["tier"] = tier
	entry["vouchers"] = 0
	entry["private"] = 0
	entry["photo_old"] = 0
	entry -= "time_left"
	return entry

/datum/criminal_bounty/warrant/board_log_name()
	return "[kind] warrant on [record?.name || "nobody"] ([target_ckey || "no ckey"])"

// ===== THE PAD =====

/// The target's current body, if it is a human
/datum/criminal_bounty/warrant/proc/target_body()
	var/datum/mind/mind = target()
	var/mob/living/carbon/human/body = mind?.current
	return (istype(body) && !QDELETED(body)) ? body : null

/datum/criminal_bounty/warrant/board_target_on_pad(obj/machinery/mission_pad/pad)
	if(!pad || !isturf(pad.loc))
		return null
	var/mob/living/carbon/human/body = target_body()
	return (body && body.loc == pad.loc) ? body : null

/// Why `ship`'s crew may not turn this one in: the target is one of them, or ever was
/datum/criminal_bounty/warrant/proc/warrant_crew_refusal(obj/structure/overmap/ship/ship)
	if(!ship)
		return null
	var/datum/mind/mind = target()
	if(mind && (mind in ship.ship_team?.members))
		return "they're one of your crew"
	if(target_ckey && length(ship.background_ever_crew) && (target_ckey in ship.background_ever_crew))
		return "they're one of your crew"
	return null

/**
 * The capture state a body pays on: dead, or without a player behind it, the dead share;
 * in crit or knocked out by their wounds, downed; cuffed, stunned, knocked down, out of breath or
 * asleep, the full share; otherwise standing free.
 */
/datum/criminal_bounty/warrant/proc/warrant_capture_state(mob/living/carbon/human/body)
	if(!body || body.stat == DEAD)
		return BOUNTY_STATE_DEAD
	if(!body.client)
		return BOUNTY_STATE_DEAD
	if(body.stat == SOFT_CRIT || body.stat == HARD_CRIT || (body.stat == UNCONSCIOUS && body.health <= body.crit_threshold))
		return BOUNTY_STATE_DOWNED
	if(body.handcuffed)
		return BOUNTY_STATE_RESTRAINED
	if(body.stat == UNCONSCIOUS || body.has_status_effect(/datum/status_effect/incapacitating/stamcrit) || body.IsKnockdown() || body.IsStun() || body.IsParalyzed())
		return BOUNTY_STATE_STUNNED
	return BOUNTY_STATE_FREE

/datum/criminal_bounty/warrant/board_target_refusal(obj/machinery/mission_pad/pad, list/found)
	var/mob/living/carbon/human/body = board_target_on_pad(pad)
	if(!body)
		return "nothing on the pad for this bounty"
	var/refusal = warrant_crew_refusal(get_ship_from_atom(pad))
	if(refusal)
		return refusal
	var/state = warrant_capture_state(body)
	if(!bounty_state_share(state))
		return "they're standing free"
	found["target"] = body
	found["state"] = state
	return null

/datum/criminal_bounty/warrant/board_pad_preview(obj/structure/overmap/ship/ship, obj/machinery/mission_pad/pad)
	if(!is_open())
		return list(FALSE, null, "that bounty is closed")
	if(!pad || QDELETED(pad))
		return list(FALSE, null, "no mission pad linked")
	var/mob/living/carbon/human/body = board_target_on_pad(pad)
	var/state = body ? warrant_capture_state(body) : null
	var/refusal = board_target_refusal(pad, list()) || pad.bounty_turn_in_refusal(ship)
	return list(!refusal, state, refusal)

/datum/criminal_bounty/warrant/board_claim(obj/structure/overmap/ship/ship, obj/machinery/mission_pad/pad, atom/movable/target, state, mob/user)
	if(!is_open())
		return "that bounty is closed"
	var/mob/living/carbon/human/body = target
	if(!istype(body) || QDELETED(body) || QDELETED(ship))
		return "nothing on the pad for this bounty"
	return claim_body(body, ship, pad, state, user)

/**
 * Pays `ship` for `body` in `state` and hands them to the Meridian: a capture cell, or the morgue.
 * Once only. The body is moved, never deleted. Returns list(credits, 0), or why not. Never yields.
 */
/datum/criminal_bounty/warrant/proc/claim_body(mob/living/carbon/human/body, obj/structure/overmap/ship/ship, obj/machinery/mission_pad/pad, state, mob/user)
	if(!is_open())
		return "that bounty is closed"
	if(!istype(body) || QDELETED(body) || QDELETED(ship))
		return "nothing on the pad for this bounty"
	if(body != target_body())
		return "nothing on the pad for this bounty"
	var/share = bounty_state_share(state)
	if(!share)
		return "they're standing free"
	update_value()
	var/list/pay = board_payout(share)
	var/wanted_name = record?.name || body.real_name
	var/minutes = round(max(0, world.time - posted_at) / (1 MINUTES))
	var/words = (body.stat != DEAD && !body.client) ? "out cold" : bounty_state_words(state)
	var/hunter_ckey = user?.ckey
	var/turf/pad_turf = get_turf(pad || body)
	if(!penitentiary_take_prisoner(body, ship))
		return "the Meridian won't take them"
	bounty_pay_ship(ship, pad, pay[1], 0)
	SEND_SIGNAL(ship, COMSIG_BACKGROUND_BOUNTY_PAID, "warrant")
	if(target_ckey)
		var/list/ledger = convict_ledger(target_ckey)
		ledger["paid"] = TRUE
	close(BOUNTY_CLOSE_CLAIMED, ship)
	ship.ship_notify("WARRANT: [wanted_name] handed to Meridian, [words]. Paid [pay[1]] credits.", "BOUNTY COMPLETE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	record_metric(METRIC_BACKGROUND, "warrant_paid", ckey = hunter_ckey, other_ckey = target_ckey, ship = ship, subject = kind, credits = pay[1], details = list("minutes_at_large" = minutes, "state" = state))
	log_game("BACKGROUNDS: [ship.name] turned in the [kind] warrant on [wanted_name] ([target_ckey]) [state] after [minutes] min at [AREACOORD(pad_turf)] for [pay[1]] cr[user ? ", pressed by [key_name(user)]" : ""]")
	return pay

// ===== MINTING AND CLOSING =====

/// The zone band a new warrant on `target` is fixed in
/proc/background_warrant_zone(datum/mind/target, kind)
	if(kind == BACKGROUND_PIRATE)
		var/obj/structure/overmap/ship/hull = target?.current ? get_ship_from_atom(target.current) : null
		var/turf/overmap_turf = get_turf(hull)
		if(overmap_turf)
			return SSovermap.get_zone_band_for_turf(overmap_turf)
		return ZONE_YELLOW
	var/turf/site_turf = get_turf(GLOB.penitentiary)
	return site_turf ? SSovermap.get_zone_band_for_turf(site_turf) : ZONE_YELLOW

/// A bounty record built from the target's body as it is now, with its crew photo for the mugshot
/proc/background_warrant_record(datum/mind/target, kind)
	var/datum/bounty_record/record = new
	var/mob/living/carbon/human/body = target?.current
	var/datum/background_state/state = target?.background_state
	record.name = body?.real_name || state?.character_name || target?.name
	record.alias = null
	record.gender = body?.gender
	record.species = ishuman(body) ? body.dna?.species?.type : null
	record.crime = kind == BACKGROUND_PIRATE ? "Piracy" : (state?.crime || "Escape")
	record.tier = clamp(state?.crime_tier || BOUNTY_TIER_WANTED, BOUNTY_TIER_PETTY, BOUNTY_TIER_MOST_WANTED)
	record.status = BOUNTY_RECORD_WANTED
	record.mugshot = background_warrant_mugshot(body)
	return record

/// The body's crew-record front photo as base64, or a flat portrait of the body itself
/proc/background_warrant_mugshot(mob/living/carbon/human/body)
	if(!ishuman(body))
		return null
	var/icon/picture
	var/datum/record/crew/crew_record = find_record(body.real_name)
	if(crew_record)
		var/obj/item/photo/photo = crew_record.get_front_photo()
		if(istype(photo))
			picture = photo.picture?.picture_image
	if(!picture)
		picture = getFlatIcon(body, SOUTH, no_anim = TRUE)
	return picture ? icon2base64(picture) : null

/// Opens a warrant on this mind (BACKGROUND_CONVICT or BACKGROUND_PIRATE). Returns it, or null.
/proc/background_mint_warrant(datum/mind/target, kind)
	if(!target || !(kind in list(BACKGROUND_CONVICT, BACKGROUND_PIRATE)))
		return null
	var/target_ckey = target.key ? ckey(target.key) : null
	if(target_ckey)
		var/list/ledger = convict_ledger(target_ckey)
		if(ledger["paid"])
			return null
	for(var/datum/criminal_bounty/warrant/old in GLOB.background_warrants.Copy())
		if(old.target() == target || (target_ckey && old.target_ckey == target_ckey))
			old.close(BOUNTY_CLOSE_ADMIN)
	var/datum/criminal_bounty/warrant/warrant = new(target, kind)
	if(target.background_state)
		target.background_state.warrant_ref = WEAKREF(warrant)
	record_metric(METRIC_BACKGROUND, "warrant_minted", ckey = target_ckey, ship = null, subject = kind, details = list("zone" = warrant.posted_zone, "tier" = warrant.tier))
	log_game("BACKGROUNDS: [warrant.board_log_name()] opened, [warrant.value] cr now")
	return warrant

/// Closes this mind's open warrant
/proc/background_close_warrant(datum/mind/target, reason)
	var/datum/criminal_bounty/warrant/warrant = background_warrant_for_mind(target)
	if(!warrant)
		return
	log_game("BACKGROUNDS: [warrant.board_log_name()] closed ([reason || "no reason"])")
	warrant.close(BOUNTY_CLOSE_ADMIN)

/// This mind's open warrant, or null
/proc/background_warrant_for_mind(datum/mind/target)
	if(!target)
		return null
	for(var/datum/criminal_bounty/warrant/warrant in GLOB.background_warrants)
		if(warrant.is_open() && warrant.target() == target)
			return warrant
	return null

/// The open warrant whose target's current body is this one, or null
/proc/background_warrant_for_body(mob/living/carbon/human/body)
	if(!ishuman(body) || !body.mind)
		return null
	var/datum/criminal_bounty/warrant/warrant = background_warrant_for_mind(body.mind)
	return (warrant && warrant.target_body() == body) ? warrant : null
