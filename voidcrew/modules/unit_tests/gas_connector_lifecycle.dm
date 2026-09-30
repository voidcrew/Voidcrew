/datum/unit_test/gas_connector_lifecycle
	abstract_type = /datum/unit_test/gas_connector_lifecycle
	var/obj/machinery/cryo_cell/machine
	var/datum/gas_machine_connector/connection
	var/obj/machinery/atmospherics/components/unary/connector
	var/obj/machinery/atmospherics/pipe/smart/pipe
	var/original_can_fire
	var/air_paused = FALSE

/datum/unit_test/gas_connector_lifecycle/Destroy()
	if(air_paused)
		SSair.can_fire = original_can_fire
	return ..()

/datum/unit_test/gas_connector_lifecycle/proc/setup_connection()
	original_can_fire = SSair.can_fire
	air_paused = TRUE
	SSair.can_fire = FALSE
	machine = allocate(/obj/machinery/cryo_cell, get_step(run_loc_floor_bottom_left, NORTH))
	connection = machine.internal_connector
	connector = connection?.gas_connector
	if(!connector)
		return FALSE
	pipe = allocate(/obj/machinery/atmospherics/pipe/smart, run_loc_floor_bottom_left)
	SSair.setup_template_machinery(list(pipe, connector))
	allocated |= list(connection, connector, pipe.parent)
	return connector.nodes[1] == pipe && connector.parents[1] == pipe.parent

/datum/unit_test/gas_connector_lifecycle/proc/check_cleanup()
	TEST_ASSERT(QDELETED(machine), "The connected cryo cell survived its connector's destruction.")
	TEST_ASSERT(QDELETED(connection), "The gas connection datum survived machine teardown.")
	TEST_ASSERT(QDELETED(connector), "The internal connector survived machine teardown.")
	TEST_ASSERT(!(machine in SSair.atmos_machinery), "The destroyed machine remained in atmos processing.")
	TEST_ASSERT(!(connector in SSair.rebuild_queue), "The destroyed connector remained queued for a pipe rebuild.")
	TEST_ASSERT(!(connector in pipe.nodes), "The surviving pipe still points to the destroyed connector.")

/datum/unit_test/gas_connector_lifecycle/connector_first/Run()
	TEST_ASSERT(setup_connection(), "The cryo cell did not connect to the test pipe.")
	// Map cleanup can encounter the internal atmos object before its visible machine.
	qdel(connector)
	check_cleanup()

/datum/unit_test/gas_connector_lifecycle/machine_first/Run()
	TEST_ASSERT(setup_connection(), "The cryo cell did not connect to the test pipe.")
	qdel(machine)
	check_cleanup()
