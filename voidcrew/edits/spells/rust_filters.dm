// VOIDCREW EDIT START: Independent cosmetic expiry must not affect a later cast on this turf. - Voidcrew rust spell integration: expire only the filter owned by this cast (voidcrew/edits/spells)
/proc/fade_rust_wall_filter(turf/closed/wall, list/owned_filter, fade_duration)
	if(QDELETED(wall) || LAZYACCESS(wall.filter_data, "rust_wall") != owned_filter)
		return

	var/rust_filter = wall.get_filter("rust_wall")
	if(!rust_filter)
		return

	animate(rust_filter, alpha = 0, time = fade_duration)

/proc/remove_rust_wall_filter(turf/closed/wall, list/owned_filter)
	if(QDELETED(wall) || LAZYACCESS(wall.filter_data, "rust_wall") != owned_filter)
		return

	wall.remove_filter("rust_wall")
// END VOIDCREW EDIT
