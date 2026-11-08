/**
 * # Gorilla throws and wall impacts
 *
 * Every body the Gorilla Arms send flying (the one-tile shove, the hurl, the haymaker) takes one
 * safe path: gorilla_plan_knockback() walks the tiles first and stops the body on the last good one
 * before space, open air, a chasm, lava, a tile with no gravity, a window, a door, a railing or a
 * grille. It never launches at all from a tile with no gravity. A wall or a standing body in the way
 * is hit, as tg would.
 *
 * Along the way the body leaves a scuff and a little dust on each tile, or a blood streak if it bleeds,
 * at most GORILLA_TRAIL_MAX of them.
 *
 * Any hard throw into a wall (a Gorilla's or anyone else's) leaves a mark chosen by the injury the body
 * carries when it hits (owner D38): no broken skin dents the wall and knocks chips off it; a bleeding
 * cut or a compound fracture splashes a half-moon on the floor and smears the wall's edge; heavy
 * bleeding or a torn artery sprays up the wall and runs. The body is pinned to the wall for a moment
 * and slides down it. A haymaker always dents the wall as well, and adds its own damage and a cracked
 * chest.
 */

/mob/living
	/// The Gorilla throw this mob is flying in, if any (hyperviolence_gorilla). Cleared when it lands.
	var/datum/gorilla_flight/gorilla_flight

/// One Gorilla throw in flight: who threw it, what kind, and what it has left on the floor.
/datum/gorilla_flight
	/// The body in the air
	var/mob/living/victim
	/// Who threw it
	var/mob/living/thrower
	/// TRUE for a haymaker: extra damage, a cracked chest and a dent on a wall
	var/haymaker = FALSE
	/// Decals left so far
	var/trail_left = 0
	/// The punch that launched it broke the skin: the trail is blood even if nothing bled before
	var/wounded = FALSE
	/// Safety timer that ends the flight if the landing signal never comes
	var/expiry_timer

/datum/gorilla_flight/New(mob/living/victim, mob/living/thrower, haymaker = FALSE, wounded = FALSE)
	. = ..()
	src.victim = victim
	src.thrower = thrower
	src.haymaker = haymaker
	src.wounded = wounded
	victim.gorilla_flight = src
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(victim, COMSIG_MOVABLE_THROW_LANDED, PROC_REF(on_landed))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))
	expiry_timer = addtimer(CALLBACK(src, PROC_REF(end)), 3 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)

/datum/gorilla_flight/Destroy()
	if(expiry_timer)
		deltimer(expiry_timer)
		expiry_timer = null
	if(victim)
		UnregisterSignal(victim, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_THROW_LANDED, COMSIG_QDELETING))
		if(victim.gorilla_flight == src)
			victim.gorilla_flight = null
	victim = null
	thrower = null
	return ..()

/// Ends the flight. Safe to call more than once.
/datum/gorilla_flight/proc/end()
	expiry_timer = null
	if(!QDELETED(src))
		qdel(src)

/datum/gorilla_flight/proc/on_victim_deleted(datum/source)
	SIGNAL_HANDLER
	end()

