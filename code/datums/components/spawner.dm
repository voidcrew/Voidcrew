

/datum/component/spawner
	/// Time to wait between spawns
	var/spawn_time
	/// Visible message to show when something spawns
	var/spawn_text
	/// List of atom types to spawn, picked randomly
	var/list/spawn_types
	/// Faction to grant to mobs (only applies to mobs)
	var/list/faction
	/// Callback to a proc that is called when a mob is spawned. Primarily used for sentient spawners.
	var/datum/callback/spawn_callback

	/// How many mobs can we spawn maximum each time we try to spawn? (1 - max) This number is applied
	var/max_spawn_per_attempt
	/// How many types of mobs, taken from spawn_types, will be spawned in every spawn attempt?
	var/max_spawn_types_per_attempt
	/// Maximum number of atoms we can have active at one time
	var/max_spawned
	/// List of weak references to things we have already created
	var/list/spawned_things = list()

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

	/// Visual Effect to spawn before the mobs spawn in that location.
	var/obj/effect/temp_visual/effect
	/// Audio path to play when spawning new mobs.
	var/sound_effect
	/// How long of a pause do we use between the effect spawning, and the mob spawning.
	var/spawn_windup

	/// What type of behavior does this spawner have?
	var/spawner_logic
	/// If using SPAWN_BY_WAVE_BEHAVIOR, how many waves should spawn before the spawner component shuts down?
	var/max_waves
	/// Number of waves of mobs that have been spawned. Only tracked with SPAWN_BY_WAVE_BEHAVIOR.
	var/completed_waves = 0
	/// Reference a mob that should it die, we'll stop the spawner component from functioning.
	var/mob/linked_mob

	COOLDOWN_DECLARE(spawn_delay)

/datum/component/spawner/Initialize(
	spawn_types = list(),
	spawn_time = 30 SECONDS,
	max_spawned = 5,
	max_spawn_per_attempt = 1,
	max_spawn_types_per_attempt = 1,
	faction = list(FACTION_MINING),
	spawn_text = null,
	datum/callback/spawn_callback = null,
	spawn_distance = 1,
	spawn_distance_exclude = 0,
	initial_spawn_delay = 0 SECONDS,
	spawner_logic = SPAWN_CONTINUOUS_BEHAVIOR,
	max_waves = 1,
	effect = null,
	sound_effect = null,
	spawn_windup = 0.5 SECONDS,
	linked_mob = null
)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE

	if (!islist(spawn_types))
		CRASH("invalid spawn_types to spawn specified for spawner component!")

	src.spawn_time = spawn_time
	src.spawn_types = spawn_types
	src.faction = faction
	src.spawn_text = spawn_text
	src.max_spawned = max_spawned
	src.spawn_callback = spawn_callback
	src.max_spawn_per_attempt = max_spawn_per_attempt
	src.max_spawn_types_per_attempt = max_spawn_types_per_attempt
	src.spawn_distance = spawn_distance
	src.spawn_distance_exclude = spawn_distance_exclude
	src.linked_mob = linked_mob
	// If set, doesn't instantly spawn a creature when the spawner component is applied.
	if(initial_spawn_delay)
		COOLDOWN_START(src, spawn_delay, spawn_time)
	src.spawner_logic = spawner_logic
	if(spawner_logic == SPAWN_BY_WAVE_BEHAVIOR)
		src.max_waves =  max_waves
	src.effect = effect
	if(effect)
		src.spawn_windup = spawn_windup
	src.sound_effect = sound_effect

	RegisterSignals(parent, list(COMSIG_QDELETING), PROC_REF(stop_spawning))
	if(linked_mob)
		RegisterSignals(linked_mob, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH), PROC_REF(stop_spawning))
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
	SEND_SIGNAL(parent, COMSIG_VENT_WAVE_CONCLUDED)
	qdel(src)

