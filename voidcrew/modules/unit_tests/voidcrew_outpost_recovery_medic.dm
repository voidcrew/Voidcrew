/**
 * Outpost recovery tests after playtest 1: decisions 31 (medics), 32 (recovery with nobody there) and 33 (the gate
 * scanner and the outpost's doors come back from an emag).
 *
 * Defines are included after the tests: values are written out with a comment naming the define. Police helpers are
 * in voidcrew_outpost_police_helpers.dm, the morgue helpers (morgue_dead_npc(), morgue_floor(), morgue_beside()) in
 * voidcrew_outpost_recovery_morgue.dm. Each test calls the procs with the mobs already in place; none waits for a walk.
 */

/// An outpost person at `where`, beaten into crit by real damage (no cash on them)
/datum/unit_test/proc/medic_hurt_npc(turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/patient = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, where)
	patient.death_cash_low = 0
	patient.death_cash_high = 0
	patient.apply_damage(70, BRUTE, BODY_ZONE_CHEST)
	patient.apply_damage(50, BRUTE, BODY_ZONE_HEAD)
	return patient

/// A medic stabilises a critted outpost person with the real kit on their belt, and never touches a player
/datum/unit_test/voidcrew_outpost_recovery_medic_stabilise

/datum/unit_test/voidcrew_outpost_recovery_medic_stabilise/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	var/turf/patient_turf = morgue_floor(outpost)
	TEST_ASSERT_NOTNULL(patient_turf, "No concourse floor for the patient")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/patient = medic_hurt_npc(patient_turf)
	TEST_ASSERT(patient.stat != DEAD, "The beating killed the patient outright")
	TEST_ASSERT(recovery_in_crit(patient), "120 brute did not put the patient in crit (health [patient.health])")
	TEST_ASSERT(recovery.patient_ok(patient), "An outpost person in crit is not a patient")
	TEST_ASSERT((patient in recovery.patients_due()), "The patient is not waiting for a medic")

	var/turf/stand = morgue_beside(patient_turf)
	TEST_ASSERT_NOTNULL(stand, "No floor beside the patient")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/medic = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic, stand)
	medic.outpost_recovery = recovery
	TEST_ASSERT_EQUAL(recovery.next_patient(medic), patient, "The medic was not given the patient")

	// The kit is real, on the belt, and never loot
	var/obj/item/stack/medical/bruise_pack/pack = locate() in medic.belt?.contents
	var/obj/item/reagent_containers/hypospray/medipen/pen = locate() in medic.belt?.contents
	TEST_ASSERT_NOTNULL(pack, "The medic has no bruise pack on their belt")
	TEST_ASSERT_NOTNULL(pen, "The medic has no medipen on their belt")
	TEST_ASSERT(human_npc_gear_consumable(pack), "The medic's bruise pack is not consumable gear")
	TEST_ASSERT(human_npc_gear_consumable(pen), "The medic's medipen is not consumable gear")
	var/pack_before = pack.amount

	// The first thing is the pen, then the stacks
	var/list/first = medic.next_treatment(patient)
	TEST_ASSERT(istype(first?[1], /obj/item/reagent_containers/hypospray/medipen), "The medic did not reach for a medipen first")
	TEST_ASSERT(medic.treat_now(patient) > 0, "The medic used nothing on the patient")
	TEST_ASSERT(patient.reagents.has_reagent(/datum/reagent/medicine/epinephrine), "No epinephrine went into the patient")
	TEST_ASSERT(QDELETED(pack) || pack.amount < pack_before, "The bruise pack was not used")
	TEST_ASSERT(patient.stat != DEAD, "The patient died under treatment")
	TEST_ASSERT(!recovery_in_crit(patient), "The patient is still in crit after the kit (health [patient.health])")
	TEST_ASSERT(!(patient in recovery.patients()), "A patient over the crit line is still a patient")

	// Never a player, never a body a player has been in
	var/mob/living/carbon/human/npc/ambient_npc/outpost/played = medic_hurt_npc(stand)
	played.mind_initialize()
	TEST_ASSERT(recovery_in_crit(played), "The second patient is not in crit")
	TEST_ASSERT(!recovery.patient_ok(played), "A body with a mind was taken as a patient")
	var/mob/living/carbon/human/player = allocate(/mob/living/carbon/human/consistent, stand)
	player.mind_initialize()
	player.apply_damage(120, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(!recovery.patient_ok(player), "A player in crit was taken as a patient")

/// A medic with nothing left in the kit and no epinephrine working in an oxy-crit patient releases them instead of standing over them
/datum/unit_test/voidcrew_outpost_recovery_medic_untreatable_yields

/datum/unit_test/voidcrew_outpost_recovery_medic_untreatable_yields/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	var/turf/patient_turf = morgue_floor(outpost)
	TEST_ASSERT_NOTNULL(patient_turf, "No concourse floor for the patient")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/patient = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, patient_turf)
	patient.death_cash_low = 0
	patient.death_cash_high = 0
	patient.apply_damage(130, OXY)
	TEST_ASSERT(recovery_in_crit(patient), "130 oxy did not put the patient in crit")

	var/turf/stand = morgue_beside(patient_turf)
	TEST_ASSERT_NOTNULL(stand, "No floor beside the patient")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/medic = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic, stand)
	medic.outpost_recovery = recovery
	// Pens spent: nothing in the kit treats pure oxy damage
	for(var/obj/item/reagent_containers/hypospray/medipen/pen in medic.get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen))
		qdel(pen)
	TEST_ASSERT_NULL(medic.next_treatment(patient), "The medic found a treatment for pure oxy damage with no pens left")
	var/datum/ambient_activity/treat_patient/job = medic.start_activity(new /datum/ambient_activity/treat_patient(medic))
	TEST_ASSERT_NOTNULL(job, "The medic could not start on the patient")
	TEST_ASSERT_EQUAL(job.act(1), 2, "A medic with nothing left in the kit for a crit patient froze instead of moving on") // AMBIENT_STEP_DONE
	TEST_ASSERT(recovery.patient_retry[WEAKREF(patient)] > world.time, "Giving up on an untreatable patient set no retry timer")
	TEST_ASSERT_NULL(recovery.patient_holder(WEAKREF(patient)), "Giving up on an untreatable patient kept the claim")
	medic.end_activity()

