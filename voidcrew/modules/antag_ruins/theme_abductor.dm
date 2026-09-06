/** Survey protocols: live containment, standard surgery, and measured tissue physiology. */

// ===== PATRON =====

/mob/living/basic/vestige_patron/abductor
	name = "the Curator"
	desc = "A grey figure in a laboratory smock, seated at its experiment table with the instruments laid out in perfect parallel. The chair beside it has been empty for a long time. The specimen cell behind it was opened from the inside."
	gender = NEUTER
	outfit_path = /datum/outfit/abductor/scientist
	appearance_tint = "#a9bdb4"
	trial_types = list(
		/datum/vestige_trial/acquisition,
		/datum/vestige_trial/vivisection,
		/datum/vestige_trial/field_study,
	)
	boon_types = list(
		/datum/vestige_boon/item/alien_baton,
		/datum/vestige_boon/item/alien_baton/perfected,
		/datum/vestige_boon/spell/anchor_tag,
		/datum/vestige_boon/spell/anchor_tag/paired,
		/datum/vestige_boon/spell/silence_field,
		/datum/vestige_boon/gland_graft,
	)
	idle_lines = list(
		"Log, supplemental: a subject has approached the bench unprompted. Curiosity remains the most effective bait in the catalogue. We have never needed a second.",
		"Specimen cell three stands open. It was opened from the inside. The occupant's file remains active, pending relocation of the occupant.",
		"My colleague stepped out mid-procedure, some while ago. The incision is still clamped. We do not close another researcher's work. It would be rude.",
		"The subject is reminded that the restraint field is currently decorative. This was not always so. Iteration is the heart of science.",
		"Subject displays initiative. Noted.",
		"Two researchers were assigned to this survey. One remains at the bench. The arithmetic of the remainder is under review.",
		"Do not touch the tray. The instruments are sterile, and they remember being used.",
	)
	accept_line = "Consent recorded. The subject is enrolled. Deviations from protocol will be observed with interest."
	busy_line = "The subject carries another researcher's open file. Parallel studies contaminate one another. Close one."
	fulfilled_line = "That protocol is closed. Re-running a closed study proves nothing but nostalgia."
	renounce_line = "Withdrawal recorded. The subject joins the control group. The control group has never produced anything. That is what it is for."
	claim_line = "Compensation is outstanding on the subject's file. Collect it. An unbalanced ledger invites review."
	exhausted_line = "Inventory is exhausted. The subject has been (the log searches for the clinical term) thorough."
	remember_line = "Subject expired; subject resumed. Noted without comment. The file was never closed. We do not close files over technicalities."

// These protocols use supplied, attempt-bound subjects; helpers remain optional.
#define VESTIGE_FILTER_SLOT "vestige_filter"

// ===== PROTOCOL: ACQUISITION =====

/datum/vestige_trial/acquisition
	name = "Protocol: Acquisition"
	desc = "Unfold the observation lens in an open area to release a nervous survey specimen. It flees your approach and shakes off pulling. Herd it at least four tiles from its release point into a small enclosure, close every exit, then scan it from outside with the lens. Four folding barriers are supplied; existing walls can help. The specimen must remain alive, conscious, and on the floor. No timed reading is required."
	var/mob/living/basic/vestige_survey_specimen/specimen
	var/obj/effect/vestige_trial_marker/release_turf

/datum/vestige_trial/acquisition/on_accepted(mob/living/user)
	var/obj/item/vestige_observation_lens/lens = new(get_turf(user))
	lens.trial_ref = WEAKREF(src)
	hand_over(user, lens)
	for(var/index in 1 to 4)
		var/obj/item/vestige_field_panel/panel = new(get_turf(user))
		panel.trial_ref = WEAKREF(src)
		hand_over(user, panel)

/datum/vestige_trial/acquisition/get_progress_text()
	if(QDELETED(specimen))
		return "Use the lens in an open area to release the specimen. Build a small enclosure, herd it away from its release point, and scan from outside."
	return "The specimen is [get_dist(specimen, release_turf)] tiles from release. Scan from two to four tiles away once every exit from its enclosure is closed."

/datum/vestige_trial/acquisition/proc/release(mob/living/user)
	if(owner?.current != user || owner.active_vestige_trial != src || !QDELETED(specimen))
		return FALSE
	// Release only into connected, open floor. An already closed cage cannot be a starting point.
	var/list/frontier = list(get_turf(user))
	var/list/visited = frontier.Copy()
	for(var/index = 1; index <= length(frontier); index++)
		var/turf/current = frontier[index]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(next in visited)
				continue
			visited += next
			if(!isfloorturf(next) || next.is_blocked_turf(exclude_mobs = TRUE) || get_dist(user, next) > 5)
				continue
			frontier += next
	var/list/candidates = list()
	for(var/turf/candidate as anything in frontier)
		if(get_dist(user, candidate) < 4)
			continue
		var/exits = 0
		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(candidate, direction)
			if(isfloorturf(neighbor) && !neighbor.is_blocked_turf(exclude_mobs = TRUE))
				exits++
		if(exits >= 3)
			candidates += candidate
	if(!length(candidates))
		to_chat(user, span_warning("The release needs connected open floor at least four tiles from you, with three clear exits."))
		return FALSE
	QDEL_NULL(release_turf)
	release_turf = mark_turf(pick(candidates))
	specimen = new(get_turf(release_turf))
	specimen.trial_ref = WEAKREF(src)
	register_loan(specimen)
	to_chat(user, span_notice("The lens releases a survey specimen. It flees nearby movement. Position yourself behind it to drive it toward your enclosure."))
	return TRUE

/// BYOND diagonal movement is two cardinal steps. Flooding legal cardinal transitions
/// therefore includes every diagonal escape, including directional window borders.
/// Loose objects and people do not count as reliable containment walls.
/datum/vestige_trial/acquisition/proc/connected_step(turf/from, turf/destination)
	// Open asteroid, space and other passable terrain are exits, not cage walls.
	if(!destination || !destination.CanPass(specimen, get_dir(destination, from)))
		return FALSE
	var/direction = get_dir(from, destination)
	for(var/obj/blocker in from)
		if(blocker.anchored && (blocker.flags_1 & ON_BORDER_1) && !blocker.CanPass(specimen, direction))
			return FALSE
	for(var/obj/blocker in destination)
		if(blocker.anchored && !blocker.CanPass(specimen, REVERSE_DIR(direction)))
			return FALSE
	return TRUE

/datum/vestige_trial/acquisition/proc/is_contained(mob/living/user)
	if(QDELETED(specimen) || specimen.mind || specimen.client || specimen.stat != CONSCIOUS || specimen.health < specimen.maxHealth / 2 || specimen.buckled || !isturf(specimen.loc))
		return FALSE
	if(!release_turf || get_dist(specimen, release_turf) < 4 || get_dist(user, specimen) < 2 || get_dist(user, specimen) > 4 || !(specimen in view(4, user)))
		return FALSE
	var/list/reached = list(get_turf(specimen))
	for(var/index = 1; index <= length(reached); index++)
		if(length(reached) > 9)
			return FALSE
		var/turf/current = reached[index]
		if(current == get_turf(user))
			return FALSE
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!(next in reached) && connected_step(current, next))
				reached += next
	return TRUE

/obj/item/vestige_observation_lens
	name = "folding observation lens"
	desc = "Use in hand to release the loan specimen. Use on it from two to four tiles away to certify a closed enclosure of at most nine floor tiles. Relocate it at least four tiles from release first. Alt-click a deployed barrier to fold it."
	icon = 'icons/obj/devices/scanner.dmi'
	icon_state = "health"
	inhand_icon_state = "healthanalyzer"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	var/datum/weakref/trial_ref

/obj/item/vestige_observation_lens/attack_self(mob/living/user)
	var/datum/vestige_trial/acquisition/trial = trial_ref?.resolve()
	if(trial && user.mind?.active_vestige_trial == trial)
		trial.release(user)

/obj/item/vestige_observation_lens/ranged_interact_with_atom(atom/target, mob/living/user, list/modifiers)
	var/datum/vestige_trial/acquisition/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || target != trial.specimen)
		return NONE
	if(!trial.is_contained(user))
		to_chat(user, span_warning("Containment rejected. Relocate the healthy, conscious specimen, close every exit, and stand outside its small enclosure within clear sight."))
		return ITEM_INTERACT_BLOCKING
	to_chat(user, span_notice("The lens certifies live containment and recalls the specimen."))
	trial.complete()
	return ITEM_INTERACT_SUCCESS

