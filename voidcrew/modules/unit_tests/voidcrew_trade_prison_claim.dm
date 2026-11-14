/**
 * Wave 5 lockup tests: the warden behind the front desk, staff-kill charges and outpost recovery, live criminal
 * bounty hand-in through Processing (`try_start_processing_claim`, `processing_claim_tick`, `lockup_claim`),
 * the ship mission pad's live-catch refusal vs dead/proof/kill-only turn-ins, the Outpost Manipulator lockup
 * section, and the eight `lockup` round metrics.
 *
 * Voidcrew defines compile after unit tests, so tuning values and constants appear as literals with comments
 * naming the define.
 */

/// Records lines spoken via `COMSIG_MOB_SAY` on a list of strings
/datum/lockup_say_listener
	var/list/lines = list()

/datum/lockup_say_listener/proc/watch(mob/speaker)
	RegisterSignal(speaker, COMSIG_MOB_SAY, PROC_REF(on_say))

/datum/lockup_say_listener/proc/on_say(datum/source, list/speech_args)
	SIGNAL_HANDLER
	lines += speech_args[SPEECH_MESSAGE]

/datum/lockup_say_listener/proc/heard(fragment)
	for(var/line as anything in lines)
		if(findtext(line, fragment))
			return TRUE
	return FALSE

// =========================================================================
// 1. WARDEN, CONCOURSE SEAMS & STAFF-KILL CHARGES
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_warden
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_warden/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	TEST_ASSERT_NOTNULL(prison, "Quartermain Depot has no lockup")
	TEST_ASSERT_NOTNULL(prison.desk_turf, "Quartermain Depot's lockup has no mapped desk_turf")
	TEST_ASSERT_NOTNULL(prison.claim_turf, "Quartermain Depot's lockup has no mapped claim_turf")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/warden = prison.ensure_warden()
	TEST_ASSERT_NOTNULL(warden, "ensure_warden() did not spawn a lockup warden")
	TEST_ASSERT_EQUAL(get_turf(warden), prison.desk_turf, "The warden did not spawn at desk_turf")
	TEST_ASSERT_EQUAL(prison.warden_at_desk(), warden, "warden_at_desk() did not return the live warden at his desk")
	TEST_ASSERT(prison.is_staff(warden), "The lockup warden did not count as wing staff")
	TEST_ASSERT(!warden.may_flee(), "The lockup warden was allowed to flee")
	TEST_ASSERT_NULL(warden.drop_from_shelf(), "The lockup warden had shelf stock to rob")

	var/obj/item/card/id/warden_id = warden.wear_id
	TEST_ASSERT_NOTNULL(warden_id, "The lockup warden has no worn ID card")
	TEST_ASSERT(istype(warden_id.trim, /datum/id_trim/outpost_police), "The warden's ID trim is [warden_id.trim?.type], not outpost_police")
	TEST_ASSERT_EQUAL(warden_id.registered_name, warden.real_name, "The warden's ID card was not stamped with their name")

	// Clicking the warden speaks an idle line and opens no shop UI; concourse bounty clues skip the lockup warden
	var/turf/front_tile = inmate_test_front_tile(prison)
	var/mob/living/carbon/human/visitor = make_player(front_tile, "lockupwardenvisitor")
	var/datum/lockup_say_listener/warden_ears = allocate(/datum/lockup_say_listener)
	warden_ears.watch(warden)
	COOLDOWN_RESET(warden, speak_cooldown)
	warden.open_trader_menu(visitor)
	TEST_ASSERT(length(warden_ears.lines) >= 1, "Clicking the warden did not speak an idle line")
	TEST_ASSERT_NULL(bounty_outpost_ask_posting(warden, visitor), "bounty_outpost_ask_posting() treated the lockup warden as a concourse clue trader")
	var/where_desk = bounty_outpost_where(prison.desk_turf, outpost)
	TEST_ASSERT(!where_desk || !findtext(where_desk, warden.name), "bounty_outpost_where() named the lockup warden's counter: [where_desk]")

	// Recovery registered the warden's post with the lockup warden subtype
	TEST_ASSERT_NOTNULL(warden.shop, "The lockup warden has no shop post for recovery")
	var/datum/outpost_recovery_post/warden_post = recovery.posts[warden.shop]
	TEST_ASSERT_NOTNULL(warden_post, "Outpost recovery did not learn the warden's desk post")
	TEST_ASSERT_EQUAL(warden_post.keeper_type, warden.type, "The warden's recovery post recorded [warden_post.keeper_type] instead of [warden.type]")
	TEST_ASSERT(recovery.keeper_on_post(warden), "The lockup warden at desk_turf did not count as keeper_on_post()")
	TEST_ASSERT(!(warden_post in recovery.vacant_posts()), "A staffed warden post appeared vacant")

	// Killing a prison guard as an outsider in view of the warden/camera charges kill_staff (4+ stars)
	var/datum/outpost_guard_record/guard_rec = prison.add_guard_record(TRUE)
	var/mob/living/carbon/human/npc/outpost_prison_guard/front_guard = guard_rec.guard
	TEST_ASSERT_NOTNULL(front_guard, "Guard 1 did not spawn")
	front_guard.forceMove(front_tile)
	var/mob/living/carbon/human/outsider_killer = make_player(prison.claim_turf, "lockupguardkiller")
	var/obj/item/knife/combat/killer_knife = allocate(/obj/item/knife/combat, outsider_killer)
	outsider_killer.put_in_hands(killer_knife)
	front_guard.record_guard_hit(outsider_killer, killer_knife, damaging = TRUE)
	front_guard.death()
	TEST_ASSERT(police.get_stars(outsider_killer.mind) >= 4, "Killing a prison guard in the front room earned [police.get_stars(outsider_killer.mind)] stars, expected 4+ (kill_staff)")
	police.admin_lift(outsider_killer.mind)
	outsider_killer.key = null
	qdel(outsider_killer)

	// Killing a lone prison guard inside an isolated cell with no witness files no outside warrant; a witnessed guard kill charges kill_staff (4+ stars)
	var/turf/yard_tile = inmate_test_yard_tile(prison)
	var/turf/isolated_cell_tile = prison.cells[1].arrival_turf()
	var/mob/living/carbon/human/inmate_killer = make_player(isolated_cell_tile, "lockupinmatekiller")
	TEST_ASSERT(prison.admin_book_player(inmate_killer, 180), "Could not book inmate_killer for cell-block guard-kill check")
	inmate_killer.forceMove(isolated_cell_tile)
	var/datum/outpost_guard_record/lone_guard_rec = prison.add_guard_record(TRUE)
	var/mob/living/carbon/human/npc/outpost_prison_guard/lone_guard = lone_guard_rec.guard
	lone_guard.forceMove(isolated_cell_tile)
	lone_guard.record_guard_hit(inmate_killer, null, damaging = TRUE)
	lone_guard.death()
	TEST_ASSERT_EQUAL(police.get_stars(inmate_killer.mind), 0, "An unwitnessed lone prison-guard kill inside an isolated cell filed a warrant")

	var/datum/outpost_guard_record/guard_rec_two = prison.add_guard_record(TRUE)
	var/mob/living/carbon/human/npc/outpost_prison_guard/yard_guard = guard_rec_two.guard
	var/mob/living/carbon/human/npc/outpost_prison_guard/witness_guard = allocate(/mob/living/carbon/human/npc/outpost_prison_guard, yard_tile)
	witness_guard.prison = prison
	prison.guard_mobs |= witness_guard
	witness_guard.arrive()
	yard_guard.forceMove(yard_tile)
	inmate_killer.forceMove(yard_tile)
	yard_guard.record_guard_hit(inmate_killer, null, damaging = TRUE)
	TEST_ASSERT_EQUAL(police.get_stars(inmate_killer.mind), 0, "A non-lethal inmate blow inside the cell block filed an outside warrant before death")
	yard_guard.death()
	TEST_ASSERT(police.get_stars(inmate_killer.mind) >= 4, "An inmate killing a prison guard in sight of another guard earned [police.get_stars(inmate_killer.mind)] stars, expected 4+ (kill_staff)")
	prison.release_inmate(inmate_killer.mind, TRUE)
	police.admin_lift(inmate_killer.mind)
	prison.guard_mobs -= witness_guard
	witness_guard.prison = null
	qdel(witness_guard)
	inmate_killer.key = null
	qdel(inmate_killer)

	// Gunpoint at the desk: a harmless toy gun does not take the warden off desk duty or pause his AI;
	// a real gun pauses his AI without starting a till stick-up, files staff assault with weapon evidence, and unpauses when lowered
	var/turf/desk_stand = get_step(prison.claim_turf, SOUTH)
	visitor.forceMove(desk_stand)
	var/obj/item/gun/energy/laser/redtag/toy_gun = allocate(/obj/item/gun/energy/laser/redtag, visitor)
	TEST_ASSERT(visitor.put_in_hands(toy_gun), "Could not put laser-tag gun in visitor's hand")
	visitor.AddComponent(/datum/component/gunpoint, warden, toy_gun)
	sleep(0.5 SECONDS)
	TEST_ASSERT(warden.has_status_effect(/datum/status_effect/grouped/heldup), "Toy gunpoint did not apply heldup status effect")
	TEST_ASSERT_EQUAL(prison.warden_at_desk(), warden, "Aiming a harmless toy gun at the warden took him off desk duty")
	TEST_ASSERT(!HAS_TRAIT_FROM(warden, TRAIT_AI_PAUSED, REF(GLOB.outpost_holdups)), "A toy gun paused the warden's AI")
	TEST_ASSERT_NULL(police.get_warrant(visitor.mind), "Aiming a toy gun at the warden filed a warrant")
	qdel(visitor.GetComponent(/datum/component/gunpoint))
	visitor.dropItemToGround(toy_gun)
	qdel(toy_gun)

	var/obj/item/gun/energy/disabler/real_gun = allocate(/obj/item/gun/energy/disabler, visitor)
	TEST_ASSERT(visitor.put_in_hands(real_gun), "Could not put disabler in visitor's hand")
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	visitor.AddComponent(/datum/component/gunpoint, warden, real_gun)
	sleep(0.5 SECONDS)
	TEST_ASSERT_NULL(warden.shop.holdup, "Aiming a real gun at the lockup warden started a till stick-up")
	TEST_ASSERT(HAS_TRAIT_FROM(warden, TRAIT_AI_PAUSED, REF(GLOB.outpost_holdups)), "The lockup warden did not pause AI while held at gunpoint with a real gun")
	var/datum/outpost_warrant/gunpoint_warrant = police.get_warrant(visitor.mind)
	TEST_ASSERT(gunpoint_warrant?.heat >= 8, "Holding the lockup warden at gunpoint did not report staff assault (8 heat)") // OUTPOST_CRIME_ASSAULT_STAFF
	TEST_ASSERT(WEAKREF(real_gun) in gunpoint_warrant?.evidence, "Warden gunpoint assault did not record the gun as evidence")
	TEST_ASSERT(length(warden_ears.lines) >= 1, "Warden stayed silent when held at gunpoint with a real gun")
	qdel(visitor.GetComponent(/datum/component/gunpoint))
	TEST_ASSERT(!HAS_TRAIT_FROM(warden, TRAIT_AI_PAUSED, REF(GLOB.outpost_holdups)), "Warden stayed AI-paused after gunpoint ended")
	police.admin_lift(visitor.mind)
	visitor.dropItemToGround(real_gun)
	qdel(real_gun)
	visitor.forceMove(front_tile)

	// Killing the warden charges kill_staff (4+ stars), vacates his post, and recovery.send_staff() spawns the replacement inside the lockup
	var/mob/living/carbon/human/warden_killer = make_player(prison.claim_turf, "lockupwardenkiller")
	var/obj/item/knife/combat/warden_knife = allocate(/obj/item/knife/combat, warden_killer)
	warden_killer.put_in_hands(warden_knife)
	outpost.register_aggression(warden_killer, "staff", warden, warden_knife) // OUTPOST_CRIME_ASSAULT_STAFF
	warden.death()
	TEST_ASSERT(police.get_stars(warden_killer.mind) >= 4, "Killing the lockup warden earned [police.get_stars(warden_killer.mind)] stars, expected 4+ (kill_staff)")
	TEST_ASSERT_NULL(prison.warden_at_desk(), "A dead warden still counted as warden_at_desk()")
	TEST_ASSERT(warden_post in recovery.vacant_posts(), "Killing the warden did not vacate his recovery post")
	police.admin_lift(warden_killer.mind)
	warden_killer.key = null
	qdel(warden_killer)
	visitor.key = null
	qdel(visitor)

	warden_post.vacant_since = world.time - 10 MINUTES
	recovery.send_staff()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/replacement = prison.warden_ref?.resolve()
	TEST_ASSERT_NOTNULL(replacement, "recovery.send_staff() did not spawn and link a replacement lockup warden")
	TEST_ASSERT(replacement != warden && replacement.stat == CONSCIOUS, "The replacement warden was not a fresh conscious mob")
	TEST_ASSERT_EQUAL(replacement.type, warden_post.keeper_type, "The replacement warden was [replacement.type], expected [warden_post.keeper_type]")
	TEST_ASSERT(prison.contains_turf(get_turf(replacement)), "The replacement warden spawned outside the lockup at [AREACOORD(replacement)]")

	dispatch_clear(police)
	recovery.sleep_tick()

