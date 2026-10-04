/**
 * World population: tests for the P0 core in voidcrew/modules/ambient_npcs/ (ambient_npc.dm,
 * ambient_activity.dm, ambient_subsystem.dm) and its hooks in planet_mobs.dm.
 *
 * Owner: P0 seams. Fork defines are included after the tests, so a test uses the literal value
 * with a comment naming the define. The tests drive the subsystem, the places and the activities
 * by hand: nothing here needs a client, a real outpost map or a real planet.
 */

/// A plain ambient NPC for the core tests, who only stands about
/mob/living/basic/ambient_npc/core_test
	routine = list(/datum/ambient_activity/idle = 1)

/// One with something to drop besides their cash
/mob/living/basic/ambient_npc/core_test/killable
	death_loot = list(/obj/item/pickaxe)

/// One who only ever sits down
/mob/living/basic/ambient_npc/core_test/sitter
	routine = list(/datum/ambient_activity/sit = 1)

/// One whose only routine is leaving: settle_in() must never settle them into it
/mob/living/basic/ambient_npc/core_test/leaver
	routine = list(/datum/ambient_activity/leave = 1)

/// A site kind the tests hand to the subsystem. No planet types and no npc_type, so the shared instance never rolls or spawns.
/datum/ambient_site_kind/core_test
	name = "core test camp"
	min_npcs = 2
	max_npcs = 2
	spot_room = 0

/// Any free test-room tile nobody took, ignoring the spacing a real planet needs
/datum/ambient_site_kind/core_test/find_spot(datum/ambient_planet/record, list/taken)
	var/list/bounds = record.bounds
	for(var/turf/tile as anything in block(locate(bounds[1], bounds[2], bounds[5]), locate(bounds[3], bounds[4], bounds[5])))
		if(!(tile in taken))
			return tile
	return null

/// An outpost role the tests hand to the subsystem. No npc_type, so the shared instance never arrives.
/datum/ambient_outpost_role/core_test
	name = "core test visitor"
	max_count = 3
	gap_low = 0
	gap_high = 0

/// The test room as a place: its bounds, list(min x, min y, max x, max y, z)
/datum/unit_test/proc/ambient_test_room_bounds()
	return list(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y, run_loc_floor_top_right.x, run_loc_floor_top_right.y, run_loc_floor_bottom_left.z)

/// A trader outpost whose concourse is the test room, with its hangar lift in the top right corner
/datum/unit_test/proc/ambient_test_outpost()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = run_loc_floor_top_right.x - run_loc_floor_bottom_left.x + 1
	outpost.outpost_template.height = run_loc_floor_top_right.y - run_loc_floor_bottom_left.y + 1
	outpost.template_bottom_left = run_loc_floor_bottom_left
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	return outpost

// =========================================================================
// THE BASE NPC
// =========================================================================

/// Nobody drags, boxes, teleports or polymorphs an ambient NPC; they can be hurt; an outpost's turrets count its people as their own; a killed one drops its cash and loot once
/datum/unit_test/voidcrew_ambient_npc_protections

