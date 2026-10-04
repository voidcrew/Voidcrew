/**
 * # Player Outpost
 *
 * A player-founded, player-built station on the overmap. Founded by using an
 * outpost deed (see outpost_deed.dm) while the crew's ship sits on an empty
 * overmap tile: the founder picks a shell template, the outpost gets its own
 * z-level (same substrate as empty-space docking, so construction is allowed),
 * and the shell is loaded into the level's build region. Hangar berths, the ship
 * bay, the shipyard and the ferry pen are fixed zones on the same level
 * (outpost_level_layout.dm): an outpost never takes more than one z-level.
 *
 * Once founded the outpost is permanent for the round, it never unloads and
 * never moves. Ship weapons never target it.
 *
 * Players may own multiple outposts; each claim has independent services.
 * Nothing about the outpost persists across rounds.
 */

/// All player outposts on the overmap
GLOBAL_LIST_EMPTY(player_outposts)
/obj/structure/overmap/dynamic/player_outpost
	name = "player outpost"
	desc = "An independent outpost."
	icon_state = "station"
	sensor_detectable = TRUE
	sensor_category = "Outposts"
	preserve_level = TRUE // never unloads (documentation, /dynamic has no unload path anyway)

	/// Ckey of the current owner. Ownership survives death/respawn.
	var/founder_ckey
	/// Display name of the founder at founding time (for examine/announcements)
	var/founder_name
	/// Weakref to the owner's mind, used to recognize the owner's crew ship
	var/datum/weakref/founder_mind
	/// Zone band this outpost was founded in (ZONE_RED/YELLOW/GREEN)
	var/founded_zone
	/// Docking policy: OUTPOST_DOCK_MODE_OPEN / _REQUEST / _LOCKDOWN
	var/dock_mode = OUTPOST_DOCK_MODE_OPEN
	/// Ships cleared to dock while in REQUEST mode
	var/list/approved_ships = list()
	/// Pending docking requests: ship -> world.time of the request
	var/list/pending_dock_requests = list()
	/// Ships refused in all modes
	var/list/banned_ships = list()
	/// Ckeys allowed to use the construction console besides the owner
	var/list/authorized_builder_ckeys = list()
	/// Owner-set public description, shown on examine and advertisements
	var/memo = ""
	/// The live advertisement, if any (see outpost_adverts.dm)
	var/datum/outpost_advert/current_advert
	/// The shell template instance that was loaded at founding
	var/datum/map_template/player_outpost/shell_template
	/// The style every room this outpost builds is drawn in, from its shell (outpost_styles.dm)
	var/outpost_style = OUTPOST_STYLE_DEFAULT
	// template_bottom_left (the shell footprint origin) lives on /obj/structure/overmap
	/// Buildable region on the outpost z-level: list(x1, y1, x2, y2)
	var/list/build_bounds
	/// Turf visitors/drones arrive at, from the shell's arrival landmark
	var/turf/arrival_turf
	/// Linked management console (from the shell)
	var/obj/machinery/computer/player_outpost_management/management_console
	/// Linked construction console (from the shell)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/construction_console
	/// The shell's loaded area instance. Turfs built in the build region get
	/// adopted into it so they draw APC power and have gravity (see adopt_turf)
	var/area/voidcrew/player_outpost/outpost_area
	/// Looping timer for the adopt_built_turfs() safety-net sweep
	var/area_sweep_timer
	var/loaded = FALSE
	var/loading = FALSE
	COOLDOWN_DECLARE(rename_cooldown)
	COOLDOWN_DECLARE(advert_cooldown)

/// Somebody's colony, as against a trader's market. Both are "Outposts" on the readout.
/obj/structure/overmap/dynamic/player_outpost/get_contact_variant()
	return "colony"

/obj/structure/overmap/dynamic/player_outpost/contains_site_turf(turf/location)
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths)
		if(bay?.contains_turf(location))
			return TRUE
	return ..()

/obj/structure/overmap/dynamic/player_outpost/Initialize(mapload)
	. = ..()
	GLOB.player_outposts += src

