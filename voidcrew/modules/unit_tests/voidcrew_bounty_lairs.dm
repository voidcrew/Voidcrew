// Owner: P10. Bounty lair tests.

/**
 * # Bounty lairs: kill-only postings, lair sites, gates and the lich (P10)
 *
 * Tests for voidcrew/modules/bounties/bounty_lair.dm and its hooks. Fork defines compile after the tests, so a test
 * uses the literal value with a comment naming the define. P5's board fixtures (voidcrew_bounty_board.dm) stop the
 * board's clock and empty it around each test, and the lair clock never posts on its own in tests
 * (SSbounty_lairs.lair_auto_post). A lair's interior is either a footprint drawn over the test floor, or the real
 * Club Volga loaded through the lair.
 */

/// The lair tests: the board stopped and emptied around each one, and whatever a test made taken down after it
/datum/unit_test/voidcrew_bounty_lairs
	abstract_type = /datum/unit_test/voidcrew_bounty_lairs
	/// Lairs whose map zone and footprint were faked by the test: never torn down for real
	var/list/obj/structure/overmap/space_ruin/bounty_lair/lair_test_fakes = list()
	/// Anything else the test made outside allocate() (landmarks survive the test floor's sweep, lairs and lich lairs live on the overmap)
	var/list/atom/lair_test_made = list()

/datum/unit_test/voidcrew_bounty_lairs/New()
	. = ..()
	board_test_begin()

/datum/unit_test/voidcrew_bounty_lairs/Destroy()
	// A faked interior must never reach a real teardown: drop it before the bounties close
	for(var/obj/structure/overmap/space_ruin/bounty_lair/lair as anything in lair_test_fakes)
		if(QDELETED(lair))
			continue
		lair.cancel_despawn_timer()
		lair.mapzone = null
		lair.footprint = null
		lair.loaded = FALSE
	board_test_end()
	for(var/atom/made as anything in lair_test_fakes + lair_test_made)
		if(!QDELETED(made))
			qdel(made)
	lair_test_fakes = null
	lair_test_made = null
	for(var/id in SSbounty_lairs.lair_kinds())
		var/datum/bounty_lair_kind/kind = SSbounty_lairs.lair_kinds[id]
		kind.lair_next_due = null
		kind.lair_disabled = FALSE
	return ..()

/// A kill-only posting made by hand with no site: `value` credits and `vouchers` vouchers on its trophy, in green space
/datum/unit_test/voidcrew_bounty_lairs/proc/test_posting(value = 5000, vouchers = 3, posting_type = /datum/criminal_bounty/kill_only)
	var/datum/criminal_bounty/kill_only/posting = new posting_type
	posting.record = bounty_kill_record("Test Boss", "testing", MALE, value, "test")
	posting.placement_kind = "ruin" // BOUNTY_PLACEMENT_RUIN
	posting.value = value
	posting.board_vouchers = vouchers
	posting.board_zone = 1 // ZONE_GREEN
	posting.expires_at = world.time + 60 MINUTES
	posting.board_gps_tag = "WANTED-[posting.record.id]"
	GLOB.criminal_bounties += posting
	return posting

/// Living mobs of `mob_type` inside `footprint`
/datum/unit_test/voidcrew_bounty_lairs/proc/test_count(mob_type, datum/map_footprint/footprint)
	var/count = 0
	for(var/mob/living/found as anything in GLOB.mob_living_list)
		if(istype(found, mob_type) && found.stat != DEAD && footprint.contains_turf(get_turf(found)))
			count++
	return count

/// The Club Volga lair kind
/datum/unit_test/voidcrew_bounty_lairs/proc/test_club_kind()
	var/list/kinds = SSbounty_lairs.lair_kinds()
	return kinds["mafia_club"]

/// A lair bound to `posting` whose "interior" is the west `width` columns of the test floor, loaded but never torn down
/datum/unit_test/voidcrew_bounty_lairs/proc/test_fake_lair(datum/criminal_bounty/kill_only/lair/posting, width = 3)
	var/turf/origin = run_loc_floor_bottom_left
	var/obj/structure/overmap/space_ruin/bounty_lair/lair = allocate(/obj/structure/overmap/space_ruin/bounty_lair)
	lair_test_fakes += lair
	lair.lair_bind_posting(posting)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = origin.z
	footprint.set_rect(origin.x, origin.y, width, 5)
	lair.footprint = footprint
	lair.loaded = TRUE
	return lair

/// Sends the load signal to `lair` and waits for it to finish linking
/datum/unit_test/voidcrew_bounty_lairs/proc/test_link(obj/structure/overmap/space_ruin/bounty_lair/lair)
	SEND_SIGNAL(lair, "voidcrew_planet_loaded", TRUE) // COMSIG_VOIDCREW_PLANET_LOADED
	var/deadline = world.time + 10 SECONDS
	UNTIL(lair.lair_link_done || world.time >= deadline)
	return lair.lair_link_done

// ===== KILL-ONLY POSTINGS =====

/// A kill-only bounty pays 100% on its trophy at a pad, pays nothing for anything else, and makes no prisoner record
/datum/unit_test/voidcrew_bounty_lairs/kill_only