/datum/unit_test/voidcrew_ambient_npc_protections/Run()
	var/mob/living/basic/ambient_npc/core_test/npc = allocate(/mob/living/basic/ambient_npc/core_test, run_loc_floor_bottom_left)
	TEST_ASSERT(npc in GLOB.ambient_npcs, "An ambient NPC is not on the list")
	TEST_ASSERT_EQUAL(npc.sentience_type, SENTIENCE_HUMANOID, "Sentience or transference potions would work on an ambient NPC")
	TEST_ASSERT(!HAS_TRAIT(npc, TRAIT_GODMODE), "An ambient NPC cannot be hurt")
	TEST_ASSERT(HAS_TRAIT(npc, "no_containment"), "An ambient NPC can be shut in a closet") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_NO_STORAGE_INSERT), "An ambient NPC can be put in a bag")
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_WEATHER_IMMUNE), "Weather hurts an ambient NPC")
	TEST_ASSERT(!npc.unsuitable_atmos_damage && !npc.unsuitable_cold_damage && !npc.unsuitable_heat_damage, "An ambient NPC dies in vacuum or cold")
	TEST_ASSERT(!is_hostile_creature(npc), "Outpost turrets would shoot an ambient NPC as a wild hostile")
	TEST_ASSERT(npc.name != initial(npc.name), "An ambient NPC has no name of their own")

	// An outpost's turrets count its people as their own, and only while they belong to it
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	npc.set_place(SSambient_npcs.outpost_place(outpost))
	TEST_ASSERT(FACTION_TURRET in npc.faction, "Outpost turrets do not count an outpost's people as their own")
	npc.set_place(null)
	TEST_ASSERT(!(FACTION_TURRET in npc.faction), "Someone gone from an outpost is still one of its turrets' own")

	// A blow hurts them
	var/health_before = npc.health
	npc.apply_damage(20, BRUTE)
	TEST_ASSERT(npc.health < health_before, "A blow did not hurt an ambient NPC")
	npc.revive(ADMIN_HEAL_ALL)
	health_before = npc.health

	// Teleports of any kind leave them where they are
	var/turf/start = get_turf(npc)
	TEST_ASSERT(!do_teleport(npc, run_loc_floor_top_right, forced = TRUE, no_effects = TRUE), "An ambient NPC was teleported")
	TEST_ASSERT_EQUAL(get_turf(npc), start, "An ambient NPC moved when teleported")

	// No polymorph, no mob type change
	TEST_ASSERT(SEND_SIGNAL(npc, COMSIG_LIVING_PRE_WABBAJACKED, "animal") & STOP_WABBAJACK, "An ambient NPC can be polymorphed")
	TEST_ASSERT(SEND_SIGNAL(npc, COMSIG_PRE_MOB_CHANGED_TYPE) & COMPONENT_BLOCK_MOB_CHANGE, "An ambient NPC can be turned into another mob")

	// No pulling, no drag-dropping onto a bed or into a crate, no closet
	var/mob/living/carbon/human/player = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	player.start_pulling(npc)
	TEST_ASSERT(player.pulling != npc, "An ambient NPC can be pulled")
	TEST_ASSERT(SEND_SIGNAL(npc, COMSIG_MOUSEDROP_ONTO, run_loc_floor_top_right, player) & COMPONENT_CANCEL_MOUSEDROP_ONTO, "An ambient NPC can be drag-dropped")
	var/obj/structure/closet/closet = allocate(/obj/structure/closet, get_turf(npc))
	TEST_ASSERT(!closet.insertion_allowed(npc), "A closet takes an ambient NPC")

	// Talking to them with an empty hand is not an attack
	npc.attack_hand(player, list())
	TEST_ASSERT_EQUAL(npc.health, health_before, "Talking to an ambient NPC hurt them")

	// The leash: never a step off it by themselves; off it, a step back is allowed
	var/turf/corner = run_loc_floor_bottom_left
	var/mob/living/basic/ambient_npc/core_test/leashed = allocate(/mob/living/basic/ambient_npc/core_test, corner)
	leashed.leash_bounds = list(corner.x, corner.y, corner.x + 1, corner.y + 1, corner.z)
	var/turf/edge = locate(corner.x + 1, corner.y, corner.z)
	var/turf/outside = locate(corner.x + 2, corner.y, corner.z)
	var/turf/far_outside = locate(corner.x + 3, corner.y, corner.z)
	leashed.forceMove(edge)
	TEST_ASSERT(!leashed.leash_ok(outside), "A turf off the leash counts as on it")
	TEST_ASSERT(!leashed.Move(outside, EAST), "An ambient NPC walked off their leash")
	TEST_ASSERT_EQUAL(get_turf(leashed), edge, "An ambient NPC left their leash")
	leashed.forceMove(far_outside)
	TEST_ASSERT(leashed.own_step_allowed(outside), "An ambient NPC off their leash may not step back towards it")

	// Killed: a body that lies down, their cash and loot once, and nothing more from a revived one killed again
	var/turf/loot_turf = run_loc_floor_top_right
	var/mob/living/basic/ambient_npc/core_test/killable/victim = allocate(/mob/living/basic/ambient_npc/core_test/killable, loot_turf)
	victim.apply_damage(victim.maxHealth * 2, BRUTE)
	TEST_ASSERT_EQUAL(victim.stat, DEAD, "An ambient NPC did not die of their wounds")
	TEST_ASSERT(!victim.density, "An ambient NPC's body still blocks the way")
	TEST_ASSERT_EQUAL(count_pickaxes(loot_turf), 1, "A killed NPC dropped [count_pickaxes(loot_turf)] of its loot, not one")
	var/cash = ambient_test_cash_on(loot_turf)
	TEST_ASSERT(cash >= 5 && cash <= 30, "A killed NPC dropped [cash] cr, not 5 to 30") // AMBIENT_DEATH_CASH_LOW/HIGH
	victim.revive(ADMIN_HEAL_ALL)
	TEST_ASSERT_EQUAL(victim.stat, CONSCIOUS, "A revived NPC is not up again")
	victim.death()
	TEST_ASSERT_EQUAL(count_pickaxes(loot_turf), 1, "A revived NPC dropped its loot again")
	TEST_ASSERT_EQUAL(ambient_test_cash_on(loot_turf), cash, "A revived NPC dropped cash again")

/datum/unit_test/voidcrew_ambient_npc_protections/proc/count_pickaxes(turf/where)
	. = 0
	for(var/obj/item/pickaxe/pick in where)
		.++

/// The credits in cash lying on `where`
/datum/unit_test/proc/ambient_test_cash_on(turf/where)
	. = 0
	for(var/obj/item/stack/spacecash/money in where)
		. += money.get_item_credit_value()

/// Dialogue: lines come from the file with the core's as a fallback, placeholders fill, and cooldowns hold
/datum/unit_test/voidcrew_ambient_npc_dialogue

/datum/unit_test/voidcrew_ambient_npc_dialogue/Run()
	var/mob/living/basic/ambient_npc/core_test/npc = allocate(/mob/living/basic/ambient_npc/core_test, run_loc_floor_bottom_left)
	TEST_ASSERT(length(npc.get_lines("attacked")), "The core file has no line for being attacked") // AMBIENT_LINE_ATTACKED
	TEST_ASSERT(length(npc.get_lines("talk")), "The core file has no line for being talked to") // AMBIENT_LINE_TALK
	TEST_ASSERT_EQUAL(length(ambient_dialogue_lines("no_such_file.json", "default", "talk")), 0, "A missing dialogue file gave lines")
	TEST_ASSERT_EQUAL(length(npc.get_lines("no_such_context")), 0, "A missing context gave lines")
	TEST_ASSERT(length(npc.pick_conversation()) == 2, "The core file has no two-person conversation")
	var/filled = npc.fill_line("{name} and {other} at {place}", npc)
	TEST_ASSERT(!findtext(filled, "{"), "A line kept a placeholder: [filled]")
	// A spontaneous line waits out their pause; a forced one does not, and starts it
	npc.next_line_at = world.time + 100
	TEST_ASSERT(!npc.speak_context("idle"), "A spontaneous line ignored their pause") // AMBIENT_LINE_IDLE
	TEST_ASSERT(npc.speak_context("talk", null, force = TRUE), "A forced line did not come")
	TEST_ASSERT(npc.next_line_at > world.time, "Speaking did not start their pause")

