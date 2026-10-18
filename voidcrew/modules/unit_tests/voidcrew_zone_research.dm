/// Fork defines follow test includes: permissions 0/1/2/3 are Public/Yellow/Advanced/Elite.
/datum/unit_test/voidcrew_zone_research
	parent_type = /datum/unit_test/voidcrew_experiment_reward_fixture
	abstract_type = /datum/unit_test/voidcrew_zone_research
	var/list/zone_records = list()

/datum/unit_test/voidcrew_zone_research/Destroy()
	QDEL_LIST(zone_records)
	return ..()

/datum/unit_test/voidcrew_zone_research/proc/zone_ship(turf/tile)
	var/obj/structure/overmap/ship/ship = make_reward_ship(tile)
	zone_records |= ship.get_crew_record()
	return ship

/// Use production capped awards rather than replacing the permission lookup.
/datum/unit_test/voidcrew_zone_research/proc/grant_permission(datum/voidcrew_crew_record/record, permission)
	for(var/band in 1 to permission)
		for(var/family in list("named_kill", "hunt", "capture"))
			record.claim_zone_work(family, band, band, "research_[band]_[family]")

/datum/unit_test/voidcrew_zone_research/proc/prepare_node(datum/techweb/web, datum/techweb_node/node)
	for(var/prereq in node.prereq_ids)
		web.research_node_id(prereq, TRUE, FALSE, FALSE)
	web.unhide_node(node)
	web.add_points_all(100000)

/// Check the entire tree, including public industrial/medical nodes and nanite siblings.
/datum/unit_test/voidcrew_zone_research/tags/Run()
	var/list/expected = list(
		/datum/techweb_node/automatic_ammunition = 1,
		/datum/techweb_node/weapon_ammo_c20r = 1,
		/datum/techweb_node/weapon_ammo_wt550 = 1,
		/datum/techweb_node/weapon_ammo_l6_saw = 2,
		/datum/techweb_node/weapon_ammo_bulldog = 2,
		/datum/techweb_node/weapon_ammo_sniper_rifle = 2,
		/datum/techweb_node/specialist_ammo = 1,
		/datum/techweb_node/experimental_ammo = 2,
		/datum/techweb_node/explosive_ammo = 2,
		/datum/techweb_node/nanite_combat = 3,
	)
	var/gated = 0
	for(var/node_id in SSresearch.techweb_nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id]
		TEST_ASSERT_EQUAL(node.zone_permission, expected[node.type] || 0, "Unexpected standing requirement on [node_id]")
		if(node.zone_permission)
			gated++
	TEST_ASSERT_EQUAL(gated, 10, "The direct-research gate must cover exactly ten nodes")
	TEST_ASSERT_EQUAL(SSresearch.techweb_node_by_id("nanite_military").type, /datum/techweb_node/nanite_combat, "Military nanites changed id")

/datum/unit_test/voidcrew_zone_research/direct/Run()
	var/obj/structure/overmap/ship/ship = zone_ship(run_loc_floor_bottom_left)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	var/mob/living/carbon/human/user = make_player(run_loc_floor_bottom_left, "zoneresearchdirect")
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/list/node_ids = list("specialist_ammo", "experimental_ammo", "nanite_military")
	for(var/permission in 1 to 3)
		server.source_code_hdd?.forceMove(run_loc_floor_bottom_left)
		var/datum/techweb/web = install_reward_disk(server, user)
		var/datum/techweb_node/node = SSresearch.techweb_node_by_id(node_ids[permission])
		prepare_node(web, node)
		var/before = web.research_points[TECHWEB_POINT_TYPE_GENERIC]
		TEST_ASSERT_EQUAL(web.get_research_zone_permission(), permission - 1, "Source standing did not resolve its ship")
		TEST_ASSERT(!web.can_unlock_node(node), "An underqualified crew can unlock [node.id]")
		TEST_ASSERT(!web.enqueue_node(node.id, user), "An underqualified crew queued [node.id]")
		TEST_ASSERT(!length(web.research_queue_nodes), "Denied enqueue changed the queue")
		TEST_ASSERT(!web.research_node(node, FALSE, TRUE, FALSE), "Direct research bypassed standing for [node.id]")
		TEST_ASSERT(!web.research_node(node, FALSE, FALSE, FALSE), "Skipping point adjustment bypassed standing")
		TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], before, "Denied research spent points")
		TEST_ASSERT(!web.researched_nodes[node.id], "Denied research acquired knowledge")
		TEST_ASSERT(!length(web.experiment_payment_receipts), "Denied research created a refund receipt")
		grant_permission(record, permission)
		TEST_ASSERT(web.can_unlock_node(node), "New standing did not permit [node.id]")
		TEST_ASSERT(web.enqueue_node(node.id, user), "New standing did not permit queueing")
		var/cost = node.get_price(web)[TECHWEB_POINT_TYPE_GENERIC]
		// SSresearch.fire() executes the first queued id through this same entry point.
		TEST_ASSERT(web.research_node_id(web.research_queue_nodes[1], FALSE, TRUE, FALSE), "Eligible queued research failed")
		TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], before - cost, "Eligible queued research charged the wrong amount")
		TEST_ASSERT(web.researched_nodes[node.id], "Eligible queued research did not unlock the node")
		TEST_ASSERT(!length(web.research_queue_nodes), "Successful research remained queued")

