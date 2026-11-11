/**
 * Outpost recovery tests: spec-rehydrate.md 1. Owner: R1.
 *
 * To write: every purchase path refuses with the keeper dead and works again with a replacement at the counter; a first keeper drops one item at or under 750 cr and its SKU's stock falls by one; a drop past the 1 500 cr outpost cap does not happen; a replacement drops nothing; a guard's death leaves the checkpoint scanning; KILL_STAFF floors at 4 stars.
 *
 * Defines are included after the tests: write values out with a comment naming the define (OUTPOST_TRADER_MOB is
 * /mob/living/carbon/human/npc/ambient_npc/outpost/trader until R1 renames it). Police helpers: voidcrew_outpost_police_helpers.dm.
 * Tests are written, not run, by the package; the lead runs them once at integration.
 */
