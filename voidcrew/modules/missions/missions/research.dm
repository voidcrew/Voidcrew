/**
 * # Research Contracts
 *
 * The science branch of the mission board: contracts posted by research
 * institutes that pay in RESEARCH POINTS rather than credits. The payout is a
 * physical dossier dropped at the turn-in point (the mission shell's
 * research_reward channel); somebody has to walk it to an R&D console and slot
 * it in before it becomes anything.
 *
 * Three asks, one per layer of the game:
 *
 * - TELEMETRY: pure ship work. Feed the orbital survey console a quota of
 *   celestial scans. No target, no landing, no combat - the science contract a
 *   crew can run while flying somewhere else.
 * - CONTAINMENT: a stabilized anomaly is manifested inside a space ruin and it
 *   will not expire on its own. Neutralizing it is the upstream anomaly loop -
 *   read the field with an analyzer, dial that frequency and code into a
 *   signaler, trigger it - and the core it sheds is the turn-in item. This is
 *   the only contract that hands out anomaly cores, so it also respects
 *   SSresearch's per-type core cap at generation.
 * - CORE SAMPLE: planetside stratigraphy on the pylon-chain pipeline. Three
 *   drill probes, each calibration loud enough to draw a wave, and the last one
 *   prints the sample cask.
 */

/**
 * Shared base: institute authorship and the research archetype. Never rolled
 * itself (weight 0).
 */
/datum/mission/research
	name = "Research Contract"
	research_origin = "field work"

/datum/mission/research/get_archetype()
	return "research"

/datum/mission/research/generate_mission_author()
	var/static/list/titles = list("Dr.", "Prof.", "Dir.", "Reader")
	var/static/list/surnames = list(
		"Aldrete", "Beck", "Cavanaugh", "Duval", "Erskine", "Fenwick",
		"Ganzorig", "Holloway", "Ishikawa", "Jarrah", "Kowalczyk", "Lindqvist",
	)
	var/static/list/institutes = list(
		"Helios Institute",
		"Vanguard Applied Sciences",
		"the Meridian Survey Board",
		"Kepler-Ross Laboratories",
		"the Outer Reach Physics Consortium",
		"Thule Analytical",
	)
	return "[pick(titles)] [pick(surnames)], [pick(institutes)]"

// =========================================================================
// TELEMETRY CONTRACT: survey console quota, paid in points
// =========================================================================

/**
 * The scan-quota ask again, but the client wants the raw telemetry rather than
 * a chart update, so it pays in points with credits as an expenses stipend.
 * Like /datum/mission/survey this type has no overmap target, so the zone
 * table never fires and the ask table below carries pay and difficulty itself.
 */
/datum/mission/research/telemetry
	name = "Telemetry Contract"
	weight = 9
	mission_limit = 2
	research_origin = "astrometry"
	value_min = 200
	value_max = 350

	/// The rolled ask (kept for UI keys)
	var/target_type = "any"
	var/target_name = "celestial objects"
	var/target_name_singular = "celestial object"
	var/required_amount = 3
	/// The scan objective, for UI progress keys
	var/datum/mission_objective/scan_celestial/scan

/datum/mission/research/telemetry/Destroy()
	scan = null
	return ..()

/datum/mission/research/telemetry/generate_details()
	// Types match the keys from survey_research.survey_objects_by_type
	var/static/list/telemetry_asks = list(
		list("type" = "nebulas", "name" = "nebulas", "name_singular" = "nebula", "amount" = 2, "research" = 600, "value_min" = 150, "value_max" = 250, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = "asteroids", "name" = "asteroid fields", "name_singular" = "asteroid field", "amount" = 2, "research" = 650, "value_min" = 150, "value_max" = 250, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = "any", "name" = "celestial objects", "name_singular" = "celestial object", "amount" = 3, "research" = 700, "value_min" = 200, "value_max" = 300, "difficulty" = MISSION_DIFFICULTY_EASY),
		list("type" = "planets", "name" = "planets", "name_singular" = "planet", "amount" = 2, "research" = 1200, "value_min" = 300, "value_max" = 450, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = "space_ruins", "name" = "space ruins", "name_singular" = "space ruin", "amount" = 2, "research" = 1200, "value_min" = 300, "value_max" = 450, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = "electric_storms", "name" = "electrical storms", "name_singular" = "electrical storm", "amount" = 2, "research" = 1150, "value_min" = 300, "value_max" = 450, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = "emp_storms", "name" = "EMP storms", "name_singular" = "EMP storm", "amount" = 2, "research" = 1900, "value_min" = 450, "value_max" = 700, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = "stars", "name" = "stars", "name_singular" = "star", "amount" = 1, "research" = 2000, "value_min" = 450, "value_max" = 700, "difficulty" = MISSION_DIFFICULTY_HARD),
	)

	var/list/ask = pick(telemetry_asks)
	target_type = ask["type"]
	target_name = ask["name"]
	target_name_singular = ask["name_singular"]
	required_amount = ask["amount"]
	research_reward = ask["research"]
	value_min = ask["value_min"]
	value_max = ask["value_max"]
	difficulty = ask["difficulty"]

