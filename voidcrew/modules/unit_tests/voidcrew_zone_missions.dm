#ifndef VOIDCREW_ZONE_MISSIONS_TESTS
#define VOIDCREW_ZONE_MISSIONS_TESTS

// Fork defines are included later than the test harness. Bands and permissions use literals.
/datum/mission_target/zone_missions_test
	var/band = 1
	var/valid = TRUE
	var/resolve_calls = 0

/datum/mission_target/zone_missions_test/get_zone_type()
	return band

/datum/mission_target/zone_missions_test/is_valid()
	return valid

/datum/mission_target/zone_missions_test/resolve()
	resolve_calls++
	return valid

/datum/mission_objective/zone_missions_test
	completed = TRUE
	var/claim_seen = FALSE
	var/reentrant_result

/datum/mission_objective/zone_missions_test/on_turn_in_finalized(atom/reward_anchor)
	claim_seen = mission.work_receipt?.claimed
	reentrant_result = mission.turn_in(reward_anchor, null, TRUE)

/datum/mission/proc/zone_missions_fixture()
	var/datum/mission_target/zone_missions_test/site = new(src)
	site.band = preferred_zone || 1
	target = site
	quote_zone = site.band
	difficulty = quote_zone
	value = 100
	requires_item = FALSE
	add_objective(new /datum/mission_objective/zone_missions_test())
	prepare_work_receipt()

/datum/mission/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/zone_missions_test/update_text()

/datum/mission/zone_missions_test/routine/generate_mission_details()
	value = 100
	add_objective(new /datum/mission_objective/zone_missions_test())

/datum/mission/recovery/kill/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/kill/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/kill/zone_missions_test/update_text()

/datum/mission/recovery/kill/zone_missions_test/on_mission_started()

/datum/mission/recovery/kill/outpost/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/kill/outpost/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/kill/outpost/zone_missions_test/update_text()

/datum/mission/recovery/kill/outpost/zone_missions_test/on_mission_started()

/datum/mission/big_game_hunt/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/big_game_hunt/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/big_game_hunt/zone_missions_test/update_text()

/datum/mission/big_game_hunt/zone_missions_test/on_mission_started()

/datum/mission/big_game_hunt/zone_missions_test/capped
	mission_limit = 1

/datum/mission/live_capture/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/live_capture/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/live_capture/zone_missions_test/update_text()

/datum/mission/live_capture/zone_missions_test/on_mission_started()

/datum/mission/live_capture/zone_missions_test/capped
	mission_limit = 1

/datum/mission/poacher_bust/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/poacher_bust/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/poacher_bust/zone_missions_test/update_text()

/datum/mission/poacher_bust/zone_missions_test/on_mission_started()

/datum/mission/poacher_bust/zone_missions_test/capped
	mission_limit = 1

/datum/mission/recovery/survey/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/survey/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/survey/zone_missions_test/update_text()

/datum/mission/recovery/survey/zone_missions_test/on_mission_started()

/datum/mission/research/core_sample/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/research/core_sample/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/research/core_sample/zone_missions_test/update_text()

/datum/mission/research/core_sample/zone_missions_test/on_mission_started()

/datum/mission/recovery/extraction/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/extraction/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/extraction/zone_missions_test/update_text()

/datum/mission/recovery/extraction/zone_missions_test/on_mission_started()

/datum/mission/prospect_stake/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/prospect_stake/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/prospect_stake/zone_missions_test/update_text()

/datum/mission/prospect_stake/zone_missions_test/on_mission_started()

/datum/mission/suppression/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/suppression/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/suppression/zone_missions_test/update_text()

/datum/mission/suppression/zone_missions_test/on_mission_started()

/datum/mission/recovery/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/recovery/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/recovery/zone_missions_test/update_text()

/datum/mission/recovery/zone_missions_test/on_mission_started()

/datum/mission/rescue/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/rescue/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/rescue/zone_missions_test/update_text()

/datum/mission/rescue/zone_missions_test/on_mission_started()

/datum/mission/outpost_courier/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/outpost_courier/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/outpost_courier/zone_missions_test/update_text()

/datum/mission/outpost_courier/zone_missions_test/on_mission_started()

/datum/mission/outpost_courier/zone_missions_test/can_turn_in_at(atom/reward_anchor)
	return TRUE

/datum/mission/survey/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/survey/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/survey/zone_missions_test/update_text()

/datum/mission/survey/zone_missions_test/on_mission_started()

/datum/mission/research/telemetry/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/research/telemetry/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/research/telemetry/zone_missions_test/update_text()

/datum/mission/research/telemetry/zone_missions_test/on_mission_started()

/datum/mission/gas_harvest/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/gas_harvest/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/gas_harvest/zone_missions_test/update_text()

/datum/mission/gas_harvest/zone_missions_test/on_mission_started()

/datum/mission/outpost_supply/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/outpost_supply/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/outpost_supply/zone_missions_test/update_text()

/datum/mission/outpost_supply/zone_missions_test/on_mission_started()

/datum/mission/outpost_supply/cook/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/outpost_supply/cook/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/outpost_supply/cook/zone_missions_test/update_text()

/datum/mission/outpost_supply/cook/zone_missions_test/on_mission_started()

/datum/mission/outpost_supply/angler/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/outpost_supply/angler/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/outpost_supply/angler/zone_missions_test/update_text()

/datum/mission/outpost_supply/angler/zone_missions_test/on_mission_started()

/datum/mission/delivery/zone_missions_test
	weight = 0
	mission_limit = 0

/datum/mission/delivery/zone_missions_test/generate_mission_details()
	zone_missions_fixture()

/datum/mission/delivery/zone_missions_test/update_text()

/datum/mission/delivery/zone_missions_test/on_mission_started()

/obj/structure/overmap/ship/zone_missions_test/roll_mission_prize(zone)
	return null

/datum/controller/subsystem/missions/zone_missions_test
	flags = SS_NO_INIT | SS_NO_FIRE
	var/fail_work = FALSE
	var/work_attempts = 0

/datum/controller/subsystem/missions/zone_missions_test/New()
	// The MC constructs every subtype. Skip singleton registration and parent PreInit.
	return

