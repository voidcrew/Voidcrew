/// Claim economy and actual ferry integration, including physical delivery without a ship.
/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home
	var/obj/docking_port/mobile/voidcrew/test_port
	var/area/shuttle/voidcrew/test_ship_area
	var/turf/test_ship_tile
	var/area/test_original_area
	var/datum/shuttle_template_load/test_load_owner
	var/queued_dispatch_finished = FALSE
	var/queued_dispatch_error

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/Destroy()
	if(test_load_owner)
		SSshuttle.release_template_load(test_load_owner)
	if(test_ship_tile && test_original_area)
		test_ship_tile.change_area(get_area(test_ship_tile), test_original_area)
	if(!QDELETED(test_port))
		if(test_port.current_ship)
			test_port.current_ship.shuttle = null
		test_port.current_ship = null
		test_port.shuttle_areas = list()
		qdel(test_port, force = TRUE)
	if(!QDELETED(test_ship_area))
		test_ship_area.shuttle_port = null
		qdel(test_ship_area)
	return ..()

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/Run()
	save_economy()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "outpostfounder"
	TEST_ASSERT(home.load_level(), "Purchased home bundle failed to load")
	TEST_ASSERT(home.home_bundle_installed, "Founding did not install the included services")
	TEST_ASSERT_NOTNULL(home.available_resident_pod(), "Purchased home has no resident arrival point")
	TEST_ASSERT_NOTNULL(home.freight_berth?.panel, "Freight receiver is inaccessible by elevator")
	var/datum/bank_account/account = home.treasury
	account.account_balance = 10000
	home.ensure_home_services()
	TEST_ASSERT_EQUAL(home.treasury, account, "Reconnecting services replaced the claim account")
	TEST_ASSERT_EQUAL(account.account_balance, 10000, "Reconnecting services changed the treasury balance")
	var/obj/machinery/computer/voidcrew_cargo/first = new(home.arrival_turf)
	var/obj/machinery/computer/voidcrew_cargo/second = new(home.arrival_turf)
	TEST_ASSERT_EQUAL(first.cargo_account(), account, "Cargo has no claim treasury")
	TEST_ASSERT_EQUAL(second.cargo_account(), account, "Second console resolved another account")
	TEST_ASSERT_EQUAL(first.checkout_list, second.checkout_list, "Consoles did not share one cart")
	var/datum/supply_pack/pack = allocate(/datum/supply_pack/security/modsuit_plating)
	var/datum/supply_order/order = new(pack)
	order.manifest_can_fail = FALSE
	home.cargo_cart += order
	var/price = order.get_final_cost()
	var/datum/voidcrew_cargo_shuttle/outpost/ferry = home.freight
	// A cancelled order waiting behind another ship must refund once and stay cancelled.
	test_load_owner = SSshuttle.acquire_template_load(1 MINUTES)
	TEST_ASSERT(test_load_owner, "Could not reserve the template queue for the freight cancellation check")
	INVOKE_ASYNC(src, PROC_REF(run_queued_dispatch), ferry)
	TEST_ASSERT(!queued_dispatch_finished && ferry.load_pending && ferry.busy, "The outpost shipment did not wait for the active template load")
	TEST_ASSERT_EQUAL(account.account_balance, 10000 - price, "Queued freight did not reserve its funds")
	ferry.cleanup_shuttle()
	TEST_ASSERT_EQUAL(account.account_balance, 10000, "Cancelling queued freight did not refund its reservation")
	TEST_ASSERT_NULL(order.ship_paid_cost, "Cancelled queued freight retained a paid order")
	TEST_ASSERT_NOTNULL(ferry.call_shuttle(), "Cancelled freight accepted a new dispatch before its previous load returned")
	SSshuttle.release_template_load(test_load_owner)
	test_load_owner = null
	UNTIL(queued_dispatch_finished)
	TEST_ASSERT_NOTNULL(queued_dispatch_error, "Cancelled queued freight reported a successful dispatch")
	TEST_ASSERT(!ferry.busy && !ferry.load_pending, "Cancelled queued freight remained busy")
	TEST_ASSERT_EQUAL(account.account_balance, 10000, "A late queued callback refunded the same order twice")
	TEST_ASSERT(order in home.cargo_cart, "Cancelling queued freight lost its unpaid cart order")
	TEST_ASSERT_NULL(ferry.call_shuttle(), "Outpost freight refused a shipment with no player ship")
	TEST_ASSERT_EQUAL(account.account_balance, 10000 - price, "Freight did not reserve the quoted funds")
	TEST_ASSERT_NOTNULL(ferry.call_shuttle(), "Repeated dispatch started a competing shipment")
	TEST_ASSERT_EQUAL(account.account_balance, 10000 - price, "Repeated dispatch charged twice")
	qdel(first)
	qdel(second)
	TEST_ASSERT_EQUAL(length(home.cargo_cart), 1, "Destroyed consoles lost the paid manifest")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(ferry.complete_arrival(), "Physical freight delivery to the hangar failed")
	TEST_ASSERT_EQUAL(length(home.cargo_cart), 0, "Delivered order remained in the cart")
	var/delivered = 0
	for(var/turf/location as anything in ferry.get_cargo_bay_turfs())
		for(var/obj/structure/closet/crate/crate in location)
			if(crate.manifest)
				delivered++
	TEST_ASSERT_EQUAL(delivered, 1, "Paid order did not produce exactly one accessible crate")
	TEST_ASSERT(!ferry.complete_arrival(), "A repeated arrival settled twice")
	TEST_ASSERT_EQUAL(account.account_balance, 10000 - price, "Arrival charged the reserved amount again")
	var/list/ferry_areas = ferry.shuttle_port.shuttle_areas.Copy()
	var/list/former_ferry_turfs = list()
	for(var/area/ferry_area as anything in ferry_areas)
		for(var/turf/deck in ferry_area)
			former_ferry_turfs += deck
	var/list/underlying_areas = ferry.shuttle_port.underlying_areas_by_turf.Copy()
	TEST_ASSERT(ferry.send_shuttle(), "Delivered freight could not depart without its console")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(ferry.complete_departure(), "Outpost exports could not settle without a console")
	for(var/area/ferry_area as anything in ferry_areas)
		for(var/turf/listed_turf as anything in ferry_area.get_turfs_from_all_zlevels())
			TEST_ASSERT_EQUAL(get_area(listed_turf), ferry_area, "Departed ferry retained another area's turf in its registry")
	for(var/turf/former_deck as anything in former_ferry_turfs)
		var/area/restored_area = get_area(former_deck)
		TEST_ASSERT(!(restored_area in ferry_areas), "Departed ferry kept a berth turf in its area")
		if(underlying_areas[former_deck])
			TEST_ASSERT_EQUAL(restored_area, underlying_areas[former_deck], "Freight teardown replaced the underlying berth area")
		var/registrations = 0
		for(var/turf/listed_turf as anything in restored_area.get_turfs_by_zlevel(former_deck.z))
			if(listed_turf == former_deck)
				registrations++
		TEST_ASSERT_EQUAL(registrations, 1, "A restored berth turf must appear exactly once in its area's registry")
	var/after_export = account.account_balance
	TEST_ASSERT(after_export > 10000 - price, "Exported physical packaging did not credit the claim")
	TEST_ASSERT(!ferry.complete_departure(), "Duplicate export settled twice")
	TEST_ASSERT_EQUAL(account.account_balance, after_export, "Duplicate export changed the balance")
	// Reserve finite market stock and cancel twice: both money and stock restore once.
	SSstock_market.materials_prices[/datum/material/iron] = 5
	SSstock_market.materials_quantity[/datum/material/iron] = 100
	var/datum/supply_pack/custom/minerals/material_pack = new("Outpost", 50, list(/obj/item/stack/sheet/iron = 10))
	var/datum/supply_order/disposable/materials/material_order = new(material_pack)
	home.cargo_cart += material_order
	TEST_ASSERT_NULL(ferry.call_shuttle(), "Materials shipment failed dispatch")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/iron], 90, "Market stock was not reserved")
	ferry.cleanup_shuttle()
	ferry.cleanup_shuttle()
	TEST_ASSERT_EQUAL(account.account_balance, after_export, "Cancelled freight lost or duplicated credits")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/iron], 100, "Cancelled freight lost or duplicated market stock")
	TEST_ASSERT_NULL(material_order.ship_paid_cost, "Cancelled order remained marked paid")
	// A rebuilt console sees the same surviving order and account, with no new stock.
	var/obj/machinery/computer/voidcrew_cargo/replacement = new(home.arrival_turf)
	TEST_ASSERT_EQUAL(replacement.cargo_account(), account, "Replacement terminal replaced treasury")
	TEST_ASSERT(material_order in replacement.checkout_list, "Replacement terminal lost the outstanding order")
	var/pods_before = length(home.resident_pods)
	TEST_ASSERT(home.install_home_bundle(), "Repeated setup failed")
	TEST_ASSERT_EQUAL(length(home.resident_pods), pods_before, "Repeated setup minted another cryopod")

	// Moving or deleting a borrowed terminal must not mutate its previous home's cart.
	replacement.forceMove(run_loc_floor_bottom_left)
	replacement.cargo_account()
	qdel(replacement)
	TEST_ASSERT(material_order in home.cargo_cart, "Moving a console discarded the claim's outstanding order")
	var/obj/machinery/materials_market/market = new(home.arrival_turf)
	TEST_ASSERT_EQUAL(market.market_account(null, FALSE), account, "Shore market did not resolve the claim account")
	TEST_ASSERT_EQUAL(market.get_order_list(), home.cargo_cart, "Shore market filed orders outside the claim cart")
	qdel(market)
	// A receiver that disappears after reservation refunds money and finite stock.
	TEST_ASSERT_NULL(ferry.call_shuttle(), "Retry after cancellation failed")
	deltimer(ferry.warmup_timer)
	var/obj/machinery/outpost_elevator/panel = home.freight_berth.panel
	home.freight_berth.panel = null
	TEST_ASSERT(!ferry.complete_arrival(), "Shipment delivered into a missing receiver")
	home.freight_berth.panel = panel
	TEST_ASSERT_EQUAL(account.account_balance, after_export, "Receiver failure lost reserved funds")
	TEST_ASSERT_EQUAL(SSstock_market.materials_quantity[/datum/material/iron], 100, "Receiver failure lost reserved stock")
	// A physical visiting ship on the claim footprint wins over the home.
	var/turf/ship_tile = home.arrival_turf
	var/area/original_area = get_area(ship_tile)
	var/area/shuttle/voidcrew/ship_area = new
	ship_tile.change_area(original_area, ship_area)
	test_ship_tile = ship_tile
	test_original_area = original_area
	test_ship_area = ship_area
	var/obj/docking_port/mobile/voidcrew/port = new(ship_tile)
	test_port = port
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.shuttle_areas = list()
	port.shuttle_areas[ship_area] = TRUE
	ship_area.shuttle_port = port
	port.shuttle_id = "part1_test_visitor"
	port.register()
	TEST_ASSERT_NULL(get_outpost_from_atom(ship_tile), "A hull under assembly inherited the claim host")
	var/obj/structure/overmap/ship/visitor = allocate(/obj/structure/overmap/ship)
	visitor.shuttle = port
	port.current_ship = visitor
	visitor.docked = home
	visitor.state = "idle" // OVERMAP_SHIP_IDLE (fork defines follow test includes)
	TEST_ASSERT_EQUAL(get_service_site(ship_tile), visitor, "Visiting ship inherited the claim host")
	TEST_ASSERT_NULL(get_outpost_from_atom(ship_tile), "Ship equipment resolved to the outpost")
	var/obj/machinery/cryopod/pod = home.available_resident_pod()
	pod.forceMove(ship_tile)
	TEST_ASSERT_EQUAL(pod.linked_ship, port, "Moved cryopod did not register to its visiting ship")
	TEST_ASSERT(!(pod in home.resident_pods), "Moved cryopod stayed on the home's arrival list")
	var/turf/home_tile = get_step(ship_tile, SOUTH)
	pod.forceMove(home_tile)
	TEST_ASSERT_EQUAL(pod.linked_outpost, home, "Returned cryopod did not regain the same claim registration")
	TEST_ASSERT(!(pod in port.spawn_points), "Returned cryopod stayed registered on the visitor")
	var/mob/living/carbon/human/steward = allocate(/mob/living/carbon/human/consistent)
	steward.mind_initialize()
	var/obj/machinery/rnd/server/ship/local_server = new(home_tile)
	var/obj/machinery/rnd/server/ship/remote_server = new(ship_tile)
	var/obj/item/computer_disk/ship_disk/local_disk = new(home_tile)
	var/obj/item/computer_disk/ship_disk/remote_disk = new(ship_tile)
	local_server.attacked_by(local_disk, steward)
	remote_server.attacked_by(remote_disk, steward)
	local_server.set_machine_stat(0)
	remote_server.set_machine_stat(0)
	TEST_ASSERT(!can_link_site_techweb(run_loc_floor_bottom_left, local_server.stored_research), "Machine outside the claim could link its server")
	TEST_ASSERT(can_link_site_techweb(pod, local_server.stored_research), "Shore lab could not link its own server")
	TEST_ASSERT(!can_link_site_techweb(pod, remote_server.stored_research), "Shore lab could link a visiting ship's server")
	// Manufacture from the physical home's disk and actual silo stock.
	var/obj/machinery/rnd/production/protolathe/lathe = new(home_tile)
	var/obj/item/multitool/tool = allocate(/obj/item/multitool)
	tool.buffer = local_server.stored_research
	TEST_ASSERT(lathe.multitool_act(steward, tool), "Home protolathe could not link its local disk")
	var/datum/design/design = SSresearch.techweb_design_by_id("cable_coil")
	local_server.stored_research.add_design_by_id(design.id)
	lathe.update_designs()
	TEST_ASSERT(design in lathe.cached_designs, "Home fabrication did not receive local designs")
	var/obj/machinery/ore_silo/silo
	for(var/turf/floor in home.outpost_area)
		silo = locate() in floor
		if(silo)
			break
	TEST_ASSERT_NOTNULL(silo, "Purchased home has no physical silo")
	tool.buffer = silo
	home.construction_console.multitool_act(steward, tool)
	TEST_ASSERT_EQUAL(home.construction_console.get_linked_silo(), silo, "Construction could not link its physical home silo")
	lathe.materials.OnMultitool(lathe, steward, tool)
	TEST_ASSERT_EQUAL(lathe.materials.silo, silo, "Protolathe did not connect to actual home stock")
	var/list/stock_before = list()
	for(var/material in design.materials)
		lathe.materials.mat_container.insert_amount_mat(10000, material)
		stock_before[material] = lathe.materials.mat_container.materials[material]
	lathe.set_machine_stat(NONE)
	call(lathe, TYPE_PROC_REF(/obj/machinery/rnd/production, do_make_item))(design, 1, 1, 1, 1, home_tile, ID_DATA(steward))
	var/obj/item/stack/cable_coil/manufactured = locate() in home_tile
	TEST_ASSERT_NOTNULL(manufactured, "Standalone home lab did not produce a physical item")
	for(var/material in stock_before)
		TEST_ASSERT(lathe.materials.mat_container.materials[material] < stock_before[material], "Home fabrication did not consume [material] from its silo")
	lathe.forceMove(ship_tile)
	TEST_ASSERT(!lathe.materials.can_use_resource(), "A fabricator moved onto a visitor could consume the home's silo")
	lathe.forceMove(home_tile)
	TEST_ASSERT(!home.propose_research_pair(steward, local_server, remote_server), "Visitor proposed a pairing without authority")
	home.stewards |= steward.mind
	TEST_ASSERT(home.propose_research_pair(steward, local_server, remote_server), "Authorized home could not request a pairing")
	var/datum/outpost_research_pair/pair = home.research_pairs[1]
	TEST_ASSERT_NOTNULL(pair.unavailable_reason(), "Pair synchronized without ship authorization")
	pair.ship_approved = TRUE
	TEST_ASSERT_NULL(pair.unavailable_reason(), "Approved installed powered server pair was unavailable")
	pair.synchronize()
	TEST_ASSERT_NOTNULL(pair.last_success, "Valid pair did not synchronize")
	var/success_time = pair.last_success
	remote_server.set_machine_stat(NOPOWER)
	TEST_ASSERT_NOTNULL(pair.unavailable_reason(), "Unpowered pair reported available")
	pair.synchronize()
	TEST_ASSERT_EQUAL(pair.last_success, success_time, "Unpowered pair reported a new success")
	remote_server.set_machine_stat(0)
	remote_disk.forceMove(home_tile)
	TEST_ASSERT_NULL(remote_server.stored_research, "Removed disk left its server linked to data")
	TEST_ASSERT_NOTNULL(pair.unavailable_reason(), "Removed trusted disk remained available")
	var/obj/item/computer_disk/ship_disk/replacement_disk = new(ship_tile)
	remote_server.attacked_by(replacement_disk, steward)
	TEST_ASSERT_NOTNULL(pair.unavailable_reason(), "Pair implicitly trusted a replacement disk")
	TEST_ASSERT_NOTEQUAL(local_server.stored_research, replacement_disk.stored_research, "Servers shared one mutable research web")
	visitor.docked = null
	TEST_ASSERT_NOTNULL(pair.unavailable_reason(), "Pair remained available after departure")
	qdel(local_server)
	TEST_ASSERT_NULL(lathe.stored_research, "Server destruction left fabrication linked to a removed disk")
	qdel(lathe)
	qdel(remote_server)
	qdel(local_disk)
	qdel(remote_disk)
	qdel(replacement_disk)
	ship_tile.change_area(ship_area, original_area)
	ship_area.shuttle_port = null
	port.shuttle_areas = list()
	visitor.shuttle = null
	port.current_ship = null
	qdel(port, force = TRUE)
	qdel(ship_area)
	test_port = null
	test_ship_area = null
	test_ship_tile = null
	test_original_area = null

