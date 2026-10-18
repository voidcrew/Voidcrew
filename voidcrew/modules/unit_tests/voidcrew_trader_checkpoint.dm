/**
 * Trader outpost checkpoints: the scan chamber, weapons permits, armed trespass and sealed goods
 * (voidcrew/modules/trade/outpost_checkpoint.dm, outpost_checkpoint_guard.dm, outpost_trespass.dm).
 *
 * The trade defines are included after the tests, so states and durations are written out with a
 * comment naming their define.
 */

/// A five by seven concourse in a reservation: checkpoint lobby below, one two-tile scan chamber, the concourse above
/datum/unit_test/voidcrew_trader_checkpoint
	abstract_type = /datum/unit_test/voidcrew_trader_checkpoint
	var/obj/structure/overmap/trader_outpost/host
	var/datum/outpost_checkpoint/checkpoint
	var/obj/machinery/door/airlock/outpost/checkpoint/outer/outer
	var/obj/machinery/door/airlock/outpost/checkpoint/inner/inner
	var/mob/living/basic/outpost_trader/checkpoint_guard/guard
	/// In front of the outer door
	var/turf/lobby
	/// Beyond the inner door
	var/turf/secured
	var/list/turf/chamber = list()
	/// Turfs moved into a test area -> the area each came from
	var/list/original_areas = list()
	/// Areas made for the test
	var/list/test_areas = list()

/datum/unit_test/voidcrew_trader_checkpoint/Destroy()
	for(var/turf/location as anything in original_areas)
		location.change_area(get_area(location), original_areas[location])
	original_areas = null
	QDEL_LIST(test_areas)
	chamber = null
	return ..()

/datum/unit_test/voidcrew_trader_checkpoint/proc/put_in_area(turf/location, area_type)
	var/area/target = GLOB.areas_by_type[area_type]
	if(!target)
		target = new area_type()
		test_areas += target
	if(!original_areas[location])
		original_areas[location] = get_area(location)
	location.change_area(get_area(location), target)

/datum/unit_test/voidcrew_trader_checkpoint/proc/fixture(with_guard = TRUE)
	host = allocate(/obj/structure/overmap/trader_outpost/general)
	host.outpost_template = new /datum/map_template/trader_outpost
	host.outpost_template.width = 5
	host.outpost_template.height = 7
	host.reservation = SSmapping.request_turf_block_reservation(5, 7, 1)
	TEST_ASSERT_NOTNULL(host.reservation, "Could not reserve the checkpoint fixture")
	host.template_bottom_left = host.reservation.bottom_left_turfs[1]
	var/turf/origin = host.template_bottom_left
	for(var/dx in 0 to 4)
		for(var/dy in 0 to 6)
			var/turf/tile = locate(origin.x + dx, origin.y + dy, origin.z)
			var/is_wall = dy >= 2 && dy <= 4 && dx != 2 && !(dy == 3 && dx == 3)
			tile = tile.ChangeTurf(is_wall ? /turf/closed/indestructible : /turf/open/indestructible)
			put_in_area(tile, dy >= 5 ? /area/voidcrew/trader_outpost : /area/voidcrew/trader_outpost/checkpoint)
	lobby = locate(origin.x + 2, origin.y + 1, origin.z)
	secured = locate(origin.x + 2, origin.y + 5, origin.z)
	chamber = list(locate(origin.x + 2, origin.y + 3, origin.z), locate(origin.x + 3, origin.y + 3, origin.z))
	outer = allocate(/obj/machinery/door/airlock/outpost/checkpoint/outer, locate(origin.x + 2, origin.y + 2, origin.z))
	outer.checkpoint_id = "test_checkpoint"
	outer.set_machine_stat(NONE)
	inner = allocate(/obj/machinery/door/airlock/outpost/checkpoint/inner, locate(origin.x + 2, origin.y + 4, origin.z))
	inner.checkpoint_id = "test_checkpoint"
	inner.set_machine_stat(NONE)
	for(var/turf/tile as anything in chamber)
		var/obj/machinery/outpost_checkpoint_scanner/arch = allocate(/obj/machinery/outpost_checkpoint_scanner, tile)
		arch.checkpoint_id = "test_checkpoint"
	if(with_guard)
		guard = allocate(/mob/living/basic/outpost_trader/checkpoint_guard/halcyon, locate(origin.x + 4, origin.y + 6, origin.z))
		guard.checkpoint_id = "test_checkpoint"
	host.link_interior_machinery()
	checkpoint = host.checkpoints["test_checkpoint"]
	TEST_ASSERT_NOTNULL(checkpoint, "The fixture checkpoint did not assemble")
	TEST_ASSERT_EQUAL(checkpoint.lobby_turf, lobby, "The outer door's far side is not the lobby")
	TEST_ASSERT_EQUAL(checkpoint.secured_turf, secured, "The inner door's far side is not the concourse")
	TEST_ASSERT_EQUAL(length(checkpoint.chamber_turfs), 2, "The chamber is not its two arch tiles")
	if(with_guard)
		TEST_ASSERT_EQUAL(checkpoint.guard, guard, "The guard was not matched to the checkpoint")
	return TRUE

