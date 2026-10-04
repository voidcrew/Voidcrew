/**
 * # Prison wing conditions
 *
 * How well the wing is kept, measured where the prisoners live:
 * - Clean: mess on the cell block's floor (the cells, their doors, the yard, the mess tables and
 *   the serving hatches). Each piece has a weight (crumbs and drips little, litter and dirt more,
 *   blood pools and vomit most), a tile counts for at most PRISON_MESS_TILE_CAP, and the load is
 *   taken per 100 floor tiles as counted when the wing was placed, so walling off part of the yard
 *   never dilutes it. A little mess is free; past that Clean falls in a straight line.
 * - Lit: light measured on the cell block's floor, each tile full marks once it
 *   is bright enough. Lights nobody in the cell block can see add nothing. Held while the riot
 *   strobe runs and while the wing's lights are waiting to be redrawn.
 * - Power: the equipment channel, after a grace. Time without power builds an outage debt that
 *   drains at half speed with power back, so flicking the breaker never keeps the grace fresh.
 *
 * Mess and power refresh every 5 seconds, light every PRISON_LIGHT_REFRESH, and the furniture and
 * floor lists every PRISON_FIXTURE_REFRESH. The mess scan looks at no more than PRISON_SCAN_BUDGET
 * atoms a time and carries on from there next time, so a yard full of junk slows the score down
 * rather than the server. Also here: what the wing does to moods, the sparks a real power cut or
 * the lights going out give the wing, flies over old filth, rats in a filthy wing, bad air, and
 * the red riot strobe, which drives the lights directly so no firelocks close.
 * The pay model is in voidcrew/_DEFINES/outpost_prison_economy.dm.
 */

/// How often mess, air and rats are refreshed, in seconds
#define PRISON_MESS_REFRESH_SECONDS 5
/// Seconds per step of damage from bad air
#define PRISON_AIR_STEP_SECONDS 5
/// Percent chance a prisoner hurt by bad air says so
#define PRISON_AIR_LINE_CHANCE 15

/// Mess weight by type (see PRISON_MESS_WEIGHT_*); types not listed are not mess
GLOBAL_LIST_INIT(outpost_prison_mess_weights, build_outpost_prison_mess_weights())
/// Furniture category ("bed", "stool", ...) by type, for the wing's furniture list
GLOBAL_LIST_INIT(outpost_prison_furniture_types, zebra_typecacheof(list(
	/obj/structure/bed = "bed",
	// The cells' chairs, and any other plain chair; stools and the reading chair are their own kinds below
	/obj/structure/chair = "chair",
	/obj/structure/chair/stool = "stool",
	/obj/structure/chair/comfy = "reading_chair",
	/obj/structure/table = "table",
	/obj/structure/table/reinforced/prison_hatch = "hatch",
	/obj/structure/toilet = "toilet",
	/obj/structure/sink = "sink",
	/obj/structure/hoop = "hoop",
	/obj/structure/bookcase = "bookcase",
	/obj/structure/reagent_dispensers/water_cooler = "cooler",
	/obj/structure/window = "window",
)))

/proc/build_outpost_prison_mess_weights()
	var/list/weights = zebra_typecacheof(list(
		/obj/effect/decal/cleanable = PRISON_MESS_WEIGHT_LIGHT,
		/obj/effect/decal/cleanable/crayon = 0,
		/obj/effect/decal/cleanable/cobweb = 0,
		/obj/effect/decal/cleanable/blood = PRISON_MESS_WEIGHT_HEAVY,
		/obj/effect/decal/cleanable/blood/drip = PRISON_MESS_WEIGHT_TRACE,
		/obj/effect/decal/cleanable/blood/footprints = PRISON_MESS_WEIGHT_TRACE,
		/obj/effect/decal/cleanable/blood/tracks = PRISON_MESS_WEIGHT_TRACE,
		/obj/effect/decal/cleanable/blood/trail_holder = PRISON_MESS_WEIGHT_LIGHT,
		/obj/effect/decal/cleanable/blood/trail = PRISON_MESS_WEIGHT_LIGHT,
		/obj/effect/decal/cleanable/vomit = PRISON_MESS_WEIGHT_HEAVY,
		/obj/effect/decal/cleanable/insectguts = PRISON_MESS_WEIGHT_HEAVY,
		/obj/effect/decal/cleanable/food/crumbs = PRISON_MESS_WEIGHT_TRACE,
		/obj/item/trash = PRISON_MESS_WEIGHT_LIGHT,
		/obj/item/cigbutt = PRISON_MESS_WEIGHT_LIGHT,
		/obj/item/shard = PRISON_MESS_WEIGHT_LIGHT,
	))
	// Decals a mop can't lift (graffiti on windows, cobwebs, rubble) are not the mess prisoners live in.
	for(var/obj/effect/decal/cleanable/decal_type as anything in typesof(/obj/effect/decal/cleanable))
		if(!initial(decal_type.is_mopped))
			weights[decal_type] = 0
	return weights

