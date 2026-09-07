/// Exercise the empty-hand relay path without opening dialogs in the test world.
/obj/machinery/rnd/server/relay/fleet_test/confirm_connection(mob/living/user, obj/structure/overmap/dynamic/player_outpost/home, disconnect = FALSE)
	return TRUE

/// Purchased templates must install ordinary, automatically bound cargo terminals.
/datum/unit_test/proc/assert_outpost_cargo_bundle(obj/structure/overmap/dynamic/player_outpost/home)
	var/terminal_count = 0
	for(var/obj/machinery/computer/voidcrew_cargo/terminal as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/voidcrew_cargo))
		if(get_outpost_from_atom(terminal) == home)
			terminal_count++
			TEST_ASSERT_EQUAL(terminal.cargo_account(), home.treasury, "A purchased cargo terminal did not automatically bind to its claim account")
	TEST_ASSERT_EQUAL(terminal_count, 1, "A purchased habitat must start with one cargo console")
	var/list/turf/reachable = list(home.arrival_turf)
	for(var/index = 1; index <= length(reachable); index++)
		var/turf/current = reachable[index]
		for(var/direction in GLOB.cardinals)
			var/turf/neighbor = get_step(current, direction)
			if(!istype(neighbor, /turf/open/floor) || get_area(neighbor) != home.outpost_area || (neighbor in reachable))
				continue
			var/blocked = FALSE
			for(var/atom/movable/obstacle in neighbor)
				// Normal airlocks are traversable; windows and dense furnishings are not.
				if(obstacle.density && !istype(obstacle, /obj/machinery/door))
					blocked = TRUE
					break
			if(!blocked)
				reachable += neighbor
	var/banks = 0
	var/pods = 0
	for(var/turf/floor in home.outpost_area)
		for(var/obj/machinery/machine in floor)
			if(istype(machine, /obj/machinery/computer/bank_machine))
				banks++
			else if(istype(machine, /obj/machinery/cryopod))
				pods++
			else if(!istype(machine, /obj/machinery/computer/voidcrew_cargo) && machine != home.management_console && machine != home.construction_console)
				continue
			for(var/atom/movable/obstacle in floor)
				if(obstacle != machine)
					TEST_ASSERT(!obstacle.density && !istype(obstacle, /obj/effect/spawner/structure/window), "A founding service overlaps a window or another dense object")
			var/accessible = FALSE
			for(var/direction in GLOB.cardinals)
				if(get_step(floor, direction) in reachable)
					accessible = TRUE
					break
			TEST_ASSERT(accessible, "A founding service cannot be reached from arrivals without climbing over furniture")
	TEST_ASSERT_EQUAL(banks, 1, "A purchased habitat must start with one bank terminal")
	TEST_ASSERT_EQUAL(pods, 1, "A purchased habitat must start with one resident cryopod")

/// Claim economy and actual ferry integration, including physical delivery without a ship.
/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home
	var/obj/docking_port/mobile/voidcrew/test_port
	var/area/shuttle/voidcrew/test_ship_area
	var/turf/test_ship_tile
	var/area/test_original_area
	var/datum/shuttle_template_load/test_load_owner
	var/queued_dispatch_finished = FALSE
	var/queued_dispatch_error
	var/list/relay_test_ports = list()
	var/list/relay_test_areas = list()

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/Destroy()
	for(var/obj/docking_port/mobile/voidcrew/port as anything in relay_test_ports)
		port.current_ship.shuttle = null
		port.current_ship = null
		port.shuttle_areas = list()
		qdel(port, force = TRUE)
	for(var/turf/location as anything in relay_test_areas)
		var/area/shuttle/voidcrew/temporary_area = get_area(location)
		location.change_area(temporary_area, relay_test_areas[location])
		temporary_area.shuttle_port = null
		qdel(temporary_area)
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

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/proc/make_relay_ship(turf/location, mob/living/captain, obj/structure/overmap/dynamic/player_outpost/home)
	var/area/shuttle/voidcrew/ship_area = new
	relay_test_areas[location] = get_area(location)
	location.change_area(get_area(location), ship_area)
	var/obj/docking_port/mobile/voidcrew/port = new(location)
	relay_test_ports += port
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.shuttle_areas = list()
	port.shuttle_areas[ship_area] = TRUE
	ship_area.shuttle_port = port
	port.register()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.shuttle = port
	port.current_ship = ship
	ship.docked = home
	ship.state = "idle"
	ship.ship_team = new /datum/team/voidcrew
	ship.ship_team.add_member(captain.mind)
	ship.claimed_captain = captain.mind
	return ship

