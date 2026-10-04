/**
 * # Prison security: built turrets
 *
 * Players build their own turrets (tg's portable turret: a frame, an energy gun and a proximity
 * sensor). Whatever a turret's settings, the prison's mobs follow one rule with it,
 * outpost_prison_turret_verdict():
 * - A prisoner is shot only while making real trouble: rioting or breaking out, loose, swinging at
 *   staff, climbing a hatch, or fighting past the argument. Never while down, cuffed, shut in a
 *   cell or dead, while backing off from a warning, or after giving up. A turret behind the office
 *   glass covers the yard too: its shots at prisoners go through glass.
 * - Guards and Kessler's people are never shot.
 * - The experiments' creatures are shot as hull turrets shoot them, in the turret's own mode.
 * Anything that is not the prison's is up to the turret, as tg has it.
 *
 * A shot at a prisoner is always a stun shot: the turret's own if its gun has a stamina or
 * electrode setting that goes through glass, else a disabler beam, whatever the mode. Before the first shot at a prisoner
 * it has not warned lately, the turret warns them and holds fire for a moment, and the prisoner
 * decides what to do about it (react_to_turret()). Its shots pass through anyone the rule spares,
 * and a lethal shot passes through every prisoner. Rioters go for turrets they can reach before
 * any fixture (priority_smash_target()).
 *
 * On a player outpost a turret's controls, and a turret control panel's, answer only to the
 * outpost's members, as a hull turret's do there (ship_defense_turret.dm).
 *
 * Hull defense turrets and trader outpost turrets keep their own rules (uses_outpost_turret_rules()).
 * Numbers in voidcrew/_DEFINES/outpost_prison_security.dm.
 */

/// portable_turret.dm #undefs its own TURRET_STUN, so the value is restated here
#define PRISON_TURRET_STUN 0

// ===== THE RULE =====

/**
 * What a turret following the prison's rules does about `target`: OUTPOST_PRISON_TURRET_SHOOT,
 * OUTPOST_PRISON_TURRET_SPARE, or OUTPOST_PRISON_TURRET_NOT_MINE for anything that is not the
 * prison's. `turret` is the turret asking, if any.
 */
/proc/outpost_prison_turret_verdict(mob/living/target, obj/machinery/porta_turret/turret)
	if(!isliving(target))
		return OUTPOST_PRISON_TURRET_NOT_MINE
	if(is_outpost_prisoner(target))
		var/mob/living/basic/outpost_prisoner/prisoner = target
		return prisoner.turret_verdict(turret)
	if(is_outpost_prison_guard(target) || istype(target, /mob/living/basic/outpost_kessler_staff))
		return OUTPOST_PRISON_TURRET_SPARE
	// The experiments' creatures (outpost_prison_creatures.dm, outpost_prison_changeling.dm): until dead, subdued or in Kessler's hands
	if(is_outpost_prison_mob(target) || is_outpost_experiment_mob(target))
		return (target.stat != DEAD && is_hostile_creature(target)) ? OUTPOST_PRISON_TURRET_SHOOT : OUTPOST_PRISON_TURRET_SPARE
	return OUTPOST_PRISON_TURRET_NOT_MINE

/// Whether a projectile type is a stun shot: stamina damage, or tg's electrode
/proc/outpost_prison_stun_projectile(projectile_type)
	if(!ispath(projectile_type, /obj/projectile))
		return FALSE
	if(ispath(projectile_type, /obj/projectile/energy/electrode))
		return TRUE
	var/obj/projectile/shot = projectile_type
	return initial(shot.damage_type) == STAMINA && initial(shot.damage) > 0

/mob/living/basic/outpost_prisoner
	/// What they did about a turret's warning while rioting (OUTPOST_PRISON_TURRET_GIVE_UP, _BACK_OFF or _DEFY), the turret, and when that runs out
	var/turret_reaction
	var/datum/weakref/turret_reaction_ref
	var/turret_reaction_until = 0
	/// Where they are walking after a turret's warning, and the world.time they stop walking; until then no turret shoots them
	var/turf/turret_retreat_spot
	var/turret_retreat_until = 0

