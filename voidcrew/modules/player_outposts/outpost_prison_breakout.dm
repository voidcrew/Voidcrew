/**
 * # Prison riots: breaking out
 *
 * From the first blow of a riot, a rioter's main goal is a way out of the cell block: a staff door,
 * a serving hatch, or a window or grille between the cell block and the rest of the wing (never a
 * cell door, and never anything in the wing's outer wall). Each rioter picks the nearest one they can
 * get at, counting the rioters already at each as PRISON_RIOT_EXIT_SPREAD tiles farther so they
 * spread out, and at most PRISON_RIOT_EXIT_CROWD work at one door or window (one at a hatch). They
 * hammer at it with their shivs until it gives:
 * - a staff airlock takes PRISON_RIOT_DOOR_DAMAGE a blow. Broken down it leaves nothing in the
 *   doorway (outpost_prison_doors.dm); an airlock built there becomes a staff door again.
 * - at a serving hatch the office side's window door takes PRISON_RIOT_WINDOOR_DAMAGE a blow,
 *   although it is outpost property that nothing else can damage. When it shatters the hatch is
 *   forced open and climbed. A window door built on the hatch facing either side becomes the
 *   hatch's own again (restore_hatch_windoor()).
 * - a window and then its grille take PRISON_RIOT_WINDOW_DAMAGE a blow.
 * The blows do real damage only while the crew is home (crew_home()). With nobody home they only
 * boom, and nobody walks out through a gap: the clocks that decide how bad a riot gets wait for the
 * crew. Broken doors and windows stay broken until the crew repairs or replaces them.
 *
 * Once a way is open, rioters go through it (escape_spot()), and anyone outside the cell block on
 * their own feet has escaped, as any escape (outpost_prison_riot.dm): the loose clock, recapture,
 * the fines. The first damaging blow at each way out is announced, once a riot.
 *
 * Fixtures (lights, tables, windows inside the cell block) are the side activity: with no way out
 * they can get at, while waiting their turn at a crowded one, and now and then on the way
 * (riot_detour_chance). In the breakout every rioter goes for the ways out, crowded or not.
 */

/datum/outpost_prison
	/// Exit tiles rioters have started on this riot (turf = TRUE): each is announced once
	var/list/riot_exits_alerted = list()
	/// Ways out waiting to be announced, as "the staff door", "a serving hatch", "a window"
	var/list/exit_alert_queue = list()
	/// Seconds before another such alert may go out
	var/exit_alert_wait = 0
	/// Percent chance a rioter picking a new target smashes a fixture on the way; tests pin it
	var/riot_detour_chance = PRISON_RIOT_DETOUR_CHANCE

// ===== THE WAYS OUT =====

/// Whether a tile is a way out of the cell block: on its edge, with the rest of the wing beyond, and not in the wing's outer wall
/datum/outpost_prison/proc/is_exit_tile(turf/tile)
	return tile && cell_block[tile] && !on_wing_edge(tile) && leads_out_of_cell_block(tile)

/**
 * What stands in the way on an exit tile, the thing a rioter hits: the serving hatch, a window, then
 * its grille, then a door they cannot get through or the wreck of one. Never a cell door. Null once
 * the way is open.
 */
/datum/outpost_prison/proc/exit_blocker(turf/tile)
	if(!tile)
		return null
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in tile
	if(hatch)
		return hatch
	for(var/obj/structure/window/pane in tile)
		if(pane.density)
			return pane
	for(var/obj/structure/grille/grille in tile)
		if(grille.density)
			return grille
	for(var/obj/machinery/door/airlock/door in tile)
		if(is_cell_door(door))
			return null
		// Open or shut, a prisoner never walks through a staff door on their own.
		if(istype(door, /obj/machinery/door/airlock/security/prison_staff) || door.density)
			return door
	var/obj/structure/door_assembly/frame = locate() in tile
	return frame

/// Whether `thing` is what stands in the way on a way out of the cell block
/datum/outpost_prison/proc/is_exit_blocker(atom/thing)
	if(!isobj(thing))
		return FALSE
	var/turf/tile = get_turf(thing)
	return is_exit_tile(tile) && exit_blocker(tile) == thing

