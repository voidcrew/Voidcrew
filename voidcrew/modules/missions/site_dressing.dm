/**
 * # Mission Site Dressing
 *
 * A recovery item on its own is one sprite on a random tile: nothing on the site
 * says anything happened there, and nothing draws the eye to it. A scene lays a
 * little set dressing around the objective's anchor turf (a crater and wreckage
 * for a crash, a dropped flare and some litter for a lost case) so the spot can be
 * found by looking and reads like the job's story.
 *
 * Everything placed here is an /obj/effect: it can't be picked up, taken apart,
 * broken for parts or sold. Footprint is the anchor plus up to two tiles around
 * it, only on open, unblocked ground inside the site, never on another objective.
 * The only lasting cost is a smoke emitter and a couple of lights, which burn out
 * on one timer each; nothing processes.
 */

/// How long a crash keeps smoking and a dropped flare keeps burning
#define MISSION_SCENE_BURN_TIME (15 MINUTES)

/// Lays a scene around an objective's anchor turf. Null or a bad path does nothing.
/proc/dress_mission_scene(scene_type, turf/anchor, datum/mission_target/target)
	if(!anchor || !ispath(scene_type, /datum/mission_scene))
		return
	var/datum/mission_scene/scene = new scene_type
	scene.dress(anchor, target)

/datum/mission_scene

/// Places the scene. The anchor holds the objective; only flat ground marks go on it.
/datum/mission_scene/proc/dress(turf/anchor, datum/mission_target/target)
	return

/// Whether one piece of dressing may go on this turf
/datum/mission_scene/proc/can_use(turf/tile, datum/mission_target/target)
	var/static/list/objective_types = typecacheof(list(
		/obj/item/mission_recovery,
		/obj/structure/mission_survey_pylon,
		/obj/structure/mission_claim_beacon,
		/obj/structure/ingredient_cache,
		/obj/item/drug_ingredient,
		/obj/effect/anomaly,
		/obj/effect/decal/mission_scene,
	))
	if(!isopenturf(tile) || isspaceturf(tile) || isgroundlessturf(tile))
		return FALSE
	if(tile.is_blocked_turf(exclude_mobs = TRUE))
		return FALSE
	// A landed ship's floor flies off with whatever is on it
	if(istype(get_area(tile), /area/shuttle))
		return FALSE
	if(target && !target.contains_turf(tile))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(objective_types[thing.type])
			return FALSE
	return TRUE

/// Usable turfs within range of the anchor, the anchor itself excluded
/datum/mission_scene/proc/spots_around(turf/anchor, datum/mission_target/target, range = 1)
	var/list/spots = list()
	for(var/turf/tile as anything in RANGE_TURFS(range, anchor))
		if(tile != anchor && can_use(tile, target))
			spots += tile
	return spots

/**
 * Puts one piece on a spot from the list, preferring one no other piece of this
 * scene took. Returns the piece, or null when there was nowhere to put it.
 */
/datum/mission_scene/proc/place(piece_type, list/spots, list/taken)
	if(!length(spots))
		return null
	var/list/free = spots - taken
	var/turf/spot = pick(length(free) ? free : spots)
	taken += spot
	return new piece_type(spot)

// =========================================================================
// CRASH: something came down hard (Field Expedition)
// =========================================================================

/datum/mission_scene/crash

/datum/mission_scene/crash/dress(turf/anchor, datum/mission_target/target)
	new /obj/effect/decal/mission_scene/scorch(anchor)
	new /obj/effect/decal/mission_scene/scorch/core(anchor)
	var/list/near = spots_around(anchor, target, 1)
	var/list/far = spots_around(anchor, target, 2) - near
	var/list/taken = list()
	// The furrow it ploughed coming in, and the hull it shed at the end of it
	var/skid_dir = pick_skid_dir(anchor, target)
	if(skid_dir)
		var/obj/effect/decal/mission_scene/skid/skid = new(anchor)
		skid.point(skid_dir)
		var/turf/beyond = get_step(anchor, REVERSE_DIR(skid_dir))
		if(beyond in near)
			taken += beyond
			new /obj/effect/decal/mission_scene/wreck(beyond)
		else
			place(/obj/effect/decal/mission_scene/wreck, near, taken)
	else
		place(/obj/effect/decal/mission_scene/wreck, near, taken)
	place(/obj/effect/decal/mission_scene/wreck/dish, near, taken)
	place(/obj/effect/decal/mission_scene/debris, near, taken)
	place(/obj/effect/decal/mission_scene/debris/glass, near, taken)
	place(/obj/effect/decal/mission_scene/debris, length(far) ? far : near, taken)
	for(var/_ in 1 to 3)
		place(/obj/effect/decal/mission_scene/debris/rubble, length(far) ? far : near, taken)

