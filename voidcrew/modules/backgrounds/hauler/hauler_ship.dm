/*
 * The Mule-class hauler: an unarmed NPC freighter patrolling
 * yellow or red space, the honest target for a crew that wants to rob someone. It runs from a
 * ship that locks on (hauler_ai.dm); when a player hull interdicts it, it gives up once: a hail,
 * a full stop, and the whole hold in a strongbox aboard. It carries a few freight cases the
 * Undertow fences. Nobody can claim it (no key, no abandonment), and once it has nothing left
 * aboard, or nobody left to fly it, it jumps out. GLOB.hauler_director keeps two flying.
 * It is never in the pirate pool or SSnpc_ships.active_ships, and never on SSbounty.
 */

/// How often a hauler asks itself whether it is done here
#define HAULER_CHECK_INTERVAL (30 SECONDS)
/// What the hauler says when it gives up
#define HAULER_LINE_HAIL "hail"
/// Gap between two crew hands speaking up at once
#define HAULER_CREW_LINE_GAP (5 SECONDS)

/obj/structure/overmap/ship/npc/hauler
	name = "freighter"
	desc = "A Mule-class freighter."
	shuttle_template = /datum/map_template/shuttle/voidcrew/hauler
	hostile = FALSE
	zone_confined = TRUE
	hold_credits_min = BACKGROUND_HAULER_HOLD_MIN
	hold_credits_max = BACKGROUND_HAULER_HOLD_MAX
	can_board = TRUE
	// default_movement_mode stays the parent's patrol circuit (NPC_MOVEMENT_PATROL compiles after this module)
	faction = list()
	retreat_without_weapons = FALSE
	crew_min = 2
	crew_max = 3
	crew_types = list(/mob/living/basic/ambient_npc/hauler_crew)
	// Not in the pirate pool: there is no pool slot to resolve, now or ever
	spawner_resolved = TRUE

	/// It has given up its hold once, and never again
	var/surrendered = FALSE
	/// world.time it stays hove to after giving up
	var/hove_to_until = 0
	/// Weakrefs to the freight cases it loaded (and any marked since)
	var/list/datum/weakref/cargo_refs = list()
	/// The strongbox it handed over, if it did
	var/datum/weakref/strongbox_ref
	/// It is jumping out (or waiting for boarders to leave so it can)
	var/departing = FALSE
	/// The looping departure check
	var/check_timer
	/// world.time another crew hand may speak up
	var/next_crew_line_at = 0
	/// The trader outpost of its band, where it runs when scared
	var/datum/weakref/haven_ref

/obj/structure/overmap/ship/npc/hauler/Destroy()
	if(check_timer)
		deltimer(check_timer)
		check_timer = null
	cargo_refs.Cut()
	strongbox_ref = null
	haven_ref = null
	return ..()

/**
 * The parent body (npc_ship.dm), with the hauler's own controller, then its name, crew, freight
 * and the departure check. Called once the hull has loaded.
 */
/obj/structure/overmap/ship/npc/hauler/initialize_ai()
	if(ai_controller)
		return

	combat_interface = new()
	combat_interface.initialize_from_ship(src)
	set_shield_power_allocation(1.0)
	ai_controller = new /datum/ai_controller/npc_ship/hauler(src)
	set_movement_mode(default_movement_mode)

	RegisterSignal(src, COMSIG_SHIP_INTEGRITY_CHANGED, PROC_REF(on_integrity_changed))
	RegisterSignal(src, COMSIG_SHIP_INTERDICTED, PROC_REF(on_interdicted))
	RegisterSignal(src, COMSIG_SHIP_EXPLOSIVE_DAMAGE, PROC_REF(on_hull_damaged))
	RegisterSignal(src, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_ship_docked))
	RegisterSignal(src, COMSIG_BACKGROUND_CREDITS_LOST, PROC_REF(on_robbed))

	mass_dirty = TRUE
	calculate_mass()
	mass_initialized = TRUE

	set_ship_name("[pick(GLOB.last_names)] Freight", null, TRUE)
	spawn_crew()
	load_cargo()
	check_timer = addtimer(CALLBACK(src, PROC_REF(check_departure)), HAULER_CHECK_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)
	npc_metric_spawned(src)

