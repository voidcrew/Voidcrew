/**
 * # Ship R&D wiring
 *
 * Every hull in this fork builds its own R&D out of the roundstart kit: a ship server, a
 * source-code disk that carries the hull's only /datum/techweb, an R&D console, and one or more
 * fabricators, all wired together by hand with a multitool. Nothing about that path is upstream's
 * - upstream has one permanent station techweb that every machine finds by itself - and until now
 * nothing in CI looked at it. The 2026-08 upstream catch-up merge broke the whole chain in four
 * separate places and every one of them shipped silently:
 *
 * - **tg #93967** made /obj/item/doMove reroute a held item through owner.transferItemToLoc() and
 *   return null even on success. The server's install path tested `if(!attacking_item.forceMove(src))`
 *   and so decided the disk had not moved - the disk sat in the server's contents forever, never
 *   registered as the HDD. It only reproduces for a disk that is genuinely IN_INVENTORY, which is
 *   why Test A goes to the trouble of putting it in a hand.
 * - **tg #94114** (be1f2318695) added `locked = TRUE` to the rdconsole circuit board. Every console
 *   in the fork - the kit's and all seventeen mapped ones - spawned locked behind ACCESS_RESEARCH,
 *   which almost nobody here carries. No conflict, no compile error, one changed default.
 * - **tg #94112** made every /obj/item/disk stackable with no opt-out. A stacked ship disk cannot
 *   be installed (the server istypes for the disk, and the held item is now the stack), and
 *   /obj/item/disk_stack/Destroy() QDEL_LISTs its contents - which takes the hull's techweb with it.
 * - The **fossil `voidcrew_tgui/interfaces/Techweb.jsx`** shadowed upstream's rewritten Techweb/
 *   directory and destructured a 5-element `design_cache` row as `[name, classes]`, so the console
 *   UI threw on first render. Test F pins the DM half of that payload contract; the JS half lives
 *   in tgui/packages/tgui/interfaces/Techweb/helpers.test.ts.
 *
 * These are behavioural tests, unlike most of the fork's suite: they build the real machines on the
 * test floor and drive the real interaction procs. That is affordable here because R&D wiring is
 * pure machine-to-machine state with no map, no ship and no timers involved - see the note on
 * fabricator linking in Test A for the one ordering constraint.
 *
 * NOTE: unit-test files compile at their `code/modules/unit_tests` include position, which is
 * BEFORE `voidcrew/_DEFINES/`. Fork defines are not available here. Literals are used with a
 * comment naming the define, per the voidcrew_loot.dm convention.
 */

/// voidcrew/_DEFINES/techweb_nodes.dm's TECHWEB_NODE_BASIC_SHUTTLE.
/// A tier-1 node hanging off the starter node /datum/techweb_node/fundamental_sci, with no
/// experiment and no survey requirement, so it is researchable from a fresh web given points alone.
#define VC_TEST_NODE_BASIC_SHUTTLE /datum/techweb_node/basic_shuttle_tech
/// voidcrew/_DEFINES/techweb_nodes.dm's TECHWEB_NODE_TRANSPORTER. Carries
/// `required_surveyed_objects = list(planets = 3)`, the fork's survey gate.
#define VC_TEST_NODE_SURVEY_GATED /datum/techweb_node/transporter

/**
 * The whole player-facing R&D bring-up, end to end.
 *
 * Guards the "a hull can never do research at all" breakage class. Specifically:
 *
 * - the ship disk mints its own techweb, and the server/console/fabricator do NOT come pre-bound
 *   to anything (which doubles as the contract test for `no_default_techweb_link` being forced TRUE
 *   in voidcrew/edits/config.dm - if that ever flips, the ship server's Initialize would bind the
 *   global science web and then QDEL_NULL it);
 * - installing a HELD disk registers it as the HDD (tg #93967);
 * - the multitool copies the web out of the server and into a console and a fabricator;
 * - researching a node banks the designs on the web and they reach the fabricators' catalogues.
 */
/datum/unit_test/voidcrew_ship_research_flow

