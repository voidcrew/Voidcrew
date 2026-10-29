// Included by the upstream test harness inside its UNIT_TESTS/SPACEMAN_DMM guard.
// BEGIN_INCLUDE
#include "_voidcrew_test_selection.dm"
#include "armor_partial_modifiers.dm"
#include "atmos_component_pipeline.dm"
#include "blood_jaunt_destinations.dm"
#include "drift_vectors.dm"
#include "gas_connector_lifecycle.dm"
#include "glass_floor_baseturfs.dm"
#include "hyperspace_jetpack.dm"
#include "late_initialization_reentry.dm"
#include "map_parser_attributes.dm"
#include "mod_night_vision.dm"
#include "operating_table_movement.dm"
#include "overmap_spawn_density.dm"
#include "pipeline_reconciliation.dm"
#include "prisoner_photos.dm"
#include "reagent_holder_teardown.dm"
#include "shuttle_cling_lifecycle.dm"
#include "shuttle_cling_rethrow.dm"
#include "shuttle_load_ownership.dm"
#include "soft_crit.dm"
#include "throw_cleanup.dm"
#include "throw_rethrow.dm"
#include "voidcrew_ambient_core.dm"
#include "voidcrew_ambient_outpost_dancer.dm"
#include "voidcrew_ambient_outposts.dm"
#include "voidcrew_ambient_planets.dm"
#include "voidcrew_ambient_recruiters.dm"
#include "voidcrew_ambient_strays.dm"
#include "voidcrew_ammo_box_materials.dm"
#include "voidcrew_anomaly_rewards.dm"
#include "voidcrew_anomaly_trade.dm"
#include "voidcrew_assault_pod.dm"
#include "voidcrew_autopilot_course.dm"
#include "voidcrew_autotranslate_morph.dm"
#include "voidcrew_autotranslate_output.dm"
#include "voidcrew_bank_deposits.dm"
#include "voidcrew_bitrunning.dm"
#include "voidcrew_blueprint_guns.dm"
#include "voidcrew_bounty_admin.dm"
#include "voidcrew_bounty_ai.dm"
#include "voidcrew_bounty_board.dm"
#include "voidcrew_bounty_bosses.dm"
#include "voidcrew_bounty_criminal.dm"
#include "voidcrew_bounty_identity.dm"
#include "voidcrew_bounty_kingpin.dm"
#include "voidcrew_bounty_lair_mafia.dm"
#include "voidcrew_bounty_lair_maps.dm"
#include "voidcrew_bounty_lairs.dm"
#include "voidcrew_bounty_outpost.dm"
#include "voidcrew_bounty_seams.dm"
#include "voidcrew_camera_scope.dm"
#include "voidcrew_cargo_cart.dm"
#include "voidcrew_cargo_docking.dm"
#include "voidcrew_cargo_load_queue.dm"
#include "voidcrew_checkpoint_loading.dm"
#include "voidcrew_checkpoint_mergers.dm"
#include "voidcrew_checkpoints.dm"
#include "voidcrew_checkpoints_every_ship.dm"
#include "voidcrew_cloning_vat_claim.dm"
#include "voidcrew_colosseum.dm"
#include "voidcrew_combat_camera_breaches.dm"
#include "voidcrew_combat_metrics.dm"
#include "voidcrew_construction_automation.dm"
#include "voidcrew_construction_berth.dm"
#include "voidcrew_construction_refunds.dm"
#include "voidcrew_cordon_teleport.dm"
#include "voidcrew_crew_antag_gc.dm"
#include "voidcrew_crew_hud.dm"
#include "voidcrew_cyberware.dm"
#include "voidcrew_derelict_helpers.dm"
#include "voidcrew_derelict_layout.dm"
#include "voidcrew_derelict_leash.dm"
#include "voidcrew_derelict_outpost.dm"
#include "voidcrew_derelict_themes.dm"
#include "voidcrew_dissection_tiers.dm"
#include "voidcrew_drug_lab.dm"
#include "voidcrew_drug_recipe.dm"
#include "voidcrew_dynamic_events.dm"
#include "voidcrew_economy_metrics.dm"
#include "voidcrew_event_horizon.dm"
#include "voidcrew_fleet_waypoints.dm"
#include "voidcrew_fresh_cores.dm"
#include "voidcrew_helm_access.dm"
#include "voidcrew_helpers.dm"
#include "voidcrew_hull_containment.dm"
#include "voidcrew_hull_survey.dm"
#include "voidcrew_launch_access.dm"
#include "voidcrew_launch_cargo.dm"
#include "voidcrew_launch_fabrication.dm"
#include "voidcrew_launch_progression.dm"
#include "voidcrew_legion_cleanup.dm"
#include "voidcrew_lich.dm"
#include "voidcrew_linda_space_share.dm"
#include "voidcrew_loot.dm"
#include "voidcrew_map_packing.dm"
#include "voidcrew_mapload_floor_dir.dm"
#include "voidcrew_medical_research_links.dm"
#include "voidcrew_megafauna_aggro.dm"
#include "voidcrew_mining_input.dm"
#include "voidcrew_mining_qol.dm"
#include "voidcrew_mission_board_rewards.dm"
#include "voidcrew_mission_console_rewards.dm"
#include "voidcrew_mission_gps.dm"
#include "voidcrew_mission_metrics.dm"
#include "voidcrew_missions.dm"
#include "voidcrew_nanite_research.dm"
#include "voidcrew_npc_boarding_docking.dm"
#include "voidcrew_npc_disarm.dm"
#include "voidcrew_npc_zone_profiles.dm"
#include "voidcrew_ore_balance.dm"
#include "voidcrew_outpost_admin.dm"
#include "voidcrew_outpost_admin_bays.dm"
#include "voidcrew_outpost_admin_checkpoints.dm"
#include "voidcrew_outpost_berth_access.dm"
#include "voidcrew_outpost_bot_access.dm"
#include "voidcrew_outpost_cargo_dock.dm"
#include "voidcrew_outpost_cloning_bay.dm"
#include "voidcrew_outpost_dock_clearance.dm"
#include "voidcrew_outpost_dock_fees.dm"
#include "voidcrew_outpost_door_access.dm"
#include "voidcrew_outpost_founding.dm"
#include "voidcrew_outpost_income.dm"
#include "voidcrew_outpost_level_layout.dm"
#include "voidcrew_outpost_management.dm"
#include "voidcrew_outpost_management_lifecycle.dm"
#include "voidcrew_outpost_market_core.dm"
#include "voidcrew_outpost_market_helpers.dm"
#include "voidcrew_outpost_market_p0.dm"
#include "voidcrew_outpost_medical_lab.dm"
#include "voidcrew_outpost_network.dm"
#include "voidcrew_outpost_npc_looks.dm"
#include "voidcrew_outpost_patrol.dm"
#include "voidcrew_outpost_prison_admin.dm"
#include "voidcrew_outpost_prison_bounty.dm"
#include "voidcrew_outpost_prison_breakout.dm"
#include "voidcrew_outpost_prison_built_turrets.dm"
#include "voidcrew_outpost_prison_capture.dm"
#include "voidcrew_outpost_prison_changeling.dm"
#include "voidcrew_outpost_prison_conditions.dm"
#include "voidcrew_outpost_prison_containment.dm"
#include "voidcrew_outpost_prison_contraband.dm"
#include "voidcrew_outpost_prison_dialogue.dm"
#include "voidcrew_outpost_prison_economy.dm"
#include "voidcrew_outpost_prison_events.dm"
#include "voidcrew_outpost_prison_experiments.dm"
#include "voidcrew_outpost_prison_extension.dm"
#include "voidcrew_outpost_prison_extension_map.dm"
#include "voidcrew_outpost_prison_extras.dm"
#include "voidcrew_outpost_prison_guards.dm"
#include "voidcrew_outpost_prison_helpers.dm"
#include "voidcrew_outpost_prison_leads.dm"
#include "voidcrew_outpost_prison_life.dm"
#include "voidcrew_outpost_prison_map.dm"
#include "voidcrew_outpost_prison_needs.dm"
#include "voidcrew_outpost_prison_panic.dm"
#include "voidcrew_outpost_prison_security.dm"
#include "voidcrew_outpost_prison_social.dm"
#include "voidcrew_outpost_prison_staff.dm"
#include "voidcrew_outpost_prison_trouble.dm"
#include "voidcrew_outpost_protection.dm"
#include "voidcrew_outpost_room_power.dm"
#include "voidcrew_outpost_safe_hubs.dm"
#include "voidcrew_outpost_self_defense.dm"
#include "voidcrew_outpost_services.dm"
#include "voidcrew_outpost_ship_bay.dm"
#include "voidcrew_outpost_shop.dm"
#include "voidcrew_outpost_sized_berths.dm"
#include "voidcrew_outpost_storage.dm"
#include "voidcrew_outpost_styles.dm"
#include "voidcrew_outpost_turret_access.dm"
#include "voidcrew_outpost_turret_targeting.dm"
#include "voidcrew_outpost_upgrade_snaps.dm"
#include "voidcrew_outpost_upgrades.dm"
#include "voidcrew_outpost_yard_droids.dm"
#include "voidcrew_overmap_management.dm"
#include "voidcrew_pandora_links.dm"
#include "voidcrew_planet_anomalies.dm"
#include "voidcrew_planet_cleanup.dm"
#include "voidcrew_planet_definitions.dm"
#include "voidcrew_planet_shared_air.dm"
#include "voidcrew_planetary_factions.dm"
#include "voidcrew_player_outpost.dm"
#include "voidcrew_plumbing_shuttle_move.dm"
#include "voidcrew_puzzle_containment.dm"
#include "voidcrew_repair_robotics.dm"
#include "voidcrew_resale.dm"
#include "voidcrew_research_lifecycle.dm"
#include "voidcrew_research_movement.dm"
#include "voidcrew_respawn_timer.dm"
#include "voidcrew_rnd_kit.dm"
#include "voidcrew_round_end.dm"
#include "voidcrew_round_metrics.dm"
#include "voidcrew_ruin_bounds.dm"
#include "voidcrew_ruin_cleanup.dm"
#include "voidcrew_ruin_reservation.dm"
#include "voidcrew_ruin_turrets.dm"
#include "voidcrew_science_program.dm"
#include "voidcrew_ship_abandonment.dm"
#include "voidcrew_ship_access.dm"
#include "voidcrew_ship_assembly.dm"
#include "voidcrew_ship_communications.dm"
#include "voidcrew_ship_device_exposure.dm"
#include "voidcrew_ship_hulls.dm"
#include "voidcrew_ship_integrity.dm"
#include "voidcrew_ship_modules.dm"
#include "voidcrew_ship_orders.dm"
#include "voidcrew_ship_silicons.dm"
#include "voidcrew_ship_starting_guns.dm"
#include "voidcrew_ship_turret_targeting.dm"
#include "voidcrew_shop_catalog.dm"
#include "voidcrew_silicon_ship_systems.dm"
#include "voidcrew_simple_mob_ai.dm"
#include "voidcrew_slime_extract_piles.dm"
#include "voidcrew_smart_locker.dm"
#include "voidcrew_survey_archive.dm"
#include "voidcrew_survey_capabilities.dm"
#include "voidcrew_survey_identity.dm"
#include "voidcrew_survey_research_links.dm"
#include "voidcrew_trader_checkpoint.dm"
#include "voidcrew_trader_rental_locker.dm"
#include "voidcrew_vestige.dm"
#include "voidcrew_vestige_abductor.dm"
#include "voidcrew_vestige_ascension.dm"
#include "voidcrew_vestige_biology_routes.dm"
#include "voidcrew_vestige_changeling.dm"
#include "voidcrew_vestige_confiscation.dm"
#include "voidcrew_vestige_field.dm"
#include "voidcrew_vestige_hunts.dm"
#include "voidcrew_vestige_lifecycle.dm"
#include "voidcrew_vestige_morph.dm"
#include "voidcrew_vestige_morph_routes.dm"
#include "voidcrew_vestige_rites.dm"
#include "voidcrew_vestige_rites_routes.dm"
#include "voidcrew_vestige_routes.dm"
#include "voidcrew_vestige_status.dm"
#include "voidcrew_vestige_visuals.dm"
#include "voidcrew_wall_break_atmos.dm"
#include "voidcrew_weapon_ladder.dm"
#include "voidcrew_weather_sites.dm"
#include "voidcrew_windoor_survey.dm"
#include "voidcrew_zone_identity.dm"
#include "voidcrew_zone_logging.dm"
#include "voidcrew_zone_missions.dm"
#include "voidcrew_zone_research.dm"
#include "voidcrew_zone_shops.dm"
#include "voidcrew_zone_teleport.dm"
#include "weather_mob_targeting.dm"
// END_INCLUDE

