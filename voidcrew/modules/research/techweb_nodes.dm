/datum/techweb_node/basic_shuttle_tech
	display_name = "Basic Shuttle Research"
	description = "Research the technology required to create and pilot basic shuttles."
	prerequisite_nodes = list(/datum/techweb_node/fundamental_sci)
	unlocked_designs = list(
		/datum/design/board/engine/plasma,
		/datum/design/board/engine, // the ion thruster
		/datum/design/board/engine/oil, // had no design at all before rounds 14/15 - the depot was its only source
		/datum/design/board/shuttle/heater, // was orphaned from every node, the heater design existed but nothing unlocked it
		/datum/design/board/shuttle/shuttle_helm,
		/datum/design/board/shuttle/scoop,
		/datum/design/board/shuttle/sublimator,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)

/datum/techweb_node/ship_construction_console
	display_name = "Shuttle Construction"
	description = "Technology for constructing and modifying shuttles."
	prerequisite_nodes = list(/datum/techweb_node/basic_shuttle_tech)
	unlocked_designs = list(
		/datum/design/board/shuttle/ship_construction,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/ship_piping
	display_name = "Shuttle Construction Piping"
	description = "Rapid piping and scanning technology for shuttle construction."
	prerequisite_nodes = list(/datum/techweb_node/ship_construction_console)
	unlocked_designs = list(
		/datum/design/ship_construction_upgrade_rpd,
		/datum/design/ship_construction_upgrade_tray,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/ship_tiling
	display_name = "Shuttle Construction Tiling"
	description = "Rapid tiling technology for shuttle construction."
	prerequisite_nodes = list(/datum/techweb_node/ship_construction_console)
	unlocked_designs = list(
		/datum/design/ship_construction_upgrade_rtd,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/ship_lighting
	display_name = "Shuttle Construction Lighting"
	description = "Rapid lighting technology for shuttle construction."
	prerequisite_nodes = list(/datum/techweb_node/ship_construction_console)
	unlocked_designs = list(
		/datum/design/ship_construction_upgrade_rld,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/exp_shuttle_tech
	display_name = "Experimental Shuttle Research"
	description = "Experimental engines and shuttle parts for unusual situations."
	prerequisite_nodes = list(/datum/techweb_node/basic_shuttle_tech)
	unlocked_designs = list(
		/datum/design/board/engine/expulsion,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

// The TEG, its circulators and the RTG had circuit boards but no research route
// anywhere in the web - the only ones in the game were mapped into hulls. Six
// players rediscovered that in rounds 14/15. Both node costs are invented and
// unplaytested. The RTG is quiet passive power one tier above the starter
// thrusters; the TEG is priced a tier above the PACMAN it outclasses, and hangs
// off the same atmos node, because the Scarab's TEG engineering module is already
// costed as a top-tier power spike ("TEG is pretty OP", ship_upgrades/ships/scarab.dm)
// and its research route should not be an early pickup.
/datum/techweb_node/rtg
	display_name = "Radioisotope Generators"
	description = "A sealed block of uranium wrapped in thermocouples. Slow, steady power with no fuel line and no moving parts."
	prerequisite_nodes = list(/datum/techweb_node/energy_manipulation)
	unlocked_designs = list(
		/datum/design/board/rtg,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/teg
	display_name = "Thermoelectric Generation"
	description = "A generator that turns the temperature difference between two circulating gas loops into serious power. Ships as a generator core and two circulators."
	prerequisite_nodes = list(/datum/techweb_node/plasma_control)
	unlocked_designs = list(
		/datum/design/board/teg,
		/datum/design/board/teg_circulator,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/survey_scanner
	display_name = "Survey Scanners"
	description = "A machine that allows you to turn power into research points."
	prerequisite_nodes = list(/datum/techweb_node/parts_upg)
	unlocked_designs = list(
		/datum/design/board/survey_scanner,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_base
	display_name = "Basic Nanite Programming"
	description = "The basics of nanite construction and programming."
	prerequisite_nodes = list(/datum/techweb_node/cybernetics)
	unlocked_designs = list(
		/datum/design/nanite_disk,
		/datum/design/nanite_remote,
		/datum/design/nanite_comm_remote,
		/datum/design/nanite_scanner,
		/datum/design/board/nanite_chamber,
		/datum/design/board/public_nanite_chamber,
		/datum/design/board/nanite_chamber_control,
		/datum/design/board/nanite_programmer,
		/datum/design/board/nanite_program_hub,
		/datum/design/board/nanite_cloud_control,
		/datum/design/nanites/relay,
		/datum/design/nanites/monitoring,
		/datum/design/nanites/access,
		/datum/design/nanites/repairing,
		/datum/design/nanites/sensor_nanite_volume,
		/datum/design/nanites/repeater,
		/datum/design/nanites/relay_repeater,
		/datum/design/nanites/reduced_diagnostics,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_smart
	display_name = "Smart Nanite Programming"
	description = "Nanite programs that require nanites to perform complex actions, act independently, roam or seek targets."
	prerequisite_nodes = list(/datum/techweb_node/nanite_base, /datum/techweb_node/robotics)
	unlocked_designs = list(
		/datum/design/nanites/purging,
		/datum/design/nanites/metabolic_synthesis,
		/datum/design/nanites/stealth,
		/datum/design/nanites/memory_leak,
		/datum/design/nanites/sensor_voice,
		/datum/design/nanites/voice,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_mesh
	display_name = "Mesh Nanite Programming"
	description = "Nanite programs that require static structures and membranes."
	prerequisite_nodes = list(/datum/techweb_node/nanite_base, /datum/techweb_node/parts_upg)
	unlocked_designs = list(
		/datum/design/nanites/hardening,
		/datum/design/nanites/dermal_button,
		/datum/design/nanites/refractive,
		/datum/design/nanites/cryo,
		/datum/design/nanites/conductive,
		/datum/design/nanites/shock,
		/datum/design/nanites/emp,
		/datum/design/nanites/temperature,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_bio
	display_name = "Biological Nanite Programming"
	description = "Nanite programs that require complex biological interaction."
	// "biotech" was an old-tg node id that no longer exists; SSresearch stripped it at
	// boot ("Invalid techweb nodes detected"). Advanced medbay gear is its closest
	// living relative for "complex biological interaction".
	prerequisite_nodes = list(/datum/techweb_node/nanite_base, /datum/techweb_node/medbay_equip_adv)
	unlocked_designs = list(
		/datum/design/nanites/regenerative,
		/datum/design/nanites/blood_restoring,
		/datum/design/nanites/coagulating,
		/datum/design/nanites/poison,
		/datum/design/nanites/flesh_eating,
		/datum/design/nanites/sensor_crit,
		/datum/design/nanites/sensor_death,
		/datum/design/nanites/sensor_health,
		/datum/design/nanites/sensor_damage,
		/datum/design/nanites/sensor_species,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_neural
	display_name = "Neural Nanite Programming"
	description = "Nanite programs affecting nerves and brain matter."
	prerequisite_nodes = list(/datum/techweb_node/nanite_bio)
	unlocked_designs = list(
		/datum/design/nanites/nervous,
		/datum/design/nanites/brain_heal,
		/datum/design/nanites/paralyzing,
		/datum/design/nanites/stun,
		/datum/design/nanites/self_scan,
		/datum/design/nanites/good_mood,
		/datum/design/nanites/bad_mood,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/nanite_synaptic
	display_name = "Synaptic Nanite Programming"
	description = "Nanite programs affecting mind and thoughts."
	// "neural_programming" was an old-tg node id that no longer exists (boot warning).
	// Brain-computer interfaces are the modern node for machine-mind meddling.
	prerequisite_nodes = list(/datum/techweb_node/nanite_neural, /datum/techweb_node/bci)
	unlocked_designs = list(
		/datum/design/nanites/mindshield,
		/datum/design/nanites/pacifying,
		/datum/design/nanites/blinding,
		/datum/design/nanites/sleepy,
		/datum/design/nanites/mute,
		/datum/design/nanites/speech,
		/datum/design/nanites/hallucination,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/nanite_harmonic
	display_name = "Harmonic Nanite Programming"
	description = "Nanite programs that require seamless integration between nanites and biology."
	prerequisite_nodes = list(/datum/techweb_node/nanite_bio, /datum/techweb_node/nanite_smart, /datum/techweb_node/nanite_mesh)
	unlocked_designs = list(
		/datum/design/nanites/fake_death,
		/datum/design/nanites/aggressive_replication,
		/datum/design/nanites/defib,
		/datum/design/nanites/regenerative_advanced,
		/datum/design/nanites/brain_heal_advanced,
		/datum/design/nanites/purging_advanced,
		/datum/design/nanites/adrenaline,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/nanite_combat
	display_name = "Military Nanite Programming"
	description = "Nanite programs that perform military-grade functions."
	prerequisite_nodes = list(/datum/techweb_node/nanite_harmonic, /datum/techweb_node/syndicate_basic)
	unlocked_designs = list(
		/datum/design/nanites/explosive,
		/datum/design/nanites/pyro,
		/datum/design/nanites/meltdown,
		/datum/design/nanites/viral,
		/datum/design/nanites/nanite_sting,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

/datum/techweb_node/nanite_hazard
	display_name = "Hazard Nanite Programs"
	description = "Extremely advanced Nanite programs with the potential of being extremely dangerous."
	// The old "alientech" id is now /datum/techweb_node/alien/base.
	prerequisite_nodes = list(/datum/techweb_node/nanite_harmonic, /datum/techweb_node/alien/base)
	unlocked_designs = list(
		/datum/design/nanites/spreading,
		/datum/design/nanites/mind_control,
		/datum/design/nanites/mitosis,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

/datum/techweb_node/nanite_replication_protocols
	display_name = "Nanite Replication Protocols"
	description = "Advanced behaviours that allow nanites to exploit certain circumstances to replicate faster."
	prerequisite_nodes = list(/datum/techweb_node/nanite_smart)
	unlocked_designs = list(
		/datum/design/nanites/kickstart,
		/datum/design/nanites/factory,
		/datum/design/nanites/tinker,
		/datum/design/nanites/offline,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)
	node_flags = parent_type::node_flags | TECHWEB_NODE_HIDDEN | TECHWEB_NODE_EXPERIMENTAL

/datum/techweb_node/sleepertech
	display_name = "Sleeper Unit Construction"
	description = "The technological peak of medical equipment within human space."
	// "adv_biotech"/"adv_engi" were old-tg node ids that no longer exist (boot warning);
	// with both stripped this node dangled with NO prerequisites at all. Advanced medbay
	// equipment + advanced parts is the same medical-plus-engineering gate they used to be.
	prerequisite_nodes = list(/datum/techweb_node/medbay_equip_adv, /datum/techweb_node/parts_adv)
	unlocked_designs = list(/datum/design/board/sleeper)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

// Station-only supply and records consoles. A ship has no station cargo department
// to file requests with and no station payroll to audit, so they come out of their
// upstream nodes; the ship bank machine, already unlocked by the consoles node.
// Is what crews use instead.
// These edits used to sit on /datum/techweb_node/basic_mining, /comptech and
// /comp_recordkeeping. None of those types exist here, so DM quietly created them
// with a null id, initialize_all_techweb_nodes() skipped them, and the removals
// never happened. Nodes are keyed by typepath now, so a mistyped parent no longer
// fails quietly - it registers as a real, nameless, free node instead.
/datum/techweb_node/mining/New()
	. = ..()
	unlocked_designs -= list(
		/datum/design/cargo_express,
	)

/datum/techweb_node/consoles/New()
	. = ..()
	unlocked_designs -= list(
		/datum/design/board/cargorequest,
		/datum/design/board/accounting_console,
	)

/datum/techweb_node/bluespace_travel/New()
	. = ..()
	unlocked_designs -= list(
		/datum/design/bluespace_pod,
	)

// Explosives gated itself behind the Low-Yield Explosives ordnance experiment, which is
// only completable by catching an explosion on a Tachyon-Doppler array and publishing the
// reading through the NT Frontier app - an ordnance lab's workflow, and no ship has one.
// That left the node unreachable no matter how many points a crew banked, and with it
// everything downstream: Exotic Ammunition and the rest of that branch. Points gate it now.
// The experiment itself is untouched and still pays out through a scientific partner
// (code/modules/research/ordnance/scipaper_partner.dm) for any crew that does build the array.
/datum/techweb_node/explosives/New()
	. = ..()
	required_experiments -= /datum/experiment/ordnance/explosive/lowyieldbomb

// The extra dissection tiers hang off the surgery ladder that gates the surgeries
// beneath them. Same orphaned-parent story as above: these were on /adv_surgery and
// /exp_surgery, which don't exist. The real node types are surgery_adv/surgery_exp,
// and upstream's old /alien_surgery is now /alien/surgery.
// Assoc writes rather than +=: /datum/techweb_node/New() has already made
// unlocked_designs associative by the time this runs, and a bare += would leave the
// new entry with a null value.
/datum/techweb_node/surgery_adv/New()
	. = ..()
	unlocked_designs[/datum/design/surgery/experimental_dissection/advanced] = TRUE

/datum/techweb_node/surgery_exp/New()
	. = ..()
	unlocked_designs[/datum/design/surgery/experimental_dissection/superior] = TRUE

/datum/techweb_node/alien/surgery/New()
	. = ..()
	unlocked_designs[/datum/design/surgery/experimental_dissection/elite] = TRUE

/datum/techweb_node/mission_logistics
	display_name = "Mission Logistics"
	description = "Equipment for managing ship contracts and missions."
	prerequisite_nodes = list(/datum/techweb_node/fundamental_sci)
	unlocked_designs = list(
		/datum/design/board/mission_board,
		/datum/design/board/mission_pad,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)

/datum/techweb_node/survey_console
	display_name = "Orbital survey console"
	unlocked_designs = list(
		/datum/design/board/survey_console,
		/datum/design/survey_console_rewards_upgrade_basic,
		/datum/design/survey_console_information_upgrade_basic,
	)
	prerequisite_nodes = list(/datum/techweb_node/fundamental_sci)
	description = "Wait, there's stuff out here?!"
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)

/datum/techweb_node/survey_console_advanced
	display_name = "Survey console advanced upgrades"
	description = "You can now choose where to dock on a planet."
	prerequisite_nodes = list(/datum/techweb_node/survey_console)
	unlocked_designs = list(
		/datum/design/survey_ship_docking,
		/datum/design/survey_console_rewards_upgrade_advanced,
		/datum/design/survey_console_information_upgrade_advanced,
	)
	required_surveyed_objects = list(planets = 1, nebulas = 3, electric_storms = 1)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)


/datum/techweb_node/survey_console_superior
	display_name = "Survey console superior upgrades"
	description = "You've seen much. Maybe you can share your findings with others?"
	prerequisite_nodes = list(/datum/techweb_node/survey_console_advanced)
	unlocked_designs = list(
		/datum/design/survey_data_disk,
		/datum/design/survey_map_obj_sight,
		/datum/design/survey_console_rewards_upgrade_superior,
		/datum/design/survey_console_information_upgrade_superior,
		/datum/design/survey_map_range_upg_superior,
	)
	required_surveyed_objects = list(emp_storms = 3, electric_storms = 3, planets = 3)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/survey_console_elite
	display_name = "Survey console elite upgrades"
	description = "You know everything. You see everything. No one is outside your reach, nor hidden from your sight."
	prerequisite_nodes = list(/datum/techweb_node/survey_console_superior)
	unlocked_designs = list(
		/datum/design/survey_map_mob_sight,
		/datum/design/survey_console_rewards_upgrade_elite,
		/datum/design/survey_console_information_upgrade_elite,
		/datum/design/survey_map_range_upg_elite,
	)
	required_surveyed_objects = list(stars = 1, planets = 5, asteroids = 2)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

// Radar array: the ship's overmap sensor suite. A dedicated ladder separate
// from the survey console: each tier widens the active-scan radius, and the
// upper tiers add ruin identification and live player-ship tracking. Read by
// the ship's sensor procs in ship_sensors.dm; the nodes unlock no designs.
/datum/techweb_node/radar_array
	display_name = "Radar Array"
	description = "A long-range overmap sensor array. Widens the helm's active-scan radius for charting planets, ruins and outposts."
	prerequisite_nodes = list(/datum/techweb_node/fundamental_sci)
	unlocked_designs = list()
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/radar_array_advanced
	display_name = "Radar Array: Signal Analysis"
	description = "Spectral analysis of charted signals. Widens the scan radius further, and identifies what a space ruin actually is as soon as it's charted, no survey needed."
	prerequisite_nodes = list(/datum/techweb_node/radar_array)
	unlocked_designs = list()
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/radar_array_elite
	display_name = "Radar Array: Vessel Tracking"
	description = "Active vessel tracking. Maximises the scan radius and plots other crews' ships within sensor range. Those contacts disappear as soon as either ship moves out of range."
	prerequisite_nodes = list(/datum/techweb_node/radar_array_advanced)
	unlocked_designs = list()
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

// Transporter: the late-game replacement for the drop pod. A drop pod is a one-way
// crate you fire at a planet; a transporter moves people both ways, from orbit, over
// and over. The ladder below is deliberately expensive: the first node is a working
// but crude lift, and the two above it are what make it precise and safe.
/datum/techweb_node/transporter
	display_name = "Molecular Transporter"
	description = "A pad and a console that take a person apart on one deck and put them back together on a planet. The pattern lock is coarse at this tier - the computer picks open ground for you, and it can only recover people who are carrying a transponder and standing out in the open."
	prerequisite_nodes = list(/datum/techweb_node/bluespace_travel, /datum/techweb_node/survey_console_advanced)
	unlocked_designs = list(
		/datum/design/board/transporter_pad,
		/datum/design/board/transporter_console,
		/datum/design/transporter_transponder,
	)
	required_surveyed_objects = list(planets = 3)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/transporter_targeting
	display_name = "Transporter Pattern Targeting"
	description = "A targeting scanner for the control console. Pick the exact turf at either end of a beam, hold a lock through a roof, and pull up whatever is standing on the coordinates - transponder or not, willing or not."
	prerequisite_nodes = list(/datum/techweb_node/transporter, /datum/techweb_node/survey_console_superior)
	unlocked_designs = list(
		/datum/design/transporter_targeting,
	)
	required_surveyed_objects = list(planets = 5, asteroids = 2)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

/datum/techweb_node/transporter_biofilter
	display_name = "Transporter Biofilter Matrix"
	description = "Filters the pattern properly on the way through. Nobody arrives burned any more, the pad recharges faster, and the console can finally tell you when someone has cut a pad's safety interlocks."
	prerequisite_nodes = list(/datum/techweb_node/transporter_targeting, /datum/techweb_node/parts_bluespace)
	unlocked_designs = list(
		/datum/design/transporter_biofilter,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)
