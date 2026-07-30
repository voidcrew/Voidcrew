/// Removes all the loot and achievements from megafauna for bitrunning related
/mob/living/simple_animal/hostile/megafauna/proc/make_virtual_megafauna()
	var/new_max = clamp(maxHealth * 0.5, 600, 1300)
	maxHealth = new_max
	health = new_max

	true_spawn = FALSE

	// true_spawn gates the GPS component, but that is read in Initialize() and we run
	// well after it, so the component is already attached by the time we get here. Left
	// alone, every megafauna domain broadcasts a lavaland signal out of the turf
	// reservation to anyone holding a GPS.
	var/datum/component/gps/beacon = GetComponent(/datum/component/gps)
	if(beacon)
		qdel(beacon)

	loot.Cut()
	loot += /obj/structure/closet/crate/secure/bitrunning/encrypted

	crusher_loot.Cut()
	crusher_loot += /obj/structure/closet/crate/secure/bitrunning/encrypted
