/// Round identity contracts. Fork defines follow test includes, so bands/permissions use literals.
/datum/unit_test/voidcrew_zone_identity
	var/list/test_records = list()
	var/list/test_ports = list()

/datum/unit_test/voidcrew_zone_identity/Destroy()
	for(var/obj/docking_port/mobile/voidcrew/port in test_ports)
		port.current_ship = null
		qdel(port, force = TRUE)
	QDEL_LIST(test_records)
	return ..()

/datum/unit_test/voidcrew_zone_identity/proc/record_for(obj/structure/overmap/ship/ship)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	test_records |= record
	return record

/datum/unit_test/voidcrew_zone_identity/proc/make_ship(datum/voidcrew_crew_record/record)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.ship_team = new
	ship.ship_team.ship = ship
	if(record)
		ship.ship_team.set_crew_record(record)
	record_for(ship)
	return ship

/datum/unit_test/voidcrew_zone_identity/proc/make_member(player_key)
	var/mob/living/carbon/human/consistent/member = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	member.mind_initialize()
	allocated += member.mind
	if(player_key)
		member.key = player_key
	member.mind.key = player_key
	return member

/datum/unit_test/voidcrew_zone_identity/proc/clear_green(datum/voidcrew_crew_record/record)
	for(var/family in list("named_kill", "hunt", "capture"))
		record.claim_zone_work(family, 1, 1, "green_[family]")

/// The six families, lifetime caps, cumulative permissions and once-only claim boundary.
/datum/unit_test/voidcrew_zone_identity/progression/Run()
	var/datum/voidcrew_crew_record/record = allocate(/datum/voidcrew_crew_record)
	TEST_ASSERT_EQUAL(length(record.zone_families), 3, "Missing work bands")
	for(var/band in record.zone_families)
		TEST_ASSERT_EQUAL(length(record.zone_families[band]), 6, "A band does not have six family counters")
	var/list/qualifying = list(
		/datum/mission/recovery/kill = "named_kill",
		/datum/mission/recovery/kill/outpost = "named_kill",
		/datum/mission/big_game_hunt = "hunt",
		/datum/mission/live_capture = "capture",
		/datum/mission/poacher_bust = "poachers",
		/datum/mission/recovery/survey = "pylons",
		/datum/mission/research/core_sample = "pylons",
		/datum/mission/recovery/extraction = "extraction",
	)
	for(var/mission_type in subtypesof(/datum/mission))
		var/expected
		for(var/family_type in qualifying)
			if(ispath(mission_type, family_type))
				expected = qualifying[family_type]
		TEST_ASSERT_EQUAL(zone_reputation_family(mission_type), expected, "Wrong progression family for [mission_type]")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 0, "Fresh crew is not Public")
	TEST_ASSERT(!record.can_work_in_zone(2) && !record.can_work_in_zone(3), "A new crew can accept dangerous work")
	TEST_ASSERT_EQUAL(record.claim_zone_work("named_kill", 99, 3, "bad_band"), 0, "Unknown band earned standing")
	TEST_ASSERT_EQUAL(record.claim_zone_work("waves", 1, 3, "bad_family"), 0, "Prize-family alias earned standing")
	TEST_ASSERT_EQUAL(record.claim_zone_work("named_kill", 1, 3, "first"), 1, "Green family exceeded its lifetime cap")
	TEST_ASSERT_EQUAL(record.claim_zone_work("named_kill", 1, 3, "second"), 0, "Repeated family earned more green standing")
	TEST_ASSERT(record.settlement_claims["second"], "Capped settlement was not claimed")
	TEST_ASSERT_EQUAL(record.claim_zone_work("hunt", 1, 3, "first"), 0, "Duplicate receipt earned standing")
	clear_green(record)
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 1, "Three green families did not open yellow")
	TEST_ASSERT(record.can_work_in_zone(2) && !record.can_work_in_zone(3), "Yellow admission is wrong")
	TEST_ASSERT_EQUAL(record.claim_zone_work("hunt", 2, 3, "yellow1"), 3, "Hard work is not worth three")
	TEST_ASSERT_EQUAL(record.claim_zone_work("hunt", 2, 3, "yellow2"), 2, "Yellow family was not clamped at five")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 1, "One yellow family opened advanced")
	TEST_ASSERT_EQUAL(record.claim_zone_work("capture", 2, 1, "yellow3"), 1, "Easy work is not worth one")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 2, "Cumulative yellow threshold did not open advanced")
	TEST_ASSERT(record.can_work_in_zone(3), "Advanced crew cannot accept red work")
	for(var/index in 1 to 3)
		record.claim_zone_work("pylons", 3, 3, "red_pylons_[index]")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 2, "One red family opened elite")
	record.claim_zone_work("extraction", 3, 3, "red_extract1")
	record.claim_zone_work("extraction", 3, 1, "red_extract2")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 3, "Nine red standing did not open elite")
	TEST_ASSERT_EQUAL(record.zone_totals["1"], 3, "Dangerous work leaked into green")
	TEST_ASSERT_EQUAL(zone_work_reward(2), 2, "Medium award drifted from board favor")
	TEST_ASSERT(!record.has_zone_permission(4) && !record.can_work_in_zone(null), "Unknown permission/band passed")

