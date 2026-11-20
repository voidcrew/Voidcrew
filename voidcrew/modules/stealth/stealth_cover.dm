/**
 * # Cover: hiding in foliage
 *
 * Someone keeping still on a tile of dense foliage (a jungle bush, tall grass, a big potted plant where the map put
 * it) is seen by a guard only from STEALTH_COVER_RANGE tiles or closer, in light or dark. Cover is never
 * invisibility: inside that range the usual sight rules apply, and the point-blank, elbow-to-elbow and close-radius
 * rules (stealth_look()) are never touched by it.
 *
 * - Moving cancels it: someone who stepped (or fired a gun) within STEALTH_COVER_SETTLE is seen as on open ground.
 *   Crawling counts as keeping still, as it is slow and low.
 * - Pushing through foliage rustles: a quiet sound players hear, and a STEALTH_NOISE_RUSTLE guards hear a little
 *   less far (abuse H2).
 * - A guard that saw someone (at suspicious notice or more) a moment before they went still in cover goes and looks
 *   at that tile, as with a locker (decision 33, stealth_closet.dm).
 * - A guard's own flashlight beam on the tile shows it what is there. Another guard's beam does not.
 * - Only people: a stealth guard never hides this way, nor does anyone who isn't a human on a turf of their own.
 *
 * What counts is a typecache (stealth_cover_typecache()), read only: no flora or biome is changed. A potted plant
 * counts only on the tile the map put it on (abuse review: a bought, printed or dragged plant is no portable hide).
 */

/// Every type that hides someone keeping still on its tile
GLOBAL_LIST_INIT(stealth_cover_typecache, make_stealth_cover_typecache())

#ifdef UNIT_TESTS
/// Unit tests: turf => TRUE for a tile any guard's beam is on (reserved test space has no light of its own)
GLOBAL_LIST_EMPTY(stealth_test_beam_turfs)
#endif

/// The cover types. Dense or tall enough to hide a crouched person; short grass, flowers, reeds, small bushes,
/// trees (dense), rocks and dead potted plants are left out.
/proc/make_stealth_cover_typecache()
	var/list/cover = typecacheof(list(
		// tg jungle flora (tg's jungle biome; tg-ported ruins)
		/obj/structure/flora/bush/jungle,
		/obj/structure/flora/bush/large,
		/obj/structure/flora/grass/jungle,
		// Voidcrew jungle flora (voidcrew jungle biomes)
		/obj/structure/flora/junglebush,
		// "tall grass" and "dense grass"
		/obj/structure/flora/deadgrass/tall,
		// Big potted plants: only where the map put them (stealth_cover_at())
		/obj/item/kirbyplants,
	))
	cover -= typecacheof(/obj/item/kirbyplants/random/dead)
	return cover

/// The cover on `tile`, or null.
/proc/stealth_cover_at(turf/tile)
	if(!isturf(tile))
		return null
	for(var/obj/thing in tile)
		if(!GLOB.stealth_cover_typecache[thing.type])
			continue
		if(istype(thing, /obj/item/kirbyplants))
			var/obj/item/kirbyplants/plant = thing
			if(plant.stealth_cover_spot != tile)
				continue
		return thing
	return null

/// Whether `who`, standing at `where`, is hidden by cover from a guard far enough off: a human, not a guard, on a
/// turf of their own, keeping still or crawling, on a cover tile.
/proc/stealth_in_cover(mob/living/who, turf/where)
	if(!ishuman(who) || who.loc != where || who.buckled)
		return FALSE
	if(istype(who.ai_controller, /datum/ai_controller/basic_controller/human_npc/stealth))
		return FALSE
	var/mob/living/carbon/human/person = who
	if(person.body_position != LYING_DOWN && world.time - person.stealth_moved_at < STEALTH_COVER_SETTLE)
		return FALSE
	return !isnull(stealth_cover_at(where))

/// How far a rustle from `walker` carries to guards where they stand now: 0 off cover or off the ground.
/proc/stealth_rustle_reach(mob/living/walker)
	if(!isturf(walker.loc) || walker.buckled || (walker.movement_type & MOVETYPES_NOT_TOUCHING_GROUND))
		return 0
	if(isnull(stealth_cover_at(walker.loc)))
		return 0
	if(walker.body_position == LYING_DOWN || HAS_TRAIT(walker, TRAIT_LIGHT_STEP))
		return STEALTH_NOISE_RANGE_RUSTLE_CRAWL
	return STEALTH_NOISE_RANGE_RUSTLE

/// `walker` pushed through cover: guards in reach hear it. Returns how many heard it (tests).
/proc/stealth_rustle(mob/living/walker)
	if(!length(GLOB.stealth_groups))
		return 0
	var/reach = stealth_rustle_reach(walker)
	if(!reach)
		return 0
	return stealth_noise(walker.loc, STEALTH_NOISE_RUSTLE, reach, walker)