// Z5 integration checks use the included Z2 fixtures and the real settlement pipeline.
// Fork defines follow this harness, so bands and permissions below use their literal values.
/datum/unit_test/voidcrew_zone_missions/presentation
	abstract_type = /datum/unit_test/voidcrew_zone_missions/presentation
	var/list/presentation_old_pending

/datum/unit_test/voidcrew_zone_missions/presentation/New()
	. = ..()
	presentation_old_pending = SSmetrics.pending
	SSmetrics.pending = list()
	SSmetrics.accepting = TRUE

/datum/unit_test/voidcrew_zone_missions/presentation/Destroy()
	var/restore_accepting = old_metrics
	old_metrics = FALSE
	SSmetrics.accepting = FALSE
	. = ..()
	SSmetrics.accepting = restore_accepting
	SSmetrics.pending = presentation_old_pending

/// One receipt, its accepting crew and a single crossing survive aliases and a hull crew change.
/datum/unit_test/voidcrew_zone_missions/presentation/receipts/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	record.claim_zone_work("hunt", 1, 1, "metric_setup_hunt")
	record.claim_zone_work("capture", 1, 1, "metric_setup_capture")
	var/datum/mission/mission = allocate(/datum/mission/recovery/kill/zone_missions_test)
	var/datum/mission/alias = allocate(/datum/mission/recovery/kill/outpost/zone_missions_test)
	alias.work_receipt = mission.work_receipt
	SSmetrics.pending = list()
	TEST_ASSERT(mission.start_mission(ship), "Metric fixture did not accept work")
	TEST_ASSERT(alias.start_mission(ship), "Metric fixture did not accept its encounter alias")
	var/list/row = SSmetrics.pending[1]
	var/list/details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["crew_id"], record.crew_id, "Acceptance omitted its continuing crew")
	TEST_ASSERT_EQUAL(details["work_receipt_serial"], mission.work_receipt.serial, "Acceptance omitted the receipt serial")
	TEST_ASSERT_EQUAL(details["work_family"], "named_kill", "Acceptance used the prize family instead of the canonical work family")
	TEST_ASSERT_EQUAL(details["work_band"], "green", "Acceptance omitted its pinned work band")
	var/obj/structure/overmap/ship/other = make_ship()
	var/datum/voidcrew_crew_record/different = other.get_crew_record()
	ship.ship_team.set_crew_record(different)
	SSmetrics.pending = list()
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, null), "Metric fixture did not settle")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 3, "A new permission needs one claim, one crossing and one ordinary payout row")
	row = SSmetrics.pending[1]
	details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(row["event"], "zone_work_claimed", "Claim diagnostics were not logged")
	TEST_ASSERT_EQUAL(row["points"], 1, "Metric gain differs from the capped award")
	TEST_ASSERT_EQUAL(row["credits"], 0, "A claim diagnostic duplicated mission money")
	TEST_ASSERT_EQUAL(details["crew_id"], record.crew_id, "A hull crew change redirected metric attribution")
	TEST_ASSERT_EQUAL(details["attempted_gain"], 1, "Claim diagnostics omitted the attempted award")
	TEST_ASSERT_EQUAL(details["capped_gain"], 0, "An uncapped award was reported as clamped")
	TEST_ASSERT_EQUAL(details["permission_before"], 0, "Wrong permission before settlement")
	TEST_ASSERT_EQUAL(details["permission_after"], 1, "Wrong permission after settlement")
	row = SSmetrics.pending[2]
	TEST_ASSERT_EQUAL(row["event"], "zone_permission_crossed", "The permission crossing was not logged")
	TEST_ASSERT_EQUAL(row["subject"], "Yellow", "The crossing named the wrong permission")
	TEST_ASSERT_EQUAL(row["round_seconds"], metric_round_seconds(), "The access timestamp differs from the settlement time")
	row = SSmetrics.pending[3]
	details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(row["event"], "mission_completed", "Ordinary reward metrics disappeared")
	TEST_ASSERT_EQUAL(row["credits"], 100, "Progression logging changed the existing payout")
	TEST_ASSERT_EQUAL(details["zone_gain"], 1, "The payout row omitted its credited gain")
	SSmetrics.pending = list()
	TEST_ASSERT(alias.turn_in(run_loc_floor_bottom_left, null), "The alias lost its ordinary reward")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 1, "An alias duplicated claim or permission metrics")
	row = SSmetrics.pending[1]
	details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(details["zone_gain"], 0, "The alias payout counted the original gain again")
	ship.ship_team.set_crew_record(record)
	var/datum/mission/capped = allocate(/datum/mission/recovery/kill/zone_missions_test)
	TEST_ASSERT(capped.start_mission(ship), "Capped family prevented ordinary acceptance")
	SSmetrics.pending = list()
	TEST_ASSERT(capped.turn_in(run_loc_floor_bottom_left, null), "Capped family prevented ordinary settlement")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 2, "Capped work needs a claim and payout, without another crossing")
	row = SSmetrics.pending[1]
	details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(row["points"], 0, "Capped work metrics invented a gain")
	TEST_ASSERT_EQUAL(details["capped_gain"], 1, "Fully capped work was not reported")
	TEST_ASSERT_EQUAL(record.zone_totals["1"], 3, "Metrics changed the crew ledger")

