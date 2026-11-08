/**
 * Mantis Blades on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_mantis.dm).
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming
 * the define. The test room is a 5x5 floor; the lunge tests wait on the dash's own timers.
 */
/datum/unit_test/voidcrew_bounty_chrome_mantis
	/// The record a test criminal fights by, so its style stays the one the test gave it
	var/datum/bounty_record/test_record

/datum/unit_test/voidcrew_bounty_chrome_mantis/Destroy()
	test_record = null
	return ..()

/// The floor tile `dx`, `dy` from the room's bottom left
/datum/unit_test/voidcrew_bounty_chrome_mantis/proc/tile(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A hunter at `where`: a human with a mind, as a player would be
/datum/unit_test/voidcrew_bounty_chrome_mantis/proc/hunter_at(turf/where)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, where)
	hunter.mind_initialize()
	return hunter

/// A Petty knife criminal at `where` with the blades in
/datum/unit_test/voidcrew_bounty_chrome_mantis/proc/criminal_at(turf/where)
	var/mob/living/basic/bounty_criminal/normal/criminal = allocate(/mob/living/basic/bounty_criminal/normal, where)
	if(!test_record)
		test_record = new
		test_record.style = "knife" // BOUNTY_STYLE_KNIFE
		test_record.tier = 1 // BOUNTY_TIER_PETTY
		test_record.archetype = "normal" // BOUNTY_ARCHETYPE_NORMAL
	criminal.record = test_record
	bounty_ai_apply_style(criminal, "knife")
	bounty_chrome_install(criminal, list("mantis")) // BOUNTY_CHROME_MANTIS
	return criminal

/// Whether the examine text of `fighter` has `text` in it
/datum/unit_test/voidcrew_bounty_chrome_mantis/proc/examine_has(mob/living/fighter, text)
	for(var/line in fighter.examine(fighter))
		if(findtext(line, text))
			return TRUE
	return FALSE

/// Telegraph marks on `turfs`
/datum/unit_test/voidcrew_bounty_chrome_mantis/proc/marks_on(list/turfs)
	. = 0
	for(var/turf/spot as anything in turfs)
		for(var/obj/effect/temp_visual/bounty_boss_mark/mark in spot)
			.++

