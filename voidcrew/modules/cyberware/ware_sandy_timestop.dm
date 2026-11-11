/**
 * # The Cascade line's time stop
 *
 * When a Cascade-line surge (ware_legend.dm, ware_line_sandy.dm) opens and no other player is within
 * SANDY_STOP_WITNESS_RANGE tiles, the world stops for the lattice's stop_duration (street 2 s, service 3 s,
 * Cascade 4 s). The rest of the window then runs as normal, then the crash. With another player near, the
 * surge is the plain one. Only a player's surge stops time: an NPC criminal's lattice never does.
 *
 * Built on tg's own time stop (code/datums/proximity_monitor/fields/timestop.dm). The field is hosted on
 * the user, so it follows them; anything it leaves behind stays frozen until it ends.
 *
 * No shortcuts on people: frozen mobs are held by tg's Stun, re-applied every tick by the tg field, and
 * anything with an AI controller also gets TRAIT_AI_PAUSED (Voidcrew's human NPCs run a basic controller on a
 * carbon body, which the tg field's basic-mob branch misses). Frozen bodies still take damage, wounds and
 * bleeding through tg as normal. Bosses (a finisher user, or a boss-rank human NPC) are held for
 * SANDY_STOP_BOSS_HOLD only, then let go while the field carries on.
 *
 * The field re-checks for players every tick and ends at once if one turns up.
 *
 * Look: frozen things get a grey-green tint instead of tg's inversion. Floor items, blood and the user are
 * never frozen, so they keep their colour. The user's own shots stop about a tile out, keep their colour,
 * and fly on when time restarts.
 */

/// Another player within this many tiles of the user means no time stop.
#define SANDY_STOP_WITNESS_RANGE 10
/// Radius of the frozen field around the user (a widescreen view is 9 tiles to each side).
#define SANDY_STOP_FIELD_RANGE 9
/// How long a boss stays frozen before it shrugs the field off.
#define SANDY_STOP_BOSS_HOLD (1 SECONDS)
/// How far, in pixels, the user's own shots fly before they hang.
#define SANDY_STOP_SHOT_HANG 32
/// Trait source for everything the time stop applies.
#define SANDY_STOP_TRAIT "sandevistan_time_stop"
/// Filter name of the user's edge glow.
#define SANDY_STOP_OUTLINE "sandy_time_stop_outline"

/// Whether a player other than `user` is within `range` tiles: anyone with a client, or a living body with a ckey whose player has disconnected.
/proc/cyberware_time_stop_witnessed(mob/living/user, range = SANDY_STOP_WITNESS_RANGE)
	var/turf/here = get_turf(user)
	if(!here)
		return TRUE
	for(var/atom/movable/found as anything in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, range))
		if(found == user)
			continue
		if(isliving(found))
			return TRUE
		if(ismob(found)) // ghosts and camera eyes don't count
			continue
		// a locker or a mech with a player in it
		for(var/mob/living/inside in found.get_all_contents())
			if(inside != user && inside.client)
				return TRUE
	for(var/mob/living/body in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_HEARING, range))
		if(body != user && body.ckey)
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

/// The grey-green wash on frozen things.
/proc/cyberware_time_stop_tint()
	var/static/list/tint = list(0.26,0.28,0.27, 0.52,0.56,0.54, 0.10,0.11,0.105, 0.02,0.05,0.04)
	return tint

/// Flattens a sprite to luminance and paints it the time stop's green (#5AFF96), lifted so dark parts still glow.
/proc/cyberware_time_stop_green()
	var/static/list/green
	if(!green)
		var/red = 90 / 255
		var/grn = 1
		var/blue = 150 / 255
		var/gain = 0.8
		var/lift = 0.5
		green = list(
			0.3 * gain * red, 0.3 * gain * grn, 0.3 * gain * blue,
			0.59 * gain * red, 0.59 * gain * grn, 0.59 * gain * blue,
			0.11 * gain * red, 0.11 * gain * grn, 0.11 * gain * blue,
			lift * red, lift * grn, lift * blue,
		)
	return green

// =========================================================================
// THE STOP
// =========================================================================

