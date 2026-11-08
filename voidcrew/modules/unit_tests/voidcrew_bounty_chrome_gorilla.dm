/**
 * Gorilla Arms on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_gorilla.dm). Every
 * test drives the piece's procs directly with the mobs in place: none waits on its timers or an AI
 * walk, but for a thrown hunter landing and a hold's own clock running out. Fork defines are included
 * after the tests, so a test uses the literal value with a comment naming the define. The test room
 * is a 5x5 floor.
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

/// Starts `piece`'s grab now: its cooldown over, nobody guarded from it
/datum/unit_test/voidcrew_bounty_chrome_gorilla/proc/ready_grab(datum/bounty_chrome/gorilla/piece)
	piece.grab_ready_at = 0
	piece.grab_guard.Cut()

/// Whether `hunter` is held fast by a Gorilla now
/datum/unit_test/voidcrew_bounty_chrome_gorilla/proc/held(mob/living/hunter)
	return !!hunter.has_status_effect(/datum/status_effect/bounty_gorilla_held)

/// Every ordinary blow is the implant's punch: its numbers and sound, a knock-back, no brawler's shove; plain fists while EMP'd; the Juggernaut keeps its own blow
/datum/unit_test/voidcrew_bounty_chrome_gorilla/fists

/datum/unit_test/voidcrew_bounty_chrome_gorilla/fists/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	// Nothing special ready: this is the ordinary blow
	piece.punch_ready_at = world.time + 100 SECONDS
	piece.grab_ready_at = world.time + 100 SECONDS
	TEST_ASSERT(piece.fists_armed, "Their fists aren't the implant's")
	TEST_ASSERT_EQUAL(criminal.npc_zone_original_melee_lower, 20, "An ordinary blow isn't the implant's punch") // BOUNTY_GORILLA_PUNCH_DAMAGE
	TEST_ASSERT_EQUAL(criminal.npc_zone_original_melee_upper, 20, "An ordinary blow isn't the implant's punch") // BOUNTY_GORILLA_PUNCH_DAMAGE
	TEST_ASSERT_EQUAL(criminal.wound_bonus, 10, "An ordinary blow lost the implant's wound bonus") // BOUNTY_GORILLA_PUNCH_WOUND_BONUS
	TEST_ASSERT_EQUAL(criminal.armour_penetration, 10, "An ordinary blow lost the implant's armour penetration") // BOUNTY_GORILLA_PUNCH_AP
	TEST_ASSERT_EQUAL(criminal.attack_sound, 'sound/items/weapons/punch1.ogg', "An ordinary blow doesn't sound like the implant's") // BOUNTY_GORILLA_FIST_SOUND
	TEST_ASSERT_EQUAL(criminal.melee_attack_cooldown, 1.5 SECONDS, "Their blows don't keep the arms' pace") // BOUNTY_GORILLA_FIST_INTERVAL
	TEST_ASSERT(bounty_chrome_owns_blow(criminal), "A brawler's shove still rides on their punches")
	var/turf/start = get_turf(hunter)
	TEST_ASSERT(criminal.melee_attack(hunter, null, TRUE), "The punch didn't land")
	TEST_ASSERT(hunter.getBruteLoss() >= 19, "An ordinary blow hit like a plain punch: [hunter.getBruteLoss()] brute")
	TEST_ASSERT(hunter.throwing || get_turf(hunter) != start, "An ordinary blow didn't knock the hunter back")
	TEST_ASSERT_NULL(piece.busy, "An ordinary blow started something with nothing ready")

	// EMP'd, they punch like anyone; rebooted, the punch is back
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT(!piece.fists_armed, "EMP'd, their fists are still the implant's")
	var/obj/item/bodypart/arm/right/arm = /obj/item/bodypart/arm/right
	TEST_ASSERT_EQUAL(criminal.npc_zone_original_melee_upper, initial(arm.unarmed_damage_high), "EMP'd, they don't punch like anyone else")
	TEST_ASSERT_EQUAL(criminal.melee_attack_cooldown, 1 SECONDS, "EMP'd, they don't keep a brawler's pace") // BOUNTY_BRAWLER_INTERVAL
	TEST_ASSERT(!bounty_chrome_owns_blow(criminal), "EMP'd, the chrome still owns their blow")
	piece.offline_until = world.time
	chrome.tick(2)
	TEST_ASSERT(piece.fists_armed, "Rebooted, the implant's punch didn't come back")
	TEST_ASSERT_EQUAL(criminal.npc_zone_original_melee_upper, 20, "Rebooted, they still punch like anyone") // BOUNTY_GORILLA_PUNCH_DAMAGE

	// A style change that puts a plain punch back is undone at the next tick
	bounty_ai_apply_style(criminal, "brawler") // BOUNTY_STYLE_BRAWLER
	chrome.tick(2)
	TEST_ASSERT_EQUAL(criminal.npc_zone_original_melee_upper, 20, "A style change left them with a plain punch") // BOUNTY_GORILLA_PUNCH_DAMAGE

	// Taken out, their fists are their own again
	qdel(chrome)
	TEST_ASSERT_EQUAL(criminal.npc_zone_original_melee_upper, initial(arm.unarmed_damage_high), "With the chrome gone, they still hit like it")
	TEST_ASSERT_EQUAL(criminal.melee_attack_cooldown, 1 SECONDS, "With the chrome gone, they keep the arms' pace") // BOUNTY_BRAWLER_INTERVAL

	// The Juggernaut's pounding is heavier than the implant's punch: it keeps its own
	var/mob/living/basic/bounty_criminal/boss/juggernaut/boss = allocate(/mob/living/basic/bounty_criminal/boss/juggernaut, tile(3, 4))
	bounty_chrome_install(boss, list("gorilla"))
	var/datum/bounty_chrome/gorilla/boss_piece = bounty_chrome_piece(boss, "gorilla")
	TEST_ASSERT(!boss_piece.fists_armed, "The Juggernaut's blow was swapped for the implant's lighter punch")
	TEST_ASSERT_EQUAL(boss.melee_damage_upper, initial(boss.melee_damage_upper), "The Juggernaut lost its own blow")

/// However the arms got there, they fight bare-handed: an admin's gunman, all of it at once, a companion with a gun; no holster shows
/datum/unit_test/voidcrew_bounty_chrome_gorilla/style

/datum/unit_test/voidcrew_bounty_chrome_gorilla/style/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(4, 4))
	var/mob/living/carbon/human/consistent/operator = allocate(/mob/living/carbon/human/consistent, tile(4, 0))
	var/datum/bounty_admin_panel/unit_test/panel = allocate(/datum/bounty_admin_panel/unit_test, operator)

	// The Bounty Panel: a Wanted pistol criminal with Gorilla Arms picked
	var/mob/living/basic/bounty_criminal/criminal = panel.admin_spawn_criminal(operator, 2, "normal", "pistol", null, tile(0, 0), list("gorilla")) // BOUNTY_TIER_WANTED, BOUNTY_STYLE_PISTOL
	TEST_ASSERT_NOTNULL(criminal, "The panel didn't spawn the criminal: [panel.error]")
	allocated += criminal
	TEST_ASSERT_EQUAL(criminal.record.style, "brawler", "A gunman given Gorilla Arms kept the gun on their record") // BOUNTY_STYLE_BRAWLER
	TEST_ASSERT_EQUAL(criminal.ai_controller.blackboard["bb_bounty_style"], "brawler", "A gunman given Gorilla Arms still fights with the gun") // BB_BOUNTY_STYLE
	TEST_ASSERT_NULL(criminal.ai_controller.blackboard["bb_bounty_weapon"], "A Gorilla Arms brawler carries a weapon") // BB_BOUNTY_WEAPON
	TEST_ASSERT_NULL(criminal.ai_holster, "A holstered gun shows on a Gorilla Arms brawler")
	TEST_ASSERT(criminal.ai_start_fight(hunter), "The criminal wouldn't fight")
	TEST_ASSERT_NULL(criminal.ai_hand, "A Gorilla Arms brawler holds something in the fight")
	TEST_ASSERT_NULL(criminal.ai_holster, "A holstered gun shows in the fight")
	TEST_ASSERT(!bounty_ai_style(criminal).ranged, "A Gorilla Arms brawler fights at range")

	// All of it at once: Mantis Blades and Gorilla Arms together, on a shotgunner
	var/list/everything = panel.chrome_choices()["All of it"]
	var/mob/living/basic/bounty_criminal/loaded = panel.admin_spawn_criminal(operator, 3, "normal", "shotgun", null, tile(0, 4), everything) // BOUNTY_TIER_MOST_WANTED, BOUNTY_STYLE_SHOTGUN
	TEST_ASSERT_NOTNULL(loaded, "The panel didn't spawn the criminal with all of it: [panel.error]")
	allocated += loaded
	TEST_ASSERT_EQUAL(loaded.record.style, "brawler", "With all of it, they didn't end up a brawler") // BOUNTY_STYLE_BRAWLER
	TEST_ASSERT_NULL(loaded.ai_holster, "With all of it, a holstered gun shows")
	TEST_ASSERT(loaded.ai_start_fight(hunter), "The loaded criminal wouldn't fight")
	TEST_ASSERT(!bounty_ai_style(loaded).ranged, "With all of it, they fight at range")
	TEST_ASSERT_NULL(loaded.ai_holster, "With all of it, a holstered gun shows in the fight")

	// A companion with a gun, given the arms
	var/mob/living/basic/bounty_companion/buddy = allocate(/mob/living/basic/bounty_companion, tile(2, 0))
	buddy.ai_take_style("pistol") // BOUNTY_STYLE_PISTOL
	TEST_ASSERT_NOTNULL(buddy.ai_holster, "The test companion's pistol isn't holstered")
	bounty_chrome_install(buddy, list("gorilla"))
	TEST_ASSERT_EQUAL(bounty_ai_style(buddy)?.key, "brawler", "A companion given Gorilla Arms kept the gun") // BOUNTY_STYLE_BRAWLER
	TEST_ASSERT_NULL(buddy.ai_holster, "A companion given Gorilla Arms still shows a holstered gun")
	buddy.ai_enter_fight()
	TEST_ASSERT_NULL(buddy.ai_hand, "A Gorilla Arms companion holds something in the fight")

/**
 * The grab: a ring and a reach, then held fast, two punches to the face and the piston punch that
 * throws them off, the whole of it within the budget; afterwards nobody is held or rooted, and the
 * same hunter can't be grabbed again straight away
 */
