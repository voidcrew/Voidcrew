// Stealth guards: flashlights, elbow-to-elbow sight, volleys and sentry facing (owner decisions 31, 39 and 41,
// voidcrew/modules/stealth/stealth_light.dm). Values from voidcrew/_DEFINES are written out: STEALTH_LIGHT_HOLD
// 5 s, STEALTH_TORCH_FORWARD 0.5, STEALTH_STRAY_LIGHT_RANGE 5, STEALTH_NOISE_COALESCE 3 s,
// STEALTH_SENTRY_TURN_INTERVAL 8 s, STEALTH_SENTRY_GLANCE_TIME 2 s.

/// Waits for tg's static lighting to apply what was just switched or moved (it updates on its own subsystem).
/// `target`: a lamp whose light is applied here if SSlighting hasn't got to it. A test run first in a world can find
/// SSlighting still holding the whole map's boot backlog (70,000 sources, not fired once 3 minutes in).
/datum/unit_test/proc/stealth_settle_light(atom/movable/target)
	sleep(1)
	for(var/i in 1 to 50)
		if(!length(SSlighting.sources_queue) && !length(SSlighting.current_sources))
			stealth_land_cone(target)
			return
		sleep(1)
	var/datum/light_source/source = target?.light
	if(source?.needs_update)
		source.update_corners()
		source.needs_update = LIGHTING_NO_UPDATE
	stealth_land_cone(target)

/// Applies `lamp`'s queued light now, without waiting, as SSlighting would: for checks that a beam's short timers
/// would outrun.
/datum/unit_test/proc/stealth_apply_light(atom/movable/lamp)
	var/datum/light_source/source = lamp?.light
	if(source?.needs_update)
		source.update_corners()
		source.needs_update = LIGHTING_NO_UPDATE
	stealth_land_cone(lamp)

/// A guard's cone looks for its lamp's light once a tick; this looks now, so a test needn't wait the tick.
/datum/unit_test/proc/stealth_land_cone(atom/movable/lamp)
	var/obj/effect/abstract/stealth_torch/torch = lamp
	if(istype(torch) && torch.owner_ai)
		torch.owner_ai.stealth_cone_stop()
		torch.owner_ai.stealth_cone_check()

/// The guard switches its light on in the dark and while on edge, off in the light, and can't while it is cut out.
/datum/unit_test/voidcrew_stealth_light_switch

/datum/unit_test/voidcrew_stealth_light_switch/Run()
	var/datum/turf_reservation/block = stealth_block(9, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/obj/item/flashlight/light = stealth_ai.stealth_light()
	TEST_ASSERT_NOTNULL(light, "A scav guard has no flashlight on its body")
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A guard's light starts on")
	var/turf/here = get_turf(guard)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "An unaware guard in the light switched its light on")
	GLOB.stealth_test_dark_turfs[here] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard standing in the dark didn't switch its light on")
	TEST_ASSERT(!light.light_on, "The seclite item lit its own beam as well as the pool")
	// Back in the light it keeps it on a moment, then switches it off.
	GLOB.stealth_test_dark_turfs[here] = FALSE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard switched its light off the moment it stepped into the light")
	stealth_ai.light_hold_until = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "An unaware guard in the light kept its light on")
	// On edge, it is on even in the light.
	stealth_ai.stealth_go_suspicious(stealth_at(block, 6, 2))
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A suspicious guard's light isn't on")
	stealth_ai.stealth_go_searching(stealth_at(block, 6, 2))
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A searching guard's light isn't on")
	stealth_ai.stealth_go_unaware()
	stealth_ai.light_hold_until = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A calm guard in the light kept its light on")
	// An EMP cuts it out at once, and the guard can't switch it back on until it recovers.
	GLOB.stealth_test_dark_turfs[here] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "The light didn't come on in the dark")
	guard.emp_act(EMP_LIGHT)
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "An EMP didn't cut the guard's light out")
	// It sputters as it dies (decision 41): a flash of the beam with the light counted off, then dark again.
	stealth_ai.stealth_sputter(stealth_ai.sputter_serial, TRUE)
	TEST_ASSERT(stealth_ai.torch.light_on && !stealth_ai.stealth_light_shows(), "A cut-out seclite doesn't sputter")
	stealth_ai.stealth_sputter(stealth_ai.sputter_serial, FALSE)
	TEST_ASSERT(!stealth_ai.torch.light_on, "A sputter left the beam on")
	stealth_ai.stealth_update_light()
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A guard switched an EMP'd light straight back on")
	light.disabled_time = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "The light didn't come back on once the EMP wore off")
	// Stunned, it has no light.
	guard.Paralyze(5 SECONDS)
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A stunned guard kept its light on")
	guard.SetParalyzed(0)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "The light didn't come back once the guard was up")
	// Gone from its body, it goes out at once.
	light.forceMove(stealth_at(block, 4, 4))
	TEST_ASSERT_NULL(stealth_ai.stealth_light(), "A guard still counts a light that left its body")
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A guard's pool stayed on after its seclite was taken")
	GLOB.stealth_test_dark_turfs[here] = FALSE
	qdel(block)

