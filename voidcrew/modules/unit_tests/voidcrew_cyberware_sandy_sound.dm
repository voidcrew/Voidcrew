/**
 * # What a Sandevistan sounds like
 *
 * voidcrew/modules/cyberware/ware_sandy_sound.dm. The user hears his surge come on, a loop for as long as his slow-mo
 * runs and a rush as he bursts into movement from standing in it, all to him alone and none of it recorded for the
 * replay. Everyone else near hears a short snap from his tile as he surges and bursts off, and the replay's viewers
 * hear it as the replay starts and as his replayed self bursts off after a pause.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so the sound files are written out. "external" stands for any of
 * the snap's files.
 */
/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound
	abstract_type = /datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound

/// Whether `heard` is `file`, or any of the snap's files for "external"
/datum/unit_test/voidcrew_cyberware_timestop/proc/is_file(sound/heard, file)
	if(file == "external")
		return heard.file in list('voidcrew/sound/cyberware/sandevistan_external_1.ogg', 'voidcrew/sound/cyberware/sandevistan_external_2.ogg', 'voidcrew/sound/cyberware/sandevistan_external_3.ogg')
	return heard.file == file

/// The cues of `file` sent to `listener`, as /sound datums
/datum/unit_test/voidcrew_cyberware_timestop/proc/cues(mob/listener, file)
	. = list()
	for(var/list/entry as anything in GLOB.sandy_cues_sent)
		var/sound/cue = entry[2]
		if(entry[1] == listener && cue.file && is_file(cue, file))
			. += cue

/// The stops sent to `listener` on `channel`
/datum/unit_test/voidcrew_cyberware_timestop/proc/stops(mob/listener, channel)
	. = 0
	for(var/list/entry as anything in GLOB.sandy_cues_sent)
		var/sound/cue = entry[2]
		if(entry[1] == listener && !cue.file && cue.channel == channel)
			.++

/// The channel the loop went out on to `user` (asserts it went out once, looping)
/datum/unit_test/voidcrew_cyberware_timestop/proc/loop_channel(mob/user)
	var/list/loops = cues(user, 'voidcrew/sound/cyberware/sandevistan_loop.ogg')
	TEST_ASSERT_EQUAL(length(loops), 1, "The slow-mo's loop didn't go out once to its user")
	var/sound/loop = loops[1]
	TEST_ASSERT(loop.repeat && loop.channel, "The loop isn't repeating on a channel of its own")
	return loop.channel

/// On a surge the user hears it come on and the slow-mo's loop, a bystander the snap; neither hears the other's, and
/// none of it is recorded. A second press stops the loop.
/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/surge

/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/surge/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandysoundsurge")
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, spot(3, 0))
	set_window(user, 2 SECONDS)
	GLOB.sandy_cues_sent.Cut()
	var/datum/sandy_replay/replay = start_recording(user)
	TEST_ASSERT_EQUAL(length(cues(user, 'voidcrew/sound/cyberware/sandevistan_activation.ogg')), 1, "The user didn't hear his surge come on")
	TEST_ASSERT_EQUAL(length(cues(user, "external")), 0, "The user heard his own snap")
	TEST_ASSERT_EQUAL(length(cues(bystander, "external")), 1, "A bystander didn't hear the snap")
	TEST_ASSERT_EQUAL(length(cues(bystander, 'voidcrew/sound/cyberware/sandevistan_activation.ogg')), 0, "A bystander heard the user's own surge")
	TEST_ASSERT_EQUAL(length(cues(bystander, 'voidcrew/sound/cyberware/sandevistan_loop.ogg')), 0, "A bystander heard the user's loop")
	var/sound/snap = cues(bystander, "external")[1]
	TEST_ASSERT(snap.x == -3 && snap.z == 0, "The snap wasn't placed at the surger's tile ([snap.x], [snap.z])")
	TEST_ASSERT(snap.frequency >= 0.94 && snap.frequency <= 1.06, "The snap's pitch ([snap.frequency]) went past its spread")
	var/channel = loop_channel(user)
	sleep(0.5 SECONDS)
	TEST_ASSERT(user.Move(spot(1, 0), EAST), "Test fixture: the user couldn't step")
	for(var/list/heard as anything in replay.sounds)
		TEST_ASSERT(!findtext("[heard[3]]", "sandevistan"), "A Sandevistan cue ([heard[3]]) was recorded for the replay")
	press_again(user)
	TEST_ASSERT_EQUAL(stops(user, channel), 1, "The loop wasn't stopped when the slow-mo ended")
	wait_over(user)
	TEST_ASSERT_EQUAL(stops(user, channel), 1, "The loop was stopped twice")

