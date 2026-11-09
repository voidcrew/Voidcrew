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

/// Runs a finisher to its end through advance(), as its timer would.
/datum/unit_test/voidcrew_gorilla_gore/proc/run_to_end(datum/hv_finisher/finisher)
	for(var/i in 1 to 20)
		if(!finisher.running)
			return
		finisher.advance()

/// Every chrome puppet left anywhere in the test room
/datum/unit_test/voidcrew_gorilla_gore/proc/puppets_left()
	. = 0
	for(var/turf/floor in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		for(var/obj/effect/abstract/chrome_puppet/puppet in floor)
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
	TEST_ASSERT(!TIMER_COOLDOWN_FINISHED(bearer, "gorilla_grab_move"), "A hurl didn't start the grab-move cooldown") // COOLDOWN_GORILLA_GRAB_MOVE
	sleep(1 SECONDS)
	TEST_ASSERT_NOTEQUAL(victim.loc, spot(1, 0), "A grabbed body wasn't hurled")
	// Grab them again: no second hurl inside the cooldown
	victim.forceMove(spot(1, 0))
	victim.SetAllImmobility(0)
	victim.grabbedby(bearer, supress_message = TRUE)
	victim.grabbedby(bearer, supress_message = TRUE)
	punch(bearer, victim)
	sleep(0.5 SECONDS)
	TEST_ASSERT_EQUAL(victim.loc, spot(1, 0), "A grabbed body was hurled twice inside the cooldown")

/// A click on the floor under a held body slams them into it; a table click slams them onto the table
/// instead of caving the table in.
/datum/unit_test/voidcrew_gorilla_gore/slam

/datum/unit_test/voidcrew_gorilla_gore/slam/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	victim.grabbedby(bearer, supress_message = TRUE)
	victim.grabbedby(bearer, supress_message = TRUE)
	var/hurt_before = victim.getBruteLoss()
	TEST_ASSERT_EQUAL(punch(bearer, spot(1, 0)), COMPONENT_CANCEL_ATTACK_CHAIN, "A floor click while grabbing wasn't a slam")
	TEST_ASSERT_NULL(bearer.pulling, "The slam kept the grab")
	sleep(0.5 SECONDS)
	TEST_ASSERT(victim.getBruteLoss() > hurt_before, "The floor slam did no damage")
	TEST_ASSERT(victim.body_position == LYING_DOWN, "The floor slam didn't knock them down")

	// The table
	var/mob/living/carbon/human/table_bearer = gorilla(spot(0, 3))
	var/mob/living/carbon/human/consistent/table_victim = allocate(/mob/living/carbon/human/consistent, spot(1, 3))
	var/obj/structure/table/table = allocate(/obj/structure/table, spot(1, 4))
	var/table_before = table.get_integrity()
	table_victim.grabbedby(table_bearer, supress_message = TRUE)
	table_victim.grabbedby(table_bearer, supress_message = TRUE)
	TEST_ASSERT_EQUAL(punch(table_bearer, table), COMPONENT_CANCEL_ATTACK_CHAIN, "A table click while grabbing wasn't a slam")
	TEST_ASSERT_EQUAL(table_victim.loc, spot(1, 4), "The slam didn't put them on the table")
	sleep(0.5 SECONDS)
	TEST_ASSERT(QDELETED(table) || table.get_integrity() <= table_before - 50, "The table didn't take the slam") // GORILLA_SLAM_TABLE_BREAK

	// A Brawler never slams
	var/mob/living/carbon/human/brawler = gorilla(spot(3, 0), street = TRUE)
	var/mob/living/carbon/human/consistent/held = allocate(/mob/living/carbon/human/consistent, spot(4, 0))
	held.grabbedby(brawler, supress_message = TRUE)
	held.grabbedby(brawler, supress_message = TRUE)
	TEST_ASSERT_NOTEQUAL(punch(brawler, spot(4, 0)), COMPONENT_CANCEL_ATTACK_CHAIN, "Brawler myomers slammed someone")

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
	right_haymaker.charge_started = world.time - 2 SECONDS
	var/hurt_before = victim.getBruteLoss()
	right_haymaker.InterceptClickOn(bearer, null, victim)
	TEST_ASSERT(!right_haymaker.charging(), "The haymaker still winds up after the release")
	TEST_ASSERT_NULL(bearer.has_status_effect(/datum/status_effect/gorilla_windup), "The wind-up outlived the release")
	TEST_ASSERT(!bearer.has_movespeed_modifier(/datum/movespeed_modifier/gorilla_windup), "The wind-up's slow outlived it")
	TEST_ASSERT(!bearer.has_offset("gorilla_windup"), "The wind-up's lean outlived it")
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
// FINISHERS (owner D39)
// =========================================================================

/// Never on someone just lying there; never from Brawler myomers or with something in hand.
/datum/unit_test/voidcrew_gorilla_gore/finisher_gates

/datum/unit_test/voidcrew_gorilla_gore/finisher_gates/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	bearer.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/resting = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	resting.set_resting(TRUE, instant = TRUE)
	TEST_ASSERT(!gorilla_try_finisher(bearer, resting), "A finisher started on someone just lying down")

	var/mob/living/carbon/human/consistent/stunned = downed(spot(0, 1))
	var/obj/item/wrench/tool = allocate(/obj/item/wrench)
	bearer.put_in_hands(tool)
	TEST_ASSERT(!gorilla_try_finisher(bearer, stunned), "A finisher started with something in hand")
	qdel(tool)

	var/mob/living/carbon/human/brawler = gorilla(spot(3, 3), street = TRUE)
	brawler.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/brawler_victim = downed(spot(4, 3))
	TEST_ASSERT(!gorilla_try_finisher(brawler, brawler_victim), "Brawler myomers started a finisher")

	// The pistons' cooldown blocks it
	gorilla_cooldown(bearer, "gorilla_pistons", 20 SECONDS) // COOLDOWN_GORILLA_PISTONS
	TEST_ASSERT(!gorilla_try_finisher(bearer, stunned), "A finisher started while the pistons were spent")

/// The head clap bursts the head, the brain survives, the rig comes down and the pistons are spent.
/datum/unit_test/voidcrew_gorilla_gore/finisher_clap

/datum/unit_test/voidcrew_gorilla_gore/finisher_clap/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(1, 1))
	bearer.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/victim = downed(spot(2, 1))
	TEST_ASSERT(gorilla_try_finisher(bearer, victim), "The head clap didn't start on someone stunned")
	var/datum/hv_finisher/chrome/gorilla/clap/finisher = bearer.chrome_finisher
	TEST_ASSERT(istype(finisher), "A head aim didn't pick the head clap")
	TEST_ASSERT(puppets_left() > 0, "The head clap put up no rig")
	TEST_ASSERT_NULL(locate(/obj/effect/temp_visual/telegraphing/hv_finisher_mark) in get_turf(victim), "A chrome finisher marked its victim")
	run_to_end(finisher)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_HEAD), "The head clap didn't burst the head")
	var/obj/item/organ/brain/brain
	for(var/turf/floor in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		brain ||= locate(/obj/item/organ/brain) in floor
	TEST_ASSERT_NOTNULL(brain, "The burst head lost its brain")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "The head clap left puppets behind")
	TEST_ASSERT_NULL(bearer.get_filter("chrome_rig_hide"), "The bearer stayed hidden")
	TEST_ASSERT_NULL(victim.get_filter("chrome_rig_hide"), "The victim stayed hidden")
	TEST_ASSERT_NOTEQUAL(bearer.mouse_opacity, MOUSE_OPACITY_OPAQUE, "The bearer kept the hidden click area")
	var/left = S_TIMER_COOLDOWN_TIMELEFT(bearer, "gorilla_pistons")
	TEST_ASSERT(left > 10 SECONDS, "A finished clap didn't spend the pistons for long ([left])")
	TEST_ASSERT_NULL(bearer.chrome_finisher, "The finished clap is still on the bearer")
	TEST_ASSERT(QDELETED(finisher), "A finished clap outlived its end and kept hold of both bodies")

