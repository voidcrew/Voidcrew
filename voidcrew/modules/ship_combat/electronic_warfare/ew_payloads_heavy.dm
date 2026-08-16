/**
 * Electronic Warfare Payloads - Heavy tier (3-4)
 *
 * Tier 3: drive_lockout, fire_control_freeze, shield_collapse, breaker_trip
 * Tier 4: runaway_burn, helm_poltergeist
 *
 * Movement payloads gate in the ship's thrust layer, not the helm UI:
 * - can_thrust() is checked by the player burn loop (ship.dm process()), the
 *   autopilot (autopilot_steer) AND every NPC movement behavior
 *   (ship_movement_behaviors.dm), so one chained override locks the drive for
 *   all three control paths.
 * - burn_engines()/change_heading() are chained on both the base ship and the
 *   NPC subtype (whose burn_engines override does not call parent) so a hijacked
 *   burn drives the actual momentum loop.
 * Weapon payloads gate in can_fire(), which both the combat console and the
 * NPC combat interface run before every shot.
 *
 * The gates read time-limited ship vars (ew_*_until deadlines), so even a
 * missed on_expire() self-heals when the deadline passes. Overlapping payloads
 * only clear a deadline they themselves imposed.
 */

// ========== SHIP STATE (added from this file) ==========

/obj/structure/overmap/ship
	/// world.time until which this ship's drive refuses to produce thrust (Drive Lockout)
	var/ew_drive_locked_until = 0
	/// world.time until which this ship's throttle is hijacked (Runaway Burn)
	var/ew_forced_burn_until = 0
	/// The heading a Runaway Burn payload has pinned the throttle to
	var/ew_forced_burn_dir = NONE
	/// world.time until which this ship's launchers and turrets refuse to fire (Fire-Control Freeze)
	var/ew_fire_control_locked_until = 0

// ========== CHAINED OVERRIDES: DRIVE ==========

/// A locked drive reports no usable engines - this single gate covers the
/// player burn loop, the autopilot and NPC discrete movement, which all ask
/// can_thrust() before moving.
/obj/structure/overmap/ship/can_thrust()
	if(world.time < ew_drive_locked_until)
		return FALSE
	return ..()

/// While the throttle is hijacked, steering commands that aren't the forced
/// heading are swallowed - helm buttons, BURN_STOP braking and autopilot
/// corrections included.
/obj/structure/overmap/ship/change_heading(direction)
	if(world.time < ew_forced_burn_until && ew_forced_burn_dir && direction != ew_forced_burn_dir)
		return
	return ..()

/obj/structure/overmap/ship/burn_engines(n_dir = null, percentage = 100, burn_seconds = 1)
	if(world.time < ew_drive_locked_until)
		return
	if(world.time < ew_forced_burn_until && ew_forced_burn_dir)
		// Every burn - including attempted braking - becomes a full burn on the
		// forced heading
		return ..(ew_forced_burn_dir, 100, burn_seconds)
	return ..()

/// The NPC override replaces the whole burn path without calling parent, so it
/// needs the same gates chained onto it directly.
/obj/structure/overmap/ship/npc/burn_engines(n_dir = null, percentage = 100)
	if(world.time < ew_drive_locked_until)
		return
	if(world.time < ew_forced_burn_until && ew_forced_burn_dir)
		return ..(ew_forced_burn_dir, 100)
	return ..()

// ========== CHAINED OVERRIDES: FIRE CONTROL ==========

/obj/machinery/ship_combat/laser_turret/can_fire()
	var/obj/structure/overmap/ship/gun_ship = get_ship_from_atom(src)
	if(gun_ship && world.time < gun_ship.ew_fire_control_locked_until)
		return FALSE
	return ..()

/obj/machinery/ship_combat/missile_launcher/can_fire(obj/structure/overmap/locked_target = null)
	var/obj/structure/overmap/ship/gun_ship = get_ship_from_atom(src)
	if(gun_ship && world.time < gun_ship.ew_fire_control_locked_until)
		return FALSE
	return ..()

// =====================================================================
// ========== TIER 3 ==========
// =====================================================================

// ========== DRIVE LOCKOUT (drive_lockout) ==========

/datum/ew_payload/drive_lockout
	id = "drive_lockout"
	name = "Drive Lockout"
	desc = "Cuts the target's engine burn and blocks all thrust for the duration."
	subsystem_name = "drive control"
	tier = 3
	warmup = 10 SECONDS
	duration = 25 SECONDS
	signature_cost = 35
	/// The deadline this instance wrote onto the ship, for ownership checks
	var/imposed_until = 0

