/// Backgrounds: owned by P4.

// Unit tests compile before the voidcrew defines, so these use literals with the define named
// beside them: "pirate" is BACKGROUND_PIRATE, "background_credits_taken" is
// COMSIG_BACKGROUND_CREDITS_TAKEN, zones 1/2/3 are ZONE_GREEN/YELLOW/RED, 25000 is
// BACKGROUND_PIRATE_GOAL and 3 is BACKGROUND_CRIMINAL_OFFERS. Recognition (P3) and the hauler
// cases (P5) are called through their API procs; these tests set up the bodies and minds those
// procs read rather than any package's internals.

/// A bare hull with a crew roster, deleted with the running test
/proc/bg_pirate_test_hull(datum/unit_test/test, type = /obj/structure/overmap/ship)
	var/obj/structure/overmap/ship/hull = test.allocate(type)
	hull.ship_team = new /datum/team/voidcrew
	hull.ship_team.ship = hull
	return hull

/// A test human with its own name, so name checks never collide between test bodies
/proc/bg_pirate_test_person(turf/where, real_name)
	var/mob/living/carbon/human/person = bg_test_human(where)
	person.fully_replace_character_name(person.real_name, real_name)
	return person

/// Puts a face-hiding mask on this person
/proc/bg_pirate_test_mask(mob/living/carbon/human/person)
	person.equip_to_slot_or_del(new /obj/item/clothing/mask/chameleon(person), ITEM_SLOT_MASK)

/// Puts a card made out to `card_name` in this person's ID slot
/proc/bg_pirate_test_card(mob/living/carbon/human/person, card_name)
	var/obj/item/card/id/advanced/chameleon/card = new(person)
	card.registered_name = card_name
	card.update_label()
	person.equip_to_slot_or_del(card, ITEM_SLOT_ID)
	return card

// ===== THE HULL (map-contracts.md M3) =====

/// The Corsair carries its kit and nothing it must not: no cargo console, no magical SMES, no turrets, only the hull-bound rigs
/datum/unit_test/voidcrew_corsair_hull
	priority = TEST_LONGER

/datum/unit_test/voidcrew_corsair_hull/Run()
	ensure_ship_upgrades_initialized()
	var/list/themes = GLOB.ship_themes[/datum/map_template/shuttle/voidcrew/corsair]
	if(!length(themes))
		check_hull(null, "default", TRUE)
		return
	var/first = TRUE
	for(var/theme_id in themes)
		check_hull(themes[theme_id], theme_id, first)
		first = FALSE

/datum/unit_test/voidcrew_corsair_hull/proc/count_of(list/things, path)
	. = 0
	for(var/atom/thing as anything in things)
		if(istype(thing, path))
			.++

