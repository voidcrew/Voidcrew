/**
 * Outpost recovery tests: spec-rehydrate.md 9 and 10. Owner: R7.
 *
 * To write: the gate emag (the scanner sets the end time and both doors answer a bump; a barred mob with a gun crosses; the gate scans again at the end time; a second emag inside 5 min does nothing; a conscious guard gives the emagger 2 stars and the emag is evidence; with the guard dead and no witness nobody has stars) and the stick-up (spec 10, M37, M38, M40).
 *
 * Defines are included after the tests: write values out with a comment naming the define (OUTPOST_TRADER_MOB is
 * /mob/living/basic/outpost_trader until R1 renames it). Police helpers: voidcrew_outpost_police_helpers.dm.
 * Tests are written, not run, by the package; the lead runs them once at integration.
 */
