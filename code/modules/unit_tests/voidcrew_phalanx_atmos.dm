/**
 * # The Phalanx atmospherics room is plumbed the way the mapper meant
 *
 * Prod round 19 (2026-08-28): every Phalanx jump threw null.add_member() from its air mixer
 * and both filters. Reading the room by the code's own linking rules (piping layer + pipe
 * colour gate every node, trinary ports come from dir/flipped) showed the real problem was
 * not the runtime: both storage siphons fed a dead-end green loop with no consumer, the
 * mixer's second input was a pump pulling from an injector, and the one "reclaimed gas"
 * line carried O2 and N2 together into a single mixer port. The ship's distro never got
 * mixer air at all. This loads the hull and checks the gas GRAPH - which device shares a
 * pipenet with which - so a future map edit that re-crosses the lines fails here.
 */
/datum/unit_test/voidcrew_phalanx_atmos

/datum/unit_test/voidcrew_phalanx_atmos/Run()
	var/obj/structure/overmap/ship/ship = vc_create_test_ship(/datum/map_template/shuttle/voidcrew/phalanx)
	if(isnull(ship))
		return
	check_atmos_room(ship)
	vc_release_test_ship(ship)

/datum/unit_test/voidcrew_phalanx_atmos/proc/check_atmos_room(obj/structure/overmap/ship/ship)
	var/obj/docking_port/mobile/port = ship.shuttle
	var/obj/machinery/atmospherics/components/trinary/mixer/airmix/mixer
	var/obj/machinery/atmospherics/components/trinary/filter/atmos/o2/o2_filter
	var/obj/machinery/atmospherics/components/trinary/filter/atmos/n2/n2_filter
	var/obj/machinery/atmospherics/components/unary/vent_pump/siphon/monitored/oxygen_output/o2_siphon
	var/obj/machinery/atmospherics/components/unary/vent_pump/siphon/monitored/nitrogen_output/n2_siphon
	var/obj/machinery/atmospherics/components/unary/outlet_injector/monitored/oxygen_input/o2_injector
	var/obj/machinery/atmospherics/components/unary/outlet_injector/monitored/nitrogen_input/n2_injector

	for(var/area/hull_area as anything in port.shuttle_areas)
		for(var/obj/machinery/atmospherics/components/machine in hull_area)
			if(istype(machine, /obj/machinery/atmospherics/components/trinary/mixer/airmix))
				TEST_ASSERT_NULL(mixer, "the Phalanx has more than one air mixer; this test expects the single atmos-room mixer")
				mixer = machine
			else if(istype(machine, /obj/machinery/atmospherics/components/trinary/filter/atmos/o2))
				o2_filter = machine
			else if(istype(machine, /obj/machinery/atmospherics/components/trinary/filter/atmos/n2))
				n2_filter = machine
			else if(istype(machine, /obj/machinery/atmospherics/components/unary/vent_pump/siphon/monitored/oxygen_output))
				o2_siphon = machine
			else if(istype(machine, /obj/machinery/atmospherics/components/unary/vent_pump/siphon/monitored/nitrogen_output))
				n2_siphon = machine
			else if(istype(machine, /obj/machinery/atmospherics/components/unary/outlet_injector/monitored/oxygen_input))
				o2_injector = machine
			else if(istype(machine, /obj/machinery/atmospherics/components/unary/outlet_injector/monitored/nitrogen_input))
				n2_injector = machine

	TEST_ASSERT_NOTNULL(mixer, "no air mixer found on the Phalanx")
	TEST_ASSERT_NOTNULL(o2_filter, "no oxygen filter found on the Phalanx")
	TEST_ASSERT_NOTNULL(n2_filter, "no nitrogen filter found on the Phalanx")
	TEST_ASSERT_NOTNULL(o2_siphon, "no monitored O2 storage siphon found on the Phalanx")
	TEST_ASSERT_NOTNULL(n2_siphon, "no monitored N2 storage siphon found on the Phalanx")
	TEST_ASSERT_NOTNULL(o2_injector, "no monitored O2 storage injector found on the Phalanx")
	TEST_ASSERT_NOTNULL(n2_injector, "no monitored N2 storage injector found on the Phalanx")

	// Every trinary needs all three ports plumbed or it refuses to run at all.
	for(var/obj/machinery/atmospherics/components/trinary/device as anything in list(mixer, o2_filter, n2_filter))
		for(var/i in 1 to 3)
			TEST_ASSERT_NOTNULL(device.nodes[i], "[device] ([device.type]) at [COORD(device)] has no pipe on port [i]")
			TEST_ASSERT_NOTNULL(device.parents[i], "[device] ([device.type]) at [COORD(device)] has no pipenet on port [i]")

	// Which mixer port is which gas is a property of the subtype, and the map must agree.
	var/o2_port = mixer.node1_concentration == O2STANDARD ? 1 : 2
	var/n2_port = o2_port == 1 ? 2 : 1
	TEST_ASSERT(abs((mixer.node1_concentration + mixer.node2_concentration) - 1) < 0.001, "the Phalanx air mixer is not a standard O2/N2 air mix")

	var/datum/pipeline/o2_net = mixer.parents[o2_port]
	var/datum/pipeline/n2_net = mixer.parents[n2_port]
	var/datum/pipeline/distro = mixer.parents[3]
	TEST_ASSERT_NOTEQUAL(o2_net, n2_net, "the mixer's two inputs are on the SAME pipenet - the O2 and N2 lines are crossed, so the mixer only ever sees one pre-mixed gas")
	TEST_ASSERT_NOTEQUAL(o2_net, distro, "the mixer's O2 input shares a pipenet with its output")
	TEST_ASSERT_NOTEQUAL(n2_net, distro, "the mixer's N2 input shares a pipenet with its output")

	// Storage feeds the mixer: each cell's siphon (and its return injector) sits on the
	// matching input line, and each filter's filtered output rejoins the same line.
	TEST_ASSERT_EQUAL(o2_siphon.parents[1], o2_net, "the O2 storage siphon is not on the mixer's O2 line - the O2 cell feeds nothing")
	TEST_ASSERT_EQUAL(n2_siphon.parents[1], n2_net, "the N2 storage siphon is not on the mixer's N2 line - the N2 cell feeds nothing")
	TEST_ASSERT_EQUAL(o2_injector.parents[1], o2_net, "the O2 storage injector is not on the O2 line")
	TEST_ASSERT_EQUAL(n2_injector.parents[1], n2_net, "the N2 storage injector is not on the N2 line")
	TEST_ASSERT_EQUAL(o2_filter.parents[2], o2_net, "the oxygen filter's filtered output does not rejoin the O2 line")
	TEST_ASSERT_EQUAL(n2_filter.parents[2], n2_net, "the nitrogen filter's filtered output does not rejoin the N2 line")

	// Waste chain: scrubber return -> one filter -> the other -> out, and never into a gas line.
	var/datum/pipeline/waste_in = o2_filter.parents[1]
	TEST_ASSERT_EQUAL(o2_filter.parents[3], n2_filter.parents[1], "the two atmos filters are not chained input-to-rest-output")
	for(var/datum/pipeline/waste as anything in list(waste_in, n2_filter.parents[3]))
		TEST_ASSERT_NOTEQUAL(waste, o2_net, "the scrubber waste line is joined to the O2 line")
		TEST_ASSERT_NOTEQUAL(waste, n2_net, "the scrubber waste line is joined to the N2 line")
		TEST_ASSERT_NOTEQUAL(waste, distro, "the scrubber waste line is joined to the distro line")