/datum/controller/subsystem/missions/zone_missions_test/create_mission(mission_type, preferred_zone, posting_zone, list/eligible_zones, create_field_contact = FALSE)
	if(!ispath(mission_type, /datum/mission/zone_missions_test/routine))
		work_attempts++
		if(fail_work)
			return null
	return ..()

/// Fixture weights are zero, so the reserved slots pick evenly from what is not held.
/datum/controller/subsystem/missions/zone_missions_test/get_weighted_mission_type()
	var/list/open_types = list()
	for(var/mission_type in mission_types)
		if(mission_type_within_limit(mission_type))
			open_types += mission_type
	return length(open_types) ? pick(open_types) : null

/datum/controller/subsystem/missions/zone_missions_test/generate_random_mission(preferred_zone, posting_zone, list/eligible_zones)
	return create_mission(/datum/mission/zone_missions_test/routine, preferred_zone, posting_zone, eligible_zones)

/datum/controller/subsystem/missions/zone_missions_test/ensure_safe_exploration_offer(obj/structure/overmap/ship/ship)
	ship.available_missions += new /datum/mission/zone_missions_test(null, 1)
	return TRUE

/datum/controller/subsystem/overmap/zone_missions_test
	flags = SS_NO_INIT | SS_NO_FIRE
	var/capacity = FALSE
	var/any_band_calls = 0
	var/turf/destination

/datum/controller/subsystem/overmap/zone_missions_test/New()
	// The MC constructs every subtype. Skip singleton registration and parent PreInit.
	return

/datum/controller/subsystem/overmap/zone_missions_test/mission_contact_capacity(tenant_class)
	return capacity

/datum/controller/subsystem/overmap/zone_missions_test/get_unused_overmap_square_in_zone_band(band, thing_not_to_have = /obj/structure/overmap, tries = 40)
	return destination

/datum/controller/subsystem/overmap/zone_missions_test/get_unused_overmap_square(thing_not_to_have = /obj/structure/overmap, tries = 40, force = FALSE)
	any_band_calls++
	return null

/datum/unit_test/voidcrew_zone_missions
	abstract_type = /datum/unit_test/voidcrew_zone_missions
	var/list/records = list()
	var/list/old_types
	var/old_metrics
	var/list/old_tallies

/datum/unit_test/voidcrew_zone_missions/New()
	. = ..()
	old_types = SSmissions.mission_types
	old_metrics = SSmetrics.accepting
	old_tallies = SSmetrics.tallies
	SSmetrics.accepting = FALSE
	SSmetrics.tallies = list()

/datum/unit_test/voidcrew_zone_missions/Destroy()
	SSmissions.mission_types = old_types
	SSmetrics.accepting = old_metrics
	SSmetrics.tallies = old_tallies
	QDEL_LIST(records)
	return ..()

/datum/unit_test/voidcrew_zone_missions/proc/make_ship(permission = 0, crewed = TRUE)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship/zone_missions_test)
	ship.ship_team = new
	ship.ship_team.ship = ship
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	records += record
	ship.ship_account = allocate(/datum/bank_account)
	if(crewed)
		var/mob/living/carbon/human/member = allocate(/mob/living/carbon/human/consistent)
		member.mind_initialize()
		allocated += member.mind
		ship.enlist_crewmember(member)
	var/list/steps = list(0, 4, 11, 22) // Public, then REPUTATION_STEP_*
	record.reputation = steps[permission + 1]
	return ship

/// Boot and manually allocated fixtures leave the real subsystems and dependency graph intact.
/datum/unit_test/voidcrew_zone_missions/subsystem_isolation/Run()
	var/datum/controller/subsystem/missions/real_missions = SSmissions
	var/datum/controller/subsystem/overmap/real_overmap = SSovermap
	TEST_ASSERT_EQUAL(real_missions.type, /datum/controller/subsystem/missions, "The missions global is a test fixture")
	TEST_ASSERT_EQUAL(real_overmap.type, /datum/controller/subsystem/overmap, "The overmap global is a test fixture")
	var/list/type_to_subsystem = list()
	for(var/datum/controller/subsystem/subsystem as anything in Master.subsystems)
		type_to_subsystem[subsystem.type] = subsystem
	TEST_ASSERT_EQUAL(type_to_subsystem[/datum/controller/subsystem/missions], real_missions, "The MC lost the exact missions type")
	TEST_ASSERT_EQUAL(type_to_subsystem[/datum/controller/subsystem/overmap], real_overmap, "The MC lost the exact overmap type")
	for(var/fixture_type in list(/datum/controller/subsystem/missions/zone_missions_test, /datum/controller/subsystem/overmap/zone_missions_test))
		var/datum/controller/subsystem/boot_fixture = type_to_subsystem[fixture_type]
		TEST_ASSERT_NOTNULL(boot_fixture, "The MC did not construct [fixture_type]")
		TEST_ASSERT_EQUAL(boot_fixture.flags & (SS_NO_INIT | SS_NO_FIRE), SS_NO_INIT | SS_NO_FIRE, "A boot fixture can initialize or fire")
		TEST_ASSERT_EQUAL(boot_fixture.times_fired, 0, "The MC fired a test fixture")
		for(var/dependency_type in boot_fixture.dependencies)
			var/datum/controller/subsystem/dependency = type_to_subsystem[dependency_type]
			TEST_ASSERT_NOTNULL(dependency, "A fixture's inherited dependency [dependency_type] does not resolve")
			TEST_ASSERT(!QDELETED(dependency), "A fixture's inherited dependency was deleted")
			TEST_ASSERT(boot_fixture.init_stage >= dependency.init_stage, "A fixture precedes an inherited dependency's init stage")
		var/datum/controller/subsystem/fixture = allocate(fixture_type)
		TEST_ASSERT_EQUAL(SSmissions, real_missions, "Constructing a fixture replaced SSmissions")
		TEST_ASSERT_EQUAL(SSovermap, real_overmap, "Constructing a fixture replaced SSovermap")
		TEST_ASSERT(!QDELETED(real_missions) && !QDELETED(real_overmap), "Constructing a fixture deleted a real subsystem")
		TEST_ASSERT(real_missions in Master.subsystems, "Constructing a fixture removed missions from the MC")
		TEST_ASSERT(real_overmap in Master.subsystems, "Constructing a fixture removed overmap from the MC")
		TEST_ASSERT_EQUAL(fixture.flags & (SS_NO_INIT | SS_NO_FIRE), SS_NO_INIT | SS_NO_FIRE, "An allocated fixture can initialize or fire")
		Master.init_subsystem(fixture)
		TEST_ASSERT(fixture.initialized, "The MC did not mark the inert fixture ready")
		qdel(fixture)
		TEST_ASSERT_EQUAL(SSmissions, real_missions, "Deleting a fixture changed SSmissions")
		TEST_ASSERT_EQUAL(SSovermap, real_overmap, "Deleting a fixture changed SSovermap")
	var/datum/controller/subsystem/missions/zone_missions_test/boot_missions = type_to_subsystem[/datum/controller/subsystem/missions/zone_missions_test]
	var/datum/controller/subsystem/overmap/zone_missions_test/boot_overmap = type_to_subsystem[/datum/controller/subsystem/overmap/zone_missions_test]
	TEST_ASSERT_EQUAL(length(boot_missions.mission_types), 0, "The MC initialized the missions fixture")
	TEST_ASSERT_NULL(boot_overmap.overmap_centre, "The MC initialized a second overmap")

