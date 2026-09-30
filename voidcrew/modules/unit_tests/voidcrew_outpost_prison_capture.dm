/**
 * Capture: members dragging downed or cuffed prisoners back through the staff doors, cuffs and
 * what they cost, riots that end once every rioter is cuffed, down, shut in a cell or gone, and
 * the lockdown a rioter shut in a cell owes.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with tick() with their own processing stopped;
 * nobody is on the level, so the AI sleeps. Fixtures are in voidcrew_outpost_prison_helpers.dm;
 * trouble_fund() and trouble_expected_drift() are in voidcrew_outpost_prison_trouble.dm.
 */

/// Bolts `cell` shut (closing its door first), or unbolts it, and refreshes where prisoners can walk
/datum/unit_test/voidcrew_outpost_management/proc/capture_bolt(datum/outpost_prison/prison, datum/outpost_prison_cell/cell, bolt = TRUE)
	var/obj/machinery/door/airlock/door = cell.door()
	if(bolt)
		if(!door.density)
			door.close()
		door.bolt()
	else
		door.unbolt()
	prison.refresh_reach()
	return door

/datum/unit_test/voidcrew_outpost_management/proc/capture_cuffed(mob/living/basic/outpost_prisoner/prisoner)
	return !!prisoner.cuffs

/datum/unit_test/voidcrew_outpost_management/proc/capture_uncuffed(mob/living/basic/outpost_prisoner/prisoner)
	return !prisoner.cuffs && !prisoner.cuff_work

/// Whether the prison's log has an entry containing `text`
/datum/unit_test/voidcrew_outpost_management/proc/capture_logged(datum/outpost_prison/prison, text)
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], text))
			return TRUE
	return FALSE

// ===== DRAGGING THROUGH THE STAFF DOORS =====

/datum/unit_test/voidcrew_outpost_prison_capture_drag
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_capture_drag/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("dragowner")
	TEST_ASSERT_NOTNULL(home, "The drag test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(staff_door, "The staff door is not where the map puts it")
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 8, 5), "dragowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 10, 5), "dragvisitor")
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 9, 5))
	staff_door.autoclose = FALSE
	staff_door.open()
	TEST_ASSERT(!staff_door.density, "The staff door did not open")

	// On their feet, the open door still stops them.
	TEST_ASSERT(!staff_door.CanAllowThrough(prisoner, NORTH), "An open staff door let a prisoner on their feet through")
	// Down, nobody dragging: still stopped.
	prisoner.adjustStaminaLoss(200)
	TEST_ASSERT(prisoner.can_be_dragged(), "A prisoner in stamina crit cannot be dragged")
	TEST_ASSERT(!staff_door.CanAllowThrough(prisoner, NORTH), "A downed prisoner nobody drags got through the staff door")
	// Dragged by a member of the wing, through they go.
	warden.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(warden.pulling, prisoner, "The warden could not pull a downed prisoner")
	TEST_ASSERT(staff_door.CanAllowThrough(prisoner, NORTH), "A member could not drag a downed prisoner through the staff door")
	// Their own AI still never paths through.
	var/datum/can_pass_info/pass_info = new(prisoner, null)
	TEST_ASSERT(!staff_door.CanAStarPass(NORTH, pass_info), "A prisoner's own pathing goes through the staff door")
	warden.stop_pulling()

	// A visitor never takes one through, even with visitors let in.
	prison.set_visitors_allowed(TRUE, warden)
	visitor.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(visitor.pulling, prisoner, "A visitor could not pull a downed prisoner")
	TEST_ASSERT(!staff_door.CanAllowThrough(prisoner, NORTH), "A visitor dragged a prisoner through the staff door")
	visitor.stop_pulling()
	prison.set_visitors_allowed(FALSE, warden)

	// Cuffed counts as well: a member walks a cuffed prisoner on their feet through, office to yard.
	prisoner.setStaminaLoss(0)
	TEST_ASSERT(!prisoner.can_be_dragged(), "A prisoner back on their feet can still be dragged")
	TEST_ASSERT(prisoner.apply_cuffs(allocate(/obj/item/restraints/handcuffs)), "The prisoner could not be cuffed")
	TEST_ASSERT(prisoner.can_be_dragged(), "A cuffed prisoner on their feet cannot be dragged")
	warden.forceMove(prison_spot(home, 9, 6))
	warden.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(warden.pulling, prisoner, "The warden could not pull a cuffed prisoner")
	TEST_ASSERT(staff_door.CanAllowThrough(prisoner, NORTH), "A member could not walk a cuffed prisoner through the staff door")
	warden.Move(prison_spot(home, 9, 7), NORTH)
	warden.Move(prison_spot(home, 9, 8), NORTH)
	TEST_ASSERT_EQUAL(prisoner.loc, prison_spot(home, 9, 7), "The cuffed prisoner was not dragged through into the yard (at [prisoner.x],[prisoner.y])")
	TEST_ASSERT(prison.in_cell_block(prisoner), "The yard past the staff door is not the cell block")
	warden.stop_pulling()

	// A runner caught out on the outpost: on their feet they must be put down first; cuffed, their
	// clock waits and turrets leave them be; walked back into the cell block, they are recaptured.
	var/mob/living/basic/outpost_prisoner/runner = trouble_prisoner(prison, prison_spot(home, 12, 8))
	var/list/bounds = prison.upgrade.footprint_bounds
	var/turf/outside = locate(bounds[1] + 8, bounds[2] - 2, bounds[5])
	TEST_ASSERT(get_area(outside) != prison.wing, "The spot outside the wing is in the wing")
	runner.forceMove(outside)
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "A prisoner outside the wing is not loose")
	TEST_ASSERT(!runner.escaped_rioting, "A prisoner who walked out on their own counts as a rioter")
	var/obj/item/restraints/handcuffs/cable/zipties/ties = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(runner.cuff_refusal(warden, ties), "won't hold still", "A runner on their feet could be cuffed")
	runner.adjustStaminaLoss(200)
	TEST_ASSERT_NULL(runner.cuff_refusal(warden, ties), "A downed runner could not be cuffed")
	TEST_ASSERT(runner.apply_cuffs(ties), "The downed runner could not be cuffed")
	TEST_ASSERT(istype(runner.cuffs, /obj/item/restraints/handcuffs/cable/zipties/used), "Zipties went on as [runner.cuffs?.type], not a used pair")
	runner.setStaminaLoss(0)
	var/clock = runner.loose_left
	prison.tick(60)
	TEST_ASSERT_EQUAL(runner.loose_left, clock, "A cuffed runner's loose clock ran ([clock] s to [runner.loose_left] s)")
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "A cuffed runner outside the wing stopped being loose")
	TEST_ASSERT(!is_hostile_creature(runner), "A turret would shoot a cuffed runner")
	TEST_ASSERT(!prison.protective_custody(), "A runner left cuffed keeps protective custody going")
	TEST_ASSERT(!prison.incident_ongoing(), "A runner left cuffed keeps the incident going")
	runner.forceMove(prison_spot(home, 12, 8))
	prison.tick(1)
	TEST_ASSERT_NULL(runner.trouble, "A cuffed runner walked back into the cell block was not recaptured")
	TEST_ASSERT(istype(runner.ai_controller, /datum/ai_controller/basic_controller/outpost_prisoner), "A recaptured runner is not back on the prisoner AI")
	TEST_ASSERT(runner.cuffs, "Recapture took the cuffs off")
	TEST_ASSERT_EQUAL(runner.lockdown_left, 0, "A runner who walked out on their own owes lockdown")

	// Loose in the office, a prisoner is past the staff doors: the open entrance lets them out and
	// their pathing goes through it. Shut, it still won't open for them.
	var/obj/machinery/door/airlock/security/prison_staff/entrance = locate() in prison_spot(home, 9, 1)
	TEST_ASSERT_NOTNULL(entrance, "The entrance is not where the map puts it")
	var/mob/living/basic/outpost_prisoner/bolter = trouble_prisoner(prison, prison_spot(home, 10, 8))
	bolter.forceMove(prison_spot(home, 9, 3))
	prison.tick(1)
	TEST_ASSERT_EQUAL(bolter.trouble, "loose", "A prisoner loose in the office is [bolter.trouble]") // PRISONER_TROUBLE_LOOSE
	entrance.autoclose = FALSE
	entrance.open()
	TEST_ASSERT(!entrance.density, "The entrance did not open")
	TEST_ASSERT(entrance.CanAllowThrough(bolter, NORTH), "The open entrance held a loose prisoner in")
	TEST_ASSERT(entrance.CanAStarPass(SOUTH, new /datum/can_pass_info(bolter)), "A loose prisoner's pathing does not go through the open entrance")
	TEST_ASSERT(!entrance.allowed(bolter), "The entrance opens for a loose prisoner")
	TEST_ASSERT(!staff_door.CanAllowThrough(prisoner, NORTH), "Another prisoner's escape let a prisoner in custody through a staff door")
	settle_prison_air(home)