// =========================================================================
// 2. PROCESSING LIVE HAND-IN & LOCKUP_CLAIM()
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_claim
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/list/obj/structure/overmap/ship/claim_ships = list()

/datum/unit_test/voidcrew_trade_prison_claim/New()
	. = ..()
	board_test_begin()

/datum/unit_test/voidcrew_trade_prison_claim/Destroy()
	wanted_cleanup(claim_ships)
	claim_ships = null
	board_test_end()
	return ..()

/datum/unit_test/voidcrew_trade_prison_claim/proc/claim_wait_door(datum/outpost_prison/prison, obj/machinery/door/airlock/door, open, seconds = 12)
	var/obj/machinery/door/airlock/inner = prison.processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = prison.processing_door(FALSE)
	for(var/i in 1 to seconds * 2)
		TEST_ASSERT(inner.density || outer.density, "Both of Processing's doors were open at once during a bounty claim")
		if(!door.operating && (open ? !door.density : door.density))
			return TRUE
		if(i % 2)
			prison.processing_tick(1)
		sleep(0.5 SECONDS)
	return FALSE

/datum/unit_test/voidcrew_trade_prison_claim/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/obj/machinery/door/airlock/security/prison_staff/processing/inner = prison.processing_door(TRUE)
	var/obj/machinery/door/airlock/security/prison_staff/processing/outer = prison.processing_door(FALSE)
	var/turf/outer_wait = prison.processing_outside_turf(outer)
	TEST_ASSERT_NOTNULL(outer_wait, "Processing's outer door has no front-room approach tile")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/warden = prison.ensure_warden()
	TEST_ASSERT_NOTNULL(warden, "No lockup warden spawned")
	var/datum/lockup_say_listener/warden_ears = allocate(/datum/lockup_say_listener)
	warden_ears.watch(warden)

	// Two-ship crew: `away_ship` is elsewhere, `berthed_ship` is docked at this outpost and should receive the payout
	var/mob/living/carbon/human/hunter = make_player(outer_wait, "lockupclaimhunter")
	var/obj/structure/overmap/ship/away_ship = wanted_ship(hunter, 0)
	away_ship.name = "ISS Away"
	var/obj/structure/overmap/ship/berthed_ship = wanted_ship(null, 0, away_ship.ship_team.crew_record)
	berthed_ship.name = "ISS Berthed"
	berthed_ship.docked = outpost
	var/obj/structure/overmap/ship/rival_ship = board_test_ship(0)
	claim_ships += list(away_ship, berthed_ship)

	// Abuse 16: Processing never opens for a lone player
	TEST_ASSERT(!outer.allowed(hunter), "Processing's outer door opened for a lone player")
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "try_start_processing_claim() started for a lone player")
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing left idle for a lone player") // OUTPOST_PROCESSING_IDLE

	// Refusals at the outer door: dead criminal, player body, decoy, kill-only target, another ship's private offer, bound kingpin, free criminal
	var/datum/criminal_bounty/dead_posting = board_test_posting()
	var/mob/living/carbon/human/npc/bounty_criminal/dead_catch = board_test_criminal(dead_posting, outer_wait)
	dead_catch.death()
	hunter.start_pulling(dead_catch)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened for a dead bounty criminal")
	TEST_ASSERT(warden_ears.heard("We don't take bodies."), "Warden did not say 'We don't take bodies.' for a corpse: [warden_ears.lines.Join(" | ")]")
	TEST_ASSERT(outer.density && !outer.operating, "Processing's outer door moved on a refused corpse")
	var/turf/desk_front = get_step(prison.claim_turf, SOUTH)
	hunter.forceMove(desk_front)
	dead_catch.forceMove(desk_front)
	hunter.start_pulling(dead_catch)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	warden.open_trader_menu(hunter)
	TEST_ASSERT_EQUAL(length(warden_ears.lines), 1, "Clicking the warden while pulling a corpse spoke [length(warden_ears.lines)] lines instead of just the refusal")
	TEST_ASSERT(warden_ears.heard("We don't take bodies."), "Clicking the warden while pulling a corpse did not speak 'We don't take bodies.'")
	hunter.stop_pulling()
	hunter.forceMove(outer_wait)
	dead_posting.close("expired")

	var/mob/living/carbon/human/player_body = make_player(outer_wait, "lockupnotabounty")
	var/obj/item/restraints/handcuffs/body_cuffs = board_test_cuff(player_body)
	hunter.start_pulling(player_body)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened for a player body")
	TEST_ASSERT(warden_ears.heard("Nobody's asking for that one."), "Warden did not refuse a player body")
	hunter.stop_pulling()
	player_body.set_handcuffed(null)
	qdel(body_cuffs)
	player_body.key = null
	qdel(player_body)

	var/datum/criminal_bounty/decoy_posting = board_test_posting()
	var/mob/living/carbon/human/npc/bounty_criminal/decoy/decoy_mob = allocate(/mob/living/carbon/human/npc/bounty_criminal/decoy, outer_wait)
	decoy_mob.ai_controller?.set_ai_status(AI_STATUS_OFF)
	decoy_mob.body_setup(decoy_posting.record, decoy_posting)
	board_test_cuff(decoy_mob)
	hunter.start_pulling(decoy_mob)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened for a trader-outpost decoy")
	TEST_ASSERT(warden_ears.heard("Nobody's asking for that one."), "Warden did not refuse a decoy")
	hunter.stop_pulling()
	decoy_posting.close("expired")

	var/datum/criminal_bounty/kill_only/kill_posting = new
	kill_posting.record = bounty_kill_record("Lockup Kill Boss", "raiding", MALE, 4000, "test")
	kill_posting.placement_kind = "ruin"
	kill_posting.value = 4000
	kill_posting.expires_at = world.time + 60 MINUTES
	GLOB.criminal_bounties += kill_posting
	var/mob/living/carbon/human/npc/bounty_mafia/don/kill_boss = allocate(/mob/living/carbon/human/npc/bounty_mafia/don, outer_wait)
	kill_boss.ai_controller?.set_ai_status(AI_STATUS_OFF)
	kill_boss.posting_ref = WEAKREF(kill_posting)
	board_test_cuff(kill_boss)
	hunter.start_pulling(kill_boss)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened for a kill-only target")
	TEST_ASSERT(warden_ears.heard("Nobody's asking for that one."), "Warden did not refuse a kill-only target")
	hunter.stop_pulling()
	kill_posting.close("expired")

	var/datum/criminal_bounty/rival_offer = board_test_posting(2, rival_ship)
	var/mob/living/carbon/human/npc/bounty_criminal/rival_catch = board_test_criminal(rival_offer, outer_wait)
	board_test_cuff(rival_catch)
	hunter.start_pulling(rival_catch)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened for another ship's private offer")
	TEST_ASSERT(warden_ears.heard("Nobody's asking for that one."), "Warden did not refuse another ship's private offer")
	TEST_ASSERT_EQUAL(rival_offer.lockup_claim(prison, rival_catch, hunter), "that offer is for another crew", "lockup_claim() took another crew's private offer")
	hunter.stop_pulling()
	rival_offer.close("expired")

	// Multi-ship crew private offer: a posting offered to `away_ship` still resolves and pays `away_ship` even when `berthed_ship` is docked here
	var/datum/criminal_bounty/away_offer = board_test_posting(2, away_ship, 800, 0)
	var/datum/bounty_record/away_offer_record = away_offer.record
	var/mob/living/carbon/human/npc/bounty_criminal/away_catch = board_test_criminal(away_offer, outer_wait)
	board_test_cuff(away_catch)
	TEST_ASSERT_EQUAL(resolve_lockup_claim_ship(hunter, prison, away_offer), away_ship, "resolve_lockup_claim_ship() did not pick the crew hull named on a private offer")
	TEST_ASSERT_EQUAL(away_offer.lockup_claim(prison, away_catch, hunter), list(800, 0), "lockup_claim() refused a multi-ship crew's own private offer")
	TEST_ASSERT_EQUAL(away_ship.ship_account.account_balance, 800, "A private offer did not pay the crew hull it was offered to")
	TEST_ASSERT_EQUAL(berthed_ship.ship_account.account_balance, 0, "A private offer for away_ship paid berthed_ship instead")
	away_ship.ship_account.adjust_money(-800)
	bounty_pool_remove(away_offer_record, "closed")

	// Kingpin bound-crew refusal across all crew hulls (abuse 22 / decision 21)
	var/datum/criminal_bounty/kingpin/kp_posting = bounty_kingpin_new_posting(null)
	kp_posting.value = 1000
	kp_posting.expires_at = world.time + 60 MINUTES
	var/mob/living/carbon/human/npc/bounty_criminal/kingpin/kp_mob = allocate(/mob/living/carbon/human/npc/bounty_criminal/kingpin, outer_wait)
	kp_mob.ai_controller?.set_ai_status(AI_STATUS_OFF)
	kp_mob.body_setup(kp_posting.record, kp_posting)
	kp_posting.board_adopt_criminal(kp_mob, null, null, null)
	board_test_cuff(kp_mob)
	SSbounty_kingpin.kingpin_bound_ships |= WEAKREF(away_ship)
	hunter.start_pulling(kp_mob)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened for a kingpin pulled by a bound crew's second hull")
	TEST_ASSERT(warden_ears.heard("Nobody's asking for that one."), "Warden did not refuse a bound multi-hull crew's kingpin hand-in")
	TEST_ASSERT_EQUAL(kp_posting.lockup_claim(prison, kp_mob, hunter), "your crew works for him", "lockup_claim() let a bound crew's second hull turn in the kingpin")
	SSbounty_kingpin.kingpin_bound_ships -= WEAKREF(away_ship)
	SSbounty_kingpin.kingpin_bind(away_ship, null)
	TEST_ASSERT((WEAKREF(berthed_ship) in SSbounty_kingpin.kingpin_bound_ships) && (WEAKREF(hunter.mind) in SSbounty_kingpin.kingpin_bound_minds), "kingpin_bind() did not bind every hull and mind of the crew")
	TEST_ASSERT_EQUAL(kp_posting.lockup_claim(prison, kp_mob, hunter), "your crew works for him", "lockup_claim() let a kingpin_bind()-bound crew turn in the kingpin")
	hunter.stop_pulling()
	kp_posting.close("expired")
	SSbounty_kingpin.kingpin_reset()

	// Free uncuffed criminal: silent refusal, outer stays shut; warden away from desk also refuses
	var/datum/criminal_bounty/live_posting = board_test_posting(2, null, 1000, 1)
	var/datum/bounty_record/live_record = live_posting.record
	var/mob/living/carbon/human/npc/bounty_criminal/live_catch = board_test_criminal(live_posting, outer_wait)
	hunter.start_pulling(live_catch)
	warden_ears.lines.Cut()
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened for a standing free criminal")
	TEST_ASSERT_EQUAL(length(warden_ears.lines), 0, "A free criminal triggered a warden refusal bark")

	var/obj/item/restraints/handcuffs/hunter_cuffs = board_test_cuff(live_catch)
	hunter_cuffs.add_fingerprint(hunter)
	warden.forceMove(inmate_test_front_tile(prison))
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened while the warden was away from his desk")
	warden.forceMove(prison.desk_turf)
	warden.Knockdown(10 SECONDS)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened while the warden was knocked down")
	warden.SetKnockdown(0)
	warden.set_resting(FALSE)

	// Valid restrained hand-in: outer opens (inner stays shut), only hunter and catch may step in, 10s prompt fires once while hunter lingers
	TEST_ASSERT(prison.try_start_processing_claim(hunter), "Processing did not open for a cuffed Wanted criminal")
	TEST_ASSERT_EQUAL(prison.processing_state, "claiming", "Processing did not enter claiming state") // OUTPOST_PROCESSING_CLAIM
	TEST_ASSERT(claim_wait_door(prison, outer, TRUE), "Processing's outer door never opened for the bounty claim")
	TEST_ASSERT(inner.density && !inner.operating, "Processing's inner door opened during a bounty claim")
	var/mob/living/carbon/human/bystander = make_player(inmate_test_front_tile(prison), "lockupclaimbystander")
	TEST_ASSERT(outer.lets_prisoner(hunter) && outer.lets_prisoner(live_catch), "Processing's outer door blocked the hunter or catch it opened for")
	TEST_ASSERT(!outer.lets_prisoner(bystander), "Processing's outer door let a bystander step in during a claim")
	bystander.key = null
	qdel(bystander)

	var/turf/door_processing_tile = get_dist(prison.processing_turfs[1], outer) == 1 ? prison.processing_turfs[1] : prison.processing_turfs[2]
	var/turf/back_processing_tile = door_processing_tile == prison.processing_turfs[1] ? prison.processing_turfs[2] : prison.processing_turfs[1]
	hunter.stop_pulling()
	live_catch.forceMove(door_processing_tile)
	hunter.forceMove(back_processing_tile)
	live_catch.set_combat_mode(TRUE)
	hunter.set_combat_mode(TRUE)
	hunter.Move(door_processing_tile, get_dir(back_processing_tile, door_processing_tile))
	TEST_ASSERT_EQUAL(get_turf(hunter), door_processing_tile, "A hunter in combat mode was trapped in Processing's dead-end tile behind a standing cuffed catch")
	TEST_ASSERT_EQUAL(get_turf(live_catch), back_processing_tile, "Swapping past the cuffed catch inside Processing did not move the catch to the back tile")
	hunter.set_combat_mode(FALSE)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	prison.processing_tick(9)
	TEST_ASSERT(!warden_ears.heard("Step out."), "Warden told the hunter to step out before 10 seconds")
	TEST_ASSERT(!QDELETED(live_catch) && live_posting.is_open(), "Claim completed while the hunter was still inside Processing")
	prison.processing_tick(1)
	TEST_ASSERT(warden_ears.heard("Step out."), "Warden did not say 'Step out.' at 10 seconds")
	var/step_out_count = length(warden_ears.lines)
	COOLDOWN_RESET(warden, speak_cooldown)
	prison.processing_tick(10)
	TEST_ASSERT_EQUAL(length(warden_ears.lines), step_out_count, "Warden repeated 'Step out.' on subsequent ticks")
	TEST_ASSERT(!QDELETED(live_catch) && live_posting.is_open(), "Claim completed while the hunter lingered past 10 seconds")

	// Hunter steps out into the front room via real Move(): outer shuts, posting closes, berthed ship gets 1000 cr, claim_turf gets voucher + poster + cuffs, record is reserved for this prison
	TEST_ASSERT(hunter.Move(get_turf(outer), get_dir(door_processing_tile, outer)), "Hunter could not step onto the open Processing doorway")
	TEST_ASSERT(hunter.Move(outer_wait, get_dir(outer, outer_wait)), "Hunter could not step out of Processing into the front room")
	warden_ears.lines.Cut()
	var/vouchers_before = board_test_vouchers(prison.claim_turf)
	TEST_ASSERT(claim_wait_door(prison, outer, FALSE), "Processing's outer door did not shut once the hunter stepped out")
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing did not return to idle after completing the claim")
	TEST_ASSERT(QDELETED(live_posting), "The bounty posting stayed open after live hand-in")
	TEST_ASSERT(QDELETED(live_catch), "The bounty criminal mob was not deleted inside closed Processing")
	TEST_ASSERT_EQUAL(berthed_ship.ship_account.account_balance, 1000, "The berthed crew ship did not receive the 1000 cr payout")
	TEST_ASSERT_EQUAL(away_ship.ship_account.account_balance, 0, "The unberthed crew ship was paid instead of the berthed one")
	TEST_ASSERT_EQUAL(board_test_vouchers(prison.claim_turf) - vouchers_before, 1, "The trade voucher did not drop on claim_turf")
	TEST_ASSERT_NOTNULL(locate(/obj/item/paper/bounty_captured) in prison.claim_turf, "The CAPTURED poster did not drop on claim_turf")
	TEST_ASSERT_EQUAL(hunter_cuffs.loc, prison.claim_turf, "The hunter's handcuffs were not returned to claim_turf")
	TEST_ASSERT(warden_ears.heard("Cuffed and breathing. Paid to the [berthed_ship.name]."), "Warden did not speak the clean live payout line: [warden_ears.lines.Join(" | ")]")
	TEST_ASSERT(live_record in GLOB.bounty_prisoner_pool, "The claimed criminal's record did not enter GLOB.bounty_prisoner_pool")
	TEST_ASSERT_EQUAL(bounty_record_reserved_for(live_record), prison, "The pooled record was not reserved for the lockup that took them in")

	// Abuse 21: double-claim on closed posting is refused, and once admitted into the yard as an outpost_prisoner they have no posting and cannot be handed in again
	TEST_ASSERT_EQUAL(live_posting.lockup_claim(prison, null, hunter), "that bounty is closed", "A closed posting did not refuse a second lockup_claim()")
	var/mob/living/carbon/human/npc/outpost_prisoner/admitted_inmate = prison.bounty_admit_record(live_record)
	TEST_ASSERT_NOTNULL(admitted_inmate, "The lockup could not admit its reserved bounty prisoner from the pool")
	TEST_ASSERT(!(live_record in GLOB.bounty_prisoner_pool) && live_record.status == "imprisoned", "Admitting the pooled record did not move it to imprisoned") // BOUNTY_RECORD_IMPRISONED
	admitted_inmate.forceMove(outer_wait)
	var/obj/item/restraints/handcuffs/re_cuffs = board_test_cuff(admitted_inmate)
	hunter.start_pulling(admitted_inmate)
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened to re-claim an already-imprisoned outpost_prisoner")
	TEST_ASSERT(warden_ears.heard("Nobody's asking for that one."), "Warden did not refuse an already-imprisoned outpost_prisoner")
	hunter.stop_pulling()
	admitted_inmate.set_handcuffed(null)
	qdel(re_cuffs)
	admitted_inmate.forceMove(admitted_inmate.cell.arrival_turf())

	// Reservation fallback + \improper ship-name stripping: if the preferred wing has had no ready cell for 3 minutes, another wing may take the record
	var/datum/criminal_bounty/fallback_posting = board_test_posting(2, null, 1000, 0)
	var/datum/bounty_record/fallback_record = fallback_posting.record
	var/mob/living/carbon/human/npc/bounty_criminal/fallback_catch = board_test_criminal(fallback_posting, outer_wait)
	board_test_cuff(fallback_catch)
	berthed_ship.name = "\improper ISS Berthed"
	warden_ears.lines.Cut()
	TEST_ASSERT(islist(fallback_posting.lockup_claim(prison, fallback_catch, hunter)), "Fallback setup lockup_claim() failed")
	TEST_ASSERT_EQUAL(fallback_record.captor_name, "ISS Berthed", "lockup_claim() leaked \\improper into captor_name")
	TEST_ASSERT(warden_ears.heard("Cuffed and breathing. Paid to the ISS Berthed."), "Warden payout line leaked \\improper on ship name: [warden_ears.lines.Join(" | ")]")
	berthed_ship.name = "ISS Berthed"
	TEST_ASSERT_EQUAL(bounty_record_reserved_for(fallback_record), prison, "Fallback record did not start reserved for prison")
	prison.prison_bounty_no_cell_since = world.time - 3 MINUTES // BOUNTY_RECORD_RESERVE_NO_CELL
	TEST_ASSERT_NULL(bounty_record_reserved_for(fallback_record), "Reservation did not release after 3 minutes with no ready cell")
	prison.prison_bounty_no_cell_since = null
	bounty_pool_remove(fallback_record, "closed")

	// Downed catch: 60% credit payout, 0 vouchers, no CAPTURED poster, and 'Barely breathing.' line
	for(var/obj/item/paper/bounty_captured/old_poster in prison.claim_turf)
		qdel(old_poster)
	var/datum/criminal_bounty/downed_posting = board_test_posting(2, null, 1000, 1) // offered = 2200 cr; 60% = 1320
	var/mob/living/carbon/human/npc/bounty_criminal/downed_catch = board_test_criminal(downed_posting, outer_wait)
	bounty_test_hurt_to(downed_catch, -10)
	TEST_ASSERT_EQUAL(downed_catch.capture_state(), "downed", "Hurt criminal did not read downed") // BOUNTY_STATE_DOWNED
	warden_ears.lines.Cut()
	var/balance_before_downed = berthed_ship.ship_account.account_balance
	vouchers_before = board_test_vouchers(prison.claim_turf)
	var/list/downed_paid = downed_posting.lockup_claim(prison, downed_catch, hunter)
	TEST_ASSERT_EQUAL(downed_paid, list(1320, 0), "Downed catch did not return list(1320, 0)")
	TEST_ASSERT_EQUAL(berthed_ship.ship_account.account_balance - balance_before_downed, 1320, "Downed catch did not pay 60% (1320 cr)")
	TEST_ASSERT_EQUAL(board_test_vouchers(prison.claim_turf) - vouchers_before, 0, "Downed catch dropped a trade voucher")
	TEST_ASSERT_NULL(locate(/obj/item/paper/bounty_captured) in prison.claim_turf, "Downed catch printed a CAPTURED poster")
	TEST_ASSERT(warden_ears.heard("Barely breathing. Paid to the [berthed_ship.name]."), "Warden did not speak the downed payout line")

	// Fireman-carried catch at the desk + free inside Processing before outer shuts: aborts without entombing live occupants, lets hunter step back in to re-cuff, and returns Processing to idle once emptied
	var/datum/criminal_bounty/escape_posting = board_test_posting(2, null, 1000, 1)
	var/mob/living/carbon/human/npc/bounty_criminal/escape_catch = board_test_criminal(escape_posting, desk_front)
	var/obj/item/restraints/handcuffs/escape_cuffs = board_test_cuff(escape_catch)
	hunter.forceMove(desk_front)
	TEST_ASSERT(hunter.buckle_mob(escape_catch, force = TRUE, check_loc = FALSE), "Could not fireman-carry escape_catch for desk hand-in check")
	warden_ears.lines.Cut()
	COOLDOWN_RESET(warden, speak_cooldown)
	warden.open_trader_menu(hunter)
	TEST_ASSERT_EQUAL(prison.processing_state, "claiming", "Clicking the warden while fireman-carrying a cuffed catch did not open Processing")
	TEST_ASSERT(warden_ears.heard("In you go."), "Warden did not say 'In you go.' when opening Processing at the desk")
	TEST_ASSERT(claim_wait_door(prison, outer, TRUE), "Outer door did not open for escape-in-Processing check")
	hunter.unbuckle_mob(escape_catch, force = TRUE)
	hunter.forceMove(outer_wait)
	escape_catch.forceMove(prison.processing_turfs[1])
	escape_catch.set_handcuffed(null)
	qdel(escape_cuffs)
	TEST_ASSERT_EQUAL(escape_catch.capture_state(), "free", "Uncuffed criminal inside Processing did not read free") // BOUNTY_STATE_FREE
	var/balance_before_escape = berthed_ship.ship_account.account_balance
	prison.processing_tick(1)
	TEST_ASSERT(prison.claim_aborting, "A criminal breaking free inside Processing did not abort the claim")
	TEST_ASSERT(outer.lets_prisoner(hunter), "An aborting claim locked the hunter out from retrieving or re-cuffing their catch")
	prison.processing_tick(65)
	TEST_ASSERT(prison.claim_aborting && !outer.density, "An aborting claim slammed outer shut on a live occupant after 60 seconds")
	var/obj/item/restraints/handcuffs/recuffs = board_test_cuff(escape_catch)
	prison.processing_tick(1)
	TEST_ASSERT(!prison.claim_aborting, "Re-cuffing an escaped catch inside Processing did not resume the claim")
	escape_catch.set_handcuffed(null)
	qdel(recuffs)
	prison.processing_tick(1)
	TEST_ASSERT(prison.claim_aborting, "Removing cuffs again did not re-enter claim_aborting")
	TEST_ASSERT(escape_posting.is_open() && !QDELETED(escape_catch), "Aborting a claim closed the posting or deleted the criminal")
	TEST_ASSERT_EQUAL(berthed_ship.ship_account.account_balance, balance_before_escape, "An aborted claim paid credits")
	escape_catch.forceMove(outer_wait)
	TEST_ASSERT(claim_wait_door(prison, outer, FALSE), "Outer door did not shut after the escaped criminal left Processing")
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing did not return to idle after aborting a claim")
	escape_posting.close("expired")

	// Drifter with no ship: holochip + trade voucher drop on claim_turf, ship-only captor_name stays null, and warden speaks 'No ship on file. Take the chip.'
	for(var/obj/item/holochip/old_chip in prison.claim_turf)
		qdel(old_chip)
	var/mob/living/carbon/human/drifter = make_player(outer_wait, "lockupclaimdrifter")
	var/datum/criminal_bounty/drifter_posting = board_test_posting(2, null, 1000, 1)
	var/datum/bounty_record/drifter_record = drifter_posting.record
	var/mob/living/carbon/human/npc/bounty_criminal/drifter_catch = board_test_criminal(drifter_posting, outer_wait)
	board_test_cuff(drifter_catch)
	warden_ears.lines.Cut()
	vouchers_before = board_test_vouchers(prison.claim_turf)
	var/list/drifter_paid = drifter_posting.lockup_claim(prison, drifter_catch, drifter)
	TEST_ASSERT_EQUAL(drifter_paid, list(1000, 1), "Drifter lockup_claim() did not pay full credits and voucher")
	TEST_ASSERT_NULL(drifter_record.captor_name, "A shipless drifter stamped their personal name into ship-only captor_name")
	bounty_pool_remove(drifter_record, "closed")
	var/obj/item/holochip/chip = locate() in prison.claim_turf
	TEST_ASSERT_NOTNULL(chip, "Drifter lockup_claim() did not drop a holochip on claim_turf")
	TEST_ASSERT_EQUAL(chip.credits, 1000, "Drifter holochip held [chip.credits] cr instead of 1000")
	TEST_ASSERT_EQUAL(board_test_vouchers(prison.claim_turf) - vouchers_before, 1, "Drifter lockup_claim() did not drop its voucher on claim_turf")
	TEST_ASSERT(warden_ears.heard("No ship on file. Take the chip."), "Warden did not speak the drifter holochip line")

	// Breached-open outer door + ambient mouse in Processing: claim can still start, mend_hack() shuts outer once the hunter steps out, and the claim settles
	var/mob/living/basic/mouse/proc_mouse = allocate(/mob/living/basic/mouse, prison.processing_turfs[2])
	proc_mouse.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/obj/item/card/emag/doorjack/claim_jack = allocate(/obj/item/card/emag/doorjack, drifter)
	TEST_ASSERT(outer.emag_act(drifter, claim_jack), "Could not doorjack Processing's outer door for breached-claim check")
	sleep(2.5 SECONDS)
	TEST_ASSERT(!outer.density && (outer.obj_flags & EMAGGED), "Processing's outer door did not open from the doorjack")
	outpost.police?.admin_lift(drifter.mind)
	dispatch_clear(outpost.police)
	var/datum/criminal_bounty/breach_posting = board_test_posting(2, null, 900, 0)
	var/datum/bounty_record/breach_record = breach_posting.record
	var/mob/living/carbon/human/npc/bounty_criminal/breach_catch = board_test_criminal(breach_posting, outer_wait)
	board_test_cuff(breach_catch)
	hunter.start_pulling(breach_catch)
	TEST_ASSERT(prison.try_start_processing_claim(hunter), "Processing refused to start a claim while outer was doorjacked open or a mouse was inside")
	hunter.stop_pulling()
	breach_catch.forceMove(prison.processing_turfs[1])
	hunter.forceMove(outer_wait)
	TEST_ASSERT(!outer.lockup_hack.processing_exit_blocked(), "Active non-aborting bounty catch or mouse blocked outer.mend_hack()")
	outer.mend_hack()
	TEST_ASSERT(claim_wait_door(prison, outer, FALSE), "Mended outer Processing door did not shut on a cuffed catch and a mouse")
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing did not finish a claim after outer mended shut")
	TEST_ASSERT(QDELETED(breach_posting) && QDELETED(breach_catch), "Claim after outer mended shut did not settle the posting and criminal")
	bounty_pool_remove(breach_record, "closed")
	qdel(proc_mouse)
	qdel(claim_jack)

	// Dead warden at the desk: Processing outer door refuses to open for a cuffed catch
	var/datum/criminal_bounty/no_warden_posting = board_test_posting(2, null, 1000, 1)
	var/mob/living/carbon/human/npc/bounty_criminal/no_warden_catch = board_test_criminal(no_warden_posting, outer_wait)
	board_test_cuff(no_warden_catch)
	warden.death()
	TEST_ASSERT_NULL(prison.warden_at_desk(), "A dead warden still counted as warden_at_desk()")
	hunter.start_pulling(no_warden_catch)
	TEST_ASSERT(!prison.try_start_processing_claim(hunter), "Processing opened while the warden was dead")
	TEST_ASSERT(outer.density && !outer.operating, "Processing's outer door moved while the warden was dead")
	hunter.stop_pulling()
	no_warden_posting.close("expired")
	outpost.recovery?.sleep_tick()

	drifter.key = null
	qdel(drifter)
	hunter.key = null
	qdel(hunter)

