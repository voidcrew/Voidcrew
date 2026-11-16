// A cut throat can't speak (owner decision 45, voidcrew/modules/stealth/stealth_knife.dm). tg's neck_slice
// (code/datums/status_effects/debuffs/debuffs.dm) lasts while the throat still bleeds from a bad cut; for that long its
// owner has tg's TRAIT_MUTE, so say(), shouting and radios all fail through tg's own can_speak(). Gasps, gags, chokes and
// other emotes still show. Everyone alike: players and NPCs, however the throat was cut.

/datum/status_effect/neck_slice/on_apply()
	. = ..()
	if(.)
		ADD_TRAIT(owner, TRAIT_MUTE, TRAIT_STATUS_EFFECT(id))

/datum/status_effect/neck_slice/on_remove()
	REMOVE_TRAIT(owner, TRAIT_MUTE, TRAIT_STATUS_EFFECT(id))
	return ..()
