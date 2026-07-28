/**
 * # Hoarfrost Matriarch - field objects
 *
 * The furniture the Matriarch's kit puts on the floor, kept out of the ability
 * datums so every tunable number lives in exactly one place.
 *
 * - [/obj/structure/hoarfrost_ice_chunk] - Avalanche's calving. Dense, opaque,
 *   destructible, self-melting. She walks through her own chunks; you do not.
 * - [/obj/effect/hoarfrost_killing_zone] - the inverted kill field: safe INSIDE
 *   two tiles of the epicentre, lethal outside it. This is the one and only
 *   implementation of Killing Cold. Her ability spawns one and so does the
 *   Matriarch's Heart deployable, so a playtest retune of the numbers at the
 *   top of this file retunes both callers at once. Do not reimplement it.
 * - [/proc/hoarfrost_paint_zone] - the shared footprint painter, so the
 *   ability's telegraph, the deployable's arming warning and the live field all
 *   draw the player the same picture.
 * - [/obj/effect/hoarfrost_rime] - Rimebreath's residue.
 *
 * The cold's "does this care about you" rule is [/proc/hoarfrost_shrugs_off_cold],
 * shared by the field and the residue, so the rimeward cloak counters both.
 */

/// How close to the epicentre you have to be for Killing Cold to spare you.
#define HOARFROST_SAFE_RADIUS 2
/// Outer bound of the kill field. Matches the Matriarch's disengage range, so
/// "close enough to be in the fight" and "close enough to be in the zone" are
/// the same statement - and a cast can never quietly execute an away team
/// somewhere else on the planet.
#define HOARFROST_LETHAL_RADIUS 14
/// Cold damage per second dealt to anything caught outside the safe ring.
/// This is meant to be lethal ground, not a nuisance - five seconds of standing
/// in the wrong place should be most of a healthbar, or the ability has no teeth
/// and the player never learns to run toward her.
#define HOARFROST_ZONE_DAMAGE 16
/// How long the field stays live once it blooms.
#define HOARFROST_ZONE_DURATION (5 SECONDS)

// =========================================================================
// KILLING COLD - the shared inverted field
// =========================================================================

/**
 * The inverted kill field. Everything further than [HOARFROST_SAFE_RADIUS] from
 * the epicentre freezes; everything closer is untouched. Spawned by the
 * Matriarch's Killing Cold ability and by the Matriarch's Heart deployable -
 * two callers, one code path.
 *
 * Pass the caster as the second `new` argument: they are exempt, and so is
 * anything sharing a *non-neutral* faction with them. Neutral is deliberately
 * not a shared faction here, or a player-deployed Heart would spare every other
 * player on the map and be worthless in a crew-vs-crew fight.
 */
/obj/effect/hoarfrost_killing_zone
	name = "killing cold"
	desc = "The air here is cold enough to kill. It gets warmer closer to the source."
	icon = 'icons/effects/effects.dmi'
	icon_state = "nothing"
	anchored = TRUE
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// Anything this close to us (or closer) is safe.
	var/safe_radius = HOARFROST_SAFE_RADIUS
	/// Outside safe_radius and out to here, the cold bites.
	var/lethal_radius = HOARFROST_LETHAL_RADIUS
	/// Cold damage dealt per second to anything caught outside the safe ring.
	var/damage_per_second = HOARFROST_ZONE_DAMAGE
	/// How long the field stays live. Read this off the *instance* rather than
	/// hardcoding the number again - Killing Cold times its inert window from it.
	var/zone_duration = HOARFROST_ZONE_DURATION
	/// Whoever put the field down. Never harmed by it.
	var/datum/weakref/creator_ref
	/// The caster's factions minus FACTION_NEUTRAL - spared by the cold.
	var/list/allied_factions
	/// Rate-limits the "you are freezing" warning to once a second per field.
	COOLDOWN_DECLARE(warn_cooldown)

