/**
 * # Cell block extension
 *
 * Three more cells, a bit more yard and a bit more office, bought from the upgrades catalog and snapped
 * onto a side wall of an outpost's prison wing (owner, 2026-09-25): up to OUTPOST_PRISON_MAX_EXTENSIONS,
 * on either side, for up to ten prisoners. Plan: data/outpost-resources/extension-plan.md.
 *
 * The extension's maps are authored with a seam column of template_noop over the wing's side wall, so
 * loading never touches the wing. Once loaded, its tiles join the wing's own area, its cells join the
 * prison and three declared seam tiles open into the wing.
 */

/// An extension's area while it loads. Its tiles then move into the wing's own area and this one is
/// deleted. A sibling of the prison wing's area, not a subtype, so nothing takes it for a wing meanwhile.
/area/voidcrew/player_outpost/prison_extension
	name = "\improper Prison Wing Extension"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "sec_prison"
	sound_environment = SOUND_AREA_LARGE_ENCLOSED

/// Marks the bottom end of a wall that an extension may join, on the wall tile itself. The upgrade that
/// owns the wall reads these at install and deletes them.
/obj/effect/landmark/outpost_upgrade_snap
	name = "upgrade joint"
	/// Which upgrades may join here
	var/snap_group = "prison_cells"
	/// "right" or "left", the side of the room this wall is on as the room is authored
	var/side
	/// The rows along the wall, counted from this landmark's row as 1, that open once an extension joins
	var/list/seam_openings = list(3, 8, 10)

/// The room's east wall, as authored
/obj/effect/landmark/outpost_upgrade_snap/right
	side = "right"
	dir = EAST

/// The room's west wall, as authored
/obj/effect/landmark/outpost_upgrade_snap/left
	side = "left"
	dir = WEST

/obj/machinery/door/airlock/security/glass/outpost_prison_cell
	/// On an extension's map, which of its cells this is (1-3). It becomes a cell number once the extension joins.
	var/extension_slot = 0

/obj/machinery/button/outpost_prison_bolt
	/// On an extension's map, which of its cells this bolts (1-3). It becomes a cell number once the extension joins.
	var/extension_slot = 0

// ===== THE UPGRADE =====

/// The extension's rooms: two sibling families, one per wall, each with a map per outpost style
/// (outpost_styles.dm). Siblings, because a family is every subtype of its base.
/datum/map_template/outpost_upgrade/prison_extension
	name = "Outpost Prison Wing Extension"

/// The right-hand wall's extension: its seam column is x = 1, and its far wall's joint is at (13,1).
/datum/map_template/outpost_upgrade/prison_extension/right

/datum/map_template/outpost_upgrade/prison_extension/right/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_prison_extension_right_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/prison_extension/right/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_prison_extension_right_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/// The left-hand wall's extension, the right-hand one mirrored: its seam column is x = 13.
/datum/map_template/outpost_upgrade/prison_extension/left
	name = "Outpost Prison Wing Extension (left)"

/datum/map_template/outpost_upgrade/prison_extension/left/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_prison_extension_left_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/prison_extension/left/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_prison_extension_left_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/outpost_upgrade/prison_extension
	id = "prison_extension"
	name = "Cell Block Extension"
	desc = "Three more cells, with yard and office space, built onto the prison wing."
	price = OUTPOST_PRISON_EXTENSION_COST
	max_owned = OUTPOST_PRISON_MAX_EXTENSIONS
	template_type = /datum/map_template/outpost_upgrade/prison_extension/right
	left_template_type = /datum/map_template/outpost_upgrade/prison_extension/left
	area_type = /area/voidcrew/player_outpost/prison_extension
	// The far wall, away from the wing: loose things on the ground are swept out that way.
	entrance_side = EAST
	snap_group = "prison_cells"
	snap_refusal = "Must join the prison wing's side wall."
	seam_refusal = "Prison wing wall blocked."
	/// Whether it has joined the wing: its tiles are the wing's, its cells the prison's and the seam is open
	var/joined = FALSE