/datum/unit_test/voidcrew_outpost_research/Run()
	var/datum/techweb/source = allocate(/datum/techweb)
	var/datum/techweb/target = allocate(/datum/techweb)
	source.research_node_id(TECHWEB_NODE_PLASMA_CONTROL, TRUE, FALSE, FALSE)
	source.research_points[TECHWEB_POINT_TYPE_GENERIC] = 500
	target.research_points[TECHWEB_POINT_TYPE_GENERIC] = 17
	var/datum/experiment/scanning/random/material = allocate(/datum/experiment/scanning/random)
	material.required_atoms = list(/obj/item/stack/sheet/iron = 3)
	material.scanned = list(/obj/item/stack/sheet/iron = list("one", "two", "three"))
	material.completed = TRUE
	source.completed_experiments[material.type] = material
	target.skipped_experiment_types[material.type] = 200
	source.survey_data = new
	var/datum/surveyed_celestial_object/planet/planet = new
	planet.ref_id = "round-survey-fixture"
	planet.object_name = "A surveyed planet"
	planet.visited = TRUE
	planet.recorded_at = 10
	source.survey_data.survey_objects_by_type["planets"] += planet
	target.merge_completed_records(source)
	target.merge_completed_records(source)
	source.merge_completed_records(target)
	TEST_ASSERT(target.researched_nodes[TECHWEB_NODE_PLASMA_CONTROL], "Sync omitted researched technologies")
	TEST_ASSERT(target.researched_designs["pacman"], "Sync omitted permitted designs")
	TEST_ASSERT_NULL(target.skipped_experiment_types[/datum/experiment/ordnance/gaseous/plasma], "Imported technology created a refund for points never spent locally")
	TEST_ASSERT_EQUAL(source.research_points[TECHWEB_POINT_TYPE_GENERIC], 500, "Sync changed the source point balance")
	TEST_ASSERT_EQUAL(target.research_points[TECHWEB_POINT_TYPE_GENERIC], 17, "Sync copied points or paid experiment rewards")
	TEST_ASSERT_EQUAL(target.skipped_experiment_types[material.type], -1, "Imported evidence left a repeat refund available")
	var/datum/experiment/completion_record/record = target.completed_experiments[material.type]
	TEST_ASSERT_NOTNULL(record, "Completed experiment evidence was omitted")
	TEST_ASSERT_EQUAL(json_encode(record.check_progress()), json_encode(material.check_progress()), "Copied evidence changed the actual requirements/progress")
	TEST_ASSERT_NOTEQUAL(record, material, "Sync shared mutable experiment state")
	TEST_ASSERT_EQUAL(length(target.survey_data.survey_objects_by_type["planets"]), 1, "Repeated sync duplicated survey identity")
	var/datum/surveyed_celestial_object/planet/copied = target.survey_data.survey_objects_by_type["planets"][1]
	TEST_ASSERT_NOTEQUAL(copied, planet, "Sync shared mutable survey records")
	planet.visited = FALSE
	planet.recorded_at = 5
	target.merge_completed_records(source)
	TEST_ASSERT(copied.visited, "Older incoming survey erased newer retained evidence")
	qdel(source)
	TEST_ASSERT(record.completed && copied.visited, "Losing the source erased the real backup")

