/**
 * Lazarus on a bounty NPC: nothing to drive. The player node (ware_military_body.dm) fires itself when its
 * bearer goes into crit, with its red lightning (ware_lazarus_lightning.dm) through the charge. These run
 * the node's real timers on a real human NPC, and on a plain human as a player would be.
 *
 * Renders: compile with -DBOUNTY_CHROME_RENDERS and lazarus_jolt writes the criminal's body, plain and
 * with the charge's lightning over it, to data/bounty_chrome_renders/.
 */

/// Puts `body` down in crit with brute, as a beating would: on the floor, short of death
/datum/unit_test/voidcrew_bounty_chrome/proc/beat_down(mob/living/carbon/body)
	for(var/i in 1 to 30)
		if(body.stat != CONSCIOUS)
			break
		body.adjustBruteLoss(10)
		body.updatehealth()

/// The node stands a criminal beaten into crit back up after its real one second charge, red lightning crawling over it meanwhile; cuffs put on mid-charge stay on, so it stands up cuffed; and it does it once in six minutes
/datum/unit_test/voidcrew_bounty_chrome/lazarus_jolt

/datum/unit_test/voidcrew_bounty_chrome/lazarus_jolt/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler", null, list("lazarus"))) // BOUNTY_TIER_WANTED, BOUNTY_CHROME_LAZARUS
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/obj/item/organ/cyberimp/cyberware/lazarus/node = locate() in criminal.organs
	TEST_ASSERT_NOTNULL(node, "The criminal has no Lazarus node in it")
#ifdef BOUNTY_CHROME_RENDERS
	fcopy(getFlatIcon(criminal, SOUTH, no_anim = TRUE), "data/bounty_chrome_renders/lazarus_body.png")
	var/list/render_arcs = cyberware_lazarus_body_arcs(null)
	criminal.add_overlay(render_arcs)
	fcopy(getFlatIcon(criminal, SOUTH, no_anim = TRUE), "data/bounty_chrome_renders/lazarus_body_charging.png")
	criminal.cut_overlay(render_arcs)
#endif

	beat_down(criminal)
	TEST_ASSERT(criminal.is_downed(), "The beating didn't put the criminal in crit (health [criminal.health])")
	TEST_ASSERT(node.jolting, "Going into crit didn't start the node's charge")
	var/datum/status_effect/cyberware_lazarus_charge/charge = criminal.has_status_effect(/datum/status_effect/cyberware_lazarus_charge)
	TEST_ASSERT_NOTNULL(charge, "No red lightning while the node charges")
	TEST_ASSERT(length(charge.arcs), "The charge has no lightning over the body")
	TEST_ASSERT_NOTNULL(criminal.get_filter("lazarus_charge_outline"), "The charge has no red outline")
	TEST_ASSERT_EQUAL(criminal.capture_state(), "downed", "A criminal down and charging isn't downed for the pad") // BOUNTY_STATE_DOWNED

	// Cuffs go on mid-charge
	sleep(0.4 SECONDS)
	var/obj/item/restraints/handcuffs/cuffs = new(criminal)
	criminal.set_handcuffed(cuffs)
	criminal.update_handcuffed()
	TEST_ASSERT(criminal.is_restrained(), "The cuffs didn't go on")
	TEST_ASSERT_NOTNULL(criminal.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "The lightning stopped when the cuffs went on")
	sleep(0.9 SECONDS)
	TEST_ASSERT(!node.jolting, "The charge never fired")
	TEST_ASSERT_EQUAL(criminal.stat, CONSCIOUS, "The node didn't stand the criminal up (health [criminal.health])")
	// The node heals "to 30%" of the damage it counts, but a body's health counts limb damage at three quarters (updatehealth()), so it lands a little under
	TEST_ASSERT(criminal.health >= criminal.maxHealth * 0.15, "The node stood it up at only [criminal.health] health")
	TEST_ASSERT_EQUAL(criminal.handcuffed, cuffs, "The jolt took the cuffs off")
	TEST_ASSERT_EQUAL(criminal.capture_state(), "restrained", "A jolted criminal in cuffs isn't restrained for the pad") // BOUNTY_STATE_RESTRAINED
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "The lightning outlived the jolt")
	TEST_ASSERT_NULL(criminal.get_filter("lazarus_charge_outline"), "The charge's outline outlived the jolt")
	TEST_ASSERT(!COOLDOWN_FINISHED(node, jolt_cooldown), "The jolt didn't spend the node")
	// Out of crit it gets up as anyone does, in tg's get_up() second, cuffs and all
	TEST_ASSERT(!HAS_TRAIT(criminal, TRAIT_FLOORED), "The jolted criminal is still floored")
	sleep(1.5 SECONDS)
	TEST_ASSERT_EQUAL(criminal.body_position, STANDING_UP, "The jolted criminal never got up off the floor")

	// Once: down again within six minutes, it stays down
	beat_down(criminal)
	TEST_ASSERT(criminal.is_downed(), "The second beating didn't put the criminal in crit")
	TEST_ASSERT(!node.jolting, "The node charged twice in six minutes")
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "The spent node showed its lightning again")
	sleep(1.2 SECONDS)
	TEST_ASSERT(criminal.is_downed(), "The criminal got up a second time inside six minutes")