/// Purchases/requisitions, split hulls, abandonment, wrecks, cryo and keyed mind replacement.
/datum/unit_test/voidcrew_zone_identity/continuation/Run()
	var/obj/structure/overmap/ship/first = make_ship()
	var/datum/voidcrew_crew_record/record = record_for(first)
	var/mob/living/carbon/human/member = make_member("zoneidentitycontinuation")
	first.enlist_crewmember(member)
	clear_green(record)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.grant_favor(first, 6)
	var/obj/structure/overmap/ship/second = make_ship()
	TEST_ASSERT(second.bind_reputation_crew(member.mind), "Purchase/requisition could not continue its buyer's crew")
	second.enlist_crewmember(member)
	TEST_ASSERT_EQUAL(record_for(second), record, "New hull copied or reset the crew")
	TEST_ASSERT(member.mind in first.ship_team.members, "A second hull removed same-crew membership")
	TEST_ASSERT_EQUAL(shop.get_favor(second), 6, "New hull lost trader discounts")
	TEST_ASSERT(record.claim_purchase(/datum/shop_sku/favor/pike_ledger), "First cap claim failed")
	shop.record_crew_purchase(second, /datum/shop_sku/favor/pike_ledger)
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(first, /datum/shop_sku/favor/pike_ledger), 2, "Hull teams kept separate purchase histories")
	var/obj/machinery/cryopod/pod = allocate(/obj/machinery/cryopod)
	pod.detach_from_crews(member.mind, member.real_name)
	TEST_ASSERT_EQUAL(length(member.mind.ship_teams), 0, "Cryo left hull rosters")
	TEST_ASSERT_EQUAL(member.mind.get_reputation_crew(), record, "Cryo erased affiliation")
	TEST_ASSERT_EQUAL(GLOB.voidcrew_crew_roster["zoneidentitycontinuation"], record, "Cryo lost keyed recovery")
	first.enlist_crewmember(member)
	first.abandon_ship(FALSE)
	TEST_ASSERT_EQUAL(member.mind.get_reputation_crew(), record, "Automated abandonment erased affiliation")
	qdel(first)
	qdel(second)
	TEST_ASSERT(!QDELETED(record) && (record in GLOB.voidcrew_crew_records), "Wreck disposed of the round record")
	var/datum/mind/old_mind = member.mind
	qdel(old_mind)
	TEST_ASSERT_EQUAL(GLOB.voidcrew_crew_roster["zoneidentitycontinuation"], record, "Mind replacement lost recovery")
	var/mob/living/carbon/human/replacement = make_member("zoneidentitycontinuation")
	var/obj/structure/overmap/ship/rebuilt = make_ship()
	rebuilt.bind_reputation_crew(replacement.mind)
	rebuilt.enlist_crewmember(replacement)
	TEST_ASSERT_EQUAL(record_for(rebuilt), record, "Respawned buyer did not recover the live crew")
	TEST_ASSERT_EQUAL(record.get_zone_permission(), 1, "Wreck/recovery lost reputation")
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(rebuilt, /datum/shop_sku/favor/pike_ledger), 2, "Recovery reset caps")
	var/obj/structure/overmap/ship/fresh = make_ship()
	TEST_ASSERT(fresh.bind_reputation_crew(replacement.mind, TRUE), "Could not form a new crew on an empty hull")
	fresh.enlist_crewmember(replacement)
	var/datum/voidcrew_crew_record/new_record = record_for(fresh)
	TEST_ASSERT(new_record != record && new_record.get_zone_permission() == 0, "Independent crew inherited standing")
	TEST_ASSERT_EQUAL(shop.get_favor(fresh), 0, "Independent crew inherited favor")
	TEST_ASSERT_EQUAL(shop.get_crew_purchases(fresh, /datum/shop_sku/favor/pike_ledger), 0, "Independent crew inherited purchases")
	TEST_ASSERT(!fresh.bind_reputation_crew(replacement.mind, TRUE), "Occupied hull could reset its identity")

