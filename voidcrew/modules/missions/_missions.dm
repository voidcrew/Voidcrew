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
	/// Item type path to spawn on completion (optional). The single-reward
	/// convenience; get_reward_types() folds it together with mission_rewards.
	var/mission_reward
	/// Additional item type paths to spawn on completion — the multi-reward
	/// channel (a whole bundle, potentially mixed rarity). May hold duplicates
	/// (e.g. two of the same warhead), which spawn as separate items.
	var/list/mission_rewards
	/// Subset of the reward types that count as "rare/exclusive" for UI accent.
	var/list/rare_reward_types
	/// Mission difficulty (MISSION_DIFFICULTY_EASY/MEDIUM/HARD) - informational only
	var/difficulty = MISSION_DIFFICULTY_MEDIUM
	/// If TRUE, mission requires an item to be turned in via mission pad
	var/requires_item = FALSE
	/// Number of trade vouchers awarded on completion (spawned on the mission pad)
	var/voucher_count = 0
	/// Set TRUE by generate_mission_details() if the mission couldn't find a valid setup; the subsystem discards it
	var/generation_failed = FALSE

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
	/// The outpost shop that posted this mission, if any (outpost-board contracts)
	var/datum/outpost_shop/shop

/datum/mission/New(datum/outpost_shop/shop)
	. = ..()
	src.shop = shop
	generate_mission_details()

/datum/mission/Destroy()
	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null
	if(servant)
		servant.remove_waypoint(REF(src))
		servant.active_missions -= src
		servant = null
	shop = null
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
	if(length(get_reward_types()))
		var/reward_name = get_reward_summary()
		name = replacetext(name, "%REWARD%", reward_name)
		desc = replacetext(desc, "%REWARD%", reward_name)

/**
 * Every item reward this mission pays, as a flat list of type paths. Folds the
 * single-reward convenience (mission_reward) together with the multi-reward
 * bundle (mission_rewards); may contain duplicates.
 */
/datum/mission/proc/get_reward_types()
	. = list()
	if(mission_reward)
		. += mission_reward
	if(length(mission_rewards))
		. += mission_rewards

/**
 * Human-readable summary of the item rewards, e.g. "a standard missile, 2×
 * light warhead and an ablative vest". Returns "goods" when nothing is set.
 */
/datum/mission/proc/get_reward_summary()
	var/list/types = get_reward_types()
	if(!length(types))
		return "goods"
	// Collapse duplicates into counts so a bundle reads "2× light missile"
	var/list/counts = list()
	for(var/reward_type in types)
		counts[reward_type] = (counts[reward_type] || 0) + 1
	var/list/parts = list()
	for(var/reward_type in counts)
		var/atom/reward_cast = reward_type
		var/reward_name = initial(reward_cast.name)
		var/count = counts[reward_type]
		parts += count > 1 ? "[count]× [reward_name]" : reward_name
	return english_list(parts)

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

	// Chart the mission's target on the helm waypoint readout, if it has one
	push_waypoint()

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
 * Whether this turn-in point (ship mission pad, outpost contract board...) is
 * valid for this mission. Most contracts accept any; courier runs insist on
 * their destination outpost.
 * * reward_anchor - The machine the turn-in is happening at
 */
/datum/mission/proc/can_turn_in_at(atom/reward_anchor)
	return TRUE

/**
 * User-facing reason a turn-in point was refused (pairs with can_turn_in_at).
 */
/datum/mission/proc/get_wrong_location_reason(atom/reward_anchor)
	return "This contract can't be turned in here."

/**
 * Short archetype tag for UI iconography ("procurement", "bounty", ...).
 */
/datum/mission/proc/get_archetype()
	return "contract"

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
 * * reward_anchor - The machine the turn-in happened at (ship mission pad or
 *   outpost contract board); rewards spawn on its turf
 * * turned_in_item - Optional item that was turned in (will be consumed)
 */
