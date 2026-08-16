// ========== TGUI INTERFACE ==========

/**
 * Faceplate art for the tactical interface. Composited by
 * tools/combat_plate/make_plate.py from a generated metal texture; re-run that
 * script if the panel GEOMETRY in ShipCombatConsole.tsx changes, or the bezels
 * will no longer line up with the wells.
 */
/datum/asset/simple/combat_faceplate
	assets = list(
		"combat_faceplate.png" = 'voidcrew/modules/ship_combat/console/combat_faceplate.png',
	)

/obj/machinery/computer/camera_advanced/ship_combat/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/combat_faceplate))

/obj/machinery/computer/camera_advanced/ship_combat/attack_hand(mob/user, list/modifiers)
	// Don't call parent - we handle our own UI
	if(machine_stat & (NOPOWER|BROKEN))
		balloon_alert(user, (machine_stat & BROKEN) ? "console broken!" : "no power!")
		return

	attempt_ship_connection()

	// Check crew membership
	if(!is_crew_member(user))
		to_chat(user, span_warning("Access denied. Crew authorization required."))
		return

	ui_interact(user)

/obj/machinery/computer/camera_advanced/ship_combat/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipCombatConsole")
		ui.open()

/obj/machinery/computer/camera_advanced/ship_combat/ui_state(mob/user)
	// Allow UI interaction while in camera mode (attack mode)
	// Server-side crew checks are still enforced in ui_act
	if(eyeobj && user.remote_control == eyeobj)
		return GLOB.always_state
	return GLOB.default_state

/obj/machinery/computer/camera_advanced/ship_combat/ui_status(mob/user, datum/ui_state/state)
	// When user is viewing through our camera eye, always allow interaction
	// This bypasses the stored ui_state which may be outdated
	if(eyeobj && user.remote_control == eyeobj)
		return UI_INTERACTIVE
	return ..()  // Fall back to normal state-based checks

