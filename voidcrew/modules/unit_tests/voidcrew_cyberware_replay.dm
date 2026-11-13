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
		var/list/had = list()
		for(var/dm_filter/filter as anything in before.filters)
			had += "[filter.type]"
		var/list/has = list()
		for(var/dm_filter/filter as anything in now.filters)
			has += "[filter.type]"
		found += "filters [length(before.filters)] ([had.Join("/")]) -> [length(now.filters)] ([has.Join("/")]), filter names now: [jointext(assoc_to_keys(thing.filter_data), "/")]"
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
	var/head_x = QDELETED(head) ? null : head.pixel_x
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
	// Not in the slow-mo, but near the user: it holds still for the replay too.
	var/mob/living/carbon/human/npc/outsider = allocate(/mob/living/carbon/human/npc, spot(5, 1))

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
	TEST_ASSERT(HAS_TRAIT_FROM(outsider, TRAIT_AI_PAUSED, "sandy_replay"), "An NPC near the user but outside the slow-mo acts during the replay")
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
	// The wrench's alpha is one change no wrapper sees. A head still tumbling at the release lands mid-replay, and its
	// bounce and roll (hv_vis_roll(), flying_gore.dm) write its pixel offsets directly: that may be another. Nothing
	// else may be.
	var/list/folded = GLOB.sandy_replay_last["folded"]
	log_test("replay/plays_and_restores: head pixel_x [head_x] at the release, [QDELETED(head) ? "gone" : head.pixel_x] after; changes no wrapper saw: [folded.Join("; ")]")
	var/wrench_changes = 0
	for(var/change in folded)
		if(findtext(change, "[/obj/item/wrench]:") == 1)
			wrench_changes++
		else
			TEST_ASSERT(head_in_flight && findtext(change, "[/obj/item/bodypart/head]") == 1, "A puppet read as changed when nothing changed it: [change]")
	TEST_ASSERT_EQUAL(wrench_changes, 1, "The var written on the wrench mid-replay wasn't seen once")
	TEST_ASSERT(!held(user) && !held(raider) && !held(bleeder) && !held(outsider), "Someone is still held after the replay")
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
	TEST_ASSERT(raider.appearance == real, "The NPC didn't snap back to its real look: [look_difference(raider, real)]")
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
	user.death() // ends the slow-mo there and then; the replay starts a tick later
	TEST_ASSERT_EQUAL(replay.state, 2, "The slow-mo of a user who died didn't end at death with its replay queued")
	deltimer(replay.begin_timer)
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

/// A user who goes into crit in the window is replayed upright from their first tile and goes down at the frame they
/// went down, and after the replay is exactly as they really are: still down, still in crit, not held
/datum/unit_test/voidcrew_cyberware_timestop/replay/user_crit