/// Lives as long as the stop, holds the field on the user, and ends the stop when it's deleted.
/obj/effect/timestop/sandevistan
	name = "stopped moment"
	desc = null
	hidden = TRUE
	alpha = 0
	freezerange = SANDY_STOP_FIELD_RANGE
	/// Whose stop this is. The field is hosted on them.
	var/mob/living/user

/// `immune_atoms` must be list(user).
/obj/effect/timestop/sandevistan/Initialize(mapload, radius, time, list/immune_atoms, start = TRUE, silent = TRUE)
	if(length(immune_atoms))
		user = immune_atoms[1]
	return ..(mapload, radius, time, immune_atoms, start, TRUE)

/obj/effect/timestop/sandevistan/Destroy()
	user = null
	return ..()

/obj/effect/timestop/sandevistan/timestop()
	target = get_turf(src)
	QDEL_IN(src, duration)
	if(QDELETED(user))
		return
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = new(user, freezerange, TRUE, immune, antimagic_flags, FALSE)
	field.stopper = src
	chronofield = field

/datum/proximity_monitor/advanced/timestop/sandevistan
	/// The effect that owns this field. Deleting it ends the stop.
	var/obj/effect/timestop/sandevistan/stopper
	/// Frozen bosses, to the world.time they shrug the field off.
	var/list/boss_holds = list()
	/// Bosses that already shrugged it off. The field leaves them be.
	var/list/released = list()
	/// The user's own shots, hanging in the air.
	var/list/hung_shots = list()

/datum/proximity_monitor/advanced/timestop/sandevistan/New(atom/_host, range, _ignore_if_not_on_turf = TRUE, list/immune, antimagic_flags, channelled)
	. = ..()
	RegisterSignal(host, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_user_fire))

/datum/proximity_monitor/advanced/timestop/sandevistan/Destroy()
	if(host)
		UnregisterSignal(host, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)
	for(var/obj/projectile/shot as anything in hung_shots)
		UnregisterSignal(shot, COMSIG_QDELETING)
		shot.paused = FALSE
	hung_shots.Cut()
	stopper = null
	. = ..()
	released.Cut()
	boss_holds.Cut()

/datum/proximity_monitor/advanced/timestop/sandevistan/freeze_atom(atom/movable/A)
	if(released[A])
		return FALSE
	if(isprojectile(A))
		var/obj/projectile/shot = A
		if(shot.firer && immune[shot.firer]) // the user's own shots hang on their own clock
			return FALSE
	return ..()

/datum/proximity_monitor/advanced/timestop/sandevistan/freeze_mob(mob/living/victim)
	. = ..()
	if(victim.ai_controller)
		ADD_TRAIT(victim, TRAIT_AI_PAUSED, SANDY_STOP_TRAIT)
	if(cyberware_time_stop_boss(victim))
		boss_holds[victim] = world.time + SANDY_STOP_BOSS_HOLD

/datum/proximity_monitor/advanced/timestop/sandevistan/unfreeze_mob(mob/living/victim)
	REMOVE_TRAIT(victim, TRAIT_AI_PAUSED, SANDY_STOP_TRAIT)
	boss_holds -= victim
	return ..()

/datum/proximity_monitor/advanced/timestop/sandevistan/process()
	if(QDELETED(host) || cyberware_time_stop_witnessed(host))
		if(!QDELETED(stopper))
			qdel(stopper) // takes this field with it
		return
	for(var/mob/living/boss as anything in boss_holds.Copy())
		if(world.time < boss_holds[boss])
			continue
		unfreeze_atom(boss)
		released[boss] = TRUE
	return ..()

/datum/proximity_monitor/advanced/timestop/sandevistan/into_the_negative_zone(atom/A)
	A.add_atom_colour(cyberware_time_stop_tint(), TEMPORARY_COLOUR_PRIORITY)

/// Signal proc for [COMSIG_PROJECTILE_FIRER_BEFORE_FIRE] on the user: watch the shot leave the barrel.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/on_user_fire(datum/source, obj/projectile/shot, atom/fired_from, atom/original)
	SIGNAL_HANDLER
	RegisterSignal(shot, COMSIG_PROJECTILE_FIRE, PROC_REF(hang_shot))