/// Decision 41: the lamp sits on the guard's tile and its beam starts half a tile ahead; a turn passes through the
/// halfway point, a turn of its own is led by the beam, a step at a walk carries the beam half a tile at a time, and
/// a searching guard sweeps it side to side.
/datum/unit_test/voidcrew_stealth_light_pool

/datum/unit_test/voidcrew_stealth_light_pool/Run()
	var/datum/turf_reservation/block = stealth_block(12, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	if(guard.move_intent == MOVE_INTENT_RUN)
		guard.toggle_move_intent()
	for(var/dx in 0 to 11)
		for(var/dy in 0 to 6)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = TRUE
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard in the dark has no beam")
	var/obj/effect/abstract/stealth_torch/torch = stealth_ai.torch
	TEST_ASSERT_EQUAL(get_turf(torch), get_turf(guard), "The lamp isn't on the guard's tile")
	TEST_ASSERT_EQUAL(torch.light_dir, EAST, "The beam doesn't point the way the guard faces")
	TEST_ASSERT_EQUAL(torch.beam_x, -0.5, "The beam doesn't start half a tile ahead of a guard facing east")
	TEST_ASSERT_EQUAL(torch.beam_y, 0, "A beam facing east starts off to one side")
	// A turn of 90 degrees shows the beam halfway, then lands.
	guard.setDir(NORTH)
	TEST_ASSERT_EQUAL(torch.light_dir, NORTHEAST, "A quarter turn didn't pass the beam through the diagonal")
	stealth_ai.stealth_torch_settle(stealth_ai.torch_serial)
	TEST_ASSERT_EQUAL(torch.light_dir, NORTH, "The beam didn't land on the new facing")
	TEST_ASSERT_EQUAL(torch.beam_y, -0.5, "The beam doesn't start half a tile ahead of a guard facing north")
	TEST_ASSERT_EQUAL(torch.beam_x, 0, "A beam facing north starts off to one side")
	// A turn of its own: the beam goes halfway first, while the body still faces the old way.
	stealth_ai.stealth_turn_to(EAST)
	TEST_ASSERT_EQUAL(guard.dir, NORTH, "A guard's own turn has no tell")
	TEST_ASSERT_EQUAL(torch.light_dir, NORTHEAST, "The beam didn't lead a turn the guard makes on its own")
	stealth_ai.stealth_finish_turn(EAST, stealth_ai.turn_planned_at)
	TEST_ASSERT_EQUAL(guard.dir, EAST, "The guard didn't finish its turn")
	TEST_ASSERT_EQUAL(torch.light_dir, EAST, "The beam didn't land when the led turn finished")
	TEST_ASSERT(!stealth_ai.torch_pass, "A led turn passed through the halfway point a second time")
	// A turn it drops: the beam goes back.
	stealth_ai.stealth_turn_to(SOUTH)
	TEST_ASSERT_EQUAL(torch.light_dir, SOUTHEAST, "The beam didn't lead the second turn")
	stealth_ai.stealth_drop_turn()
	TEST_ASSERT_EQUAL(torch.light_dir, EAST, "A dropped turn left the beam off to the side")
	// One step at a walk: the lamp moves at once, the beam half a tile behind it until it settles.
	guard.forceMove(stealth_at(block, 3, 3))
	TEST_ASSERT_EQUAL(get_turf(torch), stealth_at(block, 3, 3), "The lamp didn't follow the guard's step")
	TEST_ASSERT_EQUAL(torch.beam_x, 0, "A step at a walk didn't hold the beam half a tile back")
	stealth_ai.stealth_torch_settle(stealth_ai.torch_serial)
	TEST_ASSERT_EQUAL(torch.beam_x, -0.5, "The beam didn't land after the step")
	// Further than a step (a shove, a teleport): no half step.
	guard.forceMove(stealth_at(block, 6, 3))
	TEST_ASSERT_EQUAL(get_turf(torch), stealth_at(block, 6, 3), "The lamp didn't follow the guard")
	TEST_ASSERT_EQUAL(torch.beam_x, -0.5, "A jump of three tiles held the beam back")
	// A walked corner (tg turns a walker, then moves it, in one tick): the beam passes the diagonal as it steps.
	guard.setDir(NORTH)
	guard.forceMove(stealth_at(block, 6, 4))
	TEST_ASSERT_EQUAL(torch.light_dir, NORTHEAST, "A step round a corner snapped the beam round")
	stealth_ai.stealth_torch_settle(stealth_ai.torch_serial)
	TEST_ASSERT_EQUAL(torch.light_dir, NORTH, "The beam didn't land after a step round a corner")
	TEST_ASSERT_EQUAL(torch.beam_y, -0.5, "The beam didn't land half a tile ahead after a step round a corner")
	// A diagonal step turns the walker after it moves: the beam still passes the diagonal.
	guard.forceMove(stealth_at(block, 6, 3))
	guard.setDir(EAST)
	TEST_ASSERT_EQUAL(torch.light_dir, NORTHEAST, "A turn just after a step snapped the beam round")
	stealth_ai.stealth_torch_settle(stealth_ai.torch_serial)
	TEST_ASSERT_EQUAL(torch.light_dir, EAST, "The beam didn't land after a turn just after a step")
	// Searching, standing: one side, back, the other side, back.
	// Its sweep runs only while its AI does (a dormant level sweeps nothing).
	stealth_ai.stealth_go_searching(stealth_at(block, 8, 3))
	TEST_ASSERT(stealth_ai.stealth_scanning() || !stealth_ai.sweeping, "A guard whose AI is off sweeps its beam")
	stealth_ai.set_ai_status(AI_STATUS_ON)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.sweeping, "A searching guard with its light on doesn't sweep")
	stealth_ai.torch_moved_at = 0
	stealth_ai.turned_at = 0
	var/side = stealth_ai.look_side
	stealth_ai.stealth_sweep_tick()
	TEST_ASSERT_EQUAL(torch.light_dir, turn(EAST, 45 * side), "The sweep's first move isn't 45 degrees to a side")
	stealth_ai.stealth_sweep_tick()
	TEST_ASSERT_EQUAL(torch.light_dir, EAST, "The sweep didn't come back to the middle")
	stealth_ai.stealth_sweep_tick()
	TEST_ASSERT_EQUAL(torch.light_dir, turn(EAST, -45 * side), "The sweep didn't go to the other side")
	stealth_ai.stealth_sweep_tick()
	TEST_ASSERT_EQUAL(torch.light_dir, EAST, "The sweep didn't end in the middle")
	// A step interrupts it; calm again, it stops.
	stealth_ai.stealth_sweep_tick()
	guard.forceMove(stealth_at(block, 7, 3))
	TEST_ASSERT_EQUAL(torch.light_dir, EAST, "A step left the beam off to the side")
	stealth_ai.stealth_go_unaware()
	stealth_ai.stealth_sweep_tick()
	TEST_ASSERT(!stealth_ai.sweeping, "A calm guard keeps sweeping")
	for(var/dx in 0 to 11)
		for(var/dy in 0 to 6)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = FALSE
	qdel(guard)
	TEST_ASSERT(QDELETED(torch), "A deleted guard left its lamp behind")
	qdel(block)

