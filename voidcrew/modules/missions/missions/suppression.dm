/**
 * # Pirate Suppression Sweep
 *
 * "The lane's crawling. Thin out eight pirates anywhere in the Contested
 * Zone - we pay per confirmed transponder."
 *
 * A counter mission with a kill verb: one kill_count objective listening for
 * faction-pirate deaths galaxy-wide, credited to the crew and gated to
 * yellow/red space so green farming can't happen. Auto-completable at the
 * board like a survey - no item turn-in.
 */
/datum/mission/suppression
	name = "Suppression Sweep"
	weight = 8
	mission_limit = 2
	voucher_count = 1

	/// Kills asked for
	var/required_kills = 8
	/// Zone floor the kills must happen in (kills in deeper zones also count)
	var/minimum_zone = ZONE_YELLOW
	/// The counter objective, for text
	var/datum/mission_objective/kill_count/counter

/datum/mission/suppression/Destroy()
	counter = null
	return ..()

/datum/mission/suppression/get_archetype()
	return "bounty"

/datum/mission/suppression/generate_details()
	// Two flavors: a yellow-zone sweep, or a shorter, richer red-zone purge
	if(prob(30))
		minimum_zone = ZONE_RED
		required_kills = rand(5, 7)
		value_min = 1800
		value_max = 2600
		difficulty = MISSION_DIFFICULTY_HARD
		target_zone_name = ZONE_NAME_RED
	else
		minimum_zone = ZONE_YELLOW
		required_kills = rand(7, 10)
		value_min = 1100
		value_max = 1600
		difficulty = MISSION_DIFFICULTY_MEDIUM
		target_zone_name = ZONE_NAME_YELLOW

/datum/mission/suppression/build_objectives()
	counter = new
	counter.required_kills = required_kills
	counter.minimum_zone = minimum_zone
	add_objective(counter)

/datum/mission/suppression/update_text()
	name = "Suppression Sweep: [target_zone_name]"
	desc = "Confirm [required_kills] pirate faction NPC kills in the [target_zone_name][minimum_zone == ZONE_YELLOW ? " or deeper" : ""] after accepting this contract. \
		Your crew must make the kill or have a living member nearby to confirm it. Player pirates and destroyed ships do not count. \
		Complete the full quota, then collect the contract payment at the mission board. Includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]."
