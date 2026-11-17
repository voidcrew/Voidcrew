/**
 * # The Cascade line's time dilation
 *
 * When a Cascade-line surge (ware_legend.dm, ware_line_sandy.dm) opens and no other player is within
 * SANDY_STOP_WITNESS_RANGE tiles, the world around the user runs in slow motion for the whole window:
 *
 *   model        window  world runs at
 *   street       6 s     50%
 *   service      7 s     35%
 *   Cascade T4   8 s     20%
 *
 * Pressing the surge again ends the window early, slow-mo and all, and the crash follows as usual. With another
 * player near (the user's own crewmates don't count: they slow like an NPC), the surge is the plain one; if one comes in range mid-surge, the slow-mo ends there and the surge
 * carries on without it. Only a player's surge does this (the user needs a ckey): an NPC criminal's lattice never does.
 *
 * Built on tg's time stop field (code/datums/proximity_monitor/fields/timestop.dm), hosted on the user so
 * it follows them. Anything it touches stays slowed until the effect ends, even once the user walks off. The
 * field re-checks for players every tick and ends at once if one comes in.
 *
 * No shortcuts on people. A slowed mob moves under a movespeed modifier, and every tick the field pushes its
 * timing deadlines back by the time it lost (next_move, ability cooldowns, AI behaviour cooldowns and the
 * blackboard deadlines listed in dilated_blackboard_keys(), ranged cooldowns). Slowed bodies take damage,
 * wounds and bleeding through tg as normal.
 *
 * Everything else in the field runs on the same slowed clock, through a few helpers below:
 * - cyberware_dilated_time() and cyberware_dilated_steps() turn a length of local time into real time, exact
 *   through the slow-mo and its end. Hyperviolence gore uses them (flinches, death throes, blood paint, flying
 *   gibs), and so do a mech's weapon and melee cooldowns and a gun's fire delay.
 * - cyberware_time_lost() stretches do_after for a slowed body (VOIDCREW EDIT in do_after).
 * - Burst shots wait on a burst clock the field pushes back (cyberware_burst_wait()), so a burst queued before
 *   the slow-mo slows with it: guns (gun.dm) and basic mob ranged attacks (ranged_attacks.dm).
 * - The field pushes back mech move cooldowns, turret fire cooldowns and lit grenade fuses (_grenade.dm).
 * Things in hand stay held until the effect ends; gore and blood that merely stand in the field are slowed
 * while they are within its range. The user and anything the user carries are never slowed.
 * Nothing is ever frozen: the field never sends tg's time stop signals, so a supermatter keeps running.
 *
 * Bosses (a finisher user, or a boss-rank human NPC) are slowed for SANDY_STOP_BOSS_HOLD at most.
 *
 * Each surge model speeds its bearer up by a time multiplier (the lattice's time_multiplier): street 2x, service
 * about 2.86x, Cascade 5x. A mob on its own surge (a bounty NPC's lattice) runs at its multiplier over the user's,
 * at most SANDY_STOP_MAX_RELATIVE, for as long as both windows are open: a street NPC in a Cascade's field at 40%,
 * an equal tier at 100% (left alone), a Cascade NPC in a street user's field at 200% (2.5x, capped). Faster than
 * the user runs the same machinery the other way (its deadlines, cooldowns, walk and gore come sooner). A surging
 * mob is never tinted, at any rate. If it surges while already held, the field lets it go at once, drops every
 * slow it was carrying (surge_free()) and takes it back at its relative rate. When its window closes the field
 * takes it at the field's own pace, unless it is dead: a corpse freed by a surge is left as it fell.
 *
 * The user's reflex dodge (ware_pro_combat.dm) is off while the world is slowed: the speed gap already does that
 * job. It comes back if the slow-mo ends before the window does.
 *
 * Look: affected things get a grey-green tint instead of tg's inversion, and so does blood (decals, sprays,
 * splatters), spent casings and shooter effects; a tinted decal's drying colour waits for the tint to come off. Floor
 * items and the user keep their colour, and so do the shots, flashes and casings of the user and any surging mob.
 * Every bullet and every throw in the field flies at the field's pace, whoever started it, and gets its speed back
 * when let go; a body on its own time (the user, a surging mob) that is itself thrown flies at its own speed.
 */

/// Another player within this many tiles of the user means no dilation.
#define SANDY_STOP_WITNESS_RANGE 11
/// Radius of the field around the user (a 19x15 widescreen view is 9 tiles to each side and 7 up and down). It also
/// takes the rest of the user's room (ware_sandy_timestop_cover.dm).
#define SANDY_STOP_FIELD_RANGE 11
/// How long a boss stays slowed before it shrugs the field off.
#define SANDY_STOP_BOSS_HOLD (1 SECONDS)
/// The fastest a surging mob runs in someone else's field, relative to normal speed.
#define SANDY_STOP_MAX_RELATIVE 2
/// Relative rates this close to 1 count as the same speed: the mob is left alone.
#define SANDY_STOP_SAME_RATE 0.01
/// How long the tint's front takes per tile past the ring's own size, out to the field's edge and the room beyond.
#define SANDY_STOP_RING_TAIL 0.4
/// Filter name of the user's edge glow.
#define SANDY_STOP_OUTLINE "sandy_time_stop_outline"
/// Fullscreen category of the release flash.
#define SANDY_STOP_FLASH "sandy_time_stop_flash"
/// Filter name (and KEEP_TOGETHER source) of the slow-mo's tint on bodies and items. Same as SANDY_REPLAY_TINT.
#define SANDY_STOP_TINT "sandy_time_stop_tint"
/// The longest a slow-mo is held past its end for its user's execution or finisher to finish inside it.
#define SANDY_STOP_HOLD_MAX (6 SECONDS)
/// How long the slow-mo still holds once that move is over: its last blow (a shot's flash, the flinch, the gore) lands
/// inside the slow-mo, not in the first tick after it. SANDY_REPLAY_MOVE_TAIL in ware_sandy_replay.dm is as long.
#define SANDY_STOP_HOLD_TAIL 5

/// Every atom the dilation has hold of, to its field.
GLOBAL_LIST_EMPTY(cyberware_time_dilated)

/// How fast time runs for `thing`: 1 normally, below 1 in slow-mo, above 1 for a faster surger.
/proc/cyberware_time_scale(atom/thing)
	if(isnull(thing))
		return 1
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[thing]
	return field ? field.scale_for(thing) : 1

/// Every dilation field running now.
GLOBAL_LIST_EMPTY(cyberware_time_fields)
/// world.time and nesting depth while an untinted shooter spawns turf effects that carry no firer ref of their own.
GLOBAL_VAR_INIT(cyberware_untinted_fx_at, -1)
GLOBAL_VAR_INIT(cyberware_untinted_fx_depth, 0)

/// Whether an untinted shooter is spawning turf effects right now on this tick.
/proc/cyberware_untinted_fx_active()
	if(GLOB.cyberware_untinted_fx_at != world.time)
		GLOB.cyberware_untinted_fx_depth = 0
		return FALSE
	return GLOB.cyberware_untinted_fx_depth > 0

/// Unwraps a held, chambered or mounted item to whatever carries it.
/proc/cyberware_actor_root(atom/actor)
	while(isitem(actor) && ismovable(actor.loc))
		actor = actor.loc
	return actor

/// Whether `actor` keeps its own colours in a running slow-mo (the user, their ride, a surging mob, a freed boss).
/proc/cyberware_untinted_actor(atom/actor)
	actor = cyberware_actor_root(actor)
	if(isnull(actor) || !length(GLOB.cyberware_time_fields))
		return FALSE
	var/datum/proximity_monitor/advanced/timestop/sandevistan/holder = GLOB.cyberware_time_dilated[actor]
	if(istype(holder))
		return !!(holder.surging[actor] || holder.immune[actor] || holder.released[actor] || holder.own_ride(actor))
	if(cyberware_own_surge(actor))
		return TRUE
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field.immune[actor] || field.surging[actor] || field.released[actor] || field.own_ride(actor))
			return TRUE
		if(ismob(actor))
			var/mob/person = actor
			if(person.can_block_magic(field.antimagic_flags))
				return TRUE
	return FALSE

/// The field that tints small effects or casings made by `maker` at `where`, or null when `maker` keeps its colours.
/proc/cyberware_maker_field(atom/maker, atom/where)
	maker = cyberware_actor_root(maker)
	if(!length(GLOB.cyberware_time_fields))
		return null
	if(maker)
		var/datum/proximity_monitor/advanced/timestop/sandevistan/holder = GLOB.cyberware_time_dilated[maker]
		if(istype(holder))
			if(holder.surging[maker] || holder.immune[maker] || holder.released[maker] || holder.own_ride(maker))
				return null
			return holder
		if(cyberware_untinted_actor(maker))
			return null
	var/turf/spot = get_turf(where || maker)
	if(!spot)
		return null
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(maker && (sandy_session_shares(field, maker) || field.cover_outsider(maker)))
			continue
		if(field.tinted[spot])
			return field
		var/turf/centre = get_turf(field.host)
		if(centre && centre.z == spot.z && get_dist(centre, spot) <= field.current_range)
			return field
	return null

/// The field that slows a throw of `thing` starting or flying here, if any. A body on its own time (own_time()) flies
/// at its own speed.
/proc/cyberware_throw_field(atom/movable/thing)
	if(isnull(thing) || !length(GLOB.cyberware_time_fields))
		return null
	var/datum/proximity_monitor/advanced/timestop/sandevistan/held = GLOB.cyberware_time_dilated[thing]
	if(istype(held))
		return held.own_time(thing) ? null : held
	var/turf/spot = get_turf(thing)
	if(!spot)
		return null
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field.cover_outsider(thing) || field.own_time(thing))
			continue
		if(field.tinted[spot])
			return field
		var/turf/centre = get_turf(field.host)
		if(centre && centre.z == spot.z && get_dist(centre, spot) <= field.current_range)
			return field
	return null

/**
 * The field `thing` runs slow in: the one holding it, or one it stands inside (blood, gibs, a grenade on the
 * floor). Never for the user, anything the user carries, or a living thing the field didn't take.
 */
/proc/cyberware_time_field(atom/thing)
	if(isnull(thing) || !length(GLOB.cyberware_time_fields))
		return null
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[thing]
	if(field)
		return field
	if(isliving(thing))
		return null
	var/turf/here = get_turf(thing)
	if(!here)
		return null
	var/atom/on_turf = ismovable(thing) ? get_atom_on_turf(thing) : thing
	for(field as anything in GLOB.cyberware_time_fields)
		if(field.immune[thing] || field.immune[on_turf] || field.released[on_turf] || field.surging[on_turf])
			continue
		var/turf/centre = get_turf(field.host)
		if(centre && centre.z == here.z && get_dist(centre, here) <= field.current_range)
			return field
	return null

/// Whether `bearer` is slowing the world around them right now.
/proc/cyberware_time_stopping(mob/living/bearer)
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field.host == bearer)
			return TRUE
	return FALSE

/// Whether `thing` is a mob with its own Cascade surge window open. Such a mob runs at its own speed in any field.
/proc/cyberware_own_surge(atom/thing)
	if(!isliving(thing))
		return FALSE
	var/mob/living/body = thing
	return !!body.has_status_effect(/datum/status_effect/cyberware_cascade_window)

