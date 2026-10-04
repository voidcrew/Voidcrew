/datum/unit_test/atmos_component_pipeline
	abstract_type = /datum/unit_test/atmos_component_pipeline
	var/obj/machinery/atmospherics/components/binary/volume_pump/pump
	var/obj/machinery/atmospherics/pipe/smart/south_pipe
	var/obj/machinery/atmospherics/pipe/smart/north_pipe
	var/obj/machinery/atmospherics/pipe/smart/isolated_pipe
	var/original_can_fire
	var/air_paused = FALSE

/datum/unit_test/atmos_component_pipeline/Destroy()
	if(air_paused)
		SSair.can_fire = original_can_fire
	return ..()

/// Two separate networks connected to the ports of a pump, and a third free pipe.
/datum/unit_test/atmos_component_pipeline/proc/setup_network()
	original_can_fire = SSair.can_fire
	air_paused = TRUE
	SSair.can_fire = FALSE
	var/turf/pump_turf = get_step(run_loc_floor_bottom_left, NORTH)
	pump = allocate(/obj/machinery/atmospherics/components/binary/volume_pump, pump_turf)
	pump.custom_reconcilation = TRUE
	south_pipe = allocate(/obj/machinery/atmospherics/pipe/smart, run_loc_floor_bottom_left)
	north_pipe = allocate(/obj/machinery/atmospherics/pipe/smart, get_step(pump_turf, NORTH))
	isolated_pipe = allocate(/obj/machinery/atmospherics/pipe/smart, get_step(get_step(pump_turf, EAST), EAST))
	SSair.setup_template_machinery(list(south_pipe, north_pipe, isolated_pipe, pump))
	allocated |= list(south_pipe.parent, north_pipe.parent, isolated_pipe.parent)

/datum/unit_test/atmos_component_pipeline/rebuild/Run()
	setup_network()
	var/south_port = pump.nodes.Find(south_pipe)
	TEST_ASSERT(south_port, "The pump did not connect to its southern pipe.")
	var/datum/pipeline/old_network = south_pipe.parent
	TEST_ASSERT_EQUAL(pump.parents[south_port], old_network, "The initial southern network was not built.")
	TEST_ASSERT(pump in old_network.other_atmos_machines, "The initial network did not register the pump.")
	var/datum/gas_mixture/port_air = pump.airs[south_port]
	TEST_ASSERT(port_air in old_network.other_airs, "The initial network did not register the port's gas mixture.")

	// The same rebuilding path can take a pipe/component from a still-live network.
	var/datum/pipeline/rebuilt_network = allocate(/datum/pipeline)
	south_pipe.replace_pipenet(old_network, rebuilt_network)
	rebuilt_network.build_pipeline_blocking(south_pipe)
	TEST_ASSERT_EQUAL(pump.parents[south_port], rebuilt_network, "The rebuilt network did not take the southern port.")
	TEST_ASSERT(!(pump in old_network.other_atmos_machines), "Rebuilding left the old network owning a pump that no longer points to it.")
	TEST_ASSERT(!(port_air in old_network.other_airs), "Rebuilding left the old network sharing a gas mixture owned by the new network.")
	TEST_ASSERT(!(pump in old_network.require_custom_reconcilation), "Rebuilding left custom reconciliation on the old network.")

	// Merging the old network must not try to reparent that already moved port again.
	north_pipe.parent.merge(old_network)
	TEST_ASSERT_EQUAL(pump.parents[south_port], rebuilt_network, "Merging an old network took back the rebuilt port.")

/datum/unit_test/atmos_component_pipeline/rebuild_shared_port/Run()
	setup_network()
	var/datum/pipeline/shared_network = south_pipe.parent
	shared_network.merge(north_pipe.parent)
	var/south_port = pump.nodes.Find(south_pipe)
	var/north_port = pump.nodes.Find(north_pipe)
	TEST_ASSERT(south_port && north_port, "The pump did not connect to both pipes.")
	var/datum/pipeline/rebuilt_network = allocate(/datum/pipeline)
	south_pipe.replace_pipenet(shared_network, rebuilt_network)
	rebuilt_network.build_pipeline_blocking(south_pipe)
	TEST_ASSERT_EQUAL(pump.parents[south_port], rebuilt_network, "The rebuild did not take the southern port.")
	TEST_ASSERT_EQUAL(pump.parents[north_port], shared_network, "The rebuild disconnected the untouched northern port.")
	TEST_ASSERT(!(pump.airs[south_port] in shared_network.other_airs), "The old network kept the moved port's gas mixture.")
	TEST_ASSERT(pump.airs[north_port] in shared_network.other_airs, "The old network lost the untouched port's gas mixture.")
	TEST_ASSERT(pump in shared_network.other_atmos_machines, "Moving one port unregistered a machine still connected by another port.")
	TEST_ASSERT(pump in shared_network.require_custom_reconcilation, "Moving one port removed reconciliation needed by another port.")

/datum/unit_test/atmos_component_pipeline/merge/Run()
	setup_network()
	var/datum/pipeline/shared_network = south_pipe.parent
	shared_network.merge(north_pipe.parent)
	TEST_ASSERT_EQUAL(pump.parents[1], shared_network, "The first merge did not connect the first port.")
	TEST_ASSERT_EQUAL(pump.parents[2], shared_network, "The first merge did not connect the second port.")
	var/datum/pipeline/surviving_network = isolated_pipe.parent
	surviving_network.merge(shared_network)
	TEST_ASSERT_EQUAL(pump.parents[1], surviving_network, "The second merge left the first port on the deleted network.")
	TEST_ASSERT_EQUAL(pump.parents[2], surviving_network, "The second merge left the second port on the deleted network.")
	TEST_ASSERT_EQUAL(length(pump.return_pipenet_airs(surviving_network)), 2, "The surviving network lost a pump port's gas mixture.")