/datum/unit_test/voidcrew_outpost_permissions/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.founder_ckey = "founder"
	home.loaded = TRUE
	home.ensure_home_services()
	var/mob/living/carbon/human/resident = allocate(/mob/living/carbon/human/consistent)
	resident.mind_initialize()
	home.residents |= resident.mind
	TEST_ASSERT(home.is_resident(resident), "Resident membership was not recognized")
	TEST_ASSERT(!home.can_spend(resident), "Resident membership granted spending")
	TEST_ASSERT(!home.can_manage(resident), "Resident membership granted administration")
	TEST_ASSERT(!home.can_build(resident), "Resident membership granted construction")
	var/obj/item/card/id/id = allocate(/obj/item/card/id)
	var/datum/bank_account/personal = allocate(/datum/bank_account, "Resident personal", null, 1, FALSE)
	personal.account_balance = 100
	id.registered_account = personal
	resident.put_in_hands(id)
	TEST_ASSERT(home.deposit_from(resident, 50), "Resident could not deposit from a named ID account")
	TEST_ASSERT_EQUAL(personal.account_balance, 50, "Deposit did not debit the named payer")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 50, "Deposit did not credit the claim")
	TEST_ASSERT(!home.withdraw_to(resident, 20), "Resident without spending authority withdrew treasury funds")
	TEST_ASSERT(!home.deposit_from(resident, -1), "Negative deposit passed transaction validation")
	TEST_ASSERT(!home.deposit_from(resident, 1.5), "Fractional deposit passed transaction validation")
	home.treasurers |= resident.mind
	TEST_ASSERT(home.withdraw_to(resident, 20), "Treasury delegate could not withdraw to a named ID account")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 30, "Authorized withdrawal debited the wrong amount")
	TEST_ASSERT_EQUAL(personal.account_balance, 70, "Authorized withdrawal credited the wrong recipient")
	TEST_ASSERT_EQUAL(id.registered_account, personal, "Treasury transaction rebound the resident's ID")
	TEST_ASSERT(home.can_spend(resident), "Treasury delegate cannot operate")
	TEST_ASSERT(!home.can_manage(resident), "Treasury delegate gained management")
	home.stewards |= resident.mind
	TEST_ASSERT(home.can_manage(resident), "Steward cannot manage while the owner is absent")
	home.invited_residents["returning"] = TRUE
	TEST_ASSERT(home.has_resident_clearance("returning"), "Saved invitation requires an online owner")
	home.blocked_residents |= "returning"
	TEST_ASSERT(!home.has_resident_clearance("returning"), "Blocked player retained invitation access")
	TEST_ASSERT_NOTNULL(home.resident_admission_error("returning"), "Blocked player passed arrival policy")
	home.resident_clearance["passwordguest"] = home.resident_access_revision
	home.resident_access_revision++
	TEST_ASSERT(!home.has_resident_clearance("passwordguest"), "Password change retained stale clearance")
	home.resident_mode = "closed"
	TEST_ASSERT_NOTNULL(home.resident_admission_error("founder"), "Closed arrivals admitted the owner")
	TEST_ASSERT_EQUAL(home.active_resident_count(), 0, "Offline historical membership exhausted active positions")
	home.founder_ckey = null
	TEST_ASSERT(!home.can_spend(resident), "Abandoned claim allowed new spending")

