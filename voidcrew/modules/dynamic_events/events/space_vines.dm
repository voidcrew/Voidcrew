/**
 * Ship-scoped port of TG's Space Vines (code/modules/events/space_vines/vine_event.dm).
 *
 * Kudzu takes root somewhere aboard the target ship and spreads from there. The event
 * itself is nearly the whole original. Pick a floor, roll a mutation, hand it to a
 * /datum/spacevine_controller, with two changes:
 *
 * 1. TG seeds into `/area/station/hallway`, which does not exist here. The seed goes on
 *    any open floor aboard instead.
 * 2. The controller is a ship-scoped subtype. Vines already refuse to spread into space
 *    (see /obj/structure/spacevine/proc/spread), which contains them perfectly well on a
 *    flying ship, the vacuum is the wall. It stops containing them the moment the crew
 *    docks at a ruin or an outpost and opens the airlock, and kudzu that gets into a
 *    never-unloading trader outpost is there for the rest of the round. The subtype below
 *    culls anything that ends up off-hull.
 */
/datum/round_event_control/voidcrew/spacevine
	name = "Space Vines"
	typepath = /datum/round_event/voidcrew/spacevine
	weight = 5
	max_occurrences = 2
	earliest_start = 15 MINUTES
	category = EVENT_CATEGORY_ENTITIES
	description = "Kudzu takes root aboard the target ship."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	/// Kudzu is fought by cutting a path through it, which means there has to be a path.
	/// On a one-room hull the first spread tick is already on top of the crew.
	min_ship_mass = SHIP_MASS_MEDIUM
	min_wizard_trigger_potency = 4
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/spacevine
	fakeable = FALSE
	/// Potency of the spawned kudzu (mutation frequency and severity ceiling).
	var/potency
	/// Production of the spawned kudzu: lower spreads faster.
	var/production

/datum/round_event/voidcrew/spacevine/start()
	if(!target_valid())
		return

	// The original tests candidate floors with Enter() against a throwaway vine so it
	// never seeds somewhere a vine cannot actually exist. Worth keeping.
	var/obj/structure/spacevine/probe = new()
	var/list/turfs = list()
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/turf/open/floor/candidate in ship_area)
			if(isopenspaceturf(candidate))
				continue
			if(candidate.Enter(probe))
				turfs += candidate
	qdel(probe)

	if(!length(turfs))
		return

	var/turf/floor = pick(turfs)
	var/list/selected_mutations = list(pick(subtypesof(/datum/spacevine_mutation)))
	if(isnull(potency))
		// Tuned down from TG's rand(50, 100). Potency drives mutation severity, and the
		// nastier mutations (toxicity, aggressive spread) are balanced against a station's
		// worth of people and space to answer them with.
		potency = rand(30, 70)
	if(isnull(production))
		// Slower than TG's rand(1, 4): lower production spreads faster, and a ship is
		// small enough that fast kudzu covers the whole thing before anyone finds a hoe.
		production = rand(3, 6)

	var/datum/spacevine_controller/ship_scoped/controller = new(floor, selected_mutations, potency, production, src)
	controller.ship_ref = WEAKREF(target_ship)

/datum/round_event/voidcrew/spacevine/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"Unidentified plant growth detected aboard. Recommend immediate removal before it takes the compartment.",
		"Biohazard Alert",
	)

/**
 * A vine controller that keeps its growth on one ship.
 *
 * The cull runs on the controller rather than on spread(), because spread() dereferences
 * whatever spawn_spacevine_piece() returns without a null check, refusing to create the
 * piece there would runtime. Letting the piece exist for one tick and removing it after
 * is uglier in principle and considerably safer in practice.
 */
/datum/spacevine_controller/ship_scoped
	/// The ship this infestation belongs to.
	var/datum/weakref/ship_ref

/datum/spacevine_controller/ship_scoped/process(seconds_per_tick)
	// The controller starts processing inside its own New(), before the event has had a
	// chance to tell it which ship it belongs to. An unadopted controller must not read
	// that as "my ship is gone" and delete itself on its first tick.
	if(!ship_ref)
		return ..()

	var/obj/structure/overmap/ship/ship = ship_ref.resolve()
	// No ship left to be aboard of. The hull was destroyed or abandoned with us on it.
	if(QDELETED(ship) || !ship.shuttle)
		DeleteVines()
		return

	for(var/obj/structure/spacevine/vine as anything in vines.Copy())
		if(!ship.is_aboard(vine))
			qdel(vine)

	// The last vine dying takes the controller with it (see VineDestroyed).
	if(QDELETED(src) || !length(vines))
		return
	return ..()