// ===== People =====

/mob/living/carbon/human
	/// world.time this person last moved or fired a gun (stealth_in_cover())
	var/stealth_moved_at = 0
	/// world.time this person may next rustle
	var/stealth_rustle_at = 0

// Every human move, one assignment; a player stepping onto cover also rustles. Only players rustle, so crowds of
// NPCs cost nothing more.
/mob/living/carbon/human/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	stealth_moved_at = world.time
	if(!forced && client && isturf(loc))
		stealth_cover_step()

/// A step of its own: a quiet rustle on a cover tile, for players and for guards.
/mob/living/carbon/human/proc/stealth_cover_step()
	if(world.time < stealth_rustle_at || (movement_type & MOVETYPES_NOT_TOUCHING_GROUND) || buckled)
		return
	if(isnull(stealth_cover_at(loc)))
		return
	stealth_rustle_at = world.time + STEALTH_COVER_RUSTLE_COOLDOWN
	var/crawling = body_position == LYING_DOWN
	playsound(loc, SFX_CRUNCHY_BUSH_WHACK, crawling ? STEALTH_COVER_RUSTLE_VOLUME_CRAWL : STEALTH_COVER_RUSTLE_VOLUME, TRUE, SILENCED_SOUND_EXTRARANGE)
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(stealth_rustle), src)

// A shot from cover shows where it came from: for a moment the shooter is as plain as someone moving.
/obj/item/gun/shoot_live_shot(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = TRUE)
	. = ..()
	if(ishuman(user))
		var/mob/living/carbon/human/shooter = user
		shooter.stealth_moved_at = world.time

// ===== Potted plants =====

/obj/item/kirbyplants
	/// The tile the map put it on, or null for one made, bought or spawned later. It hides someone only there.
	var/turf/stealth_cover_spot

/obj/item/kirbyplants/Initialize(mapload)
	. = ..()
	if(mapload && isturf(loc))
		stealth_cover_spot = loc

// ===== Guards =====

/datum/ai_controller/basic_controller/human_npc/stealth
	/// REF(mob) => world.time until which it won't go and look at cover it saw them get into again
	var/list/cover_checked

/// Whether its own beam is on `tile` brightly enough to show what is in cover there.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_beam_on(turf/tile)
#ifdef UNIT_TESTS
	if(tile in GLOB.stealth_test_beam_turfs)
		return GLOB.stealth_test_beam_turfs[tile]
#endif
	if(!light_lit || QDELETED(torch) || !isturf(tile))
		return FALSE
	var/datum/light_source/source = torch.light
	var/list/strengths = source?.effect_str
	if(!length(strengths))
		return FALSE
	var/channels = source.applied_lum_r + source.applied_lum_g + source.applied_lum_b
	var/lum = 0
	for(var/datum/lighting_corner/corner as anything in list(tile.lighting_corner_NE, tile.lighting_corner_SE, tile.lighting_corner_SW, tile.lighting_corner_NW))
		if(corner)
			lum += (strengths[corner] || 0) * channels
	return lum / 12 >= STEALTH_COVER_BEAM_LUM

/// Whether cover at `where` hides `who` from it now: far enough off, not in its own beam (stealth_look()).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_covered(mob/living/who, turf/where, dist)
	if(dist <= max(stealth_skill().point_blank_range, STEALTH_COVER_RANGE))
		return FALSE
	return stealth_in_cover(who, where) && !stealth_beam_on(where)

/**
 * Whether it saw `who` get into the cover at `where`: seen at suspicious notice or more a moment ago, close to it.
 * TRUE once per sighting.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_cover_glimpsed(mob/living/who, turf/where)
	var/key = REF(who)
	var/list/entry = notice_map[key]
	if(isnull(entry) || entry[STEALTH_ENTRY_NOTICE] < STEALTH_SUSPICIOUS_AT)
		return FALSE
	if(world.time - entry[STEALTH_ENTRY_SEEN_AT] > STEALTH_CLOSET_SEEN_WINDOW)
		return FALSE
	var/turf/was = entry[STEALTH_ENTRY_TURF]
	if(isnull(was) || get_dist(was, where) > 2)
		return FALSE
	if(LAZYACCESS(cover_checked, key) > world.time)
		return FALSE
	LAZYSET(cover_checked, key, world.time + STEALTH_CLOSET_SEEN_WINDOW + STEALTH_SCAN_INTERVAL)
	return TRUE

/// It saw someone get into cover at `where`: it goes and looks there.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_check_cover(turf/where)
	switch(stealth_state())
		if(STEALTH_UNAWARE)
			stealth_go_suspicious(where)
		if(STEALTH_SUSPICIOUS)
			investigated = FALSE
			last_gain = world.time
			stealth_aim_at(where)
		if(STEALTH_SEARCHING)
			stealth_go_searching(where)
