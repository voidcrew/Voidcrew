/**
 * Electronic Warfare Payloads - Utility tier (1-2)
 *
 * Tier 1: lights_out, phantom_klaxons, door_seize
 * Tier 2: overvolt_doors, vent_purge, comms_blackout, sensor_ghosts, system_scramble
 *
 * Each payload subtype overrides only can_apply()/on_apply()/on_expire() on
 * /datum/ew_payload (see ew_payload.dm - the base New() handles registration,
 * warnings, expiry scheduling). Restore data is held as weakrefs or plain
 * values and cleared in on_expire(); no payload keeps a hard ref to anything
 * on the target ship.
 *
 * Chip subtypes live beside their payload.
 */

// ========== SHIP STATE (added from this file) ==========

/obj/structure/overmap/ship
	/// Phantom contact entries a Ghost Contacts payload is injecting into this
	/// ship's helm picture, in get_contact_snapshot() entry format. Null when clean.
	var/list/ew_phantom_contacts

/// Comms network keys (see get_comms_net() in voidcrew/modules/comms/comms.dm)
/// currently jammed by a Comms Blackout payload, as key -> world.time the jam ends.
/// Values are deadlines rather than flags so a missed cleanup self-heals.
GLOBAL_LIST_EMPTY(ew_jammed_comms_nets)

// ========== CHAINED OVERRIDES ==========

/**
 * Appends any injected phantom contacts to the helm contact picture.
 *
 * Returns a fresh concatenated list rather than appending to the parent's
 * return value - the parent caches its snapshot and mutating it would stack
 * duplicate ghosts on every read.
 */
/obj/structure/overmap/ship/get_contact_snapshot()
	. = ..()
	if(!length(ew_phantom_contacts))
		return
	return . + ew_phantom_contacts

/**
 * Drops ship-scoped transmissions on a jammed comms network.
 *
 * Every scoped voidcrew vocal signal stamps data["voidcrew_net"] with the
 * speaker's network key in send_to_receivers() before calling broadcast(),
 * so gating here silences the whole internal ship channel - sending and
 * receiving - while leaving the unscoped galaxy-wide channels (Wideband,
 * etc.) untouched.
 */
/datum/signal/subspace/vocal/voidcrew/broadcast()
	set waitfor = FALSE
	var/net = data["voidcrew_net"]
	if(net && GLOB.ew_jammed_comms_nets[net] > world.time)
		// The message dies in the handset. Tell the speaker their radio is dead
		// air rather than letting the silence read as a bug.
		var/mob/talker = virt?.source
		if(ismob(talker))
			to_chat(talker, span_warning("Your radio spits static - the channel is being jammed."))
		QDEL_IN(virt, 5 SECONDS)
		return
	return ..()

// =====================================================================
// ========== TIER 1 ==========
// =====================================================================

// ========== BLACKOUT (lights_out) ==========

/datum/ew_payload/lights_out
	id = "lights_out"
	name = "Blackout"
	desc = "Shuts down every light aboard the target ship for the duration."
	subsystem_name = "lighting control"
	tier = 1
	warmup = 4 SECONDS
	duration = 45 SECONDS
	signature_cost = 10
	/// Weakrefs of every light this payload turned off (all were on at apply)
	var/list/darkened_lights
	/// Timer ids for the apply-time flicker, cancelled on early expiry
	var/list/flicker_timers

/datum/ew_payload/lights_out/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target?.shuttle?.shuttle_areas)
		return
	darkened_lights = list()
	var/sparked = 0
	for(var/area/ship_area as anything in target.shuttle.shuttle_areas)
		for(var/obj/machinery/light/light in ship_area)
			if(!light.on)
				continue
			darkened_lights += WEAKREF(light)
			light.set_on(FALSE)
			if(sparked < 3)
				playsound(light, 'sound/effects/sparks/sparks4.ogg', 50, TRUE)
				sparked++
	if(!length(darkened_lights))
		return
	// The tell: lights snap off, blink back for a moment, then drop for good.
	flicker_timers = list(
		addtimer(CALLBACK(src, PROC_REF(flicker_lights), TRUE), 0.4 SECONDS, TIMER_STOPPABLE),
		addtimer(CALLBACK(src, PROC_REF(flicker_lights), FALSE), 0.8 SECONDS, TIMER_STOPPABLE),
	)

