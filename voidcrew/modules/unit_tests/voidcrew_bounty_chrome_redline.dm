/**
 * Redline core on a bounty NPC (voidcrew/modules/bounties/chrome/bounty_chrome_redline.dm): the AI picks
 * the moment and tells it, then everything is the player implant's (ware_legend.dm). Real human NPCs,
 * real implants, real timers; the AI is switched off so the test drives the chrome. Fork defines are
 * included after the tests, so literals carry a comment naming theirs.
 */

/// A Wanted brawler with a Redline core in, fighting `hunter`, its AI off and its chrome ready to move. Returns the criminal.
/datum/unit_test/voidcrew_bounty_chrome/proc/redliner(mob/living/hunter, archetype = "normal", kit)
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, archetype, "brawler", kit, list("redline"))) // BOUNTY_TIER_WANTED, BOUNTY_CHROME_REDLINE
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	if(hunter && archetype != "boss") // BOUNTY_ARCHETYPE_BOSS
		criminal.ai_start_fight(hunter)
	var/datum/component/bounty_chrome/chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	chrome_ai?.update_fight()
	if(chrome_ai)
		chrome_ai.next_move_at = 0
	return criminal

/// Hurts `criminal` with brute until it is at or under three quarters of its health, on its feet
/datum/unit_test/voidcrew_bounty_chrome/proc/hurt_to_redline(mob/living/carbon/human/npc/bounty_criminal/criminal)
	for(var/i in 1 to 10)
		if(criminal.health <= criminal.maxHealth * 0.7)
			break
		criminal.adjustBruteLoss(10)
	criminal.updatehealth()

/// Hurt in a fight, it tells for a second (standing still, outlined), then the implant's own burn: stun immunity, physiology, the roar on the hunter, red eyes; after the implant's 12 seconds, the crash floors it in stamina crit
/datum/unit_test/voidcrew_bounty_chrome/redline_burn

/datum/unit_test/voidcrew_bounty_chrome/redline_burn/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = redliner(hunter)
	TEST_ASSERT(locate(/obj/item/organ/cyberimp/cyberware/redline) in criminal.organs, "The criminal has no Redline core in it")
	var/datum/component/bounty_chrome/chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/redline/move = chrome_ai?.move_of(/datum/bounty_chrome_move/redline)
	TEST_ASSERT_NOTNULL(move, "A Redline carrier has no Redline move")
	TEST_ASSERT(!move.can_start(hunter), "An unhurt criminal burns its Redline")
	TEST_ASSERT_NULL(chrome_ai.plan(criminal.ai_controller, 1), "An unhurt criminal started a chrome move")

	hurt_to_redline(criminal)
	TEST_ASSERT(criminal.stat == CONSCIOUS && criminal.health <= criminal.maxHealth * 0.75, "The criminal wasn't hurt to three quarters on its feet (health [criminal.health])")
	TEST_ASSERT(move.can_start(hunter), "A hurt criminal in a fight won't burn its Redline")
	var/brute_mod_before = criminal.physiology.brute_mod
	TEST_ASSERT_EQUAL(chrome_ai.plan(criminal.ai_controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "The Redline didn't start")
	TEST_ASSERT_EQUAL(chrome_ai.telling, move, "The Redline's tell isn't running")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "The criminal doesn't stand still through the tell") // BOUNTY_CHROME_TRAIT
	TEST_ASSERT_NOTNULL(criminal.get_filter(move.tell_filter()), "The tell has no outline")
	sleep(0.7 SECONDS)
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_window), "The burn started before the tell's 0.8 seconds were up") // BOUNTY_CHROME_TELL_MIN
	sleep(0.5 SECONDS)

	// The implant's own window
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_window), "The tell ended but the implant's burn didn't start")
	TEST_ASSERT(HAS_TRAIT(criminal, TRAIT_STUNIMMUNE), "The burn gives no stun immunity")
	TEST_ASSERT(criminal.physiology.brute_mod < brute_mod_before * 0.61, "The burn didn't cut brute through the physiology ([brute_mod_before] to [criminal.physiology.brute_mod])")
	TEST_ASSERT_NOTNULL(hunter.has_status_effect(/datum/status_effect/staggered), "The roar didn't stagger the hunter in the fight")
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/bounty_redline_eyes), "Its eyes didn't go red for the burn")
	TEST_ASSERT_EQUAL(criminal.get_left_eye_color(), "#ff2a2a", "Its eyes aren't red through the burn")
	TEST_ASSERT(!move.ready(), "The implant isn't cooling down after the burn")
	TEST_ASSERT_NULL(criminal.get_filter(move.tell_filter()), "The tell's outline stayed on")
	criminal.Paralyze(3 SECONDS)
	TEST_ASSERT(!criminal.IsParalyzed(), "A stun landed in the burn")

	// The implant's 12 seconds from the end of the tell, then the crash
	sleep(12.4 SECONDS)
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_window), "The burn outlasted the implant's 12 seconds")
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_crash), "No crash after the burn")
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "The crash didn't floor it in stamina crit")
	TEST_ASSERT_EQUAL(criminal.capture_state(), "stunned", "The crash isn't a stunned capture") // BOUNTY_STATE_STUNNED
	TEST_ASSERT(!HAS_TRAIT(criminal, TRAIT_STUNIMMUNE), "Stun immunity outlasted the burn")
	TEST_ASSERT_EQUAL(criminal.physiology.brute_mod, brute_mod_before, "The physiology didn't go back after the burn")
	sleep(0.6 SECONDS)
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/bounty_redline_eyes), "Its eyes stayed red after the burn")
	TEST_ASSERT_NOTEQUAL(criminal.get_left_eye_color(), "#ff2a2a", "Its eyes stayed red after the burn")

