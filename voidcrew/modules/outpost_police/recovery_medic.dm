/**
 * # Outpost recovery: the medics
 *
 * Owner decision 31 (playtest 1). One medic, two for a big scene, comes up with the crew wave and treats the
 * outpost's own people who are down in crit but alive: traders, guards, officers, residents and the crews. Never a
 * player (a downed suspect is the arrest system's), never anyone a player has been in (morgue_npc_body()'s rule).
 *
 * Everything is tg medical, from the medic's own belt: an epinephrine medipen through the pen's own inject(), then
 * sutures, a bruise pack and ointment through the stacks' own try_heal() (its do_after, its limb checks, its loop
 * over the hurt limbs). Nobody's health is set and nothing is healed that the items do not heal. A patient whose
 * health is back over the crit line gets up and goes back to work by tg's own rules (the AI runs again once they
 * are conscious, human_npc_soft_crit.dm). What the kit can't fix (blood loss, a body full of oxygen damage) the
 * epinephrine holds off while it lasts; the medic waits with them, then moves on.
 *
 * The kit is the medic's locked gear: medical stacks and medipens are consumable gear (human_npc_gear.dm), so
 * they may be used up or dropped but are never loot, and go with the medic. The kit is finite: an empty belt
 * treats nobody, and nothing is ever conjured into the medic's hand.
 *
 * Unseen (recovery_offscreen.dm), the same kit is applied without the walk: treat_now() runs the same item procs
 * that try_heal() ends in, one use at a time, with the medic standing beside the patient.
 */

/// One patient is given up after this long (tried again later)
#define MEDIC_JOB_TIMEOUT (3 MINUTES)
/// An action that never came back (a runtime inside it) is let go after this long
#define MEDIC_ACTION_STUCK (1 MINUTES)
/// Walks to a patient that ended out of reach before they are given up for now
#define MEDIC_APPROACH_TRIES 3
/// A patient given up waits this long before a medic looks at them again
#define MEDIC_PATIENT_RETRY (60 SECONDS)
/// The order the stacks are tried in once the bleeding is stopped: the bruises, the burns, then sutures for what brute is left
#define MEDIC_STACK_ORDER list(/obj/item/stack/medical/bruise_pack, /obj/item/stack/medical/ointment, /obj/item/stack/medical/suture)

// The lines (AMBIENT_STRINGS_RECOVERY, every zone's section)
/// Aloud, kneeling by the first patient
#define RECOVERY_LINE_MEDIC_FOUND "medic_found"
/// Over the radio, a patient back over the line
#define RECOVERY_LINE_MEDIC_STABLE "medic_stable"
/// Over the radio, a patient who died on them
#define RECOVERY_LINE_MEDIC_LOST "medic_lost"

// =========================================================================
// THE MEDIC
// =========================================================================

/**
 * The medic's ID: the police lift doors, as every crew's (they come in by the staff lifts, never the checkpoint).
 * Locked to the body like the rest of the kit.
 */
/datum/id_trim/outpost_medic
	assignment = "Outpost Medic"
	trim_state = "trim_paramedic"
	department_color = COLOR_MEDICAL_BLUE
	subdepartment_color = COLOR_MEDICAL_BLUE
	sechud_icon_state = SECHUD_PARAMEDIC
	access = list(ACCESS_OUTPOST_POLICE)

/**
 * A paramedic off the station's own ambulance: the dark blue jacket with its reflective stripes over the navy
 * paramedic suit, the cap with the white cross, pale blue nitrile gloves and black work boots. Plainly the people
 * you want when you're on the floor, and nothing like the morgue crew's black scrubs. The EMT kit rides on a
 * medical belt: a suture, a bruise pack, ointment and two epinephrine pens, all of it consumable gear.
 */
