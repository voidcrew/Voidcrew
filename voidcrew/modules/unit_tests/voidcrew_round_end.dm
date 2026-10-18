/// Exercise real scheduling without constructing another subsystem or waiting for the timers.
/datum/unit_test/voidcrew_round_end
	var/list/saved_overmap
	var/list/saved_ticker
	var/saved_limit
	var/saved_transfer
	var/saved_nuked
	var/list/saved_ports

/datum/unit_test/voidcrew_round_end/proc/clear_schedule()
	for(var/field in list("jump_timer", "round_end_request_timer", "round_end_timer"))
		if(SSovermap.vars[field])
			deltimer(SSovermap.vars[field])
			SSovermap.vars[field] = null
	SSovermap.round_end_time = null
	SSovermap.jump_mode = 0 // BS_JUMP_IDLE; Voidcrew defines follow test includes.

/datum/unit_test/voidcrew_round_end/Destroy()
	if(saved_overmap)
		clear_schedule()
		for(var/field in saved_overmap)
			SSovermap.vars[field] = saved_overmap[field]
		for(var/field in saved_ticker)
			SSticker.vars[field] = saved_ticker[field]
		CONFIG_SET(number/round_time_limit, saved_limit)
		CONFIG_SET(flag/allow_vote_transfer, saved_transfer)
		GLOB.station_was_nuked = saved_nuked
		SSshuttle.mobile_docking_ports = saved_ports
	saved_overmap = null
	saved_ticker = null
	saved_ports = null
	return ..()