/datum/outpost_upgrade/prison_extension/purchase_requirement(obj/structure/overmap/dynamic/player_outpost/home)
	if(!home.running_prison())
		return "Needs a prison wing."
	if(!length(snap_offers(home)))
		return "No free wall on the prison wing."
	return null

/// Not while the wing is in uproar: the seam opens into the cell block, and new cells would change who is where mid-incident.
/datum/outpost_upgrade/prison_extension/placement_denial()
	var/datum/outpost_prison/prison = outpost?.running_prison()
	if(!prison)
		return "Needs a prison wing."
	if(prison.riot_active || prison.breaking_out)
		return "Not during a riot."
	if(prison.loose_count())
		return "Not while prisoners are loose."
	if(prison.experiment_active())
		return "Not during an experiment."
	return null

/// Which way the wing lies from the seam: back across the wall this extension joined
/datum/outpost_upgrade/prison_extension/proc/wing_side_dir()
	return angle2dir(rotation + (snap_side == "left" ? 90 : 270))

/**
 * Joins the wing, in an order that never leaves a way out of the cell block (build plan section 2.3),
 * with nothing in it that sleeps:
 * 1. its tiles move into the wing's own area (the blueprint path, set_turfs_to_area()), so its
 *    machines run off the wing's APC and every check by area now counts it as the wing;
 * 2-7. the prison takes it on (/datum/outpost_prison/proc/add_extension()): new cell numbers, new
 *    cells, the cell block and office side, the seam opened, the floor grown, and a refresh.
 * If the load failed, none of this runs and the wall stays shut.
 */
/datum/outpost_upgrade/prison_extension/on_installed(mob/user)
	if(joined)
		return
	var/datum/outpost_upgrade/prison/wing_upgrade = snap_host()
	var/area/voidcrew/player_outpost/prison/wing = wing_upgrade?.installed_area
	var/list/offer = placed_offer
	if(!istype(wing_upgrade) || !istype(wing) || !offer || !footprint_bounds)
		log_game("PLAYER OUTPOST PRISON: the [name] at '[outpost?.name]' was built with no prison wing to join")
		return
	joined = TRUE
	var/list/seam = offer["seam"]
	var/list/room = list()
	var/list/moving = list()
	for(var/turf/tile as anything in block(footprint_bounds[1], footprint_bounds[2], footprint_bounds[5], footprint_bounds[3], footprint_bounds[4], footprint_bounds[5]))
		if(seam[tile])
			continue
		room += tile
		if(istype(tile.loc, /area/voidcrew/player_outpost/prison_extension))
			moving += tile
	var/list/merged = list()
	set_turfs_to_area(moving, wing, merged)
	wing.reg_in_areas_in_z()
	wing.power_change()
	for(var/area_name in merged)
		var/area/emptied = merged[area_name]
		if(emptied != wing && !emptied.has_contained_turfs())
			qdel(emptied)
	require_area_resort()
	installed_area = wing
	wing_upgrade.extension_bounds += list(footprint_bounds.Copy())
	var/datum/outpost_prison/prison = wing_upgrade.prison
	if(QDELETED(prison))
		// A prison an admin starts again finds all of it.
		wing_upgrade.extension_floor_sizes += 0
		open_seam(offer["openings"])
	else
		prison.add_extension(src, room, offer["openings"])
	var/datum/outpost_patrol_cache/patrol = GLOB.outpost_patrol_caches[REF(outpost)]
	if(patrol)
		patrol.dirty = TRUE

/**
 * Opens the tiles of the joined wall that its joint declares (`openings`): windows and grilles go,
 * and each becomes the floor beside it on the wing's side, so the yard and the office run on through.
 */
/datum/outpost_upgrade/prison_extension/proc/open_seam(list/openings)
	var/wing_dir = wing_side_dir()
	for(var/turf/tile as anything in openings)
		for(var/obj/structure/window/pane in tile)
			qdel(pane)
		for(var/obj/structure/grille/grille in tile)
			qdel(grille)
		var/turf/pattern = get_step(tile, wing_dir)
		if(!isfloorturf(pattern))
			pattern = get_step(tile, REVERSE_DIR(wing_dir))
		if(!isfloorturf(pattern))
			pattern = null
		tile.ChangeTurf(pattern ? pattern.type : /turf/open/floor/iron, pattern?.baseturfs, CHANGETURF_INHERIT_AIR)