/datum/outpost_prison
	/// Condition scores, 0 to 100
	var/clean_score = 100
	var/lit_score = 100
	var/powered_score = 100
	/// Seconds of power cut the wing has built up (see PRISON_POWER_GRACE); the admin panel can set it
	var/outage_debt = 0
	/// Seconds the condition clocks have run, for how long mess has lain and filth has lasted
	var/conditions_time = 0
	/// Seconds since mess, light and the furniture were last refreshed
	var/mess_clock = 0
	var/light_clock = 0
	var/fixture_clock = 0
	/// Whether the prison's deletion is hooked to clear up what the conditions left in the world
	var/conditions_hooked = FALSE

	/// The cell block's floor, where mess counts and light is measured: cells, cell doors, yard, mess tables and serving hatches
	var/list/turf/mess_floor = list()
	/// How many floor tiles the wing had when it was placed; the mess density is taken against this
	var/mess_floor_size = 0
	/// Cell block tiles that held the wing's structure (windows, grilles, staff doors) when it was placed: turf = TRUE
	var/list/structure_tiles = list()
	/// The tiles light is measured on (the floor), and the cell number of each (0 outside the cells)
	var/list/turf/light_tiles = list()
	var/list/light_tile_cells = list()
	/// Every light fixture in the wing, as of the last furniture refresh
	var/list/obj/machinery/light/wing_lights = list()

	/// Mess units on the floor and tiles with any mess, as of the last full scan
	var/mess_load = 0
	var/mess_spots = 0
	/// The scan in progress: next tile, what it has counted so far, and tiles with heavy mess
	var/mess_scan_index = 1
	var/mess_scan_load = 0
	var/mess_scan_spots = 0
	var/list/mess_scan_heavy = list()
	/// Tiles with heavy mess -> conditions_time it was first seen there
	var/list/heavy_since = list()
	/// Tiles with flies -> weakref to the flies
	var/list/fly_effects = list()

	/// Light per cell ("number" -> 0 to 100), as of the last light sample
	var/list/cell_lit = list()
	/// Tiles measured at the last light sample; 0 when the lights themselves stood in
	var/lit_samples = 0
	/// Light samples in a row below PRISON_DARK_BELOW
	var/dark_samples = 0

	/// Battery percent at the last check, while the wing ran on it
	var/last_battery
	/// Seconds Clean has stayed under PRISON_RAT_CLEAN_BELOW (held between that and PRISON_RAT_STOP_ABOVE)
	var/rat_clock = 0
	/// Weakrefs to the rats the wing's filth brought in
	var/list/rat_refs = list()

	/// Red strobe state
	var/riot_lights_on = FALSE
	var/strobe_bright = TRUE
	var/strobe_timer
	/// Weakrefs to every light the riot turned red, and to the ones that strobe
	var/list/riot_lights
	var/list/strobe_lights

// ===== REFRESH =====

/**
 * Advances the conditions by `seconds`: the power score every call, mess, air and rats every
 * PRISON_MESS_REFRESH_SECONDS, light every PRISON_LIGHT_REFRESH, the furniture and floor lists every
 * PRISON_FIXTURE_REFRESH. Where prisoners can reach is refreshed by containment_tick().
 */
/datum/outpost_prison/proc/conditions_tick(seconds)
	conditions_time += seconds
	update_power(seconds)
	fixture_clock += seconds
	if(fixture_clock >= PRISON_FIXTURE_REFRESH)
		fixture_clock = 0
		refresh_fixtures()
	light_clock += seconds
	if(light_clock >= PRISON_LIGHT_REFRESH)
		light_clock = 0
		// Lights still being redrawn: try again next second rather than next time round.
		if(!sample_light() && !riot_lights_on)
			light_clock = PRISON_LIGHT_REFRESH - 1
	mess_clock += seconds
	if(mess_clock >= PRISON_MESS_REFRESH_SECONDS)
		var/elapsed = mess_clock
		mess_clock = 0
		scan_mess()
		air_tick(elapsed)
		rat_tick(elapsed)
		check_battery()