/obj/item/vestige_field_panel
	name = "folding survey barrier"
	desc = "Use on an adjacent empty floor to erect a barrier. Alt-click the barrier to fold it. Air passes freely; the survey specimen does not."
	icon = 'icons/obj/structures.dmi'
	icon_state = "rack_parts"
	w_class = WEIGHT_CLASS_SMALL
	var/datum/weakref/trial_ref

/obj/item/vestige_field_panel/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	var/datum/vestige_trial/acquisition/trial = trial_ref?.resolve()
	var/turf/floor = target
	if(!trial || user.mind?.active_vestige_trial != trial || !isfloorturf(floor) || floor.is_blocked_turf() || floor == get_turf(user))
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/vestige_field_barrier/barrier = new(target)
	barrier.trial_ref = trial_ref
	barrier.folded_panel = src
	user.temporarilyRemoveItemFromInventory(src, force = TRUE)
	forceMove(barrier)
	trial.register_loan(barrier)
	return ITEM_INTERACT_SUCCESS

/obj/structure/vestige_field_barrier
	name = "survey barrier"
	desc = "An anchored field frame. Alt-click to fold it."
	icon = 'icons/effects/effects.dmi'
	icon_state = "shield2"
	color = "#8FCAC4"
	density = TRUE
	anchored = TRUE
	max_integrity = 100
	var/datum/weakref/trial_ref
	var/obj/item/vestige_field_panel/folded_panel

/obj/structure/vestige_field_barrier/click_alt(mob/living/user)
	var/datum/vestige_trial/acquisition/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || !user.can_perform_action(src, NEED_DEXTERITY) || !folded_panel)
		return CLICK_ACTION_BLOCKING
	folded_panel.forceMove(get_turf(src))
	user.put_in_hands(folded_panel)
	folded_panel = null
	qdel(src)
	return CLICK_ACTION_SUCCESS

/mob/living/basic/vestige_survey_specimen
	name = "nervous survey specimen"
	desc = "A tagged, unfamiliar fish. It flees nearby researchers and slips out of their grasp. Observe it without injuring it."
	icon = 'icons/mob/simple/carp.dmi'
	icon_state = "base"
	icon_living = "base"
	icon_dead = "base_dead"
	health = 60
	maxHealth = 60
	mob_biotypes = MOB_ORGANIC | MOB_BEAST
	ai_controller = null
	sentience_type = NONE
	habitable_atmos = null
	minimum_survivable_temperature = 0
	maximum_survivable_temperature = 1500
	melee_damage_lower = 0
	melee_damage_upper = 0
	obj_damage = 0
	var/datum/weakref/trial_ref
	var/next_move_at = 0

/mob/living/basic/vestige_survey_specimen/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSfastprocess, src)

/mob/living/basic/vestige_survey_specimen/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	return ..()

/mob/living/basic/vestige_survey_specimen/process(seconds_per_tick)
	var/datum/vestige_trial/acquisition/trial = trial_ref?.resolve()
	var/mob/living/researcher = trial?.owner?.current
	if(!trial || trial.owner.active_vestige_trial != trial || !researcher || stat != CONSCIOUS || !isturf(loc) || buckled || world.time < next_move_at)
		return
	next_move_at = world.time + 0.7 SECONDS
	pulledby?.stop_pulling()
	if(get_dist(src, researcher) <= 4 && (researcher in view(4, src)))
		var/list/options = shuffle(GLOB.cardinals)
		var/turf/best
		var/best_distance = get_dist(src, researcher)
		for(var/direction in options)
			var/turf/candidate = get_step(src, direction)
			if(trial.connected_step(get_turf(src), candidate) && get_dist(candidate, researcher) >= best_distance)
				best = candidate
				best_distance = get_dist(candidate, researcher)
		if(best)
			step_towards(src, best)
	else if(prob(30))
		var/direction = pick(GLOB.cardinals)
		if(trial.connected_step(get_turf(src), get_step(src, direction)))
			step(src, direction)

// ===== PROTOCOL: GRAFT =====

/datum/vestige_trial/vivisection
	name = "Protocol: Graft"
	desc = "Deploy the supplied human specimen and operating table with the graft dossier. Diagnose its failed waste filter before choosing a replacement. Perform ordinary chest Organ Manipulation with the supplied drapes and complete surgical tools: remove the failed filter, transplant the compatible gland, and close with cautery. A correct filter clears the patient's real toxin burden. Certify the living, recovered patient with the dossier. The dossier does not perform surgery for you."
	var/mob/living/carbon/human/vestige_graft_patient/patient
	var/obj/structure/table/optable/vestige_graft_table/operating_table
	var/surgical_closure = FALSE

/datum/vestige_trial/vivisection/on_accepted(mob/living/user)
	var/obj/item/vestige_graft_kit/dossier = new(get_turf(user))
	dossier.trial_ref = WEAKREF(src)
	hand_over(user, dossier)
	var/obj/item/storage/box/surgical_tools = new(get_turf(user))
	surgical_tools.name = "survey surgery case"
	for(var/tool_path in list(/obj/item/surgical_drapes, /obj/item/scalpel, /obj/item/retractor, /obj/item/circular_saw, /obj/item/hemostat, /obj/item/cautery, /obj/item/healthanalyzer))
		new tool_path(surgical_tools)
	hand_over(user, surgical_tools)
	for(var/filter_kind in list("chloride", "sulfide", "ammonium"))
		var/obj/item/organ/vestige_filter/filter = new(get_turf(user))
		filter.configure(filter_kind, src)
		hand_over(user, filter)

/datum/vestige_trial/vivisection/get_progress_text()
	if(QDELETED(patient))
		return "Use the dossier in hand on clear pressurized floor to deploy the surgical specimen and table."
	return "Patient waste: [patient.waste_class]. Toxin burden: [round(patient.getToxLoss(), 0.1)]. [surgical_closure ? "Chest closed." : "An ordinary Organ Manipulation operation must be finished."]"

/datum/vestige_trial/vivisection/proc/deploy(mob/living/user)
	if(owner?.current != user || owner.active_vestige_trial != src || !QDELETED(patient))
		return FALSE
	var/turf/location = get_step(user, user.dir)
	if(!isfloorturf(location) || location.is_blocked_turf() || location.return_air()?.return_pressure() < 80)
		to_chat(user, span_warning("Face a clear, pressurized floor tile for the operating table."))
		return FALSE
	operating_table = new(location)
	register_loan(operating_table)
	patient = new(location)
	patient.trial_ref = WEAKREF(src)
	patient.waste_class = pick("chloride", "sulfide", "ammonium")
	var/obj/item/organ/vestige_filter/failed = new
	failed.configure(patient.waste_class, src)
	failed.functional = FALSE
	failed.name = "failed survey filter"
	failed.Insert(patient)
	register_loan(patient)
	operating_table.buckle_mob(patient, force = TRUE, check_loc = FALSE)
	patient.SetSleeping(1 HOURS)
	patient.setToxLoss(25)
	RegisterSignal(patient, COMSIG_MOB_SURGERY_STARTED, PROC_REF(on_surgery_started))
	to_chat(user, span_notice("The sedated specimen is ready. Examine it or use the dossier to diagnose the waste burden before opening its chest."))
	return TRUE

/datum/vestige_trial/vivisection/proc/on_surgery_started(mob/living/source, datum/surgery/operation, location, obj/item/bodypart/bodypart)
	SIGNAL_HANDLER
	if(istype(operation, /datum/surgery/organ_manipulation) && location == BODY_ZONE_CHEST)
		surgical_closure = FALSE
		RegisterSignal(operation, COMSIG_QDELETING, PROC_REF(on_surgery_deleted))

/datum/vestige_trial/vivisection/proc/on_surgery_deleted(datum/surgery/operation)
	SIGNAL_HANDLER
	// Surgery Destroy also fires on cancellation. Only advancing beyond final
	// cautery proves the ordinary operation actually completed.
	if(operation.target == patient && operation.status > length(operation.steps))
		surgical_closure = TRUE

/datum/vestige_trial/vivisection/proc/can_discharge()
	if(QDELETED(patient) || patient.mind || patient.client || patient.stat == DEAD || patient.getToxLoss() > 5 || patient.health < 75 || length(patient.surgeries) || !surgical_closure)
		return FALSE
	var/obj/item/organ/vestige_filter/filter = patient.get_organ_slot(VESTIGE_FILTER_SLOT)
	return istype(filter) && filter.compatible_with(patient) && filter.surgically_installed

/obj/structure/table/optable/vestige_graft_table
	name = "survey operating table"
	desc = "An ordinary operating surface supplied for a survey procedure."
	deconstruction_ready = FALSE
	buildstack = null
	custom_materials = null