/datum/unit_test/voidcrew_cyberware_timestop/replay/user_crit/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplaycrit")
	set_window(user, 3 SECONDS)
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.5 SECONDS)
	user.Move(spot(0, 1), NORTH)
	sleep(0.5 SECONDS)
	user.apply_damage(user.health - user.crit_threshold + 10, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(user.stat, SOFT_CRIT, "Test fixture: the user should be in soft crit")
	TEST_ASSERT_EQUAL(user.body_position, LYING_DOWN, "Test fixture: a user in crit should be lying down")
	sleep(0.3 SECONDS)
	TEST_ASSERT_EQUAL(replay.state, 1, "Crit ended the slow-mo")
	press_again(user)
	deltimer(replay.begin_timer)
	var/real = user.appearance
	var/real_angle = user.lying_angle
	var/matrix/real_turn = matrix(user.transform)
	TEST_ASSERT(!(real_turn ~= matrix()), "Test fixture: a user lying in crit should be turned")
	replay.begin()
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay of a user in crit didn't start")
	TEST_ASSERT(GLOB.sandy_replay_masked[user], "The user in crit isn't replayed")
	TEST_ASSERT_EQUAL(user.pixel_z, -32, "The user in crit isn't drawn back on their first tile")
	TEST_ASSERT(user.transform ~= matrix(), "The user in crit isn't drawn upright at frame 0")
	var/down_at = 0
	var/until = world.time + 5 SECONDS
	while(GLOB.sandy_replays[user] && world.time < until)
		if(!down_at && !(user.transform ~= matrix()))
			down_at = world.time
		sleep(world.tick_lag)
	TEST_ASSERT_NULL(GLOB.sandy_replays[user], "The replay never ended")
	TEST_ASSERT(down_at > replay.play_started, "The user in crit never goes down in their replay, or is down from its first frame")
	// the crash lands when the replay ends and plays its node looks, so the whole appearance can't match; compare the
	// parts the replay drew over
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "Test fixture: the crash should land on a user in crit")
	var/difference = look_difference(user, real)
	TEST_ASSERT(difference == "nothing in the vars compared", "The user in crit doesn't look as they really are after the replay: [difference]")
	TEST_ASSERT(user.transform ~= real_turn, "The user in crit isn't turned as they really lie after the replay")
	TEST_ASSERT_EQUAL(user.stat, SOFT_CRIT, "The replay changed the user's stat")
	TEST_ASSERT_EQUAL(user.body_position, LYING_DOWN, "The user in crit stood up after the replay")
	TEST_ASSERT_EQUAL(user.lying_angle, real_angle, "The user in crit's lying angle changed over the replay")
	TEST_ASSERT(!held(user), "The user in crit is still held after the replay")

/// A user knocked down in the window whose knockdown wears off during the replay gets up once it ends: the replay's
/// input lock fails tg's get-up while it plays
/datum/unit_test/voidcrew_cyberware_timestop/replay/gets_up_after

/datum/unit_test/voidcrew_cyberware_timestop/replay/gets_up_after/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplayknock")
	set_window(user, 3 SECONDS)
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = locate() in user.organs
	lattice.crash_stamina = 0 // the crash's stamina dump would floor them again
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.5 SECONDS)
	user.Paralyze(20 SECONDS)
	TEST_ASSERT_EQUAL(user.body_position, LYING_DOWN, "Test fixture: a paralyzed user should be lying down")
	sleep(0.3 SECONDS)
	press_again(user)
	deltimer(replay.begin_timer)
	replay.begin()
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay didn't start")
	user.SetParalyzed(0) // wears off mid-replay
	TEST_ASSERT_EQUAL(user.body_position, LYING_DOWN, "Test fixture: the replay's lock should keep the user from getting up while it plays")
	wait_over(user)
	var/until = world.time + 3 SECONDS
	while(user.body_position == LYING_DOWN && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(user.body_position, STANDING_UP, "A user whose knockdown wore off during the replay never got up after it")
	TEST_ASSERT_EQUAL(user.lying_angle, 0, "The user got up but is still turned")

/// A crit body for an execution to be done on, `dx`, `dy` from the room's corner
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/make_victim(dx, dy)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, spot(dx, dy))
	victim.adjustOxyLoss(120)
	TEST_ASSERT(victim.hv_is_helpless(), "Test fixture: the victim isn't down")
	return victim

/// The user's own look on a replay frame: never hidden. A finisher rig's hide only while a stand-in of one of the
/// rig's pictures is drawn in their place.
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/check_seen(mob/living/user, datum/sandy_replay/replay)
	var/datum/sandy_replay_track/track = replay.tracks[user]
	if(!track || track.cursor < 0 || !GLOB.sandy_replay_masked[user])
		return
	TEST_ASSERT(user.alpha > 0 && user.invisibility < INVISIBILITY_ABSTRACT, "The user is drawn hidden on replay frame [track.frames[track.cursor + 1]]")
	if(!user.filter_data?["chrome_rig_hide"] && !user.filter_data?["mantis_rig_hide"])
		return
	var/pictures = 0
	for(var/datum/sandy_replay_track/standin_track as anything in replay.standins)
		if(standin_track.standin?.loc && length(standin_track.events))
			pictures++
	TEST_ASSERT(pictures, "The user's puppet wears a rig's hide with no rig picture drawn for it on replay frame [track.frames[track.cursor + 1]]")

