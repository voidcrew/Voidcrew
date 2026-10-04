/**
 * # Prison wing events
 *
 * The wing's fixtures fail now and then, however well it is kept (owner, 2026-09-25):
 * - Blown lights: PRISON_WING_LIGHTS_MIN to _MAX working lights in the cell block burst, with tg's
 *   usual breaking glass and sparks. Lit falls until someone replaces the tubes, and a restless
 *   wing that goes dark gets the usual lights-out spark (outpost_prison_conditions.dm).
 * - A scrubber overflows: tg's scrubber overflow (code/modules/events/scrubber_overflow.dm) aimed at
 *   the wing (owner, 2026-09-25). One air scrubber in the cell block, sometimes two, gurgles for
 *   PRISON_WING_GURGLE_TIME, then each brings up tg's short-lived foam laced with something filthy
 *   but harmless (GLOB.outpost_prison_overflow_reagents). The foam keeps to the cell block, slips
 *   nobody, and leaves filth where it dies, so Clean falls until it is mopped. Welding a scrubber
 *   shut while it gurgles stops it. With no unwelded scrubber in the cell block, a sealed Kessler
 *   vent (outpost_prison_vents.dm) backs up instead and spews filth over the floor around it.
 * - A cell toilet overflows: the same gurgle, then that cell's floor is wet for a while and a
 *   little dirty. The water only slips people who run, and prisoners never slip.
 * One comes every PRISON_WING_EVENT_GAP_MIN to _MAX seconds of crew-home time, while there are
 * prisoners in the wing and nothing else is going on (no riot, nobody loose; an experiment under way
 * holds nothing, owner 2026-09-25). Each is logged on the warden console and shows in the wing, and
 * prisoners who see it say something and step out of the mess. None of them fines anyone. Numbers in
 * voidcrew/_DEFINES/outpost_prison_incidents.dm.
 *
 * Only fixtures in the cell block take part, so scrubbers built in the office never overflow,
 * and nothing outside the cell block is touched.
 */

/// What a backed-up vent brings up, and what overflow foam leaves where it dies, by weight: types the mess scan counts (outpost_prison_conditions.dm)
GLOBAL_LIST_INIT(outpost_prison_vent_filth, list(
	/obj/effect/decal/cleanable/dirt = 3,
	/obj/effect/decal/cleanable/vomit/outpost_sludge = 2,
))

/**
 * What an overflowing scrubber's foam carries, by weight. Filthy and harmless only: prison slop,
 * soot and mould. Never an acid, a toxin, a drug or anything slippery, whatever tg's own list holds.
 */
GLOBAL_LIST_INIT(outpost_prison_overflow_reagents, list(
	/datum/reagent/consumable/nutraslop = 3,
	/datum/reagent/ash = 2,
	/datum/reagent/consumable/mold = 1,
))

/datum/outpost_prison
	/// Whether wing events happen at all; the tests' prison fixture turns them off
	var/wing_events_enabled = TRUE
	/// Seconds of crew-home time before the next wing event; set on the first tick
	var/wing_event_left
	/// "scrubber" or "toilet" while one gurgles, weakrefs to what is gurgling, and the seconds left
	var/wing_event_pending
	var/list/datum/weakref/wing_event_sources = list()
	var/wing_event_gurgle_left = 0
	/// Tests only: the kind a random wing event takes
	var/wing_event_force_kind
	/// Tests only: TRUE or FALSE forces whether a second scrubber joins an overflow
	var/wing_event_force_second

// ===== THE CLOCK =====

/// Why the wing events' clock is not running now, in a few words for the admin panel, or null when it is
/datum/outpost_prison/proc/wing_event_clock_paused()
	if(!wing_events_enabled)
		return "off"
	if(!crew_home())
		return "nobody home"
	if(wing_event_pending)
		return "one under way"
	if(riot_active || breaking_out)
		return "riot"
	if(loose_count())
		return "someone loose"
	if(!wildcard_prisoner_count())
		return "no prisoners"
	return null