/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/Run()
	save_economy()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "outpostfounder"
	TEST_ASSERT(home.load_level(), "Purchased home bundle failed to load")
	TEST_ASSERT(home.home_bundle_installed, "Founding did not install the included services")
	assert_outpost_cargo_bundle(home)
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
	// A passenger entering during the departure countdown must leave before retry.
	var/list/freight_floors = ferry.get_cargo_bay_turfs()
	var/mob/living/carbon/human/passenger = allocate(/mob/living/carbon/human/consistent, freight_floors[1])
	TEST_ASSERT(!ferry.complete_departure(), "Freight departed with a late boarding passenger")
	TEST_ASSERT_NOTNULL(ferry.last_error, "Interrupted departure did not explain the passenger obstruction")
	TEST_ASSERT_EQUAL(account.account_balance, 10000 - price, "Interrupted departure credited exports before the goods left")
	passenger.forceMove(home.arrival_turf)
	TEST_ASSERT(ferry.send_shuttle(), "Freight could not retry after its passenger left")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(ferry.complete_departure(), "Outpost exports could not settle without a console")
	TEST_ASSERT_NULL(ferry.last_error, "A successful departure left the old passenger obstruction in management")
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
	var/obj/machinery/rnd/server/relay/ship_relay
	var/obj/item/computer_disk/ship_disk/local_disk = new(home_tile)
	var/obj/item/computer_disk/ship_disk/remote_disk = new(ship_tile)
	local_server.attacked_by(local_disk, steward)
	remote_server.attacked_by(remote_disk, steward)
	var/ship_points_before_relay = remote_disk.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC]
	visitor.ship_team = new /datum/team/voidcrew()
	visitor.ship_team.add_member(steward.mind)
	visitor.claimed_captain = steward.mind
	// All physical servers must remain selectable when disks and ships share names.
	var/obj/machinery/rnd/server/ship/second_local_server = new(home_tile)
	var/obj/item/computer_disk/ship_disk/second_local_disk = new(home_tile)
	second_local_disk.name = local_disk.name
	second_local_server.attacked_by(second_local_disk, steward)
	var/list/local_choices = home.research_server_options()
	var/list/remote_choices = home.research_ship_options()
	TEST_ASSERT_EQUAL(length(local_choices), 2, "Identical disk names hid a local physical server")
	TEST_ASSERT_EQUAL(length(remote_choices), 1, "A docked ship relay was not offered for linking")
	TEST_ASSERT(local_server in flatten_list(local_choices), "Local choices omitted the first physical disk")
	TEST_ASSERT(second_local_server in flatten_list(local_choices), "Local choices omitted the second physical disk")
	TEST_ASSERT(visitor in flatten_list(remote_choices), "Invitation choices omitted a docked ship without a relay")
	qdel(second_local_server)
	qdel(second_local_disk)
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
	TEST_ASSERT(!home.propose_research_link(steward, local_server, visitor, local_disk), "Visitor proposed a link without authority")
	home.stewards |= steward.mind
	TEST_ASSERT(!home.propose_research_link(steward, local_server, visitor, remote_disk), "A stale home disk was accepted")
	TEST_ASSERT(!home.propose_research_link(steward, local_server, visitor, null), "A missing home disk implicitly trusted its replacement")
	var/datum/outpost_research_link/link = home.propose_research_link(steward, local_server, visitor, local_disk)
	TEST_ASSERT_NOTNULL(link, "Authorized home could not request a relay link")
	TEST_ASSERT(link in home.research_links, "Home did not retain its pending relay link")
	TEST_ASSERT_NULL(link.ship_relay, "Invitation required a relay before acceptance")
	TEST_ASSERT_EQUAL(home.propose_research_link(steward, local_server, visitor, local_disk), link, "Repeated invitation created duplicate pending requests")
	link.reconcile()
	TEST_ASSERT(!QDELETED(link), "A pending ship invitation disappeared before relay construction")
	ship_relay = new /obj/machinery/rnd/server/relay/fleet_test(ship_tile)
	ship_relay.set_machine_stat(0)
	visitor.docked = null
	link.reconcile()
	TEST_ASSERT(!QDELETED(link), "Departure erased a pending fleet invitation")
	TEST_ASSERT_EQUAL(length(ship_relay.invitation_options()), 0, "An undocked relay offered initial acceptance")
	visitor.docked = home
	TEST_ASSERT_NULL(ship_relay.stored_research, "A new relay inherited research before crew acceptance")
	TEST_ASSERT(link in flatten_list(ship_relay.invitation_options()), "A later-built relay did not offer its ship's invitation")
	TEST_ASSERT(!link.available(), "Unapproved relay link reported available")
	var/mob/living/carbon/human/noncaptain = allocate(/mob/living/carbon/human/consistent)
	noncaptain.mind_initialize()
	noncaptain.forceMove(ship_tile)
	TEST_ASSERT(!link.approve(noncaptain, ship_relay), "An unrelated visitor accepted a ship's invitation")
	var/mob/living/carbon/human/crew_member = allocate(/mob/living/carbon/human/consistent, ship_tile)
	crew_member.mind_initialize()
	visitor.ship_team.add_member(crew_member.mind)
	TEST_ASSERT(!visitor.is_ship_captain(crew_member), "The crew-acceptance fixture accidentally made its actor captain")
	ship_relay.attack_hand(crew_member, list())
	TEST_ASSERT(link.ship_approved, "An empty-hand crew click could not accept the research invitation")
	TEST_ASSERT_EQUAL(ship_relay.connection, link, "Crew acceptance did not connect its physical relay")
	TEST_ASSERT(link.valid_endpoints(), "Approved docked relay endpoints were invalid")
	TEST_ASSERT(link.available(), "Approved powered relay link was unavailable")
	TEST_ASSERT_EQUAL(ship_relay.stored_research, local_server.stored_research, "Relay did not expose the outpost disk's authoritative web")
	var/datum/techweb_node/shared_node = SSresearch.techweb_node_by_id(TECHWEB_NODE_BLUESPACE_THEORY)
	local_server.stored_research.update_node_status(shared_node)
	local_server.stored_research.add_point_list(shared_node.get_price(local_server.stored_research))
	var/points_before_purchase = local_server.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC]
	TEST_ASSERT(local_server.stored_research.research_node(shared_node, FALSE, TRUE, FALSE), "The shared relay web could not purchase a research node")
	var/points_after_purchase = local_server.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC]
	TEST_ASSERT(!ship_relay.stored_research.research_node(shared_node, FALSE, TRUE, FALSE), "The relay purchased an already shared research node twice")
	TEST_ASSERT_EQUAL(ship_relay.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC], points_after_purchase, "The shared relay web deducted points twice")
	TEST_ASSERT(points_after_purchase < points_before_purchase, "The shared relay purchase did not deduct its cost once")
	var/obj/machinery/rnd/production/protolathe/ship_lathe = new(ship_tile)
	var/obj/item/multitool/ship_tool = allocate(/obj/item/multitool)
	TEST_ASSERT(ship_relay.multitool_act(steward, ship_tool), "Approved relay did not provide a multitool link")
	TEST_ASSERT(ship_lathe.multitool_act(steward, ship_tool), "Ship equipment could not link through the approved relay")
	TEST_ASSERT_EQUAL(ship_lathe.stored_research, local_server.stored_research, "Ship equipment did not retain the relay's authoritative web")
	var/obj/machinery/computer/rdconsole/ship_console = allocate(/obj/machinery/computer/rdconsole, ship_tile)
	TEST_ASSERT(ship_console.multitool_act(steward, ship_tool), "New ship R&D console could not link while already docked")
	TEST_ASSERT(!can_export_site_techweb(ship_console, local_disk.stored_research), "Relay allowed a portable copy of outpost research")
	TEST_ASSERT(can_export_site_techweb(lathe, local_disk.stored_research), "Local outpost research could no longer be exported")
	var/obj/item/research_notes/notes = allocate(/obj/item/research_notes, ship_tile, 31)
	ship_console.attackby(notes, steward)
	TEST_ASSERT_EQUAL(local_disk.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC], points_after_purchase + 31, "Ship research earnings did not enter the one outpost balance")
	TEST_ASSERT_EQUAL(remote_disk.stored_research.research_points[TECHWEB_POINT_TYPE_GENERIC], ship_points_before_relay, "Relay earnings were copied into the ship's own disk")
	ship_relay.set_machine_stat(NOPOWER)
	link.reconcile()
	TEST_ASSERT(!link.available(), "Powered-off relay remained available")
	TEST_ASSERT_NULL(ship_lathe.stored_research, "Power loss left the ship fabricator connected")
	TEST_ASSERT_NULL(ship_console.stored_research, "Power loss left the ship console connected")
	TEST_ASSERT_EQUAL(lathe.stored_research, local_disk.stored_research, "Relay power loss severed the outpost lab")
	ship_relay.set_machine_stat(0)
	link.reconcile()
	TEST_ASSERT(link.available(), "Relay did not become available after power returned")
	local_server.set_machine_stat(NOPOWER)
	link.reconcile()
	TEST_ASSERT(!link.available(), "Powered-off outpost server remained available")
	local_server.set_machine_stat(0)
	link.reconcile()
	TEST_ASSERT(link.available(), "Relay did not recover after the outpost server powered on")
	TEST_ASSERT(ship_lathe.multitool_act(steward, ship_tool), "Could not restore fabrication before departure")
	// Model the yielding move stage where hull areas and mobile bounds disagree.
	visitor.state = "undocking" // OVERMAP_SHIP_UNDOCKING
	port.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NOTEQUAL(get_service_site(ship_relay), visitor, "Transit fixture did not separate the hull from its mobile bounds")
	TEST_ASSERT_EQUAL(get_research_service_site(ship_relay), visitor, "Moving ship rooms inherited the outpost's research ownership")
	TEST_ASSERT(!same_research_service_site(ship_console, local_server), "A moving ship gained control of the outpost's research machines")
	TEST_ASSERT(!can_export_site_techweb(ship_console, local_disk.stored_research), "Shuttle movement allowed exporting relay research")
	TEST_ASSERT(!can_link_site_techweb(lathe, remote_disk.stored_research), "The outpost inherited a moving ship's independent research")
	TEST_ASSERT(link.available(), "A moving hull lost relay access before its port caught up")
	remote_server.forceMove(home_tile)
	TEST_ASSERT_EQUAL(visitor.find_research_web(), local_disk.stored_research, "Ship research lookup lost the relay during movement")
	remote_server.forceMove(ship_tile)
	link.reconcile()
	TEST_ASSERT(ship_lathe.validate_research_site(ship_lathe.stored_research), "Transit interrupted a still-powered research link")
	ship_relay.set_machine_stat(NOPOWER)
	TEST_ASSERT(!ship_lathe.validate_research_site(ship_lathe.stored_research), "An unpowered relay authorized fabrication during transit")
	TEST_ASSERT_EQUAL(ship_lathe.stored_research, local_disk.stored_research, "Temporary transit power loss permanently severed the ship link")
	ship_relay.set_machine_stat(0)
	port.forceMove(ship_tile)
	visitor.state = "idle"
	link.reconcile()
	TEST_ASSERT(ship_lathe.validate_research_site(ship_lathe.stored_research), "Research did not resume after the hull and port finished moving")
	visitor.docked = null
	TEST_ASSERT(link.valid_endpoints(), "Undocking incorrectly invalidated the approved relay")
	TEST_ASSERT(link.available(), "Undocking incorrectly disabled the approved relay")
	TEST_ASSERT(ship_lathe.multitool_act(steward, ship_tool), "Ship could not relink fabrication after power returned while undocked")
	var/obj/machinery/computer/operating/operating = allocate(/obj/machinery/computer/operating, ship_tile)
	TEST_ASSERT(operating.multitool_act(steward, ship_tool), "Experiment equipment could not use the relay")
	var/obj/structure/overmap/ship/replacement_ship = make_relay_ship(get_step(ship_tile, EAST), noncaptain, home)
	var/obj/machinery/rnd/server/relay/replacement_relay = allocate(/obj/machinery/rnd/server/relay, get_turf(replacement_ship.shuttle))
	replacement_relay.set_machine_stat(0)
	TEST_ASSERT(!can_link_site_techweb(replacement_relay, local_disk.stored_research), "An unrelated visiting ship inherited relay access")
	var/datum/outpost_research_link/replacement_link = home.propose_research_link(steward, local_server, replacement_ship, local_disk)
	TEST_ASSERT_NOTNULL(replacement_link, "Could not request a replacement ship's relay")
	TEST_ASSERT(link.available(), "Inviting another ship interrupted existing fleet research")
	noncaptain.forceMove(get_turf(replacement_relay))
	TEST_ASSERT(replacement_link.approve(noncaptain, replacement_relay), "The second ship could not accept its invitation")
	TEST_ASSERT(link.available() && replacement_link.available(), "Two ships could not share research simultaneously")
	TEST_ASSERT_EQUAL(replacement_relay.stored_research, ship_relay.stored_research, "Fleet relays did not share the same research and points")
	TEST_ASSERT_EQUAL(ship_lathe.stored_research, local_disk.stored_research, "Joining a second ship disconnected the first ship's lathe")
	var/obj/machinery/computer/operating/second_operating = allocate(/obj/machinery/computer/operating, get_turf(replacement_relay))
	TEST_ASSERT(second_operating.multitool_act(noncaptain, ship_tool), "The second fleet ship could not link research equipment")
	qdel(link)
	TEST_ASSERT_NULL(ship_relay.stored_research, "Revoked ship retained the outpost web")
	TEST_ASSERT_NULL(ship_lathe.stored_research, "Revoked ship retained fabrication access")
	TEST_ASSERT_NULL(operating.linked_techweb, "Revoked ship retained surgical research access")
	TEST_ASSERT_NULL(operating.experiment_handler.linked_web, "Revoked ship retained its experiment link")
	TEST_ASSERT(!ship_lathe.multitool_act(steward, ship_tool), "A stale multitool buffer restored a revoked connection")
	TEST_ASSERT(replacement_link.available(), "Revoking one ship disconnected a different fleet ship")
	TEST_ASSERT_EQUAL(second_operating.linked_techweb, local_disk.stored_research, "Revoking one ship severed another ship's equipment")
	TEST_ASSERT_EQUAL(lathe.stored_research, local_disk.stored_research, "Revoking a ship disconnected local outpost equipment")
	TEST_ASSERT_EQUAL(remote_server.stored_research, remote_disk.stored_research, "Fleet membership changed the ship's independent disk")
	qdel(replacement_relay)
	TEST_ASSERT(QDELETED(replacement_link), "Destroying a relay retained its active authorization")
	TEST_ASSERT(!QDELETED(local_disk.stored_research), "Destroying a relay deleted the outpost's physical web")
	TEST_ASSERT_EQUAL(length(home.research_links), 0, "Destroyed relay retained its connection record")
	visitor.docked = home
	link = home.propose_research_link(steward, local_server, visitor, local_disk)
	TEST_ASSERT(link?.approve(crew_member, ship_relay), "Could not authorize the original ship again")
	visitor.claimed_captain = noncaptain.mind
	link.reconcile()
	TEST_ASSERT(!QDELETED(link) && link.available(), "Captain succession revoked the crew's fleet research")
	visitor.claimed_captain = steward.mind
	local_disk.forceMove(home_tile)
	var/obj/item/computer_disk/ship_disk/replacement_disk = new(home_tile)
	local_server.attacked_by(replacement_disk, steward)
	TEST_ASSERT(QDELETED(link), "Replacing the home disk left the old link alive")
	TEST_ASSERT_EQUAL(length(home.research_links), 0, "Removing the source disk retained its fleet connections")
	TEST_ASSERT_NULL(ship_relay.stored_research, "A replaced disk left the relay connected")
	TEST_ASSERT(!can_link_site_techweb(run_loc_floor_bottom_left, local_disk.stored_research), "A removed physical disk became an unscoped fallback web")
	TEST_ASSERT(!home.propose_research_link(steward, local_server, visitor, local_disk), "A stale proposal survived disk replacement")
	qdel(local_server)
	TEST_ASSERT_NULL(lathe.stored_research, "Server destruction left fabrication linked to a removed disk")
	qdel(lathe)
	qdel(remote_server)
	qdel(local_disk)
	qdel(remote_disk)
	qdel(replacement_disk)
	qdel(ship_relay)
	qdel(ship_lathe)
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

