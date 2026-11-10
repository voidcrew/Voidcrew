// Tutorial checklist (voidcrew/modules/tutorials). Each test drives the real hooked proc and
// reads SSvc_tutorials.progress. Fork defines are included after the test harness, so step
// keys are literals here; the catalog test checks every TUTORIAL_STEP_* a hook uses against
// voidcrew/_DEFINES/tutorials.dm and the live catalog.
// Credits INSERT into tutorial_completions only when a database is connected; the fake ckey
// makes those rows harmless and the unique index keeps them to one per key.

#define TUTORIAL_TEST_CKEY "tutorialtest"

/// Ship interiors come from the zone teleport fixture (area + registered docking port).
/datum/unit_test/voidcrew_tutorials
	parent_type = /datum/unit_test/voidcrew_zone_teleport
	abstract_type = /datum/unit_test/voidcrew_tutorials
	var/list/crew_records = list()
	var/list/keyed_players = list()

/datum/unit_test/voidcrew_tutorials/New()
	. = ..()
	// The fixture's Destroy restores this; it never set it itself.
	zones_were_active = SSovermap_zones.zones_active
	SSvc_tutorials.progress -= TUTORIAL_TEST_CKEY

/datum/unit_test/voidcrew_tutorials/Destroy()
	SSvc_tutorials.progress -= TUTORIAL_TEST_CKEY
	GLOB.tutorial_checklist_hidden -= TUTORIAL_TEST_CKEY
	// A deleted mob that still holds a key with no client is reported as a stuck player.
	for(var/mob/player as anything in keyed_players)
		player.key = null
	QDEL_LIST(crew_records)
	return ..()

/// A keyed player body. The hot-path hooks bail on mobs without a ckey.
/datum/unit_test/voidcrew_tutorials/proc/make_player(turf/location = run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, location)
	player.mind_initialize()
	allocated += player.mind
	player.mind.key = TUTORIAL_TEST_CKEY
	player.key = TUTORIAL_TEST_CKEY
	keyed_players += player
	return player

/// A ship whose interior is ship_turf, crewed by the given player.
/datum/unit_test/voidcrew_tutorials/proc/make_crewed_ship(turf/ship_turf, mob/living/player)
	var/obj/structure/overmap/ship/ship = make_ship(ship_turf, run_loc_floor_top_right)
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	ship.ship_team = team
	if(player)
		team.join_member(player.mind)
	crew_records |= ship.get_crew_record()
	return ship

/datum/unit_test/voidcrew_tutorials/proc/done(key)
	return SSvc_tutorials.has_key(TUTORIAL_TEST_CKEY, key)

/datum/unit_test/voidcrew_tutorials/proc/reset_progress()
	SSvc_tutorials.progress -= TUTORIAL_TEST_CKEY

/// Swaps one turf into a fresh area; the fixture restores it.
/datum/unit_test/voidcrew_tutorials/proc/make_area(turf/location, area_type)
	var/area/new_area = new area_type
	ship_areas += new_area
	original_areas[location] = get_area(location)
	location.change_area(get_area(location), new_area)
	return new_area

/// Keys unique and short, under "vc/", each item has a category, an intro and a counted step,
/// route steps come in two or more routes, and every key a hook credits is a step in the catalog.
/datum/unit_test/voidcrew_tutorials/catalog/Run()
	SSvc_tutorials.build_catalog()
	TEST_ASSERT_EQUAL(length(SSvc_tutorials.items), 17, "The checklist does not have its seventeen items")
	var/list/seen = list()
	for(var/datum/vc_tutorial/item as anything in SSvc_tutorials.items)
		check_key(item.id, seen)
		TEST_ASSERT(item.name, "[item.id] has no name")
		TEST_ASSERT(item.category && GLOB.tutorial_categories[item.category], "[item.id] has no panel category")
		TEST_ASSERT(istext(item.intro) && length(trimtext(item.intro)), "[item.id] has no intro")
		var/counted = 0
		var/list/routes = list()
		for(var/datum/vc_tutorial_step/step as anything in item.steps)
			check_key(step.key, seen)
			TEST_ASSERT(findtext(step.key, "[item.id]/") == 1, "[step.key] is not under its item [item.id]")
			TEST_ASSERT(step.name && step.text, "[step.key] has no name or text")
			if(step.route)
				TEST_ASSERT(step.route_name, "[step.key] has a route with no name")
				routes |= step.route
			if(!step.optional)
				counted++
		TEST_ASSERT(counted, "[item.id] has no step that counts")
		TEST_ASSERT(!length(routes) || length(routes) >= 2, "[item.id] has route steps but only one route")

	var/list/define_values = list()
	var/defines = file2text("voidcrew/_DEFINES/tutorials.dm")
	var/regex/define_regex = regex("#define (TUTORIAL_STEP_\[A-Z_\]+) \"(\[^\"\]+)\"", "g")
	while(define_regex.Find(defines))
		define_values[define_regex.group[1]] = define_regex.group[2]
	TEST_ASSERT(length(define_values) >= 30, "Could not read the step defines")
	var/regex/use_regex = regex("TUTORIAL_STEP_\[A-Z_\]+", "g")
	var/files_read = 0
	for(var/file_name in flist("voidcrew/modules/tutorials/"))
		if(!findtext(file_name, ".dm", -3))
			continue
		files_read++
		var/source = file2text("voidcrew/modules/tutorials/[file_name]")
		while(use_regex.Find(source))
			var/define_name = use_regex.match
			var/key = define_values[define_name]
			TEST_ASSERT(key, "[file_name] uses [define_name], which is not defined")
			TEST_ASSERT(SSvc_tutorials.steps_by_key[key], "[file_name] credits [key], which no checklist step owns")
	TEST_ASSERT(files_read >= 10, "Could not read the tutorial hook files")

