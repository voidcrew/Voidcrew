/**
 * # World population: the drifting lifeboat (owner item 12)
 *
 * Owner: PC (strays). P0 made this file as a stub; only PC edits it.
 *
 * A freighter's lifeboat drifting in yellow or red space with one person aboard (spec 5.3), at most
 * AMBIENT_LIFEBOATS_MAX at once, the first LIFEBOAT_FIRST_LOW to LIFEBOAT_FIRST_HIGH into the
 * round and one every LIFEBOAT_GAP_LOW to LIFEBOAT_GAP_HIGH after. It is a small space ruin
 * (_maps/voidcrew/RandomRuins/SpaceRuins/ambient_lifeboat.dmm), never seeded or respawned on its own:
 * - it calls a mayday on Wideband and charts itself on every helm;
 * - its survivor appears on the landmark whenever its interior loads (a ship docking, a survey),
 *   the same person every time; they sit on the bunk, tap the canister's gauge, smack the
 *   flickering light, look out of the viewports and wave down whoever comes in, and join a crew as
 *   a stray does (recruit.dm), crossing to the ship in their softsuit;
 * - once they have gone with a crew, the beacon stops and the lifeboat is cleaned up like any ruin;
 * - nobody takes them in LIFEBOAT_QUIET_AFTER: "The lifeboat's beacon goes quiet." and it goes, as
 *   soon as nobody is there.
 * Honest by rule: it is exactly what it says. A red-space lifeboat draws crews into PvP space.
 *
 * SSambient_strays runs its clock, and also rolls escaped convicts in loaded space ruins
 * (convict.dm).
 */

/// The first lifeboat, this long into the round
#define LIFEBOAT_FIRST_LOW (30 MINUTES)
#define LIFEBOAT_FIRST_HIGH (40 MINUTES)
/// The next, this long after the last one set out
#define LIFEBOAT_GAP_LOW (40 MINUTES)
#define LIFEBOAT_GAP_HIGH (60 MINUTES)
/// With nobody taking its survivor in this long, its beacon goes quiet
#define LIFEBOAT_QUIET_AFTER (25 MINUTES)
/// ...or as soon after as nobody is aboard it
#define LIFEBOAT_QUIET_RETRY (1 MINUTES)
/// Percent chance a lifeboat drifts in red space rather than yellow
#define LIFEBOAT_RED_CHANCE 40
/// Overmap squares tried for a free spot
#define LIFEBOAT_OVERMAP_TRIES 80
/// Percent chance a loaded, docked-at space ruin has a convict hiding in it (once per ruin per round)
#define CONVICT_RUIN_CHANCE 15

// =========================================================================
// THE MAP
// =========================================================================

/area/ruin/space/has_grav/powered/ambient_lifeboat
	name = "\improper Lifeboat"

/// The lifeboat: surfaced by SSambient_strays only. Never seeded, never respawned, never on a chart.
/datum/map_template/ruin/space/ambient_lifeboat
	id = "ambient_lifeboat"
	prefix = "_maps/voidcrew/RandomRuins/SpaceRuins/"
	suffix = "ambient_lifeboat.dmm"
	name = "Drifting Lifeboat"
	description = "A freighter's lifeboat, drifting with its beacon on."
	unpickable = TRUE
	allow_duplicates = FALSE

/// Where the lifeboat's survivor appears when its interior loads
/obj/effect/landmark/ambient_lifeboat_survivor
	name = "lifeboat survivor"

/// The shared template, or null if the map is missing
/proc/ambient_lifeboat_template()
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/template = SSmapping.space_ruins_templates[template_name]
		if(template.type == /datum/map_template/ruin/space/ambient_lifeboat)
			return template
	return null

// =========================================================================
// THE OVERMAP SIGNAL
// =========================================================================

/obj/structure/overmap/space_ruin/ambient_lifeboat
	name = "drifting lifeboat"
	desc = "A lifeboat calling for help on every channel."
	fleet_waypoint_name = "Lifeboat"
	/// Its transmitter, for the mayday
	var/obj/item/radio/headset/radio
	/// The survivor, while they are out
	var/datum/weakref/survivor_ref
	/// Who is aboard (stray_identity()): the same person every time it loads
	var/list/survivor_identity
	/// The survivor went with a crew
	var/rescued = FALSE
	/// The beacon went quiet: it goes as soon as nobody is aboard
	var/ended = FALSE
	/// Timer: the beacon going quiet
	var/quiet_timer

