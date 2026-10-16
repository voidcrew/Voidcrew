/// Revoking an experiment link must cancel pending physical callbacks and rewards.
/datum/unit_test/voidcrew_relay_experiment_lifecycle
	parent_type = /datum/unit_test/voidcrew_experiment_reward_fixture

/datum/unit_test/voidcrew_relay_experiment_lifecycle/Run()
	make_reward_ship(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk)
	server.attacked_by(disk, user)
	var/points_before = disk.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC]
	var/obj/item/experi_scanner/scanner = allocate(/obj/item/experi_scanner)
	var/datum/component/experiment_handler/handler = scanner.GetComponent(/datum/component/experiment_handler)
	TEST_ASSERT_NOTNULL(handler, "Scanner has no experiment handler")
	var/datum/experiment/physical/arcade_winner/experiment = allocate(/datum/experiment/physical/arcade_winner)
	disk.stored_research.available_experiments |= experiment
	handler.link_techweb(disk.stored_research, TRUE)
	handler.link_experiment(experiment)
	var/obj/machinery/computer/arcade/arcade = allocate(/obj/machinery/computer/arcade)
	TEST_ASSERT(handler.action_experiment(null, arcade), "Physical experiment did not register its callback")
	handler.unlink_techweb()
	TEST_ASSERT_NULL(experiment.linked_experiment_handler, "Revocation retained the physical handler")
	TEST_ASSERT_NULL(experiment.currently_scanned_atom, "Revocation retained the tracked object")
	SEND_SIGNAL(arcade, COMSIG_ARCADE_PRIZEVEND)
	TEST_ASSERT(!experiment.completed, "A revoked callback completed research")
	TEST_ASSERT_EQUAL(disk.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC], points_before, "A revoked callback awarded points")
	handler.link_techweb(disk.stored_research, TRUE)
	TEST_ASSERT(!experiment.finish_experiment(handler), "Relinking revived an unselected physical callback")
	handler.link_experiment(experiment)
	TEST_ASSERT(handler.action_experiment(null, arcade), "A fresh selection could not restart the experiment")
	SEND_SIGNAL(arcade, COMSIG_ARCADE_PRIZEVEND)
	TEST_ASSERT(experiment.completed, "An authorized physical callback did not complete")
	var/reward = disk.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC]
	TEST_ASSERT(reward > 0, "Completed physical experiment did not award points")
	SEND_SIGNAL(arcade, COMSIG_ARCADE_PRIZEVEND)
	TEST_ASSERT(!experiment.finish_experiment(handler), "Completed physical experiment accepted a duplicate callback")
	TEST_ASSERT_EQUAL(disk.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC], reward, "Duplicate completion paid points twice")
	var/datum/experiment/physical/meat_wall_explosion/wall_experiment = allocate(/datum/experiment/physical/meat_wall_explosion)
	TEST_ASSERT(!wall_experiment.finish_experiment(handler), "An unauthorized physical completion performed its world effects")

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

