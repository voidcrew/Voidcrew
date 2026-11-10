/**
 * # Outpost checkpoints turning back loose finds
 *
 * A large find comes into a trader outpost crated, or not at all. The scan chamber
 * (voidcrew/modules/trade/outpost_checkpoint.dm) refuses an artifact standing loose on its floor
 * the way it refuses a gun on the floor: the inner door stays shut, the guard (or the wall
 * scanner) says so, and the outer door waits until the find has been taken back out. A find in
 * any shut crate, or carried in an exosuit, passes. Leaving through an exterior hatch is never
 * refused for a find.
 *
 * Inside, a find does nothing anyway (the outpost holds it still); this keeps one from being
 * dragged through the crowd at the door and gives the guards something to say about it.
 */

/// The refusal category for a loose find: a refused[] value and a line key for guards and scanners
#define XENOARCH_CHECKPOINT_LINE_LOOSE "xenoarch_loose_find"

/datum/outpost_checkpoint/inspect_chamber()
	var/list/refused = ..()
	if(exit_request)
		return refused
	for(var/turf/tile as anything in chamber_turfs)
		for(var/obj/machinery/artifact/find in tile)
			if(!refused[find])
				refused[find] = XENOARCH_CHECKPOINT_LINE_LOOSE
	return refused

/// Whether everything the chamber refuses right now is a loose find.
/datum/outpost_checkpoint/proc/refusing_only_loose_finds()
	var/list/refused = inspect_chamber()
	if(!length(refused))
		return FALSE
	for(var/atom/movable/thing as anything in refused)
		if(refused[thing] != XENOARCH_CHECKPOINT_LINE_LOOSE)
			return FALSE
	return TRUE

// A refusal is announced as "armed"; when the only thing refused is a loose find, say that instead.
/datum/outpost_checkpoint/announce(category, urgent = FALSE)
	if(category == CHECKPOINT_LINE_ARMED && state == CHECKPOINT_REJECTING && refusing_only_loose_finds())
		category = XENOARCH_CHECKPOINT_LINE_LOOSE
	return ..(category, urgent)

/obj/machinery/outpost_checkpoint_sensor/machine_line(category)
	if(category == XENOARCH_CHECKPOINT_LINE_LOOSE)
		return "Uncontained specimen."
	return ..()

/datum/outpost_shop/vendor/checkpoint
	/// What this guard says to someone pulling a find in loose
	var/list/xenoarch_loose_lines = list(
		"Crate it first.",
	)

/datum/outpost_shop/vendor/checkpoint/get_line(category)
	if(category == XENOARCH_CHECKPOINT_LINE_LOOSE)
		return length(xenoarch_loose_lines) ? pick(xenoarch_loose_lines) : null
	return ..()

/datum/outpost_shop/vendor/checkpoint/halcyon
	xenoarch_loose_lines = list(
		"Crate it first, please. That doesn't come in loose.",
		"Whatever that is, it goes in a crate before it comes past me.",
	)

/datum/outpost_shop/vendor/checkpoint/quartermain
	xenoarch_loose_lines = list(
		"Crate it first.",
		"Not loose. Box it and come back.",
	)

/datum/outpost_shop/vendor/checkpoint/undertow
	xenoarch_loose_lines = list(
		"Crate it.",
		"Loose rocks stay outside.",
	)

#undef XENOARCH_CHECKPOINT_LINE_LOOSE
