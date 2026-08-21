/datum/component/spawner
	/// Time to wait between spawns
	var/spawn_time
	/// Maximum number of atoms we can have active at one time
	var/max_spawned
	/// Visible message to show when something spawns
	var/spawn_text
	/// List of atom types to spawn, picked randomly
	var/list/spawn_types
	/// Faction to grant to mobs (only applies to mobs)
	var/list/faction
	/// List of weak references to things we have already created
	var/list/spawned_things = list()
	/// Callback to a proc that is called when a mob is spawned. Primarily used for sentient spawners.
	var/datum/callback/spawn_callback
	/// How many mobs can we spawn maximum each time we try to spawn? (1 - max)
	var/max_spawn_per_attempt
	/// Distance from the spawner to spawn mobs
	var/spawn_distance
	/// Distance from the spawner to exclude mobs from spawning
	var/spawn_distance_exclude
	// VOIDCREW EDIT ADDITION: cached map-tenant footprint for the presence gate in
	// try_spawn_mob(). Resolved lazily on the first tick that has anyone on our z-level and
	// re-resolved if the parent ever moves (structures do not, but components ride mobs and
	// items too). Null means "this level is not shared", which is the common case and the
	// one that keeps the plain z-level gate.
	var/datum/map_footprint/cached_footprint
	/// The turf cached_footprint was resolved from, so a moved parent invalidates it.
	var/turf/cached_footprint_turf
	// VOIDCREW EDIT ADDITION END
	COOLDOWN_DECLARE(spawn_delay)

/datum/component/spawner/Initialize(spawn_types = list(), spawn_time = 30 SECONDS, max_spawned = 5, max_spawn_per_attempt = 1 , faction = list(FACTION_MINING), spawn_text = null, datum/callback/spawn_callback = null, spawn_distance = 1, spawn_distance_exclude = 0, initial_spawn_delay = 0 SECONDS)
	if (!islist(spawn_types))
		CRASH("invalid spawn_types to spawn specified for spawner component!")
	src.spawn_time = spawn_time
	src.spawn_types = spawn_types
	src.faction = faction
	src.spawn_text = spawn_text
	src.max_spawned = max_spawned
	src.spawn_callback = spawn_callback
	src.max_spawn_per_attempt = max_spawn_per_attempt
	src.spawn_distance = spawn_distance
	src.spawn_distance_exclude = spawn_distance_exclude
	// If set, doesn't instantly spawn a creature when the spawner component is applied.
	if(initial_spawn_delay)
		COOLDOWN_START(src, spawn_delay, spawn_time)

	RegisterSignal(parent, COMSIG_QDELETING, PROC_REF(stop_spawning))
	RegisterSignal(parent, COMSIG_VENT_WAVE_CONCLUDED, PROC_REF(stop_spawning))
	START_PROCESSING((spawn_time < 2 SECONDS ? SSfastprocess : SSprocessing), src)

// VOIDCREW EDIT: break the parent <-> spawn_callback reference cycle.
// /obj/structure/spawner passes spawn_callback = CALLBACK(src, PROC_REF(on_mob_spawn)),
// and the callback datum's obj var keeps the parent alive: parent -> components ->
// this component -> spawn_callback -> parent never soft-GCs, so every component-based
// spawner hard-deletes - a multi-minute reference search each under REFERENCE_TRACKING.
/datum/component/spawner/Destroy()
	spawn_callback = null
	spawned_things = null
	cached_footprint = null
	cached_footprint_turf = null
	return ..()

/datum/component/spawner/process()
	try_spawn_mob()

/// Stop spawning mobs
/datum/component/spawner/proc/stop_spawning(force)
	SIGNAL_HANDLER

	STOP_PROCESSING(SSprocessing, src)
	spawned_things = list()

