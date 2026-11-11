// Package: P1 bolt. Unit tests for voidcrew/modules/plasma_weapons/.

/// Shared helpers for the plasma bolt tests.
/datum/unit_test/voidcrew_plasma_bolt
	abstract_type = /datum/unit_test/voidcrew_plasma_bolt

/datum/unit_test/voidcrew_plasma_bolt/proc/turf_at(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A bolt sitting on `where` that came from there, ready to be handed to bullet_act().
/datum/unit_test/voidcrew_plasma_bolt/proc/make_bolt(bolt_type, turf/where, zone = BODY_ZONE_CHEST)
	var/obj/projectile/energy/plasma_bolt/bolt = allocate(bolt_type, where)
	bolt.starting = where
	bolt.def_zone = zone
	return bolt

/// Both bolts are matter: energy armour, never reflected, stopped by glass and grilles, never hitscan.
/datum/unit_test/voidcrew_plasma_bolt/flags

/datum/unit_test/voidcrew_plasma_bolt/flags/Run()
	for(var/obj/projectile/energy/plasma_bolt/bolt_type as anything in list(/obj/projectile/energy/plasma_bolt, /obj/projectile/energy/plasma_bolt/heavy))
		TEST_ASSERT_EQUAL(initial(bolt_type.armor_flag), ENERGY, "[bolt_type] does not use energy armour")
		TEST_ASSERT_EQUAL(initial(bolt_type.damage_type), BURN, "[bolt_type] does not burn")
		TEST_ASSERT_EQUAL(initial(bolt_type.reflectable), NONE, "[bolt_type] can be reflected")
		TEST_ASSERT(!initial(bolt_type.hitscan), "[bolt_type] is hitscan")
		TEST_ASSERT(!(initial(bolt_type.pass_flags) & (PASSGLASS|PASSGRILLE)), "[bolt_type] passes through glass or grilles")
		TEST_ASSERT_EQUAL(initial(bolt_type.dismemberment), 0, "[bolt_type] dismembers through the brute projectile path")
		TEST_ASSERT_EQUAL(initial(bolt_type.light_system), OVERLAY_LIGHT, "[bolt_type] does not carry an overlay light")
	TEST_ASSERT_EQUAL(/obj/projectile/energy/plasma_bolt::damage, 30, "pistol bolt damage changed")
	TEST_ASSERT_EQUAL(/obj/projectile/energy/plasma_bolt/heavy::damage, 45, "rifle bolt damage changed")
	TEST_ASSERT_EQUAL(/obj/item/ammo_casing/energy/plasma_bolt::projectile_type, /obj/projectile/energy/plasma_bolt, "the pistol casing fires the wrong bolt")
	TEST_ASSERT_EQUAL(/obj/item/ammo_casing/energy/plasma_bolt/heavy::projectile_type, /obj/projectile/energy/plasma_bolt/heavy, "the rifle casing fires the wrong bolt")
	TEST_ASSERT_EQUAL(/obj/item/ammo_casing/energy/plasma_bolt::e_cost, PLASMA_SHOT_MOL_PISTOL, "the pistol casing costs the wrong mol")
	TEST_ASSERT_EQUAL(/obj/item/ammo_casing/energy/plasma_bolt/heavy::e_cost, PLASMA_SHOT_MOL_RIFLE, "the rifle casing costs the wrong mol")

/// A canister's energy armour stops a bolt cold; a shuttle window has none and takes the hit.
/datum/unit_test/voidcrew_plasma_bolt/structures

/datum/unit_test/voidcrew_plasma_bolt/structures/Run()
	var/turf/open/here = turf_at(1, 1)
	var/obj/machinery/portable_atmospherics/canister/canister = allocate(/obj/machinery/portable_atmospherics/canister, turf_at(2, 1))
	var/canister_before = canister.get_integrity()
	canister.projectile_hit(make_bolt(/obj/projectile/energy/plasma_bolt/heavy, here))
	TEST_ASSERT_EQUAL(canister.get_integrity(), canister_before, "a rifle bolt damaged a canister")

	var/obj/structure/window/reinforced/shuttle/window = allocate(/obj/structure/window/reinforced/shuttle, turf_at(1, 2))
	var/window_before = window.get_integrity()
	window.projectile_hit(make_bolt(/obj/projectile/energy/plasma_bolt, here))
	TEST_ASSERT(window.get_integrity() < window_before, "a pistol bolt left a shuttle window undamaged")

/// A flying bolt lights a turf holding fuel gas and oxygen, and nothing in clean air or vacuum.
/datum/unit_test/voidcrew_plasma_bolt/ignition

/datum/unit_test/voidcrew_plasma_bolt/ignition/Run()
	var/turf/open/start = turf_at(1, 1)
	var/turf/open/fuel = turf_at(2, 1)
	var/turf/open/clean = turf_at(1, 2)
	var/turf/open/vacuum = turf_at(2, 2)
	TEST_ASSERT(istype(fuel) && istype(clean) && istype(vacuum), "the test room has no open floor to fire across")
	var/datum/gas_mixture/vacuum_saved = vacuum.air.copy()
	var/datum/gas_mixture/fuel_saved = fuel.air.copy()

	fuel.atmos_spawn_air("[GAS_PLASMA]=5;TEMP=[T20C]")
	vacuum.air.remove_ratio(1)

	var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(/obj/projectile/energy/plasma_bolt, start)
	bolt.fired = TRUE
	bolt.forceMove(clean)
	TEST_ASSERT_NULL(clean.active_hotspot, "a bolt lit clean air")
	bolt.forceMove(vacuum)
	TEST_ASSERT_NULL(vacuum.active_hotspot, "a bolt lit a vacuum")
	bolt.forceMove(fuel)
	TEST_ASSERT_NOTNULL(fuel.active_hotspot, "a bolt flew through 5 mol of plasma in air and lit nothing")

	if(fuel.active_hotspot)
		qdel(fuel.active_hotspot)
	fuel.air.copy_from(fuel_saved)
	vacuum.air.copy_from(vacuum_saved)

/// A bolt that hits someone in breathable air sets them alight.
/datum/unit_test/voidcrew_plasma_bolt/fire_on_hit

/datum/unit_test/voidcrew_plasma_bolt/fire_on_hit/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(/obj/projectile/energy/plasma_bolt, turf_at(1, 1))
	TEST_ASSERT_EQUAL(bolt.fire_stacks_on_hit, PLASMA_FIRE_STACKS_ON_HIT, "a bolt carries the wrong fire stacks")
	victim.bullet_act(bolt, BODY_ZONE_CHEST)
	TEST_ASSERT(victim.fire_stacks >= PLASMA_FIRE_STACKS_ON_HIT, "a bolt hit added [victim.fire_stacks] fire stacks, expected [PLASMA_FIRE_STACKS_ON_HIT]")
	TEST_ASSERT(victim.on_fire, "a bolt hit in breathable air did not ignite the target")
	victim.extinguish_mob()

/// A rifle bolt burns away an arm already at 40/50, without a blood spray, and leaves ash.
/datum/unit_test/voidcrew_plasma_bolt/ash_arm

/datum/unit_test/voidcrew_plasma_bolt/ash_arm/Run()
	var/turf/open/spot = turf_at(2, 1)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 40, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(arm.get_damage(), 40, "could not set the arm to 40 damage")

	victim.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt/heavy, turf_at(1, 1), BODY_ZONE_L_ARM), BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_L_ARM), "a rifle bolt left an arm at 40/50 attached")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/ash) in spot, "the ashed arm left no ash")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hitsplatter) in range(4, spot), "ashing an arm sprayed blood")
	victim.extinguish_mob()
	for(var/obj/effect/decal/cleanable/leftover in range(4, spot))
		qdel(leftover)