/// Decision 41, real lighting: the beam is a wedge. It lights 1 to 4 tiles ahead and the tiles beside 2 and 3
/// ahead; the guard's own tile, its sides, its back, 5 ahead and two tiles off the line stay dark. A wall stops it.
/// Decision 42: the cone players see shows and hides with the light, points where the beam points, and stops at a wall.
/datum/unit_test/voidcrew_stealth_light_cone

/datum/unit_test/voidcrew_stealth_light_cone/Run()
	// STEALTH_BEAM_LENGTHS: the unit tests are included before voidcrew/_DEFINES, so the number is written out
	var/open_reach = 22
	var/datum/turf_reservation/block = stealth_block(12, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	for(var/dx in 0 to 11)
		for(var/dy in 0 to 6)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = TRUE
	guard.setDir(EAST)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard in the dark has no beam")
	var/obj/effect/abstract/stealth_beam/beam = stealth_ai.beam
	TEST_ASSERT_NOTNULL(beam, "A lit guard shows no cone")
	stealth_settle_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.holder, guard, "The cone isn't on its guard")
	TEST_ASSERT(beam in guard.vis_contents, "The cone isn't drawn on its guard")
	TEST_ASSERT_EQUAL(beam.shown_dir, EAST, "The cone doesn't point the way the guard faces")
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_[open_reach]", "An open beam's cone is cut short, or has no glow facing sideways")
	TEST_ASSERT_EQUAL(PLANE_TO_TRUE(beam.plane), O_LIGHTING_VISUAL_PLANE, "The cone isn't drawn as light")
	// It follows the beam through a turn, and facing away the lamp's glow is hidden by the body. It never moves ahead
	// of the light on the floor: until the lamp's turn is applied, it still points the old way.
	guard.setDir(NORTH)
	TEST_ASSERT(stealth_ai.torch.light?.needs_update, "A turn didn't queue the lamp's light")
	TEST_ASSERT_EQUAL(beam.shown_dir, EAST, "The cone turned before the light on the floor did")
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.shown_dir, NORTHEAST, "The cone didn't pass through the diagonal with the beam")
	stealth_ai.stealth_torch_settle(stealth_ai.torch_serial)
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.shown_dir, NORTH, "The cone didn't land on the new facing")
	TEST_ASSERT(findtext(beam.icon_state, "back_") == 1, "A guard facing away shows its lamp's glow through its body")
	// A turn of its own: the cone leads it with the beam.
	stealth_ai.stealth_turn_to(EAST)
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.shown_dir, NORTHEAST, "The cone didn't lead a turn the guard makes on its own")
	stealth_ai.stealth_finish_turn(EAST, stealth_ai.turn_planned_at)
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.shown_dir, EAST, "The cone didn't land when the led turn finished")
	// A wall two tiles ahead cuts it at the wall.
	var/turf/wall = stealth_at(block, 4, 3)
	wall.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_EQUAL(stealth_beam_reach(get_turf(guard), EAST), 7, "The cone doesn't stop on a wall two tiles ahead")
	TEST_ASSERT_EQUAL(stealth_beam_reach(stealth_at(block, 6, 3), EAST), open_reach, "The cone stops with nothing ahead")
	stealth_ai.stealth_place_torch()
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_7", "The cone runs through a wall two tiles ahead")
	// Off with the light at once, and gone with the guard.
	stealth_ai.stealth_set_light(FALSE)
	TEST_ASSERT_NULL(beam.holder, "The cone stayed on with the light off")
	TEST_ASSERT(!(beam in guard.vis_contents), "The cone is still drawn with the light off")
	stealth_ai.stealth_set_light(TRUE)
	stealth_settle_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.holder, guard, "The cone didn't come back with the light")
	qdel(guard)
	TEST_ASSERT(QDELETED(beam), "The cone outlived its guard")
	qdel(block)

