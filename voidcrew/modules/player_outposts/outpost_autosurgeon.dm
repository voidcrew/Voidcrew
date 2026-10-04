/**
 * # Auto-surgeon
 *
 * The medical lab's slab. The patient lies on it (buckled, never sealed in) and orders one procedure
 * from a fixed menu. The machine applies the result of the tg surgery it mirrors over a timeline,
 * with the same numbers, rather than running surgery steps, which need a surgeon mob.
 *
 * Safety rules, all enforced here:
 * * The menu is code only (GLOB.outpost_autosurgeon_procedures). Owners can switch entries off,
 *   never add one. Every procedure only heals: nothing on it deals damage, removes a part or revives.
 * * Only the occupant starts a run, awake, unrestrained, not held, present in their own body and
 *   with lab access. Getting up always works and stops the run.
 * * Incremental procedures keep what they already did when stopped; the rest apply only at the end.
 *   There is no random failure.
 */

/// Trait source for the analgesia the slab gives during a run
#define AUTOSURGEON_TRAIT "outpost_autosurgeon"

/// Procedure prototypes by id, in menu order. The whole menu: nothing else can be ordered.
GLOBAL_LIST_INIT(outpost_autosurgeon_procedures, init_outpost_autosurgeon_procedures())

/proc/init_outpost_autosurgeon_procedures()
	var/static/list/menu_order = list(
		/datum/autosurgeon_procedure/tend,
		/datum/autosurgeon_procedure/wounds,
		/datum/autosurgeon_procedure/shrapnel,
		/datum/autosurgeon_procedure/filter,
		/datum/autosurgeon_procedure/organs,
		/datum/autosurgeon_procedure/brain,
		/datum/autosurgeon_procedure/limb,
	)
	var/list/catalog = list()
	for(var/procedure_type in menu_order)
		var/datum/autosurgeon_procedure/procedure = new procedure_type
		catalog[procedure.id] = procedure
	return catalog

/// One run of one procedure on one patient
/datum/autosurgeon_run
	var/datum/autosurgeon_procedure/procedure
	var/datum/weakref/patient_ref
	/// The wound, organ, item or limb the current stage works on
	var/datum/weakref/target_ref
	/// Organ slot of the current organ stage
	var/target_slot
	/// Organ slots this run has already worked on
	var/list/done_slots = list()
	/// Seconds since the run started
	var/elapsed = 0
	/// Estimated seconds for the whole run, for the progress bar
	var/total = 0
	/// Seconds into the current stage, and its length. A zero length means the run is done.
	var/stage_elapsed = 0
	var/stage_length = 0
	/// Stages completed
	var/cycles = 0
	var/stage_text = ""

/datum/autosurgeon_run/Destroy()
	procedure = null
	patient_ref = null
	target_ref = null
	return ..()

// ===== PROCEDURES =====

/datum/autosurgeon_procedure
	var/id
	var/name
	var/desc

/// Why this procedure has nothing to do for the patient now, or null when it does
/datum/autosurgeon_procedure/proc/unavailable_reason(mob/living/carbon/patient)
	return "Nothing to treat."

/// Estimated seconds for a whole run on this patient
/datum/autosurgeon_procedure/proc/estimate(mob/living/carbon/patient)
	return 0

/// Picks the next stage's target. Returns its length in seconds, or 0 when the run is done.
/datum/autosurgeon_procedure/proc/next_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	return 0

/// Applies one finished stage, after checking its target is still there
/datum/autosurgeon_procedure/proc/complete_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	return

/// Applied once when a run finishes normally, never when it is stopped
/datum/autosurgeon_procedure/proc/finish(datum/autosurgeon_run/run, mob/living/carbon/patient)
	return

/// A tg surgery step prototype, read only
/datum/autosurgeon_procedure/proc/step_prototype(step_type)
	return GLOB.surgery_steps[step_type]

// --- Tend wounds: tg's basic brute and burn tend, both at once ---

/datum/autosurgeon_procedure/tend
	id = "tend"
	name = "Tend wounds"
	desc = "Heals bruises and burns."

/datum/autosurgeon_procedure/tend/proc/cycle_seconds()
	var/datum/surgery_step/heal/brute/basic/tend_step = step_prototype(/datum/surgery_step/heal/brute/basic)
	return tend_step ? tend_step.time / (1 SECONDS) : 2.5

