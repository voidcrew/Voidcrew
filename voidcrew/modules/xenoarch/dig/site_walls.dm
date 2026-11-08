/**
 * # Dig site walls
 *
 * Ordinary mountain rock flagged as part of a dig site. The wall keeps its own turf type (so it
 * smooths, digs and leaves the same ground as its neighbours) and gains a vein overlay, a mining
 * scanner mark, and one find. Mining it frees that find: a boulder for a large one, a strange rock
 * for a small one, taken out of its site's record in the planet's dig reserve.
 *
 * Site walls drop no ore, so NPC planet miners (ambient_ore_wall_ok()) leave them alone. They
 * never set mineralType to anything but null: upstream gets_drilled() builds whatever that is.
 *
 * Vein marks are Baystation12 excavation_overlays.dmi overlay_archaeo1-3, recoloured.
 */

/turf/closed/mineral
	/// The dig site this wall belongs to (weakref to /datum/dig_site_record)
	var/datum/weakref/dig_site_ref
	/// XENOARCH_FIND_* this wall gives up when mined, or null for plain rock
	var/dig_find
	/// The vein overlay drawn on it, so it can be taken off again
	var/mutable_appearance/dig_vein_overlay

/// Rock tints by wall sprite, so a boulder looks like the face it came out of.
GLOBAL_LIST_INIT(xenoarch_rock_tints, list(
	"icons/turf/walls/mountain_wall.dmi" = "#eef2f6",
	"icons/turf/walls/icerock_wall.dmi" = "#d5e1ec",
	"icons/turf/walls/rock_wall.dmi" = "#9c968e",
	"icons/turf/walls/sandstone_wall.dmi" = "#d8bf8e",
))

/// Turns this rock into a dig site wall holding one find of `find_kind` for `site`.
/turf/closed/mineral/proc/make_dig_site_wall(datum/dig_site_record/site, find_kind)
	dig_site_ref = WEAKREF(site)
	dig_find = find_kind
	mineralType = null
	mineralAmt = 0
	spawned_boulder = null
	scan_state = "xenoarch_site"
	if(dig_vein_overlay)
		cut_overlay(dig_vein_overlay)
	// Drawn on the 32x32 tile, not the wall's oversized 40x40 sprite.
	dig_vein_overlay = mutable_appearance('voidcrew/modules/xenoarch/icons/dig_site.dmi', "vein[rand(1, 3)]", appearance_flags = RESET_TRANSFORM)
	add_overlay(dig_vein_overlay)

/// Clears the site flag without giving anything up.
/turf/closed/mineral/proc/clear_dig_site_wall()
	dig_site_ref = null
	dig_find = null
	scan_state = ""
	if(dig_vein_overlay)
		cut_overlay(dig_vein_overlay)
		dig_vein_overlay = null

/// The colour a boulder cut from this face should take.
/turf/closed/mineral/proc/dig_rock_color()
	if(color)
		return color
	return GLOB.xenoarch_rock_tints["[icon]"] || "#8f8a83"

/turf/closed/mineral/examine(mob/user)
	. = ..()
	if(dig_find)
		. += span_notice("Pale veins run through the rock here, flecked with something that isn't stone.")

/turf/closed/mineral/gets_drilled(mob/user, exp_multiplier = 0)
	if(dig_find)
		release_dig_find(user)
	return ..()

/**
 * Frees this wall's find onto its own tile, just before the wall is scraped away.
 * Returns the boulder or strange rock, or null if the site's record had nothing left.
 */
/turf/closed/mineral/proc/release_dig_find(mob/user)
	var/datum/dig_site_record/site = dig_site_ref?.resolve()
	var/kind = dig_find
	var/rock_color = dig_rock_color()
	clear_dig_site_wall()
	if(!site || !site.take_find(kind))
		return null
	var/atom/movable/freed
	switch(kind)
		if(XENOARCH_FIND_LARGE)
			var/datum/dig_boulder_record/boulder_record = site.cut_boulder()
			boulder_record.rock_color = rock_color
			freed = new /obj/structure/xenoarch_boulder(src, boulder_record, site)
			visible_message(
				span_notice("The face splits around something harder, and a veined boulder comes away whole."),
				blind_message = span_hear("You hear rock split with a deep crack."),
			)
			playsound(src, 'sound/effects/rock/rock_break.ogg', 50, TRUE)
		if(XENOARCH_FIND_SMALL)
			freed = new /obj/item/strange_rock(src, site.band, site.site_kind)
			if(user)
				to_chat(user, span_notice("A lump of veined rock drops out of the face."))
	return freed

/// The mining scanner's pulse marks a site wall with its own sign rather than an ore's.
/obj/effect/temp_visual/mining_overlay/Initialize(mapload)
	. = ..()
	var/turf/closed/mineral/rock = loc
	if(istype(rock) && rock.dig_find)
		icon = 'voidcrew/modules/xenoarch/icons/dig_scan.dmi'
