/**
 * # The Verdigris: lich lair site + status beacon
 *
 * A necrotic signal surfaces in yellow/red space well into the round and the
 * whole galaxy is told what it is. Inside is Ilthuun, the Verdigris Lich, behind
 * four sealed defense layers. The site does nothing to anyone who stays away:
 * it is a standing, galaxy-wide raid offer, not a pressure ramp. Every
 * LICH_BEACON_INTERVAL it re-announces itself and re-pushes its helm waypoint,
 * so a crew formed an hour after he surfaced still knows where he is and that
 * he is still standing. The reward for answering is the hoard on his sanctum
 * floor (lich_loot.dm), and only the boarding party gets it.
 *
 * ## Why the site owns its own clock
 *
 * SSdynamic_events is a weight-rolled roster of ship-victim events on a minutes
 * cadence; the beacon is not an event, it is a reminder tied to one object's
 * lifetime, and it must stop the moment he dies. So the site drives its own
 * addtimer chain (same shape as the contested cache's lifecycle,
 * contested_cache.dm) and cancels it from the victory path.
 *
 * ## Why the interior never unloads
 *
 * Every other space ruin in this fork tears down its reservation the moment the
 * last player leaves (space_ruin.dm check_and_respawn/unload_level) and reloads
 * a pristine copy next time. That is exactly wrong for a raid: a crew that wipes
 * on layer three would come back to a full-health lich and a resurrected
 * garrison. Both procs are overridden to no-ops here, so once the lair loads it
 * is held for the rest of the round, boss HP, dead guards, spent ammo and
 * opened wards all persist as live objects. That costs one turf reservation,
 * the same order as the Colosseum's z-stack, and in exchange there is no state
 * mirroring to write at all: nothing needs to survive a reload, because there
 * is no reload. Precedent for the two overrides: antag_ruin.dm:104-129.
 */

/// The one lich lair this round, or null. Guards the event and the admin verb
/// against double-spawning, and is the hook every other track resolves the site
/// through (the boss reports his death to it).
GLOBAL_DATUM(lich_lair, /obj/structure/overmap/space_ruin/lich_lair)

// ===== MAP TEMPLATE =====

/datum/map_template/ruin/space/lich_lair
	prefix = "_maps/voidcrew/RandomRuins/SpaceRuins/"
	id = "lich_lair"
	suffix = "lich_lair.dmm"
	name = "The Verdigris"
	description = "A tomb-hulk of fused wreckage and quarried bone, lit green from the inside. Four sealed wards stand between the docking breach and whatever is at the middle of it."
	unpickable = TRUE // never naturally seeded; only the scheduler or an admin surfaces it
	allow_duplicates = FALSE

// ===== OVERMAP SIGNAL =====

/obj/structure/overmap/space_ruin/lich_lair
	name = "necrotic signal"
	desc = "A voice transmitting on every band at once, in a language older than any charter in the sector. It uses your ship's name."
	fleet_waypoint_name = "The Verdigris"

	/// Timer id of the pending beacon beat, so killing him can cancel it cleanly.
	var/beacon_timer
	/// TRUE once Ilthuun is dead. Stops the clock; the site stays put as a
	/// lootable husk rather than retiring, so raiders can strip it and fly home.
	var/spent = FALSE
	/// Turf the death hoard drops on: the reliquary's mapped loot_spot landmark,
	/// captured by link_interior() and kept for the round. Null if the template
	/// placed no marker, in which case the payout falls back to wherever Ilthuun
	/// fell (see get_lich_hoard_turf, lich_loot.dm).
	var/turf/hoard_turf
	/// TRUE once link_interior() has indexed the footprint. The interior never
	/// unloads, so linking is a once-per-round job, but load_level() is called on
	/// every docking attempt (the base proc early-returns on an existing map
	/// zone), so without this flag every subsequent dock would re-walk the
	/// footprint and, worse, RESPAWN Ilthuun once his corpse was gone.
	var/linked = FALSE
	/// Internal wideband transmitter for the galaxy-wide broadcasts.
	var/obj/item/radio/headset/radio
	/// Ward poddoors indexed by mapped id: "lich_ward_atrium" -> list(door, ...).
	/// Built once by link_interior(); driven through set_ward_doors().
	var/list/ward_doors = list()
	/// Interior turfs indexed by lich area typepath. Lets a ward sweep its layer
	/// (and the sanctum fallback place the boss) without re-walking the template.
	var/list/area_turfs = list()
	/// The layer-gate machines found in the template, in whatever order they
	/// were walked. Used for the "N wards still humming" readouts.
	var/list/obj/machinery/lich_ward/wards = list()
	/// Weakref to Ilthuun himself, once the interior has loaded.
	var/datum/weakref/lich_ref

