// Owner: P11. Bounty lair tests.

/**
 * # Club Volga, the mafia club lair (P11)
 *
 * Loads the template on a reserved block, the way the overmap's ruin placer does (per-load area instances),
 * and checks what the lair framework (P10) and the mobs (P12) rely on: the boss and gatekeeper landmarks,
 * the closed garage door, one mafia marker per room, the single cache, and that the garage can only be
 * reached through its door.
 *
 * Unit tests compile before voidcrew/_DEFINES; nothing here needs one.
 */
/datum/unit_test/voidcrew_bounty_lair_maps
	/// The block the club is loaded into
	var/datum/turf_reservation/reserve

/datum/unit_test/voidcrew_bounty_lair_maps/Destroy()
	QDEL_NULL(reserve)
	return ..()

/datum/unit_test/voidcrew_bounty_lair_maps/Run()
	var/datum/map_template/ruin/space/template
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[template_name]
		if(candidate.type == /datum/map_template/ruin/space/bounty_lair/mafia_club)
			template = candidate
			break
	TEST_ASSERT_NOTNULL(template, "The mafia club template is not registered in SSmapping.space_ruins_templates")
	TEST_ASSERT(template.unpickable, "The mafia club must be unpickable: only a bounty posting surfaces it")
	TEST_ASSERT(SSovermap.ruin_fits_in_slot(template), "The mafia club ([template.width]x[template.height]) no longer fits a lattice slot")

	reserve = SSmapping.request_turf_block_reservation(template.width + 4, template.height + 4, 1)
	TEST_ASSERT_NOTNULL(reserve, "Could not reserve a block for the mafia club")
	var/turf/corner = reserve.bottom_left_turfs[1]
	var/turf/origin = locate(corner.x + 2, corner.y + 2, corner.z)
	planet_ruin_area_instancing_begin(origin.z)
	var/loaded = template.load(origin)
	planet_ruin_area_instancing_end(origin.z)
	TEST_ASSERT(loaded, "The mafia club did not load")

	// Every club turf, and the atoms the lair's code looks for, gathered in one sweep straight after the
	// load (the zone_mobs markers resolve and delete themselves on a timer).
	var/list/club_turfs = list()
	var/list/obj/effect/landmark/bounty_lair_boss/bosses = list()
	var/list/obj/effect/landmark/bounty_lair_gatekeeper/gatekeepers = list()
	var/list/obj/machinery/door/poddoor/gates = list()
	var/list/obj/effect/zone_mobs/markers = list()
	var/list/obj/structure/closet/crate/zone_loot/caches = list()
	var/list/turf/entrances = list()
	for(var/turf/tile as anything in block(origin, locate(origin.x + template.width - 1, origin.y + template.height - 1, origin.z)))
		if(!istype(tile.loc, /area/ruin/space/has_grav/powered/mafia_club))
			continue
		club_turfs[tile] = TRUE
		for(var/atom/movable/thing as anything in tile)
			if(istype(thing, /obj/effect/landmark/bounty_lair_boss))
				bosses += thing
			else if(istype(thing, /obj/effect/landmark/bounty_lair_gatekeeper))
				gatekeepers += thing
			else if(istype(thing, /obj/machinery/door/poddoor))
				gates += thing
			else if(istype(thing, /obj/effect/zone_mobs))
				markers += thing
			else if(istype(thing, /obj/structure/closet/crate/zone_loot))
				caches += thing
			else if(istype(thing, /obj/machinery/door/airlock/external))
				entrances |= tile
			else if(istype(thing, /obj/machinery/computer/slot_machine))
				TEST_FAIL("A slot machine at ([tile.x],[tile.y]): slot machines pay out on an EMP, and the club must hold none")
	TEST_ASSERT(length(club_turfs), "The club loaded no turfs in its own areas")

	// The club's areas: per-load instances, no teleporting in or out
	for(var/turf/tile as anything in club_turfs)
		var/area/room = tile.loc
		if(!(room.area_flags & NOTELEPORT))
			TEST_FAIL("[room.type] at ([tile.x],[tile.y]) allows teleporting, which skips the rooms or lands in the garage")
			break

	// The boss: one landmark, set to the don's mech, in the garage
	TEST_ASSERT_EQUAL(length(bosses), 1, "The club should hold one boss landmark")
	var/obj/effect/landmark/bounty_lair_boss/boss = bosses[1]
	TEST_ASSERT_EQUAL(boss.boss_type, /mob/living/basic/bounty_lair_boss/mafia_mech, "The boss landmark is not set to the don's mech")
	TEST_ASSERT(istype(get_area(boss), /area/ruin/space/has_grav/powered/mafia_club/garage), "The boss landmark is not in the garage")

	// The gatekeepers: two lieutenants, outside the garage
	TEST_ASSERT_EQUAL(length(gatekeepers), 2, "The club should hold two gatekeeper landmarks")
	for(var/obj/effect/landmark/bounty_lair_gatekeeper/keeper as anything in gatekeepers)
		TEST_ASSERT_EQUAL(keeper.gatekeeper_type, /mob/living/basic/trooper/russian/mafia/lieutenant, "A gatekeeper landmark is not set to the lieutenant")
		TEST_ASSERT(istype(get_area(keeper), /area/ruin/space/has_grav/powered/mafia_club/back_office), "A gatekeeper landmark is not in the back office, in front of the garage door")

	// The garage door: three closed, indestructible blast doors, the club's only poddoors
	TEST_ASSERT_EQUAL(length(gates), 3, "The club should hold exactly three poddoors, the garage door")
	for(var/obj/machinery/door/poddoor/gate as anything in gates)
		TEST_ASSERT_EQUAL(gate.id, "bounty_lair_gate", "A poddoor in the club is not part of the garage door")
		TEST_ASSERT(gate.density, "The garage door starts open")
		TEST_ASSERT(gate.resistance_flags & INDESTRUCTIBLE, "The garage door can be broken down")

	// Walls that can't be cut through, and a garage floor nothing can breach
	for(var/turf/tile as anything in club_turfs)
		if(isclosedturf(tile))
			if(!istype(tile, /turf/closed/indestructible))
				TEST_FAIL("The wall at ([tile.x],[tile.y]) can be broken, which skips rooms or opens the club to space")
			continue
		if(istype(tile.loc, /area/ruin/space/has_grav/powered/mafia_club/garage))
			if(!istype(tile, /turf/open/indestructible))
				TEST_FAIL("The garage floor at ([tile.x],[tile.y]) is breakable")
			for(var/obj/thing in tile)
				if(thing.density)
					TEST_FAIL("[thing] ([thing.type]) at ([tile.x],[tile.y]) is dense: the garage holds nothing the don's rockets can break")

	// Sealed: no open floor without a door on it touches anything outside the club
	for(var/turf/tile as anything in club_turfs)
		if(isclosedturf(tile) || (locate(/obj/machinery/door) in tile))
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(tile, direction)
			if(!isclosedturf(beside) && !club_turfs[beside])
				TEST_FAIL("The club floor at ([tile.x],[tile.y]) is open to ([beside.x],[beside.y]) outside the hull")

	// One mafia marker per goon room, none in the garage or the staff room, and none close enough to a wall
	// to scatter its goons into the next room
	TEST_ASSERT_EQUAL(length(markers), 8, "The club should hold one mafia marker in each of its eight goon rooms")
	var/list/marked_rooms = list()
	for(var/obj/effect/zone_mobs/marker as anything in markers)
		TEST_ASSERT_EQUAL(marker.type, /obj/effect/zone_mobs/mafia, "The club holds a [marker.type] marker; its goons are all the mafia's")
		var/area/room = get_area(marker)
		TEST_ASSERT(!istype(room, /area/ruin/space/has_grav/powered/mafia_club/garage) && !istype(room, /area/ruin/space/has_grav/powered/mafia_club/staff), \
			"A mafia marker is in [room.type], which must never hold goons")
		TEST_ASSERT(!marked_rooms[room.type], "Two mafia markers share [room.type]")
		marked_rooms[room.type] = TRUE
		for(var/turf/open/spot in RANGE_TURFS(2, marker))
			if(spot.loc != room)
				TEST_FAIL("The mafia marker at ([marker.x],[marker.y]) can scatter goons into [spot.loc.type] at ([spot.x],[spot.y])")

	// The loot: one cache, in the counting room's vault
	TEST_ASSERT_EQUAL(length(caches), 1, "The club should hold one loot cache")
	TEST_ASSERT(istype(get_area(caches[1]), /area/ruin/space/has_grav/powered/mafia_club/counting), "The loot cache is not in the counting room's vault")

	// The staff room: two rechargers, first aid, and a bolt button for its own door
	var/rechargers = 0
	var/medkits = 0
	var/obj/machinery/button/door/bolts
	for(var/turf/tile as anything in club_turfs)
		if(!istype(tile.loc, /area/ruin/space/has_grav/powered/mafia_club/staff))
			continue
		for(var/obj/machinery/recharger/charger in tile)
			rechargers++
		for(var/obj/structure/closet/locker in tile)
			for(var/obj/item/storage/medkit/kit in locker)
				medkits++
		bolts = bolts || (locate(/obj/machinery/button/door) in tile)
	TEST_ASSERT_EQUAL(rechargers, 2, "The staff room should have two rechargers")
	TEST_ASSERT(medkits >= 2, "The staff room's first aid locker holds [medkits] medkits")
	TEST_ASSERT_NOTNULL(bolts, "The staff room has no bolt button")
	var/obj/machinery/door/airlock/staff_door
	for(var/turf/tile as anything in club_turfs)
		for(var/obj/machinery/door/airlock/door in tile)
			if(door.id_tag == bolts.id)
				staff_door = door
	TEST_ASSERT(staff_door && istype(get_area(staff_door), /area/ruin/space/has_grav/powered/mafia_club/staff), "The staff room's bolt button does not work its own door")

	// The garage is reached only through its door: with the door shut, the walk from the airlock reaches
	// every other room, both gatekeepers and every marker, but not the boss; with it open, it reaches him.
	TEST_ASSERT(length(entrances), "The club has no external airlock to walk in from")
	var/list/shut = club_walk(entrances, club_turfs, gates_open = FALSE)
	TEST_ASSERT(!shut[get_turf(boss)], "The don's mech can be reached with the garage door shut")
	for(var/turf/tile as anything in club_turfs)
		if(shut[tile] && istype(tile.loc, /area/ruin/space/has_grav/powered/mafia_club/garage))
			TEST_FAIL("The garage floor at ([tile.x],[tile.y]) can be reached with the garage door shut")
			break
	for(var/obj/effect/landmark/bounty_lair_gatekeeper/keeper as anything in gatekeepers)
		TEST_ASSERT(shut[get_turf(keeper)], "A gatekeeper at ([keeper.x],[keeper.y]) can't be reached from the airlock")
	for(var/obj/effect/zone_mobs/marker as anything in markers)
		TEST_ASSERT(shut[get_turf(marker)], "The mafia marker at ([marker.x],[marker.y]) can't be reached from the airlock")
	TEST_ASSERT(shut[get_turf(caches[1])], "The loot cache can't be reached from the airlock")
	TEST_ASSERT(shut[get_turf(staff_door)], "The staff room can't be reached from the airlock")
	var/list/open = club_walk(entrances, club_turfs, gates_open = TRUE)
	TEST_ASSERT(open[get_turf(boss)], "The don's mech can't be reached even with the garage door open")

/**
 * Every club turf a crew can walk to from `starts`: closed turfs and windows block, doors don't (they open),
 * and the garage door blocks unless `gates_open`. Furniture doesn't block: this asks what is sealed off,
 * and the map linter covers what furniture hems in.
 */
/datum/unit_test/voidcrew_bounty_lair_maps/proc/club_walk(list/turf/starts, list/club_turfs, gates_open)
	var/list/reached = list()
	var/list/queue = list()
	for(var/turf/start as anything in starts)
		reached[start] = TRUE
		queue += start
	while(length(queue))
		var/turf/here = queue[length(queue)]
		queue.len--
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(here, direction)
			if(!next || reached[next] || !club_turfs[next] || isclosedturf(next))
				continue
			if(!gates_open && (locate(/obj/machinery/door/poddoor) in next))
				continue
			if(locate(/obj/structure/window) in next)
				continue
			reached[next] = TRUE
			queue += next
	return reached