/datum/unit_test/voidcrew_outpost_medium_bundle
	var/template_type = /datum/map_template/player_outpost/medium

/datum/unit_test/voidcrew_outpost_medium_bundle/small
	template_type = /datum/map_template/player_outpost/small

/datum/unit_test/voidcrew_outpost_medium_bundle/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(template_type)
	TEST_ASSERT(home.load_level(), "Habitat failed to install its purchased home services")
	TEST_ASSERT(home.home_bundle_installed, "Habitat omitted the included bundle")
	assert_outpost_cargo_bundle(home)
	TEST_ASSERT_NOTNULL(home.available_resident_pod(), "Habitat has no resident arrival point")
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

/// Test-only pack: exercise the real cancellation path while a package is being generated.
/datum/supply_pack/voidcrew_outpost_cancel_during_generation
	name = "outpost cancellation race fixture"
	cost = 100
	crate_name = "cancellation race fixture crate"
	var/datum/voidcrew_cargo_shuttle/outpost/ferry
	var/armed = FALSE
	var/fired = FALSE
	var/obj/structure/closet/crate/generated_crate
	var/redispatch = FALSE
	var/refund_pending = FALSE
	var/replacement_error

/datum/supply_pack/voidcrew_outpost_cancel_during_generation/New(datum/voidcrew_cargo_shuttle/outpost/target_ferry)
	. = ..()
	ferry = target_ferry
	armed = !!target_ferry
	contains = list(/obj/item/stack/sheet/iron = 1)

