// Knife executions (voidcrew/modules/hyperviolence/overlays_exec/knife_executions.dm). Unit tests are included before
// voidcrew/_DEFINES, so these use the module's procs and plain numbers, never its HV_* defines.

/// Puts `attacker` on the tile west of `victim`'s tile, a combat knife in hand, aiming at the head.
/datum/unit_test/proc/hv_knife_exec_setup(mob/living/carbon/human/attacker, mob/living/carbon/human/victim)
	var/turf/east = get_step(attacker, EAST)
	victim.forceMove(east)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	attacker.put_in_active_hand(knife, forced = TRUE)
	attacker.set_combat_mode(TRUE)
	attacker.zone_selected = BODY_ZONE_HEAD
	attacker.setDir(EAST)
	return knife

/// The slash wound on the head at `severity` or worse, if any.
/proc/hv_knife_exec_test_slash(mob/living/carbon/victim, severity)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	for(var/datum/wound/slash/cut in head?.wounds)
		if(cut.severity >= severity)
			return cut
	return null

/// From behind on anyone; from the front only on the helpless.
/datum/unit_test/hv_knife_execution_trigger

/datum/unit_test/hv_knife_execution_trigger/Run()
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = hv_knife_exec_setup(attacker, victim)

	victim.setDir(EAST) // back to the attacker
	TEST_ASSERT(knife.hv_knife_execution_possible(attacker, victim), "A knife from behind could not start an execution")
	victim.setDir(WEST) // facing him
	TEST_ASSERT(!knife.hv_knife_execution_possible(attacker, victim), "A knife from the front started an execution on an aware, standing target")
	attacker.zone_selected = BODY_ZONE_CHEST
	victim.setDir(EAST)
	TEST_ASSERT(!knife.hv_knife_execution_possible(attacker, victim), "A chest-aimed knife started an execution")
	attacker.zone_selected = BODY_ZONE_PRECISE_MOUTH
	TEST_ASSERT(knife.hv_knife_execution_possible(attacker, victim), "A mouth-aimed knife from behind could not start an execution")
	attacker.set_combat_mode(FALSE)
	TEST_ASSERT(!knife.hv_knife_execution_possible(attacker, victim), "A knife out of combat mode started an execution")
	attacker.set_combat_mode(TRUE)
	TEST_ASSERT(!knife.hv_knife_execution_possible(attacker, attacker), "The attacker could execute himself")
	attacker.start_pulling(victim, supress_message = TRUE)
	attacker.setGrabState(GRAB_AGGRESSIVE)
	TEST_ASSERT(!knife.hv_knife_execution_possible(attacker, victim), "A knife execution took over tg's grab slit")
	attacker.stop_pulling()

	victim.setDir(WEST)
	victim.Knockdown(30 SECONDS)
	TEST_ASSERT(knife.hv_knife_execution_possible(attacker, victim), "A helpless target could not be executed from the front")

	var/obj/item/knife/plastic/spork = allocate(/obj/item/knife/plastic)
	if(!(spork.get_sharpness() & SHARP_EDGED) || spork.force <= 0)
		TEST_ASSERT(!spork.hv_knife_execution_possible(attacker, victim), "A blunt plastic knife started an execution")

/// A held wind-up from behind ends in tg's real throat slit (decision 45's maths). A player victim keeps the 1.5 s hold;
/// only an unaware stealth guard is cut on the click (voidcrew_stealth_d45_backstab).
/datum/unit_test/hv_knife_execution_kill

