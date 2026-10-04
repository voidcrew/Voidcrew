/**
 * # Outpost upgrades
 *
 * Prefab rooms an outpost buys from the management console's Upgrades tab. Buying one pays the
 * treasury and leaves an unplaced blueprint on the outpost; cancelling the purchase refunds it.
 * The same tab opens a schematic placement map (OutpostManagement.tsx) that stamps the blueprint
 * onto the main level at any of four rotations, within OUTPOST_UPGRADE_MAX_GAP tiles of the rest
 * of the outpost. Placement is permanent: no relocation, no refund. One of each per outpost, unless
 * the upgrade allows more (max_owned); only one of each may be bought and waiting at a time.
 *
 * A snap upgrade (snap_group) is never placed freely: it joins a wall of another upgrade at a joint
 * that wall's map marks (/obj/effect/landmark/outpost_upgrade_snap, in outpost_prison_extension.dm).
 * Its map's first column lies over that wall as template_noop, so loading never touches the wall;
 * the upgrade opens it itself once it is built. Placement offers every free joint, one position
 * and rotation each (snap_offers()), and a joined room may carry joints of its own on its far wall.
 *
 * The map is drawn from a survey the server takes once per view (and caches briefly): one
 * character per tile, made by the same rules placement enforces, so the client's green and red
 * agree with the server. Mobs are left out of the survey; the server re-checks them at Build.
 *
 * Subtypes set the catalog fields and a family of map templates, one map per outpost style: the
 * outpost's style picks which one it builds (outpost_styles.dm). The cargo dock is the first
 * (outpost_cargo_dock.dm).
 */

// Survey cell classes. The first three are ground an upgrade may cover.
#define UPGRADE_CELL_SPACE "s"
#define UPGRADE_CELL_LATTICE "l"
#define UPGRADE_CELL_FLOOR "f"
#define UPGRADE_CELL_WALL "w"
#define UPGRADE_CELL_WINDOW "g"
#define UPGRADE_CELL_DOOR "d"
#define UPGRADE_CELL_OBJECT "m"
/// Docking pads, berths, the elevator, the arrival point and other upgrades
#define UPGRADE_CELL_RESERVED "x"
/// The placement survey never covers more than this many tiles a side, centred on the outpost's core
#define UPGRADE_SURVEY_WINDOW 128
/// A placement still claiming its blueprint this long after it started, with no map loading, has died
#define UPGRADE_PLACEMENT_WATCHDOG (60 SECONDS)

/// Base for upgrade rooms. Loaded with load_rotated(), never centered or cached. Each room is an
/// abstract subtype with one map-carrying subtype per outpost style.
/datum/map_template/outpost_upgrade
	name = "Outpost Upgrade"

/// The shared template instance for one room map type. Null when the map did not load.
/proc/outpost_upgrade_template(map_type)
	var/static/list/templates = list()
	if(!map_type)
		return null
	if(!(map_type in templates))
		templates[map_type] = new map_type
	var/datum/map_template/template = templates[map_type]
	return template?.width ? template : null

/// Upgrade prototypes by id, in catalog order. They carry no outpost state; buying copies one.
GLOBAL_LIST_INIT(outpost_upgrade_catalog, init_outpost_upgrade_catalog())

/proc/init_outpost_upgrade_catalog()
	var/list/catalog = list()
	for(var/datum/outpost_upgrade/upgrade_type as anything in subtypesof(/datum/outpost_upgrade))
		var/upgrade_id = initial(upgrade_type.id)
		if(!upgrade_id)
			continue
		catalog[upgrade_id] = new upgrade_type
	return catalog

/datum/outpost_upgrade
	/// Catalog key
	var/id
	/// How many of this upgrade one outpost may own. The first's key in outpost_upgrades is its id,
	/// the next ones' "[id]_2" and on, so code that looks an upgrade up by its id finds the first.
	var/max_owned = 1
	/// This one's key in its outpost's outpost_upgrades
	var/key
	var/name = "Outpost Upgrade"
	var/desc = ""
	var/price = 0
	/// The room family this upgrade stamps: an abstract template with one map per outpost style
	var/datum/map_template/template_type
	/// Area type the template uses; the installed instance is found by it
	var/area_type
	/// Edge of the template as authored that holds the entrance
	var/entrance_side = SOUTH

	// Per-outpost state. Catalog prototypes leave these empty.
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	/// What the treasury paid, and what cancelling the purchase refunds
	var/paid = 0
	/// Claimed by a placement whose map load is still running
	var/placing = FALSE
	/// Counts placements, so a watchdog or a late load can tell whether the claim is still its own
	var/placement_serial = 0
	var/installed = FALSE
	/// Degrees clockwise the template was placed at
	var/rotation = 0
	/// list(min_x, min_y, max_x, max_y, z) of the placed footprint, set as soon as placement starts
	var/list/footprint_bounds
	/// The area instance the placement created
	var/area/installed_area

	// Snap upgrades
	/// Set for an upgrade that is only placed against a joint of this group (snap_offers())
	var/snap_group
	/// The room for a joint on a left wall, when it differs from template_type (a right wall's)
	var/datum/map_template/left_template_type
	/// Placement refusals of a snap upgrade: off every joint, and the wall at the joint not whole
	var/snap_refusal = "Must join a matching wall."
	var/seam_refusal = "Repair the wall first."
	/// The side of the joint this one was placed against, "right" or "left"
	var/snap_side
	/// The offer this one was placed from (snap_offer()), for on_installed()
	var/list/placed_offer
	/// Joints on this upgrade's walls, and on the walls of the snap upgrades joined to it
	var/list/datum/outpost_upgrade_snap/snap_points

/datum/outpost_upgrade/New(obj/structure/overmap/dynamic/player_outpost/owner)
	. = ..()
	outpost = owner
	key = id

/datum/outpost_upgrade/Destroy()
	// Deleted on its own (by an admin), it leaves the outpost's list, so it can be bought again.
	if(key && !QDELETED(outpost) && outpost.outpost_upgrades[key] == src)
		outpost.outpost_upgrades -= key
	outpost = null
	installed_area = null
	placed_offer = null
	snap_points = null
	return ..()

/// Called once the room is stamped and initialized. Upgrades wire their own systems in here.
/datum/outpost_upgrade/proc/on_installed(mob/user)
	return

/// Why `home` may not buy this now beyond the shop's own rules, or null. Called on the catalog prototype.
/datum/outpost_upgrade/proc/purchase_requirement(obj/structure/overmap/dynamic/player_outpost/home)
	return null

/// Called on the cleared footprint just before the room loads (service rooms join the outpost area here)
/datum/outpost_upgrade/proc/prepare_ground(list/footprint_turfs)
	return

/// Undoes prepare_ground() when the load built nothing
/datum/outpost_upgrade/proc/release_ground(list/footprint_turfs)
	return