/**
 * The ways out a rioter can get at, exit tile = its blocker: tiles on the cell block's edge beside
 * ground they can walk, whose blocker they have not given up on for now.
 */
/datum/outpost_prison/proc/exit_tiles(mob/living/basic/outpost_prisoner/rioter)
	var/list/exits = list()
	for(var/turf/tile as anything in rioter.reachable)
		if(rioter.walkable?[tile] || !is_exit_tile(tile))
			continue
		var/atom/blocker = exit_blocker(tile)
		if(!blocker || LAZYACCESS(rioter.riot_skips, REF(blocker)) > world.time)
			continue
		exits[tile] = blocker
	return exits

/// How many rioters can work at a way out at once: one at a serving hatch, PRISON_RIOT_EXIT_CROWD elsewhere
/datum/outpost_prison/proc/exit_room(atom/blocker)
	return istype(blocker, /obj/structure/table/reinforced/prison_hatch) ? 1 : PRISON_RIOT_EXIT_CROWD

/// How many rioters other than `except`, on their feet, are working at the way out on `tile`
/datum/outpost_prison/proc/rioters_at_exit(turf/tile, mob/living/basic/outpost_prisoner/except)
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(other == except || !other.is_rioting() || !other.trouble_can_act())
			continue
		var/atom/target = other.riot_target_ref?.resolve()
		if(target && !isturf(target) && get_turf(target) == tile)
			count++
	return count

/**
 * The way out a rioter goes for, from `exits` (exit_tiles()): the nearest, counting each rioter
 * already at one as PRISON_RIOT_EXIT_SPREAD tiles farther and a window as PRISON_RIOT_WINDOW_BIAS
 * farther than a door. One with no room left (exit_room()) is passed over unless `crowded_ok`.
 * Null if none will do.
 */
/datum/outpost_prison/proc/choose_exit(mob/living/basic/outpost_prisoner/rioter, list/exits, crowded_ok = FALSE)
	var/turf/best
	var/best_score = INFINITY
	for(var/turf/tile as anything in exits)
		var/atom/blocker = exits[tile]
		var/others = rioters_at_exit(tile, rioter)
		if(!crowded_ok && others >= exit_room(blocker))
			continue
		var/score = get_dist(rioter, tile) + others * PRISON_RIOT_EXIT_SPREAD
		if(istype(blocker, /obj/structure/window) || istype(blocker, /obj/structure/grille))
			score += PRISON_RIOT_WINDOW_BIAS
		if(score < best_score)
			best = tile
			best_score = score
	return best

// ===== FIXTURES =====

/// Whether `thing` on `tile` is one of the wing's fixtures a rioter smashes: a working light, a table, or a window or grille inside the cell block
/datum/outpost_prison/proc/is_riot_fixture(obj/thing, turf/tile)
	if(istype(thing, /obj/machinery/light))
		var/obj/machinery/light/fixture = thing
		return fixture.status != LIGHT_BROKEN
	if(istype(thing, /obj/structure/table/reinforced/prison_hatch))
		return FALSE
	if(istype(thing, /obj/structure/table))
		return TRUE
	if(istype(thing, /obj/structure/window) || istype(thing, /obj/structure/grille))
		// The wing's outer wall is left alone, and the ways out are not fixtures.
		return !on_wing_edge(tile) && !leads_out_of_cell_block(tile)
	return FALSE

/**
 * A fixture for a rioter to smash: one within PRISON_RIOT_DETOUR_RANGE tiles of `near` if there is
 * one, else any they can reach, or null with `near_only`.
 */
/datum/outpost_prison/proc/pick_fixture(mob/living/basic/outpost_prisoner/rioter, turf/near, near_only = FALSE)
	var/list/found = list()
	var/list/close = list()
	for(var/turf/tile as anything in rioter.reachable)
		for(var/obj/thing in tile)
			if(QDELETED(thing) || LAZYACCESS(rioter.riot_skips, REF(thing)) > world.time || !is_riot_fixture(thing, tile))
				continue
			found += thing
			if(near && get_dist(near, tile) <= PRISON_RIOT_DETOUR_RANGE)
				close += thing
	if(length(close))
		return pick(close)
	if(near_only)
		return null
	return length(found) ? pick(found) : null

