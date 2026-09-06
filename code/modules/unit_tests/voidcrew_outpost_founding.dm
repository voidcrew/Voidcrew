/// Founding is recoverable, has no ownership cap and grants the ship crew independent access.
/datum/unit_test/voidcrew_outpost_founding_recovery
	var/founder_key = "outpostfoundingtest"
	var/mob/living/carbon/human/founder
	var/mob/living/carbon/human/recipient
	var/mob/living/carbon/human/crewmate
	var/mob/living/carbon/human/disconnected

/datum/unit_test/voidcrew_outpost_founding_recovery/Destroy()
	if(!QDELETED(founder))
		founder.key = null
	if(!QDELETED(recipient))
		recipient.key = null
	if(!QDELETED(crewmate))
		crewmate.key = null
	if(!QDELETED(disconnected))
		disconnected.key = null
	return ..()

/datum/unit_test/voidcrew_outpost_founding_recovery/proc/prepare_founder()
	founder = allocate(/mob/living/carbon/human/consistent)
	founder.key = founder_key
	founder.mind_initialize()
	return founder.ckey == founder_key && founder.mind

/datum/unit_test/voidcrew_outpost_founding_recovery/Run()
	TEST_ASSERT(prepare_founder(), "Could not establish the founding fixture's player identity")
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/team/voidcrew/crew = allocate(/datum/team/voidcrew)
	ship.ship_team = crew
	crew.ship = ship
	crew.add_member(founder.mind)
	crewmate = allocate(/mob/living/carbon/human/consistent)
	crewmate.key = "[founder_key]crew"
	crewmate.mind_initialize()
	crew.add_member(crewmate.mind)
	disconnected = allocate(/mob/living/carbon/human/consistent)
	disconnected.key = "[founder_key]offline"
	disconnected.mind_initialize()
	crew.add_member(disconnected.mind)
	disconnected.key = null
	recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.key = "[founder_key]recipient"
	recipient.mind_initialize()
	var/datum/team/voidcrew/visitors = allocate(/datum/team/voidcrew)
	visitors.add_member(recipient.mind)
	var/datum/map_template/player_outpost/invalid_shell = allocate(/datum/map_template/player_outpost/small/refused_founding_fixture)
	var/obj/structure/overmap/dynamic/player_outpost/failed = allocate(/obj/structure/overmap/dynamic/player_outpost)
	TEST_ASSERT(!failed.found(founder, invalid_shell, "Failed claim"), "A refused shell completed founding")
	TEST_ASSERT(QDELETED(failed), "Failed founding retained an incomplete claim")
	TEST_ASSERT_NULL(failed.mapzone, "Failed founding retained its reserved map zone")
	var/datum/map_template/player_outpost/small/shell = allocate(/datum/map_template/player_outpost/small)
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	TEST_ASSERT(home.found(founder, shell, "Retried claim"), "A failed attempt prevented founding a valid home")
	TEST_ASSERT(home.loaded && home.home_bundle_installed, "Successful founding omitted the purchased home services")
	TEST_ASSERT(home.can_manage(founder) && home.is_resident(founder), "Founding did not register its actual owner and resident")
	TEST_ASSERT(home.is_resident(crewmate) && home.can_build(crewmate), "The founding crew did not receive resident and construction permission")
	TEST_ASSERT(!home.can_manage(crewmate) && !home.can_spend(crewmate), "Founding crew received management or treasury permission")
	TEST_ASSERT(home.is_resident(disconnected) && home.has_resident_clearance("[founder_key]offline"), "A disconnected crewmate lost membership or remembered return access")
	TEST_ASSERT("[founder_key]offline" in home.authorized_builder_ckeys, "A disconnected crewmate did not receive construction permission")
	TEST_ASSERT(!home.is_resident(recipient) && !home.can_build(recipient), "Founding enrolled an unrelated visiting crewmember")
	TEST_ASSERT((crewmate.mind in crew.members) && (crew in crewmate.mind.ship_teams), "Outpost membership displaced the crewmate's ship membership")
	TEST_ASSERT((recipient.mind in visitors.members) && (visitors in recipient.mind.ship_teams), "Founding changed another ship's membership")
	var/datum/bank_account/account = home.treasury
	var/obj/structure/overmap/dynamic/player_outpost/second = allocate(/obj/structure/overmap/dynamic/player_outpost)
	var/datum/map_template/player_outpost/small/second_shell = allocate(/datum/map_template/player_outpost/small)
	TEST_ASSERT(second.found(founder, second_shell, "Second claim"), "Existing ownership prevented founding another home")
	TEST_ASSERT(home.can_manage(founder) && second.can_manage(founder), "Founding another home removed existing ownership")
	TEST_ASSERT(home.treasury != second.treasury, "Multiple owned outposts shared a bank account")
	TEST_ASSERT(!home.found(founder, shell, "Repeat initialization"), "An existing site could be founded twice")
	TEST_ASSERT(!QDELETED(home) && home.treasury == account, "Repeated initialization destroyed the existing site or its account")
	account.adjust_money(73, "Founding lifecycle fixture")
	founder.forceMove(home.arrival_turf)
	TEST_ASSERT(home.set_outpost_name("Renamed claim", founder), "The owner could not rename the purchased home")
	TEST_ASSERT_EQUAL(home.treasury, account, "Renaming replaced the claim's account")
	TEST_ASSERT_EQUAL(account.account_balance, 73, "Renaming changed the claim's funds")
	qdel(ship)
	TEST_ASSERT(home.is_resident(crewmate) && home.can_build(crewmate) && home.has_resident_clearance(crewmate.ckey), "Losing the founding ship removed the crew's independent outpost grants")
	recipient.forceMove(home.arrival_turf)
	TEST_ASSERT(home.transfer_ownership(recipient, founder), "The owner could not transfer the actual purchased home")
	TEST_ASSERT(home.can_manage(recipient) && home.can_spend(recipient), "The new owner did not receive management and treasury authority")
	TEST_ASSERT(!home.can_spend(founder), "The former owner retained implicit treasury authority")
	TEST_ASSERT_EQUAL(home.treasury, account, "Ownership transfer replaced the claim's account")
	TEST_ASSERT_EQUAL(account.account_balance, 73, "Ownership transfer changed the claim's funds")
	TEST_ASSERT(home.is_resident(crewmate) && home.can_build(crewmate), "Ownership transfer removed another founding resident's construction grant")
	TEST_ASSERT(!home.can_build(founder), "The former owner retained the automatic founding construction grant after transfer")
	TEST_ASSERT(second.transfer_ownership(recipient, founder), "An existing outpost owner could not receive another outpost")
	TEST_ASSERT(home.is_owner(recipient) && second.is_owner(recipient), "A transfer displaced the recipient's other outpost")

