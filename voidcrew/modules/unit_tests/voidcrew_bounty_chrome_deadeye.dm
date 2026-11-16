/**
 * Deadeye link on a bounty gunman (voidcrew/modules/bounties/chrome/bounty_chrome_deadeye.dm): the AI's
 * opening lock and its tell, then the implant's own tag (ware_pro_combat.dm) homing its real rounds, and
 * letting go when the mark breaks line of sight. Real human NPCs, real implants and a real pistol.
 */

/// The test's record of the last round the gunman fired: the projectile, read after the optics have had their say
/datum/unit_test/voidcrew_bounty_chrome/var/obj/projectile/last_round

/datum/unit_test/voidcrew_bounty_chrome/proc/note_round(mob/living/source, obj/projectile/shot, datum/fired_from, atom/clicked)
	SIGNAL_HANDLER
	last_round = shot

/// A Petty pistol criminal with Deadeye optics, its AI off, fighting `hunter`. Returns the criminal.
/datum/unit_test/voidcrew_bounty_chrome/proc/deadeye_gunman(mob/living/hunter, style = "pistol") // BOUNTY_STYLE_PISTOL
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(1, "normal", style, null, list("deadeye"))) // BOUNTY_TIER_PETTY, BOUNTY_CHROME_DEADEYE
	criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	criminal.ai_start_fight(hunter)
	return criminal

/// Its opening lock comes half a second into the fight: a one second tell (red eyes, a red line, and it keeps acting), then the implant's tag on the hunter, and its next real rounds home in
/datum/unit_test/voidcrew_bounty_chrome/deadeye_lock

/datum/unit_test/voidcrew_bounty_chrome/deadeye_lock/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = deadeye_gunman(hunter)
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = criminal.get_organ_slot(ORGAN_SLOT_EYES)
	TEST_ASSERT(istype(optics), "The gunman has no Deadeye optics")
	var/datum/component/bounty_chrome/chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/deadeye/move = chrome_ai?.move_of(/datum/bounty_chrome_move/deadeye)
	TEST_ASSERT_NOTNULL(move, "A Deadeye carrier has no Deadeye move")
	var/eyes_before = criminal.get_left_eye_color()
	chrome_ai.update_fight()
	TEST_ASSERT_NULL(chrome_ai.telling, "The lock started the moment the fight did")
	sleep(0.7 SECONDS) // BOUNTY_DEADEYE_OPENING 0.5 seconds
	TEST_ASSERT_EQUAL(chrome_ai.telling, move, "The opening lock didn't start half a second into the fight")
	TEST_ASSERT_EQUAL(criminal.get_left_eye_color(), "#ff3300", "Its eyes didn't go red for the lock")
	TEST_ASSERT(length(move.marks), "The lock has no red line on the mark")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "The gunman stands still through its lock") // BOUNTY_CHROME_TRAIT
	TEST_ASSERT_NULL(chrome_ai.plan(criminal.ai_controller, 1), "The lock's tell stopped the gunman's other planning")
	TEST_ASSERT_NULL(optics.tagged_ref?.resolve(), "The tag landed before the tell was over")
	sleep(0.4 SECONDS)
	TEST_ASSERT_NULL(optics.tagged_ref?.resolve(), "The tag landed before the tell's 0.8 seconds were up") // BOUNTY_CHROME_TELL_MIN
	sleep(0.8 SECONDS)
	TEST_ASSERT_EQUAL(optics.tagged_ref?.resolve(), hunter, "The tell ended but the implant's tag isn't on the hunter")
	TEST_ASSERT_NOTNULL(hunter.get_filter("deadeye_mark"), "The hunter carries no reticle")
	TEST_ASSERT_EQUAL(criminal.get_left_eye_color(), "#ff3300", "Its eyes went back while the tag holds")
	TEST_ASSERT(!move.ready(), "The tag isn't cooling down")
	TEST_ASSERT_NULL(move.marks, "The red line outlived the tell")

	// A real round from a real pistol homes in
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(criminal.put_in_hands(gun), "The gunman couldn't hold the test pistol")
	RegisterSignal(criminal, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(note_round))
	gun.process_fire(hunter, criminal)
	UnregisterSignal(criminal, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)
	TEST_ASSERT_NOTNULL(last_round, "The pistol fired no round")
	TEST_ASSERT_EQUAL(last_round.homing_target, hunter, "The round didn't home in on the tagged hunter")
	TEST_ASSERT_EQUAL(optics.shots_left, 2, "The tag didn't count the homing round")
	last_round = null

	// The tag spent, it stops watching and its eyes go back
	optics.end_tag(criminal)
	sleep(0.6 SECONDS)
	TEST_ASSERT_NULL(move.mark_ref, "It kept watching a spent tag")
	TEST_ASSERT_EQUAL(criminal.get_left_eye_color(), eyes_before, "Its eyes stayed red after the tag")

/// Breaking line of sight lets the tag go, and one broken during the tell never lands; a melee style, a downed mark or a mark out of sight never gets one
/datum/unit_test/voidcrew_bounty_chrome/deadeye_sight
	/// The floor turned into a wall between them, and what it was, put back whatever happens
	var/turf/between
	var/floor_type