/obj/structure/overmap/space_ruin/lich_lair/Initialize(mapload, datum/map_template/ruin/space/template)
	. = ..()
	if(!GLOB.lich_lair)
		GLOB.lich_lair = src
	color = LICH_GREEN
	radio = new(src)
	radio.subspace_transmission = TRUE
	radio.canhear_range = 0
	radio.set_listening(FALSE)
	radio.recalculateChannels()

/obj/structure/overmap/space_ruin/lich_lair/Destroy()
	if(GLOB.lich_lair == src)
		GLOB.lich_lair = null
	if(beacon_timer)
		deltimer(beacon_timer)
		beacon_timer = null
	clear_fleet_waypoint()
	QDEL_NULL(radio)
	ward_doors = null
	area_turfs = null
	wards = null
	lich_ref = null
	return ..()

/obj/structure/overmap/space_ruin/lich_lair/categorize_ruin()
	ruin_category = "lich_lair"

/obj/structure/overmap/space_ruin/lich_lair/update_icon_for_category()
	icon_state = "strange_event"

/obj/structure/overmap/space_ruin/lich_lair/examine(mob/user)
	. = ..()
	if(spent)
		. += span_notice("The green is gone out of it. Whatever was working in there has stopped.")
		return
	. += span_boldwarning("Still transmitting. Ilthuun has not been dealt with.")
	if(loaded)
		var/sealed = sealed_ward_count()
		if(sealed)
			. += span_boldwarning("[sealed] ward[sealed == 1 ? "" : "s"] still humming behind the breach.")
		else
			. += span_boldwarning("Every ward is dark. Nothing stands between the breach and the sanctum.")