/datum/unit_test/voidcrew_corsair_hull/proc/check_hull(datum/ship_theme/theme, label, check_cargo)
	var/obj/structure/overmap/ship/hull = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/corsair, null, theme)
	if(!hull)
		TEST_FAIL("The [label] Corsair did not load")
		return
	allocated += hull
	var/list/things = list()
	var/turf/deck
	for(var/turf/tile as anything in hull.shuttle.return_turfs())
		things += tile.get_all_contents()
		if(!deck && isfloorturf(tile) && (get_area(tile) in hull.shuttle.shuttle_areas) && !tile.is_blocked_turf(exclude_mobs = TRUE) && !(locate(/obj/machinery) in tile))
			deck = tile

	var/static/list/exactly = list(
		/obj/item/storage/box/disguise_kit = 2,
		/obj/machinery/computer/mission_board/criminal = 1,
		/obj/machinery/ship_combat/interdictor = 1,
		/obj/machinery/ship_combat/interdictor/corsair = 1,
		/obj/machinery/shuttle_scrambler/ship_siphon = 1,
		/obj/machinery/shuttle_scrambler/ship_siphon/corsair = 1,
		/obj/machinery/ship_combat/laser_turret = 2,
		/obj/machinery/ship_combat/missile_launcher = 1,
		/obj/machinery/computer/camera_advanced/ship_combat = 1,
		/obj/machinery/cryopod = 2,
		/obj/machinery/computer/voidcrew_cargo = 0,
		/obj/machinery/power/smes/magical = 0,
		/obj/machinery/porta_turret = 0,
		/obj/structure/ship_missile = 0,
		/obj/machinery/ship_combat/cloak_device = 0,
		/obj/machinery/ship_combat/shield_generator = 0,
		/obj/machinery/ship_combat/ew_suite = 0,
		/obj/machinery/piratepad = 0,
	)
	for(var/path in exactly)
		var/found = count_of(things, path)
		if(found != exactly[path])
			TEST_FAIL("The [label] Corsair has [found] [path], the contract wants [exactly[path]]")
	var/static/list/at_least = list(
		/obj/machinery/mission_pad,
		/obj/machinery/holopad,
		/obj/machinery/computer/bank_machine,
		/obj/item/storage/box/rndboards/all,
	)
	for(var/path in at_least)
		if(!count_of(things, path))
			TEST_FAIL("The [label] Corsair has no [path]")

	for(var/obj/item/storage/box/disguise_kit/kit in things)
		TEST_ASSERT(locate(/obj/item/clothing/mask/chameleon) in kit, "A disguise kit on the [label] Corsair has no mask")
		TEST_ASSERT(locate(/obj/item/card/id/advanced/chameleon) in kit, "A disguise kit on the [label] Corsair has no card")

	if(!check_cargo)
		return
	// No freight line deals with a pirate hull, even through a console carried aboard
	TEST_ASSERT_NOTNULL(deck, "The [label] Corsair has no free deck")
	var/obj/machinery/computer/voidcrew_cargo/console = allocate(/obj/machinery/computer/voidcrew_cargo, deck)
	TEST_ASSERT_NOTEQUAL(console.get_shuttle_error_message(), "No freight line will deal with you", "Freight refused a hull nobody flagged")
	hull.pirate_crew = TRUE
	TEST_ASSERT_EQUAL(console.get_shuttle_error_message(), "No freight line will deal with you", "Freight dealt with a pirate hull")

// ===== THE COUNTERS (MP-1, MP-2) =====

/// Halcyon and Quartermain check faces and papers, the Undertow serves anyone, and the turrets never fire on a refusal
/datum/unit_test/voidcrew_pirate_counters