// =========================================================================
// PRESENCE AT A TRADER OUTPOST
// =========================================================================

/**
 * While nobody is on the concourse its roles are filled in place, a few people a tick, each already
 * at what they do and holding still with their AI off; a player wakes them and they carry on where
 * they stopped; while players are there, anyone who left is replaced off the lift, one at a time, up
 * to the cap; when the players leave nobody is deleted, and everyone holds still again.
 */
/datum/unit_test/voidcrew_ambient_outpost_presence

/datum/unit_test/voidcrew_ambient_outpost_presence/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	TEST_ASSERT_NOTNULL(place, "A trader outpost got no place")
	TEST_ASSERT_EQUAL(SSambient_npcs.outpost_place(outpost), place, "A trader outpost got a second place")
	TEST_ASSERT_EQUAL(length(SSambient_npcs.outpost_players(outpost)), 0, "Someone with a client is on a test concourse")
	var/datum/ambient_outpost_role/core_test/role = allocate(/datum/ambient_outpost_role/core_test)
	role.npc_type = /mob/living/basic/ambient_npc/core_test
	var/list/roles = list(role)
	var/turf/lift = run_loc_floor_top_right

	// Nobody there: the role is filled in place, no more than the tick's share at a time
	TEST_ASSERT_EQUAL(SSambient_npcs.update_outpost(place, 0, roles, 2), 2, "The first tick at an empty outpost did not make two people in place")
	TEST_ASSERT(!place.occupied, "An empty concourse counts as occupied")
	TEST_ASSERT_EQUAL(SSambient_npcs.update_outpost(place, 0, roles, 2), 1, "The rest of the role was not made in place on the next tick")
	TEST_ASSERT_EQUAL(SSambient_npcs.update_outpost(place, 0, roles, 2), 0, "More people were made in place than the role wants")
	TEST_ASSERT_EQUAL(length(place.npcs), 3, "An empty outpost has [length(place.npcs)] people for a role of three")
	for(var/mob/living/basic/ambient_npc/npc as anything in place.npcs)
		TEST_ASSERT_EQUAL(npc.place, place, "Someone made in place does not belong to the outpost")
		TEST_ASSERT_EQUAL(npc.role, role.type, "Someone made in place does not know their role")
		TEST_ASSERT(get_dist(npc, lift) > 1, "[npc] was made on or beside the lift, not in place")
		TEST_ASSERT(npc.activity?.arrived, "[npc] was made in place but is not yet at what they do")
		TEST_ASSERT_EQUAL(npc.home, get_turf(npc), "[npc]'s leash is not anchored where they were made")
		// Their AI is off with nobody there
		TEST_ASSERT(HAS_TRAIT_FROM(npc, TRAIT_AI_PAUSED, "ambient_paused"), "[npc] at an empty outpost is not held still") // AMBIENT_PAUSED_TRAIT
		TEST_ASSERT(npc.paused_at, "[npc] at an empty outpost does not know when they stopped")
		TEST_ASSERT(!npc.ai_controller.able_to_run, "[npc]'s AI can run at an empty outpost")
		TEST_ASSERT_EQUAL(npc.ai_controller.ai_status, AI_STATUS_OFF, "[npc]'s AI is on at an empty outpost")

	// Their clocks stop while nobody is there: say this one stood still for five minutes
	var/mob/living/basic/ambient_npc/sleeper = place.npcs[1]
	var/ends_before = sleeper.activity.ends_at
	var/line_before = sleeper.next_line_at
	TEST_ASSERT(ends_before, "Someone made in place is doing something with no end")
	sleeper.paused_at = world.time - 3000

	// A player comes: everyone carries on where they stopped, and nobody else comes while the roles are full
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT(place.occupied, "A concourse with a player on it is not occupied")
	TEST_ASSERT_EQUAL(length(place.npcs), 3, "Someone came while every role was full")
	for(var/mob/living/basic/ambient_npc/npc as anything in place.npcs)
		TEST_ASSERT(!HAS_TRAIT(npc, TRAIT_AI_PAUSED), "[npc] is still held still with a player on the concourse")
		TEST_ASSERT(!npc.paused_at, "[npc] still counts as stopped with a player on the concourse")
		TEST_ASSERT(npc.ai_controller.able_to_run, "[npc]'s AI cannot run with a player on the concourse")
	TEST_ASSERT_EQUAL(sleeper.activity.ends_at, ends_before + 3000, "Five minutes standing still were not added to what someone was doing")
	TEST_ASSERT_EQUAL(sleeper.next_line_at, line_before + 3000, "Five minutes standing still were not added to someone's next line")

	// Turnover while a player is there: two go, and their replacements step off the lift one at a time
	qdel(place.npcs[3])
	qdel(place.npcs[2])
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT_EQUAL(length(place.npcs), 2, "[length(place.npcs) - 1] people came off the lift at once")
	var/mob/living/basic/ambient_npc/newcomer = place.npcs[2]
	TEST_ASSERT_EQUAL(get_turf(newcomer), lift, "A replacement with a player there came somewhere other than the lift")
	TEST_ASSERT_EQUAL(newcomer.role, role.type, "A replacement does not know their role")
	TEST_ASSERT(!HAS_TRAIT(newcomer, TRAIT_AI_PAUSED), "A replacement with a player there is held still")
	TEST_ASSERT(newcomer.leash_ok(run_loc_floor_bottom_left), "A replacement is leashed off the concourse")
	newcomer.forceMove(run_loc_floor_bottom_left)
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT_EQUAL(length(place.npcs), 2, "The next replacement did not wait its turn at the lift")
	place.arrivals_at = world.time
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT_EQUAL(length(place.npcs), 3, "The second replacement never came")
	for(var/mob/living/basic/ambient_npc/arrival in lift)
		arrival.forceMove(run_loc_floor_bottom_left)

	// Never more than the outpost's cap, whatever the roles want
	role.max_count = 50
	for(var/i in 1 to 15)
		place.arrivals_at = world.time
		SSambient_npcs.update_outpost(place, 1, roles)
		for(var/mob/living/basic/ambient_npc/arrival in lift)
			arrival.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(place.living_npcs()), 8, "A trader outpost has [length(place.living_npcs())] NPCs, not the cap of 8") // AMBIENT_OUTPOST_TRANSIENT_CAP

	// A fight near them: they duck and head off
	var/mob/living/basic/ambient_npc/witness = place.npcs[1]
	var/mob/living/carbon/human/brawler = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	SEND_SIGNAL(outpost, "trader_outpost_violence", brawler) // COMSIG_TRADER_OUTPOST_VIOLENCE
	TEST_ASSERT(istype(witness.activity, /datum/ambient_activity/leave), "A witness to a fight did not head for the lift")
	TEST_ASSERT(witness.crouching, "A witness to a fight did not duck")
	TEST_ASSERT_EQUAL(witness.activity.spot, lift, "A witness is leaving somewhere other than the lift")

	// The players leave: nobody goes, however long it stays empty; everyone holds still, and nobody is made past the cap
	var/list/everyone = place.npcs.Copy()
	for(var/i in 1 to 5)
		SSambient_npcs.update_outpost(place, 0, roles, 10)
	TEST_ASSERT(!place.occupied, "The concourse is still occupied with nobody on it")
	TEST_ASSERT_EQUAL(length(place.npcs), length(everyone), "[length(place.npcs)] people are at an outpost that had [length(everyone)] before the players left")
	for(var/mob/living/basic/ambient_npc/npc as anything in everyone)
		TEST_ASSERT(!QDELETED(npc), "[npc] was deleted when the players left")
		TEST_ASSERT(HAS_TRAIT_FROM(npc, TRAIT_AI_PAUSED, "ambient_paused"), "[npc] is not held still after the players left") // AMBIENT_PAUSED_TRAIT
		TEST_ASSERT(!npc.ai_controller.able_to_run, "[npc]'s AI can run after the players left")

	// Someone who left while players were there is made up in place once they have gone
	role.max_count = 3
	for(var/mob/living/basic/ambient_npc/npc as anything in place.npcs.Copy())
		qdel(npc)
	place.needs_settling = TRUE
	SSambient_npcs.update_outpost(place, 0, roles, 10)
	TEST_ASSERT_EQUAL(length(place.npcs), 3, "An empty outpost's role was not made up in place")
	for(var/mob/living/basic/ambient_npc/npc as anything in place.npcs)
		TEST_ASSERT(get_dist(npc, lift) > 1, "[npc] was made up on or beside the lift, not in place")

	// The next player wakes them all again
	SSambient_npcs.update_outpost(place, 1, roles)
	TEST_ASSERT(place.occupied, "A returning player did not wake the outpost")
	for(var/mob/living/basic/ambient_npc/npc as anything in place.npcs)
		TEST_ASSERT(!HAS_TRAIT(npc, TRAIT_AI_PAUSED), "[npc] is still held still after a player came back")

