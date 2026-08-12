/**
 * # Mission Datum (shell)
 *
 * Base mission class for the Voidcrew mission system. The shell owns pay,
 * timing, board plumbing, the overmap target (mission_target.dm), the tracked
 * quest atom + GPS beacon, and the retarget/fail policy when targets die.
 *
 * WHAT a mission asks for lives in its ordered list of objective datums
 * (objectives/): exactly one objective is current at a time, the mission
 * advances as each completes, and turn-in delegates to the current objective.
 * A mission type is mostly generation rolls, flavor text, and an objective
 * list.
 */
/datum/mission
	/// Display name of the mission
	var/name = "Mission"
	/// Description shown to players (rebuilt by update_text())
	var/desc = "Complete this mission."
	/// Name of the mission giver (randomly generated if not set)
	var/author = ""
	/// Credit reward band. Types set their GREEN-zone band; apply_zone_scaling()
	/// multiplies it up for deeper zones.
	var/value_min = 800
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
	/// Additional item type paths to spawn on completion, the multi-reward
	/// channel (a whole bundle, potentially mixed rarity). May hold duplicates
	/// (e.g. two of the same warhead), which spawn as separate items.
	var/list/mission_rewards
	/// Subset of the reward types that count as "rare/exclusive" for UI accent.
	var/list/rare_reward_types
	/// For stack-type rewards, units to spawn, keyed by type path. A shop SKU
	/// sells "plasteel (10 sheets)" for 750cr; without this the contract pays a
	/// single sheet, because spawning a stack bare gets you the stack's own
	/// default of one. Absent or 1 leaves that default alone.
	var/list/reward_amounts
	/// Multiplier on the difficulty pay band for outpost-board contracts.
	/// Difficulty alone can't tell "hand over 30 cable coil you already have"
	/// from "fly to a hostile ruin and kill a named boss", both roll EASY in
	/// green space. Archetypes that cost a trip and a fight set this above 1.
	var/contract_pay_mult = 1
	/// Mission difficulty (MISSION_DIFFICULTY_EASY/MEDIUM/HARD) - informational only
	var/difficulty = MISSION_DIFFICULTY_MEDIUM
	/// If TRUE, mission completes by handing an item over at the pad/trader.
	/// Derived from the last objective at generation; kept as a var because
	/// the board UI and ship API read it constantly.
	var/requires_item = FALSE
	/// Number of trade vouchers awarded on completion (spawned on the mission pad)
	var/voucher_count = 0
	/// Research points paid on completion, handed over as a research-notes
	/// dossier at the turn-in point (the crew slots it into an R&D console).
	/// Types set their GREEN-zone band; apply_zone_scaling() multiplies it up
	/// alongside credits.
	var/research_reward = 0
	/// Field of study printed on that dossier ("notes of xenofauna")
	var/research_origin = "field work"
	/// Set TRUE during generation if the mission couldn't find a valid setup; the caller discards it
	var/generation_failed = FALSE

	/// World time when this mission was created/posted; unaccepted offers past
	/// MISSION_BOARD_EXPIRY get rotated off the board by SSmissions
	var/posted_at
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

	// ===== OBJECTIVES =====
	/// Ordered steps of the mission; exactly one is current at a time
	var/list/datum/mission_objective/objectives = list()
	/// Index (1-based) of the current objective
	var/objective_index = 1

	// ===== TARGET =====
	/// Where the mission points on the overmap, if anywhere
	var/datum/mission_target/target
	/// Zone band (ZONE_*) this offer would rather point at, or null for no
	/// preference. Set by whoever posts the offer - SSmissions steers boards on
	/// ships with no combat research toward Neutral space. The target honours it
	/// where it can and ignores it where it can't, so it never fails generation.
	var/preferred_zone
	/// Display name of the target's zone at generation time
	var/target_zone_name = MISSION_ZONE_UNKNOWN
	/// Flavor name of the thing being recovered/hunted/planted, if any
	var/objective_name

	// ===== QUEST ATOM & LOSS POLICY =====
	/// What to do when the quest atom or target is lost mid-run
	var/quest_lost_policy = MISSION_QUEST_LOST_FAIL
	/// Retargets remaining while active (used with MISSION_QUEST_LOST_RETARGET)
	var/retargets_left = MAX_MISSION_RETARGETS
	/// The tracked physical objective (quest item / marked mob / pod / beacon)
	var/atom/movable/quest_atom
	/// Interior bounds captured when the quest atom registered: list(min_x,
	/// min_y, max_x, max_y, z). Distinguishes "stranded in the dead site"
	/// from "safely extracted" when the site despawns.
	var/list/quest_atom_bounds
	/// Bumped on every retarget; bound items from a previous era stop matching
	var/binding_serial = 1

	// ===== GPS BEACON =====
	/// GPS beacon tag; null means this mission type has no beacon
	var/gps_tag
	/// Prefix rolled into gps_tag at generation ("RCVRY", "HUNT", ...). Null = no beacon.
	var/gps_tag_prefix
	/// Weakrefs of /datum/component/gps/item units this mission's beacon was uploaded to
	var/list/datum/weakref/linked_gps_units = list()
	/// Secondary beacons (tag -> weakref) pushed alongside gps_tag by objectives
	/// that put several marks in the field at once. Held on the shell so a GPS
	/// linked later still gets the full set and cleanup drops every tag.
	var/list/aux_gps_beacons

