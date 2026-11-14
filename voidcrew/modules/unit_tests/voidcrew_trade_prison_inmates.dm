/**
 * Player inmates in the outpost lockup (outpost_prison_inmates.dm, police_arrest.dm, police_wanted.dm,
 * police_property.dm, police_cell.dm, outpost_prison_guards.dm, outpost_prison_trouble.dm).
 *
 * Voidcrew defines are included after the unit tests, so literal values appear with a comment naming the define.
 */

/// Open yard floor tile in `prison` outside any cell
/datum/unit_test/voidcrew_outpost_management/proc/inmate_test_yard_tile(datum/outpost_prison/prison)
	for(var/turf/tile as anything in prison.cell_block)
		if(!prison.cell_at(tile) && isopenturf(tile) && !tile.is_blocked_turf())
			return tile
	return null

/// Open front-room floor tile in `prison` outside the lift alcove and desk counter
/datum/unit_test/voidcrew_outpost_management/proc/inmate_test_front_tile(datum/outpost_prison/prison)
	for(var/turf/tile as anything in lockup_flood(prison.alcove_turfs[1], doors_open = FALSE))
		if(!(tile in prison.alcove_turfs) && tile != prison.claim_turf && !tile.is_blocked_turf())
			return tile
	return null

// =========================================================================
// 1. POLICE SEAMS: FINE CHECK, CAN_BOOK, AND DESK ROUTING
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_inmates_police_seam
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/list/test_ships = list()

/datum/unit_test/voidcrew_trade_prison_inmates_police_seam/Destroy()
	wanted_cleanup(test_ships)
	test_ships.Cut()
	return ..()

/datum/unit_test/voidcrew_trade_prison_inmates_police_seam/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(prison, "Quartermain Depot has no lockup")
	TEST_ASSERT_NOTNULL(police, "Quartermain Depot has no police")

	var/turf/front_tile = inmate_test_front_tile(prison)
	TEST_ASSERT_NOTNULL(front_tile, "No open front-room floor tile found in the lockup")

	var/list/obj/structure/closet/secure_closet/personal/outpost_police/wing_lockers = list()
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in police.lockers)
		if(get_area(locker) == prison.wing)
			wing_lockers += locker
	TEST_ASSERT(length(wing_lockers) >= 4, "The lockup's front room registered [length(wing_lockers)] property lockers, fewer than 4")

	// fine_affordable() checks the same crew accounts as charge_fine() without moving a credit
	var/mob/living/carbon/human/broke = police_arrest_person(front_tile)
	var/obj/structure/overmap/ship/broke_ship = wanted_ship(broke, 0)
	test_ships += broke_ship
	var/datum/outpost_warrant/broke_warrant = police_pin_warrant(police, broke.mind, 30) // 2 stars (OUTPOST_POLICE_STAR_HEAT: 25)
	TEST_ASSERT(!police.fine_affordable(broke_warrant), "fine_affordable() accepted a broke crew for a two-star fine")
	TEST_ASSERT(!police.charge_fine(broke_warrant), "charge_fine() succeeded on a broke crew")
	TEST_ASSERT_EQUAL(broke_ship.ship_account.account_balance, 0, "Failed fine checks altered a broke crew's balance")

	var/mob/living/carbon/human/solvent = police_arrest_person(front_tile)
	var/obj/structure/overmap/ship/solvent_ship = wanted_ship(solvent, 5000)
	test_ships += solvent_ship
	var/datum/outpost_warrant/solvent_warrant = police_pin_warrant(police, solvent.mind, 30) // 2 stars
	TEST_ASSERT(police.fine_affordable(solvent_warrant), "fine_affordable() refused a solvent crew for a two-star fine")
	TEST_ASSERT_EQUAL(solvent_ship.ship_account.account_balance, 5000, "fine_affordable() moved money instead of only checking")

	// can_book() requires a wing locker that can shut and a living, non-crit suspect
	TEST_ASSERT(prison.can_book(broke), "can_book() refused a healthy suspect on a ready lockup")
	ADD_TRAIT(broke, TRAIT_CRITICAL_CONDITION, REF(src))
	TEST_ASSERT(!prison.can_book(broke), "can_book() accepted a suspect in critical condition")
	REMOVE_TRAIT(broke, TRAIT_CRITICAL_CONDITION, REF(src))
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in wing_lockers)
		locker.assigning = TRUE
	TEST_ASSERT(!prison.can_book(broke), "can_book() accepted a booking when every wing locker was unavailable")
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in wing_lockers)
		locker.assigning = FALSE
	TEST_ASSERT(prison.can_book(broke), "can_book() stayed false after the wing lockers were freed")
	prison.processing_state = "booking" // OUTPOST_PROCESSING_BOOK
	TEST_ASSERT(prison.can_book(broke), "can_book() rejected a second suspect while another booking held Processing with free wing lockers")
	prison.processing_state = "idle" // OUTPOST_PROCESSING_IDLE

	// Arrest routing at step_desk(): 1-2 star solvent stays on the station path; 1-2 star broke and 3+ stars route to the lockup
	dispatch_clear(police)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, front_tile)
	police_arrest_kit(officer)
	ADD_TRAIT(officer, TRAIT_AI_PAUSED, REF(src))

	var/datum/outpost_police_case/solvent_case = police.open_case(solvent_warrant)
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(solvent_case, "No case opened for the two-star solvent suspect")
	TEST_ASSERT(!solvent_case.wants_lockup(solvent), "A two-star suspect who can pay their fine was routed to the lockup")
	solvent_case.close()

	var/datum/outpost_police_case/broke_case = police.open_case(broke_warrant)
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(broke_case, "No case opened for the two-star broke suspect")
	TEST_ASSERT(broke_case.wants_lockup(broke), "A two-star suspect who cannot pay their fine was not routed to the lockup")
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in wing_lockers)
		locker.assigning = TRUE
	TEST_ASSERT(!broke_case.wants_lockup(broke), "wants_lockup() stayed true when the lockup had no usable wing locker")
	for(var/obj/structure/closet/secure_closet/personal/outpost_police/locker as anything in wing_lockers)
		locker.assigning = FALSE
	var/obj/item/restraints/handcuffs/outpost_police/used/broke_cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	broke.set_handcuffed(broke_cuffs)
	broke_case.cuffed = TRUE
	broke_case.searched = TRUE
	broke_case.disposed_at = world.time
	officer.start_pulling(broke)
	broke_case.step_desk()
	TEST_ASSERT_EQUAL(broke_case.step, "lockup", "step_desk() put a two-star insolvent suspect on [broke_case.step], not lockup") // CASE_STEP_LOCKUP
	officer.stop_pulling()
	broke_case.close()
	broke.set_handcuffed(null)
	qdel(broke_cuffs)

	solvent_warrant.heat = 55 // 3 stars (OUTPOST_POLICE_STAR_HEAT: 50)
	var/datum/outpost_police_case/major_case = police.open_case(solvent_warrant)
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(major_case, "No case opened for the three-star suspect")
	TEST_ASSERT(major_case.wants_lockup(solvent), "A three-star suspect with money in the bank was not routed to the lockup")
	prison.processing_state = "booking" // OUTPOST_PROCESSING_BOOK
	TEST_ASSERT(major_case.wants_lockup(solvent), "wants_lockup() diverted a three-star arrest away from the lockup while another booking held Processing")
	prison.processing_state = "idle" // OUTPOST_PROCESSING_IDLE
	major_case.close()
	REMOVE_TRAIT(officer, TRAIT_AI_PAUSED, REF(src))