/datum/supply_pack/voidcrew_outpost_cancel_during_generation/fill(obj/structure/closet/crate/crate)
	generated_crate = crate
	. = ..()
	if(armed && !fired)
		fired = TRUE
		if(refund_pending)
			ferry.cancel_pending()
		else
			ferry.cleanup_shuttle()
			if(redispatch)
				replacement_error = ferry.call_shuttle()

/// Same cancellation point, with no package returned. This catches null generation before
/// the normal QDELETED(package) failure branch.
/datum/supply_pack/voidcrew_outpost_cancel_null_during_generation
	name = "outpost null cancellation race fixture"
	cost = 100
	crate_name = "null cancellation race fixture crate"
	var/datum/voidcrew_cargo_shuttle/outpost/ferry
	var/armed = FALSE
	var/fired = FALSE

/datum/supply_pack/voidcrew_outpost_cancel_null_during_generation/New(datum/voidcrew_cargo_shuttle/outpost/target_ferry)
	. = ..()
	ferry = target_ferry
	armed = !!target_ferry
	contains = list(/obj/item/stack/sheet/iron = 1)

/datum/supply_pack/voidcrew_outpost_cancel_null_during_generation/generate(atom/location, datum/bank_account/paying_account)
	if(armed && !fired)
		fired = TRUE
		ferry.cleanup_shuttle()
		return null
	return ..()

