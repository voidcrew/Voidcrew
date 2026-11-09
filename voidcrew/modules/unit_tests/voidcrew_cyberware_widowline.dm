/**
 * The Widowline monowire against the gore layer (voidcrew/modules/hyperviolence/wire/): clean severs and their
 * thresholds, the crossing cut, the Arc's seared stumps, the delayed cut's held limb, the through-cut, blood on
 * the wire, the swing out of the spool and back, the garrote, and the sleeve mask on every stump.
 *
 * Fork defines are included after the tests, so these use literals, each with a comment naming the define.
 * Cuts are driven through the wire's own hooks (wire_cut_begin(), apply_damage(), wire_cut_end()) so the zone
 * they land on is not left to tg's 80% aim roll.
 */

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_widowline
	abstract_type = /datum/unit_test/voidcrew_widowline

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_widowline/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A human holding a wire of `wire_type` in the active hand
/datum/unit_test/voidcrew_widowline/proc/wielder(turf/where, wire_type = /obj/item/melee/cyberware_monowire)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, where)
	var/obj/item/melee/cyberware_monowire/wire = allocate(wire_type)
	TEST_ASSERT(user.put_in_active_hand(wire), "Fixture: the wielder couldn't hold the wire")
	user.set_combat_mode(TRUE)
	return user

/// The wire in `user`'s active hand
/datum/unit_test/voidcrew_widowline/proc/held(mob/living/user)
	return user.get_active_held_item()

/// One cut of `wire` held by `user` into `victim`'s `zone`, aimed there, for the wire's force. Returns the damage dealt.
/datum/unit_test/voidcrew_widowline/proc/cut(mob/living/user, mob/living/victim, zone, aim = zone)
	var/obj/item/melee/cyberware_monowire/wire = held(user)
	user.zone_selected = aim
	wire.wire_cut_begin(victim, user)
	. = victim.apply_damage(wire.force, BRUTE, zone, 0, wound_bonus = CANT_WOUND, sharpness = SHARP_EDGED, attack_direction = get_dir(user, victim), attacking_item = wire)
	wire.wire_cut_end(victim)

/// The texts queued on `victim`'s hit, joined
/datum/unit_test/voidcrew_widowline/proc/lines(mob/living/victim)
	. = ""
	for(var/list/line as anything in victim.hv_hit?.lines)
		. += "[line[1]] | "

/// Flying hitsplatter near `where`
/datum/unit_test/voidcrew_widowline/proc/splatter(atom/where)
	. = 0
	for(var/obj/effect/decal/cleanable/blood/hitsplatter/splatter in range(6, where))
		.++

/// The held limb (wire_ghost) drawn on `victim`, if any
/datum/unit_test/voidcrew_widowline/proc/get_ghost(mob/living/victim)
	for(var/obj/effect/abstract/cyberware_anim/wire_ghost/ghost in victim.vis_contents)
		return ghost

/// When a limb comes off: only an aimed cut on an arm or leg already hurt enough, never a fresh limb, a corpse,
/// an Atlas frame, the head or chest; downed bodies at a lower threshold. Off clean: dropped at the body, no fan.
/datum/unit_test/voidcrew_widowline/wire_sever

