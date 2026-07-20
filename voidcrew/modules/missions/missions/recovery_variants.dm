/**
 * # Recovery Mission Variants — Survey & Hot Extraction
 *
 * Two voucher-mission types built on the recovery pipeline (recovery.dm)
 * that ask for a VERB under pressure instead of a walk-and-grab, in the
 * spirit of the vestige trials: the objective itself is easy — doing it
 * loudly, in a ruin that answers back, is the mission.
 *
 * - SURVEY: three pylons in the ruin need calibrating, one after another.
 *   Calibration is loud; every finished pylon draws a themed, zone-scaled
 *   defender wave (see zone_mobs.dm). The last pylon prints the survey core,
 *   which is the turn-in item.
 * - HOT EXTRACTION: the objective is bolted down. Wrenching it free takes
 *   time and trips an alarm that answers in two waves. Then it's a normal
 *   carry-home — if you're still standing.
 *
 * Both inherit zone-based pay/vouchers, GPS beacons, and retargeting from
 * /datum/mission/recovery.
 */

/// How long calibrating one survey pylon takes
#define SURVEY_CALIBRATE_TIME (8 SECONDS)
/// How long unbolting the extraction objective takes
#define EXTRACTION_UNBOLT_TIME (12 SECONDS)
/// Delay before the extraction alarm's second wave
#define EXTRACTION_SECOND_WAVE_DELAY (15 SECONDS)

/// Weighted wave themes rolled per mission — who answers the noise
#define MISSION_WAVE_THEMES list(\
	/obj/effect/zone_mobs/pirate = 5,\
	/obj/effect/zone_mobs/syndicate = 4,\
	/obj/effect/zone_mobs/robot = 4,\
	/obj/effect/zone_mobs/undead = 3,\
	/obj/effect/zone_mobs/bug = 3,\
)

// =========================================================================
// SURVEY CONTRACT
// =========================================================================

/datum/mission/recovery/survey
	name = "Survey Contract"
	weight = 8
	mission_limit = 2

	/// Pylons to calibrate before the core prints
	var/points_total = 3
	/// Pylons calibrated so far
	var/points_done = 0
	/// zone_mobs theme path answering each calibration
	var/wave_theme

/datum/mission/recovery/survey/generate_objective_details()
	var/static/list/survey_subjects = list(
		"deep-field resonance survey",
		"salvage-rights assay",
		"structural decay survey",
		"anomalous emissions survey",
		"insurance write-off audit",
	)
	objective_name = pick(survey_subjects)
	wave_theme = pick_weight(MISSION_WAVE_THEMES)

/datum/mission/recovery/survey/gps_tag_prefix()
	return "SRVY"

/datum/mission/recovery/survey/update_text()
	name = "Survey Contract: [objective_name]"
	desc = "Our probes seeded [points_total] survey pylons through the signal at ([target_x], [target_y]) in the [target_zone_name]. \
		Calibrate them one after another — fair warning: calibration is loud, and something always answers — then return the finished survey core to the mission pad. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive the active pylon's beacon ([gps_tag])."

/datum/mission/recovery/survey/get_waypoint_info()
	return list("Survey: [objective_name]", target_x, target_y)

/datum/mission/recovery/survey/spawn_objective()
	if(objective_spawned || QDELETED(target_ruin))
		return
	spawn_next_pylon()

/**
 * Drops the next pylon at a fresh spot in the ruin and points the GPS at it.
 */
/datum/mission/recovery/survey/proc/spawn_next_pylon()
	var/turf/spawn_turf = target_ruin?.get_random_interior_turf() || (objective_atom && get_turf(objective_atom))
	if(!spawn_turf)
		return
	var/obj/structure/mission_survey_pylon/pylon = new(spawn_turf)
	pylon.name = "survey pylon ([points_done + 1]/[points_total])"
	pylon.mission_ref = WEAKREF(src)
	if(objective_atom && !QDELETED(objective_atom))
		UnregisterSignal(objective_atom, COMSIG_QDELETING)
	register_objective(pylon)

/**
 * A pylon finished calibrating: the ruin answers, and the survey advances.
 */
