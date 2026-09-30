/**
 * # Outpost prison
 *
 * The running side of a placed prison wing, created by the prison upgrade's on_installed().
 * The wing has one cell per prisoner. While intake is open, prisoners beam one at a time into
 * empty cells. Each prisoner in the wing earns the outpost treasury OUTPOST_PRISON_BASE_PAY a
 * minute, scaled by how well they are kept (care) and how well the wing is kept (conditions); see
 * the pay model in voidcrew/_DEFINES/outpost_prison_economy.dm. At the end of a sentence the
 * prisoner heads back to their cell, beams out and a release bonus is paid.
 *
 * This file holds the wing itself, its cells, supplies and furniture, claims, speech and the
 * clock. The rest of the prison lives beside it:
 * - outpost_prison_economy.dm: pay, fines, intake, arrivals, releases, deaths;
 * - outpost_prison_warden.dm: the warden's console and its data;
 * - outpost_prison_conditions.dm: the clean, lit and powered scores and the riot strobe;
 * - outpost_prison_containment.dm: reach, the cell block, confinement and wing members;
 * - outpost_prison_doors.dm: the wing's doors and bolt buttons;
 * - outpost_prison_prisoner.dm and outpost_prison_routine.dm: the prisoners, their needs and days;
 * - outpost_prison_trouble.dm and outpost_prison_riot.dm: mood, fights, riots and escapes;
 * - outpost_prison_experiments.dm: the researcher's experiments;
 * - outpost_prison_security.dm: what turrets players build do about the prison's mobs;
 * - outpost_prison_extras.dm: where the extras (guards, reputation, pastimes, contraband, mail,
 *   leads) hook in.
 *
 * Supplies: prisoners take food and clean uniforms only from the serving hatches (or from a
 * person's hand), never off a floor or a table, so the hatches, OUTPOST_PRISON_HATCH_CAPACITY
 * items each, are the wing's only stockpile. The office Sustenance Vendor (outpost_prison_fixtures.dm)
 * sells food on the treasury; uniforms and dressings come with the room. Stocking a
 * hatch gets a call-out from the yard; a hatch left empty while prisoners wait for it is noted
 * in the warden's log.
 *
 * Everything that advances with time goes through tick(seconds), which process() calls every
 * second, so tests can advance a prison by minutes in one call. The random mess prisoners leave,
 * drips of blood and what they say come from process() alone. Beams run on timers.
 */

GLOBAL_LIST_EMPTY(outpost_prisons)

/// How often prisoners whose AI is asleep help themselves to supplies, in seconds
#define PRISON_SUPPLY_REFRESH_SECONDS 5
/// How long the wing's list of loose food is trusted before it is looked for again
#define PRISON_LOOSE_FOOD_REFRESH (3 SECONDS)
/// The largest a cell's inside can be, in tiles
#define PRISON_CELL_MAX_TILES 16

/datum/outpost_prison
	var/datum/outpost_upgrade/prison/upgrade
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/area/voidcrew/player_outpost/prison/wing
	var/list/mob/living/basic/outpost_prisoner/prisoners = list()
	/// The wing's cells, in number order
	var/list/datum/outpost_prison_cell/cells = list()
	/// Prisoners the wing holds at once: one per cell, at most OUTPOST_PRISON_MAX_CAPACITY
	var/capacity = OUTPOST_PRISON_CAPACITY
	/// Every tile of the wing's footprint and its extensions', each once, the wing's own first; see wing_turfs()
	var/list/turf/wing_block_cache
	/// Weakrefs to food lying loose in the wing off the hatches, and when that list goes stale; see loose_food()
	var/list/datum/weakref/loose_food_refs
	var/loose_food_stale_at = 0
	/// Warden console log, newest first: list(list("time", "text"))
	var/list/entries = list()
	/// Seconds since prisoners whose AI is asleep last helped themselves to supplies
	var/supply_clock = 0
	/// The wing's furniture by category ("bed", "stool", "hoop", ...), refreshed with the condition scores
	var/list/fixtures = list()
	/// REF() of anything a prisoner is using -> that prisoner
	var/list/claims = list()
	/// Prisoners waiting for food and for a clean uniform that no hatch in their reach has, as of the last supply check
	var/waiting_for_food = 0
	var/waiting_for_suits = 0
	/// Seconds until the warden's log may note an empty hatch again
	var/hatch_warning_left = 0
	/// Prisoners who sat down to eat at a mess table -> world.time, for shared meals
	var/list/table_eaters = list()
	/// world.time of each item members who cannot spend the treasury bought from the Sustenance Vendor, within the order window
	var/list/resident_orders = list()
	COOLDOWN_DECLARE(wing_speech_cooldown)
	/// Between "Food's up!" call-outs
	COOLDOWN_DECLARE(hatch_call_cooldown)
	/// Between "mess hall" lines
	COOLDOWN_DECLARE(mess_hall_cooldown)
	/// Between the mood a staff member's basket gives the players
	COOLDOWN_DECLARE(staff_basket_cooldown)

