/**
 * Each theme owns four nonweapon tiers plus retained weapon variants.
 * A cache replaces one draw with the shared gun-or-melee selector. The
 * spawn zone changes draw counts and odds; every weapon class remains
 * reachable everywhere. Utility tools and control gear keep their sources.
 *
 * Weapon extras have weight one against weight ten per main entry. Chrome
 * weapons belong here too; other implants remain in the nonweapon tiers.
 * Guards stay colocated with their theme. Megafauna never enter these
 * guard tables: only the purpose-built arena ruins may place them.
 */
/datum/loot_theme
	/// Debug/audit label
	var/name
	/// Per-container gun percentages, indexed by ZONE_GREEN/YELLOW/RED.
	var/list/gun_chance
	/// Main gun family; each class also accepts the theme's retained variants.
	var/gun_pool = LOOT_GUN_POOL_ARMORY
	/// Class -> weighted extra weapon paths, separate from all nonweapon draws.
	var/list/gun_extras
	var/list/melee_extras
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

/// Returns a disposable pool. Freight never inherits themed weapon extras.
/datum/loot_theme/proc/get_weapon_pool(gun, weapon_class, freight = FALSE)
	return get_cache_weapon_pool(gun, weapon_class, freight ? LOOT_GUN_POOL_FREIGHT : gun_pool, freight ? null : (gun ? gun_extras : melee_extras))

/// theme typepath -> singleton instance; built once at world init
GLOBAL_LIST_INIT(loot_themes, init_loot_themes())

/proc/init_loot_themes()
	. = list()
	for(var/datum/loot_theme/theme_path as anything in subtypesof(/datum/loot_theme))
		.[theme_path] = new theme_path
