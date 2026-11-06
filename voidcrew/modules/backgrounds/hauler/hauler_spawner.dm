/// Backgrounds: owned by P5. See data/backgrounds/spec.md.

/*
 * Keeps BACKGROUND_HAULER_COUNT haulers flying, one in yellow and one in red (ECO-7, ECO-8). It
 * counts its own slots, never the pirate pool, the way the NT patrol keeps its own director.
 * A slot whose hauler leaves, is destroyed or is deleted refills BACKGROUND_HAULER_RESPAWN later,
 * never at once. It starts with the round and loads at most one hull per tick.
 * Also here: the embargo on crews that rob a hauler (Q8).
 */

/// How often the director looks over its slots
#define HAULER_DIRECTOR_TICK (30 SECONDS)
/// After a failed load, the slot tries again this much later
#define HAULER_SPAWN_RETRY (1 MINUTES)
/// A load that has not come back in this long is given up on
#define HAULER_SPAWN_TIMEOUT (3 MINUTES)

GLOBAL_DATUM_INIT(hauler_director, /datum/hauler_director, new)

/// One hauler the director keeps flying, in one band
/datum/hauler_slot
	/// The band (ZONE_*) it flies in
	var/zone
	/// The hauler in it, once loaded
	var/datum/weakref/hauler_ref
	/// world.time it may load a hauler
	var/ready_at = 0
	/// A load is under way
	var/spawning = FALSE
	/// world.time that load started
	var/spawn_started = 0
	/// Bumped for every load, so a load that outlives its claim knows it is surplus
	var/spawn_serial = 0

/datum/hauler_slot/New(zone)
	. = ..()
	src.zone = zone

/// The hauler in this slot, while it exists
/datum/hauler_slot/proc/get_hauler()
	var/obj/structure/overmap/ship/npc/hauler/hauler = hauler_ref?.resolve()
	return QDELETED(hauler) ? null : hauler

/datum/hauler_director
	/// Its slots (/datum/hauler_slot), yellow first
	var/list/datum/hauler_slot/slots = list()
	/// The round started it
	var/started = FALSE
	/// The looping tick
	var/tick_timer

/datum/hauler_director/New()
	. = ..()
	var/list/bands = list(ZONE_YELLOW, ZONE_RED)
	for(var/i in 1 to BACKGROUND_HAULER_COUNT)
		slots += new /datum/hauler_slot(bands[((i - 1) % length(bands)) + 1])
#ifndef UNIT_TESTS
	// Subsystems exist before the globals are made (code/controllers/master.dm New())
	if(SSticker)
		RegisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING, PROC_REF(on_round_starting))
	else
		log_world("Hauler director: no SSticker at creation, haulers will not fly this round")
#endif

/datum/hauler_director/Destroy()
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	QDEL_LIST(slots)
	return ..()

/datum/hauler_director/proc/on_round_starting(datum/source, start_time)
	SIGNAL_HANDLER
	start()

/// Opens every slot and starts the tick; the first haulers load on the first tick, one per tick
/datum/hauler_director/proc/start(now = world.time)
	if(started)
		return FALSE
	started = TRUE
	for(var/datum/hauler_slot/slot as anything in slots)
		slot.ready_at = now
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), HAULER_DIRECTOR_TICK, TIMER_STOPPABLE | TIMER_LOOP)
	return TRUE

/**
 * Frees the slot of any hauler that has gone or is leaving, starting its respawn clock, and loads
 * at most one hauler into a slot whose clock has run out. `now` is world.time unless a test pins it.
 */
/datum/hauler_director/proc/tick(now = world.time)
	var/loaded_one = FALSE
	for(var/datum/hauler_slot/slot as anything in slots)
		if(slot.hauler_ref)
			var/obj/structure/overmap/ship/npc/hauler/hauler = slot.get_hauler()
			if(!hauler || hauler.departing)
				release_slot(slot, now, hauler)
			continue
		if(slot.spawning)
			if(now - slot.spawn_started < HAULER_SPAWN_TIMEOUT)
				continue
			slot.spawning = FALSE // a load that never came back
		if(loaded_one || now < slot.ready_at)
			continue
		loaded_one = TRUE
		slot.spawning = TRUE
		slot.spawn_started = now
		slot.spawn_serial++
		INVOKE_ASYNC(src, PROC_REF(spawn_hauler), slot, slot.spawn_serial)

