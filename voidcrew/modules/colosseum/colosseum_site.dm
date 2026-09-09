/**
 * # The Grand Colosseum: overmap site
 *
 * A monumental PvP event venue surfaced mid-round by the Grand Colosseum
 * dynamic event (colosseum_event.dm), never at roundstart. One per round.
 *
 * Mirrors the trader-outpost pattern for docking: ships dock into per-ship
 * hangar berths (voidcrew/modules/trade/outpost_hangar.dm) and ride the alcove
 * elevator up to the concourse. The building itself is indestructible by
 * construction, every structural turf in the template is
 * /turf/closed/indestructible or /turf/open/indestructible, and the only ways
 * onto the fighting floor are the ten id-tagged poddoors this site collects at
 * load.
 *
 * The venue is two levels: the arena floor (dmm z1) and an upstairs
 * observation gallery (dmm z2), an openspace ring behind an indestructible
 * glass parapet, reached by the staircases in the lobby pockets. The file
 * follows the standard tg multi-z convention (z1 = bottom), so editors pair
 * the floors correctly. Unlike trader outposts the interior loads onto REAL
 * stacked z-levels minted at open (linked with ZTRAIT_UP/ZTRAIT_DOWN, so the
 * engine's native multiz rendering and plane offsets apply, no
 * reservation-faked verticality). Every landmark coordinate (and the dry-run
 * harness's) is expressed on the arena-floor slice.
 *
 * Unlike trader outposts the site is event-spawned, but like them it never
 * unloads once open: matches must be repeatable indefinitely, so the interior
 * (and all match state on it) stays for the rest of the round.
 */

/// The one colosseum this round, or null. Guards against double-spawns
/// (event + admin verb), UNIQUE_AREA interiors cannot coexist anyway.
GLOBAL_DATUM(colosseum_site, /obj/structure/overmap/colosseum)

/datum/map_template/colosseum
	name = "Grand Colosseum"
	mappath = "voidcrew/_maps/map_files/events/grand_colosseum_main.dmm"
	/// Number of z-slices in the map file. Standard tg multi-z convention:
	/// slice 1 is the BOTTOM of the stack (the arena floor), higher slices
	/// stack upward. load_level() loads slice i onto the i-th minted z-level.
	var/z_count = 1

/datum/map_template/colosseum/preload_size(path, cache)
	. = ..()
	if(islist(.))
		z_count = max(1, .[MAP_MAXZ])

/**
 * Loads a single z-slice of the (possibly multi-z) map file at T, mirroring
 * /datum/map_template/load for one slice. load_level() places each slice on
 * its own real z-level of the venue's stack, so GET_TURF_ABOVE/BELOW resolve
 * through the engine's own z linkage.
 */
/datum/map_template/colosseum/proc/load_z_slice(turf/placement, slice)
	if(!placement)
		return FALSE
	if((placement.x + width) - 1 > world.maxx)
		return FALSE
	if((placement.y + height) - 1 > world.maxy)
		return FALSE

	// clear the border from active atmos processing, as load() does
	var/list/to_rebuild = SSair.adjacent_rebuild
	for(var/turf/border_turf as anything in CORNER_BLOCK_OFFSET(placement, width + 2, height + 2, -1, -1))
		SSair.remove_from_active(border_turf)
		to_rebuild -= border_turf
		for(var/turf/sub_turf as anything in border_turf.atmos_adjacent_turfs)
			sub_turf.atmos_adjacent_turfs?.Remove(border_turf)
		border_turf.atmos_adjacent_turfs?.Cut()

	var/datum/parsed_map/parsed = new(file(mappath))
	if(!parsed.load(
		placement.x,
		placement.y,
		placement.z,
		crop_map = TRUE,
		no_changeturf = (SSatoms.initialized == INITIALIZATION_INSSATOMS),
		z_lower = slice,
		z_upper = slice,
		place_on_top = should_place_on_top,
	))
		return FALSE
	var/list/bounds = parsed.bounds
	if(!bounds)
		return FALSE
	require_area_resort()
	initTemplateBounds(bounds)
	log_game("[name] (z-slice [slice]) loaded at [placement.x],[placement.y],[placement.z]")
	return TRUE

// ===== INTERIOR LANDMARKS =====
// Consumed (or indexed) by link_interior(). All are optional in the map:
// every consumer has a geometric fallback so hand-edits can't brick the venue.