/datum/mission/New(datum/outpost_shop/shop, preferred_zone)
	. = ..()
	src.shop = shop
	// Has to land before generate_mission_details(): setup_target() builds the
	// target datum, which copies this off us in its own New().
	src.preferred_zone = preferred_zone
	posted_at = world.time
	generate_mission_details()

/datum/mission/Destroy()
	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null
	clear_gps_signals()
	if(quest_atom)
		UnregisterSignal(quest_atom, COMSIG_QDELETING)
		quest_atom = null
	QDEL_LIST(objectives)
	QDEL_NULL(target)
	if(servant)
		servant.remove_waypoint(REF(src))
		servant.active_missions -= src
		servant = null
	shop = null
	return ..()

// =========================================================================
// GENERATION
// =========================================================================

/**
 * Generates the whole mission: target, zone scaling, per-type details, the
 * objective list, pay roll, author, beacon tag, text. Subtypes normally
 * override the hooks (setup_target / generate_details / build_objectives /
 * update_text) rather than this.
 */
/datum/mission/proc/generate_mission_details()
	if(!setup_target())
		generation_failed = TRUE
		return

	if(target)
		var/zone_type = target.get_zone_type()
		if(!isnull(zone_type))
			apply_zone_scaling(zone_type)

	generate_details()
	if(generation_failed)
		return

	build_objectives()
	if(generation_failed)
		return
	if(length(objectives))
		var/datum/mission_objective/last = objectives[length(objectives)]
		requires_item = last.requires_item

	value = rand(value_min, value_max)
	if(!author)
		author = generate_mission_author()
	if(gps_tag_prefix)
		gps_tag = "[gps_tag_prefix]-[uppertext(random_string(3, GLOB.hex_characters))]"
	update_text()

/**
 * Creates and resolves this mission's target. Return FALSE to fail
 * generation. Types without an overmap target just return TRUE.
 */
/datum/mission/proc/setup_target()
	return TRUE

/// Per-type generation rolls (names, asks, rewards). May set generation_failed.
/datum/mission/proc/generate_details()
	return

/// Per-type objective assembly via add_objective(). May set generation_failed.
/datum/mission/proc/build_objectives()
	return

/**
 * Appends an objective and runs its generation roll.
 * Returns the objective, or null (and fails generation) on a bad roll.
 */
/datum/mission/proc/add_objective(datum/mission_objective/objective)
	objective.mission = src
	if(!objective.generate())
		qdel(objective)
		generation_failed = TRUE
		return null
	objectives += objective
	return objective

/**
 * The zone scaling service: one table mapping the target's zone to
 * difficulty, zone name, pay multiplier and a red-zone voucher bonus.
 * Types tune pay by setting their green-zone value band.
 */
