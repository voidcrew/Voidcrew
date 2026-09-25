/// The player's physical safety zone, independent of hovered objects or remote cameras.
/atom/movable/screen/screentip/proc/get_fallback_maptext()
	var/mob/player = get_mob()
	if(!player?.client || isnewplayer(player) || !SSovermap_zones?.zones_active)
		return ""
	var/turf/player_turf = get_turf(player)
	if(!player_turf)
		return ""
	var/obj/structure/overmap/ship/ship = get_voidcrew_ship_for_turf(player_turf)
	// get_turf follows docked ships to their carrier's actual overmap tile.
	var/zone_type = SSovermap_zones.get_zone_type_anywhere(ship ? get_turf(ship) : player_turf)
	var/datum/overmap_zone/zone = SSovermap_zones.get_zone_datum(zone_type)
	if(!zone)
		return ""
	return "<span class='context' style='text-align: center; color: [zone.get_color()]'>[zone.name]</span>"
