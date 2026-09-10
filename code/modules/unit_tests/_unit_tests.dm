//include unit test files in this module in this ifdef
//Keep this sorted alphabetically

#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// For advanced cases, fail unconditionally but don't return (so a test can return multiple results)
#define TEST_FAIL(reason) (Fail(reason || "No reason", __FILE__, __LINE__))

/// Asserts that a condition is true
/// If the condition is not true, fails the test
#define TEST_ASSERT(assertion, reason) if (!(assertion)) { return Fail("Assertion failed: [reason || "No reason"]", __FILE__, __LINE__) }

/// Asserts that a parameter is not null
#define TEST_ASSERT_NOTNULL(a, reason) if (isnull(a)) { return Fail("Expected non-null value: [reason || "No reason"]", __FILE__, __LINE__) }

/// Asserts that a parameter is null
#define TEST_ASSERT_NULL(a, reason) if (!isnull(a)) { return Fail("Expected null value but received [a]: [reason || "No reason"]", __FILE__, __LINE__) }

/// Asserts that the two parameters passed are equal, fails otherwise
/// Optionally allows an additional message in the case of a failure
#define TEST_ASSERT_EQUAL(a, b, message) do { \
	var/lhs = ##a; \
	var/rhs = ##b; \
	if (lhs != rhs) { \
		return Fail("Expected [isnull(lhs) ? "null" : lhs] to be equal to [isnull(rhs) ? "null" : rhs].[message ? " [message]" : ""]", __FILE__, __LINE__); \
	} \
} while (FALSE)

/// Asserts that the two parameters passed are not equal, fails otherwise
/// Optionally allows an additional message in the case of a failure
#define TEST_ASSERT_NOTEQUAL(a, b, message) do { \
	var/lhs = ##a; \
	var/rhs = ##b; \
	if (lhs == rhs) { \
		return Fail("Expected [isnull(lhs) ? "null" : lhs] to not be equal to [isnull(rhs) ? "null" : rhs].[message ? " [message]" : ""]", __FILE__, __LINE__); \
	} \
} while (FALSE)

/// *Only* run the test provided within the parentheses
/// This is useful for debugging when you want to reduce noise, but should never be pushed
/// Intended to be used in the manner of `TEST_FOCUS(/datum/unit_test/math)`
#define TEST_FOCUS(test_path) ##test_path { focus = TRUE; }

/// Logs a noticable message on GitHub, but will not mark as an error.
/// Use this when something shouldn't happen and is of note, but shouldn't block CI.
/// Does not mark the test as failed.
#define TEST_NOTICE(source, message) source.log_for_test((##message), "notice", __FILE__, __LINE__)

/// Constants indicating unit test completion status
#define UNIT_TEST_PASSED 0
#define UNIT_TEST_FAILED 1
#define UNIT_TEST_SKIPPED 2

#define TEST_PRE 0
#define TEST_DEFAULT 1
/// After most test steps, used for tests that run long so shorter issues can be noticed faster
#define TEST_LONGER 10
/// This must be the one of last tests to run due to the inherent nature of the test iterating every single tangible atom in the game and qdeleting all of them (while taking long sleeps to make sure the garbage collector fires properly) taking a large amount of time.
#define TEST_CREATE_AND_DESTROY 9001
/**
 * For tests that rely on create and destroy having iterated through every (tangible) atom so they don't have to do something similar.
 * Keep in mind tho that create and destroy will absolutely break the test platform, anything that relies on its shape cannot come after it.
 */
#define TEST_AFTER_CREATE_AND_DESTROY INFINITY

/// Change color to red on ANSI terminal output, if enabled with -DANSICOLORS.
#ifdef ANSICOLORS
#define TEST_OUTPUT_RED(text) "\x1B\x5B1;31m[text]\x1B\x5B0m"
#else
#define TEST_OUTPUT_RED(text) (text)
#endif
/// Change color to green on ANSI terminal output, if enabled with -DANSICOLORS.
#ifdef ANSICOLORS
#define TEST_OUTPUT_GREEN(text) "\x1B\x5B1;32m[text]\x1B\x5B0m"
#else
#define TEST_OUTPUT_GREEN(text) (text)
#endif
/// Change color to yellow on ANSI terminal output, if enabled with -DANSICOLORS.
#ifdef ANSICOLORS
#define TEST_OUTPUT_YELLOW(text) "\x1B\x5B1;33m[text]\x1B\x5B0m"
#else
#define TEST_OUTPUT_YELLOW(text) (text)
#endif
/// A trait source when adding traits through unit tests
#define TRAIT_SOURCE_UNIT_TESTS "unit_tests"
/// Helper to allocate a new object with the implied type (the type of the variable it's assigned to) in the corner of the test room
#define EASY_ALLOCATE(arguments...) allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left, ##arguments)