/obj/machinery/computer/camera_advanced/ship_combat/ui_data(mob/user)
	var/list/data = list()

	data["connected"] = !!current_ship
	data["ship_name"] = current_ship?.display_name
	data["ship_class"] = current_ship?.source_template?.name
	data["ship_mass"] = current_ship?.mass || 0
	data["integrity"] = current_ship ? current_ship.get_integrity_percent() : 100
	data["ship_disabled"] = current_ship?.integrity_state == SHIP_INTEGRITY_DISABLED
	data["ship_docked"] = current_ship?.is_in_ship_to_ship_dock()  // Block shields when in ship-to-ship dock (either direction)
	data["hidden_in_nebula"] = current_ship?.hidden_in_nebula  // Combat systems offline when hidden
	data["cloak_active"] = cloak_active
	data["attack_mode"] = attack_mode
	data["is_in_attack_mode"] = (eyeobj && user.remote_control == eyeobj)
	data["target_name"] = target_ship ? contact_label(target_ship) : null
	data["target_ref"] = target_ship ? REF(target_ship) : null
	// Which way missiles and laser fire approach the target; null reads as auto
	data["approach_direction"] = selected_approach_direction ? dir2text(selected_approach_direction) : null
	// Completed hostile weapons locks on US, for the defense readout
	var/list/locked_by = list()
	for(var/obj/structure/overmap/ship/attacker as anything in current_ship?.locked_on_by)
		locked_by += attacker.display_name || attacker.name
	data["locked_by"] = locked_by

	// Zone information
	if(current_ship && SSovermap_zones.zones_active)
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone(get_turf(current_ship))
		if(zone)
			data["zone_type"] = zone.zone_type
			data["zone_name"] = zone.name
			data["zone_color"] = zone.get_color()
			data["weapons_allowed"] = zone.weapons_allowed()
			data["interdiction_allowed"] = zone.interdiction_allowed()
		else
			data["zone_type"] = null
			data["zone_name"] = "Unknown"
			data["zone_color"] = "#ffffff"
			data["weapons_allowed"] = TRUE
			data["interdiction_allowed"] = TRUE
		// Zone transition info
		data["zone_transitioning"] = current_ship.zone_transitioning
		if(current_ship.zone_transitioning && current_ship.zone_transition_start_time)
			var/elapsed = world.time - current_ship.zone_transition_start_time
			var/progress = clamp((elapsed / ZONE_TRANSITION_TIME) * 100, 0, 100)
			var/remaining = max(0, ZONE_TRANSITION_TIME - elapsed) / 10
			data["zone_transition_progress"] = round(progress)
			data["zone_transition_remaining"] = round(remaining, 0.1)
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
		data["zone_name"] = "Unknown"
		data["zone_color"] = "#ffffff"
		data["weapons_allowed"] = TRUE
		data["interdiction_allowed"] = TRUE
		data["zone_transitioning"] = FALSE
		data["zone_transition_progress"] = 0
		data["zone_transition_remaining"] = 0
		data["zone_transition_target"] = null

	// Targeting lock-in-progress data
	data["is_targeting"] = is_targeting
	data["targeting_ship_name"] = targeting_ship ? contact_label(targeting_ship) : null
	data["targeting_ship_ref"] = targeting_ship ? REF(targeting_ship) : null
	if(is_targeting && targeting_start_time)
		var/elapsed = world.time - targeting_start_time
		var/total_time = COMBAT_TARGETING_TIME // Evaluate macro fully before division
		var/progress = min(100, (elapsed / total_time) * 100)
		var/remaining = max(0, total_time - elapsed)
		data["targeting_progress"] = progress
		data["targeting_time_remaining"] = remaining / 10 // Convert to seconds
	else
		data["targeting_progress"] = 0
		data["targeting_time_remaining"] = 0

	// Get nearby ships within sensor range (3 tiles)
	var/list/nearby_ships = list()
	// Get our zone for comparison
	var/our_zone_type = data["zone_type"]
	if(current_ship)
		var/turf/our_turf = get_turf(current_ship)
		if(our_turf)
			for(var/obj/structure/overmap/ship/S in range(COMBAT_TARGETING_RANGE, our_turf))
				if(S == current_ship)
					continue
				// Check if ship is visible (not cloaked)
				if(S.invisibility > INVISIBILITY_NONE)
					continue
				// Calculate distance and relative offset (east/north positive) for the scope plot
				var/turf/target_turf = get_turf(S)
				var/distance = target_turf ? get_dist(our_turf, target_turf) : 0
				var/rel_x = target_turf ? (target_turf.x - our_turf.x) : 0
				var/rel_y = target_turf ? (target_turf.y - our_turf.y) : 0
				// Get target's zone
				var/target_zone_type = null
				var/target_zone_name = "Unknown"
				if(SSovermap_zones?.initialized && target_turf)
					var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_turf)
					if(target_zone)
						target_zone_type = target_zone.zone_type
						target_zone_name = target_zone.name
				// Can target if neither ship is in Neutral zone
				var/can_target = (our_zone_type != ZONE_GREEN) && (target_zone_type != ZONE_GREEN)
				// Identity is the ship's to grant, not this console's: an unscanned
				// hull is a return on the scope and nothing more, exactly as the helm
				// chart draws it. See knows_contact() in console_targeting.dm.
				var/known = knows_contact(S)
				nearby_ships += list(list(
					"name" = known ? (S.display_name || S.name) : "unknown contact",
					"identified" = known,
					"ref" = REF(S),
					// Withheld rather than zeroed behind a drawn bar: the client renders
					// no readout at all for an unidentified contact, so these are only
					// ever read once `identified` is set.
					"shields" = known ? S.shield_health : 0,
					"shields_max" = known ? S.shield_max_health : 0,
					"integrity" = known ? S.get_integrity_percent() : 0,
					"integrity_max" = 100,
					"distance" = distance,
					"dx" = rel_x,
					"dy" = rel_y,
					"is_outpost" = FALSE,
					"speed" = known ? round(S.get_speed(), 0.1) : 0,  // Speed in spM (spaces per minute) - same as helm
					"zone_type" = target_zone_type,
					"zone_name" = target_zone_name,
					"same_zone" = can_target,
				))
			// Raidable player outposts in range are valid siege targets
			for(var/obj/structure/overmap/dynamic/player_outpost/outpost as anything in GLOB.player_outposts)
				if(!outpost.raidable)
					continue
				var/turf/outpost_turf = get_turf(outpost)
				if(!outpost_turf || outpost_turf.z != our_turf.z)
					continue
				var/distance = get_dist(our_turf, outpost_turf)
				if(distance > COMBAT_TARGETING_RANGE)
					continue
				var/target_zone_type = null
				var/target_zone_name = "Unknown"
				if(SSovermap_zones?.initialized)
					var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(outpost_turf)
					if(target_zone)
						target_zone_type = target_zone.zone_type
						target_zone_name = target_zone.name
				nearby_ships += list(list(
					"name" = outpost.name,
					// An outpost is a fixture, not a vessel. It doesn't move, it can't
					// be mistaken for anything else, and the helm never anonymised one.
					"identified" = TRUE,
					"ref" = REF(outpost),
					"shields" = 0,
					"shields_max" = 0,
					"integrity" = 100,
					"integrity_max" = 100,
					"distance" = distance,
					"dx" = outpost_turf.x - our_turf.x,
					"dy" = outpost_turf.y - our_turf.y,
					"is_outpost" = TRUE,
					"speed" = 0,
					"zone_type" = target_zone_type,
					"zone_name" = target_zone_name,
					"same_zone" = (our_zone_type != ZONE_GREEN),
				))
	data["nearby_ships"] = nearby_ships

	// Get launcher status
	var/list/launchers = list()
	var/ready_count = 0
	var/total_count = 0
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		total_count++
		var/is_ready = launcher.can_fire(target_ship)
		if(is_ready)
			ready_count++
		launchers += list(launcher.get_status(target_ship))
	data["launchers"] = launchers
	data["launchers_ready"] = ready_count
	data["launchers_total"] = total_count

	// Get assault pod tube status
	var/list/pod_tubes = list()
	var/pods_ready_count = 0
	var/pods_total_count = 0
	for(var/datum/weakref/ref in linked_pod_tubes.Copy())
		var/obj/machinery/ship_combat/pod_launcher/tube = ref.resolve()
		if(!tube)
			linked_pod_tubes -= ref
			continue
		pods_total_count++
		if(tube.can_fire(target_ship))
			pods_ready_count++
		pod_tubes += list(tube.get_status(target_ship))
	data["pod_tubes"] = pod_tubes
	data["pod_tubes_ready"] = pods_ready_count
	data["pod_tubes_total"] = pods_total_count
	// Boarding into a live shield kills the pod crew - the plate says so up front
	data["target_shields_up"] = target_shields_up()

	// Get laser turret status
	var/list/turrets = list()
	var/turrets_ready_count = 0
	var/turrets_total_count = 0
	var/turret_power_available = 0
	var/turret_power_max = 0
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(!turret)
			linked_turrets -= ref
			continue
		turrets_total_count++
		if(turret.can_fire())
			turrets_ready_count++
		turret_power_available += turret.get_cell_charge()
		turret_power_max += turret.get_cell_max()
		turrets += list(turret.get_status())
	data["turrets"] = turrets
	data["turrets_ready"] = turrets_ready_count
	data["turrets_total"] = turrets_total_count
	data["turret_power_level"] = turret_power_level
	data["turret_power_available"] = round(turret_power_available)
	data["turret_power_max"] = round(turret_power_max)

	// Interdictor data - get from linked machine
	var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
	data["interdictor_linked"] = !!interdictor
	if(interdictor)
		var/list/interdictor_status = interdictor.get_status()
		data["interdiction_active"] = interdictor_status["interdiction_active"]
		data["interdiction_warming_up"] = interdictor_status["warming_up"]
		data["interdiction_warmup_progress"] = interdictor_status["warmup_progress"]
		data["interdictor_power_level"] = interdictor_status["power_allocation"]
		data["interdictor_power_draw"] = interdictor_status["power_draw"]
		data["interdictor_target_name"] = interdictor_status["target_name"]
		data["interdictor_target_speed_cap"] = interdictor_status["target_speed_cap"]
		data["interdict_cooldown_active"] = interdictor_status["cooldown_remaining"] > 0
		data["interdict_cooldown_remaining"] = interdictor_status["cooldown_remaining"] * 10  // Convert to deciseconds for UI
		data["interdictor_ready"] = interdictor_status["ready"]
	else
		data["interdiction_active"] = FALSE
		data["interdiction_warming_up"] = FALSE
		data["interdictor_power_level"] = 1
		data["interdict_cooldown_active"] = FALSE
		data["interdict_cooldown_remaining"] = 0
		data["interdictor_ready"] = FALSE

	// Check if WE are being interdicted (for display)
	if(current_ship?.is_interdicted)
		data["being_interdicted"] = TRUE
		data["our_interdiction_strength"] = round(current_ship.interdiction_strength * 100)
		data["can_burst_shields"] = current_ship.can_burst_shields()
		data["burst_shield_cost"] = round(current_ship.get_burst_shield_cost())
	else
		data["being_interdicted"] = FALSE
		data["can_burst_shields"] = FALSE
		data["burst_shield_cost"] = 0

	// Check target distance for interdiction, force dock, and missile lock
	var/target_in_interdict_range = FALSE
	var/target_in_missile_range = FALSE
	if(target_ship && current_ship)
		var/turf/our_turf = get_turf(current_ship)
		var/turf/target_turf = get_turf(target_ship)
		if(our_turf && target_turf)
			var/distance = get_dist(our_turf, target_turf)
			target_in_interdict_range = (distance <= INTERDICTOR_RANGE)
			target_in_missile_range = (distance <= COMBAT_MISSILE_LOCK_RANGE)
	data["target_in_interdict_range"] = target_in_interdict_range
	data["target_in_missile_range"] = target_in_missile_range

	// Shield data - aggregate from all generators on the ship
	var/has_any_generators = current_ship && length(current_ship.linked_shield_generators)
	data["shield_linked"] = has_any_generators
	if(has_any_generators)
		var/list/aggregated = get_aggregated_shield_status()
		data["shield_active"] = aggregated["active"]
		data["shield_broken"] = aggregated["broken"]
		data["shield_health"] = aggregated["health"]
		data["shield_max_health"] = aggregated["max_health"]
		data["shield_overhealth"] = aggregated["overhealth"]
		data["shield_power_allocation"] = aggregated["power_allocation"]
		data["shield_regen_rate"] = aggregated["regen_rate"]
		data["shield_power_draw"] = aggregated["power_draw"]
		data["shield_efficiency"] = aggregated["efficiency"]
		data["shield_cooldown_active"] = aggregated["cooldown_active"]
		data["shield_cooldown_remaining"] = aggregated["cooldown_remaining"]
		data["shield_generator_count"] = aggregated["generator_count"]
		data["shield_active_count"] = aggregated["active_count"]
		// Individual generator data with upgrades
		var/list/generators = list()
		for(var/obj/machinery/ship_combat/shield_generator/gen in current_ship.linked_shield_generators)
			var/list/gen_status = gen.get_status()
			gen_status["id"] = REF(gen)
			gen_status["name"] = gen.name
			gen_status["ref"] = REF(gen)
			// Calculate upgrade tiers from stock parts
			var/gen_capacitor_tier = 0
			var/gen_laser_tier = 0
			var/gen_servo_tier = 0
			for(var/datum/stock_part/capacitor/cap in gen.component_parts)
				gen_capacitor_tier += cap.tier
			for(var/datum/stock_part/micro_laser/laser in gen.component_parts)
				gen_laser_tier += laser.tier
			for(var/datum/stock_part/servo/servo in gen.component_parts)
				gen_servo_tier += servo.tier
			gen_status["upgrades"] = list(
				"capacitor_tier" = gen_capacitor_tier,
				"laser_tier" = gen_laser_tier,
				"servo_tier" = gen_servo_tier,
			)
			generators += list(gen_status)
		data["shield_generators"] = generators

	// Cloaking device data - get from linked machine
	var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
	data["cloak_linked"] = !!cloak
	// Cloak is unlocked if we have a linked cloak device (no research requirement)
	data["cloak_unlocked"] = !!cloak
	if(cloak)
		// Calculate upgrade tiers from stock parts
		var/capacitor_tier = 0
		var/laser_tier = 0
		var/scanning_tier = 0
		for(var/datum/stock_part/capacitor/cap in cloak.component_parts)
			capacitor_tier += cap.tier
		for(var/datum/stock_part/micro_laser/laser in cloak.component_parts)
			laser_tier += laser.tier
		for(var/datum/stock_part/scanning_module/scanner in cloak.component_parts)
			scanning_tier += scanner.tier

		// Duration remaining
		var/duration_remaining = 0
		if(cloak.cloak_active && cloak.cloak_expire_time > world.time)
			duration_remaining = (cloak.cloak_expire_time - world.time) / 10  // Convert to seconds

		// Cooldown remaining
		var/cooldown_remaining = 0
		if(!COOLDOWN_FINISHED(cloak, recloak_cooldown))
			cooldown_remaining = COOLDOWN_TIMELEFT(cloak, recloak_cooldown) / 10  // Convert to seconds

		// Send as a single cloak_device object matching TGUI CloakDevice type
		data["cloak_device"] = list(
			"active" = cloak.cloak_active,
			"can_activate" = cloak.can_activate_cloak(),
			"duration_remaining" = duration_remaining,
			"duration_max" = cloak.max_cloak_duration / 10,  // Convert to seconds
			"cooldown_remaining" = cooldown_remaining,
			"cooldown_max" = cloak.recloak_delay / 10,  // Convert to seconds
			"upgrades" = list(
				"capacitor_tier" = capacitor_tier,
				"laser_tier" = laser_tier,
				"scanning_tier" = scanning_tier,
			),
		)
	else
		data["cloak_device"] = null

	// Siphon data - get from linked machine
	var/obj/machinery/shuttle_scrambler/ship_siphon/siphon = linked_siphon_ref?.resolve()
	data["siphon_linked"] = !!siphon
	if(siphon)
		var/list/siphon_status = siphon.get_status()
		data["siphon_active"] = siphon_status["active"]
		data["siphon_warming_up"] = siphon_status["warming_up"]
		data["siphon_warmup_progress"] = siphon_status["warmup_progress"]
		data["siphon_credits_stored"] = siphon_status["credits_stored"]
		data["siphon_goal"] = siphon_status["siphon_goal"]
		data["siphon_goal_progress"] = siphon_status["goal_progress"]
		data["siphon_target_name"] = siphon_status["target_name"]
		// What the locked target is actually carrying - the panel greys the button
		// out on an empty hull instead of letting the siphon spin up and bounce.
		// Outposts and other non-ship targets hold no account, so they read zero.
		var/obj/structure/overmap/ship/siphon_target = target_ship
		data["siphon_target_credits"] = istype(siphon_target) ? (siphon_target.ship_account?.account_balance || 0) : 0
	else
		data["siphon_active"] = FALSE
		data["siphon_warming_up"] = FALSE
		data["siphon_warmup_progress"] = 0
		data["siphon_credits_stored"] = 0
		data["siphon_goal"] = 0
		data["siphon_goal_progress"] = 0
		data["siphon_target_name"] = null
		data["siphon_target_credits"] = 0

	return data