/obj/structure/overmap/space_ruin/ambient_lifeboat/Initialize(mapload, datum/map_template/ruin/space/template)
	. = ..()
	// Its survivor is its own: never a contract's site
	mission_exclusive = TRUE
	radio = new(src)
	radio.subspace_transmission = TRUE
	radio.canhear_range = 0
	radio.set_listening(FALSE)
	radio.recalculateChannels()
	RegisterSignal(src, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_interior_loaded))

/obj/structure/overmap/space_ruin/ambient_lifeboat/Destroy()
	if(quiet_timer)
		deltimer(quiet_timer)
		quiet_timer = null
	clear_fleet_waypoint()
	QDEL_NULL(radio)
	var/mob/living/basic/ambient_npc/stray/lifeboat/survivor = survivor_ref?.resolve()
	if(survivor)
		survivor.lifeboat_ref = null
	survivor_ref = null
	return ..()

/obj/structure/overmap/space_ruin/ambient_lifeboat/categorize_ruin()
	ruin_category = "ship"

/obj/structure/overmap/space_ruin/ambient_lifeboat/examine(mob/user)
	. = ..()
	if(ended)
		. += span_notice("Its beacon has gone quiet.")
	else if(!rescued)
		. += span_notice("Its beacon is still calling.")

/// Sets out: charted on every helm, a mayday on Wideband, and the clock on its beacon
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/start_beacon()
	on_surveyed()
	broadcast_fleet_waypoint()
	var/list/maydays = ambient_dialogue_lines(AMBIENT_STRINGS_STRAYS, "lifeboat", "mayday")
	if(length(maydays))
		radio?.talk_into(src, pick(maydays), RADIO_CHANNEL_WIDEBAND)
	if(quiet_timer)
		deltimer(quiet_timer)
	quiet_timer = addtimer(CALLBACK(src, PROC_REF(go_quiet)), LIFEBOAT_QUIET_AFTER, TIMER_STOPPABLE)
	var/list/coords = get_relative_overmap_coords()
	log_game("AMBIENT: a lifeboat set out at [coords ? "[coords[1]], [coords[2]]" : "somewhere"] ([SSovermap.get_zone_band_for_turf(get_turf(src))])")

/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/on_interior_loaded(datum/source, loaded_ok)
	SIGNAL_HANDLER
	if(rescued || ended || !loaded || !ruin_bottom_left)
		return
	// The sweep for the landmark can yield on a slow tick
	INVOKE_ASYNC(src, PROC_REF(place_survivor))

/// Its survivor on their landmark, unless they are already out
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/place_survivor()
	var/mob/living/basic/ambient_npc/stray/lifeboat/survivor = survivor_ref?.resolve()
	if(!QDELETED(survivor) && survivor.stat != DEAD)
		return survivor
	var/turf/spot = survivor_spot()
	return spot ? spawn_survivor(spot) : null

/// The interior's rectangle, list(min x, min y, max x, max y, z), or null while it isn't loaded
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/interior_bounds()
	if(!ruin_bottom_left || !ruin_template?.width || !ruin_template?.height)
		return null
	return list(ruin_bottom_left.x, ruin_bottom_left.y, ruin_bottom_left.x + ruin_template.width - 1, ruin_bottom_left.y + ruin_template.height - 1, ruin_bottom_left.z)

/// The survivor's landmark in the loaded interior, or any floor there
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/survivor_spot()
	var/list/bounds = interior_bounds()
	if(!bounds)
		return null
	for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
		if(locate(/obj/effect/landmark/ambient_lifeboat_survivor) in tile)
			return tile
	return get_random_interior_turf()

/// Its survivor at `spot`: the same person as before, leashed to the lifeboat until a crew takes them
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/spawn_survivor(turf/spot)
	var/mob/living/basic/ambient_npc/stray/lifeboat/survivor = new(spot, survivor_identity)
	survivor_identity = survivor.stray_identity()
	survivor.lifeboat_ref = WEAKREF(src)
	survivor.leash_bounds = interior_bounds()
	ambient_offer_recruit(survivor)
	survivor_ref = WEAKREF(survivor)
	return survivor

