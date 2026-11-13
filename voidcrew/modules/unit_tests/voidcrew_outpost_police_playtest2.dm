/**
 * Outpost police tests for the second owner playtest (2026-11-13): the stealth scan with someone on the guard's own
 * tile, the jail strip with a MODsuit's suit storage and nested evidence, outpost NPCs stepping out of an escort's
 * way, response units never left idle in a lift, and hackable, self-mending cell doors (owner decision 47).
 * Helpers are in voidcrew_outpost_police_helpers.dm, voidcrew_outpost_police_cell.dm and
 * voidcrew_outpost_police_dispatch.dm. Fork defines are included after the tests: literal values with a comment.
 */

/// BYOND's get_dist() of a turf with itself is -1: someone on the guard's own tile is a candidate at distance 0, nearest
/// first, and a zero, fractional or negative range never overflows the distance buckets
/datum/unit_test/voidcrew_outpost_police_stealth_same_tile

/datum/unit_test/voidcrew_outpost_police_stealth_same_tile/Run()
	var/turf/spot = run_loc_floor_bottom_left
	var/mob/living/carbon/human/guard = allocate(/mob/living/carbon/human/consistent, spot)
	guard.faction = list("stealth_same_tile_guard")
	var/mob/living/carbon/human/under = allocate(/mob/living/carbon/human/consistent, spot)
	var/mob/living/carbon/human/near = allocate(/mob/living/carbon/human/consistent, get_step(spot, NORTH))
	var/list/found = stealth_candidates(guard, 7)
	TEST_ASSERT(under in found, "Someone on the guard's own tile is not a candidate")
	TEST_ASSERT(near in found, "Someone a tile away is not a candidate")
	TEST_ASSERT_EQUAL(found[1], under, "Someone on the guard's own tile is not the nearest candidate")
	for(var/range in list(0, 2.5, 0.4, -1))
		found = stealth_candidates(guard, range)
		if(range >= 0)
			TEST_ASSERT(under in found, "At range [range] someone on the guard's own tile is not a candidate")
		TEST_ASSERT(!(range < 1 && (near in found)), "At range [range] someone a tile away is a candidate")

/// The jail strip with a worn MODsuit: the gun in suit storage (dropped as the chestplate folds away) goes in the property
/// locker, a gun in the suit's own storage goes in with the suit, a warrant tool in a box in the suit's storage goes to
/// the evidence locker, and nothing is left on the prisoner or the floor
/datum/unit_test/voidcrew_outpost_police_property/strip_mod_storage