/datum/unit_test/voidcrew_bounty_chrome_gorilla/grab

/datum/unit_test/voidcrew_bounty_chrome_gorilla/grab/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	TEST_ASSERT(piece.grab_ready_at > world.time, "The first grab can come the moment the fight starts")
	TEST_ASSERT(!piece.start_grab(hunter), "A grab started inside the fight's opening")
	ready_grab(piece)

	// The reach
	TEST_ASSERT(piece.try_special(hunter), "Nothing started at the hunter beside them")
	TEST_ASSERT_EQUAL(piece.busy, "reach", "With the grab ready, they didn't reach for the hunter first") // BOUNTY_GORILLA_REACH
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Reaching, they can still walk") // BOUNTY_GORILLA_TRAIT
	TEST_ASSERT(criminal.next_move > world.time, "Reaching, they can still throw ordinary blows")
	var/obj/effect/temp_visual/bounty_boss_mark/ring = locate() in tile(2, 2)
	TEST_ASSERT_NOTNULL(ring, "No ring under the hunter they reach for")
	TEST_ASSERT_EQUAL(ring?.icon_state, "target_circle", "The reach is marked like the piston punch")
	TEST_ASSERT(LAZYACCESS(criminal.filter_data, "bounty_gorilla_glow"), "No glow on them while they reach") // BOUNTY_GORILLA_GLOW
	TEST_ASSERT(!piece.start_punch(hunter), "A piston punch wound up over the reach")
	TEST_ASSERT(!held(hunter), "The hunter is held before the reach is over")

	// Got hold of them
	TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed a hunter who stood still")
	TEST_ASSERT_EQUAL(piece.busy, "hold", "Their hands closed, but they aren't holding on") // BOUNTY_GORILLA_HOLD
	TEST_ASSERT(held(hunter), "The grabbed hunter isn't held")
	TEST_ASSERT(HAS_TRAIT_FROM(hunter, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla_held"), "The grabbed hunter can walk off") // BOUNTY_GORILLA_HELD_TRAIT
	TEST_ASSERT(!HAS_TRAIT(hunter, TRAIT_HANDS_BLOCKED), "The grabbed hunter can't use their hands")
	TEST_ASSERT_EQUAL(LAZYACCESS(LAZYACCESS(hunter.offsets, PIXEL_X_OFFSET), "bounty_chrome_gorilla_held"), -12, "The grabbed hunter isn't drawn in toward them") // GRAB_PIXEL_SHIFT_AGGRESSIVE
	TEST_ASSERT(criminal.next_move > world.time, "Holding on, they can still throw ordinary blows")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The grab itself did harm")

	// Two punches to the face
	var/obj/item/bodypart/head = hunter.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(piece.pummel(piece.serial), "The first punch of the pummel wasn't thrown")
	TEST_ASSERT(head.brute_dam > 0, "The first punch didn't land on the face")
	var/after_first = hunter.getBruteLoss()
	TEST_ASSERT(held(hunter), "Let go after one punch")
	TEST_ASSERT(piece.pummel(piece.serial), "The second punch of the pummel wasn't thrown")
	TEST_ASSERT(hunter.getBruteLoss() > after_first, "The second punch did nothing")
	TEST_ASSERT(held(hunter), "Let go after two punches")
	TEST_ASSERT_EQUAL(get_turf(hunter), tile(2, 2), "The pummel moved the hunter before the finisher")

	// The finisher: the piston punch lets go and throws them off
	TEST_ASSERT(piece.pummel(piece.serial), "The finishing punch wasn't thrown")
	TEST_ASSERT(!held(hunter), "The finisher didn't let go")
	TEST_ASSERT(!HAS_TRAIT_FROM(hunter, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla_held"), "Let go, the hunter still can't walk")
	TEST_ASSERT_NULL(LAZYACCESS(LAZYACCESS(hunter.offsets, PIXEL_X_OFFSET), "bounty_chrome_gorilla_held"), "Let go, the hunter is still drawn in")
	TEST_ASSERT(hunter.has_status_effect(/datum/status_effect/staggered), "The finisher didn't stagger the hunter")
	TEST_ASSERT(hunter.throwing || get_turf(hunter) != tile(2, 2), "The finisher didn't throw the hunter back")
	TEST_ASSERT_NULL(piece.busy, "Still busy after the finisher")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Still rooted after the finisher")
	TEST_ASSERT(!LAZYACCESS(criminal.filter_data, "bounty_gorilla_glow"), "Still glowing after the finisher")
	// Three of the implant's punches, unarmoured, come to 60: the budget holds the whole of it to 55
	TEST_ASSERT(hunter.getBruteLoss() <= 55.5, "The grab did [hunter.getBruteLoss()] brute, past its budget") // BOUNTY_GORILLA_PUMMEL_BUDGET
	TEST_ASSERT(hunter.getBruteLoss() >= 50, "The grab did only [hunter.getBruteLoss()] brute")
	TEST_ASSERT_EQUAL(hunter.stat, CONSCIOUS, "A healthy hunter didn't come out of the grab on their feet")

	// Not again straight away: their own cooldown, and anyone's guard on someone just let go
	TEST_ASSERT(piece.grab_ready_at > world.time, "No wait before the next grab")
	TEST_ASSERT(piece.punch_ready_at > world.time, "The piston punch can follow the grab at once")
	sleep(1 SECONDS) // the throw
	piece.grab_ready_at = 0
	hunter.forceMove(tile(2, 2))
	criminal.next_move = 0
	TEST_ASSERT(!piece.start_grab(hunter), "The hunter was grabbed again the moment they were let go")
	ready_grab(piece)
	TEST_ASSERT(piece.start_grab(hunter), "With the guard gone, no second grab")
	piece.stop()

/// The budget holds even where they hit hardest: a healthy hunter comes out on their feet
/datum/unit_test/voidcrew_bounty_chrome_gorilla/grab_budget

/datum/unit_test/voidcrew_bounty_chrome_gorilla/grab_budget/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	criminal.npc_zone_damage_factor = 3
	ready_grab(piece)
	TEST_ASSERT(piece.start_grab(hunter), "No grab started")
	TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed")
	for(var/i in 1 to 3)
		piece.pummel(piece.serial)
	TEST_ASSERT(!held(hunter), "The hunter is still held after the pummel")
	TEST_ASSERT(hunter.getBruteLoss() <= 55.5, "Hitting three times as hard, the grab did [hunter.getBruteLoss()] brute, past its budget") // BOUNTY_GORILLA_PUMMEL_BUDGET
	TEST_ASSERT_EQUAL(hunter.stat, CONSCIOUS, "Hitting three times as hard, the grab put a healthy hunter down")

/// Ways out: stepping off the ring, a shield, struggling, hitting them hard, an EMP, a knockdown, being pulled apart; anyone who drops is let go
/datum/unit_test/voidcrew_bounty_chrome_gorilla/grab_counters

/datum/unit_test/voidcrew_bounty_chrome_gorilla/grab_counters/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")

	// Off the ring during the reach: hands on air, and they stumble
	ready_grab(piece)
	TEST_ASSERT(piece.start_grab(hunter), "No grab started")
	hunter.forceMove(tile(3, 3))
	TEST_ASSERT(!piece.finish_reach(piece.serial), "The grab caught a hunter who stepped off the ring")
	TEST_ASSERT(!held(hunter), "A hunter who stepped away is held")
	TEST_ASSERT_EQUAL(piece.busy, "stumble", "Grabbing air, they didn't stumble") // BOUNTY_GORILLA_STUMBLE
	piece.end_stumble(piece.serial)

	// A shield stops it outright
	hunter.forceMove(tile(2, 2))
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot)
	hunter.put_in_active_hand(shield)
	ready_grab(piece)
	criminal.next_move = 0
	TEST_ASSERT(piece.start_grab(hunter), "No grab started at the shield bearer")
	TEST_ASSERT(!piece.finish_reach(piece.serial), "The grab went through a shield")
	TEST_ASSERT(!held(hunter), "A hunter behind a shield is held")
	TEST_ASSERT_EQUAL(piece.busy, "stumble", "Grabbing a shield, they didn't stumble")
	piece.end_stumble(piece.serial)
	qdel(shield)

	// Struggling free, by resisting and by trying to walk off
	for(var/how in list("resist", "move"))
		ready_grab(piece)
		criminal.next_move = 0
		TEST_ASSERT(piece.start_grab(hunter), "No grab started ([how])")
		TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed ([how])")
		var/datum/status_effect/bounty_gorilla_held/hold = hunter.has_status_effect(/datum/status_effect/bounty_gorilla_held)
		TEST_ASSERT_NOTNULL(hold, "The grabbed hunter isn't held ([how])")
		hold.break_chance = 100
		if(how == "resist")
			SEND_SIGNAL(hunter, COMSIG_LIVING_RESIST, hunter)
		else
			SEND_SIGNAL(hunter, COMSIG_MOB_CLIENT_PRE_LIVING_MOVE, get_step(hunter, EAST), EAST)
		TEST_ASSERT(!held(hunter), "Struggling free ([how]) didn't free the hunter")
		TEST_ASSERT(!HAS_TRAIT(hunter, TRAIT_IMMOBILIZED), "Struggled free ([how]), the hunter still can't walk")
		TEST_ASSERT_EQUAL(piece.busy, "stumble", "A hunter struggled free ([how]) and they didn't stumble")
		piece.end_stumble(piece.serial)
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "Getting loose before a punch still hurt")

	// Hit hard while holding on: they let go
	ready_grab(piece)
	criminal.next_move = 0
	TEST_ASSERT(piece.start_grab(hunter), "No grab started before the hard hit")
	TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed before the hard hit")
	criminal.apply_damage(25, BRUTE)
	TEST_ASSERT(!held(hunter), "Hit hard, they kept hold")
	TEST_ASSERT_EQUAL(piece.busy, "stumble", "Hit hard, they let go but didn't reel")
	piece.end_stumble(piece.serial)

	// A knockdown mid-hold
	ready_grab(piece)
	criminal.next_move = 0
	TEST_ASSERT(piece.start_grab(hunter), "No grab started before the knockdown")
	TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed before the knockdown")
	criminal.Knockdown(1 SECONDS)
	TEST_ASSERT(!held(hunter), "Knocked down, they kept hold")
	TEST_ASSERT_NULL(piece.busy, "Knocked down, they are still busy")
	criminal.SetKnockdown(0)

	// Pulled apart: the hold is gone and the next blow never lands
	ready_grab(piece)
	criminal.next_move = 0
	TEST_ASSERT(piece.start_grab(hunter), "No grab started before the pull")
	TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed before the pull")
	hunter.forceMove(tile(3, 4))
	TEST_ASSERT(!held(hunter), "Moved out of reach, the hunter is still held")
	TEST_ASSERT(!piece.pummel(piece.serial), "A punch was thrown at someone pulled out of reach")
	TEST_ASSERT_NULL(piece.busy, "With nobody to hold, they are still busy")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "Someone pulled out of reach was hurt")

	// Dropped mid-pummel: they let go
	hunter.forceMove(tile(2, 2))
	ready_grab(piece)
	criminal.next_move = 0
	TEST_ASSERT(piece.start_grab(hunter), "No grab started before the drop")
	TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed before the drop")
	hunter.Knockdown(2 SECONDS)
	TEST_ASSERT(!piece.pummel(piece.serial), "A punch was thrown at someone on the floor")
	TEST_ASSERT(!held(hunter), "Someone on the floor is still held")
	hunter.SetKnockdown(0)

	// An EMP mid-hold: let go, and they go down (a second hunter: the first is still getting up)
	var/mob/living/carbon/human/consistent/second = hunter_at(tile(1, 3))
	ready_grab(piece)
	criminal.next_move = 0
	TEST_ASSERT(piece.start_grab(second), "No grab started before the EMP")
	TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed before the EMP")
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT(!held(second), "EMP'd, they kept hold")
	TEST_ASSERT(criminal.IsKnockdown(), "EMP'd mid-hold, they stayed up")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "EMP'd mid-hold, they stay rooted")
	TEST_ASSERT_EQUAL(second.getBruteLoss(), 0, "The EMP'd hold still punched")
	ready_grab(piece)
	TEST_ASSERT(!piece.start_grab(second), "EMP'd, they can still grab")