/// Brute and burn healed by one cycle at these damage levels, by the tg basic tend formula
/datum/autosurgeon_procedure/tend/proc/cycle_heal(brute, burn)
	var/datum/surgery_step/heal/brute/basic/brute_step = step_prototype(/datum/surgery_step/heal/brute/basic)
	var/datum/surgery_step/heal/burn/basic/burn_step = step_prototype(/datum/surgery_step/heal/burn/basic)
	var/brute_heal = 0
	var/burn_heal = 0
	if(brute > 0)
		brute_heal = (brute_step ? brute_step.brutehealing : 5) + round(brute * (brute_step ? brute_step.brute_multiplier : 0.07), 0.1)
	if(burn > 0)
		burn_heal = (burn_step ? burn_step.burnhealing : 5) + round(burn * (burn_step ? burn_step.burn_multiplier : 0.07), 0.1)
	return list(brute_heal, burn_heal)

/datum/autosurgeon_procedure/tend/unavailable_reason(mob/living/carbon/patient)
	if(patient.getBruteLoss() <= 0 && patient.getFireLoss() <= 0)
		return "No bruises or burns."
	return null

/datum/autosurgeon_procedure/tend/estimate(mob/living/carbon/patient)
	var/brute = patient.getBruteLoss()
	var/burn = patient.getFireLoss()
	var/cycles = 0
	while((brute > 0 || burn > 0) && cycles < AUTOSURGEON_TEND_CYCLES)
		var/list/heal = cycle_heal(brute, burn)
		brute = max(0, brute - heal[1])
		burn = max(0, burn - heal[2])
		cycles++
	return cycles * cycle_seconds()

/datum/autosurgeon_procedure/tend/next_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	if(run.cycles >= AUTOSURGEON_TEND_CYCLES || unavailable_reason(patient))
		return 0
	run.stage_text = "Tending bruises and burns"
	return cycle_seconds()

/datum/autosurgeon_procedure/tend/complete_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	var/list/heal = cycle_heal(patient.getBruteLoss(), patient.getFireLoss())
	patient.heal_bodypart_damage(heal[1], heal[2])

// --- Treat wounds: removes each wound cleanly, worst first ---

/datum/autosurgeon_procedure/wounds
	id = "wounds"
	name = "Treat wounds"
	desc = "Sets bones, closes cuts and treats burns."

/datum/autosurgeon_procedure/wounds/proc/wound_seconds(datum/wound/wound)
	switch(wound.severity)
		if(WOUND_SEVERITY_CRITICAL)
			return 17
		if(WOUND_SEVERITY_SEVERE)
			return 8
	return 6

/datum/autosurgeon_procedure/wounds/proc/worst_wound(mob/living/carbon/patient)
	var/datum/wound/worst
	for(var/datum/wound/wound as anything in patient.all_wounds)
		if(!worst || wound.severity > worst.severity)
			worst = wound
	return worst

/datum/autosurgeon_procedure/wounds/unavailable_reason(mob/living/carbon/patient)
	return LAZYLEN(patient.all_wounds) ? null : "No wounds."

/datum/autosurgeon_procedure/wounds/estimate(mob/living/carbon/patient)
	. = 0
	for(var/datum/wound/wound as anything in patient.all_wounds)
		. += wound_seconds(wound)

/datum/autosurgeon_procedure/wounds/next_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	if(run.cycles >= 20)
		return 0
	var/datum/wound/wound = worst_wound(patient)
	if(!wound)
		return 0
	run.target_ref = WEAKREF(wound)
	run.stage_text = "Treating [wound.name][wound.limb ? " on the [wound.limb.plaintext_zone]" : ""]"
	return wound_seconds(wound)

/datum/autosurgeon_procedure/wounds/complete_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	var/datum/wound/wound = run.target_ref?.resolve()
	if(wound && (wound in patient.all_wounds))
		qdel(wound)

// --- Remove shrapnel ---

/datum/autosurgeon_procedure/shrapnel
	id = "shrapnel"
	name = "Remove shrapnel"
	desc = "Pulls out anything embedded in the patient."

/datum/autosurgeon_procedure/shrapnel/proc/embedded_items(mob/living/carbon/patient)
	var/list/items = list()
	for(var/obj/item/bodypart/part as anything in patient.bodyparts)
		items += part.embedded_objects
	return items