/// Playtest 2 (owner: "light goes through walls"): while a new aim waits on the lamp, the old cone stays on the guard.
/// Walking toward a wall or round a corner in that wait, the old cone must still stop at the wall from where it is now.
/// Backing away from a wall, it stops there too while the body glides off the old tile.
/datum/unit_test/voidcrew_stealth_light_cone_wall

/datum/unit_test/voidcrew_stealth_light_cone_wall/Run()
	var/open_reach = 22
	var/datum/turf_reservation/block = stealth_block(12, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	for(var/dx in 0 to 11)
		for(var/dy in 0 to 6)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = TRUE
	// A wall four tiles ahead.
	var/turf/wall = stealth_at(block, 6, 3)
	wall.ChangeTurf(/turf/closed/wall)
	guard.setDir(EAST)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard in the dark has no beam")
	var/obj/effect/abstract/stealth_beam/beam = stealth_ai.beam
	stealth_settle_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_15", "The cone doesn't stop on a wall four tiles ahead")
	// One step on toward it, the lamp not yet applied: the old aim waits, cut at the wall from the new tile.
	guard.forceMove(stealth_at(block, 3, 3))
	TEST_ASSERT(stealth_ai.torch.light?.needs_update, "A step didn't queue the lamp's light")
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_11", "The waiting cone runs through the wall it walked toward")
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_11", "The cone isn't cut at the wall once the light lands")
	// Round a corner: a step north to a tile with a wall right beside it to the east, the cone still pointing east.
	var/turf/side_wall = stealth_at(block, 4, 4)
	side_wall.ChangeTurf(/turf/closed/wall)
	guard.forceMove(stealth_at(block, 3, 4))
	TEST_ASSERT(stealth_ai.torch.light?.needs_update, "A step didn't queue the lamp's light")
	TEST_ASSERT_EQUAL(beam.shown_dir, EAST, "Test fixture: the cone turned before the light did")
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_3", "The waiting cone runs through the wall beside its new tile")
	stealth_apply_light(stealth_ai.torch)
	// Backing away from the wall: until the body lands, the cone stops at the wall ahead of the tile it left.
	guard.forceMove(stealth_at(block, 3, 3))
	stealth_apply_light(stealth_ai.torch)
	stealth_ai.torch_from = null
	stealth_ai.stealth_place_torch()
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_11", "Test fixture: the cone isn't cut at the wall")
	guard.set_glide_size(2)
	guard.forceMove(stealth_at(block, 2, 3))
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_11", "Mid-step backing away, the cone ran past the wall ahead of the tile it left")
	stealth_ai.torch_from_until = world.time
	stealth_ai.stealth_cone_landed()
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_15", "Landed, the cone didn't reach the wall again")
	// Nothing ahead: full length.
	wall.ChangeTurf(/turf/open/floor/iron)
	stealth_ai.stealth_place_torch()
	stealth_apply_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(beam.icon_state, "beam_[open_reach]", "An open cone is cut short")
	qdel(guard)
	qdel(block)

/datum/unit_test/voidcrew_stealth_light_beam

/datum/unit_test/voidcrew_stealth_light_beam/Run()
	var/datum/turf_reservation/block = stealth_block(12, 9)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 12, 9)
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 5, 4)), "Reserved test space isn't dark, so the light can't be tested")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 4)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard standing in the dark didn't switch its light on")
	stealth_settle_light(stealth_ai.torch)
	// offsets from the guard (ahead, aside)
	var/list/lit = list(list(1, 0), list(2, 0), list(3, 0), list(4, 0), list(2, 1), list(2, -1), list(3, 1), list(3, -1))
	var/list/dark = list(list(0, 0), list(-1, 0), list(0, 1), list(0, -1), list(-1, 1), list(5, 0), list(6, 0), list(3, 2), list(3, -2), list(1, 2))
	for(var/list/offset as anything in lit)
		TEST_ASSERT(!stealth_tile_is_dark(stealth_at(block, 2 + offset[1], 4 + offset[2])), "The beam doesn't light [offset[1]] ahead, [offset[2]] aside")
	for(var/list/offset as anything in dark)
		TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 2 + offset[1], 4 + offset[2])), "The beam lights [offset[1]] ahead, [offset[2]] aside")
	// The beam is what the guard's own "is my spot dark" test leaves out, wherever it lands.
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 4, 4), no_guard_lights = TRUE), "A tile lit only by a guard's beam isn't dark without guard lights")
	TEST_ASSERT(stealth_room_is_dark(stealth_at(block, 4, 4)), "A tile lit only by a guard's beam isn't dark by the room's light")
	// Turned north, the wedge turns with it.
	guard.setDir(NORTH)
	stealth_ai.stealth_torch_settle(stealth_ai.torch_serial)
	stealth_settle_light(stealth_ai.torch)
	TEST_ASSERT(!stealth_tile_is_dark(stealth_at(block, 2, 6)), "The beam doesn't light 2 ahead of a guard facing north")
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 4, 4)), "The beam still lights where the guard used to face")
	qdel(guard)
	stealth_settle_light()
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 2, 6)), "The beam stayed lit after its guard was gone")
	// A wall across the room two tiles ahead: lit up to it, dark past it. A lone wall tile wouldn't do: tg lights a
	// tile by its corners, and the tiles beside the one behind a pillar still see the beam.
	for(var/dy in 1 to 7)
		var/turf/wall = stealth_at(block, 4, dy)
		wall.ChangeTurf(/turf/closed/wall)
	guard = stealth_guard(block, 2, 4)
	stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_update_light()
	stealth_settle_light(stealth_ai.torch)
	TEST_ASSERT(!stealth_tile_is_dark(stealth_at(block, 3, 4)), "The beam doesn't light the tile before a wall")
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 5, 4)), "The beam lights the tile behind a wall")
	qdel(guard)
	qdel(block)