/// Death and deletion mid-hold let go; a hold whose gorilla vanished ends by itself; the Juggernaut grabs by its own rules
/datum/unit_test/voidcrew_bounty_chrome_gorilla/grab_cleanup

/datum/unit_test/voidcrew_bounty_chrome_gorilla/grab_cleanup/Run()
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(2, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = gorilla_at(tile(1, 2), hunter)
	var/datum/bounty_chrome/gorilla/piece = bounty_chrome_piece(criminal, "gorilla")
	ready_grab(piece)
	TEST_ASSERT(piece.start_grab(hunter), "No grab started")
	TEST_ASSERT(piece.finish_reach(piece.serial), "The reach missed")
	criminal.death()
	TEST_ASSERT(!held(hunter), "A dead criminal still holds the hunter")
	TEST_ASSERT(!HAS_TRAIT(hunter, TRAIT_IMMOBILIZED), "A dead criminal's hold still roots the hunter")

	// The chrome deleted mid-hold
	var/mob/living/basic/bounty_criminal/normal/second = gorilla_at(tile(1, 3), null)
	second.ai_start_fight(hunter)
	var/datum/bounty_chrome/gorilla/second_piece = bounty_chrome_piece(second, "gorilla")
	hunter.forceMove(tile(2, 3))
	ready_grab(second_piece)
	TEST_ASSERT(second_piece.start_grab(hunter), "No grab started on the second criminal")
	TEST_ASSERT(second_piece.finish_reach(second_piece.serial), "The second criminal's reach missed")
	qdel(second.GetComponent(/datum/component/bounty_chrome))
	TEST_ASSERT(!held(hunter), "With the chrome gone, the hunter is still held")
	TEST_ASSERT(!HAS_TRAIT(hunter, TRAIT_IMMOBILIZED), "With the chrome gone, the hunter still can't walk")
	TEST_ASSERT(!HAS_TRAIT_FROM(second, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "With the chrome gone, the criminal stays rooted")

	// A hold whose gorilla is gone without a word ends on its own clock
	var/mob/living/basic/bounty_criminal/normal/third = allocate(/mob/living/basic/bounty_criminal/normal, tile(1, 4))
	hunter.forceMove(tile(2, 4))
	TEST_ASSERT_NOTNULL(hunter.apply_status_effect(/datum/status_effect/bounty_gorilla_held, third, null), "The hold couldn't be put on by hand")
	sleep(3 SECONDS) // BOUNTY_GORILLA_HOLD_MAX 2.5 seconds
	TEST_ASSERT(!held(hunter), "An orphaned hold never ended")
	TEST_ASSERT(!HAS_TRAIT(hunter, TRAIT_IMMOBILIZED), "An orphaned hold left the hunter rooted")

	// The Juggernaut: busy through the reach and the hold, and cut off when knocked out of it
	var/mob/living/basic/bounty_criminal/boss/juggernaut/boss = allocate(/mob/living/basic/bounty_criminal/boss/juggernaut, tile(3, 1))
	var/mob/living/carbon/human/consistent/tank = hunter_at(tile(4, 1))
	bounty_chrome_install(boss, list("gorilla"))
	var/datum/bounty_chrome/gorilla/boss_piece = bounty_chrome_piece(boss, "gorilla")
	boss.boss_hostile = TRUE
	boss.boss_next_ability_at = 0
	ready_grab(boss_piece)
	TEST_ASSERT(boss_piece.start_grab(tank), "The Juggernaut didn't reach for the hunter")
	TEST_ASSERT_EQUAL(boss.boss_busy, "gorilla", "Reaching, the Juggernaut isn't busy") // BOUNTY_GORILLA_BOSS_BUSY
	TEST_ASSERT(boss.boss_next_ability_at > world.time, "The reach didn't push back the Juggernaut's next ability")
	TEST_ASSERT(boss_piece.finish_reach(boss_piece.serial), "The Juggernaut's reach missed")
	TEST_ASSERT_EQUAL(boss.boss_busy, "gorilla", "Holding on, the Juggernaut isn't busy")
	TEST_ASSERT(held(tank), "The Juggernaut's grab didn't hold the hunter")
	boss.boss_interrupt()
	TEST_ASSERT(!boss_piece.pummel(boss_piece.serial), "A Juggernaut knocked out of its hold still punched")
	TEST_ASSERT(!held(tank), "A Juggernaut knocked out of its hold still holds on")
	TEST_ASSERT_EQUAL(tank.getBruteLoss(), 0, "The cut-off pummel hurt someone")

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

	// The grab in its parts, for a person to lay together: the brawler facing the one they hold, the
	// held hunter facing back, the ring under someone reached for, the piston punch's tile, and the
	// punch over a face
	var/datum/bounty_look/holder_look = bounty_roll_look(/datum/species/human, MALE)
	var/mob/living/carbon/human/dummy/holder = bounty_look_dummy(holder_look, /datum/outfit/bounty_criminal/tough, null, chrome_organs = organs)
	TEST_ASSERT(holder, "The grabbing brawler's look could not be built")
	if(holder)
		holder.setDir(EAST)
		fcopy(getFlatIcon(holder, EAST), "data/bounty_chrome_renders/gorilla_grab_holder_east.png")
		qdel(holder)
	var/datum/bounty_look/held_look = bounty_roll_look(/datum/species/human, FEMALE)
	var/mob/living/carbon/human/dummy/held = bounty_look_dummy(held_look, /datum/outfit/job/security, null)
	TEST_ASSERT(held, "The held hunter's look could not be built")
	if(held)
		held.setDir(WEST)
		fcopy(getFlatIcon(held, WEST), "data/bounty_chrome_renders/gorilla_grab_held_west.png")
		qdel(held)
	var/icon/ring = icon('icons/mob/telegraphing/telegraph_holographic.dmi', "target_circle", SOUTH, 1)
	ring.MapColors(1, 0.54, 0.12, 0, 0, 0, 0, 0, 0) // BOUNTY_GORILLA_MARK_COLOR
	fcopy(ring, "data/bounty_chrome_renders/gorilla_mark_target_circle.png")
	var/icon/box = icon('icons/mob/telegraphing/telegraph_holographic.dmi', "target_box", SOUTH, 1)
	box.Blend("#ff8a1f", ICON_MULTIPLY) // BOUNTY_GORILLA_COLOR
	fcopy(box, "data/bounty_chrome_renders/gorilla_mark_target_box.png")
	fcopy(icon('icons/effects/effects.dmi', "punch", SOUTH, 1), "data/bounty_chrome_renders/gorilla_grab_punch_fx.png")