/datum/unit_test/hv_knife_execution_kill/Run()
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = hv_knife_exec_setup(attacker, victim)
	victim.setDir(EAST)

	TEST_ASSERT(!knife.hv_knife_execution_instant(attacker, victim), "A non-guard victim was cut without the hold")
	knife.melee_attack_chain(attacker, victim, list())
	TEST_ASSERT(DOING_INTERACTION(attacker, "hv_knife_execution"), "The knife click did not start the wind-up")
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_EQUAL(head.brute_dam, 0, "The knife click hurt the victim before the wind-up ended")
	sleep(2.5 SECONDS)
	TEST_ASSERT(!DOING_INTERACTION(attacker, "hv_knife_execution"), "The wind-up never ended")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/neck_slice), "An unarmoured victim's neck was not sliced")
	TEST_ASSERT_NOTNULL(hv_knife_exec_test_slash(victim, WOUND_SEVERITY_CRITICAL), "An unarmoured victim got no critical slash on the head")
	TEST_ASSERT(head.brute_dam > 0, "The cut did no damage to the head")
	TEST_ASSERT_EQUAL(attacker.pixel_w, 0, "The attacker was left offset after the move")
	TEST_ASSERT_EQUAL(attacker.pixel_z, 0, "The attacker was left offset after the move")

/// Turning to face the attacker breaks the wind-up: no cut, no damage.
/datum/unit_test/hv_knife_execution_break

/datum/unit_test/hv_knife_execution_break/Run()
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = hv_knife_exec_setup(attacker, victim)
	victim.setDir(EAST)

	knife.melee_attack_chain(attacker, victim, list())
	TEST_ASSERT(DOING_INTERACTION(attacker, "hv_knife_execution"), "The knife click did not start the wind-up")
	sleep(0.5 SECONDS)
	victim.setDir(WEST)
	sleep(2 SECONDS)
	TEST_ASSERT(!DOING_INTERACTION(attacker, "hv_knife_execution"), "The wind-up did not stop")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/neck_slice), "A broken wind-up still sliced the neck")
	TEST_ASSERT_NULL(hv_knife_exec_test_slash(victim, WOUND_SEVERITY_MODERATE), "A broken wind-up still cut the throat")
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_EQUAL(head.brute_dam, 0, "A broken wind-up still hurt the head")
	TEST_ASSERT_EQUAL(attacker.pixel_w, 0, "The attacker was left offset after a broken wind-up")
	TEST_ASSERT_EQUAL(victim.pixel_w, 0, "The victim was left offset after a broken wind-up")

	// Walking away breaks it too.
	victim.setDir(EAST)
	knife.melee_attack_chain(attacker, victim, list())
	TEST_ASSERT(DOING_INTERACTION(attacker, "hv_knife_execution"), "The second knife click did not start the wind-up")
	sleep(0.5 SECONDS)
	victim.forceMove(get_step(victim, EAST))
	sleep(2 SECONDS)
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/neck_slice), "Stepping away did not break the wind-up")

/// Head protection works as tg's slit maths says (decision 45): melee armour weakens the stab, wound armour (worn, or
/// physiology armour such as dermal cyberware) keeps the throat from being cut.
/datum/unit_test/hv_knife_execution_armour

/datum/unit_test/hv_knife_execution_armour/Run()
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/bare = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = hv_knife_exec_setup(attacker, bare)
	bare.setDir(EAST)
	TEST_ASSERT(knife.hv_finish_knife_execution(attacker, bare, list(), list()), "The bare execution did not land")
	var/bare_brute = bare.get_bodypart(BODY_ZONE_HEAD).brute_dam
	TEST_ASSERT(bare.has_status_effect(/datum/status_effect/neck_slice), "A bare throat was not cut")

	var/mob/living/carbon/human/consistent/helmeted = allocate(/mob/living/carbon/human/consistent)
	helmeted.equip_to_slot_or_del(allocate(/obj/item/clothing/head/helmet/swat), ITEM_SLOT_HEAD)
	bare.forceMove(run_loc_floor_top_right)
	helmeted.forceMove(get_step(attacker, EAST))
	helmeted.setDir(EAST)
	TEST_ASSERT(knife.hv_finish_knife_execution(attacker, helmeted, list(), list()), "The helmeted execution did not land")
	var/helmet_brute = helmeted.get_bodypart(BODY_ZONE_HEAD).brute_dam
	TEST_ASSERT(helmet_brute < bare_brute, "A helmet did not weaken the stab ([helmet_brute] vs [bare_brute])")
	TEST_ASSERT(!helmeted.has_status_effect(/datum/status_effect/neck_slice), "A SWAT helmet did not keep the neck from being cut")
	TEST_ASSERT_NULL(hv_knife_exec_test_slash(helmeted, WOUND_SEVERITY_CRITICAL), "A SWAT helmet did not keep the critical slash out")

	var/mob/living/carbon/human/consistent/plated = allocate(/mob/living/carbon/human/consistent)
	plated.physiology.armor = plated.physiology.armor.generate_new_with_modifiers(list(MELEE = 30, WOUND = 20))
	helmeted.forceMove(run_loc_floor_top_right)
	plated.forceMove(get_step(attacker, EAST))
	plated.setDir(EAST)
	TEST_ASSERT(knife.hv_finish_knife_execution(attacker, plated, list(), list()), "The plated execution did not land")
	var/plated_brute = plated.get_bodypart(BODY_ZONE_HEAD).brute_dam
	TEST_ASSERT(plated_brute < bare_brute, "Plating under the skin did not weaken the stab ([plated_brute] vs [bare_brute])")
	TEST_ASSERT(!plated.has_status_effect(/datum/status_effect/neck_slice), "Plating under the skin did not keep the neck from being cut")

