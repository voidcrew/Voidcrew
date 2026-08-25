/**
 * # Colosseum match modifiers
 *
 * One modifier is weight-rolled at roster lock and announced with the stakes
 * ("Arena condition: ..."). Where the arena-event scheduler sprinkles one-off
 * surprises, a modifier shapes the whole match: beast waves, killing heat or
 * cold, walls that rearrange the floor, or a sky that rains weapon crates.
 * Modifiers are mode-agnostic, KOTH scoring ignores beasts (only roster
 * entries hold the dais) and CTF flags can't be carried by mobs, so every
 * combination stays sane.
 *
 * Lifecycle: created at roster lock, on_match_start() when the gates pop,
 * on_match_end() at resolution (before the sweep, so cleanup and bonus
 * payouts land ahead of the claim window), qdel'd immediately after.
 */
/datum/colosseum_modifier
	/// Display name. Null marks an abstract base the roll skips.
	var/name
	var/desc
	var/weight = 10
	/// Minimum locked roster size for this modifier to be rolled
	var/min_roster = 2
	/// Back-reference, set by the controller when rolled
	var/datum/colosseum_controller/controller
	/// Whether on_match_start() has run (guards cleanup on early cancels)
	var/started = FALSE

/datum/colosseum_modifier/Destroy()
	controller = null
	return ..()

/// Called when the gates pop.
/datum/colosseum_modifier/proc/on_match_start()
	SHOULD_CALL_PARENT(TRUE)
	started = TRUE

/// Called once at resolution (or admin cancel). Clean up everything.
/datum/colosseum_modifier/proc/on_match_end()
	return

// ===== CLEAN SANDS (the default: no twist) =====

/datum/colosseum_modifier/clean
	name = "Clean Sands"
	desc = "No tricks, no beasts. Just you and them."
	weight = 30

// ===== BEAST INTERLUDE (PvE waves) =====

/**
 * Waves of arena beasts released onto the sand mid-match. They fight
 * everyone (own faction, so not each other); every beast slain fattens the
 * prize pool, and the wardens drag the carcasses off during the sweep.
 */
/datum/colosseum_modifier/beast_interlude
	name = "Beast Interlude"
	desc = "The undercroft cages are open. Beasts on the sand with you, and every kill adds to the purse."
	weight = 15
	min_roster = 3
	/// Waves still to release
	var/waves_left = 2
	/// Pending wave timer (TIMER_STOPPABLE)
	var/wave_timer
	/// Live beast mobs we spawned
	var/list/mob/living/beasts = list()
	/// Beasts slain by anyone (bonus-payout counter)
	var/kills = 0

/datum/colosseum_modifier/beast_interlude/Destroy()
	cleanup_beasts()
	return ..()

/datum/colosseum_modifier/beast_interlude/on_match_start()
	. = ..()
	waves_left = length(controller.roster) >= 6 ? 3 : 2
	wave_timer = addtimer(CALLBACK(src, PROC_REF(release_wave)), 45 SECONDS, TIMER_STOPPABLE)

/datum/colosseum_modifier/beast_interlude/proc/release_wave()
	wave_timer = null
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	waves_left--
	var/live_fighters = length(controller.live_entries())
	var/wave_size = clamp(round(live_fighters / 2) + 1, 2, 5)
	var/static/list/beast_weights = list(
		/mob/living/basic/carp = 30,
		/mob/living/basic/mining/watcher = 25,
		/mob/living/basic/mining/goliath = 25,
		/mob/living/basic/mining/brimdemon = 15,
		/mob/living/basic/mining/legion = 5,
	)
	var/list/spawn_turfs = list()
	for(var/i in 1 to wave_size)
		var/turf/spot = controller.arena_event_turf()
		if(spot)
			spawn_turfs += spot
			new /obj/effect/temp_visual/colosseum_warning(spot)
	controller.site.venue_message(span_boldannounce("The undercroft grates rattle, BEASTS take the sand!"))
	playsound(controller.site.spoils_vault || controller.site.signup_console, 'sound/machines/warning-buzzer.ogg', 60, TRUE)
	addtimer(CALLBACK(src, PROC_REF(spawn_wave), spawn_turfs, beast_weights), COLOSSEUM_EVENT_TELEGRAPH, TIMER_STOPPABLE)
	if(waves_left > 0)
		wave_timer = addtimer(CALLBACK(src, PROC_REF(release_wave)), 90 SECONDS, TIMER_STOPPABLE)

