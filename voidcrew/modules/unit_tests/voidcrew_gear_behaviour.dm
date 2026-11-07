/// A recall that can't happen leaves Vex's insurance in the body with its claim open, and the
/// stabilizer only ever pays out once.
/datum/unit_test/voidcrew_vex_insurance_stays_unspent/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(__IMPLIED_TYPE__)
	var/obj/item/implant/vex_insurance/policy = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(policy.implant(wearer), "The insurance implant fixture failed")
	wearer.adjustOxyLoss(60)
	var/oxy_before = wearer.getOxyLoss()
	policy.on_stat_change(wearer, SOFT_CRIT, CONSCIOUS)
	TEST_ASSERT(!QDELETED(policy) && policy.imp_in == wearer, "A wearer with no ship burned the implant out")
	TEST_ASSERT(policy.stabilized, "The first claim didn't stabilize the wearer")
	TEST_ASSERT(wearer.getOxyLoss() < oxy_before, "The first claim healed nothing")
	TEST_ASSERT(!policy.triggered, "A wearer with no ship left the claim latched shut")

	var/oxy_after = wearer.getOxyLoss()
	policy.on_stat_change(wearer, HARD_CRIT, SOFT_CRIT)
	TEST_ASSERT_EQUAL(wearer.getOxyLoss(), oxy_after, "An open claim paid the stabilizer twice")

	policy.triggered = TRUE
	policy.recall_home()
	TEST_ASSERT(!QDELETED(policy) && policy.imp_in == wearer, "A recall with no destination burned the implant out")
	TEST_ASSERT(!policy.triggered, "A recall with no destination left the claim latched shut")

/// The chit transmits on its earpiece's network, even when something has bound it to another ship.
/datum/unit_test/voidcrew_listening_coin_network
	var/obj/docking_port/mobile/voidcrew/enemy_port