/// Every kind of job, console and board, settles through the real shell, with claims before finalizers.
/// Safe work pays one whatever its zone or difficulty; everything else pays by difficulty.
/datum/unit_test/voidcrew_zone_missions/every_job/Run()
	var/list/types = list(
		/datum/mission/recovery/kill/zone_missions_test = FALSE,
		/datum/mission/recovery/kill/outpost/zone_missions_test = FALSE,
		/datum/mission/big_game_hunt/zone_missions_test = FALSE,
		/datum/mission/live_capture/zone_missions_test = FALSE,
		/datum/mission/poacher_bust/zone_missions_test = FALSE,
		/datum/mission/recovery/survey/zone_missions_test = FALSE,
		/datum/mission/research/core_sample/zone_missions_test = FALSE,
		/datum/mission/recovery/extraction/zone_missions_test = FALSE,
		/datum/mission/prospect_stake/zone_missions_test = FALSE,
		/datum/mission/suppression/zone_missions_test = FALSE,
		/datum/mission/recovery/zone_missions_test = FALSE,
		/datum/mission/rescue/zone_missions_test = FALSE,
		/datum/mission/outpost_courier/zone_missions_test = TRUE,
		/datum/mission/survey/zone_missions_test = TRUE,
		/datum/mission/research/telemetry/zone_missions_test = TRUE,
		/datum/mission/gas_harvest/zone_missions_test = TRUE,
		/datum/mission/outpost_supply/zone_missions_test = TRUE,
		/datum/mission/outpost_supply/cook/zone_missions_test = TRUE,
		/datum/mission/outpost_supply/angler/zone_missions_test = TRUE,
		/datum/mission/delivery/zone_missions_test = TRUE,
	)
	for(var/mission_type in types)
		var/expected_safe = types[mission_type]
		for(var/band in 1 to 3)
			var/obj/structure/overmap/ship/ship = make_ship(band - 1)
			var/datum/voidcrew_crew_record/record = ship.get_crew_record()
			var/before = record.reputation
			var/expected_gain = expected_safe ? 1 : band
			var/datum/mission/mission = allocate(mission_type, null, band)
			var/datum/mission_work_receipt/receipt = mission.work_receipt
			var/datum/mission_objective/zone_missions_test/finalizer = mission.objectives[1]
			ship.available_missions += mission
			TEST_ASSERT_EQUAL(receipt.band, band, "[mission_type] counted in the wrong zone")
			TEST_ASSERT_EQUAL(mission.difficulty, band, "The safe flag changed [mission_type]'s difficulty")
			TEST_ASSERT_EQUAL(mission.get_reputation_worth(record), expected_gain, "[mission_type] showed the wrong worth")
			TEST_ASSERT_EQUAL(ship.accept_mission(mission), TRUE, "Eligible work was denied")
			TEST_ASSERT_EQUAL(receipt.crew, record, "Acceptance did not bind the crew")
			TEST_ASSERT_EQUAL(mission.get_reputation_worth(mission.accepting_crew), expected_gain, "The accepted job lost its worth")
			TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, null), "Successful work did not settle")
			TEST_ASSERT_EQUAL(record.reputation, before + expected_gain, "[mission_type] paid the wrong reputation")
			TEST_ASSERT(finalizer.claim_seen, "A finalizer ran before the claim")
			TEST_ASSERT(!finalizer.reentrant_result, "A finalizer settled the mission twice")
			TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, null, TRUE), "Stale completion settled again")
			TEST_ASSERT_EQUAL(record.reputation, before + expected_gain, "A stale completion paid twice")

/// Which jobs are safe work, checked against the live types so a new job has to pick a side.
/datum/unit_test/voidcrew_zone_missions/safe_work/Run()
	var/list/safe_types = list(
		/datum/mission/outpost_supply,
		/datum/mission/outpost_supply/angler,
		/datum/mission/outpost_supply/cook,
		/datum/mission/outpost_courier,
		/datum/mission/delivery,
		/datum/mission/gas_harvest,
		/datum/mission/research/telemetry,
		/datum/mission/survey,
		/datum/mission/exploration,
	)
	for(var/datum/mission/mission_type as anything in subtypesof(/datum/mission))
		var/is_safe = FALSE
		for(var/safe_type in safe_types)
			if(ispath(mission_type, safe_type))
				is_safe = TRUE
				break
		TEST_ASSERT_EQUAL(initial(mission_type.safe_work), is_safe, "[mission_type] is on the wrong side of the safe work line")
	// A hard ask in red still pays one, and keeps its own difficulty for its pay.
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	var/datum/mission/routine = allocate(/datum/mission/zone_missions_test/routine, null, null, 3)
	routine.safe_work = TRUE
	routine.difficulty = 3
	TEST_ASSERT(routine.start_mission(ship), "Safe work could not start")
	TEST_ASSERT_EQUAL(routine.work_receipt.difficulty, 1, "Safe work's receipt did not pay as easy")
	TEST_ASSERT_EQUAL(routine.difficulty, 3, "The receipt changed the job's own difficulty")
	TEST_ASSERT(routine.turn_in(run_loc_floor_bottom_left, null), "Safe work did not settle")
	TEST_ASSERT_EQUAL(record.reputation, 1, "A hard safe job in red did not pay one")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 100, "The safe flag changed the job's pay")
	// The ceilings still apply to it.
	record.reputation = 4
	var/datum/mission/capped = allocate(/datum/mission/zone_missions_test/routine, null, null, 1)
	capped.safe_work = TRUE
	capped.prepare_work_receipt()
	TEST_ASSERT_EQUAL(capped.get_reputation_worth(record), 0, "Safe work in green passed the green ceiling")

