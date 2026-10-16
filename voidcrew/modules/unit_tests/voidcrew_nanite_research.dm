/// Physical research disks must stay local when nanite equipment or its server moves.
/datum/unit_test/voidcrew_nanite_research
	parent_type = /datum/unit_test/voidcrew_research_movement
	abstract_type = /datum/unit_test/voidcrew_nanite_research

/datum/unit_test/voidcrew_nanite_research/buffers/Run()
	TEST_ASSERT(setup_links(), "No separate site exists for nanite link testing")
	var/obj/machinery/rnd/server/ship/remote_server = allocate(/obj/machinery/rnd/server/ship, remote_turf)
	var/obj/item/computer_disk/ship_disk/remote_disk = allocate(/obj/item/computer_disk/ship_disk)
	remote_server.attacked_by(remote_disk, user)
	for(var/machine_type in list(/obj/machinery/computer/nanite_cloud_controller, /obj/machinery/nanite_chamber, /obj/machinery/public_nanite_chamber))
		check_buffer(machine_type, remote_disk.stored_research)

/datum/unit_test/voidcrew_nanite_research/buffers/proc/check_buffer(machine_type, datum/techweb/remote_web)
	var/obj/machinery/machine = allocate(machine_type)
	tool.buffer = web
	machine.multitool_act(user, tool)
	machine.multitool_act(user, tool)
	TEST_ASSERT_EQUAL(machine.vars["linked_techweb"], web, "[machine_type] could not link its own physical research disk")
	var/registrations = 0
	for(var/atom/consumer as anything in web.connected_machines)
		if(consumer == machine)
			registrations++
	TEST_ASSERT_EQUAL(registrations, 1, "Repeated linking duplicated [machine_type]'s registration")
	tool.buffer = remote_web
	machine.multitool_act(user, tool)
	TEST_ASSERT_EQUAL(machine.vars["linked_techweb"], web, "A foreign buffer replaced [machine_type]'s working link")
	TEST_ASSERT(!(machine in remote_web.connected_machines), "A rejected foreign buffer registered [machine_type]")
	tool.buffer = null
	machine.multitool_act(user, tool)
	TEST_ASSERT_EQUAL(machine.vars["linked_techweb"], web, "An empty buffer cleared [machine_type]'s working link")
	tool.buffer = user
	machine.multitool_act(user, tool)
	TEST_ASSERT_EQUAL(machine.vars["linked_techweb"], web, "An unrelated buffer cleared [machine_type]'s working link")
	var/datum/techweb/deleted_web = allocate(/datum/techweb)
	qdel(deleted_web)
	tool.buffer = deleted_web
	machine.multitool_act(user, tool)
	TEST_ASSERT_EQUAL(machine.vars["linked_techweb"], web, "A deleted buffer cleared [machine_type]'s working link")
	TEST_ASSERT(machine in web.connected_machines, "Rejected buffers unregistered [machine_type]'s working link")

/datum/unit_test/voidcrew_nanite_research/programmer/Run()
	TEST_ASSERT(setup_links(), "No separate site exists for nanite programmer testing")
	web.add_design_by_id("monitoring_nanites")
	for(var/move_server in list(FALSE, TRUE))
		check_programmer(move_server)
		server.forceMove(run_loc_floor_bottom_left)

/datum/unit_test/voidcrew_nanite_research/programmer/proc/check_programmer(move_server)
	var/obj/machinery/computer/nanite_cloud_controller/programmer = allocate(/obj/machinery/computer/nanite_cloud_controller)
	var/datum/nanite_program/old_program = allocate(/datum/nanite_program/self_scan)
	programmer.current_program = old_program
	programmer.multitool_act(user, tool)
	var/list/local_catalog = programmer.ui_static_data(user)
	TEST_ASSERT(length(local_catalog["programs"]), "The local programmer did not expose researched nanite programs")
	var/datum/tgui/ui = allocate(/datum/tgui, user, programmer, "NaniteCloudControl")
	move_apart(programmer, move_server)
	programmer.ui_act("download", list("program_id" = "monitoring_nanites"), ui)
	TEST_ASSERT_EQUAL(programmer.current_program, old_program, "A moved programmer replaced its program with a foreign research download (server moved: [move_server])")
	TEST_ASSERT_NULL(programmer.linked_techweb, "A moved programmer retained its foreign research link")
	TEST_ASSERT(!(programmer in web.connected_machines), "A moved programmer remained registered to its foreign disk")
	var/list/remote_catalog = programmer.ui_static_data(user)
	TEST_ASSERT(!length(remote_catalog["programs"]), "A moved programmer exposed foreign research in its catalog")
	// Moving both endpoints together keeps the same site's own link.
	server.forceMove(get_turf(programmer))
	programmer.multitool_act(user, tool)
	server.forceMove(run_loc_floor_bottom_left)
	programmer.forceMove(run_loc_floor_bottom_left)
	programmer.ui_act("download", list("program_id" = "monitoring_nanites"), ui)
	TEST_ASSERT(istype(programmer.current_program, /datum/nanite_program/monitoring), "A reunited programmer could not download its local program")
	TEST_ASSERT_EQUAL(programmer.linked_techweb, web, "Moving both endpoints together severed the local programmer link")
	move_apart(programmer, move_server)
	programmer.ui_data()
	TEST_ASSERT_NULL(programmer.linked_techweb, "Programmer UI refresh retained a separated research link")
	TEST_ASSERT(istype(programmer.current_program, /datum/nanite_program/monitoring), "Programmer UI refresh erased the program being edited")