// ===== CHOOSING =====

/**
 * A new target for a rioter. Built turrets first (outpost_prison_security.dm); then a way out
 * (choose_exit()), now and then with a fixture on the way first (riot_detour_chance); with every way
 * out crowded, a fixture near the one they want while they wait their turn; with none they can get
 * at, the wing's fixtures. Breaking out, they go for the ways out, crowded or not, and never stop
 * for a fixture on the way.
 */
/datum/outpost_prison/proc/pick_smash_target(mob/living/basic/outpost_prisoner/rioter)
	var/atom/priority = priority_smash_target(rioter)
	if(priority)
		return priority
	var/breakout = rioter.trouble == PRISONER_TROUBLE_BREAKOUT
	var/list/exits = exit_tiles(rioter)
	var/turf/exit = choose_exit(rioter, exits, crowded_ok = breakout)
	if(exit)
		if(!breakout && prob(riot_detour_chance))
			var/atom/detour = pick_fixture(rioter, get_turf(rioter), near_only = TRUE)
			if(detour)
				return detour
		return exits[exit]
	if(length(exits))
		var/turf/wanted = choose_exit(rioter, exits, crowded_ok = TRUE)
		return pick_fixture(rioter, wanted) || exits[wanted]
	return pick_fixture(rioter)

/// Whether a rioter can make for `tile` to get out: walkable for them, in the wing, outside the cell block, and not given up on
/datum/outpost_prison/proc/escape_spot_ok(turf/tile, mob/living/basic/outpost_prisoner/rioter)
	return isturf(tile) && tile.loc == wing && !cell_block[tile] && rioter.walkable?[tile] && LAZYACCESS(rioter.riot_skips, REF(tile)) <= world.time

/**
 * Where a rioter goes once a way out of the cell block is open: the nearest tile outside it they
 * can walk to, keeping the one they chose while it still works, and preferring one nobody stands on.
 * Null with nobody home, so the rioters stay in the yard, and in a wing with no cells.
 */
/datum/outpost_prison/proc/escape_spot(mob/living/basic/outpost_prisoner/rioter)
	if(!length(cell_block) || !length(rioter.walkable) || !crew_home())
		return null
	var/turf/chosen = rioter.riot_target_ref?.resolve()
	if(isturf(chosen) && escape_spot_ok(chosen, rioter))
		return chosen
	var/turf/here = get_turf(rioter)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in rioter.walkable)
		if(!escape_spot_ok(tile, rioter))
			continue
		var/distance = get_dist(here, tile) + (rioter.tile_taken(tile) ? 2 : 0)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

// ===== BREAKING THROUGH =====

/// What the crew is told a way out is: "the staff door", "a serving hatch" or "a window"
/datum/outpost_prison/proc/exit_label(atom/blocker)
	if(istype(blocker, /obj/structure/table/reinforced/prison_hatch))
		return "a serving hatch"
	if(istype(blocker, /obj/structure/window) || istype(blocker, /obj/structure/grille))
		return "a window"
	return "the staff door"

/**
 * A rioter's blow at a way out. With the crew home it does real damage, and the first such blow at
 * each way out this riot is announced; with nobody home it only booms. When the way gives, everyone's
 * reach is worked out again so the rioters see the gap. Returns TRUE.
 */
