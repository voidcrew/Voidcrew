/// Backgrounds: owned by P3.

/**
 * Bounty hunter tests (voidcrew/modules/backgrounds/hunter). Voidcrew defines are not visible here: literals
 * carry a comment naming the define. Other packages' inputs are pinned by hand: background states are made
 * directly (not through background_begin()), and a warrant is a plain posting placed in
 * GLOB.background_warrants, which is all the warrant console reads.
 */

/// Where the ship module maps live (the `directory` key of ship_upgrades.toml)
#define HUNTER_TEST_MODULE_ROOT "_maps/voidcrew/ship_modules/"

// ===== FIXTURES =====

/datum/unit_test/voidcrew_backgrounds_hunter
	abstract_type = /datum/unit_test/voidcrew_backgrounds_hunter
	/// Minds this test gave a background state, taken off GLOB.background_minds afterwards
	var/list/hunter_test_minds = list()
	/// Postings this test placed in GLOB.background_warrants
	var/list/hunter_test_warrants = list()
	/// Records this test made, deleted afterwards
	var/list/hunter_test_records = list()

/datum/unit_test/voidcrew_backgrounds_hunter/Destroy()
	for(var/datum/mind/mind as anything in hunter_test_minds)
		GLOB.background_minds -= mind
		mind.background_state = null
	for(var/datum/criminal_bounty/warrant as anything in hunter_test_warrants)
		GLOB.background_warrants -= warrant
		warrant.close("admin") // BOUNTY_CLOSE_ADMIN
	QDEL_LIST(hunter_test_records)
	return ..()

/// A human named `person_name`, dressed in a jumpsuit so a card can go on
/datum/unit_test/voidcrew_backgrounds_hunter/proc/hunter_test_person(person_name)
	var/mob/living/carbon/human/person = bg_test_human(run_loc_floor_bottom_left)
	person.fully_replace_character_name(person.real_name, person_name)
	person.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(person), ITEM_SLOT_ICLOTHING)
	return person

/// Gives the person's mind an active background state of `key`, made by hand. `state_type` lets a test use a double.
/datum/unit_test/voidcrew_backgrounds_hunter/proc/hunter_test_state(mob/living/carbon/human/person, key, state_type = /datum/background_state)
	var/datum/background_state/state = new state_type
	state.key = key
	state.ckey = ckey(person.mind.key)
	state.character_name = person.real_name
	state.mind_ref = WEAKREF(person.mind)
	state.started_at = world.time
	person.mind.background_state = state
	GLOB.background_minds |= person.mind
	hunter_test_minds |= person.mind
	return state

/// Puts an ID card naming `id_name` on the person
/datum/unit_test/voidcrew_backgrounds_hunter/proc/hunter_test_id(mob/living/carbon/human/person, id_name)
	var/obj/item/card/id/advanced/card = new(person)
	card.registered_name = id_name
	person.equip_to_slot_or_del(card, ITEM_SLOT_ID)

/// Covers the person's face
/datum/unit_test/voidcrew_backgrounds_hunter/proc/hunter_test_mask(mob/living/carbon/human/person)
	person.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava(person), ITEM_SLOT_MASK)

/// A bare hull with these minds on its roster
/datum/unit_test/voidcrew_backgrounds_hunter/proc/hunter_test_hull(list/crew_minds)
	var/obj/structure/overmap/ship/hull = allocate(/obj/structure/overmap/ship)
	var/datum/team/voidcrew/crew = new
	crew.ship = hull
	for(var/datum/mind/mind as anything in crew_minds)
		crew.members |= mind
	hull.ship_team = crew
	return hull

/// An open warrant, as far as the console can tell: a posting with a record whose mugshot is already made
/datum/unit_test/voidcrew_backgrounds_hunter/proc/hunter_test_warrant(value = 425)
	var/datum/criminal_bounty/warrant = new
	warrant.record = generate_bounty_record(1, "meek", "planet") // BOUNTY_TIER_PETTY, BOUNTY_PLACEMENT_PLANET
	warrant.record.mugshot = "picture"
	warrant.placement_kind = "planet" // BOUNTY_PLACEMENT_PLANET
	warrant.value = value
	GLOB.background_warrants += warrant
	hunter_test_warrants += warrant
	return warrant

/// The entry for `posting` in a board's wanted list, or null
/datum/unit_test/voidcrew_backgrounds_hunter/proc/hunter_test_entry(list/data, datum/criminal_bounty/posting)
	for(var/list/entry as anything in data["wanted"])
		if(entry["ref"] == REF(posting))
			return entry
	return null

/// The board tests' clock stopped and board emptied around each console test (voidcrew_bounty_board.dm)
/datum/unit_test/voidcrew_backgrounds_hunter/console
	abstract_type = /datum/unit_test/voidcrew_backgrounds_hunter/console

/datum/unit_test/voidcrew_backgrounds_hunter/console/New()
	. = ..()
	board_test_begin()

/datum/unit_test/voidcrew_backgrounds_hunter/console/Destroy()
	board_test_end()
	return ..()

/// A warrant console on a ship a test chooses
/obj/machinery/computer/mission_board/bounty/hunter_test
	var/obj/structure/overmap/ship/test_ship