/// A person with a mind, standing in the lobby
/datum/unit_test/voidcrew_trader_checkpoint/proc/visitor(turf/where)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, where || lobby)
	person.mind_initialize()
	allocated += person.mind
	return person

/// Asks for a cycle as `asker` and settles the scan at once, without the hum
/datum/unit_test/voidcrew_trader_checkpoint/proc/scan_now(mob/living/asker)
	if(!checkpoint.request_cycle(asker))
		return FALSE
	if(checkpoint.state != "scanning") // CHECKPOINT_SCANNING
		return FALSE
	checkpoint.finish_scan()
	return TRUE

/// Walks the doors back to idle between cases
/datum/unit_test/voidcrew_trader_checkpoint/proc/settle()
	sleep(2 SECONDS)
	if(!inner.density)
		checkpoint.close_door(inner)
	if(!outer.density)
		checkpoint.close_door(outer)
	sleep(2 SECONDS)
	checkpoint.set_state("idle") // CHECKPOINT_IDLE
	checkpoint.last_refused.Cut()

// ===== THE CHAMBER =====

/// Work tools and disablers pass every checkpoint weapon check; a laser remains restricted.
/datum/unit_test/voidcrew_trader_checkpoint/gun_classification
	abstract_type = /datum/unit_test/voidcrew_trader_checkpoint/gun_classification
	var/gun_type
	var/restricted = FALSE

/datum/unit_test/voidcrew_trader_checkpoint/gun_classification/disabler
	gun_type = /obj/item/gun/energy/disabler

/datum/unit_test/voidcrew_trader_checkpoint/gun_classification/kinetic_accelerator
	gun_type = /obj/item/gun/energy/recharge/kinetic_accelerator

/datum/unit_test/voidcrew_trader_checkpoint/gun_classification/plasma_cutter
	gun_type = /obj/item/gun/energy/plasmacutter

/datum/unit_test/voidcrew_trader_checkpoint/gun_classification/laser
	gun_type = /obj/item/gun/energy/laser
	restricted = TRUE

/datum/unit_test/voidcrew_trader_checkpoint/gun_classification/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	var/obj/item/gun/held_gun = allocate(gun_type)
	TEST_ASSERT(person.put_in_hands(held_gun), "Could not hold [gun_type] for the scan")
	TEST_ASSERT(scan_now(person), "Could not start a scan for [gun_type]")
	var/expected_state = restricted ? "rejecting" : "passing" // CHECKPOINT_REJECTING / CHECKPOINT_PASSING
	TEST_ASSERT_EQUAL(checkpoint.state, expected_state, "The scan misclassified [gun_type]")
	person.forceMove(secured)
	host.armed_sweep(list(person))
	TEST_ASSERT(!host.is_armed_trespasser(person.mind), "[gun_type] was flagged before the sighting grace")
	if(!restricted)
		TEST_ASSERT(!length(host.armed_sightings), "Holding [gun_type] started an armed sighting")
	host.armed_sightings[person.mind] = world.time - 2 SECONDS // OUTPOST_ARMED_SIGHTING_GRACE
	host.armed_sweep(list(person))
	TEST_ASSERT_EQUAL(!!host.is_armed_trespasser(person.mind), restricted, "Holding [gun_type] was misclassified after the sighting grace")
	TEST_ASSERT(!length(host.armed_sightings), "An armed sighting of [gun_type] was left pending")
	// A separate visitor proves the fired-gun signal independently of the holding check.
	var/mob/living/carbon/human/shooter = visitor(secured)
	var/obj/item/gun/fired_gun = allocate(gun_type)
	TEST_ASSERT(shooter.put_in_hands(fired_gun), "Could not hold [gun_type] for firing")
	SEND_SIGNAL(shooter, COMSIG_MOB_FIRED_GUN, fired_gun, lobby, null, null, list(0, 0))
	TEST_ASSERT_EQUAL(!!host.is_armed_trespasser(shooter.mind), restricted, "Firing [gun_type] was misclassified")
	var/obj/item/gun/goods = allocate(gun_type, secured)
	var/obj/item/handed_over = outpost_seal_goods(goods)
	if(restricted)
		TEST_ASSERT(istype(handed_over, /obj/item/outpost_sealed_case), "[gun_type] was handed over without a seal")
		allocated += handed_over
		TEST_ASSERT_EQUAL(goods.loc, handed_over, "[gun_type] was left outside its sealed case")
	else
		TEST_ASSERT_EQUAL(handed_over, goods, "[gun_type] was needlessly sealed")