/// A direction with two clear tiles for the furrow, or null
/datum/mission_scene/crash/proc/pick_skid_dir(turf/anchor, datum/mission_target/target)
	for(var/direction in shuffle(GLOB.alldirs))
		var/turf/first = get_step(anchor, direction)
		var/turf/second = first && get_step(first, direction)
		if(second && can_use(first, target) && can_use(second, target))
			return direction
	return null

// =========================================================================
// DROPPED CASE: somebody lost it here and lit a flare (recovery)
// =========================================================================

/datum/mission_scene/dropped_case

/datum/mission_scene/dropped_case/dress(turf/anchor, datum/mission_target/target)
	new /obj/effect/decal/mission_scene/scorch/scuff(anchor)
	var/list/near = spots_around(anchor, target, 1)
	var/list/taken = list()
	place(/obj/effect/decal/mission_scene/flare, near, taken)
	place(/obj/effect/decal/mission_scene/debris/glass, near, taken)
	place(/obj/effect/decal/mission_scene/debris, near, taken)

// =========================================================================
// CARGO WRECK: the crate it came in, broken open (extraction)
// =========================================================================

/datum/mission_scene/cargo_wreck

/datum/mission_scene/cargo_wreck/dress(turf/anchor, datum/mission_target/target)
	new /obj/effect/decal/mission_scene/scorch/scuff(anchor)
	var/list/near = spots_around(anchor, target, 1)
	var/list/taken = list()
	place(/obj/effect/decal/mission_scene/crate, near, taken)
	place(/obj/effect/decal/mission_scene/flare, near, taken)
	place(/obj/effect/decal/mission_scene/debris, near, taken)
	place(/obj/effect/decal/mission_scene/debris/glass, near, taken)

// =========================================================================
// PYLON DROP: a survey pylon landed from orbit (survey, core sample)
// =========================================================================

/datum/mission_scene/pylon_drop

/datum/mission_scene/pylon_drop/dress(turf/anchor, datum/mission_target/target)
	new /obj/effect/decal/mission_scene/scorch/pylon(anchor)
	var/list/near = spots_around(anchor, target, 1)
	var/list/taken = list()
	for(var/_ in 1 to 2)
		place(/obj/effect/decal/mission_scene/debris/rubble, near, taken)

// =========================================================================
// THE PIECES
// =========================================================================

/// Set dressing. An effect, so it gives nothing when attacked, wrenched or blown up.
/obj/effect/decal/mission_scene
	name = "wreckage"
	desc = "Torn plating and burnt wiring."
	icon = 'icons/mob/silicon/robots.dmi'
	icon_state = "gib1"
	plane = GAME_PLANE
	layer = LOW_OBJ_LAYER
	/// Icon states picked from at random, if any
	var/list/random_states
	/// Largest random pixel nudge either way
	var/jitter = 6

/obj/effect/decal/mission_scene/Initialize(mapload)
	. = ..()
	if(length(random_states))
		icon_state = pick(random_states)
	if(jitter)
		pixel_x = base_pixel_x + rand(-jitter, jitter)
		pixel_y = base_pixel_y + rand(-jitter, jitter)

/// Scraps of hull and wiring
/obj/effect/decal/mission_scene/debris
	random_states = list("gib1", "gib2", "gib3", "gib4", "gib5", "gib6")

/obj/effect/decal/mission_scene/debris/glass
	name = "broken glass"
	desc = "Glittering shards from a shattered panel."
	icon = 'icons/obj/debris.dmi'
	icon_state = "tiny"
	random_states = list("tiny", "small")

/obj/effect/decal/mission_scene/debris/glass/Initialize(mapload)
	. = ..()
	setDir(pick(GLOB.cardinals))

/obj/effect/decal/mission_scene/debris/rubble
	name = "rubble"
	desc = "Loose chunks thrown clear by the impact."
	icon = 'icons/obj/debris.dmi'
	icon_state = "rubble"
	random_states = null

/// The burn at the center. Wide and soft; the core darkens the middle off-center.
/obj/effect/decal/mission_scene/scorch
	name = "scorched ground"
	desc = "Blackened and still warm."
	icon = 'icons/effects/light_overlays/light_96.dmi'
	icon_state = "light"
	color = "#1e1610"
	alpha = 170
	plane = FLOOR_PLANE
	layer = ABOVE_OPEN_TURF_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	jitter = 4
	SET_BASE_PIXEL(-32, -32)
	/// Horizontal and vertical stretch of the sprite
	var/spread_x = 0.95
	var/spread_y = 0.8

/obj/effect/decal/mission_scene/scorch/Initialize(mapload)
	. = ..()
	var/matrix/shape = matrix()
	shape.Scale(spread_x, spread_y)
	shape.Turn(rand(0, 179))
	transform = shape

/obj/effect/decal/mission_scene/scorch/core
	icon = 'icons/effects/light_overlays/light_64.dmi'
	color = "#120c08"
	alpha = 150
	jitter = 6
	SET_BASE_PIXEL(-16, -16)
	spread_x = 0.6
	spread_y = 0.7

