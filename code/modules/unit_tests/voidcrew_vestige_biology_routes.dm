/** Complete biological mission routes, using supplied kit and actual progress events. */
/datum/unit_test/vestige_biology_route
	abstract_type = /datum/unit_test/vestige_biology_route
	var/mob/living/carbon/human/consistent/user
	var/turf/center
	var/datum/vestige_trial/trial
	var/list/terrain_originals = list()

/datum/unit_test/vestige_biology_route/New()
	..()
	center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	restore_atmos()

/datum/unit_test/vestige_biology_route/Destroy()
	QDEL_NULL(trial)
	QDEL_NULL(user)
	for(var/list/record as anything in terrain_originals)
		var/turf/spot = locate(record[1], record[2], record[3])
		spot.RemoveElement(/datum/element/forced_gravity, 1)
		spot.ChangeTurf(record[4])
	return ..()

/datum/unit_test/vestige_biology_route/proc/prepare(trial_type)
	trial = allocate(trial_type, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	return trial

/datum/unit_test/vestige_biology_route/proc/loan(item_type)
	for(var/datum/weakref/ref as anything in trial.loan_refs)
		var/obj/item/item = ref.resolve()
		if(istype(item, item_type))
			return item
	return null

/datum/unit_test/vestige_biology_route/proc/hold(obj/item/item)
	if(!item)
		return FALSE
	if(user.is_holding(item))
		user.swap_hand(user.get_held_index_of_item(item))
		return user.get_active_held_item() == item
	user.dropItemToGround(user.get_active_held_item())
	return user.put_in_active_hand(item)

/datum/unit_test/vestige_biology_route/birth/Run()
	var/datum/vestige_trial/birth/birth = prepare(/datum/vestige_trial/birth)
	var/mob/living/basic/carp/carcass = allocate(/mob/living/basic/carp, get_step(center, NORTH))
	carcass.death()
	TEST_ASSERT(hold(birth.egg), "The keeper must select the actual supplied egg.")
	birth.egg.melee_attack_chain(user, carcass, list())
	var/mob/living/basic/headslug/vestige_child/child = birth.child
	TEST_ASSERT(child, "The real five-second egg attack must hatch the child from a wild carcass.")
	child.ai_controller.PauseAi(1 MINUTES)
	for(var/prey_index in 1 to 2)
		var/mob/living/basic/carp/prey = allocate(/mob/living/basic/carp, get_step(child, EAST))
		prey.ai_controller.PauseAi(1 MINUTES)
		TEST_ASSERT(prey.base_ranged_item_interaction(user, birth.egg, list()) & ITEM_INTERACT_BLOCKING, "The actual ranged egg handler must accept the hunt input.")
		TEST_ASSERT_EQUAL(child.prey_ref?.resolve(), prey, "The kit must command the actual live prey.")
		for(var/bite in 1 to 5)
			if(child.growth >= 40)
				break
			TEST_ASSERT(child.melee_attack(prey, ignore_cooldown = TRUE), "Each feeding credit must come from a real commanded bite.")
	TEST_ASSERT_EQUAL(child.growth, 40, "Actual damage to two live carp must grow the child fully.")
	TEST_ASSERT(user.Adjacent(child), "The grown child must be beside the keeper for recall.")
	user.execute_mode()
	TEST_ASSERT(/datum/vestige_trial/birth in user.mind.completed_vestige_trials, "The actual egg activation must send the grown child home and finish Birth.")

/datum/unit_test/vestige_biology_route/faces/Run()
	var/datum/vestige_trial/faces/faces = prepare(/datum/vestige_trial/faces)
	var/obj/item/vestige_proboscis/proboscis = faces.proboscis
	var/mob/living/basic/carp/carcass = allocate(/mob/living/basic/carp, get_step(center, NORTH))
	carcass.death()
	TEST_ASSERT(hold(proboscis), "The keeper must select the supplied proboscis.")
	proboscis.melee_attack_chain(user, carcass, list())
	TEST_ASSERT(faces.sampled, "The actual three-second corpse-sampling channel must unlock adaptation.")
	for(var/exchange in 1 to 2)
		var/mob/living/basic/carp/prey = allocate(/mob/living/basic/carp, get_step(user, NORTH))
		prey.ai_controller.PauseAi(1 MINUTES)
		if(world.time < proboscis.brace_ready_at)
			sleep(proboscis.brace_ready_at - world.time)
		user.execute_mode()
		TEST_ASSERT(proboscis.brace, "The actual activate-held-object input must raise the sampled carapace.")
		var/before = user.getBruteLoss()
		prey.melee_attack(user, ignore_cooldown = TRUE)
		TEST_ASSERT_EQUAL(user.getBruteLoss(), before, "The carapace must catch a real fauna bite.")
		TEST_ASSERT_EQUAL(proboscis.attacker_ref?.resolve(), prey, "The caught bite must identify its real attacker.")
		var/direction = exchange == 1 ? EAST : WEST
		for(var/step in 1 to 2)
			TEST_ASSERT(user.Move(get_step(user, direction), direction), "The keeper must physically retreat two tiles after the bite.")
		prey.base_ranged_item_interaction(user, proboscis, list())
		if(exchange == 1)
			TEST_ASSERT_EQUAL(faces.assimilated, 20, "The first ranged counter must consume twenty actual tissue.")
	TEST_ASSERT(/datum/vestige_trial/faces in user.mind.completed_vestige_trials, "Two complete sampled-brace-bite-retreat-counter exchanges must finish Faces.")

/// Only syringe controls and bottle/culture handlers change the preparation.
/datum/unit_test/vestige_biology_route/proc/dose(obj/item/reagent_containers/syringe/vestige_precision/syringe, obj/item/reagent_containers/cup/bottle/bottle, obj/structure/vestige_tissue_culture/culture, volume)
	if(!hold(syringe))
		return FALSE
	while(volume > 0)
		var/portion = volume >= 1 ? 1 : 0.5
		for(var/index in 1 to length(syringe.possible_transfer_amounts))
			if(syringe.amount_per_transfer_from_this == portion)
				break
			user.execute_mode()
		if(syringe.amount_per_transfer_from_this != portion)
			return FALSE
		if(!(bottle.base_item_interaction(user, syringe, list(RIGHT_CLICK = "1")) & ITEM_INTERACT_SUCCESS))
			return FALSE
		if(!(culture.base_item_interaction(user, syringe, list()) & ITEM_INTERACT_SUCCESS))
			return FALSE
		volume -= portion
	return TRUE

/datum/unit_test/vestige_biology_route/field_study/Run()
	var/datum/vestige_trial/field_study/study = prepare(/datum/vestige_trial/field_study)
	var/obj/item/vestige_probe_baton/probe = loan(/obj/item/vestige_probe_baton)
	TEST_ASSERT(hold(probe), "The researcher must select the supplied probe.")
	user.execute_mode()
	var/obj/structure/vestige_tissue_culture/culture = study.culture
	TEST_ASSERT(culture, "The actual probe activation must deploy the living culture.")
	var/obj/item/reagent_containers/cup/bottle/nutrient
	var/obj/item/reagent_containers/cup/bottle/buffer
	var/list/syringes = list()
	for(var/datum/weakref/ref as anything in study.loan_refs)
		var/obj/item/item = ref.resolve()
		if(istype(item, /obj/item/reagent_containers/syringe/vestige_precision))
			syringes += item
		if(!istype(item, /obj/item/reagent_containers/cup/bottle))
			continue
		if(item.reagents.has_reagent(/datum/reagent/vestige_culture_nutrient))
			nutrient = item
		else if(item.reagents.has_reagent(/datum/reagent/vestige_culture_buffer))
			buffer = item
	TEST_ASSERT(nutrient && buffer && length(syringes) >= 2, "The issued case must contain both media and separate precision syringes.")
	TEST_ASSERT(hold(nutrient), "The nutrient bottle must be removable from the supplied case.")
	user.dropItemToGround(nutrient)
	TEST_ASSERT(hold(buffer), "The buffer bottle must be removable from the supplied case.")
	user.dropItemToGround(buffer)
	TEST_ASSERT(dose(syringes[1], nutrient, culture, 1), "The researcher must draw and inject one real nutrient unit.")
	TEST_ASSERT(hold(probe), "The researcher must select the probe for the first assay.")
	TEST_ASSERT(culture.base_item_interaction(user, probe, list()) & ITEM_INTERACT_SUCCESS, "The actual probe must assay the first measured dose.")
	var/observed_uptake = culture.energy()
	TEST_ASSERT(dose(syringes[2], buffer, culture, 1), "The researcher must draw and inject one real buffer unit.")
	TEST_ASSERT(hold(probe), "The researcher must select the probe for the second assay.")
	TEST_ASSERT(culture.base_item_interaction(user, probe, list()) & ITEM_INTERACT_SUCCESS, "The actual probe must assay the buffer response.")
	var/observed_buffer = culture.energy() - culture.stress()
	TEST_ASSERT(dose(syringes[1], nutrient, culture, culture.target_energy / observed_uptake - 1), "The supplied nutrient and syringe increments must reach the measured energy target.")
	TEST_ASSERT(dose(syringes[2], buffer, culture, culture.target_energy / observed_buffer - 1), "The supplied buffer and syringe increments must balance the measured stress.")
	TEST_ASSERT(hold(probe), "The researcher must select the probe for the final assay.")
	TEST_ASSERT(culture.base_item_interaction(user, probe, list()) & ITEM_INTERACT_SUCCESS, "The actual probe must assay the prepared culture.")
	TEST_ASSERT_EQUAL(culture.viability, 70, "Three necessary assays must leave a viable preparation.")
	TEST_ASSERT(culture.base_item_interaction(user, probe, list(RIGHT_CLICK = "1")) & ITEM_INTERACT_SUCCESS, "The real right-click probe input must harvest the balanced live culture.")
	TEST_ASSERT(/datum/vestige_trial/field_study in user.mind.completed_vestige_trials, "Actual measured bottle-to-culture chemistry must finish Field Study.")

/datum/unit_test/vestige_biology_route/proc/walk_route_to(turf/destination)
	var/turf/start = get_turf(user)
	var/list/queue = list(start)
	var/list/previous = list()
	previous[start] = TRUE
	for(var/index in 1 to 169)
		if(index > length(queue))
			return FALSE
		var/turf/current = queue[index]
		if(current == destination)
			var/list/path = list()
			while(current != start)
				path.Insert(1, current)
				current = previous[current]
			for(var/turf/next as anything in path)
				if(!user.Move(next, get_dir(user, next)))
					return FALSE
			return TRUE
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || get_dist(next, center) > 6 || previous[next] || next.is_blocked_turf())
				continue
			previous[next] = current
			queue += next
	return FALSE