/obj/machinery/computer/mission_board/bounty/hunter_test/get_ship()
	return test_ship

/// A cell door on a hull a test chooses
/obj/machinery/door/airlock/security/glass/marshal_brig/hunter_test
	var/obj/structure/overmap/ship/test_ship

/obj/machinery/door/airlock/security/glass/marshal_brig/hunter_test/owning_ship()
	return test_ship

/// A hunter hull whose sensors reach a fixed distance
/obj/structure/overmap/ship/hunter_test_watcher
	var/test_reach = 1

/obj/structure/overmap/ship/hunter_test_watcher/get_sensor_range()
	return test_reach

/obj/structure/overmap/ship/hunter_test_watcher/can_scan_ships()
	return TRUE

/// A background state whose target is in a place a test chooses
/datum/background_state/hunter_test
	var/obj/structure/overmap/test_holder

/datum/background_state/hunter_test/last_seen_holder(atom/body)
	return test_holder

// ===== THE BACKGROUND AND ITS GOAL =====

/// The registry entry, its hull, and every paid capture by a watched hull counting for its hunters only
/datum/unit_test/voidcrew_backgrounds_hunter/goal

/datum/unit_test/voidcrew_backgrounds_hunter/goal/Run()
	var/datum/background/bounty_hunter/background = background_by_key("bounty_hunter") // BACKGROUND_BOUNTY_HUNTER
	TEST_ASSERT(istype(background), "No bounty hunter background is registered under \"bounty_hunter\"")
	TEST_ASSERT_EQUAL(background.name, "Bounty Hunter", "The bounty hunter background has the wrong name")
	TEST_ASSERT_EQUAL(background.hull_type, /datum/map_template/shuttle/voidcrew/marshal, "Hunters don't start on the Marshal-class hull")
	TEST_ASSERT_NULL(background.pick_spawn_turf(), "The hunter hull doesn't start in the green default")

	var/mob/living/carbon/human/hunter = hunter_test_person("Hal Ames")
	var/mob/living/carbon/human/spacefarer = hunter_test_person("Ivy Lane")
	var/datum/background_state/state = hunter_test_state(hunter, "bounty_hunter") // BACKGROUND_BOUNTY_HUNTER
	var/datum/background_state/other = hunter_test_state(spacefarer, "spacefarer") // BACKGROUND_SPACEFARER
	background.on_started(hunter.mind, state)
	TEST_ASSERT_EQUAL(state.goal_target, 3, "The hunter goal isn't three bounties") // BACKGROUND_HUNTER_GOAL
	TEST_ASSERT_EQUAL(background.goal_line(state), "Bring in three bounties. None done so far.", "The fresh goal line is wrong")

	var/obj/structure/overmap/ship/hull = hunter_test_hull(list(hunter.mind, spacefarer.mind))
	var/obj/structure/overmap/ship/elsewhere = hunter_test_hull(list(hunter.mind))
	background.on_hull_spawned(hull)
	background.on_hull_spawned(hull) // a second registration must not double the count

	SEND_SIGNAL(elsewhere, "background_bounty_paid", "criminal") // COMSIG_BACKGROUND_BOUNTY_PAID
	TEST_ASSERT_EQUAL(state.progress, 0, "A capture paid to a hull nobody watches counted")

	SEND_SIGNAL(hull, "background_bounty_paid", "criminal") // COMSIG_BACKGROUND_BOUNTY_PAID
	SEND_SIGNAL(hull, "background_bounty_paid", "pirate_ship")
	TEST_ASSERT_EQUAL(state.progress, 2, "Two paid captures didn't count twice")
	TEST_ASSERT_EQUAL(other.progress, 0, "A crewmate who isn't a hunter got hunter progress")
	TEST_ASSERT_EQUAL(state.outcome, "ongoing", "The goal finished early") // BACKGROUND_OUTCOME_ONGOING
	TEST_ASSERT_EQUAL(background.goal_line(state), "Bring in three bounties. Two done so far.", "The goal line didn't follow the count")
	TEST_ASSERT_EQUAL(background.outcome_line(state), "Brought in 2 of 3.", "The unfinished round-end line is wrong")

	SEND_SIGNAL(hull, "background_bounty_paid", "warrant")
	TEST_ASSERT_EQUAL(state.outcome, "done", "Three paid captures didn't finish the goal") // BACKGROUND_OUTCOME_DONE
	TEST_ASSERT_EQUAL(background.outcome_line(state), "Brought in their bounties.", "The finished round-end line is wrong")

	state.ended = TRUE
	SEND_SIGNAL(hull, "background_bounty_paid", "criminal")
	TEST_ASSERT_EQUAL(state.progress, 3, "An ended hunter kept counting")

// ===== THE WARRANT CONSOLE =====

/// The console lists every open warrant beside the board's own postings; a plain board never does [BUG-3]
/datum/unit_test/voidcrew_backgrounds_hunter/console/lists_warrants

