// Xenoarchaeology tests: effects_polaris.
//
// Test files compile before voidcrew/_DEFINES, so the values below are literals. They mirror
// voidcrew/_DEFINES/xenoarch.dm:
//   bands (ZONE_*): green 1, yellow 2, red 3
//   tiers: common 1, uncommon 2, rare 3, extreme 4
//   triggers: plasma 512 (the only one a test names)
//   release methods: "touch", "aura", "pulse"

/// The Polaris and VOREStation effects: type -> list(tier, minor, harvestable), from the design catalogue.
/proc/voidcrew_xenoarch_polaris_catalogue()
	return list(
		/datum/artifact_effect/extinguisher = list(1, TRUE, TRUE),
		/datum/artifact_effect/animate = list(1, FALSE, FALSE),
		/datum/artifact_effect/sweat = list(1, TRUE, TRUE),
		/datum/artifact_effect/electric_field = list(2, FALSE, TRUE),
		/datum/artifact_effect/bestow/fortify = list(2, FALSE, TRUE),
		/datum/artifact_effect/bestow/faraday = list(2, FALSE, TRUE),
		/datum/artifact_effect/bestow/sprint = list(2, FALSE, TRUE),
		/datum/artifact_effect/bestow/berserk = list(2, FALSE, TRUE),
		/datum/artifact_effect/disarm = list(2, FALSE, TRUE),
		/datum/artifact_effect/forcefield = list(2, FALSE, FALSE),
		/datum/artifact_effect/gaia = list(2, FALSE, TRUE),
		/datum/artifact_effect/gas_vent/plasma = list(2, FALSE, FALSE),
		/datum/artifact_effect/poltergeist = list(3, FALSE, TRUE),
		/datum/artifact_effect/bestow/feysight = list(3, FALSE, TRUE),
		/datum/artifact_effect/gas_vent/sleeping = list(3, FALSE, FALSE),
		/datum/artifact_effect/life_drain = list(3, FALSE, TRUE),
		/datum/artifact_effect/gravity_wave = list(4, FALSE, FALSE),
		/datum/artifact_effect/spines = list(4, FALSE, FALSE),
		/datum/artifact_effect/life_steal = list(4, FALSE, TRUE),
		/datum/artifact_effect/resurrect = list(4, FALSE, FALSE),
	)

/// Every Polaris effect is rollable with the catalogue's tier, minor and harvest flags, and rolls sane traits.
/datum/unit_test/voidcrew_xenoarch_polaris_catalogue/Run()
	var/list/catalogue = voidcrew_xenoarch_polaris_catalogue()
	var/list/rollable = artifact_effect_types()
	TEST_ASSERT(!(/datum/artifact_effect/bestow in rollable), "the shared status-giving parent can roll")
	TEST_ASSERT(!(/datum/artifact_effect/gas_vent in rollable), "the shared gas vent parent can roll")
	for(var/effect_type in catalogue)
		var/list/row = catalogue[effect_type]
		TEST_ASSERT(effect_type in rollable, "[effect_type] can't roll")
		var/label_count = 0
		var/datum/artifact_effect/probe = effect_type
		for(var/datum/artifact_effect/other as anything in rollable)
			if(initial(other.label_name) == initial(probe.label_name))
				label_count++
		TEST_ASSERT_EQUAL(label_count, 1, "[effect_type]'s label word is shared with another effect")
		for(var/band in 1 to 3)
			for(var/roll in 1 to 10)
				var/datum/artifact_effect/effect = new effect_type(null, band)
				TEST_ASSERT_EQUAL(effect.tier, row[1], "[effect_type] has the wrong tier")
				TEST_ASSERT_EQUAL(effect.minor, row[2], "[effect_type] has the wrong minor flag")
				TEST_ASSERT_EQUAL(effect.harvestable, row[3], "[effect_type] has the wrong harvest flag")
				TEST_ASSERT(effect.release_method in effect.allowed_release_methods, "[effect_type] rolled a release it doesn't allow")
				TEST_ASSERT(effect.energy_kind in effect.possible_kinds, "[effect_type] rolled a kind it doesn't allow")
				TEST_ASSERT(effect.range >= 1 && effect.range <= 8, "[effect_type] rolled range [effect.range]")
				TEST_ASSERT(effect.touch_cost <= effect.maximum_charges, "[effect_type] can never be touched off")
				qdel(effect)
	// Plasma air never wakes the plasma vent, or it would feed itself.
	for(var/roll in 1 to 100)
		var/datum/artifact_effect/gas_vent/plasma/vent = new(null, 3)
		TEST_ASSERT(vent.trigger != 512, "the plasma vent rolled a plasma-air trigger")
		qdel(vent)
	var/datum/artifact_effect/spines/spines = new(null, 1)
	TEST_ASSERT_EQUAL(spines.green_weight, 0.5, "spines are not halved in green")
	qdel(spines)