/datum/unit_test/voidcrew_ship_research_flow/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	// The server is allocated before the disk on purpose: allocate() destroys in insertion order,
	// so the server lets go of source_code_hdd before the disk itself is reaped.
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/disk/computer/ship_disk/disk = allocate(/obj/item/disk/computer/ship_disk)
	var/obj/machinery/computer/rdconsole/console = allocate(/obj/machinery/computer/rdconsole)
	var/obj/machinery/rnd/production/protolathe/lathe = allocate(/obj/machinery/rnd/production/protolathe)
	var/obj/machinery/rnd/production/circuit_imprinter/imprinter = allocate(/obj/machinery/rnd/production/circuit_imprinter)
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)

	var/datum/techweb/web = disk.stored_research
	TEST_ASSERT_NOTNULL(web, "a fresh ship disk minted no techweb of its own")

	// no_default_techweb_link contract: nothing links itself here.
	TEST_ASSERT_NULL(server.source_code_hdd, "a fresh ship server came up with a source code drive already in it")
	TEST_ASSERT_NULL(server.stored_research, "a fresh ship server came up holding a techweb - no_default_techweb_link is not being honoured")
	TEST_ASSERT_NULL(console.stored_research, "a fresh R&D console bound itself to a techweb - no_default_techweb_link is not being honoured")
	TEST_ASSERT_NULL(lathe.stored_research, "a fresh protolathe bound itself to a techweb - no_default_techweb_link is not being honoured")
	TEST_ASSERT_NULL(imprinter.stored_research, "a fresh circuit imprinter bound itself to a techweb - no_default_techweb_link is not being honoured")

	// tg #93967 only reproduces for an item with IN_INVENTORY set, because that is the flag
	// /obj/item/doMove reads before rerouting the move through transferItemToLoc(). A disk sitting
	// on the floor installs fine even with the broken loc check, so the disk MUST be held here.
	TEST_ASSERT(user.put_in_active_hand(disk, TRUE), "the test human could not be made to hold the ship disk")
	TEST_ASSERT(user.is_holding(disk), "the ship disk was not in the test human's hands after put_in_active_hand()")

	// The real click, not a direct attacked_by(): the disk is an /obj/item/disk, so this also
	// proves nothing upstream added on the item_interaction leg (which runs first and can return
	// ITEM_INTERACT_BLOCKING) swallows the disk before the server's attacked_by ever sees it.
	disk.melee_attack_chain(user, server, list())

	TEST_ASSERT_EQUAL(server.source_code_hdd, disk, "the held disk was not registered as the server's source code drive - this is tg #93967, forceMove() returning null for an IN_INVENTORY item")
	TEST_ASSERT_EQUAL(disk.loc, server, "the disk was accepted but is not inside the server")
	TEST_ASSERT_EQUAL(server.stored_research, web, "the server did not adopt the disk's techweb")
	TEST_ASSERT(server in web.techweb_servers, "the server did not register itself on the disk's techweb")

	// A second disk must not displace the first.
	var/obj/item/disk/computer/ship_disk/spare = allocate(/obj/item/disk/computer/ship_disk)
	TEST_ASSERT(user.put_in_active_hand(spare, TRUE), "the test human could not be made to hold the spare ship disk")
	spare.melee_attack_chain(user, server, list())
	TEST_ASSERT_EQUAL(server.source_code_hdd, disk, "a second ship disk overwrote the installed one")
	TEST_ASSERT_NOTEQUAL(spare.loc, server, "a second ship disk was swallowed by a server that already had one")

	// Copy the web out with a multitool, then link the console and the fabricators to it.
	server.multitool_act(user, multitool)
	TEST_ASSERT_EQUAL(multitool.buffer, web, "multitooling the server did not put its techweb in the multitool buffer")

	console.multitool_act(user, multitool)
	TEST_ASSERT_EQUAL(console.stored_research, web, "multitooling the console did not link it to the server's techweb")
	TEST_ASSERT(console in web.consoles_accessing, "a linked console is not in the techweb's consoles_accessing")
	TEST_ASSERT(console in web.connected_machines, "a linked console is not in the techweb's connected_machines")

	// Points in, node out.
	web.adjust_multiple_points(list(TECHWEB_POINT_TYPE_GENERIC = 5000))
	TEST_ASSERT(web.research_points[TECHWEB_POINT_TYPE_GENERIC] >= 5000, "adjust_multiple_points() did not bank generic research points")

	var/datum/techweb_node/node = SSresearch.techweb_nodes[VC_TEST_NODE_BASIC_SHUTTLE]
	TEST_ASSERT_NOTNULL(node, "[VC_TEST_NODE_BASIC_SHUTTLE] is not registered in SSresearch.techweb_nodes")
	TEST_ASSERT(web.research_node(node), "a fully-funded, unhidden tier-1 node off the starter node refused to research")
	TEST_ASSERT(web.researched_nodes[VC_TEST_NODE_BASIC_SHUTTLE], "research_node() reported success but the node is not in researched_nodes")
	for(var/design_path in node.unlocked_designs)
		TEST_ASSERT(web.researched_designs[design_path], "[design_path] was not unlocked on the web by researching [VC_TEST_NODE_BASIC_SHUTTLE]")

	// The fabricators are linked AFTER the research on purpose. A web that gains designs while a
	// fabricator is already attached refreshes it through COMSIG_TECHWEB_ADD_DESIGN, which
	// on_techweb_update() batches behind a 2 SECOND addtimer - not something a test may wait on.
	// Linking afterwards routes through connect_techweb() -> on_connected_techweb() -> update_designs(),
	// which is synchronous, and exercises exactly the same catalogue-building code.
	lathe.multitool_act(user, multitool)
	imprinter.multitool_act(user, multitool)
	TEST_ASSERT_EQUAL(lathe.stored_research, web, "multitooling the protolathe did not link it to the server's techweb")
	TEST_ASSERT(lathe in web.connected_machines, "a linked protolathe is not in the techweb's connected_machines")
	TEST_ASSERT_EQUAL(imprinter.stored_research, web, "multitooling the circuit imprinter did not link it to the server's techweb")

	// Both fabricator families, because this node unlocks circuit boards (IMPRINTER) while the
	// starter node's designs are mostly PROTOLATHE - checking only one leaves the other's filter
	// untested, and can go vacuous if the node's contents ever change.
	for(var/obj/machinery/rnd/production/fabricator in list(lathe, imprinter))
		// Mirrors the filter in /obj/machinery/rnd/production/update_designs().
		var/list/expected = list()
		for(var/design_path in web.researched_designs)
			var/datum/design/design = SSresearch.techweb_designs[design_path]
			if(isnull(design))
				continue
			if(!isnull(fabricator.allowed_department_flags) && !(design.departmental_flags & fabricator.allowed_department_flags))
				continue
			if(!(design.build_type & fabricator.allowed_buildtypes))
				continue
			expected[design_path] = TRUE
		TEST_ASSERT(length(expected), "no researched design is buildable on [fabricator.type], so this leg of the test proves nothing - pick a different fabricator or node")

		var/list/cached_paths = list()
		for(var/datum/design/cached as anything in fabricator.cached_designs)
			cached_paths[cached.type] = TRUE
		for(var/design_path in expected)
			TEST_ASSERT(cached_paths[design_path], "[design_path] is on the linked techweb but never reached [fabricator.type]'s catalogue")

	// And specifically: the node we just researched put its boards on the imprinter.
	var/list/imprinter_paths = list()
	for(var/datum/design/cached as anything in imprinter.cached_designs)
		imprinter_paths[cached.type] = TRUE
	TEST_ASSERT(imprinter_paths[/datum/design/board/shuttle/shuttle_helm], "the shuttle helm board unlocked by [VC_TEST_NODE_BASIC_SHUTTLE] never reached the circuit imprinter")

