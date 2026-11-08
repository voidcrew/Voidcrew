// Xenoarchaeology tests: study.
//
// Test files compile before voidcrew/_DEFINES, so the values below are literals. They mirror
// voidcrew/_DEFINES/xenoarch.dm (see also the header of voidcrew_xenoarch_core.dm):
//   bands (ZONE_*): green 1, yellow 2, red 3
//   tiers: common 1, uncommon 2, rare 3, extreme 4
//   triggers: touch 1, water 2, acid 4
//   research for a first analysis: 100 / 150 / 250 by band, x1.5 for rare or extreme

/// A scan pad with an analyser beside it, ready for a find.
/datum/unit_test/voidcrew_xenoarch_study
	abstract_type = /datum/unit_test/voidcrew_xenoarch_study
	var/obj/machinery/artifact_scanpad/pad
	var/obj/machinery/artifact_analyser/analyser

/datum/unit_test/voidcrew_xenoarch_study/proc/build_bench()
	pad = allocate(/obj/machinery/artifact_scanpad, run_loc_floor_bottom_left)
	analyser = allocate(/obj/machinery/artifact_analyser, get_step(run_loc_floor_bottom_left, EAST))
	analyser.print_delay = 0
	analyser.find_pad()

/// A yellow-band find with one known effect, standing on the pad.
/datum/unit_test/voidcrew_xenoarch_study/proc/place_find(band = 2)
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, pad.loc, band)
	find.replace_effects(/datum/artifact_effect/heal, null, band)
	return find

/// Counts things of a type on a turf.
/datum/unit_test/voidcrew_xenoarch_study/proc/count_on(turf/where, path)
	. = 0
	for(var/atom/movable/thing in where)
		if(istype(thing, path))
			.++

/// The first full analysis of a dug find prints a report and pays research once, ever.
/datum/unit_test/voidcrew_xenoarch_study/research_once/Run()
	build_bench()
	TEST_ASSERT_EQUAL(analyser.pad, pad, "the analyser didn't find the pad beside it")
	TEST_ASSERT_EQUAL(analyser.scan_time, 10 SECONDS, "stock parts should make a ten-second scan")
	var/obj/machinery/artifact/find = place_find()
	TEST_ASSERT_EQUAL(analyser.watched, find, "the analyser isn't watching the find on its pad")
	var/turf/out = analyser.drop_location()

	TEST_ASSERT(analyser.start_scan(), "a scan didn't start")
	TEST_ASSERT(find.is_being_used(), "the scan didn't lock the find")
	analyser.finish_scan()
	TEST_ASSERT(find.research_paid, "the first analysis didn't mark research paid")
	TEST_ASSERT_NULL(find.locked_by, "finishing the scan didn't release the lock")
	TEST_ASSERT_EQUAL(count_on(out, /obj/item/research_notes), 1, "the first analysis didn't print notes")
	var/obj/item/research_notes/notes = locate() in out
	TEST_ASSERT_EQUAL(notes.value, 150, "a yellow uncommon find pays 150")

	var/obj/item/paper/artifact_report/report = locate() in out
	TEST_ASSERT_NOTNULL(report, "no report was printed")
	var/text = report.get_raw_text()
	TEST_ASSERT(findtext(text, find.serial), "the report doesn't name the serial")
	TEST_ASSERT(findtext(text, find.main_effect.report_line()), "the report doesn't carry the report line")
	TEST_ASSERT(findtext(report.name, find.serial), "the report isn't named for its find")
	TEST_ASSERT_NOTNULL(analyser.reading, "the screen kept no reading")

	TEST_ASSERT(analyser.start_scan(), "a second scan didn't start")
	analyser.finish_scan()
	TEST_ASSERT_EQUAL(count_on(out, /obj/item/research_notes), 1, "a second analysis paid research again")
	TEST_ASSERT_EQUAL(count_on(out, /obj/item/paper/artifact_report), 2, "a second analysis printed no report")

/// A find that never came out of a dig site pays nothing, but still reads.
/datum/unit_test/voidcrew_xenoarch_study/undug_pays_nothing/Run()
	build_bench()
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, pad.loc)
	find.replace_effects(/datum/artifact_effect/heal, null, null)
	TEST_ASSERT(!find.is_dug(), "a find made without a band was stamped")
	TEST_ASSERT(analyser.start_scan(), "a scan didn't start")
	analyser.finish_scan()
	TEST_ASSERT(!find.research_paid, "an undug find was marked paid")
	TEST_ASSERT_EQUAL(count_on(analyser.drop_location(), /obj/item/research_notes), 0, "an undug find paid research")
	TEST_ASSERT_EQUAL(count_on(analyser.drop_location(), /obj/item/paper/artifact_report), 1, "an undug find printed no report")
	TEST_ASSERT_EQUAL(xenoarch_claim_analysis(find, analyser, null), 0, "claiming an undug find paid")

