/**
 * Gorilla Arms x hyperviolence (voidcrew/modules/hyperviolence_gorilla/).
 *
 * Fork defines are included after the tests, so these use the literal values, each with a comment
 * naming the define. Finishers are driven by calling advance() directly, as the #509 finisher tests do.
 */

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_gorilla_gore
	abstract_type = /datum/unit_test/voidcrew_gorilla_gore
	/// Turf -> its type before the test changed it. Put back when the test ends, however it ends.
	var/list/changed_turfs
	/// The outpost PvP enforcement a test swapped out, put back when it ends
	var/datum/outpost_pvp_enforcement/real_enforcement

/datum/unit_test/voidcrew_gorilla_gore/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		clear_mess(changed)
		changed.ChangeTurf(changed_turfs[changed])
	changed_turfs = null
	if(real_enforcement)
		GLOB.outpost_pvp_enforcement = real_enforcement
		real_enforcement = null
	return ..()

/// Changes [target] to [new_type], remembering what it was so the test puts it back
/datum/unit_test/voidcrew_gorilla_gore/proc/change_turf(turf/target, new_type)
	LAZYINITLIST(changed_turfs)
	if(!changed_turfs[target])
		changed_turfs[target] = target.type
	clear_mess(target)
	return target.ChangeTurf(new_type)

/// Puts a changed turf back now
/datum/unit_test/voidcrew_gorilla_gore/proc/restore_turf(turf/target)
	var/old_type = changed_turfs?[target]
	if(!old_type)
		return
	changed_turfs -= target
	clear_mess(target)
	target.ChangeTurf(old_type)

/// Blood and other decals listen on their turf; a turf changed under them keeps the listener and the
/// decal can never be deleted cleanly. So the floor is wiped before it changes.
/datum/unit_test/voidcrew_gorilla_gore/proc/clear_mess(turf/target)
	for(var/obj/effect/decal/cleanable/mess in target)
		qdel(mess)

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_gorilla_gore/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A human with a pair of Gorilla Arms (or Brawler myomers with [street]) at `where`, in combat mode
/datum/unit_test/voidcrew_gorilla_gore/proc/gorilla(turf/where, street = FALSE)
	var/mob/living/carbon/human/consistent/bearer = allocate(/mob/living/carbon/human/consistent, where)
	var/right_type = street ? /obj/item/organ/cyberimp/cyberware/gorilla_arms/street : /obj/item/organ/cyberimp/cyberware/gorilla_arms
	var/left_type = street ? /obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left : /obj/item/organ/cyberimp/cyberware/gorilla_arms/left
	var/obj/item/organ/right = allocate(right_type)
	var/obj/item/organ/left = allocate(left_type)
	TEST_ASSERT(right.Insert(bearer, special = TRUE), "Test fixture: the right arm wouldn't go in")
	TEST_ASSERT(left.Insert(bearer, special = TRUE), "Test fixture: the left arm wouldn't go in")
	bearer.set_combat_mode(TRUE)
	return bearer

/// The bearer's arm on [zone]
/datum/unit_test/voidcrew_gorilla_gore/proc/arm(mob/living/carbon/bearer, zone = BODY_ZONE_R_ARM)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in bearer.organs)
		if(arm.zone == zone)
			return arm

/// One punch from the right arm at [target], with the arm's own clock reset first
/datum/unit_test/voidcrew_gorilla_gore/proc/punch(mob/living/carbon/human/bearer, atom/target, zone = BODY_ZONE_R_ARM)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/fist = arm(bearer, zone)
	bearer.swap_hand(zone == BODY_ZONE_L_ARM ? 1 : 2, silent = TRUE)
	COOLDOWN_RESET(fist, slam_cooldown)
	bearer.next_move = 0
	return fist.on_punch(bearer, target, TRUE, null)

/// A human at `where`, stunned flat
/datum/unit_test/voidcrew_gorilla_gore/proc/downed(turf/where)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, where)
	victim.Paralyze(100 SECONDS)
	return victim

/// Every chrome puppet left anywhere in the test room, and every body's stand-in (what shows until a client has the puppets' pictures)
/datum/unit_test/voidcrew_gorilla_gore/proc/puppets_left()
	. = 0
	for(var/turf/floor in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		for(var/obj/effect/abstract/chrome_puppet/puppet in floor)
			.++
		for(var/obj/effect/abstract/chrome_rig_stand_in/stand_in in floor)
			.++

// =========================================================================
// THE SAFE PATH
// =========================================================================

/// A knockback stops on the last good tile before space, glass and a door, hits a wall or a standing
/// body, and never launches from a tile without gravity.
/datum/unit_test/voidcrew_gorilla_gore/safe_path

/datum/unit_test/voidcrew_gorilla_gore/safe_path/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(0, 0))
	// Clear floor: the full reach
	var/list/plan = gorilla_plan_knockback(victim, EAST, 3)
	TEST_ASSERT_EQUAL(plan[2], 3, "A clear floor didn't take the full knockback")
	TEST_ASSERT_EQUAL(plan[1], spot(3, 0), "A clear knockback landed on the wrong tile")

	// Space two tiles out: stop on the tile before it
	var/turf/hole = spot(2, 0)
	change_turf(hole, /turf/open/space)
	plan = gorilla_plan_knockback(victim, EAST, 4)
	restore_turf(hole)
	TEST_ASSERT_EQUAL(plan[2], 1, "A knockback went into space")
	TEST_ASSERT_EQUAL(plan[3], 3, "A knockback into space didn't stop short") // GORILLA_THROW_SHORT

	// Glass in the way: stop before it, and nothing hits the glass
	var/obj/structure/window/fulltile/glass = allocate(/obj/structure/window/fulltile, spot(2, 0))
	plan = gorilla_plan_knockback(victim, EAST, 4)
	TEST_ASSERT_EQUAL(plan[2], 1, "A knockback went through a window")
	TEST_ASSERT_EQUAL(plan[3], 3, "A knockback hit a window") // GORILLA_THROW_SHORT
	qdel(glass)

	// A door: the same
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, spot(1, 0))
	plan = gorilla_plan_knockback(victim, EAST, 4)
	TEST_ASSERT_EQUAL(plan[2], 0, "A knockback went into a door")
	qdel(door)

	// A wall: hit it
	var/turf/wall = spot(2, 0)
	change_turf(wall, /turf/closed/wall)
	plan = gorilla_plan_knockback(victim, EAST, 4)
	restore_turf(wall)
	TEST_ASSERT_EQUAL(plan[3], 1, "A knockback into a wall didn't hit it") // GORILLA_THROW_WALL
	TEST_ASSERT_EQUAL(plan[4], wall, "A knockback hit the wrong wall")

	// A standing body in the way: hit it
	var/mob/living/carbon/human/consistent/bystander = allocate(/mob/living/carbon/human/consistent, spot(2, 0))
	plan = gorilla_plan_knockback(victim, EAST, 4)
	TEST_ASSERT_EQUAL(plan[3], 2, "A knockback didn't hit the body in the way") // GORILLA_THROW_MOB
	TEST_ASSERT_EQUAL(plan[4], bystander, "A knockback hit the wrong body")
	qdel(bystander)

	// No gravity under the victim: no launch at all
	var/turf/start = spot(0, 0)
	change_turf(start, /turf/open/space)
	plan = gorilla_plan_knockback(victim, EAST, 4)
	restore_turf(start)
	TEST_ASSERT_EQUAL(plan[2], 0, "A body was launched from a tile without gravity")