/// Two successful loads bind before either HUD enrollment; a refused load leaves no affiliation.
/datum/unit_test/voidcrew_zone_identity/simultaneous_founders/Run()
	var/mob/living/carbon/human/newcomer = make_member("zoneidentitynewcomer")
	var/obj/structure/overmap/ship/unloaded = allocate(/obj/structure/overmap/ship)
	TEST_ASSERT(!unloaded.bind_reputation_crew(newcomer.mind), "An unloaded hull accepted crew binding")
	TEST_ASSERT_NULL(newcomer.mind.get_reputation_crew(), "A refused load changed affiliation")
	var/obj/structure/overmap/ship/first = make_ship()
	var/obj/structure/overmap/ship/second = make_ship()
	TEST_ASSERT(first.bind_reputation_crew(newcomer.mind), "First commissioning failed")
	TEST_ASSERT(second.bind_reputation_crew(newcomer.mind), "Concurrent commissioning failed")
	TEST_ASSERT_EQUAL(record_for(first), record_for(second), "Simultaneous newcomer builds founded separate crews")
	first.enlist_crewmember(newcomer)
	second.enlist_crewmember(newcomer)
	TEST_ASSERT(newcomer.mind in first.ship_team.members, "Concurrent enlistment stripped a same-crew hull")
	TEST_ASSERT(newcomer.mind in second.ship_team.members, "Concurrent enlistment lost the other hull")
	// Pin both lobby routes to the tested binding transaction, after successful loading.
	var/source = file2text("voidcrew/edits/mobs/new_player.dm")
	var/purchase_start = findtext(source, "/mob/dead/new_player/proc/spawn_ship_with_upgrades(")
	var/requisition_start = findtext(source, "/mob/dead/new_player/proc/requisition_free_hull()")
	var/spawn_start = findtext(source, "/mob/dead/new_player/proc/AttemptSpawnOnShip(")
	TEST_ASSERT(purchase_start && requisition_start && spawn_start, "Lobby route anchors are missing")
	for(var/route in list(copytext(source, purchase_start, requisition_start), copytext(source, requisition_start, spawn_start)))
		var/binding = findtext(route, "target.bind_reputation_crew(mind, form_new)")
		var/enrollment = findtext(route, "if(!AttemptSpawnOnShip(")
		TEST_ASSERT(binding && enrollment && binding < enrollment, "A lobby hull enrolled before binding its buyer's crew")