/// Blinks every affected light on/off partway through apply. Timer callback -
/// revalidates everything and stands down once the payload has expired.
/datum/ew_payload/lights_out/proc/flicker_lights(turn_on)
	if(expired)
		return
	for(var/datum/weakref/light_ref as anything in darkened_lights)
		var/obj/machinery/light/light = light_ref?.resolve()
		if(!light || QDELETED(light))
			continue
		light.set_on(turn_on)

/datum/ew_payload/lights_out/on_expire()
	for(var/timer_id in flicker_timers)
		deltimer(timer_id)
	flicker_timers = null
	for(var/datum/weakref/light_ref as anything in darkened_lights)
		var/obj/machinery/light/light = light_ref?.resolve()
		if(!light || QDELETED(light))
			continue
		light.set_on(TRUE)
	darkened_lights = null

/obj/item/ew_exploit/lights_out
	name = "exploit cartridge (Blackout)"
	desc = "Intrusion software that shuts down a target ship's lighting grid."
	icon_state = "datadisk0"
	payload_type = /datum/ew_payload/lights_out
	charges = 5
	max_charges = 5

// ========== PHANTOM KLAXONS (phantom_klaxons) ==========

/datum/ew_payload/phantom_klaxons
	id = "phantom_klaxons"
	name = "Phantom Klaxons"
	desc = "Trips the target's fire alarms shipwide, dropping every firelock."
	subsystem_name = "fire suppression"
	tier = 1
	warmup = 4 SECONDS
	duration = 30 SECONDS
	signature_cost = 10
	/// Weakrefs of firelocks this payload activated (all were inactive at apply)
	var/list/tripped_locks

/datum/ew_payload/phantom_klaxons/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target?.shuttle?.shuttle_areas)
		return
	tripped_locks = list()
	for(var/area/ship_area as anything in target.shuttle.shuttle_areas)
		for(var/obj/machinery/door/firedoor/lock in ship_area)
			if(lock.active)
				// A real (or earlier) alarm already owns this door - leave it be
				continue
			tripped_locks += WEAKREF(lock)
			// Sounds the klaxon and drops the door plus its merge group
			lock.start_activation_process(FIRELOCK_ALARM_TYPE_GENERIC)

/datum/ew_payload/phantom_klaxons/on_expire()
	for(var/datum/weakref/lock_ref as anything in tripped_locks)
		var/obj/machinery/door/firedoor/lock = lock_ref?.resolve()
		if(!lock || QDELETED(lock))
			continue
		if(!lock.active)
			continue
		// Resets the door and its merge group; a genuine fire re-trips its own
		// sensors on the next check, so this can't mask a real alarm for long
		lock.start_deactivation_process()
	tripped_locks = null

/obj/item/ew_exploit/phantom_klaxons
	name = "exploit cartridge (Phantom Klaxons)"
	desc = "Intrusion software that trips a target ship's fire alarms and firelocks."
	icon_state = "datadisk0"
	payload_type = /datum/ew_payload/phantom_klaxons
	charges = 5
	max_charges = 5

// ========== BOLT OVERRIDE (door_seize) ==========

/datum/ew_payload/door_seize
	id = "door_seize"
	name = "Bolt Override"
	desc = "Seizes the target's door controllers: bolt every airlock shut, or unbolt them all."
	subsystem_name = "door control"
	tier = 1
	warmup = 5 SECONDS
	duration = 30 SECONDS
	signature_cost = 15
	modes = list("bolt", "release")
	/// Weakref -> the door's bolt state before we touched it
	var/list/door_bolt_states