/datum/autosurgeon_procedure/shrapnel/unavailable_reason(mob/living/carbon/patient)
	return length(embedded_items(patient)) ? null : "Nothing embedded."

/datum/autosurgeon_procedure/shrapnel/estimate(mob/living/carbon/patient)
	return length(embedded_items(patient)) * 4

/datum/autosurgeon_procedure/shrapnel/next_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	if(run.cycles >= 30)
		return 0
	var/list/items = embedded_items(patient)
	if(!length(items))
		return 0
	var/obj/item/embedded = items[1]
	run.target_ref = WEAKREF(embedded)
	run.stage_text = "Removing [embedded.name]"
	return 4

/datum/autosurgeon_procedure/shrapnel/complete_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	var/obj/item/embedded = run.target_ref?.resolve()
	var/datum/embedding/embed = embedded?.get_embed()
	if(embed?.owner == patient)
		embed.remove_embedding()

// --- Filter blood: tg's blood filter, no whitelist ---

/datum/autosurgeon_procedure/filter
	id = "filter"
	name = "Filter blood"
	desc = "Filters every chemical out of the blood."

/datum/autosurgeon_procedure/filter/proc/cycle_seconds()
	var/datum/surgery_step/filter_blood/filter_step = step_prototype(/datum/surgery_step/filter_blood)
	return filter_step ? filter_step.time / (1 SECONDS) : 2.5

/// What one cycle removes from `volume` units of a reagent (tg blood filter)
/datum/autosurgeon_procedure/filter/proc/cycle_removal(volume)
	return clamp(round(volume * 0.22, 0.2), 0.4, 10)

/datum/autosurgeon_procedure/filter/unavailable_reason(mob/living/carbon/patient)
	return patient.reagents?.total_volume > 0 ? null : "No chemicals in the blood."

/datum/autosurgeon_procedure/filter/estimate(mob/living/carbon/patient)
	var/cycles = 0
	for(var/datum/reagent/chem as anything in patient.reagents?.reagent_list)
		var/volume = chem.volume
		var/chem_cycles = 0
		while(volume > 0 && chem_cycles < AUTOSURGEON_FILTER_CYCLES)
			volume -= cycle_removal(volume)
			chem_cycles++
		cycles = max(cycles, chem_cycles)
	return cycles * cycle_seconds()

/datum/autosurgeon_procedure/filter/next_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	if(run.cycles >= AUTOSURGEON_FILTER_CYCLES || unavailable_reason(patient))
		return 0
	run.stage_text = "Filtering blood"
	return cycle_seconds()

/datum/autosurgeon_procedure/filter/complete_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	if(!patient.reagents)
		return
	for(var/datum/reagent/chem as anything in patient.reagents.reagent_list.Copy())
		patient.reagents.remove_reagent(chem.type, cycle_removal(chem.volume))

// --- Repair organs: the four tg organ surgeries, plus eyes and ears ---

/datum/autosurgeon_procedure/organs
	id = "organs"
	name = "Repair organs"
	desc = "Repairs damaged organs, eyes and ears."

/// Seconds per organ, the tg surgeries' nominal times
/datum/autosurgeon_procedure/organs/proc/organ_seconds(slot)
	switch(slot)
		if(ORGAN_SLOT_HEART)
			return 24.8
		if(ORGAN_SLOT_LIVER)
			return 21
		if(ORGAN_SLOT_LUNGS)
			return 18.4
		if(ORGAN_SLOT_STOMACH)
			return 23.4
		if(ORGAN_SLOT_EYES)
			return 15.2
		if(ORGAN_SLOT_EARS)
			return 20.6
	return 20

