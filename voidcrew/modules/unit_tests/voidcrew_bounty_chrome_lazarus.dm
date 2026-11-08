/// Lazarus on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_lazarus.dm): who rolls it, the charge and the jolt, what stops it, and clean-up
/datum/unit_test/voidcrew_bounty_chrome_lazarus

/// A new criminal of `criminal_type` with Lazarus in, at the test's corner
/datum/unit_test/voidcrew_bounty_chrome_lazarus/proc/lazarus_criminal(criminal_type = /mob/living/basic/bounty_criminal/normal)
	var/mob/living/basic/bounty_criminal/criminal = allocate(criminal_type, run_loc_floor_bottom_left)
	bounty_chrome_install(criminal, list("lazarus")) // BOUNTY_CHROME_LAZARUS
	return criminal

/// Puts `criminal` down at the downed line, as a hunter's hit would (the mercy rule stops it just under)
/datum/unit_test/voidcrew_bounty_chrome_lazarus/proc/knock_down(mob/living/basic/bounty_criminal/criminal)
	criminal.adjust_health(criminal.maxHealth)
	TEST_ASSERT(criminal.downed, "[criminal] didn't go down")

/// Whether any line `who` sees examining `target` has `text` in it
/datum/unit_test/voidcrew_bounty_chrome_lazarus/proc/examine_has(mob/living/target, mob/who, text)
	for(var/line in target.examine(who))
		if(findtext(line, text))
			return TRUE
	return FALSE

