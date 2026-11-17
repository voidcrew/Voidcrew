// Xenoarchaeology tests: core.
//
// Test files compile before voidcrew/_DEFINES, so the values below are literals. They mirror
// voidcrew/_DEFINES/xenoarch.dm:
//   bands (ZONE_*): green 1, yellow 2, red 3
//   tiers: common 1, uncommon 2, rare 3, extreme 4
//   triggers: touch 1, water 2, acid 4, volatile 8, toxin 16, impact 32, energy 64,
//             heat 128, cold 256, plasma 512, co2 1024, proximity 2048
//   release methods: "touch", "aura", "pulse"

/// Sale price: the design's worked examples, the label floor, condition and rounding.
/datum/unit_test/voidcrew_xenoarch_price/Run()
	TEST_ASSERT_EQUAL(xenoarch_price_for(1, 1, 1), 250, "green common, perfect label")
	TEST_ASSERT_EQUAL(xenoarch_price_for(2, 3, 1), 1125, "yellow rare, perfect label")
	TEST_ASSERT_EQUAL(xenoarch_price_for(3, 3, 1), 1750, "red rare, perfect label")
	TEST_ASSERT_EQUAL(xenoarch_price_for(3, 4, 1), 2800, "red extreme, perfect label")
	TEST_ASSERT_EQUAL(xenoarch_price_for(3, 1, 0), 140, "red common, unlabelled")
	TEST_ASSERT_EQUAL(xenoarch_price_for(3, 1, 0.3), 140, "a label under half right pays the unlabelled rate")
	TEST_ASSERT_EQUAL(xenoarch_price_for(3, 1, 0.5), 350, "a half-right label pays half")
	TEST_ASSERT_EQUAL(xenoarch_price_for(3, 1, 0.5 + 0.3 + 0.2), 700, "a perfect label summed in floating point pays in full")
	TEST_ASSERT_EQUAL(xenoarch_price_for(2, 1, 1, TRUE), 225, "damaged halves the price")
	TEST_ASSERT_EQUAL(xenoarch_price_for(1, 1, 1, FALSE, 3), 130, "three harvests take 0.8 cubed, rounded to 5")
	TEST_ASSERT_EQUAL(xenoarch_price_for(null, 1, 1), 250, "an unknown band prices as green")
	TEST_ASSERT_EQUAL(xenoarch_research_points(1, 1), 100, "green research")
	TEST_ASSERT_EQUAL(xenoarch_research_points(3, 3), 375, "red rare research")

	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	find.replace_effects(/datum/artifact_effect/heal, null, 2)
	TEST_ASSERT_EQUAL(artifact_sale_value(find), 0, "a find never dug sold for credits")
	TEST_ASSERT_EQUAL(artifact_research_value(find), 0, "a find never dug paid research")
	find.stamp_origin(2)
	TEST_ASSERT_EQUAL(artifact_research_value(find), 150, "a dug yellow uncommon find pays the wrong research")
	TEST_ASSERT(!find.stamp_origin(3), "a second stamp replaced the first")
	TEST_ASSERT_EQUAL(artifact_sale_value(find), 135, "an unlabelled yellow uncommon find")
	var/trigger_word = artifact_trigger_name(find.main_effect.trigger)
	find.apply_label(new /datum/artifact_label("Heals", trigger_word, "None"))
	TEST_ASSERT_EQUAL(find.label_accuracy(), 1, "a perfect label did not read as perfect")
	TEST_ASSERT_EQUAL(artifact_sale_value(find), 675, "a perfectly labelled yellow uncommon find")
	find.apply_label(new /datum/artifact_label("Heals", trigger_word, "Light"))
	TEST_ASSERT_EQUAL(artifact_sale_value(find), 540, "a wrong second effect costs a fifth")
	find.damaged = TRUE
	find.harvests_left = 2
	TEST_ASSERT_EQUAL(artifact_sale_value(find), 215, "damaged and harvested once")
	find.research_paid = TRUE
	TEST_ASSERT_EQUAL(artifact_research_value(find), 0, "research paid twice for one artifact")