/// Clean people pass together, and a clean result is never stored on the doors
/datum/unit_test/voidcrew_trader_checkpoint/clean_group/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/first = visitor(chamber[1])
	var/mob/living/carbon/human/second = visitor(chamber[2])
	allocate(/obj/item/storage/backpack, second)
	TEST_ASSERT(scan_now(first), "Walking into the inner door did not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "passing", "A clean group was not passed") // CHECKPOINT_PASSING
	sleep(2 SECONDS)
	TEST_ASSERT(!inner.density, "The inner door did not open for a clean group")
	TEST_ASSERT(outer.density, "The outer door opened with the inner door")
	TEST_ASSERT(!checkpoint.request_outer(first), "The outer door opened while the inner door was open")
	checkpoint.close_door(inner)
	sleep(2 SECONDS)
	TEST_ASSERT(inner.density, "The inner door did not close after the pass")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The checkpoint did not go idle after the pass") // CHECKPOINT_IDLE
	TEST_ASSERT(!inner.open(), "A pass left the inner door openable")
	TEST_ASSERT(!inner.open(BYPASS_DOOR_CHECKS), "A forced open() got through the inner door")
	TEST_ASSERT(!outer.open(BYPASS_DOOR_CHECKS), "A forced open() got through the outer door")

/// Only one door is ever open: the outer door closes before the chamber scans, and nothing opens the inner door around the scan
/datum/unit_test/voidcrew_trader_checkpoint/interlock/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor()
	TEST_ASSERT(checkpoint.request_outer(person), "The outer door did not open for someone in the lobby")
	sleep(2 SECONDS)
	TEST_ASSERT(!outer.density, "The outer door did not open")
	person.forceMove(chamber[1])
	inner.bumpopen(person)
	TEST_ASSERT(inner.density, "Bumping the inner door opened it")
	for(var/i in 1 to 30)
		if(outer.density && !outer.operating)
			break
		sleep(0.1 SECONDS)
	TEST_ASSERT(outer.density, "Asking to go through did not shut the outer door first")
	TEST_ASSERT_EQUAL(checkpoint.state, "scanning", "Shutting the outer door on someone did not start a scan") // CHECKPOINT_SCANNING
	TEST_ASSERT(!checkpoint.request_outer(person), "The outer door opened mid-scan")
	TEST_ASSERT(!checkpoint.request_cycle(person), "A second scan started mid-scan")
	// Every ordinary route to the inner door
	inner.try_to_activate_door(person)
	inner.attack_hand(person, list())
	var/obj/item/card/id/advanced/id = allocate(/obj/item/card/id/advanced)
	id.access = list(ACCESS_WEAPONS, ACCESS_SECURITY)
	inner.attackby(id, person, list(), list())
	inner.wires.on_pulse(WIRE_OPEN)
	inner.on_magic_unlock(get_turf(inner), null, person)
	inner.prison_open()
	TEST_ASSERT(inner.density && !inner.operating, "An ordinary route opened the inner door mid-scan")
	sleep(3 SECONDS) // OUTPOST_CHECKPOINT_SCAN_TIME
	TEST_ASSERT_EQUAL(checkpoint.state, "passing", "The scan did not finish on its own") // CHECKPOINT_PASSING

/// A gun lying on the chamber floor is refused, put back out, and the group backs out
/datum/unit_test/voidcrew_trader_checkpoint/floor_gun/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol, chamber[2])
	TEST_ASSERT(scan_now(person), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "A gun on the floor passed") // CHECKPOINT_REJECTING
	TEST_ASSERT_EQUAL(get_turf(gun), lobby, "Loose contraband was not put back out")
	TEST_ASSERT(get_turf(person) in chamber, "A first refusal walked someone out")
	sleep(2 SECONDS)
	TEST_ASSERT(inner.density, "A refused scan opened the inner door")
	TEST_ASSERT(!outer.density, "A refused scan did not open the outer door")