/// `surger` just opened its own surge window at `multiplier`: every field lets it go and runs it at its relative
/// rate until the window closes.
/proc/cyberware_surge_frees(mob/living/surger, multiplier)
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field.host != surger)
			field.surge_free(surger, multiplier)

/// Whether some other user's field is running `surger` at its relative rate.
/proc/cyberware_surge_in_field(mob/living/surger)
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field.surging[surger])
			return TRUE
	return FALSE

/// A field just took or let go of `surger`: its surge's own edge goes off or back on (ware_legend.dm).
/proc/cyberware_surge_refresh_perks(mob/living/surger)
	if(QDELETED(surger))
		return
	var/datum/status_effect/cyberware_cascade_window/window = surger.has_status_effect(/datum/status_effect/cyberware_cascade_window)
	window?.refresh_perks()

/// The time multiplier of `body`'s open surge window, or 1 with none.
/proc/cyberware_surge_multiplier(mob/living/body)
	if(!isliving(body))
		return 1
	var/datum/status_effect/cyberware_cascade_window/window = body.has_status_effect(/datum/status_effect/cyberware_cascade_window)
	return window ? window.time_multiplier : 1

/// A surge's tell is about to play on `body`: let its own colours show through the field's tint while it winds up.
/proc/cyberware_time_untint(mob/living/body)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[body]
	field?.escape_the_negative_zone(body)

/// The tell on `body` is over: if the field still holds it at its own pace, tint it again.
/proc/cyberware_time_retint(mob/living/body)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[body]
	if(field && !field.surging[body])
		field.into_the_negative_zone(body)

/// How long, in real time, `time` deciseconds of `thing`'s own time take from now. Exact through the slow-mo
/// and the end of the effect, as the field stands now.
/proc/cyberware_dilated_time(atom/thing, time)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_time_field(thing)
	if(!field)
		return time
	return field.real_time_for(thing, time)

/**
 * Real-time lengths for a chain of animation steps `times` on `thing`: list(step 1, step 2, ...), or null when it
 * isn't slowed. A looping chain just plays at the field's pace. `tag` names the animation, so a held mob that
 * breaks free (surge_free()) can drop it.
 */
/proc/cyberware_dilated_steps(atom/thing, list/times, loop = 1, tag)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_time_field(thing)
	if(!field)
		return null
	if(tag && field.held_mobs[thing])
		LAZYOR(field.slowed_tags[thing], tag)
	var/list/real = list()
	if(loop != 1)
		var/scale = field.scale_for(thing)
		for(var/time in times)
			real += time / scale
		return real
	var/local = 0
	var/reached = 0
	for(var/time in times)
		local += time
		var/at = field.real_time_for(thing, local)
		real += max(at - reached, 0)
		reached = at
	return real

/// Time `thing` lost in the last `elapsed` deciseconds: none of it outside a field. Negative for a surger running
/// faster than normal: it gained time.
/proc/cyberware_time_lost(atom/thing, elapsed)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[thing]
	if(!field || elapsed <= 0)
		return 0
	return elapsed * (1 - field.scale_for(thing))

/// Time a held `thing` has lost since the field last pushed its deadlines back.
/proc/cyberware_time_lag(atom/thing)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[thing]
	if(!field)
		return 0
	return (world.time - field.last_tick) * (1 - field.scale_for(thing))

/// A burst clock's start for a burst beginning now. The field pushes it back with the shooter's deadlines.
/proc/cyberware_burst_clock(atom/shooter)
	return world.time - cyberware_time_lag(shooter)

/// How much longer shot `index` (0 for the first) of a burst begun at `start`, `gap` apart, has to wait.
/proc/cyberware_burst_wait(atom/shooter, start, gap, index)
	if(!GLOB.cyberware_time_dilated[shooter])
		return max(start + gap * index - world.time, 0)
	var/due = start + cyberware_time_lag(shooter) + gap * index
	return due - world.time >= world.tick_lag ? due - world.time : 0

/// Whether a player other than `user` is within `range` tiles: any living body with a ckey, connected or not. The user's
/// own crewmates don't count: they are slowed with the rest of the world, like an NPC.
/proc/cyberware_time_stop_witnessed(mob/living/user, range = SANDY_STOP_WITNESS_RANGE)
	var/turf/here = get_turf(user)
	if(!here)
		return TRUE
	var/datum/team/user_crew = cyberware_crew_team(user) // ware_pro_combat.dm
	for(var/atom/movable/found as anything in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_HEARING, range))
		if(found == user)
			continue
		if(isliving(found))
			var/mob/living/body = found
			if(body.ckey && (!user_crew || cyberware_crew_team(body) != user_crew))
				return TRUE
			continue
		if(ismob(found)) // ghosts and camera eyes don't count
			continue
		// a locker or a mech with a player in it, or a small player picked up and carried as an item
		for(var/mob/living/inside in found.get_all_contents())
			if(inside != user && inside.ckey && (!user_crew || cyberware_crew_team(inside) != user_crew))
				return TRUE
	return FALSE

/// Whether `victim` is a boss: anything with a finisher, or a boss-rank human NPC.
/proc/cyberware_time_stop_boss(mob/living/victim)
	if(victim.GetComponent(/datum/component/hv_finisher_user))
		return TRUE
	if(istype(victim, /mob/living/carbon/human/npc))
		var/mob/living/carbon/human/npc/person = victim
		return person.npc_rank >= HUMAN_NPC_RANK_BOSS
	return FALSE

/// The grey-green wash on dilated things.
/proc/cyberware_time_stop_tint()
	var/static/list/tint = list(0.26,0.28,0.27, 0.52,0.56,0.54, 0.10,0.11,0.105, 0.02,0.05,0.04)
	return tint

/// The wash over something drawn in `colour` (a sprite coloured white-to-`colour` by its `color`): the tint's rows
/// scaled by that colour, so it reads as that colour seen through the wash.
/proc/cyberware_time_tint_of(colour)
	var/list/mixed = cyberware_time_stop_tint().Copy()
	var/list/rgb = istext(colour) ? rgb2num(colour) : null
	if(length(rgb) < 3)
		return mixed
	for(var/row in 0 to 2)
		for(var/column in 1 to 3)
			mixed[row * 3 + column] *= rgb[row + 1] / 255
	return mixed

/// Whether `thing` wears the slow-mo's tint as a colour filter. Bodies and items carry their blood as RESET_COLOR
/// overlays (wounds, gore, bloody clothes, stains on a severed limb), which a tint in `color` never reaches; a filter
/// covers the whole drawn atom, overlays included. It also leaves `atom_colours` alone, so a body's own temporary
/// colour (a chem, a perk) is still there when the tint comes off.
/proc/cyberware_time_tints_by_filter(atom/thing)
	return isliving(thing) || isitem(thing) || sandy_rig_picture(thing) // a rig picture animates its own colour (a flash)

/// Puts the slow-mo's tint on `thing`.
/proc/cyberware_time_tint_on(atom/thing)
	if(cyberware_time_tints_by_filter(thing))
		// While another colour filter was animated on a tinted body (hyperviolence's hit flash), the client drew
		// it in full colour: the flash runs through this filter instead (cyberware_time_flash()).
		thing.remove_filter("hv_vis_flash") // a hit flash already running would show the body in full colour
		thing.add_filter(SANDY_STOP_TINT, 20, color_matrix_filter(cyberware_time_stop_tint()))
		ADD_KEEP_TOGETHER(thing, SANDY_STOP_TINT)
		return
	// A blood splash, bead, strand or hitscan beam carries its colour in `color` alone, which the tint replaces: kept as
	// its own colour, so it gets that colour back (not white) when the tint comes off.
	if((istype(thing, /obj/effect/temp_visual) || istype(thing, /obj/effect/ebeam) || istype(thing, /obj/effect/projectile)) && istext(thing.color) && !LAZYACCESS(thing.atom_colours, FIXED_COLOUR_PRIORITY))
		thing.add_atom_colour(thing.color, FIXED_COLOUR_PRIORITY)
	thing.add_atom_colour(cyberware_time_tint_for(thing), TEMPORARY_COLOUR_PRIORITY)
	if(istype(thing, /obj/effect/decal/cleanable/blood/gibs)) // its meat is a RESET_COLOR overlay: see its update_overlays()
		thing.update_appearance(UPDATE_OVERLAYS)

/**
 * The tint `thing` wears in `color`. The tint replaces its colour, so a sprite drawn white and coloured by its `color` (a
 * blood splash, a bead, a gut strand, a hitscan beam: greyscale art) would show its white art through the wash, near white.
 * A temp visual, beam or hitscan piece whose own colour is kept at FIXED_COLOUR_PRIORITY (cyberware_time_tint_on()) wears
 * the wash over that colour instead. A blood decal works its own out in update_blood_color().
 */
/proc/cyberware_time_tint_for(atom/thing)
	if(!istype(thing, /obj/effect/temp_visual) && !istype(thing, /obj/effect/ebeam) && !istype(thing, /obj/effect/projectile))
		return cyberware_time_stop_tint()
	var/list/own = LAZYACCESS(thing.atom_colours, FIXED_COLOUR_PRIORITY)
	if(!own || own[ATOM_COLOR_TYPE_INDEX] == ATOM_COLOR_TYPE_FILTER || !istext(own[ATOM_COLOR_VALUE_INDEX]))
		return cyberware_time_stop_tint()
	return cyberware_time_tint_of(own[ATOM_COLOR_VALUE_INDEX])

/// tg gave `thing` (tinted in `color`) a colour of its own over the tint: kept as its own colour, and the tint put back over it.
/proc/cyberware_time_recolour_tinted(atom/thing)
	if(istext(thing.color))
		thing.add_atom_colour(thing.color, FIXED_COLOUR_PRIORITY)
	thing.add_atom_colour(cyberware_time_tint_for(thing), TEMPORARY_COLOUR_PRIORITY)

/// `first` then the slow-mo's tint, as one colour matrix (both 12-number RGB matrices).
/proc/cyberware_time_tint_after(list/first)
	var/list/tint = cyberware_time_stop_tint()
	var/list/out = list()
	for(var/row in 0 to 3)
		for(var/column in 1 to 3)
			var/sum = row == 3 ? tint[9 + column] : 0
			for(var/k in 0 to 2)
				sum += first[row * 3 + k + 1] * tint[k * 3 + column]
			out += sum
	return out

/**
 * A hit flash (`flash`, a colour matrix held for `times`: in, hold, out) on a `body` the slow-mo tints. The client
 * drew a tinted body in full colour while a second colour filter was animated on it, so the flash plays through the
 * tint filter itself: tint over the flash, held, then back to the plain tint. FALSE if the body isn't tinted.
 */
/proc/cyberware_time_flash(atom/body, list/flash, list/times)
	var/tint_filter = body.filter_data?[SANDY_STOP_TINT] && body.get_filter(SANDY_STOP_TINT)
	if(!tint_filter)
		return FALSE
	var/list/flashed = cyberware_time_tint_after(flash)
	// Beside the body's own animations: with a killing blow's death slump started the same tick, the client played the
	// flash seconds late and near white, a corpse glowing in the middle of the slow-mo.
	animate(tint_filter, color = flashed, time = times[1], easing = LINEAR_EASING, flags = ANIMATION_PARALLEL)
	animate(color = flashed, time = times[2], easing = LINEAR_EASING)
	animate(color = cyberware_time_stop_tint(), time = times[3], easing = LINEAR_EASING)
	return TRUE

