/**
 * # Voidcrew area flag namespace sentinel
 *
 * Upstream (tg PR #94071) split the single `area_flags` bitfield into two vars -
 * `area_flags` for runtime behaviour and `area_flags_mapping` for maploading and
 * worldgen - and RESTARTED the mapping bit numbering at 0. The two namespaces now
 * overlap numerically: UNIQUE_AREA is (1<<0), which is also VALID_TERRITORY, and
 * MOB_SPAWN_ALLOWED is (1<<3), which is also HIDDEN_AREA.
 *
 * That overlap is why this file exists. A fork area that keeps writing a mapping
 * flag into `area_flags` still COMPILES - the define is still a define, the var is
 * still a var - it just silently sets a different, wrong flag. When the split landed
 * in this fork's upstream merge, every planet area quietly lost CAVES_ALLOWED,
 * FLORA_ALLOWED and MOB_SPAWN_ALLOWED, gained NOTELEPORT and BLOBS_ALLOWED it was
 * never meant to have, and regained UNIQUE_AREA from the new default - which merges
 * every planet in the galaxy into one shared area instance. Nothing failed to build
 * and no existing test noticed.
 *
 * So this test pins the numbers. It asserts:
 *
 *  1. The define values themselves, in both namespaces. Any future upstream
 *     renumbering or cross-namespace move trips here first, with a name attached.
 *  2. The /area defaults, which is where UNIQUE_AREA now comes from implicitly.
 *  3. The exact effective (post-inheritance) value of BOTH vars on every fork area
 *     type whose flags carry load-bearing meaning.
 *  4. The semantics those numbers stand for, spelled out, so a failure says what
 *     broke in the game rather than which bit moved.
 *
 * Everything is read with initial() off a typepath, so no allocation and no map.
 */
/datum/unit_test/voidcrew_area_flags

