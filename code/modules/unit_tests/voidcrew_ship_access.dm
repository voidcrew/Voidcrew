/**
 * # Ship interiors have no internal access control
 *
 * A crewed hull opens every lock inside it for anyone aboard, because a five
 * person crew holds one department's ID between them and stock /tg/ department
 * locks just wall the medic off from a toolbox.
 *
 * Two carve-outs are the part that regresses quietly. An AI-run hull keeps its
 * locks, so a pirate frigate's doors are still shut until the crew claims the
 * ship with a ship key; claiming clears the ship's ai_controller, and that is
 * the only thing standing between a boarding party and a free run of the hull.
 * And "anyone aboard" means the crew: a clientless mob gets no waiver, because
 * an access-locked door is the only thing holding wildlife - a slime in its
 * xenobiology pen, a boarder, a carp - where it belongs.
 */
/datum/unit_test/voidcrew_ship_access

/datum/unit_test/voidcrew_ship_access/Run()
	var/obj/machinery/door/airlock/instant/door = allocate(/obj/machinery/door/airlock/instant)
	door.req_access = list(ACCESS_ENGINEERING)

	// Nothing has been made into a ship yet, so this is the plain upstream answer.
	TEST_ASSERT(!door.check_access_list(list()), "a locked airlock outside any ship opened for an ID with no access at all")

	var/turf/door_turf = get_turf(door)
	var/area/original_area = door_turf.loc
	var/area/shuttle/voidcrew/ship_area = new
	door_turf.change_area(original_area, ship_area)

	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)

	// A ship area with no hull attached to it yet is still just an area.
	TEST_ASSERT(!door.check_access_list(list()), "a ship area with no docking port bypassed access")

	ship_area.shuttle_port = port
	TEST_ASSERT(!door.check_access_list(list()), "a docking port with no overmap ship bypassed access")

	port.current_ship = ship
	TEST_ASSERT(door.check_access_list(list()), "a locked airlock aboard a crewed hull stayed locked")
	TEST_ASSERT(door.allowed(null), "allowed() did not follow check_access_list() aboard a crewed hull")

	// The waiver is for the crew, and a crewmember has a client. Anything else that
	// bumps the door - a boarder, a carp in through a breach, a slime out of its
	// xenobiology pen - has to show real access the way it would upstream. An
	// access-locked windoor is the only thing containing a slime, so this assertion
	// is what keeps the Phalanx pens shut.
	var/mob/living/basic/critter = allocate(/mob/living/basic)
	TEST_ASSERT(!door.allowed(critter), "the crewed-hull waiver held an access-locked door open for a clientless mob")
	door.req_access = list()
	TEST_ASSERT(door.allowed(critter), "a door mapped with no access at all turned an ID-less mob away")
	door.req_access = list(ACCESS_ENGINEERING)

	// An AI-run hull is somebody else's ship. Its locks hold.
	ship.ai_controller = new /datum/ai_controller()
	TEST_ASSERT(!door.check_access_list(list()), "an AI-run hull gave up its locks without being claimed")

	// Claiming an NPC ship clears ai_controller, and that alone opens the hull.
	QDEL_NULL(ship.ai_controller)
	TEST_ASSERT(door.check_access_list(list()), "clearing ai_controller, which is all claiming a ship does, did not open the hull")

	door_turf.change_area(ship_area, original_area)
	ship_area.shuttle_port = null
	qdel(ship_area)

/**
 * # Lockers carry no access restriction anywhere
 *
 * Secure closets ignore req_access outright, on a ship or off one, so the ship
 * rule above never gets a say in whether a locker opens. The access list stays on
 * the closet so deconstructing it still yields electronics that mean something.
 */
/datum/unit_test/voidcrew_locker_access