/// Every actual enrollment route evicts other crews and every old life of the ckey.
/datum/unit_test/voidcrew_zone_identity/join_routes/Run()
	var/obj/structure/overmap/ship/old_ship = make_ship()
	var/obj/structure/overmap/ship/new_ship = make_ship()
	var/mob/living/carbon/human/old_life = make_member("zoneidentityrespawn")
	old_ship.enlist_crewmember(old_life)
	var/mob/living/carbon/human/new_life = make_member("zoneidentityrespawn")
	new_ship.register_crewmember(new_life) // Human job/latejoin after character transfer.
	TEST_ASSERT(!(old_life.mind in old_ship.ship_team.members), "Respawn left the old keyed mind rostered")
	TEST_ASSERT_NULL(old_life.mind.get_reputation_crew(), "Respawn left the old mind affiliated")
	TEST_ASSERT_EQUAL(new_life.mind.get_reputation_crew(), new_ship.get_crew_record(), "Latejoin did not switch crews")
	TEST_ASSERT(!old_ship.is_ship_crew(new_life), "Historical crew access survived the switch")
	old_ship.password_cleared_ckeys["zoneidentityrespawn"] = TRUE
	TEST_ASSERT(!old_ship.is_ship_crew(new_life), "Saved join clearance granted old services")
	TEST_ASSERT_NULL(get_crew_ship(old_life), "Old life retained shop access")
	TEST_ASSERT_EQUAL(metric_crew_ship(new_life), new_ship, "Metrics chose an obsolete crew")
	var/datum/admin_crew_panel/admin_panel = allocate(/datum/admin_crew_panel)
	admin_panel.selected_ship = old_ship
	admin_panel.add_crew_member(new_life.mind, old_life)
	TEST_ASSERT_EQUAL(new_life.mind.get_reputation_crew(), old_ship.get_crew_record(), "Admin crew-add did not switch")
	TEST_ASSERT(!(new_life.mind in new_ship.ship_team.members), "Admin crew-add retained the old roster")
	new_ship.ship_team.admin_add_member(old_life, new_life.mind)
	TEST_ASSERT_EQUAL(new_life.mind.get_reputation_crew(), new_ship.get_crew_record(), "Generic team panel did not switch")
	TEST_ASSERT(!(new_life.mind in old_ship.ship_team.members), "Generic team panel retained the old roster")
	// A HUD-only add must not silently switch an established affiliation.
	old_ship.ship_team.add_member(new_life.mind)
	TEST_ASSERT(!(new_life.mind in old_ship.ship_team.members), "HUD enrollment bypassed authoritative joining")
	var/mob/living/carbon/human/captain = make_member()
	old_ship.enlist_crewmember(captain)
	old_ship.claimed_captain = captain.mind
	var/datum/captain_management_ui/invitation = allocate(/datum/captain_management_ui)
	invitation.ship = old_ship
	invitation.captain = captain
	TEST_ASSERT(invitation.accept_crew_invite(new_life), "Captain invitation failed")
	TEST_ASSERT_EQUAL(new_life.mind.get_reputation_crew(), old_ship.get_crew_record(), "Invitation did not switch crews")
	TEST_ASSERT(!(new_life.mind in new_ship.ship_team.members), "Invitation retained another crew")
	var/datum/voidcrew_crew_record/unchanged = old_ship.get_crew_record()
	admin_panel.promote_to_captain(new_life.mind, captain)
	TEST_ASSERT_EQUAL(old_ship.get_crew_record(), unchanged, "Captain transfer changed hull identity")
	admin_panel.kick_crew_member(new_life.mind, captain)
	TEST_ASSERT_NULL(new_life.mind.get_reputation_crew(), "Explicit kick retained affiliation")
	TEST_ASSERT_NULL(GLOB.voidcrew_crew_roster["zoneidentityrespawn"], "Explicit kick retained keyed recovery")

/// Respawn eviction must finish before the replacement's same-name manifest entry is written.
/datum/unit_test/voidcrew_zone_identity/same_name_respawn/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/mob/living/carbon/human/old_life = make_member("zoneidentitysamename")
	old_life.real_name = "Same Name"
	var/datum/job/assistant/old_job = allocate(/datum/job/assistant)
	ship.manifest_inject(old_life, old_job)
	TEST_ASSERT_EQUAL(ship.manifest[old_life.real_name], old_job, "Old life was not added to the manifest")
	var/mob/living/carbon/human/new_life = make_member("zoneidentitysamename")
	new_life.real_name = old_life.real_name
	var/datum/job/station_engineer/new_job = allocate(/datum/job/station_engineer)
	ship.manifest_inject(new_life, new_job)
	TEST_ASSERT(!(old_life.mind in ship.ship_team.members), "Same-hull respawn retained the old life")
	TEST_ASSERT_NULL(old_life.mind.get_reputation_crew(), "Same-hull respawn retained the old affiliation")
	TEST_ASSERT(new_life.mind in ship.ship_team.members, "Same-hull respawn did not enroll the replacement")
	TEST_ASSERT_EQUAL(length(ship.manifest), 1, "Same-name respawn did not retain exactly one manifest entry")
	TEST_ASSERT_EQUAL(ship.manifest[new_life.real_name], new_job, "Same-name respawn lost the replacement's manifest job")