/**
 * Refreshes everything at once: furniture and floor, a full mess scan, light, power, and where
 * prisoners can reach. For placement, admin tools and tests; the clock uses conditions_tick().
 */
/datum/outpost_prison/proc/refresh_conditions()
	refresh_fixtures()
	mess_scan_index = 1
	mess_scan_load = 0
	mess_scan_spots = 0
	mess_scan_heavy = list()
	scan_mess(INFINITY)
	sample_light(estimate_pending = TRUE)
	update_power(0)
	refresh_reach()

/// Whether the wing's APC gives its machines power
/datum/outpost_prison/proc/is_powered()
	return !!wing?.powered(AREA_USAGE_EQUIP)

/// Whether a tile is on the outside edge of the wing, so a window there looks out
/datum/outpost_prison/proc/on_wing_edge(turf/tile)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(!beside || beside.loc != wing)
			return TRUE
	return FALSE

// ===== FURNITURE AND FLOOR =====

/// Refinds the wing's furniture and lights, and the cell block's floor
/datum/outpost_prison/proc/refresh_fixtures()
	if(!conditions_hooked)
		conditions_hooked = TRUE
		RegisterSignal(src, COMSIG_QDELETING, PROC_REF(clear_conditions))
	var/list/categories = GLOB.outpost_prison_furniture_types
	var/list/found = list(
		"bed" = list(),
		"chair" = list(),
		"stool" = list(),
		"reading_chair" = list(),
		"table" = list(),
		"hatch" = list(),
		"toilet" = list(),
		"sink" = list(),
		"hoop" = list(),
		"bookcase" = list(),
		"cooler" = list(),
		"window" = list(),
	)
	var/list/lights = list()
	for(var/turf/tile as anything in wing_turfs())
		for(var/obj/structure/thing in tile)
			var/category = categories[thing.type]
			if(!category || (category == "window" && !on_wing_edge(tile)))
				continue
			found[category] += thing
		for(var/obj/machinery/light/fixture in tile)
			lights += fixture
	fixtures = found
	wing_lights = lights
	refresh_floor()

/**
 * Rebuilds the floor lists from the cell block, and the first time it finds any floor, fixes the
 * floor's size and which of its tiles are the wing's structure (windows, grilles, staff doors).
 * Later building changes where mess counts, never how much it weighs, and nothing built later
 * takes a tile off the floor: a crate, a table or a grille over filth does not hide it, and
 * furniture over a dark corner does not take it out of the light, which is measured on the same
 * tiles. Only windows on the wing's outside edge, which look out, stay off.
 */
/datum/outpost_prison/proc/refresh_floor()
	var/placing = !mess_floor_size
	var/list/floor = list()
	var/list/floor_cells = list()
	var/list/left_out = list()
	for(var/turf/tile as anything in cell_block)
		if(!isopenturf(tile) || tile.loc != wing)
			continue
		if(placing ? is_wing_structure(tile) : !is_cell_block_floor(tile))
			left_out[tile] = TRUE
			continue
		floor += tile
		var/datum/outpost_prison_cell/holding = cell_at(tile)
		floor_cells += holding ? holding.number : 0
	mess_floor = floor
	light_tiles = floor
	light_tile_cells = floor_cells
	if(placing && length(floor))
		mess_floor_size = length(floor)
		structure_tiles = left_out

/// Whether a tile holds the wing's structure: a window, a grille or a staff door
/datum/outpost_prison/proc/is_wing_structure(turf/tile)
	for(var/obj/thing in tile)
		if(istype(thing, /obj/structure/window) || istype(thing, /obj/structure/grille) || istype(thing, /obj/machinery/door/airlock/security/prison_staff))
			return TRUE
	return FALSE

/// Whether a cell block tile is floor, once the wing is placed: not its structure then, not a staff door, not a window out
/datum/outpost_prison/proc/is_cell_block_floor(turf/tile)
	if(structure_tiles[tile] || (locate(/obj/machinery/door/airlock/security/prison_staff) in tile))
		return FALSE
	return !(on_wing_edge(tile) && is_wing_structure(tile))

// ===== MESS =====

/**
 * Carries the mess scan on from where it stopped, looking at no more than `budget` atoms (a tile
 * is always finished, up to PRISON_SCAN_BUDGET atoms of it). Returns TRUE once a whole pass is done,
 * which updates Clean, the heavy tiles and the flies.
 */
