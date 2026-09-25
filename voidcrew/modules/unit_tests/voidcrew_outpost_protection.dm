/// Exercise protection on ordinary ship-area turfs, not just the market area type.
/datum/unit_test/voidcrew_outpost_protection
	abstract_type = /datum/unit_test/voidcrew_outpost_protection
	var/obj/structure/overmap/trader_outpost/outpost
	var/turf/protected_turf
	var/turf/outside_turf

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
	berth.reservation = allocate(/datum/turf_reservation)
	berth.reservation.width = 1
	berth.reservation.height = 1
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

/datum/unit_test/voidcrew_outpost_protection/explosions/Run()
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, protected_turf)
	var/obj/item/pen/contents = allocate(/obj/item/pen, bag)
	explosion(bag, devastation_range = 2, flame_range = 2, flash_range = 2, silent = TRUE, adminlog = FALSE)
	TEST_ASSERT_EQUAL(length(SSexplosions.highturf), 0, "An inventory bomb propagated inside the outpost")
	TEST_ASSERT_EQUAL(length(SSexplosions.flameturf), 0, "An outpost bomb produced fire")
	TEST_ASSERT_EQUAL(length(SSexplosions.high_mov_atom), 0, "An outpost bomb triggered nested contents")
	TEST_ASSERT_EQUAL(length(SSexplosions.held_throwturf), 0, "An outpost bomb threw objects")

	explosion(outside_turf, devastation_range = 2, flame_range = 2, silent = TRUE, adminlog = FALSE)
	TEST_ASSERT(outside_turf in SSexplosions.highturf, "An outside explosion lost its normal effects")
	TEST_ASSERT(!(protected_turf in SSexplosions.highturf), "An outside explosion reached the outpost")
	TEST_ASSERT(!(protected_turf in SSexplosions.flameturf), "An outside explosion ignited the outpost")
	TEST_ASSERT(!(protected_turf in SSexplosions.held_throwturf), "An outside explosion threw outpost contents")
	// Also exercise direct explosion calls and objects moved after a blast was queued.
	EX_ACT(bag, EXPLODE_DEVASTATE)
	TEST_ASSERT(!QDELETED(bag) && !QDELETED(contents), "Direct explosion handling bypassed inventory protection")
	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, protected_turf)
	EX_ACT(visitor, EXPLODE_DEVASTATE)
	TEST_ASSERT(!QDELETED(visitor), "Direct explosion handling gibbed an outpost visitor")

/datum/unit_test/voidcrew_outpost_protection/fixtures/Run()
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, protected_turf)
	door.AddElement(/datum/element/outpost_property)
	var/integrity = door.get_integrity()
	door.take_damage(1000, BRUTE, MELEE)
	TEST_ASSERT_EQUAL(door.get_integrity(), integrity, "Outpost property took ordinary damage")
	TEST_ASSERT_EQUAL(door.emp_act(EMP_HEAVY), EMP_PROTECT_ALL, "Outpost property lacks full EMP protection")
	TEST_ASSERT(!door.secondsElectrified, "An EMP electrified an outpost door")