/datum/unit_test/voidcrew_outpost_police_property/strip_mod_storage/Run()
	fixture(4)
	var/mob/living/carbon/human/prisoner = person()
	prisoner.equip_to_slot_if_possible(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING, disable_warning = TRUE)
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	prisoner.equip_to_slot_if_possible(card, ITEM_SLOT_ID, disable_warning = TRUE)
	var/obj/item/mod/control/pre_equipped/nuclear/mod_suit = allocate(/obj/item/mod/control/pre_equipped/nuclear)
	TEST_ASSERT(prisoner.equip_to_slot_if_possible(mod_suit, ITEM_SLOT_BACK, disable_warning = TRUE), "Setup: the MODsuit did not go on")
	mod_suit.quick_activation()
	TEST_ASSERT(mod_suit.active, "Setup: the MODsuit did not activate")
	var/obj/item/gun/ballistic/shotgun/bulldog/unrestricted/shotgun = allocate(/obj/item/gun/ballistic/shotgun/bulldog/unrestricted)
	if(prisoner.s_store)
		prisoner.dropItemToGround(prisoner.s_store)
	TEST_ASSERT(prisoner.equip_to_slot_if_possible(shotgun, ITEM_SLOT_SUITSTORE, disable_warning = TRUE), "Setup: the shotgun did not go in suit storage")
	TEST_ASSERT_NOTNULL(mod_suit.atom_storage, "Setup: the MODsuit has no storage")
	var/obj/item/gun/ballistic/automatic/pistol/clandestine/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol/clandestine)
	TEST_ASSERT(mod_suit.atom_storage.attempt_insert(pistol, prisoner, TRUE), "Setup: the pistol did not go in the MODsuit's storage")
	var/obj/item/storage/box/box = allocate(/obj/item/storage/box)
	var/obj/item/card/emag/emag = allocate(/obj/item/card/emag)
	TEST_ASSERT(box.atom_storage.attempt_insert(emag, prisoner, TRUE), "Setup: the emag did not go in the box")
	TEST_ASSERT(mod_suit.atom_storage.attempt_insert(box, prisoner, TRUE), "Setup: the box did not go in the MODsuit's storage")
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, prisoner.mind, 60)
	warrant.evidence = list(WEAKREF(emag))
	var/mob/living/carbon/human/officer = officer_beside(prisoner)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	cuffs.apply_cuffs(prisoner, officer, TRUE)
	TEST_ASSERT_NOTNULL(prisoner.handcuffed, "Setup: the prisoner is not cuffed")

	TEST_ASSERT(police.store_property(prisoner, officer), "store_property failed with free lockers")
	var/obj/structure/closet/secure_closet/personal/outpost_police/locker = police.property_locker_for(prisoner)
	TEST_ASSERT_NOTNULL(locker, "The prisoner has no locker")
	TEST_ASSERT_EQUAL(shotgun.loc, locker, "The gun from suit storage is in [shotgun.loc], not the locker")
	TEST_ASSERT(locker.holds(shotgun), "The gun from suit storage is not listed in the locker")
	TEST_ASSERT_EQUAL(mod_suit.loc, locker, "The MODsuit is not in the locker")
	TEST_ASSERT(pistol in locker.get_all_contents(), "The pistol in the MODsuit's storage is not in the locker with it")
	TEST_ASSERT(emag in evidence.get_all_contents(), "The warrant's tool in a box in the MODsuit is in [emag.loc], not the evidence locker")
	TEST_ASSERT(!(emag in locker.get_all_contents()), "The warrant's tool went in the property locker too")
	for(var/obj/item/worn as anything in prisoner.get_equipped_items(INCLUDE_POCKETS | INCLUDE_HELD))
		if(worn == card || worn == prisoner.handcuffed || istype(worn, /obj/item/clothing/under/rank/prisoner/outpost_police) || istype(worn, /obj/item/clothing/shoes/sneakers/orange/outpost_police))
			continue
		TEST_FAIL("[worn] was left on the prisoner")
	for(var/turf/near as anything in RANGE_TURFS(1, prisoner))
		for(var/obj/item/loose in near)
			if(loose != cuffs)
				TEST_FAIL("[loose] was left on the floor by the prisoner")

/// An outpost NPC in an escort's way steps aside, or on ahead in a 1-wide hall, never back toward the escort; a player stays
/datum/unit_test/voidcrew_outpost_police_step_aside

/datum/unit_test/voidcrew_outpost_police_step_aside/Run()
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	// The escort walks east along the middle row
	var/turf/escort_spot = locate(x0, y0 + 2, z0)
	var/turf/block_spot = locate(x0 + 1, y0 + 2, z0)
	var/turf/ahead_spot = locate(x0 + 2, y0 + 2, z0)
	var/mob/living/carbon/human/escort = allocate(/mob/living/carbon/human/consistent, escort_spot)
	var/mob/living/carbon/human/npc/blocker = allocate(/mob/living/carbon/human/npc, block_spot)
	blocker.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(outpost_npc_step_aside(blocker, escort, list(block_spot, ahead_spot)), "An NPC in the way did not step aside in the open")
	var/turf/moved_to = get_turf(blocker)
	TEST_ASSERT(moved_to.y != y0 + 2, "The NPC stepped along the escort's row instead of aside")
	TEST_ASSERT(moved_to.x >= x0 + 1, "The NPC stepped back toward the escort")

	// A 1-wide hall: tables on both sides and behind; the only way is on ahead
	blocker.forceMove(block_spot)
	for(var/turf/side as anything in list(locate(x0 + 1, y0 + 1, z0), locate(x0 + 1, y0 + 3, z0), locate(x0 + 2, y0 + 1, z0), locate(x0 + 2, y0 + 3, z0), locate(x0, y0 + 1, z0), locate(x0, y0 + 3, z0)))
		allocate(/obj/structure/table, side)
	TEST_ASSERT(outpost_npc_step_aside(blocker, escort, list(block_spot)), "An NPC in a 1-wide hall did not move on ahead")
	TEST_ASSERT_EQUAL(get_turf(blocker), ahead_spot, "An NPC in a 1-wide hall did not move on ahead of the escort")

	// Nowhere to go but back toward the escort: they stay
	blocker.forceMove(block_spot)
	allocate(/obj/structure/table, ahead_spot)
	TEST_ASSERT(!outpost_npc_step_aside(blocker, escort, list(block_spot)), "An NPC boxed in stepped back toward the escort")
	TEST_ASSERT_EQUAL(get_turf(blocker), block_spot, "A boxed-in NPC moved")

	// A player is never moved
	var/mob/living/carbon/human/player_like = allocate(/mob/living/carbon/human/consistent, locate(x0 + 4, y0 + 4, z0))
	TEST_ASSERT(!outpost_npc_step_aside(player_like, escort, list()), "A person who is not an outpost NPC was moved aside")