/// A reason this upgrade may not go at `footprint` (footprint_at()) turned `rotation`, beyond the ground checks, or null
/datum/outpost_upgrade/proc/placement_denial(list/footprint, rotation)
	return null

/**
 * A placement that crashed mid-load never comes back to release its blueprint, which would then
 * stay "placing" for good: it could not be placed again or refunded. So each placement arms this.
 * While any map is loading (this one, or the one it is queued behind) it waits another round;
 * otherwise, with the same placement still claiming the blueprint, it puts the blueprint back on
 * the shelf. The load itself is never wrapped in try/catch, which leaves dead maps.
 */
/datum/outpost_upgrade/proc/placement_watchdog(serial)
	if(!placing || serial != placement_serial)
		return
	if(Master.map_loading)
		addtimer(CALLBACK(src, PROC_REF(placement_watchdog), serial), UPGRADE_PLACEMENT_WATCHDOG)
		return
	placement_serial++
	placing = FALSE
	footprint_bounds = null
	rotation = 0
	snap_side = null
	placed_offer = null
	if(!QDELETED(outpost))
		outpost.upgrade_survey = null
	log_game("PLAYER OUTPOST: the [name] placement at '[outpost?.name]' never finished; its blueprint was released")

/**
 * The room's template, shared and uncached: for a joint on `side`'s wall the left room when it
 * differs (left_template_type), in `style` (by default the style of this blueprint's outpost).
 * Null when the family has no map.
 */
/datum/outpost_upgrade/proc/get_template(side, style)
	var/datum/map_template/wanted = (side == "left" && left_template_type) ? left_template_type : template_type
	if(!wanted)
		return null
	style ||= outpost?.outpost_style || OUTPOST_STYLE_DEFAULT
	return outpost_upgrade_template(outpost_style_map(wanted, style))

/// Every map this upgrade can build, in every style: its room's family and, when it has one, its left room's
/datum/outpost_upgrade/proc/all_map_types()
	var/list/maps = outpost_style_maps(template_type)
	. = maps.Copy()
	if(left_template_type)
		. |= outpost_style_maps(left_template_type)

/// The baked preview's asset name for `style` (as get_template()), or null until it exists
/datum/outpost_upgrade/proc/preview_asset(style)
	var/datum/map_template/template = get_template(style = style)
	var/preview = template && outpost_map_preview_name(template.type)
	if(!preview || !fexists("[OUTPOST_PREVIEW_DIR][preview].png"))
		return null
	return "[preview].png"

/**
 * Which edge of the placed footprint the entrance faces for a clockwise rotation. A left wall's room
 * is the right wall's mirrored, so its entrance on an east or west edge is on the other one.
 */
/datum/outpost_upgrade/proc/rotated_entrance(rotation, side = snap_side)
	var/authored = entrance_side
	if(side == "left" && (authored == EAST || authored == WEST))
		authored = REVERSE_DIR(authored)
	return angle2dir(rotation + dir2angle(authored))

/**
 * The footprint for a placement with its bottom-left on `bottom_left`, of the room for `side`:
 * list("bottom_left", "top_right", "turfs", "entrance" = edge turfs, "entrance_dir").
 * Null when the template is missing or the footprint runs off the map.
 */
/datum/outpost_upgrade/proc/footprint_at(turf/bottom_left, rotation, side = snap_side)
	var/datum/map_template/template = get_template(side)
	if(!bottom_left || !template)
		return null
	var/turned = (rotation == 90 || rotation == 270)
	var/turf/top_right = locate(bottom_left.x + (turned ? template.height : template.width) - 1, bottom_left.y + (turned ? template.width : template.height) - 1, bottom_left.z)
	if(!top_right)
		return null
	var/entrance_dir = rotated_entrance(rotation, side)
	var/list/entrance
	switch(entrance_dir)
		if(NORTH)
			entrance = block(bottom_left.x, top_right.y, bottom_left.z, top_right.x, top_right.y, bottom_left.z)
		if(SOUTH)
			entrance = block(bottom_left.x, bottom_left.y, bottom_left.z, top_right.x, bottom_left.y, bottom_left.z)
		if(EAST)
			entrance = block(top_right.x, bottom_left.y, bottom_left.z, top_right.x, top_right.y, bottom_left.z)
		else
			entrance = block(bottom_left.x, bottom_left.y, bottom_left.z, bottom_left.x, top_right.y, bottom_left.z)
	return list(
		"bottom_left" = bottom_left,
		"top_right" = top_right,
		"turfs" = block(bottom_left, top_right),
		"entrance" = entrance,
		"entrance_dir" = entrance_dir,
	)

/datum/outpost_upgrade/proc/contains_turf(turf/tile)
	return footprint_bounds && tile && tile.z == footprint_bounds[5] \
		&& tile.x >= footprint_bounds[1] && tile.y >= footprint_bounds[2] \
		&& tile.x <= footprint_bounds[3] && tile.y <= footprint_bounds[4]

/datum/outpost_upgrade/proc/state_text()
	if(installed)
		return "installed"
	if(outpost)
		return "ready"
	return "available"

// ===== OUTPOST STATE =====

/obj/structure/overmap/dynamic/player_outpost
	/// Bought upgrades by key (the id, then "[id]_2" and on), unplaced blueprints and installed rooms alike
	var/list/datum/outpost_upgrade/outpost_upgrades = list()
	/// The latest placement-map survey (see build_upgrade_survey())
	var/list/upgrade_survey
	var/upgrade_survey_time = 0
	var/upgrade_surveying = FALSE
	/// Weakrefs to management panels waiting for the running survey
	var/list/upgrade_survey_waiters

/// The claim's main level, or null before it loads
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_level_z()
	if(!mapzone || !length(mapzone.z_levels))
		return null
	var/datum/space_level/level = mapzone.z_levels[1]
	return level?.z_value

/// Blueprints bought but not yet placed, in catalog order
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_blueprints()
	var/list/blueprints = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = pending_upgrade(upgrade_id)
		if(upgrade && !upgrade.placing)
			blueprints += upgrade
	return blueprints

/// Every upgrade of this id the outpost owns, bought or installed, in the order they were bought
/obj/structure/overmap/dynamic/player_outpost/proc/owned_upgrades(upgrade_id)
	var/list/found = list()
	for(var/upgrade_key in outpost_upgrades)
		var/datum/outpost_upgrade/upgrade = outpost_upgrades[upgrade_key]
		if(upgrade?.id == upgrade_id)
			found += upgrade
	return found

/// How many upgrades of this id the outpost has built
/obj/structure/overmap/dynamic/player_outpost/proc/installed_upgrade_count(upgrade_id)
	var/count = 0
	for(var/datum/outpost_upgrade/upgrade as anything in owned_upgrades(upgrade_id))
		if(upgrade.installed)
			count++
	return count