/obj/structure/overmap/dynamic/player_outpost/Destroy()
	// remove_mapzone() below wipes the whole level, so the zones let go without wiping their own
	for(var/key in level_zones)
		var/datum/outpost_zone/zone = level_zones[key]
		zone.retired = TRUE
	var/list/retired_registrations = checkpoints
	checkpoints = list()
	QDEL_LIST(retired_registrations)
	QDEL_LIST_ASSOC_VAL(outpost_upgrades)
	GLOB.player_outposts -= src
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths.Copy())
		if(bay)
			qdel(bay)
	bay_berths.Cut()
	QDEL_NULL(freight)
	QDEL_LIST(cargo_cart)
	// Escrowed docking fees are the visiting ship's money, not the outpost's
	refund_all_dock_fee_holds()
	QDEL_NULL(treasury)
	revoke_research_links()
	deltimer(home_service_timer)
	QDEL_NULL(current_advert)
	approved_ships.Cut()
	pending_dock_requests.Cut()
	pending_dock_variants.Cut()
	banned_ships.Cut()
	if(management_console)
		management_console.outpost = null
		management_console = null
	if(construction_console)
		construction_console.outpost = null
		construction_console = null
	template_bottom_left = null
	arrival_turf = null
	deltimer(area_sweep_timer)
	area_sweep_timer = null
	outpost_area = null
	// Admin deletion must not leak hangar ground (berths eject occupants
	// to the lobby, so release them while the mapzone still exists)
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth)
			berth.release(force = TRUE)
	berths = null
	QDEL_LIST_ASSOC_VAL(level_zones)
	remove_docks()
	remove_mapzone()
	return ..()

/obj/structure/overmap/dynamic/player_outpost/proc/remove_docks()
	if(reserve_dock)
		qdel(reserve_dock, TRUE)
		reserve_dock = null
	if(reserve_dock_secondary)
		qdel(reserve_dock_secondary, TRUE)
		reserve_dock_secondary = null

/obj/structure/overmap/dynamic/player_outpost/proc/remove_mapzone()
	if(mapzone)
		// Per-slot teardown - see /datum/map_zone/clear_to_uninitialized_space(). An
		// outpost owns a whole-level slot today, so this is the last-tenant-out path and
		// behaves exactly as it did before packing.
		var/datum/map_zone/departing_zone = mapzone
		var/datum/map_footprint/departing_footprint = footprint
		departing_zone.clear_to_uninitialized_space(departing_footprint)
		departing_zone.release_slot(departing_footprint)
		mapzone = null
		footprint = null

/obj/structure/overmap/dynamic/player_outpost/examine(mob/user)
	. = ..()
	if(founder_name)
		. += span_notice("Registered to [founder_name].")
	if(memo)
		. += span_notice("\"[memo]\"")
	switch(dock_mode)
		if(OUTPOST_DOCK_MODE_OPEN)
			. += span_notice("Broadcasting an open docking invitation.")
		if(OUTPOST_DOCK_MODE_REQUEST)
			. += span_notice("Docking by request only.")
		if(OUTPOST_DOCK_MODE_LOCKDOWN)
			. += span_warning("Docking clearance revoked for all outside vessels.")

// ===== OWNERSHIP =====

/// Whether the given mob is the outpost's owner. Ckey-based, so it survives death/respawn.
/obj/structure/overmap/dynamic/player_outpost/proc/is_owner(mob/user)
	return user?.ckey && user.ckey == founder_ckey

/// Retired bodies may retain a ckey, but only the owner's current mind can manage.
/obj/structure/overmap/dynamic/player_outpost/proc/is_current_management_user(mob/living/user)
	if(!istype(user) || QDELETED(user.mind) || user.mind.current != user || !can_manage(user))
		return FALSE
	var/datum/mind/current_owner = founder_mind?.resolve()
	return !is_owner(user) || !current_owner || current_owner == user.mind

/// A returning character retains their account's claims without gaining remote controls.
/mob/living/Login()
	. = ..()
	if(. && client)
		sync_player_outpost_owner()

/mob/living/proc/sync_player_outpost_owner()
	if(!mind)
		return
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(home.is_owner(src))
			home.founder_mind = WEAKREF(mind)

/// Whether the given mob may use the construction console
/obj/structure/overmap/dynamic/player_outpost/proc/can_build(mob/user)
	if(is_owner(user))
		return TRUE
	return user?.ckey && (user.ckey in authorized_builder_ckeys)

