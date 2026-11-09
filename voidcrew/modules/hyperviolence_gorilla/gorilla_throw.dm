/**
 * # Gorilla throws and wall impacts
 *
 * Every body the Gorilla Arms send flying (the one-tile shove, the hurl, the haymaker) takes one
 * safe path: gorilla_plan_knockback() walks the tiles first and stops the body on the last good one
 * before space, open air, a chasm, lava, a tile with no gravity, a window, a door, a railing or a
 * grille. It never launches at all from a tile with no gravity. A wall or a standing body in the way
 * is hit, as tg would.
 *
 * Bodies fly flat, without spinning, and skid. Along the way the body leaves a scuff and a little dust
 * on each tile, or a ragged smear of blood drops if it bleeds, on at most GORILLA_TRAIL_MAX tiles.
 *
 * A Gorilla throw that meets a wall hurts through tg's damage and wound rolls (owner D48): a blunt hit
 * on the part that meets it and split skin on the wall's edge, harder for a haymaker than a hurl, and
 * likelier to wound a part that is already beaten. It replaces tg's own random-limb wall crash for that
 * throw. A shove only dents the wall. Any hard throw into a wall (a Gorilla's or anyone else's) then
 * leaves a mark chosen by the injuries the body carries after the hit (owner D38): no broken skin dents
 * the wall and knocks chips off it; a bleeding cut or a compound fracture splashes a half-moon on the
 * floor and smears the wall's edge; heavy bleeding or a torn artery sprays up the wall and runs. The
 * body drops at the foot of the wall with tg's knockdown, no slide (D44). A haymaker always dents too.
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
	/// TRUE for a haymaker: it always dents a wall
	var/haymaker = FALSE
	/// GORILLA_IMPACT_*: how hard it meets a wall
	var/impact = GORILLA_IMPACT_HURL
	/// Decals left so far
	var/trail_left = 0
	/// The punch that launched it broke the skin: the trail is blood even if nothing bled before
	var/wounded = FALSE
	/// Safety timer that ends the flight if the landing signal never comes
	var/expiry_timer

/datum/gorilla_flight/New(mob/living/victim, mob/living/thrower, haymaker = FALSE, wounded = FALSE, impact = GORILLA_IMPACT_HURL)
	. = ..()
	src.victim = victim
	src.thrower = thrower
	src.haymaker = haymaker
	src.wounded = wounded
	src.impact = haymaker ? GORILLA_IMPACT_HAYMAKER : impact
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
		gorilla_lay_skid_blood(left, travel, victim.get_blood_dna_list(), victim.get_static_viruses())
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

/**
 * A bleeding body's skid over [floor] along [travel]: two to GORILLA_SKID_SPLATS drops and small splats
 * of tg's blood, each a different shape, size and place along the line, so tiles don't repeat.
 */
/proc/gorilla_lay_skid_blood(turf/floor, travel, list/blood_dna, list/viruses)
	var/along_x = (travel & EAST) ? 1 : ((travel & WEST) ? -1 : 0)
	var/along_y = (travel & NORTH) ? 1 : ((travel & SOUTH) ? -1 : 0)
	for(var/i in 1 to rand(2, GORILLA_SKID_SPLATS))
		var/obj/effect/decal/cleanable/blood/splatter/gorilla_skid/splat = new(floor, viruses, blood_dna)
		if(QDELETED(splat))
			continue
		// Spread along the line of travel, a little either side of it
		var/along = rand(-13, 13)
		var/across = rand(-3, 3)
		splat.pixel_x = along * along_x + across * along_y
		splat.pixel_y = along * along_y + across * along_x
		var/matrix/shape = matrix()
		var/size = pick(0.6, 0.75, 0.9, 1.1)
		shape.Scale(size * pick(1, -1), size)
		shape.Turn(pick(0, 90, 180, 270))
		splat.transform = shape

/// One drop or splat of a bleeding body's skid. Several share a tile.
/obj/effect/decal/cleanable/blood/splatter/gorilla_skid
	random_icon_states = list("gibbl1", "gibbl2", "gibbl3", "gibbl4", "gibbl5", "drip2", "drip4")
	mergeable_decal = FALSE
	// Thin enough that walking through it does not leave footprints
	bloodiness = 5

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
	var/datum/gorilla_flight/flight = new(victim, thrower, haymaker, wounded, gentle ? GORILLA_IMPACT_SHOVE : GORILLA_IMPACT_HURL)
	// Flat, no spin: the body skids to a stop
	if(!victim.throw_at(target, distance, speed, thrower, spin = FALSE, gentle = gentle))
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
 * Which picture a wall impact leaves, from the injuries the body carries after the hit (owner D38, D48):
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
	if(!isclosedturf(hit_atom) || !hit_atom.density || !istype(throwingdatum))
		return ..()
	var/was_gentle = throwingdatum.gentle
	// A Gorilla throw's crash is its own (gorilla_wall_crash()): tg's random-limb crash is held off by
	// passing the throw to the parent as gentle, then put back.
	var/own_crash = !isnull(flight) && flight.victim == src
	if(own_crash)
		throwingdatum.gentle = TRUE
	. = ..()
	throwingdatum.gentle = was_gentle
	if(QDELETED(src) || (was_gentle && !own_crash))
		return
	gorilla_wall_impact(hit_atom, own_crash ? flight : null)

