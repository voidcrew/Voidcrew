/**
 * # Mantis Blades x hyperviolence (voidcrew/modules/mantis_gore/)
 *
 * Arterial gashes, the impaling lunge, the scissor, the kill reset, the charged leap and the safe dash,
 * the X-slash, blood on the blades and the stance. Unit-test files compile before voidcrew/_DEFINES/, so
 * the fork's numbers are restated below under MG_ names.
 */

/// MANTIS_MOVE_IMPALE, MANTIS_MOVE_XSLASH
#define MG_MOVE_IMPALE (1<<1)
#define MG_MOVE_XSLASH (1<<3)
/// MANTIS_IMPALE_TRAIT, MANTIS_CHARGE_TRAIT
#define MG_IMPALE_TRAIT "mantis_impale"
#define MG_CHARGE_TRAIT "mantis_charge"
/// TRAIT_CYBER_CAMO
#define MG_TRAIT_CAMO "cyber_camo"
/// HV_FINISHER_DONE and HV_FINISHER_DAMAGED
#define MG_FINISHER_DONE 1
#define MG_FINISHER_DAMAGED 3
/// MANTIS_GORE_ICON, MANTIS_GORE_LARGE_ICON and the held-blade files
#define MANTIS_TEST_ICON 'voidcrew/modules/mantis_gore/icons/mantis_gore.dmi'
#define MANTIS_TEST_LARGE_ICON 'voidcrew/modules/mantis_gore/icons/mantis_gore_large.dmi'
#define MANTIS_TEST_ARTERY_ICON 'voidcrew/modules/mantis_gore/icons/mantis_artery.dmi'
/// MANTIS_ARTERY_WOUND_RISE
#define MG_ARTERY_WOUND_RISE 16
#define MANTIS_TEST_LEFTHAND 'voidcrew/modules/mantis_gore/icons/mantis_lefthand.dmi'
#define MANTIS_TEST_RIGHTHAND 'voidcrew/modules/mantis_gore/icons/mantis_righthand.dmi'
/// MANTIS_GORE_REACH_ICON
#define MANTIS_TEST_REACH_ICON 'voidcrew/modules/mantis_gore/icons/mantis_gore_reach.dmi'
/// MANTIS_RIG_ORDER
#define MG_RIG_ORDER 1

/datum/unit_test/voidcrew_mantis_gore
	abstract_type = /datum/unit_test/voidcrew_mantis_gore

/// The floor [dx], [dy] tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_mantis_gore/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A human at [where] with both housings of [housing_type] installed. [out] extends the blades.
/datum/unit_test/voidcrew_mantis_gore/proc/bearer(turf/where, housing_type = /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis, out = TRUE)
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent, where)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right = allocate(housing_type)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left = allocate(text2path("[housing_type]/left"))
	TEST_ASSERT(right.Insert(body, special = TRUE), "Fixture: the right housing would not install")
	TEST_ASSERT(left.Insert(body, special = TRUE), "Fixture: the left housing would not install")
	if(out)
		right.Extend(right.contents[1])
		left.Extend(left.contents[1])
		TEST_ASSERT(right.blade_extended() && left.blade_extended(), "Fixture: the blades never came out")
	return body

/// [body]'s Mantis housings, right then left.
/datum/unit_test/voidcrew_mantis_gore/proc/housings(mob/living/carbon/body)
	. = list()
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing in body.organs)
		. += housing

/// [body]'s held Mantis blade in its right hand, or the first one.
/datum/unit_test/voidcrew_mantis_gore/proc/right_blade(mob/living/carbon/body)
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing in body.organs)
		if(housing.zone == BODY_ZONE_R_ARM)
			return housing.active_item
	return locate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis) in body.held_items

/// A landed cut on [victim]'s [zone] with [blade], as the blade's own swing reads it. 10 a cut, so five
/// fit on one arm before it is at its most damage.
/datum/unit_test/voidcrew_mantis_gore/proc/cut(obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade, mob/living/user, mob/living/victim, zone, damage = 10)
	blade.mantis_watch_cut(victim, user)
	victim.apply_damage(damage, BRUTE, zone, 0, wound_bonus = CANT_WOUND, sharpness = SHARP_EDGED, attack_direction = EAST, attacking_item = blade)
	blade.mantis_unwatch_cut(victim)

/// Puts [victim] in crit with plenty of health to spare before death. That much air loss also knocks
/// them out, which still counts: out cold at crit health.
/// The blade rig's pictures standing on [body]'s tile (mantis_rig.dm).
/datum/unit_test/voidcrew_mantis_gore/proc/rig_pictures(mob/living/body)
	. = list()
	for(var/obj/effect/abstract/mantis_puppet/picture in get_turf(body))
		. += picture

/datum/unit_test/voidcrew_mantis_gore/proc/crit(mob/living/carbon/victim)
	victim.adjustOxyLoss(110)
	TEST_ASSERT(mantis_in_crit(victim), "Fixture: [victim] isn't dying (stat [victim.stat], health [victim.health])")

// ---------------------------------------------------------------------------------------------

/// Three cuts on a bare limb tear its artery, five under light cover, never under heavy cover. The count
/// starts over after a gap, the Shiv never tears, and an Atlas frame (bone only) doesn't stop it.
/datum/unit_test/voidcrew_mantis_gore/artery