/obj/effect/landmark/colosseum
	name = "colosseum landmark"

/// Contestant seating spot in the red team ready room.
/obj/effect/landmark/colosseum/spawn_red
	name = "colosseum red seating"

/// Contestant seating spot in the blue team ready room.
/obj/effect/landmark/colosseum/spawn_blue
	name = "colosseum blue seating"

/// Contestant seating spot in one solo cell (one landmark per cell).
/obj/effect/landmark/colosseum/spawn_cell
	name = "colosseum cell seating"

/// Red CTF flag plinth (arena west).
/obj/effect/landmark/colosseum/flag_red
	name = "colosseum red flag plinth"

/// Blue CTF flag plinth (arena east).
/obj/effect/landmark/colosseum/flag_blue
	name = "colosseum blue flag plinth"

/// King-of-the-hill dais marker (arena center).
/obj/effect/landmark/colosseum/koth
	name = "colosseum dais marker"

/// Candidate spot for dynamic arena events (crate drops, hazards, cover).
/obj/effect/landmark/colosseum/arena_event
	name = "colosseum arena event spot"

/// Where corpses are laid out for retrieval after the claim window.
/obj/effect/landmark/colosseum/infirmary
	name = "colosseum infirmary berth"

// ===== THE OVERMAP SITE =====

/obj/structure/overmap/colosseum
	name = "the Grand Colosseum"
	desc = "A huge stone arena carved into a bedrock shard, tougher than anything you're carrying. The standing broadcast invites all comers: fight, wager, or watch."
	icon = 'voidcrew/modules/colosseum/icons/colosseum.dmi'
	icon_state = "colosseum_token"
	fleet_waypoint_name = "Grand Colosseum"

	/// Which template datum to load (set before open_venue)
	var/template_type = /datum/map_template/colosseum
	/// The interior template instance
	var/datum/map_template/colosseum/template
	/// The real z-levels holding the interior, bottom (arena floor) to top
	/// (gallery). Minted once by load_level(); real z-levels cannot be
	/// unminted, and the venue never unloads anyway.
	var/list/datum/space_level/interior_levels
	/// Whether the interior has been loaded
	var/loaded = FALSE
	/// Whether the interior is currently loading
	var/loading = FALSE
	/// Internal wideband transmitter for galaxy-wide announcements
	var/obj/item/radio/headset/radio
	/// The match controller running this venue's state machine
	var/datum/colosseum_controller/controller
	/// The concourse signup console (mapped, or fallback-spawned at link)
	var/obj/machinery/computer/colosseum_signup/signup_console
	/// The spoils vault (mapped, or fallback-spawned at link)
	var/obj/machinery/colosseum_vault/spoils_vault
	/// The wagering hall's bookmaker console (mapped, or fallback-spawned at link)
	var/obj/machinery/computer/colosseum_bookmaker/bookmaker
	/// The concourse gear stall's lanista (mapped, or fallback-spawned at link)
	var/mob/living/basic/outpost_trader/colosseum/armory_trader

	/// Arena gate poddoors, keyed by mapped id ("colo_gate_red" -> list of doors)
	var/list/gate_doors = list()
	/// Every mapped ETA board in the venue (wired by link_interior)
	var/list/obj/machinery/status_display/colosseum/status_displays = list()
	/// All interior turfs per colosseum area typepath (area typepath -> list of turfs)
	var/list/area_turfs = list()
	/// Landmark-marked turfs, keyed by landmark typepath -> list of turfs.
	/// Landmarks are deleted at link; only their turfs are kept.
	var/list/landmark_turfs = list()

/// Arena and gallery are dedicated levels; hangars use the shared berth bounds.
/obj/structure/overmap/colosseum/contains_site_turf(turf/location)
	if(..())
		return TRUE
	if(!location)
		return FALSE
	for(var/datum/space_level/level as anything in interior_levels)
		if(level.z_value == location.z)
			return TRUE
	return FALSE

/obj/structure/overmap/colosseum/Initialize(mapload)
	. = ..()
	if(GLOB.colosseum_site && GLOB.colosseum_site != src)
		stack_trace("Second colosseum spawned while one already exists, deleting the newcomer.")
		return INITIALIZE_HINT_QDEL
	GLOB.colosseum_site = src
	berths = new /list(OUTPOST_MAX_BERTHS)
	radio = new(src)
	radio.subspace_transmission = TRUE
	radio.canhear_range = 0
	radio.set_listening(FALSE)
	radio.recalculateChannels()