/// The organ in `slot` when it needs this procedure, else null (tg's can_start thresholds)
/datum/autosurgeon_procedure/organs/proc/needs_repair(mob/living/carbon/patient, slot)
	var/obj/item/organ/organ = patient.get_organ_slot(slot)
	if(!organ)
		return null
	switch(slot)
		if(ORGAN_SLOT_HEART)
			var/obj/item/organ/heart/heart = organ
			return (istype(heart) && heart.damage >= 60 && !heart.operated) ? organ : null
		if(ORGAN_SLOT_LIVER)
			var/obj/item/organ/liver/liver = organ
			return (istype(liver) && liver.damage >= 50 && !liver.operated) ? organ : null
		if(ORGAN_SLOT_LUNGS)
			var/obj/item/organ/lungs/lungs = organ
			return (istype(lungs) && lungs.damage >= 60 && !lungs.operated) ? organ : null
		if(ORGAN_SLOT_STOMACH)
			var/obj/item/organ/stomach/stomach = organ
			return (istype(stomach) && stomach.damage >= 50 && !stomach.operated) ? organ : null
		if(ORGAN_SLOT_EYES)
			return (organ.damage > 0 || patient.has_status_effect(/datum/status_effect/temporary_blindness)) ? organ : null
		if(ORGAN_SLOT_EARS)
			return organ.damage > 0 ? organ : null
	return null

/datum/autosurgeon_procedure/organs/proc/organ_slots()
	var/static/list/slots = list(ORGAN_SLOT_HEART, ORGAN_SLOT_LIVER, ORGAN_SLOT_LUNGS, ORGAN_SLOT_STOMACH, ORGAN_SLOT_EYES, ORGAN_SLOT_EARS)
	return slots

/datum/autosurgeon_procedure/organs/unavailable_reason(mob/living/carbon/patient)
	for(var/slot in organ_slots())
		if(needs_repair(patient, slot))
			return null
	return "No organ damage the slab can repair."

/datum/autosurgeon_procedure/organs/estimate(mob/living/carbon/patient)
	. = 0
	for(var/slot in organ_slots())
		if(needs_repair(patient, slot))
			. += organ_seconds(slot)

/datum/autosurgeon_procedure/organs/next_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	for(var/slot in organ_slots())
		if(slot in run.done_slots)
			continue
		var/obj/item/organ/organ = needs_repair(patient, slot)
		if(!organ)
			continue
		run.done_slots += slot
		run.target_slot = slot
		run.target_ref = WEAKREF(organ)
		run.stage_text = "Repairing the [organ.name]"
		return organ_seconds(slot)
	return 0

/datum/autosurgeon_procedure/organs/complete_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	var/slot = run.target_slot
	var/obj/item/organ/organ = run.target_ref?.resolve()
	if(!organ || needs_repair(patient, slot) != organ)
		return
	switch(slot)
		if(ORGAN_SLOT_HEART)
			var/obj/item/organ/heart/heart = organ
			patient.setOrganLoss(ORGAN_SLOT_HEART, 60)
			heart.operated = TRUE
		if(ORGAN_SLOT_LIVER)
			var/obj/item/organ/liver/liver = organ
			patient.setOrganLoss(ORGAN_SLOT_LIVER, 10)
			liver.operated = TRUE
		if(ORGAN_SLOT_LUNGS)
			var/obj/item/organ/lungs/lungs = organ
			patient.setOrganLoss(ORGAN_SLOT_LUNGS, 60)
			lungs.operated = TRUE
		if(ORGAN_SLOT_STOMACH)
			var/obj/item/organ/stomach/stomach = organ
			patient.setOrganLoss(ORGAN_SLOT_STOMACH, 20)
			stomach.operated = TRUE
		if(ORGAN_SLOT_EYES)
			patient.remove_status_effect(/datum/status_effect/temporary_blindness)
			patient.set_eye_blur_if_lower(70 SECONDS)
			organ.set_organ_damage(0)
		if(ORGAN_SLOT_EARS)
			var/obj/item/organ/ears/ears = organ
			ears.deaf = max(ears.deaf, 20)
			organ.set_organ_damage(0)

// --- Repair brain ---

/datum/autosurgeon_procedure/brain
	id = "brain"
	name = "Repair brain"
	desc = "Repairs brain damage."

/datum/autosurgeon_procedure/brain/proc/has_curable_trauma(mob/living/carbon/patient)
	return !!patient.has_trauma_type(resilience = TRAUMA_RESILIENCE_SURGERY)

/datum/autosurgeon_procedure/brain/unavailable_reason(mob/living/carbon/patient)
	if(!patient.get_organ_slot(ORGAN_SLOT_BRAIN))
		return "No brain."
	if(patient.get_organ_loss(ORGAN_SLOT_BRAIN) <= 0 && !has_curable_trauma(patient))
		return "No brain damage."
	return null

