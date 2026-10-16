/**
 * # Ruin and loot-cache guns come ready to fire
 *
 * A gun is only a prize if the crew that finds it can pull the trigger. Two
 * upstream habits break that here:
 *
 * 1. **Keyed pins.** The C-20r, L6 SAW, Bulldog and Cybersun S-120 ship with a
 *    syndicate implant pin. Voidcrew crews have no implant to check against, so
 *    a looted one is scrap. Upstream already publishes `/unrestricted` subtypes
 *    for most of these (that is what the security vendor stocks), this file adds
 *    the one it missed.
 * 2. **Guns that ship with no pin at all.** The accelerator laser cannon and the
 *    temperature gun are R&D prints upstream, so they arrive bare and expect the
 *    printer to fit a pin. Out of a ruin cache that means a 900-credit outfitter
 *    run before the prize does anything. (The Saber SMG has the same problem and
 *    upstream already ships `/proto/unrestricted` for it, so it is not repeated
 *    here.)
 *
 * The variants below exist purely so ruin maps and loot tables have a path to
 * point at. The pin economy is untouched everywhere else: printed and bought
 * guns still need a pin fitted, and the base types keep their stock behaviour.
 */

/// Cybersun carbine as the haunted trading post leaves it, minus the implant lock.
/obj/item/gun/energy/laser/carbine/cybersun/unrestricted
	pin = /obj/item/firing_pin

/// Accelerator laser cannon, likewise.
/obj/item/gun/energy/lasercannon/unrestricted
	pin = /obj/item/firing_pin

/// Temperature gun, likewise.
/obj/item/gun/energy/temperature/unrestricted
	pin = /obj/item/firing_pin

// Incidental contraband rolls cannot bypass the guarded weapon ladder.
/obj/effect/spawner/random/contraband/armory
	loot = list(
		/obj/item/knife/combat/survival = 1,
		/obj/item/spear = 1,
		/obj/item/hatchet = 1,
		/obj/item/melee/baseball_bat = 1,
	)

/// Main entries have equal weight; theme-specific retained variants have weight one.
GLOBAL_LIST_INIT(loot_gun_pools, list(
	LOOT_GUN_POOL_ARMORY = list(
		LOOT_WEAPON_GREEN = list(
			/obj/item/gun/ballistic/rifle/boltaction/surplus = 10,
		),
		LOOT_WEAPON_YELLOW = list(
			/obj/item/gun/energy/laser = 10,
			/obj/item/gun/energy/e_gun = 10,
			/obj/item/gun/ballistic/automatic/wt550 = 10,
		),
		LOOT_WEAPON_RED = list(
			/obj/item/gun/energy/laser/carbine = 10,
			/obj/item/gun/energy/lasercannon/unrestricted = 10,
			/obj/item/gun/energy/laser/scatter = 10,
			/obj/item/gun/ballistic/rifle/sniper_rifle = 10,
			/obj/item/gun/ballistic/shotgun/automatic/combat = 10,
		),
	),
	LOOT_GUN_POOL_SYNDICATE = list(
		LOOT_WEAPON_GREEN = list(
			/obj/item/gun/ballistic/automatic/pistol = 10,
		),
		LOOT_WEAPON_YELLOW = list(
			/obj/item/gun/ballistic/automatic/c20r/unrestricted = 10,
			/obj/item/gun/ballistic/automatic/mini_uzi = 10,
		),
		LOOT_WEAPON_RED = list(
			/obj/item/gun/ballistic/automatic/l6_saw/unrestricted = 10,
			/obj/item/gun/energy/xray = 10,
			/obj/item/gun/energy/e_gun/nuclear = 10,
		),
	),
	LOOT_GUN_POOL_PLUNDER = list(
		LOOT_WEAPON_GREEN = list(
			/obj/item/gun/ballistic/revolver/c38/detective = 10,
			/obj/item/gun/ballistic/shotgun/doublebarrel = 10,
		),
		LOOT_WEAPON_YELLOW = list(
			/obj/item/gun/ballistic/revolver = 10,
			/obj/item/gun/ballistic/automatic/tommygun = 10,
		),
		LOOT_WEAPON_RED = list(
			/obj/item/gun/ballistic/shotgun/bulldog/unrestricted = 10,
			/obj/item/gun/energy/laser/hellgun = 10,
		),
	),
	LOOT_GUN_POOL_FREIGHT = list(
		LOOT_WEAPON_GREEN = list(
			/obj/item/gun/ballistic/rifle/boltaction/surplus = 10,
			/obj/item/gun/ballistic/automatic/pistol = 10,
			/obj/item/gun/ballistic/revolver/c38/detective = 10,
			/obj/item/gun/ballistic/shotgun/doublebarrel = 10,
		),
		LOOT_WEAPON_YELLOW = list(
			/obj/item/gun/ballistic/shotgun/riot = 10,
			/obj/item/gun/ballistic/automatic/tommygun = 10,
			/obj/item/gun/ballistic/automatic/mini_uzi = 10,
		),
	),
))

GLOBAL_LIST_INIT(loot_melee_pools, list(
	LOOT_WEAPON_GREEN = list(
		/obj/item/knife/combat/survival = 10,
		/obj/item/spear = 10,
		/obj/item/hatchet = 10,
		/obj/item/melee/baseball_bat = 10,
	),
	LOOT_WEAPON_YELLOW = list(
		/obj/item/knife/combat = 10,
		/obj/item/claymore/shortsword = 10,
		/obj/item/melee/baseball_bat/ablative = 10,
		/obj/item/fireaxe = 10,
		/obj/item/melee/cleric_mace = 10,
		/obj/item/melee/sabre = 10,
	),
	LOOT_WEAPON_RED = list(
		/obj/item/claymore = 10,
		/obj/item/claymore/cutlass = 10,
		/obj/item/katana = 10,
		/obj/item/mjollnir = 10,
		/obj/item/melee/energy/sword/saber = 10,
		/obj/item/melee/energy/sword/pirate = 10,
	),
))