/// Whether the given ship carries the owner's crew (the founder's ship team)
/obj/structure/overmap/dynamic/player_outpost/proc/is_owner_crew_ship(obj/structure/overmap/ship/acting)
	if(!acting?.ship_team)
		return FALSE
	var/datum/mind/owner_mind = founder_mind?.resolve()
	if(!owner_mind)
		return FALSE
	return (acting.ship_team in owner_mind.ship_teams)

/// The ship the owner currently crews, if any (for docking-request notifications)
/obj/structure/overmap/dynamic/player_outpost/proc/get_owner_ship()
	var/datum/mind/owner_mind = founder_mind?.resolve()
	if(!owner_mind)
		return null
	for(var/datum/team/voidcrew/team as anything in owner_mind.ship_teams)
		if(team.ship)
			return team.ship
	return null

/// Notify the owner's current ship, if they crew one
/obj/structure/overmap/dynamic/player_outpost/proc/notify_owner(message, title = "OUTPOST")
	var/obj/structure/overmap/ship/owner_ship = get_owner_ship()
	if(owner_ship)
		owner_ship.ship_notify("[name]: [message]", title, SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30, anywhere = TRUE)

// ===== NOTIFICATIONS (see /obj/structure/overmap base hooks) =====

/// Notices reach everyone on the outpost plus the owner's crew ship
/obj/structure/overmap/dynamic/player_outpost/ship_notify(message, category = "ALERT", alert_level = SHIP_NOTIFY_NOTICE, sound_file = null, volume = 100)
	var/formatted
	switch(alert_level)
		if(SHIP_NOTIFY_DANGER)
			formatted = span_bolddanger("[name]: [message]")
		if(SHIP_NOTIFY_WARNING)
			formatted = span_boldwarning("[name]: [message]")
		else
			formatted = span_boldnotice("[name]: [message]")
	// The owner's crew hears about it wherever they are, through their ship
	var/obj/structure/overmap/ship/owner_ship = get_owner_ship()
	for(var/mob/living/occupant as anything in announcement_listeners(owner_ship))
		to_chat(occupant, formatted)
		if(sound_file && occupant.client)
			var/sound/S = sound(sound_file)
			S.volume = volume
			SEND_SOUND(occupant, S)
	// Relayed from the outpost, so it reaches them away from the ship too; the listeners above leave them out
	owner_ship?.ship_notify("[name]: [message]", category, alert_level, sound_file, volume, anywhere = TRUE)

/// Who on the level hears the outpost's announcements: the habitat, not the berths or the bay.
/// The owner's crew is left out; their own ship tells them.
/obj/structure/overmap/dynamic/player_outpost/proc/announcement_listeners(obj/structure/overmap/ship/owner_ship)
	. = list()
	if(!mapzone)
		return
	var/list/datum/mind/owner_crew = owner_ship?.ship_team?.members
	for(var/mob/living/occupant as anything in mapzone.get_mind_mobs_in(footprint))
		if((occupant.mind in owner_crew) || !is_habitat_turf(get_turf(occupant)))
			continue
		. += occupant

// ===== FOUNDING =====

