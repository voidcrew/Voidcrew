/**
 * Serverblight's hunt: the one thing in the game that doesn't move tile to tile.
 *
 * The blighted body is a puck in a top-down Box2D world of its own (no gravity, a metre to a tile),
 * walled in by the dense tiles and furniture around it. It's pushed after whoever's nearest, so it
 * speeds up, overshoots, slides along walls and lurches sideways, the way things move in SS14
 * rather than the way mobs walk here. The mob follows the puck: onto whichever tile it's over, and
 * pixel-shifted the rest of the way, so it's drawn exactly where it is between tiles.
 *
 * Close enough, the ragdoll's hands go for its prey (see /datum/limb_physics/proc/set_prey()).
 * Each hand that has hold of them slows them down more, until they tear loose or get away, and
 * every hand on them every tick brings them closer to being taken: they leave their body, and
 * their body is folded into the mass, bringing more hands.
 *
 * With no gravity it can't walk: it throws itself off whatever it can reach (walls, furniture,
 * lattice, people) and drifts in between, so open space is somewhere to get away to.
 *
 * Every head in it screams, all the time, each in its own voice, distorted.
 *
 * It can be killed like anyone, but everyone it's taken in is more of it to get through:
 * SERVERBLIGHT_HEALTH_PER_BODY more health each, and more of it to hit: a shot through a tile its
 * mass sprawls over hits it (see update_hitboxes()). Damage doesn't slow it (nothing does: it isn't walking), but a hit
 * jerks the body, and a gun that kicks, or a shot that would knock someone down, shoves it back.
 * Dead, it falls in a heap for SERVERBLIGHT_DEATH_TIME, then gets back up, whole. Something it
 * can't get back up from (no head, say) ends it.
 */
/datum/serverblight_chase
	/// The ragdoll this is moving about.
	var/datum/limb_physics/physics
	/// The blighted mob.
	var/mob/living/carbon/host
	/// The top-down world, as the library's handle.
	var/world_handle
	/// The puck the mob follows.
	var/body
	/// The walls' handles, rebuilt as it goes.
	var/list/wall_bodies = list()
	/// Where the walls were last built around.
	var/turf/walls_centre
	/// The tile the mob was last put on, to notice anyone else moving it.
	var/turf/last_turf
	/// Who it's after, if anyone.
	var/mob/living/carbon/prey
	/// The way to them, when they aren't in a straight line: turfs, next one first.
	var/list/path
	/// Fires so far.
	var/fires = 0
	/// How near the prey is to being taken: a point for every hand on them, every fire.
	var/grip = 0
	/// Everyone it has taken, held inside the mob.
	var/list/absorbed = list()
	/// Whoever its hands are slowing down, if anyone.
	var/mob/living/carbon/held
	/// When each voice screams next, by its place in get_voices(), as text.
	var/list/next_screams = list()
	/// Invisible stand-ins on the tiles round it that its mass sprawls over, taking shots for it.
	var/list/obj/effect/serverblight_hitbox/hitboxes = list()
	/// How much health everyone it's taken in has added to it.
	var/bonus_health = 0
	/// The fire it can next throw itself off something, with no gravity.
	var/next_pushoff = 0
	/// The timer getting it back up, while it's dead.
	var/rise_timer
	/// Whether the mob could already pass through other mobs before this.
	var/had_passmob

/datum/serverblight_chase/New(datum/limb_physics/physics)
	src.physics = physics
	host = physics.rig.owner
	physics.chase = src
	var/turf/here = get_turf(host)
	world_handle = vcphys_call("world_create", 0, 0)
	body = world_handle && vcphys_call("body_create", world_handle, LIMB_PHYSICS_DYNAMIC, here.x + 0.5, here.y + 0.5, 0, 0, 0, 0, 1)
	// A kilogram, so an impulse is the change in speed.
	if(!body || !vcphys_call("fixture_circle", world_handle, body, 0.3, 0, 0, 1 / (PI * 0.3 ** 2), 0, 0, 0))
		qdel(src)
		return
	last_turf = here
	had_passmob = host.pass_flags & PASSMOB
	// Over people rather than stopped by them: it has to get its hands round them.
	host.pass_flags |= PASSMOB
	// Sliding every which way without turning round (turning would start the ragdoll over).
	host.set_dir_on_move = FALSE
	// Falling over is physics' job: the mob itself stays upright.
	host.rotate_on_lying = FALSE
	host.update_transform()
	RegisterSignal(host, COMSIG_ATOM_BULLET_ACT, PROC_REF(on_shot))
	// Drifting is the puck's job too: no space drift on the mob.
	RegisterSignal(host, COMSIG_MOVABLE_SPACEMOVE, PROC_REF(on_spacemove))
	QDEL_NULL(host.drift_handler)
	build_walls()
	START_PROCESSING(SSlimb_physics, src)

