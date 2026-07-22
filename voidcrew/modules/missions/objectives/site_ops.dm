/**
 * # Site Operation Objectives
 *
 * Field work inside (or defended against) a mission site: planting the quest
 * item, calibrating pylon chains, walking a survivor out, and holding a claim
 * beacon against the sector.
 */

// =========================================================================
// PLANT QUEST ITEM — the recovery family's arming step
// =========================================================================

/**
 * Spawns the mission's bound quest item inside the target when its interior
 * loads, then immediately completes so the carry-home step takes over. The
 * shell keeps watching the item (quest atom) for destruction/stranding.
 */
/datum/mission_objective/field/plant_quest
	/// The quest item type planted at the site
	var/quest_item_type = /obj/item/mission_recovery

/datum/mission_objective/field/plant_quest/spawn_field_objects(turf/spawn_turf)
	var/obj/item/mission_recovery/quest_item = new quest_item_type(spawn_turf)
	quest_item.name = mission.objective_name
	mission.bind_item(quest_item)
	mission.register_quest_atom(quest_item)
	complete()

/datum/mission_objective/field/plant_quest/get_progress_string()
	var/datum/mission_target/target = mission?.target
	if(!target)
		return "Awaiting a signal fix"
	return "Signal at ([target.target_x], [target.target_y])"

// =========================================================================
// PYLON CHAIN — calibrate N pylons, each one answered by a wave
// =========================================================================

/datum/mission_objective/field/pylon_chain
	/// Pylons to calibrate before the core prints
	var/points_total = 3
	/// Pylons calibrated so far
	var/points_done = 0
	/// zone_mobs theme path answering each calibration (set by the mission)
	var/wave_theme

/datum/mission_objective/field/pylon_chain/reset()
	. = ..()
	points_done = 0

/datum/mission_objective/field/pylon_chain/spawn_field_objects(turf/spawn_turf)
	place_pylon(spawn_turf)

/// Drops the next pylon and points the mission beacon at it
/datum/mission_objective/field/pylon_chain/proc/place_pylon(turf/spawn_turf)
	if(!spawn_turf)
		return
	var/obj/structure/mission_survey_pylon/pylon = new(spawn_turf)
	pylon.name = "survey pylon ([points_done + 1]/[points_total])"
	pylon.objective_ref = WEAKREF(src)
	mission.register_quest_atom(pylon)

/**
 * A pylon finished calibrating: the ruin answers, and the survey advances.
 * Called by the pylon structure.
 */
/datum/mission_objective/field/pylon_chain/proc/on_pylon_calibrated(obj/structure/mission_survey_pylon/pylon, mob/living/user)
	if(!active || !mission || mission.failed || mission.completed)
		return
	points_done++
	// Calibration is loud. Something heard it.
	if(wave_theme)
		new wave_theme(get_turf(pylon), list(1, 2))

	// The finished pylon stays as a breadcrumb but stops being the objective
	mission.forget_quest_atom(pylon)

	if(points_done < points_total)
		place_pylon(mission.target?.get_spawn_turf() || get_turf(pylon))
		mission.push_waypoint()
		notify_crew("Pylon [points_done]/[points_total] calibrated. Next pylon's beacon is live ([mission.gps_tag]).")
		return

	// Survey complete: the last pylon prints the core
	var/obj/item/mission_recovery/core = new(pylon.drop_location())
	core.name = "[mission.objective_name] core"
	core.desc = "A completed survey core, warm from compiling. The mission pad will accept it."
	mission.bind_item(core)
	mission.register_quest_atom(core)
	notify_crew("Survey complete. Recover the [mission.objective_name] core and return it to the mission pad.")
	complete()

/datum/mission_objective/field/pylon_chain/get_progress_string()
	if(!spawned)
		var/datum/mission_target/target = mission?.target
		return target ? "Pylons at ([target.target_x], [target.target_y])" : "Awaiting a signal fix"
	return "Calibrate pylon [points_done + 1]/[points_total]"

// =========================================================================
// ESCORT — bring the survivor back breathing
// =========================================================================

/**
 * Spawns a live survivor at the site; the mission is turn-in-able while the
 * survivor is alive next to one of the ship's mission pads. Survivor death
 * routes through the mission's quest-loss policy ("another beacon" retarget).
 */