// =========================================================================
// THE PUNCH
// =========================================================================

/// The punch goes through #509 as one message, counts as aggression at an outpost, and the shove
/// rides the safe path.
/datum/unit_test/voidcrew_gorilla_gore/punch

/datum/unit_test/voidcrew_gorilla_gore/punch/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	real_enforcement = GLOB.outpost_pvp_enforcement
	var/datum/outpost_pvp_enforcement/gorilla_spy/spy = new
	GLOB.outpost_pvp_enforcement = spy
	var/hurt_before = victim.getBruteLoss()
	var/punched = punch(bearer, victim)
	// The blow lands when the fist is there: 0.1 s (GORILLA_THRUST_LANDS)
	sleep(0.3 SECONDS)
	GLOB.outpost_pvp_enforcement = real_enforcement
	real_enforcement = null
	TEST_ASSERT_EQUAL(punched, COMPONENT_CANCEL_ATTACK_CHAIN, "The Gorilla arm didn't take the punch")
	TEST_ASSERT(victim.getBruteLoss() > hurt_before, "The piston punch did no damage")
	TEST_ASSERT_NULL(victim.hv_hit, "The punch left its attack line held")
	TEST_ASSERT(length(spy.hits) && spy.hits[1] == victim, "A piston punch wasn't counted as aggression")
	qdel(spy)

	// The shove never goes into a hazard (lava here: a space hole would vent the room and the wind would do it)
	var/turf/hole = spot(2, 0)
	victim.forceMove(spot(1, 0))
	victim.set_resting(FALSE, instant = TRUE)
	change_turf(hole, /turf/open/lava/smooth)
	punch(bearer, victim)
	sleep(1 SECONDS)
	var/landed_in = victim.loc
	restore_turf(hole)
	TEST_ASSERT_NOTEQUAL(landed_in, hole, "The piston punch knocked someone into lava")

/// Records aggression instead of judging it
/datum/outpost_pvp_enforcement/gorilla_spy
	var/list/hits = list()

/datum/outpost_pvp_enforcement/gorilla_spy/New()
	return

/datum/outpost_pvp_enforcement/gorilla_spy/register_pvp_aggression(mob/living/victim, mob/living/offender)
	hits += victim

/// Three piston hits on one arm snap it (four from Brawler myomers); heavy armour or the Atlas frame stops it.
/datum/unit_test/voidcrew_gorilla_gore/bone_breakers

/datum/unit_test/voidcrew_gorilla_gore/bone_breakers/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	for(var/i in 1 to 2)
		gorilla_add_strain(victim, BODY_ZONE_L_ARM, bearer, 3, null, EAST)
	TEST_ASSERT_NULL(arm.get_wound_type(/datum/wound/blunt/bone/critical), "An arm snapped before the third hit")
	TEST_ASSERT(gorilla_add_strain(victim, BODY_ZONE_L_ARM, bearer, 3, null, EAST), "The third piston hit didn't snap the arm")
	TEST_ASSERT_NOTNULL(arm.get_wound_type(/datum/wound/blunt/bone/critical), "A snapped arm has no compound fracture")
	TEST_ASSERT("snap_l_arm_bone" in victim.hv_gore_states() + gorilla_snap_states(victim), "A snapped arm shows no bone")

	// The head never snaps
	for(var/i in 1 to 4)
		TEST_ASSERT(!gorilla_add_strain(victim, BODY_ZONE_HEAD, bearer, 3, null, EAST), "A head snapped")

	// Brawler myomers take four
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	for(var/i in 1 to 3)
		TEST_ASSERT(!gorilla_add_strain(second, BODY_ZONE_R_LEG, bearer, 4, null, EAST), "A Brawler snapped a leg early")
	TEST_ASSERT(gorilla_add_strain(second, BODY_ZONE_R_LEG, bearer, 4, null, EAST), "The fourth Brawler hit didn't snap the leg")

	// Heavy melee armour on the limb stops it
	var/mob/living/carbon/human/consistent/armoured = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	armoured.physiology.armor = armoured.physiology.armor.generate_new_with_modifiers(list(MELEE = 60))
	for(var/i in 1 to 3)
		gorilla_add_strain(armoured, BODY_ZONE_R_ARM, bearer, 3, null, EAST)
	TEST_ASSERT_NULL(armoured.get_bodypart(BODY_ZONE_R_ARM).get_wound_type(/datum/wound/blunt/bone/critical), "Heavy armour didn't stop a snap")

	// So does the Atlas frame
	var/mob/living/carbon/human/consistent/framed = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	var/obj/item/organ/atlas = allocate(/obj/item/organ/cyberimp/cyberware/atlas)
	TEST_ASSERT(atlas.Insert(framed, special = TRUE), "Test fixture: the Atlas frame wouldn't go in")
	for(var/i in 1 to 3)
		gorilla_add_strain(framed, BODY_ZONE_R_ARM, bearer, 3, null, EAST)
	TEST_ASSERT_NULL(framed.get_bodypart(BODY_ZONE_R_ARM).get_wound_type(/datum/wound/blunt/bone/critical), "The Atlas frame let an arm snap")

/// The snapped-bone states drawn on [victim] now
/proc/gorilla_snap_states(mob/living/carbon/victim)
	. = list()
	for(var/image/snap as anything in victim.gorilla_snap_overlays)
		. += snap.icon_state

/// A grabbed body is hurled once per grab-move cooldown; the next grabbed punch holds them.
/datum/unit_test/voidcrew_gorilla_gore/hurl_cooldown

/datum/unit_test/voidcrew_gorilla_gore/hurl_cooldown/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	victim.grabbedby(bearer, supress_message = TRUE)
	victim.grabbedby(bearer, supress_message = TRUE)
	TEST_ASSERT(bearer.grab_state >= GRAB_AGGRESSIVE, "Test fixture: no aggressive grab")
	punch(bearer, victim)
	sleep(0.3 SECONDS) // the fist arrives
	TEST_ASSERT(!TIMER_COOLDOWN_FINISHED(bearer, "gorilla_grab_move"), "A hurl didn't start the grab-move cooldown") // COOLDOWN_GORILLA_GRAB_MOVE
	sleep(1 SECONDS)
	TEST_ASSERT_NOTEQUAL(victim.loc, spot(1, 0), "A grabbed body wasn't hurled")
	// Grab them again: no second hurl inside the cooldown
	victim.forceMove(spot(1, 0))
	victim.SetAllImmobility(0)
	victim.grabbedby(bearer, supress_message = TRUE)
	victim.grabbedby(bearer, supress_message = TRUE)
	punch(bearer, victim)
	sleep(0.8 SECONDS)
	TEST_ASSERT_EQUAL(victim.loc, spot(1, 0), "A grabbed body was hurled twice inside the cooldown")

