/**
 * Meteor Piledriver on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_piledriver.dm).
 * Every test drives the piece's procs directly with the mobs in place: the crouch, the launch, the
 * landing and the vent are called with the leap's serial rather than waited for. Fork defines are
 * included after the tests, so a test uses the literal value with a comment naming the define. The
 * test room is a 5x5 floor.
 */
/datum/unit_test/voidcrew_bounty_chrome_piledriver
	abstract_type = /datum/unit_test/voidcrew_bounty_chrome_piledriver
	/// Turfs a test changed, put back to plain floor when it ends
	var/list/turf/changed_turfs = list()

/datum/unit_test/voidcrew_bounty_chrome_piledriver/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	return ..()

/// The floor tile `dx`, `dy` from the room's bottom left
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Changes `where` to `new_type`, to be put back when the test ends
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/change_turf(turf/where, new_type)
	changed_turfs |= where
	return where.ChangeTurf(new_type)

/// A hunter at `where`: a human with a mind, as a player would be
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/hunter_at(turf/where)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, where)
	hunter.mind_initialize()
	return hunter

/// A normal criminal at `where` with the piledriver in; returns its piece
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/leaper_at(turf/where)
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, where)
	bounty_chrome_install(criminal, list("piledriver")) // BOUNTY_CHROME_PILEDRIVER
	return bounty_chrome_piece(criminal, "piledriver")

/// Whether the landing shadow is on `where`
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/shadow_on(turf/where)
	return !isnull(locate(/obj/effect/temp_visual/cyberware_piledriver_shadow/bounty) in where)

/// Whether `fighter` is still held by the leap, by its own trait source
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/held(mob/living/fighter)
	return HAS_TRAIT_FROM(fighter, TRAIT_IMMOBILIZED, "bounty_chrome_piledriver") || HAS_TRAIT_FROM(fighter, TRAIT_AI_PAUSED, "bounty_chrome_piledriver") // BOUNTY_PILEDRIVER_SOURCE

// ===== WHO CARRIES IT =====

/// The roll: Wanted and up, normal criminals and the Pyromaniac only, never with Mantis Blades; the examine line and the worn implant
/datum/unit_test/voidcrew_bounty_chrome_piledriver/rolls