/// The one upgrade of this id bought and not yet built (placing or waiting), if any: there is never more than one
/obj/structure/overmap/dynamic/player_outpost/proc/pending_upgrade(upgrade_id)
	for(var/datum/outpost_upgrade/upgrade as anything in owned_upgrades(upgrade_id))
		if(!upgrade.installed)
			return upgrade
	return null

/// The key a new upgrade of this id takes: its id, else "[id]_2" and on, up to `most`; null when none is free
/obj/structure/overmap/dynamic/player_outpost/proc/free_upgrade_key(upgrade_id, most)
	for(var/number in 1 to most)
		var/upgrade_key = number == 1 ? upgrade_id : "[upgrade_id]_[number]"
		if(!outpost_upgrades[upgrade_key])
			return upgrade_key
	return null

/// The placed (or currently placing) upgrade covering a turf, if any
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_at_turf(turf/tile)
	for(var/upgrade_id in outpost_upgrades)
		var/datum/outpost_upgrade/upgrade = outpost_upgrades[upgrade_id]
		if(upgrade?.contains_turf(tile))
			return upgrade
	return null

/// The blueprint a UI action names by its id, when it is bought and not yet placed
/obj/structure/overmap/dynamic/player_outpost/proc/unplaced_upgrade(upgrade_id)
	// UI params are decoded JSON: a number here would index the list by position
	if(!istext(upgrade_id))
		return null
	var/datum/outpost_upgrade/blueprint = pending_upgrade(upgrade_id)
	if(!blueprint || blueprint.placing)
		return null
	return blueprint

/// Buying, placing and cancelling all need management and treasury access.
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_access_denial(mob/user)
	if(!is_current_management_user(user) || !can_spend(user))
		return "Not authorized."
	if(!loaded || loading)
		return "Outpost not ready."
	if(!treasury)
		return "No bank link."
	return null

/// Shared by the Buy button and the purchase itself. Null when the user may buy it now.
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_purchase_denial(mob/user, upgrade_id)
	if(!istext(upgrade_id))
		return "Unknown upgrade."
	var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[upgrade_id]
	if(!prototype)
		return "Unknown upgrade."
	if(pending_upgrade(upgrade_id))
		return "Blueprint already bought."
	if(length(owned_upgrades(upgrade_id)) >= prototype.max_owned)
		return prototype.max_owned == 1 ? "Already installed." : "All [prototype.max_owned] built."
	var/denial = upgrade_access_denial(user)
	if(denial)
		return denial
	if(!prototype.get_template(style = outpost_style))
		return "Upgrade unavailable."
	denial = prototype.purchase_requirement(src)
	if(denial)
		return denial
	if(prototype.price && !treasury.has_money(prototype.price))
		return "Insufficient outpost funds."
	return null

/// Pays the treasury and leaves an unplaced blueprint. Returns null on success, else the reason.
/obj/structure/overmap/dynamic/player_outpost/proc/buy_outpost_upgrade(mob/user, upgrade_id)
	var/denial = upgrade_purchase_denial(user, upgrade_id)
	if(denial)
		return denial
	var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[upgrade_id]
	var/upgrade_key = free_upgrade_key(upgrade_id, prototype.max_owned)
	if(!upgrade_key)
		return "Already installed."
	// adjust_money() refuses a zero amount, so a free upgrade skips the treasury.
	if(prototype.price && !treasury.adjust_money(-prototype.price, "Outpost upgrade: [prototype.name], bought by [user.ckey]"))
		return "Insufficient outpost funds."
	var/datum/outpost_upgrade/blueprint = new prototype.type(src)
	blueprint.paid = prototype.price
	blueprint.key = upgrade_key
	outpost_upgrades[upgrade_key] = blueprint
	log_game("PLAYER OUTPOST: [key_name(user)] bought the [prototype.name] upgrade for [prototype.price] cr at '[name]'")
	to_chat(user, span_notice((prototype.price ? "[prototype.name] ordered. [prototype.price] cr paid from the treasury." : "[prototype.name] ordered.")))
	return null

/// Whether the user may place or cancel the blueprint of this id now. Null when they may.
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_blueprint_denial(mob/user, upgrade_id)
	if(!istext(upgrade_id) || !length(owned_upgrades(upgrade_id)))
		return "No blueprint bought."
	var/datum/outpost_upgrade/pending = pending_upgrade(upgrade_id)
	if(!pending)
		return "Already installed."
	if(pending.placing)
		return "Placement in progress."
	return upgrade_access_denial(user)

/// Refunds exactly what was paid and removes the unplaced blueprint of this id. Null on success.
/obj/structure/overmap/dynamic/player_outpost/proc/cancel_outpost_upgrade(mob/user, upgrade_id)
	var/denial = upgrade_blueprint_denial(user, upgrade_id)
	if(denial)
		return denial
	var/datum/outpost_upgrade/blueprint = pending_upgrade(upgrade_id)
	outpost_upgrades -= blueprint.key
	if(blueprint.paid)
		treasury.adjust_money(blueprint.paid, "Outpost upgrade refund: [blueprint.name], cancelled by [user.ckey]")
	log_game("PLAYER OUTPOST: [key_name(user)] cancelled the [blueprint.name] upgrade at '[name]', refunding [blueprint.paid] cr")
	to_chat(user, span_notice((blueprint.paid ? "[blueprint.name] order cancelled. [blueprint.paid] cr refunded." : "[blueprint.name] order cancelled.")))
	qdel(blueprint)
	return null

// ===== GROUND RULES =====