/obj/structure/overmap/colosseum/Destroy()
	if(GLOB.colosseum_site == src)
		GLOB.colosseum_site = null
	clear_fleet_waypoint()
	QDEL_NULL(controller)
	QDEL_NULL(radio)
	signup_console = null
	spoils_vault = null
	bookmaker = null
	armory_trader = null
	// Admin deletion must not leak hangar reservations
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth)
			berth.release(force = TRUE)
	berths = null
	lobby_alcove_turfs.Cut()
	lobby_wall_turfs.Cut()
	lobby_panels.Cut()
	gate_doors.Cut()
	for(var/obj/machinery/status_display/colosseum/board as anything in status_displays)
		board.site = null
	status_displays.Cut()
	area_turfs.Cut()
	landmark_turfs.Cut()
	template_bottom_left = null
	// The interior z-levels themselves persist: z-levels can't be deleted.
	// Admin-deleting the site just leaves them as sealed, unreachable space.
	interior_levels = null
	return ..()

/obj/structure/overmap/colosseum/examine(mob/user)
	. = ..()
	. += span_notice("All vessels welcome. Contestants register at the concourse; spectators watch from behind the glass.")

// ===== ANNOUNCEMENTS =====

/**
 * Galaxy-wide broadcast: a Wideband transmission (in-fiction, reaches every
 * headset) plus a priority announcement (guaranteed delivery to players without
 * radios). Wideband is unscoped, so the site's z-level doesn't matter, see
 * voidcrew/modules/comms/comms.dm.
 */
/obj/structure/overmap/colosseum/proc/broadcast_galaxy(message, title = "Grand Colosseum")
	priority_announce(message, title, sender_override = "Grand Colosseum Master of Games")
	radio?.talk_into(src, message, RADIO_CHANNEL_WIDEBAND)

/// Human-readable overmap grid position for announcements.
/obj/structure/overmap/colosseum/proc/coords_text()
	var/list/coords = get_relative_overmap_coords()
	return coords ? "grid [coords[1]], [coords[2]]" : "an unknown position"

/**
 * Opens the venue: loads the interior, reveals the site, pushes a helm waypoint
 * to every crewed ship and tells the galaxy the games are on. Called once by
 * the spawn event (or the admin force-spawn) right after placement.
 */
/obj/structure/overmap/colosseum/proc/open_venue()
	load_level()
	if(!loaded)
		log_mapping("COLOSSEUM: interior failed to load, retiring the site.")
		qdel(src)
		return FALSE
	surveyed = TRUE
	controller = new(src)
	// The boards loaded before the controller existed and parked themselves
	update_status_displays()

	broadcast_galaxy("The Grand Colosseum has surfaced at [coords_text()]! Prizes for contestants, wagering and drinks for everyone else. Dock and register at the concourse.")
	// Registers as well as pushes: the venue stands for the rest of the round, so
	// a hull built later still gets told where the door is.
	broadcast_fleet_waypoint()
	notify_ghosts("The Grand Colosseum has surfaced at [coords_text()]!", source = src, header = "Grand Colosseum")
	log_game("Grand Colosseum surfaced at overmap [coords_text()].")
	return TRUE

// ===== INTERIOR LOAD / LINK =====

/**
 * Loads the colosseum interior onto freshly minted REAL z-levels, one per map
 * slice, linked into a stack with ZTRAIT_UP/ZTRAIT_DOWN. Load once, keep for
 * the round, z-levels cannot be unminted, which the permanent venue never
 * needed anyway.
 */