/datum/unit_test/voidcrew_bounty_chrome_piledriver/rolls/Run()
	var/datum/bounty_chrome/piledriver/proto = GLOB.bounty_chrome_protos["piledriver"] // BOUNTY_CHROME_PILEDRIVER
	TEST_ASSERT_NOTNULL(proto, "No Meteor Piledriver prototype")
	TEST_ASSERT(proto.weight > 0, "The Meteor Piledriver never rolls")
	// BOUNTY_TIER_PETTY 1, BOUNTY_TIER_WANTED 2, BOUNTY_TIER_MOST_WANTED 3
	TEST_ASSERT(!proto.can_roll(1, "normal", "brawler", null, list()), "A Petty criminal can roll the piledriver")
	for(var/style in list("brawler", "knife", "club", "pistol", "smg", "revolver", "shotgun", "bottle"))
		TEST_ASSERT(proto.can_roll(2, "normal", style, null, list()), "A Wanted [style] criminal can't roll the piledriver")
	TEST_ASSERT(!proto.can_roll(3, "meek", "holdout", null, list()), "A meek criminal can roll the piledriver") // BOUNTY_ARCHETYPE_MEEK
	TEST_ASSERT(!proto.can_roll(3, "companion", "brawler", null, list()), "A companion can roll the piledriver") // BOUNTY_CHROME_COMPANION
	TEST_ASSERT(proto.can_roll(3, "boss", null, "pyromaniac", list()), "The Pyromaniac can't roll the piledriver") // BOUNTY_KIT_PYROMANIAC
	for(var/kit in list("juggernaut", "ghost", "demolitionist", "heavy"))
		TEST_ASSERT(!proto.can_roll(3, "boss", null, kit, list()), "The [kit] mini-boss can roll the piledriver")
	TEST_ASSERT(!proto.can_roll(3, "normal", "brawler", null, list("mantis")), "The piledriver rolled alongside Mantis Blades") // BOUNTY_CHROME_MANTIS
	var/datum/bounty_chrome/mantis_proto = GLOB.bounty_chrome_protos["mantis"]
	if(mantis_proto)
		TEST_ASSERT(!mantis_proto.can_roll(3, "normal", "brawler", null, list("piledriver")), "Mantis Blades rolled alongside the piledriver")
	for(var/i in 1 to 50)
		var/list/companion_pick = bounty_pick_chrome(1, 3, "companion", "brawler", null) || list()
		TEST_ASSERT(!("piledriver" in companion_pick), "A companion picked the piledriver")
		var/list/petty_pick = bounty_pick_chrome(1, 1, "normal", "brawler", null) || list()
		TEST_ASSERT(!("piledriver" in petty_pick), "A Petty criminal picked the piledriver")

	// Examining them shows the pistons
	var/datum/bounty_chrome/piledriver/piece = leaper_at(tile(1, 1))
	TEST_ASSERT_NOTNULL(piece, "Installing the piledriver gave no piece")
	var/found = FALSE
	for(var/line in piece.owner.examine(piece.owner))
		if(findtext(line, "launch pistons"))
			found = TRUE
	TEST_ASSERT(found, "Examining them doesn't show the pistons")

	// The worn look: the real frame goes into the look dummy
	var/datum/bounty_look/look = bounty_roll_look(/datum/species/human, MALE)
	var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, null, null, chrome_organs = bounty_chrome_organ_looks(list("piledriver")))
	TEST_ASSERT_NOTNULL(dummy, "The look dummy failed with the piledriver")
	if(dummy)
		TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/piledriver) in dummy.organs, "The piledriver frame isn't in the look dummy")
		qdel(dummy)

// ===== THE LEAP =====

/**
 * A whole leap from the fight's tick: it crouches held still, launches with the shadow on its
 * target's tile, lands there crushing the target and knocking down a hunter in the ring, leaves a
 * hunter outside the ring and its own companion alone, vents, and lets go with the cooldown running.
 */
/datum/unit_test/voidcrew_bounty_chrome_piledriver/leap

