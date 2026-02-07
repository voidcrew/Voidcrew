/**
 * Pirate Ship Equipment
 *
 * Turrets and other equipment used on NPC pirate ships.
 */

// ==================== PIRATE TURRETS ====================

/// Pirate ballistic turret - fires bullets
/obj/machinery/porta_turret/syndicate/pirate
	name = "pirate turret"
	desc = "A ballistic machine gun turret used by pirates."
	faction = list(FACTION_PIRATE)

/// Pirate energy turret - fires lasers
/obj/machinery/porta_turret/syndicate/energy/pirate
	name = "pirate laser turret"
	desc = "An energy blaster turret used by pirates."
	faction = list(FACTION_PIRATE)
