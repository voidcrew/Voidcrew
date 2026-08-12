/**
 * # The Verdigris: lich lair site + ritual engine
 *
 * A necrotic signal surfaces in yellow/red space well into the round and the
 * whole galaxy is told what it is. Inside is Ilthuun, the Verdigris Lich, behind
 * four sealed defense layers. From the moment he surfaces he works: every
 * LICH_RITUAL_INTERVAL his potency climbs by one (capped at LICH_MAX_POTENCY)
 * and one eligible event from the ritual roster fires somewhere in the galaxy,
 * ramping from "your dead look at you funny" to round-warping. The only off
 * switch is a boarding party.
 *
 * ## Why the site owns its own clock
 *
 * SSdynamic_events is a weight-rolled roster of ship-victim events on a minutes
 * cadence with no notion of escalation, and its events must keep firing whether
 * or not anything spawned them. The ritual ramp is the opposite on both counts:
 * the cadence and the potency belong to one mob, and lich events must not exist
 * when there is no lich. So the site drives its own addtimer chain (same shape
 * as the contested cache's lifecycle, contested_cache.dm) and reaches into the
 * roster itself through fire_ritual_event().
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
/// through (the ritual roster gates on it, the boss reports his death to it).
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

	/// Rituals completed. Doubles as the potency of the last one, so the number
	/// the crew hears announced is the number the roster filters on. Climbs one
	/// per ritual to LICH_MAX_POTENCY and then holds there, firing forever.
	var/ritual_potency = 0
	/// Timer id of the pending ritual, so killing him can cancel it cleanly.
	var/ritual_timer
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
	/// every docking attempt (the base proc early-returns on an existing
	/// reservation), so without this flag every subsequent dock would re-walk the
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
	if(ritual_timer)
		deltimer(ritual_timer)
		ritual_timer = null
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
	. += span_boldwarning("Rituals completed: [ritual_potency][ritual_potency >= LICH_MAX_POTENCY ? " (as deep as it goes)" : ""].")
	if(loaded)
		var/sealed = sealed_ward_count()
		if(sealed)
			. += span_boldwarning("[sealed] ward[sealed == 1 ? "" : "s"] still humming behind the breach.")
		else
			. += span_boldwarning("Every ward is dark. Nothing stands between the breach and the sanctum.")

/**
 * Kicks the raid off: reveals the site (there is no mystery to survey, he
 * announces himself), charts a helm waypoint onto the whole fleet, tells the
 * galaxy who is calling and what is about to start happening to it, and starts
 * the ritual clock. Called once by the scheduler right after set_ruin_template().
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/start_event()
	on_surveyed()

	var/list/coords = get_relative_overmap_coords()
	var/where = coords ? "grid [coords[1]], [coords[2]]" : "an unknown position"

	broadcast_galaxy(
		"You have all been very busy. I have been busy longer. My name is Ilthuun, and my house has come up out of the dark at [where]. Come and look at it or don't, it changes nothing. I am going to keep cutting rites, and you are going to keep feeling them. There is one way to stop me, and it is a short walk down four sealed halls.",
		"The Verdigris",
	)

	// Registers as well as pushes: he is going to keep working for the rest of the
	// round, so a hull commissioned an hour from now still needs to be told where.
	broadcast_fleet_waypoint()

	notify_ghosts("The Verdigris has surfaced. A lich has begun a galaxy-wide ritual!", source = src, header = "The Verdigris")

	schedule_ritual(LICH_FIRST_RITUAL_DELAY)
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

// ===== RITUAL CLOCK =====

/// Arms the next ritual. Safe to call repeatedly. An existing pending ritual is
/// always replaced, never stacked.
/obj/structure/overmap/space_ruin/lich_lair/proc/schedule_ritual(delay = LICH_RITUAL_INTERVAL)
	if(QDELETED(src) || spent)
		return
	if(ritual_timer)
		deltimer(ritual_timer)
	ritual_timer = addtimer(CALLBACK(src, PROC_REF(run_ritual)), delay, TIMER_STOPPABLE)

/**
 * One beat of the clock: deepen the working, fire one event at the new potency,
 * tell the galaxy how it is going, re-arm. Potency is incremented BEFORE the
 * roll (so the first ritual lands at 1 and the announced number always matches
 * the band the roster filtered on) and never decreases.
 *
 * The broadcast is unconditional: it does not wait on the roll and does not care
 * whether an event actually ran. A ritual that finds nothing willing to fire
 * still deepens the working and Ilthuun still gloats about it, which is both the
 * honest reading of the fiction and the reason no bypass is needed in
 * get_ritual_roster().
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/run_ritual()
	ritual_timer = null
	if(QDELETED(src) || spent)
		return

	ritual_potency = min(ritual_potency + 1, LICH_MAX_POTENCY)
	// Running a round event sleeps (grand_rune.dm:187 makes the same note about
	// the same call), never block SStimer's fire on it.
	INVOKE_ASYNC(src, PROC_REF(fire_ritual_event), ritual_potency)
	broadcast_galaxy(ritual_flavor(ritual_potency), "The Verdigris")
	schedule_ritual()

/**
 * Fires one ritual at the given potency and returns the control that ran, or null
 * if nothing was eligible.
 *
 * **This is the hook the ritual roster plugs into.** Anything that subtypes
 * /datum/round_event_control/voidcrew/lich is a candidate; the band it declares
 * through min_wizard_trigger_potency..max_wizard_trigger_potency (inclusive,
 * code/modules/events/_event.dm:28-31) decides which potencies it is eligible
 * at, and eligible candidates are rolled by their event weight. No roster
 * registry to keep in sync: SSevents instantiates one control per typepath at
 * init, so subtyping the base is the whole registration step.
 *
 * One ritual, one event TYPE, but a ship-scoped one lands on every crewed ship
 * at once rather than on a rolled victim. See fire_ritual_on_every_ship().
 *
 * A null return is not a failure. It means nothing in the roster was willing to
 * run right now, and the ritual passes quietly. See get_ritual_roster().
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/fire_ritual_event(potency = ritual_potency)
	var/list/roster = get_ritual_roster(potency)
	if(!length(roster))
		log_game("LICH: ritual [potency] had no willing event in the roster; it passes quietly.")
		return null

	var/datum/round_event_control/voidcrew/lich/chosen = pick_weight(roster)
	if(!chosen)
		return null

	if(chosen.event_scope != EVENT_SCOPE_SHIP)
		chosen.run_event(random = TRUE, event_cause = "a Verdigris ritual")
		log_game("LICH: ritual [potency] fired [chosen.name] ([chosen.typepath]) galaxy-wide.")
		return chosen

	if(!fire_ritual_on_every_ship(chosen, potency))
		return null
	return chosen

/**
 * Runs a ship-scoped ritual on EVERY crewed ship, one event instance per hull.
 *
 * The ambient framework rolls a single weighted victim ship per event, which is
 * right for ambient noise and wrong for this: Ilthuun announces himself to the
 * whole galaxy, names the price of ignoring him, and then, under the old
 * behaviour, inconvenienced one crew at random while everyone else watched. A
 * pressure system that only presses one hull is not a reason for anybody else to
 * fly at the lair. So every crew that is flying with people aboard gets the rite.
 *
 * Implemented as N separate run_event() calls with `pending_target` set by hand,
 * rather than by teaching the events to take a list. Each ship gets its own event
 * instance with its own lifecycle, its own tracked objects and its own end(), so
 * every existing per-ship event works unchanged, and one crew's curse expiring or
 * one hull being destroyed mid-rite cannot touch another's.
 *
 * Two accounting details:
 *
 * - `occurrences` is restored to exactly one per ritual. The caps in
 *   lich_events.dm are written as "how many rituals may be this event", and
 *   letting a five-ship galaxy burn five occurrences would silently make every
 *   cap population-dependent.
 * - Deadchat is announced once, by the first instance. Ghosts do not need the
 *   same line per hull.
 *
 * Ships docked at a trader outpost are still skipped, via the framework's
 * `allow_in_safe_harbor` rule. That is a hard invariant about NPC outposts never
 * taking collateral, not a mercy, and the docking bay is the one place a crew can
 * legitimately sit out a rite.
 *
 * Returns the number of ships hit.
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/fire_ritual_on_every_ship(datum/round_event_control/voidcrew/lich/chosen, potency)
	var/list/targets = chosen.get_valid_target_ships()
	if(!length(targets))
		log_game("LICH: ritual [potency] rolled [chosen.name] but no crewed ship was targetable; it passes quietly.")
		return 0

	var/occurrences_before = chosen.occurrences
	var/alert_observers_before = chosen.alert_observers
	var/fired = 0

	for(var/obj/structure/overmap/ship/victim as anything in targets)
		if(QDELETED(victim))
			continue
		chosen.pending_target = victim
		chosen.run_event(random = TRUE, event_cause = "a Verdigris ritual")
		chosen.alert_observers = FALSE // the first instance already told deadchat
		fired++

	chosen.pending_target = null
	chosen.alert_observers = alert_observers_before
	if(fired)
		chosen.occurrences = occurrences_before + 1

	log_game("LICH: ritual [potency] fired [chosen.name] ([chosen.typepath]) on [fired] ship(s).")
	return fired

/**
 * Weighted candidate list for a ritual at the given potency.
 *
 * Selection mirrors the wizard grand rune (grand_rune.dm:200-217): same two
 * vars, same inclusive comparison, and can_spawn_event() is passed
 * allow_magic = TRUE so a roster flagged wizardevent isn't filtered out just
 * because SSevents.wizardmode is off (it always is, in this fork).
 *
 * can_spawn_event() is the ONLY authority on whether a candidate may run, and
 * there is deliberately no bypass around it. It is where an event's own refusals
 * live, every max_occurrences cap, the one-controller-only guards on the two
 * Mockery events, the roster's own GLOB.lich_lair gate. An empty list is a
 * legitimate answer: at sustained maximum potency, once the one-shots in band
 * have all been spent, the correct behaviour is a ritual that costs the galaxy
 * nothing but a threat. Ilthuun still talks; see run_ritual().
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/get_ritual_roster(potency = ritual_potency)
	var/list/roster = list()
	var/player_count = get_active_player_count(alive_check = TRUE, afk_check = TRUE, human_check = TRUE)

	for(var/datum/round_event_control/voidcrew/lich/candidate in SSevents.control)
		if(!candidate.typepath) // abstract bases never get a typepath
			continue
		if(candidate.min_wizard_trigger_potency > potency)
			continue
		if(candidate.max_wizard_trigger_potency < potency)
			continue
		if(!candidate.can_spawn_event(player_count, allow_magic = TRUE))
			continue
		roster[candidate] = max(candidate.weight, 1)

	return roster

/// The line Ilthuun broadcasts after a ritual of the given potency. He starts
/// almost courteous and does not stay that way.
/obj/structure/overmap/space_ruin/lich_lair/proc/ritual_flavor(potency)
	switch(potency)
		if(0, 1)
			return pick(
				"That is the first rite done. You will feel it as a chill in your teeth and nothing worse. That will not be true for long.",
				"It has started, and it started quietly. Somewhere on your ship, something that was not moving is moving now.",
			)
		if(2)
			return pick(
				"Second rite done. Your dead are listening now. They always were. The difference is that now they answer me.",
				"Can you hear the humming? That is my work settling into your crew's bones. Take your time with it. I am not in any hurry.",
			)
		if(3)
			return pick(
				"Third. The green is in your water, your air, and the little warm rooms you sleep in. Nobody has come to stop me yet. I did expect somebody by now.",
				"Three rites down. I have started a list of your ships. It is not a long list, and I am not writing it in ink.",
			)
		if(4)
			return pick(
				"Fourth rite. I can see you now. I am going to keep one of you and give the rest back changed.",
				"I am halfway done. Come and stop me, or stand still and get built into it. Either one works for me.",
			)
		if(5)
			return pick(
				"FIFTH. The green runs all the way to the edge of the chart now. I have your names written down, and I did not use ink.",
				"I do not have to reach for you any more. Every one of you is inside this already, breathing it. Say my name if you think it will help.",
			)
		if(6)
			return pick(
				"SIX. THE ROT IS IN THE AIR OF EVERY SHIP STILL FLYING. BREATHE. BREATHE. BREATHE IT IN FOR ME.",
				"Sixth rite. Your engines, your lights, your corridors: all of it is scaffolding for my sanctum now. Do you like what I have done with your sky?",
			)
		else
			return pick(
				"SEVEN. THERE IS NO EIGHTH. THERE IS ONLY THIS NOW, AND ALL OF YOU INSIDE IT.",
				"THE WORK IS FINISHED AND I AM STILL WORKING. I WILL BE WORKING ON YOUR BONES LONG AFTER THE STARS GO OUT.",
				"I HAVE STOPPED COUNTING. THERE IS NOTHING LEFT TO COUNT TOWARDS.",
			)

// ===== VICTORY =====

/**
 * Called by Ilthuun when he dies (and, as a backstop, by the death signal the
 * site registers at link time. The guard makes both paths idempotent).
 *
 * Stops the clock, lifts the curses that outlive their own firing, tells the
 * galaxy, retires the helm markers. Deliberately does NOT qdel the site or drop
 * the interior: the sanctum still has his garb and his gear in it, and the
 * raiders still have to carry all of that back to a ship and fly it home.
 */