/// Takes the slow-mo's tint off `thing`.
/proc/cyberware_time_tint_off(atom/thing)
	if(cyberware_time_tints_by_filter(thing))
		thing.remove_filter(SANDY_STOP_TINT)
		REMOVE_KEEP_TOGETHER(thing, SANDY_STOP_TINT)
		return
	thing.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY)
	if(istype(thing, /obj/effect/decal/cleanable/blood/gibs))
		thing.update_appearance(UPDATE_OVERLAYS)

/// Whether `thing` is drawn with the slow-mo's tint right now.
/proc/cyberware_time_has_tint(atom/thing)
	if(cyberware_time_tints_by_filter(thing))
		return !!thing.filter_data?[SANDY_STOP_TINT]
	var/list/entry = LAZYACCESS(thing.atom_colours, TEMPORARY_COLOUR_PRIORITY)
	if(!entry || !islist(entry[ATOM_COLOR_VALUE_INDEX]))
		return FALSE
	var/list/worn = entry[ATOM_COLOR_VALUE_INDEX]
	return compare_list(worn, cyberware_time_stop_tint()) || compare_list(worn, cyberware_time_tint_for(thing))

/// Blood and loose gore the field tints like the world around it (it is only looked at, never held): nothing about
/// gore is in colour in the slow-mo. Severed parts and spilled intestines are items, which otherwise keep their colour
/// on the floor.
/proc/cyberware_time_tinted_blood(atom/thing)
	var/static/list/blood = typecacheof(list(
		/obj/effect/decal/cleanable/blood,
		/obj/effect/temp_visual/dir_setting/bloodsplatter,
		/obj/effect/temp_visual/hv_blood_bead,
		/obj/effect/temp_visual/wire_blood_drop,
		/obj/item/hv_intestines,
		/obj/effect/ebeam/hv_gut,
		/obj/item/bodypart,
		/obj/item/organ,
	))
	if(!blood[thing.type])
		return FALSE
	return isturf(thing.loc) // a part or organ still in a body, a hand or a bag is not loose gore

/obj/item/ammo_casing
	/// Weakref to the untinted actor who fired or ejected this casing while a slow-mo ran, so it keeps its colour.
	var/datum/weakref/sandy_untinted_by

/// Whether `casing` was dropped or fired by someone who acts in their own colours in the current slow-mo.
/proc/cyberware_casing_keeps_colour(obj/item/ammo_casing/casing)
	var/atom/actor = casing.sandy_untinted_by?.resolve()
	return actor && cyberware_untinted_actor(actor)

/// Whether `shot` belongs to a shooter whose shots and hit effects stay in colour.
/proc/cyberware_shot_untinted(obj/projectile/shot)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/holder = GLOB.cyberware_time_dilated[shot]
	if(istype(holder) && holder.user_shots[shot])
		return TRUE
	return shot.firer && cyberware_untinted_actor(shot.firer)

/// Spent casings and turf shot effects the field tints like the floor, unless an untinted shooter made them.
/proc/cyberware_time_tinted_shot_trash(atom/thing)
	if(!isturf(thing.loc))
		return FALSE
	if(istype(thing, /obj/item/ammo_casing))
		return !cyberware_casing_keeps_colour(thing)
	if(istype(thing, /obj/effect/projectile) || istype(thing, /obj/effect/temp_visual/dir_setting/firing_effect) || istype(thing, /obj/effect/temp_visual/impact_effect))
		return !cyberware_untinted_fx_active()
	return FALSE

/// tg works a blood decal's drying colour out of its `color` (blending it toward the dried colour), and its sprite is
/// white, coloured by that `color`. With the slow-mo's tint matrix in `color` it would be drawn white and its drying
/// colour lost, so while tinted it wears the tint mixed with its own colour, held where it was. It works its colour
/// out again when the tint comes off (update_atom_colour() calls this). A colour filter didn't draw on decals.
/// Blood made in the slow-mo wears it from its first picture: tg starts its drying animation (from its own colour, a
/// text colour) as it is made, before the field tints it, and the client drew that blood white, its art with no colour,
/// until the decal's next animation ended.
/obj/effect/decal/cleanable/blood/update_blood_color()
	if(!sandy_time_tinted() && !sandy_time_tint_due())
		return ..()
	animate(src)
	var/own = sandy_replay_colour() // ware_sandy_replay.dm
	if(!istext(own))
		return TRUE
	color = cyberware_time_tint_of(own)
	return TRUE

/// Whether the slow-mo's tint is on this blood right now.
/obj/effect/decal/cleanable/blood/proc/sandy_time_tinted()
	return islist(color) && LAZYACCESS(atom_colours, TEMPORARY_COLOUR_PRIORITY) && GLOB.cyberware_time_dilated[src]

/// Whether this blood is being made on a slow-mo's ground that the field will tint it on this tick (once it is made).
/obj/effect/decal/cleanable/blood/proc/sandy_time_tint_due()
	if(!length(GLOB.cyberware_time_fields) || GLOB.cyberware_time_dilated[src] || !isturf(loc))
		return FALSE
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_time_field(src)
	return istype(field) && field.ring_wait(src) <= 0

/// tg's create_splatter() sets the splash's colour after making it, over the slow-mo's tint: the tint goes back on.
/mob/living/create_splatter(splatter_dir = pick(GLOB.cardinals))
	. = ..()
	for(var/obj/effect/temp_visual/dir_setting/bloodsplatter/splatter in get_turf(src))
		if(GLOB.cyberware_time_dilated[splatter] && cyberware_time_has_tint(splatter))
			cyberware_time_recolour_tinted(splatter)

/// tg's Draw() gives a beam's last, cut-short segment the beam's colour right after making it, over the tint the
/// field put on it as it was made (a gut strand's end showed raw in the slow-mo): the tint goes back on, and a
/// strand drawn in the slow-mo has its picture in vis_contents tinted at once rather than on the next field tick.
/datum/beam/Draw()
	. = ..()
	for(var/obj/effect/ebeam/segment as anything in elements)
		if(QDELETED(segment) || !cyberware_time_has_tint(segment))
			continue
		if(istext(segment.color) && !LAZYACCESS(segment.atom_colours, FIXED_COLOUR_PRIORITY))
			segment.add_atom_colour(segment.color, FIXED_COLOUR_PRIORITY) // its own colour again once the tint comes off
		segment.add_atom_colour(cyberware_time_tint_for(segment), TEMPORARY_COLOUR_PRIORITY) // the wash over that colour
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[segment]
		if(istype(field))
			field.tint_blood_bits(segment)

/obj/effect/decal/cleanable/blood/gibs
	/// Set while sandy_untinted_overlays() builds the overlays as they are without the slow-mo's tint.
	var/sandy_skip_tint = FALSE

/obj/effect/decal/cleanable/blood
	/// The pace tg sends it across the floor at (the delay of its move loop), kept while a field stretches it.
	var/sandy_flight_delay

/**
 * tg sends a gib across the floor (streak()), and the blood knocked out of a body by a hit (the hitsplatter's
 * fly_towards()), on move loops of their own, a tile every couple of deciseconds. Nothing slowed those: in a field a gib
 * shot off at full speed while its tumble (hyperviolence/visuals/flying_gore.dm) crawled, a hit's blood crossed three
 * tiles before the bullet that drew it had crossed one, and the replay showed both as many times too fast. Each step
 * takes the field's time, worked out a step at a time, so one still on its way when the slow-mo ends goes on at its own
 * pace. Call it once the loop is running.
 */
/obj/effect/decal/cleanable/blood/proc/sandy_slow_flight()
	if(QDELETED(src) || !length(GLOB.cyberware_time_fields))
		return
	var/datum/move_loop/loop = move_packet?.running_loop
	if(QDELETED(loop))
		return
	sandy_flight_delay = loop.delay
	RegisterSignal(src, COMSIG_MOVABLE_MOVED_FROM_LOOP, PROC_REF(sandy_flight_stepped), override = TRUE)
	if(sandy_flight_pace(loop))
		loop.pause_for(loop.delay) // its first step was due at tg's pace

/// Signal proc for [COMSIG_MOVABLE_MOVED_FROM_LOOP]: the step after this one takes what the field it is in now makes of it.
/obj/effect/decal/cleanable/blood/proc/sandy_flight_stepped(atom/movable/source, datum/move_loop/loop)
	SIGNAL_HANDLER
	if(!QDELETED(loop))
		sandy_flight_pace(loop)

/// Sets `loop` (the flight's) to the field's pace, keeping the steps it has left. Returns TRUE if that changed it.
/obj/effect/decal/cleanable/blood/proc/sandy_flight_pace(datum/move_loop/loop)
	var/pace = max(cyberware_dilated_time(src, sandy_flight_delay), world.tick_lag)
	if(pace == loop.delay)
		return FALSE
	loop.lifetime *= pace / loop.delay // counted down by the delay a step: the same steps left
	loop.set_delay(pace)
	return TRUE

/**
 * Short effects made inside a shooter (tg's firing_effect, gun_feel's muzzle flash) are drawn in their vis_contents,
 * where no field turf ever sees them. On a glowing user they are drawn apart so the user's edge glow doesn't wrap the
 * flash; on a slowed shooter the field tints them from their first frame, also drawn apart so the shooter's tint filter
 * doesn't wash over them a second time.
 */
/obj/effect/temp_visual/Initialize(mapload)
	. = ..()
	if(mapload || . == INITIALIZE_HINT_QDEL || !length(GLOB.cyberware_time_fields) || !ismovable(loc))
		return
	var/atom/movable/shooter = loc
	if(shooter.get_filter(SANDY_STOP_OUTLINE))
		appearance_flags |= KEEP_APART
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_maker_field(shooter, shooter)
	if(field)
		appearance_flags |= KEEP_APART
		field.take_looks(src)

/// Marks casings ejected by an untinted shooter before they hit the ground, and hands a slowed shooter's casing to
/// their field even in the outer reaches of a covered room.
/obj/item/gun/ballistic/handle_chamber(empty_chamber = TRUE, from_firing = TRUE, chamber_next_round = TRUE)
	var/obj/item/ammo_casing/casing = chambered
	var/atom/holder = cyberware_actor_root(src)
	if(istype(casing) && length(GLOB.cyberware_time_fields))
		casing.sandy_untinted_by = cyberware_untinted_actor(holder) ? WEAKREF(holder) : null
	. = ..()
	if(istype(casing) && !QDELETED(casing) && length(GLOB.cyberware_time_fields) && isturf(casing.loc) && !GLOB.cyberware_time_dilated[casing] && !cyberware_casing_keeps_colour(casing))
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_maker_field(holder, casing)
		field?.freeze_atom(casing)

/// Keeps casings and turf flashes fired without a ballistic gun (basic mobs' ranged_attacks, turrets) in step with
/// whoever fired them.
/obj/item/ammo_casing/throw_proj(atom/target, turf/targloc, mob/living/user, params, spread, atom/fired_from)
	if(!length(GLOB.cyberware_time_fields))
		return ..()
	var/atom/actor = cyberware_actor_root(user || fired_from)
	var/untinted = cyberware_untinted_actor(actor)
	sandy_untinted_by = untinted ? WEAKREF(actor) : null
	if(untinted)
		var/datum/proximity_monitor/advanced/timestop/sandevistan/holder = GLOB.cyberware_time_dilated[src]
		if(istype(holder) && !throwing)
			holder.unfreeze_atom(src)
		GLOB.cyberware_untinted_fx_at = world.time
		GLOB.cyberware_untinted_fx_depth++
	. = ..()
	if(untinted)
		GLOB.cyberware_untinted_fx_depth = max(GLOB.cyberware_untinted_fx_depth - 1, 0)
		return
	if(!QDELETED(src) && isturf(loc) && !GLOB.cyberware_time_dilated[src])
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_maker_field(actor, src)
		field?.freeze_atom(src)
	if(!user && firing_effect_type)
		var/turf/flash_spot = get_turf(src)
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = flash_spot ? cyberware_maker_field(actor, flash_spot) : null
		if(field)
			for(var/obj/effect/temp_visual/fx in flash_spot)
				if(istype(fx, firing_effect_type) && !GLOB.cyberware_time_dilated[fx])
					field.freeze_atom(fx)

