/**
 * # Outpost floors: quarters, workshop and canteen
 *
 * Owner: P14 (spec 3b.5, L35). Three /datum/outpost_upgrade/service subtypes, floors only, at
 * OUTPOST_FLOOR_QUARTERS_COST, OUTPOST_FLOOR_WORKSHOP_COST and OUTPOST_FLOOR_CANTEEN_COST, each with a clean and a
 * rundown map. P0 declared no type here on purpose: every /datum/outpost_upgrade subtype that sets an id joins
 * GLOB.outpost_upgrade_catalog, and one with no map would be sold as "Upgrade unavailable".
 */