/obj/structure/overmap/colosseum/proc/load_level()
	if(loading || length(interior_levels))
		return
	loading = TRUE

	if(!template)
		template = new template_type

	if(!template.width || !template.height)
		log_mapping("COLOSSEUM: template has no dimensions, cannot load.")
		loading = FALSE
		return

	// The venue is the one thing in the tree that mints REAL z-levels outside the map
	// zone lattice, and a whole stack of them at once - so ask for the whole stack up
	// front. add_new_zlevel() enforces nothing on its own, which is how this used to walk
	// straight past the ceiling and cost the round two permanent levels without a log line.
	if(!SSmapping.z_headroom(template.z_count))
		var/refusal = "COLOSSEUM: load refused - needs [template.z_count] z-level\s, world.maxz [world.maxz] against effective ceiling \
			[SSmapping.effective_z_ceiling()]. Raise MAX_Z_LEVELS or wait for pop/sites to fall."
		log_mapping(refusal)
		message_admins(refusal)
		// Same shape as the other aborts below: no levels minted, no bottom-left, not
		// loaded - open_venue() sees !loaded and retires the site.
		loading = FALSE
		return

	// Mint the stack bottom-up with LoadGroup-style trait autosetup (bottom
	// gets UP, top gets DOWN, middles both) so manage_z_level assigns real
	// plane offsets. GET_TURF_ABOVE/update_plane_tracking assume linked levels
	// sit on consecutive z indices; back-to-back add_new_zlevel calls guarantee
	// that (no sleeps between our calls), the check below is pure paranoia.
	interior_levels = list()
	for(var/stack_index in 1 to template.z_count)
		var/list/level_traits = list()
		if(stack_index > 1)
			level_traits[ZTRAIT_DOWN] = TRUE
		if(stack_index < template.z_count)
			level_traits[ZTRAIT_UP] = TRUE
		var/datum/space_level/level = SSmapping.add_new_zlevel("Grand Colosseum ([stack_index] of [template.z_count])", level_traits)
		if(length(interior_levels) && level.z_value != interior_levels[length(interior_levels)].z_value + 1)
			log_mapping("COLOSSEUM: interior z-levels came out non-consecutive ([interior_levels[length(interior_levels)].z_value] then [level.z_value]). Multiz linkage would be wrong, aborting load.")
			loading = FALSE
			return
		interior_levels += level

	var/placement_x = round((world.maxx - template.width) / 2) + 1
	var/placement_y = round((world.maxy - template.height) / 2) + 1
	// The arena floor is always the file's FIRST slice, and every landmark
	// coordinate (DESIGN.md, local_turf) is expressed on it.
	template_bottom_left = locate(placement_x, placement_y, interior_levels[1].z_value)

	var/load_success = TRUE
	try
		// Bottom-up, so openspace on upper slices initializes with its
		// below-turf already in place. dmm slice 1 is the bottom of the stack.
		for(var/stack_index in 1 to template.z_count)
			var/datum/space_level/level = interior_levels[stack_index]
			if(!template.load_z_slice(locate(placement_x, placement_y, level.z_value), stack_index))
				log_mapping("COLOSSEUM: failed to load z-slice [stack_index].")
				load_success = FALSE
				break
	catch(var/exception/e)
		log_mapping("COLOSSEUM: failed to load template: [e] ([e.file], line [e.line])")
		load_success = FALSE

	if(!load_success)
		// The minted levels can't be freed; leave them referenced so a retry
		// can't mint more. open_venue() retires the site on !loaded.
		template_bottom_left = null
		loading = FALSE
		return

	link_interior()

	loaded = TRUE
	loading = FALSE

/// Resolves a template-local coordinate (1-based, as in DESIGN.md) to a live turf.
/obj/structure/overmap/colosseum/proc/local_turf(x, y)
	if(!template_bottom_left)
		return null
	return locate(template_bottom_left.x + x - 1, template_bottom_left.y + y - 1, template_bottom_left.z)

/**
 * Scans the freshly loaded footprint and indexes everything match logic needs:
 * elevator alcove/panels (berth-host wiring), the ten gate poddoors by id,
 * per-area turf lists and all colosseum landmarks. Idempotent by construction.
 * It only ever runs once per load, but collections are rebuilt from scratch.
 */