/datum/mission/proc/apply_zone_scaling(zone_type)
	var/static/list/zone_scaling = list(
		"[ZONE_GREEN]" = list("name" = ZONE_NAME_GREEN, "difficulty" = MISSION_DIFFICULTY_EASY, "value_mult" = 1, "voucher_bonus" = 0),
		"[ZONE_YELLOW]" = list("name" = ZONE_NAME_YELLOW, "difficulty" = MISSION_DIFFICULTY_MEDIUM, "value_mult" = 1.7, "voucher_bonus" = 0),
		"[ZONE_RED]" = list("name" = ZONE_NAME_RED, "difficulty" = MISSION_DIFFICULTY_HARD, "value_mult" = 2.6, "voucher_bonus" = 1),
	)
	var/list/row = zone_scaling["[zone_type]"] || zone_scaling["[ZONE_GREEN]"]
	target_zone_name = row["name"]
	difficulty = row["difficulty"]
	value_min = round(value_min * row["value_mult"], 10)
	value_max = round(value_max * row["value_mult"], 10)
	if(research_reward > 0)
		research_reward = round(research_reward * row["value_mult"], 50)
	if(voucher_count > 0)
		voucher_count += row["voucher_bonus"]

/**
 * Rebuilds name/desc from current state. Called at the end of generation and
 * again after retargets/target moves. Subtypes override.
 */
/datum/mission/proc/update_text()
	return

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

// =========================================================================
// LIFECYCLE
// =========================================================================

/**
 * Called when a ship accepts this mission.
 * * ship - The ship accepting the mission
 * Returns TRUE on success, FALSE on failure.
 */
/datum/mission/proc/start_mission(obj/structure/overmap/ship/ship)
	if(!ship)
		return FALSE
	if(active)
		return FALSE

	// The target may have died while the mission sat on the board
	if(target && !target.is_valid())
		if(!target.resolve())
			return FALSE
		update_text()

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

	// Per-type start effects (courier pods, claim kits...). May fail the mission.
	on_mission_started()
	if(failed || QDELETED(src))
		return FALSE

	activate_current_objective()

	SEND_SIGNAL(src, COMSIG_MISSION_STARTED, ship)
	return TRUE

/// Per-type hook run right after the mission goes active
/datum/mission/proc/on_mission_started()
	return

/// The objective currently in play, or null when all are done
/datum/mission/proc/current_objective()
	if(objective_index < 1 || objective_index > length(objectives))
		return null
	return objectives[objective_index]

/datum/mission/proc/activate_current_objective()
	var/datum/mission_objective/objective = current_objective()
	if(objective && !objective.completed && !objective.active)
		objective.activate()

/**
 * An objective finished; advance to the next one.
 */
/datum/mission/proc/on_objective_completed(datum/mission_objective/objective)
	if(failed || completed)
		return
	if(current_objective() != objective)
		return
	objective_index++
	// Skip anything that already completed out of order (e.g. a cook wrapped
	// while the gather step was still current) so the chain can't wedge on a
	// pre-completed step that will never fire again
	var/datum/mission_objective/next_objective = current_objective()
	while(next_objective?.completed)
		objective_index++
		next_objective = current_objective()
	if(next_objective)
		activate_current_objective()
		push_waypoint()

/**
 * Called when the mission timer expires.
 */
/datum/mission/proc/on_timeout()
	timeout_timer = null
	fail("Mission timed out!")

/// Deactivates the live objective (fail/complete/abandon/retarget paths)
/datum/mission/proc/deactivate_objectives()
	var/datum/mission_objective/objective = current_objective()
	if(objective?.active)
		objective.deactivate()

/**
 * Marks the mission as failed.
 * * reason - Optional reason for failure (shown to crew)
 */
/datum/mission/proc/fail(reason = "Mission failed.")
	if(failed || completed)
		return

	failed = TRUE
	active = FALSE
	deactivate_objectives()

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

	deactivate_objectives()

	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null

	if(servant)
		servant.active_missions -= src

	SSmissions.all_active_missions -= src

	qdel(src)