/// Decision 41: a lit flashlight carried behind an unaware guard that stands in the dark makes it suspicious, never
/// alert, and it turns to look. Unlit, out of the light's reach, or in a lit room, it draws nothing.
/datum/unit_test/voidcrew_stealth_stray_light

/datum/unit_test/voidcrew_stealth_stray_light/Run()
	var/datum/turf_reservation/block = stealth_block(14, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	for(var/dx in 0 to 13)
		for(var/dy in 0 to 4)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = TRUE
	var/mob/living/carbon/human/person = stealth_person(block, 6, 2)
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 9, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	TEST_ASSERT_EQUAL(stealth_carried_light(person), 0, "Someone with no light counts as carrying one")
	// Three tiles behind it in the dark, no light: nothing.
	stealth_scans(guard, 4)
	var/list/entry = stealth_ai.notice_map[REF(person)]
	TEST_ASSERT(isnull(entry) || entry[1] == 0, "A guard built notice on someone behind it in the dark ([entry?[1]])")
	// The same with a lit flashlight in hand.
	var/obj/item/flashlight/held = allocate(/obj/item/flashlight, get_turf(person))
	TEST_ASSERT(person.put_in_hands(held), "Test fixture: the flashlight can't be held")
	held.attack_self(person)
	TEST_ASSERT(held.light_on, "Test fixture: the flashlight didn't switch on")
	TEST_ASSERT(stealth_carried_light(person) >= 3, "A lit flashlight in hand reaches [stealth_carried_light(person)] tiles")
	for(var/i in 1 to 6)
		stealth_scans(guard, 1)
		if(stealth_ai.stealth_state() != "unaware")
			break
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A lit flashlight behind a guard in the dark made it [stealth_ai.stealth_state()]")
	entry = stealth_ai.notice_map[REF(person)]
	TEST_ASSERT(entry[1] <= 1, "A light behind a guard filled its notice past suspicious ([entry[1]])")
	TEST_ASSERT_EQUAL(guard.dir, WEST, "The guard didn't turn to the light")
	qdel(guard)
	// Out of the light's reach: nothing.
	person.forceMove(stealth_at(block, 1, 2))
	guard = stealth_guard(block, 9, 2)
	stealth_ai = stealth_ai(guard)
	stealth_scans(guard, 6)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A light 8 tiles behind a guard drew its notice")
	qdel(guard)
	// In a lit room a flashlight is nothing to wonder at.
	person.forceMove(stealth_at(block, 6, 2))
	GLOB.stealth_test_dark_turfs[stealth_at(block, 9, 2)] = FALSE
	guard = stealth_guard(block, 9, 2)
	stealth_ai = stealth_ai(guard)
	stealth_scans(guard, 6)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A flashlight behind a guard in a lit room drew its notice")
	entry = stealth_ai.notice_map[REF(person)]
	TEST_ASSERT(isnull(entry) || entry[1] == 0, "A flashlight behind a guard in a lit room built notice ([entry?[1]])")
	for(var/dx in 0 to 13)
		for(var/dy in 0 to 4)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = FALSE
	qdel(block)

/// Real lighting: in a dark room the guard's pool lights what it lands on and nothing behind it.
/datum/unit_test/voidcrew_stealth_light_sight

/datum/unit_test/voidcrew_stealth_light_sight/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 12, 5)
	var/mob/living/carbon/human/person = stealth_person(block, 5, 2)
	var/turf/spot = get_turf(person)
	TEST_ASSERT(stealth_tile_is_dark(spot), "Reserved test space isn't dark, so the light can't be tested")
	// Without a light: 3 tiles off in the dark fills slowly (no near fill in the dark, decision 39).
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	qdel(stealth_ai.stealth_light())
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard with no light noticed someone 3 tiles off in the dark in one look")
	qdel(guard)
	// With one: it switches it on, the pool lands on them, and it notices them.
	guard = stealth_guard(block, 2, 2)
	stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A guard standing in the dark didn't switch its light on")
	stealth_settle_light(stealth_ai.torch)
	TEST_ASSERT(!stealth_tile_is_dark(spot), "The guard's pool doesn't light the tile it lands on")
	TEST_ASSERT(!stealth_tile_is_dark(stealth_at(block, 6, 2)), "The guard's pool doesn't light the tile past it")
	TEST_ASSERT(stealth_tile_is_dark(get_turf(guard)), "The guard's pool lights its own tile")
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 1, 2)), "The guard's pool lights the tile behind it")
	TEST_ASSERT(stealth_tile_is_dark(stealth_at(block, 8, 2)), "The guard's pool lights 6 tiles ahead")
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard didn't notice someone its pool was on")
	qdel(guard)
	stealth_settle_light()
	TEST_ASSERT(stealth_tile_is_dark(spot), "The pool stayed lit after its guard was gone")
	qdel(block)