// ===== CUFFS =====

/datum/unit_test/voidcrew_outpost_prison_cuffs
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_cuffs/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("cuffsowner")
	TEST_ASSERT_NOTNULL(home, "The cuffs test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 7, 8), "cuffsowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 11, 8), "cuffsvisitor")
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/other = trouble_prisoner(prison, prison_spot(home, 12, 8))
	var/obj/item/restraints/handcuffs/cuffs = allocate(__IMPLIED_TYPE__)

	// Members only; on their feet only while out of trouble; used zipties are no use.
	TEST_ASSERT_EQUAL(prisoner.cuff_refusal(visitor, cuffs), "members only", "A visitor could cuff a prisoner")
	TEST_ASSERT_NULL(prisoner.cuff_refusal(warden, cuffs), "A member could not cuff a calm prisoner")
	TEST_ASSERT_EQUAL(prisoner.cuff_time(), 40, "Cuffing a prisoner on their feet takes [prisoner.cuff_time()], not 4 s") // PRISONER_CUFF_TIME_STANDING
	for(var/state in list("riot", "breakout", "loose", "fight", "wreck"))
		prisoner.trouble = state
		TEST_ASSERT_EQUAL(prisoner.cuff_refusal(warden, cuffs), "won't hold still", "A prisoner on their feet in [state] trouble could be cuffed")
	prisoner.trouble = null
	prisoner.threaten(warden)
	TEST_ASSERT(prisoner.cuff_refusal(warden, cuffs), "A prisoner squaring up to staff could be cuffed")
	prisoner.cancel_threat()
	prisoner.adjustStaminaLoss(200)
	TEST_ASSERT_EQUAL(prisoner.cuff_time(), 20, "Cuffing a downed prisoner takes [prisoner.cuff_time()], not 2 s") // PRISONER_CUFF_TIME_DOWN
	prisoner.setStaminaLoss(0)
	var/obj/item/restraints/handcuffs/cable/zipties/used/spent = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(prisoner.cuff_refusal(warden, spent), "used up", "Used zipties could cuff a prisoner")

	// A visitor's cuffs never go on.
	visitor.put_in_active_hand(allocate(/obj/item/restraints/handcuffs))
	visitor.set_combat_mode(FALSE)
	click_wrapper(visitor, other)
	TEST_ASSERT(!other.cuff_work && !other.cuffs, "A visitor's cuffs went on")

	// A member's click with cuffs: the prisoner holds still, then is cuffed, and drops what they held.
	var/obj/item/toy/basketball/ball = allocate(__IMPLIED_TYPE__, prisoner.loc)
	TEST_ASSERT(prisoner.take_item(ball), "The prisoner could not pick up the ball")
	warden.put_in_active_hand(cuffs)
	warden.set_combat_mode(FALSE)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(prisoner.cuff_work, "Clicking a prisoner with cuffs did not start cuffing")
	TEST_ASSERT(prisoner.in_trouble() && !prisoner.routine_allowed(), "A prisoner being cuffed kept up their routine")
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_management, capture_cuffed), prisoner), 8 SECONDS), "A member's cuffs never went on")
	TEST_ASSERT_EQUAL(prisoner.cuffs, cuffs, "The prisoner wears [prisoner.cuffs], not the member's cuffs")
	TEST_ASSERT_EQUAL(cuffs.loc, prisoner, "The cuffs are not on the prisoner")
	TEST_ASSERT_NULL(prisoner.held_item, "A cuffed prisoner still holds [prisoner.held_item]")
	TEST_ASSERT_EQUAL(ball.loc, prisoner.loc, "A cuffed prisoner's ball did not drop at their feet")

	// Cuffed: draggable, and nothing else. No blows, riots, eating or taking from the hatch.
	TEST_ASSERT(prisoner.can_be_dragged(), "A cuffed prisoner cannot be dragged")
	TEST_ASSERT_EQUAL(prisoner.move_resist, MOVE_RESIST_DEFAULT, "A cuffed prisoner is too heavy to drag")
	TEST_ASSERT(!prisoner.trouble_can_act() && !prisoner.routine_allowed(), "A cuffed prisoner can still act")
	TEST_ASSERT(!prisoner.can_join_riot(), "A cuffed prisoner could join a riot")
	TEST_ASSERT(!prisoner.early_melee_attack(warden), "A cuffed prisoner could throw a punch")
	var/brute_before = warden.getBruteLoss()
	prisoner.melee_attack(warden, null, TRUE)
	TEST_ASSERT_EQUAL(warden.getBruteLoss(), brute_before, "A cuffed prisoner hurt the warden")
	TEST_ASSERT(!prisoner.confront(warden), "A cuffed prisoner squared up to the warden")
	var/obj/item/food/prison_ration/ration = allocate(__IMPLIED_TYPE__, warden.loc)
	TEST_ASSERT(SEND_SIGNAL(prisoner, COMSIG_MOB_PRE_EAT, ration, warden) & COMSIG_MOB_CANCEL_EAT, "A cuffed prisoner could be fed")
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	TEST_ASSERT_NOTNULL(hatch, "The serving hatch is not where the map puts it")
	var/obj/item/food/prison_ration/meal = allocate(__IMPLIED_TYPE__, hatch.loc)
	prisoner.forceMove(prison_spot(home, 5, 7))
	prison.refresh_prisoner_reach(prisoner)
	prisoner.set_hunger(10)
	prisoner.fend_for_self()
	TEST_ASSERT(!QDELETED(meal) && meal.loc == hatch.loc, "A cuffed prisoner took food off the hatch")
	prisoner.set_hunger(100)
	prisoner.forceMove(prison_spot(home, 8, 8))
	prison.refresh_prisoner_reach(prisoner)
	// tg's cuff overlay shows, and examining them says so.
	var/shows_cuffs = FALSE
	for(var/mutable_appearance/overlay as anything in prisoner.update_overlays())
		if(overlay.icon_state == "handcuff1")
			shows_cuffs = TRUE
	TEST_ASSERT(shows_cuffs, "A cuffed prisoner shows no cuffs")
	TEST_ASSERT(findtext(jointext(prisoner.examine(warden), " "), "handcuffed"), "Examining a cuffed prisoner does not say so")
	// On their feet, cuffed or not, no single blow kills them.
	prisoner.apply_damage(150, BRUTE)
	TEST_ASSERT_EQUAL(prisoner.stat, CONSCIOUS, "One blow killed a cuffed prisoner on their feet")
	prisoner.adjustBruteLoss(-prisoner.getBruteLoss(), forced = TRUE)
	prisoner.recover()

	// Ninety seconds cuffed cost nothing (PRISONER_CUFFED_GRACE); then 6 mood a minute, one more
	// each extra minute (PRISONER_MOOD_CUFFED), and no pay, as with a lock-in.
	var/pay_before = prison.pay_factor(prisoner)
	TEST_ASSERT(pay_before > 0, "A cuffed prisoner paid nothing inside the grace")
	prison.update_cuffed(prisoner, 90)
	TEST_ASSERT_EQUAL(prisoner.cuffed_seconds, 90, "Ninety seconds cuffed counted [prisoner.cuffed_seconds]")
	TEST_ASSERT(!prisoner.cuffs_souring(), "Ninety seconds cuffed already sour a prisoner")
	TEST_ASSERT(drift_is(prisoner, trouble_expected_drift(prisoner)), "Ninety seconds cuffed changed the mood drift to [prisoner.mood_drift_per_minute()]")
	prison.update_cuffed(prisoner, 1)
	TEST_ASSERT(prisoner.cuffs_souring(), "Cuffs past the grace do not sour a prisoner")
	TEST_ASSERT(drift_is(prisoner, trouble_expected_drift(prisoner, extra_loss = 6)), "Cuffed past the grace, mood drifts [prisoner.mood_drift_per_minute()] a minute")
	TEST_ASSERT_EQUAL(prison.pay_factor(prisoner), 0, "A prisoner cuffed past the grace still paid")
	prison.update_cuffed(prisoner, 60)
	TEST_ASSERT(drift_is(prisoner, trouble_expected_drift(prisoner, extra_loss = 7)), "A minute more cuffed, mood drifts [prisoner.mood_drift_per_minute()] a minute")
	TEST_ASSERT(("1 cuffed" in prison.restless_causes()), "The restless causes leave out the cuffs: [jointext(prison.restless_causes(), ", ")]")
	// For good reason (a riot, or lockdown they owe) the clock stands and it costs nothing.
	var/clock = prisoner.cuffed_seconds
	prison.riot_active = TRUE
	TEST_ASSERT(!prisoner.cuffs_souring(), "Cuffs during a riot soured a prisoner")
	TEST_ASSERT(prison.pay_factor(prisoner) > 0, "Cuffs during a riot stopped a prisoner's pay")
	prison.update_cuffed(prisoner, 60)
	TEST_ASSERT_EQUAL(prisoner.cuffed_seconds, clock, "The cuffed clock ran during a riot")
	prison.riot_active = FALSE
	prisoner.lockdown_left = 100
	TEST_ASSERT(!prisoner.cuffs_souring(), "Cuffs on a prisoner owing lockdown soured them")
	prison.update_cuffed(prisoner, 60)
	TEST_ASSERT_EQUAL(prisoner.cuffed_seconds, clock, "The cuffed clock ran while they owe lockdown")
	prisoner.lockdown_left = 0

	// A visitor's empty hand does nothing to the cuffs.
	visitor.drop_all_held_items()
	visitor.forceMove(prison_spot(home, 9, 8))
	click_wrapper(visitor, prisoner)
	TEST_ASSERT(!prisoner.cuff_work && prisoner.cuffs, "A visitor started taking the cuffs off")
	TEST_ASSERT(!prisoner.talk_menu_act(visitor, "Uncuff") && prisoner.cuffs, "A visitor took the cuffs off from the talk menu") // PRISON_TALK_UNCUFF
	// A member's "Uncuff" on the talk menu (an empty hand, not in combat mode): two seconds, and real cuffs go to their hand.
	warden.drop_all_held_items()
	warden.set_combat_mode(FALSE)
	TEST_ASSERT("Uncuff" in prisoner.talk_menu_choices(warden), "A cuffed prisoner's talk menu has no Uncuff")
	TEST_ASSERT(prisoner.talk_menu_act(warden, "Uncuff"), "A member's Uncuff did not take the cuffs off")
	TEST_ASSERT(capture_uncuffed(prisoner), "A member's Uncuff left the cuffs on")
	TEST_ASSERT(warden.is_holding(cuffs), "The real cuffs did not go to the warden's hand")
	TEST_ASSERT(!prisoner.can_be_dragged(), "An uncuffed prisoner on their feet can still be dragged")
	TEST_ASSERT_EQUAL(prisoner.move_resist, MOVE_FORCE_VERY_STRONG, "An uncuffed prisoner is still light enough to drag")
	// The clock falls two seconds a second once they are off (PRISONER_LOCKED_IN_RECOVERY).
	prison.update_cuffed(prisoner, 10)
	TEST_ASSERT_EQUAL(prisoner.cuffed_seconds, clock - 20, "Ten seconds uncuffed left the clock at [prisoner.cuffed_seconds], not [clock - 20]")
	// Cable restraints and zipties are cut away, not handed back.
	var/obj/item/restraints/handcuffs/cable/cable = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(prisoner.apply_cuffs(cable), "Cable restraints did not go on")
	prisoner.remove_cuffs(warden)
	TEST_ASSERT(QDELETED(cable), "Cable restraints were handed back, not cut off")

	// The cuffs drop to the floor when the prisoner dies, beams out or is deleted.
	var/obj/item/restraints/handcuffs/on_body = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(prisoner.apply_cuffs(on_body), "The cuffs did not go on for the death check")
	var/turf/body_spot = get_turf(prisoner)
	prisoner.death()
	TEST_ASSERT(isnull(prisoner.cuffs) && on_body.loc == body_spot, "A dead prisoner's cuffs did not drop to the floor")
	var/obj/item/restraints/handcuffs/leaving_cuffs = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(other.apply_cuffs(leaving_cuffs), "The cuffs did not go on for the release check")
	var/turf/release_spot = get_turf(other)
	prison.release(other)
	TEST_ASSERT_EQUAL(leaving_cuffs.loc, release_spot, "A released prisoner took the cuffs with them")
	var/mob/living/basic/outpost_prisoner/deleted = trouble_prisoner(prison, prison_spot(home, 10, 10))
	var/obj/item/restraints/handcuffs/deleted_cuffs = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(deleted.apply_cuffs(deleted_cuffs), "The cuffs did not go on for the deletion check")
	var/turf/deleted_spot = get_turf(deleted)
	qdel(deleted)
	TEST_ASSERT_EQUAL(deleted_cuffs.loc, deleted_spot, "A deleted prisoner's cuffs went with them")
	settle_prison_air(home)