/datum/unit_test/voidcrew_round_end/Run()
	saved_limit = CONFIG_GET(number/round_time_limit)
	saved_transfer = CONFIG_GET(flag/allow_vote_transfer)
	saved_nuked = GLOB.station_was_nuked
	saved_ports = SSshuttle.mobile_docking_ports
	saved_overmap = list()
	for(var/field in list("jump_timer", "jump_mode", "round_end_time", "round_end_request_timer", "round_end_timer"))
		saved_overmap[field] = SSovermap.vars[field]
		SSovermap.vars[field] = null
	saved_ticker = list()
	for(var/field in list("current_state", "force_ending", "round_start_time", "roundend_check_paused", "setup_done"))
		saved_ticker[field] = SSticker.vars[field]
	SSovermap.jump_mode = 0 // BS_JUMP_IDLE
	// Prevent any completion report or movement of real ships from this test.
	SSticker.current_state = GAME_STATE_FINISHED
	SSticker.setup_done = TRUE
	SSshuttle.mobile_docking_ports = list()
	var/datum/config_entry/number/round_time_limit/entry = config.entries_by_type[/datum/config_entry/number/round_time_limit]
	TEST_ASSERT_EQUAL(initial(entry.default), 360, "Untouched server configs must default to six hours")
	CONFIG_SET(number/round_time_limit, initial(entry.default))
	CONFIG_SET(flag/allow_vote_transfer, TRUE)
	var/datum/vote/transfer_vote/vote = allocate(/datum/vote/transfer_vote)
	SSticker.current_state = GAME_STATE_PREGAME
	TEST_ASSERT(!vote.is_config_enabled(), "A lobby transfer vote must not get ahead of the automatic schedule")
	TEST_ASSERT_NOTEQUAL(vote.can_be_initiated(TRUE), VOTE_AVAILABLE, "A forced lobby vote must not get ahead of the automatic schedule")
	SSticker.current_state = GAME_STATE_FINISHED
	var/started_at = world.time - (5 MINUTES)
	SSticker.round_start_time = started_at
	SSovermap.arm_round_end(SSticker, started_at)
	TEST_ASSERT_EQUAL(SSovermap.round_end_time, started_at + (360 MINUTES), "Deadline must use actual roundstart, not world start or lobby time")
	TEST_ASSERT_EQUAL(world.time + timeleft(SSovermap.round_end_timer), SSovermap.round_end_time, "Completion was not armed at the six-hour deadline")
	TEST_ASSERT_EQUAL(world.time + timeleft(SSovermap.round_end_request_timer), started_at + (348 MINUTES), "Fleet preparation must start twelve minutes before the deadline")
	var/original_timer = SSovermap.round_end_timer
	SSovermap.arm_round_end(SSticker, world.time)
	TEST_ASSERT_EQUAL(SSovermap.round_end_timer, original_timer, "Repeated start signals must not extend the round")
	TEST_ASSERT(!SSovermap.request_jump(), "A transfer vote must not bring the fleet jump forward")
	TEST_ASSERT(!vote.is_config_enabled(), "Transfer voting must be hidden while a fixed departure is armed")
	TEST_ASSERT_NOTEQUAL(vote.can_be_initiated(FALSE), VOTE_AVAILABLE, "Players must not start a transfer vote during a timed round")
	TEST_ASSERT_NOTEQUAL(vote.can_be_initiated(TRUE), VOTE_AVAILABLE, "A forced transfer vote must not replace the fixed departure")
	// Ordinary end conditions and player restart votes cannot shorten a timed round.
	GLOB.station_was_nuked = TRUE
	TEST_ASSERT(!SSticker.check_finished(), "A station event must not end a timed round early")
	SSticker.force_ending = FORCE_END_ROUND
	SSticker.fire()
	TEST_ASSERT_EQUAL(SSticker.force_ending, END_ROUND_AS_NORMAL, "An ordinary forced ending must defer to the fixed deadline")
	SSticker.force_ending = ADMIN_FORCE_END_ROUND
	SSticker.fire()
	TEST_ASSERT_EQUAL(SSticker.force_ending, ADMIN_FORCE_END_ROUND, "Explicit admin endings must remain available")
	TEST_ASSERT(SSovermap.cancel_jump(FALSE), "Admins must be able to cancel before the first announcement")
	TEST_ASSERT_NULL(SSovermap.round_end_time, "Cancellation left an active deadline")
	TEST_ASSERT_NULL(SSovermap.round_end_request_timer, "Cancellation left a fleet request armed")
	TEST_ASSERT_NULL(SSovermap.round_end_timer, "Cancellation left completion armed")
	TEST_ASSERT(vote.is_config_enabled(), "Cancellation must restore transfer voting")
	TEST_ASSERT(SSticker.check_finished(), "Cancellation must restore normal event endings")

	CONFIG_SET(number/round_time_limit, 30)
	started_at = world.time - (5 MINUTES)
	SSovermap.arm_round_end(SSticker, started_at)
	TEST_ASSERT_EQUAL(SSovermap.round_end_time, started_at + (30 MINUTES), "Config duration was not applied")
	TEST_ASSERT_EQUAL(world.time + timeleft(SSovermap.round_end_request_timer), started_at + (18 MINUTES), "Config duration did not move the fleet preparation")
	clear_schedule()
	// Simulate a delayed preparation callback: both later stages retain absolute deadlines.
	started_at = world.time - (19 MINUTES)
	SSovermap.arm_round_end(SSticker, started_at)
	deltimer(SSovermap.round_end_request_timer)
	SSovermap.request_scheduled_jump()
	TEST_ASSERT_EQUAL(world.time + timeleft(SSovermap.jump_timer), SSovermap.round_end_time - SSovermap.jump_completion_time, "Late preparation must not push launch back")
	original_timer = SSovermap.jump_timer
	TEST_ASSERT(!SSovermap.request_jump(), "A second request must not reset an announced departure")
	TEST_ASSERT_EQUAL(SSovermap.jump_timer, original_timer, "A repeated request replaced the launch timer")
	TEST_ASSERT(SSovermap.cancel_jump(FALSE), "Admins must be able to cancel an announced departure")
	TEST_ASSERT_NULL(SSovermap.jump_timer, "Cancellation left a launch armed")

	CONFIG_SET(number/round_time_limit, 1)
	SSovermap.arm_round_end(SSticker, world.time)
	TEST_ASSERT_EQUAL(timeleft(SSovermap.round_end_request_timer), world.tick_lag, "Short configurations must begin departure on the next timer tick")
	deltimer(SSovermap.round_end_request_timer)
	SSovermap.request_scheduled_jump()
	TEST_ASSERT_EQUAL(timeleft(SSovermap.jump_timer), world.tick_lag, "A short round must not wait the normal ten-minute preparation")
	deltimer(SSovermap.jump_timer)
	original_timer = SSovermap.round_end_timer
	SSovermap.initiate_jump()
	TEST_ASSERT_EQUAL(SSovermap.round_end_timer, original_timer, "Launching ships must not replace the absolute completion timer")
	TEST_ASSERT(!SSovermap.cancel_jump(FALSE), "A launched fleet must retain the existing no-cancellation rule")
	deltimer(SSovermap.round_end_timer)
	SSovermap.complete_jump()
	TEST_ASSERT_EQUAL(SSovermap.jump_mode, 3, "Completion must use BS_JUMP_COMPLETED")
	TEST_ASSERT(SSticker.check_finished(), "A completed jump must trigger normal round completion")
	clear_schedule()
	CONFIG_SET(number/round_time_limit, 0)
	SSovermap.arm_round_end(SSticker, world.time)
	TEST_ASSERT_NULL(SSovermap.round_end_time, "Zero must disable the automatic deadline")
	TEST_ASSERT_NULL(SSovermap.round_end_request_timer, "Zero must not arm fleet preparation")
	TEST_ASSERT_NULL(SSovermap.round_end_timer, "Zero must not arm completion")
	TEST_ASSERT(vote.is_config_enabled(), "Untimed rounds must retain transfer votes")
	TEST_ASSERT_EQUAL(vote.can_be_initiated(FALSE), VOTE_AVAILABLE, "Disabling the deadline must restore the current transfer vote API")
