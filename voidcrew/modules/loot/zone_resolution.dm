/**
 * # Shared overmap-zone resolver
 *
 * One-shot helper that pins a turf and resolves which ZONE_* it belongs to
 * via SSovermap_zones, retrying on a timer while the containing level may
 * still be registering (planet mapzones attach only after their template
 * load returns). Fires the callback exactly once with the resolved zone
 * type, or null if every attempt failed. The consumer picks its own
 * fallback (both current consumers fall back to ZONE_GREEN, the weakest
 * table, so a broken resolution can never inflate a payout).
 *
 * Used by the zone loot caches (zone_loot.dm) and the zone mob markers
 * (zone_mobs.dm), which previously each carried their own copy of this
 * retry loop.
 */

/// How many times a resolver re-attempts zone resolution
#define ZONE_RESOLVE_ATTEMPTS 6
/// Delay between resolution attempts
#define ZONE_RESOLVE_RETRY_DELAY (10 SECONDS)

/datum/zone_resolver
	/// The turf resolution is pinned to; never re-read from the consumer, so
	/// a cache hauled somewhere richer can't retier itself
	var/turf/target
	/// Fired exactly once as Invoke(zone_type); zone_type is null if every
	/// attempt failed
	var/datum/callback/on_done
	/// Attempts left before giving up and reporting null
	var/attempts_left = ZONE_RESOLVE_ATTEMPTS

/datum/zone_resolver/New(turf/target, datum/callback/on_done)
	src.target = target
	src.on_done = on_done
	attempt()

/datum/zone_resolver/Destroy()
	target = null
	on_done = null
	return ..()

/datum/zone_resolver/proc/attempt()
	// The consumer can be deleted mid-retry (create_and_destroy does exactly this);
	// holding its callback for the rest of the retry chain keeps a hard ref on a
	// deleted atom for up to a minute. Stop the moment the consumer is gone.
	if(isnull(on_done) || (isdatum(on_done.object) && QDELETED(on_done.object)))
		qdel(src)
		return
	var/zone_type = target ? SSovermap_zones.get_zone_type_anywhere(target) : null
	if(!isnull(zone_type) || attempts_left-- <= 0)
		on_done?.Invoke(zone_type)
		qdel(src)
		return
	addtimer(CALLBACK(src, PROC_REF(attempt)), ZONE_RESOLVE_RETRY_DELAY)

#undef ZONE_RESOLVE_ATTEMPTS
#undef ZONE_RESOLVE_RETRY_DELAY