/datum/unit_test/voidcrew_widowline/wire_sever/Run()
	var/mob/living/carbon/human/user = wielder(spot(0, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))

	// A fresh arm takes the cut and stays on.
	cut(user, victim, BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_L_ARM), "A fresh arm came off the first wire cut")
	// Not aimed there: never, however hurt.
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	cut(user, victim, BODY_ZONE_L_ARM, aim = BODY_ZONE_CHEST)
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_L_ARM), "An arm came off a cut aimed elsewhere")

	// Aimed at a badly hurt arm (60%, WIRE_SEVER_AT): off, clean.
	var/obj/item/bodypart/right = victim.get_bodypart(BODY_ZONE_R_ARM)
	right.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	var/before = splatter(victim)
	cut(user, victim, BODY_ZONE_R_ARM)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_R_ARM), "An aimed cut didn't take off an arm at 60%")
	TEST_ASSERT_EQUAL(right.loc, get_turf(victim), "The severed arm was flung instead of dropping at the body")
	TEST_ASSERT_EQUAL(right.dir, victim.dir, "The severed arm lies facing another way than it hung")

	// In profile: the near limb keeps the body's facing and lies down by the feet; the far arm lies as the near one would.
	var/mob/living/carbon/human/consistent/profile = allocate(/mob/living/carbon/human/consistent, spot(2, 3))
	profile.setDir(EAST)
	arm = profile.get_bodypart(BODY_ZONE_R_LEG)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	cut(user, profile, BODY_ZONE_R_LEG)
	TEST_ASSERT_NULL(profile.get_bodypart(BODY_ZONE_R_LEG), "Fixture: the leg didn't come off")
	TEST_ASSERT_EQUAL(arm.dir, EAST, "A leg cut from a body facing east doesn't lie facing east")
	TEST_ASSERT(abs(arm.transform.a) < 0.1 && arm.transform.f < -4, "The cut leg doesn't lie on the floor ([arm.transform.a], [arm.transform.f])")
	arm = profile.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	profile.setDir(EAST)
	cut(user, profile, BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(profile.get_bodypart(BODY_ZONE_L_ARM), "Fixture: the far arm didn't come off")
	TEST_ASSERT_EQUAL(arm.dir, WEST, "The far arm cut in profile isn't drawn as the near arm")
	TEST_ASSERT(abs(arm.transform.a) < 0.1, "The far arm cut in profile doesn't lie down")
	TEST_ASSERT_EQUAL(splatter(victim), before, "A wire sever threw tg's flying hitsplatter")
	TEST_ASSERT(findtext(lines(victim), "comes away clean"), "The sever's line didn't join the hit: [lines(victim)]")
	TEST_ASSERT(!HAS_TRAIT(victim, "hv_clean_cut"), "TRAIT_HV_CLEAN_CUT outlived the cut")

	// Head and chest never, even hurt enough on someone down.
	var/mob/living/carbon/human/consistent/stunned = allocate(/mob/living/carbon/human/consistent, spot(3, 3))
	stunned.Paralyze(100 SECONDS)
	var/obj/item/bodypart/head = stunned.get_bodypart(BODY_ZONE_HEAD)
	head.receive_damage(brute = 60, wound_bonus = CANT_WOUND)
	var/obj/item/bodypart/chest = stunned.get_bodypart(BODY_ZONE_CHEST)
	chest.receive_damage(brute = 60, wound_bonus = CANT_WOUND)
	var/mob/living/carbon/human/attacker = wielder(spot(3, 2))
	cut(attacker, stunned, BODY_ZONE_HEAD)
	TEST_ASSERT_NOTNULL(stunned.get_bodypart(BODY_ZONE_HEAD), "A wire cut took a head off")
	cut(attacker, stunned, BODY_ZONE_CHEST)
	TEST_ASSERT_NOTNULL(stunned.get_bodypart(BODY_ZONE_CHEST), "A wire cut took a chest off")

	// Down: a fifth is enough (WIRE_SEVER_AT_DOWN); less isn't.
	var/mob/living/carbon/human/consistent/downed = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	downed.Paralyze(100 SECONDS)
	var/obj/item/bodypart/leg = downed.get_bodypart(BODY_ZONE_L_LEG)
	leg.receive_damage(brute = 5, wound_bonus = CANT_WOUND)
	cut(user, downed, BODY_ZONE_L_LEG)
	TEST_ASSERT_NOTNULL(downed.get_bodypart(BODY_ZONE_L_LEG), "A leg on someone down came off at 10%")
	cut(user, downed, BODY_ZONE_L_LEG)
	TEST_ASSERT_NULL(downed.get_bodypart(BODY_ZONE_L_LEG), "A leg on someone down didn't come off past 20%")

	// A corpse keeps its limbs.
	var/mob/living/carbon/human/consistent/corpse = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	arm = corpse.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 45, wound_bonus = CANT_WOUND)
	corpse.death()
	cut(user, corpse, BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(corpse.get_bodypart(BODY_ZONE_L_ARM), "A wire cut took an arm off a corpse")

	// An Atlas frame keeps its limbs.
	var/mob/living/carbon/human/consistent/framed = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	ADD_TRAIT(framed, TRAIT_NODISMEMBER, TRAIT_SOURCE_UNIT_TESTS)
	arm = framed.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 45, wound_bonus = CANT_WOUND)
	cut(user, framed, BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(framed.get_bodypart(BODY_ZONE_L_ARM), "A wire cut took an arm off through an Atlas frame")

/// Mid wire cut tg's own roll never flings a limb: the wire takes it off clean after the hit.
/datum/unit_test/voidcrew_widowline/hv_wire_owed_sever

/datum/unit_test/voidcrew_widowline/hv_wire_owed_sever/Run()
	var/mob/living/carbon/human/user = wielder(spot(0, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	ADD_TRAIT(victim, "hv_clean_cut", TRAIT_SOURCE_UNIT_TESTS) // TRAIT_HV_CLEAN_CUT
	var/datum/wound/loss/torn = new
	torn.apply_dismember(arm, WOUND_SLASH)
	REMOVE_TRAIT(victim, "hv_clean_cut", TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(arm.owner, victim, "tg tore an arm off mid wire cut")
	TEST_ASSERT_EQUAL(victim.hv_wire_owed_sever, arm, "The arm tg wanted wasn't left for the wire")
	victim.hv_wire_owed_sever = null

	// Through the wire's own hook it comes off, though the arm was fresh and the cut aimed elsewhere.
	var/obj/item/melee/cyberware_monowire/wire = held(user)
	user.zone_selected = BODY_ZONE_CHEST
	wire.wire_cut_begin(victim, user)
	torn = new
	torn.apply_dismember(arm, WOUND_SLASH)
	victim.apply_damage(wire.force, BRUTE, BODY_ZONE_CHEST, 0, wound_bonus = CANT_WOUND, sharpness = SHARP_EDGED, attack_direction = EAST, attacking_item = wire)
	wire.wire_cut_end(victim)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_L_ARM), "The wire didn't take the arm tg's roll wanted")
	TEST_ASSERT_EQUAL(arm.loc, get_turf(victim), "The owed arm was flung")

	// A clean cut throws no hitsplatter; without it tg's does.
	var/before = splatter(victim)
	ADD_TRAIT(victim, "hv_clean_cut", TRAIT_SOURCE_UNIT_TESTS)
	victim.spray_blood(EAST, 3)
	TEST_ASSERT_EQUAL(splatter(victim), before, "spray_blood() threw hitsplatter during a clean cut")
	REMOVE_TRAIT(victim, "hv_clean_cut", TRAIT_SOURCE_UNIT_TESTS)
	victim.spray_blood(EAST, 3)
	TEST_ASSERT(splatter(victim) > before, "spray_blood() is dead outside a clean cut")

/// With a wire out in each hand every third landed hit crosses: both wires lash out, and a sever at half the damage.
/datum/unit_test/voidcrew_widowline/crossing

/datum/unit_test/voidcrew_widowline/crossing/Run()
	var/mob/living/carbon/human/user = wielder(spot(0, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 15, wound_bonus = CANT_WOUND)

	// One wire: 30% isn't enough, every time.
	for(var/i in 1 to 3)
		cut(user, victim, BODY_ZONE_CHEST)
	cut(user, victim, BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_L_ARM), "One wire took an arm at 30%")
	TEST_ASSERT_EQUAL(user.wire_cross_hits, 0, "One wire counted toward a crossing cut")
	victim.fully_heal(HEAL_DAMAGE)
	arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 15, wound_bonus = CANT_WOUND)

	// Two wires: the third landed hit crosses.
	var/obj/item/melee/cyberware_monowire/second = allocate(/obj/item/melee/cyberware_monowire)
	TEST_ASSERT(user.put_in_inactive_hand(second), "Fixture: no second hand for the second wire")
	cut(user, victim, BODY_ZONE_CHEST)
	cut(user, victim, BODY_ZONE_CHEST)
	var/obj/item/melee/cyberware_monowire/wire = held(user)
	TEST_ASSERT(wire.wire_cross_due(user), "The third hit with two wires out isn't the crossing one")
	for(var/obj/effect/abstract/wire_reach/old_lash in get_turf(user))
		qdel(old_lash)
	cut(user, victim, BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_L_ARM), "The crossing cut didn't take an arm at 30%")
	// The other hand's wire lashes out too; nothing is drawn over the target.
	TEST_ASSERT(locate(/obj/effect/abstract/wire_reach) in get_turf(user), "The crossing cut didn't lash the other wire")
	TEST_ASSERT(!(locate(/obj/effect/abstract/cyberware_anim) in victim.vis_contents), "The crossing cut drew over its target")
	TEST_ASSERT_EQUAL(user.wire_cross_hits, 0, "The count didn't start again after the crossing cut")

	// Hits too far apart start the count again.
	cut(user, victim, BODY_ZONE_CHEST)
	cut(user, victim, BODY_ZONE_CHEST)
	user.wire_cross_last -= 10 SECONDS
	TEST_ASSERT(!wire.wire_cross_due(user), "Hits seconds apart still cross")

	// The entry point with no mouse behind it: a crossing swing on demand, the target doll left as it was.
	for(var/obj/effect/abstract/wire_reach/old_lash in get_turf(user))
		qdel(old_lash)
	user.zone_selected = BODY_ZONE_HEAD
	TEST_ASSERT(wire.wire_crossing_swing(user, victim, BODY_ZONE_CHEST), "wire_crossing_swing() didn't swing")
	var/lashes = 0
	for(var/obj/effect/abstract/wire_reach/lash in get_turf(user))
		lashes++
	TEST_ASSERT(lashes >= 2, "wire_crossing_swing() didn't cross: [lashes] lash(es)")
	TEST_ASSERT_EQUAL(user.zone_selected, BODY_ZONE_HEAD, "An aimed swing left the wielder's target doll changed")
	TEST_ASSERT(!wire.force_cross, "A crossing swing left the next one crossing too")