/**
 * R&D console circuit boards are unlocked fork-wide.
 *
 * Guards tg #94114 (be1f2318695), which set `locked = TRUE` on
 * /obj/item/circuitboard/computer/rdconsole so that station engineers would have to ask science to
 * research things for them. There is no station and no science department here, and only captains
 * plus a handful of themes' scientists carry ACCESS_RESEARCH - so left at upstream's default every
 * console in the fork opens, draws the tree, and then answers "Console is locked, cannot perform
 * further actions." to every button. voidcrew/modules/research/research_boards.dm forces it back
 * open; this is the guard against the next merge quietly restoring it.
 *
 * Note the lock lives on the BOARD, not the console - /obj/machinery/computer/rdconsole still has
 * a dead `locked` var of its own that nothing reads.
 */
/datum/unit_test/voidcrew_rd_console_unlocked

/datum/unit_test/voidcrew_rd_console_unlocked/Run()
	TEST_ASSERT(!/obj/item/circuitboard/computer/rdconsole::locked, "the R&D console circuit board defaults to locked - upstream #94114's default has come back, and every console in the fleet is now ACCESS_RESEARCH gated")
	TEST_ASSERT(!/obj/item/circuitboard/computer/rdconsole/unlocked::locked, "the explicitly-unlocked R&D console board subtype is locked")

	// A console built at runtime instantiates its own board in /obj/machinery/Initialize.
	var/obj/machinery/computer/rdconsole/console = allocate(/obj/machinery/computer/rdconsole)
	var/obj/item/circuitboard/computer/rdconsole/board = console.circuit
	TEST_ASSERT_NOTNULL(board, "a freshly built R&D console has no circuit board to read the lock off")
	TEST_ASSERT(!board.locked, "a freshly built R&D console came up locked")

	// And every console the maps place. This is the half that actually failed in the incident:
	// the kit's console and all seventeen mapped ones came up locked at once.
	for(var/obj/machinery/computer/rdconsole/mapped as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/rdconsole))
		var/obj/item/circuitboard/computer/rdconsole/mapped_board = mapped.circuit
		if(!istype(mapped_board))
			continue
		if(mapped_board.locked)
			TEST_FAIL("mapped R&D console [mapped.type] at [AREACOORD(mapped)] came up locked")
	// The console count is deliberately not asserted to be non-zero: the unit test world boots
	// MetaStation, not the voidcrew overmap, so how many rdconsoles exist is a property of
	// whichever map CI happens to run.

/**
 * A ship disk can never be swallowed by a floppy-disk stack.
 *
 * Guards tg #94112, which made every /obj/item/disk stackable with no blacklist and no type filter.
 * The ship disk is an /obj/item/disk subtype (it was repathed for its sprite), so it inherited
 * stacking, and two things go wrong - the first silently:
 *
 * 1. Once stacked, the held item is the STACK. /obj/machinery/rnd/server/ship/attacked_by istypes
 *    for the disk, which a stack fails, so the player just whacks the server and nothing happens.
 * 2. /obj/item/disk_stack/Destroy() runs QDEL_LIST(stacked_disks), which reaches the ship disk's
 *    Destroy, which QDEL_NULLs stored_research. The hull's entire techweb, gone because someone
 *    tidied two disks together and the stack later burned.
 *
 * voidcrew/modules/research/edits/floppy_disk.dm closes both entry points; this covers all three
 * click directions plus the burning stack.
 */
/datum/unit_test/voidcrew_ship_disk_unstackable