/// Targetless work is open to anyone and counts where it was posted, green if that is unknown.
/datum/unit_test/voidcrew_zone_missions/targetless/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	var/datum/mission/posted = allocate(/datum/mission/zone_missions_test/routine, null, null, 3)
	posted.difficulty = 3
	TEST_ASSERT_EQUAL(posted.get_work_band(), 3, "A posting zone was not used")
	TEST_ASSERT(posted.start_mission(ship), "A targetless job was gated by its posting zone")
	TEST_ASSERT(posted.turn_in(run_loc_floor_bottom_left, null), "Targetless work did not pay")
	TEST_ASSERT_EQUAL(record.reputation, 3, "Hard targetless work did not pay three")
	record.reputation = 19
	var/datum/mission/deep = allocate(/datum/mission/zone_missions_test/routine, null, null, 3)
	deep.difficulty = 3
	TEST_ASSERT(deep.start_mission(ship), "Repeat work was refused")
	TEST_ASSERT(deep.turn_in(run_loc_floor_bottom_left, null), "Repeat work did not settle")
	TEST_ASSERT_EQUAL(record.reputation, 22, "Red work met a ceiling")
	var/datum/mission/unknown = allocate(/datum/mission/zone_missions_test/routine)
	TEST_ASSERT_EQUAL(unknown.get_work_band(), 1, "A job with no known zone did not fall back to green")
	unknown.difficulty = 3
	TEST_ASSERT_EQUAL(unknown.get_reputation_worth(record), 0, "An unprepared job claimed a worth")
	unknown.prepare_work_receipt()
	TEST_ASSERT_EQUAL(unknown.get_reputation_worth(record), 0, "Green work paid past its ceiling")
	TEST_ASSERT(unknown.start_mission(ship), "Worthless work could not be accepted")
	var/before = record.reputation
	TEST_ASSERT(unknown.turn_in(run_loc_floor_bottom_left, null), "Worthless work stopped paying its ordinary reward")
	TEST_ASSERT_EQUAL(record.reputation, before, "Green work passed its ceiling")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 300, "Reputation changed the ordinary pay")

/// A failed job, an expired job and an abandoned offer pay nothing.
/datum/unit_test/voidcrew_zone_missions/unfinished_work/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	var/datum/mission/failed_job = allocate(/datum/mission/zone_missions_test)
	TEST_ASSERT(failed_job.start_mission(ship), "The failed fixture could not start")
	failed_job.fail("Cancelled.")
	var/datum/mission/expired_job = allocate(/datum/mission/zone_missions_test)
	TEST_ASSERT(expired_job.start_mission(ship), "The expired fixture could not start")
	expired_job.on_timeout()
	var/datum/mission/ignored = allocate(/datum/mission/zone_missions_test)
	qdel(ignored)
	TEST_ASSERT_EQUAL(record.reputation, 0, "Unfinished work earned reputation")
	TEST_ASSERT_EQUAL(length(record.settlement_claims), 0, "Unfinished work claimed a receipt")

/// Aliases, capped claims and crew changes retain one encounter's original recipient.
/datum/unit_test/voidcrew_zone_missions/receipts/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/obj/structure/overmap/ship/other = make_ship()
	var/datum/voidcrew_crew_record/original = ship.get_crew_record()
	var/datum/voidcrew_crew_record/different = other.get_crew_record()
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	var/datum/mission/first = allocate(/datum/mission/recovery/kill/zone_missions_test, shop)
	var/datum/mission/alias = allocate(/datum/mission/recovery/kill/outpost/zone_missions_test)
	var/datum/mission_work_receipt/receipt = first.work_receipt
	alias.work_receipt = receipt
	TEST_ASSERT(first.start_mission(ship), "Original receipt did not bind")
	TEST_ASSERT(!alias.start_mission(other), "An alias redirected the receipt to another crew")
	TEST_ASSERT(alias.start_mission(ship), "Same-crew alias could not bind")
	ship.ship_team.set_crew_record(different)
	TEST_ASSERT(first.turn_in(run_loc_floor_bottom_left, null), "Crew change prevented the original settlement")
	TEST_ASSERT_EQUAL(original.reputation, 1, "Original crew did not receive its work")
	TEST_ASSERT_EQUAL(different.reputation, 0, "Current hull affiliation stole an accepted receipt")
	TEST_ASSERT(alias.turn_in(run_loc_floor_bottom_left, null), "Alias lost its ordinary reward")
	TEST_ASSERT_EQUAL(original.reputation, 1, "Alias credited the encounter twice")
	var/datum/mission/next = allocate(/datum/mission/recovery/kill/zone_missions_test)
	TEST_ASSERT(next.work_receipt.serial != receipt.serial, "New encounter reused an old serial")
	ship.ship_team.set_crew_record(original)
	TEST_ASSERT(next.start_mission(ship), "A repeat of the same job was refused")
	TEST_ASSERT(next.turn_in(run_loc_floor_bottom_left, null), "The repeat did not settle")
	TEST_ASSERT_EQUAL(original.reputation, 2, "Repeating the same job stopped paying")
	original.reputation = 4
	var/datum/mission/capped = allocate(/datum/mission/recovery/kill/zone_missions_test)
	var/datum/mission_work_receipt/capped_receipt = capped.work_receipt
	TEST_ASSERT_EQUAL(capped.get_reputation_worth(original), 0, "A job at its zone's ceiling showed a worth")
	var/list/card = capped.get_ui_data(original)
	TEST_ASSERT_EQUAL(card["reputation_gain"], 0, "A job at its zone's ceiling showed a worth on its card")
	TEST_ASSERT(capped.start_mission(ship), "Work at the ceiling was refused")
	TEST_ASSERT(capped.turn_in(run_loc_floor_bottom_left, null), "Work at the ceiling did not settle")
	TEST_ASSERT(capped_receipt.claimed && original.settlement_claims["[capped_receipt.serial]"], "Work at the ceiling was not claimed")
	TEST_ASSERT_EQUAL(original.reputation, 4, "Green work passed its ceiling")

