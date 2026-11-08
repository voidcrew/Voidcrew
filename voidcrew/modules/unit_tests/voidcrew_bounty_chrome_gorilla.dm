/**
 * Gorilla Arms on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_gorilla.dm). Every
 * test drives the piece's procs directly with the mobs in place: none waits on its timers or an AI
 * walk. Fork defines are included after the tests, so a test uses the literal value with a comment
 * naming the define. The test room is a 5x5 floor.
 */
/datum/unit_test/voidcrew_bounty_chrome_gorilla
	abstract_type = /datum/unit_test/voidcrew_bounty_chrome_gorilla
	/// Turfs a test changed, put back to plain floor when it ends
	var/list/turf/changed_turfs = list()
	/// Turf -> the area it had before a test moved it into a ship's area
	var/list/original_areas = list()
	/// Areas a test made
	var/list/test_areas = list()

/datum/unit_test/voidcrew_bounty_chrome_gorilla/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	for(var/turf/moved as anything in original_areas)
		moved.change_area(get_area(moved), original_areas[moved])
	original_areas = null
	QDEL_LIST(test_areas)
	return ..()

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_bounty_chrome_gorilla/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A hunter at `where`: a human with a mind, as a player would be
/datum/unit_test/voidcrew_bounty_chrome_gorilla/proc/hunter_at(turf/where)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, where)
	hunter.mind_initialize()
	return hunter

/// Changes `where` to `new_type`, put back when the test ends
/datum/unit_test/voidcrew_bounty_chrome_gorilla/proc/change_turf(turf/where, new_type)
	changed_turfs |= where
	return where.ChangeTurf(new_type)

/// Makes `where` part of a ship (a player's), put back when the test ends
/datum/unit_test/voidcrew_bounty_chrome_gorilla/proc/make_ship_tile(turf/where)
	var/area/shuttle/ship_area = new()
	test_areas += ship_area
	original_areas[where] = get_area(where)
	where.change_area(get_area(where), ship_area)
	return where