/datum/ew_payload/door_seize/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target?.shuttle?.shuttle_areas)
		return
	door_bolt_states = list()
	for(var/area/ship_area as anything in target.shuttle.shuttle_areas)
		for(var/obj/machinery/door/airlock/door in ship_area)
			if(door.machine_stat & (BROKEN | NOPOWER))
				// The exploit works the door's own electronics - dead doors don't answer
				continue
			door_bolt_states[WEAKREF(door)] = door.locked
			if(mode == "release")
				if(door.locked)
					door.unbolt()
			else
				// close() sleeps, so each door gets its own context (malf AI
				// lockdown pattern)
				INVOKE_ASYNC(src, PROC_REF(seize_door), door)

/// Closes and bolts one airlock. Runs async per door because close() sleeps.
/datum/ew_payload/door_seize/proc/seize_door(obj/machinery/door/airlock/door)
	if(QDELETED(door) || expired)
		return
	if(door.locked && !door.density)
		// Bolted open - drop the bolts so the door can close, then re-bolt shut
		door.locked = FALSE
	door.close()
	if(QDELETED(door) || expired)
		return
	door.bolt()

/datum/ew_payload/door_seize/on_expire()
	for(var/datum/weakref/door_ref as anything in door_bolt_states)
		var/obj/machinery/door/airlock/door = door_ref?.resolve()
		if(!door || QDELETED(door))
			continue
		var/was_bolted = door_bolt_states[door_ref]
		if(was_bolted && !door.locked)
			door.bolt()
		else if(!was_bolted && door.locked)
			door.unbolt()
	door_bolt_states = null

/obj/item/ew_exploit/door_seize
	name = "exploit cartridge (Bolt Override)"
	desc = "Intrusion software that seizes a target ship's airlock bolt controllers."
	icon_state = "datadisk0"
	payload_type = /datum/ew_payload/door_seize
	charges = 5
	max_charges = 5

// =====================================================================
// ========== TIER 2 ==========
// =====================================================================

// ========== OVERVOLT (overvolt_doors) ==========

/datum/ew_payload/overvolt_doors
	id = "overvolt_doors"
	name = "Overvolt"
	desc = "Electrifies every airlock on the target ship for the duration."
	subsystem_name = "door power grid"
	tier = 2
	warmup = 6 SECONDS
	duration = 30 SECONDS
	signature_cost = 20
	/// Weakrefs of doors this payload electrified (all were clean at apply)
	var/list/shocked_doors

/datum/ew_payload/overvolt_doors/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target?.shuttle?.shuttle_areas)
		return
	shocked_doors = list()
	var/sparked = 0
	for(var/area/ship_area as anything in target.shuttle.shuttle_areas)
		for(var/obj/machinery/door/airlock/door in ship_area)
			if(door.machine_stat & (BROKEN | NOPOWER))
				continue
			if(door.secondsElectrified != MACHINE_NOT_ELECTRIFIED)
				// Already hot (crew trap or another exploit) - not ours to manage
				continue
			shocked_doors += WEAKREF(door)
			// Timed to the payload duration; the countdown is the fallback and
			// on_expire() is the authoritative clear
			door.set_electrified(round(duration / 10))
			if(sparked < 6)
				do_sparks(3, TRUE, door)
				sparked++

/datum/ew_payload/overvolt_doors/on_expire()
	for(var/datum/weakref/door_ref as anything in shocked_doors)
		var/obj/machinery/door/airlock/door = door_ref?.resolve()
		if(!door || QDELETED(door))
			continue
		// Only clear a still-running timed shock. A permanent electrification
		// (crew wire work during the window) is deliberately left alone.
		if(door.secondsElectrified > MACHINE_NOT_ELECTRIFIED)
			door.set_electrified(MACHINE_NOT_ELECTRIFIED)
	shocked_doors = null

