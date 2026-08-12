/**
 * Pirate Bounty Loot Crates
 *
 * Pre-filled crates that spawn as rewards for completing pirate bounties.
 * Light pirates drop basic weapons, heavy pirates drop premium gear.
 */

// ========== LIGHT PIRATE LOOT CRATES ==========

/// Base type for light pirate loot - basic security weapons
/obj/structure/closet/crate/secure/weapon/pirate_loot
	name = "pirate weapons cache"
	desc = "A weapons crate recovered from a pirate vessel."
	locked = FALSE

/obj/structure/closet/crate/secure/weapon/pirate_loot/lasers
	name = "pirate laser cache"
	desc = "A crate of laser weapons recovered from a pirate vessel."

// Steal-objective items have to exist before the crate is first opened, so the
// objective can track them, see the closets unit test.
/obj/structure/closet/crate/secure/weapon/pirate_loot/lasers/populate_contents_immediate()
	. = ..()
	new /obj/item/gun/energy/laser(src)
	new /obj/item/gun/energy/laser(src)
	new /obj/item/gun/energy/laser(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/disablers
	name = "pirate disabler cache"
	desc = "A crate of disabler weapons recovered from a pirate vessel."

// Same as the laser cache: steal objective, so populate before first open.
/obj/structure/closet/crate/secure/weapon/pirate_loot/disablers/populate_contents_immediate()
	. = ..()
	new /obj/item/gun/energy/disabler(src)
	new /obj/item/gun/energy/disabler(src)
	new /obj/item/gun/energy/disabler(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/armor
	name = "pirate armor cache"
	desc = "A crate of armor recovered from a pirate vessel."

/obj/structure/closet/crate/secure/weapon/pirate_loot/armor/PopulateContents()
	. = ..()
	new /obj/item/clothing/suit/armor/vest(src)
	new /obj/item/clothing/suit/armor/vest(src)
	new /obj/item/clothing/suit/armor/vest(src)
	new /obj/item/clothing/head/helmet/sec(src)
	new /obj/item/clothing/head/helmet/sec(src)
	new /obj/item/clothing/head/helmet/sec(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/batons
	name = "pirate melee cache"
	desc = "A crate of melee weapons recovered from a pirate vessel."

/obj/structure/closet/crate/secure/weapon/pirate_loot/batons/PopulateContents()
	. = ..()
	new /obj/item/melee/baton/security/loaded(src)
	new /obj/item/melee/baton/security/loaded(src)
	new /obj/item/melee/baton/security/loaded(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/supplies
	name = "pirate security supplies"
	desc = "A crate of security supplies recovered from a pirate vessel."

/obj/structure/closet/crate/secure/weapon/pirate_loot/supplies/PopulateContents()
	. = ..()
	new /obj/item/storage/box/flashbangs(src)
	new /obj/item/storage/box/teargas(src)
	new /obj/item/storage/box/flashes(src)
	new /obj/item/storage/box/handcuffs(src)

// ========== HEAVY PIRATE LOOT CRATES ==========

/// Base type for heavy pirate loot - premium military weapons
/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy
	name = "pirate heavy weapons cache"
	desc = "A cache of heavy weapons recovered from a dangerous pirate vessel."

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/energy_guns
	name = "pirate energy gun cache"
	desc = "A crate of high-end energy guns recovered from a pirate vessel."

// Same as the laser cache: steal objective, so populate before first open.
/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/energy_guns/populate_contents_immediate()
	. = ..()
	new /obj/item/gun/energy/e_gun(src)
	new /obj/item/gun/energy/e_gun(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/combat_shotguns
	name = "pirate combat shotgun cache"
	desc = "A crate of combat shotguns recovered from a pirate vessel."

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/combat_shotguns/PopulateContents()
	. = ..()
	new /obj/item/gun/ballistic/shotgun/automatic/combat(src)
	new /obj/item/gun/ballistic/shotgun/automatic/combat(src)
	new /obj/item/gun/ballistic/shotgun/automatic/combat(src)
	new /obj/item/storage/belt/bandolier(src)
	new /obj/item/storage/belt/bandolier(src)
	new /obj/item/storage/belt/bandolier(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/laser_carbines
	name = "pirate laser carbine cache"
	desc = "A crate of laser carbines recovered from a pirate vessel."

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/laser_carbines/PopulateContents()
	. = ..()
	new /obj/item/gun/energy/laser/carbine(src)
	new /obj/item/gun/energy/laser/carbine(src)
	new /obj/item/gun/energy/laser/carbine(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/swat
	name = "pirate tactical gear cache"
	desc = "A crate of tactical SWAT gear recovered from a pirate vessel."

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/swat/PopulateContents()
	. = ..()
	new /obj/item/clothing/head/helmet/swat/nanotrasen(src)
	new /obj/item/clothing/head/helmet/swat/nanotrasen(src)
	new /obj/item/clothing/suit/armor/swat(src)
	new /obj/item/clothing/suit/armor/swat(src)
	new /obj/item/clothing/mask/gas/sechailer/swat(src)
	new /obj/item/clothing/mask/gas/sechailer/swat(src)
	new /obj/item/clothing/gloves/tackler/combat(src)
	new /obj/item/clothing/gloves/tackler/combat(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/riot
	name = "pirate riot gear cache"
	desc = "A crate of riot control gear recovered from a pirate vessel."

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/riot/PopulateContents()
	. = ..()
	new /obj/item/clothing/suit/armor/riot(src)
	new /obj/item/clothing/suit/armor/riot(src)
	new /obj/item/clothing/head/helmet/toggleable/riot(src)
	new /obj/item/clothing/head/helmet/toggleable/riot(src)
	new /obj/item/shield/riot(src)
	new /obj/item/shield/riot(src)

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/incendiary
	name = "pirate incendiary cache"
	desc = "A crate of incendiary weapons recovered from a pirate vessel. Handle with care."

/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/incendiary/PopulateContents()
	. = ..()
	new /obj/item/flamethrower/full(src)
	new /obj/item/tank/internals/plasma(src)
	new /obj/item/tank/internals/plasma(src)
	new /obj/item/tank/internals/plasma(src)
	new /obj/item/grenade/chem_grenade/incendiary(src)
	new /obj/item/grenade/chem_grenade/incendiary(src)
	new /obj/item/grenade/chem_grenade/incendiary(src)
