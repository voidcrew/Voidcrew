/**
 * # Recovery Mission Variants: Survey & Hot Extraction
 *
 * Two voucher-mission types on the recovery pipeline that ask for a VERB
 * under pressure instead of a walk-and-grab:
 *
 * - SURVEY: three pylons in the ruin need calibrating, one after another.
 *   Calibration is loud; every finished pylon draws a themed, zone-scaled
 *   defender wave (see zone_mobs.dm). The last pylon prints the survey core,
 *   which is the turn-in item. Objectives: [pylon chain] -> [carry it home].
 * - HOT EXTRACTION: the objective is bolted down. Wrenching it free takes
 *   time and trips an alarm that answers in two waves. Then it's a normal
 *   carry-home. Objectives: [plant anchored quest] -> [carry it home].
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

// =========================================================================
// SURVEY CONTRACT
// =========================================================================

/datum/mission/recovery/survey
	name = "Survey Contract"
	value_min = 550
	value_max = 750
	guarded_prize_family = "waves"
	weight = 8
	mission_limit = 2
	gps_tag_prefix = "SRVY"

	/// zone_mobs theme path answering each calibration
	var/wave_theme
	/// The pylon chain, for progress-aware text
	var/datum/mission_objective/field/pylon_chain/chain

/datum/mission/recovery/survey/Destroy()
	chain = null
	return ..()

/datum/mission/recovery/survey/generate_details()
	var/static/list/survey_subjects = list(
		"deep-field resonance survey",
		"salvage-rights assay",
		"structural decay survey",
		"anomalous emissions survey",
		"insurance write-off audit",
	)
	objective_name = pick(survey_subjects)
	wave_theme = pick_weight(MISSION_WAVE_THEMES)

/datum/mission/recovery/survey/build_objectives()
	chain = new
	chain.wave_theme = wave_theme
	add_objective(chain)
	add_objective(new /datum/mission_objective/deliver/bound/survey_core)

/datum/mission/recovery/survey/update_text()
	name = "Survey Contract: [objective_name]"
	desc = "Survey requested at ([target.target_x], [target.target_y]) in the [target_zone_name]: [objective_name]."

/datum/mission/recovery/survey/waypoint_label()
	return "Survey: [objective_name]"

/**
 * # Survey Pylon
 *
 * The mission's field objective. Calibrating takes a channel; the objective
 * datum handles what the noise attracts.
 */
/obj/structure/mission_survey_pylon
	name = "survey pylon"
	desc = "A tripod-mounted survey unit, dropped from orbit."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "survey_pylon"
	anchored = TRUE
	density = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Weakref to the pylon-chain objective driving this pylon
	var/datum/weakref/objective_ref
	/// Whether this pylon has been calibrated already
	var/calibrated = FALSE

/obj/structure/mission_survey_pylon/examine(mob/user)
	. = ..()
	if(calibrated)
		. += span_notice("Its display reads: SURVEY SEGMENT COMPLETE.")
	else
		. += span_notice("Its display blinks: AWAITING FIELD CALIBRATION.")

/obj/structure/mission_survey_pylon/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(calibrated)
		balloon_alert(user, "already calibrated")
		return TRUE
	var/datum/mission_objective/field/pylon_chain/objective = objective_ref?.resolve()
	if(!objective?.active || !objective.mission || objective.mission.failed || objective.mission.completed)
		balloon_alert(user, "contract expired")
		return TRUE
	balloon_alert(user, "calibrating...")
	playsound(src, 'sound/machines/terminal/terminal_processing.ogg', 60, TRUE)
	if(!do_after(user, SURVEY_CALIBRATE_TIME, target = src))
		balloon_alert(user, "calibration interrupted!")
		return TRUE
	if(calibrated)
		balloon_alert(user, "already calibrated")
		return TRUE
	objective = objective_ref?.resolve()
	if(!objective?.active || !objective.mission || objective.mission.failed || objective.mission.completed)
		balloon_alert(user, "contract expired")
		return TRUE
	calibrated = TRUE
	name = "calibrated [initial(name)]"
	icon_state = "survey_pylon_calibrated"
	playsound(src, 'sound/machines/chime.ogg', 80, TRUE)
	balloon_alert(user, "calibrated")
	objective.on_pylon_calibrated(src, user)
	return TRUE

