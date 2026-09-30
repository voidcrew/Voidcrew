/// Confirmations exercise the real save transaction without a connected client.
/datum/ship_checkpoint_ui/registry_test
	var/datum/callback/during_confirmation
	var/accept_save = TRUE
	/// Most cases place visits directly; one lets the real drones work.
	var/manual_jobs = TRUE

/datum/ship_checkpoint_ui/registry_test/confirm_save(mob/user, prompt_text)
	during_confirmation?.Invoke()
	return accept_save

/datum/ship_checkpoint_ui/registry_test/create_rebuild_job(mob/living/user, datum/ship_checkpoint/snapshot)
	return new /datum/checkpoint_construction(src, snapshot, user, manual_jobs)

/// Refuse the bay reservation to exercise a rebuild refused before anything loads.
/obj/structure/overmap/dynamic/player_outpost/registry_test
	var/refuse_bay = FALSE

/obj/structure/overmap/dynamic/player_outpost/registry_test/reserve_rebuild_bay(datum/owner)
	if(refuse_bay)
		return null
	return ..()

/datum/unit_test/voidcrew_checkpoints
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/list/obj/structure/overmap/ship/test_ships = list()
	var/destroy_original = FALSE
	var/delete_via_admin = FALSE
	var/escape_on_delete = FALSE
	var/orphaned_original = FALSE
	/// Hull census changes the case made on purpose, applied before the final comparison.
	var/list/count_adjustments = list()
	/// Place visits directly; the drone case lets the real controller work.
	var/manual_jobs = TRUE
	var/obj/machinery/computer/ship_checkpoint/terminal
	var/turf/terminal_turf

/// Recovery must also work after the hull and the captain's original body are gone.
/datum/unit_test/voidcrew_checkpoints/lost
	destroy_original = TRUE

/// Use the same post-confirmation deletion path as Shuttle Manipulator.
/datum/unit_test/voidcrew_checkpoints/admin_deleted
	destroy_original = TRUE
	delete_via_admin = TRUE

/datum/unit_test/voidcrew_checkpoints/admin_deleted/escaped
	escape_on_delete = TRUE

/// Existing hull-less records must not require the captain to abandon a ghost ship.
/datum/unit_test/voidcrew_checkpoints/missing_hull
	orphaned_original = TRUE

/// Piece by piece: visibility, the reserved bay, single-pass placement and interruptions.
/datum/unit_test/voidcrew_checkpoints/staged

/// The bay is lost after the first pieces exist.
/datum/unit_test/voidcrew_checkpoints/terminated

/// The real controller and drones, rather than directly placed visits.
/datum/unit_test/voidcrew_checkpoints/drones
	manual_jobs = FALSE

/// The captain never returns for the finished hull.
/datum/unit_test/voidcrew_checkpoints/unclaimed
	var/datum/bank_account/personal

/datum/unit_test/voidcrew_checkpoints/Destroy()
	// Dispose ships before their host reservations, just as normal departures do.
	for(var/obj/structure/overmap/ship/ship as anything in test_ships)
		if(!QDELETED(ship))
			qdel(ship)
	return ..()

/datum/unit_test/voidcrew_checkpoints/proc/drain_account(obj/structure/overmap/ship/ship)
	ship.ship_account.account_balance = 0

/datum/unit_test/voidcrew_checkpoints/proc/count_hull(obj/docking_port/mobile/port)
	var/list/counts = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		counts["[tile.type]"]++
		for(var/obj/object in tile)
			if(ismachinery(object))
				var/obj/machinery/machine = object
				if(machine.checkpoint_type())
					counts["[machine.checkpoint_type()]"]++
			else if(outpost_checkpoint_saves(object))
				// Storage shells intentionally omit the original loot-spawner subtype.
				counts[istype(object, /obj/structure/closet) ? "closet:[object.name]" : "[object.type]"]++
	return counts

/// Every turf of the permanent bay interior.
/datum/unit_test/voidcrew_checkpoints/proc/bay_turfs(datum/outpost_berth/ship_bay/bay)
	return bay.get_block()

/datum/unit_test/voidcrew_checkpoints/proc/count_bay_ship_tiles(datum/outpost_berth/ship_bay/bay)
	. = 0
	for(var/turf/tile as anything in bay_turfs(bay))
		if(istype(tile.loc, /area/shuttle))
			.++

/datum/unit_test/voidcrew_checkpoints/proc/count_bay_machines(datum/outpost_berth/ship_bay/bay)
	. = 0
	for(var/turf/tile as anything in bay_turfs(bay))
		if(!istype(tile.loc, /area/shuttle))
			continue
		for(var/obj/machinery/machine in tile)
			if(machine.checkpoint_type())
				.++

/datum/unit_test/voidcrew_checkpoints/proc/count_bay_walls(datum/outpost_berth/ship_bay/bay)
	. = 0
	for(var/turf/tile as anything in bay_turfs(bay))
		if(istype(tile.loc, /area/shuttle) && iswallturf(tile))
			.++

/// Neither a reservation nor a physical move may put another ship into a bay under construction.
/datum/unit_test/voidcrew_checkpoints/proc/check_bay_refuses_visitors(obj/structure/overmap/dynamic/player_outpost/home, datum/outpost_berth/ship_bay/bay, when)
	var/obj/structure/overmap/ship/intruder = allocate(/obj/structure/overmap/ship)
	var/obj/docking_port/mobile/voidcrew/intruder_port = new(run_loc_floor_bottom_left)
	intruder.shuttle = intruder_port
	intruder_port.current_ship = intruder
	TEST_ASSERT_NULL(home.allocate_ship_bay(intruder), "Another ship reserved the bay [when]")
	TEST_ASSERT_NULL(home.available_ship_bay(), "The bay was offered to visitors [when]")
	TEST_ASSERT_EQUAL(intruder_port.canDock(bay.dock), SHUTTLE_SOMEONE_ELSE_DOCKED, "Another ship could target the bay [when]")
	TEST_ASSERT_EQUAL(intruder_port.initiate_docking(bay.dock, force = TRUE), DOCKING_BLOCKED, "Another ship landed in the bay [when]")
	intruder_port.current_ship = null
	intruder.shuttle = null
	qdel(intruder_port, force = TRUE)

/// Called just before the reconstruction starts, while the captain is at the console.
/datum/unit_test/voidcrew_checkpoints/proc/prepare_captain(mob/living/carbon/human/captain)
	return

/// Directly placed cases are checked the moment they finish, before any outlet can draw hangar air.
/datum/unit_test/voidcrew_checkpoints/proc/breathes_ambient(datum/pipeline/network)
	return FALSE