/// Its survivor went with a crew: the beacon stops, and the lifeboat is left to the usual cleanup
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/survivor_joined()
	if(rescued)
		return
	rescued = TRUE
	if(quiet_timer)
		deltimer(quiet_timer)
		quiet_timer = null
	clear_fleet_waypoint()
	log_game("AMBIENT: [name]'s survivor went with a crew")

/// Its survivor was killed before anyone took them in: nobody is there on the next load, and the beacon stops
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/survivor_died()
	if(rescued || ended)
		return
	ended = TRUE
	if(quiet_timer)
		deltimer(quiet_timer)
		quiet_timer = null
	clear_fleet_waypoint()
	log_game("AMBIENT: [name]'s survivor was killed")

/// Nobody came: the beacon goes quiet, and the lifeboat goes as soon as nobody is aboard
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/go_quiet()
	quiet_timer = null
	if(QDELETED(src) || rescued || ended)
		return
	if(footprint && turf_footprint_has_players(footprint))
		quiet_timer = addtimer(CALLBACK(src, PROC_REF(go_quiet)), LIFEBOAT_QUIET_RETRY, TIMER_STOPPABLE)
		return
	ended = TRUE
	clear_fleet_waypoint()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship) || ship.abandoned || istype(ship, /obj/structure/overmap/ship/npc))
			continue
		ship.ship_notify("The lifeboat's beacon goes quiet.", "SENSORS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("AMBIENT: [name]'s beacon went quiet")
	retire()

/// Gone: at once if it never loaded, else once its interior is given back
/obj/structure/overmap/space_ruin/ambient_lifeboat/proc/retire()
	if(!mapzone)
		qdel(src)
		return
	mission_locked = FALSE
	// Can wait on the worldgen queue
	INVOKE_ASYNC(src, PROC_REF(check_and_respawn))

/**
 * Its interior is given back once empty, as any ruin's is, but the signal stays on the chart while its
 * beacon calls: the survivor is there again on the next load. Once the survivor went with a crew or
 * the beacon went quiet, it goes for good, and nothing replaces it.
 */
/obj/structure/overmap/space_ruin/ambient_lifeboat/check_and_respawn()
	if(mission_locked)
		cancel_despawn_timer()
		return
	if(!mapzone)
		cancel_despawn_timer()
		if(rescued || ended)
			qdel(src)
		return
	if(!release_interior())
		addtimer(CALLBACK(src, PROC_REF(check_start_despawn)), 30 SECONDS, TIMER_UNIQUE)
		return
	if(rescued || ended)
		qdel(src)

// =========================================================================
// THE SURVIVOR
// =========================================================================

/mob/living/basic/ambient_npc/stray/lifeboat
	name = "lifeboat survivor"
	desc = "Pale, thin and still in an emergency softsuit."
	outfit = /datum/outfit/ambient_lifeboat
	dialogue_section = "lifeboat"
	routine = list(
		/datum/ambient_activity/stray_rest = 2,
		/datum/ambient_activity/lifeboat_canister = 1,
		/datum/ambient_activity/stray_window = 2,
		/datum/ambient_activity/lifeboat_light = 1,
		/datum/ambient_activity/sit = 2,
		/datum/ambient_activity/idle = 2,
	)
	/// The lifeboat they were found on
	var/datum/weakref/lifeboat_ref

/mob/living/basic/ambient_npc/stray/lifeboat/Initialize(mapload, list/identity)
	. = ..()
	// Their softsuit: across open space to a ship, and about a ship's hull
	ADD_TRAIT(src, TRAIT_SPACEWALK, AMBIENT_NPC_TRAIT)

/mob/living/basic/ambient_npc/stray/lifeboat/Destroy()
	lifeboat_ref = null
	return ..()

// Killed where they were found, they are not there again on the next load
/mob/living/basic/ambient_npc/stray/lifeboat/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive || !is_wild())
		return
	var/obj/structure/overmap/space_ruin/ambient_lifeboat/lifeboat = lifeboat_ref?.resolve()
	if(!QDELETED(lifeboat))
		lifeboat.survivor_died()

/mob/living/basic/ambient_npc/stray/lifeboat/on_joined(obj/structure/overmap/ship/ship)
	var/obj/structure/overmap/space_ruin/ambient_lifeboat/lifeboat = lifeboat_ref?.resolve()
	if(!QDELETED(lifeboat))
		lifeboat.survivor_joined()

