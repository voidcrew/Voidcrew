/**
 * # Drug lab session
 *
 * The authoritative state of one cook: which ingredients are banked, which
 * stage the batch is at, and every station's attempts and scores. Owned by the
 * mission (created in generate_details, qdel'd with it), so the batch survives
 * lab machine deletion, the machines are stateless TGUI views that the cook
 * objective points at this datum whenever the ruin interior loads.
 *
 * The mixer minigame is SERVER-AUTHORITATIVE: every hopper press is a ui_act
 * round trip checked against the session's own cursor. The catalyst and
 * crystallizer games are CLIENT-RUN, SERVER-VALIDATED: act() latency makes
 * per-input checks impossible for real-time games, so the client plays the
 * chart locally and reports totals, and the server rebuilds the deterministic
 * chart and rejects implausible reports (bad counts, finishes faster than the
 * chart could physically play out, stale/replayed nonces).
 */
/datum/drug_lab_session
	/// The drug run that owns this cook (nulled by the mission on Destroy)
	var/datum/mission/drug_run/mission
	/// DRUG_LAB_STAGE_* the batch is currently at
	var/stage = DRUG_LAB_STAGE_LOADING
	/// Ingredient typepath -> TRUE once fed into the mixer's hoppers
	var/list/banked = list()
	/// Locked/best score per station (indexed by DRUG_STATION_*)
	var/list/scores = list(0, 0, 0)
	/// Attempts used per station (indexed by DRUG_STATION_*)
	var/list/attempts = list(0, 0, 0)
	/// Weakrefs of the live lab machines viewing this session (pruned lazily)
	var/list/machine_refs = list()

	// --- Live minigame state (one attempt at a time; the stage machine means
	// --- only one station can ever have a game in play) ---
	/// Whether any station's attempt is currently in play
	var/game_active = FALSE

	// --- Catalyst/crystallizer real-time game state (client-run, validated) ---
	/// Single-use token of the live real-time attempt; nulled on consumption
	/// so a stale or replayed finish report can never land
	var/game_nonce
	/// Monotonic counter folded into every nonce (uniqueness guarantee)
	var/nonce_sequence = 0
	/// world.time (DECISECONDS) when the live real-time attempt started
	var/game_started_at = 0
	/// The live catalyst attempt's authoritative chart (null outside attempts)
	var/list/catalyst_chart
	/// The live crystallizer attempt's authoritative spawn table
	var/list/crystallizer_table
	/// A finished catalyst/crystallizer attempt awaits Commit/Retry
	var/game_awaiting_choice = FALSE
	/// Capped score of the station's most recently finished real-time attempt
	var/game_attempt_score = 0
	/// Whether that attempt botched (scored under the hazard floor)
	var/game_botched = FALSE
	/// The live attempt is a retry taken right after a botch, hazards bite harder
	var/game_retry_harsher = FALSE
	/// Current round of the active attempt, 1..DRUG_MIXER_ROUNDS
	var/mixer_round = 0
	/// The current round's hopper order (list of 1..DRUG_MIXER_HOPPER_COUNT)
	var/list/mixer_sequence
	/// How many presses of the current sequence have been matched
	var/mixer_cursor = 0
	/// Rounds fully cleared this attempt
	var/mixer_rounds_completed = 0
	/// Bumped every time a fresh sequence is issued, so clients know to replay the flash phase
	var/mixer_sequence_id = 0
	/// A finished attempt is waiting on the player's Commit/Retry choice
	var/mixer_awaiting_choice = FALSE
	/// Capped score of the most recently finished attempt
	var/mixer_attempt_score = 0
	/// Whether the last finished attempt botched (scored under the hazard floor)
	var/mixer_botched = FALSE

