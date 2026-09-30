/// These reachable kits and artifacts need visible hand art, including grown ABSTRACT weapons.
/datum/unit_test/vestige_held_item_visuals/Run()
	var/list/held_items = list(
		/obj/item/borrowed_name,
		/obj/item/clothing/neck/vestige_specimen_collar,
		/obj/item/oracle_slate,
		/obj/item/vestige_blood_votive,
		/obj/item/vestige_calling_card,
		/obj/item/vestige_candle,
		/obj/item/vestige_censer,
		/obj/item/vestige_census_stinger,
		/obj/item/vestige_chalk,
		/obj/item/vestige_chrism,
		/obj/item/vestige_clan_seal,
		/obj/item/vestige_cloth,
		/obj/item/vestige_comb_egg,
		/obj/item/vestige_comb_spinneret,
		/obj/item/vestige_debris,
		/obj/item/vestige_debris_harness,
		/obj/item/vestige_dragon_egg,
		/obj/item/vestige_egg,
		/obj/item/vestige_field_manual,
		/obj/item/vestige_gambrel,
		/obj/item/vestige_geode,
		/obj/item/vestige_gloom_glass,
		/obj/item/vestige_graft_kit,
		/obj/item/vestige_keepsake,
		/obj/item/vestige_lantern,
		/obj/item/vestige_larder_bundle,
		/obj/item/vestige_morph_invitation,
		/obj/item/vestige_observation_lens,
		/obj/item/vestige_palm_anchor,
		/obj/item/vestige_primer,
		/obj/item/vestige_probe_baton,
		/obj/item/vestige_proboscis,
		/obj/item/vestige_quill,
		/obj/item/vestige_recovery_tether,
		/obj/item/vestige_rending_claw,
		/obj/item/vestige_rending_claw/butchers,
		/obj/item/vestige_second_skin,
		/obj/item/vestige_shard,
		/obj/item/vestige_snare_spinneret,
		/obj/item/vestige_syllable,
		/obj/item/vestige_threshold_weight,
		/obj/item/vestige_toll_casket,
		/obj/item/vestige_tremor_spool,
		/obj/item/vestige_wrap_spool,
		/obj/item/warframe_actuator,
		/obj/item/warframe_contact_plate,
	)
	for(var/obj/item/item_path as anything in held_items)
		var/held_state = initial(item_path.inhand_icon_state) || initial(item_path.icon_state)
		var/left_file = initial(item_path.lefthand_file)
		var/right_file = initial(item_path.righthand_file)
		if(!left_file || !(held_state in icon_states(left_file, 1)))
			TEST_FAIL("[item_path] has no left-hand sprite for '[held_state]' in [left_file].")
		if(!right_file || !(held_state in icon_states(right_file, 1)))
			TEST_FAIL("[item_path] has no right-hand sprite for '[held_state]' in [right_file].")

/// The actual damage status must create a warning with a real drawable icon state.
/datum/unit_test/vestige_vitriol_alert_visual/Run()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/datum/status_effect/vestige_vitriol_coating/coating = victim.apply_status_effect(/datum/status_effect/vestige_vitriol_coating)
	TEST_ASSERT(coating, "The actual acid coating must apply before checking its warning.")
	var/atom/movable/screen/alert/warning = coating.linked_alert
	TEST_ASSERT(warning && warning.icon, "The acid coating must create its actual HUD warning.")
	TEST_ASSERT((warning.icon_state in icon_states(warning.icon, 1)), "The active acid warning selected a missing state and rendered as an empty alert.")
	qdel(coating)
	TEST_ASSERT(QDELETED(warning), "Removing the acid must retire its warning.")

/// Use the real map preloader and deferred map initialization, without loading an entire ruin.
/datum/unit_test/vestige_mapped_graffiti_description/Run()
	var/clue = "Two stick figures holding hands, drawn low to the floor. The taller one has too many eyes."
	SSatoms.map_loader_begin(REF(src))
	world.preloader_setup(list(
		"name" = "crude drawing",
		"desc" = clue,
		"icon_state" = "stickman",
	), /obj/effect/decal/cleanable/crayon)
	var/obj/effect/decal/cleanable/crayon/mapped_clue = allocate(/obj/effect/decal/cleanable/crayon)
	SSatoms.map_loader_stop(REF(src))
	SSatoms.InitializeAtoms(list(mapped_clue))
	TEST_ASSERT(mapped_clue.flags_1 & INITIALIZED_1, "The mapped clue must finish normal map initialization.")
	TEST_ASSERT_EQUAL(mapped_clue.name, "crude drawing", "The map preloader did not apply the Menagerie drawing's name.")
	TEST_ASSERT_EQUAL(mapped_clue.icon_state, "stickman", "The map preloader did not apply the Menagerie drawing's sprite.")
	TEST_ASSERT_EQUAL(mapped_clue.desc, clue, "Crayon initialization erased the Menagerie's mapped story clue.")

	var/obj/effect/decal/cleanable/crayon/plain = allocate(/obj/effect/decal/cleanable/crayon, run_loc_floor_bottom_left, null, "rune4", "chalk warning")
	TEST_ASSERT_EQUAL(plain.desc, "A chalk warning vandalizing the station.", "Ordinary player-drawn graffiti must still describe its chosen drawing.")
	var/obj/effect/decal/cleanable/crayon/custom_drawing = allocate(/obj/effect/decal/cleanable/crayon, run_loc_floor_bottom_left, null, "rune4", "chalk warning", null, null, "An explicit drawing description.")
	TEST_ASSERT_EQUAL(custom_drawing.desc, "An explicit drawing description.", "Explicit drawing descriptions must still take precedence.")
