/// Maintenance wiring must not be mistaken for uploading a research link.
/datum/unit_test/voidcrew_rnd_panel_wires/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	var/obj/machinery/rnd/production/protolathe/lathe = allocate(/obj/machinery/rnd/production/protolathe)
	lathe.panel_open = TRUE
	TEST_ASSERT(lathe.multitool_act(user, tool), "An unlinked lathe must permit maintenance wiring")
	TEST_ASSERT_NULL(lathe.stored_research, "Opening wires invented a research link")
	var/datum/techweb/original = allocate(/datum/techweb)
	var/datum/techweb/replacement = allocate(/datum/techweb)
	lathe.panel_open = FALSE
	tool.buffer = original
	lathe.multitool_act(user, tool)
	TEST_ASSERT(lathe in original.connected_machines, "The initial multitool link was not registered")
	lathe.panel_open = TRUE
	tool.buffer = replacement
	lathe.multitool_act(user, tool)
	TEST_ASSERT_EQUAL(lathe.stored_research, original, "Opening wires replaced the research link")
	TEST_ASSERT_EQUAL(length(original.connected_machines), 1, "Opening wires changed the existing consumer registration")
	TEST_ASSERT(!(lathe in replacement.connected_machines), "Opening wires registered an unused buffer")

/// All connection paths must follow the physical disk and remove old design signals.
/datum/unit_test/voidcrew_rnd_disk_lifecycle/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk)
	server.attacked_by(disk, user)
	var/datum/techweb/first_web = disk.stored_research
	var/obj/machinery/rnd/server/ship/replacement = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/computer_disk/ship_disk/new_disk = allocate(/obj/item/computer_disk/ship_disk)
	replacement.attacked_by(new_disk, user)
	var/datum/techweb/new_web = new_disk.stored_research
	var/obj/machinery/rnd/production/protolathe/lathe = allocate(/obj/machinery/rnd/production/protolathe)
	lathe.connect_techweb(first_web)
	lathe.connect_techweb(first_web)
	TEST_ASSERT_EQUAL(length(first_web.connected_machines), 1, "Repeated direct linking must register one consumer")
	lathe.connect_techweb(new_web)
	TEST_ASSERT(!(lathe in first_web.connected_machines), "Relinking retained the old consumer registration")
	TEST_ASSERT(lathe in new_web.connected_machines, "Relinking omitted the replacement registration")
	first_web.remove_design_by_id("cable_coil")
	first_web.add_design_by_id("cable_coil")
	TEST_ASSERT(!lathe.techweb_updating, "The old disk still sent design updates to a relinked lathe")
	var/turf/remote_turf
	for(var/level in 1 to world.maxz)
		var/turf/candidate = locate(1, 1, level)
		if(!same_service_site(lathe, candidate))
			remote_turf = candidate
			break
	TEST_ASSERT_NOTNULL(remote_turf, "No separate physical site exists for the rejected-link regression")
	server.forceMove(remote_turf)
	lathe.connect_techweb(first_web)
	TEST_ASSERT_EQUAL(lathe.stored_research, new_web, "A rejected remote link replaced the current local disk")
	new_web.remove_design_by_id("cable_coil")
	new_web.add_design_by_id("cable_coil")
	TEST_ASSERT(lathe.techweb_updating, "A rejected remote link stopped the current disk's design updates")
	lathe.update_designs()
	TEST_ASSERT(length(lathe.cached_designs), "The current physical disk did not supply any designs")
	new_disk.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(lathe.stored_research, "Removing the physical disk left a direct-linked lathe connected")
	TEST_ASSERT_EQUAL(length(lathe.cached_designs), 0, "Removing the physical disk retained cached fabrication designs")
	TEST_ASSERT(!(lathe in new_web.connected_machines), "A detached lathe remained registered to its old disk")
	var/datum/tgui/ui = allocate(/datum/tgui, user, lathe, "Fabricator")
	TEST_ASSERT(lathe.ui_act("build", list("ref" = "cable_coil", "amount" = "1"), ui), "A stale print request after disk removal was not safely consumed")
	TEST_ASSERT(!lathe.busy, "An unlinked lathe started a stale print request")
