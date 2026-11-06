/// Backgrounds: owned by P2.

// Tests for the convict background and the Meridian Penitentiary. Unit tests compile before the
// voidcrew defines, so values are literals with the define named beside them:
// "convict" BACKGROUND_CONVICT, "pirate" BACKGROUND_PIRATE, 2 ZONE_YELLOW, "dead" BOUNTY_STATE_DEAD,
// "background_convict" TRAIT_BACKGROUND_CONVICT, "background" BACKGROUND_TRAIT.
// The map tests skip with a notice while P0's placeholder map (fewer than 12 NPC cells) is in.

/datum/unit_test/voidcrew_bg_convict
	abstract_type = /datum/unit_test/voidcrew_bg_convict
	/// Minds made by the test, whose warrants, ledgers, lockers and states are cleared after it
	var/list/datum/mind/test_minds = list()

/datum/unit_test/voidcrew_bg_convict/Destroy()
	for(var/datum/mind/mind as anything in test_minds)
		if(!mind)
			continue
		for(var/datum/criminal_bounty/warrant/warrant in GLOB.background_warrants.Copy())
			if(warrant.target() == mind)
				qdel(warrant)
		var/mind_ckey = ckey(mind.key)
		if(mind_ckey)
			GLOB.background_ledger -= mind_ckey
			GLOB.penitentiary_last_pods -= mind_ckey
		var/obj/structure/closet/secure_closet/penitentiary_evidence/locker = GLOB.penitentiary?.evidence_locker_for(mind)
		locker?.release()
		GLOB.background_minds -= mind
	test_minds.Cut()
	return ..()

/// A human with a mind and a fake ckey, cleaned up after the test
/datum/unit_test/voidcrew_bg_convict/proc/test_human(turf/where)
	var/mob/living/carbon/human/person = bg_test_human(where || run_loc_floor_bottom_left)
	test_minds += person.mind
	return person

/// The live Penitentiary when its real map is in, else null (the test then skips with a notice)
/datum/unit_test/voidcrew_bg_convict/proc/full_site()
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	if(!site?.loaded || length(site.prison?.cells) < 12)
		return null
	return site