/datum/unit_test/voidcrew_bounty_chrome_mantis/Run()
	var/obj/item/blade = /obj/item/melee/energy/blade/hardlight/cyberware_mantis
	var/obj/item/kitchen_knife = /obj/item/knife/kitchen

	// ----- Who rolls it -----
	var/datum/bounty_chrome/proto = GLOB.bounty_chrome_protos["mantis"] // BOUNTY_CHROME_MANTIS
	TEST_ASSERT_NOTNULL(proto, "No Mantis Blades prototype")
	TEST_ASSERT(proto.weight > 0, "Mantis Blades never roll")
	for(var/style in list("brawler", "knife", "club"))
		TEST_ASSERT(proto.can_roll(1, "normal", style, null, list()), "A Petty [style] criminal can't roll Mantis Blades") // BOUNTY_TIER_PETTY, BOUNTY_ARCHETYPE_NORMAL
		TEST_ASSERT(proto.can_roll(1, "companion", style, null, list()), "A [style] companion can't roll Mantis Blades") // BOUNTY_CHROME_COMPANION
	for(var/style in list("pistol", "smg", "revolver", "shotgun", "bottle"))
		TEST_ASSERT(!proto.can_roll(3, "normal", style, null, list()), "A [style] criminal rolled Mantis Blades")
		TEST_ASSERT(!proto.can_roll(3, "companion", style, null, list()), "A [style] companion rolled Mantis Blades")
	TEST_ASSERT(!proto.can_roll(3, "meek", "holdout", null, list()), "A meek criminal rolled Mantis Blades") // BOUNTY_ARCHETYPE_MEEK
	for(var/kit in list("juggernaut", "ghost", "heavy", "pyromaniac", "demolitionist"))
		TEST_ASSERT(!proto.can_roll(3, "boss", null, kit, list()), "The [kit] mini-boss rolled Mantis Blades") // BOUNTY_ARCHETYPE_BOSS
	TEST_ASSERT(!proto.can_roll(3, "normal", "knife", null, list("gorilla")), "Mantis Blades rolled beside Gorilla Arms") // BOUNTY_CHROME_GORILLA
	TEST_ASSERT(!proto.can_roll(3, "normal", "knife", null, list("piledriver")), "Mantis Blades rolled beside the Piledriver") // BOUNTY_CHROME_PILEDRIVER
	var/rolled = FALSE
	for(var/i in 1 to 300)
		var/list/keys = bounty_roll_chrome(3, "normal", "brawler", null)
		if("mantis" in keys)
			rolled = TRUE
		TEST_ASSERT(!("mantis" in bounty_roll_chrome(3, "normal", "pistol", null)), "A pistol criminal's roll gave Mantis Blades")
	TEST_ASSERT(rolled, "300 Most Wanted brawlers never rolled Mantis Blades")

	// ----- Housings on, blades in, until the fight -----
	var/mob/living/carbon/human/consistent/hunter = hunter_at(tile(3, 2))
	var/mob/living/basic/bounty_criminal/normal/criminal = criminal_at(tile(0, 2))
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome/mantis/piece = bounty_chrome_piece(criminal, "mantis")
	TEST_ASSERT_NOTNULL(piece, "The criminal has no Mantis Blades")
	TEST_ASSERT(!piece.deployed, "The blades are out before any fight")
	TEST_ASSERT(examine_has(criminal, "housings"), "Examining them doesn't show the housings")

	// The fight starts: the blades come out, one in each hand, and hit as the real blade does
	TEST_ASSERT(criminal.ai_start_fight(hunter), "The criminal wouldn't fight")
	TEST_ASSERT(piece.deployed, "The blades didn't come out when the fight started")
	TEST_ASSERT_EQUAL(criminal.ai_controller.blackboard["bb_bounty_weapon"], blade, "The blade isn't their weapon") // BB_BOUNTY_WEAPON
	TEST_ASSERT_EQUAL(criminal.melee_damage_upper, initial(blade.force), "The blades don't hit like a mantis blade")
	TEST_ASSERT_EQUAL(criminal.sharpness, SHARP_EDGED, "The blades don't cut")
	TEST_ASSERT_EQUAL(criminal.armour_penetration, initial(blade.armour_penetration), "The blades lost their armour penetration")
	TEST_ASSERT_EQUAL(criminal.ai_hand?.held_type, blade, "The right hand doesn't show a blade")
	TEST_ASSERT(piece.left_blade && (piece.left_blade in criminal.vis_contents), "The left hand doesn't show a blade")
	TEST_ASSERT(examine_has(criminal, "Hardlight blades"), "Examining them doesn't show the blades out")

	// ----- The lunge: a marked line through the hunter, then a dash down all of it -----
	piece.next_lunge_at = 0
	TEST_ASSERT(piece.can_lunge(hunter), "No lunge at a hunter three tiles off in a clear line")
	TEST_ASSERT(piece.start_lunge(hunter), "The lunge didn't start")
	TEST_ASSERT_EQUAL(piece.lunge_state, "windup", "The lunge didn't wind up first")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_mantis"), "They don't plant their feet for the wind-up")
	var/list/path = piece.lunge_path.Copy()
	TEST_ASSERT_EQUAL(length(path), 4, "The line doesn't run on past the hunter to the room's far wall")
	TEST_ASSERT_EQUAL(path[length(path)], tile(4, 2), "The line doesn't end at the far wall")
	TEST_ASSERT(tile(3, 2) in path, "The line doesn't run through the hunter")
	TEST_ASSERT_EQUAL(marks_on(path), length(path), "The line isn't marked on the floor")
	TEST_ASSERT(!piece.can_lunge(hunter), "A second lunge could start during the first")
	var/health_before = hunter.health
	TEST_ASSERT(piece.begin_dash(piece.lunge_serial), "The dash didn't start when the wind-up ended")
	TEST_ASSERT_EQUAL(marks_on(path), 0, "The marks stayed on the floor once the dash began")
	sleep(1 SECONDS)
	TEST_ASSERT(hunter.health < health_before, "The lunge didn't cut the hunter on the line")
	TEST_ASSERT(hunter.IsKnockdown(), "The lunge didn't put the hunter down")
	TEST_ASSERT(hunter.has_status_effect(/datum/status_effect/bounty_boss_bleed), "The hunter isn't bleeding from the lunge")
	TEST_ASSERT_EQUAL(get_turf(criminal), tile(4, 2), "The dash didn't carry them down the whole line")
	TEST_ASSERT_EQUAL(piece.lunge_state, "recover", "They didn't have to recover after the lunge")
	TEST_ASSERT(piece.lunge_hit, "The lunge didn't count the cut")
	TEST_ASSERT(criminal.next_move > world.time, "They can swing straight after the lunge")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_mantis"), "They can walk straight after the lunge")
	sleep(1.5 SECONDS) // BOUNTY_MANTIS_RECOVER_HIT 1.2 seconds
	TEST_ASSERT_NULL(piece.lunge_state, "The recovery never ended")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_mantis"), "They stayed rooted after the recovery")

	// ----- Sidestepping the line: the dash doesn't turn, and cuts nobody -----
	var/mob/living/carbon/human/consistent/dodger = hunter_at(tile(3, 0))
	criminal.forceMove(tile(0, 0))
	piece.next_lunge_at = 0
	TEST_ASSERT(piece.start_lunge(dodger), "No lunge at the second hunter")
	dodger.forceMove(tile(3, 1))
	var/dodger_health = dodger.health
	piece.begin_dash(piece.lunge_serial)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(dodger.health, dodger_health, "The lunge followed a hunter who stepped off the line")
	TEST_ASSERT_EQUAL(get_turf(criminal), tile(4, 0), "The dash didn't follow its marked line")
	TEST_ASSERT(!piece.lunge_hit, "A lunge that cut nobody counted as a hit")
	TEST_ASSERT_EQUAL(piece.lunge_state, "recover", "A missed lunge left them no recovery")
	sleep(2.5 SECONDS) // BOUNTY_MANTIS_RECOVER_WHIFF 2 seconds
	TEST_ASSERT_NULL(piece.lunge_state, "The recovery after a miss never ended")

	// ----- Tables and doors -----
	// No lunge across a table
	criminal.forceMove(tile(0, 4))
	var/mob/living/carbon/human/consistent/behind_table = hunter_at(tile(4, 4))
	var/obj/structure/table/table = allocate(/obj/structure/table, tile(2, 4))
	piece.next_lunge_at = 0
	TEST_ASSERT(!piece.can_lunge(behind_table), "They lunged across a table")
	qdel(table)
	// Nor at someone already on the floor, whom the blades would pass over
	var/mob/living/carbon/human/consistent/floored = hunter_at(tile(2, 2))
	floored.Knockdown(5 SECONDS)
	TEST_ASSERT(!piece.can_lunge(floored), "They lunged at a hunter already on the floor")
	qdel(floored)
	// A door shut on the line during the wind-up stops the dash at the door
	TEST_ASSERT(piece.can_lunge(behind_table), "No lunge once the table was gone")
	TEST_ASSERT(piece.start_lunge(behind_table), "The lunge at the hunter by the door didn't start")
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, tile(2, 4))
	var/door_side_health = behind_table.health
	piece.begin_dash(piece.lunge_serial)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(criminal), tile(1, 4), "The dash went through a shut door")
	TEST_ASSERT_EQUAL(behind_table.health, door_side_health, "The lunge reached a hunter behind a shut door")
	qdel(door)
	sleep(2.5 SECONDS) // BOUNTY_MANTIS_RECOVER_WHIFF 2 seconds

	// ----- A friend standing on the line: no lunge that stops short of its target -----
	var/mob/living/basic/bounty_companion/buddy = allocate(/mob/living/basic/bounty_companion, tile(2, 4))
	buddy.leader_ref = WEAKREF(criminal)
	criminal.forceMove(tile(0, 4))
	piece.next_lunge_at = 0
	TEST_ASSERT(!piece.start_lunge(behind_table), "They lunged with a friend standing in the line")
	TEST_ASSERT_NULL(piece.lunge_state, "A refused lunge still wound up")
	qdel(buddy)

	// ----- A shield blocks it, and they stagger -----
	var/mob/living/carbon/human/consistent/shield_bearer = hunter_at(tile(3, 0))
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot)
	shield_bearer.put_in_active_hand(shield)
	criminal.forceMove(tile(0, 0))
	piece.next_lunge_at = 0
	TEST_ASSERT(piece.start_lunge(shield_bearer), "No lunge at the hunter with a shield")
	var/shield_health = shield_bearer.health
	piece.begin_dash(piece.lunge_serial)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(shield_bearer.health, shield_health, "The lunge went through a shield")
	TEST_ASSERT(!shield_bearer.IsKnockdown(), "A shield didn't keep the hunter on their feet")
	TEST_ASSERT_EQUAL(get_turf(criminal), tile(2, 0), "The dash didn't stop at the shield")
	TEST_ASSERT_EQUAL(piece.lunge_state, "recover", "Hitting a shield didn't stagger them")
	sleep(3 SECONDS) // BOUNTY_MANTIS_RECOVER_BLOCKED 2.5 seconds

	// ----- An EMP pulls the blades and stops a lunge mid wind-up -----
	criminal.forceMove(tile(0, 2))
	var/mob/living/carbon/human/consistent/emp_target = hunter_at(tile(3, 3))
	piece.next_lunge_at = 0
	TEST_ASSERT(piece.start_lunge(emp_target), "No lunge before the EMP")
	var/list/emp_path = piece.lunge_path.Copy()
	criminal.emp_act(EMP_HEAVY)
	TEST_ASSERT(!piece.online(), "The blades work through an EMP")
	TEST_ASSERT(!piece.deployed, "The blades stayed out through an EMP")
	TEST_ASSERT_NULL(piece.lunge_state, "The lunge carried on through an EMP")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_mantis"), "An EMP mid wind-up left them rooted")
	TEST_ASSERT_EQUAL(marks_on(emp_path), 0, "An EMP mid wind-up left the line marked")
	TEST_ASSERT_EQUAL(criminal.ai_controller.blackboard["bb_bounty_weapon"], kitchen_knife, "Their knife didn't come back with the blades in") // BB_BOUNTY_WEAPON
	TEST_ASSERT_EQUAL(criminal.melee_damage_upper, initial(kitchen_knife.force), "With the blades in, they still hit like a blade")
	TEST_ASSERT_EQUAL(criminal.ai_hand?.held_type, kitchen_knife, "Their knife isn't back in hand mid-fight")
	TEST_ASSERT_NULL(piece.left_blade, "The left blade stayed out through an EMP")
	for(var/obj/effect/abstract/bounty_held/held in criminal.vis_contents)
		TEST_ASSERT(held.held_type != blade, "A blade is still drawn on them through an EMP")
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(criminal), tile(0, 2), "The lunge dashed after the EMP")
	// It reboots, and the blades come back in the fight
	piece.offline_until = world.time
	chrome.tick(2)
	TEST_ASSERT(piece.online(), "The blades never came back from the EMP")
	TEST_ASSERT(piece.deployed, "Back from the EMP mid-fight, the blades didn't come out again")

	// ----- Out of the fight, the blades go away and the knife comes back -----
	criminal.ai_calm_down()
	chrome.tick(2)
	TEST_ASSERT(!piece.deployed, "The blades stayed out after the fight")
	TEST_ASSERT_EQUAL(criminal.ai_controller.blackboard["bb_bounty_weapon"], kitchen_knife, "Their knife didn't come back after the fight") // BB_BOUNTY_WEAPON
	TEST_ASSERT(criminal.ai_hand?.held_type != blade, "A blade is still in their hand after the fight")

	// ----- Death and deletion leave nothing behind -----
	criminal.ai_start_fight(hunter)
	TEST_ASSERT(piece.deployed, "The blades didn't come out for a second fight")
	criminal.death()
	TEST_ASSERT(!piece.deployed, "The blades stayed out on a body")
	TEST_ASSERT_NULL(piece.left_blade, "The left blade stayed on a body")
	var/mob/living/basic/bounty_criminal/normal/doomed = criminal_at(tile(4, 4))
	var/datum/bounty_chrome/mantis/doomed_piece = bounty_chrome_piece(doomed, "mantis")
	doomed.ai_start_fight(hunter)
	TEST_ASSERT(doomed_piece.deployed, "The blades didn't come out for the doomed criminal")
	var/obj/effect/abstract/bounty_held/left = doomed_piece.left_blade
	qdel(doomed)
	TEST_ASSERT(QDELETED(left), "The left blade outlived its criminal")
	TEST_ASSERT_NULL(doomed_piece.owner, "The piece kept its deleted criminal")

	// ----- A companion: the blades out in the fight, its fists back after -----
	var/mob/living/basic/bounty_companion/companion = allocate(/mob/living/basic/bounty_companion, tile(1, 1))
	companion.ai_take_style("brawler") // BOUNTY_STYLE_BRAWLER
	bounty_chrome_install(companion, list("mantis"))
	var/datum/bounty_chrome/mantis/companion_piece = bounty_chrome_piece(companion, "mantis")
	companion.ai_enter_fight()
	TEST_ASSERT(companion_piece.deployed, "A companion's blades didn't come out in the fight")
	TEST_ASSERT_EQUAL(companion.melee_damage_upper, initial(blade.force), "A companion's blades don't hit like a mantis blade")
	TEST_ASSERT_EQUAL(companion.ai_hand?.held_type, blade, "A companion's hand doesn't show a blade")
	companion.ai_leave_fight()
	var/datum/component/bounty_chrome/companion_chrome = companion.GetComponent(/datum/component/bounty_chrome)
	companion_chrome.tick(2)
	TEST_ASSERT(!companion_piece.deployed, "A companion's blades stayed out after the fight")
	TEST_ASSERT_NULL(companion.ai_controller.blackboard["bb_bounty_weapon"], "A brawler companion kept a weapon after the blades went in") // BB_BOUNTY_WEAPON
	var/obj/item/bodypart/arm/right/arm = /obj/item/bodypart/arm/right
	TEST_ASSERT_EQUAL(companion.melee_damage_upper, initial(arm.unarmed_damage_high), "A brawler companion's fists didn't come back")

	// ----- The worn look: both housings go into the look dummy -----
	var/datum/bounty_look/look = bounty_roll_look(/datum/species/human, MALE)
	var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, null, null, chrome_organs = bounty_chrome_organ_looks(list("mantis")))
	TEST_ASSERT_NOTNULL(dummy, "The look dummy failed with Mantis Blades")
	if(dummy)
		TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left) in dummy.organs, "The left housing isn't on the look dummy")
		var/right_found = FALSE
		for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing in dummy.organs)
			if(!istype(housing, /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left))
				right_found = TRUE
		TEST_ASSERT(right_found, "The right housing isn't on the look dummy")
		qdel(dummy)

	// Regression (augments_internal.dm, cyberimp Destroy): a worn implant deleted in place leaves no dead
	// overlay on its limb, and a clothed dummy wearing chrome deletes without a runtime, as the look builder does
	var/mob/living/carbon/human/dummy/clothed = bounty_look_dummy(look, /datum/outfit/bounty_criminal/tough, null, chrome_organs = bounty_chrome_organ_looks(list("mantis")))
	TEST_ASSERT_NOTNULL(clothed, "The clothed look dummy failed with Mantis Blades")
	if(clothed)
		var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left/housing = locate() in clothed.organs
		var/obj/item/bodypart/limb = housing?.bodypart_owner
		TEST_ASSERT_NOTNULL(limb, "The left housing isn't in an arm")
		qdel(housing)
		for(var/datum/bodypart_overlay/augment/overlay in limb?.bodypart_overlays)
			TEST_ASSERT_NOTNULL(overlay.implant, "Deleting an implanted organ left a dead overlay on its limb")
		clothed.update_body_parts()
		qdel(clothed)