/// Rebuilt engines are refuelled to full: a fueled thruster's heater holds gas_capacity moles.
/datum/unit_test/voidcrew_checkpoints/proc/engine_is_full(obj/machinery/power/shuttle_engine/ship/engine)
	if(istype(engine, /obj/machinery/power/shuttle_engine/ship/fueled))
		var/obj/machinery/power/shuttle_engine/ship/fueled/thruster = engine
		var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = thruster.attached_heater?.resolve()
		return heater && engine.return_fuel() >= heater.gas_capacity * 0.99
	if(istype(engine, /obj/machinery/power/shuttle_engine/ship/liquid))
		return engine.return_fuel_cap() && engine.return_fuel() >= engine.return_fuel_cap() * 0.99
	return TRUE

/// Restocked air and plasma tanks share their gas with the pipes they feed.
/datum/unit_test/voidcrew_checkpoints/proc/fed_by_restocked_tank(datum/pipeline/network)
	for(var/obj/machinery/atmospherics/components/tank/supply in network.other_atmos_machines)
		if(is_type_in_typecache(supply, GLOB.outpost_checkpoint_restocked))
			return TRUE
	return FALSE

/// Batteries are charged as each machine lands. Directly placed cases are checked before any
/// of that charge can be used. The source batteries were emptied or removed before saving.
/datum/unit_test/voidcrew_checkpoints/proc/battery_floor()
	return 0.99

/// The ordinary cases place every visit directly, in build order.
/datum/unit_test/voidcrew_checkpoints/proc/build_hull(datum/checkpoint_construction/job, obj/structure/overmap/dynamic/player_outpost/registry_test/home, datum/outpost_berth/ship_bay/bay, mob/living/carbon/human/captain, obj/structure/overmap/ship/original, datum/ship_checkpoint_ui/registry_test/panel, datum/ship_checkpoint/snapshot)
	job.fast_forward()
	return captain

