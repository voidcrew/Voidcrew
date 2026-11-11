/**
 * # The Cascade line's time dilation
 *
 * When a Cascade-line surge (ware_legend.dm, ware_line_sandy.dm) opens and no other player is within
 * SANDY_STOP_WITNESS_RANGE tiles, the world around the user slows down:
 *
 *   model        freeze  then slow-mo
 *   street       -       50% for 2 s
 *   service      -       35% for 3 s
 *   Cascade T4   1 s     20% for 3 s
 *
 * The rest of the window then runs as normal, then the crash. With another player near, the surge is the
 * plain one. Only a player's surge does this (the user needs a ckey): an NPC criminal's lattice never does.
 *
 * Built on tg's time stop field (code/datums/proximity_monitor/fields/timestop.dm), hosted on the user so
 * it follows them. Anything it touches stays slowed (or frozen) until the effect ends, even once the user
 * walks off. The field re-checks for players every tick and ends at once if one comes in.
 *
 * No shortcuts on people. A frozen mob gets tg's own TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED and
 * TRAIT_AI_PAUSED, never a fake state or a Stun. A slowed mob moves under a movespeed modifier, and every
 * tick the field pushes its timing deadlines back by the time it lost (next_move, ability cooldowns, AI
 * behaviour cooldowns and the blackboard deadlines listed in dilated_blackboard_keys(), ranged cooldowns).
 * Frozen and slowed bodies take damage, wounds and bleeding through tg as normal.
 *
 * Everything else in the field runs on the same slowed clock, through a few helpers below:
 * - cyberware_dilated_time() and cyberware_dilated_steps() turn a length of local time into real time, exact
 *   through the freeze, the slow-mo and the end. Hyperviolence gore uses them (flinches, death throes, blood
 *   paint, flying gibs), and so do a mech's weapon and melee cooldowns and a gun's fire delay.
 * - cyberware_time_lost() stretches do_after for a slowed body (VOIDCREW EDIT in do_after).
 * - Burst shots wait on a burst clock the field pushes back (cyberware_burst_wait()), so a burst queued before
 *   the slow-mo slows with it: guns (gun.dm) and basic mob ranged attacks (ranged_attacks.dm).
 * - The field pushes back mech move cooldowns, turret fire cooldowns and lit grenade fuses (_grenade.dm), and
 *   shuts a mech down for the freeze.
 * Things in hand stay held until the effect ends; gore and blood that merely stand in the field are slowed
 * while they are within its range. The user and anything the user carries are never slowed.
 *
 * Bosses (a finisher user, or a boss-rank human NPC) are held for SANDY_STOP_BOSS_HOLD at most.
 *
 * Each surge model speeds its bearer up by a time multiplier (the lattice's time_multiplier): street 2x, service
 * about 2.86x, Cascade 5x. A mob on its own surge (a bounty NPC's lattice) runs at its multiplier over the user's,
 * at most SANDY_STOP_MAX_RELATIVE: a street NPC in a Cascade's field at 40%, an equal tier at 100% (left alone),
 * a Cascade NPC in a street user's field at 200% (2.5x, capped). The user's freeze doesn't change that: a surging
 * mob keeps its relative rate through it, so the freeze only stops those with no surge. Faster than the user runs
 * the same machinery the other way (its deadlines, cooldowns, walk and gore come sooner). A surging mob is
 * never tinted, at any rate. If it surges while already held, the field lets it go at once, drops every slow it
 * was carrying (surge_free()) and takes it back at its relative rate. When its window closes the field takes it at
 * the field's own pace, unless it is dead: a corpse freed by a surge is left as it fell.
 *
 * The user's reflex dodge (ware_pro_combat.dm) is off while the world is slowed: the speed gap already does that
 * job. It comes back for the rest of the window.
 *
 * Look: affected things get a grey-green tint instead of tg's inversion. Floor items, blood decals and the
 * user are never touched, so they keep their colour, and so do the user's own shots. Every bullet in the field
 * flies at the field's pace, whoever fired it: the user's and a surging mob's crawl in the slow-mo like the rest
 * (a faster surger fires sooner, but its bullets still crawl), untinted. Shots the user fires while the world is
 * frozen fly a tile, hang there, and go on when it starts moving again. A shot leaving the field gets its speed back.
 */

