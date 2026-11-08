/**
 * Pirate crew AI (voidcrew/modules/npc_ships/code/pirate_crew.dm, pirate_crew_ai.dm and
 * pirate_crew_human.dm): which doors a pirate walks through, which it may break, the search for the
 * door in the way, and how a hull's crew and a raid are put together. NPC ship crews are human NPCs
 * (faction_pirate_humans.dm), so most of these use them; voidcrew_pirate_crew_human.dm tests what they
 * do with their hands.
 *
 * Fork defines are included after the tests, so roles and blackboard keys appear as their
 * literal strings ("captain" is PIRATE_ROLE_CAPTAIN, "pirate_crew" is BB_PIRATE_CREW). Every
 * test calls the procs directly; none waits on a timer or an AI walk.
 */

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_pirate_crew
	abstract_type = /datum/unit_test/voidcrew_pirate_crew
	/// Turfs a test changed, put back to plain floor when it ends
	var/list/turf/changed_turfs = list()

/datum/unit_test/voidcrew_pirate_crew/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	restore_atmos()
	return ..()

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner (the room is 5x5)
/datum/unit_test/voidcrew_pirate_crew/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Changes `where` to `new_type`, to be put back when the test ends
/datum/unit_test/voidcrew_pirate_crew/proc/change_turf(turf/where, new_type)
	changed_turfs |= where
	return where.ChangeTurf(new_type)

/// Builds a human NPC now at `where`, dressed in `outfit` if given (an outfit or an outfit table)
/datum/unit_test/voidcrew_pirate_crew/proc/build_npc(npc_type, turf/where, outfit)
	var/datum/human_npc_order/order = spawn_human_npc(npc_type, where || run_loc_floor_bottom_left, outfit = outfit, immediate = TRUE)
	var/mob/living/carbon/human/npc/npc = order?.spawned_ref?.resolve()
	if(npc)
		allocated += npc
	return npc

// ===== WHICH DOORS OPEN =====

/// An unlocked airlock opens for a pirate; a bolted, welded, unpowered or access-locked one does not
/datum/unit_test/voidcrew_pirate_crew/door_rules

/datum/unit_test/voidcrew_pirate_crew/door_rules/Run()
	var/mob/living/carbon/human/npc/faction_pirate/grey/melee/pirate = build_npc(/mob/living/carbon/human/npc/faction_pirate/grey/melee, spot(0, 0))
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, spot(2, 2))
	TEST_ASSERT(door.density, "The test airlock spawned open")
	TEST_ASSERT(pirate_can_open_door(pirate, door), "A pirate can't open an unlocked, powered airlock")

	door.locked = TRUE
	TEST_ASSERT(!pirate_can_open_door(pirate, door), "A pirate can open a bolted airlock")
	door.locked = FALSE

	door.welded = TRUE
	TEST_ASSERT(!pirate_can_open_door(pirate, door), "A pirate can open a welded airlock")
	door.welded = FALSE

	var/old_stat = door.machine_stat
	door.set_machine_stat(old_stat | NOPOWER)
	TEST_ASSERT(!pirate_can_open_door(pirate, door), "A pirate can open an unpowered airlock")
	door.set_machine_stat(old_stat)
	TEST_ASSERT(pirate_can_open_door(pirate, door), "Restoring power didn't make the airlock openable again")

	// The pirate's ID card carries its name and no access
	door.req_access = list(ACCESS_ENGINEERING)
	TEST_ASSERT(!pirate_can_open_door(pirate, door), "A pirate's ID card opens an access-locked airlock")
	door.req_access = null

/// Breaking an external airlock with space beyond it is off limits; an inner door or an indestructible one depends
/datum/unit_test/voidcrew_pirate_crew/never_smash