/// With nobody at the outpost the recovery finishes at once: NPC bodies gone, a player's body in a tray, mess washed
/datum/unit_test/voidcrew_outpost_recovery_offscreen

/datum/unit_test/voidcrew_outpost_recovery_offscreen/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	var/turf/npc_turf = morgue_floor(outpost)
	var/turf/player_turf = morgue_floor(outpost, list(npc_turf))
	TEST_ASSERT_NOTNULL(player_turf, "No concourse floor for the bodies")

	var/mob/living/npc_body = morgue_dead_npc(npc_turf)
	recovery.npc_dead += WEAKREF(npc_body)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent, player_turf)
	body.mind_initialize()
	body.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(body), ITEM_SLOT_ICLOTHING)
	body.equip_to_slot_or_del(new /obj/item/pen(body), ITEM_SLOT_LPOCKET)
	var/list/carried = body.get_all_contents_type(/obj/item)
	body.death()
	recovery.player_dead += WEAKREF(body)

	// A tray for the player's body, as the morgue room has
	var/turf/corner = run_loc_floor_bottom_left
	var/obj/structure/bodycontainer/morgue/tray = allocate(/obj/structure/bodycontainer/morgue, locate(corner.x + 1, corner.y + 1, corner.z))
	tray.setDir(EAST)
	recovery.morgue_trays = list(tray)

	// Blood where the janitors would work: by a patrol stop, or anywhere in the box on a map without stops
	var/list/stops = recovery.work_stops()
	var/turf/blood_turf = length(stops) ? stops[1] : npc_turf
	var/obj/effect/decal/cleanable/blood/blood = new(blood_turf)
	TEST_ASSERT(recovery_is_mess(blood), "Fresh blood is not mess")

	recovery.set_state(2) // OUTPOST_RECOVERY_CLEANUP
	TEST_ASSERT_EQUAL(recovery.unseen_wait, 10 MINUTES, "The recovery does not wait 10 minutes with nobody there") // RECOVERY_UNSEEN_WAIT, owner decision 40
	TEST_ASSERT(!recovery.player_at_outpost(), "The test world has a player at the outpost")
	TEST_ASSERT(!recovery.unseen_ready(), "The recovery finished without waiting out the wait")
	TEST_ASSERT(recovery.unseen_since, "Nobody being there did not start the wait")
	// Most of the wait gone: still nothing
	recovery.unseen_since = world.time - 9 MINUTES
	TEST_ASSERT(!recovery.unseen_ready(), "The recovery finished a minute before its wait was up")
	// A shortened wait, run out: ready, and the tick does it all at once
	recovery.unseen_wait = 1 SECONDS
	recovery.unseen_since = world.time - 2 SECONDS
	TEST_ASSERT(recovery.unseen_ready(), "The recovery did not finish once nobody had been there for its wait")
	// A shut port holds it (review SF3), and the lost-wave ladder is not wiped by the unseen finish
	recovery.port_shut_until = world.time + 1 MINUTES
	TEST_ASSERT(!recovery.unseen_ready(), "The recovery finished unseen while the port was shut")
	recovery.port_shut_until = 0
	recovery.waves_lost = 2

	recovery.tick()
	recovery.unseen_wait = initial(recovery.unseen_wait)
	TEST_ASSERT_EQUAL(recovery.waves_lost, 2, "Leaving the outpost wiped the lost-wave ladder")
	TEST_ASSERT_EQUAL(recovery.state, 0, "The outpost is not back to normal") // OUTPOST_RECOVERY_NORMAL
	TEST_ASSERT(QDELETED(npc_body), "The NPC body is still there")
	TEST_ASSERT(QDELETED(blood), "The blood was not washed")
	TEST_ASSERT(!QDELETED(body), "A player's body was deleted")
	var/obj/structure/closet/body_bag/outpost_morgue/bag = body.loc
	TEST_ASSERT(istype(bag), "The player's body is in [body.loc], not a crew body bag")
	TEST_ASSERT_EQUAL(bag.loc, tray, "The player's body is not in the morgue tray")
	TEST_ASSERT(morgue_body_done(body), "The player's body is not where it belongs")
	var/list/now_carried = body.get_all_contents()
	for(var/obj/item/item as anything in carried)
		TEST_ASSERT(!QDELETED(item) && (item in now_carried), "[item] was taken off the player's body")