/// Another player within this many tiles of the user means no dilation.
#define SANDY_STOP_WITNESS_RANGE 11
/// Radius of the field around the user (a widescreen view is 9 tiles to each side).
#define SANDY_STOP_FIELD_RANGE 9
/// How long a boss stays frozen or slowed before it shrugs the field off.
#define SANDY_STOP_BOSS_HOLD (1 SECONDS)
/// How far, in pixels, the user's own shots fly before they hang in a frozen world.
#define SANDY_STOP_SHOT_HANG 32
/// The fastest a surging mob runs in someone else's field, relative to normal speed.
#define SANDY_STOP_MAX_RELATIVE 2
/// Relative rates this close to 1 count as the same speed: the mob is left alone.
#define SANDY_STOP_SAME_RATE 0.01
/// Trait source for everything the dilation applies.
#define SANDY_STOP_TRAIT "sandevistan_time_stop"
/// Filter name of the user's edge glow.
#define SANDY_STOP_OUTLINE "sandy_time_stop_outline"

/// Every atom the dilation has hold of, to its field.
GLOBAL_LIST_EMPTY(cyberware_time_dilated)

/// How fast time runs for `thing`: 1 normally, 0 frozen, in between in slow-mo, above 1 for a faster surger.
/proc/cyberware_time_scale(atom/thing)
	if(isnull(thing))
		return 1
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = GLOB.cyberware_time_dilated[thing]
	return field ? field.scale_for(thing) : 1

/// Every dilation field running now.
GLOBAL_LIST_EMPTY(cyberware_time_fields)

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

/// Whether `bearer` is slowing the world around them right now (the freeze or the slow-mo).
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

/// The next hue for a surging `bearer`'s rainbow trail: inside someone's field it skips the greens, which read as the field's own tint.
/proc/cyberware_time_trail_hue(mob/living/bearer, hue)
	if(hue < 70 || hue > 170)
		return hue
	for(var/datum/proximity_monitor/advanced/timestop/sandevistan/field as anything in GLOB.cyberware_time_fields)
		if(field.surging[bearer])
			return 170
	return hue

/// How long, in real time, `time` deciseconds of `thing`'s own time take from now. Exact through the freeze,
/// the slow-mo and the end of the effect, as the field stands now.
/proc/cyberware_dilated_time(atom/thing, time)
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = cyberware_time_field(thing)
	if(!field)
		return time
	return field.real_time_for(thing, time)

