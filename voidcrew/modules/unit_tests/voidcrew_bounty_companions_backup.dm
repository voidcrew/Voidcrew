/**
 * Bounty hunting: companions back their criminal up (C4), for voidcrew/modules/bounties/bounty_companions.dm,
 * bounty_placement.dm (the posting's company), bounty_posting.dm (the sighting) and bounty_styles.dm (the
 * companions' strings and bursts). At most one of a criminal's company carries a gun; the posting rolls
 * the company with its site, names it on the card, the notices and the warrant, and spawns that same
 * company; companions get up before they draw, a beat after their criminal, fire pistol strings of three
 * and SMG bursts of two; and now and then one carries a piece of real chrome, rarer than its criminal's.
 *
 * The tests drive the procs directly (a test world has no clients, so the AI is off), with the gun tests'
 * helpers (voidcrew_bounty_guns.dm). Fork defines are included after the tests, so a test uses the
 * literal value with a comment naming the define.
 */

/// One companion of a company as bounty_roll_company() makes it: `style` (BOUNTY_STYLE_*) and `chrome` (keys, or null)
/proc/bounty_test_company_member(style, list/chrome)
	return list("style" = style, "chrome" = chrome) // BOUNTY_COMPANY_STYLE, BOUNTY_COMPANY_CHROME

/// The companion tests, in the bounty AI tests' room, with the gun tests' helpers
/datum/unit_test/voidcrew_bounty_companions
	parent_type = /datum/unit_test/voidcrew_bounty_guns
	abstract_type = /datum/unit_test/voidcrew_bounty_companions

/// `leader`'s companion at `where`, made now as the posting's `member` would be (bounty_test_company_member()), its AI off
/datum/unit_test/voidcrew_bounty_companions/proc/make_companion(mob/living/carbon/human/npc/bounty_criminal/leader, turf/where, list/member)
	var/datum/human_npc_order/order = bounty_spawn_companion(leader, where, null, TRUE, member)
	var/mob/living/carbon/human/npc/bounty_companion/buddy = order?.spawned_ref?.resolve()
	qdel(order)
	TEST_ASSERT_NOTNULL(buddy, "Test fixture: no companion was made")
	allocated += buddy
	buddy.ai_controller.set_ai_status(AI_STATUS_OFF)
	return buddy

/// A hunter at `where` whom `buddy` and its criminal are out to get: on the criminal's grudge list, the companion's enemy and its target
/datum/unit_test/voidcrew_bounty_companions/proc/make_companion_target(mob/living/carbon/human/npc/bounty_companion/buddy, turf/where)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, where)
	buddy.ai_leader()?.ai_add_grudge(hunter)
	buddy.ai_mark_enemy(hunter)
	buddy.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	return hunter

/// The chrome organ types in `body`
/datum/unit_test/voidcrew_bounty_companions/proc/chrome_in(mob/living/carbon/body)
	. = list()
	for(var/obj/item/organ/organ in body.organs)
		if(organ.GetComponent(/datum/component/cyberware))
			. += organ.type

// ===== THE COMPANY =====

/**
 * A criminal's company: never two guns, and the gun (if any) first; a companion's chrome is one piece at
 * most, never Lazarus or the Piledriver, rolled for its own style, and only now and then. Companions a
 * criminal spawns without a posting's company follow the same rule, and so does one more joining a
 * criminal who already has an armed companion.
 */
/datum/unit_test/voidcrew_bounty_companions/rolls