/// Advances a gurgle under way and the clock by `seconds`; the extras' tick calls it
/datum/outpost_prison/proc/wing_events_tick(seconds)
	if(wing_event_pending)
		gurgle_tick(seconds)
		return
	if(isnull(wing_event_left))
		wing_event_left = rand(PRISON_WING_EVENT_GAP_MIN, PRISON_WING_EVENT_GAP_MAX)
	if(wing_event_clock_paused())
		return
	wing_event_left -= seconds
	if(wing_event_left > 0)
		return
	wing_event_left = start_wing_event() ? rand(PRISON_WING_EVENT_GAP_MIN, PRISON_WING_EVENT_GAP_MAX) : PRISON_WING_EVENT_RETRY

/**
 * Starts a wing event of `kind` ("lights", "scrubber" or "toilet"), or one picked by weight among
 * those the wing has the fixtures for. A scrubber or toilet gurgles first. Returns the kind started,
 * or null.
 */
/datum/outpost_prison/proc/start_wing_event(kind)
	if(wing_event_pending)
		return null
	kind = kind || wing_event_force_kind
	var/list/lights = blowable_lights()
	var/list/sources = overflow_sources()
	var/list/toilets = cell_toilets()
	var/list/options = list()
	if(length(lights))
		options["lights"] = PRISON_WING_EVENT_WEIGHT_LIGHTS
	if(length(sources))
		options["scrubber"] = PRISON_WING_EVENT_WEIGHT_SCRUBBER
	if(length(toilets))
		options["toilet"] = PRISON_WING_EVENT_WEIGHT_TOILET
	if(kind)
		if(!options[kind])
			return null
		options = list((kind) = 1)
	switch(pick_weight(options))
		if("lights")
			return blow_lights(lights) ? "lights" : null
		if("scrubber")
			return begin_backup(pick_overflow_sources(sources), "scrubber")
		if("toilet")
			return begin_backup(list(pick(toilets)), "toilet")
	return null

/// Why an admin can't start a wing event of `kind` now, or null
/datum/outpost_prison/proc/wing_event_refusal(kind)
	if(wing_event_pending)
		return "Something is already backing up."
	switch(kind)
		if("lights")
			if(!length(blowable_lights()))
				return "No working light in the wing."
		if("scrubber")
			if(!length(overflow_sources()))
				return "No scrubber or vent in the cell block can overflow."
		if("toilet")
			if(!length(cell_toilets()))
				return "No cell has a toilet."
	return null

/// An admin started one: the clock starts over, so the next does not follow straight after
/datum/outpost_prison/proc/wing_event_admin_started()
	wing_event_left = rand(PRISON_WING_EVENT_GAP_MIN, PRISON_WING_EVENT_GAP_MAX)

// ===== BLOWN LIGHTS =====