/obj/structure/table/optable/vestige_graft_table/atom_deconstruct(disassembled)
	// Loan furniture cannot be converted into permanent frames or sheets.
	return

/obj/structure/table/optable/vestige_graft_table/Destroy()
	// The upstream table deletes its attached tank even after shared loan cleanup
	// moves it out. These are player additions, never part of this supplied table.
	if(air_tank)
		air_tank.forceMove(get_turf(src))
		air_tank = null
	if(breath_mask)
		UnregisterSignal(breath_mask, list(COMSIG_MOVABLE_MOVED, COMSIG_ITEM_DROPPED))
		if(breath_mask.loc == src)
			breath_mask.forceMove(get_turf(src))
		else if(breath_mask.loc)
			UnregisterSignal(breath_mask.loc, COMSIG_MOVABLE_MOVED)
		breath_mask = null
	return ..()

/obj/item/vestige_graft_kit
	name = "graft dossier"
	desc = "Use in hand to deploy the patient on the tile you face. Examine the patient for its waste class. Select chest, turn combat mode off, apply drapes and choose Organ Manipulation. Use scalpel, retractor, saw, hemostat, scalpel; then hemostat to extract the FAILED SURVEY FILTER, insert the matching replacement, and use cautery to close. Use this dossier on the patient to certify recovery. A wrong filter can be removed and replaced during the same operation."
	icon = 'icons/obj/service/library.dmi'
	icon_state = "book"
	inhand_icon_state = "clipboard"
	var/datum/weakref/trial_ref

/obj/item/vestige_graft_kit/attack_self(mob/living/user)
	var/datum/vestige_trial/vivisection/trial = trial_ref?.resolve()
	if(trial && user.mind?.active_vestige_trial == trial)
		trial.deploy(user)

/obj/item/vestige_graft_kit/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	var/datum/vestige_trial/vivisection/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || target != trial.patient)
		return NONE
	to_chat(user, span_notice(trial.patient.diagnosis()))
	if(!trial.can_discharge())
		to_chat(user, span_warning("Certification needs a surgically installed compatible filter, a completed chest closure, and a living patient with toxin burden at most five and health at least seventy-five."))
		return ITEM_INTERACT_BLOCKING
	to_chat(user, span_notice("The transplanted filter has restored waste clearance. The Curator recalls the recovered specimen."))
	trial.complete()
	return ITEM_INTERACT_SUCCESS

/mob/living/carbon/human/vestige_graft_patient
	name = "survey graft specimen"
	real_name = "survey graft specimen"
	var/datum/weakref/trial_ref
	var/waste_class = "chloride"

/mob/living/carbon/human/vestige_graft_patient/proc/diagnosis()
	return "Survey chemistry: accumulating [waste_class] waste; toxin burden [round(getToxLoss(), 0.1)]. Replace the failed supplemental filter with a gland that binds [waste_class]. The heart, lungs and liver are healthy organs and should remain in place."

/mob/living/carbon/human/vestige_graft_patient/examine(mob/user)
	. = ..()
	. += span_notice(diagnosis())

/mob/living/carbon/human/vestige_graft_patient/Life(seconds_per_tick, times_fired)
	. = ..()
	var/datum/vestige_trial/vivisection/trial = trial_ref?.resolve()
	if(!trial || trial.patient != src || trial.owner?.active_vestige_trial != trial || stat == DEAD)
		return
	var/obj/item/organ/vestige_filter/filter = get_organ_slot(VESTIGE_FILTER_SLOT)
	if(istype(filter) && filter.compatible_with(src))
		adjustToxLoss(-2 * seconds_per_tick)
	else if(getToxLoss() < 35)
		adjustToxLoss(seconds_per_tick)

/obj/item/organ/vestige_filter
	name = "survey filter"
	desc = "A benign supplemental waste filter. It can only be transplanted into its assigned survey specimen."
	icon_state = "liver"
	slot = VESTIGE_FILTER_SLOT
	zone = BODY_ZONE_CHEST
	organ_flags = ORGAN_ORGANIC
	var/waste_class
	var/functional = TRUE
	var/surgically_installed = FALSE
	var/datum/weakref/trial_ref

/obj/item/organ/vestige_filter/proc/configure(filter_kind, datum/vestige_trial/vivisection/trial)
	waste_class = filter_kind
	name = "[filter_kind]-binding survey filter"
	desc = "A benign supplemental gland that binds [filter_kind] waste. Other waste classes pass straight through. Only its assigned specimen accepts the graft."
	trial_ref = WEAKREF(trial)

/obj/item/organ/vestige_filter/proc/compatible_with(mob/living/carbon/human/vestige_graft_patient/patient)
	var/datum/vestige_trial/vivisection/trial = trial_ref?.resolve()
	return functional && trial && trial.owner?.active_vestige_trial == trial && trial.patient == patient && waste_class == patient.waste_class

/obj/item/organ/vestige_filter/pre_surgical_insertion(mob/living/user, mob/living/carbon/new_owner, target_zone)
	. = ..()
	var/datum/vestige_trial/vivisection/trial = trial_ref?.resolve()
	if(!. || !trial || trial.owner?.active_vestige_trial != trial || trial.patient != new_owner)
		to_chat(user, span_warning("This filter only fits its assigned survey specimen."))
		return FALSE

/obj/item/organ/vestige_filter/on_surgical_insertion(mob/living/user, mob/living/carbon/new_owner, target_zone, obj/item/tool)
	. = ..()
	surgically_installed = TRUE
	if(istype(new_owner, /mob/living/carbon/human/vestige_graft_patient) && compatible_with(new_owner))
		new_owner.setToxLoss(0)
		new_owner.visible_message(span_notice("[src] clears the specimen's accumulated waste; its grey pallor lifts."))
	else
		new_owner.visible_message(span_warning("The graft takes, but the specimen's waste burden does not improve."))

/obj/item/organ/vestige_filter/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	surgically_installed = FALSE

// ===== PROTOCOL: FIELD STUDY =====

/datum/vestige_trial/field_study
	name = "Protocol: Field Study"
	desc = "Deploy a living tissue culture with the probe. Use the supplied precision syringes to measure its response to nutrient and buffer doses, then prepare a viable sample within the culture's energy and membrane-stress windows. Each probe assay spends tissue viability; large overdoses damage it further. Ten units of water flush all media and recover the same culture immediately. Harvest a correctly balanced live culture with a right-click of the probe."
	var/obj/structure/vestige_tissue_culture/culture

/datum/vestige_trial/field_study/on_accepted(mob/living/user)
	var/obj/item/vestige_probe_baton/probe = new(get_turf(user))
	probe.trial_ref = WEAKREF(src)
	hand_over(user, probe)
	var/obj/item/storage/box/supplies = new(get_turf(user))
	supplies.name = "culture titration case"
	for(var/reagent_path in list(/datum/reagent/vestige_culture_nutrient, /datum/reagent/vestige_culture_buffer, /datum/reagent/water))
		var/obj/item/reagent_containers/cup/bottle/bottle = new(supplies)
		var/datum/reagent/reagent = GLOB.chemical_reagents_list[reagent_path]
		bottle.name = "[initial(reagent.name)] culture bottle"
		bottle.reagents.add_reagent(reagent_path, 50)
		new /obj/item/reagent_containers/syringe/vestige_precision(supplies)
	hand_over(user, supplies)

/datum/vestige_trial/field_study/get_progress_text()
	if(QDELETED(culture))
		return "Use the probe in hand to deploy the tissue culture. Examine the probe for syringe controls and the assay method."
	return "Culture viability [culture.viability]%. Target energy [culture.target_energy - 1] to [culture.target_energy + 1], stress -1 to +1. Right-click the culture with the probe to harvest."

/obj/item/reagent_containers/syringe/vestige_precision
	name = "survey precision syringe"
	desc = "A standard syringe with fine volume settings. Use in hand to cycle its transfer amount; right-click a bottle to draw that amount, then left-click the tissue culture to inject. Right-click the culture with an empty syringe to withdraw excess medium. Keep nutrient, buffer and water in separate syringes."
	amount_per_transfer_from_this = 1
	possible_transfer_amounts = list(0.5, 1, 2, 5, 10, 15)

/datum/reagent/vestige_culture_nutrient
	name = "survey nutrient"
	description = "A synthetic substrate metabolized only by survey tissue cultures. Inert in other organisms."
	color = "#D8AE53"
	taste_description = "chalk"

/datum/reagent/vestige_culture_buffer
	name = "survey buffer"
	description = "An inert culture medium that supports survey tissue membranes. It has no medicinal effect."
	color = "#74B5D1"
	taste_description = "chalk"