/**
 * Real-time lengths for a chain of animation steps `times` on `thing`: list(hold, step 1, step 2, ...), or null
 * when it isn't slowed. `hold` is how long it sits still first (the freeze). A looping chain just plays at the
 * field's pace. `tag` names the animation, so a held mob that breaks free (surge_free()) can drop it.
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
		if(scale <= 0)
			scale = field.slow_scale
		real += 0
		for(var/time in times)
			real += time / max(scale, 0.05)
		return real
	var/hold = field.real_time_for(thing, 0)
	real += hold
	var/local = 0
	var/reached = hold
	for(var/time in times)
		local += time
		var/at = field.real_time_for(thing, local)
		real += max(at - reached, 0)
		reached = at
	return real

/// Time `thing` lost in the last `elapsed` deciseconds: all of it frozen, none of it outside a field. Negative for a
/// surger running faster than normal: it gained time.
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
	if(!cyberware_time_scale(shooter))
		return world.tick_lag
	var/due = start + cyberware_time_lag(shooter) + gap * index
	return due - world.time >= world.tick_lag ? due - world.time : 0

/// Whether a player other than `user` is within `range` tiles: any living body with a ckey, connected or not.
/proc/cyberware_time_stop_witnessed(mob/living/user, range = SANDY_STOP_WITNESS_RANGE)
	var/turf/here = get_turf(user)
	if(!here)
		return TRUE
	for(var/atom/movable/found as anything in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_HEARING, range))
		if(found == user)
			continue
		if(isliving(found))
			var/mob/living/body = found
			if(body.ckey)
				return TRUE
			continue
		if(ismob(found) || isitem(found)) // ghosts and camera eyes don't count; radios hold nobody
			continue
		// a locker or a mech with a player in it
		for(var/mob/living/inside in found.get_all_contents())
			if(inside != user && inside.ckey)
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
	/// How long the world is frozen first.
	var/freeze_time = 0
	/// How fast the world runs after that.
	var/slow_scale = 1
	/// The user's own time multiplier (their surge model's), for surging mobs' relative rates.
	var/user_multiplier = 1

/// `immune_atoms` must be list(user). `time` is the whole effect; `freeze` of it is frozen, the rest at `scale`.
/// `multiplier` is the user's surge model's time multiplier.
/obj/effect/timestop/sandevistan/Initialize(mapload, radius, time, list/immune_atoms, start = TRUE, silent = TRUE, freeze = 0, scale = 1, multiplier = 1)
	if(length(immune_atoms))
		user = immune_atoms[1]
	freeze_time = freeze
	slow_scale = scale
	user_multiplier = multiplier
	return ..(mapload, radius, time, immune_atoms, start, TRUE)

/obj/effect/timestop/sandevistan/Destroy()
	user = null
	return ..()

/obj/effect/timestop/sandevistan/timestop()
	target = get_turf(src)
	QDEL_IN(src, duration)
	if(QDELETED(user))
		return
	var/datum/proximity_monitor/advanced/timestop/sandevistan/field = new(user, freezerange, TRUE, immune, antimagic_flags, FALSE, freeze_time > 0 ? 0 : slow_scale, user_multiplier)
	field.stopper = src
	field.slow_scale = slow_scale
	if(freeze_time > 0)
		field.thaw_at = world.time + freeze_time
	field.ends_at = world.time + duration
	chronofield = field

// =========================================================================
// THE FIELD
// =========================================================================

/datum/proximity_monitor/advanced/timestop/sandevistan
	/// The effect that owns this field. Deleting it ends the dilation.
	var/obj/effect/timestop/sandevistan/stopper
	/// How fast time runs in here right now. 0 is frozen.
	var/time_scale = 0
	/// The slow-mo scale the field drops to once the freeze ends.
	var/slow_scale = 1
	/// world.time the freeze ends and slow-mo starts, or 0.
	var/thaw_at = 0
	/// world.time of the last tick, for how much time each tick dilated.
	var/last_tick = 0
	/// The field's own clock. A timer, not SSfastprocess, which sleeps outside RUNLEVEL_GAME.
	var/tick_timer
	/// Mobs in hand.
	var/list/held_mobs = list()
	/// Projectiles in hand, to their own speed.
	var/list/held_shots = list()
	/// Thrown things in hand.
	var/list/held_throws = list()
	/// The user's own shots: never tinted. A surging mob's held shots aren't tinted either.
	var/list/user_shots = list()
	/// Bosses in hand, to the world.time they shrug the field off.
	var/list/boss_holds = list()
	/// Bosses that already shrugged it off. The field leaves them be.
	var/list/released = list()
	/// world.time the effect ends, when time runs normally again.
	var/ends_at = INFINITY
	/// Mechs held, to whether the field shut them down for the freeze.
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

/datum/proximity_monitor/advanced/timestop/sandevistan/New(atom/_host, range, _ignore_if_not_on_turf = TRUE, list/immune, antimagic_flags, channelled, start_scale = 0, _user_multiplier = 1)
	time_scale = start_scale
	user_multiplier = _user_multiplier > 0 ? _user_multiplier : 1
	last_tick = world.time
	GLOB.cyberware_time_fields += src
	. = ..()
	STOP_PROCESSING(SSfastprocess, src) // tick() runs on tick_timer instead
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), 0.2 SECONDS, TIMER_LOOP | TIMER_STOPPABLE | TIMER_DELETE_ME)
	RegisterSignal(host, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_user_fire))
	if(ismob(host))
		senses = new(src)

/datum/proximity_monitor/advanced/timestop/sandevistan/Destroy()
	QDEL_NULL(senses)
	deltimer(tick_timer)
	tick_timer = null
	if(host)
		UnregisterSignal(host, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)
	stopper = null
	GLOB.cyberware_time_fields -= src
	for(var/mob/living/surger as anything in surging)
		UnregisterSignal(surger, COMSIG_QDELETING)
	surging.Cut()
	. = ..() // unfreeze_all() lets everything go
	own_scales.Cut()
	released.Cut()

/// How long, in real time from now, `local` deciseconds of `thing`'s own time take: the rest of the freeze,
/// then the slow-mo until the effect (or a boss's hold) ends, then real time.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/real_time_for(atom/thing, local)
	var/now = world.time
	var/ends = ends_at
	if(boss_holds[thing])
		ends = min(ends, boss_holds[thing])
	if(ends <= now)
		return local
	var/own = own_scales[thing]
	if(own) // a surger at its own steady rate, freeze or not
		var/own_span = (ends - now) * own
		if(local <= own_span)
			return local / own
		return ends - now + local - own_span
	if(surging[thing])
		return local
	var/at = now
	var/scale = time_scale
	if(scale <= 0)
		at = thaw_at ? min(thaw_at, ends) : ends
		scale = slow_scale
	if(at < ends && scale > 0)
		var/span = (ends - at) * scale
		if(local <= span)
			return at - now + local / scale
		local -= span
		at = ends
	return at - now + local

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
	if(!istype(A) || GLOB.cyberware_time_dilated[A] || global_frozen_atoms[A] || released[A] || immune[A] || surging[A])
		return FALSE
	if(cyberware_own_surge(A))
		take_surger(A, cyberware_surge_multiplier(A))
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
			if(time_scale <= 0) // hang_shot takes these
				return FALSE
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
		if(time_scale <= 0)
			hold_turret_fire(A)
	else if((ismachinery(A) && !istype(A, /obj/machinery/light)) || isstructure(A))
		frozen_structures += A // looks only
	else if(cyberware_lit_grenade(A))
		held_grenades[A] = TRUE
		tint = !!A.throwing // floor items keep their colour
	else if(!A.throwing)
		return FALSE
	if(A.throwing)
		held_throws[A] = TRUE
		if(time_scale <= 0)
			A.throwing.paused = TRUE
	GLOB.cyberware_time_dilated[A] = src
	frozen_things[A] = TRUE
	RegisterSignal(A, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)
	if(tint)
		into_the_negative_zone(A)
	SEND_SIGNAL(A, COMSIG_ATOM_TIMESTOP_FREEZE, src)
	return TRUE

/datum/proximity_monitor/advanced/timestop/sandevistan/unfreeze_all()
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
		var/datum/thrownthing/throw_datum = A.throwing
		if(throw_datum)
			throw_datum.paused = FALSE
		held_throws -= A
	if(!isnull(held_mechs[A]))
		start_mech(A)
		held_mechs -= A
	held_turrets -= A
	held_grenades -= A
	frozen_structures -= A
	user_shots -= A
	slowed_tags -= A
	own_scales -= A
	UnregisterSignal(A, COMSIG_QDELETING)
	escape_the_negative_zone(A)
	frozen_things -= A
	GLOB.cyberware_time_dilated -= A
	SEND_SIGNAL(A, COMSIG_ATOM_TIMESTOP_UNFREEZE, src)

// ----- mobs -----

/// Takes hold of a mob: frozen or slowed (or sped up, for a faster surger), whichever its rate is.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_mob(mob/living/victim)
	held_mobs[victim] = TRUE
	var/rate = scale_for(victim)
	if(rate <= 0)
		freeze_mob(victim)
	else
		slow_mob(victim)
	if(rate < 1 && cyberware_time_stop_boss(victim))
		boss_holds[victim] = world.time + SANDY_STOP_BOSS_HOLD

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/let_go_mob(mob/living/victim)
	unfreeze_mob(victim)
	unslow_mob(victim)
	held_mobs -= victim
	boss_holds -= victim

/datum/proximity_monitor/advanced/timestop/sandevistan/freeze_mob(mob/living/victim)
	frozen_mobs[victim] = TRUE
	victim.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_AI_PAUSED, TRAIT_MUTE, TRAIT_EMOTEMUTE), SANDY_STOP_TRAIT)
	GLOB.move_manager.stop_looping(victim)
	if(isanimal(victim)) // the old simple mob AI doesn't read TRAIT_AI_PAUSED
		var/mob/living/simple_animal/animal_victim = victim
		animal_victim.toggle_ai(AI_OFF)

/datum/proximity_monitor/advanced/timestop/sandevistan/unfreeze_mob(mob/living/victim)
	if(!frozen_mobs[victim])
		return
	frozen_mobs -= victim
	victim.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED, TRAIT_AI_PAUSED, TRAIT_MUTE, TRAIT_EMOTEMUTE), SANDY_STOP_TRAIT)
	if(isanimal(victim))
		var/mob/living/simple_animal/animal_victim = victim
		animal_victim.toggle_ai(initial(animal_victim.AIStatus))

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
	var/now = world.time
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

// ----- mobs on their own surge -----

/**
 * `surger` runs its own surge at `multiplier`: at the same rate as the user it is left alone; otherwise the field
 * holds it at its relative rate, slower or faster, untinted. The user's freeze doesn't touch it.
 */
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/take_surger(mob/living/surger, multiplier)
	surging[surger] = TRUE
	RegisterSignal(surger, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)
	var/rate = relative_rate(multiplier)
	if(abs(rate - 1) < SANDY_STOP_SAME_RATE)
		return
	own_scales[surger] = rate
	hold_mob(surger)
	GLOB.cyberware_time_dilated[surger] = src
	frozen_things[surger] = TRUE
	SEND_SIGNAL(surger, COMSIG_ATOM_TIMESTOP_FREEZE, src)