/// A normal brawler at `where` with Gorilla Arms, fighting `hunter`, its first punch ready
/datum/unit_test/voidcrew_bounty_chrome_gorilla/proc/gorilla_at(turf/where, mob/living/hunter)
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, where)
	bounty_chrome_install(criminal, list("gorilla")) // BOUNTY_CHROME_GORILLA
	if(hunter)
		criminal.ai_start_fight(hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	if(piece)
		piece.punch_ready_at = 0
	return criminal

/// It rolls on brawlers, brawler companions and the Juggernaut, and nowhere else
/datum/unit_test/voidcrew_bounty_chrome_gorilla/rolls

/datum/unit_test/voidcrew_bounty_chrome_gorilla/rolls/Run()
	var/datum/bounty_chrome/gorilla/proto = GLOB.bounty_chrome_protos["gorilla"] // BOUNTY_CHROME_GORILLA
	TEST_ASSERT_NOTNULL(proto, "No Gorilla Arms prototype")
	TEST_ASSERT(proto.weight > 0, "Gorilla Arms never rolls")
	// BOUNTY_TIER_PETTY 1, BOUNTY_TIER_WANTED 2, BOUNTY_TIER_MOST_WANTED 3
	TEST_ASSERT(proto.can_roll(1, "normal", "brawler", null, list()), "A Petty brawler can't roll Gorilla Arms")
	TEST_ASSERT(proto.can_roll(1, "companion", "brawler", null, list()), "A brawler companion can't roll Gorilla Arms") // BOUNTY_CHROME_COMPANION
	TEST_ASSERT(proto.can_roll(3, "boss", null, "juggernaut", list()), "A Juggernaut can't roll Gorilla Arms") // BOUNTY_KIT_JUGGERNAUT
	for(var/style in list("knife", "club", "pistol", "smg", "revolver", "shotgun", "bottle"))
		TEST_ASSERT(!proto.can_roll(2, "normal", style, null, list()), "A [style] criminal can roll Gorilla Arms")
		TEST_ASSERT(!proto.can_roll(2, "companion", style, null, list()), "A [style] companion can roll Gorilla Arms")
	TEST_ASSERT(!proto.can_roll(2, "meek", "holdout", null, list()), "A meek criminal can roll Gorilla Arms")
	for(var/kit in list("pyromaniac", "demolitionist", "ghost", "heavy"))
		TEST_ASSERT(!proto.can_roll(3, "boss", null, kit, list()), "A [kit] mini-boss can roll Gorilla Arms")
	TEST_ASSERT(!proto.can_roll(2, "normal", "brawler", null, list("mantis")), "Gorilla Arms can roll alongside Mantis Blades") // BOUNTY_CHROME_MANTIS

	// Real picks: it turns up on brawlers, never on a gunman or the Ghost
	var/rolled = FALSE
	for(var/i in 1 to 200)
		if("gorilla" in bounty_pick_chrome(1, 1, "normal", "brawler", null))
			rolled = TRUE
			break
	TEST_ASSERT(rolled, "200 picks for a brawler never gave Gorilla Arms")
	for(var/i in 1 to 100)
		TEST_ASSERT(!("gorilla" in bounty_pick_chrome(1, 2, "normal", "pistol", null)), "A pistol criminal was given Gorilla Arms")
		TEST_ASSERT(!("gorilla" in bounty_pick_chrome(1, 3, "boss", null, "ghost")), "The Ghost was given Gorilla Arms")

/// The wind-up, then the punch: hurt, staggered and thrown back, and the light and the rooting gone
/datum/unit_test/voidcrew_bounty_chrome_gorilla/punch

/datum/unit_test/voidcrew_bounty_chrome_gorilla/punch/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), null)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	TEST_ASSERT_NOTNULL(piece, "The installed piece can't be found")
	TEST_ASSERT(criminal.ai_start_fight(hunter), "The criminal wouldn't fight the hunter")
	TEST_ASSERT(piece.punch_ready_at > world.time, "The first punch can come the moment the fight starts")
	TEST_ASSERT(!piece.start_punch(hunter), "A punch wound up inside the fight's opening")
	piece.punch_ready_at = 0

	TEST_ASSERT(piece.start_punch(hunter), "No punch wound up at the hunter beside them")
	TEST_ASSERT_EQUAL(piece.busy, "punch", "Winding up, it isn't busy punching") // BOUNTY_GORILLA_PUNCH
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Winding up, they can still walk") // BOUNTY_GORILLA_TRAIT
	TEST_ASSERT(criminal.next_move > world.time, "Winding up, they can still throw ordinary blows")
	TEST_ASSERT(locate(/obj/effect/temp_visual/bounty_boss_mark) in tile(2, 2), "No light on the hunter's tile")
	TEST_ASSERT(LAZYACCESS(criminal.filter_data, "bounty_gorilla_glow"), "No glow on them while they wind up") // BOUNTY_GORILLA_GLOW
	TEST_ASSERT(!piece.start_punch(hunter), "A second punch wound up over the first")

	var/turf/start = get_turf(hunter)
	TEST_ASSERT(piece.finish_punch(piece.serial), "The punch missed a hunter who stood still")
	TEST_ASSERT(hunter.getBruteLoss() > 0, "The punch did no harm")
	TEST_ASSERT(hunter.has_status_effect(/datum/status_effect/staggered), "Punched, the hunter isn't staggered")
	TEST_ASSERT(hunter.throwing || get_turf(hunter) != start, "The punch didn't throw the hunter back")
	TEST_ASSERT_NULL(piece.busy, "Still busy after the punch")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Still rooted after the punch")
	TEST_ASSERT(!LAZYACCESS(criminal.filter_data, "bounty_gorilla_glow"), "Still glowing after the punch")
	TEST_ASSERT_NULL(locate(/obj/effect/temp_visual/bounty_boss_mark) in tile(2, 2), "The light stayed after the punch")
	TEST_ASSERT(piece.punch_ready_at > world.time, "No wait before the next punch")

/// Stepping off the lit tile: the punch hits air and they stumble; someone down on it isn't hit at all
/datum/unit_test/voidcrew_bounty_chrome_gorilla/whiff

