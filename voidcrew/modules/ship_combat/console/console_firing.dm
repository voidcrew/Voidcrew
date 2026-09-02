// ========== FIRING ==========

/// Get the turf the user is currently targeting (where the eye is)
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_target_turf()
	if(!eyeobj)
		return null
	return get_turf(eyeobj)

/**
 * If zone rules are what's stopping the shot, tell the gunner so instead of
 * leaving them with a generic "not ready" (or nothing at all). Returns TRUE
 * when the zone blocks fire and a message was sent.
 *
 * honor_siege_exception: missiles and pods may still fire at a raidable player
 * outpost outside the red zone; when that exception applies the zone isn't the
 * blocker, so stay quiet and let the normal fallback message run. Lasers have
 * no such exception and pass FALSE.
 */
/obj/machinery/computer/camera_advanced/ship_combat/proc/explain_zone_weapons_lock(mob/user, honor_siege_exception = TRUE)
	if(!user)
		return FALSE
	if(SSovermap_zones.weapons_allowed_at(src))
		return FALSE
	if(honor_siege_exception)
		for(var/datum/weakref/ref in linked_launchers)
			var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
			if(launcher?.is_siege_shot_allowed(target_ship))
				return FALSE
		for(var/datum/weakref/ref in linked_pod_tubes)
			var/obj/machinery/ship_combat/pod_launcher/tube = ref.resolve()
			if(tube?.is_siege_shot_allowed(target_ship))
				return FALSE
	var/zone_name = "this zone"
	if(current_ship)
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone(get_turf(current_ship))
		if(zone)
			zone_name = zone.name
	to_chat(user, span_warning("Weapons are safed in [zone_name]. Ship weapons can only fire in the [ZONE_NAME_RED]."))
	return TRUE

/// Fire at the current target location with all missiles from all launchers
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_all(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return 0

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return 0

	// Build list of staggered SPAWN positions (missiles converge on same target)
	// Spread missiles in a grid pattern at their spawn point
	var/list/stagger_offsets = list(
		list(0, 0),    // center
		list(-3, 0),   // left
		list(3, 0),    // right
		list(0, 3),    // up
		list(-3, 3),   // up-left
		list(3, 3),    // up-right
		list(0, -3),   // down
		list(-3, -3),  // down-left
		list(3, -3),   // down-right
	)

	var/fired_count = 0
	var/offset_index = 1

	// Fire ALL missiles from ALL launchers
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue

		// Keep firing from this launcher until it's empty
		while(launcher.can_fire(target_ship))
			// Get spawn offset for this missile
			var/list/offset = stagger_offsets[offset_index]

			// Fire at the SAME target, but with staggered spawn positions
			if(launcher.fire(target_turf, target_ship, current_ship, user, offset[1], offset[2], selected_approach_direction))
				fired_count++

			// Cycle through offsets
			offset_index++
			if(offset_index > length(stagger_offsets))
				offset_index = 1

	// Firing breaks cloak
	if(fired_count > 0 && current_ship)
		SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)

	if(user)
		if(fired_count > 0)
			to_chat(user, span_danger("Fired [fired_count] missile[fired_count > 1 ? "s" : ""]!"))
		else if(!explain_zone_weapons_lock(user))
			to_chat(user, span_warning("No missiles ready to fire!"))

	return fired_count

/// Fire the first ready launcher (optionally filtered by selected missile type)
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_one(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return FALSE

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		if(!launcher.can_fire(target_ship))
			continue
		// Filter by selected missile type if set
		if(selected_missile_type && launcher.loaded_missile)
			if(launcher.loaded_missile["payload_type"] != selected_missile_type)
				continue // Missile type doesn't match
		if(launcher.fire(target_turf, target_ship, current_ship, user, approach_dir = selected_approach_direction))
			// Firing breaks cloak
			if(current_ship)
				SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)
			if(user)
				to_chat(user, span_danger("Missile away!"))
			return TRUE

	if(user)
		if(explain_zone_weapons_lock(user))
			return FALSE
		if(selected_missile_type)
			to_chat(user, span_warning("No [selected_missile_type] missiles ready to fire!"))
		else
			to_chat(user, span_warning("No launchers ready to fire!"))
	return FALSE

/**
 * Launch one loaded assault pod at the current target location.
 *
 * Unlike the fire keys this can be carrying people, so a shielded target gets a
 * confirmation rather than a chat warning after the fact - a pod that meets a
 * live shield kills everyone strapped into it.
 */