/// A removable server drive must unlink the exofab without losing its paid work.
/datum/unit_test/voidcrew_exofab_disk_lifecycle/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk)
	server.attacked_by(disk, user)
	var/datum/techweb/web = disk.stored_research
	web.add_design_by_id("basic_cell")
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(/obj/machinery/mecha_part_fabricator)
	fabricator.drop_direction = 0
	fabricator.rmat.set_local_size(1000 * SHEET_MATERIAL_AMOUNT)
	tool.buffer = web
	fabricator.multitool_act(user, tool)
	var/datum/design/design = SSresearch.techweb_design_by_id("basic_cell")
	TEST_ASSERT(design in fabricator.cached_designs, "The installed disk did not provide its cell design")
	for(var/material in design.materials)
		fabricator.rmat.mat_container.insert_amount_mat(10000, material)
	TEST_ASSERT(fabricator.build_part(design, FALSE), "The exofab could not start a paid physical job")
	var/list/paid_materials = fabricator.being_built_materials.Copy()
	disk.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(fabricator.stored_research, "Removing the physical disk left the exofab connected")
	TEST_ASSERT_EQUAL(length(fabricator.cached_designs), 0, "A disconnected exofab retained the disk's designs")
	TEST_ASSERT(!(fabricator in web.connected_machines), "A disconnected exofab retained its consumer registration")
	TEST_ASSERT_EQUAL(fabricator.being_built, design, "Removing the disk discarded an already-paid job")
	TEST_ASSERT_EQUAL(json_encode(fabricator.being_built_materials), json_encode(paid_materials), "Removing the disk changed the job's captured payment")
	TEST_ASSERT(fabricator.dispense_built_part(design), "Removing the disk prevented an already-paid job from completing")
	var/obj/item/stock_parts/power_store/cell/empty/product = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(product, "The paid job did not produce a physical cell")
	var/datum/tgui/ui = allocate(/datum/tgui, user, fabricator, "ExosuitFabricator")
	fabricator.ui_act("build", list("designs" = list("basic_cell")), ui)
	TEST_ASSERT_EQUAL(length(fabricator.queue), 0, "An unlinked exofab accepted a stale build request")
	server.attacked_by(disk, user)
	fabricator.connect_techweb(web)
	fabricator.connect_techweb(web)
	TEST_ASSERT_EQUAL(length(web.connected_machines), 1, "Repeated exofab linking created duplicate consumer registrations")
	qdel(server)
	TEST_ASSERT_NULL(fabricator.stored_research, "Destroying the server left the exofab connected")
	TEST_ASSERT_EQUAL(disk.stored_research, web, "Destroying the server erased its surviving physical disk")

/// A newly built exofab must support inspection and maintenance before receiving a disk link.
/datum/unit_test/voidcrew_exofab_unlinked/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(/obj/machinery/mecha_part_fabricator)
	TEST_ASSERT(fabricator.multitool_act(user, tool), "The unlinked exofab did not handle an empty multitool")
	fabricator.update_menu_tech()
	TEST_ASSERT_NULL(fabricator.stored_research, "An empty buffer invented a research link")
	TEST_ASSERT_EQUAL(length(fabricator.cached_designs), 0, "The unlinked exofab invented researched designs")
	var/datum/design/local_design = SSresearch.techweb_design_by_id("basic_cell")
	fabricator.illegal_local_designs |= local_design
	fabricator.update_menu_tech()
	TEST_ASSERT(local_design in fabricator.cached_designs, "Disconnecting research erased an independent local design")
	var/datum/tgui/ui = allocate(/datum/tgui, user, fabricator, "ExosuitFabricator")
	fabricator.ui_act("build", list("designs" = list("basic_cell")), ui)
	TEST_ASSERT_EQUAL(length(fabricator.queue), 1, "The unlinked exofab rejected its own local design")

