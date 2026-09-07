/datum/techweb_node/basic_shuttle_tech
	id = TECHWEB_NODE_BASIC_SHUTTLE
	display_name = "Basic Shuttle Research"
	description = "Research the technology required to create and pilot basic shuttles."
	prereq_ids = list(TECHWEB_NODE_FUNDIMENTAL_SCI)
	design_ids = list(
		"cryopod_console", // had no board at all until the console became deconstructable
		"engine_plasma",
		"engine_ion",
		"engine_oil", // had no design at all before rounds 14/15 - the depot was its only source
		"shuttle_heater", // was orphaned from every node, the heater design existed but nothing unlocked it
		"shuttle_helm",
		"shuttle_scoop",
		"shuttle_sublimator",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)

/datum/techweb_node/ship_construction_console
	id = TECHWEB_NODE_SHIP_CONSTRUCTION
	display_name = "Shuttle Construction"
	description = "Technology for constructing and modifying shuttles."
	prereq_ids = list(TECHWEB_NODE_BASIC_SHUTTLE)
	design_ids = list(
		"ship_construction",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/ship_piping
	id = TECHWEB_NODE_SHIP_PIPING
	display_name = "Shuttle Construction Piping"
	description = "Rapid piping and scanning technology for shuttle construction."
	prereq_ids = list(TECHWEB_NODE_SHIP_CONSTRUCTION)
	design_ids = list(
		"ship_construction_upgrade_rpd",
		"ship_construction_upgrade_tray",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/ship_tiling
	id = TECHWEB_NODE_SHIP_TILING
	display_name = "Shuttle Construction Tiling"
	description = "Rapid tiling technology for shuttle construction."
	prereq_ids = list(TECHWEB_NODE_SHIP_CONSTRUCTION)
	design_ids = list(
		"ship_construction_upgrade_rtd",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/ship_lighting
	id = TECHWEB_NODE_SHIP_LIGHTING
	display_name = "Shuttle Construction Lighting"
	description = "Rapid lighting technology for shuttle construction."
	prereq_ids = list(TECHWEB_NODE_SHIP_CONSTRUCTION)
	design_ids = list(
		"ship_construction_upgrade_rld",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/ship_fabrication
	id = TECHWEB_NODE_SHIP_FABRICATION
	display_name = "Shuttle Construction Servos"
	description = "Faster actuators for the ship construction drone, shaving a quarter off every build."
	prereq_ids = list(TECHWEB_NODE_SHIP_CONSTRUCTION)
	design_ids = list(
		"ship_construction_upgrade_servo",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/ship_fabrication_advanced
	id = TECHWEB_NODE_SHIP_FABRICATION_ADV
	display_name = "Advanced Shuttle Construction Servos"
	description = "A second-generation servo package for the ship construction drone, halving its build times."
	prereq_ids = list(TECHWEB_NODE_SHIP_FABRICATION)
	design_ids = list(
		"ship_construction_upgrade_servo_mk2",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/exp_shuttle_tech
	id = TECHWEB_NODE_EXPERIMENTAL_SHUTTLE
	display_name = "Experimental Shuttle Research"
	description = "Experimental engines and shuttle parts for unusual situations."
	prereq_ids = list(TECHWEB_NODE_BASIC_SHUTTLE)
	design_ids = list(
		"engine_expulsion",
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
	id = TECHWEB_NODE_RTG
	display_name = "Radioisotope Generators"
	description = "A sealed block of uranium wrapped in thermocouples. Slow, steady power with no fuel line and no moving parts, and the shielding work that goes with handling it."
	prereq_ids = list(TECHWEB_NODE_ENERGY_MANIPULATION)
	design_ids = list(
		"rtg",
		// Shares the node because it is the same problem read backwards - the RTG holds
		// radiation in, the shielder keeps a tritium nebula's out. It is also what makes
		// harvesting tritium with a ram scoop survivable, so it wants to be reachable
		// around the time a crew starts working the deeper bands.
		"radioactive_nebula_shielding",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/teg
	id = TECHWEB_NODE_TEG
	display_name = "Thermoelectric Generation"
	description = "A generator that turns the temperature difference between two circulating gas loops into serious power. Ships as a generator core and two circulators."
	prereq_ids = list(TECHWEB_NODE_PLASMA_CONTROL)
	design_ids = list(
		"teg",
		"teg_circulator",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/survey_scanner
	id = TECHWEB_NODE_SURVEY_SCANNER
	display_name = "Survey Scanners"
	description = "A machine that allows you to turn power into research points."
	prereq_ids = list(TECHWEB_NODE_PARTS_UPG)
	design_ids = list(
		"surveyscanner",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_base
	id = TECHWEB_NODE_NANITE_BASIC
	display_name = "Basic Nanite Programming"
	description = "The basics of nanite construction and programming."
	prereq_ids = list(TECHWEB_NODE_CYBERNETICS)
	design_ids = list(
		"nanite_disk",
		"nanite_remote",
		"nanite_comm_remote",
		"nanite_scanner",
		"nanite_chamber",
		"public_nanite_chamber",
		"nanite_chamber_control",
		"nanite_programmer",
		"nanite_program_hub",
		"nanite_cloud_control",
		"relay_nanites",
		"monitoring_nanites",
		"access_nanites",
		"repairing_nanites",
		"sensor_nanite_volume",
		"repeater_nanites",
		"relay_repeater_nanites",
		"red_diag_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_smart
	id = TECHWEB_NODE_NANITE_SMART
	display_name = "Smart Nanite Programming"
	description = "Nanite programs that require nanites to perform complex actions, act independently, roam or seek targets."
	prereq_ids = list(TECHWEB_NODE_NANITE_BASIC, TECHWEB_NODE_ROBOTICS)
	design_ids = list(
		"purging_nanites",
		"metabolic_nanites",
		"stealth_nanites",
		"memleak_nanites",
		"sensor_voice_nanites",
		"voice_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_mesh
	id = TECHWEB_NODE_NANITE_MESH
	display_name = "Mesh Nanite Programming"
	description = "Nanite programs that require static structures and membranes."
	prereq_ids = list(TECHWEB_NODE_NANITE_BASIC, TECHWEB_NODE_PARTS_UPG)
	design_ids = list(
		"hardening_nanites",
		"dermal_button_nanites",
		"refractive_nanites",
		"cryo_nanites",
		"conductive_nanites",
		"shock_nanites",
		"emp_nanites",
		"temperature_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

// NEED TO FIX ALL NANITE TECH IDS
/datum/techweb_node/nanite_bio
	id = "nanite_bio"
	display_name = "Biological Nanite Programming"
	description = "Nanite programs that require complex biological interaction."
	// "biotech" was an old-tg node id that no longer exists; SSresearch stripped it at
	// boot ("Invalid techweb nodes detected"). Advanced medbay gear is its closest
	// living relative for "complex biological interaction".
	prereq_ids = list("nanite_base", TECHWEB_NODE_MEDBAY_EQUIP_ADV)
	design_ids = list(
		"regenerative_nanites",
		"bloodheal_nanites",
		"coagulating_nanites",
		"poison_nanites",
		"flesheating_nanites",
		"sensor_crit_nanites",
		"sensor_death_nanites",
		"sensor_health_nanites",
		"sensor_damage_nanites",
		"sensor_species_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/nanite_neural
	id = "nanite_neural"
	display_name = "Neural Nanite Programming"
	description = "Nanite programs affecting nerves and brain matter."
	prereq_ids = list("nanite_bio")
	design_ids = list(
		"nervous_nanites",
		"brainheal_nanites",
		"paralyzing_nanites",
		"stun_nanites",
		"selfscan_nanites",
		"good_mood_nanites",
		"bad_mood_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/nanite_synaptic
	id = "nanite_synaptic"
	display_name = "Synaptic Nanite Programming"
	description = "Nanite programs affecting mind and thoughts."
	// "neural_programming" was an old-tg node id that no longer exists (boot warning).
	// Brain-computer interfaces are the modern node for machine-mind meddling.
	prereq_ids = list("nanite_neural", TECHWEB_NODE_BCI)
	design_ids = list(
		"mindshield_nanites",
		"pacifying_nanites",
		"blinding_nanites",
		"sleep_nanites",
		"mute_nanites",
		"speech_nanites",
		"hallucination_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/nanite_harmonic
	id = "nanite_harmonic"
	display_name = "Harmonic Nanite Programming"
	description = "Nanite programs that require seamless integration between nanites and biology."
	prereq_ids = list("nanite_bio","nanite_smart","nanite_mesh")
	design_ids = list(
		"fakedeath_nanites",
		"aggressive_nanites",
		"defib_nanites",
		"regenerative_plus_nanites",
		"brainheal_plus_nanites",
		"purging_plus_nanites",
		"adrenaline_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/nanite_combat
	id = "nanite_military"
	display_name = "Military Nanite Programming"
	description = "Nanite programs that perform military-grade functions."
	prereq_ids = list("nanite_harmonic", "syndicate_basic")
	design_ids = list(
		"explosive_nanites",
		"pyro_nanites",
		"meltdown_nanites",
		"viral_nanites",
		"nanite_sting_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

/datum/techweb_node/nanite_hazard
	id = "nanite_hazard"
	display_name = "Hazard Nanite Programs"
	description = "Extremely advanced Nanite programs with the potential of being extremely dangerous."
	prereq_ids = list("nanite_harmonic", "alientech")
	design_ids = list(
		"spreading_nanites",
		"mindcontrol_nanites",
		"mitosis_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

/datum/techweb_node/nanite_replication_protocols
	id = "nanite_replication_protocols"
	display_name = "Nanite Replication Protocols"
	description = "Advanced behaviours that allow nanites to exploit certain circumstances to replicate faster."
	prereq_ids = list("nanite_smart")
	design_ids = list(
		"kickstart_nanites",
		"factory_nanites",
		"tinker_nanites",
		"offline_nanites",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)
	hidden = TRUE
	experimental = TRUE

/datum/techweb_node/sleepertech
	id = "sleepertech"
	display_name = "Sleeper Unit Construction"
	description = "The technological peak of medical equipment within human space."
	// "adv_biotech"/"adv_engi" were old-tg node ids that no longer exist (boot warning);
	// with both stripped this node dangled with NO prerequisites at all. Advanced medbay
	// equipment + advanced parts is the same medical-plus-engineering gate they used to be.
	prereq_ids = list(TECHWEB_NODE_MEDBAY_EQUIP_ADV, TECHWEB_NODE_PARTS_ADV)
	design_ids = list("sleeper")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

// Station-only supply and records consoles. A ship has no station cargo department
// to file requests with and no station payroll to audit, so they come out of their
// upstream nodes; the ship bank machine, already unlocked by the consoles node.
// Is what crews use instead.
// These edits used to sit on /datum/techweb_node/basic_mining, /comptech and
// /comp_recordkeeping. None of those types exist here, so DM quietly created them
// with a null id, initialize_all_techweb_nodes() skipped them, and the removals
// never happened.
/datum/techweb_node/mining/New()
	. = ..()
	design_ids -= list(
		"cargoexpress",
	)

/datum/techweb_node/consoles/New()
	. = ..()
	design_ids -= list(
		"cargorequest",
		"account_console",
	)

/datum/techweb_node/bluespace_travel/New()
	. = ..()
	design_ids -= list(
		"bluespace_pod"
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
// /exp_surgery, which don't exist. The real node types are surgery_adv/surgery_exp.
/datum/techweb_node/surgery_adv/New()
	. = ..()
	design_ids += list(
		"surgery_oldstation_dissection_advanced",
	)

/datum/techweb_node/surgery_exp/New()
	. = ..()
	design_ids += list(
		"surgery_oldstation_dissection_superior",
	)

/datum/techweb_node/alien_surgery/New()
	. = ..()
	design_ids += list(
		"surgery_oldstation_dissection_elite",
	)

/**
 * Generic ammunition manufacturing.
 *
 * The weapons bench covers each blueprint gun's own ammo (voidcrew/modules/weapons_bench/).
 * Common reloads branch into specialist, experimental and explosive ammunition.
 * L6, Bulldog and sniper specialty loads also require their standard ammo research.
 */
/datum/techweb_node/ballistic_ammunition
	id = TECHWEB_NODE_BALLISTIC_AMMO
	display_name = "Ballistic Ammunition"
	description = "Case, primer and projectile tooling for the calibers every hauler ends up carrying."
	prereq_ids = list(TECHWEB_NODE_BASIC_ARMS)
	design_ids = list(
		"vc_shotgun_slug",
		"vc_shotgun_buckshot",
		"vc_a357_lathe",
		"vc_strilka310_clip",
		"vc_n762",
		"vc_mag_m9mm",
		"vc_mag_m10mm",
		"vc_mag_m45",
		"vc_ammo_m50",
		"vc_ammo_a357",
		"vc_ammo_harpoon",
		"vc_ammo_foam_smg",
		"vc_ammo_foam_pistol",
		"vc_ammo_foam_smgm45",
		"vc_ammo_foam_m762",
		"vc_c9mm_lathe",
		"vc_c10mm_lathe",
		"vc_c45_lathe",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/automatic_ammunition
	id = TECHWEB_NODE_AUTOMATIC_AMMO
	display_name = "Automatic Ammunition"
	description = "High-capacity feed devices and specialist shells. Keeping an automatic fed costs a lot more metal than keeping a pistol fed."
	prereq_ids = list(TECHWEB_NODE_BALLISTIC_AMMO)
	design_ids = list(
		"vc_mag_m9mm_aps",
		"vc_mag_smgm9mm",
		"vc_shotgun_dragonsbreath",
		"vc_ammo_uzi",
		"vc_ammo_tommygun",
		"vc_ammo_m223",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/specialist_ammo
	id = TECHWEB_NODE_SPECIALIST_AMMO
	display_name = "Specialist Ammunition"
	description = "Precision, armor-piercing, hollow-point and incendiary loads for conventional firearms."
	prereq_ids = list(TECHWEB_NODE_AUTOMATIC_AMMO, TECHWEB_NODE_EXOTIC_AMMO)
	design_ids = list(
		"vc_ammo_m9mm_ap",
		"vc_ammo_m9mm_hp",
		"vc_ammo_m9mm_fire",
		"vc_ammo_m10mm_ap",
		"vc_ammo_m10mm_hp",
		"vc_ammo_m10mm_fire",
		"vc_ammo_aps_ap",
		"vc_ammo_aps_hp",
		"vc_ammo_aps_fire",
		"vc_ammo_saber_ap",
		"vc_ammo_saber_fire",
		"vc_ammo_c20r_ap",
		"vc_ammo_c20r_hp",
		"vc_ammo_c20r_fire",
		"vc_ammo_c38_match",
		"vc_ammo_m38_match",
		"vc_ammo_c38_dumdum",
		"vc_ammo_m38_dumdum",
		"vc_ammo_a357_match",
		"vc_ammo_grenade_rubber",
		"vc_ammo_shotgun_stun",
		"vc_ammo_shotgun_milspec_slug",
		"vc_ammo_shotgun_milspec_buckshot",
		"vc_ammo_shotgun_executioner",
		"vc_ammo_shotgun_pulverizer",
		"vc_ammo_shotgun_incendiary_precision",
		"vc_ammo_shotgun_meteor",
		"vc_ammo_shotgun_incapacitating",
		"vc_ammo_shotgun_ion",
		"vc_ammo_shotgun_dart_large",
		"vc_ammo_shotgun_breacher",
		"vc_ammo_foam_smg_riot",
		"vc_ammo_foam_pistol_riot",
		"vc_ammo_foam_smgm45_riot",
		"vc_ammo_foam_m762_riot",
		"mag_autorifle_ap",
		"mag_autorifle_ic",
		"donkshell",
		"vc_riot_darts_lathe",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/experimental_ammo
	id = TECHWEB_NODE_EXPERIMENTAL_AMMO
	display_name = "Experimental Ammunition"
	description = "Guided and phasic projectiles, advanced payloads and high-energy shells."
	prereq_ids = list(TECHWEB_NODE_SPECIALIST_AMMO, TECHWEB_NODE_APPLIED_BLUESPACE)
	design_ids = list(
		"vc_ammo_smartgun",
		"vc_ammo_reaper",
		"vc_ammo_a357_phasic",
		"vc_ammo_a357_heartseeker",
		"vc_ammo_strilka_phasic",
		"vc_ammo_m223_phasic",
		"vc_ammo_rocket_heap",
		"vc_ammo_shotgun_pulse",
		"vc_ammo_shotgun_bioterror",
		"vc_ammo_ronin",
		"vc_ammo_buster",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

/datum/techweb_node/explosive_ammo
	id = TECHWEB_NODE_EXPLOSIVE_AMMO
	display_name = "Explosive Ammunition"
	description = "Gyrojet cartridges, launcher grenades and 84mm rockets."
	prereq_ids = list(TECHWEB_NODE_AUTOMATIC_AMMO, TECHWEB_NODE_EXPLOSIVES)
	design_ids = list(
		"vc_ammo_gyrojet",
		"vc_ammo_grenade_he",
		"vc_ammo_rocket_he",
		"vc_ammo_rocket_low_yield",
		"vc_ammo_shotgun_frag12",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/bulldog_special_ammo
	id = TECHWEB_NODE_BULLDOG_SPECIAL_AMMO
	display_name = "Specialist Bulldog Ammunition"
	description = "Specialty 12-gauge drums, including taser, incendiary and biochemical loads."
	prereq_ids = list(TECHWEB_NODE_WEAPON_AMMO_BULLDOG, TECHWEB_NODE_EXPERIMENTAL_AMMO)
	design_ids = list(
		"vc_ammo_bulldog_stun",
		"vc_ammo_bulldog_dragon",
		"vc_ammo_bulldog_bioterror",
		"vc_ammo_bulldog_meteor",
		"vc_ammo_bulldog_flechette",
		"vc_ammo_bulldog_donk",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/l6_special_ammo
	id = TECHWEB_NODE_L6_SPECIAL_AMMO
	display_name = "Specialist L6 SAW Ammunition"
	description = "Special-purpose 7mm ammunition and high-capacity rubber magazines for the L6 SAW."
	prereq_ids = list(TECHWEB_NODE_WEAPON_AMMO_L6_SAW, TECHWEB_NODE_SPECIALIST_AMMO)
	design_ids = list(
		"vc_ammo_l6_ap",
		"vc_ammo_l6_hp",
		"vc_ammo_l6_incendiary",
		"vc_ammo_l6_match",
		"vc_ammo_l6_rubber",
		"vc_ammo_l6_rubber_hicap",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/sniper_special_ammo
	id = TECHWEB_NODE_SNIPER_SPECIAL_AMMO
	display_name = "Specialist Sniper Ammunition"
	description = "Disruptor, incendiary, penetrator and marksman loads for anti-materiel rifles."
	prereq_ids = list(TECHWEB_NODE_WEAPON_AMMO_SNIPER, TECHWEB_NODE_EXPERIMENTAL_AMMO)
	design_ids = list(
		"vc_ammo_sniper_disruptor",
		"vc_ammo_sniper_incendiary",
		"vc_ammo_sniper_penetrator",
		"vc_ammo_sniper_marksman",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/mission_logistics
	id = TECHWEB_NODE_MISSION_LOGISTICS
	display_name = "Mission Logistics"
	description = "Equipment for managing ship contracts and missions."
	prereq_ids = list(TECHWEB_NODE_FUNDIMENTAL_SCI)
	design_ids = list(
		"mission_board",
		"mission_pad",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)

/datum/techweb_node/survey_console
	id = TECHWEB_NODE_SURVEY_CONSOLE
	display_name = "Orbital survey console"
	design_ids = list(
		"survey_console_board",
		"survey_console_rewards_upgrade_basic",
		"survey_console_information_upgrade_basic"
	)
	prereq_ids = list(TECHWEB_NODE_FUNDIMENTAL_SCI)
	description = "Wait, there's stuff out here?!"
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)

/datum/techweb_node/survey_console_advanced
	id = TECHWEB_NODE_SURVEY_CONSOLE_ADV
	display_name = "Survey console advanced upgrades"
	description = "You can now choose where to dock on a planet."
	prereq_ids = list(TECHWEB_NODE_SURVEY_CONSOLE)
	design_ids = list(
		"survey_ship_docking",
		"survey_console_rewards_upgrade_advanced",
		"survey_console_information_upgrade_advanced",
	)
	required_surveyed_objects = list(planets = 1, nebulas = 3, electric_storms = 1)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)


/datum/techweb_node/survey_console_superior
	id = TECHWEB_NODE_SURVEY_CONSOLE_SUPERIOR
	display_name = "Survey console superior upgrades"
	description = "You've seen much. Maybe you can share your findings with others?"
	prereq_ids = list(TECHWEB_NODE_SURVEY_CONSOLE_ADV)
	design_ids = list(
		"survey_data_disk",
		"survey_map_obj_sight",
		"survey_console_rewards_upgrade_superior",
		"survey_console_information_upgrade_superior",
		"survey_map_range_upg_superior"
	)
	required_surveyed_objects = list(emp_storms = 3, electric_storms = 3, planets = 3)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/survey_console_elite
	id = TECHWEB_NODE_SURVEY_CONSOLE_ELITE
	display_name = "Survey console elite upgrades"
	description = "You know everything. You see everything. No one is outside your reach, nor hidden from your sight."
	prereq_ids = list(TECHWEB_NODE_SURVEY_CONSOLE_SUPERIOR)
	design_ids = list(
		 "survey_map_mob_sight",
		 "survey_console_rewards_upgrade_elite",
		 "survey_console_information_upgrade_elite",
		 "survey_map_range_upg_elite"
	)
	required_surveyed_objects = list(stars = 1, planets = 5, asteroids = 2)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

// Radar array: the ship's overmap sensor suite. A dedicated ladder separate
// from the survey console: each tier widens the active-scan radius, and the
// upper tiers add ruin identification and live player-ship tracking. Read by
// the ship's sensor procs in ship_sensors.dm; the nodes unlock no designs.
/datum/techweb_node/radar_array
	id = TECHWEB_NODE_RADAR_ARRAY
	display_name = "Radar Array"
	description = "A long-range overmap sensor array. Widens the helm's active-scan radius for charting planets, ruins and outposts."
	prereq_ids = list(TECHWEB_NODE_FUNDIMENTAL_SCI)
	design_ids = list()
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/techweb_node/radar_array_advanced
	id = TECHWEB_NODE_RADAR_ARRAY_ADV
	display_name = "Radar Array: Signal Analysis"
	description = "Spectral analysis of charted signals. Widens the scan radius further, and identifies what a space ruin actually is as soon as it's charted, no survey needed."
	prereq_ids = list(TECHWEB_NODE_RADAR_ARRAY)
	design_ids = list()
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/radar_array_elite
	id = TECHWEB_NODE_RADAR_ARRAY_ELITE
	display_name = "Radar Array: Vessel Tracking"
	description = "Active vessel tracking. Maximises the scan radius and plots other crews' ships within sensor range. Those contacts disappear as soon as either ship moves out of range."
	prereq_ids = list(TECHWEB_NODE_RADAR_ARRAY_ADV)
	design_ids = list()
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

// Transporter: the late-game replacement for the drop pod. A drop pod is a one-way
// crate you fire at a planet; a transporter moves people both ways, from orbit, over
// and over. The ladder below is deliberately expensive: the first node is a working
// but crude lift, and the two above it are what make it precise and safe.
/datum/techweb_node/transporter
	id = TECHWEB_NODE_TRANSPORTER
	display_name = "Molecular Transporter"
	description = "A pad and a console that take a person apart on one deck and put them back together on a planet. The pattern lock is coarse at this tier - the computer picks open ground for you, and it can only recover people who are carrying a transponder and standing out in the open."
	prereq_ids = list(TECHWEB_NODE_BLUESPACE_TRAVEL, TECHWEB_NODE_SURVEY_CONSOLE_ADV)
	design_ids = list(
		"transporter_pad",
		"transporter_console",
		"transporter_transponder",
	)
	required_surveyed_objects = list(planets = 3)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/transporter_targeting
	id = TECHWEB_NODE_TRANSPORTER_TARGETING
	display_name = "Transporter Pattern Targeting"
	description = "A targeting scanner for the control console. Pick the exact turf at either end of a beam, hold a lock through a roof, and pull up whatever is standing on the coordinates - transponder or not, willing or not."
	prereq_ids = list(TECHWEB_NODE_TRANSPORTER, TECHWEB_NODE_SURVEY_CONSOLE_SUPERIOR)
	design_ids = list(
		"transporter_targeting",
	)
	required_surveyed_objects = list(planets = 5, asteroids = 2)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

/datum/techweb_node/transporter_biofilter
	id = TECHWEB_NODE_TRANSPORTER_BIOFILTER
	display_name = "Transporter Biofilter Matrix"
	description = "Filters the pattern properly on the way through. Nobody arrives burned any more, the pad recharges faster, and the console can finally tell you when someone has cut a pad's safety interlocks."
	prereq_ids = list(TECHWEB_NODE_TRANSPORTER_TARGETING, TECHWEB_NODE_PARTS_BLUESPACE)
	design_ids = list(
		"transporter_biofilter",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_5_POINTS)

/datum/techweb_node/fundamental_sci/New()
	. = ..()
	design_ids |= "rdrelay"