/// Below the margin the arm stays; chests and heads are never ashed however hurt they are.
/datum/unit_test/voidcrew_plasma_bolt/ash_limits

/datum/unit_test/voidcrew_plasma_bolt/ash_limits/Run()
	var/turf/open/from = turf_at(1, 1)

	// Ends at 30/50, under the rifle's 35.
	var/mob/living/carbon/human/consistent/light = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/projectile/energy/plasma_bolt/heavy/weak = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, BODY_ZONE_R_ARM)
	weak.damage = 30
	light.bullet_act(weak, BODY_ZONE_R_ARM)
	var/obj/item/bodypart/right_arm = light.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_NOTNULL(right_arm, "an arm at 30/50 was ashed")
	TEST_ASSERT_EQUAL(right_arm?.get_damage(), 30, "the arm should have ended at 30/50")
	light.extinguish_mob()

	for(var/zone in list(BODY_ZONE_CHEST, BODY_ZONE_HEAD))
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
		var/obj/item/bodypart/part = victim.get_bodypart(zone)
		part.receive_damage(brute = part.max_damage - 10, wound_bonus = CANT_WOUND)
		victim.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, zone), zone)
		TEST_ASSERT_NOTNULL(victim.get_bodypart(zone), "a rifle bolt ashed a [zone]")
		victim.extinguish_mob()

	for(var/obj/effect/decal/cleanable/leftover in range(4, from))
		qdel(leftover)

/// The ash handler removes itself on its first damage event, even one the bolt didn't cause.
/datum/unit_test/voidcrew_plasma_bolt/ash_unregisters

/datum/unit_test/voidcrew_plasma_bolt/ash_unregisters/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))

	var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(/obj/projectile/energy/plasma_bolt, turf_at(1, 1))
	victim.bullet_act(bolt, BODY_ZONE_CHEST)
	TEST_ASSERT(!QDELETED(bolt), "bullet_act deleted the bolt")
	TEST_ASSERT_NULL(LAZYACCESS(bolt._signal_procs, victim), "the bolt is still listening to its target after the hit")

	// Some other damage lands first: the handler leaves, and that damage ashes nothing.
	var/obj/projectile/energy/plasma_bolt/heavy/second = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, turf_at(1, 1))
	second.RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, TYPE_PROC_REF(/obj/projectile/energy/plasma_bolt, plasma_check_ash))
	var/obj/item/bodypart/leg = victim.get_bodypart(BODY_ZONE_L_LEG)
	victim.apply_damage(50, BURN, leg, wound_bonus = CANT_WOUND)
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_L_LEG), "damage from something other than the bolt ashed a leg")
	TEST_ASSERT_NULL(LAZYACCESS(second._signal_procs, victim), "the ash handler did not unregister on a damage event that wasn't its bolt")

	// A bolt deleted before its damage lands takes its registration with it.
	var/obj/projectile/energy/plasma_bolt/third = make_bolt(/obj/projectile/energy/plasma_bolt, turf_at(1, 1))
	third.RegisterSignal(victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, TYPE_PROC_REF(/obj/projectile/energy/plasma_bolt, plasma_check_ash))
	LAZYADD(third.hissed_mobs, victim)
	qdel(third)
	var/listeners = victim._listen_lookup?[COMSIG_MOB_AFTER_APPLY_DAMAGE]
	TEST_ASSERT(islist(listeners) ? !(third in listeners) : listeners != third, "a deleted bolt is still registered on its target")
	TEST_ASSERT_NULL(third.hissed_mobs, "a deleted bolt kept its hiss-by list")
	victim.extinguish_mob()
