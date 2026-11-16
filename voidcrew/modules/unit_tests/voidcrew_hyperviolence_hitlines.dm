/**
 * Hyperviolence hit lines and bleeding NPCs: tests for voidcrew/modules/hyperviolence/hitlines/.
 *
 * Tests are included before the module files, so the module's own defines are written out here with
 * a comment naming them: HV_NPC_BLOOD_NONE 0, HV_NPC_BLOOD_LIGHT 1, HV_NPC_BLOOD_MEDIUM 2 and
 * HV_NPC_BLOOD_HEAVY 3; the queued-line indexes are 1 text, 2 self text, 3 severity and 4 range.
 * No test has a client, so a message is checked as the text compose() builds, not as a chat line.
 */

/// One hit: the attack line, then the bold lines after it, each reader getting their own copy.
/datum/unit_test/hv_hitlines_batch/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	victim.hv_hold_attack_message("Alice slashes Bob in the arm!", "Alice slashes you in the arm!", "You slash Bob in the arm!", attacker)
	victim.hv_add_hit_line("The bone in Bob's arm snaps!", HV_LINE_BOLD, "The bone in your arm snaps!")
	victim.hv_add_hit_line("Bob's arm is severed!", HV_LINE_HUGE)
	var/datum/hv_hit/hit = victim.hv_hit
	TEST_ASSERT_NOTNULL(hit, "Holding an attack line started no hit")
	TEST_ASSERT(hit.compose(), "A hit with an attack line and two lines had nothing to say")
	TEST_ASSERT_EQUAL(hit.near_range, COMBAT_MESSAGE_RANGE, "The attack line did not keep its own range")

	var/attack_at = findtext(hit.others_message, "Alice slashes Bob in the arm!")
	var/snap_at = findtext(hit.others_message, "<b>The bone in Bob's arm snaps!</b>")
	var/sever_at = findtext(hit.others_message, "<b><i>Bob's arm is severed!</i></b>")
	TEST_ASSERT(attack_at && snap_at && sever_at, "Onlookers did not read the attack and both lines: [hit.others_message]")
	TEST_ASSERT(attack_at < snap_at && snap_at < sever_at, "The lines did not follow the attack in the order they were queued: [hit.others_message]")

	TEST_ASSERT(findtext(hit.victim_message, "Alice slashes you in the arm!"), "The victim lost their own attack line: [hit.victim_message]")
	TEST_ASSERT(findtext(hit.victim_message, "<b>The bone in your arm snaps!</b>"), "The victim lost their own wound line: [hit.victim_message]")
	TEST_ASSERT(!findtext(hit.victim_message, "The bone in Bob's arm"), "The victim read the bystander line: [hit.victim_message]")
	TEST_ASSERT(findtext(hit.victim_message, "<b><i>Bob's arm is severed!</i></b>"), "A line with no self text did not fall back to its text: [hit.victim_message]")
	TEST_ASSERT(findtext(hit.attacker_message, "You slash Bob in the arm!") && findtext(hit.attacker_message, "Bob's arm is severed!"), "The attacker did not read their line with the wounds: [hit.attacker_message]")
	TEST_ASSERT_NULL(hit.far_message, "Lines at the attack's range were sent a second time")

	victim.hv_flush_hit()
	TEST_ASSERT_NULL(victim.hv_hit, "Sending the hit did not end it")