/datum/serverblight_chase/Destroy()
	STOP_PROCESSING(SSlimb_physics, src)
	deltimer(rise_timer)
	QDEL_LIST(hitboxes)
	hold(null, 0)
	if(world_handle)
		vcphys_call("world_destroy", world_handle)
	world_handle = null
	var/turf/drop = get_turf(host)
	for(var/mob/living/carbon/taken as anything in absorbed)
		if(!QDELETED(taken) && taken.loc == host)
			let_go(taken, drop)
	absorbed.Cut()
	if(!QDELETED(host))
		host.maxHealth -= bonus_health
		host.updatehealth()
		host.remove_offsets(SERVERBLIGHT_TRAIT, animate = FALSE)
		host.set_dir_on_move = TRUE
		host.rotate_on_lying = TRUE
		host.update_transform()
		UnregisterSignal(host, list(COMSIG_ATOM_BULLET_ACT, COMSIG_MOVABLE_SPACEMOVE))
		if(!had_passmob)
			host.pass_flags &= ~PASSMOB
	if(physics?.chase == src)
		physics.chase = null
		physics.set_prey(null, null)
	physics = null
	host = null
	prey = null
	path = null
	return ..()

/datum/serverblight_chase/process(seconds_per_tick)
	if(QDELETED(host) || QDELETED(physics))
		qdel(src)
		return PROCESS_KILL
	if(host.stat == DEAD)
		if(!physics.dormant)
			die()
		return
	// Back up early (someone revived it).
	if(physics.dormant)
		rise()
		return
	scream()
	// Shut in something, or buckled: wait it out.
	if(!isturf(host.loc) || host.buckled)
		return
	fires++
	var/turf/here = host.loc
	// Moved by something else (pulled, thrown, teleported): pick up from there.
	if(here != last_turf)
		vcphys_call("body_set_transform", world_handle, body, here.x + 0.5, here.y + 0.5, 0)
		vcphys_call("body_set_velocity", world_handle, body, 0, 0, 0)
		last_turf = here
		host.remove_offsets(SERVERBLIGHT_TRAIT, animate = FALSE)
		build_walls()
		physics.add_surroundings()
	else if(fires % 10 == 0 || get_dist(here, walls_centre) > 2)
		build_walls()
	if(fires % 5 == 0 || !is_prey(prey))
		find_prey()
	var/list/state = read_puck()
	if(!state)
		qdel(src)
		return PROCESS_KILL
	steer(state)
	if(!vcphys_call("world_step", world_handle, LIMB_PHYSICS_DT, LIMB_PHYSICS_VELOCITY_ITERATIONS, LIMB_PHYSICS_POSITION_ITERATIONS, LIMB_PHYSICS_STEPS_PER_FIRE))
		qdel(src)
		return PROCESS_KILL
	state = read_puck()
	if(!state)
		qdel(src)
		return PROCESS_KILL
	place(state[1], state[2])
	// Nothing to walk on, the legs just seize.
	physics.walk_speed = host.has_gravity() ? sqrt(state[4] ** 2 + state[5] ** 2) : 0
	update_hitboxes()
	reach()

/// The puck: list(x, y, angle, vx, vy, spin), in tiles. Null if it can't be read.
/datum/serverblight_chase/proc/read_puck()
	var/reply = vcphys_call("body_read", world_handle, body)
	var/list/fields = reply && splittext(reply, " ")
	if(length(fields) != 7)
		return null
	. = list()
	for(var/i in 2 to 7)
		var/value = text2num(fields[i])
		if(!isnum(value) || value != value)
			return null
		. += value

