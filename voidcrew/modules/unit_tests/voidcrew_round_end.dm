/// REALTIMEOFDAY reads the clock on every use, so real-time checks allow a couple of deciseconds.
#define ROUND_END_NEAR(actual, expected) (abs((actual) - (expected)) <= 2)

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
	for(var/alert_timer in SSovermap.jump_alert_timers)
		deltimer(alert_timer)
	SSovermap.jump_alert_timers = list()
	SSovermap.jump_launch_time = null
	SSovermap.round_end_time = null
	SSovermap.jump_mode = 0 // BS_JUMP_IDLE; Voidcrew defines follow test includes.

/// Whether a timer runs on real time rather than world.time.
/datum/unit_test/voidcrew_round_end/proc/is_real_time(timer_id)
	var/datum/timedevent/timer = SStimer.timer_id_dict[timer_id]
	return timer && (timer.flags & TIMER_CLIENT_TIME)

/// Body of the newest station announcement, or null.
/datum/unit_test/voidcrew_round_end/proc/last_announcement()
	for(var/datum/feed_channel/channel as anything in GLOB.news_network.network_channels)
		if(channel.channel_name == NEWSCASTER_STATION_ANNOUNCEMENTS && length(channel.messages))
			var/datum/feed_message/message = channel.messages[length(channel.messages)]
			return message.body

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
	for(var/field in list("jump_timer", "jump_mode", "round_end_time", "round_end_request_timer", "round_end_timer", "jump_launch_time", "jump_alert_timers"))
		saved_overmap[field] = SSovermap.vars[field]
		SSovermap.vars[field] = null
	SSovermap.jump_alert_timers = list()
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
	var/real_now = REALTIMEOFDAY
	SSovermap.arm_round_end(SSticker, started_at)
	TEST_ASSERT(ROUND_END_NEAR(SSovermap.round_end_time, real_now - (5 MINUTES) + (360 MINUTES)), "Deadline must be six real hours after the actual roundstart, not world start or lobby time")
	TEST_ASSERT(is_real_time(SSovermap.round_end_timer), "Completion must run on real time, not world.time")
	TEST_ASSERT(is_real_time(SSovermap.round_end_request_timer), "The first warning must run on real time, not world.time")
	TEST_ASSERT(ROUND_END_NEAR(REALTIMEOFDAY + timeleft(SSovermap.round_end_timer), SSovermap.round_end_time), "Completion was not armed at the six-hour deadline")
	TEST_ASSERT(ROUND_END_NEAR(REALTIMEOFDAY + timeleft(SSovermap.round_end_request_timer), SSovermap.round_end_time - (12 MINUTES)), "Fleet preparation must start twelve minutes before the deadline")
	TEST_ASSERT_NULL(SSovermap.jump_countdown_text(), "The countdown must not show before the first warning")
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
	real_now = REALTIMEOFDAY
	SSovermap.arm_round_end(SSticker, world.time - (5 MINUTES))
	TEST_ASSERT(ROUND_END_NEAR(SSovermap.round_end_time, real_now + (25 MINUTES)), "Config duration was not applied")
	TEST_ASSERT(ROUND_END_NEAR(REALTIMEOFDAY + timeleft(SSovermap.round_end_request_timer), real_now + (13 MINUTES)), "Config duration did not move the fleet preparation")
	clear_schedule()

	// The whole departure from the first warning: T-12 warning, T-7 and T-3 alerts, T-2 launch, T-0 end.
	real_now = REALTIMEOFDAY
	SSovermap.arm_round_end(SSticker, world.time - (18 MINUTES))
	TEST_ASSERT(ROUND_END_NEAR(SSovermap.round_end_time, real_now + (12 MINUTES)), "Deadline missed for a round eighteen minutes in")
	TEST_ASSERT(timeleft(SSovermap.round_end_request_timer) <= 2, "The first warning must be due twelve minutes before the end")
	deltimer(SSovermap.round_end_request_timer)
	var/articles = GLOB.news_network.message_count
	SSovermap.request_scheduled_jump()
	TEST_ASSERT_EQUAL(GLOB.news_network.message_count, articles + 1, "The first warning was not announced")
	var/announced = last_announcement()
	if(announced)
		TEST_ASSERT(findtext(announced, "fleet jump in 10 minutes"), "Unexpected first warning: [announced]")
	TEST_ASSERT(ROUND_END_NEAR(SSovermap.jump_launch_time, SSovermap.round_end_time - (2 MINUTES)), "Launch must come two minutes before the end")
	TEST_ASSERT(is_real_time(SSovermap.jump_timer), "The launch must run on real time, not world.time")
	TEST_ASSERT(ROUND_END_NEAR(REALTIMEOFDAY + timeleft(SSovermap.jump_timer), SSovermap.jump_launch_time), "The launch timer does not match the countdown")
	TEST_ASSERT_EQUAL(length(SSovermap.jump_alert_timers), 2, "The five- and one-minute alerts were not both scheduled")
	TEST_ASSERT(is_real_time(SSovermap.jump_alert_timers[1]), "The alerts must run on real time, not world.time")
	TEST_ASSERT(ROUND_END_NEAR(REALTIMEOFDAY + timeleft(SSovermap.jump_alert_timers[1]), SSovermap.jump_launch_time - (5 MINUTES)), "The red alert must play five minutes before launch")
	TEST_ASSERT(ROUND_END_NEAR(REALTIMEOFDAY + timeleft(SSovermap.jump_alert_timers[2]), SSovermap.jump_launch_time - (1 MINUTES)), "The last alert must play one minute before launch")
	var/countdown = SSovermap.jump_countdown_text()
	TEST_ASSERT(countdown == "Fleet Jump: 10:00" || findtext(countdown, "Fleet Jump: 09:5") == 1, "The countdown must start at the first warning (got [countdown])")
	var/mob/living/carbon/human/consistent/viewer = allocate(/mob/living/carbon/human/consistent)
	var/shown = FALSE
	for(var/line in viewer.get_status_tab_items())
		if(findtext("[line]", "Fleet Jump: "))
			shown = TRUE
	TEST_ASSERT(shown, "The countdown is missing from the status panel")
	articles = GLOB.news_network.message_count
	SSovermap.jump_alert(5 MINUTES)
	TEST_ASSERT_EQUAL(GLOB.news_network.message_count, articles + 1, "The five-minute alert did not play")
	announced = last_announcement()
	if(announced)
		TEST_ASSERT(findtext(announced, "fleet jump in 5 minutes"), "Unexpected five-minute alert: [announced]")
	// A server that slept through the alerts wakes with all of them due: only the newest one plays.
	SSovermap.jump_launch_time = REALTIMEOFDAY + (30 SECONDS)
	articles = GLOB.news_network.message_count
	SSovermap.jump_alert(5 MINUTES)
	TEST_ASSERT_EQUAL(GLOB.news_network.message_count, articles, "An overtaken five-minute alert still played")
	SSovermap.jump_alert(1 MINUTES)
	TEST_ASSERT_EQUAL(GLOB.news_network.message_count, articles + 1, "The one-minute alert did not play")
	TEST_ASSERT(SSovermap.cancel_jump(FALSE), "Admins must be able to cancel an announced departure")
	TEST_ASSERT_NULL(SSovermap.jump_countdown_text(), "Cancellation left the countdown running")
	TEST_ASSERT_EQUAL(length(SSovermap.jump_alert_timers), 0, "Cancellation left departure alerts armed")

	// Simulate a delayed preparation callback: both later stages retain absolute deadlines.
	SSovermap.arm_round_end(SSticker, world.time - (19 MINUTES))
	deltimer(SSovermap.round_end_request_timer)
	SSovermap.request_scheduled_jump()
	TEST_ASSERT(ROUND_END_NEAR(REALTIMEOFDAY + timeleft(SSovermap.jump_timer), SSovermap.round_end_time - SSovermap.jump_completion_time), "Late preparation must not push launch back")
	TEST_ASSERT_EQUAL(length(SSovermap.jump_alert_timers), 2, "Nine minutes before launch still leaves room for both alerts")
	original_timer = SSovermap.jump_timer
	TEST_ASSERT(!SSovermap.request_jump(), "A second request must not reset an announced departure")
	TEST_ASSERT_EQUAL(SSovermap.jump_timer, original_timer, "A repeated request replaced the launch timer")
	TEST_ASSERT(SSovermap.cancel_jump(FALSE), "Admins must be able to cancel an announced departure")
	TEST_ASSERT_NULL(SSovermap.jump_timer, "Cancellation left a launch armed")

	CONFIG_SET(number/round_time_limit, 1)
	SSovermap.arm_round_end(SSticker, world.time)
	TEST_ASSERT(timeleft(SSovermap.round_end_request_timer) <= 1, "Short configurations must begin departure on the next timer tick")
	deltimer(SSovermap.round_end_request_timer)
	SSovermap.request_scheduled_jump()
	TEST_ASSERT(timeleft(SSovermap.jump_timer) <= 1, "A short round must not wait the normal ten-minute preparation")
	TEST_ASSERT_EQUAL(length(SSovermap.jump_alert_timers), 0, "A short round has no time for departure alerts")
	deltimer(SSovermap.jump_timer)
	original_timer = SSovermap.round_end_timer
	SSovermap.initiate_jump()
	TEST_ASSERT_EQUAL(SSovermap.round_end_timer, original_timer, "Launching ships must not replace the absolute completion timer")
	TEST_ASSERT_NULL(SSovermap.jump_countdown_text(), "The countdown must stop at launch")
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

#undef ROUND_END_NEAR
