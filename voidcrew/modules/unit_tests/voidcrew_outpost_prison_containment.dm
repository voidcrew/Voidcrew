/**
 * Outpost prison containment: the management panel's static pushes while placing the wing;
 * dragging, stuns, bolt buttons and bolted-in prisoners; teleports, pods, polymorph and revival;
 * breaches, confinement, members and visitors, rebuilt doors and deleting the outpost.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

/**
 * A second full update inside tgui's refresh cooldown makes the window remount, which lost the
 * placement map the first time a player pressed Place. The panel must push once per survey and
 * never twice inside the cooldown.
 */
/datum/unit_test/voidcrew_outpost_panel_refresh
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_panel_refresh/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("refreshowner")
	TEST_ASSERT_NOTNULL(home, "The refresh test outpost did not load")
	var/turf/console_turf = get_turf(home.management_console)
	var/mob/living/carbon/human/owner = make_player(console_turf, "refreshowner")
	var/obj/machinery/computer/player_outpost_management/console = allocate(__IMPLIED_TYPE__, console_turf)
	var/datum/player_outpost_management_ui/management_test/push_log/panel = allocate(__IMPLIED_TYPE__, home, owner, console)
	home.outpost_upgrades["prison"] = new /datum/outpost_upgrade/prison(home)
	home.upgrade_survey = null

	// First Place: the survey starts, runs, and is pushed exactly once when it lands.
	act(panel, owner, "open_upgrade_map", null, list("id" = "prison"))
	var/deadline = world.time + 20 SECONDS
	while(home.upgrade_surveying && world.time < deadline)
		sleep(1)
	TEST_ASSERT(!home.upgrade_surveying, "The survey never finished")
	TEST_ASSERT(wait_for_pushes(panel, 1), "The finished survey was never pushed")
	sleep(2)
	TEST_ASSERT_EQUAL(length(panel.push_times), 1, "Opening the placement map pushed static data more than once")
	TEST_ASSERT_NOTNULL(panel.ui_static_data(owner)["upgrade_survey"], "The pushed static data has no survey")

	// Back at once: the close waits out the cooldown instead of refreshing the window.
	act(panel, owner, "close_upgrade_map", null, list("id" = "prison"))
	TEST_ASSERT_EQUAL(length(panel.push_times), 1, "Closing the map pushed inside the refresh cooldown")
	TEST_ASSERT(wait_for_pushes(panel, 2), "Closing the map never pushed")
	TEST_ASSERT(panel.push_times[2] - panel.push_times[1] >= TGUI_REFRESH_FULL_UPDATE_COOLDOWN, "Two pushes came [panel.push_times[2] - panel.push_times[1]] ds apart")
	TEST_ASSERT_NULL(panel.ui_static_data(owner)["upgrade_survey"], "The survey was still sent after the map closed")

	// Place again with the survey cached: one push, again not inside the cooldown.
	act(panel, owner, "open_upgrade_map", null, list("id" = "prison"))
	TEST_ASSERT(wait_for_pushes(panel, 3), "Reopening the map with a cached survey never pushed")
	TEST_ASSERT(panel.push_times[3] - panel.push_times[2] >= TGUI_REFRESH_FULL_UPDATE_COOLDOWN, "The cached survey was pushed inside the cooldown")

	// Pushes that pile up while one waits collapse into a single push.
	panel.push_static_data()
	panel.push_static_data()
	panel.push_static_data()
	TEST_ASSERT(wait_for_pushes(panel, 4), "Queued pushes were never sent")
	sleep(TGUI_REFRESH_FULL_UPDATE_COOLDOWN + 2)
	TEST_ASSERT_EQUAL(length(panel.push_times), 4, "Three queued pushes were not collapsed into one")

	// A window's own cooldown, such as a client refresh the panel did not send, is waited out too.
	var/datum/tgui/window = allocate(/datum/tgui, owner, panel, "OutpostManagement")
	window.initialized = TRUE
	LAZYADD(panel.open_uis, window)
	COOLDOWN_START(window, refresh_cooldown, TGUI_REFRESH_FULL_UPDATE_COOLDOWN)
	var/started = world.time
	panel.push_static_data()
	TEST_ASSERT_EQUAL(length(panel.push_times), 4, "A push ignored the window's own refresh cooldown")
	TEST_ASSERT(wait_for_pushes(panel, 5), "A push waiting on the window's cooldown was never sent")
	TEST_ASSERT(panel.push_times[5] - started >= TGUI_REFRESH_FULL_UPDATE_COOLDOWN, "A push came before the window's cooldown ended")
	LAZYREMOVE(panel.open_uis, window)