/// Walls round the mob, a tile's radius past what it can see: anything it couldn't walk into.
/datum/serverblight_chase/proc/build_walls()
	for(var/wall in wall_bodies)
		vcphys_call("body_destroy", world_handle, wall)
	wall_bodies.Cut()
	walls_centre = get_turf(host)
	if(!walls_centre)
		return
	var/range = SERVERBLIGHT_SIGHT + 1
	for(var/turf/spot as anything in RANGE_TURFS(range, walls_centre))
		if(spot == walls_centre || !spot.is_blocked_turf(TRUE, host))
			continue
		var/wall = vcphys_call("body_create", world_handle, LIMB_PHYSICS_STATIC, spot.x + 0.5, spot.y + 0.5, 0, 0, 0)
		if(wall && vcphys_call("fixture_box", world_handle, wall, 0.5, 0.5, 0, 0, 0, 0, 0, 0, 0))
			wall_bodies += wall
	// The map's edge.
	for(var/list/edge in list(list(0.5, world.maxy / 2, 0.5, world.maxy), list(world.maxx + 0.5, world.maxy / 2, 0.5, world.maxy), list(world.maxx / 2, 0.5, world.maxx, 0.5), list(world.maxx / 2, world.maxy + 0.5, world.maxx, 0.5)))
		var/wall = vcphys_call("body_create", world_handle, LIMB_PHYSICS_STATIC, edge[1], edge[2], 0, 0, 0)
		if(wall && vcphys_call("fixture_box", world_handle, wall, edge[3], edge[4], 0, 0, 0, 0, 0, 0, 0))
			wall_bodies += wall

/// Whether someone is worth hunting.
/datum/serverblight_chase/proc/is_prey(mob/living/carbon/who)
	return istype(who) && !QDELETED(who) && who != host && who.stat != DEAD && isturf(who.loc) && who.z == host.z && !(who in absorbed) && !who.limb_rig?.physics?.blighted && get_dist(who, host) <= SERVERBLIGHT_SIGHT

/// The nearest person it can see, players first.
/datum/serverblight_chase/proc/find_prey()
	var/mob/living/carbon/best
	var/best_score = INFINITY
	for(var/mob/living/carbon/who in view(SERVERBLIGHT_SIGHT, host))
		if(!is_prey(who))
			continue
		var/score = get_dist(who, host) + (who.client ? 0 : 100)
		if(score < best_score)
			best = who
			best_score = score
	if(best != prey)
		path = null
	prey = best

/**
 * Pushes the puck toward its prey: straight at them if nothing's in the way, else along a path
 * round. Not smoothly: it lurches sideways and stops dead now and then, and never quite goes
 * where it means to.
 */
/datum/serverblight_chase/proc/steer(list/state)
	var/goal_x
	var/goal_y
	if(prey)
		var/turf/prey_turf = get_turf(prey)
		if(get_dist(host, prey) <= 1 || !length(get_line_blockers(prey_turf)))
			path = null
			goal_x = prey_turf.x + 0.5
			goal_y = prey_turf.y + 0.5
		else
			if(!length(path) || fires % 10 == 0)
				path = get_path_to(host, prey_turf, SERVERBLIGHT_SIGHT * 3, simulated_only = FALSE)
			while(length(path))
				var/turf/next = path[1]
				if(abs(next.x + 0.5 - state[1]) >= 0.35 || abs(next.y + 0.5 - state[2]) >= 0.35)
					goal_x = next.x + 0.5
					goal_y = next.y + 0.5
					break
				path.Cut(1, 2)
	var/want_x = 0
	var/want_y = 0
	if(!isnull(goal_x) && !prob(6))
		var/dx = goal_x - state[1]
		var/dy = goal_y - state[2]
		var/distance = sqrt(dx ** 2 + dy ** 2)
		if(distance > 0.05)
			var/speed = min(SERVERBLIGHT_SPEED, distance * 6)
			want_x = dx / distance * speed
			want_y = dy / distance * speed
	if(!host.has_gravity())
		// Nothing to walk on: it throws itself off whatever it can reach, now and then, straight
		// at where it wants to be, and drifts until it next can.
		if(fires < next_pushoff || !can_push_off())
			return
		next_pushoff = fires + SERVERBLIGHT_PUSHOFF_FIRES
		vcphys_call("body_impulse", world_handle, body, want_x - state[4], want_y - state[5])
		return
	// Most of the way to the speed it wants each tick, no harder than about four gees.
	var/push_x = (want_x - state[4]) * 0.6
	var/push_y = (want_y - state[5]) * 0.6
	var/push = sqrt(push_x ** 2 + push_y ** 2)
	if(push > 4)
		push_x *= 4 / push
		push_y *= 4 / push
	if(prob(12))
		// A lurch across the way it's going.
		var/across = pick(-1, 1) * rand(20, 40) / 10
		var/speed = max(sqrt(state[4] ** 2 + state[5] ** 2), 0.1)
		push_x += -state[5] / speed * across
		push_y += state[4] / speed * across
	vcphys_call("body_impulse", world_handle, body, push_x, push_y)