/datum/unit_test/voidcrew_pirate_counters/Run()
	var/obj/structure/overmap/trader_outpost/halcyon = allocate(/obj/structure/overmap/trader_outpost/general)
	var/obj/structure/overmap/trader_outpost/quartermain = allocate(/obj/structure/overmap/trader_outpost/outfitter)
	var/obj/structure/overmap/trader_outpost/undertow = allocate(/obj/structure/overmap/trader_outpost/black_market)
	var/turf/floor = run_loc_floor_bottom_left

	// A spacefarer with a face is served everywhere
	var/mob/living/carbon/human/spacer = bg_pirate_test_person(floor, "Merrit Cole")
	TEST_ASSERT(!halcyon.background_service_refused(spacer), "Halcyon refused a spacefarer showing his face")
	TEST_ASSERT_NULL(halcyon.background_refusal_line(spacer), "Halcyon had a refusal line for a spacefarer showing his face")

	// No face and no papers: refused at Halcyon and Quartermain, whoever it is
	var/mob/living/carbon/human/stranger = bg_pirate_test_person(floor, "Odile Varga")
	bg_pirate_test_mask(stranger)
	TEST_ASSERT(halcyon.background_service_refused(stranger), "Halcyon served a masked stranger with no card")
	TEST_ASSERT(quartermain.background_service_refused(stranger), "Quartermain served a masked stranger with no card")
	TEST_ASSERT(halcyon.is_user_barred(stranger), "Halcyon's counters served a masked stranger with no card")
	TEST_ASSERT_EQUAL(halcyon.background_refusal_line(stranger), "No face, no papers.", "The trader gave the wrong line to a masked stranger")
	TEST_ASSERT(!undertow.background_service_refused(stranger), "The Undertow refused a masked stranger")
	TEST_ASSERT(!halcyon.is_turret_target(stranger), "Halcyon's turrets would fire on a masked stranger")
	// The same stranger with a card is served
	bg_pirate_test_card(stranger, "Odile Varga")
	TEST_ASSERT(!halcyon.background_service_refused(stranger), "Halcyon refused a masked stranger carrying a card")

	// A pirate with his face showing is refused whatever the card says
	var/mob/living/carbon/human/pirate = bg_pirate_test_person(floor, "Ash Vane")
	TEST_ASSERT_NOTNULL(bg_test_state(pirate, "pirate"), "The pirate's background did not start") // BACKGROUND_PIRATE
	bg_pirate_test_card(pirate, "Tomas Hale")
	TEST_ASSERT(halcyon.background_service_refused(pirate), "Halcyon served a pirate showing his face")
	TEST_ASSERT(quartermain.background_service_refused(pirate), "Quartermain served a pirate showing his face")
	TEST_ASSERT_EQUAL(halcyon.background_refusal_line(pirate), "Not your kind. Move along.", "The trader gave the wrong line to a pirate")
	TEST_ASSERT(!undertow.background_service_refused(pirate), "The Undertow refused a pirate")
	TEST_ASSERT(!halcyon.is_turret_target(pirate), "Halcyon's turrets would fire on a pirate who has done nothing")

	// Masked with a forged card in another name: served
	bg_pirate_test_mask(pirate)
	TEST_ASSERT(!halcyon.background_service_refused(pirate), "Halcyon refused a masked pirate carrying a forged card")
	// Masked with a card in his own name: the name gives him away
	var/obj/item/card/id/card = pirate.wear_id
	card.registered_name = "Ash Vane"
	card.update_label()
	TEST_ASSERT(halcyon.background_service_refused(pirate), "Halcyon served a masked pirate carrying a card in his own name")

	// Somebody else wearing the pirate's name on a card, face showing, is not taken for him
	var/mob/living/carbon/human/namesake = bg_pirate_test_person(floor, "Ash Vane")
	TEST_ASSERT(!halcyon.background_service_refused(namesake), "Halcyon refused the pirate's namesake showing his own face")

// ===== THE BERTHS (MP-4) =====

/// Halcyon and Quartermain turn pirate hulls and carriers of pirate hulls away; the Undertow berths them
/datum/unit_test/voidcrew_pirate_docking

/datum/unit_test/voidcrew_pirate_docking/Run()
	var/obj/structure/overmap/trader_outpost/halcyon = allocate(/obj/structure/overmap/trader_outpost/general)
	var/obj/structure/overmap/trader_outpost/quartermain = allocate(/obj/structure/overmap/trader_outpost/outfitter)
	var/obj/structure/overmap/trader_outpost/undertow = allocate(/obj/structure/overmap/trader_outpost/black_market)
	var/mob/living/carbon/human/pilot = bg_pirate_test_person(run_loc_floor_bottom_left, "Lena Holt")

	var/obj/structure/overmap/ship/raider = bg_pirate_test_hull(src)
	var/obj/structure/overmap/ship/carrier = bg_pirate_test_hull(src)
	TEST_ASSERT_NULL(halcyon.background_docking_refusal(raider), "Halcyon refused a hull nobody flagged")
	raider.pirate_crew = TRUE
	TEST_ASSERT_NOTNULL(halcyon.background_docking_refusal(raider), "Halcyon berthed a pirate hull")
	TEST_ASSERT_NOTNULL(quartermain.background_docking_refusal(raider), "Quartermain berthed a pirate hull")
	TEST_ASSERT_NULL(undertow.background_docking_refusal(raider), "The Undertow refused a pirate hull")

	// The refusal stops ship_act() before any berth is claimed or the interior loads
	var/state_before = raider.state
	halcyon.ship_act(pilot, raider)
	TEST_ASSERT_EQUAL(raider.state, state_before, "A refused pirate hull was put into a docking state")
	TEST_ASSERT(!halcyon.concerned, "Halcyon was left busy by a refused pirate hull")
	TEST_ASSERT(!halcyon.loaded, "Halcyon loaded its interior for a refused pirate hull")

	// A carrier with a pirate hull riding in it is refused too
	TEST_ASSERT(!background_rider_flagged(carrier), "An empty carrier read as carrying a pirate")
	TEST_ASSERT_NULL(halcyon.background_docking_refusal(carrier), "Halcyon refused an empty carrier")
	raider.forceMove(carrier)
	TEST_ASSERT(background_rider_flagged(carrier), "A carrier with a pirate hull aboard did not read as carrying one")
	TEST_ASSERT_NOTNULL(halcyon.background_docking_refusal(carrier), "Halcyon berthed a carrier with a pirate hull aboard")
	state_before = carrier.state
	halcyon.ship_act(pilot, carrier)
	TEST_ASSERT_EQUAL(carrier.state, state_before, "A refused carrier was put into a docking state")
	TEST_ASSERT_NULL(undertow.background_docking_refusal(carrier), "The Undertow refused a carrier with a pirate hull aboard")
	raider.forceMove(run_loc_floor_bottom_left)