/datum/mission/recovery/survey/proc/on_pylon_calibrated(obj/structure/mission_survey_pylon/pylon, mob/living/user)
	if(failed || completed)
		return
	points_done++
	// Calibration is loud. Something heard it.
	new wave_theme(get_turf(pylon), list(1, 2))

	// The finished pylon stays as a breadcrumb but stops being the objective
	UnregisterSignal(pylon, COMSIG_QDELETING)

	if(points_done < points_total)
		spawn_next_pylon()
		push_waypoint()
		if(servant)
			servant.ship_notify("Pylon [points_done]/[points_total] calibrated. Next pylon's beacon is live ([gps_tag]).", "MISSION UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		return

	// Survey complete: the last pylon prints the core
	var/obj/item/mission_recovery/core = new(pylon.drop_location())
	core.name = "[objective_name] core"
	core.desc = "A completed survey core, warm from compiling. The mission pad will accept it."
	core.mission_ref = WEAKREF(src)
	objective_atom = core
	RegisterSignal(core, COMSIG_QDELETING, PROC_REF(on_objective_destroyed))
	capture_objective_bounds()
	push_gps_signal()
	if(servant)
		servant.ship_notify("Survey complete. Recover the [objective_name] core and return it to the mission pad.", "MISSION UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/datum/mission/recovery/survey/retarget()
	// A fresh ruin means a fresh survey
	points_done = 0
	return ..()

/datum/mission/recovery/survey/get_progress_string()
	if(!objective_spawned)
		return "Pylons at ([target_x], [target_y])"
	if(points_done >= points_total)
		return "Return the survey core to the pad"
	return "Calibrate pylon [points_done + 1]/[points_total]"

/**
 * # Survey Pylon
 *
 * The mission's field objective. Calibrating takes a channel; the mission
 * datum handles what the noise attracts.
 */
/obj/structure/mission_survey_pylon
	name = "survey pylon"
	desc = "A tripod-mounted survey unit, dropped from orbit and still waiting on a field tech. The calibration routine is not subtle."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "survey_pylon"
	anchored = TRUE
	density = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Weakref to the survey mission
	var/datum/weakref/mission_ref
	/// Whether this pylon has been calibrated already
	var/calibrated = FALSE

/obj/structure/mission_survey_pylon/examine(mob/user)
	. = ..()
	if(calibrated)
		. += span_notice("Its display reads: SURVEY SEGMENT COMPLETE.")
	else
		. += span_notice("Its display blinks: AWAITING FIELD CALIBRATION. Use an empty hand and stand by — the routine takes a while and it is <b>loud</b>.")

/obj/structure/mission_survey_pylon/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(calibrated)
		balloon_alert(user, "already calibrated")
		return TRUE
	var/datum/mission/recovery/survey/mission = mission_ref?.resolve()
	if(!mission || mission.failed || mission.completed)
		balloon_alert(user, "contract expired")
		return TRUE
	balloon_alert(user, "calibrating...")
	playsound(src, 'sound/machines/terminal/terminal_processing.ogg', 60, TRUE)
	if(!do_after(user, SURVEY_CALIBRATE_TIME, target = src))
		balloon_alert(user, "calibration interrupted!")
		return TRUE
	calibrated = TRUE
	name = "calibrated [initial(name)]"
	icon_state = "survey_pylon_calibrated"
	playsound(src, 'sound/machines/chime.ogg', 80, TRUE)
	balloon_alert(user, "calibrated")
	mission.on_pylon_calibrated(src, user)
	return TRUE

// =========================================================================
// HOT EXTRACTION CONTRACT
// =========================================================================

/datum/mission/recovery/extraction
	name = "Extraction Contract"
	weight = 8
	mission_limit = 2

	/// zone_mobs theme path answering the alarm
	var/wave_theme
	/// Whether the unbolting alarm already fired
	var/alarm_tripped = FALSE

/datum/mission/recovery/extraction/generate_objective_details()
	var/static/list/extraction_prizes = list(
		"military-grade power core",
		"sealed cargo pod",
		"prototype engine block",
		"quarantined specimen vault",
		"encrypted banking node",
	)
	objective_name = pick(extraction_prizes)
	wave_theme = pick_weight(MISSION_WAVE_THEMES)

/datum/mission/recovery/extraction/gps_tag_prefix()
	return "XTRC"

/datum/mission/recovery/extraction/update_text()
	name = "Extraction Contract: [objective_name]"
	desc = "A [objective_name] is bolted down inside the signal at ([target_x], [target_y]) in the [target_zone_name]. \
		Wrenching it free takes time and WILL trip whatever's watching the site — plan for company, then haul it to the mission pad. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive the cargo's beacon ([gps_tag])."

/datum/mission/recovery/extraction/get_waypoint_info()
	return list("Extraction: [objective_name]", target_x, target_y)

/datum/mission/recovery/extraction/spawn_objective()
	if(objective_spawned || QDELETED(target_ruin))
		return
	var/turf/spawn_turf = target_ruin.get_random_interior_turf() || target_ruin.ruin_bottom_left
	if(!spawn_turf)
		return
	var/obj/item/mission_recovery/anchored/cargo = new(spawn_turf)
	cargo.name = objective_name
	cargo.mission_ref = WEAKREF(src)
	register_objective(cargo)

/datum/mission/recovery/extraction/retarget()
	alarm_tripped = FALSE
	return ..()

/**
 * First wrench on the bolts: the site answers in two waves.
 */
/datum/mission/recovery/extraction/proc/trigger_extraction_alarm(obj/item/mission_recovery/anchored/cargo)
	if(alarm_tripped || failed || completed)
		return
	alarm_tripped = TRUE
	var/turf/site = get_turf(cargo)
	new wave_theme(site, list(1, 2))
	addtimer(CALLBACK(src, PROC_REF(second_wave), get_area(site), site), EXTRACTION_SECOND_WAVE_DELAY)
	if(servant)
		servant.ship_notify("[name]: site security tripped. Expect resistance in waves.", "MISSION UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)

/datum/mission/recovery/extraction/proc/second_wave(area/site_area, turf/site)
	if(failed || completed || !site)
		return
	new wave_theme(site, list(1, 2))

/datum/mission/recovery/extraction/get_progress_string()
	if(!objective_spawned)
		return "Cargo at ([target_x], [target_y])"
	var/obj/item/mission_recovery/anchored/cargo = objective_atom
	if(istype(cargo) && cargo.anchored)
		return "Unbolt the [objective_name]"
	return "Return the [objective_name] to the pad"

/**
 * # Anchored Recovery Cargo
 *
 * The extraction objective: a mission_recovery item that starts bolted to
 * the deck. Unbolting is a channel that trips the mission's alarm.
 */
/obj/item/mission_recovery/anchored
	desc = "Flagged for recovery under a standing contract — and bolted to the deck. Freeing it will take a minute, and it won't be quiet."
	icon_state = "recovery_anchored"
	anchored = TRUE
	w_class = WEIGHT_CLASS_BULKY

/obj/item/mission_recovery/anchored/examine(mob/user)
	. = ..()
	if(anchored)
		. += span_warning("It is bolted down. Use an empty hand to start wrenching it free.")

/obj/item/mission_recovery/anchored/attack_hand(mob/living/user, list/modifiers)
	if(!anchored)
		return ..()
	var/datum/mission/recovery/extraction/mission = mission_ref?.resolve()
	balloon_alert(user, "wrenching it free...")
	playsound(src, 'sound/items/tools/ratchet.ogg', 60, TRUE)
	mission?.trigger_extraction_alarm(src)
	if(!do_after(user, EXTRACTION_UNBOLT_TIME, target = src))
		balloon_alert(user, "still bolted!")
		return TRUE
	anchored = FALSE
	balloon_alert(user, "wrenched free")
	playsound(src, 'sound/machines/click.ogg', 60, TRUE)
	return TRUE

#undef SURVEY_CALIBRATE_TIME
#undef EXTRACTION_UNBOLT_TIME
#undef EXTRACTION_SECOND_WAVE_DELAY
#undef MISSION_WAVE_THEMES