/**
 * `surger` opened its own surge at `multiplier`: if the field holds it, let it go now and drop every slow it
 * carried (its walk, its pauses, its last bit of lost time, its slowed animations and the shots it fired), then
 * take it back at its relative rate. Its shots go back in at the field's pace, untinted.
 */
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/surge_free(mob/living/surger, multiplier)
	if(surging[surger])
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
	held_mechs[mech] = FALSE
	if(time_scale <= 0)
		stop_mech(mech)
	for(var/mob/living/pilot in mech.occupants)
		freeze_atom(pilot)

/// The freeze shuts a mech down, as tg's own time stop does.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/stop_mech(obj/vehicle/sealed/mecha/mech)
	if(held_mechs[mech] || mech.completely_disabled)
		return
	mech.completely_disabled = TRUE
	held_mechs[mech] = TRUE

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/start_mech(obj/vehicle/sealed/mecha/mech)
	if(!held_mechs[mech])
		return
	mech.completely_disabled = FALSE
	held_mechs[mech] = FALSE

/// A frozen turret's cooldown stays a little ahead of the clock, so it can't fire until time moves.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_turret_fire(obj/machinery/porta_turret/turret)
	turret.last_fired = max(turret.last_fired, world.time + 0.3 SECONDS - turret.shot_delay)

