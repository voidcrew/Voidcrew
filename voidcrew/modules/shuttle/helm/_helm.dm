#define JUMP_STATE_OFF 0
#define JUMP_STATE_CHARGING 1
#define JUMP_STATE_IONIZING 2
#define JUMP_STATE_FIRING 3
#define JUMP_STATE_FINALIZED 4
#define JUMP_CHARGE_DELAY (20 SECONDS)
#define JUMP_CHARGEUP_TIME (3 MINUTES)
/// Minimum gap between hails sent from one console. A hail fans out to every helm
/// in the view ring and lands in each one's comms log, so it needs a floor.
#define HAIL_SEND_COOLDOWN (3 SECONDS)
/// Minimum gap between keystroke sounds. The comms field asks for one per keypress.
#define TYPING_SOUND_COOLDOWN (0.4 SECONDS)

/// How drunk a pilot has to be before the helm starts punishing manual course changes.
#define HELM_DRUNK_THRESHOLD 10
/// Added chance, in percent, that a heading input goes astray per point of drunkenness past the threshold.
#define HELM_DRUNK_CHANCE_PER_POINT 0.8
/// Ceiling on the chance that a heading input goes astray, no matter how far gone the pilot is.
#define HELM_DRUNK_MAX_CHANCE 50

/datum/armor/computer_helm
	melee = 50
	bullet = 30
	laser = 30
	energy = 30
	bomb = 50
	fire = 80
	acid = 70

/obj/machinery/computer/helm
	name = "helm control console"
	desc = "Used to view or control the ship."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "navigation"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/shuttle/helm
	light_color = LIGHT_COLOR_FLARE
	// Helm consoles are critical ship infrastructure - make them tough
	max_integrity = 500
	armor_type = /datum/armor/computer_helm

	/// The ship we reside on for ease of access
	var/obj/structure/overmap/ship/current_ship //voidcrew todo: ship functionality
	/// All users currently using this
	var/list/concurrent_users = list()
	/// Is this console view only? I.E. cant dock/etc
	var/viewer = FALSE
	/// When are we allowed to jump
	var/jump_allowed
	/// Current state of our jump
	var/jump_state = JUMP_STATE_OFF
	///if we are calibrating the jump
	var/calibrating = FALSE
	///holding jump timer ID
	var/jump_timer
	/// Last known ship state for detecting changes
	var/last_ship_state
	/// Last known integrity percent for threshold detection
	var/last_integrity_percent = 100
	/// Whether we've played the 55% alert already
	var/played_55_alert = FALSE
	/// Console ambient sounds
	var/datum/console_ambience/console_ambience

	COOLDOWN_DECLARE(hail_send_cooldown)
	COOLDOWN_DECLARE(typing_sound_cooldown)

/obj/machinery/computer/helm/Initialize(mapload)
	. = ..()
	// Console ambient sounds (not for viewscreens)
	if(!viewer)
		console_ambience = new(src, get_console_ambience_sounds())
		console_ambience.start()

/obj/machinery/computer/helm/Destroy()
	QDEL_NULL(console_ambience)
	if(current_ship)
		LAZYREMOVE(current_ship.helm_consoles, src)
		current_ship = null
	return ..()

/obj/machinery/computer/helm/viewscreen
	name = "ship viewscreen"
	icon = 'icons/obj/wallmounts.dmi'
	icon_state = "telescreen"
	icon_keyboard = null
	icon_screen = null
	layer = SIGN_LAYER
	density = FALSE
	viewer = TRUE

/obj/machinery/computer/helm/attackby(obj/item/I, mob/living/user, params)
	// Handle ship authorization key
	if(istype(I, /obj/item/ship_key))
		attempt_claim_ship(I, user)
		return TRUE
	// Handle star chart uploads
	if(istype(I, /obj/item/disk/star_chart))
		var/obj/item/disk/star_chart/chart = I
		if(!current_ship && !attempt_ship_connection(last_resort = TRUE))
			to_chat(user, span_warning("This console is not connected to a ship!"))
			return TRUE
		chart.upload_to_ship(current_ship, user)
		return TRUE
	return ..()

/// Attempts to claim the ship using an authorization key
/obj/machinery/computer/helm/proc/attempt_claim_ship(obj/item/ship_key/key, mob/living/user)
	if(!current_ship && !attempt_ship_connection(last_resort = TRUE))
		to_chat(user, span_warning("This console is not connected to a ship!"))
		return FALSE

	// Check if key matches this ship
	var/obj/structure/overmap/ship/npc/npc_ship = key.get_ship()
	if(npc_ship != current_ship)
		to_chat(user, span_warning("This key is for a different vessel: [key.ship_name]"))
		return FALSE

	// Check if key is valid (has AI controller) OR ship is abandoned OR ship is disabled (all claimable)
	if(!key.is_valid() && !current_ship.abandoned && !npc_ship?.is_disabled)
		to_chat(user, span_warning("This authorization key is no longer valid."))
		return FALSE

	// Claim the ship!
	if(claim_npc_ship(npc_ship, user))
		to_chat(user, span_notice("Ship authorization accepted. You now have command of [npc_ship.name]."))
		playsound(src, 'sound/machines/terminal/terminal_on.ogg', 50, TRUE)
		// Send signal that key was used before destroying
		SEND_SIGNAL(key, COMSIG_SHIP_KEY_USED, npc_ship, user)
		// Mark destruction reason and consume the key
		key.mark_destruction_reason(KEY_DESTROYED_CLAIMED)
		qdel(key)
		return TRUE
	else
		to_chat(user, span_warning("Failed to claim ship. Try again."))
		return FALSE

