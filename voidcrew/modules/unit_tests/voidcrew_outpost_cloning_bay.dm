/**
 * Outpost cloning bay (outpost_cloning_bay.dm) and the ghost clone chooser (clone_wake.dm).
 *
 * Voidcrew defines are not visible from test files, so prices, ids and messages are literals:
 * the imprint price key is "clone_imprint", its default 600 cr; LOCKDOWN is "lockdown".
 * The room map is 11x9 with its entrance at (6,1); the vats stand at (2,8), (3,8), (9,8), (10,8).
 */
/datum/unit_test/voidcrew_outpost_cloning_bay
	parent_type = /datum/unit_test/voidcrew_outpost_management
	abstract_type = /datum/unit_test/voidcrew_outpost_cloning_bay
	/// Ghosts and clones made outside allocate(), deleted with their offline keys cleared
	var/list/mob/made_mobs = list()

/datum/unit_test/voidcrew_outpost_cloning_bay/Destroy()
	for(var/mob/made as anything in made_mobs)
		if(!QDELETED(made))
			made.key = null
			qdel(made)
	made_mobs.Cut()
	return ..()

/// `count` free floor tiles of the claim's own area
/datum/unit_test/voidcrew_outpost_cloning_bay/proc/bay_test_floors(obj/structure/overmap/dynamic/player_outpost/home, count)
	. = list()
	var/turf/console_turf = get_turf(home.management_console)
	for(var/turf/open/floor/tile in home.outpost_area)
		if(tile == console_turf || tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		. += tile
		if(length(.) >= count)
			return

/// A powered vat of `vat_type` on `location`
/datum/unit_test/voidcrew_outpost_cloning_bay/proc/make_test_vat(turf/location, vat_type = /obj/machinery/cloning_vat/outpost)
	var/obj/machinery/cloning_vat/vat = allocate(vat_type, location)
	vat.set_machine_stat(vat.machine_stat & ~NOPOWER)
	return vat

/datum/unit_test/voidcrew_outpost_cloning_bay/proc/grow(obj/machinery/cloning_vat/vat)
	vat.growth_progress = vat.growth_time
	vat.body_ready = TRUE

/// Kills `body` and returns its ghost. `can_reenter` FALSE makes the mindless ghost of suicide, DNR or the Ghost verb.
/datum/unit_test/voidcrew_outpost_cloning_bay/proc/kill_to_ghost(mob/living/body, can_reenter = TRUE)
	body.death()
	return ghost_of(body, can_reenter)

/datum/unit_test/voidcrew_outpost_cloning_bay/proc/ghost_of(mob/living/body, can_reenter = TRUE)
	var/mob/dead/observer/ghost = body.ghostize(can_reenter)
	if(ghost)
		made_mobs += ghost
		ADD_TRAIT(ghost, TRAIT_PRESERVE_UI_WITHOUT_CLIENT, REF(src))
	return ghost

/// Presses Wake in the ghost's chooser for a vat (or a raw ref)
/datum/unit_test/voidcrew_outpost_cloning_bay/proc/wake(mob/dead/observer/ghost, vat_or_ref)
	var/datum/clone_wake_menu/menu = allocate(/datum/clone_wake_menu, ghost)
	var/datum/tgui/ui = allocate(/datum/tgui, ghost, menu, "CloneWake")
	var/ref = istext(vat_or_ref) ? vat_or_ref : REF(vat_or_ref)
	world.push_usr(ghost, CALLBACK(menu, TYPE_PROC_REF(/datum, ui_act), "wake", list("ref" = ref), ui))

// ===== BASE VAT =====

/// Ship vats: claim_denial() reasons, a claim that regrows, and the character-swap race (F-20)
/datum/unit_test/voidcrew_outpost_cloning_bay/base_vat

/datum/unit_test/voidcrew_outpost_cloning_bay/base_vat/Run()
	var/obj/machinery/cloning_vat/vat = make_test_vat(run_loc_floor_bottom_left, /obj/machinery/cloning_vat)
	TEST_ASSERT(!vat.is_single_use(), "A ship vat is single-use")
	var/mob/living/carbon/human/player = make_player(run_loc_floor_bottom_left, "clonebaseplayer")
	var/datum/mind/mind = player.mind
	vat.do_imprint(player)
	var/mob/dead/observer/ghost = ghost_of(player)
	TEST_ASSERT_EQUAL(vat.claim_denial(ghost, mind), "No clone grown.", "An empty vat gave the wrong reason")
	vat.growth_progress = vat.growth_time / 2
	TEST_ASSERT_EQUAL(vat.claim_denial(ghost, mind), "Still growing.", "A growing vat gave the wrong reason")
	grow(vat)
	TEST_ASSERT_EQUAL(vat.claim_denial(ghost, mind), "You are still alive.", "A ghost of a living body could claim")
	player.death()
	TEST_ASSERT_NULL(vat.claim_denial(ghost, mind), "The dead holder's ghost could not claim a ready vat")
	vat.set_machine_stat(vat.machine_stat | NOPOWER)
	TEST_ASSERT_EQUAL(vat.claim_denial(ghost, mind), "Vat is offline.", "An unpowered vat allowed a claim")
	vat.set_machine_stat(vat.machine_stat & ~NOPOWER)

	var/mob/living/carbon/human/stranger = make_player(run_loc_floor_bottom_left, "clonebasestranger")
	var/mob/dead/observer/stranger_ghost = kill_to_ghost(stranger)
	TEST_ASSERT_EQUAL(vat.claim_denial(stranger_ghost, mind), "Not your clone.", "Another player's ghost could claim")

	vat.claim(ghost, mind)
	var/mob/living/carbon/human/clone = mind.current
	TEST_ASSERT(clone && clone != player, "The claim did not move the player into a clone")
	made_mobs += clone
	TEST_ASSERT_EQUAL(vat.imprint_mind_ref?.resolve(), mind, "A ship vat lost its imprint on a claim")
	TEST_ASSERT(!vat.body_ready && vat.growth_progress == 0, "A ship vat did not start regrowing after the claim")
	TEST_ASSERT(vat in LAZYACCESS(GLOB.imprinted_vats_by_ckey, "clonebaseplayer"), "The regrowing ship vat left the chooser index")

	// F-20: the player is now someone else, alive; their old character's mindless ghost must not match
	var/obj/machinery/cloning_vat/twin_vat = make_test_vat(run_loc_floor_bottom_left, /obj/machinery/cloning_vat)
	var/mob/living/carbon/human/old_self = make_player(run_loc_floor_bottom_left, "clonebasetwin")
	var/datum/mind/old_mind = old_self.mind
	twin_vat.do_imprint(old_self)
	grow(twin_vat)
	var/mob/dead/observer/twin_ghost = kill_to_ghost(old_self, can_reenter = FALSE)
	TEST_ASSERT(twin_vat.holder_matches(twin_ghost, old_mind), "The mindless ghost of the dead holder did not match")
	var/mob/living/carbon/human/new_self = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	new_self.mind_initialize()
	new_self.mind.key = "clonebasetwin"
	TEST_ASSERT(!twin_vat.holder_matches(twin_ghost, old_mind), "A ghost matched its old character while the player lives as another")
	TEST_ASSERT_EQUAL(twin_vat.claim_denial(twin_ghost, old_mind), "Not your clone.", "The character-swap race could claim")
	new_self.mind.key = null

// ===== CHARGING =====

/// Visitors pay once from their ID; members, residents and ownerless outposts are free; refusals move nothing
/datum/unit_test/voidcrew_outpost_cloning_bay/charging

/datum/unit_test/voidcrew_outpost_cloning_bay/charging/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("clonechargeowner")
	TEST_ASSERT_NOTNULL(home, "The cloning test outpost did not load")
	var/list/floors = bay_test_floors(home, 8)
	TEST_ASSERT_EQUAL(length(floors), 8, "Not enough free floor on the test outpost")
	var/list/obj/machinery/cloning_vat/outpost/vats = list()
	for(var/turf/tile as anything in floors)
		vats += make_test_vat(tile)
	var/obj/machinery/cloning_vat/outpost/first = vats[1]
	TEST_ASSERT_EQUAL(first.host_outpost(), home, "A vat on the claim did not find its outpost")
	TEST_ASSERT(first.is_single_use(), "An outpost vat is not single-use")
	var/datum/bank_account/treasury = home.treasury
	var/start_treasury = treasury.account_balance

	// A visitor with money pays exactly once
	var/mob/living/carbon/human/visitor = make_market_visitor(floors[1], "clonechargevisitor", 1000)
	var/datum/bank_account/visitor_account = visitor.get_idcard(TRUE).registered_account
	TEST_ASSERT_NULL(first.paid_imprint(visitor, home, 600), "A visitor with money could not imprint")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 400, "The visitor was not charged 600 cr")
	TEST_ASSERT_EQUAL(treasury.account_balance, start_treasury + 600, "The treasury was not credited 600 cr")
	TEST_ASSERT_EQUAL(first.paid_amount, 600, "The vat did not record the payment")
	var/list/last_line = home.service_ledger[length(home.service_ledger)]
	TEST_ASSERT_EQUAL(last_line["service"], "clone_imprint", "The ledger line has the wrong service")
	TEST_ASSERT_EQUAL(last_line["amount"], 600, "The ledger line has the wrong amount")

	// Occupied: neither the holder nor anyone else overwrites; one imprint per player per outpost
	TEST_ASSERT_EQUAL(first.paid_imprint(visitor, home, 600), "Occupied.", "The holder could refresh a paid imprint")
	var/mob/living/carbon/human/other = make_market_visitor(floors[2], "clonechargeother", 1000)
	TEST_ASSERT_EQUAL(first.paid_imprint(other, home, 600), "Occupied.", "Another player overwrote a paid imprint")
	var/obj/machinery/cloning_vat/outpost/second = vats[2]
	TEST_ASSERT_EQUAL(second.paid_imprint(visitor, home, 600), "You already have a clone here.", "A player stacked two imprints on one outpost")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 400, "A refused imprint moved money")
	TEST_ASSERT_NULL(second.imprint_mind_ref, "A refused imprint filled the vat")

	// Short, siphon-locked and price-changed customers are refused with nothing moved
	var/treasury_before = treasury.account_balance
	var/obj/machinery/cloning_vat/outpost/third = vats[3]
	var/obj/machinery/cloning_vat/outpost/fourth = vats[4]
	var/mob/living/carbon/human/poor = make_market_visitor(floors[3], "clonechargepoor", 100)
	TEST_ASSERT_EQUAL(third.paid_imprint(poor, home, 600), "Insufficient credits.", "A short visitor was not refused")
	var/mob/living/carbon/human/siphoned = make_market_visitor(floors[4], "clonechargesiphon", 1000)
	var/datum/bank_account/siphoned_account = siphoned.get_idcard(TRUE).registered_account
	siphoned_account.mark_siphoned()
	TEST_ASSERT_EQUAL(fourth.paid_imprint(siphoned, home, 600), "Insufficient credits.", "A siphon-locked account paid")
	home.outpost_prices["clone_imprint"] = 700
	TEST_ASSERT_EQUAL(third.paid_imprint(other, home, 600), "Price changed to 700 cr.", "A changed price was charged")
	home.outpost_prices -= "clone_imprint"
	TEST_ASSERT_EQUAL(treasury.account_balance, treasury_before, "A refused imprint changed the treasury")
	TEST_ASSERT_EQUAL(poor.get_idcard(TRUE).registered_account.account_balance, 100, "A short visitor lost money")
	TEST_ASSERT_EQUAL(siphoned_account.account_balance, 1000, "A siphon-locked visitor lost money")
	TEST_ASSERT_EQUAL(other.get_idcard(TRUE).registered_account.account_balance, 1000, "A price-changed visitor lost money")
	TEST_ASSERT_NULL(third.imprint_mind_ref, "A refused imprint filled the vat")

	// Members pay nothing: the owner and a resident see a fee of 0
	var/obj/machinery/cloning_vat/outpost/fifth = vats[5]
	var/obj/machinery/cloning_vat/outpost/sixth = vats[6]
	var/mob/living/carbon/human/owner = make_market_visitor(floors[5], "clonechargeowner", 1000)
	TEST_ASSERT_EQUAL(fifth.paid_imprint(owner, home, 600), "Price changed to 0 cr.", "The owner was quoted the visitor price")
	TEST_ASSERT_NULL(fifth.paid_imprint(owner, home, 0), "The owner could not imprint free")
	var/mob/living/carbon/human/resident = make_market_visitor(floors[6], "clonechargeresident", 1000)
	home.residents += resident.mind
	TEST_ASSERT_NULL(sixth.paid_imprint(resident, home, 0), "A resident could not imprint free")
	TEST_ASSERT_EQUAL(sixth.paid_amount, 0, "A free imprint recorded a payment")
	TEST_ASSERT_EQUAL(treasury.account_balance, treasury_before, "A member imprint changed the treasury")
	TEST_ASSERT_EQUAL(owner.get_idcard(TRUE).registered_account.account_balance, 1000, "The owner was charged")

	// An ownerless outpost charges nothing
	var/obj/machinery/cloning_vat/outpost/seventh = vats[7]
	home.founder_ckey = null
	var/mob/living/carbon/human/drifter = make_market_visitor(floors[7], "clonechargedrifter", 1000)
	TEST_ASSERT_NULL(seventh.paid_imprint(drifter, home, 0), "An ownerless outpost refused a free imprint")
	TEST_ASSERT_EQUAL(drifter.get_idcard(TRUE).registered_account.account_balance, 1000, "An ownerless outpost charged")
	home.founder_ckey = "clonechargeowner"

	// Bag-of-holding rifts and tools leave the vat and its imprint alone
	first.singularity_act()
	TEST_ASSERT(!QDELETED(first) && first.imprint_mind_ref, "A singularity deleted a paid vat")
	var/mob/living/carbon/human/vandal = make_player(floors[8], "clonechargevandal")
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	vandal.forceMove(get_turf(first))
	wrench.melee_attack_chain(vandal, first)
	screwdriver.melee_attack_chain(vandal, first)
	crowbar.melee_attack_chain(vandal, first)
	TEST_ASSERT(first.anchored, "A wrench unanchored an outpost vat")
	TEST_ASSERT(!first.panel_open, "A screwdriver opened an outpost vat")
	TEST_ASSERT(!QDELETED(first), "A crowbar deconstructed an outpost vat")

