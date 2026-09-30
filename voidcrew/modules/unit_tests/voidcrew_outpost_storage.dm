/**
 * Outpost safe storage (outpost_storage.dm): the room at every rotation, renting and paying,
 * the ckey lock, giving a locker up, admin release, what a locker refuses and what it survives,
 * and the outpost's deletion taking the lockers and their contents with it.
 *
 * Voidcrew defines are not visible from test files, so prices, counts and messages are literals:
 * 13 lockers, a 200 cr default rent, price key "storage_rent".
 */

/// An open tile beside `locker` that a player can stand on, or null
/datum/unit_test/proc/storage_test_stand(obj/locker)
	for(var/direction in GLOB.cardinals)
		var/turf/open/spot = get_step(locker, direction)
		if(istype(spot) && !spot.is_blocked_turf(exclude_mobs = TRUE))
			return spot
	return null

/// A market visitor with a mock client, so the ckey lock counts them as a connected player
/datum/unit_test/voidcrew_outpost_management/proc/storage_test_player(turf/location, player_key, balance = 0)
	var/mob/living/carbon/human/player = make_market_visitor(location, player_key, balance)
	player.mock_client = new()
	return player

/// The account on the ID a market visitor wears
/datum/unit_test/proc/storage_test_account(mob/living/carbon/human/player)
	var/obj/item/card/id/card = player.wear_id?.GetID()
	return card?.registered_account

// ===== THE ROOM =====