/// Opaque or dense turfs between the mob and a turf.
/datum/serverblight_chase/proc/get_line_blockers(turf/target)
	. = list()
	for(var/turf/spot as anything in get_line(get_turf(host), target))
		if(spot.opacity || spot.is_blocked_turf(TRUE, host))
			. += spot

/// Puts the mob where the puck is: on the tile under it, shifted the rest of the way.
/datum/serverblight_chase/proc/place(x, y)
	var/turf/target = locate(floor(x), floor(y), host.z)
	var/old_w = host.pixel_w
	var/old_z = host.pixel_z
	if(target && target != last_turf)
		var/turf/from = last_turf
		host.Move(target, get_dir(from, target), world.icon_size)
		var/turf/now = get_turf(host)
		if(now != target)
			// Something the walls didn't have (someone's door shut, a wall went up): back onto the
			// tile it's on, stopped.
			x = clamp(x, now.x + 0.2, now.x + 0.8)
			y = clamp(y, now.y + 0.2, now.y + 0.8)
			vcphys_call("body_set_transform", world_handle, body, x, y, 0)
			vcphys_call("body_set_velocity", world_handle, body, 0, 0, 0)
			walls_centre = null
		old_w += (from.x - now.x) * world.icon_size
		old_z += (from.y - now.y) * world.icon_size
		last_turf = now
		physics.add_surroundings()
	// Offset the rest of the way, easing there over the tick from where it's drawn now.
	host.add_offsets(SERVERBLIGHT_TRAIT, round((x - last_turf.x - 0.5) * world.icon_size), null, null, round((y - last_turf.y - 0.5) * world.icon_size), animate = FALSE)
	var/new_w = host.pixel_w
	var/new_z = host.pixel_z
	host.pixel_w = old_w
	host.pixel_z = old_z
	animate(host, pixel_w = new_w, pixel_z = new_z, time = SSlimb_physics.wait)

/**
 * Tells the ragdoll's hands where the prey is, if it's in reach, and takes them if every hand's
 * been on them long enough. Any hand on them holds them.
 */
/datum/serverblight_chase/proc/reach()
	if(!prey)
		physics.set_prey(null, null)
		hold(null, 0)
		grip = 0
		return
	var/list/puck = read_puck()
	// Where they stand in the ragdoll's frame: a tile is SERVERBLIGHT_TILE_METRES across, and a
	// tile further north is drawn a tile higher.
	var/dx = (prey.x + 0.5 - puck[1]) * SERVERBLIGHT_TILE_METRES
	var/dy = (prey.y + 0.5 - puck[2]) * SERVERBLIGHT_TILE_METRES
	if(abs(dx) > 2 * SERVERBLIGHT_TILE_METRES || abs(dy) > 2 * SERVERBLIGHT_TILE_METRES)
		physics.set_prey(null, null)
		hold(null, 0)
		grip = 0
		return
	physics.set_prey(dx, dy)
	var/holding = physics.count_gripping_hands()
	hold(prey, holding)
	grip = holding ? grip + holding : max(grip - 2, 0)
	if(grip >= SERVERBLIGHT_ASSIMILATION)
		absorb(prey)

/// Takes someone: out of their body, which goes into the mass.
/datum/serverblight_chase/proc/absorb(mob/living/carbon/taken)
	grip = 0
	prey = null
	path = null
	physics.set_prey(null, null)
	hold(null, 0)
	playsound(host, 'sound/effects/wounds/crackandbleed.ogg', 100, TRUE)
	taken.visible_message(span_danger("[host] folds [taken] into itself."), span_userdanger("Every hand closes. You aren't in there any more."))
	log_admin("Serverblight ([key_name(host)]) took [key_name(taken)] at [AREACOORD(host)].")
	// Out of their body, and kept out of it for now, but still its owner: they're put back when it's let go.
	var/mob/dead/observer/ghost = taken.ghostize(can_reenter_corpse = TRUE)
	if(ghost)
		ghost.can_reenter_corpse = FALSE
	taken.set_limb_physics(FALSE)
	absorbed += taken
	bonus_health += SERVERBLIGHT_HEALTH_PER_BODY
	host.maxHealth += SERVERBLIGHT_HEALTH_PER_BODY
	host.updatehealth()
	ADD_TRAIT(taken, TRAIT_IMMOBILIZED, SERVERBLIGHT_TRAIT)
	ADD_TRAIT(taken, TRAIT_HANDS_BLOCKED, SERVERBLIGHT_TRAIT)
	// Drawn from how they look before they're out of sight.
	physics.merge(taken)
	taken.forceMove(host)
	// Held as they are in there, not suffocating in it.
	taken.apply_status_effect(/datum/status_effect/grouped/stasis, SERVERBLIGHT_TRAIT)