/datum/outfit/outpost_medic
	name = "Outpost medic"
	uniform = /obj/item/clothing/under/rank/medical/paramedic
	suit = /obj/item/clothing/suit/toggle/labcoat/paramedic
	head = /obj/item/clothing/head/soft/paramedic
	gloves = /obj/item/clothing/gloves/latex/nitrile
	shoes = /obj/item/clothing/shoes/workboots/black
	ears = /obj/item/radio/headset
	belt = /obj/item/storage/belt/medical
	belt_contents = list(
		/obj/item/stack/medical/suture = 1,
		/obj/item/stack/medical/bruise_pack = 1,
		/obj/item/stack/medical/ointment = 1,
		/obj/item/reagent_containers/hypospray/medipen = 2,
	)
	id = /obj/item/card/id/advanced
	id_trim = /datum/id_trim/outpost_medic

/// Treats the outpost's people who are down but alive
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic
	name = "outpost medic"
	desc = "Outpost medical staff."
	outfit = /datum/outfit/outpost_medic
	// On the station's radio net, as the morgue crew
	stealth_radio = TRUE
	routine = list(/datum/ambient_activity/treat_patient = 1)

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	var/obj/item/card/id/card = wear_id
	if(istype(card))
		card.registered_name = real_name
		card.update_label()
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	var/section = outpost?.police?.profile?.voice_section
	if(section)
		dialogue_section = section

/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(was_alive && stat == DEAD)
		medic_recovery()?.crew_lost(src)

/// The recovery they work for: the one that sent them, or the outpost's they stand at
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/proc/medic_recovery()
	if(outpost_recovery && !QDELETED(outpost_recovery))
		return outpost_recovery
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	return outpost?.ensure_recovery()

/// Anywhere on their outpost, as the morgue crew: the hurt lie anywhere
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/leash_ok(turf/tile)
	var/obj/structure/overmap/trader_outpost/keep = outpost_recovery?.outpost
	if(!keep)
		return ..()
	tile = get_turf(tile)
	return tile && get_trader_outpost_for_turf(tile) == keep