/datum/unit_test/voidcrew_bounty_chrome/deadeye_sight/Destroy()
	if(between && floor_type && between.type != floor_type)
		between.ChangeTurf(floor_type)
		restore_atmos()
	between = null
	return ..()

/datum/unit_test/voidcrew_bounty_chrome/deadeye_sight/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 0))
	between = spot(2, 0)
	floor_type = between.type
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = deadeye_gunman(hunter)
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = criminal.get_organ_slot(ORGAN_SLOT_EYES)
	var/datum/component/bounty_chrome/chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/deadeye/move = chrome_ai.move_of(/datum/bounty_chrome_move/deadeye)
	chrome_ai.update_fight()
	TEST_ASSERT(chrome_ai.start_move(move, hunter), "The lock didn't start")
	sleep(1.2 SECONDS)
	TEST_ASSERT_EQUAL(optics.tagged_ref?.resolve(), hunter, "The tag didn't land")
	// A wall between them
	between.ChangeTurf(/turf/closed/wall/r_wall)
	sleep(0.7 SECONDS) // BOUNTY_DEADEYE_WATCH 0.5 seconds
	TEST_ASSERT_NULL(optics.tagged_ref?.resolve(), "The tag held with a wall between them")
	TEST_ASSERT_NULL(hunter.get_filter("deadeye_mark"), "The reticle stayed on the hunter behind the wall")
	TEST_ASSERT_NOTEQUAL(criminal.get_left_eye_color(), "#ff3300", "Its eyes stayed red after it let go")
	between.ChangeTurf(floor_type)
	restore_atmos()
	qdel(criminal)

	// Line of sight broken during the tell: the implant refuses the tag
	criminal = deadeye_gunman(hunter)
	optics = criminal.get_organ_slot(ORGAN_SLOT_EYES)
	chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	move = chrome_ai.move_of(/datum/bounty_chrome_move/deadeye)
	chrome_ai.update_fight()
	TEST_ASSERT(chrome_ai.start_move(move, hunter), "The second lock didn't start")
	between.ChangeTurf(/turf/closed/wall/r_wall)
	sleep(1.2 SECONDS)
	TEST_ASSERT_NULL(optics.tagged_ref?.resolve(), "The tag landed through a wall")
	TEST_ASSERT_NOTEQUAL(criminal.get_left_eye_color(), "#ff3300", "Its eyes stayed red after the lock failed")
	TEST_ASSERT(move.ready(), "A tag that never landed went on cooldown")
	between.ChangeTurf(floor_type)
	restore_atmos()

	// A downed mark is never tagged
	hunter.adjustOxyLoss(hunter.health + 10)
	hunter.updatehealth()
	TEST_ASSERT(!move.can_start(hunter), "It would lock onto a hunter in crit")
	qdel(criminal)

	// A brawler given the optics (an admin's pick) has nothing to home
	var/mob/living/carbon/human/brawled = make_person(spot(4, 1))
	var/mob/living/carbon/human/npc/bounty_criminal/brawler = deadeye_gunman(brawled, "brawler") // BOUNTY_STYLE_BRAWLER
	var/datum/component/bounty_chrome/brawler_ai = brawler.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/deadeye/brawler_move = brawler_ai.move_of(/datum/bounty_chrome_move/deadeye)
	TEST_ASSERT(!brawler_move.can_start(brawled), "A brawler locks on with Deadeye")
	brawler_ai.update_fight()
	sleep(0.7 SECONDS)
	TEST_ASSERT_NULL(brawler_ai.telling, "A brawler's opening lock started")

/// Down or dead, it lets go of its tag and its eyes go back
/datum/unit_test/voidcrew_bounty_chrome/deadeye_downed

/datum/unit_test/voidcrew_bounty_chrome/deadeye_downed/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = deadeye_gunman(hunter)
	var/obj/item/organ/eyes/robotic/cyberware/deadeye/optics = criminal.get_organ_slot(ORGAN_SLOT_EYES)
	var/datum/component/bounty_chrome/chrome_ai = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/deadeye/move = chrome_ai.move_of(/datum/bounty_chrome_move/deadeye)
	chrome_ai.update_fight()
	TEST_ASSERT(chrome_ai.start_move(move, hunter), "The lock didn't start")
	sleep(1.2 SECONDS)
	TEST_ASSERT_EQUAL(optics.tagged_ref?.resolve(), hunter, "The tag didn't land")
	beat_down(criminal)
	TEST_ASSERT(criminal.is_downed(), "The gunman didn't go down")
	TEST_ASSERT_NULL(optics.tagged_ref?.resolve(), "A downed gunman kept its tag")
	TEST_ASSERT_NULL(hunter.get_filter("deadeye_mark"), "The reticle stayed on the hunter when the gunman went down")
	TEST_ASSERT_NOTEQUAL(criminal.get_left_eye_color(), "#ff3300", "A downed gunman's eyes stayed red")
	criminal.death()
	TEST_ASSERT_NULL(move.mark_ref, "A dead gunman kept watching a tag")
