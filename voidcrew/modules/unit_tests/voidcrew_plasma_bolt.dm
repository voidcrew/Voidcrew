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
	TEST_ASSERT_EQUAL(/obj/projectile/energy/plasma_bolt::damage, 32, "pistol bolt damage changed")
	TEST_ASSERT_EQUAL(/obj/projectile/energy/plasma_bolt/heavy::damage, 45, "rifle bolt damage changed")
	TEST_ASSERT(/obj/projectile/energy/plasma_bolt/heavy::wound_bonus > /obj/projectile/energy/plasma_bolt::wound_bonus, "the rifle bolt should wound more readily than the pistol bolt")
	TEST_ASSERT(/obj/projectile/energy/plasma_bolt::wound_bonus > 0, "the pistol bolt has no wound bonus")
	TEST_ASSERT_EQUAL(/obj/projectile/energy/plasma_bolt::demolition_mod, PLASMA_DEMOLITION_PISTOL, "pistol bolt structure damage changed")
	TEST_ASSERT_EQUAL(/obj/projectile/energy/plasma_bolt/heavy::demolition_mod, PLASMA_DEMOLITION_RIFLE, "rifle bolt structure damage changed")
	TEST_ASSERT_EQUAL(/obj/item/ammo_casing/energy/plasma_bolt::projectile_type, /obj/projectile/energy/plasma_bolt, "the pistol casing fires the wrong bolt")
	TEST_ASSERT_EQUAL(/obj/item/ammo_casing/energy/plasma_bolt/heavy::projectile_type, /obj/projectile/energy/plasma_bolt/heavy, "the rifle casing fires the wrong bolt")
	TEST_ASSERT_EQUAL(/obj/item/ammo_casing/energy/plasma_bolt::e_cost, PLASMA_SHOT_MOL_PISTOL, "the pistol casing costs the wrong mol")
	TEST_ASSERT_EQUAL(/obj/item/ammo_casing/energy/plasma_bolt/heavy::e_cost, PLASMA_SHOT_MOL_RIFLE, "the rifle casing costs the wrong mol")

/// A canister's energy armour stops a bolt cold; a shuttle window has none and takes the hit at the
/// bolt's demolition multiplier. Doors take it too; other machines take plain damage.
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
	var/expected = /obj/projectile/energy/plasma_bolt::damage * PLASMA_DEMOLITION_PISTOL
	TEST_ASSERT_EQUAL(window_before - window.get_integrity(), expected, "a pistol bolt took [window_before - window.get_integrity()] from a shuttle window, expected [expected]")

	var/obj/projectile/energy/plasma_bolt/heavy/rifle_bolt = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, here)
	var/obj/machinery/door/airlock/public/door = allocate(/obj/machinery/door/airlock/public, turf_at(2, 2))
	TEST_ASSERT_EQUAL(rifle_bolt.get_demolition_modifier(window), PLASMA_DEMOLITION_RIFLE, "a rifle bolt does not break windows faster")
	TEST_ASSERT_EQUAL(rifle_bolt.get_demolition_modifier(door), PLASMA_DEMOLITION_RIFLE, "a rifle bolt does not break doors faster")
	var/obj/machinery/recharger/machine = allocate(/obj/machinery/recharger, turf_at(1, 1))
	TEST_ASSERT_EQUAL(rifle_bolt.get_demolition_modifier(machine), 1, "a rifle bolt breaks ordinary machines faster")

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

/// A bolt that hits someone in breathable air burns them but never sets them alight.
/datum/unit_test/voidcrew_plasma_bolt/no_fire_on_hit

/datum/unit_test/voidcrew_plasma_bolt/no_fire_on_hit/Run()
	for(var/bolt_type in list(/obj/projectile/energy/plasma_bolt, /obj/projectile/energy/plasma_bolt/heavy))
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
		victim.bullet_act(make_bolt(bolt_type, turf_at(1, 1)), BODY_ZONE_CHEST)
		TEST_ASSERT(victim.getFireLoss() > 0, "a [bolt_type] hit did no burn damage")
		TEST_ASSERT_EQUAL(victim.fire_stacks, 0, "a [bolt_type] hit added [victim.fire_stacks] fire stacks")
		TEST_ASSERT(!victim.on_fire, "a [bolt_type] hit set the target alight")

/// A rifle bolt on a bare, unhurt arm always leaves a burn wound (its wound bonus clears the moderate
/// threshold on any roll) and does not melt the arm in one hit.
/datum/unit_test/voidcrew_plasma_bolt/burn_wound