/datum/unit_test/voidcrew_backgrounds_hunter/console/lists_warrants/Run()
	var/obj/structure/overmap/ship/ship = board_test_ship()
	var/obj/machinery/computer/mission_board/bounty/console = allocate(/obj/machinery/computer/mission_board/bounty)
	var/obj/machinery/computer/mission_board/plain = allocate(/obj/machinery/computer/mission_board)
	var/datum/criminal_bounty/warrant = hunter_test_warrant()
	var/datum/criminal_bounty/posting = board_test_posting(1)
	TEST_ASSERT(!(warrant in GLOB.criminal_bounties), "A warrant is in the public bounty list")

	var/list/data = list()
	console.board_add_wanted_data(data, ship, null)
	var/list/entry = hunter_test_entry(data, warrant)
	TEST_ASSERT_NOTNULL(entry, "The warrant console doesn't list an open warrant")
	TEST_ASSERT_EQUAL(entry["warrant"], 1, "A warrant's card isn't marked as a warrant")
	var/list/npc_entry = hunter_test_entry(data, posting)
	TEST_ASSERT_NOTNULL(npc_entry, "The warrant console dropped the board's own postings")
	TEST_ASSERT(!npc_entry["warrant"], "An ordinary posting is marked as a warrant")

	var/list/plain_data = list()
	plain.board_add_wanted_data(plain_data, ship, null)
	TEST_ASSERT_NULL(hunter_test_entry(plain_data, warrant), "A plain mission board lists a warrant")
	TEST_ASSERT_NOTNULL(hunter_test_entry(plain_data, posting), "The plain board lost its own posting")

	// The picture goes through static data, keyed by record id
	var/list/mugshots = console.board_wanted_mugshots(ship)
	TEST_ASSERT_EQUAL(mugshots[warrant.record.id], "picture", "The warrant's mugshot isn't in the console's static data")
	TEST_ASSERT(!(warrant.record.id in plain.board_wanted_mugshots(ship)), "A plain board carries a warrant's mugshot")
	TEST_ASSERT(findtext(console.board_static_signature(ship), "[warrant.record.id]:"), "The console's static signature ignores warrants")
	TEST_ASSERT(!console.board_mugshots_pending(ship), "The console waits on a picture that is already made")

	warrant.close("admin") // BOUNTY_CLOSE_ADMIN
	data = list()
	console.board_add_wanted_data(data, ship, null)
	TEST_ASSERT_NULL(hunter_test_entry(data, warrant), "A closed warrant is still listed")

/// No contracts at the warrant console: the actions are refused server side and the lists are empty
/datum/unit_test/voidcrew_backgrounds_hunter/console/refuses_contracts

/datum/unit_test/voidcrew_backgrounds_hunter/console/refuses_contracts/Run()
	var/obj/structure/overmap/ship/ship = board_test_ship()
	var/obj/machinery/computer/mission_board/bounty/hunter_test/console = allocate(/obj/machinery/computer/mission_board/bounty/hunter_test)
	console.test_ship = ship
	var/obj/machinery/computer/mission_board/plain = allocate(/obj/machinery/computer/mission_board)

	var/refreshed_at = world.time - 1 HOURS
	ship.last_mission_refresh = refreshed_at
	TEST_ASSERT(console.ui_act("refresh", list(), null), "The console didn't handle a refresh request")
	TEST_ASSERT_EQUAL(ship.last_mission_refresh, refreshed_at, "The warrant console refreshed the ship's contracts")
	TEST_ASSERT(console.ui_act("accept", list("ref" = "nothing"), null), "The console didn't handle an accept request")
	TEST_ASSERT(console.ui_act("turn_in", list("ref" = "nothing"), null), "The console didn't handle a turn-in request")

	var/datum/criminal_bounty/warrant = hunter_test_warrant()
	var/list/data = console.ui_data(null)
	TEST_ASSERT(data["has_ship"], "The test console isn't on its ship")
	TEST_ASSERT(islist(data["available_missions"]) && !length(data["available_missions"]), "The warrant console offers contracts")
	TEST_ASSERT(islist(data["active_missions"]) && !length(data["active_missions"]), "The warrant console lists contracts")
	TEST_ASSERT_NOTNULL(hunter_test_entry(data, warrant), "The console's live data has no warrant")

	var/list/static_data = console.ui_static_data(null)
	TEST_ASSERT_EQUAL(static_data["board_flavour"], "bounty", "The warrant console doesn't say it is one")
	var/list/plain_static = plain.ui_static_data(null)
	TEST_ASSERT_EQUAL(plain_static["board_flavour"], "standard", "The plain board's flavour changed")
	TEST_ASSERT_EQUAL(console.name, "warrant console", "The console has the wrong name")
	var/obj/item/circuitboard/computer/mission_board/bounty/board = allocate(/obj/item/circuitboard/computer/mission_board/bounty)
	TEST_ASSERT_EQUAL(board.build_path, /obj/machinery/computer/mission_board/bounty, "The warrant console's board builds something else")

	// MP-12: no design prints the board
	for(var/datum/design/design as anything in subtypesof(/datum/design))
		if(ispath(initial(design.build_path), /obj/item/circuitboard/computer/mission_board/bounty))
			TEST_FAIL("[design] prints the warrant console's board")

// ===== RECOGNITION =====