/// The cell's walk: an outpost NPC standing on the lobby tile outside the door steps off it, never into the cell or the doorway
/datum/unit_test/voidcrew_outpost_police_cell_clear_step

/datum/unit_test/voidcrew_outpost_police_cell_clear_step/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/officer = police_cell_person(get_step(cell.outside_turf, NORTH))
	var/mob/living/carbon/human/npc/blocker = allocate(/mob/living/carbon/human/npc, cell.outside_turf)
	blocker.ai_controller?.set_ai_status(AI_STATUS_OFF)
	cell.cell_clear_step(officer, cell.outside_turf)
	var/turf/moved_to = get_turf(blocker)
	TEST_ASSERT(moved_to != cell.outside_turf, "An NPC on the lobby tile did not step out of the officer's way")
	TEST_ASSERT(!(moved_to in cell.tiles), "An NPC stepped into the cell to get out of the way")
	TEST_ASSERT(moved_to != get_turf(cell.door), "An NPC stepped into the doorway to get out of the way")

/// Nobody waits in a lift for good: an idle response unit (no suspect, no case) goes home by the lift they stand in,
/// one away from a lift picks a lift tile nobody stands on, and a wave still forming up is left alone
/datum/unit_test/voidcrew_outpost_police_dispatch_lift_idle

/datum/unit_test/voidcrew_outpost_police_dispatch_lift_idle/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	dispatch_clear(police)
	var/list/old_lifts = police.lift_turfs
	var/list/turf/row = dispatch_row(outpost)
	TEST_ASSERT_NOTNULL(row, "Setup: no three free concourse tiles in a row")
	// Lift tiles at both ends of the row; the middle tile is beside the first
	var/turf/lift_one = row[1]
	var/turf/middle = row[2]
	var/turf/lift_two = police_floor(outpost)
	for(var/i in 1 to 20)
		if(lift_two && !(lift_two in row) && dispatch_free(outpost, lift_two))
			break
		lift_two = police_floor(outpost)
	police.lift_turfs = list(lift_one, lift_two)
	var/mob/living/suspect = dispatch_suspect(outpost, 10) // one star: two units wanted (OUTPOST_POLICE_UNITS)
	police.dispatch_next_wave = world.time + 1 MINUTES
	var/list/busy = list()
	for(var/i in 1 to 2)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/responder = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
		responder.resume_routine() // as if someone were on the concourse
		responder.dispatch_mind = WEAKREF(suspect.mind)
		busy += responder
	// Came for someone who is gone, standing in a lift
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/idle_in_lift = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, lift_two)
	idle_in_lift.resume_routine()
	// Still forming up behind the lift door with their wave
	var/datum/outpost_police_wave/wave = police.dispatch_new_wave("concourse", lift_two) // POLICE_SECTOR_CONCOURSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/forming = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, lift_two)
	forming.resume_routine()
	forming.dispatch_wave = wave
	wave.members += WEAKREF(forming)
	police.dispatch_respond(police.alert_level())
	TEST_ASSERT_EQUAL(idle_in_lift.npc_exit, lift_two, "An idle response unit standing in a lift was not sent home by it")
	TEST_ASSERT_NULL(forming.npc_exit, "A unit still forming up with its wave was sent home")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/responder as anything in busy)
		TEST_ASSERT_NULL(responder.npc_exit, "A unit responding to a wanted suspect was sent home")

	// One beside a lift tile someone stands on goes for a free one (the two above have gone home by now)
	qdel(idle_in_lift)
	forming.npc_walk_out(lift_two)
	qdel(forming)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/standing = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, lift_one)
	standing.resume_routine()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/walker = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, middle)
	walker.resume_routine()
	TEST_ASSERT(police.dispatch_send_home(walker), "A unit with lifts about was not sent home")
	TEST_ASSERT_EQUAL(walker.npc_exit, lift_two, "A unit went for a lift tile someone stands on")
	// Their exit taken after all: the next look picks another
	walker.npc_walk_out(lift_one)
	police.dispatch_check_idle()
	TEST_ASSERT_EQUAL(walker.npc_exit, lift_two, "A unit kept walking to a lift tile someone stands on")

	police.lift_turfs = old_lifts
	police.dispatch_waves -= wave
	qdel(wave)
	dispatch_clear(police)