/datum/unit_test/voidcrew_plasma_bolt/burn_wound/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	victim.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt/heavy, turf_at(1, 1), BODY_ZONE_R_ARM), BODY_ZONE_R_ARM)
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_NOTNULL(arm, "one rifle bolt melted an unhurt arm")
	TEST_ASSERT_NOTNULL(arm?.get_wound_type(/datum/wound/burn/flesh), "a rifle bolt on a bare arm left no burn wound")

/// A rifle bolt burns away an arm already at 40/50, without a blood spray, and leaves no ash (the melt leaves slag).
/datum/unit_test/voidcrew_plasma_bolt/ash_arm

/datum/unit_test/voidcrew_plasma_bolt/ash_arm/Run()
	var/turf/open/spot = turf_at(2, 1)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/bodypart/arm = victim.get_bodypart(BODY_ZONE_L_ARM)
	arm.receive_damage(brute = 40, wound_bonus = CANT_WOUND)
	TEST_ASSERT_EQUAL(arm.get_damage(), 40, "could not set the arm to 40 damage")

	victim.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt/heavy, turf_at(1, 1), BODY_ZONE_L_ARM), BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_L_ARM), "a rifle bolt left an arm at 40/50 attached")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/ash) in spot, "the melted arm left tg's ash pile")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/blood/hitsplatter) in range(4, spot), "ashing an arm sprayed blood")
	for(var/obj/effect/decal/cleanable/leftover in range(4, spot))
		qdel(leftover)

	// A bolt that armour stopped most of melts nothing, however hurt the arm
	var/mob/living/carbon/human/consistent/armoured = allocate(/mob/living/carbon/human/consistent, spot)
	var/obj/item/bodypart/right_arm = armoured.get_bodypart(BODY_ZONE_R_ARM)
	right_arm.receive_damage(brute = 45, wound_bonus = CANT_WOUND)
	var/obj/projectile/energy/plasma_bolt/glancing = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, turf_at(1, 1), BODY_ZONE_R_ARM)
	glancing.damage = PLASMA_ASH_MIN_LANDED - 1
	armoured.bullet_act(glancing, BODY_ZONE_R_ARM)
	TEST_ASSERT_NOTNULL(armoured.get_bodypart(BODY_ZONE_R_ARM), "a bolt that landed under [PLASMA_ASH_MIN_LANDED] burn melted an arm")

/// A barely hurt arm stays; a pistol bolt melts a hurt arm within its margin; a rifle bolt melts a leg
/// carrying a slagged plasma critical and a pistol bolt does not; a tg critical burn alone sets up no melt;
/// chests and heads never melt.
/datum/unit_test/voidcrew_plasma_bolt/ash_limits