/// Try to create a new mob
/datum/component/spawner/proc/try_spawn_mob()
	if(!length(spawn_types))
		return
	if(!COOLDOWN_FINISHED(src, spawn_delay))
		return

	// VOIDCREW EDIT: don't spawn where nobody is standing.
	// Spawned mobs die unattended out there (vacuum, weather, each other) and
	// validate_references() frees the slot the instant one is DEAD, so a bone pit or
	// monster den on a loaded-but-unvisited level emits a fresh corpse every spawn_time
	// for the rest of the round - and nothing reaps corpses.
	// We deliberately keep processing (and do not touch the cooldown) so a player arriving
	// re-enables the spawner on the very next tick.
	//
	// The gate used to be same-z only, and said so on purpose ("a cave level with no one in
	// it should stay quiet even if the surface above is busy"). Map packing INVERTS that
	// intent without changing a line of it: up to four tenants now share one z-level, so
	// planet A's monster dens spew all round because someone is standing on planet B. The
	// gate is therefore the tenant's footprint where the level is shared, and the plain
	// z-level check - byte for byte the old behaviour - where it is not.
	//
	// Ordering matters: the z-level client list is checked FIRST, because an empty level is
	// both the common case and the one where no rectangle work should be paid for at all.
	var/turf/spawner_turf = get_turf(parent)
	if(!spawner_turf)
		return
	// Dynamically created z-levels (planets, encounters) can outrun SSmobs' resize.
	if(spawner_turf.z > length(SSmobs.clients_by_zlevel))
		return
	var/list/clients_here = SSmobs.clients_by_zlevel[spawner_turf.z]
	if(!length(clients_here))
		return
	// Only a resolved footprint is worth caching. A null answer means "not shared", and
	// re-deriving that costs a list index and a length check - while caching it would leave
	// a spawner z-gated for the rest of the round if a second tenant moved in next door
	// after this one first ticked. A released slot qdels its footprint, which re-resolves
	// here for free.
	if(QDELETED(cached_footprint) || cached_footprint_turf != spawner_turf)
		cached_footprint_turf = spawner_turf
		cached_footprint = map_footprint_at_turf(spawner_turf)
	if(cached_footprint && !footprint_holds_any_client(cached_footprint, clients_here))
		return
	// END VOIDCREW EDIT

	validate_references()
	var/spawned_total = length(spawned_things)
	if(spawned_total >= max_spawned)
		return
	var/atom/spawner = parent
	COOLDOWN_START(src, spawn_delay, spawn_time)
	var/chosen_mob_type = pick(spawn_types)
	var/adjusted_spawn_count = 1
	var/max_spawn_this_attempt = min(max_spawn_per_attempt, max_spawned - spawned_total)
	if (max_spawn_this_attempt > 1)
		adjusted_spawn_count = rand(1, max_spawn_this_attempt)
	for(var/i in 1 to adjusted_spawn_count)
		var/atom/created
		var/turf/picked_spot

		if(spawn_distance == 1)
			created = new chosen_mob_type(spawner.loc)
		else if(spawn_distance >= 1 && spawn_distance_exclude >= 1)
			picked_spot = pick(turf_peel(spawn_distance, spawn_distance_exclude, spawner.loc, view_based = TRUE))
			if(!picked_spot)
				picked_spot = pick(circle_range_turfs(spawner.loc, spawn_distance))
			if(picked_spot == spawner.loc)
				SEND_SIGNAL(spawner, COMSIG_SPAWNER_SPAWNED_DEFAULT)
			created = new chosen_mob_type(picked_spot)
		else if (spawn_distance >= 1)
			picked_spot = pick(circle_range_turfs(spawner.loc, spawn_distance))
			created = new chosen_mob_type(picked_spot)

		created.flags_1 |= (spawner.flags_1 & ADMIN_SPAWNED_1)
		spawned_things += WEAKREF(created)

		if (isliving(created))
			var/mob/living/created_mob = created
			created_mob.faction = src.faction
			// The assignment above deliberately replaces the mob's initialized faction list,
			// so restore any native-planet token it received during Initialize().
			inherit_planetary_faction(created_mob)
			RegisterSignal(created, COMSIG_MOB_STATCHANGE, PROC_REF(mob_stat_changed))

		SEND_SIGNAL(src, COMSIG_SPAWNER_SPAWNED, created)
		RegisterSignal(created, COMSIG_QDELETING, PROC_REF(on_deleted))
		spawn_callback?.Invoke(created)


	if (spawn_text)
		spawner.visible_message(span_danger("A creature [spawn_text] [spawner]."))



/// Remove weakrefs to atoms which have been killed or deleted without us picking it up somehow
/datum/component/spawner/proc/validate_references()
	for (var/datum/weakref/weak_thing as anything in spawned_things)
		var/atom/previously_spawned = weak_thing?.resolve()
		if (!previously_spawned)
			spawned_things -= weak_thing
			continue
		if (!isliving(previously_spawned))
			continue
		var/mob/living/spawned_mob = previously_spawned
		if (spawned_mob.stat != DEAD)
			continue
		spawned_things -= weak_thing

/// Called when an atom we spawned is deleted, remove it from the list
/datum/component/spawner/proc/on_deleted(atom/source)
	SIGNAL_HANDLER
	spawned_things -= WEAKREF(source)

/// Called when a mob we spawned dies, remove it from the list and unregister signals
/datum/component/spawner/proc/mob_stat_changed(mob/living/source)
	if (source.stat != DEAD)
		return
	spawned_things -= WEAKREF(source)
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_MOB_STATCHANGE))