/// Pushes back the clocks of held machines and grenades by `push` deciseconds.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/push_machine_deadlines(push)
	var/now = world.time
	for(var/obj/vehicle/sealed/mecha/mech as anything in held_mechs)
		if(mech.cooldown_vehicle_move > now)
			mech.cooldown_vehicle_move += push
	for(var/obj/machinery/porta_turret/turret as anything in held_turrets)
		if(turret.last_fired + turret.shot_delay > now)
			turret.last_fired += push
		if(time_scale <= 0)
			hold_turret_fire(turret)
	for(var/obj/item/grenade/bomb as anything in held_grenades)
		if(bomb.cyberware_fuse_at > now)
			bomb.cyberware_fuse_at += push

// ----- projectiles -----

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hold_shot(obj/projectile/shot)
	held_shots[shot] = shot.speed
	var/rate = scale_for(shot)
	if(rate <= 0)
		shot.paused = TRUE
	else
		shot.speed = held_shots[shot] * rate

/datum/proximity_monitor/advanced/timestop/sandevistan/proc/let_go_shot(obj/projectile/shot)
	shot.speed = held_shots[shot]
	shot.paused = FALSE
	held_shots -= shot

/// Signal proc for [COMSIG_PROJECTILE_FIRER_BEFORE_FIRE] on the user: watch the shot leave the barrel.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/on_user_fire(datum/source, obj/projectile/shot, atom/fired_from, atom/original)
	SIGNAL_HANDLER
	RegisterSignal(shot, COMSIG_PROJECTILE_FIRE, PROC_REF(hang_shot))