// =========================================================================
// WALL IMPACTS (owner D38)
// =========================================================================

/// The mark a wall impact leaves follows the injury: a dent with no broken skin, a floor half-moon and
/// edge smear for a bleeding cut, a spray and runs for a heavy one. 
/datum/unit_test/voidcrew_gorilla_gore/wall_impact

/datum/unit_test/voidcrew_gorilla_gore/wall_impact/Run()
	var/turf/wall_spot = spot(2, 0)
	change_turf(wall_spot, /turf/closed/wall)
	var/turf/closed/wall/wall = spot(2, 0)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))

	// Unhurt: a dent, no blood
	TEST_ASSERT_EQUAL(victim.gorilla_splat_kind(), 1, "An unhurt body doesn't dent") // GORILLA_SPLAT_DENT
	var/dents_before = LAZYLEN(wall.dent_decals)
	victim.gorilla_wall_impact(wall, null)
	TEST_ASSERT_EQUAL(LAZYLEN(wall.dent_decals), dents_before + 1, "An unhurt impact left no dent")

	// A bleeding cut: the half-moon and the edge
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/slash/flesh/moderate/cut = new
	cut.apply_wound(chest, silent = TRUE)
	TEST_ASSERT_EQUAL(victim.gorilla_splat_kind(), 2, "A bleeding cut doesn't splash") // GORILLA_SPLAT_EDGE
	victim.gorilla_wall_impact(wall, null)
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/gorilla_splash) in spot(1, 0), "A bleeding impact left no half-moon")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/edge) in spot(1, 0), "A bleeding impact left no edge smear")

	// A heavy cut: the spray and the runs
	var/datum/wound/slash/flesh/severe/gash = new
	gash.apply_wound(victim.get_bodypart(BODY_ZONE_L_ARM), silent = TRUE)
	TEST_ASSERT_EQUAL(victim.gorilla_splat_kind(), 3, "A heavy cut doesn't spray") // GORILLA_SPLAT_SPRAY
	victim.gorilla_wall_impact(wall, null)
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray) in spot(1, 0), "A heavy impact left no spray")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/runs) in spot(1, 0), "A heavy impact left no runs")
	// Twice on the same wall face refreshes, never stacks
	victim.gorilla_wall_impact(wall, null)
	var/sprays = 0
	for(var/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/spray in spot(1, 0))
		if(spray.type == /obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray)
			sprays++
	TEST_ASSERT_EQUAL(sprays, 1, "Wall sprays stacked")

/// A Gorilla throw's wall crash wounds through tg (owner D48): a shove only dents; a haymaker into a wall
/// wounds an unhurt body and the mark follows the wound it caused; an already-bleeding body sprays; a hurl
/// through the real throw_impact deals the crash's own damage instead of tg's random-limb crash.
/datum/unit_test/voidcrew_gorilla_gore/wall_crash

/datum/unit_test/voidcrew_gorilla_gore/wall_crash/Run()
	var/turf/wall_spot = spot(2, 0)
	change_turf(wall_spot, /turf/closed/wall)
	var/turf/closed/wall/wall = spot(2, 0)
	var/mob/living/carbon/human/consistent/thrower = allocate(/mob/living/carbon/human/consistent, spot(0, 2))

	// A light shove: a dent, nothing else
	var/mob/living/carbon/human/consistent/shoved = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/datum/gorilla_flight/shove = new(shoved, thrower, FALSE, FALSE, 1) // GORILLA_IMPACT_SHOVE
	var/dents_before = LAZYLEN(wall.dent_decals)
	shoved.gorilla_wall_impact(wall, shove)
	shove.end()
	TEST_ASSERT_EQUAL(LAZYLEN(wall.dent_decals), dents_before + 1, "A shove into a wall left no dent")
	TEST_ASSERT_EQUAL(shoved.getBruteLoss(), 0, "A shove into a wall did damage")
	TEST_ASSERT_EQUAL(length(shoved.all_wounds), 0, "A shove into a wall wounded")
	TEST_ASSERT(!shoved.IsParalyzed(), "A shove into a wall knocked them down")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in spot(1, 0), "A shove into a wall left blood")
	qdel(shoved)

	// A haymaker into the wall: a real wound on an unhurt body, and the mark that wound calls for. The roll
	// is tg's, so a few fresh bodies get a go; each must match its own wounds.
	var/wounded_one = FALSE
	for(var/attempt in 1 to 6)
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
		var/datum/gorilla_flight/flight = new(victim, thrower, TRUE, FALSE)
		TEST_ASSERT_EQUAL(flight.impact, 3, "A haymaker flight isn't a haymaker impact") // GORILLA_IMPACT_HAYMAKER
		victim.gorilla_wall_impact(wall, flight)
		flight.end()
		TEST_ASSERT(victim.getBruteLoss() > 0, "A haymaker into a wall did no damage")
		TEST_ASSERT(victim.IsParalyzed(), "A haymaker into a wall didn't knock them down")
		var/kind = victim.gorilla_splat_kind()
		if(kind == 3) // GORILLA_SPLAT_SPRAY
			TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/runs) in spot(1, 0), "A haymaker that tore a heavy wound left no spray")
		else if(kind == 2) // GORILLA_SPLAT_EDGE
			TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/gorilla_splash) in spot(1, 0), "A haymaker that split the skin left no half-moon")
		else
			TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hv_spray) in spot(1, 0), "A haymaker with no broken skin left blood")
		if(length(victim.all_wounds))
			wounded_one = TRUE
		qdel(victim)
		clear_mess(spot(1, 0))
		if(wounded_one)
			break
	TEST_ASSERT(wounded_one, "Six haymakers into a wall never wounded an unhurt body")

	// Already bleeding hard: the spray up the wall
	var/mob/living/carbon/human/consistent/bleeder = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/datum/wound/slash/flesh/severe/gash = new
	gash.apply_wound(bleeder.get_bodypart(BODY_ZONE_L_ARM), silent = TRUE)
	var/datum/gorilla_flight/slam = new(bleeder, thrower, TRUE, FALSE)
	bleeder.gorilla_wall_impact(wall, slam)
	slam.end()
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray) in spot(1, 0), "A bleeding body slammed into a wall left no spray")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/runs) in spot(1, 0), "A bleeding body slammed into a wall left no runs")
	qdel(bleeder)
	clear_mess(spot(1, 0))

	// A hurl through the real impact: the crash's own 12 brute, not tg's random-limb crash on top
	var/mob/living/carbon/human/consistent/hurled = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/datum/gorilla_flight/hurl = new(hurled, thrower, FALSE, FALSE, 2) // GORILLA_IMPACT_HURL
	var/datum/thrownthing/throw_datum = new(hurled, wall, EAST, 1, 2, thrower, FALSE, MOVE_FORCE_STRONG, FALSE, null, null)
	hurled.throw_impact(wall, throw_datum)
	TEST_ASSERT(!throw_datum.gentle, "The wall crash left the throw marked gentle")
	TEST_ASSERT_EQUAL(hurled.getBruteLoss(), 12, "A hurl into a wall did the wrong damage") // GORILLA_WALL_HURL_BLUNT + GORILLA_WALL_HURL_EDGE
	TEST_ASSERT(hurled.IsParalyzed(), "A hurl into a wall didn't knock them down")
	hurl.end()
	qdel(throw_datum)