/datum/unit_test/voidcrew_checkpoints/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "registrycaptain"
	TEST_ASSERT(home.load_level(), "The registry outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The permanent recovery bay did not load")
	// Checkpoints are saved and rebuilt at the ship bay's own shipyard console.
	terminal = outpost_bay_shipyard_console(LAZYACCESS(home.bay_berths, 1))
	TEST_ASSERT_NOTNULL(terminal, "The ship bay has no shipyard console")
	terminal_turf = get_turf(terminal)
	var/mob/living/carbon/human/captain = make_player(terminal_turf, "registrycaptain")
	var/mob/living/carbon/human/visitor = make_player(terminal_turf, "registryvisitor")
	var/obj/structure/overmap/ship/original = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(original, "Could not create the source hull")
	test_ships += original
	original.enlist_crewmember(captain)
	original.claimed_captain = captain.mind
	original.enlist_crewmember(visitor)
	original.ship_account.account_balance = 40000
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(original)
	TEST_ASSERT_NOTNULL(bay, "Could not allocate the source bay")
	// What the bay floor looks like before any hull lands on it.
	var/list/bay_floor = list()
	for(var/turf/tile as anything in bay_turfs(bay))
		bay_floor[tile] = list(tile.type, tile.loc)
	adjust_reserve_dock_to_shuttle(bay.dock, original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	original.shuttle.initiate_docking(bay.dock)
	original.shuttle.mode = SHUTTLE_IDLE
	original.docked = home
	original.forceMove(home)
	original.state = "idle"
	bay.on_ship_docked(original)
	TEST_ASSERT(bay.is_ship_present(), "The real source hull did not land in the bay")
	var/obj/machinery/ore_silo/silo = home.ship_bay_silo()
	TEST_ASSERT_NOTNULL(silo, "The mapped outpost silo was not discovered without a construction link")
	// No selected silo, no materials and no grants may be required by checkpoints.
	bay.revoke_silo()
	bay.console.disconnect_materials()
	var/turf/fixture_turf
	for(var/turf/tile as anything in original.shuttle.return_turfs())
		if(isfloorturf(tile) && (get_area(tile) in original.shuttle.shuttle_areas))
			fixture_turf = tile
			break
	var/obj/machinery/autolathe/lathe = new(fixture_turf)
	lathe.name = "checkpoint upgrade fixture"
	for(var/datum/stock_part/matter_bin/part in lathe.component_parts.Copy())
		lathe.component_parts -= part
		lathe.component_parts += GLOB.stock_part_datums[/datum/stock_part/matter_bin/tier4]
	lathe.RefreshParts()
	var/expected_bin_rating = lathe.total_part_rating(/datum/stock_part/matter_bin)
	lathe.materials.insert_amount_mat(5000, /datum/material/iron)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/builder = new(fixture_turf)
	for(var/disk_type in list(/obj/item/ship_construction_upgrade/rtd, /obj/item/ship_construction_upgrade/rpd, /obj/item/ship_construction_upgrade/rld, /obj/item/ship_construction_upgrade/decal, /obj/item/ship_construction_upgrade/servo/mk4))
		var/obj/item/disk = new disk_type(builder)
		builder.item_interaction(captain, disk)
	var/expected_construction_upgrades = builder.console_upgrades
	new /obj/machinery/power/shuttle_engine/ship/liquid/oil(fixture_turf)
	new /obj/machinery/vending/cola(fixture_turf)
	var/obj/machinery/ore_silo/ship_silo = new(fixture_turf)
	ship_silo.materials.insert_amount_mat(5000, /datum/material/iron)
	new /obj/item/stack/sheet/iron(fixture_turf, 50)
	var/removed_apc_cell = FALSE
	var/removed_smes_cells = FALSE
	for(var/turf/tile as anything in original.shuttle.return_turfs())
		for(var/obj/machinery/power/apc/controller in tile)
			if(!removed_apc_cell)
				QDEL_NULL(controller.cell)
				removed_apc_cell = TRUE
			else if(controller.cell)
				controller.cell.charge = 0
		for(var/obj/machinery/power/smes/bank in tile)
			for(var/obj/item/stock_parts/power_store/battery in bank.component_parts.Copy())
				if(!removed_smes_cells)
					bank.component_parts -= battery
					qdel(battery)
				else
					battery.charge = 0
			removed_smes_cells = TRUE
			bank.RefreshParts()
	var/datum/ship_checkpoint_ui/registry_test/panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
	TEST_ASSERT_NOTNULL(panel.save_denial(visitor, bay), "A non-captain could register the hull")
	TEST_ASSERT(panel.prepare_save(captain, bay), "Could not prepare a real hull: [panel.error]")
	TEST_ASSERT(!findtext(panel.quote.tgm, "/obj/item"), "The snapshot includes items")
	TEST_ASSERT(findtext(panel.quote.tgm, "/obj/machinery/computer/helm"), "Checkpoint omitted the helm")
	TEST_ASSERT(!findtext(panel.quote.tgm, "initial_gas_mix"), "The snapshot preserved room gases")
	var/datum/parsed_map/parsed = new(panel.quote.tgm)
	TEST_ASSERT_EQUAL(parsed.bounds[4], panel.quote.width, "Exported width does not parse correctly")
	TEST_ASSERT_EQUAL(parsed.bounds[5], panel.quote.height, "Exported height does not parse correctly")
	qdel(parsed)
	rustg_file_write(panel.quote.tgm, "data/registry-source-hull.dmm")
	var/list/before_counts = count_hull(original.shuttle)
	TEST_ASSERT(before_counts["[/obj/machinery/cryopod]"], "The source hull has no cryopod to recover")
	var/list/dropped = list()
	for(var/turf/tile as anything in original.shuttle.return_turfs())
		if(!(get_area(tile) in original.shuttle.shuttle_areas))
			continue
		for(var/obj/machinery/machine in tile)
			if(!machine.checkpoint_type())
				dropped["[machine.type]"]++
		for(var/obj/structure/fitting in tile)
			if(!outpost_checkpoint_saves(fitting))
				dropped["[fitting.type]"]++
	var/list/dropped_text = list()
	for(var/type_name in dropped)
		dropped_text += "[type_name] x[dropped[type_name]]"
	log_test("Machinery and structures a checkpoint of this hull leaves out: [length(dropped_text) ? dropped_text.Join(", ") : "none"]")
	var/room_count = length(panel.quote.rooms)
	var/before_iron = silo.materials.get_material_amount(/datum/material/iron)
	var/before_money = original.ship_account.account_balance
	var/before_treasury = home.treasury.account_balance
	panel.accept_save = FALSE
	TEST_ASSERT(!panel.save_quote(captain), "Cancelling confirmation still saved a checkpoint")
	TEST_ASSERT_EQUAL(original.ship_account.account_balance, before_money, "Cancellation charged credits")
	panel.accept_save = TRUE
	panel.during_confirmation = CALLBACK(src, PROC_REF(drain_account), original)
	TEST_ASSERT(!panel.save_quote(captain), "Funds spent during confirmation were charged again")
	TEST_ASSERT_EQUAL(length(home.checkpoints), 0, "A declined save created a checkpoint")
	panel.during_confirmation = null
	original.ship_account.account_balance = before_money
	var/datum/ship_checkpoint_ui/registry_test/other_panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
	TEST_ASSERT(other_panel.prepare_save(captain, bay), "Could not prepare a concurrent save")
	TEST_ASSERT_EQUAL(panel.quoted_fee, 10000, "First checkpoint did not cost 10,000 credits")
	TEST_ASSERT(panel.save_quote(captain), "Could not save a checkpoint without silo access: [panel.error]")
	TEST_ASSERT_EQUAL(before_money - original.ship_account.account_balance, 10000, "Save charged the wrong amount")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, before_treasury, "Checkpoint fee was refunded through the outpost treasury")
	TEST_ASSERT(!other_panel.save_quote(captain), "A stale save overwrote the paid checkpoint")
	var/datum/ship_checkpoint/snapshot = home.checkpoints[1]
	TEST_ASSERT(!panel.save_quote(captain), "A repeated save reused the paid snapshot")
	// Updating must capture the newest design, charge 5k and preserve the old one on failure.
	lathe.name = "updated checkpoint fixture"
	TEST_ASSERT(panel.prepare_save(captain, bay), "Could not prepare an update")
	TEST_ASSERT_EQUAL(panel.quoted_fee, 5000, "Updating did not cost 5,000 credits")
	panel.accept_save = FALSE
	TEST_ASSERT(!panel.save_quote(captain) && home.checkpoints[1] == snapshot, "Cancelled update lost the old checkpoint")
	panel.accept_save = TRUE
	original.ship_account.account_balance = 4999
	TEST_ASSERT(!panel.save_quote(captain) && home.checkpoints[1] == snapshot, "Unaffordable update lost the old checkpoint")
	original.ship_account.account_balance = before_money - 10000
	TEST_ASSERT(panel.save_quote(captain), "Could not update a checkpoint")
	TEST_ASSERT(QDELETED(snapshot), "Update retained the old snapshot")
	TEST_ASSERT_EQUAL(length(home.checkpoints), 1, "Updating created a second checkpoint")
	TEST_ASSERT_EQUAL(before_money - original.ship_account.account_balance, 15000, "Save and update charged the wrong total")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, before_treasury, "Update fee was refunded through the outpost treasury")
	TEST_ASSERT_EQUAL(silo.materials.get_material_amount(/datum/material/iron), before_iron, "Checkpoint consumed silo materials")
	snapshot = home.checkpoints[1]
	TEST_ASSERT(findtext(snapshot.tgm, "updated checkpoint fixture"), "Update retained the older design")
	TEST_ASSERT_NOTNULL(panel.rebuild_denial(captain, snapshot), "A crewed original permitted a second hull")
	TEST_ASSERT_NOTNULL(panel.rebuild_denial(visitor, snapshot), "A non-captain could recover another captain's hull")
	// Move the original out of its construction bay, then abandon it.
	var/obj/docking_port/stationary/transit/source_transit = original.shuttle.assigned_transit || SSshuttle.generate_transit_dock(original.shuttle)
	original.shuttle.mode = SHUTTLE_PREARRIVAL
	TEST_ASSERT_EQUAL(original.shuttle.initiate_docking(source_transit), DOCKING_SUCCESS, "Source hull could not enter transit")
	original.shuttle.mode = SHUTTLE_IDLE
	original.docked = null
	original.forceMove(get_turf(home))
	original.state = "flying"
	home.on_ship_undock_complete(original)
	TEST_ASSERT_EQUAL(home.bay_berths[1], bay, "Departure replaced the permanent bay")
	TEST_ASSERT(bay.is_available(), "Departure retained the old ship reservation")
	var/old_balance = original.ship_account.account_balance
	if(orphaned_original)
		// Reproduce the old admin deletion's resulting state without its known
		// unexpected-port-deletion stack trace polluting this regression case.
		var/obj/docking_port/mobile/old_port = original.detach_shuttle()
		old_port.jumpToNullSpace()
		TEST_ASSERT(!QDELETED(original) && !original.abandoned && !original.shuttle, "The orphan fixture still has a hull or was abandoned")
		TEST_ASSERT_NULL(panel.rebuild_denial(captain, snapshot), "A hull-less overmap record blocks recovery")
		original.retired_by_checkpoint = TRUE
		TEST_ASSERT_NOTNULL(panel.rebuild_denial(captain, snapshot), "A retired hull-less record bypassed duplicate protection")
		original.retired_by_checkpoint = FALSE
		original.checkpoint_rebuilding = TRUE
		TEST_ASSERT_NOTNULL(panel.rebuild_denial(captain, snapshot), "A hull-less record bypassed concurrent recovery protection")
		original.checkpoint_rebuilding = FALSE
	else if(!destroy_original)
		original.abandon_ship(crash = FALSE)
		TEST_ASSERT_NULL(panel.rebuild_denial(captain, snapshot), "The registered captain cannot recover an abandoned hull")
	if(destroy_original)
		if(delete_via_admin)
			var/obj/docking_port/mobile/old_port = original.shuttle
			TEST_ASSERT(old_port.admin_delete_shuttle(escape = escape_on_delete), "The admin deletion was refused")
			TEST_ASSERT(QDELETED(old_port) && QDELETED(original), "Admin deletion left the hull or overmap ship alive")
			TEST_ASSERT(!(original in SSovermap.simulated_ships), "Admin deletion retained its fleet entry")
		else
			qdel(original)
		TEST_ASSERT(snapshot in home.checkpoints, "Deleting the original consumed its paid registration")
		old_balance = 0
		qdel(panel)
		captain.key = null
		captain = make_player(terminal_turf, "registrycaptain")
		panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
		TEST_ASSERT_NULL(panel.rebuild_denial(captain, snapshot), "A new body with the saved captain's key cannot recover a destroyed hull")
	var/list/recovery_data = panel.ui_data(captain)
	TEST_ASSERT_EQUAL(length(recovery_data["bays"]), 0, "An empty permanent bay was offered as a docked ship")
	TEST_ASSERT_EQUAL(length(recovery_data["blueprints"]), 1, "The terminal lost the captain's saved hull")
	var/list/saved_hull = recovery_data["blueprints"][1]
	TEST_ASSERT_NULL(saved_hull["denial"], "The recovery button remains disabled after losing the original")
	var/before_recovery_iron = silo.materials.get_material_amount(/datum/material/iron)
	if(!destroy_original)
		home.refuse_bay = TRUE
		TEST_ASSERT(!panel.rebuild(captain, snapshot), "A refused bay reservation reported a started rebuild")
		TEST_ASSERT(snapshot in home.checkpoints, "A refused rebuild consumed the registration")
		TEST_ASSERT(!snapshot.busy && !original.checkpoint_rebuilding && !original.retired_by_checkpoint, "A refused rebuild left a recovery or retirement lock")
		TEST_ASSERT_NULL(SSshuttle.preview_shuttle, "A refused rebuild leaked its preview ship")
		TEST_ASSERT_NULL(SSshuttle.preview_reservation, "A refused rebuild leaked its preview reservation")
		TEST_ASSERT_NULL(SSshuttle.active_template_load, "A refused rebuild locked the shuttle loader")
		TEST_ASSERT_EQUAL(original.ship_account.account_balance, old_balance, "A refused rebuild changed the original balance")
		TEST_ASSERT(bay.is_available(), "A refused rebuild retained the bay reservation")
		TEST_ASSERT_EQUAL(length(home.checkpoint_jobs), 0, "A refused rebuild left a job behind")
		home.refuse_bay = FALSE
	if(!destroy_original && !orphaned_original)
		// A hull back in service before the first piece stops the job with nothing built.
		TEST_ASSERT(panel.rebuild(captain, snapshot), "Could not start a reconstruction: [panel.error]")
		var/datum/checkpoint_construction/stopped = home.checkpoint_jobs[1]
		var/obj/docking_port/mobile/voidcrew/stopped_copy = stopped.port
		original.abandoned = FALSE
		stopped.fast_forward(1)
		original.abandoned = TRUE
		TEST_ASSERT(QDELETED(stopped) && !length(home.checkpoint_jobs), "A refused commitment left its job running")
		TEST_ASSERT(QDELETED(stopped_copy), "A refused commitment leaked its hidden copy")
		TEST_ASSERT((snapshot in home.checkpoints) && !snapshot.busy, "A rebuild stopped before its first piece consumed the checkpoint")
		TEST_ASSERT(!original.checkpoint_rebuilding && !original.retired_by_checkpoint, "A stopped rebuild kept a lock on the original")
		TEST_ASSERT(bay.is_available() && !bay.dock.get_docked(), "A stopped rebuild kept the bay")
		TEST_ASSERT_EQUAL(count_bay_ship_tiles(bay), 0, "A stopped rebuild left pieces in the bay")
		TEST_ASSERT_EQUAL(original.ship_account.account_balance, old_balance, "A stopped rebuild moved the original balance")
		TEST_ASSERT_NULL(SSshuttle.active_template_load, "A stopped rebuild locked the shuttle loader")
	panel.manual_jobs = manual_jobs
	prepare_captain(captain)
	TEST_ASSERT(panel.rebuild(captain, snapshot), "Rebuild failed: [panel.error]")
	TEST_ASSERT_EQUAL(length(home.checkpoint_jobs), 1, "Reconstruction did not create exactly one job")
	var/datum/checkpoint_construction/job = home.checkpoint_jobs[1]
	TEST_ASSERT_NULL(SSshuttle.preview_shuttle, "Reconstruction held the shared shuttle preview")
	TEST_ASSERT_NULL(SSshuttle.active_template_load, "Reconstruction held the shared shuttle loader")
	TEST_ASSERT(snapshot in home.checkpoints, "The checkpoint was consumed before the first piece")
	TEST_ASSERT(!bay.is_available(), "The bay was released while reconstruction owned it")
	TEST_ASSERT_EQUAL(count_bay_ship_tiles(bay), 0, "The hull appeared before construction started")
	TEST_ASSERT_EQUAL(length(job.markers), length(job.hull_indices), "Warning markers do not cover the hull footprint")
	TEST_ASSERT(!panel.rebuild(captain, snapshot), "A second click started another reconstruction")
	var/obj/docking_port/mobile/voidcrew/built_port = job.port
	captain = build_hull(job, home, bay, captain, original, panel, snapshot)
	if(!captain)
		return
	TEST_ASSERT(QDELETED(job), "Reconstruction did not finish")
	TEST_ASSERT_EQUAL(silo.materials.get_material_amount(/datum/material/iron), before_recovery_iron, "Rebuilding charged materials a second time")
	var/datum/outpost_berth/ship_bay/rebuilt_bay = home.bay_berths[1]
	TEST_ASSERT_EQUAL(rebuilt_bay, bay, "Recovery replaced the permanent bay")
	TEST_ASSERT_NULL(bay.rebuild_owner, "Successful recovery retained the build reservation")
	var/obj/structure/overmap/ship/rebuilt = rebuilt_bay.ship
	test_ships += rebuilt
	TEST_ASSERT_EQUAL(rebuilt.shuttle, built_port, "The rebuilt ship record does not own the hull that was built")
	TEST_ASSERT(rebuilt_bay.is_ship_present(), "Recovered ship is not physically docked")
	TEST_ASSERT(rebuilt.is_ship_captain(captain), "Recovered captain lacks command")
	TEST_ASSERT_EQUAL(rebuilt.ship_account.account_balance, old_balance, "Recovery minted money or lost the original account")
	if(orphaned_original)
		TEST_ASSERT(QDELETED(original), "Recovery retained the hull-less overmap record")
	else if(!destroy_original && !QDELETED(original))
		// A build that takes real time can outlast the retired hull: the derelict sweep removes it.
		TEST_ASSERT_EQUAL(original.ship_account.account_balance, 0, "The original kept its transferred balance")
		TEST_ASSERT(original.retired_by_checkpoint, "The original hull was not retired")
		TEST_ASSERT(!original.claim_abandoned_ship(visitor), "A retired hull can still be claimed")
	TEST_ASSERT_EQUAL(length(home.checkpoints), 0, "Successful recovery did not consume the registration")
	TEST_ASSERT(QDELETED(snapshot), "Consumed snapshot leaked")
	TEST_ASSERT(!panel.rebuild(captain, snapshot), "The consumed registration rebuilt twice")
	TEST_ASSERT_EQUAL(length(home.checkpoint_jobs), 0, "A finished reconstruction stayed listed")
	TEST_ASSERT_EQUAL(length(hull_owned_areas(rebuilt.shuttle)), room_count, "Recovery claimed padding or lost a room")
	for(var/area/room as anything in rebuilt.shuttle.shuttle_areas)
		for(var/z_level in 1 to length(room.turfs_by_zlevel))
			if(z_level != rebuilt.shuttle.z)
				TEST_ASSERT(!length(room.get_turfs_by_zlevel(z_level)), "[room] kept hidden construction tiles on z [z_level]")
	var/list/after_counts = count_hull(rebuilt.shuttle)
	for(var/type_name in count_adjustments)
		before_counts[type_name] += count_adjustments[type_name]
	for(var/type_name in (before_counts | after_counts))
		if(after_counts[type_name] != before_counts[type_name])
			TEST_FAIL("Hull infrastructure changed for [type_name]: expected [before_counts[type_name]], got [after_counts[type_name]]")
	for(var/turf/tile as anything in rebuilt.shuttle.return_turfs())
		if(!(get_area(tile) in rebuilt.shuttle.shuttle_areas))
			continue
		for(var/obj/structure/closet/storage in tile)
			storage.dump_contents() // First use must not spawn fresh default stock.
		for(var/obj/item/item in tile.get_all_contents())
			if(ismachinery(item.loc))
				var/obj/machinery/machine = item.loc
				if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship) && (istype(item, /obj/item/construction) || istype(item, /obj/item/pipe_dispenser) || istype(item, /obj/item/airlock_painter)))
					continue
				if((item in machine.component_parts) || istype(item, /obj/item/radio))
					continue
				if(istype(machine, /obj/machinery/power/apc))
					var/obj/machinery/power/apc/controller = machine
					if(item == controller.cell)
						continue
				if(istype(machine, /obj/machinery/atmospherics/components/unary/shuttle/heater))
					var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = machine
					if(item == heater.fuel_tank)
						continue
			if(istype(item, /obj/item/encryptionkey) && istype(item.loc, /obj/item/radio))
				continue
			TEST_FAIL("Rebuilt checkpoint contains a free item: [item.type], loc=[item.loc?.type], deleted=[QDELETED(item)]")
		for(var/obj/machinery/power/apc/controller in tile)
			TEST_ASSERT(controller.cell?.charge > controller.cell?.maxcharge * battery_floor(), "APC did not recover with a charged battery: [controller.cell?.charge]/[controller.cell?.maxcharge]")
		for(var/obj/machinery/power/smes/bank in tile)
			var/capacity = 0
			var/stored = 0
			for(var/obj/item/stock_parts/power_store/battery in bank.component_parts)
				capacity += battery.maxcharge
				stored += battery.charge
			TEST_ASSERT(capacity > 0 && stored > capacity * battery_floor(), "SMES did not recover charged batteries: [stored]/[capacity]")
			if(bank.terminal?.powernet && bank.powernet)
				TEST_ASSERT(bank.terminal.powernet != bank.powernet, "[bank] was rebuilt charging from its own output network")
		for(var/obj/machinery/autolathe/restored_lathe in tile)
			if(restored_lathe.name == "updated checkpoint fixture")
				TEST_ASSERT_EQUAL(restored_lathe.total_part_rating(/datum/stock_part/matter_bin), expected_bin_rating, "Recovery lost fitted upgrades")
			TEST_ASSERT_EQUAL(restored_lathe.materials.get_material_amount(/datum/material/iron), 0, "Recovery copied lathe stock")
		for(var/obj/machinery/computer/camera_advanced/base_construction/ship/restored_builder in tile)
			TEST_ASSERT_EQUAL(restored_builder.console_upgrades, expected_construction_upgrades, "Construction console lost its installed upgrades")
			TEST_ASSERT(!QDELETED(restored_builder.internal_rcd) && !QDELETED(restored_builder.internal_rtd) && !QDELETED(restored_builder.internal_rpd) && !QDELETED(restored_builder.internal_rld) && !QDELETED(restored_builder.internal_painter), "Construction console lost its internal tools")
			TEST_ASSERT_EQUAL(restored_builder.internal_rcd.matter, 0, "Construction console recovered free material charges")
			TEST_ASSERT_NULL(restored_builder.internal_painter.ink, "Construction console recovered a toner cartridge")
		for(var/obj/machinery/ore_silo/restored_silo in tile)
			TEST_ASSERT_EQUAL(restored_silo.materials.get_material_amount(/datum/material/iron), 0, "Recovery copied silo materials")
		for(var/obj/structure/reagent_dispensers/dispenser in tile)
			if(is_type_in_typecache(dispenser, GLOB.outpost_checkpoint_restocked))
				TEST_ASSERT(dispenser.reagents?.total_volume >= dispenser.reagents?.maximum_volume, "[dispenser] came back [dispenser.reagents?.total_volume]/[dispenser.reagents?.maximum_volume], not full")
			else
				TEST_ASSERT(!dispenser.reagents?.total_volume, "Recovery refilled [dispenser] with [dispenser.reagents?.total_volume] units")
		for(var/obj/structure/bedsheetbin/bin in tile)
			TEST_ASSERT_EQUAL(bin.amount, 0, "Recovery restocked a bedsheet bin")
		for(var/obj/machinery/vending/vendor in tile)
			for(var/datum/data/vending_product/product as anything in vendor.product_records + vendor.hidden_records + vendor.coin_records)
				TEST_ASSERT_EQUAL(product.amount, 0, "Recovery restocked a vendor")
		for(var/obj/machinery/atmospherics/machine in tile)
			for(var/datum/pipeline/network as anything in machine.return_pipenets())
				if(network && (breathes_ambient(network) || fed_by_restocked_tank(network)))
					continue
				TEST_ASSERT(!network?.air?.total_moles(), "Rebuilt pipe network at [machine] ([machine.type]) contains [network?.air?.total_moles()] moles of free gas")
		for(var/obj/machinery/atmospherics/components/tank/stored_tank in tile)
			if(is_type_in_typecache(stored_tank, GLOB.outpost_checkpoint_restocked))
				TEST_ASSERT(stored_tank.air_contents?.total_moles(), "Rebuilt [stored_tank] ([stored_tank.type]) came back empty")
			else
				TEST_ASSERT(!stored_tank.air_contents?.total_moles(), "Rebuilt [stored_tank] ([stored_tank.type]) was refilled with [stored_tank.air_contents?.total_moles()] moles")
	TEST_ASSERT(length(rebuilt.helm_consoles), "Recovered ship has no connected helm")
	// Decks take the hangar's air as they land; an airless tile would be a vacuum pocket in the bay.
	for(var/turf/open/deck in rebuilt.shuttle.return_turfs())
		if((get_area(deck) in rebuilt.shuttle.shuttle_areas) && !deck.blocks_air && !isspaceturf(deck))
			TEST_ASSERT(deck.air?.total_moles() > 0, "Rebuilt deck [deck.x],[deck.y] ([deck.type]) landed as a vacuum pocket in the bay")
	var/obj/machinery/cryopod/spawn_pod = locate() in rebuilt.shuttle.spawn_points
	TEST_ASSERT(spawn_pod && (get_area(spawn_pod) in rebuilt.shuttle.shuttle_areas), "Recovered ship has no cryopod spawn point")
	for(var/obj/machinery/computer/helm/helm as anything in rebuilt.helm_consoles)
		TEST_ASSERT_EQUAL(helm.current_ship, rebuilt, "Helm remained attached to the old ship")
		TEST_ASSERT(helm.powered(), "Recovered helm is unpowered")
	rebuilt.refresh_engines()
	var/thrust = 0
	for(var/obj/machinery/power/shuttle_engine/ship/engine in rebuilt.shuttle.engine_list)
		if(istype(engine, /obj/machinery/power/shuttle_engine/ship/liquid) || istype(engine, /obj/machinery/power/shuttle_engine/ship/fueled))
			TEST_ASSERT(engine_is_full(engine), "[engine] came back with [engine.return_fuel()] fuel, not full")
		thrust += engine.burn_engine(100, rebuilt.mass, 1)
	TEST_ASSERT(thrust > 0, "Recovered engines cannot produce thrust")
	var/obj/docking_port/stationary/transit/recovery_transit = SSshuttle.generate_transit_dock(rebuilt.shuttle)
	TEST_ASSERT_NOTNULL(recovery_transit, "Recovered hull has no transit destination")
	rebuilt.shuttle.mode = SHUTTLE_PREARRIVAL
	TEST_ASSERT_EQUAL(rebuilt.shuttle.initiate_docking(recovery_transit), DOCKING_SUCCESS, "Recovered hull cannot depart")
	rebuilt.shuttle.mode = SHUTTLE_IDLE
	rebuilt.docked = null
	rebuilt.forceMove(get_turf(home))
	rebuilt.state = "flying"
	home.on_ship_undock_complete(rebuilt)
	TEST_ASSERT_EQUAL(home.bay_berths[1], rebuilt_bay, "Recovered ship departure replaced the permanent bay")
	TEST_ASSERT(rebuilt_bay.has_ground() && rebuilt_bay.is_available(), "Recovered ship departure unloaded or retained its bay reservation")
	TEST_ASSERT_EQUAL(home.get_floor_alcove(rebuilt_bay.berth_number), rebuilt_bay.alcove_turfs, "Recovered ship departure removed elevator access")
	// The staged hull must leave exactly the floor it was built on.
	var/stranded = 0
	for(var/turf/tile as anything in bay_floor)
		var/list/floor = bay_floor[tile]
		if(tile.type != floor[1] || tile.loc != floor[2] || isshuttleturf(tile))
			stranded++
	TEST_ASSERT_EQUAL(stranded, 0, "The recovered hull left [stranded] tile(s) of itself in the bay after departure")

