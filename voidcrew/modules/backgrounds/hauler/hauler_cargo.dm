/// Backgrounds: owned by P5. See data/backgrounds/spec.md.

/obj/effect/landmark/hauler

/obj/effect/landmark/hauler/cargo
	name = "hauler cargo"

/obj/effect/landmark/hauler/crew
	name = "hauler crew"

/// Marks one case on a live hauler for this Hijack and returns it, or null
/proc/hauler_mark_case(datum/mission/criminal/hijack/mission)
	return null
