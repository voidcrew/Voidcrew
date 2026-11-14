/**
 * Lockup airlocks (outpost_prison_doors.dm, owner decision O8; police decisions 47 and 48): cell doors, staff doors
 * and Processing doors reject a plain emag, allow panel and wire hacking with screwdriver/wirecutters/multitool and
 * opening with an override card, report OUTPOST_CRIME_JAILBREAK when opened while the wing holds anyone, mend after
 * 3 minutes once the doorway is clear (and wait while occupied), and staff doors open on rioter blows and mend.
 *
 * Voidcrew defines are included after the unit tests, so literal values appear with a comment naming the define.
 */

/datum/unit_test/voidcrew_trade_prison_doors
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_doors/proc/beside_door(obj/machinery/door/airlock/door, turf/avoid)
	var/turf/here = get_turf(door)
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(here, direction)
		if(candidate && candidate != avoid && isopenturf(candidate) && !candidate.is_blocked_turf())
			return candidate
	return null

/datum/unit_test/voidcrew_trade_prison_doors/proc/check_door_o8(
	obj/machinery/door/airlock/door,
	label,
	datum/outpost_prison/prison,
	datum/outpost_police/cell_test/police,
	mob/living/carbon/human/hacker,
	mob/living/carbon/human/blocker,
	turf/park_turf,
	obj/item/screwdriver/screwdriver,
	obj/item/wirecutters/wirecutters,
	obj/item/multitool/multitool,
	obj/item/weldingtool/welder,
	obj/item/wrench/wrench,
	obj/item/card/emag/plain_emag,
	obj/item/card/emag/doorjack/doorjack
)
	var/turf/work_turf = beside_door(door)
	TEST_ASSERT_NOTNULL(work_turf, "No open floor beside [label]")
	var/turf/doorway = get_turf(door)
	blocker.forceMove(park_turf)
	hacker.forceMove(work_turf)
	TEST_ASSERT(door.density, "Setup: [label] starts open")

	// Outpost property lets screwdriver and wirecutters reach the panel and wires, never a welder or wrench
	TEST_ASSERT(door.outpost_hackable(screwdriver), "[label] refused a screwdriver under outpost_hackable()")
	TEST_ASSERT(door.outpost_hackable(wirecutters), "[label] refused wirecutters under outpost_hackable()")
	TEST_ASSERT(!door.outpost_hackable(welder), "[label] allowed a welder under outpost_hackable()")
	TEST_ASSERT(!door.outpost_hackable(wrench), "[label] allowed a wrench under outpost_hackable()")
	TEST_ASSERT(door.outpost_forceable(), "[label] is not outpost_forceable()")

	// Police decision 48: a plain emag does nothing
	var/crimes_before = length(police.crimes)
	TEST_ASSERT(!door.emag_act(hacker, plain_emag), "A plain emag worked on [label]")
	TEST_ASSERT(!door.emag_act(hacker, null), "emag_act() with no card worked on [label]")
	TEST_ASSERT(door.density && !(door.obj_flags & EMAGGED), "A plain emag altered [label]")
	TEST_ASSERT_EQUAL(length(police.crimes), crimes_before, "A refused emag on [label] reported a crime")

	// Wire-hacking open while a prisoner is held: schedules the 3-minute mend and reports a jailbreak on the opener
	var/started = world.time
	hacker.drop_all_held_items()
	hacker.put_in_active_hand(screwdriver)
	screwdriver.melee_attack_chain(hacker, door)
	TEST_ASSERT(door.panel_open, "A screwdriver did not open [label]'s maintenance panel")
	var/mend_pending = FALSE
	var/mend_due = 0
	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = door
		mend_pending = staff_door.mend_pending
		mend_due = staff_door.mend_due
	else
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = door
		mend_pending = cell_door.mend_pending
		mend_due = cell_door.mend_due
	TEST_ASSERT(mend_pending, "Opening [label]'s panel did not schedule a mend")
	TEST_ASSERT(mend_due >= started + (3 MINUTES) && mend_due <= world.time + (3 MINUTES), "[label]'s mend due time is not 3 minutes out") // OUTPOST_CHECKPOINT_EMAG_TIME

	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		hacker.drop_all_held_items()
		hacker.put_in_active_hand(multitool)
		door.wires.pulse(WIRE_OPEN, hacker)
		sleep(2 SECONDS)
		TEST_ASSERT(door.density, "Pulsing WIRE_OPEN opened [label] while WIRE_IDSCAN was uncut")

	hacker.drop_all_held_items()
	hacker.put_in_active_hand(wirecutters)
	door.wires.cut(WIRE_IDSCAN, hacker)
	door.wires.cut(WIRE_POWER1, hacker)
	door.wires.cut(WIRE_POWER2, hacker)
	door.wires.cut(WIRE_POWER1, hacker)
	door.wires.cut(WIRE_POWER2, hacker)
	TEST_ASSERT(!door.wires.is_cut(WIRE_POWER1) && !door.wires.is_cut(WIRE_POWER2) && door.hasPower(), "Cutting cut power wires did not mend them on [label]")
	door.bolt()
	hacker.drop_all_held_items()
	hacker.put_in_active_hand(multitool)
	door.wires.pulse(WIRE_BOLTS, hacker)
	TEST_ASSERT(!door.locked, "Pulsing WIRE_BOLTS did not unbolt [label]")
	door.wires.pulse(WIRE_OPEN, hacker)
	sleep(2 SECONDS)
	TEST_ASSERT(!door.density, "Wire-hacking did not open [label]")
	TEST_ASSERT_EQUAL(length(police.crimes), crimes_before + 1, "Wire-hacking [label] open with a prisoner held did not report one crime")
	var/list/crime = police_last_crime(police)
	TEST_ASSERT_EQUAL(crime[1], hacker, "Wire-hacking [label] blamed [crime[1]], not the opener")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "Wire-hacking [label] reported [crime[2]], not jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT_EQUAL(crime[3], multitool, "Wire-hacking [label] did not record the tool used")

	// Mend waits while someone stands in the doorway, then shuts the panel, mends wires, restores power/bolts and closes
	blocker.forceMove(doorway)
	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = door
		staff_door.mend_hack()
		TEST_ASSERT(staff_door.panel_open && !staff_door.density, "[label] mended while someone stood in the doorway")
		blocker.forceMove(park_turf)
		staff_door.mend_hack()
		sleep(2 SECONDS)
		TEST_ASSERT(!staff_door.panel_open && !staff_door.mend_pending, "[label] left its panel open or mend pending after mending")
	else
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = door
		cell_door.mend_hack()
		TEST_ASSERT(cell_door.panel_open && !cell_door.density, "[label] mended while someone stood in the doorway")
		blocker.forceMove(park_turf)
		cell_door.mend_hack()
		sleep(2 SECONDS)
		TEST_ASSERT(!cell_door.panel_open && !cell_door.mend_pending, "[label] left its panel open or mend pending after mending")
	TEST_ASSERT(!door.wires.is_cut(WIRE_IDSCAN), "[label] kept a cut wire after mending")
	TEST_ASSERT(door.hasPower() && !door.locked, "[label] was not powered and unbolted after mending")
	TEST_ASSERT(door.density, "[label] did not shut after mending")

	// Override card (doorjack) opens the door, reports a jailbreak while occupied, and mends cleanly
	doorjack.charges = 3
	crimes_before = length(police.crimes)
	TEST_ASSERT(door.emag_act(hacker, doorjack), "An airlock authentication override card was refused by [label]")
	sleep(2.5 SECONDS)
	TEST_ASSERT(!door.density && (door.obj_flags & EMAGGED), "An override card did not open [label]")
	TEST_ASSERT_EQUAL(length(police.crimes), crimes_before + 1, "Opening [label] with an override card did not report a jailbreak")
	crime = police_last_crime(police)
	TEST_ASSERT_EQUAL(crime[1], hacker, "Override-card opening of [label] blamed [crime[1]], not the opener")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "Override-card opening of [label] reported [crime[2]], not jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT_EQUAL(crime[3], doorjack, "Override-card opening of [label] did not record the card as evidence")
	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = door
		staff_door.mend_hack()
	else
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = door
		cell_door.mend_hack()
	sleep(2 SECONDS)
	TEST_ASSERT(door.density && !(door.obj_flags & EMAGGED) && door.hasPower() && !door.locked, "[label] did not mend after an override card")
	hacker.drop_all_held_items()