/// An emagged gate scanner and an emagged outpost door come back by themselves, with a spark
/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_repair

/datum/unit_test/voidcrew_outpost_recovery_robbery/gate_repair/Run()
	if(!gate_fixture())
		return
	quiet_witnesses(checkpoint.sensor)
	TEST_ASSERT(checkpoint.sensor.emag_act(person, emag), "An emag on the wall scanner did nothing")
	TEST_ASSERT(checkpoint.is_disabled(), "The gate is not down after the emag")
	// The repair is on a timer of its own, due when the 3 minutes are up
	TEST_ASSERT(checkpoint.emag_timer, "Nothing is set to bring the scanner back")
	var/left = timeleft(checkpoint.emag_timer)
	TEST_ASSERT(left > 1700 && left <= 1800, "The scanner comes back in [left] ds, not 3 minutes") // OUTPOST_CHECKPOINT_EMAG_TIME
	// The time is up
	checkpoint.disabled_until = world.time
	checkpoint.end_disable()
	TEST_ASSERT(!checkpoint.is_disabled(), "The gate is still down after its time")
	TEST_ASSERT_EQUAL(checkpoint.sensor.look, "idle", "The scanner's light did not come back")
	TEST_ASSERT(checkpoint.sensor.light_on, "The scanner's light is off")
	TEST_ASSERT_NULL(checkpoint.emag_timer, "The scanner's repair timer was left behind")

	// A plain outpost door: tg's emag leaves it open, bolted and dark; it mends itself
	var/turf/door_turf = morgue_floor(outpost)
	TEST_ASSERT_NOTNULL(door_turf, "No concourse floor for the door")
	var/obj/machinery/door/airlock/outpost/door = allocate(/obj/machinery/door/airlock/outpost, door_turf)
	door.set_machine_stat(NONE)
	TEST_ASSERT(door.emag_act(person, emag), "An emag on an outpost door did nothing")
	sleep(1.5 SECONDS) // finish_emag_act() runs 0.6 s after
	TEST_ASSERT(door.obj_flags & EMAGGED, "The outpost door was not emagged")
	TEST_ASSERT(door.locked, "The emagged door is not bolted")
	door.mend_emag()
	TEST_ASSERT(!(door.obj_flags & EMAGGED), "The outpost door is still emagged")
	TEST_ASSERT(!door.locked, "The mended door is still bolted")
	TEST_ASSERT(door.lights, "The mended door's lights are off")
	sleep(2 SECONDS)
	TEST_ASSERT(door.density, "The mended door did not shut")
