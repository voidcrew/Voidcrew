/**
 * # Cyberware models, set B
 *
 * Hardweave plating, the Strut frame, the Deep-lung bladder, the Heat-sink and
 * Frostline linings, the Twitchwire and Weaver shunt, and the Thumper ear
 * (voidcrew/modules/cyberware/ware_models_b.dm). Each model has to share its
 * parent's slot, keep its own numbers, and leave the parent's numbers exactly
 * as they were.
 *
 * Unit-test files compile before voidcrew/_DEFINES/, so the fork's defines are
 * written as literals below: CYBERWARE_TIER_1/2/3 are 1/2/3, and the
 * unbreakable-bones trait is "cyberware_unbreakable_bones".
 */

/// Every model sits in its parent's slot with the planned load and tier, a
/// state of its own, and a description without a number in it.
/datum/unit_test/voidcrew_cyberware_models_b_slots

/datum/unit_test/voidcrew_cyberware_models_b_slots/Run()
	// model, parent, load, tier
	var/list/models = list(
		list(/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave, /obj/item/organ/cyberimp/cyberware/dermal_mesh, 3, 2),
		list(/obj/item/organ/cyberimp/cyberware/atlas/street, /obj/item/organ/cyberimp/cyberware/atlas, 2, 2),
		list(/obj/item/organ/cyberimp/cyberware/second_wind/deep, /obj/item/organ/cyberimp/cyberware/second_wind, 2, 2),
		list(/obj/item/organ/cyberimp/cyberware/coolant/street, /obj/item/organ/cyberimp/cyberware/coolant, 1, 1),
		list(/obj/item/organ/cyberimp/cyberware/frostline, /obj/item/organ/cyberimp/cyberware/coolant, 1, 1),
		list(/obj/item/organ/cyberimp/cyberware/slipwire/street, /obj/item/organ/cyberimp/cyberware/slipwire, 2, 1),
		list(/obj/item/organ/cyberimp/cyberware/slipwire/milspec, /obj/item/organ/cyberimp/cyberware/slipwire, 5, 3),
		list(/obj/item/organ/cyberimp/cyberware/doppler/street, /obj/item/organ/cyberimp/cyberware/doppler, 1, 1),
	)
	for(var/list/row as anything in models)
		var/obj/item/organ/cyberimp/cyberware/ware = allocate(row[1])
		var/obj/item/organ/cyberimp/cyberware/parent = allocate(row[2])
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		TEST_ASSERT_NOTNULL(chrome, "[ware.type] has no cyberware component")
		TEST_ASSERT_EQUAL(ware.slot, parent.slot, "[ware.type] is not in [parent.type]'s slot, so the two would stack")
		TEST_ASSERT_EQUAL(ware.zone, parent.zone, "[ware.type] is in a different body zone from [parent.type]")
		TEST_ASSERT_EQUAL(chrome.chrome_load, row[3], "[ware.type] has the wrong chrome load")
		TEST_ASSERT_EQUAL(chrome.tier, row[4], "[ware.type] has the wrong tier")
		TEST_ASSERT(!findtext(ware.desc, regex("\[0-9]")), "[ware.type]'s description has a number in it")
		TEST_ASSERT(!findtext(ware.desc, "tier") && !findtext(ware.desc, "load"), "[ware.type]'s description talks about game rules")
		if(ware.type != /obj/item/organ/cyberimp/cyberware/frostline)
			TEST_ASSERT(ware.icon_state != parent.icon_state, "[ware.type] reuses its parent's item state")
		// Where the parent has a worn look, the model has its own.
		if(parent.aug_overlay)
			TEST_ASSERT(ware.aug_overlay && ware.aug_overlay != parent.aug_overlay, "[ware.type] wears its parent's overlay")

	// The seal slot is one slot with five choices: whichever went in last is
	// the only one left.
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/list/seal_ware = list(
		/obj/item/organ/cyberimp/cyberware/second_wind,
		/obj/item/organ/cyberimp/cyberware/second_wind/deep,
		/obj/item/organ/cyberimp/cyberware/coolant/street,
		/obj/item/organ/cyberimp/cyberware/frostline,
		/obj/item/organ/cyberimp/cyberware/coolant,
	)
	var/list/placed = list()
	for(var/seal_path in seal_ware)
		var/obj/item/organ/cyberimp/cyberware/seal = allocate(seal_path)
		TEST_ASSERT(seal.Insert(patient, special = TRUE), "[seal_path] staging insert was refused")
		TEST_ASSERT_EQUAL(patient.get_organ_slot(seal.slot), seal, "[seal_path] did not take the seal slot")
		for(var/obj/item/organ/earlier as anything in placed)
			TEST_ASSERT(earlier.owner != patient, "[earlier.type] stayed in the seal slot beside [seal_path]")
		placed += seal