/// A helmet crumples instead and the skull caves in; the Atlas frame holds.
/datum/unit_test/voidcrew_gorilla_gore/finisher_clap_armour

/datum/unit_test/voidcrew_gorilla_gore/finisher_clap_armour/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(1, 1))
	bearer.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/helmeted = downed(spot(2, 1))
	helmeted.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/swat(helmeted), ITEM_SLOT_HEAD)
	var/datum/hv_finisher/chrome/gorilla/clap/finisher = new(bearer, helmeted)
	TEST_ASSERT(finisher.start(), "Test fixture: the clap wouldn't start on a helmet")
	run_to_end(finisher)
	TEST_ASSERT_NOTNULL(helmeted.get_bodypart(BODY_ZONE_HEAD), "A helmet didn't stop the burst")
	TEST_ASSERT_NOTNULL(helmeted.get_bodypart(BODY_ZONE_HEAD).get_wound_type(/datum/wound/blunt/bone/critical/hv_skull), "The skull didn't cave in under the helmet")
	qdel(finisher)

	var/mob/living/carbon/human/second = gorilla(spot(1, 3))
	second.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/framed = downed(spot(2, 3))
	var/obj/item/organ/atlas = allocate(/obj/item/organ/cyberimp/cyberware/atlas)
	TEST_ASSERT(atlas.Insert(framed, special = TRUE), "Test fixture: the Atlas frame wouldn't go in")
	var/datum/hv_finisher/chrome/gorilla/clap/frame_finisher = new(second, framed)
	TEST_ASSERT(frame_finisher.start(), "Test fixture: the clap wouldn't start on the Atlas frame")
	run_to_end(frame_finisher)
	TEST_ASSERT_NOTNULL(framed.get_bodypart(BODY_ZONE_HEAD), "The Atlas frame's head burst")
	qdel(frame_finisher)