/// A line that carries further than the attack line still reaches the viewers beyond it, and only them.
/datum/unit_test/hv_hitlines_ranges/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.hv_hold_attack_message("Alice hits Bob!", "Alice hits you!")
	victim.hv_add_hit_line("Bob's arm snaps!")
	victim.hv_add_hit_line("Bob's head caves in!", HV_LINE_BOLD, null, DEFAULT_MESSAGE_RANGE)
	var/datum/hv_hit/hit = victim.hv_hit
	TEST_ASSERT(hit.compose(), "The hit had nothing to say")
	TEST_ASSERT_EQUAL(hit.near_range, COMBAT_MESSAGE_RANGE, "The attack line's range changed")
	TEST_ASSERT_EQUAL(hit.far_range, DEFAULT_MESSAGE_RANGE, "The wide line's range was lost")
	TEST_ASSERT(findtext(hit.others_message, "arm snaps") && findtext(hit.others_message, "head caves in"), "Close viewers did not read every line: [hit.others_message]")
	TEST_ASSERT(findtext(hit.far_message, "head caves in") && !findtext(hit.far_message, "arm snaps") && !findtext(hit.far_message, "Alice hits Bob"), "The far viewers read more than the wide line: [hit.far_message]")
	victim.hv_flush_hit()

	// With no attack line held, the nearest line sets the range and the wide one is the extra
	victim.hv_add_hit_line("Bob's leg snaps!")
	victim.hv_add_hit_line("Bob's head caves in!", HV_LINE_BOLD, null, DEFAULT_MESSAGE_RANGE)
	hit = victim.hv_hit
	TEST_ASSERT(hit.compose(), "Standalone lines had nothing to say")
	TEST_ASSERT_EQUAL(hit.near_range, COMBAT_MESSAGE_RANGE, "Standalone lines did not take the nearest line's range")
	TEST_ASSERT(!findtext(hit.others_message, "Alice"), "Standalone lines carried an attack line")
	TEST_ASSERT(findtext(hit.far_message, "head caves in"), "The wide standalone line was not sent beyond the close ones")
	victim.hv_flush_hit()

	// A wide line alone is one message at its own range
	victim.hv_add_hit_line("Bob's head caves in!", HV_LINE_BOLD, null, DEFAULT_MESSAGE_RANGE)
	hit = victim.hv_hit
	TEST_ASSERT(hit.compose(), "A lone wide line had nothing to say")
	TEST_ASSERT_EQUAL(hit.near_range, DEFAULT_MESSAGE_RANGE, "A lone wide line lost its range")
	TEST_ASSERT_NULL(hit.far_message, "A lone wide line was sent twice")
	victim.hv_flush_hit()

/// Lines queued with no attack line behind them go out on the next tick on their own.
/datum/unit_test/hv_hitlines_standalone/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.hv_add_hit_line("Bob's arm snaps!")
	victim.hv_add_hit_line("Bob's leg snaps!")
	TEST_ASSERT_NOTNULL(victim.hv_hit, "A line queued with no hit started none")
	TEST_ASSERT_EQUAL(length(victim.hv_hit.lines), 2, "Two lines on one tick were not merged")
	TEST_ASSERT_NULL(victim.hv_hit.others_text, "Standalone lines held an attack line")
	sleep(1 SECONDS)
	TEST_ASSERT_NULL(victim.hv_hit, "Nothing sent lines that were never joined to an attack")

/// A new attack line sends what was waiting instead of mixing the two hits, and one hit's queue is capped.
/datum/unit_test/hv_hitlines_queue/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.hv_hold_attack_message("first hit!", "first hit!")
	victim.hv_add_hit_line("first wound!")
	victim.hv_hold_attack_message("second hit!", "second hit!")
	TEST_ASSERT_EQUAL(victim.hv_hit.others_text, "second hit!", "The second hit did not replace the first")
	TEST_ASSERT_EQUAL(length(victim.hv_hit.lines), 0, "The first hit's wound followed the second hit")
	victim.hv_flush_hit()

	for(var/i in 1 to 20)
		victim.hv_add_hit_line("wound [i]!")
	TEST_ASSERT_EQUAL(length(victim.hv_hit.lines), 6, "One hit queued more than six plain lines") // HV_MAX_HIT_LINES
	victim.hv_add_hit_line("a limb comes off!", HV_LINE_HUGE)
	TEST_ASSERT_EQUAL(length(victim.hv_hit.lines), 7, "A full queue turned away the worst line")
	victim.hv_flush_hit()
	victim.hv_flush_hit() // nothing waiting is fine
	TEST_ASSERT_NULL(victim.hv_hit, "Sending an empty hit started one")

/// A mob deleted mid-hit still says what was done to it.
/datum/unit_test/hv_hitlines_destroy/Run()
	var/mob/living/carbon/human/doomed = new /mob/living/carbon/human/consistent(run_loc_floor_bottom_left)
	doomed.hv_hold_attack_message("Alice hits Bob!", "Alice hits you!")
	doomed.hv_add_hit_line("Bob is torn apart!", HV_LINE_HUGE)
	TEST_ASSERT_NOTNULL(doomed.hv_hit, "The doomed mob had no hit to send")
	qdel(doomed)
	TEST_ASSERT_NULL(doomed.hv_hit, "Deleting a mob left its hit unsent")