/// The parents run on the numbers they had before the vars existed.
/datum/unit_test/voidcrew_cyberware_models_b_parents

/datum/unit_test/voidcrew_cyberware_models_b_parents/Run()
	var/obj/item/organ/cyberimp/cyberware/second_wind/bladder = allocate(/obj/item/organ/cyberimp/cyberware/second_wind)
	TEST_ASSERT_EQUAL(bladder.reserve, 180 SECONDS, "Second Wind's reserve changed")
	TEST_ASSERT_EQUAL(bladder.max_reserve, 180 SECONDS, "Second Wind's cap changed")
	TEST_ASSERT_EQUAL(bladder.refill_rate, 16 SECONDS, "Second Wind's refill changed")

	var/obj/item/organ/cyberimp/cyberware/coolant/loops = allocate(/obj/item/organ/cyberimp/cyberware/coolant)
	TEST_ASSERT_EQUAL(loops.burn_mult, 0.5, "Coolant Loops stopped halving burns")

	var/obj/item/organ/cyberimp/cyberware/slipwire/slipwire = allocate(/obj/item/organ/cyberimp/cyberware/slipwire)
	TEST_ASSERT_EQUAL(slipwire.dodge_chance, 15, "Slipwire's dodge changed")
	TEST_ASSERT_EQUAL(slipwire.gait_modifier, /datum/movespeed_modifier/cyberware_slipwire, "Slipwire's gait changed")
	TEST_ASSERT(!findtext(slipwire.desc, "seven") && !findtext(slipwire.desc, regex("\[0-9]")), "Slipwire's description still quotes its odds")

	var/obj/item/organ/cyberimp/cyberware/doppler/doppler = allocate(/obj/item/organ/cyberimp/cyberware/doppler)
	TEST_ASSERT_EQUAL(doppler.sonar_range, 9, "Heartbeat Doppler's range changed")
	TEST_ASSERT_EQUAL(doppler.contact_fade, 4 SECONDS, "Heartbeat Doppler's fade changed")
	TEST_ASSERT_EQUAL(doppler.ping_volume_bonus, 0, "Heartbeat Doppler's ping got louder")

	var/obj/item/organ/cyberimp/cyberware/atlas/atlas = allocate(/obj/item/organ/cyberimp/cyberware/atlas)
	TEST_ASSERT_EQUAL(atlas.throw_range_bonus, 2, "Atlas Frame's throw range changed")
	TEST_ASSERT_EQUAL(atlas.throw_speed_bonus, 1, "Atlas Frame's throw speed changed")
	TEST_ASSERT(atlas.resists_knockback, "Atlas Frame stopped resisting knockback")
	// The text pass cut the examine line that explained the frame's rules.
	TEST_ASSERT_NULL(atlas.frame_examine, "Atlas Frame's examine explains its rules again")
	TEST_ASSERT(TRAIT_NODISMEMBER in atlas.organ_traits, "Atlas Frame stopped holding limbs on")
	TEST_ASSERT("cyberware_unbreakable_bones" in atlas.organ_traits, "Atlas Frame stopped holding bones together")

	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/mesh = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh)
	TEST_ASSERT_EQUAL(mesh.mesh_armor, /datum/armor/cyberware_dermal_mesh, "Dermal Mesh's plating changed")