/datum/unit_test/voidcrew_locker_access/Run()
	var/obj/structure/closet/secure_closet/engineering_electrical/locker = allocate(/obj/structure/closet/secure_closet/engineering_electrical)
	TEST_ASSERT(length(locker.req_access), "the test locker carries no req_access, so it cannot tell a bypass from stock behaviour")

	TEST_ASSERT(locker.check_access_list(list()), "a secure locker turned away an ID carrying no access")
	TEST_ASSERT(locker.allowed(null), "allowed() did not follow check_access_list() on a secure locker")

	// The locker is sitting in a plain station area, well away from any hull.
	var/area/locker_area = get_area(locker)
	TEST_ASSERT(!istype(locker_area, /area/shuttle/voidcrew), "the test locker spawned inside a ship area, so it cannot tell the locker rule from the ship rule")

	// The path a player actually takes: right click a locked locker while holding nothing.
	var/mob/living/carbon/human/consistent/crewmember = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(locker.locked, "the test locker did not start locked")
	locker.togglelock(crewmember, silent = TRUE)
	TEST_ASSERT(!locker.locked, "a crewmember carrying no ID could not unlock a secure locker")

/// Password rotation must invalidate both remembered passwords and captain approvals.
/datum/unit_test/voidcrew_ship_join_password_reset

/datum/unit_test/voidcrew_ship_join_password_reset/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	TEST_ASSERT(ship.set_join_password("old password"), "could not set the initial join password")
	ship.password_cleared_ckeys["passworduser"] = TRUE
	ship.password_cleared_ckeys["inviteduser"] = TRUE

	var/datum/ship_application/application = allocate(/datum/ship_application, ship, "approveduser", "Applicant", "Let me join")
	ship.crew_applications += application
	TEST_ASSERT(ship.resolve_crew_application(application, TRUE), "could not approve the application")
	TEST_ASSERT(ship.is_password_cleared("approveduser"), "approval did not grant join access")

	// Case and surrounding whitespace do not change the effective password.
	ship.set_join_password(" OLD PASSWORD ")
	TEST_ASSERT(ship.is_password_cleared("passworduser"), "saving an equivalent password unexpectedly reset join access")

	ship.set_join_password("new password")
	TEST_ASSERT(!ship.check_join_password("old password"), "the old password still works after rotation")
	TEST_ASSERT(ship.check_join_password(" NEW PASSWORD "), "the new password is not accepted with normal trimming and case folding")
	TEST_ASSERT(!ship.is_password_cleared("passworduser"), "a remembered password bypassed the new password")
	TEST_ASSERT(!ship.is_password_cleared("inviteduser"), "an old invitation bypassed the new password")
	TEST_ASSERT(!ship.is_password_cleared("approveduser"), "an old application approval bypassed the new password")

	// Removing and later restoring a password must not resurrect old approvals.
	ship.password_cleared_ckeys["approveduser"] = TRUE
	ship.set_join_password(null)
	TEST_ASSERT(ship.is_password_cleared("newuser"), "clearing the password did not open joining to everyone")
	TEST_ASSERT_EQUAL(length(ship.password_cleared_ckeys), 0, "clearing the password retained old join access")
	ship.password_cleared_ckeys["publicjoiner"] = TRUE
	ship.set_join_password("new password")
	TEST_ASSERT(!ship.is_password_cleared("approveduser"), "restoring a password resurrected an old approval")
	TEST_ASSERT(!ship.is_password_cleared("publicjoiner"), "someone who joined while public bypassed the new lock")

/// A manual reset revokes future joins while preserving the password and serving crew.
/datum/unit_test/voidcrew_ship_join_access_reset

