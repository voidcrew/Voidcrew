/// Backgrounds: owned by P2.

/**
 * # Meridian Penitentiary
 *
 * A permanent walled prison in the yellow band, placed and loaded during SSovermap's init like
 * the trader outposts, but a sibling of them, never one: no shop, no GLOB.trader_outposts, no
 * strike ladder [MP-7]. Visitors berth in generated hangars and ride the lift to the Visitor
 * Hall. The interior is one turf reservation read only through its landmarks (map-contracts.md
 * M1); load_level() never wraps the template load in try/catch.
 */

/// An escape-wing cell
#define PENITENTIARY_CELL_ESCAPE "escape"
/// A capture-wing cell
#define PENITENTIARY_CELL_CAPTURE "capture"

/// The round's Penitentiary, once placed
GLOBAL_DATUM(penitentiary, /obj/structure/overmap/penitentiary)

/// Meridian Penitentiary on the overmap. A sibling of the trader outposts, never one of them.
/obj/structure/overmap/penitentiary
	name = "Meridian Penitentiary"
	desc = "A walled prison station. Visitors berth at the hangar and wait in the hall."
	icon_state = "station"
	sensor_visible = TRUE
	/// The turf reservation the site's map is loaded into
	var/datum/turf_reservation/reservation
	/// The loaded template
	var/datum/map_template/penitentiary/site_template
	var/loaded = FALSE
	var/loading = FALSE
	/// The NPC wing
	var/datum/outpost_prison/penitentiary/prison
	/// The wing's one area instance
	var/area/voidcrew/player_outpost/prison/penitentiary/wing_area
	/// Cell Block D: cell number -> /datum/penitentiary_cell
	var/list/escape_cells = list()
	/// Secure Holding: cell number -> /datum/penitentiary_cell
	var/list/capture_cells = list()
	/// Where the dead officers lie in scenario 2
	var/list/turf/massacre_body_turfs = list()
	/// Where scenario-2 convicts come to, and how many of them are taken this round
	var/list/turf/massacre_spots = list()
	var/massacre_spots_used = 0
	/// The processing room is dressed once per round [ECO-5]
	var/massacre_dressed = FALSE
	/// The launch bay's cradles, by the console they belong to (nearest first)
	var/list/turf/pod_cradles = list()
	var/list/obj/machinery/computer/penitentiary_launch/launch_consoles = list()
	/// Where a body goes when every morgue tray is full
	var/turf/morgue_turf
	var/list/obj/structure/bodycontainer/morgue/morgue_trays = list()
	var/list/obj/structure/closet/secure_closet/penitentiary_evidence/evidence_lockers = list()
	/// The Visitor Hall's arrival mark, for admins and fallbacks
	var/turf/arrival_turf
	/// The warden and the clerk
	var/list/mob/living/basic/ambient_npc/penitentiary/staff = list()

/obj/structure/overmap/penitentiary/Initialize(mapload)
	. = ..()
	GLOB.penitentiary = src
	berths = new /list(OUTPOST_MAX_BERTHS)

/obj/structure/overmap/penitentiary/Destroy()
	if(GLOB.penitentiary == src)
		GLOB.penitentiary = null
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth)
			berth.release(force = TRUE)
	berths = null
	lobby_alcove_turfs.Cut()
	lobby_wall_turfs.Cut()
	lobby_panels.Cut()
	QDEL_NULL(prison)
	QDEL_LIST_ASSOC_VAL(escape_cells)
	QDEL_LIST_ASSOC_VAL(capture_cells)
	massacre_body_turfs.Cut()
	massacre_spots.Cut()
	pod_cradles.Cut()
	launch_consoles.Cut()
	morgue_trays.Cut()
	evidence_lockers.Cut()
	staff.Cut()
	morgue_turf = null
	arrival_turf = null
	wing_area = null
	template_bottom_left = null
	loaded = FALSE
	QDEL_NULL(reservation)
	QDEL_NULL(site_template)
	return ..()