/datum/autosurgeon_procedure/brain/estimate(mob/living/carbon/patient)
	return clamp(CEILING(patient.get_organ_loss(ORGAN_SLOT_BRAIN) / 50, 1), 1, AUTOSURGEON_BRAIN_CYCLES) * 10

/datum/autosurgeon_procedure/brain/next_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	if(run.cycles >= AUTOSURGEON_BRAIN_CYCLES || !patient.get_organ_slot(ORGAN_SLOT_BRAIN))
		return 0
	if(patient.get_organ_loss(ORGAN_SLOT_BRAIN) <= 0 && (run.cycles || !has_curable_trauma(patient)))
		return 0
	run.stage_text = "Repairing the brain"
	return 10

/datum/autosurgeon_procedure/brain/complete_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	var/damage = patient.get_organ_loss(ORGAN_SLOT_BRAIN)
	if(damage > 0)
		// Set rather than adjusted, as tg does, to clear the brain's failing flag
		patient.setOrganLoss(ORGAN_SLOT_BRAIN, max(0, damage - 50))

/datum/autosurgeon_procedure/brain/finish(datum/autosurgeon_run/run, mob/living/carbon/patient)
	patient.cure_all_traumas(TRAUMA_RESILIENCE_SURGERY)

// --- Reattach limb ---

/datum/autosurgeon_procedure/limb
	id = "limb"
	name = "Reattach limb"
	desc = "Reattaches an arm or leg."

/// Why this held bodypart cannot go on the patient, or null
/datum/autosurgeon_procedure/limb/proc/limb_denial(mob/living/carbon/patient, obj/item/bodypart/limb)
	if(!istype(limb) || limb.owner || !(limb in patient.held_items))
		return "Hold the arm or leg to reattach."
	if(!(limb.body_zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)))
		return "Only arms and legs."
	if(patient.get_bodypart(limb.body_zone))
		return "That limb is already there."
	// Chrome travels inside a severed limb and would skip the Chrome Cradle's install checks
	if(locate(/obj/item/organ) in limb)
		return "Remove the implants from [limb] first."
	if(!limb.can_attach_limb(patient))
		return "[limb] doesn't fit."
	return null

/// The first held limb that could be attached, else the first held limb, else null
/datum/autosurgeon_procedure/limb/proc/held_limb(mob/living/carbon/patient)
	var/obj/item/bodypart/fallback
	for(var/obj/item/bodypart/limb in patient.held_items)
		if(!limb_denial(patient, limb))
			return limb
		fallback ||= limb
	return fallback

/datum/autosurgeon_procedure/limb/unavailable_reason(mob/living/carbon/patient)
	var/obj/item/bodypart/limb = held_limb(patient)
	if(!limb)
		return "Hold the arm or leg to reattach."
	return limb_denial(patient, limb)

/datum/autosurgeon_procedure/limb/estimate(mob/living/carbon/patient)
	return 10

/datum/autosurgeon_procedure/limb/next_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	if(run.cycles)
		return 0
	var/obj/item/bodypart/limb = held_limb(patient)
	if(!limb || limb_denial(patient, limb))
		return 0
	run.target_ref = WEAKREF(limb)
	run.stage_text = "Attaching [limb.name]"
	return 10

/// Heals the loose limb and strips its wounds first, so attaching it never adds damage to the patient
/datum/autosurgeon_procedure/limb/complete_stage(datum/autosurgeon_run/run, mob/living/carbon/patient)
	var/obj/item/bodypart/limb = run.target_ref?.resolve()
	if(!limb || limb_denial(patient, limb))
		return
	if(!patient.temporarilyRemoveItemFromInventory(limb))
		return
	limb.heal_damage(limb.brute_dam, limb.burn_dam, updating_health = FALSE, forced = TRUE)
	for(var/datum/wound/wound as anything in LAZYCOPY(limb.wounds))
		qdel(wound)
	if(!limb.try_attach_limb(patient))
		patient.put_in_hands(limb)
		return
	if(limb.check_for_frankenstein(patient))
		limb.bodypart_flags |= BODYPART_IMPLANTED
	// Anything that came back with the limb goes as well
	for(var/datum/wound/wound as anything in LAZYCOPY(limb.wounds))
		qdel(wound)