/datum/unit_test/voidcrew_area_flags/Run()
	// (1) The namespaces themselves. These are the values every expectation below is
	// written against; if upstream moves a flag between vars or renumbers a bit, this
	// block names the flag instead of leaving a silently-wrong area definition.
	TEST_ASSERT_EQUAL(VALID_TERRITORY, (1<<0), "area_flags: VALID_TERRITORY moved")
	TEST_ASSERT_EQUAL(BLOBS_ALLOWED, (1<<1), "area_flags: BLOBS_ALLOWED moved")
	TEST_ASSERT_EQUAL(NOTELEPORT, (1<<2), "area_flags: NOTELEPORT moved")
	TEST_ASSERT_EQUAL(HIDDEN_AREA, (1<<3), "area_flags: HIDDEN_AREA moved")
	TEST_ASSERT_EQUAL(CULT_PERMITTED, (1<<7), "area_flags: CULT_PERMITTED moved")
	TEST_ASSERT_EQUAL(NO_GRAVITY, (1<<14), "area_flags: NO_GRAVITY moved")
	TEST_ASSERT_EQUAL(LOCAL_TELEPORT, (1<<15), "area_flags: LOCAL_TELEPORT moved")

	TEST_ASSERT_EQUAL(UNIQUE_AREA, (1<<0), "area_flags_mapping: UNIQUE_AREA moved")
	TEST_ASSERT_EQUAL(CAVES_ALLOWED, (1<<1), "area_flags_mapping: CAVES_ALLOWED moved")
	TEST_ASSERT_EQUAL(FLORA_ALLOWED, (1<<2), "area_flags_mapping: FLORA_ALLOWED moved")
	TEST_ASSERT_EQUAL(MOB_SPAWN_ALLOWED, (1<<3), "area_flags_mapping: MOB_SPAWN_ALLOWED moved")
	TEST_ASSERT_EQUAL(MEGAFAUNA_SPAWN_ALLOWED, (1<<4), "area_flags_mapping: MEGAFAUNA_SPAWN_ALLOWED moved")

	// (2) The defaults. UNIQUE_AREA is no longer written out by areas that want it -
	// it is inherited - so areas that must NOT be unique now have to clear it by hand.
	var/area/base_area = /area
	TEST_ASSERT(initial(base_area.area_flags_mapping) & UNIQUE_AREA, "/area no longer defaults to UNIQUE_AREA - every fork area that clears area_flags_mapping to stay non-unique is now doing so for no reason, and every area relying on the default has silently become non-unique")
	TEST_ASSERT(!(initial(base_area.area_flags) & NOTELEPORT), "/area now defaults to NOTELEPORT")

	// (3) Effective values, per type. list(expected area_flags, expected area_flags_mapping).
	var/list/expected = list(
		// The overmap itself: no teleporting onto it, and not a singleton.
		/area/overmap = list(NOTELEPORT, NONE),

		// Encounter reservations. Deliberately NOT NOTELEPORT (jaunt and fulton have to
		// work planetside) and deliberately NOT UNIQUE_AREA (every reservation mints its
		// own instance; sharing one would put every planet in the galaxy in one area).
		/area/overmap_encounter = list(HIDDEN_AREA, CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED),
		/area/overmap_encounter/planetoid = list(HIDDEN_AREA, CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED),
		/area/overmap_encounter/planetoid/cave = list(HIDDEN_AREA, CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED),
		// The one encounter area that IS shielded, which is the whole point of the subtype.
		/area/overmap_encounter/planet_ruin = list(HIDDEN_AREA | NOTELEPORT, CAVES_ALLOWED | FLORA_ALLOWED | MOB_SPAWN_ALLOWED),

		// Landable asteroid fields: one area instance per field, caves and fauna allowed.
		/area/centcom/asteroid/voidcrew = list(NONE, CAVES_ALLOWED | MOB_SPAWN_ALLOWED),

		// Outposts. The outpost proper is a singleton; the hangar is loaded once per
		// berth and the player-outpost shell once per outpost, so neither may be one.
		/area/voidcrew/trader_outpost = list(NOTELEPORT, UNIQUE_AREA),
		/area/voidcrew/outpost_hangar = list(NOTELEPORT, NONE),
		/area/voidcrew/player_outpost = list(NOTELEPORT, NONE),

		// Single-instance venues whose gate/ward logic resolves areas by typepath
		// through GLOB.areas_by_type, which only holds UNIQUE_AREA types.
		/area/voidcrew/colosseum = list(NOTELEPORT, UNIQUE_AREA),
		/area/ruin/space/has_grav/powered/lich_lair = list(NOTELEPORT, UNIQUE_AREA),
		/area/ruin/space/has_grav/vestige/arena = list(HIDDEN_AREA | NOTELEPORT, UNIQUE_AREA),
	)

	for(var/area/area_type as anything in expected)
		var/list/want = expected[area_type]
		var/got_flags = initial(area_type.area_flags)
		var/got_mapping = initial(area_type.area_flags_mapping)
		if(got_flags != want[1])
			TEST_FAIL("[area_type] area_flags is [got_flags], expected [want[1]] - a flag was added, dropped, or written into the wrong namespace")
		if(got_mapping != want[2])
			TEST_FAIL("[area_type] area_flags_mapping is [got_mapping], expected [want[2]] - a mapping flag was added, dropped, or written into the wrong namespace")

	// (4) The semantics, said out loud. These overlap (3) on purpose: (3) catches the
	// change, these say what the change costs.

	// Planet worldgen reads all three off area_flags_mapping (voidcrew/datums/mapgen/
	// biomes/_biome.dm, PlanetGenerator.dm). Without them a planet generates bare
	// terrain: no cave pockets, no flora, and not one fauna spawn anywhere on it.
	for(var/area/planet_area as anything in list(/area/overmap_encounter/planetoid, /area/overmap_encounter/planetoid/cave))
		var/mapping = initial(planet_area.area_flags_mapping)
		if(!(mapping & CAVES_ALLOWED))
			TEST_FAIL("[planet_area] cannot generate caves - planet terrain generation is disabled on it")
		if(!(mapping & FLORA_ALLOWED))
			TEST_FAIL("[planet_area] cannot spawn flora - planets generate bare ground")
		if(!(mapping & MOB_SPAWN_ALLOWED))
			TEST_FAIL("[planet_area] cannot spawn mobs - planets generate with no fauna at all")

	// Packed encounter levels rest on encounter areas being per-instance. If these
	// become UNIQUE_AREA, the map loader hands every reservation the SAME area object
	// and teardown, lighting, ambience and get_area_turfs() span every planet at once.
	for(var/area/nonunique as anything in list(
		/area/overmap_encounter,
		/area/overmap_encounter/planetoid,
		/area/overmap_encounter/planetoid/cave,
		/area/overmap_encounter/planet_ruin,
		/area/centcom/asteroid/voidcrew,
		/area/voidcrew/outpost_hangar,
		/area/voidcrew/player_outpost,
	))
		if(initial(nonunique.area_flags_mapping) & UNIQUE_AREA)
			TEST_FAIL("[nonunique] carries UNIQUE_AREA - every load of it shares ONE area instance, so separate sites merge into a single area")

	// The inverse: ward/gate logic looks these up by typepath in GLOB.areas_by_type,
	// which /area/New() only files for UNIQUE_AREA types. Non-unique here means the
	// lookup returns null and the doors never resolve their layer.
	for(var/area/unique as anything in list(
		/area/voidcrew/trader_outpost,
		/area/voidcrew/colosseum,
		/area/ruin/space/has_grav/powered/lich_lair,
		/area/ruin/space/has_grav/vestige/arena,
	))
		if(!(initial(unique.area_flags_mapping) & UNIQUE_AREA))
			TEST_FAIL("[unique] lost UNIQUE_AREA - GLOB.areas_by_type will not hold it and the logic that resolves this area by typepath breaks")

	// NOTELEPORT lives in area_flags and is read there by check_teleport_valid(),
	// process_teleport_locs() and the cordon's own dusting area. Sealed venues must
	// keep it; the encounter base must NOT have it, because it makes jaunt unusable
	// planetside and kills fulton packs on the one map type that wants them.
	for(var/area/sealed as anything in list(
		/area/misc/cordon,
		/area/overmap_encounter/planet_ruin,
		/area/voidcrew/colosseum,
		/area/ruin/space/has_grav/powered/lich_lair,
		/area/ruin/space/has_grav/vestige/arena,
	))
		if(!(initial(sealed.area_flags) & NOTELEPORT))
			TEST_FAIL("[sealed] lost NOTELEPORT - a teleport or jaunt can now skip whatever this area puts between a player and its contents")

	for(var/area/open as anything in list(/area/overmap_encounter, /area/overmap_encounter/planetoid, /area/overmap_encounter/planetoid/cave))
		if(initial(open.area_flags) & NOTELEPORT)
			TEST_FAIL("[open] gained NOTELEPORT - jaunt becomes unusable planetside and fulton packs stop working on planets")
