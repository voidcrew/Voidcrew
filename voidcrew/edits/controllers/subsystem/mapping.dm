// Voidcrew extensions to code/controllers/subsystem/mapping.dm.

/datum/controller/subsystem/mapping
	/// Whether we have already reported a reservation turf found sitting in a destroyed area.
	var/warned_about_dead_reservation_area = FALSE
	/// off and which still have to be taken out of GLOB.starlight. Assoc turf -> TRUE so the
	/// compaction below is a membership test rather than a search. See release_reservation_starlight().
	var/list/starlight_release_queue
	/// Rate limit for reconcile_used_turfs(), which walks all of used_turfs.
	var/next_used_turf_reconcile = 0
