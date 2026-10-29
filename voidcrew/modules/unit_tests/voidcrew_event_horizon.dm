/// The sole difference from master's rifle is the missing scope.
/datum/unit_test/voidcrew_event_horizon_defaults/Run()
	var/obj/item/gun/energy/event_horizon/rifle = allocate(/obj/item/gun/energy/event_horizon)
	TEST_ASSERT_NULL(rifle.GetComponent(/datum/component/scope), "A new Event Horizon must have no scope.")
	TEST_ASSERT(rifle.selfcharge, "The Event Horizon must recharge itself.")
	TEST_ASSERT(rifle.can_charge, "The Event Horizon must accept external charging.")
	TEST_ASSERT_EQUAL(rifle.get_cell(null, null), rifle.cell, "The Event Horizon must expose its cell to chargers.")
	TEST_ASSERT_EQUAL(rifle.self_charge_amount, STANDARD_ENERGY_GUN_SELF_CHARGE_RATE * 10, "The Event Horizon's recharge rate must match master.")
	TEST_ASSERT(!(rifle.gun_flags & TURRET_INCOMPATIBLE), "The Event Horizon must fit emitters and turrets.")
	var/obj/item/ammo_casing/energy/event_horizon/shot = rifle.ammo_type[rifle.select]
	TEST_ASSERT_EQUAL(shot.e_cost, LASER_SHOTS(1, STANDARD_CELL_CHARGE), "The Event Horizon must expend a full standard cell per shot.")
	TEST_ASSERT_EQUAL(rifle.fire_delay, shot.delay, "The Event Horizon must use its upstream firing delay.")
	var/obj/projectile/beam/event_horizon/projectile = shot.loaded_projectile
	TEST_ASSERT(istype(projectile), "The Event Horizon must fire its upstream beam.")
	TEST_ASSERT_EQUAL(projectile.damage, 100, "The Event Horizon beam must deal master's damage.")
	TEST_ASSERT_EQUAL(projectile.damage_type, BURN, "The Event Horizon beam must deal burn damage.")
	TEST_ASSERT_EQUAL(projectile.range, 150, "The Event Horizon beam must keep master's range.")

/// Exercise real firing and recharging without releasing a destructive projectile in the test room.
/datum/unit_test/voidcrew_event_horizon_firing/Run()
	var/obj/item/gun/energy/event_horizon/rifle = allocate(/obj/item/gun/energy/event_horizon)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!HAS_TRAIT(user, TRAIT_USER_SCOPED), "The shooter must start unscoped.")
	var/obj/item/ammo_casing/energy/original_shot = rifle.ammo_type[rifle.select]
	var/obj/item/ammo_casing/energy/event_horizon/unit_test/shot = allocate(/obj/item/ammo_casing/energy/event_horizon/unit_test, rifle)
	rifle.ammo_type[rifle.select] = shot
	rifle.chambered = shot
	qdel(original_shot)
	TEST_ASSERT(rifle.process_fire(run_loc_floor_top_right, user, FALSE, null, "", 0), "The Event Horizon must fire without scoping.")
	TEST_ASSERT_EQUAL(rifle.cell.charge, 0, "One shot must empty the Event Horizon's cell.")
	TEST_ASSERT(!rifle.can_shoot(), "An empty Event Horizon must not fire.")
	rifle.process(rifle.charge_delay)
	TEST_ASSERT_EQUAL(rifle.cell.charge, rifle.cell.maxcharge, "The Event Horizon must regain a full shot at master's recharge rate.")
	// Recharge and clear only the ordinary gun cooldown; the old 20-second rifle cooldown would still block this.
	rifle.reset_fire_cd()
	TEST_ASSERT(rifle.process_fire(run_loc_floor_top_right, user, FALSE, null, "", 0), "A recharged Event Horizon must fire again without the old rifle cooldown.")
	TEST_ASSERT_EQUAL(rifle.cell.charge, 0, "The recharged shot must spend the cell again.")
	TEST_ASSERT(!HAS_TRAIT(user, TRAIT_USER_SCOPED), "Firing the Event Horizon must not scope the shooter.")