/**
 * Ground no upgrade may cover on level `z`, as list(x0, y0, x1, y1) corners in any order:
 * every docking port's footprint (the cargo dock pad, docked hulls). Berths and the ship bay
 * are zones outside the build region.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_protected_rects(z)
	var/list/rects = list()
	for(var/obj/docking_port/stationary/dock in SSshuttle.stationary_docking_ports)
		if(dock.z == z)
			rects += list(dock.return_coords())
	for(var/obj/docking_port/mobile/port in SSshuttle.mobile_docking_ports)
		if(port.z == z)
			rects += list(port.return_coords())
	return rects

/// Outpost ground kept free whatever stands on it: docking, berths, the elevator, arrivals, other upgrades.
/obj/structure/overmap/dynamic/player_outpost/proc/is_upgrade_ground_reserved(turf/tile, list/protected_rects)
	if(tile == arrival_turf || (tile in lobby_alcove_turfs) || (tile in lobby_wall_turfs))
		return TRUE
	if(upgrade_at_turf(tile))
		return TRUE
	if(isnull(protected_rects))
		protected_rects = upgrade_protected_rects(tile.z)
	for(var/list/rect as anything in protected_rects)
		if(tile.x >= min(rect[1], rect[3]) && tile.x <= max(rect[1], rect[3]) && tile.y >= min(rect[2], rect[4]) && tile.y <= max(rect[2], rect[4]))
			return TRUE
	for(var/datum/outpost_berth/berth in berths)
		if(berth.contains_turf(tile))
			return TRUE
	for(var/datum/outpost_berth/ship_bay/bay in bay_berths)
		if(bay.contains_turf(tile))
			return TRUE
	return FALSE

/**
 * Whether an upgrade may be stamped over this tile. Pass `protected_rects` from
 * upgrade_protected_rects() when checking many tiles. Lattices and catwalks are cleared by the
 * placement and loose items are moved out of the way (sweep_upgrade_footprint()); decals stay.
 * The survey passes `ignore_mobs`: mobs move, so the server only checks them when the room is
 * actually built. Landmarks never block: a level's teardown keeps them, so a recycled level can
 * carry invisible ones left by deleted hulls.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/is_upgrade_turf_clear(turf/tile, list/protected_rects, ignore_mobs = FALSE)
	if(!is_turf_buildable(tile) || isclosedturf(tile))
		return FALSE
	if(is_upgrade_ground_reserved(tile, protected_rects))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(ismob(thing))
			if(isliving(thing) && !ignore_mobs)
				return FALSE
			continue // camera eyes and observers
		if(istype(thing, /obj/docking_port))
			return FALSE
		if(istype(thing, /obj/structure/lattice) || istype(thing, /obj/effect/decal) || istype(thing, /obj/effect/landmark))
			continue
		if(thing.density || thing.anchored)
			return FALSE
	return TRUE

/**
 * Turfs that count as the outpost for the distance rule: the outpost's own area and every
 * installed upgrade's area on the main level, each area once (a snap upgrade can join another's
 * area). A claim that never got an outpost area falls back to its arrival point and its shell's
 * footprint.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/outpost_owned_turfs()
	var/list/owned = list()
	var/z = upgrade_level_z()
	if(!z)
		return owned
	var/list/counted = list()
	if(outpost_area)
		owned += outpost_area.get_turfs_by_zlevel(z)
		counted[outpost_area] = TRUE
	for(var/upgrade_key in outpost_upgrades)
		var/datum/outpost_upgrade/upgrade = outpost_upgrades[upgrade_key]
		if(!upgrade?.installed || !upgrade.installed_area || counted[upgrade.installed_area])
			continue
		counted[upgrade.installed_area] = TRUE
		owned += upgrade.installed_area.get_turfs_by_zlevel(z)
	if(length(owned))
		return owned
	if(arrival_turf)
		owned += arrival_turf
	if(template_bottom_left && shell_template?.width)
		owned += block(template_bottom_left.x, template_bottom_left.y, template_bottom_left.z, template_bottom_left.x + shell_template.width - 1, template_bottom_left.y + shell_template.height - 1, template_bottom_left.z)
	return owned

/// Whether a footprint has a tile within OUTPOST_UPGRADE_MAX_GAP tiles of outpost ground
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_footprint_near_outpost(turf/bottom_left, turf/top_right)
	var/list/owned = list()
	for(var/turf/owned_turf as anything in outpost_owned_turfs())
		owned[owned_turf] = TRUE
	var/gap = OUTPOST_UPGRADE_MAX_GAP
	for(var/turf/near as anything in block(max(1, bottom_left.x - gap), max(1, bottom_left.y - gap), bottom_left.z, min(world.maxx, top_right.x + gap), min(world.maxy, top_right.y + gap), bottom_left.z))
		if(owned[near])
			return TRUE
	return FALSE

/**
 * Stamps a bought blueprint with its footprint's bottom-left on `bottom_left`, turned `rotation`
 * degrees clockwise. Returns null on success, else the reason. Permanent. A snap upgrade goes only
 * where one of its offers puts it (snap_offers()); the wall it joins is left to it to open.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/place_outpost_upgrade(datum/outpost_upgrade/blueprint, turf/bottom_left, rotation, mob/user)
	if(QDELETED(blueprint) || outpost_upgrades[blueprint.key] != blueprint || blueprint.installed || blueprint.placing)
		return "No upgrade blueprint to place."
	rotation = SIMPLIFY_DEGREES(rotation)
	if(rotation % 90)
		return "Invalid rotation."
	var/list/offer
	if(blueprint.snap_group)
		offer = blueprint.snap_offer_at(bottom_left, rotation)
		if(!offer)
			return blueprint.get_template() ? blueprint.snap_refusal : "Upgrade unavailable."
	var/side = offer?["side"]
	var/datum/map_template/template = blueprint.get_template(side)
	if(!template)
		return "Upgrade unavailable."
	var/list/footprint = offer ? offer["footprint"] : blueprint.footprint_at(bottom_left, rotation)
	if(!footprint)
		return "Invalid position."
	var/list/footprint_turfs = footprint["turfs"]
	var/list/seam = offer?["seam"] || list()
	var/turf/top_right = footprint["top_right"]
	if(offer)
		var/denial = snap_offer_denial(blueprint, offer)
		if(denial)
			return denial
	else
		var/list/protected_rects = upgrade_protected_rects(bottom_left.z)
		for(var/turf/tile as anything in footprint_turfs)
			if(!is_upgrade_turf_clear(tile, protected_rects))
				return "Position obstructed."
		if(!upgrade_footprint_near_outpost(bottom_left, top_right))
			return "Too far from the outpost."
		var/denial = blueprint.placement_denial(footprint, rotation)
		if(denial)
			return denial
	// Claim the blueprint and its ground before the load can yield, so a second Build or an
	// elevator placement finds nothing to work with.
	blueprint.placing = TRUE
	var/serial = ++blueprint.placement_serial
	addtimer(CALLBACK(blueprint, TYPE_PROC_REF(/datum/outpost_upgrade, placement_watchdog), serial), UPGRADE_PLACEMENT_WATCHDOG)
	blueprint.rotation = rotation
	blueprint.snap_side = side
	blueprint.footprint_bounds = list(bottom_left.x, bottom_left.y, top_right.x, top_right.y, bottom_left.z)
	// The seam is the wall being joined: nothing on it is cleared or moved.
	for(var/turf/tile as anything in footprint_turfs)
		if(seam[tile])
			continue
		for(var/obj/structure/lattice/lattice in tile) // catwalks included
			qdel(lattice)
	sweep_upgrade_footprint(footprint, seam)
	blueprint.prepare_ground(footprint_turfs)
	var/list/loaded_bounds = template.load_rotated(bottom_left, rotation)
	// Gone, or the watchdog gave up on this load and released the blueprint meanwhile
	if(QDELETED(blueprint) || blueprint.placement_serial != serial)
		return "The upgrade could not be built."
	blueprint.placing = FALSE
	if(!loaded_bounds || QDELETED(src))
		// Nothing was built: the blueprint goes back on the shelf, and a joined wall stays shut.
		blueprint.release_ground(footprint_turfs)
		blueprint.footprint_bounds = null
		blueprint.rotation = 0
		blueprint.snap_side = null
		return "The upgrade could not be built."
	blueprint.installed = TRUE
	for(var/turf/tile as anything in footprint_turfs)
		if(istype(tile.loc, blueprint.area_type))
			blueprint.installed_area = tile.loc
			break
	// The ground changed under the placement map.
	upgrade_survey = null
	if(offer)
		var/datum/outpost_upgrade_snap/joint = offer["snap"]
		joint.taken_by = blueprint.key
		blueprint.placed_offer = offer
	blueprint.collect_snaps(footprint_turfs)
	blueprint.on_installed(user)
	join_rooms_to_grid() // a corridor may already reach this room's door; the wing/dock/room joins right away
	var/list/entrance = footprint["entrance"]
	playsound(entrance[CEILING(length(entrance) / 2, 1)], 'sound/machines/ding.ogg', 60, TRUE)
	log_game("PLAYER OUTPOST: [key_name(user)] placed the [blueprint.name] upgrade at '[name]' ([bottom_left.x],[bottom_left.y],[bottom_left.z], rotated [rotation])")
	return null

/**
 * Moves loose things off a footprint that is about to be built over, onto the ground outside its
 * entrance, so nothing ends up inside the new walls. Anchored things, effects and decals stay, and
 * so does everything on `skip` (turf = TRUE: the wall a snap upgrade joins, and whatever is beside it).
 */
