/**
 * Outposts are safe hubs: ship weapons never target one, player-owned or trader, and no trader
 * outpost map rolls hostile creatures inside itself.
 */

/// Neither a player outpost nor a trader outpost is a ship combat target, and a weapons console will not lock onto either
/datum/unit_test/voidcrew_outpost_not_combat_target
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_not_combat_target/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("notcombattargetowner")
	TEST_ASSERT_NOTNULL(home, "The test outpost did not load")
	var/obj/structure/overmap/trader_outpost/market = allocate(/obj/structure/overmap/trader_outpost/general)
	var/obj/machinery/computer/camera_advanced/ship_combat/console = allocate(/obj/machinery/computer/camera_advanced/ship_combat, run_loc_floor_bottom_left)

	// The two made here, and every outpost the round itself spawned
	var/list/outposts = list(home, market)
	outposts |= GLOB.player_outposts
	outposts |= GLOB.trader_outposts
	for(var/obj/structure/overmap/outpost in outposts)
		TEST_ASSERT(!outpost.is_combat_targetable(), "[outpost] ([outpost.type]) is a ship combat target")
		TEST_ASSERT(!console.start_targeting(outpost), "A weapons console started a lock on [outpost] ([outpost.type])")
		TEST_ASSERT(!console.set_target_ship(outpost), "A weapons console accepted [outpost] ([outpost.type]) as a target")
		TEST_ASSERT_NULL(console.targeting_ship, "A weapons console is locking onto [outpost] ([outpost.type])")
		TEST_ASSERT_NULL(console.target_ship, "A weapons console holds a lock on [outpost] ([outpost.type])")
		TEST_ASSERT(!console.is_targeting, "A weapons console is acquiring a lock after refusing [outpost] ([outpost.type])")

/// No trader outpost map places a zone mob marker or a mob spawner: those roll hostiles after the load, inside a safe hub
/datum/unit_test/voidcrew_trader_outpost_no_hostile_spawners

/datum/unit_test/voidcrew_trader_outpost_no_hostile_spawners/Run()
	var/static/list/banned_paths = list(
		"/obj/effect/zone_mobs",
		"/obj/structure/spawner",
	)
	var/checked = 0
	for(var/datum/map_template/trader_outpost/template_path as anything in subtypesof(/datum/map_template/trader_outpost))
		var/map_path = initial(template_path.mappath)
		if(!map_path)
			continue
		var/text = file2text(map_path)
		TEST_ASSERT(length(text), "[template_path] points at [map_path], which could not be read")
		checked++
		for(var/banned in banned_paths)
			if(findtext(text, banned))
				TEST_FAIL("[map_path] ([template_path]) places [banned], which spawns hostiles inside a trader outpost")
	TEST_ASSERT(checked, "No trader outpost map was checked")

/// A small reserved concourse exercises the real linking pass without loading a whole market.
/datum/unit_test/voidcrew_trader_checkpoint
	abstract_type = /datum/unit_test/voidcrew_trader_checkpoint
	var/obj/structure/overmap/trader_outpost/host
	var/obj/machinery/door/airlock/outpost/checkpoint/door
	var/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/scanner
	var/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/other_scanner
	var/mob/living/carbon/human/actor
	var/clean_signals = 0
	var/alarm_signals = 0

/datum/unit_test/voidcrew_trader_checkpoint/proc/fixture()
	host = allocate(/obj/structure/overmap/trader_outpost/general)
	host.outpost_template = new /datum/map_template/trader_outpost
	host.outpost_template.width = 7
	host.outpost_template.height = 5
	host.reservation = SSmapping.request_turf_block_reservation(7, 5, 1)
	TEST_ASSERT_NOTNULL(host.reservation, "Could not reserve the checkpoint fixture")
	host.template_bottom_left = host.reservation.bottom_left_turfs[1]
	var/turf/origin = host.template_bottom_left
	for(var/turf/tile as anything in host.reservation.reserved_turfs)
		tile.ChangeTurf(/turf/open/indestructible)
	door = allocate(/obj/machinery/door/airlock/outpost/checkpoint, locate(origin.x + 3, origin.y + 2, origin.z))
	door.checkpoint_id = "test_checkpoint"
	door.set_machine_stat(NONE)
	scanner = allocate(/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint, get_step(door, WEST))
	scanner.checkpoint_id = door.checkpoint_id
	scanner.set_machine_stat(NONE)
	other_scanner = allocate(/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint, get_step(door, EAST))
	other_scanner.checkpoint_id = door.checkpoint_id
	other_scanner.set_machine_stat(NONE)
	host.link_interior_machinery()
	scanner.set_machine_stat(NOPOWER)
	actor = allocate(/mob/living/carbon/human, get_turf(scanner))
	scanner.set_machine_stat(NONE)
	RegisterSignal(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, PROC_REF(clean_signal))
	RegisterSignal(scanner, COMSIG_SCANGATE_PASS_TRIGGER, PROC_REF(alarm_signal))
	TEST_ASSERT_EQUAL(length(door.checkpoint_scanners), 2, "The checkpoint did not link both scanners")
	return TRUE