// BEGIN_INCLUDE
#include "abductor_baton_spell.dm"
#include "ablative_hud.dm"
#include "achievements.dm"
#include "anchored_mobs.dm"
#include "anonymous_themes.dm"
#include "antag_conversion.dm"
#include "antag_moodlets.dm"
#include "area_contents.dm"
#include "armor_verification.dm"
#include "asset_smart_cache.dm"
#include "atmos_component_pipeline.dm"
#include "atmospherics_sanity.dm"
#include "autowiki.dm"
#include "bake_a_cake.dm"
#include "barsigns.dm"
#include "baseturfs.dm"
#include "bee.dm"
#include "bespoke_id.dm"
#include "binary_insert.dm"
#include "bitrunning.dm"
#include "blindness.dm"
#include "bloody_footprints.dm"
#include "breath.dm"
#include "burning.dm"
#include "cable_powernets.dm"
#include "can_see.dm"
#include "card_mismatch.dm"
#include "cardboard_cutouts.dm"
#include "cargo_crate_sanity.dm"
#include "cargo_dep_order_locations.dm"
#include "cargo_selling.dm"
#include "chain_pull_through_space.dm"
#include "changeling.dm"
#include "chat_filter.dm"
#include "circuit_component_category.dm"
#include "client_colours.dm"
#include "closets.dm"
#include "clothing_drops_items.dm"
#include "clothing_under_armor_subtype_check.dm"
#include "combat.dm"
#include "combat_blocking.dm"
#include "combat_cuffs.dm"
#include "combat_eyestab.dm"
#include "combat_flash.dm"
#include "combat_help.dm"
#include "combat_pistol_whip.dm"
#include "combat_stamina.dm"
#include "combat_welder.dm"
#include "component_tests.dm"
#include "confusion.dm"
#include "connect_loc.dm"
#include "container_sanity.dm"
#include "crafting.dm"
#include "crayons.dm"
#include "create_and_destroy.dm"
#include "damp_rag.dm"
#include "dcs_check_list_arguments.dm"
#include "dcs_get_id_from_elements.dm"
#include "designs.dm"
#include "dismemberment.dm"
#include "dna_infusion.dm"
#include "door_access.dm"
#include "dragon_expiration.dm"
#include "drink_icons.dm"
#include "dropper.dm"
#include "dummy_spawn.dm"
#include "dynamic_ruleset_sanity.dm"
#include "egg_glands.dm"
#include "embedding.dm"
#include "emoting.dm"
#include "emp_flashlight.dm"
#include "ensure_subtree_operational_datum.dm"
#include "ethereal_revival.dm"
#include "explosion_action.dm"
#include "firedoor_regions.dm"
#include "fish_unit_tests.dm"
#include "focus_only_tests.dm"
#include "font_awesome_icons.dm"
#include "food_edibility_check.dm"
#include "full_heal.dm"
#include "gas_connector_lifecycle.dm"
#include "gas_transfer.dm"
#include "pipeline_reconciliation.dm"
#include "get_turf_pixel.dm"
#include "geyser.dm"
#include "glass_floor_baseturfs.dm"
#include "gloves_and_shoes_armor.dm"
#include "greyscale_config.dm"
#include "hallucination_icons.dm"
#include "heretic_knowledge.dm"
#include "heretic_rituals.dm"
#include "high_five.dm"
#include "holder_loving.dm"
#include "holidays.dm"
#include "holofan_placement.dm"
#include "hulk.dm"
#include "human_through_recycler.dm"
#include "hunger_curse.dm"
#include "hydroponics_extractor_storage.dm"
#include "hydroponics_harvest.dm"
#include "hydroponics_self_mutations.dm"
#include "hydroponics_validate_genes.dm"
#include "inhands.dm"
#include "interaction_door.dm"
#include "interaction_silicon.dm"
#include "interaction_structures.dm"
#include "json_savefile_importing.dm"
#include "keybinding_init.dm"
#include "kinetic_crusher.dm"
#include "knockoff_component.dm"
#include "language_transfer.dm"
#include "late_initialization_reentry.dm"
#include "leash.dm"
#include "lesserform.dm"
#include "limbsanity.dm"
#include "ling_decap.dm"
#include "liver.dm"
#include "load_map_security.dm"
#include "lootpanel.dm"
#include "lungs.dm"
#include "machine_disassembly.dm"
#include "mafia.dm"
#include "map_landmarks.dm"
#include "map_parser_attributes.dm"
#include "mapload_space_verification.dm"
#include "mapping.dm"
#include "mapping_nearstation_test.dm"
#include "market.dm"
#include "mecha_damage.dm"
#include "medical_wounds.dm"
#include "merge_type.dm"
#include "metabolizing.dm"
#include "mindbound_actions.dm"
#include "missing_icons.dm"
#include "mob_chains.dm"
#include "mob_damage.dm"
#include "mob_faction.dm"
#include "mob_spawn.dm"
#include "modify_fantasy_variable.dm"
#include "modsuit.dm"
#include "modular_map_loader.dm"
#include "monkey_business.dm"
#include "mouse_bite_cable.dm"
#include "movement_order_sanity.dm"
#include "mutant_hands_consistency.dm"
#include "mutant_organs.dm"
#include "novaflower_burn.dm"
#include "nuke_cinematic.dm"
#include "omnitools.dm"
#include "operating_table.dm"
#include "orderable_items.dm"
#include "organ_bodypart_shuffle.dm"
#include "organs.dm"
#include "orphaned_genturf.dm"
#include "outfit_sanity.dm"
#include "oxyloss_suffocation.dm"
#include "paintings.dm"
#include "pills.dm"
#include "plane_double_transform.dm"
#include "plane_dupe_detector.dm"
#include "plane_sanity.dm"
#include "plantgrowth_tests.dm"
#include "preference_species.dm"
#include "preferences.dm"
#include "prisoner_photos.dm"
#include "projectiles.dm"
#include "quirks.dm"
#include "range_return.dm"
#include "rcd.dm"
#include "reagent_container_defaults.dm"
#include "reagent_id_typos.dm"
#include "reagent_holder_teardown.dm"
#include "reagent_mob_expose.dm"
#include "reagent_mod_procs.dm"
#include "reagent_names.dm"
#include "reagent_recipe_collisions.dm"
#include "reagent_transfer.dm"
#include "required_map_items.dm"
#include "resist.dm"
#include "say.dm"
#include "screenshot_airlocks.dm"
#include "screenshot_antag_icons.dm"
#include "screenshot_basic.dm"
#include "screenshot_digi.dm"
#include "screenshot_dynamic_human_icons.dm"
#include "screenshot_high_luminosity_eyes.dm"
#include "screenshot_humanoids.dm"
#include "screenshot_husk.dm"
#include "screenshot_saturnx.dm"
#include "security_levels.dm"
#include "security_officer_distribution.dm"
#include "serving_tray.dm"
#include "shuttle_cling_lifecycle.dm"
#include "shuttle_load_ownership.dm"
#include "simple_animal_freeze.dm"
#include "siunit.dm"
#include "slime_mood.dm"
#include "slips.dm"
#include "soft_crit.dm"
#include "spawn_humans.dm"
#include "spawn_mobs.dm"
#include "species_change_clothing.dm"
#include "species_change_organs.dm"
#include "species_config_sanity.dm"
#include "species_unique_id.dm"
#include "species_whitelists.dm"
#include "spell_invocations.dm"
#include "spell_jaunt.dm"
#include "spell_mindswap.dm"
#include "spell_names.dm"
#include "spell_shapeshift.dm"
#include "spell_timestop.dm"
#include "spies.dm"
#include "spraycan.dm"
#include "spritesheets.dm"
#include "stack_singular_name.dm"
#include "station_trait_tests.dm"
#include "status_effect_validity.dm"
#include "stomach.dm"
#include "storage.dm"
#include "strange_reagent.dm"
#include "strippable.dm"
#include "stuns.dm"
#include "subsystem_init.dm"
#include "suit_storage_icons.dm"
#include "surgeries.dm"
#include "syringe_gun.dm"
#include "tail_wag.dm"
#include "teleporters.dm"
#include "throw_cleanup.dm"
#include "text.dm"
#include "tgui_create_message.dm"
#include "timer_sanity.dm"
#include "trait_addition_and_removal.dm"
#include "traitor.dm"
#include "traitor_mail_content_check.dm"
#include "trauma_granting.dm"
#include "turf_icons.dm"
#include "tutorial_sanity.dm"
#include "unit_test.dm"
#include "verify_config_tags.dm"
#include "verify_emoji_names.dm"
#include "voidcrew_ammo_box_materials.dm"
#include "voidcrew_assault_pod.dm"
#include "voidcrew_autopilot_course.dm"
#include "voidcrew_autotranslate_morph.dm"
#include "voidcrew_autotranslate_output.dm"
#include "voidcrew_bitrunning.dm"
#include "voidcrew_blueprint_guns.dm"
#include "voidcrew_colosseum.dm"
#include "voidcrew_construction_refunds.dm"
#include "voidcrew_construction_automation.dm"
#include "voidcrew_repair_robotics.dm"
#include "voidcrew_cordon_teleport.dm"
#include "voidcrew_crew_antag_gc.dm"
#include "voidcrew_crew_hud.dm"
#include "voidcrew_cyberware.dm"
#include "voidcrew_drug_lab.dm"
#include "voidcrew_drug_recipe.dm"
#include "voidcrew_dynamic_events.dm"
#include "voidcrew_fleet_waypoints.dm"
#include "voidcrew_helpers.dm"
#include "voidcrew_hull_containment.dm"
#include "voidcrew_hull_survey.dm"
#include "voidcrew_lich.dm"
#include "voidcrew_launch_access.dm"
#include "voidcrew_launch_cargo.dm"
#include "voidcrew_bank_deposits.dm"
#include "voidcrew_cargo_cart.dm"
#include "voidcrew_cargo_load_queue.dm"
#include "voidcrew_launch_fabrication.dm"
#include "voidcrew_launch_progression.dm"
#include "voidcrew_loot.dm"
#include "voidcrew_map_packing.dm"
#include "voidcrew_planetary_factions.dm"
#include "voidcrew_overmap_management.dm"
#include "voidcrew_planet_cleanup.dm"
#include "voidcrew_missions.dm"
#include "voidcrew_mining_input.dm"
#include "voidcrew_mission_gps.dm"
#include "voidcrew_npc_boarding_docking.dm"
#include "voidcrew_npc_disarm.dm"
#include "voidcrew_player_outpost.dm"
#include "voidcrew_outpost_management.dm"
#include "voidcrew_outpost_admin.dm"
#include "voidcrew_outpost_management_lifecycle.dm"
#include "voidcrew_outpost_services.dm"
#include "voidcrew_outpost_self_defense.dm"
#include "voidcrew_outpost_founding.dm"
#include "voidcrew_medical_research_links.dm"
#include "voidcrew_megafauna_aggro.dm"
#include "voidcrew_nanite_research.dm"
#include "voidcrew_research_lifecycle.dm"
#include "voidcrew_research_movement.dm"
#include "voidcrew_science_program.dm"
#include "voidcrew_survey_research_links.dm"
#include "voidcrew_survey_archive.dm"
#include "voidcrew_survey_identity.dm"
#include "voidcrew_survey_capabilities.dm"
#include "voidcrew_camera_scope.dm"
#include "voidcrew_ruin_bounds.dm"
#include "voidcrew_ruin_reservation.dm"
#include "voidcrew_ship_abandonment.dm"
#include "voidcrew_ship_access.dm"
#include "voidcrew_ship_assembly.dm"
#include "voidcrew_ship_communications.dm"
#include "voidcrew_ship_hulls.dm"
#include "voidcrew_ship_integrity.dm"
#include "voidcrew_ship_modules.dm"
#include "voidcrew_ship_turret_targeting.dm"
#include "voidcrew_shop_catalog.dm"
#include "voidcrew_silicon_ship_systems.dm"
#include "voidcrew_simple_mob_ai.dm"
#include "voidcrew_smart_locker.dm"
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
#include "voidcrew_weather_sites.dm"
#include "voidcrew_zone_logging.dm"
#include "washing.dm"
#include "weather_mob_targeting.dm"
#include "weird_food.dm"
#include "wizard_loadout.dm"
#include "worn_icons.dm"
// END_INCLUDE
#ifdef REFERENCE_TRACKING_DEBUG //Don't try and parse this file if ref tracking isn't turned on. IE: don't parse ref tracking please mr linter
#include "find_reference_sanity.dm"
#endif

#undef TEST_ASSERT
#undef TEST_ASSERT_EQUAL
#undef TEST_ASSERT_NOTEQUAL
//#undef TEST_FOCUS - This define is used by vscode unit test extension to pick specific unit tests to run and appended later so needs to be used out of scope here
#endif