/datum/unit_test/voidcrew_tutorials/catalog/proc/check_key(key, list/seen)
	TEST_ASSERT(istext(key) && length(key), "A checklist key is empty")
	TEST_ASSERT(length(key) <= 64, "[key] is longer than the 64 characters the table holds")
	TEST_ASSERT(findtext(key, "vc/") == 1, "[key] does not start with vc/")
	TEST_ASSERT(!seen[key], "[key] is used twice")
	seen[key] = TRUE

/// A two-route item built outside the catalog (no id, so build_catalog skips the type).
/datum/vc_tutorial/route_test
	name = "Route test"
	steps = list(
		/datum/vc_tutorial_step/route_test_shared,
		/datum/vc_tutorial_step/route_test_a1,
		/datum/vc_tutorial_step/route_test_a2,
		/datum/vc_tutorial_step/route_test_b1,
	)

/datum/vc_tutorial_step/route_test_shared
	key = "vc/route_test/shared"
	name = "Shared"
	text = "Shared step."

/datum/vc_tutorial_step/route_test_a1
	key = "vc/route_test/a1"
	name = "A1"
	text = "Route A, first step."
	route = "a"
	route_name = "Route A"

/datum/vc_tutorial_step/route_test_a2
	key = "vc/route_test/a2"
	name = "A2"
	text = "Route A, second step."
	route = "a"
	route_name = "Route A"

/datum/vc_tutorial_step/route_test_b1
	key = "vc/route_test/b1"
	name = "B1"
	text = "Route B."
	route = "b"
	route_name = "Route B"

/// Finishing every step of route A excuses route B and completes the item.
/datum/unit_test/voidcrew_tutorials/routes
	var/datum/vc_tutorial/route_test/test_item

/datum/unit_test/voidcrew_tutorials/routes/Destroy()
	if(test_item)
		for(var/datum/vc_tutorial_step/step as anything in test_item.steps)
			SSvc_tutorials.steps_by_key -= step.key
			SSvc_tutorials.item_by_step -= step.key
		QDEL_LIST(test_item.steps)
		QDEL_NULL(test_item)
	return ..()

/datum/unit_test/voidcrew_tutorials/routes/Run()
	SSvc_tutorials.build_catalog()
	test_item = new
	test_item.id = "vc/route_test"
	var/list/step_instances = list()
	for(var/step_type in test_item.steps)
		var/datum/vc_tutorial_step/step = new step_type
		step_instances += step
		SSvc_tutorials.steps_by_key[step.key] = step
		SSvc_tutorials.item_by_step[step.key] = test_item
	test_item.steps = step_instances
	var/datum/vc_tutorial_step/a1 = step_instances[2]
	var/datum/vc_tutorial_step/b1 = step_instances[4]
	var/mob/living/carbon/human/player = make_player()

	tutorial_credit(player, "vc/route_test/shared")
	tutorial_credit(player, "vc/route_test/a1")
	TEST_ASSERT(!b1.excused(player), "Route B was excused with route A half done")
	TEST_ASSERT(!SSvc_tutorials.item_complete(test_item, TUTORIAL_TEST_CKEY, player), "The item completed with route A half done")
	tutorial_credit(player, "vc/route_test/a2")
	TEST_ASSERT(b1.excused(player), "Finishing route A did not excuse route B")
	TEST_ASSERT(b1.route_excused(TUTORIAL_TEST_CKEY), "Finishing route A did not excuse route B by ckey")
	TEST_ASSERT(!a1.excused(player), "The finished route excused itself")
	TEST_ASSERT(SSvc_tutorials.item_complete(test_item, TUTORIAL_TEST_CKEY, null), "Finishing route A did not complete the item")
	TEST_ASSERT(done("vc/route_test"), "Finishing route A did not save the item key")
	TEST_ASSERT(!done("vc/route_test/b1"), "Route B's step was marked done")

/// The suggested item is the first incomplete one in panel order with a step the viewer
/// can do now: steps marked unavailable or excused don't count.
/datum/unit_test/voidcrew_tutorials/suggested/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/mob/living/carbon/human/player = make_player(deck)
	make_crewed_ship(deck, player)
	SSvc_tutorials.build_catalog()
	tutorial_credit(player, "vc/ship/manage")
	TEST_ASSERT_EQUAL(SSvc_tutorials.suggested_item(TUTORIAL_TEST_CKEY, player), "vc/ship", "A new player was not pointed at Your ship")
	// What's left of Your ship needs a helm, and this hull has none.
	tutorial_credit(player, "vc/ship/search")
	TEST_ASSERT_EQUAL(SSvc_tutorials.suggested_item(TUTORIAL_TEST_CKEY, player), "vc/power", "Steps marked unavailable still held the suggestion")
	for(var/datum/vc_tutorial/item as anything in SSvc_tutorials.items)
		SSvc_tutorials.progress[TUTORIAL_TEST_CKEY][item.id] = TRUE
	TEST_ASSERT_NULL(SSvc_tutorials.suggested_item(TUTORIAL_TEST_CKEY, player), "Something was suggested with every item done")