/**
 * Kicks the raid off: reveals the site (there is no mystery to survey, he
 * announces himself), charts a helm waypoint onto the whole fleet, tells the
 * galaxy who is out there and where, and starts the status beacon. Called once
 * by the scheduler right after set_ruin_template().
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/start_event()
	on_surveyed()

	var/list/coords = get_relative_overmap_coords()
	var/where = coords ? "grid [coords[1]], [coords[2]]" : "an unknown position"

	broadcast_galaxy(
		"You have all been very busy. I have been busy longer. My name is Ilthuun, and my house has come up out of the dark at [where]. Come and look at it or don't, it changes nothing. If you want me ended, it is a short walk down four sealed halls, and everything I own is at the bottom of it.",
		"The Verdigris",
	)

	// Registers as well as pushes: he is going to sit there for the rest of the
	// round, so a hull commissioned an hour from now still needs to be told where.
	broadcast_fleet_waypoint()

	notify_ghosts("The Verdigris has surfaced. Ilthuun waits behind four sealed wards!", source = src, header = "The Verdigris")

	schedule_beacon()
	log_game("LICH: The Verdigris surfaced at overmap [where].")

/**
 * Galaxy-wide broadcast in Ilthuun's voice: a Wideband transmission (in-fiction
 * he is simply on every channel) plus a green priority announcement so players
 * without a headset still get it. Wideband is unscoped, see
 * voidcrew/modules/comms/comms.dm, so the site's z-level is irrelevant.
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/broadcast_galaxy(message, title)
	priority_announce(message, title, sender_override = LICH_ANNOUNCER, color_override = "green")
	radio?.talk_into(src, message, RADIO_CHANNEL_WIDEBAND)

// ===== STATUS BEACON =====

/// Arms the next beacon beat. Safe to call repeatedly. An existing pending beat
/// is always replaced, never stacked.
/obj/structure/overmap/space_ruin/lich_lair/proc/schedule_beacon(delay = LICH_BEACON_INTERVAL)
	if(QDELETED(src) || spent)
		return
	if(beacon_timer)
		deltimer(beacon_timer)
	beacon_timer = addtimer(CALLBACK(src, PROC_REF(run_beacon)), delay, TIMER_STOPPABLE)

/**
 * One beat of the status beacon: tell the galaxy he is still standing, re-push
 * the fleet waypoint, re-arm. That is the whole beat, there is no mechanical
 * effect on anybody. It exists so a crew that formed after he surfaced (or
 * cleared its helm marker, or missed the surface announcement) keeps being told
 * where the raid is until somebody answers it.
 *
 * broadcast_fleet_waypoint() is idempotent: add_waypoint() dedups on
 * source_key (ship_waypoints.dm), so the re-push refreshes existing markers in
 * place rather than stacking duplicates, and restores any a crew cleared.
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/run_beacon()
	beacon_timer = null
	if(QDELETED(src) || spent)
		return

	var/list/coords = get_relative_overmap_coords()
	var/where = coords ? "grid [coords[1]], [coords[2]]" : "an uncharted position"
	broadcast_galaxy(pick(
		"The Verdigris is still transmitting from [where]. Ilthuun has not been dealt with.",
		"The necrotic signal at [where] has not stopped. Ilthuun is still in there.",
	), "The Verdigris")
	broadcast_fleet_waypoint()
	schedule_beacon()

// ===== VICTORY =====

/**
 * Called by Ilthuun when he dies (and, as a backstop, by the death signal the
 * site registers at link time. The guard makes both paths idempotent).
 *
 * Stops the beacon, tells the galaxy, retires the helm markers. Deliberately
 * does NOT qdel the site or drop the interior: the sanctum still has his garb
 * and his gear in it, and the raiders still have to carry all of that back to a
 * ship and fly it home.
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/on_lich_slain(mob/living/slain, mob/living/killer)
	if(spent)
		return
	spent = TRUE

	if(beacon_timer)
		deltimer(beacon_timer)
		beacon_timer = null
	if(slain)
		UnregisterSignal(slain, COMSIG_LIVING_DEATH)
	lich_ref = null

	name = "the Verdigris"
	desc = "A tomb-hulk with the light gone out of it. Whatever was working in there has stopped."
	color = "#6c8f76"
	clear_fleet_waypoint()

	broadcast_galaxy(
		"...oh. Oh, that was well done. That was very well done. I had forever in my hands, and you walked four halls and took it back off me. What is left of me is lying on the sanctum floor. Take it and go. Ilthuun is finished.",
		"The Verdigris",
	)
	notify_ghosts("Ilthuun has been slain. The Verdigris has gone dark.", source = src, header = "The Verdigris")
	log_game("LICH: Ilthuun slain by [killer ? key_name(killer) : "unknown"].")

/// COMSIG_LIVING_DEATH backstop. The boss calls on_lich_slain() himself; this
/// exists so a missed call can never leave the status beacon running on a corpse.
/obj/structure/overmap/space_ruin/lich_lair/proc/on_boss_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(on_lich_slain), source, null) // announcing sleeps

// ===== INTERIOR =====

/**
 * The lair loads lazily, on the first dock, and then stays, so link_interior()
 * runs exactly once per round (guarded by `linked`).
 *
 * The try/catch is load-bearing, not paranoia. load_level() is called from the
 * INHERITED ship_act() (space_ruin.dm), which has already set `concerned = TRUE`
 * and put the docking ship into OVERMAP_SHIP_ACTING by this point, and clears
 * neither until it returns. An uncaught runtime in here would therefore propagate
 * out of ship_act() and strand BOTH sides permanently: the site would answer every
 * future dock with "Too much traffic, try again later!", and the ship would sit in
 * ACTING state unable to move or dock anywhere else. Indexing the footprint, and
 * in particular spawning Ilthuun, whose Initialize() is a lot of moving parts, is
 * not worth that risk. A failure here leaves a raidable-but-unlinked lair and a
 * loud log line, which is recoverable; a bricked ship is not.
 */
