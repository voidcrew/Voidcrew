/**
 * # Chrome animations, second batch
 *
 * Like the first batch's tests: each animation puts its holders, filters,
 * looks and timers on, and they come off again when it ends or is cut short
 * (the chrome pulled, the bearer dead, the sequence cancelled).
 *
 * Unit-test files compile before voidcrew/_DEFINES/ and the module's own
 * defines are local, so looks, states and filter names are literals here.
 */

/// TRUE if a chrome animation holder playing [state] is drawn on [bearer].
/proc/voidcrew_test_anim_state(atom/movable/bearer, state)
	for(var/obj/effect/abstract/cyberware_anim/holder in bearer.vis_contents)
		if(holder.icon_state == state)
			return TRUE
	return FALSE

/// Redline: the window lights the nodes and the halo, the crash cools them and
/// slumps the body, and the end, a death or a pulled core leaves nothing behind.
/datum/unit_test/voidcrew_cyberware_anim2_redline

/datum/unit_test/voidcrew_cyberware_anim2_redline/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/redline/core = allocate(/obj/item/organ/cyberimp/cyberware/redline)
	TEST_ASSERT(core.Insert(bearer, special = TRUE), "Test fixture: Redline insert refused")

	bearer.apply_status_effect(/datum/status_effect/cyberware_redline_window, core)
	TEST_ASSERT_EQUAL(core.burn_look, "flash", "The nodes didn't flash when the burn kicked in")
	TEST_ASSERT(core.burn_look_timer, "The nodes flashed and never ran red")
	TEST_ASSERT(findtext(bearer.icon_render_keys[BODY_ZONE_CHEST], "flash"), "The chest wasn't redrawn for the flash")
	TEST_ASSERT(bearer.get_filter("cyberware_redline_window"), "The burn has no red outline")
	TEST_ASSERT(core.burn_light_ref?.resolve(), "The burn throws no light")
	TEST_ASSERT((locate(/obj/effect/temp_visual/circle_wave/cyberware_roar) in get_turf(bearer)), "The roar rolled no ring")
	core.set_burn_look("hot")
	var/found_nodes = FALSE
	var/found_eyes = FALSE
	for(var/image/part as anything in core.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_CHEST)))
		if(part.icon_state == "redline_hot")
			found_nodes = TRUE
			TEST_ASSERT_EQUAL(part.layer, -13.7, "Red-hot nodes don't shine through what is worn on the back")
		if(part.icon_state == "eyes_l")
			found_eyes = TRUE
	TEST_ASSERT(found_nodes, "The red-hot nodes aren't drawn over the core")
	TEST_ASSERT(found_eyes, "The eyes don't flood red")

	bearer.remove_status_effect(/datum/status_effect/cyberware_redline_window)
	TEST_ASSERT(bearer.has_status_effect(/datum/status_effect/cyberware_redline_crash), "Test fixture: no crash after the window")
	TEST_ASSERT_EQUAL(core.burn_look, "surge", "The spine doesn't run white as the crash begins")
	var/found_spine = FALSE
	for(var/image/part as anything in core.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_CHEST)))
		if(part.icon_state == "redline_surge")
			found_spine = TRUE
	TEST_ASSERT(found_spine, "The white spine isn't drawn over the core")
	TEST_ASSERT(core.burn_look_timer, "The charge never leaves the spine")
	TEST_ASSERT(!bearer.get_filter("cyberware_redline_window"), "The red outline outlived the window")
	TEST_ASSERT(bearer.get_filter("cyberware_redline_gutter"), "The outline goes out without a stutter")
	// Its stutters by hand. Each is stored, so anything that rebuilds the body's filters meanwhile can't relight it.
	core.gutter_burn(WEAKREF(bearer), 1)
	TEST_ASSERT_EQUAL(bearer.filter_data["cyberware_redline_gutter"]["color"], "#ff2a2a00", "The guttering outline doesn't go out between stutters")
	core.gutter_burn(WEAKREF(bearer), 5)
	TEST_ASSERT(!bearer.get_filter("cyberware_redline_gutter"), "The outline never finishes guttering out")
	TEST_ASSERT(!core.burn_light_ref?.resolve(), "The red light outlived the window")
	TEST_ASSERT(bearer.get_filter("cyberware_redline_sag"), "The crash doesn't slump the body")
	// The charge leaves the spine: the nodes cool, the eyes dim, and arcs crawl out across the deck under the body.
	core.ground_burn()
	TEST_ASSERT_EQUAL(core.burn_look, "cool1", "The nodes didn't start cooling once the charge left them")
	var/obj/effect/temp_visual/cyberware_redline_ground/arcs = locate() in get_turf(bearer)
	TEST_ASSERT_NOTNULL(arcs, "The charge never earths through the deck")
	TEST_ASSERT_EQUAL(PLANE_TO_TRUE(arcs.plane), FLOOR_PLANE, "The arcs on the deck draw over the people standing on it")
	TEST_ASSERT_EQUAL(arcs.pixel_y, 0, "The arcs on the deck sort a row forward of their own tile")
	TEST_ASSERT(icon_exists(arcs.icon, arcs.icon_state), "The arcs on the deck have no picture")
	var/found_dying_eyes = FALSE
	for(var/image/part as anything in core.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_CHEST)))
		if(part.icon_state == "eyes_l")
			found_dying_eyes = TRUE
	TEST_ASSERT(found_dying_eyes, "The red goes out of the eyes at once, with no dying flicker")

	bearer.remove_status_effect(/datum/status_effect/cyberware_redline_crash)
	TEST_ASSERT_NULL(core.burn_look, "The nodes kept a look after the crash")
	// A living body eases up out of the slump, and the filter comes off once it is flat.
	TEST_ASSERT_EQUAL(bearer.filter_data?["cyberware_redline_sag"]?["size"], 0, "The body doesn't straighten up when the crash ends")
	cyberware_redline_straightened(WEAKREF(bearer))
	TEST_ASSERT(!bearer.get_filter("cyberware_redline_sag"), "The slump outlived the crash")
	TEST_ASSERT(!bearer.get_filter("cyberware_redline_gutter"), "The outline's last stutter outlived the crash")
	TEST_ASSERT(!core.burn_look_timer, "Node looks keep coming after the crash")

	// Dead mid-burn: the picture goes at once, though the window runs on.
	bearer.apply_status_effect(/datum/status_effect/cyberware_redline_window, core)
	bearer.death()
	TEST_ASSERT_NULL(core.burn_look, "A dead body kept its red-hot nodes")
	TEST_ASSERT(!bearer.get_filter("cyberware_redline_window"), "A dead body kept the red outline")
	TEST_ASSERT(!core.burn_light_ref?.resolve(), "A dead body kept the red light")

	// Pulled mid-crash: nothing stays on the old bearer.
	var/mob/living/carbon/human/next_bearer = allocate(/mob/living/carbon/human/consistent)
	core.Remove(bearer, special = TRUE)
	TEST_ASSERT(core.Insert(next_bearer, special = TRUE), "Test fixture: Redline reinsert refused")
	next_bearer.apply_status_effect(/datum/status_effect/cyberware_redline_window, core)
	next_bearer.remove_status_effect(/datum/status_effect/cyberware_redline_window)
	core.Remove(next_bearer, special = TRUE)
	TEST_ASSERT_NULL(core.burn_look, "A pulled core kept its node look")
	TEST_ASSERT(!next_bearer.get_filter("cyberware_redline_sag"), "A pulled core left the slump")
	TEST_ASSERT(!next_bearer.get_filter("cyberware_redline_gutter"), "A pulled core left the outline stuttering")
	TEST_ASSERT(!core.burn_look_timer, "A pulled core still earths its charge")