/obj/structure/vestige_tissue_culture
	name = "living survey tissue culture"
	desc = "A sealed, transparent culture reservoir. Inject measured nutrient and buffer using a syringe; an empty syringe can withdraw excess medium. Ten units of water flush the media and restore the same tissue. Use the probe for an assay; right-click with it to harvest."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "liver"
	color = "#A8D5C2"
	density = FALSE
	anchored = TRUE
	var/datum/weakref/trial_ref
	var/uptake_coefficient
	var/buffer_coefficient
	var/target_energy
	var/viability = 100
	var/assayed = FALSE
	var/washing = FALSE
	var/harvested = FALSE

/obj/structure/vestige_tissue_culture/Initialize(mapload)
	. = ..()
	create_reagents(80, INJECTABLE | DRAWABLE | TRANSPARENT)
	uptake_coefficient = pick(1, 1.5, 2)
	buffer_coefficient = pick(1, 1.5, 2)
	target_energy = pick(12, 15, 18)
	RegisterSignal(reagents, COMSIG_REAGENTS_HOLDER_UPDATED, PROC_REF(on_media_changed))

/obj/structure/vestige_tissue_culture/examine(mob/user)
	. = ..()
	. += span_notice("Target energy: [target_energy - 1] to [target_energy + 1]. Target membrane stress: -1 to +1. Viability: [viability]%; harvest needs at least 60%.")
	. += span_notice("Nutrient increases energy and stress proportionally. Buffer lowers stress without changing energy. Their uptake rates vary between cultures. A one-unit dose and an assay reveal a rate. Each assay spends 10% viability; energy above [target_energy + 4] or stress outside -8 to +8 spends another 25%. Flush with 10 units of water to recover without changing the rates.")

/obj/structure/vestige_tissue_culture/proc/energy()
	return reagents.get_reagent_amount(/datum/reagent/vestige_culture_nutrient) * uptake_coefficient

/obj/structure/vestige_tissue_culture/proc/stress()
	return energy() - reagents.get_reagent_amount(/datum/reagent/vestige_culture_buffer) * buffer_coefficient

/obj/structure/vestige_tissue_culture/proc/on_media_changed(datum/reagents/source)
	SIGNAL_HANDLER
	if(washing || harvested)
		return
	if(reagents.get_reagent_amount(/datum/reagent/water) >= 10)
		washing = TRUE
		reagents.clear_reagents()
		viability = 100
		assayed = FALSE
		washing = FALSE
		visible_message(span_notice("The water flushes all media from [src]. Its membrane repairs; the same culture is ready for another preparation."))

/obj/structure/vestige_tissue_culture/proc/assay()
	if(harvested)
		return
	assayed = TRUE
	viability = max(0, viability - 10)
	if(energy() > target_energy + 4 || abs(stress()) > 8)
		viability = max(0, viability - 25)
		visible_message(span_warning("[src] blisters under the assay pulse: the preparation is rupturing its membrane!"))
	return "Assay: energy [round(energy(), 0.1)], membrane stress [round(stress(), 0.1)], viability [viability]%. Target energy [target_energy - 1]..[target_energy + 1], stress -1..+1, viability at least 60%."

/obj/structure/vestige_tissue_culture/proc/viable()
	return !harvested && assayed && viability >= 60 && abs(energy() - target_energy) <= 1 && abs(stress()) <= 1

/// Consumes the measured preparation before the caller pays the single reward.
/obj/structure/vestige_tissue_culture/proc/harvest()
	if(!viable())
		return FALSE
	harvested = TRUE
	reagents.clear_reagents()
	viability = 0
	return TRUE

/obj/item/vestige_probe_baton
	name = "culture assay probe"
	desc = "Use in hand on clear floor to deploy a living culture. Syringes: use in hand to set volume, right-click bottles to draw, left-click culture to inject. Keep media separate. Start with small doses: nutrient increases energy and stress, buffer decreases stress. Probe left-click measures both and spends viability. Infer dose response, titrate into the displayed windows, then right-click with the probe to harvest. Ten units of water flush a failed preparation immediately."
	icon = 'icons/obj/devices/scanner.dmi'
	icon_state = "health"
	inhand_icon_state = "healthanalyzer"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	var/datum/weakref/trial_ref

/obj/item/vestige_probe_baton/attack_self(mob/living/user)
	var/datum/vestige_trial/field_study/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || !QDELETED(trial.culture))
		return
	var/turf/location = get_turf(user)
	if(!isfloorturf(location))
		return
	trial.culture = new(location)
	trial.culture.trial_ref = trial_ref
	trial.register_loan(trial.culture)
	to_chat(user, span_notice("The living culture unfolds. Examine it for its target window and safe assay limits."))

/obj/item/vestige_probe_baton/interact_with_atom(atom/target, mob/living/user, list/modifiers)
	var/datum/vestige_trial/field_study/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || target != trial.culture)
		return NONE
	to_chat(user, span_notice(trial.culture.assay()))
	trial.refresh_tracker()
	return ITEM_INTERACT_SUCCESS

/obj/item/vestige_probe_baton/interact_with_atom_secondary(atom/target, mob/living/user, list/modifiers)
	var/datum/vestige_trial/field_study/trial = trial_ref?.resolve()
	if(!trial || user.mind?.active_vestige_trial != trial || target != trial.culture)
		return NONE
	if(!trial.culture.harvest())
		to_chat(user, span_warning("Harvest rejected: assay the live tissue, retain at least 60% viability, and bring actual energy and stress inside both target windows."))
		return ITEM_INTERACT_BLOCKING
	to_chat(user, span_notice("The probe extracts the viable preparation. The culture chamber is empty."))
	trial.complete()
	return ITEM_INTERACT_SUCCESS

#undef VESTIGE_FILTER_SLOT

/**
 * # The Menagerie: abductor vestige BOONS (patron: the Curator)
 *
 * The boon half of the abductor theme: the Curator pays out in equipment and
 * procedures, catalogued like everything else it owns. Upstream abductor gear
 * is gated hard behind TRAIT_ABDUCTOR_TRAINING (AbductorCheck / ScientistCheck,
 * verified in abductor_items.dm) and DM cannot skip a parent's override to
 * reach a grandparent, so the tools here are local re-ports built on the clean
 * base classes rather than subtypes of the locked gear. The heal gland is the
 * exception: its organ logic carries no abductor checks at all (verified in
 * equipment/gland.dm and glands/heal.dm), so The Gift implants the upstream
 * organ unmodified.
 *
 * Patron and trials live in the theme file; this file defines only boons and
 * their granted gear/spells.
 */

// Boon and gear descs quote these numbers literally. Keep them in sync.
/// Recharge between successful motor-interruption (stun) discharges on the base instrument
#define VESTIGE_INSTRUMENT_STUN_RECHARGE (8 SECONDS)
/// Recharge between stun discharges on the perfected instrument
#define VESTIGE_INSTRUMENT_STUN_RECHARGE_PERFECTED (5 SECONDS)
/// Paralyze dealt by a stun discharge (upstream deals 14s; trimmed to crew tempo)
#define VESTIGE_INSTRUMENT_PARALYZE (6 SECONDS)
/// Sleep induced in an already-downed target (upstream deals 2 MINUTES; that deletes people from rounds)
#define VESTIGE_INSTRUMENT_SLEEP_TIME (30 SECONDS)
/// Recharge between successful sleep inductions
#define VESTIGE_INSTRUMENT_SLEEP_RECHARGE (20 SECONDS)
/// Channel time to fabricate restraints around a target's wrists (upstream: 3 seconds)
#define VESTIGE_INSTRUMENT_CUFF_TIME (3 SECONDS)
/// The cooldown planting the tag leaves behind, and the one a pull that never landed is refunded to
#define VESTIGE_ANCHOR_BUTTON_COOLDOWN (2 SECONDS)
/// How long the pull spends winding up before it lands. Any change of loc breaks it.
#define VESTIGE_ANCHOR_WARMUP (5 SECONDS)
/// Recharge on the anchor's return-teleport half
#define VESTIGE_ANCHOR_RECALL_COOLDOWN (60 SECONDS)
/// Recharge on the paired anchor's return-teleport half
#define VESTIGE_ANCHOR_RECALL_COOLDOWN_PAIRED (40 SECONDS)
/// Radius of the null field, in tiles around the caster
#define VESTIGE_NULL_FIELD_RADIUS 3
/// How long the null field's silence holds those caught in it
#define VESTIGE_NULL_FIELD_DURATION (20 SECONDS)
/// Recharge between null fields
#define VESTIGE_NULL_FIELD_COOLDOWN (60 SECONDS)

