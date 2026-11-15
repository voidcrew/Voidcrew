/**
 * # How a Sandevistan replay's recording ends, and how the replay hands back
 *
 * voidcrew/modules/cyberware/ware_sandy_replay.dm. A death that ends the slow-mo is recorded to the end of its fall, a
 * thing the game moves under the replay stays drawn where its frame has it, a body's held pose carries on after the
 * replay, and a flash of light in the field is lit again in the replay and put out after it.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so literals stand in for the module's defines: the replay's states
 * are 1 recording, 2 about to play, 3 playing; a frame is 6 entries of a track's frames list (index, look, x, y, z, dir).
 */

/// The user is shot dead in the slow-mo with a blow heavy enough to slide the corpse a tile. The recording goes on until
/// it has slid, so the replay's last frame has it where it lies, and the slide leaves no trail.
/datum/unit_test/voidcrew_cyberware_timestop/replay/user_slides_dead

/datum/unit_test/voidcrew_cyberware_timestop/replay/user_slides_dead/Run()
	var/mob/living/carbon/human/user = make_user(spot(1, 1), "sandyreplayslide")
	set_window(user, 3 SECONDS)
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.6 SECONDS)
	// The killing blow, as hyperviolence notes a hit in the tick it lands: heavy, from the west.
	user.hv_vis_hit_time = world.time
	user.hv_vis_hit_dir = EAST
	user.hv_vis_hit_damage = 60
	user.death() // ends the slow-mo there and then
	TEST_ASSERT(user.hv_vis_slide_due, "Test fixture: the death queued no slide across a tile")
	TEST_ASSERT_EQUAL(replay.state, 1, "The recording stopped before the dead user's body slid")
	TEST_ASSERT(replay.wait_started, "The recording isn't waiting for the dead user's body to slide")
	var/until = world.time + 3 SECONDS
	while(replay.state == 1 && !QDELETED(replay) && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT(!QDELETED(replay) && replay.state >= 2, "The recording never ended after the body slid, or nothing replays")
	TEST_ASSERT_EQUAL(user.loc, spot(2, 1), "Test fixture: the body didn't slide a tile east")
	var/datum/sandy_replay_track/track = replay.tracks[user]
	var/list/frames = track.frames
	var/at = length(frames) - 6
	TEST_ASSERT(frames[at + 3] == user.x && frames[at + 4] == user.y, "The replay's last frame doesn't have the body where it slid to")
	TEST_ASSERT(frames[at + 1] > track.surge_until, "The body's slide counts as a surging step and leaves a trail")
	wait_over(user)
	TEST_ASSERT_EQUAL(GLOB.sandy_replay_last["played"], TRUE, "The death didn't replay")
	TEST_ASSERT_EQUAL(user.loc, spot(2, 1), "The body isn't where it slid to after the replay")
	TEST_ASSERT(user.pixel_w == user.base_pixel_w && user.pixel_z == user.base_pixel_z, "The body is left drawn off its tile: [user.pixel_w],[user.pixel_z]")

/// A puppet the game moves a tile under the replay jumps there instead of gliding, so it stays drawn on its frame's tile,
/// and glides its own moves again after the replay.
/datum/unit_test/voidcrew_cyberware_timestop/replay/puppet_moved_jumps

/datum/unit_test/voidcrew_cyberware_timestop/replay/puppet_moved_jumps/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplayjump")
	set_window(user, 3 SECONDS)
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.6 SECONDS)
	raider.forceMove(spot(3, 0))
	sleep(0.6 SECONDS)
	press_again(user)
	deltimer(replay.begin_timer)
	var/movement = raider.animate_movement
	replay.begin()
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay didn't start")
	TEST_ASSERT(GLOB.sandy_replay_masked[raider], "The NPC that moved isn't replayed")
	TEST_ASSERT_EQUAL(raider.pixel_w, -32, "The NPC isn't drawn back on its first tile")
	raider.forceMove(spot(3, 1)) // the game moves it under the replay
	TEST_ASSERT_EQUAL(raider.animate_movement, NO_STEPS, "A puppet moved under the replay glides, drawn a tile off its frame's tile as it goes")
	TEST_ASSERT_EQUAL(raider.pixel_z, -32, "The moved puppet isn't drawn on its frame's tile")
	wait_over(user)
	TEST_ASSERT_EQUAL(raider.animate_movement, movement, "The NPC doesn't glide its own moves after the replay")
	TEST_ASSERT_EQUAL(raider.loc, spot(3, 1), "The NPC isn't where it was really moved to")

/// A corpse's pose held in the slow-mo (slid within its tile) is played on its puppet, and carries on from there on the
/// real body when the replay hands it back, instead of being ended with the puppet.
/datum/unit_test/voidcrew_cyberware_timestop/replay/held_pose_carries_on

/datum/unit_test/voidcrew_cyberware_timestop/replay/held_pose_carries_on/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplaypose")
	set_window(user, 3 SECONDS)
	var/mob/living/carbon/human/npc/victim = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.6 SECONDS)
	victim.death()
	victim.hv_vis_slide_in_tile(EAST, 20)
	sleep(0.6 SECONDS)
	press_again(user)
	deltimer(replay.begin_timer)
	var/real_w = victim.pixel_w
	replay.begin()
	TEST_ASSERT(GLOB.sandy_replay_masked[victim], "The corpse isn't replayed")
	var/datum/sandy_replay_track/track = replay.tracks[victim]
	var/until = world.time + 3 SECONDS
	while(!length(track.chain) && GLOB.sandy_replays[user] && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT(length(track.chain), "The corpse's slide wasn't played on its puppet")
	var/resumed = replay.chains_resumed
	replay.finish()
	TEST_ASSERT(GLOB.sandy_replay_last["chains_resumed"] > resumed, "The corpse's held pose ended at the hand-back")
	TEST_ASSERT_EQUAL(victim.pixel_w, real_w, "The corpse's real offset changed")

/// A flash of light lit on the floor in the field is lit again in the replay, as bright, and is out after it.
/datum/unit_test/voidcrew_cyberware_timestop/replay/flash_light_replayed

/datum/unit_test/voidcrew_cyberware_timestop/replay/flash_light_replayed/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplaylight")
	set_window(user, 3 SECONDS)
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.6 SECONDS)
	var/turf/flash_at = spot(2, 1)
	flash_at.flash_lighting_fx(3, 2, LIGHT_COLOR_ORANGE, 2) // an execution's shot
	TEST_ASSERT_EQUAL(length(replay.lights), 1, "A flash of light in the field wasn't recorded")
	sleep(0.6 SECONDS)
	var/list/light = replay.lights[1]
	TEST_ASSERT(light[2] != INFINITY && light[2] > light[1], "The recording didn't see the flash go out")
	press_again(user)
	deltimer(replay.begin_timer)
	replay.begin()
	var/found_lit = FALSE
	var/until = world.time + 3 SECONDS
	while(!found_lit && GLOB.sandy_replays[user] && world.time < until)
		for(var/obj/effect/dummy/lighting_obj/glow in flash_at)
			found_lit = glow.light_range == 3 && glow.light_power == 2 && glow.light_color == LIGHT_COLOR_ORANGE
		if(!found_lit)
			sleep(world.tick_lag)
	TEST_ASSERT(found_lit, "The replay didn't light the flash as the live one was lit")
	wait_over(user)
	TEST_ASSERT(!(locate(/obj/effect/dummy/lighting_obj) in flash_at), "A light the replay lit is still on after it")