/obj/structure/overmap/space_ruin/lich_lair/proc/on_lich_slain(mob/living/slain, mob/living/killer)
	if(spent)
		return
	spent = TRUE

	if(ritual_timer)
		deltimer(ritual_timer)
		ritual_timer = null
	if(slain)
		UnregisterSignal(slain, COMSIG_LIVING_DEATH)
	lich_ref = null

	// Stopping the clock only stops FUTURE rites. Tongues of the Dead installs a
	// permanent global curse that would otherwise outlast him for the whole round,
	// so his death has to reach back and undo it (see end_lich_babel() and rule 2)
	// in the lich_events.dm header. Runs before the broadcast below, which tells
	// the galaxy it has happened.
	end_lich_babel()

	name = "the Verdigris"
	desc = "A tomb-hulk with the light gone out of it. Whatever was working in there has stopped."
	color = "#6c8f76"
	clear_fleet_waypoint()

	broadcast_galaxy(
		"...oh. Oh, that was well done. That was very well done. I had the whole of it in my hands, and you walked four halls and took it back off me. Everything I made is going to dust on the way out, so check your pockets. You keep only what you take off my floor, and whatever of me has ended up in your head. Ilthuun is finished. The rites are finished.",
		"The Verdigris",
	)
	notify_ghosts("Ilthuun has been slain. The Verdigris rituals have stopped.", source = src, header = "The Verdigris")
	log_game("LICH: Ilthuun slain by [killer ? key_name(killer) : "unknown"] after [ritual_potency] ritual(s).")

