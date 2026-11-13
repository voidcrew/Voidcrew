/**
 * Shared fixtures for the lockup tests: a bare trader outpost with the fixture wing loaded, prisoners
 * booked in by hand, waits for beams and window doors, and the trouble tests' fixture and helpers.
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

/// The fixture wing: 17 x 16, four cells, a yard, an office behind a staff door and two hatches. The tests read
/// its layout tile for tile (prison_spot()).
/datum/map_template/trade_prison_test_wing
	name = "Lockup test wing"
	mappath = "voidcrew/_maps/map_files/unit_tests/trade_prison_test_wing.dmm"

/// A bare trader outpost (no interior of its own, as allocate() makes one) that hosts the fixture wing
/obj/structure/overmap/trader_outpost/prison_test_host
	/// The wing's prison (test_prison())
	var/datum/outpost_prison/unit_test/fixture_prison
	/// The loaded wing's south-west tile, and the block it was loaded into
	var/turf/wing_corner
	var/datum/turf_reservation/wing_reservation

/obj/structure/overmap/trader_outpost/prison_test_host/Destroy()
	QDEL_NULL(fixture_prison)
	QDEL_NULL(wing_reservation)
	wing_corner = null
	return ..()

/**
 * The fixture's prison. No player is staff or an inmate of a real wing yet, so the tests' player (the one
 * made with the key the fixture was asked for) stands in for both: whatever the wing lets its staff or an
 * inmate do, they may do. Everyone else is judged as in the game.
 */
/datum/outpost_prison/unit_test
	/// The key of the tests' player
	var/member_key

/datum/outpost_prison/unit_test/proc/is_test_member(mob/person)
	return ismob(person) && !!member_key && !!person.ckey && person.ckey == ckey(member_key)

/datum/outpost_prison/unit_test/is_staff(mob/person)
	return is_test_member(person) || ..()

/datum/outpost_prison/unit_test/is_inmate(mob/person)
	return is_test_member(person) || ..()

/**
 * A bare trader outpost with the fixture wing loaded into a block of its own, unrotated, so authored map
 * coordinates apply, and a prison running on the wing's area. The prison's own clock is stopped; tests
 * drive it with tick(). Intake is shut and trouble (threats, fights, riots, escapes), wildcards and wing
 * events are off, so these tests see the quiet side on its own; trouble_test_claim() turns trouble back
 * on. The wing does not keep itself either: no galley, no standing roster of guards, no cleanbot, and
 * its dead lie where they fell, so each test stocks, staffs and clears what it is about; the tests of
 * those things turn them on. Somebody is always there to see it (audience_override): a test world has no clients. The fixture
 * wing draws its power from its own APC, so the power tests still have a switch to throw; a mapped lockup
 * never loses power. `owner_key` is the key of the tests' player (see /datum/outpost_prison/unit_test);
 * `style` is ignored, there is one fixture map.
 */
/datum/unit_test/voidcrew_outpost_management/proc/prison_test_claim(owner_key, style)
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = allocate(/obj/structure/overmap/trader_outpost/prison_test_host)
	var/datum/map_template/trade_prison_test_wing/template = allocate(/datum/map_template/trade_prison_test_wing)
	home.wing_reservation = SSmapping.request_turf_block_reservation(template.width, template.height, 1)
	if(!home.wing_reservation)
		TEST_NOTICE(src, "No room for the test wing for [owner_key]")
		return null
	home.wing_corner = home.wing_reservation.bottom_left_turfs[1]
	if(!template.load(home.wing_corner))
		TEST_NOTICE(src, "The test wing for [owner_key] did not load")
		return null
	var/area/voidcrew/outpost_lockup/wing = get_area(locate(home.wing_corner.x + 8, home.wing_corner.y + 8, home.wing_corner.z))
	if(!istype(wing))
		TEST_NOTICE(src, "The test wing for [owner_key] has no lockup area")
		return null
	wing.requires_power = TRUE
	var/datum/outpost_prison/unit_test/prison = new(home, wing)
	prison.member_key = owner_key
	STOP_PROCESSING(SSprocessing, prison)
	prison.intake_open = FALSE
	prison.arrival_gap = 0
	prison.arrival_countdown = null
	prison.trouble_enabled = FALSE
	// Random incidents and wing events would land in the middle of other tests; their own tests turn them on.
	prison.wildcards_enabled = FALSE
	prison.wing_events_enabled = FALSE
	prison.galley_on = FALSE
	prison.roster_kept = FALSE
	prison.bot_kept = FALSE
	prison.bodies_cleared = FALSE
	prison.audience_override = TRUE
	prison.refresh_conditions()
	home.fixture_prison = prison
	return home