/// Lazarus: crit starts the charge, death or a pulled node ends it, and the
/// jolt flashes, bursts and springs the patient without leaving anything on.
/datum/unit_test/voidcrew_cyberware_anim2_lazarus

/datum/unit_test/voidcrew_cyberware_anim2_lazarus/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/lazarus/node = allocate(/obj/item/organ/cyberimp/cyberware/lazarus)
	TEST_ASSERT(node.Insert(patient, special = TRUE), "Test fixture: Lazarus insert refused")

	patient.adjustBruteLoss(120)
	TEST_ASSERT(patient.stat == SOFT_CRIT || patient.stat == HARD_CRIT, "Test fixture: the patient isn't in crit")
	TEST_ASSERT(node.jolting, "Test fixture: crit didn't start the windup")
	TEST_ASSERT(voidcrew_test_anim_state(patient, "lazarus_charge"), "The windup has no charge glow")
	TEST_ASSERT(voidcrew_test_anim_state(patient, "lazarus_arcs"), "The windup has no arcs")
	TEST_ASSERT(patient.get_filter("cyberware_lazarus_charge"), "The windup doesn't light the body")

	node.jolt(node.jolt_generation, WEAKREF(patient))
	TEST_ASSERT(patient.stat != DEAD, "Test fixture: the jolt didn't take")
	TEST_ASSERT(!voidcrew_test_anim_state(patient, "lazarus_charge"), "The charge glow outlived the jolt")
	TEST_ASSERT(!patient.get_filter("cyberware_lazarus_charge"), "The charge's halo outlived the jolt")
	TEST_ASSERT(voidcrew_test_anim_state(patient, "lazarus_jolt"), "The jolt has no burst")
	TEST_ASSERT(patient.get_filter("cyberware_flash"), "The jolt has no flash")
	TEST_ASSERT_EQUAL(patient.has_offset("cyberware_lazarus_spring", PIXEL_Z_OFFSET), 3, "The jolt doesn't spring the patient up")

	// Dead during the windup: the charge dies with them.
	var/mob/living/carbon/human/doomed = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/lazarus/second_node = allocate(/obj/item/organ/cyberimp/cyberware/lazarus)
	TEST_ASSERT(second_node.Insert(doomed, special = TRUE), "Test fixture: second Lazarus insert refused")
	second_node.play_charge_fx(doomed, 1 SECONDS)
	doomed.death()
	TEST_ASSERT(!(locate(/obj/effect/abstract/cyberware_anim) in doomed.vis_contents), "The charge played on a corpse")
	TEST_ASSERT(!doomed.get_filter("cyberware_lazarus_charge"), "The charge's halo stayed on a corpse")

	// Pulled during the windup.
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/lazarus/third_node = allocate(/obj/item/organ/cyberimp/cyberware/lazarus)
	TEST_ASSERT(third_node.Insert(donor, special = TRUE), "Test fixture: third Lazarus insert refused")
	third_node.play_charge_fx(donor, 1 SECONDS)
	third_node.Remove(donor, special = TRUE)
	TEST_ASSERT(!(locate(/obj/effect/abstract/cyberware_anim) in donor.vis_contents), "A pulled node left its charge")
	TEST_ASSERT(!donor.get_filter("cyberware_lazarus_charge"), "A pulled node left the charge's halo")