// ===== RIOTS END WHEN EVERY RIOTER IS DEALT WITH =====

/datum/unit_test/voidcrew_outpost_prison_riot_capture
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_riot_capture/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("riotcaptureowner")
	TEST_ASSERT_NOTNULL(home, "The riot capture test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 8, 8), "grumpy")
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 10, 8), "grumpy")
	var/mob/living/basic/outpost_prisoner/bystander = trouble_prisoner(prison, prison_spot(home, 4, 10), "cheerful")
	set_moods(list(first, second), 20)
	TEST_ASSERT(prison.start_riot("test"), "The riot did not start")
	TEST_ASSERT(first.is_rioting() && second.is_rioting() && !bystander.is_rioting(), "The wrong prisoners joined the riot")
	prison.tick(5)

	// Down, a rioter is still a rioter at large, but held where they lie: not free, and dealt with
	// as far as the riot goes. Their shiv drops and their mood stands. With another free, the riot
	// goes on, and so does its breakout clock.
	var/first_mood = first.mood
	first.adjustStaminaLoss(200)
	TEST_ASSERT_EQUAL(first.trouble, "riot", "A stunned rioter stopped rioting")
	TEST_ASSERT(!first.has_shiv() && (locate(/obj/item/knife/shiv) in first.loc), "A stunned rioter did not drop their shiv")
	TEST_ASSERT(abs(first.mood - first_mood) < 0.01, "Stunning a rioter moved their mood to [first.mood]")
	TEST_ASSERT(first.riot_at_large() && !first.riot_free(), "A downed rioter is not at large, or is free")
	TEST_ASSERT(first.riot_handled(), "A downed rioter does not count as held")
	var/elapsed = prison.riot_elapsed
	prison.tick(10)
	TEST_ASSERT(prison.riot_active, "The riot ended with a rioter free")
	TEST_ASSERT_EQUAL(prison.riot_elapsed, elapsed + 10, "The breakout clock waited with a rioter free")
	// Up and free again, a rioter riots on, and snatches back the shiv at their feet.
	first.setStaminaLoss(0)
	TEST_ASSERT(first.riot_free() && !first.riot_handled(), "A rioter back on their feet is not free")
	TEST_ASSERT(first.has_shiv(), "A rioter back on their feet left their shiv on the floor")

	// Cuffed, a rioter is still a rioter at large, but not free: held.
	first.adjustStaminaLoss(200)
	TEST_ASSERT(first.apply_cuffs(allocate(/obj/item/restraints/handcuffs)), "The downed rioter could not be cuffed")
	first.setStaminaLoss(0)
	TEST_ASSERT_EQUAL(first.trouble, "riot", "A cuffed rioter stopped rioting")
	TEST_ASSERT(first.riot_at_large() && !first.riot_free(), "A cuffed rioter on their feet is not at large, or is free")
	TEST_ASSERT(first.riot_handled(), "A cuffed rioter does not count as held")
	TEST_ASSERT(!first.has_shiv(), "A cuffed rioter picked their shiv back up")

	// Someone who joins once the riot is on counts like the rest.
	bystander.start_rioting(FALSE)
	// Shut in a cell, a rioter is in custody and owes four minutes of lockdown
	// (PRISON_RIOT_LOCKDOWN_TIME, a second of it served), still rioting until the riot ends, and
	// going for nothing in there.
	second.forceMove(second.cell.arrival_turf())
	capture_bolt(prison, second.cell)
	prison.tick(1)
	TEST_ASSERT(!second.riot_at_large(), "A rioter bolted in a cell is still at large")
	TEST_ASSERT_EQUAL(second.trouble, "riot", "A rioter shut in a cell stopped rioting while the riot is on")
	TEST_ASSERT_EQUAL(second.lockdown_left, 239, "A rioter shut in a cell owes [second.lockdown_left] s of lockdown, not 239")
	TEST_ASSERT_NULL(second.riot_target(), "A rioter bolted in a cell went for [second.riot_target()]")
	TEST_ASSERT(prison.riot_active, "The riot ended with a latecomer free in the yard")
	// The last free rioter knocked down: one cuffed in the yard, one shut in, one down, and the riot
	// is over. Every rioter calms to 50 (PRISONER_RIOT_CALM_MOOD) and the wing is subdued
	// (PRISON_SUBDUED_TIME). Only the one shut in owes lockdown; the cuffs stay on.
	bystander.adjustStaminaLoss(200)
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "The riot went on with every rioter cuffed, down or shut in a cell")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in list(first, second, bystander))
		TEST_ASSERT_NULL(rioter.trouble, "[rioter] kept rioting after the riot")
		TEST_ASSERT(abs(rioter.mood - 50) < 1, "[rioter] calmed to [rioter.mood], not 50")
	TEST_ASSERT(second.lockdown_left > 0, "The rioter shut in a cell owes no lockdown after the riot")
	TEST_ASSERT_EQUAL(first.lockdown_left, 0, "The rioter cuffed in the yard owes lockdown")
	TEST_ASSERT(first.cuffs, "The end of the riot took the cuffs off")
	TEST_ASSERT_EQUAL(prison.subdued_left, 360, "The end of the riot subdued the wing for [prison.subdued_left] s, not 360")
	TEST_ASSERT(!prison.incident_open, "The incident outlived the riot")

	// With nobody home a riot is a sit-in, and after ten minutes (PRISON_RIOT_TRANSFER_TIME) the
	// rioters not yet in a cell are transferred, 750 cr each (OUTPOST_PRISON_TRANSFER_FEE). Those
	// already shut in stay.
	prison.admin_calm()
	prison.set_subdued(0)
	first.remove_cuffs()
	bystander.setStaminaLoss(0)
	capture_bolt(prison, second.cell, FALSE)
	first.forceMove(prison_spot(home, 8, 8))
	second.forceMove(prison_spot(home, 10, 8))
	prison.refresh_reach()
	var/datum/bank_account/treasury = trouble_fund(home, 5000)
	var/paid_before = prison.paid_total
	set_moods(list(first, second), 20)
	TEST_ASSERT(prison.start_riot("test"), "The sit-in did not start")
	TEST_ASSERT(first.is_rioting() && second.is_rioting() && !bystander.is_rioting(), "The wrong prisoners joined the sit-in")
	prison.tick(5)
	prison.crew_home_override = FALSE
	second.adjustStaminaLoss(200)
	second.forceMove(second.cell.arrival_turf())
	capture_bolt(prison, second.cell)
	second.setStaminaLoss(0)
	prison.tick(1)
	elapsed = prison.riot_elapsed
	var/absent = prison.riot_absent
	prison.tick(600 - absent - 1)
	TEST_ASSERT(prison.riot_active, "The sit-in was transferred early")
	TEST_ASSERT_EQUAL(prison.riot_elapsed, elapsed, "The breakout clock ran with nobody home")
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "Ten minutes of sit-in did not end the riot")
	TEST_ASSERT_EQUAL(first.phase, "leaving", "The rioter in the yard was not transferred") // PRISONER_LEAVING
	TEST_ASSERT_EQUAL(second.phase, "present", "The rioter shut in a cell was transferred")
	TEST_ASSERT_NULL(second.trouble, "The rioter shut in a cell kept rioting after the transfer")
	var/stipends = prison.paid_total - paid_before
	TEST_ASSERT_EQUAL(treasury.account_balance, 5000 - 750 + stipends, "One transfer took [5000 + stipends - treasury.account_balance], not 750")
	prison.crew_home_override = TRUE
	prison.set_subdued(0)

	// A dead rioter is out of it: with nobody else at large, the riot is over.
	capture_bolt(prison, second.cell, FALSE)
	second.lockdown_left = 0
	second.forceMove(prison_spot(home, 10, 8))
	prison.refresh_reach()
	set_moods(list(second, bystander), 70)
	var/mob/living/basic/outpost_prisoner/doomed = trouble_prisoner(prison, prison_spot(home, 12, 8), "grumpy")
	doomed.set_mood(10)
	TEST_ASSERT(prison.start_riot("test"), "The last riot did not start")
	TEST_ASSERT(doomed.is_rioting() && !second.is_rioting(), "The wrong prisoners joined the last riot")
	doomed.death()
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "The riot went on with its only rioter dead")
	settle_prison_air(home)

