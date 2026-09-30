/**
 * # Kudzu size cap
 *
 * TG's kudzu has no size limit. A station's walls and the vacuum outside bound it,
 * and on a ship the hull does. A planet is 128x128 of open ground, so one seed pack
 * planted there spreads for the rest of the round into thousands of processed,
 * light-blocking, atmos-sensitive vines. Seed packs are easy to come by, and one
 * player seeding six planets was enough to lag the whole server.
 *
 * Each cluster stops spreading at a fixed size, and all clusters together stop at
 * a global total, so planting on many planets does not get around the per-cluster
 * cap. Once the global total is reached, new seed packs refuse to take root. A
 * capped cluster still grows, entangles and mutates in place. Cutting it back lets
 * it spread again.
 */

/// Vines one cluster may hold before it stops spreading.
#define SPACEVINE_CLUSTER_CAP 50
/// Vines all clusters together may hold before any of them spreads further.
#define SPACEVINE_GLOBAL_CAP 400

/// Every live kudzu controller, for the global cap.
GLOBAL_LIST_EMPTY(spacevine_controllers)
/// Cached total of vines across every controller. See spacevine_total().
GLOBAL_VAR_INIT(spacevine_total, 0)
/// world.time the cached total was last recounted.
GLOBAL_VAR_INIT(spacevine_total_counted, -1)

/**
 * Total vines owned by every kudzu controller.
 *
 * Recounted from the controllers once per tick, so a vine removed without going
 * through VineDestroyed() can't leak into the count. Spreads within the same tick
 * bump the cache directly, so many clusters spreading at once can't overshoot.
 */
/proc/spacevine_total()
	if(GLOB.spacevine_total_counted != world.time)
		var/total = 0
		for(var/datum/spacevine_controller/controller as anything in GLOB.spacevine_controllers)
			total += length(controller.vines)
		GLOB.spacevine_total = total
		GLOB.spacevine_total_counted = world.time
	return GLOB.spacevine_total

/datum/spacevine_controller/New(turf/location, list/muts, potency, production, datum/round_event/event = null)
	GLOB.spacevine_controllers += src
	return ..()

/datum/spacevine_controller/Destroy()
	GLOB.spacevine_controllers -= src
	return ..()

/datum/spacevine_controller/spawn_spacevine_piece(turf/location, obj/structure/spacevine/parent, list/muts)
	var/before = length(vines)
	. = ..()
	GLOB.spacevine_total += length(vines) - before

/// Whether this cluster may spread any further.
/datum/spacevine_controller/proc/can_spread_further()
	return length(vines) < SPACEVINE_CLUSTER_CAP && spacevine_total() < SPACEVINE_GLOBAL_CAP

// Checked before the parent so mutations' on_spread() effects (breaking through
// walls and the like) also stop at the cap.
/obj/structure/spacevine/spread()
	if(master && !master.can_spread_further())
		return
	return ..()

/obj/item/seeds/kudzu/plant(mob/user)
	if(spacevine_total() >= SPACEVINE_GLOBAL_CAP)
		to_chat(user, span_warning("[src] fails to take root."))
		return FALSE
	return ..()

#undef SPACEVINE_CLUSTER_CAP
#undef SPACEVINE_GLOBAL_CAP