// ===== BOONS =====

// The instrument is a local port of the abductor baton (abductor_items.dm):
// same sprite family, same mode structure, minus the training lock, the probe
// mode, and the worst of the numbers. Modes are trimmed from four to two,
// stun and restraints, with per-mode internal recharges so the tool is a
// scalpel, not a crowd-control firehose. Sleep induction is held back for the
// revision, since taking a specimen off the board entirely is the strongest
// thing the tool does.
/datum/vestige_boon/item/alien_baton
	name = "The Instrument"
	// Keep the numbers in sync with VESTIGE_INSTRUMENT_STUN_RECHARGE /
	// VESTIGE_INSTRUMENT_CUFF_TIME (initial values must be constant, so no
	// define interpolation here)
	desc = "A handling tool with two settings. The first stuns a target on contact. The second spends a few seconds fabricating restraints around their wrists, and they are very hard to get off again. Specimens arrive in better condition when they are not chased."
	grant_text = "A cool alien weight settles into your hand, already humming."
	item_type = /obj/item/melee/baton/vestige_instrument

/datum/vestige_boon/item/alien_baton/perfected
	name = "The Perfected Instrument"
	// Keep the numbers in sync with VESTIGE_INSTRUMENT_STUN_RECHARGE_PERFECTED
	// / VESTIGE_INSTRUMENT_SLEEP_TIME (initial values must be constant, so no
	// define interpolation here)
	desc = "The tool you already carry, revised in place. The stun recharges faster, and a third setting is added: sleep induction, which only works on someone already down."
	grant_text = "Your instrument reworks itself in your grip, and comes back humming at a slightly more confident pitch."
	upgrades_from = /datum/vestige_boon/item/alien_baton
	item_type = /obj/item/melee/baton/vestige_instrument/perfected

/**
 * /datum/vestige_boon/item has no upgrade-replacement logic (only spells do),
 * so the perfected boon handles the swap itself, and it revises rather than
 * replaces: the first unrevised instrument the claimant is carrying is
 * upgraded where it sits, so the tool keeps its slot, its bag, and its charge
 * timers. Only a claimant carrying no instrument at all (stashed in a locker,
 * dropped, lost with a body) is issued a fresh perfected one.
 */
/datum/vestige_boon/item/alien_baton/perfected/grant(mob/living/user, datum/mind/owner)
	for(var/obj/item/melee/baton/vestige_instrument/prior in user.get_all_contents())
		if(!prior.perfect())
			continue
		to_chat(user, span_boldnotice(grant_text))
		return
	return ..()

// The recall anchor is a rebuild of the OLD abductor vest's blink-back; this
// tree's vest (abductor_clothing.dm) carries only stealth/combat modes, so
// there is no upstream behavior left to match and the spell below sets its
// own rules. The anchor is a physical tag rather than a stored turf on
// purpose: this fork's ships are shuttles whose turfs are copied wholesale
// when they transit, so a turf ref would strand the anchor in the empty space
// the ship departed, a tag object rides the deck it is planted on.
/datum/vestige_boon/spell/anchor_tag
	name = "Recall Anchor"
	// Keep the duration in sync with VESTIGE_ANCHOR_RECALL_COOLDOWN
	// (initial values must be constant, so no define interpolation here)
	desc = "Plant a tag where you stand, then pull yourself back to it from anywhere on the same world. The pull takes a while to wind up, and anything that moves you breaks it. It still respects local teleport wards. Moving the tag is free. Right-click the ability to plant or move it."
	grant_text = "A sense of exactly where you last stood settles into the back of your head."
	spell_type = /datum/action/cooldown/spell/vestige_recall_anchor

/datum/vestige_boon/spell/anchor_tag/paired
	name = "Paired Anchor"
	// Keep the duration in sync with VESTIGE_ANCHOR_RECALL_COOLDOWN_PAIRED
	// (initial values must be constant, so no define interpolation here)
	desc = "The pull takes a passenger now: whatever living thing you have grabbed, or that is riding on your back, arrives with you, and it recharges quicker. Specimens transported this way arrive in measurably better condition than specimens dragged the whole way."
	grant_text = "The tag learns a second signature."
	upgrades_from = /datum/vestige_boon/spell/anchor_tag
	spell_type = /datum/action/cooldown/spell/vestige_recall_anchor/paired

// The null field translates the abductor silencer (abductor_items.dm) for
// crew hands. Upstream shuts down radio HARDWARE; the boon enforces silence
// on the speakers themselves, the mute status effect
// (/datum/status_effect/silenced, applied via set_silence_if_lower, verified
// in status_effects.dm), which reads the same in play and cannot be undone
// by toggling a headset back on.
/datum/vestige_boon/spell/silence_field
	name = "Null Field"
	// Keep the numbers in sync with VESTIGE_NULL_FIELD_RADIUS /
	// VESTIGE_NULL_FIELD_DURATION (initial values must be constant, so no
	// define interpolation here)
	desc = "Silence every voice close around you for a while. Yours keeps working. It does no damage and makes no noise doing it. Most procedures go smoother without commentary."
	grant_text = "You find you know exactly how to take a room's voice away."
	spell_type = /datum/action/cooldown/spell/aoe/vestige_null_field

/**
 * The Gift: the upstream abductor HEAL gland (/obj/item/organ/heart/gland/heal,
 * glands/heal.dm), implanted directly. The organ carries no antag coupling.
 * Its activate() loop runs off owner alone, ejecting implants, regrowing
 * failing organs and limbs, and purging toxins/restoring blood on a 20-40
 * second cycle (verified in gland.dm/heal.dm; on_mob_insert Start()s it for
 * any non-surgical insertion). It replaces the heart in-slot: the displaced
 * original is dropped at the subject's feet (default unflagged Insert()
 * behavior, verified in organ_movement.dm) rather than destroyed, so the
 * squeamish can reverse the procedure surgically later.
 *
 * Body-bound by nature: the gland lives in the flesh, not the mind, so it is
 * lost with the body. The vestige record re-runs grant() on respawn restore,
 * which implants a fresh one. The desc says so honestly.
 */
/datum/vestige_boon/gland_graft
	name = "The Gift"
	desc = "A replicator gland grafted in where your heart used to be. It ejects foreign implants, regrows failing organs and limbs, and replaces lost blood, usually via the mouth. It does not survive a change of bodies, but reapplication is free."
	grant_text = "Something turns over in your chest twice and settles into a rhythm that isn't quite yours."
	radial_icon = 'icons/obj/antags/abductor.dmi'
	radial_icon_state = "health"

/datum/vestige_boon/gland_graft/grant(mob/living/user, datum/mind/owner)
	..()
	var/obj/item/organ/heart/gland/heal/gift = new()
	// Decommissioned like the trial kit's graft: the upstream gland ships with
	// 3 mind-control charges any abductor console could spend on the bearer
	gift.mind_control_uses = 0
	// Boons must land on plain humans, and they will, but a granting ritual
	// should never eat the pick on an exotic body. Non-carbons get the organ
	// in hand for later surgical installation instead.
	if(!iscarbon(user))
		user.put_in_hands(gift)
		to_chat(user, span_warning("The Curator's voice, faintly annoyed: \"Incompatible chassis. You will have to install it yourself.\""))
		return
	var/mob/living/carbon/subject = user
	if(!gift.Insert(subject)) // paranoia; carbon is checked above
		user.put_in_hands(gift)
		return
	playsound(subject, 'sound/effects/splat.ogg', 50, TRUE)
	subject.visible_message(
		span_warning("[subject] clutches [subject.p_their()] chest as something under the ribs rearranges itself!"),
		span_userdanger("Something slides into place behind your sternum and starts beating. Your original heart is on the floor at your feet."),
	)

// ===== THE INSTRUMENT =====

/**
 * The Curator's handling tool: the abductor baton, re-ported without the
 * training lock. Built on the clean baton base rather than the abductor
 * subtype because AbductorCheck lives in that subtype's can_baton()/toggle()
 * and DM offers no way to call past it to the grandparent.
 *
 * The base pipeline's shared stun cooldown (var/cooldown) gates EVERY
 * left-click mode behind one timer, which would break the tool's identity
 * combo (stun, switch settings, restrain), so it is zeroed, upstream-style,
 * and each mode meters itself inside baton_effect() instead. A stun attempt
 * during recharge is a harmless zero-force bonk with a balloon.
 */