/// Opening a locker aboard counts; one off the ship doesn't.
/datum/unit_test/voidcrew_tutorials/ship_search/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/turf/outside = get_step(deck, EAST)
	var/mob/living/carbon/human/player = make_player(outside)
	make_crewed_ship(deck, player)
	var/obj/structure/closet/off_ship = allocate(/obj/structure/closet, outside)
	TEST_ASSERT(off_ship.open(player), "The off-ship locker would not open")
	TEST_ASSERT(!done("vc/ship/search"), "A locker off the ship counted as searching the ship")
	player.forceMove(deck)
	var/obj/structure/closet/aboard = allocate(/obj/structure/closet, deck)
	TEST_ASSERT(aboard.open(player), "The locker aboard would not open")
	TEST_ASSERT(done("vc/ship/search"), "Opening a locker aboard was not credited")

/// An abandoned cache opened off-ship counts.
/datum/unit_test/voidcrew_tutorials/ruin_cache/Run()
	var/mob/living/carbon/human/player = make_player()
	// A crate won't open with someone standing on it.
	var/obj/structure/closet/crate/zone_loot/cache = allocate(/obj/structure/closet/crate/zone_loot, get_step(run_loc_floor_bottom_left, EAST))
	TEST_ASSERT(cache.open(player), "The cache would not open")
	TEST_ASSERT(done("vc/ruin/cache"), "Opening an abandoned cache was not credited")

/// Walking into a ruin, and into a vestige (which is also a ruin).
/datum/unit_test/voidcrew_tutorials/ruin_entry/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/turf/ruin_turf = get_step(start, EAST)
	var/turf/vestige_turf = get_step(ruin_turf, EAST)
	make_area(ruin_turf, /area/ruin)
	make_area(vestige_turf, /area/ruin/space/has_grav/vestige)
	var/mob/living/carbon/human/player = make_player(start)
	player.forceMove(ruin_turf)
	TEST_ASSERT(done("vc/ruin/find"), "Entering a ruin was not credited")
	TEST_ASSERT(!done("vc/vestige/find"), "A plain ruin counted as a vestige")
	reset_progress()
	player.forceMove(vestige_turf)
	TEST_ASSERT(done("vc/vestige/find"), "Entering a vestige was not credited")
	TEST_ASSERT(done("vc/ruin/find"), "A vestige did not count as a ruin")

/datum/unit_test/voidcrew_tutorials/surgery/Run()
	var/mob/living/carbon/human/surgeon = make_player()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/surgery/operation = new /datum/surgery(patient, BODY_ZONE_CHEST, patient.get_bodypart(BODY_ZONE_CHEST))
	operation.complete(surgeon)
	TEST_ASSERT(QDELETED(operation), "The finished operation was not cleaned up")
	TEST_ASSERT(done("vc/surgery/finish"), "Finishing an operation was not credited")

/// A dissection that pays research counts; reopening a spent body doesn't.
/datum/unit_test/voidcrew_tutorials/dissection/Run()
	var/mob/living/carbon/human/surgeon = make_player()
	var/mob/living/carbon/human/corpse = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))
	corpse.death()
	var/datum/surgery_step/experimental_dissection/dissect = allocate(/datum/surgery_step/experimental_dissection)
	dissect.success(surgeon, corpse, BODY_ZONE_CHEST, null, null)
	TEST_ASSERT(corpse.dissection_points_paid > 0, "The dissection paid nothing")
	TEST_ASSERT(done("vc/surgery/dissect"), "A paying dissection was not credited")
	reset_progress()
	dissect.success(surgeon, corpse, BODY_ZONE_CHEST, null, null)
	TEST_ASSERT(!done("vc/surgery/dissect"), "Re-dissecting a spent body was credited")
	for(var/obj/item/research_notes/notes in surgeon.loc)
		qdel(notes)
	for(var/obj/item/research_notes/notes in surgeon.held_items)
		qdel(notes)

/// Survey console and Shuttle Warfare Systems credit the crew of the ship holding the server.
/datum/unit_test/voidcrew_tutorials/research_nodes/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/mob/living/carbon/human/player = make_player(get_step(deck, EAST))
	make_crewed_ship(deck, player)
	var/datum/techweb/web = allocate(/datum/techweb)
	var/obj/machinery/rnd/server/server = allocate(/obj/machinery/rnd/server, deck)
	web.techweb_servers |= server
	// TECHWEB_NODE_SURVEY_CONSOLE and TECHWEB_NODE_SHIP_COMBAT
	TEST_ASSERT(web.research_node(SSresearch.techweb_node_by_id("survey_console"), TRUE, FALSE, FALSE), "The survey console node could not be researched")
	TEST_ASSERT(done("vc/surveys/node"), "Researching the survey console was not credited to the crew")
	TEST_ASSERT(!done("vc/zones/warfare"), "The survey node counted as warfare research")
	TEST_ASSERT(web.research_node(SSresearch.techweb_node_by_id("ship_combat"), TRUE, FALSE, FALSE), "The warfare node could not be researched")
	TEST_ASSERT(done("vc/zones/warfare"), "Researching Shuttle Warfare Systems was not credited to the crew")
	web.techweb_servers -= server

/// Buying chrome at a trader counts for trade and for cyberware.
/datum/unit_test/voidcrew_tutorials/purchase/Run()
	var/mob/living/carbon/human/player = make_player()
	var/obj/structure/overmap/ship/ship = make_crewed_ship(get_step(run_loc_floor_bottom_left, EAST), player)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Tutorial test", null, 1, FALSE)
	account.account_balance = 1000
	ship.ship_account = account
	var/datum/shop_sku/sku = allocate(/datum/shop_sku)
	sku.item_path = /obj/item/organ/cyberimp/cyberware/shock_coils
	sku.price_credits = 500
	sku.stock = 1
	TEST_ASSERT(sku.try_purchase(player, null), "The stocked general SKU would not sell")
	TEST_ASSERT_EQUAL(account.account_balance, 500, "The purchase charged the wrong amount")
	TEST_ASSERT(done("vc/trade/buy"), "Buying from a trader was not credited")
	TEST_ASSERT(done("vc/chrome/buy"), "Buying chrome was not credited")
	ship.ship_account = null
	for(var/obj/item/organ/cyberimp/bought in player.held_items)
		qdel(bought)
	for(var/obj/item/organ/cyberimp/bought in player.loc)
		qdel(bought)