/datum/ew_payload/drive_lockout/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target)
		return
	target.ew_drive_locked_until = max(target.ew_drive_locked_until, world.time + duration)
	imposed_until = target.ew_drive_locked_until
	// The tell: engines spark and the helm's thrust readout dies; burn attempts
	// also trip the ship's own "no thrust" warning
	if(target.shuttle)
		var/sparked = 0
		for(var/obj/machinery/power/shuttle_engine/ship/engine in target.shuttle.engine_list)
			if(QDELETED(engine))
				continue
			do_sparks(3, FALSE, engine)
			if(++sparked >= 3)
				break
	target.ship_notify("Drive control lockout in effect - thrust systems unresponsive.", "ENGINES", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 25)

/datum/ew_payload/drive_lockout/on_expire()
	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return
	// Only lift a lock we own - a later payload wrote a later deadline
	if(target.ew_drive_locked_until && target.ew_drive_locked_until <= imposed_until)
		target.ew_drive_locked_until = 0
		target.ship_notify("Drive control restored.", "ENGINES", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)

/obj/item/ew_exploit/drive_lockout
	name = "exploit cartridge (Drive Lockout)"
	desc = "Intrusion software that locks a target ship's drive out of its own engines."
	icon_state = "datadisk2"
	payload_type = /datum/ew_payload/drive_lockout
	charges = 3
	max_charges = 3

// ========== FIRE-CONTROL FREEZE (fire_control_freeze) ==========

/datum/ew_payload/fire_control_freeze
	id = "fire_control_freeze"
	name = "Fire-Control Freeze"
	desc = "Blocks the target's missile launchers and laser turrets from firing."
	subsystem_name = "fire control"
	tier = 3
	warmup = 10 SECONDS
	duration = 20 SECONDS
	signature_cost = 35
	/// The deadline this instance wrote onto the ship, for ownership checks
	var/imposed_until = 0