/// Whether the body leaves blood rather than a scuff.
/datum/gorilla_flight/proc/bleeds()
	if(victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return FALSE
	if(wounded)
		return TRUE
	if(!iscarbon(victim))
		return FALSE
	var/mob/living/carbon/body = victim
	return body.get_bleed_rate() > 0

/// Each tile left behind gets a scuff and dust, or a streak of blood.
/datum/gorilla_flight/proc/on_moved(atom/movable/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(trail_left >= GORILLA_TRAIL_MAX || !isturf(old_loc) || !victim.throwing)
		return
	var/turf/left = old_loc
	if(!isfloorturf(left) || !left.has_gravity())
		return
	trail_left++
	var/travel = get_dir(old_loc, victim) || dir
	if(bleeds())
		hv_blood_lay_spray(left, /obj/effect/decal/cleanable/blood/hv_spray/streak, travel, victim.get_blood_dna_list(), victim.get_static_viruses())
		return
	new /obj/effect/temp_visual/gorilla_scuff(left, travel)
	var/obj/effect/temp_visual/mook_dust/dust = cyberware_grey_dust(left)
	if(dust)
		dust.transform = matrix().Scale(0.5)

/// Where it skids to a stop: a splash if it bleeds.
/datum/gorilla_flight/proc/on_landed(datum/source, datum/thrownthing/throwing_datum)
	SIGNAL_HANDLER
	var/turf/stop = get_turf(victim)
	if(isfloorturf(stop) && stop.has_gravity() && bleeds() && trail_left < GORILLA_TRAIL_MAX)
		hv_blood_lay_spray(stop, /obj/effect/decal/cleanable/blood/hv_spray, throwing_datum?.init_dir || victim.dir, victim.get_blood_dna_list(), victim.get_static_viruses())
	end()

/// The grey drag mark a launched body leaves on the floor. It fades on its own.
/obj/effect/temp_visual/gorilla_scuff
	icon = GORILLA_GORE_ICON
	icon_state = "scuff"
	plane = FLOOR_PLANE
	layer = ABOVE_OPEN_TURF_LAYER
	randomdir = FALSE
	duration = 8 SECONDS

/obj/effect/temp_visual/gorilla_scuff/Initialize(mapload, travel_dir)
	. = ..()
	setDir(travel_dir || SOUTH)
	animate(src, alpha = 255, time = duration - 3 SECONDS)
	animate(alpha = 0, time = 3 SECONDS)

// =========================================================================
// THE SAFE PATH
// =========================================================================

/**
 * Whether a body flying from [here] into [next] must stop short on [here] without hitting anything:
 * the edge of the map, a hole, lava, open air, space, no gravity, or glass, a door, a railing or a
 * grille in the way (the body would break the glass or the door would take the hit).
 */
/proc/gorilla_throw_stops_short(turf/here, turf/next, direction)
	if(isnull(next))
		return TRUE
	if(isspaceturf(next) || isopenspaceturf(next) || ischasm(next) || islava(next) || isgroundlessturf(next))
		return TRUE
	if(!isclosedturf(next) && !next.has_gravity())
		return TRUE
	// Something on the edge of our own tile, facing the way we fly
	for(var/obj/border in here)
		if(!border.density || !(border.flags_1 & ON_BORDER_1) || !(border.dir & direction))
			continue
		if(gorilla_throw_is_barrier(border))
			return TRUE
	for(var/obj/thing in next)
		if(!thing.density)
			continue
		if((thing.flags_1 & ON_BORDER_1) && !(thing.dir & REVERSE_DIR(direction)))
			continue
		if(gorilla_throw_is_barrier(thing))
			return TRUE
	return FALSE

/// Glass, doors, railings and grilles: a flying body stops before them rather than going through or breaking them.
/proc/gorilla_throw_is_barrier(obj/thing)
	return istype(thing, /obj/structure/window) || istype(thing, /obj/machinery/door) || istype(thing, /obj/structure/railing) || istype(thing, /obj/structure/grille) || istype(thing, /obj/structure/falsewall)

/**
 * Plans a knockback of [victim] up to [range] tiles along [direction]. Returns a list:
 * (the turf to throw at, how many tiles it travels, GORILLA_THROW_* why it stops, what it hits or null).
 * A distance of 0 means no throw at all.
 */
/proc/gorilla_plan_knockback(mob/living/victim, direction, range)
	var/turf/here = get_turf(victim)
	if(isnull(here) || !direction || range <= 0)
		return list(here, 0, GORILLA_THROW_SHORT, null)
	if(!here.has_gravity())
		return list(here, 0, GORILLA_THROW_SHORT, null)
	var/turf/current = here
	for(var/step in 1 to range)
		var/turf/next = get_step(current, direction)
		if(isnull(next))
			return list(current, step - 1, GORILLA_THROW_SHORT, null)
		if(isclosedturf(next))
			// The wall is hit: throw at it and the body stops against it
			return list(next, step, GORILLA_THROW_WALL, next)
		if(gorilla_throw_stops_short(current, next, direction))
			return list(current, step - 1, GORILLA_THROW_SHORT, null)
		for(var/mob/living/standing in next)
			if(standing.density && standing != victim)
				return list(next, step, GORILLA_THROW_MOB, standing)
		current = next
	return list(current, range, GORILLA_THROW_CLEAR, null)

/**
 * Throws [victim] along [direction] on the safe path. [haymaker] marks a haymaker's flight; [wounded]
 * makes the trail blood. Returns the distance it will travel, 0 if it doesn't move.
 */
/proc/gorilla_launch(mob/living/victim, mob/living/thrower, direction, range, speed = 2, gentle = FALSE, haymaker = FALSE, wounded = FALSE)
	if(QDELETED(victim) || victim.anchored || victim.buckled || victim.move_resist == INFINITY)
		return 0
	var/list/plan = gorilla_plan_knockback(victim, direction, range)
	var/turf/target = plan[1]
	var/distance = plan[2]
	if(distance <= 0 || isnull(target))
		return 0
	// Megafauna and anything bolted down shrug it off, as safe_throw_at() decides
	if(MOVE_FORCE_STRONG < victim.move_resist * MOVE_FORCE_THROW_RATIO)
		return 0
	if(victim.gorilla_flight)
		qdel(victim.gorilla_flight)
	var/datum/gorilla_flight/flight = new(victim, thrower, haymaker, wounded)
	if(!victim.throw_at(target, distance, speed, thrower, spin = !gentle, gentle = gentle))
		flight.end()
		return 0
	return distance

// =========================================================================
// WALL IMPACTS (owner D38)
// =========================================================================

/// The wounds on a body right now, with their severities, to tell what a hit added.
/mob/living/carbon/proc/gorilla_wound_snapshot()
	. = list()
	for(var/datum/wound/wound as anything in all_wounds)
		.[wound] = wound.severity

/**
 * Which picture a wall impact leaves, from the injury the body carries as it hits (owner D38):
 * GORILLA_SPLAT_SPRAY for a heavy cut or stab or a torn artery, GORILLA_SPLAT_EDGE for a bleeding
 * cut or stab or a compound fracture, else GORILLA_SPLAT_DENT. A body that can't bleed only dents.
 */
/mob/living/carbon/proc/gorilla_splat_kind()
	if(can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return GORILLA_SPLAT_DENT
	var/kind = GORILLA_SPLAT_DENT
	for(var/datum/wound/wound as anything in all_wounds)
		var/series = wound.get_pregen_data()?.wound_series
		// A torn aorta or throat (#509), or a limb artery torn by a blade
		if(series == WOUND_SERIES_HV_AORTA || series == WOUND_SERIES_HV_CAROTID || series == "wound_series_hv_limb_artery")
			return GORILLA_SPLAT_SPRAY
		if(istype(wound, /datum/wound/slash) || istype(wound, /datum/wound/pierce))
			if(wound.severity >= WOUND_SEVERITY_SEVERE)
				return GORILLA_SPLAT_SPRAY
			if(wound.severity >= WOUND_SEVERITY_MODERATE)
				kind = GORILLA_SPLAT_EDGE
		else if(istype(wound, /datum/wound/blunt/bone) && wound.severity >= WOUND_SEVERITY_CRITICAL)
			// A compound fracture breaks the skin
			kind = GORILLA_SPLAT_EDGE
	return kind

/mob/living/carbon/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	var/datum/gorilla_flight/flight = gorilla_flight
	var/hard_wall = isclosedturf(hit_atom) && hit_atom.density && istype(throwingdatum) && !throwingdatum.gentle
	. = ..()
	if(!hard_wall || QDELETED(src))
		return
	gorilla_wall_impact(hit_atom, flight)

/**
 * A hard landing against [wall]: the haymaker's extra, the pinned slide down the wall and the marks.
 */
/mob/living/carbon/proc/gorilla_wall_impact(turf/wall, datum/gorilla_flight/flight)
	var/turf/floor = get_turf(src)
	var/toward = get_dir(floor, wall)
	if(!toward)
		return
	if(flight?.haymaker)
		gorilla_haymaker_wall_hit(flight)
	gorilla_wall_sag(toward)
	var/kind = gorilla_splat_kind()
	// Only a straight hit on a wall face gets the pictures; a glancing corner hit gets the dent.
	if(!(toward in GLOB.cardinals))
		gorilla_wall_dent(wall, toward)
		return
	switch(kind)
		if(GORILLA_SPLAT_SPRAY)
			gorilla_lay_wall_decal(floor, /obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray, toward)
			gorilla_lay_wall_decal(floor, /obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/runs, toward)
		if(GORILLA_SPLAT_EDGE)
			gorilla_lay_wall_decal(floor, /obj/effect/decal/cleanable/blood/hv_spray/gorilla_splash, toward)
			gorilla_lay_wall_decal(floor, /obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/edge, toward)
		else
			gorilla_wall_chips(floor, toward)
	if(kind == GORILLA_SPLAT_DENT || flight?.haymaker)
		gorilla_wall_dent(wall, toward)

/// The haymaker's body hits the wall harder: more damage and a cracked chest unless armour stops it.
/mob/living/carbon/proc/gorilla_haymaker_wall_hit(datum/gorilla_flight/flight)
	var/obj/item/bodypart/chest = get_bodypart(BODY_ZONE_CHEST)
	if(isnull(chest))
		return
	var/armour = run_armor_check(chest, MELEE)
	apply_damage(GORILLA_HAYMAKER_WALL_DAMAGE, BRUTE, chest, armour, wound_bonus = CANT_WOUND)
	if(hv_crit_cover_rating(src, chest, MELEE) >= GORILLA_SNAP_ARMOUR)
		return
	if(hv_crit_apply_wound(chest, /datum/wound/blunt/bone/severe, get_dir(flight?.thrower || src, src), flight?.thrower))
		hv_add_hit_line("[src]'s ribs crack against the wall!", HV_LINE_BOLD, "Your ribs crack against the wall!")

/// Pinned to the wall for a beat, then sliding down it. Every offset is a tracked source tg removes.
/mob/living/proc/gorilla_wall_sag(toward)
	var/dx = (toward & EAST) ? 5 : ((toward & WEST) ? -5 : 0)
	var/dy = (toward & NORTH) ? 7 : ((toward & SOUTH) ? -3 : 0)
	add_offsets(GORILLA_WALL_SAG, x_add = dx, z_add = dy, animate = FALSE)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/mob/living, remove_offsets), GORILLA_WALL_SAG, TRUE), 0.15 SECONDS)