/// No progress bar is drawn while a replay plays (owner, 2026-11-12): no execution bar near the user, and no do_after
/// bar image on the user's screen.
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/check_no_bars(mob/living/user)
	var/datum/sandy_replay/replay = GLOB.sandy_replays[user]
	if(!replay || replay.state != 3)
		return
	for(var/obj/effect/abstract/hv_exec_bar/bar as anything in GLOB.hv_exec_bars)
		TEST_ASSERT(bar.invisibility >= INVISIBILITY_ABSTRACT || get_dist(bar, user) > 11, "An execution bar shows during the replay")
	for(var/target in user.progressbars)
		for(var/datum/progressbar/progress as anything in user.progressbars[target])
			TEST_ASSERT(!progress.user_client || !(progress.bar in progress.user_client.images), "A progress bar shows on the user's screen during the replay")

/// Whether `user` sees the surge's own screen colour
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/surge_tinted(mob/living/user)
	return !!user.get_client_colour("cyberware_cascade_window")

/// `user`'s surge window
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/window_of(mob/living/user)
	return user.has_status_effect(/datum/status_effect/cyberware_cascade_window)

/**
 * A gun execution in its wind-up when the slow-mo is asked to end (its time is up, or a second press; playtest bug
 * 2026-11-12): the slow-mo holds, with the user's edge glow on, until the shot goes off for real, then ends and
 * replays. Nobody is held while it holds. The user is never hidden in the replay, sees no surge colour during or
 * after it, and is left exactly where and as they really are; the crash lands after.
 */
/datum/unit_test/voidcrew_cyberware_timestop/replay/execution_running_at_end