/// COMSIG_LIVING_DEATH backstop. The boss calls on_lich_slain() himself; this
/// exists so a missed call can never leave the ritual clock running on a corpse.
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
/obj/structure/overmap/space_ruin/lich_lair/load_level()
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
// See the file header. Both of these tear the reservation down in the base
// class; here they are deliberate no-ops so the raid survives a party wipe.

/// No-op: the lair is never emptied, recycled or replaced. Once it loads it is
/// held for the rest of the round, damage and corpses and all.
/obj/structure/overmap/space_ruin/lich_lair/check_and_respawn()
	return

/// No-op: the base proc drops the reservation and relocates the signal to a
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
 * Places The Verdigris on an unused overmap square and starts its ritual clock.
 * Mid-to-dangerous space by preference: a galaxy-threatening raid boss has no
 * business parked in the safe outer ring. Shared by the scheduler and the admin
 * verb. Returns the site, or null if it could not be placed.
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

ADMIN_VERB(spawn_lich_lair, R_ADMIN, "Spawn The Verdigris", "Force-surface the lich lair raid site on the overmap and start its ritual clock, ignoring both the 90-minute gate and the minimum-player gate.", ADMIN_CATEGORY_EVENTS)
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
 * Ritual-clock control, the counterpart to the Colosseum's match-control verb
 * (colosseum_controller.dm). The ramp is deliberately slow, potency caps roughly
 * half an hour after the lair surfaces, which makes the late game of this event
 * almost untestable in real time. This drives the clock by hand instead.
 */