/obj/structure/overmap/colosseum/proc/link_interior()
	if(!template_bottom_left || !length(interior_levels))
		return
	gate_doors = list()
	area_turfs = list()
	landmark_turfs = list()
	// Every level of the z-stack: a multi-z venue can mount boards
	// (or, one day, gates/landmarks) on its upper decks too.
	var/list/interior_turfs = list()
	for(var/datum/space_level/level as anything in interior_levels)
		interior_turfs += block(
			locate(template_bottom_left.x, template_bottom_left.y, level.z_value),
			locate(template_bottom_left.x + template.width - 1, template_bottom_left.y + template.height - 1, level.z_value),
		)
	for(var/turf/interior_turf as anything in interior_turfs)
		var/area/turf_area = interior_turf.loc
		if(istype(turf_area, /area/voidcrew/colosseum))
			LAZYADDASSOCLIST(area_turfs, turf_area.type, interior_turf)
		// block() iterates y-major then x, same order the hangar-side alcove
		// collects in, so the elevator can map alcove turf i to alcove turf i.
		for(var/obj/effect/landmark/outpost_elevator_alcove/alcove_mark in interior_turf)
			lobby_alcove_turfs += interior_turf
			qdel(alcove_mark)
		for(var/obj/effect/landmark/colosseum/colo_mark in interior_turf)
			LAZYADDASSOCLIST(landmark_turfs, colo_mark.type, interior_turf)
			qdel(colo_mark)
		// The gear stall's shopkeeper is self-sufficient (owns its own shop
		// datum), indexing it here only wires the post-match restock hook
		for(var/mob/living/basic/outpost_trader/colosseum/merchant in interior_turf)
			armory_trader = merchant
		for(var/obj/machinery/machine in interior_turf)
			if(istype(machine, /obj/machinery/outpost_elevator))
				var/obj/machinery/outpost_elevator/panel = machine
				panel.outpost = src
				panel.is_lobby = TRUE
				lobby_panels += panel
			else if(istype(machine, /obj/machinery/door/poddoor))
				var/obj/machinery/door/poddoor/gate = machine
				if(istext(gate.id) && findtext(gate.id, "colo_"))
					LAZYADDASSOCLIST(gate_doors, gate.id, gate)
			else if(istype(machine, /obj/machinery/computer/colosseum_signup))
				var/obj/machinery/computer/colosseum_signup/console = machine
				console.site = src
				signup_console = console
			else if(istype(machine, /obj/machinery/colosseum_vault))
				var/obj/machinery/colosseum_vault/vault = machine
				vault.site = src
				spoils_vault = vault
			else if(istype(machine, /obj/machinery/computer/colosseum_bookmaker))
				var/obj/machinery/computer/colosseum_bookmaker/book_console = machine
				book_console.site = src
				bookmaker = book_console
			else if(istype(machine, /obj/machinery/status_display/colosseum))
				var/obj/machinery/status_display/colosseum/board = machine
				board.site = src
				status_displays += board
	// The venue must function even if a map edit loses the service machinery.
	// Fall back to spawning it on any clear concourse tile.
	if(!signup_console)
		var/turf/console_turf = get_random_lobby_turf()
		if(console_turf)
			signup_console = new(console_turf)
			signup_console.site = src
			log_mapping("COLOSSEUM: template has no signup console, fallback-spawned one at ([console_turf.x], [console_turf.y]).")
	if(!spoils_vault)
		var/turf/vault_turf = get_random_lobby_turf()
		if(vault_turf)
			spoils_vault = new(vault_turf)
			spoils_vault.site = src
			log_mapping("COLOSSEUM: template has no spoils vault, fallback-spawned one at ([vault_turf.x], [vault_turf.y]).")
	if(!bookmaker)
		var/turf/book_turf = get_random_lobby_turf()
		if(book_turf)
			bookmaker = new(book_turf)
			bookmaker.site = src
			log_mapping("COLOSSEUM: template has no bookmaker console, fallback-spawned one at ([book_turf.x], [book_turf.y]).")
	if(!armory_trader)
		var/turf/stall_turf = get_random_lobby_turf()
		if(stall_turf)
			armory_trader = new(stall_turf)
			log_mapping("COLOSSEUM: template has no gear stall lanista, fallback-spawned one at ([stall_turf.x], [stall_turf.y]).")
	if(!length(lobby_alcove_turfs))
		log_mapping("COLOSSEUM: template has no elevator alcove landmarks. Ships cannot reach the concourse.")
	if(!length(lobby_panels))
		log_mapping("COLOSSEUM: template has no concourse elevator panel.")
	for(var/expected_id in list(COLOSSEUM_GATE_RED, COLOSSEUM_GATE_BLUE, COLOSSEUM_GATE_SOLO, COLOSSEUM_SEAL))
		if(!length(gate_doors[expected_id]))
			log_mapping("COLOSSEUM: no poddoors found with id '[expected_id]'.")

/// All interior turfs belonging to the given colosseum area typepath.
/obj/structure/overmap/colosseum/proc/get_area_turfs_cached(area_type)
	return area_turfs[area_type] || list()