// ===== DRAGGING, STUNS AND BOLTS =====

/datum/unit_test/voidcrew_outpost_prison_restraint
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_restraint/proc/in_stamcrit(mob/living/prisoner)
	return !!prisoner.has_status_effect(/datum/status_effect/incapacitating/stamcrit)

/datum/unit_test/voidcrew_outpost_prison_restraint/proc/back_up(mob/living/basic/outpost_prisoner/prisoner)
	return !prisoner.can_be_dragged()

/datum/unit_test/voidcrew_outpost_prison_restraint/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("restraintowner")
	TEST_ASSERT_NOTNULL(home, "The restraint test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	REMOVE_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 7, 8), "restraintowner")
	var/obj/structure/bed/bed = prison.cells[1].bed()

	// Awake and calm: they can be pulled and go along with it, but nobody drags them onto things.
	TEST_ASSERT(!prisoner.can_be_dragged(), "An awake prisoner counts as draggable")
	warden.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(warden.pulling, prisoner, "Nobody could pull a calm prisoner")
	warden.stop_pulling()
	TEST_ASSERT(SEND_SIGNAL(prisoner, COMSIG_MOUSEDROP_ONTO, bed, warden) & COMPONENT_CANCEL_MOUSEDROP_ONTO, "An awake prisoner could be dragged onto a bed")
	prisoner.end_activity()

	// A security baton: 60 stamina and a knockdown a hit; two hits put them in stamina crit.
	var/obj/item/melee/baton/security/loaded/baton = allocate(__IMPLIED_TYPE__)
	warden.put_in_active_hand(baton)
	baton.attack_self(warden)
	TEST_ASSERT(baton.active, "The baton did not switch on")
	warden.set_combat_mode(TRUE)
	click_wrapper(warden, prisoner)
	TEST_ASSERT(prisoner.getStaminaLoss() >= 60, "A baton hit did [prisoner.getStaminaLoss()] stamina damage")
	// A security baton knocks down two seconds after the hit, as it does people.
	TEST_ASSERT(wait_until(CALLBACK(prisoner, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, can_be_dragged)), 4 SECONDS), "A knocked down prisoner could not be dragged")
	TEST_ASSERT(prisoner.has_status_effect(/datum/status_effect/incapacitating/knockdown), "The baton did not knock the prisoner down")
	COOLDOWN_RESET(baton, cooldown_check)
	REMOVE_TRAIT(prisoner, TRAIT_IWASBATONED, REF(warden))
	click_wrapper(warden, prisoner)
	warden.set_combat_mode(FALSE)
	TEST_ASSERT(in_stamcrit(prisoner), "Two baton hits did not put a prisoner in stamina crit")
	TEST_ASSERT_EQUAL(prisoner.body_position, LYING_DOWN, "A prisoner in stamina crit is still standing")
	TEST_ASSERT(!prisoner.routine_allowed(), "A prisoner in stamina crit kept up their routine")

	// Down, they can be pulled and dragged; stamina crit holds 20 seconds after the last hit
	// (PRISONER_STAMCRIT_TIME), twice tg's default.
	TEST_ASSERT_EQUAL(prisoner.stamina_regen_time, 200, "Prisoner stamina crit does not last 20 seconds")
	TEST_ASSERT(!(SEND_SIGNAL(prisoner, COMSIG_MOUSEDROP_ONTO, bed, warden) & COMPONENT_CANCEL_MOUSEDROP_ONTO), "A prisoner in stamina crit could not be dragged onto a bed")
	warden.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(warden.pulling, prisoner, "A prisoner in stamina crit could not be pulled")
	sleep(11 SECONDS)
	TEST_ASSERT(in_stamcrit(prisoner), "Stamina crit ended within tg's default 10 seconds")
	// Back on their feet and calm, they go along with the pull that still has them (outpost_prison_warden_tools.dm).
	prisoner.setStaminaLoss(0)
	TEST_ASSERT(!in_stamcrit(prisoner), "Clearing stamina did not end stamina crit")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(back_up), prisoner), 8 SECONDS), "The prisoner never recovered")
	TEST_ASSERT_EQUAL(warden.pulling, prisoner, "A calm prisoner back on their feet shook off the pull")
	TEST_ASSERT_EQUAL(prisoner.move_resist, MOVE_RESIST_DEFAULT, "A calm prisoner being pulled is too heavy to pull")
	warden.stop_pulling()
	TEST_ASSERT_EQUAL(prisoner.move_resist, MOVE_FORCE_VERY_STRONG, "Let go, a prisoner on their feet is light enough to shove")
	prisoner.end_activity()

	// A disabler: 30 stamina a shot, four shots.
	var/mob/living/basic/outpost_prisoner/runner = test_prisoner(prison, prison_spot(home, 12, 8))
	REMOVE_TRAIT(runner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/gun/energy/disabler/disabler = allocate(__IMPLIED_TYPE__)
	warden.forceMove(prison_spot(home, 11, 8))
	warden.drop_all_held_items()
	warden.put_in_active_hand(disabler)
	for(var/i in 1 to 6)
		if(in_stamcrit(runner))
			break
		disabler.melee_attack_chain(warden, runner)
		sleep(1 SECONDS)
	TEST_ASSERT(in_stamcrit(runner), "A disabler did not put a prisoner in stamina crit (stamina [runner.getStaminaLoss()])")
	runner.setStaminaLoss(0)

	// Bolt buttons: each bolts its own cell's door and no other, and the link goes through its own wing.
	var/obj/machinery/button/outpost_prison_bolt/button = locate() in prison_spot(home, 8, 11)
	TEST_ASSERT_NOTNULL(button, "Cell 2's bolt button is not where the map puts it")
	TEST_ASSERT_EQUAL(button.cell_number, 2, "The button beside cell 2 is for cell [button.cell_number]")
	TEST_ASSERT_EQUAL(get_outpost_prison(button), prison, "The button does not belong to this prison")
	var/datum/outpost_prison_cell/cell_two = prison.cells[2]
	var/obj/machinery/door/airlock/cell_door = cell_two.door()
	TEST_ASSERT(get_dist(button, cell_door) <= 1, "Cell 2's button is not beside its door")
	TEST_ASSERT(button.attempt_press(warden), "The bolt button could not be pressed")
	TEST_ASSERT(cell_door.locked, "The bolt button did not bolt its cell")
	for(var/datum/outpost_prison_cell/other as anything in prison.cells)
		if(other != cell_two)
			TEST_ASSERT(!other.door().locked, "Cell 2's button bolted cell [other.number]")

	// Bolted in: they stay in the cell, and the time is counted.
	var/mob/living/basic/outpost_prisoner/inmate = runner
	inmate.forceMove(prison_spot(home, 7, 14))
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(!inmate.walkable[prison_spot(home, 7, 8)], "A bolted-in prisoner could still walk into the yard")
	for(var/turf/tile as anything in inmate.walkable)
		TEST_ASSERT(cell_two.turf_set[tile], "A bolted-in prisoner could walk to [tile.x],[tile.y] outside the cell")
	for(var/i in 1 to 10)
		var/datum/prisoner_activity/chosen = inmate.choose_activity()
		if(chosen?.spot)
			TEST_ASSERT(cell_two.turf_set[chosen.spot], "A bolted-in prisoner chose [chosen.type] outside the cell")
		inmate.end_activity(cancel_ai = FALSE)
	prison.tick(60)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 60, "A minute bolted in counted [inmate.locked_in_seconds] s")
	var/list/admin_data = prison.admin_payload()
	var/found_locked = FALSE
	for(var/list/row as anything in admin_data["prisoners"])
		if(row["ref"] == REF(inmate))
			found_locked = row["locked_in"]
	TEST_ASSERT(found_locked, "The admin panel does not show the prisoner as locked in")
	var/datum/prisoner_activity/call_out/calling = new(inmate)
	TEST_ASSERT_EQUAL(calling.get_weight(), 0, "A prisoner called out before two minutes bolted in")
	prison.tick(61)
	TEST_ASSERT(calling.get_weight() > 0, "A prisoner bolted in over two minutes would not call out")
	TEST_ASSERT(calling.setup(), "Calling out could not be set up")
	TEST_ASSERT(cell_two.turf_set[calling.spot] && get_dist(calling.spot, cell_door) == 1, "Calling out did not go to the cell door")
	qdel(calling)
	var/said_locked_in = FALSE
	for(var/i in 1 to 30)
		var/list/choice = inmate.pick_speech()
		if(choice && choice[1] == "locked_in")
			said_locked_in = TRUE
			break
	TEST_ASSERT(said_locked_in, "A prisoner bolted in over two minutes never complained about it")
	TEST_ASSERT(button.attempt_press(warden), "The bolt button could not be pressed again")
	TEST_ASSERT(!cell_door.locked, "The bolt button did not unbolt its cell")
	// Out of the cell, the locked-in time falls (by 2 s a second, PRISONER_LOCKED_IN_RECOVERY) until it is gone.
	prison.tick(1)
	TEST_ASSERT(inmate.locked_in_seconds < 121, "Unbolting did not start the locked-in time falling ([inmate.locked_in_seconds] s)")
	prison.tick(60)
	TEST_ASSERT_EQUAL(inmate.locked_in_seconds, 0, "A minute out of the cell left [inmate.locked_in_seconds] s locked in")
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(inmate.walkable[prison_spot(home, 7, 8)], "An unbolted prisoner still could not reach the yard")
	settle_prison_air(home)