/datum/unit_test/voidcrew_bounty_chrome_piledriver/leap/Run()
	var/datum/bounty_chrome/piledriver/piece = leaper_at(tile(0, 0))
	var/mob/living/basic/bounty_criminal/normal/criminal = piece.owner
	var/mob/living/carbon/human/consistent/target = hunter_at(tile(3, 0))
	var/mob/living/carbon/human/consistent/beside = hunter_at(tile(4, 2))
	var/mob/living/carbon/human/consistent/far = hunter_at(tile(0, 4))
	var/mob/living/basic/bounty_companion/buddy = allocate(/mob/living/basic/bounty_companion, tile(2, 1))
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)

	TEST_ASSERT(criminal.ai_start_fight(target), "The criminal wouldn't start the fight")
	// Theirs from here on, after the rally, so the companion's own fight never starts in the test
	buddy.leader_ref = WEAKREF(criminal)
	TEST_ASSERT(bounty_chrome_fighting(criminal), "The criminal isn't fighting")
	TEST_ASSERT(piece.next_leap_at > world.time, "It may leap the moment the fight starts")
	TEST_ASSERT_EQUAL(piece.next_leap_at - world.time, 15, "The first leap waits [piece.next_leap_at - world.time] deciseconds into the fight, not 15") // BOUNTY_PILEDRIVER_OPENING
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.phase, 0, "It leapt before its opening wait was over") // BOUNTY_PILEDRIVER_IDLE

	piece.next_leap_at = 0
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.phase, 1, "Off cooldown with a hunter in reach, it didn't crouch") // BOUNTY_PILEDRIVER_CROUCHING
	TEST_ASSERT(held(criminal), "It isn't held still while it crouches")
	TEST_ASSERT_EQUAL(criminal.loc, tile(0, 0), "It moved in the crouch")
	TEST_ASSERT_NOTNULL(criminal.get_filter("bounty_piledriver_glow"), "The crouch shows no outline") // BOUNTY_PILEDRIVER_GLOW_FILTER

	TEST_ASSERT(piece.launch(piece.serial), "It didn't launch")
	TEST_ASSERT_EQUAL(piece.phase, 2, "Launched, it isn't in the air") // BOUNTY_PILEDRIVER_AIRBORNE
	TEST_ASSERT_NULL(criminal.get_filter("bounty_piledriver_glow"), "The crouch's outline stayed on in the air")
	TEST_ASSERT_EQUAL(piece.landing, tile(3, 0), "It isn't coming down on its target's tile")
	TEST_ASSERT(shadow_on(tile(3, 0)), "No shadow on the landing tile")
	TEST_ASSERT_EQUAL(criminal.loc, tile(0, 0), "It arrived before the air time was over")
	TEST_ASSERT(piece.next_leap_at > world.time, "No cooldown from the launch")
	TEST_ASSERT(target.getBruteLoss() == 0 && !target.IsParalyzed(), "The target was hurt before the landing")

	var/old_serial = piece.serial
	TEST_ASSERT(piece.land(piece.serial), "It didn't land")
	TEST_ASSERT_EQUAL(criminal.loc, tile(3, 0), "It didn't land on the shadow")
	TEST_ASSERT(!shadow_on(tile(3, 0)), "The shadow outlived the landing")
	TEST_ASSERT(target.getBruteLoss() > 0, "The target under it wasn't crushed")
	TEST_ASSERT(target.IsParalyzed(), "The crushed target isn't pinned")
	TEST_ASSERT(beside.getBruteLoss() > 0, "A hunter two tiles off took no shockwave")
	TEST_ASSERT(beside.IsKnockdown(), "A hunter two tiles off wasn't knocked down")
	TEST_ASSERT(!beside.IsParalyzed(), "A hunter in the ring was pinned as if crushed")
	TEST_ASSERT(far.getBruteLoss() == 0 && !far.IsKnockdown(), "A hunter four tiles off was caught")
	TEST_ASSERT(buddy.health == buddy.maxHealth && !buddy.IsKnockdown(), "It hit its own companion")
	TEST_ASSERT_EQUAL(piece.phase, 3, "Landed, it isn't venting") // BOUNTY_PILEDRIVER_RECOVERING
	TEST_ASSERT(held(criminal), "It isn't held still while it vents")
	TEST_ASSERT(!piece.land(old_serial), "A second landing went through")

	TEST_ASSERT(piece.recover(piece.serial), "The vent didn't end")
	TEST_ASSERT_EQUAL(piece.phase, 0, "Done, it is still leaping") // BOUNTY_PILEDRIVER_IDLE
	TEST_ASSERT(!held(criminal), "Done, it is still held")
	TEST_ASSERT_EQUAL(criminal.pixel_z, criminal.base_pixel_z, "Done, it is still up in the air")
	chrome.tick(2)
	TEST_ASSERT_EQUAL(piece.phase, 0, "It leapt again inside its cooldown")

/// Where it won't leap: a hunter too close, behind a wall, a window or a shut door; over a table it will. A target on lava is landed beside.
/datum/unit_test/voidcrew_bounty_chrome_piledriver/reach