/// Working lights in the cell block, or failing that anywhere in the wing
/datum/outpost_prison/proc/blowable_lights()
	var/list/in_block = list()
	var/list/elsewhere = list()
	for(var/turf/tile as anything in wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(QDELETED(fixture) || fixture.status != LIGHT_OK)
				continue
			if(in_cell_block(fixture))
				in_block += fixture
			else
				elsewhere += fixture
	return length(in_block) ? in_block : elsewhere

/// PRISON_WING_LIGHTS_MIN to _MAX of `lights` burst, with glass and sparks. Returns how many.
/datum/outpost_prison/proc/blow_lights(list/lights)
	var/list/candidates = lights.Copy()
	var/count = min(rand(PRISON_WING_LIGHTS_MIN, PRISON_WING_LIGHTS_MAX), length(candidates))
	var/list/blown = list()
	for(var/i in 1 to count)
		var/obj/machinery/light/fixture = pick_n_take(candidates)
		fixture.break_light_tube()
		fixture.visible_message(span_warning("[fixture] pops and goes dark!"))
		blown += fixture
	if(!length(blown))
		return 0
	add_log(length(blown) == 1 ? "A light blew in the wing." : "[length(blown)] lights blew in the wing.")
	wing_event_react("wing_lights_blown", blown[1])
	return length(blown)

// ===== OVERFLOWING SCRUBBERS, BACKED-UP VENTS AND TOILETS =====

/**
 * What can overflow in the cell block: the air scrubbers not welded shut, or, with none of those,
 * the Kessler vents with their covers on and nothing in the duct
 */
/datum/outpost_prison/proc/overflow_sources()
	var/list/scrubbers = list()
	var/list/kessler_vents = list()
	for(var/turf/tile as anything in wing_turfs())
		if(!in_cell_block(tile))
			continue
		for(var/obj/thing in tile)
			if(istype(thing, /obj/machinery/atmospherics/components/unary/vent_scrubber))
				if(can_back_up(thing))
					scrubbers += thing
			else if(istype(thing, /obj/structure/outpost_kessler_vent))
				if(can_back_up(thing))
					kessler_vents += thing
	return length(scrubbers) ? scrubbers : kessler_vents

/**
 * The one or two of `sources` that overflow: a scrubber, and PRISON_OVERFLOW_SECOND_CHANCE percent
 * of the time a second one with it. A Kessler vent backs up on its own.
 */
/datum/outpost_prison/proc/pick_overflow_sources(list/sources)
	var/list/candidates = sources.Copy()
	var/obj/first = pick_n_take(candidates)
	var/list/picked = list(first)
	if(!istype(first, /obj/machinery/atmospherics/components/unary/vent_scrubber) || !length(candidates))
		return picked
	var/second = isnull(wing_event_force_second) ? prob(PRISON_OVERFLOW_SECOND_CHANCE) : wing_event_force_second
	if(second)
		picked += pick(candidates)
	return picked

/// Whether a scrubber, vent or toilet can back up now: not gone, not welded shut, not open, nothing in the duct
/datum/outpost_prison/proc/can_back_up(obj/thing)
	if(QDELETED(thing) || !isturf(thing.loc) || get_area(thing) != wing)
		return FALSE
	if(istype(thing, /obj/structure/outpost_kessler_vent))
		var/obj/structure/outpost_kessler_vent/kessler = thing
		return !kessler.open && !kessler.occupant && !kessler.wrenching
	if(istype(thing, /obj/machinery/atmospherics/components/unary))
		var/obj/machinery/atmospherics/components/unary/vent = thing
		return !vent.welded
	return TRUE

/// The toilets inside the cells
/datum/outpost_prison/proc/cell_toilets()
	var/list/found = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		var/obj/structure/toilet/toilet = contraband_cistern(cell)
		if(toilet)
			found += toilet
	return found

/// The things gurgling now, forgetting any that are gone
/datum/outpost_prison/proc/wing_event_source_objects()
	var/list/found = list()
	for(var/datum/weakref/ref as anything in wing_event_sources)
		var/obj/source = ref.resolve()
		if(source && !QDELETED(source))
			found += source
	return found

/// `sources` start to gurgle; PRISON_WING_GURGLE_TIME later they back up (finish_backup()). Returns `kind`.
/datum/outpost_prison/proc/begin_backup(list/sources, kind)
	wing_event_pending = kind
	wing_event_sources = list()
	wing_event_gurgle_left = PRISON_WING_GURGLE_TIME
	for(var/obj/source as anything in sources)
		wing_event_sources += WEAKREF(source)
		playsound(source, 'sound/effects/bubbles/bubbles2.ogg', 50, TRUE)
		source.Shake(1, 0, 0.5 SECONDS)
		source.visible_message(span_warning(kind == "toilet" ? "[source] gurgles. The water in the bowl is rising." : "[source] gurgles and knocks."))
	log_game("PLAYER OUTPOST PRISON: a [kind] event started backing up in the prison wing at '[outpost?.name]' ([length(sources)] source\s)")
	return kind

/// The gurgle goes on, louder halfway, and then it backs up
/datum/outpost_prison/proc/gurgle_tick(seconds)
	var/before = wing_event_gurgle_left
	wing_event_gurgle_left -= seconds
	var/halfway = PRISON_WING_GURGLE_TIME / 2
	if(wing_event_gurgle_left > 0 && before > halfway && wing_event_gurgle_left <= halfway)
		for(var/obj/source as anything in wing_event_source_objects())
			playsound(source, 'sound/effects/bubbles/bubbles.ogg', 60, TRUE)
			source.Shake(1, 0, 0.5 SECONDS)
	if(wing_event_gurgle_left <= 0)
		finish_backup()

/**
 * The gurgle is over: each scrubber overflows, the Kessler vent spews or the toilet floods, unless
 * it was welded shut or taken away meanwhile. Returns how many of them backed up.
 */
/datum/outpost_prison/proc/finish_backup()
	var/list/sources = wing_event_source_objects()
	var/kind = wing_event_pending
	wing_event_pending = null
	wing_event_sources = list()
	wing_event_gurgle_left = 0
	var/list/working = list()
	for(var/obj/source as anything in sources)
		if(can_back_up(source))
			working += source
		else
			source.visible_message(span_notice("[source] goes quiet."))
	if(!length(working))
		return 0
	if(kind == "toilet")
		toilet_flood(working[1])
		return 1
	var/list/scrubbers = list()
	for(var/obj/source as anything in working)
		if(istype(source, /obj/machinery/atmospherics/components/unary/vent_scrubber))
			scrubbers += source
		else
			vent_spew(source)
	if(length(scrubbers))
		scrubber_overflow(scrubbers)
	return length(working)

/**
 * tg's scrubber overflow, from each of `scrubbers`: PRISON_OVERFLOW_FOAM units of a filthy, harmless
 * reagent (GLOB.outpost_prison_overflow_reagents) come up as tg's short-lived foam over up to that
 * many tiles of the cell block, and the foam leaves filth where it dies. Returns the tiles the
 * prisoners step off: open floor within PRISON_VENT_MESS_RANGE of the scrubbers.
 */
/datum/outpost_prison/proc/scrubber_overflow(list/scrubbers)
	var/list/splashed = list()
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in scrubbers)
		var/turf/origin = get_turf(scrubber)
		// As tg's event (scrubber_overflow.dm): a reagent holder on the scrubber, turned into foam
		var/datum/reagents/dispensed = new /datum/reagents(PRISON_OVERFLOW_FOAM)
		dispensed.my_atom = scrubber
		dispensed.add_reagent(pick_weight(GLOB.outpost_prison_overflow_reagents), PRISON_OVERFLOW_FOAM)
		dispensed.create_foam(/datum/effect_system/fluid_spread/foam/short/outpost_prison, PRISON_OVERFLOW_FOAM)
		qdel(dispensed)
		playsound(origin, 'sound/effects/splat.ogg', 60, TRUE)
		scrubber.visible_message(span_danger("[scrubber] overflows and spews filthy froth across the floor!"))
		for(var/mob/living/nearby in view(PRISON_WING_EVENT_REACT_RANGE, origin))
			if(!HAS_TRAIT(nearby, TRAIT_ANOSMIA))
				to_chat(nearby, span_warning("A sour reek rolls out of [scrubber] with the froth."))
		splashed |= backup_tiles(origin, PRISON_VENT_MESS_RANGE)
	add_log(length(scrubbers) == 1 ? "A scrubber in the wing overflowed." : "[length(scrubbers)] scrubbers in the wing overflowed.")
	wing_event_react("wing_scrubber_overflow", scrubbers[1], splashed)
	return splashed