/// The limb rip tears the aimed arm off and leaves it on the victim's tile.
/datum/unit_test/voidcrew_gorilla_gore/finisher_rip

/datum/unit_test/voidcrew_gorilla_gore/finisher_rip/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(1, 1))
	bearer.zone_selected = BODY_ZONE_L_ARM
	var/mob/living/carbon/human/consistent/victim = downed(spot(2, 1))
	TEST_ASSERT(gorilla_try_finisher(bearer, victim), "The limb rip didn't start")
	var/datum/hv_finisher/chrome/gorilla/rip/finisher = bearer.chrome_finisher
	TEST_ASSERT(istype(finisher), "An arm aim didn't pick the limb rip")
	run_to_end(finisher)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_L_ARM), "The aimed arm wasn't torn off")
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_R_ARM), "The wrong arm was torn off")
	var/obj/item/bodypart/arm/left/torn = locate() in get_turf(victim)
	TEST_ASSERT_NOTNULL(torn, "The torn arm wasn't left on the victim's tile")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "The limb rip left puppets behind")

	// Armour on the arm: the shoulder comes out instead
	var/mob/living/carbon/human/second = gorilla(spot(1, 3))
	second.zone_selected = BODY_ZONE_R_ARM
	var/mob/living/carbon/human/consistent/armoured = downed(spot(2, 3))
	armoured.physiology.armor = armoured.physiology.armor.generate_new_with_modifiers(list(MELEE = 60))
	var/datum/hv_finisher/chrome/gorilla/rip/armoured_rip = new(second, armoured)
	armoured_rip.aimed_zone = BODY_ZONE_R_ARM
	TEST_ASSERT(armoured_rip.start(), "Test fixture: the rip wouldn't start on armour")
	run_to_end(armoured_rip)
	TEST_ASSERT_NOTNULL(armoured.get_bodypart(BODY_ZONE_R_ARM), "An armoured arm was torn off")
	TEST_ASSERT_NOTNULL(armoured.get_bodypart(BODY_ZONE_R_ARM).get_wound_type(/datum/wound/blunt/bone/moderate), "An armoured arm didn't dislocate")
	qdel(armoured_rip)