/// Converts an NPC ship to player control
/obj/machinery/computer/helm/proc/claim_npc_ship(obj/structure/overmap/ship/npc/npc_ship, mob/living/claimer)
	if(!istype(npc_ship))
		return FALSE

	// Cancel abandonment timer if one is running
	if(npc_ship.abandonment_timer)
		npc_ship.cancel_abandonment_timer()

	// Reset abandoned state if ship was abandoned
	if(npc_ship.abandoned)
		npc_ship.abandoned = FALSE
		npc_ship.joining_allowed = TRUE

	// Remove the AI controller
	if(npc_ship.ai_controller)
		QDEL_NULL(npc_ship.ai_controller)

	// Remove the combat interface (no longer needed for AI)
	if(npc_ship.combat_interface)
		QDEL_NULL(npc_ship.combat_interface)

	// Clear NPC-specific state
	npc_ship.hostile = FALSE

	// Remove NPC color tint
	npc_ship.color = null
	npc_ship.chat_color = null

	// Convert ship areas to require power (NPC ships don't need power, player ships do)
	// Also convert any pirate turrets to be player-friendly
	if(npc_ship.shuttle?.shuttle_areas)
		for(var/area/shuttle_area as anything in npc_ship.shuttle.shuttle_areas)
			shuttle_area.requires_power = TRUE
			// Update all machinery in the area to respect power requirements
			shuttle_area.power_change()
			// Turn off pirate turrets - syndicate-based turrets can't be made safe
			// (their assess_perp always returns 10), but players can deconstruct
			// and rebuild them as standard turrets
			for(var/obj/machinery/porta_turret/syndicate/turret in shuttle_area)
				turret.toggle_on(FALSE)
			// Top up the SMES and APC cells. NPC hulls run on free power, so
			// whatever charge theirs were sitting at is meaningless - and the
			// requires_power flip above is the moment that stops being true.
			// Handing over drained buffers would leave the claimer with a dark ship.
			for(var/obj/machinery/power/smes/unit in shuttle_area)
				if(QDELETED(unit) || (unit.machine_stat & (BROKEN | EMPED)))
					continue
				unit.fill_charge()
			for(var/obj/machinery/power/apc/apc in shuttle_area)
				if(QDELETED(apc) || !apc.cell || (apc.machine_stat & (BROKEN | EMPED)))
					continue
				apc.set_full_charge()
				// set_full_charge() only writes the cell; without this the readout
				// sits on whatever charging state it was last left in until the
				// APC's own process ticks, which never re-evaluates a full cell.
				apc.charging = APC_FULLY_CHARGED
				apc.update_appearance()

	// Remove access requirements from all doors (player ships have open access)
	npc_ship.clear_door_access()

	// Reset ship movement state (NPC ships have different movement mechanics)
	npc_ship.speed = list(0, 0)
	npc_ship.speed_multiplier = 1
	npc_ship.is_interdicted = FALSE
	npc_ship.interdiction_strength = 0
	npc_ship.player_controlled = TRUE  // Use normal engine physics instead of NPC simplified movement

	// Announce the change of ownership
	npc_ship.ship_notify("NOTICE: Command authorization transferred. New commanding officer recognized.", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	// Add claimer to ship team if it exists, or create one
	// Note: Players can be members of multiple ship teams simultaneously
	if(claimer?.mind)
		if(!npc_ship.ship_team)
			// Create a ship team if one doesn't exist
			npc_ship.ship_team = new /datum/team/voidcrew()
			npc_ship.ship_team.name = npc_ship.name
			npc_ship.ship_team.ship = npc_ship
		npc_ship.ship_team.add_member(claimer.mind)

		// Set the claimer as captain (for NPC ships without job_slots)
		npc_ship.claimed_captain = claimer.mind

		// Grant the Captain Management action button
		grant_captain_management(claimer, npc_ship)

	// Log the claim
	log_game("[key_name(claimer)] claimed NPC ship [npc_ship.name] at [AREACOORD(npc_ship)]")

	return TRUE

/**
 * Faceplate art for the helm interface. Its bezels are drawn at the exact panel
 * GEOMETRY coordinates in HelmComputer.tsx, so the art has to be redrawn if that
 * layout moves, or the bezels will no longer line up with the wells.
 */
/datum/asset/simple/helm_faceplate
	assets = list(
		"helm_faceplate.png" = 'voidcrew/modules/shuttle/helm/helm_faceplate.png',
	)

/obj/machinery/computer/helm/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/helm_faceplate))

/obj/machinery/computer/helm/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!current_ship && !attempt_ship_connection(last_resort = TRUE))
		return FALSE

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "HelmComputer", name)
		ui.open()
		// The chart is drawn client-side from contact data, so the helm no longer
		// needs the ship's camera map instance. Autoupdate is the idle heartbeat;
		// while under way the ship pushes a frame per tile from tick_move().
		ui.set_autoupdate(TRUE)

