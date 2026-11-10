/**
 * # Tutorial checklist progress
 *
 * Holds which tutorial steps each ckey has done and saves them to tg's existing
 * `tutorial_completions` table under "vc/" keys (no schema change). tg's own
 * SStutorials ignores keys it doesn't know, so the two never collide.
 *
 * Progress belongs to the ckey, not the body: death, ghosting and cryo lose nothing.
 * With no database it lives in memory for the round.
 *
 * The credit API every hook calls:
 * - tutorial_credit(mob/user, step_key)
 * - tutorial_credit_crew(obj/structure/overmap/ship/ship, step_key, aboard_only = FALSE)
 */

/// How long a ship's "is this machine aboard" scan stays cached.
#define TUTORIAL_MACHINE_CACHE_TIME (60 SECONDS)

SUBSYSTEM_DEF(vc_tutorials)
	name = "Tutorial Checklist"
	flags = SS_NO_FIRE

	/// ckey -> list(key -> TRUE). Step and item keys both live here.
	var/list/progress = list()
	/// Every checklist item singleton, sorted by category (GLOB.tutorial_categories order), then order.
	var/list/datum/vc_tutorial/items
	/// step key -> step singleton
	var/list/datum/vc_tutorial_step/steps_by_key
	/// step key -> the item singleton that owns it
	var/list/datum/vc_tutorial/item_by_step
	/// Ckeys whose saved progress has been loaded (or asked for) this round.
	var/list/loaded_ckeys = list()
	/// "[REF(ship)]|[type]" -> list(world.time, result). Keyed by ref string so no hard ref is held.
	var/list/machine_cache = list()
	/// ckey -> the item id the viewer has open in the panel. The in-game highlight reads it.
	var/list/selected = list()

/datum/controller/subsystem/vc_tutorials/Initialize()
	build_catalog()
	RegisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT, PROC_REF(on_client_connect))
	for(var/client/client as anything in GLOB.clients)
		if(client?.ckey)
			INVOKE_ASYNC(src, PROC_REF(load_progress), client.ckey)
	return SS_INIT_SUCCESS

/// Builds the item and step singletons. Safe to call more than once; callers that can run
/// before Initialize call it first.
/datum/controller/subsystem/vc_tutorials/proc/build_catalog()
	if(items)
		return
	items = list()
	steps_by_key = list()
	item_by_step = list()
	for(var/item_type in subtypesof(/datum/vc_tutorial))
		var/datum/vc_tutorial/item = new item_type
		if(!item.id)
			continue
		var/list/step_instances = list()
		for(var/step_type in item.steps)
			var/datum/vc_tutorial_step/step = new step_type
			step_instances += step
			steps_by_key[step.key] = step
			item_by_step[step.key] = item
		item.steps = step_instances
		items += item
	sortTim(items, GLOBAL_PROC_REF(cmp_vc_tutorial_order))

/// Sort helper for the checklist items: category order first, then order within it.
/proc/cmp_vc_tutorial_order(datum/vc_tutorial/a, datum/vc_tutorial/b)
	var/category_a = GLOB.tutorial_categories.Find(a.category)
	var/category_b = GLOB.tutorial_categories.Find(b.category)
	if(category_a != category_b)
		return category_a - category_b
	return a.order - b.order

/datum/controller/subsystem/vc_tutorials/proc/on_client_connect(datum/source, client/client)
	SIGNAL_HANDLER
	if(client?.ckey)
		INVOKE_ASYNC(src, PROC_REF(load_progress), client.ckey)