/// Leaps: take-off carries the drawing over to the landing and only the drawing, drawn over whoever stands on its
/// row; the fall brings it down as the landing is due; touchdown gives it back without a glide; a leap up or down
/// the screen moves its place in the front-to-back order with it; a leap that never lands is put down anyway.
/datum/unit_test/voidcrew_cyberware_anim2_leap

/datum/unit_test/voidcrew_cyberware_anim2_leap/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/turf/landing = locate(start.x + 2, start.y, start.z)
	TEST_ASSERT(landing && landing.x <= run_loc_floor_top_right.x, "Test fixture: the test room is too narrow for a two-tile leap")
	var/mob/living/carbon/human/jumper = allocate(/mob/living/carbon/human/consistent, start)

	var/ground_layer = jumper.layer
	cyberware_leap_takeoff_fx(jumper, start, landing, 0.2 SECONDS, 20, 26)
	TEST_ASSERT_EQUAL(jumper.loc, start, "The take-off moved the body")
	TEST_ASSERT_EQUAL(jumper.pixel_w, 64, "The leap's drawing doesn't end over the landing")
	TEST_ASSERT_EQUAL(jumper.pixel_z, 26, "The leap's drawing doesn't rise")
	cyberware_leap_fall_fx(WEAKREF(jumper), 0.1 SECONDS)
	TEST_ASSERT_EQUAL(jumper.pixel_z, 0, "The leap's drawing isn't down on the floor when its landing is due")
	TEST_ASSERT(jumper.layer > ground_layer, "A leaping body doesn't draw over the people on its row")
	TEST_ASSERT((locate(/obj/effect/temp_visual/cyberware_leap_shadow) in start), "The leap has no floor shadow")
	TEST_ASSERT(jumper.cyberware_leap_until, "Nothing watches for a leap that never lands")

	cyberware_leap_touchdown_fx(jumper)
	TEST_ASSERT_EQUAL(jumper.pixel_w, 0, "The landing left the drawing to one side")
	TEST_ASSERT_EQUAL(jumper.pixel_z, 0, "The landing left the drawing in the air")
	TEST_ASSERT_EQUAL(jumper.layer, ground_layer, "The landing left the body drawn over everyone")
	TEST_ASSERT_EQUAL(jumper.animate_movement, NO_STEPS, "The move onto the landing tile would glide after the arc")
	cyberware_leap_steps_back(WEAKREF(jumper))
	TEST_ASSERT_EQUAL(jumper.animate_movement, SLIDE_STEPS, "A landed body's steps never glide again")
	TEST_ASSERT(!jumper.cyberware_leap_until, "A landed leap is still watched")

	// One tile arcs like any other: the landing never glides, so there is nothing to hide by hopping in place.
	cyberware_leap_takeoff_fx(jumper, start, get_step(start, EAST), 0.2 SECONDS, 20, 26)
	TEST_ASSERT_EQUAL(jumper.pixel_w, 32, "A one-tile leap doesn't travel")
	cyberware_leap_touchdown_fx(jumper)

	// Up the screen the run is pixel_y, so the body's place in the front-to-back order goes with it.
	cyberware_leap_takeoff_fx(jumper, start, get_step(start, NORTH), 0.2 SECONDS, 20, 26)
	TEST_ASSERT_EQUAL(jumper.pixel_y, 32, "A leap up the screen keeps its launch row's place in the draw order")
	cyberware_leap_touchdown_fx(jumper)
	TEST_ASSERT_EQUAL(jumper.pixel_y, 0, "The landing left the drawing up the screen")

	// The pistons pulled mid-air: no landing ever runs, the failsafe puts the body down.
	cyberware_leap_takeoff_fx(jumper, start, landing, 0.2 SECONDS, 20, 26)
	jumper.cyberware_leap_until = world.time
	cyberware_leap_failsafe(WEAKREF(jumper))
	TEST_ASSERT_EQUAL(jumper.pixel_w, 0, "A leap that never landed stayed to one side")
	TEST_ASSERT_EQUAL(jumper.pixel_z, 0, "A leap that never landed stayed in the air")
	TEST_ASSERT_EQUAL(jumper.layer, ground_layer, "A leap that never landed stayed drawn over everyone")

	// The real button, end to end.
	var/obj/item/organ/cyberimp/cyberware/hopper/pistons = allocate(/obj/item/organ/cyberimp/cyberware/hopper)
	TEST_ASSERT(pistons.Insert(jumper, special = TRUE), "Test fixture: Hopper insert refused")
	var/datum/action/cooldown/cyberware/hopper_leap/action = locate() in pistons.actions
	TEST_ASSERT(action.Activate(landing), "Test fixture: the leap refused a clear two-tile jump")
	TEST_ASSERT_EQUAL(jumper.loc, start, "The leap moved the body before it landed")
	TEST_ASSERT_EQUAL(jumper.pixel_w, 64, "The Hopper's arc doesn't travel")
	action.land(landing)
	TEST_ASSERT_EQUAL(jumper.loc, landing, "The leap landed somewhere else")
	TEST_ASSERT_EQUAL(jumper.pixel_w, 0, "The Hopper landed off to one side")
	TEST_ASSERT_EQUAL(jumper.pixel_z, 0, "The Hopper landed in the air")
	TEST_ASSERT_EQUAL(jumper.layer, ground_layer, "The Hopper landed still drawn over everyone")

	// The Piledriver's impact cracks the floor and leaves it alone afterwards.
	cyberware_piledriver_impact_fx(landing, 2)
	var/obj/effect/temp_visual/cyberware_impact_cracks/cracks = locate() in landing
	TEST_ASSERT(cracks, "The impact left no cracks")
	TEST_ASSERT(cracks.timerid, "The cracks never clean themselves up")