/datum/unit_test/voidcrew_outpost_medium_bundle/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/medium)
	TEST_ASSERT(home.load_level(), "Waystation Frame failed to install its purchased home services")
	TEST_ASSERT(home.home_bundle_installed, "Waystation Frame omitted the included bundle")
	TEST_ASSERT_NOTNULL(home.available_resident_pod(), "Waystation Frame has no resident arrival point")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "A new home received an unpurchased allowance")

/// Material/research checks can run after a buffered endpoint leaves the map.
/datum/unit_test/voidcrew_service_site_nullspace/Run()
	var/obj/item/first = allocate(/obj/item)
	var/obj/item/second = allocate(/obj/item)
	TEST_ASSERT(same_service_site(first, second), "Co-located unregistered endpoints lost normal local linking")
	first.moveToNullspace()
	TEST_ASSERT(!same_service_site(first, second), "A removed source retained a physical service link")
	TEST_ASSERT(!same_service_site(second, first), "A removed target retained a physical service link")
	second.moveToNullspace()
	TEST_ASSERT(!same_service_site(first, second), "Two missing endpoints were treated as one service site")
	TEST_ASSERT(!same_service_site(null, run_loc_floor_bottom_left), "A deleted endpoint retained a service link")

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/proc/run_queued_dispatch(datum/voidcrew_cargo_shuttle/outpost/ferry)
	queued_dispatch_error = ferry.call_shuttle()
	queued_dispatch_finished = TRUE