/// A visible face is the person's own mind whatever the card says; a hidden face is whoever the ID names; no face and no ID is no papers [MP-1, MP-2]
/datum/unit_test/voidcrew_backgrounds_hunter/recognition

/datum/unit_test/voidcrew_backgrounds_hunter/recognition/Run()
	var/mob/living/carbon/human/pirate = hunter_test_person("Ada Flint")
	var/datum/background_state/state = hunter_test_state(pirate, "pirate") // BACKGROUND_PIRATE
	var/mob/living/carbon/human/namesake = hunter_test_person("Bram Cole")

	hunter_test_id(pirate, "Bram Cole")
	TEST_ASSERT(!background_face_hidden(pirate), "A bare face reads as hidden")
	TEST_ASSERT_EQUAL(background_recognised_mind(pirate, "pirate"), pirate.mind, "A bare-faced pirate with someone else's card wasn't recognised")
	TEST_ASSERT_EQUAL(background_recognised_mind(pirate, null), pirate.mind, "A bare-faced pirate wasn't recognised under any background")
	TEST_ASSERT_NULL(background_recognised_mind(pirate, "convict"), "A pirate was recognised as a convict") // BACKGROUND_CONVICT

	hunter_test_id(namesake, "Ada Flint")
	TEST_ASSERT_NULL(background_recognised_mind(namesake, "pirate"), "A bare face carrying the pirate's card was taken for the pirate")

	hunter_test_mask(namesake)
	TEST_ASSERT(background_face_hidden(namesake), "A balaclava doesn't hide the face")
	TEST_ASSERT_EQUAL(background_recognised_mind(namesake, "pirate"), pirate.mind, "A masked face carrying the pirate's card wasn't taken for the pirate")
	TEST_ASSERT(!background_no_papers(namesake), "A masked face with a card has no papers")

	hunter_test_mask(pirate)
	TEST_ASSERT_NULL(background_recognised_mind(pirate, "pirate"), "A masked pirate carrying someone else's card was recognised")

	var/mob/living/carbon/human/stranger = hunter_test_person("Cora Vane")
	TEST_ASSERT(!background_no_papers(stranger), "A bare face has no papers")
	hunter_test_mask(stranger)
	TEST_ASSERT(background_no_papers(stranger), "A masked face with no card has papers")
	TEST_ASSERT_NULL(background_recognised_mind(stranger, null), "A masked face with no card was recognised")

	state.ended = TRUE
	TEST_ASSERT_NULL(background_recognised_mind(namesake, "pirate"), "A finished background was still recognised")

/// Pay and recognition never read a crew record's wanted status [MP-3]; the watch marks only the target's own record
/datum/unit_test/voidcrew_backgrounds_hunter/records

/datum/unit_test/voidcrew_backgrounds_hunter/records/Run()
	var/mob/living/carbon/human/pirate = hunter_test_person("Dana Reyes")
	hunter_test_state(pirate, "pirate") // BACKGROUND_PIRATE
	var/mob/living/carbon/human/innocent = hunter_test_person("Eli Ward")

	var/datum/record/crew/clean = new(name = "Dana Reyes")
	hunter_test_records += clean
	var/datum/record/crew/marked = new(name = "Eli Ward")
	hunter_test_records += marked
	marked.wanted_status = WANTED_ARREST
	TEST_ASSERT_EQUAL(background_recognised_mind(pirate, "pirate"), pirate.mind, "A clean record hid a pirate")
	TEST_ASSERT_NULL(background_recognised_mind(innocent, null), "A wanted record made someone a background target")

	// A namesake's record comes first in the manifest; the watch must mark the record bound to the mind
	var/mob/living/carbon/human/convict = hunter_test_person("Finn Rook")
	hunter_test_state(convict, "convict") // BACKGROUND_CONVICT
	var/datum/record/crew/namesake_record = new(name = "Finn Rook")
	hunter_test_records += namesake_record
	var/datum/record/locked/lock = new(name = "Finn Rook", locked_dna = convict.dna, mind_ref = convict.mind)
	hunter_test_records += lock
	var/datum/record/crew/own_record = new(name = "Finn Rook", lock_ref = REF(lock))
	hunter_test_records += own_record
	TEST_ASSERT_EQUAL(background_crew_record(convict.mind, "Finn Rook"), own_record, "The mind's record was confused with a namesake's")

	var/datum/background_hunter_watch/watch = GLOB.background_hunter_watch
	watch.reassert_records(list(convict.mind))
	TEST_ASSERT_EQUAL(own_record.wanted_status, WANTED_ARREST, "A warrant target's record wasn't marked wanted")
	TEST_ASSERT_EQUAL(namesake_record.wanted_status, WANTED_NONE, "A namesake's record was marked wanted")
	own_record.wanted_status = WANTED_NONE
	watch.reassert_records(list(convict.mind))
	TEST_ASSERT_EQUAL(own_record.wanted_status, WANTED_ARREST, "A cleared record wasn't put back")
	watch.reassert_records(list())
	TEST_ASSERT_EQUAL(own_record.wanted_status, WANTED_NONE, "A closed warrant left the record wanted")
	watch.reassert_records(list(convict.mind))
	own_record.wanted_status = WANTED_PRISONER
	watch.reassert_records(list())
	TEST_ASSERT_EQUAL(own_record.wanted_status, WANTED_PRISONER, "Closing the warrant undid a capture's record")