/// A queued request retains knowledge only if it succeeds against the live source crew.
/datum/unit_test/voidcrew_zone_research/queue_recheck/Run()
	var/obj/structure/overmap/ship/ship = zone_ship(run_loc_floor_bottom_left)
	var/datum/voidcrew_crew_record/qualified = ship.get_crew_record()
	grant_permission(qualified, 1)
	var/datum/voidcrew_crew_record/public_crew = allocate(/datum/voidcrew_crew_record)
	var/mob/living/carbon/human/user = make_player(run_loc_floor_bottom_left, "zoneresearchqueue")
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/datum/techweb/web = install_reward_disk(server, user)
	var/datum/techweb_node/node = SSresearch.techweb_node_by_id("specialist_ammo")
	prepare_node(web, node)
	TEST_ASSERT(web.enqueue_node(node.id, user), "Qualified source could not queue research")
	ship.ship_team.set_crew_record(public_crew)
	var/before = web.research_points[TECHWEB_POINT_TYPE_GENERIC]
	TEST_ASSERT(!web.research_node_id(web.research_queue_nodes[1], FALSE, TRUE, FALSE), "Queue execution used stale standing")
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], before, "Denied queue execution debited points")
	TEST_ASSERT(node.id in web.research_queue_nodes, "Denied execution discarded the accepted queue entry")
	// Free-node processing in SSresearch must not bypass the same gate.
	web.boost_techweb_node(node, node.research_costs.Copy())
	TEST_ASSERT(node.is_free(web), "The free-queue fixture is not free")
	TEST_ASSERT(!web.research_node(node), "A free queued node bypassed live standing")
	ship.ship_team.set_crew_record(qualified)
	TEST_ASSERT(web.research_node_id(web.research_queue_nodes[1], FALSE, TRUE, FALSE), "Restored standing did not resume queued work")
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], before, "A free qualified node consumed points")

/// Standing supplements the existing point, experiment and survey checks.
/datum/unit_test/voidcrew_zone_research/other_requirements/Run()
	var/obj/structure/overmap/ship/ship = zone_ship(run_loc_floor_bottom_left)
	grant_permission(ship.get_crew_record(), 3)
	var/mob/living/carbon/human/user = make_player(run_loc_floor_bottom_left, "zoneresearchrequirements")
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/datum/techweb/web = install_reward_disk(server, user)
	var/datum/techweb_node/node = allocate(/datum/techweb_node)
	node.id = "zone_research_requirements"
	node.zone_permission = 1
	node.research_costs = list(TECHWEB_POINT_TYPE_GENERIC = 100)
	node.required_experiments = list(/datum/experiment/physical/arcade_winner)
	node.required_surveyed_objects = list("planets" = 1)
	SSresearch.techweb_nodes[node.id] = node
	web.unhide_node(node)
	web.add_points_all(100)
	TEST_ASSERT(!web.can_unlock_node(node), "Standing replaced experiment/survey requirements")
	TEST_ASSERT(!web.research_node(node, FALSE, TRUE, FALSE), "Direct research ignored missing requirements")
	var/datum/experiment/experiment = allocate(/datum/experiment/physical/arcade_winner)
	web.completed_experiments[experiment.type] = experiment
	TEST_ASSERT(!web.can_unlock_node(node), "A missing survey was accepted")
	TEST_ASSERT(!web.research_node(node, FALSE, TRUE, FALSE), "Direct research ignored a missing survey")
	web.survey_data = allocate(/datum/survey_research)
	web.survey_data.survey_objects_by_type["planets"] = list(allocate(/datum/surveyed_celestial_object/planet))
	web.completed_experiments.Cut()
	TEST_ASSERT(!web.research_node(node, FALSE, TRUE, FALSE), "A surveyed node ignored its experiment")
	web.completed_experiments[experiment.type] = experiment
	web.remove_points_all(100)
	TEST_ASSERT(!web.can_unlock_node(node), "Standing replaced the point requirement")
	TEST_ASSERT(!web.research_node(node, FALSE, TRUE, FALSE), "Direct research ignored missing points")
	web.add_points_all(100)
	TEST_ASSERT(web.can_unlock_node(node), "All requirements met but research is still locked")
	TEST_ASSERT(web.research_node(node, FALSE, TRUE, FALSE), "Research with every requirement met failed")
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], 0, "Research did not charge its actual cost")