/// Casings tipped out of a cylinder, box or hand take or skip the tint by whoever dropped them; picked up off the
/// floor, they drop the field's tint.
/obj/item/ammo_casing/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	var/on_floor = isturf(loc)
	if(on_floor == isturf(old_loc))
		return
	if(!on_floor)
		sandy_untinted_by = null
		if(!throwing)
			var/datum/proximity_monitor/advanced/timestop/sandevistan/holder = GLOB.cyberware_time_dilated[src]
			holder?.unfreeze_atom(src)
		return
	if(!length(GLOB.cyberware_time_fields) || !old_loc)
		return
	var/atom/actor = cyberware_actor_root(old_loc)
	if(cyberware_untinted_actor(actor))
		sandy_untinted_by = WEAKREF(actor)
		if(!throwing)
			var/datum/proximity_monitor/advanced/timestop/sandevistan/holder = GLOB.cyberware_time_dilated[src]
			holder?.unfreeze_atom(src)
	else if(!cyberware_casing_keeps_colour(src) && !GLOB.cyberware_time_dilated[src])
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_maker_field(actor, src)
		field?.freeze_atom(src)

/// Impact puffs stay untinted for an untinted shooter's round and take the tint for a slowed one's.
/obj/projectile/on_hit(atom/target, blocked = 0, pierce_hit)
	if(!length(GLOB.cyberware_time_fields))
		return ..()
	if(cyberware_shot_untinted(src))
		GLOB.cyberware_untinted_fx_at = world.time
		GLOB.cyberware_untinted_fx_depth++
		. = ..()
		GLOB.cyberware_untinted_fx_depth = max(GLOB.cyberware_untinted_fx_depth - 1, 0)
		return
	. = ..()
	if(impact_effect_type && !hitscan)
		var/turf/spot = get_turf(target)
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = spot ? cyberware_maker_field(firer || fired_from, spot) : null
		if(field)
			for(var/obj/effect/temp_visual/fx in spot)
				if(istype(fx, impact_effect_type) && !GLOB.cyberware_time_dilated[fx])
					field.freeze_atom(fx)

/// tg's hitscan sets its muzzle, tracer and impact colours after making them, over any tint the turf put on them:
/// put the wash back over a slowed shooter's beam, and leave an untinted shooter's beam in its own colour.
/obj/projectile/generate_hitscan_tracers(impact_point = TRUE, impact_visual = TRUE)
	if(!length(GLOB.cyberware_time_fields))
		return ..()
	if(cyberware_shot_untinted(src))
		GLOB.cyberware_untinted_fx_at = world.time
		GLOB.cyberware_untinted_fx_depth++
		. = ..()
		GLOB.cyberware_untinted_fx_depth = max(GLOB.cyberware_untinted_fx_depth - 1, 0)
		return
	. = ..()
	var/datum/proximity_monitor/advanced/timestop/sandevistan/maker_field = cyberware_maker_field(firer || fired_from, src)
	var/list/spots = list()
	if(isturf(loc))
		spots[loc] = TRUE
	if(last_point)
		var/turf/end_turf = last_point.return_turf()
		if(end_turf)
			spots[end_turf] = TRUE
	for(var/datum/point/pt as anything in beam_points)
		var/turf/pt_turf = pt.return_turf()
		if(pt_turf)
			spots[pt_turf] = TRUE
		var/datum/point/next_pt = beam_points[pt]
		var/turf/next_turf = next_pt?.return_turf()
		if(pt_turf && next_turf)
			for(var/turf/line_turf as anything in get_line(pt_turf, next_turf))
				spots[line_turf] = TRUE
	for(var/turf/spot as anything in spots)
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = maker_field || cyberware_maker_field(null, spot)
		for(var/obj/effect/projectile/beam_fx in spot)
			if(!GLOB.cyberware_time_dilated[beam_fx] && field)
				field.freeze_atom(beam_fx)
			var/datum/proximity_monitor/advanced/timestop/sandevistan/holder = GLOB.cyberware_time_dilated[beam_fx]
			if(istype(holder) && holder.tinted[beam_fx] && istext(beam_fx.color))
				cyberware_time_recolour_tinted(beam_fx)
				holder.replay?.resample(beam_fx)

/// Every throw started inside a dilation field skips tg's immediate full-speed first step and flies at the field's pace,
/// even for bodies already held in `held_mobs` or items already lying on the floor.
/atom/movable/throw_at(atom/target, range, speed, mob/thrower, spin = TRUE, diagonals_first = FALSE, datum/callback/callback, force = MOVE_FORCE_STRONG, gentle = FALSE, quickstart = TRUE, throw_datum_typepath = /datum/thrownthing)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = length(GLOB.cyberware_time_fields) ? cyberware_throw_field(src) : null
	if(field)
		quickstart = FALSE
	var/datum/thrownthing/previous = throwing
	. = ..()
	if(!. || !throwing || throwing == previous)
		return
	if(previous)
		for(var/datum/proximity_monitor/advanced/timestop/sandevistan/holder as anything in GLOB.cyberware_time_fields)
			if(holder.held_throws[src])
				holder.held_throws -= src
	field = field || (length(GLOB.cyberware_time_fields) ? cyberware_throw_field(src) : null)
	field?.take_throw(src)

/// Restores a slowed throw's real speed as it lands, before `finalize()` works out impact damage and zero-g drift.
/datum/thrownthing/finalize(hit = FALSE, target = null)
	set waitfor = FALSE
	if(thrownthing && length(GLOB.cyberware_time_fields))
		for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
			if(field.held_throws[thrownthing])
				field.finish_throw(thrownthing, src)
				break
	return ..()

/obj/effect/decal/cleanable/blood/gibs/streak(list/directions, mapload = FALSE)
	. = ..()
	if(!mapload)
		sandy_slow_flight()

/obj/effect/decal/cleanable/blood/hitsplatter/fly_towards(turf/target_turf, range)
	. = ..()
	sandy_slow_flight()

/// A gib's meat and bone are a KEEP_APART, RESET_COLOR overlay that the tint in `color` skips: tinted, it wears the
/// wash over its own colour too, and gets its colour back when the tint comes off (cyberware_time_tint_off()).
/obj/effect/decal/cleanable/blood/gibs/update_overlays()
	. = ..()
	if(sandy_skip_tint || !sandy_time_tinted())
		return
	for(var/mutable_appearance/bit in .)
		if(bit.appearance_flags & RESET_COLOR)
			bit.color = cyberware_time_tint_of(istext(bit.color) ? bit.color : COLOR_WHITE)

/// Swaps the tinted meat overlay in `look` (a copy of this gib's appearance) for the untinted one, so the replay
/// shows the meat in its own colour (ware_sandy_replay.dm, clean_look()).
/obj/effect/decal/cleanable/blood/gibs/proc/sandy_untinted_overlays(mutable_appearance/look)
	if(managed_overlays)
		look.overlays -= managed_overlays
	sandy_skip_tint = TRUE
	var/list/plain = update_overlays()
	sandy_skip_tint = FALSE
	for(var/overlay in plain)
		if(overlay)
			look.overlays += overlay

/// Flattens a sprite to luminance and paints it the dilation's green (#5AFF96).
/proc/cyberware_time_stop_green()
	var/static/list/green
	if(!green)
		var/red = 90 / 255
		var/grn = 1
		var/blue = 150 / 255
		// gain + lift = 1, so white maps to the green itself and black to a dim green
		var/gain = 0.65
		var/lift = 0.35
		green = list(
			0.3 * gain * red, 0.3 * gain * grn, 0.3 * gain * blue,
			0.59 * gain * red, 0.59 * gain * grn, 0.59 * gain * blue,
			0.11 * gain * red, 0.11 * gain * grn, 0.11 * gain * blue,
			lift * red, lift * grn, lift * blue,
		)
	return green

/// Blackboard keys holding world.time deadlines that slow down with their owner.
/proc/dilated_blackboard_keys()
	var/static/list/keys = list(
		BB_HUMAN_NPC_NEXT_SHOT,
		BB_HUMAN_NPC_RELOAD_UNTIL,
		BB_HUMAN_NPC_ARMING_RETRY_AT,
		BB_HUMAN_NPC_NEXT_TREAT,
		BB_HUMAN_NPC_FLEE_UNTIL,
		BB_BOUNTY_NEXT_STEP_AT,
		BB_BOUNTY_BACKSTEP_AT,
		BB_BOUNTY_BOSS_HUNT_AT,
		BB_BOUNTY_BOSS_RELOAD_UNTIL,
		BB_BASIC_MOB_REINFORCEMENTS_COOLDOWN,
		// defined and undefined inside their own modules
		"convict_hit_until",
		"convict_lost_since",
		"pirate_windup_until",
		"pirate_breach_started",
		"pirate_no_path_at",
		"pirate_breach_progress_at",
		"pirate_next_execution", // BB_PIRATE_NEXT_EXECUTION
		"BB_outpost_horror_hunt_at", // BB_OUTPOST_HORROR_HUNT_AT
	)
	return keys

/datum/movespeed_modifier/cyberware_dilation
	variable = TRUE

// =========================================================================
// THE EFFECT
// =========================================================================

/// Lives as long as the dilation, holds the field on the user, and ends it when deleted.
/obj/effect/timestop/sandevistan
	name = "stopped moment"
	desc = null
	hidden = TRUE
	alpha = 0
	freezerange = SANDY_STOP_FIELD_RANGE
	/// Whose dilation this is. The field is hosted on them.
	var/mob/living/user
	/// How fast the world runs.
	var/slow_scale = 1
	/// The user's own time multiplier (their surge model's), for surging mobs' relative rates.
	var/user_multiplier = 1
	/// The timer that ends the slow-mo when its time is up.
	var/end_timer

/// `immune_atoms` must be list(user). `time` is the whole effect, all of it at `scale`. `multiplier` is the user's
/// surge model's time multiplier.
/obj/effect/timestop/sandevistan/Initialize(mapload, radius, time, list/immune_atoms, start = TRUE, silent = TRUE, scale = 1, multiplier = 1)
	if(length(immune_atoms))
		user = immune_atoms[1]
	slow_scale = scale
	user_multiplier = multiplier
	return ..(mapload, radius, time, immune_atoms, start, TRUE)

/obj/effect/timestop/sandevistan/Destroy()
	deltimer(end_timer)
	end_timer = null
	user = null
	return ..()

/// The slow-mo's time is up. Its user's surge window decides when it really ends; without one it ends now.
/obj/effect/timestop/sandevistan/proc/time_up()
	end_timer = null
	var/datum/status_effect/cyberware_cascade_window/window = user?.has_status_effect(/datum/status_effect/cyberware_cascade_window)
	if(window?.time_stop == src)
		window.slowmo_time_up()
		return
	qdel(src)