/datum/unit_test/voidcrew_mantis_gore/artery/Run()
	var/mob/living/carbon/human/user = bearer(spot(0, 0))
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	var/limb_artery = /datum/wound/slash/flesh/critical/hv_carotid/limb
	// One blade, so no X-slash follow-through adds to the limb between the counted cuts.
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/off_housing = housings(user)[2]
	off_housing.Retract()

	var/mob/living/carbon/human/consistent/bare = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/obj/item/bodypart/arm = bare.get_bodypart(BODY_ZONE_L_ARM)
	cut(blade, user, bare, BODY_ZONE_L_ARM)
	cut(blade, user, bare, BODY_ZONE_L_ARM)
	TEST_ASSERT(!arm.get_wound_type(limb_artery), "Two cuts tore the artery")
	cut(blade, user, bare, BODY_ZONE_L_ARM)
	var/datum/wound/slash/flesh/critical/hv_carotid/limb/torn = arm.get_wound_type(limb_artery)
	TEST_ASSERT(torn, "Three cuts on a bare arm didn't tear its artery")
	TEST_ASSERT_EQUAL(torn?.spurt_dir, EAST, "The artery doesn't pump the way the cut went")
	var/found_line = FALSE
	for(var/list/line as anything in bare.hv_hit?.lines)
		if(findtext(line[1], "artery"))
			found_line = TRUE
	TEST_ASSERT(found_line, "The tear added no hit line")
	TEST_ASSERT(blade.drenched_until > world.time, "A torn artery didn't drench the blade")
	blade.stop_dripping()

	// Light cover (Slabskin-like plating 25, less the blade's 10): five cuts.
	var/mob/living/carbon/human/consistent/plated = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	plated.physiology.armor = plated.physiology.armor.generate_new_with_modifiers(list(MELEE = 25))
	var/obj/item/bodypart/plated_arm = plated.get_bodypart(BODY_ZONE_R_ARM)
	for(var/i in 1 to 4)
		cut(blade, user, plated, BODY_ZONE_R_ARM)
	TEST_ASSERT(!plated_arm.get_wound_type(limb_artery), "Four cuts tore a plated arm")
	cut(blade, user, plated, BODY_ZONE_R_ARM)
	TEST_ASSERT(plated_arm.get_wound_type(limb_artery), "Five cuts didn't tear a plated arm")

	// Heavy cover (45 less 10 = 35): never.
	var/mob/living/carbon/human/consistent/armoured = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	armoured.physiology.armor = armoured.physiology.armor.generate_new_with_modifiers(list(MELEE = 45))
	var/obj/item/bodypart/armoured_leg = armoured.get_bodypart(BODY_ZONE_L_LEG)
	for(var/i in 1 to 6)
		cut(blade, user, armoured, BODY_ZONE_L_LEG)
	TEST_ASSERT(!armoured_leg.get_wound_type(limb_artery), "A heavily armoured leg tore")

	// A gap starts the count over.
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent, spot(2, 0))
	var/obj/item/bodypart/patient_leg = patient.get_bodypart(BODY_ZONE_R_LEG)
	cut(blade, user, patient, BODY_ZONE_R_LEG)
	cut(blade, user, patient, BODY_ZONE_R_LEG)
	var/datum/status_effect/mantis_cuts/cuts = patient.has_status_effect(/datum/status_effect/mantis_cuts)
	TEST_ASSERT(cuts, "Cuts left no count on the target")
	cuts.limb_cut_times[BODY_ZONE_R_LEG] = world.time - 9 SECONDS
	cut(blade, user, patient, BODY_ZONE_R_LEG)
	TEST_ASSERT(!patient_leg.get_wound_type(limb_artery), "The count carried over a gap")
	TEST_ASSERT_EQUAL(cuts.limb_cuts[BODY_ZONE_R_LEG], 1, "The count didn't start over after a gap")

	// A light cut doesn't count.
	var/mob/living/carbon/human/consistent/grazed = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	var/obj/item/bodypart/grazed_arm = grazed.get_bodypart(BODY_ZONE_L_ARM)
	for(var/i in 1 to 4)
		cut(blade, user, grazed, BODY_ZONE_L_ARM, 5)
	TEST_ASSERT(!grazed_arm.get_wound_type(limb_artery), "Grazes tore an artery")

	// Atlas covers bone, not soft tissue.
	var/mob/living/carbon/human/consistent/framed = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	ADD_TRAIT(framed, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)
	for(var/i in 1 to 3)
		cut(blade, user, framed, BODY_ZONE_R_ARM)
	TEST_ASSERT(framed.get_bodypart(BODY_ZONE_R_ARM).get_wound_type(limb_artery), "An Atlas frame stopped the artery tear")

	// The neck is #509's slit throat.
	var/mob/living/carbon/human/consistent/necked = allocate(/mob/living/carbon/human/consistent, spot(3, 0))
	for(var/i in 1 to 3)
		cut(blade, user, necked, BODY_ZONE_HEAD)
	TEST_ASSERT(necked.get_bodypart(BODY_ZONE_HEAD).get_wound_type(/datum/wound/slash/flesh/critical/hv_carotid), "Three cuts on the neck didn't slit the throat")

	// The Shiv only bleeds them.
	var/mob/living/carbon/human/shiv_user = bearer(spot(4, 4), /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/shiv = right_blade(shiv_user)
	var/mob/living/carbon/human/consistent/shivved = allocate(/mob/living/carbon/human/consistent, spot(3, 4))
	for(var/i in 1 to 4)
		cut(shiv, shiv_user, shivved, BODY_ZONE_L_ARM)
	TEST_ASSERT(!shivved.get_bodypart(BODY_ZONE_L_ARM).get_wound_type(limb_artery), "The Shiv tore an artery")

	// The Scorch sears it half shut.
	var/mob/living/carbon/human/scorch_user = bearer(spot(4, 0), /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch = right_blade(scorch_user)
	var/mob/living/carbon/human/consistent/seared = allocate(/mob/living/carbon/human/consistent, spot(3, 1))
	for(var/i in 1 to 3)
		cut(scorch, scorch_user, seared, BODY_ZONE_L_LEG)
	var/datum/wound/seared_wound = seared.get_bodypart(BODY_ZONE_L_LEG).get_wound_type(/datum/wound/slash/flesh/critical/hv_carotid/limb/seared)
	TEST_ASSERT(seared_wound, "Three scorch cuts didn't sear the artery open")
	TEST_ASSERT(seared_wound?.blood_flow < torn?.blood_flow, "The seared artery bleeds as hard as a cut one")

/// The limb artery: no gargle, a hemostat clamps it, and the seared one clots.
/datum/unit_test/voidcrew_mantis_gore/wounds

/datum/unit_test/voidcrew_mantis_gore/wounds/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	var/datum/wound/slash/flesh/critical/hv_carotid/limb/torn = hv_crit_apply_wound(arm, /datum/wound/slash/flesh/critical/hv_carotid/limb, WEST, null)
	TEST_ASSERT(torn, "The limb artery wound would not apply")
	TEST_ASSERT_EQUAL(torn.spurt_dir, WEST, "The limb artery forgot the cut's direction")
	TEST_ASSERT_EQUAL(torn.next_spurt, INFINITY, "The throat's pulse still runs on a limb")
	var/list/message_args = list("hello there")
	torn.gargle_speech(victim, message_args)
	TEST_ASSERT_EQUAL(message_args[TREAT_MESSAGE_ARG], "hello there", "An arm wound gargled speech")
	var/before = torn.blood_flow
	torn.clamped = TRUE
	torn.adjust_blood_flow(-2.5)
	TEST_ASSERT(torn.blood_flow < before, "Clamping did nothing")
	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_L_LEG)
	var/datum/wound/slash/flesh/critical/hv_carotid/limb/seared/seared = hv_crit_apply_wound(leg, /datum/wound/slash/flesh/critical/hv_carotid/limb/seared, EAST, null)
	TEST_ASSERT(seared, "The seared artery would not apply")
	TEST_ASSERT(seared.clot_rate > 0, "The seared artery never clots")
	TEST_ASSERT(GLOB.all_wound_pregen_data[/datum/wound/slash/flesh/critical/hv_carotid/limb], "The limb artery has no pregen data")
	TEST_ASSERT(!GLOB.all_wound_pregen_data[/datum/wound/slash/flesh/critical/hv_carotid/limb].can_be_randomly_generated, "The limb artery can come from tg's random wound roll")

/// Two blades into someone hurt hold them; a wall behind pins them longer. Safety ends it with no rip,
/// the rip floors them, and everything is put back.
/datum/unit_test/voidcrew_mantis_gore/impale

/datum/unit_test/voidcrew_mantis_gore/impale/Run()
	var/mob/living/carbon/human/user = bearer(spot(0, 2))
	var/list/held_housings = housings(user)
	var/datum/action/cooldown/cyberware/mantis_lunge/lunge = locate() in mantis_lunge_actions(user)

	var/mob/living/carbon/human/consistent/fresh = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	TEST_ASSERT(!mantis_can_impale(user, fresh, held_housings), "Someone unhurt can be skewered")
	fresh.adjustBruteLoss(40)
	TEST_ASSERT(mantis_can_impale(user, fresh, held_housings), "Someone at 60% health can't be skewered")
	TEST_ASSERT(!mantis_can_impale(user, fresh, list(held_housings[1])), "One blade skewered")
	fresh.mob_size = MOB_SIZE_LARGE
	TEST_ASSERT(!mantis_can_impale(user, fresh, held_housings), "Something big was skewered")
	fresh.mob_size = MOB_SIZE_HUMAN
	var/mob/living/carbon/human/consistent/floored = allocate(/mob/living/carbon/human/consistent, spot(1, 3))
	floored.Knockdown(10 SECONDS)
	TEST_ASSERT(mantis_can_impale(user, floored, held_housings), "Someone on the floor can't be skewered")
	// Off the floor and up on the blades: drawn upright, still lying down to tg, and laid back down after.
	var/datum/mantis_impale/hoisted = new(user, floored, held_housings, 2 SECONDS)
	TEST_ASSERT(hoisted.start(), "Someone on the floor wasn't skewered")
	TEST_ASSERT(hoisted.hoist_angle, "Someone on the floor wasn't brought up on the blades")
	TEST_ASSERT(abs(floored.transform.b) < 0.01 && floored.transform.a > 0.99, "Someone brought up on the blades isn't drawn upright")
	TEST_ASSERT_EQUAL(floored.body_position, LYING_DOWN, "Bringing them up stood them up")
	hoisted.begin_rig()
	hoisted.finish()
	TEST_ASSERT(!hoisted.hoist_angle, "The hoist outlived the hold")
	TEST_ASSERT(!length(rig_pictures(user)), "The blades stayed drawn after the hold")
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, spot(1, 1))
	TEST_ASSERT(!mantis_can_impale(user, mouse, held_housings), "A mouse was skewered")

	// Open floor behind: held up for the short beat.
	TEST_ASSERT(mantis_start_impale(lunge, user, fresh, held_housings, 2 SECONDS), "The impale didn't start")
	var/datum/mantis_impale/skewer = lunge.impale
	TEST_ASSERT(skewer, "The lunge doesn't know about its skewer")
	TEST_ASSERT(!skewer.wall_pin, "Open floor counted as a wall")
	TEST_ASSERT_EQUAL(skewer.hold_time, 0.8 SECONDS, "The open hold isn't 0.8 seconds")
	TEST_ASSERT(HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, MG_IMPALE_TRAIT) && HAS_TRAIT_FROM(user, TRAIT_HANDS_BLOCKED, MG_IMPALE_TRAIT), "The bearer isn't rooted with full hands")
	TEST_ASSERT(HAS_TRAIT_FROM(fresh, TRAIT_IMMOBILIZED, MG_IMPALE_TRAIT), "The victim isn't held")
	TEST_ASSERT(!HAS_TRAIT(fresh, TRAIT_HANDS_BLOCKED), "The victim's hands are tied")
	TEST_ASSERT_EQUAL(fresh.dir, WEST, "The victim wasn't turned onto the blades")
	// The bearer is drawn by the rig from the glide in; the lunging body lands and the blades go in: drawn
	// under them and over them.
	TEST_ASSERT(skewer.rig, "The lunging body isn't drawn by the rig")
	skewer.begin_rig()
	skewer.stab()
	TEST_ASSERT(skewer.rig, "The bearer isn't drawn around the victim")
	TEST_ASSERT(fresh.has_offset(MG_IMPALE_TRAIT, PIXEL_W_OFFSET) < 0, "The victim isn't drawn onto the blades")
	var/list/pictures = rig_pictures(user)
	TEST_ASSERT_EQUAL(length(pictures), 5, "The blades going in aren't drawn in four pieces and the wounds")
	var/under = 0
	var/over = 0
	for(var/obj/effect/abstract/mantis_puppet/picture as anything in pictures)
		if(picture.layer < fresh.layer)
			under++
		else if(picture.layer > fresh.layer)
			over++
	TEST_ASSERT(under == 2 && over == 3, "The bearer isn't split around the victim ([under] under, [over] over)")
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/held_blade = right_blade(user)
	TEST_ASSERT(held_blade.inhand_hidden_until > world.time, "The held blade is drawn over the blades going in")
	skewer.show_beat("hold")
	TEST_ASSERT(fresh.has_offset(MG_IMPALE_TRAIT, PIXEL_Z_OFFSET) > 0, "The victim isn't lifted")
	var/brute_before = fresh.getBruteLoss()
	skewer.rip()
	TEST_ASSERT(HAS_TRAIT_FROM(fresh, TRAIT_IMMOBILIZED, MG_IMPALE_TRAIT), "The pull-back let them go before the blades came out")
	var/datum/mantis_rig/dropping = skewer.rig
	skewer.tear_out()
	TEST_ASSERT(!dropping || !QDELETED(dropping), "The bearer wasn't drawn through the drop")
	qdel(dropping)
	TEST_ASSERT(!length(rig_pictures(user)), "The blades stayed drawn in them after the rip")
	TEST_ASSERT(!user.get_filter("mantis_rig_hide"), "The bearer is still hidden after the rip")
	TEST_ASSERT(!held_blade.inhand_hidden_until, "The held blade never came back")
	TEST_ASSERT(fresh.getBruteLoss() > brute_before, "The rip did no damage")
	TEST_ASSERT(fresh.IsKnockdown(), "The rip didn't floor them")
	TEST_ASSERT(!HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, MG_IMPALE_TRAIT) && !HAS_TRAIT_FROM(user, TRAIT_HANDS_BLOCKED, MG_IMPALE_TRAIT), "The bearer is still held")
	TEST_ASSERT(!HAS_TRAIT_FROM(fresh, TRAIT_IMMOBILIZED, MG_IMPALE_TRAIT), "The victim is still held")
	TEST_ASSERT(!fresh.has_offset(MG_IMPALE_TRAIT, PIXEL_Z_OFFSET), "The victim's lift outlived the hold")
	TEST_ASSERT(isnull(lunge.impale), "The lunge still holds a skewer")
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	TEST_ASSERT_EQUAL(blade.mantis_pose, "guard", "The blades didn't come back to the guard")
	TEST_ASSERT(blade.drenched_until > world.time, "The rip didn't drench the blades")
	blade.stop_dripping()

	// A wall right behind: pinned for longer.
	var/mob/living/carbon/human/consistent/pinned = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	pinned.adjustBruteLoss(40)
	allocate(/obj/structure/window/fulltile, spot(3, 2))
	user.forceMove(spot(1, 2))
	TEST_ASSERT(mantis_start_impale(lunge, user, pinned, held_housings, 2 SECONDS), "The wall impale didn't start")
	skewer = lunge.impale
	TEST_ASSERT(skewer.wall_pin, "A window behind them didn't pin them")
	TEST_ASSERT_EQUAL(skewer.hold_time, 1.5 SECONDS, "The pin isn't 1.5 seconds")
	// It runs out on its own and rips: the 1.5 s hold, up to a 0.2 s tick, then the 0.4 s pull-back and tear-out.
	sleep(2.5 SECONDS)
	TEST_ASSERT(isnull(lunge.impale), "The pin never ended")
	TEST_ASSERT(pinned.IsKnockdown(), "The pin ended without the rip")

	// An EMP stows a blade: it ends at once, no rip.
	var/mob/living/carbon/human/consistent/emp_victim = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	emp_victim.adjustBruteLoss(40)
	user.forceMove(spot(1, 1))
	TEST_ASSERT(mantis_start_impale(lunge, user, emp_victim, held_housings, 2 SECONDS), "The EMP impale didn't start")
	skewer = lunge.impale
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in held_housings)
		housing.Retract()
	skewer.tick()
	TEST_ASSERT(isnull(lunge.impale), "Stowed blades kept them held")
	TEST_ASSERT(!emp_victim.IsKnockdown(), "Stowed blades still ripped out")
	TEST_ASSERT(!HAS_TRAIT_FROM(emp_victim, TRAIT_IMMOBILIZED, MG_IMPALE_TRAIT), "Stowed blades left the victim held")
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in held_housings)
		housing.Extend(housing.contents[1])

	// Teleported out: ends.
	var/mob/living/carbon/human/consistent/jaunter = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	jaunter.adjustBruteLoss(40)
	TEST_ASSERT(mantis_start_impale(lunge, user, jaunter, held_housings, 2 SECONDS), "The teleport impale didn't start")
	jaunter.forceMove(spot(4, 4))
	TEST_ASSERT(isnull(lunge.impale), "Teleporting away didn't end the hold")
	TEST_ASSERT(!HAS_TRAIT_FROM(jaunter, TRAIT_IMMOBILIZED, MG_IMPALE_TRAIT), "Teleporting away left them held")

	// Died on the blades: ends.
	var/mob/living/carbon/human/consistent/goner = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	goner.adjustBruteLoss(40)
	TEST_ASSERT(mantis_start_impale(lunge, user, goner, held_housings, 2 SECONDS), "The death impale didn't start")
	goner.death()
	TEST_ASSERT(isnull(lunge.impale), "A death on the blades didn't end the hold")
	TEST_ASSERT(!HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, MG_IMPALE_TRAIT), "A death on the blades left the bearer rooted")

	// Hit hard while holding: lets go at half the rip, and staggers.
	var/mob/living/carbon/human/consistent/rescued = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	rescued.adjustBruteLoss(40)
	TEST_ASSERT(mantis_start_impale(lunge, user, rescued, held_housings, 2 SECONDS), "The interrupted impale didn't start")
	user.apply_damage(16, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(isnull(lunge.impale), "Taking a beating didn't break the hold")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/staggered), "Losing the grip didn't stagger the bearer")
	TEST_ASSERT(rescued.IsKnockdown(), "Losing the grip didn't drop them")