/obj/item/ew_exploit/overvolt_doors
	name = "exploit cartridge (Overvolt)"
	desc = "Intrusion software that dumps charge into a target ship's airlock frames."
	icon_state = "datadisk1"
	payload_type = /datum/ew_payload/overvolt_doors
	charges = 4
	max_charges = 4

// ========== VENT PURGE (vent_purge) ==========

/datum/ew_payload/vent_purge
	id = "vent_purge"
	name = "Vent Purge"
	desc = "Switches every air alarm on the target to panic siphon, venting the ship's atmosphere."
	subsystem_name = "life support"
	tier = 2
	warmup = 8 SECONDS
	duration = 45 SECONDS
	signature_cost = 25
	/// Weakref -> the air alarm mode typepath it ran before we touched it
	var/list/alarm_modes

/datum/ew_payload/vent_purge/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target?.shuttle?.shuttle_areas)
		return
	alarm_modes = list()
	for(var/area/ship_area as anything in target.shuttle.shuttle_areas)
		for(var/obj/machinery/airalarm/alarm in ship_area)
			if(!alarm.my_area)
				continue
			alarm_modes[WEAKREF(alarm)] = alarm.selected_mode?.type || /datum/air_alarm_mode/filtering
			alarm.select_mode(alarm, /datum/air_alarm_mode/panic_siphon)
			playsound(alarm, 'sound/machines/warning-buzzer.ogg', 40, TRUE)
	if(!length(alarm_modes))
		return
	// This one kills - the warning is loud and unambiguous
	target.ship_notify("WARNING: Air alarms switching to panic siphon on all decks. Atmosphere is being vented!", "LIFE SUPPORT", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 30)

/datum/ew_payload/vent_purge/on_expire()
	for(var/datum/weakref/alarm_ref as anything in alarm_modes)
		var/obj/machinery/airalarm/alarm = alarm_ref?.resolve()
		if(!alarm || QDELETED(alarm) || !alarm.my_area)
			continue
		// Only revert alarms still stuck in our siphon - a crew member who
		// already reset one keeps their setting
		if(alarm.selected_mode?.type != /datum/air_alarm_mode/panic_siphon)
			continue
		alarm.select_mode(alarm, alarm_modes[alarm_ref] || /datum/air_alarm_mode/filtering)
	alarm_modes = null

/obj/item/ew_exploit/vent_purge
	name = "exploit cartridge (Vent Purge)"
	desc = "Intrusion software that turns a target ship's air alarms against its own atmosphere."
	icon_state = "datadisk1"
	payload_type = /datum/ew_payload/vent_purge
	charges = 4
	max_charges = 4

// ========== COMMS BLACKOUT (comms_blackout) ==========

/datum/ew_payload/comms_blackout
	id = "comms_blackout"
	name = "Comms Blackout"
	desc = "Jams the target ship's internal radio network. Wideband hailing still gets through."
	subsystem_name = "communications array"
	tier = 2
	warmup = 6 SECONDS
	duration = 60 SECONDS
	signature_cost = 20
	// NPC crews don't co-ordinate over vocal radio - nothing to jam
	works_on_npc = FALSE
	/// The network key this instance jammed
	var/jammed_net
	/// The deadline this instance wrote into the jam list, for ownership checks
	var/jam_deadline = 0

/datum/ew_payload/comms_blackout/can_apply(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker)
	if(!target?.shuttle)
		return "No comms network detected on the target."
	return TRUE