/obj/effect/timestop/sandevistan/timestop()
	target = get_turf(src)
	// A tick before the window would close, so the window hears it first: an execution in progress holds the slow-mo
	// (cyberware_cascade_window/proc/slowmo_time_up()).
	end_timer = addtimer(CALLBACK(src, PROC_REF(time_up)), max(duration - world.tick_lag, world.tick_lag), TIMER_STOPPABLE | TIMER_DELETE_ME)
	if(QDELETED(user))
		return
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = new(user, freezerange, FALSE, immune, antimagic_flags, FALSE, slow_scale, user_multiplier) // a user inside a mech still slows the world
	field.stopper = src
	field.ends_at = world.time + duration
	chronofield = field

// =========================================================================
// THE FIELD
// =========================================================================

/datum/proximity_monitor/advanced/timestop/sandevistan
	/// The effect that owns this field. Deleting it ends the dilation.
	var/obj/effect/timestop/sandevistan/stopper
	/// How fast time runs in here, below 1.
	var/time_scale = 1
	/// world.time of the last tick, for how much time each tick dilated.
	var/last_tick = 0
	/// The field's own clock. A timer, not SSfastprocess, which sleeps outside RUNLEVEL_GAME.
	var/tick_timer
	/// Mobs in hand.
	var/list/held_mobs = list()
	/// Projectiles in hand, to their own speed.
	var/list/held_shots = list()
	/// Thrown things in hand, to their own speed.
	var/list/held_throws = list()
	/// The user's own shots: never tinted. A surging mob's held shots aren't tinted either.
	var/list/user_shots = list()
	/// Bosses in hand, to the world.time they shrug the field off.
	var/list/boss_holds = list()
	/// Bosses that already shrugged it off. The field leaves them be.
	var/list/released = list()
	/// world.time the effect ends, when time runs normally again.
	var/ends_at = INFINITY
	/// Mechs held. Their move cooldown runs slow.
	var/list/held_mechs = list()
	/// Turrets held. Their fire cooldown runs slow.
	var/list/held_turrets = list()
	/// Armed grenades held. Their fuse runs slow.
	var/list/held_grenades = list()
	/// Mobs in range running their own surge. The field leaves them and their shots be until their window closes.
	var/list/surging = list()
	/// Held mobs, to the tags of their slowed hv_vis_play() animations, to drop if they break free.
	var/list/slowed_tags = list()
	/// The user's slowed weather and sound (ware_sandy_senses.dm).
	var/datum/sandy_senses/senses
	/// The user's time multiplier. A surging mob runs at its own over this.
	var/user_multiplier = 1
	/// Surging mobs held at their relative rate, to that rate. Never 0, never tinted. Their shots fly at the field's pace.
	var/list/own_scales = list()
	/// Things that should wear the tint, to TRUE.
	var/list/tinted = list()
	/// Tinted things the ring hasn't reached yet, to the timer that tints them when it does.
	var/list/tint_timers = list()
	/// Where the green ring rolls out from, while it is rolling.
	var/turf/ring_center
	/// world.time the ring started rolling.
	var/ring_start = 0
	/// How long the ring takes to reach its full size.
	var/ring_time = 0
	/// The ring's full size, in tiles of radius.
	var/ring_reach = 0
	/// The recording of this slow-mo, played back when it ends (ware_sandy_replay.dm). Only a player's field has one.
	var/datum/sandy_replay/replay
	/// Tinted blood decals and gut strands, checked each tick for drips, trail pieces or strand pictures new in their vis_contents.
	var/list/blood_holders = list()
	/// The user's finisher rig pictures, to the glow drawn under each (glow_rig_picture()).
	var/list/rig_glows = list()

/datum/proximity_monitor/advanced/timestop/sandevistan/New(atom/_host, range, _ignore_if_not_on_turf = TRUE, list/immune, antimagic_flags, channelled, _time_scale = 1, _user_multiplier = 1)
	time_scale = _time_scale > 0 ? _time_scale : 1
	user_multiplier = _user_multiplier > 0 ? _user_multiplier : 1
	last_tick = world.time
	GLOB.cyberware_time_fields += src
	if(isliving(_host))
		var/mob/living/recorded = _host
		if(recorded.ckey)
			replay = new(src, recorded) // before the field takes its first turf, so it sees everything
	cover_preset_ring(_host) // ware_sandy_timestop_cover.dm
	. = ..()
	cover_start() // ware_sandy_timestop_cover.dm
	STOP_PROCESSING(SSfastprocess, src) // tick() runs on tick_timer instead
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), 0.2 SECONDS, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	RegisterSignal(host, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_user_fire))
	if(ismob(host))
		senses = new(src)

/datum/proximity_monitor/advanced/timestop/sandevistan/Destroy()
	QDEL_NULL(senses)
	cover_end() // ware_sandy_timestop_cover.dm
	deltimer(tick_timer)
	tick_timer = null
	if(host)
		UnregisterSignal(host, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)
	stopper = null
	GLOB.cyberware_time_fields -= src
	var/list/were_surging = surging.Copy()
	for(var/mob/living/surger as anything in surging)
		UnregisterSignal(surger, COMSIG_QDELETING)
	surging.Cut()
	. = ..() // unfreeze_all() lets everything go
	for(var/mob/living/surger as anything in were_surging)
		cyberware_surge_refresh_perks(surger) // a surge still open gets its own edge back
	own_scales.Cut()
	released.Cut()
	var/datum/sandy_replay/recording = replay
	replay = null
	recording?.field_over() // it plays back from here; a player cutting the slow-mo short cancelled it in tick()

/// How long, in real time from now, `local` deciseconds of `thing`'s own time take: its rate in the field until
/// the effect (or a boss's hold) ends, then real time.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/real_time_for(atom/thing, local)
	var/now = world.time
	var/ends = ends_at
	if(boss_holds[thing])
		ends = min(ends, boss_holds[thing])
	var/rate = scale_for(thing)
	if(ends <= now || rate == 1)
		return local
	var/span = (ends - now) * rate
	if(local <= span)
		return local / rate
	return ends - now + local - span

/// How fast time runs for `thing` in this field: a surger's own relative rate, 1 for a surger left alone, else the field's pace.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/scale_for(atom/thing)
	var/own = own_scales[thing]
	if(own)
		return own
	if(surging[thing])
		return 1
	return time_scale

/// The rate, against normal speed, of a mob surging at `multiplier` in this field. Capped at SANDY_STOP_MAX_RELATIVE.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/relative_rate(multiplier)
	if(!multiplier || multiplier <= 0)
		multiplier = 1
	return min(multiplier / user_multiplier, SANDY_STOP_MAX_RELATIVE)

/datum/proximity_monitor/advanced/timestop/sandevistan/freeze_atom(atom/movable/A)
	replay?.notice(A) // everything on, entering or made on a field turf comes through here
	if(sandy_session_shares(src, A)) // another member of a shared slow-mo runs in its own field (ware_sandy_timestop_shared.dm)
		return FALSE
	if(!istype(A) || global_frozen_atoms[A])
		return FALSE
	if(GLOB.cyberware_time_dilated[A] || released[A] || immune[A] || surging[A])
		if(A.throwing)
			take_throw(A) // a body already held, thrown across the field
		return FALSE
	if(cyberware_own_surge(A))
		take_surger(A, cyberware_surge_multiplier(A))
		return FALSE
	if(own_ride(A)) // the user's mech or vehicle is part of them: full speed
		return FALSE
	if(ismob(A))
		var/mob/M = A
		if(M.can_block_magic(antimagic_flags))
			immune[A] = TRUE
			return FALSE
	var/tint = TRUE
	if(isliving(A))
		hold_mob(A)
	else if(isprojectile(A))
		var/obj/projectile/shot = A
		if(shot.firer && immune[shot.firer])
			user_shots[shot] = TRUE
			tint = FALSE
			escape_the_negative_zone(shot) // in case it was tinted before it had a firer
		else if(shot.firer && (surging[shot.firer] || cyberware_own_surge(shot.firer))) // at the field's pace, like every bullet, but in colour
			tint = FALSE
		hold_shot(shot)
	else if(ismecha(A))
		hold_mech(A)
	else if(istype(A, /obj/machinery/porta_turret))
		frozen_structures += A
		held_turrets[A] = TRUE
	else if((ismachinery(A) && !istype(A, /obj/machinery/light)) || isstructure(A) || cyberware_time_tinted_blood(A) || cyberware_time_tinted_shot_trash(A))
		frozen_structures += A // looks only
	else if(cyberware_lit_grenade(A))
		held_grenades[A] = TRUE
		tint = !!A.throwing // floor items keep their colour
	else if(!A.throwing)
		return FALSE
	else if(istype(A, /obj/item/ammo_casing) && cyberware_casing_keeps_colour(A))
		tint = FALSE
	if(A.throwing)
		hold_throw(A)
	GLOB.cyberware_time_dilated[A] = src
	frozen_things[A] = TRUE
	RegisterSignal(A, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)
	if(tint)
		into_the_negative_zone(A)
		if(istype(A, /obj/effect/decal/cleanable/blood) || istype(A, /obj/effect/ebeam))
			tint_blood_bits(A)
	return TRUE

/datum/proximity_monitor/advanced/timestop/sandevistan/setup_field_turf(turf/target)
	if(!replay)
		return ..()
	replay.covering = TRUE // what stands on a turf the field moves onto was there all along
	. = ..()
	replay?.covering = FALSE

/datum/proximity_monitor/advanced/timestop/sandevistan/unfreeze_all()
	for(var/obj/effect/picture as anything in rig_glows)
		drop_rig_glow(picture)
	for(var/atom/movable/flier as anything in held_throws.Copy())
		let_go_throw(flier)
		if(!frozen_things[flier] && !surging[flier])
			UnregisterSignal(flier, COMSIG_QDELETING)
	for(var/atom/movable/thing as anything in frozen_things)
		unfreeze_atom(thing)
	for(var/turf/ground as anything in frozen_turfs)
		unfreeze_turf(ground)
	frozen_turfs.Cut()

/datum/proximity_monitor/advanced/timestop/sandevistan/unfreeze_atom(atom/movable/A)
	if(held_mobs[A])
		let_go_mob(A)
	if(held_shots[A])
		let_go_shot(A)
	if(held_throws[A])
		let_go_throw(A)
	held_mechs -= A
	held_turrets -= A
	held_grenades -= A
	frozen_structures -= A
	blood_holders -= A
	user_shots -= A
	slowed_tags -= A
	own_scales -= A
	UnregisterSignal(A, COMSIG_QDELETING)
	escape_the_negative_zone(A)
	frozen_things -= A
	GLOB.cyberware_time_dilated -= A

// ----- mobs -----

/// Takes hold of a mob: slowed (or sped up, for a faster surger), whichever its rate is.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_mob(mob/living/victim)
	held_mobs[victim] = TRUE
	slow_mob(victim)
	if(scale_for(victim) < 1 && cyberware_time_stop_boss(victim))
		boss_holds[victim] = world.time + SANDY_STOP_BOSS_HOLD

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/let_go_mob(mob/living/victim)
	unslow_mob(victim)
	held_mobs -= victim
	boss_holds -= victim