/// Imports must use the receiving controller's current research, never the disk or cloud's history.
/datum/unit_test/voidcrew_nanite_research/backup_import
	abstract_type = /datum/unit_test/voidcrew_nanite_research/backup_import
	var/obj/machinery/computer/nanite_cloud_controller/controller
	var/obj/item/disk/nanite_program/backup_disk
	var/datum/nanite_cloud_backup/cloud
	var/datum/nanite_program/cloud_program
	var/datum/nanite_program/cloud_settings
	var/datum/nanite_program/disk_program
	var/datum/nanite_program/disk_settings
	var/datum/tgui/ui

/datum/unit_test/voidcrew_nanite_research/backup_import/proc/setup_import()
	if(!setup_links())
		return FALSE
	web.add_design_by_id("selfscan_nanites")
	web.researched_designs -= "monitoring_nanites"
	controller = allocate(/obj/machinery/computer/nanite_cloud_controller)
	controller.multitool_act(user, tool)
	controller.current_view = 95
	controller.generate_backup(controller.current_view, user)
	cloud = controller.get_backup(controller.current_view)
	if(!cloud)
		return FALSE
	cloud_program = allocate(/datum/nanite_program/self_scan)
	cloud_program.activation_code = 1234
	cloud_program.timer_restart = 120
	cloud_program.set_extra_setting("Scan Type", "Chemical") // NES_SCAN_TYPE
	cloud.nanites.add_program(null, cloud_program)
	cloud_settings = allocate(/datum/nanite_program/self_scan)
	cloud_program.copy_programming(cloud_settings)
	backup_disk = allocate(/obj/item/disk/nanite_program, controller)
	controller.disk = backup_disk
	disk_program = allocate(/datum/nanite_program/self_scan)
	disk_program.activated = FALSE
	disk_program.activation_code = 4321
	disk_program.deactivation_code = 2345
	disk_program.kill_code = 3456
	disk_program.trigger_code = 4567
	disk_program.timer_restart = 230
	disk_program.timer_shutdown = 340
	disk_program.timer_trigger = 450
	disk_program.timer_trigger_delay = 560
	disk_program.all_rules_required = FALSE
	disk_program.set_extra_setting("Scan Type", "Nanite") // NES_SCAN_TYPE
	allocate(/datum/nanite_rule/health, disk_program)
	backup_disk.backup += disk_program
	disk_settings = allocate(/datum/nanite_program/self_scan)
	disk_program.copy_programming(disk_settings)
	allocated += disk_settings.rules
	ui = allocate(/datum/tgui, user, controller, "NaniteCloudControl")
	return TRUE

/datum/unit_test/voidcrew_nanite_research/backup_import/proc/assert_rejected(reason)
	var/list/contents_before = backup_disk.backup.Copy()
	controller.ui_act("load_backup", list(), ui)
	TEST_ASSERT_EQUAL(length(cloud.nanites.programs), 1, "[reason]: rejection changed the cloud's program count")
	TEST_ASSERT(cloud_program in cloud.nanites.programs, "[reason]: rejection replaced the existing cloud program")
	TEST_ASSERT(!QDELETED(cloud_program), "[reason]: rejection deleted the existing cloud program")
	TEST_ASSERT(!cloud_settings.programming_differs(cloud_program), "[reason]: rejection changed existing cloud settings")
	TEST_ASSERT_EQUAL(controller.disk, backup_disk, "[reason]: rejection discarded the source disk")
	TEST_ASSERT(!QDELETED(backup_disk), "[reason]: rejection deleted the source disk")
	TEST_ASSERT_EQUAL(length(backup_disk.backup), length(contents_before), "[reason]: rejection changed the disk's program count")
	for(var/index in 1 to length(contents_before))
		TEST_ASSERT_EQUAL(backup_disk.backup[index], contents_before[index], "[reason]: rejection changed a disk entry")
	TEST_ASSERT(!QDELETED(disk_program), "[reason]: rejection deleted the disk's permitted program")
	TEST_ASSERT(!disk_settings.programming_differs(disk_program), "[reason]: rejection changed disk settings")