/datum/unit_test/voidcrew_bounty_companions/rolls/Run()
	var/chromed = 0
	var/members = 0
	for(var/i in 1 to 300)
		var/list/company = bounty_roll_company(2, 3) // BOUNTY_TIER_MOST_WANTED
		TEST_ASSERT_EQUAL(length(company), 2, "Two companions rolled as [length(company)]")
		var/guns = 0
		for(var/j in 1 to length(company))
			var/list/member = company[j]
			var/style = member["style"] // BOUNTY_COMPANY_STYLE
			TEST_ASSERT_NOTNULL(GLOB.bounty_styles[style], "A companion rolled the style [style]")
			if(bounty_style_is_gun(style))
				guns++
				TEST_ASSERT_EQUAL(j, 1, "The armed companion isn't first in the company")
			members++
			var/list/chrome = member["chrome"] // BOUNTY_COMPANY_CHROME
			if(!length(chrome))
				continue
			chromed++
			TEST_ASSERT_EQUAL(length(chrome), 1, "A companion rolled [length(chrome)] pieces of chrome")
			TEST_ASSERT(!(chrome[1] in list("lazarus", "piledriver")), "A companion rolled [chrome[1]]") // BOUNTY_CHROME_LAZARUS, BOUNTY_CHROME_PILEDRIVER
			var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces[chrome[1]]
			TEST_ASSERT(piece.can_roll(3, "companion", style, null, list()), "A [style] companion rolled [chrome[1]], which doesn't suit it") // BOUNTY_CHROME_COMPANION
		TEST_ASSERT(guns <= 1, "A company rolled [guns] guns")
	// A Most Wanted criminal's companion: 60 / 3 percent (BOUNTY_CHROME_CHANCE_MOST_WANTED / BOUNTY_CHROME_COMPANION_DIVISOR)
	var/percent = chromed * 100 / members
	TEST_ASSERT(percent >= 12 && percent <= 28, "A Most Wanted criminal's companions carry chrome [percent]% of the time, not about 20%")
	// A Petty criminal's never roll the chrome that is Wanted or worse
	for(var/i in 1 to 300)
		var/list/petty_company = bounty_roll_company(1, 1) // BOUNTY_TIER_PETTY
		var/list/member = petty_company[1]
		for(var/key in member["chrome"])
			TEST_ASSERT(!(key in list("cascade", "redline")), "A Petty criminal's companion rolled [key]") // BOUNTY_CHROME_CASCADE, BOUNTY_CHROME_REDLINE
	// The unarmed roll never gives a gun
	for(var/i in 1 to 200)
		TEST_ASSERT(!bounty_style_is_gun(bounty_roll_companion_style(no_gun = TRUE)), "The unarmed roll gave a gun")

	// Spawned by the criminal without a company: still at most one gun
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(2, 2), "brawler") // BOUNTY_STYLE_BRAWLER
	for(var/i in 1 to 6)
		var/list/gang = criminal.spawn_companions(2, TRUE)
		var/guns = 0
		for(var/mob/living/carbon/human/npc/bounty_companion/member as anything in gang)
			if(bounty_style_is_gun(member.ai_style))
				guns++
		TEST_ASSERT(guns <= 1, "A criminal's own company rolled [guns] guns")
		QDEL_LIST(gang)
	// One more joining a criminal with an armed companion carries no gun of its own
	var/mob/living/carbon/human/npc/bounty_companion/gunner = make_companion(criminal, tile(1, 1), bounty_test_company_member("smg")) // BOUNTY_STYLE_SMG
	TEST_ASSERT(bounty_company_armed(criminal), "A criminal with an SMG companion has no armed company")
	for(var/i in 1 to 6)
		var/mob/living/carbon/human/npc/bounty_companion/late = make_companion(criminal, tile(3, 1))
		TEST_ASSERT(!bounty_style_is_gun(late.ai_style), "A second companion rolled a [late.ai_style] beside an armed one")
		allocated -= late
		qdel(late)
	allocated -= gunner
	qdel(gunner)

/**
 * The posting's company is who comes: their styles, the weapons they carry, and their chrome, put in their
 * bodies as real organs and driven by the chrome subtree; a companion the posting rolled no chrome for has
 * none, and none is rolled for it as it is dressed.
 */
/datum/unit_test/voidcrew_bounty_companions/chrome

