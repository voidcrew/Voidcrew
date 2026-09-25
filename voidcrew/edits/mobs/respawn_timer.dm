/**
 * Keeps the respawn delay counting from the death itself.
 *
 * Upstream ghostize() writes the body's timeofdeath onto the persistent client every time a
 * player leaves their corpse. Stasis (stasis beds, Winterkiss, legion cores, ...) pushes a
 * corpse's timeofdeath forward for as long as it holds the body, because that value also drives
 * defib and decay windows. So a player who re-entered their body on a stasis bed and ghosted
 * again had the respawn countdown pushed back by the whole stasis time, and lost a Neutral Zone
 * waiver along with it (see green_zone_respawn.dm).
 *
 * The body remembers when it actually died. Ghosting out of a body that is still dead from
 * that death puts the real time back. Being revived and dying again records a new death, and
 * ghosting out of a living body (or observing from the lobby) is left as upstream has it.
 */
/mob/living
	/// world.time this mob last became dead. Unlike timeofdeath, stasis never moves it.
	var/respawn_death_time = 0

/mob/living/set_stat(new_stat)
	. = ..()
	if(!isnull(.) && . != DEAD && stat == DEAD)
		respawn_death_time = world.time

/mob/living/ghostize(can_reenter_corpse = TRUE, admin_ghost = FALSE)
	//The player's persistent client follows them into the ghost, so grab it while it is ours.
	var/datum/persistent_client/player = persistent_client
	. = ..()
	if(!. || !player || stat != DEAD || !respawn_death_time)
		return
	player.time_of_death = respawn_death_time