/datum/unit_test/voidcrew_nanite_research/backup_import/permitted/Run()
	TEST_ASSERT(setup_import(), "Could not prepare backup import testing")
	web.add_design_by_id("monitoring_nanites")
	var/datum/nanite_program/second_program = allocate(/datum/nanite_program/monitoring)
	backup_disk.backup += second_program
	controller.ui_act("load_backup", list(), ui)
	TEST_ASSERT(QDELETED(cloud_program), "A permitted import did not replace the old cloud program")
	TEST_ASSERT_EQUAL(length(cloud.nanites.programs), 2, "A permitted import did not load the entire disk")
	var/datum/nanite_program/imported = cloud.nanites.programs[1]
	TEST_ASSERT_EQUAL(imported.type, disk_program.type, "A permitted import changed the program type")
	TEST_ASSERT(imported != disk_program, "A permitted import installed the source datum instead of a copy")
	TEST_ASSERT(!disk_settings.programming_differs(imported), "A permitted import lost codes, timers, rules or extra settings")
	allocated += imported.rules
	var/datum/nanite_program/second_imported = cloud.nanites.programs[2]
	TEST_ASSERT_EQUAL(second_imported.type, second_program.type, "A permitted import lost its second program")
	TEST_ASSERT(second_imported != second_program, "A permitted import took its second program from the disk")
	TEST_ASSERT_EQUAL(controller.disk, backup_disk, "A permitted import discarded its disk")
	TEST_ASSERT_EQUAL(backup_disk.backup[1], disk_program, "A permitted import replaced the first disk program")
	TEST_ASSERT_EQUAL(backup_disk.backup[2], second_program, "A permitted import replaced the second disk program")
	TEST_ASSERT(!disk_settings.programming_differs(disk_program), "A permitted import changed the disk's settings")
	backup_disk.backup.Cut()
	controller.ui_act("load_backup", list(), ui)
	TEST_ASSERT_EQUAL(length(cloud.nanites.programs), 0, "A valid local research link could not import an empty backup")

/datum/unit_test/voidcrew_nanite_research/backup_import/forbidden/Run()
	TEST_ASSERT(setup_import(), "Could not prepare backup rejection testing")
	var/datum/nanite_program/forbidden = allocate(/datum/nanite_program/monitoring)
	backup_disk.backup += forbidden
	assert_rejected("Permitted program followed by an unresearched program")
	TEST_ASSERT(!QDELETED(forbidden), "Rejection deleted the disk's unresearched program")
	backup_disk.backup.Swap(1, 2)
	assert_rejected("Unresearched program followed by a permitted program")
	backup_disk.backup = list(disk_program)
	var/datum/nanite_program/unknown = allocate(/datum/nanite_program/sensor)
	unknown.name = disk_program.name
	backup_disk.backup += unknown
	web.add_design_by_id("repeater_nanites")
	assert_rejected("Unknown actual type with a permitted display name and researched sensor subtype")
	backup_disk.backup = list(disk_program)
	var/datum/nanite_program/deleted = allocate(/datum/nanite_program/self_scan)
	qdel(deleted)
	for(var/invalid in list(null, "invalid program", /datum/nanite_program/self_scan, deleted))
		backup_disk.backup += list(invalid)
		assert_rejected("Invalid disk entry [invalid]")
		backup_disk.backup.Cut(2)
	// An open catalog must confer no authority after research changes.
	controller.ui_static_data(user)
	web.researched_designs["selfscan_nanites"] = FALSE
	assert_rejected("Research removed after catalog generation")