/datum/outpost_prison/proc/scan_mess(budget = PRISON_SCAN_BUDGET)
	var/list/weights = GLOB.outpost_prison_mess_weights
	var/seen = 0
	var/count = length(mess_floor)
	while(mess_scan_index <= count && seen < budget)
		var/turf/tile = mess_floor[mess_scan_index++]
		var/load = 0
		var/heavy = FALSE
		var/on_tile = 0
		for(var/atom/movable/thing as anything in tile)
			if(++on_tile > PRISON_SCAN_BUDGET)
				break
			var/weight = weights[thing.type]
			if(!weight)
				continue
			load += weight
			if(weight >= PRISON_MESS_WEIGHT_HEAVY)
				heavy = TRUE
		seen += on_tile
		if(load > 0)
			mess_scan_load += min(load, PRISON_MESS_TILE_CAP)
			mess_scan_spots++
		if(heavy)
			mess_scan_heavy[tile] = TRUE
	if(mess_scan_index <= count)
		return FALSE
	finish_mess_scan()
	return TRUE

/// A mess pass is done: publish its totals and start the next one
/datum/outpost_prison/proc/finish_mess_scan()
	mess_load = mess_scan_load
	mess_spots = mess_scan_spots
	var/list/heavy_now = mess_scan_heavy
	mess_scan_index = 1
	mess_scan_load = 0
	mess_scan_spots = 0
	mess_scan_heavy = list()
	clean_score = clean_for_load(mess_load)
	for(var/turf/tile as anything in heavy_since.Copy())
		if(!heavy_now[tile])
			heavy_since -= tile
	for(var/turf/tile as anything in heavy_now)
		if(isnull(heavy_since[tile]))
			heavy_since[tile] = conditions_time
	update_flies()

/// Clean, 0 to 100, for `load` mess units on the floor
/datum/outpost_prison/proc/clean_for_load(load)
	if(!mess_floor_size)
		return 100
	var/density = 100 * load / mess_floor_size_now()
	var/dirty = clamp((density - PRISON_MESS_FREE) / (PRISON_MESS_SQUALID - PRISON_MESS_FREE), 0, 1)
	return round(100 * (1 - dirty), 1)

/**
 * The floor the mess is spread over: the wing's as placed, with each cell block extension's share
 * counted only as far as its cells are occupied. Mess counts where the prisoners live, so empty
 * extension cells never thin it out.
 */
/datum/outpost_prison/proc/mess_floor_size_now()
	var/size = mess_floor_size
	var/list/all_bounds = upgrade?.extension_bounds
	var/list/floors = upgrade?.extension_floor_sizes
	for(var/index in 1 to min(length(all_bounds), length(floors)))
		var/total = 0
		var/taken = 0
		for(var/datum/outpost_prison_cell/cell as anything in cells)
			if(!cell.door_in_bounds(all_bounds[index]))
				continue
			total++
			if(cell.occupant)
				taken++
		if(total)
			size -= floors[index] * (total - taken) / total
	return max(1, size)

/// Flies over the heavy mess that has lain longest, once it has lain PRISON_FLY_AFTER; gone once it is cleaned
/datum/outpost_prison/proc/update_flies()
	var/fly_after = PRISON_FLY_AFTER / (1 SECONDS)
	var/list/old_enough = list()
	for(var/turf/tile as anything in heavy_since)
		if(conditions_time - heavy_since[tile] >= fly_after)
			old_enough += tile
	// Oldest first, at most PRISON_FLY_MAX.
	var/list/chosen = list()
	while(length(old_enough) && length(chosen) < PRISON_FLY_MAX)
		var/turf/oldest = old_enough[1]
		for(var/turf/tile as anything in old_enough)
			if(heavy_since[tile] < heavy_since[oldest])
				oldest = tile
		old_enough -= oldest
		chosen[oldest] = TRUE
	for(var/turf/tile as anything in fly_effects.Copy())
		var/datum/weakref/fly_ref = fly_effects[tile]
		var/obj/effect/outpost_prison_flies/flies = fly_ref?.resolve()
		if(chosen[tile] && flies && flies.loc == tile)
			continue
		fly_effects -= tile
		if(flies)
			qdel(flies)
	for(var/turf/tile as anything in chosen)
		if(!fly_effects[tile])
			fly_effects[tile] = WEAKREF(new /obj/effect/outpost_prison_flies(tile))

/// Flies circling old filth on the prison floor
/obj/effect/outpost_prison_flies
	name = "flies"
	desc = "Flies, circling something that should have been cleaned up a while ago."
	icon = 'icons/effects/effects.dmi'
	icon_state = "fly-surrounding"
	layer = ABOVE_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE

// ===== LIGHT =====

/**
 * Measures the light on the cell block's floor, and on each cell's. Held while the riot
 * strobe runs. While a light in the wing has changed and the lighting has not redrawn it, what is
 * on the tiles is not yet what the lights give: the sample is held, or with `estimate_pending`
 * (placement, admin tools, tests) the cell block's working lights stand in. Tiles with no
 * lighting are skipped, and with none measured the working lights stand in too.
 * Returns TRUE if the scores were refreshed.
 */
/datum/outpost_prison/proc/sample_light(estimate_pending = FALSE)
	if(riot_lights_on)
		return FALSE
	if(lighting_pending())
		if(!estimate_pending)
			return FALSE
		light_from_fixtures()
		note_light_sample()
		return TRUE
	var/total = 0
	var/sampled = 0
	var/list/cell_totals = list()
	var/list/cell_counts = list()
	for(var/index in 1 to length(light_tiles))
		var/turf/tile = light_tiles[index]
		if(!tile.lighting_object)
			continue
		var/value = min(1, tile.get_lumcount() / PRISON_LIT_ENOUGH)
		total += value
		sampled++
		var/number = light_tile_cells[index]
		if(number)
			cell_totals["[number]"] += value
			cell_counts["[number]"] += 1
	if(!sampled)
		light_from_fixtures()
		note_light_sample()
		return TRUE
	lit_samples = sampled
	lit_score = round(100 * total / sampled, 1)
	var/list/by_cell = list()
	for(var/key in cell_counts)
		by_cell[key] = round(100 * cell_totals[key] / cell_counts[key], 1)
	cell_lit = by_cell
	note_light_sample()
	return TRUE

/// Two light samples in a row this dark put the wing on edge
/datum/outpost_prison/proc/note_light_sample()
	if(lit_score >= PRISON_DARK_BELOW)
		dark_samples = 0
		return
	dark_samples++
	if(dark_samples == 2)
		trouble_event(PRISON_SPIKE_LIGHTS_OUT, "the lights went out")

/// Whether a light in the wing has changed and the lighting subsystem has not drawn it yet
/datum/outpost_prison/proc/lighting_pending()
	for(var/obj/machinery/light/fixture as anything in wing_lights)
		if(QDELETED(fixture))
			continue
		var/datum/light_source/source = fixture.light
		if(source?.needs_update)
			return TRUE
	return FALSE

/**
 * Lit and the cells' light from the share of the cell block's lights that are on, for when the
 * light itself can't be measured. Only lights on the cell block's tiles count, so lights nobody
 * in the cell block can see still add nothing.
 */
/datum/outpost_prison/proc/light_from_fixtures()
	var/total = 0
	var/working = 0
	var/list/cell_totals = list()
	var/list/cell_counts = list()
	for(var/obj/machinery/light/fixture as anything in wing_lights)
		var/turf/spot = get_turf(fixture)
		if(QDELETED(fixture) || !cell_block[spot])
			continue
		var/on = fixture.on && fixture.status == LIGHT_OK
		total++
		working += on
		var/datum/outpost_prison_cell/holding = cell_at(spot)
		if(holding)
			cell_totals["[holding.number]"] += on
			cell_counts["[holding.number]"] += 1
	lit_samples = 0
	lit_score = total ? round(100 * working / total, 1) : 0
	for(var/key in cell_counts)
		cell_lit[key] = round(100 * cell_totals[key] / cell_counts[key], 1)

/// How lit a cell is, 0 to 100, as of the last light sample
/datum/outpost_prison/proc/cell_light(datum/outpost_prison_cell/cell)
	var/value = cell ? cell_lit["[cell.number]"] : null
	return isnull(value) ? 100 : value

/// The numbers of the cells lit below PRISON_DARK_BELOW, lowest first
/datum/outpost_prison/proc/dark_cells()
	var/list/dark = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell_light(cell) < PRISON_DARK_BELOW)
			dark += cell.number
	return dark

// ===== POWER =====

/**
 * Moves the outage debt on by `seconds` and works out Power: 100 while the equipment channel is
 * on; while it is off, 100 until the debt passes PRISON_POWER_GRACE, then down to 0 over
 * PRISON_POWER_RAMP. The debt stops growing once Power is 0, so it always drains in a few minutes.
 * Power first dropping puts the wing on edge.
 */
