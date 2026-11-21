// Decision 45: the stealth head shot graded by the round and the head's protection, shields and shots in the back, and
// the throat cut from behind (voidcrew/modules/stealth/stealth_crits.dm, hyperviolence/overlays_exec/knife_executions.dm,
// voidcrew/edits/objects/items/shield_rear.dm, voidcrew/edits/datums/neck_slice_mute.dm). Unit tests compile before
// voidcrew/_DEFINES, so values are written out: STEALTH_HEAD_SHOT_BRAIN_DAMAGE 120, STEALTH_CALL_ALARM 3.

/// A gun of `gun_type` in `shooter`'s hand, aimed at the head.
/datum/unit_test/proc/d45_arm(mob/living/carbon/human/shooter, gun_type, suppressed = FALSE)
	var/obj/item/gun/ballistic/gun = allocate(gun_type)
	gun.can_misfire = FALSE
	if(suppressed)
		gun.install_suppressor(new /obj/item/suppressor(gun))
	shooter.put_in_active_hand(gun, forced = TRUE)
	shooter.zone_selected = BODY_ZONE_HEAD
	return gun

/// A bare-headed guard (no helmet, no mask) at (dx, dy), facing east.
/datum/unit_test/proc/d45_bare_guard(datum/turf_reservation/block, dx, dy)
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, dx, dy)
	if(guard.head)
		qdel(guard.head)
	if(guard.wear_mask)
		qdel(guard.wear_mask)
	return guard

/// Puts `helmet_type` on `guard`.
/datum/unit_test/proc/d45_helmet(mob/living/carbon/human/guard, helmet_type)
	var/obj/item/clothing/helmet = new helmet_type(guard)
	TEST_ASSERT(guard.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD, disable_warning = TRUE), "Couldn't put [helmet] on the guard")

/// (a) A .357 to the back of an unaware guard's bare head bursts it: no head, dead.
/datum/unit_test/voidcrew_stealth_d45_burst

/datum/unit_test/voidcrew_stealth_d45_burst/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 2)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 2)
	var/obj/item/gun/gun = d45_arm(person, /obj/item/gun/ballistic/revolver)
	gun.fire_gun(guard, person, TRUE, null)
	TEST_ASSERT_NULL(guard.get_bodypart(BODY_ZONE_HEAD), "A .357 to an unaware guard's bare head didn't burst it")
	TEST_ASSERT_EQUAL(guard.stat, DEAD, "A guard whose head burst is alive")
	qdel(block)

/// (b) A suppressed 9mm to an unaware guard's bare head: through the skull, brain damage, a heavy bleed, out cold. A
/// .357 to a guard with Dermal Mesh is stepped down to the same.
/datum/unit_test/voidcrew_stealth_d45_down

/datum/unit_test/voidcrew_stealth_d45_down/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 2)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 2)
	var/obj/item/gun/gun = d45_arm(person, /obj/item/gun/ballistic/automatic/pistol, suppressed = TRUE)
	gun.fire_gun(guard, person, TRUE, null)
	var/obj/item/bodypart/head = guard.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_NOTNULL(head, "A suppressed 9mm burst a head")
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/pierce/bleed/critical/hv_head_shot), "A suppressed 9mm head shot left no wound through the skull")
	TEST_ASSERT(guard.get_organ_loss(ORGAN_SLOT_BRAIN) >= 120, "The head shot did too little brain damage ([guard.get_organ_loss(ORGAN_SLOT_BRAIN)])")
	TEST_ASSERT(guard.IsUnconscious(), "The guard shot through the head isn't out cold")
	TEST_ASSERT(guard.stat >= UNCONSCIOUS, "The guard shot through the head is still conscious")
	TEST_ASSERT(guard.get_bleed_rate() >= 5, "The head shot doesn't bleed heavily ([guard.get_bleed_rate()])")
	// Dermal Mesh (physiology armour, as the implant applies it) steps a .357 down from a burst to the same.
	var/mob/living/carbon/human/npc/meshed = d45_bare_guard(block, 4, 4)
	meshed.physiology.armor = meshed.physiology.armor.add_other_armor(/datum/armor/cyberware_dermal_mesh)
	var/mob/living/carbon/human/second = stealth_person(block, 3, 4)
	gun = d45_arm(second, /obj/item/gun/ballistic/revolver)
	gun.fire_gun(meshed, second, TRUE, null)
	head = meshed.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_NOTNULL(head, "Dermal Mesh didn't step a .357 down from a burst")
	TEST_ASSERT_NOTNULL(head.get_wound_type(/datum/wound/pierce/bleed/critical/hv_head_shot), "A .357 through Dermal Mesh didn't go through the skull")
	qdel(block)