// ===== THE MAP (map-contracts.md M1) =====

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_map

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_map/Run()
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	TEST_ASSERT_NOTNULL(site, "No Meridian Penitentiary was placed at SSovermap init")
	TEST_ASSERT(site.loaded, "The Penitentiary's interior did not load")
	if(!full_site())
		TEST_NOTICE(src, "Skipped: the Penitentiary map is still P0's placeholder (fewer than 12 NPC cells). Runs once M1 lands.")
		return
	TEST_ASSERT_EQUAL(length(site.lobby_alcove_turfs), 9, "The Visitor Hall needs exactly 9 lift alcove tiles")
	var/min_x = INFINITY
	var/max_x = -INFINITY
	var/min_y = INFINITY
	var/max_y = -INFINITY
	for(var/turf/alcove as anything in site.lobby_alcove_turfs)
		min_x = min(min_x, alcove.x)
		max_x = max(max_x, alcove.x)
		min_y = min(min_y, alcove.y)
		max_y = max(max_y, alcove.y)
	TEST_ASSERT(max_x - min_x == 2 && max_y - min_y == 2, "The lift alcove is not one 3x3 block")
	TEST_ASSERT_EQUAL(length(site.lobby_panels), 1, "The Visitor Hall needs exactly one lift panel")
	TEST_ASSERT_EQUAL(length(site.prison.cells), 12, "The General Population wing needs 12 NPC cells")
	for(var/datum/outpost_prison_cell/cell as anything in site.prison.cells)
		TEST_ASSERT(length(cell.turfs) <= 16, "NPC cell [cell.number] is larger than 16 tiles")
		TEST_ASSERT_NOTNULL(cell.bed(), "NPC cell [cell.number] has no bed")
	TEST_ASSERT_EQUAL(length(site.escape_cells), 8, "Cell Block D needs 8 escape cells with landmarks")
	for(var/number in site.escape_cells)
		var/datum/penitentiary_cell/cell = site.escape_cells[number]
		TEST_ASSERT(istype(cell.door(), /obj/machinery/door/airlock/security/glass/penitentiary_escape), "Escape cell [number] has no escape-line door numbered to match")
		TEST_ASSERT(length(cell.turf_set) <= 16, "Escape cell [number] is larger than 16 tiles")
	TEST_ASSERT_EQUAL(length(site.capture_cells), 6, "Secure Holding needs 6 capture cells with landmarks")
	for(var/number in site.capture_cells)
		var/datum/penitentiary_cell/cell = site.capture_cells[number]
		TEST_ASSERT(istype(cell.door(), /obj/machinery/door/airlock/outpost/penitentiary/capture), "Capture cell [number] has no secure capture door numbered to match")
		TEST_ASSERT(length(cell.bed_turfs) >= 2, "Capture cell [number] needs two beds")
	TEST_ASSERT_EQUAL(length(site.launch_consoles), 2, "The launch bay needs 2 launch consoles")
	TEST_ASSERT_EQUAL(length(site.pod_cradles), 2, "The launch bay needs 2 pod cradles")
	TEST_ASSERT(length(site.massacre_body_turfs) >= 6, "The processing room needs at least 6 massacre body marks")
	TEST_ASSERT_EQUAL(length(site.massacre_spots), 4, "The processing room needs 4 convict massacre spots")
	TEST_ASSERT_EQUAL(length(site.evidence_lockers), 8, "The evidence vault needs 8 evidence lockers")
	TEST_ASSERT_EQUAL(length(site.morgue_trays), 4, "The morgue needs 4 trays")
	var/warden = FALSE
	var/clerk = FALSE
	for(var/mob/living/basic/ambient_npc/penitentiary/npc in site.staff)
		warden |= istype(npc, /mob/living/basic/ambient_npc/penitentiary/warden)
		clerk |= istype(npc, /mob/living/basic/ambient_npc/penitentiary/clerk)
	TEST_ASSERT(warden && clerk, "The warden and the intake clerk must both be mapped")
	TEST_ASSERT_NOTNULL(site.prison.guard_office_spot(), "The guard office has no free tile for a guard to beam into")
	for(var/turf/tile as anything in site.interior_turfs())
		TEST_ASSERT(!istype(tile.loc, /area/voidcrew/trader_outpost) && !istype(tile.loc, /area/voidcrew/outpost_hangar), "A trader outpost area is on the Penitentiary map at [AREACOORD(tile)]")
		TEST_ASSERT(!(locate(/obj/machinery/power/apc) in tile), "An APC is on the Penitentiary map at [AREACOORD(tile)]")
		for(var/obj/machinery/computer/outpost_prison_warden/console in tile)
			TEST_ASSERT(istype(console, /obj/machinery/computer/outpost_prison_warden/penitentiary), "The base warden's console is on the Penitentiary map")

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_routes
	var/obj/structure/overmap/penitentiary/site

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_routes/Destroy()
	site = null
	return ..()

/// Whether a walk may go through `door`: the escape line and the wing's staff doors when `escape_line`, secure doors when `secure`, the public outpost doors always
/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_routes/proc/door_opens(obj/machinery/door/door, escape_line, secure)
	if(is_type_in_typecache(door, GLOB.penitentiary_escape_line_doors))
		return escape_line
	if(istype(door, /obj/machinery/door/airlock/outpost/penitentiary) || istype(door, /obj/machinery/door/window/brigdoor/penitentiary))
		return secure
	if(istype(door, /obj/machinery/door/airlock/outpost))
		return TRUE
	return FALSE