/datum/unit_test/voidcrew_bounty_lairs/kill_only/Run()
	var/turf/pad_turf = run_loc_floor_bottom_left
	var/turf/aside = locate(pad_turf.x + 2, pad_turf.y, pad_turf.z)
	var/obj/machinery/mission_pad/pad = allocate(/obj/machinery/mission_pad, pad_turf)
	var/obj/structure/overmap/ship/ship = board_test_ship()
	var/datum/criminal_bounty/kill_only/posting = test_posting(5000, 3)

	// Dead or nothing: no capture state pays
	for(var/state in list("restrained", "stunned", "downed", "free")) // BOUNTY_STATE_*
		TEST_ASSERT_EQUAL(posting.board_share_for(state, state), 0, "A kill-only bounty pays for a [state] boss")
	TEST_ASSERT_EQUAL(posting.board_share_for("dead", "dead"), 100, "A kill-only bounty doesn't pay in full on the kill") // BOUNTY_STATE_DEAD

	// The card says wanted dead, with the full value as its one figure; the warrant says WANTED: DEAD
	var/list/card = posting.board_ui_entry(ship, pad)
	TEST_ASSERT_EQUAL(card["terms"], "Wanted dead", "The card doesn't say wanted dead")
	TEST_ASSERT_EQUAL(card["value"], 5000, "The card's pay figure isn't the full value")
	TEST_ASSERT(findtext(posting.board_warrant_text(), "WANTED: DEAD"), "The warrant doesn't say WANTED: DEAD")

	// The pad never takes the boss, alive or dead, even one wanted on this very bounty: only its trophy
	var/mob/living/basic/bounty_lair_boss/boss = allocate(/mob/living/basic/bounty_lair_boss, pad_turf)
	boss.posting_ref = WEAKREF(posting)
	boss.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/list/found = list()
	TEST_ASSERT(istext(posting.board_target_refusal(pad, found)), "The pad took a boss standing on it")
	boss.death()
	TEST_ASSERT(istext(posting.board_target_refusal(pad, found)), "The pad took a boss's body")
	var/list/preview = posting.board_pad_preview(ship, pad)
	TEST_ASSERT(!preview[1], "The card offers to turn in a body")

	// The trophy drops where the boss fell, bound to the bounty, and there is only ever one
	var/obj/item/bounty_proof/trophy/trophy = posting.kill_drop_trophy(aside)
	TEST_ASSERT_NOTNULL(trophy, "The kill dropped no trophy")
	TEST_ASSERT_EQUAL(trophy.loc, aside, "The trophy isn't where the boss fell")
	TEST_ASSERT_EQUAL(trophy.posting_ref?.resolve(), posting, "The trophy isn't bound to its bounty")
	TEST_ASSERT_EQUAL(posting.board_proof(), trophy, "The trophy isn't the bounty's proof")
	TEST_ASSERT_EQUAL(posting.kill_drop_trophy(pad_turf), trophy, "A second kill dropped a second trophy")
	TEST_ASSERT(istext(posting.board_target_refusal(pad, found)), "The pad took a trophy lying beside it")

	// Another bounty's trophy on the pad is not this one's
	var/datum/criminal_bounty/kill_only/other = test_posting(1000, 0)
	var/obj/item/bounty_proof/trophy/other_trophy = other.kill_drop_trophy(pad_turf)
	TEST_ASSERT(istext(posting.board_target_refusal(pad, found)), "The pad took another bounty's trophy")

	// On the pad: the full value and the vouchers, and the record goes nowhere
	trophy.forceMove(pad_turf)
	// (Whether the card offers the turn-in also needs the pad aboard the ship, which this bare pad isn't: P5's rule.)
	preview = posting.board_pad_preview(ship, pad)
	TEST_ASSERT_EQUAL(preview[2], "trophy", "The card doesn't show the trophy on the pad")
	found = list()
	TEST_ASSERT_NULL(posting.board_target_refusal(pad, found), "The pad refused the trophy")
	TEST_ASSERT_EQUAL(found["target"], trophy, "The pad picked something other than the trophy")
	var/datum/bounty_record/record = posting.record
	var/pool_before = length(GLOB.bounty_prisoner_pool)
	var/balance_before = ship.ship_account.account_balance
	var/list/paid = posting.board_claim(ship, pad, found["target"], found["state"])
	TEST_ASSERT(islist(paid), "The trophy was refused: [paid]")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance - balance_before, 5000, "The trophy didn't pay the full value")
	TEST_ASSERT_EQUAL(board_test_vouchers(pad_turf), 3, "The trophy didn't pay its vouchers")
	TEST_ASSERT(QDELETED(trophy), "The pad left the trophy behind")
	TEST_ASSERT(QDELETED(posting), "The bounty stayed up after its trophy was turned in")
	TEST_ASSERT_EQUAL(length(GLOB.bounty_prisoner_pool), pool_before, "A kill-only bounty made a prisoner record")
	TEST_ASSERT(!(record in GLOB.bounty_prisoner_pool), "The boss's record went to the prisoner pool")
	TEST_ASSERT_EQUAL(record.status, "dead", "The boss's record isn't closed as dead") // BOUNTY_RECORD_DEAD
	TEST_ASSERT(!QDELETED(other_trophy) && other.is_open(), "Turning one bounty in touched another's trophy")

	// A trophy the boss's death made for itself, bound only by its ref, is taken as well
	var/datum/criminal_bounty/kill_only/third = test_posting(2000, 1)
	var/obj/item/bounty_proof/trophy/made = new(pad_turf)
	made.posting_ref = WEAKREF(third)
	found = list()
	TEST_ASSERT_NULL(third.board_target_refusal(pad, found), "The pad refused a trophy bound to the bounty")
	TEST_ASSERT_EQUAL(found["target"], made, "The pad picked something other than the bound trophy")
	balance_before = ship.ship_account.account_balance
	TEST_ASSERT(islist(third.board_claim(ship, pad, found["target"], found["state"])), "The bound trophy was refused")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance - balance_before, 2000, "The bound trophy didn't pay the full value")

	// A kill-only bounty's site is fixed: losing its trophy ends it rather than moving it
	qdel(other_trophy)
	sleep(2 SECONDS)
	TEST_ASSERT(QDELETED(other), "A kill-only bounty stayed up after its trophy was destroyed")