/**
 * Loads a hauler for `slot` somewhere in its band. Sleeps through the template load, so only
 * ever runs through INVOKE_ASYNC. Returns the hauler, or null.
 */
/datum/hauler_director/proc/spawn_hauler(datum/hauler_slot/slot, serial)
	var/turf/spawn_turf = SSnpc_ships.get_spawn_turf(list(slot.zone))
	var/obj/structure/overmap/ship/npc/hauler/hauler
	if(spawn_turf)
		hauler = SSnpc_ships.create_npc_ship(/datum/map_template/shuttle/voidcrew/hauler, spawn_turf, /obj/structure/overmap/ship/npc/hauler)
	if(!istype(hauler) || QDELETED(hauler))
		hauler = null
	// Timed out and replaced while it loaded: this one is surplus
	if(slot.spawn_serial != serial || slot.hauler_ref)
		hauler?.begin_departure()
		return null
	slot.spawning = FALSE
	if(!hauler)
		slot.ready_at = world.time + HAULER_SPAWN_RETRY
		log_world("Hauler director: no hauler loaded in zone [slot.zone][spawn_turf ? "" : " (no free spot)"]")
		return null
	fill_slot(slot, hauler)
	return hauler

/// Puts `hauler` in `slot`
/datum/hauler_director/proc/fill_slot(datum/hauler_slot/slot, obj/structure/overmap/ship/npc/hauler/hauler)
	slot.hauler_ref = WEAKREF(hauler)
	slot.spawning = FALSE
	hauler.pool_zone_type = slot.zone
	RegisterSignal(hauler, COMSIG_QDELETING, PROC_REF(on_hauler_deleted))
	log_shuttle("HAULER: [hauler.name] took the zone [slot.zone] slot")

/// Empties `slot` and starts its respawn clock at `now`. `hauler` is the one that was in it, if known.
/datum/hauler_director/proc/release_slot(datum/hauler_slot/slot, now = world.time, obj/structure/overmap/ship/npc/hauler/hauler)
	// A hauler mid-delete drops its own registrations
	if(!QDELETED(hauler))
		UnregisterSignal(hauler, COMSIG_QDELETING)
	slot.hauler_ref = null
	slot.spawning = FALSE
	slot.ready_at = now + BACKGROUND_HAULER_RESPAWN

/// A hauler went without leaving first (destroyed, admin-deleted): its slot's clock starts now
/datum/hauler_director/proc/on_hauler_deleted(datum/source)
	SIGNAL_HANDLER
	for(var/datum/hauler_slot/slot as anything in slots)
		// The hauler is mid-delete, so its weakref no longer resolves: compare the ref itself
		if(slot.hauler_ref && slot.hauler_ref == source.weak_reference)
			release_slot(slot, world.time, source)
			return

/// Every hauler in a slot that is not leaving
/datum/hauler_director/proc/live_haulers()
	. = list()
	for(var/datum/hauler_slot/slot as anything in slots)
		var/obj/structure/overmap/ship/npc/hauler/hauler = slot.get_hauler()
		if(hauler && !hauler.departing)
			. += hauler

/// Every live hauler
/proc/hauler_live_haulers()
	if(!GLOB.hauler_director)
		return list()
	return GLOB.hauler_director.live_haulers()

/**
 * `robber` took `amount` off a hauler (`how`: "surrender" or "siphon"). The take is logged for
 * every robber; a player crew that is not flagged pirate is embargoed at every trader outpost but
 * the Undertow, through the outposts' own embargo (Q8). Pirates are refused there already.
 */
/proc/hauler_embargo_robber(obj/structure/overmap/ship/robber, amount, how, obj/structure/overmap/ship/npc/hauler/hauler)
	if(!hauler_player_hull(robber) || amount <= 0)
		return FALSE
	record_metric(METRIC_BACKGROUND, "hauler_robbed", ship = robber, credits = amount, details = list("how" = how), location = hauler)
	if(robber.pirate_crew)
		return FALSE
	for(var/obj/structure/overmap/trader_outpost/outpost in GLOB.trader_outposts)
		if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
			continue
		outpost.embargo_ship(robber)
	return TRUE

#undef HAULER_DIRECTOR_TICK
#undef HAULER_SPAWN_RETRY
#undef HAULER_SPAWN_TIMEOUT
