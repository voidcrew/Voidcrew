/**
 * # Player Outpost
 *
 * A player-founded, player-built station on the overmap. Founded by using an
 * outpost deed (see outpost_deed.dm) while the crew's ship sits on an empty
 * overmap tile: the founder picks a shell template, the outpost gets its own
 * z-level (same substrate as empty-space docking, so construction is allowed),
 * and the shell is loaded next to two reserve docks.
 *
 * Once founded the outpost is permanent for the round, it never unloads and
 * never moves. Zone rules are locked in at founding: green-zone outposts are
 * protected from ship weapons, yellow/red outposts are raidable.
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
	/// Whether ship weapons may target this outpost. Locked in at founding from the zone band.
	var/raidable = FALSE
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
	/// Shield generators built on this outpost's z-level, in registration order.
	/// Only the first operational one holds the shield at any moment (see outpost_shield.dm). Lazy.
	var/list/shield_generators
	var/loaded = FALSE
	var/loading = FALSE
	COOLDOWN_DECLARE(rename_cooldown)
	COOLDOWN_DECLARE(advert_cooldown)

/// Somebody's colony, as against a trader's market. Both are "Outposts" on the readout.
/obj/structure/overmap/dynamic/player_outpost/get_contact_variant()
	return "colony"

/obj/structure/overmap/dynamic/player_outpost/contains_site_turf(turf/location)
	return ..() || freight_berth?.reservation?.contains_turf(location)

/obj/structure/overmap/dynamic/player_outpost/Initialize(mapload)
	. = ..()
	GLOB.player_outposts += src

/obj/structure/overmap/dynamic/player_outpost/Destroy()
	GLOB.player_outposts -= src
	QDEL_NULL(freight)
	QDEL_NULL(freight_berth)
	QDEL_LIST(cargo_cart)
	QDEL_NULL(treasury)
	revoke_research_links()
	deltimer(home_service_timer)
	QDEL_NULL(current_advert)
	approved_ships.Cut()
	pending_dock_requests.Cut()
	banned_ships.Cut()
	if(management_console)
		management_console.outpost = null
		management_console = null
	if(construction_console)
		construction_console.outpost = null
		construction_console = null
	for(var/obj/machinery/outpost_shield_generator/generator as anything in shield_generators)
		generator.outpost = null
	shield_generators = null
	template_bottom_left = null
	arrival_turf = null
	deltimer(area_sweep_timer)
	area_sweep_timer = null
	outpost_area = null
	// Admin deletion must not leak hangar reservations (berths eject occupants
	// to the lobby, so release them while the mapzone still exists)
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth)
			berth.release(force = TRUE)
	berths = null
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
	if(raidable)
		. += span_danger("This deep-space claim is outside patrolled space. It can be attacked.")
		if(get_shield_generator()?.charge > 0)
			. += span_boldnotice("Sensors show an energy shield up around the claim.")
	else
		. += span_notice("Registered in patrolled space. Protected from ship weapons.")

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
		owner_ship.ship_notify("[name]: [message]", title, SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)

// ===== COMBAT TARGET API (see /obj/structure/overmap base hooks) =====

/// Combat notifications reach everyone on the outpost plus the owner's crew ship
/obj/structure/overmap/dynamic/player_outpost/ship_notify(message, category = "ALERT", alert_level = SHIP_NOTIFY_NOTICE, sound_file = null, volume = 100)
	var/formatted
	switch(alert_level)
		if(SHIP_NOTIFY_DANGER)
			formatted = span_bolddanger("[name]: [message]")
		if(SHIP_NOTIFY_WARNING)
			formatted = span_boldwarning("[name]: [message]")
		else
			formatted = span_boldnotice("[name]: [message]")
	if(mapzone)
		for(var/mob/living/occupant as anything in mapzone.get_mind_mobs_in(footprint))
			to_chat(occupant, formatted)
			if(sound_file && occupant.client)
				var/sound/S = sound(sound_file)
				S.volume = volume
				SEND_SOUND(occupant, S)
	// The owner hears about it wherever they are
	var/obj/structure/overmap/ship/owner_ship = get_owner_ship()
	if(owner_ship && !(mapzone && (owner_ship.docked == src)))
		owner_ship.ship_notify("[name]: [message]", category, alert_level, sound_file, volume)

/obj/structure/overmap/dynamic/player_outpost/is_combat_targetable()
	return raidable

// Null: the outpost owns its whole z-level, so sounds/shakes need no area filter
/obj/structure/overmap/dynamic/player_outpost/get_combat_target_areas()
	return null

/obj/structure/overmap/dynamic/player_outpost/get_combat_bounds()
	return build_bounds

/obj/structure/overmap/dynamic/player_outpost/combat_camera_can_view(turf/T)
	return is_turf_buildable(T)

/obj/structure/overmap/dynamic/player_outpost/get_combat_camera_turfs()
	if(!build_bounds || !mapzone)
		return null
	var/datum/space_level/zlevel = mapzone.z_levels[1]
	if(!zlevel)
		return null
	return block(
		locate(build_bounds[1], build_bounds[2], zlevel.z_value),
		locate(build_bounds[3], build_bounds[4], zlevel.z_value)
	)

/obj/structure/overmap/dynamic/player_outpost/get_combat_default_turf()
	return arrival_turf

// ===== SHIELD GENERATORS (see outpost_shield.dm) =====

/// Registers a shield generator built on this outpost's z-level. Idempotent.
/obj/structure/overmap/dynamic/player_outpost/proc/register_shield_generator(obj/machinery/outpost_shield_generator/generator)
	LAZYOR(shield_generators, generator)

/// Unregisters a destroyed/deconstructed shield generator
/obj/structure/overmap/dynamic/player_outpost/proc/unregister_shield_generator(obj/machinery/outpost_shield_generator/generator)
	LAZYREMOVE(shield_generators, generator)

/**
 * The generator currently holding the shield: the first registered one that is
 * anchored and powered. Only this unit charges and absorbs, extra generators
 * are cold standbys that take over (empty) if it's destroyed or loses power,
 * so stacking generators never multiplies effective shield charge.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/get_shield_generator()
	for(var/obj/machinery/outpost_shield_generator/generator as anything in shield_generators)
		if(generator.is_operational_unit())
			return generator
	return null

/**
 * Siege damage interception: while the active generator has charge, the hit is
 * absorbed (charge drains by damage) and the outpost is unharmed. Returns TRUE
 * when absorbed. Depleted, unpowered or absent shields let everything through.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/try_absorb_siege_damage(damage, turf/impact_loc, obj/structure/overmap/ship/attacker)
	var/obj/machinery/outpost_shield_generator/generator = get_shield_generator()
	if(!generator || generator.charge <= 0)
		return FALSE
	generator.absorb_hit(damage, impact_loc, attacker)
	return TRUE

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
	raidable = (founded_zone != ZONE_GREEN)

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
 * Allocates the outpost's z-level (empty-space pattern: construction allowed,
 * two reserve docks included) and centers the shell template on the level.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/load_level()
	if(mapzone || loading)
		return FALSE
	loading = TRUE

	if(!shell_template?.width || !shell_template?.height)
		log_mapping("PLAYER OUTPOST: Shell template '[shell_template?.name]' has no dimensions, cannot load.")
		loading = FALSE
		return FALSE

	// MAP_TENANT_CLASS_OUTPOST, never FLAT: an outpost is a long-lived, preserve_level-shaped
	// tenant that would pin a lattice slot for the whole round, so it gets its own class and
	// never shares a level with the flat encounters that recycle every few minutes. The class
	// deals one whole-level slot today, which is exactly the allocation outposts already had.
	var/list/dynamic_encounter_values = SSovermap.spawn_dynamic_encounter(null, FALSE, tenant_class = MAP_TENANT_CLASS_OUTPOST, tenant_owner = src)
	if(!length(dynamic_encounter_values))
		loading = FALSE
		return FALSE
	mapzone = dynamic_encounter_values[1]
	reserve_dock = dynamic_encounter_values[2]
	reserve_dock_secondary = dynamic_encounter_values[3]
	footprint = LAZYACCESS(dynamic_encounter_values, 4)

	var/datum/space_level/zlevel = mapzone.z_levels[1]
	// Anchored off the outpost's own footprint - the level rect only happens to agree
	// while an outpost owns a whole level.
	var/anchor_low_x = footprint ? footprint.low_x : zlevel.low_x
	var/anchor_low_y = footprint ? footprint.low_y : zlevel.low_y
	var/anchor_high_x = footprint ? footprint.high_x : zlevel.high_x
	var/anchor_high_y = footprint ? footprint.high_y : zlevel.high_y
	// Center the entire shell within the owned footprint, leaving room to expand on every side.
	var/turf/bottom_left = locate(
		anchor_low_x + round((anchor_high_x - anchor_low_x + 1 - shell_template.width) / 2),
		anchor_low_y + round((anchor_high_y - anchor_low_y + 1 - shell_template.height) / 2),
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

	// The claim owns the entire level; every shell gets the same room to build.
	build_bounds = list(anchor_low_x, anchor_low_y, anchor_high_x, anchor_high_y)

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
 * Handles a visiting ship: access control first, then the planet-style
 * two-dock allocation. The level is always loaded (founding loads it).
 */