/// In his slow-mo the user hears the step when he bursts off from standing, never again within 1.5 s of it; others
/// hear the snap at most every 0.4 s
/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/steps

/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/steps/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandysoundsteps")
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, spot(0, 3))
	set_window(user, 4 SECONDS)
	start_recording(user)
	GLOB.sandy_cues_sent.Cut()
	sleep(0.4 SECONDS)
	for(var/dx in 1 to 3)
		TEST_ASSERT(user.Move(spot(dx, 0), EAST), "Test fixture: the user couldn't step")
	TEST_ASSERT_EQUAL(length(cues(user, 'voidcrew/sound/cyberware/sandevistan_step.ogg')), 1, "Bursting off from standing didn't cue the step once")
	TEST_ASSERT_EQUAL(length(cues(bystander, "external")), 1, "Bursting off from standing didn't cue the snap once")
	TEST_ASSERT_EQUAL(length(cues(bystander, 'voidcrew/sound/cyberware/sandevistan_step.ogg')), 0, "A bystander heard the user's step")
	var/sound/step = cues(user, 'voidcrew/sound/cyberware/sandevistan_step.ogg')[1]
	TEST_ASSERT(step.frequency >= 0.92 && step.frequency <= 1.08, "The step's pitch ([step.frequency]) went past its spread")
	sleep(0.5 SECONDS)
	TEST_ASSERT(user.Move(spot(4, 0), EAST), "Test fixture: the user couldn't step")
	TEST_ASSERT_EQUAL(length(cues(user, 'voidcrew/sound/cyberware/sandevistan_step.ogg')), 1, "The step cued again within 1.5 s of the last")
	TEST_ASSERT_EQUAL(length(cues(bystander, "external")), 2, "A burst off past 0.4 s didn't cue the snap again")
	sleep(1.1 SECONDS)
	user.forceMove(spot(5, 0))
	TEST_ASSERT_EQUAL(length(cues(user, 'voidcrew/sound/cyberware/sandevistan_step.ogg')), 1, "A forced move cued a step")
	sleep(0.4 SECONDS)
	TEST_ASSERT(user.Move(spot(6, 0), EAST), "Test fixture: the user couldn't step")
	TEST_ASSERT_EQUAL(length(cues(user, 'voidcrew/sound/cyberware/sandevistan_step.ogg')), 2, "Bursting off from standing 1.5 s after the last step didn't cue it again")
	press_again(user)
	wait_over(user)

/// The loop stops when the user dies, and nothing stops it a second time
/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/loop_stops_on_death

/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/loop_stops_on_death/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandysoundloopdie")
	set_window(user, 2 SECONDS)
	GLOB.sandy_cues_sent.Cut()
	start_recording(user)
	var/channel = loop_channel(user)
	user.death()
	TEST_ASSERT_EQUAL(stops(user, channel), 1, "The loop wasn't stopped when the user died")
	wait_over(user)
	TEST_ASSERT_EQUAL(stops(user, channel), 1, "The loop was stopped twice")

/// The loop stops when the user logs out, and the slow-mo's end doesn't stop it again
/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/loop_stops_on_logout

/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/loop_stops_on_logout/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandysoundlooplogout")
	set_window(user, 2 SECONDS)
	GLOB.sandy_cues_sent.Cut()
	start_recording(user)
	var/channel = loop_channel(user)
	SEND_SIGNAL(user, COMSIG_MOB_LOGOUT)
	TEST_ASSERT_EQUAL(stops(user, channel), 1, "The loop wasn't stopped when the user logged out")
	press_again(user)
	wait_over(user)
	TEST_ASSERT_EQUAL(stops(user, channel), 1, "The loop was stopped twice")