/// Silicon spawn takes exactly the same join transaction as human spawning.
/datum/unit_test/voidcrew_zone_identity/silicon/Run()
	var/obj/structure/overmap/ship/old_ship = make_ship()
	var/obj/structure/overmap/ship/new_ship = make_ship()
	var/mob/living/silicon/robot/borg = allocate(/mob/living/silicon/robot, run_loc_floor_bottom_left)
	borg.mind_initialize()
	allocated += borg.mind
	old_ship.enlist_crewmember(borg)
	var/obj/docking_port/mobile/voidcrew/port = new(run_loc_floor_bottom_left)
	port.register()
	test_ports += port
	new_ship.shuttle = port
	port.current_ship = new_ship
	var/datum/job/cyborg/job = allocate(/datum/job/cyborg)
	job.ship_role = "cyborg"
	job.ship_borg_model = /obj/item/robot_model/engineering
	job.crew_ship_ref = WEAKREF(new_ship)
	borg.mind.set_assigned_role(job)
	job.finish_ship_silicon_spawn(borg, new_ship)
	TEST_ASSERT_EQUAL(borg.mind.get_reputation_crew(), new_ship.get_crew_record(), "Silicon spawn did not switch crews")
	TEST_ASSERT(!(borg.mind in old_ship.ship_team.members), "Silicon retained its former crew")
	new_ship.shuttle = null

/// Claims continue any crewmate's identity, and cannot overwrite occupied hulls.
/datum/unit_test/voidcrew_zone_identity/claims/Run()
	var/obj/structure/overmap/ship/home = make_ship()
	var/mob/living/carbon/human/member = make_member()
	home.enlist_crewmember(member)
	var/datum/voidcrew_crew_record/record = record_for(home)
	clear_green(record)
	var/obj/structure/overmap/ship/derelict = make_ship()
	derelict.abandoned = TRUE
	TEST_ASSERT(derelict.claim_abandoned_ship(member), "Abandoned claim failed")
	TEST_ASSERT_EQUAL(record_for(derelict), record, "Abandoned claim reset a non-captain's standing")
	var/obj/structure/overmap/ship/npc/pirate = allocate(/obj/structure/overmap/ship/npc)
	var/obj/machinery/computer/helm/helm = allocate(/obj/machinery/computer/helm)
	TEST_ASSERT(helm.claim_npc_ship(pirate, member), "NPC key-claim transaction failed")
	TEST_ASSERT_EQUAL(record_for(pirate), record, "NPC claim reset standing")
	TEST_ASSERT(member.mind in home.ship_team.members, "Claim stripped same-crew membership")
	TEST_ASSERT(!helm.claim_npc_ship(pirate, member, TRUE), "Occupied NPC hull could reset caps")
	var/obj/structure/overmap/ship/independent = make_ship()
	independent.abandoned = TRUE
	TEST_ASSERT(independent.claim_abandoned_ship(member, TRUE), "Independent claim failed")
	TEST_ASSERT(record_for(independent) != record, "Independent claim reused the former crew")
	TEST_ASSERT(!(member.mind in home.ship_team.members), "Independent claim left former memberships")

/// Ambiguous fleets need a hull selection; it never selects another crew or survives a switch.
/datum/unit_test/voidcrew_zone_identity/service_selection/Run()
	var/obj/structure/overmap/ship/first = make_ship()
	var/datum/voidcrew_crew_record/record = record_for(first)
	var/obj/structure/overmap/ship/second = make_ship(record)
	var/obj/structure/overmap/ship/foreign = make_ship()
	var/mob/living/carbon/human/member = make_member()
	first.enlist_crewmember(member)
	TEST_ASSERT_NULL(get_crew_ship(member), "Fleet roster order silently chose an account")
	TEST_ASSERT(member.mind.select_crew_service_ship(second), "Explicit same-crew hull selection failed")
	TEST_ASSERT_EQUAL(get_crew_ship(member), second, "Service ignored the selected hull")
	TEST_ASSERT(!member.mind.select_crew_service_ship(foreign), "Could select a foreign hull")
	TEST_ASSERT(record.claim_purchase(/datum/shop_sku/favor/pike_ledger), "First shared-cap reservation failed")
	TEST_ASSERT(second.get_crew_record().claim_purchase(/datum/shop_sku/favor/pike_ledger), "Second hull could not share the cap")
	TEST_ASSERT(record.claim_purchase(/datum/shop_sku/favor/pike_ledger), "Third shared-cap reservation failed")
	TEST_ASSERT(!second.get_crew_record().claim_purchase(/datum/shop_sku/favor/pike_ledger), "Concurrent hulls exceeded the shared cap")
	record.release_purchase(/datum/shop_sku/favor/pike_ledger)
	TEST_ASSERT(record.claim_purchase(/datum/shop_sku/favor/pike_ledger), "Failed-sale release did not restore its reservation")
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.embargo_ship(first)
	TEST_ASSERT(outpost.is_user_barred(member), "Selecting a second crew hull bypassed the embargo")
	foreign.enlist_crewmember(member)
	TEST_ASSERT_NULL(member.mind.crew_service_ship_ref, "Crew switch kept stale hull selection")
	TEST_ASSERT_EQUAL(get_crew_ship(member), foreign, "Service used a former crew after switching")
	TEST_ASSERT_EQUAL(metric_crew_ship(member), foreign, "Metrics used a former crew after switching")
	TEST_ASSERT(!outpost.is_user_barred(member), "An old crew's embargo followed a departing member")

