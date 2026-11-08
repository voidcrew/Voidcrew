/**
 * Bounty hunting: the mini-bosses' reach, cover, Gorilla Arms smash, longer tells and the whole hunting
 * crew at the site, for voidcrew/modules/bounties/bounty_boss.dm and bounty_boss_kits.dm (port package
 * C5 of PR #507 onto the human bosses).
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming the
 * define. Every test calls the boss's procs, or one planning subtree, directly with the mob in place and
 * its AI off; none waits on a timer or an AI walk.
 */

/// Shared helpers for these tests; not a test itself
/datum/unit_test/voidcrew_bounty_boss/reach
	abstract_type = /datum/unit_test/voidcrew_bounty_boss/reach
	/// Turfs a test changed -> the type each had first, put back when it ends (outside the room they are space)
	var/list/reach_turfs = list()

/datum/unit_test/voidcrew_bounty_boss/reach/Destroy()
	for(var/turf/changed as anything in reach_turfs)
		changed.ChangeTurf(reach_turfs[changed])
	reach_turfs = null
	return ..()

// Remembers what the turf was, not plain floor: outside the test room it is space
/datum/unit_test/voidcrew_bounty_boss/reach/change_turf(turf/where, new_type)
	if(isnull(reach_turfs[where]))
		reach_turfs[where] = where.type
	return where.ChangeTurf(new_type)

/// The tile `dx`, `dy` from the test room's bottom-left corner, outside the room too (space on the test level until a test floors it)
/datum/unit_test/voidcrew_bounty_boss/reach/proc/outside(dx, dy)
	return locate(clamp(run_loc_floor_bottom_left.x + dx, 1, world.maxx), clamp(run_loc_floor_bottom_left.y + dy, 1, world.maxy), run_loc_floor_bottom_left.z)

/// Floors the rectangle `dx`..`dx2`, `dy`..`dy2` from the room's corner (outside the room), to be put back when the test ends
/datum/unit_test/voidcrew_bounty_boss/reach/proc/floor_area(dx, dy, dx2, dy2)
	for(var/x_offset in dx to dx2)
		for(var/y_offset in dy to dy2)
			change_turf(outside(x_offset, y_offset), /turf/open/floor/iron)

/// Whether `controller`'s last plan has `behavior_type` among its planned behaviours
/datum/unit_test/voidcrew_bounty_boss/reach/proc/planned(datum/ai_controller/controller, behavior_type)
	return !!controller.planned_behaviors[GET_AI_BEHAVIOR(behavior_type)]

/// Runs `boss`'s planning subtree of `subtree_type` once, as a planning pass would, and returns what it returned
/datum/unit_test/voidcrew_bounty_boss/reach/proc/plan_with(mob/living/carbon/human/npc/bounty_criminal/boss/boss, subtree_type)
	var/datum/ai_controller/controller = boss.ai_controller
	var/datum/ai_planning_subtree/subtree = locate(subtree_type) in controller.planning_subtrees
	TEST_ASSERT_NOTNULL(subtree, "[boss.type] doesn't plan with [subtree_type]")
	controller.planned_behaviors.Cut()
	return subtree.SelectBehaviors(controller, 1)

/// A boss of `boss_type` at `where` with its AI off, so it stays where the test puts it
/datum/unit_test/voidcrew_bounty_boss/reach/proc/boss_at(boss_type, turf/where)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = allocate(boss_type, where)
	boss.ai_controller?.set_ai_status(AI_STATUS_OFF)
	return boss

/// A Juggernaut at `where` with a real pair of Gorilla Arms put in, the way an NPC gets its chrome (npc_install_cyberware())
/datum/unit_test/voidcrew_bounty_boss/reach/proc/gorilla_boss(turf/where)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut/boss = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut, where)
	TEST_ASSERT_NOTNULL(boss.npc_install_cyberware(/obj/item/organ/cyberimp/cyberware/gorilla_arms), "The right Gorilla Arm didn't go in")
	TEST_ASSERT_NOTNULL(boss.npc_install_cyberware(/obj/item/organ/cyberimp/cyberware/gorilla_arms/left), "The left Gorilla Arm didn't go in")
	TEST_ASSERT_EQUAL(length(boss.boss_gorilla_arms()), 2, "The boss's Gorilla Arms aren't both working")
	return boss

/// Every arm's own punch cooldown over, and its body ready to click
/datum/unit_test/voidcrew_bounty_boss/reach/proc/ready_fists(mob/living/carbon/human/npc/bounty_criminal/boss/boss)
	ready_hands(boss)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in boss.organs)
		arm.slam_cooldown = 0

// ===== LONGER TELLS AND COVER LINES (review r2) =====

/datum/unit_test/voidcrew_bounty_boss/reach/tells