/// Higher permissions and a partial family clamp report the same gains as the real ledger.
/datum/unit_test/voidcrew_zone_missions/presentation/higher_permissions/Run()
	var/obj/structure/overmap/ship/ship = make_ship(1)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	record.claim_zone_work("hunt", 2, 3, "yellow_hunt_hard")
	record.claim_zone_work("hunt", 2, 1, "yellow_hunt_easy")
	record.claim_zone_work("capture", 2, 1, "yellow_capture")
	var/datum/mission/yellow = allocate(/datum/mission/big_game_hunt/zone_missions_test, null, 2)
	TEST_ASSERT(yellow.start_mission(ship), "Eligible yellow work was refused")
	SSmetrics.pending = list()
	TEST_ASSERT(yellow.turn_in(run_loc_floor_bottom_left, null), "Yellow work did not settle")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 3, "Advanced permission crossing was not logged once")
	var/list/row = SSmetrics.pending[1]
	var/list/details = json_decode(row["details"])
	TEST_ASSERT_EQUAL(row["points"], 1, "Partially capped yellow gain was not recorded")
	TEST_ASSERT_EQUAL(details["attempted_gain"], 2, "Medium work has the wrong attempted gain")
	TEST_ASSERT_EQUAL(details["capped_gain"], 1, "Partial clamp amount was not recorded")
	row = SSmetrics.pending[2]
	TEST_ASSERT_EQUAL(row["subject"], "Advanced", "Yellow work logged the wrong new permission")
	record.claim_zone_work("named_kill", 3, 3, "red_kill_first")
	record.claim_zone_work("named_kill", 3, 3, "red_kill_second")
	record.claim_zone_work("capture", 3, 3, "red_capture")
	var/datum/mission/red = allocate(/datum/mission/big_game_hunt/zone_missions_test, null, 3)
	TEST_ASSERT(red.start_mission(ship), "Eligible red work was refused")
	SSmetrics.pending = list()
	TEST_ASSERT(red.turn_in(run_loc_floor_bottom_left, null), "Red work did not settle")
	TEST_ASSERT_EQUAL(length(SSmetrics.pending), 3, "Elite permission crossing was not logged once")
	row = SSmetrics.pending[1]
	TEST_ASSERT_EQUAL(row["points"], 3, "Red work metrics changed the hard-work gain")
	row = SSmetrics.pending[2]
	TEST_ASSERT_EQUAL(row["subject"], "Elite", "Red work logged the wrong new permission")

