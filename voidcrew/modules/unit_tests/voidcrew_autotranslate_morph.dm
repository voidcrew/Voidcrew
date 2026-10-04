/**
 * # text_morph releases its looping frame timer when it completes
 *
 * Prod rounds 16-19 (2026-08-27/28): every /datum/text_morph left its TIMER_LOOP frame
 * timer alive. complete() runs INSIDE that timer's own callback, when SStimer has already
 * marked the timer spent, and both deltimer() and /datum/Destroy()'s _active_timers sweep
 * refuse a spent timer unless it carries TIMER_DELETE_ME. The orphaned timer pinned the
 * morph (565 of 567 qdels hard-deleted in round 17), then kept firing every tick with a
 * null callback object: ~8,000 runtimes a second, 160M+ per round, all hidden behind the
 * flood breaker. This drives a real morph through SStimer and checks the timer is gone.
 */
/datum/unit_test/voidcrew_autotranslate_morph
	var/frames = 0
	var/finished = FALSE

/datum/unit_test/voidcrew_autotranslate_morph/Run()
	var/datum/text_morph/morph = new(
		"hello there",
		"привет мир",
		CALLBACK(src, PROC_REF(on_frame)),
		CALLBACK(src, PROC_REF(on_finish)),
		0.3 SECONDS
	)
	morph.start()
	var/timer_id = morph.timer_id
	TEST_ASSERT(timer_id, "text_morph.start() did not create a frame timer")
	TEST_ASSERT_NOTNULL(SStimer.timer_id_dict[timer_id], "frame timer is not registered with SStimer")

	// Let the real timer subsystem drive the animation to completion, so complete()
	// runs from inside the timer callback exactly as it does in a live round.
	var/deadline = world.time + 5 SECONDS
	while(!finished && world.time < deadline)
		sleep(world.tick_lag)

	TEST_ASSERT(finished, "morph never invoked on_finish within 5 seconds")
	TEST_ASSERT(frames >= 2, "morph emitted [frames] frame(s); the timer should have driven at least one frame after the initial one")
	TEST_ASSERT(QDELETED(morph), "text_morph did not qdel itself after completing")
	TEST_ASSERT_NULL(SStimer.timer_id_dict[timer_id], "text_morph's frame timer survived completion - without TIMER_DELETE_ME it outlives the morph, forces a hard delete, and runtimes every tick")

/datum/unit_test/voidcrew_autotranslate_morph/proc/on_frame(frame)
	frames++

/datum/unit_test/voidcrew_autotranslate_morph/proc/on_finish()
	finished = TRUE
