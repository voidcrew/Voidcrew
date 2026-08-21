/datum/config_entry/flag/no_default_techweb_link
	default = TRUE

/datum/config_entry/flag/forbid_station_traits
	default = FALSE

/datum/config_entry/flag/enable_night_shifts
	default = FALSE

/datum/config_entry/flag/allow_random_events
	default = FALSE

/datum/config_entry/flag/allow_vote_transfer
	default = TRUE

/datum/config_entry/flag/free_ships
	default = FALSE

/**
 * Hard ceiling on world.maxz.
 *
 * BYOND never frees a z-level. Every one ever minted keeps its full 255x255 turf plane
 * for the rest of the round - measured at ~49 MB bare, ~76 MB carrying a site's payload -
 * against a 32-bit server's ~3500 MB wall, and nothing in the tree limited how many could
 * be created. A round that churned encounters simply climbed until it died.
 *
 * The budget this default comes from, on the packed allocator:
 *
 *   roundstart space/ruin/empty levels + station   ~10
 *   planets (four to a level, ~3 concurrent)         1-2
 *   packed encounters (four to a level, ~8 live)     2-3
 *   oversized SOLO ruins                             1-2
 *   reservations / transit                           2-3
 *   colosseum, isolated ruins, headroom              2
 *                                                   ----
 *                                                  18-22
 *
 * 24 leaves headroom over that and is ~1,180 MB of committed turf plane, roughly a third
 * of the wall. A config entry rather than a define so a host with more memory (or less)
 * can move it without a recompile. 0 disables the ceiling entirely.
 *
 * At the ceiling a site is REFUSED A SLOT and retries on its own timer - it is not queued
 * behind anything. See claim_free_slot() (overmap.dm) and
 * request_turf_block_reservation() (mapping.dm) for the two enforcement points.
 */
/datum/config_entry/number/max_z_levels
	default = 24
	integer = TRUE
	min_val = 0

/// world.maxz at which the ceiling starts warning in the logs, so a host sees the climb
/// before the wall rather than after it. Kept below max_z_levels; a value at or above it
/// simply never fires before the cap message does.
/datum/config_entry/number/max_z_levels_warn_at
	default = 20
	integer = TRUE
	min_val = 0