/// The backbreaker breaks the back (they can't stand), and the fold comes off when the body is moved.
/datum/unit_test/voidcrew_gorilla_gore/finisher_backbreaker

/datum/unit_test/voidcrew_gorilla_gore/finisher_backbreaker/Run()
	var/mob/living/carbon/human/bearer = gorilla(spot(1, 1))
	bearer.zone_selected = BODY_ZONE_CHEST
	var/mob/living/carbon/human/consistent/victim = downed(spot(2, 1))
	TEST_ASSERT(gorilla_try_finisher(bearer, victim), "The backbreaker didn't start")
	var/datum/hv_finisher/chrome/gorilla/backbreaker/finisher = bearer.chrome_finisher
	TEST_ASSERT(istype(finisher), "A chest aim didn't pick the backbreaker")
	run_to_end(finisher)
	var/obj/item/bodypart/chest = victim.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/spine = chest.get_wound_type(/datum/wound/blunt/bone/critical/gorilla_spine)
	TEST_ASSERT_NOTNULL(spine, "The back didn't break")
	TEST_ASSERT(HAS_TRAIT_FROM(victim, TRAIT_FLOORED, REF(spine)), "A broken back can still stand")
	TEST_ASSERT_EQUAL(victim.loc, spot(1, 1), "The body didn't come down off the knee where it broke")
	TEST_ASSERT_NOTNULL(victim.GetComponent(/datum/component/gorilla_fold), "The broken back isn't drawn bent")
	TEST_ASSERT_NOTNULL(victim.get_filter("chrome_rig_hide"), "The bent body isn't the one shown")
	victim.forceMove(spot(3, 3))
	TEST_ASSERT_NULL(victim.GetComponent(/datum/component/gorilla_fold), "The fold stayed on a moved body")
	TEST_ASSERT_NULL(victim.get_filter("chrome_rig_hide"), "A moved body stayed hidden")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "The fold left puppets behind")
	var/spine_ref = REF(spine)
	spine.remove_wound()
	TEST_ASSERT(!HAS_TRAIT_FROM(victim, TRAIT_FLOORED, spine_ref), "A set back still can't stand")

/// Damage on the bearer, the bearer moving, or the victim coming out of the stun stops it, with the
/// shorter cooldown, and nothing is left hidden or posed.
/datum/unit_test/voidcrew_gorilla_gore/finisher_interrupts

/datum/unit_test/voidcrew_gorilla_gore/finisher_interrupts/Run()
	// Hit hard enough: lets go
	var/mob/living/carbon/human/bearer = gorilla(spot(1, 1))
	bearer.zone_selected = BODY_ZONE_CHEST
	var/mob/living/carbon/human/consistent/victim = downed(spot(2, 1))
	TEST_ASSERT(gorilla_try_finisher(bearer, victim), "Test fixture: no finisher")
	var/datum/hv_finisher/chrome/gorilla/finisher = bearer.chrome_finisher
	finisher.advance()
	bearer.apply_damage(15, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(!finisher.running, "Damage on the bearer didn't stop the finisher")
	TEST_ASSERT(QDELETED(finisher), "A stopped finisher outlived its end")
	TEST_ASSERT_EQUAL(finisher.result, 3, "Damage stopped it for the wrong reason") // HV_FINISHER_DAMAGED
	TEST_ASSERT_EQUAL(puppets_left(), 0, "A stopped finisher left puppets")
	TEST_ASSERT_NULL(victim.get_filter("chrome_rig_hide"), "A stopped finisher left the victim hidden")
	TEST_ASSERT_NULL(bearer.get_filter("chrome_rig_hide"), "A stopped finisher left the bearer hidden")
	var/left = S_TIMER_COOLDOWN_TIMELEFT(bearer, "gorilla_pistons")
	TEST_ASSERT(left > 0 && left <= 10 SECONDS, "A stopped finisher cost the wrong cooldown ([left])") // GORILLA_PISTONS_INTERRUPTED
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_CHEST), "Test fixture: no chest")
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_CHEST).get_wound_type(/datum/wound/blunt/bone/critical/gorilla_spine), "A stopped backbreaker still broke the back")

	// The bearer steps away: lets go
	var/mob/living/carbon/human/walker = gorilla(spot(1, 3))
	walker.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/walk_victim = downed(spot(2, 3))
	TEST_ASSERT(gorilla_try_finisher(walker, walk_victim), "Test fixture: no second finisher")
	var/datum/hv_finisher/chrome/gorilla/walk_finisher = walker.chrome_finisher
	walker.forceMove(spot(0, 3))
	TEST_ASSERT(!walk_finisher.running, "The bearer walked off mid-finisher")
	TEST_ASSERT_NOTNULL(walk_victim.get_bodypart(BODY_ZONE_HEAD), "A walked-off clap still burst the head")

	// The victim comes out of the stun before the kill: twists free
	var/mob/living/carbon/human/third = gorilla(spot(3, 0))
	third.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/waking = downed(spot(4, 0))
	TEST_ASSERT(gorilla_try_finisher(third, waking), "Test fixture: no third finisher")
	var/datum/hv_finisher/chrome/gorilla/wake_finisher = third.chrome_finisher
	waking.SetAllImmobility(0)
	wake_finisher.tick()
	TEST_ASSERT(!wake_finisher.running, "A victim out of the stun didn't twist free")
	TEST_ASSERT_NOTNULL(waking.get_bodypart(BODY_ZONE_HEAD), "A victim who twisted free lost the head")
	TEST_ASSERT_EQUAL(puppets_left(), 0, "Twisting free left puppets")

