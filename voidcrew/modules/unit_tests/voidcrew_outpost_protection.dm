/// Exercise protection on ordinary ship-area turfs, not just the market area type.
/datum/unit_test/voidcrew_outpost_protection
	abstract_type = /datum/unit_test/voidcrew_outpost_protection
	var/obj/structure/overmap/trader_outpost/outpost
	var/turf/protected_turf
	var/turf/outside_turf
	/// Bounds-only stand-in for a hangar reservation. It never claimed the live map.
	var/datum/turf_reservation/hangar_fixture

/datum/unit_test/voidcrew_outpost_protection/Destroy()
	// Releasing the stand-in would hand its corner, a test floor, to the reservation pool.
	if(hangar_fixture)
		hangar_fixture.bottom_left_turfs.Cut()
		hangar_fixture.top_right_turfs.Cut()
		hangar_fixture = null
	return ..()

/datum/unit_test/voidcrew_outpost_protection/New()
	. = ..()
	protected_turf = run_loc_floor_bottom_left
	outside_turf = get_step(protected_turf, NORTH)
	outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = 1
	outpost.outpost_template.height = 1
	outpost.template_bottom_left = protected_turf

/datum/unit_test/voidcrew_outpost_protection/boundaries/Run()
	TEST_ASSERT(is_trader_outpost_protected(protected_turf), "Concourse footprint is not protected")
	TEST_ASSERT(!is_trader_outpost_protected(outside_turf), "Protection leaked to another site on the same z-level")
	TEST_ASSERT(!is_trader_outpost_protected(null), "Nullspace must not be protected")
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, protected_turf)
	var/obj/item/pen/contents = allocate(/obj/item/pen, bag)
	TEST_ASSERT(is_trader_outpost_protected(contents), "Nested inventory did not resolve to its protected turf")
	bag.forceMove(outside_turf)
	TEST_ASSERT(!is_trader_outpost_protected(contents), "Leaving the outpost retained protection")

	var/datum/outpost_berth/berth = allocate(/datum/outpost_berth, outpost, 1, null)
	berth.hangar_bottom_left = outside_turf
	// A one-tile hangar: the berth reads its ground from the reservation's corners.
	hangar_fixture = allocate(/datum/turf_reservation)
	hangar_fixture.bottom_left_turfs = list(outside_turf)
	hangar_fixture.top_right_turfs = list(outside_turf)
	berth.reservation = hangar_fixture
	outpost.berths[1] = berth
	TEST_ASSERT(is_trader_outpost_protected(outside_turf), "Docked ship areas inside a trader hangar must be protected")
	TEST_ASSERT(!is_trader_outpost_protected(get_step(outside_turf, NORTH)), "Hangar protection leaked beyond its reservation")
	outpost.berths[1] = null
	TEST_ASSERT(!is_trader_outpost_protected(outside_turf), "Released hangar retained protection")

/datum/unit_test/voidcrew_outpost_protection/bags/Run()
	var/obj/item/storage/backpack/holding/bag = allocate(/obj/item/storage/backpack/holding, protected_turf)
	var/datum/storage/bag_of_holding/storage = bag.atom_storage
	TEST_ASSERT(!storage.can_create_rift(), "A bag bomb was allowed in the outpost")
	bag.forceMove(outside_turf)
	TEST_ASSERT(storage.can_create_rift(), "Bags cannot detonate outside the outpost")
	// Simulate relocation while the confirmation is open; the final check must be fresh.
	bag.forceMove(protected_turf)
	TEST_ASSERT(!storage.can_create_rift(), "Moving a confirmed bag into the outpost bypassed protection")
	var/obj/item/pen/pen = allocate(/obj/item/pen, protected_turf)
	TEST_ASSERT(storage.attempt_insert(pen, force = TRUE), "Protection broke ordinary bag storage")
	TEST_ASSERT_EQUAL(pen.loc, bag, "Ordinary item was not stored")