/**
 * Open floor of the cell block within `range` steps of `origin`, reached through open floor only:
 * never through walls, windows, shut doors or tables. `origin` itself always counts.
 */
/datum/outpost_prison/proc/backup_tiles(turf/origin, range)
	var/list/found = list()
	if(!isopenturf(origin))
		return found
	var/list/steps = list()
	steps[origin] = 0
	var/list/queue = list(origin)
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		if(current != origin && current.is_blocked_turf(exclude_mobs = TRUE))
			continue
		found += current
		if(steps[current] >= range)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || !isnull(steps[next]) || next.loc != wing || !isopenturf(next) || !in_cell_block(next))
				continue
			steps[next] = steps[current] + 1
			queue += next
	return found

/**
 * A backed-up Kessler vent (the fallback when no scrubber can overflow) spews PRISON_VENT_MESS_MIN
 * to _MAX pieces of filth over the open floor within PRISON_VENT_MESS_RANGE steps, a tile each while
 * there are tiles to spare, and it stinks. Returns how many pieces were left.
 */
/datum/outpost_prison/proc/vent_spew(obj/vent)
	var/turf/origin = get_turf(vent)
	var/list/tiles = backup_tiles(origin, PRISON_VENT_MESS_RANGE)
	if(!length(tiles))
		return 0
	var/list/free = tiles.Copy()
	var/made = 0
	for(var/i in 1 to rand(PRISON_VENT_MESS_MIN, PRISON_VENT_MESS_MAX))
		if(!length(free))
			free = tiles.Copy()
		var/turf/tile = pick_n_take(free)
		var/filth_type = pick_weight(GLOB.outpost_prison_vent_filth)
		var/obj/effect/decal/cleanable/filth = new filth_type(tile)
		// The same filth twice on one tile merges into the first
		if(!QDELETED(filth))
			made++
	playsound(origin, 'sound/effects/splat.ogg', 60, TRUE)
	vent.visible_message(span_danger("[vent] backs up and spews filth across the floor!"))
	for(var/mob/living/nearby in view(PRISON_WING_EVENT_REACT_RANGE, origin))
		if(!HAS_TRAIT(nearby, TRAIT_ANOSMIA))
			to_chat(nearby, span_warning("A reek of sewage rolls out of [vent]."))
	add_log("A vent in the wing backed up and spewed filth.")
	wing_event_react("wing_scrubber_overflow", vent, tiles)
	return made