/// A gun in a box in a backpack is found; refused twice in a row, its carrier is walked out
/datum/unit_test/voidcrew_trader_checkpoint/nested_gun/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, person)
	var/obj/item/storage/box/box = allocate(/obj/item/storage/box, bag)
	allocate(/obj/item/gun/energy/laser, box)
	TEST_ASSERT(scan_now(person), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "A nested gun passed") // CHECKPOINT_REJECTING
	TEST_ASSERT(get_turf(person) in chamber, "A first refusal walked someone out")
	checkpoint.set_state("idle") // CHECKPOINT_IDLE
	sleep(2 SECONDS)
	checkpoint.close_door(outer)
	sleep(2 SECONDS)
	TEST_ASSERT(outer.density, "The outer door did not close on the refused group")
	TEST_ASSERT_EQUAL(checkpoint.state, "scanning", "Closing the outer door on people did not scan again") // CHECKPOINT_SCANNING
	checkpoint.finish_scan()
	TEST_ASSERT_EQUAL(get_turf(person), lobby, "Someone refused twice in a row was not walked out")

/// Implants and organs are part of the person: an arm-mounted gun is found while retracted
/datum/unit_test/voidcrew_trader_checkpoint/implanted_gun/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	var/obj/item/organ/cyberimp/arm/toolkit/gun/laser/implant = allocate(/obj/item/organ/cyberimp/arm/toolkit/gun/laser)
	implant.Insert(person)
	TEST_ASSERT(implant.owner == person, "The arm implant did not go in")
	TEST_ASSERT(!length(person.held_items - null), "The implanted gun started out in hand")
	TEST_ASSERT(scan_now(person), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "An implanted gun passed") // CHECKPOINT_REJECTING

/// A smuggler's satchel still hides what is inside it
/datum/unit_test/voidcrew_trader_checkpoint/shielded_storage/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, person)
	allocate(/obj/item/gun/ballistic/automatic/pistol, bag)
	ADD_TRAIT(bag, TRAIT_CONTRABAND_BLOCKER, TRAIT_GENERIC)
	TEST_ASSERT(scan_now(person), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "passing", "Contraband-shielded storage lost its shielding") // CHECKPOINT_PASSING

/// Mindshields and weapon-access IDs exempt nobody
/datum/unit_test/voidcrew_trader_checkpoint/no_exemptions/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	allocate(/obj/item/gun/ballistic/automatic/pistol, person)
	ADD_TRAIT(person, TRAIT_MINDSHIELD, TRAIT_GENERIC)
	var/obj/item/card/id/advanced/id = allocate(/obj/item/card/id/advanced)
	id.access = list(ACCESS_WEAPONS, ACCESS_SECURITY, ACCESS_CAPTAIN)
	person.equip_to_slot_or_del(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING)
	person.equip_to_slot_or_del(id, ITEM_SLOT_ID)
	TEST_ASSERT(scan_now(person), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "A mindshield or a weapons ID let a gun through") // CHECKPOINT_REJECTING

/// Someone the outpost bars is refused even with nothing on them
/datum/unit_test/voidcrew_trader_checkpoint/barred/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	host.flag_trespasser(person)
	TEST_ASSERT(scan_now(person), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "A barred person was let through") // CHECKPOINT_REJECTING

// ===== PERMITS =====