/datum/outpost_prison/New(datum/outpost_upgrade/prison/owner)
	. = ..()
	upgrade = owner
	outpost = owner.outpost
	wing = owner.installed_area
	wing.prison = src
	GLOB.outpost_prisons += src
	find_cells()
	capacity = min(OUTPOST_PRISON_MAX_CAPACITY, length(cells))
	// Whoever placed the wing, or an admin starting it again, is there now.
	last_crew_home_at = world.time
	sync_arrival_lanes()
	refresh_cell_block()
	refresh_conditions()
	START_PROCESSING(SSprocessing, src)

/datum/outpost_prison/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	extras_destroy()
	GLOB.outpost_prisons -= src
	set_riot_lights(FALSE)
	QDEL_LIST(fights)
	if(wing?.prison == src)
		wing.prison = null
	var/list/leaving = prisoners
	prisoners = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in leaving)
		close_bounty_record(prisoner, BOUNTY_RECORD_CLOSED)
		prisoner.prison = null
		prisoner.cell = null
	QDEL_LIST(leaving)
	QDEL_LIST(cells)
	claims.Cut()
	fixtures.Cut()
	cell_block.Cut()
	table_eaters.Cut()
	if(upgrade?.prison == src)
		upgrade.prison = null
	upgrade = null
	outpost = null
	wing = null
	return ..()

// ===== THE WING =====

/// Every tile of the placed wing and of the extensions joined to it (outpost_prison_extension.dm), the wing's own first
/datum/outpost_prison/proc/wing_turfs()
	if(!upgrade?.footprint_bounds || !wing)
		return list()
	if(isnull(wing_block_cache))
		wing_block_cache = upgrade.wing_blocks()
	var/list/turfs = list()
	for(var/turf/tile as anything in wing_block_cache)
		if(tile.loc == wing)
			turfs += tile
	return turfs

/// Whether a tile is inside the footprint of the wing or of one of its extensions, whatever its area
/datum/outpost_prison/proc/in_wing_bounds(turf/tile)
	if(!tile || !upgrade)
		return FALSE
	for(var/list/bounds as anything in upgrade.wing_bounds())
		if(tile.z == bounds[5] && tile.x >= bounds[1] && tile.y >= bounds[2] && tile.x <= bounds[3] && tile.y <= bounds[4])
			return TRUE
	return FALSE

/**
 * Whether a tile is on the wing's outer ring: inside the footprint of the wing or one of its
 * extensions, beside a tile outside all of them. The walls where an extension joins are not.
 */
/datum/outpost_prison/proc/on_outer_ring(turf/tile)
	if(!in_wing_bounds(tile))
		return FALSE
	for(var/direction in GLOB.cardinals)
		if(!in_wing_bounds(get_step(tile, direction)))
			return TRUE
	return FALSE

/// How many cell block extensions are joined to the wing
/datum/outpost_prison/proc/extension_count()
	return min(OUTPOST_PRISON_MAX_EXTENSIONS, length(upgrade?.extension_bounds))

/// Cells free for a new arrival
/datum/outpost_prison/proc/free_slots()
	var/free = 0
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(!cell.occupant)
			free++
	return min(free, max(0, capacity - length(prisoners)))

/// The furniture of one category, as of the last refresh
/datum/outpost_prison/proc/fixtures_of(category)
	var/list/found = fixtures[category]
	return found || list()

// ===== CELLS =====

/**
 * Finds the wing's cells from its numbered cell doors: the inside of a cell is the small room on
 * the side of its door that has a bed. Works at any rotation. Only for a new prison: it throws
 * away every cell it had, and with them who lives in each. An extension adds its cells with
 * add_cells_from().
 */
/datum/outpost_prison/proc/find_cells()
	QDEL_LIST(cells)
	add_cells_from(wing_turfs())

/**
 * Makes a cell for each numbered cell door of the wing on `turfs` that no cell has yet, and keeps
 * `cells` in number order. Unnumbered doors, and doors whose number is taken, get the next free
 * number. Returns the new cells.
 */