/// Crit only, any player on any player, never someone strapped down; damage breaks it; Atlas keeps the
/// head on; otherwise the head comes off with the brain.
/datum/unit_test/voidcrew_mantis_gore/scissor

/datum/unit_test/voidcrew_mantis_gore/scissor/Run()
	var/mob/living/carbon/human/user = bearer(spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	victim.Knockdown(30 SECONDS)
	var/datum/hv_finisher/mantis_scissor/early = allocate(/datum/hv_finisher/mantis_scissor, user, victim)
	TEST_ASSERT(!early.can_start(), "Someone only knocked down can be scissored")
	crit(victim)
	TEST_ASSERT(!hv_finisher_valid_victim(user, victim), "Test premise: #509's check now lets players finish players")
	TEST_ASSERT(early.can_start(), "Someone dying can't be scissored by another player")
	ADD_TRAIT(user, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!early.can_start(), "A pacifist can scissor")
	REMOVE_TRAIT(user, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)

	var/obj/structure/chair/chair = allocate(/obj/structure/chair, spot(2, 1))
	chair.buckle_mob(victim, force = TRUE)
	TEST_ASSERT(!early.can_start(), "Someone strapped to a chair can be scissored")
	chair.unbuckle_mob(victim, force = TRUE)

	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left = housings(user)[2]
	left.Retract()
	TEST_ASSERT(!early.can_start(), "One blade can scissor")
	left.Extend(left.contents[1])

	// Started by the swing: combat mode, head aimed.
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	user.set_combat_mode(TRUE)
	user.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(!blade.mantis_try_scissor(victim, user), "A chest swing started the scissor")
	user.zone_selected = BODY_ZONE_HEAD
	TEST_ASSERT(blade.attack(victim, user, list(), list()), "A head swing at someone dying didn't start the scissor")
	var/datum/hv_finisher/mantis_scissor/scissor = user.mantis_state?.scissor
	TEST_ASSERT(scissor?.running, "The scissor isn't running")
	TEST_ASSERT_EQUAL(blade.mantis_pose, "raise", "The blades didn't rise for the wind-up")

	// Hurt it: it reels back.
	user.apply_damage(16, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(scissor.result, MG_FINISHER_DAMAGED, "Damage didn't break the scissor")
	TEST_ASSERT(user.has_status_effect(/datum/status_effect/hv_finisher_reeling), "The bearer didn't reel")
	TEST_ASSERT_EQUAL(blade.mantis_pose, "guard", "The blades stayed raised")
	TEST_ASSERT(isnull(user.mantis_state.scissor), "The broken scissor is still on the bearer")
	TEST_ASSERT(!blade.mantis_try_scissor(victim, user), "The scissor has no cooldown")
	user.remove_status_effect(/datum/status_effect/hv_finisher_reeling)
	user.mantis_state.next_scissor = 0
	user.heal_overall_damage(brute = 50)

	// Atlas: the blades stop on metal, the head stays.
	ADD_TRAIT(victim, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/hv_finisher/mantis_scissor/framed = allocate(/datum/hv_finisher/mantis_scissor, user, victim, CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_scissor_ended)))
	TEST_ASSERT(framed.start(), "The scissor didn't start on an Atlas body")
	var/head_brute = victim.get_bodypart(BODY_ZONE_HEAD).brute_dam
	for(var/i in 1 to 20)
		if(!framed.running)
			break
		framed.advance()
	TEST_ASSERT(framed.completed, "The Atlas scissor never closed")
	TEST_ASSERT(victim.get_bodypart(BODY_ZONE_HEAD), "An Atlas body lost its head")
	TEST_ASSERT(victim.get_bodypart(BODY_ZONE_HEAD).brute_dam > head_brute, "The blades did nothing to the Atlas neck")
	REMOVE_TRAIT(victim, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)
	// Ended as the game ends one (mantis_try_scissor()'s callback): the rig fades into the real bearer
	sleep(0.25 SECONDS) // mantis_rig/hand_back(), MANTIS_RIG_HANDBACK 0.15 s

	// The head comes off, brain inside, and lands where they lie.
	var/mob/living/carbon/human/consistent/doomed = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	crit(doomed)
	var/datum/hv_finisher/mantis_scissor/kill = allocate(/datum/hv_finisher/mantis_scissor, user, doomed, CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_scissor_ended)))
	TEST_ASSERT(kill.start(), "The scissor didn't start")
	TEST_ASSERT(kill.rig, "The bearer isn't drawn around the victim")
	kill.advance()
	var/list/closing = rig_pictures(user)
	var/below = 0
	for(var/obj/effect/abstract/mantis_puppet/picture as anything in closing)
		if(picture.layer < doomed.layer)
			below++
	var/list/diag_states = list()
	for(var/obj/effect/abstract/mantis_puppet/picture as anything in closing)
		diag_states += "[picture.icon_state]@[picture.layer < doomed.layer][QDELETED(picture) ? "Q" : ""]"
	TEST_ASSERT(length(closing) == 4 && below == 1, "The closing blades aren't drawn with the far blade under the neck ([length(closing)] pieces, [below] under) (DIAG [jointext(diag_states, ",")] stage [kill.current_stage?.type])")
	TEST_ASSERT(right_blade(user).inhand_hidden_until > world.time, "The held blade is drawn over the closing blades")
	for(var/i in 1 to 20)
		if(!kill.running)
			break
		kill.advance()
	TEST_ASSERT_EQUAL(kill.result, MG_FINISHER_DONE, "The scissor didn't finish")
	sleep(0.25 SECONDS) // the rig fades out (mantis_rig/hand_back(), MANTIS_RIG_HANDBACK 0.15 s)
	TEST_ASSERT(!length(rig_pictures(user)) && !user.get_filter("mantis_rig_hide"), "The bearer is still drawn by the rig after the scissor")
	TEST_ASSERT_NULL(doomed.get_bodypart(BODY_ZONE_HEAD), "The head is still on")
	var/obj/item/bodypart/head/head = locate() in get_turf(doomed)
	TEST_ASSERT(head, "The head isn't at their feet")
	TEST_ASSERT(locate(/obj/item/organ/brain) in head, "The brain didn't stay in the head")

	// A human NPC below boss rank never scissors.
	var/mob/living/carbon/human/npc/grunt = allocate(/mob/living/carbon/human/npc, spot(3, 3))
	var/mob/living/carbon/human/consistent/npc_victim = allocate(/mob/living/carbon/human/consistent, spot(3, 2))
	crit(npc_victim)
	var/datum/hv_finisher/mantis_scissor/npc_try = allocate(/datum/hv_finisher/mantis_scissor, grunt, npc_victim)
	TEST_ASSERT(!grunt.hv_can_execute() && !npc_try.can_start(), "An ordinary NPC can scissor")