/// Halting, losing the find, losing power or deleting the analyser always lets go of the lock.
/datum/unit_test/voidcrew_xenoarch_study/lock_release/Run()
	build_bench()
	var/obj/machinery/artifact/find = place_find()

	TEST_ASSERT(analyser.start_scan(), "a scan didn't start")
	analyser.abort_scan("Scan halted.")
	TEST_ASSERT_NULL(find.locked_by, "halting didn't release the lock")
	TEST_ASSERT(!pad.beam_on, "halting left the beam on")

	TEST_ASSERT(analyser.start_scan(), "a scan didn't restart after a halt")
	find.forceMove(get_step(pad.loc, NORTH))
	TEST_ASSERT_NULL(analyser.scan_target, "moving the find off the pad didn't stop the scan")
	TEST_ASSERT_NULL(find.locked_by, "moving the find off the pad didn't release the lock")
	TEST_ASSERT_NULL(analyser.watched, "the analyser kept watching a find that left the pad")
	TEST_ASSERT(!find.research_paid, "an aborted scan paid research")

	find.forceMove(pad.loc)
	TEST_ASSERT_EQUAL(analyser.watched, find, "the analyser didn't notice the find coming back")
	TEST_ASSERT(analyser.start_scan(), "a scan didn't start on the returned find")
	analyser.set_is_operational(FALSE)
	TEST_ASSERT_NULL(find.locked_by, "losing power didn't release the lock")
	analyser.set_is_operational(TRUE)

	TEST_ASSERT(analyser.start_scan(), "a scan didn't start after power came back")
	qdel(analyser)
	TEST_ASSERT_NULL(find.locked_by, "deleting the analyser mid-scan didn't release the lock")
	TEST_ASSERT(!pad.beam_on, "deleting the analyser left the beam on")

/// A find another machine holds can't be scanned until it lets go.
/datum/unit_test/voidcrew_xenoarch_study/lock_respected/Run()
	build_bench()
	var/obj/machinery/artifact/find = place_find()
	var/obj/machinery/artifact_analyser/other = allocate(/obj/machinery/artifact_analyser, get_step(run_loc_floor_bottom_left, NORTHEAST))
	TEST_ASSERT(find.try_lock(other), "another machine couldn't take the lock")
	TEST_ASSERT(!analyser.start_scan(), "a scan started on a find another machine holds")
	find.release_lock(other)
	TEST_ASSERT(analyser.start_scan(), "a scan didn't start once the other machine let go")
	analyser.abort_scan()

/// Deleting a find mid-scan stops the scan cleanly.
/datum/unit_test/voidcrew_xenoarch_study/find_deleted/Run()
	build_bench()
	var/obj/machinery/artifact/find = place_find()
	TEST_ASSERT(analyser.start_scan(), "a scan didn't start")
	qdel(find)
	TEST_ASSERT_NULL(analyser.scan_target, "the scan outlived its find")
	TEST_ASSERT_NULL(analyser.watched, "the analyser kept a deleted find")
	TEST_ASSERT(!pad.beam_on, "the beam outlived the find")

/// The tape records each stimulus and whether the find answered it.
/datum/unit_test/voidcrew_xenoarch_study/tape/Run()
	build_bench()
	var/obj/machinery/artifact/find = place_find()
	find.main_effect.trigger = 2 // water
	find.stimulate(4) // acid
	find.stimulate(2) // water
	var/list/texts = list()
	for(var/list/line as anything in analyser.tape)
		texts += line["text"]
	TEST_ASSERT("Acid. No response." in texts, "the tape didn't record a stimulus that woke nothing")
	TEST_ASSERT("Water. Response." in texts, "the tape didn't record a stimulus that woke the find")
	var/before = length(analyser.tape)
	find.stimulate(4)
	find.stimulate(4)
	TEST_ASSERT(length(analyser.tape) <= before + 1, "repeated stimuli each took a new line")
	TEST_ASSERT(analyser.tear_tape(null), "the tape couldn't be torn off")
	TEST_ASSERT(!length(analyser.tape), "tearing the tape left lines on it")
	TEST_ASSERT_EQUAL(count_on(analyser.drop_location(), /obj/item/paper/artifact_tape), 1, "tearing the tape left no slip")
	find.main_effect.deactivate(quiet = TRUE)