/datum/outpost_prison/proc/add_cells_from(list/turfs)
	var/list/found = list()
	for(var/turf/tile as anything in turfs)
		if(tile.loc != wing || cell_with_door_turf(tile))
			continue
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/door = locate() in tile
		if(!door)
			continue
		var/list/inside = cell_inside(door)
		if(inside)
			found += new /datum/outpost_prison_cell(src, door, inside)
	var/list/taken = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		taken["[cell.number]"] = TRUE
	for(var/datum/outpost_prison_cell/cell as anything in found)
		if(cell.number < 1 || taken["[cell.number]"])
			cell.number = 0
		else
			taken["[cell.number]"] = TRUE
	var/next_number = 1
	for(var/datum/outpost_prison_cell/cell as anything in found)
		if(cell.number)
			continue
		while(taken["[next_number]"])
			next_number++
		cell.number = next_number
		taken["[next_number]"] = TRUE
	var/list/unsorted = cells + found
	cells = list()
	while(length(unsorted))
		var/datum/outpost_prison_cell/lowest = unsorted[1]
		for(var/datum/outpost_prison_cell/cell as anything in unsorted)
			if(cell.number < lowest.number)
				lowest = cell
		unsorted -= lowest
		cells += lowest
	return found

/// The tiles inside the cell `door` closes, or null
/datum/outpost_prison/proc/cell_inside(obj/machinery/door/door)
	var/turf/door_turf = get_turf(door)
	for(var/direction in GLOB.cardinals)
		var/turf/start = get_step(door_turf, direction)
		if(!start || start.loc != wing || !prisoner_can_stand(start) || (locate(/obj/machinery/door) in start))
			continue
		var/list/room = list(start)
		var/list/seen = list()
		seen[start] = TRUE
		seen[door_turf] = TRUE
		var/index = 1
		var/too_big = FALSE
		while(index <= length(room))
			var/turf/current = room[index++]
			for(var/step_dir in GLOB.cardinals)
				var/turf/next = get_step(current, step_dir)
				if(!next || seen[next])
					continue
				seen[next] = TRUE
				if(next.loc != wing || !prisoner_can_stand(next) || (locate(/obj/machinery/door) in next))
					continue
				room += next
				if(length(room) > PRISON_CELL_MAX_TILES)
					too_big = TRUE
					break
			if(too_big)
				break
		if(too_big)
			continue
		for(var/turf/tile as anything in room)
			if(locate(/obj/structure/bed) in tile)
				return room
	return null

/datum/outpost_prison/proc/cell_by_number(number)
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.number == number)
			return cell
	return null

/// The cell a tile is inside, if any
/datum/outpost_prison/proc/cell_at(turf/tile)
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.turf_set[tile])
			return cell
	return null

/// Who owns this bed, if it is a cell's bed with someone in the cell
/datum/outpost_prison/proc/bed_owner(obj/structure/bed/bed)
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.bed() == bed)
			return cell.occupant
	return null

/**
 * Bolts or unbolts a cell's door. An open door is closed first, and only bolted once it shuts.
 * Returns FALSE if the cell has no door.
 */
/datum/outpost_prison/proc/toggle_cell_bolts(number, mob/user)
	var/datum/outpost_prison_cell/cell = cell_by_number(number)
	var/obj/machinery/door/airlock/door = cell?.door()
	if(!door)
		return FALSE
	if(door.locked)
		door.unbolt()
	else if(door.density)
		door.bolt()
	else
		INVOKE_ASYNC(src, PROC_REF(close_and_bolt), door)
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] toggled the bolts of cell [number] at '[outpost?.name]'")
	refresh_reach()
	return TRUE

/datum/outpost_prison/proc/close_and_bolt(obj/machinery/door/airlock/door)
	if(!door.close())
		return
	door.bolt()
	refresh_reach()

// ===== SUPPLIES AND FURNITURE =====

/**
 * Advances supplies by `seconds`: every PRISON_SUPPLY_REFRESH_SECONDS, prisoners whose AI is asleep
 * help themselves, hurt prisoners go to anyone holding dressings, and the hatches are checked for
 * prisoners left waiting (noted in the log at most every OUTPOST_PRISON_HATCH_WARNING_GAP).
 */
/datum/outpost_prison/proc/supply_tick(seconds)
	hatch_warning_left = max(0, hatch_warning_left - seconds)
	supply_clock += seconds
	if(supply_clock < PRISON_SUPPLY_REFRESH_SECONDS)
		return
	supply_clock = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		prisoner.fend_for_self()
		prisoner.check_sick_call()
	check_hatch_shortage()

/// The serving hatches, as of the last furniture refresh
/datum/outpost_prison/proc/hatches()
	var/list/found = list()
	for(var/obj/structure/table/reinforced/prison_hatch/hatch in fixtures_of("hatch"))
		if(!QDELETED(hatch) && isturf(hatch.loc))
			found += hatch
	return found