// ===== EVERY WAY A RIOT ENDS =====

/**
 * However the crew mixes them, a riot is over once every rioter is dealt with (riot_handled()):
 * cuffed, even outside the cells or in one left unbolted; bolted into any cell, their own or not;
 * or gone, deleted mid-riot.
 */
/datum/unit_test/voidcrew_outpost_prison_riot_end
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// Starts a riot of every prisoner in `rioters` and runs it past its wind-up (PRISON_RIOT_WINDUP). Returns TRUE if they all joined.
/datum/unit_test/voidcrew_outpost_prison_riot_end/proc/riot_of(datum/outpost_prison/prison, list/rioters)
	prison.set_subdued(0)
	set_moods(rioters, 20)
	if(!prison.start_riot("test"))
		return FALSE
	prison.tick(5)
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in rioters)
		if(!rioter.is_rioting())
			return FALSE
	return TRUE

/datum/unit_test/voidcrew_outpost_prison_riot_end/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("riotendowner")
	TEST_ASSERT_NOTNULL(home, "The riot end test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 8, 8), "grumpy")
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 10, 8), "grumpy")
	var/mob/living/basic/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 12, 8), "grumpy")
	var/list/rioters = list(first, second, third)

	// Every rioter cuffed, two in the yard and one in their own cell with the door left unbolted:
	// the riot is over, nobody owes lockdown, and the cuffs stay on.
	TEST_ASSERT(riot_of(prison, rioters), "The first riot did not start with all three")
	third.forceMove(third.cell.arrival_turf())
	prison.refresh_reach()
	TEST_ASSERT(!third.is_confined(), "A rioter behind an unbolted cell door counts as shut in")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in list(first, second))
		TEST_ASSERT(rioter.apply_cuffs(allocate(/obj/item/restraints/handcuffs)), "[rioter] could not be cuffed")
	prison.tick(1)
	TEST_ASSERT(prison.riot_active, "The riot ended with a rioter free in an unbolted cell")
	TEST_ASSERT(third.apply_cuffs(allocate(/obj/item/restraints/handcuffs)), "The rioter in the unbolted cell could not be cuffed")
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "The riot went on with every rioter cuffed")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in rioters)
		TEST_ASSERT_NULL(rioter.trouble, "[rioter] kept rioting after the riot")
		TEST_ASSERT(rioter.cuffs, "The end of the riot took [rioter]'s cuffs off")
		TEST_ASSERT_EQUAL(rioter.lockdown_left, 0, "[rioter] was never shut in a cell but owes lockdown")
	TEST_ASSERT(!prison.incident_open, "The incident outlived the cuffed riot")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in rioters)
		rioter.remove_cuffs()
	third.forceMove(prison_spot(home, 12, 8))
	prison.refresh_reach()

	// Every rioter bolted into a cell, two of them together in one that is neither's: the riot is
	// over, and each owes lockdown. Shut in, a rioter goes for nothing, not even the cell's window.
	var/datum/outpost_prison_cell/spare
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		if(!cell.occupant)
			spare = cell
			break
	TEST_ASSERT_NOTNULL(spare, "The test wing has no empty cell")
	TEST_ASSERT(riot_of(prison, rioters), "The second riot did not start with all three")
	first.forceMove(spare.arrival_turf())
	second.forceMove(spare.arrival_turf())
	capture_bolt(prison, spare)
	prison.tick(1)
	TEST_ASSERT(prison.riot_active, "The riot ended with a rioter free in the yard")
	TEST_ASSERT(first.is_confined() && second.is_confined(), "Two rioters bolted into a spare cell are not shut in")
	TEST_ASSERT_NULL(first.riot_target(), "A rioter bolted in a cell went for [first.riot_target()]")
	third.forceMove(third.cell.arrival_turf())
	capture_bolt(prison, third.cell)
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "The riot went on with every rioter bolted in a cell")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in rioters)
		TEST_ASSERT_NULL(rioter.trouble, "[rioter] kept rioting after the riot")
		TEST_ASSERT(rioter.lockdown_left > 0, "[rioter] was shut in a cell and owes no lockdown")
	prison.admin_calm()
	capture_bolt(prison, spare, FALSE)
	capture_bolt(prison, third.cell, FALSE)
	first.forceMove(prison_spot(home, 8, 8))
	second.forceMove(prison_spot(home, 10, 8))
	third.forceMove(prison_spot(home, 12, 8))
	prison.refresh_reach()

	// A rioter deleted mid-riot drops out of the count: with the others cuffed, the riot is over.
	// Knocked off their feet for a moment, the last one still counts.
	TEST_ASSERT(riot_of(prison, rioters), "The third riot did not start with all three")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in list(first, second))
		TEST_ASSERT(rioter.apply_cuffs(allocate(/obj/item/restraints/handcuffs)), "[rioter] could not be cuffed")
	prison.tick(1)
	TEST_ASSERT(prison.riot_active, "The riot ended with a rioter free in the yard")
	third.Knockdown(2 SECONDS)
	TEST_ASSERT(!third.riot_handled(), "A rioter only knocked down counts as dealt with")
	prison.tick(1)
	TEST_ASSERT(prison.riot_active, "A knockdown of the last free rioter ended the riot")
	third.SetKnockdown(0)
	qdel(third)
	TEST_ASSERT(!(third in prison.prisoners), "A deleted rioter stayed on the roster")
	TEST_ASSERT(third.riot_handled(), "A deleted rioter still counts toward the riot")
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "The riot went on after its last free rioter was deleted")
	TEST_ASSERT(!prison.incident_open, "The incident outlived the riot")
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in list(first, second))
		rioter.remove_cuffs()
	settle_prison_air(home)