// ===== LAIR SITES =====

/// A lair is spawned for its posting, rare, mission-locked, claimed, one of a kind at a time, and let go when the posting closes
/datum/unit_test/voidcrew_bounty_lairs/site

/datum/unit_test/voidcrew_bounty_lairs/site/Run()
	var/datum/bounty_lair_kind/kind = test_club_kind()
	TEST_ASSERT_NOTNULL(kind, "There is no Club Volga lair kind")
	TEST_ASSERT_NOTNULL(kind.find_template(), "The Club Volga template is not registered")
	var/datum/criminal_bounty/kill_only/lair/posting = bounty_post_lair(kind, 2) // ZONE_YELLOW
	TEST_ASSERT_NOTNULL(posting, "The Club Volga lair was not posted")
	var/obj/structure/overmap/space_ruin/bounty_lair/lair = posting.site()
	TEST_ASSERT(istype(lair), "The lair posting's site is not a lair")
	lair_test_made += lair

	// Spawned for it: rare, locked, claimed, and nobody else's site
	TEST_ASSERT_EQUAL(lair.ruin_template?.type, /datum/map_template/ruin/space/bounty_lair/mafia_club, "The lair didn't get the Club Volga template")
	TEST_ASSERT(lair.rare, "The lair is not rare, so cleaning it up would spawn a replacement")
	TEST_ASSERT(lair.mission_locked, "The lair is not mission-locked")
	TEST_ASSERT(lair.mission_exclusive, "Contracts may aim at the lair")
	TEST_ASSERT_EQUAL(lair.mission_claims, 1, "The lair doesn't carry its posting's claim")
	TEST_ASSERT_EQUAL(lair.posting_ref?.resolve(), posting, "The lair isn't bound to its posting")
	TEST_ASSERT_EQUAL(posting.board_site_name, "Club Volga", "The card doesn't name the club")

	// Yellow or red space; 4800-5600 times the zone, 3 vouchers and red +1 (BOUNTY_PAY_LAIR_MIN/_MAX, BOUNTY_VOUCHERS_LAIR)
	TEST_ASSERT(posting.board_zone in list(2, 3), "The club is not in yellow or red space") // ZONE_YELLOW, ZONE_RED
	var/mult = posting.board_zone == 3 ? 2.6 : 1.7 // BOUNTY_ZONE_MULT_RED, _YELLOW
	TEST_ASSERT(posting.value >= round(4800 * mult, 10) && posting.value <= round(5600 * mult, 10), "The club pays [posting.value] in zone [posting.board_zone]")
	TEST_ASSERT_EQUAL(posting.board_vouchers, posting.board_zone == 3 ? 4 : 3, "The club doesn't pay its vouchers")
	TEST_ASSERT_EQUAL(posting.kill_trophy_type, /obj/item/bounty_proof/trophy/mafia_don, "The club's trophy isn't the don's")
	TEST_ASSERT(posting.record?.mugshot, "The club's card has no picture")

	// One of a kind, and it doesn't take a public slot
	TEST_ASSERT_EQUAL(kind.live(), posting, "The kind doesn't know its lair is up")
	TEST_ASSERT_NULL(bounty_post_lair(kind, 2), "A second Club Volga went up while one is live")
	TEST_ASSERT_EQUAL(SScriminal_bounties.board_public_count(), 0, "The lair took one of the board's public slots")

	// Hunting it charts the lair on the helm
	var/obj/structure/overmap/ship/ship = board_test_ship()
	TEST_ASSERT_EQUAL(posting.hunt(ship), TRUE, "A ship could not hunt the lair")
	TEST_ASSERT(ship.get_waypoint(posting.board_waypoint_key()), "Hunting the lair charted no waypoint")

	// A lair nobody boarded goes once its bounty closes (a tick later, when the posting's claim is off it), and the
	// next of its kind waits 60-90 minutes
	posting.close("admin") // BOUNTY_CLOSE_ADMIN
	TEST_ASSERT(!lair.mission_locked, "Closing the bounty didn't unlock its lair")
	TEST_ASSERT_EQUAL(lair.mission_claims, 0, "The closed bounty still claims its lair")
	var/deadline = world.time + 5 SECONDS
	UNTIL(QDELETED(lair) || world.time >= deadline)
	TEST_ASSERT(QDELETED(lair), "A lair that never loaded stayed on the chart after its bounty closed")
	TEST_ASSERT_NULL(kind.live(), "The kind still counts a closed lair as up")
	TEST_ASSERT(kind.lair_next_due >= world.time + 60 MINUTES && kind.lair_next_due <= world.time + 90 MINUTES, "The next lair isn't due 60-90 minutes after the last closed") // BOUNTY_LAIR_GAP_MIN/_MAX

	// A loaded lair: held while its bounty is open, handed to cleanup when it closes, never torn down with someone inside
	posting = bounty_post_lair(kind, 2)
	TEST_ASSERT_NOTNULL(posting, "A second lair could not be posted after the first closed")
	lair = posting.site()
	lair_test_fakes += lair
	var/turf/inside = run_loc_floor_bottom_left
	var/datum/map_zone/zone = allocate(/datum/map_zone)
	zone.z_levels = list(reservation)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = inside.z
	footprint.set_rect(inside.x, inside.y, 1, 1)
	lair.mapzone = zone
	lair.footprint = footprint
	lair.loaded = TRUE
	lair.check_start_despawn()
	TEST_ASSERT_NULL(lair.despawn_timer_id, "A lair with an open bounty armed cleanup")
	lair.check_and_respawn()
	TEST_ASSERT(lair.loaded && lair.mapzone == zone, "A lair with an open bounty was cleaned up")
	TEST_ASSERT(istext(lair.admin_unload_blocker()), "Overmap Management may unload a lair with an open bounty")
	var/mob/living/basic/body = allocate(/mob/living/basic, inside)
	body.mind_initialize()
	posting.close("admin") // BOUNTY_CLOSE_ADMIN
	TEST_ASSERT(!lair.mission_locked, "Closing the bounty didn't unlock its lair")
	sleep(1 SECONDS)
	TEST_ASSERT(!QDELETED(lair) && lair.mapzone == zone, "The lair was torn down with someone inside")
	TEST_ASSERT(length(lair.admin_cleanup_timers()), "The released lair never tries its cleanup again")