/datum/unit_test/voidcrew_checkpoints/staged/build_hull(datum/checkpoint_construction/job, obj/structure/overmap/dynamic/player_outpost/registry_test/home, datum/outpost_berth/ship_bay/bay, mob/living/carbon/human/captain, obj/structure/overmap/ship/original, datum/ship_checkpoint_ui/registry_test/panel, datum/ship_checkpoint/snapshot)
	check_bay_refuses_visitors(home, bay, "before the first piece")
	TEST_ASSERT_EQUAL(job.state, "marking", "Reconstruction skipped its survey markers")
	// The first visit consumes the checkpoint and moves the frame, then places one tile.
	job.fast_forward(1)
	TEST_ASSERT(job.committed, "The first piece was placed without consuming the checkpoint")
	TEST_ASSERT(QDELETED(snapshot) && !length(home.checkpoints), "The first piece did not consume the checkpoint")
	TEST_ASSERT(original.retired_by_checkpoint, "The first piece did not retire the original hull")
	TEST_ASSERT_EQUAL(bay.dock.get_docked(), job.port, "The hull frame did not take the bay")
	TEST_ASSERT(job.port in SSshuttle.mobile_docking_ports, "The hull frame was not registered")
	TEST_ASSERT_EQUAL(count_bay_ship_tiles(bay), 1, "The first visit placed more than one tile")
	TEST_ASSERT_EQUAL(count_bay_machines(bay), 0, "Machinery appeared with the first deck tile")
	var/datum/checkpoint_visit/first = job.completed_visits[1]
	var/area/first_room = get_area(job.bay_turfs[first.index])
	var/list/room_lighting = list(first_room.base_lighting_color, first_room.base_lighting_alpha)
	TEST_ASSERT(first_room.base_lighting_alpha >= 110, "The new deck was not floodlit: [first_room.base_lighting_alpha]")
	var/list/original_lighting = job.lit_rooms[first_room]
	TEST_ASSERT(!job.execute_visit(first), "A completed visit ran twice")
	TEST_ASSERT_EQUAL(job.visits_done, 1, "Replaying a visit counted it again")
	TEST_ASSERT(!panel.rebuild(captain, snapshot), "The consumed checkpoint started another reconstruction")
	check_bay_refuses_visitors(home, bay, "during construction")
	var/highest_stage = 1
	var/turf/broken_wall
	var/broken_wall_type
	var/lathe_removed = FALSE
	var/interrupted = FALSE
	while(job.state == "building")
		var/stage_before = job.stage
		job.fast_forward(1)
		if(QDELETED(job) || job.state != "building")
			break
		var/datum/checkpoint_visit/latest = job.completed_visits[length(job.completed_visits)]
		TEST_ASSERT(latest.stage >= highest_stage, "A stage [latest.stage] piece was placed after stage [highest_stage] began")
		highest_stage = max(highest_stage, latest.stage)
		if(job.stage == stage_before)
			continue
		switch(job.stage)
			if(2) // Hull: every deck tile down, and nothing standing on it yet.
				TEST_ASSERT_EQUAL(count_bay_walls(bay), 0, "Walls went up before the deck was finished")
				TEST_ASSERT_EQUAL(count_bay_machines(bay), 0, "Machinery appeared during the deck stage")
			if(3) // Systems: the hull is up. Break one finished wall; it must stay broken.
				TEST_ASSERT(count_bay_walls(bay) > 0, "The hull stage placed no walls")
				for(var/turf/closed/wall/wall in bay_turfs(bay))
					if(istype(wall.loc, /area/shuttle))
						broken_wall = wall
						break
				TEST_ASSERT_NOTNULL(broken_wall, "No finished wall to damage")
				broken_wall_type = broken_wall.type
				var/turf/scraped = broken_wall.ScrapeAway()
				count_adjustments["[broken_wall_type]"] -= 1
				count_adjustments["[scraped.type]"] += 1
			if(4) // Machinery: only infrastructure exists so far.
				TEST_ASSERT_EQUAL(count_bay_machines(bay), count_bay_infrastructure(bay), "Ordinary machinery appeared before its stage")
			if(5) // Fittings: remove a finished machine and interrupt the job part way.
				for(var/turf/tile as anything in bay_turfs(bay))
					for(var/obj/machinery/autolathe/fixture in tile)
						if(fixture.name == "updated checkpoint fixture")
							qdel(fixture)
							lathe_removed = TRUE
				count_adjustments["[/obj/machinery/autolathe]"] -= 1
				TEST_ASSERT(lathe_removed, "The upgraded fixture was never placed")
				// Losing the console, its panel and the captain must not stop or restart the job.
				qdel(panel)
				qdel(terminal)
				captain.death()
				qdel(job)
				TEST_ASSERT(!QDELETED(job), "An ordinary deletion stopped a reconstruction that had pieces")
				interrupted = TRUE
	TEST_ASSERT(interrupted, "The interruption point was never reached")
	// Finished, the hull is handed over at once, and it is still its captain's while they are dead
	TEST_ASSERT(QDELETED(job), "The finished hull was not handed over at once")
	TEST_ASSERT(original_lighting && room_lighting[2] != original_lighting[2], "The floodlit room recorded no lighting to restore")
	TEST_ASSERT(first_room.base_lighting_alpha == original_lighting[2] && first_room.base_lighting_color == original_lighting[1], "The finished hull kept the construction floodlights")
	TEST_ASSERT_NOTNULL(bay.ship, "The finished hull did not take the bay")
	TEST_ASSERT(!bay.ship.abandoned, "The finished hull was left to be claimed while its captain was only dead")
	TEST_ASSERT(!iswallturf(broken_wall), "A broken wall was rebuilt")
	for(var/turf/tile as anything in bay_turfs(bay))
		for(var/obj/machinery/autolathe/fixture in tile)
			TEST_ASSERT(fixture.name != "updated checkpoint fixture", "A removed machine was rebuilt")
	return captain

