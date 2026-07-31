/**
 * # Molecular transporter
 *
 * The late-game answer to the drop pod. A transporter pad and a control console,
 * built together, let a ship in orbit put people on the surface and pull them back
 * without ever docking. Crew going down carry a transponder so the console can find
 * them again.
 *
 * The pad owns all of the actual work - beam timing, cooldown, part upgrades and the
 * emag sabotage. The console is the interface that aims it, and holds the research
 * gating for precision targeting.
 *
 * Research ladder (see voidcrew/modules/research/techweb_nodes.dm):
 * - transporter: build the pad, console and transponders. Beam down to random open
 *   ground, beam up anyone carrying a transponder.
 * - transporter_targeting: unlocks the targeting scanner, so you pick the exact turf
 *   at either end. This is what lets you beam into a structure, or grab someone who
 *   isn't carrying a transponder and doesn't want to come.
 * - transporter_biofilter: cleans up the residual damage a cheap pad does to the
 *   people it moves, and lets the console see when a pad's pattern buffer has been
 *   tampered with.
 */

/// Beam cycle length on a pad with no servo upgrades.
#define TRANSPORTER_BASE_BEAM_TIME (10 SECONDS)
/// Beam cycle length on a pad with the best servos.
#define TRANSPORTER_MIN_BEAM_TIME (4 SECONDS)
/// Recharge time between cycles on a stock pad.
#define TRANSPORTER_BASE_COOLDOWN (100 SECONDS)
/// Recharge floor once capacitors and the biofilter node are accounted for.
#define TRANSPORTER_MIN_COOLDOWN (25 SECONDS)
/// How many atoms a stock pattern buffer holds in one cycle.
#define TRANSPORTER_BASE_BUFFER 2

/// Site is a legal endpoint for a beam.
#define TRANSPORTER_SITE_CLEAR 0
/// Site is inside the orbited object but something is standing in the way.
#define TRANSPORTER_SITE_BLOCKED 1
/// Site is not part of whatever the ship is currently orbiting.
#define TRANSPORTER_SITE_NO_LOCK 2
/// Site is inside a structure, which needs the targeting node to thread a beam into.
#define TRANSPORTER_SITE_SEALED 3
/// Site refuses teleports outright.
#define TRANSPORTER_SITE_SHIELDED 4

/// Too big for a pattern buffer to hold, at any tier.
GLOBAL_LIST_INIT(transporter_mass_blacklist, typecacheof(list(
	/mob/living/simple_animal/hostile/megafauna,
	/mob/living/basic/boss,
	/obj/vehicle/sealed/mecha,
)))

/// How far down the sprite the dissolve mask has to travel to hide it completely.
/// The mask icon is 96 tall and BYOND centres filter masks on the thing they're
/// applied to, so a 32-tall sprite sits across the mask's middle third: its head at
/// mask row 32 (where the opaque block starts) and its feet at row 63. The gradient
/// above the opaque block runs out at row 6, so the mask has to slide 63 - 6 + 1 = 58
/// pixels before the feet are fully clear of it.
#define TRANSPORTER_MASK_TRAVEL -58
/// How long a pattern takes to knit back together on arrival.
#define TRANSPORTER_MATERIALISE_TIME (1.2 SECONDS)
/// How long a beam column takes to lift back out when it ends.
#define TRANSPORTER_BEAM_WINDDOWN (0.5 SECONDS)

/// The motes a pattern sheds while it is coming apart or going back together.
/particles/transporter_motes
	icon = 'icons/effects/particles/generic.dmi'
	icon_state = list("dot" = 4, "cross" = 1)
	width = 64
	height = 96
	// Deliberately modest - a full pattern buffer runs this on several atoms at once,
	// at both ends of the beam.
	count = 90
	spawning = 10
	lifespan = 1.4 SECONDS
	fade = 0.7 SECONDS
	fadein = 0.15 SECONDS
	color = 0
	color_change = 0.1
	gradient = list("#8fe3ff", "#d8f6ff", "#ffffff")
	position = generator(GEN_BOX, list(-9, -14, 0), list(9, 12, 0), UNIFORM_RAND)
	velocity = generator(GEN_VECTOR, list(-1, 3, 0), list(1, 11, 0), UNIFORM_RAND)
	drift = generator(GEN_VECTOR, list(-0.3, 0), list(0.3, 0.1), UNIFORM_RAND)
	scale = generator(GEN_VECTOR, list(0.6, 0.6), list(1.1, 1.1), NORMAL_RAND)
	spin = generator(GEN_NUM, list(-20, 20), NORMAL_RAND)