/**
 * Owner decision 47: a cell door is hacked like any airlock and mends itself. Its panel opens past outpost property;
 * a pulsed open wire needs the ID wire cut; a hack that opens it on a held prisoner is the hacker's jailbreak; a pry
 * works once its power is out; an emag opens it; the mend waits for a clear doorway and puts everything back; and
 * officers still book and release through a door that is still hacked, and through a mended one.
 */
/datum/unit_test/voidcrew_outpost_police_cell_hacked

/datum/unit_test/voidcrew_outpost_police_cell_hacked/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door = cell.door
	door.AddElement(/datum/element/outpost_property)
	var/mob/living/carbon/human/hacker = police_cell_person(cell.outside_turf)
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	police_pin_warrant(police, prisoner.mind, 12)
	cell.admit(prisoner, world.time + 10 MINUTES)
	TEST_ASSERT(door.density, "Setup: the cell door is open")

	// The panel, past outpost property
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	hacker.put_in_hands(screwdriver)
	screwdriver.melee_attack_chain(hacker, door)
	TEST_ASSERT(door.panel_open, "A screwdriver did not open a cell door's panel")
	TEST_ASSERT(door.mend_pending, "Opening the panel did not start the mend")

	// The open wire does nothing while the door checks IDs; with the ID wire cut it opens the door on the prisoner
	door.wires.pulse(WIRE_OPEN, hacker)
	sleep(2 SECONDS)
	TEST_ASSERT(door.density, "A pulsed open wire opened a cell door that still checks IDs")
	door.wires.cut(WIRE_IDSCAN, hacker)
	door.wires.pulse(WIRE_OPEN, hacker)
	sleep(2 SECONDS)
	TEST_ASSERT(!door.density, "A pulsed open wire with the ID wire cut did not open the cell door")
	var/list/crime = police_last_crime(police)
	TEST_ASSERT_NOTNULL(crime, "Hacking a cell door open on a prisoner reported nothing")
	TEST_ASSERT_EQUAL(crime[1], hacker, "The jailbreak went to [crime?[1]], not the hacker")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "Hacking a cell door open on a prisoner was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT(cell.open_until > world.time, "A hacked-open cell door is not held open a while, as a forced one is")

	// The mend waits for a clear doorway, then puts everything back
	var/turf/doorway = get_turf(door)
	hacker.forceMove(doorway)
	door.mend_hack()
	TEST_ASSERT(door.panel_open, "The door mended with someone in the doorway")
	hacker.forceMove(cell.outside_turf)
	door.mend_hack()
	TEST_ASSERT(!door.panel_open, "The mend left the panel open")
	TEST_ASSERT(!door.wires.is_cut(WIRE_IDSCAN), "The mend left a wire cut")
	TEST_ASSERT(door.hasPower(), "The mend left the door without power")
	TEST_ASSERT(!door.locked, "The mend left the bolts down")
	TEST_ASSERT(!door.mend_pending, "A mend is still pending after the mend")
	cell.open_until = 0
	cell.close_check()
	sleep(2 SECONDS)
	TEST_ASSERT(door.density, "The mended door did not shut on its prisoner")

	// A pry once the power is out
	var/before = length(police.crimes)
	screwdriver.melee_attack_chain(hacker, door)
	for(var/power_wire in list(WIRE_POWER1, WIRE_POWER2, WIRE_BACKUP1, WIRE_BACKUP2))
		door.wires.cut(power_wire, hacker)
	TEST_ASSERT(!door.hasPower(), "Setup: cutting the power wires left the door powered")
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	hacker.put_in_hands(crowbar)
	door.crowbar_act(hacker, crowbar)
	sleep(2 SECONDS)
	TEST_ASSERT(!door.density, "A crowbar did not pry open an unpowered cell door")
	TEST_ASSERT_EQUAL(length(police.crimes), before + 1, "Prying an unpowered cell door open on a prisoner reported no jailbreak")
	hacker.forceMove(locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z))
	door.mend_hack()
	cell.open_until = 0
	cell.close_check()
	sleep(2 SECONDS)
	TEST_ASSERT(door.density, "Setup: the mended door did not shut")

	// An airlock authentication override card
	hacker.forceMove(cell.outside_turf)
	before = length(police.crimes)
	var/obj/item/card/emag/doorjack/doorjack = allocate(/obj/item/card/emag/doorjack)
	TEST_ASSERT(door.emag_act(hacker, doorjack), "An override card was refused by a cell door")
	sleep(3 SECONDS)
	TEST_ASSERT(!door.density, "An override card did not open a cell door")
	TEST_ASSERT(door.obj_flags & EMAGGED, "An override card left no mark on the cell door")
	TEST_ASSERT_EQUAL(length(police.crimes), before + 1, "Opening a cell door with an override card on a prisoner reported no jailbreak")
	hacker.forceMove(locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z))
	door.mend_emag()
	TEST_ASSERT(!(door.obj_flags & EMAGGED), "The emag mend left the door broken")
	TEST_ASSERT(!door.locked, "The emag mend left the bolts down")

	// Release through a door still hacked: bolted and without power, the cell's own control still lets them out
	cell.open_until = 0
	cell.close_check()
	sleep(2 SECONDS)
	TEST_ASSERT(door.density, "Setup: the door did not shut before the release")
	for(var/power_wire in list(WIRE_POWER1, WIRE_POWER2, WIRE_BACKUP1, WIRE_BACKUP2))
		door.wires.cut(power_wire, hacker)
	door.bolt()
	cell.prisoners[prisoner.mind] = world.time
	police.tick_cells()
	sleep(3 SECONDS)
	TEST_ASSERT(!(prisoner.mind in cell.prisoners), "Setup: the prisoner's time was up and they are still held")
	TEST_ASSERT(!door.density, "The release could not open a hacked cell door")
	prisoner.forceMove(locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z))
	hacker.forceMove(locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z))
	cell.open_until = 0
	cell.override_until = 0
	cell.close_check()

	// Booking through doors that are still hacked (both cells: bolted, unpowered, wires cut)
	for(var/datum/outpost_police_cell/each_cell as anything in police.cells)
		var/obj/machinery/door/airlock/outpost/glass/police_cell/each_door = each_cell.door
		each_door.mend_hack()
		each_cell.open_until = 0
		each_cell.close_check()
	sleep(2 SECONDS)
	for(var/datum/outpost_police_cell/each_cell as anything in police.cells)
		var/obj/machinery/door/airlock/outpost/glass/police_cell/each_door = each_cell.door
		TEST_ASSERT(each_door.density, "Setup: cell [each_cell.cell_id]'s door is open")
		each_door.panel_open = TRUE
		for(var/power_wire in list(WIRE_POWER1, WIRE_POWER2, WIRE_BACKUP1, WIRE_BACKUP2, WIRE_BOLTS))
			each_door.wires.cut(power_wire, hacker)
		TEST_ASSERT(each_door.locked, "Setup: cutting the bolt wire did not drop the bolts")
	var/list/booked = police_test_book(police, 1, TRUE)
	TEST_ASSERT_NOTNULL(booked, "Officers could not book a prisoner through a hacked cell door")

	// And through a mended one
	if(booked)
		var/mob/living/carbon/human/first = booked[1]
		var/datum/outpost_police_cell/used = booked[3]
		used.forget_prisoner(first.mind)
		first.forceMove(locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z))
	for(var/datum/outpost_police_cell/each_cell as anything in police.cells)
		var/obj/machinery/door/airlock/outpost/glass/police_cell/each_door = each_cell.door
		each_door.mend_hack()
		TEST_ASSERT(!each_door.wires.is_cut(WIRE_BOLTS) && !each_door.locked && each_door.hasPower(), "Cell [each_cell.cell_id]'s door did not mend")
	TEST_ASSERT_NOTNULL(police_test_book(police, 1, TRUE), "Officers could not book a prisoner through a mended cell door")