/obj/machinery/computer/helm/ui_data(mob/user)
	// var/list/data = list()
	var/list/data = ..()

	data["integrity"] = current_ship.get_integrity_percent()
	data["overhealth"] = current_ship.get_overhealth_percent()

	// Read the latch rather than re-deriving the band from a percentage. The console and the
	// ship have to agree on when the hull is disabled, and a second copy of the comparison
	// drifts the moment the thresholds move - it also loses the hysteresis, so the console
	// would flicker between states on every tile repaired near the boundary.
	data["shipDisabled"] = current_ship.integrity_state == SHIP_INTEGRITY_DISABLED
	data["shipCrashed"] = current_ship.has_crash_landed && current_ship.integrity_state == SHIP_INTEGRITY_DISABLED

	// Repair progress as tile counts - shows exact mass repaired vs needed
	if(data["shipCrashed"])
		var/target_integrity = round(current_ship.integrity_recovery_threshold())
		data["repairCurrent"] = max(0, current_ship.integrity - current_ship.crashed_at_integrity)
		data["repairTotal"] = max(1, target_integrity - current_ship.crashed_at_integrity)
	else
		data["repairCurrent"] = 0
		data["repairTotal"] = 0

	data["calibrating"] = calibrating
	data["canThrust"] = current_ship.can_thrust()
	data["otherInfo"] = list()
	for (var/obj/structure/overmap/object as anything in current_ship.close_overmap_objects)
		var/other_integrity = object.integrity
		// For ships, use percentage-based integrity
		if(istype(object, /obj/structure/overmap/ship))
			var/obj/structure/overmap/ship/other_ship = object
			other_integrity = other_ship.get_integrity_percent()
		var/list/other_data = list(
			name = object.name,
			integrity = other_integrity,
			// What going down there costs, on the card the crew reads with a finger on the
			// Dock button. Null for everything with nothing to warn about.
			hazard = object.get_hazard_note(),
			ref = REF(object)
		)
		data["otherInfo"] += list(other_data)
	var/turf/T = get_turf(current_ship)
	// Convert absolute turf coordinates to relative overmap coordinates (1-based)
	data["x"] = T.x - OVERMAP_LEFT_SIDE_COORD + 1
	data["y"] = T.y - OVERMAP_SOUTH_SIDE_COORD + 1
	data["state"] = current_ship.state
	data["docked"] = isturf(current_ship.loc) ? FALSE : TRUE

	// Unified navigation readout: live distance/bearing from current position,
	// grouped by category on the helm. Trader outposts are permanent fixtures,
	// always listed (no per-ship state, no clear button). Most other entries are
	// charted waypoints, missions, bounties, active-scan contacts. Ship
	// contacts are appended live (not charted) when the top radar tier is
	// researched: they vanish the moment either ship leaves the bubble.
	data["sensorRange"] = current_ship.get_sensor_range()
	data["scanCooldown"] = !COOLDOWN_FINISHED(current_ship, sensor_scan_cooldown)
	data["scanCooldownRemaining"] = COOLDOWN_TIMELEFT(current_ship, sensor_scan_cooldown)
	// The contact set itself is cached on the ship and shared by every console on
	// it; distance and bearing are derived here so they stay live between rebuilds
	// even while the ship is moving a tile at a time.
	data["waypoints"] = list()
	for(var/list/contact as anything in current_ship.get_contact_snapshot())
		var/dx = contact["x"] - data["x"]
		var/dy = contact["y"] - data["y"]
		// Copy so the per-read distance never writes back into the shared cache.
		var/list/entry = contact.Copy()
		entry["dist"] = round(sqrt(dx * dx + dy * dy))
		entry["bearing"] = overmap_delta_to_compass(dx, dy)
		data["waypoints"] += list(entry)
	// Hails heard by this ship. Newest last, as the log stores them; `live` marks
	// the ones still young enough to pulse on the chart (see ship_transmissions.dm).
	data["transmissions"] = list()
	for(var/datum/overmap_transmission/transmission as anything in current_ship.comms_log)
		var/obj/structure/overmap/ship/sender = transmission.sender_ref?.resolve()
		data["transmissions"] += list(list(
			"message" = transmission.message,
			"sender" = transmission.sender_name || "unknown contact",
			"x" = transmission.coord_x,
			"y" = transmission.coord_y,
			"age" = transmission.age_seconds(),
			"live" = transmission.is_live(),
			"own" = sender == current_ship,
		))

	// Our own distress beacon. The state of everyone else's rides the contact
	// snapshot above; this is the switch on this console (see ship_distress.dm).
	data["distress"] = list(
		"active" = current_ship.distress_active,
		"message" = current_ship.distress_message,
		"cooldown" = !COOLDOWN_FINISHED(current_ship, distress_toggle_cooldown),
		"cooldownRemaining" = COOLDOWN_TIMELEFT(current_ship, distress_toggle_cooldown),
	)

	// Sealed rumors bought from traders, waiting on the reveal button
	data["pendingRumors"] = list()
	for(var/datum/rumor_chart/chart as anything in current_ship.pending_rumors)
		data["pendingRumors"] += list(list(
			"name" = chart.name,
			"desc" = chart.desc,
			"ref" = REF(chart),
		))
	var/drift_direction = current_ship.get_heading()
	data["heading"] = dir2text(drift_direction) || "None"
	// Where the ship is actually going, as a dir, as opposed to where the engines
	// are pushing. tick_move() steps by the SIGN of each velocity axis and nothing
	// out here slows a hull down, so this is the direction the ship keeps crossing
	// tiles in with the engines cold. The chart projects its drift track along it.
	data["driftDirection"] = drift_direction
	data["speed"] = current_ship.get_speed()
	data["eta"] = current_ship.get_eta()
	// Exactly the interval tick_move() is scheduled on, in milliseconds. The chart
	// glides its token over this long, so each move lands as the next one starts
	// and a tile-by-tile jump reads as continuous flight.
	data["moveIntervalMs"] = round(current_ship.get_move_interval() * 100)
	data["est_thrust"] = current_ship.est_thrust
	data["burnDirection"] = current_ship.burn_direction
	data["burnPercentage"] = current_ship.burn_percentage
	// The course being held, as distinct from the burn: the compass rose lights
	// from this, and it stays lit while the ship cruises with the engines cold.
	data["commandedCourse"] = current_ship.commanded_course
	// The throttle's cruise ceiling and the dock assist's own, converted to
	// tiles/min for the readout (speeds are stored in tiles per decisecond).
	data["cruiseTargetSpeed"] = round(current_ship.max_speed * 600 * current_ship.burn_percentage / 100, 0.1)
	data["dockAssistMaxSpeed"] = round(current_ship.max_speed * 600 * DOCK_ASSIST_SPEED_FRACTION, 0.1)
	data["engineInfo"] = list()
	data["canLand"] = current_ship.shuttle.port_destinations ? TRUE : FALSE
	data["autopilot"] = current_ship.get_autopilot_data()

	// What the Dock button offers from this tile. It used to only ever dock into
	// empty space and refused outright when anything shared the tile, then only
	// ever offered the first real candidate found, this lists every one, so a
	// tile with more than one dockable thing on it lets the crew choose.
	var/list/dock_candidates = get_dock_candidates()
	var/list/dock_options = list()
	if(length(dock_candidates))
		for(var/obj/structure/overmap/candidate as anything in dock_candidates)
			dock_options += list(list(
				"name" = describe_dock_candidate(candidate),
				"ref" = REF(candidate),
				"isEmpty" = FALSE,
			))
	else
		// Nebulas aren't a docking target. Concealment is the Cloak control's job,
		// but sitting in one and being told only "empty space" reads as the console
		// having missed it, so the label says where the empty space is.
		var/dock_name = (locate(/obj/structure/overmap/event/nebula) in T) \
			? "empty space (inside nebula)" \
			: "empty space"
		dock_options += list(list(
			"name" = dock_name,
			"ref" = null,
			"isEmpty" = TRUE,
		))
	data["dockOptions"] = dock_options

	// Undock cooldown data (after docking)
	data["undockCooldown"] = !COOLDOWN_FINISHED(current_ship, undock_cooldown)
	data["undockCooldownRemaining"] = COOLDOWN_TIMELEFT(current_ship, undock_cooldown)

	// Interdiction undock lockout data
	data["undockLocked"] = !COOLDOWN_FINISHED(current_ship, interdiction_undock_lockout)
	data["undockLockoutRemaining"] = COOLDOWN_TIMELEFT(current_ship, interdiction_undock_lockout)

	// Post-failure hull lockout. Outlives the damage that caused it, so the console has to
	// name it - otherwise a fully repaired ship reads 100% next to a dead Undock button.
	data["integrityLockout"] = !COOLDOWN_FINISHED(current_ship, integrity_undock_lockout)
	data["integrityLockoutRemaining"] = COOLDOWN_TIMELEFT(current_ship, integrity_undock_lockout)

	// Dock warmup data
	data["dockWarmup"] = !!current_ship.dock_warmup_timer
	data["dockWarmupRemaining"] = current_ship.dock_warmup_timer ? timeleft(current_ship.dock_warmup_timer) : 0

	// Undock warmup data
	data["undockWarmup"] = !!current_ship.undock_warmup_timer
	data["undockWarmupRemaining"] = current_ship.undock_warmup_timer ? timeleft(current_ship.undock_warmup_timer) : 0

	// Cargo shuttle status - block undock if shuttle is present
	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = current_ship.get_cargo_shuttle()
	cargo_shuttle?.check_stalled() // a delivery that never resolved would block undock forever
	data["cargoShuttlePresent"] = cargo_shuttle && cargo_shuttle.state != CARGO_SHUTTLE_AWAY

	// Interdiction status
	data["isInterdicted"] = current_ship.is_interdicted
	data["interdictionStrength"] = current_ship.interdiction_strength
	data["speedMultiplier"] = current_ship.speed_multiplier

	// Nebula concealment status
	data["hiddenInNebula"] = current_ship.hidden_in_nebula
	data["nebulaHideWarmup"] = !!current_ship.nebula_hide_timer
	data["nebulaHideRemaining"] = current_ship.nebula_hide_timer ? timeleft(current_ship.nebula_hide_timer) : 0
	// Check if we're on a nebula tile (can hide)
	var/on_nebula = FALSE
	for(var/obj/structure/overmap/event/nebula/N in T)
		on_nebula = TRUE
		break
	data["onNebula"] = on_nebula

	// Zone information
	if(SSovermap_zones.zones_active)
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone(T)
		if(zone)
			data["zone_type"] = zone.zone_type
			data["zone_name"] = zone.name
			data["zone_color"] = zone.get_color()
			data["zone_description"] = zone.get_description()
			data["weapons_allowed"] = zone.weapons_allowed()
			data["interdiction_allowed"] = zone.interdiction_allowed()
		else
			data["zone_type"] = null
			data["zone_name"] = "Unknown"
			data["zone_color"] = "#ffffff"
			data["zone_description"] = "Zone data unavailable."
			data["weapons_allowed"] = TRUE
			data["interdiction_allowed"] = TRUE
		// Zone transition info (when crossing between zones)
		data["zone_transitioning"] = current_ship.zone_transitioning
		if(current_ship.zone_transitioning && current_ship.zone_transition_start_time)
			var/elapsed = world.time - current_ship.zone_transition_start_time
			var/progress = clamp((elapsed / ZONE_TRANSITION_TIME) * 100, 0, 100)
			var/remaining = max(0, ZONE_TRANSITION_TIME - elapsed) / 10
			data["zone_transition_progress"] = round(progress)
			data["zone_transition_remaining"] = round(remaining, 0.1)
			// Get target zone name
			if(current_ship.zone_transition_target)
				var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(current_ship.zone_transition_target)
				data["zone_transition_target"] = target_zone?.name || "Unknown Zone"
			else
				data["zone_transition_target"] = "Unknown Zone"
		else
			data["zone_transition_progress"] = 0
			data["zone_transition_remaining"] = 0
			data["zone_transition_target"] = null
	else
		data["zone_type"] = null
		data["zone_name"] = "Inactive"
		data["zone_color"] = "#888888"
		data["zone_description"] = "Zone system inactive."
		data["weapons_allowed"] = TRUE
		data["interdiction_allowed"] = TRUE
		data["zone_shift_seconds"] = 0
		data["zone_shift_minutes"] = 0
		data["zone_shift_remaining_seconds"] = 0
		data["zone_transitioning"] = FALSE
		data["zone_transition_progress"] = 0
		data["zone_transition_remaining"] = 0
		data["zone_transition_target"] = null

	// Standing version of the crossing warning: the band we're in (or headed
	// into) versus what this hull has researched to meet it. Null while there is
	// nothing to say. See voidcrew/modules/onboarding/zone_advisory.dm
	data["zone_advisory"] = current_ship.zone_advisory_state()

	for(var/obj/machinery/power/shuttle_engine/ship/E in current_ship.shuttle.engine_list)
		if(QDELETED(E))
			continue
		var/list/engine_data
		if(!E.thruster_active)
			engine_data = list(
				name = E.name,
				fuel = 0,
				maxFuel = 100,
				enabled = E.enabled,
				ref = REF(E)
			)
		else
			engine_data = list(
				name = E.name,
				fuel = E.return_fuel() || 0,
				maxFuel = E.return_fuel_cap() || 100,
				enabled = E.enabled,
				ref = REF(E)
			)
		data["engineInfo"] += list(engine_data)

	return data