/// Retargeting cannot change the work band or mint a new objective receipt.
/datum/unit_test/voidcrew_zone_missions/retarget/Run()
	var/obj/structure/overmap/ship/ship = make_ship()
	var/datum/mission/mission = allocate(/datum/mission/recovery/kill/zone_missions_test)
	var/datum/mission_target/zone_missions_test/target = mission.target
	var/datum/mission_work_receipt/receipt = mission.work_receipt
	target.band = 99
	TEST_ASSERT(!mission.can_accept_work(ship), "Unknown band passed admission")
	target.band = 2
	TEST_ASSERT(!mission.resolve_quoted_target(), "Retarget escaped its pinned band")
	TEST_ASSERT(!mission.start_mission(ship), "Mismatched quote was accepted")
	target.band = 1
	TEST_ASSERT(mission.start_mission(ship), "Original band was refused")
	mission.named_kill_completed = TRUE
	mission.boss_cash_issued = TRUE
	mission.retarget()
	TEST_ASSERT_EQUAL(mission.work_receipt, receipt, "Retarget replaced the encounter receipt")
	TEST_ASSERT(mission.named_kill_completed && mission.boss_cash_issued, "Retarget reset S06 lifetime flags")
	TEST_ASSERT(!mission.create_field_contact, "Active work retained permission to mint contacts")
	target.band = 2
	TEST_ASSERT(!mission.turn_in(run_loc_floor_bottom_left, null), "Moving work laundered its band")

/// Viewer projections never consume the shared offer or mutate another crew's package.
/datum/unit_test/voidcrew_zone_missions/shared_offers/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	var/obj/structure/overmap/ship/public_ship = make_ship()
	var/obj/structure/overmap/ship/advanced_ship = make_ship(2)
	var/datum/mission/offer = allocate(/datum/mission/zone_missions_test, outpost.shop, 3)
	outpost.shop_offers += offer
	// A new outpost posts its own open jobs, so these look for this one.
	TEST_ASSERT(!(offer in outpost.get_contract_offers_for(public_ship)), "Public crew saw denied work")
	TEST_ASSERT(offer in outpost.get_contract_offers_for(advanced_ship), "Eligible crew lost the shared offer")
	TEST_ASSERT(offer in outpost.shop_offers, "Filtering deleted a shared offer")
	public_ship.available_missions += offer
	TEST_ASSERT(public_ship.accept_mission(offer) != TRUE, "Stale action bypassed authoritative admission")
	public_ship.available_missions -= offer
	TEST_ASSERT(offer in outpost.shop_offers, "Denied acceptance consumed the shared offer")

/datum/unit_test/voidcrew_zone_missions/proc/package_offer(datum/shop_sku/sku)
	var/datum/mission/mission = allocate(/datum/mission/zone_missions_test/routine)
	mission.contract_quote = 2400
	mission.contract_stock = list()
	mission.contract_item_values = list()
	mission.contract_stock[sku.item_path] = sku
	mission.contract_item_values[sku.item_path] = 900
	mission.mission_rewards = list(sku.item_path)
	mission.reward_amounts = list()
	mission.reward_amounts[sku.item_path] = 1
	mission.set_contract_currency(1500)
	return mission

/// Permission/stock loss uses M1's exact remainder, with original-crew cap reservation/release.
/datum/unit_test/voidcrew_zone_missions/packages/Run()
	var/obj/structure/overmap/ship/public_ship = make_ship()
	var/obj/structure/overmap/ship/advanced_ship = make_ship(2)
	var/datum/voidcrew_crew_record/record = advanced_ship.get_crew_record()
	var/datum/shop_sku/sku = allocate(/datum/shop_sku/general/beans)
	sku.zone_permission = 2
	sku.stock = 2
	sku.crew_limit = 1
	var/datum/mission/offer = package_offer(sku)
	var/list/low = offer.get_effective_contract_package(public_ship.get_crew_record())
	var/list/high = offer.get_effective_contract_package(record)
	TEST_ASSERT_EQUAL(length(low["items"]), 0, "Public package included denied goods")
	TEST_ASSERT_EQUAL(length(high["items"]), 1, "Permitted package lost available goods")
	TEST_ASSERT_EQUAL(low["credits"] + low["vouchers"] * 1200, 2400, "Public fallback changed total value")
	TEST_ASSERT_EQUAL(length(offer.mission_rewards), 1, "Viewing rewrote the shared package")
	TEST_ASSERT_EQUAL(sku.stock, 2, "Viewing reserved stock")
	TEST_ASSERT(offer.start_mission(advanced_ship), "Permitted package did not reserve")
	TEST_ASSERT_EQUAL(sku.reserved_stock, 1, "Acceptance lost its stock hold")
	TEST_ASSERT_EQUAL(record.favor_unique_purchases[sku.type], 1, "Acceptance did not claim the crew cap")
	var/datum/mission/racing = package_offer(sku)
	TEST_ASSERT(racing.start_mission(advanced_ship), "A capped package should still accept currency")
	TEST_ASSERT_EQUAL(length(racing.get_reward_types()), 0, "Two packages charged the same crew cap")
	TEST_ASSERT_EQUAL(racing.value + racing.voucher_count * 1200, 2400, "Cap fallback lost value")
	offer.fail("Cancelled.")
	TEST_ASSERT_EQUAL(sku.stock, 2, "Cancellation lost held stock")
	TEST_ASSERT_EQUAL(record.favor_unique_purchases[sku.type], 0, "Cancellation lost the crew's purchase slot")
	var/datum/mission/settlement = package_offer(sku)
	TEST_ASSERT(settlement.start_mission(advanced_ship), "Second reservation failed")
	record.reputation = 0
	TEST_ASSERT(settlement.turn_in(run_loc_floor_bottom_left, null), "Permission loss blocked currency settlement")
	TEST_ASSERT_EQUAL(sku.stock, 2, "Denied settlement consumed the restricted goods")
	TEST_ASSERT_EQUAL(sku.reserved_stock, 0, "Denied settlement retained its hold")
	TEST_ASSERT_EQUAL(record.favor_unique_purchases[sku.type], 0, "Denied settlement consumed the original cap")
	TEST_ASSERT_EQUAL(public_ship.get_crew_record().favor_unique_purchases[sku.type] || 0, 0, "Another crew's cap was charged")
	var/datum/mission/drained = package_offer(sku)
	sku.stock = 0
	TEST_ASSERT(drained.start_mission(public_ship), "Empty shelf prevented currency settlement")
	TEST_ASSERT_EQUAL(length(drained.get_reward_types()), 0, "Unavailable stock remained in the bound package")
	TEST_ASSERT_EQUAL(drained.value + drained.voucher_count * 1200, 2400, "Empty shelf lost quoted value")

