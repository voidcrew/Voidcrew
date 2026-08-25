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

/// Cybersun S-120 as the haunted trading post leaves it, minus the implant lock.
/// (Upstream reparented it out from under /laser/carbine during the 2026 merge.)
/obj/item/gun/energy/laser/cybersun/unrestricted
	pin = /obj/item/firing_pin

/// Accelerator laser cannon, likewise.
/obj/item/gun/energy/lasercannon/unrestricted
	pin = /obj/item/firing_pin

/// Temperature gun, likewise.
/obj/item/gun/energy/temperature/unrestricted
	pin = /obj/item/firing_pin

/**
 * The armory contraband spawner is scattered through a dozen ruins, and its two
 * `/contraband` pistols roll a 1-in-10 clown pin on spawn: usually a gun the
 * finder simply cannot fire, and on the super-ultra roll one that detonates in
 * their hands. Same guns, same odds, without the coin flip.
 */
/obj/effect/spawner/random/contraband/armory
	loot = list(
		/obj/item/gun/ballistic/automatic/pistol = 80,
		/obj/item/gun/ballistic/shotgun/automatic/combat = 50,
		/obj/item/storage/box/syndie_kit/throwing_weapons = 30,
		/obj/item/grenade/clusterbuster/teargas = 20,
		/obj/item/grenade/clusterbuster = 20,
		/obj/item/gun/ballistic/automatic/pistol/deagle,
		/obj/item/gun/ballistic/revolver/mateba = 9,
		/obj/item/gun/ballistic/revolver/reverse/mateba = 1,
	)