/datum/unit_test/voidcrew_pirate_crew/never_smash/Run()
	change_turf(spot(4, 4), /turf/open/space)
	var/obj/machinery/door/airlock/external/hatch = allocate(/obj/machinery/door/airlock/external, spot(4, 3))
	TEST_ASSERT(!pirate_door_breachable(hatch, spot(4, 2)), "A pirate may break an external airlock that opens onto space")
	var/obj/machinery/door/airlock/instant/inner = allocate(/obj/machinery/door/airlock/instant, spot(0, 3))
	TEST_ASSERT(pirate_door_breachable(inner, spot(0, 2)), "A pirate may not break an ordinary inner airlock")
	inner.resistance_flags |= INDESTRUCTIBLE
	TEST_ASSERT(!pirate_door_breachable(inner, spot(0, 2)), "A pirate may break an indestructible airlock")
	inner.resistance_flags &= ~INDESTRUCTIBLE
	inner.open()
	TEST_ASSERT(!pirate_door_breachable(inner, spot(0, 2)), "A pirate may break an airlock that is already open")

	// A firelock holding back a room that lost its air is never forced either
	var/obj/machinery/door/firedoor/firelock = allocate(/obj/machinery/door/firedoor, spot(4, 3))
	TEST_ASSERT(pirate_door_vents_space(firelock, spot(4, 2)), "A pirate may force a firelock with vacuum behind it")
	var/obj/machinery/door/firedoor/inner_firelock = allocate(/obj/machinery/door/firedoor, spot(1, 3))
	TEST_ASSERT(!pirate_door_vents_space(inner_firelock, spot(1, 2)), "A firelock with air on both sides counts as venting")

// ===== THE DOOR IN THE WAY =====

/// Two rooms joined only by a bolted airlock: the search finds that airlock and the floor to break it from
/datum/unit_test/voidcrew_pirate_crew/breach_search

/datum/unit_test/voidcrew_pirate_crew/breach_search/Run()
	var/mob/living/carbon/human/npc/faction_pirate/grey/melee/pirate = build_npc(/mob/living/carbon/human/npc/faction_pirate/grey/melee, spot(0, 2))
	for(var/dy in list(0, 1, 3, 4))
		change_turf(spot(2, dy), /turf/closed/wall)
	var/obj/machinery/door/airlock/instant/door = allocate(/obj/machinery/door/airlock/instant, spot(2, 2))
	var/list/areas = list()
	areas[get_area(spot(0, 2))] = TRUE

	door.locked = TRUE
	var/list/result = pirate_crew_breach_search(pirate, spot(0, 2), spot(4, 2), areas)
	TEST_ASSERT_NOTNULL(result, "The search found no way through a bolted airlock")
	TEST_ASSERT_EQUAL(result["door"], door, "The search didn't name the bolted airlock as the door to break")
	TEST_ASSERT_EQUAL(result["stand"], spot(1, 2), "The search didn't say to break the airlock from the floor in front of it")

	door.locked = FALSE
	result = pirate_crew_breach_search(pirate, spot(0, 2), spot(4, 2), areas)
	TEST_ASSERT_NOTNULL(result, "The search found no way through an unlocked airlock")
	TEST_ASSERT_NULL(result["door"], "The search wants to break an airlock that would open")

	door.open()
	result = pirate_crew_breach_search(pirate, spot(0, 2), spot(4, 2), areas)
	TEST_ASSERT_NOTNULL(result, "The search found no way through an open airlock")
	TEST_ASSERT_NULL(result["door"], "The search wants to break an open airlock")

	// A grille is never broken, so with one in the gap there is no way through at all
	qdel(door)
	allocate(/obj/structure/grille, spot(2, 2))
	TEST_ASSERT_NULL(pirate_crew_breach_search(pirate, spot(0, 2), spot(4, 2), areas), "The search found a way through a grille")

	// And it stays inside the areas it was given
	TEST_ASSERT_NULL(pirate_crew_breach_search(pirate, spot(0, 2), spot(1, 2), list()), "The search ran with no areas to search")

// ===== CREWS =====

/// A hull's crew has one captain and one guard, a melee guard when there is one, and alerting it wakes
/// everyone; the captain and guard join the hunt once the rest are out of the fight (dead, down or cuffed)
/datum/unit_test/voidcrew_pirate_crew/defending_roles