/// Killed outright, the node does nothing; killed mid-charge, the lightning goes at once and it stays dead
/datum/unit_test/voidcrew_bounty_chrome/lazarus_dead

/datum/unit_test/voidcrew_bounty_chrome/lazarus_dead/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler", null, list("lazarus")))
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	criminal.death()
	TEST_ASSERT_NULL(criminal.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "A criminal killed outright showed the node's lightning")
	sleep(1.2 SECONDS)
	TEST_ASSERT_EQUAL(criminal.stat, DEAD, "The node brought a dead criminal back")

	var/mob/living/carbon/human/npc/bounty_criminal/second = make_criminal(make_record(2, "normal", "brawler", null, list("lazarus")), spot(1, 1))
	second.ai_controller?.set_ai_status(AI_STATUS_OFF)
	beat_down(second)
	TEST_ASSERT_NOTNULL(second.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "The second criminal's node didn't charge")
	second.death()
	TEST_ASSERT_NULL(second.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "The lightning kept crawling over a corpse")
	TEST_ASSERT_NULL(second.get_filter("lazarus_charge_outline"), "A corpse kept the charge's outline")
	sleep(1.2 SECONDS)
	TEST_ASSERT_EQUAL(second.stat, DEAD, "The node brought back someone killed mid-charge")

/// The lightning is the player node's own: a plain human (a player) shows it and is stood up the same way; an EMP mid-charge cuts the charge and its lightning
/datum/unit_test/voidcrew_bounty_chrome/lazarus_player

/datum/unit_test/voidcrew_bounty_chrome/lazarus_player/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/organ/cyberimp/cyberware/lazarus/node = allocate(/obj/item/organ/cyberimp/cyberware/lazarus)
	TEST_ASSERT(node.Insert(patient, special = TRUE), "The node didn't go in")
	beat_down(patient)
	TEST_ASSERT(patient.stat == SOFT_CRIT || patient.stat == HARD_CRIT, "The beating didn't put the patient in crit")
	TEST_ASSERT_NOTNULL(patient.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "A player's node charges with no lightning")
	sleep(1.3 SECONDS)
	TEST_ASSERT_EQUAL(patient.stat, CONSCIOUS, "The node didn't stand the patient up")
	TEST_ASSERT_NULL(patient.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "The lightning outlived the player's jolt")

	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent, spot(3, 1))
	var/obj/item/organ/cyberimp/cyberware/lazarus/second_node = allocate(/obj/item/organ/cyberimp/cyberware/lazarus)
	TEST_ASSERT(second_node.Insert(second, special = TRUE), "The second node didn't go in")
	beat_down(second)
	TEST_ASSERT_NOTNULL(second.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "The second node charges with no lightning")
	second.emp_act(EMP_HEAVY)
	TEST_ASSERT(!second_node.jolting, "An EMP didn't cut the node's charge")
	sleep(0.7 SECONDS) // its next look, on the fast process (0.2 s)
	TEST_ASSERT_NULL(second.has_status_effect(/datum/status_effect/cyberware_lazarus_charge), "The lightning kept going after an EMP cut the charge")
	sleep(1 SECONDS)
	TEST_ASSERT(second.stat != CONSCIOUS && second.stat != DEAD, "A node cut by an EMP still stood the patient up")