/// Original crew disposal releases stock and references without granting restricted goods later.
/datum/unit_test/voidcrew_zone_missions/cleanup/Run()
	var/obj/structure/overmap/ship/ship = make_ship(2)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	var/datum/shop_sku/sku = allocate(/datum/shop_sku/general/beans)
	sku.zone_permission = 2
	sku.stock = 1
	sku.crew_limit = 1
	var/datum/mission/mission = package_offer(sku)
	TEST_ASSERT(mission.start_mission(ship), "Cleanup fixture could not reserve")
	qdel(record)
	TEST_ASSERT_NULL(mission.accepting_crew, "Accepted work retained a disposed crew record")
	TEST_ASSERT_EQUAL(sku.stock, 1, "Crew disposal lost held stock")
	TEST_ASSERT_EQUAL(sku.reserved_stock, 0, "Crew disposal retained held stock")
	TEST_ASSERT_EQUAL(length(mission.get_reward_types()), 0, "Disposed crew retained restricted package goods")
	TEST_ASSERT_EQUAL(mission.value + mission.voucher_count * 1200, 2400, "Crew disposal changed the fixed quote")
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, null), "Crew disposal prevented ordinary currency settlement")

/// Five slots, the reserved top-band offers, bounded retries and a fixed hull clock.
/datum/unit_test/voidcrew_zone_missions/opportunities/Run()
	var/datum/controller/subsystem/missions/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	controller.mission_types = list(
		/datum/mission/recovery/kill/zone_missions_test,
		/datum/mission/big_game_hunt/zone_missions_test,
		/datum/mission/live_capture/zone_missions_test,
		/datum/mission/poacher_bust/zone_missions_test,
		/datum/mission/recovery/survey/zone_missions_test,
		/datum/mission/recovery/extraction/zone_missions_test,
	)
	var/obj/structure/overmap/ship/ship = make_ship()
	TEST_ASSERT(controller.refresh_ship_missions(ship), "Scheduled board generation failed")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 5, "Board did not preserve five slots")
	var/reserved = 0
	for(var/datum/mission/offer in ship.available_missions)
		if(offer.target)
			reserved++
			TEST_ASSERT_EQUAL(offer.quote_zone, 1, "New crew received higher-band work")
	TEST_ASSERT_EQUAL(reserved, 4, "The board did not hold its green travel job and three reserved offers")
	TEST_ASSERT_EQUAL(ship.next_mission_refresh, world.time + 20 MINUTES, "Scheduled interval changed")
	var/refresh_at = ship.next_mission_refresh
	var/datum/mission/accepted = ship.available_missions[1]
	TEST_ASSERT_EQUAL(ship.accept_mission(accepted), TRUE, "Reserved green travel fixture did not accept")
	var/datum/mission/deleted = ship.available_missions[1]
	ship.available_missions -= deleted
	qdel(deleted)
	var/attempts_before = controller.work_attempts
	TEST_ASSERT(!controller.force_refresh_ship_missions(ship), "Vacancies triggered a reroll")
	TEST_ASSERT_EQUAL(controller.work_attempts, attempts_before, "A premature refresh attempted generation")
	TEST_ASSERT_EQUAL(ship.next_mission_refresh, refresh_at, "A vacancy reset the hull's clock")
	controller.fail_work = TRUE
	ship.next_mission_refresh = world.time
	TEST_ASSERT(controller.refresh_ship_missions(ship), "Scheduled shortage did not refresh")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 5, "A shortage of targeted work left the board short")
	TEST_ASSERT(controller.work_attempts - attempts_before <= 24, "Shortage retries were not bounded")
	TEST_ASSERT(accepted in ship.active_missions, "Refresh removed accepted work")
	controller.fail_work = FALSE
	for(var/list/step as anything in list(list(0, 1), list(3, 1), list(4, 2), list(10, 2), list(11, 3), list(22, 3)))
		var/obj/structure/overmap/ship/stepped = make_ship()
		var/datum/voidcrew_crew_record/record = stepped.get_crew_record()
		record.reputation = step[1]
		TEST_ASSERT_EQUAL(controller.top_work_band(record), step[2], "Reputation [step[1]] picked the wrong top band")
		TEST_ASSERT_EQUAL(controller.reserve_top_band_offers(stepped), 3, "The top band was not reserved")
		for(var/datum/mission/offer in stepped.available_missions)
			TEST_ASSERT_EQUAL(offer.quote_zone, step[2], "A reserved offer sat in the wrong band")