/// A real install counts for the body that gets it; a special (spawn/clone) insert doesn't.
/datum/unit_test/voidcrew_tutorials/chrome_install/Run()
	var/mob/living/carbon/human/player = make_player()
	var/obj/item/organ/cyberimp/chest/nutriment/silent = allocate(/obj/item/organ/cyberimp/chest/nutriment)
	silent.Insert(player, TRUE)
	TEST_ASSERT(silent.owner == player, "The special insert failed")
	TEST_ASSERT(!done("vc/chrome/install"), "A special insert was credited")
	silent.Remove(player, TRUE)
	var/obj/item/organ/cyberimp/chest/nutriment/implant = allocate(/obj/item/organ/cyberimp/chest/nutriment)
	implant.Insert(player)
	TEST_ASSERT(implant.owner == player, "The install failed")
	TEST_ASSERT(done("vc/chrome/install"), "Installing an implant was not credited")

/// A chrome finisher that lands counts; one called off, or a boss-style finisher, doesn't.
/datum/unit_test/voidcrew_tutorials/chrome_execute/Run()
	var/mob/living/carbon/human/player = make_player()
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))

	var/datum/hv_finisher/chrome/called_off = new(player, victim)
	called_off.running = TRUE
	called_off.stop(HV_FINISHER_LOST_GRIP)
	TEST_ASSERT(!done("vc/chrome/execute"), "A called-off chrome finisher was credited")

	var/datum/hv_finisher/boss_style = new(player, victim)
	boss_style.running = TRUE
	boss_style.completed = TRUE
	boss_style.stop(HV_FINISHER_DONE)
	qdel(boss_style)
	TEST_ASSERT(!done("vc/chrome/execute"), "A non-chrome finisher was credited")

	var/datum/hv_finisher/chrome/finished = new(player, victim)
	finished.running = TRUE
	finished.completed = TRUE
	finished.stop(HV_FINISHER_DONE)
	TEST_ASSERT(done("vc/chrome/execute"), "A finished chrome execution was not credited")

	reset_progress()
	var/datum/hv_finisher/mantis_scissor/scissor = new(player, victim)
	scissor.running = TRUE
	scissor.completed = TRUE
	scissor.stop(HV_FINISHER_DONE)
	qdel(scissor)
	TEST_ASSERT(done("vc/chrome/execute"), "A finished Mantis scissor was not credited")

/// Redeeming research notes at an R&D console.
/datum/unit_test/voidcrew_tutorials/research_notes/Run()
	var/mob/living/carbon/human/player = make_player()
	var/obj/machinery/computer/rdconsole/console = allocate(/obj/machinery/computer/rdconsole, get_step(run_loc_floor_bottom_left, EAST))
	var/datum/techweb/web = allocate(/datum/techweb)
	console.stored_research = web
	var/obj/item/research_notes/notes = allocate(/obj/item/research_notes, run_loc_floor_bottom_left)
	notes.value = 10
	console.attackby(notes, player)
	TEST_ASSERT(QDELETED(notes), "The console did not take the notes")
	TEST_ASSERT(done("vc/surveys/notes"), "Turning in research notes was not credited")
	console.stored_research = null

/// R&D setup: kit, built ship server, disk, multitool, built console and protolathe, then links.
/// The link step waits until both the console and the protolathe are on the server's web.
/datum/unit_test/voidcrew_tutorials/rnd_setup/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/mob/living/carbon/human/player = make_player(deck)
	var/obj/structure/overmap/ship/ship = make_crewed_ship(deck, player)

	var/obj/item/storage/box/rndboards/all/kit = allocate(/obj/item/storage/box/rndboards/all, deck)
	kit.pickup(player)
	TEST_ASSERT(done("vc/research/kit"), "Picking up the R&D kit was not credited")

	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship, deck)
	TEST_ASSERT(!done("vc/research/server"), "A spawned server counted as building one")
	server.on_construction(player)
	TEST_ASSERT(done("vc/research/server"), "Building the ship server was not credited")

	var/obj/item/computer_disk/ship_disk/disk = allocate(/obj/item/computer_disk/ship_disk, deck)
	server.attacked_by(disk, player)
	TEST_ASSERT_EQUAL(server.source_code_hdd, disk, "The server did not take the disk")
	TEST_ASSERT(done("vc/research/disk"), "Adding the ship disk was not credited")

	var/obj/item/multitool/tool = allocate(/obj/item/multitool, deck)
	server.multitool_act(player, tool)
	TEST_ASSERT_EQUAL(tool.buffer, disk.stored_research, "The multitool did not store the server's techweb")
	TEST_ASSERT(done("vc/research/multitool"), "Multitooling the server was not credited")

	var/obj/machinery/computer/rdconsole/console = allocate(/obj/machinery/computer/rdconsole, deck)
	console.on_construction(player)
	TEST_ASSERT(done("vc/research/console"), "Building the R&D console was not credited")
	var/obj/machinery/rnd/production/protolathe/lathe = allocate(/obj/machinery/rnd/production/protolathe, deck)
	lathe.on_construction(player)
	TEST_ASSERT(done("vc/research/protolathe"), "Building the protolathe was not credited")
	console.unsync_research_servers()
	lathe.unsync_research_servers()

	console.multitool_act(player, tool)
	TEST_ASSERT_EQUAL(console.stored_research, disk.stored_research, "The console did not link to the server")
	TEST_ASSERT(!done("vc/research/link"), "Linking only the console counted as linking everything")
	TEST_ASSERT(!tutorial_ship_rnd_linked(ship), "The ship counted as linked with the protolathe unlinked")
	lathe.multitool_act(player, tool)
	TEST_ASSERT_EQUAL(lathe.stored_research, disk.stored_research, "The protolathe did not link to the server")
	TEST_ASSERT(done("vc/research/link"), "Linking the console and protolathe was not credited")
	TEST_ASSERT(done("vc/research"), "Finishing every R&D step did not complete the item")
	console.unsync_research_servers()
	lathe.unsync_research_servers()

