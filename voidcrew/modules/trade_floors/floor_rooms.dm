/**
 * # Outpost floors: rooms and trading
 *
 * Owner: P4 (spec 4). Rooms are the player outposts' own /datum/outpost_upgrade blueprints, bought and placed at
 * the floor's consoles as on an outpost, and every paid service a room sells finds its floor through the host's
 * contains_service_turf() (_floor_types.dm). What an outpost's code would get wrong for a floor is overridden on
 * the host here:
 *
 * - the catalogue: no cargo dock, no cell block extension, no ship bay; the rooms made for floors are sold;
 * - placement: the console's survey and the distance rule both measure from a level and a shell a floor lacks,
 *   and a room, which is never moved, must not wall up the landing or the goods lift;
 * - the network pad: it follows the floor's setting, and reads the zone of the outpost the floor is in;
 * - adverts and research links, which ask where the outpost is and which ships are docked at it.
 *
 * Nothing here charges anyone: a visitor pays through charge_service() and the shop's take_payment() as on an
 * outpost, into the floor's treasury, with nobody needing to be home.
 */

// ===== THE CATALOGUE =====

/**
 * A floor sells every room an outpost does but two: the cargo dock, which needs a ferry and room to land it, and
 * the cell block extension (OUTPOST_FLOOR_MAX_EXTENSIONS, lead decision L9). It also sells the rooms made for
 * floors (floors_only), which the outposts' own answer refuses, so that answer is not asked. The ship bay is not
 * a room: ship_bay_setup_denial().
 */
/obj/structure/overmap/dynamic/player_outpost/floor/offers_upgrade(datum/outpost_upgrade/upgrade)
	if(istype(upgrade, /datum/outpost_upgrade/cargo_dock))
		return FALSE
	if(istype(upgrade, /datum/outpost_upgrade/prison_extension))
		return OUTPOST_FLOOR_MAX_EXTENSIONS > 0
	return TRUE

/// A floor's wing takes OUTPOST_FLOOR_MAX_EXTENSIONS cell blocks, whatever the catalogue allows an outpost
/obj/structure/overmap/dynamic/player_outpost/floor/upgrade_purchase_denial(mob/user, upgrade_id)
	. = ..()
	if(. || !istext(upgrade_id))
		return
	if(!istype(GLOB.outpost_upgrade_catalog[upgrade_id], /datum/outpost_upgrade/prison_extension))
		return
	if(length(owned_upgrades(upgrade_id)) >= OUTPOST_FLOOR_MAX_EXTENSIONS)
		return OUTPOST_FLOOR_MAX_EXTENSIONS == 1 ? "Already installed." : "All [OUTPOST_FLOOR_MAX_EXTENSIONS] built."

/// A floor has no ship bay: the outpost's berths already have the shipyard console. Paid or granted, it is refused.
/obj/structure/overmap/dynamic/player_outpost/floor/ship_bay_setup_denial()
	return "Not sold here."

/// A room has just been placed: the fitters come up (floor_life.dm)
/obj/structure/overmap/dynamic/player_outpost/floor/on_upgrade_placed(datum/outpost_upgrade/upgrade)
	floor?.on_room_placed(upgrade)
	floor?.shop_refresh_signs() // a new Shop room puts OPEN or SHUT on the signs

// ===== PLACEMENT =====

