/**
 * Shared fixtures for the outpost prison tests: a loaded claim with a placed prison wing, prisoners
 * booked in by hand, waits for beams and window doors, and the trouble tests' claim and helpers.
 * Each prison test file keeps any further helpers of its own in that file.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers.
 */

/// Records every static data push, since a test world has no client to show the refresh screen
/datum/player_outpost_management_ui/management_test/push_log
	var/list/push_times = list()

/datum/player_outpost_management_ui/management_test/push_log/update_static_data_for_all_viewers()
	push_times += world.time
	return ..()

/// Sleeps until `panel` has made `count` pushes or `timeout` passes
/datum/unit_test/voidcrew_outpost_management/proc/wait_for_pushes(datum/player_outpost_management_ui/management_test/push_log/panel, count, timeout = 3 SECONDS)
	var/deadline = world.time + timeout
	while(length(panel.push_times) < count && world.time < deadline)
		sleep(1)
	return length(panel.push_times) >= count

// ===== PRISON FIXTURE =====

/// A loaded claim with a running prison wing placed north of its shell, unrotated, so authored
/// map coordinates apply. The prison's own clock is stopped; tests drive it with tick(). Trouble
/// (threats, fights, riots, escapes) is off, so these tests see the quiet side on its own;
/// trouble_test_claim() turns it back on. The wing is drawn in `style`, by default the test
/// claim's own (the default style's): every style's wing is the same tile for tile.
/datum/unit_test/voidcrew_outpost_management/proc/prison_test_claim(owner_key, style)
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim(owner_key)
	if(!home)
		TEST_NOTICE(src, "The test claim for [owner_key] did not load")
		return null
	if(style)
		home.outpost_style = style
	var/datum/outpost_upgrade/prison/blueprint = new(home)
	home.outpost_upgrades["prison"] = blueprint
	var/turf/bottom_left = locate(home.template_bottom_left.x, home.template_bottom_left.y + home.shell_template.height + 3, home.upgrade_level_z())
	var/refusal = home.place_outpost_upgrade(blueprint, bottom_left, 0, null)
	if(refusal || !blueprint.prison)
		// Rare and not reproduced on a rerun: say what was in the way, as the cargo dock tests do.
		TEST_NOTICE(src, "The test prison for [owner_key] was not built: [refusal || "no prison"] [refusal == "Position obstructed." ? cargo_dock_blocker(home, blueprint, bottom_left, 0) : ""]")
		return null
	STOP_PROCESSING(SSprocessing, blueprint.prison)
	blueprint.prison.pay_clock = 0
	blueprint.prison.pay_owed = 0
	blueprint.prison.trouble_enabled = FALSE
	// Random incidents and wing events would land in the middle of other tests; their own tests turn them on.
	blueprint.prison.wildcards_enabled = FALSE
	blueprint.prison.wing_events_enabled = FALSE
	home.ensure_home_services()
	return home