/// The lair clock: the first lair 45-60 minutes in, only with 3 or more crews out, one of a kind at a time
/datum/unit_test/voidcrew_bounty_lairs/clock

/datum/unit_test/voidcrew_bounty_lairs/clock/Run()
	var/datum/bounty_lair_kind/kind = test_club_kind()
	kind.lair_next_due = null
	var/datum/criminal_bounty/kill_only/lair/early = kind.lair_maybe_post(SSticker.round_start_time, 10)
	TEST_ASSERT_NULL(early, "A lair went up at the start of the round")
	// BOUNTY_LAIR_FIRST_AFTER 45 minutes, BOUNTY_LAIR_FIRST_SPREAD 15 minutes
	TEST_ASSERT(kind.lair_next_due >= SSticker.round_start_time + 45 MINUTES && kind.lair_next_due <= SSticker.round_start_time + 60 MINUTES, "The first lair isn't due 45-60 minutes in")

	kind.lair_next_due = world.time - 1
	TEST_ASSERT_NULL(kind.lair_maybe_post(world.time, 2), "A lair went up with two crews out") // BOUNTY_LAIR_MIN_SHIPS 3
	var/datum/criminal_bounty/kill_only/lair/posting = kind.lair_maybe_post(world.time, 3)
	TEST_ASSERT_NOTNULL(posting, "No lair went up when one was due with three crews out")
	lair_test_made += posting.site()
	kind.lair_next_due = world.time - 1
	TEST_ASSERT_NULL(kind.lair_maybe_post(world.time, 10), "A second lair of the kind went up while one is live")
	posting.close("admin") // BOUNTY_CLOSE_ADMIN
	TEST_ASSERT_NULL(kind.lair_maybe_post(world.time, 10), "The next lair went up right after the last one closed")

	// The clock itself does nothing in tests
	TEST_ASSERT(!SSbounty_lairs.lair_auto_post, "The lair clock posts on its own in tests")

/// Indexing the interior: once per load, the boss and gatekeepers spawned, the gate only when every gatekeeper is dead and only inside the footprint, and the trophy where the boss fell
/datum/unit_test/voidcrew_bounty_lairs/link