/**
 * The placement map's survey. The outposts' own clamps its region to the claim's build bounds and centres it on
 * the shell, and a floor host has neither, so it would hand the console nothing and no room could ever be placed.
 * A floor's survey is the floor: its whole rectangle, one character a tile from the same rule placement enforces
 * (upgrade_survey_class()), so the hull, the landing and the goods lift draw as ground nothing may cover (A5).
 * Every tile is near the outpost (upgrade_footprint_near_outpost()). Yields.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/build_upgrade_survey()
	var/datum/outpost_floor/surveyed = floor
	var/list/rectangle = surveyed?.bounds
	if(length(rectangle) < 5)
		return null
	var/low_x = rectangle[1]
	var/low_y = rectangle[2]
	var/z = rectangle[5]
	var/width = rectangle[3] - low_x + 1
	var/height = rectangle[4] - low_y + 1
	var/list/protected_rects = upgrade_protected_rects(z)
	var/list/cells = new /list(width * height)
	var/index = 0
	for(var/y in low_y to low_y + height - 1)
		for(var/x in low_x to low_x + width - 1)
			cells[++index] = upgrade_survey_class(locate(x, y, z), protected_rects)
		CHECK_TICK
	// It yielded: the floor may have gone, and its ground with it
	if(QDELETED(src) || floor != surveyed || QDELETED(surveyed))
		return null
	return list(
		"x" = low_x,
		"y" = low_y,
		"z" = z,
		"width" = width,
		"height" = height,
		"cells" = jointext(cells, ""),
		"near" = repeat_string(width * height, "1"),
	)

/**
 * Whether a footprint is close enough to the outpost to build. On an outpost that is OUTPOST_UPGRADE_MAX_GAP
 * tiles from its own ground, so rooms cannot be scattered across a level. A floor is all its crew's own ground
 * inside one hull: anywhere on it is near. What may be covered is still is_upgrade_turf_clear()'s to say.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/upgrade_footprint_near_outpost(turf/bottom_left, turf/top_right)
	return !!(floor?.contains_turf(bottom_left) && floor.contains_turf(top_right))

/**
 * Ground a room may never cover. A room is never moved or sold back, so one set against the landing would wall up
 * the front door for the rest of the round, and one against the goods lift would wall in every delivery. The row
 * of deck beside both stays clear of rooms, and the placement map draws it so. The crew still builds there by hand:
 * what they build, they can take down.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/is_upgrade_ground_reserved(turf/tile, list/protected_rects)
	if(floor && tile)
		var/list/landing = floor.landing_bounds
		if(length(landing) >= 5 && tile.z == landing[5] && tile.x >= landing[1] - 1 && tile.x <= landing[3] + 1 && tile.y >= landing[2] - 1 && tile.y <= landing[4] + 1)
			return TRUE
		for(var/turf/goods_tile in floor.goods_turfs)
			if(goods_tile.z == tile.z && get_dist(goods_tile, tile) <= 1)
				return TRUE
	return ..()

// ===== THE NETWORK PAD =====

/// A floor has no docking, so its pad has no lockdown and no approved crews to follow (lead decision L25)
/obj/structure/overmap/dynamic/player_outpost/floor/pad_follows_dock_modes()
	return FALSE

/// The pad takes whoever the lift would take up alone, by the floor's setting, and nobody else (A54)
/obj/structure/overmap/dynamic/player_outpost/floor/pad_admits(mob/living/traveller)
	return !!floor?.may_visit(traveller)

/// The pad reads the zone of the outpost the floor is in: the host itself is nowhere on the overmap
/obj/structure/overmap/dynamic/player_outpost/floor/network_zone_turf()
	return get_turf(floor?.outpost)

// ===== ADVERTS AND RESEARCH =====

/// An advert names the floor and the outpost it is in, and its pin on the chart is the outpost's
/obj/structure/overmap/dynamic/player_outpost/floor/advert_place()
	var/obj/structure/overmap/trader_outpost/building = floor?.outpost
	if(!building)
		return ..()
	// A trader outpost's name carries \improper, which a chart row would show as a stray character
	var/building_name = format_text(building.name)
	return floor.floor_name ? "[floor.floor_name], [building_name]" : building_name

/obj/structure/overmap/dynamic/player_outpost/floor/advert_coords()
	return floor?.outpost?.get_relative_overmap_coords()

/**
 * Whether `ship` counts as docked here for research links. No ship ever docks with a floor: it is one that the
 * floor's own people crew (a crew the owner is on, or one a resident is on), standing in a berth of this outpost.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/ship_is_home(obj/structure/overmap/ship/ship)
	var/obj/structure/overmap/trader_outpost/building = floor?.outpost
	if(!building || QDELETED(ship) || ship.docked != building)
		return FALSE
	if(is_owner_crew_ship(ship))
		return TRUE
	var/list/datum/mind/crew = ship.ship_team?.members
	for(var/datum/mind/resident in residents)
		if(resident in crew)
			return TRUE
	return FALSE

// ===== THE BOARD =====

/**
 * What this floor offers visitors, as words for the board, in the board's order: Shop, Clinic, Cloning, Lockers,
 * Teleporter, Canteen. One word a room that is built. Shop only while the shop is open (shop_open(),
 * floor_shopfront.dm). A floor nobody holds offers nothing.
 */
/datum/outpost_floor/proc/offers()
	var/list/words = list()
	if(QDELETED(host) || !host.founder_ckey)
		return words
	if(shop_open())
		words += "Shop"
	// Upgrade id -> the board's word. The canteen is floor_base_rooms.dm's.
	var/static/list/room_words = list(
		OUTPOST_MEDICAL_LAB_ID = "Clinic",
		"cloning_bay" = "Cloning",
		"storage" = "Lockers",
		"teleporter" = "Teleporter",
		"canteen" = "Canteen",
	)
	for(var/room_id in room_words)
		if(host.service_upgrade(room_id))
			words += room_words[room_id]
	return words