/**
 * Two or three hands on the hull's crew markers (open floor if the map has none). No captain and
 * no ship key, and no pirate health scaling: they are not fighters.
 * Deliberately does not call the parent, which spawns a key-carrying captain on random floor.
 */
/obj/structure/overmap/ship/npc/hauler/spawn_crew()
	if(!shuttle?.shuttle_areas)
		log_shuttle("HAULER: [name] spawn_crew found no shuttle areas - hull gets no crew")
		return
	var/list/spots = list()
	for(var/obj/effect/landmark/hauler/crew/marker in find_markers(/obj/effect/landmark/hauler/crew))
		var/turf/spot = get_turf(marker)
		if(spot)
			spots |= spot
	if(!length(spots))
		spots = open_floor()
	var/count = min(rand(crew_min, crew_max), length(spots))
	for(var/i in 1 to count)
		var/mob/living/basic/ambient_npc/hauler_crew/hand = new(pick_n_take(spots))
		hand.hauler_ref = WEAKREF(src)
		tracked_crew += hand
		RegisterSignal(hand, COMSIG_LIVING_DEATH, PROC_REF(on_crew_death))
	if(length(tracked_crew))
		crew_ever_spawned = TRUE

/// BACKGROUND_HAULER_CASES freight cases on the hold's cargo markers (open floor if the map has none)
/obj/structure/overmap/ship/npc/hauler/proc/load_cargo()
	var/list/spots = list()
	for(var/obj/effect/landmark/hauler/cargo/marker in find_markers(/obj/effect/landmark/hauler/cargo))
		var/turf/spot = get_turf(marker)
		if(spot)
			spots |= spot
	if(!length(spots))
		spots = open_floor()
	if(!length(spots))
		return
	var/list/free = spots.Copy()
	for(var/i in 1 to BACKGROUND_HAULER_CASES)
		var/turf/spot = length(free) ? pick_n_take(free) : pick(spots)
		track_cargo(new /obj/item/hauler_cargo(spot))

/// Counts `cargo` as this hauler's freight
/obj/structure/overmap/ship/npc/hauler/proc/track_cargo(obj/item/hauler_cargo/cargo)
	if(QDELETED(cargo))
		return
	cargo.hauler_ref = WEAKREF(src)
	cargo_refs |= WEAKREF(cargo)

/// Its freight still aboard (dropping cases that are gone for good)
/obj/structure/overmap/ship/npc/hauler/proc/cargo_aboard()
	. = list()
	for(var/datum/weakref/cargo_ref in cargo_refs.Copy())
		var/obj/item/hauler_cargo/cargo = cargo_ref.resolve()
		if(QDELETED(cargo))
			cargo_refs -= cargo_ref
			continue
		if(holds(cargo))
			. += cargo

/// Whether its strongbox is still aboard with anything in it
/obj/structure/overmap/ship/npc/hauler/proc/strongbox_aboard()
	var/obj/item/storage/hauler_strongbox/strongbox = strongbox_ref?.resolve()
	if(QDELETED(strongbox))
		return FALSE
	return holds(strongbox) && length(strongbox.contents) > 0

/// Whether `thing` is somewhere on this hull
/obj/structure/overmap/ship/npc/hauler/proc/holds(atom/movable/thing)
	var/area/thing_area = get_area(thing)
	if(!thing_area || !shuttle?.shuttle_areas)
		return FALSE
	return !!shuttle.shuttle_areas[thing_area]

/// This hull's markers of `marker_type`
/obj/structure/overmap/ship/npc/hauler/proc/find_markers(marker_type)
	. = list()
	if(!shuttle?.shuttle_areas)
		return
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/obj/effect/landmark/hauler/marker in shuttle_area)
			if(istype(marker, marker_type))
				. += marker