/// Human NPCs below boss rank never execute; bosses and players do.
/datum/unit_test/hv_knife_execution_npc_rank

/datum/unit_test/hv_knife_execution_npc_rank/Run()
	var/mob/living/carbon/human/npc/npc = allocate(/mob/living/carbon/human/npc)
	QDEL_NULL(npc.ai_controller)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = hv_knife_exec_setup(npc, victim)
	victim.setDir(EAST)
	TEST_ASSERT(!npc.hv_can_execute(), "Test fixture: a regular NPC can execute")
	TEST_ASSERT(!knife.hv_knife_execution_possible(npc, victim), "A regular human NPC started a knife execution")
	knife.melee_attack_chain(npc, victim, list())
	TEST_ASSERT(!DOING_INTERACTION(npc, "hv_knife_execution"), "A regular human NPC's knife click started the wind-up")
	npc.npc_rank = 2 // HUMAN_NPC_RANK_BOSS
	TEST_ASSERT(knife.hv_knife_execution_possible(npc, victim), "A boss NPC could not start a knife execution")

/// How many stand-in arm pieces and knives of the hold from behind exist anywhere.
/proc/hv_knife_exec_test_pieces()
	. = 0
	for(var/obj/effect/abstract/hv_knife_exec_part/piece in world)
		if(!QDELETED(piece))
			.++

/// The hold from behind puts stand-in arms on both bodies and takes every one of them away again, cut or broken.
/datum/unit_test/hv_knife_execution_visuals