// ===== LAST SEEN [PERF-3] =====

/// A reading needs a hunter hull's sensors on the target's place, and comes at most once every 30 s
/datum/unit_test/voidcrew_backgrounds_hunter/last_seen

/datum/unit_test/voidcrew_backgrounds_hunter/last_seen/Run()
	var/mob/living/carbon/human/convict = hunter_test_person("Gil Hart")
	var/datum/background_state/hunter_test/state = hunter_test_state(convict, "convict", /datum/background_state/hunter_test) // BACKGROUND_CONVICT
	var/obj/structure/overmap/ship/hunter_test_watcher/watcher = allocate(/obj/structure/overmap/ship/hunter_test_watcher, run_loc_floor_bottom_left)
	var/obj/structure/overmap/ship/holder = allocate(/obj/structure/overmap/ship, run_loc_floor_bottom_left)
	holder.name = "Wanderer"
	state.test_holder = holder
	TEST_ASSERT_NULL(state.last_seen_text(), "A target nobody has seen has a last-seen line")

	TEST_ASSERT(state.update_last_seen(list(watcher)), "The first reading didn't happen")
	TEST_ASSERT_EQUAL(state.last_seen_text(), "Last seen at Wanderer", "The reading didn't name the place")
	TEST_ASSERT_EQUAL(state.last_seen_at, world.time, "The reading has no time")

	holder.name = "Elsewhere"
	TEST_ASSERT(!state.update_last_seen(list(watcher)), "A second reading came inside 30 s") // BACKGROUND_LAST_SEEN_INTERVAL
	TEST_ASSERT_EQUAL(state.last_seen_text(), "Last seen at Wanderer", "A refused reading changed the card")

	state.extra["p3_last_check"] = world.time - 31 SECONDS
	TEST_ASSERT(state.update_last_seen(list(watcher)), "No reading after 30 s")
	TEST_ASSERT_EQUAL(state.last_seen_text(), "Last seen at Elsewhere", "The new reading didn't replace the old")

	// Out of the sensors' reach: the card keeps the last reading
	var/obj/structure/overmap/ship/far = allocate(/obj/structure/overmap/ship, run_loc_floor_top_right)
	far.name = "Far Away"
	state.test_holder = far
	state.extra["p3_last_check"] = world.time - 31 SECONDS
	TEST_ASSERT(!background_sensors_reach(watcher, far), "Sensors with a reach of one tile saw across the room")
	state.update_last_seen(list(watcher))
	TEST_ASSERT_EQUAL(state.last_seen_text(), "Last seen at Elsewhere", "A place out of reach was read")

// ===== EVER-CREW [ECO-2] =====

/// Rosters go on the hull's list by ckey; "free" means conscious, uncuffed and not stunned
/datum/unit_test/voidcrew_backgrounds_hunter/ever_crew

/datum/unit_test/voidcrew_backgrounds_hunter/ever_crew/Run()
	var/mob/living/carbon/human/deputy = hunter_test_person("Hank Pell")
	var/obj/structure/overmap/ship/hull = hunter_test_hull(list(deputy.mind))
	GLOB.background_hunter_watch.note_roster(hull)
	TEST_ASSERT(ckey(deputy.mind.key) in hull.background_ever_crew, "A roster member isn't on the ever-crew list")
	background_note_ever_crew(hull, "Some Player")
	TEST_ASSERT("someplayer" in hull.background_ever_crew, "The list doesn't hold ckeys")
	background_note_ever_crew(null, "Some Player") // no hull, no runtime

	var/mob/living/carbon/human/convict = hunter_test_person("Iris Kane")
	TEST_ASSERT(background_is_free(convict), "A standing convict isn't free")
	ADD_TRAIT(convict, TRAIT_RESTRAINED, "hunter_test")
	TEST_ASSERT(!background_is_free(convict), "A cuffed convict is free")
	REMOVE_TRAIT(convict, TRAIT_RESTRAINED, "hunter_test")
	ADD_TRAIT(convict, TRAIT_INCAPACITATED, "hunter_test")
	TEST_ASSERT(!background_is_free(convict), "A stunned convict is free")
	REMOVE_TRAIT(convict, TRAIT_INCAPACITATED, "hunter_test")

	// Brought aboard cuffed, the convict is the hull's prisoner even once uncuffed; walking aboard free is a meet-up
	var/datum/background_hunter_watch/watch = GLOB.background_hunter_watch
	var/datum/background_state/state = hunter_test_state(convict, "convict") // BACKGROUND_CONVICT
	var/convict_ckey = ckey(convict.mind.key)
	ADD_TRAIT(convict, TRAIT_RESTRAINED, "hunter_test")
	watch.note_aboard(convict.mind, hull)
	REMOVE_TRAIT(convict, TRAIT_RESTRAINED, "hunter_test")
	watch.note_aboard(convict.mind, hull)
	TEST_ASSERT(!(convict_ckey in hull.background_ever_crew), "A prisoner let out of his cuffs aboard was counted as crew")
	var/obj/structure/overmap/ship/other_hull = hunter_test_hull(list())
	watch.note_aboard(convict.mind, other_hull)
	TEST_ASSERT(convict_ckey in other_hull.background_ever_crew, "A convict standing free on a hull wasn't counted")
	watch.note_aboard(convict.mind, null)
	TEST_ASSERT_NULL(state.extra["p3_held_by"], "Leaving the hull didn't end its hold")
	watch.note_aboard(convict.mind, hull)
	TEST_ASSERT(convict_ckey in hull.background_ever_crew, "A convict who left and walked back aboard free wasn't counted")

	convict.death()
	TEST_ASSERT(!background_is_free(convict), "A dead convict is free")