/datum/outpost_prison/proc/hit_exit(mob/living/basic/outpost_prisoner/rioter, obj/target)
	var/turf/tile = get_turf(target)
	rioter.trouble_line("riot_break_door", fallback = "riot")
	if(!crew_home())
		playsound(target, 'sound/effects/bang.ogg', 50, TRUE)
		target.Shake(1, 1, 0.3 SECONDS)
		return TRUE
	var/label = exit_label(target)
	note_exit_attacked(tile, label)
	var/broke = FALSE
	var/obj/structure/table/reinforced/prison_hatch/hatch = target
	if(istype(hatch))
		broke = hatch.take_rioter_blow(rioter)
	else
		var/damage = PRISON_SMASH_DAMAGE
		if(istype(target, /obj/machinery/door))
			damage = PRISON_RIOT_DOOR_DAMAGE
			target.Shake(1, 1, 0.3 SECONDS)
		else if(istype(target, /obj/structure/window) || istype(target, /obj/structure/grille))
			damage = PRISON_RIOT_WINDOW_DAMAGE
		target.take_damage(damage * rioter.bounty_breakout_mult(), BRUTE, "", TRUE, get_dir(target, rioter))
		broke = !exit_blocker(tile)
	if(broke)
		exit_broken(label)
	return TRUE

/// A way out gave: logged, and every prisoner's reach is worked out again at once
/datum/outpost_prison/proc/exit_broken(label)
	add_log("The rioters broke through [label].")
	refresh_reach()

/// A rioter started on a way out: announced once a riot, together with any others started meanwhile
/datum/outpost_prison/proc/note_exit_attacked(turf/tile, label)
	if(riot_exits_alerted[tile])
		return FALSE
	riot_exits_alerted[tile] = TRUE
	exit_alert_queue |= label
	return TRUE

/// Advances the alerts by `seconds`: the ways out queued by note_exit_attacked() go out as one alert, at most one per PRISON_EXIT_ALERT_GAP seconds
/datum/outpost_prison/proc/exit_alert_tick(seconds)
	exit_alert_wait = max(0, exit_alert_wait - seconds)
	if(!length(exit_alert_queue) || exit_alert_wait > 0)
		return FALSE
	exit_alert_wait = PRISON_EXIT_ALERT_GAP
	var/where = english_list(exit_alert_queue)
	exit_alert_queue.Cut()
	add_log("Rioters are breaking at [where].")
	announce("Prison wing: rioters are breaking at [where].", SHIP_NOTIFY_DANGER)
	return TRUE

/// A new riot: every way out may be announced again
/datum/outpost_prison/proc/reset_exit_alerts()
	riot_exits_alerted.Cut()
	exit_alert_queue.Cut()

// ===== THE SERVING HATCH =====

/obj/structure/table/reinforced/prison_hatch
	/// The way the yard side's window door faces: toward the yard. Kept for when that door is gone.
	var/yard_dir

/**
 * A rioter's blow from the yard side. The office side's window door takes it; when it shatters the
 * hatch is forced open (force_open()). With the office side already open or gone, the yard side opens
 * for them, or takes the blow if it cannot open. Returns TRUE if the office side gave.
 */
/obj/structure/table/reinforced/prison_hatch/proc/take_rioter_blow(mob/living/basic/outpost_prisoner/rioter)
	playsound(src, 'sound/effects/glass/glassbash.ogg', 50, TRUE)
	var/obj/machinery/door/window/staff_door = staff_windoor()
	if(staff_door?.density)
		staff_door.Shake(1, 1, 0.3 SECONDS)
		staff_door.take_rioter_damage(PRISON_RIOT_WINDOOR_DAMAGE * rioter.bounty_breakout_mult(), get_dir(staff_door, rioter))
		if(!QDELETED(staff_door))
			return FALSE
		visible_message(span_danger("The office side of [src] gives way!"))
		force_open()
		return TRUE
	var/obj/machinery/door/window/yard_door = yard_windoor()
	if(yard_door?.density && !open_for_prisoner(rioter) && !yard_door.operating && (!yard_door.hasPower() || !yard_door.allowed(rioter)))
		yard_door.Shake(1, 1, 0.3 SECONDS)
		yard_door.take_rioter_damage(PRISON_RIOT_WINDOOR_DAMAGE, get_dir(yard_door, rioter))
	return FALSE