/// Every rollable effect is complete, every tier can roll, and the free-power fix holds.
/datum/unit_test/voidcrew_xenoarch_catalogue/Run()
	var/list/tiers_seen = list()
	for(var/datum/artifact_effect/effect_type as anything in artifact_effect_types())
		var/datum/artifact_effect/effect = new effect_type(null, 1)
		TEST_ASSERT(effect.tier >= 1 && effect.tier <= 4, "[effect_type] has tier [effect.tier]")
		TEST_ASSERT(!effect.minor || effect.tier <= 2, "[effect_type] is minor above uncommon")
		TEST_ASSERT(length(effect.allowed_release_methods), "[effect_type] can't release at all")
		TEST_ASSERT(effect.release_method in list("touch", "aura", "pulse"), "[effect_type] rolled release [effect.release_method]")
		TEST_ASSERT(GLOB.artifact_energy_kinds[effect.energy_kind], "[effect_type] rolled unknown energy kind [effect.energy_kind]")
		TEST_ASSERT(effect.trigger in list(1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048), "[effect_type] rolled trigger [effect.trigger]")
		TEST_ASSERT(effect.label_name in artifact_effect_label_names(), "[effect_type]'s label is missing from the labeler words")
		TEST_ASSERT(!(effect.helpful && effect.harmful), "[effect_type] is both helpful and harmful")
		tiers_seen |= effect.tier
		qdel(effect)
	for(var/tier in 1 to 4)
		TEST_ASSERT(tier in tiers_seen, "no effect can roll at tier [tier]")
		TEST_ASSERT(xenoarch_pick_effect_type(tier, 1), "picking a tier [tier] effect found nothing")
	TEST_ASSERT(xenoarch_pick_effect_type(null, 3, minor_only = TRUE), "no minor second effect can roll")
	var/datum/artifact_effect/tesla/tesla = new(null, 3)
	TEST_ASSERT(!(tesla.zap_flags & ZAP_GENERATES_POWER), "the tesla effect powers tesla coils")
	qdel(tesla)

	// Deeper bands roll stronger effects (2000 rolls each; the means are about 1.5 and 2.15).
	var/green_total = 0
	var/red_total = 0
	for(var/i in 1 to 2000)
		green_total += xenoarch_roll_tier(1)
		red_total += xenoarch_roll_tier(3)
	TEST_ASSERT(red_total > green_total * 1.2, "red tier rolls ([red_total]) are not clearly above green ([green_total])")

