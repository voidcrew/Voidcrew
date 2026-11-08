/**
 * # Planet dig reserve
 *
 * What a planet's dig sites still hold for the rest of the round. It lives on the persistent
 * overmap planet, never on its disposable surface, because surfaces rebuild five minutes after
 * the last visitor leaves: seeding per build would refill every site on every visit.
 *
 * The first build fills one record per site; rebuilds place only what is left, and mining a
 * site wall takes from its record. Same pattern as /datum/planet_ore_reserve.
 *
 * A boulder already cut out of the rock keeps its whole state here (depth, field, scan, tag) until
 * it is opened or lost, so a crew that flies off for a stabiliser finds it as they left it.
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

/// Makes one record per site, the first time the planet is built. `planet_type` picks the site kinds.
/datum/planet_dig_reserve/proc/seed(planet_type)
	if(seeded)
		return FALSE
	seeded = TRUE
	var/list/large = XENOARCH_LARGE_PER_SITE
	var/list/small = XENOARCH_SMALL_PER_SITE
	var/index = XENOARCH_BAND_INDEX(band)
	for(var/i in 1 to XENOARCH_SITES_PER_PLANET)
		var/datum/dig_site_record/site = new(band, xenoarch_pick_site_kind(planet_type))
		site.large_left = large[index]
		site.small_left = small[index]
		sites += site
	return TRUE

/// Sites with anything left in them, in placement order.
/datum/planet_dig_reserve/proc/sites_with_finds()
	. = list()
	for(var/datum/dig_site_record/site as anything in sites)
		if(site.finds_left() > 0)
			. += site

/// Every find still to come out of the planet, boulders already cut loose included.
/datum/planet_dig_reserve/proc/finds_left()
	. = 0
	for(var/datum/dig_site_record/site as anything in sites)
		. += site.finds_left()

/// What one dig site still holds.
/datum/dig_site_record
	/// Large finds (boulders) left in the site
	var/large_left = 0
	/// Small finds (strange rocks) left in the site
	var/small_left = 0
	/// Which kind of site it is (XENOARCH_SITE_*)
	var/site_kind = XENOARCH_SITE_HOUSE
	/// Where the site sat on the last build, from the planet footprint's low corner, so a rebuild
	/// tries the same spot first. Terrain is regenerated on a rebuild, so it may not fit again.
	var/x
	var/y
	/// ZONE_* every find from here is stamped with
	var/band = ZONE_GREEN
	/// Boulders cut out of the rock but not yet opened, kept so a rebuild puts them back as they were
	var/list/datum/dig_boulder_record/loose = list()

/datum/dig_site_record/New(band, site_kind)
	. = ..()
	src.band = XENOARCH_BAND_INDEX(band)
	if(site_kind)
		src.site_kind = site_kind

/datum/dig_site_record/Destroy(force)
	QDEL_LIST(loose)
	return ..()

/// Finds still to come out of this site.
/datum/dig_site_record/proc/finds_left()
	return large_left + small_left + length(loose)

/// Takes one find of `kind` (XENOARCH_FIND_*) out of the count. FALSE if none were left.
/datum/dig_site_record/proc/take_find(kind)
	switch(kind)
		if(XENOARCH_FIND_LARGE)
			if(large_left <= 0)
				return FALSE
			large_left--
			return TRUE
		if(XENOARCH_FIND_SMALL)
			if(small_left <= 0)
				return FALSE
			small_left--
			return TRUE
	return FALSE

/// A boulder was cut out of the face: rolls what it holds and keeps it until it is opened or lost.
/datum/dig_site_record/proc/cut_boulder()
	var/datum/dig_boulder_record/boulder = new(band)
	boulder.site_kind = site_kind
	loose += boulder
	return boulder

/// A loose boulder was opened or lost. It is gone from the site for good.
/datum/dig_site_record/proc/settle_boulder(datum/dig_boulder_record/boulder)
	loose -= boulder

/**
 * Everything about one boulder: what is inside, how deep, which field holds it, and how far the
 * crew has got. The boulder structure only draws it.
 */
/datum/dig_boulder_record
	/// ZONE_* the find is stamped with
	var/band = ZONE_GREEN
	/// The catalogue number on its holotag, which an artifact keeps when it comes out
	var/serial
	/// What is inside (a type path), rolled by band
	var/find_type
	/// Depth of the find's surface, in cm
	var/target_depth = XENOARCH_BOULDER_DEPTH_MIN
	/// What the plain depth scanner reads: the true depth give or take XENOARCH_SCAN_ERROR
	var/rough_depth = XENOARCH_BOULDER_DEPTH_MIN
	/// The one stabilising field that holds it (one of GLOB.xenoarch_stabilising_fields)
	var/field
	/// Radiometric age, in years, for the spectrometer report
	var/age = 0
	/// cm cut so far
	var/dug = 0
	/// 0 not sounded, 1 sounded roughly, 2 sounded exactly
	var/sounded = 0
	/// The field the crew projected on it, if any
	var/field_applied
	/// The projected field matches
	var/stabilised = FALSE
	/// A holotag (GPS) has been fixed to it
	var/tagged = FALSE
	/// Sprite variant, 1 to 4
	var/variant = 1
	/// Colour of the rock it was cut from
	var/rock_color
	/// The kind of site it came from, for the spectrometer report
	var/site_kind
	/// Opened or lost: nothing more to do with it
	var/settled = FALSE

/datum/dig_boulder_record/New(band)
	. = ..()
	src.band = XENOARCH_BAND_INDEX(band)
	serial = xenoarch_new_serial()
	find_type = xenoarch_roll_large_find(src.band)
	target_depth = rand(XENOARCH_BOULDER_DEPTH_MIN, XENOARCH_BOULDER_DEPTH_MAX)
	rough_depth = max(1, target_depth + rand(-XENOARCH_SCAN_ERROR, XENOARCH_SCAN_ERROR))
	field = pick(GLOB.xenoarch_stabilising_fields)
	age = rand(4, 900) * 1000000
	variant = rand(1, 4)

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