/datum/mission/research/telemetry/build_objectives()
	scan = new
	scan.target_type = target_type
	scan.target_name = target_name
	scan.target_name_singular = target_name_singular
	scan.required_amount = required_amount
	add_objective(scan)

/datum/mission/research/telemetry/update_text()
	var/display_name = required_amount == 1 ? target_name_singular : target_name
	name = "Telemetry Contract: [display_name]"
	desc = "Run [required_amount] [display_name] through the orbital survey console and forward us the raw telemetry. \
		Nothing to bring back - the contract settles at the mission board. \
		Pays [research_reward] research points as a data dossier, plus [value] credits in expenses. \
		Slot the dossier into an R&D console to bank the points."

/datum/mission/research/telemetry/get_ui_data()
	var/list/data = ..()
	data["target_type"] = target_type
	data["target_name"] = target_name
	data["required_amount"] = required_amount
	data["current_amount"] = scan ? scan.current_amount : 0
	return data

// =========================================================================
// CONTAINMENT CONTRACT: put an anomaly down, bring back its core
// =========================================================================

/datum/mission/research/containment
	name = "Containment Contract"
	weight = 6
	mission_limit = 1
	// The analyzer/signaler dance on top of the flight out; the standard half
	// hour is tight for a crew meeting the loop for the first time.
	duration = 35 MINUTES
	quest_lost_policy = MISSION_QUEST_LOST_RETARGET
	gps_tag_prefix = "ANOM"
	research_origin = "anomalous physics"
	// Green band; the zone table scales it, then the anomaly's own hazard
	// multiplier is applied on top in generate_details().
	value_min = 500
	value_max = 800
	research_reward = 1600

	/// Display name of the rolled anomaly ("flux anomaly")
	var/anomaly_name = "anomaly"
	/// One-line warning about what this anomaly does to people, for the board
	var/hazard_brief = ""
	/// Anomaly typepath manifested at the site
	var/anomaly_type
	/// Core typepath its neutralization sheds
	var/core_type

/datum/mission/research/containment/setup_target()
	var/datum/mission_target/space_ruin/ruin_target = new(src)
	if(!ruin_target.resolve())
		qdel(ruin_target)
		return FALSE
	target = ruin_target
	return TRUE

/datum/mission/research/containment/generate_details()
	// Curated set: everything here is already a shipboard random event in this
	// fork, minus the three that would eat the site itself (dimensional rewrites
	// turfs, the black hole swallows them, bluespace scatters the crew off the
	// reservation). hazard is the pay multiplier applied on top of zone scaling.
	var/static/list/containment_targets = list(
		list(
			"anomaly" = /obj/effect/anomaly/hallucination,
			"core" = /obj/item/assembly/signaler/anomaly/hallucination,
			"name" = "hallucination anomaly",
			"brief" = "Field bleed makes anyone near it see things that are not there. Instruments still read true.",
			"hazard" = 0.85,
			"weight" = 5,
		),
		list(
			"anomaly" = /obj/effect/anomaly/grav,
			"core" = /obj/item/assembly/signaler/anomaly/grav,
			"name" = "gravitational anomaly",
			"brief" = "It drags everything loose towards itself and throws it back at whoever is standing there. Secure your gear before you approach.",
			"hazard" = 0.9,
			"weight" = 5,
		),
		list(
			"anomaly" = /obj/effect/anomaly/flux,
			"core" = /obj/item/assembly/signaler/anomaly/flux,
			"name" = "flux anomaly",
			"brief" = "It arcs to anything conductive nearby. Wear insulated gloves.",
			"hazard" = 1,
			"weight" = 4,
		),
		list(
			"anomaly" = /obj/effect/anomaly/pyro,
			"core" = /obj/item/assembly/signaler/anomaly/pyro,
			"name" = "pyroclastic anomaly",
			"brief" = "It vents burning plasma into the room every few seconds. Bring a firesuit and an extinguisher.",
			"hazard" = 1.1,
			"weight" = 3,
		),
		list(
			"anomaly" = /obj/effect/anomaly/bioscrambler,
			"core" = /obj/item/assembly/signaler/anomaly/bioscrambler,
			"name" = "bioscrambler anomaly",
			"brief" = "It swaps limbs off anything organic that gets close. Send someone synthetic, or plan on surgery afterwards.",
			"hazard" = 1.25,
			"weight" = 2,
		),
	)

	// Anomaly cores are capped per type for the whole round (SSresearch): a
	// contract for a core the sector can no longer produce would strand the
	// crew at a neutralized anomaly with nothing on the deck.
	var/list/available = list()
	for(var/list/row as anything in containment_targets)
		if(!SSresearch.is_core_available(row["core"]))
			continue
		for(var/i in 1 to row["weight"])
			available += list(row)
	if(!length(available))
		generation_failed = TRUE
		return

	var/list/rolled = pick(available)
	anomaly_type = rolled["anomaly"]
	core_type = rolled["core"]
	anomaly_name = rolled["name"]
	hazard_brief = rolled["brief"]
	value_min = round(value_min * rolled["hazard"], 10)
	value_max = round(value_max * rolled["hazard"], 10)
	research_reward = round(research_reward * rolled["hazard"], 50)