/obj/item/melee/baton/vestige_instrument
	name = "alien instrument"
	desc = "A slim alien rod that drinks the light. Two settings: one for stopping a specimen, one for fitting a stopped specimen with restraints. Between uses it hums quietly to itself, counting."
	desc_controls = "Left-click to apply the active setting. Right-click to strike. Use in hand to switch settings."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "wonderprodStun"
	inhand_icon_state = "wonderprodStun"
	lefthand_file = 'icons/mob/inhands/antag/abductor_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/antag/abductor_righthand.dmi'
	icon_angle = -45
	force = 7
	wound_bonus = 0
	cooldown = 0 SECONDS // per-mode recharges are metered in baton_effect instead
	stamina_damage = 0
	on_stun_sound = 'sound/items/weapons/egloves.ogg'
	affect_cyborg = TRUE
	actions_types = list(/datum/action/item_action/toggle_mode)
	action_slots = ALL
	/// Current setting, always one of the entries in modes
	var/mode = BATON_STUN
	/// The settings this pattern carries, in cycle order (the revision splices in BATON_SLEEP)
	var/list/modes = list(BATON_STUN, BATON_CUFF)
	/// Recharge between successful stun discharges
	var/stun_recharge = VESTIGE_INSTRUMENT_STUN_RECHARGE
	/// Whether the perfected revision has been applied to this instrument
	var/perfected = FALSE
	/// Ready-time gate on the stun setting
	COOLDOWN_DECLARE(stun_ready)
	/// Ready-time gate on the sleep setting
	COOLDOWN_DECLARE(sleep_ready)

/obj/item/melee/baton/vestige_instrument/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/melee/baton/vestige_instrument/update_icon_state()
	. = ..()
	switch(mode)
		if(BATON_STUN)
			icon_state = "wonderprodStun"
			inhand_icon_state = "wonderprodStun"
		if(BATON_SLEEP)
			icon_state = "wonderprodSleep"
			inhand_icon_state = "wonderprodSleep"
		if(BATON_CUFF)
			icon_state = "wonderprodCuff"
			inhand_icon_state = "wonderprodCuff"

/obj/item/melee/baton/vestige_instrument/examine(mob/user)
	. = ..()
	switch(mode)
		if(BATON_STUN)
			. += span_notice("It is set to motor interruption.")
			if(!COOLDOWN_FINISHED(src, stun_ready))
				. += span_warning("The charge indicator is dim: [DisplayTimeText(COOLDOWN_TIMELEFT(src, stun_ready))] to ready.")
		if(BATON_SLEEP)
			. += span_notice("It is set to sleep induction. It takes hold fully only on someone already down.")
			if(!COOLDOWN_FINISHED(src, sleep_ready))
				. += span_warning("The sedative reservoir is cycling: [DisplayTimeText(COOLDOWN_TIMELEFT(src, sleep_ready))] to ready.")
		if(BATON_CUFF)
			. += span_notice("It is set to restraint fabrication.")

/obj/item/melee/baton/vestige_instrument/attack_self(mob/living/user)
	. = ..()
	toggle(user)

/// Cycles to the next setting. No training check: the Curator issues, it does not gatekeep.
/obj/item/melee/baton/vestige_instrument/proc/toggle(mob/living/user)
	// Find() on a setting that somehow isn't in the list returns 0, which lands on the first entry
	mode = modes[(modes.Find(mode) % length(modes)) + 1]
	var/setting
	switch(mode)
		if(BATON_STUN)
			setting = "motor interruption"
		if(BATON_SLEEP)
			setting = "sleep induction"
		if(BATON_CUFF)
			setting = "restraint fabrication"
	var/is_stun_mode = mode == BATON_STUN
	affect_cyborg = is_stun_mode
	log_stun_attack = is_stun_mode // sleep and cuffs write their own log lines
	on_stun_sound = (mode == BATON_CUFF) ? null : 'sound/items/weapons/egloves.ogg'
	balloon_alert(user, "set to [setting]")
	update_appearance()

// Messages are handled per-mode in baton_effect and its helpers, upstream-style
/obj/item/melee/baton/vestige_instrument/get_stun_description(mob/living/target, mob/living/user)
	return

/obj/item/melee/baton/vestige_instrument/get_cyborg_stun_description(mob/living/target, mob/living/user)
	return

/obj/item/melee/baton/vestige_instrument/baton_effect(mob/living/target, mob/living/user, modifiers, stun_override)
	switch(mode)
		if(BATON_STUN)
			if(!COOLDOWN_FINISHED(src, stun_ready))
				balloon_alert(user, "still charging!")
				return FALSE
			COOLDOWN_START(src, stun_ready, stun_recharge)
			target.visible_message(
				span_danger("[user] stuns [target] with [src]!"),
				span_userdanger("[user] stuns you with [src]!"),
				visible_message_flags = ALWAYS_SHOW_SELF_MESSAGE,
			)
			// Upstream's stun package, trimmed: 6s paralyze against upstream's 14
			target.set_jitter_if_lower(20 SECONDS)
			target.set_confusion_if_lower(8 SECONDS)
			target.set_stutter_if_lower(10 SECONDS)
			SEND_SIGNAL(target, COMSIG_LIVING_MINOR_SHOCK)
			target.Paralyze(VESTIGE_INSTRUMENT_PARALYZE * (HAS_TRAIT(target, TRAIT_BATON_RESISTANCE) ? 0.1 : 1))
			return TRUE
		if(BATON_SLEEP)
			sleep_attack(target, user)
		if(BATON_CUFF)
			cuff_attack(target, user)
	return FALSE

/**
 * Sleep induction (perfected pattern only), ported from upstream SleepAttack
 * with the round-deleting edges filed off: full effect only lands on a target
 * already stopped, incapacitated (ignoring mere cuffs or grabs, upstream's
 * own test) or flat on the deck, sleeps for 30 seconds instead of two
 * minutes, and the inducer recharges 20 seconds between doses. Standing
 * targets get token drowsiness; the stun setting exists for a reason.
 */
/obj/item/melee/baton/vestige_instrument/proc/sleep_attack(mob/living/target, mob/living/user)
	if(!COOLDOWN_FINISHED(src, sleep_ready))
		balloon_alert(user, "sedative cycling!")
		return
	if(INCAPACITATED_IGNORING(target, INCAPABLE_RESTRAINTS|INCAPABLE_GRAB) || target.body_position == LYING_DOWN)
		if(target.can_block_magic(MAGIC_RESISTANCE_MIND))
			to_chat(user, span_warning("Something in [target]'s head shrugs the inducer off. It seems you've been foiled."))
			target.visible_message(
				span_danger("[user] tried to induce sleep in [target] with [src], but is unsuccessful!"),
				span_userdanger("You feel a strange wave of heavy drowsiness wash over you!"),
			)
			target.adjust_drowsiness(4 SECONDS)
			return
		target.visible_message(
			span_danger("[user] induces sleep in [target] with [src]!"),
			span_userdanger("You suddenly feel very drowsy!"),
		)
		target.Sleeping(VESTIGE_INSTRUMENT_SLEEP_TIME)
		COOLDOWN_START(src, sleep_ready, VESTIGE_INSTRUMENT_SLEEP_RECHARGE)
		log_combat(user, target, "put to sleep", src.name)
		return
	// Standing and struggling: token drowsiness only, no recharge spent
	if(target.can_block_magic(MAGIC_RESISTANCE_MIND, charge_cost = 0))
		to_chat(user, span_warning("Something in [target]'s head blocks the inducer entirely. It seems you've been foiled."))
		return
	target.adjust_drowsiness(2 SECONDS)
	to_chat(user, span_warning("The inducer takes hold fully only on specimens already down."))
	target.visible_message(
		span_danger("[user] waves [src] over [target] to little effect!"),
		span_userdanger("You suddenly feel drowsy!"),
	)

/**
 * Restraint fabrication, ported from upstream CuffAttack unchanged in the
 * ways that matter: a 3 second channel, then upstream's self-tightening
 * hard-light restraints, 45 second breakout, and they discharge into sparks
 * the moment they come off (energy/used is DROPDEL; verified in
 * abductor_items.dm).
 */