/datum/unit_test/voidcrew_bounty_chrome_lazarus/Run()
	var/datum/bounty_chrome/lazarus/proto = GLOB.bounty_chrome_protos["lazarus"] // BOUNTY_CHROME_LAZARUS
	TEST_ASSERT_NOTNULL(proto, "No Lazarus prototype")
	TEST_ASSERT(proto.weight > 0, "Lazarus never rolls")

	// Who rolls it: Wanted and up (tier 2, BOUNTY_TIER_WANTED), never the meek; every kit; companions of a Wanted criminal
	TEST_ASSERT(!proto.can_roll(1, "normal", "pistol", null, list()), "A Petty criminal can roll Lazarus") // BOUNTY_TIER_PETTY, BOUNTY_ARCHETYPE_NORMAL
	TEST_ASSERT(proto.can_roll(2, "normal", "pistol", null, list()), "A Wanted pistol criminal can't roll Lazarus")
	TEST_ASSERT(proto.can_roll(3, "normal", "brawler", null, list()), "A Most Wanted brawler can't roll Lazarus")
	TEST_ASSERT(!proto.can_roll(3, "meek", "holdout", null, list()), "A meek criminal can roll Lazarus") // BOUNTY_ARCHETYPE_MEEK
	for(var/kit in list("juggernaut", "pyromaniac", "demolitionist", "ghost", "heavy")) // BOUNTY_KIT_*
		TEST_ASSERT(proto.can_roll(3, "boss", null, kit, list()), "A [kit] mini-boss can't roll Lazarus") // BOUNTY_ARCHETYPE_BOSS
	TEST_ASSERT(proto.can_roll(2, "companion", "knife", null, list()), "A Wanted criminal's companion can't roll Lazarus") // BOUNTY_CHROME_COMPANION
	TEST_ASSERT(!proto.can_roll(1, "companion", "knife", null, list()), "A Petty criminal's companion can roll Lazarus")
	for(var/i in 1 to 100)
		TEST_ASSERT(!("lazarus" in bounty_roll_chrome(3, "meek", "holdout", null)), "A meek criminal rolled Lazarus")
	var/rolled = FALSE
	for(var/i in 1 to 300)
		if("lazarus" in bounty_pick_chrome(1, 3, "normal", "pistol", null))
			rolled = TRUE
			break
	TEST_ASSERT(rolled, "Lazarus never came up in 300 picks for a Most Wanted pistol criminal")

	// Down, it charges where everyone can see it, then jolts them up at half health with the recovery clock stopped
	var/mob/living/basic/bounty_criminal/criminal = lazarus_criminal()
	var/datum/bounty_chrome/lazarus/piece = bounty_chrome_piece(criminal, "lazarus")
	TEST_ASSERT_NOTNULL(piece, "Lazarus didn't go in")
	TEST_ASSERT(examine_has(criminal, criminal, "ribs hums"), "A ready Lazarus doesn't hum on examine")
	knock_down(criminal)
	TEST_ASSERT(piece.charging, "Going down didn't start the charge")
	TEST_ASSERT_NOTNULL(criminal.get_filter("bounty_lazarus_charge"), "The charge has no glow") // BOUNTY_LAZARUS_FILTER
	TEST_ASSERT_NOTNULL(piece.charge_light, "The charge gives off no light")
	TEST_ASSERT(piece.discharge(piece.charge_serial), "The full charge didn't jolt them")
	TEST_ASSERT(!criminal.downed, "The jolt didn't stand them up")
	TEST_ASSERT(criminal.health >= criminal.maxHealth * 0.5 - 1, "The jolt stood them up at [criminal.health]/[criminal.maxHealth], not half") // BOUNTY_LAZARUS_HEAL_TO
	TEST_ASSERT_NULL(criminal.body_recovery_timer, "The jolt left the recovery clock running")
	TEST_ASSERT(!piece.charging, "Still charging after the jolt")
	TEST_ASSERT_NULL(criminal.get_filter("bounty_lazarus_charge"), "The glow stayed on after the jolt")
	TEST_ASSERT_NULL(piece.charge_light, "The light stayed on after the jolt")
	TEST_ASSERT(!piece.discharge(piece.charge_serial), "A stale charge jolted twice")
	TEST_ASSERT(examine_has(criminal, criminal, "ribs ticks"), "A spent Lazarus doesn't tick on examine")

	// Spent: down again, nothing
	knock_down(criminal)
	TEST_ASSERT(!piece.charging, "A spent Lazarus charged again")

	// An EMP during the charge dumps it, and they stay down
	criminal = lazarus_criminal()
	piece = bounty_chrome_piece(criminal, "lazarus")
	knock_down(criminal)
	var/serial = piece.charge_serial
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT(!piece.charging, "An EMP didn't stop the charge")
	TEST_ASSERT_NULL(criminal.get_filter("bounty_lazarus_charge"), "The glow stayed on through an EMP")
	TEST_ASSERT(!piece.discharge(serial), "An EMP'd charge still jolted")
	TEST_ASSERT(criminal.downed, "An EMP'd criminal got up")
	piece.offline_until = world.time
	piece.check_reboot()
	TEST_ASSERT(!COOLDOWN_FINISHED(piece, recharge), "An EMP'd charge wasn't spent")

	// Cuffed during the charge: it fizzles, and they stay down and cuffed
	criminal = lazarus_criminal()
	piece = bounty_chrome_piece(criminal, "lazarus")
	knock_down(criminal)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs, run_loc_floor_bottom_left)
	TEST_ASSERT(criminal.body_apply_cuffs(cuffs, null), "Couldn't cuff a downed criminal")
	TEST_ASSERT(!piece.discharge(piece.charge_serial), "A cuffed criminal jolted up")
	TEST_ASSERT(criminal.downed && criminal.is_restrained(), "The fizzle let a cuffed criminal up")
	TEST_ASSERT(!piece.charging, "Still charging after cuffs went on")

	// Cuffs going on when it is due: it waits, then jolts once the try fails
	criminal = lazarus_criminal()
	piece = bounty_chrome_piece(criminal, "lazarus")
	knock_down(criminal)
	serial = piece.charge_serial
	criminal.body_cuff_work = TRUE
	TEST_ASSERT(!piece.discharge(serial), "It jolted with cuffs going on")
	TEST_ASSERT(piece.charging && criminal.downed, "Cuffs going on didn't hold the charge")
	criminal.body_cuff_work = FALSE
	TEST_ASSERT(piece.discharge(serial), "A held charge didn't jolt once the cuffs failed")
	TEST_ASSERT(!criminal.downed, "A held charge left them down")

	// Shut in a locker during the charge: it fizzles
	criminal = lazarus_criminal()
	piece = bounty_chrome_piece(criminal, "lazarus")
	knock_down(criminal)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, run_loc_floor_bottom_left)
	criminal.forceMove(locker)
	TEST_ASSERT(!piece.discharge(piece.charge_serial), "A criminal in a locker jolted up")
	TEST_ASSERT(criminal.downed, "A criminal in a locker got up")
	criminal.forceMove(run_loc_floor_bottom_left)

	// Given up first: no charge at all
	criminal = lazarus_criminal()
	piece = bounty_chrome_piece(criminal, "lazarus")
	ADD_TRAIT(criminal, "bounty_surrendered", "unit_test") // TRAIT_BOUNTY_SURRENDERED
	knock_down(criminal)
	TEST_ASSERT(!piece.charging, "A criminal who gave up charged")

	// Taken down with stamina: it never fires
	criminal = lazarus_criminal()
	piece = bounty_chrome_piece(criminal, "lazarus")
	criminal.adjustStaminaLoss(1000, forced = TRUE)
	TEST_ASSERT(!criminal.downed, "Stamina downed them")
	TEST_ASSERT(!piece.charging, "A stamina takedown set Lazarus off")

	// Killed during the charge: it stops, cleans up, and never revives them
	criminal = lazarus_criminal()
	piece = bounty_chrome_piece(criminal, "lazarus")
	knock_down(criminal)
	serial = piece.charge_serial
	criminal.death()
	TEST_ASSERT(!piece.charging, "Still charging after death")
	TEST_ASSERT_NULL(criminal.get_filter("bounty_lazarus_charge"), "The glow stayed on a corpse")
	TEST_ASSERT_NULL(piece.charge_light, "The light stayed on a corpse")
	TEST_ASSERT(!piece.discharge(serial), "A dead criminal's charge jolted")
	TEST_ASSERT_EQUAL(criminal.stat, DEAD, "Lazarus revived the dead")

	// Deleted during the charge: nothing left behind
	criminal = lazarus_criminal()
	piece = bounty_chrome_piece(criminal, "lazarus")
	knock_down(criminal)
	var/obj/effect/dummy/lighting_obj/moblight/light = piece.charge_light
	TEST_ASSERT_NOTNULL(light, "No light to check")
	qdel(criminal)
	TEST_ASSERT(QDELETED(light), "The charge's light outlived its criminal")
	TEST_ASSERT_NULL(piece.owner, "The piece kept a deleted criminal")
	TEST_ASSERT_NULL(piece.charge_timer, "The charge's timer outlived its criminal")

	// A mini-boss gets up at its own recovery health, rallying
	var/mob/living/basic/bounty_criminal/boss/juggernaut/boss = lazarus_criminal(/mob/living/basic/bounty_criminal/boss/juggernaut)
	piece = bounty_chrome_piece(boss, "lazarus")
	knock_down(boss)
	TEST_ASSERT(piece.charging, "A downed mini-boss didn't charge")
	TEST_ASSERT(piece.discharge(piece.charge_serial), "A mini-boss's charge didn't jolt")
	TEST_ASSERT(!boss.downed, "The jolt didn't stand the mini-boss up")
	TEST_ASSERT(boss.health >= boss.maxHealth * 0.35 - 1 && boss.health < boss.maxHealth * 0.5, "The mini-boss got up at [boss.health]/[boss.maxHealth], not its recovery health") // BOUNTY_RECOVER_TO
	TEST_ASSERT(boss.body_is_rallying(), "The mini-boss didn't rally after the jolt")

	// A companion: giving up sets it off, and the jolt puts them back on their feet, hands down
	var/mob/living/basic/bounty_companion/buddy = allocate(/mob/living/basic/bounty_companion, run_loc_floor_bottom_left)
	bounty_chrome_install(buddy, list("lazarus"))
	piece = bounty_chrome_piece(buddy, "lazarus")
	buddy.adjust_health(buddy.maxHealth * 0.8)
	buddy.adjustStaminaLoss(1000, forced = TRUE)
	TEST_ASSERT(buddy.ai_gave_up, "Stamina crit didn't make the companion give up")
	TEST_ASSERT(piece.charging, "A companion giving up didn't charge")
	TEST_ASSERT(piece.discharge(piece.charge_serial), "The companion's charge didn't jolt")
	TEST_ASSERT(!buddy.ai_gave_up, "The jolted companion still has their hands up")
	TEST_ASSERT_NULL(buddy.ai_over_head, "The hands-up mark stayed")
	TEST_ASSERT_EQUAL(buddy.staminaloss, 0, "The jolt left the companion winded")
	TEST_ASSERT(!buddy.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "The jolted companion is still in stamina crit")
	TEST_ASSERT(buddy.health >= buddy.maxHealth * 0.5 - 1, "The companion got up at [buddy.health]/[buddy.maxHealth], not half")
	TEST_ASSERT(buddy.ai_can_fight(), "The jolted companion can't fight")