/datum/unit_test/voidcrew_outpost_storage_room
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_storage_room/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("storageroomowner")
	TEST_ASSERT_NOTNULL(home, "The storage test outpost did not load")
	var/datum/outpost_upgrade/service/storage/prototype = GLOB.outpost_upgrade_catalog["storage"]
	TEST_ASSERT(istype(prototype), "Safe storage is missing from the upgrade catalog")
	TEST_ASSERT_EQUAL(prototype.price, 1000, "Safe storage has the wrong upgrade price")
	var/datum/map_template/template = prototype.get_template()
	TEST_ASSERT_NOTNULL(template, "The safe storage map did not load")

	var/list/room_turfs = list()
	for(var/rotation in list(0, 90, 180, 270))
		var/mapping_log_count = length(GLOB.unit_test_mapping_logs)
		var/datum/outpost_upgrade/service/storage/room = place_test_service_room(home, new /datum/outpost_upgrade/service/storage(home), list(rotation))
		TEST_ASSERT(istype(room), "Safe storage was not placed at [rotation] degrees: [room]")
		if(length(GLOB.unit_test_mapping_logs) > mapping_log_count)
			TEST_FAIL("Placing safe storage at [rotation] degrees logged mapping errors: [jointext(GLOB.unit_test_mapping_logs.Copy(mapping_log_count + 1), "; ")]")
			return
		var/list/footprint = room.room_turfs()
		room_turfs += footprint

		// Thirteen lockers, numbered 1 to 13, each bound to the room and protected.
		var/list/lockers = room.live_lockers()
		TEST_ASSERT_EQUAL(length(lockers), 13, "The room has the wrong number of lockers at [rotation] degrees")
		var/list/numbers = list()
		for(var/obj/structure/closet/secure_closet/outpost_storage/locker as anything in lockers)
			numbers |= locker.locker_number
			TEST_ASSERT_EQUAL(locker.get_room(), room, "Locker [locker.locker_number] does not know its room at [rotation] degrees")
			TEST_ASSERT_EQUAL(locker.get_home(), home, "Locker [locker.locker_number] does not know its outpost at [rotation] degrees")
			TEST_ASSERT(HAS_TRAIT(locker, "outpost_property"), "Locker [locker.locker_number] is not outpost property at [rotation] degrees")
			TEST_ASSERT(locker.flags_1 & PREVENT_CONTENTS_EXPLOSION_1, "Locker [locker.locker_number] lets explosions reach its contents at [rotation] degrees")
			TEST_ASSERT(blocks_magic_recall(locker), "Locker [locker.locker_number] does not block recall at [rotation] degrees")
			TEST_ASSERT(!locker.renter_ckey && !locker.locked, "Locker [locker.locker_number] starts rented or locked at [rotation] degrees")
			TEST_ASSERT(storage_test_stand(locker), "Locker [locker.locker_number] cannot be reached at [rotation] degrees")
		TEST_ASSERT_EQUAL(length(numbers), 13, "The lockers are not numbered 1 to 13 at [rotation] degrees")
		TEST_ASSERT_EQUAL(min(numbers), 1, "The lockers are not numbered from 1 at [rotation] degrees")
		TEST_ASSERT_EQUAL(max(numbers), 13, "The lockers are not numbered to 13 at [rotation] degrees")

		// The room joined its own area, and everything fixed in it is anchored.
		for(var/turf/tile as anything in footprint)
			TEST_ASSERT_EQUAL(tile.loc, room.installed_area, "Tile [tile.x],[tile.y] is not in the room's own area at [rotation] degrees")
			for(var/obj/structure/fixture in tile)
				TEST_ASSERT(fixture.anchored, "[fixture] at [tile.x],[tile.y] is not anchored at [rotation] degrees")
			if(isclosedturf(tile))
				TEST_ASSERT(istype(tile, /turf/closed/indestructible), "Wall [tile.x],[tile.y] is destructible at [rotation] degrees")
			else
				TEST_ASSERT(istype(tile, /turf/open/indestructible), "Floor [tile.x],[tile.y] is destructible at [rotation] degrees")

		// One vault door, on the entrance edge, fanned, opening from inside.
		var/list/doors = list()
		for(var/turf/tile as anything in footprint)
			for(var/obj/machinery/door/airlock/outpost/service/vault/door in tile)
				doors += door
		TEST_ASSERT_EQUAL(length(doors), 1, "The room should have exactly one door at [rotation] degrees")
		var/obj/machinery/door/airlock/outpost/service/vault/door = doors[1]
		var/list/placed = room.footprint_at(locate(room.footprint_bounds[1], room.footprint_bounds[2], room.footprint_bounds[5]), rotation)
		var/list/entrance = placed["entrance"]
		TEST_ASSERT(get_turf(door) in entrance, "The door is not on the entrance edge at [rotation] degrees")
		TEST_ASSERT(locate(/obj/structure/fans/tiny) in get_turf(door), "The door has no tiny fan at [rotation] degrees")
		TEST_ASSERT_EQUAL(door.unres_sides, turn(room.rotated_entrance(rotation), 180), "The door does not open from inside at [rotation] degrees")
		TEST_ASSERT_NULL(door.id_tag, "The door has an id tag at [rotation] degrees")
		TEST_ASSERT(WEAKREF(door) in room.doors, "The room did not adopt its door at [rotation] degrees")

		// One room per claim: forget this one so the next rotation can be placed.
		home.outpost_upgrades -= "storage"

	settle_room_air(room_turfs)

// ===== RENTING, THE LOCK AND RELEASE =====