// =========================================================================
// THE HAYMAKER
// =========================================================================

/// Each real arm winds up a haymaker; the Brawler has none. A wound-up release hits the body in
/// front, sends it flying and spends the pistons; a swing at nothing staggers; a vent costs less.
/datum/unit_test/voidcrew_gorilla_gore/haymaker

/datum/unit_test/voidcrew_gorilla_gore/haymaker/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	var/datum/action/cooldown/cyberware/gorilla_haymaker/right_haymaker = locate() in arm(bearer, BODY_ZONE_R_ARM).actions
	var/datum/action/cooldown/cyberware/gorilla_haymaker/left_haymaker = locate() in arm(bearer, BODY_ZONE_L_ARM).actions
	TEST_ASSERT_NOTNULL(right_haymaker, "The right Gorilla arm has no haymaker")
	TEST_ASSERT_NOTNULL(left_haymaker, "The left Gorilla arm has no haymaker")
	TEST_ASSERT_EQUAL(right_haymaker.owner, bearer, "The haymaker wasn't granted")
	var/mob/living/carbon/human/brawler = gorilla(spot(4, 4), street = TRUE)
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/cyberware/gorilla_haymaker) in arm(brawler).actions, "Brawler myomers have a haymaker")

	// Wind up, then let go at someone in front
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	bearer.setDir(EAST)
	right_haymaker.Trigger(bearer)
	TEST_ASSERT(right_haymaker.charging(), "Triggering the haymaker didn't wind it up")
	TEST_ASSERT_NOTNULL(bearer.has_status_effect(/datum/status_effect/gorilla_windup), "The wind-up has no status effect")
	TEST_ASSERT(bearer.has_movespeed_modifier(/datum/movespeed_modifier/gorilla_windup), "The wind-up doesn't slow")
	// The lean: a pixel back at once, turning with the bearer, GORILLA_HAYMAKER_LEAN and a tremble at full charge
	var/datum/status_effect/gorilla_windup/windup = bearer.has_status_effect(/datum/status_effect/gorilla_windup)
	TEST_ASSERT_EQUAL(bearer.has_offset("gorilla_windup", PIXEL_X_OFFSET), -1, "The wind-up doesn't start a pixel back from an east facing")
	bearer.setDir(NORTH)
	TEST_ASSERT_EQUAL(bearer.has_offset("gorilla_windup", PIXEL_X_OFFSET), 0, "A turn left the old lean behind")
	TEST_ASSERT_EQUAL(bearer.has_offset("gorilla_windup", PIXEL_Z_OFFSET), -1, "Facing away, the lean isn't down the screen")
	bearer.setDir(EAST)
	right_haymaker.charge_started = world.time - 2 SECONDS
	windup.tick(0.2)
	TEST_ASSERT_EQUAL(bearer.has_offset("gorilla_windup", PIXEL_X_OFFSET), -4, "A full charge doesn't lean all the way back") // GORILLA_HAYMAKER_LEAN
	TEST_ASSERT(bearer.has_offset("gorilla_windup_tremble", PIXEL_W_OFFSET), "A full charge doesn't tremble")
	var/hurt_before = victim.getBruteLoss()
	right_haymaker.InterceptClickOn(bearer, null, victim)
	TEST_ASSERT(!right_haymaker.charging(), "The haymaker still winds up after the release")
	TEST_ASSERT_NULL(bearer.has_status_effect(/datum/status_effect/gorilla_windup), "The wind-up outlived the release")
	TEST_ASSERT(!bearer.has_movespeed_modifier(/datum/movespeed_modifier/gorilla_windup), "The wind-up's slow outlived it")
	TEST_ASSERT(!bearer.has_offset("gorilla_windup"), "The wind-up's lean outlived it")
	TEST_ASSERT(!bearer.has_offset("gorilla_windup_tremble"), "The wind-up's tremble outlived it")
	// The blow lands when the thrown fist does (GORILLA_HAYMAKER_THROW)
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), hurt_before, "The haymaker landed before its fist was thrown")
	sleep(0.2 SECONDS)
	TEST_ASSERT(victim.getBruteLoss() - hurt_before >= 20, "A full haymaker hit for too little") // GORILLA_HAYMAKER_MIN_DAMAGE
	TEST_ASSERT(!TIMER_COOLDOWN_FINISHED(bearer, "gorilla_pistons"), "The haymaker didn't spend the pistons") // COOLDOWN_GORILLA_PISTONS
	TEST_ASSERT(!left_haymaker.IsAvailable(), "The other arm's haymaker didn't share the cooldown")
	sleep(2 SECONDS)
	TEST_ASSERT_NOTEQUAL(victim.loc, spot(1, 0), "The haymaker didn't send them flying")

	// A swing at nothing staggers and still spends the pistons
	var/mob/living/carbon/human/whiffer = gorilla(spot(0, 4))
	var/datum/action/cooldown/cyberware/gorilla_haymaker/whiff = locate() in arm(whiffer).actions
	whiffer.setDir(EAST)
	whiff.Trigger(whiffer)
	whiff.charge_started = world.time - 1 SECONDS
	whiff.InterceptClickOn(whiffer, null, spot(1, 4))
	TEST_ASSERT_NOTNULL(whiffer.has_status_effect(/datum/status_effect/staggered), "A whiffed haymaker didn't stagger")
	TEST_ASSERT(!TIMER_COOLDOWN_FINISHED(whiffer, "gorilla_pistons"), "A whiff didn't spend the pistons")

	// Called off: the pistons vent for a shorter while
	var/mob/living/carbon/human/venter = gorilla(spot(2, 2))
	var/datum/action/cooldown/cyberware/gorilla_haymaker/vent = locate() in arm(venter).actions
	vent.Trigger(venter)
	TEST_ASSERT(vent.charging(), "Test fixture: the third haymaker didn't wind up")
	vent.unset_click_ability(venter, refund_cooldown = TRUE)
	TEST_ASSERT(!vent.charging(), "Calling the haymaker off left it winding up")
	var/left = S_TIMER_COOLDOWN_TIMELEFT(venter, "gorilla_pistons")
	TEST_ASSERT(left > 0 && left <= 5 SECONDS, "A vent cost the wrong cooldown ([left])") // GORILLA_PISTONS_VENTED