/// Settling in never starts someone off heading for the lift: a role whose only routine is leaving fails to settle rather than starting it
/datum/unit_test/voidcrew_ambient_settle_never_leaves

/datum/unit_test/voidcrew_ambient_settle_never_leaves/Run()
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/mob/living/basic/ambient_npc/core_test/leaver/npc = new(run_loc_floor_bottom_left)
	npc.set_place(place)
	TEST_ASSERT(!npc.settle_in(), "Someone whose only routine is leaving was settled into it")
	TEST_ASSERT_NULL(npc.activity, "A failed settle left an activity running")
	TEST_ASSERT(get_dist(npc, run_loc_floor_top_right) > 1, "Someone whose only routine is leaving ended up on or beside the lift")

// =========================================================================
// PLANET SITES
// =========================================================================

/// A planet rolls at most two sites and six NPCs; a site comes out whole within the budget; one despawned alive comes back; one killed does not, and once all are killed the site is spent; the planet's fauna budget pays for them and forgets them when it unloads
/datum/unit_test/voidcrew_ambient_planet_sites

/datum/unit_test/voidcrew_ambient_planet_sites/Run()
	var/datum/ambient_site_kind/core_test/kind = allocate(/datum/ambient_site_kind/core_test)
	kind.npc_type = /mob/living/basic/ambient_npc/core_test/killable
	kind.planet_types = list(/datum/overmap/planet/jungle)
	kind.chance = 100
	var/datum/ambient_planet/record = allocate(/datum/ambient_planet)
	record.key = "ambient core test planet"
	record.planet_type = /datum/overmap/planet/jungle
	record.band = 1 // ZONE_GREEN
	record.bounds = ambient_test_room_bounds()

	// Its chance is for its own planet types and bands only
	var/datum/ambient_planet/elsewhere = allocate(/datum/ambient_planet)
	elsewhere.planet_type = /datum/overmap/planet/lava
	elsewhere.band = 1 // ZONE_GREEN
	TEST_ASSERT_EQUAL(kind.chance_on(elsewhere), 0, "A site kind rolls on a planet type it does not list")
	TEST_ASSERT_EQUAL(kind.chance_on(record), 100, "A site kind does not roll on its own planet type")

	// Rolling: at most one site, however many kinds come up
	SSambient_npcs.roll_planet_sites(record, list(kind, kind, kind, kind))
	TEST_ASSERT(record.rolled, "A rolled planet does not know it was rolled")
	TEST_ASSERT_EQUAL(length(record.sites), 1, "A planet rolled [length(record.sites)] sites, not the cap of 1") // AMBIENT_PLANET_SITES_MAX
	QDEL_LIST(record.sites)

	// ...and at most six NPCs: an eight-NPC site gets six
	kind.min_npcs = 8
	kind.max_npcs = 8
	record.rolled = FALSE
	SSambient_npcs.roll_planet_sites(record, list(kind))
	TEST_ASSERT_EQUAL(length(record.sites), 1, "A planet did not roll its site")
	var/datum/ambient_place/site/big_site = record.sites[1]
	TEST_ASSERT_EQUAL(big_site.npc_total, 6, "A site holds [big_site.npc_total] NPCs, over the planet's six") // AMBIENT_PLANET_NPCS_MAX
	QDEL_LIST(record.sites)
	kind.min_npcs = 2
	kind.max_npcs = 2

	// One two-NPC site
	var/datum/ambient_place/site/site = new(kind, run_loc_floor_bottom_left, record)
	site.npc_total = 2
	record.sites += site
	TEST_ASSERT_EQUAL(site.state, "dormant", "A new site is not dormant") // AMBIENT_SITE_DORMANT

	// It comes out whole or not at all
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 1), 0, "Half a site came out on a budget of one")
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 2, "A two-NPC site did not come out")
	TEST_ASSERT_EQUAL(site.state, "active", "A site with its NPCs out is not active") // AMBIENT_SITE_ACTIVE
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 0, "A site came out twice")
	for(var/mob/living/basic/ambient_npc/npc as anything in site.living_npcs())
		TEST_ASSERT_EQUAL(npc.place, site, "A site's NPC does not belong to it")
		TEST_ASSERT(!HAS_TRAIT(npc, TRAIT_GODMODE), "A planet NPC is in godmode")

	// Despawned alive (the planet sweep): they come back on the next visit
	var/list/npcs = site.living_npcs()
	qdel(npcs[1])
	TEST_ASSERT_EQUAL(site.npcs_missing(), 1, "A despawned NPC is not missed")
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 1, "A despawned NPC did not come back")

	// Killed: that one never comes back, the other still does
	npcs = site.living_npcs()
	var/mob/living/basic/ambient_npc/first_victim = npcs[1]
	first_victim.death()
	TEST_ASSERT_EQUAL(site.dead, 1, "A killed NPC was not counted")
	TEST_ASSERT(site.state != "spent", "A site was spent with one of its two NPCs still alive") // AMBIENT_SITE_SPENT
	for(var/mob/living/basic/ambient_npc/npc as anything in site.npcs.Copy())
		qdel(npc)
	TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 1, "A site came back with [length(site.living_npcs())] NPCs after losing one of two")

	// Both killed: spent for the round, however often the crew leaves and lands again
	npcs = site.living_npcs()
	var/mob/living/basic/ambient_npc/second_victim = npcs[1]
	second_victim.death()
	TEST_ASSERT_EQUAL(site.state, "spent", "A site whose NPCs were all killed is not spent") // AMBIENT_SITE_SPENT
	for(var/mob/living/basic/ambient_npc/npc as anything in site.npcs.Copy())
		qdel(npc)
	for(var/visit in 1 to 3)
		TEST_ASSERT_EQUAL(SSambient_npcs.realize_planet(record, 6), 0, "A spent site came back on visit [visit]")
	TEST_ASSERT_EQUAL(site.npcs_missing(), 0, "A spent site misses NPCs")

	// Through SSplanet_mobs: the planet's people are charged to its fauna budget, and forgotten when it unloads
	var/datum/planet_mob_tracker/tracker = SSplanet_mobs.register_planet("ambient core test tracker", run_loc_floor_bottom_left.z, null, 1) // ZONE_GREEN
	var/datum/ambient_planet/hooked = new
	hooked.key = tracker.name
	hooked.planet_type = /datum/overmap/planet/jungle
	hooked.band = 1 // ZONE_GREEN
	hooked.bounds = ambient_test_room_bounds()
	hooked.rolled = TRUE
	var/datum/ambient_place/site/hooked_site = new(kind, run_loc_floor_top_right, hooked)
	hooked_site.npc_total = 2
	hooked.sites += hooked_site
	SSambient_npcs.planets[tracker.name] = hooked
	var/total_before = SSplanet_mobs.total_managed_mobs
	SSplanet_mobs.spawn_planet_mobs(tracker)
	TEST_ASSERT_EQUAL(tracker.spawned_count, 2, "The planet's budget was charged [tracker.spawned_count] for two NPCs")
	TEST_ASSERT_EQUAL(SSplanet_mobs.total_managed_mobs, total_before + 2, "The galaxy's budget was not charged for a planet's NPCs")
	TEST_ASSERT_EQUAL(length(hooked_site.living_npcs()), 2, "The planet's site did not come out with its fauna")
	SSplanet_mobs.unregister_planet(tracker.name)
	TEST_ASSERT(!(tracker.name in SSambient_npcs.planets), "An unloaded planet's sites were not forgotten")
	TEST_ASSERT(QDELETED(hooked), "An unloaded planet's record was not deleted")
	TEST_ASSERT_EQUAL(SSplanet_mobs.total_managed_mobs, total_before, "An unloaded planet kept its NPCs' budget")