/// A foreign-site rejection must leave the existing links usable and report failure.
/datum/unit_test/voidcrew_fabricator_refused_link/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk)
	server.attacked_by(disk, user)
	var/datum/techweb/local_web = disk.stored_research
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(/obj/machinery/mecha_part_fabricator)
	var/obj/machinery/component_printer/printer = allocate(/obj/machinery/component_printer)
	fabricator.connect_techweb(local_web)
	printer.connect_techweb(local_web)
	var/turf/remote_turf
	for(var/level in 1 to world.maxz)
		var/turf/candidate = locate(1, 1, level)
		if(!same_service_site(fabricator, candidate))
			remote_turf = candidate
			break
	TEST_ASSERT_NOTNULL(remote_turf, "No separate site exists for the refused-link regression")
	var/obj/machinery/rnd/server/ship/remote_server = allocate(/obj/machinery/rnd/server/ship, remote_turf)
	var/obj/item/computer_disk/ship_disk/remote_disk = allocate(/obj/item/computer_disk/ship_disk)
	remote_server.attacked_by(remote_disk, user)
	tool.buffer = remote_disk.stored_research
	TEST_ASSERT(!fabricator.multitool_act(user, tool), "The exofab reported a successful foreign-site link")
	TEST_ASSERT(!printer.multitool_act(user, tool), "The component printer reported a successful foreign-site link")
	TEST_ASSERT_EQUAL(fabricator.stored_research, local_web, "Refusing a foreign disk replaced the exofab's local link")
	TEST_ASSERT_EQUAL(printer.techweb, local_web, "Refusing a foreign disk replaced the printer's local link")
	local_web.remove_design_by_id("comp_arithmetic")
	local_web.add_design_by_id("comp_arithmetic")
	TEST_ASSERT_EQUAL(printer.current_unlocked_designs[/obj/item/circuit_component/arithmetic], "comp_arithmetic", "The refusal stopped local component design updates")
	local_web.remove_design_by_id("basic_cell")
	sleep(2.1 SECONDS)
	var/datum/design/cell_design = SSresearch.techweb_design_by_id("basic_cell")
	TEST_ASSERT(!(cell_design in fabricator.cached_designs), "The refusal stopped local exofab design removal updates")
	local_web.add_design_by_id("basic_cell")
	sleep(2.1 SECONDS)
	TEST_ASSERT(cell_design in fabricator.cached_designs, "The refusal stopped local exofab design addition updates")
	remote_server.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(fabricator.multitool_act(user, tool), "The exofab refused the replacement disk after it joined this site")
	TEST_ASSERT_EQUAL(fabricator.stored_research, remote_disk.stored_research, "A valid relink did not use the replacement disk")
	disk.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(fabricator.stored_research, remote_disk.stored_research, "Removing an old disk disconnected the exofab's replacement link")
	TEST_ASSERT_NULL(printer.techweb, "Disk removal left the component printer linked")
	TEST_ASSERT_EQUAL(length(printer.current_unlocked_designs), 0, "Disk removal retained component designs")
	remote_disk.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(fabricator.stored_research, "Removing the current disk retained the exofab's link")

/// One-tile ships exercise real service-site ownership without loading a fleet of maps.
/datum/unit_test/voidcrew_experiment_reward_fixture
	parent_type = /datum/unit_test/voidcrew_outpost_management
	abstract_type = /datum/unit_test/voidcrew_experiment_reward_fixture
	var/list/reward_ports = list()
	var/list/reward_areas = list()

/datum/unit_test/voidcrew_experiment_reward_fixture/Destroy()
	for(var/obj/docking_port/mobile/voidcrew/port in reward_ports)
		if(port.current_ship)
			port.current_ship.shuttle = null
		port.current_ship = null
		port.shuttle_areas = list()
		qdel(port, force = TRUE)
	for(var/turf/tile as anything in reward_areas)
		var/area/shuttle/voidcrew/room = get_area(tile)
		tile.change_area(room, reward_areas[tile])
		room.shuttle_port = null
		qdel(room)
	return ..()

/datum/unit_test/voidcrew_experiment_reward_fixture/proc/make_reward_ship(turf/tile)
	var/area/shuttle/voidcrew/room = new
	reward_areas[tile] = get_area(tile)
	tile.change_area(get_area(tile), room)
	var/obj/docking_port/mobile/voidcrew/port = new(tile)
	reward_ports += port
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.shuttle_areas = list((room) = TRUE)
	room.shuttle_port = port
	port.register()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	SSovermap.simulated_ships |= ship
	ship.shuttle = port
	port.current_ship = ship
	ship.state = "idle"
	ship.ship_team = new /datum/team/voidcrew
	ship.ship_team.ship = ship
	return ship

/datum/unit_test/voidcrew_experiment_reward_fixture/proc/install_reward_disk(obj/machinery/rnd/server/ship/server, mob/living/user)
	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk)
	server.attacked_by(disk, user)
	return disk.stored_research