/**
 * The piston punch's arm: the blow waits for the fist; for the punch and no longer, the punching arm is a puppet over a
 * body with that arm masked out; a bearer who looks the same is not pictured again; the arm steps with a bearer who
 * steps and comes down when they turn; and a bearer who can't be drawn still lands the blow.
 */
/datum/unit_test/voidcrew_gorilla_gore/punch_thrust

/datum/unit_test/voidcrew_gorilla_gore/punch_thrust/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	bearer.setDir(EAST)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/fist = arm(bearer)
	var/obj/item/bodypart/hand = bearer.get_bodypart(BODY_ZONE_R_ARM)
	var/filters_before = length(bearer.filters)
	var/hurt_before = victim.getBruteLoss()
	TEST_ASSERT(fist.piston_hit(bearer, victim, hand, BODY_ZONE_CHEST), "The piston punch wasn't thrown")
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), hurt_before, "The piston punch landed before its fist did")
	TEST_ASSERT_NOTNULL(bearer.gorilla_thrust, "The punch drew no arm")
	TEST_ASSERT_EQUAL(puppets_left(), 2, "A punch seen from the side isn't an arm and the torso under it")
	TEST_ASSERT_EQUAL(length(bearer.filters), filters_before + 1, "The real arm wasn't masked out under its puppet")
	sleep(0.3 SECONDS)
	TEST_ASSERT(victim.getBruteLoss() > hurt_before, "The piston punch never landed")
	sleep(0.4 SECONDS)
	TEST_ASSERT_NULL(bearer.gorilla_thrust, "The punch's arm outlived the punch")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "The punch left a puppet behind")
	TEST_ASSERT_EQUAL(length(bearer.filters), filters_before, "The mask on the real arm outlived the punch")
	var/matrix/rested = bearer.transform
	TEST_ASSERT(rested.a == 1 && !rested.b && !rested.c && !rested.d && rested.e == 1 && !rested.f, "The lunge left the bearer off their feet")

	// The same look is not pictured twice; the arm walks with its bearer and comes down on a turn
	var/mob/living/carbon/human/walker = gorilla(spot(0, 2))
	var/mob/living/carbon/human/consistent/bag = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	ADD_TRAIT(bag, TRAIT_GODMODE, TRAIT_SOURCE_UNIT_TESTS)
	bag.anchored = TRUE
	walker.setDir(EAST)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/walker_fist = arm(walker)
	var/obj/item/bodypart/walker_hand = walker.get_bodypart(BODY_ZONE_R_ARM)
	walker_fist.piston_hit(walker, bag, walker_hand, BODY_ZONE_HEAD)
	var/datum/gorilla_arm_look/look = walker.gorilla_arm_looks?["[EAST]"]
	TEST_ASSERT_NOTNULL(look, "The punch kept no picture of its bearer")
	sleep(0.6 SECONDS)
	walker_fist.piston_hit(walker, bag, walker_hand, BODY_ZONE_HEAD)
	TEST_ASSERT_EQUAL(walker.gorilla_arm_looks["[EAST]"], look, "A second punch pictured a bearer who hadn't changed")
	var/datum/gorilla_thrust/thrust = walker.gorilla_thrust
	TEST_ASSERT_NOTNULL(thrust, "The second punch drew no arm")
	walker.forceMove(spot(0, 3))
	TEST_ASSERT_EQUAL(walker.gorilla_thrust, thrust, "A step took the arm down")
	for(var/obj/effect/abstract/chrome_puppet/puppet as anything in thrust.pieces)
		TEST_ASSERT_EQUAL(puppet.loc, walker.loc, "The arm didn't step with its bearer")
	walker.setDir(NORTH)
	TEST_ASSERT_NULL(walker.gorilla_thrust, "A turn left the old facing's arm up")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "A turn left a puppet behind")
	sleep(0.6 SECONDS)

	// A bearer on the floor can't be drawn: tg's lunge, and the blow still lands
	var/mob/living/carbon/human/floored = gorilla(spot(2, 4))
	var/mob/living/carbon/human/consistent/kicked = allocate(/mob/living/carbon/human/consistent, spot(3, 4))
	floored.set_resting(TRUE, silent = TRUE, instant = TRUE)
	var/kicked_before = kicked.getBruteLoss()
	arm(floored).piston_hit(floored, kicked, floored.get_bodypart(BODY_ZONE_R_ARM), BODY_ZONE_CHEST)
	TEST_ASSERT_NULL(floored.gorilla_thrust, "A bearer lying down drew an arm")
	sleep(0.3 SECONDS)
	TEST_ASSERT(kicked.getBruteLoss() > kicked_before, "A punch from the floor never landed")

	// The first punch a picture is taken for lands as soon as any other
	var/mob/living/carbon/human/fresh = gorilla(spot(3, 2))
	var/mob/living/carbon/human/consistent/dummy = allocate(/mob/living/carbon/human/consistent, spot(4, 2))
	ADD_TRAIT(dummy, TRAIT_GODMODE, TRAIT_SOURCE_UNIT_TESTS)
	dummy.anchored = TRUE
	fresh.setDir(EAST)
	var/first_wait = gorilla_thrust(fresh, dummy, BODY_ZONE_R_ARM, BODY_ZONE_CHEST)
	TEST_ASSERT_NOTNULL(fresh.gorilla_thrust, "Test fixture: the first punch drew no arm")
	TEST_ASSERT_EQUAL(first_wait, 0.1 SECONDS, "The first punch of a new look lands late") // GORILLA_THRUST_LANDS
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(gorilla_thrust(fresh, dummy, BODY_ZONE_R_ARM, BODY_ZONE_CHEST), first_wait, "A later punch lands at another time than the first")
	sleep(0.6 SECONDS)

	// The fist reaches the part it is thrown at, down to the leg of a body beside its bearer
	var/datum/gorilla_arm_look/fresh_look = fresh.gorilla_arm_looks?["[EAST]"]
	var/datum/chrome_rig/fresh_rig = fresh_look?.rig
	TEST_ASSERT_NOTNULL(fresh_rig, "Test fixture: the punch kept no picture")
	for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_LEG))
		var/list/point = gorilla_fist_target(fresh, dummy, zone)
		// GORILLA_THRUST_LUNGE_MIN, GORILLA_THRUST_LUNGE_MAX, GORILLA_THRUST_TIP, GORILLA_SWING_EASY_LENGTH, GORILLA_SWING_MAX_LENGTH
		var/list/reach = chrome_swing_reach(fresh_rig, "r", point[1], point[2], list(1, 0), 8, 16, 15, 1.9, 3.3, -90)
		var/list/fist_at = fresh_rig.hand_at("r", list(reach[2], reach[3], chrome_swing_base(reach[1], 0, 15)))
		TEST_ASSERT(abs(fist_at[1] - point[1]) <= 1 && abs(fist_at[2] - point[2]) <= 1, "The fist stops short of the [zone] of a body beside its bearer")

	// A body a corner away gets tg's lunge: the arm is thrown the way its bearer faces
	var/mob/living/carbon/human/consistent/cornered = allocate(/mob/living/carbon/human/consistent, spot(4, 3))
	var/cornered_before = cornered.getBruteLoss()
	arm(fresh).piston_hit(fresh, cornered, fresh.get_bodypart(BODY_ZONE_R_ARM), BODY_ZONE_CHEST)
	TEST_ASSERT_NULL(fresh.gorilla_thrust, "A punch at a corner tile threw its arm past the body")
	sleep(0.3 SECONDS)
	TEST_ASSERT(cornered.getBruteLoss() > cornered_before, "A punch at a corner tile never landed")