/// (c) A 9mm into a SWAT helmet: knocked out for a few seconds, no wound through the skull. A heavy helmet stops it: only
/// the hit. An alert guard and an ordinary person: only the hit.
/datum/unit_test/voidcrew_stealth_d45_helmet

/datum/unit_test/voidcrew_stealth_d45_helmet/Run()
	var/datum/turf_reservation/block = stealth_block(8, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	d45_helmet(guard, /obj/item/clothing/head/helmet/swat)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	var/obj/item/gun/gun = d45_arm(person, /obj/item/gun/ballistic/automatic/pistol)
	gun.fire_gun(guard, person, TRUE, null)
	var/obj/item/bodypart/head = guard.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_NOTNULL(head, "A 9mm burst a helmeted head")
	TEST_ASSERT_NULL(head.get_wound_type(/datum/wound/pierce/bleed/critical/hv_head_shot), "A 9mm went through a SWAT helmet")
	TEST_ASSERT(guard.IsUnconscious(), "A 9mm into a SWAT helmet didn't knock the guard out")
	TEST_ASSERT(guard.AmountUnconscious() <= 8 SECONDS, "The helmet knockout is too long ([guard.AmountUnconscious()])")
	// A heavy helmet (bullet 60): just the hit.
	var/mob/living/carbon/human/npc/heavy = d45_bare_guard(block, 4, 3)
	d45_helmet(heavy, /obj/item/clothing/head/helmet/alt)
	var/mob/living/carbon/human/second = stealth_person(block, 3, 3)
	gun = d45_arm(second, /obj/item/gun/ballistic/automatic/pistol)
	gun.fire_gun(heavy, second, TRUE, null)
	TEST_ASSERT(!heavy.IsUnconscious(), "A 9mm into a heavy helmet knocked the guard out")
	TEST_ASSERT(heavy.getBruteLoss() > 0, "Test fixture: the shot into the heavy helmet missed")
	// An alert guard, bare headed: just the hit.
	var/mob/living/carbon/human/npc/alert = d45_bare_guard(block, 4, 5)
	var/datum/ai_controller/basic_controller/human_npc/stealth/alert_ai = stealth_ai(alert)
	var/mob/living/carbon/human/third = stealth_person(block, 3, 5)
	alert_ai.stealth_go_alert(third)
	alert_ai.stealth_rewind(1)
	gun = d45_arm(third, /obj/item/gun/ballistic/automatic/pistol)
	gun.fire_gun(alert, third, TRUE, null)
	TEST_ASSERT(!alert.IsUnconscious(), "An alert guard was knocked out by a head shot")
	TEST_ASSERT_NULL(alert.get_bodypart(BODY_ZONE_HEAD)?.get_wound_type(/datum/wound/pierce/bleed/critical/hv_head_shot), "An alert guard was shot through the skull")
	// An ordinary person: just the hit.
	var/mob/living/carbon/human/victim = stealth_person(block, 6, 1)
	victim.setDir(EAST)
	var/mob/living/carbon/human/fourth = stealth_person(block, 5, 2)
	fourth.forceMove(stealth_at(block, 5, 1))
	gun = d45_arm(fourth, /obj/item/gun/ballistic/automatic/pistol)
	gun.fire_gun(victim, fourth, TRUE, null)
	TEST_ASSERT(!victim.IsUnconscious(), "A person was knocked out by a stealth head shot")
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_HEAD)?.get_wound_type(/datum/wound/pierce/bleed/critical/hv_head_shot), "A person was shot through the skull")
	qdel(block)

/// A held shield stops a shot from the front, never one in the back.
/datum/unit_test/voidcrew_stealth_d45_shield

/datum/unit_test/voidcrew_stealth_d45_shield/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/holder = stealth_person(block, 4, 2)
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot)
	shield.block_chance = 200
	holder.put_in_hands(shield, forced = TRUE)
	holder.setDir(EAST)
	// From the front: blocked.
	var/mob/living/carbon/human/front = stealth_person(block, 5, 2)
	var/obj/item/gun/gun = d45_arm(front, /obj/item/gun/ballistic/automatic/pistol)
	front.zone_selected = BODY_ZONE_CHEST
	holder.setDir(EAST)
	gun.fire_gun(holder, front, TRUE, null)
	TEST_ASSERT_EQUAL(holder.getBruteLoss(), 0, "A shield didn't stop a shot from the front")
	// From behind: through.
	var/mob/living/carbon/human/back = stealth_person(block, 3, 2)
	gun = d45_arm(back, /obj/item/gun/ballistic/automatic/pistol)
	back.zone_selected = BODY_ZONE_CHEST
	holder.setDir(EAST)
	gun.fire_gun(holder, back, TRUE, null)
	TEST_ASSERT(holder.getBruteLoss() > 0, "A shield stopped a shot in the back")
	TEST_ASSERT(!holder.vc_shot_in_back, "The shot-in-the-back mark stayed on after the shot")
	qdel(block)