/// Winded by stamina it burns too; with someone outside the fight in the roar's reach it doesn't start, and someone stepping in during the tell keeps the button unpressed; its own companion does neither, and the roar spares it
/datum/unit_test/voidcrew_bounty_chrome/redline_gate

/datum/unit_test/voidcrew_bounty_chrome/redline_gate/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = redliner(hunter)
	var/datum/component/bounty_chrome/chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/redline/move = chrome_ai.move_of(/datum/bounty_chrome_move/redline)
	criminal.adjustStaminaLoss(60)
	TEST_ASSERT(bounty_redline_hurt(criminal), "Winded to 60 stamina doesn't count")
	TEST_ASSERT(move.can_start(hunter), "A winded criminal won't burn its Redline")

	// A bystander a few tiles off, in the roar's reach
	var/mob/living/carbon/human/bystander = make_person(spot(1, 2))
	TEST_ASSERT(!move.can_start(hunter), "It burns its Redline with a bystander in the roar's reach")
	bystander.forceMove(run_loc_floor_top_right)
	var/far = get_dist(criminal, bystander) > 5 // BOUNTY_REDLINE_ROAR_RANGE
	if(far)
		TEST_ASSERT(move.can_start(hunter), "A bystander out of the roar's reach keeps the Redline shut")

	// Someone steps in during the tell: the button stays unpressed
	TEST_ASSERT(chrome_ai.start_move(move, hunter), "The tell didn't start")
	bystander.forceMove(spot(1, 2))
	sleep(1.2 SECONDS)
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_window), "It roared at a bystander who stepped in during the tell")
	TEST_ASSERT_NULL(bystander.has_status_effect(/datum/status_effect/staggered), "The bystander was staggered")
	TEST_ASSERT(move.ready(), "The unpressed burn still went on cooldown")

	// Its own companion in the roar's reach doesn't hold it back, and the roar spares it
	qdel(bystander)
	var/datum/human_npc_order/order = bounty_spawn_companion(criminal, spot(1, 2), null, TRUE, bounty_test_company_member("brawler", null)) // BOUNTY_STYLE_BRAWLER
	var/mob/living/carbon/human/npc/bounty_companion/buddy = order?.spawned_ref?.resolve()
	qdel(order)
	TEST_ASSERT_NOTNULL(buddy, "Test fixture: no companion was made")
	allocated += buddy
	buddy.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(move.can_start(hunter), "Its own companion in the roar's reach keeps the Redline shut")
	TEST_ASSERT(chrome_ai.start_move(move, hunter), "The tell didn't start with its companion near")
	sleep(1.2 SECONDS)
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_window), "It didn't burn with only its companion near")
	TEST_ASSERT_NULL(buddy.has_status_effect(/datum/status_effect/staggered), "The roar staggered its own companion")

/// An EMP in the tell fires nothing; one in the burn drops it straight into the implant's crash and back on its cooldown
/datum/unit_test/voidcrew_bounty_chrome/redline_emp

/datum/unit_test/voidcrew_bounty_chrome/redline_emp/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = redliner(hunter)
	var/datum/component/bounty_chrome/chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/redline/move = chrome_ai.move_of(/datum/bounty_chrome_move/redline)
	hurt_to_redline(criminal)
	TEST_ASSERT(chrome_ai.start_move(move, hunter), "The tell didn't start")
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_NULL(chrome_ai.telling, "An EMP didn't cut the tell short")
	sleep(1.2 SECONDS)
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_window), "It burned through an EMP in the tell")
	qdel(criminal)

	criminal = redliner(hunter)
	chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	move = chrome_ai.move_of(/datum/bounty_chrome_move/redline)
	hurt_to_redline(criminal)
	TEST_ASSERT(chrome_ai.start_move(move, hunter), "The second tell didn't start")
	sleep(1.2 SECONDS)
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_window), "The second burn didn't start")
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_window), "An EMP in the burn didn't end it")
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/cyberware_redline_crash), "An EMP in the burn didn't crash it")
	TEST_ASSERT(!move.ready(), "The Redline is ready again straight after an EMP crash")
	sleep(0.6 SECONDS)
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/bounty_redline_eyes), "Its eyes stayed red after the EMP crash")

/// A mini-boss with a Redline core uses it through its ability rotation, only once it is hurt
/datum/unit_test/voidcrew_bounty_chrome/redline_boss

/datum/unit_test/voidcrew_bounty_chrome/redline_boss/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = redliner(null, "boss", "pyromaniac") // BOUNTY_KIT_PYROMANIAC
	TEST_ASSERT(istype(boss), "No Pyromaniac spawned")
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability
	for(var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/found in boss.boss_abilities)
		if(istype(found.move, /datum/bounty_chrome_move/redline))
			ability = found
	TEST_ASSERT_NOTNULL(ability, "The Pyromaniac's Redline isn't in its ability rotation")
	boss.body_add_grudge(hunter)
	boss.boss_turn_hostile(hunter)
	TEST_ASSERT(!ability.worth_using(hunter), "An unhurt mini-boss reaches for its Redline")
	hurt_to_redline(boss)
	TEST_ASSERT(ability.worth_using(hunter), "A hurt mini-boss won't use its Redline")
	TEST_ASSERT(ability.windup >= 0.8 SECONDS, "The mini-boss's Redline winds up for [ability.windup / 10] s") // BOUNTY_CHROME_TELL_MIN