// =========================================================================
// 2. BOOKING WALK, SENTENCE CLOCK, WARRANT HOLD, BAIL RETRY, AND RELEASE
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_inmates_booking_and_clock
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/old_time_scale = 1
	var/forced_moves = 0
	var/list/test_ships = list()

/datum/unit_test/voidcrew_trade_prison_inmates_booking_and_clock/New()
	. = ..()
	old_time_scale = GLOB.outpost_police_property_time_scale
	GLOB.outpost_police_property_time_scale = 0.02

/datum/unit_test/voidcrew_trade_prison_inmates_booking_and_clock/Destroy()
	GLOB.outpost_police_property_time_scale = old_time_scale
	wanted_cleanup(test_ships)
	test_ships.Cut()
	return ..()

/datum/unit_test/voidcrew_trade_prison_inmates_booking_and_clock/proc/note_move(atom/movable/source, atom/old_loc, movement_dir, forced)
	SIGNAL_HANDLER
	if(forced)
		forced_moves++

/datum/unit_test/voidcrew_trade_prison_inmates_booking_and_clock/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/datum/outpost_police/police = outpost.police

	var/obj/machinery/door/airlock/security/prison_staff/inner = prison.processing_door(TRUE)
	var/obj/machinery/door/airlock/security/prison_staff/outer = prison.processing_door(FALSE)
	var/turf/outer_wait = prison.booking_door_turf()
	var/turf/front_clear = prison.processing_clear_turf(outer)
	var/turf/inner_wait = prison.processing_outside_turf(inner)
	TEST_ASSERT_NOTNULL(outer_wait, "The lockup has no booking door approach tile")
	TEST_ASSERT_NOTNULL(front_clear, "Processing's outer door has no clear front-room tile")
	TEST_ASSERT_NOTNULL(inner_wait, "Processing's inner door has no yard approach tile")

	var/mob/living/carbon/human/npc/outpost_prisoner/greeter = trouble_prisoner(prison, prison.processing_clear_turf(inner) || inner_wait)

	dispatch_clear(police)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, outer_wait)
	police.sleep_tick()
	ADD_TRAIT(officer, TRAIT_AI_PAUSED, REF(src))
	police_arrest_kit(officer)

	var/mob/living/carbon/human/suspect = make_player(front_clear, "lockupinmate1")
	suspect.equip_to_slot_or_del(allocate(/obj/item/clothing/under/rank/cargo/tech), ITEM_SLOT_ICLOTHING, initial = TRUE)
	suspect.equip_to_slot_or_del(allocate(/obj/item/clothing/shoes/sneakers/black), ITEM_SLOT_FEET, initial = TRUE)
	var/obj/item/card/id/advanced/id_card = allocate(/obj/item/card/id/advanced)
	suspect.equip_to_slot_or_del(id_card, ITEM_SLOT_ID, initial = TRUE)
	var/obj/item/storage/backpack/pack = allocate(/obj/item/storage/backpack)
	var/obj/item/crowbar/tool = allocate(/obj/item/crowbar, pack)
	suspect.equip_to_slot_or_del(pack, ITEM_SLOT_BACK, initial = TRUE)
	var/obj/item/restraints/handcuffs/outpost_police/used/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.set_handcuffed(cuffs)
	officer.start_pulling(suspect)

	var/obj/structure/overmap/ship/ship = wanted_ship(suspect, 5000)
	test_ships += ship
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 55) // 3 stars -> 600 s (OUTPOST_POLICE_JAIL[3])

	RegisterSignal(suspect, COMSIG_MOVABLE_MOVED, PROC_REF(note_move))
	RegisterSignal(officer, COMSIG_MOVABLE_MOVED, PROC_REF(note_move))
	TEST_ASSERT(prison.book_player(suspect, officer, warrant), "book_player() did not book the three-star suspect into the lockup")
	UnregisterSignal(suspect, COMSIG_MOVABLE_MOVED)
	UnregisterSignal(officer, COMSIG_MOVABLE_MOVED)

	TEST_ASSERT_EQUAL(forced_moves, 0, "book_player() used forceMove [forced_moves] time(s) on the suspect or officer")
	TEST_ASSERT_NULL(suspect.handcuffed, "The booked inmate was left in handcuffs")
	TEST_ASSERT(istype(suspect.w_uniform, /obj/item/clothing/under/rank/prisoner/outpost_police), "The booked inmate is not wearing a prison jumpsuit ([suspect.w_uniform?.type])")
	TEST_ASSERT(istype(suspect.shoes, /obj/item/clothing/shoes/sneakers/orange/outpost_police), "The booked inmate is not wearing prison sneakers ([suspect.shoes?.type])")
	TEST_ASSERT_EQUAL(suspect.wear_id, id_card, "Stripping removed the inmate's ID card")
	var/obj/structure/closet/secure_closet/personal/outpost_police/wing_locker = pack.loc
	TEST_ASSERT(istype(wing_locker) && get_area(wing_locker) == prison.wing, "The inmate's backpack was not stored in a front-room lockup locker ([pack.loc])")
	TEST_ASSERT_EQUAL(tool.loc, pack, "Items inside the inmate's backpack were lost during property storage")
	TEST_ASSERT(prison.in_cell_block(suspect), "The booked inmate did not step out into the cell block")
	TEST_ASSERT(prison.in_front_room(officer), "The booking officer did not step back out into the front room")
	TEST_ASSERT(inner.density && !inner.operating && outer.density && !outer.operating, "Processing's doors were not both shut after booking")
	TEST_ASSERT(prison.holds(suspect.mind) && prison.is_inmate(suspect) && prison.has_inmates(), "The wing does not record the booked suspect as a held inmate")
	TEST_ASSERT_EQUAL(police.cell_holding(suspect.mind), prison, "police.cell_holding() did not return the lockup holding the inmate")
	TEST_ASSERT(police.in_custody(suspect), "A held lockup inmate is not in police custody")
	TEST_ASSERT_EQUAL(greeter.last_line, "Fresh one.", "Yard prisoner did not greet the new inmate")

	var/datum/prison_sentence/sentence = prison.sentence_for(suspect)
	TEST_ASSERT_NOTNULL(sentence, "No /datum/prison_sentence was created for the booked inmate")
	TEST_ASSERT_EQUAL(sentence.total_seconds, 600, "Three-star sentence is [sentence.total_seconds] s, not 600 s") // OUTPOST_POLICE_JAIL[3]

	// Held in custody: warrant heat never decays on tick_warrants()
	warrant.last_crime_at = world.time - 10 MINUTES
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 55, "A held lockup inmate's warrant decayed from 55 to [warrant.heat]")

	// Sentence clock ticks while clientless, asleep, and in critical condition
	TEST_ASSERT_NULL(suspect.client, "Setup: test player unexpectedly has a live client")
	prison.inmate_tick(20)
	TEST_ASSERT_EQUAL(sentence.seconds_served, 20, "Sentence did not tick while logged out ([sentence.seconds_served] s)")
	suspect.Sleeping(20 SECONDS)
	prison.inmate_tick(20)
	suspect.SetSleeping(0)
	TEST_ASSERT_EQUAL(sentence.seconds_served, 40, "Sentence did not tick while asleep ([sentence.seconds_served] s)")
	ADD_TRAIT(suspect, TRAIT_CRITICAL_CONDITION, REF(src))
	prison.inmate_tick(20)
	REMOVE_TRAIT(suspect, TRAIT_CRITICAL_CONDITION, REF(src))
	TEST_ASSERT_EQUAL(sentence.seconds_served, 60, "Sentence did not tick while in crit ([sentence.seconds_served] s)")

	// Climbing stars inside raises total_seconds while keeping seconds_served; dropping heat never shrinks total_seconds
	warrant.heat = 100 // 4 stars -> 900 s (OUTPOST_POLICE_JAIL[4])
	prison.inmate_tick(1)
	TEST_ASSERT_EQUAL(sentence.total_seconds, 900, "Raising warrant to four stars left total_seconds at [sentence.total_seconds], not 900")
	TEST_ASSERT_EQUAL(sentence.seconds_served, 61, "Raising total_seconds lost seconds_served ([sentence.seconds_served])")
	warrant.heat = 55
	prison.inmate_tick(1)
	TEST_ASSERT_EQUAL(sentence.total_seconds, 900, "Lowering warrant heat shrank total_seconds from 900 to [sentence.total_seconds]")

	// 3+ stars cannot bail out even with a solvent crew account; serving the remaining time releases the inmate
	prison.inmate_tick(35)
	TEST_ASSERT(prison.holds(suspect.mind), "A three-star inmate was bailed out before serving their term")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 5000, "Bail retry charged a three-star inmate's crew")

	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = guard_test_spawn(prison, get_turf(suspect))
	prison.inmate_tick(900)
	TEST_ASSERT(!prison.holds(suspect.mind) && !prison.is_inmate(suspect), "An inmate who served their full sentence is still held")
	TEST_ASSERT_NULL(police.cell_holding(suspect.mind), "cell_holding() still returned the lockup after release")
	TEST_ASSERT(!police.in_custody(suspect), "A released inmate remained in custody")
	TEST_ASSERT_NULL(police.get_warrant(suspect.mind), "Release did not close the inmate's warrant as served")
	TEST_ASSERT(WEAKREF(suspect) in prison.processing_release_refs, "Release did not queue the inmate for Processing's exit cycle")
	TEST_ASSERT(wing_locker.released_at > 0, "Release did not start the wing property locker's abandonment clock")
	if(guard)
		TEST_ASSERT(findtext(guard.last_line, "You're out."), "On-duty guard did not announce the inmate's release ([guard.last_line])")

	// 1-2 star bail retry every 30 s (OUTPOST_POLICE_BAIL_RETRY): pays fine and releases as soon as the crew account can cover it
	var/turf/yard_tile = inmate_test_yard_tile(prison)
	var/mob/living/carbon/human/bail_inmate = make_player(yard_tile, "lockupbail1")
	var/obj/structure/overmap/ship/bail_ship = wanted_ship(bail_inmate, 0)
	test_ships += bail_ship
	var/datum/outpost_warrant/bail_warrant = police_pin_warrant(police, bail_inmate.mind, 12) // 1 star -> 180 s
	prison.admit_inmate_sentence(bail_inmate, bail_warrant, 1)
	prison.inmate_tick(30)
	TEST_ASSERT(prison.holds(bail_inmate.mind), "A broke one-star inmate was bailed out without funds")
	bail_ship.ship_account.account_balance = 2000
	prison.inmate_tick(29)
	TEST_ASSERT(prison.holds(bail_inmate.mind), "Bail retry fired before 30 seconds elapsed") // OUTPOST_POLICE_BAIL_RETRY
	prison.inmate_tick(1)
	TEST_ASSERT(!prison.holds(bail_inmate.mind), "Bail retry did not release a funded one-star inmate at 30 seconds")
	TEST_ASSERT_NULL(police.get_warrant(bail_inmate.mind), "Bail release did not close the one-star warrant")
	TEST_ASSERT(!bail_ship.ship_account.account_balance || bail_ship.ship_account.account_balance < 2000, "Bail release did not deduct the fine from the crew account")

	// Processing softlock recovery: an incapacitated inmate in OUTPOST_PROCESSING_IN times out cleanly and re-opens inner on bump;
	// a released person stalling inside Processing times out cleanly, is not blocked by processing_outsider_inside() on outer bump,
	// and never opens outer while a held inmate is inside Processing.
	var/mob/living/carbon/human/stalled_inmate = police_arrest_person(prison.processing_turfs[1])
	var/datum/outpost_warrant/stalled_warrant = police_pin_warrant(police, stalled_inmate.mind, 55)
	prison.admit_inmate_sentence(stalled_inmate, stalled_warrant, 3)
	stalled_inmate.Sleeping(20 SECONDS)
	prison.processing_state = "coming_in" // OUTPOST_PROCESSING_IN
	prison.processing_who_ref = WEAKREF(stalled_inmate)
	prison.processing_seconds = 0
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "OUTPOST_PROCESSING_IN stayed wedged on an unconscious player inmate") // OUTPOST_PROCESSING_IDLE
	stalled_inmate.SetSleeping(0)
	stalled_inmate.Knockdown(20 SECONDS)
	prison.processing_state = "coming_in" // OUTPOST_PROCESSING_IN
	prison.processing_who_ref = WEAKREF(stalled_inmate)
	prison.processing_seconds = 0
	prison.processing_tick(15) // OUTPOST_PRISON_PROCESSING_WAIT
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "OUTPOST_PROCESSING_IN never timed out on a conscious downed player inmate") // OUTPOST_PROCESSING_IDLE
	stalled_inmate.SetKnockdown(0)
	stalled_inmate.set_resting(FALSE)
	stalled_inmate.set_body_position(STANDING_UP)
	var/inner_shut_deadline = world.time + 4 SECONDS
	while((!inner.density || inner.operating) && world.time < inner_shut_deadline)
		prison.processing_work_door(inner, FALSE)
		sleep(1)
	TEST_ASSERT(inner.density && outer.density, "Setup: Processing doors were not shut before inner bump recovery")
	inner.Bumped(stalled_inmate)
	TEST_ASSERT_EQUAL(prison.processing_state, "coming_in", "Bumping the inner Processing door did not start OUTPOST_PROCESSING_IN for a recovered held inmate") // OUTPOST_PROCESSING_IN
	var/mob/living/carbon/human/released_walker = police_arrest_person(prison.processing_turfs[2])
	prison.processing_release_refs |= WEAKREF(released_walker)
	prison.processing_done()
	var/deadline = world.time + 4 SECONDS
	while((!inner.density || inner.operating) && world.time < deadline)
		prison.processing_work_door(inner, FALSE)
		sleep(1)
	TEST_ASSERT(!prison.try_start_processing_release(released_walker), "Processing started a release cycle to the front room while a held inmate stood inside Processing")
	stalled_inmate.forceMove(yard_tile)
	prison.release_inmate(stalled_inmate.mind, TRUE)
	prison.processing_release_refs -= WEAKREF(stalled_inmate)
	TEST_ASSERT(!prison.processing_outsider_inside(released_walker), "processing_outsider_inside(except) counted the released person inside Processing against themselves")
	outer.Bumped(released_walker)
	TEST_ASSERT_EQUAL(prison.processing_state, "releasing", "Bumping the shut outer Processing door did not start OUTPOST_PROCESSING_RELEASE for a released inmate inside") // OUTPOST_PROCESSING_RELEASE
	prison.processing_tick(15) // OUTPOST_PRISON_PROCESSING_WAIT
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "OUTPOST_PROCESSING_RELEASE never timed out when a released player stalled inside Processing") // OUTPOST_PROCESSING_IDLE
	TEST_ASSERT(WEAKREF(released_walker) in prison.processing_release_refs, "Timing out OUTPOST_PROCESSING_RELEASE dropped the released player from processing_release_refs before they reached the front room")
	deadline = world.time + 4 SECONDS
	while((!outer.density || outer.operating) && world.time < deadline)
		prison.processing_work_door(outer, FALSE)
		sleep(1)
	outer.Bumped(released_walker)
	TEST_ASSERT_EQUAL(prison.processing_state, "releasing", "Bumping the shut outer door after a timeout did not re-open OUTPOST_PROCESSING_RELEASE") // OUTPOST_PROCESSING_RELEASE
	released_walker.forceMove(front_clear)
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing stayed in OUTPOST_PROCESSING_RELEASE after the released inmate entered the front room") // OUTPOST_PROCESSING_IDLE
	deadline = world.time + 4 SECONDS
	while((!outer.density || outer.operating) && world.time < deadline)
		prison.processing_work_door(outer, FALSE)
		sleep(1)
	REMOVE_TRAIT(officer, TRAIT_AI_PAUSED, REF(src))

