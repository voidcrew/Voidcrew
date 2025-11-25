/**
 * Voidcrew Player Shop - Preferences Extension
 *
 * Adds inventory tracking to the preferences datum
 * This stores which shop items the player has purchased
 */

/datum/preferences
	/// List of all purchased shop items (typepaths)
	/// Permanent unlocks that persist across rounds
	var/list/inventory = list()
