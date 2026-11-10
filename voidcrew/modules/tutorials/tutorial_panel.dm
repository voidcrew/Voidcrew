/**
 * # Tutorial checklist panel
 *
 * One tgui window per viewer (TutorialChecklist). It opens by itself 4 s after every
 * spawn unless the player turned that off, closed it this round, or has every item
 * done. The "Tutorials" OOC verb opens it any time, ghosts included.
 *
 * Its only action is the "open on spawn" preference. It takes no refs and never acts
 * on the world.
 */

/// Gap between spawning and the checklist opening, so it lands after the client has
/// loaded into its body.
#define TUTORIAL_CHECKLIST_DELAY (4 SECONDS)

/// Ckeys who closed the checklist this round. It stays shut for them until next round.
GLOBAL_LIST_EMPTY(tutorial_checklist_hidden)

/// One datum for the whole server; tgui keys windows on (user, datum).
GLOBAL_DATUM_INIT(tutorial_checklist, /datum/tutorial_checklist, new)

/datum/tutorial_checklist

/datum/tutorial_checklist/ui_state(mob/user)
	return GLOB.always_state

/datum/tutorial_checklist/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		run_state_checks(user)
		ui = new(user, src, "TutorialChecklist")
		// Credits push updates themselves (SStgui.try_update_ui), so the window
		// doesn't need to rebuild its notes every tick.
		ui.set_autoupdate(FALSE)
		ui.open()

/// Credits steps the viewer has already done but no hook saw.
/datum/tutorial_checklist/proc/run_state_checks(mob/user)
	var/ckey = tutorial_viewer_ckey(user)
	if(!ckey)
		return
	SSvc_tutorials.build_catalog()
	for(var/key in SSvc_tutorials.steps_by_key)
		if(SSvc_tutorials.has_key(ckey, key))
			continue
		var/datum/vc_tutorial_step/step = SSvc_tutorials.steps_by_key[key]
		if(step.state_satisfied(user))
			tutorial_credit(user, key)

/datum/tutorial_checklist/ui_static_data(mob/user)
	SSvc_tutorials.build_catalog()
	var/list/items = list()
	for(var/datum/vc_tutorial/item as anything in SSvc_tutorials.items)
		var/list/steps = list()
		for(var/datum/vc_tutorial_step/step as anything in item.steps)
			steps += list(list(
				"key" = step.key,
				"name" = step.name,
				"text" = step.text,
				"optional" = step.optional,
			))
		items += list(list(
			"id" = item.id,
			"name" = item.name,
			"steps" = steps,
		))
	return list("items" = items)

/datum/tutorial_checklist/ui_data(mob/user)
	var/list/data = list()
	var/ckey = tutorial_viewer_ckey(user)
	var/list/done_keys = list()
	var/list/notes = list()
	var/list/excused = list()
	var/list/progress = ckey ? SSvc_tutorials.progress[ckey] : null
	for(var/key in progress)
		done_keys += key
	for(var/key in SSvc_tutorials.steps_by_key)
		if(progress?[key])
			continue
		var/datum/vc_tutorial_step/step = SSvc_tutorials.steps_by_key[key]
		var/note = step.availability(user)
		if(note)
			notes[key] = note
		if(step.excused(user))
			excused += key
	data["done"] = done_keys
	data["notes"] = notes
	data["excused"] = excused
	data["spawn_open"] = user.client?.prefs ? !!user.client.prefs.read_preference(/datum/preference/toggle/tutorial_checklist) : TRUE
	return data

/datum/tutorial_checklist/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("toggle_spawn_open")
			var/datum/preferences/prefs = ui.user.client?.prefs
			if(!prefs)
				return FALSE
			var/datum/preference/toggle/tutorial_checklist/pref = GLOB.preference_entries[/datum/preference/toggle/tutorial_checklist]
			prefs.write_preference(pref, !prefs.read_preference(/datum/preference/toggle/tutorial_checklist))
			return TRUE

/datum/tutorial_checklist/ui_close(mob/user)
	. = ..()
	var/ckey = tutorial_viewer_ckey(user)
	if(ckey)
		GLOB.tutorial_checklist_hidden |= ckey

/// The ckey whose progress a viewer sees.
/proc/tutorial_viewer_ckey(mob/user)
	return user?.ckey || ckey(user?.mind?.key)

/**
 * Opens the checklist 4 s after a spawn, if the player wants it and still has
 * something left to do. Called from the spawn paths.
 */
/proc/try_show_tutorial_checklist(mob/user)
	if(!user?.client)
		return
	var/ckey = tutorial_viewer_ckey(user)
	if(!ckey || (ckey in GLOB.tutorial_checklist_hidden))
		return
	if(!user.client.prefs?.read_preference(/datum/preference/toggle/tutorial_checklist))
		return
	if(SSvc_tutorials.all_complete(ckey, user))
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(show_tutorial_checklist), user), TUTORIAL_CHECKLIST_DELAY)

/// Timer landing point for try_show_tutorial_checklist().
/proc/show_tutorial_checklist(mob/user)
	if(!user?.client)
		return
	if(tutorial_viewer_ckey(user) in GLOB.tutorial_checklist_hidden)
		return
	GLOB.tutorial_checklist.ui_interact(user)

/client/verb/tutorial_checklist()
	set name = "Tutorials"
	set category = "OOC"
	set desc = "Open the tutorial checklist."
	if(!mob)
		return
	GLOB.tutorial_checklist.ui_interact(mob)

#undef TUTORIAL_CHECKLIST_DELAY
