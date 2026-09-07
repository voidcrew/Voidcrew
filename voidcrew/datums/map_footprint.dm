/**
 * # Map footprint
 *
 * One tenant's rectangle on a shared z-level.
 *
 * "Planet footprint" and "z-level bounds" used to be the same object: /datum/space_level
 * carried exactly one rect, and ~35 call sites were correct *because* level.low_x..high_x
 * WAS the tenant. The moment a level holds more than one rect every one of them silently
 * starts describing the whole z - or the neighbour - and several of them delete things.
 *
 * This datum is the separation. A tenant (a flat encounter, a player outpost, a planet)
 * holds a footprint, and everything that used to ask "is this turf on my z-level?" asks
 * contains_turf() instead.
 *
 * A footprint also carries its tenant's GROUND (`baseturf`), which is what lets planets of
 * different biomes share a level - see footprint_baseturf_for_turf() at the bottom of this
 * file, and the var's own doc.
 *
 * Footprints are handed out by /datum/map_zone's slot register (see map_zones.dm), never
 * constructed directly by feature code:
 *
 *   var/datum/map_footprint/footprint = SSovermap.claim_free_slot(MAP_TENANT_CLASS_FLAT, src)
 *   ... build inside footprint.get_block() ...
 *   footprint.zone.release_slot(footprint)   // on teardown
 */
/datum/map_footprint
	/// Inclusive rectangle on `z_value`. Null until the footprint is attached to a level.
	var/low_x
	var/low_y
	var/high_x
	var/high_y
	/// The z-level this rectangle lives on. 0 until attach_level().
	var/z_value = 0
	/// The /obj/structure/overmap holding this footprint. Weak by signal: cleared the
	/// moment the owner is qdeleted, so a footprint outliving its tenant never keeps a
	/// deleted overmap object alive.
	var/atom/owner
	/// 1..slot_capacity within the owning zone.
	var/slot_index = 1
	/// One of the MAP_TENANT_CLASS_* keys - see planet_defines.dm.
	var/tenant_class
	/**
	 * The ground this tenant is made of: the turf path a baseturfs chain ending in
	 * /turf/baseturf_bottom resolves to for turfs inside this rectangle.
	 *
	 * This is the whole of mixed-biome packing. ZTRAIT_BASETURF is published once per
	 * z-level, so on a level holding a lava planet and an ice planet it can only ever be
	 * right for one of them - the other's crew digs a hole and finds the neighbour's ground
	 * (or, with no trait at all, vacuum) at the bottom of it. The footprint is per tenant,
	 * so it can answer for both.
	 *
	 * Null means "this tenant has no ground of its own" - flat encounters, player outposts,
	 * empty space - and the resolver falls through to the level trait exactly as before.
	 * Set by the tenant at build time, before any of its turfs exist; see build_planet().
	 */
	var/turf/baseturf
	/**
	 * A round-unique faction shared by living mobs native to this planet.
	 *
	 * Null for non-planet tenants. Planet builders enable it before loading or generating
	 * their surface, so every mob created inside the footprint inherits it without losing
	 * role factions such as `saloon`, `pirate`, or `wasteland`. A unique value per footprint
	 * keeps separate planets independent even when they share a packed z-level.
	 */
	var/planetary_faction
	/// The map zone that dealt this slot.
	var/datum/map_zone/zone
	/// The space level this footprint is registered on, once attached.
	var/datum/space_level/level

/datum/map_footprint/New(datum/map_zone/new_zone, new_tenant_class, new_slot_index = 1, atom/new_owner)
	. = ..()
	zone = new_zone
	tenant_class = new_tenant_class
	slot_index = new_slot_index
	if(new_owner)
		set_owner(new_owner)

/datum/map_footprint/Destroy(force)
	detach_level()
	set_owner(null)
	planetary_faction = null
	zone = null
	return ..()

/**
 * Points this footprint at its tenant, watching for the tenant's deletion.
 *
 * A signal rather than a bare ref: the teardown order between an overmap object and its
 * footprint is not fixed (player outposts release theirs from Destroy(), flat encounters
 * release theirs before qdel), and a stale hard ref here would be a hard-delete blocker.
 */
/datum/map_footprint/proc/set_owner(atom/new_owner)
	if(owner)
		UnregisterSignal(owner, COMSIG_QDELETING)
	owner = new_owner
	if(owner)
		RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(on_owner_deleted))