/obj/structure/overmap/dynamic/player_outpost/proc/sweep_upgrade_footprint(list/footprint, list/skip)
	var/list/entrance = footprint["entrance"]
	var/entrance_dir = footprint["entrance_dir"]
	if(!length(entrance))
		return
	var/turf/outside = get_step(entrance[CEILING(length(entrance) / 2, 1)], entrance_dir)
	if(!outside || isclosedturf(outside))
		outside = null
		for(var/turf/edge as anything in entrance)
			var/turf/beyond = get_step(edge, entrance_dir)
			if(beyond && !isclosedturf(beyond))
				outside = beyond
				break
	if(!outside)
		return
	for(var/turf/tile as anything in footprint["turfs"])
		if(skip?[tile])
			continue
		for(var/atom/movable/thing as anything in tile)
			if(thing.anchored || iseffect(thing) || !(isobj(thing) || isliving(thing)))
				continue
			thing.forceMove(outside)

// ===== SNAP UPGRADES =====

/**
 * A joint on an upgrade's wall where a snap upgrade of its group may be placed, taken from an
 * /obj/effect/landmark/outpost_upgrade_snap on the wall's map. The joint is the wall tile at the
 * bottom end of the seam, which runs along the wall the way the wall's room was placed facing north.
 */
/datum/outpost_upgrade_snap
	var/snap_group
	/// "right" or "left": which wall of its room, as authored
	var/side
	/// The wall tile the landmark stood on
	var/turf/joint
	/// Degrees clockwise the wall's room was placed at. A room joined here is placed the same way.
	var/rotation = 0
	/// Rows along the seam, the joint's row being 1, that open once a room joins here
	var/list/openings
	/// The key of the upgrade whose wall this is
	var/wall_key
	/// The key of the upgrade joined here, null while the joint is free
	var/taken_by

/**
 * Takes the joint landmarks off a room that was just built into a snap registry, and deletes
 * them: its own registry, or for a snap upgrade its host's, so every joint of a group is in one place.
 */
/datum/outpost_upgrade/proc/collect_snaps(list/turfs)
	var/datum/outpost_upgrade/registry = snap_group ? snap_host() : src
	for(var/turf/tile as anything in turfs)
		for(var/obj/effect/landmark/outpost_upgrade_snap/mark in tile)
			registry?.add_snap(mark, src)
			qdel(mark)

/// Registers the joint `mark` stands on, on a wall of `wall_owner`'s room. Returns the joint.
/datum/outpost_upgrade/proc/add_snap(obj/effect/landmark/outpost_upgrade_snap/mark, datum/outpost_upgrade/wall_owner)
	var/datum/outpost_upgrade_snap/snap = new
	snap.snap_group = mark.snap_group
	snap.side = mark.side
	snap.joint = get_turf(mark)
	snap.openings = islist(mark.seam_openings) ? mark.seam_openings.Copy() : list()
	snap.rotation = wall_owner.rotation
	snap.wall_key = wall_owner.key
	LAZYADD(snap_points, snap)
	return snap

/// The built upgrade whose registry holds the joints of this snap upgrade's group, if any
/datum/outpost_upgrade/proc/snap_host(obj/structure/overmap/dynamic/player_outpost/home = outpost)
	if(!snap_group || QDELETED(home))
		return null
	for(var/upgrade_key in home.outpost_upgrades)
		var/datum/outpost_upgrade/other = home.outpost_upgrades[upgrade_key]
		if(!other?.installed || other == src)
			continue
		for(var/datum/outpost_upgrade_snap/snap as anything in other.snap_points)
			if(snap.snap_group == snap_group)
				return other
	return null

/// The tile of the room for `side`, as list(column, row) counted from 1, that lands on the joint: its first column's bottom, over the wall
/datum/outpost_upgrade/proc/snap_anchor(side, datum/map_template/template)
	return side == "left" ? list(template.width, 1) : list(1, 1)

/// Every place this snap upgrade may go at the free joints of its group: one offer each (snap_offer())
/datum/outpost_upgrade/proc/snap_offers(obj/structure/overmap/dynamic/player_outpost/home = outpost)
	var/list/offers = list()
	var/datum/outpost_upgrade/host = snap_host(home)
	if(!host)
		return offers
	for(var/datum/outpost_upgrade_snap/snap as anything in host.snap_points)
		if(snap.snap_group != snap_group || snap.taken_by)
			continue
		var/list/offer = snap_offer(snap)
		if(offer)
			offers += list(offer)
	return offers

/// The offer that puts this snap upgrade's footprint on `bottom_left` at `rotation`, if any
/datum/outpost_upgrade/proc/snap_offer_at(turf/bottom_left, rotation)
	for(var/list/offer as anything in snap_offers())
		if(offer["bottom_left"] == bottom_left && offer["rotation"] == rotation)
			return offer
	return null

/**
 * Where this snap upgrade goes at a joint. The joint's side picks the room, the room is turned the
 * way the wall's room was, and its anchor (snap_anchor()) lands on the joint. Returns
 * list("snap", "side", "bottom_left", "rotation", "footprint" (footprint_at()), "seam" (turf = TRUE:
 * the room's first column, lying over the wall), "openings" (the seam tiles that open)), or null
 * when it would run off the map.
 */