/// The Arc sears the stump: little blood, the stump drawn charred; not on a body its shock can't reach.
/datum/unit_test/voidcrew_widowline/wire_sears

/datum/unit_test/voidcrew_widowline/wire_sears/Run()
	var/mob/living/carbon/human/user = wielder(spot(0, 1))
	var/mob/living/carbon/human/attacker = wielder(spot(0, 3), /obj/item/melee/cyberware_monowire/live)

	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	var/blood_before = victim.blood_volume
	cut(user, victim, BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_L_ARM), "Fixture: the plain wire didn't sever")
	TEST_ASSERT(blood_before - victim.blood_volume >= 40, "A plain sever lost too little blood ([blood_before - victim.blood_volume])")
	TEST_ASSERT(!LAZYACCESS(victim.hv_stump_burnt, BODY_ZONE_L_ARM), "The plain wire seared a stump")

	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent, spot(1, 3))
	arm = body.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	blood_before = body.blood_volume
	cut(attacker, body, BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(body.get_bodypart(BODY_ZONE_L_ARM), "The Arc didn't sever")
	TEST_ASSERT(blood_before - body.blood_volume <= 20, "A seared sever lost as much blood as a wet one ([blood_before - body.blood_volume])")
	TEST_ASSERT(LAZYACCESS(body.hv_stump_burnt, BODY_ZONE_L_ARM), "The Arc's stump isn't seared")
	TEST_ASSERT(findtext(lines(body), "seared shut"), "The seared sever's line is missing: [lines(body)]")
	body.hv_reveal_stump(BODY_ZONE_L_ARM)
	var/charred = FALSE
	for(var/image/gore_image as anything in body.hv_gore_overlays)
		if(gore_image.icon_state == "stump_l_arm_blood" && gore_image.color == "#2a1b15") // WIRE_BURNT_STUMP_COLOR
			charred = TRUE
	TEST_ASSERT(charred, "The seared stump isn't drawn charred")
	// A limb back on forgets the sear.
	body.regenerate_limb(BODY_ZONE_L_ARM)
	body.update_damage_overlays()
	TEST_ASSERT(!LAZYACCESS(body.hv_stump_burnt, BODY_ZONE_L_ARM), "A new arm kept the old stump's sear")

	// Shock-immune: a plain wet sever.
	var/mob/living/carbon/human/consistent/grounded = allocate(/mob/living/carbon/human/consistent, spot(2, 3))
	ADD_TRAIT(grounded, TRAIT_SHOCKIMMUNE, TRAIT_SOURCE_UNIT_TESTS)
	arm = grounded.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	cut(attacker, grounded, BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(grounded.get_bodypart(BODY_ZONE_L_ARM), "The Arc didn't sever a shock-immune arm")
	TEST_ASSERT(!LAZYACCESS(grounded.hv_stump_burnt, BODY_ZONE_L_ARM), "The Arc seared a stump its shock can't reach")

/// The delayed cut: the limb stays drawn on, its stump held back, until it slides; nothing lingers after, and a
/// body deleted, restored or carried off mid-beat takes the picture with it.
/datum/unit_test/voidcrew_widowline/wire_ghost

/datum/unit_test/voidcrew_widowline/wire_ghost/Run()
	var/mob/living/carbon/human/user = wielder(spot(0, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	cut(user, victim, BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_L_ARM), "Fixture: the arm didn't come off")
	var/obj/effect/abstract/cyberware_anim/wire_ghost/ghost = get_ghost(victim)
	TEST_ASSERT_NOTNULL(ghost, "The severed arm isn't held on its body for the beat")
	TEST_ASSERT(length(ghost.overlays), "The held arm draws nothing")
	TEST_ASSERT(!("stump_l_arm_blood" in victim.hv_gore_states()), "The stump shows while the arm is still drawn on")
	TEST_ASSERT_EQUAL(arm.alpha, 255, "The severed arm on the floor isn't really there yet (server alpha)")
	ghost.slide()
	TEST_ASSERT(("stump_l_arm_blood" in victim.hv_gore_states()), "The stump didn't show when the arm slid off")
	sleep(1 SECONDS)
	TEST_ASSERT_NULL(get_ghost(victim), "The held arm lingered after it slid off")

	// The body deleted mid-beat.
	var/mob/living/carbon/human/consistent/doomed = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	arm = doomed.get_bodypart(BODY_ZONE_R_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	cut(user, doomed, BODY_ZONE_R_ARM)
	ghost = get_ghost(doomed)
	TEST_ASSERT_NOTNULL(ghost, "Fixture: no held arm on the doomed body")
	qdel(doomed)
	TEST_ASSERT(QDELETED(ghost), "The held arm outlived its body")

	// The limb back on mid-beat: the picture just goes.
	var/mob/living/carbon/human/consistent/healed = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	arm = healed.get_bodypart(BODY_ZONE_R_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	cut(user, healed, BODY_ZONE_R_ARM)
	ghost = get_ghost(healed)
	healed.regenerate_limb(BODY_ZONE_R_ARM)
	ghost.slide()
	TEST_ASSERT(!LAZYACCESS(healed.hv_stump_reveal_at, BODY_ZONE_R_ARM), "A restored arm left its stump held back")
	sleep(0.3 SECONDS)
	TEST_ASSERT_NULL(get_ghost(healed), "The held arm stayed on a body whose arm grew back")

	// Death mid-beat: it still never outlives the hard timer.
	var/mob/living/carbon/human/consistent/dying = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	arm = dying.get_bodypart(BODY_ZONE_L_LEG)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	cut(user, dying, BODY_ZONE_L_LEG)
	TEST_ASSERT_NOTNULL(get_ghost(dying), "Fixture: no held leg")
	dying.death()
	sleep(1.5 SECONDS)
	TEST_ASSERT_NULL(get_ghost(dying), "The held leg outlived its beat on a body that died")

/// The wire carries on into whoever stands behind the target and cleaves the rest, as lines of the one hit.
/datum/unit_test/voidcrew_widowline/wire_cleave

/datum/unit_test/voidcrew_widowline/wire_cleave/Run()
	var/mob/living/carbon/human/user = wielder(spot(0, 1))
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/mob/living/carbon/human/consistent/behind = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	var/mob/living/carbon/human/consistent/beside = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	var/obj/item/melee/cyberware_monowire/wire = held(user)
	wire.wire_cleave(target, user)
	TEST_ASSERT(behind.getBruteLoss() > 0, "The mob behind the target took no cut")
	TEST_ASSERT(beside.getBruteLoss() > 0, "The mob beside the target took no cleave")
	var/result = lines(target)
	TEST_ASSERT(findtext(result, "carries through into [behind]"), "The through-cut's line didn't join the hit: [result]")
	TEST_ASSERT(findtext(result, "sings through everything beside"), "The cleave's line didn't join the hit: [result]")
	var/streak = locate(/obj/effect/decal/cleanable/blood/hv_spray/streak) in get_turf(behind)
	TEST_ASSERT_NOTNULL(streak, "The through-cut left no streak through the second body's tile")
	TEST_ASSERT(!HAS_TRAIT(behind, "hv_clean_cut"), "TRAIT_HV_CLEAN_CUT outlived the cleave")

	// A real swing does all of it in one message.
	target.hv_flush_hit()
	behind.fully_heal(HEAL_DAMAGE)
	user.zone_selected = BODY_ZONE_CHEST
	wire.melee_attack_chain(user, target)
	TEST_ASSERT(target.getBruteLoss() > 0, "The swing didn't land")
	TEST_ASSERT(behind.getBruteLoss() > 0, "A landed swing didn't carry through")

/// A cut wets the wire with the victim's blood, which drips, dries and flicks off on stowing; the DNA stays. The Arc stays clean.
/datum/unit_test/voidcrew_widowline/wire_bloody

/datum/unit_test/voidcrew_widowline/wire_bloody/Run()
	var/mob/living/carbon/human/user = wielder(spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	var/obj/item/melee/cyberware_monowire/wire = held(user)
	TEST_ASSERT_EQUAL(wire.blood_stage(), 0, "A new wire is bloody")
	cut(user, victim, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(wire.blood_stage(), 2, "A cut didn't wet the wire")
	TEST_ASSERT(length(GET_ATOM_BLOOD_DNA(wire)), "A cut left no blood DNA on the wire")
	var/found = FALSE
	for(var/mutable_appearance/look in wire.worn_overlays(mutable_appearance(wire.righthand_file, "monowire"), TRUE, wire.righthand_file))
		if(look.icon_state == "monowire_blood2")
			found = TRUE
	TEST_ASSERT(found, "The wet wire draws no blood in hand")
	for(var/look in wire.overlays)
		var/mutable_appearance/drawn = look
		TEST_ASSERT_NOTEQUAL(drawn.icon_state, "itemblood", "tg's generic stain is drawn on the wire")

	// Drips, capped.
	for(var/i in 1 to 12)
		wire.drip()
	var/drips = 0
	for(var/obj/effect/decal/cleanable/blood/drip/drop in get_turf(user))
		drips++
	TEST_ASSERT(drips > 0, "A wet wire never dripped")
	TEST_ASSERT(wire.drips_left >= 0, "The drips ran past their cap")

	// Dry to stained.
	wire.wet_until = world.time - 1
	wire.update_blood_look()
	TEST_ASSERT_EQUAL(wire.blood_stage(), 1, "The wire didn't dry to a stain")

	// Wet again, stowed: drops in front, the look clears, the DNA stays.
	cut(user, victim, BODY_ZONE_CHEST)
	user.setDir(EAST)
	var/list/plan = wire_fan_plan(EAST, "right")
	TEST_ASSERT_EQUAL(length(plan), 6, "The fan isn't six drops") // WIRE_FLICK_DROPS
	for(var/list/drop as anything in plan)
		TEST_ASSERT(drop[3] > drop[1] && abs(drop[4]) <= 48, "A drop of the fan lands behind the wielder or too far off ([drop[3]], [drop[4]])")
	var/turf/ahead = get_step(user, EAST)
	var/before = 0
	for(var/obj/effect/decal/cleanable/blood/drip/drop in range(2, user))
		if(get_turf(drop) != get_turf(user))
			before++
	wire.flick_blood(user, "right")
	TEST_ASSERT(locate(/obj/effect/temp_visual/wire_blood_drop) in get_turf(user), "The fan threw no drops")
	sleep(1 SECONDS)
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood/drip) in ahead, "The fan landed no blood ahead")
	var/after = 0
	for(var/obj/effect/decal/cleanable/blood/drip/drop in range(2, user))
		if(get_turf(drop) != get_turf(user))
			after++
	TEST_ASSERT(after - before <= 6, "The fan left more drips than drops")
	wire.clear_blood_look()
	TEST_ASSERT_EQUAL(wire.blood_stage(), 0, "The flick left the wire looking bloody")
	TEST_ASSERT(length(GET_ATOM_BLOOD_DNA(wire)), "The flick wiped the blood DNA")

	// A wash clears it all.
	cut(user, victim, BODY_ZONE_CHEST)
	wire.wash(CLEAN_TYPE_BLOOD)
	TEST_ASSERT_EQUAL(wire.blood_stage(), 0, "A wash left the wire bloody")

	// The Arc burns its blood off.
	var/mob/living/carbon/human/attacker = wielder(spot(1, 3), /obj/item/melee/cyberware_monowire/live)
	var/obj/item/melee/cyberware_monowire/arc = held(attacker)
	cut(attacker, victim, BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(arc.blood_stage(), 0, "The Arc shows blood")

/// The wire swings out of the spool and reels back in, the held wire hidden for the swing; a wet one flicks.
/datum/unit_test/voidcrew_widowline/play_deploy

/datum/unit_test/voidcrew_widowline/play_deploy/Run()
	var/mob/living/carbon/human/consistent/bearer = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire/housing = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire)
	TEST_ASSERT(housing.Insert(bearer, special = TRUE), "Fixture: the housing wouldn't go in")
	housing.ui_action_click()
	var/obj/item/melee/cyberware_monowire/wire = housing.active_item
	TEST_ASSERT(istype(wire) && bearer.is_holding(wire), "The wire didn't deploy")
	var/list/states = list()
	for(var/obj/effect/abstract/cyberware_anim/look in bearer.vis_contents)
		states += look.icon_state
	TEST_ASSERT(("monowire_deploy_right" in states) || ("monowire_deploy_left" in states), "The wire didn't swing out: [jointext(states, ", ")]")
	TEST_ASSERT(wire.inhand_hidden_until > world.time, "The held wire shows over its own swing")

	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	bearer.zone_selected = BODY_ZONE_CHEST
	wire.wire_cut_begin(victim, bearer)
	victim.apply_damage(wire.force, BRUTE, BODY_ZONE_CHEST, 0, wound_bonus = CANT_WOUND, sharpness = SHARP_EDGED, attack_direction = EAST, attacking_item = wire)
	wire.wire_cut_end(victim)
	TEST_ASSERT_EQUAL(wire.blood_stage(), 2, "Fixture: the cut didn't wet the wire")
	for(var/obj/effect/abstract/cyberware_anim/look in bearer.vis_contents)
		qdel(look)
	housing.ui_action_click()
	TEST_ASSERT(wire.loc == housing, "The wire didn't stow")
	states = list()
	for(var/obj/effect/abstract/cyberware_anim/look in bearer.vis_contents)
		states += look.icon_state
	TEST_ASSERT(("monowire_retract_right" in states) || ("monowire_retract_left" in states), "The wire didn't reel in: [jointext(states, ", ")]")
	TEST_ASSERT(("monowire_retract_blood2_right" in states) || ("monowire_retract_blood2_left" in states), "A wet wire reeled in clean: [jointext(states, ", ")]")
	TEST_ASSERT_EQUAL(wire.blood_stage(), 0, "The wire is still bloody in its spool")

/// The garrote: only on someone helpless (crit or stunned, not just lying down), even a fellow player; no mark;
/// a real grab; the head in hard crit, the throat otherwise, turned by a collar; broken by damage; the wire's blow.
/datum/unit_test/voidcrew_widowline/garrote

/datum/unit_test/voidcrew_widowline/garrote/Run()
	var/mob/living/carbon/human/user = wielder(spot(1, 1))
	var/obj/item/melee/cyberware_monowire/wire = held(user)
	user.zone_selected = BODY_ZONE_HEAD

	// On their feet, or just lying down: no.
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	TEST_ASSERT(!wire.wire_try_garrote(victim, user), "A garrote started on someone standing")
	victim.Knockdown(100 SECONDS)
	TEST_ASSERT(!wire.wire_try_garrote(victim, user), "A garrote started on someone only knocked down")
	victim.SetKnockdown(0)

	// Stunned, though both are neutral-faction people: yes. No mark; the wire thrown at the neck.
	victim.Paralyze(100 SECONDS)
	TEST_ASSERT(wire.wire_try_garrote(victim, user), "A garrote didn't start on a stunned person")
	var/datum/hv_finisher/garrote/garrote = wire.garrote_running
	TEST_ASSERT_NOTNULL(garrote, "The wire doesn't know its garrote")
	TEST_ASSERT_NULL(garrote.mark, "The garrote put a mark over its victim")
	TEST_ASSERT_EQUAL(length(garrote.reach_refs), 1, "No wire thrown at the neck in the wind-up")
	TEST_ASSERT(user.wire_garrote_ready_at > world.time, "The garrote started with no wait after it")
	TEST_ASSERT(!wire.wire_try_garrote(victim, user), "A second garrote started at once")
	// The hold: a real grab, the wire tight.
	garrote.advance()
	TEST_ASSERT(garrote.gripped, "The garrote's hold didn't grip")
	TEST_ASSERT(user.pulling == victim && user.grab_state >= GRAB_AGGRESSIVE, "The garrote's hold isn't a real aggressive grab")
	var/datum/weakref/loop_ref = LAZYACCESS(garrote.loop_refs, 1)
	var/obj/effect/abstract/cyberware_anim/loop = loop_ref?.resolve()
	TEST_ASSERT(loop && loop.icon_state == "garrote_tight_front", "The wire didn't pull tight")
	// The grab's own pull is applied (12 px toward the garroter, who stands west), the body lies head first to them,
	// and the hold draws it in until its head lies at their feet, on the floor: never lifted.
	TEST_ASSERT_EQUAL(LAZYACCESS(LAZYACCESS(victim.offsets, PIXEL_X_OFFSET), GRABBING_TRAIT), -12, "The grab didn't pull the body in")
	TEST_ASSERT_EQUAL(victim.lying_angle, LYING_ANGLE_WEST, "The body doesn't lie head first to the garroter")
	var/list/neck = garrote.neck_point()
	var/list/hands = garrote.hold_point()
	TEST_ASSERT(abs(neck[1] - hands[1]) <= 2 && abs(neck[2] - hands[2]) <= 2, "The neck isn't at the garroter's feet ([neck[1]],[neck[2]] vs [hands[1]],[hands[2]])")
	TEST_ASSERT(!LAZYACCESS(LAZYACCESS(victim.offsets, PIXEL_Y_OFFSET), HV_FINISHER_OFFSET), "The hold lifted the body off the floor")
	TEST_ASSERT_EQUAL(length(garrote.strand_refs), 2, "The wire doesn't run from both hands")
	// The strands' ends on the neck go with it as it thrashes.
	for(var/datum/weakref/strand_ref as anything in garrote.strand_refs)
		var/obj/effect/abstract/wire_reach/strand = strand_ref.resolve()
		TEST_ASSERT_EQUAL(length(strand?.span), 2, "A strand doesn't know where its end on the neck is")
	garrote.thrash(0.5 SECONDS)
	TEST_ASSERT(user.wire_garrote_ready_at - world.time > 10 SECONDS, "A garrote that got a grip has the short wait")
	// The kill, not in hard crit: the throat.
	for(var/i in 1 to 10)
		if(!garrote.running)
			break
		garrote.advance()
	var/obj/item/bodypart/head = victim.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_NOTNULL(head, "A garrote took the head off someone only stunned")
	TEST_ASSERT_NOTNULL(locate(/datum/wound/slash/flesh/critical/hv_carotid) in head.wounds, "The garrote didn't slit the throat")
	TEST_ASSERT_NULL(wire.garrote_running, "The wire still thinks it is garroting")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/hv_finisher_hold), "The victim is still held")
	// Let go at the kill: nothing of the grab or the hold still draws the body off its tile.
	TEST_ASSERT(user.pulling != victim, "The garroter still holds the body")
	TEST_ASSERT(!LAZYACCESS(LAZYACCESS(victim.offsets, PIXEL_X_OFFSET), GRABBING_TRAIT) && !LAZYACCESS(LAZYACCESS(victim.offsets, PIXEL_X_OFFSET), HV_FINISHER_OFFSET), "The body is still drawn pulled in after the kill")

	// Hard crit: the head, at the body's feet.
	user.wire_garrote_ready_at = 0
	var/mob/living/carbon/human/consistent/dying = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	dying.equip_to_slot_or_del(new /obj/item/radio/headset(dying), ITEM_SLOT_EARS)
	dying.apply_damage(150, OXY)
	TEST_ASSERT(dying.stat >= HARD_CRIT && dying.stat != DEAD, "Fixture: not in hard crit ([dying.stat])")
	user.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(!wire.wire_try_garrote(dying, user), "A click at the chest started a garrote")
	TEST_ASSERT(wire.wire_start_garrote(user, dying), "wire_start_garrote() didn't start on someone in hard crit")
	user.zone_selected = BODY_ZONE_HEAD
	garrote = wire.garrote_running
	for(var/i in 1 to 10)
		if(!garrote.running)
			break
		garrote.advance()
	var/obj/item/bodypart/taken = locate(/obj/item/bodypart/head) in get_turf(dying)
	TEST_ASSERT_NULL(dying.get_bodypart(BODY_ZONE_HEAD), "A garrote in hard crit didn't take the head")
	TEST_ASSERT_NOTNULL(taken, "The head wasn't left at the body")
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/brain) in taken, "The head lost its brain")
	// The garroter stands south of this one: the head drops toward their feet.
	TEST_ASSERT(taken.transform.f + taken.pixel_y < 0, "The head didn't drop at the garroter's feet ([taken.transform.f], [taken.pixel_y])")
	// The headset came off with it and lies on its side by it, not stood up on the body.
	var/obj/item/radio/headset/headset = locate() in get_turf(dying)
	TEST_ASSERT_NOTNULL(headset, "The headset didn't come off with the head")
	TEST_ASSERT(abs(headset.transform.b) > 0.5, "The headset isn't lying on its side by the head")
	// The pool goes down once the body has settled after the kill.
	sleep(0.5 SECONDS)
	var/pooled = FALSE
	for(var/obj/effect/decal/cleanable/blood/pool in get_turf(dying))
		if(!istype(pool, /obj/effect/decal/cleanable/blood/drip) && !istype(pool, /obj/effect/decal/cleanable/blood/hv_spray))
			pooled = TRUE
	TEST_ASSERT(pooled, "The neck left no pool under the body")

	// A sealed helmet turns the wire: no slit throat, a blow instead.
	user.wire_garrote_ready_at = 0
	var/mob/living/carbon/human/consistent/helmeted = allocate(/mob/living/carbon/human/consistent, spot(2, 2))
	helmeted.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/space(helmeted), ITEM_SLOT_HEAD)
	helmeted.Paralyze(100 SECONDS)
	TEST_ASSERT(wire.wire_try_garrote(helmeted, user), "Fixture: no garrote on the helmeted victim")
	garrote = wire.garrote_running
	for(var/i in 1 to 10)
		if(!garrote.running)
			break
		garrote.advance()
	head = helmeted.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_NULL(locate(/datum/wound/slash/flesh/critical/hv_carotid) in head.wounds, "The wire slit a throat under a sealed helmet")

	// Damage on the garroter breaks it, and a garrote that never gripped has the short wait.
	user.wire_garrote_ready_at = 0
	var/mob/living/carbon/human/consistent/saved = allocate(/mob/living/carbon/human/consistent, spot(0, 1))
	saved.Paralyze(100 SECONDS)
	TEST_ASSERT(wire.wire_try_garrote(saved, user), "Fixture: no garrote on the last victim")
	garrote = wire.garrote_running
	user.apply_damage(25, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(!garrote.running, "25 damage on the garroter didn't break the garrote")
	TEST_ASSERT_EQUAL(garrote.result, 3, "The garrote ended for the wrong reason") // HV_FINISHER_DAMAGED
	TEST_ASSERT(user.wire_garrote_ready_at - world.time <= 5 SECONDS, "A garrote that never gripped has the long wait")
	TEST_ASSERT(!saved.has_status_effect(/datum/status_effect/hv_finisher_hold), "The broken garrote still holds its victim")

	// The garrote's blow is the wire's, never the heaviest thing in the other hand.
	user.fully_heal(HEAL_ALL)
	user.wire_garrote_ready_at = 0
	var/obj/item/claymore/heavy = allocate(/obj/item/claymore)
	user.put_in_inactive_hand(heavy)
	saved.SetParalyzed(100 SECONDS)
	TEST_ASSERT(wire.wire_try_garrote(saved, user), "A garrote didn't start with a heavier weapon in the other hand")
	garrote = wire.garrote_running
	TEST_ASSERT(garrote.real_blow(BODY_ZONE_HEAD), "The garrote's blow didn't swing")
	TEST_ASSERT_EQUAL(user.get_active_held_item(), wire, "The garrote swung the heavier weapon, not the wire")
	garrote.stop(2) // HV_FINISHER_LOST_GRIP

	// The crit gates never count the wire's penetration; its cuts still do.
	TEST_ASSERT_EQUAL(hv_crit_armour_pen(wire), 0, "The wire's penetration counts at the crit gates")
	TEST_ASSERT_EQUAL(wire.armour_penetration, 100, "The wire lost its penetration for its cuts")

/// Every stump: the jumpsuit is cut away where the lost limb was, and comes back with the limb.
/datum/unit_test/voidcrew_widowline/hv_mask_sleeves

/datum/unit_test/voidcrew_widowline/hv_mask_sleeves/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	body.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(body), ITEM_SLOT_ICLOTHING)
	var/mutable_appearance/uniform = body.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT(istype(uniform), "Fixture: no jumpsuit drawn")
	TEST_ASSERT(!LAZYACCESS(uniform.filter_data, "hv_sleeve_mask"), "A whole body's jumpsuit is masked")
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	arm.dismember()
	uniform = body.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT(LAZYACCESS(uniform.filter_data, "hv_sleeve_mask"), "The jumpsuit keeps an empty sleeve on a lost arm")
	body.regenerate_limb(BODY_ZONE_L_ARM)
	body.update_body_parts()
	uniform = body.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT(!LAZYACCESS(uniform.filter_data, "hv_sleeve_mask"), "The jumpsuit stayed masked with the arm back on")