/// Globally held types cannot reserve failed slots ahead of available work.
/datum/unit_test/voidcrew_zone_missions/globally_capped_opportunities/Run()
	var/datum/controller/subsystem/missions/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	var/obj/structure/overmap/ship/holder = make_ship()
	SSovermap.simulated_ships |= holder
	var/list/capped_types = list(
		/datum/mission/big_game_hunt/zone_missions_test/capped,
		/datum/mission/live_capture/zone_missions_test/capped,
		/datum/mission/poacher_bust/zone_missions_test/capped,
	)
	for(var/mission_type in capped_types)
		var/datum/mission/held = allocate(mission_type)
		holder.available_missions += held
		TEST_ASSERT(mission_type_within_limit(mission_type), "An unaccepted private offer occupied global capacity")
	controller.mission_types = capped_types
	var/obj/structure/overmap/ship/second_crew = make_ship()
	TEST_ASSERT_EQUAL(controller.reserve_top_band_offers(second_crew), 3, "Private offers kept another crew from the reserved slots")
	TEST_ASSERT_EQUAL(length(second_crew.available_missions), 3, "Another crew could not obtain the held types")
	for(var/datum/mission/held in holder.available_missions.Copy())
		TEST_ASSERT_EQUAL(holder.accept_mission(held), TRUE, "A private offer blocked acceptance before any mission was running")
		TEST_ASSERT(!mission_type_within_limit(held.type), "Accepted work failed to occupy its global cap")
	for(var/datum/mission/racing in second_crew.available_missions)
		TEST_ASSERT_EQUAL(second_crew.accept_mission(racing), "That contract is already taken.", "Acceptance bypassed running-work capacity")
	TEST_ASSERT_EQUAL(length(second_crew.active_missions), 0, "Refused acceptance started a mission")
	controller.work_attempts = 0
	controller.mission_types = capped_types + list(/datum/mission/recovery/kill/zone_missions_test)
	var/obj/structure/overmap/ship/partial = make_ship()
	TEST_ASSERT(controller.refresh_ship_missions(partial), "Partial supply did not refresh")
	TEST_ASSERT_EQUAL(length(partial.available_missions), 5, "Globally capped types consumed otherwise available board slots")
	TEST_ASSERT_EQUAL(controller.work_attempts, 3, "Reserved slots rolled a type nobody can take")

/// Empty, dead and abandoned rosters do not roll offers or advance the hull clock.
/datum/unit_test/voidcrew_zone_missions/idle_hulls/Run()
	var/datum/controller/subsystem/missions/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	controller.mission_types = list(/datum/mission/recovery/kill/zone_missions_test)
	var/obj/structure/overmap/ship/ship = make_ship(0, FALSE)
	TEST_ASSERT(!controller.refresh_ship_missions(ship), "A crewless hull generated offers")
	TEST_ASSERT_EQUAL(ship.next_mission_refresh, 0, "Crewless refresh advanced the hull clock")
	var/mob/living/carbon/human/member = allocate(/mob/living/carbon/human/consistent)
	member.mind_initialize()
	allocated += member.mind
	ship.enlist_crewmember(member)
	member.stat = DEAD
	TEST_ASSERT(!controller.refresh_ship_missions(ship), "A dead crew generated offers")
	member.stat = CONSCIOUS
	ship.abandoned = TRUE
	TEST_ASSERT(!controller.refresh_ship_missions(ship), "An abandoned hull generated offers")
	TEST_ASSERT_EQUAL(length(ship.available_missions), 0, "An idle hull retained generated offers")
	ship.abandoned = FALSE
	TEST_ASSERT(controller.refresh_ship_missions(ship), "A living crew could not receive its first batch")

/// Actual contact entry points fail closed at capacity and never fall back across bands.
/datum/unit_test/voidcrew_zone_missions/capacity/Run()
	var/datum/controller/subsystem/overmap/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	var/planets_before = length(GLOB.overmap_planets)
	var/ruins_before = length(GLOB.space_ruin_signals)
	TEST_ASSERT_NULL(controller.spawn_mission_planet(1), "Full world created a planet contact")
	TEST_ASSERT_NULL(controller.spawn_mission_ruin(1), "Full world created a ruin contact")
	TEST_ASSERT_EQUAL(length(GLOB.overmap_planets), planets_before, "Capacity refusal leaked a planet")
	TEST_ASSERT_EQUAL(length(GLOB.space_ruin_signals), ruins_before, "Capacity refusal leaked a ruin")
	controller.capacity = TRUE
	TEST_ASSERT_NULL(controller.spawn_mission_planet(1), "Empty overmap created an invalid contact")
	TEST_ASSERT_NULL(controller.spawn_dynamic_planet(/obj/structure/overmap/planet/lava, 1, 1, null, TRUE), "Strict contact creation invented a destination")
	TEST_ASSERT_EQUAL(controller.any_band_calls, 0, "A strict contact fell back outside its band")

/// Mixed occupancy, unknown zones and absent coordinate bands never trigger a higher-band fallback.
/datum/unit_test/voidcrew_zone_missions/strict_targets
	var/list/saved_planets
	var/list/saved_ruins
	var/list/saved_outposts
	var/turf/green
	var/turf/red
	var/green_type
	var/red_type

/datum/unit_test/voidcrew_zone_missions/strict_targets/Destroy()
	. = ..()
	if(green)
		green.ChangeTurf(green_type)
	if(red)
		red.ChangeTurf(red_type)
	if(saved_planets)
		GLOB.overmap_planets = saved_planets
	if(saved_ruins)
		GLOB.space_ruin_signals = saved_ruins
	if(saved_outposts)
		GLOB.trader_outposts = saved_outposts