/datum/unit_test/voidcrew_ship_join_access_reset/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/obj/structure/overmap/ship/other_ship = allocate(/obj/structure/overmap/ship)
	ship.set_join_password("password")
	other_ship.set_join_password("other password")
	ship.password_cleared_ckeys["returninguser"] = TRUE
	other_ship.password_cleared_ckeys["returninguser"] = TRUE

	var/mob/living/carbon/human/consistent/crewmember = allocate(/mob/living/carbon/human/consistent)
	crewmember.mind_initialize()
	ship.ship_team = new /datum/team/voidcrew()
	ship.ship_team.ship = ship
	ship.enlist_crewmember(crewmember)
	ship.claimed_captain = crewmember.mind

	ship.reset_join_access()
	TEST_ASSERT_EQUAL(ship.join_password, "password", "resetting join access changed the password")
	TEST_ASSERT(!ship.is_password_cleared("returninguser"), "resetting join access did not revoke remembered access")
	TEST_ASSERT(other_ship.is_password_cleared("returninguser"), "resetting one ship revoked access to another ship")
	TEST_ASSERT(ship.is_ship_crew(crewmember), "resetting join access removed a serving crewmember's airlock access")
	TEST_ASSERT(ship.is_ship_captain(crewmember), "resetting join access removed the captain's authority")
	TEST_ASSERT(crewmember.real_name in ship.manifest, "resetting join access removed a serving crewmember from the manifest")

	var/datum/ship_application/application = allocate(/datum/ship_application, ship, "returninguser", "Applicant", "Let me rejoin")
	ship.crew_applications += application
	TEST_ASSERT(ship.resolve_crew_application(application, TRUE), "could not approve an application after resetting access")
	TEST_ASSERT(ship.is_password_cleared("returninguser"), "a fresh approval did not restore join access")
	ship.reset_join_access()
	TEST_ASSERT(!ship.is_password_cleared("returninguser"), "a manual reset did not revoke an application approval")

	ship.ship_team.remove_member(crewmember.mind)

/// Docking and safe air must not let visitors bypass crew-only exterior airlocks.
/datum/unit_test/voidcrew_ship_crew_airlocks
	var/turf/door_turf
	var/area/original_area
	var/area/shuttle/voidcrew/ship_area
	var/obj/structure/overmap/ship/ship

/datum/unit_test/voidcrew_ship_crew_airlocks/Destroy()
	if(ship_area)
		door_turf.change_area(ship_area, original_area)
		ship_area.shuttle_port = null
		QDEL_NULL(ship_area)
	if(ship)
		ship.set_crew_only_airlocks(FALSE)
	return ..()

/datum/unit_test/voidcrew_ship_crew_airlocks/Run()
	var/obj/machinery/door/airlock/external/door = allocate(/obj/machinery/door/airlock/external)
	door.autoclose = FALSE
	door.space_dir = EAST
	door.shuttledocked = TRUE
	door_turf = get_turf(door)
	original_area = door_turf.loc
	ship_area = new
	door_turf.change_area(original_area, ship_area)
	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew)
	ship = allocate(/obj/structure/overmap/ship)
	ship_area.shuttle_port = port
	port.current_ship = ship
	ship.ship_team = new /datum/team/voidcrew()
	ship.ship_team.ship = ship

	var/mob/living/carbon/human/consistent/visitor = allocate(/mob/living/carbon/human/consistent, get_step(door, EAST))
	visitor.mock_client = allocate(/datum/client_interface)
	visitor.mind_initialize()
	TEST_ASSERT(door.hasPower(), "the exterior airlock needs power to exercise the safety access bypass")
	TEST_ASSERT(door.try_safety_unlock(visitor), "an unlocked, docked ship refused a visitor")
	TEST_ASSERT(!door.density, "the unlocked exterior airlock did not actually open")
	door.close()

	TEST_ASSERT(ship.set_crew_only_airlocks(TRUE), "could not enable crew-only airlocks")
	TEST_ASSERT(!door.allowed(visitor), "an unrelated visitor passed the normal crew check")
	TEST_ASSERT(!door.try_safety_unlock(visitor), "docking bypassed the crew lock")
	TEST_ASSERT(door.density, "a visitor opened the docked exterior airlock")

	// Exercise the actual bump and empty-hand entry points as well as the safety helper.
	visitor.last_bumped = 0
	door.Bumped(visitor)
	TEST_ASSERT(door.density && !door.operating, "bumping a docked exterior airlock bypassed the crew lock")
	door.attack_hand(visitor)
	TEST_ASSERT(door.density && !door.operating, "clicking a docked exterior airlock bypassed the crew lock")

	door.shuttledocked = FALSE
	var/obj/machinery/door/airlock/external/linked_door = allocate(/obj/machinery/door/airlock/external, run_loc_floor_top_right)
	linked_door.shuttledocked = TRUE
	door.cyclelinkedairlock = linked_door
	TEST_ASSERT(!door.try_safety_unlock(visitor), "a docked cycle partner bypassed the crew lock")
	door.cyclelinkedairlock = null
	// is_safe_turf() also rejects occupied tiles, so approach from the other side.
	visitor.forceMove(get_step(door, NORTH))
	TEST_ASSERT(is_safe_turf(get_step(door, EAST), TRUE, FALSE), "the test needs safe air outside the door")
	TEST_ASSERT(!door.try_safety_unlock(visitor), "safe air outside bypassed the crew lock")

	// Emergency access and unrestricted sides cannot override the captain's lock either.
	door.emergency = TRUE
	door.unres_sides = NORTH
	TEST_ASSERT(!door.try_safety_unlock(visitor), "emergency access or an unrestricted side bypassed the crew lock")
	door.emergency = FALSE
	door.unres_sides = NONE

	ship.ship_team.add_member(visitor.mind)
	TEST_ASSERT(door.try_safety_unlock(visitor), "the crew lock refused a rostered crewmember")
	TEST_ASSERT(!door.density, "the crew member could not open the exterior airlock")
	door.close()
	ship.ship_team.remove_member(visitor.mind)

	// A disabled reader retains the existing safety bypass, as advertised in the UI.
	door.wires.cut(WIRE_IDSCAN)
	TEST_ASSERT(door.try_safety_unlock(visitor), "the crew lock disabled the cut-reader safety bypass")
	door.close()
	door.wires.cut(WIRE_IDSCAN)

	TEST_ASSERT(ship.set_crew_only_airlocks(FALSE), "could not disable crew-only airlocks")
	TEST_ASSERT(door.try_safety_unlock(visitor), "disabling the crew lock did not restore visitor entry")
	TEST_ASSERT(!door.density, "the exterior airlock stayed shut after the crew lock was disabled")