/**
 * Completes founding: registers ownership, locks in zone rules, loads the
 * z-level and shell. Called by the shell catalog UI right after creation.
 * Returns TRUE on success; on failure the outpost deletes itself.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/found(mob/living/founder, datum/map_template/player_outpost/shell, outpost_name)
	// A single site may only be initialized once, regardless of how many sites its owner holds.
	if(founder_ckey || loaded || loading)
		return FALSE
	if(!founder?.ckey || !founder.mind)
		qdel(src)
		return FALSE
	founder_ckey = founder.ckey
	founder_name = founder.real_name
	founder_mind = WEAKREF(founder.mind)
	// Snapshot the actual crew before map loading yields; nearby ships are visitors.
	var/obj/structure/overmap/ship/founding_ship = get_crew_ship(founder)
	var/list/datum/mind/founding_crew = founding_ship?.ship_team?.members.Copy()
	shell_template = shell
	name = outpost_name
	display_name = outpost_name

	founded_zone = SSovermap.get_zone_band_for_turf(get_turf(src))

	// Preserve the loader's own recovery boundaries for individual map errors.
	// A broad catch here unwinds past their cleanup instead of allowing it to run.
	var/site_ready = load_level()
	if(!site_ready)
		qdel(src)
		return FALSE

	// Spawned onto the tile the founding ship is sitting still on; no ENTERED
	// fires, so register with co-located ships now or the outpost stays hidden
	// from their helm/sensors until they re-cross the tile.
	sync_close_overmap_objects()

	residents |= founder.mind
	resident_clearance[founder_ckey] = resident_access_revision
	register_founding_crew(founding_crew)

	priority_announce("[founder_name]'s crew has founded the outpost [name] in [founded_zone == ZONE_GREEN ? "patrolled" : "unpatrolled"] space.", "Colonial Registry")
	log_shuttle("PLAYER OUTPOST: [key_name(founder)] founded '[name]' ([shell.name]) at zone [founded_zone]")
	message_admins("[key_name_admin(founder)] founded player outpost '[name]'")
	return TRUE

/**
 * Allocates the outpost's z-level (empty-space pattern: construction allowed), carves its
 * zones (outpost_level_layout.dm) and centers the shell template in the build region.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/load_level()
	if(mapzone || loading)
		return FALSE
	loading = TRUE

	if(!shell_template?.width || !shell_template?.height)
		log_mapping("PLAYER OUTPOST: Shell template '[shell_template?.name]' has no dimensions, cannot load.")
		loading = FALSE
		return FALSE
	outpost_style = shell_template.outpost_style || OUTPOST_STYLE_DEFAULT

	// MAP_TENANT_CLASS_OUTPOST, never FLAT: an outpost is a long-lived, preserve_level-shaped
	// tenant that would pin a lattice slot for the whole round, so it gets its own class and
	// never shares a level with the flat encounters that recycle every few minutes. The class
	// deals one whole-level slot today, which is exactly the allocation outposts already had.
	var/list/dynamic_encounter_values = SSovermap.spawn_dynamic_encounter(null, FALSE, tenant_class = MAP_TENANT_CLASS_OUTPOST, tenant_owner = src)
	if(!length(dynamic_encounter_values))
		loading = FALSE
		return FALSE
	mapzone = dynamic_encounter_values[1]
	footprint = LAZYACCESS(dynamic_encounter_values, 4)
	// Ships reach an outpost by hangar elevator only; the encounter's two reserve pads would
	// sit on the berth and bay zones.
	reserve_dock = dynamic_encounter_values[2]
	reserve_dock_secondary = dynamic_encounter_values[3]
	remove_docks()

	var/datum/space_level/zlevel = mapzone.z_levels[1]
	// Berth, bay, shipyard and ferry zones, cordon round them, and build_bounds.
	carve_level(zlevel)
	// Center the entire shell within the build region, leaving room to expand on every side.
	var/turf/bottom_left = locate(
		build_bounds[1] + round((build_bounds[3] - build_bounds[1] + 1 - shell_template.width) / 2),
		build_bounds[2] + round((build_bounds[4] - build_bounds[2] + 1 - shell_template.height) / 2),
		zlevel.z_value
	)
	if(!bottom_left)
		log_mapping("PLAYER OUTPOST: Could not locate shell origin turf.")
		fail_load()
		return FALSE

	var/load_success = shell_template.load(bottom_left)

	if(!load_success)
		fail_load()
		return FALSE

	template_bottom_left = bottom_left

	link_interior_machinery()

	// The loader gave the shell its own /area/voidcrew/player_outpost instance
	// (non-UNIQUE_AREA). Grab it so built turfs can be adopted into it. Corner
	// tiles are template_noop, so scan for it rather than trusting a corner.
	var/turf/shell_top_right = locate(
		bottom_left.x + shell_template.width - 1,
		bottom_left.y + shell_template.height - 1,
		bottom_left.z
	)
	for(var/turf/interior_turf as anything in block(bottom_left, shell_top_right))
		var/area/candidate = interior_turf.loc
		if(istype(candidate, /area/voidcrew/player_outpost))
			outpost_area = candidate
			break
	if(outpost_area)
		area_sweep_timer = addtimer(CALLBACK(src, PROC_REF(adopt_built_turfs)), PLAYER_OUTPOST_AREA_SWEEP_INTERVAL, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	else
		log_mapping("PLAYER OUTPOST: Shell '[shell_template.name]' loaded without a /area/voidcrew/player_outpost area; built turfs cannot be powered.")

	ensure_home_services()
	if(!install_home_bundle())
		fail_load()
		return FALSE
	loaded = TRUE
	loading = FALSE
	home_service_timer = addtimer(CALLBACK(src, PROC_REF(process_home_services)), 5 SECONDS, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	return TRUE

/// Cleanup after a failed shell load: release the freshly-claimed mapzone
/obj/structure/overmap/dynamic/player_outpost/proc/fail_load()
	remove_docks()
	remove_mapzone()
	loading = FALSE

/// Whether this outpost has an operational hangar elevator (placed via the
/// construction console). With one installed, docking switches to hangar berths.
/obj/structure/overmap/dynamic/player_outpost/proc/has_hangar_elevator()
	return length(lobby_alcove_turfs) && length(lobby_panels)

/// Whether the given turf is inside the outpost's buildable region
/obj/structure/overmap/dynamic/player_outpost/proc/is_turf_buildable(turf/target)
	if(!target || !build_bounds || !mapzone)
		return FALSE
	var/datum/space_level/zlevel = mapzone.z_levels[1]
	if(!zlevel || target.z != zlevel.z_value)
		return FALSE
	return (target.x >= build_bounds[1] && target.y >= build_bounds[2] && target.x <= build_bounds[3] && target.y <= build_bounds[4])

/**
 * Adopts a turf into the outpost's area, giving it APC power coverage and
 * gravity. Called by the construction console when the drone builds outside
 * the current area, and by the periodic sweep for hand-built structures.
 * Only ever claims turfs from the encounter's default space area, docked
 * shuttles, ruins and anything else keep their own areas.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/adopt_turf(turf/target)
	if(!outpost_area || !is_turf_buildable(target))
		return
	var/area/old_area = get_area(target)
	if(old_area == outpost_area || !istype(old_area, /area/space))
		return
	target.change_area(old_area, outpost_area)
	queue_room_power_join()

/**
 * Safety-net sweep over the build region: anything constructed by hand (no
 * console involved) still joins the outpost area. Otherwise those rooms would
 * sit in the space area forever: unpowered, dark and weightless.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/adopt_built_turfs()
	if(!outpost_area || !build_bounds || !mapzone)
		return
	var/datum/space_level/zlevel = mapzone.z_levels[1]
	if(!zlevel)
		return
	var/turf/sweep_bottom_left = locate(build_bounds[1], build_bounds[2], zlevel.z_value)
	var/turf/sweep_top_right = locate(build_bounds[3], build_bounds[4], zlevel.z_value)
	if(!sweep_bottom_left || !sweep_top_right)
		return
	for(var/turf/target as anything in block(sweep_bottom_left, sweep_top_right))
		CHECK_TICK
		if(isspaceturf(target))
			continue
		adopt_turf(target)

/**
 * Finds the machinery the shell spawned and links it to this outpost.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/link_interior_machinery()
	if(!template_bottom_left || !shell_template?.width || !shell_template?.height)
		return
	var/turf/top_right = locate(
		template_bottom_left.x + shell_template.width - 1,
		template_bottom_left.y + shell_template.height - 1,
		template_bottom_left.z
	)
	if(!top_right)
		return
	for(var/turf/interior_turf as anything in block(template_bottom_left, top_right))
		for(var/obj/effect/landmark/player_outpost_arrival/mark in interior_turf)
			arrival_turf = interior_turf
			qdel(mark)
		// block() iterates y-major then x, same order the hangar-side alcove
		// collects in, so the elevator's ride maps alcove turf i to alcove turf i
		for(var/obj/effect/landmark/outpost_elevator_alcove/alcove_mark in interior_turf)
			lobby_alcove_turfs += interior_turf
			qdel(alcove_mark)
		for(var/obj/machinery/machine in interior_turf)
			if(istype(machine, /obj/machinery/computer/player_outpost_management))
				var/obj/machinery/computer/player_outpost_management/console = machine
				console.outpost = src
				management_console = console
			else if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship/outpost))
				var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/builder = machine
				builder.outpost = src
				construction_console = builder
			else if(istype(machine, /obj/machinery/outpost_elevator))
				// Shells ship with a hangar elevator pre-installed. Its backing
				// wall is shell hull, so lobby_wall_turfs stays empty, relocating
				// the elevator later leaves that wall standing instead of
				// reverting it to plating (which could breach the shell).
				var/obj/machinery/outpost_elevator/panel = machine
				panel.outpost = src
				panel.is_lobby = TRUE
				lobby_panels += panel

/obj/structure/overmap/dynamic/player_outpost/attack_ghost(mob/user)
	if(arrival_turf)
		user.forceMove(arrival_turf)
		return TRUE
	return ..()

// ===== RENAME / MEMO =====

/**
 * Renames the outpost (galaxy-visible). Mirrors /obj/structure/overmap/ship/set_ship_name:
 * cooldown-gated, announced, admin-logged. Returns TRUE on success.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/set_outpost_name(new_name, mob/user)
	if(!new_name || new_name == name)
		return FALSE
	if(!COOLDOWN_FINISHED(src, rename_cooldown))
		return FALSE
	priority_announce("The outpost [name] has been renamed to [new_name].", "Colonial Registry")
	message_admins("[key_name_admin(user)] renamed player outpost '[name]' to '[new_name]'")
	name = new_name
	display_name = new_name
	if(treasury)
		treasury.account_holder = "[new_name] Treasury"
	COOLDOWN_START(src, rename_cooldown, PLAYER_OUTPOST_RENAME_COOLDOWN)
	return TRUE

/// Sets the owner memo (already sanitized by the console)
/obj/structure/overmap/dynamic/player_outpost/proc/set_memo(new_memo)
	memo = new_memo
	desc = length(memo) ? "An independent outpost. \"[memo]\"" : "An independent outpost."

// ===== DOCKING =====

/**
 * Handles a visiting ship: access control first, then a hangar berth or the ship
 * bay on the outpost's own level. The level is always loaded (founding loads it).
 */
