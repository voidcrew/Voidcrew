/**
 * This sets the overflow role, and maxes out its job positions.
 * We instead use the job overflow to show what is the 'Captain' job of the roundstart template.
 * Therefore, we don't want to use this, we instead manually set it on `/datum/job/map_check()`
 */
/datum/controller/subsystem/job/set_overflow_role(new_overflow_role)
	return

/**
 * Voidcrew override: Skip standard TG job assignment.
 * We assign jobs in create_characters() based on ship job slots and category preferences.
 * This proc is called during roundstart but we handle job assignment ourselves.
 */
/datum/controller/subsystem/job/divide_occupations(pure = FALSE, allow_all = FALSE)
	// Still send the signal for anything that listens to it
	run_divide_occupation_pure = pure
	SEND_SIGNAL(src, COMSIG_OCCUPATIONS_DIVIDED, pure, allow_all)

	// Count ready players for logging
	var/ready_count = 0
	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		if(player.ready == PLAYER_READY_TO_PLAY && player.mind)
			ready_count++

	job_debug("VOIDCREW DO: Skipping standard job assignment. [ready_count] ready players will be assigned in create_characters().")
	run_divide_occupation_pure = FALSE
	return TRUE