/// A permit lets its holder through armed; it is personal, the paper proves nothing, and it runs out
/datum/unit_test/voidcrew_trader_checkpoint/permit/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/holder = visitor(chamber[1])
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, holder)
	allocate(/obj/item/gun/ballistic/automatic/pistol, bag)
	TEST_ASSERT(host.grant_weapons_permit(holder), "Could not issue a permit")
	TEST_ASSERT(host.has_weapons_permit(holder), "The permit was not recorded")
	TEST_ASSERT(scan_now(holder), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "passing", "A permit holder was refused") // CHECKPOINT_PASSING
	settle()
	// Personal: another person carrying a gun (and the holder's receipt) is still refused
	holder.forceMove(lobby)
	var/mob/living/carbon/human/friend = visitor(chamber[2])
	allocate(/obj/item/gun/ballistic/automatic/pistol, friend)
	var/obj/item/paper/weapons_permit/receipt = allocate(/obj/item/paper/weapons_permit, friend)
	receipt.fill_in(holder, host, host.weapon_permits[holder.mind])
	TEST_ASSERT(scan_now(friend), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "Someone else's permit let a gun through") // CHECKPOINT_REJECTING
	settle()
	// A gun the holder carries is theirs; one left lying on the floor is not
	friend.forceMove(lobby)
	holder.forceMove(chamber[1])
	var/obj/item/gun/ballistic/automatic/pistol/dropped = allocate(/obj/item/gun/ballistic/automatic/pistol, chamber[2])
	TEST_ASSERT(scan_now(holder), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "A permit covered a gun left on the floor") // CHECKPOINT_REJECTING
	TEST_ASSERT_EQUAL(get_turf(dropped), lobby, "The loose gun was not put back out")
	settle()
	// Only at the outpost that issued it
	var/obj/structure/overmap/trader_outpost/elsewhere = allocate(/obj/structure/overmap/trader_outpost/black_market)
	TEST_ASSERT(!elsewhere.has_weapons_permit(holder), "A permit carried over to another outpost")
	// It runs out
	host.weapon_permits[holder.mind] = world.time - 1
	TEST_ASSERT(!host.has_weapons_permit(holder), "An expired permit still counted")
	TEST_ASSERT(host.has_weapons_permit(holder, 30 SECONDS), "The lapse grace did not apply") // OUTPOST_WEAPONS_PERMIT_GRACE
	TEST_ASSERT(scan_now(holder), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "An expired permit let a gun through") // CHECKPOINT_REJECTING

// ===== FORCING THE INNER DOOR =====

/// Prying starts a long, alarmed attempt; a breached door flags anyone who goes through it from the chamber
/datum/unit_test/voidcrew_trader_checkpoint/forced_entry/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	TEST_ASSERT(inner.outpost_forceable() && !outer.outpost_forceable(), "Only the inner door may be forced")
	var/mob/living/carbon/human/burglar = visitor(chamber[1])
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar, burglar)
	burglar.put_in_hands(crowbar)
	// The outpost property element lets the crowbar through to this door, and the attempt takes time
	INVOKE_ASYNC(crowbar, TYPE_PROC_REF(/obj/item, melee_attack_chain), burglar, inner, list())
	sleep(1 SECONDS)
	TEST_ASSERT(checkpoint.forcing, "Prying the inner door did not start forcing it")
	TEST_ASSERT(inner.density, "The inner door gave at once")
	// The outer door's crowbar is still stopped by outpost property
	crowbar.melee_attack_chain(burglar, outer, list())
	TEST_ASSERT(outer.density, "A crowbar opened the outer door")
	// Walking away stops the attempt
	burglar.forceMove(lobby)
	sleep(2 SECONDS)
	TEST_ASSERT(!checkpoint.forcing, "Walking away did not stop the attempt")
	TEST_ASSERT(inner.density, "An abandoned attempt opened the door")
	// When it gives, whoever goes through from the chamber is an armed trespasser; someone already inside is not
	var/mob/living/carbon/human/insider = visitor(secured)
	burglar.forceMove(chamber[1])
	checkpoint.breach(burglar)
	sleep(2 SECONDS)
	TEST_ASSERT(!inner.density, "A breach did not open the inner door")
	TEST_ASSERT(checkpoint.request_outer(visitor()), "The outer door stayed interlocked during a breach")
	burglar.Move(get_turf(inner), NORTH)
	TEST_ASSERT_EQUAL(get_turf(burglar), get_turf(inner), "Could not walk into the breached doorway")
	TEST_ASSERT(host.is_armed_trespasser(burglar.mind), "Going through a forced door was not flagged")
	TEST_ASSERT(host.is_user_barred(burglar), "Going through a forced door did not bar them")
	burglar.forceMove(secured)
	insider.Move(get_turf(inner), SOUTH)
	TEST_ASSERT(!host.is_armed_trespasser(insider.mind), "Stepping into the doorway from inside was flagged")
	checkpoint.end_breach()
	sleep(3 SECONDS)
	TEST_ASSERT(inner.density, "The forced door did not shut again")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The checkpoint did not settle after the breach") // CHECKPOINT_IDLE