/datum/unit_test/voidcrew_bounty_chrome_gorilla/whiff/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	TEST_ASSERT(piece.start_punch(hunter), "No punch wound up")
	hunter.forceMove(tile(4, 4))
	TEST_ASSERT(!piece.finish_punch(piece.serial), "The punch landed on a hunter who stepped away")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "A hunter who stepped away was hurt")
	TEST_ASSERT_EQUAL(piece.busy, "stumble", "Punching air, they didn't stumble") // BOUNTY_GORILLA_STUMBLE
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Stumbling, they can still walk")
	TEST_ASSERT(criminal.next_move > world.time, "Stumbling, they can still swing")
	piece.end_stumble(piece.serial)
	TEST_ASSERT_NULL(piece.busy, "The stumble never ended")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Still rooted after the stumble")

	// Down on the tile when it lands, the punch is pulled: no hit, no stumble
	hunter.forceMove(tile(2, 2))
	piece.punch_ready_at = 0
	criminal.next_move = 0
	TEST_ASSERT(piece.start_punch(hunter), "No second punch wound up")
	hunter.death()
	TEST_ASSERT(!piece.finish_punch(piece.serial), "The punch landed on someone dead")
	TEST_ASSERT_NULL(piece.busy, "Pulling the punch, they stumbled anyway")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The pulled punch hurt the body")

/// With a wall behind them, the hunter is driven into it and knocked flat instead of thrown
/datum/unit_test/voidcrew_bounty_chrome_gorilla/pinned

/datum/unit_test/voidcrew_bounty_chrome_gorilla/pinned/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	change_turf(tile(3, 2), /turf/closed/wall)
	TEST_ASSERT(bounty_gorilla_backstop(hunter, EAST), "The wall behind the hunter isn't seen")
	TEST_ASSERT(piece.start_punch(hunter), "No punch wound up")
	TEST_ASSERT(piece.finish_punch(piece.serial), "The punch didn't land")
	TEST_ASSERT(hunter.IsKnockdown(), "Driven into the wall, the hunter stayed up")
	TEST_ASSERT_EQUAL(get_turf(hunter), tile(2, 2), "The hunter went through the wall")

/// An EMP: mid-punch they go down at once; otherwise their next swing seizes; it passes with the reboot
/datum/unit_test/voidcrew_bounty_chrome_gorilla/emp

/datum/unit_test/voidcrew_bounty_chrome_gorilla/emp/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)

	TEST_ASSERT(piece.start_punch(hunter), "No punch wound up")
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT(criminal.IsKnockdown(), "EMP'd mid-punch, they stayed up")
	TEST_ASSERT_NULL(piece.busy, "EMP'd mid-punch, the punch still waits to land")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "EMP'd mid-punch, they stay rooted")
	TEST_ASSERT(!piece.seized, "The punch that seized still waits on their next swing")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The EMP'd punch landed")

	// Back up and rebooted
	criminal.SetKnockdown(0)
	piece.offline_until = world.time
	chrome.tick(2)
	TEST_ASSERT(piece.online(), "The piece never came back from the EMP")

	// EMP'd between punches, their next swing seizes
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT(piece.seized, "EMP'd between punches, nothing waits on their next swing")
	TEST_ASSERT(!criminal.melee_attack(hunter), "An EMP'd swing still landed")
	TEST_ASSERT(criminal.IsKnockdown(), "The EMP'd swing didn't put them down")
	TEST_ASSERT(!piece.seized, "A second swing would seize too")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The seized swing hurt the hunter")

	// The seizure passes with the reboot
	criminal.SetKnockdown(0)
	piece.offline_until = world.time
	chrome.tick(2)
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT(piece.seized, "A third EMP didn't seize their arms")
	piece.offline_until = world.time
	chrome.tick(2)
	TEST_ASSERT(!piece.seized, "Rebooted, their arms still seize")

/// Doors: forced when the hunter is behind one; a bolted one holds and is left alone; never a ship's, never one onto space
/datum/unit_test/voidcrew_bounty_chrome_gorilla/doors