/obj/structure/overmap/dynamic/player_outpost/get_dock_description()
	// Access control still runs on the actual dock attempt, this only promises the
	// button will ask, not that the outpost will say yes.
	return "[name] (hangar berth)"

/// Outpost shells are STANDARD_GRAVITY, and adopted turfs inherit that, so a berthed
/// ship stays weighted regardless of what its own plating is doing.
/obj/structure/overmap/dynamic/player_outpost/has_ambient_gravity()
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner, dock_variant)
	// dock() refuses interdicted ships only after a dock slot below is claimed
	// and the ship is locked into ACTING - refuse up front instead
	if(acting.is_interdicted)
		to_chat(user, span_warning("Cannot dock while interdicted!"))
		return
	if(concerned)
		to_chat(user, span_notice("Too much traffic, try again later!"))
		return
	if(!loaded)
		to_chat(user, span_warning("The outpost's transponder isn't responding."))
		return

	if(dock_variant && (dock_variant != OUTPOST_DOCK_VARIANT_BAY || !ship_bay_installed || !has_hangar_elevator()))
		to_chat(user, span_warning("Ship bay unavailable."))
		return
	var/denial = get_docking_denial(acting)
	if(denial)
		if(acting in pending_dock_requests)
			pending_dock_variants[acting] = dock_variant
		to_chat(user, span_warning(denial))
		return
	// The ship bay's docking fee: quoted to the helm until the captain approves it (outpost_dock_fees.dm)
	var/fee_denial = dock_fee_denial(acting, dock_variant)
	if(fee_denial)
		to_chat(user, span_warning(fee_denial))
		return

	concerned = TRUE
	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING
	balloon_alert(user, "starting docking process..")

	var/obj/docking_port/stationary/dock_to_use = null
	var/datum/outpost_berth/berth = null
	// Port destinations are set by survey consoles
	if(acting.shuttle.port_destinations && !dock_variant)
		dock_to_use = acting.shuttle.port_destinations
	else
		var/long_axis = max(acting.shuttle.width, acting.shuttle.height)
		var/short_axis = min(acting.shuttle.width, acting.shuttle.height)
		if(long_axis > RESERVE_DOCK_MAX_SIZE_LONG || short_axis > RESERVE_DOCK_MAX_SIZE_SHORT)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_warning("Ship is too large to dock at [name]."))
			return

		// Ships berth in the hangar zones on the outpost's own level, reached by the hangar
		// elevator; there are no landing pads (see outpost_level_layout.dm)
		if(!has_hangar_elevator())
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_notice("[name] traffic control: the hangar lift is down. No berths available."))
			return
		berth = dock_variant == OUTPOST_DOCK_VARIANT_BAY ? allocate_ship_bay(acting) : allocate_berth(acting)
		if(!berth)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_notice("[name] traffic control: no [dock_variant ? "ship bay" : "hangar"] berth is available. Try again later."))
			return
		adjust_reserve_dock_to_shuttle(berth.dock, acting.shuttle)
		dock_to_use = berth.dock

	if(acting.shuttle.height > dock_to_use.height || acting.shuttle.width > dock_to_use.width)
		berth?.release(force = TRUE) // nothing has landed yet, safe to free immediately
		acting.release_berth_flags(src)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Ship is too large to dock at this location."))
		return

	// Escrow the approved docking fee. No yield between this and dock().
	var/fee_refusal = take_dock_fee(acting, dock_variant)
	if(fee_refusal)
		berth?.release(force = TRUE)
		acting.release_berth_flags(src)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning(fee_refusal))
		return

	// dock() only returns a string when it refuses; a successful start is announced
	// to the whole crew by ship_notify()
	var/dock_result = acting.dock(src, dock_to_use)
	if(dock_result)
		refund_dock_fee_hold(acting, "dock refused")
		berth?.release(force = TRUE)
		acting.release_berth_flags(src)
		acting.state = prev_state
		to_chat(user, span_notice("[dock_result]"))
	concerned = FALSE

	if(optional_partner)
		ship_act(user, optional_partner, dock_variant = dock_variant)