ADMIN_VERB(lich_ritual_control, R_ADMIN, "Verdigris Ritual Control", "Drive the lich's ritual clock: fire a ritual now, set its potency, or resolve the event outright.", ADMIN_CATEGORY_EVENTS)
	var/obj/structure/overmap/space_ruin/lich_lair/site = GLOB.lich_lair
	if(!site)
		to_chat(user, span_warning("There is no Verdigris this round. Use \"Spawn The Verdigris\" first."))
		return
	if(site.spent)
		to_chat(user, span_warning("Ilthuun is already dead. The ritual clock is stopped and the site is a husk."))
		return

	var/static/list/choices = list(
		"Fire a ritual now (keeps current potency)",
		"Deepen by one and fire (a normal ritual beat)",
		"Set potency...",
		"Slay Ilthuun (resolve the event)",
		"Cancel",
	)
	var/choice = tgui_input_list(user.mob, "Ritual potency is currently [site.ritual_potency] of [LICH_MAX_POTENCY].", "Verdigris Ritual Control", choices)
	if(!choice || choice == "Cancel")
		return
	// Re-resolve: the input above sleeps, and the raid party may have killed him
	// (or an admin deleted the site) while the box was open.
	site = GLOB.lich_lair
	if(!site || site.spent)
		to_chat(user, span_warning("The Verdigris is no longer running an event."))
		return

	switch(choice)
		if("Fire a ritual now (keeps current potency)")
			// fire_ritual_event() runs a round event, which sleeps
			INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap/space_ruin/lich_lair, fire_ritual_event), site.ritual_potency)
			to_chat(user, span_notice("Fired one ritual event at potency [site.ritual_potency]."))
			message_admins("[key_name_admin(user)] fired a Verdigris ritual at potency [site.ritual_potency].")
			log_admin("[key_name(user)] fired a Verdigris ritual at potency [site.ritual_potency].")

		if("Deepen by one and fire (a normal ritual beat)")
			// run_ritual() increments, fires, broadcasts and re-arms the clock
			INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap/space_ruin/lich_lair, run_ritual))
			to_chat(user, span_notice("Advancing the clock one beat (potency [site.ritual_potency] -> [min(site.ritual_potency + 1, LICH_MAX_POTENCY)])."))
			message_admins("[key_name_admin(user)] advanced the Verdigris ritual clock one beat.")
			log_admin("[key_name(user)] advanced the Verdigris ritual clock one beat.")

		if("Set potency...")
			var/new_potency = tgui_input_number(user.mob, "Ritual potency (0 to [LICH_MAX_POTENCY]). This does not fire an event; it sets where the ramp sits.", "Verdigris Potency", site.ritual_potency, LICH_MAX_POTENCY, 0)
			if(isnull(new_potency))
				return
			site = GLOB.lich_lair
			if(!site || site.spent)
				return
			var/old_potency = site.ritual_potency
			site.ritual_potency = clamp(round(new_potency), 0, LICH_MAX_POTENCY)
			to_chat(user, span_notice("Potency [old_potency] -> [site.ritual_potency]. The next ritual will roll from that band."))
			message_admins("[key_name_admin(user)] set Verdigris ritual potency to [site.ritual_potency] (was [old_potency]).")
			log_admin("[key_name(user)] set Verdigris ritual potency to [site.ritual_potency] (was [old_potency]).")

		if("Slay Ilthuun (resolve the event)")
			// Prefer a real death so the mob's own death path runs (summon cleanup,
			// the loot hoard, its own site handoff). Fall back to resolving the site
			// directly if the mob is already gone somehow.
			var/mob/living/boss = site.lich_ref?.resolve()
			if(QDELETED(boss))
				INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap/space_ruin/lich_lair, on_lich_slain), null, user.mob)
				to_chat(user, span_warning("No live Ilthuun found, resolved the event on the site directly (no loot will drop)."))
			else
				boss.investigate_log("was admin-slain by [key_name(user)].", INVESTIGATE_DEATHS)
				boss.adjustBruteLoss(boss.maxHealth * 2)
				if(boss.stat != DEAD)
					boss.death()
				to_chat(user, span_notice("Ilthuun killed; rituals stop and the hoard drops in the sanctum."))
			message_admins("[key_name_admin(user)] slew Ilthuun via ritual control.")
			log_admin("[key_name(user)] slew Ilthuun via ritual control.")

	BLACKBOX_LOG_ADMIN_VERB("Verdigris Ritual Control")