/datum/outpost_prison/proc/update_power(seconds)
	var/powered = is_powered()
	if(powered)
		outage_debt -= PRISON_POWER_DEBT_RECOVERY * seconds
	else
		outage_debt += seconds
	outage_debt = clamp(outage_debt, 0, PRISON_POWER_GRACE + PRISON_POWER_RAMP)
	var/was = powered_score
	if(powered || outage_debt <= PRISON_POWER_GRACE)
		powered_score = 100
	else
		powered_score = round(100 * (1 - (outage_debt - PRISON_POWER_GRACE) / PRISON_POWER_RAMP), 1)
	if(was >= 100 && powered_score < 100)
		trouble_event(PRISON_SPIKE_POWER_CUT, "the power went out")

/// The wing APC's battery percent while it is running on it (not charging), or null
/datum/outpost_prison/proc/battery_percent()
	var/obj/machinery/power/apc/apc = wing?.apc
	var/obj/item/stock_parts/power_store/cell = apc?.cell
	if(!cell || apc.charging != APC_NOT_CHARGING)
		return null
	return round(cell.percent(), 1)

/// The battery running down past PRISON_BATTERY_WARNING: the lights flicker and someone says so
/datum/outpost_prison/proc/check_battery()
	var/battery = battery_percent()
	if(!isnull(battery) && !isnull(last_battery) && last_battery >= PRISON_BATTERY_WARNING && battery < PRISON_BATTERY_WARNING)
		var/mob/living/basic/outpost_prisoner/speaker = pick_conditions_speaker()
		if(speaker?.say_context("lights_flicker"))
			note_speech()
	last_battery = battery

// ===== SCORES =====

/// Conditions, 0 to 100: the weighted clean, lit and powered scores
/datum/outpost_prison/proc/conditions_score()
	return PRISON_WEIGHT_CLEAN * clean_score + PRISON_WEIGHT_LIT * lit_score + PRISON_WEIGHT_POWER * powered_score

/// How much of full pay the wing's conditions allow, OUTPOST_PRISON_CONDITIONS_PAY_FLOOR to 1
/datum/outpost_prison/proc/conditions_pay_factor()
	return OUTPOST_PRISON_CONDITIONS_PAY_FLOOR + (1 - OUTPOST_PRISON_CONDITIONS_PAY_FLOOR) * conditions_score() / 100

/// The warden console's and the admin panel's conditions block
/datum/outpost_prison/proc/conditions_payload()
	return list(
		"clean" = round(clean_score, 1),
		"lit" = round(lit_score, 1),
		"powered" = round(powered_score, 1),
		"score" = round(conditions_score(), 1),
		"mess_spots" = mess_spots,
		"dark_cells" = dark_cells(),
		"battery" = battery_percent(),
	)

/**
 * Kept for older callers. The sparks now come from the refreshes themselves: sample_light() for
 * the lights going out, update_power() for a power cut past its grace.
 */
/datum/outpost_prison/proc/note_condition_changes(old_lit, old_powered)
	return

// ===== MOOD =====

/**
 * What the state of the wing does to a prisoner's mood per minute: list(gain, loss), before
 * personality. Dirty and dark cost nothing down to PRISON_WING_MOOD_LINE and their full rate at 0;
 * no power costs in proportion; a clean, lit, powered wing is a small comfort; and a dark cell of
 * their own costs a little more.
 */
/mob/living/basic/outpost_prisoner/proc/wing_mood_per_minute()
	var/loss = 0
	var/gain = 0
	if(prison && trouble != PRISONER_TROUBLE_LOOSE)
		loss += PRISONER_MOOD_DIRTY_WING * max(0, PRISON_WING_MOOD_LINE - prison.clean_score) / PRISON_WING_MOOD_LINE
		loss += PRISONER_MOOD_DARK * max(0, PRISON_WING_MOOD_LINE - prison.lit_score) / PRISON_WING_MOOD_LINE
		loss += PRISONER_MOOD_NO_POWER * (1 - clamp(prison.powered_score, 0, 100) / 100)
		if(prison.clean_score >= PRISON_GOOD_CONDITIONS && prison.lit_score >= PRISON_GOOD_CONDITIONS && prison.powered_score >= 100)
			gain += PRISONER_MOOD_GOOD_WING
		if(cell && prison.cell_light(cell) < PRISON_DARK_BELOW)
			loss += PRISONER_MOOD_DARK_CELL
	return list(gain, loss)

// ===== AIR =====