/// Lays (or refreshes) one wall-impact decal on the floor tile in front of the wall.
/mob/living/carbon/proc/gorilla_lay_wall_decal(turf/floor, decal_type, toward)
	if(!isturf(floor) || isclosedturf(floor) || isgroundlessturf(floor))
		return null
	var/list/blood_dna = get_blood_dna_list()
	var/list/viruses = get_static_viruses()
	for(var/obj/effect/decal/cleanable/blood/hv_spray/existing in floor)
		if(existing.type != decal_type || existing.dir != toward || existing.dried || QDELETED(existing))
			continue
		existing.add_blood_DNA(blood_dna, viruses)
		return existing
	var/obj/effect/decal/cleanable/blood/hv_spray/fresh = new decal_type(floor, viruses, blood_dna)
	if(QDELETED(fresh))
		return null
	fresh.hv_aim(toward)
	return fresh

/// Chips knocked off the wall where the body hit it.
/mob/living/carbon/proc/gorilla_wall_chips(turf/floor, toward)
	var/obj/effect/abstract/gorilla_chips/chips = new(floor)
	chips.aim(toward)

/// A body-sized dent in a wall, kept with the wall's bullet holes and dents so a welder repairs it.
/proc/gorilla_wall_dent(turf/closed/wall/wall, toward)
	if(!istype(wall) || LAZYLEN(wall.dent_decals) >= MAX_DENT_DECALS)
		return FALSE
	if(!(toward in GLOB.cardinals))
		toward = (toward & (EAST|WEST)) || (toward & (NORTH|SOUTH))
	var/mutable_appearance/dent = mutable_appearance(GORILLA_GORE_ICON, "wall_dent_[dir2text(toward)]", BULLET_HOLE_LAYER)
	if(LAZYLEN(wall.dent_decals))
		wall.cut_overlay(wall.dent_decals)
		wall.dent_decals += dent
	else
		wall.dent_decals = list(dent)
	wall.add_overlay(wall.dent_decals)
	return TRUE