/// From a corner a head swing at someone dying is only a swing: the scissor starts square on.
/datum/unit_test/voidcrew_mantis_gore/scissor_square_on

/datum/unit_test/voidcrew_mantis_gore/scissor_square_on/Run()
	var/mob/living/carbon/human/user = bearer(spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	crit(victim)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	user.set_combat_mode(TRUE)
	user.zone_selected = BODY_ZONE_HEAD
	TEST_ASSERT(!blade.mantis_try_scissor(victim, user), "The scissor started on someone on a corner")
	var/hurt_before = victim.getBruteLoss() + victim.getFireLoss()
	blade.attack(victim, user, list(), list())
	TEST_ASSERT(isnull(user.mantis_state?.scissor), "A corner swing started the scissor")
	TEST_ASSERT(victim.getBruteLoss() + victim.getFireLoss() > hurt_before, "The corner swing didn't cut")

	// Square on, it starts; dragged onto a corner before the cut, it stops
	victim.forceMove(spot(2, 1))
	user.next_move = 0
	TEST_ASSERT(blade.mantis_try_scissor(victim, user), "The scissor didn't start square on")
	var/datum/hv_finisher/mantis_scissor/scissor = user.mantis_state.scissor
	TEST_ASSERT(scissor?.running, "The scissor isn't running")
	victim.forceMove(spot(2, 2))
	TEST_ASSERT(QDELETED(scissor) || !scissor.running, "The scissor went on with the body on a corner")
	TEST_ASSERT(isnull(user.mantis_state.scissor), "The stopped scissor is still on the bearer")
	sleep(0.25 SECONDS) // the rig fades out (mantis_rig/hand_back(), MANTIS_RIG_HANDBACK 0.15 s)
	TEST_ASSERT(!length(rig_pictures(user)), "A scissor stopped on a corner left the bearer drawn by the rig")

/// Who counts, at most once per bearer per 8 s and per body per 2 min, never prisoners, only kills
/// within 5 s of the bearer's cut, and never under 3 s.
/datum/unit_test/voidcrew_mantis_gore/reset

/datum/unit_test/voidcrew_mantis_gore/reset/proc/cooldown_left(mob/living/carbon/body)
	var/datum/action/cooldown/cyberware/mantis_lunge/lunge = locate() in mantis_lunge_actions(body)
	return lunge.next_use_time - world.time

/datum/unit_test/voidcrew_mantis_gore/reset/proc/wind_up(mob/living/carbon/body)
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge as anything in mantis_lunge_actions(body))
		lunge.StartCooldown(20 SECONDS)