/datum/unit_test/voidcrew_bounty_chrome_piledriver/reach/Run()
	var/datum/bounty_chrome/piledriver/piece = leaper_at(tile(0, 0))
	var/mob/living/carbon/human/consistent/target = hunter_at(tile(3, 0))
	TEST_ASSERT_EQUAL(piece.landing_for(target), tile(3, 0), "No leap at a hunter three tiles off in the open")

	target.forceMove(tile(2, 0))
	TEST_ASSERT_NULL(piece.landing_for(target), "It would leap at a hunter two tiles off")
	target.forceMove(tile(3, 0))

	var/obj/structure/table/table = allocate(/obj/structure/table, tile(2, 0))
	TEST_ASSERT_EQUAL(piece.landing_for(target), tile(3, 0), "A table between them stopped the leap")
	qdel(table)

	var/obj/structure/window/fulltile/window = allocate(/obj/structure/window/fulltile, tile(2, 0))
	TEST_ASSERT(piece.arc_blocked(tile(0, 0), tile(3, 0)), "A window doesn't stop the arc")
	qdel(window)

	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, tile(2, 0))
	TEST_ASSERT(door.density, "The test airlock isn't shut")
	TEST_ASSERT(piece.arc_blocked(tile(0, 0), tile(3, 0)), "A shut door doesn't stop the arc")
	qdel(door)

	change_turf(tile(2, 0), /turf/closed/wall)
	TEST_ASSERT(piece.arc_blocked(tile(0, 0), tile(3, 0)), "A wall doesn't stop the arc")
	TEST_ASSERT(!piece.try_leap(target), "It crouched to leap through a wall")
	TEST_ASSERT_EQUAL(piece.phase, 0, "It is leaping through a wall") // BOUNTY_PILEDRIVER_IDLE
	change_turf(tile(2, 0), /turf/open/floor/iron)

	// Never down onto lava: the target's tile is passed over for the floor beside it
	ADD_TRAIT(target, TRAIT_LAVA_IMMUNE, TRAIT_GENERIC)
	change_turf(tile(3, 0), /turf/open/lava/smooth)
	TEST_ASSERT(!piece.safe_landing(tile(3, 0)), "Lava is a safe landing")
	var/turf/landing = piece.landing_for(target)
	TEST_ASSERT_NOTNULL(landing, "With its target on lava it found nowhere to land")
	TEST_ASSERT(landing && !islava(landing) && get_dist(landing, tile(3, 0)) == 1, "It would land on lava, or not beside its target")
	change_turf(tile(3, 0), /turf/open/floor/iron)

/// The target steps off the shadow: nobody is crushed and it lands anyway. A wall behind the landing shields a hunter from the shockwave.
/datum/unit_test/voidcrew_bounty_chrome_piledriver/dodge

/datum/unit_test/voidcrew_bounty_chrome_piledriver/dodge/Run()
	var/datum/bounty_chrome/piledriver/piece = leaper_at(tile(0, 0))
	var/mob/living/basic/bounty_criminal/normal/criminal = piece.owner
	var/mob/living/carbon/human/consistent/target = hunter_at(tile(3, 0))
	var/mob/living/carbon/human/consistent/sheltered = hunter_at(tile(3, 2))
	change_turf(tile(3, 1), /turf/closed/wall)
	change_turf(tile(2, 1), /turf/closed/wall)
	change_turf(tile(4, 1), /turf/closed/wall)
	TEST_ASSERT(piece.try_leap(target), "It didn't crouch")
	TEST_ASSERT(piece.launch(piece.serial), "It didn't launch")
	target.forceMove(tile(4, 4))
	TEST_ASSERT(piece.land(piece.serial), "It didn't land")
	TEST_ASSERT_EQUAL(criminal.loc, tile(3, 0), "It didn't come down on the shadow")
	TEST_ASSERT(target.getBruteLoss() == 0 && !target.IsParalyzed() && !target.IsKnockdown(), "A hunter who got clear was still caught")
	TEST_ASSERT(sheltered.getBruteLoss() == 0 && !sheltered.IsKnockdown(), "The shockwave went through a wall")
	piece.recover(piece.serial)
	TEST_ASSERT(!held(criminal), "Done, it is still held")

/// An EMP in the air drops it short in a heap; in the crouch it just stops. A shut door across the arc mid-air drops it too, and so does a knockdown, harmlessly.
/datum/unit_test/voidcrew_bounty_chrome_piledriver/grounded