/// Move the actor without also exercising the automatic turf-entry scan.
/datum/unit_test/voidcrew_trader_checkpoint/proc/move_actor(turf/destination)
	var/old_stat = scanner.machine_stat
	var/other_stat = other_scanner.machine_stat
	scanner.set_machine_stat(NOPOWER)
	other_scanner.set_machine_stat(NOPOWER)
	actor.forceMove(destination)
	scanner.set_machine_stat(old_stat)
	other_scanner.set_machine_stat(other_stat)

/datum/unit_test/voidcrew_trader_checkpoint/proc/clean_signal(datum/source, atom/movable/thing)
	SIGNAL_HANDLER
	clean_signals++

/datum/unit_test/voidcrew_trader_checkpoint/proc/alarm_signal(datum/source, atom/movable/thing)
	SIGNAL_HANDLER
	alarm_signals++

/datum/unit_test/voidcrew_trader_checkpoint/signals/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_TRIGGER, actor)
	TEST_ASSERT(door.density && !door.operating, "An alarm opened the checkpoint")
	var/obj/item/coin/coin = allocate(/obj/item/coin)
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, coin)
	TEST_ASSERT(door.density && !door.operating, "A clean item opened the checkpoint")
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	TEST_ASSERT(door.operating, "A clean living scan did not immediately start opening")
	sleep(2 SECONDS)
	TEST_ASSERT(!door.density, "A clean scan did not open the checkpoint")
	TEST_ASSERT(door.close(), "The checkpoint could not close after a clean scan")
	TEST_ASSERT(!door.open(), "A prior clean result was reusable")
	move_actor(get_turf(other_scanner))
	SEND_SIGNAL(other_scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	sleep(2 SECONDS)
	TEST_ASSERT(!door.density, "The opposite scanner did not open the checkpoint")
	TEST_ASSERT(door.autoclose && door.safe, "Checkpoint lost normal autoclose or safety")
	// Wait for the inherited timer, with nobody on the doorway.
	sleep(10 SECONDS)
	TEST_ASSERT(door.density && !door.operating, "Checkpoint did not autoclose")
	TEST_ASSERT(!door.open(), "Autoclose left a reusable scan permission")

/datum/unit_test/voidcrew_trader_checkpoint/opening_routes/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	for(var/force_type in list(DEFAULT_DOOR_CHECKS, FORCING_DOOR_CHECKS, BYPASS_DOOR_CHECKS))
		TEST_ASSERT(!door.open(force_type), "Direct open([force_type]) bypassed the scanner")
	door.bumpopen(actor)
	TEST_ASSERT(door.density && !door.operating, "Bump-open bypassed the scanner")
	actor.last_bumped = 0
	door.Bumped(actor)
	TEST_ASSERT(door.density && !door.operating, "Living Bumped bypassed the scanner")
	door.attack_hand(actor, list())
	TEST_ASSERT(door.density && !door.operating, "Hand activation bypassed the scanner")
	door.try_to_activate_door(actor)
	TEST_ASSERT(door.density && !door.operating, "Ordinary activation bypassed the scanner")
	door.try_to_activate_door(actor, TRUE)
	TEST_ASSERT(door.density && !door.operating, "Access-bypass activation bypassed the scanner")
	var/obj/item/card/id/advanced/id = allocate(/obj/item/card/id/advanced)
	id.access = list(ACCESS_WEAPONS, ACCESS_SECURITY)
	door.attackby(id, actor, list(), list())
	TEST_ASSERT(door.density && !door.operating, "An ID swipe bypassed the scanner")
	door.Bumped(id)
	TEST_ASSERT(door.density && !door.operating, "A thrown ID bypassed the scanner")
	door.emergency = TRUE
	door.unres_sides = ALL_CARDINALS
	door.try_to_activate_door(actor)
	TEST_ASSERT(door.density && !door.operating, "Emergency access or unrestricted sides bypassed the scanner")
	door.wires.on_pulse(WIRE_OPEN)
	door.on_magic_unlock(get_turf(door), null, actor)
	door.prison_open()
	TEST_ASSERT(door.density && !door.operating, "Wire, magic, or prison opening bypassed the scanner")
	door.unbolt()
	door.attack_ai(actor)
	TEST_ASSERT(door.density && !door.operating, "Silicon control bypassed the scanner")
	// Exercise the actual control-wand and silicon toggle routes with their own checks satisfied.
	var/obj/item/door_remote/omni/remote = allocate(/obj/item/door_remote/omni)
	door.opens_with_door_remote = TRUE
	door.aiControlDisabled = AI_WIRE_NORMAL
	remote.ranged_interact_with_atom(door, actor, list())
	TEST_ASSERT(door.density && !door.operating, "A control wand bypassed the scanner")
	var/mob/living/silicon/robot/robot = allocate(/mob/living/silicon/robot)
	door.user_toggle_open(robot)
	TEST_ASSERT(door.density && !door.operating, "A silicon UI toggle bypassed the scanner")
	// A power-free pry takes the same BYPASS route used by tools, aliens and mechs.
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	door.set_machine_stat(NOPOWER)
	door.try_to_crowbar(crowbar, actor)
	TEST_ASSERT(door.density && !door.operating, "An unpowered crowbar bypassed the scanner")
	door.set_machine_stat(NONE)
	door.finish_emag_act()
	TEST_ASSERT(door.density && !door.operating, "Emag opening bypassed the scanner")
	// These security state changes never create a stored clean result.
	door.obj_flags &= ~EMAGGED
	door.unbolt()
	TEST_ASSERT(!door.open(BYPASS_DOOR_CHECKS), "Clearing an emag created permission")

/datum/unit_test/voidcrew_trader_checkpoint/guns/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, actor)
	var/obj/item/storage/box/box = allocate(/obj/item/storage/box, bag)
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol, box)
	scanner.perform_scan(actor)
	TEST_ASSERT_EQUAL(alarm_signals, 1, "A nested gun did not trigger the scanner")
	TEST_ASSERT_EQUAL(clean_signals, 0, "A nested gun produced a clean scan")
	ADD_TRAIT(actor, TRAIT_MINDSHIELD, TRAIT_GENERIC)
	scanner.perform_scan(actor)
	TEST_ASSERT_EQUAL(alarm_signals, 2, "Mindshield exempted an armed human")
	REMOVE_TRAIT(actor, TRAIT_MINDSHIELD, TRAIT_GENERIC)
	var/obj/item/card/id/advanced/id = allocate(/obj/item/card/id/advanced)
	id.access = list(ACCESS_WEAPONS)
	actor.equip_to_slot_or_del(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING)
	actor.equip_to_slot_or_del(id, ITEM_SLOT_ID)
	TEST_ASSERT_EQUAL(actor.get_idcard(FALSE), id, "Weapon-access ID was not equipped")
	scanner.perform_scan(actor)
	TEST_ASSERT_EQUAL(alarm_signals, 3, "Weapon-access ID exempted an armed human")
	ADD_TRAIT(actor, TRAIT_MINDSHIELD, TRAIT_GENERIC)
	scanner.perform_scan(actor)
	TEST_ASSERT_EQUAL(alarm_signals, 4, "Combined exemptions let a gun pass")
	TEST_ASSERT(door.density && !door.operating, "An armed actor opened the checkpoint")
	// The upstream scanner still has its own exemptions; this change is confined to our subtype.
	var/obj/machinery/scanner_gate/preset_guns/upstream = allocate(/obj/machinery/scanner_gate/preset_guns, get_step(other_scanner, NORTH))
	upstream.base_false_beep = 0
	RegisterSignal(upstream, COMSIG_SCANGATE_PASS_NO_TRIGGER, PROC_REF(clean_signal))
	upstream.perform_scan(actor)
	TEST_ASSERT_EQUAL(clean_signals, 1, "Upstream Guns-mode exemptions changed")
	// Contraband-blocking containers keep tg's shielding semantics.
	ADD_TRAIT(bag, TRAIT_CONTRABAND_BLOCKER, TRAIT_GENERIC)
	scanner.perform_scan(actor)
	TEST_ASSERT_EQUAL(clean_signals, 2, "Contraband-blocking storage lost tg shielding")
	sleep(2 SECONDS)
	TEST_ASSERT(!door.density, "A tg-shielded inventory was not clean")
	TEST_ASSERT(door.close(), "Could not close the checkpoint after a shielded scan")
	REMOVE_TRAIT(bag, TRAIT_CONTRABAND_BLOCKER, TRAIT_GENERIC)
	gun.forceMove(get_step(scanner, NORTH))
	scanner.perform_scan(gun)
	TEST_ASSERT_EQUAL(alarm_signals, 5, "A loose gun was not detected")
	box.forceMove(get_step(scanner, NORTH))
	gun.forceMove(box)
	scanner.perform_scan(box)
	TEST_ASSERT_EQUAL(alarm_signals, 6, "A gun in a nonhuman container was not detected")
	TEST_ASSERT(door.density && !door.operating, "Scanning an object opened the checkpoint")
	TEST_ASSERT_EQUAL(scanner.base_false_beep, 0, "Checkpoint has random false results")
	TEST_ASSERT(scanner.locked, "Checkpoint configuration starts unlocked")
	scanner.attackby(id, actor, list(), list())
	scanner.emag_act(actor, null)
	scanner.ui_act("toggle_lock", list(), null, null)
	scanner.ui_act("set_mode", list("new_mode" = "Off"), null, null)
	scanner.ui_act("toggle_reverse", list(), null, null)
	TEST_ASSERT(scanner.locked && !scanner.reverse && scanner.scangate_mode == "Guns", "Checkpoint configuration could be changed")
	// Repeated scans must be deterministic, including when higher-tier parts change the modifier.
	scanner.minus_false_beep = 5
	for(var/i in 1 to 20)
		scanner.perform_scan(actor)
	TEST_ASSERT_EQUAL(alarm_signals, 6, "An unarmed scan randomly alarmed")
	TEST_ASSERT_EQUAL(clean_signals, 22, "An unarmed scan randomly failed")