/obj/machinery/computer/camera_advanced/ship_combat/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	// Server-side crew check as safety net
	if(!is_crew_member(ui.user))
		to_chat(ui.user, span_warning("Access denied. Crew authorization required."))
		return TRUE

	switch(action)
		if("select_target")
			var/target_ref = params["ref"]
			if(!target_ref)
				return FALSE
			var/obj/structure/overmap/new_target = locate(target_ref) in SSovermap.simulated_ships
			if(!new_target)
				new_target = locate(target_ref) in GLOB.player_outposts
			if(!new_target || new_target == current_ship)
				return FALSE
			set_target_ship(new_target, ui.user)
			return TRUE

		if("clear_target")
			cancel_targeting()
			clear_target()
			return TRUE

		if("cancel_targeting")
			cancel_targeting()
			return TRUE

		if("activate")
			if(!target_ship)
				to_chat(ui.user, span_warning("Select a target first!"))
				return FALSE
			enter_attack_mode(ui.user)
			return TRUE

		if("deactivate")
			exit_attack_mode(ui.user)
			return TRUE

		if("fire_missile")
			fire_one(ui.user)
			return TRUE

		if("fire_all")
			fire_all(ui.user)
			return TRUE

		if("launch_pod")
			// Can stop to ask about shields, so it doesn't get to block the UI loop
			INVOKE_ASYNC(src, PROC_REF(launch_pod), ui.user)
			return TRUE

		if("start_interdict")
			var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
			if(!interdictor)
				to_chat(ui.user, span_warning("No interdictor linked! Link an interdiction system with a multitool."))
				return FALSE
			if(!istype(target_ship, /obj/structure/overmap/ship))
				to_chat(ui.user, span_warning("Interdiction fields cannot anchor a stationary structure."))
				return FALSE
			return interdictor.start_interdiction(target_ship, ui.user)

		if("cancel_interdict")
			var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
			if(interdictor)
				interdictor.cancel_interdiction("Cancelled by operator.")
			return TRUE

		if("set_interdictor_power")
			var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
			if(!interdictor)
				return FALSE
			var/new_power = params["power"]
			if(!isnum(new_power))
				return FALSE
			// Convert from percentage (25-200) to multiplier (0.25-2)
			interdictor.set_power_allocation(new_power / 100)
			return TRUE

		// Shield power allocation (0-200%) - applies to ship's shared shield pool
		if("set_shield_power")
			if(!current_ship || !length(current_ship.linked_shield_generators))
				to_chat(ui.user, span_warning("No shield generators are linked to the ship."))
				return FALSE
			var/new_power = params["power"]
			if(!isnum(new_power))
				return FALSE
			// Convert from percentage (0-200) to multiplier (0-2)
			var/power_mult = new_power / 100
			current_ship.set_shield_power_allocation(power_mult)
			invalidate_shield_cache()  // Force immediate UI refresh
			// The crew just asked for shields. If they cannot come up, say why -
			// a slider that silently does nothing reads as "shields refuse to work"
			// (round 4). Generators activate on their next process tick, so report
			// the blocking condition rather than polling for the state change.
			if(power_mult > 0 && !current_ship.shields_active)
				var/reason = current_ship.get_shield_blocker_reason()
				if(reason)
					to_chat(ui.user, span_warning(reason))
			return TRUE

		// Shield burst - sacrifice shields to break interdiction
		if("burst_shields")
			if(!current_ship)
				return FALSE
			if(!current_ship.can_burst_shields())
				var/required = current_ship.get_burst_shield_cost()
				to_chat(ui.user, span_warning("Cannot perform shield burst! Requires: being interdicted, shields active, and [required] shield health."))
				return FALSE
			return current_ship.burst_shields_break_interdiction()

		// Laser turret power allocation (25-200%) - applies to ALL turrets
		if("set_turret_power")
			var/new_power = params["power"]
			if(!isnum(new_power))
				return FALSE
			// Convert from percentage (25-200) to multiplier (0.25-2) and apply to all turrets
			turret_power_level = clamp(new_power / 100, LASER_POWER_MIN, LASER_POWER_MAX)
			for(var/datum/weakref/ref in linked_turrets)
				var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
				if(turret)
					turret.set_power_level(turret_power_level)
			return TRUE

		// Fire one laser at current target
		if("fire_laser")
			fire_laser_one(ui.user)
			return TRUE

		// Fire all lasers at current target
		if("fire_all_lasers")
			fire_all_lasers(ui.user)
			return TRUE

		// Cloaking device controls
		if("cloak_activate")
			var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
			if(!cloak)
				to_chat(ui.user, span_warning("No cloaking device linked! Link a cloaking device with a multitool."))
				return FALSE
			return cloak.activate_cloak(ui.user)

		if("cloak_deactivate")
			var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
			if(!cloak)
				return FALSE
			return cloak.deactivate_cloak()

		if("siphon_activate")
			var/obj/machinery/shuttle_scrambler/ship_siphon/siphon = linked_siphon_ref?.resolve()
			if(!siphon)
				to_chat(ui.user, span_warning("No siphon linked! Link a data siphon with a multitool."))
				return FALSE
			if(!target_ship)
				to_chat(ui.user, span_warning("No target locked. Acquire a weapons lock first."))
				return FALSE
			if(!istype(target_ship, /obj/structure/overmap/ship))
				to_chat(ui.user, span_warning("Siphon protocols require a ship-class target."))
				return FALSE
			return siphon.player_activate_siphon(ui.user, target_ship)

		if("siphon_deactivate")
			var/obj/machinery/shuttle_scrambler/ship_siphon/siphon = linked_siphon_ref?.resolve()
			if(siphon)
				siphon.deactivate_siphon()
			return TRUE

		// Which side of the target missiles and laser fire come in from
		if("set_approach_direction")
			var/dir_name = params["dir"]
			if(dir_name == "auto")
				selected_approach_direction = null
				return TRUE
			var/new_dir = text2dir(dir_name)
			if(!(new_dir in GLOB.cardinals))
				return FALSE
			selected_approach_direction = new_dir
			return TRUE

	return FALSE