// =========================================================================
// HOT EXTRACTION CONTRACT
// =========================================================================

/datum/mission/recovery/extraction
	name = "Extraction Contract"
	value_min = 500
	value_max = 700
	guarded_prize_family = "waves"
	weight = 8
	mission_limit = 2
	gps_tag_prefix = "XTRC"

	/// zone_mobs theme path answering the alarm
	var/wave_theme
	/// Whether the unbolting alarm already fired
	var/alarm_tripped = FALSE
	/// Timer id for the alarm's pending second wave
	var/second_wave_timer

/datum/mission/recovery/extraction/Destroy()
	deltimer(second_wave_timer)
	second_wave_timer = null
	return ..()

/datum/mission/recovery/extraction/generate_details()
	var/static/list/extraction_prizes = list(
		"military-grade power core",
		"sealed cargo pod",
		"prototype engine block",
		"quarantined specimen vault",
		"encrypted banking node",
	)
	objective_name = pick(extraction_prizes)
	wave_theme = pick_weight(MISSION_WAVE_THEMES)

/datum/mission/recovery/extraction/build_objectives()
	var/datum/mission_objective/field/plant_quest/plant = new
	plant.quest_item_type = /obj/item/mission_recovery/anchored
	add_objective(plant)
	add_objective(new /datum/mission_objective/deliver/bound)

/datum/mission/recovery/extraction/retarget(reason)
	deltimer(second_wave_timer)
	second_wave_timer = null
	alarm_tripped = FALSE
	return ..()

/datum/mission/recovery/extraction/update_text()
	name = "Extraction Contract: [objective_name]"
	desc = "Recover the [objective_name] from ([target.target_x], [target.target_y]) in the [target_zone_name]."

/datum/mission/recovery/extraction/waypoint_label()
	return "Extraction: [objective_name]"

/**
 * The bolts come free: the site answers in two waves.
 */
/datum/mission/recovery/extraction/proc/trigger_extraction_alarm(obj/item/mission_recovery/anchored/cargo)
	if(alarm_tripped || failed || completed)
		return
	alarm_tripped = TRUE
	var/turf/site = get_turf(cargo)
	new wave_theme(site, list(1, 2))
	second_wave_timer = addtimer(CALLBACK(src, PROC_REF(second_wave), site), EXTRACTION_SECOND_WAVE_DELAY, TIMER_STOPPABLE)
	servant?.ship_notify("[name]: site security alarm triggered.", "MISSION UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)

/datum/mission/recovery/extraction/proc/second_wave(turf/site)
	second_wave_timer = null
	if(failed || completed || !site)
		return
	new wave_theme(site, list(1, 2))

/**
 * # Anchored Recovery Cargo
 *
 * The extraction objective: a mission_recovery item that starts bolted to
 * the deck. Unbolting is a channel that trips the mission's alarm.
 */
/obj/item/mission_recovery/anchored
	desc = "Contracted salvage, bolted to the deck."
	icon_state = "recovery_anchored"
	anchored = TRUE
	w_class = WEIGHT_CLASS_BULKY

/obj/item/mission_recovery/anchored/examine(mob/user)
	. = ..()
	if(anchored)
		. += span_warning("It is bolted down.")

/obj/item/mission_recovery/anchored/attack_hand(mob/living/user, list/modifiers)
	if(!anchored)
		return ..()
	balloon_alert(user, "wrenching it free...")
	playsound(src, 'sound/items/tools/ratchet.ogg', 60, TRUE)
	if(!do_after(user, EXTRACTION_UNBOLT_TIME, target = src))
		balloon_alert(user, "still bolted!")
		return TRUE
	if(!anchored)
		balloon_alert(user, "already free")
		return TRUE
	anchored = FALSE
	balloon_alert(user, "wrenched free")
	playsound(src, 'sound/machines/click.ogg', 60, TRUE)
	var/datum/mission/recovery/extraction/mission = mission_ref?.resolve()
	if(istype(mission))
		mission.trigger_extraction_alarm(src)
	return TRUE

#undef SURVEY_CALIBRATE_TIME
#undef EXTRACTION_UNBOLT_TIME
#undef EXTRACTION_SECOND_WAVE_DELAY