// ===== LOCKDOWN =====

/datum/unit_test/voidcrew_outpost_prison_lockdown
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_lockdown/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("lockdownowner")
	TEST_ASSERT_NOTNULL(home, "The lockdown test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 8, 4), "lockdownowner")
	var/mob/living/basic/outpost_prisoner/inmate = trouble_prisoner(prison, prison_spot(home, 8, 8), "chatty")
	var/mob/living/basic/outpost_prisoner/yardbird = trouble_prisoner(prison, prison_spot(home, 12, 8), "cheerful")
	var/datum/outpost_prison_cell/cell = inmate.cell

	// A rioter shut in a cell owes four minutes of lockdown (PRISON_RIOT_LOCKDOWN_TIME).
	TEST_ASSERT(prison.start_riot("test", forced = inmate), "The riot did not start")
	TEST_ASSERT(inmate.is_rioting() && !yardbird.is_rioting(), "The wrong prisoners joined the riot")
	prison.tick(5)
	inmate.adjustStaminaLoss(200)
	inmate.forceMove(cell.arrival_turf())
	capture_bolt(prison, cell)
	prison.tick(1)
	TEST_ASSERT(!prison.riot_active, "The riot went on with its only rioter shut in a cell")
	TEST_ASSERT_EQUAL(inmate.lockdown_left, 239, "The captured rioter owes [inmate.lockdown_left] s of lockdown, not 239")
	TEST_ASSERT(capture_logged(prison, "[inmate.real_name] is on lockdown."), "The lockdown was not logged")
	TEST_ASSERT(!capture_logged(prison, "minutes of lockdown"), "The log gives the lockdown's length")
	inmate.setStaminaLoss(0)

	// While they owe it, being shut in or cuffed costs nothing, and it counts down shut in.
	TEST_ASSERT(!prison.protective_custody(), "The wing is still in protective custody after the riot")
	prison.tick(60)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 0, "Lockdown counted [inmate.locked_in_seconds] s toward the lock-in clock")
	TEST_ASSERT_EQUAL(inmate.lockdown_left, 179, "A minute shut in left [inmate.lockdown_left] s of lockdown, not 179")
	TEST_ASSERT(inmate.apply_cuffs(allocate(/obj/item/restraints/handcuffs)), "The inmate could not be cuffed")
	prison.tick(10)
	TEST_ASSERT_EQUAL(inmate.cuffed_seconds, 0, "Cuffs on a prisoner owing lockdown ran the cuffed clock")
	inmate.remove_cuffs()
	TEST_ASSERT_EQUAL(inmate.lockdown_left, 169, "Lockdown did not count down while cuffed in the cell")
	// Sullen meanwhile.
	var/sullen = FALSE
	for(var/i in 1 to 200)
		var/list/choice = inmate.pick_speech()
		if(choice && choice[1] == "lockdown")
			sullen = TRUE
			break
	TEST_ASSERT(sullen, "A prisoner on lockdown never brought it up")

	// Where staff look: the prisoner's examine and the cell's bolt button, about 3 minutes left.
	TEST_ASSERT(findtext(jointext(inmate.examine(warden), " "), "On lockdown for about 3 more minutes"), "Examining a prisoner on lockdown does not say how long: [jointext(inmate.examine(warden), " ")]")
	var/obj/machinery/button/outpost_prison_bolt/button
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/button/outpost_prison_bolt/candidate in tile)
			if(candidate.cell_number == cell.number)
				button = candidate
	TEST_ASSERT_NOTNULL(button, "Cell [cell.number] has no bolt button")
	TEST_ASSERT(findtext(jointext(button.examine(warden), " "), "[inmate.real_name] is on lockdown"), "The cell's bolt button does not show the lockdown")

	// Out through a hole with their cell still bolted, nobody let them out: the grace waits, no riot
	var/turf/served_from = inmate.loc
	inmate.forceMove(prison_spot(home, 10, 8))
	prison.tick(40)
	TEST_ASSERT(!prison.riot_active, "A prisoner out through a hole in their bolted cell started a riot")
	TEST_ASSERT_EQUAL(inmate.lockdown_out, 0, "The grace ran while their cell was still bolted")
	inmate.forceMove(served_from)

	// Let out early: out of the cell on their feet and uncuffed, the lockdown stops counting. Cuffed
	// or down the grace waits; after 30 seconds (PRISON_LOCKDOWN_GRACE) on their feet they riot
	// again, even in the quiet after the last riot.
	TEST_ASSERT(prison.subdued_left > 0, "The wing is not subdued after the riot")
	capture_bolt(prison, cell, FALSE)
	TEST_ASSERT(!inmate.is_confined(), "A prisoner behind an unbolted door counts as confined")
	TEST_ASSERT(inmate.apply_cuffs(allocate(/obj/item/restraints/handcuffs)), "The inmate could not be cuffed out of the cell")
	prison.tick(40)
	TEST_ASSERT_EQUAL(inmate.lockdown_out, 0, "The grace ran while the prisoner was cuffed")
	TEST_ASSERT_EQUAL(inmate.lockdown_left, 169, "Lockdown counted down out of the cell")
	inmate.remove_cuffs()
	prison.tick(30)
	TEST_ASSERT(!prison.riot_active, "A prisoner owing lockdown rioted inside the grace")
	TEST_ASSERT_EQUAL(inmate.lockdown_out, 30, "Thirty seconds out counted [inmate.lockdown_out]")
	prison.tick(1)
	TEST_ASSERT(prison.riot_active, "Letting a prisoner out before their lockdown was up started no riot")
	TEST_ASSERT_EQUAL(inmate.trouble, "riot", "The prisoner let out early did not riot")
	TEST_ASSERT_EQUAL(inmate.lockdown_left, 0, "The lockdown outlived the early release")
	TEST_ASSERT(capture_logged(prison, "was let out before their lockdown was up"), "The early release was not logged")
	prison.admin_calm()
	prison.set_subdued(0)

	// Served: announced once, they say so, and the usual lock-in rules apply again.
	inmate.forceMove(cell.arrival_turf())
	capture_bolt(prison, cell)
	prison.start_lockdown(inmate)
	TEST_ASSERT(is_line_for(inmate.last_line, "lockdown"), "Owing lockdown, the prisoner said no lockdown line: [inmate.last_line]")
	prison.tick(239)
	TEST_ASSERT_EQUAL(inmate.lockdown_left, 1, "Lockdown counted [240 - inmate.lockdown_left] s in 239")
	prison.tick(1)
	TEST_ASSERT_EQUAL(inmate.lockdown_left, 0, "Four minutes shut in did not serve the lockdown")
	TEST_ASSERT(capture_logged(prison, "lockdown is over"), "The end of the lockdown was not logged")
	TEST_ASSERT(is_line_for(inmate.last_line, "lockdown_over"), "The prisoner said no lockdown_over line: [inmate.last_line]")
	prison.tick(10)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 10, "After the lockdown, the lock-in clock counted [inmate.locked_in_seconds] s, not 10")
	capture_bolt(prison, cell, FALSE)
	inmate.forceMove(prison_spot(home, 8, 8))
	prison.refresh_reach()

	// A runner who got out during a riot owes lockdown once caught.
	yardbird.set_mood(20)
	TEST_ASSERT(prison.start_riot("test", forced = yardbird), "The runner's riot did not start")
	prison.tick(5)
	yardbird.forceMove(prison_spot(home, 8, 4))
	prison.tick(1)
	TEST_ASSERT_EQUAL(yardbird.trouble, "loose", "A rioter out in the office is not loose")
	TEST_ASSERT(yardbird.escaped_rioting, "A rioter who got out does not count as a runner from a riot")
	yardbird.adjustStaminaLoss(200)
	yardbird.forceMove(prison_spot(home, 12, 8))
	prison.tick(1)
	TEST_ASSERT_NULL(yardbird.trouble, "The runner from the riot was not recaptured")
	TEST_ASSERT_EQUAL(yardbird.lockdown_left, 240, "A runner caught after a riot owes [yardbird.lockdown_left] s of lockdown, not 240")
	yardbird.setStaminaLoss(0)

	// The admin panel shows it and clears it.
	var/mob/living/carbon/human/operator = make_player(prison_spot(home, 9, 3), "lockdownadmin")
	var/datum/outpost_manipulator/unit_test/prison/panel = allocate(__IMPLIED_TYPE__, operator)
	panel.selected = home
	var/list/row
	for(var/list/candidate_row as anything in prison.admin_payload()["prisoners"])
		if(candidate_row["ref"] == REF(yardbird))
			row = candidate_row
	TEST_ASSERT_EQUAL(row?["lockdown_left"], 240, "The admin panel shows [row?["lockdown_left"]] s of lockdown")
	panel.manage_outpost(home, operator, "prison_set", list("ref" = REF(yardbird), "field" = "lockdown", "value" = 0))
	TEST_ASSERT(!panel.error, "Clearing a lockdown was refused: [panel.error]")
	TEST_ASSERT_EQUAL(yardbird.lockdown_left, 0, "The admin panel did not clear the lockdown")
	prison.admin_calm()
	settle_prison_air(home)
