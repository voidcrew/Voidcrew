/// Newly built medical equipment must tolerate empty and unrelated multitool buffers.
/datum/unit_test/voidcrew_medical_research_buffers/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	for(var/machine_type in list(/obj/machinery/computer/dna_console, /obj/machinery/computer/operating, /mob/living/basic/bot/medbot))
		check_empty_buffer(machine_type, user, tool)

/datum/unit_test/voidcrew_medical_research_buffers/proc/check_empty_buffer(machine_type, mob/living/user, obj/item/multitool/tool)
	var/atom/movable/machine = allocate(machine_type)
	var/research_var = istype(machine, /obj/machinery/computer/dna_console) ? "stored_research" : "linked_techweb"
	tool.buffer = null
	TEST_ASSERT(machine.multitool_act(user, tool), "[machine_type] did not handle an empty multitool")
	TEST_ASSERT_NULL(machine.vars[research_var], "[machine_type] invented a link from an empty buffer")
	tool.buffer = user
	TEST_ASSERT(machine.multitool_act(user, tool), "[machine_type] did not handle an unrelated multitool buffer")
	TEST_ASSERT_NULL(machine.vars[research_var], "[machine_type] accepted a non-techweb buffer")

/// Refusing another site's disk must preserve the current link and incomplete experiment.
/datum/unit_test/voidcrew_medical_research_sites/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk)
	server.attacked_by(disk, user)
	var/turf/remote_turf
	for(var/level in 1 to world.maxz)
		var/turf/candidate = locate(1, 1, level)
		if(!same_service_site(server, candidate))
			remote_turf = candidate
			break
	TEST_ASSERT_NOTNULL(remote_turf, "No separate physical site exists for medical link testing")
	var/obj/machinery/rnd/server/ship/remote_server = allocate(/obj/machinery/rnd/server/ship, remote_turf)
	var/obj/item/computer_disk/ship_disk/remote_disk = allocate(/obj/item/computer_disk/ship_disk)
	remote_server.attacked_by(remote_disk, user)
	var/list/machines = list()
	for(var/machine_type in list(/obj/machinery/computer/dna_console, /obj/machinery/computer/operating, /mob/living/basic/bot/medbot))
		var/atom/movable/machine = check_site_links(machine_type, user, tool, disk.stored_research, remote_disk.stored_research)
		if(machine)
			machines += machine
	disk.forceMove(run_loc_floor_bottom_left)
	for(var/atom/movable/machine as anything in machines)
		var/research_var = istype(machine, /obj/machinery/computer/dna_console) ? "stored_research" : "linked_techweb"
		TEST_ASSERT_NULL(machine.vars[research_var], "Removing the physical disk left [machine.type] linked")
		if(istype(machine, /obj/machinery/computer/operating))
			var/obj/machinery/computer/operating/operating = machine
			TEST_ASSERT_NULL(operating.experiment_handler.linked_web, "Disk removal left the operating experiment handler linked")
			TEST_ASSERT_NULL(operating.experiment_handler.selected_experiment, "Disk removal retained an active experiment selection")

/datum/unit_test/voidcrew_medical_research_sites/proc/check_site_links(machine_type, mob/living/user, obj/item/multitool/tool, datum/techweb/local_web, datum/techweb/remote_web)
	var/atom/movable/machine = allocate(machine_type)
	var/research_var = istype(machine, /obj/machinery/computer/dna_console) ? "stored_research" : "linked_techweb"
	tool.buffer = local_web
	TEST_ASSERT(machine.multitool_act(user, tool), "[machine_type] refused its own physical server")
	machine.multitool_act(user, tool)
	TEST_ASSERT_EQUAL(machine.vars[research_var], local_web, "[machine_type] failed to retain its local link")
	var/registration_count = 0
	for(var/atom/consumer as anything in local_web.connected_machines)
		if(consumer == machine)
			registration_count++
	TEST_ASSERT_EQUAL(registration_count, 1, "Repeated linking duplicated [machine_type]'s consumer registration")
	var/obj/machinery/computer/operating/operating = astype(machine)
	var/datum/experiment/autopsy/human/pending
	if(operating)
		pending = allocate(/datum/experiment/autopsy/human)
		operating.experiment_handler.selected_experiment = pending
		TEST_ASSERT(operating.multitool_act(user, tool), "Repeating the existing operating link was not handled")
		TEST_ASSERT_EQUAL(operating.experiment_handler.selected_experiment, pending, "Repeating the existing link cancelled the local incomplete experiment")
	tool.buffer = remote_web
	TEST_ASSERT(!machine.multitool_act(user, tool), "[machine_type] accepted another site's research disk")
	TEST_ASSERT_EQUAL(machine.vars[research_var], local_web, "A refused link replaced [machine_type]'s local research")
	TEST_ASSERT(machine in local_web.connected_machines, "A refused link unregistered [machine_type] from its own disk")
	TEST_ASSERT(!(machine in remote_web.connected_machines), "A refused link registered [machine_type] to another site's disk")
	if(operating)
		TEST_ASSERT_EQUAL(operating.experiment_handler.linked_web, local_web, "A refused link changed the operating experiment handler's server")
		TEST_ASSERT_EQUAL(operating.experiment_handler.selected_experiment, pending, "A refused link cancelled the local incomplete experiment")
	var/previous_consumer_count = length(local_web.connected_machines)
	tool.buffer = null
	TEST_ASSERT(machine.multitool_act(user, tool), "[machine_type] did not handle an empty buffer while linked")
	TEST_ASSERT_EQUAL(machine.vars[research_var], local_web, "An empty buffer cleared [machine_type]'s working link")
	TEST_ASSERT_EQUAL(length(local_web.connected_machines), previous_consumer_count, "An empty buffer duplicated [machine_type]'s registration")
	if(operating)
		TEST_ASSERT_EQUAL(operating.experiment_handler.selected_experiment, pending, "An empty buffer cancelled the local incomplete experiment")
	return machine
