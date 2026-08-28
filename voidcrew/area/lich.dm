/**
 * Areas for The Verdigris: the lich lair raid site.
 *
 * The lair is a runtime-loaded space ruin (lich_lair.dmm), so it inherits the
 * ordinary space-ruin area parent: gravity on, power free, no APCs to shoot out
 * from under the raiders. What is NOT ordinary is that the interior never
 * unloads for the rest of the round (see lich_site.dm), so these area instances
 * are effectively permanent once the lair surfaces.
 *
 * The four layer areas are the raid's structure: one per defense layer, each
 * sealed behind an /obj/machinery/lich_ward that only unseals when its layer's
 * garrison is dead. The wards resolve their layer by area typepath through
 * GLOB.areas_by_type, which works because every one of these inherits
 * UNIQUE_AREA from /area/ruin/space.
 *
 * NOTELEPORT is deliberate and load-bearing: a teleport scroll or a bluespace
 * jaunt that skips three layers would delete the entire fight. It applies to
 * Ilthuun too, so his abilities must be positional (blink/step/summon), not
 * do_teleport() based.
 */
/area/ruin/space/has_grav/powered/lich_lair
	name = "\improper The Verdigris"
	icon_state = "away"
	static_lighting = TRUE
	area_flags = NOTELEPORT // UNIQUE_AREA is the area_flags_mapping default
	ambience_index = AMBIENCE_SPOOKY
	sound_environment = SOUND_AREA_TUNNEL_ENCLOSED

/// Layer 1: the breach hall the docking tube opens onto. First ward.
/area/ruin/space/has_grav/powered/lich_lair/atrium
	name = "\improper Verdigris Atrium"

/// Layer 2: stacked bone galleries. Second ward.
/area/ruin/space/has_grav/powered/lich_lair/ossuary
	name = "\improper Verdigris Ossuary"
	sound_environment = SOUND_AREA_SMALL_ENCLOSED

/// Layer 3: the tunnels his risen dead are quarried out of. Third ward.
/area/ruin/space/has_grav/powered/lich_lair/warrens
	name = "\improper Verdigris Warrens"
	sound_environment = SOUND_AREA_ASTEROID

/// Layer 4: the ritual chamber. Ilthuun is leashed here and does not leave it.
/// The fourth ward seals raiders OUT until the warrens are clear, and the boss
/// fight (and the loot) happen entirely inside.
/area/ruin/space/has_grav/powered/lich_lair/sanctum
	name = "\improper Verdigris Sanctum"
	ambience_index = AMBIENCE_CREEPY
	sound_environment = SOUND_AREA_LARGE_ENCLOSED