/// Brownout: worn chrome stutters together and the show leaves no looks behind,
/// on its own, on recovery and on death.
/datum/unit_test/voidcrew_cyberware_anim2_brownout

/datum/unit_test/voidcrew_cyberware_anim2_brownout/Run()
	var/mob/living/carbon/human/bearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = allocate(/obj/item/organ/cyberimp/cyberware/cascade)
	var/obj/item/organ/cyberimp/cyberware/test_heavy/heavy = allocate(/obj/item/organ/cyberimp/cyberware/test_heavy)
	var/obj/item/organ/cyberimp/cyberware/test_overflow/overflow = allocate(/obj/item/organ/cyberimp/cyberware/test_overflow)
	TEST_ASSERT(lattice.Insert(bearer, special = TRUE), "Test fixture: Cascade insert refused")
	var/datum/component/cyberware/chrome = lattice.GetComponent(/datum/component/cyberware)

	// At rest the lattice breathes: its LEDs replace the still glow.
	var/found_led = FALSE
	var/found_still = FALSE
	for(var/image/part as anything in lattice.bodypart_aug.get_overlay(EXTERNAL_ADJACENT, bearer.get_bodypart(BODY_ZONE_CHEST)))
		if(part.icon_state == "cascade_led" || part.icon_state == "cascade_led_e")
			found_led = TRUE
		if(part.icon_state == "cascade_e")
			found_still = TRUE
	TEST_ASSERT(found_led, "The lattice's LEDs don't breathe")
	TEST_ASSERT(!found_still, "The still glow is drawn under the breathing one")

	TEST_ASSERT(heavy.Insert(bearer, special = TRUE), "Test fixture: heavy insert refused")
	if(!chrome.browned_out)
		TEST_ASSERT(overflow.Insert(bearer, special = TRUE), "Test fixture: overflow insert refused")
	TEST_ASSERT(chrome.browned_out, "Test fixture: the body didn't brown out")
	var/datum/component/chrome_brownout_show/show = bearer.GetComponent(/datum/component/chrome_brownout_show)
	TEST_ASSERT(show, "A brownout put on no show")
	TEST_ASSERT_EQUAL(lattice.cyberware_worn_look(), "warm", "The brownout didn't start with the warm stutter")
	TEST_ASSERT(show.step_timer, "The stutter stopped on its first frame")
	while(length(show.steps))
		show.advance()
	show.advance()
	TEST_ASSERT(QDELETED(show), "The brownout show didn't end")
	TEST_ASSERT_NULL(chrome.brownout_look, "The finished show left a look")
	TEST_ASSERT_EQUAL(lattice.cyberware_worn_look(), "brown", "Browned-out chrome isn't drawn browned out")

	// Back under: the stutter back on, then plain.
	if(overflow.owner)
		overflow.Remove(bearer, special = TRUE)
	heavy.Remove(bearer, special = TRUE)
	TEST_ASSERT(!chrome.browned_out, "Test fixture: the brownout didn't clear")
	show = bearer.GetComponent(/datum/component/chrome_brownout_show)
	TEST_ASSERT(show, "Coming back up played no stutter")
	TEST_ASSERT_EQUAL(lattice.cyberware_worn_look(), "brown", "The way back up didn't start dark")

	// Dead mid-stutter: the show ends and the looks go with it.
	bearer.death()
	TEST_ASSERT(QDELETED(show), "The brownout show outlived its bearer")
	TEST_ASSERT_NULL(chrome.brownout_look, "Death left a stutter look")
	TEST_ASSERT_NULL(lattice.cyberware_worn_look(), "Recovered chrome isn't drawn plain")