/// Prisoners on bad air lose a little health every PRISON_AIR_STEP_SECONDS, never below PRISON_AIR_HEALTH_FLOOR percent
/datum/outpost_prison/proc/air_tick(seconds)
	var/steps = max(1, round(seconds / PRISON_AIR_STEP_SECONDS))
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD || !outpost_prison_unsafe_air(prisoner.loc?.return_air()))
			continue
		var/hurt = FALSE
		for(var/i in 1 to steps)
			var/above_floor = prisoner.health - prisoner.maxHealth * PRISON_AIR_HEALTH_FLOOR / 100
			if(above_floor <= 0)
				break
			prisoner.adjustBruteLoss(min(PRISON_AIR_DAMAGE, above_floor))
			hurt = TRUE
		if(hurt && prisoner.stat == CONSCIOUS && prob(PRISON_AIR_LINE_CHANCE) && wing_can_speak() && prisoner.say_context("no_air"))
			note_speech()

/// Whether air is too thin, too thick, too hot, too cold or too full of plasma to live in
/proc/outpost_prison_unsafe_air(datum/gas_mixture/air)
	if(!air)
		return TRUE
	var/pressure = air.return_pressure()
	if(pressure < PRISON_AIR_PRESSURE_MIN || pressure > PRISON_AIR_PRESSURE_MAX)
		return TRUE
	if(air.temperature < PRISON_AIR_TEMP_MIN || air.temperature > PRISON_AIR_TEMP_MAX)
		return TRUE
	var/list/plasma = air.gases[/datum/gas/plasma]
	return plasma && plasma[MOLES] > PRISON_AIR_PLASMA_MAX

// ===== RATS =====

/**
 * A filthy wing gets rats: once Clean has stayed under PRISON_RAT_CLEAN_BELOW for PRISON_RAT_AFTER,
 * a PRISON_RAT_CHANCE percent chance a minute of a rat on the cell block floor, at most
 * PRISON_RAT_MAX alive at once, until Clean is back to PRISON_RAT_STOP_ABOVE.
 */
/datum/outpost_prison/proc/rat_tick(seconds)
	if(clean_score >= PRISON_RAT_STOP_ABOVE)
		rat_clock = 0
		return
	if(clean_score < PRISON_RAT_CLEAN_BELOW)
		rat_clock += seconds
	if(rat_clock < PRISON_RAT_AFTER / (1 SECONDS) || living_rats() >= PRISON_RAT_MAX)
		return
	if(prob(min(100, PRISON_RAT_CHANCE * seconds / 60)))
		spawn_rat()

/// The rats the wing brought in that are still alive
/datum/outpost_prison/proc/living_rats()
	var/alive = 0
	for(var/datum/weakref/rat_ref as anything in rat_refs.Copy())
		var/mob/living/rat = rat_ref.resolve()
		if(QDELETED(rat) || rat.stat == DEAD)
			rat_refs -= rat_ref
			continue
		alive++
	return alive

/// A rat on a cell block floor, for filth and for the admin panel. Returns the rat, or null.
/datum/outpost_prison/proc/spawn_rat()
	if(!length(light_tiles))
		return null
	var/turf/spot = pick(light_tiles)
	var/mob/living/basic/mouse/rat = new(spot)
	rat_refs += WEAKREF(rat)
	log_game("PLAYER OUTPOST PRISON: a rat turned up in the prison wing at '[outpost?.name]'")
	for(var/mob/living/basic/outpost_prisoner/prisoner in view(7, spot))
		if(prisoner.prison == src && prisoner.stat == CONSCIOUS && prisoner.say_context("rat"))
			note_speech()
			break
	return rat

/// Someone in the wing to remark on its state
/datum/outpost_prison/proc/pick_conditions_speaker()
	var/list/candidates = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase == PRISONER_PRESENT && prisoner.stat == CONSCIOUS && prisoner.trouble != PRISONER_TROUBLE_LOOSE)
			candidates += prisoner
	return length(candidates) ? pick(candidates) : null

// ===== RIOT LIGHTS =====

/// The strobe runs through a riot, and through a breakout until the rioters who got out are dealt with
/datum/outpost_prison/proc/update_riot_lights()
	set_riot_lights(riot_active || (broke_out && loose_count()))

/**
 * Puts the wing's lights in steady emergency red and strobes the PRISON_STROBE_MAX_LIGHTS nearest
 * the middle of the cell block (PRISON_STROBE_LIGHTS_PER_EXTENSION more for each extension), or
 * puts them all back. Driven directly rather than through the
 * fire alarm, so no firelocks close.
 */