// ===== ARMED TRESPASS =====

/// A gun drawn past the checkpoint flags its holder once it stays out; holstered, permitted or in the lobby it does not
/datum/unit_test/voidcrew_trader_checkpoint/drawn_gun/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(secured)
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack)
	person.equip_to_slot_or_del(bag, ITEM_SLOT_BACK)
	gun.forceMove(bag)
	host.armed_sweep(list(person))
	TEST_ASSERT(!length(host.armed_sightings), "A holstered gun was noticed")
	person.put_in_hands(gun)
	host.armed_sweep(list(person))
	TEST_ASSERT(!host.is_armed_trespasser(person.mind), "A gun was flagged the moment it came out")
	host.armed_sightings[person.mind] = world.time - 2 SECONDS // OUTPOST_ARMED_SIGHTING_GRACE
	host.armed_sweep(list(person))
	TEST_ASSERT(host.is_armed_trespasser(person.mind), "A gun kept out past the checkpoint was not flagged")
	var/obj/machinery/porta_turret/outpost/turret = allocate(/obj/machinery/porta_turret/outpost, secured)
	turret.outpost = host
	TEST_ASSERT(turret.valid_target(person), "The turrets ignore an armed trespasser")
	// The hostile window ends before the bar does
	host.armed_trespassers[person.mind] = world.time - 10 MINUTES - 1 // OUTPOST_TRESPASS_HOSTILE_DURATION
	TEST_ASSERT(!turret.valid_target(person), "The turrets kept shooting after the hostile window")
	TEST_ASSERT(host.is_user_barred(person), "The bar ended with the hostile window")
	host.trespass_bars[person.mind] = world.time - 1
	TEST_ASSERT(!host.is_user_barred(person), "The bar did not lift")
	// A permit holder, and anyone in the lobby, may carry openly
	var/mob/living/carbon/human/holder = visitor(secured)
	holder.put_in_hands(allocate(/obj/item/gun/ballistic/automatic/pistol))
	host.grant_weapons_permit(holder)
	var/mob/living/carbon/human/arrival = visitor(lobby)
	arrival.put_in_hands(allocate(/obj/item/gun/ballistic/automatic/pistol))
	host.armed_sightings[holder.mind] = world.time - 2 SECONDS
	host.armed_sightings[arrival.mind] = world.time - 2 SECONDS
	host.armed_sweep(list(holder, arrival))
	TEST_ASSERT(!host.is_armed_trespasser(holder.mind), "A permit holder was flagged for carrying")
	TEST_ASSERT(!host.is_armed_trespasser(arrival.mind), "Someone in the checkpoint lobby was flagged")

/// Firing a gun past the checkpoint without a permit flags the shooter at once
/datum/unit_test/voidcrew_trader_checkpoint/fired_gun/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/shooter = visitor(secured)
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	SEND_SIGNAL(shooter, COMSIG_MOB_FIRED_GUN, gun, lobby, null, null, list(0, 0))
	TEST_ASSERT(host.is_armed_trespasser(shooter.mind), "Firing past the checkpoint was not flagged")

/// The traders and the permit desk refuse an armed trespasser, and the desk sells them nothing
/datum/unit_test/voidcrew_trader_checkpoint/refused_service/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(get_step(guard, SOUTH))
	var/datum/shop_sku/weapons_permit/permit = locate() in guard.shop.skus
	TEST_ASSERT_NOTNULL(permit, "The guard does not sell permits")
	TEST_ASSERT_EQUAL(permit.price_credits, 1000, "The permit price changed") // OUTPOST_WEAPONS_PERMIT_PRICE
	TEST_ASSERT(permit.fixed_price && !permit.contract_reward, "The permit can be discounted or paid out by contracts")
	TEST_ASSERT(permit.can_trade(person, guard), "The permit desk would not serve an ordinary customer")
	host.flag_trespasser(person)
	TEST_ASSERT(host.is_user_barred(person), "An armed trespasser is not barred")
	TEST_ASSERT(!permit.can_trade(person, guard), "The permit desk would serve an armed trespasser")
	TEST_ASSERT(!permit.try_purchase(person, guard), "An armed trespasser bought a permit")
	TEST_ASSERT(!host.has_weapons_permit(person), "An armed trespasser got a permit")

