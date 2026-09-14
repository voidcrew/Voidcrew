#define COMSIG_VOIDCREW_PLANET_LOADED "voidcrew_planet_loaded"

/// Sent on a space ruin as its interior is torn down, BEFORE the reservation is
/// freed and while the signal object itself lives on. Anything holding a claim on
/// the site (a live contract with an objective standing in there) gets its chance
/// to let go of what is about to be wiped, instead of reading the wipe as a loss.
#define COMSIG_VOIDCREW_RUIN_UNLOADING "voidcrew_ruin_unloading"

/// Sent by every site load_level() on EVERY exit past the point where it claimed the
/// job (success AND failure: queue timeout, reservation failure, template failure).
/// Arg is TRUE on success, FALSE on failure. Distinct from COMSIG_VOIDCREW_PLANET_LOADED,
/// which only ever fires on success and has listeners (missions, survey consoles) whose
/// semantics must not change - ships waiting to auto-resume a docking approach listen to
/// this one instead (see /obj/structure/overmap/ship/proc/request_site_load).
#define COMSIG_VOIDCREW_SITE_LOAD_FINISHED "voidcrew_site_load_finished"

/**
 * Smallest a planet's bounded region may be.
 *
 * Two reserve docks sit side by side along the bottom edge, so the width has to
 * cover padding + dock + padding + dock + padding:
 * (RESERVE_DOCK_DEFAULT_PADDING * 3) + (RESERVE_DOCK_MAX_SIZE_LONG * 2) + border.
 * set_bounds() clamps to this, so a planet_size below it silently rounds up.
 */
#define PLANET_MIN_SIZE 123

/**
 * ---- Map-zone slot lattice (planet packing, phase 1) ----
 *
 * A z-level used to hold exactly one tenant. It now holds a fixed lattice of slots, each
 * one a /datum/map_footprint rectangle handed to a single tenant (a flat encounter, a
 * player outpost, a planet). The lattice is FIXED rather than allocated: with four
 * identical squares at known offsets there is no fragmentation, no packing search and no
 * failure mode where a tenant cannot be placed.
 *
 * The side is PLANET_MIN_SIZE, the smallest footprint the two side-by-side reserve berths
 * fit in, so a slot is exactly as small as an interior is allowed to get:
 *
 *   MAP_SLOT_MARGIN + SIDE + MAP_SLOT_GUTTER + SIDE + MAP_SLOT_MARGIN
 *   =        2       + 123  +       5        + 123  +        2        = 255 = world.maxx
 *
 * Origins are therefore (3,3), (131,3), (3,131), (131,131). The margin and gutter are
 * painted cordon by place_cordon(), which computes them once per z-level as the complement
 * of every slot rect - see /datum/space_level/place_cordon().
 */
#define MAP_SLOT_SIDE PLANET_MIN_SIZE
/// Turfs of cordon left between the lattice and the world edge.
#define MAP_SLOT_MARGIN 2
/// Turfs of cordon left between two neighbouring slots. One turf of /turf/cordon is
/// physically sufficient (it blocks air, sight, movement, reach, bullets, explosions,
/// radiation and jaunt); the rest is margin for BYOND corner cases.
#define MAP_SLOT_GUTTER 5
/// Slots per axis, and therefore MAP_SLOT_LATTICE_COLUMNS * MAP_SLOT_LATTICE_ROWS per z.
#define MAP_SLOT_LATTICE_COLUMNS 2
#define MAP_SLOT_LATTICE_ROWS 2
#define MAP_SLOT_LATTICE_CAPACITY (MAP_SLOT_LATTICE_COLUMNS * MAP_SLOT_LATTICE_ROWS)

/**
 * Tenant classes. A map zone deals slots of exactly ONE class at a time, so tenants whose
 * geometry or lifecycle cannot be mixed never end up on the same level.
 *
 * A zone with no occupied slots has no class and is free to be re-dealt as any of them,
 * which is what keeps the recycled-zone pool from splintering per class.
 */
