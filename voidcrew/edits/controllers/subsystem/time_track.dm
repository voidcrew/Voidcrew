// Voidcrew extensions to code/controllers/subsystem/time_track.dm.

/// Total number of datums sitting in SSgarbage's collection queues. A climbing
/// value means qdel'd objects are piling up faster than they resolve.
/datum/controller/subsystem/time_track/proc/gc_queue_depth()
	. = 0
	for(var/list/queue in SSgarbage.queues)
		. += length(queue)