/datum/unit_test/voidcrew_trade_prison_doors/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	TEST_ASSERT_NOTNULL(prison, "Quartermain Depot has no lockup")

	var/datum/outpost_police/real_police = outpost.police
	var/datum/outpost_police/cell_test/police = allocate(/datum/outpost_police/cell_test, outpost)
	outpost.police = police

	var/datum/outpost_prison_cell/cell = prison.cells[1]
	var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = cell.door()
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison.guard_yard_doors()[1]
	var/obj/machinery/door/airlock/security/prison_staff/processing/proc_door = prison.processing_door(FALSE)
	TEST_ASSERT_NOTNULL(cell_door, "No cell door found in the lockup")
	TEST_ASSERT_NOTNULL(staff_door, "No office staff door found in the lockup")
	TEST_ASSERT_NOTNULL(proc_door, "No Processing outer door found in the lockup")

	var/turf/park_turf = prison.alcove_turfs[1]
	var/mob/living/carbon/human/hacker = police_cell_person(park_turf)
	var/mob/living/carbon/human/blocker = police_cell_person(prison.alcove_turfs[9])
	var/mob/living/carbon/human/npc/outpost_prisoner/held = test_prisoner(prison, cell.arrival_turf())
	TEST_ASSERT(prison.holds_anyone(), "The lockup does not know it holds a prisoner")

	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/wirecutters/wirecutters = allocate(/obj/item/wirecutters)
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	var/obj/item/card/emag/plain_emag = allocate(/obj/item/card/emag)
	var/obj/item/card/emag/doorjack/doorjack = allocate(/obj/item/card/emag/doorjack)

	check_door_o8(cell_door, "cell door", prison, police, hacker, blocker, park_turf, screwdriver, wirecutters, multitool, welder, wrench, plain_emag, doorjack)
	check_door_o8(staff_door, "staff door", prison, police, hacker, blocker, park_turf, screwdriver, wirecutters, multitool, welder, wrench, plain_emag, doorjack)
	check_door_o8(proc_door, "Processing door", prison, police, hacker, blocker, park_turf, screwdriver, wirecutters, multitool, welder, wrench, plain_emag, doorjack)

	// With power cut, a crowbar pries a lockup door open without removing electronics, reports a jailbreak, and mends
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	var/crimes_pry = length(police.crimes)
	hacker.forceMove(beside_door(cell_door))
	hacker.drop_all_held_items()
	hacker.put_in_active_hand(screwdriver)
	screwdriver.melee_attack_chain(hacker, cell_door)
	hacker.drop_all_held_items()
	hacker.put_in_active_hand(wirecutters)
	cell_door.wires.cut(WIRE_POWER1, hacker)
	cell_door.wires.cut(WIRE_POWER2, hacker)
	cell_door.wires.cut(WIRE_BACKUP1, hacker)
	cell_door.wires.cut(WIRE_BACKUP2, hacker)
	TEST_ASSERT(!cell_door.hasPower(), "Cutting all power wires left the cell door powered")
	hacker.drop_all_held_items()
	hacker.put_in_active_hand(crowbar)
	crowbar.melee_attack_chain(hacker, cell_door)
	sleep(2 SECONDS)
	TEST_ASSERT(!QDELETED(cell_door) && !cell_door.density, "A crowbar did not pry the unpowered cell door open")
	TEST_ASSERT_EQUAL(length(police.crimes), crimes_pry + 1, "Prying an occupied cell door open did not report a jailbreak")
	var/list/pry_crime = police_last_crime(police)
	TEST_ASSERT_EQUAL(pry_crime[1], hacker, "Prying the cell door blamed [pry_crime[1]], not the opener")
	TEST_ASSERT_EQUAL(pry_crime[2], "jailbreak", "Prying the cell door reported [pry_crime[2]], not jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT_EQUAL(pry_crime[3], crowbar, "Prying the cell door did not record the crowbar as evidence")
	cell_door.mend_hack()
	sleep(2 SECONDS)
	TEST_ASSERT(cell_door.density && cell_door.hasPower() && !cell_door.panel_open, "The pried cell door did not mend")
	// With power on and bolted, a crowbar begins a slow force instead of prying or removing electronics, and aborts if the hacker leaves
	cell_door.bolt()
	hacker.put_in_active_hand(crowbar)
	TEST_ASSERT_EQUAL(cell_door.crowbar_act(hacker, crowbar), ITEM_INTERACT_SUCCESS, "A crowbar was refused on a powered bolted cell door")
	TEST_ASSERT(cell_door.lockup_hack.forcing, "A crowbar on a powered bolted cell door did not start forcing")
	hacker.forceMove(park_turf)
	sleep(0.5 SECONDS)
	TEST_ASSERT(!cell_door.lockup_hack.forcing && cell_door.density, "Moving away did not cancel forcing the cell door")
	cell_door.mend_hack()
	hacker.drop_all_held_items()

	// With nobody held in the wing, opening a lockup door reports no jailbreak
	qdel(held)
	TEST_ASSERT(!prison.holds_anyone(), "An empty lockup still claims to hold someone")
	var/crimes_empty = length(police.crimes)
	doorjack.charges = 3
	hacker.forceMove(beside_door(staff_door))
	TEST_ASSERT(staff_door.emag_act(hacker, doorjack), "An override card failed on the staff door of an empty lockup")
	sleep(2.5 SECONDS)
	TEST_ASSERT(!staff_door.density, "The staff door of an empty lockup did not open")
	TEST_ASSERT_EQUAL(length(police.crimes), crimes_empty, "Opening a lockup door with nobody held inside reported a jailbreak")
	staff_door.mend_hack()
	sleep(2 SECONDS)
	TEST_ASSERT(staff_door.density, "The staff door did not shut after mending")
	hacker.forceMove(park_turf)

	// Rioter blows batter a staff door open at its threshold without deleting it, and it mends
	var/turf/yard_side
	for(var/direction in GLOB.cardinals)
		var/turf/step_tile = get_step(staff_door, direction)
		if(step_tile && prison.in_cell_block(step_tile) && isopenturf(step_tile) && !step_tile.is_blocked_turf())
			yard_side = step_tile
			break
	TEST_ASSERT_NOTNULL(yard_side, "No yard tile beside the staff door for the rioter")
	prison.trouble_enabled = TRUE
	var/mob/living/carbon/human/npc/outpost_prisoner/rioter = trouble_prisoner(prison, yard_side)
	TEST_ASSERT(breakout_riot(prison), "The riot did not start for the staff door battering check")
	var/blows_needed = round(staff_door.max_integrity / 10) // PRISON_RIOT_DOOR_DAMAGE
	for(var/blow in 1 to blows_needed - 1)
		rioter.confront(staff_door)
	TEST_ASSERT(!QDELETED(staff_door) && !staff_door.rioter_broken && staff_door.density, "The staff door gave way early")
	rioter.confront(staff_door)
	TEST_ASSERT(!QDELETED(staff_door) && staff_door.rioter_broken && staff_door.mend_pending, "Rioter blows at the threshold did not batter the staff door open")
	sleep(2 SECONDS)
	TEST_ASSERT(!staff_door.density, "The battered staff door did not swing open")
	staff_door.mend_hack()
	sleep(2 SECONDS)
	TEST_ASSERT(!staff_door.rioter_broken && staff_door.rioter_damage == 0 && !staff_door.mend_pending, "Mending left rioter state on the staff door")
	TEST_ASSERT(staff_door.density && staff_door.hasPower() && !staff_door.locked, "The battered staff door was not shut, powered and unbolted after mending")

	prison.admin_calm()
	outpost.police = real_police