/datum/unit_test/voidcrew_bounty_chrome_piledriver/grounded/Run()
	var/datum/bounty_chrome/piledriver/piece = leaper_at(tile(0, 0))
	var/mob/living/basic/bounty_criminal/normal/criminal = piece.owner
	var/mob/living/carbon/human/consistent/target = hunter_at(tile(3, 0))

	// EMP in the crouch: no leap, no heap
	TEST_ASSERT(piece.try_leap(target), "It didn't crouch")
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.phase, 0, "An EMP in the crouch didn't stop it") // BOUNTY_PILEDRIVER_IDLE
	TEST_ASSERT(!held(criminal), "An EMP in the crouch left it held")
	TEST_ASSERT(!criminal.IsKnockdown(), "An EMP in the crouch knocked it down")
	TEST_ASSERT_NULL(criminal.get_filter("bounty_piledriver_glow"), "An EMP in the crouch left the outline on")
	TEST_ASSERT(!piece.try_leap(target), "It leapt with its chrome down")
	piece.offline_until = world.time
	piece.check_reboot()
	TEST_ASSERT(piece.online(), "The piledriver never came back from the EMP")

	// EMP in the air: it drops where it stood
	TEST_ASSERT(piece.try_leap(target), "It didn't crouch after the reboot")
	TEST_ASSERT(piece.launch(piece.serial), "It didn't launch")
	var/air_serial = piece.serial
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.phase, 0, "An EMP in the air didn't drop it") // BOUNTY_PILEDRIVER_IDLE
	TEST_ASSERT_EQUAL(criminal.loc, tile(0, 0), "Dropped by an EMP, it still reached the landing")
	TEST_ASSERT(criminal.IsKnockdown(), "Dropped by an EMP, it isn't down in a heap")
	TEST_ASSERT(!shadow_on(tile(3, 0)), "The shadow stayed after the EMP")
	TEST_ASSERT(!held(criminal), "Dropped by an EMP, it is still held")
	TEST_ASSERT_EQUAL(criminal.pixel_z, criminal.base_pixel_z, "Dropped by an EMP, it is still up in the air")
	TEST_ASSERT(!piece.land(air_serial), "The landing came after the EMP")
	TEST_ASSERT(target.getBruteLoss() == 0, "The target was hurt by a leap that never landed")
	criminal.SetKnockdown(0)
	piece.offline_until = world.time
	piece.check_reboot()

	// A door shut across the arc while it is up: it comes down short
	TEST_ASSERT(piece.try_leap(target), "It didn't crouch after the second reboot")
	TEST_ASSERT(piece.launch(piece.serial), "It didn't launch the third time")
	for(var/dy in 0 to 4)
		change_turf(tile(2, dy), /turf/closed/wall)
	TEST_ASSERT(!piece.land(piece.serial), "It landed through a wall")
	TEST_ASSERT_EQUAL(criminal.loc, tile(0, 0), "It went through a wall")
	TEST_ASSERT(criminal.IsKnockdown(), "Cut off mid-air, it isn't down in a heap")
	TEST_ASSERT(!held(criminal), "Cut off mid-air, it is still held")
	criminal.SetKnockdown(0)
	for(var/dy in 0 to 4)
		change_turf(tile(2, dy), /turf/open/floor/iron)

	// Knocked down in the air: it drops where it took off, in a puff of dust, never lands, and nothing is left behind
	TEST_ASSERT(piece.try_leap(target), "It didn't crouch the fourth time")
	TEST_ASSERT(piece.launch(piece.serial), "It didn't launch the fourth time")
	var/dust_before = 0
	for(var/obj/effect/temp_visual/mook_dust/small/dust in tile(0, 0))
		dust_before++
	criminal.Knockdown(1 SECONDS)
	TEST_ASSERT_EQUAL(piece.phase, 0, "Knocked down in the air, it is still leaping") // BOUNTY_PILEDRIVER_IDLE
	TEST_ASSERT(!shadow_on(tile(3, 0)), "Knocked down in the air, its shadow stayed")
	TEST_ASSERT(!held(criminal), "Knocked down in the air, it is still held")
	TEST_ASSERT_EQUAL(criminal.pixel_z, criminal.base_pixel_z, "Knocked down in the air, it is still up there")
	TEST_ASSERT_EQUAL(criminal.loc, tile(0, 0), "Knocked down in the air, it still went somewhere")
	var/dust_after = 0
	for(var/obj/effect/temp_visual/mook_dust/small/dust in tile(0, 0))
		dust_after++
	TEST_ASSERT_EQUAL(dust_after, dust_before + 1, "Knocked out of the air, it came down with no dust")
	TEST_ASSERT(target.getBruteLoss() == 0, "The target was hurt by a leap knocked out of the air")
	criminal.SetKnockdown(0)

	// Knocked down in the crouch: it just stands up out of it, no fall
	TEST_ASSERT(piece.try_leap(target), "It didn't crouch the fifth time")
	dust_before = dust_after
	criminal.Knockdown(1 SECONDS)
	TEST_ASSERT_EQUAL(piece.phase, 0, "Knocked down in the crouch, it is still leaping") // BOUNTY_PILEDRIVER_IDLE
	TEST_ASSERT_NULL(criminal.get_filter("bounty_piledriver_glow"), "Knocked down in the crouch, the outline stayed on")
	dust_after = 0
	for(var/obj/effect/temp_visual/mook_dust/small/dust in tile(0, 0))
		dust_after++
	TEST_ASSERT_EQUAL(dust_after, dust_before, "Knocked down in the crouch, it fell as if from the air")