/// A construction fixture executes real create_vessel()/enlist_captain() without placing a map.
/datum/checkpoint_construction/zone_identity_test
	var/datum/mind/test_command

/datum/checkpoint_construction/zone_identity_test/New()
	state = "complete"

/datum/checkpoint_construction/zone_identity_test/captain_mind()
	return test_command

/datum/checkpoint_construction/zone_identity_test/Destroy(force)
	test_command = null
	return ..()

/datum/checkpoint_construction/order/zone_identity_test/New()
	state = "complete"

/// A live checkpoint reference includes post-save gains; departed captains cannot recover it.
/datum/unit_test/voidcrew_zone_identity/checkpoints_and_orders/Run()
	var/mob/living/carbon/human/captain = make_member("zoneidentitycheckpoint")
	var/obj/structure/overmap/ship/original = make_ship()
	original.enlist_crewmember(captain)
	var/datum/voidcrew_crew_record/record = record_for(original)
	var/datum/ship_checkpoint/snapshot = allocate(/datum/ship_checkpoint)
	snapshot.crew_record_ref = WEAKREF(record)
	snapshot.captain_ckey = "zoneidentitycheckpoint"
	clear_green(record) // Earned after capture.
	var/datum/map_template/shuttle/voidcrew/commissioned/template = allocate(/datum/map_template/shuttle/voidcrew/commissioned)
	var/datum/checkpoint_construction/zone_identity_test/job = allocate(/datum/checkpoint_construction/zone_identity_test)
	job.template = template
	job.crew_record_ref = snapshot.crew_record_ref
	job.captain_ckey = snapshot.captain_ckey
	job.test_command = captain.mind
	job.vessel = job.create_vessel()
	allocated += job.vessel
	TEST_ASSERT_EQUAL(record_for(job.vessel), record, "Checkpoint copied or reset the live crew record")
	TEST_ASSERT(job.enlist_captain(captain.mind), "Checkpoint handover failed")
	TEST_ASSERT_EQUAL(job.vessel.get_crew_record().get_zone_permission(), 1, "Checkpoint lost post-save gains")
	var/datum/checkpoint_construction/order/zone_identity_test/order = allocate(/datum/checkpoint_construction/order/zone_identity_test)
	order.order = allocate(/datum/ship_order, template)
	order.template = template
	order.buyer_mind_ref = WEAKREF(captain.mind)
	order.vessel = order.create_vessel()
	allocated += order.vessel
	TEST_ASSERT_EQUAL(record_for(order.vessel), record, "Simultaneous order commissioned a copied crew")
	TEST_ASSERT(order.enlist_captain(captain.mind), "Outpost order handover failed")
	TEST_ASSERT_EQUAL(order.vessel.claimed_captain, captain.mind, "Outpost order did not give its buyer command")
	TEST_ASSERT(captain.mind in order.vessel.ship_team.members, "Outpost order did not enroll its buyer")
	var/datum/checkpoint_construction/order/zone_identity_test/independent = allocate(/datum/checkpoint_construction/order/zone_identity_test)
	independent.order = order.order
	independent.template = template
	independent.buyer_mind_ref = WEAKREF(captain.mind)
	independent.form_new_crew = TRUE
	independent.vessel = independent.create_vessel()
	allocated += independent.vessel
	var/datum/voidcrew_crew_record/new_crew = record_for(independent.vessel)
	TEST_ASSERT(new_crew != record, "Independent shipyard order continued the buyer's former crew")
	TEST_ASSERT_EQUAL(new_crew.get_zone_permission(), 0, "Independent shipyard order inherited standing")
	TEST_ASSERT_EQUAL(captain.mind.get_reputation_crew(), new_crew, "Independent shipyard order did not bind its buyer")
	TEST_ASSERT(independent.enlist_captain(captain.mind), "Independent shipyard order handover failed")
	TEST_ASSERT_EQUAL(independent.vessel.claimed_captain, captain.mind, "Independent shipyard order did not give its buyer command")
	TEST_ASSERT(captain.mind in independent.vessel.ship_team.members, "Independent shipyard order did not enroll its buyer")
	var/obj/structure/overmap/ship/other = make_ship()
	other.enlist_crewmember(captain)
	var/datum/voidcrew_crew_record/current = record_for(other)
	var/obj/structure/overmap/ship/later = job.create_vessel()
	allocated += later
	TEST_ASSERT_EQUAL(record_for(later), current, "Old checkpoint reclaimed a former crew's standing")
	TEST_ASSERT_EQUAL(later.get_crew_record().get_zone_permission(), 0, "Old checkpoint transferred reputation")
	// The shared template belongs to this fixture, not the construction job teardown.
	job.template = null
	order.template = null
	independent.template = null