/// Walks the open floor from `start`. Returns list(turfs reached (turf = TRUE), doors met and not opened (door = TRUE)).
/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_routes/proc/walk_from(turf/start, escape_line, secure)
	var/list/seen = list()
	var/list/doors_met = list()
	seen[start] = TRUE
	var/list/turf/queue = list(start)
	while(length(queue))
		var/turf/current = queue[length(queue)]
		queue.len--
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || seen[next] || isclosedturf(next) || !site.reservation.contains_turf(next))
				continue
			var/passable = TRUE
			for(var/obj/thing in next)
				if(istype(thing, /obj/machinery/door))
					if(door_opens(thing, escape_line, secure))
						continue
					doors_met[thing] = TRUE
					passable = FALSE
					break
				if(thing.density && !(thing.flags_1 & ON_BORDER_1))
					passable = FALSE
					break
			if(!passable)
				continue
			seen[next] = TRUE
			queue += next
	return list(seen, doors_met)

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_routes/Run()
	site = full_site()
	if(!site)
		TEST_NOTICE(src, "Skipped: the Penitentiary map is still P0's placeholder. Runs once M1 lands.")
		return
	TEST_ASSERT_NOTNULL(site.arrival_turf, "No arrival landmark in the Visitor Hall")
	for(var/number in site.escape_cells)
		var/datum/penitentiary_cell/cell = site.escape_cells[number]
		var/list/walk = walk_from(cell.mark_turf, TRUE, FALSE)
		var/list/seen = walk[1]
		for(var/obj/machinery/computer/penitentiary_launch/console as anything in site.launch_consoles)
			var/reached = FALSE
			for(var/direction in GLOB.cardinals)
				if(seen[get_step(console, direction)])
					reached = TRUE
					break
			TEST_ASSERT(reached, "Escape cell [number] has no escape-line route to the launch console at [AREACOORD(console)]")
		var/reached_vault = FALSE
		for(var/turf/tile as anything in seen)
			if(istype(tile.loc, /area/voidcrew/penitentiary/evidence))
				reached_vault = TRUE
				break
		TEST_ASSERT(reached_vault, "Escape cell [number] has no escape-line route to the evidence vault")
	var/list/starts = list(site.arrival_turf)
	for(var/number in site.capture_cells)
		var/datum/penitentiary_cell/cell = site.capture_cells[number]
		starts += cell.mark_turf
	for(var/turf/start as anything in starts)
		var/list/walk = walk_from(start, TRUE, FALSE)
		var/list/seen = walk[1]
		for(var/turf/tile as anything in seen)
			for(var/obj/machinery/door/door in tile)
				TEST_ASSERT(!is_type_in_typecache(door, GLOB.penitentiary_escape_line_doors), "The walk from [AREACOORD(start)] reaches an escape-line door at [AREACOORD(door)]")
	var/list/public_walk = walk_from(site.arrival_turf, FALSE, FALSE)
	var/list/public_doors = public_walk[2]
	for(var/obj/machinery/door/door as anything in public_doors)
		TEST_ASSERT(istype(door, /obj/machinery/door/airlock/outpost/penitentiary) || istype(door, /obj/machinery/door/window/brigdoor/penitentiary), "A door off the public side is not secure: [door.type] at [AREACOORD(door)]")

// ===== THE NPC WING =====

/// Counts make_mess() calls
/mob/living/basic/outpost_prisoner/bg_mess_spy
	var/messes = 0

/mob/living/basic/outpost_prisoner/bg_mess_spy/make_mess()
	messes++

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_prison_quiet

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_prison_quiet/Run()
	var/datum/outpost_prison/penitentiary/prison = GLOB.penitentiary?.prison
	TEST_ASSERT_NOTNULL(prison, "The Penitentiary has no NPC wing")
	TEST_ASSERT(!(prison in GLOB.outpost_prisons), "The Penitentiary's wing joined GLOB.outpost_prisons, so the pool would feed it")
	var/list/wing = prison.wing_turfs()
	TEST_ASSERT(length(wing), "The wing has no tiles")
	var/mob/living/carbon/human/visitor = test_human(pick(wing))
	TEST_ASSERT(!prison.is_member(visitor), "A plain human counts as a member of the Penitentiary's wing")
	// The spy stands in the wing; process() runs by hand with the prison off the processing list
	var/mob/living/basic/outpost_prisoner/bg_mess_spy/spy = allocate(/mob/living/basic/outpost_prisoner/bg_mess_spy, pick(wing), null)
	prison.admit(spy, null)
	STOP_PROCESSING(SSprocessing, prison)
	var/stage_before = prison.stage
	var/inmates_before = length(prison.prisoners)
	for(var/i in 1 to 20)
		prison.process(600)
	prison.trouble_tick(600)
	prison.intake_tick(600)
	START_PROCESSING(SSprocessing, prison)
	TEST_ASSERT_EQUAL(spy.messes, 0, "The Penitentiary's process() made a mess (PERF-1)")
	TEST_ASSERT_EQUAL(prison.stage, stage_before, "trouble_tick() moved the wing's stage")
	TEST_ASSERT(!prison.riot_active, "A riot started in the Penitentiary")
	TEST_ASSERT(length(prison.prisoners) <= inmates_before, "intake_tick() admitted someone")

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_guard_cell

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_guard_cell/Run()
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	var/datum/outpost_prison/penitentiary/prison = site?.prison
	TEST_ASSERT_NOTNULL(prison, "The Penitentiary has no NPC wing")
	var/turf/open_tile
	for(var/turf/tile as anything in prison.wing_turfs())
		if(isopenturf(tile) && !tile.is_blocked_turf(exclude_mobs = TRUE))
			open_tile = tile
			break
	TEST_ASSERT_NOTNULL(open_tile, "The wing has no open floor")
	var/mob/living/carbon/human/convict = test_human(open_tile)
	ADD_TRAIT(convict, "background_convict", "background") // TRAIT_BACKGROUND_CONVICT, BACKGROUND_TRAIT
	TEST_ASSERT(prison.convict_loose_target(convict), "A convict loose in the wing is not a guard's target")
	// The same tile, made his own cell: guards leave him be (MP-10)
	var/datum/penitentiary_cell/own_cell = new(99, "escape", open_tile)
	own_cell.turf_set[open_tile] = TRUE
	own_cell.owner_ref = WEAKREF(convict.mind)
	site.escape_cells["99"] = own_cell
	var/in_cell = prison.convict_loose_target(convict)
	site.escape_cells -= "99"
	qdel(own_cell)
	TEST_ASSERT(!in_cell, "Guards would go after a convict inside his own cell (MP-10)")
	REMOVE_TRAIT(convict, "background_convict", "background")
	TEST_ASSERT(!prison.convict_loose_target(convict), "A human who is no convict is a guard's target")