/// Real lighting: a searching guard sees as far as in daylight onto the tiles its pool lights.
/datum/unit_test/voidcrew_stealth_light_body

/datum/unit_test/voidcrew_stealth_light_body/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_unlist(block, 12, 5)
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 7, 4))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 2)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 4, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = stealth_ai(friend)
	stealth_ai.stealth_setup()
	friend_ai.stealth_setup()
	qdel(friend_ai.stealth_light())
	friend.death()
	var/turf/body_turf = get_turf(friend)
	TEST_ASSERT(stealth_tile_is_dark(body_turf), "Reserved test space isn't dark, so the light can't be tested")
	var/datum/stealth_skill/profile = stealth_ai.stealth_skill()
	// Its light cut out, the body's tile is dark to it.
	var/obj/item/flashlight/light = stealth_ai.stealth_light()
	light.on_saboteur(null, 1 MINUTES)
	stealth_ai.stealth_go_searching(get_turf(guard))
	TEST_ASSERT(!stealth_ai.stealth_light_shows(), "A guard's cut-out light shows a pool")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_range_onto(body_turf), profile.dark_sight_range, "A guard sees into the dark as if it were lit")
	// With it on, it is lit, and it finds the body.
	light.disabled_time = 0
	stealth_ai.stealth_update_light()
	TEST_ASSERT(stealth_ai.stealth_light_shows(), "A searching guard's light didn't come on")
	stealth_settle_light(stealth_ai.torch)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_range_onto(body_turf), profile.sight_range, "A guard's pool doesn't light the body it lands on")
	stealth_ai.next_body_scan = 0
	stealth_ai.stealth_check_bodies()
	TEST_ASSERT(REF(friend) in stealth_ai.blackboard["stealth_bodies_seen"], "A searching guard with its light on didn't find the body")
	TEST_ASSERT(get_dist(stealth_ai.search_center, friend) <= 1, "The search didn't move to the body")
	TEST_ASSERT(stealth_ai.search_for_body, "The search isn't marked as over a body")
	qdel(block)