/// What the serving hatches hold: list("meals", "clean_suits", "dirty_suits", "capacity", "lasts_minutes")
/datum/outpost_prison/proc/hatch_stock()
	var/meals = 0
	var/clean_suits = 0
	var/dirty_suits = 0
	var/list/all_hatches = hatches()
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in all_hatches)
		for(var/obj/item/thing in hatch.loc)
			if(istype(thing, /obj/item/food))
				meals++
				continue
			var/obj/item/clothing/under/rank/prisoner/outpost/suit = thing
			if(!istype(suit))
				continue
			if(suit.grime < PRISONER_GRIME_DIRTY)
				clean_suits++
			else
				dirty_suits++
	// How long it lasts at the usual rates, for the prisoners here (or a full wing while intake is open).
	var/eaters = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_ARRIVING && prisoner.stat != DEAD && prisoner.trouble != PRISONER_TROUBLE_LOOSE)
			eaters++
	if(!eaters && intake_open)
		eaters = capacity
	var/lasts
	if(eaters)
		lasts = round(min(meals / (OUTPOST_PRISON_MEAL_RATE * eaters), clean_suits / (OUTPOST_PRISON_SUIT_RATE * eaters)))
	return list(
		"meals" = meals,
		"clean_suits" = clean_suits,
		"dirty_suits" = dirty_suits,
		"capacity" = length(all_hatches) * OUTPOST_PRISON_HATCH_CAPACITY,
		"lasts_minutes" = lasts,
	)

/// Whether someone is waiting for food or a clean uniform that no serving hatch in their reach has
/datum/outpost_prison/proc/hatch_shortage()
	return waiting_for_food > 0 || waiting_for_suits > 0

/**
 * Counts who is waiting on the hatches: hungry (not well fed) with no food on a hatch they can
 * reach, or in a dirty uniform with no clean one there. Only prisoners who can reach a hatch
 * count, and only while they are well and out of trouble. Notes it in the warden's log.
 */
/datum/outpost_prison/proc/check_hatch_shortage()
	waiting_for_food = 0
	waiting_for_suits = 0
	var/list/all_hatches = hatches()
	if(!length(all_hatches))
		return
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT || prisoner.trouble)
			continue
		var/reaches_hatch = FALSE
		for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in all_hatches)
			if(prisoner.reachable?[hatch.loc])
				reaches_hatch = TRUE
				break
		if(!reaches_hatch)
			continue
		if(prisoner.hunger < PRISONER_HUNGER_HUNGRY && prisoner.well_fed_left <= 0 && !istype(prisoner.held_item, /obj/item/food) && !find_supply(prisoner))
			waiting_for_food++
		if(prisoner.wants_clean_uniform() && !find_supply(prisoner, TRUE))
			waiting_for_suits++
	if(hatch_shortage() && hatch_warning_left <= 0)
		hatch_warning_left = OUTPOST_PRISON_HATCH_WARNING_GAP / (1 SECONDS)
		add_log(hatch_warning_text())

/// "The hatch is out of food and 2 prisoners are waiting."
/datum/outpost_prison/proc/hatch_warning_text()
	var/missing
	if(waiting_for_food && waiting_for_suits)
		missing = "food and clean uniforms"
	else
		missing = waiting_for_food ? "food" : "clean uniforms"
	var/waiting = max(waiting_for_food, waiting_for_suits)
	return "The hatch is out of [missing] and [waiting] prisoner[waiting == 1 ? " is" : "s are"] waiting."

/**
 * Fills every serving hatch to capacity for free: meals up to OUTPOST_PRISON_FILL_MEAL_SHARE of
 * it, then clean uniforms. For the admin panel. Returns the items added.
 */
/datum/outpost_prison/proc/fill_hatches()
	var/added = 0
	var/meal_target = round(OUTPOST_PRISON_HATCH_CAPACITY * OUTPOST_PRISON_FILL_MEAL_SHARE, 1)
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches())
		var/meals = 0
		for(var/obj/item/food/meal in hatch.loc)
			meals++
		while(hatch.room_left() > 0 && meals < meal_target)
			new /obj/item/food/prison_ration(hatch.loc)
			meals++
			added++
		while(hatch.room_left() > 0)
			new /obj/item/clothing/under/rank/prisoner/outpost(hatch.loc)
			added++
	return added

/**
 * The nearest thing in the prisoner's reach that they want: food anywhere in the wing (a serving
 * hatch, a table, a cell, the floor), or a cleaner uniform off a serving hatch when `want_uniform`
 * is set. Anything another prisoner is already fetching is left alone.
 */
/datum/outpost_prison/proc/find_supply(mob/living/basic/outpost_prisoner/prisoner, want_uniform = FALSE)
	if(!prisoner.reachable)
		refresh_prisoner_reach(prisoner)
	var/obj/item/best
	var/best_distance = INFINITY
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches())
		var/turf/counter = hatch.loc
		if(!prisoner.reachable?[counter])
			continue
		for(var/obj/item/thing in counter)
			if(want_uniform ? !prisoner.would_change_into(thing) : !istype(thing, /obj/item/food))
				continue
			if(claimed_by_other(thing, prisoner) || reserved_supply(thing, prisoner))
				continue
			var/distance = get_dist(prisoner, thing)
			if(distance < best_distance)
				best = thing
				best_distance = distance
	if(want_uniform)
		return best
	for(var/obj/item/food/meal as anything in loose_food())
		if(!prisoner.reachable?[meal.loc] || claimed_by_other(meal, prisoner) || reserved_supply(meal, prisoner))
			continue
		var/distance = get_dist(prisoner, meal)
		if(distance < best_distance)
			best = meal
			best_distance = distance
	return best