/**
 * Lets someone it took go, out onto drop: out of stasis, dead (nobody comes out of it alive), and
 * whoever played them back in their body, to be revived like anyone dead.
 */
/datum/serverblight_chase/proc/let_go(mob/living/carbon/taken, turf/drop)
	taken.forceMove(drop)
	REMOVE_TRAITS_IN(taken, SERVERBLIGHT_TRAIT)
	taken.remove_status_effect(/datum/status_effect/grouped/stasis, SERVERBLIGHT_TRAIT)
	if(taken.stat != DEAD)
		taken.death()
	var/mob/dead/observer/ghost = taken.get_ghost(even_if_they_cant_reenter = TRUE)
	if(ghost)
		ghost.can_reenter_corpse = TRUE
		ghost.reenter_corpse()
	taken.visible_message(span_danger("[taken] slides out of [host], limp."))

/// Slows someone down for every hand on them, letting go of whoever it was holding before.
/datum/serverblight_chase/proc/hold(mob/living/carbon/who, hands)
	if(held && (held != who || !hands))
		held.remove_movespeed_modifier(/datum/movespeed_modifier/serverblight_grip)
		held = null
	if(!who || !hands)
		return
	if(!held)
		to_chat(who, span_userdanger("Long fingers close around you."))
	held = who
	who.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/serverblight_grip, multiplicative_slowdown = clamp(hands * SERVERBLIGHT_GRIP_SLOWDOWN, 0, SERVERBLIGHT_GRIP_MAX_SLOWDOWN))

/// Serverblight's hands on someone: slower for each one.
/datum/movespeed_modifier/serverblight_grip
	variable = TRUE

/// Everyone screaming in it: its own head twice (it has more than one), then everyone it's taken.
/datum/serverblight_chase/proc/get_voices()
	return list(host, host) + absorbed

/// Every voice screams again when it's done, each a little apart: pitched down and doubled out of
/// tune, a quarter of them backwards.
/datum/serverblight_chase/proc/scream()
	var/list/voices = get_voices()
	for(var/index in 1 to length(voices))
		if(world.time < (next_screams["[index]"] || 0))
			continue
		next_screams["[index]"] = world.time + rand(8, 22)
		var/scream = get_serverblight_scream(voices[index])
		var/pitch = rand(55, 85) / 100 * (prob(25) ? -1 : 1)
		playsound(host, scream, 55, FALSE, 4, frequency = pitch)
		playsound(host, scream, 40, FALSE, 4, frequency = pitch * 1.06)

/// Dead: slack, silent, and still for a while.
/datum/serverblight_chase/proc/die()
	physics.go_dormant()
	hold(null, 0)
	prey = null
	path = null
	grip = 0
	next_screams.Cut()
	vcphys_call("body_set_velocity", world_handle, body, 0, 0, 0)
	// Lying dead, it's only where it lies.
	for(var/obj/effect/serverblight_hitbox/hitbox as anything in hitboxes)
		hitbox.moveToNullspace()
	host.visible_message(span_danger("[host] comes apart and lies still."))
	rise_timer = addtimer(CALLBACK(src, PROC_REF(rise)), SERVERBLIGHT_DEATH_TIME, TIMER_STOPPABLE|TIMER_UNIQUE)

/// Gets back up, whole (limbs aside: without a head, it stays down), and starts over.
/datum/serverblight_chase/proc/rise()
	deltimer(rise_timer)
	rise_timer = null
	if(QDELETED(host) || QDELETED(physics))
		return
	if(host.stat == DEAD)
		host.revive(HEAL_DAMAGE|HEAL_ORGANS|HEAL_REFRESH_ORGANS|HEAL_WOUNDS|HEAL_BLOOD|HEAL_TEMP, force_grab_ghost = TRUE)
	if(host.stat == DEAD)
		host.visible_message(span_notice("[host] twitches once, and doesn't get up."))
		qdel(physics)
		return
	physics.rebuild()
	if(QDELETED(physics))
		return
	host.visible_message(span_danger("[host] pulls itself back up, every joint the wrong way."))
	playsound(host, 'sound/effects/wounds/crack2.ogg', 100, TRUE)