// =========================================================================
// TARGET & QUEST ATOM TRACKING
// =========================================================================

/**
 * Tracks a physical objective (quest item, marked mob, pod, beacon): watches
 * its destruction, captures the site's bounds for stranding checks, and
 * points the GPS beacon at it. Re-registering swaps tracking to the new atom
 * (kill missions swap corpse -> tag; pylon chains hop pylon -> pylon).
 */
/datum/mission/proc/register_quest_atom(atom/movable/new_quest_atom)
	if(quest_atom == new_quest_atom)
		return
	if(quest_atom)
		UnregisterSignal(quest_atom, COMSIG_QDELETING)
	quest_atom = new_quest_atom
	RegisterSignal(quest_atom, COMSIG_QDELETING, PROC_REF(on_quest_atom_destroyed))
	quest_atom_bounds = target?.get_interior_bounds()
	push_gps_signal()
	on_quest_atom_registered(new_quest_atom)

/// Per-type hook when a quest atom starts being tracked (pickup ambushes etc.)
/datum/mission/proc/on_quest_atom_registered(atom/movable/new_quest_atom)
	return

/// Stops tracking an atom WITHOUT running the loss policy (finished pylons)
/datum/mission/proc/forget_quest_atom(atom/movable/old_quest_atom)
	if(quest_atom != old_quest_atom)
		return
	UnregisterSignal(quest_atom, COMSIG_QDELETING)
	quest_atom = null
	quest_atom_bounds = null

/// Binds a quest item to this mission (pad matching + era serial)
/datum/mission/proc/bind_item(obj/item/item)
	if(istype(item, /obj/item/mission_recovery))
		var/obj/item/mission_recovery/bound = item
		bound.mission_ref = WEAKREF(src)
		bound.binding_serial = binding_serial
	else if(istype(item, /obj/item/freight_pod))
		var/obj/item/freight_pod/pod = item
		pod.mission_ref = WEAKREF(src)

/datum/mission/proc/on_quest_atom_destroyed(datum/source)
	SIGNAL_HANDLER
	quest_atom = null
	quest_atom_bounds = null
	if(failed || completed)
		return
	handle_quest_loss("Objective lost - contract void.")

/**
 * The quest atom (or the target before anything spawned) was lost: retarget
 * or fail per policy.
 */
/datum/mission/proc/handle_quest_loss(reason = "Objective lost - contract void.")
	if(failed || completed)
		return
	if(quest_lost_policy == MISSION_QUEST_LOST_RETARGET)
		retarget(reason)
	else
		fail(reason)

/**
 * Whether the quest atom is still physically inside the (now dying) site.
 */
/datum/mission/proc/is_quest_atom_stranded()
	if(!quest_atom || QDELETED(quest_atom) || !length(quest_atom_bounds))
		return FALSE
	var/turf/quest_turf = get_turf(quest_atom)
	if(!quest_turf)
		return FALSE
	return quest_turf.z == quest_atom_bounds[5] \
		&& quest_turf.x >= quest_atom_bounds[1] && quest_turf.x <= quest_atom_bounds[3] \
		&& quest_turf.y >= quest_atom_bounds[2] && quest_turf.y <= quest_atom_bounds[4]

/**
 * The target object is being deleted (abandoned ruin respawning elsewhere...).
 * If the quest atom was left behind inside it, destroy it ourselves so the
 * quest-loss path runs; if it was extracted, the mission can still finish.
 */
/datum/mission/proc/on_target_lost()
	if(failed || completed)
		return
	if(quest_atom)
		if(is_quest_atom_stranded())
			qdel(quest_atom) // triggers on_quest_atom_destroyed -> policy
		return
	handle_quest_loss("Target lost - contract void.")