/// Same-type ship jobs must not confer command, prevent acting command, or survive demotion.
/datum/unit_test/voidcrew_pill_captain_commands/Run()
	var/datum/map_template/shuttle/voidcrew/pill/template = allocate(/datum/map_template/shuttle/voidcrew/pill)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.job_slots = template.assemble_job_slots()
	for(var/datum/job/job as anything in ship.job_slots)
		allocated += job
	ship.ship_team = allocate(/datum/team/voidcrew)
	ship.ship_team.ship = ship
	var/datum/job/head_prisoner = ship.get_captain_job()
	var/datum/job/prisoner = ship.job_slots[2]
	TEST_ASSERT_EQUAL(head_prisoner.type, prisoner.type, "The real Pill slots must exercise jobs with the same type")
	TEST_ASSERT_NOTEQUAL(head_prisoner, prisoner, "The Pill's command and crew slots must be separate datums")

	var/mob/living/carbon/human/consistent/captain = allocate(/mob/living/carbon/human/consistent)
	captain.mind_initialize()
	captain.mind.assigned_role = head_prisoner
	var/mob/living/carbon/human/consistent/crew = allocate(/mob/living/carbon/human/consistent)
	crew.mind_initialize()
	crew.mind.assigned_role = prisoner
	ship.ship_team.add_member(crew.mind)

	TEST_ASSERT(!ship.has_real_captain(), "An ordinary Prisoner must not count as the Head Prisoner")
	TEST_ASSERT(!ship.is_ship_captain(crew), "An ordinary Prisoner must not receive job-based command")
	TEST_ASSERT(!ship.is_ship_captain(captain), "The command slot must not authorize someone outside the roster")
	TEST_ASSERT(ship.make_acting_captain(crew), "The first Prisoner must be able to take acting command")
	TEST_ASSERT(ship.is_ship_captain(crew), "Acting command must authorize the Prisoner's ship controls")

	var/datum/admin_crew_panel/admin_panel = allocate(/datum/admin_crew_panel)
	admin_panel.selected_ship = ship
	var/list/panel_data = admin_panel.ui_data(crew)
	var/list/crew_row = panel_data["crew"][1]
	TEST_ASSERT(crew_row["is_captain"], "The admin roster must show acting command")
	TEST_ASSERT(admin_panel.demote_from_captain(crew.mind, ship), "An admin must be able to demote an acting captain")
	TEST_ASSERT(!ship.is_ship_captain(crew), "Demotion must remove acting command")
	TEST_ASSERT_NULL(locate(/datum/action/innate/captain_management) in crew.actions, "Demotion must remove the acting captain's controls")

	ship.ship_team.add_member(captain.mind)
	ship.refresh_command_buttons()
	TEST_ASSERT(ship.has_real_captain(), "The actual Head Prisoner must count as a real captain")
	TEST_ASSERT(ship.is_ship_captain(captain), "The actual Head Prisoner must hold command")
	TEST_ASSERT(!ship.is_ship_captain(crew), "A Prisoner must not share the Head Prisoner's command")
	TEST_ASSERT_NOTNULL(locate(/datum/action/innate/captain_management) in captain.actions, "The Head Prisoner must receive ship controls")
	TEST_ASSERT(admin_panel.demote_from_captain(captain.mind, ship), "An admin must be able to demote the Head Prisoner")
	TEST_ASSERT_EQUAL(captain.mind.assigned_role, prisoner, "Demotion must assign the ordinary Prisoner slot")
	TEST_ASSERT(!ship.has_real_captain(), "Changing to a same-type crew slot must remove real command")
	TEST_ASSERT(!ship.is_ship_captain(captain), "The demoted Head Prisoner must lose command")
	TEST_ASSERT_NULL(locate(/datum/action/innate/captain_management) in captain.actions, "The demoted Head Prisoner must lose ship controls")
	TEST_ASSERT(!admin_panel.demote_from_captain(captain.mind, ship), "Repeated demotion must recognize that the Prisoner is already demoted")

	// An invited officer can come from another Pill with identically named job slots.
	var/list/other_slots = template.assemble_job_slots()
	for(var/datum/job/job as anything in other_slots)
		allocated += job
	var/datum/job/other_head_prisoner = other_slots[1]
	captain.mind.assigned_role = other_head_prisoner
	TEST_ASSERT(!ship.has_real_captain(), "Another Pill's Head Prisoner must not fill this ship's command slot")
	TEST_ASSERT(!ship.is_ship_captain(captain), "An invited captain must not inherit command of another Pill")
	TEST_ASSERT(!admin_panel.demote_from_captain(captain.mind, ship), "Demotion on this ship must not change another ship's officer role")
	TEST_ASSERT_EQUAL(captain.mind.assigned_role, other_head_prisoner, "An unrelated officer role must be preserved")

	admin_panel.promote_to_captain(crew.mind, captain)
	TEST_ASSERT(ship.is_ship_captain(crew), "Admin promotion must authorize the selected crewmember")
	TEST_ASSERT(!ship.is_ship_captain(captain), "Admin promotion must confer exclusive command")
	TEST_ASSERT_NOTNULL(locate(/datum/action/innate/captain_management) in crew.actions, "Admin promotion must restore ship controls")
	TEST_ASSERT(admin_panel.demote_from_captain(crew.mind, ship), "An admin-appointed captain must be demotable")
	TEST_ASSERT(!ship.is_ship_captain(crew), "Demotion must clear both the appointment and the officer job")
	TEST_ASSERT_NULL(locate(/datum/action/innate/captain_management) in crew.actions, "Demotion must retire the restored controls")

	// The admin panel must use the same rules even for minds without a current body.
	var/datum/mind/offline_captain = allocate(/datum/mind)
	offline_captain.assigned_role = head_prisoner
	ship.ship_team.members += offline_captain
	panel_data = admin_panel.ui_data(crew)
	var/list/offline_row = panel_data["crew"][3]
	TEST_ASSERT(offline_row["is_captain"], "A bodyless Head Prisoner must still appear as captain to admins")
	TEST_ASSERT(!offline_row["is_online"], "A bodyless captain must appear offline")
	TEST_ASSERT(admin_panel.demote_from_captain(offline_captain, ship), "A bodyless captain must be demotable")
	TEST_ASSERT(!ship.is_ship_captain_mind(offline_captain), "The bodyless captain must remain demoted")
	ship.ship_team.members -= offline_captain
	ship.ship_team.remove_member(captain.mind)
	ship.ship_team.remove_member(crew.mind)