/datum/unit_test/voidcrew_bounty_chrome_gorilla/doors/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(3, 2))
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	TEST_ASSERT(door.density, "The test's door isn't shut")
	TEST_ASSERT(!can_see(criminal, hunter, 9), "The test's door doesn't hide the hunter")
	TEST_ASSERT(bounty_gorilla_door_holds_air(door), "A door between two rooms of air counts as a breach")
	TEST_ASSERT(piece.check_doors(), "With the hunter behind the door, they didn't go for it")
	TEST_ASSERT_EQUAL(piece.busy, "pry", "Going for the door, they aren't prying it") // BOUNTY_GORILLA_PRY
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Prying, they can still walk")
	TEST_ASSERT(piece.finish_pry(piece.serial), "The pry didn't open the door")
	TEST_ASSERT_NULL(piece.busy, "Still prying after the door gave")
	sleep(2 SECONDS) // the door's opening animation
	TEST_ASSERT(!door.density, "The forced door is still shut")

	// A bolted door holds, and they leave it alone afterwards
	criminal.forceMove(tile(1, 0))
	hunter.forceMove(tile(3, 0))
	var/obj/machinery/door/airlock/bolted = allocate(/obj/machinery/door/airlock, tile(2, 0))
	bolted.bolt()
	TEST_ASSERT(piece.check_doors(), "They didn't try the bolted door")
	TEST_ASSERT(!piece.finish_pry(piece.serial), "The bolted door gave")
	TEST_ASSERT(bolted.density, "The bolted door opened")
	TEST_ASSERT(!piece.check_doors(), "They went straight back to a door that held")

	// Never a ship's door
	bolted.unbolt()
	piece.held_doors = null
	TEST_ASSERT(piece.door_may_force(bolted), "With the bolts up, they won't try the door again")
	make_ship_tile(tile(2, 0))
	TEST_ASSERT(!piece.door_may_force(bolted), "They would force a ship's door")

	// Never one with space beside it
	change_turf(tile(2, 1), /turf/open/space/basic)
	TEST_ASSERT(!bounty_gorilla_door_holds_air(bolted), "A door onto space counts as safe to force")

/// Dead, downed or with the chrome removed mid-punch: nothing lands, and nothing is left on them
/datum/unit_test/voidcrew_bounty_chrome_gorilla/cleanup