/datum/unit_test/voidcrew_outpost_protection/singularities/Run()
	var/obj/reality_tear/tear = allocate(/obj/reality_tear, protected_turf)
	tear.start_disaster()
	TEST_ASSERT(QDELETED(tear), "A bag rift started in the outpost")
	var/obj/singularity/prevented = allocate(/obj/singularity, protected_turf)
	TEST_ASSERT(QDELETED(prevented), "A singularity spawned inside the outpost")
	// Supermatter and other callers can act on the return value of new().
	prevented.expand(STAGE_TWO)
	for(var/singularity_type in subtypesof(/obj/singularity))
		var/obj/singularity/variant = allocate(singularity_type, protected_turf)
		TEST_ASSERT(QDELETED(variant), "A [singularity_type] spawned inside the outpost")

	var/obj/singularity/singulo = allocate(/obj/singularity, outside_turf)
	TEST_ASSERT(!QDELETED(singulo), "A singularity outside the outpost was suppressed")
	var/datum/component/singularity/component = singulo.singularity_component.resolve()
	STOP_PROCESSING(SSsinguloprocess, singulo)
	STOP_PROCESSING(SSsinguloprocess, component)
	singulo.expand(STAGE_FIVE)
	var/obj/structure/chair/fixture = allocate(/obj/structure/chair, protected_turf)
	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, protected_turf)
	component.consume(singulo, fixture)
	singulo.consume(visitor)
	TEST_ASSERT(!QDELETED(fixture), "Component consumption destroyed protected furniture")
	TEST_ASSERT(!QDELETED(visitor), "Direct consumption destroyed an outpost visitor")
	singulo.combust_mobs()
	TEST_ASSERT(!visitor.on_fire, "An outside singularity ignited an outpost visitor")
	component.turfs_to_consume = list(protected_turf)
	component.digest()
	TEST_ASSERT_EQUAL(fixture.loc, protected_turf, "A stage-five singularity pulled outpost property out of protection")
	TEST_ASSERT(!component.can_move(protected_turf), "Singularity movement accepts protected turfs")
	TEST_ASSERT(!singulo.Move(protected_turf, SOUTH), "Stage-five movement bypassed the outpost boundary")

	var/obj/item/pen/victim = allocate(/obj/item/pen, outside_turf)
	component.consume(singulo, victim)
	TEST_ASSERT(QDELETED(victim), "Singularity consumption stopped working outside the outpost")
	singulo.forceMove(protected_turf)
	singulo.process(1)
	TEST_ASSERT(QDELETED(singulo), "A transported singularity was not neutralized before processing")

/datum/unit_test/voidcrew_outpost_protection/teslas/Run()
	var/obj/energy_ball/prevented = allocate(/obj/energy_ball, protected_turf)
	TEST_ASSERT(QDELETED(prevented), "A Tesla spawned inside the outpost")
	var/obj/energy_ball/tesla = allocate(/obj/energy_ball, outside_turf)
	STOP_PROCESSING(SSobj, tesla)
	TEST_ASSERT(!QDELETED(tesla), "A Tesla outside the outpost was suppressed")
	TEST_ASSERT(!tesla.can_move(protected_turf), "Tesla movement accepts protected turfs")
	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, protected_turf)
	tesla.dust_mobs(visitor)
	TEST_ASSERT(!QDELETED(visitor), "A Tesla dusted an outpost visitor")
	var/list/shocked_targets = list()
	tesla_zap(tesla, power = 1 MEGA JOULES, shocked_targets = shocked_targets)
	TEST_ASSERT(!shocked_targets[visitor], "An outside Tesla arc reached an outpost visitor")
	tesla.forceMove(protected_turf)
	tesla.process()
	TEST_ASSERT(QDELETED(tesla), "A transported Tesla was not neutralized before processing")

/datum/unit_test/voidcrew_outpost_protection/explosions
	var/list/saved_queues = list()

/datum/unit_test/voidcrew_outpost_protection/explosions/New()
	. = ..()
	for(var/queue in list("highturf", "medturf", "lowturf", "high_mov_atom", "med_mov_atom", "low_mov_atom", "flameturf", "held_throwturf"))
		saved_queues[queue] = SSexplosions.vars[queue]
		SSexplosions.vars[queue] = list()

/datum/unit_test/voidcrew_outpost_protection/explosions/Destroy()
	for(var/turf/thrown_turf as anything in SSexplosions.held_throwturf)
		thrown_turf.explosion_throw_details = null
	for(var/queue in saved_queues)
		SSexplosions.vars[queue] = saved_queues[queue]
	return ..()