/obj/machinery/computer/helm/ui_static_data(mob/user)
	var/list/data = list()

	data["isViewer"] = viewer
	data["shipInfo"] = list(
		name = current_ship.display_name,
		class = current_ship.source_template?.name,
		mass = current_ship.mass,
	)
	data["canFly"] = TRUE

	// Chart geometry. Zones are concentric bands around the sun and never rotate,
	// so the client can draw the whole ring system from these four numbers instead
	// of us shipping per-tile colour data.
	data["chart"] = list(
		"size" = OVERMAP_SIZE,
		// Must match SSovermap_zones' own centre, not the grid's true geometric
		// middle: overmap_centre (and the sun placed on it) sits at index
		// (OVERMAP_SIZE - 1) / 2, one tile off from round((SIZE + 1) / 2), because
		// setup_overmap() computes it that way ("not actually the centre but close
		// enough", see overmap.dm). calculate_zone_for_turf() measures every
		// zone boundary from that same off-centre point, so the rings drawn here
		// have to be centred on it too, or the yellow/red boundaries on the chart
		// read as smaller than where a ship actually crosses into them.
		"centre" = (OVERMAP_SIZE - 1) / 2,
		"ringInner" = ZONE_INNER_RING_RATIO,
		"ringMiddle" = ZONE_MIDDLE_RING_RATIO,
		// The free sight radius, drawn as the solid inner ring. Fixed forever.
		// Research moves the sensor ring, never this one (see ship_sensors.dm).
		"viewRange" = SHIP_VIEW_RANGE,
	)

	// Check if user is a crew member of this ship
	// Everything the ship has ever seen. Static because it only changes on a new
	// discovery, which pushes a refresh (see get_charted_contacts), it is much
	// the largest table the helm sends, and re-sending it every frame was the
	// whole cost of charting the map as you go.
	data["chartedContacts"] = current_ship.get_charted_contacts()

	data["isNotCrew"] = !is_crew_member(user)

	// Abandoned ship status
	data["isAbandoned"] = current_ship?.abandoned

	return data

/**
 * What the Dock button would call `object` if offered as an option, or null if it
 * isn't dockable at all. Ships get their own wording (see describe_dock_target()
 * in ship_sensors.dm) since docking with one is still a request/accept handshake
 * rather than an instant dock; everything else opts in by overriding
 * get_dock_description() (see _overmap.dm).
 */
/obj/machinery/computer/helm/proc/describe_dock_candidate(obj/structure/overmap/object)
	if(istype(object, /obj/structure/overmap/ship))
		var/obj/structure/overmap/ship/other = object
		return current_ship?.describe_dock_target(other)
	return object.get_dock_description()

/**
 * Every object the Dock button could act on from the ship's current tile, or an
 * empty list when there is nothing here and docking means holding station in
 * empty space. Order is whatever close_overmap_objects happens to hold, the
 * console doesn't rank docking options, it just lists them.
 */
/obj/machinery/computer/helm/proc/get_dock_candidates()
	. = list()
	if(!current_ship)
		return .
	for(var/obj/structure/overmap/object as anything in current_ship.close_overmap_objects)
		if(isnull(describe_dock_candidate(object)))
			continue
		. += object

/**
 * Names an autopilot destination from the ship's own contact set, so the label the
 * crew sees in chat is one the server already knows about. The client never gets to
 * supply this text, it ends up inside ship_notify() output, and a client-supplied
 * string there is an injection waiting to happen.
 */
/obj/machinery/computer/helm/proc/describe_autopilot_destination(rel_x, rel_y)
	for(var/list/contact as anything in current_ship.get_contact_snapshot())
		if(contact["x"] == rel_x && contact["y"] == rel_y)
			return contact["name"]
	return "([rel_x], [rel_y])"

/**
 * Checks if the given user is a member of this ship's crew
 */
/obj/machinery/computer/helm/proc/is_crew_member(mob/user)
	if(!ismob(user))
		return FALSE
	// Allow admin ghosts with AI interaction enabled
	if(isAdminGhostAI(user))
		return TRUE
	var/mob/living/living_user = user
	if(!istype(living_user) || !living_user.mind)
		return FALSE
	if(!current_ship?.ship_team)
		return TRUE // No ship team set up, allow access
	if(current_ship.abandoned)
		return TRUE // Abandoned ships allow anyone to access for claiming
	return (living_user.mind in current_ship.ship_team.members)

