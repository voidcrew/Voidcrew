// Voidcrew extensions to code/modules/experisci/experiment/types/scanning_fish.dm.

/**
 * The scanned list is shared between every fish experiment of a techweb, so the tally keeps climbing
 * past the requirement of the ones already done. Clamp it so a completed experiment doesn't read "8/7".
 */
/datum/experiment/scanning/fish/serialize_progress_stage(atom/target, list/seen_instances)
	var/required = required_atoms[target]
	return EXPERIMENT_PROG_INT(scan_message, min(length(seen_instances), required), required)