/// Paces a mob's walk to its rate in the field: slower, or faster for a faster surger. Its timers move with it every tick().
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/slow_mob(mob/living/victim)
	var/rate = scale_for(victim)
	victim.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation)
	// A slowed walk gets at least a decisecond's delay to stretch; a faster one divides what it really has.
	var/base_delay = rate < 1 ? max(victim.cached_multiplicative_slowdown, 1) : max(victim.cached_multiplicative_slowdown, 0)
	victim.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation, multiplicative_slowdown = base_delay * (1 / rate - 1))
	if(istype(victim, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/animal_victim = victim
		animal_victim.move_to_delay = initial(animal_victim.move_to_delay) / rate

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/unslow_mob(mob/living/victim)
	victim.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation)
	if(istype(victim, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/animal_victim = victim
		animal_victim.move_to_delay = initial(animal_victim.move_to_delay)

/// Pushes every timing deadline `victim` has that hasn't passed yet back by `push` deciseconds (forward, if negative).
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/push_deadlines(mob/living/victim, push)
	cyberware_push_deadlines(victim, push)

/**
 * Pushes every timing deadline `victim` has that was still to come at `since` (default now) back by `push` deciseconds
 * (forward, if negative). The one list of a mob's clocks: the slow-mo field slows them with it, and the replay's hold
 * (ware_sandy_replay.dm) stops them with it, so a clock added here is covered by both.
 */
/proc/cyberware_push_deadlines(mob/living/victim, push, since = world.time)
	var/now = since
	if(victim.next_move > now)
		victim.next_move += push
	for(var/datum/action/cooldown/ability in victim.actions)
		if(ability.next_use_time > now)
			ability.next_use_time += push
	var/datum/ai_controller/controller = victim.ai_controller
	if(controller)
		for(var/behavior in controller.behavior_cooldowns)
			if(controller.behavior_cooldowns[behavior] > now)
				controller.behavior_cooldowns[behavior] += push
		for(var/key in dilated_blackboard_keys())
			var/deadline = controller.blackboard[key]
			if(isnum(deadline) && deadline > now)
				controller.blackboard[key] = deadline + push
	var/datum/component/ranged_attacks/ranged = victim.GetComponent(/datum/component/ranged_attacks)
	if(ranged && ranged.fire_cooldown > now)
		ranged.fire_cooldown += push
	if(istype(victim, /mob/living/simple_animal/hostile))
		var/mob/living/simple_animal/hostile/animal_victim = victim
		if(animal_victim.ranged_cooldown > now)
			animal_victim.ranged_cooldown += push

	for(var/obj/item/gun/gun in victim.held_items)
		gun.cyberware_burst_start += push
	if(ranged)
		ranged.cyberware_burst_start += push
	victim.cyberware_push_clocks(push) // its own clocks (ware_sandy_timestop_cover.dm)

// ----- mobs on their own surge -----

/**
 * `surger` runs its own surge at `multiplier`: at the same rate as the user it is left alone; otherwise the field
 * holds it at its relative rate, slower or faster, untinted.
 */
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/take_surger(mob/living/surger, multiplier)
	surging[surger] = TRUE
	RegisterSignal(surger, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)
	cyberware_surge_refresh_perks(surger) // the field paces it now, not its own edge
	var/rate = relative_rate(multiplier)
	if(abs(rate - 1) < SANDY_STOP_SAME_RATE)
		return
	own_scales[surger] = rate
	hold_mob(surger)
	GLOB.cyberware_time_dilated[surger] = src
	frozen_things[surger] = TRUE

/**
 * `surger` opened its own surge at `multiplier`: if the field holds it, let it go now and drop every slow it
 * carried (its walk, its pauses, its last bit of lost time, its slowed animations and the shots it fired), then
 * take it back at its relative rate. Its shots go back in at the field's pace, untinted.
 */
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/surge_free(mob/living/surger, multiplier)
	if(surging[surger] || sandy_session_shares(src, surger))
		return
	var/list/its_shots = list()
	if(GLOB.cyberware_time_dilated[surger] == src)
		var/lag = cyberware_time_lag(surger)
		if(lag > 0)
			push_deadlines(surger, lag) // the time it really lost since the last tick
		var/list/tags = slowed_tags[surger]
		unfreeze_atom(surger)
		for(var/tag in tags)
			surger.hv_vis_release(tag, 1) // back to its real pose at once, not at the slowed pace
		for(var/obj/projectile/shot as anything in held_shots.Copy())
			if(shot.firer == surger)
				unfreeze_atom(shot)
				its_shots += shot
	else
		var/turf/centre = get_turf(host)
		var/turf/here = get_turf(surger)
		if(!centre || !here || here.z != centre.z || get_dist(centre, here) > current_range)
			return // out of reach: if it walks in still surging, freeze_atom() takes it at its rate
	take_surger(surger, multiplier)
	for(var/obj/projectile/shot as anything in its_shots)
		if(!QDELETED(shot))
			freeze_atom(shot)

/// Every tick: surgers whose window has closed go back to the field's pace, if they are still in range. A surger
/// that died is let go for good: its corpse is never taken back and tinted.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/check_surgers()
	var/turf/centre = get_turf(host)
	for(var/mob/living/surger as anything in surging.Copy())
		if(surger.stat != DEAD && cyberware_own_surge(surger))
			continue
		if(GLOB.cyberware_time_dilated[surger] == src)
			var/lag = cyberware_time_lag(surger)
			if(lag)
				push_deadlines(surger, lag)
			unfreeze_atom(surger)
		surging -= surger
		UnregisterSignal(surger, COMSIG_QDELETING)
		cyberware_surge_refresh_perks(surger)
		if(surger.stat == DEAD)
			released[surger] = TRUE
			continue
		var/turf/here = get_turf(surger)
		if(centre && here && here.z == centre.z && get_dist(centre, here) <= current_range)
			freeze_atom(surger)

// ----- mechs, turrets, grenades -----

/// Takes hold of a mech and whoever is driving it.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_mech(obj/vehicle/sealed/mecha/mech)
	frozen_structures += mech
	held_mechs[mech] = TRUE
	for(var/mob/living/pilot in mech.occupants)
		freeze_atom(pilot)

/// Pushes back the clocks of held machines and grenades by `push` deciseconds.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/push_machine_deadlines(push)
	for(var/obj/vehicle/sealed/mecha/mech as anything in held_mechs)
		cyberware_push_machine_deadlines(mech, push)
	for(var/obj/machinery/porta_turret/turret as anything in held_turrets)
		cyberware_push_machine_deadlines(turret, push)
	for(var/obj/item/grenade/bomb as anything in held_grenades)
		cyberware_push_machine_deadlines(bomb, push)

/// Pushes the clock of a held machine or grenade `thing` back by `push` deciseconds, if it was still to come at `since`
/// (default now). Shared by the field and the replay's hold (ware_sandy_replay.dm), like cyberware_push_deadlines().
/proc/cyberware_push_machine_deadlines(atom/thing, push, since = world.time)
	var/now = since
	if(ismecha(thing))
		var/obj/vehicle/sealed/mecha/mech = thing
		if(mech.cooldown_vehicle_move > now)
			mech.cooldown_vehicle_move += push
	else if(istype(thing, /obj/machinery/porta_turret))
		var/obj/machinery/porta_turret/turret = thing
		if(turret.last_fired + turret.shot_delay > now)
			turret.last_fired += push
	else if(istype(thing, /obj/item/grenade))
		var/obj/item/grenade/bomb = thing
		if(bomb.cyberware_fuse_at > now)
			bomb.cyberware_fuse_at += push

// ----- projectiles -----

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_shot(obj/projectile/shot)
	held_shots[shot] = shot.speed
	shot.speed = held_shots[shot] * scale_for(shot)
	if(!user_shots[shot]) // a shot is made, and taken, before it has a firer
		RegisterSignal(shot, COMSIG_PROJECTILE_FIRE, PROC_REF(held_shot_fired), override = TRUE)

/// Signal proc for [COMSIG_PROJECTILE_FIRE] on a held shot: now it has a firer, a surging mob's shot loses the tint.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/held_shot_fired(obj/projectile/shot)
	SIGNAL_HANDLER
	UnregisterSignal(shot, COMSIG_PROJECTILE_FIRE)
	if(shot.firer && (surging[shot.firer] || cyberware_own_surge(shot.firer)))
		escape_the_negative_zone(shot)

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/let_go_shot(obj/projectile/shot)
	shot.speed = held_shots[shot]
	held_shots -= shot
	UnregisterSignal(shot, COMSIG_PROJECTILE_FIRE)

/// Signal proc for [COMSIG_PROJECTILE_FIRER_BEFORE_FIRE] on the user: watch the shot leave the barrel.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/on_user_fire(datum/source, obj/projectile/shot, atom/fired_from, atom/original)
	SIGNAL_HANDLER
	RegisterSignal(shot, COMSIG_PROJECTILE_FIRE, PROC_REF(take_user_shot), override = TRUE)

/// Signal proc for [COMSIG_PROJECTILE_FIRE]: the user's shot keeps its colour but crawls at the field's pace like
/// every bullet in it.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/take_user_shot(obj/projectile/shot)
	SIGNAL_HANDLER
	UnregisterSignal(shot, COMSIG_PROJECTILE_FIRE)
	if(QDELETED(shot) || shot.deletion_queued)
		return
	user_shots[shot] = TRUE
	escape_the_negative_zone(shot) // in case it was tinted before it had a firer
	if(held_shots[shot])
		return
	// Another field (a crewmate's, in a shared slow-mo) took it as it was made: it lets go first, or both would slow
	// it, and whichever let go last would leave it flying at the slowed pace after the slow-mo.
	var/datum/proximity_monitor/advanced/timestop/sandevistan/holder = GLOB.cyberware_time_dilated[shot]
	if(istype(holder) && holder != src)
		holder.unfreeze_atom(shot)
	hold_shot(shot)
	GLOB.cyberware_time_dilated[shot] = src
	frozen_things[shot] = TRUE
	RegisterSignal(shot, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)

// ----- throws -----

/// Whether `thing` is a body on its own time here: the user, their ride, a surging mob, a freed boss, a crewmate in the
/// shared slow-mo, anyone the field can't touch. Thrown, it flies at its own speed.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/own_time(atom/movable/thing)
	return !!(thing == host || immune[thing] || surging[thing] || released[thing] || own_ride(thing) || sandy_session_shares(src, thing))

/// Takes a throw started or arriving in the field: held bodies and floor items alike fly at the field's pace.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/take_throw(atom/movable/thing)
	if(QDELETED(thing) || !thing.throwing || cover_outsider(thing) || own_time(thing))
		return
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/holder as anything in GLOB.cyberware_time_fields)
		if(holder.held_throws[thing])
			return
	if(!GLOB.cyberware_time_dilated[thing] && freeze_atom(thing))
		return
	replay?.notice(thing)
	hold_throw(thing)
	if(held_grenades[thing] && !tinted[thing])
		into_the_negative_zone(thing)
	else if(!frozen_things[thing] && !surging[thing])
		RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)

/// Records `thing`'s own throw speed and slows its flight to the field's pace.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_throw(atom/movable/thing)
	var/datum/thrownthing/flight = thing.throwing
	if(!flight)
		return
	if(!held_throws[thing])
		held_throws[thing] = flight.speed
	pace_throw(thing, held_throws[thing] * time_scale, flight)

/// Sets `thing`'s `flight` to `new_speed`, keeping its progress along the current tile.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/pace_throw(atom/movable/thing, new_speed, datum/thrownthing/flight = thing.throwing)
	if(!flight || new_speed <= 0 || flight.speed == new_speed)
		return
	var/elapsed = max(world.time - flight.start_time + flight.delayed_time, 0)
	flight.start_time = world.time + flight.delayed_time - elapsed * (flight.speed / new_speed)
	flight.speed = new_speed

/// Restores `thing`'s throw to its own speed from where it has got to.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/let_go_throw(atom/movable/thing)
	var/orig_speed = held_throws[thing]
	held_throws -= thing
	if(orig_speed && thing.throwing)
		pace_throw(thing, orig_speed)

/// `thing`'s throw is landing inside the slow-mo: put its real speed back for impact, and let a plain floor item go.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/finish_throw(atom/movable/thing, datum/thrownthing/flight)
	var/orig_speed = held_throws[thing]
	if(!orig_speed)
		return
	held_throws -= thing
	if(flight)
		pace_throw(thing, orig_speed, flight)
	if(!frozen_things[thing])
		if(!surging[thing])
			UnregisterSignal(thing, COMSIG_QDELETING)
		return
	if(held_grenades[thing])
		escape_the_negative_zone(thing)
		return
	if(!held_mobs[thing] && !held_shots[thing] && !held_mechs[thing] && !held_turrets[thing] && !(thing in frozen_structures))
		unfreeze_atom(thing)

/// Forgets a held thing that got deleted.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/held_gone(atom/movable/thing)
	SIGNAL_HANDLER
	held_shots -= thing
	user_shots -= thing
	held_mobs -= thing
	held_throws -= thing
	held_mechs -= thing
	held_turrets -= thing
	held_grenades -= thing
	boss_holds -= thing
	surging -= thing
	slowed_tags -= thing
	tinted -= thing
	if(tint_timers[thing])
		deltimer(tint_timers[thing])
	tint_timers -= thing
	own_scales -= thing
	frozen_structures -= thing
	blood_holders -= thing
	frozen_things -= thing
	GLOB.cyberware_time_dilated -= thing

// ----- the clock -----

/datum/proximity_monitor/advanced/timestop/sandevistan/process()
	return PROCESS_KILL

/// Every 0.2 s: end if a player came in, push back the timers of everything held, let bosses go.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/tick()
	if(QDELETED(host) || cyberware_time_stop_witnessed(host))
		if(sandy_session_field_cut(src)) // a shared slow-mo ends for everyone in it (ware_sandy_timestop_shared.dm)
			return
		replay?.cancel() // cut short: nothing replays
		if(!QDELETED(stopper))
			qdel(stopper) // takes this field with it
		return
	sandy_session_check_touch(src) // a crewmate's slow-mo touching this one joins it (ware_sandy_timestop_shared.dm)
	if(QDELETED(src))
		return
	var/elapsed = world.time - last_tick
	last_tick = world.time
	for(var/mob/living/victim as anything in held_mobs)
		var/lost = elapsed * (1 - scale_for(victim)) // a faster surger's is negative: its deadlines come sooner
		if(lost)
			push_deadlines(victim, lost)
	var/push = elapsed * (1 - time_scale)
	if(push > 0)
		push_machine_deadlines(push)
	check_surgers()
	let_go_own_ride()
	for(var/mob/living/boss as anything in boss_holds.Copy())
		if(world.time < boss_holds[boss])
			continue
		unfreeze_atom(boss)
		released[boss] = TRUE
	for(var/obj/effect/holder as anything in blood_holders)
		tint_blood_bits(holder)
	senses?.refresh_weather()
	cover_tick() // ware_sandy_timestop_cover.dm

/// Whether `thing` is what the user is riding or piloting: a vehicle with them aboard, or anything they're buckled to.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/own_ride(atom/movable/thing)
	if(!ismob(host) || !istype(thing))
		return FALSE
	var/mob/living/user = host
	if(istype(thing, /obj/vehicle))
		var/obj/vehicle/ride = thing
		if(ride.is_occupant(user))
			return TRUE
	return isliving(user) && user.buckled == thing

/// The user climbed into a mech or onto a vehicle the field already holds: it runs at full speed from now on.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/let_go_own_ride()
	if(!isliving(host))
		return
	var/mob/living/user = host
	for(var/atom/movable/ride in list(user.loc, user.buckled))
		if(frozen_things[ride] && own_ride(ride))
			unfreeze_atom(ride)

/datum/proximity_monitor/advanced/timestop/sandevistan/into_the_negative_zone(atom/A)
	tinted[A] = TRUE
	replay?.resample(A) // recorded without the tint from here on
	var/wait = ring_wait(A)
	if(wait > 0)
		if(!tint_timers[A])
			tint_timers[A] = addtimer(CALLBACK(src, PROC_REF(ring_reached), A), wait, TIMER_STOPPABLE)
		return
	cyberware_time_tint_on(A)

/datum/proximity_monitor/advanced/timestop/sandevistan/escape_the_negative_zone(atom/A)
	if(tint_timers[A])
		deltimer(tint_timers[A])
	tint_timers -= A
	if(!tinted[A])
		return
	tinted -= A
	cyberware_time_tint_off(A)

/// Drips and trail pieces are blood drawn in a blood decal's vis_contents with RESET_COLOR, and a gut strand (a beam)
/// draws its picture from one shared object in each segment's vis_contents: the holder's tint never reaches them. Each
/// is tinted on its own like the holder, and let go with the field. Blood that drips onto a tinted decal later is
/// picked up by tick().
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/tint_blood_bits(obj/effect/holder)
	blood_holders[holder] = TRUE // a new drip or trail has no bits yet: they come as more blood lands on it
	if(!length(holder.vis_contents))
		return
	for(var/obj/effect/bit in holder.vis_contents)
		if(!istype(bit, /obj/effect/decal/cleanable/blood) && !istype(bit, /obj/effect/ebeam))
			continue
		if(frozen_things[bit] || QDELETED(bit))
			continue
		GLOB.cyberware_time_dilated[bit] = src
		frozen_things[bit] = TRUE
		frozen_structures += bit
		RegisterSignal(bit, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)
		tinted[bit] = TRUE // not recorded: the replay draws the decal, not what is in its vis_contents
		var/wait = ring_wait(bit)
		if(wait > 0)
			tint_timers[bit] = addtimer(CALLBACK(src, PROC_REF(ring_reached), bit), wait, TIMER_STOPPABLE)
		else
			cyberware_time_tint_on(bit)

/// The ring starts rolling out from `center` to `reach` tiles over `time`: everything it hasn't reached yet loses
/// its tint until the ring's front passes it.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/sweep_ring(turf/center, reach, time)
	ring_center = center
	ring_start = world.time
	ring_time = time
	ring_reach = reach
	for(var/atom/movable/thing as anything in tinted)
		if(tint_timers[thing])
			continue
		var/wait = ring_wait(thing)
		if(wait <= 0)
			continue
		cyberware_time_tint_off(thing)
		tint_timers[thing] = addtimer(CALLBACK(src, PROC_REF(ring_reached), thing), wait, TIMER_STOPPABLE)

/// How long until the rolling ring's front reaches `thing`, or 0 if it already has. The ring grows with a sine
/// ease-out (cyberware_time_ring).
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/ring_wait(atom/thing)
	if(!ring_center)
		return 0
	var/turf/spot = get_turf(thing)
	if(!spot || spot.z != ring_center.z)
		return 0
	var/dist = sqrt((spot.x - ring_center.x) ** 2 + (spot.y - ring_center.y) ** 2)
	if(dist > ring_reach) // past the ring's own size the front keeps rolling out at SANDY_STOP_RING_TAIL a tile, not all at once
		return max(ring_start + ring_time + (dist - ring_reach) * SANDY_STOP_RING_TAIL - world.time, 0)
	if(world.time >= ring_start + ring_time)
		return 0
	var/reached = clamp((dist - 0.2) / max(ring_reach - 0.2, 0.1), 0, 1)
	return ring_start + ring_time * arcsin(reached) / 90 - world.time

/// The ring's front got to `thing`: on with its tint, if it still wants it.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/ring_reached(atom/movable/thing)
	tint_timers -= thing
	if(QDELETED(thing) || !tinted[thing])
		return
	cyberware_time_tint_on(thing)

// ----- finisher rigs -----

/// The user's edge glow is on their body, which a finisher rig hides while posed pictures of it stand in its place
/// (chrome_puppet_rig.dm, mantis_rig.dm). Each picture of the user gets a solid copy in the glow's colour, a pixel
/// bigger, drawn under all of the user's pictures: together they show as one rim round the whole posed body.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/glow_rig_picture(obj/effect/picture)
	var/obj/effect/abstract/sandy_rig_glow/glow = rig_glows[picture]
	if(glow)
		glow.copy_overlays_of(picture) // redrawn (the blade rig's body piece takes the bearer's look again)
		return
	glow = new(null)
	glow.copy_overlays_of(picture)
	if(istype(picture, /obj/effect/abstract/mantis_puppet))
		// The blade rig's pieces stand on other rows (pixel_y, SIDE_MAP): a copy with a layer of its own would sort on
		// the tile's row, over the piece. Each is drawn under its own piece instead.
		glow.vis_flags |= VIS_UNDERLAY
	else
		glow.layer = picture.layer - 0.05
	picture.vis_contents += glow
	rig_glows[picture] = glow
	RegisterSignal(picture, COMSIG_QDELETING, PROC_REF(rig_picture_gone))

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/drop_rig_glow(obj/effect/picture)
	var/obj/effect/abstract/sandy_rig_glow/glow = rig_glows[picture]
	rig_glows -= picture
	UnregisterSignal(picture, COMSIG_QDELETING)
	if(glow)
		picture.vis_contents -= glow
		qdel(glow)

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/rig_picture_gone(obj/effect/picture)
	SIGNAL_HANDLER
	drop_rig_glow(picture)

/// Tints `thing` (a rig picture, a muzzle flash in vis_contents) as looks-only, let go when the field ends.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/take_looks(atom/movable/thing)
	if(frozen_things[thing] || QDELETED(thing))
		return
	GLOB.cyberware_time_dilated[thing] = src
	frozen_things[thing] = TRUE
	frozen_structures += thing // looks only
	RegisterSignal(thing, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)
	into_the_negative_zone(thing)

/// A rig picture of a body the field tints: tinted like it, and let go with the field.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/take_rig_picture(obj/effect/picture)
	take_looks(picture)

/// The solid copy under one of the user's rig pictures. It takes the picture's icon, facing and turn.
/obj/effect/abstract/sandy_rig_glow
	name = ""
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = RESET_COLOR | PIXEL_SCALE
	vis_flags = VIS_INHERIT_ICON | VIS_INHERIT_ICON_STATE | VIS_INHERIT_DIR | VIS_INHERIT_PLANE
	color = list(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.82, 0.353, 1, 0.588, 0)

/obj/effect/abstract/sandy_rig_glow/Initialize(mapload)
	. = ..()
	add_filter("sandy_rig_glow", 1, outline_filter(1, "#5AFF96D2"))

/// A picture drawn from overlays (the blade rig's body piece is a copy of the bearer's whole look) has little or no
/// icon of its own to inherit: the copy takes its overlays too, so it is the whole figure's shape.
/obj/effect/abstract/sandy_rig_glow/proc/copy_overlays_of(obj/effect/picture)
	overlays = picture.overlays.Copy()
	underlays = picture.underlays.Copy()

/**
 * A finisher rig stood up `picture`, a posed piece of `body` (or a loose picture of the move's, like the victim's
 * blood spraying). In a Sandevistan slow-mo it looks like the body it stands for: the user's carry the user's edge
 * glow, a held body's are tinted with the world.
 */
/proc/cyberware_time_rig_picture(obj/effect/picture, mob/living/body)
	if(!length(GLOB.cyberware_time_fields) || QDELETED(picture) || isnull(body))
		return
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field.host == body)
			field.glow_rig_picture(picture)
			return
		if(field.tinted[body])
			field.take_rig_picture(picture)
			return