/obj/machinery/computer/camera_advanced/ship_combat/proc/launch_pod(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return FALSE

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	var/obj/machinery/ship_combat/pod_launcher/tube = get_ready_pod_tube()
	if(!tube)
		if(user && !explain_zone_weapons_lock(user))
			to_chat(user, span_warning("No assault pod tubes ready to launch!"))
		return FALSE

	if(target_shields_up())
		var/choice = tgui_alert(
			user,
			"[target_ship.display_name] still has shields up. The pod will detonate against them and everyone aboard it will die. Launch anyway?",
			"Shields Detected",
			list("Hold", "Launch"),
		)
		if(choice != "Launch")
			to_chat(user, span_notice("Launch held."))
			return FALSE
		// The wait is long enough for the shot to have gone stale
		if(!attack_mode || QDELETED(target_ship))
			return FALSE
		target_turf = get_target_turf()
		if(!target_turf)
			return FALSE
		tube = get_ready_pod_tube()
		if(!tube)
			to_chat(user, span_warning("No assault pod tubes ready to launch!"))
			return FALSE

	if(!tube.fire(target_turf, target_ship, current_ship, user, selected_approach_direction))
		return FALSE

	// Launching breaks cloak, same as any other shot
	if(current_ship)
		SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)
	return TRUE

/// First linked pod tube that could launch right now, dropping dead refs as we go
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_ready_pod_tube()
	for(var/datum/weakref/ref in linked_pod_tubes.Copy())
		var/obj/machinery/ship_combat/pod_launcher/tube = ref.resolve()
		if(!tube)
			linked_pod_tubes -= ref
			continue
		if(!tube.can_fire(target_ship))
			continue
		return tube
	return null

/// Whether the locked target is currently holding a shield up
/obj/machinery/computer/camera_advanced/ship_combat/proc/target_shields_up()
	var/obj/structure/overmap/ship/target_vessel = target_ship
	if(istype(target_vessel))
		return target_vessel.shield_health > 0
	// A raidable player outpost holds a shield envelope of its own, and it kills a
	// boarding party the same way a ship shield does - try_outpost_shield_intercept()
	// routes straight into shield_impact(), which gibs everyone aboard. This check
	// only knew about ships, so a pod launched at a shielded outpost got no warning.
	var/obj/structure/overmap/dynamic/player_outpost/outpost = target_ship
	if(istype(outpost))
		var/obj/machinery/outpost_shield_generator/generator = outpost.get_shield_generator()
		return generator && generator.charge > 0
	return FALSE