/obj/structure/overmap/penitentiary/contains_site_turf(turf/location)
	return ..() || reservation?.contains_turf(location)

/obj/structure/overmap/penitentiary/start_level_load(mob/user, obj/structure/overmap/ship/waiting_ship)
	INVOKE_ASYNC(src, PROC_REF(load_level))

/obj/structure/overmap/penitentiary/is_loading()
	return loading

/obj/structure/overmap/penitentiary/is_loaded()
	return loaded

/obj/structure/overmap/penitentiary/has_ambient_gravity()
	return TRUE

/obj/structure/overmap/penitentiary/get_dock_description()
	return "Meridian Penitentiary"

/obj/structure/overmap/penitentiary/attack_ghost(mob/user)
	if(length(lobby_alcove_turfs))
		user.forceMove(pick(lobby_alcove_turfs))
		return TRUE
	if(arrival_turf || template_bottom_left)
		user.forceMove(arrival_turf || template_bottom_left)
		return TRUE
	return

/datum/map_template/penitentiary
	name = "Meridian Penitentiary"
	mappath = "voidcrew/_maps/map_files/outposts/penitentiary.dmm"

/// Places and loads the Penitentiary during SSovermap init
/datum/controller/subsystem/overmap/proc/setup_penitentiary()
	if(GLOB.penitentiary)
		return
	var/turf/candidate = get_unused_overmap_square_in_zone_band(ZONE_YELLOW)
	if(!candidate)
		log_mapping("SSovermap: WARNING - failed to place the Meridian Penitentiary in zone band [ZONE_YELLOW]")
		return
	var/obj/structure/overmap/penitentiary/site = new(candidate)
	site.load_level()
	log_mapping("SSovermap: Spawned the Meridian Penitentiary in zone band [ZONE_YELLOW] at ([candidate.x], [candidate.y])[site.loaded ? "" : ", interior FAILED to load"]")

/// Whether a thing stands inside the Penitentiary's reservation
/proc/is_penitentiary_turf(atom/thing)
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	if(!site?.reservation || !thing)
		return FALSE
	var/turf/location = get_turf(thing)
	return !!(location && site.reservation.contains_turf(location))

// ===== LOADING =====

/**
 * Loads the interior into its own turf reservation, permanently, then links it. Never wrapped in
 * try/catch: a map runtime there must surface, not unwind the reader's own cleanup.
 */
/obj/structure/overmap/penitentiary/proc/load_level()
	if(loaded || loading)
		return loaded
	loading = TRUE
	if(!site_template)
		site_template = new
	var/success = FALSE
	if(!site_template.width || !site_template.height)
		log_mapping("PENITENTIARY: template '[site_template.name]' has no dimensions, cannot load.")
	else
		reservation = SSmapping.request_turf_block_reservation(site_template.width, site_template.height, 1, requester = "Meridian Penitentiary")
		if(reservation)
			template_bottom_left = reservation.bottom_left_turfs[1]
			if(site_template.load(template_bottom_left))
				success = TRUE
	if(!success)
		QDEL_NULL(reservation)
		template_bottom_left = null
	else
		link_interior()
	loaded = success
	loading = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, loaded)
	return loaded

/// Every turf of the loaded interior
/obj/structure/overmap/penitentiary/proc/interior_turfs()
	if(!template_bottom_left || !site_template?.width || !site_template?.height)
		return list()
	var/turf/top_right = locate(template_bottom_left.x + site_template.width - 1, template_bottom_left.y + site_template.height - 1, template_bottom_left.z)
	if(!top_right)
		return list()
	return block(template_bottom_left, top_right)

/**
 * Reads the interior: the lift alcove and panels, the doors, the staff, the outpost property
 * sweep, the cells and their doors, the landmarks, and starts the NPC wing.
 */