/// Open, unblocked floor on this hull (the parent spawn_crew's rule), for a map without markers
/obj/structure/overmap/ship/npc/hauler/proc/open_floor()
	. = list()
	if(!shuttle?.shuttle_areas)
		return
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/turf/open/floor/tile in shuttle_area)
			var/blocked = FALSE
			for(var/obj/thing in tile)
				if(thing.density)
					blocked = TRUE
					break
			if(!blocked)
				. += tile

/// One crew hand may speak up now; the next must wait a moment. TRUE if this one may.
/obj/structure/overmap/ship/npc/hauler/proc/claim_crew_line()
	if(world.time < next_crew_line_at)
		return FALSE
	next_crew_line_at = world.time + HAULER_CREW_LINE_GAP
	return TRUE

// =========================================================================
// RUNNING AND HOLDING STILL
// =========================================================================

/// It goes nowhere: given up and hove to, held by an interdictor, or leaving
/obj/structure/overmap/ship/npc/hauler/proc/is_holding_still()
	return departing || is_interdicted || world.time < hove_to_until

/// The trader outpost of its band, or null
/obj/structure/overmap/ship/npc/hauler/proc/flight_haven()
	var/obj/structure/overmap/trader_outpost/haven = haven_ref?.resolve()
	if(!QDELETED(haven))
		return haven
	var/band = pool_zone_type || SSovermap_zones.get_zone_type(get_turf(src))
	if(!band)
		return null
	for(var/obj/structure/overmap/trader_outpost/outpost in GLOB.trader_outposts)
		if(SSovermap_zones.get_zone_type(get_turf(outpost)) == band)
			haven_ref = WEAKREF(outpost)
			return outpost
	return null

// Boardable whenever it is not leaving; the integrity, interdiction and engine rules are for fighting ships
/obj/structure/overmap/ship/npc/hauler/update_boarding_state()
	can_board = !departing

// =========================================================================
// GIVING UP
// =========================================================================

/// Whether `ship` is a player crew's hull: anything but an NPC's, or an NPC hull a crew claimed
/proc/hauler_player_hull(obj/structure/overmap/ship/ship)
	if(!istype(ship) || QDELETED(ship))
		return FALSE
	if(istype(ship, /obj/structure/overmap/ship/npc))
		var/obj/structure/overmap/ship/npc/npc_ship = ship
		return npc_ship.player_controlled
	return TRUE

/obj/structure/overmap/ship/npc/hauler/on_interdicted(datum/source, obj/machinery/ship_combat/interdictor/interdictor, power_level)
	. = ..()
	var/obj/structure/overmap/ship/aggressor = interdictor?.linked_ship_ref?.resolve()
	if(surrendered || departing || !hauler_player_hull(aggressor))
		return
	INVOKE_ASYNC(src, PROC_REF(surrender), aggressor)

/**
 * Gives up to `aggressor`, once: a hail, a full stop for BACKGROUND_HAULER_SURRENDER_TIME, the whole
 * ship account in a strongbox on a cargo marker (so a later siphon finds under
 * SIPHON_MINIMUM_TARGET_BALANCE and is refused), the two credit signals, and the crew's hands up.
 * Returns TRUE if it gave up.
 */
/obj/structure/overmap/ship/npc/hauler/proc/surrender(obj/structure/overmap/ship/aggressor)
	if(surrendered || departing || QDELETED(src) || QDELETED(aggressor))
		return FALSE
	surrendered = TRUE
	hove_to_until = world.time + BACKGROUND_HAULER_SURRENDER_TIME
	full_stop()
	var/datum/ai_controller/npc_ship/hauler/controller = ai_controller
	if(istype(controller))
		controller.stop_flight()

	var/hail = hauler_line(HAULER_LINE_HAIL) || "Easy! The strongbox is yours. Leave the crew be."
	aggressor.ship_notify("[name] hails: \"[hail]\"", "HAIL", SHIP_NOTIFY_NOTICE)

	var/amount = ship_account ? round(ship_account.account_balance) : 0
	var/turf/spot = amount > 0 ? strongbox_spot() : null
	if(spot && ship_account.adjust_money(-amount, "Hold: handed over"))
		var/obj/item/storage/hauler_strongbox/strongbox = new(spot, amount)
		strongbox_ref = WEAKREF(strongbox)
		SEND_SIGNAL(aggressor, COMSIG_BACKGROUND_CREDITS_TAKEN, src, amount, "surrender")
		SEND_SIGNAL(src, COMSIG_BACKGROUND_CREDITS_LOST, aggressor, amount, "surrender")
	else
		amount = 0

	for(var/mob/living/basic/ambient_npc/hauler_crew/hand in tracked_crew)
		hand.hands_up()
	log_game("HAULER: [name] gave up its hold of [amount] cr to [aggressor.name]")
	return TRUE