/datum/unit_test/voidcrew_bounty_boss/reach/tells/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/boss/ghost/ghost = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/ghost, spot(0, 0))
	var/datum/action/cooldown/mob_cooldown/bounty_boss/dash/dash = ability_of(ghost, /datum/action/cooldown/mob_cooldown/bounty_boss/dash)
	TEST_ASSERT(abs(dash.windup - 6) < 0.01, "The Ghost's dash tell is [dash.windup / 10] s") // BOUNTY_GHOST_DASH_WINDUP 0.6 s
	var/mob/living/carbon/human/npc/bounty_criminal/boss/pyromaniac/pyro = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/pyromaniac, spot(2, 0))
	var/datum/action/cooldown/mob_cooldown/bounty_boss/flamer/flamer = ability_of(pyro, /datum/action/cooldown/mob_cooldown/bounty_boss/flamer)
	TEST_ASSERT(abs(flamer.windup - 8) < 0.01, "The flamer's tell is [flamer.windup / 10] s") // BOUNTY_PYROMANIAC_FLAMER_WINDUP 0.8 s
	var/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut/juggernaut = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut, spot(4, 0))
	var/datum/action/cooldown/mob_cooldown/bounty_boss/slam/slam = ability_of(juggernaut, /datum/action/cooldown/mob_cooldown/bounty_boss/slam)
	TEST_ASSERT(abs(slam.windup - 8) < 0.01, "The slam's tell is [slam.windup / 10] s") // BOUNTY_JUGGERNAUT_SLAM_WINDUP 0.8 s

	// Every kit has its own lines for breaking cover (boss_bark("cover")), as many as any other context
	var/list/lines = bounty_identity_strings("lines")
	for(var/kit in list("juggernaut", "pyromaniac", "demolitionist", "ghost", "heavy")) // BOUNTY_KIT_*
		TEST_ASSERT(length(lines["[kit]_cover"]?["any"]) >= 6, "The [kit] has fewer than 6 lines for taking cover")

// ===== THE WHOLE HUNTING CREW AT ITS SITE OWES COMPANIONS (review r1, r2; OC-8) =====

/**
 * Turning hostile, it counts every crew member of a ship hunting it who is playing and at its site,
 * seen or not: on the site, on its dock strip. One hunter can't wake it alone while the crew waits by
 * the ship. Crew elsewhere on its level (another site in the same lattice), SSD crew, and strangers
 * don't count. Each one beyond the first owes it a companion; nothing changes its health.
 */
/datum/unit_test/voidcrew_bounty_boss/reach/crews
	/// The test crew, let go of its minds before it goes
	var/datum/team/voidcrew/crew

/datum/unit_test/voidcrew_bounty_boss/reach/crews/Run()
	board_test_begin()
	var/datum/criminal_bounty/posting = board_test_posting(3, null, 3400, 2, "boss")
	posting.record.kit = "juggernaut" // BOUNTY_KIT_JUGGERNAUT
	var/obj/structure/overmap/ship/ship = board_test_ship()
	crew = new
	crew.ship = ship
	ship.ship_team = crew
	var/mob/living/carbon/human/consistent/tagger = hunter_at(spot(2, 0))
	// Out of its sight past the room's walls, but on its site
	var/mob/living/carbon/human/consistent/on_site = hunter_at(outside(0, 20))
	// On the dock strip, at the bottom of its site
	var/mob/living/carbon/human/consistent/on_dock = hunter_at(outside(3, -2))
	// On its level, off its site: another planet in the lattice
	var/mob/living/carbon/human/consistent/elsewhere = hunter_at(outside(40, 0))
	// On its site, but SSD
	var/mob/living/carbon/human/consistent/asleep = hunter_at(outside(1, 20))
	// On its site and playing, but not hunting it
	var/mob/living/carbon/human/consistent/stranger = hunter_at(outside(2, 20))
	TEST_ASSERT(get_dist(on_site, run_loc_floor_bottom_left) > 9, "The on-site crewmate is within the boss's sight") // BOUNTY_BOSS_POSSE_RANGE
	for(var/mob/living/carbon/human/consistent/playing as anything in list(tagger, on_site, on_dock, elsewhere, stranger))
		playing.mock_client = allocate(/datum/client_interface)
	for(var/mob/living/carbon/human/consistent/member as anything in list(tagger, on_site, on_dock, elsewhere, asleep))
		crew.join_member(member.mind)
	TEST_ASSERT_EQUAL(posting.hunt(ship), TRUE, "The test ship couldn't hunt the bounty")
	var/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut/boss = spawn_bounty_criminal(posting.record, spot(0, 0), posting)
	if(boss)
		allocated += boss
	TEST_ASSERT(istype(boss), "The posted Juggernaut spawned as [boss?.type]")
	boss.ai_controller?.set_ai_status(AI_STATUS_OFF)
	// Its site: the room and well around it, with a dock strip along the bottom
	var/turf/corner = run_loc_floor_bottom_left
	boss.site_bounds = list(corner.x - 3, corner.y - 3, corner.x + 25, corner.y + 25, corner.z)
	boss.body_dock_top_y = corner.y - 1
	TEST_ASSERT(boss.body_on_site(get_turf(on_site)), "The test's on-site spot is off the site")
	TEST_ASSERT(!boss.body_on_site(get_turf(on_dock)) && boss.body_on_dock_strip(get_turf(on_dock)), "The test's dock strip spot isn't on the dock strip")
	TEST_ASSERT(!boss.body_on_site(get_turf(elsewhere)), "The test's off-site spot is on the site")

	boss.body_add_grudge(tagger)
	boss.boss_turn_hostile(tagger)
	TEST_ASSERT(boss.boss_engaged[REF(tagger)], "The hunter who woke it isn't in its posse")
	TEST_ASSERT(boss.boss_engaged[REF(on_site)], "A crewmate out of its sight on its site isn't in its posse")
	TEST_ASSERT(boss.boss_engaged[REF(on_dock)], "A crewmate waiting on the dock strip isn't in its posse")
	TEST_ASSERT(!boss.boss_engaged[REF(elsewhere)], "A crewmate on another site on its level joined its posse")
	TEST_ASSERT(!boss.boss_engaged[REF(asleep)], "An SSD crewmate joined its posse")
	TEST_ASSERT(!boss.boss_engaged[REF(stranger)], "Someone out of its sight who isn't hunting it joined its posse")
	// Three of the crew at its site: two companions owed (one per hunter beyond the first), and its body as it was
	TEST_ASSERT_EQUAL(boss.boss_reinforcements_owed + boss.boss_reinforcements_sent, 2, "Woken with three of a crew at its site, it owes the wrong number of companions")
	TEST_ASSERT_NOTNULL(boss.boss_reinforce_timer, "The companions owed weren't scheduled")
	TEST_ASSERT_EQUAL(boss.maxHealth, 100, "The crew changed the boss's health") // MAX_LIVING_HEALTH
	for(var/datum/mind/member as anything in crew.members.Copy())
		member.ship_teams = null
	crew.members.Cut()
	crew.ship = null
	ship.ship_team = null
	QDEL_NULL(crew)
	board_test_end()

