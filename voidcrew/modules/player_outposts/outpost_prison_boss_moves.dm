/**
 * # Outpost prison: the bounty bosses' riot moves
 *
 * A caught mini-boss or the kingpin, rebuilt as a prisoner from their record (outpost_prison_bounty.dm),
 * fights like themself in a riot. Each has one move, telegraphed and dodgeable like the field kits
 * (bounty_boss_kits.dm), whose marks and effects it reuses:
 * - Juggernaut: a shoulder charge. Head down and a line marked on the floor, up to
 *   PRISON_BOSS_CHARGE_RANGE tiles toward staff in sight, then he runs it and knocks down the first
 *   member of staff in the way. Walls, doors, windows and anything solid stop him and he reels; he
 *   breaks nothing. Anyone else in the way and he pulls up short.
 * - Pyromaniac: a match onto a bunk near staff. The field kit's scripted burning floor
 *   (/obj/effect/bounty_boss_fire_pool) on the bunk and the tiles right beside it, for
 *   PRISON_BOSS_FIRE_TIME, burning only staff. No real fire, so it never spreads; an extinguisher or
 *   foam on any of its tiles puts it out.
 * - Demolitionist: once a riot, a charge packed against the way out he is already breaking. A beeping,
 *   blinking fuse (the field's /obj/effect/bounty_boss_explosive), then PRISON_BOSS_RIG_SHARE percent of
 *   that fixture's full integrity through the breakout's own rules (outpost_prison_breakout.dm): only
 *   a way out a riot may break, and only with the crew home. Staff right beside it are knocked down.
 * - Ghost: once a riot, cuffed, they work at the cuffs for PRISON_BOSS_SLIP_TIME (a knockdown or a drag
 *   stops it), and the cuffs drop to the floor. Then a shimmer like the field cloak for
 *   PRISON_BOSS_SHIMMER_TIME: half of all hits miss, and a hit that lands or a flash ends it.
 * - Heavy: tg's table flip on the nearest table, toward staff, or a locker shoved into the doorway
 *   staff are coming through. It only blocks: nothing is broken or leaves the cell block.
 * - Kingpin: joining a riot with the crew home, he gives the word and prisoners on the fence join too
 *   (PRISON_BOSS_WORD_BONUS on their riot line). Once a riot he pays off an NPC guard, never a
 *   player, who stays out of the fight for PRISON_BOSS_BRIBE_TIME and then goes back to work.
 *
 * Every move is only for a boss who is rioting or breaking out in the cell block, past the riot's
 * wind-up, awake and on their feet (the Ghost cuffed), with a member of the wing home (crew_home())
 * and someone on the level (ai_running()). Only staff the riot goes for count as targets: awake staff
 * (is_outpost_prison_staff()) in the cell block where the boss could get at them. Never another
 * prisoner, nobody the riot leaves alone.
 *
 * The prison calls in here from one-line hooks: extras_tick() -> boss_moves_tick(),
 * extras_prisoner_leaving() and extras_destroy() (outpost_prison_extras.dm); start_riot() ->
 * boss_kingpin_word() (outpost_prison_riot.dm); trouble_target() -> boss_move_busy()
 * (outpost_prison_trouble.dm); a guard's on_duty() -> boss_bribed() (outpost_prison_guards.dm).
 * Every prisoner and guard proc here is a new proc, never an override: this file is included before
 * the files that define them (see outpost_prison_bounty.dm).
 */

// What a guard activity's tick() wants next, as in outpost_prison_guard_routine.dm (which undefines its own)
#define BOSS_GUARD_ACTIVITY_CONTINUE 0
#define BOSS_GUARD_ACTIVITY_DONE 1

/datum/outpost_prison
	/// Goes up with every riot that starts, for the moves a boss may use once a riot
	var/boss_riot_serial = 0
	/// Weakrefs to guards the kingpin paid off, until they are back at work
	var/list/boss_bribed_guards = list()

/mob/living/basic/outpost_prisoner
	/// Their riot move, made the first time a riot needs it (boss_move_datum()), or null
	var/datum/prison_boss_move/boss_move

/mob/living/basic/outpost_prison_guard
	/// world.time until which they stay out of a riot, paid off by the kingpin
	var/prison_bribed_until = 0

// ===== THE PRISON'S SIDE =====

/// The riot move a prisoner from `record` has (/datum/prison_boss_move subtype), or null for anyone but a mini-boss with a kit or the kingpin
/proc/bounty_boss_move_type(datum/bounty_record/record)
	if(!record)
		return null
	if(record.archetype == BOUNTY_ARCHETYPE_KINGPIN)
		return /datum/prison_boss_move/bribe
	if(record.archetype != BOUNTY_ARCHETYPE_BOSS)
		return null
	switch(record.kit)
		if(BOUNTY_KIT_JUGGERNAUT)
			return /datum/prison_boss_move/charge
		if(BOUNTY_KIT_PYROMANIAC)
			return /datum/prison_boss_move/bed_fire
		if(BOUNTY_KIT_DEMOLITIONIST)
			return /datum/prison_boss_move/rigged_charge
		if(BOUNTY_KIT_GHOST)
			return /datum/prison_boss_move/slip_cuffs
		if(BOUNTY_KIT_HEAVY)
			return /datum/prison_boss_move/barricade
	return null

/**
 * Advances the bosses' moves by `seconds` (extras_tick()): paid-off guards whose time is up go back
 * to work, and while a riot is on, every boss who may use their move and has a target starts it.
 */
/datum/outpost_prison/proc/boss_moves_tick(seconds)
	boss_bribes_tick()
	if(!trouble_enabled || !riot_active)
		return
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		var/datum/prison_boss_move/move = prisoner.boss_move_datum()
		if(!move)
			continue
		move.observe(prisoner)
		move.try_start()

/// A prisoner is leaving the roster (extras_prisoner_leaving()): their move stops
/datum/outpost_prison/proc/boss_moves_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	QDEL_NULL(prisoner.boss_move)

/// The prison is being deleted (extras_destroy())
/datum/outpost_prison/proc/boss_moves_destroy()
	boss_bribed_guards.Cut()

/**
 * Whether `prisoner` may use their move now: rioting or breaking out in the cell block, not shut in a
 * cell, past the riot's wind-up, awake and on their feet, not held, climbing or batoned, with a member
 * of the wing home and someone on the level. Uncuffed, or cuffed if `cuffed`.
 */
/datum/outpost_prison/proc/boss_riot_ok(mob/living/basic/outpost_prisoner/prisoner, cuffed = FALSE)
	if(!trouble_enabled || !riot_active || riot_windup_left > 0 || !crew_home())
		return FALSE
	if(QDELETED(prisoner) || prisoner.prison != src || prisoner.stat != CONSCIOUS || !prisoner.riot_at_large())
		return FALSE
	if(!in_cell_block(prisoner) || !isturf(prisoner.loc) || !prisoner.ai_running())
		return FALSE
	if(prisoner.is_down() || prisoner.pulledby || prisoner.climb_ref || prisoner.beaten_left > 0 || prisoner.surrendered_to_turret() || world.time < prisoner.baton_stop_until)
		return FALSE
	return cuffed ? !!prisoner.cuffs : !prisoner.cuffs