// ===== THE SLAB =====

/obj/machinery/outpost_autosurgeon
	name = "auto-surgeon"
	desc = "An operating slab under a ring of surgical arms."
	icon = 'icons/obj/medical/surgery_table.dmi'
	icon_state = "surgery_table"
	density = FALSE
	anchored = TRUE
	can_buckle = TRUE
	buckle_lying = 90
	circuit = null
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 2
	processing_flags = NONE
	// The occupant works the controls lying down
	interaction_flags_atom = parent_type::interaction_flags_atom | INTERACT_ATOM_IGNORE_MOBILITY
	/// The running procedure, or null while idle
	var/datum/autosurgeon_run/run
	/// world.time the slab last went idle with someone on it
	var/idle_since = 0

/obj/machinery/outpost_autosurgeon/Destroy()
	stop_run("The auto-surgeon shuts down.")
	return ..()

/obj/machinery/outpost_autosurgeon/singularity_act()
	return 0

/obj/machinery/outpost_autosurgeon/singularity_pull(atom/singularity, current_size)
	return

/obj/machinery/outpost_autosurgeon/examine(mob/user)
	. = ..()
	if(run)
		. += span_notice("It is working: [run.stage_text].")
	var/datum/outpost_upgrade/service/medical_lab/lab = outpost_medical_lab_at(src)
	if(lab && !lab.is_exempt(user))
		var/seconds_left = lab.pass_seconds_left(user)
		. += span_notice((seconds_left ? "Lab pass: [DisplayTimeText(seconds_left * (1 SECONDS))] left." : "No lab pass."))

/// Whether a player is controlling this mob. Test subtypes override it: test mobs have no client.
/obj/machinery/outpost_autosurgeon/proc/has_player(mob/living/patient)
	return !!patient?.client

// ----- occupancy -----

/obj/machinery/outpost_autosurgeon/is_buckle_possible(mob/living/target, force = FALSE, check_loc = TRUE)
	if(!iscarbon(target))
		return FALSE
	return ..()

/obj/machinery/outpost_autosurgeon/post_buckle_mob(mob/living/patient)
	set_occupant(patient)
	idle_since = world.time
	playsound(src, 'sound/effects/servostep.ogg', 40, TRUE)
	ui_interact(patient)
	SStgui.update_uis(src)

/obj/machinery/outpost_autosurgeon/post_unbuckle_mob(mob/living/patient)
	stop_run("You got off the slab. The procedure stopped.")
	if(patient == occupant)
		set_occupant(null)
	SStgui.update_uis(src)

// A click on an occupied slab opens the controls; it never pulls the patient off.
/obj/machinery/outpost_autosurgeon/attack_hand(mob/living/user, list/modifiers)
	if(occupant)
		add_fingerprint(user)
		ui_interact(user)
		return TRUE
	return ..()

/obj/machinery/outpost_autosurgeon/user_unbuckle_mob(mob/living/buckled_mob, mob/user)
	if(user != buckled_mob)
		var/denial = unbuckle_denial(user)
		if(denial)
			if(user)
				balloon_alert(user, denial)
			return null
	return ..()

/**
 * Why `user` cannot take the occupant off the slab, or null. The occupant can always get up.
 * Nobody else may stop a running procedure. An idle occupant can be taken off when dead,
 * unconscious, not played, without lab access, or idle for a minute.
 */
/obj/machinery/outpost_autosurgeon/proc/unbuckle_denial(mob/user)
	var/mob/living/patient = occupant
	if(!patient || user == patient || isAdminGhostAI(user))
		return null
	if(run)
		return "procedure running!"
	if(patient.stat != CONSCIOUS || !has_player(patient))
		return null
	if(!outpost_lab_access(src, patient))
		return null
	if(world.time >= idle_since + AUTOSURGEON_IDLE_EVICT)
		return null
	return "in use!"

// ----- runs -----