/// Signal proc for [COMSIG_PROJECTILE_FIRE]: the user's shot keeps its colour but flies at the field's pace like
/// every bullet in it. In a frozen world it flies a tile, then hangs; in the slow-mo it crawls with the rest.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/hang_shot(obj/projectile/shot)
	SIGNAL_HANDLER
	UnregisterSignal(shot, COMSIG_PROJECTILE_FIRE)
	if(QDELETED(shot) || shot.deletion_queued)
		return
	if(time_scale > 0)
		user_shots[shot] = TRUE
		escape_the_negative_zone(shot) // in case it was tinted before it had a firer
		if(!held_shots[shot])
			hold_shot(shot)
			GLOB.cyberware_time_dilated[shot] = src
			frozen_things[shot] = TRUE
			RegisterSignal(shot, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)
		return
	// A hitscan beam takes its first step itself once paused (process_hitscan) and stops there.
	if(!shot.hitscan)
		shot.paused = FALSE // it may have been caught before it had a firer
		shot.process_movement(SANDY_STOP_SHOT_HANG)
		if(QDELETED(shot) || shot.deletion_queued)
			return
	user_shots[shot] = TRUE
	escape_the_negative_zone(shot) // in case it was tinted before it had a firer
	if(held_shots[shot])
		shot.paused = TRUE
	else
		hold_shot(shot)
	GLOB.cyberware_time_dilated[shot] = src
	frozen_things[shot] = TRUE
	RegisterSignal(shot, COMSIG_QDELETING, PROC_REF(held_gone), override = TRUE)

/// Forgets a held thing that got deleted.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/held_gone(atom/movable/thing)
	SIGNAL_HANDLER
	held_shots -= thing
	user_shots -= thing
	held_mobs -= thing
	frozen_mobs -= thing
	held_throws -= thing
	held_mechs -= thing
	held_turrets -= thing
	held_grenades -= thing
	boss_holds -= thing
	surging -= thing
	slowed_tags -= thing
	own_scales -= thing
	frozen_structures -= thing
	frozen_things -= thing
	GLOB.cyberware_time_dilated -= thing

// ----- the clock -----

/// Moves the whole field to a new pace: frozen things start moving, slowed things change speed.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/set_time_scale(new_scale)
	time_scale = new_scale
	for(var/mob/living/victim as anything in held_mobs)
		if(own_scales[victim]) // a surger keeps its own rate
			continue
		unfreeze_mob(victim)
		if(time_scale <= 0)
			unslow_mob(victim)
			freeze_mob(victim)
		else
			slow_mob(victim)
	for(var/obj/projectile/shot as anything in held_shots)
		shot.paused = time_scale <= 0
		if(time_scale > 0)
			shot.speed = held_shots[shot] * time_scale
	for(var/atom/movable/thing as anything in held_throws)
		if(thing.throwing)
			thing.throwing.paused = time_scale <= 0
	for(var/obj/vehicle/sealed/mecha/mech as anything in held_mechs)
		if(time_scale <= 0)
			stop_mech(mech)
		else
			start_mech(mech)
	senses?.update()

/datum/proximity_monitor/advanced/timestop/sandevistan/process()
	return PROCESS_KILL

/// Every 0.2 s: end if a player came in, push back the timers of everything held, let bosses go, end the freeze.
/datum/proximity_monitor/advanced/timestop/sandevistan/proc/tick()
	if(QDELETED(host) || cyberware_time_stop_witnessed(host))
		if(!QDELETED(stopper))
			qdel(stopper) // takes this field with it
		return
	var/elapsed = world.time - last_tick
	last_tick = world.time
	for(var/mob/living/victim as anything in held_mobs)
		var/lost = elapsed * (1 - scale_for(victim)) // a faster surger's is negative: its deadlines come sooner
		if(lost)
			push_deadlines(victim, lost)
	var/push = elapsed * (1 - time_scale)
	if(push > 0)
		for(var/atom/movable/thing as anything in held_throws)
			var/datum/thrownthing/throw_datum = thing.throwing
			if(throw_datum && !throw_datum.paused)
				throw_datum.start_time += push
		push_machine_deadlines(push)
	check_surgers()
	for(var/mob/living/boss as anything in boss_holds.Copy())
		if(world.time < boss_holds[boss])
			continue
		unfreeze_atom(boss)
		released[boss] = TRUE
	if(thaw_at && world.time >= thaw_at)
		thaw_at = 0
		set_time_scale(slow_scale)
	senses?.refresh_weather()