/// Whether a move of `prisoner`'s may land on `person`: awake staff the riot goes for, in the cell block where `prisoner` can get at them
/datum/outpost_prison/proc/boss_may_hit(mob/living/basic/outpost_prisoner/prisoner, mob/living/person)
	if(QDELETED(person) || person == prisoner || !is_outpost_prison_staff(person))
		return FALSE
	return in_cell_block(person) && !!prisoner.reachable?[get_turf(person)]

/// The nearest staff a move of `prisoner`'s may land on (boss_may_hit()) within `range` and in sight, or null
/datum/outpost_prison/proc/boss_nearest_staff(mob/living/basic/outpost_prisoner/prisoner, range = PRISON_BOSS_SIGHT)
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in view(range, prisoner))
		if(!boss_may_hit(prisoner, person))
			continue
		var/distance = get_dist(prisoner, person)
		if(distance < nearest_distance)
			nearest = person
			nearest_distance = distance
	return nearest

/// Straight toward `goal` from `start` along the axis they are furthest apart on, never a diagonal
/proc/boss_move_cardinal_dir(atom/start, atom/goal)
	var/dx = goal.x - start.x
	var/dy = goal.y - start.y
	if(!dx && !dy)
		return NONE
	if(abs(dx) >= abs(dy))
		return dx > 0 ? EAST : WEST
	return dy > 0 ? NORTH : SOUTH

// ===== THE PRISONER'S SIDE =====

/// Their riot move, made the first time it is asked for; null for anyone without one (bounty_boss_move_type())
/mob/living/basic/outpost_prisoner/proc/boss_move_datum()
	if(boss_move)
		return boss_move
	var/move_type = bounty_boss_move_type(bounty_record)
	if(!move_type)
		return null
	boss_move = new move_type(src)
	return boss_move

/// Whether they are winding up or in the middle of their move (or reeling from it), so they hold still (trouble_target())
/mob/living/basic/outpost_prisoner/proc/boss_move_busy()
	return !!boss_move && boss_move.busy_until > world.time

// ===== A MOVE =====

/**
 * A boss prisoner's riot move. try_start() looks for a target (find_target()) and starts the wind-up:
 * the boss holds still and telegraph() shows everyone what is coming, with a sound. When the wind-up
 * is over, effect() does it, unless the boss was knocked down, dragged, stopped rioting or is
 * otherwise no longer free to (may_finish(), checked every PRISON_BOSS_MOVE_WATCH meanwhile). Tests
 * call finish_windup(pending_serial) instead of waiting.
 */
/datum/prison_boss_move
	/// The prisoner whose move it is (/mob/living/basic/outpost_prisoner)
	var/datum/weakref/prisoner_ref
	/// How long it winds up, telegraphing, before anything happens
	var/windup = 1 SECONDS
	/// How long after it starts before it may start again
	var/cooldown = 20 SECONDS
	/// Whether it may be used only once a riot (and in that riot's breakout)
	var/once_per_riot = FALSE
	/// Whether it is used cuffed, rather than free
	var/needs_cuffs = FALSE
	/// The riot (the prison's boss_riot_serial) it was last used in, for once_per_riot
	var/used_in_riot = 0
	/// world.time it may start again
	var/ready_at = 0
	/// The wind-up under way: its serial, 0 when none, and what it is aimed at
	var/pending_serial = 0
	var/datum/weakref/pending_target
	/// world.time until which the boss holds still, their AI quiet (boss_move_busy())
	var/busy_until = 0
	/// Weakrefs to the wind-up's marks still showing
	var/list/telegraphs

/datum/prison_boss_move/New(mob/living/basic/outpost_prisoner/owner)
	. = ..()
	prisoner_ref = WEAKREF(owner)

/datum/prison_boss_move/Destroy()
	cancel()
	prisoner_ref = null
	return ..()

/// The prisoner, while they exist
/datum/prison_boss_move/proc/owner()
	var/mob/living/basic/outpost_prisoner/prisoner = prisoner_ref?.resolve()
	return QDELETED(prisoner) ? null : prisoner

/// Every tick of a riot, before try_start(): anything the move keeps track of
/datum/prison_boss_move/proc/observe(mob/living/basic/outpost_prisoner/prisoner)
	return

/// Starts the move if it is ready, the boss may use it and there is something to use it on. Returns TRUE if it started.
/datum/prison_boss_move/proc/try_start()
	if(pending_serial || world.time < busy_until || world.time < ready_at)
		return FALSE
	var/mob/living/basic/outpost_prisoner/prisoner = owner()
	var/datum/outpost_prison/prison = prisoner?.prison
	if(!prison || (once_per_riot && used_in_riot == prison.boss_riot_serial))
		return FALSE
	if(!prison.boss_riot_ok(prisoner, needs_cuffs))
		return FALSE
	var/atom/target = find_target(prisoner)
	if(QDELETED(target))
		return FALSE
	var/static/next_serial = 0
	var/serial = ++next_serial
	pending_serial = serial
	pending_target = WEAKREF(target)
	ready_at = world.time + cooldown
	busy_until = world.time + windup
	ADD_TRAIT(prisoner, TRAIT_IMMOBILIZED, PRISON_BOSS_MOVE_TRAIT)
	prisoner.ai_controller?.CancelActions()
	if(isturf(target.loc))
		prisoner.face_atom(target)
	telegraph(prisoner, target)
	addtimer(CALLBACK(src, PROC_REF(finish_windup), serial), windup, TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(watch_windup), serial), PRISON_BOSS_MOVE_WATCH, TIMER_DELETE_ME)
	return TRUE

/// Whether the boss is still free to finish the wind-up under way
/datum/prison_boss_move/proc/may_finish(mob/living/basic/outpost_prisoner/prisoner)
	return !!prisoner?.prison?.boss_riot_ok(prisoner, needs_cuffs)

/// During the wind-up: stopped if the boss is no longer free to finish it (knocked down, dragged, cuffed, out of the riot)
/datum/prison_boss_move/proc/watch_windup(serial)
	if(!serial || serial != pending_serial)
		return FALSE
	var/mob/living/basic/outpost_prisoner/prisoner = owner()
	if(!may_finish(prisoner))
		cancel()
		interrupted(prisoner)
		return FALSE
	addtimer(CALLBACK(src, PROC_REF(watch_windup), serial), PRISON_BOSS_MOVE_WATCH, TIMER_DELETE_ME)
	return TRUE

/**
 * The wind-up under `serial` is over: effect(), if the boss is still free to. A move used once a riot
 * counts as used once its effect happened. Returns TRUE if it happened.
 */
/datum/prison_boss_move/proc/finish_windup(serial)
	if(!serial || serial != pending_serial)
		return FALSE
	var/atom/target = pending_target?.resolve()
	var/mob/living/basic/outpost_prisoner/prisoner = owner()
	if(!may_finish(prisoner))
		cancel()
		interrupted(prisoner)
		return FALSE
	pending_serial = 0
	pending_target = null
	busy_until = 0
	clear_telegraphs()
	REMOVE_TRAIT(prisoner, TRAIT_IMMOBILIZED, PRISON_BOSS_MOVE_TRAIT)
	if(!effect(prisoner, target))
		return FALSE
	if(once_per_riot)
		used_in_riot = prisoner.prison.boss_riot_serial
	return TRUE

/// Stops a wind-up under way: its marks go, the boss is free to move, and nothing happens
/datum/prison_boss_move/proc/cancel()
	pending_serial = 0
	pending_target = null
	busy_until = 0
	clear_telegraphs()
	var/mob/living/basic/outpost_prisoner/prisoner = owner()
	if(prisoner)
		REMOVE_TRAIT(prisoner, TRAIT_IMMOBILIZED, PRISON_BOSS_MOVE_TRAIT)