/datum/unit_test/voidcrew_bounty_companions/chrome/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(2, 2), "brawler", 2) // BOUNTY_STYLE_BRAWLER, BOUNTY_TIER_WANTED
	var/list/company = list(
		bounty_test_company_member("pistol", list("deadeye")), // BOUNTY_STYLE_PISTOL, BOUNTY_CHROME_DEADEYE
		bounty_test_company_member("knife"), // BOUNTY_STYLE_KNIFE
	)
	var/list/buddies = criminal.spawn_companions(2, TRUE, company)
	allocated += buddies
	TEST_ASSERT_EQUAL(length(buddies), 2, "The company didn't spawn")
	var/mob/living/carbon/human/npc/bounty_companion/shooter = buddies[1]
	var/mob/living/carbon/human/npc/bounty_companion/blade = buddies[2]
	TEST_ASSERT_EQUAL(shooter.ai_style, "pistol", "The first companion isn't the company's pistol")
	TEST_ASSERT_EQUAL(blade.ai_style, "knife", "The second companion isn't the company's knife")
	TEST_ASSERT_EQUAL(shooter.ai_controller.blackboard["bb_bounty_style"], "pistol", "The pistol companion fights in another style") // BB_BOUNTY_STYLE
	TEST_ASSERT_NOTNULL(carried(shooter, /obj/item/gun/ballistic/automatic/pistol/aps), "The pistol companion carries no Stechkin")
	TEST_ASSERT_NOTNULL(carried(blade, /obj/item/knife), "The knife companion carries no knife")

	// The pistol companion's Deadeye is a real organ in its eyes, and its chrome subtree has it
	TEST_ASSERT(/obj/item/organ/eyes/robotic/cyberware/deadeye in chrome_in(shooter), "The pistol companion has no Deadeye link in its body")
	TEST_ASSERT(length(shooter.ai_chrome) == 1 && shooter.ai_chrome[1] == "deadeye", "The pistol companion's chrome isn't the company's") // BOUNTY_CHROME_DEADEYE
	var/datum/component/bounty_chrome/chrome = shooter.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_NOTNULL(chrome, "The chromed companion's AI doesn't know its chrome")
	TEST_ASSERT("deadeye" in chrome.keys, "The chromed companion's AI doesn't drive its Deadeye")
	TEST_ASSERT(!length(chrome_in(blade)), "A companion the company rolled no chrome for carries some")
	TEST_ASSERT_NULL(blade.GetComponent(/datum/component/bounty_chrome), "An unchromed companion has the chrome AI")

	// The companion's tree: up first, then its chrome, then its weapon
	var/list/subtrees = shooter.ai_controller.planning_subtrees
	var/getting_up = subtrees.Find(locate(/datum/ai_planning_subtree/bounty_companion_getting_up) in subtrees)
	var/chrome_at = subtrees.Find(locate(/datum/ai_planning_subtree/bounty_chrome) in subtrees)
	var/arm_at = subtrees.Find(locate(/datum/ai_planning_subtree/bounty_arm) in subtrees)
	var/retaliate_at = subtrees.Find(locate(/datum/ai_planning_subtree/target_retaliate/bounty) in subtrees)
	TEST_ASSERT(retaliate_at && getting_up && chrome_at && arm_at, "The companion's tree is missing its targeting, getting up, chrome or arming")
	TEST_ASSERT(retaliate_at < getting_up && getting_up < chrome_at && chrome_at < arm_at, "The companion's tree isn't targeting, getting up, chrome, then arming")

	// Their chrome dies with them: scrap, as on every human NPC
	shooter.death()
	TEST_ASSERT(!(/obj/item/organ/eyes/robotic/cyberware/deadeye in chrome_in(shooter)), "A dead companion's Deadeye still works")

/**
 * Joining a fight, a companion gets up first: for a second (BOUNTY_COMPANION_DRAW_DELAY) nothing but
 * facing the hunter is planned, so no weapon comes out and no blow or shot goes; then the arm subtree
 * draws its gun with its line, as a criminal's does. Out of the fight and back in, it gets up again.
 */
/datum/unit_test/voidcrew_bounty_companions/draw_delay