/// Exercise refusal after the claim allocates its map zone, without logging a malformed map.
/datum/map_template/player_outpost/small/refused_founding_fixture/load(turf/target, centered = FALSE)
	return FALSE

/// Approval resumes the real ship docking path without overriding a departed or busy ship.
/datum/unit_test/voidcrew_outpost_docking_clearance
	var/obj/structure/overmap/ship/ship
	var/obj/docking_port/mobile/voidcrew/port
	var/obj/docking_port/stationary/destination

/datum/unit_test/voidcrew_outpost_docking_clearance/Destroy()
	if(!QDELETED(ship))
		if(ship.dock_warmup_timer)
			deltimer(ship.dock_warmup_timer)
			ship.dock_warmup_timer = null
		ship.shuttle = null
		ship.docked = null
	if(!QDELETED(port))
		port.current_ship = null
		qdel(port, force = TRUE)
	if(!QDELETED(destination))
		qdel(destination, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_outpost_docking_clearance/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.loaded = TRUE
	ship = allocate(/obj/structure/overmap/ship)
	port = allocate(/obj/docking_port/mobile/voidcrew)
	port.width = 1
	port.height = 1
	destination = allocate(/obj/docking_port/stationary)
	port.port_destinations = destination
	ship.shuttle = port
	// Fork state defines are included after unit tests.
	ship.state = "flying"
	ship.forceMove(run_loc_floor_top_right)
	home.pending_dock_requests[ship] = world.time
	home.approve_dock_request(ship)
	TEST_ASSERT_NULL(ship.docked, "Clearance pulled a departed ship back to the outpost")
	ship.forceMove(get_turf(home))
	ship.speed[1] = 1
	home.pending_dock_requests[ship] = world.time
	home.approve_dock_request(ship)
	TEST_ASSERT_NULL(ship.docked, "Clearance docked a moving ship")
	ship.speed[1] = 0
	ship.is_interdicted = TRUE
	home.pending_dock_requests[ship] = world.time
	home.approve_dock_request(ship)
	TEST_ASSERT_NULL(ship.docked, "Automatic docking bypassed interdiction")
	ship.is_interdicted = FALSE
	ship.state = "docking"
	home.pending_dock_requests[ship] = world.time
	home.approve_dock_request(ship)
	TEST_ASSERT_NULL(ship.dock_warmup_timer, "Approval interrupted another docking operation")
	ship.state = "flying"
	home.pending_dock_requests[ship] = world.time
	home.approve_dock_request(ship)
	TEST_ASSERT_NULL(ship.docked, "Automatic approval bypassed the destination size check")
	destination.width = 1
	destination.height = 1
	home.pending_dock_requests[ship] = world.time
	home.approve_dock_request(ship)
	TEST_ASSERT_EQUAL(ship.docked, home, "Approval did not automatically resume the waiting ship's approach")
	TEST_ASSERT_EQUAL(ship.state, "docking", "Automatic approval skipped normal docking state")
	TEST_ASSERT_NOTNULL(ship.dock_warmup_timer, "Automatic approval skipped the normal docking warmup")
	TEST_ASSERT(!(ship in home.pending_dock_requests), "Approval retained the pending request")
	var/timer = ship.dock_warmup_timer
	home.approve_dock_request(ship)
	TEST_ASSERT_EQUAL(ship.dock_warmup_timer, timer, "Repeated approval restarted an active approach")

/// Simulate a populated home without connecting clients to an unattended test world.
/obj/structure/overmap/dynamic/player_outpost/populated_resident_test/active_resident_count()
	return 100

/datum/unit_test/voidcrew_outpost_no_resident_cap/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost/populated_resident_test)
	home.loaded = TRUE
	home.founder_ckey = "nocapowner"
	home.resident_mode = "open"
	for(var/i in 1 to 100)
		home.arrival_reservations["reservation[i]"] = TRUE
	TEST_ASSERT_NULL(home.resident_admission_error("newresident", reservation = TRUE), "Resident or reservation counts capped an otherwise valid arrival")
	TEST_ASSERT_NOTNULL(home.resident_admission_error("newresident"), "Removing the resident cap also removed the physical cryopod requirement")
	home.blocked_residents |= "newresident"
	TEST_ASSERT_NOTNULL(home.resident_admission_error("newresident", reservation = TRUE), "Removing the resident cap bypassed revoked access")