/// Starting a PACMAN counts; stopping one doesn't.
/datum/unit_test/voidcrew_tutorials/generator/Run()
	var/mob/living/carbon/human/player = make_player()
	var/obj/machinery/power/port_gen/pacman/generator = allocate(/obj/machinery/power/port_gen/pacman, get_step(run_loc_floor_bottom_left, EAST))
	generator.sheets = 50
	var/datum/tgui/generator_ui = allocate(/datum/tgui, player, generator, "PortableGenerator")
	generator.ui_act("toggle_power", list(), generator_ui, generator_ui.state)
	TEST_ASSERT(generator.active, "The generator did not start")
	TEST_ASSERT(done("vc/power/generator"), "Starting the generator was not credited")
	reset_progress()
	generator.ui_act("toggle_power", list(), generator_ui, generator_ui.state)
	TEST_ASSERT(!generator.active, "The generator did not stop")
	TEST_ASSERT(!done("vc/power/generator"), "Stopping the generator was credited")

/// Dock and undock credit crew aboard; a ship with no berth doesn't count as docked.
/datum/unit_test/voidcrew_tutorials/dock_undock/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/mob/living/carbon/human/player = make_player(deck)
	var/obj/structure/overmap/ship/ship = make_crewed_ship(deck, player)
	SEND_SIGNAL(ship, "voidcrew_ship_docked") // COMSIG_VOIDCREW_SHIP_DOCKED
	TEST_ASSERT(!done("vc/ship/dock"), "A rebuild with no berth counted as docking")
	var/obj/structure/overmap/ship/berth = allocate(/obj/structure/overmap/ship, get_step(run_loc_floor_top_right, WEST))
	ship.docked = berth
	SEND_SIGNAL(ship, "voidcrew_ship_docked") // COMSIG_VOIDCREW_SHIP_DOCKED
	ship.docked = null
	TEST_ASSERT(done("vc/ship/dock"), "Docking was not credited to the crew aboard")
	TEST_ASSERT(!done("vc/ruin/land"), "Docking at a ship counted as landing on a planet")
	SEND_SIGNAL(ship, "voidcrew_ship_undocked") // COMSIG_VOIDCREW_SHIP_UNDOCKED
	TEST_ASSERT(done("vc/ship/undock"), "Undocking was not credited to the crew aboard")
	TEST_ASSERT(!done("vc/trade/travel"), "Docking at a ship counted as reaching an outpost")
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost, get_step(run_loc_floor_top_right, WEST))
	ship.docked = outpost
	SEND_SIGNAL(ship, "voidcrew_ship_docked") // COMSIG_VOIDCREW_SHIP_DOCKED
	ship.docked = null
	TEST_ASSERT(done("vc/trade/travel"), "Docking at a trader outpost was not credited to the crew aboard")

/// Pact, completed trial and claimed boon.
/datum/unit_test/voidcrew_tutorials/vestige/Run()
	var/mob/living/carbon/human/player = make_player()
	var/datum/mind/keeper = player.mind
	var/datum/vestige_trial/trial = allocate(/datum/vestige_trial, keeper, "Test patron", list())
	keeper.active_vestige_trial = trial
	trial.begin(player)
	TEST_ASSERT(done("vc/vestige/pact"), "Making a pact was not credited")
	trial.complete()
	TEST_ASSERT(QDELETED(trial), "The completed trial was not cleaned up")
	TEST_ASSERT(done("vc/vestige/trial"), "Completing a trial was not credited")
	reset_progress()
	trial.complete()
	TEST_ASSERT(!done("vc/vestige/trial"), "A stale completion was credited")

	var/datum/vestige_record/record = get_vestige_record(keeper, create = TRUE)
	var/list/candidates = list(/datum/vestige_boon/unit_test_a)
	record.pending_candidates = candidates.Copy()
	var/datum/action/vestige_reward/reward = allocate(/datum/action/vestige_reward, keeper, candidates, "Test patron")
	reward.Grant(player)
	reward.claim(player, keeper, /datum/vestige_boon/unit_test_a)
	TEST_ASSERT(/datum/vestige_boon/unit_test_a in keeper.vestige_boons, "The boon was not paid")
	TEST_ASSERT(done("vc/vestige/claim"), "Claiming a boon was not credited")
	GLOB.vestige_records -= ckey(keeper.key)
	qdel(record)