/datum/unit_test/voidcrew_bounty_lairs/link/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/datum/criminal_bounty/kill_only/lair/posting = test_posting(5000, 3, /datum/criminal_bounty/kill_only/lair)
	// The lair's footprint is the west three columns of the floor; the east two are someone else's
	var/obj/structure/overmap/space_ruin/bounty_lair/lair = test_fake_lair(posting, 3)
	var/datum/map_footprint/footprint = lair.footprint

	var/turf/boss_spot = locate(origin.x, origin.y + 4, origin.z)
	var/obj/effect/landmark/bounty_lair_boss/boss_mark = new(boss_spot)
	boss_mark.boss_type = /mob/living/basic/mouse
	lair_test_made += boss_mark
	var/list/keeper_marks = list()
	for(var/offset in 1 to 2)
		var/obj/effect/landmark/bounty_lair_gatekeeper/keeper_mark = new(locate(origin.x + offset, origin.y + 2, origin.z))
		keeper_mark.gatekeeper_type = /mob/living/basic/mouse
		keeper_marks += keeper_mark
		lair_test_made += keeper_mark
	var/obj/machinery/door/poddoor/gate = allocate(/obj/machinery/door/poddoor, locate(origin.x + 1, origin.y, origin.z))
	gate.id = "bounty_lair_gate" // BOUNTY_LAIR_GATE_ID
	var/obj/machinery/door/poddoor/outside_gate = allocate(/obj/machinery/door/poddoor, locate(origin.x + 4, origin.y, origin.z))
	outside_gate.id = "bounty_lair_gate" // BOUNTY_LAIR_GATE_ID

	// The load: indexed, the boss and the gatekeepers spawned on their landmarks, the gate found
	SEND_SIGNAL(lair, "voidcrew_planet_loaded", TRUE) // COMSIG_VOIDCREW_PLANET_LOADED
	TEST_ASSERT(lair.lair_linked, "The lair didn't start linking on its load")
	var/deadline = world.time + 10 SECONDS
	UNTIL(lair.lair_link_done || world.time >= deadline)
	TEST_ASSERT(lair.lair_link_done, "The lair never finished linking")
	TEST_ASSERT(QDELETED(boss_mark), "The boss landmark was left behind")
	for(var/obj/effect/landmark/bounty_lair_gatekeeper/keeper_mark as anything in keeper_marks)
		TEST_ASSERT(QDELETED(keeper_mark), "A gatekeeper landmark was left behind")
	TEST_ASSERT_EQUAL(length(lair.lair_bosses), 1, "The lair isn't watching one boss")
	var/datum/weakref/boss_ref = lair.lair_bosses[1]
	var/mob/living/basic/mouse/boss = boss_ref.resolve()
	TEST_ASSERT(istype(boss), "The boss landmark didn't spawn its boss type")
	TEST_ASSERT_EQUAL(get_turf(boss), boss_spot, "The boss didn't spawn on its landmark")
	TEST_ASSERT_EQUAL(length(lair.lair_gatekeepers), 2, "The lair isn't watching two gatekeepers")
	TEST_ASSERT_EQUAL(length(lair.lair_gate_doors), 1, "The lair's gate took a door outside its footprint, or missed its own")
	var/list/keepers = list()
	for(var/datum/weakref/ref as anything in lair.lair_gatekeepers)
		keepers += ref.resolve()
	for(var/mob/living/basic/mouse/lair_mob as anything in keepers + boss)
		lair_mob.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/mice = test_count(/mob/living/basic/mouse, footprint)
	TEST_ASSERT_EQUAL(mice, 3, "The lair spawned [mice] mobs, not a boss and two gatekeepers")

	// A second load signal does nothing
	SEND_SIGNAL(lair, "voidcrew_planet_loaded", TRUE) // COMSIG_VOIDCREW_PLANET_LOADED
	sleep(1)
	TEST_ASSERT_EQUAL(test_count(/mob/living/basic/mouse, footprint), mice, "A second load signal spawned the lair's mobs again")

	// A polymorph or a type change deletes a mob without a death: the lair's mobs refuse both, so neither opens the gate
	var/mob/living/first_keeper = keepers[1]
	var/mob/living/second_keeper = keepers[2]
	first_keeper.wabbajack()
	TEST_ASSERT(!QDELETED(first_keeper), "A polymorph took a gatekeeper away")
	second_keeper.change_mob_type(/mob/living/basic/cow, delete_old_mob = TRUE)
	TEST_ASSERT(!QDELETED(second_keeper), "A type change took a gatekeeper away")
	boss.wabbajack()
	TEST_ASSERT(!QDELETED(boss), "A polymorph took the boss away")
	TEST_ASSERT(!lair.lair_gate_open, "Polymorph or a type change opened the gate")
	TEST_ASSERT_EQUAL(test_count(/mob/living/basic/mouse, footprint), mice, "Polymorph or a type change replaced a lair mob")

	// The gate: shut while one gatekeeper stands, open once both are gone (one dead, one deleted), and only in the lair
	first_keeper.death()
	TEST_ASSERT(!lair.lair_gate_open, "The gate opened with a gatekeeper still standing")
	TEST_ASSERT(gate.density, "The gate door opened with a gatekeeper still standing")
	qdel(second_keeper)
	TEST_ASSERT(lair.lair_gate_open, "The gate didn't open when the last gatekeeper went")
	sleep(3 SECONDS)
	TEST_ASSERT(!gate.density, "The lair's gate door didn't open")
	TEST_ASSERT(outside_gate.density, "A door with the gate's id outside the lair opened")

	// The boss falls and nothing takes over from it: the trophy drops where it fell
	var/turf/fell = get_turf(boss)
	boss.death()
	sleep(6 SECONDS) // BOUNTY_LAIR_TROPHY_GRACE 5 seconds
	TEST_ASSERT(lair.lair_boss_killed, "The lair doesn't know its boss is dead")
	var/obj/item/bounty_proof/trophy/trophy = posting.board_proof()
	TEST_ASSERT(istype(trophy), "No trophy dropped when the boss died")
	TEST_ASSERT_EQUAL(trophy.loc, fell, "The trophy isn't where the boss fell")
	TEST_ASSERT_EQUAL(trophy.posting_ref?.resolve(), posting, "The trophy isn't bound to the lair's bounty")

	// Closing the bounty lets the lair go and stops it listening (the faked footprint is dropped first: it holds no slot)
	lair.footprint = null
	lair.loaded = FALSE
	posting.close("admin") // BOUNTY_CLOSE_ADMIN
	TEST_ASSERT(QDELETED(trophy), "The trophy of a closed bounty was left in the world")
	TEST_ASSERT(!lair.mission_locked, "Closing the bounty didn't unlock its lair")
	TEST_ASSERT_NULL(lair.posting_ref, "The released lair still points at its bounty")

/// The boss's next phase takes over from it; a boss deleted alive (an admin) ends the bounty instead of paying out
/datum/unit_test/voidcrew_bounty_lairs/phases

/datum/unit_test/voidcrew_bounty_lairs/phases/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/datum/criminal_bounty/kill_only/lair/posting = test_posting(5000, 3, /datum/criminal_bounty/kill_only/lair)
	var/obj/structure/overmap/space_ruin/bounty_lair/lair = test_fake_lair(posting, 3)
	var/obj/effect/landmark/bounty_lair_boss/boss_mark = new(locate(origin.x, origin.y + 4, origin.z))
	boss_mark.boss_type = /mob/living/basic/mouse
	lair_test_made += boss_mark
	TEST_ASSERT(test_link(lair), "The lair never finished linking")
	var/datum/weakref/boss_ref = lair.lair_bosses[1]
	var/mob/living/basic/mouse/first_phase = boss_ref.resolve()
	first_phase.ai_controller?.set_ai_status(AI_STATUS_OFF)

	// The mech hands over to the don as it breaks (P12's signal): he is taken on at once
	var/mob/living/basic/mouse/second_phase = allocate(/mob/living/basic/mouse, locate(origin.x + 1, origin.y + 4, origin.z))
	second_phase.ai_controller?.set_ai_status(AI_STATUS_OFF)
	SEND_SIGNAL(first_phase, "bounty_mafia_don_ejected", second_phase) // COMSIG_BOUNTY_MAFIA_DON_EJECTED
	TEST_ASSERT_EQUAL(length(lair.lair_bosses), 2, "The lair didn't take on the boss's next phase")
	first_phase.death()
	sleep(6 SECONDS) // BOUNTY_LAIR_TROPHY_GRACE 5 seconds
	TEST_ASSERT(!lair.lair_boss_killed, "The lair called the fight over with the next phase still standing")
	TEST_ASSERT_NULL(posting.board_proof(), "A trophy dropped with the next phase still standing")

	// The next phase is deleted alive: nobody earned a trophy, and nothing can finish the bounty, so it closes
	qdel(second_phase)
	sleep(6 SECONDS) // BOUNTY_LAIR_TROPHY_GRACE 5 seconds
	TEST_ASSERT(QDELETED(posting), "The bounty stayed up after its boss was deleted alive")
	for(var/obj/item/bounty_proof/trophy/stray in range(5, origin))
		TEST_FAIL("A boss deleted alive dropped a trophy at ([stray.x],[stray.y])")

