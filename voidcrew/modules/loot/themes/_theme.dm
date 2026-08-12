/**
 * # Loot themes
 *
 * One datum per loot theme (armory, plunder, ...), owning everything the
 * theme hands out and everything defending it: the four tier tables
 * consumed by /obj/structure/closet/crate/zone_loot (zone_loot.dm), plus,
 * by file colocation, the theme's crate subtype and the guard-marker
 * subtypes (/obj/effect/zone_mobs) that watch over it.
 *
 * A theme is ONE pool split by how good the item is, not by where you are.
 * Overmap zone never selects a table. It only decides how many draws a
 * cache gets and how the odds lean across the four tiers (see zone_loot.dm).
 * Every band can reach every tier; deep space just reaches the top of it far
 * more often. This mirrors how zones already scale planet ore, fauna and
 * weather (voidcrew/_DEFINES/overmap_zones.dm): amounts and odds, not kinds.
 *
 * Why a datum instead of vars on the crate subtype (the old shape): the
 * cache weights are hand-tuned against outpost shop prices ("the gamble
 * channel and the certainty channel stay on one curve") and against the
 * theme's own guard tables. Keeping tables, guards and the SKU
 * cross-reference list in one file per theme makes that curve a same-screen
 * edit instead of a comment maintained across three files, and gives the
 * loot audit unit test (code/modules/unit_tests/voidcrew_loot.dm) a single
 * registry to walk.
 *
 * CYBERWARE (2026-08-05): the parlor roster rides these tables the same way
 * the gun blueprints do. The shop is the certainty channel, the caches are
 * the gamble channel, and both sit on one curve. Chrome enters at the tier
 * that matches what Splice charges for it
 * (voidcrew/modules/cyberware/ripperdoc_catalog.dm):
 * - Street chrome (400-2000cr) -> common / uncommon
 * - Pro chrome (2800-3600cr, 1-2 vouchers) -> uncommon / prime
 * - Military chrome (2-4 vouchers) -> the long tail of prime, weight 2-3
 * Two exclusions, both deliberate: Legend chrome (Cascade, Redline, Governor
 * Delete) is the authored chase and is always on Splice's shelf, and the
 * Piledriver is the black market's contract-only reward, neither drops. The
 * Skyhook Wrist is the mirror of that: it has no SKU anywhere, so a cache is
 * the only place it exists (expedition prime).
 *
 * A found piece is not a worn piece. Chrome still installs only at a Chrome
 * Cradle or through organ-manipulation surgery, and it still costs capacity,
 * so a cache pays the hardware and never the seat in the chair.
 *
 * HARD RULE (design): no megafauna anywhere in the zone system, not in
 * guard tables, not as bosses, never as generic cache guards in new maps.
 * Megafauna (including this fork's /mob/living/basic/boss tier, see
 * ismegafauna()) belong to planet apex spawns and to the handful of
 * purpose-built boss-arena ruins enumerated in the unit test's whitelist
 * (blood-drunk shrines, the hierophant arena, the wendigo cave, ...).
 * "Harder versions of normal mobs" (elites, ancients, captains) are the
 * ceiling everywhere else; the unit test enforces this for the tables and
 * for every shipped ruin .dmm.
 */
/datum/loot_theme
	/// Debug/audit label
	var/name
	/// Weighted tier tables (typepath -> weight). Bread and butter; what a
	/// cache pays most of the time in any band.
	var/list/loot_common
	/// The theme's working kit: worth the trip, still not a story.
	var/list/loot_uncommon
	/// The top of the theme: gear a crew reorganizes around. Green reaches
	/// this rarely, red reaches it constantly.
	var/list/loot_prime
	/// One-of-a-kind authored prizes (voidcrew/modules/loot/uniques/). Drawn
	/// as a fourth tier at low odds; there is deliberately no global
	/// already-dropped registry, so a long round can repeat one.
	var/list/loot_uniques
	/// zone_mobs marker types that fit this theme's ruins, the guard side of
	/// the same design. Mappers: place these around the theme's caches.
	var/list/guard_themes
	/// Shop SKUs whose prices are deliberately tuned against these tables,
	/// the certainty channel to the caches' gamble channel. Kept here so a
	/// weight change and a price change happen on the same screen, and so the
	/// audit unit test can walk the curve.
	var/list/theme_skus

/// theme typepath -> singleton instance; built once at world init
GLOBAL_LIST_INIT(loot_themes, init_loot_themes())

/proc/init_loot_themes()
	. = list()
	for(var/datum/loot_theme/theme_path as anything in subtypesof(/datum/loot_theme))
		.[theme_path] = new theme_path