// ===== WAKING =====

/// Single use, the arrival rules (F-19), R9's ownerless wakes and the chooser
/datum/unit_test/voidcrew_outpost_cloning_bay/waking

/datum/unit_test/voidcrew_outpost_cloning_bay/waking/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("clonewakeowner")
	TEST_ASSERT_NOTNULL(home, "The cloning test outpost did not load")
	var/list/floors = bay_test_floors(home, 4)
	TEST_ASSERT_EQUAL(length(floors), 4, "Not enough free floor on the test outpost")
	var/obj/machinery/cloning_vat/outpost/visitor_vat = make_test_vat(floors[1])
	var/obj/machinery/cloning_vat/outpost/owner_vat = make_test_vat(floors[2])
	var/obj/machinery/cloning_vat/outpost/stranger_vat = make_test_vat(floors[3])
	var/obj/machinery/cloning_vat/ship_vat = make_test_vat(run_loc_floor_bottom_left, /obj/machinery/cloning_vat)

	var/mob/living/carbon/human/visitor = make_market_visitor(floors[1], "clonewakevisitor", 1000)
	var/datum/mind/visitor_mind = visitor.mind
	TEST_ASSERT_NULL(visitor_vat.paid_imprint(visitor, home, 600), "The visitor could not imprint")
	ship_vat.do_imprint(visitor)
	grow(visitor_vat)
	var/mob/living/carbon/human/owner = make_market_visitor(floors[2], "clonewakeowner", 0)
	var/datum/mind/owner_mind = owner.mind
	TEST_ASSERT_NULL(owner_vat.paid_imprint(owner, home, 0), "The owner could not imprint")
	grow(owner_vat)
	var/mob/living/carbon/human/stranger = make_market_visitor(floors[3], "clonewakestranger", 1000)
	TEST_ASSERT_NULL(stranger_vat.paid_imprint(stranger, home, 600), "The stranger could not imprint")
	grow(stranger_vat)

	// A living holder's ghost is listed but cannot wake
	var/mob/dead/observer/stranger_ghost = ghost_of(stranger)
	var/datum/clone_wake_menu/stranger_menu = allocate(/datum/clone_wake_menu, stranger_ghost)
	var/list/stranger_data = stranger_menu.ui_data(stranger_ghost)
	TEST_ASSERT(stranger_data["alive"], "The chooser did not see a living holder")
	wake(stranger_ghost, stranger_vat)
	TEST_ASSERT_EQUAL(stranger.mind.current, stranger, "A living holder woke in a clone")

	// Dead, suicide style: the chooser lists exactly this player's vats, ship and outpost
	var/mob/dead/observer/visitor_ghost = kill_to_ghost(visitor, can_reenter = FALSE)
	TEST_ASSERT_NULL(visitor_ghost.mind, "The suicide ghost kept its mind")
	var/list/owned = get_owned_cloning_vats(visitor_ghost)
	TEST_ASSERT_EQUAL(length(owned), 2, "The chooser did not list exactly the player's two vats")
	TEST_ASSERT((visitor_vat in owned) && (ship_vat in owned), "The chooser missed one of the player's vats")
	visitor_ghost.started_as_observer = TRUE
	TEST_ASSERT(!length(get_owned_cloning_vats(visitor_ghost)), "A lobby observer with the player's ckey saw their clones")
	visitor_ghost.started_as_observer = FALSE

	var/datum/clone_wake_menu/menu = allocate(/datum/clone_wake_menu, visitor_ghost)
	var/list/data = menu.ui_data(visitor_ghost)
	TEST_ASSERT(!data["alive"], "The chooser thinks a dead holder lives")
	var/list/rows = data["clones"]
	TEST_ASSERT_EQUAL(length(rows), 2, "The chooser sent the wrong number of rows")
	var/list/row = rows[1]
	for(var/key in list("ref", "site", "ready", "offline", "percent", "unsafe_air", "denial", "warning"))
		TEST_ASSERT(key in row, "A chooser row has no [key]")
	TEST_ASSERT_EQUAL(row["ref"], REF(visitor_vat), "The ready clone is not listed first")
	TEST_ASSERT_EQUAL(row["site"], home.name, "The outpost vat's site is wrong")
	TEST_ASSERT(visitor_vat.is_single_use(), "The outpost vat is not single-use")

	// F-19: a visitor's wake is an arrival
	home.dock_mode = "lockdown"
	TEST_ASSERT_EQUAL(visitor_vat.claim_denial(visitor_ghost, visitor_mind), "[home.name] is in lockdown.", "A visitor woke during a lockdown")
	var/mob/dead/observer/owner_ghost = kill_to_ghost(owner)
	TEST_ASSERT_NULL(owner_vat.claim_denial(owner_ghost, owner_mind), "A member could not wake during a lockdown")
	home.founder_ckey = null
	TEST_ASSERT_NULL(visitor_vat.claim_denial(visitor_ghost, visitor_mind), "An ownerless outpost refused a visitor's wake (R9)")
	home.founder_ckey = "clonewakeowner"
	home.dock_mode = "open"
	var/datum/team/voidcrew/crew = allocate(/datum/team/voidcrew)
	var/obj/structure/overmap/ship/crew_ship = allocate(/obj/structure/overmap/ship)
	crew.ship = crew_ship
	LAZYADD(visitor_mind.ship_teams, crew)
	home.banned_ships[crew_ship] = TRUE
	TEST_ASSERT_EQUAL(visitor_vat.claim_denial(visitor_ghost, visitor_mind), "Your crew is banned from [home.name].", "A banned crew's visitor woke")
	var/list/banned_row = visitor_vat.clone_wake_row(visitor_ghost)
	TEST_ASSERT_NOTNULL(banned_row["denial"], "The chooser row does not show why the wake is refused")
	wake(visitor_ghost, visitor_vat)
	TEST_ASSERT_EQUAL(visitor_mind.current, visitor, "A refused wake claimed the clone")
	home.banned_ships -= crew_ship
	LAZYREMOVE(visitor_mind.ship_teams, crew)
	crew.ship = null

	// Another player's vat, a deleted vat and a growing vat are refused; a ready vat wakes, once
	wake(visitor_ghost, stranger_vat)
	TEST_ASSERT_EQUAL(visitor_mind.current, visitor, "Another player's vat woke this ghost")
	var/obj/machinery/cloning_vat/outpost/gone = make_test_vat(floors[4])
	var/gone_ref = REF(gone)
	qdel(gone)
	wake(visitor_ghost, gone_ref)
	TEST_ASSERT_EQUAL(visitor_mind.current, visitor, "A deleted vat woke this ghost")
	wake(visitor_ghost, ship_vat)
	TEST_ASSERT_EQUAL(visitor_mind.current, visitor, "A growing ship vat woke this ghost")
	wake(visitor_ghost, visitor_vat)
	var/mob/living/carbon/human/clone = visitor_mind.current
	TEST_ASSERT(clone && clone != visitor, "Wake did not claim the ready clone")
	made_mobs += clone
	TEST_ASSERT_NULL(visitor_vat.imprint_mind_ref, "A claimed outpost vat kept its imprint")
	TEST_ASSERT_EQUAL(visitor_vat.paid_amount, 0, "A claimed outpost vat kept its payment")
	TEST_ASSERT(!(visitor_vat in LAZYACCESS(GLOB.imprinted_vats_by_ckey, "clonewakevisitor")), "A used-up vat stayed in the chooser index")

	// The emptied vat takes a new imprint
	var/mob/living/carbon/human/next = make_market_visitor(floors[1], "clonewakenext", 1000)
	TEST_ASSERT_NULL(visitor_vat.paid_imprint(next, home, 600), "A used-up vat refused a new imprint")