/obj/structure/overmap/penitentiary/proc/link_interior()
	var/list/escape_doors = list()
	var/list/capture_doors = list()
	var/list/turf/interior = interior_turfs()
	for(var/turf/interior_turf as anything in interior)
		if(!wing_area && istype(interior_turf.loc, /area/voidcrew/player_outpost/prison/penitentiary))
			wing_area = interior_turf.loc
		// block() order, as the trader outposts, so the lift maps alcove turf i to alcove turf i
		for(var/obj/effect/landmark/outpost_elevator_alcove/alcove_mark in interior_turf)
			lobby_alcove_turfs += interior_turf
			qdel(alcove_mark)
		for(var/mob/living/basic/ambient_npc/penitentiary/npc in interior_turf)
			npc.link_to_site(src)
			staff |= npc
		for(var/obj/machinery/machine in interior_turf)
			if(istype(machine, /obj/machinery/door/airlock/outpost))
				var/obj/machinery/door/airlock/outpost/door = machine
				door.outpost = src
				if(istype(door, /obj/machinery/door/airlock/outpost/penitentiary/capture))
					var/obj/machinery/door/airlock/outpost/penitentiary/capture/cell_door = door
					capture_doors["[cell_door.cell_number]"] = cell_door
			else if(istype(machine, /obj/machinery/door/airlock/security/glass/penitentiary_escape))
				var/obj/machinery/door/airlock/security/glass/penitentiary_escape/cell_door = machine
				escape_doors["[cell_door.cell_number]"] = cell_door
			else if(istype(machine, /obj/machinery/outpost_elevator))
				var/obj/machinery/outpost_elevator/panel = machine
				panel.outpost = src
				panel.is_lobby = TRUE
				lobby_panels += panel
			else if(istype(machine, /obj/machinery/computer/penitentiary_launch))
				launch_consoles += machine
		for(var/obj/structure/thing in interior_turf)
			if(istype(thing, /obj/structure/closet/secure_closet/penitentiary_evidence))
				evidence_lockers += thing
			else if(istype(thing, /obj/structure/bodycontainer/morgue))
				morgue_trays += thing
		// Everything the template placed is property [DST-1, MP-8], except the escape line (made
		// to be hacked), the wing's staff doors, and the furniture people sit, lie and lean on.
		for(var/obj/fixture in interior_turf)
			if(!ismachinery(fixture) && !isstructure(fixture))
				continue
			if(is_type_in_typecache(fixture, GLOB.penitentiary_escape_line_doors))
				continue
			if(istype(fixture, /obj/structure/chair))
				// Seats stay seats: never folded up and swung
				var/obj/structure/chair/seat = fixture
				seat.item_chair = null
				continue
			if(istype(fixture, /obj/structure/bed))
				continue
			if(istype(fixture, /obj/structure/table) && !istype(fixture, /obj/structure/table/reinforced/prison_hatch))
				continue
			fixture.AddElement(/datum/element/outpost_property)
		read_landmarks(interior_turf)
	link_cells(escape_doors, capture_doors)
	if(wing_area)
		prison = new(src, wing_area)
		prison.populate()
	else
		log_mapping("PENITENTIARY: no General Population wing area on the map; the NPC wing stays empty.")

/// Reads (and clears, all but the arrival mark) the Penitentiary's landmarks on one turf
/obj/structure/overmap/penitentiary/proc/read_landmarks(turf/interior_turf)
	for(var/obj/effect/landmark/penitentiary/mark in interior_turf)
		if(istype(mark, /obj/effect/landmark/penitentiary/arrival))
			arrival_turf = interior_turf
			continue
		if(istype(mark, /obj/effect/landmark/penitentiary/escape_cell))
			var/obj/effect/landmark/penitentiary/escape_cell/cell_mark = mark
			escape_cells["[cell_mark.cell_number]"] = new /datum/penitentiary_cell(cell_mark.cell_number, PENITENTIARY_CELL_ESCAPE, interior_turf)
		else if(istype(mark, /obj/effect/landmark/penitentiary/capture_cell))
			var/obj/effect/landmark/penitentiary/capture_cell/cell_mark = mark
			capture_cells["[cell_mark.cell_number]"] = new /datum/penitentiary_cell(cell_mark.cell_number, PENITENTIARY_CELL_CAPTURE, interior_turf)
		else if(istype(mark, /obj/effect/landmark/penitentiary/massacre_body))
			massacre_body_turfs += interior_turf
		else if(istype(mark, /obj/effect/landmark/penitentiary/convict_massacre))
			massacre_spots += interior_turf
		else if(istype(mark, /obj/effect/landmark/penitentiary/pod_cradle))
			pod_cradles += interior_turf
		else if(istype(mark, /obj/effect/landmark/penitentiary/morgue))
			morgue_turf = interior_turf
		qdel(mark)