/// The room leash: a lair mob won't walk out of its room, but is moved when pulled or thrown, and walks freely once out
/datum/unit_test/voidcrew_bounty_lairs/leash
	/// The tiles the test turned into another room, and the room they came from
	var/list/turf/leash_test_turfs = list()
	var/area/leash_test_home
	var/area/overmap_encounter/planet_ruin/leash_test_room

/datum/unit_test/voidcrew_bounty_lairs/leash/Destroy()
	for(var/turf/tile as anything in leash_test_turfs)
		tile.change_area(leash_test_room, leash_test_home)
	leash_test_turfs = null
	QDEL_NULL(leash_test_room)
	leash_test_home = null
	return ..()

/datum/unit_test/voidcrew_bounty_lairs/leash/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/home_spot = locate(origin.x + 1, origin.y + 1, origin.z)
	var/turf/door_spot = locate(origin.x + 2, origin.y + 1, origin.z)
	var/turf/far_spot = locate(origin.x + 3, origin.y + 1, origin.z)
	// The east tiles become another room
	leash_test_home = get_area(home_spot)
	leash_test_room = new
	for(var/turf/tile as anything in list(door_spot, far_spot))
		tile.change_area(leash_test_home, leash_test_room)
		leash_test_turfs += tile

	var/mob/living/basic/goon = allocate(/mob/living/basic, home_spot)
	goon.AddElement(/datum/element/bounty_lair_room_leash, leash_test_home.type)

	// It won't step out of its room
	goon.Move(door_spot, EAST)
	TEST_ASSERT_EQUAL(get_turf(goon), home_spot, "A leashed mob walked out of its room")

	// Pulled, it goes: a player in the next room drags it through
	var/mob/living/carbon/human/consistent/puller = allocate(/mob/living/carbon/human/consistent, door_spot)
	puller.start_pulling(goon)
	TEST_ASSERT_EQUAL(goon.pulledby, puller, "The test couldn't pull the leashed mob")
	puller.Move(far_spot, EAST)
	TEST_ASSERT_EQUAL(get_turf(goon), door_spot, "A pulled mob was held in its room")
	puller.stop_pulling()
	puller.forceMove(locate(origin.x, origin.y + 3, origin.z))

	// Out of its room, it walks freely, and never gets stuck
	goon.Move(far_spot, EAST)
	TEST_ASSERT_EQUAL(get_turf(goon), far_spot, "A mob out of its room couldn't walk")

	// Thrown out of its room, it goes
	goon.forceMove(home_spot)
	goon.throw_at(locate(origin.x + 4, origin.y + 1, origin.z), 2, 1)
	var/deadline = world.time + 5 SECONDS
	UNTIL(!goon.throwing || world.time >= deadline)
	TEST_ASSERT(get_area(goon) != leash_test_home, "A thrown mob was held in its room")

/// Where a trophy lands: on the floor it fell on, the nearest floor reached past a hole, and never in space or outside its lair
/datum/unit_test/voidcrew_bounty_lairs/trophy_spot
	/// The tile the test turned to space
	var/turf/trophy_test_hole

/datum/unit_test/voidcrew_bounty_lairs/trophy_spot/Destroy()
	trophy_test_hole?.ChangeTurf(/turf/open/floor/iron)
	trophy_test_hole = null
	return ..()

/datum/unit_test/voidcrew_bounty_lairs/trophy_spot/Run()
	var/turf/floor = run_loc_floor_bottom_left
	TEST_ASSERT_EQUAL(bounty_lair_trophy_spot(floor), floor, "A trophy didn't land on the floor it fell on")
	trophy_test_hole = run_loc_floor_top_right.ChangeTurf(/turf/open/space)
	var/turf/landed = bounty_lair_trophy_spot(trophy_test_hole)
	TEST_ASSERT(landed && !isspaceturf(landed) && get_dist(landed, trophy_test_hole) == 1, "A trophy dropped in space didn't land on the floor beside it")
	var/datum/map_footprint/hole_only = allocate(/datum/map_footprint)
	hole_only.z_value = trophy_test_hole.z
	hole_only.set_rect(trophy_test_hole.x, trophy_test_hole.y, 1, 1)
	TEST_ASSERT_NULL(bounty_lair_trophy_spot(trophy_test_hole, hole_only), "A trophy with no floor inside its lair landed anyway")

/// The real Club Volga, loaded through its lair: the don's mech in the garage, two lieutenants on the gate, three gate doors, and torn down with no replacement once its bounty closes
/datum/unit_test/voidcrew_bounty_lairs/club