/// The backstab (one path for every sharp knife, the knife execution): from behind on an unaware guard it goes for the
/// throat whatever is aimed at, and the cut is tg's critical slash and neck_slice; the guard can't speak. Not from the
/// front, not a blunt blade, not through a SWAT helmet, not when held in a grab (tg's own slit). The mute goes with the
/// cut. An unaware guard is cut on the click itself, with no hold (decision 45 amended): a patrolling guard would walk out
/// of a 1.5 s hold. A helpless guard still gets the hold.
/datum/unit_test/voidcrew_stealth_d45_backstab

/datum/unit_test/voidcrew_stealth_d45_backstab/Run()
	var/datum/turf_reservation/block = stealth_block(8, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	person.put_in_active_hand(knife, forced = TRUE)
	person.set_combat_mode(TRUE)
	person.zone_selected = BODY_ZONE_CHEST
	// From the front: no backstab.
	person.forceMove(stealth_at(block, 5, 1))
	TEST_ASSERT(!knife.hv_knife_execution_possible(person, guard), "The knife backstabs from the front")
	person.forceMove(stealth_at(block, 3, 1))
	TEST_ASSERT(knife.hv_knife_execution_possible(person, guard), "The knife doesn't backstab an unaware guard from behind with the chest aimed at")
	TEST_ASSERT(knife.hv_knife_execution_instant(person, guard), "An unaware guard from behind waits for the hold")
	// The cut lands on the click, no hold.
	knife.melee_attack_chain(person, guard, list())
	TEST_ASSERT(!DOING_INTERACTION(person, "hv_knife_execution"), "The backstab on an unaware guard started a hold")
	TEST_ASSERT(guard.has_status_effect(/datum/status_effect/neck_slice), "A backstab didn't cut the throat on the click")
	var/obj/item/bodypart/head = guard.get_bodypart(BODY_ZONE_HEAD)
	var/critical_slash = FALSE
	for(var/datum/wound/cut as anything in head.wounds)
		if(istype(cut, /datum/wound/slash) && cut.severity == WOUND_SEVERITY_CRITICAL)
			critical_slash = TRUE
	TEST_ASSERT(critical_slash, "A backstab left no critical slash on the head")
	TEST_ASSERT_EQUAL(knife.hv_knife_exec_spray, 2, "A cut throat didn't spray the most blood")
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_MUTE), "A cut throat isn't mute")
	TEST_ASSERT(!guard.can_speak(), "A guard with a cut throat can speak")
	TEST_ASSERT(!knife.hv_knife_execution_possible(person, guard), "A cut throat can be cut again")
	guard.remove_status_effect(/datum/status_effect/neck_slice)
	TEST_ASSERT(!HAS_TRAIT(guard, TRAIT_MUTE), "The mute stayed after the cut")
	// Any sharp-edged knife backstabs; a blunt one doesn't.
	var/mob/living/carbon/human/npc/second = d45_bare_guard(block, 4, 3)
	var/mob/living/carbon/human/stabber = stealth_person(block, 3, 3)
	var/obj/item/knife/combat/blade = allocate(/obj/item/knife/combat)
	stabber.put_in_active_hand(blade, forced = TRUE)
	stabber.set_combat_mode(TRUE)
	stabber.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(blade.hv_knife_execution_possible(stabber, second), "A plain combat knife doesn't backstab")
	// A helpless guard taken from the front keeps the hold.
	stabber.forceMove(stealth_at(block, 5, 3))
	stabber.zone_selected = BODY_ZONE_HEAD
	second.Knockdown(30 SECONDS)
	TEST_ASSERT(blade.hv_knife_execution_possible(stabber, second), "A knife can't execute a helpless guard from the front")
	TEST_ASSERT(!blade.hv_knife_execution_instant(stabber, second), "A helpless guard from the front was cut without the hold")
	second.SetKnockdown(0)
	stabber.forceMove(stealth_at(block, 3, 3))
	stabber.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(blade.hv_knife_execution_possible(stabber, second), "Back behind it, the combat knife no longer backstabs")
	// Made to order, so the checks hold whatever tg does to the plastic knife: an edge with no force, then force with no edge.
	var/obj/item/knife/plastic/spork = allocate(/obj/item/knife/plastic)
	spork.force = 0
	spork.sharpness = SHARP_EDGED
	TEST_ASSERT(!spork.hv_knife_execution_possible(stabber, second), "A knife with no force backstabs")
	spork.force = 10
	spork.sharpness = NONE
	TEST_ASSERT(!spork.hv_knife_execution_possible(stabber, second), "A blunt knife backstabs")
	// A SWAT helmet (wound 15): tg's wound maths keeps the critical slash out; an ordinary stab to the head.
	var/mob/living/carbon/human/npc/helmeted = d45_bare_guard(block, 4, 5)
	d45_helmet(helmeted, /obj/item/clothing/head/helmet/swat)
	var/mob/living/carbon/human/third = stealth_person(block, 3, 5)
	var/obj/item/knife/combat/other_knife = allocate(/obj/item/knife/combat)
	third.put_in_active_hand(other_knife, forced = TRUE)
	third.set_combat_mode(TRUE)
	TEST_ASSERT(!other_knife.slit_gets_through(helmeted, helmeted.get_bodypart(BODY_ZONE_HEAD)), "A slit got through a SWAT helmet")
	TEST_ASSERT(other_knife.hv_finish_knife_execution(third, helmeted, list(), list()), "The stab at a helmeted guard didn't land")
	TEST_ASSERT(!helmeted.has_status_effect(/datum/status_effect/neck_slice), "A helmeted guard's throat was cut")
	TEST_ASSERT(helmeted.get_bodypart(BODY_ZONE_HEAD).brute_dam > 0, "The stab at a protected throat did nothing")
	TEST_ASSERT(other_knife.hv_knife_exec_spray < 2, "A protected throat sprayed like a cut one")
	TEST_ASSERT(helmeted.can_speak(), "A guard whose throat was protected can't speak")
	// Held in an aggressive grab: tg's own slit, not this one.
	var/mob/living/carbon/human/npc/held = d45_bare_guard(block, 6, 5)
	third.forceMove(stealth_at(block, 5, 5))
	third.start_pulling(held, supress_message = TRUE)
	third.setGrabState(GRAB_AGGRESSIVE)
	TEST_ASSERT(!other_knife.hv_knife_execution_possible(third, held), "The backstab took over tg's grab slit")
	third.stop_pulling()
	qdel(block)