/obj/structure/overmap/space_ruin/lich_lair/load_level(mob/user, obj/structure/overmap/ship/waiting_ship, queue_timeout)
	..()
	if(!loaded)
		return
	try
		link_interior()
	catch(var/exception/e)
		log_mapping("LICH: link_interior() failed: [e] ([e.file], line [e.line]). The lair is loaded but unlinked. Wards, gates and the boss may all be missing.")
		stack_trace("The Verdigris failed to link its interior: [e]")

/**
 * Walks the freshly loaded footprint once and indexes everything the raid needs:
 * per-layer turf lists, the ward gate poddoors by mapped id, the ward machines,
 * and Ilthuun himself.
 *
 * Every landmark is optional, so every consumer has a geometric fallback: if the
 * map placed no boss, one is spawned on the boss_spawn landmark, and failing
 * that on any clear sanctum tile. A map that placed its own lich is found first
 * and never doubled.
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/link_interior()
	if(linked)
		return
	if(!ruin_bottom_left || !ruin_template?.width || !ruin_template?.height)
		return
	var/turf/top_right = locate(
		ruin_bottom_left.x + ruin_template.width - 1,
		ruin_bottom_left.y + ruin_template.height - 1,
		ruin_bottom_left.z
	)
	if(!top_right)
		return

	ward_doors = list()
	area_turfs = list()
	wards = list()
	var/mob/living/found_lich
	var/turf/boss_spawn_turf

	for(var/turf/interior_turf as anything in block(ruin_bottom_left, top_right))
		var/area/turf_area = interior_turf.loc
		if(istype(turf_area, /area/ruin/space/has_grav/powered/lich_lair))
			LAZYADDASSOCLIST(area_turfs, turf_area.type, interior_turf)
		for(var/obj/effect/landmark/lich/boss_spawn/boss_mark in interior_turf)
			boss_spawn_turf = interior_turf
			qdel(boss_mark)
		// Where the hoard lands when Ilthuun dies. Resolved HERE, from a walk over
		// this lair's own footprint, rather than by scanning GLOB.landmarks_list at
		// death time, that scan once paid the whole hoard out onto a docked
		// player's ship, because ruin interiors and docked shuttles share
		// reservation z-levels. A footprint walk cannot stray off the map.
		for(var/obj/effect/landmark/lich/loot_spot/loot_mark in interior_turf)
			hoard_turf = interior_turf
			qdel(loot_mark)
		for(var/obj/machinery/machine in interior_turf)
			if(istype(machine, /obj/machinery/door/poddoor))
				var/obj/machinery/door/poddoor/gate = machine
				if(istext(gate.id) && findtext(gate.id, "lich_ward_"))
					LAZYADDASSOCLIST(ward_doors, gate.id, gate)
			else if(istype(machine, /obj/machinery/lich_ward))
				var/obj/machinery/lich_ward/ward = machine
				ward.link_site(src)
				wards += ward
		if(!found_lich)
			found_lich = locate(/mob/living/basic/lich) in interior_turf

	// Never conjure a replacement after the event has resolved. A spent site is a
	// lootable husk, not a respawner.
	if(!found_lich && !spent)
		var/turf/spawn_turf = boss_spawn_turf || get_random_layer_turf(/area/ruin/space/has_grav/powered/lich_lair/sanctum)
		if(spawn_turf)
			found_lich = new /mob/living/basic/lich(spawn_turf)
			log_mapping("LICH: template placed no lich. Spawned one at ([spawn_turf.x], [spawn_turf.y]).")
		else
			log_mapping("LICH: no lich, no boss_spawn landmark and no sanctum turf. The raid has no boss.")
	if(found_lich)
		bind_lich(found_lich)

	linked = TRUE

	for(var/expected_id in list(LICH_WARD_ATRIUM, LICH_WARD_OSSUARY, LICH_WARD_WARRENS, LICH_WARD_SANCTUM))
		if(!length(ward_doors[expected_id]))
			log_mapping("LICH: no poddoors found with id '[expected_id]'.")
	if(!length(wards))
		log_mapping("LICH: template placed no ward machines. Every layer stands open.")

/// Adopts a lich as this site's boss and arms the death backstop.
/obj/structure/overmap/space_ruin/lich_lair/proc/bind_lich(mob/living/boss)
	if(QDELETED(boss))
		return
	lich_ref = WEAKREF(boss)
	RegisterSignal(boss, COMSIG_LIVING_DEATH, PROC_REF(on_boss_death), override = TRUE)

/// All interior turfs belonging to the given lich area typepath (may be empty).
/obj/structure/overmap/space_ruin/lich_lair/proc/get_layer_turfs(area_type)
	return area_turfs?[area_type] || list()

/// A random unblocked tile in the given layer, or null.
/obj/structure/overmap/space_ruin/lich_lair/proc/get_random_layer_turf(area_type, tries = 20)
	var/list/candidates = get_layer_turfs(area_type)
	if(!length(candidates))
		return null
	for(var/_ in 1 to tries)
		var/turf/candidate = pick(candidates)
		if(!candidate.is_blocked_turf())
			return candidate
	return null

// ===== WARD GATES =====
// Ward machines drive the mapped ids through here, exactly like the colosseum
// drives its arena gates (colosseum_site.dm:564). Any buttons a mapper wires to
// the same ids keep working independently.

/// Opens or closes every poddoor mapped with the given ward id.
/obj/structure/overmap/space_ruin/lich_lair/proc/set_ward_doors(ward_id, open)
	for(var/obj/machinery/door/poddoor/gate as anything in ward_doors?[ward_id])
		if(QDELETED(gate))
			continue
		INVOKE_ASYNC(gate, open ? TYPE_PROC_REF(/obj/machinery/door, open) : TYPE_PROC_REF(/obj/machinery/door, close))

/// How many wards are still sealed. Drives the "N wards still humming" readouts
/// on the site, on every ward, and in the wards' unseal announcements.
/obj/structure/overmap/space_ruin/lich_lair/proc/sealed_ward_count()
	. = 0
	for(var/obj/machinery/lich_ward/ward as anything in wards)
		if(!QDELETED(ward) && !ward.unsealed)
			.++

// ===== PERSISTENCE OVERRIDES =====
// See the file header. Both of these tear the interior down in the base
// class; here they are deliberate no-ops so the raid survives a party wipe.

/// No-op: the lair is never emptied, recycled or replaced. Once it loads it is
/// held for the rest of the round, damage and corpses and all.
/obj/structure/overmap/space_ruin/lich_lair/check_and_respawn()
	return

/// No-op: the base proc drops the map slot and relocates the signal to a
/// fresh overmap square. The Verdigris holds both. The galaxy was told exactly
/// where it is, and the interior is the persistent state.
/obj/structure/overmap/space_ruin/lich_lair/unload_level()
	return

// ===== SCHEDULER =====

/datum/controller/subsystem/overmap
	/// Whether this round's lich lair has already surfaced (or is being placed).
	var/lich_lair_spawned = FALSE

/**
 * Arms the once-per-round lich arrival. Called once from Initialize.
 *
 * Rolls LICH_SPAWN_CHANCE here rather than at fire time so a round that isn't
 * getting a lich never arms the timer at all. The retry loop below would
 * otherwise have to re-roll on every attempt, which compounds into a much higher
 * effective chance the longer a round runs. One roll, one round, logged either way
 * so a quiet round is distinguishable from a broken one.
 */