/// Triggers: only the matching stimulus wakes an effect, wakes lapse, and a crated find never stirs.
/datum/unit_test/voidcrew_xenoarch_triggers/Run()
	TEST_ASSERT_EQUAL(artifact_reagent_trigger(/datum/reagent/water), 2, "water is not a water trigger")
	TEST_ASSERT_EQUAL(artifact_reagent_trigger(/datum/reagent/hydrogen), 2, "hydrogen is not a water trigger")
	TEST_ASSERT_EQUAL(artifact_reagent_trigger(/datum/reagent/toxin/acid), 4, "acid is not an acid trigger")
	TEST_ASSERT_EQUAL(artifact_reagent_trigger(/datum/reagent/toxin/plasma), 8, "liquid plasma is not volatile")
	TEST_ASSERT_EQUAL(artifact_reagent_trigger(/datum/reagent/toxin), 16, "toxin is not a toxin trigger")
	TEST_ASSERT_EQUAL(artifact_reagent_trigger(/datum/reagent/consumable/sugar), 0, "sugar set something off")
	TEST_ASSERT_EQUAL(artifact_reagent_triggers(list(/datum/reagent/water, /datum/reagent/toxin/acid)), 6, "a mixture should count as both")

	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	find.replace_effects(/datum/artifact_effect/temperature/heat, /datum/artifact_effect/light, 1)
	find.main_effect.trigger = 2
	find.second_effect.trigger = 32
	TEST_ASSERT(!find.stimulate(1), "touch matched a water trigger")
	TEST_ASSERT(!find.is_active(), "a wrong stimulus woke it")
	TEST_ASSERT(find.stimulate(2), "water did not match a water trigger")
	TEST_ASSERT(find.main_effect.activated, "water did not wake the main effect")
	TEST_ASSERT(!find.second_effect.activated, "water woke the impact-triggered second effect")
	TEST_ASSERT(find.shown_awake, "the artifact does not look awake")
	TEST_ASSERT_EQUAL(find.icon_state, "[find.shape]_active", "the artifact did not switch to its active sprite")
	find.main_effect.awake_until = world.time - 1
	find.process(2)
	TEST_ASSERT(!find.main_effect.activated, "an expired wake did not lapse")
	TEST_ASSERT_EQUAL(find.icon_state, find.shape, "the artifact kept its active sprite asleep")

	// The glove rule.
	var/mob/living/carbon/human/consistent/tester = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(artifact_touch_counts(tester), "a bare hand did not count as touch")
	var/obj/item/clothing/gloves/latex/latex = allocate(/obj/item/clothing/gloves/latex)
	tester.equip_to_slot_if_possible(latex, ITEM_SLOT_GLOVES)
	TEST_ASSERT(!artifact_touch_counts(tester), "latex gloves counted as touch")
	qdel(latex)
	var/obj/item/clothing/gloves/color/yellow/insulated = allocate(/obj/item/clothing/gloves/color/yellow)
	tester.equip_to_slot_if_possible(insulated, ITEM_SLOT_GLOVES)
	TEST_ASSERT(artifact_touch_counts(tester), "ordinary gloves did not count as touch")
	find.main_effect.trigger = 1
	find.touched_by(tester)
	TEST_ASSERT(find.main_effect.activated, "a gloved hand did not wake a touch trigger")

	// Proximity is held while someone stands near, and only then.
	find.main_effect.deactivate(quiet = TRUE)
	find.main_effect.trigger = 2048
	tester.moveToNullspace()
	find.process(2)
	TEST_ASSERT(!find.main_effect.activated, "proximity woke with nobody near")
	tester.forceMove(get_step(find, EAST))
	find.process(2)
	TEST_ASSERT(find.main_effect.activated, "proximity did not wake with someone beside it")

	// Crated, it goes still and ignores everything.
	var/obj/structure/closet/crate/specimen/crate = allocate(/obj/structure/closet/crate/specimen, get_step(find, NORTH))
	find.forceMove(crate)
	TEST_ASSERT(!find.is_active(), "a crated find stayed awake")
	TEST_ASSERT(!find.stimulate(2048), "a crated find took a stimulus")
	find.process(2)
	TEST_ASSERT(!find.is_active(), "a crated find woke from proximity")

/// The analyser and harvester lock frees itself on release, on its holder's deletion and on timeout.
/datum/unit_test/voidcrew_xenoarch_lock/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	var/datum/analyser = allocate(/datum)
	var/datum/harvester = allocate(/datum)
	TEST_ASSERT(find.try_lock(analyser), "a free artifact refused a lock")
	TEST_ASSERT(find.is_being_used(), "a locked artifact reads as free")
	TEST_ASSERT(!find.try_lock(harvester), "a second machine took a held lock")
	TEST_ASSERT(!find.release_lock(harvester), "a machine released someone else's lock")
	TEST_ASSERT(find.release_lock(analyser), "a halted scan could not release its lock")
	TEST_ASSERT(!find.is_being_used(), "releasing left the artifact locked")
	TEST_ASSERT(find.try_lock(harvester), "a released artifact refused a new lock")
	qdel(harvester)
	TEST_ASSERT(!find.is_being_used(), "a deleted machine kept its lock")
	TEST_ASSERT(find.try_lock(analyser, 0), "could not take a lock")
	TEST_ASSERT(!find.is_being_used(), "a lock outlived its timeout")

