/**
 * Ship-scoped port of TG's anomaly random-event family.
 *
 * Each event selects one open floor turf from its target ship, announces the
 * containing area to that ship's crew, and spawns the upstream anomaly object
 * only if the selected turf still belongs to the target ship.
 *
 * ALL OF THESE ARE ADMIN-ONLY. Every control below is weight 0 / max_occurrences 0, and
 * none of them roll naturally. Anomalies now generate on planet surfaces instead, see
 * voidcrew/datums/mapgen/planet_anomalies.dm and the ZONE_PLANET_ANOMALY_BUDGET_* defines.
 *
 * The reason is that a shuttle is the worst possible venue for one. A ship has a single
 * route between compartments, so an anomaly spawned in a corridor is not a hazard the
 * crew can route around. It is a toll on reaching engineering, payable in burns, for as
 * long as the event runs. The crew did nothing to invite it and can do nothing to end it
 * short of a neutralizer they probably have not researched yet.
 *
 * On open planet ground the identical object reads as content: stationary, lit, visible
 * from outside its reach, and encountered only because somebody walked toward it. The
 * code here is kept intact so admins can still place one deliberately.
 */
/datum/round_event_control/voidcrew/anomaly
	name = "Anomaly: Energetic Flux"
	typepath = /datum/round_event/voidcrew/anomaly
	min_players = 1
	max_occurrences = 0
	// Abstract base: subtypes carry real weights. A non-zero weight here would sit
	// in the weighted roster draining rolls onto an event that can never fire.
	weight = 0
	category = EVENT_CATEGORY_ANOMALIES
	description = "This anomaly shocks and explodes. This is the base type."
	allowed_zones = list(ZONE_RED)
	/// Every anomaly needs floor to be walked away from. Subtypes that eat or ignite the
	/// hull raise this further.
	min_ship_mass = SHIP_MASS_SMALL

/datum/round_event_control/voidcrew/anomaly/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	return !isnull(ship.get_random_open_ship_turf())

/** Base event that resolves and spawns one anomaly strictly aboard its target ship. */
/datum/round_event/voidcrew/anomaly
	start_when = ANOMALY_START_HARMFUL_TIME
	announce_when = ANOMALY_ANNOUNCE_HARMFUL_TIME
	// Our announcement names the area the anomaly picked, which setup() chooses. False
	// Alarm builds its borrowed event without ever calling setup(), so a faked anomaly
	// has no spawn turf and announce() bails on the first line. It would burn a False
	// Alarm occurrence and say nothing at all.
	fakeable = FALSE
	/// Area containing the selected spawn turf, used for the rough-location warning.
	var/area/impact_area
	/// Open floor turf selected from the target ship during setup.
	var/turf/spawn_location
	/// Upstream anomaly object type to create.
	var/obj/effect/anomaly/anomaly_path = /obj/effect/anomaly/flux
	/// Flavor text placed before the common ship-local location warning.
	var/announcement_text = "Energetic flux wave"
	/// Optional advice appended to the location warning.
	var/announcement_suffix = ""
	/// Optional announcer sound key.
	var/announcement_sound

/datum/round_event/voidcrew/anomaly/setup()
	if(!target_valid())
		return
	spawn_location = target_ship.get_random_open_ship_turf()
	if(!spawn_location)
		return
	impact_area = get_area(spawn_location)
	if(!impact_area)
		spawn_location = null

/datum/round_event/voidcrew/anomaly/announce(fake)
	if(!target_valid())
		return
	if(QDELETED(spawn_location) || !impact_area || !target_ship.is_aboard(spawn_location))
		return
	target_ship.ship_event_announce("[announcement_text] detected aboard the vessel in [impact_area.name].[announcement_suffix]", "Anomaly Alert", announcement_sound)

/datum/round_event/voidcrew/anomaly/start()
	if(!target_valid())
		return
	if(QDELETED(spawn_location) || !impact_area || !target_ship.is_aboard(spawn_location))
		return
	var/obj/effect/anomaly/new_anomaly = new anomaly_path(spawn_location)
	if(QDELETED(new_anomaly))
		return
	apply_anomaly_properties(new_anomaly)
	announce_to_ghosts(new_anomaly)

/// Applies subtype-specific state after the anomaly object has been created.
/datum/round_event/voidcrew/anomaly/proc/apply_anomaly_properties(obj/effect/anomaly/new_anomaly)
	return