/**
 * The distress-beacon switch.
 *
 * Lighting one opens a text prompt prefilled with a plain mayday, which the crew
 * can rewrite to say anything at all before it goes out - nothing verifies it,
 * and that is the whole design (see ship_distress.dm). Shutting one down takes no
 * prompt at all: getting off the air has to be one press.
 *
 * No rank check anywhere. Anyone who can work this console can raise or drop the
 * beacon, because the situations it exists for are the ones where the officers
 * are already dead.
 */
/obj/machinery/computer/helm/proc/toggle_distress_beacon(mob/user)
	if(!current_ship)
		return
	if(!COOLDOWN_FINISHED(current_ship, distress_toggle_cooldown))
		// Balloon rather than say(): the refusal belongs to whoever pressed the
		// button, not to the whole bridge.
		balloon_alert(user, "beacon interlock cycling")
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
		return
	if(current_ship.distress_active)
		current_ship.deactivate_distress_beacon(user)
		playsound(src, 'sound/machines/terminal/terminal_off.ogg', 40)
		current_ship.push_helm_frame()
		return

	var/message = tgui_input_text(
		user,
		"This repeats on Wideband and puts your position on every helm in the galaxy until you switch it off. Nothing checks what it says.",
		"Distress Beacon",
		current_ship.default_distress_message(),
		DISTRESS_MESSAGE_MAX_LEN,
	)
	if(isnull(message))
		return
	// The prompt sleeps, so nothing that was true when it opened is still
	// guaranteed: the console can be gone, the ship can be gone, the roster can
	// have changed, and somebody at another helm can have lit the beacon first.
	if(QDELETED(src) || !current_ship || !is_crew_member(user))
		return
	if(current_ship.distress_active || !COOLDOWN_FINISHED(current_ship, distress_toggle_cooldown))
		return
	if(!current_ship.activate_distress_beacon(message, user))
		say("ERROR: Distress beacon refused the transmission.")
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
		return
	playsound(src, 'sound/machines/terminal/terminal_alert.ogg', 50)
	current_ship.push_helm_frame()

/obj/machinery/computer/helm/LateInitialize()
	. = ..()
	attempt_ship_connection()