/**
 * The next thing to use on `patient` from the kit: list(item, zone), or null when nothing they carry helps now.
 * A medipen first while the patient is in crit and has no epinephrine in them; then a suture on a bleeding limb;
 * then the first stack, in MEDIC_STACK_ORDER, that tg's own checks (try_heal_checks()) let them use on a limb.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/proc/next_treatment(mob/living/carbon/patient)
	if(!iscarbon(patient) || patient.stat == DEAD)
		return null
	if(recovery_in_crit(patient) && !patient.reagents?.has_reagent(/datum/reagent/medicine/epinephrine))
		for(var/obj/item/reagent_containers/hypospray/medipen/pen in get_all_contents_type(/obj/item/reagent_containers/hypospray/medipen))
			if(!pen.used_up && pen.reagents?.total_volume)
				return list(pen, null)
	for(var/obj/item/stack/medical/suture/suture in get_all_contents_type(/obj/item/stack/medical/suture))
		if(QDELETED(suture) || suture.amount <= 0)
			continue
		for(var/obj/item/bodypart/limb as anything in patient.bodyparts)
			if(limb.get_modified_bleed_rate() > 0 && suture.try_heal_checks(patient, src, limb.body_zone, silent = TRUE))
				return list(suture, limb.body_zone)
	for(var/stack_type in MEDIC_STACK_ORDER)
		for(var/obj/item/stack/medical/stack in get_all_contents_type(stack_type))
			if(QDELETED(stack) || stack.amount <= 0)
				continue
			for(var/obj/item/bodypart/limb as anything in patient.bodyparts)
				if(stack.try_heal_checks(patient, src, limb.body_zone, silent = TRUE))
					return list(stack, limb.body_zone)
	return null

/// Takes `item` from the belt into a free hand. FALSE if it can't (hands full, not theirs).
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/proc/take_out(obj/item/item)
	return !QDELETED(item) && human_npc_take_in_hand(src, item)

/// Puts `item` back on the belt; a spent pen is dropped where they kneel, as anyone would
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/proc/put_back(obj/item/item)
	if(QDELETED(item) || !is_holding(item))
		return
	var/obj/item/reagent_containers/hypospray/medipen/pen = item
	if(istype(pen) && pen.used_up)
		dropItemToGround(pen)
		return
	var/obj/item/storage/belt/kit = belt
	if(istype(kit) && kit.atom_storage?.attempt_insert(item, src, override = TRUE, messages = FALSE))
		return
	item.equip_to_best_slot(src)

/**
 * One treatment on `patient`, the way a person does it: the item in hand, then its own proc. A pen is inject();
 * a stack is try_heal(), which sleeps through its do_after and carries on over the hurt limbs until the stack or
 * the hurt runs out. Sleeps. TRUE if something was used.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/proc/treat(mob/living/carbon/patient)
	var/list/next = next_treatment(patient)
	if(!next)
		return FALSE
	var/obj/item/tool = next[1]
	if(!take_out(tool))
		return FALSE
	face_atom(patient)
	. = TRUE
	var/obj/item/reagent_containers/hypospray/medipen/pen = tool
	if(istype(pen))
		pen.inject(patient, src)
	else
		var/obj/item/stack/medical/stack = tool
		stack.try_heal(patient, src, next[2], FALSE, TRUE)
	if(!QDELETED(src))
		put_back(tool)

/**
 * The same kit with nobody there to watch (recovery_offscreen.dm): the pen's inject(), and for each stack the
 * heal_carbon() and use() that try_heal() ends in, one use per limb per pass, until the kit or the hurt runs out.
 * The do_afters are the only thing skipped. Never sleeps. Returns how many uses went on the patient.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/proc/treat_now(mob/living/carbon/patient)
	. = 0
	// A bound: a stack has at most a few dozen uses, and each pass uses one
	for(var/pass in 1 to 60)
		var/list/next = next_treatment(patient)
		if(!next)
			return
		var/obj/item/tool = next[1]
		var/obj/item/reagent_containers/hypospray/medipen/pen = tool
		if(istype(pen))
			if(!pen.inject(patient, src))
				return
			.++
			continue
		var/obj/item/stack/medical/stack = tool
		if(!stack.heal_carbon(patient, src, next[2]))
			return
		stack.use(1)
		.++

/**
 * Says a line of `context` over their headset, on the station's frequency: nothing with the headset off, EMPed or
 * jammed, or when they can't talk (decision 19). TRUE if they spoke.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/proc/crew_radio(context)
	if(stat != CONSCIOUS || fading || paused_at || !human_npc_can_talk(src))
		return FALSE
	var/obj/item/radio/headset = ears
	if(!istype(headset) || !headset.is_on() || is_within_radio_jammer_range(src))
		return FALSE
	var/list/lines = get_lines(context)
	if(!length(lines))
		return FALSE
	var/line = pick(lines)
	if(!istext(line))
		return FALSE
	if(headset.frequency != OUTPOST_POLICE_RADIO_FREQ)
		headset.set_frequency(OUTPOST_POLICE_RADIO_FREQ)
	say_line(";[fill_line(line)]")
	return TRUE

// =========================================================================
// HELPERS
// =========================================================================

/// Whether `patient` is down in crit but alive: soft or hard crit, or at or under the crit line
/proc/recovery_in_crit(mob/living/patient)
	if(!isliving(patient) || patient.stat == DEAD)
		return FALSE
	return patient.stat == SOFT_CRIT || patient.stat == HARD_CRIT || patient.health <= patient.crit_threshold

// =========================================================================
// THE PATIENTS (the recovery datum's)
// =========================================================================

/datum/outpost_recovery
	/// Patient weakref -> medic weakref: one medic per patient
	var/list/patient_claims = list()
	/// Patient weakref -> world.time they may be tried again
	var/list/patient_retry = list()
	/// Medics of the current wave not built yet
	var/wave_medics_left = 0
	/// The wave whose first patient was spoken of, or -1
	var/medic_first_wave = -1

/**
 * Whether a medic of this outpost may treat `patient`: an outpost person (an ambient NPC nobody ever played, so
 * never a player and never a suspect), alive and in crit, in the outpost's own box (not in a hangar or aboard a
 * ship), lying loose (not carried, pulled, buckled or shut in something).
 */
