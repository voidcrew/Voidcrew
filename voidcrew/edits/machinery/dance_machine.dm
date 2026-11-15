/// How far from a dance machine a player can stand and still be made to dance.
#define DANCE_FLOOR_RANGE 3

/**
 * Runs the light show in the background.
 *
 * Upstream activate_music() calls lights_spin() and only then begin_processing().
 * lights_spin() loops until the song ends, so nobody danced during the first song,
 * and processing was switched on after every song ended and left running while idle.
 */
/obj/machinery/jukebox/disco/lights_spin()
	set waitfor = FALSE
	..()

/**
 * Only players on the dance floor dance, and not while fighting, cuffed or held.
 *
 * Upstream makes every listener in earshot dance, about twelve tiles out. That
 * spins and floors anyone shopping near a dance machine that's playing.
 * Replaces the upstream proc.
 */
/obj/machinery/jukebox/disco/process()
	var/dance_num = rand(1, 4) //all will do the same dance
	for(var/mob/living/dancer in music_player.get_active_listeners())
		if(get_dist(dancer, src) > DANCE_FLOOR_RANGE)
			continue
		if(!(dancer.mobility_flags & MOBILITY_MOVE))
			continue
		// Nobody dances mid-fight, in cuffs, or while being dragged or held.
		if(dancer.combat_mode || HAS_TRAIT(dancer, TRAIT_RESTRAINED) || dancer.pulledby || dancer.buckled)
			continue
		if(HAS_TRAIT(dancer, TRAIT_DISCO_DANCER))
			continue
		dance(dancer, dance_num)

#undef DANCE_FLOOR_RANGE