/// Pairs each cell with its door, works out its room, and bolts every player cell shut
/obj/structure/overmap/penitentiary/proc/link_cells(list/escape_doors, list/capture_doors)
	for(var/number in escape_cells)
		var/datum/penitentiary_cell/cell = escape_cells[number]
		cell.attach(escape_doors[number])
	for(var/number in capture_cells)
		var/datum/penitentiary_cell/cell = capture_cells[number]
		cell.attach(capture_doors[number])

// ===== DOCKING =====

/**
 * The trader outposts' berth branch (outpost.dm ship_act()), without the shop's greeting. Flagged
 * pirate hulls and carriers, and escape pods, are turned away first [MP-13].
 */
/obj/structure/overmap/penitentiary/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	var/refusal = penitentiary_docking_refusal(acting)
	if(refusal)
		to_chat(user, span_warning(refusal))
		return
	if(acting.is_interdicted)
		to_chat(user, span_warning("Cannot dock while interdicted!"))
		return
	if(concerned || admin_operation || loading)
		to_chat(user, span_notice("Too much traffic, try again later!"))
		return
	concerned = TRUE

	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING
	balloon_alert(user, "starting docking process..")

	load_level()

	if(!reservation || !loaded)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Failed to load the location."))
		return

	var/obj/docking_port/stationary/dock_to_use = null
	var/datum/outpost_berth/berth = null

	if(acting.shuttle.port_destinations)
		dock_to_use = acting.shuttle.port_destinations
	else
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
		berth?.release(force = TRUE)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Ship is too large to dock at this location."))
		return

	var/dock_result = acting.dock(src, dock_to_use)
	if(dock_result)
		to_chat(user, span_notice("[dock_result]"))

	concerned = FALSE

	if(optional_partner)
		ship_act(user, optional_partner)

/// Why traffic control turns `acting` away, or null [MP-13]
/obj/structure/overmap/penitentiary/proc/penitentiary_docking_refusal(obj/structure/overmap/ship/acting)
	if(!acting)
		return null
	if(acting.pirate_crew || background_rider_flagged(acting))
		return "Meridian traffic control: your transponder is flagged. Docking denied."
	if(istype(acting.source_template, /datum/map_template/shuttle/voidcrew/escape_pod))
		return "Meridian traffic control: that pod is not cleared to dock."
	return null

// ===== CELLS =====

/**
 * One player cell: its number, door, room and who it is for. An escape cell has one owner, the
 * fresh scenario-1 convict it was given to; a capture cell holds up to two captives in beds and
 * any overflow on the floor [OWN-2].
 */
/datum/penitentiary_cell
	var/number = 0
	var/kind
	/// The landmark's turf, on the first bed
	var/turf/mark_turf
	var/datum/weakref/door_ref
	/// The room, turf = TRUE
	var/list/turf_set = list()
	/// The room's beds' turfs, the landmark's first
	var/list/turf/bed_turfs = list()
	/// Escape cell: the mind it was given to
	var/datum/weakref/owner_ref
	/// Escape cell: world.time until which it is held for a convict on their way in
	var/reserved_until = 0
	/// Capture cell: weakrefs to the bodies put in it
	var/list/datum/weakref/occupants = list()

/datum/penitentiary_cell/New(number, kind, turf/mark_turf)
	. = ..()
	src.number = number
	src.kind = kind
	src.mark_turf = mark_turf

