#define ALLOWED_LOOSE_TURFS 100
/**
 * Responsible for managing the sizes of area.contained_turfs and area.turfs_to_uncontain
 * These lists do not check for duplicates, which is fine, but it also means they can balloon in size over time
 * as a consequence of repeated changes in area in a space
 * They additionally may not always resolve often enough to avoid memory leaks
 * This is annoying, so lets keep an eye on them and cut them down to size if needed
 */
SUBSYSTEM_DEF(area_contents)
	name = "Area Contents"
	ss_flags = SS_NO_INIT
	runlevels = RUNLEVEL_LOBBY|RUNLEVELS_DEFAULT
	var/list/currentrun
	var/list/area/marked_for_clearing = list()

/datum/controller/subsystem/area_contents/stat_entry(msg)
	var/total_clearing_from = 0
	var/total_to_clear = 0
	for(var/area/to_clear as anything in marked_for_clearing)
		for (var/area_zlevel in 1 to length(to_clear.turfs_to_uncontain_by_zlevel))
			if (length(to_clear.turfs_to_uncontain_by_zlevel[area_zlevel]))
				total_to_clear += length(to_clear.turfs_to_uncontain_by_zlevel[area_zlevel])
				if (length(to_clear.turfs_by_zlevel) >= area_zlevel) //this should always be true, but stat_entry is no place for runtimes. fire() can handle that
					total_clearing_from += length(to_clear.turfs_by_zlevel[area_zlevel])
	msg = "\n  A:[length(currentrun)] MR:[length(marked_for_clearing)] TC:[total_to_clear] CF:[total_clearing_from]"
	return ..()


/datum/controller/subsystem/area_contents/fire(resumed)
	if(!resumed)
		currentrun = GLOB.areas.Copy()

	while(length(currentrun))
		var/area/test = currentrun[length(currentrun)]
		// A destroyed area has both bookkeeping lists nulled, so there is nothing to mark and
		// marking it would only pin the corpse until the next drain.
		if(!QDELETED(test))
			for (var/area_zlevel in 1 to length(test.turfs_to_uncontain_by_zlevel))
				if(length(test.turfs_to_uncontain_by_zlevel[area_zlevel]) > ALLOWED_LOOSE_TURFS)
					marked_for_clearing |= test
					break
		currentrun.len--
		if(MC_TICK_CHECK)
			return

	// Alright, if we've done a scan on all our areas, it's time to knock the existing ones down to size
	while(length(marked_for_clearing))
		var/area/clear = marked_for_clearing[length(marked_for_clearing)]
		// Marked during the scan, died before the drain reached it. /area/Destroy() nulls
		// turfs_to_uncontain_by_zlevel, so every length() below would read 0 anyway - drop it
		// rather than leaving a dead area sitting at the end of the list.
		if(QDELETED(clear) || isnull(clear.turfs_to_uncontain_by_zlevel))
			marked_for_clearing.len--
			if(MC_TICK_CHECK)
				return
			continue

		for (var/area_zlevel in 1 to length(clear.turfs_to_uncontain_by_zlevel))
			if (!length(clear.turfs_to_uncontain_by_zlevel[area_zlevel]))
				continue
			if (length(clear.turfs_by_zlevel) < area_zlevel)
				stack_trace("[clear]([clear.type])'s turfs_by_zlevel is length [length(clear.turfs_by_zlevel)] but we are being asked to remove turfs from zlevel [area_zlevel] from it.")
				clear.turfs_to_uncontain_by_zlevel[area_zlevel] = list()
				continue

			// VOIDCREW EDIT REPLACEMENT START - drain a whole z-level per pass, through the
			// counted-occurrence rebuild in cannonize_contained_turfs_by_zlevel().
			//
			// This used to cut one entry at a time with `turfs_by_zlevel[z] -= cut_from[i]`,
			// on the theory that a per-entry cut yields more smoothly than a batch. It does,
			// but each of those cuts is a full O(N) rescan of a list the area doc itself calls
			// HUGE - on /area/space that is ~65,000 entries. Draining one packed level's
			// teardown (~121,000 loose turfs) that way is ~10^11 comparisons, so the drain
			// made a few hundred cuts per fire and lost the race permanently. Both lists then
			// grew by a whole footprint every build/teardown cycle, which is where the soak's
			// unexplained ~116 MB/h of retained memory lived: list CONTENTS, not instances.
			//
			// The rebuild is O(contained + cut) and must not be split, because a partially
			// rebuilt list plus a concurrent change_area() append is corruption. One z-level
			// is therefore the atomic unit: the tick check runs BEFORE it so the pass starts
			// with a full budget rather than the tail of someone else's.
			//
			// It also has to be _autoclean = FALSE and per-z. The old code emptied the WHOLE
			// cut list in one assignment after the z loop - and change_area() appends to that
			// same list during every MC_TICK_CHECK yield taken above it, so any entry that
			// landed mid-drain was thrown away without ever being applied. The turf stayed in
			// turfs_by_zlevel forever with nothing left to remove it: a permanent phantom
			// occupant, and the reason has_contained_turfs() could not be trusted (see
			// has_resident_turfs() in areas.dm). cannonize_contained_turfs_by_zlevel() clears
			// only the z it just applied, inside the same unyielding call, so there is no
			// window for an append to be lost.
			if(MC_TICK_CHECK)
				return
			clear.cannonize_contained_turfs_by_zlevel(area_zlevel, _autoclean = FALSE)
			// VOIDCREW EDIT REPLACEMENT END

		// VOIDCREW EDIT ADDITION - trim the trailing empty z lists off the cut list.
		// `_autoclean = FALSE` above is mandatory: the autoclean tail shortens this very list,
		// and the `1 to length()` bound above is snapshotted, so letting it run mid-loop would
		// index off the end. The trim has to happen somewhere though - get_zlevel_turf_lists()
		// decides whether to cannonize at all from `length(turfs_to_uncontain_by_zlevel)`, and
		// it is called on hot paths (APC power, lighting, get_turfs_from_all_zlevels). Leaving
		// a full-length list of empty lists behind would make every one of those calls walk
		// every z for nothing. Only trailing empties are dropped, so nothing pending is lost.
		clear.trim_trailing_empty_uncontain_lists()

		marked_for_clearing.len--

#undef ALLOWED_LOOSE_TURFS