/// Loads a ckey's saved "vc/" keys and merges them into anything credited this round.
/datum/controller/subsystem/vc_tutorials/proc/load_progress(ckey)
	if(!ckey || loaded_ckeys[ckey])
		return
	if(!SSdbcore.IsConnected())
		return
	loaded_ckeys[ckey] = TRUE
	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT tutorial_key FROM [format_table_name("tutorial_completions")] WHERE ckey = :ckey AND tutorial_key LIKE :prefix",
		list("ckey" = ckey, "prefix" = "[TUTORIAL_KEY_PREFIX]%")
	)
	if(!query.Execute())
		qdel(query)
		loaded_ckeys -= ckey
		return
	var/list/done = progress[ckey]
	if(!done)
		done = list()
		progress[ckey] = done
	while(query.NextRow())
		var/key = query.item[1]
		if(key)
			done[key] = TRUE
	qdel(query)
	var/mob/viewer = get_mob_by_ckey(ckey)
	if(viewer)
		SStgui.try_update_ui(viewer, GLOB.tutorial_checklist)

/// Writes keys for a ckey. Duplicates are ignored by the table's unique index.
/datum/controller/subsystem/vc_tutorials/proc/save_keys(ckey, list/keys)
	if(!SSdbcore.IsConnected())
		return
	for(var/key in keys)
		var/datum/db_query/query = SSdbcore.NewQuery(
			"INSERT INTO [format_table_name("tutorial_completions")] (ckey, tutorial_key) VALUES (:ckey, :tutorial_key) ON DUPLICATE KEY UPDATE tutorial_key = tutorial_key",
			list("ckey" = ckey, "tutorial_key" = key)
		)
		query.warn_execute()
		qdel(query)

/// TRUE if the ckey has this key (step or item).
/datum/controller/subsystem/vc_tutorials/proc/has_key(ckey, key)
	var/list/done = progress[ckey]
	return !!done?[key]

/// TRUE if the item is complete for this viewer: its item key is saved, or every
/// counted step (not optional, not excused for them) is done.
/datum/controller/subsystem/vc_tutorials/proc/item_complete(datum/vc_tutorial/item, ckey, mob/user)
	var/list/done = progress[ckey]
	if(!done)
		return FALSE
	if(done[item.id])
		return TRUE
	for(var/datum/vc_tutorial_step/step as anything in item.steps)
		if(step.optional || done[step.key])
			continue
		if(step.route_excused(ckey))
			continue
		if(user && step.excused(user))
			continue
		return FALSE
	return TRUE

/**
 * The item the panel suggests next for this viewer: the first incomplete item, in panel
 * order, with a counted step left that is neither excused nor marked unavailable for them.
 * Returns the item id, or null.
 */
/datum/controller/subsystem/vc_tutorials/proc/suggested_item(ckey, mob/user)
	build_catalog()
	var/list/done = progress[ckey]
	for(var/datum/vc_tutorial/item as anything in items)
		if(item_complete(item, ckey, user))
			continue
		for(var/datum/vc_tutorial_step/step as anything in item.steps)
			if(step.optional || done?[step.key] || step.route_excused(ckey))
				continue
			if(user && (step.excused(user) || step.availability(user)))
				continue
			return item.id
	return null

/// TRUE if every item is complete for this viewer.
/datum/controller/subsystem/vc_tutorials/proc/all_complete(ckey, mob/user)
	build_catalog()
	for(var/datum/vc_tutorial/item as anything in items)
		if(!item_complete(item, ckey, user))
			return FALSE
	return TRUE

/// Marks a step for a ckey. Returns TRUE if it was newly marked.
/datum/controller/subsystem/vc_tutorials/proc/credit_ckey(ckey, step_key, mob/user)
	build_catalog()
	var/list/done = progress[ckey]
	if(!done)
		done = list()
		progress[ckey] = done
	if(done[step_key])
		return FALSE
	done[step_key] = TRUE
	var/list/to_save = list(step_key)
	var/datum/vc_tutorial/item = item_by_step[step_key]
	if(item && !done[item.id] && item_complete(item, ckey, user))
		done[item.id] = TRUE
		to_save += item.id
	if(SSdbcore.IsConnected())
		INVOKE_ASYNC(src, PROC_REF(save_keys), ckey, to_save)
	var/mob/viewer = user?.client ? user : get_mob_by_ckey(ckey)
	if(viewer)
		SStgui.try_update_ui(viewer, GLOB.tutorial_checklist)
		tutorial_refresh_highlights(viewer)
	return TRUE