/datum/unit_test/voidcrew_cyberware_timestop/replay/execution_running_at_end/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 1), "sandyreplayexec")
	set_window(user, 4 SECONDS)
	var/mob/living/carbon/human/victim = make_victim(1, 0)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(user.put_in_active_hand(pistol), "Test fixture: the pistol wouldn't go in the user's hand")
	user.zone_selected = BODY_ZONE_HEAD
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/head_brute = head.brute_dam
	var/datum/sandy_replay/replay = start_recording(user)
	var/datum/status_effect/cyberware_cascade_window/window = window_of(user)
	sleep(0.6 SECONDS)
	user.Move(spot(0, 0), SOUTH) // off the tile the replay starts on: its puppet is drawn a tile up
	sleep(0.3 SECONDS)
	user.face_atom(victim)
	INVOKE_ASYNC(pistol, TYPE_PROC_REF(/obj/item/gun, hv_start_execution), user, victim, null)
	sleep(0.4 SECONDS)
	TEST_ASSERT(sandy_replay_mid_move(user), "The wind-up isn't seen as a move in progress")

	var/asked = world.time
	window.slowmo_time_up() // what its time running out and a second press both do
	sleep(world.tick_lag)
	TEST_ASSERT_NOTNULL(window.time_stop, "The slow-mo ended in the middle of the user's execution")
	TEST_ASSERT(window.hold_until, "The slow-mo isn't holding for the execution")
	TEST_ASSERT(user.filter_data?["sandy_time_stop_outline"], "The user's edge glow went off while the slow-mo holds")
	TEST_ASSERT_EQUAL(replay.state, 1, "The recording stopped while the slow-mo holds")
	TEST_ASSERT(!held(user), "The user is held while their execution plays out")
	TEST_ASSERT(!surge_tinted(user), "The surge's colour is on the user's screen in the slow-mo")
	var/until = world.time + 7 SECONDS
	while(replay.state == 1 && !QDELETED(replay) && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT(!QDELETED(replay) && replay.state >= 2, "The slow-mo never ended after the execution, or nothing replayed")
	TEST_ASSERT(world.time - asked <= 6.5 SECONDS, "The hold ran past its cap")
	TEST_ASSERT(!sandy_replay_mid_move(user), "The slow-mo ended before the execution did")
	head = victim.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(!head || head.brute_dam > head_brute, "The execution didn't go off")
	TEST_ASSERT(!window_of(user), "The surge window outlived the slow-mo it held")
	TEST_ASSERT(!user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash didn't wait for the replay")
	while(replay.state != 3 && GLOB.sandy_replays[user] && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay never played after the execution")
	// Frame 0 has the user a tile up, never hidden. Then every frame to the end, with no surge colour.
	TEST_ASSERT_EQUAL(user.pixel_z, 32, "The user isn't drawn back on their first tile")
	while(GLOB.sandy_replays[user] && world.time < until + 8 SECONDS)
		check_seen(user, replay)
		TEST_ASSERT(!surge_tinted(user), "The surge's colour is on the user's screen during the replay")
		check_no_bars(user)
		sleep(world.tick_lag)
	wait_over(user)
	TEST_ASSERT(!surge_tinted(user), "The surge's colour is on the user's screen after the replay")
	TEST_ASSERT(user.pixel_w == user.base_pixel_w && user.pixel_z == user.base_pixel_z, "The user is left drawn off their tile: [user.pixel_w],[user.pixel_z]")
	TEST_ASSERT(user.pixel_x == user.base_pixel_x && user.pixel_y == user.base_pixel_y, "The user is left shifted: [user.pixel_x],[user.pixel_y]")
	TEST_ASSERT(user.alpha == 255 && user.invisibility == initial(user.invisibility), "The user is left hidden")
	TEST_ASSERT(user.transform ~= matrix(), "The user is left turned or scaled")
	TEST_ASSERT(!held(user), "The user is still held after the replay")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash didn't land when the replay ended")

/**
 * A move still going when the hold's cap runs out: the slow-mo ends without a replay (the replay's hold would cut the
 * move short), the move isn't touched, and the crash lands. Asking again while it holds changes nothing.
 */
/datum/unit_test/voidcrew_cyberware_timestop/replay/hold_capped

/datum/unit_test/voidcrew_cyberware_timestop/replay/hold_capped/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplaycap")
	set_window(user, 3 SECONDS)
	var/datum/sandy_replay/replay = start_recording(user)
	var/datum/status_effect/cyberware_cascade_window/window = window_of(user)
	// A rig's hide is what marks a move in progress that has no status of its own (the impale, the slam)
	user.add_filter("chrome_rig_hide", 1, color_matrix_filter(list(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)))
	TEST_ASSERT(sandy_replay_mid_move(user), "Test fixture: the user isn't mid-move")
	var/asked = world.time
	window.slowmo_time_up()
	TEST_ASSERT(window.hold_until, "The slow-mo isn't holding for the move")
	TEST_ASSERT(window.hold_until - asked <= 6 SECONDS, "The hold's cap is [window.hold_until - asked] ds")
	window.slowmo_time_up() // asked again (a second press) while holding: still holding
	TEST_ASSERT_NOTNULL(window.time_stop, "A second ask ended a holding slow-mo")
	var/until = world.time + 8 SECONDS
	while(window_of(user) && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT(!window_of(user), "The hold never ended")
	TEST_ASSERT(world.time - asked >= 6 SECONDS - world.tick_lag, "The hold ended before its cap with the move still going")
	TEST_ASSERT(world.time - asked <= 6.5 SECONDS, "The hold ran past its cap")
	TEST_ASSERT(QDELETED(replay) && !GLOB.sandy_replays[user], "A slow-mo that ended on its cap replayed")
	TEST_ASSERT(user.filter_data?["chrome_rig_hide"], "Ending the slow-mo touched the move")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The crash didn't land")
	TEST_ASSERT(!surge_tinted(user), "The surge's colour stayed on the user's screen")
	user.remove_filter("chrome_rig_hide")

/**
 * A rig move done inside the slow-mo is replayed: its posed pictures are recorded and drawn as stand-ins, with the
 * animations that posed them played again, and the user's puppet wears the rig's hide only while they are. In the
 * slow-mo the user's pictures carry the edge glow. And tg's offsets set on a puppet mid-replay (a finisher letting
 * go, a grab) land on the real body, not on the puppet's shift: nothing is left drawn off its tile.
 */
/datum/unit_test/voidcrew_cyberware_timestop/replay/rig_move_inside

/datum/unit_test/voidcrew_cyberware_timestop/replay/rig_move_inside/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 1), "sandyreplayrig")
	set_window(user, 3 SECONDS)
	var/datum/sandy_replay/replay = start_recording(user)
	var/datum/status_effect/cyberware_cascade_window/window = window_of(user)
	sleep(0.6 SECONDS)
	user.Move(spot(0, 0), SOUTH)
	var/datum/chrome_rig/rig = new(user, EAST)
	TEST_ASSERT(rig.snapshot(), "Test fixture: the rig couldn't picture the user")
	rig.rig_arms()
	rig.conceal()
	TEST_ASSERT(user.filter_data?["chrome_rig_hide"], "Test fixture: the rig didn't hide the user")
	TEST_ASSERT(sandy_replay_mid_move(user), "A rigged body isn't seen as mid-move")
	var/side = rig.near_side()
	var/obj/effect/abstract/chrome_puppet/arm = rig.puppet("arm_[side]") // the rig keys its arms "arm_l" and "arm_r" (rig_arms())
	TEST_ASSERT_NOTNULL(arm, "Test fixture: the rig has no arm")
	TEST_ASSERT(replay.tracks[arm], "The rig's picture isn't recorded")
	TEST_ASSERT(locate(/obj/effect/abstract/sandy_rig_glow) in arm.vis_contents, "The user's rig picture has no edge glow in the slow-mo")
	var/journaled = replay.journaled
	rig.swing_arm(side, 90, 0.4 SECONDS)
	TEST_ASSERT(replay.journaled > journaled, "The rig's swing wasn't journaled for the replay")
	sleep(0.5 SECONDS)
	qdel(rig)
	sleep(0.3 SECONDS)
	window.slowmo_time_up()
	TEST_ASSERT_EQUAL(replay.state, 2, "A finished move held the slow-mo")
	replay.begin()
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay didn't start")
	TEST_ASSERT_EQUAL(user.pixel_z, 32, "The user isn't drawn back on their first tile")
	// tg's offsets on the puppet (a finisher's lean, then letting go), as a cut-short move would
	user.add_offsets("sandy_replay_test", null, 6, 4)
	sleep(world.tick_lag)
	user.remove_offsets("sandy_replay_test")
	var/saw_swing = FALSE
	var/until = world.time + 5 SECONDS
	while(GLOB.sandy_replays[user] && world.time < until)
		check_seen(user, replay)
		for(var/datum/sandy_replay_track/track as anything in replay.standins)
			if(track.standin?.loc && track.event_at > 1)
				saw_swing = TRUE
		sleep(world.tick_lag)
	wait_over(user)
	TEST_ASSERT(saw_swing, "The rig's pictures and their swing weren't played in the replay")
	TEST_ASSERT(user.pixel_w == user.base_pixel_w && user.pixel_z == user.base_pixel_z, "Offsets set mid-replay left the user drawn off their tile: [user.pixel_w],[user.pixel_z]")
	TEST_ASSERT(user.pixel_x == user.base_pixel_x && user.pixel_y == user.base_pixel_y, "Offsets set mid-replay left the user shifted: [user.pixel_x],[user.pixel_y]")
	TEST_ASSERT(!user.filter_data?["chrome_rig_hide"] && user.alpha == 255, "The user is left hidden")

/**
 * An execution early in the slow-mo, then more happens in it (owner, 2026-11-12: "if an execution isn't the same
 * speed, we won't get the whole replay if something happens after"). The slow-mo doesn't hold for a move that's over,
 * the recording runs on at the slow-mo's own rate after the move, the replay shows what came after the move after
 * the move's frames, ends on its own well before its watchdog, holds the user for exactly its length, and leaves
 * everything as it really is.
 */
/datum/unit_test/voidcrew_cyberware_timestop/replay/after_execution

/datum/unit_test/voidcrew_cyberware_timestop/replay/after_execution/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplayafter")
	set_window(user, 5 SECONDS)
	var/mob/living/carbon/human/victim = make_victim(1, 0)
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, spot(3, 0))
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(user.put_in_active_hand(pistol), "Test fixture: the pistol wouldn't go in the user's hand")
	user.zone_selected = BODY_ZONE_HEAD
	var/datum/sandy_replay/replay = start_recording(user)
	var/datum/status_effect/cyberware_cascade_window/window = window_of(user)
	user.face_atom(victim)
	INVOKE_ASYNC(pistol, TYPE_PROC_REF(/obj/item/gun, hv_start_execution), user, victim, null)
	sleep(world.tick_lag)
	TEST_ASSERT(sandy_replay_mid_move(user), "The wind-up isn't seen as a move in progress")
	var/until = world.time + 4 SECONDS
	while(sandy_replay_mid_move(user) && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT(!sandy_replay_mid_move(user), "The execution never ended")
	TEST_ASSERT_EQUAL(replay.state, 1, "The recording stopped when the execution ended")
	TEST_ASSERT(window_of(user) && !window.hold_until, "The slow-mo ended, or held, for an execution that was already over")
	var/move_over = replay.frame_now()
	sleep(0.5 SECONDS)
	TEST_ASSERT(bystander.Move(spot(3, 1), NORTH), "Test fixture: the bystander couldn't step")
	sleep(0.5 SECONDS)
	TEST_ASSERT(replay.frame_now() - move_over <= round(1 SECONDS / replay.interval) + 2, "The recording didn't go back to the slow-mo's rate after the execution")
	until = world.time + 6 SECONDS
	while(replay.state == 1 && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT(replay.state >= 2, "The slow-mo never ended")
	TEST_ASSERT(!window.hold_until, "The slow-mo held at its end with no move going")
	// The bystander's step is in the recording, after the execution's frames.
	var/datum/sandy_replay_track/track = replay.tracks[bystander]
	TEST_ASSERT_NOTNULL(track, "The bystander wasn't recorded")
	var/stepped_at = -1
	var/turf/stepped_to = spot(3, 1)
	for(var/i in 1 to length(track.frames) step 6)
		if(track.frames[i + 2] == stepped_to.x && track.frames[i + 3] == stepped_to.y)
			stepped_at = track.frames[i]
			break
	TEST_ASSERT(stepped_at > move_over, "The step after the execution isn't in the recording after it (frame [stepped_at], move over at [move_over])")
	while(replay.state != 3 && GLOB.sandy_replays[user] && world.time < until + 1 SECONDS)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay never played")
	var/play_started = world.time
	var/total = replay.total
	TEST_ASSERT(held(user), "The user isn't held for the replay")
	while(GLOB.sandy_replays[user] && world.time < play_started + 15 SECONDS)
		if(world.time - play_started < (total - 1) * world.tick_lag)
			TEST_ASSERT(held(user), "The user was let go before the replay was over")
		check_no_bars(user)
		sleep(world.tick_lag)
	TEST_ASSERT_NULL(GLOB.sandy_replays[user], "The replay never ended")
	TEST_ASSERT(world.time - play_started <= (total + 2) * world.tick_lag + 0.2 SECONDS, "The replay was ended by its watchdog, not by playing out ([world.time - play_started] for [total] frames)")
	TEST_ASSERT(GLOB.sandy_replay_last["played"], "Nothing replayed")
	TEST_ASSERT(!held(user), "The user is still held after the replay")
	TEST_ASSERT_EQUAL(get_turf(bystander), stepped_to, "The bystander isn't where they really are")
	TEST_ASSERT(bystander.pixel_w == bystander.base_pixel_w && bystander.pixel_z == bystander.base_pixel_z, "The bystander is left drawn off their tile")
	TEST_ASSERT(bystander.alpha == 255, "The bystander is left hidden")
	TEST_ASSERT(user.pixel_w == user.base_pixel_w && user.pixel_z == user.base_pixel_z && user.alpha == 255, "The user is left drawn off their tile or hidden")

/// Fires a harmless bullet from `from` at `target`, by `firer`
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/fire_shot(turf/from, mob/living/firer, atom/target)
	var/obj/projectile/bullet/shot = new(from)
	shot.damage = 0
	shot.stamina = 0
	shot.firer = firer
	shot.fired_from = firer
	shot.aim_projectile(target, from)
	shot.fire()
	return shot

/// Whether a replay stand-in is anywhere near `user`
/datum/unit_test/voidcrew_cyberware_timestop/replay/proc/standin_near(mob/living/user)
	for(var/obj/effect/abstract/sandy_replay_standin/standin in range(8, user))
		return TRUE
	return FALSE

/// The user's shot, fired and spent inside the slow-mo, is in the replay from the muzzle to the spot it hit, along its
/// path, and gone after it: nothing is left behind.
/datum/unit_test/voidcrew_cyberware_timestop/replay/shot_spent_inside

/datum/unit_test/voidcrew_cyberware_timestop/replay/shot_spent_inside/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplayshot")
	set_window(user, 4 SECONDS)
	var/mob/living/carbon/human/npc/target = allocate(/mob/living/carbon/human/npc, spot(2, 0))
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.2 SECONDS)
	var/obj/projectile/shot = fire_shot(spot(0, 0), user, target)
	var/datum/sandy_replay_track/track = replay.tracks[shot]
	TEST_ASSERT_NOTNULL(track, "The shot wasn't recorded")
	TEST_ASSERT(track.flier, "The shot wasn't recorded as a shot")
	var/until = world.time + 3.5 SECONDS
	while(!QDELETED(shot) && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT(QDELETED(shot), "The shot never hit in the slow-mo")
	TEST_ASSERT(track in replay.gone, "The spent shot isn't kept to be drawn")
	var/list/frames = track.frames
	var/count = length(frames) / 6
	TEST_ASSERT(count >= 3, "The shot's flight has [count] frames")
	TEST_ASSERT(track.last > frames[length(frames) - 5], "The spot the shot hit is never shown (last [track.last])")
	var/prev = -INFINITY
	for(var/i = 1, i <= length(frames), i += 6)
		var/mutable_appearance/look = new(frames[i + 1])
		var/at = frames[i + 2] * 32 + look.pixel_x
		TEST_ASSERT(at >= prev, "The shot goes back on itself at frame [frames[i]]: [prev] -> [at]")
		TEST_ASSERT(look.alpha > 0, "The shot is drawn invisible at frame [frames[i]]")
		prev = at
	TEST_ASSERT_EQUAL(frames[length(frames) - 3], target.x, "The shot's last frame isn't on the tile it hit")
	press_again(user)
	until = world.time + 2 SECONDS
	while(replay.state != 3 && !QDELETED(replay) && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay didn't start")
	var/drawn = 0
	var/drawn_after = 0
	while(!QDELETED(replay) && replay.state == 3)
		var/frame = round((world.time - replay.play_started) / world.tick_lag)
		if(track.standin?.loc)
			drawn++
			if(frame > track.last)
				drawn_after++
		sleep(world.tick_lag)
	log_test("replay/shot_spent_inside: [count] frames, first [track.first], last [track.last], drawn [drawn] ticks")
	TEST_ASSERT(drawn >= count - 1, "The shot was drawn for [drawn] ticks of its [count] frames")
	TEST_ASSERT_EQUAL(drawn_after, 0, "The shot was drawn after the frame it hit in")
	wait_over(user)
	TEST_ASSERT(!standin_near(user), "A stand-in is left after the replay")
	TEST_ASSERT_EQUAL(length(GLOB.sandy_replay_masked), 0, "Puppets are left after the replay")

/// A shot still flying when the slow-mo ends is drawn by itself (one shot, never two), held where the recording left
/// it while the replay plays, and flies on from there after, with its own look back.
/datum/unit_test/voidcrew_cyberware_timestop/replay/shot_flying_at_end

/datum/unit_test/voidcrew_cyberware_timestop/replay/shot_flying_at_end/Run()
	var/mob/living/carbon/human/user = make_user(spot(0, 0), "sandyreplayflying")
	set_window(user, 4 SECONDS)
	var/mob/living/carbon/human/npc/gunman = allocate(/mob/living/carbon/human/npc, spot(1, 2))
	var/datum/sandy_replay/replay = start_recording(user)
	sleep(0.2 SECONDS)
	var/obj/projectile/shot = fire_shot(spot(1, 2), gunman, spot(6, 2))
	var/turf/fired_at = get_turf(shot)
	sleep(0.8 SECONDS)
	TEST_ASSERT(!QDELETED(shot), "The shot was gone before the slow-mo ended")
	TEST_ASSERT(replay.tracks[shot], "The shot wasn't recorded")
	press_again(user)
	var/until = world.time + 2 SECONDS
	while(replay.state != 3 && !QDELETED(replay) && world.time < until)
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(replay.state, 3, "The replay didn't start")
	TEST_ASSERT(!QDELETED(shot), "The shot was gone before the replay")
	var/datum/sandy_replay_track/track = replay.tracks[shot]
	var/list/frames = track.frames
	var/turf/held_at = get_turf(shot)
	var/mutable_appearance/real_look = new(track.saved_look) // the shot is drawn from the recording now: its real look is kept aside
	var/real_x = real_look.pixel_x
	TEST_ASSERT(shot.paused && (shot in replay.held_shots), "The shot flies on while the replay plays")
	TEST_ASSERT(GLOB.sandy_replay_masked[shot], "The shot isn't drawn from the recording")
	TEST_ASSERT(held_at != fired_at, "The shot never moved in the slow-mo")
	TEST_ASSERT(frames[length(frames) - 3] == held_at.x && frames[length(frames) - 2] == held_at.y, "The recording's last frame isn't where the shot is held")
	var/standins = 0
	while(!QDELETED(replay) && replay.state == 3)
		TEST_ASSERT_EQUAL(get_turf(shot), held_at, "The shot moved during the replay")
		if(standin_near(user))
			standins++
		sleep(world.tick_lag)
	TEST_ASSERT_EQUAL(standins, 0, "A second shot was drawn beside the real one")
	wait_over(user)
	TEST_ASSERT(!QDELETED(shot), "The shot was gone after the replay")
	TEST_ASSERT(!shot.paused, "The shot is still held after the replay")
	TEST_ASSERT(!GLOB.sandy_replay_masked[shot], "The shot is still drawn from the recording")
	TEST_ASSERT_EQUAL(shot.pixel_x, real_x, "The shot isn't back on its real spot")
	TEST_ASSERT(shot.pixel_w == 0 && shot.pixel_z == 0 && shot.alpha > 0, "The shot is left drawn off its spot, or hidden")
	sleep(0.3 SECONDS)
	TEST_ASSERT(QDELETED(shot) || get_turf(shot) != held_at, "The shot didn't fly on after the replay")
	if(!QDELETED(shot))
		qdel(shot)