/// Every Polaris effect wakes, touches, runs a field and bursts on a real artifact without errors,
/// and leaves no force walls standing once it is gone.
/datum/unit_test/voidcrew_xenoarch_polaris_effects_run/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	var/turf/home = get_turf(find)
	var/mob/living/carbon/human/consistent/tester = allocate(/mob/living/carbon/human/consistent, get_step(home, EAST))
	tester.mind_initialize()
	allocate(/obj/item/crowbar, get_step(get_step(home, NORTH), NORTH))
	for(var/effect_type in voidcrew_xenoarch_polaris_catalogue())
		find.forceMove(home)
		tester.forceMove(get_step(home, EAST))
		find.replace_effects(effect_type, null, 3)
		var/datum/artifact_effect/effect = find.main_effect
		TEST_ASSERT(effect, "[effect_type] did not attach to the artifact")
		if(istype(effect, /datum/artifact_effect/gas_vent))
			var/datum/artifact_effect/gas_vent/vent = effect
			vent.reserve = 0 // Venting is tested on its own, with the air put back afterwards.
		effect.wake(1 MINUTES)
		TEST_ASSERT(effect.activated, "[effect_type] did not wake")
		effect.do_effect_touch(tester)
		effect.do_effect_aura(2)
		effect.do_effect_pulse(effect.maximum_charges)
		effect.deactivate(quiet = TRUE)
		tester.fully_heal(HEAL_ALL)
	find.replace_effects(null, null)
	for(var/obj/effect/forcefield/artifact/wall in range(4, home))
		TEST_ASSERT(!wall.density, "a force wall still stands after its effect is gone")
	for(var/obj/effect/decal/cleanable/artifact_ooze/puddle in range(4, home))
		TEST_ASSERT(puddle.reagents?.total_volume <= 30, "an ooze puddle grew past a cupful")

/// Resurrect: three lives, then spent; refuses the long dead, minds that moved on, and the absent.
/datum/unit_test/voidcrew_xenoarch_resurrect/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	find.replace_effects(/datum/artifact_effect/resurrect, null, 3)
	var/datum/artifact_effect/resurrect/rite = find.main_effect
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent, get_step(find, EAST))
	patient.mind_initialize()
	for(var/life in 1 to 3)
		patient.adjustBruteLoss(40)
		patient.death()
		TEST_ASSERT_EQUAL(patient.stat, DEAD, "the patient did not die (life [life])")
		TEST_ASSERT_EQUAL(rite.raise_refusal(patient), "gone", "a body with no player to come back was offered a revival")
		TEST_ASSERT(rite.raise(patient), "a fresh body was not raised (life [life])")
		TEST_ASSERT(patient.stat != DEAD, "the patient is still dead after being raised (life [life])")
		TEST_ASSERT_EQUAL(rite.uses_left, 3 - life, "a revival did not spend a use")
	patient.death()
	TEST_ASSERT_EQUAL(rite.raise_refusal(patient), "spent", "a spent artifact offered a fourth life")
	TEST_ASSERT(!rite.raise(patient), "a spent artifact raised the dead")
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "a spent artifact brought the patient back")

	// A fresh artifact for the remaining rules.
	find.replace_effects(/datum/artifact_effect/resurrect, null, 3)
	rite = find.main_effect
	patient.timeofdeath = world.time - 6 MINUTES
	TEST_ASSERT_EQUAL(rite.raise_refusal(patient), "too late", "a body dead six minutes was offered a revival")
	patient.timeofdeath = world.time
	var/mob/living/carbon/human/consistent/clone = allocate(/mob/living/carbon/human/consistent, get_step(find, WEST))
	patient.mind.transfer_to(clone)
	TEST_ASSERT_EQUAL(rite.raise_refusal(patient), "gone", "a body whose mind moved on was offered a revival")
	clone.mind.transfer_to(patient)
	ADD_TRAIT(patient, TRAIT_SUICIDED, "unit_test")
	TEST_ASSERT_EQUAL(rite.raise_refusal(patient), "ruined", "a suicide was offered a revival")
	REMOVE_TRAIT(patient, TRAIT_SUICIDED, "unit_test")

	// Its mending is capped like any artifact healing.
	var/mob/living/carbon/human/consistent/wreck = allocate(/mob/living/carbon/human/consistent, get_step(find, NORTH))
	wreck.mind_initialize()
	wreck.adjustBruteLoss(170)
	wreck.death()
	rite.raise(wreck)
	TEST_ASSERT(wreck.getBruteLoss() >= 139.5, "resurrect mended past the artifact healing cap ([wreck.getBruteLoss()] brute left)")