/// A turret's verdict on them; see outpost_prison_turret_verdict()
/mob/living/basic/outpost_prisoner/proc/turret_verdict(obj/machinery/porta_turret/turret)
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || can_be_dragged() || is_confined())
		return OUTPOST_PRISON_TURRET_SPARE
	if(surrendered_to_turret() || backing_off_from_turret() || !turret_trouble())
		return OUTPOST_PRISON_TURRET_SPARE
	return OUTPOST_PRISON_TURRET_SHOOT

/// The trouble a turret answers: rioting or breaking out, loose, swinging at staff, climbing a hatch, or fighting past the argument. Threats, arguments and wrecking a cell are not.
/mob/living/basic/outpost_prisoner/proc/turret_trouble()
	if(is_rioting() || trouble == PRISONER_TROUBLE_LOOSE || climb_ref || swing_ref?.resolve())
		return TRUE
	return trouble == PRISONER_TROUBLE_FIGHT && fight?.fighting

/// A rioter who gave up at a turret's warning: in the riot until staff bolt them in, but doing nothing
/mob/living/basic/outpost_prisoner/proc/surrendered_to_turret()
	return turret_reaction == OUTPOST_PRISON_TURRET_GIVE_UP && is_rioting()

/// Walking away after backing off from a turret's warning
/mob/living/basic/outpost_prisoner/proc/backing_off_from_turret()
	return world.time < turret_retreat_until

/// Forgets what a turret's warning made them do: a riot starting or ending clears it
/mob/living/basic/outpost_prisoner/proc/clear_turret_reaction()
	turret_reaction = null
	turret_reaction_ref = null
	turret_reaction_until = 0
	turret_retreat_spot = null
	turret_retreat_until = 0

// ===== THE TURRET =====

/obj/machinery/porta_turret
	/// REF() of prisoners it warned -> world.time of the warning (outpost_prison_security.dm)
	var/list/prison_warned_at

/**
 * Whether the prison's rules and the outpost's control lock hold for this turret: for every
 * turret players can build or bring. Hull defense turrets and trader outpost turrets have their own.
 */
/obj/machinery/porta_turret/proc/uses_outpost_turret_rules()
	return TRUE

/obj/machinery/porta_turret/ship_defense/uses_outpost_turret_rules()
	return FALSE

/obj/machinery/porta_turret/outpost/uses_outpost_turret_rules()
	return FALSE

/// The stock scan found `targets`; the prison's mobs the rule spares are dropped before one is picked
/obj/machinery/porta_turret/tryToShootAt(list/atom/movable/targets)
	if(!uses_outpost_turret_rules())
		return ..()
	for(var/mob/living/target in targets.Copy())
		if(outpost_prison_turret_verdict(target, src) == OUTPOST_PRISON_TURRET_SPARE)
			targets -= target
	if(length(targets))
		return ..()
	// Nothing left to shoot: down, as when the stock scan finds nothing
	if(!always_up)
		popDown()
	return FALSE

/**
 * At a prisoner: only while the rule says so, once its warning is done with, never in a riot's
 * wind-up, and only ever a stun shot, whatever the mode and the gun. Anything else as tg has it.
 */
/obj/machinery/porta_turret/shootAt(atom/movable/target)
	if(!uses_outpost_turret_rules() || !is_outpost_prisoner(target))
		return ..()
	if(!prison_may_fire_at(target))
		return null
	var/old_mode = mode
	var/old_projectile = stun_projectile
	var/old_sound = stun_projectile_sound
	mode = PRISON_TURRET_STUN
	// A turret behind the office glass covers the yard, so the shot has to go through glass
	var/obj/projectile/own_stun = stun_projectile
	if(!outpost_prison_stun_projectile(own_stun) || !(initial(own_stun.pass_flags) & PASSGLASS))
		stun_projectile = /obj/projectile/beam/disabler
		stun_projectile_sound = 'sound/items/weapons/taser2.ogg'
	. = ..()
	mode = old_mode
	stun_projectile = old_projectile
	stun_projectile_sound = old_sound
	if(mode != PRISON_TURRET_STUN)
		update_appearance()