/// Chrome cradle: the rig follows the install's beats and pulls back and parks
/// when the sequence is cancelled, with nothing left in the gripper.
/datum/unit_test/voidcrew_cyberware_anim2_cradle

/datum/unit_test/voidcrew_cyberware_anim2_cradle/Run()
	var/obj/machinery/chrome_cradle/cradle = allocate(/obj/machinery/chrome_cradle)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent, get_turf(cradle))
	TEST_ASSERT(cradle.buckle_mob(patient, force = TRUE, check_loc = FALSE), "Test fixture: couldn't buckle the patient")
	var/obj/item/organ/cyberimp/cyberware/redline/street/ware = allocate(/obj/item/organ/cyberimp/cyberware/redline/street)
	ware.forceMove(cradle)

	cradle.begin_install(ware)
	TEST_ASSERT(cradle.busy, "Test fixture: the install didn't start")
	TEST_ASSERT_EQUAL(cradle.rig_phase, "arms_down", "The arms didn't come down on the first beat")
	TEST_ASSERT(voidcrew_test_anim_state(cradle, "rig_arms_down"), "The rig isn't drawn coming down")
	cradle.run_sequence_stage()
	TEST_ASSERT_EQUAL(cradle.rig_phase, "grip_down", "The gripper didn't come down on the second beat")
	var/obj/effect/abstract/cyberware_anim/carried = cradle.rig_ware_ref?.resolve()
	TEST_ASSERT(carried && carried.icon_state == ware.icon_state, "The gripper isn't carrying the ware")
	TEST_ASSERT(!voidcrew_test_anim_state(cradle, "rig_arms_down"), "The last move's rig stayed drawn")
	cradle.run_sequence_stage(TRUE)
	TEST_ASSERT_EQUAL(cradle.rig_phase, "press", "The gripper didn't press on the third beat")

	cradle.cancel_sequence()
	TEST_ASSERT_EQUAL(cradle.rig_phase, "retract", "A cancelled install left the rig down")
	TEST_ASSERT(QDELETED(carried), "A cancelled install left the ware in the gripper")
	TEST_ASSERT(cradle.rig_park_timer, "The rig never parks")
	cradle.park_rig()
	TEST_ASSERT_NULL(cradle.rig_phase, "The parked rig still has a move")
	TEST_ASSERT(!(locate(/obj/effect/abstract/cyberware_anim) in cradle.vis_contents), "The parked rig left a drawing")
	cradle.unbuckle_mob(patient, force = TRUE)