/// Missing source context is Public; public science continues to work without standing.
/datum/unit_test/voidcrew_zone_research/public_science/Run()
	var/datum/techweb/web = allocate(/datum/techweb)
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 0, "An uninstalled web has standing")
	var/list/public_types = list(/datum/techweb_node/parts_upg, /datum/techweb_node/parts_adv, /datum/techweb_node/chem_synthesis, /datum/techweb_node/medbay_equip_adv)
	for(var/datum/techweb_node/node_type as anything in public_types)
		var/datum/techweb_node/node = SSresearch.techweb_node_by_id(initial(node_type.id))
		TEST_ASSERT_NOTEQUAL(node, SSresearch.error_node, "Missing public science node [node_type]")
		prepare_node(web, node)
		for(var/experiment_type in node.required_experiments)
			web.completed_experiments[experiment_type] = allocate(experiment_type)
		TEST_ASSERT(web.can_unlock_node(node), "Public science acquired a standing gate: [node.id]")
		TEST_ASSERT(web.research_node(node, FALSE, TRUE, FALSE), "Public industrial/medical research failed: [node.id]")
	var/datum/techweb_node/gated = SSresearch.techweb_node_by_id("specialist_ammo")
	prepare_node(web, gated)
	TEST_ASSERT(!web.research_node(gated, FALSE, TRUE, FALSE), "An uninstalled web bypassed the gate")