/// Hardweave sits between the Mesh and the Slabskin Plate, and swapping it for
/// the Mesh hands back exactly the difference.
/datum/unit_test/voidcrew_cyberware_models_b_hardweave

/datum/unit_test/voidcrew_cyberware_models_b_hardweave/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave/hardweave = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave)
	var/obj/item/organ/cyberimp/cyberware/dermal_mesh/mesh = allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh)
	// melee, bullet, laser, energy, wound
	var/list/ratings = list(MELEE, BULLET, LASER, ENERGY, WOUND)
	var/list/bare = list()
	for(var/rating in ratings)
		bare[rating] = patient.physiology.armor.get_rating(rating)

	TEST_ASSERT(hardweave.Insert(patient, special = TRUE), "Hardweave staging insert was refused")
	var/list/hardweave_plus = list(20, 20, 15, 10, 10)
	for(var/index in 1 to length(ratings))
		var/rating = ratings[index]
		TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(rating), bare[rating] + hardweave_plus[index], "Hardweave gave the wrong [rating] armour")

	TEST_ASSERT(mesh.Insert(patient, special = TRUE), "Dermal Mesh staging insert was refused")
	TEST_ASSERT(!hardweave.owner, "Hardweave stayed in the dermal slot beside the Mesh")
	var/list/mesh_plus = list(15, 15, 10, 0, 5)
	for(var/index in 1 to length(ratings))
		var/rating = ratings[index]
		TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(rating), bare[rating] + mesh_plus[index], "Swapping Hardweave for the Mesh left the wrong [rating] armour")

	TEST_ASSERT(hardweave.Insert(patient, special = TRUE), "Hardweave second staging insert was refused")
	patient.emp_act(EMP_HEAVY)
	TEST_ASSERT(hardweave.organ_flags & ORGAN_FAILING, "An EMP never reached Hardweave")
	for(var/rating in ratings)
		TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(rating), bare[rating], "EMP-scrambled Hardweave kept armouring its bearer")
	var/datum/component/cyberware/chrome = hardweave.GetComponent(/datum/component/cyberware)
	chrome.tune_up()
	TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(MELEE), bare[MELEE] + 20, "A tune-up did not hand Hardweave's plating back")
	hardweave.Remove(patient, special = TRUE)
	TEST_ASSERT_EQUAL(patient.physiology.armor.get_rating(MELEE), bare[MELEE], "Pulling Hardweave left plating on the body")

/// The Strut frame holds bones and nothing else; the Atlas it undercuts still
/// holds limbs on and still throws and shrugs like a frame.
/datum/unit_test/voidcrew_cyberware_models_b_strut

/datum/unit_test/voidcrew_cyberware_models_b_strut/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/atlas/street/strut = allocate(/obj/item/organ/cyberimp/cyberware/atlas/street)
	var/obj/item/organ/cyberimp/cyberware/atlas/atlas = allocate(/obj/item/organ/cyberimp/cyberware/atlas)

	TEST_ASSERT(strut.Insert(patient, special = TRUE), "Strut frame staging insert was refused")
	TEST_ASSERT(HAS_TRAIT(patient, "cyberware_unbreakable_bones"), "The Strut frame did not keep the bones together")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_NODISMEMBER), "The Strut frame keeps limbs on")
	TEST_ASSERT_NULL(strut._signal_procs?[patient]?[COMSIG_MOB_THROW], "The Strut frame is boosting throws")
	TEST_ASSERT_NULL(strut._signal_procs?[patient]?[COMSIG_MOVABLE_PRE_THROW], "The Strut frame is resisting knockback")
	var/examined = jointext(strut.examine(patient), " ")
	TEST_ASSERT(!findtext(examined, "no losing a limb"), "The Strut frame examine still promises limbs stay on")

	// The Atlas replaces it and gets everything back.
	TEST_ASSERT(atlas.Insert(patient, special = TRUE), "Atlas staging insert was refused")
	TEST_ASSERT(!strut.owner, "The Strut frame stayed in the frame slot beside the Atlas")
	TEST_ASSERT(HAS_TRAIT(patient, "cyberware_unbreakable_bones"), "The Atlas lost its bones")
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_NODISMEMBER), "The Atlas lost its limbs")
	TEST_ASSERT_NOTNULL(atlas._signal_procs?[patient]?[COMSIG_MOB_THROW], "The Atlas stopped boosting throws")
	TEST_ASSERT_NOTNULL(atlas._signal_procs?[patient]?[COMSIG_MOVABLE_PRE_THROW], "The Atlas stopped resisting knockback")

	// And the Atlas still does the arithmetic it did.
	var/list/thrown = list(null, 8, 1, patient)
	atlas.boost_throw(null, thrown)
	TEST_ASSERT_EQUAL(thrown[2], 10, "The Atlas added the wrong range to a throw")
	TEST_ASSERT_EQUAL(thrown[3], 2, "The Atlas added the wrong speed to a throw")
	var/list/shoved = list(null, 8, 1, null)
	atlas.on_owner_thrown(patient, shoved)
	TEST_ASSERT_EQUAL(shoved[2], 4, "The Atlas stopped halving knockback")

	atlas.Remove(patient, special = TRUE)
	TEST_ASSERT(!HAS_TRAIT(patient, "cyberware_unbreakable_bones") && !HAS_TRAIT(patient, TRAIT_NODISMEMBER), "Pulling the Atlas left traits on the body")

