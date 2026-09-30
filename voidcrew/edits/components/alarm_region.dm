/datum/alarm_listener
	/// Voidcrew: weakref to the atom whose map region scopes a z-scoped
	/// listener, or null for "z granularity only" (the upstream behaviour). Set by
	/// /datum/station_alert/New(); see the comment there.
	var/datum/weakref/region_anchor_ref