/// What a riot left of its window doors, for examining the hatch
/obj/structure/table/reinforced/prison_hatch/proc/windoor_examine()
	. = list()
	var/obj/machinery/door/window/staff_door = staff_windoor()
	if(!staff_door)
		. += span_warning("The office side's window door has been smashed out.")
	else if(staff_door.get_integrity() < staff_door.max_integrity)
		. += span_warning("The office side's window door is [staff_door.get_integrity() < staff_door.max_integrity / 2 ? "badly " : ""]cracked.")
	if(!yard_windoor())
		. += span_warning("The yard side's window door is missing.")

// ===== WINDOW DOORS =====

/// Whether `thing` is one of the serving hatch's own window doors
/proc/is_outpost_prison_windoor(atom/thing)
	return istype(thing, /obj/machinery/door/window/outpost_prison_yard) || istype(thing, /obj/machinery/door/window/brigdoor/outpost_prison_staff)

/**
 * A rioter's blow. A serving hatch's window doors are outpost property that nothing else can
 * damage; a rioter's blows wear them down all the same, and at nothing they shatter.
 */
/obj/machinery/door/window/proc/take_rioter_damage(damage, attack_dir)
	if(!(resistance_flags & INDESTRUCTIBLE))
		take_damage(damage, BRUTE, "", TRUE, attack_dir)
		return
	play_attack_sound(damage)
	update_integrity(get_integrity() - damage)
	if(get_integrity() <= 0)
		deconstruct(FALSE)

/// "It looks slightly damaged." and so on, as for any machine, for fixtures whose outpost property hides it
/proc/outpost_prison_damage_examine(obj/thing)
	if(!thing.max_integrity || thing.get_integrity() >= thing.max_integrity)
		return null
	var/percent = thing.get_integrity() / thing.max_integrity * 100
	if(percent >= 50)
		return "It looks slightly damaged."
	if(percent >= 25)
		return "It appears heavily damaged."
	return span_warning("It's falling apart!")

/obj/machinery/door/window/outpost_prison_yard/examine(mob/user)
	. = ..()
	var/damage = outpost_prison_damage_examine(src)
	if(damage)
		. += damage

/obj/machinery/door/window/brigdoor/outpost_prison_staff/examine(mob/user)
	. = ..()
	var/damage = outpost_prison_damage_examine(src)
	if(damage)
		. += damage

/**
 * A window door built on a serving hatch, where one of its own was smashed out, becomes that one
 * again: facing the yard, the yard side; facing away from it, the office side. It keeps the
 * builder's electronics. Anything else built there stays as it is.
 */
/datum/outpost_prison/proc/restore_hatch_windoor(obj/machinery/door/window/built)
	if(QDELETED(built) || QDELETED(src) || is_outpost_prison_windoor(built))
		return null
	var/turf/tile = built.loc
	if(!isturf(tile))
		return null
	var/obj/structure/table/reinforced/prison_hatch/hatch = locate(/obj/structure/table/reinforced/prison_hatch) in tile
	if(!hatch)
		return null
	// Looks the doors up, so the hatch knows its facing
	hatch.yard_windoor()
	hatch.staff_windoor()
	if(!hatch.yard_dir)
		return null
	var/restored_type
	if(built.dir == hatch.yard_dir && !hatch.yard_windoor())
		restored_type = /obj/machinery/door/window/outpost_prison_yard
	else if(built.dir == REVERSE_DIR(hatch.yard_dir) && !hatch.staff_windoor())
		restored_type = /obj/machinery/door/window/brigdoor/outpost_prison_staff
	if(!restored_type)
		return null
	var/obj/machinery/door/window/restored = new restored_type(tile, built.dir)
	if(built.electronics)
		var/obj/item/electronics/airlock/parts = built.electronics
		built.electronics = null
		restored.electronics = parts
		parts.forceMove(restored)
	qdel(built)
	add_log("A new window door was fitted to a serving hatch.")
	return restored

/// Watches the serving hatches' tiles, so a window door built on one is noticed (restore_hatch_windoor())
/datum/outpost_prison/proc/watch_hatch_turfs()
	for(var/turf/tile as anything in wing_turfs())
		var/obj/structure/table/reinforced/prison_hatch/hatch = locate() in tile
		if(!hatch)
			continue
		hatch.yard_windoor()
		hatch.staff_windoor()
		watch_door_turf(tile)