/datum/outpost_upgrade/proc/snap_offer(datum/outpost_upgrade_snap/snap)
	var/datum/map_template/template = get_template(snap.side)
	var/turf/joint = snap.joint
	if(!template || !joint)
		return null
	var/list/anchor = snap_anchor(snap.side, template)
	var/list/offset = rotated_template_offset(anchor[1] - 1, anchor[2] - 1, snap.rotation, template.width, template.height)
	var/turf/bottom_left = locate(joint.x - offset[1], joint.y - offset[2], joint.z)
	if(!bottom_left || template.rotated_template_turf(bottom_left, anchor[1] - 1, anchor[2] - 1, snap.rotation) != joint)
		return null
	var/list/footprint = footprint_at(bottom_left, snap.rotation, snap.side)
	if(!footprint)
		return null
	var/list/seam = list()
	for(var/row in 0 to template.height - 1)
		var/turf/tile = template.rotated_template_turf(bottom_left, anchor[1] - 1, row, snap.rotation)
		if(!tile)
			return null
		seam[tile] = TRUE
	var/list/openings = list()
	for(var/opening in snap.openings)
		var/turf/tile = template.rotated_template_turf(bottom_left, anchor[1] - 1, anchor[2] - 2 + opening, snap.rotation)
		if(tile && seam[tile])
			openings += tile
	return list(
		"snap" = snap,
		"side" = snap.side,
		"bottom_left" = bottom_left,
		"rotation" = snap.rotation,
		"footprint" = footprint,
		"seam" = seam,
		"openings" = openings,
	)