/// A light scuff where something heavy hit the deck
/obj/effect/decal/mission_scene/scorch/scuff
	name = "scuff marks"
	color = "#2a2420"
	alpha = 110
	jitter = 0
	spread_x = 0.6
	spread_y = 0.6

/obj/effect/decal/mission_scene/scorch/pylon
	alpha = 160
	jitter = 0
	spread_x = 0.7
	spread_y = 0.7

/// The furrow a crash ploughs: a long soft smudge pointed away from the anchor
/obj/effect/decal/mission_scene/skid
	name = "furrow"
	desc = "A long gouge in the ground."
	icon = 'icons/effects/light_overlays/light_96.dmi'
	icon_state = "light"
	color = "#1a130d"
	alpha = 150
	plane = FLOOR_PLANE
	layer = ABOVE_OPEN_TURF_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	blocks_emissive = EMISSIVE_BLOCK_NONE
	jitter = 0
	SET_BASE_PIXEL(-32, -32)

/// Lays the furrow out from the anchor toward direction
/obj/effect/decal/mission_scene/skid/proc/point(direction)
	var/matrix/shape = matrix()
	shape.Scale(ISDIAGONALDIR(direction) ? 1.2 : 0.9, 0.38)
	shape.Turn(dir2angle(direction) - 90)
	transform = shape
	var/dx = (direction & EAST) ? 1 : ((direction & WEST) ? -1 : 0)
	var/dy = (direction & NORTH) ? 1 : ((direction & SOUTH) ? -1 : 0)
	pixel_x = base_pixel_x + dx * 44
	pixel_y = base_pixel_y + dy * 44

/// The biggest piece of what came down, smoking until it burns out
/obj/effect/decal/mission_scene/wreck
	name = "smoking wreckage"
	desc = "A buckled hull section, still smoking."
	icon = 'icons/obj/fluff/general.dmi'
	icon_state = "broken_canister"
	color = "#8a8078"
	layer = BELOW_OBJ_LAYER
	jitter = 4
	light_range = 2
	light_power = 0.8
	light_color = LIGHT_COLOR_FIRE
	/// Whether this piece puts up the smoke column
	var/smokes = TRUE

/obj/effect/decal/mission_scene/wreck/Initialize(mapload)
	. = ..()
	if(smokes)
		particles = new /particles/smoke/mission_plume
		addtimer(CALLBACK(src, PROC_REF(burn_out)), MISSION_SCENE_BURN_TIME, TIMER_DELETE_ME)

/obj/effect/decal/mission_scene/wreck/Destroy(force)
	QDEL_NULL(particles)
	return ..()

/obj/effect/decal/mission_scene/wreck/proc/burn_out()
	QDEL_NULL(particles)
	set_light(0)
	name = "wreckage"
	desc = "A buckled hull section, scorched black."

/obj/effect/decal/mission_scene/wreck/dish
	name = "bent antenna dish"
	desc = "Snapped off its mount on the way down."
	icon_state = "sat_dish"
	color = "#a09890"
	light_range = 0
	smokes = FALSE

/obj/effect/decal/mission_scene/wreck/dish/Initialize(mapload)
	. = ..()
	setDir(pick(GLOB.cardinals))
	transform = transform.Turn(pick(-70, 70, 110, -110))

/// The crate the cargo came in
/obj/effect/decal/mission_scene/crate
	name = "smashed crate"
	desc = "Split open and empty."
	icon = 'icons/obj/storage/crates.dmi'
	icon_state = "crateopen"
	color = "#8a8078"
	layer = BELOW_OBJ_LAYER
	jitter = 3

/obj/effect/decal/mission_scene/crate/Initialize(mapload)
	. = ..()
	transform = transform.Turn(rand(-20, 20))

/// Somebody lit it to mark the spot
/obj/effect/decal/mission_scene/flare
	name = "flare"
	desc = "A road flare, burning low."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "flare-on"
	light_range = 3
	light_power = 1
	light_color = LIGHT_COLOR_FLARE

/obj/effect/decal/mission_scene/flare/Initialize(mapload)
	. = ..()
	transform = transform.Turn(rand(0, 359))
	addtimer(CALLBACK(src, PROC_REF(burn_out)), MISSION_SCENE_BURN_TIME, TIMER_DELETE_ME)

/obj/effect/decal/mission_scene/flare/proc/burn_out()
	set_light(0)
	icon_state = "flare-empty"
	name = "spent flare"
	desc = "Burnt down to the stub."

/// A tall, slow column a crew can spot from across the site. Client-side only.
/particles/smoke/mission_plume
	width = 192
	height = 320
	count = 150
	spawning = 2
	lifespan = 4 SECONDS
	fade = 2 SECONDS
	position = generator(GEN_SPHERE, 0, 4, NORMAL_RAND)
	scale = list(1.5, 1.5)
	grow = list(0.05, 0.05)
	gravity = list(0.08, 0.95)

#undef MISSION_SCENE_BURN_TIME