/// A smart locker counts once a player finishes building one and once they put something in it.
/// Shelf assembly and crate loading wait in do_after, so they are not driven here.
/datum/unit_test/voidcrew_tutorials/smart_locker/Run()
	var/mob/living/carbon/human/player = make_player()
	var/obj/machinery/smartfridge/storage/locker = allocate(/obj/machinery/smartfridge/storage, get_step(run_loc_floor_bottom_left, EAST))
	TEST_ASSERT(!done("vc/storage/locker"), "A spawned smart locker counted as building one")
	locker.on_construction(player)
	TEST_ASSERT(done("vc/storage/locker"), "Building a smart locker was not credited")
	var/obj/item/wrench/stored = allocate(/obj/item/wrench)
	TEST_ASSERT(player.put_in_hands(stored), "The player could not hold the item")
	TEST_ASSERT(locker.load(stored, player), "The smart locker refused the item")
	TEST_ASSERT_EQUAL(stored.loc, locker, "The item did not go into the smart locker")
	TEST_ASSERT(done("vc/storage/store"), "Storing an item in a smart locker was not credited")

/// Researching Shuttle Repair Swarm credits the crew whose techweb did it.
/datum/unit_test/voidcrew_tutorials/repair_swarm_research/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/mob/living/carbon/human/player = make_player(get_step(deck, EAST))
	make_crewed_ship(deck, player)
	var/datum/techweb/web = allocate(/datum/techweb)
	var/obj/machinery/rnd/server/server = allocate(/obj/machinery/rnd/server, deck)
	web.techweb_servers |= server
	// TECHWEB_NODE_SHIP_REPAIR_SWARM
	TEST_ASSERT(web.research_node(SSresearch.techweb_node_by_id("ship_repair_swarm"), TRUE, FALSE, FALSE), "The repair swarm node could not be researched")
	TEST_ASSERT(done("vc/repair_drones/research"), "Researching Shuttle Repair Swarm was not credited to the crew")
	web.techweb_servers -= server

/// A save being used, from the lobby or a shipyard console, credits whoever saved it.
/datum/unit_test/voidcrew_tutorials/ship_save_load/Run()
	var/datum/ship_save_store/old_store = GLOB.ship_save_store
	var/datum/ship_saves/old_saves = GLOB.ship_saves
	var/datum/ship_economy_db/old_economy = GLOB.ship_economy_db
	var/datum/ship_save_store/fake/store = new
	store.saved["[TUTORIAL_TEST_CKEY]|1"] = list("meta" = list(), "payload" = null)
	GLOB.ship_save_store = store
	GLOB.ship_saves = new /datum/ship_saves
	GLOB.ship_economy_db = new /datum/ship_economy_db/fake
	GLOB.ship_saves.spend(TUTORIAL_TEST_CKEY, 1)
	var/credited = done("vc/ship_save/load")
	var/removed = !store.saved["[TUTORIAL_TEST_CKEY]|1"]
	qdel(GLOB.ship_saves)
	qdel(GLOB.ship_economy_db)
	qdel(store)
	GLOB.ship_save_store = old_store
	GLOB.ship_saves = old_saves
	GLOB.ship_economy_db = old_economy
	TEST_ASSERT(removed, "The spent save was not removed")
	TEST_ASSERT(credited, "Using a saved ship was not credited")

/// Taking a contract credits whoever accepted it; work and turn-in credit the crew.
/datum/unit_test/voidcrew_tutorials_contract
	parent_type = /datum/unit_test/voidcrew_zone_missions

/datum/unit_test/voidcrew_tutorials_contract
	var/mob/keyed_member

/datum/unit_test/voidcrew_tutorials_contract/Destroy()
	SSvc_tutorials.progress -= TUTORIAL_TEST_CKEY
	keyed_member?.key = null
	return ..()

/datum/unit_test/voidcrew_tutorials_contract/Run()
	SSvc_tutorials.progress -= TUTORIAL_TEST_CKEY
	var/obj/structure/overmap/ship/ship = make_ship(0, FALSE)
	// The fixture's bare account has no job, so it can't unregister itself on delete.
	var/datum/bank_account/fixture_account = ship.ship_account
	SSeconomy.bank_accounts_by_id -= "[fixture_account.account_id]"
	fixture_account.add_to_accounts = FALSE
	var/mob/living/carbon/human/member = allocate(/mob/living/carbon/human/consistent)
	member.mind_initialize()
	allocated += member.mind
	member.mind.key = TUTORIAL_TEST_CKEY
	member.key = TUTORIAL_TEST_CKEY
	keyed_member = member
	ship.enlist_crewmember(member)
	var/datum/mission/mission = allocate(/datum/mission/zone_missions_test, null, 1)
	ship.available_missions += mission
	usr = member
	TEST_ASSERT_EQUAL(ship.accept_mission(mission), TRUE, "The contract was refused")
	usr = null
	TEST_ASSERT(SSvc_tutorials.has_key(TUTORIAL_TEST_CKEY, "vc/contract/take"), "Taking a contract was not credited")
	TEST_ASSERT(!SSvc_tutorials.has_key(TUTORIAL_TEST_CKEY, "vc/contract/turn_in"), "Taking a contract counted as turning it in")
	TEST_ASSERT(mission.turn_in(run_loc_floor_bottom_left, null), "The contract did not settle")
	TEST_ASSERT(SSvc_tutorials.has_key(TUTORIAL_TEST_CKEY, "vc/contract/work"), "Doing the contract was not credited to the crew")
	TEST_ASSERT(SSvc_tutorials.has_key(TUTORIAL_TEST_CKEY, "vc/contract/turn_in"), "Turning in the contract was not credited to the crew")
	TEST_ASSERT(SSvc_tutorials.has_key(TUTORIAL_TEST_CKEY, "vc/contract"), "Finishing every contract step did not complete the item")

/// A hostile NPC hull with no AI and no spawner record. The overrides keep a hull failure
/// from crash-landing a ship that has no interior.
/obj/structure/overmap/ship/npc/tutorial_test
	name = "tutorial test pirate"
	spawner_resolved = TRUE