/// Why `acting` cannot start a procedure now, or null
/obj/machinery/outpost_autosurgeon/proc/consent_denial(mob/living/acting)
	var/mob/living/carbon/patient = occupant
	if(!istype(patient))
		return "Nobody is on the slab."
	if(acting != patient)
		return "Patient only."
	if(patient.stat != CONSCIOUS)
		return "The patient must be awake."
	if(HAS_TRAIT(patient, TRAIT_RESTRAINED) || patient.handcuffed)
		return "The patient is restrained."
	if(patient.pulledby && patient.pulledby.grab_state >= GRAB_AGGRESSIVE)
		return "The patient is being held down."
	if(!has_player(patient) || patient.mind?.current != patient)
		return "The patient must be present."
	if(!outpost_lab_access(src, patient))
		return "No lab pass."
	if(length(patient.surgeries))
		return "Finish the open surgery first."
	if(run)
		return "A procedure is already running."
	if(!is_operational)
		return "No power."
	return null

/// Starts a procedure ordered by `acting`. Returns null when started, else a refusal. Never sleeps.
/obj/machinery/outpost_autosurgeon/proc/start_procedure(mob/living/acting, procedure_id)
	// UI params are decoded JSON: a number would index the catalog by position
	if(!istext(procedure_id))
		return "Unknown procedure."
	var/datum/autosurgeon_procedure/procedure = GLOB.outpost_autosurgeon_procedures[procedure_id]
	if(!procedure)
		return "Unknown procedure."
	var/denial = consent_denial(acting)
	if(denial)
		return denial
	var/mob/living/carbon/patient = occupant
	denial = procedure.unavailable_reason(patient)
	if(denial)
		return denial
	var/datum/autosurgeon_run/new_run = new
	new_run.procedure = procedure
	new_run.patient_ref = WEAKREF(patient)
	new_run.total = procedure.estimate(patient)
	new_run.stage_length = procedure.next_stage(new_run, patient)
	if(!new_run.stage_length)
		qdel(new_run)
		return "Nothing to treat."
	run = new_run
	ADD_TRAIT(patient, TRAIT_ANALGESIA, AUTOSURGEON_TRAIT)
	update_use_power(ACTIVE_POWER_USE)
	begin_processing()
	log_combat(patient, patient, "autosurgery: [procedure_id] started", src)
	playsound(src, 'sound/items/handling/surgery/scalpel1.ogg', 40, TRUE)
	visible_message(span_notice("[src]'s arms fold down over [patient]."))
	SStgui.update_uis(src)
	return null

/**
 * Ends the run. `completed` runs the procedure's finishing step; a stopped run keeps only what its
 * stages already did.
 */
/obj/machinery/outpost_autosurgeon/proc/stop_run(message, completed = FALSE)
	if(!run)
		return
	var/datum/autosurgeon_run/ending = run
	run = null
	end_processing()
	update_use_power(IDLE_POWER_USE)
	idle_since = world.time
	var/mob/living/carbon/patient = ending.patient_ref?.resolve()
	if(patient)
		REMOVE_TRAIT(patient, TRAIT_ANALGESIA, AUTOSURGEON_TRAIT)
		if(completed && !QDELETED(patient) && patient.stat != DEAD)
			ending.procedure.finish(ending, patient)
		log_combat(patient, patient, "autosurgery: [ending.procedure.id] [completed ? "finished" : "stopped"]", src)
		if(message)
			to_chat(patient, completed ? span_notice(message) : span_warning(message))
	playsound(src, completed ? 'sound/machines/ping.ogg' : 'sound/machines/buzz/buzz-sigh.ogg', 30, TRUE)
	qdel(ending)
	if(!QDELETED(src))
		SStgui.update_uis(src)

/obj/machinery/outpost_autosurgeon/process(seconds_per_tick)
	if(!run)
		return PROCESS_KILL
	var/mob/living/carbon/patient = run.patient_ref?.resolve()
	if(QDELETED(patient) || patient != occupant || !(patient in buckled_mobs))
		stop_run("The procedure stopped.")
		return PROCESS_KILL
	if(patient.stat == DEAD)
		stop_run("The patient died. The procedure stopped.")
		return PROCESS_KILL
	if(!is_operational)
		stop_run("The slab lost power. The procedure stopped.")
		return PROCESS_KILL
	var/datum/autosurgeon_procedure/procedure = run.procedure
	run.elapsed += seconds_per_tick
	run.stage_elapsed += seconds_per_tick
	while(run.stage_length && run.stage_elapsed >= run.stage_length)
		run.stage_elapsed -= run.stage_length
		procedure.complete_stage(run, patient)
		run.cycles++
		if(QDELETED(patient) || patient.stat == DEAD)
			stop_run("The procedure stopped.")
			return PROCESS_KILL
		run.stage_length = procedure.next_stage(run, patient)
	if(!run.stage_length)
		stop_run("[procedure.name]: done.", completed = TRUE)
		return PROCESS_KILL
	run.total = max(run.total, run.elapsed + run.stage_length - run.stage_elapsed)
	if(SPT_PROB(40, seconds_per_tick))
		playsound(src, pick('sound/items/handling/surgery/hemostat1.ogg', 'sound/items/handling/surgery/retractor1.ogg', 'sound/items/handling/surgery/retractor2.ogg'), 25, TRUE)
	SStgui.update_uis(src)