// =========================================================================
// THE ROUTINE RUNNER
// =========================================================================

/// The planner picks from the routine and walks to it; the activity runs where it happens and puts everything back; reactions outrank routines and nothing outranks leaving; chat, drink and work run
/datum/unit_test/voidcrew_ambient_activities

/datum/unit_test/voidcrew_ambient_activities/Run()
	var/turf/corner = run_loc_floor_bottom_left
	var/turf/chair_turf = run_loc_floor_top_right

	// The planner: a routine of sitting, a chair across the room
	var/obj/structure/chair/chair = allocate(/obj/structure/chair, chair_turf)
	var/mob/living/basic/ambient_npc/core_test/sitter/sitter = allocate(/mob/living/basic/ambient_npc/core_test/sitter, corner)
	var/datum/ai_controller/controller = sitter.ai_controller
	TEST_ASSERT(istype(controller, /datum/ai_controller/basic_controller/ambient_npc), "An ambient NPC has no ambient AI")
	// A test world has no client near: every move (update_grid(), recalculate_idle()) would idle the AI, and the planner only runs while it is on
	controller.can_idle = FALSE
	controller.set_ai_status(AI_STATUS_ON)
	controller.SelectBehaviors(1)
	TEST_ASSERT(istype(sitter.activity, /datum/ambient_activity/sit), "The planner did not start the routine's activity")
	TEST_ASSERT_EQUAL(controller.blackboard["ambient_destination"], chair_turf, "The planner is not walking to the chair") // BB_AMBIENT_DESTINATION
	// The walk, then the next plan runs the activity where it happens
	sitter.forceMove(chair_turf)
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_ON, "The walk to the chair turned the AI off")
	controller.SelectBehaviors(1)
	var/datum/ai_behavior/ambient_activity/runner = GET_AI_BEHAVIOR(/datum/ai_behavior/ambient_activity)
	TEST_ASSERT(controller.planned_behaviors[runner], "The planner did not run the activity at the chair")
	runner.perform(1, controller)
	TEST_ASSERT_EQUAL(sitter.buckled, chair, "The runner did not sit them down")
	controller.set_ai_status(AI_STATUS_OFF)
	sitter.end_activity()
	TEST_ASSERT_NULL(sitter.buckled, "Ending the activity did not stand them up")
	TEST_ASSERT_NULL(sitter.activity, "An ended activity is still running")

	// Priorities: a reaction replaces a routine, and nothing replaces leaving
	var/mob/living/basic/ambient_npc/core_test/npc = allocate(/mob/living/basic/ambient_npc/core_test, corner)
	TEST_ASSERT_NOTNULL(npc.start_activity(new /datum/ambient_activity/idle(npc)), "Standing about could not start")
	TEST_ASSERT_NOTNULL(npc.start_activity(new /datum/ambient_activity/shelter(npc, null, 100)), "Sheltering did not replace standing about")
	TEST_ASSERT_NULL(npc.start_activity(new /datum/ambient_activity/idle(npc)), "Standing about replaced sheltering")
	TEST_ASSERT_NOTNULL(npc.start_activity(new /datum/ambient_activity/leave(npc, chair_turf)), "Leaving did not replace sheltering")
	TEST_ASSERT_NULL(npc.start_activity(new /datum/ambient_activity/shelter(npc, null, 100)), "Sheltering replaced leaving")
	// Leaving: at the exit they fade out, and nothing starts after
	npc.forceMove(chair_turf)
	npc.activity_step(1)
	TEST_ASSERT(npc.fading, "Someone at the exit did not leave")
	TEST_ASSERT_NULL(npc.start_activity(new /datum/ambient_activity/idle(npc)), "Someone fading out started something new")

	// Drinking: a real glass in hand, sipped, set down on the table at the end
	var/obj/structure/table/table = allocate(/obj/structure/table, locate(corner.x + 2, corner.y, corner.z))
	var/mob/living/basic/ambient_npc/core_test/drinker = allocate(/mob/living/basic/ambient_npc/core_test, corner)
	var/datum/ambient_activity/drink/drink = drinker.start_activity(new /datum/ambient_activity/drink(drinker, table))
	TEST_ASSERT_NOTNULL(drink, "A drink at a table could not start")
	drinker.forceMove(drink.spot)
	TEST_ASSERT_EQUAL(drinker.activity_step(1), 0, "Drinking stopped at once") // AMBIENT_STEP_CONTINUE
	var/obj/item/glass = drinker.held_item
	TEST_ASSERT(istype(glass, /obj/item/reagent_containers/cup/glass/drinkingglass), "A drinker has no glass")
	TEST_ASSERT(drinker.sip(), "A drinker could not sip")
	drinker.end_activity()
	TEST_ASSERT_NULL(drinker.held_item, "A drinker kept their glass after drinking")
	TEST_ASSERT_EQUAL(glass.loc, table.loc, "A finished glass was not set down on the table")

	// Chat: the partner drops what it was doing and answers until the starter is done
	var/mob/living/basic/ambient_npc/core_test/talker = allocate(/mob/living/basic/ambient_npc/core_test, corner)
	var/mob/living/basic/ambient_npc/core_test/listener = allocate(/mob/living/basic/ambient_npc/core_test, locate(corner.x, corner.y + 1, corner.z))
	listener.start_activity(new /datum/ambient_activity/idle(listener))
	var/datum/ambient_activity/chat/chat = talker.start_activity(new /datum/ambient_activity/chat(talker, listener))
	TEST_ASSERT_NOTNULL(chat, "A chat with someone right there could not start")
	var/datum/ambient_activity/chat/answer = listener.activity
	TEST_ASSERT(istype(answer) && answer.responding, "The partner did not stop to answer")
	TEST_ASSERT(chat.at_spot(), "The talker wants to walk to someone right beside them")
	TEST_ASSERT_EQUAL(talker.activity_step(1), 0, "The chat ended at once") // AMBIENT_STEP_CONTINUE
	TEST_ASSERT_EQUAL(listener.activity_step(1), 0, "The answer ended at once") // AMBIENT_STEP_CONTINUE
	talker.end_activity()
	TEST_ASSERT_EQUAL(listener.activity_step(1), 2, "The partner kept answering after the talker left") // AMBIENT_STEP_DONE

	// Work at an object: the mechanics' work loop, on them for the job and off them after
	allocate(/obj/structure/rack, locate(corner.x + 2, corner.y + 3, corner.z))
	var/mob/living/basic/ambient_npc/core_test/worker = allocate(/mob/living/basic/ambient_npc/core_test, locate(corner.x + 1, corner.y + 3, corner.z))
	worker.work_weights = list(/datum/outpost_ambient_work/wrench = 1)
	var/datum/ambient_activity/work/work = worker.start_activity(new /datum/ambient_activity/work(worker))
	TEST_ASSERT_NOTNULL(work, "Work at a rack could not start")
	TEST_ASSERT_NOTNULL(worker.GetComponent(/datum/component/outpost_ambient_worker), "Working did not use the work loop")
	worker.forceMove(work.spot)
	TEST_ASSERT_EQUAL(worker.activity_step(1), 0, "Work stopped at once") // AMBIENT_STEP_CONTINUE
	TEST_ASSERT_NOTNULL(work.worker?.work, "No job was started at the rack")
	worker.end_activity()
	TEST_ASSERT_NULL(worker.GetComponent(/datum/component/outpost_ambient_worker), "The work loop stayed on after the job")