/// The wound and dismember messages of tg queue as lines instead of speaking for themselves.
/datum/unit_test/hv_hitlines_wounds/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/wound/slash/flesh/moderate/cut = new
	cut.apply_wound(arm)
	TEST_ASSERT_NOTNULL(victim.hv_hit, "A wound spoke for itself instead of queueing a line")
	TEST_ASSERT_EQUAL(length(victim.hv_hit.lines), 1, "A wound queued [length(victim.hv_hit.lines)] lines")
	var/list/wound_line = victim.hv_hit.lines[1]
	TEST_ASSERT(findtext(wound_line[1], "[victim]'s [arm.plaintext_zone]"), "The wound line does not name the limb: [wound_line[1]]") // text
	TEST_ASSERT(findtext(wound_line[2], "Your [arm.plaintext_zone]"), "The victim lost their own wound line: [wound_line[2]]") // self text
	TEST_ASSERT_EQUAL(wound_line[3], HV_LINE_BOLD, "A moderate wound was not a plain bold line") // severity
	TEST_ASSERT_EQUAL(wound_line[4], COMBAT_MESSAGE_RANGE, "A moderate wound carried further than tg's close range") // range
	victim.hv_flush_hit()

	var/obj/item/bodypart/other_arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	var/datum/wound/loss/severed = new
	severed.apply_dismember(other_arm, WOUND_SLASH)
	TEST_ASSERT_NOTNULL(victim.hv_hit, "A severed limb spoke for itself instead of queueing a line")
	var/list/sever_line = victim.hv_hit.lines[length(victim.hv_hit.lines)]
	TEST_ASSERT_EQUAL(sever_line[3], HV_LINE_HUGE, "A severed limb was not the biggest line") // severity
	TEST_ASSERT_EQUAL(sever_line[4], DEFAULT_MESSAGE_RANGE, "A severed limb lost tg's wide range") // range
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_R_ARM), "The arm was not severed")
	victim.hv_flush_hit()

/// A melee hit holds its attack line while the damage lands, then sends it.
/datum/unit_test/hv_hitlines_melee/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/blade = allocate(/obj/item/knife)
	held_while_hitting = null
	RegisterSignal(blade, COMSIG_ITEM_ATTACK_ZONE, PROC_REF(check_held))
	victim.attacked_by(blade, attacker)
	TEST_ASSERT(held_while_hitting, "The attack line was not held back while the blow landed")
	TEST_ASSERT_NULL(victim.hv_hit, "The attack line was never sent")

/// Whether the victim of the knife was holding an attack line at the moment the damage was dealt
/datum/unit_test/hv_hitlines_melee
	var/held_while_hitting

/datum/unit_test/hv_hitlines_melee/proc/check_held(datum/source, mob/living/target, mob/living/user, zone)
	SIGNAL_HANDLER
	held_while_hitting = !isnull(target.hv_hit?.others_text)

/// Organic NPCs are given blood; machines, bones and plants are not.
/datum/unit_test/hv_npc_blood_grants/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/basic/trooper/pirate = allocate(/mob/living/basic/trooper, spot)
	TEST_ASSERT_EQUAL(pirate.blood_volume, BLOOD_VOLUME_NORMAL, "A human-shaped trooper has no blood")
	TEST_ASSERT_NOTNULL(pirate.get_bloodtype(), "The trooper's blood has no type")
	var/mob/living/basic/cockroach/roach = allocate(/mob/living/basic/cockroach, spot)
	TEST_ASSERT(roach.blood_volume > 0, "An organic animal has no blood")
	var/mob/living/basic/skeleton/bones = allocate(/mob/living/basic/skeleton, spot)
	TEST_ASSERT_EQUAL(bones.blood_volume, 0, "A skeleton bleeds")
	var/mob/living/basic/hivebot/machine = allocate(/mob/living/basic/hivebot, spot)
	TEST_ASSERT_EQUAL(machine.blood_volume, 0, "A robot bleeds")
	var/mob/living/basic/mushroom/plant = allocate(/mob/living/basic/mushroom, spot)
	TEST_ASSERT_EQUAL(plant.blood_volume, 0, "A plant bleeds")

	// Blood leaves marks where it is spilled, and nothing else does
	pirate.add_splatter_floor(spot)
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood) in spot, "A bleeding trooper left nothing on the floor")
	for(var/obj/effect/decal/cleanable/blood/stain in spot)
		qdel(stain)
	machine.add_splatter_floor(spot)
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood) in spot, "A robot left blood on the floor")