/// Death and deletion mid-leap leave nothing behind
/datum/unit_test/voidcrew_bounty_chrome_piledriver/cleanup

/datum/unit_test/voidcrew_bounty_chrome_piledriver/cleanup/Run()
	var/datum/bounty_chrome/piledriver/piece = leaper_at(tile(0, 0))
	var/mob/living/basic/bounty_criminal/normal/criminal = piece.owner
	var/mob/living/carbon/human/consistent/target = hunter_at(tile(3, 0))
	TEST_ASSERT(piece.try_leap(target), "It didn't crouch")
	TEST_ASSERT(piece.launch(piece.serial), "It didn't launch")
	criminal.death()
	TEST_ASSERT_EQUAL(piece.phase, 0, "Dead, it is still leaping") // BOUNTY_PILEDRIVER_IDLE
	TEST_ASSERT(!shadow_on(tile(3, 0)), "Dead, its shadow stayed")
	TEST_ASSERT(!held(criminal), "Dead, it is still held")
	TEST_ASSERT(!piece.try_leap(target), "A dead criminal leapt")

	var/datum/bounty_chrome/piledriver/second = leaper_at(tile(0, 4))
	var/mob/living/basic/bounty_criminal/normal/other = second.owner
	var/mob/living/carbon/human/consistent/second_target = hunter_at(tile(4, 4))
	TEST_ASSERT(second.try_leap(second_target), "The second criminal didn't crouch")
	TEST_ASSERT(second.launch(second.serial), "The second criminal didn't launch")
	TEST_ASSERT(shadow_on(tile(4, 4)), "No shadow under the second target")
	qdel(other)
	TEST_ASSERT(QDELETED(second), "The piece outlived its criminal")
	TEST_ASSERT_NULL(second.owner, "The deleted piece kept its criminal")
	TEST_ASSERT(!shadow_on(tile(4, 4)), "The shadow outlived its criminal")

/// The Pyromaniac leaps inside its busy state, never over one of its own abilities, and reels when an EMP drops it
/datum/unit_test/voidcrew_bounty_chrome_piledriver/boss