// ===== THE BRIG =====

/// A cell door opens for its hull's crew and nobody else; no card, item or emergency setting opens it
/datum/unit_test/voidcrew_backgrounds_hunter/brig_door

/datum/unit_test/voidcrew_backgrounds_hunter/brig_door/Run()
	var/mob/living/carbon/human/deputy = hunter_test_person("Jack Moor")
	var/mob/living/carbon/human/prisoner = hunter_test_person("Kit Vale")
	var/obj/structure/overmap/ship/hull = hunter_test_hull(list(deputy.mind))
	var/obj/machinery/door/airlock/security/glass/marshal_brig/hunter_test/door = allocate(/obj/machinery/door/airlock/security/glass/marshal_brig/hunter_test)
	door.test_ship = hull
	TEST_ASSERT_EQUAL(door.name, "brig cell", "The cell door has the wrong name")

	TEST_ASSERT(door.allowed(deputy), "The cell door refused the hull's crew")
	TEST_ASSERT(!door.allowed(prisoner), "The cell door opened for someone off the roster")
	TEST_ASSERT(!door.allowed(null), "The cell door opened for nobody at all")
	door.emergency = TRUE
	TEST_ASSERT(!door.allowed(prisoner), "Emergency access opened the cell")
	door.emergency = FALSE
	door.req_access = null
	door.req_one_access = null
	var/obj/item/card/id/advanced/gold/card = allocate(/obj/item/card/id/advanced/gold)
	TEST_ASSERT(!door.check_access(card), "A card opens the cell")
	TEST_ASSERT(!door.check_access(null), "The cell needs no access at all")

	var/obj/machinery/door/airlock/security/glass/marshal_brig/loose = allocate(/obj/machinery/door/airlock/security/glass/marshal_brig)
	TEST_ASSERT(!loose.allowed(deputy), "A cell door off any hull opened")

/// The marshal's locker holds the hull's weapons and opens for its crew only [ECO-12]
/datum/unit_test/voidcrew_backgrounds_hunter/marshal_locker

/datum/unit_test/voidcrew_backgrounds_hunter/marshal_locker/Run()
	var/mob/living/carbon/human/stranger = hunter_test_person("Lou Hale")
	var/obj/structure/closet/secure_closet/marshal_arms/locker = allocate(/obj/structure/closet/secure_closet/marshal_arms)
	TEST_ASSERT(!locker.allowed(stranger), "The marshal's locker opened off any hull")
	TEST_ASSERT(locker.locked, "The marshal's locker starts unlocked")
	locker.PopulateContents()
	var/disablers = 0
	var/flashes = 0
	var/bolas = 0
	for(var/obj/item/item in locker)
		if(istype(item, /obj/item/gun/energy/disabler))
			disablers++
		else if(istype(item, /obj/item/assembly/flash/handheld))
			flashes++
		else if(istype(item, /obj/item/restraints/legcuffs/bola))
			bolas++
		else
			TEST_FAIL("The marshal's locker holds [item.type]")
	TEST_ASSERT_EQUAL(disablers, 2, "The marshal's locker doesn't hold two disablers")
	TEST_ASSERT_EQUAL(flashes, 2, "The marshal's locker doesn't hold two flashes")
	TEST_ASSERT_EQUAL(bolas, 4, "The marshal's locker doesn't hold four bolas")

/// The hunter outfits carry no weapons [ECO-12] and cuff their wearer's belt
/datum/unit_test/voidcrew_backgrounds_hunter/outfits

/datum/unit_test/voidcrew_backgrounds_hunter/outfits/Run()
	var/list/outfit_types = list(
		/datum/outfit/job/captain/bounty_hunter,
		/datum/outfit/job/security/bounty_hunter,
		/datum/outfit/job/engineer/bounty_hunter,
		/datum/outfit/job/assistant/bounty_hunter,
	)
	for(var/outfit_type in outfit_types)
		var/datum/outfit/outfit = new outfit_type
		var/list/carried = list(outfit.uniform, outfit.suit, outfit.suit_store, outfit.belt, outfit.l_pocket, outfit.r_pocket, outfit.l_hand, outfit.r_hand, outfit.head, outfit.glasses, outfit.accessory)
		for(var/path in outfit.backpack_contents)
			carried += path
		for(var/path in outfit.belt_contents)
			carried += path
		for(var/path in carried)
			if(ispath(path, /obj/item/gun) || ispath(path, /obj/item/melee) || ispath(path, /obj/item/assembly/flash) || ispath(path, /obj/item/restraints/legcuffs))
				TEST_FAIL("[outfit_type] carries [path]")
		TEST_ASSERT_EQUAL(outfit.head, /obj/item/clothing/head/cowboy/bounty, "[outfit_type] has no bounty hat")
		TEST_ASSERT_EQUAL(outfit.glasses, /obj/item/clothing/glasses/hud/security, "[outfit_type] has no sec HUD")
		var/cuffs = (LAZYACCESS(outfit.belt_contents, /obj/item/restraints/handcuffs) || 0) + (LAZYACCESS(outfit.backpack_contents, /obj/item/restraints/handcuffs) || 0)
		TEST_ASSERT_EQUAL(cuffs, 2, "[outfit_type] doesn't carry two pairs of cuffs")
		qdel(outfit)

