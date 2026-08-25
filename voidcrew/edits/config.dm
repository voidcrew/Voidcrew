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
 * This number is the CONFIGURED ceiling, not the one enforced at any given moment. Every
 * other thing on the server scales with population - mobs, atoms, client-side rendering,
 * the reservation churn of ships flying - so the same 24 levels that sit comfortably at
 * 40 players are over the wall at 118. The effective ceiling therefore shrinks with pop,
 * see max_z_levels_pop_scale_start / _per / max_z_levels_pop_floor below and
 * effective_z_ceiling() in voidcrew/mapping/_mapping.dm. Nothing reads this entry to make
 * a decision; they ask that proc.
 *
 * The colosseum's two budgeted levels above are now actually charged against the ceiling:
 * load_level() used to mint them through raw add_new_zlevel() past the gate and without a
 * log line. It asks z_headroom() first now, and every ungated mint anywhere in the tree
 * reports itself through report_z_mint().
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

/// Client count above which the effective z-ceiling starts shrinking below max_z_levels.
/// Below this the configured ceiling is used as-is. 0 disables pop scaling entirely, which
/// is what a host with a 64-bit server (or a hard population cap well under the wall) wants.
/// 80 is where the last measured rounds started spending the rest of the address space on
/// everything that is not turf plane.
/datum/config_entry/number/max_z_levels_pop_scale_start
	default = 80
	integer = TRUE
	min_val = 0

/// One z-level comes off the effective ceiling per this many clients past
/// max_z_levels_pop_scale_start, e.g. 24 levels at 80 players, 20 at 120 on the defaults.
/// A level is ~49 MB bare and ~76 MB loaded; ten more players cost roughly that much in
/// mobs, atoms and per-client rendering state, so trading one for the other holds the total.
/datum/config_entry/number/max_z_levels_pop_scale_per
	default = 10
	integer = TRUE
	min_val = 1

/// Floor the pop scaling can never push the effective ceiling below. The round still needs
/// its roundstart levels, its reservations and somewhere to put a planet; scaling all the
/// way down would strand every ship rather than save the round. 0 removes the floor and
/// lets the scaling run to zero. Never raises the ceiling above max_z_levels.
/datum/config_entry/number/max_z_levels_pop_floor
	default = 18
	integer = TRUE
	min_val = 0