/datum/outpost_prison/proc/set_riot_lights(on)
	on = !!on
	if(on == riot_lights_on)
		return
	riot_lights_on = on
	if(on)
		var/list/found = list()
		for(var/turf/tile as anything in wing_turfs())
			for(var/obj/machinery/light/fixture in tile)
				found += fixture
		riot_lights = list()
		for(var/obj/machinery/light/fixture as anything in found)
			fixture.major_emergency = TRUE
			redraw_light(fixture)
			riot_lights += WEAKREF(fixture)
		strobe_lights = list()
		for(var/obj/machinery/light/fixture as anything in nearest_to_cell_block(found, PRISON_STROBE_MAX_LIGHTS + PRISON_STROBE_LIGHTS_PER_EXTENSION * extension_count()))
			strobe_lights += WEAKREF(fixture)
		strobe_bright = TRUE
		strobe_timer = addtimer(CALLBACK(src, PROC_REF(strobe_step)), PRISON_STROBE_INTERVAL, TIMER_STOPPABLE | TIMER_DELETE_ME)
		return
	if(strobe_timer)
		deltimer(strobe_timer)
		strobe_timer = null
	for(var/datum/weakref/light_ref as anything in riot_lights)
		var/obj/machinery/light/fixture = light_ref.resolve()
		if(!fixture)
			continue
		fixture.major_emergency = FALSE
		redraw_light(fixture)
	riot_lights = null
	strobe_lights = null

/**
 * Makes a light show what it should now (normal, or emergency red), with its switch count kept so
 * a riot does not wear it out. update() alone is not enough: it leaves the light as it is whenever
 * its light source still holds the values it is about to set, which is the case until the
 * lighting subsystem has drawn the last change (a busy server, or a riot over before the red was
 * drawn), and its burn-out roll can skip the change. Clearing the light first and zeroing the
 * count makes it set the light every time.
 */
/datum/outpost_prison/proc/redraw_light(obj/machinery/light/fixture)
	var/switches = fixture.switchcount
	fixture.set_light(l_range = 0)
	fixture.switchcount = -1
	fixture.update(FALSE)
	fixture.switchcount = switches

/// The `count` lights of `lights` nearest the middle of the cell block
/datum/outpost_prison/proc/nearest_to_cell_block(list/lights, count)
	var/list/around = length(light_tiles) ? light_tiles : cell_block
	var/middle_x = 0
	var/middle_y = 0
	if(length(around))
		for(var/turf/tile as anything in around)
			middle_x += tile.x
			middle_y += tile.y
		middle_x /= length(around)
		middle_y /= length(around)
	var/list/distances = list()
	for(var/obj/machinery/light/fixture as anything in lights)
		distances[fixture] = (fixture.x - middle_x) ** 2 + (fixture.y - middle_y) ** 2
	var/list/nearest = list()
	while(length(distances) && length(nearest) < count)
		var/obj/machinery/light/closest
		for(var/obj/machinery/light/fixture as anything in distances)
			if(!closest || distances[fixture] < distances[closest])
				closest = fixture
		distances -= closest
		nearest += closest
	return nearest

/// One half of the strobe: bright red, then dim red
/datum/outpost_prison/proc/strobe_step()
	strobe_timer = null
	if(QDELETED(src) || !riot_lights_on)
		return
	strobe_bright = !strobe_bright
	for(var/datum/weakref/light_ref as anything in strobe_lights)
		var/obj/machinery/light/fixture = light_ref.resolve()
		if(!fixture || !fixture.on || fixture.status != LIGHT_OK || !fixture.major_emergency)
			continue
		fixture.set_light(l_power = strobe_bright ? fixture.bulb_power : PRISON_STROBE_DIM)
	strobe_timer = addtimer(CALLBACK(src, PROC_REF(strobe_step)), PRISON_STROBE_INTERVAL, TIMER_STOPPABLE | TIMER_DELETE_ME)

// ===== CLEAN UP =====

/// The prison is going: the flies go with it, and the rats are on their own
/datum/outpost_prison/proc/clear_conditions(datum/source)
	SIGNAL_HANDLER
	for(var/turf/tile as anything in fly_effects)
		var/datum/weakref/fly_ref = fly_effects[tile]
		var/obj/effect/outpost_prison_flies/flies = fly_ref?.resolve()
		if(flies)
			qdel(flies)
	fly_effects = list()
	heavy_since = list()
	mess_scan_heavy = list()
	mess_floor = list()
	structure_tiles = list()
	light_tiles = list()
	wing_lights = list()
	rat_refs = list()

#undef PRISON_MESS_REFRESH_SECONDS
#undef PRISON_AIR_STEP_SECONDS
#undef PRISON_AIR_LINE_CHANCE