/**
 * The haymaker's arm: a bearer who stands still winds up on the rig, whose puppets lean with the hidden body; the blow
 * lands when the thrown fist does, and the rig comes down when the arms are back at rest. A step or a turn mid
 * wind-up takes the rig down and the wind-up goes on; a wind-up called off lowers the arms and then the rig.
 */
/datum/unit_test/voidcrew_gorilla_gore/haymaker_swing

/datum/unit_test/voidcrew_gorilla_gore/haymaker_swing/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	bearer.setDir(EAST)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/haymaker = locate() in arm(bearer, BODY_ZONE_R_ARM).actions
	haymaker.Trigger(bearer)
	TEST_ASSERT_NOTNULL(haymaker.rig, "A wind-up standing still raised no rig")
	// Three puppets, plus the body's stand-in that every concealed rig puts up (chrome_rig/conceal())
	TEST_ASSERT_EQUAL(puppets_left(), 4, "The wind-up's rig isn't a body and two arms")
	TEST_ASSERT_EQUAL(length(haymaker.rig.puppets), 3, "The wind-up's rig isn't a body and two arms")
	var/datum/status_effect/gorilla_windup/windup = bearer.has_status_effect(/datum/status_effect/gorilla_windup)
	haymaker.charge_started = world.time - 2 SECONDS
	windup.tick(0.2)
	var/obj/effect/abstract/chrome_puppet/body_puppet = haymaker.rig.puppet("body")
	TEST_ASSERT_EQUAL(body_puppet.pixel_x, bearer.pixel_x, "The puppets didn't lean with the hidden body")
	TEST_ASSERT_EQUAL(body_puppet.pixel_w, bearer.pixel_w, "The puppets didn't tremble with the hidden body")
	var/hurt_before = victim.getBruteLoss()
	haymaker.InterceptClickOn(bearer, null, victim)
	TEST_ASSERT_NOTNULL(haymaker.rig, "The rig came down before the swing")
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), hurt_before, "The haymaker landed before its fist was thrown")
	sleep(0.2 SECONDS)
	TEST_ASSERT(victim.getBruteLoss() - hurt_before >= 20, "The thrown haymaker never landed") // GORILLA_HAYMAKER_MIN_DAMAGE
	TEST_ASSERT_NOTNULL(haymaker.rig, "The rig came down before the follow-through")
	sleep(0.6 SECONDS)
	TEST_ASSERT_NULL(haymaker.rig, "The rig outlived the swing")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "The swing left a puppet behind")
	TEST_ASSERT(!bearer.get_filter("chrome_rig_hide"), "The swing left its bearer hidden") // CHROME_RIG_HIDE_FILTER

	// A step: the lean alone from there, and the wind-up goes on
	var/mob/living/carbon/human/walker = gorilla(spot(0, 2))
	walker.setDir(EAST)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/walking = locate() in arm(walker, BODY_ZONE_R_ARM).actions
	walking.Trigger(walker)
	TEST_ASSERT_NOTNULL(walking.rig, "Test fixture: the second wind-up raised no rig")
	walker.forceMove(spot(0, 3))
	TEST_ASSERT_NULL(walking.rig, "A step left the rig standing where the bearer was")
	TEST_ASSERT(walking.charging(), "A step ended the wind-up")
	TEST_ASSERT_NOTNULL(walker.has_status_effect(/datum/status_effect/gorilla_windup), "A step ended the wind-up's lean")
	walking.unset_click_ability(walker, refund_cooldown = TRUE)

	// A turn does the same
	var/mob/living/carbon/human/turner = gorilla(spot(2, 2))
	turner.setDir(EAST)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/turning = locate() in arm(turner, BODY_ZONE_R_ARM).actions
	turning.Trigger(turner)
	TEST_ASSERT_NOTNULL(turning.rig, "Test fixture: the third wind-up raised no rig")
	turner.setDir(SOUTH)
	TEST_ASSERT_NULL(turning.rig, "A turn left the old facing's puppets up")
	TEST_ASSERT(turning.charging(), "A turn ended the wind-up")
	turning.unset_click_ability(turner, refund_cooldown = TRUE)

	// Called off: the arms come down first, then the rig
	var/mob/living/carbon/human/venter = gorilla(spot(2, 4))
	venter.setDir(EAST)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/vented = locate() in arm(venter, BODY_ZONE_R_ARM).actions
	vented.Trigger(venter)
	TEST_ASSERT_NOTNULL(vented.rig, "Test fixture: the fourth wind-up raised no rig")
	vented.unset_click_ability(venter, refund_cooldown = TRUE)
	TEST_ASSERT(!vented.charging(), "Test fixture: the wind-up wasn't called off")
	TEST_ASSERT_NOTNULL(vented.rig, "A wind-up called off dropped its arms in one frame")
	sleep(0.5 SECONDS)
	TEST_ASSERT_NULL(vented.rig, "The rig outlived a wind-up called off")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "A wind-up called off left a puppet behind")

	// Thrown at a body a corner away: the rig comes down, the lunge is tg's, and the blow still lands
	var/mob/living/carbon/human/cornerer = gorilla(spot(3, 3))
	var/mob/living/carbon/human/consistent/cornered = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	cornerer.setDir(EAST)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/corner_swing = locate() in arm(cornerer, BODY_ZONE_R_ARM).actions
	corner_swing.Trigger(cornerer)
	TEST_ASSERT_NOTNULL(corner_swing.rig, "Test fixture: the fifth wind-up raised no rig")
	corner_swing.charge_started = world.time - 1 SECONDS
	var/cornered_before = cornered.getBruteLoss()
	corner_swing.InterceptClickOn(cornerer, null, cornered)
	TEST_ASSERT_NULL(corner_swing.rig, "A haymaker at a corner tile threw its arm past the body")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "A haymaker at a corner tile left a puppet behind")
	sleep(0.2 SECONDS)
	TEST_ASSERT(cornered.getBruteLoss() - cornered_before >= 20, "A haymaker at a corner tile never landed") // GORILLA_HAYMAKER_MIN_DAMAGE

	// Something in the guard hand: that arm stays down, so the thing isn't pulled apart
	var/mob/living/carbon/human/guarder = gorilla(spot(4, 2))
	guarder.setDir(EAST)
	guarder.put_in_hand(allocate(/obj/item/wrench), 1)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/guarded = locate() in arm(guarder, BODY_ZONE_R_ARM).actions
	guarded.Trigger(guarder)
	TEST_ASSERT_NOTNULL(guarded.rig, "A wind-up with something in the guard hand raised no rig")
	TEST_ASSERT_NOTNULL(guarded.rig.arm_poses["r"], "Test fixture: the punching arm wasn't drawn back")
	TEST_ASSERT_NULL(guarded.rig.arm_poses["l"], "A guard arm with something in its hand was raised")
	guarded.unset_click_ability(guarder, refund_cooldown = TRUE)

	// Something in the punching hand: no drawing, and the wind-up goes on
	var/mob/living/carbon/human/gripper = gorilla(spot(0, 4))
	gripper.setDir(EAST)
	gripper.put_in_hand(allocate(/obj/item/wrench), 2)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/gripped = locate() in arm(gripper, BODY_ZONE_R_ARM).actions
	gripped.Trigger(gripper)
	TEST_ASSERT_NULL(gripped.rig, "A punching arm with something in its hand was drawn on the rig")
	TEST_ASSERT(gripped.charging(), "Something in the punching hand stopped the wind-up")
	gripped.unset_click_ability(gripper, refund_cooldown = TRUE)
	sleep(0.4 SECONDS)
	TEST_ASSERT_EQUAL(puppets_left(), 0, "A wind-up with full hands left a puppet behind")