/**
 * An overflowing cell toilet: the cell's floor goes wet for PRISON_TOILET_WET_TIME and gets a little
 * dirt. Only the cell floods. Returns how many tiles got wet.
 */
/datum/outpost_prison/proc/toilet_flood(obj/structure/toilet/toilet)
	var/datum/outpost_prison_cell/cell = cell_at(get_turf(toilet))
	var/list/floors = list()
	for(var/turf/open/floor in (cell ? cell.turfs : list(get_turf(toilet))))
		floors += floor
	for(var/turf/open/floor as anything in floors)
		floor.MakeSlippery(TURF_WET_WATER, min_wet_time = PRISON_TOILET_WET_TIME, wet_time_to_add = PRISON_TOILET_WET_TIME / 2)
	var/list/dirty = floors.Copy()
	for(var/i in 1 to rand(PRISON_TOILET_GRIME_MIN, PRISON_TOILET_GRIME_MAX))
		if(!length(dirty))
			break
		new /obj/effect/decal/cleanable/dirt(pick_n_take(dirty))
	playsound(toilet, 'sound/effects/splash.ogg', 50, TRUE)
	toilet.visible_message(span_warning("[toilet] overflows and floods the cell!"))
	add_log(cell ? "The toilet in cell [cell.number] overflowed." : "A toilet in the wing overflowed.")
	wing_event_react("wing_toilet_flood", toilet, floors)
	return length(floors)

// ===== THE YARD'S REACTION =====

/**
 * Prisoners who can see `source` react: up to PRISON_WING_EVENT_MAX_LINES of them say a `context`
 * line, and anyone standing in `tiles` (the filth or the water) leaves what they were idling at and
 * walks out of it.
 */
/datum/outpost_prison/proc/wing_event_react(context, atom/source, list/tiles)
	var/turf/origin = get_turf(source)
	if(!origin)
		return
	var/list/splashed = list()
	if(length(tiles))
		for(var/turf/tile as anything in tiles)
			splashed[tile] = TRUE
	var/lines = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in view(PRISON_WING_EVENT_REACT_RANGE, origin))
		if(prisoner.prison != src || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS || prisoner.in_trouble() || prisoner.activity?.sleeping)
			continue
		prisoner.face_atom(source)
		if(lines < PRISON_WING_EVENT_MAX_LINES && prisoner.say_context(context))
			lines++
		else if(length(splashed) && get_dist(prisoner, origin) <= 2)
			prisoner.manual_emote(pick("gags.", "covers [prisoner.p_their()] nose.", "backs off, grimacing."))
		if(splashed[get_turf(prisoner)])
			step_out_of_mess(prisoner, splashed)
	if(lines)
		note_speech()

