/**
 * # Mission Objectives
 *
 * One step of a mission. A mission owns an ordered list of these; exactly one
 * is current at a time, and the mission advances when the current objective
 * completes. Each objective owns its own signal hooks, progress text and
 * (when it puts something physical in the world) its field spawns.
 *
 * Objectives that end with the crew handing an item over at the pad or a
 * trader set requires_item and implement the item-offer trio; the mission
 * shell delegates its turn-in interface to whichever objective is current.
 *
 * Cross-cutting state deliberately does NOT live here: the mission target
 * (mission_target.dm) and the tracked quest atom + GPS beacon (the shell)
 * outlive and span objectives, a ruin dying affects every stage at once.
 */
/datum/mission_objective
	/// The mission this objective belongs to (set on add)
	var/datum/mission/mission
	/// Whether this objective is the mission's current, live step
	var/active = FALSE
	/// Whether this objective has been completed
	var/completed = FALSE
	/// Whether completing this step ends with an item offered at the turn-in
	/// point. The mission shell's requires_item mirrors its LAST objective.
	var/requires_item = FALSE

/datum/mission_objective/Destroy()
	if(active)
		deactivate()
	mission = null
	return ..()

/**
 * Rolls this objective's own details at mission generation time.
 * Return FALSE to fail the whole mission's generation.
 */
/datum/mission_objective/proc/generate()
	return TRUE

/**
 * This objective just became the mission's current step (mission is active,
 * servant is set). Register signals and place field spawns here.
 */
/datum/mission_objective/proc/activate()
	active = TRUE

/**
 * The objective stopped being current (completed, mission over, or a
 * retarget reset). Must undo everything activate() did.
 */
/datum/mission_objective/proc/deactivate()
	active = FALSE

/**
 * Marks the objective complete and advances the mission.
 */
/datum/mission_objective/proc/complete()
	if(completed || !mission)
		return
	completed = TRUE
	if(active)
		deactivate()
	mission.on_objective_completed(src)

/**
 * Whether the objective counts as done right now. Event-driven objectives
 * just report their flag; poll-style objectives (escort) override with a
 * live check. Poll-style objectives only work as a mission's LAST step.
 */
/datum/mission_objective/proc/is_satisfied()
	return completed

/**
 * Returns the objective to pristine so a retarget can run it again.
 * Deactivation has already happened by the time this is called.
 */
/datum/mission_objective/proc/reset()
	completed = FALSE

/// One-line progress text for the board UI
/datum/mission_objective/proc/get_progress_string()
	return ""

/**
 * The mission just fully turned in (rewards not yet distributed). Every
 * objective gets this; use it for turn-in side effects like repatriating an
 * escorted survivor or pay bonuses.
 */
/datum/mission_objective/proc/on_turn_in_finalized(atom/reward_anchor)
	return

// ===== ITEM TURN-IN INTERFACE (requires_item objectives only) =====

/// Whether the offered item satisfies this objective right now
/datum/mission_objective/proc/can_turn_in(obj/item/item)
	return FALSE

/// User-facing reason can_turn_in() said no
/datum/mission_objective/proc/describe_turn_in_failure(obj/item/item)
	if(!item)
		return "No item provided."
	return "That item doesn't satisfy this contract."

/**
 * Whether the item is the RIGHT KIND for this ask, ignoring every quantity or
 * quality gate. Turn-in points use it to tell "you're holding nothing like it"
 * apart from "you're holding it but it falls short", so the refusal can name
 * the real shortfall instead of telling someone to hold what they're holding.
 */
/datum/mission_objective/proc/matches_ask(obj/item/item)
	return FALSE

/**
 * Consumes an accepted item and advances the objective. Only called after
 * can_turn_in() passed. Returns MISSION_ITEM_COMPLETE when the objective is
 * finished, MISSION_ITEM_PROGRESS when it still wants more.
 */
/datum/mission_objective/proc/accept_item(obj/item/item, atom/reward_anchor)
	qdel(item)
	complete()
	return MISSION_ITEM_COMPLETE

// ===== CONVENIENCE =====

/// The servant ship, while the mission is active
/datum/mission_objective/proc/get_servant()
	return mission?.servant

/// Shorthand for notifying the servant ship's crew
/datum/mission_objective/proc/notify_crew(message, header = "MISSION UPDATE", type = SHIP_NOTIFY_NOTICE, sound = 'voidcrew/sound/notify.ogg', volume = 50)
	mission?.servant?.ship_notify(message, header, type, sound, volume)