/datum/mission_objective/field/escort
	/// The survivor mob type
	var/survivor_type = /mob/living/basic/mission_survivor
	/// The live survivor
	var/mob/living/survivor
	/// Health fraction at turn-in for the "still walking" pay bonus
	var/unharmed_threshold = 0.8
	/// Multiplier applied to mission credits when unharmed
	var/unharmed_bonus = 2

/datum/mission_objective/field/escort/deactivate()
	if(survivor)
		UnregisterSignal(survivor, COMSIG_LIVING_DEATH)
		survivor = null
	return ..()

/datum/mission_objective/field/escort/reset()
	. = ..()
	survivor = null

/datum/mission_objective/field/escort/spawn_field_objects(turf/spawn_turf)
	survivor = new survivor_type(spawn_turf)
	RegisterSignal(survivor, COMSIG_LIVING_DEATH, PROC_REF(on_survivor_death))
	mission.register_quest_atom(survivor)
	notify_crew("Survivor beacon locked ([mission.gps_tag]). They're alive - go get them.")

/datum/mission_objective/field/escort/proc/on_survivor_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!mission || mission.failed || mission.completed)
		return
	UnregisterSignal(source, COMSIG_LIVING_DEATH)
	survivor = null
	mission.handle_quest_loss("The survivor didn't make it.")

/// Whether the survivor is alive and on/beside one of the servant's pads
/datum/mission_objective/field/escort/is_satisfied()
	if(QDELETED(survivor) || survivor.stat == DEAD)
		return FALSE
	var/obj/structure/overmap/ship/ship = get_servant()
	for(var/obj/machinery/mission_pad/pad as anything in ship?.linked_mission_pads)
		if(QDELETED(pad))
			continue
		var/turf/pad_turf = get_turf(pad)
		var/turf/survivor_turf = get_turf(survivor)
		if(pad_turf && survivor_turf && pad_turf.z == survivor_turf.z && get_dist(pad_turf, survivor_turf) <= 1)
			return TRUE
	return FALSE

/datum/mission_objective/field/escort/on_turn_in_finalized(atom/reward_anchor)
	if(QDELETED(survivor))
		return
	// Still walking pays double
	if(survivor.health >= survivor.maxHealth * unharmed_threshold)
		mission.value *= unharmed_bonus
		notify_crew("Survivor recovered unharmed - fee doubled.")
	// Repatriation: they step onto the pad and ship out
	var/mob/living/leaving = survivor
	UnregisterSignal(leaving, COMSIG_LIVING_DEATH)
	survivor = null
	leaving.visible_message(span_notice("[leaving] waves goodbye and is teleported out."))
	if(istype(reward_anchor, /obj/machinery/mission_pad))
		var/obj/machinery/mission_pad/pad = reward_anchor
		pad.do_teleport_effect()
	qdel(leaving)

/datum/mission_objective/field/escort/get_progress_string()
	if(!spawned)
		var/datum/mission_target/target = mission?.target
		return target ? "Beacon at ([target.target_x], [target.target_y])" : "Awaiting a signal fix"
	if(QDELETED(survivor))
		return "Survivor lost"
	return "Bring the survivor to the mission pad alive"

// =========================================================================
// CLAIM DEFENSE — plant the beacon, hold the site, print the deed
// =========================================================================

/**
 * The prospect-stake centerpiece: a claim beacon kit is dispensed at accept;
 * deploying it (only with the ship holding at the target coordinates) files
 * the claim on Wideband - everyone hears - and starts a defend clock that
 * only runs while the ship stays on station. The beacon survives, it prints
 * the deed; the beacon dies, the contract dies with it.
 */
/datum/mission_objective/claim_defense
	/// How long the beacon must survive after deployment
	var/defend_duration = 8 MINUTES
	/// Seconds of defense remaining (set on deploy)
	var/defend_remaining = 0
	/// How far (overmap tiles) the ship may drift from the stake coordinates
	var/hold_range = 2
	/// Interval between defender waves while the clock runs
	var/wave_interval = 2 MINUTES
	/// zone_mobs theme answering the claim (set by the mission)
	var/wave_theme
	/// The kit handed over at accept
	var/obj/item/claim_beacon_kit/kit
	/// The deployed beacon
	var/obj/structure/mission_claim_beacon/beacon
	/// Whether the deed has printed (beacon survived)
	var/deed_printed = FALSE

