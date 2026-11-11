/**
 * # The replay after a Sandevistan slow-mo
 *
 * voidcrew/modules/cyberware/ware_sandy_replay.dm. A slow-mo that runs out, or that its user ends, is shown again
 * from frame 0 on the real things, drawn at their recorded spots without being moved, and every one of them ends
 * exactly as it really was. A slow-mo another player cut short doesn't replay.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so literals stand in for the module's defines: the replay's
 * states are 1 recording, 2 about to play, 3 playing, and its trait source is "sandy_replay".
 */
/datum/unit_test/voidcrew_cyberware_timestop/replay
	abstract_type = /datum/unit_test/voidcrew_cyberware_timestop/replay

/// Opens `user`'s slow-mo and returns its recording
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/start_recording(mob/living/carbon/human/user)
	surge(user)
	sleep(0.1 SECONDS) // the field starts async
	var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
	TEST_ASSERT_NOTNULL(replay, "The slow-mo isn't being recorded")
	TEST_ASSERT_EQUAL(replay.state, 1, "The recording didn't start in its recording state")
	return replay

/// Ends `user`'s slow-mo the way a second press of the surge does
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/press_again(mob/living/carbon/human/user)
	user.remove_status_effect(/datum/status_effect/cyberware_cascade_window)

/// Waits up to `limit` for `user`'s replay to be over
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/wait_over(mob/living/carbon/human/user, limit = 5 SECONDS)
	var/until = world.time + limit
	while(GLOB.sandy_replays[user] && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT_NULL(GLOB.sandy_replays[user], "The replay never ended")

/// Whether the replay holds `body` (AI pause or input lock)
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/held(mob/living/body)
	return HAS_TRAIT_FROM(body, TRAIT_AI_PAUSED, "sandy_replay") || HAS_TRAIT_FROM(body, TRAIT_IMMOBILIZED, "sandy_replay") || HAS_TRAIT_FROM(body, TRAIT_INCAPACITATED, "sandy_replay")

/// Names what differs between `thing`'s look now and the appearance `was`
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/look_difference(atom/movable/thing, was)
	var/mutable_appearance/now = new(thing)
	var/mutable_appearance/before = new(was)
	var/list/found = list()
	for(var/name in list("icon", "icon_state", "pixel_x", "pixel_y", "pixel_w", "pixel_z", "alpha", "layer", "plane", "invisibility", "mouse_opacity", "appearance_flags", "blend_mode", "name"))
		if(now.vars[name] != before.vars[name])
			found += "[name] [before.vars[name]] -> [now.vars[name]]"
	if(!(now.color ~= before.color))
		found += "color"
	if(!(now.transform ~= before.transform))
		found += "transform"
	if(length(now.overlays) != length(before.overlays))
		found += "overlays [length(before.overlays)] -> [length(now.overlays)]"
	if(length(now.underlays) != length(before.underlays))
		found += "underlays [length(before.underlays)] -> [length(now.underlays)]"
	if(length(now.filters) != length(before.filters))
		found += "filters [length(before.filters)] -> [length(now.filters)]"
	return length(found) ? found.Join(", ") : "nothing in the vars compared"

/// A slow-mo the user ends replays from frame 0 on the real things, without moving them, and every one of them
/// ends exactly as it really was. Changes made to them mid-replay land on their real look.
/datum/unit_test/voidcrew_cyberware_timestop/replay/plays_and_restores

/datum/unit_test/voidcrew_cyberware_timestop/replay/plays_and_restores/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplayuser")
	set_window(user, 3 SECONDS)
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/mob/living/carbon/human/npc/bleeder = allocate(/mob/living/carbon/human/npc, spot(4, 0))
	var/mob/living/carbon/human/npc/victim = allocate(/mob/living/carbon/human/npc, spot(4, 2))
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench, spot(1, 1))
	var/obj/item/crowbar/still = allocate(/obj/item/crowbar, spot(1, 2))
	var/obj/structure/table/table = allocate(/obj/structure/table, spot(3, 2))
	var/datum/sandy_replay/replay = start_recording(user)
	TEST_ASSERT(replay.tracks[raider] && replay.tracks[wrench] && replay.tracks[table] && replay.tracks[user], "The recording missed things in the field")

	// The window: the user steps, an NPC is moved, one bleeds, one loses its head and dies, a thing is made, one is made and deleted.
	sleep(0.6 SECONDS)
	user.Move(spot(0, 1), NORTH)
	raider.forceMove(spot(3, 0))
	wrench.forceMove(spot(2, 2))
	bleeder.cause_wound_of_type_and_severity(WOUND_SLASH, bleeder.get_bodypart(BODY_ZONE_CHEST), WOUND_SEVERITY_SEVERE)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	head.dismember()
	victim.death()
	var/obj/item/screwdriver/made = allocate(/obj/item/screwdriver, spot(3, 1))
	var/obj/item/pen/spent = new(spot(1, 0))
	playsound(spot(2, 1), 'sound/items/weapons/genhit1.ogg', 50, FALSE)
	sleep(0.6 SECONDS)
	qdel(spent)
	sleep(0.3 SECONDS)
	TEST_ASSERT(replay.tracks[made], "Something made mid-window wasn't recorded")

	// The second press: the slow-mo's looks come off, and that is everything's real final state.
	press_again(user)
	TEST_ASSERT_EQUAL(replay.state, 2, "Ending the slow-mo didn't queue the replay")
	TEST_ASSERT(!user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash didn't wait for the replay")
	var/list/things = list(user, raider, bleeder, victim, wrench, still, table, made)
	// A head still flying (a throw, or hyperviolence's tumble) really lands during the replay, and its roll on landing
	// moves its pixel_x 6 px (hv_vis_roll() in hyperviolence/visuals/flying_gore.dm): a real change, not the replay's.
	var/head_in_flight = !QDELETED(head) && (!!head.throwing || !!head.GetComponent(/datum/component/hv_tumble))
	if(!QDELETED(head) && !head_in_flight)
		things += head
	log_test("replay/plays_and_restores: severed head [QDELETED(head) ? "gone" : (head_in_flight ? "still in flight at the release, left out of the exact check" : "at rest, checked")]")
	var/list/real = list()
	var/list/real_spot = list()
	var/list/real_dir = list()
	for(var/atom/movable/thing as anything in things)
		real[thing] = thing.appearance
		real_spot[thing] = thing.loc
		real_dir[thing] = thing.dir
	var/raider_overlays = length(raider.overlays)

	replay.begin()
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay didn't start")
	// Frame 0: drawn back where they started, standing on the tiles they ended on.
	for(var/atom/movable/thing as anything in things)
		TEST_ASSERT_EQUAL(thing.loc, real_spot[thing], "The replay moved [thing] for real")
	TEST_ASSERT(GLOB.sandy_replay_masked[user] && GLOB.sandy_replay_masked[raider] && GLOB.sandy_replay_masked[wrench] && GLOB.sandy_replay_masked[victim], "Things that changed aren't replayed")
	TEST_ASSERT(!GLOB.sandy_replay_masked[still] && !GLOB.sandy_replay_masked[table], "Things that never changed are replayed (the slow-mo's tint wasn't taken out of the recording cleanly)")
	TEST_ASSERT_EQUAL(user.pixel_z, -32, "The user isn't drawn back on their first tile")
	TEST_ASSERT_EQUAL(raider.pixel_w, -32, "The NPC isn't drawn back on its first tile")
	TEST_ASSERT_EQUAL(wrench.pixel_w - initial(wrench.pixel_w), -32, "The item isn't drawn back on its first tile")
	TEST_ASSERT_EQUAL(made.alpha, 0, "Something made mid-window shows at frame 0")
	var/datum/sandy_replay_track/victim_track = replay.tracks[victim]
	TEST_ASSERT(victim.appearance != real[victim], "The corpse's first frame is its last")
	TEST_ASSERT(length(victim_track.frames) > 6, "The corpse has one frame")
	TEST_ASSERT(length(replay.standins) >= 1, "Something deleted mid-window has no stand-in")
	TEST_ASSERT(HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, "sandy_replay") && HAS_TRAIT_FROM(user, TRAIT_INCAPACITATED, "sandy_replay"), "The user can act during the replay")
	TEST_ASSERT(HAS_TRAIT_FROM(raider, TRAIT_AI_PAUSED, "sandy_replay"), "The NPC's AI runs during the replay")
	TEST_ASSERT(!raider.IsStun() && !user.IsStun(), "The replay stunned someone")
	TEST_ASSERT(!user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash started during the replay")

	// Mid-replay: the game changes puppets. Through wrapped procs (an overlay, a lying turn) and by a plain var write.
	sleep(0.1 SECONDS)
	var/mutable_appearance/mark = mutable_appearance('icons/effects/effects.dmi', "shield-old")
	raider.add_overlay(mark)
	raider.set_lying_angle(90)
	wrench.alpha = 128
	TEST_ASSERT(GLOB.sandy_replay_masked[raider], "A change to a puppet ended its replay")

	wait_over(user)
	TEST_ASSERT_EQUAL(GLOB.sandy_replay_last["played"], TRUE, "The replay didn't play")
	TEST_ASSERT_EQUAL(length(GLOB.sandy_replay_masked), 0, "Puppets are left after the replay")
	for(var/atom/movable/thing as anything in things)
		TEST_ASSERT_EQUAL(thing.loc, real_spot[thing], "[thing] isn't where it really ended")
		TEST_ASSERT_EQUAL(thing.dir, real_dir[thing], "[thing] isn't facing the way it really ended")
		if(thing == raider || thing == wrench || thing == user) // changed mid-replay below; the user wears the crash now
			continue
		TEST_ASSERT(thing.appearance == real[thing], "[thing] doesn't look exactly as it really ended: [look_difference(thing, real[thing])]")
	// The changes made mid-replay are on the real looks, and nothing else is.
	TEST_ASSERT_EQUAL(length(raider.overlays), raider_overlays + 1, "An overlay added mid-replay was lost, or others were")
	TEST_ASSERT_EQUAL(raider.lying_angle, 90, "The lying turn didn't hold")
	var/mutable_appearance/raider_was = new(real[raider])
	var/matrix/upright = matrix(raider_was.transform)
	TEST_ASSERT(!(raider.transform ~= upright), "A lying turn made mid-replay isn't on the real body")
	TEST_ASSERT_EQUAL(raider.pixel_w, raider_was.pixel_w, "The NPC is left drawn off its tile")
	TEST_ASSERT(user.pixel_w == 0 && user.pixel_z == 0 && user.alpha == 255, "The user is left drawn off their tile or hidden")
	TEST_ASSERT(user.transform ~= matrix(), "The user is left turned or scaled")
	TEST_ASSERT_EQUAL(user.mouse_opacity, initial(user.mouse_opacity), "The user can't be clicked after the replay")
	TEST_ASSERT_EQUAL(wrench.alpha, 128, "A var written mid-replay was lost")
	TEST_ASSERT_EQUAL(wrench.pixel_w, initial(wrench.pixel_w), "The item is left drawn off its tile")
	TEST_ASSERT_EQUAL(wrench.mouse_opacity, initial(wrench.mouse_opacity), "The item can't be clicked after the replay")
	TEST_ASSERT_EQUAL(GLOB.sandy_replay_last["unhooked"], 1, "Puppets read as changed when nothing changed them")
	TEST_ASSERT(!held(user) && !held(raider) && !held(bleeder), "Someone is still held after the replay")
	TEST_ASSERT(!(locate(/obj/effect/abstract/sandy_replay_standin) in range(9, user)), "A stand-in outlived the replay")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash didn't land when the replay ended")
	// It looks and sounds like a surge: the user's step left an afterimage, and the sound made in the field played again.
	TEST_ASSERT(GLOB.sandy_replay_last["afterimages"] >= 1, "The user's step in the replay left no afterimage")
	TEST_ASSERT(GLOB.sandy_replay_last["sounds"] >= 1, "A sound made in the field wasn't recorded")
	TEST_ASSERT_EQUAL(GLOB.sandy_replay_last["sounds_played"], GLOB.sandy_replay_last["sounds"], "The recorded sounds didn't all play in the replay")

/// A slow-mo that runs out replays by itself, and the watchdog ends a replay whose frames stopped coming
/datum/unit_test/voidcrew_cyberware_timestop/replay/watchdog

/datum/unit_test/voidcrew_cyberware_timestop/replay/watchdog/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplaywatch")
	set_window(user, 1 SECONDS)
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.4 SECONDS)
	raider.forceMove(spot(3, 0))
	var/until = world.time + 3 SECONDS
	while(replay.state != 3 && !QDELETED(replay) && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(replay.state, 3, "A slow-mo that ran out didn't replay")
	TEST_ASSERT(GLOB.sandy_replay_masked[raider], "The NPC that moved isn't replayed")
	var/datum/sandy_replay_track/raider_track = replay.tracks[raider]
	var/mutable_appearance/real = new(raider_track.saved_look)
	deltimer(replay.play_timer) // the frames stop coming
	replay.play_timer = null
	var/stalled_at = world.time
	wait_over(user)
	TEST_ASSERT(world.time - stalled_at >= 1 SECONDS, "The stalled replay ended before the watchdog could have ended it")
	TEST_ASSERT(!held(user) && !held(raider), "Someone is still held after the watchdog ended the replay")
	TEST_ASSERT_EQUAL(raider.pixel_w, real.pixel_w, "The NPC is left drawn off its tile")
	TEST_ASSERT_EQUAL(length(GLOB.sandy_replay_masked), 0, "Puppets are left after the watchdog ended the replay")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash didn't land when the watchdog ended the replay")

/// A player who isn't crew coming near ends the replay at once
/datum/unit_test/voidcrew_cyberware_timestop/replay/player_arrives

/datum/unit_test/voidcrew_cyberware_timestop/replay/player_arrives/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplayalone")
	set_window(user, 3 SECONDS)
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(1 SECONDS)
	raider.forceMove(spot(3, 0))
	sleep(0.5 SECONDS)
	press_again(user)
	var/real = raider.appearance
	replay.begin()
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay didn't start")
	TEST_ASSERT_EQUAL(raider.pixel_w, -32, "The NPC isn't replayed")
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	stranger.key = "sandyreplaystranger"
	replay.play_frame()
	TEST_ASSERT_NULL(GLOB.sandy_replays[user], "The replay went on with another player near")
	TEST_ASSERT(raider.appearance == real, "The NPC didn't snap back to its real look")
	TEST_ASSERT(!held(user) && !held(raider), "Someone is still held after a player ended the replay")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash didn't land when a player ended the replay")

/// A slow-mo another player cut short doesn't replay
/datum/unit_test/voidcrew_cyberware_timestop/replay/not_when_cut_short

/datum/unit_test/voidcrew_cyberware_timestop/replay/not_when_cut_short/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplaycut")
	set_window(user, 1.5 SECONDS)
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	start_recording(user)
	raider.forceMove(spot(3, 0))
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	stranger.key = "sandyreplaycutter"
	sleep(0.5 SECONDS) // the field's next tick sees them
	TEST_ASSERT_NULL(GLOB.sandy_replays[user], "A slow-mo cut short by a player kept its recording")
	sleep(1.5 SECONDS) // past the end of the window
	TEST_ASSERT(!user.has_status_effect(/datum/status_effect/cyberware_cascade_window), "Test fixture: the window should be over")
	TEST_ASSERT_NULL(GLOB.sandy_replays[user], "A slow-mo cut short by a player replayed")
	TEST_ASSERT_EQUAL(length(GLOB.sandy_replay_masked), 0, "A slow-mo cut short by a player made puppets")
	TEST_ASSERT(!held(user) && !held(raider), "Someone is held with no replay")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash didn't land at the end of the window")

/// The user dying in the window is replayed too: their body isn't locked, and no crash follows
/datum/unit_test/voidcrew_cyberware_timestop/replay/user_dies

/datum/unit_test/voidcrew_cyberware_timestop/replay/user_dies/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplaydead")
	set_window(user, 3 SECONDS)
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.5 SECONDS)
	user.Move(spot(0, 1), NORTH)
	sleep(0.5 SECONDS)
	user.death()
	sleep(0.3 SECONDS)
	if(user.has_status_effect(/datum/status_effect/cyberware_cascade_window))
		press_again(user)
	TEST_ASSERT_EQUAL(replay.state, 2, "The slow-mo of a user who died didn't queue its replay")
	var/real = user.appearance
	replay.begin()
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay of a user who died didn't start")
	TEST_ASSERT(GLOB.sandy_replay_masked[user], "The dead user's body isn't replayed")
	TEST_ASSERT_EQUAL(user.pixel_z, -32, "The dead user isn't drawn back on their first tile")
	TEST_ASSERT(user.appearance != real, "The dead user isn't drawn alive at frame 0")
	TEST_ASSERT(!held(user), "A dead user was input-locked")
	wait_over(user)
	TEST_ASSERT(user.appearance == real, "The dead user's body doesn't look as it really ended")
	TEST_ASSERT(!user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "A dead user crashed")
