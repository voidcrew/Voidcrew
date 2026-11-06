/// Backgrounds: owned by P6.

/// Never in a random ruin pool: it has no id. frontier_before_ruins() stamps it at the surface centre.
/datum/map_template/ruin/frontier_homestead
	name = "Frontier homestead"
	prefix = "voidcrew/_maps/map_files/frontier/"
	suffix = "frontier_homestead.dmm"

// Livestock: mapped directly, never swept, never allied with the planet's wildlife

/mob/living/basic/cow/homestead
	gold_core_spawnable = NO_SPAWN

/mob/living/basic/cow/homestead/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_HOMESTEAD_RESIDENT, BACKGROUND_TRAIT)

/mob/living/basic/cow/homestead/should_inherit_planetary_faction()
	return FALSE

/mob/living/basic/chicken/homestead
	gold_core_spawnable = NO_SPAWN

/mob/living/basic/chicken/homestead/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_HOMESTEAD_RESIDENT, BACKGROUND_TRAIT)

/mob/living/basic/chicken/homestead/should_inherit_planetary_faction()
	return FALSE

/mob/living/basic/goat/homestead
	gold_core_spawnable = NO_SPAWN

/mob/living/basic/goat/homestead/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_HOMESTEAD_RESIDENT, BACKGROUND_TRAIT)

/mob/living/basic/goat/homestead/should_inherit_planetary_faction()
	return FALSE

/mob/living/basic/pony/syndicate/homestead
	desc = "A sturdy ranch horse."
	gold_core_spawnable = NO_SPAWN

/mob/living/basic/pony/syndicate/homestead/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_HOMESTEAD_RESIDENT, BACKGROUND_TRAIT)

/mob/living/basic/pony/syndicate/homestead/should_inherit_planetary_faction()
	return FALSE

/mob/living/basic/pet/dog/corgi/homestead
	gold_core_spawnable = NO_SPAWN

/mob/living/basic/pet/dog/corgi/homestead/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_HOMESTEAD_RESIDENT, BACKGROUND_TRAIT)

/mob/living/basic/pet/dog/corgi/homestead/should_inherit_planetary_faction()
	return FALSE

/**
 * After every atom on the stamped homestead has initialized (called from frontier_attach_cave(),
 * during SSovermap's init): the family's fixtures become indestructible and tool-proof (DST-2, and
 * the accepted M4 deviations: every door in the house, barn and cellar, the barn shell's contents
 * the family uses), every mob on the template is a resident, the larder gets its first stock, any
 * family member a landmark failed to make is made, and the homestead starts ticking.
 */
/proc/homestead_after_atoms()
	var/datum/homestead/homestead = GLOB.homestead
	if(!homestead || length(homestead.bounds) < 5)
		return
	var/list/bounds = homestead.bounds
	for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
		var/area/tile_area = tile.loc
		var/indoors = istype(tile_area, /area/voidcrew/homestead) && !istype(tile_area, /area/voidcrew/homestead/yard)
		for(var/atom/movable/thing as anything in tile)
			if(isliving(thing))
				ADD_TRAIT(thing, TRAIT_HOMESTEAD_RESIDENT, BACKGROUND_TRAIT)
				continue
			if(homestead_fixture_protected(thing, indoors))
				thing.AddElement(/datum/element/outpost_property)
				if(istype(thing, /obj/machinery/door/airlock))
					var/obj/machinery/door/airlock/door = thing
					door.aiControlDisabled = AI_WIRE_DISABLED
			// Every door the family uses, the coop's included: not for the animals, and the cellar's barred in a raid
			if(istype(thing, /obj/machinery/door/airlock))
				homestead.watch_door(thing, homestead_door_to_cellar(thing))
		CHECK_TICK
	homestead.find_house_centre()
	homestead.stock_larder()
	homestead.ensure_family()
	homestead.start()

/// Whether `door` opens into the storm cellar
/proc/homestead_door_to_cellar(obj/machinery/door/door)
	var/turf/here = get_turf(door)
	if(!here)
		return FALSE
	if(istype(here.loc, /area/voidcrew/homestead/cellar))
		return TRUE
	for(var/direction in GLOB.cardinals)
		var/turf/neighbour = get_step(here, direction)
		if(neighbour && istype(neighbour.loc, /area/voidcrew/homestead/cellar))
			return TRUE
	return FALSE

/// Whether the stamp sweep makes `thing` the homestead's indestructible property
/proc/homestead_fixture_protected(atom/movable/thing, indoors)
	if(istype(thing, /obj/machinery/oven/range) || istype(thing, /obj/structure/bed))
		return TRUE
	if(istype(thing, /obj/structure/water_source/homestead_well) || istype(thing, /obj/structure/homestead_coop))
		return TRUE
	// Doors of the shell: the house, barn and cellar. Yard gates are fences, and stay ordinary.
	if(indoors && (istype(thing, /obj/machinery/door/airlock) || istype(thing, /obj/structure/mineral_door)))
		return TRUE
	return FALSE