/// Landmark-marked turfs of the given landmark typepath (may be empty).
/obj/structure/overmap/colosseum/proc/get_landmark_turfs(landmark_type)
	return landmark_turfs[landmark_type] || list()

/// A random clear standing spot in the given colosseum area (null if none).
/obj/structure/overmap/colosseum/proc/get_random_clear_turf(area_type, tries = 20)
	var/list/candidates = get_area_turfs_cached(area_type)
	if(!length(candidates))
		return null
	for(var/_ in 1 to tries)
		var/turf/candidate = pick(candidates)
		if(!candidate.is_blocked_turf())
			return candidate
	return null

/// A random clear concourse tile, ejection destination and machinery fallback.
/obj/structure/overmap/colosseum/proc/get_random_lobby_turf()
	return get_random_clear_turf(/area/voidcrew/colosseum/lobby) || (length(lobby_alcove_turfs) ? pick(lobby_alcove_turfs) : null)

/**
 * Infirmary berth turfs for laying out the dead. Prefers mapped infirmary
 * landmarks; falls back to the infirmary's mid-row per DESIGN.md (x49..55 y23),
 * then any clear lobby tile.
 */
/obj/structure/overmap/colosseum/proc/get_infirmary_turfs()
	var/list/marked = get_landmark_turfs(/obj/effect/landmark/colosseum/infirmary)
	if(length(marked))
		return marked
	var/list/fallback = list()
	for(var/x in 49 to 55)
		var/turf/T = local_turf(x, 23)
		if(T && !T.is_blocked_turf())
			fallback += T
	if(length(fallback))
		return fallback
	var/turf/last_resort = get_random_lobby_turf()
	return last_resort ? list(last_resort) : list()

/**
 * Whether a mob counts as present at the venue: inside the building proper,
 * standing in one of its hangar berths, or aboard a ship parked in one. Used
 * by the seating-close roster check (gearing up on your own docked ship must
 * not get you struck as a no-show) and by venue_message's reach.
 */
/obj/structure/overmap/colosseum/proc/mob_at_venue(mob/visitor)
	var/area/mob_area = get_area(visitor)
	if(istype(mob_area, /area/voidcrew/colosseum))
		return TRUE
	for(var/datum/outpost_berth/berth as anything in berths)
		if(!berth)
			continue
		// Each hangar load gets its own area instance, so comparing instances
		// pins the mob to one of OUR berths, not some other outpost's hangar.
		if(berth.hangar_bottom_left && mob_area == get_area(berth.hangar_bottom_left))
			return TRUE
		if(berth.arrived && berth.ship?.shuttle?.shuttle_areas[mob_area])
			return TRUE
	return FALSE

/// Sends a chat line to every player currently at the venue (docked ships included).
/obj/structure/overmap/colosseum/proc/venue_message(message)
	for(var/mob/player as anything in GLOB.player_list)
		if(mob_at_venue(player))
			to_chat(player, message)

/// Post-match supply run for the gear stall: tops up core stock, swaps
/// sold-out rotating slots and rerolls the special. Fired by the match
/// controller when a match resolves.
/obj/structure/overmap/colosseum/proc/restock_armory()
	if(QDELETED(armory_trader) || !armory_trader.shop)
		return
	armory_trader.shop.convoy_restock()
	armory_trader.speak_line(TRADER_LINE_RESTOCK)

/// Refreshes every ETA board (state flips re-arm their countdown processing).
/obj/structure/overmap/colosseum/proc/update_status_displays()
	for(var/obj/machinery/status_display/colosseum/board as anything in status_displays)
		if(!QDELETED(board))
			board.update()

/// Warden escort: drops a mob on a clear concourse tile with a message.
/// Callback target for the area boundary guards (staging, spoils chamber).
/obj/structure/overmap/colosseum/proc/bounce_to_lobby(mob/living/visitor, message)
	if(QDELETED(visitor) || QDELETED(src))
		return
	var/turf/eject_to = get_random_lobby_turf()
	if(!eject_to)
		return
	visitor.forceMove(eject_to)
	if(message)
		to_chat(visitor, span_warning(message))

/**
 * Claim window opening: anyone in the spoils chamber who isn't one of this
 * match's winners is walked out before the winners come collect. The chamber
 * door and the area guard keep it that way for the rest of the window.
 */