/// Biologic anomaly that swaps the limbs of nearby unprotected creatures.
/datum/round_event_control/voidcrew/anomaly/anomaly_bioscrambler
	name = "Anomaly: Bioscrambler"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_bioscrambler
	min_players = 1
	// Admin-only. The announcement names a compartment, but the anomaly wanders out of it
	// and a swapped limb needs surgery to put right. The crew eats a permanent injury for
	// walking down the wrong corridor. Every other anomaly's damage ends when it does.
	max_occurrences = 0
	weight = 0
	description = "This anomaly replaces the limbs of nearby people."
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 2
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)

/datum/round_event/voidcrew/anomaly/anomaly_bioscrambler
	start_when = ANOMALY_START_MEDIUM_TIME
	announce_when = ANOMALY_ANNOUNCE_MEDIUM_TIME
	anomaly_path = /obj/effect/anomaly/bioscrambler
	announcement_text = "Biologic limb-swapping agent"
	announcement_suffix = " Wear biosuits or other protective gear to counter the effects."

/// Bluespace anomaly that teleports nearby atoms.
/datum/round_event_control/voidcrew/anomaly/anomaly_bluespace
	name = "Anomaly: Bluespace"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_bluespace
	max_occurrences = 0
	weight = 0
	description = "This anomaly randomly teleports all items and mobs in a large area."
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 2
	allowed_zones = null

/datum/round_event/voidcrew/anomaly/anomaly_bluespace
	start_when = ANOMALY_START_MEDIUM_TIME
	announce_when = ANOMALY_ANNOUNCE_MEDIUM_TIME
	anomaly_path = /obj/effect/anomaly/bluespace
	announcement_text = "Bluespace instability"

/// Dimensional anomaly that changes nearby materials.
/datum/round_event_control/voidcrew/anomaly/anomaly_dimensional
	name = "Anomaly: Dimensional"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_dimensional
	min_players = 1
	max_occurrences = 0
	weight = 0
	description = "This anomaly replaces the materials of the surrounding area."
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 2
	allowed_zones = null

/datum/round_event/voidcrew/anomaly/anomaly_dimensional
	start_when = ANOMALY_START_MEDIUM_TIME
	announce_when = ANOMALY_ANNOUNCE_MEDIUM_TIME
	anomaly_path = /obj/effect/anomaly/dimensional
	announcement_text = "Dimensional instability"
	/// Optional initial dimension theme override, retained for manual configuration.
	var/anomaly_theme

/datum/round_event/voidcrew/anomaly/anomaly_dimensional/apply_anomaly_properties(obj/effect/anomaly/dimensional/new_anomaly)
	if(!anomaly_theme)
		return
	new_anomaly.prepare_area(new_theme_path = anomaly_theme)

/// Paranormal anomaly whose effect scales with its orbiting ghosts.
/datum/round_event_control/voidcrew/anomaly/anomaly_ectoplasm
	name = "Anomaly: Ectoplasmic Outburst"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_ectoplasm
	min_players = 2
	max_occurrences = 0
	weight = 0
	description = "Anomaly that produces an effect of varying intensity based on how many ghosts are orbiting it."
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 3
	allowed_zones = null

/datum/round_event/voidcrew/anomaly/anomaly_ectoplasm
	start_when = ANOMALY_START_HARMFUL_TIME
	announce_when = ANOMALY_ANNOUNCE_HARMFUL_TIME
	anomaly_path = /obj/effect/anomaly/ectoplasm
	announcement_text = "Paranormal ectoplasmic outburst"
	/// Optional impact power override, retained for manual configuration.
	var/effect_override
	/// Optional simulated orbiting-ghost count, retained for manual configuration.
	var/orbit_override

/datum/round_event/voidcrew/anomaly/anomaly_ectoplasm/apply_anomaly_properties(obj/effect/anomaly/ectoplasm/new_anomaly)
	if(!effect_override || !orbit_override)
		return
	new_anomaly.override_ghosts = TRUE
	new_anomaly.effect_power = effect_override
	new_anomaly.ghosts_orbiting = orbit_override
	new_anomaly.intensity_update()

/// Hyper-energetic anomaly that shocks and explodes.
/datum/round_event_control/voidcrew/anomaly/anomaly_flux
	name = "Anomaly: Hyper-Energetic Flux"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_flux
	min_players = 1
	max_occurrences = 0
	weight = 0
	description = "This anomaly shocks and explodes."
	min_wizard_trigger_potency = 1
	max_wizard_trigger_potency = 4
	allowed_zones = list(ZONE_RED)