/datum/unit_test/voidcrew_checkpoints/proc/count_bay_infrastructure(datum/outpost_berth/ship_bay/bay)
	. = 0
	for(var/turf/tile as anything in bay_turfs(bay))
		if(!istype(tile.loc, /area/shuttle))
			continue
		for(var/obj/machinery/machine in tile)
			if(machine.checkpoint_type() && (is_type_in_typecache(machine, GLOB.outpost_checkpoint_infrastructure) || istype(machine, /obj/machinery/power/smes)))
				.++

/datum/unit_test/voidcrew_checkpoints/terminated/build_hull(datum/checkpoint_construction/job, obj/structure/overmap/dynamic/player_outpost/registry_test/home, datum/outpost_berth/ship_bay/bay, mob/living/carbon/human/captain, obj/structure/overmap/ship/original, datum/ship_checkpoint_ui/registry_test/panel, datum/ship_checkpoint/snapshot)
	job.fast_forward(40)
	TEST_ASSERT(job.committed && count_bay_ship_tiles(bay) > 0, "No pieces were placed before the bay was lost")
	var/datum/checkpoint_visit/placed = job.completed_visits[1]
	var/mob/living/carbon/human/bystander = make_player(job.bay_turfs[placed.index], "registrybystander")
	var/obj/docking_port/mobile/voidcrew/partial_port = job.port
	var/datum/outpost_zone/hidden_copy = job.source_zone
	TEST_ASSERT(hidden_copy?.is_held_by(job), "The hidden copy is not held in the outpost's shipyard")
	var/held = job.held_balance
	TEST_ASSERT(held > 0, "Commitment did not hold the original's account balance")
	qdel(bay)
	TEST_ASSERT(QDELETED(job), "Reconstruction outlived its bay")
	TEST_ASSERT(QDELETED(partial_port) && !(partial_port in SSshuttle.mobile_docking_ports), "The partial hull left a registered port behind")
	TEST_ASSERT(hidden_copy.state == "wiping" || hidden_copy.state == "vacant", "The hidden copy's shipyard outlived its job ([hidden_copy.state])")
	TEST_ASSERT(!length(home.checkpoints), "Losing the bay restored a consumed checkpoint")
	TEST_ASSERT(!original.retired_by_checkpoint && !original.checkpoint_rebuilding, "The original stayed replaced after its replacement was destroyed")
	TEST_ASSERT_EQUAL(original.ship_account.account_balance, held, "The original's balance was not returned")
	TEST_ASSERT(bystander.stat != DEAD && (get_turf(bystander) in home.get_floor_alcove(0)), "A player on the partial hull was not evacuated")
	return null