/**
 * Not a check: draws the worn housings and the blades out to data/bounty_chrome_renders/ for a person
 * to look at. Each look three ways: housings only, blades out facing south, blades out facing east.
 * The blades are the NPC's own in-hand states laid over the body, as its vis_contents draw them.
 */
/datum/unit_test/voidcrew_bounty_chrome_mantis/renders

/datum/unit_test/voidcrew_bounty_chrome_mantis/renders/Run()
	var/datum/outfit/bare = new
	bare.name = "Mantis render: bare arms"
	bare.uniform = /obj/item/clothing/under/pants/jeans
	bare.shoes = /obj/item/clothing/shoes/workboots
	var/list/looks = list(
		"1_human_bare" = list(/datum/species/human, bare),
		"2_lizard_tough" = list(/datum/species/lizard, /datum/outfit/bounty_criminal/tough),
		"3_moth_survivor" = list(/datum/species/moth, /datum/outfit/hermit/survivor),
	)
	var/obj/item/blade = /obj/item/melee/energy/blade/hardlight/cyberware_mantis
	for(var/look_name in looks)
		var/list/spec = looks[look_name]
		var/datum/bounty_look/look = bounty_roll_look(spec[1], MALE)
		var/mob/living/carbon/human/dummy/dummy = bounty_look_dummy(look, spec[2], null, chrome_organs = bounty_chrome_organ_looks(list("mantis"))) // BOUNTY_CHROME_MANTIS
		TEST_ASSERT(dummy, "The [look_name] look could not be built")
		if(!dummy)
			continue
		dummy.setDir(SOUTH)
		fcopy(getFlatIcon(dummy, SOUTH), "data/bounty_chrome_renders/mantis_[look_name].png")
		for(var/facing in list(SOUTH, EAST))
			var/icon/out = getFlatIcon(dummy, facing)
			out.Blend(icon(initial(blade.righthand_file), initial(blade.inhand_icon_state), facing), ICON_OVERLAY)
			out.Blend(icon(initial(blade.lefthand_file), initial(blade.inhand_icon_state), facing), ICON_OVERLAY)
			fcopy(out, "data/bounty_chrome_renders/mantis_[look_name]_blades_[dir2text(facing)].png")
		qdel(dummy)
	// One tile of the marked line, first frame, in its colour
	var/icon/mark = icon('icons/mob/telegraphing/telegraph_holographic.dmi', "target_box", SOUTH, 1)
	mark.MapColors(0.42, 0.72, 1, 0, 0, 0, 0, 0, 0) // BOUNTY_MANTIS_MARK_COLOR
	fcopy(mark, "data/bounty_chrome_renders/mantis_mark.png")
	qdel(bare)