/// Rounds per mixer attempt (sequence lengths 4..8 via build_mixer_sequence)
#define DRUG_MIXER_ROUNDS 5
/// Score awarded per cleared mixer round
#define DRUG_MIXER_ROUND_SCORE 20
/// Countdown the real-time game clients render before the chart's t=0, in ms
#define DRUG_GAME_LEAD_IN_MS 3000
/// Wall-clock grace past a chart's full span before a live real-time attempt
/// counts as abandoned (window closed mid-run) and can be reclaimed
#define DRUG_GAME_ABANDON_GRACE (30 SECONDS)
/// Points per PERFECT catalyst note
#define DRUG_CATALYST_PERFECT_POINTS 100
/// Points per GOOD catalyst note
#define DRUG_CATALYST_GOOD_POINTS 60
/// Score docked per tainted crystal caught at the crystallizer
#define DRUG_CRYSTALLIZER_TAINT_PENALTY 10

/datum/drug_lab_session/New(datum/mission/drug_run/mission)
	..()
	src.mission = mission

/datum/drug_lab_session/Destroy()
	mission = null
	mixer_sequence = null
	catalyst_chart = null
	crystallizer_table = null
	machine_refs.Cut()
	return ..()

// =========================================================================
// MACHINE PLUMBING: stateless views registering with the state
// =========================================================================

/// Tracks a live lab machine so mutations can push its UI (wire_lab calls this)
/datum/drug_lab_session/proc/register_machine(obj/machinery/drug_lab/machine)
	if(QDELETED(machine))
		return
	machine_refs |= WEAKREF(machine)

/// Drops a machine (its Destroy calls this; stale weakrefs also prune on push)
/datum/drug_lab_session/proc/unregister_machine(obj/machinery/drug_lab/machine)
	for(var/datum/weakref/ref as anything in machine_refs)
		if(ref.resolve() == machine)
			machine_refs -= ref
			return

/// Pushes fresh ui_data and icon state to every live lab machine
/datum/drug_lab_session/proc/push_ui_updates()
	// Iterate a copy: stale refs get pruned from the real list mid-walk
	for(var/datum/weakref/ref as anything in machine_refs.Copy())
		var/obj/machinery/drug_lab/machine = ref.resolve()
		if(QDELETED(machine))
			machine_refs -= ref
			continue
		machine.update_appearance()
		SStgui.update_uis(machine)

/// The live machine of one station, if it's loaded right now (hazard and
/// product delivery both key off this)
/datum/drug_lab_session/proc/get_station_machine(station)
	for(var/datum/weakref/ref as anything in machine_refs.Copy())
		var/obj/machinery/drug_lab/machine = ref.resolve()
		if(QDELETED(machine))
			machine_refs -= ref
			continue
		if(machine.station_index == station)
			return machine
	return null

// =========================================================================
// LOADING: bank the shopping list into the hoppers
// =========================================================================

/**
 * Feeds one field-harvested ingredient into the batch. Only types on the
 * recipe that aren't already banked are accepted; the item is consumed. When
 * all three are in, the batch advances to the mixer stage.
 */