/datum/round_event/voidcrew/anomaly/anomaly_flux
	start_when = ANOMALY_START_DANGEROUS_TIME
	announce_when = ANOMALY_ANNOUNCE_DANGEROUS_TIME
	anomaly_path = /obj/effect/anomaly/flux
	announcement_text = "Hyper-energetic flux wave"

/// Gravitational anomaly that throws nearby atoms around.
/datum/round_event_control/voidcrew/anomaly/anomaly_grav
	name = "Anomaly: Gravitational"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_grav
	max_occurrences = 0
	weight = 0
	description = "This anomaly throws things around."
	min_wizard_trigger_potency = 1
	max_wizard_trigger_potency = 3
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)

/datum/round_event/voidcrew/anomaly/anomaly_grav
	start_when = ANOMALY_START_HARMFUL_TIME
	announce_when = ANOMALY_ANNOUNCE_HARMFUL_TIME
	anomaly_path = /obj/effect/anomaly/grav
	announcement_text = "Gravitational anomaly"
	announcement_sound = ANNOUNCER_GRANOMALIES

/// Rare high-intensity gravitational variant from TG.
/datum/round_event_control/voidcrew/anomaly/anomaly_grav/high
	name = "Anomaly: Gravitational (High Intensity)"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_grav/high
	weight = 0
	max_occurrences = 0
	earliest_start = 20 MINUTES
	description = "This anomaly has an intense gravitational field, and can disable the gravity generator."

/datum/round_event/voidcrew/anomaly/anomaly_grav/high
	start_when = ANOMALY_START_HARMFUL_TIME
	announce_when = ANOMALY_ANNOUNCE_HARMFUL_TIME
	anomaly_path = /obj/effect/anomaly/grav/high

/// Hallucinatory anomaly that distorts the perceptions of nearby creatures.
/datum/round_event_control/voidcrew/anomaly/anomaly_hallucination
	name = "Anomaly: Hallucination"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_hallucination
	min_players = 1
	max_occurrences = 0
	weight = 0
	description = "This anomaly causes you to hallucinate."
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 2
	allowed_zones = null

/datum/round_event/voidcrew/anomaly/anomaly_hallucination
	start_when = ANOMALY_START_MEDIUM_TIME
	announce_when = ANOMALY_ANNOUNCE_MEDIUM_TIME
	anomaly_path = /obj/effect/anomaly/hallucination
	announcement_text = "Hallucinatory event"

/// Pyroclastic anomaly that ignites its surroundings.
/datum/round_event_control/voidcrew/anomaly/anomaly_pyro
	name = "Anomaly: Pyroclastic"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_pyro
	max_occurrences = 0
	weight = 0
	description = "This anomaly sets things on fire, and creates a pyroclastic slime."
	min_wizard_trigger_potency = 1
	max_wizard_trigger_potency = 4
	allowed_zones = list(ZONE_RED)
	/// A fire needs somewhere to be fought from. On a small hull the whole ship is the fire.
	min_ship_mass = SHIP_MASS_MEDIUM

/datum/round_event/voidcrew/anomaly/anomaly_pyro
	start_when = ANOMALY_START_HARMFUL_TIME
	announce_when = ANOMALY_ANNOUNCE_HARMFUL_TIME
	anomaly_path = /obj/effect/anomaly/pyro
	announcement_text = "Pyroclastic anomaly"

/// Vortex anomaly that pulls in and detonates nearby items.
/datum/round_event_control/voidcrew/anomaly/anomaly_vortex
	name = "Anomaly: Vortex"
	typepath = /datum/round_event/voidcrew/anomaly/anomaly_vortex
	min_players = 2
	// Admin-only. It eats whatever it reaches, crew and cargo alike, and there is nothing
	// to do about it but be elsewhere, which the announcement does not give you time for.
	max_occurrences = 0
	weight = 0
	description = "This anomaly sucks in and detonates items."
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 7
	allowed_zones = list(ZONE_RED)
	/// This one detonates what it pulls in and takes hull with it. A small ship does not
	/// survive to the point where the crew could do anything about it.
	min_ship_mass = SHIP_MASS_MEDIUM

/datum/round_event/voidcrew/anomaly/anomaly_vortex
	start_when = ANOMALY_START_DANGEROUS_TIME
	announce_when = ANOMALY_ANNOUNCE_DANGEROUS_TIME
	anomaly_path = /obj/effect/anomaly/bhole
	announcement_text = "Localized high-intensity vortex anomaly"