/datum/unit_test/voidcrew_trader_checkpoint/unavailable/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	for(var/bad_stat in list(BROKEN, NOPOWER, BROKEN | NOPOWER))
		scanner.set_machine_stat(bad_stat)
		scanner.auto_scan(actor)
		scanner.perform_scan(actor)
		SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
		TEST_ASSERT(door.density && !door.operating, "A scanner with status [bad_stat] granted entry")
	scanner.set_machine_stat(NONE)
	scanner.panel_open = TRUE
	scanner.auto_scan(actor)
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	TEST_ASSERT(door.density && !door.operating, "An open-panel scanner granted entry")
	scanner.panel_open = FALSE
	scanner.set_anchored(FALSE)
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	TEST_ASSERT(door.density && !door.operating, "An unanchored scanner granted entry")
	scanner.set_anchored(TRUE)
	door.unlink_scanner(scanner)
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	TEST_ASSERT(door.density && !door.operating, "An unlinked scanner granted entry")
	TEST_ASSERT_EQUAL(length(door.checkpoint_scanners), 1, "Unlink left a scanner reference")
	TEST_ASSERT(door.link_scanner(scanner), "Could not relink the scanner")
	move_actor(get_step(scanner, NORTH))
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	TEST_ASSERT(door.density && !door.operating, "A remote actor granted entry")
	move_actor(get_turf(scanner))
	scanner.checkpoint_id = "wrong_checkpoint"
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	TEST_ASSERT(door.density && !door.operating, "A changed scanner ID granted entry")
	scanner.checkpoint_id = door.checkpoint_id
	qdel(scanner)
	TEST_ASSERT_EQUAL(length(door.checkpoint_scanners), 1, "Deleted scanner stayed linked")
	scanner = allocate(/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint, get_step(door, WEST))
	scanner.checkpoint_id = door.checkpoint_id
	scanner.set_machine_stat(NONE)
	TEST_ASSERT_NULL(scanner.checkpoint_door, "Rebuilt scanner inherited a link")
	TEST_ASSERT(!door.open(), "Rebuilding granted entry")
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	TEST_ASSERT(door.density && !door.operating, "A rebuilt, unlinked scanner granted entry")
	TEST_ASSERT(door.link_scanner(scanner), "Rebuilt scanner could not be deliberately linked")
	qdel(door)
	TEST_ASSERT_NULL(scanner.checkpoint_door, "Deleted door left a scanner link")
	door = allocate(/obj/machinery/door/airlock/outpost/checkpoint, get_step(scanner, EAST))
	door.checkpoint_id = scanner.checkpoint_id
	TEST_ASSERT(!door.open(), "Rebuilt door inherited permission")

