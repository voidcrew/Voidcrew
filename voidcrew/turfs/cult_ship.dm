/**
 * Ship-safe runed metal
 *
 * The Delta's cult refit is scenery. Nobody aboard is a cultist, nothing here
 * joins a cult team, and the stock turfs work fine for a normal crew - the
 * engraving is drawn by /obj/effect/cult_turf, which has no visibility gate.
 *
 * What the stock turfs also do is announce themselves with a conversion
 * flourish (/obj/effect/temp_visual/cult/turf) in Initialize(). A shuttle
 * re-initialises every one of its turfs each time it docks, so a hull built
 * from stock runed metal replays that flourish across ~190 tiles on every
 * single move. These subtypes are the parents in every other respect; they
 * just drop the flourish.
 */
/turf/closed/wall/mineral/cult/ship

/turf/closed/wall/mineral/cult/ship/Initialize(mapload)
	. = ..()
	// The parent spawned its flourish into us before returning. Bin it.
	for(var/obj/effect/temp_visual/cult/turf/flourish in src)
		qdel(flourish)

/turf/open/floor/engine/cult/ship

/turf/open/floor/engine/cult/ship/Initialize(mapload)
	. = ..()
	for(var/obj/effect/temp_visual/cult/turf/flourish in src)
		qdel(flourish)