/datum/ew_payload/fire_control_freeze/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target)
		return
	target.ew_fire_control_locked_until = max(target.ew_fire_control_locked_until, world.time + duration)
	imposed_until = target.ew_fire_control_locked_until
	// The tell: weapon mounts spark and every console readout drops to not-ready
	var/sparked = 0
	for(var/obj/machinery/weapon as anything in target.get_ship_machines(/obj/machinery/ship_combat/laser_turret) + target.get_ship_machines(/obj/machinery/ship_combat/missile_launcher))
		if(QDELETED(weapon))
			continue
		do_sparks(3, FALSE, weapon)
		if(++sparked >= 4)
			break
	target.ship_notify("Fire-control computers frozen - weapons will not respond.", "WEAPONS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 25)

/datum/ew_payload/fire_control_freeze/on_expire()
	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return
	if(target.ew_fire_control_locked_until && target.ew_fire_control_locked_until <= imposed_until)
		target.ew_fire_control_locked_until = 0
		target.ship_notify("Fire-control computers restored.", "WEAPONS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)

/obj/item/ew_exploit/fire_control_freeze
	name = "exploit cartridge (Fire-Control Freeze)"
	desc = "Intrusion software that freezes a target ship's weapon fire-control computers."
	icon_state = "datadisk2"
	payload_type = /datum/ew_payload/fire_control_freeze
	charges = 3
	max_charges = 3

// ========== SHIELD COLLAPSE (shield_collapse) ==========

/datum/ew_payload/shield_collapse
	id = "shield_collapse"
	name = "Shield Collapse"
	desc = "Forces the target's shields down and blocks reactivation for the duration."
	subsystem_name = "shield control"
	tier = 3
	warmup = 10 SECONDS
	duration = 30 SECONDS
	signature_cost = 35
	/// Whether the target's shields were up when we hit them
	var/was_active = FALSE
	/// Whether the target's shields were already broken/cooling down at apply
	var/prior_broken = FALSE
	/// world.time the target's own reactivation cooldown would have ended
	var/natural_end = 0
	/// world.time our imposed reactivation cooldown ends, for ownership checks
	var/imposed_end = 0

/datum/ew_payload/shield_collapse/can_apply(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker)
	if(!target)
		return "No target."
	if(!length(target.linked_shield_generators))
		return "Target has no shield grid to attack."
	return TRUE

/datum/ew_payload/shield_collapse/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target)
		return
	was_active = target.shields_active
	prior_broken = target.shields_broken
	// A cooldown the crew already owed (from a genuine break) survives our
	// window; one imposed purely by this hack does not
	natural_end = prior_broken ? (world.time + COOLDOWN_TIMELEFT(target, shield_reactivation_cooldown)) : world.time

	if(was_active)
		// Full break: generators power down, shield walls drop, break signal fires
		target.break_ship_shields(graceful = FALSE)
	// Covers the shields-off case too: activate_generator() refuses while broken
	target.shields_broken = TRUE
	COOLDOWN_START(target, shield_reactivation_cooldown, max(duration, COOLDOWN_TIMELEFT(target, shield_reactivation_cooldown)))
	imposed_end = world.time + COOLDOWN_TIMELEFT(target, shield_reactivation_cooldown)
	// The shields-off path above forces shields_broken without break_ship_shields(),
	// which is what normally starts ship processing - the only thing that ever clears
	// the flag once the cooldown ends. Without this, a lost on_expire() (attacker
	// deleted mid-window) left the target refusing shield activation for the rest of
	// the round with no message anywhere. Idempotent when already processing.
	target.start_shield_processing()

	var/sparked = 0
	for(var/obj/machinery/ship_combat/shield_generator/gen in target.linked_shield_generators)
		if(QDELETED(gen))
			continue
		do_sparks(3, FALSE, gen)
		if(++sparked >= 3)
			break
	target.ship_notify("Shield control compromised - shields down, reactivation blocked.", "SHIELDS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 30)

/datum/ew_payload/shield_collapse/on_expire()
	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return
	var/current_end = world.time + COOLDOWN_TIMELEFT(target, shield_reactivation_cooldown)
	if(current_end > imposed_end)
		// A later collapse (or something else) extended the lock past ours -
		// it owns the restore now
		return
	// Hand back whatever cooldown was naturally owed (usually none) - with it
	// finished, the ship's own process() reactivates willing generators, or
	// the crew can bring them up by hand
	COOLDOWN_START(target, shield_reactivation_cooldown, max(0, natural_end - world.time))
	if(!was_active && !prior_broken)
		// We forced the broken flag onto a ship whose shields were merely off;
		// nothing is pending, so clear it outright
		target.shields_broken = FALSE
	target.ship_notify("Shield control restored.", "SHIELDS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)

/obj/item/ew_exploit/shield_collapse
	name = "exploit cartridge (Shield Collapse)"
	desc = "Intrusion software that forces a target ship's shield grid offline."
	icon_state = "datadisk2"
	payload_type = /datum/ew_payload/shield_collapse
	charges = 3
	max_charges = 3

// ========== BREAKER TRIP (breaker_trip) ==========

/datum/ew_payload/breaker_trip
	id = "breaker_trip"
	name = "Breaker Trip"
	desc = "Trips the equipment and lighting breakers on every APC aboard the target."
	subsystem_name = "power distribution"
	tier = 3
	warmup = 8 SECONDS
	duration = 30 SECONDS
	signature_cost = 30
	/// Weakref -> list(prior equipment setting, prior lighting setting) per APC
	var/list/apc_settings

/datum/ew_payload/breaker_trip/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target?.shuttle?.shuttle_areas)
		return
	apc_settings = list()
	var/sparked = 0
	for(var/area/ship_area as anything in target.shuttle.shuttle_areas)
		for(var/obj/machinery/power/apc/breaker in ship_area)
			if(QDELETED(breaker))
				continue
			apc_settings[WEAKREF(breaker)] = list(breaker.equipment, breaker.lighting)
			breaker.equipment = APC_CHANNEL_OFF
			breaker.lighting = APC_CHANNEL_OFF
			breaker.update_appearance(UPDATE_ICON)
			// update() pushes the dead channels onto the area and plays the
			// power-down sound at each APC - the shipwide tell
			breaker.update()
			if(sparked < 4)
				do_sparks(2, TRUE, breaker)
				sparked++

/datum/ew_payload/breaker_trip/on_expire()
	for(var/datum/weakref/breaker_ref as anything in apc_settings)
		var/obj/machinery/power/apc/breaker = breaker_ref?.resolve()
		if(!breaker || QDELETED(breaker))
			continue
		var/list/prior = apc_settings[breaker_ref]
		var/changed = FALSE
		// Restore only channels still tripped - a crew member who already
		// flipped a breaker back keeps their setting
		if(breaker.equipment == APC_CHANNEL_OFF)
			breaker.equipment = prior[1]
			changed = TRUE
		if(breaker.lighting == APC_CHANNEL_OFF)
			breaker.lighting = prior[2]
			changed = TRUE
		if(changed)
			breaker.update_appearance(UPDATE_ICON)
			breaker.update()
	apc_settings = null

/obj/item/ew_exploit/breaker_trip
	name = "exploit cartridge (Breaker Trip)"
	desc = "Intrusion software that trips the breakers on a target ship's power distribution."
	icon_state = "datadisk2"
	payload_type = /datum/ew_payload/breaker_trip
	charges = 3
	max_charges = 3

// =====================================================================
// ========== TIER 4 ==========
// =====================================================================

// ========== RUNAWAY BURN (runaway_burn) ==========

/datum/ew_payload/runaway_burn
	id = "runaway_burn"
	name = "Runaway Burn"
	desc = "Pins the target's throttle at full burn on its current heading, ignoring helm input."
	subsystem_name = "drive control"
	tier = 4
	warmup = 12 SECONDS
	duration = 15 SECONDS
	signature_cost = 45
	/// The deadline this instance wrote onto the ship, for ownership checks
	var/imposed_until = 0

/datum/ew_payload/runaway_burn/can_apply(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker)
	if(!target)
		return "No target."
	if(target.state != OVERMAP_SHIP_FLYING)
		return "Target's drive is not under way."
	return TRUE

/datum/ew_payload/runaway_burn/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target)
		return
	// Current heading; a stationary target burns wherever it was last pointed,
	// or a random heading if it never was
	var/forced_dir = target.get_heading()
	if(!forced_dir)
		forced_dir = (target.burn_direction > 0) ? target.burn_direction : pick(GLOB.cardinals)

	// Clear the flight computer's commanded course so the lock isn't fighting it
	target.disengage_autopilot("helm override detected")

	target.ew_forced_burn_dir = forced_dir
	target.ew_forced_burn_until = world.time + duration
	imposed_until = target.ew_forced_burn_until
	// Light the burn through the ship's own steering proc (the forced heading
	// passes our own gate) so thrust processing spins up normally
	target.change_heading(forced_dir)

	if(target.shuttle)
		var/sparked = 0
		for(var/obj/machinery/power/shuttle_engine/ship/engine in target.shuttle.engine_list)
			if(QDELETED(engine))
				continue
			do_sparks(3, FALSE, engine)
			if(++sparked >= 3)
				break
	target.ship_notify("Throttle override detected - engines locked at full burn! Helm input is not responding.", "ENGINES", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 30)

/datum/ew_payload/runaway_burn/on_expire()
	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return
	if(!target.ew_forced_burn_until || target.ew_forced_burn_until > imposed_until)
		return
	var/forced_dir = target.ew_forced_burn_dir
	target.ew_forced_burn_until = 0
	target.ew_forced_burn_dir = NONE
	// Kill the burn we lit; the crew takes it from here
	if(target.burn_direction == forced_dir)
		target.change_heading(BURN_NONE)
	target.ship_notify("Throttle control restored.", "ENGINES", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)

/obj/item/ew_exploit/runaway_burn
	name = "exploit cartridge (Runaway Burn)"
	desc = "Intrusion software that pins a target ship's throttle wide open."
	icon_state = "datadisk7"
	payload_type = /datum/ew_payload/runaway_burn
	charges = 2
	max_charges = 2

// ========== POLTERGEIST (helm_poltergeist) ==========

/datum/ew_payload/helm_poltergeist
	id = "helm_poltergeist"
	name = "Poltergeist"
	desc = "Shoves the target's course onto a random heading every few seconds."
	subsystem_name = "helm control"
	tier = 4
	warmup = 12 SECONDS
	duration = 20 SECONDS
	signature_cost = 40
	/// Looping timer driving the course nudges
	var/pulse_timer_id
	/// The last heading we shoved the ship onto, so expiry only clears our burn
	var/last_forced_dir = NONE

/datum/ew_payload/helm_poltergeist/can_apply(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker)
	if(!target)
		return "No target."
	if(target.state != OVERMAP_SHIP_FLYING)
		return "Target's helm is not under way."
	return TRUE

/datum/ew_payload/helm_poltergeist/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target)
		return
	target.ship_notify("Helm interference detected - course keeps deviating from input!", "HELM", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 25)
	pulse()
	pulse_timer_id = addtimer(CALLBACK(src, PROC_REF(pulse)), 3 SECONDS, TIMER_STOPPABLE | TIMER_LOOP)

/// One course shove. Timer callback - revalidates everything every pulse.
/datum/ew_payload/helm_poltergeist/proc/pulse()
	if(expired)
		return
	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return
	if(target.state != OVERMAP_SHIP_FLYING || target.zone_transitioning)
		return
	// The autopilot would just steer back - break it first, with feedback
	target.interrupt_autopilot("helm interference")
	last_forced_dir = pick(GLOB.alldirs)
	target.change_heading(last_forced_dir)

/datum/ew_payload/helm_poltergeist/on_expire()
	if(pulse_timer_id)
		deltimer(pulse_timer_id)
		pulse_timer_id = null
	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return
	// Stop only a burn we started; a heading the crew re-took stays theirs
	if(last_forced_dir && target.burn_direction == last_forced_dir)
		target.change_heading(BURN_NONE)
	target.ship_notify("Helm control restored.", "HELM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)

/obj/item/ew_exploit/helm_poltergeist
	name = "exploit cartridge (Poltergeist)"
	desc = "Intrusion software that wrenches a target ship's helm onto random headings."
	icon_state = "datadisk7"
	payload_type = /datum/ew_payload/helm_poltergeist
	charges = 2
	max_charges = 2