/// A real physical callback, including an intrinsic reward in addition to the flat 200.
/datum/unit_test/voidcrew_experiment_reward_fixture/proc/complete_arcade(datum/techweb/web, turf/tile)
	var/obj/item/experi_scanner/scanner = allocate(/obj/item/experi_scanner, tile)
	var/datum/component/experiment_handler/handler = scanner.GetComponent(/datum/component/experiment_handler)
	var/datum/experiment/physical/arcade_winner/experiment = allocate(/datum/experiment/physical/arcade_winner)
	experiment.points_reward = list(TECHWEB_POINT_TYPE_GENERIC = 37)
	web.available_experiments |= experiment
	handler.link_techweb(web, TRUE)
	handler.link_experiment(experiment)
	var/obj/machinery/computer/arcade/arcade = allocate(/obj/machinery/computer/arcade, tile)
	TEST_ASSERT(handler.action_experiment(null, arcade), "Physical reward fixture could not register its callback")
	SEND_SIGNAL(arcade, COMSIG_ARCADE_PRIZEVEND)
	TEST_ASSERT(experiment.completed && web.completed_experiments[experiment.type] == experiment, "Physical completion was not restored on this disk")
	TEST_ASSERT(!experiment.finish_experiment(handler), "A duplicate physical callback was accepted")

/// Publish through the ordnance route, which bypasses experiment.finish_experiment().
/datum/unit_test/voidcrew_experiment_reward_fixture/proc/publish_reward_paper(datum/techweb/web)
	var/experiment_type = /datum/experiment/ordnance/explosive/lowyieldbomb
	web.add_experiment(experiment_type)
	for(var/datum/experiment/experiment as anything in web.available_experiments)
		if(experiment.type == experiment_type)
			experiment.points_reward = list(TECHWEB_POINT_TYPE_GENERIC = 37)
	var/datum/scientific_paper/paper = allocate(/datum/scientific_paper)
	paper.experiment_path = experiment_type
	paper.tier = 1
	paper.partner_path = /datum/scientific_partner/mining
	paper.gains = list(1, 1)
	TEST_ASSERT(web.add_scientific_paper(paper), "The ordnance reward fixture could not publish")
	TEST_ASSERT_NOTNULL(web.completed_experiments[experiment_type], "Publication did not restore experiment completion")
	var/points = web.research_points[TECHWEB_POINT_TYPE_GENERIC]
	paper.tier = 2
	TEST_ASSERT(web.add_scientific_paper(paper), "A later publication tier was refused")
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], points, "A later paper tier paid another completion reward")

/datum/unit_test/voidcrew_experiment_reward_fixture/crew_entitlement/Run()
	var/obj/structure/overmap/ship/first_ship = make_reward_ship(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/datum/techweb/web = install_reward_disk(server, user)
	TEST_ASSERT_EQUAL(web.experiment_reward_ledger(), first_ship.ship_team.research_reward_ledger, "The physical source did not resolve its crew's ledger")
	complete_arcade(web, get_turf(server))
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 237, "Physical completion did not pay the flat and intrinsic rewards once")
	publish_reward_paper(web)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 474, "Ordnance and physical reward routes disagree")
	server.source_code_hdd.forceMove(run_loc_floor_bottom_left)
	web = install_reward_disk(server, user)
	complete_arcade(web, get_turf(server))
	publish_reward_paper(web)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0, 0, "A fresh source disk repaid the same crew")
	// A simultaneous second server and a later replacement both use the same entitlement.
	var/obj/machinery/rnd/server/ship/second = allocate(/obj/machinery/rnd/server/ship)
	web = install_reward_disk(second, user)
	complete_arcade(web, get_turf(second))
	publish_reward_paper(web)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0, 0, "A second server multiplied one crew's rewards")
	qdel(server)
	qdel(second)
	server = allocate(/obj/machinery/rnd/server/ship)
	web = install_reward_disk(server, user)
	complete_arcade(web, get_turf(server))
	publish_reward_paper(web)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0, 0, "Replacing the physical servers reset entitlement")
	var/obj/structure/overmap/ship/other_ship = make_reward_ship(run_loc_floor_top_right)
	TEST_ASSERT(other_ship.ship_team.research_reward_ledger != first_ship.ship_team.research_reward_ledger, "Separate crews share one ledger")
	server = allocate(/obj/machinery/rnd/server/ship, run_loc_floor_top_right)
	web = install_reward_disk(server, user)
	complete_arcade(web, get_turf(server))
	publish_reward_paper(web)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 474, "A separate crew could not earn its own experiment rewards")

