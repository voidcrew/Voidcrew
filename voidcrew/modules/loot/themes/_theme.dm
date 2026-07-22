/**
 * # Loot themes
 *
 * One datum per loot theme (armory, plunder, ...), owning everything the
 * theme hands out and everything defending it: the six zone cache tables
 * consumed by /obj/structure/closet/crate/zone_loot (zone_loot.dm), plus —
 * by file colocation — the theme's crate subtypes and the guard-marker
 * subtypes (/obj/effect/zone_mobs) that watch over them.
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
 * HARD RULE (design): no megafauna anywhere in the zone system — not in
 * guard tables, not as bosses, never as generic cache guards in new maps.
 * Megafauna (including this fork's /mob/living/basic/boss tier — see
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
	/// Weighted cache tables (typepath -> weight) keyed by spawn zone
	var/list/loot_green
	var/list/loot_yellow
	var/list/loot_red
	/// Rare-cache tables ("the top of the zone's table"); /rare crates fall
	/// back to the normal table for zones where these are empty
	var/list/rare_loot_green
	var/list/rare_loot_yellow
	var/list/rare_loot_red
	/// zone_mobs marker types that fit this theme's ruins — the guard side of
	/// the same design. Mappers: place these around the theme's caches.
	var/list/guard_themes
	/// Shop SKUs whose prices are deliberately tuned against these tables —
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