// ===== THE CORDON (MP-5, MP-6) =====

/// A pirate hull is turned back at the edge of green; an ordinary hull crosses; a force-docked victim is let through
/datum/unit_test/voidcrew_pirate_green_cordon

/datum/unit_test/voidcrew_pirate_green_cordon/Run()
	var/datum/overmap_zone/green = allocate(/datum/overmap_zone, 1) // ZONE_GREEN
	var/datum/overmap_zone/yellow = allocate(/datum/overmap_zone, 2) // ZONE_YELLOW
	var/turf/far_side = run_loc_floor_top_right

	var/obj/structure/overmap/ship/raider = bg_pirate_test_hull(src)
	raider.pirate_crew = TRUE
	raider.start_zone_transition(far_side, green)
	TEST_ASSERT(!raider.zone_transitioning, "A pirate hull began crossing into green")
	raider.start_zone_transition(far_side, yellow)
	TEST_ASSERT(raider.zone_transitioning, "A pirate hull could not cross into yellow")
	raider.cancel_zone_transition()

	var/obj/structure/overmap/ship/trader = bg_pirate_test_hull(src)
	trader.start_zone_transition(far_side, green)
	TEST_ASSERT(trader.zone_transitioning, "An ordinary hull could not cross into green")
	trader.cancel_zone_transition()

	// A hull that took a pirate aboard willingly stays out with it
	raider.forceMove(trader)
	trader.start_zone_transition(far_side, green)
	TEST_ASSERT(!trader.zone_transitioning, "A hull carrying a pirate it took aboard crossed into green")

	// A pirate that force-docked onto its victim is cast off at the line, and the victim goes through
	COOLDOWN_START(trader, interdiction_undock_lockout, 5 MINUTES)
	TEST_ASSERT(!trader.background_zone_refusal(green), "A force-docked victim was kept out of green with its attacker")
	trader.start_zone_transition(far_side, green)
	TEST_ASSERT(trader.zone_transitioning, "A force-docked victim could not run for green")
	trader.cancel_zone_transition()
	COOLDOWN_RESET(trader, interdiction_undock_lockout)
	raider.forceMove(run_loc_floor_bottom_left)

// ===== THE BLACK LEDGER =====

/// A pirate hull's board fills from the criminal pool only, with no green reserve, and the Black Ledger never lists the wanted
/datum/unit_test/voidcrew_pirate_criminal_board