/// The replay plays the snap to its viewers as it starts, where the user began, and where the replayed user bursts off
/// after a pause, placed from their view and not from his real body, and not again for every step after it
/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/replay_snap

/datum/unit_test/voidcrew_cyberware_timestop/replay/sandy_sound/replay_snap/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandysoundreplay")
	set_window(user, 3 SECONDS)
	start_recording(user)
	TEST_ASSERT(user.Move(spot(1, 0), EAST), "Test fixture: the user couldn't step")
	sleep(0.6 SECONDS)
	for(var/dx in 2 to 4)
		TEST_ASSERT(user.Move(spot(dx, 0), EAST), "Test fixture: the user couldn't step")
		sleep(0.3 SECONDS)
	GLOB.sandy_replay_heard.Cut()
	var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
	press_again(user)
	// A view off to one side; a client's would follow the replayed self.
	replay.eye = new /obj/effect/abstract/sandy_replay_eye(spot(0, 1))
	wait_over(user)
	var/list/heard = list()
	for(var/list/entry as anything in GLOB.sandy_replay_heard)
		if(entry[1] == user && is_file(entry[2], "external"))
			heard += entry[2]
	TEST_ASSERT_EQUAL(length(heard), 2, "The replay's viewer didn't hear the snap at its start and once at the burst after the pause")
	var/sound/start = heard[1]
	var/sound/burst = heard[2]
	// The start plays as the replay opens, while the view stands on where the user began (not on his body, at (4, 0)).
	TEST_ASSERT(start.x == 0 && start.z == 0, "The replay's start snap was placed at ([start.x], [start.z]), not where the user began (0, 0)")
	TEST_ASSERT(burst.x == 1 && burst.z == -1, "The burst snap was placed at ([burst.x], [burst.z]), not where the replayed user burst off from the view (1, -1)")
	TEST_ASSERT(burst.volume > 60, "The burst snap played at [burst.volume], not at full volume")

/// In a shared slow-mo each member hears the other's snap, never his own, and his own loop ends when his time is out
/datum/unit_test/voidcrew_cyberware_timestop/shared/sandy_sound

/datum/unit_test/voidcrew_cyberware_timestop/shared/sandy_sound/Run()
	var/mob/living/carbon/human/first = make_user(spot(0, 0), "sandysoundone")
	var/mob/living/carbon/human/second = make_user(spot(3, 0), "sandysoundtwo")
	make_crew(list(first, second))
	set_window(first, 3 SECONDS)
	set_window(second, 3 SECONDS)
	var/datum/status_effect/cyberware_cascade_window/one = surge(first)
	sleep(0.2 SECONDS)
	GLOB.sandy_cues_sent.Cut()
	surge(second)
	sleep(0.3 SECONDS)
	TEST_ASSERT_NOTNULL(session_of(first), "Test fixture: the two slow-mos didn't join")
	TEST_ASSERT_EQUAL(length(cues(first, "external")), 1, "A member didn't hear his crewmate surge")
	TEST_ASSERT_EQUAL(length(cues(second, "external")), 0, "A member heard his own snap")
	TEST_ASSERT_EQUAL(length(cues(first, 'voidcrew/sound/cyberware/sandevistan_activation.ogg')), 0, "A member heard his crewmate's own surge")
	var/channel = loop_channel(second)
	sleep(0.2 SECONDS)
	TEST_ASSERT(second.Move(spot(4, 0), EAST), "Test fixture: the member couldn't step")
	TEST_ASSERT_EQUAL(length(cues(first, "external")), 2, "A member didn't hear his crewmate burst off")
	TEST_ASSERT_EQUAL(length(cues(second, "external")), 0, "A member heard his own snap as he burst off")
	var/datum/action/cooldown/cyberware/cascade_surge/button = surge_button(second)
	TEST_ASSERT(button.Trigger(), "The second press did nothing")
	TEST_ASSERT_NOTNULL(one.time_stop, "Test fixture: one member dropping out ended the shared slow-mo")
	TEST_ASSERT_EQUAL(stops(second, channel), 1, "The loop of a member whose time is out didn't stop")
	qdel(one)
	sleep(0.1 SECONDS)
	wait_replay(first)
	TEST_ASSERT_EQUAL(stops(second, channel), 1, "The loop was stopped twice")
	first.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	second.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