/datum/unit_test/voidcrew_bounty_companions/draw_delay/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(2, 2), "brawler") // BOUNTY_STYLE_BRAWLER
	criminal.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/npc/bounty_companion/buddy = make_companion(criminal, tile(1, 2), bounty_test_company_member("pistol")) // BOUNTY_STYLE_PISTOL
	var/mob/living/carbon/human/hunter = make_companion_target(buddy, tile(4, 2))
	var/datum/ai_controller/controller = buddy.ai_controller
	var/list/subtrees = controller.planning_subtrees
	var/datum/ai_planning_subtree/getting_up = locate(/datum/ai_planning_subtree/bounty_companion_getting_up) in subtrees
	var/datum/ai_planning_subtree/arm = locate(/datum/ai_planning_subtree/bounty_arm) in subtrees
	var/datum/ai_behavior/draw = GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_draw/bounty)

	// Out of a fight, nothing holds them
	TEST_ASSERT(!getting_up.SelectBehaviors(controller, 0.1), "A companion out of a fight is held getting up")

	// Rallied: in the fight, at a run, and getting up for a second
	var/joined_at = world.time
	buddy.ai_join_fight(hunter)
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	TEST_ASSERT(buddy.ai_in_fight, "Rallied, the companion didn't join the fight")
	TEST_ASSERT(buddy.ai_draw_at >= joined_at + 10, "The companion may draw less than a second after joining the fight") // BOUNTY_COMPANION_DRAW_DELAY
	TEST_ASSERT_EQUAL(getting_up.SelectBehaviors(controller, 0.1), 1, "Just in the fight, the companion's planning goes past getting up") // SUBTREE_RETURN_FINISH_PLANNING
	var/obj/item/gun/stechkin = carried(buddy, /obj/item/gun/ballistic/automatic/pistol/aps)
	TEST_ASSERT(!buddy.is_holding(stechkin), "The companion's pistol came out the moment they joined the fight")

	// Up: the arm subtree draws the pistol, with its line, holding the first shot as a criminal's draw does
	buddy.ai_draw_at = world.time
	TEST_ASSERT(!getting_up.SelectBehaviors(controller, 0.1), "Up again, the companion is still held getting up")
	controller.planned_behaviors.Cut()
	TEST_ASSERT_EQUAL(arm.SelectBehaviors(controller, 0.1), 1, "Up, the companion doesn't reach for its gun") // SUBTREE_RETURN_FINISH_PLANNING
	TEST_ASSERT(controller.planned_behaviors[draw], "Up, the companion's arming didn't plan the draw")
	TEST_ASSERT_EQUAL(controller.blackboard["human_npc_draw_item"], stechkin, "The companion reached for something other than its pistol") // BB_HUMAN_NPC_DRAW_ITEM
	controller.CancelActions()
	TEST_ASSERT_EQUAL(draw_gun(buddy), stechkin, "The companion didn't draw its pistol")
	TEST_ASSERT(controller.blackboard["bb_bounty_windup_until"] >= world.time + 6, "The companion's draw doesn't hold its first shot") // BB_BOUNTY_WINDUP_UNTIL, BOUNTY_DRAW_TIME

	// Out of the fight and back in: up first again
	buddy.ai_leave_fight()
	TEST_ASSERT(!buddy.ai_in_fight && !buddy.ai_draw_at, "Out of the fight, the companion is still getting up")
	buddy.ai_join_fight(hunter)
	TEST_ASSERT_EQUAL(getting_up.SelectBehaviors(controller, 0.1), 1, "Back in the fight, the companion didn't get up first") // SUBTREE_RETURN_FINISH_PLANNING
	controller.CancelActions()

/**
 * A companion's gun is backup: its Stechkin fires strings of three (BOUNTY_COMPANION_PISTOL_STRING), then the
 * criminal's pause, and its WT-550 bursts of two (BOUNTY_COMPANION_SMG_BURST); a criminal's stay six and four.
 */
/datum/unit_test/voidcrew_bounty_companions/backup_fire