/datum/unit_test/voidcrew_trader_checkpoint/reservation_scope/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/obj/structure/overmap/trader_outpost/other_host = allocate(/obj/structure/overmap/trader_outpost/general)
	other_host.outpost_template = new /datum/map_template/trader_outpost
	other_host.outpost_template.width = 3
	other_host.outpost_template.height = 3
	other_host.reservation = SSmapping.request_turf_block_reservation(3, 3, 1, host.template_bottom_left.z)
	TEST_ASSERT_NOTNULL(other_host.reservation, "Could not reserve the other concourse")
	other_host.template_bottom_left = other_host.reservation.bottom_left_turfs[1]
	var/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/foreign = allocate(/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint, other_host.template_bottom_left)
	foreign.checkpoint_id = door.checkpoint_id
	other_host.link_interior_machinery()
	host.link_interior_machinery()
	TEST_ASSERT_NULL(foreign.checkpoint_door, "A matching ID linked across reservations")
	TEST_ASSERT(!door.link_scanner(foreign), "Direct linking crossed reservation boundaries")
	TEST_ASSERT_EQUAL(length(door.checkpoint_scanners), 2, "Relinking duplicated the local circuit")
	TEST_ASSERT_EQUAL(host.template_bottom_left.z, other_host.template_bottom_left.z, "Scope fixture did not exercise a shared z-level")
	move_actor(get_turf(scanner))
	SEND_SIGNAL(foreign, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	TEST_ASSERT(door.density && !door.operating, "A foreign scanner opened this outpost's door")

/datum/unit_test/voidcrew_trader_checkpoint/obstruction_safety/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	SEND_SIGNAL(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, actor)
	sleep(2 SECONDS)
	TEST_ASSERT(!door.density, "The safety fixture never opened")
	move_actor(get_turf(door))
	TEST_ASSERT(!door.close(), "Checkpoint closed on a dense obstruction")
	TEST_ASSERT(!door.density, "Checkpoint obstructed a living actor")
	move_actor(get_turf(scanner))
	TEST_ASSERT(door.close(), "Checkpoint could not close after the obstruction moved")
	// Simulate an actor arriving in the closing animation: inherited CheckForMobs must reopen.
	move_actor(get_turf(door))
	door.CheckForMobs()
	TEST_ASSERT(!door.density, "Checkpoint safety could not reopen without a scan")
	move_actor(get_turf(scanner))
	TEST_ASSERT(door.close(), "Safety reopen prevented later closing")
	TEST_ASSERT(!door.open(), "Safety reopen left permission for an ordinary opening")

/// Load all three templates and verify the six actual linked circuits, alcoves and approaches.
/datum/unit_test/voidcrew_trader_checkpoint_maps/Run()
	var/list/circuits = list(
		/obj/structure/overmap/trader_outpost/general = list(list(38, 34, NORTH, 37, 31)),
		/obj/structure/overmap/trader_outpost/outfitter = list(list(15, 10, NORTH, 14, 7), list(13, 30, EAST), list(36, 8, EAST)),
		/obj/structure/overmap/trader_outpost/black_market = list(list(29, 7, EAST, 30, 6), list(34, 18, EAST)),
	)
	var/checked = 0
	for(var/host_type in circuits)
		var/obj/structure/overmap/trader_outpost/market = allocate(host_type)
		TEST_ASSERT(market.load_level(), "Could not load [host_type]")
		var/turf/origin = market.template_bottom_left
		var/list/restored_fixtures = list()
		var/expected_door_type = /obj/machinery/door/airlock/outpost/checkpoint/glass
		var/obj/machinery/door/airlock/style_type = /obj/machinery/door/airlock/public/glass
		if(host_type == /obj/structure/overmap/trader_outpost/general)
			restored_fixtures = list(
				list(36, 29, /obj/machinery/light/floor),
				list(40, 29, /obj/machinery/light/floor),
				list(36, 35, /obj/machinery/light/floor),
				list(40, 35, /obj/machinery/light/floor),
				list(38, 30, /obj/structure/table/reinforced),
			)
		else if(host_type == /obj/structure/overmap/trader_outpost/black_market)
			expected_door_type = /obj/machinery/door/airlock/outpost/checkpoint/grunge
			style_type = /obj/machinery/door/airlock/centcom
			restored_fixtures = list(
				list(28, 6, /obj/item/radio/intercom/directional/south),
				list(28, 6, /obj/machinery/light/red/directional/south),
				list(28, 8, /obj/machinery/newscaster/directional/north),
			)
		for(var/list/fixture as anything in restored_fixtures)
			var/turf/fixture_turf = locate(origin.x + fixture[1] - 1, origin.y + fixture[2] - 1, origin.z)
			var/obj/restored = locate(fixture[3]) in fixture_turf
			TEST_ASSERT_NOTNULL(restored, "[host_type] lost [fixture[3]] beside its elevator")
		var/list/entries = circuits[host_type]
		for(var/list/entry as anything in entries)
			var/turf/door_turf = locate(origin.x + entry[1] - 1, origin.y + entry[2] - 1, origin.z)
			var/obj/machinery/door/airlock/outpost/checkpoint/checkpoint = locate() in door_turf
			TEST_ASSERT_NOTNULL(checkpoint, "[host_type] is missing its checkpoint at [entry[1]],[entry[2]]")
			TEST_ASSERT_EQUAL(checkpoint.type, expected_door_type, "Mapped checkpoint lost its interior door style")
			TEST_ASSERT_EQUAL(checkpoint.icon, initial(style_type.icon), "Mapped checkpoint has the wrong door sprite")
			TEST_ASSERT_EQUAL(checkpoint.overlays_file, initial(style_type.overlays_file), "Mapped checkpoint has the wrong door overlays")
			TEST_ASSERT_EQUAL(checkpoint.glass, initial(style_type.glass), "Mapped checkpoint has the wrong glazing")
			TEST_ASSERT_EQUAL(checkpoint.outpost, market, "Mapped checkpoint linked to the wrong host")
			TEST_ASSERT_EQUAL(length(checkpoint.checkpoint_scanners), 2, "Mapped checkpoint does not have two scanners")
			TEST_ASSERT(HAS_TRAIT(checkpoint, "outpost_property"), "Mapped checkpoint lost property protection")
			for(var/direction in list(entry[3], turn(entry[3], 180)))
				var/turf/approach = get_step(door_turf, direction)
				TEST_ASSERT(isopenturf(approach), "Mapped checkpoint has a closed approach")
				var/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/gate = locate() in approach
				TEST_ASSERT_NOTNULL(gate, "Mapped checkpoint is missing an approach scanner")
				TEST_ASSERT(gate in checkpoint.checkpoint_scanners, "Mapped approach scanner is not in the circuit")
				TEST_ASSERT_EQUAL(gate.checkpoint_door?.resolve(), checkpoint, "Mapped scanner points at the wrong door")
				TEST_ASSERT(HAS_TRAIT(gate, "outpost_property"), "Mapped scanner lost property protection")
				TEST_ASSERT(gate.anchored, "Mapped scanner can travel with the elevator")
				for(var/atom/movable/blocker in approach)
					TEST_ASSERT(!blocker.density, "[blocker] blocks a checkpoint approach")
				// Equip the rider before permitting the automatic turf-entry scan.
				var/old_stat = gate.machine_stat
				gate.set_machine_stat(NOPOWER)
				var/mob/living/carbon/human/rider = allocate(/mob/living/carbon/human, approach)
				var/obj/item/gun/weapon = allocate(/obj/item/gun/ballistic/automatic/pistol, rider)
				gate.set_machine_stat(old_stat)
				gate.perform_scan(rider)
				TEST_ASSERT(checkpoint.density && !checkpoint.operating, "A styled checkpoint admitted an armed rider")
				qdel(weapon)
				gate.perform_scan(rider)
				sleep(2 SECONDS)
				TEST_ASSERT(!checkpoint.density, "A mapped circuit did not open from direction [direction]")
				qdel(rider)
				TEST_ASSERT(checkpoint.close(), "A mapped checkpoint could not close")
				TEST_ASSERT(!checkpoint.open(), "A mapped checkpoint cached a scan")
			if(length(entry) >= 5)
				TEST_ASSERT_EQUAL(length(market.lobby_alcove_turfs), 9, "Elevator lost a landing tile")
				var/index = 0
				for(var/y_offset in 0 to 2)
					for(var/x_offset in 0 to 2)
						var/turf/landing = locate(origin.x + entry[4] + x_offset - 1, origin.y + entry[5] + y_offset - 1, origin.z)
						TEST_ASSERT_EQUAL(market.lobby_alcove_turfs[++index], landing, "Elevator landing order changed")
						TEST_ASSERT(isopenturf(landing), "Elevator landing was walled over")
						for(var/atom/movable/blocker in landing)
							TEST_ASSERT(!blocker.density, "[blocker] blocks an elevator landing")
				TEST_ASSERT_EQUAL(length(market.lobby_panels), 1, "Elevator panel disappeared")
				var/obj/machinery/outpost_elevator/panel = market.lobby_panels[1]
				TEST_ASSERT_EQUAL(panel.get_own_alcove(), market.lobby_alcove_turfs, "Elevator panel lost its ordered landing")
				TEST_ASSERT(get_turf(panel) in market.lobby_alcove_turfs, "Elevator panel cannot be reached from its landing")
				check_elevator_travel(market, panel)
			checked++
	TEST_ASSERT_EQUAL(checked, 6, "Did not check all six trader entrances")

/// Move nine passengers down and back through the real elevator proc, retaining their tile order.
/datum/unit_test/voidcrew_trader_checkpoint_maps/proc/check_elevator_travel(obj/structure/overmap/trader_outpost/market, obj/machinery/outpost_elevator/lobby_panel)
	var/datum/outpost_berth/berth = new(market, 1, null)
	market.berths[1] = berth
	berth.reservation = SSmapping.request_turf_block_reservation(3, 3, 1)
	TEST_ASSERT_NOTNULL(berth.reservation, "Could not reserve an elevator destination")
	for(var/turf/tile as anything in block(berth.reservation.bottom_left_turfs[1], berth.reservation.top_right_turfs[1]))
		berth.alcove_turfs += tile.ChangeTurf(/turf/open/indestructible)
	berth.panel = new /obj/machinery/outpost_elevator(berth.alcove_turfs[1])
	berth.panel.outpost = market
	berth.panel.berth = berth
	var/list/obj/item/coin/passengers = list()
	var/list/stationary_fixtures = list()
	for(var/turf/landing as anything in market.lobby_alcove_turfs)
		passengers += allocate(/obj/item/coin, landing)
		for(var/obj/machinery/fixture in landing)
			if(fixture.anchored)
				stationary_fixtures[fixture] = landing
	var/mob/living/carbon/human/rider = allocate(/mob/living/carbon/human, market.lobby_alcove_turfs[5])
	TEST_ASSERT(get_dist(rider, lobby_panel) <= 1, "Elevator controls are out of reach of a standing rider")
	lobby_panel.complete_ride(1, WEAKREF(rider))
	for(var/obj/machinery/fixture as anything in stationary_fixtures)
		TEST_ASSERT_EQUAL(get_turf(fixture), stationary_fixtures[fixture], "Elevator carried an anchored fixture downstairs")
	for(var/i in 1 to 9)
		TEST_ASSERT_EQUAL(get_turf(passengers[i]), berth.alcove_turfs[i], "Elevator changed the outgoing tile order")
	TEST_ASSERT_EQUAL(get_turf(rider), berth.alcove_turfs[5], "Elevator did not carry the rider down")
	berth.panel.complete_ride(0, WEAKREF(rider))
	for(var/obj/machinery/fixture as anything in stationary_fixtures)
		TEST_ASSERT_EQUAL(get_turf(fixture), stationary_fixtures[fixture], "Elevator moved an anchored fixture on return")
	for(var/i in 1 to 9)
		TEST_ASSERT_EQUAL(get_turf(passengers[i]), market.lobby_alcove_turfs[i], "Elevator changed the returning tile order")
	TEST_ASSERT_EQUAL(get_turf(rider), market.lobby_alcove_turfs[5], "Elevator did not return the rider")
	qdel(rider)
	for(var/obj/item/coin/passenger as anything in passengers)
		qdel(passenger)
	qdel(berth)