/datum/unit_test/voidcrew_outpost_management/proc/test_prison(obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_upgrade/prison/blueprint = home.outpost_upgrades["prison"]
	return blueprint.prison

/// A tile of the unrotated wing by its authored map coordinates (1,1 is the south-west corner)
/datum/unit_test/voidcrew_outpost_management/proc/prison_spot(obj/structure/overmap/dynamic/player_outpost/home, x, y)
	var/datum/outpost_upgrade/prison/blueprint = home.outpost_upgrades["prison"]
	var/list/bounds = blueprint.footprint_bounds
	return locate(bounds[1] + x - 1, bounds[2] + y - 1, bounds[5])

/// A prisoner booked into the first free cell by hand, standing still at `spot`, fed and in a clean uniform
/datum/unit_test/voidcrew_outpost_management/proc/test_prisoner(datum/outpost_prison/prison, turf/spot)
	var/mob/living/basic/outpost_prisoner/prisoner = new(spot)
	prison.admit(prisoner)
	prisoner.sentence_left = 3600
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(0)
	ADD_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	return prisoner

/// Lets a freshly placed wing's air go idle before the claim is torn down
/datum/unit_test/voidcrew_outpost_management/proc/settle_prison_air(obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_upgrade/prison/blueprint = home.outpost_upgrades["prison"]
	var/list/bounds = blueprint?.footprint_bounds
	if(!bounds)
		return
	var/settle_until = world.time + 30 SECONDS
	while(world.time < settle_until)
		var/busy = FALSE
		for(var/turf/open/room_turf in block(bounds[1] - 1, bounds[2] - 1, bounds[5], bounds[3] + 1, bounds[4] + 1, bounds[5]))
			if(room_turf.excited)
				busy = TRUE
				break
		if(!busy)
			break
		sleep(1 SECONDS)

/// Sleeps until `condition` holds or `timeout` passes; returns whether it held
/datum/unit_test/voidcrew_outpost_management/proc/wait_until(datum/callback/condition, timeout = 5 SECONDS)
	var/deadline = world.time + timeout
	while(!condition.Invoke() && world.time < deadline)
		sleep(1)
	return condition.Invoke()

/datum/unit_test/voidcrew_outpost_management/proc/windoor_open(obj/machinery/door/window/windoor)
	return windoor && !windoor.density && !windoor.operating

/// Keeps a prisoner reaching for `thing` (opening a hatch as needed) until they can, or 12 seconds pass
/datum/unit_test/voidcrew_outpost_management/proc/reach_until_ok(mob/living/basic/outpost_prisoner/prisoner, obj/item/thing)
	var/deadline = world.time + 12 SECONDS
	while(world.time < deadline)
		if(prisoner.try_reach(thing) == 1) // PRISONER_REACH_OK
			return TRUE
		sleep(2)
	return prisoner.try_reach(thing) == 1

/**
 * Plays one activity to its end as the AI would, with walks done by teleport. Returns what the
 * last tick returned (1 done), or 0 if it ran out of steps.
 */
/datum/unit_test/voidcrew_outpost_management/proc/drive_activity(mob/living/basic/outpost_prisoner/prisoner, datum/prisoner_activity/activity, steps = 40, list/walked)
	for(var/i in 1 to steps)
		if(QDELETED(activity) || prisoner.activity != activity)
			return 1
		if(activity.spot && prisoner.loc != activity.spot)
			walked?.Add(activity.spot)
			prisoner.stand_up()
			prisoner.forceMove(activity.spot)
		if(activity.spot || !activity.started)
			if(!activity.arrive())
				prisoner.end_activity(cancel_ai = FALSE)
				return 1
			continue
		var/result = activity.tick(1)
		if(result == 1) // ACTIVITY_DONE
			prisoner.end_activity(cancel_ai = FALSE)
			return 1
		if(result == 0) // ACTIVITY_CONTINUE
			sleep(1)
	return 0

/// Whether the datum behind a weakref is gone
/proc/is_qdeleted_ref(datum/weakref/ref)
	var/datum/thing = ref?.resolve()
	return QDELETED(thing)

// ===== TROUBLE FIXTURE =====

/// A prison claim with trouble switched on and every bulb working
/datum/unit_test/voidcrew_outpost_management/proc/trouble_test_claim(owner_key)
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim(owner_key)
	if(!home)
		return null
	var/datum/outpost_prison/prison = test_prison(home)
	prison.trouble_enabled = TRUE
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(fixture.status != LIGHT_OK)
				fixture.fix()
	prison.refresh_conditions()
	return home

/// A prisoner with a known personality at mood 70, booked in and standing still at `spot`
/datum/unit_test/voidcrew_outpost_management/proc/trouble_prisoner(datum/outpost_prison/prison, turf/spot, personality = "chatty")
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, spot)
	prisoner.personality = personality
	prisoner.set_mood(70)
	return prisoner

/datum/unit_test/voidcrew_outpost_management/proc/drift_is(mob/living/basic/outpost_prisoner/prisoner, expected)
	return abs(prisoner.mood_drift_per_minute() - expected) < 0.01

/datum/unit_test/voidcrew_outpost_management/proc/set_moods(list/prisoners, mood)
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in prisoners)
		prisoner.set_mood(mood)

/datum/unit_test/voidcrew_outpost_management/proc/all_lights(datum/outpost_prison/prison)
	var/list/lights = list()
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			lights += fixture
	return lights

/datum/unit_test/voidcrew_outpost_management/proc/set_wing_power(datum/outpost_prison/prison, on)
	var/obj/machinery/power/apc/apc = prison.wing.apc
	apc.operating = on
	apc.update()
	prison.refresh_conditions()

/datum/unit_test/voidcrew_outpost_management/proc/hit_with_toolbox(mob/living/carbon/human/attacker, mob/living/target)
	var/obj/item/storage/toolbox/toolbox = attacker.get_active_held_item()
	if(!istype(toolbox))
		attacker.drop_all_held_items()
		toolbox = allocate(/obj/item/storage/toolbox)
		attacker.put_in_active_hand(toolbox)
	attacker.set_combat_mode(TRUE)
	click_wrapper(attacker, target)
	attacker.set_combat_mode(FALSE)

/// Whether `line` is one of the dialogue file's lines for `context`, for any personality
/datum/unit_test/voidcrew_outpost_management/proc/is_line_for(line, context)
	var/list/lines = outpost_prisoner_dialogue("lines")
	var/list/entry = lines[context]
	if(!islist(entry) || !line)
		return FALSE
	for(var/pool_key in entry)
		for(var/candidate in entry[pool_key])
			if(findtext(candidate, "{"))
				// A line with placeholders: compare what is left of it around them.
				var/list/parts = splittext(candidate, regex("\\{\[a-z_\]+\\}"))
				var/all_found = TRUE
				for(var/part in parts)
					if(length(part) && !findtext(line, part))
						all_found = FALSE
						break
				if(all_found)
					return TRUE
			else if(candidate == line)
				return TRUE
	return FALSE