/datum/unit_test/vestige_biology_route/acquisition/Run()
	center = locate(run_loc_floor_bottom_left.x + 6, run_loc_floor_bottom_left.y + 6, run_loc_floor_bottom_left.z)
	var/center_x = center.x
	var/center_y = center.y
	var/center_z = center.z
	for(var/turf/spot in RANGE_TURFS(6, center))
		terrain_originals += list(list(spot.x, spot.y, spot.z, spot.type))
		var/turf/floor = spot.ChangeTurf(/turf/open/floor/plating)
		floor.AddElement(/datum/element/forced_gravity, 1)
	center = locate(center_x, center_y, center_z)
	user.forceMove(center)
	ADD_TRAIT(user, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(user, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(user, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/vestige_trial/acquisition/acquisition = prepare(/datum/vestige_trial/acquisition)
	var/obj/item/vestige_observation_lens/lens = loan(/obj/item/vestige_observation_lens)
	TEST_ASSERT(hold(lens), "The researcher must select the actual observation lens.")
	user.execute_mode()
	var/mob/living/basic/vestige_survey_specimen/specimen = acquisition.specimen
	TEST_ASSERT(specimen, "The normal lens activation must find connected release floor and create its specimen.")
	STOP_PROCESSING(SSfastprocess, specimen)
	var/list/panels = list()
	for(var/datum/weakref/ref as anything in acquisition.loan_refs)
		var/obj/item/vestige_field_panel/panel = ref.resolve()
		if(istype(panel))
			panels += panel
	TEST_ASSERT_EQUAL(length(panels), 4, "The real kit must supply exactly four enclosure panels.")
	var/drive_direction
	if(abs(specimen.x - center.x) >= abs(specimen.y - center.y))
		drive_direction = specimen.x > center.x ? WEST : EAST
	else
		drive_direction = specimen.y > center.y ? SOUTH : NORTH
	var/turf/enclosure = get_turf(specimen)
	for(var/step in 1 to 4)
		enclosure = get_step(enclosure, drive_direction)
	var/perpendicular = turn(drive_direction, 90)
	var/list/wall_directions = list(drive_direction, perpendicular, REVERSE_DIR(perpendicular))
	for(var/index in 1 to 3)
		var/turf/barrier_spot = get_step(enclosure, wall_directions[index])
		var/approached = FALSE
		for(var/direction in GLOB.cardinals)
			if(walk_route_to(get_step(barrier_spot, direction)))
				approached = TRUE
				break
		TEST_ASSERT(approached, "The researcher must physically approach each enclosure side.")
		TEST_ASSERT(hold(panels[index]), "The researcher must hold the supplied panel before deploying it.")
		TEST_ASSERT(barrier_spot.base_item_interaction(user, panels[index], list()) & ITEM_INTERACT_SUCCESS, "The real panel input must build each of the first three enclosure sides.")
	TEST_ASSERT(walk_route_to(get_step(specimen, REVERSE_DIR(drive_direction))), "The researcher must walk behind the released specimen.")
	for(var/step in 1 to 4)
		var/turf/previous_spot = get_turf(specimen)
		specimen.next_move_at = world.time
		specimen.process(0.7)
		TEST_ASSERT_EQUAL(get_turf(specimen), get_step(previous_spot, drive_direction), "The specimen's actual fleeing process must move it away from the researcher.")
		TEST_ASSERT(user.Move(previous_spot, drive_direction), "The herder must physically follow the specimen's previous tile.")
	TEST_ASSERT_EQUAL(get_turf(specimen), enclosure, "Actual herding must deliver the specimen four tiles from release.")
	var/turf/final_barrier = get_turf(user)
	TEST_ASSERT(user.Move(get_step(user, perpendicular), perpendicular), "The herder must leave the final doorway before closing it.")
	TEST_ASSERT(hold(panels[4]), "The researcher must select the final supplied barrier.")
	TEST_ASSERT(final_barrier.base_item_interaction(user, panels[4], list()) & ITEM_INTERACT_SUCCESS, "The actual fourth panel must close the last escape.")
	TEST_ASSERT(user.Move(get_step(user, REVERSE_DIR(drive_direction)), REVERSE_DIR(drive_direction)), "The researcher must stand outside scanning distance.")
	TEST_ASSERT(hold(lens), "The researcher must recover the actual observation lens.")
	TEST_ASSERT(specimen.base_ranged_item_interaction(user, lens, list()) & ITEM_INTERACT_SUCCESS, "The actual lens must certify the live, herded, enclosed specimen.")
	TEST_ASSERT(/datum/vestige_trial/acquisition in user.mind.completed_vestige_trials, "Real release, herding, barrier placement and scanning must finish Acquisition.")

/**
 * Clientless tests cannot answer tgui_input_list. This subtype supplies only the
 * failed-filter extraction selection; stock timing, extraction, insertion,
 * repeatable-step handling and surgery completion remain inherited.
 */
/datum/surgery_step/manipulate_organs/internal/vestige_route_selection/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	if(!(implement_type in implements_extract))
		return ..()
	var/obj/item/organ/vestige_filter/selected = target.get_organ_slot("vestige_filter")
	if(!istype(selected) || selected.functional || selected.zone != target_zone || !can_use_organ(selected) || !user.Adjacent(target) || user.get_active_held_item() != tool || (selected.organ_flags & ORGAN_UNREMOVABLE))
		return SURGERY_STEP_FAIL
	current_type = "extract"
	target_organ = selected

/datum/unit_test/vestige_biology_route/graft/Run()
	var/datum/vestige_trial/vivisection/graft = prepare(/datum/vestige_trial/vivisection)
	var/obj/item/vestige_graft_kit/dossier = loan(/obj/item/vestige_graft_kit)
	TEST_ASSERT(hold(dossier), "The researcher must select the supplied graft dossier.")
	user.setDir(NORTH)
	user.execute_mode()
	var/mob/living/carbon/human/vestige_graft_patient/patient = graft.patient
	TEST_ASSERT(patient && graft.operating_table, "The dossier must deploy its patient on a real pressurized operating table.")
	TEST_ASSERT(patient.buckled == graft.operating_table && patient.IsSleeping(), "The issued patient must be positioned for ordinary surgery.")
	TEST_ASSERT(patient.base_item_interaction(user, dossier, list()) & ITEM_INTERACT_BLOCKING, "The diagnostic input must reject the sick, unopened patient.")
	var/obj/item/organ/vestige_filter/failed = patient.get_organ_slot("vestige_filter")
	var/obj/item/organ/vestige_filter/replacement
	for(var/datum/weakref/ref as anything in graft.loan_refs)
		var/obj/item/organ/vestige_filter/filter = ref.resolve()
		if(istype(filter) && filter.functional && filter.waste_class == patient.waste_class)
			replacement = filter
	TEST_ASSERT(replacement, "The diagnosed waste class must have a matching supplied replacement.")
	var/obj/item/surgical_drapes/drapes = loan(/obj/item/surgical_drapes)
	TEST_ASSERT(hold(drapes), "The researcher must take the actual drapes from the supplied case.")
	user.zone_selected = BODY_ZONE_CHEST
	drapes.melee_attack_chain(user, patient, list())
	var/datum/component/surgery_initiator/initiator = drapes.GetComponent(/datum/component/surgery_initiator)
	TEST_ASSERT_EQUAL(initiator.surgery_target_ref?.resolve(), patient, "The actual drapes input must identify the supplied patient.")
	var/datum/surgery/selected_operation
	for(var/datum/surgery/available as anything in initiator.get_available_surgeries(user, patient))
		if(available.type == /datum/surgery/organ_manipulation)
			selected_operation = available
	TEST_ASSERT(selected_operation, "Ordinary chest Organ Manipulation must actually be offered by the drapes.")
	// The exact callback used after choosing Organ Manipulation in the drapes UI.
	initiator.try_choose_surgery(user, patient, selected_operation)
	var/datum/surgery/organ_manipulation/operation = locate() in patient.surgeries
	TEST_ASSERT(operation, "The real drapes selection callback must start the ordinary operation.")
	operation.steps = operation.steps.Copy()
	operation.steps[6] = /datum/surgery_step/manipulate_organs/internal/vestige_route_selection
	var/list/opening_tools = list(/obj/item/scalpel, /obj/item/retractor, /obj/item/circular_saw, /obj/item/hemostat, /obj/item/scalpel)
	for(var/index in 1 to 5)
		var/obj/item/tool = loan(opening_tools[index])
		TEST_ASSERT(hold(tool), "The researcher must hold the supplied tool for opening step [index].")
		TEST_ASSERT(tool.melee_attack_chain(user, patient, list()), "Actual tool dispatch must run opening step [index].")
		TEST_ASSERT_EQUAL(operation.status, index + 1, "The real opening channel must advance exactly once.")
	var/obj/item/hemostat/hemostat = loan(/obj/item/hemostat)
	TEST_ASSERT(hold(hemostat), "The researcher must select the actual extraction hemostat.")
	TEST_ASSERT(hemostat.melee_attack_chain(user, patient, list()), "Actual hemostat dispatch must extract the selected failed filter.")
	TEST_ASSERT(!failed.owner && isturf(failed.loc), "The stock extraction must put the failed organ outside the patient's body.")
	TEST_ASSERT_EQUAL(operation.status, 6, "Extraction must preserve the ordinary repeatable organ step.")
	TEST_ASSERT(hold(replacement), "The researcher must hold the diagnosed compatible replacement.")
	TEST_ASSERT(replacement.melee_attack_chain(user, patient, list()), "Actual held-organ dispatch must run the stock insertion channel.")
	TEST_ASSERT_EQUAL(replacement.owner, patient, "The compatible replacement must actually enter the patient.")
	TEST_ASSERT(replacement.surgically_installed && patient.getToxLoss() <= 5, "The actual surgical insertion hook must restore real waste clearance.")
	TEST_ASSERT(!graft.can_discharge(), "Successful insertion alone must not certify an open operation.")
	var/obj/item/cautery/cautery = loan(/obj/item/cautery)
	TEST_ASSERT(hold(cautery), "The researcher must select the actual supplied cautery.")
	TEST_ASSERT(cautery.melee_attack_chain(user, patient, list()), "Actual cautery dispatch must close the stock operation.")
	TEST_ASSERT(QDELETED(operation) && graft.surgical_closure, "The final actual cautery must complete surgery and record closure.")
	TEST_ASSERT(hold(dossier), "The researcher must return to the supplied dossier for certification.")
	TEST_ASSERT(patient.base_item_interaction(user, dossier, list()) & ITEM_INTERACT_SUCCESS, "The actual dossier must certify the recovered, closed, living specimen.")
	TEST_ASSERT(/datum/vestige_trial/vivisection in user.mind.completed_vestige_trials, "Actual deployment, ordinary surgery, organ physiology and certification must finish Graft.")
