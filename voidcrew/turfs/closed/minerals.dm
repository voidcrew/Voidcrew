/**
 * Zone ore scaling: planets in deeper overmap zone bands yield MORE ore per
 * mineral wall (same ore tables; kinds are never zone-gated, only amounts).
 *
 * Called from the one-line VOIDCREW EDIT in the base gets_drilled()
 * (code/game/turfs/closed/minerals.dm), the single payout choke point every
 * mining path funnels through (picks, drills, KA/plasma projectiles, ex_act,
 * blob). Scaling at payout instead of Initialize means spread-vein walls
 * (which keep the default mineralAmt of 3, never touched by
 * scale_ore_to_vent()) and mapper-placed ore walls inside planet ruins get
 * scaled too, and it costs nothing at planet init. Walls created after init
 * are equally covered, and on non-planet z-levels (space ruins,
 * asteroid-field reservations, outposts, transit) the band lookup returns
 * null, so behavior there is byte-identical to upstream.
 *
 * Deliberately NOT scaled:
 * * telecrystal + glacial core veins: the planetary trade goods
 *   (voidcrew/modules/trade/planetary_goods.dm); their supply is
 *   economy-tuned, so a richer red-band spigot would distort the
 *   voucher/credit ladder
 * * gibtonite and "very strong rock": their gets_drilled() overrides never
 *   call the base proc, so they never reach this hook; gibtonite's
 *   mineralAmt is detonation bookkeeping, not an ore payout
 * * gulag boulder walls: they use spawned_boulder, not mineralType, so the
 *   base proc's mineralType guard already skips them
 */
/turf/closed/mineral/proc/zone_scaled_ore_amount(amount)
	if(amount <= 0)
		return amount
	// trade-good veins keep their tuned yields (see block comment)
	if(istype(src, /turf/closed/mineral/telecrystal) || istype(src, /turf/closed/mineral/glacial))
		return amount
	// Resolved live, from THIS wall's turf. SSmapping.get_planet_zone_band_for_z() alone
	// only answers for pre-generated roundstart planets, and every planet this round is
	// dynamic, so it always came back null; planet_zone_type_for_turf() asks the overmap
	// first and falls back to it. Turf-scoped, not z-scoped: a z-level can carry more than
	// one planet and they can sit in different bands, so the wall has to speak for itself.
	// Not cached per z either - dynamic planet z-levels are recycled, so a cached band
	// would follow the z-level onto the next planet to inherit it.
	switch(SSovermap_zones?.planet_zone_type_for_turf(src))
		if(ZONE_YELLOW)
			return round(amount * ZONE_PLANET_ORE_MULT_YELLOW)
		if(ZONE_RED)
			return round(amount * ZONE_PLANET_ORE_MULT_RED)
	return amount

/**
 * Per-z index of the ore vents that count for a wall, grouped by the loaded interior each
 * vent sits in.
 *
 * `"[z]"` -> `list("stamp" = <vent count>, "built" = <world.time>, "zones" = list(entries))`,
 * where an entry is `list(low_x, low_y, high_x, high_y, list/vent_coords)` and `vent_coords`
 * is a flat run of x, y pairs.
 *
 * Mineral walls are the hottest code on a planet - a 123x123 surface initializes tens of
 * thousands of them in one burst - so the per-wall question has to be four integer
 * comparisons, not an overmap lookup. All the expensive work (resolving which planet, ruin
 * or outpost each vent belongs to) happens once per z per rebuild, over the handful of
 * vents that exist, and every wall then reads the answer out of a rect test.
 *
 * Coordinates rather than vent references on purpose. A cached ref to a vent that has since
 * been qdeleted is a hard-delete blocker for as long as nothing re-queries that z, and a
 * torn-down planet's z is exactly the one nothing re-queries. Numbers can't hold anything
 * alive, and distance is all this is ever asked for.
 *
 * Invalidated on the vent count changing, plus a short time expiry so a z-level that was
 * recycled onto a different planet while the count happened to land back on its old value
 * can't serve a stale rectangle. Both are cheap enough to check per wall.
 */