/// Positive acceptance: imported nodes and individual designs can be used by a Public crew.
/datum/unit_test/voidcrew_zone_research/imports/Run()
	zone_ship(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = make_player(run_loc_floor_bottom_left, "zoneresearchimports")
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/datum/techweb/receiver = install_reward_disk(server, user)
	var/datum/techweb/donor = allocate(/datum/techweb)
	var/list/node_ids = list("specialist_ammo", "experimental_ammo", "nanite_military")
	for(var/node_id in node_ids)
		TEST_ASSERT(donor.research_node_id(node_id, TRUE, FALSE, FALSE), "Forced import was denied at Public standing")
	var/before = receiver.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0
	donor.copy_research_to(receiver)
	for(var/node_id in node_ids)
		TEST_ASSERT(receiver.isNodeResearchedID(node_id), "Copying research lost imported knowledge: [node_id]")
		var/datum/techweb_node/node = SSresearch.techweb_node_by_id(node_id)
		for(var/design_id in node.design_ids)
			TEST_ASSERT(receiver.isDesignResearchedID(design_id), "Imported node lost an acquired design: [design_id]")
	TEST_ASSERT_EQUAL(receiver.get_research_zone_permission(), 0, "Importing knowledge granted standing")
	TEST_ASSERT_EQUAL(receiver.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0, before, "Forced imports charged points")
	TEST_ASSERT(!length(receiver.experiment_payment_receipts), "Imports created paid-discount receipts")
	var/datum/design/design = SSresearch.techweb_design_by_id("vc_ammo_m9mm_ap")
	TEST_ASSERT(receiver.isDesignResearched(design), "Imported ammunition is unusable")
	var/datum/techweb/design_receiver = allocate(/datum/techweb)
	TEST_ASSERT(design_receiver.add_design(design, TRUE), "Public standing rejected a design copy")
	TEST_ASSERT(design_receiver.isDesignResearched(design), "Copied design is unusable")
	var/obj/machinery/rnd/production/protolathe/launch_fabrication_test/lathe = allocate(/obj/machinery/rnd/production/protolathe/launch_fabrication_test)
	lathe.connect_techweb(receiver)
	lathe.update_designs()
	TEST_ASSERT(design in lathe.cached_designs, "Public lathe did not receive imported designs")
	lathe.set_machine_stat(NONE)
	lathe.materials.set_local_size(1000 * SHEET_MATERIAL_AMOUNT)
	var/list/stock_before = list()
	for(var/material in design.materials)
		lathe.materials.mat_container.insert_amount_mat(10000, material)
		stock_before[material] = lathe.materials.mat_container.materials[material]
	lathe.print_test_design(design, 1)
	var/obj/item/product = locate(design.build_path) in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(product, "Public standing blocked fabrication of imported ammunition")
	for(var/material in stock_before)
		TEST_ASSERT(lathe.materials.mat_container.materials[material] < stock_before[material], "Imported ammunition did not consume its materials")
	var/obj/machinery/computer/nanite_cloud_controller/programmer = allocate(/obj/machinery/computer/nanite_cloud_controller)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	tool.buffer = receiver
	programmer.multitool_act(user, tool)
	var/datum/tgui/ui = allocate(/datum/tgui, user, programmer, "NaniteCloudControl")
	programmer.ui_act("download", list("program_id" = "pyro_nanites"), ui)
	var/datum/design/nanites/military_design = SSresearch.techweb_design_by_id("pyro_nanites")
	TEST_ASSERT(istype(programmer.current_program, military_design.program_type), "Public standing blocked use of imported military nanite research")

/// A source disk carries knowledge, while direct research follows its new physical host.
/datum/unit_test/voidcrew_zone_research/disk_move/Run()
	var/obj/structure/overmap/ship/rich_ship = zone_ship(run_loc_floor_bottom_left)
	grant_permission(rich_ship.get_crew_record(), 3)
	zone_ship(run_loc_floor_top_right)
	var/mob/living/carbon/human/user = make_player(run_loc_floor_bottom_left, "zoneresearchmove")
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/datum/techweb/web = install_reward_disk(server, user)
	var/obj/item/computer_disk/ship_disk/disk = server.source_code_hdd
	var/datum/techweb_node/known = SSresearch.techweb_node_by_id("specialist_ammo")
	prepare_node(web, known)
	TEST_ASSERT(web.research_node(known, FALSE, TRUE, FALSE), "Qualified source could not research ammunition")
	disk.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 0, "Removed source disk retained standing")
	var/obj/machinery/rnd/server/ship/replacement = allocate(/obj/machinery/rnd/server/ship, run_loc_floor_top_right)
	replacement.attacked_by(disk, user)
	TEST_ASSERT_EQUAL(replacement.stored_research, web, "Moving the source disk replaced its web")
	TEST_ASSERT(web.isNodeResearched(known), "Moving the source disk erased acquired knowledge")
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 0, "Source disk stored its former host's permission")
	var/datum/techweb_node/next_node = SSresearch.techweb_node_by_id("experimental_ammo")
	prepare_node(web, next_node)
	var/before = web.research_points[TECHWEB_POINT_TYPE_GENERIC]
	TEST_ASSERT(!web.research_node(next_node, FALSE, TRUE, FALSE), "Public replacement inherited direct-research access")
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], before, "Denied moved-disk research spent points")
	// Moving the physical server also changes context without moving or recreating its disk.
	replacement.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 3, "Server movement did not resolve the new physical site")
	TEST_ASSERT(web.research_node(next_node, FALSE, TRUE, FALSE), "Qualified physical source could not resume direct research")
	qdel(replacement)
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 0, "Destroyed physical server retained standing")
	TEST_ASSERT(web.isNodeResearched(next_node), "Server destruction erased the surviving disk's knowledge")