/obj/structure/overmap/colosseum/proc/secure_vault_chamber()
	var/datum/colosseum_controller/controller = src.controller
	for(var/turf/chamber_turf as anything in get_area_turfs_cached(/area/voidcrew/colosseum/vault))
		for(var/mob/living/loiterer in chamber_turf)
			if(loiterer.mind && controller?.winner_minds[loiterer.mind])
				continue
			if(!loiterer.mind && !loiterer.client)
				continue
			bounce_to_lobby(loiterer, "Colosseum wardens clear the spoils chamber for the winners.")

// ===== GATE CONTROL =====
// Event code drives the mapped ids directly; the referee-box buttons keep
// working independently because they share the same ids.

/// Opens or closes every poddoor mapped with the given id.
/obj/structure/overmap/colosseum/proc/set_gates(gate_id, open)
	for(var/obj/machinery/door/poddoor/gate as anything in gate_doors[gate_id])
		if(QDELETED(gate))
			continue
		INVOKE_ASYNC(gate, open ? TYPE_PROC_REF(/obj/machinery/door, open) : TYPE_PROC_REF(/obj/machinery/door, close))

/// Closes every arena gate and reopens the staging rear seals (idle posture).
/obj/structure/overmap/colosseum/proc/gates_to_idle()
	set_gates(COLOSSEUM_GATE_RED, FALSE)
	set_gates(COLOSSEUM_GATE_BLUE, FALSE)
	set_gates(COLOSSEUM_GATE_SOLO, FALSE)
	set_gates(COLOSSEUM_SEAL, TRUE)

// ===== DOCKING =====

/obj/structure/overmap/colosseum/attack_ghost(mob/user)
	if(length(lobby_alcove_turfs))
		user.forceMove(pick(lobby_alcove_turfs))
		return TRUE
	if(template_bottom_left)
		user.forceMove(template_bottom_left)
		return TRUE
	return

/**
 * Handles ship docking: allocates the ship its own hangar berth (see
 * outpost_hangar.dm) and docks it there. The interior is already loaded,
 * open_venue() ran at spawn, but load_level() is retried defensively.
 */
/obj/structure/overmap/colosseum/get_dock_description()
	return "[name] (arena berth)"

/// The venue is carved into a bedrock shard and its areas are STANDARD_GRAVITY.
/// A ship berthed here is held down by the rock, not by its own plating.
/obj/structure/overmap/colosseum/has_ambient_gravity()
	return TRUE

/obj/structure/overmap/colosseum/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	// dock() refuses interdicted ships only after a berth below is claimed
	// and the ship is locked into ACTING - refuse up front instead
	if(acting.is_interdicted)
		to_chat(user, span_warning("Cannot dock while interdicted!"))
		return
	if(concerned)
		to_chat(user, span_notice("Too much traffic, try again later!"))
		return
	concerned = TRUE

	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING
	balloon_alert(user, "starting docking process..")

	load_level()

	if(!loaded)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Failed to load the location."))
		return

	var/obj/docking_port/stationary/dock_to_use = null
	var/datum/outpost_berth/berth = null

	// Port destinations are set by survey console
	if(acting.shuttle.port_destinations)
		dock_to_use = acting.shuttle.port_destinations
	else
		// Cheap size gate before spending a reservation on a ship that can't fit
		var/long_axis = max(acting.shuttle.width, acting.shuttle.height)
		var/short_axis = min(acting.shuttle.width, acting.shuttle.height)
		if(long_axis > RESERVE_DOCK_MAX_SIZE_LONG || short_axis > RESERVE_DOCK_MAX_SIZE_SHORT)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_warning("Ship is too large for [name]'s hangar berths."))
			return

		berth = allocate_berth(acting)
		if(!berth)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_notice("[name] traffic control: all hangar berths are occupied. Try again later."))
			return
		adjust_reserve_dock_to_shuttle(berth.dock, acting.shuttle)
		dock_to_use = berth.dock

	if(acting.shuttle.height > dock_to_use.height || acting.shuttle.width > dock_to_use.width)
		berth?.release(force = TRUE) // nothing has landed yet, safe to free immediately
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Ship is too large to dock at this location."))
		return

	// dock() only returns a string when it refuses; a successful start is announced
	// to the whole crew by ship_notify()
	var/dock_result = acting.dock(src, dock_to_use)
	if(dock_result)
		to_chat(user, span_notice("[dock_result]"))

	concerned = FALSE

	if(optional_partner)
		ship_act(user, optional_partner)