/// What the move goes for now, or null: a member of staff, or a thing near them
/datum/prison_boss_move/proc/find_target(mob/living/basic/outpost_prisoner/prisoner)
	return null

/// Shows everyone what is coming, with a sound and a line
/datum/prison_boss_move/proc/telegraph(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	return

/// Does it. `target` may be gone by now. Returns TRUE if anything happened.
/datum/prison_boss_move/proc/effect(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	return FALSE

/// The wind-up was stopped before it finished
/datum/prison_boss_move/proc/interrupted(mob/living/basic/outpost_prisoner/prisoner)
	return

/// Marks `turfs` for the wind-up, with the field kits' floor marks
/datum/prison_boss_move/proc/mark_turfs(list/turfs, mark_color, mark_state = "target_box")
	for(var/turf/spot as anything in turfs)
		var/obj/effect/temp_visual/bounty_boss_mark/mark = new(spot, windup, mark_color, mark_state)
		LAZYADD(telegraphs, WEAKREF(mark))

/datum/prison_boss_move/proc/clear_telegraphs()
	var/list/to_clear = telegraphs
	telegraphs = null
	for(var/datum/weakref/ref as anything in to_clear)
		var/datum/thing = ref.resolve()
		if(!QDELETED(thing))
			qdel(thing)

// ===== JUGGERNAUT: SHOULDER CHARGE =====

/datum/prison_boss_move/charge
	windup = PRISON_BOSS_CHARGE_WINDUP
	cooldown = PRISON_BOSS_CHARGE_COOLDOWN
	/// The tiles marked for the run, from the telegraph
	var/list/path
	/// How far along the run is
	var/step_index = 0
	/// The run under way, 0 when none, so a stale step does nothing
	var/charge_serial = 0

/datum/prison_boss_move/charge/Destroy()
	charge_serial = 0
	path = null
	return ..()

/// The nearest staff in sight, PRISON_BOSS_CHARGE_MIN_RANGE to _RANGE tiles off, on a line he could run clear to them
/datum/prison_boss_move/charge/find_target(mob/living/basic/outpost_prisoner/prisoner)
	var/datum/outpost_prison/prison = prisoner.prison
	var/mob/living/best
	var/best_distance = INFINITY
	for(var/mob/living/person in view(PRISON_BOSS_CHARGE_RANGE, prisoner))
		var/distance = get_dist(prisoner, person)
		if(distance < PRISON_BOSS_CHARGE_MIN_RANGE || distance >= best_distance || !prison.boss_may_hit(prisoner, person))
			continue
		// Someone already on the floor is no one to knock down
		if(person.body_position == LYING_DOWN || !clear_run_to(prisoner, person))
			continue
		best = person
		best_distance = distance
	return best

/**
 * The line from the boss toward `target`, PRISON_BOSS_CHARGE_RANGE tiles long: it stops at the first
 * wall, and never runs past the cell block's edge.
 */
/datum/prison_boss_move/charge/proc/charge_line(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	. = list()
	var/datum/outpost_prison/prison = prisoner.prison
	var/turf/origin = get_turf(prisoner)
	var/turf/aim = get_turf(target)
	if(!prison || !origin || !aim || origin == aim || origin.z != aim.z)
		return
	var/angle = get_angle(origin, aim)
	var/turf/far = locate(
		clamp(origin.x + round(PRISON_BOSS_CHARGE_RANGE * sin(angle), 1), 1, world.maxx),
		clamp(origin.y + round(PRISON_BOSS_CHARGE_RANGE * cos(angle), 1), 1, world.maxy),
		origin.z,
	)
	for(var/turf/spot as anything in get_line(origin, far))
		if(spot == origin)
			continue
		if(!prison.in_cell_block(spot))
			break
		. += spot
		if(length(.) >= PRISON_BOSS_CHARGE_RANGE || isclosedturf(spot))
			break

/// Whether the line toward `person` reaches them with nothing solid and nobody else before them
/datum/prison_boss_move/charge/proc/clear_run_to(mob/living/basic/outpost_prisoner/prisoner, mob/living/person)
	var/turf/aim = get_turf(person)
	for(var/turf/spot as anything in charge_line(prisoner, person))
		if(spot == aim)
			return TRUE
		if(!prisoner.prison.boss_run_tile_ok(prisoner, spot) || (locate(/mob/living) in spot))
			return FALSE
	return FALSE

/// Whether a charge can run onto `spot`: in the cell block, ground the boss could walk, nothing solid on it
/datum/outpost_prison/proc/boss_run_tile_ok(mob/living/basic/outpost_prisoner/prisoner, turf/spot)
	if(!spot || spot.z != prisoner.z || isclosedturf(spot) || !in_cell_block(spot) || !prisoner.walkable?[spot])
		return FALSE
	if(isgroundlessturf(spot) || islava(spot) || ischasm(spot))
		return FALSE
	return !spot.is_blocked_turf(exclude_mobs = TRUE)

/datum/prison_boss_move/charge/telegraph(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	path = charge_line(prisoner, target)
	prisoner.visible_message(span_boldwarning("[prisoner] drops [prisoner.p_their()] shoulder and lowers [prisoner.p_their()] head!"))
	playsound(prisoner, 'sound/mobs/non-humanoids/gorilla/gorilla.ogg', 60, TRUE)
	prisoner.Shake(1, 0, windup)
	mark_turfs(path, "#c8a060")
	prisoner.say_context("boss_move_charge")

/datum/prison_boss_move/charge/effect(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	if(!length(path) || get_dist(prisoner, path[1]) > 1)
		path = null
		return FALSE
	var/static/next_run = 0
	charge_serial = ++next_run
	step_index = 0
	busy_until = world.time + (length(path) + 1) * PRISON_BOSS_CHARGE_STEP + 1 SECONDS
	prisoner.visible_message(span_danger("[prisoner] charges!"))
	playsound(prisoner, 'sound/effects/meteorimpact.ogg', 40, TRUE)
	prisoner.set_glide_size(DELAY_TO_GLIDE_SIZE(PRISON_BOSS_CHARGE_STEP))
	charge_step(charge_serial)
	return TRUE

/**
 * One tile of the run. Staff on the next tile are slammed and knocked down, and the run is over;
 * anyone else there and he pulls up short. A wall, a door, a window or anything else solid, and he
 * slams into it and reels. Nothing is broken, and he never leaves the cell block.
 */
/datum/prison_boss_move/charge/proc/charge_step(serial)
	var/mob/living/basic/outpost_prisoner/prisoner = owner()
	var/datum/outpost_prison/prison = prisoner?.prison
	if(!serial || serial != charge_serial || !prison || !prison.boss_riot_ok(prisoner))
		end_charge()
		return
	step_index++
	if(step_index > length(path))
		end_charge()
		return
	var/turf/next = path[step_index]
	for(var/mob/living/person in next)
		if(!person.density || person == prisoner)
			continue
		end_charge()
		if(prison.boss_may_hit(prisoner, person))
			slam_into(prisoner, person)
		else
			prisoner.visible_message(span_warning("[prisoner] pulls up short of [person]."))
		return
	if(!prison.boss_run_tile_ok(prisoner, next) || !prisoner.Move(next, get_dir(prisoner, next)))
		bounce(prisoner, next)
		return
	addtimer(CALLBACK(src, PROC_REF(charge_step), serial), PRISON_BOSS_CHARGE_STEP, TIMER_DELETE_ME)

/// Knocks `person` off their feet: brute through melee armour and a knockdown (a guard, who can't be knocked down, takes the blow)
/datum/prison_boss_move/charge/proc/slam_into(mob/living/basic/outpost_prisoner/prisoner, mob/living/person)
	prisoner.face_atom(person)
	prisoner.do_attack_animation(person, ATTACK_EFFECT_SMASH)
	person.visible_message(span_danger("[prisoner] slams into [person]!"), span_userdanger("[prisoner] slams into you!"))
	playsound(person, 'sound/effects/meteorimpact.ogg', 60, TRUE)
	person.apply_damage(PRISON_BOSS_CHARGE_DAMAGE, BRUTE, BODY_ZONE_CHEST, person.run_armor_check(BODY_ZONE_CHEST, MELEE, silent = TRUE))
	person.Knockdown(PRISON_BOSS_CHARGE_KNOCKDOWN)
	shake_camera(person, 3, 2)
	log_combat(prisoner, person, "shoulder-charged")

/// Ran into something solid on `spot`: stopped dead, reeling for PRISON_BOSS_CHARGE_REEL. It takes no harm.
/datum/prison_boss_move/charge/proc/bounce(mob/living/basic/outpost_prisoner/prisoner, turf/spot)
	end_charge()
	if(prisoner.stat != CONSCIOUS)
		return
	var/atom/obstacle = isclosedturf(spot) ? spot : null
	for(var/obj/thing in spot)
		if(thing.density)
			obstacle = thing
			break
	if(obstacle)
		prisoner.visible_message(span_danger("[prisoner] slams into [obstacle] and reels!"))
	else
		prisoner.visible_message(span_danger("[prisoner] crashes to a halt and reels!"))
	playsound(prisoner, 'sound/effects/bang.ogg', 70, TRUE)
	prisoner.Shake(2, 1, PRISON_BOSS_CHARGE_REEL)
	prisoner.Immobilize(PRISON_BOSS_CHARGE_REEL)
	busy_until = world.time + PRISON_BOSS_CHARGE_REEL

/datum/prison_boss_move/charge/proc/end_charge()
	charge_serial = 0
	path = null
	busy_until = 0

// ===== PYROMANIAC: A BUNK ALIGHT =====

/datum/prison_boss_move/bed_fire
	windup = PRISON_BOSS_FIRE_WINDUP
	cooldown = PRISON_BOSS_FIRE_COOLDOWN
	/// The tiles that will burn, from the telegraph
	var/list/patch
	/// The fire burning now, one at a time (/obj/effect/bounty_boss_fire_pool/prison_bed)
	var/datum/weakref/fire_ref

/datum/prison_boss_move/bed_fire/Destroy()
	patch = null
	fire_ref = null
	return ..()

/// A bunk within PRISON_BOSS_FIRE_RANGE tiles, in sight with nothing in the way, with staff standing where it would burn
/datum/prison_boss_move/bed_fire/find_target(mob/living/basic/outpost_prisoner/prisoner)
	if(fire_ref?.resolve())
		return null
	var/datum/outpost_prison/prison = prisoner.prison
	var/turf/here = get_turf(prisoner)
	for(var/obj/structure/bed/bunk in view(PRISON_BOSS_FIRE_RANGE, prisoner))
		if(!prison.boss_bunk_ok(bunk) || !bounty_boss_clear_line(here, get_turf(bunk)))
			continue
		for(var/turf/spot as anything in prison.boss_fire_patch(bunk))
			for(var/mob/living/person in spot)
				if(prison.boss_may_hit(prisoner, person))
					return bunk
	return null

/// Whether `bunk` is one a pyromaniac may set alight: a bed or mattress in the cell block, not a medical bed
/datum/outpost_prison/proc/boss_bunk_ok(obj/structure/bed/bunk)
	return !QDELETED(bunk) && !istype(bunk, /obj/structure/bed/medical) && in_cell_block(bunk)

/// What burns when `bunk` goes up: its tile and the open tiles right beside it in the cell block, never through a wall, a door or a window
/datum/outpost_prison/proc/boss_fire_patch(obj/structure/bed/bunk)
	. = list()
	var/turf/center = get_turf(bunk)
	if(!center)
		return
	. += center
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(center, direction)
		if(!beside || isclosedturf(beside) || !in_cell_block(beside) || beside.is_blocked_turf(exclude_mobs = TRUE))
			continue
		. += beside

/datum/prison_boss_move/bed_fire/telegraph(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	patch = prisoner.prison.boss_fire_patch(target)
	prisoner.visible_message(span_boldwarning("[prisoner] strikes a match and eyes [target]."))
	playsound(prisoner, 'sound/items/match_strike.ogg', 60, TRUE)
	mark_turfs(patch, "#ff5a1f", "target_circle")
	prisoner.say_context("boss_move_fire")

/datum/prison_boss_move/bed_fire/effect(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	var/obj/structure/bed/bunk = target
	var/list/burning = patch
	patch = null
	var/datum/outpost_prison/prison = prisoner.prison
	if(!prison.boss_bunk_ok(bunk) || !length(burning) || !bounty_boss_clear_line(get_turf(prisoner), get_turf(bunk)))
		return FALSE
	prisoner.visible_message(span_danger("[prisoner] flicks the match onto [bunk], and it goes up in flames!"))
	playsound(bunk, 'sound/items/weapons/fwoosh.ogg', 70, TRUE)
	var/obj/effect/bounty_boss_fire_pool/prison_bed/fire = new(get_turf(bunk), burning, PRISON_BOSS_FIRE_TIME, prison, PRISON_BOSS_FIRE_DAMAGE)
	if(QDELETED(fire))
		return FALSE
	fire_ref = WEAKREF(fire)
	return TRUE

/**
 * A pyromaniac's burning bunk: the field kit's scripted burning floor, which burns only the wing's
 * staff in the cell block. No gas, no hotspots, nothing really alight, so it never spreads. Water or
 * foam on any of its tiles (an extinguisher) puts it out.
 */
/obj/effect/bounty_boss_fire_pool/prison_bed
	/// The prison whose staff it burns (/datum/outpost_prison)
	var/datum/weakref/prison_ref

/obj/effect/bounty_boss_fire_pool/prison_bed/Initialize(mapload, list/fire_turfs, lifetime, datum/outpost_prison/prison, landing_damage = 0)
	// Set before the parent's first scorch, which asks may_burn()
	prison_ref = prison ? WEAKREF(prison) : null
	. = ..(mapload, fire_turfs, lifetime, null, landing_damage)
	if(. == INITIALIZE_HINT_QDEL || !length(turfs))
		return
	for(var/turf/spot as anything in turfs)
		RegisterSignal(spot, COMSIG_ATOM_EXPOSE_REAGENTS, PROC_REF(on_exposed))

/obj/effect/bounty_boss_fire_pool/prison_bed/Destroy()
	for(var/turf/spot as anything in turfs)
		UnregisterSignal(spot, COMSIG_ATOM_EXPOSE_REAGENTS)
	prison_ref = null
	return ..()

/obj/effect/bounty_boss_fire_pool/prison_bed/may_burn(atom/victim)
	var/datum/outpost_prison/prison = prison_ref?.resolve()
	var/mob/living/person = victim
	if(QDELETED(prison) || !isliving(person) || ismecha(person.loc))
		return FALSE
	return is_outpost_prison_staff(person) && prison.in_cell_block(person)

/// Water or firefighting foam landed on one of its tiles
/obj/effect/bounty_boss_fire_pool/prison_bed/proc/on_exposed(turf/source, list/exposed, datum/reagents/holder, methods, show_message)
	SIGNAL_HANDLER
	for(var/datum/reagent/reagent as anything in exposed)
		if(istype(reagent, /datum/reagent/water) || istype(reagent, /datum/reagent/firefighting_foam))
			put_out()
			return

/// Put out before its time: the flames go at once
/obj/effect/bounty_boss_fire_pool/prison_bed/proc/put_out()
	if(QDELETED(src))
		return
	for(var/turf/spot as anything in turfs)
		for(var/obj/effect/temp_visual/bounty_boss_flames/flame in spot)
			qdel(flame)
	var/turf/here = get_turf(src)
	if(here)
		here.visible_message(span_notice("The flames hiss out."))
		playsound(here, 'sound/effects/extinguish.ogg', 50, TRUE)
	qdel(src)

// ===== DEMOLITIONIST: A RIGGED CHARGE =====

/datum/prison_boss_move/rigged_charge
	windup = PRISON_BOSS_RIG_WINDUP
	cooldown = PRISON_BOSS_RIG_FUSE
	once_per_riot = TRUE

/**
 * The way out of the cell block he is breaking now, beside him, once the riot's blows have been at it
 * (note_exit_attacked()): a staff door, a serving hatch not yet open, or a window. Never anything else.
 */
/datum/prison_boss_move/rigged_charge/find_target(mob/living/basic/outpost_prisoner/prisoner)
	var/datum/outpost_prison/prison = prisoner.prison
	var/obj/target = prisoner.riot_target_ref?.resolve()
	if(!isobj(target) || !prison.is_exit_blocker(target) || !prisoner.within_reach(target))
		return null
	if(!prison.riot_exits_alerted[get_turf(target)])
		return null
	var/obj/structure/table/reinforced/prison_hatch/hatch = target
	if(istype(hatch) && hatch.both_sides_open())
		return null
	return target

/datum/prison_boss_move/rigged_charge/telegraph(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	prisoner.visible_message(span_boldwarning("[prisoner] crouches by [target] and packs something against it."))
	playsound(prisoner, 'sound/machines/click.ogg', 60, TRUE)
	mark_turfs(list(get_turf(target)), COLOR_RED)
	prisoner.say_context("boss_move_rig")

/datum/prison_boss_move/rigged_charge/effect(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	var/datum/outpost_prison/prison = prisoner.prison
	if(QDELETED(target) || !prison.is_exit_blocker(target))
		return FALSE
	var/obj/effect/bounty_boss_explosive/prison_rig/rig = new(get_turf(target), prison)
	if(QDELETED(rig))
		return FALSE
	target.visible_message(span_danger("Something packed against [target] starts beeping!"))
	return TRUE

/**
 * A demolitionist's packed charge: the field grenade's beeping and blinking ring for
 * PRISON_BOSS_RIG_FUSE, then the prison's own blast (boss_rig_blast()), never a real explosion.
 */
/obj/effect/bounty_boss_explosive/prison_rig
	name = "packed charge"
	desc = "Something packed tight and taped down. It's beeping."
	icon_state = "plastic-explosive0_active"
	fuse = PRISON_BOSS_RIG_FUSE
	radius = 1
	damage = PRISON_BOSS_RIG_DAMAGE
	knockdown = PRISON_BOSS_RIG_KNOCKDOWN
	object_radius = 0
	object_damage = 0
	/// The prison whose way out it is on (/datum/outpost_prison)
	var/datum/weakref/prison_ref

/obj/effect/bounty_boss_explosive/prison_rig/Initialize(mapload, datum/outpost_prison/prison)
	prison_ref = prison ? WEAKREF(prison) : null
	return ..(mapload, null)

/obj/effect/bounty_boss_explosive/prison_rig/Destroy()
	prison_ref = null
	return ..()

/obj/effect/bounty_boss_explosive/prison_rig/beep()
	playsound(src, 'sound/machines/beep/beep.ogg', 60, TRUE)

/obj/effect/bounty_boss_explosive/prison_rig/detonate()
	var/turf/here = get_turf(src)
	var/datum/outpost_prison/prison = prison_ref?.resolve()
	if(here)
		if(QDELETED(prison))
			new /obj/effect/temp_visual/explosion/fast(here)
			playsound(here, 'sound/effects/explosion/explosion1.ogg', 60, TRUE)
		else
			prison.boss_rig_blast(here)
	qdel(src)

/**
 * A packed charge goes off on `tile`. Staff right beside it (not through a wall) take
 * PRISON_BOSS_RIG_DAMAGE against bomb armour and are knocked down; prisoners are not. The way out on
 * the tile takes PRISON_BOSS_RIG_SHARE percent of its full integrity through the breakout's rules
 * (hit_exit()): only while the crew is home, only a way out a riot breaks, and a hatch's window door
 * the way a rioter's blow wears it. Returns TRUE if the way out took it.
 */
/datum/outpost_prison/proc/boss_rig_blast(turf/tile)
	new /obj/effect/temp_visual/explosion/fast(tile)
	playsound(tile, 'sound/effects/explosion/explosion1.ogg', 60, TRUE)
	for(var/mob/living/person in range(1, tile))
		if(!is_outpost_prison_staff(person) || !bounty_boss_clear_line(tile, get_turf(person)))
			continue
		person.apply_damage(PRISON_BOSS_RIG_DAMAGE, BRUTE, BODY_ZONE_CHEST, person.run_armor_check(BODY_ZONE_CHEST, BOMB, silent = TRUE))
		person.Knockdown(PRISON_BOSS_RIG_KNOCKDOWN)
		shake_camera(person, 3, 2)
		to_chat(person, span_userdanger("The blast throws you off your feet!"))
	var/obj/blocker = is_exit_tile(tile) ? exit_blocker(tile) : null
	if(!blocker)
		return FALSE
	if(!crew_home())
		blocker.Shake(1, 1, 0.3 SECONDS)
		return FALSE
	var/label = exit_label(blocker)
	note_exit_attacked(tile, label)
	var/broke = FALSE
	var/obj/structure/table/reinforced/prison_hatch/hatch = blocker
	if(istype(hatch))
		broke = boss_rig_hatch(hatch)
	else
		blocker.take_damage(blocker.max_integrity * PRISON_BOSS_RIG_SHARE / 100, BRUTE, "", TRUE)
		broke = !exit_blocker(tile)
	if(broke)
		exit_broken(label)
	return TRUE

/// A packed charge at a serving hatch: its office side takes it as a rioter's blows wear it, and forced open if it shatters; with that side gone, the yard side takes it. Returns TRUE if the office side gave.
/datum/outpost_prison/proc/boss_rig_hatch(obj/structure/table/reinforced/prison_hatch/hatch)
	var/obj/machinery/door/window/staff_door = hatch.staff_windoor()
	if(staff_door?.density)
		staff_door.take_rioter_damage(staff_door.max_integrity * PRISON_BOSS_RIG_SHARE / 100, null)
		if(!QDELETED(staff_door))
			return FALSE
		hatch.visible_message(span_danger("The office side of [hatch] gives way!"))
		hatch.force_open()
		return TRUE
	var/obj/machinery/door/window/yard_door = hatch.yard_windoor()
	if(yard_door?.density)
		yard_door.take_rioter_damage(yard_door.max_integrity * PRISON_BOSS_RIG_SHARE / 100, null)
	return FALSE

// ===== GHOST: SLIPPING THE CUFFS =====

/datum/prison_boss_move/slip_cuffs
	windup = PRISON_BOSS_SLIP_TIME
	cooldown = PRISON_BOSS_SLIP_RETRY
	once_per_riot = TRUE
	needs_cuffs = TRUE
	/// world.time they were first seen cuffed this time, 0 while they are not
	var/cuffed_at = 0

/datum/prison_boss_move/slip_cuffs/observe(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.cuffs)
		cuffed_at = 0
	else if(!cuffed_at)
		cuffed_at = world.time

/// Their cuffs, once they have worn them PRISON_BOSS_SLIP_DELAY, with staff in sight to get away from
/datum/prison_boss_move/slip_cuffs/find_target(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner.cuffs || !cuffed_at || world.time - cuffed_at < PRISON_BOSS_SLIP_DELAY)
		return null
	if(!prisoner.prison.boss_nearest_staff(prisoner))
		return null
	return prisoner.cuffs

/datum/prison_boss_move/slip_cuffs/may_finish(mob/living/basic/outpost_prisoner/prisoner)
	return ..() && prisoner.cuffs == pending_target?.resolve()

/datum/prison_boss_move/slip_cuffs/telegraph(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	prisoner.visible_message(span_boldwarning("[prisoner] starts twisting at [target], working a hand loose."))
	playsound(prisoner, 'sound/items/weapons/handcuffs.ogg', 40, TRUE)
	prisoner.Shake(1, 0, windup)
	prisoner.say_context("boss_move_slip")

/datum/prison_boss_move/slip_cuffs/interrupted(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner?.stat == CONSCIOUS && prisoner.cuffs)
		prisoner.visible_message(span_notice("[prisoner] loses [prisoner.p_their()] grip on [prisoner.cuffs]."))

/datum/prison_boss_move/slip_cuffs/effect(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	var/obj/item/restraints/handcuffs/worn = prisoner.cuffs
	if(!worn || worn != target)
		return FALSE
	// Without a user they drop where they stand: the same cuffs, on the floor
	prisoner.remove_cuffs()
	prisoner.visible_message(span_danger("[prisoner] slips out of [worn]!"))
	playsound(prisoner, 'sound/effects/magic/smoke.ogg', 40, TRUE)
	prisoner.apply_status_effect(/datum/status_effect/prison_boss_shimmer)
	return TRUE

/**
 * The shimmer after a Ghost slips their cuffs, as the field cloak: faint and blurred for
 * PRISON_BOSS_SHIMMER_TIME, and PRISON_BOSS_SHIMMER_MISS percent of blows, throws and shots miss. A hit
 * that lands or a flash ends it.
 */
/datum/status_effect/prison_boss_shimmer
	id = "prison_boss_shimmer"
	duration = PRISON_BOSS_SHIMMER_TIME
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	/// Broken by a hit or a flash, which says so itself
	var/broken = FALSE
	/// The miss message shows at most every second, so a burst of fire doesn't flood chat
	COOLDOWN_DECLARE(miss_message_cooldown)

/datum/status_effect/prison_boss_shimmer/on_apply()
	if(owner.stat != CONSCIOUS)
		return FALSE
	animate(owner, alpha = PRISON_BOSS_SHIMMER_ALPHA, time = 0.3 SECONDS)
	owner.add_filter("prison_boss_shimmer", 2, list("type" = "blur", "size" = 1))
	RegisterSignal(owner, COMSIG_LIVING_CHECK_BLOCK, PROC_REF(on_check_block))
	RegisterSignal(owner, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_prehit))
	RegisterSignal(owner, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_damaged))
	RegisterSignal(owner, COMSIG_MOB_FLASHED, PROC_REF(on_flashed))
	owner.visible_message(span_warning("[owner] fades into a faint shimmer!"))
	return TRUE

/datum/status_effect/prison_boss_shimmer/on_remove()
	UnregisterSignal(owner, list(COMSIG_LIVING_CHECK_BLOCK, COMSIG_PROJECTILE_PREHIT, COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_MOB_FLASHED))
	animate(owner, alpha = 255, time = 0.3 SECONDS)
	owner.remove_filter("prison_boss_shimmer")
	if(!broken && owner.stat != DEAD)
		owner.visible_message(span_notice("The shimmer around [owner] fades."))

/datum/status_effect/prison_boss_shimmer/proc/miss_message(message)
	if(!COOLDOWN_FINISHED(src, miss_message_cooldown))
		return
	COOLDOWN_START(src, miss_message_cooldown, 1 SECONDS)
	owner.visible_message(message)

/datum/status_effect/prison_boss_shimmer/proc/on_check_block(mob/living/source, atom/hit_by, damage, attack_text, attack_type, armour_penetration, damage_type)
	SIGNAL_HANDLER
	if(owner.stat != CONSCIOUS || !prob(PRISON_BOSS_SHIMMER_MISS))
		return NONE
	miss_message(span_warning("[attack_text] passes through the shimmer where [owner] was!"))
	return SUCCESSFUL_BLOCK

/datum/status_effect/prison_boss_shimmer/proc/on_prehit(mob/living/source, obj/projectile/shot)
	SIGNAL_HANDLER
	if(shot.firer == owner || owner.stat != CONSCIOUS || !prob(PRISON_BOSS_SHIMMER_MISS))
		return NONE
	miss_message(span_warning("[shot] passes through the shimmer around [owner]!"))
	return PROJECTILE_INTERRUPT_HIT_PHASE

/datum/status_effect/prison_boss_shimmer/proc/on_damaged(mob/living/source, damage, damagetype)
	SIGNAL_HANDLER
	if(damage <= 0 || broken)
		return
	broken = TRUE
	owner.visible_message(span_warning("A hit breaks the shimmer around [owner]."))
	qdel(src)

/datum/status_effect/prison_boss_shimmer/proc/on_flashed(mob/living/source)
	SIGNAL_HANDLER
	if(broken)
		return
	broken = TRUE
	owner.visible_message(span_warning("The flash burns away the shimmer around [owner]!"))
	qdel(src)

// ===== HEAVY: A BARRICADE =====

/datum/prison_boss_move/barricade
	windup = PRISON_BOSS_BARRICADE_WINDUP
	cooldown = PRISON_BOSS_BARRICADE_COOLDOWN
	/// A table flip: the way it goes over, toward staff
	var/flip_dir = NONE
	/// A shove: the doorway tile the locker goes to, the shove under way (0 when none) and its steps
	var/turf/shove_to
	var/shove_serial = 0
	var/shove_steps = 0
	/// The locker being shoved (/obj/structure/closet)
	var/datum/weakref/shove_ref

/datum/prison_boss_move/barricade/Destroy()
	shove_to = null
	shove_ref = null
	shove_serial = 0
	return ..()

/**
 * The nearest table beside him that tg lets be flipped, to go over toward the nearest staff in sight;
 * failing that, a locker beside him to shove into the doorway of a staff door staff are coming through.
 */
/datum/prison_boss_move/barricade/find_target(mob/living/basic/outpost_prisoner/prisoner)
	var/datum/outpost_prison/prison = prisoner.prison
	var/mob/living/nearest = prison.boss_staff_about(prisoner, PRISON_BOSS_BARRICADE_SIGHT)
	if(!nearest)
		return null
	for(var/obj/structure/table/table in range(1, prisoner))
		var/direction = boss_move_cardinal_dir(table, nearest)
		if(prison.boss_table_flippable(table, direction))
			flip_dir = direction
			shove_to = null
			return table
	for(var/turf/door_tile as anything in prison.guard_yard_doors())
		if(!prison.boss_staff_coming_through(door_tile))
			continue
		var/turf/front = prison.boss_doorway_front(door_tile, prisoner)
		if(!front)
			continue
		for(var/obj/structure/closet/locker in range(1, prisoner))
			if(get_turf(locker) == front || get_dist(locker, front) > PRISON_BOSS_SHOVE_STEPS || !prison.boss_locker_shovable(locker, prisoner))
				continue
			flip_dir = NONE
			shove_to = front
			return locker
	return null

/// The nearest awake staff in sight within `range` anywhere in the wing, the office included: who a barricade is against
/datum/outpost_prison/proc/boss_staff_about(mob/living/basic/outpost_prisoner/prisoner, range)
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in view(range, prisoner))
		if(person == prisoner || !is_outpost_prison_staff(person) || get_area(person) != wing)
			continue
		var/distance = get_dist(prisoner, person)
		if(distance < nearest_distance)
			nearest = person
			nearest_distance = distance
	return nearest

/**
 * Whether a heavy may flip `table` over toward `direction`: tg lets it be flipped (not reinforced, not
 * already over), it is in the cell block and not outpost property, nobody stands on it, and what it
 * throws off lands in the cell block.
 */
/datum/outpost_prison/proc/boss_table_flippable(obj/structure/table/table, direction)
	if(QDELETED(table) || !direction || !table.can_flip || table.is_flipped || istype(table, /obj/structure/table/reinforced/prison_hatch))
		return FALSE
	if(!in_cell_block(table) || (table.resistance_flags & INDESTRUCTIBLE) || HAS_TRAIT(table, TRAIT_OUTPOST_PROPERTY))
		return FALSE
	var/turf/spot = get_turf(table)
	if(locate(/mob/living) in spot)
		return FALSE
	var/turf/throw_to = get_step(spot, direction)
	return !throw_to || isclosedturf(throw_to) || in_cell_block(throw_to)

/// Whether staff are coming through the staff door on `door_tile`: awake staff within PRISON_BOSS_DOORWAY_RANGE of it, on either side
/datum/outpost_prison/proc/boss_staff_coming_through(turf/door_tile)
	for(var/mob/living/person in range(PRISON_BOSS_DOORWAY_RANGE, door_tile))
		if(is_outpost_prison_staff(person) && get_area(person) == wing)
			return TRUE
	return FALSE

/// The tile straight in front of the staff door on `door_tile`, on the yard side, that `prisoner` can walk and nothing stands on, or null
/datum/outpost_prison/proc/boss_doorway_front(turf/door_tile, mob/living/basic/outpost_prisoner/prisoner)
	for(var/direction in GLOB.cardinals)
		var/turf/front = get_step(door_tile, direction)
		if(!front || !cell_block[front] || isclosedturf(front) || !prisoner.walkable?[front] || front.is_blocked_turf())
			continue
		return front
	return null

/// Whether a heavy may shove `locker`: a shut locker or crate, loose on the floor, in the cell block where `prisoner` can get at it, and not outpost property
/datum/outpost_prison/proc/boss_locker_shovable(obj/structure/closet/locker, mob/living/basic/outpost_prisoner/prisoner)
	if(QDELETED(locker) || locker.anchored || !locker.density || !isturf(locker.loc))
		return FALSE
	if((locker.resistance_flags & INDESTRUCTIBLE) || HAS_TRAIT(locker, TRAIT_OUTPOST_PROPERTY))
		return FALSE
	return in_cell_block(locker) && !!prisoner.reachable?[get_turf(locker)]

/// Whether a shoved locker may go onto `spot`: open ground of the cell block a prisoner could stand on, with nobody and nothing solid on it
/datum/outpost_prison/proc/boss_shove_tile_ok(turf/spot)
	return spot && cell_block[spot] && !isclosedturf(spot) && prisoner_can_stand(spot) && !spot.is_blocked_turf()

/datum/prison_boss_move/barricade/telegraph(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	if(shove_to)
		shove_ref = WEAKREF(target)
		prisoner.visible_message(span_boldwarning("[prisoner] puts [prisoner.p_their()] shoulder to [target]."))
		playsound(prisoner, 'sound/items/weapons/thudswoosh.ogg', 50, TRUE)
		mark_turfs(list(shove_to), "#c0c0c0")
	else
		prisoner.visible_message(span_boldwarning("[prisoner] grabs the edge of [target]."))
		playsound(prisoner, 'sound/items/weapons/thudswoosh.ogg', 50, TRUE)
		mark_turfs(list(get_turf(target)), "#c0c0c0")
	prisoner.say_context("boss_move_barricade")

/datum/prison_boss_move/barricade/effect(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	var/datum/outpost_prison/prison = prisoner.prison
	if(shove_to)
		var/obj/structure/closet/locker = target
		if(!prison.boss_locker_shovable(locker, prisoner) || !prisoner.Adjacent(locker))
			shove_to = null
			return FALSE
		var/static/next_shove = 0
		shove_serial = ++next_shove
		shove_steps = 0
		busy_until = world.time + (PRISON_BOSS_SHOVE_STEPS + 1) * PRISON_BOSS_SHOVE_STEP + 1 SECONDS
		prisoner.visible_message(span_danger("[prisoner] shoves [locker] toward the door!"))
		playsound(locker, 'sound/effects/bang.ogg', 50, TRUE)
		shove_step(shove_serial)
		return TRUE
	var/obj/structure/table/table = target
	if(!prison.boss_table_flippable(table, flip_dir) || !prisoner.Adjacent(table))
		return FALSE
	prisoner.visible_message(span_danger("[prisoner] flips [table] over!"))
	table.flip_table(flip_dir)
	return TRUE

/**
 * One tile of a shove: the locker slides a tile toward the doorway and the heavy steps in behind it.
 * It stops in the doorway, at anything or anyone in the way, or when the heavy can't follow.
 */
/datum/prison_boss_move/barricade/proc/shove_step(serial)
	var/mob/living/basic/outpost_prisoner/prisoner = owner()
	var/datum/outpost_prison/prison = prisoner?.prison
	var/obj/structure/closet/locker = shove_ref?.resolve()
	if(!serial || serial != shove_serial || !prison || !prison.boss_riot_ok(prisoner) || QDELETED(locker) || !shove_to)
		end_shove()
		return
	var/turf/here = get_turf(locker)
	if(here == shove_to || ++shove_steps > PRISON_BOSS_SHOVE_STEPS || !prison.boss_locker_shovable(locker, prisoner))
		end_shove()
		return
	var/turf/next = get_step(here, boss_move_cardinal_dir(here, shove_to))
	if(!prison.boss_shove_tile_ok(next) || !locker.Move(next, get_dir(here, next)))
		end_shove()
		return
	// He steps in behind it, onto the tile it left
	if(!prisoner.Adjacent(locker) && !(prison.boss_shove_tile_ok(here) && prisoner.Move(here, get_dir(prisoner, here))))
		end_shove()
		return
	addtimer(CALLBACK(src, PROC_REF(shove_step), serial), PRISON_BOSS_SHOVE_STEP, TIMER_DELETE_ME)

/datum/prison_boss_move/barricade/proc/end_shove()
	shove_serial = 0
	shove_steps = 0
	shove_to = null
	shove_ref = null
	busy_until = 0

// ===== KINGPIN: THE WORD AND THE PAYOFF =====

/**
 * A riot is starting (start_riot()) with `joining` joining it: a new riot for the moves used once a
 * riot. If the kingpin is among them, able and in the cell block with the crew home, he gives the
 * word: prisoners on the fence, up to PRISON_BOSS_WORD_BONUS mood points above their riot line and
 * able to riot, join too. Not in a riot everyone joins or one prisoner starts alone
 * (`forced_riot`). Returns who joins.
 */
/datum/outpost_prison/proc/boss_kingpin_word(list/joining, forced_riot = FALSE)
	if(!length(joining))
		return joining
	boss_riot_serial++
	if(forced_riot || !crew_home())
		return joining
	var/mob/living/basic/outpost_prisoner/kingpin
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in joining)
		if(prisoner.bounty_record?.archetype != BOUNTY_ARCHETYPE_KINGPIN || prisoner.stat != CONSCIOUS || prisoner.cuffs)
			continue
		if(!in_cell_block(prisoner) || prisoner.is_confined() || !prisoner.ai_running())
			continue
		kingpin = prisoner
		break
	if(!kingpin)
		return joining
	var/list/swayed = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if((prisoner in joining) || !prisoner.can_join_riot())
			continue
		if(prisoner.mood < prisoner.riot_join_mood() + PRISON_BOSS_WORD_BONUS)
			swayed += prisoner
	kingpin.visible_message(span_danger("[kingpin] gives the yard a nod."))
	playsound(kingpin, 'sound/mobs/humanoids/human/snap/fingersnap1.ogg', 60, TRUE)
	if(length(swayed))
		add_log("[kingpin.real_name] gave the word.")
	return joining + swayed

/datum/prison_boss_move/bribe
	windup = PRISON_BOSS_BRIBE_WINDUP
	cooldown = PRISON_BOSS_BRIBE_RETRY
	once_per_riot = TRUE

/// The nearest of the wing's own NPC guards in sight and on duty, never a player
/datum/prison_boss_move/bribe/find_target(mob/living/basic/outpost_prisoner/prisoner)
	var/datum/outpost_prison/prison = prisoner.prison
	var/mob/living/basic/outpost_prison_guard/best
	var/best_distance = INFINITY
	for(var/mob/living/basic/outpost_prison_guard/guard in view(PRISON_BOSS_BRIBE_RANGE, prisoner))
		var/distance = get_dist(prisoner, guard)
		if(distance < best_distance && prison.boss_bribable(guard))
			best = guard
			best_distance = distance
	return best

/// Whether the kingpin may pay off `guard`: one of this wing's guards, on duty, not already paid, and nobody's playing them
/datum/outpost_prison/proc/boss_bribable(mob/living/basic/outpost_prison_guard/guard)
	if(!istype(guard) || QDELETED(guard) || guard.prison != src || !guard.on_duty())
		return FALSE
	return isnull(guard.mind) && isnull(guard.client)

/datum/prison_boss_move/bribe/telegraph(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	prisoner.visible_message(span_boldwarning("[prisoner] catches [target]'s eye and taps [prisoner.p_their()] pocket."))
	playsound(prisoner, 'sound/items/coinflip.ogg', 50, TRUE)
	mark_turfs(list(get_turf(target)), "#e0c050", "target_circle")
	prisoner.say_context("boss_move_bribe")

/datum/prison_boss_move/bribe/effect(mob/living/basic/outpost_prisoner/prisoner, atom/target)
	var/datum/outpost_prison/prison = prisoner.prison
	var/mob/living/basic/outpost_prison_guard/guard = target
	if(!prison.boss_bribable(guard) || get_dist(prisoner, guard) > PRISON_BOSS_BRIBE_RANGE || !(guard in view(PRISON_BOSS_BRIBE_RANGE, prisoner)))
		return FALSE
	prison.boss_bribe_guard(guard)
	return TRUE

/**
 * `guard` takes the kingpin's money: off the fight for PRISON_BOSS_BRIBE_TIME (on_duty() is FALSE, so
 * no riot response, no baton, and rioters leave them be), standing back in the office's far corner.
 * boss_bribes_tick() sends them back to work.
 */
/datum/outpost_prison/proc/boss_bribe_guard(mob/living/basic/outpost_prison_guard/guard)
	guard.prison_bribed_until = world.time + PRISON_BOSS_BRIBE_TIME
	guard.end_response()
	guard.set_baton(FALSE)
	var/datum/outpost_guard_activity/prison_bribed/stand_back = new(guard)
	stand_back.setup()
	guard.start_activity(stand_back)
	guard.visible_message(span_warning("[guard] pockets something and steps back from the fight."))
	playsound(guard, 'sound/items/coinflip.ogg', 50, TRUE)
	boss_bribed_guards += WEAKREF(guard)
	add_log("[guard.real_name] stepped back from the riot.")

/// Paid-off guards whose time is up go back to work
/datum/outpost_prison/proc/boss_bribes_tick()
	for(var/datum/weakref/ref as anything in boss_bribed_guards.Copy())
		var/mob/living/basic/outpost_prison_guard/guard = ref.resolve()
		if(QDELETED(guard))
			boss_bribed_guards -= ref
			continue
		if(guard.boss_bribed())
			continue
		boss_bribed_guards -= ref
		if(istype(guard.activity, /datum/outpost_guard_activity/prison_bribed))
			guard.end_activity()
		if(guard.on_duty())
			guard.visible_message(span_notice("[guard] squares [guard.p_their()] shoulders and gets back to work."))

/// Whether the kingpin has them standing back from the riot (on_duty())
/mob/living/basic/outpost_prison_guard/proc/boss_bribed()
	return prison_bribed_until > world.time

/**
 * A paid-off guard standing back in the office's far corner (guard_fallback_spot()), or where they
 * are if there is no room. Never picked as routine, never interrupted; over once they are back at work.
 */
/datum/outpost_guard_activity/prison_bribed
	name = "standing back"
	status = "routine"
	leisure = FALSE
	interruptible = FALSE
	min_duration = PRISON_BOSS_BRIBE_TIME
	max_duration = PRISON_BOSS_BRIBE_TIME

/datum/outpost_guard_activity/prison_bribed/setup()
	var/turf/spot = guard.prison?.guard_fallback_spot(guard) || guard.prison?.guard_office_spot(guard)
	if(spot && spot != guard.loc)
		set_goal(spot)
	return TRUE

/datum/outpost_guard_activity/prison_bribed/tick(seconds)
	return guard.boss_bribed() ? BOSS_GUARD_ACTIVITY_CONTINUE : BOSS_GUARD_ACTIVITY_DONE

#undef BOSS_GUARD_ACTIVITY_CONTINUE
#undef BOSS_GUARD_ACTIVITY_DONE