/// Determine if we can spawn a mob based on the current spawn logic.
/datum/component/spawner/proc/check_spawn_availability(mobs_spawned)
	if(!spawner_logic)
		CRASH("A spawner was created without selecting it's spawning logic!")

	validate_references()
	switch(spawner_logic)
		if(SPAWN_CONTINUOUS_BEHAVIOR)
			if(mobs_spawned >= max_spawned)
				return FALSE
		if(SPAWN_BY_WAVE_BEHAVIOR)
			if(mobs_spawned) //If any mobs are still alive.
				return FALSE
			if(completed_waves >= max_waves)
				stop_spawning()
				return FALSE
			completed_waves++
			var/atom/spawner_atom = parent
			spawner_atom.balloon_alert_to_viewers("wave [completed_waves]/[max_waves]")
	return TRUE

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
	// END VOIDCREW EDIT (validate_references() now runs inside check_spawn_availability())

	var/spawned_total = length(spawned_things)
	if(!check_spawn_availability(spawned_total))
		return
	var/atom/spawner = parent
	COOLDOWN_START(src, spawn_delay, spawn_time)
	var/list/local_spawn_types = spawn_types.Copy()
	for(var/i in 1 to max_spawn_types_per_attempt)
		var/chosen_mob_type = pick_n_take(local_spawn_types) //This way we avoid duplicates when spawning.
		var/adjusted_spawn_count = 1
		var/max_spawn_this_attempt = min(max_spawn_per_attempt, max_spawned - spawned_total)
		if (max_spawn_this_attempt > 1)
			adjusted_spawn_count = rand(1, max_spawn_this_attempt)
		for(var/j in 1 to adjusted_spawn_count)
			var/atom/created
			var/turf/picked_spot = select_turf(spawner)
			if(!effect || (effect && !spawn_windup))
				created = new chosen_mob_type(picked_spot)
			else
				new effect(picked_spot)
				addtimer(CALLBACK(src, PROC_REF(delayed_mob_spawn), picked_spot, chosen_mob_type, spawner), spawn_windup)

			if(created)
				setup_spawned_mob(created, spawner)
	if(sound_effect)
		playsound(parent, sound_effect, 40)

/**
 * This proc determines the tile that a spawner will place a mob on.
 * @param: atom/spawner: typed definition of the parent, used to send a signal in case a mob spawns to the default position, as well as center our circles to pick turfs from.
 */
/datum/component/spawner/proc/select_turf(atom/spawner)
	var/turf/picked_spot
	if(spawn_distance == 1)
		picked_spot = spawner.loc
	else if(spawn_distance >= 1 && spawn_distance_exclude >= 1)
		picked_spot = pick(turf_peel(spawn_distance, spawn_distance_exclude, spawner.loc, view_based = TRUE, reject_dense = TRUE))
		if(!picked_spot)
			picked_spot = pick(circle_range_turfs(spawner.loc, spawn_distance))
		if(picked_spot == spawner.loc)
			SEND_SIGNAL(spawner, COMSIG_SPAWNER_SPAWNED_DEFAULT)
	else if (spawn_distance >= 1)
		picked_spot = pick(circle_range_turfs(spawner.loc, spawn_distance))
	return picked_spot

/**
 * Adds handling to the created mob from the spawner component,
 * such as adding to spawned_things list,
 * weakrefs to the spawned_things list, and registering relevant signals.
 *
 * @param: turf/picked_spot: Turf to spawn the mob onto.
 * @param: mob/chosen_mob_type: Type of mob to spawn.
 * @param: atom/spawner: type definition of parent, passed for further setup on setup_spawned_mob.
 */
/datum/component/spawner/proc/delayed_mob_spawn(turf/picked_spot, mob/chosen_mob_type, atom/spawner)
	if(!picked_spot)
		CRASH("Incorrect parameters for delayed mob spawn - no picked spot to spawn!")

	var/atom/created = new chosen_mob_type(picked_spot)
	if(!created)
		CRASH("Failed to spawn mob!")
	setup_spawned_mob(created, spawner)

/**
 * Registers signals and flags onto a component spawned mob, to keep track of the spawned mob, as well as prevent them from getting treated as naturally spawned.
 * @param: mob/spawned_mob: Mob to have signals sent to/registered onto.
 * @param: atom/spawner:
 */
/datum/component/spawner/proc/setup_spawned_mob(mob/spawned_mob, atom/spawner)
	spawned_mob.flags_1 |= (spawner.flags_1 & ADMIN_SPAWNED_1)
	spawned_things += WEAKREF(spawned_mob)

	if(isliving(spawned_mob))
		var/mob/living/created_mob = spawned_mob
		created_mob.set_faction(faction)
		// VOIDCREW EDIT ADDITION: set_faction() above replaces the mob's initialized faction
		// list, so restore any native-planet token it received during Initialize().
		inherit_planetary_faction(created_mob)
		// VOIDCREW EDIT ADDITION END
		RegisterSignal(created_mob, COMSIG_LIVING_DEATH, PROC_REF(mob_death))
		if(spawner_logic == SPAWN_BY_WAVE_BEHAVIOR)
			created_mob.adjust_timed_status_effect(60 SECONDS, /datum/status_effect/heads_up)

	SEND_SIGNAL(src, COMSIG_SPAWNER_SPAWNED, spawned_mob)
	RegisterSignal(spawned_mob, COMSIG_QDELETING, PROC_REF(on_deleted))
	spawn_callback?.Invoke(spawned_mob)

	if(spawn_text)
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
/datum/component/spawner/proc/mob_death(mob/living/source)
	spawned_things -= WEAKREF(source)
	source.remove_status_effect(/datum/status_effect/heads_up)
	UnregisterSignal(source, list(COMSIG_QDELETING, COMSIG_LIVING_DEATH))
