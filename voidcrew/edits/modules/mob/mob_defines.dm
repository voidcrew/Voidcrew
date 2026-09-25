// Voidcrew extensions to code/modules/mob/mob_defines.dm.

/mob
	/// Whether this mob has ever been assigned as a mind's current body.
	/// This remains TRUE after the mind leaves so formerly player-controlled bodies can still be identified.
	var/ever_had_mind = FALSE