/// The target moved without dying (planets relocate after unloading)
/datum/mission/proc/on_target_moved()
	if(failed || completed)
		return
	update_text()
	if(active)
		push_waypoint()
		servant?.ship_notify("[name]: target signal relocated to ([target.target_x], [target.target_y]).", "MISSION UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)

/// The target's interior just loaded; let the current objective arm itself
/datum/mission/proc/on_target_interior_loaded()
	var/datum/mission_objective/field/objective = current_objective()
	if(istype(objective))
		objective.on_interior_loaded()

/**
 * The target's interior is being torn down while the target itself lives on -
 * an emptied ruin handing its reservation back. Everything this mission put in
 * there is about to go with the turfs, but that is not the same event as losing
 * the objective: the site is still on the chart at the same coordinates and the
 * crew can fly back to it.
 *
 * So this rewinds rather than retargets. The watch on whatever is standing in
 * the dead site is dropped before the wipe can fire it (otherwise the wipe reads
 * as a destroyed objective and burns a retarget re-rolling to a ruin the crew
 * has no reason to be at), the objective chain resets, and the field step
 * re-arms on the load signal - so docking there again lays the job out fresh.
 *
 * Anything the crew already carried out is untouched: it isn't in the site, so
 * the contract is still on its delivery step and nothing here applies.
 */
/datum/mission/proc/on_target_interior_unloaded()
	if(failed || completed || !active)
		return
	if(!quest_atom || !is_quest_atom_stranded())
		return

	UnregisterSignal(quest_atom, COMSIG_QDELETING)
	quest_atom = null
	quest_atom_bounds = null

	deactivate_objectives()
	for(var/datum/mission_objective/objective as anything in objectives)
		objective.reset()
	objective_index = 1
	activate_current_objective()
	push_waypoint()
	servant?.ship_notify("[name]: the site powered down before we recovered anything, and our gear went with it. The contract stands - it will be set up again next time you dock at ([target.target_x], [target.target_y]).", "MISSION UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)

/**
 * Re-picks the target and restarts the objective chain from step one.
 * Free while the mission sits on the board; budgeted while active.
 */
/datum/mission/proc/retarget(reason = "Target lost - contract void.")
	if(quest_atom)
		UnregisterSignal(quest_atom, COMSIG_QDELETING)
		quest_atom = null
	quest_atom_bounds = null
	binding_serial++ // items bound before the retarget stop matching

	if(active)
		retargets_left--
		if(retargets_left < 0)
			fail(reason)
			return
	if(!target?.resolve())
		fail(reason)
		return

	deactivate_objectives()
	for(var/datum/mission_objective/objective as anything in objectives)
		objective.reset()
	objective_index = 1
	update_text()

	if(active)
		activate_current_objective()
		push_waypoint()
		servant?.ship_notify("[name]: target signal relocated to ([target.target_x], [target.target_y]), [target_zone_name].", "MISSION UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)

// =========================================================================
// COMPLETION & TURN-IN
// =========================================================================

/// Whether every objective reports satisfied right now
/datum/mission/proc/all_objectives_satisfied()
	for(var/datum/mission_objective/objective as anything in objectives)
		if(!objective.is_satisfied())
			return FALSE
	return TRUE

/**
 * Checks if the mission can be completed (non-item missions).
 * Item-based missions complete via can_turn_in instead.
 */
/datum/mission/proc/can_complete()
	if(failed || completed)
		return FALSE
	if(requires_item)
		return FALSE
	return all_objectives_satisfied()

/**
 * Checks if a specific item can be used to turn in the mission right now.
 * Delegates to the current objective.
 */
/datum/mission/proc/can_turn_in(obj/item/item)
	if(failed || completed)
		return FALSE
	var/datum/mission_objective/objective = current_objective()
	if(!objective?.requires_item)
		return FALSE
	return objective.can_turn_in(item)

/**
 * Whether this turn-in point (ship mission pad, outpost trader...) is valid
 * for this mission. Most contracts accept any; courier runs insist on their
 * destination outpost.
 */
/datum/mission/proc/can_turn_in_at(atom/reward_anchor)
	return TRUE

/**
 * User-facing reason a turn-in point was refused (pairs with can_turn_in_at).
 */
/datum/mission/proc/get_wrong_location_reason(atom/reward_anchor)
	return "This contract can't be turned in here."

/**
 * The best item in the user's hands to offer this contract: the first that
 * satisfies the ask outright, or failing that the first that is the right KIND
 * of goods. The near-miss matters. It lets a refusal name the real shortfall
 * ("Need 30, only have 12") instead of telling someone holding the goods to go
 * hold the goods. Returns null when nothing in hand is even close.
 *
 * Callers must re-check can_turn_in() on the result; a near-miss comes back too.
 */
/datum/mission/proc/pick_offered_item(mob/living/user)
	if(!isliving(user) || !requires_item)
		return null
	var/datum/mission_objective/objective = current_objective()
	var/obj/item/near_miss
	for(var/obj/item/held in user.held_items)
		if(can_turn_in(held))
			return held
		if(!near_miss && objective?.matches_ask(held))
			near_miss = held
	return near_miss

/**
 * Short archetype tag for UI iconography ("procurement", "bounty", ...).
 */
/datum/mission/proc/get_archetype()
	return "contract"

/**
 * Returns a detailed reason why the mission can't be completed or the item
 * can't be turned in. Used for user-facing error messages.
 */
/datum/mission/proc/get_failure_reason(obj/item/item)
	if(failed)
		return "Mission already failed."
	if(completed)
		return "Mission already completed."
	var/datum/mission_objective/objective = current_objective()
	if(requires_item)
		if(objective?.requires_item)
			return objective.describe_turn_in_failure(item)
		if(objective)
			return "[objective.get_progress_string()]."
		return "Requirements not met."
	if(objective)
		return "Still in progress: [objective.get_progress_string()]."
	if(!all_objectives_satisfied())
		return "Requirements not met."
	return "Requirements not met."

/**
 * Completes (or advances) the mission at a turn-in point.
 * * reward_anchor - The machine/NPC the turn-in happened at; rewards spawn there
 * * turned_in_item - Optional item that was offered (consumed by the objective)
 * * force - Skip objective validation (admin testing); state guards still apply
 *
 * Returns TRUE when the offer was accepted. The mission may have completed
 * (it is qdeleted by then) or just advanced a counted hand-over.
 */
/datum/mission/proc/turn_in(atom/reward_anchor, obj/item/turned_in_item, force = FALSE)
	if(failed || completed)
		return FALSE

	if(!force)
		if(requires_item)
			if(!can_turn_in(turned_in_item))
				return FALSE
			var/datum/mission_objective/objective = current_objective()
			var/result = objective.accept_item(turned_in_item, reward_anchor)
			if(result == MISSION_ITEM_PROGRESS)
				return TRUE // partial hand-over; mission continues
			if(!all_objectives_satisfied())
				return TRUE // an objective closed but more remain
		else
			if(!can_complete())
				return FALSE

	finish_mission(reward_anchor)
	return TRUE

/**
 * The mission is done: run objective finalizers, pay out, notify, clean up.
 */
/datum/mission/proc/finish_mission(atom/reward_anchor)
	completed = TRUE
	active = FALSE

	if(timeout_timer)
		deltimer(timeout_timer)
		timeout_timer = null

	// Turn-in side effects (escort repatriation, pay bonuses) before payout
	for(var/datum/mission_objective/objective as anything in objectives)
		objective.on_turn_in_finalized(reward_anchor)

	deactivate_objectives()

	// Distribute rewards
	distribute_rewards(reward_anchor)

	// Standing with the posting trader (board contracts only; see trader_favor.dm)
	var/favor_gain = get_favor_reward()
	if(favor_gain > 0 && servant && shop)
		shop.grant_favor(servant, favor_gain)

	// Notify ship
	if(servant)
		var/list/reward_parts = list()
		if(value > 0)
			reward_parts += "[value] credits"
		if(length(get_reward_types()))
			reward_parts += get_reward_summary()
		if(research_reward > 0)
			reward_parts += "[research_reward] research points"
		if(voucher_count > 0)
			reward_parts += "[voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]"
		if(favor_gain > 0 && shop)
			reward_parts += "+[favor_gain] standing with [shop.favor_trader_name()]"
		var/reward_text = length(reward_parts) ? reward_parts.Join(" + ") : "settled"
		servant.ship_notify("[name] completed! Reward: [reward_text]", "MISSION COMPLETE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		servant.active_missions -= src

	// Remove from subsystem tracking
	SSmissions.all_active_missions -= src

	SEND_SIGNAL(src, COMSIG_MISSION_COMPLETED)

	qdel(src)

// =========================================================================
// WAYPOINTS & GPS
// =========================================================================

/// Short label for the helm waypoint readout
/datum/mission/proc/waypoint_label()
	return name

/**
 * Returns this mission's overmap target for the helm waypoint readout as
 * list(name, x, y) in relative overmap coordinates, or null if this mission
 * type has no overmap target.
 */
/datum/mission/proc/get_waypoint_info()
	if(!target)
		return null
	return list(waypoint_label(), target.target_x, target.target_y)

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
 * Returns TRUE if this mission had a beacon to upload.
 */
/datum/mission/proc/link_gps_unit(datum/component/gps/item/gps_unit)
	if(failed || completed || !gps_tag || !gps_unit)
		return FALSE
	linked_gps_units |= WEAKREF(gps_unit)
	if(quest_atom && !QDELETED(quest_atom))
		gps_unit.add_mission_signal(gps_tag, quest_atom)
	for(var/beacon_tag in aux_gps_beacons)
		var/datum/weakref/beacon_ref = aux_gps_beacons[beacon_tag]
		var/atom/movable/beacon_target = beacon_ref?.resolve()
		if(beacon_target)
			gps_unit.add_mission_signal(beacon_tag, beacon_target)
	return TRUE

/**
 * Adds (or re-points) a secondary beacon on every linked GPS unit. Objectives
 * with several marks in the field at once use this so the crew sees all of
 * them, instead of one dot that hops between them without saying so.
 */
/datum/mission/proc/add_gps_beacon(beacon_tag, atom/movable/beacon_target)
	if(!beacon_tag || QDELETED(beacon_target))
		return
	LAZYSET(aux_gps_beacons, beacon_tag, WEAKREF(beacon_target))
	for(var/datum/weakref/unit_ref as anything in linked_gps_units)
		var/datum/component/gps/item/unit = unit_ref.resolve()
		if(!unit)
			linked_gps_units -= unit_ref
			continue
		unit.add_mission_signal(beacon_tag, beacon_target)

/// Drops one secondary beacon from every linked GPS unit
/datum/mission/proc/remove_gps_beacon(beacon_tag)
	if(!beacon_tag)
		return
	LAZYREMOVE(aux_gps_beacons, beacon_tag)
	for(var/datum/weakref/unit_ref as anything in linked_gps_units)
		var/datum/component/gps/item/unit = unit_ref.resolve()
		unit?.remove_mission_signal(beacon_tag)

/**
 * (Re)points the beacon at the current quest atom on every linked GPS unit.
 */
/datum/mission/proc/push_gps_signal()
	if(!gps_tag || !quest_atom || QDELETED(quest_atom))
		return
	for(var/datum/weakref/unit_ref as anything in linked_gps_units)
		var/datum/component/gps/item/unit = unit_ref.resolve()
		if(!unit)
			linked_gps_units -= unit_ref
			continue
		unit.add_mission_signal(gps_tag, quest_atom)

/**
 * Removes every beacon this mission pushed - its own and any secondaries -
 * from every linked GPS unit.
 */
/datum/mission/proc/clear_gps_signals()
	for(var/datum/weakref/unit_ref as anything in linked_gps_units)
		var/datum/component/gps/item/unit = unit_ref.resolve()
		if(!unit)
			continue
		if(gps_tag)
			unit.remove_mission_signal(gps_tag)
		for(var/beacon_tag in aux_gps_beacons)
			unit.remove_mission_signal(beacon_tag)
	aux_gps_beacons = null
	linked_gps_units.Cut()

// =========================================================================
// REWARDS
// =========================================================================

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
		// A bundled stack counts by its units, so "10× plasteel" not "plasteel"
		var/count = counts[reward_type] * (LAZYACCESS(reward_amounts, reward_type) || 1)
		parts += count > 1 ? "[count]× [reward_name]" : reward_name
	return english_list(parts)

/**
 * The whole of what an outpost contract pays, goods and scrip together, e.g.
 * "a laser gun and 2× stimpack + 2 trade vouchers". Board contracts never pay
 * credits, so the item bundle plus any voucher top-up is the entire settlement.
 */
/datum/mission/proc/get_contract_pay_summary()
	var/list/parts = list(get_reward_summary())
	if(voucher_count > 0)
		parts += "[voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]"
	return parts.Join(" + ")

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
			// Stacks carry their bundled count, matching what the shelf sells
			var/stack_amount = LAZYACCESS(reward_amounts, reward_type)
			if(stack_amount > 1 && ispath(reward_type, /obj/item/stack))
				new reward_type(reward_turf, stack_amount)
			else
				new reward_type(reward_turf)
		flash_reward_anchor(reward_anchor)

	// Research payouts are physical: a dossier the crew has to carry to an R&D
	// console. A ship keeps its techweb on a server disk that may not be
	// installed (or may have been pulled), so paying an atom is the only channel
	// that works for every crew - and it can be stolen off the pad like any prize.
	if(research_reward > 0 && reward_turf)
		new /obj/item/research_notes(reward_turf, research_reward, research_origin)
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

// =========================================================================
// DISPLAY
// =========================================================================

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
 * Returns the UI color for the band the target sits in. Same scale as the
 * difficulty tag, since zone and difficulty move together.
 */
/datum/mission/proc/get_zone_color()
	switch(target_zone_name)
		if(ZONE_NAME_GREEN)
			return "good"
		if(ZONE_NAME_YELLOW)
			return "average"
		if(ZONE_NAME_RED)
			return "bad"
	return "label"

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
 * Returns progress string for display: the current objective's line, or a
 * ready-to-collect note once everything is satisfied.
 */
/datum/mission/proc/get_progress_string()
	var/datum/mission_objective/objective = current_objective()
	if(objective)
		return objective.get_progress_string()
	if(length(objectives))
		return "Ready to turn in"
	return ""

/**
 * Returns mission data for TGUI display.
 */
/datum/mission/proc/get_ui_data()
	// Every reward in the bundle, each with its own sprite and a rarity accent
	var/list/reward_items = list()
	for(var/reward_type in get_reward_types())
		var/atom/reward_cast = reward_type
		var/stack_amount = LAZYACCESS(reward_amounts, reward_type) || 1
		reward_items += list(list(
			"name" = stack_amount > 1 ? "[stack_amount]× [initial(reward_cast.name)]" : initial(reward_cast.name),
			"icon" = icon2base64(icon(initial(reward_cast.icon), initial(reward_cast.icon_state))),
			"rare" = (reward_type in rare_reward_types),
		))
	// First reward mirrored onto the legacy single-reward fields for compatibility
	var/list/first_reward = length(reward_items) ? reward_items[1] : null
	// Per-objective checklist (additive; the board renders progress either way)
	var/list/objective_data = list()
	for(var/datum/mission_objective/objective as anything in objectives)
		objective_data += list(list(
			"text" = objective.get_progress_string(),
			"done" = objective.is_satisfied(),
			"current" = (objective == current_objective()),
		))
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
		"objectives" = objective_data,
		"can_complete" = can_complete(),
		"active" = active,
		"failed" = failed,
		"completed" = completed,
		"difficulty" = difficulty,
		"difficulty_name" = get_difficulty_name(),
		"difficulty_color" = get_difficulty_color(),
		"zone_name" = (target_zone_name == MISSION_ZONE_UNKNOWN) ? null : target_zone_name,
		"zone_color" = get_zone_color(),
		"requires_item" = requires_item,
		"voucher_count" = voucher_count,
		"research_reward" = research_reward,
		"archetype" = get_archetype(),
		"favor_reward" = get_favor_reward(),
		"favor_trader" = shop ? shop.favor_trader_name() : null,
	)
