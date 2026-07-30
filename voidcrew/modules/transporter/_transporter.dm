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

/**
 * The column of light that stands on a turf for the whole length of a beam cycle.
 * Spawned at both ends, so the people being left behind and the people about to be
 * landed on both get a few seconds of warning.
 */
/obj/effect/temp_visual/transporter_beam
	name = "transporter beam"
	desc = "A column of shimmering bluespace light."
	icon_state = "bluestream"
	randomdir = FALSE
	layer = ABOVE_MOB_LAYER
	alpha = 0
	light_range = 3
	light_power = 2
	light_color = COLOR_CYAN
	duration = TRANSPORTER_BASE_BEAM_TIME

/obj/effect/temp_visual/transporter_beam/Initialize(mapload, beam_duration)
	if(beam_duration)
		duration = beam_duration
	. = ..()
	animate(src, alpha = 200, time = 0.6 SECONDS, loop = -1)
	animate(alpha = 110, time = 0.6 SECONDS)

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
 * Puts the dematerialisation shimmer on an atom for the length of a beam cycle.
 * Returns the alpha it had beforehand, so the caller can hand it back to
 * transporter_shimmer_stop() whether the beam completes or aborts.
 */
/proc/transporter_shimmer_start(atom/movable/target, duration)
	if(QDELETED(target))
		return 255
	. = target.alpha
	target.add_filter("transporter_shimmer", 2, list("type" = "rays", "size" = 12, "color" = "#8fe3ff"))
	target.add_filter("transporter_edge", 3, list("type" = "outline", "size" = 1, "color" = "#8fe3ff"))
	animate(target, alpha = 60, time = duration, easing = SINE_EASING)

/// Clears the shimmer and puts the atom back to the alpha it had before the beam.
/proc/transporter_shimmer_stop(atom/movable/target, original_alpha = 255)
	if(QDELETED(target))
		return
	target.remove_filter(list("transporter_shimmer", "transporter_edge"))
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