/**
 * Why a snap upgrade can't be built at `offer` now, or null: its own rules first
 * (placement_denial()), then ground off the seam that is not clear, then the wall being joined
 * (snap_seam_denial()). `ignore_mobs` is for the placement map. Tiles off the seam that are not
 * clear are added to `blocked` when it is given.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/snap_offer_denial(datum/outpost_upgrade/blueprint, list/offer, ignore_mobs = FALSE, list/blocked)
	var/list/seam = offer["seam"]
	var/list/footprint = offer["footprint"]
	var/turf/bottom_left = offer["bottom_left"]
	var/list/protected_rects = upgrade_protected_rects(bottom_left.z)
	var/obstructed = FALSE
	for(var/turf/tile as anything in footprint["turfs"])
		if(seam[tile] || is_upgrade_turf_clear(tile, protected_rects, ignore_mobs))
			continue
		obstructed = TRUE
		if(isnull(blocked))
			break
		blocked += tile
	var/denial = blueprint.placement_denial()
	if(denial)
		return denial
	if(obstructed)
		return "Position obstructed."
	return snap_seam_denial(blueprint, offer)

/**
 * Whether the wall a snap upgrade joins is whole, so nothing flows through it before the new room
 * is ready: every seam tile in the host's area; no door, machine or hatch on any of them; every
 * tile that stays wall a wall; and each tile that opens a wall, or floor holding nothing but
 * windows, grilles, cables, items and effects. Returns the blueprint's seam_refusal, or null.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/snap_seam_denial(datum/outpost_upgrade/blueprint, list/offer)
	var/datum/outpost_upgrade/host = blueprint.snap_host()
	var/area/host_area = host?.installed_area
	if(!host_area)
		return blueprint.seam_refusal
	var/list/openings = offer["openings"]
	for(var/turf/tile as anything in offer["seam"])
		if(tile.loc != host_area)
			return blueprint.seam_refusal
		for(var/obj/thing in tile)
			if(istype(thing, /obj/machinery) || istype(thing, /obj/structure/table))
				return blueprint.seam_refusal
		if(isclosedturf(tile))
			continue
		if(!(tile in openings))
			return blueprint.seam_refusal
		for(var/obj/thing in tile)
			if(!istype(thing, /obj/structure/window) && !istype(thing, /obj/structure/grille) && !istype(thing, /obj/structure/cable) && !isitem(thing) && !iseffect(thing))
				return blueprint.seam_refusal
	return null

// ===== PLACEMENT MAP SURVEY =====

/// What the placement map draws for one tile. Open classes are exactly the tiles is_upgrade_turf_clear() accepts, mobs aside.
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_survey_class(turf/tile, list/protected_rects)
	if(is_upgrade_turf_clear(tile, protected_rects, ignore_mobs = TRUE))
		if(locate(/obj/structure/lattice) in tile)
			return UPGRADE_CELL_LATTICE
		return isspaceturf(tile) ? UPGRADE_CELL_SPACE : UPGRADE_CELL_FLOOR
	if(!is_turf_buildable(tile) || is_upgrade_ground_reserved(tile, protected_rects))
		return UPGRADE_CELL_RESERVED
	if(isclosedturf(tile))
		return UPGRADE_CELL_WALL
	if(locate(/obj/machinery/door) in tile)
		return UPGRADE_CELL_DOOR
	if((locate(/obj/structure/window) in tile) || (locate(/obj/structure/grille) in tile))
		return UPGRADE_CELL_WINDOW
	return UPGRADE_CELL_OBJECT

/// The largest side of any catalog room in any style, so the map reaches every legal spot
/proc/largest_outpost_upgrade_side()
	var/largest = 1
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
		for(var/map_type in upgrade.all_map_types())
			var/datum/map_template/template = outpost_upgrade_template(map_type)
			if(template)
				largest = max(largest, template.width, template.height)
	return largest

/// The middle of the outpost's shell, or its arrival point, which the placement survey is centred on
/obj/structure/overmap/dynamic/player_outpost/proc/upgrade_survey_center()
	if(template_bottom_left && shell_template?.width)
		return locate(template_bottom_left.x + round(shell_template.width / 2), template_bottom_left.y + round(shell_template.height / 2), template_bottom_left.z)
	return arrival_turf

/**
 * Surveys the ground around the outpost for the placement map. Yields. Returns
 * list("x", "y", "z", "width", "height", "cells", "near") or null, where `cells` has one
 * UPGRADE_CELL_* character per tile and `near` has "1" where a tile is within
 * OUTPOST_UPGRADE_MAX_GAP of outpost ground. Both run row by row from the bottom-left corner.
 * The region is the outpost ground's bounding box widened by the gap plus the largest room,
 * clamped to the claim and to UPGRADE_SURVEY_WINDOW tiles a side around the outpost's core, so an
 * outpost sprawled across the claim does not survey all of it.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/build_upgrade_survey()
	var/z = upgrade_level_z()
	var/list/owned = outpost_owned_turfs()
	if(!z || !build_bounds || !length(owned))
		return null
	var/low_x = world.maxx
	var/low_y = world.maxy
	var/high_x = 1
	var/high_y = 1
	for(var/turf/owned_turf as anything in owned)
		low_x = min(low_x, owned_turf.x)
		low_y = min(low_y, owned_turf.y)
		high_x = max(high_x, owned_turf.x)
		high_y = max(high_y, owned_turf.y)
	var/margin = OUTPOST_UPGRADE_MAX_GAP + largest_outpost_upgrade_side()
	low_x = max(build_bounds[1], low_x - margin)
	low_y = max(build_bounds[2], low_y - margin)
	high_x = min(build_bounds[3], high_x + margin)
	high_y = min(build_bounds[4], high_y + margin)
	var/turf/center = upgrade_survey_center()
	if(center)
		var/half = round(UPGRADE_SURVEY_WINDOW / 2)
		low_x = max(low_x, center.x - half)
		low_y = max(low_y, center.y - half)
		high_x = min(high_x, center.x - half + UPGRADE_SURVEY_WINDOW - 1)
		high_y = min(high_y, center.y - half + UPGRADE_SURVEY_WINDOW - 1)
	var/width = high_x - low_x + 1
	var/height = high_y - low_y + 1
	if(width < 1 || height < 1)
		return null

	// Near mask: mark outpost ground, then widen by the gap along rows, then along columns.
	var/gap = OUTPOST_UPGRADE_MAX_GAP
	var/list/marks = new /list(width * height)
	for(var/turf/owned_turf as anything in owned)
		if(owned_turf.x >= low_x && owned_turf.x <= high_x && owned_turf.y >= low_y && owned_turf.y <= high_y)
			marks[(owned_turf.y - low_y) * width + (owned_turf.x - low_x) + 1] = TRUE
	var/list/row_near = new /list(width * height)
	var/list/prefix = new /list(max(width, height) + 1)
	for(var/row in 0 to height - 1)
		prefix[1] = 0
		for(var/column in 1 to width)
			prefix[column + 1] = prefix[column] + (marks[row * width + column] ? 1 : 0)
		for(var/column in 1 to width)
			if(prefix[min(width, column + gap) + 1] - prefix[max(1, column - gap)] > 0)
				row_near[row * width + column] = TRUE
		CHECK_TICK
	var/list/near = new /list(width * height)
	for(var/column in 1 to width)
		prefix[1] = 0
		for(var/row in 1 to height)
			prefix[row + 1] = prefix[row] + (row_near[(row - 1) * width + column] ? 1 : 0)
		for(var/row in 1 to height)
			near[(row - 1) * width + column] = (prefix[min(height, row + gap) + 1] - prefix[max(1, row - gap)] > 0) ? "1" : "0"
		CHECK_TICK

	var/list/protected_rects = upgrade_protected_rects(z)
	var/list/cells = new /list(width * height)
	var/index = 0
	for(var/y in low_y to high_y)
		for(var/x in low_x to high_x)
			cells[++index] = upgrade_survey_class(locate(x, y, z), protected_rects)
		CHECK_TICK
	if(QDELETED(src))
		return null
	return list(
		"x" = low_x,
		"y" = low_y,
		"z" = z,
		"width" = width,
		"height" = height,
		"cells" = jointext(cells, ""),
		"near" = jointext(near, ""),
	)

/**
 * Gets a survey to the panel: the cached one while fresh, else a new one in the background.
 * Nothing is pushed when a survey starts: ui_data's `upgrade_surveying` already shows
 * "Surveying", and a second static push inside tgui's refresh cooldown remounts the window.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/request_upgrade_survey(datum/player_outpost_management_ui/panel, force = FALSE)
	LAZYOR(upgrade_survey_waiters, WEAKREF(panel))
	if(upgrade_surveying)
		return
	if(!force && upgrade_survey && world.time < upgrade_survey_time + OUTPOST_UPGRADE_SURVEY_LIFETIME)
		notify_upgrade_survey()
		return
	upgrade_surveying = TRUE
	INVOKE_ASYNC(src, PROC_REF(run_upgrade_survey))

/obj/structure/overmap/dynamic/player_outpost/proc/run_upgrade_survey()
	var/list/survey = build_upgrade_survey()
	if(QDELETED(src))
		return
	upgrade_surveying = FALSE
	upgrade_survey = survey
	upgrade_survey_time = world.time
	notify_upgrade_survey()

/obj/structure/overmap/dynamic/player_outpost/proc/notify_upgrade_survey()
	for(var/datum/weakref/panel_ref as anything in upgrade_survey_waiters)
		var/datum/player_outpost_management_ui/panel = panel_ref.resolve()
		if(!QDELETED(panel))
			panel.push_static_data()
	upgrade_survey_waiters = null

// ===== MANAGEMENT CONSOLE =====

/datum/asset/simple/outpost_upgrade_previews

/datum/asset/simple/outpost_upgrade_previews/register()
	assets = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
		for(var/map_type in upgrade.all_map_types())
			var/preview = outpost_map_preview_name(map_type)
			if(fexists("[OUTPOST_PREVIEW_DIR][preview].png"))
				assets["[preview].png"] = file("[OUTPOST_PREVIEW_DIR][preview].png")
			else
				log_asset("outpost_upgrade_previews: missing preview image [preview].png for [upgrade.id]")
	// The ship bay is sold in the same list as the rooms
	for(var/map_type in outpost_style_maps(/datum/map_template/outpost_hangar/ship_bay))
		var/preview = outpost_map_preview_name(map_type)
		if(fexists("[OUTPOST_PREVIEW_DIR][preview].png"))
			assets["[preview].png"] = file("[OUTPOST_PREVIEW_DIR][preview].png")
		else
			log_asset("outpost_upgrade_previews: missing preview image [preview].png for the ship bay")
	return ..()

/datum/player_outpost_management_ui
	/// Why the last upgrade action was refused, or null. The user is told in chat.
	var/upgrade_error
	/// Whether this panel has its placement map open and wants the survey in its static data
	var/wants_upgrade_survey = FALSE
	/// The id of the upgrade whose placement map is open, for a snap upgrade's joints
	var/placing_upgrade_id
	/// world.time of this panel's last static data push (see push_static_data())
	var/last_static_push = 0

/**
 * The only way this panel pushes static data. A second full update inside tgui's
 * TGUI_REFRESH_FULL_UPDATE_COOLDOWN makes the window show its "refreshing" screen and
 * remount the interface, which throws away the tab and placement map the player had open.
 * So a push that comes too soon after the last one waits out the remainder, and pushes that
 * pile up while it waits collapse into one, sent with whatever the data is by then.
 */
/datum/player_outpost_management_ui/proc/push_static_data()
	if(QDELETED(src))
		return
	var/wait = last_static_push ? last_static_push + TGUI_REFRESH_FULL_UPDATE_COOLDOWN - world.time : 0
	for(var/datum/tgui/window as anything in open_uis)
		// Covers full updates this panel did not send, such as the client's own refresh.
		wait = max(wait, COOLDOWN_TIMELEFT(window, refresh_cooldown))
		// A window that has not finished opening drops full updates, and it is about to get
		// this data with its first one anyway.
		if(!window.initialized)
			wait = max(wait, 1)
	if(wait > 0)
		addtimer(CALLBACK(src, PROC_REF(push_static_data)), wait, TIMER_UNIQUE)
		return
	last_static_push = world.time
	update_static_data_for_all_viewers()