/obj/machinery/computer/helm/proc/calibrate_jump(inline = FALSE)
	if(jump_allowed < 0)
		say("Bluespace Jump Calibration offline. Please contact your system administrator.")
		return
	if(current_ship.state != OVERMAP_SHIP_FLYING)
		say("Bluespace Jump Calibration detected interference in the local area.")
		return
	if(world.time < jump_allowed)
		var/jump_wait = DisplayTimeText(jump_allowed - world.time)
		say("Bluespace Jump Calibration is currently recharging. ETA: [jump_wait].")
		return
	if(jump_state != JUMP_STATE_OFF && !inline)
		// Guards against href exploits calling this more than once per client. It used
		// to return in total silence, which meant any jump that failed mid-sequence
		// bricked the console for the rest of the round with no way to tell.
		say("Bluespace Jump sequence already underway.")
		return
	message_admins("[ADMIN_LOOKUPFLW(usr)] has initiated a bluespace jump in [ADMIN_VERBOSEJMP(src)]")
	jump_timer = addtimer(CALLBACK(src, PROC_REF(jump_sequence), TRUE), JUMP_CHARGEUP_TIME, TIMER_STOPPABLE)
	current_ship?.ship_notify("Bluespace jump calibration initialized. Calibration completion in [JUMP_CHARGEUP_TIME/600] minutes.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	calibrating = TRUE
	return TRUE

/**
 * Aborts a jump, whether it is still calibrating or already running the launch
 * sequence, and puts the console back to a state that can jump again.
 *
 * jump_state has to be reset here: leaving it non-OFF makes calibrate_jump()
 * refuse every future attempt. deltimer() has to cover the sequence timers too -
 * jump_timer only ever held the initial calibration timer, so a cancel after
 * calibration finished left the chain running and unstoppable.
 */
/obj/machinery/computer/helm/proc/cancel_jump()
	current_ship?.ship_notify("Pylon Disengaged. Jump cancelled.", "BLUESPACE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
	reset_jump()

/// Clears all jump state and any pending sequence timer.
/obj/machinery/computer/helm/proc/reset_jump()
	calibrating = FALSE
	jump_state = JUMP_STATE_OFF
	if(jump_timer)
		deltimer(jump_timer)
		jump_timer = null

/obj/machinery/computer/helm/proc/jump_sequence()
	switch(jump_state)
		if(JUMP_STATE_OFF)
			jump_state = JUMP_STATE_CHARGING
			SStgui.close_uis(src)
		if(JUMP_STATE_CHARGING)
			jump_state = JUMP_STATE_IONIZING
			current_ship?.ship_notify("Bluespace Jump Calibration completed. Ionizing Bluespace Pylon.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		if(JUMP_STATE_IONIZING)
			jump_state = JUMP_STATE_FIRING
			current_ship?.ship_notify("Bluespace Ionization finalized; preparing to fire Bluespace Pylon.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		if(JUMP_STATE_FIRING)
			jump_state = JUMP_STATE_FINALIZED
			current_ship?.ship_notify("Bluespace Pylon launched.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'sound/effects/magic/lightning_chargeup.ogg', 50)
			jump_timer = addtimer(CALLBACK(src, PROC_REF(do_jump)), 10 SECONDS, TIMER_STOPPABLE)
			return
	jump_timer = addtimer(CALLBACK(src, PROC_REF(jump_sequence), TRUE), JUMP_CHARGE_DELAY, TIMER_STOPPABLE)

/obj/machinery/computer/helm/proc/do_jump()
	jump_timer = null
	current_ship?.ship_notify("Bluespace Jump Initiated.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	if(!current_ship)
		reset_jump()
		return
	// Extract ship parts from all players on the ship before jumping
	extract_ship_parts_from_ship(current_ship, "bluespace_jump")
	// ignore_crew: the jump is supposed to take the crew with it, and the console
	// asked for confirmation before any of this started.
	if(current_ship.destroy_ship(TRUE, ignore_crew = TRUE))
		return
	// Never strand the console in a state it cannot leave - a failed jump has to be
	// retryable, and the crew has to hear that it failed.
	current_ship.ship_notify("Bluespace Pylon misfire. Jump aborted; recalibration required.", "BLUESPACE", SHIP_NOTIFY_DANGER, 'voidcrew/sound/notify.ogg', 50)
	stack_trace("Bluespace jump failed to destroy ship [current_ship] - the console has been reset.")
	reset_jump()

/obj/machinery/computer/helm/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	if(!istype(port))
		return
	set_current_ship(port.current_ship)

/**
 * This proc manually rechecks that the helm computer is connected to a proper ship
 */
/obj/machinery/computer/helm/proc/attempt_ship_connection(last_resort = FALSE)
	if(current_ship && current_ship.shuttle.z == z)
		// Already connected, but ensure signal is registered
		RegisterSignal(current_ship, COMSIG_SHIP_INTEGRITY_CHANGED, PROC_REF(on_ship_integrity_changed), override = TRUE)
		return TRUE

	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(!ship && last_resort)
		stack_trace("Failed to connect a helm to its ship, this is almost certainly a bug!")

	set_current_ship(ship)
	return !!current_ship

/**
 * Sets the current ship and registers signal listeners
 */
/obj/machinery/computer/helm/proc/set_current_ship(obj/structure/overmap/ship/new_ship)
	// Unregister from old ship
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_SHIP_INTEGRITY_CHANGED)
		LAZYREMOVE(current_ship.helm_consoles, src)

	current_ship = new_ship

	// Register to new ship for auto UI updates
	if(current_ship)
		RegisterSignal(current_ship, COMSIG_SHIP_INTEGRITY_CHANGED, PROC_REF(on_ship_integrity_changed))
		// The ship pushes a UI frame to every linked console as it crosses a tile,
		// so the chart's glide stays in step with the move loop
		// (adjust_speed() -> tick_move() -> push_helm_frame()).
		LAZYOR(current_ship.helm_consoles, src)

/**
 * Signal handler - refreshes UI when ship integrity changes
 */
/obj/machinery/computer/helm/proc/on_ship_integrity_changed(datum/source, new_integrity, max_integrity, display_percent)
	SIGNAL_HANDLER
	SStgui.update_uis(src)

	// Play alert sound when crossing 55% threshold (going down)
	if(last_integrity_percent > 55 && display_percent <= 55 && !played_55_alert)
		played_55_alert = TRUE
		playsound(src, 'sound/effects/alert.ogg', 75, FALSE)

	// Reset the alert flag if we repair above 55%
	if(display_percent > 55)
		played_55_alert = FALSE

	last_integrity_percent = display_percent

/**
 * Rolls to see whether a drunk pilot fumbles a manual course change.
 *
 * Only ever called from a manual course input on this console, the direction pad and the
 * keyboard flight keys. Autopilot, braking, docking and undocking never route through here,
 * so however far gone the pilot is they can always still stop the ship.
 * * user - The mob that asked for the course.
 * * requested_dir - The direction they asked for.
 * Returns the direction the ship should actually burn in.
 */
/obj/machinery/computer/helm/proc/drunken_heading(mob/user, requested_dir)
	if(!requested_dir || !isliving(user))
		return requested_dir
	var/mob/living/pilot = user
	var/drunkenness = pilot.get_drunk_amount()
	if(drunkenness <= HELM_DRUNK_THRESHOLD)
		return requested_dir
	var/fumble_chance = min((drunkenness - HELM_DRUNK_THRESHOLD) * HELM_DRUNK_CHANCE_PER_POINT, HELM_DRUNK_MAX_CHANCE)
	if(!prob(fumble_chance))
		return requested_dir
	var/list/wrong_directions = GLOB.alldirs - requested_dir
	if(!length(wrong_directions))
		return requested_dir
	var/static/list/fumble_messages = list(
		"Your vision swims and you yank the controls the wrong way",
		"You lean on the console harder than you meant to and the ship lurches off course",
		"You misjudge the distance to the controls and slap in the wrong heading",
	)
	to_chat(user, span_warning("[pick(fumble_messages)]..."))
	balloon_alert(user, "wrong way!")
	playsound(src, 'sound/machines/terminal/terminal_error.ogg', 20)
	return pick(wrong_directions)

/**
 * This proc manually rechecks that the helm computer is connected to a proper ship
 */
/obj/machinery/computer/helm/proc/reload_ship()
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(ship)
		current_ship = ship
	return TRUE

/obj/machinery/computer/helm/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(viewer)
		return
	// Server-side crew check as safety net
	if(!is_crew_member(usr))
		say("ERROR: Access denied. Crew authorization required.")
		return
	switch(action) // Universal topics
		if("rename_ship")
			var/new_name = params["newName"]
			if(!new_name)
				return
			new_name = reject_bad_text(trim(new_name), MAX_NAME_LEN)
			if(!new_name)
				say("Error: Replacement designation rejected by system.")
				return
			if(!current_ship.can_rename_ship(usr))
				say("Error: Registry changes require the commanding officer's authorization.")
				return
			current_ship.set_ship_name(new_name, usr)
			update_static_data(usr, ui)
			return
			/*
		if("toggle_kos")
			current_ship.set_ship_faction("KOS")
			update_static_data(usr, ui)
			return
		if("return")
			current_ship.set_ship_faction("return")
			update_static_data(usr, ui)
			return
			*/
		if("remove_waypoint")
			var/datum/ship_waypoint/waypoint = locate(params["waypoint"]) in current_ship.waypoints
			if(waypoint)
				current_ship.delete_waypoint(waypoint)
			return
		if("autopilot_pref")
			// Flight policy is editable whether or not a course is being flown,
			// which is why this sits with the universal topics. The key is
			// whitelisted server-side in set_autopilot_pref(); an unknown one
			// is dropped there without touching anything.
			current_ship.set_autopilot_pref(params["key"], params["value"])
			return
		if("reveal_rumor")
			var/datum/rumor_chart/chart = locate(params["chart"]) in current_ship.pending_rumors
			if(!chart)
				return
			var/obj/structure/overmap/space_ruin/ruin = current_ship.reveal_pending_rumor(chart)
			if(!ruin)
				say("ERROR: Unable to pin down the rumor's coordinates. Retry shortly.")
				playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
				return
			var/list/coords = ruin.get_relative_overmap_coords()
			say("Rumor decrypted: rare signal located at ([coords[1]], [coords[2]]). Charted under Rumors.")
			playsound(src, 'sound/machines/ping.ogg', 40)
			return
		if("reload_ship")
			reload_ship()
			current_ship.calculate_mass() // Refresh health based on current turfs
			update_static_data(usr, ui)
			return
		if("reload_engines")
			current_ship.refresh_engines()
			// The refresh itself is silent, and an unregistered thruster is invisible
			// on this console - read back what was found and why anything was refused,
			// so a missing engine is a diagnosis instead of a fifteen-minute mystery.
			var/list/engine_report = current_ship.engine_diagnostic_report()
			var/registered = 0
			for(var/obj/machinery/power/shuttle_engine/ship/E in current_ship.shuttle?.engine_list)
				if(!QDELETED(E))
					registered++
			if(registered)
				say("Engine refresh complete. [registered] thruster\s registered.")
			else
				say("Engine refresh complete. No thrusters registered to this hull.")
			for(var/line in engine_report)
				say("[line]")
			return
		if("typing_sound")
			// The comms field asks for this on every keypress, so the console decides
			// how often it actually makes a noise.
			if(!COOLDOWN_FINISHED(src, typing_sound_cooldown))
				return
			COOLDOWN_START(src, typing_sound_cooldown, TYPING_SOUND_COOLDOWN)
			playsound(src, pick('sound/machines/terminal/terminal_button01.ogg', 'sound/machines/terminal/terminal_button02.ogg', 'sound/machines/terminal/terminal_button03.ogg', 'sound/machines/terminal/terminal_button04.ogg', 'sound/machines/terminal/terminal_button05.ogg', 'sound/machines/terminal/terminal_button06.ogg', 'sound/machines/terminal/terminal_button07.ogg', 'sound/machines/terminal/terminal_button08.ogg'), 10, TRUE)
			return
		if("broadcast")
			if(!COOLDOWN_FINISHED(src, hail_send_cooldown))
				// Balloon rather than say(): the refusal is for whoever pressed the
				// button, and say() would let a held key talk over the whole bridge.
				balloon_alert(usr, "transmitter still cycling")
				return
			// A hail is filed on every receiving ship and read back by each of their
			// helms, so it gets the same handling the communications console gives an
			// outgoing message: encoded, trimmed and capped.
			var/message = trim(html_encode(params["message"]), MAX_BROADCAST_LEN)
			if(!length(message))
				return
			COOLDOWN_START(src, hail_send_cooldown, HAIL_SEND_COOLDOWN)
			log_game("[key_name(usr)] hailed from [current_ship.name] at [AREACOORD(src)]: \"[message]\"")
			current_ship.ship_broadcast_runechat(message)
			return
		if("distress")
			// Deliberately a universal topic: the hull-critical lockout below turns
			// off every other control on this console, and a hull that far gone is
			// precisely the one that needs to call for help.
			toggle_distress_beacon(usr)
			return
		if("claim_abandoned")
			if(!current_ship?.abandoned)
				say("ERROR: This ship is not abandoned.")
				return
			var/mob/living/living_user = usr
			if(!istype(living_user))
				return
			if(current_ship.claim_abandoned_ship(living_user))
				playsound(src, 'sound/machines/terminal/terminal_on.ogg', 50, TRUE)
				update_static_data(usr, ui)
			else
				say("ERROR: Failed to claim ship.")
			return

	// Prevent operation if ship is destroyed (at or below 50% integrity)
	if(current_ship.get_integrity_percent() <= 50)
		say("ERROR: Hull integrity critical. All systems offline.")
		return

	switch(current_ship.state) // Ship state-limited topics
		if(OVERMAP_SHIP_FLYING)
			switch(action)
				if("active_scan")
					var/category = params["category"]
					// active_scan() treats an unrecognised category as "no filter" and
					// sweeps everything for one cooldown, so only the categories the
					// console actually offers get through.
					if(!(category in GLOB.overmap_scan_categories))
						return
					var/found = current_ship.active_scan(category)
					var/label = lowertext(category) || "object"
					// Vessels are identified where they float rather than charted, and
					// only as far as the crew can see. Say what actually happened.
					var/vessels = category == "Ships"
					var/outcome = vessels ? "identified" : "charted"
					var/reach = vessels ? "visual range" : "sensor range"
					if(found < 0)
						say("Sensors recharging. ETA: [DisplayTimeText(COOLDOWN_TIMELEFT(current_ship, sensor_scan_cooldown))].")
						playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
					else if(found > 0)
						say("Active scan complete: [found] [label] contact[found > 1 ? "s" : ""] [outcome].")
						playsound(src, 'sound/machines/ping.ogg', 40)
					else
						say("Active scan complete: no new [label] contacts in [reach].")
						playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
					return
				if("act_overmap")
					var/obj/structure/overmap/to_act = locate(params["ship_to_act"])
					// overmap_object_act() only checks that we're stopped, not that the
					// target is reachable, and the chart now hands the client a ref for
					// every contact it can see. close_overmap_objects is strictly
					// same-tile (see /obj/structure/overmap/on_entered), so it is the
					// honest reachability test.
					if(!to_act || !(to_act in current_ship.close_overmap_objects))
						say("ERROR: No such contact at this position.")
						playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
						return
					say(current_ship.overmap_object_act(usr, to_act))
					return
				if("toggle_engine")
					var/obj/machinery/power/shuttle_engine/ship/E = locate(params["engine"])
					// locate() reaches any engine in the world off a ref, and the ref
					// came from the client. Only engines this console's own ship lists
					// are ours to switch.
					if(!istype(E) || !(E in current_ship.shuttle?.engine_list))
						return
					E.enabled = !E.enabled
					current_ship.refresh_engines()
					return
				if("change_heading")
					var/new_direction = text2num(params["dir"])
					// Touching the helm takes the ship off autopilot. Quietly, the
					// crew just did it on purpose and doesn't need to be told.
					current_ship.disengage_autopilot("manual heading", notify = FALSE)
					// A drunk pilot has a chance to send the ship somewhere else entirely
					new_direction = drunken_heading(usr, new_direction)
					// Toggle off if clicking the course already held, back to a coast
					if(new_direction == current_ship.commanded_course)
						current_ship.command_course(BURN_NONE)
					else
						current_ship.command_course(new_direction)
					return
				if("set_course")
					// Keyboard flight: non-toggling, so a held key holds the course
					// instead of strobing it on and off. The dir comes off the wire,
					// only real courses (or 0 to coast) get through.
					var/new_direction = text2num(params["dir"])
					if(isnull(new_direction) || !(new_direction in list(0, NORTH, SOUTH, EAST, WEST, NORTH|EAST, NORTH|WEST, SOUTH|EAST, SOUTH|WEST)))
						return
					current_ship.disengage_autopilot("manual heading", notify = FALSE)
					// Same fumble roll the buttons get. A press to coast (0) is left
					// alone; taking the engines off is not a course to get wrong.
					new_direction = drunken_heading(usr, new_direction)
					current_ship.command_course(new_direction)
					return
				if("autopilot")
					// Travel & dock: a contact row can ask for the course to end in a
					// docking approach. The ref comes off the wire, so it only counts
					// when it resolves to a dockable non-ship overmap object (ships
					// keep their consensual request/accept handshake), anything else
					// degrades to a plain course to the clicked tile.
					var/obj/structure/overmap/dock_target
					if(params["dock"])
						var/obj/structure/overmap/located = locate(params["target"])
						if(istype(located) && !istype(located, /obj/structure/overmap/ship) && !isnull(located.get_dock_description()))
							dock_target = located
					var/result
					if(dock_target)
						// Plot to the target's LIVE position. Its .x/.y are already
						// the absolute turf coordinates engage_autopilot() takes. The
						// label is the console's own naming, never client text (see
						// describe_autopilot_destination above for why).
						result = current_ship.engage_autopilot(dock_target.x, dock_target.y, describe_dock_candidate(dock_target), usr, dock_target)
					else
						// Chart coordinates arrive relative; the ship works in absolute
						// turf coordinates.
						var/dest_x = text2num(params["x"])
						var/dest_y = text2num(params["y"])
						if(isnull(dest_x) || isnull(dest_y))
							return
						dest_x = round(dest_x)
						dest_y = round(dest_y)
						var/label = describe_autopilot_destination(dest_x, dest_y)
						result = current_ship.engage_autopilot(
							dest_x + OVERMAP_LEFT_SIDE_COORD - 1,
							dest_y + OVERMAP_SOUTH_SIDE_COORD - 1,
							label,
							usr,
						)
					say(result)
					playsound(src, findtext(result, "ERROR") ? 'sound/machines/terminal/terminal_error.ogg' : 'sound/machines/ping.ogg', 40)
					return
				if("autopilot_cancel")
					if(!current_ship.autopilot_engaged)
						return
					current_ship.disengage_autopilot("stood down at the helm")
					return
				if("change_burn_percentage")
					var/new_percentage = clamp(text2num(params["percentage"]), 1, 100)
					current_ship.burn_percentage = new_percentage
					// The throttle doubles as the cruise target, so a held course is
					// re-commanded against the new number: cutting it trims speed off
					// on the spot (free, like braking), raising it starts the top-up.
					if(current_ship.commanded_course != BURN_NONE && current_ship.state == OVERMAP_SHIP_FLYING && !current_ship.zone_transitioning)
						current_ship.command_course(current_ship.commanded_course)
					return
				if("stop")
					current_ship.disengage_autopilot("manual override", notify = FALSE)
					// Cancel zone transition if in progress
					if(current_ship.zone_transitioning)
						current_ship.cancel_zone_transition()
						return
					// Brake always brakes: burning, cruising or coasting, the first
					// press is BURN_STOP. Only a second press while already braking
					// releases back to a coast.
					if(current_ship.burn_direction == BURN_STOP)
						current_ship.command_course(BURN_NONE)
					else
						current_ship.command_course(BURN_STOP)
					return
				if("bluespace_jump")
					if(calibrating)
						cancel_jump()
						return
					else
						if(tgui_alert(usr, "Do you want to bluespace jump? Your ship and everything on it will be removed from the round.", "Jump Confirmation", list("Yes", "No")) != "Yes")
							return
						calibrate_jump()
						return
				if("dock")
					// Dock into whatever is actually here. Previously this refused
					// outright whenever a ruin or planet shared the tile, so the only
					// way to land on one was the contact list's Interact button.
					//
					// Auto-stop assist: a slow approach is close enough, the console
					// finishes the stop itself rather than bouncing the crew to the
					// brake button. Above the assist ceiling the refusal stands, or
					// Dock would double as a crash-stop from full cruise. Runs before
					// the candidate/empty-space split because it is the only stillness
					// gate either path has - dock_in_empty_space() never had its own.
					if(!current_ship.is_still())
						if(MAGNITUDE(current_ship.speed[1], current_ship.speed[2]) > current_ship.max_speed * DOCK_ASSIST_SPEED_FRACTION)
							say("ERROR: Too fast for a docking approach. Slow below [round(current_ship.max_speed * 600 * DOCK_ASSIST_SPEED_FRACTION)] tiles/min.")
							playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
							return
						current_ship.full_stop()
					var/list/dock_candidates = get_dock_candidates()
					var/obj/structure/overmap/dock_candidate
					if(length(dock_candidates))
						// The client always sends the option it clicked once there is
						// more than one, but re-validate against close_overmap_objects
						// rather than trusting the ref on its own, same reason
						// "act_overmap" above does.
						var/target_ref = params["target"]
						if(target_ref)
							var/obj/structure/overmap/located = locate(target_ref)
							if(!located || !(located in dock_candidates))
								say("ERROR: No such contact at this position.")
								playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
								return
							dock_candidate = located
						else if(length(dock_candidates) == 1)
							dock_candidate = dock_candidates[1]
						else
							say("ERROR: Multiple docking options here. Choose one from the Dock button.")
							playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
							return
						current_ship.disengage_autopilot("docking", notify = FALSE)
						current_ship.overmap_object_act(usr, dock_candidate)
						return
					current_ship.disengage_autopilot("docking", notify = FALSE)
					// Only refusals come back as text; a dock that started is
					// broadcast to the crew by the ship itself
					var/dock_result = current_ship.dock_in_empty_space(usr)
					if(dock_result)
						say(dock_result)
					return
				if("hide_in_nebula")
					if(!current_ship.can_hide_in_nebula())
						if(current_ship.hidden_in_nebula)
							say("ERROR: Already concealed in nebula.")
						else if(current_ship.nebula_hide_timer)
							say("ERROR: Nebula concealment already in progress...")
						else if(current_ship.is_interdicted)
							say("ERROR: Cannot hide while interdicted!")
						else
							say("ERROR: Must be inside a nebula to engage concealment.")
						return
					if(current_ship.hide_in_nebula())
						say("Initiating nebula concealment sequence...")
					return
				if("cancel_nebula_hide")
					if(current_ship.cancel_nebula_hide())
						say("Nebula concealment cancelled.")
					return
				if("unhide_from_nebula")
					if(!current_ship.can_unhide_from_nebula())
						say("ERROR: Ship is not in concealment mode.")
						return
					if(current_ship.unhide_from_nebula())
						say("Emerging from nebula concealment. Combat systems online.")
					return
		if(OVERMAP_SHIP_IDLE)
			if(action == "undock")
				// Check if cargo shuttle is still present
				var/datum/voidcrew_cargo_shuttle/cargo_shuttle = current_ship.get_cargo_shuttle()
				cargo_shuttle?.check_stalled() // never let a stranded delivery strand the ship
				if(cargo_shuttle && cargo_shuttle.state != CARGO_SHUTTLE_AWAY)
					say("ERROR: Cannot undock while cargo shuttle is present. Send the cargo shuttle away first.")
					return
				current_ship.calculate_avg_fuel()
				if(current_ship.avg_fuel_amnt < 25 && tgui_alert(usr, "Ship only has ~[round(current_ship.avg_fuel_amnt)]% fuel remaining! Are you sure you want to undock?", name, list("Yes", "No")) != "Yes")
					return
				// As with docking, only refusals come back as text
				var/undock_result = current_ship.undock()
				if(undock_result)
					say(undock_result)
				return
		else
			// DOCKING, UNDOCKING and ACTING have no controls of their own, so every
			// navigation topic above is unreachable while the ship is in one of them and
			// used to fall off the end of this switch in total silence. A console that
			// eats every button without a word is indistinguishable from a broken one -
			// and until complete_dock() learned to give up (abort_stalled_dock() in
			// ship.dm) a stalled move really could pin the ship here for good.
			if(action in list("dock", "undock", "change_heading", "set_course", "stop", "autopilot", "autopilot_cancel", "change_burn_percentage", "toggle_engine", "bluespace_jump", "active_scan", "act_overmap", "hide_in_nebula", "cancel_nebula_hide", "unhide_from_nebula"))
				say("Manoeuvring systems busy: [current_ship.get_state_readout()]. Stand by.")
				playsound(src, 'sound/machines/terminal/terminal_error.ogg', 30)
			return



#undef HELM_DRUNK_CHANCE_PER_POINT
#undef HELM_DRUNK_MAX_CHANCE
#undef HELM_DRUNK_THRESHOLD
#undef JUMP_STATE_OFF
#undef JUMP_STATE_CHARGING
#undef JUMP_STATE_IONIZING
#undef JUMP_STATE_FIRING
#undef JUMP_STATE_FINALIZED
#undef JUMP_CHARGE_DELAY
#undef JUMP_CHARGEUP_TIME
#undef HAIL_SEND_COOLDOWN
#undef TYPING_SOUND_COOLDOWN