// ===== WARRANTS =====

/datum/unit_test/voidcrew_bg_convict/voidcrew_warrant_value

/datum/unit_test/voidcrew_bg_convict/voidcrew_warrant_value/Run()
	var/mob/living/carbon/human/convict = test_human()
	var/datum/criminal_bounty/warrant/warrant = background_mint_warrant(convict.mind, "convict") // BACKGROUND_CONVICT
	TEST_ASSERT_NOTNULL(warrant, "No warrant was minted")
	TEST_ASSERT(warrant in GLOB.background_warrants, "The warrant is not in GLOB.background_warrants")
	TEST_ASSERT(!(warrant in GLOB.criminal_bounties), "The warrant leaked into GLOB.criminal_bounties (BUG-3)")
	TEST_ASSERT(!warrant.board_visible_to(null), "A warrant shows on ordinary boards")
	warrant.posted_zone = 2 // ZONE_YELLOW
	warrant.tier = 2
	warrant.posted_at = world.time
	var/fresh = warrant.current_value()
	TEST_ASSERT(fresh >= 420 && fresh <= 430, "A fresh yellow warrant is worth [fresh], not a quarter of 1000 x 1.7")
	warrant.posted_at = world.time - 27000 // BACKGROUND_WARRANT_FULL_TIME, 45 minutes
	TEST_ASSERT_EQUAL(warrant.current_value(), 1700, "A warrant 45 minutes old is not worth 1000 x 1.7")
	warrant.posted_at = world.time - 54000
	TEST_ASSERT_EQUAL(warrant.current_value(), 1700, "A warrant keeps growing past full value")
	warrant.tier = 3
	TEST_ASSERT_EQUAL(warrant.current_value(), 1870, "Most wanted is not a tenth above the full value")
	// A second warrant on the same mind closes the first (ECO-3)
	var/datum/criminal_bounty/warrant/second = background_mint_warrant(convict.mind, "convict")
	TEST_ASSERT_NOTNULL(second, "A new life's warrant was not minted")
	TEST_ASSERT(QDELETED(warrant) || !warrant.is_open(), "The old warrant stayed open beside the new one")
	TEST_ASSERT_EQUAL(background_warrant_for_mind(convict.mind), second, "The mind's open warrant is not the new one")
	TEST_ASSERT_EQUAL(background_warrant_for_body(convict), second, "The body's open warrant is not the new one")

/datum/unit_test/voidcrew_bg_convict/voidcrew_warrant_claim