/datum/unit_test/voidcrew_mantis_gore/reset/Run()
	var/mob/living/carbon/human/user = bearer(spot(0, 0))
	TEST_ASSERT(length(mantis_lunge_actions(user)) == 2, "Fixture: the bearer hasn't two lunge buttons")

	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	var/mob/living/carbon/human/species/monkey/monkey = allocate(/mob/living/carbon/human/species/monkey, spot(1, 1))
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, spot(1, 2))
	TEST_ASSERT(mantis_kill_reset_counts(person), "A person doesn't count")
	TEST_ASSERT(!mantis_kill_reset_counts(monkey), "A monkey counts")
	TEST_ASSERT(!mantis_kill_reset_counts(mouse), "A mouse counts")
	mouse.maxHealth = 150
	TEST_ASSERT(mantis_kill_reset_counts(mouse), "Something big doesn't count")

	wind_up(user)
	TEST_ASSERT(mantis_try_kill_reset(user, person), "A kill didn't reset the lunge")
	TEST_ASSERT(cooldown_left(user) <= 3 SECONDS && cooldown_left(user) > 0, "The reset isn't down to 3 seconds")

	// Once per 8 seconds.
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent, spot(2, 0))
	wind_up(user)
	TEST_ASSERT(!mantis_try_kill_reset(user, second), "Two resets inside 8 seconds")
	user.mantis_state.next_kill_reset = 0
	TEST_ASSERT(mantis_try_kill_reset(user, second), "The second kill after the 8 seconds didn't reset")

	// Once per body per 2 minutes.
	user.mantis_state.next_kill_reset = 0
	wind_up(user)
	TEST_ASSERT(!mantis_try_kill_reset(user, person), "The same body reset twice inside 2 minutes")
	person.mantis_reset_given_at = world.time - 2 MINUTES - 1
	TEST_ASSERT(mantis_try_kill_reset(user, person), "The body still blocks after 2 minutes")

	// Never prisoners.
	var/mob/living/carbon/human/consistent/prisoner = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	ADD_TRAIT(prisoner, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	user.mantis_state.next_kill_reset = 0
	wind_up(user)
	TEST_ASSERT(!mantis_try_kill_reset(user, prisoner), "Killing a cuffed prisoner reset the lunge")
	var/mob/living/carbon/human/consistent/strapped = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	var/obj/structure/chair/chair = allocate(/obj/structure/chair, spot(2, 2))
	chair.buckle_mob(strapped, force = TRUE)
	TEST_ASSERT(!mantis_try_kill_reset(user, strapped), "Killing someone strapped down reset the lunge")

	// Never shorter than the floor: a cooldown already under 3 s is left alone.
	for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge as anything in mantis_lunge_actions(user))
		lunge.StartCooldown(2 SECONDS)
	var/mob/living/carbon/human/consistent/late = allocate(/mob/living/carbon/human/consistent, spot(3, 0))
	TEST_ASSERT(!mantis_try_kill_reset(user, late), "A reset lengthened a short cooldown")
	TEST_ASSERT(cooldown_left(user) <= 2 SECONDS, "A short cooldown got longer")

	// Through the death signal: a cut 6 seconds back is not the kill; a fresh one is.
	user.mantis_state.next_kill_reset = 0
	wind_up(user)
	var/mob/living/carbon/human/consistent/bled_out = allocate(/mob/living/carbon/human/consistent, spot(3, 1))
	var/datum/status_effect/mantis_cuts/old_cuts = mantis_note_hit(bled_out, user)
	old_cuts.last_hit = world.time - 6 SECONDS
	bled_out.death()
	TEST_ASSERT(cooldown_left(user) > 3 SECONDS, "A death long after the cut reset the lunge")
	var/mob/living/carbon/human/consistent/killed = allocate(/mob/living/carbon/human/consistent, spot(3, 2))
	mantis_note_hit(killed, user)
	killed.death()
	TEST_ASSERT(cooldown_left(user) <= 3 SECONDS, "A fresh kill didn't reset the lunge")
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	TEST_ASSERT(blade.drenched_until > world.time, "A kill didn't drench the blades")
	blade.stop_dripping()

	// A plain NPC bearer gets no reset.
	var/mob/living/carbon/human/npc/grunt = allocate(/mob/living/carbon/human/npc, spot(4, 4))
	var/mob/living/carbon/human/consistent/npc_kill = allocate(/mob/living/carbon/human/consistent, spot(4, 3))
	TEST_ASSERT(!mantis_try_kill_reset(grunt, npc_kill), "An ordinary NPC got a reset")

/// The hold to charge: reach by hold time, the field drops at the press, a hit breaks the crouch for the
/// whole cooldown, a light hit doesn't, it straightens up on its own, and a release leaps.
/datum/unit_test/voidcrew_mantis_gore/charge

/datum/unit_test/voidcrew_mantis_gore/charge/Run()
	TEST_ASSERT_EQUAL(mantis_charge_range(0.2 SECONDS, 5), 5, "A tap reaches further than the lunge")
	TEST_ASSERT_EQUAL(mantis_charge_range(0.35 SECONDS, 5), 5, "The start of the crouch reaches further than the lunge")
	TEST_ASSERT_EQUAL(mantis_charge_range(0.775 SECONDS, 5), 6, "Halfway reaches the wrong distance")
	TEST_ASSERT_EQUAL(mantis_charge_range(1.2 SECONDS, 5), 7, "A full charge doesn't reach 7")
	TEST_ASSERT_EQUAL(mantis_charge_range(3 SECONDS, 5), 7, "A long hold reaches past 7")

	var/mob/living/carbon/human/user = bearer(spot(0, 0))
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = allocate(/obj/item/organ/cyberimp/cyberware/ghostskin)
	TEST_ASSERT(weave.Insert(user, special = TRUE), "Fixture: the weave would not install")
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, spot(4, 0))
	var/datum/action/cooldown/cyberware/mantis_lunge/lunge = locate() in mantis_lunge_actions(user)
	weave.engage_camo(user)
	TEST_ASSERT(HAS_TRAIT(user, MG_TRAIT_CAMO), "Fixture: the field didn't come up")
	TEST_ASSERT(lunge.begin_charge(target), "The charge didn't begin")
	TEST_ASSERT(!HAS_TRAIT(user, MG_TRAIT_CAMO), "The field stayed up through the press")

	// The crouch, then a solid hit.
	lunge.enter_crouch()
	TEST_ASSERT(lunge.crouched, "The crouch didn't show")
	TEST_ASSERT(HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, MG_CHARGE_TRAIT), "The crouch isn't rooted")
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	TEST_ASSERT_EQUAL(blade.mantis_pose, "coil", "The blades aren't drawn back")
	user.apply_damage(5, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(lunge.crouched, "A graze broke the crouch")
	user.apply_damage(12, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(!lunge.crouched, "A solid hit didn't break the crouch")
	TEST_ASSERT(!HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, MG_CHARGE_TRAIT), "The broken crouch is still rooted")
	TEST_ASSERT(!user.has_offset(MG_CHARGE_TRAIT, PIXEL_Z_OFFSET), "The broken crouch left the bearer sunk")
	for(var/datum/action/cooldown/cyberware/mantis_lunge/each as anything in mantis_lunge_actions(user))
		TEST_ASSERT(each.next_use_time - world.time > 15 SECONDS, "A broken crouch didn't cost the full cooldown")
		each.ResetCooldown()
	TEST_ASSERT_EQUAL(blade.mantis_pose, "guard", "The blades stayed drawn back")
	user.heal_overall_damage(brute = 50)
	user.mantis_state.next_charge = 0

	// Held too long: straightens up, no cooldown, a moment before setting again.
	TEST_ASSERT(lunge.begin_charge(target), "The second charge didn't begin")
	lunge.enter_crouch()
	lunge.charge_started = world.time - 3.1 SECONDS
	lunge.crouch_tick()
	TEST_ASSERT(!lunge.crouched, "A long hold never straightened up")
	TEST_ASSERT(lunge.IsAvailable(), "Straightening up cost the cooldown")
	TEST_ASSERT(!lunge.begin_charge(target), "The bearer set again at once")
	user.mantis_state.next_charge = 0

	// Released after a full charge: the leap lands next to them.
	TEST_ASSERT(lunge.begin_charge(target), "The third charge didn't begin")
	lunge.enter_crouch()
	lunge.charge_started = world.time - 1.2 SECONDS
	TEST_ASSERT(lunge.release_charge(), "The release didn't leap")
	TEST_ASSERT(user.Adjacent(target), "The leap didn't land beside the target")
	TEST_ASSERT(!lunge.crouched && !HAS_TRAIT_FROM(user, TRAIT_IMMOBILIZED, MG_CHARGE_TRAIT), "The leap left the bearer crouched")
	TEST_ASSERT(!lunge.IsAvailable(), "The leap cost no cooldown")
	// They go down with the impact, once the body has glided in (land_lunge(), mantis_lunge_knockdown())
	sleep(1 SECONDS)
	TEST_ASSERT(target.IsKnockdown(), "The leap didn't drop the target")

/// The dash stops at the edge of a chasm or lava, never on it.
/datum/unit_test/voidcrew_mantis_gore/lunge_path
	var/list/turf/changed_turfs = list()
	var/list/original_turf_types = list()

/datum/unit_test/voidcrew_mantis_gore/lunge_path/Destroy()
	for(var/i in 1 to length(changed_turfs))
		var/turf/changed = changed_turfs[i]
		changed.ChangeTurf(original_turf_types[i])
	return ..()

/datum/unit_test/voidcrew_mantis_gore/lunge_path/Run()
	for(var/hazard in list(/turf/open/chasm, /turf/open/lava/smooth))
		var/mob/living/carbon/human/user = bearer(spot(0, 2))
		var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, spot(4, 2))
		var/turf/gap = spot(2, 2)
		original_turf_types += gap.type
		changed_turfs += gap.ChangeTurf(hazard)
		var/datum/action/cooldown/cyberware/mantis_lunge/lunge = locate() in mantis_lunge_actions(user)
		lunge.do_lunge(WEAKREF(target))
		TEST_ASSERT_EQUAL(get_turf(user), spot(1, 2), "The dash didn't stop at the edge of [hazard]")
		TEST_ASSERT(!target.IsKnockdown(), "A dash stopped short of [hazard] still dropped the target")
		var/turf/changed = changed_turfs[length(changed_turfs)]
		changed.ChangeTurf(original_turf_types[length(original_turf_types)])
		changed_turfs.Cut()
		original_turf_types.Cut()
		qdel(user)
		qdel(target)
	TEST_ASSERT(mantis_lunge_unsafe_turf(null), "No turf counted as safe")