/datum/unit_test/voidcrew_ship_disk_unstackable/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/disk/computer/ship_disk/ship_disk = allocate(/obj/item/disk/computer/ship_disk)
	var/obj/item/disk/plain = allocate(/obj/item/disk)
	var/turf/floor = run_loc_floor_bottom_left

	var/datum/techweb/web = ship_disk.stored_research
	TEST_ASSERT_NOTNULL(web, "a fresh ship disk minted no techweb of its own")
	TEST_ASSERT(ship_disk.unstackable, "the ship disk is not flagged unstackable")
	TEST_ASSERT(!plain.unstackable, "a plain floppy disk is flagged unstackable, which would break ordinary disk stacking")

	// Direction 1: a plain disk held, the ship disk clicked. `src` is the target disk.
	var/plain_onto_ship = ship_disk.item_interaction(user, plain, list())
	TEST_ASSERT(plain_onto_ship & ITEM_INTERACT_BLOCKING, "clicking a plain disk onto a ship disk was not refused")

	// Direction 2: the ship disk held, a plain disk clicked.
	var/ship_onto_plain = plain.item_interaction(user, ship_disk, list())
	TEST_ASSERT(ship_onto_plain & ITEM_INTERACT_BLOCKING, "clicking a ship disk onto a plain disk was not refused")

	var/obj/item/disk_stack/stranded = locate(/obj/item/disk_stack) in floor
	TEST_ASSERT_NULL(stranded, "a disk stack was built on the floor despite both clicks being refused - upstream's handler creates the stack before it adds to it, so a refusal further in strands an empty stack")
	TEST_ASSERT_EQUAL(ship_disk.loc, floor, "the ship disk moved off the floor during a refused stacking attempt")
	TEST_ASSERT_EQUAL(plain.loc, floor, "the plain disk moved off the floor during a refused stacking attempt")

	// Direction 3: an existing stack. This route does not go through the item_interaction override
	// above at all, it lands straight in add_to_stack(), which is why that has its own backstop.
	var/obj/item/disk_stack/stack = allocate(/obj/item/disk_stack)
	var/obj/item/disk/filler_one = allocate(/obj/item/disk)
	var/obj/item/disk/filler_two = allocate(/obj/item/disk)
	stack.add_to_stack(user, filler_one)
	stack.add_to_stack(user, filler_two)
	TEST_ASSERT_EQUAL(length(stack.stacked_disks), 2, "two plain disks would not stack, so this test can no longer prove the ship disk is the one being refused")

	var/ship_onto_stack = stack.item_interaction(user, ship_disk, list())
	TEST_ASSERT(ship_onto_stack & ITEM_INTERACT_BLOCKING, "clicking a ship disk onto an existing stack was not refused")
	TEST_ASSERT(!(ship_disk in stack.stacked_disks), "a ship disk ended up inside a disk stack")
	TEST_ASSERT_EQUAL(ship_disk.loc, floor, "a ship disk was moved into a disk stack")

	// Direction 4: the stack held, the ship disk clicked.
	var/stack_onto_ship = ship_disk.item_interaction(user, stack, list())
	TEST_ASSERT(stack_onto_ship & ITEM_INTERACT_BLOCKING, "clicking a stack onto a ship disk was not refused")
	TEST_ASSERT_EQUAL(ship_disk.loc, floor, "a ship disk was absorbed by a stack clicked onto it")
	TEST_ASSERT_EQUAL(length(stack.stacked_disks), 2, "the ship disk was merged into the stack")

	// The consequence the whole guard exists for: a stack burning must not be able to take a
	// hull's techweb with it.
	qdel(stack)
	TEST_ASSERT(!QDELETED(web), "destroying a disk stack destroyed a ship techweb that was standing next to it")
	TEST_ASSERT_EQUAL(ship_disk.stored_research, web, "the ship disk lost its techweb when a nearby disk stack was destroyed")

/**
 * A destroyed techweb cuts every machine loose.
 *
 * Upstream's /datum/techweb/Destroy() nulls the node and design lists but never clears
 * consoles_accessing / techweb_servers / connected_machines, so a dead web leaves every machine
 * that was multitooled to it still holding a gutted datum: the console keeps reporting itself
 * linked and its catalogue stays permanently empty. That never mattered for the station's
 * permanent web. Here a techweb dies whenever its ship disk does - incinerated, dropped in a
 * disposal, aboard a hull that got blown up - so this is a routine event, and
 * voidcrew/modules/research/edits/_techweb.dm cuts the machines loose on the way out.
 */
/datum/unit_test/voidcrew_techweb_destroy_releases_machines

/datum/unit_test/voidcrew_techweb_destroy_releases_machines/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/disk/computer/ship_disk/disk = allocate(/obj/item/disk/computer/ship_disk)
	var/obj/machinery/computer/rdconsole/console = allocate(/obj/machinery/computer/rdconsole)
	var/obj/machinery/rnd/production/protolathe/lathe = allocate(/obj/machinery/rnd/production/protolathe)
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)

	var/datum/techweb/web = disk.stored_research
	TEST_ASSERT_NOTNULL(web, "a fresh ship disk minted no techweb of its own")

	TEST_ASSERT(user.put_in_active_hand(disk, TRUE), "the test human could not be made to hold the ship disk")
	disk.melee_attack_chain(user, server, list())
	TEST_ASSERT_EQUAL(server.source_code_hdd, disk, "the disk did not install, so the teardown below would prove nothing")

	server.multitool_act(user, multitool)
	console.multitool_act(user, multitool)
	lathe.multitool_act(user, multitool)
	TEST_ASSERT_EQUAL(console.stored_research, web, "the console did not link, so the teardown below would prove nothing")
	TEST_ASSERT_EQUAL(lathe.stored_research, web, "the protolathe did not link, so the teardown below would prove nothing")

	// Killing the disk kills the web, which is the only way a ship techweb ever dies.
	QDEL_NULL(disk)
	TEST_ASSERT(QDELETED(web), "destroying the ship disk left its techweb alive")

	TEST_ASSERT_NULL(server.stored_research, "the ship server still holds a destroyed techweb")
	TEST_ASSERT_NULL(console.stored_research, "the R&D console still holds a destroyed techweb - it will report itself linked with an empty catalogue for the rest of the round")
	TEST_ASSERT_NULL(lathe.stored_research, "the protolathe still holds a destroyed techweb")

