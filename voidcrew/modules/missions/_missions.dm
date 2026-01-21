/**
 * # Mission Datum
 *
 * Base mission class for the Voidcrew mission system.
 * Missions are accepted by ships and provide credit/item rewards upon completion.
 */
/datum/mission
	/// Display name of the mission
	var/name = "Mission"
	/// Description shown to players. Supports text substitution (%TARGET%, %ITEM%, etc.)
	var/desc = "Complete this mission."
	/// Name of the mission giver (randomly generated if not set)
	var/author = ""
	/// Minimum credit reward
	var/value_min = 800
	/// Maximum credit reward
	var/value_max = 1200
	/// Actual credit reward (set during generation from min/max)
	var/value = 0
	/// Time limit in deciseconds (default 30 minutes)
	var/duration = DEFAULT_MISSION_DURATION
	/// Selection weight for random mission generation (0 = never auto-selected)
	var/weight = 0
	/// Maximum number of this mission type that can be active at once (0 = unlimited)
	var/mission_limit = 0
	/// Item type path to spawn on completion (optional)
	var/mission_reward
	/// Mission difficulty (MISSION_DIFFICULTY_EASY/MEDIUM/HARD) - informational only
	var/difficulty = MISSION_DIFFICULTY_MEDIUM
	/// If TRUE, mission requires an item to be turned in via mission pad
	var/requires_item = FALSE

	/// Whether the mission has been accepted/started
	var/active = FALSE
	/// Whether the mission has failed
	var/failed = FALSE
	/// Whether the mission has been completed
	var/completed = FALSE
	/// World time when mission was started
	var/time_started
	/// Timer ID for the mission timeout
	var/timeout_timer

	/// The ship that accepted this mission
	var/obj/structure/overmap/ship/servant

/datum/mission/New()
	. = ..()
	generate_mission_details()

/datum/mission/Destroy()
	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null
	if(servant)
		servant.active_missions -= src
		servant = null
	return ..()

/**
 * Generates randomized mission details on creation.
 * Randomizes value within min/max range and generates author if not set.
 */
/datum/mission/proc/generate_mission_details()
	// Randomize value within min/max range
	value = rand(value_min, value_max)

	// Generate random author if not set
	if(!author)
		author = generate_mission_author()

	// Apply text substitutions to name and desc
	apply_text_substitutions()

/**
 * Generates a random mission author name.
 */
/datum/mission/proc/generate_mission_author()
	var/static/list/first_names = list(
		"Dr.", "Prof.", "Capt.", "Chief", "Director", "Agent", "Officer"
	)
	var/static/list/last_names = list(
		"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
		"Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Wilson"
	)
	return "[pick(first_names)] [pick(last_names)]"

/**
 * Returns the display name for the current difficulty.
 */
/datum/mission/proc/get_difficulty_name()
	switch(difficulty)
		if(MISSION_DIFFICULTY_EASY)
			return "Easy"
		if(MISSION_DIFFICULTY_MEDIUM)
			return "Medium"
		if(MISSION_DIFFICULTY_HARD)
			return "Hard"
	return "Unknown"

/**
 * Returns the UI color for the current difficulty.
 */
/datum/mission/proc/get_difficulty_color()
	switch(difficulty)
		if(MISSION_DIFFICULTY_EASY)
			return "good"
		if(MISSION_DIFFICULTY_MEDIUM)
			return "average"
		if(MISSION_DIFFICULTY_HARD)
			return "bad"
	return "label"

/**
 * Applies text substitutions to name and desc.
 * Override in subtypes to add custom substitutions.
 */
/datum/mission/proc/apply_text_substitutions()
	if(author)
		name = replacetext(name, "%AUTHOR%", author)
		desc = replacetext(desc, "%AUTHOR%", author)
	if(mission_reward)
		var/obj/item/reward_item = mission_reward
		var/reward_name = initial(reward_item.name)
		name = replacetext(name, "%REWARD%", reward_name)
		desc = replacetext(desc, "%REWARD%", reward_name)

/**
 * Called when a ship accepts this mission.
 * Moves mission from available to active list.
 * * ship - The ship accepting the mission
 * Returns TRUE on success, FALSE on failure.
 */
/datum/mission/proc/start_mission(obj/structure/overmap/ship/ship)
	if(!ship)
		return FALSE
	if(active)
		return FALSE

	servant = ship
	active = TRUE
	time_started = world.time

	// Move from available to active
	ship.available_missions -= src
	ship.active_missions += src

	// Start timeout timer
	timeout_timer = addtimer(CALLBACK(src, PROC_REF(on_timeout)), duration, TIMER_STOPPABLE)

	// Track in subsystem
	SSmissions.all_active_missions += src

	// Send signal
	SEND_SIGNAL(src, COMSIG_MISSION_STARTED, ship)

	return TRUE

/**
 * Called when the mission timer expires.
 */
/datum/mission/proc/on_timeout()
	timeout_timer = null
	fail("Mission timed out!")

/**
 * Marks the mission as failed.
 * * reason - Optional reason for failure (shown to crew)
 */
/datum/mission/proc/fail(reason = "Mission failed.")
	if(failed || completed)
		return

	failed = TRUE
	active = FALSE

	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null

	// Notify ship
	if(servant)
		servant.ship_notify("[name]: [reason]", "MISSION FAILED", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 25)
		servant.active_missions -= src

	// Remove from subsystem tracking
	SSmissions.all_active_missions -= src

	SEND_SIGNAL(src, COMSIG_MISSION_FAILED, reason)

	qdel(src)