/obj/item/melee/baton/vestige_instrument/proc/cuff_attack(mob/living/victim, mob/living/user)
	if(!iscarbon(victim))
		balloon_alert(user, "no compatible wrists!")
		return
	var/mob/living/carbon/carbon_victim = victim
	if(carbon_victim.handcuffed)
		balloon_alert(user, "already restrained!")
		return
	if(!carbon_victim.canBeHandcuffed())
		to_chat(user, span_warning("[carbon_victim] doesn't have two hands..."))
		return
	playsound(src, 'sound/items/weapons/cablecuff.ogg', 30, TRUE, -2)
	carbon_victim.visible_message(
		span_danger("[user] begins restraining [carbon_victim] with [src]!"),
		span_userdanger("[user] begins shaping an energy field around your hands!"),
	)
	if(!do_after(user, VESTIGE_INSTRUMENT_CUFF_TIME, carbon_victim) || !carbon_victim.canBeHandcuffed() || carbon_victim.handcuffed)
		to_chat(user, span_warning("You fail to restrain [carbon_victim]."))
		return
	carbon_victim.set_handcuffed(new /obj/item/restraints/handcuffs/energy/used(carbon_victim))
	carbon_victim.update_handcuffed()
	to_chat(user, span_notice("You restrain [carbon_victim]."))
	log_combat(user, carbon_victim, "handcuffed", src.name)

/**
 * The revision, applied to an instrument that already exists: quicker between
 * discharges, and sleep induction spliced onto the end of the setting cycle.
 *
 * The perfected boon calls this on the tool the claimant is already carrying,
 * so the upgrade keeps the same object rather than handing over a replacement.
 * Returns FALSE if this instrument has already been revised, which is what
 * lets the boon walk a claimant's contents and stop at the first unrevised one.
 */
/obj/item/melee/baton/vestige_instrument/proc/perfect()
	if(perfected)
		return FALSE
	perfected = TRUE
	name = "perfected alien instrument"
	desc = "A slim alien rod that drinks the light. Three settings: stopping a specimen, fitting a stopped specimen with restraints, and putting one to sleep. The hum between uses is shorter now."
	modes = list(BATON_STUN, BATON_CUFF, BATON_SLEEP)
	stun_recharge = VESTIGE_INSTRUMENT_STUN_RECHARGE_PERFECTED
	update_appearance()
	return TRUE

// The revised pattern issued whole, for a claimant who no longer has the tool
// they were given. Everything the revision changes lives in perfect(), so a
// spawned copy and an upgraded-in-place copy cannot drift apart.
/obj/item/melee/baton/vestige_instrument/perfected/Initialize(mapload)
	. = ..()
	perfect()

// ===== RECALL ANCHOR =====

/**
 * A two-stage return spell rebuilt from the retired abductor vest blink-back.
 * Left-click (or keybind) pulls the caster to the planted tag; right-clicking
 * the button plants or moves the tag (the same input split the heretic living
 * heart uses). With no tag planted, any cast plants one.
 *
 * The pull is not instant: it winds up for five seconds first, drawn on the
 * caster's tile, and any change of loc during those seconds breaks it. The
 * channel runs in before_cast, so a broken pull cancels the cast outright and
 * costs nothing but the time spent standing there.
 *
 * Only the PULL pays the long recharge, but that recharge IS the action's
 * cooldown_time rather than a private timer, so the button displays it. The
 * halves that shouldn't pay it (planting, a pull that never landed) wave off
 * the automatic cooldown with SPELL_NO_IMMEDIATE_COOLDOWN and start the short
 * one by hand; a right-click replant lifts the timer for the length of its own
 * trigger so moving the tag stays free while the pull recharges.
 *
 * The pull refuses to cross z-levels. There is no upstream rule to match
 * (this tree's vest lost its blink-back), and in an overmap fork a cross-z
 * recall is a free ride home from anywhere in the galaxy. Because the tag is
 * a physical object, it transits WITH a ship that moves, so "same z" always
 * reads as "same local space", and a ship undocking without you honestly
 * strands you. do_teleport runs unforced on the magic channel: NOTELEPORT
 * areas and TRAIT_NO_TELEPORT keep their veto.
 */
/datum/action/cooldown/spell/vestige_recall_anchor
	name = "Recall Anchor"
	desc = "Teleport back to your anchor tag, from anywhere on the same world. It cannot reach a tag on a ship out in space or on another world. The pull takes a while to wind up and breaks if anything moves you. Right-click to plant or move the tag."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "vortex_recall"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	school = SCHOOL_TRANSLOCATION
	cooldown_time = VESTIGE_ANCHOR_RECALL_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// The planted tag. A physical object so it rides whatever deck it is planted on.
	var/obj/effect/vestige_anchor_tag/anchor
	/// Whether the activation in flight arrived via right-click (a replant request)
	var/replant_requested = FALSE
	/// Resolved intent for the cast in flight: TRUE plants/moves the tag, FALSE pulls to it
	var/planting_this_cast = TRUE
	/// TRUE while a pull is winding up, so a second click can't stack channels
	var/channelling = FALSE

/datum/action/cooldown/spell/vestige_recall_anchor/Destroy()
	QDEL_NULL(anchor)
	return ..()

/datum/action/cooldown/spell/vestige_recall_anchor/Trigger(mob/clicker, trigger_flags, atom/target)
	if(channelling)
		owner.balloon_alert(owner, "already pulling!")
		return FALSE
	replant_requested = !!(trigger_flags & TRIGGER_SECONDARY_ACTION)
	if(!replant_requested)
		return ..()
	// The button's timer is the pull's recharge, which is the number a player
	// needs to see, but planting was never gated by it. Lift the timer for the
	// length of this trigger and hand back whatever is left of it, so a replant
	// during the recharge goes through without clearing (or refreshing) it.
	// Nothing on the planting path sleeps, so no tick can land in the gap.
	var/pull_ready_at = next_use_time
	next_use_time = 0
	. = ..()
	next_use_time = max(next_use_time, pull_ready_at)
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/// The tag's current turf, or null while it is unplanted (or has somehow been destroyed)
/datum/action/cooldown/spell/vestige_recall_anchor/proc/get_anchor_turf()
	if(QDELETED(anchor))
		anchor = null
		return null
	return get_turf(anchor)

/datum/action/cooldown/spell/vestige_recall_anchor/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	if(channelling)
		owner.balloon_alert(owner, "already pulling!")
		return . | SPELL_CANCEL_CAST
	planting_this_cast = replant_requested || !get_anchor_turf()
	replant_requested = FALSE // never let a stale right-click steer a later keybind cast
	// Both halves start their own cooldown (plant_tag and pull_to_tag), so the
	// automatic one is waved off. Otherwise planting, which is free, would
	// stamp the pull's minute onto the button on its way out
	. |= SPELL_NO_IMMEDIATE_COOLDOWN
	if(planting_this_cast)
		return
	var/turf/here = get_turf(cast_on)
	var/turf/destination = get_anchor_turf()
	if(here == destination)
		owner.balloon_alert(owner, "already at the anchor!")
		return . | SPELL_CANCEL_CAST
	if(!here || here.z != destination.z)
		owner.balloon_alert(owner, "anchor out of reach!")
		// Say the rule out loud: players who left the tag on a ship now in orbit
		// read the old vague line as the power being broken (round 14)
		to_chat(owner, span_warning("The tag answers faintly from another space entirely. The pull only reaches a tag on the same world - it cannot cross to a ship out in space."))
		return . | SPELL_CANCEL_CAST
	// The wind-up lives here rather than in cast(): a broken pull cancels the
	// whole cast, so it pays no recharge at all. Standing still IS the cost
	if(!channel_pull(cast_on))
		return . | SPELL_CANCEL_CAST
	// Five seconds is long enough for the world to move underneath the tag, or
	// for the caster to stop being one
	if(QDELETED(src) || QDELETED(owner) || QDELETED(cast_on) || owner != cast_on)
		return . | SPELL_CANCEL_CAST
	here = get_turf(cast_on)
	destination = get_anchor_turf()
	if(!here || !destination || here == destination || here.z != destination.z)
		owner.balloon_alert(owner, "anchor out of reach!")
		to_chat(owner, span_warning("The fold closes on nothing. The tag is no longer somewhere the pull can reach."))
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/vestige_recall_anchor/cast(mob/living/cast_on)
	. = ..()
	if(planting_this_cast)
		plant_tag(cast_on)
	else
		pull_to_tag(cast_on)

/**
 * The wind-up. Five seconds of standing still while the tag takes hold, drawn
 * on the caster's own tile so anyone watching gets the same warning the caster
 * does. do_after does the enforcing: walking off, being dragged, being thrown
 * or being stunned all break it, and a broken pull costs only the time. What
 * the caster is holding is left out of it. The pull is a thing done to the
 * body, and there is no reason swapping hands should interrupt it.
 */