// =========================================================================
// THE WINDOW'S SIDE
// =========================================================================

/datum/status_effect/cyberware_cascade_window
	/// How fast the world runs in slow-mo, if nobody else is near when the window opens. Copied from the lattice.
	var/dilation_scale = 0.1
	/// How much faster than normal the bearer runs: sets surging mobs' relative rates in each other's fields.
	var/time_multiplier = 10
	/// How long the window runs when it slows the world. Copied from the lattice; 0 keeps the plain length.
	var/slowmo_duration = 0
	/// world.time a plain surge from the same start would have ended: a slow-mo a player cuts short carries on as a
	/// plain surge no longer than this.
	var/plain_end = 0
	/// The running dilation, if any.
	var/obj/effect/timestop/sandevistan/time_stop
	/// world.time the window closes on its own, before any hold.
	var/natural_end = 0
	/// The slow-mo is held for an execution in progress until this world.time at most (slowmo_time_up()). 0 when not holding.
	var/hold_until = 0
	/// This surge's one hold is used.
	var/hold_spent = FALSE
	var/hold_timer
	/// The held move is over: the slow-mo ends at this world.time (SANDY_STOP_HOLD_TAIL). 0 while it runs.
	var/tail_until = 0

/// Slows the world for the whole window if the bearer is a player and nobody else is near. Called as the window
/// opens, while `duration` is still its length.
/datum/status_effect/cyberware_cascade_window/proc/try_time_stop()
	cyberware_surge_frees(owner, time_multiplier) // anyone's surge runs at its own rate in someone else's field
	if(dilation_scale <= 0 || dilation_scale >= 1 || duration <= 0 || !owner.ckey || time_stop)
		return FALSE
	if(cyberware_time_stop_witnessed(owner))
		return FALSE
	if(sandy_session_bars(owner)) // under a replay, or beside a crewmate's slow-mo too far gone to join (ware_sandy_timestop_shared.dm)
		return FALSE
	var/turf/here = get_turf(owner)
	if(!here)
		return FALSE
	plain_end = world.time + duration
	duration = max(duration, slowmo_duration) // the slow-mo runs longer than the plain surge
	natural_end = world.time + duration
	time_stop = new(here, SANDY_STOP_FIELD_RANGE, duration, list(owner), TRUE, TRUE, dilation_scale, time_multiplier)
	if(QDELETED(time_stop))
		time_stop = null
		duration = plain_end - world.time // no slow-mo: a plain surge's length
		natural_end = plain_end
		return FALSE
	RegisterSignal(time_stop, COMSIG_QDELETING, PROC_REF(time_stop_over))
	var/obj/item/organ/cyberimp/cyberware/cascade/lattice = cyberware_bearer_lattice(owner)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = time_stop.chronofield
	if(lattice)
		lattice.roll_stop_ring()
		field?.sweep_ring(here, lattice.stop_ring_scale, lattice.ring_time)
	owner.remove_client_colour(id) // the user sees the slowed world as it is
	owner.add_filter(SANDY_STOP_OUTLINE, 2, outline_filter(1, "#5AFF96D2"))
	if(field)
		sandy_session_check_touch(field, src) // a crewmate's slow-mo this touches becomes one with it (ware_sandy_timestop_shared.dm)
	sandy_sound_sync() // ware_sandy_sound.dm
	return TRUE