/datum/unit_test/voidcrew_bounty_companions/backup_fire/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/criminal = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(2, 4), "brawler") // BOUNTY_STYLE_BRAWLER
	criminal.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/datum/bounty_style/pistol = GLOB.bounty_styles["pistol"] // BOUNTY_STYLE_PISTOL
	var/datum/bounty_style/smg = GLOB.bounty_styles["smg"] // BOUNTY_STYLE_SMG
	var/datum/bounty_style/revolver = GLOB.bounty_styles["revolver"] // BOUNTY_STYLE_REVOLVER

	// The pistol: three shots half a second apart, then two seconds to the next string
	var/mob/living/carbon/human/npc/bounty_companion/gunner = make_companion(criminal, tile(0, 2), bounty_test_company_member("pistol"))
	var/mob/living/carbon/human/hunter = make_companion_target(gunner, tile(4, 2))
	TEST_ASSERT_EQUAL(pistol.string_length(gunner), 3, "A companion's pistol strings aren't three")
	TEST_ASSERT_EQUAL(pistol.string_length(criminal), 6, "A criminal's pistol strings aren't six") // BOUNTY_PISTOL_STRING_SHOTS
	TEST_ASSERT_EQUAL(revolver.string_length(gunner), 0, "A companion's revolver fires in strings")
	var/obj/item/gun/ballistic/automatic/pistol/aps/stechkin = draw_gun(gunner)
	var/datum/ai_controller/controller = gunner.ai_controller
	controller.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL
	controller.set_blackboard_key("bb_bounty_next_shot", world.time) // BB_BOUNTY_NEXT_SHOT
	var/full = bounty_gun_live_rounds(stechkin)
	TEST_ASSERT(full >= 7, "Test fixture: the companion's Stechkin holds only [full]")
	for(var/shot in 1 to 6)
		shoot_step(gunner)
		TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), full - shot, "The companion's shot [shot] wasn't a single round")
		var/wait = controller.blackboard["bb_bounty_next_shot"] - world.time // BB_BOUNTY_NEXT_SHOT
		if(!(shot % 3))
			TEST_ASSERT_EQUAL(wait, 20, "After the companion's [shot]th shot, the next string isn't 2 seconds off") // BOUNTY_PISTOL_INTERVAL + BOUNTY_PISTOL_STRING_PAUSE
		else
			TEST_ASSERT_EQUAL(wait, 5, "The companion's shot [shot + 1] isn't half a second after shot [shot]") // BOUNTY_PISTOL_INTERVAL
		next_pull(gunner, hunter)
		if(shot == 3)
			// The pause is waited out, not skipped: no new raise for the second string
			controller.set_blackboard_key("bb_bounty_last_shot", world.time - 20) // BB_BOUNTY_LAST_SHOT
			controller.set_blackboard_key("bb_bounty_drawn_at", world.time - 30) // BB_BOUNTY_DRAWN_AT
	shoot_stopped(gunner)
	allocated -= gunner
	qdel(gunner)

	// The SMG: bursts of two pulls
	var/mob/living/carbon/human/npc/bounty_companion/sprayer = make_companion(criminal, tile(0, 1), bounty_test_company_member("smg"))
	var/mob/living/carbon/human/mark = make_companion_target(sprayer, tile(4, 1))
	TEST_ASSERT_EQUAL(smg.burst_length(sprayer), 2, "A companion's SMG bursts aren't two")
	TEST_ASSERT_EQUAL(smg.burst_length(criminal), 4, "A criminal's SMG bursts aren't four") // BOUNTY_SMG_BURST
	TEST_ASSERT_EQUAL(pistol.burst_length(sprayer), 1, "A companion's pistol fires bursts")
	var/obj/item/gun/ballistic/automatic/wt550/wt550 = sprayer.belt
	TEST_ASSERT(istype(wt550), "Test fixture: the SMG companion has no WT-550 on its belt")
	TEST_ASSERT(human_npc_take_in_hand(sprayer, wt550), "The companion's WT-550 can't be drawn")
	var/datum/ai_controller/smg_ai = sprayer.ai_controller
	var/rounds = start_burst(sprayer, mark, wt550)
	TEST_ASSERT_EQUAL(smg_ai.blackboard["bb_bounty_burst_left"], 1, "A companion's burst doesn't have one pull left after the first") // BB_BOUNTY_BURST_LEFT
	shoot_step(sprayer)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(wt550), rounds - 1, "The companion's second pull didn't fire")
	TEST_ASSERT_NULL(smg_ai.blackboard["bb_bounty_burst_left"], "A companion's burst didn't end after two pulls") // BB_BOUNTY_BURST_LEFT
	TEST_ASSERT_EQUAL(smg_ai.blackboard["bb_bounty_next_shot"], world.time + 5, "After a companion's burst, the next one isn't half a second off") // BOUNTY_SMG_INTERVAL
	shoot_stopped(sprayer)
	allocated -= sprayer
	qdel(sprayer)