/datum/unit_test/voidcrew_bounty_chrome_gorilla/cleanup/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	TEST_ASSERT(piece.start_punch(hunter), "No punch wound up")
	var/old_serial = piece.serial
	criminal.death()
	TEST_ASSERT_NULL(piece.busy, "Dead, they are still winding up")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Dead, the chrome still roots them")
	TEST_ASSERT(!piece.finish_punch(old_serial), "A dead criminal's punch landed")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "A dead criminal's punch hurt someone")

	// Downed mid-punch
	var/mob/living/basic/bounty_criminal/normal/second = gorilla_at(tile(1, 3), null)
	second.ai_start_fight(hunter)
	var/datum/bounty_chrome/gorilla/second_piece = bounty_chrome_piece(second, "gorilla")
	second_piece.punch_ready_at = 0
	hunter.forceMove(tile(2, 3))
	TEST_ASSERT(second_piece.start_punch(hunter), "No punch wound up on the second criminal")
	var/datum/component/bounty_chrome/second_chrome = second.GetComponent(/datum/component/bounty_chrome)
	second_chrome.downed()
	TEST_ASSERT_NULL(second_piece.busy, "Downed, they are still winding up")
	TEST_ASSERT(!HAS_TRAIT_FROM(second, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Downed, the chrome still roots them")

	// The chrome taken out mid-punch
	second_piece.punch_ready_at = 0
	second.next_move = 0
	TEST_ASSERT(second_piece.start_punch(hunter), "No punch wound up after the downed test")
	qdel(second_chrome)
	TEST_ASSERT_NULL(second_piece.owner, "A removed piece kept its owner")
	TEST_ASSERT(!HAS_TRAIT_FROM(second, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "With the chrome gone, they stay rooted")
	TEST_ASSERT(!LAZYACCESS(second.filter_data, "bounty_gorilla_glow"), "With the chrome gone, they still glow")
	TEST_ASSERT_NULL(locate(/obj/effect/temp_visual/bounty_boss_mark) in tile(2, 3), "With the chrome gone, the light stays")

/// On the Juggernaut: its punch keeps it busy and pushes back its abilities, a stun cuts it off, and an EMP'd swing makes it reel
/datum/unit_test/voidcrew_bounty_chrome_gorilla/juggernaut

/datum/unit_test/voidcrew_bounty_chrome_gorilla/juggernaut/Run()
	var/mob/living/basic/bounty_criminal/boss/juggernaut/boss = allocate(/mob/living/basic/bounty_criminal/boss/juggernaut, tile(1, 1))
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 1))
	bounty_chrome_install(boss, list("gorilla"))
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(boss, "gorilla")
	TEST_ASSERT_NOTNULL(piece, "The Juggernaut's piece can't be found")
	boss.boss_hostile = TRUE
	boss.boss_next_ability_at = 0
	piece.punch_ready_at = 0
	TEST_ASSERT(piece.start_punch(hunter), "The Juggernaut didn't wind up a punch")
	TEST_ASSERT_EQUAL(boss.boss_busy, "gorilla", "Winding up a punch, the Juggernaut isn't busy") // BOUNTY_GORILLA_BOSS_BUSY
	TEST_ASSERT(boss.boss_next_ability_at > world.time, "The punch didn't push back the Juggernaut's next ability")
	TEST_ASSERT(piece.finish_punch(piece.serial), "The Juggernaut's punch didn't land")
	TEST_ASSERT_NULL(boss.boss_busy, "The Juggernaut is still busy after its punch")
	TEST_ASSERT(hunter.getBruteLoss() > 0, "The Juggernaut's punch did no harm")

	// Cut off mid-punch: nothing lands
	var/mob/living/carbon/human/consistent/second = hunter_at(tile(1, 2))
	boss.boss_next_ability_at = 0
	piece.punch_ready_at = 0
	boss.next_move = 0
	TEST_ASSERT(piece.start_punch(second), "The Juggernaut didn't wind up a second punch")
	boss.boss_interrupt()
	TEST_ASSERT(!piece.finish_punch(piece.serial), "A punch the Juggernaut was knocked out of still landed")
	TEST_ASSERT_EQUAL(second.getBruteLoss(), 0, "The cut-off punch hurt someone")
	TEST_ASSERT(!HAS_TRAIT_FROM(boss, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Cut off, the Juggernaut stays rooted")

	// EMP'd, its next swing makes it reel, open to damage
	boss.emp_act(EMP_HEAVY)
	TEST_ASSERT(piece.seized, "EMP'd, nothing waits on the Juggernaut's next swing")
	TEST_ASSERT(!boss.melee_attack(second), "The Juggernaut's EMP'd swing landed")
	TEST_ASSERT_EQUAL(boss.boss_busy, "stagger", "The Juggernaut's EMP'd swing didn't make it reel")

/**
 * Not a check: draws the worn look to data/bounty_chrome_renders/ for a person to look at, each with
 * the chrome and without it, facing south and east. Checks only that both arms go into the dummy.
 */
/datum/unit_test/voidcrew_bounty_chrome_gorilla/renders

/datum/unit_test/voidcrew_bounty_chrome_gorilla/renders/Run()
	var/list/looks = list(
		"1_bare" = list(/datum/species/human, null),
		"2_local" = list(/datum/species/human, /datum/outfit/bounty_criminal/local),
		"3_tough_lizard" = list(/datum/species/lizard, /datum/outfit/bounty_criminal/tough),
		"4_survivor_felinid" = list(/datum/species/human/felinid, /datum/outfit/hermit/survivor),
		"5_juggernaut" = list(/datum/species/human, /datum/outfit/bounty_boss/juggernaut),
	)
	var/list/organs = bounty_chrome_organ_looks(list("gorilla"))
	TEST_ASSERT_EQUAL(length(organs), 2, "Gorilla Arms doesn't show both arms")
	for(var/look_name in looks)
		var/list/spec = looks[look_name]
		var/datum/bounty_look/look = bounty_roll_look(spec[1], MALE)
		for(var/with_chrome in list(TRUE, FALSE))
			var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, spec[2], null, chrome_organs = with_chrome ? organs : null)
			TEST_ASSERT(dummy, "The [look_name] look could not be built")
			if(!dummy)
				continue
			if(with_chrome)
				var/arms = 0
				for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in dummy.organs)
					arms++
				TEST_ASSERT_EQUAL(arms, 2, "The [look_name] dummy has [arms] Gorilla Arms in it, not 2")
			var/suffix = with_chrome ? "" : "_none"
			for(var/facing in list(SOUTH, EAST))
				dummy.setDir(facing)
				fcopy(getFlatIcon(dummy, facing), "data/bounty_chrome_renders/gorilla_[look_name][suffix]_[dir2text(facing)].png")
			qdel(dummy)