/// Deep-lung, Heat-sink and Frostline.
/datum/unit_test/voidcrew_cyberware_models_b_seal

/datum/unit_test/voidcrew_cyberware_models_b_seal/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)

	// Deep-lung: a bigger bladder that refills faster, otherwise a Second Wind.
	var/obj/item/organ/cyberimp/cyberware/second_wind/deep/deep = allocate(/obj/item/organ/cyberimp/cyberware/second_wind/deep)
	TEST_ASSERT_EQUAL(deep.max_reserve, 360 SECONDS, "The Deep-lung bladder holds the wrong amount")
	TEST_ASSERT_EQUAL(deep.reserve, deep.max_reserve, "The Deep-lung bladder starts partly empty")
	TEST_ASSERT_EQUAL(deep.refill_rate, 24 SECONDS, "The Deep-lung bladder refills at the wrong rate")
	TEST_ASSERT(deep.Insert(patient, special = TRUE), "Deep-lung staging insert was refused")
	deep.reserve = 0
	patient.forceMove(run_loc_floor_bottom_left)
	patient.breathe(2, 1)
	TEST_ASSERT_EQUAL(deep.reserve, 24 SECONDS, "A breath of good air refilled the wrong amount of Deep-lung reserve")
	deep.reserve = deep.max_reserve - 10
	patient.breathe(2, 1)
	TEST_ASSERT_EQUAL(deep.reserve, deep.max_reserve, "The Deep-lung bladder refilled past its cap")
	deep.Remove(patient, special = TRUE)

	// Heat-sink: the heat half of the loops, no burn halving.
	var/obj/item/organ/cyberimp/cyberware/coolant/street/sink = allocate(/obj/item/organ/cyberimp/cyberware/coolant/street)
	var/obj/item/organ/cyberimp/cyberware/coolant/loops = allocate(/obj/item/organ/cyberimp/cyberware/coolant)
	var/bare_burn = patient.physiology.burn_mod
	TEST_ASSERT(sink.Insert(patient, special = TRUE), "Heat-sink staging insert was refused")
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_RESISTHEAT), "The Heat-sink lining does not turn heat away")
	TEST_ASSERT_EQUAL(patient.physiology.burn_mod, bare_burn, "The Heat-sink lining halves burns")
	TEST_ASSERT(!sink.coolant_mod_applied, "The Heat-sink lining thinks it applied a burn mod")
	patient.adjust_fire_stacks(5)
	var/lit_stacks = patient.fire_stacks
	TEST_ASSERT(lit_stacks > 0, "Test fixture: the patient took no fire stacks")
	sink.on_life(1, 1)
	TEST_ASSERT(patient.fire_stacks < lit_stacks, "The Heat-sink lining does not scrub fire")
	patient.set_fire_stacks(0)

	TEST_ASSERT(loops.Insert(patient, special = TRUE), "Coolant Loops staging insert was refused")
	TEST_ASSERT(!sink.owner, "The Heat-sink lining stayed in the seal slot beside the loops")
	TEST_ASSERT_EQUAL(patient.physiology.burn_mod, bare_burn * 0.5, "Coolant Loops stopped halving burns")
	TEST_ASSERT(sink.Insert(patient, special = TRUE), "Heat-sink second staging insert was refused")
	TEST_ASSERT_EQUAL(patient.physiology.burn_mod, bare_burn, "Swapping the loops for the Heat-sink left a burn mod on the body")
	sink.Remove(patient, special = TRUE)
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_RESISTHEAT), "Pulling the Heat-sink left heat immunity on the body")

	// Frostline: the cold stops hurting and nothing else changes.
	var/obj/item/organ/cyberimp/cyberware/frostline/frost = allocate(/obj/item/organ/cyberimp/cyberware/frostline)
	TEST_ASSERT(frost.Insert(patient, special = TRUE), "Frostline staging insert was refused")
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_RESISTCOLD), "Frostline does not turn the cold away")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_RESISTHEAT), "Frostline turns the heat away too")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_NOBREATH) && !HAS_TRAIT(patient, TRAIT_RESISTLOWPRESSURE), "Frostline does more than the cold")
	TEST_ASSERT_EQUAL(patient.physiology.burn_mod, bare_burn, "Frostline changed how burns land")
	patient.emp_act(EMP_HEAVY)
	TEST_ASSERT(frost.organ_flags & ORGAN_FAILING, "An EMP never reached the Frostline lining")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_RESISTCOLD), "An EMP-scrambled Frostline lining kept the cold off")
	var/datum/component/cyberware/chrome = frost.GetComponent(/datum/component/cyberware)
	chrome.tune_up()
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_RESISTCOLD), "A tune-up did not bring the Frostline lining back")
	frost.Remove(patient, special = TRUE)
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_RESISTCOLD), "Pulling the Frostline lining left cold resistance on the body")