/**
 * Access control. Returns a denial message, or null when the ship may dock.
 * Owner-crew ships always pass. Queues a docking request as a side effect in
 * REQUEST mode.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/get_docking_denial(obj/structure/overmap/ship/acting)
	if(banned_ships[acting])
		return "[name] traffic control: your vessel has been denied docking privileges."
	if(is_owner_crew_ship(acting))
		return null
	switch(dock_mode)
		if(OUTPOST_DOCK_MODE_OPEN)
			return null
		if(OUTPOST_DOCK_MODE_LOCKDOWN)
			return "[name] traffic control: outpost is in lockdown. Docking denied."
		if(OUTPOST_DOCK_MODE_REQUEST)
			if(approved_ships[acting])
				return null
			var/requested_at = pending_dock_requests[acting]
			if(requested_at && (world.time - requested_at) < OUTPOST_DOCK_REQUEST_TIMEOUT)
				return "[name] traffic control: docking clearance still pending. Hold position."
			pending_dock_requests[acting] = world.time
			notify_owner("[acting.name] is requesting docking clearance.", "DOCKING REQUEST")
			management_console?.on_dock_requests_changed()
			return "[name] traffic control: docking clearance requested. Hold position."
	return null

/// Owner approved a pending request
/obj/structure/overmap/dynamic/player_outpost/proc/approve_dock_request(obj/structure/overmap/ship/requester)
	if(QDELETED(requester) || !(requester in pending_dock_requests))
		return
	var/dock_variant = pending_dock_variants[requester]
	pending_dock_variants -= requester
	pending_dock_requests -= requester
	approved_ships[requester] = TRUE
	requester.ship_notify("[name]: docking clearance granted.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	// Continue the approach they requested, only while still waiting at this site.
	if(loaded && get_turf(src) && requester.loc == loc && requester.state == OVERMAP_SHIP_FLYING && requester.is_still() && !requester.is_interdicted && !QDELETED(requester.shuttle))
		requester.overmap_object_act(null, src, dock_variant = dock_variant)

/// Owner denied a pending request
/obj/structure/overmap/dynamic/player_outpost/proc/deny_dock_request(obj/structure/overmap/ship/requester)
	pending_dock_variants -= requester
	pending_dock_requests -= requester
	requester.ship_notify("[name]: docking clearance denied.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/// Drop expired requests and dead ship refs before showing the list
/obj/structure/overmap/dynamic/player_outpost/proc/prune_dock_requests()
	for(var/obj/structure/overmap/ship/requester in pending_dock_requests)
		if(QDELETED(requester) || (world.time - pending_dock_requests[requester]) >= OUTPOST_DOCK_REQUEST_TIMEOUT)
			pending_dock_requests -= requester
			pending_dock_variants -= requester

// ===== ABANDON / TRANSFER =====

/**
 * The owner walks away: ownership clears, docking opens up, adverts die.
 * The physical outpost persists (round-permanent by design). The previous
 * owner can found or claim another outpost at any time.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/abandon(mob/user, admin_override = FALSE)
	if(admin_override ? !check_rights_for(user?.client, R_ADMIN) : !is_owner(user))
		return
	priority_announce("The outpost [name] has been abandoned by its owner. Salvage rights unclaimed.", "Colonial Registry")
	message_admins("[key_name_admin(user)] abandoned player outpost '[name]'")
	// Intake closes and the prisoners are transferred out (outpost_prison_economy.dm).
	running_prison()?.on_outpost_abandoned()
	stewards.Cut()
	treasurers.Cut()
	resident_mode = "closed"
	resident_clearance.Cut()
	revoke_research_links()
	revoke_bay_materials()
	freight?.cancel_pending()
	founder_ckey = null
	founder_name = null
	founder_mind = null
	dock_mode = OUTPOST_DOCK_MODE_OPEN
	authorized_builder_ckeys.Cut()
	pending_dock_requests.Cut()
	pending_dock_variants.Cut()
	QDEL_NULL(current_advert)
	reset_market_on_abandon() // VOIDCREW MARKET: pricers, prices, playtest billing, room settings

/**
 * Transfers ownership to another player, or accepts a local claim on an unowned site.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/transfer_ownership(mob/living/new_owner, mob/user, admin_override = FALSE)
	if(!istype(new_owner) || !new_owner.ckey || !new_owner.mind)
		return FALSE
	var/claiming = new_owner == user && can_claim(user)
	if(admin_override ? !check_rights_for(user?.client, R_ADMIN) : (!is_owner(user) && !claiming))
		return FALSE
	// An owner cannot retain command or spending by delegating authority to themselves
	// before transferring the deed. Other residents retain their independent grants.
	revoke_research_links()
	revoke_bay_materials()
	var/datum/mind/former_owner = founder_mind?.resolve()
	stewards -= former_owner
	treasurers -= former_owner
	stewards -= user.mind
	treasurers -= user.mind
	pricers -= former_owner
	pricers -= user.mind
	playtest_visitor_ckey = null
	stop_all_bay_evictions() // VOIDCREW MARKET: an eviction ordered by the former owner does not outlive the deed
	if(claiming)
		// A claimant starts with their own crew, not the previous owner's residents
		residents.Cut()
		stewards.Cut()
		treasurers.Cut()
		pricers.Cut()
	else if(former_owner && former_owner != new_owner.mind)
		// The former owner is not kept on as a member; the new owner can add them back
		residents -= former_owner
	authorized_builder_ckeys -= founder_ckey
	residents |= new_owner.mind
	resident_clearance[new_owner.ckey] = resident_access_revision
	blocked_residents -= new_owner.ckey
	founder_ckey = new_owner.ckey
	founder_name = new_owner.real_name
	founder_mind = WEAKREF(new_owner.mind)
	if(claiming)
		var/obj/structure/overmap/ship/claiming_ship = get_crew_ship(new_owner)
		register_founding_crew(claiming_ship?.ship_team?.members.Copy())
		resident_mode = "approved"
	message_admins("[key_name_admin(user)] transferred player outpost '[name]' to [key_name_admin(new_owner)]")
	to_chat(new_owner, span_boldnotice("You are now the registered owner of [name]."))
	return TRUE

/// A claim must be vacant and visited in person; prior ownership never disqualifies a player.
/obj/structure/overmap/dynamic/player_outpost/proc/can_claim(mob/living/user)
	return !founder_ckey && loaded && !loading && is_management_candidate(user) && user.mind.current == user