// =========================================================================
// GROUND POUND
// =========================================================================

/// The synced pair grants the chip; the pound staggers and dazes everyone around but the bearer, does no
/// brute, and loose things hop outward but never into space.
/datum/unit_test/voidcrew_gorilla_gore/ground_pound

/datum/unit_test/voidcrew_gorilla_gore/ground_pound/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(2, 2))
	TEST_ASSERT(gorilla_synced(bearer), "Test fixture: the pair isn't synced")
	var/datum/action/cooldown/cyberware/gorilla_pound/pound = locate() in arm(bearer, BODY_ZONE_R_ARM).actions
	TEST_ASSERT_NOTNULL(pound, "A synced pair has no ground pound")
	TEST_ASSERT_EQUAL(pound.owner, bearer, "The ground pound wasn't granted")

	var/mob/living/carbon/human/consistent/near = allocate(/mob/living/carbon/human/consistent, spot(3, 2))
	var/mob/living/carbon/human/consistent/far = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	// Lava, not space: a space hole would vent the room and the wind would move things itself
	var/turf/hole = spot(0, 2)
	change_turf(hole, /turf/open/lava/smooth)
	var/obj/item/wrench/loose = allocate(/obj/item/wrench, spot(1, 2))
	var/brute_before = near.getBruteLoss()
	var/list/hit = gorilla_ground_pound(bearer, get_turf(bearer))
	TEST_ASSERT(near in hit, "The pound missed someone beside it")
	TEST_ASSERT(!(far in hit), "The pound reached someone two tiles off")
	TEST_ASSERT(!(bearer in hit), "The pound hit its bearer")
	TEST_ASSERT_NOTNULL(near.has_status_effect(/datum/status_effect/staggered), "The pound didn't stagger")
	TEST_ASSERT_EQUAL(near.getBruteLoss(), brute_before, "The pound did brute")
	var/hopped_to = loose.loc
	restore_turf(hole)
	TEST_ASSERT_NOTEQUAL(hopped_to, hole, "The pound hopped a loose thing into lava")

	// Out of sync: the chip goes
	var/obj/item/organ/left = arm(bearer, BODY_ZONE_L_ARM)
	left.Remove(bearer, special = TRUE)
	sleep(0.1 SECONDS)
	TEST_ASSERT(QDELETED(pound) || pound.owner != bearer, "The ground pound outlived the pair")

// =========================================================================
// DOOR PRY
// =========================================================================

/// A trader outpost's airlock never gives to the Gorilla.
/datum/unit_test/voidcrew_gorilla_gore/pry_outpost

/datum/unit_test/voidcrew_gorilla_gore/pry_outpost/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	bearer.set_combat_mode(FALSE)
	var/obj/machinery/door/airlock/outpost/door = allocate(/obj/machinery/door/airlock/outpost, spot(1, 0))
	TEST_ASSERT(gorilla_pry_refused(door), "An outpost airlock isn't refused")
	var/result = SEND_SIGNAL(bearer, COMSIG_LIVING_UNARMED_ATTACK, door, TRUE, list())
	TEST_ASSERT(result & COMPONENT_CANCEL_ATTACK_CHAIN, "The pry didn't take the outpost door click")
	sleep(0.5 SECONDS)
	TEST_ASSERT(door.density, "The Gorilla pried an outpost airlock")
	var/obj/machinery/door/airlock/plain = allocate(/obj/machinery/door/airlock, spot(0, 1))
	TEST_ASSERT(!gorilla_pry_refused(plain), "A plain airlock is refused")

// =========================================================================
// BRAWLER MYOMERS (owner D49): the street slam, the light pound, the rip, doors
// =========================================================================

/// The synced Brawler pair's pound staggers and winds those beside it, never dazes them and moves nothing.
/datum/unit_test/voidcrew_gorilla_gore/brawler_pound