/// The labeler takes only words from its lists, and a tag made from the right words reads as right.
/datum/unit_test/voidcrew_xenoarch_study/labeler/Run()
	var/obj/item/artifact_labeler/labeler = allocate(/obj/item/artifact_labeler)
	TEST_ASSERT_NULL(labeler.make_label(), "a blank labeler made a tag")
	TEST_ASSERT(!labeler.set_word("effect", "Turns lead into gold"), "the labeler took a word it doesn't know")
	TEST_ASSERT(!labeler.set_word("trigger", "Heals"), "the labeler took an effect word as a trigger")
	TEST_ASSERT(!labeler.set_word("colour", "Heals"), "the labeler took a field it doesn't have")
	var/obj/machinery/artifact/find = allocate(/obj/machinery/artifact, run_loc_floor_bottom_left, 1)
	find.replace_effects(/datum/artifact_effect/heal, null, 1)
	TEST_ASSERT(labeler.set_word("effect", "Heals"), "the labeler refused an effect word")
	TEST_ASSERT(labeler.set_word("trigger", artifact_trigger_name(find.main_effect.trigger)), "the labeler refused a trigger word")
	TEST_ASSERT_NULL(labeler.make_label(), "a labeler with a blank line made a tag")
	TEST_ASSERT(labeler.set_word("second", "None"), "the labeler refused None for the second line")
	var/datum/artifact_label/tag = labeler.make_label()
	TEST_ASSERT_NOTNULL(tag, "a full labeler made no tag")
	find.apply_label(tag)
	TEST_ASSERT_EQUAL(find.label_accuracy(), 1, "a tag with every word right didn't read as right")
	TEST_ASSERT(labeler.set_word("second", "Light"), "the labeler refused an effect word for the second line")
	find.apply_label(labeler.make_label())
	TEST_ASSERT_EQUAL(find.label_accuracy(), 0.8, "a wrong second line should cost a fifth")

/// The three research nodes sit on the price ladder and unlock every study design.
/datum/unit_test/voidcrew_xenoarch_study_nodes/Run()
	var/list/expected = list(
		"xenoarchaeology" = list(40, list("xenoarch_analyser", "xenoarch_scanpad", "xenoarch_labeler")),
		"xenoarch_excavation" = list(80, list()),
		"xenoarch_exotic_particles" = list(120, list()),
	)
	for(var/node_id in expected)
		var/datum/techweb_node/node = SSresearch.techweb_node_by_id(node_id)
		TEST_ASSERT(node && node.id == node_id, "research node [node_id] is missing")
		var/list/costs = node.research_costs
		TEST_ASSERT_EQUAL(costs[TECHWEB_POINT_TYPE_GENERIC], expected[node_id][1], "[node_id] is off the price ladder")
		for(var/design_id in expected[node_id][2])
			TEST_ASSERT_NOTNULL(SSresearch.techweb_designs[design_id], "design [design_id] is missing")
			TEST_ASSERT(design_id in node.design_ids, "[node_id] doesn't unlock [design_id]")
	TEST_ASSERT_EQUAL(SSresearch.techweb_node_by_id("xenoarchaeology").zone_permission, 0, "the analyser node needs no standing")
	TEST_ASSERT_EQUAL(SSresearch.techweb_node_by_id("xenoarch_exotic_particles").zone_permission, 1, "the harvester node should need yellow standing (ZONE_PERMISSION_YELLOW)")
	var/datum/design/board/analyser_board = SSresearch.techweb_designs["xenoarch_analyser"]
	TEST_ASSERT_EQUAL(analyser_board.build_path, /obj/item/circuitboard/machine/artifact_analyser, "the analyser design prints the wrong board")
	var/list/curio_points = SSresearch.techweb_point_items[/obj/item/relic]
	TEST_ASSERT_EQUAL(curio_points?[TECHWEB_POINT_TYPE_GENERIC], 60, "the strange object pays no research in the destructive analyzer")

/**
 * Every design the xenoarchaeology nodes list exists. The dig, use and trade parts define most of
 * them, so this only passes once all the parts are together; a failure names the id to rename.
 */
/datum/unit_test/voidcrew_xenoarch_study_node_designs/Run()
	var/list/expected = list(
		"xenoarchaeology" = list("xenoarch_analyser", "xenoarch_scanpad", "xenoarch_labeler", "xenoarch_stabiliser", "xenoarch_spectrometer", "xenoarch_specimen_crate"),
		"xenoarch_excavation" = list("xenoarch_scanner_advanced", "xenoarch_brush_quick"),
		"xenoarch_exotic_particles" = list("xenoarch_harvester", "xenoarch_battery", "xenoarch_utilizer"),
	)
	for(var/node_id in expected)
		var/datum/techweb_node/node = SSresearch.techweb_node_by_id(node_id)
		for(var/design_id in expected[node_id])
			TEST_ASSERT_NOTNULL(SSresearch.techweb_designs[design_id], "[node_id] lists design [design_id], which no part defines")
			TEST_ASSERT(design_id in node?.design_ids, "[node_id] lost design [design_id]")