/// Deleting an unclaimed NPC hull must discard its unused provisional identity.
/datum/unit_test/voidcrew_zone_identity/npc_cleanup/Run()
	var/registry_size = length(GLOB.voidcrew_crew_records)
	var/datum/map_template/shuttle/voidcrew/commissioned/template = allocate(/datum/map_template/shuttle/voidcrew/commissioned)
	var/obj/structure/overmap/ship/npc/ship = allocate(/obj/structure/overmap/ship/npc)
	TEST_ASSERT(ship.setup_from_template(template), "NPC identity fixture could not set up its hull")
	var/datum/voidcrew_crew_record/record = record_for(ship)
	TEST_ASSERT_EQUAL(length(GLOB.voidcrew_crew_records), registry_size + 1, "NPC hull did not create one provisional record")
	qdel(ship)
	TEST_ASSERT(QDELETED(record), "Deleted NPC hull retained its provisional record")
	TEST_ASSERT_EQUAL(length(GLOB.voidcrew_crew_records), registry_size, "Deleting an NPC hull grew the crew registry")

/// Registry/admin disposal drops hull, mind and ckey references without deleting the hulls.
/datum/unit_test/voidcrew_zone_identity/cleanup/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/mob/living/carbon/human/member = make_member("zoneidentitycleanup")
	ship.enlist_crewmember(member)
	var/datum/voidcrew_crew_record/record = record_for(ship)
	qdel(record)
	TEST_ASSERT(!(record in GLOB.voidcrew_crew_records), "Disposed record remains registered")
	TEST_ASSERT_NULL(GLOB.voidcrew_crew_roster["zoneidentitycleanup"], "Disposed record remains rostered")
	TEST_ASSERT_NULL(member.mind.reputation_crew, "Disposed record retained a mind backlink")
	TEST_ASSERT_NULL(ship.ship_team.crew_record, "Disposed record retained a hull backlink")
	TEST_ASSERT_EQUAL(length(ship.ship_team.members), 0, "Disposed record retained a HUD roster")
	TEST_ASSERT(!QDELETED(ship), "Disposing a record deleted its hull")

/// The real survey/commissioning route must bind the surveyor before enlisting occupants.
/datum/unit_test/voidcrew_zone_identity_scratch
	parent_type = /datum/unit_test/voidcrew_hull_survey
	var/obj/structure/overmap/ship/commissioned
	var/list/crew_records = list()

/datum/unit_test/voidcrew_zone_identity_scratch/Destroy()
	qdel(commissioned)
	QDEL_LIST(crew_records)
	return ..()