/**
 * Unlinked R&D machinery is silent, not runtiming.
 *
 * `no_default_techweb_link` is forced TRUE fork-wide (voidcrew/edits/config.dm), so "built but not
 * yet multitooled to a server" is the NORMAL starting state of every R&D machine here, not an edge
 * case - and upstream's code was written on the assumption that the station techweb always exists.
 * The destructive analyzer was the worst of them: ui_data() reports the missing link as
 * data["server_connected"] and then dereferences stored_research two lines later anyway, so loading
 * an item into an unlinked analyzer and opening it runtimed and showed an empty window with no
 * explanation.
 *
 * There is no assertion on the ui_data() calls themselves and there does not need to be: the suite
 * fails the whole run on ANY runtime, so calling them unlinked IS the assertion.
 */
/datum/unit_test/voidcrew_unlinked_rnd_machines_are_quiet

/datum/unit_test/voidcrew_unlinked_rnd_machines_are_quiet/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)

	var/list/machine_paths = valid_subtypesof(/obj/machinery/rnd) + list(/obj/machinery/computer/rdconsole)
	var/checked = 0
	for(var/machine_path in machine_paths)
		// Servers are skipped: they are the one R&D machine that is never unlinked, because
		// /obj/machinery/rnd/server/Initialize mints its own techweb when no_default_techweb_link
		// is set. They also have no tgui at all. The ship server is the exception - it QDEL_NULLs
		// that web straight back out in its own Initialize, so unlinked IS its starting state.
		if(ispath(machine_path, /obj/machinery/rnd/server) && machine_path != /obj/machinery/rnd/server/ship)
			continue
		var/obj/machinery/machine = allocate(machine_path)
		checked++

		// Every one of these must come up unlinked, or the sweep is testing the linked path.
		if(istype(machine, /obj/machinery/rnd))
			var/obj/machinery/rnd/rnd_machine = machine
			TEST_ASSERT_NULL(rnd_machine.stored_research, "[machine_path] bound itself to a techweb at build time - no_default_techweb_link is not being honoured")
		else if(istype(machine, /obj/machinery/computer/rdconsole))
			var/obj/machinery/computer/rdconsole/rdconsole = machine
			TEST_ASSERT_NULL(rdconsole.stored_research, "[machine_path] bound itself to a techweb at build time - no_default_techweb_link is not being honoured")

		machine.ui_data(user)
		machine.ui_static_data(user)

	TEST_ASSERT(checked >= 4, "the R&D machine sweep only found [checked] machines to build; the type walk has broken and this test is passing vacuously")

	// The analyzer's own fix: rather than duplicating all of upstream's ui_data to guard it, the
	// machine simply refuses to hold an item while it has no server to report to.
	var/obj/machinery/rnd/destructive_analyzer/analyzer = allocate(/obj/machinery/rnd/destructive_analyzer)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	TEST_ASSERT_NULL(analyzer.stored_research, "the destructive analyzer built itself linked, so the refusal below would prove nothing")
	// The item has to be genuinely held: base_item_interaction inserts through
	// user.transferItemToLoc(), which refuses anything that is not in the mob's inventory - an
	// unheld wrench would be refused whether the machine is linked or not.
	TEST_ASSERT(user.put_in_active_hand(wrench, TRUE), "the test human could not be made to hold the wrench")

	TEST_ASSERT(!analyzer.is_insertion_ready(user), "an unlinked destructive analyzer reported itself ready to accept an item")
	analyzer.base_item_interaction(user, wrench, list())
	TEST_ASSERT_NULL(analyzer.loaded_item, "an unlinked destructive analyzer accepted an item; opening it will runtime on stored_research.deconstructed_items")
	TEST_ASSERT(user.is_holding(wrench), "the refused wrench left the user's hands anyway")
	analyzer.ui_data(user)

	// Paired half. is_insertion_ready() also gates on panel_open, disabled, busy, BROKEN, NOPOWER
	// and loaded_item, so without this the refusal above could be any of those and would keep
	// passing for the wrong reason after the server-link guard was gone.
	var/datum/techweb/analyzer_web = new
	analyzer.connect_techweb(analyzer_web)
	TEST_ASSERT(analyzer.is_insertion_ready(user), "a linked destructive analyzer still refuses items, so the refusal above is not about the missing server link and this test proves nothing")
	analyzer.base_item_interaction(user, wrench, list())
	TEST_ASSERT_EQUAL(analyzer.loaded_item, wrench, "a linked destructive analyzer did not accept a held item")
	// The path that used to runtime: item loaded, UI opened.
	analyzer.ui_data(user)

	// And losing the server mid-load hands the item back rather than leaving the machine
	// runtiming on every UI update.
	analyzer.unsync_research_servers()
	TEST_ASSERT_NULL(analyzer.stored_research, "the analyzer kept its techweb through unsync_research_servers()")
	TEST_ASSERT_NULL(analyzer.loaded_item, "the analyzer kept its loaded item after losing its server")
	qdel(analyzer_web)