/datum/unit_test/voidcrew_experiment_reward_fixture/relay_entitlement/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "researchledgerowner"
	TEST_ASSERT(home.load_level(), "The reward-ledger outpost could not load")
	var/mob/living/carbon/human/owner = make_player(home.arrival_turf, home.founder_ckey)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship, home.arrival_turf)
	server.set_machine_stat(NONE)
	var/datum/techweb/web = install_reward_disk(server, owner)
	TEST_ASSERT_EQUAL(web.experiment_reward_ledger(), home.research_reward_ledger, "Outpost research did not resolve its site ledger")
	for(var/turf/tile as anything in list(run_loc_floor_bottom_left, run_loc_floor_top_right))
		var/obj/structure/overmap/ship/ship = make_reward_ship(tile)
		ship.docked = home
		var/mob/living/carbon/human/crew = make_player(tile, "researchrelay[tile.x][tile.y]")
		ship.ship_team.add_member(crew.mind)
		var/obj/machinery/rnd/server/relay/relay = allocate(/obj/machinery/rnd/server/relay, tile)
		relay.set_machine_stat(NONE)
		var/datum/outpost_research_link/link = home.propose_research_link(owner, server, ship, server.source_code_hdd)
		TEST_ASSERT_NOTNULL(link, "The reward fixture could not propose a relay")
		TEST_ASSERT(link.approve(crew, relay), "The reward fixture could not approve a relay")
		TEST_ASSERT_EQUAL(relay.stored_research.experiment_reward_ledger(), home.research_reward_ledger, "A relay used the consuming crew's ledger")
		TEST_ASSERT_EQUAL(length(ship.ship_team.research_reward_ledger), 0, "Sharing outpost research consumed the visitor's entitlement")
	complete_arcade(web, run_loc_floor_bottom_left)
	publish_reward_paper(web)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 474, "Relay-backed research did not award exactly once to the source site")
	var/obj/item/experi_scanner/other_scanner = allocate(/obj/item/experi_scanner, run_loc_floor_top_right)
	var/datum/component/experiment_handler/other_handler = other_scanner.GetComponent(/datum/component/experiment_handler)
	other_handler.link_techweb(web, TRUE)
	var/datum/experiment/completed = web.completed_experiments[/datum/experiment/physical/arcade_winner]
	TEST_ASSERT(!other_handler.can_select_experiment(completed), "A second relay could select already-completed work")
	TEST_ASSERT(!completed.finish_experiment(other_handler), "A second relay accepted a stale completion")
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 474, "A second relay multiplied the source reward")
	// Repeat on a new disk and server at the site, then expose it through both relays again.
	qdel(server)
	server = allocate(/obj/machinery/rnd/server/ship, home.arrival_turf)
	server.set_machine_stat(NONE)
	web = install_reward_disk(server, owner)
	for(var/obj/docking_port/mobile/voidcrew/port in reward_ports)
		var/obj/structure/overmap/ship/ship = port.current_ship
		var/datum/mind/member = ship.ship_team.members[1]
		var/obj/machinery/rnd/server/relay/relay = locate() in get_turf(port)
		var/datum/outpost_research_link/link = home.propose_research_link(owner, server, ship, server.source_code_hdd)
		TEST_ASSERT_NOTNULL(link, "The replacement source could not invite an existing relay crew")
		TEST_ASSERT(link.approve(member.current, relay), "An existing relay could not reconnect to the replacement source")
		TEST_ASSERT_EQUAL(relay.stored_research.experiment_reward_ledger(), home.research_reward_ledger, "Reconnecting a relay replaced the site ledger")
		TEST_ASSERT_EQUAL(length(ship.ship_team.research_reward_ledger), 0, "Outpost rewards consumed a visitor crew's entitlement")
	complete_arcade(web, run_loc_floor_top_right)
	publish_reward_paper(web)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0, 0, "Replacing an outpost server reset its shared entitlement")
	// A disk without an installed physical owner has no completion entitlement.
	server.source_code_hdd.forceMove(home.arrival_turf)
	TEST_ASSERT_NULL(web.experiment_reward_ledger(), "A removed source disk retained a reward owner")

