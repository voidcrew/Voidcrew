/**
 * Base types for voidcrew dynamic events.
 *
 * TG's random events assume a single station z-level; voidcrew has none of that.
 * Ships are shuttles whose areas migrate between shared z-levels (transit space,
 * planets, ruins, outposts), so every ported event is scoped to ONE target ship's
 * shuttle areas, never to a z-level. Trader outposts, ruins and bystander ships
 * are structurally untouchable because events only ever resolve locations through
 * the target ship's area list.
 *
 * Ported events are standalone subtypes (/datum/round_event_control/voidcrew/foo
 * + /datum/round_event/voidcrew/foo) that copy-adapt the TG event logic. The TG
 * originals stay untouched and disabled (allow_random_events remains FALSE);
 * scheduling is handled by SSdynamic_events instead of SSevents.
 */
/datum/round_event_control/voidcrew
	/// How this event selects its victims (EVENT_SCOPE_SHIP or EVENT_SCOPE_GALAXY).
	var/event_scope = EVENT_SCOPE_SHIP
	/// Minimum living, client-connected players physically aboard for a ship to be targetable.
	var/min_crew_aboard = 1
	/// Minimum hull size a target ship must have, one of the SHIP_MASS_* bands.
	///
	/// This is the size gate, and it is a separate question from min_crew_aboard: a full
	/// crew aboard a tiny hull is still a tiny hull, and the crew count says nothing about
	/// whether there is a second compartment to run to. Destructive events set this so they
	/// leave the small hulls alone. A Pill-class is three tiles with no airlock and no
	/// medbay; a supply pod, a vortex anomaly or a boarding party is not an event there,
	/// it is the end of the round for all four people aboard before they can react.
	///
	/// Ships whose mass has not been calculated read as 0 and fail every band above
	/// SHIP_MASS_ANY. That is the safe direction to fail.
	var/min_ship_mass = SHIP_MASS_ANY
	/// Zone bands (ZONE_GREEN/ZONE_YELLOW/ZONE_RED) the target ship must be in. Null = any zone.
	/// Use this to keep dangerous events out of the safe outer ring.
	var/list/allowed_zones = null
	/// If TRUE the target must be flying free on the overmap, for events that make no sense while landed or docked.
	var/requires_flying = FALSE
	/// If TRUE this event may hit ships docked at a trader outpost. Defaults off: outposts are safe harbors.
	var/allow_in_safe_harbor = FALSE
	/// If TRUE the target must be somewhere its own deck plating is the only thing holding
	/// the crew down, free space, or docked at a wreck or another ship. A ship sitting on
	/// a planet surface or in an outpost hangar stands in that location's gravity
	/// (has_ambient_gravity()), so an event that cuts ship gravity there would float a crew
	/// that is, visibly, parked on solid ground.
	var/requires_zero_g = FALSE
	/// If TRUE this event ignores the per-ship DYNAMIC_EVENT_SHIP_COOLDOWN when picking a
	/// target. Reserved for events belonging to a driven pressure system with its own
	/// cadence, the lich's rituals (voidcrew/modules/lich/) are the reason this exists:
	/// LICH_RITUAL_INTERVAL is 4 minutes and the ambient ship cooldown is longer than
	/// that, so on a single-crewed-ship server the cooldown would eat nearly every
	/// ritual, and an unrelated ambient event landing first would swallow the next one.
	/// Events that set this still STAMP last_dynamic_event (see /datum/round_event/voidcrew/New),
	/// so ambient events keep backing off a ship a driven system just hit, the exemption
	/// is one-directional on purpose. Do not set this on ambient events; the cooldown is
	/// what stops one crew being singled out for a spam wave.
	var/ignores_ship_cooldown = FALSE
	/// Ship chosen for the next run_event() call. Set by the scheduler (or picked on demand when admin-forced).
	var/obj/structure/overmap/ship/pending_target

/datum/round_event_control/voidcrew/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	if(event_scope == EVENT_SCOPE_SHIP && !length(get_valid_target_ships()))
		return FALSE
	return TRUE