// =========================================================================
// 3. SHIP MISSION PAD SPLIT: LIVE REFUSED, DEAD / PROOF / TROPHY ACCEPTED
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_pad_split
	var/obj/structure/overmap/ship/split_hull

/datum/unit_test/voidcrew_trade_prison_pad_split/New()
	. = ..()
	board_test_begin()

/datum/unit_test/voidcrew_trade_prison_pad_split/Destroy()
	board_test_end()
	if(!QDELETED(split_hull))
		qdel(split_hull)
	split_hull = null
	return ..()

/datum/unit_test/voidcrew_trade_prison_pad_split/Run()
	var/obj/structure/overmap/ship/ship = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(ship, "The test hull did not load")
	split_hull = ship
	var/turf/deck
	for(var/turf/tile as anything in ship.shuttle.return_turfs())
		if(isfloorturf(tile) && (get_area(tile) in ship.shuttle.shuttle_areas) && !tile.is_blocked_turf(exclude_mobs = TRUE) && !(locate(/obj/machinery) in tile))
			deck = tile
			break
	TEST_ASSERT_NOTNULL(deck, "The test hull has no free deck")
	var/obj/machinery/mission_pad/pad = new(deck)

	// Live restrained criminal on a bolted ship pad: refused everywhere with 'Alive. The lockup takes those.'
	var/datum/criminal_bounty/live_posting = board_test_posting()
	var/mob/living/carbon/human/npc/bounty_criminal/live_catch = board_test_criminal(live_posting, deck)
	board_test_cuff(live_catch)
	live_catch.forceMove(deck)
	var/list/found = list()
	TEST_ASSERT_EQUAL(live_posting.board_target_refusal(pad, found), "Alive. The lockup takes those.", "board_target_refusal() did not refuse a live catch on the ship pad")
	var/list/preview = live_posting.board_pad_preview(ship, pad)
	TEST_ASSERT(!preview[1] && preview[2] == "restrained" && preview[3] == "Alive. The lockup takes those.", "board_pad_preview() did not report restrained + lockup refusal")
	var/pad_line = pad.bounty_pad_line(live_catch)
	TEST_ASSERT(findtext(pad_line, "Alive. The lockup takes those.") && !findtext(pad_line, ".."), "bounty_pad_line() malformed the lockup refusal: [pad_line]")
	var/balance_before = ship.ship_account.account_balance
	TEST_ASSERT_EQUAL(live_posting.turn_in(pad, ship), "Alive. The lockup takes those.", "turn_in() on the ship pad did not refuse a live catch")
	TEST_ASSERT(live_posting.is_open() && !QDELETED(live_catch) && ship.ship_account.account_balance == balance_before, "A refused live pad turn-in altered the posting, criminal or balance")

	// Dead criminal on the ship pad: still pays 25% (550 cr of 2200 offered)
	live_catch.death()
	live_catch.forceMove(deck)
	var/list/dead_paid = live_posting.turn_in(pad, ship)
	TEST_ASSERT_EQUAL(dead_paid, list(550, 0), "Dead criminal on the ship pad did not pay 25% (550 cr)")

	// Bounty proof tag on the ship pad: still pays 25% (550 cr)
	var/datum/criminal_bounty/proof_posting = board_test_posting()
	var/mob/living/carbon/human/npc/bounty_criminal/proof_catch = board_test_criminal(proof_posting, run_loc_floor_bottom_left)
	proof_catch.death()
	var/obj/item/bounty_proof/tag = proof_posting.board_proof()
	TEST_ASSERT_NOTNULL(tag, "Dead criminal dropped no bounty_proof tag")
	tag.forceMove(deck)
	var/list/proof_paid = proof_posting.turn_in(pad, ship)
	TEST_ASSERT_EQUAL(proof_paid, list(550, 0), "Bounty proof tag on the ship pad did not pay 25% (550 cr)")

	// Kill-only lair trophy on the ship pad: still pays 100% + vouchers
	var/datum/criminal_bounty/kill_only/lair/lair_posting = new
	lair_posting.record = bounty_kill_record("Pad Split Boss", "extortion", MALE, 4000, "test")
	lair_posting.placement_kind = "ruin"
	lair_posting.value = 4000
	lair_posting.board_vouchers = 2
	lair_posting.board_zone = 1
	lair_posting.expires_at = world.time + 60 MINUTES
	GLOB.criminal_bounties += lair_posting
	var/obj/item/bounty_proof/trophy/trophy = lair_posting.kill_drop_trophy(deck)
	var/vouchers_before = board_test_vouchers(deck)
	var/list/trophy_paid = lair_posting.turn_in(pad, ship)
	TEST_ASSERT_EQUAL(trophy_paid, list(4000, 2), "Kill-only trophy on the ship pad did not pay 100% + vouchers")
	TEST_ASSERT(QDELETED(trophy) && QDELETED(lair_posting), "Kill-only trophy turn-in left trophy or posting behind")
	TEST_ASSERT_EQUAL(board_test_vouchers(deck) - vouchers_before, 2, "Kill-only trophy turn-in did not drop its 2 vouchers")