/// The aimed sever, the crossing cut and the garrote are the wielder's moves, through one switch
/// (hv_wire_moves_allowed()): a human NPC holding a wire doesn't use them yet.
/datum/unit_test/voidcrew_widowline/hv_wire_moves_allowed

/datum/unit_test/voidcrew_widowline/hv_wire_moves_allowed/Run()
	var/mob/living/carbon/human/npc/chrome_dummy/npc = allocate(/mob/living/carbon/human/npc/chrome_dummy, spot(0, 1))
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent, spot(0, 3))
	TEST_ASSERT(!hv_wire_moves_allowed(npc), "A human NPC may use the wire's moves")
	TEST_ASSERT(hv_wire_moves_allowed(body), "A player's body may not use the wire's moves")
	var/obj/item/melee/cyberware_monowire/wire = allocate(/obj/item/melee/cyberware_monowire)
	TEST_ASSERT(npc.put_in_active_hand(wire), "Fixture: the NPC couldn't hold the wire")
	npc.set_combat_mode(TRUE)

	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot(1, 1))
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 30, wound_bonus = CANT_WOUND)
	cut(npc, victim, BODY_ZONE_L_ARM)
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_L_ARM), "A human NPC's aimed wire cut took an arm")
	TEST_ASSERT(victim.getBruteLoss() > 0, "The NPC's wire did no damage at all")

	var/obj/item/melee/cyberware_monowire/second = allocate(/obj/item/melee/cyberware_monowire)
	npc.put_in_inactive_hand(second)
	npc.wire_cross_hits = 2
	npc.wire_cross_last = world.time
	TEST_ASSERT(!wire.wire_cross_due(npc), "A human NPC with two wires makes the crossing cut")

	npc.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/consistent/downed = allocate(/mob/living/carbon/human/consistent, spot(1, 2))
	downed.Paralyze(100 SECONDS)
	TEST_ASSERT(!wire.wire_try_garrote(downed, npc), "A human NPC started a garrote")
	TEST_ASSERT(!wire.wire_start_garrote(npc, downed), "A human NPC started a garrote from the entry point")
	TEST_ASSERT(!wire.wire_crossing_swing(npc, victim), "A human NPC made a crossing swing from the entry point")
	// Its plain aimed swing still cuts, as the wire always did.
	var/before = victim.getBruteLoss()
	TEST_ASSERT(wire.wire_aimed_swing(npc, victim, BODY_ZONE_CHEST), "A human NPC couldn't swing the wire at all")
	TEST_ASSERT(victim.getBruteLoss() > before, "A human NPC's wire swing did nothing")