/**
 * Not a check: draws Lazarus fighters to data/bounty_chrome_renders/ for a person to look at. The node
 * sits inside the chest, so the worn looks show nothing of it; the charge looks show the arcs a fighter
 * wears while it charges (the glow outline and the light are not drawn by getFlatIcon()).
 */
/datum/unit_test/voidcrew_bounty_chrome_lazarus/renders/Run()
	var/list/looks = list(
		"lazarus_1_bare" = list(/datum/species/human, null, FALSE),
		"lazarus_2_lizard_tough" = list(/datum/species/lizard, /datum/outfit/bounty_criminal/tough, FALSE),
		"lazarus_3_charge_bare" = list(/datum/species/human, null, TRUE),
		"lazarus_4_charge_hauler" = list(/datum/species/human, /datum/outfit/bounty_criminal/hauler, TRUE),
	)
	for(var/look_name in looks)
		var/list/spec = looks[look_name]
		var/datum/bounty_look/look = bounty_roll_look(spec[1], MALE)
		var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, spec[2], null, chrome_organs = bounty_chrome_organ_looks(list("lazarus")))
		TEST_ASSERT(dummy, "The [look_name] look could not be built")
		if(!dummy)
			continue
		TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/lazarus) in dummy.organs, "The Lazarus node isn't in the [look_name] dummy")
		if(spec[3])
			dummy.add_overlay(bounty_lazarus_arcs())
		dummy.setDir(SOUTH)
		fcopy(getFlatIcon(dummy, SOUTH), "data/bounty_chrome_renders/[look_name].png")
		qdel(dummy)
