/**
 * # Drug run targets & objectives
 *
 * The mission-side plumbing for the drug smuggling run (mission.dm):
 * a planet target that reports to a harvest site instead of the mission
 * shell, a space-ruin target resolved against the mission's own lab, and the
 * three mission steps (gather / cook / deliver).
 */

// =========================================================================
// INGREDIENT SITE TARGET: a planet pin that reports to its harvest site
// =========================================================================

/**
 * /datum/mission_target/planet with its callbacks rerouted: load/move/death
 * notifications go to the owning /datum/ingredient_site instead of the
 * mission shell, so three of these can ride one mission without fighting
 * over on_target_interior_loaded(). The drug run's main target stays the
 * hidden lab; these are side-pins.
 */
/datum/mission_target/planet/ingredient_site
	/// The harvest site whose callbacks we carry
	var/datum/ingredient_site/owner

/datum/mission_target/planet/ingredient_site/Destroy()
	owner = null
	return ..()

/datum/mission_target/planet/ingredient_site/on_planet_loaded(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED)
	owner?.on_site_loaded()

/// One planet of each type flies per round: a dead pin has nowhere to go (FAIL policy)
/datum/mission_target/planet/ingredient_site/on_planet_deleted(datum/source)
	SIGNAL_HANDLER
	unhook()
	owner?.on_site_lost()

/// The planet relocated after unloading: the site's helm marker follows it
/datum/mission_target/planet/ingredient_site/on_planet_moved(datum/source)
	SIGNAL_HANDLER
	if(!istype(get_turf(planet), /turf/open/overmap))
		return
	cache_coords_from(planet)
	owner?.on_site_moved()

// =========================================================================
// PRESPAWNED RUIN TARGET: aimed at a ruin the mission raised itself
// =========================================================================

/**
 * /datum/mission_target/space_ruin resolved against an injected ruin (the
 * drug run spawns its own lab) instead of scanning GLOB.space_ruin_signals.
 * Set `ruin` before calling resolve().
 */
/datum/mission_target/space_ruin/prespawned

/datum/mission_target/space_ruin/prespawned/resolve()
	if(QDELETED(ruin))
		return FALSE
	// The base candidate scan is skipped on purpose; claim and hook the
	// injected ruin exactly the way the base claims a picked one (unhook()
	// undoes both, same as the parent)
	ruin.mission_claims++
	cache_coords_from(ruin)
	RegisterSignal(ruin, COMSIG_QDELETING, PROC_REF(on_ruin_deleted))
	return TRUE

// =========================================================================
// GATHER INGREDIENTS: fill the formula's shopping list
// =========================================================================

/**
 * The shopping-list step: arms every harvest site (their scenes spawn as
 * their planets load) and completes when the last ingredient is picked up.
 * Sites report pickups to the mission, which nudges check_progress().
 */
/datum/mission_objective/gather_ingredients

/datum/mission_objective/gather_ingredients/activate()
	. = ..()
	var/datum/mission/drug_run/run = mission
	if(istype(run))
		run.arm_all_sites()

/// A site reported a pickup (via the mission): complete once all are in hand
/datum/mission_objective/gather_ingredients/proc/check_progress()
	if(completed || !active)
		return
	var/datum/mission/drug_run/run = mission
	if(!istype(run))
		return
	if(run.count_collected_sites() >= length(run.sites))
		notify_crew("Shopping list filled. Take the ingredients to the kitchen and cook.")
		complete()

/datum/mission_objective/gather_ingredients/get_progress_string()
	var/datum/mission/drug_run/run = mission
	if(!istype(run))
		return "Gather ingredients"
	return "Gather ingredients ([run.count_collected_sites()]/[length(run.sites)])"

// =========================================================================
// COOK THE BATCH: wire the lab machines to the mission's session
// =========================================================================