// ===== EXPIRY AND BLOCKED HOLDERS =====

/// F-21: an expired paid imprint leaves nothing behind; B-10: a blocked resident's ghost is not a member
/datum/unit_test/voidcrew_outpost_cloning_bay/expiry

/datum/unit_test/voidcrew_outpost_cloning_bay/expiry/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("cloneexpiryowner")
	TEST_ASSERT_NOTNULL(home, "The cloning test outpost did not load")
	var/list/floors = bay_test_floors(home, 3)
	TEST_ASSERT_EQUAL(length(floors), 3, "Not enough free floor on the test outpost")
	var/obj/machinery/cloning_vat/outpost/vat = make_test_vat(floors[1])
	var/obj/machinery/cloning_vat/outpost/held_vat = make_test_vat(floors[2])
	make_market_visitor(floors[3], "cloneexpiryowner", 0)
	var/mob/living/carbon/human/visitor = make_market_visitor(floors[1], "cloneexpiryvisitor", 2000)
	home.treasury.account_balance = 1000

	TEST_ASSERT_NULL(vat.paid_imprint(visitor, home, 600), "The visitor could not imprint")
	vat.expire_imprint()
	TEST_ASSERT_EQUAL(vat.paid_amount, 0, "Expiry kept the payment")
	TEST_ASSERT_NULL(vat.imprint_ckey, "Expiry kept the imprint ckey")
	TEST_ASSERT_NULL(vat.imprint_mind_ref, "Expiry kept the imprint")

	var/datum/mind/visitor_mind = visitor.mind
	TEST_ASSERT_NULL(held_vat.paid_imprint(visitor, home, 600), "The visitor could not imprint again")
	grow(held_vat)
	var/mob/dead/observer/ghost = kill_to_ghost(visitor, FALSE)
	home.residents += visitor_mind
	TEST_ASSERT(held_vat.holder_is_member(home, ghost, visitor_mind), "A resident's ghost is not a member")
	home.blocked_residents += "cloneexpiryvisitor"
	TEST_ASSERT(!held_vat.holder_is_member(home, ghost, visitor_mind), "A blocked resident's ghost counts as a member")
	home.dock_mode = "lockdown"
	TEST_ASSERT_EQUAL(held_vat.claim_denial(ghost, visitor_mind), "[home.name] is in lockdown.", "A blocked resident's ghost woke during a lockdown")
	home.dock_mode = "open"

