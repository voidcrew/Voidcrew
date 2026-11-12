/**
 * # Outpost floors: the host
 *
 * Owner: P1. The host type, its `floor` var and its two frozen overrides (is_turf_buildable(), contains_service_turf())
 * are in _floor_types.dm. Everything else a player outpost does that assumes a level of its own is overridden here:
 * found(), load_level(), adopt_built_turfs(), upgrade_level_z(), announcement_listeners(), ship_act(),
 * ensure_home_services() and Destroy() (build plan P1), and the front door's place in the door access rules.
 *
 * P0 proved the host safe in nullspace (unit test voidcrew_outpost_floors_seam_host_off_overmap): Initialize(),
 * the lookups that walk GLOB.player_outposts and GLOB.overmap_objects, and Destroy() run with no runtime. The base
 * Destroy() only frees a mapzone when there is one, and a floor never has one.
 *
 * A host is made by /datum/outpost_floor/proc/let_to() (floor_registry.dm) and by nothing else. Its ground is its
 * floor's: the floor datum holds the reservation and gives it back.
 */

/obj/structure/overmap/dynamic/player_outpost/floor
	name = "outpost floor"
	desc = "A leased floor of a trader outpost."
	// Never a contact: it is not on the overmap, and nothing may chart it if an admin ever puts it there.
	sensor_detectable = FALSE
	sensor_visible = FALSE
	/// The shell map found() was handed, until load_level() has loaded it
	var/datum/map_template/outpost_floor/shell_map
	/// The shell's front door (floor_shell.dm)
	var/datum/weakref/shell_front_door

/// Before the refs go: whoever is on the floor is put in the lobby, the ground is given back and the floor is unlet (A10)
/obj/structure/overmap/dynamic/player_outpost/floor/Destroy()
	var/datum/outpost_floor/old_floor = floor
	if(old_floor?.host == src)
		old_floor.host_lost()
		old_floor.host = null
	floor = null
	shell_map = null
	shell_front_door = null
	return ..()

// ===== LETTING =====