/datum/mission/research/containment/build_objectives()
	var/datum/mission_objective/field/contain_anomaly/containment = new
	containment.anomaly_type = anomaly_type
	containment.core_type = core_type
	containment.anomaly_name = anomaly_name
	add_objective(containment)

	var/datum/mission_objective/deliver/handover = new
	handover.required_type = core_type
	handover.required_name = "the [anomaly_name] core"
	handover.required_amount = 1
	add_objective(handover)

/datum/mission/research/containment/update_text()
	name = "Containment Contract: [anomaly_name]"
	desc = "A [anomaly_name] has settled inside the derelict at ([target.target_x], [target.target_y]) in the [target_zone_name], and it is stable - it will still be there whenever you arrive. \
		[hazard_brief] \
		Neutralize it the standard way: read its field with a handheld analyzer for the frequency and code, dial those into a signaler, and trigger the signaler beside it. \
		It sheds its core when it goes. Bring that core to the mission pad. \
		Pays [research_reward] research points as a data dossier - slot it into an R&D console to bank them."

/datum/mission/research/containment/waypoint_label()
	return "Containment: [anomaly_name]"

/datum/mission/research/containment/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target.target_x
	data["target_y"] = target.target_y
	return data

// =========================================================================
// CORE SAMPLE CONTRACT: planetside stratigraphy under fire
// =========================================================================

/datum/mission/research/core_sample
	name = "Core Sample Contract"
	weight = 7
	mission_limit = 1
	voucher_count = 1
	quest_lost_policy = MISSION_QUEST_LOST_RETARGET
	gps_tag_prefix = "STRAT"
	research_origin = "planetary geology"
	value_min = 450
	value_max = 700
	research_reward = 1200

	/// zone_mobs theme path answering each calibration
	var/wave_theme
	/// The pylon chain, for progress-aware text
	var/datum/mission_objective/field/pylon_chain/chain

/datum/mission/research/core_sample/Destroy()
	chain = null
	return ..()

/datum/mission/research/core_sample/setup_target()
	var/datum/mission_target/planet/planet_target = new(src)
	if(!planet_target.resolve())
		qdel(planet_target)
		return FALSE
	target = planet_target
	return TRUE

/datum/mission/research/core_sample/generate_details()
	var/static/list/sample_subjects = list(
		"deep stratigraphic column",
		"mantle isotope series",
		"subsurface hydrology profile",
		"impact-glass horizon",
		"paleomagnetic reversal record",
	)
	objective_name = pick(sample_subjects)
	wave_theme = pick_weight(list(
		/obj/effect/zone_mobs/wildlife = 6,
		/obj/effect/zone_mobs/bug = 4,
		/obj/effect/zone_mobs/pirate = 2,
	))

/datum/mission/research/core_sample/build_objectives()
	chain = new
	chain.wave_theme = wave_theme
	add_objective(chain)
	add_objective(new /datum/mission_objective/deliver/bound)

/datum/mission/research/core_sample/update_text()
	name = "Core Sample Contract: [objective_name]"
	desc = "We need a [objective_name] off the planet at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		Our drop seeded [chain ? chain.points_total : 3] drill probes across one stretch of the surface. They are all down already and you can take them in any order. \
		The drill run is loud enough to draw whatever lives nearby, so go armed. The last probe you finish casks the sample; bring the cask to the mission pad. \
		Pays [research_reward] research points as a data dossier plus [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive a beacon for every probe still standing ([gps_tag])."

/datum/mission/research/core_sample/waypoint_label()
	return "Core Sample: [objective_name]"