// ===== THE ROOM =====

/// Placement at every rotation: 8 vats where the map puts them, one fanned door, the outpost's own area
/datum/unit_test/voidcrew_outpost_cloning_bay/placement

/datum/unit_test/voidcrew_outpost_cloning_bay/placement/Run()
	var/list/bay_maps = outpost_style_maps(/datum/map_template/outpost_upgrade/cloning_bay)
	TEST_ASSERT(length(bay_maps), "The cloning bay has no map")
	for(var/datum/map_template/map_type as anything in bay_maps)
		var/datum/parsed_map/parsed = new(file(initial(map_type.mappath)))
		var/datum/map_report/report = parsed.check_for_errors()
		if(report)
			TEST_FAIL("The [map_type] map has errors: bad paths [jointext(report.bad_paths, ", ")], bad keys [jointext(report.bad_keys, ", ")]")
			qdel(report)
		qdel(parsed)

	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("clonebayplacer")
	TEST_ASSERT_NOTNULL(home, "The cloning bay placement outpost did not load")
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "clonebayplacer")
	var/list/placed_turfs = list()
	for(var/rotation in list(0, 90, 180, 270))
		var/mapping_log_count = length(GLOB.unit_test_mapping_logs)
		var/result = place_test_service_room(home, /datum/outpost_upgrade/service/cloning_bay, list(rotation), owner)
		if(!istype(result, /datum/outpost_upgrade/service/cloning_bay))
			TEST_FAIL("The cloning bay could not be placed at [rotation] degrees: [result]")
			continue
		var/datum/outpost_upgrade/service/cloning_bay/room = result
		if(length(GLOB.unit_test_mapping_logs) > mapping_log_count)
			TEST_FAIL("Placing the cloning bay at [rotation] degrees logged mapping errors: [jointext(GLOB.unit_test_mapping_logs.Copy(mapping_log_count + 1), "; ")]")
		var/turf/bottom_left = locate(room.footprint_bounds[1], room.footprint_bounds[2], room.footprint_bounds[5])
		TEST_ASSERT_EQUAL(length(room.room_vats()), 8, "The cloning bay did not find 8 vats at [rotation] degrees")
		for(var/problem in room.contract_problems())
			TEST_FAIL("The cloning bay at [rotation] degrees: [problem]")
		for(var/obj/machinery/cloning_vat/outpost/vat as anything in room.room_vats())
			TEST_ASSERT(room.contains_turf(get_turf(vat)), "A vat stands outside the room at [rotation] degrees")
			TEST_ASSERT_EQUAL(vat.host_outpost(), home, "A room vat did not find its outpost at [rotation] degrees")
			TEST_ASSERT(HAS_TRAIT(vat, "outpost_property"), "A room vat is not outpost property at [rotation] degrees")
		var/list/footprint = room.room_turfs()
		for(var/turf/tile as anything in footprint)
			TEST_ASSERT_EQUAL(tile.loc, room.installed_area, "Room tile [tile.x],[tile.y] is not in the room's own area at [rotation] degrees")
		var/list/doors_out = upgrade_exterior_doors(footprint)
		var/list/exterior = doors_out[1]
		var/list/unfanned = doors_out[2]
		TEST_ASSERT_EQUAL(length(exterior), 1, "The cloning bay should have exactly one door out at [rotation] degrees")
		TEST_ASSERT(!length(unfanned), "The cloning bay's door has no tiny fan at [rotation] degrees")
		var/obj/machinery/door/entrance = exterior[1]
		TEST_ASSERT(istype(entrance, /obj/machinery/door/airlock/outpost/service), "The cloning bay's door is not a service airlock at [rotation] degrees")
		var/list/placed_footprint = room.footprint_at(bottom_left, rotation)
		var/list/entrance_edge = placed_footprint["entrance"]
		TEST_ASSERT(get_turf(entrance) in entrance_edge, "The door is not on the entrance edge at [rotation] degrees")
		placed_turfs += footprint
		// One bay per claim: forget this one so the next rotation can be placed
		home.outpost_upgrades -= "cloning_bay"
		qdel(room)
	settle_room_air(placed_turfs)