/datum/unit_test/voidcrew_outpost_storage_rental
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_storage_rental/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("storageowner")
	TEST_ASSERT_NOTNULL(home, "The storage test outpost did not load")
	var/datum/outpost_upgrade/service/storage/room = place_test_service_room(home, /datum/outpost_upgrade/service/storage)
	TEST_ASSERT(istype(room), "Safe storage was not placed: [room]")
	var/list/lockers = room.live_lockers()
	TEST_ASSERT_EQUAL(length(lockers), 13, "The room has the wrong number of lockers")
	TEST_ASSERT_EQUAL(home.get_price("storage_rent"), 200, "The default locker rent is not 200 cr")

	var/obj/structure/closet/secure_closet/outpost_storage/first = lockers[1]
	var/turf/stand = storage_test_stand(first)
	var/mob/living/carbon/human/owner = storage_test_player(stand, "storageowner")
	var/mob/living/carbon/human/visitor = storage_test_player(stand, "storagevisitor", 1000)
	var/datum/bank_account/visitor_account = storage_test_account(visitor)
	var/treasury_start = home.treasury.account_balance

	// A stale quote is refused and moves no money.
	TEST_ASSERT_EQUAL(first.complete_rental(visitor, 150), "Price changed to 200 cr.", "A stale quote was not refused")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1000, "A stale quote charged the visitor")
	TEST_ASSERT_NULL(first.renter_ckey, "A stale quote rented the locker")
	TEST_ASSERT_EQUAL(first.complete_rental(visitor, "200"), "Price changed.", "A text price was accepted")

	// The visitor rents: charged once from the ID they present, the treasury credited once.
	var/obj/item/card/id/hand_card = allocate(/obj/item/card/id)
	var/datum/bank_account/hand_account = allocate(/datum/bank_account, "Hand card", null, 1, FALSE)
	hand_account.account_balance = 500
	hand_card.registered_account = hand_account
	TEST_ASSERT(visitor.put_in_active_hand(hand_card), "The visitor could not hold a second card")
	TEST_ASSERT_NULL(first.complete_rental(visitor, 200), "A visitor could not rent a vacant locker")
	TEST_ASSERT_EQUAL(hand_account.account_balance, 300, "Renting did not charge the presented card 200 cr")
	TEST_ASSERT_EQUAL(visitor_account.account_balance, 1000, "Renting charged the worn card instead of the presented one")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_start + 200, "The treasury was not credited once")
	var/list/totals = home.service_totals["storage_rent"]
	TEST_ASSERT_EQUAL(totals?["count"], 1, "The rental was not recorded once in the service totals")
	TEST_ASSERT_EQUAL(first.renter_ckey, "storagevisitor", "The locker was not rented to the visitor's ckey")
	TEST_ASSERT(first.locked, "Renting did not lock the locker")
	TEST_ASSERT_NULL(first.id_card, "Renting bound the locker to an ID card")
	TEST_ASSERT_EQUAL(first.paid, 200, "The rental did not record what was paid")
	visitor.dropItemToGround(hand_card)

	// One per player per outpost; a second renter cannot take a rented locker.
	var/obj/structure/closet/secure_closet/outpost_storage/second = lockers[2]
	TEST_ASSERT_EQUAL(second.complete_rental(visitor, 200), "You already rent locker [first.locker_number] here.", "A second rental at the same outpost was allowed")
	var/mob/living/carbon/human/rival = storage_test_player(stand, "storagerival", 1000)
	TEST_ASSERT_EQUAL(first.complete_rental(rival, 200), "Already rented.", "A rented locker was rented again")
	TEST_ASSERT_EQUAL(storage_test_account(rival).account_balance, 1000, "A refused rental charged the rival")

	// Short of money, or no player behind the body: refused with nothing moved.
	var/obj/structure/closet/secure_closet/outpost_storage/third = lockers[3]
	var/mob/living/carbon/human/poor = storage_test_player(stand, "storagepoor", 50)
	TEST_ASSERT_EQUAL(third.complete_rental(poor, 200), "Insufficient credits.", "A short account was not refused")
	var/mob/living/carbon/human/no_client = make_market_visitor(stand, "storagenoclient", 1000)
	TEST_ASSERT_EQUAL(third.complete_rental(no_client, 200), "Not available.", "A body with no player rented a locker")
	TEST_ASSERT_NULL(third.renter_ckey, "A refused rental left a renter")

	// A member rents free (the fee they are shown is 0), and nothing reaches the treasury.
	owner.forceMove(storage_test_stand(second))
	var/treasury_before_member = home.treasury.account_balance
	TEST_ASSERT_NULL(second.complete_rental(owner, 0), "The owner could not rent a locker free")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_before_member, "A member's rental moved money")
	TEST_ASSERT_EQUAL(second.renter_ckey, "storageowner", "The owner's rental was not recorded")

	// The lock answers to the ckey: nobody else, not the owner, not the ID, not a stand-in body.
	TEST_ASSERT(first.locked, "The rented locker was not locked")
	var/obj/item/card/id/renter_card = visitor.wear_id?.GetID()
	var/mob/living/carbon/human/thief = storage_test_player(stand, "storagethief", 0)
	visitor.transferItemToLoc(renter_card, thief.loc)
	TEST_ASSERT(thief.put_in_active_hand(renter_card), "The thief could not hold the renter's ID")
	first.togglelock(thief)
	TEST_ASSERT(first.locked, "Another player holding the renter's ID unlocked the locker")
	owner.forceMove(stand)
	first.togglelock(owner)
	TEST_ASSERT(first.locked, "The outpost owner unlocked a rented locker")
	var/mob/living/carbon/human/steward = storage_test_player(stand, "storagesteward", 0)
	home.residents += steward.mind
	home.stewards += steward.mind
	home.treasurers += steward.mind
	first.togglelock(steward)
	TEST_ASSERT(first.locked, "A steward and treasurer unlocked a rented locker")
	var/mob/living/carbon/human/fake = storage_test_player(stand, "@storagevisitor", 0)
	first.togglelock(fake)
	TEST_ASSERT(first.locked, "A body keyed '@renter' unlocked the locker")
	TEST_ASSERT(!first.is_renter(fake), "A body keyed '@renter' counts as the renter")

	// The same player in another body opens it: a clone, a respawn, a new character.
	var/mob/living/carbon/human/new_body = storage_test_player(stand, null, 0)
	new_body.key = "storagevisitor"
	TEST_ASSERT_EQUAL(new_body.ckey, "storagevisitor", "The new body did not take the renter's key")
	var/datum/client_interface/new_client = new_body.mock_client
	new_body.mock_client = null
	first.togglelock(new_body)
	TEST_ASSERT(first.locked, "The renter's ckey with no player connected unlocked the locker")
	new_body.mock_client = new_client
	TEST_ASSERT(room.admits_visitor_extra(new_body), "The renter is not let through a closed room")
	TEST_ASSERT(!room.admits_visitor_extra(thief), "A non-renter is let through a closed room")

	// The renter reaches the paid locker whatever the room's door is keyed to; nobody else does
	var/datum/weakref/vault_ref = LAZYACCESS(room.doors, 1)
	var/obj/machinery/door/airlock/outpost/service/vault = vault_ref?.resolve()
	TEST_ASSERT_NOTNULL(vault, "The storage room has no door")
	var/turf/vault_outside = get_step(vault, turn(vault.unres_sides, 180))
	home.apply_door_access(vault, "owner")
	new_body.forceMove(vault_outside)
	thief.forceMove(vault_outside)
	TEST_ASSERT(vault.allowed(new_body), "An owner-only storage door refused the renter")
	TEST_ASSERT(!vault.allowed(thief), "An owner-only storage door let in someone who rents nothing")
	home.apply_door_access(vault, "public")
	new_body.forceMove(stand)
	thief.forceMove(stand)

	// Deleting the renter's ID changes nothing (the stock closet would go public).
	qdel(renter_card)
	first.togglelock(thief)
	TEST_ASSERT(first.locked, "Deleting the renter's ID opened the locker to others")
	TEST_ASSERT_EQUAL(first.renter_ckey, "storagevisitor", "Deleting the renter's ID ended the rental")
	first.togglelock(new_body)
	TEST_ASSERT(!first.locked, "The renter in a new body could not unlock the locker")

	// Closing a rented locker locks it again.
	TEST_ASSERT(first.open(new_body), "The unlocked locker would not open")
	var/obj/item/wrench/stored = allocate(/obj/item/wrench, get_turf(first))
	TEST_ASSERT(first.close(new_body), "The rented locker would not close")
	TEST_ASSERT(first.locked, "Closing a rented locker did not lock it")
	TEST_ASSERT_EQUAL(stored.loc, first, "Closing did not take the item on the tile")

	// Giving it up: the renter only, only while open, no refund.
	TEST_ASSERT_EQUAL(first.release(new_body), "Open it first.", "A closed locker was given up with its contents inside")
	first.togglelock(new_body)
	TEST_ASSERT(first.open(new_body), "The renter could not open the locker")
	TEST_ASSERT_EQUAL(first.release(thief), "Not your locker.", "Another player gave up the rental")
	var/treasury_before_release = home.treasury.account_balance
	TEST_ASSERT_NULL(first.release(new_body), "The renter could not give up an open locker")
	TEST_ASSERT_NULL(first.renter_ckey, "Giving up the locker left a renter")
	TEST_ASSERT_EQUAL(hand_account.account_balance, 300, "Giving up the locker refunded the renter")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, treasury_before_release, "Giving up the locker moved treasury money")
	TEST_ASSERT(first.close(new_body), "The vacant locker would not close")
	TEST_ASSERT(!first.locked, "A vacant locker locked itself on closing")

	// The management console sees the room kind only: never contents, never who rents what.
	var/list/detail = room.service_ui_data(owner)
	TEST_ASSERT_EQUAL(detail["kind"], "storage", "The storage detail has the wrong kind")
	TEST_ASSERT_EQUAL(length(detail), 1, "The storage detail sends more than its kind")
	TEST_ASSERT_EQUAL(length(room.live_lockers()), 13, "The room has the wrong locker count")
	var/rented = 0
	for(var/obj/structure/closet/secure_closet/outpost_storage/locker as anything in room.live_lockers())
		if(locker.renter_ckey)
			rented++
	TEST_ASSERT_EQUAL(rented, 1, "The room has the wrong rented count")

	// Admin release through the manipulator rows.
	var/list/rows = room.admin_ui_data()
	TEST_ASSERT_EQUAL(length(rows), 13, "The manipulator should show one row per locker")
	var/list/release_row
	for(var/list/row as anything in rows)
		for(var/key in list("label", "action", "ref"))
			TEST_ASSERT(key in row, "A manipulator row has no [key]")
		if(row["action"] == "release")
			release_row = row
	TEST_ASSERT_NOTNULL(release_row, "The owner's rented locker has no release row")
	var/obj/structure/closet/secure_closet/outpost_storage/stray = allocate(/obj/structure/closet/secure_closet/outpost_storage, home.arrival_turf)
	stray.renter_ckey = "storagestray"
	TEST_ASSERT(room.admin_ui_act(owner, "release", list("ref" = REF(stray))), "The release action was not handled")
	TEST_ASSERT_EQUAL(stray.renter_ckey, "storagestray", "The release action reached a locker outside the room")
	TEST_ASSERT(room.admin_ui_act(owner, "release", list("ref" = release_row["ref"])), "The release action was not handled")
	TEST_ASSERT_NULL(second.renter_ckey, "The admin release did not end the rental")
	TEST_ASSERT(!second.locked, "The admin release left the locker locked")
	TEST_ASSERT(!room.admin_ui_act(owner, "unknown", list()), "An unknown admin action was handled")

	// The same player may rent at another outpost.
	var/obj/structure/overmap/dynamic/player_outpost/other_home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	other_home.loaded = TRUE
	var/datum/outpost_upgrade/service/storage/other_room = new(other_home)
	other_home.outpost_upgrades["storage"] = other_room
	other_room.installed = TRUE
	var/mob/living/carbon/human/traveller = storage_test_player(storage_test_stand(third), "storagetraveller", 1000)
	TEST_ASSERT_NULL(third.complete_rental(traveller, 200), "A visitor could not rent here")
	// A stand-in locker of the other outpost, on the traveller's own tile so it is in reach
	var/obj/structure/closet/secure_closet/outpost_storage/other_locker = allocate(/obj/structure/closet/secure_closet/outpost_storage, get_turf(traveller))
	other_locker.room_ref = WEAKREF(other_room)
	other_room.lockers = list(WEAKREF(other_locker))
	// The other outpost has no owner, so its lockers are free
	TEST_ASSERT_NULL(other_locker.complete_rental(traveller, 0), "A renter here could not rent at another outpost")
	other_home.loaded = FALSE

	// Abandonment keeps every rental; an ownerless outpost rents free.
	home.abandon(owner)
	TEST_ASSERT_NULL(home.founder_ckey, "The outpost was not abandoned")
	TEST_ASSERT_EQUAL(third.renter_ckey, "storagetraveller", "Abandoning the outpost ended a rental")
	TEST_ASSERT(third.locked, "Abandoning the outpost unlocked a rental")
	var/obj/structure/closet/secure_closet/outpost_storage/fourth = lockers[4]
	var/rival_balance = storage_test_account(rival).account_balance
	rival.forceMove(storage_test_stand(fourth))
	TEST_ASSERT_NULL(fourth.complete_rental(rival, 0), "An ownerless outpost did not rent free")
	TEST_ASSERT_EQUAL(storage_test_account(rival).account_balance, rival_balance, "An ownerless outpost charged for a locker")