/datum/unit_test/voidcrew_pirate_criminal_board/Run()
	var/obj/structure/overmap/ship/raider = bg_pirate_test_hull(src)
	raider.pirate_crew = TRUE
	// An ordinary offer from before the hull was flagged
	var/datum/mission/delivery/old_offer = new(null, null)
	raider.available_missions += old_offer
	SSmissions.refresh_ship_missions(raider)
	TEST_ASSERT(QDELETED(old_offer), "An ordinary offer stayed on a pirate hull's board")
	TEST_ASSERT_EQUAL(length(raider.available_missions), 3, "A pirate hull's board did not fill to the criminal offer count") // BACKGROUND_CRIMINAL_OFFERS
	for(var/datum/mission/offer as anything in raider.available_missions)
		TEST_ASSERT(istype(offer, /datum/mission/criminal), "A pirate hull was offered [offer.type]")
	QDEL_LIST(raider.available_missions)
	raider.available_missions = list()

	var/obj/machinery/computer/mission_board/criminal/ledger = allocate(/obj/machinery/computer/mission_board/criminal)
	TEST_ASSERT_EQUAL(ledger.name, "Black Ledger", "The Black Ledger has the wrong name")
	var/list/data = list()
	ledger.board_add_wanted_data(data, raider, null)
	TEST_ASSERT_EQUAL(length(data["wanted"]), 0, "The Black Ledger listed wanted criminals")
	var/list/static_data = ledger.ui_static_data(null)
	TEST_ASSERT_EQUAL(static_data["board_flavour"], "criminal", "The Black Ledger did not send its flavour")
	var/obj/item/circuitboard/board = ledger.circuit
	TEST_ASSERT_EQUAL(board?.build_path, /obj/machinery/computer/mission_board/criminal, "The Black Ledger's board builds something else")
	// MP-12: nothing prints the board
	for(var/datum/design/design as anything in subtypesof(/datum/design))
		if(ispath(initial(design.build_path), /obj/item/circuitboard/computer/mission_board/criminal))
			TEST_FAIL("[design] prints the Black Ledger's board")

// ===== SHAKEDOWN (ECO-9) =====

/// Takes off player hulls complete a Shakedown but pay nothing; only takes off NPC hulls pay
/datum/unit_test/voidcrew_pirate_shakedown_pay

/datum/unit_test/voidcrew_pirate_shakedown_pay/Run()
	// run_shakedown() returns the failure instead of a list when one of its own checks fails
	var/list/result = run_shakedown(0, 1)
	if(!islist(result))
		return
	TEST_ASSERT_EQUAL(result[2], 0, "A Shakedown paid for credits taken off a player hull")
	result = run_shakedown(0.5, 0.5)
	if(!islist(result))
		return
	TEST_ASSERT_EQUAL(result[2], round(result[1] * 0.5), "A half-NPC Shakedown did not pay half")
	result = run_shakedown(1, 0)
	if(!islist(result))
		return
	TEST_ASSERT_EQUAL(result[2], result[1], "An all-NPC Shakedown did not pay in full")

/// Runs one Shakedown to the end with these shares of its target taken off NPC and player hulls. Returns list(full pay, paid)
/datum/unit_test/voidcrew_pirate_shakedown_pay/proc/run_shakedown(npc_share, player_share)
	var/obj/structure/overmap/ship/raider = bg_pirate_test_hull(src)
	raider.ship_account = allocate(/datum/bank_account/ship, "Shakedown test [REF(raider)]", null, 1, FALSE)
	var/datum/mission/criminal/shakedown/job = new(null, 2) // ZONE_YELLOW
	TEST_ASSERT(!job.generation_failed, "A Shakedown failed to generate")
	TEST_ASSERT(job.take_target >= 1500 && job.take_target <= 3000, "A Shakedown asked for [job.take_target] cr") // BACKGROUND_SHAKEDOWN_TARGET_MIN, _MAX
	raider.available_missions += job
	TEST_ASSERT_EQUAL(raider.accept_mission(job), TRUE, "The test hull could not take a Shakedown")
	var/full_pay = job.value
	var/obj/structure/overmap/ship/npc/mark = allocate(/obj/structure/overmap/ship/npc)
	var/obj/structure/overmap/ship/friend = bg_pirate_test_hull(src)
	if(npc_share)
		SEND_SIGNAL(raider, "background_credits_taken", mark, job.take_target * npc_share, "siphon") // COMSIG_BACKGROUND_CREDITS_TAKEN
	if(player_share)
		SEND_SIGNAL(raider, "background_credits_taken", friend, job.take_target * player_share, "siphon") // COMSIG_BACKGROUND_CREDITS_TAKEN
	TEST_ASSERT(job.can_complete(), "A Shakedown was not done after its full take")
	var/balance_before = raider.ship_account.account_balance
	TEST_ASSERT_EQUAL(raider.complete_mission(job, null, null), TRUE, "A finished Shakedown could not be turned in")
	return list(full_pay, raider.ship_account.account_balance - balance_before)