/// Every third landed cut with both blades out, on the same target and inside the window, crosses both
/// blades; its follow-through never counts as a cut of its own.
/datum/unit_test/voidcrew_mantis_gore/xslash

/datum/unit_test/voidcrew_mantis_gore/xslash/Run()
	var/mob/living/carbon/human/user = bearer(spot(0, 0))
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, spot(1, 0))
	cut(blade, user, target, BODY_ZONE_CHEST)
	cut(blade, user, target, BODY_ZONE_CHEST)
	TEST_ASSERT(!target.has_status_effect(/datum/status_effect/staggered), "Two cuts staggered them")
	var/brute_before = target.getBruteLoss()
	cut(blade, user, target, BODY_ZONE_CHEST)
	TEST_ASSERT(target.has_status_effect(/datum/status_effect/staggered), "The third cut didn't stagger them")
	TEST_ASSERT(target.getBruteLoss() - brute_before > 10, "The off blade didn't follow through")
	TEST_ASSERT_EQUAL(user.mantis_state.xslash_count, 0, "The follow-through counted as a cut, or the count didn't reset")

	// A new target starts over.
	var/mob/living/carbon/human/consistent/other = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	cut(blade, user, target, BODY_ZONE_CHEST)
	cut(blade, user, target, BODY_ZONE_CHEST)
	cut(blade, user, other, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(user.mantis_state.xslash_count, 1, "Switching targets kept the count")
	// So does a gap.
	cut(blade, user, other, BODY_ZONE_CHEST)
	user.mantis_state.xslash_last = world.time - 5 SECONDS
	cut(blade, user, other, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(user.mantis_state.xslash_count, 1, "A gap kept the count")

	// One blade out: never.
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/left = housings(user)[2]
	left.Retract()
	var/mob/living/carbon/human/consistent/single = allocate(/mob/living/carbon/human/consistent, spot(2, 0))
	for(var/i in 1 to 3)
		cut(blade, user, single, BODY_ZONE_CHEST)
	TEST_ASSERT(!single.has_status_effect(/datum/status_effect/staggered), "One blade crossed itself")

	// The Shiv has no X.
	var/mob/living/carbon/human/shiv_user = bearer(spot(4, 4), /obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/street)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/shiv = right_blade(shiv_user)
	TEST_ASSERT(!(shiv.gore_moves & MG_MOVE_XSLASH), "The Shiv can X-slash")
	TEST_ASSERT(!(shiv.gore_moves & MG_MOVE_IMPALE), "The Shiv can impale")

/// The Mantis blade takes blood, the Scorch doesn't. Stowing a bloody blade flicks it clean onto the
/// floor ahead and stains the housing until the bearer washes.
/datum/unit_test/voidcrew_mantis_gore/blood

/datum/unit_test/voidcrew_mantis_gore/blood/Run()
	var/mob/living/carbon/human/consistent/donor = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/loose = allocate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis)
	loose.add_mob_blood(donor)
	TEST_ASSERT(loose.is_bloody(), "The Mantis blade refuses blood")
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch/clean = allocate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch)
	clean.add_mob_blood(donor)
	TEST_ASSERT(!clean.is_bloody(), "The Scorch blade took blood")
	TEST_ASSERT(!clean.drench(donor), "The Scorch blade drenched")

	var/mob/living/carbon/human/user = bearer(spot(1, 1))
	user.setDir(EAST)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right_blade(user)
	TEST_ASSERT(blade.drench(donor), "The blade wouldn't drench")
	TEST_ASSERT(blade.drenched_until > world.time && blade.drip_timer, "A drenched blade doesn't drip")
	var/list/overlays = blade.worn_overlays(mutable_appearance(MANTIS_TEST_RIGHTHAND, "mantis_guard"), TRUE, MANTIS_TEST_RIGHTHAND)
	var/stained_hand = FALSE
	var/drips = FALSE
	for(var/mutable_appearance/overlay as anything in overlays)
		if(overlay.icon_state == "mantis_guard_soak")
			stained_hand = TRUE
		if(overlay.icon_state == "mantis_guard_drip")
			drips = TRUE
	TEST_ASSERT(stained_hand, "The held blade shows no blood")
	TEST_ASSERT(drips, "The drenched held blade shows no drops")

	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right = housings(user)[1]
	right.Retract()
	TEST_ASSERT(!blade.is_bloody(), "Stowing didn't flick the blade clean")
	TEST_ASSERT(!blade.drip_timer, "A stowed blade still drips")
	TEST_ASSERT(right.stained, "The housing kept no stain")
	TEST_ASSERT(findtext(right.cyberware_worn_key(), "blood"), "The stain isn't part of the housing's look")
	// Past the fold, the housing shows again, stain and all.
	right.stop_blade_anim()
	var/list/dressed = right.cyberware_dress_worn(list(image(icon = 'voidcrew/modules/cyberware/icons/cyberware_worn.dmi', icon_state = "mantis_right")), -27, user.get_bodypart(BODY_ZONE_R_ARM))
	var/stain_drawn = FALSE
	for(var/image/part as anything in dressed)
		if(part.icon_state == "mantis_right_stain")
			stain_drawn = TRUE
	TEST_ASSERT(stain_drawn, "The stained housing draws no stain")
	// The flicked blood is in the air for a moment before it lands.
	sleep(0.4 SECONDS)
	var/obj/effect/decal/cleanable/blood/mantis_flick/spatter = locate() in spot(2, 1)
	TEST_ASSERT_NOTNULL(spatter, "The flick left no spatter ahead")
	TEST_ASSERT_EQUAL(spatter.dir, user.dir, "The flick's spatter doesn't point the way it was thrown")
	TEST_ASSERT(icon_exists(spatter.icon, spatter.icon_state), "The flick's spatter has no picture")
	TEST_ASSERT(!(locate(/obj/effect/decal/cleanable/blood/hv_spray/streak) in spot(2, 1)), "The flick still lays a streak")
	user.wash(CLEAN_TYPE_BLOOD)
	TEST_ASSERT(!right.stained, "Washing didn't clear the housing")

	// A clean blade just stows.
	right.Extend(right.contents[1])
	right.Retract()
	TEST_ASSERT(!right.stained, "A clean blade stained the housing")

