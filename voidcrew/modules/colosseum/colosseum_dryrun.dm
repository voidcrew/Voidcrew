/**
 * # Colosseum headless dry-run harness
 *
 * Compiled ONLY when COLOSSEUM_DRYRUN is defined (never in normal builds.
 * The define is injected into a scratch .dme copy). Drives the same
 * controller procs the admin verbs call, through two full match cycles, with
 * clientless dummy contestants, and logs a PASS/FAIL transcript to game.log
 * under the "COLOSSEUM DRYRUN" prefix.
 *
 * Cycle 1: 4 contestants, natural mode pick. Signup → seat → live → kill 3
 *          → resolve → sweep/prizes → claim checks → reset → IDLE.
 * Cycle 2: 6 contestants, forced Tournament. Round cuts, mid-match
 *          sweep/reset/reseat, intermissions, final, doubled payout.
 */
#ifdef COLOSSEUM_DRYRUN

SUBSYSTEM_DEF(colosseum_dryrun)
	name = "Colosseum Dryrun"
	flags = SS_NO_FIRE
	var/failures = 0

/datum/controller/subsystem/colosseum_dryrun/Initialize()
	// The MC suspends a clientless world's tick after init (sleep_offline),
	// which freezes every sleep/timer. The harness would die at its first
	// sleep. Same opt-out the autowiki harness uses.
	Master.sleep_offline_after_initializations = FALSE
	// A playerless headless round "ends" instantly and reboots the world about
	// 45 seconds after init. Hold it open or the test dies mid-flight.
	SSticker.delay_end = TRUE
	// NOT addtimer: timers scheduled from init-context never fire in this
	// environment (verified empirically 2026-07-18). Engine sleeps do.
	INVOKE_ASYNC(src, PROC_REF(launch))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/colosseum_dryrun/proc/launch()
	log_game("COLOSSEUM DRYRUN: launch() entered, ticker state [SSticker ? SSticker.current_state : "no ticker"]")
	UNTIL(SSticker.current_state >= GAME_STATE_PREGAME) // MC init finished
	log_game("COLOSSEUM DRYRUN: pregame reached (state [SSticker.current_state]), settling 15s")
	sleep(15 SECONDS)
	log_game("COLOSSEUM DRYRUN: settle sleep done, ticker state [SSticker.current_state]")
	SSticker.delay_end = TRUE
	run_test()

/datum/controller/subsystem/colosseum_dryrun/proc/report(label, ok, detail = "")
	if(!ok)
		failures++
	log_game("COLOSSEUM DRYRUN: [ok ? "PASS" : "FAIL"], [label][detail ? " ([detail])" : ""]")

/datum/controller/subsystem/colosseum_dryrun/proc/make_dummy(turf/spot, name_suffix)
	var/mob/living/carbon/human/consistent/dummy = new(spot)
	dummy.fully_replace_character_name(dummy.real_name, "Dryrun Fighter [name_suffix]")
	dummy.mind_initialize()
	return dummy

/// Moves every live contestant into staging so close_seating() keeps them.
/datum/controller/subsystem/colosseum_dryrun/proc/stage_roster(datum/colosseum_controller/controller)
	var/obj/structure/overmap/colosseum/site = controller.site
	var/list/staging = site.get_area_turfs_cached(/area/voidcrew/colosseum/staging)
	for(var/datum/colosseum_contestant/entry as anything in controller.live_entries())
		var/mob/living/body = entry.mind.current
		var/turf/spot
		for(var/_ in 1 to 30)
			spot = pick(staging)
			if(!spot.is_blocked_turf())
				break
		body.forceMove(spot)