/// Food lying loose on the wing's tiles, off the serving hatches (find_supply() looks at those itself). Looked for again at most every PRISON_LOOSE_FOOD_REFRESH.
/datum/outpost_prison/proc/loose_food()
	if(isnull(loose_food_refs) || world.time >= loose_food_stale_at)
		loose_food_stale_at = world.time + PRISON_LOOSE_FOOD_REFRESH
		loose_food_refs = list()
		for(var/turf/tile as anything in wing_turfs())
			if(locate(/obj/structure/table/reinforced/prison_hatch) in tile)
				continue
			for(var/obj/item/food/meal in tile)
				loose_food_refs += WEAKREF(meal)
	. = list()
	for(var/datum/weakref/ref as anything in loose_food_refs)
		var/obj/item/food/meal = ref.resolve()
		// Still lying in the wing: not eaten, picked up or carried out since
		if(!QDELETED(meal) && isturf(meal.loc) && meal.loc.loc == wing)
			. += meal

/**
 * Staff put something on a serving hatch. Prisoners who want it leave whatever they were idling
 * at to go and get it, one prisoner who can see it and wants it calls it out ("Food's up!", "Clean
 * suits!"), and someone already waiting at that hatch for it thanks them. Returns the prisoner who
 * called it out, or null.
 */
/datum/outpost_prison/proc/on_hatch_stocked(obj/structure/table/reinforced/prison_hatch/hatch, list/stocked, mob/user)
	if(!hatch || !length(stocked) || (user && !is_member(user)))
		return null
	// A birthday cake or a letter is the extras' business (outpost_prison_extras.dm).
	if(extras_hatch_stocked(hatch, stocked, user))
		return null
	var/food = FALSE
	var/suits = FALSE
	for(var/obj/item/thing as anything in stocked)
		if(istype(thing, /obj/item/food))
			food = TRUE
		else if(istype(thing, /obj/item/clothing/under/rank/prisoner/outpost))
			var/obj/item/clothing/under/rank/prisoner/outpost/suit = thing
			if(suit.grime < PRISONER_GRIME_DIRTY)
				suits = TRUE
	if(!food && !suits)
		return null
	if(user)
		note_staff_stock(user)
	// Whoever wants it drops what they were idling at and comes over.
	for(var/mob/living/basic/outpost_prisoner/wanting in prisoners)
		var/datum/prisoner_activity/idle = wanting.activity
		if(!wanting.ai_running() || !idle?.leisure || !idle.interruptible || idle.sleeping)
			continue
		if((food && wanting.wants_food()) || (suits && wanting.wants_clean_uniform()))
			wanting.end_activity()
	var/mob/living/basic/outpost_prisoner/thanker
	for(var/mob/living/basic/outpost_prisoner/waiting in prisoners)
		var/datum/prisoner_activity/hatch_wait/wait = waiting.activity
		if(!istype(wait) || wait.hatch_ref?.resolve() != hatch)
			continue
		if((food && waiting.wants_food()) || (suits && waiting.wants_clean_uniform()))
			thanker = waiting
			if(user)
				waiting.note_carer(user)
			INVOKE_ASYNC(waiting, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, thank), (food && waiting.wants_food()) ? "thanks_food" : "thanks_uniform")
			break
	if(!COOLDOWN_FINISHED(src, hatch_call_cooldown))
		return null
	for(var/mob/living/basic/outpost_prisoner/crier as anything in shuffle(prisoners))
		if(crier == thanker || crier.stat != CONSCIOUS || crier.phase != PRISONER_PRESENT || crier.in_trouble() || crier.activity?.sleeping)
			continue
		var/context
		if(food && crier.wants_food())
			context = "food_up"
		else if(suits && crier.wants_clean_uniform())
			context = "suits_up"
		if(!context || !(hatch in view(7, crier)))
			continue
		COOLDOWN_START(src, hatch_call_cooldown, OUTPOST_PRISON_HATCH_CALL_GAP)
		note_speech()
		INVOKE_ASYNC(crier, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), context)
		return crier
	return null

/**
 * A prisoner sat down to eat at a mess table. PRISONER_SHARED_MEAL_COUNT or more doing so within
 * PRISONER_SHARED_MEAL_WINDOW makes a shared meal: each of them cheers up a little, once, and one
 * of them says so. Returns the prisoners who got the lift.
 */