/datum/action/cooldown/spell/vestige_recall_anchor/proc/channel_pull(mob/living/user)
	var/turf/here = get_turf(user)
	user.visible_message(
		span_warning("[user] goes rigid, and the air folds inward around [user.p_them()]!"),
		span_notice("The tag takes hold and starts reeling you in. Hold still."),
	)
	playsound(here, 'sound/effects/magic/lightning_chargeup.ogg', 35, TRUE, -2)
	var/obj/effect/temp_visual/vestige_recall_pull/winding = new(here)
	channelling = TRUE
	. = do_after(user, VESTIGE_ANCHOR_WARMUP, timed_action_flags = IGNORE_HELD_ITEM)
	channelling = FALSE
	if(!QDELETED(winding))
		qdel(winding)
	if(. || QDELETED(user))
		return
	user.balloon_alert(user, "pull broken!")
	to_chat(user, span_warning("The fold comes apart, and the deck is still under you."))

/// Plants the tag at the caster's feet, or drags the existing one over
/datum/action/cooldown/spell/vestige_recall_anchor/proc/plant_tag(mob/living/user)
	var/turf/spot = get_turf(user)
	if(!spot)
		return
	if(QDELETED(anchor))
		anchor = new(spot)
	else
		anchor.forceMove(spot)
	playsound(spot, 'sound/machines/click.ogg', 30, TRUE)
	user.balloon_alert(user, "anchor planted")
	StartCooldown(VESTIGE_ANCHOR_BUTTON_COOLDOWN) // planting is free; this is only anti-spam
	// A tag in a warded area plants fine and then refuses every pull,
	// complain now, not at the worst possible moment
	var/area/spot_area = get_area(spot)
	if(spot_area.area_flags & NOTELEPORT)
		to_chat(user, span_warning("The tag buzzes unhappily: something about this place refuses arrivals. The pull will not land here."))

/// The pull. Buckled riders (fireman carries, piggybacks) come along via
/// do_teleport's own rider handling; a grabbed passenger is the paired
/// pattern's business, captured before the jump breaks the pull.
/datum/action/cooldown/spell/vestige_recall_anchor/proc/pull_to_tag(mob/living/user)
	var/turf/destination = get_anchor_turf()
	var/mob/living/passenger = destination ? gather_passenger(user) : null
	if(!destination || !do_teleport(user, destination, asoundout = 'sound/effects/phasein.ogg', channel = TELEPORT_CHANNEL_MAGIC))
		// do_teleport balloons the refusal itself; a pull that never landed spends no recharge
		StartCooldown(VESTIGE_ANCHOR_BUTTON_COOLDOWN)
		return
	StartCooldown() // the recharge the button counts down
	if(!passenger || QDELETED(passenger))
		return
	if(do_teleport(passenger, destination, channel = TELEPORT_CHANNEL_MAGIC, no_effects = TRUE))
		user.start_pulling(passenger, supress_message = TRUE)
		to_chat(passenger, span_warning("The deck blinks, and you are somewhere else. You are still held."))
	else
		to_chat(user, span_warning("The pull arrives alone. Your passenger was refused."))

/// Who comes along for the pull. The base anchor takes nobody.
/datum/action/cooldown/spell/vestige_recall_anchor/proc/gather_passenger(mob/living/user)
	return null

/datum/action/cooldown/spell/vestige_recall_anchor/paired
	name = "Paired Anchor"
	desc = "Teleport back to your anchor tag, bringing whoever you're grabbing or carrying. The pull takes a while to wind up and breaks if anything moves you. Right-click to plant or move the tag."
	cooldown_time = VESTIGE_ANCHOR_RECALL_COOLDOWN_PAIRED

// Grabbed-or-willing, by this fork's own teleport grammar: a pulled living
// thing (grabs are adjacency by definition) is ferried by hand below, and
// willing riders buckled on for a carry are ferried by do_teleport natively.
/datum/action/cooldown/spell/vestige_recall_anchor/paired/gather_passenger(mob/living/user)
	if(isliving(user.pulling))
		return user.pulling
	return null

/// The planted half of the recall anchor. A physical object on purpose:
/// shuttle transits carry it with the deck it is planted on, where a stored
/// turf ref would point forever at the tile the ship left behind. Effects
/// are indestructible and immovable by default, so the counterplay is
/// spotting it (it glows, faintly) and camping it, not breaking it.
/obj/effect/vestige_anchor_tag
	name = "recall anchor"
	desc = "A stubby alien beacon planted flat against the deck. It stays with whatever it is stuck to, wherever that ends up going."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "beacon"
	layer = LOW_OBJ_LAYER
	anchored = TRUE
	alpha = 160
	light_range = 1.2
	light_power = 0.4
	light_color = "#9fd8cf"

/**
 * The pull winding up, drawn on the caster's tile for the length of the
 * channel. It borrows the abductor pad's own teleport silhouette (pad.dm) so
 * the wind-up reads as the same technology as the tag, and grows as it charges
 * so a bystander can see how much time is left to do something about it.
 */
/obj/effect/temp_visual/vestige_recall_pull
	name = "folding air"
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "teleport"
	duration = VESTIGE_ANCHOR_WARMUP
	randomdir = FALSE
	alpha = 70
	light_range = 1.5
	light_power = 0.5
	light_color = "#9fd8cf"

/obj/effect/temp_visual/vestige_recall_pull/Initialize(mapload)
	. = ..()
	transform = matrix().Scale(0.5)
	animate(src, transform = matrix(), alpha = 230, time = duration, easing = SINE_EASING)

// ===== NULL FIELD =====

/**
 * The abductor silencer, translated from hardware to procedure. Upstream
 * (abductor_items.dm) switches off radios in a small view radius; the boon
 * spec reads that as enforced silence and applies the mute status effect
 * (/datum/status_effect/silenced, TRAIT_MUTE under a timer, cleared on
 * death/fullheal) to everyone caught in the field at cast. One application,
 * no lingering zone, no damage, and (deliberately) no sound or room-wide
 * message: a silencer that announced itself would be a contradiction. The
 * caster is exempt, as upstream exempts its user.
 *
 * Mind-antimagic bearers shrug it off (charge-free check, the same courtesy
 * the instrument's sleep inducer pays) so a warded target keeps their voice.
 * range() rather than view(): it is a field, and glass or a shut door is no
 * defense against twenty seconds of nothing.
 */
/datum/action/cooldown/spell/aoe/vestige_null_field
	name = "Null Field"
	desc = "Silences everyone close around you for a while. You can still talk."
	button_icon = 'icons/mob/actions/actions_mime.dmi'
	button_icon_state = "mime_speech"
	background_icon_state = "bg_alien"
	overlay_icon_state = "bg_alien_border"
	cooldown_time = VESTIGE_NULL_FIELD_COOLDOWN
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	antimagic_flags = MAGIC_RESISTANCE_MIND
	aoe_radius = VESTIGE_NULL_FIELD_RADIUS

/datum/action/cooldown/spell/aoe/vestige_null_field/get_things_to_cast_on(atom/center)
	var/list/things = list()
	for(var/mob/living/nearby in range(aoe_radius, center))
		if(nearby == owner || nearby == center || nearby.stat == DEAD)
			continue
		things += nearby
	return things

/datum/action/cooldown/spell/aoe/vestige_null_field/cast_on_thing_in_aoe(mob/living/victim, atom/caster)
	if(victim.can_block_magic(antimagic_flags, charge_cost = 0))
		to_chat(victim, span_notice("A pressure closes around your throat for a heartbeat, and something you carry shrugs it away."))
		return
	victim.set_silence_if_lower(VESTIGE_NULL_FIELD_DURATION)
	to_chat(victim, span_warning("Your voice goes somewhere you can't reach it. The room has gone completely silent."))

/datum/action/cooldown/spell/aoe/vestige_null_field/after_cast(atom/cast_on)
	. = ..()
	owner.balloon_alert(owner, "the field takes hold")

#undef VESTIGE_INSTRUMENT_STUN_RECHARGE
#undef VESTIGE_INSTRUMENT_STUN_RECHARGE_PERFECTED
#undef VESTIGE_INSTRUMENT_PARALYZE
#undef VESTIGE_INSTRUMENT_SLEEP_TIME
#undef VESTIGE_INSTRUMENT_SLEEP_RECHARGE
#undef VESTIGE_INSTRUMENT_CUFF_TIME
#undef VESTIGE_ANCHOR_BUTTON_COOLDOWN
#undef VESTIGE_ANCHOR_WARMUP
#undef VESTIGE_ANCHOR_RECALL_COOLDOWN
#undef VESTIGE_ANCHOR_RECALL_COOLDOWN_PAIRED
#undef VESTIGE_NULL_FIELD_RADIUS
#undef VESTIGE_NULL_FIELD_DURATION
#undef VESTIGE_NULL_FIELD_COOLDOWN
