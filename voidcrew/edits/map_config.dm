/**
 * Roundstart space levels: none.
 *
 * Upstream mints DEFAULT_SPACE_RUIN_LEVELS (7) "Ruin Area" levels and one "Empty Area"
 * level in SSmapping/Initialize() before a single encounter exists. This fork never uses
 * them: setup_ruins() is overridden and seeds nothing on them, every encounter builds on
 * its own packed map zone, and setup_map_transitions() is a no-op so they do not even
 * carry edge transitions. Eight 255x255 turf planes of pure waste, ~390 MB, and BYOND
 * never frees a z-level - round 79 (2026-09-16) booted at world.maxz 10 with zero map
 * zones and ended at 24, and eight of those ten were these.
 *
 * Set HERE, on the datum defaults, and not only in _maps/metastation.json: config/maps.txt
 * declares no `default` map, so config.defaultmap is null and SSmapping/Initialize() runs
 * the round on the DEFAULTED /datum/map_config - the JSON is never read in production.
 * (The census proves it: 1 CentCom + 7 ruin + 1 empty + 1 transit = the 10 levels that
 * were live at boot.)
 *
 * What used to read them:
 *  - dump_in_space() threw hyperspace-overboard mobs onto the CROSSLINKED ones. Replaced
 *    by voidcrew_dump_in_space() (voidcrew/edits/hyperspace_overboard.dm); the upstream
 *    fallback below it walks ZTRAIT_MINING (every encounter level) then ZTRAIT_STATION.
 *  - Aurora Caelus (both versions) checks SSmapping.empty_space and simply never rolls.
 *  - The cursed mirror picks from levels_by_trait(ZTRAIT_SPACE_RUINS) behind a length()
 *    guard; the hand teleporter's levels_by_any_trait() list includes ZTRAIT_STATION.
 *  - The ERT custom-shuttle verb read empty_space.z_value unguarded; guarded now.
 */
/datum/map_config
	space_ruin_levels = 0
	space_empty_levels = 0

/**
 * LoadConfig
 *
 * We're setting planetary to FALSE for unit testing, as we don't have a map.
 * We're alo clearing all job changes, as job changes are per TG map, not ship/planet/whatnot, making this unwanted by us.
 */
/datum/map_config/LoadConfig(filename, error_if_missing)
	. = ..()
	planetary = FALSE
	job_changes = list()