// ===== THE PRISON =====

/**
 * Takes on an extension whose tiles (`room`, its seam aside) have just joined the wing's area, and
 * opens the seam tiles in `openings`. Steps 2 to 7 of the build plan's section 2.3, in that order:
 * the cell block and the office side are known before the seam opens, so nothing that goes wrong
 * afterwards can leave prisoners counted as escaped in their own yard.
 */
/datum/outpost_prison/proc/add_extension(datum/outpost_upgrade/prison_extension/extension, list/room, list/openings)
	wing_block_cache = null
	// 2. Its cells take the numbers after the wing's highest: 5-7 for the first, 8-10 for the second.
	var/highest = 0
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		highest = max(highest, cell.number)
	var/list/numbers = list()
	for(var/turf/tile as anything in room)
		for(var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/door in tile)
			if(door.extension_slot)
				door.cell_number = highest + door.extension_slot
				door.name = "Cell [door.cell_number]"
				numbers |= door.cell_number
		for(var/obj/machinery/button/outpost_prison_bolt/button in tile)
			if(button.extension_slot)
				button.cell_number = highest + button.extension_slot
				button.name = "cell [button.cell_number] bolt button"
	// 3. The new cells join the old; nobody in the old ones is disturbed (find_cells() would clear them all).
	var/list/new_cells = add_cells_from(room)
	// 4. The cell block and the office side, flooded from the new cells over the room and the openings.
	var/list/allowed = list()
	for(var/turf/tile as anything in room)
		allowed[tile] = TRUE
	for(var/turf/tile as anything in openings)
		allowed[tile] = TRUE
	var/list/found = list()
	var/list/queue = list()
	for(var/datum/outpost_prison_cell/cell as anything in new_cells)
		for(var/turf/tile as anything in cell.turfs)
			if(!found[tile])
				found[tile] = TRUE
				queue += tile
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || found[next] || !allowed[next] || next.loc != wing)
				continue
			found[next] = TRUE
			if(!isclosedturf(next) && cell_block_passable(next))
				queue += next
	for(var/turf/tile as anything in found)
		cell_block[tile] = TRUE
	if(isnull(staff_ground))
		staff_ground = list()
	for(var/turf/tile as anything in room)
		if(!found[tile] && !isclosedturf(tile) && tile.loc == wing)
			staff_ground[tile] = TRUE
	for(var/turf/tile as anything in openings)
		if(!found[tile])
			staff_ground[tile] = TRUE
	// 5. The seam opens.
	extension.open_seam(openings)
	// 6. The floor grows by the new cell block floor; the yard's old seam windows are floor now.
	var/new_floor = 0
	for(var/turf/tile as anything in found)
		if(!isopenturf(tile) || tile.loc != wing)
			continue
		if(is_wing_structure(tile))
			structure_tiles[tile] = TRUE
			continue
		structure_tiles -= tile
		new_floor++
	if(mess_floor_size)
		mess_floor_size += new_floor
	upgrade.extension_floor_sizes += new_floor
	// 7. Capacity, arrival lanes, the cell block with its doors watched, and the conditions.
	capacity = min(OUTPOST_PRISON_MAX_CAPACITY, length(cells))
	sync_arrival_lanes()
	refresh_cell_block()
	refresh_conditions()
	arrival_countdown = next_arrival_in()
	sortTim(numbers, GLOBAL_PROC_REF(cmp_numeric_asc))
	var/cell_text = "no new cells"
	if(length(numbers) == 1)
		cell_text = "cell [numbers[1]]"
	else if(length(numbers) > 1)
		cell_text = "cells [numbers[1]]-[numbers[length(numbers)]]"
	add_log("The cell block was extended: [cell_text].")