/// A freighter hand in the softsuit from the lifeboat's locker
/datum/outfit/ambient_lifeboat
	name = "Lifeboat Survivor"
	uniform = /obj/item/clothing/under/color/grey
	suit = /obj/item/clothing/suit/space/fragile
	shoes = /obj/item/clothing/shoes/sneakers/black

/// Tapping the gauge on the air canister
/datum/ambient_activity/lifeboat_canister
	name = "checking the air"
	duration_low = 8 SECONDS
	duration_high = 15 SECONDS
	var/datum/weakref/canister_ref

/datum/ambient_activity/lifeboat_canister/setup()
	var/obj/machinery/portable_atmospherics/canister/canister = locate() in range(AMBIENT_ACTIVITY_RANGE, doer)
	if(!canister || !isturf(canister.loc))
		return FALSE
	var/turf/stand = doer.free_tile_beside(canister, 1, failed_spots)
	if(!stand)
		return FALSE
	canister_ref = WEAKREF(canister)
	go_to(stand)
	set_duration()
	return TRUE

/datum/ambient_activity/lifeboat_canister/arrive()
	var/obj/machinery/portable_atmospherics/canister/canister = canister_ref?.resolve()
	if(!canister)
		return
	doer.face_atom(canister)
	doer.manual_emote("taps the gauge on [canister].")
	doer.speak_context("canister", null)

/datum/ambient_activity/lifeboat_canister/act(seconds)
	return canister_ref?.resolve() ? AMBIENT_STEP_CONTINUE : AMBIENT_STEP_DONE

/// Smacking the light until it stops flickering
/datum/ambient_activity/lifeboat_light
	name = "fixing the light"
	duration_low = 6 SECONDS
	duration_high = 10 SECONDS
	var/datum/weakref/light_ref

/datum/ambient_activity/lifeboat_light/setup()
	var/obj/machinery/light/lamp = locate() in range(AMBIENT_ACTIVITY_RANGE, doer)
	if(!lamp || !isturf(lamp.loc))
		return FALSE
	var/turf/stand = doer.standable(lamp.loc, failed_spots) ? lamp.loc : doer.free_tile_beside(lamp, 1, failed_spots)
	if(!stand)
		return FALSE
	light_ref = WEAKREF(lamp)
	go_to(stand)
	set_duration()
	return TRUE

/datum/ambient_activity/lifeboat_light/arrive()
	var/obj/machinery/light/lamp = light_ref?.resolve()
	if(!lamp)
		return
	lamp.flicker(rand(3, 6))
	doer.manual_emote("smacks [lamp].")
	doer.speak_context("light", null)

/datum/ambient_activity/lifeboat_light/act(seconds)
	return light_ref?.resolve() ? AMBIENT_STEP_CONTINUE : AMBIENT_STEP_DONE

// =========================================================================
// THE CLOCK
// =========================================================================

/**
 * # SSambient_strays
 *
 * Once a minute: sends a lifeboat out when one is due and none is out, and rolls, once per space ruin
 * per round, whether a loaded ruin a crew has docked at has an escaped convict hiding in it.
 * Nothing on its own in unit tests (`strays_auto`), which drive it by hand.
 */
SUBSYSTEM_DEF(ambient_strays)
	name = "Ambient Strays"
	wait = 1 MINUTES
	// Nothing to set up while the world loads
	flags = SS_BACKGROUND | SS_NO_INIT
	runlevels = RUNLEVEL_GAME
	/// world.time the next lifeboat may set out, once worked out
	var/next_lifeboat_at = 0
	/// Weakrefs to space ruins already rolled for a convict this round -> TRUE
	var/list/rolled_ruins = list()
#ifdef UNIT_TESTS
	/// Whether it runs on its own clock. Off in tests.
	var/strays_auto = FALSE
#else
	/// Whether it runs on its own clock. Off in tests.
	var/strays_auto = TRUE
#endif

/datum/controller/subsystem/ambient_strays/fire(resumed)
	if(!strays_auto)
		return
	check_lifeboat()
	roll_ruin_convicts()

/datum/controller/subsystem/ambient_strays/stat_entry(msg)
	msg = "L:[length(live_lifeboats())]|C:[ambient_live_convicts()]"
	return ..()