// ===== WHAT A LOCKER REFUSES AND SURVIVES =====

/datum/unit_test/voidcrew_outpost_storage_locker
	/// Set when an explosion started inside a locker reached its area
	var/explosion_escaped = FALSE

/datum/unit_test/voidcrew_outpost_storage_locker/proc/on_area_explosion(datum/source, list/arguments)
	SIGNAL_HANDLER
	explosion_escaped = TRUE
	return COMSIG_CANCEL_EXPLOSION

/datum/unit_test/voidcrew_outpost_storage_locker/Run()
	var/obj/structure/closet/secure_closet/outpost_storage/locker = allocate(/obj/structure/closet/secure_closet/outpost_storage, run_loc_floor_bottom_left)
	var/turf/locker_turf = get_turf(locker)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, get_step(locker_turf, NORTH))
	user.set_combat_mode(FALSE)

	// Refused at any depth: mobs, corpses, held mobs, brains, bombs and triggers.
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, locker_turf)
	TEST_ASSERT(!locker.insert(person), "A living person was put in a locker")
	var/mob/living/carbon/human/consistent/corpse = allocate(/mob/living/carbon/human/consistent, locker_turf)
	corpse.death()
	TEST_ASSERT(!locker.insert(corpse), "A corpse was put in a locker")
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, locker_turf)
	var/obj/item/mob_holder/held = allocate(/obj/item/mob_holder, locker_turf, mouse)
	TEST_ASSERT(!locker.insert(held), "A held mob was put in a locker")
	var/obj/item/organ/brain/brain = allocate(/obj/item/organ/brain, locker_turf)
	allocate(/mob/living/brain, brain)
	TEST_ASSERT(!locker.insert(brain), "A brain with a brainmob was put in a locker")
	TEST_ASSERT(!locker.insert(allocate(/obj/item/grenade/chem_grenade, locker_turf)), "A grenade was put in a locker")
	TEST_ASSERT(!locker.insert(allocate(/obj/item/transfer_valve, locker_turf)), "A tank transfer valve was put in a locker")
	var/obj/item/storage/backpack/bomb_bag = allocate(/obj/item/storage/backpack, locker_turf)
	allocate(/obj/item/assembly/signaler, bomb_bag)
	TEST_ASSERT(!locker.insert(bomb_bag), "A backpack holding a signaler was put in a locker")
	var/obj/item/tank/internals/plasma/rigged = allocate(/obj/item/tank/internals/plasma, locker_turf)
	rigged.tank_assembly = allocate(/obj/item/assembly_holder, locker_turf)
	TEST_ASSERT(!locker.insert(rigged), "A rigged tank was put in a locker")
	rigged.tank_assembly = null
	var/obj/item/storage/backpack/kit_bag = allocate(/obj/item/storage/backpack, locker_turf)
	allocate(/obj/item/wrench, kit_bag)
	allocate(/obj/item/crowbar, kit_bag)
	TEST_ASSERT(locker.insert(kit_bag), "A backpack of ordinary items was refused")
	TEST_ASSERT(locker.insert(allocate(/obj/item/assembly/signaler/anomaly/pyro, locker_turf)), "An anomaly core was refused")
	var/mob/living/carbon/human/consistent/shoved = allocate(/mob/living/carbon/human/consistent, locker_turf)
	shoved.forceMove(locker)
	TEST_ASSERT_EQUAL(shoved.loc, locker_turf, "A person moved straight into a locker stayed inside")

	// Closing leaves refused things on the tile and takes the rest.
	TEST_ASSERT(locker.open(user), "The vacant locker would not open")
	var/obj/item/grenade/chem_grenade/left_out = allocate(/obj/item/grenade/chem_grenade, locker_turf)
	var/obj/item/screwdriver/taken = allocate(/obj/item/screwdriver, locker_turf)
	TEST_ASSERT(locker.close(user), "The locker would not close")
	TEST_ASSERT_EQUAL(left_out.loc, locker_turf, "Closing took a grenade")
	TEST_ASSERT_EQUAL(taken.loc, locker, "Closing left an ordinary item out")

	// B-08: ship keys and contract goods stay out, as they do at cryo
	TEST_ASSERT(locker.open(user), "The locker would not open for the key test")
	var/obj/item/storage/backpack/key_bag = allocate(/obj/item/storage/backpack, locker_turf)
	var/obj/item/ship_key/stolen_key = allocate(/obj/item/ship_key, key_bag)
	var/obj/item/mission_recovery/payload = allocate(/obj/item/mission_recovery, locker_turf)
	TEST_ASSERT(locker.close(user), "The locker would not close on the key test")
	TEST_ASSERT_EQUAL(key_bag.loc, locker_turf, "Closing took a bag holding a ship key")
	TEST_ASSERT_EQUAL(payload.loc, locker_turf, "Closing took contract goods")
	TEST_ASSERT(!(stolen_key in locker.get_all_contents()), "A ship key ended up in a locker")

	// Store by click: an item used on an open locker goes in, and does not hit it.
	TEST_ASSERT(locker.open(user), "The locker would not reopen")
	var/obj/item/wrench/clicked = allocate(/obj/item/wrench)
	TEST_ASSERT(user.put_in_active_hand(clicked), "The user could not hold the item")
	var/integrity = locker.get_integrity()
	clicked.melee_attack_chain(user, locker)
	TEST_ASSERT_EQUAL(clicked.loc, locker_turf, "Clicking an open locker with an item did not put it in")
	TEST_ASSERT_EQUAL(locker.get_integrity(), integrity, "Clicking an open locker with an item hit it")
	TEST_ASSERT(locker.close(user), "The locker would not close again")

	// A rented, locked locker survives everything with its contents inside.
	locker.renter_ckey = "storagelockertest"
	locker.lock()
	var/obj/item/crowbar/valuable = allocate(/obj/item/crowbar)
	valuable.forceMove(locker)
	SEND_SIGNAL(locker_turf, COMSIG_ATOM_MAGICALLY_UNLOCKED, null, user)
	TEST_ASSERT(locker.locked && !locker.opened, "Knock opened a rented locker")
	TEST_ASSERT(!locker.emag_act(user, null), "An emag worked on a locker")
	TEST_ASSERT(locker.locked && !locker.broken, "An emag broke a locker's lock")
	for(var/i in 1 to 20)
		locker.emp_act(EMP_HEAVY)
	TEST_ASSERT(locker.locked && !locker.opened, "EMPs flipped a locker's lock")
	locker.bust_open()
	TEST_ASSERT(locker.locked && !locker.opened && !locker.broken, "A locker was busted open")
	locker.singularity_act()
	locker.singularity_pull(user, 11)
	TEST_ASSERT(!QDELETED(locker) && locker.loc == locker_turf, "A singularity took a locker")
	var/mob/living/carbon/human/consistent/shove_target = allocate(/mob/living/carbon/human/consistent, locker_turf)
	SEND_SIGNAL(locker_turf, COMSIG_LIVING_DISARM_COLLIDE, user, shove_target, NONE)
	TEST_ASSERT(locker.locked && !locker.opened && shove_target.loc == locker_turf, "A shove opened a locker or put someone in it")
	TEST_ASSERT_EQUAL(valuable.loc, locker, "The stored item left the locker")

	// Explosions: the locker and its contents stay; one started inside never gets out.
	EX_ACT(locker, EXPLODE_DEVASTATE)
	TEST_ASSERT(!QDELETED(locker) && !QDELETED(valuable) && valuable.loc == locker, "An explosion reached a locker's contents")
	TEST_ASSERT(!(valuable in SSexplosions.high_mov_atom), "An explosion queued a locker's contents")
	var/area/locker_area = get_area(locker)
	RegisterSignal(locker_area, COMSIG_AREA_INTERNAL_EXPLOSION, PROC_REF(on_area_explosion))
	explosion(valuable, 1, 2, 3, adminlog = FALSE, silent = TRUE)
	UnregisterSignal(locker_area, COMSIG_AREA_INTERNAL_EXPLOSION)
	TEST_ASSERT(!explosion_escaped, "An explosion inside a locker got out")

	// Tools: anchored, and wrenching, welding and prying are refused.
	TEST_ASSERT(locker.anchored && !locker.anchorable, "A locker is not bolted down")
	TEST_ASSERT(!user.start_pulling(locker) && user.pulling != locker, "A locker could be pulled")
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	TEST_ASSERT(SEND_SIGNAL(locker, COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_WRENCH), user, wrench) & ITEM_INTERACT_BLOCKING, "A wrench could unbolt a locker")
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	TEST_ASSERT(SEND_SIGNAL(locker, COMSIG_ATOM_TOOL_ACT(TOOL_WELDER), user, welder, list()) & ITEM_INTERACT_BLOCKING, "A welder could work a locker")
	TEST_ASSERT(!locker.can_weld_shut, "A locker can be welded shut")
	TEST_ASSERT(!locker.tool_interact(welder, user), "A locker's tool interaction took a welder")

	// Gas from a leaking stored tank does not reach the room.
	var/turf/open/room_turf = locker_turf
	var/moles_before = room_turf.air.total_moles()
	var/datum/gas_mixture/leak = new
	leak.add_gas(/datum/gas/plasma)
	leak.gases[/datum/gas/plasma][MOLES] = 100
	var/obj/item/tank/internals/plasma/leaker = allocate(/obj/item/tank/internals/plasma)
	leaker.forceMove(locker)
	leaker.loc.assume_air(leak)
	TEST_ASSERT(room_turf.air.total_moles() < moles_before + 1, "Gas leaking inside a locker reached the room")

	// A marked item is not recalled out of the locker.
	var/mob/living/carbon/human/consistent/wizard = allocate(/mob/living/carbon/human/consistent, get_step(locker_turf, EAST))
	var/datum/action/cooldown/spell/summonitem/recall = allocate(/datum/action/cooldown/spell/summonitem)
	recall.mark_item(valuable)
	recall.try_recall_item(wizard)
	TEST_ASSERT_EQUAL(valuable.loc, locker, "A marked item was recalled out of a locker")
	recall.unmark_item()

// ===== DELETION =====

/// Deleting the outpost deletes the lockers and everything in them (M4).
/datum/unit_test/voidcrew_outpost_storage_deletion
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_storage_deletion/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("storagedeleteowner")
	TEST_ASSERT_NOTNULL(home, "The storage test outpost did not load")
	var/datum/outpost_upgrade/service/storage/room = place_test_service_room(home, /datum/outpost_upgrade/service/storage)
	TEST_ASSERT(istype(room), "Safe storage was not placed: [room]")
	var/list/lockers = room.live_lockers()
	TEST_ASSERT_EQUAL(length(lockers), 13, "The room has the wrong number of lockers")
	var/obj/structure/closet/secure_closet/outpost_storage/locker = lockers[1]
	locker.renter_ckey = "storagedeleterenter"
	var/obj/item/wrench/stored = new(locker)
	locker.lock()
	settle_room_air(room.room_turfs())
	qdel(home)
	TEST_ASSERT(QDELETED(room), "Deleting the outpost left its storage room")
	TEST_ASSERT(QDELETED(locker), "Deleting the outpost left a rented locker")
	TEST_ASSERT(QDELETED(stored), "Deleting the outpost left a rented locker's contents")