// ===== THE POSTING'S COMPANY =====

/**
 * The company is rolled with the posting's site and named on the sighting: the card, the hunt notice and
 * the warrant say who they were seen with, at most one of them armed. Nobody comes with a meek criminal,
 * a mini-boss or at a trader outpost, one at most aboard a pirate ship; the same company stays while the
 * bounty is at a site, a new site rolls a new one, and that company is who spawns beside the criminal.
 */
/datum/unit_test/voidcrew_bounty_company_card
	parent_type = /datum/unit_test/voidcrew_bounty_board

/datum/unit_test/voidcrew_bounty_company_card/Run()
	var/datum/criminal_bounty/posting = board_test_posting(archetype = "normal") // BOUNTY_ARCHETYPE_NORMAL
	// What the sighting says
	posting.board_company = list(bounty_test_company_member("brawler")) // BOUNTY_STYLE_*
	TEST_ASSERT_EQUAL(posting.board_company_text(), "with a friend", "One unarmed companion")
	posting.board_company = list(bounty_test_company_member("pistol"))
	TEST_ASSERT_EQUAL(posting.board_company_text(), "with an armed friend", "One armed companion")
	posting.board_company = list(bounty_test_company_member("knife"), bounty_test_company_member("club"))
	TEST_ASSERT_EQUAL(posting.board_company_text(), "with two friends", "Two unarmed companions")
	posting.board_company = list(bounty_test_company_member("smg"), bounty_test_company_member("bottle"))
	TEST_ASSERT_EQUAL(posting.board_company_text(), "with two friends, one armed", "Two companions, one armed")
	TEST_ASSERT_EQUAL(posting.board_sighting_text(), "[posting.board_place_text()] with two friends, one armed", "The sighting doesn't name the company after the place")
	var/obj/structure/overmap/ship/board_test_listener/ship = board_test_listener()
	var/list/entry = posting.board_ui_entry(ship, null)
	TEST_ASSERT_EQUAL(entry["place"], posting.board_sighting_text(), "The card doesn't name the company")
	TEST_ASSERT(findtext(posting.board_warrant_text(), "With two friends, one armed."), "The warrant doesn't name the company")
	TEST_ASSERT_EQUAL(posting.hunt(ship), TRUE, "The ship could not hunt the bounty")
	TEST_ASSERT(ship.board_test_heard("WANTED: now hunting [posting.record.name]. [posting.board_sighting_text()]."), "The hunt notice doesn't name the company")
	// Relisting, the company isn't known
	posting.board_relisting = TRUE
	TEST_ASSERT_NULL(posting.board_company_text(), "A relisting bounty names its company")
	posting.board_relisting = FALSE
	posting.board_company = list()
	TEST_ASSERT_NULL(posting.board_company_text(), "A criminal on their own is seen with someone")
	TEST_ASSERT_EQUAL(posting.board_sighting_text(), posting.board_place_text(), "A criminal on their own isn't seen just where they are")

	// The roll for where they are: at most two, one aboard a pirate ship, none at a trader outpost or with another kind of criminal
	for(var/i in 1 to 50)
		var/list/rolled = posting.board_roll_company()
		TEST_ASSERT(length(rolled) <= 2, "A planet criminal rolled [length(rolled)] companions") // BOUNTY_MAX_COMPANIONS
		var/guns = 0
		for(var/list/member as anything in rolled)
			if(bounty_style_is_gun(member["style"]))
				guns++
		TEST_ASSERT(guns <= 1, "A posting's company rolled [guns] guns")
	posting.placement_kind = "npc_ship" // BOUNTY_PLACEMENT_NPC_SHIP
	for(var/i in 1 to 50)
		TEST_ASSERT(length(posting.board_roll_company()) <= 1, "A criminal aboard a pirate ship rolled more than one companion")
	posting.placement_kind = "trader_outpost" // BOUNTY_PLACEMENT_TRADER_OUTPOST
	TEST_ASSERT(!length(posting.board_roll_company()), "A trader-outpost fugitive rolled companions")
	posting.placement_kind = "planet" // BOUNTY_PLACEMENT_PLANET
	var/datum/criminal_bounty/runner = board_test_posting() // a meek criminal
	var/datum/criminal_bounty/heavy = board_test_posting(tier = 3, archetype = "boss") // BOUNTY_TIER_MOST_WANTED, BOUNTY_ARCHETYPE_BOSS
	for(var/i in 1 to 20)
		TEST_ASSERT(!length(runner.board_roll_company()), "A meek criminal rolled companions")
		TEST_ASSERT(!length(heavy.board_roll_company()), "A mini-boss rolled companions")
	TEST_ASSERT_NULL(runner.board_company_text(), "A meek criminal is seen with someone")

	// Kept at its site, and rolled again for a new one
	var/obj/structure/overmap/ship/first_site = board_test_ship()
	var/obj/structure/overmap/ship/second_site = board_test_ship()
	posting.site_ref = WEAKREF(first_site)
	var/list/kept = posting.board_company()
	TEST_ASSERT(posting.board_company() == kept, "The company changed while the bounty stayed at its site")
	posting.site_ref = WEAKREF(second_site)
	TEST_ASSERT(posting.board_company() != kept, "A new site didn't roll a new company")
	posting.site_ref = null

	// The company the posting rolled is who spawns, through the human NPC queue
	var/datum/criminal_bounty/gang_posting = board_test_posting(archetype = "normal") // BOUNTY_ARCHETYPE_NORMAL
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = spawn_bounty_criminal(gang_posting.record, run_loc_floor_bottom_left, gang_posting)
	TEST_ASSERT_NOTNULL(criminal, "Test fixture: no criminal")
	allocated += criminal
	criminal.ai_controller.set_ai_status(AI_STATUS_OFF)
	gang_posting.criminal_ref = WEAKREF(criminal)
	criminal.posting_ref = WEAKREF(gang_posting)
	gang_posting.board_company = list(bounty_test_company_member("revolver", list("deadeye")), bounty_test_company_member("club")) // BOUNTY_STYLE_REVOLVER, BOUNTY_CHROME_DEADEYE, BOUNTY_STYLE_CLUB
	gang_posting.board_spawn_companions(criminal)
	// Queued for the human NPC queue: built here and now, as the queue would build them (a test room has no zone to wait for)
	var/list/datum/human_npc_order/orders = list()
	for(var/datum/human_npc_order/order as anything in SShuman_npcs.queue)
		var/datum/npc_spawn_context/bounty_company/context = order.context
		if(istype(context) && context.company_leader_ref?.resolve() == criminal)
			orders += order
	TEST_ASSERT_EQUAL(length(orders), 2, "The posting queued [length(orders)] companions, not its company of two")
	for(var/datum/human_npc_order/order as anything in orders)
		order.fulfil()
		qdel(order)
	var/list/buddies = criminal.ai_companions()
	allocated += buddies
	TEST_ASSERT_EQUAL(length(buddies), 2, "The posting's company didn't spawn")
	var/list/styles = list()
	for(var/mob/living/carbon/human/npc/bounty_companion/buddy as anything in buddies)
		buddy.ai_controller.set_ai_status(AI_STATUS_OFF)
		styles += buddy.ai_style
		TEST_ASSERT(WEAKREF(buddy) in gang_posting.companions, "A spawned companion isn't on the posting's list")
		var/has_deadeye = !!buddy.get_organ_by_type(/obj/item/organ/eyes/robotic/cyberware/deadeye)
		TEST_ASSERT_EQUAL(has_deadeye, buddy.ai_style == "revolver", "The [buddy.ai_style] companion's chrome isn't the company's")
	TEST_ASSERT(("revolver" in styles) && ("club" in styles), "The company spawned as [jointext(styles, ", ")], not the revolver and the club")