/// Fire one ready laser turret at the current target location
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_laser_one(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return FALSE

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Lasers remain ship-to-ship only; sieging outposts is missile work
	if(!istype(target_ship, /obj/structure/overmap/ship))
		if(user)
			to_chat(user, span_warning("Laser tracking cannot resolve station-scale targets. Use missiles."))
		return FALSE

	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(!turret)
			linked_turrets -= ref
			continue
		if(!turret.can_fire())
			continue
		if(turret.fire(target_turf, target_ship, current_ship, user, approach_direction = selected_approach_direction))
			return TRUE

	if(user && !explain_zone_weapons_lock(user, honor_siege_exception = FALSE))
		to_chat(user, span_warning("No laser turrets ready to fire!"))
	return FALSE

/// Fire all ready laser turrets as a single combined beam at the current target
/// Combines damage from all ready turrets into one powerful multi-beam shot
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_all_lasers(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return 0

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return 0

	// Lasers remain ship-to-ship only; sieging outposts is missile work
	if(!istype(target_ship, /obj/structure/overmap/ship))
		if(user)
			to_chat(user, span_warning("Laser tracking cannot resolve station-scale targets. Use missiles."))
		return 0

	// Collect all ready turrets and calculate combined damage
	var/list/ready_turrets = list()
	var/combined_damage = 0
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(!turret)
			linked_turrets -= ref
			continue
		if(!turret.can_fire())
			continue
		ready_turrets += turret
		combined_damage += turret.get_effective_damage()

	if(!length(ready_turrets))
		if(user && !explain_zone_weapons_lock(user, honor_siege_exception = FALSE))
			to_chat(user, span_warning("No laser turrets ready to fire!"))
		return 0

	var/turret_count = length(ready_turrets)
	var/is_multi_beam = turret_count > 1

	// Use the first turret to actually fire, but drain power and start cooldown on ALL turrets
	var/obj/machinery/ship_combat/laser_turret/primary_turret = ready_turrets[1]

	// Drain power, start cooldown, and create visual effects on all turrets
	for(var/obj/machinery/ship_combat/laser_turret/turret in ready_turrets)
		var/power_needed = turret.get_power_per_shot()
		turret.cell?.use(power_needed)
		COOLDOWN_START(turret, fire_cooldown, turret.get_effective_cooldown())
		turret.update_appearance()
		// Create visual effects at each turret (always single beam at source turrets)
		// The multi-beam effect is only shown at the target ship
		new /obj/effect/temp_visual/turret_muzzle_flash(get_turf(turret), turret.dir)
		new /obj/effect/temp_visual/turret_laser_visual(get_turf(turret), turret.dir, FALSE)

	// Fire a single combined beam from the primary turret
	// Skip the normal fire() power/cooldown handling since we did it manually
	new /obj/effect/ship_laser_beam(
		get_turf(primary_turret),
		target_turf,
		target_ship,
		current_ship,
		combined_damage,
		primary_turret.power_level,
		is_multi_beam,
		selected_approach_direction,
	)

	// Create visual beam on the overmap between ships (only if not on same tile)
	if(current_ship && target_ship && get_turf(current_ship) != get_turf(target_ship))
		current_ship.Beam(
			target_ship,
			icon_state = "beam_omni",
			icon = 'icons/obj/weapons/guns/projectiles_tracer.dmi',
			emissive = TRUE,
			time = 0.5 SECONDS,
		)

	// Play sound (extrarange and ignore_walls so it's audible from inside the ship)
	playsound(primary_turret, 'sound/items/weapons/beam_sniper.ogg', 100, TRUE, extrarange = 50, ignore_walls = TRUE)

	// Visual feedback
	primary_turret.visible_message(span_danger("[turret_count > 1 ? "Multiple turrets fire" : "[primary_turret] fires"] a [is_multi_beam ? "concentrated" : ""] laser beam!"))

	// Firing breaks cloak
	if(current_ship)
		SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)
		SEND_SIGNAL(current_ship, COMSIG_SHIP_LASER_FIRED, primary_turret, target_ship)

	if(user)
		to_chat(user, span_danger("Fired [turret_count] turret[turret_count > 1 ? "s" : ""] as combined beam! ([round(combined_damage)] damage)"))

	return turret_count

/// Opens a power level selection for laser turrets
/obj/machinery/computer/camera_advanced/ship_combat/proc/open_laser_power_radial(mob/user)
	var/list/options = list("25%", "50%", "75%", "100%", "125%", "150%", "175%", "200%")

	var/choice = tgui_input_list(user, "Select laser power level:", "Laser Power", options)
	if(!choice)
		return

	var/new_level = text2num(choice) / 100
	turret_power_level = clamp(new_level, LASER_POWER_MIN, LASER_POWER_MAX)

	// Apply to all linked turrets
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(turret)
			turret.set_power_level(turret_power_level)

	to_chat(user, span_notice("Laser power set to [choice]. Damage: [round(LASER_DAMAGE_BASE * turret_power_level)], Power/shot: [round(LASER_POWER_BASE * turret_power_level)]W"))

/// Opens a selection menu to choose which missile type to fire
/obj/machinery/computer/camera_advanced/ship_combat/proc/open_missile_radial(mob/user)
	// Get available missile types from loaded launchers
	var/list/available_types = list()
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher?.loaded_missile)
			continue
		var/payload_type = launcher.loaded_missile["payload_type"]
		if(payload_type && !(payload_type in available_types))
			available_types += payload_type

	if(!length(available_types))
		to_chat(user, span_warning("No missiles loaded in any launcher!"))
		return

	// Build selection options - capitalize for display
	var/list/options = list("Any")
	for(var/payload_type in available_types)
		options += capitalize(payload_type)

	// Use tgui_input_list which works reliably with camera eye control
	var/choice = tgui_input_list(user, "Select missile type to fire:", "Missile Selection", options)
	if(!choice)
		return

	if(choice == "Any")
		selected_missile_type = null
		to_chat(user, span_notice("Will fire any available missile."))
	else
		// Convert back to lowercase payload_type
		selected_missile_type = lowertext(choice)
		to_chat(user, span_notice("Will fire [choice] missiles."))

/// Gets an icon state for a payload type
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_missile_type_icon(payload_type)
	switch(payload_type)
		if("light")
			return "low_yield_rocket"
		if("standard")
			return "84mm-heap"
		if("heavy")
			return "srm-8"
		if("EMP")
			return "disruptor-ammo"
		if("chemical")
			return "84mm-heap"
	return "84mm-heap"

/// Opens a selection menu to choose missile approach direction
/obj/machinery/computer/camera_advanced/ship_combat/proc/open_direction_radial(mob/user)
	var/list/options = list("Auto", "North", "South", "East", "West")

	// Use tgui_input_list which works reliably with camera eye control
	var/choice = tgui_input_list(user, "Select direction missiles approach from:", "Missile Direction", options)
	if(!choice)
		return

	switch(choice)
		if("Auto")
			selected_approach_direction = null
			to_chat(user, span_notice("Missiles will approach from the closest edge to target."))
		if("North")
			selected_approach_direction = NORTH
			to_chat(user, span_notice("Missiles will approach from the North."))
		if("South")
			selected_approach_direction = SOUTH
			to_chat(user, span_notice("Missiles will approach from the South."))
		if("East")
			selected_approach_direction = EAST
			to_chat(user, span_notice("Missiles will approach from the East."))
		if("West")
			selected_approach_direction = WEST
			to_chat(user, span_notice("Missiles will approach from the West."))

/// Get status of all linked launchers
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_launcher_status()
	var/list/status = list()
	var/ready_count = 0
	var/total_count = 0

	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		total_count++
		if(launcher.can_fire())
			ready_count++

	status["ready"] = ready_count
	status["total"] = total_count
	return status