/// Impacts: a chrome weapon's hit plays its impact over the target in place of
/// tg's flying item, upright, turned to the attacker's side, and it goes away.
/datum/unit_test/voidcrew_cyberware_anim2_impact

/datum/unit_test/voidcrew_cyberware_anim2_impact/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/west = allocate(/mob/living/carbon/human/consistent, start)
	var/mob/living/carbon/human/east = allocate(/mob/living/carbon/human/consistent, get_step(start, EAST))

	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = allocate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis)
	blade.animate_attack(west, east)
	var/obj/effect/abstract/cyberware_anim/impact = locate() in east.vis_contents
	TEST_ASSERT(impact, "A Mantis hit drew no impact over its target")
	TEST_ASSERT_EQUAL(impact.icon_state, "impact_mantis", "A Mantis hit drew the wrong impact")
	TEST_ASSERT(impact.appearance_flags & RESET_TRANSFORM, "The impact turns with a lying target")
	TEST_ASSERT_EQUAL(impact.transform.a, 1, "A blow from the west was mirrored")
	TEST_ASSERT(length(impact.overlays), "The Mantis impact doesn't glow")
	qdel(impact)

	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/street/shiv = allocate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis/street)
	shiv.animate_attack(east, west)
	impact = locate() in west.vis_contents
	TEST_ASSERT(impact && impact.icon_state == "impact_shiv", "A Shiv hit drew the wrong impact")
	TEST_ASSERT_EQUAL(impact.transform.a, -1, "A blow from the east wasn't mirrored")
	TEST_ASSERT(!length(impact.overlays), "The Shiv's steel impact glows")
	qdel(impact)

	// The wire's lash from the hand is its picture: nothing goes over the target, not even tg's flying spool.
	for(var/wire_type in list(/obj/item/melee/cyberware_monowire, /obj/item/melee/cyberware_monowire/live))
		var/obj/item/melee/cyberware_monowire/wire = allocate(wire_type)
		wire.animate_attack(west, east)
		TEST_ASSERT(!(locate(/obj/effect/abstract/cyberware_anim) in east.vis_contents), "[wire_type] drew an impact over its target")
		TEST_ASSERT(!(locate(/atom/movable/flick_visual) in east.vis_contents), "[wire_type] drew tg's flying spool")

	// Its shock is a small crackle where the wire touched: never a bolt from the wielder, nor sparks thrown about.
	var/obj/item/melee/cyberware_monowire/live/arc = allocate(/obj/item/melee/cyberware_monowire/live)
	arc.arc_visuals(east, west)
	TEST_ASSERT(locate(/obj/effect/temp_visual/cyberware_arc_crackle) in get_turf(east), "The Arc's shock drew no crackle where it touched")
	TEST_ASSERT(!(locate(/obj/effect/ebeam) in get_turf(west)), "The Arc's shock drew a beam from the wielder")
	TEST_ASSERT(!(locate(/obj/effect/particle_effect/sparks) in range(1, east)), "The Arc's shock threw sparks")

	// A Scorch cut throws embers but draws nothing over the blade's own slash.
	cyberware_scorch_trail_fx(west, east)
	var/obj/effect/temp_visual/cyberware_scorch_embers/embers = locate() in get_turf(east)
	TEST_ASSERT(embers?.particles, "A Scorch cut threw no embers")
	TEST_ASSERT_EQUAL(embers.icon_state, "nothing", "A Scorch cut drew a picture over the blade's impact")

	// Nothing to draw on a wall or a floor: those keep tg's own.
	TEST_ASSERT_NULL(cyberware_play_impact(west, get_turf(east), "impact_mantis"), "An impact was drawn on a turf")