/datum/controller/subsystem/overmap/proc/schedule_lich_lair()
	if(!prob(LICH_SPAWN_CHANCE))
		log_mapping("LICH: spawn roll failed ([LICH_SPAWN_CHANCE]% chance), no lich this round.")
		return
	addtimer(CALLBACK(src, PROC_REF(spawn_scheduled_lich_lair)), LICH_FIRST_SPAWN_TIME)

/// Surfaces the lair, retrying on the interval if the overmap had no room.
/datum/controller/subsystem/overmap/proc/spawn_scheduled_lich_lair()
	if(lich_lair_spawned || GLOB.lich_lair)
		return
	// Population gate, not just a time gate: see LICH_MIN_PLAYERS. Both this and a
	// failed placement fall through to the same retry, so the lich is deferred
	// until the round can actually field a raid party rather than cancelled.
	if(get_active_player_count(alive_check = TRUE, afk_check = TRUE, human_check = TRUE) < LICH_MIN_PLAYERS)
		addtimer(CALLBACK(src, PROC_REF(spawn_scheduled_lich_lair)), LICH_SPAWN_RETRY)
		return
	if(!surface_lich_lair())
		addtimer(CALLBACK(src, PROC_REF(spawn_scheduled_lich_lair)), LICH_SPAWN_RETRY)