/datum/unit_test/voidcrew_bounty_lairs/club/Run()
	var/datum/bounty_lair_kind/kind = test_club_kind()
	var/datum/criminal_bounty/kill_only/lair/posting = bounty_post_lair(kind, 2) // ZONE_YELLOW
	TEST_ASSERT_NOTNULL(posting, "Club Volga could not be posted")
	var/obj/structure/overmap/space_ruin/bounty_lair/lair = posting.site()
	lair_test_made += lair
	lair.load_level()
	TEST_ASSERT(lair.is_loaded(), "Club Volga did not load")
	var/deadline = world.time + 30 SECONDS
	UNTIL(lair.lair_link_done || world.time >= deadline)
	TEST_ASSERT(lair.lair_link_done, "Club Volga never linked its interior")

	// The boss: the don's mech, on its landmark in the garage, wanted on this bounty, kept to the garage
	var/list/mechs = list()
	for(var/mob/living/basic/bounty_lair_boss/mafia_mech/mech in GLOB.mob_living_list)
		if(lair.footprint.contains_turf(get_turf(mech)))
			mechs += mech
	TEST_ASSERT_EQUAL(length(mechs), 1, "Club Volga should hold one mech")
	var/mob/living/basic/bounty_lair_boss/mafia_mech/mech = mechs[1]
	mech.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT_EQUAL(mech.posting_ref?.resolve(), posting, "The mech isn't wanted on the club's bounty")
	TEST_ASSERT(istype(get_area(mech), /area/ruin/space/has_grav/powered/mafia_club/garage), "The mech isn't in the garage")

	// Loading again does nothing: no second mech
	lair.load_level()
	SEND_SIGNAL(lair, "voidcrew_planet_loaded", TRUE) // COMSIG_VOIDCREW_PLANET_LOADED
	sleep(1)
	TEST_ASSERT_EQUAL(test_count(/mob/living/basic/bounty_lair_boss/mafia_mech, lair.footprint), 1, "Loading the club again spawned a second mech")

	// The gate: two lieutenants, three closed doors that open when both are dead
	TEST_ASSERT_EQUAL(length(lair.lair_gatekeepers), 2, "Club Volga should have two gatekeepers")
	TEST_ASSERT_EQUAL(length(lair.lair_gate_doors), 3, "Club Volga's gate should be three doors")
	var/list/gate_doors = list()
	for(var/datum/weakref/ref as anything in lair.lair_gate_doors)
		var/obj/machinery/door/poddoor/door = ref.resolve()
		gate_doors += door
		TEST_ASSERT(door?.density, "A garage door starts open")
	var/list/keepers = list()
	for(var/datum/weakref/ref as anything in lair.lair_gatekeepers)
		var/mob/living/keeper = ref.resolve()
		keeper.ai_controller?.set_ai_status(AI_STATUS_OFF)
		keepers += keeper
	var/mob/living/first_keeper = keepers[1]
	TEST_ASSERT(istype(first_keeper, /mob/living/basic/trooper/russian/mafia/lieutenant), "The gatekeepers aren't the lieutenants")
	TEST_ASSERT(istype(get_area(first_keeper), /area/ruin/space/has_grav/powered/mafia_club/back_office), "A lieutenant isn't in the back office")
	first_keeper.death()
	TEST_ASSERT(!lair.lair_gate_open, "The garage opened with a lieutenant still standing")
	var/mob/living/second_keeper = keepers[2]
	second_keeper.death()
	TEST_ASSERT(lair.lair_gate_open, "The garage didn't open when both lieutenants died")
	sleep(3 SECONDS)
	for(var/obj/machinery/door/poddoor/door as anything in gate_doors)
		TEST_ASSERT(!door.density, "A garage door didn't open")

	// Closed: torn down once empty, and nothing replaces it (a rare ruin never respawns)
	TEST_ASSERT(lair.rare, "The club is not rare, so tearing it down would spawn a replacement")
	posting.close("admin") // BOUNTY_CLOSE_ADMIN
	deadline = world.time + 2 MINUTES
	UNTIL(QDELETED(lair) || world.time >= deadline)
	TEST_ASSERT(QDELETED(lair), "The released club was not torn down")
	for(var/obj/structure/overmap/space_ruin/leftover as anything in GLOB.space_ruin_signals)
		if(!QDELETED(leftover) && leftover.ruin_template?.type == /datum/map_template/ruin/space/bounty_lair/mafia_club)
			TEST_FAIL("A Club Volga signal is still on the chart after its lair was torn down")

// ===== THE LICH =====

/// Surfacing the lich posts his kill bounty; his death drops the crown shard at the corpse, which pays at the pad; a lair gone without a kill closes it
/datum/unit_test/voidcrew_bounty_lairs/lich