/datum/unit_test/voidcrew_pirate_crew/defending_roles/Run()
	var/obj/structure/overmap/ship/npc/pirate/hull = allocate(/obj/structure/overmap/ship/npc/pirate)
	var/mob/living/carbon/human/npc/faction_pirate/silverscale/captain/captain = build_npc(/mob/living/carbon/human/npc/faction_pirate/silverscale/captain, spot(0, 0))
	var/mob/living/carbon/human/npc/faction_pirate/silverscale/ranged/gunner = build_npc(/mob/living/carbon/human/npc/faction_pirate/silverscale/ranged, spot(1, 0))
	var/mob/living/carbon/human/npc/faction_pirate/silverscale/melee/brawler = build_npc(/mob/living/carbon/human/npc/faction_pirate/silverscale/melee, spot(2, 0))
	var/mob/living/carbon/human/npc/faction_pirate/silverscale/melee/deckhand = build_npc(/mob/living/carbon/human/npc/faction_pirate/silverscale/melee, spot(3, 0))
	TEST_ASSERT(pirate_crew_is_ranged(gunner), "A marksman holding a gun doesn't count as a gunner")
	TEST_ASSERT(!pirate_crew_is_ranged(brawler), "A duelist counts as a gunner")

	TEST_ASSERT(pirate_crew_enlist_defender(captain, hull, "captain"), "The captain could not join the hull's crew")
	// The gunner joins first and takes the guard post; the first melee recruit takes it off him
	TEST_ASSERT(pirate_crew_enlist_defender(gunner, hull), "A gunner could not join the hull's crew")
	TEST_ASSERT(pirate_crew_enlist_defender(brawler, hull), "A brawler could not join the hull's crew")
	TEST_ASSERT(pirate_crew_enlist_defender(deckhand, hull), "A deckhand could not join the hull's crew")

	var/datum/pirate_crew/crew = pirate_crew_of(hull)
	TEST_ASSERT_NOTNULL(crew, "Enlisting made no crew for the hull")
	TEST_ASSERT(!crew.raiding, "A hull's own crew was made as a raid")
	TEST_ASSERT_EQUAL(length(crew.members), 4, "The crew doesn't have all four pirates")
	var/captains = 0
	var/guards = 0
	for(var/mob/living/member in crew.members)
		switch(crew.members[member])
			if("captain")
				captains++
			if("guard")
				guards++
		TEST_ASSERT_EQUAL(member.ai_controller?.blackboard["pirate_crew"], crew, "[member] doesn't know its crew")
		TEST_ASSERT_EQUAL(member.ai_controller?.type, /datum/ai_controller/basic_controller/pirate_crew/human, "[member] isn't on the human pirate crew controller")
		TEST_ASSERT_EQUAL(member.ai_controller?.blackboard[BB_TARGET_MINIMUM_STAT], HARD_CRIT, "[member] stops shooting people in crit")
	TEST_ASSERT_EQUAL(captains, 1, "The crew has [captains] captains")
	TEST_ASSERT_EQUAL(guards, 1, "The crew has [guards] guards")
	TEST_ASSERT_EQUAL(crew.members[captain], "captain", "The pirate enlisted as captain isn't the captain")
	TEST_ASSERT_EQUAL(crew.members[brawler], "guard", "The first melee pirate didn't take the guard post from the gunner")
	TEST_ASSERT_EQUAL(crew.members[gunner], "hunter", "The gunner kept the guard post")
	TEST_ASSERT_EQUAL(crew.starting_crew, 3, "The crew counts [crew.starting_crew] pirates besides the captain")
	// The hull has no helm here, so the captain holds where it stands
	TEST_ASSERT_EQUAL(crew.post_turf, spot(0, 0), "The captain's post isn't where the captain stood")
	TEST_ASSERT(crew.holds_post(captain) && crew.holds_post(brawler), "The captain and the guard don't hold the post")
	TEST_ASSERT(!crew.holds_post(gunner), "A hunter holds the post")

	TEST_ASSERT(!crew.alerted, "A fresh hull crew starts on alert")
	crew.raise_alert()
	TEST_ASSERT(crew.alerted, "Raising the alert didn't alert the crew")
	for(var/mob/living/member in crew.members)
		TEST_ASSERT(!member.ai_controller.can_idle, "[member] can still idle on alert")

	// The guard down and the deckhand cuffed: only the gunner is still fighting, so the captain joins in
	brawler.adjustOxyLoss(110)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(deckhand.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED), "Test fixture: the deckhand could not be cuffed")
	crew.check_promotion()
	TEST_ASSERT(crew.promoted, "The captain didn't join the hunt with only one of his crew still fighting")
	TEST_ASSERT(!crew.holds_post(captain), "The captain still holds the post once his crew is beaten")

	qdel(crew)
	TEST_ASSERT_NULL(pirate_crew_of(hull), "A deleted crew is still registered to its hull")
	TEST_ASSERT_NULL(captain.ai_controller.blackboard["pirate_crew"], "The captain still points at a deleted crew")

