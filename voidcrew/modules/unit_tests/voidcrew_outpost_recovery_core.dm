/**
 * Outpost recovery tests: spec-rehydrate.md 2 and 4. Owner: R2.
 *
 * To write: the recovery state table row by row with pinned times, the 4.2 ladder, and the body cap (removes the oldest NPC body, never a player). Also R0's link_rooms() (R5's acceptance: one morgue landmark with four trays and one closet landmark on a loaded outpost).
 *
 * Defines are included after the tests: write values out with a comment naming the define (OUTPOST_TRADER_MOB is
 * /mob/living/basic/outpost_trader until R1 renames it). Police helpers: voidcrew_outpost_police_helpers.dm.
 * Tests are written, not run, by the package; the lead runs them once at integration.
 */