/// Whether it may fire at `prisoner` now. The first time in a while it warns them instead, and holds fire for OUTPOST_PRISON_TURRET_WARN_TIME.
/obj/machinery/porta_turret/proc/prison_may_fire_at(mob/living/basic/outpost_prisoner/prisoner)
	if(outpost_prison_turret_verdict(prisoner, src) != OUTPOST_PRISON_TURRET_SHOOT)
		return FALSE
	var/warned = LAZYACCESS(prison_warned_at, REF(prisoner))
	if(!warned || world.time - warned >= OUTPOST_PRISON_TURRET_REWARN_TIME)
		warn_prisoner(prisoner)
		return FALSE
	if(world.time - warned < OUTPOST_PRISON_TURRET_WARN_TIME)
		return FALSE
	// A riot's wind-up is warned, not fired on
	return !(prisoner.is_rioting() && prisoner.prison?.riot_windup_left > 0)

/// The warning: a red line on them, a triple beep and "Step away.", and they decide what to do about it. Returns what they did.
/obj/machinery/porta_turret/proc/warn_prisoner(mob/living/basic/outpost_prisoner/prisoner)
	for(var/key in prison_warned_at?.Copy())
		if(world.time - prison_warned_at[key] >= OUTPOST_PRISON_TURRET_REWARN_TIME)
			LAZYREMOVE(prison_warned_at, key)
	LAZYSET(prison_warned_at, REF(prisoner), world.time)
	setDir(get_dir(base, prisoner))
	Beam(prisoner, icon_state = "r_beam", time = OUTPOST_PRISON_TURRET_WARN_TIME)
	playsound(src, 'sound/machines/beep/triple_beep.ogg', 40, FALSE)
	say("Step away.")
	return prisoner.react_to_turret(src)

/// A turret following the prison's rules lands no shot on anyone the rule spares, and no lethal one on a prisoner
/obj/projectile/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	if(isliving(target) && istype(firer, /obj/machinery/porta_turret) && !outpost_prison_turret_shot_lands(src, target))
		return FALSE
	return ..()

/// Whether `shot`, fired by a turret, may land on `target`
/proc/outpost_prison_turret_shot_lands(obj/projectile/shot, mob/living/target)
	var/obj/machinery/porta_turret/turret = shot.firer
	if(!turret.uses_outpost_turret_rules())
		return TRUE
	switch(outpost_prison_turret_verdict(target, turret))
		if(OUTPOST_PRISON_TURRET_NOT_MINE)
			return TRUE
		if(OUTPOST_PRISON_TURRET_SPARE)
			return FALSE
	return !is_outpost_prisoner(target) || outpost_prison_stun_projectile(shot.type)

// ===== THE WARNING, FROM THE PRISONER'S SIDE =====

/// Percent chance someone swinging at staff or fighting backs off at a turret's warning: likelier the better their mood, never certain either way
/proc/outpost_prisoner_turret_backoff_chance(mood)
	var/share = clamp(mood, 0, 100) / 100
	var/chance = OUTPOST_PRISON_TURRET_BACKOFF_AT_0 + (OUTPOST_PRISON_TURRET_BACKOFF_AT_100 - OUTPOST_PRISON_TURRET_BACKOFF_AT_0) * share
	return clamp(round(chance), OUTPOST_PRISON_TURRET_CHANCE_MIN, OUTPOST_PRISON_TURRET_CHANCE_MAX)

/**
 * A warned rioter's odds, as weights: list(give up, back off, defy). A better mood leans to giving
 * up and a worse one to defying; nervous and cheerful rioters give up more, grumpy ones defy more.
 * No outcome ever drops below OUTPOST_PRISON_TURRET_RIOT_MIN_WEIGHT.
 */
/proc/outpost_prisoner_turret_riot_weights(mood, personality)
	var/shift = clamp(mood, 0, 100) - OUTPOST_PRISON_TURRET_RIOT_MID_MOOD
	var/give_up = OUTPOST_PRISON_TURRET_RIOT_GIVE_UP + shift * OUTPOST_PRISON_TURRET_RIOT_GIVE_UP_PER_MOOD
	var/back_off = OUTPOST_PRISON_TURRET_RIOT_BACK_OFF
	var/defy = OUTPOST_PRISON_TURRET_RIOT_DEFY - shift * OUTPOST_PRISON_TURRET_RIOT_DEFY_PER_MOOD
	if(personality == "nervous" || personality == "cheerful")
		give_up *= OUTPOST_PRISON_TURRET_RIOT_PERSONALITY_MULT
	else if(personality == "grumpy")
		defy *= OUTPOST_PRISON_TURRET_RIOT_PERSONALITY_MULT
	return list(
		OUTPOST_PRISON_TURRET_GIVE_UP = max(round(give_up), OUTPOST_PRISON_TURRET_RIOT_MIN_WEIGHT),
		OUTPOST_PRISON_TURRET_BACK_OFF = max(round(back_off), OUTPOST_PRISON_TURRET_RIOT_MIN_WEIGHT),
		OUTPOST_PRISON_TURRET_DEFY = max(round(defy), OUTPOST_PRISON_TURRET_RIOT_MIN_WEIGHT),
	)

