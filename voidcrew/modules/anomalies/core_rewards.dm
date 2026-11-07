#define PLANET_ICE_DEMON_CORE_CAP 2

/obj/structure/overmap/planet
	/// Shared by both demon variants, retained when the surface unloads or relocates.
	var/ice_demon_cores_emitted = 0

/// Remember the source at spawn, before a demon can be carried to another site.
/datum/component/ice_demon_core_reward
	var/datum/weakref/source_planet_ref
	/// Preloaded surfaces get their overmap owner after their mapped mobs initialize.
	var/turf/pending_spawn_turf
	var/core_type
	var/drop_chance
	/// A failed first roll is final too; revival cannot buy another attempt.
	var/attempted = FALSE

/datum/component/ice_demon_core_reward/Initialize(core_type, drop_chance)
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	src.core_type = core_type
	src.drop_chance = drop_chance
	var/turf/spawn_turf = get_turf(parent)
	bind_source(spawn_turf)
	if(!source_planet_ref && !SSovermap.initialized)
		pending_spawn_turf = spawn_turf
		RegisterSignal(SSovermap, COMSIG_SUBSYSTEM_POST_INITIALIZE, PROC_REF(on_overmap_initialized))

/datum/component/ice_demon_core_reward/proc/bind_source(turf/spawn_turf)
	var/datum/map_footprint/footprint = map_region_for_turf(spawn_turf)
	if(istype(footprint) && istype(footprint.owner, /obj/structure/overmap/planet))
		source_planet_ref = WEAKREF(footprint.owner)

/datum/component/ice_demon_core_reward/proc/on_overmap_initialized(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(SSovermap, COMSIG_SUBSYSTEM_POST_INITIALIZE)
	bind_source(pending_spawn_turf)
	pending_spawn_turf = null

/datum/component/ice_demon_core_reward/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))

/datum/component/ice_demon_core_reward/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_LIVING_DEATH)

/datum/component/ice_demon_core_reward/Destroy(force)
	UnregisterSignal(SSovermap, COMSIG_SUBSYSTEM_POST_INITIALIZE)
	pending_spawn_turf = null
	source_planet_ref = null
	return ..()

/datum/component/ice_demon_core_reward/proc/on_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(attempted)
		return
	attempted = TRUE
	if(!prob(drop_chance) || pending_spawn_turf)
		return
	var/obj/structure/overmap/planet/source_planet = source_planet_ref?.resolve()
	// A deleted source cannot turn a transported demon into an unrestricted reward.
	if(source_planet_ref && (!source_planet || source_planet.ice_demon_cores_emitted >= PLANET_ICE_DEMON_CORE_CAP))
		return
	var/atom/destination = source.drop_location()
	if(!destination)
		return
	var/obj/item/core = new core_type(destination)
	if(!QDELETED(core) && source_planet)
		source_planet.ice_demon_cores_emitted++

/mob/living/basic/mining/ice_demon/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/ice_demon_core_reward, /obj/item/raw_anomaly_core/bluespace, 5)

/mob/living/simple_animal/hostile/asteroid/old_demon/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/ice_demon_core_reward, /obj/item/assembly/signaler/anomaly/bluespace, 20)

#undef PLANET_ICE_DEMON_CORE_CAP