/datum/unit_test/voidcrew_listening_coin_network/Destroy()
	if(enemy_port)
		qdel(enemy_port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_listening_coin_network/Run()
	var/obj/item/radio/listening_coin/chit = allocate(__IMPLIED_TYPE__)
	var/obj/item/radio/headset/listening_coin_earpiece/earpiece = chit.paired_earpiece?.resolve()
	TEST_ASSERT_NOTNULL(earpiece, "The chit didn't ship with its earpiece")
	allocated += earpiece
	enemy_port = allocate(/obj/docking_port/mobile/voidcrew)
	chit.bind_comms_to_ship(enemy_port)
	TEST_ASSERT_EQUAL(chit.get_comms_net(), earpiece.get_comms_net(), "The chit left its earpiece's network")
	TEST_ASSERT(earpiece.matches_comms_net(chit.get_comms_net()), "The earpiece can't hear its own chit")

/// Printed brain implants no longer stun for 20 seconds on an EMP.
/datum/unit_test/voidcrew_brain_implant_emp_stun/Run()
	var/mob/living/carbon/human/consistent/patient = allocate(__IMPLIED_TYPE__)
	var/obj/item/organ/cyberimp/brain/anti_drop/implant = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(implant.Insert(patient), "The brain implant fixture failed")
	implant.emp_act(EMP_HEAVY)
	TEST_ASSERT(patient.IsStun(), "An EMP should still stun the wearer of a brain implant")
	TEST_ASSERT(patient.AmountStun() <= 5 SECONDS, "A heavy EMP stunned for longer than 5 seconds")

/// A mindshield costs no neural load.
/datum/unit_test/voidcrew_mindshield_neural_load/Run()
	var/mob/living/carbon/human/consistent/patient = allocate(__IMPLIED_TYPE__)
	var/obj/item/implant/mindshield/shield = allocate(__IMPLIED_TYPE__)
	var/load_before = get_chrome_load(patient)
	TEST_ASSERT(shield.implant(patient), "The mindshield fixture failed")
	TEST_ASSERT_EQUAL(get_chrome_load(patient), load_before, "A mindshield cost neural load")

/// A found deathrattle implant answers to its wearer's crew and nobody else.
/datum/unit_test/voidcrew_found_deathrattle/Run()
	var/datum/voidcrew_crew_record/crew = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/wearer = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/crewmate = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/stranger = allocate(__IMPLIED_TYPE__)
	wearer.mind_initialize()
	crewmate.mind_initialize()
	stranger.mind_initialize()
	wearer.mind.reputation_crew = crew
	crewmate.mind.reputation_crew = crew
	crew.minds |= wearer.mind
	crew.minds |= crewmate.mind

	var/obj/item/implant/deathrattle/rattle = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(rattle.implant(wearer), "The deathrattle fixture failed")
	TEST_ASSERT(!rattle.in_group, "A found implant shouldn't belong to a group")
	TEST_ASSERT(rattle.is_wearers_crewmate(crewmate), "The implant didn't recognise a crewmate")
	TEST_ASSERT(!rattle.is_wearers_crewmate(stranger), "The implant reported on someone off the crew")
	TEST_ASSERT(!rattle.is_wearers_crewmate(wearer), "The implant reported on its own wearer")

	var/datum/deathrattle_group/group = allocate(/datum/deathrattle_group, "test group")
	var/obj/item/implant/deathrattle/linked = allocate(__IMPLIED_TYPE__)
	group.register(linked)
	TEST_ASSERT(linked.in_group, "A linked implant should leave the reporting to its group")

/// Ablative insulation halves the burn an EMP does to an exosuit.
/datum/unit_test/voidcrew_ablative_insulation_emp/Run()
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(__IMPLIED_TYPE__)
	var/obj/item/mecha_parts/mecha_equipment/armor/antiemp_armor_booster/plate = allocate(__IMPLIED_TYPE__)
	plate.attach(mech)
	var/integrity_before = mech.get_integrity()
	mech.emp_act(EMP_HEAVY)
	var/lost = integrity_before - mech.get_integrity()
	TEST_ASSERT(lost > 0, "The EMP did no burn at all")
	TEST_ASSERT(lost <= MECH_EMP_DAMAGE_UPPER / 2, "Ablative insulation didn't halve the EMP burn (lost [lost])")

/// Wick only pays for a control unit with a core in it.
/datum/unit_test/voidcrew_wick_control_unit_core/Run()
	var/datum/shop_buyback/fitter/scrap_control/ledger = allocate(__IMPLIED_TYPE__)
	var/obj/item/mod/control/pre_equipped/civilian/suit = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(ledger.matches(suit), "Wick refused a whole suit")
	var/obj/item/mod/core/core = suit.core
	core.uninstall()
	core.forceMove(run_loc_floor_bottom_left)
	allocated += core
	TEST_ASSERT(!ledger.matches(suit), "Wick paid for a control unit with no core")

/// The chameleon suit's armor applies to the chest it covers.
/datum/unit_test/voidcrew_chameleon_suit_coverage/Run()
	var/obj/item/clothing/suit/chameleon/vest = /obj/item/clothing/suit/chameleon
	TEST_ASSERT(initial(vest.body_parts_covered) & CHEST, "The chameleon suit covers no chest, so its armor never applies")

/// A payload landing writes a metrics row. No database: the row stays in SSmetrics' memory.
/// Categories are written as strings: unit tests are included before voidcrew/_DEFINES/metrics.dm.
/datum/unit_test/voidcrew_ew_payload_metric
	var/was_accepting
	var/list/old_pending
	var/list/old_tallies
	var/obj/docking_port/mobile/voidcrew/port
	var/obj/structure/overmap/ship/attacker

/datum/unit_test/voidcrew_ew_payload_metric/Destroy()
	SSmetrics.accepting = was_accepting
	SSmetrics.pending = old_pending
	SSmetrics.tallies = old_tallies
	if(attacker)
		attacker.shuttle = null
	if(port)
		port.current_ship = null
		qdel(port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_ew_payload_metric/Run()
	was_accepting = SSmetrics.accepting
	old_pending = SSmetrics.pending
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = TRUE
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

	attacker = allocate(/obj/structure/overmap/ship)
	port = allocate(/obj/docking_port/mobile/voidcrew)
	port.current_ship = attacker
	attacker.shuttle = port
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/obj/item/ew_exploit/lights_out/chip = allocate(__IMPLIED_TYPE__)

	ship_metric_ew_payload(attacker, target, chip, null, "tester")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "A landed payload should write one row")
	var/list/row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["category"], "player_ship", "category column")
	TEST_ASSERT_EQUAL(row["event"], "ew_payload_run", "event column")
	TEST_ASSERT_EQUAL(row["ckey"], "tester", "ckey column")
	TEST_ASSERT_EQUAL(row["subject"], "[chip.payload_type]", "subject column")
	TEST_ASSERT_EQUAL(row["ship_id"], attacker.metric_id, "ship_id column")