/datum/map_footprint/proc/on_owner_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(owner, COMSIG_QDELETING)
	owner = null

/**
 * Registers this footprint on a z-level and stamps its slot rectangle onto it.
 *
 * The rect comes from the lattice geometry for (tenant_class, slot_index) - see
 * map_slot_rect() - so a tenant never has to know where its slot is. Terrain planets
 * narrow it afterwards with set_bounds_at()/set_bounds().
 */
/datum/map_footprint/proc/attach_level(datum/space_level/new_level)
	if(!new_level)
		return FALSE
	if(level == new_level)
		return TRUE
	detach_level()
	level = new_level
	z_value = new_level.z_value
	var/list/rect = map_slot_rect(tenant_class, slot_index)
	low_x = rect[1]
	low_y = rect[2]
	high_x = rect[3]
	high_y = rect[4]
	level.add_footprint(src)
	return TRUE

/datum/map_footprint/proc/detach_level()
	if(!level)
		return
	var/datum/space_level/old_level = level
	level = null
	old_level.remove_footprint(src)

/// Narrows (or widens) this footprint to an explicit rectangle, clamped to the level.
/// Callers that want the lattice rect back should re-attach rather than guess at it.
/datum/map_footprint/proc/set_rect(origin_x, origin_y, width, height)
	low_x = clamp(origin_x, 1, world.maxx)
	low_y = clamp(origin_y, 1, world.maxy)
	high_x = clamp(low_x + width - 1, low_x, world.maxx)
	high_y = clamp(low_y + height - 1, low_y, world.maxy)
	level?.sync_level_bounds()

/// The primitive ~15 call sites need: is this turf inside my rectangle?
/// Null-safe on the turf so callers can pass get_turf() output straight in.
/datum/map_footprint/proc/contains_turf(turf/checked_turf)
	if(!checked_turf)
		return FALSE
	return contains_coords(checked_turf.x, checked_turf.y, checked_turf.z)

/**
 * Enables the native-mob alliance for this footprint and returns its faction token.
 *
 * Kept explicit rather than inferred from tenant_class: flat and solo footprints also
 * host crashed ships, outposts, and space ruins whose occupants are meant to retain their
 * normal rivalries. Only an actual planet build opts in.
 */
/datum/map_footprint/proc/enable_planetary_faction()
	if(planetary_faction)
		return planetary_faction
	var/static/next_planetary_faction_id = 0
	next_planetary_faction_id++
	planetary_faction = "planetary_[next_planetary_faction_id]"
	return planetary_faction

/// Adds this planet's token without replacing any identity or role factions on the mob.
/datum/map_footprint/proc/add_planetary_faction(mob/living/local_mob)
	if(!planetary_faction || QDELETED(local_mob) || !local_mob.should_inherit_planetary_faction())
		return FALSE
	local_mob.faction |= planetary_faction
	return TRUE

/// Only NPC mob families inherit the native alliance; player forms and companions can opt out.
/mob/living/proc/should_inherit_planetary_faction()
	// New player bodies (including vat clones) do not have a mind or client during Initialize.
	return isanimal_or_basicmob(src)

/**
 * Gives the token to living mobs already inside the footprint.
 *
 * This is the bridge for preloaded planets, whose mapped mobs initialize before SSovermap
 * creates their footprint. Dynamic planet builders also run it after ruin seeding as a
 * defensive post-load pass. Future mobs use inherit_planetary_faction() from Initialize().
 */
/datum/map_footprint/proc/add_planetary_faction_to_existing_mobs()
	. = 0
	if(!planetary_faction || isnull(low_x) || !z_value)
		return
	for(var/mob/living/local_mob as anything in GLOB.mob_living_list)
		if(QDELETED(local_mob) || !contains_turf(get_turf(local_mob)))
			continue
		add_planetary_faction(local_mob)
		.++

/// Coordinate form of contains_turf(), for callers that hold coordinates rather than a
/// turf ref (docking-port homes, cached bounds, anything that must survive a recycle).
/datum/map_footprint/proc/contains_coords(check_x, check_y, check_z)
	if(isnull(low_x) || !z_value)
		return FALSE
	if(check_z != z_value)
		return FALSE
	return check_x >= low_x && check_x <= high_x && check_y >= low_y && check_y <= high_y