/**
 * A turret warned them. What they do is a roll that mood tilts but never settles:
 * - swinging at staff or fighting: back off (drop it, step away, no squaring up for the threat
 *   cooldown), or carry on and take the stun;
 * - climbing a hatch: climb back down, or keep climbing;
 * - rioting: give up (the shiv goes down and they walk back to their cell for staff to bolt), back
 *   off (riot on out of the turret's sight), or defy it (go for the turret).
 * Loose prisoners run on the outpost patrol AI and take no notice. Returns what they did, or null.
 */
/mob/living/basic/outpost_prisoner/proc/react_to_turret(obj/machinery/porta_turret/turret)
	if(QDELETED(turret) || stat != CONSCIOUS || phase != PRISONER_PRESENT || can_be_dragged())
		return null
	var/reaction
	if(is_rioting())
		reaction = prison?.forced_turret_reaction || pick_weight(outpost_prisoner_turret_riot_weights(mood, personality))
		switch(reaction)
			if(OUTPOST_PRISON_TURRET_GIVE_UP)
				turret_give_up(turret)
			if(OUTPOST_PRISON_TURRET_BACK_OFF)
				turret_back_off_riot(turret)
			else
				reaction = OUTPOST_PRISON_TURRET_DEFY
				turret_defy(turret)
	else if(climb_ref)
		reaction = turret_roll(OUTPOST_PRISON_TURRET_CLIMB_DOWN_CHANCE)
		if(reaction == OUTPOST_PRISON_TURRET_BACK_OFF)
			stop_climb(fell = TRUE)
	else if(swing_ref?.resolve() || (trouble == PRISONER_TROUBLE_FIGHT && fight?.fighting))
		reaction = turret_roll(outpost_prisoner_turret_backoff_chance(mood))
		if(reaction == OUTPOST_PRISON_TURRET_BACK_OFF)
			turret_stand_down(turret)
	else
		return null
	face_atom(turret)
	var/line = "turret_backs_off"
	if(reaction == OUTPOST_PRISON_TURRET_DEFY)
		line = "turret_defies"
	else if(reaction == OUTPOST_PRISON_TURRET_GIVE_UP)
		line = "turret_gives_up"
	INVOKE_ASYNC(src, PROC_REF(say_context), line)
	return reaction

/// Backing off with `chance` percent, else defying. The prison's forced_turret_reaction settles it instead, for tests.
/mob/living/basic/outpost_prisoner/proc/turret_roll(chance)
	var/forced = prison?.forced_turret_reaction
	if(forced)
		return forced == OUTPOST_PRISON_TURRET_DEFY ? OUTPOST_PRISON_TURRET_DEFY : OUTPOST_PRISON_TURRET_BACK_OFF
	return prob(chance) ? OUTPOST_PRISON_TURRET_BACK_OFF : OUTPOST_PRISON_TURRET_DEFY

/mob/living/basic/outpost_prisoner/proc/set_turret_reaction(reaction, obj/machinery/porta_turret/turret, duration)
	turret_reaction = reaction
	turret_reaction_ref = WEAKREF(turret)
	turret_reaction_until = world.time + duration

/// Heads for `spot`, if there is one; no turret shoots them for `duration` meanwhile
/mob/living/basic/outpost_prisoner/proc/start_turret_retreat(turf/spot, duration)
	turret_retreat_spot = spot
	turret_retreat_until = world.time + duration