/// Finds never ride along in a ship checkpoint or save.
/datum/unit_test/voidcrew_xenoarch_checkpoints/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	TEST_ASSERT(!outpost_checkpoint_saves(find), "a checkpoint would save a loose artifact")
	find.set_anchored(TRUE)
	TEST_ASSERT(!outpost_checkpoint_saves(find), "a checkpoint would save a bolted artifact")
	TEST_ASSERT_NULL(find.checkpoint_type(), "an artifact has a checkpoint rebuild type")
	var/obj/machinery/power/charged_crystal/crystal = allocate(/obj/machinery/power/charged_crystal)
	TEST_ASSERT(!outpost_checkpoint_saves(crystal), "a checkpoint would save a charged crystal")

/// Artifact healing shares one cap per person, whatever does the healing.
/datum/unit_test/voidcrew_xenoarch_heal_cap/Run()
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	patient.take_overall_damage(60, 60)
	var/healed = 0
	for(var/i in 1 to 6)
		healed += artifact_capped_heal(patient, 12)
	TEST_ASSERT(healed <= 30.5, "artifact healing went past the cap ([healed])")
	TEST_ASSERT(healed >= 29.5, "artifact healing stopped short of the cap ([healed])")
	TEST_ASSERT_EQUAL(artifact_capped_heal(patient, 50), 0, "a fresh call slipped past the cap")

	// A wound of one kind takes the whole heal, not half of it.
	var/mob/living/carbon/human/consistent/bruised = allocate(/mob/living/carbon/human/consistent)
	bruised.take_overall_damage(40, 0)
	var/mended = artifact_capped_heal(bruised, 12)
	TEST_ASSERT(mended >= 11.5 && mended <= 12.5, "a brute-only wound healed [mended] of 12")
	TEST_ASSERT_EQUAL(artifact_capped_heal(allocate(/mob/living/carbon/human/consistent), 12), 0, "an unhurt body used up heal")

/// Deleting an artifact deletes its effects and leaves them no holder.
/datum/unit_test/voidcrew_xenoarch_cleanup/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	find.replace_effects(/datum/artifact_effect/heal, /datum/artifact_effect/light, 1)
	var/datum/artifact_effect/main = find.main_effect
	var/datum/artifact_effect/second = find.second_effect
	main.wake(1 MINUTES)
	second.wake(1 MINUTES)
	qdel(find)
	TEST_ASSERT(QDELETED(main), "the main effect outlived its artifact")
	TEST_ASSERT(QDELETED(second), "the second effect outlived its artifact")
	TEST_ASSERT_NULL(main.holder, "the main effect kept its artifact")

/**
 * An artifact idling, or running heat and gas, on a planet never gives a planet turf private air.
 * Uses the shared planet air room from voidcrew_planet_shared_air.dm.
 */
/datum/unit_test/voidcrew_planet_shared_air/xenoarch_idle_artifact/Run()
	if(!planetary_atmos_shared_mix_enabled())
		return
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, center)
	find.replace_effects(/datum/artifact_effect/temperature/heat, /datum/artifact_effect/gas, 3)
	// Air triggers read the air every process.
	find.main_effect.trigger = 128
	find.second_effect.trigger = 1024
	TEST_ASSERT(room_is_pristine(), "placing an artifact gave the planet private air")
	for(var/i in 1 to 3)
		find.process(2)
	TEST_ASSERT(room_is_pristine(), "an idle artifact gave the planet private air")
	find.main_effect.release_method = "aura"
	find.second_effect.release_method = "aura"
	find.main_effect.wake(1 MINUTES)
	find.second_effect.wake(1 MINUTES)
	for(var/i in 1 to 3)
		find.process(2)
	TEST_ASSERT(room_is_pristine(), "heat or gas running on a planet gave it private air")