/// Signal proc for [COMSIG_PROJECTILE_FIRE]: the shot flies a tile, then hangs until time restarts.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hang_shot(obj/projectile/shot)
	SIGNAL_HANDLER
	UnregisterSignal(shot, COMSIG_PROJECTILE_FIRE)
	if(QDELETED(shot) || shot.deletion_queued)
		return
	// A hitscan beam takes its first step itself once paused (process_hitscan) and stops there.
	if(!shot.hitscan)
		shot.process_movement(SANDY_STOP_SHOT_HANG)
		if(QDELETED(shot) || shot.deletion_queued)
			return
	shot.paused = TRUE
	hung_shots += shot
	RegisterSignal(shot, COMSIG_QDELETING, PROC_REF(shot_gone))

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/shot_gone(obj/projectile/shot)
	SIGNAL_HANDLER
	hung_shots -= shot

// =========================================================================
// THE WINDOW'S SIDE
// =========================================================================

/datum/status_effect/cyberware_cascade_window
	/// How long the world stops if nobody else is near when the window opens. Copied from the lattice.
	var/stop_duration = 4 SECONDS
	/// The running stop, if time is stopped.
	var/obj/effect/timestop/sandevistan/time_stop

/// Stops time if the bearer is a player and nobody else is near. Called as the window opens.
/datum/status_effect/cyberware_cascade_window/proc/try_time_stop()
	if(stop_duration <= 0 || !owner.ckey || time_stop)
		return FALSE
	if(cyberware_time_stop_witnessed(owner))
		return FALSE
	var/turf/here = get_turf(owner)
	if(!here)
		return FALSE
	time_stop = new(here, SANDY_STOP_FIELD_RANGE, stop_duration, list(owner))
	if(QDELETED(time_stop))
		time_stop = null
		return FALSE
	RegisterSignal(time_stop, COMSIG_QDELETING, PROC_REF(time_stop_over))
	owner.remove_client_colour(id) // the user sees the frozen world as it is
	owner.add_filter(SANDY_STOP_OUTLINE, 2, outline_filter(1, "#5AFF96D2"))
	return TRUE

/// Signal proc for [COMSIG_QDELETING] on the stop: time restarts and the rest of the window runs as normal.
/datum/status_effect/cyberware_cascade_window/proc/time_stop_over(datum/source)
	SIGNAL_HANDLER
	time_stop = null
	if(QDELETED(owner))
		return
	owner.remove_filter(SANDY_STOP_OUTLINE)
	owner.add_client_colour(colour_type, id)

/// Ends the stop early (the window is closing).
/datum/status_effect/cyberware_cascade_window/proc/end_time_stop()
	if(!time_stop)
		return
	UnregisterSignal(time_stop, COMSIG_QDELETING)
	QDEL_NULL(time_stop)
	if(!QDELETED(owner))
		owner.remove_filter(SANDY_STOP_OUTLINE)

/// One afterimage while time is stopped: green, gone in 0.4 s. It sits on the user's own tile, shifted back to
/// where they were, so it sorts on their row and draws behind them in every facing.
/datum/status_effect/cyberware_cascade_window/proc/stopped_afterimage(turf/old_loc)
	var/turf/here = get_turf(owner)
	if(!here)
		return
	var/obj/effect/temp_visual/decoy/fading/cascade/stopped/image = new(here, owner, 0, afterimage_alpha)
	image.color = cyberware_time_stop_green()
	image.filters = null
	image.pixel_w = owner.pixel_w + (old_loc.x - here.x) * ICON_SIZE_X
	image.pixel_z = owner.pixel_z + (old_loc.y - here.y) * ICON_SIZE_Y
	image.layer = owner.layer - 0.01

/// The afterimage left while time is stopped.
/obj/effect/temp_visual/decoy/fading/cascade/stopped
	duration = 4

#undef SANDY_STOP_WITNESS_RANGE
#undef SANDY_STOP_FIELD_RANGE
#undef SANDY_STOP_BOSS_HOLD
#undef SANDY_STOP_SHOT_HANG
#undef SANDY_STOP_TRAIT
#undef SANDY_STOP_OUTLINE