/// A lookout with a cut throat makes no radio call and no shout; one with its throat whole does.
/datum/unit_test/voidcrew_stealth_d45_quiet
	var/says = 0

/datum/unit_test/voidcrew_stealth_d45_quiet/proc/on_say(datum/source)
	SIGNAL_HANDLER
	says++

/datum/unit_test/voidcrew_stealth_d45_quiet/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/obj/effect/landmark/stealth_group/marker = allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 6, 4))
	var/datum/stealth_group/group = marker.group
	var/mob/living/carbon/human/npc/cut = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout, stealth_at(block, 2, 2))
	var/mob/living/carbon/human/npc/whole = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav/lookout, stealth_at(block, 5, 2))
	var/datum/ai_controller/basic_controller/human_npc/stealth/cut_ai = cut.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/whole_ai = whole.ai_controller
	cut_ai.stealth_setup()
	whole_ai.stealth_setup()
	TEST_ASSERT(cut_ai.group == group && whole_ai.group == group, "Test fixture: the lookouts aren't in the marker's group")
	TEST_ASSERT(cut.stealth_radio_ready() && whole.stealth_radio_ready(), "Test fixture: a lookout's earpiece doesn't work")
	cut.apply_status_effect(/datum/status_effect/neck_slice)
	TEST_ASSERT(HAS_TRAIT(cut, TRAIT_MUTE), "Test fixture: no throat wound to keep the cut")
	var/turf/spot = stealth_at(block, 1, 1)
	// The cut throat.
	RegisterSignal(cut, COMSIG_MOB_SAY, PROC_REF(on_say))
	TEST_ASSERT(!cut_ai.stealth_shout(), "A guard with a cut throat shouted")
	TEST_ASSERT(!cut_ai.stealth_start_call(3, spot), "A guard with a cut throat reached for its earpiece")
	cut_ai.pending_call = list(3, spot, world.time, null)
	group.next_radio_alarm = 0
	cut_ai.stealth_deliver_call()
	TEST_ASSERT_EQUAL(group.next_radio_alarm, 0, "A guard with a cut throat made a radio call")
	TEST_ASSERT_EQUAL(says, 0, "A guard with a cut throat said something")
	UnregisterSignal(cut, COMSIG_MOB_SAY)
	// The whole throat, the same way.
	RegisterSignal(whole, COMSIG_MOB_SAY, PROC_REF(on_say))
	whole_ai.pending_call = list(3, spot, world.time, null)
	whole_ai.stealth_deliver_call()
	TEST_ASSERT(group.next_radio_alarm > 0, "Test fixture: the lookout with a whole throat made no radio call")
	TEST_ASSERT(says > 0, "Test fixture: the lookout with a whole throat said nothing")
	UnregisterSignal(whole, COMSIG_MOB_SAY)
	qdel(block)