/// Flat encounters: empty space, crashed ships, weak signals. No terrain, no baseturf, no
/// weather, no SSplanet_mobs - nothing that is one-per-z. Packed 4 to a level.
#define MAP_TENANT_CLASS_FLAT "flat"
/// Player outposts. Long-lived, `preserve_level`-shaped tenants that would pin a lattice
/// slot for the whole round, so they get their own class and never mix with FLAT.
#define MAP_TENANT_CLASS_OUTPOST "outpost"
/// Anything that must own a whole z-level to itself: oversized ruin templates, encounters
/// carrying their own map generator. One tenant, whole-level footprint, no cordon.
#define MAP_TENANT_CLASS_SOLO "solo"
/**
 * Terrain planets. ONE class for every biome - a lava, an ice and two jungle planets share
 * a level happily. Packed 4 to a level (see map_slot_capacity_for_class).
 *
 * This replaced the per-biome MAP_TENANT_BIOME_CLASS("biome-<datum path>") keys. Those
 * existed for exactly one reason: ZTRAIT_BASETURF is published per z-level, and it is what
 * a dug-up or blown-out turf on a planet bottoms out into, so a mixed-biome level used to
 * hand one of its tenants the other's ground under every hole its crew made. That is now
 * answered per-RECTANGLE instead of per-level - /datum/map_footprint carries the biome's
 * ground turf and footprint_baseturf_for_turf() resolves it at the scrape - so the biome is
 * no longer an allocation constraint. Everything else the level publishes is either
 * categorical (ZTRAIT_MINING, ZTRAIT_LINKAGE), per-site (weather, storms, danger band) or
 * read from the planet's own pool (ruins), which the co-tenancy audit in
 * scratchpad/mixed-biome-report.md walks one by one.
 */
#define MAP_TENANT_CLASS_PLANET "planet"

/// Turfs of breathing room left around the reserve docks that ruins may not be placed in.
/// Matches EVENT_FIELD_DOCK_CLEARANCE - a ship parked flush against a ruin wall is as bad
/// as one parked on top of it.
#define PLANET_DOCK_RUIN_CLEARANCE 3

/**
 * ---- Where a ruin template may be stamped inside a lattice slot ----
 *
 * A slot spends its bottom rows on TWO 56x40 reserve berths laid side by side
 * (spawn_dynamic_encounter() anchors them at low_y + RESERVE_DOCK_DEFAULT_PADDING + 1, so
 * they occupy y offsets 4..43 and x offsets 4..118). Anything the ruin placer measures
 * DOWN from the slot's top edge lands on top of both of them the moment the template is
 * tall enough - which for a 123-tall slot is any template of 73 rows or more.
 *
 * So the ruin region is the slot MINUS the berth band and its clearance collar, with a
 * couple of turfs left inside the slot edge so a template never ends up flush against the
 * cordon. Every number below is derived from the berth geometry rather than typed in, so
 * moving a berth moves the gate with it.
 *
 *   x: MAP_SLOT_RUIN_MARGIN .. MAP_SLOT_SIDE-1 - MAP_SLOT_RUIN_MARGIN   = 119 wide
 *   y: MAP_SLOT_RUIN_MIN_Y_OFFSET .. MAP_SLOT_SIDE-1 - MAP_SLOT_RUIN_MARGIN =  74 tall
 *
 * Measured against the live SSmapping.space_ruins_templates list (113 templates,
 * 2026-08-20): 112 fit, the sole outlier being russian_derelict at 83x111, which takes
 * MAP_TENANT_CLASS_SOLO instead. See ruin_fits_in_slot().
 */