/// A boarder joins the raid on the ship it landed on; a human pirate gets the human controller, and a
/// basic trooper still gets the melee controller, a ranged trooper the ranged one
/datum/unit_test/voidcrew_pirate_crew/raid_controllers

/datum/unit_test/voidcrew_pirate_crew/raid_controllers/Run()
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	var/mob/living/basic/trooper/trooper = allocate(/mob/living/basic/trooper, spot(0, 0))
	var/mob/living/basic/trooper/pirate/ranged/basic_gunner = allocate(/mob/living/basic/trooper/pirate/ranged, spot(1, 0))
	var/mob/living/carbon/human/npc/faction_pirate/irs/ranged/boarder = build_npc(/mob/living/carbon/human/npc/faction_pirate/irs/ranged, spot(2, 0))
	TEST_ASSERT_EQUAL(pirate_crew_controller_type(trooper), /datum/ai_controller/basic_controller/pirate_crew, "A melee trooper is down for the wrong controller")
	TEST_ASSERT_EQUAL(pirate_crew_controller_type(basic_gunner), /datum/ai_controller/basic_controller/pirate_crew/ranged, "A ranged trooper is down for the wrong controller")
	TEST_ASSERT_EQUAL(pirate_crew_controller_type(boarder), /datum/ai_controller/basic_controller/pirate_crew/human, "A human pirate is down for the wrong controller")

	TEST_ASSERT(pirate_crew_enlist_raider(trooper, target), "A trooper could not join the raid")
	TEST_ASSERT(pirate_crew_enlist_raider(basic_gunner, target), "A basic gunner could not join the raid")
	TEST_ASSERT(pirate_crew_enlist_raider(boarder, target), "A human boarder could not join the raid")
	TEST_ASSERT_EQUAL(trooper.ai_controller?.type, /datum/ai_controller/basic_controller/pirate_crew, "The trooper didn't get the pirate crew controller")
	TEST_ASSERT_EQUAL(basic_gunner.ai_controller?.type, /datum/ai_controller/basic_controller/pirate_crew/ranged, "The basic gunner didn't get the ranged pirate crew controller")
	TEST_ASSERT_EQUAL(boarder.ai_controller?.type, /datum/ai_controller/basic_controller/pirate_crew/human, "The human boarder lost its human controller")

	var/datum/pirate_crew/raid = pirate_crew_of(target, TRUE)
	TEST_ASSERT_NOTNULL(raid, "Enlisting made no raid on the ship")
	TEST_ASSERT_NULL(pirate_crew_of(target), "A raid registered itself as the ship's own crew")
	TEST_ASSERT(raid.raiding && raid.alerted, "A raid isn't on the attack from the start")
	TEST_ASSERT_EQUAL(raid.members[boarder], "hunter", "A boarder isn't a hunter")
	TEST_ASSERT(!raid.holds_post(boarder), "A boarder holds a post")
	TEST_ASSERT(!trooper.ai_controller.can_idle && !boarder.ai_controller.can_idle, "Boarders can idle")
	qdel(raid)