/datum/unit_test/voidcrew_nanite_research/backup_import/research_link/Run()
	TEST_ASSERT(setup_import(), "Could not prepare backup research-link testing")
	controller.unsync_research_servers()
	assert_rejected("Missing receiver research, despite the cloud's old research attribution")
	backup_disk.backup.Cut()
	assert_rejected("Empty backup without receiver research")
	var/datum/techweb/deleted_web = allocate(/datum/techweb)
	qdel(deleted_web)
	controller.linked_techweb = deleted_web
	assert_rejected("Empty backup with a deleted receiver techweb")
	TEST_ASSERT_NULL(controller.linked_techweb, "A rejected import retained a deleted research link")
	backup_disk.backup += disk_program
	for(var/move_server in list(FALSE, TRUE))
		controller.multitool_act(user, tool)
		move_apart(controller, move_server)
		assert_rejected("Separated research endpoints (server moved: [move_server])")
		TEST_ASSERT_NULL(controller.linked_techweb, "A rejected import retained a foreign research link")
		TEST_ASSERT(!(controller in web.connected_machines), "A rejected import retained a foreign research registration")
		server.forceMove(run_loc_floor_bottom_left)
		controller.forceMove(run_loc_floor_bottom_left)
	controller.multitool_act(user, tool)
	var/obj/item/computer_disk/ship_disk/source_disk = server.source_code_hdd
	source_disk.forceMove(run_loc_floor_bottom_left)
	// Even a stale reference to the removed disk must not authorize an import.
	controller.linked_techweb = web
	web.connected_machines |= controller
	assert_rejected("Removed research source disk")
	TEST_ASSERT_NULL(controller.linked_techweb, "A rejected import retained a removed research disk's link")
	server.attacked_by(source_disk, user)
	controller.multitool_act(user, tool)
	backup_disk.forceMove(run_loc_floor_bottom_left)
	assert_rejected("Removed backup disk with a stale controller reference")
	backup_disk.forceMove(controller)
	server.forceMove(remote_turf)
	controller.forceMove(remote_turf)
	controller.ui_act("load_backup", list(), ui)
	TEST_ASSERT(QDELETED(cloud_program), "Moving both endpoints together prevented a permitted import")
	TEST_ASSERT_EQUAL(length(cloud.nanites.programs), 1, "Moving both endpoints together lost the imported program")
	var/datum/nanite_program/imported = cloud.nanites.programs[1]
	allocated += imported.rules
	TEST_ASSERT(!disk_settings.programming_differs(imported), "Import after movement lost its settings")

/datum/unit_test/voidcrew_nanite_research/backup_import/checkpoint/Run()
	TEST_ASSERT(setup_import(), "Could not prepare nanite checkpoint testing")
	controller.current_program = allocate(/datum/nanite_program/monitoring)
	var/datum/ship_checkpoint/snapshot = allocate(/datum/ship_checkpoint)
	var/machine_text = snapshot.atom_text(controller)
	var/datum/parsed_map/parsed = allocate(/datum/parsed_map, "\"a\" = ([machine_text],/turf/template_noop,/area/template_noop)\n(1,1,1) = {\"\na\n\"}\n")
	var/datum/map_template/template = allocate(/datum/map_template)
	template.cached_map = parsed
	template.width = 1
	template.height = 1
	TEST_ASSERT(template.load(run_loc_floor_top_right), "Could not load the checkpoint controller")
	var/obj/machinery/computer/nanite_cloud_controller/rebuilt = locate() in run_loc_floor_top_right
	TEST_ASSERT_NOTNULL(rebuilt, "The checkpoint omitted its nanite controller")
	TEST_ASSERT_EQUAL(length(rebuilt.cloud_backups), 0, "The checkpoint retained cloud backup contents")
	TEST_ASSERT_NULL(rebuilt.disk, "The checkpoint retained its source disk")
	TEST_ASSERT_NULL(locate(/obj/item/disk/nanite_program) in rebuilt, "The checkpoint copied a program disk into the controller")
	TEST_ASSERT_NULL(rebuilt.current_program, "The checkpoint retained the program being edited")
	TEST_ASSERT_NULL(rebuilt.linked_techweb, "The checkpoint retained the original research link")
	TEST_ASSERT_EQUAL(controller.get_backup(controller.current_view), cloud, "The checkpoint changed the original controller's cloud")
	TEST_ASSERT_EQUAL(controller.disk, backup_disk, "The checkpoint changed the original controller's disk")

/datum/unit_test/voidcrew_nanite_research/chambers/Run()
	TEST_ASSERT(setup_links(), "No separate site exists for nanite chamber testing")
	for(var/move_server in list(FALSE, TRUE))
		check_chamber(move_server)
		server.forceMove(run_loc_floor_bottom_left)
		check_public_chamber(move_server)
		server.forceMove(run_loc_floor_bottom_left)

