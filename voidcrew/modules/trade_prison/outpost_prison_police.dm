/**
 * # Outpost lockup: the police
 *
 * Models a trader outpost's lockup (/datum/outpost_prison) as a police sector, following
 * voidcrew/modules/trade_floors/police_floors.dm: the sector is the /datum/outpost_prison itself, its lift tiles are
 * its 3x3 alcove (alcove_turfs), its elevator floor id is OUTPOST_LIFT_LOCKUP, and its lift panel is a witness camera.
 *
 * When a prisoner goes loose while a player is at the outpost (has_audience()), the wing orders one response unit to
 * its sector through order_unit(), at most once per riot. While a loose prisoner is still on their feet, dispatch
 * keeps that unit on scene and sends it searching for them; once none remain, dispatch stands it down through the
 * alcove as usual.
 */

/datum/outpost_prison
	/// Whether this riot or breakout has already ordered a police unit
	var/riot_police_called = FALSE

/// Clears the one-call-per-riot latch once no riot is on and nobody is loose
/datum/outpost_prison/proc/clear_riot_police_call()
	if(!riot_active && !loose_count())
		riot_police_called = FALSE

/// Orders one police officer to this lockup when a prisoner goes loose with an audience, at most once per riot
/datum/outpost_prison/proc/maybe_call_riot_police()
	if(riot_police_called || !has_audience() || !outpost?.police)
		return null
	riot_police_called = TRUE
	return outpost.police.order_unit(POLICE_UNIT_OFFICER, src)

// =========================================================================
// SECTORS, CAMERAS AND BREAKOUT RESPONSE
// =========================================================================

/// The lockup sector `where` is in (the /datum/outpost_prison) when it lies in this outpost's wing and has an alcove, else null
/datum/outpost_police/proc/lockup_sector_of(turf/where)
	var/datum/outpost_prison/lockup = outpost?.prison
	if(!lockup || !length(lockup.alcove_turfs) || !lockup.contains_turf(get_turf(where)))
		return null
	return lockup

/// The lift tiles of a lockup sector: its alcove
/datum/outpost_police/proc/lockup_lift_tiles(sector)
	var/datum/outpost_prison/lockup = sector
	if(!istype(lockup) || lockup != outpost?.prison)
		return list()
	return lockup.alcove_turfs || list()

/// Whether `where` is a lift tile of this outpost's lockup
/datum/outpost_police/proc/lockup_is_lift_tile(turf/where)
	var/datum/outpost_prison/lockup = outpost?.prison
	return !!(lockup && (where in lockup.alcove_turfs))

/// The lockup's lift panel, watched like the lobby's and a berth's
/datum/outpost_police/proc/lockup_cameras()
	var/obj/machinery/outpost_elevator/lockup/panel = outpost?.prison?.lift_panel
	if(QDELETED(panel))
		return list()
	return list(panel)

/// A loose prisoner of this outpost's lockup who is still on their feet (turret_target()), nearest `from` when given, or null
/datum/outpost_police/proc/lockup_loose_target(atom/from)
	var/datum/outpost_prison/lockup = outpost?.prison
	if(!lockup)
		return null
	var/turf/from_turf = get_turf(from)
	var/mob/living/carbon/human/npc/outpost_prisoner/best
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in lockup.prisoners)
		if(QDELETED(prisoner) || !prisoner.turret_target())
			continue
		if(!from_turf)
			return prisoner
		var/turf/where = get_turf(prisoner)
		var/distance = (where && where.z == from_turf.z) ? get_dist(from_turf, where) : 1000
		if(!best || distance < best_distance)
			best = prisoner
			best_distance = distance
	return best

/// Whether a pending spawn `order` was queued for the lockup while a loose prisoner is still up
/datum/outpost_police/proc/lockup_keeps_order(datum/human_npc_order/order)
	var/datum/outpost_prison/lockup = outpost?.prison
	if(!lockup || !order || !lockup_loose_target())
		return FALSE
	for(var/datum/outpost_police_wave/wave as anything in dispatch_waves)
		if(wave?.sector == lockup && (order in wave.orders))
			return TRUE
	return FALSE

/// Whether `officer` is a response unit working a loose prisoner in this outpost's lockup
/datum/outpost_police/proc/lockup_keeps_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/outpost_prison/lockup = outpost?.prison
	if(!lockup || QDELETED(officer) || !dispatch_is_response_unit(officer) || !lockup_loose_target())
		return FALSE
	return officer.dispatch_wave?.sector == lockup || lockup.contains_turf(get_turf(officer))

/// Sends an idle response unit in the lockup searching toward a loose prisoner
/datum/outpost_police/proc/lockup_direct_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(!lockup_keeps_officer(officer))
		return FALSE
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	if(!istype(brain) || officer.stat != CONSCIOUS || officer.client || officer.case || officer.npc_exit || officer.dispatch_riding)
		return FALSE
	if(brain.stealth_state() != STEALTH_UNAWARE || brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) || world.time < brain.police_research_at)
		return FALSE
	var/mob/living/carbon/human/npc/outpost_prisoner/runner = lockup_loose_target(officer)
	var/turf/where = get_turf(runner)
	if(!where)
		return FALSE
	brain.police_research_at = world.time + OUTPOST_POLICE_RESEARCH_GAP
	brain.stealth_go_searching(where)
	return TRUE

// Loose prisoners share FACTION_NEUTRAL with officers, so stealth's scan and police_will_fight() must not pass them over as allies.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/faction_check_atom(atom/movable/target, exact_match)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = target
	if(istype(prisoner) && prisoner.turret_target())
		return FALSE
	return ..()