/// Admin edits preserve caps and shared identity; resetting cannot replay spent encounters.
/datum/unit_test/voidcrew_zone_missions/presentation/admin_record/Run()
	var/obj/structure/overmap/ship/first = make_ship()
	var/obj/structure/overmap/ship/second = make_ship()
	var/datum/voidcrew_crew_record/record = first.get_crew_record()
	second.ship_team.set_crew_record(record)
	var/id_before = record.crew_id
	TEST_ASSERT(!record.admin_set_zone_family("waves", 1, 1), "Admin accepted a noncanonical family")
	TEST_ASSERT(!record.admin_set_zone_family("hunt", 99, 1), "Admin accepted an unknown band")
	TEST_ASSERT(!record.admin_set_zone_family("hunt", 1, 2), "Admin exceeded the green family cap")
	TEST_ASSERT(!record.admin_set_zone_family("hunt", 2, 6), "Admin exceeded the danger family cap")
	TEST_ASSERT(!record.admin_set_zone_family("hunt", 2, -1), "Admin accepted negative standing")
	TEST_ASSERT(!record.admin_set_zone_family("hunt", 2, 1.5), "Admin accepted fractional standing")
	for(var/family in list("named_kill", "hunt", "capture"))
		TEST_ASSERT(record.admin_set_zone_family(family, 1, 1), "Admin could not set a valid family contribution")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 1, "Admin totals did not derive the correct permission")
	TEST_ASSERT(record.admin_set_zone_family("hunt", 2, 5), "Admin could not set the yellow cap")
	TEST_ASSERT(record.admin_set_zone_family("capture", 2, 1), "Admin could not set a second yellow family")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 2, "Admin totals did not open advanced access")
	TEST_ASSERT(record.admin_set_zone_family("hunt", 2, 2), "Admin could not lower a contribution")
	TEST_ASSERT_EQUAL(record.zone_totals["2"], 3, "Admin edits added to the old total instead of recomputing it")
	record.claim_zone_work("extraction", 1, 1, "spent_before_reset")
	record.trader_favor[/datum/outpost_shop] = 6
	record.claim_purchase(/datum/shop_sku/favor)
	TEST_ASSERT(record.admin_reset_zone_record(), "Admin could not reset the record")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 0, "Reset left zone access open")
	TEST_ASSERT_EQUAL(record.crew_id, id_before, "Reset replaced the continuing crew identity")
	TEST_ASSERT_EQUAL(first.get_crew_record(), record, "Reset detached the first hull")
	TEST_ASSERT_EQUAL(second.get_crew_record(), record, "Reset detached the second hull")
	TEST_ASSERT_EQUAL(length(record.trader_favor), 0, "Reset left trader favor behind")
	TEST_ASSERT_EQUAL(length(record.favor_unique_purchases), 0, "Reset left purchase history behind")
	TEST_ASSERT(record.settlement_claims["spent_before_reset"], "Reset forgot a spent encounter")
	TEST_ASSERT_EQUAL(record.claim_zone_work("extraction", 1, 1, "spent_before_reset"), 0, "Reset enabled a spent encounter replay")
	for(var/band in record.zone_families)
		var/list/families = record.zone_families[band]
		TEST_ASSERT_EQUAL(record.zone_totals[band], 0, "Reset left a band total behind")
		for(var/family in families)
			TEST_ASSERT_EQUAL(families[family], 0, "Reset left a family contribution behind")