/// A hull holds one Shakedown at a time: every live Shakedown hears the same take
/datum/unit_test/voidcrew_pirate_shakedown_single

/datum/unit_test/voidcrew_pirate_shakedown_single/Run()
	var/obj/structure/overmap/ship/raider = bg_pirate_test_hull(src)
	var/datum/mission/criminal/shakedown/first = new(null, 2) // ZONE_YELLOW
	var/datum/mission/criminal/shakedown/second = new(null, 2)
	raider.available_missions += list(first, second)
	TEST_ASSERT_EQUAL(raider.accept_mission(first), TRUE, "The test hull could not take a Shakedown")
	TEST_ASSERT_NOTEQUAL(raider.accept_mission(second), TRUE, "A hull took a second Shakedown while one was live")
	TEST_ASSERT(!second.active, "A refused Shakedown went live")
	qdel(first)
	TEST_ASSERT_EQUAL(raider.accept_mission(second), TRUE, "A hull could not take a Shakedown after the last one ended")
	qdel(second)

// ===== THE FLAG AND THE GOAL (MP-4, ECO-10) =====

/// The flag follows a pirate onto a hull he commands, never onto one he only crews, never onto an NPC hull
/datum/unit_test/voidcrew_pirate_flag_follow

/datum/unit_test/voidcrew_pirate_flag_follow/Run()
	var/datum/background/pirate/pirates = background_by_key("pirate") // BACKGROUND_PIRATE
	var/mob/living/carbon/human/captain = bg_pirate_test_person(run_loc_floor_bottom_left, "Corin Mast")
	TEST_ASSERT_NOTNULL(bg_test_state(captain, "pirate"), "The pirate's background did not start")

	var/obj/structure/overmap/ship/claimed = bg_pirate_test_hull(src)
	claimed.ship_team.add_member(captain.mind)
	claimed.claimed_captain = captain.mind
	var/obj/structure/overmap/ship/signed_on = bg_pirate_test_hull(src)
	signed_on.ship_team.add_member(captain.mind)
	var/obj/structure/overmap/ship/npc/npc_hull = bg_pirate_test_hull(src, /obj/structure/overmap/ship/npc)
	npc_hull.ship_team.add_member(captain.mind)
	npc_hull.claimed_captain = captain.mind

	pirates.flag_follow_tick()
	TEST_ASSERT(claimed.pirate_crew, "A hull a pirate claimed was not flagged")
	TEST_ASSERT(!signed_on.pirate_crew, "A hull a pirate only signed onto was flagged")
	TEST_ASSERT(!npc_hull.pirate_crew, "An NPC hull was flagged")

	// A pirate passing through in command does not brand the hull for the round; a hull flagged at spawn keeps it.
	// Bare test hulls are not simulated, so they join the list for this one tick only (nothing yields in between).
	var/obj/structure/overmap/ship/corsair_like = bg_pirate_test_hull(src)
	pirates.pirate_flag_hull(corsair_like)
	claimed.ship_team.remove_member(captain.mind)
	SSovermap.simulated_ships += list(claimed, corsair_like)
	pirates.flag_follow_tick()
	SSovermap.simulated_ships -= list(claimed, corsair_like)
	TEST_ASSERT(!claimed.pirate_crew, "A hull kept the pirate flag after its pirate commander left")
	TEST_ASSERT(corsair_like.pirate_crew, "A hull flagged at spawn lost its flag")

	// A hull claimed a moment ago is turned away at once, without waiting for the next tick
	var/obj/structure/overmap/ship/fresh = bg_pirate_test_hull(src)
	fresh.ship_team.add_member(captain.mind)
	fresh.claimed_captain = captain.mind
	var/obj/structure/overmap/trader_outpost/halcyon = allocate(/obj/structure/overmap/trader_outpost/general)
	TEST_ASSERT_NOTNULL(halcyon.background_docking_refusal(fresh), "Halcyon berthed a hull a pirate had just claimed")
	TEST_ASSERT(fresh.pirate_crew, "A hull a pirate had just claimed was not flagged at the berth")

	signed_on.ship_team.remove_member(captain.mind)
	npc_hull.ship_team.remove_member(captain.mind)
	fresh.ship_team.remove_member(captain.mind)

