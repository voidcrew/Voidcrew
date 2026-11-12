/**
 * # Outpost floors: who may build
 *
 * Owner: P13 (spec 3b.1, L29, L37). outpost_service_build_allowed() (stack recipes, the RCD, pipes, disposals, cable)
 * and the RCD's deconstruct mode ask the proc below. P13 also keeps tg's restaurant portal shut on a floor (A86).
 *
 * Stub below is P0's.
 */

/// Whether `builder` may build, bolt down, lay cable or use an RCD on `target`. Off a floor: yes. On a floor: only its
/// people and its owner's named builders, and never on the landing or the goods lift (A5, A77). Stub: TRUE.
/proc/outpost_floor_build_allowed(mob/builder, atom/target)
	return TRUE
