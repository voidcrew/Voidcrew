/**
 * Outpost police tests: police_cutter.dm (voidcrew/modules/outpost_police/). Owner: P9.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 */

/// A police datum that records the crews it was told to pardon, so a payment can be checked without the wanted
/// code (police_wanted.dm) being in the build
/datum/outpost_police/cutter_test_recorder
	/// Crew records pardon_crew() was called with
	var/list/pardoned = list()

/datum/outpost_police/cutter_test_recorder/pardon_crew(datum/voidcrew_crew_record/crew)
	pardoned += crew
	return ..()

/**
 * The cutter's types: an empty hold, its own dialog and template, crew in port security's kit that pays out
 * nothing, and a template kept off every list a player or a checkpoint test walks.
 */
/datum/unit_test/voidcrew_outpost_police_cutter_types

/datum/unit_test/voidcrew_outpost_police_cutter_types/Run()
	var/obj/structure/overmap/ship/npc/pirate/nt_patrol/police/cutter_type = /obj/structure/overmap/ship/npc/pirate/nt_patrol/police
	TEST_ASSERT_EQUAL(initial(cutter_type.shuttle_template), /datum/map_template/shuttle/voidcrew/police_cutter, "The cutter flies a hull that is not its own")
	TEST_ASSERT_EQUAL(initial(cutter_type.hold_credits_min), 0, "The cutter's hold has a credit floor")
	TEST_ASSERT_EQUAL(initial(cutter_type.hold_credits_max), 0, "The cutter's hold has a credit ceiling")
	TEST_ASSERT_EQUAL(initial(cutter_type.negotiation_dialog_type), /datum/pirate_faction_dialog/police_cutter, "The cutter negotiates in the customs' words")
	TEST_ASSERT(ispath(initial(cutter_type.captain_type), /mob/living/carbon/human/npc/faction_pirate/nt_customs/sergeant/police), "The cutter's captain is not port security")
	TEST_ASSERT(ispath(initial(cutter_type.boss_type), /mob/living/carbon/human/npc/faction_pirate/nt_customs/director/police), "The cutter's boss is not port security's commander")
	var/list/crew_types = initial(cutter_type.crew_types) + initial(cutter_type.boarding_pod_mob_types)
	TEST_ASSERT(length(crew_types), "The cutter has no crew")
	for(var/crew_type in crew_types)
		TEST_ASSERT(ispath(crew_type, /mob/living/carbon/human/npc/faction_pirate/nt_customs), "[crew_type] in the cutter's crew is not a customs-family NPC")
		TEST_ASSERT(ispath(crew_type, /mob/living/carbon/human/npc/faction_pirate/nt_customs/officer/police) || ispath(crew_type, /mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector/police), "[crew_type] in the cutter's crew is not port security")

	// The crew: port security's kit, the customs' guns, and nothing for a player to take off a body
	for(var/zone in 1 to 3)
		var/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer/police/officer = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/nt_customs/officer/police, zone)
		var/mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector/police/marksman = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/nt_customs/inspector/police, zone)
		var/mob/living/carbon/human/npc/faction_pirate/nt_customs/sergeant/police/sergeant = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/nt_customs/sergeant/police, zone)
		TEST_ASSERT_NOTNULL(locate(/obj/item/melee/baton/security) in officer?.held_items, "A cutter officer doesn't hold a stun baton in zone [zone]")
		var/obj/item/gun/ballistic/marksman_gun = human_npc_held_gun(marksman)
		var/obj/item/gun/ballistic/sergeant_gun = human_npc_held_gun(sergeant)
		if(zone == 3)
			TEST_ASSERT(istype(marksman_gun, /obj/item/gun/ballistic/automatic/wt550), "A red-zone cutter marksman doesn't hold a WT-550")
			TEST_ASSERT(istype(sergeant_gun, /obj/item/gun/ballistic/automatic/ar), "A red-zone cutter sergeant doesn't hold a rifle")
		else
			TEST_ASSERT(istype(marksman_gun, /obj/item/gun/ballistic/automatic/pistol/m1911), "A zone [zone] cutter marksman doesn't hold the ladder pistol")
			TEST_ASSERT(istype(sergeant_gun, /obj/item/gun/ballistic/automatic/pistol/m1911), "A zone [zone] cutter sergeant doesn't hold the ladder pistol")
		TEST_ASSERT_NOTNULL(human_npc_find_ammo(marksman, marksman_gun), "A cutter marksman carries no spare magazine in zone [zone]")
		TEST_ASSERT_NOTNULL(human_npc_find_ammo(sergeant, sergeant_gun), "A cutter sergeant carries no spare magazine in zone [zone]")
		for(var/mob/living/carbon/human/npc/faction_pirate/nt_customs/crew as anything in list(officer, marksman, sergeant))
			TEST_ASSERT_NOTNULL(crew, "A cutter crewman wasn't built in zone [zone]")
			if(isnull(crew))
				continue
			TEST_ASSERT(ROLE_DEATHSQUAD in crew.faction, "[crew.type] isn't on the Deathsquad side its hull's turrets are keyed to")
			TEST_ASSERT(!(FACTION_PIRATE in crew.faction), "[crew.type] counts as a pirate")
			TEST_ASSERT(istype(crew.wear_mask, /obj/item/clothing/mask/gas/sechailer), "[crew.type] isn't in port security's kit")
			TEST_ASSERT(istype(crew.wear_id, /obj/item/card/id) && !istype(crew.wear_id, /obj/item/card/id/advanced/centcom), "[crew.type] carries the customs' CentCom card")
			TEST_ASSERT(human_npc_gear_locked(crew.wear_id), "[crew.type]'s ID card isn't locked to it")
			TEST_ASSERT(human_npc_gear_locked(crew.w_uniform), "[crew.type]'s uniform isn't locked to it")
			TEST_ASSERT(!length(crew.npc_roll_death_loot()), "[crew.type] rolls death loot; a cutter is no prize")
			TEST_ASSERT_EQUAL(crew.npc_death_cash, 0, "[crew.type] carries cash")
	var/mob/living/carbon/human/npc/faction_pirate/nt_customs/director/police/commander = human_npc_build_in_zone(/mob/living/carbon/human/npc/faction_pirate/nt_customs/director/police, 3)
	TEST_ASSERT_NOTNULL(commander, "The cutter's commander wasn't built")
	TEST_ASSERT_EQUAL(commander.npc_rank, 2, "The commander isn't a boss") // HUMAN_NPC_RANK_BOSS
	TEST_ASSERT(istype(human_npc_held_gun(commander), /obj/item/gun/energy/e_gun), "The commander doesn't hold an e-gun")
	TEST_ASSERT(!length(commander.npc_roll_death_loot()), "The commander drops loot: he took the customs Director's e-gun and baton with him")
	TEST_ASSERT_EQUAL(commander.npc_death_cash, 0, "The commander carries the customs Director's fines")

	// Killed, none of them leaves anything lying where a player could pick it up
	for(var/mob/living/carbon/human/npc/faction_pirate/nt_customs/crew as anything in allocated.Copy())
		if(!istype(crew, /mob/living/carbon/human/npc/faction_pirate/nt_customs))
			continue
		crew.death()
		var/turf/where = get_turf(crew)
		var/obj/item/left_behind = locate(/obj/item) in where
		TEST_ASSERT_NULL(left_behind, "A dead [crew.type] left [left_behind?.type] on the floor")

	// The template: found, hidden, off the shelf, off the catalog, skipped by the template loops, no slot markers
	var/datum/map_template/shuttle/voidcrew/police_cutter/template
	for(var/shuttle_id in SSmapping.shuttle_templates)
		if(istype(SSmapping.shuttle_templates[shuttle_id], /datum/map_template/shuttle/voidcrew/police_cutter))
			template = SSmapping.shuttle_templates[shuttle_id]
			break
	TEST_ASSERT_NOTNULL(template, "The cutter's template isn't registered, so no cutter can ever load")
	TEST_ASSERT(template.player_hidden, "The cutter's template is not player_hidden: the Ship Workshop and the player lists would offer it")
	TEST_ASSERT(!is_player_purchasable_ship(template), "A player can buy the cutter's hull")
	ensure_ship_catalog_initialized()
	TEST_ASSERT(!(template in GLOB.ship_catalog_templates), "The cutter's hull is in the ship catalog")
	TEST_ASSERT(!(template in get_purchasable_ship_templates()), "The cutter's hull is on the shelf")
	TEST_ASSERT_EQUAL(template.abstract, template.type, "The cutter's template is not skipped by the loops over every template (every_ship, the checkpoint tests)")
	TEST_ASSERT(!is_roundstart_eligible_hull(template), "The roundstart fleet can roll the cutter's hull")
	var/map_text = vc_test_file_text(template.mappath)
	TEST_ASSERT(length(map_text), "The cutter's map [template.mappath] is missing")
	TEST_ASSERT(!findtext(map_text, "/obj/modular_map_root/ship_upgrade"), "The cutter's map has a ship-upgrade slot marker, so the preview generator would render it")
	TEST_ASSERT(!findtext(map_text, "/obj/item/"), "The cutter's map places an item: a stripped copy holds none")
	TEST_ASSERT(!findtext(map_text, "/area/shuttle/voidcrew/nt_patrol"), "The cutter's map still refers to the customs corvette's area")