/// The whole 5x5 test room becomes outpost ground; returns its middle tile
/datum/unit_test/voidcrew_outpost_protection/explosions/proc/claim_room()
	outpost.outpost_template.width = run_loc_floor_top_right.x - run_loc_floor_bottom_left.x + 1
	outpost.outpost_template.height = run_loc_floor_top_right.y - run_loc_floor_bottom_left.y + 1
	return locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)

/// Applies what the blast queued, turfs then movables, as SSexplosions.fire() does (throws are left out)
/datum/unit_test/voidcrew_outpost_protection/explosions/proc/apply_blast()
	for(var/list/pass in list(list("lowturf", EXPLODE_LIGHT), list("medturf", EXPLODE_HEAVY), list("highturf", EXPLODE_DEVASTATE)))
		var/list/queued = SSexplosions.vars[pass[1]]
		SSexplosions.vars[pass[1]] = list()
		var/severity = pass[2]
		for(var/turf/blasted as anything in queued)
			EX_ACT(blasted, severity)
	for(var/list/pass in list(list("high_mov_atom", EXPLODE_DEVASTATE), list("med_mov_atom", EXPLODE_HEAVY), list("low_mov_atom", EXPLODE_LIGHT)))
		var/list/queued = SSexplosions.vars[pass[1]]
		SSexplosions.vars[pass[1]] = list()
		var/severity = pass[2]
		for(var/atom/movable/blasted as anything in queued)
			if(!QDELETED(blasted))
				EX_ACT(blasted, severity)

/// Everything a blast could change about a tile's own ground
/datum/unit_test/voidcrew_outpost_protection/explosions/proc/ground_state(turf/ground)
	. = "[ground.type] [islist(ground.baseturfs) ? jointext(ground.baseturfs, ",") : ground.baseturfs] [ground.icon_state]"
	if(isopenturf(ground))
		var/turf/open/floor = ground
		. += " [floor.broken] [floor.burnt]"

/// Decision 38: a blast at a trader outpost hurts people and placed things as anywhere, never the ground or the outpost's property
/datum/unit_test/voidcrew_outpost_protection/explosions/Run()
	var/turf/epicenter = claim_room()
	TEST_ASSERT(is_trader_outpost_protected(epicenter) && is_trader_outpost_protected(run_loc_floor_top_right), "The test room is not outpost ground")
	var/list/before = list()
	for(var/turf/ground in range(2, epicenter))
		before[ground] = ground_state(ground)

	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, get_step(epicenter, EAST))
	var/obj/structure/chair/placed = allocate(/obj/structure/chair, get_step(epicenter, WEST))
	var/obj/item/pen/loose = allocate(/obj/item/pen, epicenter)
	// Property at ground zero: a tank that blows up from its own ex_act(), and a machine with parts inside
	var/obj/structure/reagent_dispensers/fueltank/tank = allocate(/obj/structure/reagent_dispensers/fueltank, epicenter)
	tank.AddElement(/datum/element/outpost_property)
	var/obj/machinery/recharger/fixture = allocate(/obj/machinery/recharger, epicenter)
	fixture.AddElement(/datum/element/outpost_property)
	var/obj/item/circuitboard/fixture_board = fixture.circuit
	var/fixture_integrity = fixture.get_integrity()
	var/tank_integrity = tank.get_integrity()

	explosion(epicenter, heavy_impact_range = 1, light_impact_range = 2, flame_range = 0, flash_range = 0, silent = TRUE, adminlog = FALSE)
	TEST_ASSERT(epicenter in SSexplosions.medturf, "An outpost bomb did not go off")
	TEST_ASSERT(get_turf(visitor) in SSexplosions.lowturf, "The blast did not travel across the outpost floor")
	apply_blast()

	TEST_ASSERT(visitor.getBruteLoss() + visitor.getFireLoss() > 0, "An outpost bomb did not hurt a visitor beside it")
	TEST_ASSERT(QDELETED(placed) || placed.get_integrity() < placed.max_integrity, "A placed chair in the blast was unharmed")
	TEST_ASSERT(QDELETED(loose) || loose.get_integrity() < loose.max_integrity, "A loose pen at ground zero was unharmed")
	TEST_ASSERT(!QDELETED(tank) && tank.get_integrity() == tank_integrity, "A blast damaged or set off an outpost fuel tank")
	TEST_ASSERT(!QDELETED(fixture) && fixture.get_integrity() == fixture_integrity, "A blast damaged an outpost machine")
	TEST_ASSERT(!QDELETED(fixture_board) && fixture_board.loc == fixture, "A blast destroyed an outpost machine's parts")
	TEST_ASSERT_EQUAL(length(SSexplosions.highturf) + length(SSexplosions.medturf) + length(SSexplosions.lowturf), 0, "Outpost property set off a second blast")
	for(var/turf/ground as anything in before)
		TEST_ASSERT_EQUAL(ground_state(ground), before[ground], "A blast changed the outpost's ground at [ground.x],[ground.y]")