/datum/unit_test/voidcrew_outpost_management/proc/test_prison(obj/structure/overmap/trader_outpost/prison_test_host/home)
	return home.fixture_prison

/// A tile of the unrotated wing by its authored map coordinates (1,1 is the south-west corner)
/datum/unit_test/voidcrew_outpost_management/proc/prison_spot(obj/structure/overmap/trader_outpost/prison_test_host/home, x, y)
	return locate(home.wing_corner.x + x - 1, home.wing_corner.y + y - 1, home.wing_corner.z)

/// A prisoner booked into the first free cell by hand, standing still at `spot`, fed and in a clean uniform
/datum/unit_test/voidcrew_outpost_management/proc/test_prisoner(datum/outpost_prison/prison, turf/spot)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = new(spot)
	prison.admit(prisoner)
	prisoner.sentence_left = 3600
	prisoner.set_hunger(100)
	prisoner.set_uniform_grime(0)
	ADD_TRAIT(prisoner, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	return prisoner

/// Lets a freshly loaded wing's air go idle before the fixture is torn down
/datum/unit_test/voidcrew_outpost_management/proc/settle_prison_air(obj/structure/overmap/trader_outpost/prison_test_host/home)
	var/turf/corner = home?.wing_corner
	if(!corner)
		return
	var/settle_until = world.time + 30 SECONDS
	while(world.time < settle_until)
		var/busy = FALSE
		for(var/turf/open/room_turf in block(corner.x, corner.y, corner.z, corner.x + 16, corner.y + 15, corner.z))
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

/// Whether a prisoner is on their feet: not down in any of tg's ways (is_down())
/datum/unit_test/voidcrew_outpost_management/proc/prisoner_up(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	return !prisoner.is_down()

/// Waits for a prisoner to get up after a knockdown or stamina crit ends: tg's get_up() takes a second
/datum/unit_test/voidcrew_outpost_management/proc/wait_until_up(mob/living/carbon/human/npc/outpost_prisoner/prisoner, timeout = 5 SECONDS)
	return wait_until(CALLBACK(src, PROC_REF(prisoner_up), prisoner), timeout)

/**
 * Lets `hitter` swing again at once, as click_wrapper() does for a player: its melee cooldown, and
 * ClickOn()'s one click a tick, which would drop a second blow in the same tick.
 */
/proc/outpost_prison_test_ready_blow(mob/living/hitter)
	hitter.next_move = 0
	hitter.next_click = 0

/datum/unit_test/voidcrew_outpost_management/proc/windoor_open(obj/machinery/door/window/windoor)
	return windoor && !windoor.density && !windoor.operating

/// Keeps a prisoner reaching for `thing` (opening a hatch as needed) until they can, or 12 seconds pass
/datum/unit_test/voidcrew_outpost_management/proc/reach_until_ok(mob/living/carbon/human/npc/outpost_prisoner/prisoner, obj/item/thing)
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
/datum/unit_test/voidcrew_outpost_management/proc/drive_activity(mob/living/carbon/human/npc/outpost_prisoner/prisoner, datum/prisoner_activity/activity, steps = 40, list/walked)
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
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim(owner_key)
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
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = test_prisoner(prison, spot)
	prisoner.personality = personality
	prisoner.set_mood(70)
	return prisoner

/datum/unit_test/voidcrew_outpost_management/proc/drift_is(mob/living/carbon/human/npc/outpost_prisoner/prisoner, expected)
	return abs(prisoner.mood_drift_per_minute() - expected) < 0.01

/datum/unit_test/voidcrew_outpost_management/proc/set_moods(list/prisoners, mood)
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner as anything in prisoners)
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

/**
 * Puts `cuffs` (an /obj/item/restraints/handcuffs, or a typepath) on `target` the way tg's cuffing ends
 * (equip_to_slot() into the handcuff slot, zipties becoming their used pair), as if a member had just
 * finished cuffing them. Returns TRUE if they are cuffed.
 */
/proc/outpost_prison_test_cuff(mob/living/carbon/target, obj/item/restraints/handcuffs/cuffs = /obj/item/restraints/handcuffs)
	if(QDELETED(target) || target.handcuffed)
		return FALSE
	if(ispath(cuffs))
		cuffs = new cuffs(target.drop_location())
	if(cuffs.trashtype)
		var/used_type = cuffs.trashtype
		qdel(cuffs)
		cuffs = new used_type(target.drop_location())
	target.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	return target.handcuffed == cuffs
