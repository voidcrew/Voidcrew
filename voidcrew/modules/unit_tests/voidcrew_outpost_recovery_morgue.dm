/**
 * Outpost recovery tests: spec-rehydrate.md 3.1. Owner: R3.
 *
 * To write: a worker bags a dead NPC and the bag is gone after the ride; a dead player ends in a tray, still exists and keeps every item; a body with a conscious player within 2 tiles is skipped; a living mob is never bagged (M32).
 *
 * Defines are included after the tests: write values out with a comment naming the define (OUTPOST_TRADER_MOB is
 * /mob/living/basic/outpost_trader until R1 renames it). Police helpers: voidcrew_outpost_police_helpers.dm.
 * Tests are written, not run, by the package; the lead runs them once at integration.
 */