/**
 * A landing against [wall]: the Gorilla throw's crash, if it was one, then the marks by the wounds after it.
 */
/mob/living/carbon/proc/gorilla_wall_impact(turf/wall, datum/gorilla_flight/flight)
	var/turf/floor = get_turf(src)
	var/toward = get_dir(floor, wall)
	if(!toward)
		return
	if(flight)
		gorilla_wall_crash(wall, flight, toward)
		if(QDELETED(src))
			return
	// A shove only bumps the wall, whatever the body carries
	var/kind = flight?.impact == GORILLA_IMPACT_SHOVE ? GORILLA_SPLAT_DENT : gorilla_splat_kind()
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

/**
 * A Gorilla throw meets [wall] going [toward] (owner D48). A shove does nothing more than tg's gentle
 * throw. A hurl or a haymaker knocks the body down as tg's crash does and lands two real hits on the
 * part that meets the wall: a blunt one (tg's bone wounds) and the skin split on the wall's edge (tg's
 * cuts), each through armour and tg's wound roll. A part that is already beaten gets a higher wound
 * bonus, so a hurt body is likelier to break open.
 */
/mob/living/carbon/proc/gorilla_wall_crash(turf/wall, datum/gorilla_flight/flight, toward)
	var/blunt
	var/blunt_wound
	var/edge
	var/edge_wound
	switch(flight.impact)
		if(GORILLA_IMPACT_HAYMAKER)
			blunt = GORILLA_WALL_HAYMAKER_BLUNT
			blunt_wound = GORILLA_WALL_HAYMAKER_BLUNT_WOUND
			edge = GORILLA_WALL_HAYMAKER_EDGE
			edge_wound = GORILLA_WALL_HAYMAKER_EDGE_WOUND
		if(GORILLA_IMPACT_HURL)
			blunt = GORILLA_WALL_HURL_BLUNT
			blunt_wound = GORILLA_WALL_HURL_BLUNT_WOUND
			edge = GORILLA_WALL_HURL_EDGE
			edge_wound = GORILLA_WALL_HURL_EDGE_WOUND
		else
			return
	Paralyze(GORILLA_WALL_KNOCKDOWN)
	visible_message(span_danger("[src] slams into [wall]!"), span_userdanger("You slam into [wall]!"))
	playsound(src, 'sound/items/weapons/punch1.ogg', 50, TRUE)
	log_combat(flight.thrower || wall, src, "slammed into a wall", null, "(gorilla throw, impact [flight.impact])")
	var/obj/item/bodypart/part = get_bodypart(gorilla_wall_zone(toward)) || get_bodypart(BODY_ZONE_CHEST)
	if(isnull(part))
		return
	var/hurt_bonus = min(GORILLA_WALL_HURT_MAX, round(part.brute_dam / GORILLA_WALL_HURT_PER_POINT))
	var/armour = run_armor_check(part, MELEE, silent = TRUE)
	// The wall's marks are the picture; no #509 blood fan on top of them
	gorilla_hold_spray(src)
	apply_damage(blunt, BRUTE, part, armour, wound_bonus = blunt_wound + hurt_bonus, attack_direction = toward)
	if(QDELETED(src) || part.owner != src)
		return
	apply_damage(edge, BRUTE, part, armour, wound_bonus = edge_wound + hurt_bonus, sharpness = SHARP_EDGED, attack_direction = toward)

/**
 * The part that meets a wall at [toward]: a body side-on to it takes it on the shoulder half the time,
 * otherwise the chest, sometimes the head.
 */
/mob/living/carbon/proc/gorilla_wall_zone(toward)
	if(turn(dir, -90) == toward && prob(50))
		return BODY_ZONE_R_ARM
	if(turn(dir, 90) == toward && prob(50))
		return BODY_ZONE_L_ARM
	return prob(75) ? BODY_ZONE_CHEST : BODY_ZONE_HEAD

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
	// Against a side wall, seen from above, the half-moon would sit on the wall line like option A's spray:
	// pull it out onto the floor so it reads as a puddle at the wall's foot.
	if(spray_dir & EAST)
		pixel_x -= 8
	else if(spray_dir & WEST)
		pixel_x += 8

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
	// The runs grow downward from their top on the wall face, so they never show past it. Parallel: tg's
	// drying animation keeps running.
	var/top = 0
	switch(spray_dir)
		if(SOUTH)
			top = -17
		if(NORTH)
			top = 25
		else
			top = -1
	var/matrix/start = matrix()
	start.Scale(1, 0.25)
	start.Translate(0, round(top * 0.75))
	transform = start
	animate(src, transform = matrix(), time = 3 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)

/// Option C's thin band on the wall's edge where the body slid down it.
/obj/effect/decal/cleanable/blood/hv_spray/wall/gorilla_spray/edge
	name = "blood smear"
	icon_state = "impact_edge"
	alpha = 220