/datum/unit_test/voidcrew_nanite_research/chambers/proc/check_chamber(move_server)
	var/obj/machinery/nanite_chamber/chamber = allocate(/obj/machinery/nanite_chamber)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent, chamber)
	chamber.occupant = patient
	chamber.multitool_act(user, tool)
	move_apart(chamber, move_server)
	chamber.complete_injection(FALSE)
	TEST_ASSERT_NULL(patient.GetComponent(/datum/component/nanites), "A separated chamber injected nanites using foreign research (server moved: [move_server])")
	TEST_ASSERT_NULL(chamber.linked_techweb, "A separated chamber retained its research link")
	TEST_ASSERT(!chamber.busy && !chamber.locked, "Rejecting a stale injection left the chamber busy or locked")
	server.forceMove(get_turf(chamber))
	chamber.multitool_act(user, tool)
	chamber.complete_injection(FALSE)
	var/datum/component/nanites/nanites = patient.GetComponent(/datum/component/nanites)
	TEST_ASSERT_NOTNULL(nanites, "A reunited chamber could not inject nanites")
	TEST_ASSERT_EQUAL(nanites.linked_techweb, web, "A reunited chamber lost local research attribution")

/datum/unit_test/voidcrew_nanite_research/chambers/proc/check_public_chamber(move_server)
	var/obj/machinery/public_nanite_chamber/chamber = allocate(/obj/machinery/public_nanite_chamber)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent, chamber)
	chamber.occupant = patient
	chamber.cloud_id = 0
	chamber.multitool_act(user, tool)
	move_apart(chamber, move_server)
	chamber.complete_injection(FALSE)
	var/datum/component/nanites/nanites = patient.GetComponent(/datum/component/nanites)
	TEST_ASSERT_NOTNULL(nanites, "A public chamber lost its existing ability to inject without research")
	TEST_ASSERT_NULL(chamber.linked_techweb, "A public chamber retained its separated research link")
	TEST_ASSERT_NULL(nanites.linked_techweb, "A public chamber attributed new nanites to foreign research (server moved: [move_server])")
	var/datum/nanite_program/program = allocate(/datum/nanite_program/monitoring)
	nanites.add_program(null, program)
	chamber.complete_injection(FALSE)
	TEST_ASSERT(program in nanites.programs, "Unlinked injection erased an installed nanite program")
	TEST_ASSERT(!chamber.busy && !chamber.locked, "Public injection left the chamber busy or locked")

/datum/unit_test/voidcrew_nanite_research/cloud/Run()
	TEST_ASSERT(setup_links(), "No separate site exists for nanite cloud testing")
	for(var/move_server in list(FALSE, TRUE))
		check_cloud(move_server)
		server.forceMove(run_loc_floor_bottom_left)

/datum/unit_test/voidcrew_nanite_research/cloud/proc/check_cloud(move_server)
	var/obj/machinery/computer/nanite_cloud_controller/controller = allocate(/obj/machinery/computer/nanite_cloud_controller)
	controller.multitool_act(user, tool)
	var/backup_id = 91 + move_server * 2
	controller.generate_backup(backup_id, user)
	var/datum/nanite_cloud_backup/original = controller.get_backup(backup_id)
	TEST_ASSERT_NOTNULL(original, "A local controller could not create a cloud backup")
	TEST_ASSERT_EQUAL(original.nanites.linked_techweb, web, "A local cloud backup lost its research attribution")
	var/datum/nanite_program/program = allocate(/datum/nanite_program/monitoring)
	original.nanites.add_program(null, program)
	move_apart(controller, move_server)
	controller.generate_backup(backup_id + 1, user)
	var/datum/nanite_cloud_backup/unlinked = controller.get_backup(backup_id + 1)
	TEST_ASSERT_NOTNULL(unlinked, "A controller lost its existing ability to create backups without research")
	TEST_ASSERT_NULL(controller.linked_techweb, "A moved controller retained its foreign research link")
	TEST_ASSERT_NULL(unlinked.nanites.linked_techweb, "A new backup retained foreign research after movement (server moved: [move_server])")
	controller.ui_data()
	TEST_ASSERT_EQUAL(controller.get_backup(backup_id), original, "Research separation discarded an existing cloud backup")
	TEST_ASSERT(program in original.nanites.programs, "Research separation erased an existing cloud program")
	qdel(controller)