/datum/penitentiary_cell/Destroy()
	mark_turf = null
	door_ref = null
	owner_ref = null
	turf_set.Cut()
	bed_turfs.Cut()
	occupants.Cut()
	return ..()

/// Links the cell to its door, finds its room from the landmark (open tiles in the same area, no door), and bolts it
/datum/penitentiary_cell/proc/attach(obj/machinery/door/airlock/door)
	door_ref = door ? WEAKREF(door) : null
	turf_set = list()
	bed_turfs = list()
	if(mark_turf)
		var/area/room_area = mark_turf.loc
		var/list/turf/queue = list(mark_turf)
		turf_set[mark_turf] = TRUE
		while(length(queue) && length(turf_set) <= 16)
			var/turf/current = queue[1]
			queue.Cut(1, 2)
			for(var/direction in GLOB.cardinals)
				var/turf/next = get_step(current, direction)
				if(!next || turf_set[next] || next.loc != room_area || isclosedturf(next))
					continue
				if(locate(/obj/machinery/door) in next)
					continue
				turf_set[next] = TRUE
				queue += next
		if(locate(/obj/structure/bed) in mark_turf)
			bed_turfs += mark_turf
		for(var/turf/tile as anything in turf_set)
			if(tile != mark_turf && (locate(/obj/structure/bed) in tile))
				bed_turfs += tile
		if(!length(bed_turfs))
			bed_turfs += mark_turf
	if(door)
		door.set_bolt(TRUE)
		door.update_appearance()

/datum/penitentiary_cell/proc/door()
	var/obj/machinery/door/airlock/door = door_ref?.resolve()
	return QDELETED(door) ? null : door

/datum/penitentiary_cell/proc/contains(atom/thing)
	var/turf/location = get_turf(thing)
	return !!(location && turf_set[location])

/// The escape cell's owner, if any
/datum/penitentiary_cell/proc/owner()
	return owner_ref?.resolve()

/**
 * Whether an escape cell can take a fresh convict: nobody owns it, its owner's background is over,
 * or its owner has left it.
 */
/datum/penitentiary_cell/proc/is_free()
	if(world.time < reserved_until)
		return FALSE
	var/datum/mind/owner = owner()
	if(!owner)
		return TRUE
	var/datum/background_state/state = owner.background_state
	if(!state || state.ended || state.key != BACKGROUND_CONVICT)
		return TRUE
	return !contains(owner.current)

/// Shuts the cell for a new arrival: wires mended, panel shut, door closed and bolted
/datum/penitentiary_cell/proc/reset_door()
	var/obj/machinery/door/airlock/door = door()
	if(!door)
		return
	door.wires?.repair()
	door.panel_open = FALSE
	if(door.density)
		door.set_bolt(TRUE)
		door.update_appearance()
	else
		INVOKE_ASYNC(src, PROC_REF(close_and_bolt), door)

/datum/penitentiary_cell/proc/close_and_bolt(obj/machinery/door/airlock/door)
	if(QDELETED(door))
		return
	door.close()
	door.set_bolt(TRUE)
	door.update_appearance()

/// The capture cell's bodies still inside it, oldest first
/datum/penitentiary_cell/proc/bodies_inside()
	var/list/bodies = list()
	for(var/datum/weakref/ref as anything in occupants.Copy())
		var/mob/living/body = ref?.resolve()
		if(QDELETED(body) || !contains(body))
			occupants -= ref
			continue
		bodies += body
	return bodies

/// Where the next captive goes in this capture cell: a free bed, or a free floor tile once both beds are taken
/datum/penitentiary_cell/proc/next_spot()
	var/list/bodies = bodies_inside()
	var/list/turf/taken = list()
	for(var/mob/living/body as anything in bodies)
		taken[get_turf(body)] = TRUE
	for(var/turf/bed as anything in bed_turfs)
		if(!taken[bed])
			return bed
	for(var/turf/tile as anything in turf_set)
		if(!taken[tile] && !tile.is_blocked_turf(exclude_mobs = TRUE))
			return tile
	return mark_turf