/**
 * Called when player abandons the mission voluntarily.
 * No penalty, mission is just removed.
 */
/datum/mission/proc/give_up()
	if(failed || completed)
		return

	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null

	if(servant)
		servant.active_missions -= src

	SSmissions.all_active_missions -= src

	qdel(src)

/**
 * Checks if the mission can be completed.
 * Override in subtypes to add completion requirements.
 * Returns TRUE if mission can be turned in.
 */
/datum/mission/proc/can_complete()
	if(failed || completed)
		return FALSE
	// Item-based missions can only be completed via can_turn_in
	if(requires_item)
		return FALSE
	return TRUE

/**
 * Checks if a specific item can be used to turn in the mission.
 * Override in subtypes that require item turn-in.
 * * item - The item being offered for turn-in
 * Returns TRUE if item satisfies mission requirements.
 */
/datum/mission/proc/can_turn_in(obj/item/item)
	return can_complete()

/**
 * Returns a detailed reason why the mission can't be completed or item can't be turned in.
 * Used for user-facing error messages. Override in subtypes for specific messages.
 * * item - The item being offered (may be null)
 */
/datum/mission/proc/get_failure_reason(obj/item/item)
	if(failed)
		return "Mission already failed."
	if(completed)
		return "Mission already completed."
	if(requires_item && !item)
		return "No item provided."
	return "Requirements not met."

/**
 * Completes the mission and distributes rewards.
 * * pad - The mission pad used for turn-in (for item rewards)
 * * turned_in_item - Optional item that was turned in (will be consumed)
 */
/datum/mission/proc/turn_in(obj/machinery/mission_pad/pad, obj/item/turned_in_item)
	// Validate completion - use can_turn_in for item missions, can_complete otherwise
	if(requires_item)
		if(!can_turn_in(turned_in_item))
			return FALSE
	else
		if(!can_complete())
			return FALSE

	if(failed || completed)
		return FALSE

	completed = TRUE
	active = FALSE

	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null

	// Consume turned in item via hook (subtypes can override for stacks, etc.)
	if(turned_in_item)
		consume_turned_in_item(turned_in_item)

	// Distribute rewards
	distribute_rewards(pad)

	// Notify ship
	if(servant)
		servant.ship_notify("[name] completed! Reward: [value] credits[mission_reward ? " + item reward" : ""]", "MISSION COMPLETE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		servant.active_missions -= src

	// Remove from subsystem tracking
	SSmissions.all_active_missions -= src

	SEND_SIGNAL(src, COMSIG_MISSION_COMPLETED)

	qdel(src)
	return TRUE

/**
 * Consumes the turned in item. Override for custom behavior (e.g., stack consumption).
 * * item - The item to consume
 */
/datum/mission/proc/consume_turned_in_item(obj/item/item)
	qdel(item)

/**
 * Distributes mission rewards to the ship account.
 * Item rewards spawn on the mission pad.
 * * pad - The mission pad (for item reward spawning)
 */
/datum/mission/proc/distribute_rewards(obj/machinery/mission_pad/pad)
	if(!servant)
		return

	// Pay ship account
	if(servant.ship_account && value > 0)
		servant.ship_account.adjust_money(value)

	// Spawn item reward on pad
	if(mission_reward && pad)
		new mission_reward(get_turf(pad))
		// Visual effect
		pad.do_teleport_effect()

/**
 * Returns the time remaining until mission timeout in deciseconds.
 */
/datum/mission/proc/get_time_remaining()
	if(!timeout_timer)
		return 0
	return timeleft(timeout_timer)

/**
 * Returns a formatted string of time remaining (MM:SS).
 */
/datum/mission/proc/get_time_remaining_text()
	var/time_left = get_time_remaining() / 10 // Convert to seconds
	if(time_left <= 0)
		return "00:00"
	var/minutes = floor(time_left / 60)
	var/seconds = time_left % 60
	return "[add_leading(num2text(minutes), 2, "0")]:[add_leading(num2text(seconds), 2, "0")]"

/**
 * Returns progress string for display (e.g., "3/5").
 * Override in subtypes that track progress.
 */
/datum/mission/proc/get_progress_string()
	return ""

/**
 * Returns mission data for TGUI display.
 */
/datum/mission/proc/get_ui_data()
	var/reward_icon_base64 = null
	if(mission_reward)
		reward_icon_base64 = icon2base64(icon(initial(mission_reward:icon), initial(mission_reward:icon_state)))
	return list(
		"ref" = REF(src),
		"name" = name,
		"desc" = desc,
		"author" = author,
		"value" = value,
		"reward_item" = mission_reward ? initial(mission_reward:name) : null,
		"reward_item_icon" = reward_icon_base64,
		"duration" = duration,
		"time_remaining" = get_time_remaining(),
		"time_remaining_text" = get_time_remaining_text(),
		"progress" = get_progress_string(),
		"can_complete" = can_complete(),
		"active" = active,
		"failed" = failed,
		"completed" = completed,
		"difficulty" = difficulty,
		"difficulty_name" = get_difficulty_name(),
		"difficulty_color" = get_difficulty_color(),
		"requires_item" = requires_item,
	)