/// Elbow to elbow: someone on the next tile in front is seen in the dark (an alert, decision 32); behind or side-on
/// is not; two ahead in the dark fills slowly (no near fill in the dark, decision 39).
/datum/unit_test/voidcrew_stealth_adjacent

/datum/unit_test/voidcrew_stealth_adjacent/Run()
	var/datum/turf_reservation/block = stealth_block(7, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	for(var/dx in 0 to 6)
		for(var/dy in 0 to 6)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = TRUE
	var/mob/living/carbon/human/person = stealth_person(block, 4, 3)
	// offset from the guard => its state after two scans
	var/list/cases = list(
		list(1, 0, "alert"),
		list(-1, 0, "unaware"),
		list(0, 1, "unaware"),
		list(2, 0, "unaware"),
	)
	for(var/list/test_case as anything in cases)
		person.forceMove(stealth_at(block, 3 + test_case[1], 3 + test_case[2]))
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 3, 3)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		stealth_scans(guard, 2)
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), test_case[3], "Offset ([test_case[1]], [test_case[2]]) in the dark: state [stealth_ai.stealth_state()]")
		qdel(guard)
	for(var/dx in 0 to 6)
		for(var/dy in 0 to 6)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = FALSE
	qdel(block)

/// Takes a test block's turfs off the test light list, so they read the real light.
/datum/unit_test/proc/stealth_unlist(datum/turf_reservation/block, width, height)
	for(var/dx in 0 to width - 1)
		for(var/dy in 0 to height - 1)
			GLOB.stealth_test_dark_turfs -= stealth_at(block, dx, dy)

/// A quick volley from one spot is one noise; the same gun 3 s later is a new one; a loud gun still alarms.
/datum/unit_test/voidcrew_stealth_live/hear/volley