/obj/item/ammo_casing/energy/event_horizon/unit_test/fire_casing(atom/target, mob/living/user, params, distro, quiet, zone_override, spread, atom/fired_from)
	// Only substitute projectile launch; the rifle still chambers, consumes charge and recharges normally.
	QDEL_NULL(loaded_projectile)
	return TRUE

/// A beam hit spawns master's temporary tear, which consumes people as well as the room.
/datum/unit_test/voidcrew_event_horizon_tear/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/pen/fixture = allocate(/obj/item/pen)
	var/obj/projectile/beam/event_horizon/projectile = allocate(/obj/projectile/beam/event_horizon)
	projectile.on_hit(victim, 0, FALSE)
	var/obj/reality_tear/temporary/tear = locate(/obj/reality_tear/temporary) in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(tear, "An Event Horizon hit must create a temporary reality tear.")
	var/datum/component/singularity/singularity = tear.GetComponent(/datum/component/singularity)
	TEST_ASSERT_NOTNULL(singularity, "The Event Horizon tear must start its singularity.")
	// Consume only the chosen targets, without damaging test-room turfs or other tests.
	STOP_PROCESSING(SSsinguloprocess, singularity)
	TEST_ASSERT_EQUAL(victim.getFireLoss(), 0, "The hit callback must not add the nerf's extra 200 burn damage.")
	TEST_ASSERT_EQUAL(singularity.consume_range, 2, "The Event Horizon tear must keep master's consumption radius.")
	TEST_ASSERT_EQUAL(singularity.grav_pull, 3, "The Event Horizon tear must keep master's pull radius.")
	TEST_ASSERT_EQUAL(singularity.singularity_size, STAGE_SIX, "The Event Horizon tear must keep master's singularity strength.")
	TEST_ASSERT(!singularity.roaming, "The Event Horizon tear must remain stationary.")
	TEST_ASSERT_EQUAL(tear.collapse_spawn_time, 2 SECONDS, "The Event Horizon tear must keep master's lifetime.")
	singularity.consume(tear, fixture)
	TEST_ASSERT(QDELETED(fixture), "The Event Horizon tear must consume nearby objects.")
	singularity.consume(tear, victim)
	TEST_ASSERT(QDELETED(victim), "The Event Horizon tear must gib and consume people.")
	tear.reality_collapse()
	TEST_ASSERT(QDELETED(tear), "The temporary tear must disappear when it collapses.")
	TEST_ASSERT_NULL(locate(/obj/singularity) in run_loc_floor_bottom_left, "The temporary tear must not leave a wandering singularity.")

/// Both machine installation paths must accept the rifle and retain its beam.
/datum/unit_test/voidcrew_event_horizon_mounting/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/energy/event_horizon/emitter_rifle = allocate(/obj/item/gun/energy/event_horizon)
	var/obj/machinery/power/emitter/emitter = allocate(/obj/machinery/power/emitter)
	TEST_ASSERT(user.put_in_hands(emitter_rifle), "The shooter must hold the rifle for emitter installation.")
	TEST_ASSERT(emitter.integrate(emitter_rifle, user), "An emitter must accept the Event Horizon.")
	TEST_ASSERT_EQUAL(emitter.gun, emitter_rifle, "The emitter must retain its installed Event Horizon.")
	TEST_ASSERT_EQUAL(emitter.gun_properties["lethal_projectile"], /obj/projectile/beam/event_horizon, "The emitter must retain the Event Horizon's beam.")
	var/obj/item/gun/energy/event_horizon/turret_rifle = allocate(/obj/item/gun/energy/event_horizon)
	var/obj/machinery/porta_turret_construct/frame = allocate(/obj/machinery/porta_turret_construct)
	frame.build_step = 3 // PTURRET_INTERNAL_ARMOUR_ON (local to portable_turret_construct.dm).
	TEST_ASSERT(user.put_in_hands(turret_rifle), "The shooter must hold the rifle for turret installation.")
	frame.attackby(turret_rifle, user, list(), list())
	TEST_ASSERT_EQUAL(frame.installed_gun, turret_rifle, "A turret frame must accept the Event Horizon.")
	TEST_ASSERT_EQUAL(frame.build_step, 4, "Installing the Event Horizon must advance turret construction.") // PTURRET_GUN_EQUIPPED