/obj/machinery/outpost_autosurgeon/on_set_is_operational(old_value)
	if(old_value && run)
		stop_run("The slab lost power. The procedure stopped.")

// ----- UI -----

/obj/machinery/outpost_autosurgeon/ui_status(mob/user, datum/ui_state/state)
	if(user == occupant)
		return user.shared_ui_interaction(src)
	return ..()

/obj/machinery/outpost_autosurgeon/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostAutosurgeon", name)
		ui.open()

/obj/machinery/outpost_autosurgeon/ui_data(mob/user)
	var/list/data = list()
	var/mob/living/carbon/patient = occupant
	data["powered"] = is_operational
	data["occupant_is_user"] = !!patient && patient == user
	data["can_unbuckle"] = !!patient && !unbuckle_denial(user)
	data["consent_denial"] = patient ? consent_denial(user) : null
	data["occupant"] = null
	var/list/offers = list()
	if(istype(patient))
		data["occupant"] = list(
			"name" = patient.name,
			"health" = patient.health,
			"maxHealth" = patient.maxHealth,
		)
		for(var/procedure_id in GLOB.outpost_autosurgeon_procedures)
			var/datum/autosurgeon_procedure/procedure = GLOB.outpost_autosurgeon_procedures[procedure_id]
			var/reason = procedure.unavailable_reason(patient)
			offers += list(list(
				"id" = procedure_id,
				"name" = procedure.name,
				"available" = !reason,
				"reason" = reason,
			))
	data["offers"] = offers
	data["run"] = run ? list(
		"id" = run.procedure.id,
		"name" = run.procedure.name,
		"elapsed" = round(run.elapsed),
		"total" = round(run.total),
		"stage" = run.stage_text,
	) : null
	return data

/obj/machinery/outpost_autosurgeon/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	// Off the ui, never a stored var
	var/mob/living/acting = ui.user
	switch(action)
		if("get_up")
			if(occupant)
				if(acting == occupant)
					unbuckle_mob(occupant)
				else
					user_unbuckle_mob(occupant, acting)
			return TRUE
		if("cancel")
			if(acting != occupant)
				balloon_alert(acting, "patient's call!")
				return TRUE
			stop_run("You stopped the procedure.")
			return TRUE
		if("start")
			var/refusal = start_procedure(acting, params["id"])
			if(refusal)
				balloon_alert(acting, "refused")
				to_chat(acting, span_warning(refusal))
			return TRUE

// ===== CONSOLE =====

/// Opens the slab's controls from beside it
/obj/machinery/computer/outpost_autosurgeon
	name = "auto-surgeon console"
	desc = "Shows the auto-surgeon's patient and procedure."
	icon_screen = "crew"
	icon_keyboard = "med_key"
	circuit = null

/obj/machinery/computer/outpost_autosurgeon/singularity_act()
	return 0

/obj/machinery/computer/outpost_autosurgeon/singularity_pull(atom/singularity, current_size)
	return

/// The slab beside this console, if any
/obj/machinery/computer/outpost_autosurgeon/proc/find_slab()
	for(var/direction in GLOB.alldirs)
		var/obj/machinery/outpost_autosurgeon/slab = locate() in get_step(src, direction)
		if(slab)
			return slab
	return null

// Opens the slab's window; the console has none of its own
/obj/machinery/computer/outpost_autosurgeon/interact(mob/user)
	var/obj/machinery/outpost_autosurgeon/slab = find_slab()
	if(!slab)
		balloon_alert(user, "no slab!")
		return TRUE
	slab.ui_interact(user)
	return TRUE

#undef AUTOSURGEON_TRAIT