/datum/outpost_prison/proc/note_table_meal(mob/living/basic/outpost_prisoner/eater)
	for(var/mob/living/basic/outpost_prisoner/earlier as anything in table_eaters.Copy())
		if(QDELETED(earlier) || !(earlier in prisoners) || world.time - table_eaters[earlier] > PRISONER_SHARED_MEAL_WINDOW)
			table_eaters -= earlier
	table_eaters[eater] = world.time
	var/list/lifted = list()
	if(length(table_eaters) < PRISONER_SHARED_MEAL_COUNT)
		return lifted
	for(var/mob/living/basic/outpost_prisoner/diner as anything in table_eaters)
		if(diner.shared_meal_at && world.time - diner.shared_meal_at <= PRISONER_SHARED_MEAL_WINDOW)
			continue
		diner.shared_meal_at = world.time
		diner.adjust_mood(PRISONER_MOOD_SHARED_MEAL)
		lifted += diner
	if(length(lifted))
		note_shared_meal(lifted)
	if(length(lifted) && COOLDOWN_FINISHED(src, mess_hall_cooldown))
		COOLDOWN_START(src, mess_hall_cooldown, OUTPOST_PRISON_MESS_HALL_GAP)
		var/mob/living/basic/outpost_prisoner/speaker = pick(lifted)
		INVOKE_ASYNC(speaker, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "mess_hall")
	return lifted

/**
 * A member of staff sank a shot while two or more prisoners were playing: each player cheers up,
 * at most once per OUTPOST_PRISON_STAFF_BASKET_GAP. Returns TRUE if it counted.
 */
/datum/outpost_prison/proc/staff_basket(mob/living/shooter, obj/structure/hoop/hoop)
	if(!is_member(shooter) || !COOLDOWN_FINISHED(src, staff_basket_cooldown))
		return FALSE
	var/list/players = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.stat == CONSCIOUS && prisoner.phase == PRISONER_PRESENT && istype(prisoner.activity, /datum/prisoner_activity/basketball))
			players += prisoner
	if(length(players) < 2)
		return FALSE
	COOLDOWN_START(src, staff_basket_cooldown, OUTPOST_PRISON_STAFF_BASKET_GAP)
	note_staff_basket(shooter)
	for(var/mob/living/basic/outpost_prisoner/player as anything in players)
		player.adjust_mood(PRISONER_MOOD_STAFF_BASKET)
		player.face_atom(hoop)
	var/mob/living/basic/outpost_prisoner/cheering = pick(players)
	INVOKE_ASYNC(cheering, TYPE_PROC_REF(/atom, manual_emote), pick("whistles.", "claps.", "cheers."))
	return TRUE

/// The nearest trash bin the prisoner can reach
/datum/outpost_prison/proc/find_bin(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.reachable)
		refresh_prisoner_reach(prisoner)
	var/obj/structure/closet/crate/bin/best
	var/best_distance = INFINITY
	for(var/turf/spot as anything in prisoner.reachable)
		for(var/obj/structure/closet/crate/bin/bin in spot)
			var/distance = get_dist(prisoner, bin)
			if(distance < best_distance)
				best = bin
				best_distance = distance
	return best

/// The nearest litter lying where the prisoner may walk, off the serving hatches and out of other cells
/datum/outpost_prison/proc/find_litter(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.walkable)
		refresh_prisoner_reach(prisoner)
	var/obj/item/trash/best
	var/best_distance = INFINITY
	for(var/turf/spot as anything in prisoner.reachable)
		if(locate(/obj/structure/table/reinforced/prison_hatch) in spot)
			continue
		var/obj/item/trash/litter = locate() in spot
		if(!litter || claimed_by_other(litter, prisoner) || !prisoner.may_loiter(spot))
			continue
		var/distance = get_dist(prisoner, litter)
		if(distance < best_distance)
			best = litter
			best_distance = distance
	return best

/// A basketball the prisoner can get at: their own, loose within reach, or in another player's hands
/datum/outpost_prison/proc/find_ball(mob/living/basic/outpost_prisoner/prisoner)
	if(istype(prisoner.held_item, /obj/item/toy/basketball))
		return prisoner.held_item
	if(!prisoner.reachable)
		refresh_prisoner_reach(prisoner)
	for(var/turf/spot as anything in prisoner.reachable)
		var/obj/item/toy/basketball/ball = locate() in spot
		if(ball)
			return ball
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(istype(other.held_item, /obj/item/toy/basketball) && prisoner.walkable?[get_turf(other)])
			return other.held_item
	return null

/// The nearest book lying about within reach, not on a shelf
/datum/outpost_prison/proc/find_loose_book(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.reachable)
		refresh_prisoner_reach(prisoner)
	var/obj/item/book/best
	var/best_distance = INFINITY
	for(var/turf/spot as anything in prisoner.reachable)
		for(var/obj/item/book/book in spot)
			if(claimed_by_other(book, prisoner))
				continue
			var/distance = get_dist(prisoner, book)
			if(distance < best_distance)
				best = book
				best_distance = distance
	return best

