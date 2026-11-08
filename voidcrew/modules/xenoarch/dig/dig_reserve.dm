/**
 * # Planet dig reserve
 *
 * What a planet's dig sites still hold for the rest of the round. It lives on the persistent
 * overmap planet, never on its disposable surface, because surfaces rebuild five minutes after
 * the last visitor leaves: seeding per build would refill every site on every visit.
 *
 * The first build fills one record per site; rebuilds place only what is left, and mining a
 * site wall takes from its record. Same pattern as /datum/planet_ore_reserve.
 */
/datum/planet_dig_reserve
	/// ZONE_* of the planet when the reserve was made; finds are stamped with it
	var/band = ZONE_GREEN
	/// One record per dig site, in the order they were placed
	var/list/datum/dig_site_record/sites = list()
	/// Set once the first build has placed every site
	var/seeded = FALSE

/datum/planet_dig_reserve/New(band)
	. = ..()
	src.band = XENOARCH_BAND_INDEX(band)

/datum/planet_dig_reserve/Destroy(force)
	QDEL_LIST(sites)
	return ..()

/// What one dig site still holds.
/datum/dig_site_record
	/// Large finds (boulders) left in the site
	var/large_left = 0
	/// Small finds (strange rocks) left in the site
	var/small_left = 0
	/// Which kind of site it is (garden, animal, house, technical, temple, war)
	var/site_kind
	/// Where the site was placed on the first build, so rebuilds put it back in the same spot
	var/x
	var/y

/obj/structure/overmap/planet
	/// What this planet's dig sites still hold; made on first use
	var/datum/planet_dig_reserve/dig_reserve

/obj/structure/overmap/planet/Destroy()
	QDEL_NULL(dig_reserve)
	return ..()

/// This planet's dig reserve, made on first use with the planet's band.
/obj/structure/overmap/planet/proc/get_dig_reserve()
	if(!dig_reserve)
		dig_reserve = new(ore_zone())
	return dig_reserve