/obj/structure/overmap/dynamic/player_outpost/get_dock_description()
	// Access control still runs on the actual dock attempt, this only promises the
	// button will ask, not that the outpost will say yes.
	return "[name] (hangar berth)"

/// Outpost shells are STANDARD_GRAVITY, and adopted turfs inherit that, so a berthed
/// ship stays weighted regardless of what its own plating is doing.
/obj/structure/overmap/dynamic/player_outpost/has_ambient_gravity()
	return TRUE

/obj/structure/overmap/dynamic/player_outpost/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
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

	var/denial = get_docking_denial(acting)
	if(denial)
		to_chat(user, span_warning(denial))
		return

	concerned = TRUE
	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING
	balloon_alert(user, "starting docking process..")

	var/obj/docking_port/stationary/dock_to_use = null
	var/datum/outpost_berth/berth = null
	// Port destinations are set by survey consoles
	if(acting.shuttle.port_destinations)
		dock_to_use = acting.shuttle.port_destinations
	else
		var/long_axis = max(acting.shuttle.width, acting.shuttle.height)
		var/short_axis = min(acting.shuttle.width, acting.shuttle.height)
		if(long_axis > RESERVE_DOCK_MAX_SIZE_LONG || short_axis > RESERVE_DOCK_MAX_SIZE_SHORT)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_warning("Ship is too large to dock at [name]."))
			return

		if(has_hangar_elevator())
			// A placed hangar elevator upgrades docking to per-ship berths,
			// exactly like the trader outposts (see outpost_hangar.dm)
			berth = allocate_berth(acting)
			if(!berth)
				acting.state = prev_state
				concerned = FALSE
				to_chat(user, span_notice("[name] traffic control: all hangar berths are occupied. Try again later."))
				return
			adjust_reserve_dock_to_shuttle(berth.dock, acting.shuttle)
			dock_to_use = berth.dock
		else
			// Berths do not stay where they were built - see reset_free_reserve_docks_for(). Put
			// the free ones back before choosing one, or the last visitor's offset is carried into
			// this placement and compounds on every arrival. Only the padded reserve docks need
			// this; the hangar-elevator branch above hands out mapped per-ship berths instead.
			reset_free_reserve_docks_for(reserve_dock, reserve_dock_secondary, first_dock_taken, second_dock_taken)
			if(reserve_dock && !first_dock_taken && !reserve_dock.get_docked())
				dock_to_use = reserve_dock
				first_dock_taken = TRUE
				acting.dock_index = 1
			else if(reserve_dock_secondary && !second_dock_taken && !reserve_dock_secondary.get_docked())
				dock_to_use = reserve_dock_secondary
				second_dock_taken = TRUE
				acting.dock_index = 2

			if(!dock_to_use)
				acting.state = prev_state
				concerned = FALSE
				to_chat(user, span_notice("[name] traffic control: all docking pads are occupied."))
				return
			adjust_reserve_dock_to_shuttle(dock_to_use, acting.shuttle)

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
	pending_dock_requests -= requester
	approved_ships[requester] = TRUE
	requester.ship_notify("[name]: docking clearance granted.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	// Continue the approach they requested, only while still waiting at this site.
	if(loaded && get_turf(src) && requester.loc == loc && requester.state == OVERMAP_SHIP_FLYING && requester.is_still() && !requester.is_interdicted && !QDELETED(requester.shuttle))
		requester.overmap_object_act(null, src)

/// Owner denied a pending request
/obj/structure/overmap/dynamic/player_outpost/proc/deny_dock_request(obj/structure/overmap/ship/requester)
	pending_dock_requests -= requester
	requester.ship_notify("[name]: docking clearance denied.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/// Drop expired requests and dead ship refs before showing the list
/obj/structure/overmap/dynamic/player_outpost/proc/prune_dock_requests()
	for(var/obj/structure/overmap/ship/requester in pending_dock_requests)
		if(QDELETED(requester) || (world.time - pending_dock_requests[requester]) >= OUTPOST_DOCK_REQUEST_TIMEOUT)
			pending_dock_requests -= requester

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
	stewards.Cut()
	treasurers.Cut()
	resident_mode = "closed"
	resident_clearance.Cut()
	revoke_research_links()
	freight?.cancel_pending()
	founder_ckey = null
	founder_name = null
	founder_mind = null
	dock_mode = OUTPOST_DOCK_MODE_OPEN
	authorized_builder_ckeys.Cut()
	pending_dock_requests.Cut()
	QDEL_NULL(current_advert)

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
	var/datum/mind/former_owner = founder_mind?.resolve()
	stewards -= former_owner
	treasurers -= former_owner
	stewards -= user.mind
	treasurers -= user.mind
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
