// Voidcrew extensions to code/modules/error_handler/error_viewer.dm.

/datum/error_viewer/error_source
	/// VOIDCREW ADDITION: every runtime this source has produced, retained or not.
	var/total_errors = 0
	/// VOIDCREW ADDITION: how many of those were counted but not kept as a full entry.
	var/dropped_errors = 0