/obj/effect/hoarfrost_killing_zone/Initialize(mapload, mob/living/creator)
	. = ..()
	if(!isnull(creator))
		creator_ref = WEAKREF(creator)
		if(length(creator.faction))
			allied_factions = creator.faction.Copy() - FACTION_NEUTRAL
	hoarfrost_paint_zone(src, zone_duration)
	new /obj/effect/temp_visual/circle_wave/hoarfrost(get_turf(src))
	playsound(src, 'sound/effects/magic/ethereal_exit.ogg', 75, TRUE)
	START_PROCESSING(SSfastprocess, src)
	QDEL_IN(src, zone_duration)

/obj/effect/hoarfrost_killing_zone/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	creator_ref = null
	allied_factions = null
	return ..()

/obj/effect/hoarfrost_killing_zone/process(seconds_per_tick)
	var/turf/epicentre = get_turf(src)
	if(isnull(epicentre))
		return PROCESS_KILL
	var/mob/living/exempt = creator_ref?.resolve()
	for(var/mob/living/victim in range(lethal_radius, epicentre))
		if(get_dist(epicentre, victim) <= safe_radius)
			continue
		if(victim == exempt)
			continue
		if(hoarfrost_shrugs_off_cold(victim, allied_factions))
			continue
		bite(victim, seconds_per_tick)

/**
 * Freeze one poor soul who is standing in the wrong half of the field.
 *
 * Deliberately NOT spread_damage: SSfastprocess ticks every 0.2s, so a tick is a
 * fraction of a point, and spreading that across six limbs rounds most of it away
 * at DAMAGE_PRECISION. Concentrated damage actually lands, and it reads to the
 * player as being hurt rather than as nothing happening.
 *
 * Feedback is deterministic once a second rather than a probability roll. A player
 * standing in a lethal field must never be left wondering whether it is on.
 */
/obj/effect/hoarfrost_killing_zone/proc/bite(mob/living/victim, seconds_per_tick)
	victim.apply_damage(damage_per_second * seconds_per_tick, BURN)
	victim.adjust_bodytemperature(-25 * seconds_per_tick)
	victim.apply_status_effect(/datum/status_effect/hoarfrost_chill/mild, 2 SECONDS)
	if(!COOLDOWN_FINISHED(src, warn_cooldown))
		return
	COOLDOWN_START(src, warn_cooldown, 1 SECONDS)
	to_chat(victim, span_userdanger("The cold is killing you - it is WARMER NEAR THE SOURCE!"))
	victim.playsound_local(get_turf(victim), 'sound/effects/magic/ethereal_exit.ogg', 40, TRUE)

/**
 * Paints the Killing Cold footprint: the safe disc in one colour and the first
 * lethal ring in another. Called by the ability's telegraph, by the deployable's
 * arming warning and by the field itself, so all three read identically and a
 * radius change here changes every one of them.
 *
 * Only the boundary ring is painted rather than the whole lethal area - the
 * outer edge is fourteen tiles out and nobody needs six hundred temp visuals to
 * be told "not here".
 */
/proc/hoarfrost_paint_zone(atom/epicentre, duration)
	var/turf/centre = get_turf(epicentre)
	if(isnull(centre) || duration <= 0)
		return
	for(var/turf/marked as anything in RANGE_TURFS(HOARFROST_SAFE_RADIUS + 1, centre))
		if(get_dist(centre, marked) <= HOARFROST_SAFE_RADIUS)
			new /obj/effect/temp_visual/hoarfrost_zone/safe(marked, duration)
		else
			new /obj/effect/temp_visual/hoarfrost_zone/lethal(marked, duration)

/**
 * The single "does the cold care about you" rule, shared by the killing field
 * and by Rimebreath's residue.
 *
 * Cold-immune things (the rimeward cloak, and the fauna that already lives on a
 * glacier - which is how the Matriarch's own entourage is spared) walk through
 * both untouched, as do non-neutral faction allies of whoever cast it.
 */