/// The specks of light that stream up the inside of an open-sky beam column.
/particles/transporter_stream
	icon = 'icons/effects/particles/generic.dmi'
	icon_state = list("dot" = 3, "cross" = 1)
	width = 96
	// Tall enough that risers reach the top of the screen of whoever is standing
	// in the column before they leave the drawing region.
	height = 480
	count = 80
	spawning = 5
	lifespan = 1.8 SECONDS
	fade = 0.6 SECONDS
	fadein = 0.2 SECONDS
	color = 0
	color_change = 0.1
	gradient = list("#8fe3ff", "#d8f6ff", "#ffffff")
	position = generator(GEN_BOX, list(-7, -20, 0), list(7, 0, 0), UNIFORM_RAND)
	velocity = generator(GEN_VECTOR, list(-0.5, 12, 0), list(0.5, 26, 0), UNIFORM_RAND)
	drift = generator(GEN_VECTOR, list(-0.2, 0), list(0.2, 0.2), UNIFORM_RAND)
	scale = generator(GEN_VECTOR, list(0.4, 0.4), list(0.9, 0.9), NORMAL_RAND)
	spin = generator(GEN_NUM, list(-15, 15), NORMAL_RAND)

/**
 * The column of light that stands on a turf for the whole length of a beam cycle.
 *
 * Under an open sky it uses the full-height state - a 32x320 shaft that runs ten
 * tiles up the screen, so someone standing inside it sees it go all the way to the
 * top of their view, with motes streaming up the inside. Indoors it swaps to the
 * compact three-tile state, because a deck has a ceiling and the tall shaft would
 * draw across every room north of the pad. Spawned at both ends, so the people
 * being left behind and the people about to be landed on both get warning.
 */
/obj/effect/temp_visual/transporter_beam
	name = "transporter beam"
	desc = "A column of shimmering bluespace light."
	icon = 'voidcrew/modules/transporter/icons/transporter_beam.dmi'
	icon_state = "transporter_column"
	randomdir = FALSE
	layer = ABOVE_ALL_MOB_LAYER
	// The base atom flags include TILE_BOUND, which would cull the shaft for anyone
	// whose screen doesn't include its base turf - fatal for a ten-tile icon.
	appearance_flags = LONG_GLIDE
	alpha = 0
	light_range = 3
	light_power = 2
	light_color = COLOR_CYAN
	duration = TRANSPORTER_BASE_BEAM_TIME
	/// The mote stream rising inside an open-sky column. Null indoors.
	var/obj/effect/abstract/particle_holder/stream

/obj/effect/temp_visual/transporter_beam/Initialize(mapload, beam_duration)
	if(beam_duration)
		duration = beam_duration
	. = ..()
	SET_PLANE(src, ABOVE_GAME_PLANE, loc)
	var/area/here = get_area(src)
	if(here?.outdoors)
		// The particle holder hooks our deletion, so it needs no cleanup of ours.
		stream = new(src, /particles/transporter_stream)
	else
		icon_state = "transporter_column_short"
	// Drops in from above rather than appearing, then breathes for the rest of the
	// cycle. The loop on the second step carries through the rest of the chain.
	transform = matrix().Translate(0, 72)
	animate(src, transform = matrix(), alpha = 215, time = 0.45 SECONDS, easing = CUBIC_EASING | EASE_OUT)
	animate(alpha = 150, time = 0.7 SECONDS, loop = -1)
	animate(alpha = 215, time = 0.7 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(wind_down)), max(duration - TRANSPORTER_BEAM_WINDDOWN, 0.1 SECONDS))

/// Lifts the column back up into the sky instead of letting it blink off on expiry.
/obj/effect/temp_visual/transporter_beam/proc/wind_down()
	// Cut the stream first so no fresh motes spawn under a column that's leaving.
	if(stream?.particles)
		stream.particles.spawning = 0
	animate(src, transform = matrix().Translate(0, 72), alpha = 0, time = TRANSPORTER_BEAM_WINDDOWN, easing = CUBIC_EASING | EASE_IN)