/// Each new move can be started without a mouse or an aimed zone, for an AI later.
/datum/unit_test/voidcrew_gorilla_gore/ai_entry_points

/datum/unit_test/voidcrew_gorilla_gore/ai_entry_points/Run()
	// The haymaker: the same wind-up, then the hit
	var/mob/living/carbon/human/bearer = gorilla(spot(0, 0))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/hurt_before = victim.getBruteLoss()
	TEST_ASSERT(gorilla_try_haymaker(bearer, victim, 0.8 SECONDS), "The haymaker couldn't be started without a click")
	TEST_ASSERT_NOTNULL(bearer.has_status_effect(/datum/status_effect/gorilla_windup), "An AI haymaker skipped the wind-up")
	sleep(1.5 SECONDS)
	TEST_ASSERT(victim.getBruteLoss() > hurt_before, "An AI haymaker never landed")
	TEST_ASSERT(!TIMER_COOLDOWN_FINISHED(bearer, "gorilla_pistons"), "An AI haymaker didn't spend the pistons") // COOLDOWN_GORILLA_PISTONS

	// The ground pound
	var/mob/living/carbon/human/pounder = gorilla(spot(2, 4))
	TEST_ASSERT(gorilla_try_pound(pounder), "The ground pound couldn't be started without the chip")
	TEST_ASSERT(!TIMER_COOLDOWN_FINISHED(pounder, "gorilla_pound"), "An AI pound didn't start its cooldown") // COOLDOWN_GORILLA_POUND

	// A finisher by zone, whatever the bearer aims at
	var/mob/living/carbon/human/finisher_bearer = gorilla(spot(0, 2))
	finisher_bearer.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/downed_victim = downed(spot(1, 2))
	TEST_ASSERT(gorilla_try_finisher(finisher_bearer, downed_victim, BODY_ZONE_CHEST), "A finisher couldn't be started by zone")
	TEST_ASSERT(istype(finisher_bearer.chrome_finisher, /datum/hv_finisher/chrome/gorilla/backbreaker), "The zone given didn't pick the finisher")
	run_to_end(finisher_bearer.chrome_finisher)

	// The slam
	var/mob/living/carbon/human/slammer = gorilla(spot(3, 0))
	var/mob/living/carbon/human/consistent/held = allocate(/mob/living/carbon/human/consistent, spot(4, 0))
	held.grabbedby(slammer, supress_message = TRUE)
	held.grabbedby(slammer, supress_message = TRUE)
	slammer.swap_hand(2, silent = TRUE)
	TEST_ASSERT(gorilla_try_slam(slammer, get_turf(held)), "The slam couldn't be started without a click")