/datum/ew_payload/comms_blackout/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target?.shuttle)
		return
	// Same key get_comms_net() stamps onto scoped transmissions
	jammed_net = "ship_[REF(target.shuttle)]"
	jam_deadline = world.time + duration
	GLOB.ew_jammed_comms_nets[jammed_net] = jam_deadline
	target.ship_notify("Broad-spectrum interference detected. Internal radio channels are being jammed.", "COMMS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	target.play_ship_sound('sound/effects/empulse.ogg', 30)

/datum/ew_payload/comms_blackout/on_expire()
	if(!jammed_net)
		return
	// Only lift a jam we own - a later payload on the same net wrote a later deadline
	if(GLOB.ew_jammed_comms_nets[jammed_net] && GLOB.ew_jammed_comms_nets[jammed_net] <= jam_deadline)
		GLOB.ew_jammed_comms_nets -= jammed_net
		var/obj/structure/overmap/ship/target = get_target()
		if(target && !QDELETED(target))
			target.ship_notify("Interference cleared. Internal radio channels restored.", "COMMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)
	jammed_net = null

/obj/item/ew_exploit/comms_blackout
	name = "exploit cartridge (Comms Blackout)"
	desc = "Intrusion software that jams a target ship's internal radio network."
	icon_state = "datadisk1"
	payload_type = /datum/ew_payload/comms_blackout
	charges = 4
	max_charges = 4

// ========== GHOST CONTACTS (sensor_ghosts) ==========

/datum/ew_payload/sensor_ghosts
	id = "sensor_ghosts"
	name = "Ghost Contacts"
	desc = "Paints three phantom vessel contacts onto the target's sensor picture."
	subsystem_name = "sensor array"
	tier = 2
	warmup = 6 SECONDS
	duration = 120 SECONDS
	signature_cost = 15
	// NPC hulls don't read the helm contact picture - nothing to spoof
	works_on_npc = FALSE
	/// The phantom entry list this instance injected, for ownership checks
	var/list/my_ghosts

/datum/ew_payload/sensor_ghosts/can_apply(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker)
	if(!target?.get_relative_overmap_coords())
		return "Cannot resolve the target's sensor grid."
	return TRUE

/datum/ew_payload/sensor_ghosts/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	var/list/origin = target?.get_relative_overmap_coords()
	if(!origin)
		return
	my_ghosts = list()
	for(var/i in 1 to 3)
		// Scatter inside the view ring so the ghosts draw as live sightings
		var/ghost_x = 0
		var/ghost_y = 0
		while(!ghost_x && !ghost_y)
			ghost_x = rand(-SHIP_VIEW_RANGE + 1, SHIP_VIEW_RANGE - 1)
			ghost_y = rand(-SHIP_VIEW_RANGE + 1, SHIP_VIEW_RANGE - 1)
		my_ghosts += list(list(
			"name" = "unknown contact",
			"x" = clamp(origin[1] + ghost_x, 1, OVERMAP_SIZE),
			"y" = clamp(origin[2] + ghost_y, 1, OVERMAP_SIZE),
			"category" = "Ships",
			"kind" = "ship",
			"live" = TRUE,
			"identified" = FALSE,
			"ref" = null,
		))
	target.ew_phantom_contacts = my_ghosts
	// Force the next helm read to rebuild with the ghosts included
	target.contact_snapshot_time = 0
	target.ship_notify("Sensor returns inconsistent - multiple unresolved contacts painted on the chart.", "SENSORS", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/datum/ew_payload/sensor_ghosts/on_expire()
	var/obj/structure/overmap/ship/target = get_target()
	if(target && !QDELETED(target) && target.ew_phantom_contacts == my_ghosts)
		target.ew_phantom_contacts = null
		target.contact_snapshot_time = 0
	my_ghosts = null

/obj/item/ew_exploit/sensor_ghosts
	name = "exploit cartridge (Ghost Contacts)"
	desc = "Intrusion software that paints phantom vessels onto a target ship's sensors."
	icon_state = "datadisk1"
	payload_type = /datum/ew_payload/sensor_ghosts
	charges = 4
	max_charges = 4

// ========== SCRAMBLER (system_scramble) ==========

/datum/ew_payload/system_scramble
	id = "system_scramble"
	name = "Scrambler"
	desc = "Forces the target's interdictor offline and its cloak down, and blocks both from restarting."
	subsystem_name = "combat systems"
	tier = 2
	warmup = 8 SECONDS
	duration = 45 SECONDS
	signature_cost = 25
	/// Weakref -> list(natural cooldown end, imposed cooldown end) per interdictor
	var/list/interdictor_cooldowns
	/// Weakref to the target's cloak device, if one was jammed
	var/datum/weakref/cloak_ref
	/// world.time the cloak's recloak cooldown would have ended naturally
	var/cloak_natural_end = 0
	/// world.time our imposed recloak cooldown ends
	var/cloak_imposed_end = 0

/datum/ew_payload/system_scramble/can_apply(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker)
	if(!target)
		return "No target."
	if(!length(target.linked_interdictors) && !target.linked_cloak_device)
		return "Target has no interdiction or cloaking systems to scramble."
	return TRUE

/datum/ew_payload/system_scramble/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target)
		return
	interdictor_cooldowns = list()

	for(var/obj/machinery/ship_combat/interdictor/jammer as anything in target.linked_interdictors)
		if(QDELETED(jammer))
			continue
		if(jammer.interdiction_active || jammer.interdiction_warming_up)
			jammer.cancel_interdiction("Control system compromised")
		// Ride the machine's own recharge gate: can_interdict() refuses while
		// interdict_cooldown runs, and the console UI shows it as recharging
		var/natural_end = world.time + COOLDOWN_TIMELEFT(jammer, interdict_cooldown)
		COOLDOWN_START(jammer, interdict_cooldown, max(duration, COOLDOWN_TIMELEFT(jammer, interdict_cooldown)))
		interdictor_cooldowns[WEAKREF(jammer)] = list(natural_end, world.time + COOLDOWN_TIMELEFT(jammer, interdict_cooldown))
		do_sparks(3, FALSE, jammer)

	var/obj/machinery/ship_combat/cloak_device/cloak = target.linked_cloak_device
	if(cloak && !QDELETED(cloak))
		if(cloak.cloak_active)
			cloak.deactivate_cloak(silent = FALSE, forced = TRUE)
		// Same trick on the cloak's own recloak gate
		cloak_natural_end = world.time + COOLDOWN_TIMELEFT(cloak, recloak_cooldown)
		COOLDOWN_START(cloak, recloak_cooldown, max(duration, COOLDOWN_TIMELEFT(cloak, recloak_cooldown)))
		cloak_imposed_end = world.time + COOLDOWN_TIMELEFT(cloak, recloak_cooldown)
		cloak_ref = WEAKREF(cloak)
		do_sparks(3, FALSE, cloak)

/datum/ew_payload/system_scramble/on_expire()
	for(var/datum/weakref/jammer_ref as anything in interdictor_cooldowns)
		var/obj/machinery/ship_combat/interdictor/jammer = jammer_ref?.resolve()
		if(!jammer || QDELETED(jammer))
			continue
		var/list/ends = interdictor_cooldowns[jammer_ref]
		var/current_end = world.time + COOLDOWN_TIMELEFT(jammer, interdict_cooldown)
		// Leave any cooldown someone else extended past ours (EMP, a later payload)
		if(current_end > ends[2])
			continue
		COOLDOWN_START(jammer, interdict_cooldown, max(0, ends[1] - world.time))
	interdictor_cooldowns = null

	var/obj/machinery/ship_combat/cloak_device/cloak = cloak_ref?.resolve()
	if(cloak && !QDELETED(cloak))
		var/current_end = world.time + COOLDOWN_TIMELEFT(cloak, recloak_cooldown)
		if(current_end <= cloak_imposed_end)
			COOLDOWN_START(cloak, recloak_cooldown, max(0, cloak_natural_end - world.time))
	cloak_ref = null

/obj/item/ew_exploit/system_scramble
	name = "exploit cartridge (Scrambler)"
	desc = "Intrusion software that knocks a target ship's interdictor and cloak offline."
	icon_state = "datadisk1"
	payload_type = /datum/ew_payload/system_scramble
	charges = 4
	max_charges = 4