// ===== HURT FROM WHERE IT CAN'T REACH (review r1 F4) =====

/**
 * Shot from behind glass it can't break, with no way round: it doesn't go after the shooter, and it
 * breaks for cover out of their sight on its own side, with a line. Once they come round, it goes after
 * them again.
 */
/datum/unit_test/voidcrew_bounty_boss/reach/out_of_reach

/datum/unit_test/voidcrew_bounty_boss/reach/out_of_reach/Run()
	// A wall down the middle of the room: reinforced glass low, solid wall high
	for(var/dy in 0 to 2)
		allocate(/obj/structure/window/reinforced/fulltile, spot(2, dy))
	change_turf(spot(2, 3), /turf/closed/wall/r_wall)
	change_turf(spot(2, 4), /turf/closed/wall/r_wall)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/ghost/ghost = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/ghost, spot(0, 0))
	var/datum/ai_controller/controller = ghost.ai_controller
	var/mob/living/carbon/human/consistent/sniper = hunter_at(spot(4, 4))
	var/atom/barrier = ghost.boss_barrier_between(get_turf(ghost), get_turf(sniper))
	TEST_ASSERT(istype(barrier, /obj/structure/window), "The glass between them isn't what stops it: [barrier?.type]")
	TEST_ASSERT(!ghost.boss_goes_through(barrier), "The Ghost goes through reinforced glass")
	TEST_ASSERT(!ghost.boss_can_reach(sniper), "The Ghost can reach someone behind glass with no way round")
	TEST_ASSERT(ghost.boss_valid_target(sniper), "Before a shot, the Ghost won't go after someone it can see")

	// Shot from there: it keeps away from them
	ghost.body_add_grudge(sniper)
	TEST_ASSERT(ghost.boss_note_attacker(sniper), "The shot wasn't noted")
	TEST_ASSERT(ghost.boss_shuns(sniper), "Shot from behind glass, the Ghost doesn't keep away from the shooter")
	TEST_ASSERT(!ghost.boss_valid_target(sniper), "Shot from behind glass, the Ghost still goes after the shooter")
	TEST_ASSERT_NULL(ghost.boss_revenge_target(), "Shot from behind glass, the Ghost turns on the shooter")
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(/datum/targeting_strategy/basic/human_npc/bounty_boss)
	TEST_ASSERT(!strategy.can_attack(ghost, sniper, 9), "The boss's targeting picks a shooter it can't get at") // BOUNTY_BOSS_POSSE_RANGE
	TEST_ASSERT_NULL(ghost.boss_nearest_hunter(list(sniper)), "The hunt walks it out at a shooter behind glass")
	var/list/watchers = ghost.boss_watchers()
	TEST_ASSERT(sniper in watchers, "The shooter isn't one it hides from")
	TEST_ASSERT(ghost.boss_seen_from(get_turf(ghost), watchers), "The test needs the shooter to see the Ghost where it stands")
	var/turf/cover = ghost.boss_find_cover(watchers)
	TEST_ASSERT_NOTNULL(cover, "The Ghost found no cover on its side of the glass")
	TEST_ASSERT(!can_see(sniper, cover, 9), "The Ghost's cover is in the shooter's sight") // BOUNTY_BOSS_COVER_SIGHT
	TEST_ASSERT(cover.x < spot(2, 0).x, "The Ghost's cover is on the shooter's side")

	// Its planner breaks for that cover, with a line of its own
	var/datum/component/bounty_identity_voice/voice = ghost.LoadComponent(/datum/component/bounty_identity_voice)
	voice.line_cooldown = 0
	voice.last_line = null
	TEST_ASSERT_EQUAL(plan_with(ghost, /datum/ai_planning_subtree/bounty_boss_cover), SUBTREE_RETURN_FINISH_PLANNING, "Seen by a shooter it can't get at, it planned nothing")
	TEST_ASSERT_NOTNULL(controller.blackboard["BB_bounty_boss_cover"], "Seen by a shooter it can't get at, it stays put") // BB_BOUNTY_BOSS_COVER
	TEST_ASSERT(planned(controller, /datum/ai_behavior/travel_towards), "It doesn't walk for cover")
	TEST_ASSERT(voice.last_line in bounty_identity_strings("lines")["ghost_cover"]["any"], "Breaking for cover, the Ghost said [voice.last_line || "nothing"]")
	controller.CancelActions()
	controller.clear_blackboard_key("BB_bounty_boss_cover")

	// Come round: fair game again
	sniper.forceMove(spot(1, 0))
	TEST_ASSERT(ghost.boss_can_reach(sniper), "The Ghost can't reach someone right beside it")
	TEST_ASSERT(!ghost.boss_shuns(sniper), "The Ghost keeps away from someone who came round to it")
	TEST_ASSERT(ghost.boss_valid_target(sniper), "The Ghost won't go after someone who came round to it")
	TEST_ASSERT(!(sniper in ghost.boss_watchers()), "It still hides from someone who came round to it")