// ===== SEALED GOODS AND THE EXIT GATE =====

/// A gun handed over past the checkpoint comes sealed; the seal opens outside the checkpoint
/datum/unit_test/voidcrew_trader_checkpoint/sealed_goods/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/buyer = visitor(secured)
	var/obj/item/gun/energy/laser/gun = allocate(/obj/item/gun/energy/laser, secured)
	var/obj/item/outpost_sealed_case/case = outpost_seal_goods(gun)
	TEST_ASSERT(istype(case), "A gun handed over past the checkpoint was not sealed")
	allocated += case
	TEST_ASSERT_EQUAL(gun.loc, case, "The gun is not in its case")
	buyer.put_in_hands(case)
	case.attack_self(buyer)
	TEST_ASSERT_EQUAL(gun.loc, case, "The seal broke past the checkpoint")
	var/obj/item/coin/coin = allocate(/obj/item/coin, secured)
	TEST_ASSERT_EQUAL(outpost_seal_goods(coin), coin, "Harmless goods were sealed")
	buyer.forceMove(lobby)
	case.attack_self(buyer)
	TEST_ASSERT(QDELETED(case), "The seal did not break in the lobby")
	TEST_ASSERT(gun in buyer.held_items, "The gun did not come out of the case")
	var/obj/item/gun/energy/laser/lobby_gun = allocate(/obj/item/gun/energy/laser, lobby)
	TEST_ASSERT_EQUAL(outpost_seal_goods(lobby_gun), lobby_gun, "Goods handed over in the lobby were sealed")
	// A cache crate's lid is sealed whatever it holds
	var/obj/structure/closet/crate/zone_loot/syndicate/trader/crate = allocate(/obj/structure/closet/crate/zone_loot/syndicate/trader, secured)
	outpost_seal_goods(crate)
	TEST_ASSERT(!crate.open(buyer), "A sealed crate opened past the checkpoint")
	crate.forceMove(lobby)
	TEST_ASSERT(crate.open(buyer), "A sealed crate did not open in the lobby")

/// The exit gate lets people and things out of the concourse and nothing back in
/datum/unit_test/voidcrew_trader_checkpoint/exit_gate/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/turf/origin = host.template_bottom_left
	// Open a second way between the floors at x = 0 and put a gate in it, pointing at the lobby
	var/turf/gate_turf = locate(origin.x, origin.y + 3, origin.z)
	for(var/dy in 2 to 4)
		var/turf/tile = locate(origin.x, origin.y + dy, origin.z)
		tile.ChangeTurf(/turf/open/indestructible)
	var/turf/inside = locate(origin.x, origin.y + 4, origin.z)
	var/turf/outside = locate(origin.x, origin.y + 2, origin.z)
	var/obj/structure/outpost_exit_gate/gate = allocate(/obj/structure/outpost_exit_gate, gate_turf)
	gate.setDir(SOUTH)
	var/mob/living/carbon/human/leaving = visitor(inside)
	TEST_ASSERT(leaving.Move(gate_turf, SOUTH), "The gate stopped someone leaving")
	sleep(0.5 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(leaving), outside, "The gate did not carry them through")
	var/mob/living/carbon/human/sneaking = visitor(outside)
	TEST_ASSERT(!sneaking.Move(gate_turf, NORTH), "The gate let someone in from the lobby side")
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol, outside)
	TEST_ASSERT(!gun.Move(gate_turf, NORTH), "The gate let a gun in from the lobby side")
	TEST_ASSERT(!gate.CanAStarPass(SOUTH, null), "Pathing goes in through the gate")
	TEST_ASSERT(gate.CanAStarPass(NORTH, null), "Pathing cannot go out through the gate")