/// While a blade is out its fist rides up and it holds the guard; it glints now and then; all of it ends
/// when the blade is stowed or the housing pulled. Every pose has its art.
/datum/unit_test/voidcrew_mantis_gore/stance

/datum/unit_test/voidcrew_mantis_gore/stance/Run()
	var/mob/living/carbon/human/user = bearer(spot(1, 1), out = FALSE)
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/right = housings(user)[1]
	var/obj/item/bodypart/arm = user.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade = right.contents[1]
	right.Extend(blade)
	TEST_ASSERT_EQUAL(blade.inhand_icon_state, "mantis_guard", "The blade isn't held in the guard")
	TEST_ASSERT(right.stance_overlay && (right.stance_overlay in arm.bodypart_overlays), "The fist didn't come up")
	TEST_ASSERT_EQUAL(right.stance_overlay.raise, 2, "The guard fist isn't 2 pixels up")
	TEST_ASSERT(right.glint_timer, "No glint is coming")
	blade.set_mantis_pose("raise")
	TEST_ASSERT_EQUAL(blade.inhand_icon_state, "mantis_raise", "The raise pose didn't take")
	TEST_ASSERT_EQUAL(right.stance_overlay.raise, 3, "The fist didn't follow the raise")
	blade.set_mantis_pose("nonsense")
	TEST_ASSERT_EQUAL(blade.inhand_icon_state, "mantis_guard", "A pose with no art didn't fall back to the guard")
	right.Retract()
	TEST_ASSERT(isnull(right.stance_overlay), "The stance outlived the blade")
	for(var/datum/bodypart_overlay/overlay as anything in arm.bodypart_overlays)
		TEST_ASSERT(!istype(overlay, /datum/bodypart_overlay/mantis_stance), "The raised fist stayed on the arm")
	TEST_ASSERT(!right.glint_timer, "The glint outlived the blade")
	right.Extend(blade)
	right.Remove(user, special = TRUE)
	TEST_ASSERT(isnull(right.stance_overlay), "A pulled housing left the fist raised")

	var/static/list/poses_by_model = list(
		"mantis" = list("guard", "lunge", "raise", "coil"),
		"mantis_street" = list("guard"),
		"mantis_scorch" = list("guard", "lunge", "raise", "coil"),
	)
	for(var/model in poses_by_model)
		for(var/pose in poses_by_model[model])
			for(var/hand_file in list(MANTIS_TEST_LEFTHAND, MANTIS_TEST_RIGHTHAND))
				TEST_ASSERT(icon_exists(hand_file, "[model]_[pose]"), "[hand_file] has no [model]_[pose]")
	for(var/state in list("mantis_trail", "mantis_scorch_trail", "mantis_impale", "mantis_scorch_impale", "mantis_coil_glow_right", "mantis_scorch_coil_glow_left", "mantis_guard_glint_right", "mantis_raise_glint_left", "scorch_gash_l_arm", "scorch_gash_head", "flick_spatter_right", "flick_spatter_left"))
		TEST_ASSERT(icon_exists(MANTIS_TEST_ICON, state), "The gore sheet has no [state]")
	for(var/state in list("mantis_flick_right", "mantis_flick_left"))
		TEST_ASSERT(icon_exists(MANTIS_TEST_LARGE_ICON, state), "The large gore sheet has no [state]")
	// Every piece the blade rig draws, for every model that can impale and scissor.
	var/list/moves = list(
		"impale" = list("arrive", "contact", "enter", "lift1", "lift2", "hold", "pull1", "pull2", "pull3", "rip", "drop"),
		"scissor" = list("raise", "glint", "close", "cut", "recover"),
	)
	for(var/model in list("mantis", "mantis_scorch"))
		for(var/move in moves)
			for(var/beat in moves[move])
				for(var/facing in GLOB.cardinals)
					var/list/spec = mantis_rig_beat(move, beat, facing)
					TEST_ASSERT(spec, "The rig has no [move] [beat] facing [dir2text(facing)]")
					for(var/piece in spec[MG_RIG_ORDER])
						if(piece == "T" || piece == "body" || piece == "whole")
							continue
						TEST_ASSERT(icon_exists(MANTIS_TEST_REACH_ICON, "[model]_[move]_[beat]_[piece]"), "The reach sheet has no [model]_[move]_[beat]_[piece]")
	// The beat only some views draw: the scissor's swing, seen from the side and the front.
	var/list/side_moves = list("scissor" = list("swing"))
	for(var/model in list("mantis", "mantis_scorch"))
		for(var/move in side_moves)
			for(var/beat in side_moves[move])
				for(var/facing in list(EAST, WEST, SOUTH))
					var/list/spec = mantis_rig_beat(move, beat, facing)
					TEST_ASSERT(spec, "The rig has no [move] [beat] facing [dir2text(facing)]")
					for(var/piece in spec[MG_RIG_ORDER])
						if(piece == "T" || piece == "body" || piece == "whole")
							continue
						TEST_ASSERT(icon_exists(MANTIS_TEST_REACH_ICON, "[model]_[move]_[beat]_[piece]"), "The reach sheet has no [model]_[move]_[beat]_[piece]")

/// What a torn artery looks like: drops thrown the way the cut went that land as spots, and the blood running
/// down the body for as long as the wound is open.
/datum/unit_test/voidcrew_mantis_gore/artery_look