/datum/controller/subsystem/colosseum_dryrun/proc/run_test()
	log_game("COLOSSEUM DRYRUN: starting")

	// ===== VENUE SPAWN + LINK =====
	// The shipping map is the two-level venue (observation gallery over the
	// arena); the gallery checks below run against its upper slice.
	var/obj/structure/overmap/colosseum/site = spawn_colosseum_site()
	report("site spawned", !!site)
	if(!site)
		return
	// spawn_colosseum_site kicks open_venue asynchronously; wait it out
	for(var/_ in 1 to 60)
		if(site.loaded && site.controller)
			break
		sleep(1 SECONDS)
	report("interior loaded", site.loaded)
	report("alcove turfs = 9", length(site.lobby_alcove_turfs) == 9, "[length(site.lobby_alcove_turfs)]")
	report("lobby panel linked", length(site.lobby_panels) == 1 && site.lobby_panels[1].is_lobby)
	report("floor 0 alcove resolves", length(site.get_floor_alcove(0)) == 9)
	report("gate ids collected", length(site.gate_doors[COLOSSEUM_GATE_RED]) == 2 \
		&& length(site.gate_doors[COLOSSEUM_GATE_BLUE]) == 2 \
		&& length(site.gate_doors[COLOSSEUM_GATE_SOLO]) == 6 \
		&& length(site.gate_doors[COLOSSEUM_SEAL]) == 10)
	report("signup console linked", !!site.signup_console)
	report("spoils vault linked", !!site.spoils_vault)
	report("landmarks: cells", length(site.get_landmark_turfs(/obj/effect/landmark/colosseum/spawn_cell)) == 6)
	report("landmarks: red/blue seats", length(site.get_landmark_turfs(/obj/effect/landmark/colosseum/spawn_red)) == 6 && length(site.get_landmark_turfs(/obj/effect/landmark/colosseum/spawn_blue)) == 6)
	report("landmarks: koth 16", length(site.get_landmark_turfs(/obj/effect/landmark/colosseum/koth)) == 16)
	report("landmarks: flags", length(site.get_landmark_turfs(/obj/effect/landmark/colosseum/flag_red)) == 1 && length(site.get_landmark_turfs(/obj/effect/landmark/colosseum/flag_blue)) == 1)
	report("landmarks: arena events 8", length(site.get_landmark_turfs(/obj/effect/landmark/colosseum/arena_event)) == 8)
	report("infirmary berths 4", length(site.get_infirmary_turfs()) == 4)

	// ===== MULTI-Z GALLERY =====
	if(length(site.interior_levels) >= 2)
		var/turf/arena_mid = site.local_turf(32, 32)
		var/turf/over_arena = arena_mid ? GET_TURF_ABOVE(arena_mid) : null
		report("gallery: glass deck over arena center", istype(over_arena, /turf/open/indestructible/glass))
		report("gallery: spectator area above", istype(over_arena?.loc, /area/voidcrew/colosseum/spectator))
		var/turf/stair_turf = site.local_turf(22, 15)
		report("gallery: south grand stairs mapped", !!(stair_turf && (locate(/obj/structure/stairs) in stair_turf)))
		var/turf/stair_turf_east = site.local_turf(40, 16)
		report("gallery: east grand stairs mapped", !!(stair_turf_east && (locate(/obj/structure/stairs) in stair_turf_east)))
		var/turf/stairwell = stair_turf ? GET_TURF_ABOVE(stair_turf) : null
		report("gallery: stairwell openspace", istype(stairwell, /turf/open/openspace))
		var/turf/landing_ground = site.local_turf(22, 17)
		var/turf/landing = landing_ground ? GET_TURF_ABOVE(landing_ground) : null
		report("gallery: landing is stone deck", istype(landing, /turf/open/indestructible/stone))
		var/turf/parapet_ground = site.local_turf(17, 30)
		var/turf/parapet = parapet_ground ? GET_TURF_ABOVE(parapet_ground) : null
		report("gallery: parapet indestructible glass", istype(parapet, /turf/closed/indestructible/opsglass))
		var/turf/bridge_ground = site.local_turf(20, 33)
		var/turf/bridge = bridge_ground ? GET_TURF_ABOVE(bridge_ground) : null
		report("gallery: west bridge glass deck", istype(bridge, /turf/open/indestructible/glass))
		// Rail sits 2 tiles off the glass (y=31/32 are a buffer strip) so the
		// parapet turf is never Chebyshev-adjacent to a transparent tile,
		// see [[turf_z_transparency]]'s 3x3 spillover, which otherwise
		// projects the arena floor onto any solid turf touching openspace/glass.
		var/turf/bridge_edge_ground = site.local_turf(20, 30)
		var/turf/bridge_edge = bridge_edge_ground ? GET_TURF_ABOVE(bridge_edge_ground) : null
		report("gallery: bridge edge parapet", istype(bridge_edge, /turf/closed/indestructible/opsglass))
		var/turf/quadrant_ground = site.local_turf(22, 40)
		var/turf/quadrant = quadrant_ground ? GET_TURF_ABOVE(quadrant_ground) : null
		report("gallery: openspace quadrant survives", istype(quadrant, /turf/open/openspace))
		report("gallery: deck resolves back down", arena_mid && over_arena && (GET_TURF_BELOW(over_arena) == arena_mid))
	var/datum/colosseum_controller/controller = site.controller
	report("controller exists", !!controller)
	if(!controller)
		return
	report("arena snapshot taken", length(controller.arena_baseline_turfs) > 700, "[length(controller.arena_baseline_turfs)] turfs, [length(controller.arena_baseline_objects)] objects")

	// ===== CYCLE 1: natural mode, 4 fighters =====
	report("signup opens", controller.open_signup(null, forced = TRUE))
	var/list/mob/living/carbon/human/dummies = list()
	for(var/i in 1 to 4)
		var/mob/living/carbon/human/dummy = make_dummy(site.get_random_lobby_turf(), "[i]")
		dummies += dummy
		report("register #[i]", controller.register_contestant(dummy))
	report("roster = 4", length(controller.roster) == 4)
	controller.lock_roster()
	report("roster locked -> SEATING", controller.state == COLOSSEUM_STATE_SEATING, "mode: [controller.mode?.name]")
	if(!istype(controller.mode, /datum/colosseum_game/deathmatch))
		// Deterministic cycle: kill-3-of-4 leaves exactly one winner only in FFA
		qdel(controller.mode)
		controller.mode = new /datum/colosseum_game/deathmatch
		controller.mode.controller = controller
		controller.mode.assign_teams(controller.roster)
		report("forced FFA for determinism", TRUE)
	report("modifier rolled", !!controller.modifier, "[controller.modifier?.name]")
	var/datum/colosseum_book/test_book = controller.book
	report("book open at lock", !!test_book?.open)
	// 100 on the eventual winner, 300 on a loser: winner should collect
	// 100 + (300 losing pool * 0.9 rake-adjusted) = 370, loser slips void.
	report("stake on winner recorded", test_book.record_stake(dummies[4].mind, 100))
	report("stake on loser recorded", test_book.record_stake(dummies[1].mind, 300))
	stage_roster(controller)
	controller.close_seating()
	report("seating closed (countdown)", controller.state == COLOSSEUM_STATE_SEATING && length(controller.live_entries()) == 4)
	sleep(12 SECONDS)
	report("match LIVE", controller.state == COLOSSEUM_STATE_LIVE)

	// loose loot on the sand for the sweep to find
	new /obj/item/knife/combat(site.get_random_clear_turf(/area/voidcrew/colosseum/arena))

	// kill three: signal-driven eliminations must resolve the match
	for(var/i in 1 to 3)
		var/mob/living/carbon/human/victim = dummies[i]
		victim.death()
	sleep(2 SECONDS)
	report("resolved via death signals", controller.state == COLOSSEUM_STATE_RESOLVED, "state: [controller.state]")
	report("one winner", length(controller.winner_minds) == 1)
	var/obj/machinery/colosseum_vault/vault = site.spoils_vault
	var/corpses_in_vault = 0
	var/items_in_vault = 0
	for(var/atom/movable/thing as anything in vault.contents)
		if(ismob(thing))
			corpses_in_vault++
			continue
		items_in_vault++
		// Parts, credits and vouchers all ride inside the champion's case
		if(istype(thing, /obj/item/storage/briefcase/secure/extraction/tournament))
			var/obj/item/storage/briefcase/secure/extraction/tournament/prize_case = thing
			items_in_vault += length(prize_case.contents)
	report("sweep: 3 corpses in vault", corpses_in_vault == 3, "[corpses_in_vault]")
	report("prizes banked", items_in_vault >= 5, "[items_in_vault] items (3 parts + credits + voucher + knife expected)")
	report("book settled + closed", test_book.settled && !test_book.open)
	report("winning bet pays 370", test_book.payout_for(dummies[4].mind, 100) == 370, "[test_book.payout_for(dummies[4].mind, 100)]")
	report("losing bet pays 0", test_book.payout_for(dummies[1].mind, 300) == 0)
	report("bookmaker console linked", !!site.bookmaker)
	var/mob/living/carbon/human/winner = dummies[4]
	report("winner can claim", vault.can_claim(winner))
	var/mob/living/carbon/human/outsider = make_dummy(site.get_random_lobby_turf(), "Outsider")
	report("outsider cannot claim", !vault.can_claim(outsider))
	controller.end_claim_window()
	report("post-window: outsider can claim", vault.can_claim(outsider))
	var/corpses_left = 0
	for(var/mob/living/corpse in vault.contents)
		corpses_left++
	report("corpses laid out in infirmary", corpses_left == 0)
	sleep(15 SECONDS)
	report("reset -> IDLE", controller.state == COLOSSEUM_STATE_IDLE)
	report("matches_run = 1", controller.matches_run == 1)

	// ===== CYCLE 2: forced tournament, 6 fighters =====
	controller.next_signup_at = 0
	report("second signup opens", controller.open_signup(null, forced = TRUE))
	var/list/mob/living/carbon/human/field = list(winner, outsider)
	winner.forceMove(site.get_random_lobby_turf())
	for(var/i in 1 to 4)
		field += make_dummy(site.get_random_lobby_turf(), "T[i]")
	for(var/mob/living/carbon/human/fighter as anything in field)
		controller.register_contestant(fighter)
	report("tournament roster = 6", length(controller.roster) == 6)
	controller.lock_roster()
	if(!istype(controller.mode, /datum/colosseum_game/tournament))
		// Force the wrapper deterministically, re-running exactly what lock_roster did
		qdel(controller.mode)
		controller.mode = new /datum/colosseum_game/tournament
		controller.mode.controller = controller
		controller.mode.assign_teams(controller.roster)
	report("tournament mode set", istype(controller.mode, /datum/colosseum_game/tournament))
	stage_roster(controller)
	controller.close_seating()
	sleep(12 SECONDS)
	report("tournament LIVE", controller.state == COLOSSEUM_STATE_LIVE)
	var/datum/colosseum_game/tournament/bracket = controller.mode
	report("round 1 armed (cut 1 of 6)", bracket.round_number == 1 && bracket.cut_remaining == 1, "cut_remaining: [bracket.cut_remaining]")

	// Round 1: one kill ends the round
	var/datum/colosseum_contestant/first_kill = controller.live_entries()[1]
	var/mob/living/round1_victim = first_kill.body
	round1_victim.death()
	sleep(3 SECONDS)
	report("round 1 ended (intermission)", bracket.intermission, "live: [length(controller.live_entries())]")
	sleep(COLOSSEUM_TOURNAMENT_INTERMISSION + 2 SECONDS)
	report("round 2 armed (cut 2 of 5)", bracket.round_number == 2 && bracket.cut_remaining == 2, "round [bracket.round_number], cut [bracket.cut_remaining]")

	// Round 2: two kills
	for(var/i in 1 to 2)
		var/datum/colosseum_contestant/entry = controller.live_entries()[1]
		var/mob/living/victim = entry.body
		victim.death()
		sleep(1 SECONDS)
	sleep(3 SECONDS)
	sleep(COLOSSEUM_TOURNAMENT_INTERMISSION + 2 SECONDS)
	report("final armed (3 fighters)", bracket.cut_remaining == 0 && length(controller.live_entries()) == 3, "live: [length(controller.live_entries())]")

	// The final: kill down to one
	for(var/i in 1 to 2)
		var/list/live = controller.live_entries()
		if(length(live) <= 1)
			break
		var/datum/colosseum_contestant/entry = live[1]
		var/mob/living/victim = entry.body
		victim.death()
		sleep(1 SECONDS)
	sleep(2 SECONDS)
	report("tournament resolved", controller.state == COLOSSEUM_STATE_RESOLVED, "winners: [length(controller.winner_minds)]")
	report("matches_run = 2", controller.matches_run == 2)
	sleep(16 SECONDS)
	report("second reset -> IDLE", controller.state == COLOSSEUM_STATE_IDLE)

	log_game("COLOSSEUM DRYRUN: COMPLETE: [failures] failure\s")

#endif