// ===== THE HULL (map-contracts.md M2) =====

/// Both Marshal themes carry the contract's kit: one port with a steady dock, two cryopods, the warrant console with a bolted pad beside it, the standard machines, two cell doors, the marshal's locker, and nothing forbidden
/datum/unit_test/voidcrew_marshal_hull
	priority = TEST_LONGER

/datum/unit_test/voidcrew_marshal_hull/Run()
	ensure_ship_upgrades_initialized()
	var/list/templates = vc_test_voidcrew_hull_templates()
	var/datum/map_template/shuttle/voidcrew/hull = templates[/datum/map_template/shuttle/voidcrew/marshal]
	TEST_ASSERT_NOTNULL(hull, "The Marshal-class hull template isn't registered")
	TEST_ASSERT_EQUAL(hull.background_start, "bounty_hunter", "The Marshal-class isn't the bounty hunter start") // BACKGROUND_BOUNTY_HUNTER
	var/list/themes = GLOB.ship_themes[hull.type]
	for(var/theme_id in list("lawman", "bondsman"))
		TEST_ASSERT(theme_id in themes, "The Marshal-class has no [theme_id] theme")
	for(var/theme_id in themes)
		var/datum/ship_theme/theme = themes[theme_id]
		check_crew(theme)
		var/map_path = "[hull.prefix]ship_[theme.template_suffix].dmm"
		var/datum/vc_test_dmm/map = vc_test_parse_dmm(map_path)
		if(!map)
			TEST_FAIL("[map_path] is missing or unreadable")
			continue
		check_hull_map(hull, theme, theme_id, map)

/// The theme's crew: the Marshal first and in command, every hunter outfit present
/datum/unit_test/voidcrew_marshal_hull/proc/check_crew(datum/ship_theme/theme)
	var/list/slots = theme.job_slots
	if(!length(slots))
		TEST_FAIL("The [theme.id] theme has no crew")
		return
	var/list/first = slots[1]
	if(first["outfit"] != /datum/outfit/job/captain/bounty_hunter || !first["officer"])
		TEST_FAIL("The [theme.id] theme's first job isn't the Marshal in command")
	var/list/outfits = list()
	for(var/list/slot as anything in slots)
		outfits += slot["outfit"]
	for(var/outfit_type in list(/datum/outfit/job/security/bounty_hunter, /datum/outfit/job/engineer/bounty_hunter, /datum/outfit/job/assistant/bounty_hunter))
		if(!(outfit_type in outfits))
			TEST_FAIL("The [theme.id] theme has no job wearing [outfit_type]")

/datum/unit_test/voidcrew_marshal_hull/proc/check_hull_map(datum/map_template/shuttle/voidcrew/hull, datum/ship_theme/theme, theme_id, datum/vc_test_dmm/map)
	var/where = map.map_path

	var/list/ports = map.find_instances("/obj/docking_port/mobile/")
	if(length(ports) != 1)
		TEST_FAIL("[where] places [length(ports)] mobile docking ports, not one")
	else
		check_dock_rotation(where, ports[1][3], map)

	if(length(map.find_instances("/obj/machinery/cryopod")) < 2)
		TEST_FAIL("[where] has fewer than two cryopods")
	if(length(map.find_instances("/obj/machinery/door/airlock/security/glass/marshal_brig")) != 2)
		TEST_FAIL("[where] doesn't have exactly two brig cell doors")
	if(length(map.find_instances("/obj/structure/closet/secure_closet/marshal_arms")) != 1)
		TEST_FAIL("[where] doesn't have exactly one marshal's locker")

	var/list/consoles = map.find_instances("/obj/machinery/computer/mission_board/bounty")
	if(length(consoles) != 1)
		TEST_FAIL("[where] doesn't have exactly one warrant console")
	else
		var/list/console = consoles[1]
		var/pad_ok = FALSE
		for(var/list/pad as anything in map.find_instances("/obj/machinery/mission_pad"))
			if(!vc_test_entry_boolean(pad[3], "anchored", TRUE))
				continue
			if(max(abs(pad[1] - console[1]), abs(pad[2] - console[2])) <= 3)
				pad_ok = TRUE
		if(!pad_ok)
			TEST_FAIL("[where] has no bolted mission pad within 3 tiles of the warrant console")

	var/static/list/standard = list(
		/obj/machinery/computer/bank_machine = "bank machine",
		/obj/machinery/computer/voidcrew_cargo = "cargo console",
		/obj/item/storage/box/rndboards/all = "R&D board kit",
		/obj/machinery/holopad = "holopad",
		/obj/machinery/computer/helm = "helm",
	)
	for(var/path in standard)
		if(length(map.find_instances("[path]")))
			continue
		if(slot_guarantees(hull, theme, theme_id, path))
			continue
		TEST_FAIL("[where] has no [standard[path]] and no slot guarantees one")

	var/list/markers = map.find_instances("/obj/modular_map_root/ship_upgrade")
	var/marker_ok = FALSE
	for(var/list/marker as anything in markers)
		if(findtext(vc_test_entry_var(marker[3], "key"), "marshal_bay"))
			marker_ok = TRUE
	if(!marker_ok)
		TEST_FAIL("[where] has no marshal_bay slot marker")

	check_forbidden(map)
	for(var/slot_key in get_upgrade_slot_ids_for_theme(hull, theme))
		for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(hull.type, theme_id, slot_key))
			var/datum/vc_test_dmm/module_map = vc_test_parse_dmm(module_map_path(module, theme_id))
			if(!module_map)
				TEST_FAIL("[module.id]'s map is missing or unreadable")
				continue
			check_forbidden(module_map)
			for(var/path in list("/obj/machinery/cryopod", "/obj/machinery/computer/helm", "/obj/docking_port"))
				if(length(module_map.find_instances(path)))
					TEST_FAIL("[module_map.map_path] places [path], which belongs to the hull")

