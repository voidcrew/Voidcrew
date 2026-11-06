/// Backgrounds: owned by P1. See data/backgrounds/spec.md.

/datum/map_template/shuttle/voidcrew
	/// The background this hull is the start of (a BACKGROUND_* key). Keeps it off the shelf and out of the roundstart roll.
	var/background_start

/obj/structure/overmap/ship
	/// Set when the hull is abandoned: it stops being a background hull and is ordinary salvage
	var/background_cleared = FALSE

/// Background key -> background hulls minted this round, destroyed ones included
GLOBAL_LIST_EMPTY(background_hulls_minted)

/// The background this hull starts, or null
/obj/structure/overmap/ship/proc/background_key()
	return background_cleared ? null : source_template?.background_start

/// Whether another hull of this background may be minted this round
/proc/background_hull_available(key)
	return TRUE