/datum/outpost_recovery/proc/patient_ok(mob/living/carbon/human/npc/ambient_npc/patient)
	if(!istype(patient) || QDELETED(patient) || !outpost || !recovery_in_crit(patient))
		return FALSE
	if(patient.mind || patient.ckey || patient.client || patient.last_mind)
		return FALSE
	if(!isturf(patient.loc) || patient.pulledby || patient.buckled)
		return FALSE
	var/turf/where = patient.loc
	if(get_trader_outpost_for_turf(where) != outpost || !outpost.police?.dispatch_in_box(where))
		return FALSE
	return !get_ship_from_atom(where)

/// The outpost's people who need a medic now
/datum/outpost_recovery/proc/patients()
	. = list()
	if(!outpost)
		return
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in GLOB.ambient_npcs)
		if(patient_ok(npc))
			. += npc

/// The patients nobody has given up on for now: the ones a wave is called for and waited on
/datum/outpost_recovery/proc/patients_due()
	. = list()
	for(var/mob/living/patient as anything in patients())
		if(patient_retry[WEAKREF(patient)] <= world.time)
			. += patient

/// The medic holding `key`'s claim, or null: a claim lapses when its medic is gone, down or on someone else
/datum/outpost_recovery/proc/patient_holder(datum/weakref/key)
	var/datum/weakref/medic_ref = patient_claims[key]
	var/mob/living/carbon/human/npc/ambient_npc/medic = medic_ref?.resolve()
	var/valid = istype(medic) && !QDELETED(medic) && medic.stat == CONSCIOUS
	if(valid)
		var/datum/ambient_activity/treat_patient/job = medic.activity
		valid = istype(job) && job.patient_ref == key
	if(!valid)
		patient_claims -= key
		return null
	return medic

/// The patient `medic` should go to next: nobody else's, not waiting out a retry, the nearest. Null if none.
/datum/outpost_recovery/proc/next_patient(mob/living/medic)
	var/turf/from = get_turf(medic)
	var/mob/living/best
	var/best_distance = INFINITY
	for(var/mob/living/patient as anything in patients())
		var/datum/weakref/key = WEAKREF(patient)
		var/mob/living/holder = patient_holder(key)
		if(holder && holder != medic)
			continue
		if(patient_retry[key] > world.time)
			continue
		var/turf/where = get_turf(patient)
		var/distance = (from && where.z == from.z) ? get_dist(from, where) : 500
		if(distance < best_distance)
			best = patient
			best_distance = distance
	return best

// =========================================================================
// THE JOB
// =========================================================================

/**
 * One patient: walk up, kneel, use the kit until they are over the crit line or the kit has nothing more for
 * them, and say so on the radio. A reaction (a fight, leaving) replaces it; finish() lets the patient go.
 */
/datum/ambient_activity/treat_patient
	name = "treating the hurt"
	/// The recovery it is for
	var/datum/outpost_recovery/recovery
	/// The patient (the claim key)
	var/datum/weakref/patient_ref
	/// A treatment is running (begin_action())
	var/acting = FALSE
	var/acting_since = 0
	/// world.time this patient is given up
	var/give_up_at = 0
	var/approach_tries = 0
	/// Whether anything from the kit went on the patient
	var/treated = FALSE

/datum/ambient_activity/treat_patient/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/medic = doer
	if(!istype(medic) || !isturf(medic.loc))
		return FALSE
	recovery = medic.medic_recovery()
	if(!recovery)
		return FALSE
	var/mob/living/patient = recovery.next_patient(medic)
	if(!patient)
		return FALSE
	patient_ref = WEAKREF(patient)
	recovery.patient_claims[patient_ref] = WEAKREF(medic)
	give_up_at = world.time + MEDIC_JOB_TIMEOUT
	go_to(get_turf(patient), 1)
	if(recovery.medic_first_wave != medic.wave)
		recovery.medic_first_wave = medic.wave
		medic.speak_context(RECOVERY_LINE_MEDIC_FOUND, patient, force = TRUE)
	return TRUE