/**
 * Shot: the hit jerks the body. It only moves it if the gun kicks, or the shot would knock someone
 * down: then it's shoved back, harder the more it kicks.
 */
/datum/serverblight_chase/proc/on_shot(mob/living/source, obj/projectile/shot, def_zone, piercing_hit, blocked)
	SIGNAL_HANDLER
	if(!istype(shot) || QDELETED(physics))
		return
	var/dx = sin(shot.angle)
	var/dy = cos(shot.angle)
	physics.push(RIG_CHEST, dx * shot.damage * 0.6, abs(dy) * shot.damage * 0.3)
	var/obj/item/gun/gun = shot.fired_from
	var/shove = (istype(gun) ? max(gun.recoil, 0) : 0) + (shot.knockdown ? 2 : 0)
	if(shove)
		vcphys_call("body_impulse", world_handle, body, dx * shove * 1.5, dy * shove * 1.5)

/// The scream a body makes, as its species screams, or a person's for anything that doesn't.
/proc/get_serverblight_scream(mob/living/carbon/voice)
	var/mob/living/carbon/human/human = voice
	if(istype(human))
		. = human.dna?.species?.get_scream_sound(human)
	if(islist(.))
		. = pick(.)
	if(!.)
		. = pick('sound/mobs/humanoids/human/scream/malescream_1.ogg', 'sound/mobs/humanoids/human/scream/femalescream_1.ogg')

/// Whether there's anything in reach to throw itself off: anything solid, or lattice.
/datum/serverblight_chase/proc/can_push_off()
	return host.get_spacemove_backup() || (locate(/obj/structure/lattice) in range(1, get_turf(host)))

/datum/serverblight_chase/proc/on_spacemove(atom/movable/source, movement_dir, continuous_move)
	SIGNAL_HANDLER
	return COMSIG_MOVABLE_STOP_SPACEMOVE

/**
 * Everyone it's taken in makes it bigger to hit: two more of the tiles round it for each, the ones
 * its mass sprawls over (either side first, then above), wherever there's room.
 */
/datum/serverblight_chase/proc/update_hitboxes()
	var/static/list/sprawl = list(EAST, WEST, NORTH, NORTHEAST, NORTHWEST)
	var/wanted = min(length(absorbed) * 2, length(sprawl))
	while(length(hitboxes) < wanted)
		hitboxes += new /obj/effect/serverblight_hitbox(null, src)
	var/turf/here = get_turf(host)
	for(var/index in 1 to length(hitboxes))
		var/obj/effect/serverblight_hitbox/hitbox = hitboxes[index]
		var/turf/spot = here && get_step(here, sprawl[index])
		if(!spot || spot.density)
			if(hitbox.loc)
				hitbox.moveToNullspace()
			continue
		if(hitbox.loc != spot)
			hitbox.forceMove(spot)

/// Where Serverblight's mass is, but not its body: stops shots, and hands them to the body.
/obj/effect/serverblight_hitbox
	name = "Serverblight"
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	// Dense, so shots stop here; everything else is let through (see CanAllowThrough()).
	density = TRUE
	/// The hunt it's part of.
	var/datum/serverblight_chase/chase

/obj/effect/serverblight_hitbox/Initialize(mapload, datum/serverblight_chase/chase)
	. = ..()
	src.chase = chase

/obj/effect/serverblight_hitbox/Destroy()
	chase = null
	return ..()

/obj/effect/serverblight_hitbox/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	return . || !isprojectile(mover)

/obj/effect/serverblight_hitbox/bullet_act(obj/projectile/proj, def_zone, piercing_hit = FALSE, blocked = 0)
	. = ..()
	if(. != BULLET_ACT_HIT)
		return
	var/mob/living/carbon/host = chase?.host
	if(QDELETED(host) || host.stat == DEAD)
		return BULLET_ACT_FORCE_PIERCE
	return host.bullet_act(proj, def_zone, piercing_hit, host.check_projectile_armor(def_zone, proj))