/// Swinging or fighting, and backing off: they drop it, step away from the turret and whoever they were going for, and don't square up again for the threat cooldown
/mob/living/basic/outpost_prisoner/proc/turret_stand_down(obj/machinery/porta_turret/turret)
	var/mob/living/other = swing_ref?.resolve() || fight?.opponent_of(src)
	cancel_threat()
	threat_cooldown = max(threat_cooldown, PRISONER_THREAT_COOLDOWN)
	if(fight)
		prison?.end_fight(fight)
	stop_blows()
	ai_controller?.CancelActions()
	start_turret_retreat(pick_turret_retreat(turret, FALSE, other), OUTPOST_PRISON_TURRET_RETREAT_TIME)

/// A rioter who gives up: the shiv goes down and they walk back to their own cell. Bolted in, they are out of the riot, owing lockdown (outpost_prison_capture.dm).
/mob/living/basic/outpost_prisoner/proc/turret_give_up(obj/machinery/porta_turret/turret)
	set_turret_reaction(OUTPOST_PRISON_TURRET_GIVE_UP, turret, 0)
	cancel_threat()
	drop_shiv()
	riot_target_ref = null
	riot_target_hits = 0
	riot_victim_ref = null
	ai_controller?.CancelActions()
	start_turret_retreat(own_cell_spot(), OUTPOST_PRISON_TURRET_SURRENDER_WALK_TIME)
	update_bubble()
	prison?.add_log("[real_name] gave up rioting at a turret's warning.")

/// A rioter who backs off: still rioting, but out of the turret's sight, and leaving alone what it can see for a while
/mob/living/basic/outpost_prisoner/proc/turret_back_off_riot(obj/machinery/porta_turret/turret)
	set_turret_reaction(OUTPOST_PRISON_TURRET_BACK_OFF, turret, OUTPOST_PRISON_TURRET_AVOID_TIME)
	// The turret too: under its cover it does not show up in its own view
	LAZYSET(riot_skips, REF(turret), turret_reaction_until)
	for(var/obj/thing in view(turret.scan_range, turret))
		if(reachable?[get_turf(thing)])
			LAZYSET(riot_skips, REF(thing), turret_reaction_until)
	riot_target_ref = null
	riot_target_hits = 0
	riot_victim_ref = null
	ai_controller?.CancelActions()
	start_turret_retreat(pick_turret_retreat(turret, TRUE), OUTPOST_PRISON_TURRET_RETREAT_TIME)

/// A rioter who defies it: they go for the turret before anything else (riot_target()), and get shot on the way
/mob/living/basic/outpost_prisoner/proc/turret_defy(obj/machinery/porta_turret/turret)
	set_turret_reaction(OUTPOST_PRISON_TURRET_DEFY, turret, OUTPOST_PRISON_TURRET_DEFY_TIME)
	LAZYREMOVE(riot_skips, REF(turret))
	ai_controller?.CancelActions()

/// The turret a rioter defied, while they still mean to smash it and can get at it
/mob/living/basic/outpost_prisoner/proc/defied_turret()
	if(turret_reaction != OUTPOST_PRISON_TURRET_DEFY || world.time >= turret_reaction_until || !is_rioting())
		return null
	var/obj/machinery/porta_turret/turret = turret_reaction_ref?.resolve()
	if(!turret || !prison?.still_smashable(turret, src))
		return null
	return turret

/// Where a rioter who gave up waits: their cell's chair or bed (home_seat()), or any free tile of their own cell they can walk to
/mob/living/basic/outpost_prisoner/proc/own_cell_spot()
	if(!cell)
		return null
	var/obj/structure/seat = home_seat()
	if(seat)
		return get_turf(seat)
	for(var/turf/tile as anything in cell.turfs)
		if(walkable?[tile] && (tile == loc || !tile_taken(tile)))
			return tile
	return null

/**
 * Where they back off to from `turret`. A rioter (`out_of_sight`) goes to the nearest tile they
 * can walk to that it cannot see, or failing that the one farthest from it; anyone else a tile or
 * two away, as far as they can get from it and from `other`. Null if nowhere will do.
 */