/datum/mission_objective/claim_defense/deactivate()
	if(beacon)
		beacon.objective_ref = null
		beacon = null
	kit = null
	return ..()

/datum/mission_objective/claim_defense/activate()
	. = ..()
	defend_remaining = defend_duration / 10

/// Called by the mission at start: hand the kit over at the ship's pad
/datum/mission_objective/claim_defense/proc/dispense_kit()
	var/obj/structure/overmap/ship/ship = get_servant()
	var/turf/kit_turf
	for(var/obj/machinery/mission_pad/pad as anything in ship?.linked_mission_pads)
		if(!QDELETED(pad))
			kit_turf = get_turf(pad)
			break
	if(!kit_turf)
		mission.fail("No mission pad to dispense the claim beacon to.")
		return FALSE
	kit = new(kit_turf)
	kit.objective_ref = WEAKREF(src)
	notify_crew("Claim beacon kit delivered to your mission pad. Deploy it while holding at the marked coordinates.")
	return TRUE

/// Whether the ship is close enough to the stake coordinates to count
/datum/mission_objective/claim_defense/proc/ship_on_station()
	var/obj/structure/overmap/ship/ship = get_servant()
	var/datum/mission_target/target = mission?.target
	if(!ship || !target)
		return FALSE
	var/rel_x = ship.x
	var/rel_y = ship.y - OVERMAP_SOUTH_SIDE_COORD + 1
	return sqrt((rel_x - target.target_x) ** 2 + (rel_y - target.target_y) ** 2) <= hold_range

/// The kit was used in hand and the channel finished: raise the beacon
/datum/mission_objective/claim_defense/proc/deploy(mob/living/user, turf/where)
	if(beacon || !active)
		return
	beacon = new(where)
	beacon.objective_ref = WEAKREF(src)
	QDEL_NULL(kit)
	var/datum/mission_target/target = mission.target
	beacon.file_claim("Prospect filing: mineral-rights claim staked at grid [target.target_x], [target.target_y]. Claim matures in [round(defend_duration / (1 MINUTES))] minutes. All counterclaims settled on-site.")
	notify_crew("Claim filed on Wideband. The whole sector heard it - hold the site for [round(defend_duration / (1 MINUTES))] minutes.", type = SHIP_NOTIFY_WARNING)

/// One second of defending, ticked by the beacon's process
/datum/mission_objective/claim_defense/proc/tick_defense(seconds)
	if(deed_printed || !active || !beacon)
		return
	if(!ship_on_station())
		beacon.show_offstation_warning()
		return
	defend_remaining -= seconds
	if(defend_remaining <= 0)
		print_deed()
		return
	// Periodic company
	if(wave_theme && beacon.next_wave_at <= world.time)
		beacon.next_wave_at = world.time + wave_interval
		new wave_theme(get_turf(beacon), list(1, 2))
		notify_crew("Claim jumpers inbound on the beacon!", type = SHIP_NOTIFY_WARNING, sound = 'voidcrew/sound/notify2.ogg')

/// The clock ran out with the beacon alive: print the deed
/datum/mission_objective/claim_defense/proc/print_deed()
	if(deed_printed || QDELETED(beacon))
		return
	deed_printed = TRUE
	var/obj/item/mission_recovery/deed = new(beacon.drop_location())
	deed.name = "notarized claim deed"
	deed.desc = "A matured mineral-rights filing, printed and bonded. The mission pad will accept it."
	mission.bind_item(deed)
	mission.register_quest_atom(deed)
	beacon.retire()
	beacon = null
	notify_crew("Claim matured! Recover the deed and return it to the mission pad.")
	complete()

/// The beacon was destroyed before the claim matured
/datum/mission_objective/claim_defense/proc/on_beacon_destroyed()
	beacon = null
	if(deed_printed || !mission || mission.failed || mission.completed)
		return
	mission.fail("Claim beacon destroyed - the filing is void.")

/datum/mission_objective/claim_defense/get_progress_string()
	if(deed_printed)
		return "Deed printed"
	if(beacon)
		if(!ship_on_station())
			return "OFF STATION - claim clock paused"
		return "Defend the beacon ([round(defend_remaining / 60)]:[add_leading(num2text(round(defend_remaining) % 60), 2, "0")])"
	var/datum/mission_target/target = mission?.target
	return target ? "Deploy the beacon at ([target.target_x], [target.target_y])" : "Deploy the beacon"