/**
 * A sniper far off (review r2): past the walk it works out, and past BOUNTY_BOSS_COVER_SIGHT. On its
 * site with open ground round the table between them, it goes after them. Off its site (where it can't
 * follow), it sees that they see it and backs off, keeps walking until it gets there, and hides
 * behind a wall when one is near. Its walk is always worked out from the tile it stands on.
 */
/datum/unit_test/voidcrew_bounty_boss/reach/far_sniper

/datum/unit_test/voidcrew_bounty_boss/reach/far_sniper/Run()
	// Open floor north of the room: 21 wide, 5 deep
	floor_area(0, 10, 20, 14)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/ghost/ghost = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/ghost, outside(0, 12))
	var/datum/ai_controller/controller = ghost.ai_controller
	allocate(/obj/structure/table, outside(2, 12))
	var/mob/living/carbon/human/consistent/sniper = hunter_at(outside(13, 12))
	TEST_ASSERT(get_dist(ghost, sniper) > 10, "The sniper isn't past the walk it works out") // BOUNTY_BOSS_REACH_RANGE
	TEST_ASSERT(istype(ghost.boss_barrier_between(get_turf(ghost), get_turf(sniper)), /obj/structure/table), "The table isn't between them")

	// On its site, open ground round the table: in reach, and it goes after them
	TEST_ASSERT(ghost.boss_can_reach(sniper), "A sniper 13 tiles off across open ground is out of its reach")
	ghost.body_add_grudge(sniper)
	TEST_ASSERT(ghost.boss_note_attacker(sniper), "The shot wasn't noted")
	TEST_ASSERT(!ghost.boss_shuns(sniper), "Shot from 13 tiles off across open ground, it keeps away from the shooter")
	TEST_ASSERT(ghost.boss_valid_target(sniper), "Shot from 13 tiles off, it won't go after the shooter")
	TEST_ASSERT(!(sniper in ghost.boss_watchers()), "It hides from a shooter it can walk to")
	TEST_ASSERT_EQUAL(ghost.boss_nearest_hunter(list(sniper)), sniper, "The hunt doesn't pick the shooter")
	controller.set_blackboard_key("BB_bounty_boss_prey", sniper) // BB_BOUNTY_BOSS_PREY
	controller.set_blackboard_key("BB_bounty_boss_hunt_at", world.time + 10 SECONDS) // BB_BOUNTY_BOSS_HUNT_AT
	TEST_ASSERT_EQUAL(plan_with(ghost, /datum/ai_planning_subtree/bounty_boss_hunt), SUBTREE_RETURN_FINISH_PLANNING, "The hunt planned nothing")
	TEST_ASSERT(planned(controller, /datum/ai_behavior/travel_towards/adjacent), "It doesn't walk after the shooter")
	controller.CancelActions()
	controller.clear_blackboard_key("BB_bounty_boss_prey")

	// Walled in near it, the same sniper is out of reach: the walk never gets it closer to them
	var/mob/living/carbon/human/npc/bounty_criminal/boss/ghost/boxed = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/ghost, outside(0, 12))
	for(var/dy in 10 to 14)
		change_turf(outside(1, dy), /turf/closed/wall/r_wall)
	TEST_ASSERT(!boxed.boss_can_reach(sniper), "Walled in, it can reach a sniper 13 tiles off")
	for(var/dy in 10 to 14)
		change_turf(outside(1, dy), /turf/open/floor/iron)
	qdel(boxed)

	// Off its site (in their ship), 12 tiles off with a clear line: it can't follow, and it knows they see it
	var/mob/living/carbon/human/npc/bounty_criminal/boss/ghost/hider = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/ghost, outside(7, 12))
	controller = hider.ai_controller
	var/turf/ship_floor = make_ship_tile(outside(19, 12))
	sniper.forceMove(ship_floor)
	hider.body_add_grudge(sniper)
	TEST_ASSERT(hider.boss_note_attacker(sniper), "The shot from the ship wasn't noted")
	TEST_ASSERT(hider.boss_shuns(sniper), "Shot from off its site, it doesn't keep away from the shooter")
	var/list/watchers = hider.boss_watchers()
	TEST_ASSERT(sniper in watchers, "The shooter in their ship isn't one it hides from")
	TEST_ASSERT(hider.boss_seen_from(get_turf(hider), watchers), "12 tiles off with a clear line, it thinks the shooter can't see it")

	// Nowhere hidden in reach: it backs off as far as it can, saying so, and keeps going (review r2 bug 3)
	var/datum/component/bounty_identity_voice/voice = hider.LoadComponent(/datum/component/bounty_identity_voice)
	voice.line_cooldown = 0
	voice.last_line = null
	var/turf/start = get_turf(hider)
	TEST_ASSERT_EQUAL(plan_with(hider, /datum/ai_planning_subtree/bounty_boss_cover), SUBTREE_RETURN_FINISH_PLANNING, "In the open in a shooter's sight, it planned nothing")
	var/turf/away = controller.blackboard["BB_bounty_boss_cover"] // BB_BOUNTY_BOSS_COVER
	TEST_ASSERT_NOTNULL(away, "In the open in a shooter's sight, it stays put")
	TEST_ASSERT(get_dist(away, sniper) > get_dist(start, sniper), "It doesn't back away from the shooter")
	TEST_ASSERT(planned(controller, /datum/ai_behavior/travel_towards), "It doesn't walk away from the shooter")
	TEST_ASSERT(voice.last_line in bounty_identity_strings("lines")["ghost_cover"]["any"], "Breaking for cover, the Ghost said [voice.last_line || "nothing"]")
	// The next plan, still on its way: it keeps walking
	TEST_ASSERT_EQUAL(plan_with(hider, /datum/ai_planning_subtree/bounty_boss_cover), SUBTREE_RETURN_FINISH_PLANNING, "On its way, it planned nothing")
	TEST_ASSERT(planned(controller, /datum/ai_behavior/travel_towards), "On its way to the farthest spot, it dropped its own walk")
	TEST_ASSERT_EQUAL(controller.blackboard["BB_bounty_boss_cover"], away, "On its way, it changed its mind") // BB_BOUNTY_BOSS_COVER
	controller.CancelActions()

	// A wall near it: it hides behind that, out of the shooter's line
	for(var/dy in 11 to 13)
		change_turf(outside(5, dy), /turf/closed/wall/r_wall)
	hider.boss_walk_cache = null
	var/turf/cover = hider.boss_find_cover(watchers)
	TEST_ASSERT_NOTNULL(cover, "With a wall near it, it found no cover from a shooter 12 tiles off")
	TEST_ASSERT(!hider.boss_seen_from(cover, watchers), "Its cover is in the shooter's line")
	TEST_ASSERT(cover.x < outside(5, 12).x, "Its cover isn't behind the wall")

	// Its walk is worked out from where it stands, not where it stood
	var/list/steps = hider.boss_walkable()
	TEST_ASSERT_EQUAL(steps[get_turf(hider)], 0, "Its walk doesn't start where it stands")
	hider.forceMove(outside(8, 10))
	steps = hider.boss_walkable()
	TEST_ASSERT_EQUAL(steps[get_turf(hider)], 0, "A step later, its walk still starts where it stood")