/// A fixed dodge for the arbiter tests.
/datum/unit_test/voidcrew_cyberware_models_b_slipwire
	/// Stand-in for a Cascade window's source.
	var/test_source_chance = 40

/datum/unit_test/voidcrew_cyberware_models_b_slipwire/proc/fixed_chance()
	return test_source_chance

/// Twitchwire and the Weaver shunt dodge through the shared arbiter and bring
/// their own gait; the Slipwire between them keeps its own.
/datum/unit_test/voidcrew_cyberware_models_b_slipwire/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/cyberimp/cyberware/slipwire/slipwire = allocate(/obj/item/organ/cyberimp/cyberware/slipwire)
	var/obj/item/organ/cyberimp/cyberware/slipwire/street/twitch = allocate(/obj/item/organ/cyberimp/cyberware/slipwire/street)
	var/obj/item/organ/cyberimp/cyberware/slipwire/milspec/weaver = allocate(/obj/item/organ/cyberimp/cyberware/slipwire/milspec)

	// ware, dodge chance, gait modifier (null for none)
	var/list/rungs = list(
		list(twitch, 8, null),
		list(slipwire, 15, /datum/movespeed_modifier/cyberware_slipwire),
		list(weaver, 20, /datum/movespeed_modifier/cyberware_slipwire/weaver),
	)
	var/list/every_gait = list(/datum/movespeed_modifier/cyberware_slipwire, /datum/movespeed_modifier/cyberware_slipwire/weaver)
	for(var/list/rung as anything in rungs)
		var/obj/item/organ/cyberimp/cyberware/slipwire/ware = rung[1]
		TEST_ASSERT(ware.Insert(patient, special = TRUE), "[ware.type] staging insert was refused")
		var/datum/component/cyberware_dodge/arbiter = patient.GetComponent(/datum/component/cyberware_dodge)
		TEST_ASSERT_NOTNULL(arbiter, "[ware.type] never reached the shared dodge arbiter")
		TEST_ASSERT_EQUAL(length(arbiter.dodge_sources), 1, "[ware.type] left [length(arbiter.dodge_sources)] dodge sources, the ladder stacked")
		var/datum/callback/source = arbiter.dodge_sources[REF(ware)]
		TEST_ASSERT_NOTNULL(source, "[ware.type] registered no dodge source of its own")
		TEST_ASSERT_EQUAL(source.Invoke(), rung[2], "[ware.type] dodges at the wrong chance")
		for(var/gait in every_gait)
			TEST_ASSERT_EQUAL(!!patient.has_movespeed_modifier(gait), (gait == rung[3]) ? 1 : 0, "[ware.type] has the wrong gait")

	// A scrambled ware dodges nothing and runs no faster.
	patient.emp_act(EMP_HEAVY)
	var/datum/component/cyberware_dodge/scrambled = patient.GetComponent(/datum/component/cyberware_dodge)
	var/datum/callback/scrambled_source = scrambled.dodge_sources[REF(weaver)]
	TEST_ASSERT_EQUAL(scrambled_source.Invoke(), 0, "An EMP-scrambled Weaver shunt still dodges")
	TEST_ASSERT(!patient.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_slipwire/weaver), "An EMP-scrambled Weaver shunt still runs fast")
	var/datum/component/cyberware/chrome = weaver.GetComponent(/datum/component/cyberware)
	chrome.tune_up()
	TEST_ASSERT(patient.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_slipwire/weaver), "A tune-up did not give the Weaver shunt its gait back")

	// Another source (a Cascade window is one) shares the arbiter by its own
	// key. The arbiter rolls the highest of them, so both stay registered
	// and neither is summed into the other.
	var/datum/component/cyberware_dodge/shared = patient.GetComponent(/datum/component/cyberware_dodge)
	cyberware_register_dodge_source(patient, "voidcrew_test_window", CALLBACK(src, PROC_REF(fixed_chance)))
	TEST_ASSERT_EQUAL(length(shared.dodge_sources), 2, "A second dodge source did not share the arbiter")
	var/best = 0
	for(var/key in shared.dodge_sources)
		var/datum/callback/chance_callback = shared.dodge_sources[key]
		best = max(best, chance_callback.Invoke())
	TEST_ASSERT_EQUAL(best, 40, "The Weaver shunt raised a Cascade window's dodge")
	cyberware_unregister_dodge_source(patient, "voidcrew_test_window")

	weaver.Remove(patient, special = TRUE)
	TEST_ASSERT_NULL(patient.GetComponent(/datum/component/cyberware_dodge), "Pulling the last dodge ware left the arbiter behind")
	TEST_ASSERT(!patient.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_slipwire/weaver), "Pulling the Weaver shunt left its gait on the body")