/**
 * The slow-mo's time is up, or the user pressed the surge again. If the user is in the middle of an execution or a
 * finisher, the slow-mo holds until the move is over (once a surge, at most SANDY_STOP_HOLD_MAX past now), so the
 * move plays out inside it and its replay shows it. Otherwise the window closes now, and the slow-mo with it.
 */
/datum/status_effect/cyberware_cascade_window/proc/slowmo_time_up()
	if(hold_until)
		return // already holding: it ends when the move does
	if(time_stop && !hold_spent && sandy_session_mid_move(src)) // or a crewmate's, at a shared slow-mo's end (ware_sandy_timestop_shared.dm)
		hold_spent = TRUE
		hold_until = world.time + SANDY_STOP_HOLD_MAX
		duration = max(duration, hold_until + world.tick_lag) // the window outlasts the hold; hold_check() closes it
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = time_stop.chronofield
		if(field)
			field.ends_at = hold_until
		var/datum/sandy_session/session = GLOB.sandy_session_of[owner]
		session?.repace() // every member's field holds with it
		session?.hold_for_moves() // and a member out of time who is the one mid-move finishes it at its own speed
		hold_timer = addtimer(CALLBACK(src, PROC_REF(hold_check)), world.tick_lag, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
		return
	qdel(src)

/// Every tick of a hold: the move is over, so the window (and the slow-mo) closes. At the cap the move is still
/// going: the slow-mo ends without a replay, rather than the replay's hold cutting the move short.
/datum/status_effect/cyberware_cascade_window/proc/hold_check()
	if(QDELETED(owner) || !time_stop)
		qdel(src)
		return
	if(sandy_session_mid_move(src))
		tail_until = 0
		if(world.time < hold_until)
			return
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = time_stop.chronofield
		if(!sandy_session_others_active(owner)) // a shared slow-mo goes on, and its replay with it
			field?.replay?.cancel()
		qdel(src)
		return
	if(!tail_until)
		tail_until = world.time + SANDY_STOP_HOLD_TAIL
		duration = max(duration, tail_until + world.tick_lag)
		var/datum/proximity_monitor/advanced/timestop/sandevistan/field = time_stop.chronofield
		if(field)
			field.ends_at = max(field.ends_at, tail_until)
	if(world.time < tail_until)
		return
	qdel(src)

/// Signal proc for [COMSIG_QDELETING] on the dilation when the window didn't end it (a player came near): time runs
/// normally and the rest of the window carries on as an ordinary surge, in its own colour.
/datum/status_effect/cyberware_cascade_window/proc/time_stop_over(datum/source)
	SIGNAL_HANDLER
	time_stop = null
	sandy_sound_sync() // ware_sandy_sound.dm
	if(QDELETED(owner))
		return
	stop_hold()
	owner.remove_filter(SANDY_STOP_OUTLINE)
	sandy_release_flash(owner)
	var/ends = min(natural_end, plain_end) // a plain surge's length: the slow-mo's extra time goes with the slow-mo
	if(world.time >= ends)
		QDEL_IN(src, 0) // past where a plain surge would have ended (or the window's own end, during a hold)
		return
	duration = ends
	owner.add_client_colour(colour_type, id)
	refresh_perks() // the rest of the window is an ordinary surge

/datum/status_effect/cyberware_cascade_window/proc/stop_hold()
	deltimer(hold_timer)
	hold_timer = null
	hold_until = 0
	tail_until = 0

/// Ends the dilation early (the window is closing).
/datum/status_effect/cyberware_cascade_window/proc/end_time_stop()
	if(sandy_session_window_ends(src)) // a shared slow-mo decides (ware_sandy_timestop_shared.dm)
		return
	stop_hold()
	if(!time_stop)
		return
	UnregisterSignal(time_stop, COMSIG_QDELETING)
	QDEL_NULL(time_stop)
	sandy_sound_sync() // ware_sandy_sound.dm
	if(!QDELETED(owner))
		owner.remove_filter(SANDY_STOP_OUTLINE)
		sandy_release_flash(owner)

/// A pale green flash on the user's screen as the world speeds back up.
/proc/sandy_release_flash(mob/living/user)
	user.overlay_fullscreen(SANDY_STOP_FLASH, /atom/movable/screen/fullscreen/flash/sandy_release)
	user.clear_fullscreen(SANDY_STOP_FLASH, 0.22 SECONDS)

/atom/movable/screen/fullscreen/flash/sandy_release
	color = "#E1FFEB"
	alpha = 140

/// The afterimage left while time is dilated, laid and coloured like the rest of the trail (cyberware_cascade_window/on_move()).
/// Its colour matrix keeps it out of the world's tint.
/obj/effect/temp_visual/decoy/fading/cascade/stopped

// =========================================================================
// CLOCKS THAT RUN SLOW
// =========================================================================

/obj/item/gun
	/// world.time the current burst began, pushed back while the shooter is slowed (cyberware time dilation).
	var/cyberware_burst_start = 0
	/// The gap between the current burst's shots, in the shooter's own time.
	var/cyberware_burst_gap = 0

/datum/component/ranged_attacks
	/// world.time the current burst began, pushed back while the mob is slowed (cyberware time dilation).
	var/cyberware_burst_start = 0

/// One shot of a burst (`index` 1 is the second shot), fired when the mob's own clock gets there.
/datum/component/ranged_attacks/proc/cyberware_burst_shot(mob/living/basic/firer, atom/target, modifiers, index)
	if(QDELETED(firer))
		return
	var/wait = cyberware_burst_wait(firer, cyberware_burst_start, burst_intervals, index)
	if(wait > 0)
		addtimer(CALLBACK(src, PROC_REF(cyberware_burst_shot), firer, target, modifiers, index), wait, TIMER_DELETE_ME)
		return
	async_fire_ranged_attack(firer, target, modifiers)

/obj/item/grenade
	/// world.time the fuse runs out, pushed back while the grenade sits in a dilation field. 0 when not lit.
	var/cyberware_fuse_at = 0

/// Whether `thing` is a grenade with its fuse burning.
/proc/cyberware_lit_grenade(atom/thing)
	if(!istype(thing, /obj/item/grenade))
		return FALSE
	var/obj/item/grenade/bomb = thing
	return bomb.active && bomb.cyberware_fuse_at

/obj/item/grenade/arm_grenade(mob/user, delayoverride, msg = TRUE, volume = 60)
	cyberware_fuse_at = world.time + (isnull(delayoverride) ? det_time : delayoverride)
	. = ..()
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_time_field(src)
	field?.freeze_atom(src)

/// The fuse timer ran out: go off, unless the grenade's own clock is still behind.
/obj/item/grenade/proc/cyberware_fuse_done()
	if(!cyberware_fuse_at)
		return
	var/wait = cyberware_fuse_at + cyberware_time_lag(src) - world.time
	if(wait >= world.tick_lag)
		addtimer(CALLBACK(src, PROC_REF(cyberware_fuse_done)), max(wait, world.tick_lag), TIMER_DELETE_ME)
		return
	cyberware_fuse_at = 0
	detonate()

#undef SANDY_STOP_WITNESS_RANGE
#undef SANDY_STOP_FIELD_RANGE
#undef SANDY_STOP_RING_TAIL
#undef SANDY_STOP_BOSS_HOLD
#undef SANDY_STOP_MAX_RELATIVE
#undef SANDY_STOP_SAME_RATE
#undef SANDY_STOP_OUTLINE
#undef SANDY_STOP_FLASH
#undef SANDY_STOP_TINT
#undef SANDY_STOP_HOLD_MAX
#undef SANDY_STOP_HOLD_TAIL