/// Life steal: never heals past the shared cap, and takes exactly what it gives.
/datum/unit_test/voidcrew_xenoarch_life_steal/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	find.replace_effects(/datum/artifact_effect/life_steal, null, 3)
	var/datum/artifact_effect/life_steal/thief = find.main_effect
	thief.range = 3
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, get_step(find, EAST))
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, get_step(find, WEST))
	TEST_ASSERT_EQUAL(thief.steal_for(user, 10), 0, "life steal healed an unhurt person")
	TEST_ASSERT_EQUAL(victim.getBruteLoss() + victim.getFireLoss(), 0, "life steal hurt someone without healing anyone")
	user.take_overall_damage(60, 0)
	var/healed = 0
	for(var/i in 1 to 6)
		healed += thief.steal_for(user, 10)
	TEST_ASSERT(healed <= 30.5, "life steal healed past the artifact cap ([healed])")
	TEST_ASSERT(healed >= 29.5, "life steal stopped short of the cap ([healed])")
	var/lost = victim.getBruteLoss() + victim.getFireLoss()
	TEST_ASSERT(abs(lost - healed) < 1, "life steal took [lost] but gave [healed]")

/// The status effects do what they say while they last and leave nothing behind.
/datum/unit_test/voidcrew_xenoarch_polaris_status_effects/Run()
	var/mob/living/carbon/human/consistent/tester = allocate(/mob/living/carbon/human/consistent)

	tester.apply_status_effect(/datum/status_effect/artifact/fortify, 30 SECONDS)
	tester.apply_damage(20, BRUTE, BODY_ZONE_CHEST)
	var/fortified_loss = tester.getBruteLoss()
	TEST_ASSERT(fortified_loss > 15 && fortified_loss < 19, "fortified skin took [fortified_loss] from a 20 brute hit")
	tester.remove_status_effect(/datum/status_effect/artifact/fortify)
	tester.apply_damage(20, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(tester.getBruteLoss() - fortified_loss > 19.5, "fortify outlived its status effect")
	tester.fully_heal(HEAL_ALL)

	// Doses never stack past one dose, nor past the cap.
	var/datum/status_effect/artifact/fortify/dose = tester.apply_status_effect(/datum/status_effect/artifact/fortify, 10 SECONDS)
	tester.apply_status_effect(/datum/status_effect/artifact/fortify, 10 SECONDS)
	TEST_ASSERT(dose.duration <= world.time + 10 SECONDS, "two fortify doses stacked")
	tester.apply_status_effect(/datum/status_effect/artifact/fortify, 10 MINUTES)
	TEST_ASSERT(dose.duration <= world.time + 90 SECONDS, "a fortify dose ran past its cap")
	tester.remove_status_effect(/datum/status_effect/artifact/fortify)

	tester.apply_status_effect(/datum/status_effect/artifact/sprint, 30 SECONDS)
	TEST_ASSERT(tester.has_movespeed_modifier(/datum/movespeed_modifier/status_effect/artifact_sprint), "sprint did not speed anyone up")
	tester.remove_status_effect(/datum/status_effect/artifact/sprint)
	TEST_ASSERT(!tester.has_movespeed_modifier(/datum/movespeed_modifier/status_effect/artifact_sprint), "sprint outlived its status effect")

	tester.apply_status_effect(/datum/status_effect/artifact/faraday, 30 SECONDS)
	TEST_ASSERT(tester.emp_act(EMP_HEAVY) & EMP_PROTECT_SELF, "faraday did not stop an EMP")
	tester.remove_status_effect(/datum/status_effect/artifact/faraday)
	TEST_ASSERT(!(tester.emp_act(EMP_HEAVY) & EMP_PROTECT_SELF), "faraday outlived its status effect")

	tester.apply_status_effect(/datum/status_effect/artifact/feysight, 30 SECONDS)
	TEST_ASSERT(HAS_TRAIT(tester, TRAIT_THERMAL_VISION), "feysight gave no sight through walls")
	tester.remove_status_effect(/datum/status_effect/artifact/feysight)
	TEST_ASSERT(!HAS_TRAIT(tester, TRAIT_THERMAL_VISION), "feysight outlived its status effect")

	tester.apply_status_effect(/datum/status_effect/artifact/berserk, 30 SECONDS)
	TEST_ASSERT(HAS_TRAIT(tester, TRAIT_PERFECT_ATTACKER), "berserk did not take")
	tester.remove_status_effect(/datum/status_effect/artifact/berserk)
	TEST_ASSERT(!HAS_TRAIT(tester, TRAIT_PERFECT_ATTACKER), "berserk outlived its status effect")
	TEST_ASSERT(tester.has_status_effect(/datum/status_effect/artifact/exhausted), "berserk ended without the crash")
	tester.apply_status_effect(/datum/status_effect/artifact/berserk, 30 SECONDS)
	TEST_ASSERT(!tester.has_status_effect(/datum/status_effect/artifact/berserk), "an exhausted person was enraged again")
	tester.remove_status_effect(/datum/status_effect/artifact/exhausted)
	TEST_ASSERT(!tester.has_movespeed_modifier(/datum/movespeed_modifier/status_effect/artifact_exhausted), "exhaustion outlived its status effect")

/// Gas vents: indoors they vent from a finite reserve, then run dry for good.
/datum/unit_test/voidcrew_xenoarch_gas_vent_reserve/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	var/turf/open/here = get_turf(find)
	var/datum/gas_mixture/original = here.return_air().copy()
	find.replace_effects(/datum/artifact_effect/gas_vent/plasma, null, 3)
	var/datum/artifact_effect/gas_vent/plasma/vent = find.main_effect
	vent.reserve = 10
	vent.max_pressure = 1000
	TEST_ASSERT_EQUAL(vent.vent(6), 6, "the plasma vent did not vent indoors")
	TEST_ASSERT_EQUAL(vent.vent(6), 4, "the plasma vent vented past its reserve")
	TEST_ASSERT_EQUAL(vent.vent(6), 0, "a dry plasma vent kept venting")
	var/list/plasma = here.return_air().gases[/datum/gas/plasma]
	TEST_ASSERT(plasma && plasma[MOLES] >= 9.5, "the vented plasma is not on the tile")
	here.return_air().copy_from(original)
	here.air_update_turf(FALSE, FALSE)

/// Animate never walks while bolted down, and follows someone when loose.
/datum/unit_test/voidcrew_xenoarch_animate/Run()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact)
	find.replace_effects(/datum/artifact_effect/animate, null, 1)
	var/datum/artifact_effect/animate/walker = find.main_effect
	walker.range = 5
	var/turf/start = get_turf(find)
	var/mob/living/carbon/human/consistent/quarry = allocate(/mob/living/carbon/human/consistent, locate(start.x + 3, start.y, start.z))
	quarry.mind_initialize()
	find.set_anchored(TRUE)
	walker.stalk()
	TEST_ASSERT_EQUAL(get_turf(find), start, "a bolted artifact walked")
	find.set_anchored(FALSE)
	TEST_ASSERT(walker.stalk(), "a loose artifact did not follow someone in reach")
	TEST_ASSERT(get_dist(find, quarry) < 3, "the artifact did not close in on its quarry")