/// The Thumper ear: shorter reach, shorter fade, louder ping; the Heartbeat
/// Doppler it undercuts keeps its own.
/datum/unit_test/voidcrew_cyberware_models_b_doppler

/datum/unit_test/voidcrew_cyberware_models_b_doppler/Run()
	var/obj/item/organ/cyberimp/cyberware/doppler/street/thumper = allocate(/obj/item/organ/cyberimp/cyberware/doppler/street)
	TEST_ASSERT_EQUAL(thumper.sonar_range, 5, "The Thumper ear reaches the wrong distance")
	TEST_ASSERT_EQUAL(thumper.contact_fade, 3 SECONDS, "The Thumper ear fades contacts at the wrong rate")
	TEST_ASSERT_EQUAL(thumper.ping_volume_bonus, 10, "The Thumper ear is not louder")

	// The range var is what the sweep reads: a contact across the test room is
	// in reach, and not once the reach is cut below the distance.
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/contact = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/distance = get_dist(listener, contact)
	TEST_ASSERT(distance >= 2 && distance <= 5, "Test fixture: the room is [distance] tiles across, not between 2 and 5")
	TEST_ASSERT(thumper.Insert(listener, special = TRUE), "Thumper staging insert was refused")
	thumper.start_sonar()
	TEST_ASSERT(thumper.watched[contact], "The Thumper ear did not hear a contact [distance] tiles away")
	thumper.stop_sonar(listener)
	thumper.sonar_range = distance - 1
	thumper.start_sonar()
	TEST_ASSERT(!thumper.watched[contact], "The Thumper ear heard a contact beyond its reach")
	thumper.stop_sonar(listener)
	TEST_ASSERT(!length(thumper.watched) && !length(thumper.contacts), "Stopping the Thumper ear left contacts behind")
	thumper.Remove(listener, special = TRUE)

	// The parent still reaches the full nine.
	var/obj/item/organ/cyberimp/cyberware/doppler/doppler = allocate(/obj/item/organ/cyberimp/cyberware/doppler)
	TEST_ASSERT(doppler.Insert(listener, special = TRUE), "Doppler staging insert was refused")
	TEST_ASSERT(!thumper.owner, "The Thumper ear stayed in the ear slot beside the Doppler")
	doppler.start_sonar()
	TEST_ASSERT(doppler.watched[contact], "The Heartbeat Doppler lost a contact it used to hear")
	doppler.stop_sonar(listener)