/datum/unit_test/voidcrew_stealth_live/hear/volley/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/first = walker(5, 1)
	var/mob/living/carbon/human/npc/second = walker(7, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = first.ai_controller
	var/datum/stealth_group/group = first_ai.group
	var/turf/spot = at(4, 1)
	TEST_ASSERT(stealth_noise(spot, "gun_quiet") > 0, "A suppressed shot a tile off wasn't heard")
	for(var/i in 1 to 2)
		group.rewind(0.5 SECONDS)
		TEST_ASSERT_EQUAL(stealth_noise(spot, "gun_quiet"), 0, "Shot [i + 1] of a volley counted as a new noise")
	TEST_ASSERT_EQUAL(group.lure_count(spot), 1, "A volley counted as more than one lure")
	TEST_ASSERT_EQUAL(state_of(second), "unaware", "A volley sent a second guard")
	// A loud gun from the same spot is still an alarm.
	TEST_ASSERT(stealth_noise(spot, "gun_long") > 0, "A rifle after the volley wasn't heard")
	TEST_ASSERT_EQUAL(state_of(second), "searching", "A rifle shot after a quiet volley didn't send the guards running")
	// The same quiet gun later is a new noise.
	settle(first)
	settle(second)
	group.rewind(3.5 SECONDS)
	TEST_ASSERT(stealth_noise(spot, "gun_quiet") > 0, "A shot 3.5 s after the volley was merged into it")
	no_targets(list(first, second))

/// A sentry faces the way it was placed, glancing aside only now and then.
/datum/unit_test/voidcrew_stealth_live/sentry_facing

/datum/unit_test/voidcrew_stealth_live/sentry_facing/Run()
	TEST_ASSERT(make_room(14, 5), "No room for the test")
	person_at(13, 4)
	var/mob/living/carbon/human/npc/guard = guard_at(1, 2, SOUTH)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	var/deadline = world.time + 10 SECONDS
	while(!stealth_ai.stealth_ready && world.time < deadline)
		sleep(1)
	TEST_ASSERT(stealth_ai.stealth_ready, "The sentry never planned")
	sleep(1 SECONDS)
	TEST_ASSERT_NULL(stealth_ai.route_id, "A guard with no stop near it claimed a route")
	TEST_ASSERT_EQUAL(stealth_ai.sentry_dir, SOUTH, "A sentry placed facing south took [dir2text(stealth_ai.sentry_dir)] as its post")
	TEST_ASSERT_EQUAL(guard.dir, SOUTH, "A sentry placed facing south faces [dir2text(guard.dir)] a second later")
	var/total = 0
	var/count = 0
	for(var/i in 1 to 24)
		sleep(0.5 SECONDS)
		total++
		if(guard.dir == SOUTH)
			count++
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "The sentry was disturbed during the test")
	TEST_ASSERT(count >= total * 0.7, "A sentry faced its post only [count] of [total] looks over 12 s")

/// Someone carrying a lit light is lit up by it: a guard sees them at its full range in the dark, wherever the beam points.
/datum/unit_test/voidcrew_stealth_light_carried_seen

/datum/unit_test/voidcrew_stealth_light_carried_seen/Run()
	var/datum/turf_reservation/block = stealth_block(16, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	for(var/dx in 0 to 15)
		for(var/dy in 0 to 4)
			GLOB.stealth_test_dark_turfs[stealth_at(block, dx, dy)] = TRUE
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/stealth_skill/profile = stealth_ai.stealth_skill()
	// In its cone in the dark, past how far it sees in the dark but within its full sight.
	var/mob/living/carbon/human/person = stealth_person(block, 2 + profile.dark_sight_range + 2, 2)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_range_onto(get_turf(person), person), profile.dark_sight_range, "Someone in the dark with no light is seen at full range")
	stealth_scans(guard, 2)
	var/list/entry = stealth_ai.notice_map[REF(person)]
	TEST_ASSERT(isnull(entry) || entry[1] == 0, "A guard built notice on someone past its dark sight with no light ([entry?[1]])")
	var/obj/item/flashlight/held = allocate(/obj/item/flashlight, get_turf(person))
	TEST_ASSERT(person.put_in_hands(held), "Test fixture: the flashlight can't be held")
	person.setDir(WEST)
	held.attack_self(person)
	TEST_ASSERT(held.light_on, "Test fixture: the flashlight didn't switch on")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_range_onto(get_turf(person), person), profile.sight_range, "Someone carrying a lit light isn't seen at full range in the dark")
	stealth_scans(guard, 2)
	entry = stealth_ai.notice_map[REF(person)]
	TEST_ASSERT(entry && entry[1] > 0, "A guard didn't notice someone carrying a lit light in the dark")