/// A cargo marker with no freight on it, else any cargo marker, else open floor; null if the hull has none
/obj/structure/overmap/ship/npc/hauler/proc/strongbox_spot()
	var/list/free = list()
	var/list/taken = list()
	for(var/obj/effect/landmark/hauler/cargo/marker in find_markers(/obj/effect/landmark/hauler/cargo))
		var/turf/spot = get_turf(marker)
		if(!spot)
			continue
		if(locate(/obj/item/hauler_cargo) in spot)
			taken += spot
		else
			free += spot
	if(length(free))
		return pick(free)
	if(length(taken))
		return pick(taken)
	var/list/floor = open_floor()
	return length(floor) ? pick(floor) : null

/// Robbed of `amount` (a surrender or a siphon run): the robber answers for it at the outposts
/obj/structure/overmap/ship/npc/hauler/proc/on_robbed(datum/source, obj/structure/overmap/ship/taker, amount, how)
	SIGNAL_HANDLER
	hauler_embargo_robber(taker, amount, how, src)

// =========================================================================
// LEAVING
// =========================================================================

/// Picked clean: the account under the siphon's floor, and no strongbox or freight left aboard
/obj/structure/overmap/ship/npc/hauler/proc/picked_clean()
	if(ship_account && ship_account.account_balance >= SIPHON_MINIMUM_TARGET_BALANCE)
		return FALSE
	return !strongbox_aboard() && !length(cargo_aboard())

/// Every HAULER_CHECK_INTERVAL: nobody left to fly it, or nothing left to carry, and it goes
/obj/structure/overmap/ship/npc/hauler/proc/check_departure()
	if(QDELETED(src) || player_controlled)
		return
	if(departing)
		depart()
		return
	if(count_live_crew_aboard() <= 0 || picked_clean())
		begin_departure()

/// Stops everything and jumps out as soon as nobody is aboard to be taken along
/obj/structure/overmap/ship/npc/hauler/proc/begin_departure()
	if(departing || QDELETED(src))
		return
	departing = TRUE
	can_board = FALSE
	var/datum/ai_controller/npc_ship/hauler/controller = ai_controller
	if(istype(controller))
		controller.stop_flight()
	depart()

/**
 * The jump. despawn_derelict() is the teardown (it frees the berth, refuses while a player or a
 * docked ship is aboard, and deletes the NPCs aboard); a refusal is retried on the next check.
 * TRUE once it has gone.
 */
/obj/structure/overmap/ship/npc/hauler/proc/depart()
	if(QDELETED(src))
		return TRUE
	if(shuttle?.move_in_flight())
		return FALSE
	var/turf/here = get_turf(src)
	var/hauler_name = name
	abandoned_at = world.time // despawn_derelict() logs minutes since this
	if(!despawn_derelict())
		return FALSE
	log_shuttle("HAULER: [hauler_name] jumped out")
	if(here)
		playsound(here, 'sound/effects/magic/wand_teleport.ogg', 75, TRUE)
		do_sparks(3, FALSE, here)
	return TRUE

// No claim window: the abandonment timer that opens one for pirate hulls never starts here
/obj/structure/overmap/ship/npc/hauler/start_abandonment_timer()
	return

// Abandoning would make it claimable at the helm (claim_abandoned_ship()). It leaves instead.
/obj/structure/overmap/ship/npc/hauler/abandon_ship(crash = TRUE)
	begin_departure()

#undef HAULER_CHECK_INTERVAL
#undef HAULER_LINE_HAIL
#undef HAULER_CREW_LINE_GAP