/datum/unit_test/voidcrew_checkpoints/drones/build_hull(datum/checkpoint_construction/job, obj/structure/overmap/dynamic/player_outpost/registry_test/home, datum/outpost_berth/ship_bay/bay, mob/living/carbon/human/captain, obj/structure/overmap/ship/original, datum/ship_checkpoint_ui/registry_test/panel, datum/ship_checkpoint/snapshot)
	TEST_ASSERT(length(job.drones) >= 8, "Reconstruction started with [length(job.drones)] drones")
	var/list/obj/effect/checkpoint_build_drone/fleet = job.drones.Copy()
	var/list/cradles = list()
	for(var/obj/effect/checkpoint_build_drone/drone as anything in fleet)
		var/obj/structure/checkpoint_drone_bay/cradle = drone.cradle_ref?.resolve()
		TEST_ASSERT(cradle && get_turf(drone) == get_turf(cradle), "A drone did not launch from a drone bay")
		cradles |= cradle
	TEST_ASSERT_EQUAL(length(cradles), 4, "Drones did not use all four corner drone bays")
	var/started_at = world.time
	var/deadline = world.time + 30 SECONDS
	while(!QDELETED(job) && job.visits_done < 40 && world.time < deadline)
		sleep(1)
	TEST_ASSERT(!QDELETED(job) && job.committed, "The drones never consumed the checkpoint")
	TEST_ASSERT(job.visits_done >= 40, "The drones placed [job.visits_done] visits in 30 seconds")
	TEST_ASSERT(count_bay_ship_tiles(bay) > 0 && count_bay_ship_tiles(bay) < length(job.hull_indices), "The drone build was not partial part way through")
	// Let the real controller finish and hand over on its own.
	var/total_visits = job.visit_total
	var/list/copy_turfs = job.get_source_block()
	deadline = world.time + 5 MINUTES
	// Placing pieces must not keep the pressurised hangar's air awake.
	var/list/peaks = list()
	var/list/sums = list()
	var/list/stage_samples = list()
	while(!QDELETED(job) && world.time < deadline)
		sleep(5)
		if(QDELETED(job))
			break
		var/stage = job.stage_name()
		var/list/counts = list("bay deck ([stage])" = 0, "bay ship ([stage])" = 0)
		for(var/turf/open/active as anything in SSair.active_turfs)
			if(bay.contains_turf(active))
				counts[(get_area(active) in job.port?.shuttle_areas) ? "bay ship ([stage])" : "bay deck ([stage])"]++
		for(var/key in counts)
			peaks[key] = max(peaks[key], counts[key])
			sums[key] += counts[key]
			stage_samples[key]++
	TEST_ASSERT(QDELETED(job), "The drones did not finish [total_visits] visits within five minutes")
	// Releasing the hidden copy's space must not leave its job spawns behind for the next user.
	TEST_ASSERT(outpost_zone_wait_vacant(home.level_zone("yard")), "The shipyard was never cleared after the build")
	for(var/turf/tile as anything in copy_turfs)
		var/obj/effect/landmark/stray = locate() in tile
		if(stray)
			TEST_FAIL("The hidden copy left [stray.type] at [tile.x],[tile.y]")
			break
	var/list/report = list()
	for(var/key in peaks)
		var/mean = round(sums[key] / stage_samples[key])
		report += "[key] peak [peaks[key]] mean [mean]"
		// The bay resets its air before a build, so placing pieces leaves little to settle.
		TEST_ASSERT(mean <= 300, "The hangar stayed busy with atmos while building: [key] averaged [mean] active turfs")
	log_test("Drone reconstruction placed [total_visits] visits in [(world.time - started_at) / 10] seconds, including the survey. Active air turfs while building: [report.Join("; ")].")
	// Released drones fly back to their own bays and dock there.
	deadline = world.time + 30 SECONDS
	var/docked = FALSE
	while(!docked && world.time < deadline)
		docked = TRUE
		for(var/obj/effect/checkpoint_build_drone/drone as anything in fleet)
			if(!QDELETED(drone))
				docked = FALSE
				TEST_ASSERT(drone.returning_until, "A drone outlived the job without being sent home")
		if(!docked)
			sleep(2)
	TEST_ASSERT(docked, "Drones did not return to their drone bays after the build")
	return captain