/// Blood is for show: a wounded NPC keeps its blood and loses exactly the health it was dealt.
/datum/unit_test/hv_npc_blood_no_bleed_out/Run()
	var/mob/living/basic/trooper/pirate = allocate(/mob/living/basic/trooper, run_loc_floor_bottom_left)
	var/health_before = pirate.health
	pirate.adjustBruteLoss(health_before - 10)
	TEST_ASSERT_EQUAL(pirate.health, 10, "A wounded trooper lost health besides the damage it took")
	TEST_ASSERT_EQUAL(pirate.blood_volume, BLOOD_VOLUME_NORMAL, "A wounded trooper lost blood")
	TEST_ASSERT_EQUAL(pirate.get_bleed_rate(), 0, "A trooper has a bleeding rate")

/// The blood overlay is light, medium, then heavy as health falls, and goes when the NPC is healed.
/datum/unit_test/hv_npc_blood_overlay/Run()
	var/mob/living/basic/cow/cow = allocate(/mob/living/basic/cow, run_loc_floor_bottom_left)
	var/max_health = cow.maxHealth
	TEST_ASSERT_EQUAL(cow.hv_blood_stage, 0, "A healthy cow showed blood") // HV_NPC_BLOOD_NONE
	TEST_ASSERT(!hv_blood_overlay(cow), "A healthy cow had a blood overlay")

	cow.adjustBruteLoss(max_health * 3 / 10)
	TEST_ASSERT_EQUAL(cow.hv_blood_stage, 1, "A cow at 70% health did not show light blood") // HV_NPC_BLOOD_LIGHT
	TEST_ASSERT(hv_blood_overlay(cow), "A cow at 70% health had no blood overlay")
	TEST_ASSERT(cow.appearance_flags & KEEP_TOGETHER, "The inset blood needs the cow drawn as one group")

	cow.adjustBruteLoss(max_health * 2 / 10)
	TEST_ASSERT_EQUAL(cow.hv_blood_stage, 2, "A cow at 50% health did not show medium blood") // HV_NPC_BLOOD_MEDIUM
	TEST_ASSERT_EQUAL(hv_blood_overlay_count(cow), 1, "Medium blood stacked on the light blood")

	cow.adjustBruteLoss(max_health * 3 / 10)
	TEST_ASSERT_EQUAL(cow.hv_blood_stage, 3, "A cow at 20% health did not show heavy blood") // HV_NPC_BLOOD_HEAVY
	TEST_ASSERT_EQUAL(hv_blood_overlay_count(cow), 1, "Heavy blood stacked on the lighter blood")

	cow.adjustBruteLoss(-max_health)
	TEST_ASSERT_EQUAL(cow.hv_blood_stage, 0, "A healed cow kept its blood") // HV_NPC_BLOOD_NONE
	TEST_ASSERT(!hv_blood_overlay(cow), "A healed cow kept its blood overlay")
	TEST_ASSERT(!(cow.appearance_flags & KEEP_TOGETHER), "A healed cow was still drawn as one group")

/// How many blood overlays a mob wears
/datum/unit_test/proc/hv_blood_overlay_count(mob/living/target)
	var/count = 0
	for(var/mutable_appearance/overlay as anything in target.overlays)
		if(overlay.icon == 'voidcrew/modules/hyperviolence/hitlines/icons/npc_blood.dmi')
			count++
	return count

/// Whether a mob wears a blood overlay
/datum/unit_test/proc/hv_blood_overlay(mob/living/target)
	return hv_blood_overlay_count(target) > 0
