// Tutorial checklist hooks. Part C: cyberware install and surgery hooks.
// Overrides chain with any others of the same proc; each returns the parent's value unchanged.

/// Chrome credits the body that receives it; a surgeon gets credit under Surgery instead.
/obj/item/organ/cyberimp/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(!special && organ_owner?.ckey)
		tutorial_credit(organ_owner, TUTORIAL_STEP_CHROME_INSTALL)

/obj/item/organ/eyes/robotic/cyberware/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(!special && organ_owner?.ckey)
		tutorial_credit(organ_owner, TUTORIAL_STEP_CHROME_INSTALL)

/datum/surgery_step/initiate(mob/living/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, try_to_fail = FALSE)
	tutorial_credit(user, TUTORIAL_STEP_SURGERY_START)
	return ..()

/// Credited before the parent, which qdels the surgery. Not COMSIG_MOB_SURGERY_FINISHED:
/// that fires from Destroy(), including for cancelled operations.
/datum/surgery/complete(mob/surgeon)
	tutorial_credit(surgeon, TUTORIAL_STEP_SURGERY_FINISH)
	return ..()

/// Every dissection tier inherits this step. The body's dissection_points_paid grows by
/// exactly what the notes are worth, so a rise means research was actually earned.
/datum/surgery_step/experimental_dissection/success(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	var/paid_before = target?.dissection_points_paid
	. = ..()
	if(target && target.dissection_points_paid > paid_before)
		tutorial_credit(user, TUTORIAL_STEP_SURGERY_DISSECT)

// ---- chrome-surgery: First surgery pointers, live lines and the surgery window's focus ----

/**
 * What [user] still needs on them for Tend Wounds: a scalpel, a hemostat, a cautery and a sheet
 * (anything that starts surgery: a bedsheet, drapes or a cloak). Memoised for the current tick,
 * because the step's filter asks once per candidate; fresh skips the memo.
 */
/proc/tutorial_surgery_missing(mob/living/user, fresh = FALSE)
	var/static/memo_time = -1
	var/static/list/memo = list()
	if(memo_time != world.time || fresh)
		memo_time = world.time
		memo.Cut()
	var/user_ref = REF(user)
	if(memo[user_ref])
		return memo[user_ref]
	var/scalpel = FALSE
	var/hemostat = FALSE
	var/cautery = FALSE
	var/sheet = FALSE
	if(istype(user))
		for(var/obj/item/thing in user.get_all_contents())
			switch(thing.tool_behaviour)
				if(TOOL_SCALPEL)
					scalpel = TRUE
				if(TOOL_HEMOSTAT)
					hemostat = TRUE
				if(TOOL_CAUTERY)
					cautery = TRUE
			if(!sheet && thing.GetComponent(/datum/component/surgery_initiator))
				sheet = TRUE
	var/list/missing = list()
	if(!scalpel)
		missing += "a scalpel"
	if(!hemostat)
		missing += "a hemostat"
	if(!cautery)
		missing += "a cautery"
	if(!sheet)
		missing += "a sheet"
	memo[user_ref] = missing
	return missing

/// An operation in progress that [user] is working on: on themselves or someone beside them,
/// at the body part they are aiming at. Null when there is none.
/proc/tutorial_surgery_in_reach(mob/living/user)
	if(!istype(user) || !isturf(user.loc))
		return null
	var/list/patients = list(user)
	for(var/mob/living/patient in orange(1, user))
		patients += patient
	for(var/mob/living/patient as anything in patients)
		for(var/datum/surgery/operation as anything in patient.surgeries)
			if(operation.location == user.zone_selected && operation.status <= length(operation.steps))
				return operation
	return null

/// The surgery window (SurgeryInitiator.tsx) pulses the surgery a First surgery step names, or the
/// body picker first while the surgeon isn't aiming at the chest. Both those surgeries are chest-only.
/datum/component/surgery_initiator/ui_data(mob/user)
	. = ..()
	var/focus = tutorial_ui_focus(user, "surgery")
	if(!focus)
		return
	if(user.zone_selected != BODY_ZONE_CHEST)
		focus = "surgery_chest"
	.["tutorial_focus"] = focus
	for(var/list/entry as anything in .["surgeries"])
		var/surgery_name = entry["name"]
		if(findtext(surgery_name, "Tend Wounds") == 1)
			entry["tutorial_id"] = "surgery_tend_wounds"
		else if(findtext(surgery_name, "Dissection"))
			entry["tutorial_id"] = "surgery_dissection"