/datum/unit_test/voidcrew_bg_convict/voidcrew_warrant_claim/Run()
	var/mob/living/carbon/human/convict = test_human()
	var/datum/criminal_bounty/warrant/warrant = background_mint_warrant(convict.mind, "convict")
	TEST_ASSERT_NOTNULL(warrant, "No warrant was minted")
	// No player behind the body: the dead share (ECO-4)
	var/state = warrant.warrant_capture_state(convict)
	TEST_ASSERT_EQUAL(state, "dead", "A target with no client does not pay the dead share") // BOUNTY_STATE_DEAD
	var/obj/structure/overmap/ship/ship = bg_test_ship(/datum/map_template/shuttle/voidcrew/escape_pod)
	TEST_ASSERT_NOTNULL(ship, "The test hull did not spawn")
	// Anyone who was ever aboard the hunters' hull is refused (ECO-2)
	var/list/saved_crew = ship.background_ever_crew
	ship.background_ever_crew = list(warrant.target_ckey)
	TEST_ASSERT_EQUAL(warrant.warrant_crew_refusal(ship), "they're one of your crew", "A target on the hull's ever-crew list was not refused")
	ship.background_ever_crew = saved_crew
	TEST_ASSERT_NULL(warrant.warrant_crew_refusal(ship), "A stranger was refused as crew")
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	if(!length(site?.capture_cells))
		// The placeholder has no Secure Holding: the claim must refuse rather than pay
		var/refused = warrant.claim_body(convict, ship, null, state, null)
		TEST_ASSERT(istext(refused), "A claim paid with nowhere to hold the captive")
		TEST_NOTICE(src, "Capture-cell half skipped: the Penitentiary map is still P0's placeholder.")
	else
		var/expected = round(warrant.update_value() * 25 / 100) // BOUNTY_SHARE_DEAD
		var/list/result = warrant.claim_body(convict, ship, null, state, null)
		TEST_ASSERT(islist(result), "The claim was refused: [result]")
		TEST_ASSERT_EQUAL(result[1], expected, "The dead share was not paid")
		TEST_ASSERT(!QDELETED(convict), "The claim deleted the body")
		TEST_ASSERT_NOTNULL(site.capture_cell_holding(convict), "The captive is not in a capture cell")
		TEST_ASSERT(!warrant.is_open(), "The warrant is still open after it was paid")
	// One payout per ckey per round: no new warrant after a paid claim (ECO-1, ECO-3)
	var/list/ledger = convict_ledger(ckey(convict.mind.key))
	ledger["paid"] = TRUE
	TEST_ASSERT_NULL(background_mint_warrant(convict.mind, "convict"), "A warrant was minted for a ckey already paid for this round")

// ===== PODS, CLEAN SLATE, DOORS, DOCKING, ZONES =====

/datum/unit_test/voidcrew_bg_convict/voidcrew_pod_launch_refusals