/// The short flash at the end of a cycle, on the side something arrived at.
/obj/effect/temp_visual/transporter_flash
	name = "materialising pattern"
	icon_state = "phasein"
	duration = 0.6 SECONDS
	randomdir = FALSE
	light_range = 2
	light_power = 2
	light_color = COLOR_CYAN

/// The same, on the side something left from.
/obj/effect/temp_visual/transporter_flash/departure
	name = "dematerialising pattern"
	icon_state = "phaseout"

/**
 * Hangs the beam filters on an atom: an alpha mask that can wipe it away from the
 * top down, plus the glow and rays that sell it as light rather than fading out.
 */
/proc/transporter_apply_filters(atom/movable/target, mask_y)
	// Built once. icon() is expensive and this runs per passenger per beam.
	var/static/icon/dissolve_mask = icon('voidcrew/modules/transporter/icons/transporter_mask.dmi', "transporter_dissolve")
	target.add_filter("transporter_dissolve", 1, list(
		"type" = "alpha",
		"icon" = dissolve_mask,
		"y" = mask_y,
	))
	target.add_filter("transporter_edge", 2, list("type" = "outline", "size" = 1, "color" = "#8fe3ff"))
	target.add_filter("transporter_rays", 3, list("type" = "rays", "size" = 10, "color" = "#8fe3ff"))

/**
 * Starts taking an atom apart over the length of a beam cycle. The mask slides down
 * the sprite so the body disappears from the head down, motes come off it the whole
 * way, and what's left thins out to almost nothing by the end.
 *
 * Returns the alpha it had beforehand, so the caller can hand it back to
 * transporter_restore() whether the beam completes or aborts.
 */
/proc/transporter_dematerialise(atom/movable/target, duration)
	if(QDELETED(target))
		return 255
	. = target.alpha

	transporter_apply_filters(target, 0)
	var/dissolve = target.get_filter("transporter_dissolve")
	if(dissolve)
		animate(dissolve, y = TRANSPORTER_MASK_TRAVEL, time = duration, easing = SINE_EASING)
	// Not all the way to 0 - the mask is doing the real work, and a little left over
	// keeps the outline readable right up to the moment they go.
	animate(target, alpha = 40, time = duration, easing = SINE_EASING)

/**
 * The other half, run at the far end once the atom has actually arrived. Same
 * filters in reverse: it knits back together from the feet up.
 */
/proc/transporter_materialise(atom/movable/target, original_alpha = 255)
	if(QDELETED(target))
		return
	// Clear anything the outbound leg left on, so the filters can't stack up.
	target.remove_filter(list("transporter_dissolve", "transporter_edge", "transporter_rays"))
	transporter_apply_filters(target, TRANSPORTER_MASK_TRAVEL)

	var/dissolve = target.get_filter("transporter_dissolve")
	if(dissolve)
		animate(dissolve, y = 0, time = TRANSPORTER_MATERIALISE_TIME, easing = SINE_EASING)
	target.alpha = 40
	animate(target, alpha = original_alpha, time = TRANSPORTER_MATERIALISE_TIME, easing = SINE_EASING)

	var/obj/effect/abstract/particle_holder/motes = new(target, /particles/transporter_motes)
	QDEL_IN(motes, TRANSPORTER_MATERIALISE_TIME)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(transporter_restore), target, original_alpha), TRANSPORTER_MATERIALISE_TIME)

/// Strips every beam effect and puts the atom back to the alpha it started with.
/proc/transporter_restore(atom/movable/target, original_alpha = 255)
	if(QDELETED(target))
		return
	target.remove_filter(list("transporter_dissolve", "transporter_edge", "transporter_rays"))
	// Cancel the running alpha animation before writing the value back, or the
	// animation keeps ticking over the top of it.
	animate(target)
	target.alpha = original_alpha

/// Quantum sparks, the same set the quantum pad throws.
/proc/transporter_sparks(atom/where)
	var/turf/spark_turf = get_turf(where)
	if(!spark_turf)
		return
	var/datum/effect_system/spark_spread/quantum/sparks = new
	sparks.set_up(5, 1, spark_turf)
	sparks.start()