/// Checkpoint lockers are free, lock to the first card swiped, one per card per outpost, and are free again once emptied
/datum/unit_test/voidcrew_trader_checkpoint/lockers/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	var/turf/origin = host.template_bottom_left
	var/obj/structure/closet/secure_closet/outpost_rental/checkpoint/first = allocate(/obj/structure/closet/secure_closet/outpost_rental/checkpoint, locate(origin.x, origin.y, origin.z))
	var/obj/structure/closet/secure_closet/outpost_rental/checkpoint/second = allocate(/obj/structure/closet/secure_closet/outpost_rental/checkpoint, locate(origin.x + 1, origin.y, origin.z))
	var/mob/living/carbon/human/owner = visitor(locate(origin.x, origin.y + 1, origin.z))
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.registered_name = "Locker owner"
	var/datum/bank_account/account = allocate(/datum/bank_account, "Locker owner", null, 1, FALSE)
	account.account_balance = 1000
	card.registered_account = account
	TEST_ASSERT(owner.put_in_active_hand(card), "The owner could not hold the card")
	TEST_ASSERT(!first.locked && isnull(first.id_card), "A checkpoint locker started out claimed")
	first.attackby(card, owner)
	TEST_ASSERT(first.locked && first.id_card?.resolve() == card, "Swiping did not lock the locker to the card")
	TEST_ASSERT_EQUAL(account.account_balance, 1000, "A checkpoint locker charged a fee")
	second.attackby(card, owner)
	TEST_ASSERT(isnull(second.id_card), "One card claimed two lockers at the same outpost")
	TEST_ASSERT(!first.emag_act(owner, null), "An emag broke a checkpoint locker")
	var/mob/living/carbon/human/stranger = visitor(locate(origin.x + 1, origin.y + 1, origin.z))
	TEST_ASSERT(stranger.put_in_active_hand(allocate(/obj/item/card/id)), "The stranger could not hold a card")
	first.togglelock(stranger)
	TEST_ASSERT(first.locked, "Someone else's card opened a claimed locker")
	first.togglelock(owner)
	TEST_ASSERT(!first.locked, "The owner's card did not open their locker")
	TEST_ASSERT(first.open(owner), "The owner could not open their locker")
	var/obj/item/coin/kept = allocate(/obj/item/coin, get_turf(first))
	TEST_ASSERT(first.close(owner), "The owner could not close their locker")
	TEST_ASSERT_EQUAL(kept.loc, first, "The locker did not take what was left in it")
	TEST_ASSERT(first.id_card?.resolve() == card, "A locker with something in it was freed")
	TEST_ASSERT(first.open(owner), "The owner could not reopen their locker")
	kept.forceMove(get_step(first, NORTH))
	TEST_ASSERT(first.close(owner), "The owner could not close the emptied locker")
	TEST_ASSERT(isnull(first.id_card) && !first.locked, "An emptied locker stayed claimed")
	second.attackby(card, owner)
	TEST_ASSERT(second.id_card?.resolve() == card, "A freed card could not claim another locker")

/// The lobby checkpoints are a way in only (the exit gate is the way out); an exterior hatch cycles both ways
/datum/unit_test/voidcrew_trader_checkpoint/directions/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/insider = visitor(secured)
	TEST_ASSERT(!checkpoint.request_cycle(insider), "A guarded checkpoint cycled outward for someone inside")
	var/datum/can_pass_info/walker = new(null, list())
	TEST_ASSERT(!inner.CanAStarPass(get_dir(inner, secured), walker), "Pathing goes out through a guarded checkpoint's inner door")
	TEST_ASSERT(inner.CanAStarPass(get_dir(inner, chamber[1]), walker), "Pathing cannot come in through a guarded checkpoint's inner door")
	// Without a guard (an exterior hatch) the chamber cycles outward for someone inside
	qdel(guard)
	guard = null
	TEST_ASSERT_NULL(checkpoint.guard, "The checkpoint kept a deleted guard")
	TEST_ASSERT(scan_now(insider), "An exterior hatch would not cycle outward")
	TEST_ASSERT_EQUAL(checkpoint.state, "passing", "An empty chamber did not open for someone leaving") // CHECKPOINT_PASSING
	sleep(2 SECONDS)
	TEST_ASSERT(!inner.density, "The inner door did not open for someone leaving")
	TEST_ASSERT(inner.CanAStarPass(get_dir(inner, secured), walker), "Pathing cannot leave through an exterior hatch")