/**
 * Places The Verdigris on an unused overmap square and starts its status
 * beacon. Mid-to-dangerous space by preference: a raid boss has no business
 * parked in the safe outer ring. Shared by the scheduler and the admin verb.
 * Returns the site, or null if it could not be placed.
 */
/proc/surface_lich_lair()
	if(GLOB.lich_lair)
		return null

	var/datum/map_template/ruin/space/lich_lair/template
	for(var/ruin_id in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/lich_lair/candidate = SSmapping.space_ruins_templates[ruin_id]
		if(istype(candidate))
			template = candidate
			break
	if(!template)
		log_mapping("LICH: lair template missing, the event is disabled this round.")
		return null

	var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(pick(ZONE_YELLOW, ZONE_RED))
	if(!spawn_turf)
		spawn_turf = SSovermap.get_unused_overmap_square()
	if(!spawn_turf)
		log_mapping("LICH: no unused overmap square found, cannot surface the lair.")
		return null

	var/obj/structure/overmap/space_ruin/lich_lair/site = new(spawn_turf)
	if(QDELETED(site))
		return null
	SSovermap.lich_lair_spawned = TRUE
	site.set_ruin_template(template)
	site.start_event()
	log_mapping("SSovermap: The Verdigris surfaced on the overmap.")
	return site

ADMIN_VERB(spawn_lich_lair, R_ADMIN, "Spawn The Verdigris", "Force-surface the lich lair raid site on the overmap and start its status beacon, ignoring both the spawn-time gate and the minimum-player gate.", ADMIN_CATEGORY_EVENTS)
	if(GLOB.lich_lair)
		var/list/coords = GLOB.lich_lair.get_relative_overmap_coords()
		to_chat(user, span_warning("The Verdigris already exists this round[coords ? " (at grid [coords[1]], [coords[2]])" : ""]."))
		return
	var/obj/structure/overmap/space_ruin/lich_lair/site = surface_lich_lair()
	if(!site)
		to_chat(user, span_warning("Failed to place The Verdigris. No free overmap square, or the lair template is missing?"))
		return
	message_admins("[key_name_admin(user)] force-surfaced The Verdigris.")
	log_admin("[key_name(user)] force-surfaced The Verdigris.")
	BLACKBOX_LOG_ADMIN_VERB("Spawn The Verdigris")

/**
 * Minimal beacon control: fires one status-beacon beat immediately (the
 * galaxy-wide status line plus the fleet-waypoint re-push) and re-arms the
 * clock from now. Killing him is done the ordinary way, or with a smite; the
 * old ritual-control verb died with the ritual ramp.
 */
ADMIN_VERB(lich_beacon_control, R_ADMIN, "Verdigris Beacon", "Fire the Verdigris status beacon now: re-broadcast the galaxy-wide status line and re-push the fleet waypoint.", ADMIN_CATEGORY_EVENTS)
	var/obj/structure/overmap/space_ruin/lich_lair/site = GLOB.lich_lair
	if(!site)
		to_chat(user, span_warning("There is no Verdigris this round. Use \"Spawn The Verdigris\" first."))
		return
	if(site.spent)
		to_chat(user, span_warning("Ilthuun is already dead. The beacon is stopped and the site is a husk."))
		return
	// The broadcast path sleeps; never block the verb on it. run_beacon()
	// re-arms the clock itself.
	INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap/space_ruin/lich_lair, run_beacon))
	to_chat(user, span_notice("Fired one beacon beat. The clock re-armed from now."))
	message_admins("[key_name_admin(user)] fired the Verdigris status beacon.")
	log_admin("[key_name(user)] fired the Verdigris status beacon.")
	BLACKBOX_LOG_ADMIN_VERB("Verdigris Beacon")