/obj/structure/overmap/ship/npc/tutorial_test/crash_land()
	return

/obj/structure/overmap/ship/npc/tutorial_test/get_random_ship_turf()
	return null

/obj/structure/overmap/ship/npc/tutorial_test/start_critical_alert()
	return

/obj/structure/overmap/ship/npc/tutorial_test/stop_critical_alert()
	return

/// A player hull whose ship-to-ship dock always succeeds without moving anything.
/obj/structure/overmap/ship/tutorial_dock_test

/obj/structure/overmap/ship/tutorial_dock_test/dock_ships_directly(obj/structure/overmap/ship/other_ship, mob/user, instant = FALSE)
	return null

/// Stands in for a missile in flight; gone a moment after the launcher's delayed spawn.
/obj/effect/temp_visual/tutorial_test_missile
	duration = 1

/// A launcher that can always fire, with a harmless missile loaded.
/obj/machinery/ship_combat/missile_launcher/tutorial_test

/obj/machinery/ship_combat/missile_launcher/tutorial_test/can_fire()
	return TRUE

/obj/machinery/ship_combat/missile_launcher/tutorial_test/get_missile_spawn_turf(turf/target, obj/structure/overmap/tgt_ship, approach_dir = null)
	return target

/// Like make_crewed_ship(), but with a chosen hull type.
/datum/unit_test/voidcrew_tutorials/proc/make_crewed_ship_of_type(turf/ship_turf, mob/living/player, ship_type)
	var/area/shuttle/voidcrew/ship_area = new
	ship_areas += ship_area
	original_areas[ship_turf] = get_area(ship_turf)
	ship_turf.change_area(get_area(ship_turf), ship_area)
	var/obj/docking_port/mobile/voidcrew/port = new(ship_turf)
	port.shuttle_areas[ship_area] = TRUE
	port.register()
	ship_area.shuttle_port = port
	var/obj/structure/overmap/ship/ship = allocate(ship_type, run_loc_floor_top_right)
	ship.shuttle = port
	port.current_ship = ship
	ships += ship
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	ship.ship_team = team
	team.join_member(player.mind)
	crew_records |= ship.get_crew_record()
	return ship

/// Building a ship weapon from a frame credits the builder; a mapped one doesn't.
/datum/unit_test/voidcrew_tutorials/weapon_build/Run()
	var/mob/living/carbon/human/player = make_player()
	var/obj/machinery/ship_combat/interdictor/interdictor = allocate(/obj/machinery/ship_combat/interdictor, get_step(run_loc_floor_bottom_left, EAST))
	TEST_ASSERT(!done("vc/weapons/interdictor"), "A spawned interdictor counted as building one")
	interdictor.on_construction(player)
	TEST_ASSERT(done("vc/weapons/interdictor"), "Building an interdictor was not credited")
	TEST_ASSERT(!done("vc/weapons/shield"), "Building an interdictor counted as a shield generator")