/**
 * Contract sentinels for the R&D console's tgui payload and its point income.
 *
 * These are the couplings that break silently because both halves compile: an action name the UI
 * sends, a params key the DM reads, the arity of an override that must forward everything it was
 * given, and the SHAPE of the static payload. The last one is what the deleted fossil
 * `voidcrew_tgui/interfaces/Techweb.jsx` got wrong - it destructured a design_cache row as
 * `[name, classes]` when the row is five elements with the material cost in slot 2, so
 * `classes.startsWith(...)` threw on first TechNode render and the console UI never came up.
 * The JS half of that contract is pinned in
 * tgui/packages/tgui/interfaces/Techweb/helpers.test.ts; this is the DM half.
 */
/datum/unit_test/voidcrew_rd_console_contracts

/datum/unit_test/voidcrew_rd_console_contracts/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/rnd/server/ship/server = allocate(/obj/machinery/rnd/server/ship)
	var/obj/item/disk/computer/ship_disk/disk = allocate(/obj/item/disk/computer/ship_disk)
	var/obj/machinery/computer/rdconsole/console = allocate(/obj/machinery/computer/rdconsole)
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)

	var/datum/techweb/web = disk.stored_research
	TEST_ASSERT_NOTNULL(web, "a fresh ship disk minted no techweb of its own")
	TEST_ASSERT(user.put_in_active_hand(disk, TRUE), "the test human could not be made to hold the ship disk")
	disk.melee_attack_chain(user, server, list())
	server.multitool_act(user, multitool)
	console.multitool_act(user, multitool)
	TEST_ASSERT_EQUAL(console.stored_research, web, "the console did not link, so none of the contracts below can be checked")

	// --- ui_act("researchNode") ---
	// Behavioural arity check. The fork's ui_act override in
	// voidcrew/modules/research/edits/_rd_consoles.dm restates upstream's FULL four-parameter
	// signature on purpose; a shorter override is one merge away from silently dropping `ui` and
	// `state` on the way through ..(). Driving the real four-argument call and asserting the node
	// actually got researched proves the whole chain - the override, the ..(), the board lock
	// check, and the params["node_path"] key the UI sends.
	//
	// The /datum/tgui is not decoration: /obj/machinery/ui_act reads ui.user, and /datum/ui_act
	// returns TRUE (which upstream's rdconsole/ui_act treats as "handled, stop") for a null ui or
	// a non-interactive one. A test that passed null here would pass vacuously forever.
	web.adjust_multiple_points(list(TECHWEB_POINT_TYPE_GENERIC = 5000))
	var/datum/tgui/window = new(user, console, "Techweb")
	TEST_ASSERT_EQUAL(window.status, UI_INTERACTIVE, "the test tgui datum is not interactive, so ui_act would bail before reaching any action")
	var/old_usr = usr
	usr = user // upstream's researchNode branch passes usr straight into investigate_log()
	console.ui_act("researchNode", list("node_path" = "[VC_TEST_NODE_BASIC_SHUTTLE]"), window, window.state)
	usr = old_usr
	qdel(window)
	TEST_ASSERT(web.researched_nodes[VC_TEST_NODE_BASIC_SHUTTLE], "ui_act(\"researchNode\") did not research the node - either the action name, the params\[\"node_path\"\] key, the board lock default, or the fork's ui_act override's parameter list has drifted from upstream")

	// --- research notes bank exactly their value ---
	// Notes reach the console on the attackby leg, and only because upstream's item_interaction
	// returns NONE for anything that is not an /obj/item/disk. Driving the whole melee chain is the
	// point: if upstream ever makes that item_interaction claim non-disk items, feeding notes
	// silently stops working and this is what catches it.
	var/points_before = web.research_points[TECHWEB_POINT_TYPE_GENERIC]
	var/obj/item/research_notes/notes = allocate(/obj/item/research_notes, null, 137, "unit test")
	TEST_ASSERT_EQUAL(notes.value, 137, "research notes did not take the value they were constructed with")
	TEST_ASSERT(user.put_in_active_hand(notes, TRUE), "the test human could not be made to hold the research notes")
	notes.melee_attack_chain(user, console, list())
	TEST_ASSERT_EQUAL(web.research_points[TECHWEB_POINT_TYPE_GENERIC], points_before + 137, "feeding research notes to a linked R&D console did not bank exactly their value")
	TEST_ASSERT(QDELETED(notes), "the research notes survived being banked, so they can be banked again")

	// --- ui_static_data payload shape ---
	var/list/payload = console.ui_static_data(user)
	var/list/static_data = payload["static_data"]
	TEST_ASSERT_NOTNULL(static_data, "the R&D console's ui_static_data has no \"static_data\" key")

	var/list/node_cache = static_data["node_cache"]
	TEST_ASSERT(length(node_cache), "the R&D console sent an empty node_cache; the tree renders as nothing")
	var/list/design_cache = static_data["design_cache"]
	TEST_ASSERT(length(design_cache), "the R&D console sent an empty design_cache")

	// The row shape the fossil got wrong. Slot 2 is the material cost LIST, not the sprite class
	// string - reading it as `classes` and calling .startsWith() on it is what threw.
	for(var/design_key in design_cache)
		var/list/row = design_cache[design_key]
		TEST_ASSERT_EQUAL(length(row), 5, "design_cache row \"[design_key]\" is not the 5-element (name, cost, build_type, departmental_flags, sprite class) row the Techweb UI destructures")
		TEST_ASSERT(istext(row[1]), "design_cache row \"[design_key]\" slot 1 is not the design name")
		TEST_ASSERT(islist(row[2]), "design_cache row \"[design_key]\" slot 2 is not the material cost list - if this became the sprite class string again, the rows have been reordered under the UI")
		TEST_ASSERT(istext(row[5]), "design_cache row \"[design_key]\" slot 5 is not the spritesheet class string the UI passes to startsWith()")

	// --- survey gating survives into the payload ---
	// compress_id() is a plain lookup by this point: ..() has already assigned an id to every node
	// path, so this cannot mint a new one for a node that really is in the cache.
	var/list/gated_node_data = node_cache["[console.compress_id(VC_TEST_NODE_SURVEY_GATED)]"]
	TEST_ASSERT_NOTNULL(gated_node_data, "[VC_TEST_NODE_SURVEY_GATED] is missing from the console's node_cache")
	TEST_ASSERT(length(gated_node_data["required_surveyed_objects"]), "[VC_TEST_NODE_SURVEY_GATED] is survey-gated but its node_cache entry carries no required_surveyed_objects; the UI cannot tell the crew what to chart")

