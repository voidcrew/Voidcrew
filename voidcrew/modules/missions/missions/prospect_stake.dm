/**
 * # Prospect Stake
 *
 * "Plant our claim beacon at these red-zone coordinates and keep it alive
 * for eight minutes. The filing goes out on Wideband, so expect... interest."
 *
 * The announced PvP flashpoint as a mission: a claim kit is dispensed at
 * accept; deploying it (ship holding at the marked coordinates) files the
 * claim galaxy-wide - the contested-cache broadcast pattern - and starts a
 * defend clock that only runs on station. Boarding waves answer the filing;
 * red space means anyone else can too. The beacon survives, it prints a
 * bonded deed for the pad. Objectives: [fly there] -> [deploy & defend] ->
 * [carry the deed home].
 */
/datum/mission/prospect_stake
	name = "Prospect Stake"
	weight = 6
	mission_limit = 1
	duration = 40 MINUTES
	quest_lost_policy = MISSION_QUEST_LOST_FAIL // the beacon IS the contract
	gps_tag_prefix = "CLAIM"
	// Top of the mission pay curve - it's an announced fight
	value_min = 2200
	value_max = 3000
	voucher_count = 3

	/// zone_mobs theme answering the claim
	var/wave_theme
	/// The defense objective (kit dispensing at start)
	var/datum/mission_objective/claim_defense/defense
	/// Whether this stake pays a ship-part prize crate instead of vouchers
	var/pays_ship_parts = FALSE

/datum/mission/prospect_stake/Destroy()
	defense = null
	return ..()

/datum/mission/prospect_stake/get_archetype()
	return "claim"

/datum/mission/prospect_stake/setup_target()
	var/datum/mission_target/coords/coords = new(src)
	// Yellow stakes are the on-ramp; red is the real thing
	coords.zone_weights = list(
		"[ZONE_YELLOW]" = 45,
		"[ZONE_RED]" = 55,
	)
	if(!coords.resolve())
		qdel(coords)
		return FALSE
	target = coords
	return TRUE

/datum/mission/prospect_stake/generate_details()
	objective_name = "notarized claim deed"
	wave_theme = pick_weight(MISSION_WAVE_THEMES)
	// Red-zone stakes can trade the voucher stack for a ship-part crate
	if(difficulty == MISSION_DIFFICULTY_HARD)
		voucher_count = 4
		if(prob(35))
			pays_ship_parts = TRUE
			voucher_count = 0

/datum/mission/prospect_stake/build_objectives()
	var/datum/mission_objective/goto_coords/approach = new
	approach.arrival_message = "On station. Deploy the claim beacon while holding these coordinates."
	add_objective(approach)
	defense = new
	defense.wave_theme = wave_theme
	add_objective(defense)
	add_objective(new /datum/mission_objective/deliver/bound)

/datum/mission/prospect_stake/on_mission_started()
	defense?.dispense_kit()

/datum/mission/prospect_stake/update_text()
	name = "Prospect Stake: ([target.target_x], [target.target_y])"
	desc = "File our mineral-rights claim at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		A claim beacon kit lands on your mission pad when you sign. Fly out, deploy it aboard your ship while holding at those coordinates, and keep it in one piece for [defense ? round(defense.defend_duration / (1 MINUTES)) : 8] minutes. The clock only runs while the ship holds station. \
		The filing goes out on Wideband, so [target_zone_name == ZONE_NAME_RED ? "every pirate in red space will know exactly where you are" : "the whole lane will hear it"]. Expect boarders. \
		The deed prints at the beacon once the claim matures; bring it to the mission pad. \
		Pays [pays_ship_parts ? "a bonded crate of ship-grade components" : "[voucher_count] trade vouchers"] on top of the fee."

/datum/mission/prospect_stake/waypoint_label()
	return "Prospect stake"

/datum/mission/prospect_stake/distribute_rewards(atom/reward_anchor)
	..()
	if(pays_ship_parts)
		var/turf/reward_turf = get_turf(reward_anchor)
		if(reward_turf)
			spawn_ship_part_prize(reward_turf)
			flash_reward_anchor(reward_anchor)

/**
 * # Claim Beacon Kit
 *
 * The packed beacon handed over at accept. Use in hand while the ship holds
 * at the stake coordinates; the deployment channel raises the beacon on the
 * spot you're standing.
 */