/// A short burst of grey chips off the contact point.
/obj/effect/abstract/gorilla_chips
	name = "chips"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = ABOVE_MOB_LAYER

/obj/effect/abstract/gorilla_chips/Initialize(mapload)
	. = ..()
	particles = new /particles/gorilla_chips
	addtimer(CALLBACK(src, PROC_REF(stop)), 0.2 SECONDS)
	QDEL_IN(src, 1 SECONDS)

/// Throws the chips back off the wall at [toward].
/obj/effect/abstract/gorilla_chips/proc/aim(toward)
	var/dx = (toward & EAST) ? 1 : ((toward & WEST) ? -1 : 0)
	var/dy = (toward & NORTH) ? 1 : ((toward & SOUTH) ? -1 : 0)
	pixel_x = dx * 14
	pixel_y = dy * 14
	var/particles/gorilla_chips/burst = particles
	burst.velocity = generator(GEN_BOX, list(-dx * 3 - 1.5, -dy * 3 - 1.5, 0), list(-dx * 1 + 1.5, -dy * 1 + 1.5, 0), UNIFORM_RAND)

/obj/effect/abstract/gorilla_chips/proc/stop()
	if(particles)
		particles.spawning = 0

/particles/gorilla_chips
	icon = 'icons/effects/particles/generic.dmi'
	icon_state = list("dot" = 3, "cross" = 1)
	color = "#8a8e96"
	count = 12
	spawning = 6
	lifespan = 0.5 SECONDS
	fade = 0.25 SECONDS
	position = generator(GEN_BOX, list(-4, -4, 0), list(4, 4, 0), UNIFORM_RAND)
	velocity = generator(GEN_BOX, list(-2, -2, 0), list(2, 2, 0), UNIFORM_RAND)
	gravity = list(0, -0.4)
	friction = 0.1
	scale = 0.5

