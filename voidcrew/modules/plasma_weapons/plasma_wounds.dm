// Plasma burns: a wound series for plasma bolts. Seam stubs; the wound core fills these in.

/// TRUE when a damage source should roll the plasma burn series instead of tg's burns.
/proc/plasma_burn_source(source)
	return FALSE

/// TRUE if the limb carries a critical burn that counts as burned through.
/proc/plasma_limb_burned_through(obj/item/bodypart/limb)
	return !!limb?.get_wound_type(/datum/wound/burn/flesh/critical)

/// TRUE if the limb is ready for the rifle's burn-through melt.
/proc/plasma_burn_through_ready(obj/item/bodypart/limb)
	return !!limb?.get_wound_type(/datum/wound/burn/flesh/critical)

/datum/wound/burn/flesh/plasma
	/// Slag still in the wound
	var/slag = 0
	/// Seconds of heat left
	var/heat = 0
	/// Healing held back while slag is in
	var/stored_healing = 0

/// Takes slag out; handles the slag reaching zero.
/datum/wound/burn/flesh/plasma/proc/remove_slag(amount, mob/user)
	return

/// Cools the wound at once.
/datum/wound/burn/flesh/plasma/proc/quench(silent = FALSE)
	return

/// Returns "hot", "set" or "raw".
/datum/wound/burn/flesh/plasma/proc/look_state()
	return "raw"