/datum/colosseum_modifier/beast_interlude/proc/spawn_wave(list/turf/spawn_turfs, list/beast_weights)
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	for(var/turf/spot as anything in spawn_turfs)
		if(QDELETED(spot))
			continue
		var/beast_type = pick_weight(beast_weights)
		var/mob/living/beast = new beast_type(spot)
		beast.faction = list("colosseum") // beasts side with beasts, and nobody else
		beasts += beast
		RegisterSignal(beast, COMSIG_LIVING_DEATH, PROC_REF(on_beast_death))
		RegisterSignal(beast, COMSIG_QDELETING, PROC_REF(on_beast_gone))

/datum/colosseum_modifier/beast_interlude/proc/on_beast_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	kills++
	controller?.site?.venue_message(span_boldannounce("\The [source] is slain! The purse grows. ([kills] beast\s down)"))

/datum/colosseum_modifier/beast_interlude/proc/on_beast_gone(mob/living/source)
	SIGNAL_HANDLER
	beasts -= source

/// Wardens haul every beast (and carcass) back to the undercroft.
/datum/colosseum_modifier/beast_interlude/proc/cleanup_beasts()
	if(wave_timer)
		deltimer(wave_timer)
		wave_timer = null
	for(var/mob/living/beast as anything in beasts)
		if(QDELETED(beast))
			continue
		UnregisterSignal(beast, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		qdel(beast)
	beasts.Cut()

/datum/colosseum_modifier/beast_interlude/on_match_end()
	cleanup_beasts()
	if(!kills)
		return
	var/obj/machinery/colosseum_vault/vault = controller?.site?.spoils_vault
	if(!vault)
		return
	new /obj/item/holochip(vault, kills * 150)
	for(var/i in 1 to round(kills / 3))
		var/static/list/bonus_part_weights = list(
			/obj/item/ship_parts/combat = 55,
			/obj/item/ship_parts/science = 15,
			/obj/item/ship_parts/trade = 15,
			/obj/item/ship_parts/misc = 15,
		)
		var/part_type = pick_weight(bonus_part_weights)
		new part_type(vault)
	controller.site.venue_message(span_notice("The beast bounty is added to the spoils: [kills * 150] credits[kills >= 3 ? " and salvage" : ""]."))

// ===== TEMPERATURE (scorching / freezing) =====

/**
 * The arena bakes or freezes: contestants on the sand fight their body
 * temperature as well as each other. Retreating through an open gate into
 * staging pauses the pressure, at the cost of ground.
 */
/datum/colosseum_modifier/temperature
	/// Body-temperature push per second while in the arena area
	var/delta = 0
	/// Clamps passed to adjust_bodytemperature: dangerous, not instantly lethal
	var/min_temp = 0
	var/max_temp = INFINITY
	/// Occasional flavor line shown to affected fighters
	var/flavor

/datum/colosseum_modifier/temperature/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/datum/colosseum_modifier/temperature/on_match_start()
	. = ..()
	START_PROCESSING(SSprocessing, src)

/datum/colosseum_modifier/temperature/on_match_end()
	STOP_PROCESSING(SSprocessing, src)

/datum/colosseum_modifier/temperature/process(seconds_per_tick)
	if(!controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	for(var/datum/colosseum_contestant/entry as anything in controller.live_entries())
		var/mob/living/body = entry.body
		if(!isliving(body) || body.stat == DEAD)
			continue
		if(!istype(get_area(body), /area/voidcrew/colosseum/arena))
			continue
		body.adjust_bodytemperature(delta * seconds_per_tick, min_temp, max_temp)
		if(flavor && prob(5))
			to_chat(body, span_warning(flavor))

/datum/colosseum_modifier/temperature/scorching
	name = "Scorching Sands"
	desc = "The floor braziers are stoked white-hot. The sand cooks whoever stands on it."
	weight = 10
	delta = 8
	max_temp = 390
	flavor = "The heat off the sand sears your lungs."

/datum/colosseum_modifier/temperature/freezing
	name = "Freezing Gale"
	desc = "The vents are blasting glacier-cold air. Keep moving or freeze."
	weight = 10
	delta = -8
	min_temp = 252
	flavor = "The cold gnaws through everything you're wearing."

// ===== SHIFTING WALLS =====

/**
 * The arena rearranges itself: lines of barricade cover rise from the sand
 * every shift, and the previous set crumbles. Sightlines never stay safe.
 */
/datum/colosseum_modifier/shifting_walls
	name = "Shifting Walls"
	desc = "The arena floor rebuilds itself while you fight. No lane stays safe."
	weight = 12
	/// Barricades from the current shift
	var/list/obj/structure/active_walls = list()
	/// Pending shift timer (TIMER_STOPPABLE)
	var/shift_timer

/datum/colosseum_modifier/shifting_walls/Destroy()
	crumble_walls()
	if(shift_timer)
		deltimer(shift_timer)
		shift_timer = null
	return ..()

/datum/colosseum_modifier/shifting_walls/on_match_start()
	. = ..()
	shift_timer = addtimer(CALLBACK(src, PROC_REF(shift)), 20 SECONDS, TIMER_STOPPABLE)

/datum/colosseum_modifier/shifting_walls/proc/shift()
	shift_timer = null
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	crumble_walls()
	var/list/turf/wall_turfs = list()
	for(var/line in 1 to 2)
		var/turf/start = controller.arena_event_turf()
		if(!start)
			continue
		var/direction = pick(GLOB.cardinals)
		var/turf/cursor = start
		for(var/i in 1 to 5)
			if(!cursor || !istype(cursor.loc, /area/voidcrew/colosseum/arena))
				break
			if(!cursor.is_blocked_turf() && !istype(cursor, /turf/open/indestructible))
				wall_turfs += cursor
				new /obj/effect/temp_visual/colosseum_warning(cursor)
			cursor = get_step(cursor, direction)
	if(length(wall_turfs))
		controller.site.venue_message(span_boldannounce("The sand churns, the walls are shifting!"))
		addtimer(CALLBACK(src, PROC_REF(raise_walls), wall_turfs), COLOSSEUM_EVENT_TELEGRAPH, TIMER_STOPPABLE)
	shift_timer = addtimer(CALLBACK(src, PROC_REF(shift)), 60 SECONDS, TIMER_STOPPABLE)

/datum/colosseum_modifier/shifting_walls/proc/raise_walls(list/turf/wall_turfs)
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	for(var/turf/wall_turf as anything in wall_turfs)
		if(QDELETED(wall_turf) || wall_turf.is_blocked_turf())
			continue
		active_walls += new /obj/structure/barricade/sandbags(wall_turf)

/datum/colosseum_modifier/shifting_walls/proc/crumble_walls()
	for(var/obj/structure/wall as anything in active_walls)
		if(!QDELETED(wall))
			qdel(wall)
	active_walls.Cut()

/datum/colosseum_modifier/shifting_walls/on_match_end()
	if(shift_timer)
		deltimer(shift_timer)
		shift_timer = null
	crumble_walls()

// ===== RAINING STEEL =====

/**
 * Weapon crates fall constantly. Independent of the one-off scheduler, so it
 * works in every mode, including the ones that turn the scheduler off.
 */
/datum/colosseum_modifier/raining_steel
	name = "Raining Steel"
	desc = "Weapon crates keep falling all match. Control the drops and you control the match."
	weight = 12
	/// Pending drop timer (TIMER_STOPPABLE)
	var/drop_timer

/datum/colosseum_modifier/raining_steel/Destroy()
	if(drop_timer)
		deltimer(drop_timer)
		drop_timer = null
	return ..()

/datum/colosseum_modifier/raining_steel/on_match_start()
	. = ..()
	drop_timer = addtimer(CALLBACK(src, PROC_REF(next_drop)), 25 SECONDS, TIMER_STOPPABLE)

/datum/colosseum_modifier/raining_steel/proc/next_drop()
	drop_timer = null
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	controller.drop_weapon_crate()
	drop_timer = addtimer(CALLBACK(src, PROC_REF(next_drop)), rand(35 SECONDS, 55 SECONDS), TIMER_STOPPABLE)

/datum/colosseum_modifier/raining_steel/on_match_end()
	if(drop_timer)
		deltimer(drop_timer)
		drop_timer = null