/// Lifeboats out now
/datum/controller/subsystem/ambient_strays/proc/live_lifeboats()
	. = list()
	for(var/obj/structure/overmap/space_ruin/ambient_lifeboat/lifeboat in GLOB.space_ruin_signals)
		if(!QDELETED(lifeboat))
			. += lifeboat

/// Sends one out when it is due and there is room
/datum/controller/subsystem/ambient_strays/proc/check_lifeboat()
	if(length(live_lifeboats()) >= AMBIENT_LIFEBOATS_MAX)
		return
	if(!next_lifeboat_at)
		next_lifeboat_at = SSticker.round_start_time + rand(LIFEBOAT_FIRST_LOW, LIFEBOAT_FIRST_HIGH)
	if(world.time < next_lifeboat_at)
		return
	next_lifeboat_at = world.time + rand(LIFEBOAT_GAP_LOW, LIFEBOAT_GAP_HIGH)
	launch_lifeboat()

/**
 * A lifeboat, now, in zone band `band` (or yellow or red, rolled; the other if that is full). Returns
 * it, or null (no template, or no free square).
 */
/datum/controller/subsystem/ambient_strays/proc/launch_lifeboat(band)
	var/datum/map_template/ruin/space/template = ambient_lifeboat_template()
	if(!template)
		log_mapping("AMBIENT: the lifeboat ruin template is not registered")
		return null
	band ||= prob(LIFEBOAT_RED_CHANCE) ? ZONE_RED : ZONE_YELLOW
	var/turf/spot = SSovermap.get_unused_overmap_square_in_zone_band(band, tries = LIFEBOAT_OVERMAP_TRIES)
	if(!spot)
		band = band == ZONE_RED ? ZONE_YELLOW : ZONE_RED
		spot = SSovermap.get_unused_overmap_square_in_zone_band(band, tries = LIFEBOAT_OVERMAP_TRIES)
	if(!spot)
		log_game("AMBIENT: no free square in yellow or red space for a lifeboat")
		return null
	var/obj/structure/overmap/space_ruin/ambient_lifeboat/lifeboat = new(spot)
	lifeboat.set_ruin_template(template)
	lifeboat.start_beacon()
	return lifeboat

/// Rolls each space ruin a crew has docked at, once a round, for a convict hiding there
/datum/controller/subsystem/ambient_strays/proc/roll_ruin_convicts()
	for(var/datum/weakref/ref as anything in rolled_ruins.Copy())
		if(!ref?.resolve())
			rolled_ruins -= ref
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(!ambient_ruin_convict_ok(ruin))
			continue
		var/datum/weakref/ref = WEAKREF(ruin)
		if(rolled_ruins[ref])
			continue
		rolled_ruins[ref] = TRUE
		if(prob(CONVICT_RUIN_CHANCE) && ambient_convict_room())
			ambient_place_ruin_convict(ruin)

ADMIN_VERB(ambient_launch_lifeboat, R_ADMIN|R_DEBUG, "Ambient NPCs: Launch Lifeboat", "Send a drifting lifeboat out now, in yellow or red space.", ADMIN_CATEGORY_DEBUG)
	var/datum/controller/subsystem/ambient_strays/strays = SSambient_strays
	var/obj/structure/overmap/space_ruin/ambient_lifeboat/lifeboat = strays.launch_lifeboat()
	if(!lifeboat)
		to_chat(user, span_warning("No lifeboat could be sent out."))
		return
	to_chat(user, span_notice("A lifeboat set out."))
	message_admins("[key_name_admin(user)] launched a lifeboat at [ADMIN_VERBOSEJMP(lifeboat)].")
	log_admin("[key_name(user)] launched a lifeboat.")
	BLACKBOX_LOG_ADMIN_VERB("Launch Ambient Lifeboat")

#undef LIFEBOAT_FIRST_LOW
#undef LIFEBOAT_FIRST_HIGH
#undef LIFEBOAT_GAP_LOW
#undef LIFEBOAT_GAP_HIGH
#undef LIFEBOAT_QUIET_AFTER
#undef LIFEBOAT_QUIET_RETRY
#undef LIFEBOAT_RED_CHANCE
#undef LIFEBOAT_OVERMAP_TRIES
#undef CONVICT_RUIN_CHANCE