/datum/unit_test/voidcrew_zone_identity_scratch/Run()
	TEST_ASSERT(reserved, "Scratch commissioning could not reserve a fixture")
	reset_block()
	build_walled_room()
	var/turf/door_turf = spot(4, 2)
	door_turf.ChangeTurf(/turf/open/floor/plating, /turf/open/space)
	new /obj/machinery/door/airlock(door_turf)
	settle()
	var/datum/hull_claim/claim = survey_enclosure(spot(4, 4))
	TEST_ASSERT_NULL(validate_hull_claim(claim, null), "Scratch fixture is not a valid enclosure")
	var/mob/living/carbon/human/consistent/surveyor = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	var/mob/living/carbon/human/consistent/occupant = allocate(/mob/living/carbon/human/consistent, spot(4, 5))
	surveyor.mind_initialize()
	occupant.mind_initialize()
	allocated += surveyor.mind
	allocated += occupant.mind
	occupant.mock_client = allocate(/datum/client_interface)
	var/obj/structure/overmap/ship/original = allocate(/obj/structure/overmap/ship)
	original.ship_team = new
	original.ship_team.ship = original
	original.enlist_crewmember(surveyor)
	var/datum/voidcrew_crew_record/record = original.get_crew_record()
	crew_records += record
	record.claim_zone_work("hunt", 1, 1, "before_build")
	var/obj/structure/overmap/ship/occupant_home = allocate(/obj/structure/overmap/ship)
	occupant_home.ship_team = new
	occupant_home.ship_team.ship = occupant_home
	occupant_home.enlist_crewmember(occupant)
	crew_records += occupant_home.get_crew_record()
	commissioned = commission_vessel(surveyor, spot(4, 4), claim.turfs, "Identity fixture")
	TEST_ASSERT_NOTNULL(commissioned, "Scratch commissioning failed")
	TEST_ASSERT_EQUAL(commissioned.get_crew_record(), record, "First occupant replaced the surveyor's crew identity")
	TEST_ASSERT(surveyor.mind in original.ship_team.members, "Commissioning removed the surveyor from their own crew")
	TEST_ASSERT(occupant.mind in commissioned.ship_team.members, "Commissioning did not enroll its occupant")
	TEST_ASSERT(!(occupant.mind in occupant_home.ship_team.members), "Commissioning left its occupant in a second crew")
	TEST_ASSERT_EQUAL(occupant.mind.get_reputation_crew(), record, "Occupant did not join the surveyor's crew")
	TEST_ASSERT_EQUAL(record.zone_totals["1"], 1, "Commissioning changed standing")

/datum/mission_target/zone_identity_test
	var/band = 1
	var/valid = TRUE

/datum/mission_target/zone_identity_test/get_zone_type()
	return band

/datum/mission_target/zone_identity_test/is_valid()
	return valid

/datum/mission/zone_identity_test
	var/starts = 0

/datum/mission/zone_identity_test/New()
	return // Admission fixture: no generated targets or rewards.

/datum/mission/zone_identity_test/start_mission(obj/structure/overmap/ship/ship)
	starts++
	return TRUE

/// ship.accept_mission is the common enforcement point for console and trader callers.
/datum/unit_test/voidcrew_zone_identity/admission/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/record = record_for(ship)
	var/datum/mission/zone_identity_test/mission = allocate(/datum/mission/zone_identity_test)
	var/datum/mission_target/zone_identity_test/target = allocate(/datum/mission_target/zone_identity_test, mission)
	mission.target = target
	ship.available_missions += mission
	for(var/band in list(2, 3))
		target.band = band
		mission.quote_zone = band
		TEST_ASSERT(ship.accept_mission(mission) != TRUE, "Public crew bypassed band [band] through accept_mission")
	TEST_ASSERT_EQUAL(mission.starts, 0, "Denied work reached start_mission")
	target.band = 1
	mission.quote_zone = 2
	TEST_ASSERT(ship.accept_mission(mission) != TRUE, "Mismatched target/quote was admitted")
	mission.quote_zone = 1
	TEST_ASSERT_EQUAL(ship.accept_mission(mission), TRUE, "Public green work was denied")
	clear_green(record)
	target.band = 2
	mission.quote_zone = 2
	TEST_ASSERT_EQUAL(ship.accept_mission(mission), TRUE, "Newly permitted yellow work stayed denied")
	target.band = 3
	mission.quote_zone = 3
	TEST_ASSERT(ship.accept_mission(mission) != TRUE, "Yellow crew accepted red work")
	record.claim_zone_work("hunt", 2, 3, "yellow_hunt")
	record.claim_zone_work("capture", 2, 3, "yellow_capture")
	TEST_ASSERT_EQUAL(ship.accept_mission(mission), TRUE, "Newly permitted red work stayed denied")
	target.band = 99
	mission.quote_zone = 99
	TEST_ASSERT(ship.accept_mission(mission) != TRUE, "Unknown work band was admitted")
	target.band = 1
	mission.quote_zone = 1
	target.valid = FALSE
	TEST_ASSERT(ship.accept_mission(mission) != TRUE, "Lost target was admitted before resolution")
	var/obj/structure/overmap/ship/public_ship = make_ship()
	mission.target = null
	mission.quote_zone = 3 // Targetless asks stay Public regardless of posting band.
	public_ship.available_missions += mission
	TEST_ASSERT_EQUAL(public_ship.accept_mission(mission), TRUE, "Targetless routine ask was gated by posting band")
