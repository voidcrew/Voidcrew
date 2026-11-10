// Tutorial checklist hook: a finished chrome execution (Cyberware item).
// The three cyberware finishers are separate engine types: the Gorilla Arms moves (/datum/hv_finisher/chrome),
// the Mantis Blades scissor and the Widowline garrote. Boss finishers and gun executions don't count.
// Hooked on the shared stop() so each line is covered; returns the parent's value unchanged.

/// The finishers that count as a cyberware execution.
GLOBAL_LIST_INIT(tutorial_chrome_finisher_types, typecacheof(list(
	/datum/hv_finisher/chrome,
	/datum/hv_finisher/garrote,
	/datum/hv_finisher/mantis_scissor,
)))

/datum/hv_finisher/stop(reason)
	// Captured first: the end callback can delete the finisher inside the parent.
	var/was_running = running
	var/mob/living/doer = user
	var/killed = completed
	. = ..()
	if(!was_running || !(killed || reason == HV_FINISHER_DONE))
		return
	if(!doer?.ckey || !GLOB.tutorial_chrome_finisher_types[type])
		return
	tutorial_credit(doer, TUTORIAL_STEP_CHROME_EXECUTE)