GLOBAL_LIST_EMPTY(ore_vent_index_by_z)

/// How long a built vent index stays trusted without the vent count changing under it.
#define ORE_VENT_INDEX_LIFESPAN (10 SECONDS)

/// Builds (or reuses) the vent index for a z-level. Returns the list of zone entries.
/proc/get_ore_vent_index_for_z(z_value)
	if(!z_value || isnull(SSore_generation))
		return null
	var/list/all_vents = SSore_generation.possible_vents
	var/stamp = length(all_vents)
	var/list/cached = GLOB.ore_vent_index_by_z["[z_value]"]
	if(cached && cached["stamp"] == stamp && (world.time - cached["built"]) < ORE_VENT_INDEX_LIFESPAN)
		return cached["zones"]

	var/list/zones = list()
	for(var/obj/structure/ore_vent/vent as anything in all_vents)
		if(vent.z != z_value)
			continue
		var/list/rect = SSovermap_zones?.get_interior_rect_for_turf(get_turf(vent))
		// No resolvable interior (lavaland proper, an unregistered site): the vent belongs
		// to the whole level, which is exactly what the old `vent.z == z` test said about
		// every vent. Same shape, so these merge into one entry.
		if(!rect)
			rect = list(1, 1, world.maxx, world.maxy)
		var/list/zone_entry
		for(var/list/existing as anything in zones)
			if(existing[1] == rect[1] && existing[2] == rect[2] && existing[3] == rect[3] && existing[4] == rect[4])
				zone_entry = existing
				break
		if(!zone_entry)
			zone_entry = list(rect[1], rect[2], rect[3], rect[4], list())
			zones += list(zone_entry)
		var/list/entry_coords = zone_entry[5]
		entry_coords += vent.x
		entry_coords += vent.y

	GLOB.ore_vent_index_by_z["[z_value]"] = list("stamp" = stamp, "built" = world.time, "zones" = zones)
	return zones

/**
 * Coordinates of the ore vents that count for this wall - the ones inside the same loaded
 * interior - as a flat run of x, y pairs. Null when nothing local qualifies.
 *
 * A vent 130 tiles away used to be "on my z-level, so mine". On a packed level it is on the
 * planet next door, behind a cordon, and letting it speak for this wall is what flips one
 * planet's entire mineral generation onto a gradient it has no vents for.
 *
 * Entries whose rectangle is the whole level (vents nothing owns) still match everything on
 * the level, so a single-tenant z behaves exactly as it did. When both a footprint entry and
 * a whole-level entry match, the wall gets the union - a vent nobody could place is still a
 * vent that could be anywhere.
 */
/turf/closed/mineral/proc/local_ore_vent_coords()
	var/list/zones = get_ore_vent_index_for_z(z)
	if(!length(zones))
		return null
	var/list/matching
	for(var/list/zone_entry as anything in zones)
		if(x < zone_entry[1] || x > zone_entry[3] || y < zone_entry[2] || y > zone_entry[4])
			continue
		// Copy only on the second match, so the overwhelmingly common single-match path
		// allocates nothing.
		matching = isnull(matching) ? zone_entry[5] : (matching + zone_entry[5])
	return matching

/**
 * Vent-proximity ore, in a place that has no vents yet.
 *
 * Upstream ties both "does this wall carry ore" and "how much" to the distance
 * to the nearest ore vent, and gets away with it because lavaland/icemoon seed
 * their ruins (vents included) BEFORE the world-wide terrain sweep runs. A
 * planet is built the other way round - build_planet() lays terrain down first
 * and only then seeds ruins (see planet.dm) - so every mineral wall initializes
 * while SSore_generation.possible_vents holds nothing for it.
 *
 * Upstream's "no vent found" answer is its 128 sentinel, which is past every
 * VENT_PROX_ band, so both procs returned 0: proximity_based walls (volcanic,
 * snow) never got an ore type at all, and every other random wall got its ore
 * type with mineralAmt 0, which gets_drilled()'s `mineralAmt > 0` guard then
 * silently ate. Planets shipped no minable ore of any kind, and the trade-good
 * veins seeded from those same tables (telecrystal on lava, glacial cores on
 * ice) never appeared either.
 *
 * So when there are no vents here, fall back to the flat, vent-independent
 * behaviour these turfs used before upstream's vent rework: the type's own
 * mineralChance, and upstream's own no-vent amount fallback. Gated on the vent
 * lookup rather than on being a planet, so a place that does have vents (lavaland
 * proper, and any wall created after a planet's ruins have landed) keeps
 * upstream's proximity gradient untouched.
 *
 * "Here" is the wall's own footprint, not its z-level. A z-level that carries two planets
 * carries two separate mineral economies, and the neighbour having seeded its ruins first
 * must not decide that this planet's rock is on a gradient - it has no vents to grade
 * against, so every wall would come out empty and the planet would ship no ore at all.
 */