/// A generator-side cancellation must not turn a refunded reservation into a delivered order.
/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/cancel_during_generation
/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/cancel_during_generation/Run()
	save_economy()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "outpostcancelrace"
	TEST_ASSERT(home.load_level(), "Cancellation race home failed to load")
	var/datum/bank_account/account = home.treasury
	account.account_balance = 1000
	var/datum/voidcrew_cargo_shuttle/outpost/ferry = home.freight
	var/datum/supply_pack/voidcrew_outpost_cancel_during_generation/pack = new(ferry)
	var/datum/supply_order/order = new(pack)
	home.cargo_cart += order
	var/price = order.get_final_cost()
	TEST_ASSERT_NULL(ferry.call_shuttle(), "Cancellation race shipment failed to dispatch")
	TEST_ASSERT_EQUAL(account.account_balance, 1000 - price, "Cancellation race did not reserve funds")
	deltimer(ferry.warmup_timer)
	var/delivered = ferry.complete_arrival()
	TEST_ASSERT(!delivered, "Generator-side cancellation reported a successful delivery")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "Generator-side cancellation did not refund the reservation")
	TEST_ASSERT(order in home.cargo_cart, "Generator-side cancellation lost the unpaid cart order")
	TEST_ASSERT_NULL(order.ship_paid_cost, "Generator-side cancellation left the order marked paid")
	TEST_ASSERT(QDELETED(pack.generated_crate), "Cancelled generated package survived the reservation refund")
	home.cargo_cart -= order
	qdel(order)

	var/datum/supply_pack/voidcrew_outpost_cancel_null_during_generation/null_pack = new(ferry)
	var/datum/supply_order/null_order = new(null_pack)
	home.cargo_cart += null_order
	var/null_price = null_order.get_final_cost()
	TEST_ASSERT_NULL(ferry.call_shuttle(), "Null cancellation race shipment failed to dispatch")
	TEST_ASSERT_EQUAL(account.account_balance, 1000 - null_price, "Null cancellation race did not reserve funds")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(!ferry.complete_arrival(), "Null generator cancellation reported a successful delivery")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "Null generator cancellation did not refund the reservation")
	TEST_ASSERT(null_order in home.cargo_cart, "Null generator cancellation lost the unpaid cart order")
	TEST_ASSERT_NULL(null_order.ship_paid_cost, "Null generator cancellation left the order marked paid")

	home.cargo_cart -= null_order
	qdel(null_order)
	var/datum/supply_pack/voidcrew_outpost_cancel_during_generation/replacement_pack = new(ferry)
	replacement_pack.redispatch = TRUE
	var/datum/supply_order/replacement_order = new(replacement_pack)
	home.cargo_cart += replacement_order
	var/replacement_price = replacement_order.get_final_cost()
	TEST_ASSERT_NULL(ferry.call_shuttle(), "Replacement-race shipment failed to dispatch")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(!ferry.complete_arrival(), "Old arrival reported success after a replacement dispatch")
	TEST_ASSERT_NULL(replacement_pack.replacement_error, "Replacement dispatch failed inside the old generator")
	TEST_ASSERT_EQUAL(account.account_balance, 1000 - replacement_price, "Replacement reservation was lost or charged twice")
	TEST_ASSERT_NOTNULL(ferry.warmup_timer, "Old arrival erased the replacement warmup")
	TEST_ASSERT(QDELETED(replacement_pack.generated_crate), "Old generation left an unpaid crate after replacement")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(ferry.complete_arrival(), "Old completion damaged the replacement shipment")
	TEST_ASSERT_EQUAL(account.account_balance, 1000 - replacement_price, "Replacement delivery charged twice")
	TEST_ASSERT(!QDELETED(replacement_pack.generated_crate), "Replacement delivery lost its paid crate")

