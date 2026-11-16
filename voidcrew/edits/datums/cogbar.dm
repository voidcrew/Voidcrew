// A cogbar takes away only its own cog. tg's Destroy() removes every managed vis overlay on the user, and a cog
// fades for half a second before it is deleted, so a do_after started within that half second (picking plasma
// slag one bead after another, voidcrew/modules/plasma_weapons/plasma_wound_care.dm) lost its cog to the old one's
// cleanup and other players saw no cog for the rest of the work.
/datum/cogbar/Destroy()
	if(user)
		if(cog)
			SSvis_overlays.remove_vis_overlay(user, list(cog))
		user_client?.images -= blank
	// tg's Destroy() then skips its own removal and clears the rest
	user = null
	return ..()