/**
 * The breach planner (review r2): with its charge on cooldown and a way round, the Juggernaut goes
 * round rather than wait at the glass; with the charge ready it walks up; with no way round it waits
 * at the glass for the charge.
 */
/datum/unit_test/voidcrew_bounty_boss/reach/breach

/datum/unit_test/voidcrew_bounty_boss/reach/breach/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut/boss = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut, spot(0, 2))
	var/datum/ai_controller/controller = boss.ai_controller
	var/mob/living/carbon/human/consistent/behind = hunter_at(spot(4, 2))
	var/obj/structure/window/fulltile/pane = allocate(/obj/structure/window/fulltile, spot(2, 2))
	var/datum/action/cooldown/mob_cooldown/bounty_boss/charge/charge = ability_of(boss, /datum/action/cooldown/mob_cooldown/bounty_boss/charge)
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, behind)
	TEST_ASSERT(boss.boss_goes_through(pane), "The Juggernaut's charge doesn't go through plain glass")
	var/list/blockers = boss.boss_line_blockers(get_turf(boss), get_turf(behind))
	TEST_ASSERT_EQUAL(length(blockers), 1, "One plain window reads as [length(blockers)] things in its way")
	TEST_ASSERT(boss.boss_gets_through(blockers), "The Juggernaut's charge doesn't get through one plain window")
	TEST_ASSERT_EQUAL(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], behind, "The test's target didn't stick")

	// Charge on cooldown, a way round: no breach, so the melee planner walks it round
	charge.next_use_time = world.time + 100 SECONDS
	TEST_ASSERT(!boss.boss_breaks_through_now(pane), "The Juggernaut's charge is ready on cooldown")
	TEST_ASSERT_NULL(plan_with(boss, /datum/ai_planning_subtree/bounty_boss_breach), "With its charge on cooldown and a way round, it went at the glass")
	TEST_ASSERT_NULL(controller.blackboard["BB_bounty_boss_spot"], "With its charge on cooldown and a way round, it picked a spot at the glass") // BB_BOUNTY_BOSS_SPOT

	// Charge ready: it walks up to the glass
	charge.next_use_time = 0
	TEST_ASSERT(boss.boss_breaks_through_now(pane), "The Juggernaut's charge isn't ready off cooldown")
	TEST_ASSERT_EQUAL(plan_with(boss, /datum/ai_planning_subtree/bounty_boss_breach), SUBTREE_RETURN_FINISH_PLANNING, "With its charge ready, it didn't go at the glass")
	TEST_ASSERT_EQUAL(controller.blackboard["BB_bounty_boss_spot"], spot(1, 2), "With its charge ready, it isn't walking up to the glass") // BB_BOUNTY_BOSS_SPOT
	TEST_ASSERT(planned(controller, /datum/ai_behavior/travel_towards), "With its charge ready, it doesn't walk")
	controller.CancelActions()
	controller.clear_blackboard_key("BB_bounty_boss_spot")

	// No way round: it waits at the glass for its charge
	for(var/dy in list(0, 1, 3, 4))
		allocate(/obj/structure/window/reinforced/fulltile, spot(2, dy))
	boss.boss_walk_cache = null
	charge.next_use_time = world.time + 100 SECONDS
	TEST_ASSERT(!boss.boss_walks_to(get_turf(behind)), "The test's glass wall has a way round")
	TEST_ASSERT_EQUAL(plan_with(boss, /datum/ai_planning_subtree/bounty_boss_breach), SUBTREE_RETURN_FINISH_PLANNING, "With no way round, it didn't go at the glass")
	TEST_ASSERT_EQUAL(controller.blackboard["BB_bounty_boss_spot"], spot(1, 2), "With no way round, it isn't walking up to the glass") // BB_BOUNTY_BOSS_SPOT
	controller.CancelActions()