/datum/unit_test/hv_knife_execution_visuals/Run()
	var/mob/living/carbon/human/consistent/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/knife/combat/knife = hv_knife_exec_setup(attacker, victim)
	victim.setDir(EAST)
	var/attacker_filters = length(attacker.filters)
	var/victim_filters = length(victim.filters)
	var/attacker_overlays = length(attacker.overlays)
	var/victim_overlays = length(victim.overlays)
	var/attacker_layer = attacker.layer

	// Broken: the victim turns round.
	knife.melee_attack_chain(attacker, victim, list())
	sleep(0.5 SECONDS)
	TEST_ASSERT_NOTNULL(knife.hv_vis_exec, "The hold from behind drew nothing")
	TEST_ASSERT(hv_knife_exec_test_pieces() > 0, "The hold from behind made no stand-in arm")
	TEST_ASSERT(knife.hv_vis_hide_inhand, "The held knife was still drawn in the real hand under the stand-in one")
	TEST_ASSERT(length(victim.filters) > victim_filters || length(victim.overlays) > victim_overlays, "The victim's own arm did not come up")
	victim.setDir(WEST)
	sleep(1 SECONDS)
	TEST_ASSERT_NULL(knife.hv_vis_exec, "A broken hold's pictures were still running a second later")
	TEST_ASSERT_EQUAL(hv_knife_exec_test_pieces(), 0, "A broken hold left stand-in arm pieces behind")
	TEST_ASSERT(!knife.hv_vis_hide_inhand, "A broken hold left the held knife hidden")
	TEST_ASSERT_EQUAL(length(attacker.filters), attacker_filters, "A broken hold left a mask on the attacker")
	TEST_ASSERT_EQUAL(length(victim.filters), victim_filters, "A broken hold left a mask on the victim")
	TEST_ASSERT_EQUAL(length(attacker.overlays), attacker_overlays, "A broken hold left a cover on the attacker")
	TEST_ASSERT_EQUAL(length(victim.overlays), victim_overlays, "A broken hold left a cover on the victim")
	TEST_ASSERT_EQUAL(attacker.layer, attacker_layer, "A broken hold left the attacker on another layer")

	// Carried through: every piece is gone once the victim's hand has left his throat.
	victim.setDir(EAST)
	knife.melee_attack_chain(attacker, victim, list())
	TEST_ASSERT(DOING_INTERACTION(attacker, "hv_knife_execution"), "The second knife click did not start the wind-up")
	sleep(2.2 SECONDS)
	TEST_ASSERT(!knife.hv_vis_hide_inhand, "The held knife was still hidden after the attacker let go")
	TEST_ASSERT_EQUAL(length(attacker.filters), attacker_filters, "The attacker kept a mask after letting go")
	TEST_ASSERT_EQUAL(attacker.layer, attacker_layer, "The attacker was left on another layer after letting go")
	sleep(2.5 SECONDS)
	TEST_ASSERT_NULL(knife.hv_vis_exec, "The execution's pictures never ended")
	TEST_ASSERT_EQUAL(hv_knife_exec_test_pieces(), 0, "The execution left stand-in arm pieces behind")
	TEST_ASSERT_EQUAL(length(victim.filters), victim_filters, "The victim kept a mask")

	// Far-hand side view with the victim's near hand full: blade starts behind the attacker, rises at the chin, and
	// the victim's far arm still comes up.
	var/mob/living/carbon/human/consistent/west_victim = allocate(/mob/living/carbon/human/consistent)
	west_victim.forceMove(get_step(attacker, WEST))
	west_victim.setDir(WEST)
	attacker.setDir(WEST)
	attacker.dropItemToGround(knife, force = TRUE)
	attacker.swap_hand(2)
	attacker.put_in_active_hand(knife, forced = TRUE)
	var/obj/item/universal_scanner/held_tool = allocate(/obj/item/universal_scanner)
	west_victim.put_in_l_hand(held_tool)
	var/west_vic_filters = length(west_victim.filters)
	sleep(1.1 SECONDS) // clear the 1 s visual cooldown
	knife.melee_attack_chain(attacker, west_victim, list())
	sleep(0.1 SECONDS)
	var/datum/hv_knife_exec_vis/west_vis = knife.hv_vis_exec
	TEST_ASSERT_NOTNULL(west_vis, "The west far-hand hold drew nothing")
	TEST_ASSERT(west_vis.far_cut, "West right-hand hold was not marked far_cut")
	TEST_ASSERT(west_vis.blade.layer < attacker.layer, "Far-hand blade started over the attacker ([west_vis.blade.layer] vs [attacker.layer])")
	TEST_ASSERT(west_vis.blade_release_layer < attacker.layer, "Far-hand blade release layer is over the attacker")
	TEST_ASSERT_NOTNULL(west_vis.arms["v"], "Victim's far arm did not come up when his near hand held a tool")
	sleep(0.35 SECONDS)
	TEST_ASSERT(west_vis.blade.layer > MOB_LAYER, "Far-hand blade did not come in front of the neck at the chin")
	west_victim.setDir(EAST)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(hv_knife_exec_test_pieces(), 0, "Broken west hold left stand-in pieces behind")
	TEST_ASSERT_EQUAL(length(west_victim.filters), west_vic_filters, "Broken west hold left a mask on the victim")