/datum/drug_lab_session/proc/bank_ingredient(obj/item/drug_ingredient/item, mob/user)
	if(stage != DRUG_LAB_STAGE_LOADING)
		item.balloon_alert(user, "hoppers already sealed!")
		return FALSE
	if(!mission?.recipe)
		item.balloon_alert(user, "no formula loaded!")
		return FALSE
	var/wanted = FALSE
	for(var/list/entry in mission.recipe.ingredients)
		if(entry["type"] == item.type)
			wanted = TRUE
			break
	if(!wanted)
		item.balloon_alert(user, "not on the formula!")
		return FALSE
	if(banked[item.type])
		item.balloon_alert(user, "already banked!")
		return FALSE
	var/item_name = item.name
	banked[item.type] = TRUE
	qdel(item)
	user?.balloon_alert(user, "[item_name] banked ([length(banked)]/3)")
	playsound(get_station_machine(DRUG_STATION_MIXER) || user, 'sound/machines/click.ogg', 40, TRUE)
	if(length(banked) >= length(mission.recipe.ingredients))
		stage = DRUG_LAB_STAGE_MIXER
		mission.servant?.ship_notify("All precursors banked. The mixer is live. Run the hopper sequence.", "DRUG RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 25)
	push_ui_updates()
	return TRUE

// =========================================================================
// MIXER MINIGAME: server-side Simon-says over the hoppers
// =========================================================================

/// Starts (or retries) a mixer attempt: fresh round 1 sequence, cursor zeroed
/datum/drug_lab_session/proc/mixer_start_attempt(mob/user)
	if(stage != DRUG_LAB_STAGE_MIXER || game_active)
		return
	if(attempts[DRUG_STATION_MIXER] >= DRUG_STATION_ATTEMPTS)
		return
	if(!mission?.recipe)
		return
	attempts[DRUG_STATION_MIXER]++
	mixer_awaiting_choice = FALSE
	mixer_botched = FALSE
	mixer_round = 1
	mixer_rounds_completed = 0
	mixer_cursor = 0
	mixer_sequence = mission.recipe.build_mixer_sequence(mixer_round)
	mixer_sequence_id++
	game_active = TRUE
	push_ui_updates()

/**
 * One hopper press, checked against the server-side cursor. Correct presses
 * advance the round; a full round issues the next sequence (or finishes the
 * attempt after round DRUG_MIXER_ROUNDS); any wrong press ends the attempt
 * immediately at rounds_completed x DRUG_MIXER_ROUND_SCORE.
 */
/datum/drug_lab_session/proc/mixer_press(index, mob/user)
	if(!game_active || !islist(mixer_sequence))
		return
	index = round(text2num("[index]"))
	if(!index || index < 1 || index > DRUG_MIXER_HOPPER_COUNT)
		return
	if(index != mixer_sequence[mixer_cursor + 1])
		mixer_finish_attempt(user)
		return
	mixer_cursor++
	if(mixer_cursor < length(mixer_sequence))
		push_ui_updates()
		return
	// Round cleared
	mixer_rounds_completed++
	if(mixer_round >= DRUG_MIXER_ROUNDS)
		mixer_finish_attempt(user)
		return
	mixer_round++
	mixer_cursor = 0
	mixer_sequence = mission.recipe.build_mixer_sequence(mixer_round)
	mixer_sequence_id++
	push_ui_updates()

/**
 * Ends the live attempt: score is rounds_completed x DRUG_MIXER_ROUND_SCORE
 * capped by this attempt number's ceiling; the station keeps its best. Botches
 * (under DRUG_HAZARD_BOTCH_SCORE) vent a hazard at the mixer machine. With
 * attempts left the player chooses Commit/Retry; out of attempts, it locks in.
 */
/datum/drug_lab_session/proc/mixer_finish_attempt(mob/user)
	game_active = FALSE
	mixer_sequence = null
	var/static/list/attempt_caps = DRUG_ATTEMPT_MAX_SCORES
	var/cap = attempt_caps[min(attempts[DRUG_STATION_MIXER], length(attempt_caps))]
	mixer_attempt_score = min(mixer_rounds_completed * DRUG_MIXER_ROUND_SCORE, cap)
	scores[DRUG_STATION_MIXER] = max(scores[DRUG_STATION_MIXER], mixer_attempt_score)
	mixer_botched = mixer_attempt_score < DRUG_HAZARD_BOTCH_SCORE
	if(mixer_botched)
		var/obj/machinery/drug_lab/mixer/machine = get_station_machine(DRUG_STATION_MIXER)
		if(istype(machine))
			machine.run_hazard(user)
	if(attempts[DRUG_STATION_MIXER] >= DRUG_STATION_ATTEMPTS)
		// Out of attempts: the score locks in without a choice
		mixer_awaiting_choice = FALSE
		commit_station(DRUG_STATION_MIXER, scores[DRUG_STATION_MIXER])
		return
	mixer_awaiting_choice = TRUE
	push_ui_updates()

/// The player accepted a finished attempt's result: lock the mixer in
/datum/drug_lab_session/proc/mixer_commit(mob/user)
	if(stage != DRUG_LAB_STAGE_MIXER || game_active || !mixer_awaiting_choice)
		return
	mixer_awaiting_choice = FALSE
	commit_station(DRUG_STATION_MIXER, scores[DRUG_STATION_MIXER])

// =========================================================================
// CATALYST & CRYSTALLIZER: client-run real-time games, server-validated
// =========================================================================

/**
 * Starts (or retries) a catalyst attempt: rebuilds the deterministic chart,
 * rolls a fresh single-use nonce and stamps the wall clock. The client runs
 * the rhythm game locally against the pushed chart and reports totals via
 * catalyst_finish().
 */
/datum/drug_lab_session/proc/catalyst_start_attempt(mob/user)
	if(stage != DRUG_LAB_STAGE_CATALYST || !mission?.recipe)
		return
	if(game_active)
		if(!reclaim_abandoned_game(user))
			return
		if(stage != DRUG_LAB_STAGE_CATALYST) // the reclaim spent the last attempt and locked the station in
			return
	if(attempts[DRUG_STATION_CATALYST] >= DRUG_STATION_ATTEMPTS)
		return
	attempts[DRUG_STATION_CATALYST]++
	game_retry_harsher = game_awaiting_choice && game_botched
	game_awaiting_choice = FALSE
	game_botched = FALSE
	catalyst_chart = mission.recipe.build_catalyst_chart()
	nonce_sequence++
	game_nonce = "[world.time]-[nonce_sequence]"
	game_started_at = world.time
	game_active = TRUE
	push_ui_updates()

/**
 * The catalyst client reports its finished run. The nonce must match the live
 * attempt (single-use, consumed here); the totals are validated against the
 * authoritative chart, and an implausible report simply scores 0, flowing
 * through the same finish path (cheaters get the botch hazard for free).
 */
/datum/drug_lab_session/proc/catalyst_finish(nonce, perfects, goods, misses, mob/user)
	if(stage != DRUG_LAB_STAGE_CATALYST || !game_active || !islist(catalyst_chart))
		return
	if(isnull(game_nonce) || "[nonce]" != game_nonce)
		return
	var/score = validate_catalyst_result(catalyst_chart, text2num("[perfects]"), text2num("[goods]"), text2num("[misses]"), game_started_at)
	finish_realtime_attempt(DRUG_STATION_CATALYST, max(score, 0), user)

/// The player accepted a finished catalyst attempt: lock the column in
/datum/drug_lab_session/proc/catalyst_commit(mob/user)
	if(stage != DRUG_LAB_STAGE_CATALYST || game_active || !game_awaiting_choice)
		return
	game_awaiting_choice = FALSE
	commit_station(DRUG_STATION_CATALYST, scores[DRUG_STATION_CATALYST])

/// Crystallizer twin of catalyst_start_attempt(): fresh spawn table + nonce
/datum/drug_lab_session/proc/crystallizer_start_attempt(mob/user)
	if(stage != DRUG_LAB_STAGE_CRYSTALLIZER || !mission?.recipe)
		return
	if(game_active)
		if(!reclaim_abandoned_game(user))
			return
		if(stage != DRUG_LAB_STAGE_CRYSTALLIZER)
			return
	if(attempts[DRUG_STATION_CRYSTALLIZER] >= DRUG_STATION_ATTEMPTS)
		return
	attempts[DRUG_STATION_CRYSTALLIZER]++
	game_retry_harsher = game_awaiting_choice && game_botched
	game_awaiting_choice = FALSE
	game_botched = FALSE
	crystallizer_table = mission.recipe.build_crystallizer_table()
	nonce_sequence++
	game_nonce = "[world.time]-[nonce_sequence]"
	game_started_at = world.time
	game_active = TRUE
	push_ui_updates()

/// Crystallizer twin of catalyst_finish(): validate the catch totals
/datum/drug_lab_session/proc/crystallizer_finish(nonce, caught_pure, caught_tainted, missed_pure, mob/user)
	if(stage != DRUG_LAB_STAGE_CRYSTALLIZER || !game_active || !islist(crystallizer_table))
		return
	if(isnull(game_nonce) || "[nonce]" != game_nonce)
		return
	var/score = validate_crystallizer_result(crystallizer_table, text2num("[caught_pure]"), text2num("[caught_tainted]"), text2num("[missed_pure]"), game_started_at)
	finish_realtime_attempt(DRUG_STATION_CRYSTALLIZER, max(score, 0), user)

/// The player accepted a finished crystallizer attempt: lock the chamber in
/datum/drug_lab_session/proc/crystallizer_commit(mob/user)
	if(stage != DRUG_LAB_STAGE_CRYSTALLIZER || game_active || !game_awaiting_choice)
		return
	game_awaiting_choice = FALSE
	commit_station(DRUG_STATION_CRYSTALLIZER, scores[DRUG_STATION_CRYSTALLIZER])

/**
 * Shared tail of both real-time games: cap the validated score by the attempt
 * number's ceiling, keep the station's best, vent the machine's hazard on a
 * botch, then either lock in (attempts spent) or offer Commit/Retry, the
 * mixer's exact flow. `deliver_hazard` FALSE skips the fallout (abandoned-game
 * reclaims: nobody is standing there to deserve it).
 */
/datum/drug_lab_session/proc/finish_realtime_attempt(station, raw_score, mob/user, deliver_hazard = TRUE)
	game_active = FALSE
	game_nonce = null
	catalyst_chart = null
	crystallizer_table = null
	var/static/list/attempt_caps = DRUG_ATTEMPT_MAX_SCORES
	var/cap = attempt_caps[min(attempts[station], length(attempt_caps))]
	game_attempt_score = clamp(raw_score, 0, cap)
	scores[station] = max(scores[station], game_attempt_score)
	game_botched = game_attempt_score < DRUG_HAZARD_BOTCH_SCORE
	if(game_botched && deliver_hazard)
		var/obj/machinery/drug_lab/machine = get_station_machine(station)
		machine?.run_botch_hazard(user, game_retry_harsher)
	game_retry_harsher = FALSE
	if(attempts[station] >= DRUG_STATION_ATTEMPTS)
		// Out of attempts: the score locks in without a choice
		game_awaiting_choice = FALSE
		commit_station(station, scores[station])
		return
	game_awaiting_choice = TRUE
	push_ui_updates()

/**
 * A live client-run attempt whose window died mid-run never sends a finish,
 * which would wedge the station forever. When a fresh start arrives past the
 * whole chart span plus DRUG_GAME_ABANDON_GRACE, the abandoned attempt
 * finalizes at 0 (its slot was already spent; no hazard, nobody owns the
 * botch) and the station unblocks. Returns TRUE when a stale game was cleared.
 */
/datum/drug_lab_session/proc/reclaim_abandoned_game(mob/user)
	var/list/live_chart = catalyst_chart || crystallizer_table
	if(!islist(live_chart) || !length(live_chart))
		// A live game with no chart is the mixer's, server-stepped, never stale
		return FALSE
	var/list/last_entry = live_chart[length(live_chart)]
	var/duration_ds = (last_entry["t"] + DRUG_GAME_LEAD_IN_MS) / 100
	if(world.time - game_started_at < duration_ds + DRUG_GAME_ABANDON_GRACE)
		return FALSE
	var/station = islist(catalyst_chart) ? DRUG_STATION_CATALYST : DRUG_STATION_CRYSTALLIZER
	finish_realtime_attempt(station, 0, user, deliver_hazard = FALSE)
	return TRUE

// =========================================================================
// RESULT VALIDATORS: pure procs, no session state (unit-testable directly)
// =========================================================================

/**
 * PURE validation of a client-reported catalyst run against the authoritative
 * chart. Returns the 0-100 score, or -1 when the report is implausible:
 * malformed/negative/non-integer counts, totals not matching the chart, or a
 * finish arriving faster than the chart could physically play out.
 * `started_at_ds` is world.time DECISECONDS at attempt start; chart times are
 * MILLISECONDS (hence the /100 conversion).
 */
/proc/validate_catalyst_result(list/chart, perfects, goods, misses, started_at_ds)
	if(!islist(chart) || !length(chart))
		return -1
	if(!isnum(perfects) || !isnum(goods) || !isnum(misses))
		return -1
	if(perfects != round(perfects) || goods != round(goods) || misses != round(misses))
		return -1
	if(perfects < 0 || goods < 0 || misses < 0)
		return -1
	if(perfects + goods + misses != length(chart))
		return -1
	var/list/last_note = chart[length(chart)]
	var/duration_ds = (last_note["t"] + DRUG_GAME_LEAD_IN_MS) / 100
	if(world.time - started_at_ds < duration_ds)
		return -1
	var/score = round((perfects * DRUG_CATALYST_PERFECT_POINTS + goods * DRUG_CATALYST_GOOD_POINTS) / length(chart))
	return clamp(score, 0, 100)

/**
 * PURE validation of a client-reported crystallizer run against the
 * authoritative spawn table. Same contract as validate_catalyst_result():
 * 0-100 score or -1. Every pure crystal must be accounted for (caught or
 * missed); tainted catches can't exceed the table's tainted count.
 */
/proc/validate_crystallizer_result(list/spawn_table, caught_pure, caught_tainted, missed_pure, started_at_ds)
	if(!islist(spawn_table) || !length(spawn_table))
		return -1
	if(!isnum(caught_pure) || !isnum(caught_tainted) || !isnum(missed_pure))
		return -1
	if(caught_pure != round(caught_pure) || caught_tainted != round(caught_tainted) || missed_pure != round(missed_pure))
		return -1
	if(caught_pure < 0 || caught_tainted < 0 || missed_pure < 0)
		return -1
	var/pure_count = 0
	var/tainted_count = 0
	for(var/list/entry in spawn_table)
		if(entry["tainted"])
			tainted_count++
		else
			pure_count++
	if(!pure_count)
		return -1
	if(caught_pure + missed_pure != pure_count)
		return -1
	if(caught_tainted > tainted_count)
		return -1
	var/list/last_entry = spawn_table[length(spawn_table)]
	var/duration_ds = (last_entry["t"] + DRUG_GAME_LEAD_IN_MS) / 100
	if(world.time - started_at_ds < duration_ds)
		return -1
	var/score = round(caught_pure * 100 / pure_count) - caught_tainted * DRUG_CRYSTALLIZER_TAINT_PENALTY
	return clamp(score, 0, 100)

// =========================================================================
// STAGE PROGRESSION
// =========================================================================

/// Locks a station's score in and advances the batch to the next stage
/datum/drug_lab_session/proc/commit_station(station, score)
	scores[station] = max(scores[station], score)
	mission?.servant?.ship_notify("Station [station]/3 locked in at [scores[station]]/100.", "DRUG RUN", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 25)
	advance_stage()

/// MIXER -> CATALYST -> CRYSTALLIZER -> DONE; DONE scores the batch's purity
/datum/drug_lab_session/proc/advance_stage()
	switch(stage)
		if(DRUG_LAB_STAGE_MIXER)
			stage = DRUG_LAB_STAGE_CATALYST
		if(DRUG_LAB_STAGE_CATALYST)
			stage = DRUG_LAB_STAGE_CRYSTALLIZER
		if(DRUG_LAB_STAGE_CRYSTALLIZER)
			stage = DRUG_LAB_STAGE_DONE
			finish_cook()
	push_ui_updates()

/// The whole cook is done: judge purity off the combined score, tell the mission
/datum/drug_lab_session/proc/finish_cook()
	var/total = scores[DRUG_STATION_MIXER] + scores[DRUG_STATION_CATALYST] + scores[DRUG_STATION_CRYSTALLIZER]
	var/tier = DRUG_PURITY_STREET
	if(total >= DRUG_SCORE_PRIMO_THRESHOLD)
		tier = DRUG_PURITY_PRIMO
	else if(total >= DRUG_SCORE_PURE_THRESHOLD)
		tier = DRUG_PURITY_PURE
	if(!mission)
		return
	mission.purity_tier = tier
	mission.on_cook_finished(get_product_drop_turf())

/**
 * An open tile beside the live crystallizer machine, where the finished
 * product prints. Null when the lab isn't loaded right now (the machine
 * weakrefs are dead), in which case the mission falls back to the pad.
 */
/datum/drug_lab_session/proc/get_product_drop_turf()
	var/obj/machinery/drug_lab/machine = get_station_machine(DRUG_STATION_CRYSTALLIZER)
	if(!machine)
		return null
	for(var/direction in GLOB.cardinals)
		var/turf/open/candidate = get_step(machine, direction)
		if(istype(candidate) && !candidate.is_blocked_turf(exclude_mobs = TRUE))
			return candidate
	return get_turf(machine)

// =========================================================================
// UI DATA: each machine's payload, built here so the machines stay thin
// =========================================================================

/// The full ui_data payload for one station's machine. The heavy chart lists
/// only ride the payload while their game is actually live, data pushes
/// re-send everything, so idle payloads stay lean.
/datum/drug_lab_session/proc/ui_data_for(station)
	var/list/data = list(
		"stage" = stage,
		"station" = station,
		"scores" = scores,
		"station_score" = scores[station],
		"attempts_used" = attempts[station],
		"max_attempts" = DRUG_STATION_ATTEMPTS,
		"street_name" = mission?.recipe?.street_name,
	)
	var/static/list/attempt_caps = DRUG_ATTEMPT_MAX_SCORES
	var/next_cap = attempts[station] < DRUG_STATION_ATTEMPTS ? attempt_caps[attempts[station] + 1] : null
	switch(station)
		if(DRUG_STATION_MIXER)
			var/mixer_live = game_active && stage == DRUG_LAB_STAGE_MIXER
			var/list/checklist = list()
			if(mission?.recipe)
				for(var/list/entry in mission.recipe.ingredients)
					checklist += list(list(
						"name" = entry["name"],
						"banked" = !!banked[entry["type"]],
					))
			data["ingredients"] = checklist
			data["hopper_count"] = DRUG_MIXER_HOPPER_COUNT
			data["total_rounds"] = DRUG_MIXER_ROUNDS
			data["game_active"] = mixer_live
			data["round"] = mixer_round
			data["rounds_completed"] = mixer_rounds_completed
			data["sequence"] = mixer_live ? mixer_sequence : null
			data["sequence_id"] = mixer_sequence_id
			data["cursor"] = mixer_cursor
			data["awaiting_choice"] = mixer_awaiting_choice
			data["last_attempt_score"] = mixer_attempt_score
			data["botched"] = mixer_botched
			data["next_cap"] = next_cap
		if(DRUG_STATION_CATALYST)
			var/catalyst_live = game_active && stage == DRUG_LAB_STAGE_CATALYST
			data["lane_count"] = DRUG_CATALYST_LANE_COUNT
			data["lead_in_ms"] = DRUG_GAME_LEAD_IN_MS
			data["game_active"] = catalyst_live
			data["chart"] = catalyst_live ? catalyst_chart : null
			data["nonce"] = catalyst_live ? game_nonce : null
			data["awaiting_choice"] = (stage == DRUG_LAB_STAGE_CATALYST) && game_awaiting_choice
			data["last_attempt_score"] = game_attempt_score
			data["botched"] = (stage == DRUG_LAB_STAGE_CATALYST) && game_botched
			data["next_cap"] = next_cap
		if(DRUG_STATION_CRYSTALLIZER)
			var/crystallizer_live = game_active && stage == DRUG_LAB_STAGE_CRYSTALLIZER
			data["col_count"] = DRUG_CRYSTALLIZER_COL_COUNT
			data["lead_in_ms"] = DRUG_GAME_LEAD_IN_MS
			data["game_active"] = crystallizer_live
			data["spawn_table"] = crystallizer_live ? crystallizer_table : null
			data["nonce"] = crystallizer_live ? game_nonce : null
			data["awaiting_choice"] = (stage == DRUG_LAB_STAGE_CRYSTALLIZER) && game_awaiting_choice
			data["last_attempt_score"] = game_attempt_score
			data["botched"] = (stage == DRUG_LAB_STAGE_CRYSTALLIZER) && game_botched
			data["next_cap"] = next_cap
	return data

#undef DRUG_MIXER_ROUNDS
#undef DRUG_MIXER_ROUND_SCORE
#undef DRUG_GAME_LEAD_IN_MS
#undef DRUG_GAME_ABANDON_GRACE
#undef DRUG_CATALYST_PERFECT_POINTS
#undef DRUG_CATALYST_GOOD_POINTS
#undef DRUG_CRYSTALLIZER_TAINT_PENALTY