/**
 * Polaris effects on planet ground never give a planet turf private air: the gas vents, the
 * extinguisher and the force walls. (A real flame writes the air itself, so none is lit here.) Uses the shared planet air room from voidcrew_planet_shared_air.dm.
 */
/datum/unit_test/voidcrew_planet_shared_air/xenoarch_polaris_effects/Run()
	if(!planetary_atmos_shared_mix_enabled())
		return
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, center)
	find.replace_effects(/datum/artifact_effect/gas_vent/plasma, /datum/artifact_effect/gas_vent/sleeping, 3)
	TEST_ASSERT(room_is_pristine(), "placing an artifact gave the planet private air")
	for(var/datum/artifact_effect/gas_vent/vent as anything in find.effects())
		vent.release_method = "aura"
		vent.wake(1 MINUTES)
		TEST_ASSERT_EQUAL(vent.vent(10), 0, "a gas vent vented into planet air")
		vent.do_effect_touch(null)
		vent.do_effect_pulse(50)
	for(var/i in 1 to 3)
		find.process(2)
	TEST_ASSERT(room_is_pristine(), "a gas vent running on a planet gave it private air")
	find.replace_effects(/datum/artifact_effect/extinguisher, /datum/artifact_effect/forcefield, 3)
	var/datum/artifact_effect/extinguisher/snuffer = find.main_effect
	snuffer.range = 2
	snuffer.do_effect_pulse(50)
	snuffer.do_effect_aura(2)
	var/datum/artifact_effect/forcefield/field = find.second_effect
	field.ring_radius = 2
	field.raise_ring(10 SECONDS)
	TEST_ASSERT(room_is_pristine(), "the extinguisher or force walls gave the planet private air")
	field.drop_ring()