// ===== GORILLA ARMS THROUGH GLASS: THE IMPLANT'S OWN PUNCHES =====

/**
 * Smashing is all or nothing (review r2): Gorilla Arms leave alone a grille with glass behind it they
 * can't break in a few punches, and go at one with glass they can.
 */
/datum/unit_test/voidcrew_bounty_boss/reach/smash_line

/datum/unit_test/voidcrew_bounty_boss/reach/smash_line/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut/boss = gorilla_boss(spot(0, 1))
	var/datum/ai_controller/controller = boss.ai_controller
	var/mob/living/carbon/human/consistent/behind = hunter_at(spot(4, 1))
	var/obj/structure/grille/grille = allocate(/obj/structure/grille, spot(2, 1))
	var/obj/structure/window/reinforced/fulltile/thick = allocate(/obj/structure/window/reinforced/fulltile, spot(2, 1))
	var/list/blockers = boss.boss_line_blockers(get_turf(boss), get_turf(behind))
	TEST_ASSERT((grille in blockers) && (thick in blockers), "The grille and the glass on one tile aren't both in its way")
	TEST_ASSERT(boss.boss_gorilla_goes_through(grille), "Gorilla Arms don't go through a grille")
	TEST_ASSERT(!boss.boss_gorilla_goes_through(thick), "Gorilla Arms go through reinforced glass")
	TEST_ASSERT(!boss.boss_gets_through(blockers), "It goes at a grille with glass behind it it can't break")
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, behind)
	TEST_ASSERT_NULL(plan_with(boss, /datum/ai_planning_subtree/bounty_boss_breach), "It went at a grille with glass behind it it can't break")
	TEST_ASSERT_NULL(controller.blackboard["BB_bounty_boss_spot"], "It picked a spot at glass it can't break") // BB_BOUNTY_BOSS_SPOT

	// Plain glass behind the grille: all of it breaks, so it goes at it, its Gorilla Arms ready with the charge on cooldown
	qdel(thick)
	var/obj/structure/window/fulltile/pane = allocate(/obj/structure/window/fulltile, spot(2, 1))
	var/datum/action/cooldown/mob_cooldown/bounty_boss/charge/charge = ability_of(boss, /datum/action/cooldown/mob_cooldown/bounty_boss/charge)
	charge.next_use_time = world.time + 100 SECONDS
	boss.boss_walk_cache = null
	blockers = boss.boss_line_blockers(get_turf(boss), get_turf(behind))
	TEST_ASSERT((grille in blockers) && (pane in blockers), "The grille and the plain glass on one tile aren't both in its way")
	TEST_ASSERT_EQUAL(length(blockers), 2, "A grille and a window on one tile read as [length(blockers)] things in its way")
	TEST_ASSERT(boss.boss_gets_through(blockers), "It won't go at a grille with plain glass behind it")
	TEST_ASSERT(boss.boss_breaks_through_now(grille), "Its Gorilla Arms aren't ready for the grille")
	TEST_ASSERT_EQUAL(plan_with(boss, /datum/ai_planning_subtree/bounty_boss_breach), SUBTREE_RETURN_FINISH_PLANNING, "It didn't go at a grille and glass it can break")
	TEST_ASSERT_EQUAL(controller.blackboard["BB_bounty_boss_spot"], spot(1, 1), "It isn't walking up to glass it can break") // BB_BOUNTY_BOSS_SPOT
	controller.CancelActions()

