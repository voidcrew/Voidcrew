/datum/unit_test/late_initialization_reentry
	var/list/saved_late_loaders
	var/datum/shuttle_template_load/load_owner
	var/mapload_source = "unit test late initialization"

/datum/unit_test/late_initialization_reentry/Destroy()
	SSatoms.clear_tracked_initalize(mapload_source)
	if(saved_late_loaders)
		SSatoms.late_loaders = saved_late_loaders
	if(load_owner)
		SSshuttle.release_template_load(load_owner)
	return ..()

/datum/unit_test/late_initialization_reentry/Run()
	load_owner = SSshuttle.acquire_template_load(1 MINUTES)
	TEST_ASSERT_NOTNULL(load_owner, "Could not reserve the loader for the nested initialization fixture")
	saved_late_loaders = SSatoms.late_loaders
	SSatoms.late_loaders = list()
	SSatoms.map_loader_begin(mapload_source)
	var/obj/machinery/late_initialization_probe/before = allocate(/obj/machinery/late_initialization_probe)
	var/obj/effect/late_initialization_reentry/nested = allocate(/obj/effect/late_initialization_reentry)
	nested.perform_nested_load = TRUE
	var/obj/machinery/late_initialization_probe/after = allocate(/obj/machinery/late_initialization_probe)
	SSatoms.map_loader_stop(mapload_source)
	SSatoms.InitializeAtoms(list(before, nested, after))
	TEST_ASSERT_EQUAL(before.late_calls, 1, "Nested initialization reprocessed earlier machinery")
	TEST_ASSERT_EQUAL(after.late_calls, 1, "Nested initialization lost or repeated later machinery")
	TEST_ASSERT_EQUAL(nested.late_calls, 1, "Nested initialization reprocessed its own initiating atom")
	TEST_ASSERT_EQUAL(length(SSatoms.late_loaders), 0, "Nested initialization left an undrained queue")
	// During startup, new atoms created by late callbacks also need a late callback.
	SSatoms.set_tracked_initalized(INITIALIZATION_INNEW_MAPLOAD, mapload_source)
	var/obj/effect/late_initialization_enqueue/enqueuer = allocate(/obj/effect/late_initialization_enqueue)
	enqueuer.spawn_followup = TRUE
	SSatoms.InitializeAtoms(list())
	SSatoms.clear_tracked_initalize(mapload_source)
	TEST_ASSERT_NOTNULL(enqueuer.new_machine, "The late callback did not create its follow-up machine")
	TEST_ASSERT_EQUAL(enqueuer.new_machine.late_calls, 1, "A machine queued during a late callback was lost or initialized twice")
	TEST_ASSERT_EQUAL(length(SSatoms.late_loaders), 0, "Follow-up initialization left an undrained queue")

/// Generic construction tests must not activate these helpers' map-loading behavior.
/datum/unit_test/late_initialization_reentry/helpers/Run()
	load_owner = SSshuttle.acquire_template_load(1 MINUTES)
	TEST_ASSERT_NOTNULL(load_owner, "Could not reserve the loader for the helper construction check")
	saved_late_loaders = SSatoms.late_loaders
	SSatoms.late_loaders = list()
	SSatoms.set_tracked_initalized(INITIALIZATION_INNEW_MAPLOAD, mapload_source)
	var/obj/machinery/late_initialization_probe/pending = allocate(/obj/machinery/late_initialization_probe)
	SSatoms.clear_tracked_initalize(mapload_source)
	allocate(/obj/effect/late_initialization_reentry)
	var/obj/effect/late_initialization_enqueue/enqueuer = allocate(/obj/effect/late_initialization_enqueue)
	TEST_ASSERT_EQUAL(pending.late_calls, 0, "Constructing an unarmed helper drained another load's pending initialization")
	TEST_ASSERT_NULL(enqueuer.new_machine, "Constructing an unarmed helper created extra machinery")
	SSatoms.InitializeAtoms(list())
	TEST_ASSERT_EQUAL(pending.late_calls, 1, "The pending machine did not initialize when its loader resumed")

/obj/machinery/late_initialization_probe
	var/late_calls = 0

/obj/machinery/late_initialization_probe/post_machine_initialize()
	late_calls++
	return ..()

/obj/effect/late_initialization_reentry
	var/late_calls = 0
	var/perform_nested_load = FALSE

/obj/effect/late_initialization_reentry/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/effect/late_initialization_reentry/LateInitialize()
	late_calls++
	if(perform_nested_load && late_calls == 1)
		SSatoms.InitializeAtoms(list())

/obj/effect/late_initialization_enqueue
	var/obj/machinery/late_initialization_probe/new_machine
	var/spawn_followup = FALSE

/obj/effect/late_initialization_enqueue/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/effect/late_initialization_enqueue/Destroy()
	QDEL_NULL(new_machine)
	return ..()

/obj/effect/late_initialization_enqueue/LateInitialize()
	if(spawn_followup && !new_machine)
		new_machine = new(get_turf(src))