/datum/unit_test/voidcrew_mantis_gore/artery_look/Run()
	for(var/height in list("low", "mid", "high"))
		for(var/strength in list("", "_weak"))
			TEST_ASSERT(icon_exists(MANTIS_TEST_ARTERY_ICON, "spurt_[height][strength]"), "The artery sheet has no spurt_[height][strength]")
			TEST_ASSERT(icon_exists(MANTIS_TEST_ICON, "artery_drops_[height][strength]"), "The gore sheet has no artery_drops_[height][strength]")
	for(var/zone in GLOB.all_body_zones)
		TEST_ASSERT(icon_exists(MANTIS_TEST_ICON, "artery_run_[zone]"), "The gore sheet has no artery_run_[zone]")
		TEST_ASSERT(icon_exists(MANTIS_TEST_ICON, "artery_ran_[zone]"), "The gore sheet has no artery_ran_[zone]")
	for(var/drips in 1 to 3)
		TEST_ASSERT(icon_exists(MANTIS_TEST_ICON, "artery_feet_[drips]"), "The gore sheet has no artery_feet_[drips]")

	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	victim.setDir(SOUTH)
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/wound/slash/flesh/critical/hv_carotid/limb/torn = hv_crit_apply_wound(arm, /datum/wound/slash/flesh/critical/hv_carotid/limb, EAST, null)
	TEST_ASSERT(torn, "The limb artery wound would not apply")
	// The artery throws its own drops: tg's wound spray, a line of blood three tiles long, stays out of it.
	TEST_ASSERT(!(locate(/obj/effect/decal/cleanable/blood/hitsplatter) in range(1, victim)), "The limb artery threw tg's own wound spray as well")
	TEST_ASSERT_EQUAL(torn.spurt_dir, EAST, "The limb artery forgot the cut's direction")
	TEST_ASSERT_EQUAL(mantis_artery_height(victim, BODY_ZONE_L_ARM), "mid", "An arm's artery is not at arm height")
	TEST_ASSERT_EQUAL(mantis_artery_height(victim, BODY_ZONE_R_LEG), "low", "A leg's artery is not near the floor")
	TEST_ASSERT_EQUAL(mantis_artery_height(victim, BODY_ZONE_HEAD), "high", "The neck's artery is not at neck height")

	// One spurt: drops in the air the way the cut went, then spots where they come down, a tile east.
	var/obj/effect/abstract/cyberware_anim/jet = mantis_spurt_fx(victim, BODY_ZONE_L_ARM, EAST)
	TEST_ASSERT_NOTNULL(jet, "A torn artery throws nothing")
	TEST_ASSERT_EQUAL(jet.icon_state, "spurt_mid", "An arm's spurt isn't the arm-height one")
	TEST_ASSERT_EQUAL(jet.dir, EAST, "The spurt doesn't fly the way the cut went")
	TEST_ASSERT(!(locate(/obj/effect/decal/cleanable/blood/drip/mantis_drops) in spot(2, 1)), "The drops are on the floor before they have flown")
	sleep(0.5 SECONDS)
	var/obj/effect/decal/cleanable/blood/drip/mantis_drops/drops = locate() in spot(2, 1)
	TEST_ASSERT_NOTNULL(drops, "The spurt's drops left no spots where they came down")
	TEST_ASSERT_EQUAL(drops.icon_state, "artery_drops_mid", "The spots are not the spurt's own")
	TEST_ASSERT_EQUAL(drops.dir, EAST, "The spots don't lie the way the drops flew")
	TEST_ASSERT(!(locate(/obj/effect/decal/cleanable/blood/hv_spray) in spot(2, 1)), "A spurt still lays a spray")
	// The next beat comes down on the same spots.
	mantis_spurt_fx(victim, BODY_ZONE_L_ARM, EAST)
	sleep(0.5 SECONDS)
	var/spots = 0
	for(var/obj/effect/decal/cleanable/blood/drip/mantis_drops/laid in spot(2, 1))
		spots++
	TEST_ASSERT_EQUAL(spots, 1, "A second beat stacked its spots on the first's")
	// A weak one falls close by.
	var/obj/effect/abstract/cyberware_anim/weak_jet = mantis_spurt_fx(victim, BODY_ZONE_L_ARM, EAST, TRUE)
	TEST_ASSERT_EQUAL(weak_jet?.icon_state, "spurt_mid_weak", "A weak spurt isn't the weak one")
	// Thrown straight up or down the screen out of an arm, the drops lean out to that arm's side and land clear
	// of the body. Thrown sideways they don't lean.
	var/list/straight = mantis_spurt_spot(list(6, 1), "mid", FALSE, NORTH)
	var/list/leaning = mantis_spurt_spot(list(6, 1), "mid", FALSE, NORTH, 1)
	TEST_ASSERT(leaning[1] > straight[1], "Drops thrown up the screen out of an arm on the right don't lean out to the right")
	TEST_ASSERT_EQUAL(leaning[2], straight[2], "Leaning out changed how far the drops fly")
	TEST_ASSERT_EQUAL(mantis_spurt_lean(FALSE, EAST, 1), 0, "Drops thrown sideways lean")
	// Every spurt's drops are still in its picture where they come down, on the last frame it holds. The neck's,
	// thrown down the screen, fall furthest: the wound sits above the picture's middle to leave them the room.
	// And its first frame is empty: the half beat a swinging blade cocks back, so no drop is out ahead of the cut.
	var/icon/spurt_sheet = icon(MANTIS_TEST_ARTERY_ICON)
	for(var/spurt_height in list("low", "mid", "high"))
		for(var/spurt_weak in list(FALSE, TRUE))
			var/list/spurt_shape = mantis_spurt_shape(spurt_height, spurt_weak)
			var/spurt_state = "spurt_[spurt_height][spurt_weak ? "_weak" : ""]"
			var/last_frame = spurt_shape[3] / 0.5 + 2
			for(var/way in GLOB.alldirs)
				var/list/landing = mantis_spurt_spot(list(0, 0), spurt_height, spurt_weak, way)
				var/landed = FALSE
				for(var/across in -3 to 3)
					for(var/up in -3 to 3)
						if(spurt_sheet.GetPixel(49 + landing[1] + across, 48 + MG_ARTERY_WOUND_RISE + landing[2] + up, spurt_state, way, last_frame))
							landed = TRUE
				TEST_ASSERT(landed, "The [spurt_state] thrown [dir2text(way)] has left its picture before its drops come down")
				var/early = FALSE
				for(var/across in -2 to 2)
					for(var/up in -2 to 2)
						if(spurt_sheet.GetPixel(49 + across, 48 + MG_ARTERY_WOUND_RISE + up, spurt_state, way, 1))
							early = TRUE
				TEST_ASSERT(!early, "The [spurt_state] thrown [dir2text(way)] has drops out of the wound before the blade has cut")

	// The blood runs down the body, and goes when the wound does.
	var/obj/effect/abstract/cyberware_anim/mantis_run/run = mantis_artery_run_fx(victim, BODY_ZONE_L_ARM, torn)
	TEST_ASSERT_NOTNULL(run, "A torn artery doesn't run down the body")
	TEST_ASSERT(run in victim.vis_contents, "The run isn't drawn on the body")
	TEST_ASSERT_EQUAL(run.icon_state, "artery_run_l_arm", "The run isn't the arm's")
	sleep(0.9 SECONDS)
	TEST_ASSERT_EQUAL(run.icon_state, "artery_ran_l_arm", "The run isn't held once it has run its length")
	// Three drips fall off its lower end and make a small pool at the feet, just under the body's own tile.
	sleep(0.5 SECONDS)
	var/obj/effect/decal/cleanable/blood/drip/mantis_drops/pool
	for(var/obj/effect/decal/cleanable/blood/drip/mantis_drops/found in get_step(victim, SOUTH))
		if(found.feet_drips)
			pool = found
	TEST_ASSERT_NOTNULL(pool, "The run dripped nothing at the feet")
	TEST_ASSERT_EQUAL(pool.icon_state, "artery_feet_3", "Three drips at the feet did not make the small pool")
	TEST_ASSERT_NOTNULL(mantis_artery_run_foot(BODY_ZONE_L_ARM, EAST), "The blood off a far arm comes down to no sole")
	// tg's own bleeding still drips onto a tile that holds the artery's spots, and makes its pool there in the end.
	var/turf/spotted = spot(2, 1)
	for(var/drips in 1 to 6)
		victim.get_bloodtype()?.make_blood_splatter(victim, spotted, TRUE)
	var/pooled = FALSE
	for(var/obj/effect/decal/cleanable/blood/splatter in spotted)
		if(!istype(splatter, /obj/effect/decal/cleanable/blood/drip))
			pooled = TRUE
	TEST_ASSERT(pooled, "Blood dripping onto the artery's spots never made a pool")
	qdel(torn)
	TEST_ASSERT(QDELETED(run), "The run outlived its wound")

	// Lying down the blood goes to the floor: low drops, and nothing runs down the body.
	victim.set_body_position(LYING_DOWN)
	TEST_ASSERT_EQUAL(mantis_artery_height(victim, BODY_ZONE_L_ARM), "low", "A body lying down still bleeds from arm height")
	var/datum/wound/slash/flesh/critical/hv_carotid/limb/again = hv_crit_apply_wound(arm, /datum/wound/slash/flesh/critical/hv_carotid/limb, EAST, null)
	TEST_ASSERT(again, "The limb artery wound would not apply a second time")
	TEST_ASSERT_NULL(mantis_artery_run_fx(victim, BODY_ZONE_L_ARM, again), "Blood runs down a body lying flat")

#undef MG_MOVE_IMPALE
#undef MG_MOVE_XSLASH
#undef MG_IMPALE_TRAIT
#undef MG_CHARGE_TRAIT
#undef MG_TRAIT_CAMO
#undef MG_FINISHER_DONE
#undef MG_FINISHER_DAMAGED
#undef MANTIS_TEST_ICON
#undef MANTIS_TEST_LARGE_ICON
#undef MANTIS_TEST_ARTERY_ICON
#undef MG_ARTERY_WOUND_RISE
#undef MANTIS_TEST_LEFTHAND
#undef MANTIS_TEST_RIGHTHAND
#undef MANTIS_TEST_REACH_ICON
#undef MG_RIG_ORDER