/turf/closed/mineral/proc/has_local_ore_vent()
	return length(local_ore_vent_coords()) > 0

/// DEPRECATED alias for has_local_ore_vent(). The answer stopped being about the z-level.
/turf/closed/mineral/proc/z_has_ore_vent()
	return has_local_ore_vent()

/**
 * Distance to the nearest ore vent that counts for this wall, or upstream's 128 "none"
 * sentinel.
 *
 * Reimplements the base proc against local_ore_vent_coords() rather than chaining to it: the
 * upstream body scans every vent on the z with `vent.z != src.z`, and slots are only 128
 * apart on a packed level, so a neighbouring planet's vent lands well inside get_dist()'s
 * 127-tile reach and would grade this wall against rock it cannot see. The is_mining_level()
 * guard and the 128 sentinel are kept verbatim so the numbers this feeds are unchanged.
 *
 * max(|dx|, |dy|) is what get_dist() returns for two turfs on one z-level, which every vent
 * in the index is by construction.
 */
/turf/closed/mineral/prox_to_vent()
	if(!is_mining_level(z))
		return 0
	var/distance = 128 // Max distance for a get_dist is 127
	var/list/vent_coords = local_ore_vent_coords()
	for(var/index in 1 to round(length(vent_coords) / 2))
		var/delta_x = abs(x - vent_coords[index * 2 - 1])
		var/delta_y = abs(y - vent_coords[index * 2])
		var/temp_distance = max(delta_x, delta_y)
		if(temp_distance < distance)
			distance = temp_distance
	return distance

/turf/closed/mineral/random/proximity_ore_chance()
	if(!has_local_ore_vent())
		return mineralChance
	return ..()

/turf/closed/mineral/scale_ore_to_vent()
	if(!has_local_ore_vent())
		return rand(1, 5) // upstream's own off-lavaland fallback, see the base proc
	return ..()

#undef ORE_VENT_INDEX_LIFESPAN

/turf/closed/mineral/random/high_chance/wasteland
	baseturfs = /turf/open/misc/dust

/turf/closed/mineral/random/high_chance/mineral_chances()
	return list(
		/obj/item/stack/ore/uranium = 35,
		/obj/item/stack/ore/diamond = 30,
		/obj/item/stack/ore/gold = 45,
		/obj/item/stack/ore/titanium = 45,
		/obj/item/stack/ore/iron = 55,
		/obj/item/stack/ore/silver = 50,
		/obj/item/stack/ore/plasma = 50,
		/obj/item/stack/ore/bluespace_crystal = 20,
		/turf/closed/mineral/gibtonite/wasteland = 4,
		/turf/closed/mineral/telecrystal/wasteland = 6,
	)

/turf/closed/mineral/gibtonite/wasteland
	baseturfs = /turf/open/misc/dust

/turf/closed/mineral/random/beach
	baseturfs = /turf/open/misc/asteroid/sand/beach/dense

/turf/closed/wall/mineral/titanium/interior/blue
	color = "#9CE9F6"
	smoothing_flags = SMOOTH_BITMASK

/turf/closed/wall/mineral/titanium/interior/blue/Initialize()
	. = ..()
	add_atom_colour("#9CE9F6", FIXED_COLOUR_PRIORITY) // fuck you