/datum/unit_test/voidcrew_bounty_lairs/lich/Run()
	if(GLOB.lich_lair)
		TEST_NOTICE(src, "A lich lair already exists this round; the lich bounty test was skipped")
		return
	var/was_spawned = SSovermap.lich_lair_spawned
	var/obj/structure/overmap/space_ruin/lich_lair/site = surface_lich_lair()
	TEST_ASSERT_NOTNULL(site, "The lich lair did not surface")
	lair_test_made += site
	var/datum/criminal_bounty/kill_only/lich/posting = bounty_lich_posting(site)
	TEST_ASSERT_NOTNULL(posting, "Surfacing the lich posted no kill bounty")
	TEST_ASSERT_EQUAL(posting.record?.name, "Ilthuun, the Lich", "The lich bounty has the wrong name")
	TEST_ASSERT_EQUAL(posting.site(), site, "The lich bounty isn't on his lair")
	TEST_ASSERT_EQUAL(bounty_post_lich(site), posting, "A second call posted a second lich bounty")
	TEST_ASSERT_EQUAL(SScriminal_bounties.board_public_count(), 0, "The lich took one of the board's public slots")

	// The Most Wanted band times 1.5, in his zone, plus the Most Wanted vouchers
	// (BOUNTY_PAY_MOST_WANTED_MIN/_MAX 3000/3800, BOUNTY_LICH_PAY_MULT 1.5, BOUNTY_ZONE_MULT_*)
	var/zone = posting.board_zone
	var/mult = zone == 3 ? 2.6 : (zone == 2 ? 1.7 : 1)
	TEST_ASSERT(posting.value >= round(4500 * mult, 10) - 10 && posting.value <= round(5700 * mult, 10) + 10, "The lich pays [posting.value] in zone [zone]")
	TEST_ASSERT_EQUAL(posting.board_vouchers, SScriminal_bounties.board_vouchers_for(3, zone), "The lich doesn't pay the Most Wanted vouchers")
	TEST_ASSERT(posting.board_clock_held(), "The lich bounty's clock runs while he lives")

	// His lair links with him in it (a stand-in here): the board's tick keeps the bounty up
	var/turf/pad_turf = run_loc_floor_bottom_left
	var/turf/aside = locate(pad_turf.x + 2, pad_turf.y, pad_turf.z)
	var/mob/living/basic/corpse = allocate(/mob/living/basic, aside)
	site.linked = TRUE
	site.lich_ref = WEAKREF(corpse)
	posting.board_process(0)
	TEST_ASSERT(posting.is_open(), "The lich bounty closed with him still in his lair")

	// He dies: the shard drops at the corpse, and the clock runs
	site.on_lich_slain(corpse, null)
	var/obj/item/bounty_proof/trophy/lich/shard = posting.board_proof()
	TEST_ASSERT(istype(shard), "His death dropped no crown shard")
	TEST_ASSERT_EQUAL(shard.loc, aside, "The crown shard isn't at the corpse")
	TEST_ASSERT(!posting.board_clock_held(), "The lich bounty's clock still waits after he died")
	TEST_ASSERT(posting.is_open(), "The lich bounty closed when he died")

	// The shard pays at the pad
	var/obj/machinery/mission_pad/pad = allocate(/obj/machinery/mission_pad, pad_turf)
	var/obj/structure/overmap/ship/ship = board_test_ship()
	shard.forceMove(pad_turf)
	var/list/found = list()
	TEST_ASSERT_NULL(posting.board_target_refusal(pad, found), "The pad refused the crown shard")
	var/value = posting.value
	var/balance_before = ship.ship_account.account_balance
	TEST_ASSERT(islist(posting.board_claim(ship, pad, found["target"], found["state"])), "The crown shard was refused")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance - balance_before, value, "The crown shard didn't pay the lich's value")
	TEST_ASSERT(QDELETED(posting), "The lich bounty stayed up after it was turned in")

	// A second lich removed without dying (a polymorph, an admin) after his lair linked: the board's tick closes his
	// bounty, which nothing could finish; showing the card never does
	qdel(site)
	var/obj/structure/overmap/space_ruin/lich_lair/second_site = surface_lich_lair()
	TEST_ASSERT_NOTNULL(second_site, "The lich lair did not surface a second time")
	lair_test_made += second_site
	var/datum/criminal_bounty/kill_only/lich/second = bounty_lich_posting(second_site)
	TEST_ASSERT_NOTNULL(second, "The second lich lair posted no bounty")
	var/mob/living/basic/vanished = allocate(/mob/living/basic, aside)
	second_site.linked = TRUE
	second_site.lich_ref = WEAKREF(vanished)
	qdel(vanished)
	second.board_ui_entry(ship, pad)
	TEST_ASSERT(second.is_open(), "Showing the card closed the lich bounty")
	second.board_process(0)
	TEST_ASSERT(QDELETED(second), "The lich bounty stayed up after he was removed without dying")

	// A third lair that goes away before he is ever fought takes its bounty with it
	qdel(second_site)
	var/obj/structure/overmap/space_ruin/lich_lair/third_site = surface_lich_lair()
	TEST_ASSERT_NOTNULL(third_site, "The lich lair did not surface a third time")
	lair_test_made += third_site
	var/datum/criminal_bounty/kill_only/lich/third = bounty_lich_posting(third_site)
	TEST_ASSERT_NOTNULL(third, "The third lich lair posted no bounty")
	qdel(third_site)
	TEST_ASSERT(QDELETED(third), "The lich bounty stayed up after his lair went away without a kill")
	SSovermap.lich_lair_spawned = was_spawned

// ===== ADMIN =====

/// Overmap Management's spawn catalog never offers a lair template: lairs come from the board
/datum/unit_test/voidcrew_bounty_lairs/catalog

/datum/unit_test/voidcrew_bounty_lairs/catalog/Run()
	var/registered = FALSE
	for(var/id in SSmapping.space_ruins_templates)
		if(istype(SSmapping.space_ruins_templates[id], /datum/map_template/ruin/space/bounty_lair))
			registered = TRUE
			break
	TEST_ASSERT(registered, "No lair template is registered, so this test proves nothing")
	var/mob/living/basic/operator = allocate(/mob/living/basic)
	var/datum/overmap_management/panel = allocate(/datum/overmap_management, operator)
	panel.build_spawn_catalog()
	TEST_ASSERT(length(panel.spawn_catalog), "The admin catalog is empty")
	for(var/id in panel.spawn_catalog)
		var/list/option = panel.spawn_catalog[id]
		if(istype(option["path"], /datum/map_template/ruin/space/bounty_lair))
			TEST_FAIL("Overmap Management offers the lair template [option["name"]]")