/// Returns an assoc list of targetable ships weighted by crew count, for pick_weight().
/datum/round_event_control/voidcrew/proc/get_valid_target_ships()
	var/list/valid = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		var/crew_aboard = length(ship.get_event_crew())
		if(crew_aboard < min_crew_aboard)
			continue
		if(!is_valid_target(ship))
			continue
		valid[ship] = max(crew_aboard, 1)
	return valid

/// Whether the given ship may be targeted by this event right now. Crew count is checked separately.
/datum/round_event_control/voidcrew/proc/is_valid_target(obj/structure/overmap/ship/ship)
	if(QDELETED(ship) || ship.abandoned || !ship.shuttle)
		return FALSE
	if(min_ship_mass > SHIP_MASS_ANY && ship.mass < min_ship_mass)
		return FALSE
	if(!ignores_ship_cooldown && world.time < ship.last_dynamic_event + SSdynamic_events.ship_cooldown)
		return FALSE
	if(!allow_in_safe_harbor && istype(ship.docked, /obj/structure/overmap/trader_outpost))
		return FALSE
	if(requires_flying && (ship.state != OVERMAP_SHIP_FLYING || ship.docked))
		return FALSE
	if(requires_zero_g && ship.docked?.has_ambient_gravity())
		return FALSE
	if(allowed_zones)
		var/band = SSovermap.get_zone_band_for_turf(get_turf(ship))
		if(!(band in allowed_zones))
			return FALSE
	return TRUE

/// Picks the ship the next event instance will hit. With force (admin-forced events),
/// relaxes the cooldown/zone rules rather than fizzling entirely.
/datum/round_event_control/voidcrew/proc/pick_target_ship(force = FALSE)
	var/list/valid = get_valid_target_ships()
	if(length(valid))
		return pick_weight(valid)
	if(!force)
		return null
	var/list/fallback = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship) || ship.abandoned || !ship.shuttle)
			continue
		if(!length(ship.get_event_crew()))
			continue
		fallback += ship
	return length(fallback) ? pick(fallback) : null

/datum/round_event_control/voidcrew/run_event(random = FALSE, announce_chance_override = null, admin_forced = FALSE, event_cause)
	if(event_scope == EVENT_SCOPE_SHIP && !pending_target)
		pending_target = pick_target_ship(force = admin_forced)
		if(!pending_target)
			message_admins("Dynamic event [name] found no valid target ship, skipping.")
			return
	. = ..()
	pending_target = null

/datum/round_event_control/voidcrew/Topic(href, href_list)
	// The parent clears `triggering` while handling the reroll, so record whether this
	// click was the one that caught the pending event before handing over.
	var/was_pending = triggering
	..()
	// The parent's "SOMETHING ELSE" reroll goes through SSevents.spawnEvent, which is a
	// no-op while allow_random_events is off, reroll through our scheduler instead.
	// Only the click that actually stood the pending event down gets to do it: every
	// later click on the same link still satisfies `!triggering`, and each one used to
	// roll another event.
	if(href_list["different_event"] && was_pending && !triggering)
		SSdynamic_events.spawn_dynamic_event(excluded_event = src)

/datum/round_event/voidcrew
	/// The ship this event is confined to. Null only for EVENT_SCOPE_GALAXY events.
	var/obj/structure/overmap/ship/target_ship

/datum/round_event/voidcrew/New(my_processing = TRUE, datum/round_event_control/event_controller)
	..()
	var/datum/round_event_control/voidcrew/voidcrew_control = event_controller
	if(istype(voidcrew_control))
		target_ship = voidcrew_control.pending_target
		if(target_ship)
			target_ship.last_dynamic_event = world.time

/// TRUE while the target ship still exists as a loaded shuttle. Ship-scoped events
/// must check this at the top of start()/tick()/end() and bail if it fails, the
/// ship can be destroyed or abandoned mid-event.
/datum/round_event/voidcrew/proc/target_valid()
	return !QDELETED(target_ship) && !target_ship.abandoned && target_ship.shuttle

/datum/round_event/voidcrew/announce_deadchat(random, cause)
	if(target_ship)
		deadchat_broadcast(" has just been[random ? " randomly" : ""] triggered aboard [target_ship.display_name || target_ship.name]!", "<b>[control.name]</b>", message_type = DEADCHAT_ANNOUNCEMENT)
		return
	..()