/// Synthetic nodes isolate payment accounting while using real purchase, import and completion procs.
/datum/unit_test/voidcrew_experiment_refunds
	var/node_number = 0

/datum/unit_test/voidcrew_experiment_refunds/Destroy()
	SSresearch.point_types -= "receipt_test"
	return ..()

/datum/unit_test/voidcrew_experiment_refunds/proc/refund_node(list/costs, list/discounts)
	var/datum/techweb_node/node = allocate(/datum/techweb_node)
	node.id = "receipt_test_[++node_number]"
	node.research_costs = costs
	node.discount_experiments = discounts
	SSresearch.techweb_nodes[node.id] = node
	return node

/datum/unit_test/voidcrew_experiment_refunds/proc/finish(datum/techweb/web, experiment_type)
	var/datum/experiment/experiment = allocate(experiment_type)
	experiment.completed = TRUE
	web.available_experiments |= experiment
	web.complete_experiment(experiment)
	return experiment

/datum/unit_test/voidcrew_experiment_refunds/Run()
	SSresearch.point_types["receipt_test"] = "Test"
	var/first_type = /datum/experiment/physical/arcade_winner
	var/second_type = /datum/experiment/physical/meat_wall_explosion
	var/datum/techweb/web = allocate(/datum/techweb)
	web.add_point_list(list(TECHWEB_POINT_TYPE_GENERIC = 1000, "receipt_test" = 1000))
	var/datum/techweb_node/node = refund_node(list(TECHWEB_POINT_TYPE_GENERIC = 100, "receipt_test" = 40), list((first_type) = 20, (second_type) = 50))
	var/costs_before = json_encode(node.research_costs)
	web.boost_techweb_node(node, list(TECHWEB_POINT_TYPE_GENERIC = 70, "receipt_test" = 10))
	TEST_ASSERT(web.research_node(node, FALSE, TRUE, FALSE), "The boosted paid node could not be researched")
	var/datum/techweb_node/another = refund_node(list(TECHWEB_POINT_TYPE_GENERIC = 80), list((first_type) = 15))
	TEST_ASSERT(web.research_node(another, FALSE, TRUE, FALSE), "A second paid node could not be researched")
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 890, "Boosts did not reduce the actual debit")
	TEST_ASSERT_EQUAL(web.research_points["receipt_test"], 970, "The second point currency was not charged correctly")
	var/datum/techweb/imported = allocate(/datum/techweb)
	web.copy_research_to(imported)
	TEST_ASSERT(imported.researched_nodes[node.id] && imported.researched_nodes[another.id], "The transfer fixture did not import its nodes")
	TEST_ASSERT_EQUAL(length(imported.experiment_payment_receipts), 0, "Research transfer copied another web's payment receipts")
	finish(imported, first_type)
	finish(imported, second_type)
	TEST_ASSERT_EQUAL(imported.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0, 0, "Imported nodes created discount refunds")
	var/datum/experiment/first = finish(web, first_type)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 925, "One experiment did not refund both paid nodes' discounts")
	TEST_ASSERT_EQUAL(web.research_points["receipt_test"], 990, "The discount did not refund its own point currency")
	var/datum/experiment/second = finish(web, second_type)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 935, "Several discounts exceeded the node's remaining actual payment")
	TEST_ASSERT_EQUAL(web.research_points["receipt_test"], 1000, "Refunds exceeded actual payment in the second currency")
	web.complete_experiment(first)
	web.complete_experiment(second)
	// Even restoring completion from scratch must not refill consumed receipts.
	web.completed_experiments -= first_type
	finish(web, first_type)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 935, "Repeated completion refunded a consumed discount")
	TEST_ASSERT_EQUAL(web.research_points["receipt_test"], 1000, "Repeated completion refilled another currency's receipt")
	var/list/price = node.get_price(web)
	TEST_ASSERT_EQUAL(price[TECHWEB_POINT_TYPE_GENERIC], 0, "Discounts and boosts returned a negative price")
	TEST_ASSERT_EQUAL(price["receipt_test"], 0, "Experiment discounts returned a negative price in another currency")
	TEST_ASSERT_EQUAL(json_encode(node.research_costs), costs_before, "Pricing mutated a shared node's base costs")
	price = node.get_price(null)
	price[TECHWEB_POINT_TYPE_GENERIC] = -10
	TEST_ASSERT_EQUAL(json_encode(node.research_costs), costs_before, "Unhosted pricing returned the shared cost list")
	var/datum/techweb/unpaid = allocate(/datum/techweb)
	var/datum/techweb_node/free_node = refund_node(list(TECHWEB_POINT_TYPE_GENERIC = 100), list((first_type) = 50))
	unpaid.boost_techweb_node(free_node, list(TECHWEB_POINT_TYPE_GENERIC = 200))
	TEST_ASSERT(unpaid.research_node(free_node, FALSE, TRUE, FALSE), "The fully boosted free node could not unlock")
	var/datum/techweb_node/starting = refund_node(list(TECHWEB_POINT_TYPE_GENERIC = 100), list((first_type) = 50))
	starting.starting_node = TRUE
	TEST_ASSERT(unpaid.research_node(starting, TRUE, FALSE, FALSE), "The starting-node fixture could not unlock")
	var/datum/techweb_node/failed = refund_node(list(TECHWEB_POINT_TYPE_GENERIC = 100), list((first_type) = 50))
	TEST_ASSERT(!unpaid.research_node(failed, FALSE, TRUE, FALSE), "An unaffordable purchase succeeded")
	TEST_ASSERT_EQUAL(length(unpaid.experiment_payment_receipts), 0, "A free, starting or failed purchase created refund entitlement")
	finish(unpaid, first_type)
	TEST_ASSERT_EQUAL(unpaid.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0, 0, "An unpaid node created a refund")