/// Outpost standing follows its current founder's round roster, including offline founders.
/datum/unit_test/voidcrew_zone_research/outpost_and_relay/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "zoneresearchowner"
	TEST_ASSERT(home.load_level(), "The research outpost fixture could not load")
	var/mob/living/carbon/human/owner = make_player(home.arrival_turf, home.founder_ckey)
	home.founder_mind = WEAKREF(owner.mind)
	var/datum/voidcrew_crew_record/source_crew = allocate(/datum/voidcrew_crew_record)
	owner.mind.join_reputation_crew(source_crew)
	grant_permission(source_crew, 3)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship, home.arrival_turf)
	server.set_machine_stat(NONE)
	var/datum/techweb/web = install_reward_disk(server, owner)
	var/obj/structure/overmap/ship/visitor = zone_ship(run_loc_floor_bottom_left)
	visitor.docked = home
	var/mob/living/carbon/human/crew = make_player(run_loc_floor_bottom_left, "zoneresearchvisitor")
	visitor.ship_team.add_member(crew.mind)
	var/obj/machinery/rnd/server/relay/relay = allocate(/obj/machinery/rnd/server/relay)
	relay.set_machine_stat(NONE)
	var/datum/outpost_research_link/link = home.propose_research_link(owner, server, visitor, server.source_code_hdd)
	TEST_ASSERT_NOTNULL(link, "Could not propose the research relay")
	TEST_ASSERT(link.approve(crew, relay), "Could not approve the research relay")
	TEST_ASSERT_EQUAL(relay.stored_research, web, "Relay did not expose the physical source web")
	TEST_ASSERT_EQUAL(visitor.get_crew_record().get_zone_permission(), 0, "Visitor fixture is not Public")
	TEST_ASSERT_EQUAL(relay.stored_research.get_research_zone_permission(), 3, "Relay used the visitor's standing")
	var/datum/techweb_node/node = SSresearch.techweb_node_by_id("specialist_ammo")
	prepare_node(web, node)
	TEST_ASSERT(relay.stored_research.research_node(node, FALSE, TRUE, FALSE), "Public visitor could not use a qualified source's research service")
	var/datum/voidcrew_crew_record/public_crew = allocate(/datum/voidcrew_crew_record)
	owner.mind.join_reputation_crew(public_crew)
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 0, "Outpost retained the founder's former standing")
	TEST_ASSERT(relay.stored_research.isNodeResearched(node), "Founder crew change removed shared acquired knowledge")
	grant_permission(visitor.get_crew_record(), 3)
	var/datum/techweb_node/next_node = SSresearch.techweb_node_by_id("experimental_ammo")
	prepare_node(web, next_node)
	var/before = web.research_points[TECHWEB_POINT_TYPE_GENERIC]
	TEST_ASSERT(!relay.stored_research.research_node(next_node, FALSE, TRUE, FALSE), "A wealthy relay consumer authorized a Public physical source")
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], before, "Denied relay research debited the source")
	owner.mind.join_reputation_crew(source_crew)
	home.founder_mind = null
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 3, "Offline founder lost the round roster's standing")
	owner.mind.leave_reputation_crew()
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 0, "Explicit founder departure retained standing")
	home.founder_ckey = null
	TEST_ASSERT_EQUAL(web.get_research_zone_permission(), 0, "Unowned outpost gained standing")

/datum/unit_test/voidcrew_zone_research/green_resources/Run()
	var/list/expected = list(
		/datum/gas/plasma = 55,
		/datum/gas/nitrogen = 30,
		/datum/gas/water_vapor = 15,
		/datum/gas/miasma = 1,
		/datum/gas/tritium = 1,
		/datum/gas/pluoxium = 1,
		/datum/gas/nitrium = 1,
		/datum/gas/hypernoblium = 1,
	)
	var/list/green = GLOB.nebula_gas_tables_by_band["1"]
	TEST_ASSERT_EQUAL(length(green), length(expected), "Green nebulas do not offer all eight gases")
	for(var/gas_type in expected)
		TEST_ASSERT_EQUAL(green[gas_type], expected[gas_type], "Wrong green nebula weight for [gas_type]")
		TEST_ASSERT(GLOB.nebula_gas_scoop_rates[gas_type] > 0, "A green gas cannot be harvested")
	// Every gas present in any other band must be accessible in green.
	for(var/band in GLOB.nebula_gas_tables_by_band)
		var/list/weights = GLOB.nebula_gas_tables_by_band[band]
		for(var/gas_type in weights)
			TEST_ASSERT(green[gas_type] > 0, "A raw nebula gas remains zone-exclusive")
	var/list/ores = ordinary_ore_weights(1)
	var/list/expected_ores = list(
		/obj/item/stack/ore/iron = 110,
		/obj/item/stack/ore/plasma = 40,
		/obj/item/stack/ore/silver = 16,
		/obj/item/stack/ore/titanium = 16,
		/obj/item/stack/ore/gold = 8,
		/obj/item/stack/ore/uranium = 5,
		/obj/item/stack/ore/diamond = 2,
		/obj/item/stack/ore/bluespace_crystal = 2,
		/obj/item/stack/ore/bananium = 1,
	)
	TEST_ASSERT_EQUAL(length(ores), length(expected_ores), "Green ore coverage changed")
	for(var/ore_type in expected_ores)
		TEST_ASSERT_EQUAL(ores[ore_type], expected_ores[ore_type], "Existing green ore weight changed")