/proc/hoarfrost_shrugs_off_cold(mob/living/victim, list/allied_factions)
	if(QDELETED(victim) || victim.stat == DEAD)
		return TRUE
	if(HAS_TRAIT(victim, TRAIT_RESISTCOLD) || HAS_TRAIT(victim, TRAIT_SNOWSTORM_IMMUNE))
		return TRUE
	if(length(allied_factions) && length(victim.faction) && length(victim.faction & allied_factions))
		return TRUE
	return FALSE

// =========================================================================
// AVALANCHE - the ice chunks
// =========================================================================

/**
 * A slab of glacier ice dropped out of the sky. Blocks movement and sight, so
 * Avalanche cuts firing lanes rather than just dealing damage - but it is
 * destructible and melts on its own, so it is never a hard trap.
 *
 * The Matriarch passes through her own chunks. Without that she walls herself
 * in during the Calving, where Avalanche and Killing Cold fire together.
 */
/obj/structure/hoarfrost_ice_chunk
	name = "hoarfrost chunk"
	desc = "A slab of blue-black glacier ice, dropped hard enough to bury itself in the floor. It will melt soon enough."
	icon = 'voidcrew/icons/obj/hoarfrost.dmi'
	icon_state = "ice_chunk"
	density = TRUE
	opacity = TRUE
	anchored = TRUE
	max_integrity = 80
	can_atmos_pass = ATMOS_PASS_DENSITY
	resistance_flags = FREEZE_PROOF
	/// How long the chunk survives before it melts on its own.
	var/melt_time = 20 SECONDS
	/// Brute dealt to anything standing where the chunk lands.
	var/impact_damage = 15

/obj/structure/hoarfrost_ice_chunk/Initialize(mapload)
	. = ..()
	playsound(src, 'sound/effects/glass/glassbash.ogg', 55, TRUE)
	for(var/mob/living/caught in loc)
		crush(caught)
	QDEL_IN(src, melt_time)

/obj/structure/hoarfrost_ice_chunk/Destroy()
	// Covers both paths out: smashed apart, or melted by its own timer.
	var/turf/here = get_turf(src)
	if(here)
		playsound(here, SFX_SHATTER, 55, TRUE)
		new /obj/effect/temp_visual/hoarfrost_shatter(here)
	return ..()

/// Someone was standing where this chunk landed: hurt them and shove them clear.
/obj/structure/hoarfrost_ice_chunk/proc/crush(mob/living/caught)
	if(istype(caught, /mob/living/basic/hoarfrost_matriarch))
		return
	caught.apply_damage(impact_damage, BRUTE, spread_damage = TRUE)
	to_chat(caught, span_userdanger("[src] slams down on top of you!"))
	var/list/escape_turfs = list()
	for(var/turf/open/candidate in orange(1, src))
		if(!candidate.is_blocked_turf(exclude_mobs = TRUE))
			escape_turfs += candidate
	if(!length(escape_turfs))
		return
	caught.safe_throw_at(pick(escape_turfs), 1, 1, force = MOVE_FORCE_STRONG)

/obj/structure/hoarfrost_ice_chunk/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(istype(mover, /mob/living/basic/hoarfrost_matriarch))
		return TRUE

/obj/structure/hoarfrost_ice_chunk/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(istype(pass_info?.requester_ref?.resolve(), /mob/living/basic/hoarfrost_matriarch))
		return TRUE
	return ..()

// =========================================================================
// RIMEBREATH - the residue
// =========================================================================

/**
 * The frost Rimebreath leaves behind. Standing in it is a mild, refreshing slow
 * - the cone's real punishment is the heavy chill, this is the tax on walking
 * back through the lane she just carved.
 */