/**
 * The cook step: points every lab machine inside the hidden ruin at the
 * mission's /datum/drug_lab_session whenever the ruin's interior loads.
 *
 * The hook is PERSISTENT, the interior-loaded signal stays registered for
 * this objective's whole active life, so a lab that unloads and reloads gets
 * its freshly-spawned machines re-wired every time (batch state lives on the
 * session, which never unloads). Completion is single-path: the session
 * reaches DONE -> mission.on_cook_finished() -> cook.complete().
 */
/datum/mission_objective/drug_cook
	/// The lab ruin we're currently signal-hooked on
	var/obj/structure/overmap/space_ruin/hooked_ruin

/datum/mission_objective/drug_cook/activate()
	. = ..()
	var/datum/mission/drug_run/run = mission
	if(hooked_ruin || !istype(run) || QDELETED(run.lab_ruin))
		return
	hooked_ruin = run.lab_ruin
	// No unregister in the handler: every future load re-wires the fresh machines
	RegisterSignal(hooked_ruin, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_lab_loaded))
	RegisterSignal(hooked_ruin, COMSIG_QDELETING, PROC_REF(on_lab_deleted))
	if(hooked_ruin.loaded)
		wire_lab()

/datum/mission_objective/drug_cook/deactivate()
	if(hooked_ruin)
		UnregisterSignal(hooked_ruin, list(COMSIG_VOIDCREW_PLANET_LOADED, COMSIG_QDELETING))
		hooked_ruin = null
	return ..()

/// The lab's interior (re)loaded: fresh machines exist, point them at the session
/datum/mission_objective/drug_cook/proc/on_lab_loaded(datum/source)
	SIGNAL_HANDLER
	wire_lab()

/// The ruin object itself died; the mission target's loss policy handles the
/// fallout, we just stop holding a ref
/datum/mission_objective/drug_cook/proc/on_lab_deleted(datum/source)
	SIGNAL_HANDLER
	hooked_ruin = null

/**
 * Sweeps the lab site's own slot for /obj/machinery/drug_lab and points each at the
 * mission's session. Safe to call repeatedly.
 */
/datum/mission_objective/drug_cook/proc/wire_lab()
	var/datum/mission/drug_run/run = mission
	if(!istype(run) || !run.session)
		return
	// The site's rectangle, not its z-level: a packed level carries up to four sites and
	// the wide sweep would adopt a neighbouring lab's machines into this session.
	var/list/turf/lab_block = run.lab_ruin?.footprint?.get_block()
	if(!length(lab_block))
		return
	for(var/turf/tile as anything in lab_block)
		for(var/obj/machinery/drug_lab/machine in tile)
			machine.session_ref = WEAKREF(run.session)
			run.session.register_machine(machine)
	run.session.push_ui_updates()

/datum/mission_objective/drug_cook/get_progress_string()
	var/datum/mission/drug_run/run = mission
	var/datum/drug_lab_session/session = istype(run) ? run.session : null
	var/station = 1
	switch(session?.stage)
		if(DRUG_LAB_STAGE_CATALYST)
			station = 2
		if(DRUG_LAB_STAGE_CRYSTALLIZER, DRUG_LAB_STAGE_DONE)
			station = 3
	return "Cook the batch at the hidden lab (station [station]/3)"

// =========================================================================
// DELIVER THE PRODUCT: the carry-home leg
// =========================================================================

/**
 * The bound batch (printed beside the lab's crystallizer, or at the pad when
 * the lab isn't loaded) handed over the counter. The parent's binding
 * checks gate WHAT counts; the mission's can_turn_in_at() gates WHERE,
 * outpost traders only.
 */
/datum/mission_objective/deliver/bound/drug_product
	required_name = "the product"

/datum/mission_objective/deliver/bound/drug_product/describe_ask()
	var/datum/mission/drug_run/run = mission
	if(istype(run) && run.recipe)
		return "the batch of [run.recipe.street_name]"
	return required_name

/datum/mission_objective/deliver/bound/drug_product/get_progress_string()
	return "Deliver the product to Vex"