// ===== TELEPORTS, PODS, POLYMORPH AND REVIVAL =====

/**
 * Nothing moves a prisoner out of the wing but the prison's own beam: forced teleports fail, drop
 * pods and supply pods leave them behind, polymorph does nothing, and a dead prisoner stays dead.
 */
/datum/unit_test/voidcrew_outpost_prison_relocation
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_relocation/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("relocateowner")
	TEST_ASSERT_NOTNULL(home, "The relocation test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/yard = prison_spot(home, 8, 8)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, yard)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 10, 8), "relocateowner")

	// A forced teleport, as a drop pod's is, fails; the same teleport moves anyone else.
	TEST_ASSERT(!do_teleport(prisoner, prison_spot(home, 12, 8), no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM, forced = TRUE), "A forced teleport reported moving a prisoner")
	TEST_ASSERT_EQUAL(prisoner.loc, yard, "A forced teleport moved a prisoner")
	TEST_ASSERT(do_teleport(owner, prison_spot(home, 11, 8), no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM, forced = TRUE), "A forced teleport failed for someone who is not a prisoner")

	// Pods leave prisoners behind, but still take other people.
	var/obj/structure/closet/supplypod/supply_pod = allocate(/obj/structure/closet/supplypod, prison_spot(home, 12, 9))
	supply_pod.reverse_option_list["Mobs"] = TRUE
	TEST_ASSERT(!supply_pod.insertion_allowed(prisoner), "A supply pod would carry a prisoner off")
	TEST_ASSERT(supply_pod.insertion_allowed(owner), "A supply pod set to take mobs refused a person")
	var/obj/structure/closet/supplypod/drop_pod/drop_pod = allocate(/obj/structure/closet/supplypod/drop_pod, prison_spot(home, 13, 9))
	TEST_ASSERT(!drop_pod.insertion_allowed(prisoner), "A drop pod would carry a prisoner off")
	TEST_ASSERT(drop_pod.insertion_allowed(owner), "A drop pod refused a person")

	// Polymorph and type changes leave them as they are.
	prisoner.wabbajack()
	TEST_ASSERT(!QDELETED(prisoner), "A polymorph bolt deleted a prisoner")
	TEST_ASSERT(prisoner in prison.prisoners, "A polymorphed prisoner left the roster")
	TEST_ASSERT_NULL(prisoner.change_mob_type(/mob/living/basic/mouse, delete_old_mob = TRUE), "A prisoner was turned into another mob")
	TEST_ASSERT(!QDELETED(prisoner), "Changing a prisoner's type deleted them")

	// Strange reagent on a dead prisoner: they stay dead, the attempt is logged, and nobody comes for the body.
	var/mob/living/basic/outpost_prisoner/body = test_prisoner(prison, prison_spot(home, 12, 10))
	body.death()
	TEST_ASSERT_EQUAL(body.stat, DEAD, "The prisoner did not die")
	var/datum/reagent/medicine/strange_reagent/instant/strange = allocate(__IMPLIED_TYPE__)
	strange.expose_mob(body, TOUCH, 20)
	TEST_ASSERT_EQUAL(body.stat, DEAD, "Strange reagent brought a dead prisoner back")
	TEST_ASSERT(!QDELETED(body) && body.phase == "present" && (body in prison.prisoners), "A revival attempt took the body away") // PRISONER_PRESENT
	var/list/newest = prison.entries[1]
	TEST_ASSERT(findtext(newest["text"], "already logged the death"), "The revival attempt was not logged: [newest["text"]]")
	// Carried out of the cell block, the body leaves the roster, and it still stays dead.
	var/turf/outside = prison.outside_spot_near(body)
	TEST_ASSERT_NOTNULL(outside, "Nowhere outside the cell block to carry the body")
	body.forceMove(outside)
	prison.tick(1)
	TEST_ASSERT(!(body in prison.prisoners), "The body carried out of the cell block stayed on the roster")
	TEST_ASSERT(!body.can_be_revived(), "A dead prisoner off the roster could be revived")
	strange.expose_mob(body, TOUCH, 20)
	TEST_ASSERT_EQUAL(body.stat, DEAD, "Strange reagent brought back a dead prisoner off the roster")
	qdel(body)
	settle_prison_air(home)

// ===== BREACHES =====

/**
 * Walls are the cell block's edge: a hole between two cells is still inside, so a prisoner
 * standing in it has not escaped. A hole into the office leaves the office outside, even after
 * the layout is worked out again, and a prisoner who walks through it has escaped.
 */
/datum/unit_test/voidcrew_outpost_prison_breach
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_breach/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("breachowner")
	TEST_ASSERT_NOTNULL(home, "The breach test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/turf/cell_one = prison_spot(home, 3, 14)
	var/mob/living/basic/outpost_prisoner/prisoner = trouble_prisoner(prison, cell_one)

	// The wall between cells 1 and 2, knocked down
	var/turf/divider = prison_spot(home, 5, 14)
	TEST_ASSERT(isclosedturf(divider), "There is no wall between cells 1 and 2 where the map puts it")
	TEST_ASSERT(prison.in_cell_block(divider), "The wall between two cells is not part of the cell block")
	var/divider_type = divider.type
	divider.ChangeTurf(/turf/open/floor/iron)
	prisoner.forceMove(divider)
	prison.refresh_prisoner_reach(prisoner)
	prison.tick(1)
	TEST_ASSERT_NULL(prisoner.trouble, "A prisoner standing in a hole between two cells counted as [prisoner.trouble]")
	TEST_ASSERT_EQUAL(prison.loose_count(), 0, "A hole between two cells let a prisoner escape")
	// Thirty seconds on, the changed walls are noticed and the cell block is worked out again.
	prison.tick(30)
	TEST_ASSERT(prison.in_cell_block(divider), "The hole between two cells left the cell block after the layout check")
	TEST_ASSERT_NULL(prisoner.trouble, "The layout check turned a prisoner in the cell block into [prisoner.trouble]")
	prisoner.forceMove(cell_one)

	// A hole in the wall between the yard and the office
	var/turf/office_wall = prison_spot(home, 6, 6)
	var/turf/office = prison_spot(home, 6, 5)
	TEST_ASSERT(isclosedturf(office_wall), "There is no wall between the yard and the office where the map puts it")
	var/office_wall_type = office_wall.type
	office_wall.ChangeTurf(/turf/open/floor/iron)
	prison.refresh_layout()
	TEST_ASSERT(prison.in_cell_block(office_wall), "The hole in the yard wall is not part of the cell block")
	TEST_ASSERT(!prison.in_cell_block(office), "The office joined the cell block through a hole in the wall")
	TEST_ASSERT(!prison.in_cell_block(prison_spot(home, 9, 3)), "The office joined the cell block through a hole in the wall")
	var/mob/living/basic/outpost_prisoner/runner = trouble_prisoner(prison, office_wall)
	prison.tick(1)
	TEST_ASSERT_NULL(runner.trouble, "A prisoner standing in the hole counted as [runner.trouble]")
	runner.forceMove(office)
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "A prisoner who walked through a hole into the office did not escape") // PRISONER_TROUBLE_LOOSE

	// With no cells there is no cell block: anywhere in the wing counts as inside, and nowhere else.
	var/list/kept_cells = prison.cells
	prison.cells = list()
	prison.cell_block = list()
	TEST_ASSERT(prison.in_cell_block(prison_spot(home, 9, 3)), "A wing without cells treated its office as outside")
	var/list/bounds = prison.upgrade.footprint_bounds
	var/turf/beyond = locate(bounds[1] - 1, bounds[2], bounds[5])
	TEST_ASSERT(beyond && !prison.in_cell_block(beyond), "A wing without cells treated the ground outside it as inside")
	prison.cells = kept_cells
	prison.refresh_cell_block()
	TEST_ASSERT(!prison.in_cell_block(office), "Rebuilding the cell block put the office inside it")
	TEST_ASSERT(prison.in_cell_block(divider), "Rebuilding the cell block left out the hole between two cells")

	office_wall.ChangeTurf(office_wall_type)
	divider.ChangeTurf(divider_type)
	settle_prison_air(home)

// ===== CONFINEMENT =====

/// A cell is confining whenever its prisoner can walk nowhere but the cell: bolted, welded or walled in.
/datum/unit_test/voidcrew_outpost_prison_confinement
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_confinement/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("confineowner")
	TEST_ASSERT_NOTNULL(home, "The confinement test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/inmate = test_prisoner(prison, prison_spot(home, 7, 14))
	var/datum/outpost_prison_cell/cell_two = prison.cells[2]
	var/obj/machinery/door/airlock/door = cell_two.door()
	TEST_ASSERT(cell_two.contains(inmate), "The inmate is not in cell 2")

	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(!inmate.is_confined(), "A prisoner behind an open cell door counts as confined")

	// Welded shut
	door.welded = TRUE
	door.update_appearance()
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(inmate.is_confined(), "A prisoner behind a welded cell door does not count as confined")
	door.welded = FALSE
	door.update_appearance()
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(!inmate.is_confined(), "Unwelding the cell door did not free the prisoner")

	// A wall built in front of the open door
	var/turf/front = prison_spot(home, 7, 11)
	var/front_type = front.type
	front.ChangeTurf(/turf/closed/wall)
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(inmate.is_confined(), "A prisoner walled in behind their cell door does not count as confined")
	front.ChangeTurf(front_type)
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(!inmate.is_confined(), "Taking the wall away did not free the prisoner")

	// The doorway itself walled up
	var/turf/doorway = cell_two.door_turf
	var/doorway_type = doorway.type
	qdel(door)
	doorway.ChangeTurf(/turf/closed/wall)
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(inmate.is_confined(), "A prisoner in a walled-up cell does not count as confined")
	prison.tick(10)
	TEST_ASSERT(inmate.locked_in_seconds >= 10, "Ten seconds walled in counted [inmate.locked_in_seconds] s")
	doorway.ChangeTurf(doorway_type)
	settle_prison_air(home)

// ===== MEMBERS AND VISITORS =====

/**
 * Staff doors and the office side of the hatches open for members of the wing only, unless the
 * warden lets visitors in; bolt buttons are for members whatever the setting. Prisoners never.
 */
/datum/unit_test/voidcrew_outpost_prison_visitors
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_visitors/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("wingowner")
	TEST_ASSERT_NOTNULL(home, "The visitor test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 3, 3), "wingowner")
	var/mob/living/carbon/human/visitor = make_player(prison_spot(home, 4, 3), "wingvisitor")
	var/mob/living/carbon/human/builder = make_player(prison_spot(home, 5, 3), "wingbuilder")
	var/mob/living/carbon/human/resident = make_player(prison_spot(home, 6, 3), "wingresident")
	var/mob/living/carbon/human/steward = make_player(prison_spot(home, 7, 3), "wingsteward")
	var/mob/living/carbon/human/shipmate = make_player(prison_spot(home, 10, 3), "wingshipmate")
	home.authorized_builder_ckeys |= "wingbuilder"
	home.residents |= resident.mind
	home.stewards |= steward.mind
	// The owner's crew: a ship team with a ship, holding the owner and a shipmate
	home.founder_mind = WEAKREF(owner.mind)
	var/obj/structure/overmap/ship/ship = allocate(__IMPLIED_TYPE__)
	var/datum/team/voidcrew/crew = new
	crew.ship = ship
	crew.members |= owner.mind
	crew.members |= shipmate.mind
	LAZYADD(owner.mind.ship_teams, crew)

	for(var/mob/living/carbon/human/member as anything in list(owner, builder, resident, steward, shipmate))
		TEST_ASSERT(prison.is_member(member), "[member.ckey] is not a member of the wing")
	TEST_ASSERT(!prison.is_member(visitor), "A visitor counts as a member of the wing")
	TEST_ASSERT(!prison.is_member(prisoner), "A prisoner counts as a member of the wing")

	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison_spot(home, 9, 6)
	var/obj/machinery/door/airlock/security/prison_staff/entrance = locate() in prison_spot(home, 9, 1)
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in prison_spot(home, 5, 6)
	var/obj/machinery/door/window/hatch_door = hatch?.staff_windoor()
	var/obj/machinery/button/outpost_prison_bolt/button = locate() in prison_spot(home, 8, 11)
	TEST_ASSERT(staff_door && entrance && hatch_door && button, "The wing's doors and buttons are not where the map puts them")
	var/datum/outpost_prison_cell/cell_two = prison.cell_by_number(2)
	var/obj/machinery/door/airlock/cell_door = cell_two.door()

	// Members only, by default
	TEST_ASSERT(!prison.visitors_allowed, "Visitors are let in by default")
	for(var/obj/machinery/door/door as anything in list(staff_door, entrance, hatch_door))
		TEST_ASSERT(door.allowed(owner), "[door] refused the owner")
		TEST_ASSERT(door.allowed(shipmate), "[door] refused the owner's shipmate")
		TEST_ASSERT(!door.allowed(visitor), "[door] opened for a visitor")
		TEST_ASSERT(!door.allowed(prisoner), "[door] opened for a prisoner")
	TEST_ASSERT(!button.attempt_press(visitor), "A visitor pressed a bolt button")
	TEST_ASSERT(!cell_door.locked, "A visitor bolted a cell")
	TEST_ASSERT(button.attempt_press(resident), "A resident could not press a bolt button")
	TEST_ASSERT(cell_door.locked, "A resident's press did not bolt the cell")
	TEST_ASSERT(button.attempt_press(resident), "A resident could not unbolt the cell")

	// Visitors let in: the doors open for them, the bolt buttons still do not, prisoners still never
	TEST_ASSERT(prison.set_visitors_allowed(TRUE, owner), "Letting visitors in changed nothing")
	for(var/obj/machinery/door/door as anything in list(staff_door, entrance, hatch_door))
		TEST_ASSERT(door.allowed(visitor), "[door] refused a visitor while visitors are let in")
		TEST_ASSERT(!door.allowed(prisoner), "[door] opened for a prisoner while visitors are let in")
	TEST_ASSERT(!button.attempt_press(visitor), "A visitor pressed a bolt button while visitors are let in")
	TEST_ASSERT(!cell_door.locked, "A visitor bolted a cell while visitors are let in")
	TEST_ASSERT(prison.set_visitors_allowed(FALSE, owner), "Closing the wing to visitors changed nothing")
	TEST_ASSERT(!staff_door.allowed(visitor), "The staff door still opens for visitors after they were closed out")

	LAZYREMOVE(owner.mind.ship_teams, crew)
	crew.members.Cut()
	qdel(crew)
	settle_prison_air(home)

// ===== REBUILT DOORS =====

/**
 * An airlock built where a cell door stood becomes that cell's door and bolts from its button;
 * one built where a staff door stood becomes a staff door. A staff door broken down leaves no
 * frame in the doorway; one taken apart does.
 */
/datum/unit_test/voidcrew_outpost_prison_rebuilt_doors
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_rebuilt_doors/proc/prison_door_on(turf/tile)
	return (locate(/obj/machinery/door/airlock/security/glass/outpost_prison_cell) in tile) || (locate(/obj/machinery/door/airlock/security/prison_staff) in tile)

/datum/unit_test/voidcrew_outpost_prison_rebuilt_doors/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("doorsowner")
	TEST_ASSERT_NOTNULL(home, "The rebuilt door test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 8, 10), "doorsowner")
	var/mob/living/basic/outpost_prisoner/inmate = test_prisoner(prison, prison_spot(home, 7, 14))
	var/datum/outpost_prison_cell/cell_two = prison.cells[2]

	// Cell 2's door, torn out and replaced with a plain airlock
	var/turf/cell_doorway = cell_two.door_turf
	qdel(cell_two.door())
	TEST_ASSERT_NULL(cell_two.door(), "The cell still has a door after it was deleted")
	var/obj/machinery/door/airlock/plain = new(cell_doorway)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(prison_door_on), cell_doorway)), "An airlock built in a cell's doorway never became a cell door")
	TEST_ASSERT(QDELETED(plain), "The plain airlock was left beside the new cell door")
	var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/rebuilt_cell_door = locate() in cell_doorway
	TEST_ASSERT_EQUAL(rebuilt_cell_door.cell_number, 2, "The rebuilt cell door is numbered [rebuilt_cell_door.cell_number]")
	TEST_ASSERT_EQUAL(cell_two.door(), rebuilt_cell_door, "The cell does not know its rebuilt door")
	var/obj/machinery/button/outpost_prison_bolt/button = locate() in prison_spot(home, 8, 11)
	TEST_ASSERT(button.attempt_press(owner), "Cell 2's bolt button could not be pressed")
	TEST_ASSERT(rebuilt_cell_door.locked, "Cell 2's bolt button did not bolt the rebuilt door")
	prison.refresh_prisoner_reach(inmate)
	TEST_ASSERT(inmate.is_confined(), "A prisoner behind a bolted rebuilt door does not count as confined")
	TEST_ASSERT(button.attempt_press(owner), "Cell 2's bolt button could not unbolt the rebuilt door")

	// The office door, replaced with a plain glass airlock
	var/turf/office_doorway = prison_spot(home, 9, 6)
	qdel(locate(/obj/machinery/door/airlock/security/prison_staff) in office_doorway)
	var/obj/machinery/door/airlock/glass/plain_glass = new(office_doorway)
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(prison_door_on), office_doorway)), "An airlock built in the office doorway never became a staff door")
	TEST_ASSERT(QDELETED(plain_glass), "The plain airlock was left beside the new staff door")
	var/obj/machinery/door/airlock/security/prison_staff/rebuilt_staff_door = locate() in office_doorway
	TEST_ASSERT(istype(rebuilt_staff_door, /obj/machinery/door/airlock/security/prison_staff/glass), "A glass airlock came back as a solid staff door")
	TEST_ASSERT(!rebuilt_staff_door.allowed(inmate), "The rebuilt staff door opens for prisoners")
	TEST_ASSERT(!prison.prisoner_can_stand(office_doorway), "Prisoners can walk through the rebuilt staff door")
	rebuilt_staff_door.open()
	TEST_ASSERT(!rebuilt_staff_door.CanAllowThrough(inmate, SOUTH), "Prisoners can pass the open rebuilt staff door")
	rebuilt_staff_door.close()

	// Broken down, a staff door leaves nothing solid in the doorway; taken apart, it leaves its frame.
	var/turf/entrance_doorway = prison_spot(home, 9, 1)
	var/obj/machinery/door/airlock/security/prison_staff/entrance = locate() in entrance_doorway
	entrance.deconstruct(FALSE)
	TEST_ASSERT_NULL(locate(/obj/structure/door_assembly) in entrance_doorway, "A staff door broken down left a frame in the doorway")
	rebuilt_staff_door.deconstruct(TRUE)
	TEST_ASSERT_NOTNULL(locate(/obj/structure/door_assembly) in office_doorway, "A staff door taken apart left no frame")
	settle_prison_air(home)