/datum/unit_test/voidcrew_bounty_chrome_piledriver/boss/Run()
	var/mob/living/basic/bounty_criminal/boss/pyromaniac/boss = allocate(/mob/living/basic/bounty_criminal/boss/pyromaniac, tile(0, 0))
	bounty_chrome_install(boss, list("piledriver"))
	var/datum/bounty_chrome/piledriver/piece = bounty_chrome_piece(boss, "piledriver")
	var/mob/living/carbon/human/consistent/target = hunter_at(tile(3, 0))
	TEST_ASSERT_NOTNULL(piece, "The Pyromaniac has no piledriver")

	var/busy_serial = boss.boss_set_busy("windup", 1 SECONDS)
	TEST_ASSERT(!piece.try_leap(target), "It leapt in the middle of its own ability")
	boss.boss_clear_busy(busy_serial)
	boss.boss_next_ability_at = 0

	TEST_ASSERT(piece.try_leap(target), "The Pyromaniac didn't crouch")
	TEST_ASSERT_EQUAL(boss.boss_busy, "bounty_chrome_piledriver", "The leap isn't its busy state") // BOUNTY_PILEDRIVER_SOURCE
	TEST_ASSERT(boss.boss_next_ability_at > world.time, "Its next ability may start in the middle of the leap")
	TEST_ASSERT(piece.launch(piece.serial), "The Pyromaniac didn't launch")
	TEST_ASSERT(piece.land(piece.serial), "The Pyromaniac didn't land")
	TEST_ASSERT_EQUAL(boss.loc, tile(3, 0), "The Pyromaniac didn't land on the shadow")
	TEST_ASSERT(target.getBruteLoss() > 0, "The Pyromaniac's landing didn't crush its target")
	TEST_ASSERT_EQUAL(boss.boss_busy, "bounty_chrome_piledriver", "The Pyromaniac isn't held while it vents")
	TEST_ASSERT(piece.recover(piece.serial), "The Pyromaniac's vent didn't end")
	TEST_ASSERT_NULL(boss.boss_busy, "Done, the Pyromaniac is still busy")

	// An EMP in the air: it reels where it stood
	target.forceMove(tile(0, 0))
	boss.boss_next_ability_at = 0
	TEST_ASSERT(piece.try_leap(target), "The Pyromaniac didn't crouch the second time")
	TEST_ASSERT(piece.launch(piece.serial), "The Pyromaniac didn't launch the second time")
	boss.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(piece.phase, 0, "An EMP in the air didn't drop the Pyromaniac") // BOUNTY_PILEDRIVER_IDLE
	TEST_ASSERT_EQUAL(boss.loc, tile(3, 0), "Dropped by an EMP, the Pyromaniac still reached the landing")
	TEST_ASSERT_EQUAL(boss.boss_busy, "stagger", "Dropped by an EMP, the Pyromaniac isn't reeling")

// ===== RENDERS =====

/**
 * Not a check: draws the worn frame to data/bounty_chrome_renders/ for a person to look at. A dummy
 * per look, facing south, and the bare one from the side too.
 */
/datum/unit_test/voidcrew_bounty_chrome_piledriver/renders

/datum/unit_test/voidcrew_bounty_chrome_piledriver/renders/Run()
	var/list/looks = list(
		"1" = list(/datum/species/human, null),
		"2" = list(/datum/species/lizard, /datum/outfit/bounty_criminal/tough),
		"3" = list(/datum/species/human, /datum/outfit/bounty_boss/pyromaniac),
		"4" = list(/datum/species/moth, /datum/outfit/hermit/survivor),
	)
	for(var/look_name in looks)
		var/list/spec = looks[look_name]
		var/datum/bounty_look/look = bounty_roll_look(spec[1], MALE)
		var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, spec[2], null, chrome_organs = bounty_chrome_organ_looks(list("piledriver")))
		TEST_ASSERT(dummy, "The [look_name] look could not be built")
		if(!dummy)
			continue
		dummy.setDir(SOUTH)
		fcopy(getFlatIcon(dummy, SOUTH), "data/bounty_chrome_renders/piledriver_[look_name].png")
		if(look_name == "1")
			dummy.setDir(EAST)
			fcopy(getFlatIcon(dummy, EAST), "data/bounty_chrome_renders/piledriver_[look_name]_side.png")
		qdel(dummy)