/// The module's themed map if it has one, else its base map
/datum/unit_test/voidcrew_marshal_hull/proc/module_map_path(datum/ship_upgrade_module/module, theme_id)
	var/themed = "[HUNTER_TEST_MODULE_ROOT][vc_test_themed_module_filename(module.map_file, theme_id)]"
	if(fexists(themed))
		return themed
	return "[HUNTER_TEST_MODULE_ROOT][module.map_file]"

/// Whether every module that can fill one of the theme's slots carries `path`
/datum/unit_test/voidcrew_marshal_hull/proc/slot_guarantees(datum/map_template/shuttle/voidcrew/hull, datum/ship_theme/theme, theme_id, path)
	for(var/slot_key in get_upgrade_slot_ids_for_theme(hull, theme))
		var/list/candidates = get_modules_for_ship_slot(hull.type, theme_id, slot_key)
		if(!length(candidates))
			continue
		var/all_carry = TRUE
		for(var/datum/ship_upgrade_module/module as anything in candidates)
			var/text = vc_test_file_text(module_map_path(module, theme_id))
			if(!text || !vc_test_map_has_path(text, path))
				all_carry = FALSE
				break
		if(all_carry)
			return TRUE
	return FALSE

/// No weapons, armor or ammo on the map (the marshal's locker stocks itself), no tracking implants [TEL-3], no combat kit
/datum/unit_test/voidcrew_marshal_hull/proc/check_forbidden(datum/vc_test_dmm/map)
	var/static/list/forbidden = list(
		"/obj/item/gun",
		"/obj/item/ammo_box",
		"/obj/item/ammo_casing",
		"/obj/item/melee",
		"/obj/item/clothing/suit/armor",
		"/obj/item/assembly/flash",
		"/obj/item/restraints/legcuffs",
		"/obj/item/implant/tracking",
		"/obj/item/implanter/tracking",
		"/obj/item/implantcase/tracking",
		"/obj/machinery/ship_combat",
		"/obj/machinery/porta_turret",
		"/obj/machinery/power/smes/magical",
	)
	for(var/path in forbidden)
		if(length(map.find_instances(path)))
			TEST_FAIL("[map.map_path] places [path]")

/// The hull's preferred_direction matches adjust_reserve_dock_to_shuttle()'s aspect guess (voidcrew_hull_dock_rotation, for a hull off the shelf)
/datum/unit_test/voidcrew_marshal_hull/proc/check_dock_rotation(where, entry, datum/vc_test_dmm/map)
	var/obj/docking_port/mobile/port_type = vc_test_entry_type(entry)
	if(!ispath(port_type, /obj/docking_port/mobile/voidcrew/marshal))
		TEST_FAIL("[where]'s docking port is [port_type], not a Marshal-class port")
		return
	var/mapped_dir = vc_test_entry_dir(entry)
	var/port_width = map.width
	var/port_height = map.height
	if(mapped_dir & (EAST|WEST))
		port_width = map.height
		port_height = map.width
	var/true_height = port_height
	var/true_width = port_width
	if(initial(port_type.port_direction) & (EAST|WEST))
		true_height = port_width
		true_width = port_height
	var/aspect_guess = (true_height > true_width) ? EAST : NORTH
	if(initial(port_type.preferred_direction) != aspect_guess)
		TEST_FAIL("[port_type]: preferred_direction [initial(port_type.preferred_direction)] doesn't match the [aspect_guess] guessed for [where]; the hull would turn on every dock")

#undef HUNTER_TEST_MODULE_ROOT