/mob/living/basic/outpost_prisoner/proc/pick_turret_retreat(obj/machinery/porta_turret/turret, out_of_sight = FALSE, mob/living/other)
	if(!length(walkable))
		return null
	var/turf/here = get_turf(src)
	var/list/seen
	if(out_of_sight)
		seen = list()
		for(var/turf/tile in view(turret.scan_range, turret))
			seen[tile] = TRUE
	var/turf/best
	var/best_score = -INFINITY
	for(var/turf/tile as anything in walkable)
		if(tile == here || tile_taken(tile) || !may_loiter(tile))
			continue
		var/score
		if(out_of_sight)
			// Anywhere out of its sight beats anywhere in it: the nearer the better out of it, the farther from it in it
			score = seen[tile] ? get_dist(tile, turret) - 1000 : -get_dist(here, tile)
		else
			if(get_dist(here, tile) > OUTPOST_PRISON_TURRET_STEP_BACK)
				continue
			score = get_dist(tile, turret) + (other ? get_dist(tile, other) : 0)
		if(score > best_score)
			best = tile
			best_score = score
	return best

/**
 * Plans the walk after a turret's warning, from the trouble subtree: TRUE while they are on the
 * way. At the spot, or out of time, they stop; one who gave up and got to their cell's chair or
 * bed sits down (sit_in_cell()).
 */
/mob/living/basic/outpost_prisoner/proc/plan_turret_retreat(datum/ai_controller/controller)
	if(!turret_retreat_spot)
		return FALSE
	if(loc == turret_retreat_spot || world.time >= turret_retreat_until)
		finish_turret_retreat()
		return FALSE
	if(stat != CONSCIOUS || phase != PRISONER_PRESENT || can_be_dragged() || pulledby || climb_ref)
		return FALSE
	controller.queue_behavior(/datum/ai_behavior/outpost_prisoner_turret_retreat)
	return TRUE

/mob/living/basic/outpost_prisoner/proc/finish_turret_retreat()
	var/turf/spot = turret_retreat_spot
	turret_retreat_spot = null
	if(!surrendered_to_turret() || loc != spot || !cell?.contains(src) || !((locate(/obj/structure/chair) in loc) || (locate(/obj/structure/bed) in loc)))
		return
	var/obj/machinery/door/door = cell.door()
	sit_in_cell(door ? get_cardinal_dir(src, door) : SOUTH)

/// Walks to where they are backing off to
/datum/ai_behavior/outpost_prisoner_turret_retreat
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT
	required_distance = 0
	action_cooldown = 0.5 SECONDS

/datum/ai_behavior/outpost_prisoner_turret_retreat/setup(datum/ai_controller/controller)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	var/turf/spot = prisoner?.turret_retreat_spot
	if(!spot)
		return FALSE
	prisoner.stand_up()
	set_movement_target(controller, spot)
	return TRUE

/datum/ai_behavior/outpost_prisoner_turret_retreat/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	if(!prisoner?.turret_retreat_spot || prisoner.loc != prisoner.turret_retreat_spot)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	prisoner.finish_turret_retreat()
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

// ===== THE PRISON'S SIDE =====

/datum/outpost_prison
	/// Between onlookers remarking on a turret hit, and between rioters shouting to go for one
	COOLDOWN_DECLARE(turret_hit_line_cooldown)
	COOLDOWN_DECLARE(turret_smash_line_cooldown)
	/// For tests: what a warned prisoner does (OUTPOST_PRISON_TURRET_GIVE_UP, _BACK_OFF or _DEFY) instead of rolling for it
	var/forced_turret_reaction

/**
 * What a rioter goes for before any fixture: the nearest unbroken turret following the prison's
 * rules that they can reach and have not given up on, or null. A rioter newly going for one may
 * shout about it.
 */
/datum/outpost_prison/proc/priority_smash_target(mob/living/basic/outpost_prisoner/rioter)
	if(!rioter?.reachable)
		return null
	var/obj/machinery/porta_turret/nearest
	var/nearest_distance = INFINITY
	for(var/turf/tile as anything in rioter.reachable)
		var/obj/machinery/porta_turret/turret = locate() in tile
		if(!turret || !turret.uses_outpost_turret_rules() || (turret.machine_stat & BROKEN) || LAZYACCESS(rioter.riot_skips, REF(turret)) > world.time)
			continue
		var/distance = get_dist(rioter, turret)
		if(distance < nearest_distance)
			nearest = turret
			nearest_distance = distance
	if(nearest && rioter.riot_target_ref?.resolve() != nearest && COOLDOWN_FINISHED(src, turret_smash_line_cooldown))
		COOLDOWN_START(src, turret_smash_line_cooldown, OUTPOST_PRISON_TURRET_SMASH_LINE_GAP)
		INVOKE_ASYNC(rioter, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "turret_smash")
	return nearest