/obj/effect/hoarfrost_rime
	name = "rime"
	desc = "A crust of hoarfrost on the floor. Slow going."
	icon = 'voidcrew/icons/obj/hoarfrost.dmi'
	icon_state = "rime"
	// The art is already sparse frost flecks on transparency (~8% coverage), so
	// it reads as frost ON the floor rather than replacing it. Only a light
	// alpha knock-down is needed - do not re-tint, the palette is in the art.
	alpha = 200
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// How long a patch of rime lasts before it sublimates.
	var/residue_duration = 8 SECONDS
	/// Stoppable melt timer, so a second cone over the same turf refreshes it.
	var/melt_timer

/obj/effect/hoarfrost_rime/Initialize(mapload)
	. = ..()
	// One patch per turf: a second pass refreshes the one already there.
	for(var/obj/effect/hoarfrost_rime/existing in loc)
		if(existing == src)
			continue
		existing.reset_melt()
		return INITIALIZE_HINT_QDEL

	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
	reset_melt()
	for(var/mob/living/standing in loc)
		chill(standing)

/obj/effect/hoarfrost_rime/Destroy()
	melt_timer = null
	return ..()

/// (Re)starts the sublimation timer.
/obj/effect/hoarfrost_rime/proc/reset_melt()
	if(melt_timer)
		deltimer(melt_timer)
	melt_timer = QDEL_IN_STOPPABLE(src, residue_duration)

/obj/effect/hoarfrost_rime/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(isliving(arrived))
		chill(arrived)

/// Apply the mild, refreshing chill to whoever is standing on us.
/obj/effect/hoarfrost_rime/proc/chill(mob/living/walker)
	if(hoarfrost_shrugs_off_cold(walker))
		return
	walker.apply_status_effect(/datum/status_effect/hoarfrost_chill/mild)

// =========================================================================
// Telegraphs and flourishes
// =========================================================================

/// Flat tile marker used to paint the Killing Cold footprint.
/obj/effect/temp_visual/hoarfrost_zone
	icon = 'icons/mob/telegraphing/telegraph.dmi'
	icon_state = "blank_semi_transparent"
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	randomdir = FALSE
	duration = 2.5 SECONDS

/obj/effect/temp_visual/hoarfrost_zone/Initialize(mapload, new_duration)
	if(new_duration)
		duration = new_duration
	return ..()

/// Inside the ring. Stand here.
/obj/effect/temp_visual/hoarfrost_zone/safe
	color = COLOR_BLUE_LIGHT

/// The first tile of the kill field. Everything past it is worse.
/obj/effect/temp_visual/hoarfrost_zone/lethal
	color = COLOR_RED

/// The cone Rimebreath is about to breathe.
/obj/effect/temp_visual/hoarfrost_cone_telegraph
	icon = 'icons/mob/telegraphing/telegraph_holographic.dmi'
	icon_state = "target_box"
	color = COLOR_BLUE_LIGHT
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	randomdir = FALSE
	duration = 1.2 SECONDS

/obj/effect/temp_visual/hoarfrost_cone_telegraph/Initialize(mapload, new_duration)
	if(new_duration)
		duration = new_duration
	return ..()

/// The bloom that marks a Killing Cold field going live.
/obj/effect/temp_visual/circle_wave/hoarfrost
	color = COLOR_BLUE_LIGHT
	duration = 1 SECONDS
	amount_to_scale = 6

/// The shadow of a chunk that is already falling. Duration is passed in so it
/// always matches Avalanche's telegraph window rather than drifting from it.
/obj/effect/temp_visual/shadow_telegraph/hoarfrost

/obj/effect/temp_visual/shadow_telegraph/hoarfrost/Initialize(mapload, new_duration)
	if(new_duration)
		duration = new_duration
	return ..()

/// A chunk coming apart.
/obj/effect/temp_visual/hoarfrost_shatter
	icon = 'icons/effects/effects.dmi'
	icon_state = "blueshatter"
	randomdir = FALSE
	duration = 0.6 SECONDS

#undef HOARFROST_SAFE_RADIUS
#undef HOARFROST_LETHAL_RADIUS
#undef HOARFROST_ZONE_DAMAGE
#undef HOARFROST_ZONE_DURATION