/datum/unit_test/voidcrew_bg_convict/voidcrew_pod_launch_refusals/Run()
	var/obj/machinery/computer/penitentiary_launch/console = allocate(/obj/machinery/computer/penitentiary_launch, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/stranger = test_human(run_loc_floor_bottom_left)
	TEST_ASSERT(console.launch_refusal(stranger), "The launch console works for someone who is no convict (MP-8)")
	var/mob/living/carbon/human/convict = test_human(run_loc_floor_bottom_left)
	var/datum/background_state/state = bg_test_state(convict, "convict") // BACKGROUND_CONVICT
	TEST_ASSERT_NOTNULL(state, "No convict state")
	TEST_ASSERT_NULL(console.launch_refusal(convict), "A convict with pods left was refused")
	var/list/ledger = convict_ledger(state.ckey)
	ledger["pods"] = 1
	var/datum/stand_in_pod = allocate(/datum)
	GLOB.penitentiary_last_pods[state.ckey] = WEAKREF(stand_in_pod)
	TEST_ASSERT_EQUAL(console.launch_refusal(convict), "pod still out", "A second pod launched while the first is out (SPA-1)")
	GLOB.penitentiary_last_pods -= state.ckey
	ledger["pods"] = 2 // BACKGROUND_PODS_PER_CKEY
	TEST_ASSERT_EQUAL(console.launch_refusal(convict), "no pods left", "A third pod launched for one ckey (SPA-1)")

/datum/unit_test/voidcrew_bg_convict/voidcrew_clean_slate_refusals

/datum/unit_test/voidcrew_bg_convict/voidcrew_clean_slate_refusals/Run()
	var/datum/shop_sku/black_market/clean_slate/sku = allocate(/datum/shop_sku/black_market/clean_slate)
	var/mob/living/carbon/human/buyer = test_human(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(sku.get_denial_reason(buyer), "Your file's already closed.", "Clean Slate sold with no open warrant (ECO-15)")
	TEST_ASSERT_NOTNULL(background_mint_warrant(buyer.mind, "convict"), "No warrant was minted")
	buyer.equip_to_slot_or_del(new /obj/item/clothing/mask/gas(buyer), ITEM_SLOT_MASK)
	TEST_ASSERT_EQUAL(sku.get_denial_reason(buyer), "I deal with faces, not masks.", "Clean Slate sold to a masked buyer with no papers")
	TEST_ASSERT(!sku.try_purchase(buyer, null), "A refused buyer still bought Clean Slate")

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_doors

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_doors/Run()
	var/mob/living/carbon/human/visitor = test_human(run_loc_floor_bottom_left)
	var/turf/spot = locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/obj/machinery/door/airlock/outpost/penitentiary/secure = allocate(/obj/machinery/door/airlock/outpost/penitentiary, spot)
	TEST_ASSERT(!secure.emag_act(visitor, null), "A secure door took an emag (MP-8)")
	TEST_ASSERT(!secure.allowed(visitor), "A secure door opens for a visitor (MP-8)")
	// "outpost_property" is TRAIT_OUTPOST_PROPERTY
	TEST_ASSERT(HAS_TRAIT(secure, "outpost_property"), "A secure door can be taken apart with tools")
	var/obj/machinery/door/airlock/outpost/penitentiary/capture/capture = allocate(/obj/machinery/door/airlock/outpost/penitentiary/capture, locate(spot.x + 1, spot.y, spot.z))
	TEST_ASSERT(!capture.emag_act(visitor, null), "A capture cell door took an emag (TIM-2)")
	var/obj/machinery/door/window/brigdoor/penitentiary/counter = allocate(/obj/machinery/door/window/brigdoor/penitentiary, locate(spot.x + 2, spot.y, spot.z))
	TEST_ASSERT(!counter.emag_act(visitor, null), "The intake counter took an emag")
	var/obj/structure/closet/secure_closet/penitentiary_evidence/locker = allocate(/obj/structure/closet/secure_closet/penitentiary_evidence, locate(spot.x + 3, spot.y, spot.z))
	TEST_ASSERT(!locker.emag_act(visitor, null), "An evidence locker took an emag (MP-8)")
	TEST_ASSERT(locker.locked, "An emag unlocked an evidence locker")
	TEST_ASSERT(!locker.allowed(visitor), "A free evidence locker opens for anyone")
	var/mob/living/carbon/human/owner = test_human(run_loc_floor_bottom_left)
	locker.assign_to(owner.mind)
	TEST_ASSERT(locker.allowed(owner), "An evidence locker does not open for its owner")
	TEST_ASSERT(!locker.allowed(visitor), "An evidence locker opens for someone else's mind (MP-8)")

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_docking

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_docking/Run()
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	TEST_ASSERT_NOTNULL(site, "No Penitentiary")
	TEST_ASSERT(!istype(site, /obj/structure/overmap/trader_outpost) && !(site in GLOB.trader_outposts), "The Penitentiary is a trader outpost (MP-7)")
	var/obj/structure/overmap/ship/pod = bg_test_ship(/datum/map_template/shuttle/voidcrew/escape_pod)
	TEST_ASSERT_NOTNULL(pod, "The pod did not spawn")
	TEST_ASSERT_EQUAL(site.penitentiary_docking_refusal(pod), "Meridian traffic control: that pod is not cleared to dock.", "An escape pod may dock at the Penitentiary (MP-13)")
	var/mob/living/carbon/human/pilot = test_human(run_loc_floor_bottom_left)
	var/state_before = pod.state
	site.ship_act(pilot, pod)
	TEST_ASSERT_EQUAL(pod.state, state_before, "ship_act() went on to dock a refused pod")
	pod.pirate_crew = TRUE
	TEST_ASSERT_EQUAL(site.penitentiary_docking_refusal(pod), "Meridian traffic control: your transponder is flagged. Docking denied.", "A pirate hull may dock at the Penitentiary (MP-13)")
	pod.pirate_crew = FALSE

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_zone_lookup

/datum/unit_test/voidcrew_bg_convict/voidcrew_penitentiary_zone_lookup/Run()
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	TEST_ASSERT(site?.loaded, "No loaded Penitentiary")
	var/turf/inside = site.template_bottom_left
	TEST_ASSERT_NOTNULL(inside, "The Penitentiary has no interior")
	TEST_ASSERT_EQUAL(SSovermap_zones.get_overmap_object_for_turf(inside), site, "A Penitentiary turf does not resolve to the site (TEL-2)")
	TEST_ASSERT(is_penitentiary_turf(inside), "is_penitentiary_turf() is FALSE inside the site")
	TEST_ASSERT(!is_penitentiary_turf(run_loc_floor_bottom_left), "is_penitentiary_turf() is TRUE outside the site")

// ===== THE POD HULL (map-contracts.md M3) =====

/datum/unit_test/voidcrew_bg_convict/voidcrew_escape_pod_hull

/datum/unit_test/voidcrew_bg_convict/voidcrew_escape_pod_hull/Run()
	var/obj/structure/overmap/ship/pod = bg_test_ship(/datum/map_template/shuttle/voidcrew/escape_pod)
	TEST_ASSERT_NOTNULL(pod?.shuttle, "The escape pod did not spawn")
	var/list/turf/hull = pod.shuttle.return_turfs()
	for(var/turf/tile as anything in hull)
		if(locate(/obj/machinery/power/port_gen) in tile)
			TEST_NOTICE(src, "Skipped: the escape pod is still P0's placeholder (it carries a generator). Runs once M3 lands.")
			return
	TEST_ASSERT_EQUAL(length(pod.shuttle.spawn_points), 1, "The pod needs exactly one cryopod")
	var/ports = 0
	var/obj/machinery/power/smes/battery
	var/static/list/forbidden = typecacheof(list(
		/obj/item/gun,
		/obj/item/melee,
		/obj/item/storage/toolbox,
		/obj/item/screwdriver,
		/obj/item/wrench,
		/obj/item/crowbar,
		/obj/item/weldingtool,
		/obj/item/multitool,
		/obj/item/wirecutters,
	))
	for(var/turf/tile as anything in hull)
		for(var/obj/docking_port/mobile/port in tile)
			ports++
		battery = battery || (locate(/obj/machinery/power/smes) in tile)
		for(var/obj/item/thing in tile.get_all_contents())
			TEST_ASSERT(!is_type_in_typecache(thing, forbidden), "The pod carries [thing.type], which the contract forbids")
	TEST_ASSERT_EQUAL(ports, 1, "The pod needs exactly one mobile docking port")
	TEST_ASSERT_NOTNULL(battery, "The pod has no battery")
	TEST_ASSERT(battery.charge > 0, "The pod's battery starts empty")

// ===== CRIMES =====

/datum/unit_test/voidcrew_bg_convict/voidcrew_convict_crimes

/datum/unit_test/voidcrew_bg_convict/voidcrew_convict_crimes/Run()
	var/static/list/goals = list("haul", "captain", "clean_slate", "stash", "witness") // CONVICT_GOAL_*
	for(var/crime_name in GLOB.prisoner_crimes)
		var/datum/prisoner_crime/crime = GLOB.prisoner_crimes[crime_name]
		TEST_ASSERT(crime.background_goal in goals, "[crime_name] has no convict goal")
		TEST_ASSERT(crime.background_tier >= 1 && crime.background_tier <= 3, "[crime_name] has a warrant tier out of 1-3")
	var/datum/prisoner_crime/smuggling = GLOB.prisoner_crimes["Smuggling"]
	TEST_ASSERT_NOTNULL(smuggling, "Smuggling is not a crime")
	TEST_ASSERT_EQUAL(smuggling.background_goal, "stash", "Smuggling does not give the stash goal")
	var/datum/preference/choiced/prisoner_crime/pref = GLOB.preference_entries[/datum/preference/choiced/prisoner_crime]
	var/list/values = pref.init_possible_values()
	TEST_ASSERT_EQUAL(length(values), 6, "The Crime dropdown is not the five crimes and Random")
	for(var/crime_name in values)
		TEST_ASSERT(crime_name == "Random" || GLOB.prisoner_crimes[crime_name], "The Crime dropdown offers [crime_name], which is no crime")