// ---- The decals. Greyscale art tinted to the victim's blood, on the floor tile in front of the wall. ----

/// Option C: a half-moon splash on the floor at the foot of the wall. Mops like floor blood.
/obj/effect/decal/cleanable/blood/hv_spray/gorilla_splash
	name = "blood splatter"
	icon = GORILLA_GORE_LARGE_ICON
	icon_state = "impact_splash"
	random_icon_states = null
	bloodiness = 20

/obj/effect/decal/cleanable/blood/hv_spray/gorilla_splash/hv_aim(spray_dir)
	setDir(spray_dir)
	pixel_x = -16
	pixel_y = -16

/// Wall pictures: 64x64 on the floor tile at -16,-16, drawn up onto the wall's near edge.
/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray
	name = "blood spray"
	icon = GORILLA_GORE_LARGE_ICON
	icon_state = "impact_spray"
	random_icon_states = null
	alpha = 230

/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/hv_aim(spray_dir)
	setDir(spray_dir)
	pixel_x = -16
	pixel_y = -16

/// Option A's runs down the wall face. They crawl down as they appear.
/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/runs
	name = "blood runs"
	icon_state = "impact_runs"
	alpha = 220

/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/runs/hv_aim(spray_dir)
	. = ..()
	// The runs grow downward from where the spray hit. Parallel: tg's drying animation keeps running.
	var/matrix/start = matrix()
	start.Scale(1, 0.25)
	start.Translate(0, 16)
	transform = start
	animate(src, transform = matrix(), time = 3 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)

/// Option C's thin band on the wall's edge where the body slid down it.
/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/edge
	name = "blood smear"
	icon_state = "impact_edge"
	alpha = 220