// ===== THE SITE'S HELPERS =====

/// A free escape cell, or null
/obj/structure/overmap/penitentiary/proc/free_escape_cell()
	for(var/number in escape_cells)
		var/datum/penitentiary_cell/cell = escape_cells[number]
		if(cell.is_free())
			return cell
	return null

/// Massacre spots left this round
/obj/structure/overmap/penitentiary/proc/massacre_spots_left()
	return max(0, length(massacre_spots) - massacre_spots_used)

/// Takes the next massacre spot, or null
/obj/structure/overmap/penitentiary/proc/take_massacre_spot()
	if(!massacre_spots_left())
		return null
	massacre_spots_used++
	return massacre_spots[massacre_spots_used]

/// The capture cell the next captive goes to: the lowest-numbered one with a free bed, else the emptiest [OWN-2]
/obj/structure/overmap/penitentiary/proc/capture_cell_for_next()
	var/datum/penitentiary_cell/emptiest
	var/emptiest_count = INFINITY
	for(var/number in capture_cells)
		var/datum/penitentiary_cell/cell = capture_cells[number]
		var/count = length(cell.bodies_inside())
		if(count < BACKGROUND_PEN_CAPTURE_PER_CELL)
			return cell
		if(count < emptiest_count)
			emptiest = cell
			emptiest_count = count
	return emptiest

/// The capture cell `body` lies in, or null
/obj/structure/overmap/penitentiary/proc/capture_cell_holding(mob/living/body)
	for(var/number in capture_cells)
		var/datum/penitentiary_cell/cell = capture_cells[number]
		if(cell.contains(body))
			return cell
	return null

/// An empty, closed morgue tray, or null
/obj/structure/overmap/penitentiary/proc/free_morgue_tray()
	for(var/obj/structure/bodycontainer/morgue/tray in morgue_trays)
		if(QDELETED(tray) || (tray.connected && tray.connected.loc != tray))
			continue
		if(locate(/mob/living) in tray.get_all_contents())
			continue
		return tray
	return null

/// The evidence locker given to `mind`; with `assign`, a free one is given if they have none
/obj/structure/overmap/penitentiary/proc/evidence_locker_for(datum/mind/mind, assign = FALSE)
	if(!mind)
		return null
	for(var/obj/structure/closet/secure_closet/penitentiary_evidence/locker in evidence_lockers)
		if(locker.owner() == mind)
			return locker
	if(!assign)
		return null
	for(var/obj/structure/closet/secure_closet/penitentiary_evidence/locker in evidence_lockers)
		if(!locker.owner())
			locker.assign_to(mind)
			return locker
	// Every locker taken: reclaim one whose owner's background is over
	for(var/obj/structure/closet/secure_closet/penitentiary_evidence/locker in evidence_lockers)
		var/datum/mind/owner = locker.owner()
		if(!owner?.background_state || owner.background_state.ended)
			locker.release()
			locker.assign_to(mind)
			return locker
	return null

/**
 * Dresses the processing room as a massacre, once per round [ECO-5]: an officer's body at each
 * body mark and blood about them.
 */
/obj/structure/overmap/penitentiary/proc/dress_massacre()
	if(massacre_dressed)
		return
	massacre_dressed = TRUE
	for(var/turf/spot as anything in massacre_body_turfs)
		new /obj/effect/mob_spawn/corpse/human/penitentiary_officer(spot)
		new /obj/effect/decal/cleanable/blood(spot)
		for(var/i in 1 to 2)
			var/turf/near = get_step(spot, pick(GLOB.alldirs))
			if(near && !isclosedturf(near) && is_penitentiary_turf(near))
				new /obj/effect/decal/cleanable/blood/splatter(near)
	log_game("PENITENTIARY: the processing room was dressed for scenario 2 ([length(massacre_body_turfs)] bodies)")