/**
 * Registers `founder` as the floor's owner and loads its shell (load_level()). Unlike an outpost's founding this
 * announces nothing and, when it fails, leaves the clean-up to let_to(), which owns the floor's state.
 * The founder's ship crew become residents. Yields.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/found(mob/living/founder, datum/map_template/outpost_floor/shell, outpost_name)
	if(founder_ckey || loaded || loading || !floor || !shell)
		return FALSE
	if(!founder?.ckey || !founder.mind)
		return FALSE
	var/datum/mind/owner_mind = founder.mind
	founder_ckey = founder.ckey
	founder_name = founder.real_name
	founder_mind = WEAKREF(owner_mind)
	// The crew as it stands now, before the load yields; nearby ships are visitors.
	var/obj/structure/overmap/ship/founding_ship = get_crew_ship(founder)
	var/list/datum/mind/founding_crew = founding_ship?.ship_team?.members.Copy()
	shell_map = shell
	name = outpost_name
	display_name = outpost_name
	founded_zone = SSovermap.get_zone_band_for_turf(get_turf(floor.outpost))

	if(!load_level())
		return FALSE

	residents |= owner_mind
	resident_clearance[founder_ckey] = resident_access_revision
	register_founding_crew(founding_crew)
	log_shuttle("OUTPOST FLOORS: [key_name(founder)] leased floor [floor.number] of '[floor.outpost]' as '[name]'")
	return TRUE

/**
 * Reserves the floor's ground and loads the shell onto it, in the order of spec 2: the fit is asked first, the
 * ground reserved, the map loaded with no try round it, and the shell linked. FALSE leaves whatever ground was
 * taken with the floor, for let_to() to give back.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/load_level()
	if(loaded || loading || !floor || floor.reservation)
		return FALSE
	var/datum/map_template/outpost_floor/shell = shell_map
	shell_map = null
	if(!shell?.width || !shell.height)
		log_mapping("OUTPOST FLOORS: shell '[shell?.name]' has no dimensions, cannot load.")
		return FALSE
	// A request no reservation level can ever hold is refused before it is made (voidcrew/mapping/_mapping.dm)
	if(!SSmapping.reservation_can_ever_fit(shell.width, shell.height))
		log_mapping("OUTPOST FLOORS: shell '[shell.name]' ([shell.width]x[shell.height]) can never be reserved.")
		return FALSE
	loading = TRUE
	outpost_style = shell.outpost_style || OUTPOST_STYLE_DEFAULT

	var/datum/turf_reservation/ground = SSmapping.request_turf_block_reservation(shell.width, shell.height, 1, requester = "outpost floor [floor.number] of '[floor.outpost]'")
	// The request waits its turn: the host or the floor can be gone by now
	if(QDELETED(src) || QDELETED(floor))
		if(ground)
			qdel(ground)
		loading = FALSE
		return FALSE
	if(!ground || !floor.take_ground(ground))
		if(ground)
			qdel(ground)
		loading = FALSE
		return FALSE

	// Never in a try: a caught runtime unwinds the loader past its own clean-up and leaves half a map
	// (trade/outpost.dm wraps its load; it must not be copied)
	var/shell_loaded = shell.load(ground.bottom_left_turfs[1])
	if(QDELETED(src) || QDELETED(floor))
		loading = FALSE
		return FALSE
	if(!shell_loaded || !floor.link_shell())
		loading = FALSE
		return FALSE

	ensure_home_services()
	if(!install_home_bundle())
		log_mapping("OUTPOST FLOORS: shell '[shell.name]' is missing a console, a bank terminal, a cryopod or its arrival landmark.")
		loading = FALSE
		return FALSE
	loaded = TRUE
	loading = FALSE
	home_service_timer = addtimer(CALLBACK(src, PROC_REF(process_home_services)), 5 SECONDS, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

// ===== NO LEVEL OF ITS OWN =====

/// Every tile of a floor is in its area from the moment the shell loads: there is nothing to adopt
/obj/structure/overmap/dynamic/player_outpost/floor/adopt_built_turfs()
	return

/// The level the floor's ground is on, or null before it has any. Shared with other floors and the concourse:
/// never a test of where something is (get_outpost_floor_for_turf() is).
/obj/structure/overmap/dynamic/player_outpost/floor/upgrade_level_z()
	return length(floor?.bounds) >= 5 ? floor.bounds[5] : null

/// Who hears the floor's announcements: the players on it. The owner's crew is left out; their own ship tells them.
/obj/structure/overmap/dynamic/player_outpost/floor/announcement_listeners(obj/structure/overmap/ship/owner_ship)
	. = list()
	if(length(floor?.bounds) < 5)
		return
	var/list/datum/mind/owner_crew = owner_ship?.ship_team?.members
	for(var/mob/living/occupant in outpost_site_clients(locate(floor.bounds[1], floor.bounds[2], floor.bounds[5])))
		if(occupant.mind in owner_crew)
			continue
		. += occupant

/// Nothing docks at a floor: ships berth at the trader outpost
/obj/structure/overmap/dynamic/player_outpost/floor/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner, dock_variant)
	return

/// The treasury as on any outpost, and the goods lift's freight in place of the ferry (floor_supply.dm)
/obj/structure/overmap/dynamic/player_outpost/floor/ensure_home_services()
	if(!freight)
		freight = new /datum/voidcrew_cargo_shuttle/outpost/floor(src)
	return ..()

// ===== THE FRONT DOOR =====

/// Keys the front door to members, free from the deck side so nobody is shut in upstairs (spec 3, 5.1)
/obj/structure/overmap/dynamic/player_outpost/floor/proc/key_front_door()
	var/obj/machinery/door/airlock/outpost_floor_front/door = shell_front_door?.resolve()
	if(QDELETED(door) || !floor)
		return
	// A map may point the free side itself; else it is the side the deck is on
	var/free_side = outpost_door_first_side(door.unres_sides)
	if(!free_side)
		for(var/side in GLOB.cardinals)
			if(floor.is_buildable(get_step(door, side)))
				free_side = side
				break
	apply_door_access(door, OUTPOST_DOOR_MEMBERS, free_side)

/// The front door stands on the landing, where nothing is built, yet its setting is the crew's to change (spec 5.1)
/obj/structure/overmap/dynamic/player_outpost/floor/door_access_fixed(obj/machinery/door/door)
	var/obj/machinery/door/front_door = shell_front_door?.resolve()
	if(front_door && door == front_door && !QDELETED(door))
		return null
	return ..()

/// Every door back to its default. On a floor the front door's is members, not public.
/obj/structure/overmap/dynamic/player_outpost/floor/reset_door_access()
	. = ..()
	key_front_door()
