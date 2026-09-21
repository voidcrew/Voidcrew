/**
 * # Dynamic event roster conformance
 *
 * SSdynamic_events rolls a weighted roster of ~54 ship-scoped events. An event
 * that fires with no announcement and no ghost notification is not a quiet
 * event, it is an invisible one: something changes aboard a ship and nobody.
 * Crew, observers, or the round log. Is told. "Ship Camera Failure" shipped
 * that way at weight 100 out of 753, so one roll in seven said nothing at all.
 *
 * The invariant this pins: **an event that can be rolled must be observable.**
 * Either the control alerts observers, or the event overrides announce()
 * somewhere in its type chain. Admin-only controls (weight 0) are exempt.
 * They are never rolled, and whoever fired one already knows.
 *
 * DM cannot ask whether a type overrides a proc, so the announce() overrides
 * are read out of the source text. The scan asserts on its own hit count so a
 * format change fails loudly instead of turning the test into a no-op.
 */

/// Source roots that declare /datum/round_event/voidcrew subtypes.
#define DYNAMIC_EVENT_SOURCE_ROOTS list("voidcrew/modules/dynamic_events/", "voidcrew/modules/colosseum/")

/datum/unit_test/voidcrew_dynamic_event_observability
	priority = TEST_LONGER

/datum/unit_test/voidcrew_dynamic_event_observability/Run()
	var/list/sources = list()
	for(var/root in DYNAMIC_EVENT_SOURCE_ROOTS)
		vc_test_collect_dm_files(root, sources)
	TEST_ASSERT(length(sources) > 20, "the dynamic-event source scan found only [length(sources)] .dm files, wrong roots?")

	var/list/announcers = list()
	for(var/file_path in sources)
		for(var/line in splittext(sources[file_path], "\n"))
			if(findtextEx(line, "/datum/round_event/voidcrew") != 1)
				continue
			var/announce_at = findtextEx(line, "/announce(")
			if(!announce_at)
				continue
			var/event_path = text2path(copytext(line, 1, announce_at))
			if(event_path)
				announcers[event_path] = TRUE
	TEST_ASSERT(length(announcers) > 10, "the announce() scan matched only [length(announcers)] event types. The source format changed and this test is no longer checking anything")

	var/list/seen_typepaths = list()
	var/controls_checked = 0
	for(var/datum/round_event_control/voidcrew/control_type as anything in subtypesof(/datum/round_event_control/voidcrew))
		var/datum/round_event/voidcrew/event_type = initial(control_type.typepath)
		if(!event_type)
			continue // abstract; SSevents drops controls with no typepath
		if(!ispath(event_type, /datum/round_event/voidcrew))
			TEST_FAIL("[control_type] has typepath [event_type], which is not a /datum/round_event/voidcrew subtype. It would fire outside the ship-scoping framework entirely")
			continue
		if(seen_typepaths[event_type])
			TEST_FAIL("[control_type] shares typepath [event_type] with [seen_typepaths[event_type]]; two controls firing one event double its real weight in the roster")
		seen_typepaths[event_type] = control_type
		controls_checked++

		var/weight = initial(control_type.weight)
		if(weight <= 0)
			continue // admin-only: never rolled, and the admin who fired it knows
		if(initial(control_type.max_occurrences) <= 0)
			TEST_FAIL("[control_type] carries weight [weight] but max_occurrences 0. can_spawn_event() refuses it every time (occurrences >= max_occurrences is true from the start), so all it does is take roster weight away from events that can actually fire. Drop the weight to 0 like the other admin-only controls.")
		if(initial(control_type.alert_observers))
			continue

		var/announces = FALSE
		var/check_type = event_type
		while(check_type && check_type != /datum/round_event)
			if(announcers[check_type])
				announces = TRUE
				break
			check_type = type2parent(check_type)
		if(!announces)
			TEST_FAIL("[control_type] rolls at weight [weight] with alert_observers FALSE and no announce() override anywhere in [event_type]'s chain, so it fires completely invisibly. Give it an announcement (target_ship.ship_event_announce) or let it alert observers.")
	TEST_ASSERT(controls_checked > 30, "only [controls_checked] dynamic-event controls were checked. The roster walk is not seeing the module")

#undef DYNAMIC_EVENT_SOURCE_ROOTS