/// Whether a machine of this type is aboard the ship, cached for TUTORIAL_MACHINE_CACHE_TIME
/// because get_ship_machines() walks every area's contents.
/datum/controller/subsystem/vc_tutorials/proc/ship_has_machine(obj/structure/overmap/ship/ship, machine_type)
	if(QDELETED(ship))
		return FALSE
	var/cache_key = "[REF(ship)]|[machine_type]"
	var/list/cached = machine_cache[cache_key]
	if(cached && world.time < cached[1] + TUTORIAL_MACHINE_CACHE_TIME)
		return cached[2]
	var/result = length(ship.get_ship_machines(machine_type)) > 0
	machine_cache[cache_key] = list(world.time, result)
	return result

/**
 * Credits a tutorial step to a player. Returns TRUE if it was newly credited.
 * Cheap when the step is already done: one assoc lookup.
 */
/proc/tutorial_credit(mob/user, step_key)
	if(!user || !step_key)
		return FALSE
	var/ckey = user.ckey || ckey(user.mind?.key)
	if(!ckey)
		return FALSE
	var/list/done = SSvc_tutorials.progress[ckey]
	if(done?[step_key])
		return FALSE
	return SSvc_tutorials.credit_ckey(ckey, step_key, user)

/**
 * Credits a step to every member of a ship's crew, through their current bodies.
 * With aboard_only, only members whose body is aboard that ship.
 */
/proc/tutorial_credit_crew(obj/structure/overmap/ship/ship, step_key, aboard_only = FALSE)
	if(!ship?.ship_team || !step_key)
		return
	for(var/datum/mind/member as anything in ship.ship_team.members)
		var/mob/body = member?.current
		if(!body)
			continue
		if(aboard_only && get_ship_from_atom(body) != ship)
			continue
		tutorial_credit(body, step_key)

// ---------------------------------------------------------------------------
// Ship signals: dock, undock, land, survey
// ---------------------------------------------------------------------------

/obj/structure/overmap/ship/Initialize(mapload, datum/map_template/shuttle/voidcrew/template)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL || istype(src, /obj/structure/overmap/ship/npc))
		return
	RegisterSignal(src, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(tutorial_on_docked))
	RegisterSignal(src, COMSIG_VOIDCREW_SHIP_UNDOCKED, PROC_REF(tutorial_on_undocked))
	RegisterSignal(src, COMSIG_VOIDCREW_SURVEY_COMPLETED, PROC_REF(tutorial_on_survey))

/obj/structure/overmap/ship/proc/tutorial_on_docked(datum/source)
	SIGNAL_HANDLER
	// A checkpoint rebuild also sends DOCKED; only a real berth counts.
	if(!docked)
		return
	tutorial_credit_crew(src, TUTORIAL_STEP_SHIP_DOCK, aboard_only = TRUE)
	if(istype(docked, /obj/structure/overmap/planet) && !istype(docked, /obj/structure/overmap/planet/empty))
		tutorial_credit_crew(src, TUTORIAL_STEP_RUIN_LAND, aboard_only = TRUE)
	// Trader outposts only: the trade steps after this one (elevator, shops) are theirs.
	else if(istype(docked, /obj/structure/overmap/trader_outpost))
		tutorial_credit_crew(src, TUTORIAL_STEP_TRADE_TRAVEL, aboard_only = TRUE)

/obj/structure/overmap/ship/proc/tutorial_on_undocked(datum/source)
	SIGNAL_HANDLER
	// Also sent while a derelict hull is being deleted; nobody flew that.
	if(QDELETED(src))
		return
	tutorial_credit_crew(src, TUTORIAL_STEP_SHIP_UNDOCK, aboard_only = TRUE)

/obj/structure/overmap/ship/proc/tutorial_on_survey(datum/source, celestial_type)
	SIGNAL_HANDLER
	tutorial_credit_crew(src, TUTORIAL_STEP_SURVEYS_SURVEY)

#undef TUTORIAL_MACHINE_CACHE_TIME