/// Decision 38: a bombing that catches a visitor at an outpost is an attack by the bomber, as a blow would be
/datum/unit_test/voidcrew_outpost_protection/explosions/bombing_reported/Run()
	var/turf/epicenter = claim_room()
	var/mob/living/carbon/human/consistent/bomber = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, get_step(epicenter, EAST))
	bomber.mind_initialize()
	visitor.mind_initialize()
	// A rocket's blast is blamed on whoever fired it
	var/obj/projectile/rocket = allocate(/obj/projectile)
	rocket.firer = bomber
	TEST_ASSERT_EQUAL(outpost_bomber_of(rocket), bomber, "A rocket's blast was not blamed on its firer")
	var/obj/item/pen/untouched = allocate(/obj/item/pen)
	TEST_ASSERT_NULL(outpost_bomber_of(untouched), "A bomb nobody touched was blamed on someone")
	// Review D1: the last hand on a bomb is never blame (whoever moved it), only whoever armed it
	untouched.fingerprintslast = "[bomber.ckey || "bomber"]"
	TEST_ASSERT_NULL(outpost_bomber_of(untouched), "A bomb nobody armed was blamed on the last hand to touch it")
	outpost_note_armed_unless_armed(untouched, visitor)
	TEST_ASSERT_EQUAL(outpost_bomber_of(untouched), visitor, "A bomb set off by hand was not blamed on that hand")
	outpost_note_armed_unless_armed(untouched, bomber)
	TEST_ASSERT_EQUAL(outpost_bomber_of(untouched), visitor, "Setting off a bomb someone else armed took the blame off the armer")
	untouched.outpost_armed_by = null
	// A grenade sewn into a plush is the sewer's bomb, not that of whoever pets the plush and sets it off
	var/obj/item/toy/plush/carpplushie/plush = allocate(/obj/item/toy/plush/carpplushie, get_turf(bomber))
	plush.stuffed = FALSE
	var/obj/item/grenade/smokebomb/sewn = allocate(/obj/item/grenade/smokebomb, get_turf(bomber))
	sewn.det_time = 1 HOURS
	bomber.put_in_hands(sewn)
	plush.attackby(sewn, bomber)
	TEST_ASSERT_EQUAL(plush.grenade, sewn, "Setup: the grenade was not sewn into the plush")
	plush.attack_self(visitor)
	TEST_ASSERT(sewn.active, "Setup: petting the plush did not set the grenade off")
	TEST_ASSERT_EQUAL(outpost_bomber_of(sewn), bomber, "A grenade sewn into a plush was blamed on [outpost_bomber_of(sewn)], not whoever sewed it in")
	plush.grenade = null
	qdel(sewn)

	explosion(epicenter, light_impact_range = 2, flame_range = 0, flash_range = 0, silent = TRUE, adminlog = FALSE, explosion_cause = rocket)
	TEST_ASSERT(LAZYACCESS(outpost.self_defense_targets[visitor.mind], bomber.mind), "A bombing at the outpost did not count as an attack on the visitor")
	TEST_ASSERT_NULL(outpost.self_defense_targets[bomber.mind], "The bombed visitor was counted as the attacker")
	apply_blast()

/datum/unit_test/voidcrew_outpost_protection/fixtures/Run()
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, protected_turf)
	door.AddElement(/datum/element/outpost_property)
	var/integrity = door.get_integrity()
	door.take_damage(1000, BRUTE, MELEE)
	TEST_ASSERT_EQUAL(door.get_integrity(), integrity, "Outpost property took ordinary damage")
	TEST_ASSERT_EQUAL(door.emp_act(EMP_HEAVY), EMP_PROTECT_ALL, "Outpost property lacks full EMP protection")
	TEST_ASSERT(!door.secondsElectrified, "An EMP electrified an outpost door")