// ===== ADMIN DELETION =====

/// Prisoners never keep an admin from deleting the outpost; they go with it.
/datum/unit_test/voidcrew_outpost_prison_admin_delete
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_admin_delete/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("deleteowner")
	TEST_ASSERT_NOTNULL(home, "The deletion test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/first = test_prisoner(prison, prison_spot(home, 3, 14))
	var/mob/living/basic/outpost_prisoner/second = test_prisoner(prison, prison_spot(home, 8, 8))
	TEST_ASSERT(is_outpost_prison_mob(first), "A prisoner does not count as one of the prison's mobs")
	var/datum/outpost_manipulator/manipulator = allocate(__IMPLIED_TYPE__, null)
	TEST_ASSERT_NULL(manipulator.deletion_denial(home), "Prisoners blocked deleting the outpost: [manipulator.deletion_denial(home)]")
	var/mob/living/carbon/human/stray = make_player(prison_spot(home, 9, 3), "deletevisitor")
	TEST_ASSERT_NOTNULL(manipulator.deletion_denial(home), "A person in the outpost did not block deleting it")
	stray.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(manipulator.deletion_denial(home), "Deletion stayed blocked after the person left")
	settle_prison_air(home)
	qdel(home)
	TEST_ASSERT(QDELETED(first) && QDELETED(second), "Deleting the outpost left its prisoners behind")