/// Every turf in the footprint. Null (not an empty list) when the footprint is unattached,
/// so a caller that forgot to check does not silently sweep nothing.
/datum/map_footprint/proc/get_block()
	if(isnull(low_x) || !z_value)
		return null
	return block(locate(low_x, low_y, z_value), locate(high_x, high_y, z_value))

/datum/map_footprint/proc/get_width()
	return isnull(low_x) ? 0 : (high_x - low_x + 1)

/datum/map_footprint/proc/get_height()
	return isnull(low_y) ? 0 : (high_y - low_y + 1)

/// Middle of the footprint. What every `locate(world.maxx/2, world.maxy/2, z)` in the
/// codebase actually meant - that one lands in the gutter on a packed level.
/datum/map_footprint/proc/get_center_turf()
	if(isnull(low_x) || !z_value)
		return null
	return locate(round((low_x + high_x) / 2), round((low_y + high_y) / 2), z_value)

/// Whether this footprint covers the entire z-level (the whole-level compat shim used by
/// planets and outposts until they are packed). No cordon is painted for such a level.
/datum/map_footprint/proc/is_whole_level()
	if(isnull(low_x))
		return FALSE
	return low_x <= 1 && low_y <= 1 && high_x >= world.maxx && high_y >= world.maxy

/**
 * Living, minded mobs standing inside this footprint.
 *
 * The footprint-scoped counterpart of /datum/map_zone/get_mind_mobs(), which matches by z
 * alone. On a packed level the z-wide version counts the NEIGHBOUR's crew, which fuses the
 * two tenants' lifecycles: neither recycles until both are empty.
 */
/datum/map_footprint/proc/get_mind_mobs()
	. = list()
	if(isnull(low_x) || !z_value)
		return
	for(var/mob/living/living_mob as anything in GLOB.mob_living_list)
		if(!living_mob.mind || living_mob.stat == DEAD)
			continue
		if(contains_turf(get_turf(living_mob)))
			. += living_mob

/**
 * Whether any client-having, living player is standing inside this footprint.
 *
 * Same shape as turf_reservation_has_players() (map_zones.dm), which is the pattern every
 * bounds-scoped presence check in this codebase copies. get_turf() rather than the mob's
 * own z: a player inside a locker, a mech or a bodybag reads z 0 off the mob.
 */
/datum/map_footprint/proc/has_living_players()
	if(isnull(low_x) || !z_value)
		return FALSE
	for(var/mob/player as anything in GLOB.player_list)
		if(!isliving(player))
			continue
		var/mob/living/living_player = player
		if(living_player.stat == DEAD)
			continue
		if(contains_turf(get_turf(living_player)))
			return TRUE
	return FALSE

/// Debug/logging form: "z12 (3,3)-(125,125)"
/datum/map_footprint/proc/describe()
	if(isnull(low_x))
		return "unattached slot [slot_index] ([tenant_class])"
	return "z[z_value] ([low_x],[low_y])-([high_x],[high_y]) slot [slot_index] ([tenant_class])"

/**
 * The ground turf path for `checked_turf`, taken from whichever footprint on its z-level
 * contains it. Null when no footprint covers the turf or the one that does has no ground
 * of its own.
 *
 * This is the resolution point for mixed-biome packing: it is called from /turf/ChangeTurf
 * (the LIVE body in voidcrew/edits/turf.dm) and from the turf_z_transparency element, i.e.
 * from every place the /turf/baseturf_bottom sentinel is turned into a real turf path. The
 * level's ZTRAIT_BASETURF stays as the fallback, so a level with no footprints, an outpost,
 * a roundstart planet or lavaland behaves byte-for-byte as it always did.
 *
 * Deliberately allocation-free: one list index, one list read, and at most
 * MAP_SLOT_LATTICE_CAPACITY rectangle tests. No block(), no get_turf(), no
 * get_overmap_object_for_turf() walk over the GLOB site lists.
 */