/**
 * Experiment handlers only take an unforced techweb link they could legitimately reach.
 *
 * Experiment handlers are the only research machinery in this fork that links itself, and the
 * second argument to link_techweb() is what separates the two routes:
 *
 * - unforced is what the Experiment Configuration UI sends, and is validated against
 *   SSresearch.find_valid_servers() so a crafted href cannot tap a docked neighbour's web;
 * - forced is the multitool route and a ship server adopting its own unlinked handlers, and skips
 *   the check on purpose.
 *
 * Upstream's link_techweb() takes one argument. The fork's override in
 * voidcrew/modules/research/edits/_experiments.dm adds `forced`, and DM will happily let a caller
 * pass a second argument to a one-parameter proc - so if that override is ever lost in a merge,
 * every `link_techweb(web, TRUE)` call site keeps compiling and silently becomes an unforced link.
 */
/datum/unit_test/voidcrew_experiment_handler_forced_link

/datum/unit_test/voidcrew_experiment_handler_forced_link/Run()
	var/obj/item/experi_scanner/scanner = allocate(/obj/item/experi_scanner)
	var/datum/component/experiment_handler/handler = scanner.GetComponent(/datum/component/experiment_handler)
	TEST_ASSERT_NOTNULL(handler, "the Experi-Scanner has no experiment handler component")
	TEST_ASSERT_NULL(handler.linked_web, "a freshly built Experi-Scanner linked itself to a techweb - no_default_techweb_link is not being honoured")

	// A bare techweb with no servers anywhere. find_valid_servers() walks the web's OWN
	// techweb_servers list, so this is deterministic: there is nothing for it to find.
	var/datum/techweb/orphan_web = new
	TEST_ASSERT(!length(orphan_web.techweb_servers), "the test techweb came with servers attached")

	handler.link_techweb(orphan_web)
	TEST_ASSERT_NULL(handler.linked_web, "an unforced link_techweb() bound a handler to a techweb with no reachable server - the fork's validation override has been lost")

	handler.link_techweb(orphan_web, TRUE)
	TEST_ASSERT_EQUAL(handler.linked_web, orphan_web, "a forced link_techweb() did not bind the handler; the multitool route and ship-server adoption are both dead")

	handler.unlink_techweb()
	TEST_ASSERT_NULL(handler.linked_web, "unlink_techweb() did not clear the link")

	qdel(orphan_web)

/**
 * Every design and prerequisite a node names must actually exist.
 *
 * A sentinel for a landmine that has not gone off yet. SSresearch's initialize_nodes()
 * (code/controllers/subsystem/networks/research.dm) does this, with no null guard:
 *
 *     for(var/design_path in new_node.unlocked_designs)
 *         var/datum/design/unlocked_design = techweb_designs[design_path]
 *         unlocked_design.unlocked_by += node_path
 *
 * and the same pattern again for prerequisite_nodes. A node listing a design that self-qdels in
 * New(), or an abstract design path, or a design whose file stopped being included, runtimes right
 * there - which ABORTS node initialisation partway through. SSresearch comes up half-populated,
 * the science techweb is never created, and R&D is globally broken with nothing in the logs
 * pointing at the node that did it. This test names the offender instead.
 */
/datum/unit_test/voidcrew_techweb_node_graph_resolves