/// A turret's shot is about to land on `target`: now and then someone watching says something
/datum/outpost_prison/proc/note_turret_hit(mob/living/basic/outpost_prisoner/target)
	if(!COOLDOWN_FINISHED(src, turret_hit_line_cooldown) || !prob(OUTPOST_PRISON_TURRET_HIT_LINE_CHANCE))
		return FALSE
	for(var/mob/living/basic/outpost_prisoner/onlooker in shuffle(prisoners))
		if(onlooker == target || onlooker.stat != CONSCIOUS || onlooker.phase != PRISONER_PRESENT || !onlooker.ai_running() || onlooker.in_trouble())
			continue
		if(get_dist(onlooker, target) > 7 || !(target in view(7, onlooker)))
			continue
		COOLDOWN_START(src, turret_hit_line_cooldown, OUTPOST_PRISON_TURRET_HIT_LINE_GAP)
		onlooker.face_atom(target)
		INVOKE_ASYNC(onlooker, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "turret_hit")
		return TRUE
	return FALSE

// ===== CONTROLS =====

/**
 * Whether `user` may work `machine`'s controls: on a player outpost only its members (the owner,
 * stewards, treasurers, residents and builders), as for a hull turret bolted there; anywhere
 * else, or on a claim nobody holds, whoever tg lets.
 */
/proc/outpost_turret_controls_allowed(atom/machine, mob/user)
	if(!ismob(user) || isAdminGhostAI(user))
		return TRUE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(machine)
	if(isnull(home) || !home.founder_ckey)
		return TRUE
	return home.can_manage(user) || home.can_spend(user) || home.is_resident(user) || home.can_build(user)

/obj/machinery/porta_turret/proc/outpost_controls_allowed(mob/user)
	return !uses_outpost_turret_rules() || outpost_turret_controls_allowed(src, user)

/// Whether using `tool` on it works its controls: an ID swipe, a wrench while it is off, or a crowbar on its wreck
/obj/machinery/porta_turret/proc/is_control_tool(obj/item/tool)
	if(machine_stat & BROKEN)
		return tool.tool_behaviour == TOOL_CROWBAR
	if(tool.tool_behaviour == TOOL_WRENCH && !on)
		return TRUE
	return !isnull(tool.GetID())

/obj/machinery/porta_turret/ui_interact(mob/user, datum/tgui/ui)
	if(!ui && !isobserver(user) && !outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

/obj/machinery/porta_turret/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(!outpost_controls_allowed(ui.user))
		balloon_alert(ui.user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/porta_turret/attackby(obj/item/I, mob/user, list/modifiers, list/attack_modifiers)
	if(is_control_tool(I) && !outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/porta_turret/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/porta_turret_cover/attackby(obj/item/I, mob/user, list/modifiers, list/attack_modifiers)
	if(parent_turret && ((I.tool_behaviour == TOOL_WRENCH && !parent_turret.on) || I.GetID()) && !parent_turret.outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/porta_turret_cover/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	if(parent_turret && !parent_turret.outpost_controls_allowed(user))
		balloon_alert(user, "controls locked!")
		return ITEM_INTERACT_BLOCKING
	return ..()

// A turret control panel sets every turret linked to it, so it answers to the same people.

/obj/machinery/turretid/ui_interact(mob/user, datum/tgui/ui)
	if(!ui && !isobserver(user) && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

/obj/machinery/turretid/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(!outpost_turret_controls_allowed(src, ui.user))
		balloon_alert(ui.user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/turretid/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.GetID() && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return TRUE
	return ..()

/obj/machinery/turretid/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	if(!outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return ITEM_INTERACT_BLOCKING
	return ..()

// The switches, reached from the panel and from AI and cyborg clicks
/obj/machinery/turretid/toggle_on(mob/user)
	if(user && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

/obj/machinery/turretid/toggle_lethal(mob/user)
	if(user && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

/obj/machinery/turretid/shoot_silicons(mob/user)
	if(user && !outpost_turret_controls_allowed(src, user))
		balloon_alert(user, "controls locked!")
		return
	return ..()

#undef PRISON_TURRET_STUN