/proc/footprint_baseturf_for_turf(turf/checked_turf)
	if(isnull(checked_turf))
		return null
	var/z_value = checked_turf.z
	if(z_value < 1 || z_value > length(SSmapping.z_list))
		return null
	var/datum/space_level/level = SSmapping.z_list[z_value]
	var/list/footprints = level?.footprints
	if(!length(footprints))
		return null
	var/check_x = checked_turf.x
	var/check_y = checked_turf.y
	for(var/datum/map_footprint/footprint as anything in footprints)
		// Ground first: a tenant with no ground of its own can never win the turf, and this
		// is the branch that skips the whole rect test on a level of flat encounters.
		if(isnull(footprint?.baseturf))
			continue
		if(footprint.z_value != z_value)
			continue
		// Inlined rather than contains_coords(): this runs inside ChangeTurf. An unattached
		// footprint has null bounds, and null compares as 0, so `check_x > null` is TRUE for
		// every real coordinate - it falls out of the test rather than matching everything.
		if(check_x < footprint.low_x || check_x > footprint.high_x)
			continue
		if(check_y < footprint.low_y || check_y > footprint.high_y)
			continue
		return footprint.baseturf
	return null

/**
 * How many tenants one z-level of the given class holds.
 *
 * Two classes pack: MAP_TENANT_CLASS_FLAT (empty space, crashed ships, weak signals - they
 * carry none of the one-per-z services) and MAP_TENANT_CLASS_PLANET (terrain planets of ANY
 * biome, since the ground a scrape resolves to now comes from the footprint rather than
 * from the level - see footprint_baseturf_for_turf()).
 *
 * Everything else is one to a level: MAP_TENANT_CLASS_SOLO (oversized ruin templates,
 * encounters carrying their own map generator, roundstart planets whose full-size z-level
 * was generated at boot) and MAP_TENANT_CLASS_OUTPOST (long-lived, would pin a slot).
 */
/proc/map_slot_capacity_for_class(tenant_class)
	switch(tenant_class)
		if(MAP_TENANT_CLASS_FLAT, MAP_TENANT_CLASS_PLANET)
			return MAP_SLOT_LATTICE_CAPACITY
	return 1

/**
 * The rectangle slot `slot_index` of `tenant_class` occupies, as list(low_x, low_y, high_x, high_y).
 *
 * Packed classes get a cell of the fixed lattice; everything else gets the whole level.
 * Slots are numbered left-to-right, bottom-to-top: 1 = (3,3), 2 = (131,3), 3 = (3,131),
 * 4 = (131,131).
 */
/proc/map_slot_rect(tenant_class, slot_index = 1)
	if(map_slot_capacity_for_class(tenant_class) <= 1)
		return list(1, 1, world.maxx, world.maxy)
	var/zero_based = clamp(slot_index, 1, MAP_SLOT_LATTICE_CAPACITY) - 1
	var/column = zero_based % MAP_SLOT_LATTICE_COLUMNS
	var/row = round(zero_based / MAP_SLOT_LATTICE_COLUMNS)
	var/origin_x = MAP_SLOT_MARGIN + 1 + (column * (MAP_SLOT_SIDE + MAP_SLOT_GUTTER))
	var/origin_y = MAP_SLOT_MARGIN + 1 + (row * (MAP_SLOT_SIDE + MAP_SLOT_GUTTER))
	return list(origin_x, origin_y, origin_x + MAP_SLOT_SIDE - 1, origin_y + MAP_SLOT_SIDE - 1)

/**
 * The complement of a set of inclusive 1D intervals within [range_low, range_high].
 *
 * place_cordon() paints the band between the slots. Rather than testing 65,025 turfs for
 * membership, the lattice decomposes into column and row intervals and their complements
 * give the cordon as a handful of solid strips - the same four strips a single-tenant
 * level has always produced, and exactly 4,509 turfs for the 2x2 lattice.
 *
 * `intervals` is a list of list(low, high); the return is the same shape, sorted ascending.
 */
/proc/map_interval_complement(list/intervals, range_low, range_high)
	. = list()
	var/list/sorted = list()
	for(var/list/interval as anything in intervals)
		var/inserted = FALSE
		for(var/index in 1 to length(sorted))
			var/list/placed = sorted[index]
			if(interval[1] < placed[1])
				sorted.Insert(index, list(interval))
				inserted = TRUE
				break
		if(!inserted)
			sorted += list(interval)

	var/cursor = range_low
	for(var/list/interval as anything in sorted)
		if(interval[1] > cursor)
			. += list(list(cursor, interval[1] - 1))
		cursor = max(cursor, interval[2] + 1)
	if(cursor <= range_high)
		. += list(list(cursor, range_high))