/// Crew reward claims must not suppress legitimate web-local refunds on replacement disks.
/datum/unit_test/voidcrew_experiment_reward_fixture/refund_after_reward/Run()
	var/obj/structure/overmap/ship/ship = make_reward_ship(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/datum/techweb/web = install_reward_disk(server, user)
	ship.ship_team.research_reward_ledger[/datum/experiment/physical/arcade_winner] = TRUE
	web.add_point_list(list(TECHWEB_POINT_TYPE_GENERIC = 100))
	var/datum/techweb_node/node = allocate(/datum/techweb_node)
	node.id = "rewarded_experiment_refund_test"
	node.research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 100)
	node.discount_experiments = list(/datum/experiment/physical/arcade_winner = 60)
	TEST_ASSERT(web.research_node(node, FALSE, TRUE, FALSE), "An already-rewarded experiment's node could not be paid for")
	complete_arcade(web, get_turf(server))
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 60, "An existing crew reward either suppressed a paid refund or paid the completion bonus again")

/datum/unit_test/voidcrew_research_note_conservation/Run()
	var/obj/item/research_notes/notes = allocate(/obj/item/research_notes, run_loc_floor_bottom_left, 60, "biology")
	TEST_ASSERT(!notes.merge(notes), "A paper merged with itself")
	TEST_ASSERT(!QDELETED(notes) && notes.value == 60, "A self-merge changed or consumed its paper")
	var/obj/item/research_notes/incoming = allocate(/obj/item/research_notes, run_loc_floor_bottom_left, 50, "physics")
	TEST_ASSERT(notes.merge(incoming), "Different-origin papers could not merge")
	TEST_ASSERT(QDELETED(incoming), "Merging retained the incoming paper")
	TEST_ASSERT_EQUAL(notes.value, 110, "A mixed-origin merge created a bonus")
	TEST_ASSERT_EQUAL(notes.icon_state, "paperslip_words", "Merging did not update the paper's appearance")
	incoming = allocate(/obj/item/research_notes, run_loc_floor_bottom_left, 2390, "biology")
	notes.attackby(incoming, null, list(), list())
	TEST_ASSERT(QDELETED(incoming), "The item interaction retained the incoming paper")
	TEST_ASSERT_EQUAL(notes.value, 2500, "The item interaction did not conserve note value")
	TEST_ASSERT_EQUAL(notes.icon_state, "paper_words", "The item interaction did not update appearance")
	notes.attackby(notes, null, list(), list())
	TEST_ASSERT(!QDELETED(notes) && notes.value == 2500, "The item interaction accepted a self-merge")
	incoming = allocate(/obj/item/research_notes, run_loc_floor_bottom_left, 0, "chemistry")
	TEST_ASSERT(notes.merge(incoming), "A zero-value incoming paper could not merge")
	TEST_ASSERT(QDELETED(incoming) && notes.value == 2500, "A zero-value paper changed the total or survived merging")