/// Turfs left between a stamped ruin and its slot's edge.
#define MAP_SLOT_RUIN_MARGIN 2
/// First row (offset from a slot's low_y) above the berth band a ruin may occupy.
///
/// This is the PACKING GATE, not the placement default: ruin_fits_in_slot() measures against
/// it, so raising it moves templates onto whole z-levels of their own. WHERE a template is
/// actually stamped is decided by slot_build_region(), which prefers
/// MAP_SLOT_RUIN_PREFERRED_Y_OFFSET and only drops back to here for a template too tall to
/// fit above that.
#define MAP_SLOT_RUIN_MIN_Y_OFFSET (RESERVE_DOCK_DEFAULT_PADDING + RESERVE_DOCK_MAX_SIZE_SHORT + PLANET_DOCK_RUIN_CLEARANCE + 1)
/**
 * Preferred first row (offset from a slot's low_y) for a stamped ruin: the berth band plus
 * the full PLANET_DOCK_HOSTILE_CLEARANCE collar planets keep, rather than the three turfs
 * MAP_SLOT_RUIN_MIN_Y_OFFSET allows.
 *
 * Three rows stop a ruin being BUILT on a berth; they do not stop its turrets shooting into
 * one, which is what #227 reported on planets. Space-ruin encounters have the same geometry
 * and the same problem, but the fix planets got - widening the reserved strip - cannot be
 * applied here, because here the strip IS the packing gate: widening it pushes every
 * template over the new height onto a whole z-level of its own (~49 MB apiece;
 * spacehotel.dmm at 67x71 is the one that would move). So the gate stays where it is and
 * the PLACEMENT prefers the wider collar instead, falling back only for the handful of
 * templates too tall to take it.
 *
 * In a 123-tall lattice slot this leaves 67 rows above the preferred floor against the
 * gate's 74, so templates of 68..74 rows are the ones that fall back. A whole-level (SOLO)
 * footprint has 200 rows and never falls back.
 */
#define MAP_SLOT_RUIN_PREFERRED_Y_OFFSET (RESERVE_DOCK_DEFAULT_PADDING + RESERVE_DOCK_MAX_SIZE_SHORT + PLANET_DOCK_HOSTILE_CLEARANCE + 1)
/// Widest ruin template a slot can hold.
#define MAP_SLOT_RUIN_REGION_WIDTH (MAP_SLOT_SIDE - (MAP_SLOT_RUIN_MARGIN * 2))
/// Tallest ruin template a slot can hold, once the berths have taken the bottom rows.
#define MAP_SLOT_RUIN_REGION_HEIGHT (MAP_SLOT_SIDE - MAP_SLOT_RUIN_MARGIN - MAP_SLOT_RUIN_MIN_Y_OFFSET)

/// Minimum cleanup delay once an undocked planet has no living, connected players.
#define PLANET_DESPAWN_TIMER 5 MINUTES
/**
 * Cleanup delay for an interior no ship has ever docked at.
 *
 * A survey, a transporter lock or a survey-camera refresh generates a whole surface
 * without anybody flying to it, and those planets used to sit resident for the rest of
 * the round: the countdown was only ever armed by a ship undocking, so one that was
 * never docked at never got a countdown at all. They are on the same clock as everybody
 * else now, but a longer one - the crew that charted it is usually still deciding
 * whether to land, and the helm invites them to "dock when ready".
 */
#define PLANET_UNVISITED_DESPAWN_TIMER 15 MINUTES
/// A living SSD player's body is protected for this long after its last disconnect.
#define PLANET_SSD_GRACE_PERIOD 10 MINUTES

/// How long a site waits before retrying a load that was refused for want of map volume
/// (world.maxz at its ceiling - see /datum/config_entry/number/max_z_levels).
///
/// A SLOT-AVAILABILITY wait, deliberately outside the worldgen queue: the site releases
/// the queue before arming this, so a ruin or an empty-space dock never ends up waiting
/// behind somebody else's planet build. Matches the 30-second re-arm every other
/// "somebody is still busy" retry in the overmap lifecycle uses.
#define SITE_CAPACITY_RETRY_DELAY (30 SECONDS)
/// How often a crew still waiting on charting capacity is reminded of it. The first refusal
/// of a hold warns loudly; the retries between reminders stay silent (the wait itself is
/// SITE_CAPACITY_RETRY_DELAY-paced). Long enough not to nag, short enough that a
/// minutes-long hold is distinguishable from a hang.
#define SITE_CAPACITY_RENOTIFY_INTERVAL (3 MINUTES)