/**
 * The cutter's hull as loaded: nothing lying on a deck, nothing stocked in a locker, no oxygen tanks in the
 * dispenser. Machines keep their own circuit boards and cells; only what a player could carry off counts.
 */
/datum/unit_test/voidcrew_outpost_police_cutter_hull
	priority = TEST_LONGER
	/// The hull the test loaded
	var/obj/structure/overmap/ship/cutter_hull

/datum/unit_test/voidcrew_outpost_police_cutter_hull/Destroy()
	if(!QDELETED(cutter_hull))
		qdel(cutter_hull)
	cutter_hull = null
	return ..()

/datum/unit_test/voidcrew_outpost_police_cutter_hull/Run()
	var/obj/structure/overmap/ship/ship = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/police_cutter)
	TEST_ASSERT_NOTNULL(ship, "The cutter's hull did not load")
	cutter_hull = ship
	var/tiles = 0
	var/lockers = 0
	for(var/turf/tile as anything in ship.shuttle.return_turfs())
		if(!(get_area(tile) in ship.shuttle.shuttle_areas))
			continue
		tiles++
		for(var/obj/item/loose in tile)
			TEST_FAIL("A [loose.type] lies at ([tile.x], [tile.y]) on the cutter's stripped hull")
		for(var/obj/structure/closet/locker in tile)
			lockers++
			TEST_ASSERT(!length(locker.contents), "The [locker.type] at ([tile.x], [tile.y]) on the cutter is stocked with [locker.contents[1]]")
		for(var/obj/structure/tank_dispenser/dispenser in tile)
			TEST_ASSERT_EQUAL(dispenser.oxygentanks + dispenser.plasmatanks, 0, "The tank dispenser on the cutter is stocked")
	TEST_ASSERT(tiles > 100, "Only [tiles] tiles of the cutter were found; the scan isn't seeing the hull")
	TEST_ASSERT(lockers > 0, "The cutter has no lockers to check; has the map lost them?")