/// Takes count toward the goal of every pirate aboard, except takes off other pirates and off hulls that share a player
/datum/unit_test/voidcrew_pirate_siphon_goal

/datum/unit_test/voidcrew_pirate_siphon_goal/Run()
	var/datum/background/pirate/pirates = background_by_key("pirate") // BACKGROUND_PIRATE
	var/mob/living/carbon/human/sailor = bg_pirate_test_person(run_loc_floor_bottom_left, "Iva Rook")
	var/datum/background_state/state = bg_test_state(sailor, "pirate")
	TEST_ASSERT_NOTNULL(state, "The pirate's background did not start")
	state.goal_target = 25000 // BACKGROUND_PIRATE_GOAL
	state.progress = 0
	var/obj/structure/overmap/ship/raider = bg_pirate_test_hull(src)
	raider.ship_team.add_member(sailor.mind)
	pirates.on_hull_spawned(raider)
	TEST_ASSERT(raider.pirate_crew, "A spawned pirate hull was not flagged")

	var/obj/structure/overmap/ship/npc/mark = allocate(/obj/structure/overmap/ship/npc)
	SEND_SIGNAL(raider, "background_credits_taken", mark, 1200, "siphon") // COMSIG_BACKGROUND_CREDITS_TAKEN
	TEST_ASSERT_EQUAL(state.progress, 1200, "A take off an NPC hull did not count")

	var/obj/structure/overmap/ship/rival = bg_pirate_test_hull(src)
	rival.pirate_crew = TRUE
	SEND_SIGNAL(raider, "background_credits_taken", rival, 500, "siphon")
	TEST_ASSERT_EQUAL(state.progress, 1200, "A take off another pirate hull counted")

	var/obj/structure/overmap/ship/friend = bg_pirate_test_hull(src)
	friend.background_ever_crew = list(ckey(sailor.mind.key))
	SEND_SIGNAL(raider, "background_credits_taken", friend, 500, "siphon")
	TEST_ASSERT_EQUAL(state.progress, 1200, "A take off a hull this pirate once crewed counted")

	var/obj/structure/overmap/ship/stranger = bg_pirate_test_hull(src)
	SEND_SIGNAL(raider, "background_credits_taken", stranger, 300, "siphon")
	TEST_ASSERT_EQUAL(state.progress, 1500, "A take off a stranger's hull did not count")

	SEND_SIGNAL(raider, "background_credits_taken", mark, 0, "siphon")
	TEST_ASSERT_EQUAL(state.progress, 1500, "An empty take counted")

	raider.pirate_crew = FALSE
	SEND_SIGNAL(raider, "background_credits_taken", mark, 100, "siphon")
	TEST_ASSERT_EQUAL(state.progress, 1500, "A take counted after the hull lost its flag")
	raider.ship_team.remove_member(sailor.mind)

/// The goal's memory and round-end lines read the take with separators
/datum/unit_test/voidcrew_pirate_goal_lines