/datum/unit_test/voidcrew_zone_missions/strict_targets/Run()
	saved_planets = GLOB.overmap_planets
	saved_ruins = GLOB.space_ruin_signals
	saved_outposts = GLOB.trader_outposts
	GLOB.overmap_planets = list()
	GLOB.space_ruin_signals = list()
	GLOB.trader_outposts = list()
	green_type = run_loc_floor_bottom_left.type
	red_type = run_loc_floor_top_right.type
	green = run_loc_floor_bottom_left.ChangeTurf(/turf/open/overmap)
	red = run_loc_floor_top_right.ChangeTurf(/turf/open/overmap)
	var/turf/open/overmap/green_tile = green
	var/turf/open/overmap/red_tile = red
	green_tile.current_zone = allocate(/datum/overmap_zone, 1)
	red_tile.current_zone = allocate(/datum/overmap_zone, 3)
	var/obj/structure/overmap/space_ruin/green_ruin = allocate(__IMPLIED_TYPE__, green)
	var/obj/structure/overmap/space_ruin/red_ruin = allocate(__IMPLIED_TYPE__, red)
	green_ruin.loaded = TRUE
	var/datum/mission/mission = allocate(/datum/mission/zone_missions_test, null, 1)
	var/datum/mission_target/space_ruin/ruin_target = allocate(__IMPLIED_TYPE__, mission)
	TEST_ASSERT(ruin_target.resolve(), "An eligible loaded site was hidden by a cold site in another band")
	TEST_ASSERT_EQUAL(ruin_target.ruin, green_ruin, "Ruin preference escaped its band")
	ruin_target.unhook()
	TEST_ASSERT_EQUAL(green_ruin.mission_claims, 0, "Unhook retained the ruin claim")
	mission.exclusive_site = TRUE
	TEST_ASSERT(!ruin_target.resolve(), "Exclusive work fell back to an ineligible cold ruin")
	mission.exclusive_site = FALSE
	var/obj/structure/overmap/planet/lava/green_planet = allocate(__IMPLIED_TYPE__, green)
	var/obj/structure/overmap/planet/lava/red_planet = allocate(__IMPLIED_TYPE__, red)
	var/datum/mission_target/planet/planet_target = allocate(__IMPLIED_TYPE__, mission)
	TEST_ASSERT(planet_target.resolve(), "Eligible planet was not selected")
	TEST_ASSERT_EQUAL(planet_target.planet, green_planet, "Planet resolution escaped its band")
	planet_target.unhook()
	green_planet.mission_exclusive = TRUE
	TEST_ASSERT(!planet_target.resolve(), "Planet selection ignored site exclusivity")
	green_planet.mission_exclusive = FALSE
	var/list/tables = list(/datum/overmap/planet/lava = TRUE)
	TEST_ASSERT_EQUAL(length(mission.get_work_biomes(tables)), 1, "Eligible biome pool was empty")
	green_tile.current_zone = null
	TEST_ASSERT(!planet_target.resolve(), "Unknown planet band was accepted")
	TEST_ASSERT(!ruin_target.resolve(), "Unknown ruin band was accepted")
	TEST_ASSERT_EQUAL(length(mission.get_work_biomes(tables)), 0, "Biome preselection included unknown or denied sites")
	mission.create_field_contact = TRUE
	TEST_ASSERT_EQUAL(length(mission.get_work_biomes(tables)), 1, "Scheduled empty-site generation lost the repeatable biome pool")
	mission.create_field_contact = FALSE
	var/datum/mission_target/coords/coords = allocate(__IMPLIED_TYPE__, mission)
	coords.zone_weights = list("2" = 1, "3" = 1)
	TEST_ASSERT_NULL(coords.pick_zone_band(), "Coordinate target fell back from an unavailable band")
	var/obj/structure/overmap/trader_outpost/post = allocate(__IMPLIED_TYPE__, red)
	var/datum/mission_target/outpost/courier = allocate(__IMPLIED_TYPE__, mission)
	TEST_ASSERT(!courier.resolve(), "Courier destination fell back to a denied band")
	var/datum/mission/posted_here = allocate(/datum/mission/zone_missions_test/routine, post.shop)
	TEST_ASSERT_EQUAL(posted_here.get_work_band(), 3, "A trader job did not count in its outpost's zone")
	// Keep fixture locals alive through the assertions; cleanup must not touch real sites.
	TEST_ASSERT(red_ruin && red_planet && post, "Mixed-band fixtures disappeared")

/// Factory output stays unloaded and uses only ordinary repeatable content in the pinned band.
/datum/unit_test/voidcrew_zone_missions/field_contacts
	var/turf/destination
	var/original_type

/datum/unit_test/voidcrew_zone_missions/field_contacts/Destroy()
	. = ..()
	if(destination)
		destination.ChangeTurf(original_type)

/datum/unit_test/voidcrew_zone_missions/field_contacts/Run()
	original_type = run_loc_floor_bottom_left.type
	destination = run_loc_floor_bottom_left.ChangeTurf(/turf/open/overmap)
	var/turf/open/overmap/tile = destination
	tile.current_zone = allocate(/datum/overmap_zone, 2)
	var/datum/controller/subsystem/overmap/zone_missions_test/controller = allocate(__IMPLIED_TYPE__)
	controller.capacity = TRUE
	controller.destination = destination
	var/obj/structure/overmap/planet/planet = controller.spawn_mission_planet(2, /datum/overmap/planet/lava)
	TEST_ASSERT_NOTNULL(planet, "An empty eligible planet pool could not create a contact")
	allocated += planet
	TEST_ASSERT_EQUAL(planet.zone_band, 2, "Field planet escaped its band")
	TEST_ASSERT(!planet.loaded && !planet.mapzone && !planet.footprint, "Offer generation loaded a planet interior")
	// Use the production registry: the old synthetic duplicate-enabled template hid an empty pool.
	var/list/approved = list()
	TEST_ASSERT_EQUAL(length(controller.mission_ruin_templates), 3, "The approved ordinary combat ruin list changed")
	for(var/datum/map_template/ruin/space/template_type as anything in controller.mission_ruin_templates)
		var/datum/map_template/ruin/space/template = SSmapping.space_ruins_templates[initial(template_type.name)]
		TEST_ASSERT_NOTNULL(template, "Approved ruin [template_type] is absent from the production registry")
		TEST_ASSERT_EQUAL(template.type, template_type, "Approved ruin resolved to a different template")
		TEST_ASSERT(!template.unpickable && !template.allow_duplicates, "Mission approval changed natural seeding or selected unique content")
		TEST_ASSERT(template.width > 0 && template.height > 0 && fexists(template.mappath), "Approved ruin has no production map")
		TEST_ASSERT(controller.ruin_fits_in_level(template), "Approved ruin cannot be docked")
		approved += template
		// Every approved template is already in use; mission replacement must still be allowed.
		var/obj/structure/overmap/space_ruin/existing = allocate(__IMPLIED_TYPE__, destination)
		existing.set_ruin_template(template)
		existing.mission_claims = 1
	var/obj/structure/overmap/space_ruin/ruin = controller.spawn_mission_ruin(2)
	TEST_ASSERT_NOTNULL(ruin, "An empty eligible ruin pool could not create a contact")
	allocated += ruin
	TEST_ASSERT(ruin.ruin_template in approved, "A field contact reused unapproved, chart or unique content")
	TEST_ASSERT(!ruin.loaded && !ruin.mapzone && !ruin.footprint, "Offer generation loaded a ruin interior")
	TEST_ASSERT_EQUAL(SSovermap_zones.get_zone_type(get_turf(ruin)), 2, "Field ruin escaped its pinned band")

#endif