/**
 * dispatch_nt_patrol() with the two new arguments builds the police ship and its director; the drug mission's
 * default call still builds the customs ones, with their hold and patience.
 */
/datum/unit_test/voidcrew_outpost_police_cutter_dispatch
	priority = TEST_LONGER
	/// The ship the patrols are sent after
	var/obj/structure/overmap/ship/cutter_quarry
	/// Patrol ships and directors to clean up
	var/list/cutter_made = list()

/datum/unit_test/voidcrew_outpost_police_cutter_dispatch/Destroy()
	for(var/datum/thing as anything in cutter_made)
		if(!QDELETED(thing))
			qdel(thing)
	cutter_made.Cut()
	if(!QDELETED(cutter_quarry))
		qdel(cutter_quarry)
	cutter_quarry = null
	return ..()

/datum/unit_test/voidcrew_outpost_police_cutter_dispatch/Run()
	var/obj/structure/overmap/ship/quarry = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(quarry, "The quarry's hull did not load")
	cutter_quarry = quarry

	// The default call, as the drug mission makes it
	var/datum/nt_patrol_director/customs = dispatch_nt_patrol(quarry, 500, null)
	TEST_ASSERT_NOTNULL(customs, "The default dispatch built no director")
	cutter_made += customs
	var/obj/structure/overmap/ship/npc/pirate/nt_patrol/corvette = customs.patrol_ship
	TEST_ASSERT_NOTNULL(corvette, "The default dispatch built no patrol ship")
	cutter_made += corvette
	TEST_ASSERT_EQUAL(customs.type, /datum/nt_patrol_director, "The default dispatch built a different director")
	TEST_ASSERT_EQUAL(corvette.type, /obj/structure/overmap/ship/npc/pirate/nt_patrol, "The default dispatch built a different ship")
	TEST_ASSERT_EQUAL(corvette.source_template?.type, /datum/map_template/shuttle/voidcrew/nt_patrol, "The default dispatch loaded a different hull")
	TEST_ASSERT_EQUAL(corvette.min_negotiation_demand, 500, "The default dispatch didn't set the fine")
	TEST_ASSERT((corvette.ship_account?.account_balance || 0) > 0, "The customs corvette lost its hold")
	TEST_ASSERT_EQUAL(customs.giveup_time(), 4 MINUTES, "The drug mission's customs patrol changed its patience") // DRUG_COP_GIVEUP_TIME
	TEST_ASSERT(customs.counts_as_targetless(quarry, 30 SECONDS), "The customs patrol stopped counting a targetless tick")
	qdel(corvette)

	// With the cutter's ship and director
	var/datum/nt_patrol_director/police/hunt = dispatch_nt_patrol(quarry, 6000, null, /obj/structure/overmap/ship/npc/pirate/nt_patrol/police, /datum/nt_patrol_director/police)
	TEST_ASSERT_NOTNULL(hunt, "The cutter's dispatch built no director")
	cutter_made += hunt
	var/obj/structure/overmap/ship/npc/pirate/nt_patrol/police/cutter = hunt.patrol_ship
	TEST_ASSERT_NOTNULL(cutter, "The cutter's dispatch built no patrol ship")
	cutter_made += cutter
	TEST_ASSERT_EQUAL(hunt.type, /datum/nt_patrol_director/police, "The cutter's dispatch built a different director")
	TEST_ASSERT_EQUAL(cutter.type, /obj/structure/overmap/ship/npc/pirate/nt_patrol/police, "The cutter's dispatch built a different ship")
	TEST_ASSERT_EQUAL(cutter.source_template?.type, /datum/map_template/shuttle/voidcrew/police_cutter, "The cutter's dispatch loaded a different hull")
	TEST_ASSERT_EQUAL(cutter.min_negotiation_demand, 6000, "The cutter's dispatch didn't set the fine")
	TEST_ASSERT_EQUAL(cutter.max_negotiation_demand, 6000, "The cutter's dispatch didn't pin the fine")
	TEST_ASSERT_EQUAL(cutter.ship_account?.account_balance || 0, 0, "The cutter carries credits") // abuse M9
	TEST_ASSERT_EQUAL(hunt.giveup_time(), 6 MINUTES, "The cutter's patience isn't six minutes") // OUTPOST_POLICE_CUTTER_GIVEUP
	// Without a record of its incident (an admin-built hunt) it still counts every tick against itself
	TEST_ASSERT(hunt.counts_as_targetless(quarry, 30 SECONDS), "A cutter with no incident stopped counting its patience")