/datum/unit_test/voidcrew_techweb_node_graph_resolves/Run()
	TEST_ASSERT(length(SSresearch.techweb_designs), "SSresearch has no techweb designs registered at all")

	// Deliberately NOT walking SSresearch.techweb_nodes. If the landmine has already gone off, that
	// list is truncated at the offending node - and the offender is not even in it, because
	// initialize_nodes() registers a node AFTER the unlocked_designs loop that runtimed. Walking
	// the type tree the way initialize_nodes() does is the only way to name the culprit.
	// initialize_designs() runs to completion first and has no equivalent hole, so
	// SSresearch.techweb_designs is trustworthy either way.
	var/list/instances = list()
	for(var/datum/techweb_node/node_path as anything in valid_subtypesof(/datum/techweb_node))
		var/datum/techweb_node/node = new node_path()
		// Matches initialize_nodes()' own escape hatch for a node that decides not to exist.
		if(QDELING(node))
			continue
		instances[node_path] = node
	TEST_ASSERT(length(instances) > 100, "the techweb node type walk found only [length(instances)] nodes; the graph has collapsed or this test is no longer looking at it")

	for(var/node_path in instances)
		var/datum/techweb_node/node = instances[node_path]
		for(var/design_path in node.unlocked_designs)
			if(isnull(SSresearch.techweb_designs[design_path]))
				TEST_FAIL("techweb node [node_path] unlocks [design_path], which is not registered in SSresearch.techweb_designs - initialize_nodes() dereferences that null and aborts, leaving SSresearch half-built and R&D globally dead")
		for(var/prerequisite_path in node.prerequisite_nodes)
			if(isnull(instances[prerequisite_path]))
				TEST_FAIL("techweb node [node_path] requires [prerequisite_path], which is not an instantiable techweb node - initialize_nodes() dereferences that null and aborts")

	// The instances are plain datums with no Destroy and nothing holding a reference to them once
	// this list goes out of scope, so they are refcounted away without troubling SSgarbage.

/**
 * Reads the parameter list of a proc definition out of a source file, as raw text.
 *
 * `header` must include the opening parenthesis so it cannot match a call site or a longer
 * proc name. Returns null if the file or the definition is missing, which callers MUST assert
 * on: a scan that silently matches nothing is the exact failure mode this whole family of tests
 * exists to avoid.
 */
/proc/vc_test_proc_parameters(path, header)
	var/text = vc_test_file_text(path)
	if(isnull(text))
		return null
	var/definition_at = findtextEx(text, header)
	if(!definition_at)
		return null
	var/open_at = definition_at + length(header) - 1
	var/close_at = findtextEx(text, ")", open_at)
	if(!close_at)
		return null
	return trim(copytext(text, open_at + 1, close_at))

/**
 * The fork's R&D overrides declare exactly the parameters their parents do.
 *
 * DM lets a proc override declare fewer parameters than the proc it overrides, and lets a caller
 * pass more arguments than a proc declares, without a word from the compiler. Three of the fork's
 * R&D overrides sit at the OUTERMOST end of a chain that carries four arguments each, and every
 * one of them documents in a comment that its full signature is restated on purpose:
 *
 * - /obj/machinery/computer/rdconsole/ui_act        (voidcrew/modules/research/edits/_rd_consoles.dm)
 * - /obj/machinery/computer/rdconsole/attackby      (same file - this is how research notes are banked)
 * - /obj/machinery/rnd/server/ship/attacked_by      (voidcrew/modules/research/server.dm - the disk install)
 *
 * That comment is the only thing keeping them correct today. This turns it into a gate: if
 * upstream ever grows the parent's parameter list, the fork override stops matching and CI says
 * so, instead of the extra argument going quietly missing at the ..() a merge or two later.
 *
 * Static source comparison rather than reflection, because DM cannot introspect a proc's arity -
 * the same reason voidcrew_loot.dm and voidcrew_dynamic_events.dm read the source tree.
 */
/datum/unit_test/voidcrew_rd_override_signatures

/datum/unit_test/voidcrew_rd_override_signatures/Run()
	var/list/checks = list(
		// fork file, fork header, parent file, parent header
		list(
			"voidcrew/modules/research/edits/_rd_consoles.dm", "/obj/machinery/computer/rdconsole/ui_act(",
			"code/modules/research/rdconsole.dm", "/obj/machinery/computer/rdconsole/ui_act(",
		),
		list(
			"voidcrew/modules/research/edits/_rd_consoles.dm", "/obj/machinery/computer/rdconsole/attackby(",
			"code/_onclick/item_attack.dm", "/atom/proc/attackby(",
		),
		list(
			"voidcrew/modules/research/server.dm", "/obj/machinery/rnd/server/ship/attacked_by(",
			"code/_onclick/item_attack.dm", "/atom/proc/attacked_by(",
		),
	)

	for(var/list/check as anything in checks)
		var/fork_parameters = vc_test_proc_parameters(check[1], check[2])
		TEST_ASSERT_NOTNULL(fork_parameters, "could not find `[check[2]]` in [check[1]] - the override moved and this test is checking nothing")
		var/parent_parameters = vc_test_proc_parameters(check[3], check[4])
		TEST_ASSERT_NOTNULL(parent_parameters, "could not find `[check[4]]` in [check[3]] - the parent moved and this test is checking nothing")
		TEST_ASSERT_EQUAL(fork_parameters, parent_parameters, "`[check[2]]` in [check[1]] declares ([fork_parameters]) but its parent in [check[3]] declares ([parent_parameters]). Restate the parent's full signature or the extra parameters go missing at the ..().")

#undef VC_TEST_NODE_BASIC_SHUTTLE
#undef VC_TEST_NODE_SURVEY_GATED