/obj/item/claim_beacon_kit
	name = "claim beacon kit"
	desc = "A folded prospecting claim beacon, bonded and pre-registered. Use it in hand while your ship holds at the contracted coordinates. Filings are public, so expect company."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "recovery_anchored"
	w_class = WEIGHT_CLASS_BULKY

	/// Weakref to the claim_defense objective this kit serves
	var/datum/weakref/objective_ref

/obj/item/claim_beacon_kit/attack_self(mob/user)
	. = ..()
	if(.)
		return
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	if(!objective?.mission || objective.mission.failed || objective.mission.completed)
		balloon_alert(user, "contract expired!")
		return TRUE
	if(!objective.active || !objective.ship_on_station())
		balloon_alert(user, "ship not holding at the stake coordinates!")
		return TRUE
	balloon_alert(user, "deploying beacon...")
	playsound(src, 'sound/items/tools/ratchet.ogg', 60, TRUE)
	if(!do_after(user, 8 SECONDS, target = user))
		balloon_alert(user, "deployment interrupted!")
		return TRUE
	if(!objective.ship_on_station())
		balloon_alert(user, "drifted off station!")
		return TRUE
	objective.deploy(user, get_turf(user))
	return TRUE

/**
 * # Claim Beacon
 *
 * The deployed stake: destructible on purpose - defending it is the mission.
 * Ticks the defend clock while the ship holds station, calls its own waves,
 * and files every beat on Wideband like the contested cache does.
 */
/obj/structure/mission_claim_beacon
	name = "prospecting claim beacon"
	desc = "A registered mineral-rights beacon, broadcasting its claim on every open channel. Keeping it in one piece is the whole job."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "survey_pylon"
	anchored = TRUE
	density = TRUE
	max_integrity = 400

	/// Weakref to the claim_defense objective driving this beacon
	var/datum/weakref/objective_ref
	/// Internal wideband transmitter (the contested-cache broadcast pattern)
	var/obj/item/radio/headset/radio
	/// world.time gate for the next defender wave
	var/next_wave_at = 0
	/// Throttle for off-station warnings
	COOLDOWN_DECLARE(offstation_warn_cooldown)

/obj/structure/mission_claim_beacon/Initialize(mapload)
	. = ..()
	radio = new(src)
	radio.subspace_transmission = TRUE
	radio.canhear_range = 0
	radio.set_listening(FALSE)
	radio.recalculateChannels()
	next_wave_at = world.time + 1 MINUTES
	START_PROCESSING(SSobj, src)

/obj/structure/mission_claim_beacon/Destroy()
	STOP_PROCESSING(SSobj, src)
	QDEL_NULL(radio)
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	objective_ref = null
	objective?.on_beacon_destroyed()
	return ..()

/obj/structure/mission_claim_beacon/process(seconds_per_tick)
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	if(!objective)
		return PROCESS_KILL
	objective.tick_defense(seconds_per_tick)

/// Galaxy-wide filing: Wideband + priority announcement, like the contested cache
/obj/structure/mission_claim_beacon/proc/file_claim(message)
	priority_announce(message, "Prospect Filing", sender_override = "Sector Claims Registry")
	radio?.talk_into(src, message, RADIO_CHANNEL_WIDEBAND)

/obj/structure/mission_claim_beacon/proc/show_offstation_warning()
	if(!COOLDOWN_FINISHED(src, offstation_warn_cooldown))
		return
	COOLDOWN_START(src, offstation_warn_cooldown, 15 SECONDS)
	balloon_alert_to_viewers("claim clock paused - off station!")
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	objective?.notify_crew("Claim beacon reports the ship off station - the clock is paused.", type = SHIP_NOTIFY_WARNING, sound = 'voidcrew/sound/notify2.ogg')

/// The claim matured: stop being a mission object, stay as scenery
/obj/structure/mission_claim_beacon/proc/retire()
	STOP_PROCESSING(SSobj, src)
	objective_ref = null
	name = "matured claim beacon"
	desc = "A prospecting beacon whose claim has matured and printed. It hums contentedly."

/obj/structure/mission_claim_beacon/examine(mob/user)
	. = ..()
	var/datum/mission_objective/claim_defense/objective = objective_ref?.resolve()
	if(objective)
		. += span_boldwarning("[objective.get_progress_string()].")