// =========================================================================
// 3. CONTAINMENT, ESCAPE/CARRY-OUT, RIOTS, GUARD BATON & CRIT AID, DEATH, QDEL
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_inmates_containment_escape_riot_death
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_inmates_containment_escape_riot_death/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/datum/outpost_police/police = outpost.police
	dispatch_clear(police)
	police.sleep_tick()

	var/turf/yard_tile = inmate_test_yard_tile(prison)
	var/turf/front_tile = inmate_test_front_tile(prison)
	TEST_ASSERT_NOTNULL(yard_tile, "No open yard floor tile found")
	TEST_ASSERT_NOTNULL(front_tile, "No open front-room floor tile found")

	var/mob/living/carbon/human/inmate = make_player(yard_tile, "lockupinmate2")
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, inmate.mind, 55) // 3 stars
	var/datum/prison_sentence/sentence = prison.admit_inmate_sentence(inmate, warrant, 3)

	// Awake upright inmate blocks crates, bags and bluespace teleports; knocked down allows containment while still blocking teleports
	var/obj/structure/closet/crate/box = allocate(/obj/structure/closet/crate, yard_tile)
	box.open()
	TEST_ASSERT(HAS_TRAIT(inmate, "no_containment"), "Awake upright inmate lacks no_containment") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(HAS_TRAIT(inmate, TRAIT_NO_STORAGE_INSERT), "Awake upright inmate lacks TRAIT_NO_STORAGE_INSERT")
	TEST_ASSERT(!box.insertion_allowed(inmate), "An open crate accepted an awake upright inmate")
	TEST_ASSERT(!do_teleport(inmate, front_tile, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "do_teleport() moved a held lockup inmate")
	TEST_ASSERT_EQUAL(get_turf(inmate), yard_tile, "Refused teleport still moved the inmate")

	inmate.Knockdown(10 SECONDS)
	TEST_ASSERT(!HAS_TRAIT(inmate, "no_containment"), "Knocked-down inmate kept no_containment") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(box.insertion_allowed(inmate), "A crate refused an incapacitated inmate")
	TEST_ASSERT(!do_teleport(inmate, front_tile, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "do_teleport() moved a knocked-down held inmate")
	inmate.SetKnockdown(0)
	inmate.set_resting(FALSE)
	inmate.set_body_position(STANDING_UP)
	TEST_ASSERT(HAS_TRAIT(inmate, "no_containment"), "Standing back up did not restore no_containment") // TRAIT_NO_CONTAINMENT
	qdel(box)

	// Friend pulling a downed inmate out gets the jailbreak charge; inmate keeps their hold and return_left waits until they can walk
	var/mob/living/carbon/human/friend = make_player(front_tile, "lockupfriend")
	inmate.Knockdown(10 SECONDS)
	inmate.pulledby = friend
	inmate.forceMove(front_tile)
	prison.inmate_tick(1)
	TEST_ASSERT(police.get_stars(friend.mind) >= 3, "Friend who pulled a downed inmate out did not get at least 3 stars ([police.get_stars(friend.mind)])") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT(prison.holds(inmate.mind), "An inmate pulled out while down lost their sentence hold")
	TEST_ASSERT_EQUAL(sentence.return_left, 20, "Pulled-out inmate did not get 20 s to walk back ([sentence.return_left])") // OUTPOST_POLICE_CELL_RETURN
	prison.inmate_tick(25)
	TEST_ASSERT(prison.holds(inmate.mind) && sentence.return_left == 20, "return_left ticked down while the inmate was still knocked down and pulled")
	inmate.pulledby = null
	inmate.SetKnockdown(0)
	inmate.set_resting(FALSE)
	inmate.set_body_position(STANDING_UP)
	inmate.forceMove(yard_tile)
	prison.inmate_tick(1)
	TEST_ASSERT_EQUAL(sentence.return_left, 0, "Returning inside the cell block did not clear return_left")

	// Voluntary resting or hiding in an unlocked closet outside the wing still ticks return_left; brief flooring pauses without inflating return_left back to 20 s
	var/mob/living/carbon/human/active_inmate = police_arrest_person(yard_tile)
	var/datum/outpost_warrant/active_warrant = police_pin_warrant(police, active_inmate.mind, 55)
	var/datum/prison_sentence/active_sentence = prison.admit_inmate_sentence(active_inmate, active_warrant, 3)
	active_inmate.Knockdown(10 SECONDS)
	active_inmate.pulledby = friend
	active_inmate.forceMove(front_tile)
	prison.inmate_tick(1)
	TEST_ASSERT_EQUAL(active_sentence.return_left, 20, "Setup: active_inmate did not start at 20 s return_left") // OUTPOST_POLICE_CELL_RETURN
	active_inmate.pulledby = null
	active_inmate.SetKnockdown(0)
	active_inmate.set_resting(TRUE)
	active_inmate.set_body_position(LYING_DOWN)
	TEST_ASSERT(prison.inmate_can_walk_back(active_inmate, active_inmate.mind), "Voluntary resting outside the wing fooled inmate_can_walk_back() into pausing return_left")
	prison.inmate_tick(5)
	TEST_ASSERT_EQUAL(active_sentence.return_left, 15, "Voluntary resting kept return_left at [active_sentence.return_left] instead of ticking to 15")
	active_inmate.set_resting(FALSE)
	active_inmate.Knockdown(10 SECONDS)
	prison.inmate_tick(5)
	TEST_ASSERT_EQUAL(active_sentence.return_left, 15, "Genuine knockdown while outside inflated or ticked return_left ([active_sentence.return_left], expected 15)")
	active_inmate.SetKnockdown(0)
	active_inmate.set_body_position(STANDING_UP)
	var/obj/structure/closet/outside_closet = allocate(/obj/structure/closet, front_tile)
	active_inmate.forceMove(outside_closet)
	TEST_ASSERT(prison.inmate_can_walk_back(active_inmate, active_inmate.mind), "Hiding in an unlocked closet outside the wing paused return_left")
	prison.inmate_tick(5)
	TEST_ASSERT_EQUAL(active_sentence.return_left, 10, "Unlocked closet outside the wing did not tick return_left down to 10 ([active_sentence.return_left])")
	outside_closet.welded = TRUE
	TEST_ASSERT(!prison.inmate_can_walk_back(active_inmate, active_inmate.mind), "Being welded inside a closet outside the wing still counted as able to walk back")
	outside_closet.welded = FALSE
	active_inmate.forceMove(front_tile)
	qdel(outside_closet)
	prison.inmate_tick(10)
	TEST_ASSERT(active_sentence.escaped && !prison.holds(active_inmate.mind), "Expiring return_left while resting/uncontained outside did not mark the inmate escaped")

	// Walking out on their own feet is a jailbreak; rebooking resets served and worked-off time to 0
	sentence.seconds_served = 120
	sentence.seconds_worked_off = 50
	SEND_SIGNAL(inmate, COMSIG_MOB_CLIENT_PRE_MOVE, list())
	inmate.forceMove(front_tile)
	prison.inmate_tick(1)
	TEST_ASSERT(sentence.escaped, "Stepping out of the cell block on own feet did not mark the sentence escaped")
	TEST_ASSERT(!prison.holds(inmate.mind) && !police.in_custody(inmate), "An escaped inmate stayed held in custody")
	TEST_ASSERT(!HAS_TRAIT(inmate, "no_containment"), "An escaped inmate kept no_containment") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(police.get_warrant(inmate.mind)?.heat >= 55, "Escaping did not keep the old warrant live with jailbreak heat")

	inmate.forceMove(yard_tile)
	sentence = prison.admit_inmate_sentence(inmate, police.get_warrant(inmate.mind), 3)
	TEST_ASSERT_EQUAL(sentence.seconds_served, 0, "Rebooking an escaped inmate kept seconds_served ([sentence.seconds_served])")
	TEST_ASSERT_EQUAL(sentence.seconds_worked_off, 0, "Rebooking an escaped inmate kept seconds_worked_off ([sentence.seconds_worked_off])")
	TEST_ASSERT(!sentence.escaped && prison.holds(inmate.mind), "Rebooking an escaped inmate did not restore an active hold")

	// Rioters ignore held inmates unless provoked, while still targeting non-inmate intruders in the cell block
	var/mob/living/carbon/human/visitor = make_player(yard_tile, "lockupvisitor")
	var/mob/living/carbon/human/npc/outpost_prisoner/rioter = trouble_awake_prisoner(prison, yard_tile)
	var/mob/living/carbon/human/npc/outpost_prisoner/witness_prisoner = trouble_awake_prisoner(prison, yard_tile)
	prison.trouble_enabled = TRUE
	TEST_ASSERT(breakout_riot(prison), "Riot did not start")
	var/list/riot_targets = prison.staff_in_reach(rioter)
	TEST_ASSERT(!(inmate in riot_targets), "A rioter targeted an unprovoking held player inmate")
	TEST_ASSERT(visitor in riot_targets, "A rioter ignored a non-inmate intruder standing in the yard")
	prison.end_riot()

	// Witnessed player kill of an NPC prisoner reports OUTPOST_CRIME_KILL_CIVILIAN and raises sentence if stars climb
	var/datum/outpost_warrant/murder_warrant = police.get_warrant(inmate.mind)
	murder_warrant.heat = 55
	sentence.total_seconds = 600
	var/mob/living/carbon/human/npc/outpost_prisoner/slain = trouble_awake_prisoner(prison, yard_tile)
	TEST_ASSERT(witness_prisoner.stat == CONSCIOUS, "Setup: witness prisoner is not conscious")
	slain.note_player_damage_hit(inmate)
	slain.death()
	TEST_ASSERT(murder_warrant.heat > 55, "Killing an NPC prisoner in view of another prisoner did not add murder heat") // OUTPOST_CRIME_KILL_CIVILIAN
	TEST_ASSERT(sentence.total_seconds > 600, "Climbing stars from a witnessed yard kill did not lengthen the sentence ([sentence.total_seconds] s)")

	// Guard baton: mop in hand stays peaceful, knife in hand or unprovoked blow warrants the baton, 10 s self-defense does not, knockdown stops it
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = guard_test_spawn(prison, yard_tile)
	TEST_ASSERT_NOTNULL(guard, "No lockup guard spawned for the baton and crit tests")
	var/obj/item/mop/mop = allocate(/obj/item/mop)
	inmate.put_in_active_hand(mop)
	TEST_ASSERT(!prison.inmate_holds_weapon(inmate) && !prison.inmate_baton_warranted(inmate), "Holding a mop warranted the guard's baton")
	inmate.dropItemToGround(mop)
	qdel(mop)

	var/obj/item/knife/kitchen/knife = allocate(/obj/item/knife/kitchen)
	inmate.put_in_active_hand(knife)
	TEST_ASSERT(prison.inmate_holds_weapon(inmate) && prison.inmate_baton_warranted(inmate), "Holding a kitchen knife in the yard did not warrant the guard's baton")
	inmate.dropItemToGround(knife)
	qdel(knife)

	var/obj/structure/table/reinforced/prison_hatch/hatch
	var/obj/machinery/door/window/outpost_prison_yard/yard_windoor
	var/obj/machinery/door/airlock/security/prison_staff/staff_door
	for(var/turf/tile as anything in prison.cell_block)
		if(!hatch)
			hatch = locate() in tile
			if(hatch)
				yard_windoor = locate() in tile
		if(!staff_door)
			staff_door = locate() in tile
	TEST_ASSERT_NOTNULL(hatch, "No serving hatch found on the cell-block perimeter")
	TEST_ASSERT_NOTNULL(yard_windoor, "No yard hatch window found on the serving hatch")
	TEST_ASSERT_NOTNULL(staff_door, "No staff airlock found on the cell-block perimeter")
	var/turf/hatch_approach
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(get_turf(hatch), direction)
		if(candidate && prison.in_cell_block(candidate) && isopenturf(candidate) && !candidate.is_blocked_turf())
			hatch_approach = candidate
			break
	var/turf/door_approach
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(get_turf(staff_door), direction)
		if(candidate && prison.in_cell_block(candidate) && isopenturf(candidate) && !candidate.is_blocked_turf())
			door_approach = candidate
			break
	TEST_ASSERT_NOTNULL(hatch_approach, "No open yard approach tile beside the serving hatch")
	TEST_ASSERT_NOTNULL(door_approach, "No open yard approach tile beside the staff airlock")

	var/obj/item/food/prison_ration/ration = allocate(/obj/item/food/prison_ration, get_turf(hatch))
	inmate.forceMove(hatch_approach)
	inmate.set_combat_mode(TRUE)
	TEST_ASSERT(!prison.note_inmate_breakout(inmate, ration), "A ration bar on a serving hatch counted as a breakout target")
	TEST_ASSERT(!prison.note_inmate_breakout(inmate, yard_windoor), "The yard hatch window counted as a breakout target")
	inmate.UnarmedAttack(ration, TRUE)
	TEST_ASSERT(!prison.inmate_baton_warranted(inmate), "Picking up food off a serving hatch in combat mode warranted the guard's baton")
	inmate.dropItemToGround(ration)
	qdel(ration)
	inmate.UnarmedAttack(yard_windoor, TRUE)
	TEST_ASSERT(!prison.inmate_baton_warranted(inmate), "Opening the yard hatch window in combat mode warranted the guard's baton")
	inmate.forceMove(door_approach)
	inmate.UnarmedAttack(staff_door, TRUE)
	TEST_ASSERT(!prison.inmate_baton_warranted(inmate), "Bare-hand clicking a staff airlock in combat mode warranted the guard's baton")
	TEST_ASSERT(prison.note_inmate_breakout(inmate, staff_door), "Hacking or battering a staff airlock did not flag the inmate for the baton")
	TEST_ASSERT(prison.inmate_baton_warranted(inmate), "inmate_baton_warranted() stayed false after flagging a staff-door breakout")
	sentence.baton_until = 0
	inmate.set_combat_mode(FALSE)
	inmate.forceMove(yard_tile)

	prison.note_inmate_provoked(inmate, rioter)
	TEST_ASSERT(!prison.note_inmate_attack(inmate, rioter, ATTACKER_DAMAGING_ATTACK), "Hitting back within the 10 s self-defense window warranted the guard's baton")
	TEST_ASSERT(!prison.inmate_baton_warranted(inmate), "Self-defense left inmate_baton_warranted() true")

	TEST_ASSERT(prison.note_inmate_attack(inmate, witness_prisoner, ATTACKER_DAMAGING_ATTACK), "An unprovoked hit in the yard did not flag the inmate for the baton")
	TEST_ASSERT(prison.inmate_baton_warranted(inmate), "inmate_baton_warranted() was false after an unprovoked hit")
	prison.dispatch_guards()
	TEST_ASSERT_EQUAL(guard.last_line, "Hands off!", "Guard did not call 'Hands off!' on first baton response ([guard.last_line])")
	TEST_ASSERT(inmate.getStaminaLoss() > 0, "Guard's stun baton blow dealt no real stamina damage")
	inmate.Knockdown(10 SECONDS)
	TEST_ASSERT(!prison.inmate_baton_warranted(inmate), "Guard kept batoning an inmate who was already knocked down")
	prison.dispatch_guards()
	TEST_ASSERT_NULL(guard.response, "Guard kept their inmate baton response after the inmate went down")
	inmate.SetKnockdown(0)
	inmate.setStaminaLoss(0)
	inmate.set_resting(FALSE)
	inmate.set_body_position(STANDING_UP)
	sentence.baton_until = 0

	// Guard crit first aid & medkit supply splitting/stow: splits stacks instead of draining the office medkit and never deletes stowed stacks on settle
	var/obj/item/storage/medkit/kit = prison.guard_first_aid_kit()
	TEST_ASSERT_NOTNULL(kit, "Quartermain Depot's lockup office has no stocked first-aid kit")
	var/sutures_before = 0
	var/obj/item/stack/medical/suture/kit_suture
	for(var/obj/item/stack/medical/suture/suture in kit)
		sutures_before += suture.amount
		if(!kit_suture && suture.amount > 2)
			kit_suture = suture
	TEST_ASSERT_NOTNULL(kit_suture, "Office medkit had no suture stack with more than 2 charges")
	var/turf/old_guard_turf = get_turf(guard)
	var/turf/kit_spot = prison.guard_spot_beside(kit) || get_turf(kit)
	guard.forceMove(kit_spot)
	TEST_ASSERT(guard.take_one_crit_supply(kit_suture), "take_one_crit_supply() failed to split sutures from the office medkit")
	TEST_ASSERT_EQUAL(kit_suture.loc, kit, "take_one_crit_supply() pulled the entire suture stack out of the office medkit instead of splitting")
	var/obj/item/stack/medical/suture/guard_suture = locate() in guard.get_all_contents_type(/obj/item/stack/medical/suture)
	TEST_ASSERT_NOTNULL(guard_suture, "Guard had no split suture stack after take_one_crit_supply()")
	TEST_ASSERT_EQUAL(guard_suture.amount, 2, "take_one_crit_supply() took [guard_suture.amount] sutures instead of 2")
	if(!guard.is_holding(guard_suture))
		human_npc_take_in_hand(guard, guard_suture)
	guard.stow_crit_supplies()
	sleep(1)
	var/sutures_after = 0
	for(var/obj/item/stack/medical/suture/suture in kit)
		sutures_after += suture.amount
	TEST_ASSERT_EQUAL(sutures_after, sutures_before, "Stowing unused sutures back into the office medkit lost charges ([sutures_after] vs [sutures_before])")
	var/bruise_before = 0
	for(var/obj/item/stack/medical/bruise_pack/pack in kit)
		bruise_before += pack.amount
	guard.adjustBruteLoss(25)
	var/obj/item/stack/medical/taken_bruise = guard.take_treatment_from(kit)
	TEST_ASSERT_NOTNULL(taken_bruise, "take_treatment_from() failed to pull a dressing for an injured guard")
	TEST_ASSERT_EQUAL(taken_bruise.amount, 1, "take_treatment_from() took [taken_bruise.amount] charges instead of splitting 1")
	guard.stow_crit_supplies()
	sleep(1)
	var/bruise_after = 0
	for(var/obj/item/stack/medical/bruise_pack/pack in kit)
		bruise_after += pack.amount
	TEST_ASSERT_EQUAL(bruise_after, bruise_before, "Stowing a split bruise pack back into the office medkit deleted it on settle ([bruise_after] vs [bruise_before])")
	var/obj/item/reagent_containers/hypospray/medipen/kit_pen = locate() in kit
	TEST_ASSERT_NOTNULL(kit_pen, "Office medkit has no epinephrine medipen")
	TEST_ASSERT(guard.take_one_crit_supply(kit_pen), "take_one_crit_supply() failed to take the medipen")
	if(!guard.is_holding(kit_pen))
		human_npc_take_in_hand(guard, kit_pen)
	guard.stow_crit_supplies()
	sleep(1)
	TEST_ASSERT(!QDELETED(kit_pen) && kit_pen.loc == kit, "Stowing a locked medipen back into the office medkit deleted it on settle")
	guard.adjustBruteLoss(-25)
	guard.forceMove(old_guard_turf)
	inmate.adjustOxyLoss(120)
	inmate.updatehealth()
	TEST_ASSERT(prison.guard_in_crit(inmate), "Inmate at [inmate.health] health did not register as in crit")
	TEST_ASSERT_EQUAL(prison.guard_pick_crit_patient(list(guard)), inmate, "guard_pick_crit_patient() did not select the inmate in crit")
	var/datum/outpost_guard_response/crit_job = guard.give_response("crit", 5, "crit:[REF(inmate)]", inmate) // OUTPOST_GUARD_PRIORITY_CRIT
	guard.take_crit_supplies_from(kit, inmate, FALSE)
	var/obj/item/aid = guard.carried_crit_item(inmate, FALSE)
	TEST_ASSERT(istype(aid, /obj/item/reagent_containers/hypospray/medipen), "Guard did not pull the epinephrine medipen first ([aid?.type])")
	TEST_ASSERT(guard.apply_crit_item(crit_job, inmate, aid), "Guard failed to inject the epinephrine medipen into the crit inmate")
	TEST_ASSERT(inmate.reagents.has_reagent(/datum/reagent/medicine/epinephrine), "Crit inmate received no epinephrine from the guard's medipen")
	guard.end_response(cancel_ai = FALSE)
	inmate.setOxyLoss(0)
	inmate.updatehealth()

	// Death in custody: ends sentence, closes warrant as served, leaves body intact with ID, queues carry-out, and opens Processing doors when no guard can carry
	var/obj/item/card/id/advanced/inmate_id = allocate(/obj/item/card/id/advanced)
	inmate.equip_to_slot_or_del(inmate_id, ITEM_SLOT_ID, initial = TRUE)
	inmate.death()
	TEST_ASSERT(!QDELETED(inmate), "Dying in the lockup deleted the player's body")
	TEST_ASSERT_EQUAL(inmate.wear_id, inmate_id, "Dying in the lockup stripped the player's ID")
	TEST_ASSERT(!prison.holds(inmate.mind) && sentence.released, "Death in custody did not end the inmate's sentence")
	TEST_ASSERT_NULL(police.get_warrant(inmate.mind), "Death in custody did not close the inmate's warrant as served")
	TEST_ASSERT_EQUAL(prison.next_dead_inmate_body(), inmate, "Dead inmate in the yard was not queued for front-room carry-out")
	TEST_ASSERT(prison.has_able_corpse_guard() && !prison.corpse_doors_open(), "Processing fallback opened with an able on-duty guard present")
	guard.death()
	TEST_ASSERT(!prison.has_able_corpse_guard() && prison.corpse_doors_open(), "corpse_doors_open() did not engage when no guard could carry the body out")
	inmate.set_stat(CONSCIOUS)
	prison.prune_dead_inmate_bodies()
	TEST_ASSERT(!(WEAKREF(inmate) in prison.dead_inmate_bodies), "Reviving a dead inmate in the yard left them in dead_inmate_bodies")
	TEST_ASSERT(WEAKREF(inmate) in prison.processing_release_refs, "Reviving a former inmate in the yard did not queue them in processing_release_refs to exit Processing")

	// Wing deletion drops active holds and traits without closing live warrants (design 14 #28)
	var/mob/living/carbon/human/survivor = make_player(yard_tile, "lockupsurvivor")
	var/datum/outpost_warrant/live_warrant = police_pin_warrant(police, survivor.mind, 55)
	prison.admit_inmate_sentence(survivor, live_warrant, 3)
	TEST_ASSERT(police.cell_holding(survivor.mind) == prison, "Setup: survivor is not held by the lockup")
	qdel(prison)
	TEST_ASSERT_NULL(outpost.prison, "Deleting the lockup left outpost.prison set")
	TEST_ASSERT_NULL(police.cell_holding(survivor.mind), "Deleting the lockup left cell_holding() pointing at it")
	TEST_ASSERT(!HAS_TRAIT(survivor, "no_containment"), "Deleting the lockup left no_containment on the former inmate") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT_EQUAL(police.get_warrant(survivor.mind), live_warrant, "Deleting the lockup closed a live warrant instead of only dropping the hold")
	TEST_ASSERT_EQUAL(live_warrant.heat, 55, "Deleting the lockup altered the live warrant's heat")