/**
 * The map tenant's rectangle a turf sits inside, but ONLY on a level that actually has
 * more than one tenant. Null otherwise.
 *
 * The "only when shared" part is the whole point. Every presence check that used to ask
 * "is anyone on this z-level?" is correct on a level with a single tenant and becomes
 * wrong the moment the level is packed, so this returns null for the single-tenant case
 * and lets the caller keep its existing z-wide path unchanged - no behaviour drift on
 * unpacked levels, no per-turf rectangle work on them either.
 *
 * O(1) plus one rect test per tenant: the level already carries its own footprint register
 * (see /datum/space_level), so this never walks the overmap object lists the way
 * SSovermap_zones.get_overmap_object_for_turf() does.
 */
/proc/map_footprint_at_turf(turf/candidate)
	if(!candidate)
		return null
	var/z_value = candidate.z
	if(z_value < 1 || z_value > length(SSmapping.z_list))
		return null
	var/datum/space_level/level = SSmapping.z_list[z_value]
	var/list/footprints = level?.footprints
	if(length(footprints) < 2)
		return null
	for(var/datum/map_footprint/footprint as anything in footprints)
		if(footprint?.contains_turf(candidate))
			return footprint
	return null

/**
 * The map tenant containing a turf, including levels with only one tenant.
 *
 * Unlike map_footprint_at_turf(), this is not a compatibility gate for formerly z-wide
 * systems: creation-time ownership always needs the actual footprint, even before a
 * neighbour takes another slot on the level.
 */
/proc/map_footprint_containing_turf(turf/candidate)
	if(!candidate)
		return null
	var/z_value = candidate.z
	if(z_value < 1 || z_value > length(SSmapping.z_list))
		return null
	var/datum/space_level/level = SSmapping.z_list[z_value]
	var/list/footprints = level?.footprints
	if(!length(footprints))
		return null
	for(var/datum/map_footprint/footprint as anything in footprints)
		if(footprint?.contains_turf(candidate))
			return footprint
	return null

/**
 * Gives a newly created living mob the alliance of the planet it was born on.
 *
 * Deliberately creation-only: landing parties and captured wildlife do not change sides
 * merely by crossing a footprint boundary. Spawners that replace a new mob's faction
 * after Initialize() must call this again after that replacement.
 */
/proc/inherit_planetary_faction(mob/living/spawned_mob)
	if(QDELETED(spawned_mob))
		return FALSE
	var/datum/map_footprint/footprint = map_footprint_containing_turf(get_turf(spawned_mob))
	return footprint?.add_planetary_faction(spawned_mob)

/**
 * Whether two turfs belong to the same map tenant - i.e. whether "same z-level" really
 * means "same place" for this pair.
 *
 * The gap every distance- and z-keyed system fell into once levels started carrying four
 * tenants apiece. A cordon gutter blocks air, sight, movement, reach, bullets, explosions
 * and radiation, but it does not blunt `get_dist()` and it does not change `z`, so a mission
 * kill nine tiles away across the band still reads as local, and a beacon in the next slot
 * still prints a walking distance nobody can walk.
 *
 * Null-footprint pairs answer TRUE: map_footprint_at_turf() only resolves on a level that
 * genuinely holds more than one tenant, so an unpacked level is one place exactly as it
 * always was, and no behaviour changes there.
 */
/proc/turfs_share_map_site(turf/first, turf/second)
	if(!first || !second)
		return FALSE
	if(first.z != second.z)
		return FALSE
	var/datum/map_footprint/first_site = map_footprint_at_turf(first)
	var/datum/map_footprint/second_site = map_footprint_at_turf(second)
	if(isnull(first_site) && isnull(second_site))
		return TRUE
	return first_site == second_site

/**
 * Whether any of the given client mobs is standing inside `footprint`.
 *
 * `clients` is one of SSmobs.clients_by_zlevel's per-z lists. Callers must have checked it
 * is non-empty first - the whole saving of these gates is that an empty z costs nothing.
 */
/proc/footprint_holds_any_client(datum/map_footprint/footprint, list/clients)
	if(!footprint)
		return FALSE
	for(var/mob/player as anything in clients)
		if(QDELETED(player))
			continue
		if(footprint.contains_turf(get_turf(player)))
			return TRUE
	return FALSE