/// Refunding remaining orders while a later package is generated must leave earlier paid goods accessible.
/datum/unit_test/voidcrew_launch_cargo_fixture/outpost_home/cancel_during_generation/partial_refund/Run()
	save_economy()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/small)
	home.founder_ckey = "outpostpartialcancel"
	TEST_ASSERT(home.load_level(), "Partial cancellation home failed to load")
	home.treasury.account_balance = 1000
	var/datum/voidcrew_cargo_shuttle/outpost/ferry = home.freight
	var/datum/supply_pack/voidcrew_outpost_cancel_during_generation/paid_pack = new
	var/datum/supply_pack/voidcrew_outpost_cancel_during_generation/cancelled_pack = new(ferry)
	cancelled_pack.refund_pending = TRUE
	var/datum/supply_order/paid_order = new(paid_pack)
	var/datum/supply_order/cancelled_order = new(cancelled_pack)
	var/paid_price = paid_order.get_final_cost()
	home.cargo_cart += paid_order
	home.cargo_cart += cancelled_order
	TEST_ASSERT_NULL(ferry.call_shuttle(), "Partial cancellation shipment failed to dispatch")
	deltimer(ferry.warmup_timer)
	TEST_ASSERT(!ferry.complete_arrival(), "Cancelled shipment reported complete delivery")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 1000 - paid_price, "Cancellation did not preserve only the settled payment")
	TEST_ASSERT(!QDELETED(paid_pack.generated_crate), "Cancellation destroyed an earlier paid package")
	TEST_ASSERT(ferry.shuttle_port?.is_in_shuttle_bounds(paid_pack.generated_crate), "Paid package is no longer on the accessible freight deck")
	TEST_ASSERT(QDELETED(cancelled_pack.generated_crate), "Cancellation left an unpaid staged package")
	TEST_ASSERT(!ferry.busy, "Cancellation left freight processing stuck")
	TEST_ASSERT_EQUAL(ferry.shuttle_port?.get_docked(), home.freight_berth.dock, "Cancellation removed the delivered goods' physical receiver")