/datum/proximity_monitor/advanced/timestop/sandevistan/into_the_negative_zone(atom/A)
	A.add_atom_colour(cyberware_time_stop_tint(), TEMPORARY_COLOUR_PRIORITY)

// =========================================================================
// THE WINDOW'S SIDE
// =========================================================================

/datum/status_effect/cyberware_cascade_window
	/// How long the world is frozen if nobody else is near when the window opens. Copied from the lattice.
	var/dilation_freeze = 1 SECONDS
	/// How long slow-mo runs after the freeze.
	var/dilation_time = 3 SECONDS
	/// How fast the world runs in slow-mo.
	var/dilation_scale = 0.2
	/// How much faster than normal the bearer runs: sets surging mobs' relative rates in each other's fields.
	var/time_multiplier = 5
	/// The running dilation, if any.
	var/obj/effect/timestop/sandevistan/time_stop
	/// Whether this window slowed the world. Its trail stays green after the dilation ends.
	var/dilated = FALSE

/// Slows the world if the bearer is a player and nobody else is near. Called as the window opens.
/datum/status_effect/cyberware_cascade_window/proc/try_time_stop()
	cyberware_surge_frees(owner, time_multiplier) // anyone's surge runs at its own rate in someone else's field
	if(dilation_freeze + dilation_time <= 0 || !owner.ckey || time_stop)
		return FALSE
	if(cyberware_time_stop_witnessed(owner))
		return FALSE
	var/turf/here = get_turf(owner)
	if(!here)
		return FALSE
	time_stop = new(here, SANDY_STOP_FIELD_RANGE, dilation_freeze + dilation_time, list(owner), TRUE, TRUE, dilation_freeze, dilation_scale, time_multiplier)
	if(QDELETED(time_stop))
		time_stop = null
		return FALSE
	RegisterSignal(time_stop, COMSIG_QDELETING, PROC_REF(time_stop_over))
	dilated = TRUE
	owner.remove_client_colour(id) // the user sees the slowed world as it is
	owner.add_filter(SANDY_STOP_OUTLINE, 2, outline_filter(1, "#5AFF96D2"))
	return TRUE

/// Signal proc for [COMSIG_QDELETING] on the dilation: time runs normally and the rest of the window carries on.
/datum/status_effect/cyberware_cascade_window/proc/time_stop_over(datum/source)
	SIGNAL_HANDLER
	time_stop = null
	if(QDELETED(owner))
		return
	owner.remove_filter(SANDY_STOP_OUTLINE)
	owner.add_client_colour(colour_type, id)

/// Ends the dilation early (the window is closing).
/datum/status_effect/cyberware_cascade_window/proc/end_time_stop()
	if(!time_stop)
		return
	UnregisterSignal(time_stop, COMSIG_QDELETING)
	QDEL_NULL(time_stop)
	if(!QDELETED(owner))
		owner.remove_filter(SANDY_STOP_OUTLINE)

/// One afterimage while time is dilated: green, gone in 0.4 s. It sits on the user's own tile, shifted back to
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

/// The afterimage left while time is dilated.
/obj/effect/temp_visual/decoy/fading/cascade/stopped
	duration = 4

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
	if(wait >= world.tick_lag || (GLOB.cyberware_time_dilated[src] && !cyberware_time_scale(src)))
		addtimer(CALLBACK(src, PROC_REF(cyberware_fuse_done)), max(wait, world.tick_lag), TIMER_DELETE_ME)
		return
	cyberware_fuse_at = 0
	detonate()

#undef SANDY_STOP_WITNESS_RANGE
#undef SANDY_STOP_FIELD_RANGE
#undef SANDY_STOP_BOSS_HOLD
#undef SANDY_STOP_SHOT_HANG
#undef SANDY_STOP_MAX_RELATIVE
#undef SANDY_STOP_SAME_RATE
#undef SANDY_STOP_TRAIT
#undef SANDY_STOP_OUTLINE