// =========================================================================
// 4. ADMIN MANIPULATOR & LOCKUP ROUND METRICS
// =========================================================================

/datum/unit_test/voidcrew_trade_prison_admin_and_metrics
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/saved_accepting = FALSE
	var/saved_max_pending = 5000
	var/list/saved_pending
	var/list/saved_tallies

/datum/unit_test/voidcrew_trade_prison_admin_and_metrics/Destroy()
	if(!isnull(saved_pending))
		SSmetrics.accepting = saved_accepting
		SSmetrics.max_pending = saved_max_pending
		SSmetrics.pending = saved_pending
		SSmetrics.tallies = saved_tallies
		saved_pending = null
		saved_tallies = null
	board_test_end()
	return ..()

/datum/unit_test/voidcrew_trade_prison_admin_and_metrics/proc/lockup_panel_act(datum/outpost_manipulator/panel, mob/user, action, list/params = list())
	var/datum/tgui/ui = allocate(/datum/tgui, user, panel, "OutpostManipulator")
	world.push_usr(user, CALLBACK(panel, TYPE_PROC_REF(/datum, ui_act), action, params, ui))

/datum/unit_test/voidcrew_trade_prison_admin_and_metrics/proc/find_lockup_metric(event_type)
	for(var/list/row as anything in SSmetrics.pending)
		if(row["category"] == "lockup" && row["event"] == event_type) // METRIC_LOCKUP
			return row
	return null