/// Exercise the real reconstruction after the original ship and crew datum have been deleted.
/datum/unit_test/voidcrew_checkpoints/research_reward_ledger
	destroy_original = TRUE

/datum/unit_test/voidcrew_checkpoints/research_reward_ledger/build_hull(datum/checkpoint_construction/job, obj/structure/overmap/dynamic/player_outpost/registry_test/home, datum/outpost_berth/ship_bay/bay, mob/living/carbon/human/captain, obj/structure/overmap/ship/original, datum/ship_checkpoint_ui/registry_test/panel, datum/ship_checkpoint/snapshot)
	var/list/ledger = snapshot.research_reward_ledger
	TEST_ASSERT_NOTNULL(ledger, "Deleting the original crew lost the checkpoint's ledger")
	TEST_ASSERT_EQUAL(job.research_reward_ledger, ledger, "Reconstruction copied or replaced the saved ledger")
	ledger[/datum/experiment/physical/arcade_winner] = TRUE
	job.fast_forward(1)
	TEST_ASSERT(QDELETED(snapshot), "The checkpoint was not consumed at the first piece")
	TEST_ASSERT_EQUAL(job.research_reward_ledger, ledger, "Consuming the checkpoint lost the ledger")
	ledger[/datum/experiment/ordnance/explosive/lowyieldbomb] = TRUE
	job.fast_forward()
	var/obj/structure/overmap/ship/rebuilt = bay.ship
	TEST_ASSERT_NOTNULL(rebuilt, "The reward-ledger checkpoint did not finish reconstruction")
	TEST_ASSERT_EQUAL(rebuilt.ship_team.research_reward_ledger, ledger, "The rebuilt crew restored an older reward entitlement")
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship, get_turf(rebuilt.shuttle))
	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk)
	server.attacked_by(disk, captain)
	var/datum/techweb/web = disk.stored_research
	TEST_ASSERT_EQUAL(web.experiment_reward_ledger(), ledger, "The reconstructed physical server did not resolve the continued ledger")
	for(var/experiment_type in list(/datum/experiment/physical/arcade_winner, /datum/experiment/ordnance/explosive/lowyieldbomb))
		var/datum/experiment/experiment = allocate(experiment_type)
		experiment.completed = TRUE
		web.available_experiments |= experiment
		web.complete_experiment(experiment)
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0, 0, "Reconstruction repaid a reward claimed after snapshot capture")
	// The inherited checkpoint checks still require the reconstructed hull to contain no added stock.
	qdel(disk)
	qdel(server)
	return captain