// ===== LOOKS =====

/// A gunner's look keeps the gun in its hand; a body dressed by the same kind of spawner still gets no free gun
/datum/unit_test/voidcrew_pirate_crew/held_gun_look

/datum/unit_test/voidcrew_pirate_crew/held_gun_look/Run()
	// equip() turns a spawner's outfit path into an instance, so each body needs its own spawner
	var/obj/effect/mob_spawn/corpse/human/pirate/faction/grey/ranged/look_spawner = new(null, TRUE)
	look_spawner.outfit_override = list("r_hand" = /obj/item/gun/energy/laser)
	var/mob/living/carbon/human/dummy/consistent/dummy = allocate(/mob/living/carbon/human/dummy/consistent)
	look_spawner.equip(dummy)
	TEST_ASSERT(locate(/obj/item/gun/energy/laser) in dummy.held_items, "An NPC's appearance dummy lost the gun its spawner put in its hand")
	qdel(look_spawner)

	var/obj/effect/mob_spawn/corpse/human/pirate/faction/grey/ranged/body_spawner = new(null, TRUE)
	body_spawner.outfit_override = list("r_hand" = /obj/item/gun/energy/laser)
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body_spawner.equip(body)
	TEST_ASSERT(!(locate(/obj/item/gun/energy/laser) in body.get_all_contents()), "A spawner left a free gun on a real body")
	qdel(body_spawner)

// ===== MINERAL DOORS =====

/// Iron and wooden doors only open for players. A pirate crew's paths still go through them shut, the breach search walks through them, and nobody else's paths do.
/datum/unit_test/voidcrew_pirate_crew/mineral_doors

/datum/unit_test/voidcrew_pirate_crew/mineral_doors/Run()
	var/mob/living/carbon/human/npc/faction_pirate/grey/melee/pirate = build_npc(/mob/living/carbon/human/npc/faction_pirate/grey/melee, spot(0, 2))
	var/mob/living/basic/trooper/pirate/melee/bystander = allocate(/mob/living/basic/trooper/pirate/melee, spot(4, 2))
	var/obj/structure/overmap/ship/target = allocate(/obj/structure/overmap/ship)
	TEST_ASSERT(pirate_crew_enlist_raider(pirate, target), "A pirate could not join the raid")
	for(var/dy in list(0, 1, 3, 4))
		change_turf(spot(2, dy), /turf/closed/wall)
	var/obj/structure/mineral_door/iron/slab = allocate(/obj/structure/mineral_door/iron, spot(2, 2))
	var/list/areas = list()
	areas[get_area(spot(0, 2))] = TRUE

	TEST_ASSERT(pirate_can_open_mineral_door(slab), "A pirate can't push a shut iron door open")
	TEST_ASSERT(slab.CanAStarPass(EAST, new /datum/can_pass_info(pirate, list())), "A pirate crew's path can't go through a shut iron door")
	TEST_ASSERT(!slab.CanAStarPass(WEST, new /datum/can_pass_info(bystander, list())), "Any NPC's path now goes through a shut iron door")

	var/list/result = pirate_crew_breach_search(pirate, spot(0, 2), spot(4, 2), areas)
	TEST_ASSERT_NOTNULL(result, "The search found no way through a shut iron door")
	TEST_ASSERT_NULL(result["door"], "The search wants to break an iron door the pirate can push open")

	// A loose one can't be opened, so it's just a slab in the way
	slab.set_anchored(FALSE)
	TEST_ASSERT(!pirate_can_open_mineral_door(slab), "A pirate tries to open a loose iron door")
	TEST_ASSERT_NULL(pirate_crew_breach_search(pirate, spot(0, 2), spot(4, 2), areas), "The search found a way through a loose iron door")
	qdel(pirate_crew_of(target, TRUE))