/datum/unit_test/voidcrew_trade_prison_admin_and_metrics/Run()
	board_test_begin()
	saved_accepting = SSmetrics.accepting
	saved_max_pending = SSmetrics.max_pending
	saved_pending = SSmetrics.pending
	saved_tallies = SSmetrics.tallies
	SSmetrics.accepting = TRUE
	SSmetrics.max_pending = 5000
	SSmetrics.pending = list()
	SSmetrics.tallies = list()

	var/obj/structure/overmap/trader_outpost/prison_test_host/unit_test_host = prison_test_claim("lockupadminmetrics")
	TEST_ASSERT_NOTNULL(unit_test_host, "Fixture wing did not load")
	var/datum/outpost_prison/prison = test_prison(unit_test_host)
	var/turf/yard_tile = prison_spot(unit_test_host, 9, 9)
	var/turf/desk_spot = prison_spot(unit_test_host, 8, 4)
	prison.desk_turf = desk_spot
	unit_test_host.prison = prison
	TEST_ASSERT_EQUAL(get_trader_outpost_for_turf(desk_spot), unit_test_host, "get_trader_outpost_for_turf() did not find an un-templated host through outpost.prison")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/host_warden = prison.ensure_warden()
	TEST_ASSERT_NOTNULL(host_warden, "Fixture lockup did not spawn a warden at desk_spot")
	TEST_ASSERT(unit_test_host.ensure_recovery().keeper_on_post(host_warden), "The lockup warden on an un-templated host with police did not count as keeper_on_post()")
	unit_test_host.recovery?.sleep_tick()
	prison.warden_destroy()
	var/mob/living/carbon/human/operator = make_player(yard_tile, "lockupadminop")
	var/mob/living/carbon/human/subject = make_player(yard_tile, "lockupadminsubj")

	// Outpost Manipulator lockup list, selection, jump, admin player booking without a warrant, early release, and audience override
	var/datum/outpost_manipulator/unit_test/panel = allocate(/datum/outpost_manipulator/unit_test, operator)
	var/list/top_data = panel.ui_data(operator)
	var/found_lockup = FALSE
	for(var/list/entry as anything in top_data["lockups"])
		if(entry["ref"] == REF(prison))
			found_lockup = TRUE
			break
	TEST_ASSERT(found_lockup, "Outpost Manipulator ui_data() did not list the trader-outpost lockup")

	lockup_panel_act(panel, operator, "select_lockup", list("ref" = REF(prison)))
	var/list/selected_data = panel.ui_data(operator)["selected_lockup"]
	TEST_ASSERT_NOTNULL(selected_data, "Selecting a lockup did not populate selected_lockup")
	TEST_ASSERT_EQUAL(selected_data["ref"], REF(prison), "selected_lockup pointed at the wrong prison")

	lockup_panel_act(panel, operator, "lockup_jump")
	TEST_ASSERT_EQUAL(get_turf(operator), desk_spot, "lockup_jump did not move the admin to desk_turf")
	operator.forceMove(yard_tile)

	var/mob/living/carbon/human/npc/bounty_criminal/minded_npc = allocate(/mob/living/carbon/human/npc/bounty_criminal, yard_tile)
	minded_npc.ai_controller?.set_ai_status(AI_STATUS_OFF)
	minded_npc.mind_initialize()
	allocated += minded_npc.mind
	TEST_ASSERT(!prison.admin_book_player(minded_npc, 60), "admin_book_player() accepted a human NPC")
	lockup_panel_act(panel, operator, "prison_book_player", list("ref" = REF(minded_npc), "seconds" = 60))
	TEST_ASSERT(!prison.is_inmate(minded_npc), "prison_book_player panel action booked a human NPC")
	qdel(minded_npc)

	var/obj/structure/overmap/trader_outpost/other_outpost = lockup_test_outpost()
	var/datum/outpost_prison/other_prison = other_outpost.prison
	var/datum/outpost_police/other_police = other_outpost.police
	TEST_ASSERT(other_prison.admin_book_player(subject, 120), "Could not book subject into Quartermain's lockup for transfer check")
	var/obj/item/uniform_before_rebook = subject.w_uniform
	TEST_ASSERT_NOTNULL(uniform_before_rebook, "Booked inmate had no prison uniform")
	TEST_ASSERT(other_prison.admin_book_player(subject, 240), "Could not re-book an already-held inmate")
	TEST_ASSERT_EQUAL(subject.w_uniform, uniform_before_rebook, "Re-booking an already-held inmate stripped their prison uniform into a locker")

	lockup_panel_act(panel, operator, "prison_book_player", list("ref" = REF(subject), "seconds" = 180))
	TEST_ASSERT(prison.is_inmate(subject), "prison_book_player did not book the target player")
	TEST_ASSERT(!other_prison.holds(subject.mind), "Transferring an inmate via prison_book_player left custody active on the old lockup")
	other_prison.inmate_tick(1)
	TEST_ASSERT_EQUAL(other_police.get_stars(subject.mind), 0, "Transferring an inmate to another lockup filed false jailbreak stars at the old lockup")
	var/datum/prison_sentence/sentence = prison.sentences[subject.mind]
	TEST_ASSERT(sentence?.admin_booked && sentence.remaining_seconds() == 180, "Admin-booked sentence did not set admin_booked or 180s duration")
	prison.inmate_tick(10)
	TEST_ASSERT(prison.is_inmate(subject) && sentence.remaining_seconds() == 170, "Admin-booked inmate without a police warrant was dropped on inmate_tick()")

	// Work completion metric (lockup_worked_off) + early release via panel
	TEST_ASSERT_EQUAL(prison.note_work(subject, "wash", "tray_load_1"), 30, "note_work() did not credit 30s for a wash load") // OUTPOST_PRISON_WORK_WASH
	lockup_panel_act(panel, operator, "prison_release_inmate", list("ref" = REF(subject.mind)))
	TEST_ASSERT(!prison.is_inmate(subject), "prison_release_inmate did not release the booked inmate")

	prison.trouble_enabled = TRUE
	var/mob/living/carbon/human/npc/outpost_prisoner/rioter_a = trouble_prisoner(prison, yard_tile)
	var/mob/living/carbon/human/npc/outpost_prisoner/rioter_b = trouble_prisoner(prison, yard_tile)
	lockup_panel_act(panel, operator, "prison_audience", list("mode" = "off"))
	TEST_ASSERT_EQUAL(prison.audience_override, FALSE, "prison_audience 'off' did not set audience_override = FALSE")
	TEST_ASSERT_EQUAL(rioter_a.ai_controller.ai_status, AI_STATUS_OFF, "prison_audience 'off' did not immediately reconcile prisoner AI off")
	lockup_panel_act(panel, operator, "prison_audience", list("mode" = "auto"))
	TEST_ASSERT_NULL(prison.audience_override, "prison_audience 'auto' did not reset audience_override = null")
	lockup_panel_act(panel, operator, "prison_audience", list("mode" = "on"))
	TEST_ASSERT_EQUAL(prison.audience_override, TRUE, "prison_audience 'on' did not set audience_override = TRUE")
	TEST_ASSERT_EQUAL(rioter_a.ai_controller.ai_status, AI_STATUS_ON, "prison_audience 'on' did not immediately reconcile prisoner AI on")

	// Remaining lockup metrics: served, escape, break_in, riot, bounty_claimed_live, bounty_claimed_dead
	TEST_ASSERT(prison.admin_book_player(subject, 5), "Could not re-book subject for lockup_served metric check")
	prison.inmate_tick(5)
	TEST_ASSERT(!prison.is_inmate(subject), "5s admin sentence did not expire after 5s")

	record_lockup_escape(prison, subject, "inmate")
	var/datum/outpost_prison_cell/first_cell = prison.cells[1]
	var/obj/machinery/door/airlock/cell_door = first_cell.door()
	TEST_ASSERT_NOTNULL(cell_door, "Cell 1 has no cell airlock")
	record_lockup_break_in(prison, cell_door, operator)

	rioter_a.set_mood(0)
	rioter_b.set_mood(0)
	TEST_ASSERT(prison.start_riot(), "start_riot() did not start a riot for metric verification")
	prison.admin_calm()

	var/obj/structure/overmap/ship/metric_ship = board_test_ship(0)
	var/mob/living/carbon/human/hunter = board_test_hunter(metric_ship, yard_tile)
	prison.claim_turf = yard_tile
	var/datum/criminal_bounty/live_posting = board_test_posting(2, null, 1000, 1)
	var/mob/living/carbon/human/npc/bounty_criminal/live_catch = board_test_criminal(live_posting, yard_tile)
	board_test_cuff(live_catch)
	TEST_ASSERT(islist(live_posting.lockup_claim(prison, live_catch, hunter)), "lockup_claim() failed in metric check")

	var/obj/machinery/mission_pad/pad = allocate(/obj/machinery/mission_pad, yard_tile)
	var/datum/criminal_bounty/dead_posting = board_test_posting(2, null, 1000, 0)
	var/mob/living/carbon/human/npc/bounty_criminal/dead_catch = board_test_criminal(dead_posting, yard_tile)
	dead_catch.death()
	TEST_ASSERT(islist(dead_posting.board_claim(metric_ship, pad, dead_catch, "dead")), "Dead board_claim() failed in metric check")

	SSmetrics.fold_tallies()
	for(var/expected_event in list("lockup_booked", "lockup_served", "lockup_worked_off", "lockup_escape", "lockup_break_in", "lockup_riot", "bounty_claimed_live", "bounty_claimed_dead"))
		TEST_ASSERT_NOTNULL(find_lockup_metric(expected_event), "Expected lockup metric '[expected_event]' was not recorded")

	settle_prison_air(unit_test_host)