/// Out of the mess: whatever idle thing they were doing there ends, and they walk to the nearest clean floor
/datum/outpost_prison/proc/step_out_of_mess(mob/living/basic/outpost_prisoner/prisoner, list/splashed)
	var/datum/prisoner_activity/current = prisoner.activity
	if(current && (!current.leisure || !current.interruptible))
		return FALSE
	if(!prisoner.routine_allowed())
		return FALSE
	if(!prisoner.walkable)
		refresh_prisoner_reach(prisoner)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile in range(PRISON_VENT_MESS_RANGE + 1, prisoner))
		if(splashed[tile] || !prisoner.walkable?[tile] || prisoner.tile_taken(tile) || !prisoner.may_loiter(tile))
			continue
		var/distance = get_dist(prisoner, tile)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	if(!best)
		return FALSE
	var/datum/prisoner_activity/wander/away = new(prisoner)
	away.spot = best
	prisoner.start_activity(away)
	return TRUE

// ===== CLEAN UP =====

/datum/outpost_prison/proc/wing_events_destroy()
	wing_event_pending = null
	wing_event_sources = list()

// ===== THE FILTH =====

/// What a backed-up vent brings up. A kind of vomit to the mess scan: heavy mess.
/obj/effect/decal/cleanable/vomit/outpost_sludge
	name = "sludge"
	desc = "Thick grey-brown sludge that came up out of a vent. It smells exactly as bad as it looks."
	color = "#7a6a4f"

// ===== THE FOAM =====

/// tg's scrubber overflow foam (short-lived) for a prison wing: see the foam below
/datum/effect_system/fluid_spread/foam/short/outpost_prison
	effect_type = /obj/effect/particle_effect/fluid/foam/short_life/outpost_prison

/**
 * Froth from an overflowing prison scrubber: tg's short-lived foam that slips nobody, keeps to the
 * cell block of the prison it came up in, and leaves a piece of filth on each open tile where it dies.
 */
/obj/effect/particle_effect/fluid/foam/short_life/outpost_prison
	name = "filthy froth"
	slippery_foam = FALSE

/obj/effect/particle_effect/fluid/foam/short_life/outpost_prison/make_result()
	var/turf/open/tile = loc
	// Not under tables or anything else a mop can't get at
	if(!istype(tile) || tile.is_blocked_turf(exclude_mobs = TRUE))
		return null
	var/filth_type = pick_weight(GLOB.outpost_prison_vent_filth)
	return new filth_type(tile)

/// tg's foam spread (effects_foam.dm), only onto tiles of the same prison's cell block, and checked from this tile to the next
/obj/effect/particle_effect/fluid/foam/short_life/outpost_prison/spread(seconds_per_tick = 0.2 SECONDS)
	if(group.total_size > group.target_size)
		return
	var/turf/location = get_turf(src)
	if(!istype(location))
		return FALSE
	var/datum/outpost_prison/prison = get_outpost_prison(location)
	if(!prison)
		return FALSE
	var/datum/can_pass_info/info = new(no_id = TRUE)
	info.pass_flags = PASSTABLE | PASSGRILLE | PASSMACHINE | PASSSTRUCTURE
	for(var/iter_dir in GLOB.cardinals)
		var/turf/spread_turf = get_step(src, iter_dir)
		if(!spread_turf || spread_turf.density || location.LinkBlockedWithAccess(spread_turf, info))
			continue
		if(get_outpost_prison(spread_turf) != prison || !prison.in_cell_block(spread_turf))
			continue
		if(locate(/obj/effect/particle_effect/fluid/foam) in spread_turf)
			continue
		if(is_type_in_typecache(spread_turf, blacklisted_turfs))
			continue
		for(var/mob/living/foaming in spread_turf)
			if(HAS_TRAIT(foaming, TRAIT_MOB_ELEVATED))
				continue
			foam_mob(foaming, seconds_per_tick)
		var/obj/effect/particle_effect/fluid/foam/spread_foam = new type(spread_turf, group, src)
		reagents.trans_to(spread_foam, reagents.total_volume, copy_only = TRUE)
		spread_foam.add_atom_colour(color, FIXED_COLOUR_PRIORITY)
		spread_foam.result_type = result_type
		SSfoam.queue_spread(spread_foam)