/datum/player_outpost_management_ui/ui_static_data(mob/user)
	var/list/catalog = list()
	// The catalog shows each room as this outpost would build it
	var/style = outpost?.outpost_style || OUTPOST_STYLE_DEFAULT
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
		var/datum/map_template/template = upgrade.get_template(style = style)
		catalog += list(list(
			"id" = upgrade_id,
			"name" = upgrade.name,
			"desc" = upgrade.desc,
			"price" = upgrade.price,
			"width" = template?.width || 0,
			"height" = template?.height || 0,
			"preview" = upgrade.preview_asset(style),
			"snap" = !!upgrade.snap_group,
		))
	// The survey can be tens of kilobytes: static data only, and only while a map is open. The key
	// is always sent, because tgui merges static data into the old state and would keep a stale one.
	var/show_survey = wants_upgrade_survey && !QDELETED(outpost) && !outpost.upgrade_surveying
	var/datum/map_template/bay_template = outpost_ship_bay_template(style)
	return list(
		"upgrade_catalog" = catalog,
		"ship_bay_preview" = outpost_ship_bay_preview(style),
		"ship_bay_width" = bay_template?.width || 0,
		"ship_bay_height" = bay_template?.height || 0,
		"upgrade_survey" = show_survey ? outpost.upgrade_survey : null,
		"upgrade_snaps" = show_survey ? upgrade_snap_payload() : null,
	)

/**
 * The joints a snap upgrade's placement map offers, worked out afresh: list of
 * {x, y (the footprint's bottom-left), rotation, side, reason (why not, or null), blocked,
 * openings (lists of [x, y])}. Null while the map open is not a snap upgrade's.
 */
/datum/player_outpost_management_ui/proc/upgrade_snap_payload()
	var/datum/outpost_upgrade/blueprint = outpost.unplaced_upgrade(placing_upgrade_id)
	if(!blueprint?.snap_group)
		return null
	var/list/payload = list()
	for(var/list/offer as anything in blueprint.snap_offers())
		var/list/blocked = list()
		var/reason = outpost.snap_offer_denial(blueprint, offer, TRUE, blocked)
		var/turf/bottom_left = offer["bottom_left"]
		payload += list(list(
			"x" = bottom_left.x,
			"y" = bottom_left.y,
			"rotation" = offer["rotation"],
			"side" = offer["side"],
			"reason" = reason,
			"blocked" = outpost_upgrade_coordinates(blocked),
			"openings" = outpost_upgrade_coordinates(offer["openings"]),
		))
	return payload

/// list(list(x, y), ...) for the placement map
/proc/outpost_upgrade_coordinates(list/turfs)
	var/list/coordinates = list()
	for(var/turf/tile as anything in turfs)
		coordinates += list(list(tile.x, tile.y))
	return coordinates

/// Per-outpost state for each catalog entry: list("id", "state", "denial", "manage_denial")
/datum/player_outpost_management_ui/proc/upgrade_ui_data(mob/user)
	var/list/states = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[upgrade_id]
		var/datum/outpost_upgrade/pending = outpost.pending_upgrade(upgrade_id)
		var/state = "available"
		if(pending)
			state = pending.state_text()
		else if(outpost.installed_upgrade_count(upgrade_id) >= prototype.max_owned)
			state = "installed"
		states += list(list(
			"id" = upgrade_id,
			"state" = state,
			"denial" = outpost.upgrade_purchase_denial(user, upgrade_id),
			"manage_denial" = length(outpost.owned_upgrades(upgrade_id)) ? outpost.upgrade_blueprint_denial(user, upgrade_id) : null,
		))
	return states

/**
 * Upgrades tab and placement map actions. The caller has already checked management access.
 * A refusal is kept in upgrade_error and told to the user in chat.
 */
/datum/player_outpost_management_ui/proc/upgrade_action(action, list/params, mob/living/user)
	upgrade_error = null
	switch(action)
		if("buy_upgrade")
			upgrade_error = outpost.buy_outpost_upgrade(user, params["id"])
		if("cancel_upgrade")
			upgrade_error = outpost.cancel_outpost_upgrade(user, params["id"])
			if(!upgrade_error)
				close_upgrade_map()
		if("open_upgrade_map", "refresh_upgrade_map")
			upgrade_error = outpost.upgrade_blueprint_denial(user, params["id"])
			if(!upgrade_error)
				wants_upgrade_survey = TRUE
				placing_upgrade_id = params["id"]
				outpost.request_upgrade_survey(src, force = (action == "refresh_upgrade_map"))
		if("close_upgrade_map")
			close_upgrade_map()
		if("place_upgrade")
			upgrade_error = place_upgrade_from_map(user, params)
			if(!upgrade_error)
				close_upgrade_map()
	if(upgrade_error)
		to_chat(user, span_warning(upgrade_error))
	return TRUE

/datum/player_outpost_management_ui/proc/close_upgrade_map()
	if(!wants_upgrade_survey)
		return
	wants_upgrade_survey = FALSE
	placing_upgrade_id = null
	push_static_data()

/// Build from the placement map: world coordinates of the footprint's bottom-left and a rotation.
/datum/player_outpost_management_ui/proc/place_upgrade_from_map(mob/living/user, list/params)
	var/upgrade_id = params["id"]
	var/denial = outpost.upgrade_blueprint_denial(user, upgrade_id)
	if(denial)
		return denial
	var/x = params["x"]
	var/y = params["y"]
	var/rotation = params["rotation"]
	if(!isnum(x) || !isnum(y) || !(rotation in list(0, 90, 180, 270)))
		return "Invalid position."
	var/z = outpost.upgrade_level_z()
	var/turf/bottom_left = z && locate(round(x), round(y), z)
	if(!bottom_left)
		return "Invalid position."
	var/datum/outpost_upgrade/blueprint = outpost.unplaced_upgrade(upgrade_id)
	var/error = outpost.place_outpost_upgrade(blueprint, bottom_left, rotation, user)
	if(!error)
		to_chat(user, span_notice("[blueprint.name] installed."))
	return error

#undef UPGRADE_CELL_SPACE
#undef UPGRADE_CELL_LATTICE
#undef UPGRADE_CELL_FLOOR
#undef UPGRADE_CELL_WALL
#undef UPGRADE_CELL_WINDOW
#undef UPGRADE_CELL_DOOR
#undef UPGRADE_CELL_OBJECT
#undef UPGRADE_CELL_RESERVED
#undef UPGRADE_SURVEY_WINDOW
#undef UPGRADE_PLACEMENT_WATCHDOG