/// The mess table a stool faces, or failing that any table beside it
/datum/outpost_prison/proc/table_beside(obj/structure/chair/stool)
	var/turf/ahead = get_step(stool, stool.dir)
	if(is_mess_table(ahead))
		return ahead
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(stool, direction)
		if(is_mess_table(beside))
			return beside
	return null

/datum/outpost_prison/proc/is_mess_table(turf/tile)
	if(!tile || tile.loc != wing)
		return FALSE
	for(var/obj/structure/table/table in tile)
		if(!istype(table, /obj/structure/table/reinforced/prison_hatch))
			return TRUE
	return FALSE

/// Whether a prisoner other than `except` is doing an activity of this type
/datum/outpost_prison/proc/anyone_doing(activity_type, mob/living/basic/outpost_prisoner/except)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner != except && istype(prisoner.activity, activity_type))
			return TRUE
	return FALSE

// ===== CLAIMS =====

/// Reserves `thing` for `prisoner`. FALSE if someone else is using it.
/datum/outpost_prison/proc/claim(atom/thing, mob/living/basic/outpost_prisoner/prisoner)
	if(claimed_by_other(thing, prisoner))
		return FALSE
	claims[REF(thing)] = prisoner
	return TRUE

/// The prisoner using `thing`, if any
/datum/outpost_prison/proc/claimant(atom/thing)
	var/mob/living/basic/outpost_prisoner/holder = claims[REF(thing)]
	if(QDELETED(holder) || !holder.activity)
		return null
	return holder

/datum/outpost_prison/proc/claimed_by_other(atom/thing, mob/living/basic/outpost_prisoner/prisoner)
	var/mob/living/basic/outpost_prisoner/holder = claimant(thing)
	return holder && holder != prisoner

// ===== SPEECH =====

/// Whether the wing is quiet enough for a new spontaneous line
/datum/outpost_prison/proc/wing_can_speak()
	return COOLDOWN_FINISHED(src, wing_speech_cooldown) && !scene_active()

/datum/outpost_prison/proc/note_speech()
	COOLDOWN_START(src, wing_speech_cooldown, OUTPOST_PRISON_SPEECH_GAP)

// ===== TIME =====

/datum/outpost_prison/process(seconds_per_tick)
	if(QDELETED(outpost) || !wing)
		return
	tick(seconds_per_tick)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT)
			continue
		prisoner.maybe_drip(seconds_per_tick)
		if(prisoner.stat != CONSCIOUS)
			continue
		if(prisoner.trouble != PRISONER_TROUBLE_LOOSE && SPT_PROB(OUTPOST_PRISON_MESS_CHANCE / 60, seconds_per_tick))
			prisoner.make_mess()
		// Nobody on the level, nobody to hear it.
		if(prisoner.ai_running())
			prisoner.speech_tick()

/**
 * Advances the prison by `seconds`, in a fixed order: who is home, the condition scores, reach,
 * supplies; then for each prisoner their body (body_tick()), pay and sentence, needs, confinement, cuffs
 * and lockdown (outpost_prison_capture.dm), mood, and release; then trouble
 * (outpost_prison_riot.dm), experiments, arrivals and deposits.
 * Prisoners who are fighting earn nothing; rioting or loose, they earn nothing and their sentence
 * stops. Each part keeps its own cadence inside its own tick proc; keep this order as it is.
 */
/datum/outpost_prison/proc/tick(seconds)
	presence_tick(seconds)
	conditions_tick(seconds)
	containment_tick(seconds)
	supply_tick(seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase != PRISONER_PRESENT)
			continue
		if(prisoner.stat == DEAD)
			body_tick(prisoner)
			continue
		var/serving = prisoner.serving_sentence()
		if(serving)
			var/served = min(seconds, prisoner.sentence_left)
			accrue_pay(prisoner, served)
			prisoner.sentence_left -= served
		prisoner.adjust_needs(seconds)
		update_locked_in(prisoner, seconds)
		update_cuffed(prisoner, seconds)
		lockdown_tick(prisoner, seconds)
		// Pulled while calm, and in trouble since: they shake the pull off (outpost_prison_warden_tools.dm).
		prisoner.shake_off_pull()
		// Hitting back at a player runs its course (outpost_prison_trouble.dm).
		prisoner.retaliation_tick(seconds)
		prisoner.drift_mood(seconds)
		if(serving)
			check_release(prisoner)
	trouble_tick(seconds)
	experiments_tick(seconds)
	extras_tick(seconds)
	intake_tick(seconds)
	pay_tick(seconds)

// ===== COMINGS AND GOINGS =====