/**
 * start_pursuit(): once per incident, the cutter is named for the force that sent it, a payment pardons the crew
 * (at the outpost it was wanted at, or at all of them at five stars), docking time at that outpost is not counted
 * against it up to twenty minutes, and it stands down when the embargo ends.
 */
/datum/unit_test/voidcrew_outpost_police_cutter_pursuit
	priority = TEST_LONGER
	/// The ship being chased
	var/obj/structure/overmap/ship/cutter_quarry
	/// The cutter's ship
	var/obj/structure/overmap/ship/npc/pirate/nt_patrol/cutter_ship

/datum/unit_test/voidcrew_outpost_police_cutter_pursuit/Destroy()
	if(!QDELETED(cutter_ship))
		qdel(cutter_ship)
	cutter_ship = null
	if(!QDELETED(cutter_quarry))
		qdel(cutter_quarry)
	cutter_quarry = null
	return ..()

/datum/unit_test/voidcrew_outpost_police_cutter_pursuit/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost/general)
	var/obj/structure/overmap/trader_outpost/other_outpost = allocate(/obj/structure/overmap/trader_outpost/outfitter)
	var/datum/outpost_police/cutter_test_recorder/police = new(outpost)
	var/datum/outpost_police/cutter_test_recorder/other_police = new(other_outpost)
	QDEL_NULL(outpost.police)
	outpost.police = police
	QDEL_NULL(other_outpost.police)
	other_outpost.police = other_police

	var/obj/structure/overmap/ship/quarry = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(quarry, "The quarry's hull did not load")
	cutter_quarry = quarry
	var/datum/voidcrew_crew_record/crew = quarry.get_crew_record()
	TEST_ASSERT_NOTNULL(crew, "The quarry has no crew record to pardon")
	outpost.embargo_ship(quarry, 15 MINUTES)

	TEST_ASSERT(!police.start_pursuit(quarry, 3, 0), "Three stars sent a cutter")
	TEST_ASSERT(police.start_pursuit(quarry, 4, 1), "Four stars sent no cutter")
	TEST_ASSERT(!police.start_pursuit(quarry, 4, 1), "A second cutter was ordered for the same incident")
	var/datum/outpost_police_pursuit/pursuit = GLOB.outpost_police_pursuits[WEAKREF(quarry)]
	TEST_ASSERT_NOTNULL(pursuit, "Ordering a cutter left no record of the incident")
	TEST_ASSERT_EQUAL(pursuit.fine, 6000, "The four-star fine isn't 6 000") // OUTPOST_POLICE_CUTTER_FINES
	var/waited = 0
	while(pursuit && !QDELETED(pursuit) && pursuit.dispatching && waited < 180)
		sleep(1 SECONDS)
		waited++
	TEST_ASSERT(!QDELETED(pursuit), "The cutter never came, so its order was forgotten")
	var/datum/nt_patrol_director/police/hunt = pursuit.director
	TEST_ASSERT_NOTNULL(hunt, "The order has no hunt")
	cutter_ship = hunt.patrol_ship
	TEST_ASSERT_NOTNULL(cutter_ship, "The hunt has no ship")
	TEST_ASSERT(findtext(cutter_ship.name, police.profile.force_name), "The cutter [cutter_ship.name] isn't named for the force that sent it ([police.profile.force_name])")
	TEST_ASSERT_EQUAL(cutter_ship.min_negotiation_demand, 6000, "The cutter doesn't demand the fine")
	TEST_ASSERT(!police.start_pursuit(quarry, 5, 0), "A cutter on the hunt let a second one be ordered")

	// Docked at an outpost it isn't wanted at, the ship's time counts against the cutter like any other
	quarry.docked = other_outpost
	TEST_ASSERT(hunt.counts_as_targetless(quarry, 30 SECONDS), "Docking time at an outpost the ship isn't wanted at went uncounted")
	// Docked at the outpost it is wanted at, it costs the cutter no patience, for twenty minutes
	quarry.docked = outpost
	for(var/tick in 1 to 40) // OUTPOST_POLICE_CUTTER_LURK_MAX, 20 minutes, in 30 second ticks
		TEST_ASSERT(!hunt.counts_as_targetless(quarry, 30 SECONDS), "Tick [tick] of the first twenty minutes at the wanted outpost counted against the cutter")
	TEST_ASSERT(hunt.counts_as_targetless(quarry, 30 SECONDS), "The cutter's patience stayed frozen past twenty minutes")
	quarry.docked = null

	// The embargo still holds
	TEST_ASSERT(!hunt.embargo_over(), "The cutter thinks the embargo is over while it runs")

	// A payment pardons the crew where it was wanted, and nowhere else at four stars
	hunt.on_negotiation_ended(null, null, TRUE)
	TEST_ASSERT(hunt.fine_paid, "A successful negotiation didn't settle the hunt")
	TEST_ASSERT(crew in police.pardoned, "A payment didn't pardon the crew where it was wanted")
	TEST_ASSERT(!(crew in other_police.pardoned), "A four-star payment pardoned the crew at another outpost")
	// ... and at every outpost at five
	police.pardoned.Cut()
	pursuit.stars = 5
	pursuit.pardon()
	TEST_ASSERT(crew in police.pardoned, "A five-star payment didn't pardon the crew where it was wanted")
	TEST_ASSERT(crew in other_police.pardoned, "A five-star payment didn't pardon the crew at the other outposts")

	// When the embargo ends before anyone pays, the cutter stands down (the pardon above closed the incident, so
	// put the embargo window back as it stood)
	hunt.fine_paid = FALSE
	pursuit.ends_at = world.time + 10 MINUTES
	outpost.embargoed_ships -= quarry
	TEST_ASSERT(hunt.embargo_over(), "The cutter doesn't see the embargo has ended")
	var/obj/structure/overmap/ship/npc/pirate/nt_patrol/leaving = cutter_ship
	hunt.hunt_tick()
	TEST_ASSERT(hunt.standing_down, "The cutter kept hunting after the embargo ended")
	TEST_ASSERT(hunt.hunt_over, "The hunt wasn't closed when the embargo ended")
	TEST_ASSERT(QDELETED(leaving) || leaving.warping_out, "The cutter didn't leave when the embargo ended")
	// The incident's embargo window still covers the ship; once it has run out, a new incident gets a new cutter
	TEST_ASSERT(pursuit.is_current(), "A ship that outlasted the cutter met a second one in the same incident")
	pursuit.ends_at = world.time - 1
	TEST_ASSERT(!pursuit.is_current(), "A new incident is still blocked by the last one")