/datum/unit_test/voidcrew_pirate_goal_lines/Run()
	var/datum/background/pirate/pirates = background_by_key("pirate") // BACKGROUND_PIRATE
	TEST_ASSERT_EQUAL(pirate_credits_text(0), "0", "0 credits read wrong")
	TEST_ASSERT_EQUAL(pirate_credits_text(950), "950", "950 credits read wrong")
	TEST_ASSERT_EQUAL(pirate_credits_text(25000), "25,000", "25,000 credits read wrong")
	TEST_ASSERT_EQUAL(pirate_credits_text(1234567), "1,234,567", "1,234,567 credits read wrong")

	var/mob/living/carbon/human/sailor = bg_pirate_test_person(run_loc_floor_bottom_left, "Bram Teller")
	var/datum/background_state/state = bg_test_state(sailor, "pirate")
	TEST_ASSERT_NOTNULL(state, "The pirate's background did not start")
	pirates.on_started(sailor.mind, state)
	TEST_ASSERT_EQUAL(state.goal_target, 25000, "The pirate goal is not 25,000") // BACKGROUND_PIRATE_GOAL
	TEST_ASSERT_EQUAL(state.crime, "Piracy", "A pirate is not wanted for piracy")
	state.progress = 1250
	TEST_ASSERT_EQUAL(pirates.goal_line(state), "Take 25,000 cr off other ships. 1,250 cr taken so far.", "The goal line reads wrong")
	pirates.judge(state)
	TEST_ASSERT_EQUAL(state.outcome, "failed", "A short take did not settle as failed") // BACKGROUND_OUTCOME_FAILED
	TEST_ASSERT_EQUAL(pirates.outcome_line(state), "Took 1,250 cr of 25,000.", "The short round-end line reads wrong")

	var/mob/living/carbon/human/rich = bg_pirate_test_person(run_loc_floor_bottom_left, "Sela Marr")
	var/datum/background_state/done = bg_test_state(rich, "pirate")
	TEST_ASSERT_NOTNULL(done, "The second pirate's background did not start")
	done.goal_target = 25000 // BACKGROUND_PIRATE_GOAL
	done.progress = 25000
	pirates.judge(done)
	TEST_ASSERT_EQUAL(done.outcome, "done", "A full take did not settle as done") // BACKGROUND_OUTCOME_DONE
	TEST_ASSERT_EQUAL(pirates.outcome_line(done), "Took their 25,000.", "The full round-end line reads wrong")

	// Spawns in yellow or red, never green
	var/turf/spot = pirates.pick_spawn_turf()
	if(spot && SSovermap.overmap_centre)
		TEST_ASSERT(!SSovermap.is_turf_in_green_zone(spot), "A pirate hull would spawn in green")

// ===== HULL-BOUND RIGS (ECO-6) =====

/// The Corsair's interdictor and siphon come apart into two iron sheets, never a board or parts
/datum/unit_test/voidcrew_pirate_hull_bound

/datum/unit_test/voidcrew_pirate_hull_bound/Run()
	var/turf/floor = run_loc_floor_top_right
	for(var/rig_type in list(/obj/machinery/ship_combat/interdictor/corsair, /obj/machinery/shuttle_scrambler/ship_siphon/corsair))
		var/obj/machinery/rig = allocate(rig_type, floor)
		rig.deconstruct(TRUE)
		TEST_ASSERT(QDELETED(rig), "[rig_type] survived being taken apart")
		var/iron = 0
		for(var/obj/item/stack/sheet/iron/sheet in floor)
			iron += sheet.amount
		TEST_ASSERT_EQUAL(iron, 2, "[rig_type] came apart into [iron] iron")
		TEST_ASSERT_NULL(locate(/obj/item/circuitboard) in floor, "[rig_type] left its board")
		TEST_ASSERT_NULL(locate(/obj/structure/frame) in floor, "[rig_type] left a frame")
		TEST_ASSERT_NULL(locate(/obj/item/stock_parts) in floor, "[rig_type] left its parts")
		for(var/obj/item/stack/sheet/iron/sheet in floor)
			qdel(sheet)

	// The takings are money, not a part: they come out as a chip
	var/obj/machinery/shuttle_scrambler/ship_siphon/corsair/siphon = allocate(/obj/machinery/shuttle_scrambler/ship_siphon/corsair, floor)
	siphon.credits_stored = 700
	siphon.deconstruct(TRUE)
	var/obj/item/holochip/chip = locate() in floor
	TEST_ASSERT_EQUAL(chip?.credits, 700, "A siphon taken apart lost its takings")
	qdel(chip)
	for(var/obj/item/stack/sheet/iron/sheet in floor)
		qdel(sheet)