/datum/unit_test/voidcrew_plasma_bolt/ash_limits/Run()
	var/turf/open/from = turf_at(1, 1)

	// Damage under the "already hurt" line: even a full rifle bolt leaves the arm on.
	var/mob/living/carbon/human/consistent/light = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/right_arm = light.get_bodypart(BODY_ZONE_R_ARM)
	right_arm.receive_damage(brute = PLASMA_ASH_PRIOR_DAMAGE - 5, wound_bonus = CANT_WOUND)
	light.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, BODY_ZONE_R_ARM), BODY_ZONE_R_ARM)
	TEST_ASSERT_NOTNULL(light.get_bodypart(BODY_ZONE_R_ARM), "a rifle bolt melted an arm that was barely hurt")

	// Pistol: 15 before + 32 = 47, inside its margin (40). 5 before + 32 = 37 stays.
	var/mob/living/carbon/human/consistent/hurt = allocate(/mob/living/carbon/human/consistent, turf_at(2, 1))
	var/obj/item/bodypart/hurt_arm = hurt.get_bodypart(BODY_ZONE_L_ARM)
	hurt_arm.receive_damage(brute = 15, wound_bonus = CANT_WOUND)
	hurt.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt, from, BODY_ZONE_L_ARM), BODY_ZONE_L_ARM)
	TEST_ASSERT_NULL(hurt.get_bodypart(BODY_ZONE_L_ARM), "a pistol bolt left a hurt arm at 47/50 attached")
	var/obj/item/bodypart/hurt_leg = hurt.get_bodypart(BODY_ZONE_L_LEG)
	hurt_leg.receive_damage(brute = 5, wound_bonus = CANT_WOUND)
	hurt.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt, from, BODY_ZONE_L_LEG), BODY_ZONE_L_LEG)
	TEST_ASSERT_NOTNULL(hurt.get_bodypart(BODY_ZONE_L_LEG), "a pistol bolt melted a leg that was barely hurt")

	// A slagged plasma critical and no damage: the rifle bolt burns through, the pistol bolt does not.
	for(var/bolt_type in list(/obj/projectile/energy/plasma_bolt, /obj/projectile/energy/plasma_bolt/heavy))
		var/mob/living/carbon/human/consistent/burned = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
		var/obj/item/bodypart/leg = burned.get_bodypart(BODY_ZONE_R_LEG)
		leg.force_wound_upwards(/datum/wound/burn/flesh/plasma/critical)
		leg.heal_damage(brute = 200, burn = 200)
		var/datum/wound/burn/flesh/plasma/critical/slagged = leg.get_wound_type(/datum/wound/burn/flesh/plasma/critical)
		TEST_ASSERT_NOTNULL(slagged, "could not give a leg a plasma critical burn")
		TEST_ASSERT(slagged.slag > 0, "a fresh plasma critical carries no slag")
		var/obj/projectile/energy/plasma_bolt/bolt = make_bolt(bolt_type, from, BODY_ZONE_R_LEG)
		bolt.damage = PLASMA_ASH_MIN_LANDED
		burned.bullet_act(bolt, BODY_ZONE_R_LEG)
		if(bolt.ash_critical_burns)
			TEST_ASSERT_NULL(burned.get_bodypart(BODY_ZONE_R_LEG), "a rifle bolt left a leg with a slagged plasma critical attached")
		else
			TEST_ASSERT_NOTNULL(burned.get_bodypart(BODY_ZONE_R_LEG), "a pistol bolt melted a critically burnt leg with no damage")

	// A tg critical burn alone (fire, a laser) does not set up the rifle's burn-through.
	var/mob/living/carbon/human/consistent/fire_burned = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
	var/obj/item/bodypart/fire_leg = fire_burned.get_bodypart(BODY_ZONE_R_LEG)
	fire_leg.force_wound_upwards(/datum/wound/burn/flesh/critical)
	fire_leg.heal_damage(brute = 200, burn = 200)
	TEST_ASSERT_NOTNULL(fire_leg.get_wound_type(/datum/wound/burn/flesh/critical), "could not give a leg a tg critical burn")
	var/obj/projectile/energy/plasma_bolt/rifle_bolt = make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, BODY_ZONE_R_LEG)
	rifle_bolt.damage = 5
	fire_burned.bullet_act(rifle_bolt, BODY_ZONE_R_LEG)
	TEST_ASSERT_NOTNULL(fire_burned.get_bodypart(BODY_ZONE_R_LEG), "a rifle bolt melted a leg with only a tg critical burn")

	for(var/zone in list(BODY_ZONE_CHEST, BODY_ZONE_HEAD))
		var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, turf_at(2, 2))
		var/obj/item/bodypart/part = victim.get_bodypart(zone)
		part.receive_damage(brute = part.max_damage - 10, wound_bonus = CANT_WOUND)
		victim.bullet_act(make_bolt(/obj/projectile/energy/plasma_bolt/heavy, from, zone), zone)
		TEST_ASSERT_NOTNULL(victim.get_bodypart(zone), "a rifle bolt ashed a [zone]")
	
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

/// Sound plumbing: no tg sizzle on a plasma burn, no tg dismember sound mid-melt, and a shield slot that falls back to the shield
/datum/unit_test/voidcrew_plasma_sound_slots

/datum/unit_test/voidcrew_plasma_sound_slots/Run()
	for(var/datum/wound/burn/flesh/plasma/wound_type as anything in typesof(/datum/wound/burn/flesh/plasma))
		TEST_ASSERT_NULL(initial(wound_type.sound_effect), "[wound_type] plays a tg wound sound on top of the bolt's")

	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!plasma_melt_in_progress(victim), "A body counts as mid-melt with no melt running")
	GLOB.plasma_melt_no_splatter = WEAKREF(victim)
	TEST_ASSERT(plasma_melt_in_progress(victim), "A body mid-melt does not count as mid-melt")
	GLOB.plasma_melt_no_splatter = null

	var/obj/projectile/energy/plasma_bolt/bolt = allocate(/obj/projectile/energy/plasma_bolt)
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot)
	var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen)
	bolt.shield_block_sound = 'sound/machines/click.ogg'
	TEST_ASSERT_EQUAL(bolt.blocked_sound_for(shield), 'sound/machines/click.ogg', "A set shield sound does not replace the shield's own")
	TEST_ASSERT_NULL(bolt.blocked_sound_for(knife), "The shield sound replaced a non-shield's block sound")
	bolt.shield_block_sound = null
	TEST_ASSERT_NULL(bolt.blocked_sound_for(shield), "An unset shield sound does not fall back to the shield's own")
