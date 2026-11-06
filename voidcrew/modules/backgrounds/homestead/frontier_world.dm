/// Backgrounds: owned by P6. See data/backgrounds/spec.md.

/obj/structure/overmap/planet
	/// The Frontier's cave level, owned by its planet
	var/datum/map_footprint/cave_footprint

/// The Frontier's surface z, or 0
/proc/frontier_surface_z()
	return 0

/// The Frontier's cave z, or 0
/proc/frontier_cave_z()
	return 0

/// Stamps the homestead and its keep-out rings before ruins seed
/proc/frontier_before_ruins(list/record)
	return

/// Places the cave ladders once the ground is generated
/proc/frontier_after_terrain(list/record)
	return

/// Gives the planet its cave footprint and trackers
/proc/frontier_attach_cave(obj/structure/overmap/planet/planet, datum/map_zone/mapzone, list/record)
	return
