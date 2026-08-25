/// Debug census of SSair.active_turfs: bins by z-level and by turf type, with a sample
/// coordinate + area for each type so offenders can be jumped to directly.
/// Run in-game via Debug -> Advanced ProcCall -> GLOBAL PROC -> audit_active_turfs.
/// Output goes to the caller's chat and game log; safe to run mid-round (read-only).
/proc/audit_active_turfs()
	var/list/count_by_z = list()
	var/list/count_by_type = list()
	var/list/sample_by_type = list()
	var/planetary_count = 0

	for(var/turf/open/active as anything in SSair.active_turfs)
		count_by_z["[active.z]"] += 1
		count_by_type[active.type] += 1
		if(active.planetary_atmos)
			planetary_count += 1
		if(!sample_by_type[active.type])
			var/area/sample_area = get_area(active)
			sample_by_type[active.type] = "([active.x],[active.y],[active.z]) in [sample_area ? sample_area.name : "null area"]"

	var/list/out = list()
	out += "ACTIVE TURF AUDIT: [length(SSair.active_turfs)] active, [planetary_count] of them planetary_atmos"

	out += "By z-level:"
	for(var/z_key in count_by_z)
		out += "  z[z_key]: [count_by_z[z_key]]"

	out += "By type (sample coordinate + area):"
	// selection sort by count, descending. Type list is small
	var/list/remaining = count_by_type.Copy()
	while(length(remaining))
		var/best_type
		var/best_count = -1
		for(var/turf_type in remaining)
			if(remaining[turf_type] > best_count)
				best_type = turf_type
				best_count = remaining[turf_type]
		out += "  [best_count]x [best_type], [sample_by_type[best_type]]"
		remaining -= best_type

	var/msg = out.Join("\n")
	log_admin("ACTIVE TURF AUDIT:\n[msg]")
	if(usr)
		to_chat(usr, span_adminnotice("<pre>[msg]</pre>"))
	return "[length(SSair.active_turfs)] active turfs, breakdown sent to chat + admin log"