/datum/unit_test/voidcrew_gorilla_gore/brawler_pound/Run()
	var/mob/living/carbon/human/brawler = gorilla(spot(2, 2), street = TRUE)
	TEST_ASSERT(brawler_synced(brawler), "Test fixture: the Brawler pair isn't synced")
	TEST_ASSERT(!gorilla_synced(brawler), "A Brawler pair synced as Gorilla Arms")
	var/datum/action/cooldown/cyberware/gorilla_pound/brawler/pound = locate() in arm(brawler, BODY_ZONE_R_ARM).actions
	TEST_ASSERT_NOTNULL(pound, "A synced Brawler pair has no ground pound")
	TEST_ASSERT_EQUAL(pound.owner, brawler, "The Brawler ground pound wasn't granted")
	TEST_ASSERT_EQUAL(pound.cooldown_time, 60 SECONDS, "The Brawler pound isn't on a minute's clock") // BRAWLER_POUND_COOLDOWN
	TEST_ASSERT(!pound.daze, "The Brawler pound dazes")

	var/mob/living/carbon/human/consistent/near = allocate(/mob/living/carbon/human/consistent, spot(3, 2))
	var/obj/item/wrench/loose = allocate(/obj/item/wrench, spot(1, 2))
	var/brute_before = near.getBruteLoss()
	var/stamina_before = near.getStaminaLoss()
	var/list/hit = gorilla_ground_pound(brawler, get_turf(brawler), pound.stagger, pound.daze, pound.stamina, pound.full_pound)
	TEST_ASSERT(near in hit, "The Brawler pound missed someone beside it")
	var/datum/status_effect/staggered/stagger = near.has_status_effect(/datum/status_effect/staggered)
	TEST_ASSERT_NOTNULL(stagger, "The Brawler pound didn't stagger")
	TEST_ASSERT(stagger.duration - world.time <= 6 SECONDS, "The Brawler pound staggered past six seconds") // BRAWLER_POUND_STAGGER
	TEST_ASSERT_NULL(near.has_status_effect(/datum/status_effect/dazed), "The Brawler pound dazed someone")
	var/winded = near.getStaminaLoss() - stamina_before
	TEST_ASSERT(winded > 5 && winded <= 10, "The Brawler pound took [winded] stamina, not 10") // BRAWLER_POUND_STAMINA
	TEST_ASSERT_EQUAL(near.getBruteLoss(), brute_before, "The Brawler pound did brute")
	TEST_ASSERT_EQUAL(loose.loc, spot(1, 2), "The Brawler pound moved a loose thing")

	// Through the chip, on its own clock
	var/mob/living/carbon/human/pounder = gorilla(spot(0, 4), street = TRUE)
	TEST_ASSERT(gorilla_try_pound(pounder), "The Brawler pound couldn't be started without the chip")
	TEST_ASSERT(S_TIMER_COOLDOWN_TIMELEFT(pounder, "gorilla_pound") > 45 SECONDS, "The Brawler pound ran on the Gorilla's clock") // COOLDOWN_GORILLA_POUND

	// A mixed pair has no pound at all
	var/mob/living/carbon/human/consistent/mixed = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	var/obj/item/organ/real = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms)
	var/obj/item/organ/street = allocate(/obj/item/organ/cyberimp/cyberware/gorilla_arms/street/left)
	TEST_ASSERT(real.Insert(mixed, special = TRUE), "Test fixture: the real arm wouldn't go in")
	TEST_ASSERT(street.Insert(mixed, special = TRUE), "Test fixture: the Brawler arm wouldn't go in")
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/cyberware/gorilla_pound) in real.actions, "A mixed pair got a ground pound")
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/cyberware/gorilla_pound) in street.actions, "A mixed pair got a Brawler pound")

	// Out of sync: the chip goes
	var/obj/item/organ/left = arm(brawler, BODY_ZONE_L_ARM)
	left.Remove(brawler, special = TRUE)
	sleep(0.1 SECONDS)
	TEST_ASSERT(QDELETED(pound) || pound.owner != brawler, "The Brawler pound outlived the pair")

/// Brawler punches dent plain and reinforced airlocks, less than the Gorilla's; the synced pair forces a
/// powered one slower than the Gorilla; a trader outpost's door takes neither.
/datum/unit_test/voidcrew_gorilla_gore/brawler_doors

/datum/unit_test/voidcrew_gorilla_gore/brawler_doors/Run()
	var/mob/living/carbon/human/brawler = gorilla(spot(0, 0), street = TRUE)
	var/obj/machinery/door/airlock/plain = allocate(/obj/machinery/door/airlock, spot(1, 0))
	var/plain_before = plain.get_integrity()
	TEST_ASSERT_EQUAL(punch(brawler, plain), COMPONENT_CANCEL_ATTACK_CHAIN, "A Brawler punch at an airlock wasn't a smash")
	var/brawler_dent = plain_before - plain.get_integrity()
	TEST_ASSERT(brawler_dent > 0, "A Brawler punch didn't dent a plain airlock")

	var/obj/machinery/door/airlock/reinforced = allocate(/obj/machinery/door/airlock, spot(0, 1))
	reinforced.damage_deflection = 30 // AIRLOCK_DAMAGE_DEFLECTION_R
	var/reinforced_before = reinforced.get_integrity()
	punch(brawler, reinforced)
	TEST_ASSERT(reinforced.get_integrity() < reinforced_before, "A Brawler punch didn't dent a reinforced airlock")

	var/mob/living/carbon/human/real = gorilla(spot(3, 0))
	var/obj/machinery/door/airlock/real_door = allocate(/obj/machinery/door/airlock, spot(4, 0))
	var/real_before = real_door.get_integrity()
	punch(real, real_door)
	TEST_ASSERT(real_before - real_door.get_integrity() > brawler_dent, "A Brawler punch dents an airlock as deep as a Gorilla's")

	// Forcing a powered airlock that won't open for them: slower than the Gorilla's four seconds
	brawler.set_combat_mode(FALSE)
	var/obj/machinery/door/airlock/shut = allocate(/obj/machinery/door/airlock, spot(1, 1))
	shut.req_access = list(ACCESS_CAPTAIN)
	TEST_ASSERT(shut.hasPower(), "Test fixture: the test room airlock has no power")
	TEST_ASSERT(!shut.allowed(brawler), "Test fixture: the airlock opens for the Brawler anyway")
	var/forced = SEND_SIGNAL(brawler, COMSIG_LIVING_UNARMED_ATTACK, shut, TRUE, list())
	TEST_ASSERT(forced & COMPONENT_CANCEL_ATTACK_CHAIN, "The Brawler pair didn't take the airlock click")
	sleep(4.5 SECONDS)
	TEST_ASSERT(shut.density, "The Brawler pair forced an airlock as fast as the Gorilla") // GORILLA_PRY_TIME
	// 7 s of prying, then the airlock's own opening before it stops blocking
	sleep(4 SECONDS)
	TEST_ASSERT(!shut.density, "The Brawler pair never forced the airlock") // BRAWLER_PRY_TIME 7 s

	// An arm that's down forces nothing: the click is an ordinary one
	var/obj/machinery/door/airlock/second_shut = allocate(/obj/machinery/door/airlock, spot(1, 2))
	second_shut.req_access = list(ACCESS_CAPTAIN)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/down_arm = arm(brawler, BODY_ZONE_L_ARM)
	down_arm.organ_flags |= ORGAN_FAILING
	var/weak = SEND_SIGNAL(brawler, COMSIG_LIVING_UNARMED_ATTACK, second_shut, TRUE, list())
	TEST_ASSERT(!(weak & COMPONENT_CANCEL_ATTACK_CHAIN), "A Brawler pair with an arm down started forcing an airlock")
	down_arm.organ_flags &= ~ORGAN_FAILING

	// A trader outpost's airlock takes no punch and no pry
	var/obj/machinery/door/airlock/outpost/outpost_door = allocate(/obj/machinery/door/airlock/outpost, spot(0, 2))
	var/outpost_before = outpost_door.get_integrity()
	brawler.set_combat_mode(TRUE)
	TEST_ASSERT_EQUAL(punch(brawler, outpost_door), COMPONENT_CANCEL_ATTACK_CHAIN, "A Brawler punch at an outpost airlock went through to the door")
	TEST_ASSERT_EQUAL(outpost_door.get_integrity(), outpost_before, "A Brawler punch dented an outpost airlock")
	brawler.set_combat_mode(FALSE)
	var/refused = SEND_SIGNAL(brawler, COMSIG_LIVING_UNARMED_ATTACK, outpost_door, TRUE, list())
	TEST_ASSERT(refused & COMPONENT_CANCEL_ATTACK_CHAIN, "The Brawler pry didn't take the outpost door click")
	sleep(0.5 SECONDS)
	TEST_ASSERT(outpost_door.density, "The Brawler pair pried an outpost airlock")