/// What the shelf and the trade-in say: the cradle quotes a price, the
/// planned price and permission, and a trade-in that pays half the shelf price.
/datum/unit_test/voidcrew_cyberware_models_b_shop

/datum/unit_test/voidcrew_cyberware_models_b_shop/Run()
	build_cyberware_price_index()
	// sku, item, credits, vouchers, permission reference
	var/list/skus = list(
		list(/datum/shop_sku/ripperdoc/hardweave, /obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave, 3000, 0, /datum/shop_sku/ripperdoc/dermal_mesh),
		list(/datum/shop_sku/ripperdoc/atlas_street, /obj/item/organ/cyberimp/cyberware/atlas/street, 1500, 0, /datum/shop_sku/ripperdoc/dermal_mesh),
		list(/datum/shop_sku/ripperdoc/second_wind_deep, /obj/item/organ/cyberimp/cyberware/second_wind/deep, 1800, 0, /datum/shop_sku/ripperdoc/shock_coils),
		list(/datum/shop_sku/ripperdoc/coolant_street, /obj/item/organ/cyberimp/cyberware/coolant/street, 1500, 0, /datum/shop_sku/ripperdoc/shock_coils),
		list(/datum/shop_sku/ripperdoc/frostline, /obj/item/organ/cyberimp/cyberware/frostline, 1500, 0, /datum/shop_sku/ripperdoc/shock_coils),
		list(/datum/shop_sku/ripperdoc/slipwire_street, /obj/item/organ/cyberimp/cyberware/slipwire/street, 1800, 0, /datum/shop_sku/ripperdoc/dermal_mesh),
		list(/datum/shop_sku/ripperdoc/slipwire_milspec, /obj/item/organ/cyberimp/cyberware/slipwire/milspec, 0, 3, /datum/shop_sku/ripperdoc/coolant),
		list(/datum/shop_sku/ripperdoc/doppler_street, /obj/item/organ/cyberimp/cyberware/doppler/street, 1500, 0, /datum/shop_sku/ripperdoc/dermal_mesh),
	)
	for(var/list/row as anything in skus)
		var/datum/shop_sku/sku_type = row[1]
		var/reference_type = row[5]
		var/datum/shop_sku/reference = reference_type
		TEST_ASSERT_EQUAL(initial(sku_type.item_path), row[2], "[sku_type] sells the wrong piece")
		TEST_ASSERT_EQUAL(initial(sku_type.price_credits), row[3], "[sku_type] has the wrong credit price")
		TEST_ASSERT_EQUAL(initial(sku_type.price_vouchers), row[4], "[sku_type] has the wrong voucher price")
		TEST_ASSERT_EQUAL(initial(sku_type.zone_permission), initial(reference.zone_permission), "[sku_type] sits behind the wrong reputation")
		var/list/quote = GLOB.cyberware_price_index[row[2]]
		TEST_ASSERT_NOTNULL(quote, "The cradle has no price for [row[2]]")
		if(quote)
			TEST_ASSERT_EQUAL(quote["credits"], row[3], "The cradle quotes [row[2]] differently from its shelf")
			TEST_ASSERT_EQUAL(quote["vouchers"], row[4], "The cradle quotes [row[2]] differently from its shelf")

	// The trade-in: one entry per credit-priced model, exact type, half list.
	// Splice's entry and Ratchet's share the item and the pay.
	var/list/ledgers = list(
		list(/datum/shop_buyback/ripperdoc/hardweave, /datum/shop_sku/ripperdoc/hardweave),
		list(/datum/shop_buyback/ripperdoc/atlas_street, /datum/shop_sku/ripperdoc/atlas_street),
		list(/datum/shop_buyback/ripperdoc/second_wind_deep, /datum/shop_sku/ripperdoc/second_wind_deep),
		list(/datum/shop_buyback/ripperdoc/coolant_street, /datum/shop_sku/ripperdoc/coolant_street),
		list(/datum/shop_buyback/ripperdoc/frostline, /datum/shop_sku/ripperdoc/frostline),
		list(/datum/shop_buyback/ripperdoc/slipwire_street, /datum/shop_sku/ripperdoc/slipwire_street),
		list(/datum/shop_buyback/ripperdoc/doppler_street, /datum/shop_sku/ripperdoc/doppler_street),
	)
	for(var/list/row as anything in ledgers)
		var/ledger_type = row[1]
		var/datum/shop_sku/sku_type = row[2]
		var/datum/shop_buyback/ledger = allocate(ledger_type)
		var/datum/shop_buyback/ratchet = allocate(text2path("[ledger_type]/street_doc"))
		TEST_ASSERT_EQUAL(ledger.item_path, initial(sku_type.item_path), "[ledger_type] buys the wrong piece")
		TEST_ASSERT(!ledger.match_subtypes, "[ledger_type] buys back its piece's subtypes")
		TEST_ASSERT_EQUAL(ledger.pay_credits * 2, initial(sku_type.price_credits), "[ledger_type] does not pay half the shelf price")
		TEST_ASSERT(!ledger.pay_vouchers, "[ledger_type] pays vouchers")
		TEST_ASSERT_EQUAL(ratchet.item_path, ledger.item_path, "The street doc's [ledger_type] buys a different piece")
		TEST_ASSERT_EQUAL(ratchet.pay_credits, ledger.pay_credits, "The street doc's [ledger_type] pays a different amount")
		TEST_ASSERT(ratchet.desc != ledger.desc, "The street doc's [ledger_type] has no wording of his own")

	// The parents' own entries take only the parent, so a Hardweave or a
	// Deep-lung never sells at the cheaper piece's rate.
	var/datum/shop_buyback/mesh_ledger = allocate(/datum/shop_buyback/ripperdoc/dermal_mesh)
	TEST_ASSERT(mesh_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh)), "The Dermal Mesh ledger won't take a Dermal Mesh")
	TEST_ASSERT(!mesh_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/dermal_mesh/hardweave)), "The Dermal Mesh ledger takes a Hardweave")
	var/datum/shop_buyback/bladder_ledger = allocate(/datum/shop_buyback/ripperdoc/second_wind)
	TEST_ASSERT(bladder_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/second_wind)), "The Second Wind ledger won't take a Second Wind")
	TEST_ASSERT(!bladder_ledger.matches(allocate(/obj/item/organ/cyberimp/cyberware/second_wind/deep)), "The Second Wind ledger takes a Deep-lung")

	// Vouchers cannot be refunded: the Weaver shunt has no entry anywhere.
	for(var/buyback_type in typesof(/datum/shop_buyback/ripperdoc))
		var/datum/shop_buyback/ledger = buyback_type
		var/path = initial(ledger.item_path)
		if(!path)
			continue
		var/buys_weaver = initial(ledger.match_subtypes) ? ispath(/obj/item/organ/cyberimp/cyberware/slipwire/milspec, path) : (path == /obj/item/organ/cyberimp/cyberware/slipwire/milspec)
		TEST_ASSERT(!buys_weaver, "[buyback_type] buys back the Weaver shunt")