/**
 * The smash: a tell first, then the implant's own punches through a plain window, never reinforced glass
 * or an airlock, never off its site or near a ship, never with an EMP'd arm or a full hand, and nothing
 * lands if it is stopped in the tell. Then what the other kits get through.
 */
/datum/unit_test/voidcrew_bounty_boss/reach/smash

/datum/unit_test/voidcrew_bounty_boss/reach/smash/Run()
	var/obj/structure/window/fulltile/pane = allocate(/obj/structure/window/fulltile, spot(1, 2))
	var/obj/structure/window/reinforced/fulltile/thick = allocate(/obj/structure/window/reinforced/fulltile, spot(1, 4))
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, spot(1, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut/boss = gorilla_boss(spot(0, 2))
	TEST_ASSERT(boss.boss_gorilla_goes_through(pane), "Gorilla Arms don't go through plain glass")
	TEST_ASSERT(!boss.boss_gorilla_goes_through(thick), "Gorilla Arms go through reinforced glass")
	TEST_ASSERT(!boss.boss_can_smash(door), "Gorilla Arms smash an airlock instead of forcing it")

	// The tell: rooted, glowing, the tile lit, nothing broken yet
	var/integrity = pane.get_integrity()
	TEST_ASSERT(boss.boss_start_smash(pane), "The smash didn't start")
	var/serial = boss.boss_busy_serial
	TEST_ASSERT_EQUAL(boss.boss_busy, "smash", "The smash doesn't hold the boss") // BOUNTY_BOSS_BUSY_SMASH
	TEST_ASSERT(HAS_TRAIT(boss, TRAIT_IMMOBILIZED), "It walks about mid-smash")
	TEST_ASSERT_NOTNULL(boss.get_filter("bounty_boss_smash"), "The smash's tell doesn't glow") // BOUNTY_BOSS_SMASH_FILTER
	TEST_ASSERT(marks_near(pane, 0) > 0, "The smash marks nothing")
	TEST_ASSERT_EQUAL(pane.get_integrity(), integrity, "The glass broke before the tell was over")
	TEST_ASSERT(!boss.boss_start_smash(pane), "A second smash started mid-smash")

	// The punches: the implant's own, each what one Gorilla Arms punch does to that glass
	var/expected = pane.run_atom_armor(40, BRUTE, MELEE) // BOUNTY_BOSS_SMASH_BLOW, CYBERWARE_GORILLA_STRUCTURE_DAMAGE
	ready_fists(boss)
	TEST_ASSERT(boss.boss_smash_blow(serial), "The first punch wasn't thrown")
	TEST_ASSERT(abs((integrity - pane.get_integrity()) - expected) < 0.1, "A Gorilla Arms punch took [integrity - pane.get_integrity()] off the glass, not the [expected] the smash counts on")
	var/punches = 1
	for(var/i in 1 to 6) // BOUNTY_BOSS_SMASH_MOST_BLOWS
		if(boss.boss_busy != "smash")
			break
		ready_fists(boss)
		if(boss.boss_smash_blow(serial))
			punches++
	TEST_ASSERT(QDELETED(pane) || !pane.density, "[punches] punches didn't get it through the plain window")
	TEST_ASSERT(punches <= 6, "It threw [punches] punches") // BOUNTY_BOSS_SMASH_MOST_BLOWS
	TEST_ASSERT_NULL(boss.boss_busy, "The smash kept the boss after it got through")
	TEST_ASSERT(!HAS_TRAIT(boss, TRAIT_IMMOBILIZED), "The boss is still rooted after the smash")
	TEST_ASSERT_NULL(boss.get_filter("bounty_boss_smash"), "The smash's glow outlived it")
	TEST_ASSERT_EQUAL(marks_near(spot(1, 2), 0), 0, "The smash's mark outlived it")

	// Stopped in the tell: nothing lands, the mark goes
	var/obj/structure/window/fulltile/other_pane = allocate(/obj/structure/window/fulltile, spot(0, 3))
	boss.boss_next_ability_at = 0
	integrity = other_pane.get_integrity()
	TEST_ASSERT(boss.boss_start_smash(other_pane), "The second smash didn't start")
	serial = boss.boss_busy_serial
	boss.boss_interrupt()
	ready_fists(boss)
	TEST_ASSERT(!boss.boss_smash_blow(serial), "An interrupted smash threw a punch")
	TEST_ASSERT_EQUAL(other_pane.get_integrity(), integrity, "An interrupted smash hurt the glass")
	TEST_ASSERT_EQUAL(marks_near(other_pane, 0), 0, "An interrupted smash left its mark")

	// EMP'd, the arms are dead weight until they reboot
	boss.boss_next_ability_at = 0
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in boss.organs)
		var/datum/component/cyberware/ware = arm.GetComponent(/datum/component/cyberware)
		ware.start_emp_reboot()
	TEST_ASSERT(!boss.boss_gorilla_goes_through(other_pane), "EMP'd Gorilla Arms go through glass")
	TEST_ASSERT(!boss.boss_start_smash(other_pane), "EMP'd Gorilla Arms smashed glass")
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in boss.organs)
		var/datum/component/cyberware/ware = arm.GetComponent(/datum/component/cyberware)
		ware.tune_up()
	TEST_ASSERT(boss.boss_gorilla_goes_through(other_pane), "Rebooted Gorilla Arms don't go through glass")

	// Both hands full: no fist to punch with
	var/obj/item/wrench/left_load = allocate(/obj/item/wrench)
	var/obj/item/screwdriver/right_load = allocate(/obj/item/screwdriver)
	TEST_ASSERT(boss.put_in_hands(left_load) && boss.put_in_hands(right_load), "Test fixture: the boss couldn't fill both hands")
	TEST_ASSERT(!boss.boss_has_gorilla_fist(), "With both hands full, it still has a fist to punch with")
	TEST_ASSERT(!boss.boss_gorilla_goes_through(other_pane), "With both hands full, its Gorilla Arms go through glass")
	qdel(left_load)
	qdel(right_load)
	TEST_ASSERT(boss.boss_has_gorilla_fist(), "Hands empty again, it has no fist")

	// Off its site: never
	var/turf/corner = run_loc_floor_bottom_left
	boss.site_bounds = list(corner.x, corner.y, corner.x + 1, corner.y + 2, corner.z)
	TEST_ASSERT(!boss.boss_can_smash(other_pane), "Gorilla Arms go at glass off its site")
	boss.site_bounds = null

	// The other kits
	var/obj/structure/window/fulltile/plain = allocate(/obj/structure/window/fulltile, spot(3, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut/juggernaut = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut, spot(4, 0))
	TEST_ASSERT(juggernaut.boss_goes_through(plain), "The Juggernaut's charge doesn't go through plain glass")
	TEST_ASSERT(!juggernaut.boss_goes_through(thick), "The Juggernaut's charge goes through reinforced glass")
	var/mob/living/carbon/human/npc/bounty_criminal/boss/heavy/heavy = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/heavy, spot(4, 3))
	TEST_ASSERT(heavy.boss_goes_through(thick), "The Heavy's rounds don't chip interior glass")
	var/mob/living/carbon/human/npc/bounty_criminal/boss/pyromaniac/pyro = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/pyromaniac, spot(3, 3))
	TEST_ASSERT(pyro.boss_goes_through(thick), "The Pyromaniac's molotov doesn't go over glass")
	TEST_ASSERT(!pyro.boss_goes_through(door), "The Pyromaniac's molotov goes over a shut airlock")
	var/mob/living/carbon/human/npc/bounty_criminal/boss/ghost/ghost = boss_at(/mob/living/carbon/human/npc/bounty_criminal/boss/ghost, spot(4, 4))
	TEST_ASSERT(!ghost.boss_goes_through(plain), "The Ghost goes through glass")

	// Near a player's ship: never (BOUNTY_ENV_SAFE_RANGE)
	make_ship_tile(spot(4, 1))
	TEST_ASSERT(!boss.boss_can_smash(other_pane), "Gorilla Arms go at glass near a player's ship")
	TEST_ASSERT(!boss.boss_gorilla_goes_through(other_pane), "Gorilla Arms go through glass near a player's ship")