/// The grid is live from the Systems stage on, so the rest of the build runs on the SMES.
/// A Box drew about 4% of it by handover.
/datum/unit_test/voidcrew_checkpoints/drones/battery_floor()
	return 0.9

/// An open outlet on an unfinished hull equalises with the hangar during a real-time build.
/datum/unit_test/voidcrew_checkpoints/drones/breathes_ambient(datum/pipeline/network)
	for(var/obj/machinery/atmospherics/components/unary/passive_vent/outlet in network.other_atmos_machines)
		return TRUE
	return FALSE

/datum/unit_test/voidcrew_checkpoints/unclaimed/prepare_captain(mob/living/carbon/human/captain)
	var/obj/item/card/id/id = allocate(/obj/item/card/id)
	personal = allocate(/datum/bank_account, "Checkpoint captain", null, 1, FALSE)
	id.registered_account = personal
	TEST_ASSERT(captain.put_in_active_hand(id), "The captain could not hold their ID")

/datum/unit_test/voidcrew_checkpoints/unclaimed/build_hull(datum/checkpoint_construction/job, obj/structure/overmap/dynamic/player_outpost/registry_test/home, datum/outpost_berth/ship_bay/bay, mob/living/carbon/human/captain, obj/structure/overmap/ship/original, datum/ship_checkpoint_ui/registry_test/panel, datum/ship_checkpoint/snapshot)
	var/before_personal = personal.account_balance
	captain.key = null
	// Nobody holds the captain's key: finished, the hull is handed over at once to be claimed
	var/steps = 0
	while(!QDELETED(job) && !job.committed && steps++ < 50)
		job.fast_forward(1)
	var/held = job.held_balance
	TEST_ASSERT(held > 0, "Commitment did not hold the original's balance")
	job.fast_forward()
	TEST_ASSERT(QDELETED(job), "The unclaimed reconstruction did not finish")
	var/obj/structure/overmap/ship/rebuilt = bay.ship
	TEST_ASSERT_NOTNULL(rebuilt, "The unclaimed hull did not take the bay")
	test_ships += rebuilt
	TEST_ASSERT_NULL(bay.rebuild_owner, "The unclaimed hull kept the build reservation")
	TEST_ASSERT(rebuilt.abandoned, "The unclaimed hull cannot be claimed at its helm")
	TEST_ASSERT_EQUAL(rebuilt.ship_account.account_balance, 0, "The old ship's money went to whoever claims the hull")
	TEST_ASSERT_EQUAL(personal.account_balance - before_personal, held, "The old ship's money did not return to its captain")
	return null
