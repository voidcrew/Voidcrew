/**
 * Planet anomalies.
 *
 * Anomalies used to arrive as a ship-scoped dynamic event: one materialised inside the
 * hull, the crew got an area name, and then they lived with it in their own corridors
 * until it timed out. There was no version of that a crew could play well, a shuttle
 * has one route between compartments, so "avoid the gravitational anomaly" and "reach
 * engineering" were frequently the same tile.
 *
 * The same object on open planet ground is the opposite proposition. It is stationary,
 * it is lit and visible from well outside its own reach, and nothing brought it to the
 * crew, the crew walked to it. Standing next to one is a decision, and a crew that
 * researched Anomaly Research (tier 3) and printed a neutralizer turns that decision
 * into an anomaly core.
 *
 * These are the ONLY anomalies that spawn naturally. The ship-scoped controls in
 * voidcrew/modules/dynamic_events/events/anomalies.dm are all weight 0 / admin-only.
 *
 * Two properties separate a planet anomaly from its parent:
 *
 * - `immortal`: planets are prebuilt in the lobby and released minutes into the round,
 *   so a normal ANOMALY_COUNTDOWN_TIMER anomaly would detonate and vanish long before
 *   anybody could land and look at it. Immortal also suppresses detonate(), which is
 *   correct here: the payoff for finding one is the core, not the explosion.
 * - `move_chance = 0`: a wandering hazard cannot be routed around, and one that drifts
 *   into a landing site turns a considered approach into an ambush. Planet anomalies
 *   stay where the generator put them.
 */

/**
 * Weighted table of anomaly types a planet may seed.
 *
 * Deliberately not the full anomaly roster. Excluded, and why:
 *
 * - bioscrambler: swapped limbs need surgery, so the injury outlives the trip home.
 * - vortex: eats what it reaches, and there is nothing to do about it but not be there.
 * - dimensional: rewrites surrounding turfs into a themed set, which on generated
 *   terrain carves a chunk of somebody's station out of the landscape.
 * - pyroclastic: dumps 1000K plasma into open air every few seconds. On a planet with
 *   planetary_atmos that is a fire with a whole biome to spread through.
 * - ectoplasm: scales off orbiting ghost count, which has nothing to do with the planet.
 */
GLOBAL_LIST_INIT(voidcrew_planet_anomalies, list(
	/obj/effect/anomaly/flux/planetary = 30,
	/obj/effect/anomaly/grav/planetary = 30,
	/obj/effect/anomaly/hallucination/planetary = 25,
	/obj/effect/anomaly/bluespace/planetary = 15,
))

/// Dense, and shocks whatever touches it. The clearest of the four: it does nothing at
/// all until something makes contact with it.
/obj/effect/anomaly/flux/planetary
	immortal = TRUE
	move_chance = 0

/// Pulls loose objects and unsecured people in from a few tiles out. The one with reach,
/// so it reads as a hazard at a distance rather than a trap.
/obj/effect/anomaly/grav/planetary
	immortal = TRUE
	move_chance = 0

/**
 * Pulses hallucinations at anyone within a few tiles. Harmless in the sense that matters
 * here: it does no damage and leaves nothing behind once the crew walks away.
 *
 * Decoys are off. On a station they are a science minigame. Scan the cluster, find the
 * one that answers. On a planet they would be three extra processing objects and three
 * extra ghost points of interest per anomaly, sitting on a z-level that is prebuilt and
 * then left alone for most of the round, in service of a puzzle nobody came here to do.
 */
/obj/effect/anomaly/hallucination/planetary
	immortal = TRUE
	move_chance = 0
	spawn_decoys = FALSE

/// Dense, and throws whatever touches it a short distance. Planets are a single cordoned
/// z-level, so it can only ever relocate somebody within the same landmass.
/obj/effect/anomaly/bluespace/planetary
	immortal = TRUE
	move_chance = 0