// =========================================================================
// LOITERING AND CROWDING
// =========================================================================

/// ambient_open_span(), the loiter floor (lift clearance, doors), crowded(), settling spread out, idle and wander landing on loiter tiles, chat partners skipping a crowd, and cover spreading out from the refuge
/datum/unit_test/voidcrew_ambient_outpost_spread

/datum/unit_test/voidcrew_ambient_outpost_spread/Run()
	var/turf/bl = run_loc_floor_bottom_left
	var/turf/lift = run_loc_floor_top_right

	// ambient_open_span(): a single 5-tile row is a passage on its short axis; the full 5x5 room is wide open at its centre
	var/list/row = list()
	for(var/x in bl.x to bl.x + 4)
		row[locate(x, bl.y, bl.z)] = TRUE
	TEST_ASSERT_EQUAL(ambient_open_span(locate(bl.x + 2, bl.y, bl.z), row), 1, "A one-tile-wide row has an open span other than 1")
	var/list/room = list()
	for(var/turf/tile as anything in block(locate(bl.x, bl.y, bl.z), locate(bl.x + 4, bl.y + 4, bl.z)))
		room[tile] = TRUE
	TEST_ASSERT_EQUAL(ambient_open_span(locate(bl.x + 2, bl.y + 2, bl.z), room), 5, "The centre of a 5x5 room has an open span other than 5")

	// The loiter floor: the lift's clearance, a door and its cardinal side are out; a far corner is in
	var/obj/structure/overmap/trader_outpost/outpost = ambient_test_outpost()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/turf/near_lift = locate(lift.x - 1, lift.y, lift.z)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, locate(bl.x + 1, bl.y + 1, bl.z))
	var/turf/door_turf = get_turf(door)
	var/turf/beside_door = locate(door_turf.x - 1, door_turf.y, door_turf.z)
	var/turf/far_corner = bl
	var/list/loiter = place.get_loiter_floor()
	TEST_ASSERT(!loiter[near_lift], "A tile within 2 of the lift is a loiter tile") // AMBIENT_LIFT_CLEARANCE
	TEST_ASSERT(!loiter[door_turf], "A door tile is a loiter tile")
	TEST_ASSERT(!loiter[beside_door], "A tile beside a door is a loiter tile")
	TEST_ASSERT(loiter[far_corner], "The far corner is not a loiter tile")

	// crowded(): one NPC within 2 tiles does not crowd it; two do; a claimed (not yet arrived) spot is crowded too
	var/turf/target = locate(far_corner.x + 2, far_corner.y + 2, far_corner.z)
	var/mob/living/basic/ambient_npc/core_test/watcher1 = new(locate(target.x - 1, target.y, target.z))
	watcher1.set_place(place)
	TEST_ASSERT(!place.crowded(target, null), "One NPC within 2 tiles already crowds a tile") // AMBIENT_CROWD_MAX
	var/mob/living/basic/ambient_npc/core_test/watcher2 = new(locate(target.x, target.y - 1, target.z))
	watcher2.set_place(place)
	TEST_ASSERT(place.crowded(target, null), "Two NPCs within 2 tiles do not crowd a tile") // AMBIENT_CROWD_RADIUS, AMBIENT_CROWD_MAX
	qdel(watcher1)
	qdel(watcher2)
	var/mob/living/basic/ambient_npc/core_test/claimer = new(bl)
	claimer.set_place(place)
	claimer.activity = new /datum/ambient_activity/idle(claimer)
	claimer.activity.go_to(target)
	TEST_ASSERT(place.crowded(target, null), "A tile someone is walking to is not claimed")
	qdel(claimer)

	// An NPC starting idle beside the door is sent to a loiter tile; a wander stop is a loiter tile
	var/mob/living/basic/ambient_npc/core_test/idler = new(beside_door)
	idler.set_place(place)
	var/datum/ambient_activity/idle/idle_act = idler.start_activity(new /datum/ambient_activity/idle(idler))
	TEST_ASSERT_NOTNULL(idle_act, "Idle could not start beside the door")
	TEST_ASSERT(idle_act.spot && loiter[idle_act.spot], "An NPC idling beside the door was not sent to a loiter tile")
	qdel(idler)
	var/mob/living/basic/ambient_npc/core_test/wanderer = new(far_corner)
	wanderer.set_place(place)
	var/stops = 0
	for(var/i in 1 to 20)
		var/turf/stop = wanderer.random_tile_near(far_corner, 4)
		if(!stop)
			continue
		stops++
		TEST_ASSERT(loiter[stop], "A wander stop was not a loiter tile")
	TEST_ASSERT(stops > 0, "Wandering never found a stop")
	qdel(wanderer)

	// find_chat_partner() skips a candidate crowded by two others already beside them
	var/mob/living/basic/ambient_npc/core_test/crowded_a = new(far_corner)
	crowded_a.set_place(place)
	var/mob/living/basic/ambient_npc/core_test/crowded_b = new(locate(far_corner.x + 1, far_corner.y, far_corner.z))
	crowded_b.set_place(place)
	var/mob/living/basic/ambient_npc/core_test/crowded_c = new(locate(far_corner.x, far_corner.y + 1, far_corner.z))
	crowded_c.set_place(place)
	var/mob/living/basic/ambient_npc/core_test/asker = new(locate(far_corner.x + 2, far_corner.y, far_corner.z))
	asker.set_place(place)
	TEST_ASSERT_NULL(asker.find_chat_partner(), "find_chat_partner() picked a partner already crowded by two others")
	qdel(crowded_a)
	qdel(crowded_b)
	qdel(crowded_c)
	qdel(asker)

	// Settling three with a role of max_count = 3: none within 2 of the lift, none with 2 or more others within 2 tiles
	var/datum/ambient_outpost_role/core_test/spread_role = allocate(/datum/ambient_outpost_role/core_test)
	spread_role.npc_type = /mob/living/basic/ambient_npc/core_test
	spread_role.max_count = 3
	place.needs_settling = TRUE
	SSambient_npcs.settle_outpost(place, list(spread_role), 10)
	TEST_ASSERT_EQUAL(length(place.npcs), 3, "Settling a role of three made [length(place.npcs)] NPCs")
	var/list/settled = place.npcs.Copy()
	for(var/i in 1 to length(settled))
		var/mob/living/basic/ambient_npc/npc = settled[i]
		TEST_ASSERT(get_dist(npc, lift) > 2, "[npc] settled within 2 tiles of the lift") // AMBIENT_LIFT_CLEARANCE
		var/earlier_nearby = 0
		for(var/j in 1 to i - 1)
			if(get_dist(npc, settled[j]) <= 2) // AMBIENT_CROWD_RADIUS
				earlier_nearby++
		TEST_ASSERT(earlier_nearby < 2, "[npc] settled with 2 or more earlier arrivals within 2 tiles") // AMBIENT_CROWD_MAX
	for(var/mob/living/basic/ambient_npc/npc as anything in place.npcs.Copy())
		qdel(npc)

	// Cover: with no crew fighting, three NPCs sent for cover get three different spots, the first one the refuge
	var/turf/refuge = locate(bl.x + 2, bl.y + 2, bl.z)
	var/mob/living/basic/ambient_npc/core_test/first = new(bl)
	first.set_place(place)
	var/mob/living/basic/ambient_npc/core_test/second = new(bl)
	second.set_place(place)
	var/mob/living/basic/ambient_npc/core_test/third = new(bl)
	third.set_place(place)
	first.react_shootout(refuge)
	TEST_ASSERT(istype(first.activity, /datum/ambient_activity/take_cover), "The first NPC did not take cover")
	TEST_ASSERT_EQUAL(first.activity.spot, refuge, "The first NPC to take cover did not go to the refuge")
	second.react_shootout(refuge)
	TEST_ASSERT(istype(second.activity, /datum/ambient_activity/take_cover), "The second NPC did not take cover")
	TEST_ASSERT(second.activity.spot != refuge, "The second NPC also went to the refuge")
	third.react_shootout(refuge)
	TEST_ASSERT(istype(third.activity, /datum/ambient_activity/take_cover), "The third NPC did not take cover")
	TEST_ASSERT(third.activity.spot != refuge && third.activity.spot != second.activity.spot, "Two NPCs got the same cover spot")
	qdel(first)
	qdel(second)
	qdel(third)