/datum/mission/proc/turn_in(atom/reward_anchor, obj/item/turned_in_item)
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
	distribute_rewards(reward_anchor)

	// Notify ship
	if(servant)
		var/list/reward_parts = list()
		if(value > 0)
			reward_parts += "[value] credits"
		if(length(get_reward_types()))
			reward_parts += get_reward_summary()
		if(voucher_count > 0)
			reward_parts += "[voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]"
		var/reward_text = length(reward_parts) ? reward_parts.Join(" + ") : "settled"
		servant.ship_notify("[name] completed! Reward: [reward_text]", "MISSION COMPLETE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
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
 * Returns this mission's overmap target for the helm waypoint readout as
 * list(name, x, y) in relative overmap coordinates, or null if this mission
 * type has no overmap target.
 */
/datum/mission/proc/get_waypoint_info()
	return null

/**
 * Pushes (or refreshes) this mission's waypoint on the servant ship's helm
 * readout. Safe to call again after a retarget; the marker moves in place.
 */
/datum/mission/proc/push_waypoint()
	if(!servant)
		return
	var/list/info = get_waypoint_info()
	if(!info)
		return
	servant.add_waypoint(REF(src), info[1], info[2], info[3], "Missions")

/**
 * Uploads this mission's objective beacon to a specific handheld GPS unit
 * (player tapped the unit on the mission board console).
 * Override in mission types that have a trackable objective.
 * Returns TRUE if this mission had a beacon to upload.
 */
/datum/mission/proc/link_gps_unit(datum/component/gps/item/gps_unit)
	return FALSE

/**
 * Distributes mission rewards to the ship account.
 * Item rewards spawn at the turn-in point (mission pad or outpost board).
 * * reward_anchor - The machine to spawn physical rewards at
 */
/datum/mission/proc/distribute_rewards(atom/reward_anchor)
	if(!servant)
		return

	// Pay ship account
	if(servant.ship_account && value > 0)
		servant.ship_account.adjust_money(value)

	var/turf/reward_turf = get_turf(reward_anchor)

	// Spawn every item reward in the bundle at the turn-in point
	var/list/reward_types = get_reward_types()
	if(length(reward_types) && reward_turf)
		for(var/reward_type in reward_types)
			new reward_type(reward_turf)
		flash_reward_anchor(reward_anchor)

	// Spawn voucher rewards at the turn-in point
	if(voucher_count > 0 && reward_turf)
		new /obj/item/stack/trade_voucher(reward_turf, voucher_count)
		flash_reward_anchor(reward_anchor)

/**
 * Turn-in visual: pads get their teleport effect, other anchors stay quiet
 * (the outpost board plays its own sounds).
 */
/datum/mission/proc/flash_reward_anchor(atom/reward_anchor)
	if(istype(reward_anchor, /obj/machinery/mission_pad))
		var/obj/machinery/mission_pad/pad = reward_anchor
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
	// Every reward in the bundle, each with its own sprite and a rarity accent
	var/list/reward_items = list()
	for(var/reward_type in get_reward_types())
		var/atom/reward_cast = reward_type
		reward_items += list(list(
			"name" = initial(reward_cast.name),
			"icon" = icon2base64(icon(initial(reward_cast.icon), initial(reward_cast.icon_state))),
			"rare" = (reward_type in rare_reward_types),
		))
	// First reward mirrored onto the legacy single-reward fields for compatibility
	var/list/first_reward = length(reward_items) ? reward_items[1] : null
	return list(
		"ref" = REF(src),
		"name" = name,
		"desc" = desc,
		"author" = author,
		"value" = value,
		"reward_items" = reward_items,
		"reward_item" = first_reward ? first_reward["name"] : null,
		"reward_item_icon" = first_reward ? first_reward["icon"] : null,
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
		"voucher_count" = voucher_count,
		"archetype" = get_archetype(),
	)