/// Sealing a loaded missile credits whoever armed it; unsealing it doesn't.
/datum/unit_test/voidcrew_tutorials/missile_arm/Run()
	var/mob/living/carbon/human/player = make_player()
	var/obj/structure/ship_missile/missile = allocate(/obj/structure/ship_missile, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/screwdriver/tool = allocate(/obj/item/screwdriver)
	TEST_ASSERT(player.put_in_active_hand(tool), "The player could not hold the screwdriver")
	missile.construction_state = 3 // MISSILE_STATE_PAYLOAD
	missile.attackby(tool, player)
	TEST_ASSERT_EQUAL(missile.construction_state, 4, "The screwdriver did not arm the missile") // MISSILE_STATE_ARMED
	TEST_ASSERT(done("vc/weapons/missile"), "Arming a missile was not credited")
	reset_progress()
	missile.attackby(tool, player)
	TEST_ASSERT_EQUAL(missile.construction_state, 3, "The screwdriver did not unseal the missile") // MISSILE_STATE_PAYLOAD
	TEST_ASSERT(!done("vc/weapons/missile"), "Unsealing a missile was credited")

/// A launch at a ship credits the player who fired; an NPC launch has no player to credit.
/datum/unit_test/voidcrew_tutorials/missile_fire/Run()
	var/mob/living/carbon/human/player = make_player()
	var/obj/machinery/ship_combat/missile_launcher/tutorial_test/launcher = allocate(/obj/machinery/ship_combat/missile_launcher/tutorial_test, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/structure/overmap/ship/target_ship = allocate(/obj/structure/overmap/ship, get_step(run_loc_floor_top_right, WEST))
	var/turf/target_turf = get_step(run_loc_floor_top_right, SOUTH)
	launcher.loaded_missile = list("effect_type" = /obj/effect/temp_visual/tutorial_test_missile)
	TEST_ASSERT(launcher.fire(target_turf, target_ship, null, null), "The NPC launch failed")
	TEST_ASSERT(!done("vc/combat/missile"), "A launch with no player was credited")
	launcher.loaded_missile = list("effect_type" = /obj/effect/temp_visual/tutorial_test_missile)
	TEST_ASSERT(launcher.fire(target_turf, target_ship, null, player), "The launch failed")
	TEST_ASSERT(done("vc/combat/missile"), "Launching a missile at a ship was not credited")
	// Let the delayed missile spawns land and clear inside the test.
	sleep(2 SECONDS)

/// Force-docking a held pirate credits the user, and boarding it to the crew aboard.
/datum/unit_test/voidcrew_tutorials/force_dock/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/mob/living/carbon/human/player = make_player(deck)
	var/obj/structure/overmap/ship/our_ship = make_crewed_ship_of_type(deck, player, /obj/structure/overmap/ship/tutorial_dock_test)
	var/obj/structure/overmap/ship/npc/tutorial_test/pirate = allocate(/obj/structure/overmap/ship/npc/tutorial_test, get_turf(our_ship))
	pirate.state = "flying" // OVERMAP_SHIP_FLYING
	var/obj/machinery/ship_combat/interdictor/interdictor = allocate(/obj/machinery/ship_combat/interdictor, get_step(run_loc_floor_top_right, SOUTH))
	interdictor.linked_ship_ref = WEAKREF(our_ship)
	TEST_ASSERT(!interdictor.force_dock_target(player), "Force-docking with no lock succeeded")
	TEST_ASSERT(!done("vc/combat/force_dock"), "A failed force-dock was credited")
	interdictor.interdicted_ship_ref = WEAKREF(pirate)
	interdictor.interdiction_active = TRUE
	TEST_ASSERT(interdictor.force_dock_target(player), "The force-dock failed")
	TEST_ASSERT(done("vc/combat/force_dock"), "Force-docking was not credited")
	TEST_ASSERT(done("vc/pirates/board"), "Force-docking a pirate was not credited as boarding it")

/// Hunting pirates: finishing "Let them board" excuses "Fight ship to ship" and completes the
/// item. The boss and the dock go through their real procs; the wave handler is called directly.
/datum/unit_test/voidcrew_tutorials/pirate_routes/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/mob/living/carbon/human/player = make_player(deck)
	var/obj/structure/overmap/ship/our_ship = make_crewed_ship(deck, player)
	var/obj/structure/overmap/ship/npc/tutorial_test/pirate = allocate(/obj/structure/overmap/ship/npc/tutorial_test, get_turf(our_ship))
	var/datum/ai_controller/npc_ship/controller = new(pirate)
	pirate.ai_controller = controller
	// The ship controller has no movement type, and the base Destroy() it calls into reads one.
	controller.change_ai_movement_type(/datum/ai_movement/dumb)
	controller.set_blackboard_key("npc_target", our_ship) // BB_NPC_TARGET

	controller.tutorial_on_wave_complete(controller, 1)
	TEST_ASSERT(done("vc/pirates/boarders"), "Clearing the boarding wave was not credited")
	controller.handle_boss_killed()
	TEST_ASSERT(pirate.is_disabled, "Beating the commander did not disable the pirate ship")
	TEST_ASSERT(done("vc/pirates/commander"), "Beating the commander was not credited")
	reset_progress()
	controller.handle_boss_killed()
	TEST_ASSERT(!done("vc/pirates/commander"), "A second boss call on a disabled ship was credited")
	tutorial_credit(player, "vc/pirates/boarders")
	tutorial_credit(player, "vc/pirates/commander")

	var/datum/vc_tutorial_step/shoot = SSvc_tutorials.steps_by_key["vc/pirates/shoot"]
	var/datum/vc_tutorial/item = SSvc_tutorials.item_by_step["vc/pirates/shoot"]
	TEST_ASSERT(!shoot.excused(player), "Fight ship to ship was excused with Let them board unfinished")
	var/obj/structure/overmap/planet/empty/space = allocate(/obj/structure/overmap/planet/empty, get_step(run_loc_floor_top_right, WEST))
	var/list/saved_ships = SSovermap.simulated_ships
	SSovermap.simulated_ships = list(our_ship, pirate)
	pirate.docked = space
	our_ship.docked = space
	SEND_SIGNAL(our_ship, "voidcrew_ship_docked") // COMSIG_VOIDCREW_SHIP_DOCKED
	our_ship.docked = null
	pirate.docked = null
	SSovermap.simulated_ships = saved_ships
	TEST_ASSERT(done("vc/pirates/board"), "Docking beside a pirate ship was not credited as boarding it")
	TEST_ASSERT(shoot.excused(player), "Finishing Let them board did not excuse Fight ship to ship")
	TEST_ASSERT(SSvc_tutorials.item_complete(item, TUTORIAL_TEST_CKEY, player), "Finishing Let them board did not complete Hunting pirates")
	TEST_ASSERT(done("vc/pirates"), "Finishing Let them board did not save the item key")
	TEST_ASSERT(!done("vc/pirates/shoot"), "Fight ship to ship was marked done")

/// A pirate hull failing credits the crew it was fighting, once.
/datum/unit_test/voidcrew_tutorials/pirate_shot_down/Run()
	var/turf/deck = run_loc_floor_bottom_left
	var/mob/living/carbon/human/player = make_player(deck)
	var/obj/structure/overmap/ship/our_ship = make_crewed_ship(deck, player)
	var/obj/structure/overmap/ship/npc/tutorial_test/pirate = allocate(/obj/structure/overmap/ship/npc/tutorial_test, get_step(run_loc_floor_top_right, WEST))
	var/datum/ai_controller/npc_ship/controller = new(pirate)
	pirate.ai_controller = controller
	// The ship controller has no movement type, and the base Destroy() it calls into reads one.
	controller.change_ai_movement_type(/datum/ai_movement/dumb)
	controller.set_blackboard_key("npc_target", our_ship) // BB_NPC_TARGET
	pirate.on_ship_destroyed()
	TEST_ASSERT(pirate.has_crash_landed, "The pirate hull did not fail")
	TEST_ASSERT(done("vc/pirates/shoot"), "Shooting down a pirate was not credited to its target's crew")
	reset_progress()
	pirate.on_ship_destroyed()
	TEST_ASSERT(!done("vc/pirates/shoot"), "A hull that had already failed was credited again")

#undef TUTORIAL_TEST_CKEY