/datum/ambient_activity/treat_patient/Destroy()
	recovery = null
	return ..()

/datum/ambient_activity/treat_patient/finish()
	release()
	return ..()

/datum/ambient_activity/treat_patient/spot_unreachable()
	. = ..()
	give_up()

/datum/ambient_activity/treat_patient/shift_times(delay)
	. = ..()
	give_up_at = ambient_shifted(give_up_at, delay)
	acting_since = ambient_shifted(acting_since, delay)

/// The patient, if they are still about
/datum/ambient_activity/treat_patient/proc/patient()
	var/mob/living/patient = patient_ref?.resolve()
	return QDELETED(patient) ? null : patient

/// Lets the patient go for whoever comes next
/datum/ambient_activity/treat_patient/proc/release()
	if(!recovery || !patient_ref)
		return
	var/datum/weakref/holder_ref = recovery.patient_claims[patient_ref]
	if(holder_ref?.resolve() == doer)
		recovery.patient_claims -= patient_ref

/// Gives the patient up for MEDIC_PATIENT_RETRY
/datum/ambient_activity/treat_patient/proc/give_up()
	if(recovery && patient_ref)
		recovery.patient_retry[patient_ref] = world.time + MEDIC_PATIENT_RETRY
	release()
	patient_ref = null
	go_to(null)

/// Runs a treatment on its own (it sleeps); act() waits for it
/datum/ambient_activity/treat_patient/proc/begin_action(mob/living/carbon/patient)
	acting = TRUE
	acting_since = world.time
	go_to(null)
	INVOKE_ASYNC(src, PROC_REF(run_action), patient)

/datum/ambient_activity/treat_patient/proc/run_action(mob/living/carbon/patient)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/medic = doer
	if(istype(medic) && medic.treat(patient))
		treated = TRUE
	if(!QDELETED(src))
		acting = FALSE

/datum/ambient_activity/treat_patient/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/medic = doer
	if(acting)
		if(world.time - acting_since < MEDIC_ACTION_STUCK)
			return AMBIENT_STEP_CONTINUE
		acting = FALSE
	if(!patient_ref || !istype(medic))
		return AMBIENT_STEP_DONE
	var/mob/living/carbon/patient = patient()
	if(!patient)
		release()
		return AMBIENT_STEP_DONE
	if(patient.stat == DEAD)
		if(treated)
			medic.crew_radio(RECOVERY_LINE_MEDIC_LOST)
		release()
		return AMBIENT_STEP_DONE
	if(!recovery_in_crit(patient))
		if(treated)
			medic.crew_radio(RECOVERY_LINE_MEDIC_STABLE)
		release()
		return AMBIENT_STEP_DONE
	if(world.time >= give_up_at || !recovery?.patient_ok(patient))
		give_up()
		return AMBIENT_STEP_DONE
	if(!medic.Adjacent(patient))
		if(++approach_tries > MEDIC_APPROACH_TRIES)
			give_up()
			return AMBIENT_STEP_DONE
		var/turf/stand = medic.free_tile_beside(patient, 1, failed_spots, TRUE)
		if(stand)
			go_to(stand)
		else
			go_to(get_turf(patient), 1)
		return AMBIENT_STEP_MOVE
	approach_tries = 0
	// Nothing more in the kit for them: they wait with the patient while the epinephrine works
	if(medic.next_treatment(patient))
		begin_action(patient)
	return AMBIENT_STEP_CONTINUE

#undef MEDIC_JOB_TIMEOUT
#undef MEDIC_ACTION_STUCK
#undef MEDIC_APPROACH_TRIES
#undef MEDIC_PATIENT_RETRY
#undef MEDIC_STACK_ORDER