/// Drops a prisoner from the roster and their cell, and starts refilling it
/datum/outpost_prison/proc/forget(mob/living/basic/outpost_prisoner/prisoner)
	if(!(prisoner in prisoners))
		return
	// Whatever else closed their bounty record first decided how it ended (outpost_prison_bounty.dm).
	close_bounty_record(prisoner, BOUNTY_RECORD_CLOSED)
	if(prisoner.fight)
		end_fight(prisoner.fight)
	if(prisoner.trouble == PRISONER_TROUBLE_LOOSE)
		clear_outpost_patrol(prisoner)
	prisoners -= prisoner
	extras_prisoner_leaving(prisoner)
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()
	var/datum/outpost_prison_cell/emptied = prisoner.cell
	if(emptied?.occupant == prisoner)
		emptied.occupant = null
	prisoner.cell = null
	prisoner.prison = null
	for(var/key in claims.Copy())
		if(claims[key] == prisoner)
			claims -= key
	table_eaters -= prisoner
	on_cell_emptied(emptied)

/datum/outpost_prison/proc/add_log(text)
	entries = list(list("time" = station_time_timestamp("hh:mm"), "text" = text)) + entries
	if(length(entries) > OUTPOST_PRISON_LOG_LENGTH)
		entries.Cut(OUTPOST_PRISON_LOG_LENGTH + 1)
	log_game("PLAYER OUTPOST PRISON: '[outpost?.name]': [text]")

// ===== CELL =====

/// One cell of a prison wing: its door, its bed, the tiles inside and who lives there
/datum/outpost_prison_cell
	var/number = 0
	var/datum/outpost_prison/prison
	var/datum/weakref/door_ref
	/// Where the door stood, so a door rebuilt there is still the cell's
	var/turf/door_turf
	var/datum/weakref/bed_ref
	/// The tiles inside, and the same as a set (turf = TRUE)
	var/list/turfs
	var/list/turf_set
	/// The prisoner who owns it
	var/mob/living/basic/outpost_prisoner/occupant
	/// world.time from which the cell may take a new arrival
	var/ready_at = 0

/datum/outpost_prison_cell/New(datum/outpost_prison/owner, obj/machinery/door/airlock/security/glass/outpost_prison_cell/door, list/inside)
	. = ..()
	prison = owner
	number = door.cell_number
	door_ref = WEAKREF(door)
	door_turf = get_turf(door)
	turfs = inside
	turf_set = list()
	for(var/turf/tile as anything in inside)
		turf_set[tile] = TRUE
		var/obj/structure/bed/bed = locate() in tile
		if(bed && !bed_ref)
			bed_ref = WEAKREF(bed)

/datum/outpost_prison_cell/Destroy()
	if(occupant?.cell == src)
		occupant.cell = null
	occupant = null
	prison = null
	door_turf = null
	turfs = null
	turf_set = null
	return ..()

/// The cell's door: the one it was found with, or any airlock since built where it stood
/datum/outpost_prison_cell/proc/door()
	var/obj/machinery/door/airlock/door = door_ref?.resolve()
	if(door)
		return door
	for(var/obj/machinery/door/airlock/rebuilt in door_turf)
		if(!QDELETED(rebuilt))
			return rebuilt
	return null

/// The cell's bed, while it is still inside the cell
/datum/outpost_prison_cell/proc/bed()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	return (bed && turf_set[get_turf(bed)]) ? bed : null

/// A chair inside the cell: the one the map puts there, or any moved or built in since
/datum/outpost_prison_cell/proc/chair()
	for(var/turf/tile as anything in turfs)
		for(var/obj/structure/chair/seat in tile)
			if(!QDELETED(seat))
				return seat
	return null

/// Whether the cell is in a cell block extension rather than the wing's own footprint
/datum/outpost_prison_cell/proc/in_extension()
	return prison?.upgrade?.footprint_bounds && !prison.upgrade.contains_turf(door_turf)

/// Whether the cell's door stands inside `bounds`, a list(min_x, min_y, max_x, max_y, z)
/datum/outpost_prison_cell/proc/door_in_bounds(list/bounds)
	return door_turf && door_turf.z == bounds[5] && door_turf.x >= bounds[1] && door_turf.y >= bounds[2] && door_turf.x <= bounds[3] && door_turf.y <= bounds[4]

/datum/outpost_prison_cell/proc/contains(atom/thing)
	return !!turf_set[get_turf(thing)]

/datum/outpost_prison_cell/proc/is_bolted()
	var/obj/machinery/door/airlock/door = door()
	return !!door?.locked

/// Where a new prisoner materialises: beside their bed, or anywhere inside
/datum/outpost_prison_cell/proc/arrival_turf()
	var/obj/structure/bed/bed = bed()
	if(bed)
		return get_turf(bed)
	return length(turfs) ? turfs[1] : null

#undef PRISON_SUPPLY_REFRESH_SECONDS
#undef PRISON_LOOSE_FOOD_REFRESH
#undef PRISON_CELL_MAX_TILES
