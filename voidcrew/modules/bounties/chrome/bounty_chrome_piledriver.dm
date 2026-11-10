/**
 * # Bounty chrome: the Meteor Piledriver
 *
 * Owner: C1. A criminal's Meteor Piledriver is the player's leg frame
 * (/obj/item/organ/cyberimp/cyberware/piledriver, ware_legend.dm): the leap, its reach, the warning
 * shadow, the 0.8 s in the air, the crush on whoever is still under it, the shockwave around it, and
 * the minute's cooldown are all the implant's own, and nothing here changes them. Once it is in the
 * air it comes down, as a player's leap does: shot or stunned up there, it still lands. This file is
 * only how an NPC uses it (owner decision 5):
 * - When: in a fight, with its target BOUNTY_PILEDRIVER_MIN_RANGE to BOUNTY_PILEDRIVER_MAX_RANGE tiles
 *   off and in sight (anyone closer it fights hand to hand), and a landing it can make: the target's
 *   own tile, or the nearest free tile beside them, that the implant itself would take (in reach, in
 *   sight, an open arc, a surface to land on) and that the NPC would choose: on its leash (a mini-boss
 *   also where its abilities may land), never space, a chasm or lava.
 * - Never onto people outside its fight (C0's bystander gate, over everything the landing reaches),
 *   and never onto anyone already down. Checked when it decides and again when it jumps.
 * - The tell: it drops into a crouch with its pistons whining and an amber glow, and a red reticle
 *   sits where it means to land, following its target, for BOUNTY_PILEDRIVER_CROUCH. Then the
 *   implant's own Meteor Leap, Trigger()ed onto the landing tile as a player's click; the implant puts
 *   its own warning shadow down there for the time it is in the air.
 * - If the landing is gone when the crouch ends (its target got behind a wall, a bystander walked in,
 *   its target went down), the pistons hiss and settle and nothing fires.
 * A target in a mech isn't leapt at: the landing can't reach anyone inside one.
 */

/// Nearest a target may be for a leap, in tiles: anyone closer is fought hand to hand
#define BOUNTY_PILEDRIVER_MIN_RANGE 3
/// Furthest a target may be for a leap, in tiles: a tile beside them stays in the implant's reach
#define BOUNTY_PILEDRIVER_MAX_RANGE 7
/// The implant's own reach (CYBERWARE_PILEDRIVER_RANGE, ware_legend.dm)
#define BOUNTY_PILEDRIVER_REACH 8
/// How far around the landing the implant's shockwave reaches (CYBERWARE_PILEDRIVER_IMPACT_RANGE, ware_legend.dm)
#define BOUNTY_PILEDRIVER_IMPACT 2
/// The crouch before the leap: its tell
#define BOUNTY_PILEDRIVER_CROUCH (1 SECONDS)
/// Pixels it sinks in the crouch
#define BOUNTY_PILEDRIVER_DIP 3
/// The glow through the crouch, piston amber
#define BOUNTY_PILEDRIVER_COLOR "#ffb347"
/// Offset source for the crouch
#define BOUNTY_PILEDRIVER_SOURCE "bounty_chrome_piledriver"

/datum/bounty_chrome_move/piledriver
	piece_key = BOUNTY_CHROME_PILEDRIVER
	name = "Meteor leap"
	action_type = /datum/action/cooldown/cyberware/piledriver_leap
	tell_time = BOUNTY_PILEDRIVER_CROUCH
	tell_color = BOUNTY_PILEDRIVER_COLOR
	tell_sound = 'sound/machines/piston/piston_lower.ogg'
	tell_lines = list("Heads up!", "Stay right there.", "Look up.")
	area_move = TRUE
	min_range = BOUNTY_PILEDRIVER_MIN_RANGE
	max_range = BOUNTY_PILEDRIVER_MAX_RANGE
	// Its time in the air on top of the usual gap
	recover_time = 5 SECONDS
	/// What the crouch is aimed at, while the reticle follows it
	var/atom/movable/tracked

/datum/bounty_chrome_move/piledriver/can_start(atom/target)
	if(ismecha(target) || !..())
		return FALSE
	var/turf/spot = landing_for(target)
	return !isnull(spot) && !downed_in(impact_turfs(spot))

/datum/bounty_chrome_move/piledriver/area_turfs(atom/target)
	var/turf/spot = landing_for(target)
	return spot ? impact_turfs(spot) : list()

/datum/bounty_chrome_move/piledriver/tell(atom/target)
	..()
	if(QDELETED(owner))
		return
	owner.add_offsets(BOUNTY_PILEDRIVER_SOURCE, z_add = -BOUNTY_PILEDRIVER_DIP)
	place_aim_mark(landing_for(target))
	stop_tracking()
	if(ismovable(target))
		tracked = target
		RegisterSignal(tracked, COMSIG_MOVABLE_MOVED, PROC_REF(on_tracked_moved))
		RegisterSignal(tracked, COMSIG_QDELETING, PROC_REF(stop_tracking))

/datum/bounty_chrome_move/piledriver/tell_text(atom/target)
	return "[owner] drops into a crouch, [owner.p_their()] leg pistons whining."

/datum/bounty_chrome_move/piledriver/clear_tell()
	stop_tracking()
	// Only its own crouch: offsets put back while it is up in the air would drop it out of its leap's rise. No animation: the rise starts from here a moment later.
	if(!QDELETED(owner) && (BOUNTY_PILEDRIVER_SOURCE in owner.offsets?[PIXEL_Z_OFFSET]))
		owner.remove_offsets(BOUNTY_PILEDRIVER_SOURCE, animate = FALSE)
	return ..()

/**
 * The crouch is over: it jumps at where its target stands now, as a player clicks where they see
 * them, if it still may. Otherwise the pistons settle and nothing fires.
 */
/datum/bounty_chrome_move/piledriver/effect(atom/target)
	var/turf/spot
	if(!QDELETED(target) && !ismecha(target) && bounty_ai_may_hit(owner, target))
		spot = landing_for(target)
	if(!spot || !bounty_chrome_area_clear(owner, impact_turfs(spot), target) || downed_in(impact_turfs(spot)))
		settle()
		return FALSE
	return bounty_chrome_trigger(owner, action_type, spot)

/// The crouch came to nothing: the pistons hiss and settle
/datum/bounty_chrome_move/piledriver/proc/settle()
	if(QDELETED(owner) || owner.stat != CONSCIOUS)
		return
	playsound(owner, 'sound/machines/steam_hiss.ogg', 40, TRUE)
	owner.visible_message(span_notice("[owner]'s leg pistons hiss and settle."))

/// Everything a landing on `spot` reaches: the tile, and the shockwave's ring around it
/datum/bounty_chrome_move/piledriver/proc/impact_turfs(turf/spot)
	return RANGE_TURFS(BOUNTY_PILEDRIVER_IMPACT, spot)

/// Whether anyone in `turfs` is down and still alive: it never lands on a person who is down
/datum/bounty_chrome_move/piledriver/proc/downed_in(list/turfs)
	for(var/turf/spot as anything in turfs)
		for(var/mob/living/person in spot)
			if(person != owner && person.stat != CONSCIOUS && person.stat != DEAD)
				return TRUE
	return FALSE

/**
 * The tile a leap at `target` comes down on now, or null if there is none: their own tile if it may
 * land there, else the free tile beside them nearest to it, never one next to where it stands.
 * Geometry only: who it may jump at is can_start()'s and effect()'s.
 */
/datum/bounty_chrome_move/piledriver/proc/landing_for(atom/target)
	var/turf/here = get_turf(owner)
	var/turf/aim = get_turf(target)
	if(!here || !aim || here.z != aim.z || !isturf(owner.loc))
		return null
	var/datum/action/cooldown/cyberware/piledriver_leap/leap = bounty_chrome_action(owner, action_type)
	if(!leap)
		return null
	if(landing_ok(here, aim, leap))
		return aim
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/beside as anything in RANGE_TURFS(1, aim))
		var/from_here = get_dist(here, beside)
		if(beside == aim || from_here < 2 || from_here >= best_distance)
			continue
		if(!landing_ok(here, beside, leap))
			continue
		best = beside
		best_distance = from_here
	return best

/**
 * Whether it may land on `spot` from `here`: what the implant itself takes (in reach and in sight, a
 * surface to land on, an open arc, Activate() in ware_legend.dm) and what the NPC chooses: never
 * space, a chasm or lava, and only on its own ground (on_its_ground()).
 */
/datum/bounty_chrome_move/piledriver/proc/landing_ok(turf/here, turf/spot, datum/action/cooldown/cyberware/piledriver_leap/leap)
	if(!spot || spot == here || get_dist(here, spot) > BOUNTY_PILEDRIVER_REACH)
		return FALSE
	if(isspaceturf(spot) || isopenspaceturf(spot) || islava(spot) || ischasm(spot))
		return FALSE
	if(spot.is_blocked_turf(exclude_mobs = TRUE))
		return FALSE
	if(!can_see(owner, spot, BOUNTY_PILEDRIVER_REACH) || leap.arc_blocker(here, spot))
		return FALSE
	return on_its_ground(spot)

/// Whether `spot` is ground it would land on: its leash (a companion its criminal's), and for a mini-boss where its abilities may land
/datum/bounty_chrome_move/piledriver/proc/on_its_ground(turf/spot)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = owner
	if(istype(boss))
		return boss.boss_landing_ok(spot)
	var/mob/living/carbon/human/npc/bounty_criminal/side = bounty_ai_side_of(owner)
	if(side)
		return side.leash_ok(spot)
	return spot.can_cross_safely(owner)

/// Puts the reticle on `spot`, or takes it away for a null one
/datum/bounty_chrome_move/piledriver/proc/place_aim_mark(turf/spot)
	// The reticle is the only mark the crouch puts down (add_mark())
	var/obj/effect/temp_visual/bounty_boss_mark/mark
	for(var/datum/weakref/mark_ref as anything in marks)
		var/obj/effect/temp_visual/bounty_boss_mark/live = mark_ref.resolve()
		if(!QDELETED(live))
			mark = live
			break
	if(!spot)
		if(mark)
			qdel(mark)
		return
	if(!mark)
		// The bounty bosses' red floor mark (bounty_boss.dm) as a reticle, like every boss mark and the implant's own shadow; deleted when the crouch ends, its duration only a backstop
		add_mark(new /obj/effect/temp_visual/bounty_boss_mark(spot, BOUNTY_PILEDRIVER_CROUCH * 3, null, "target_circle"))
		return
	mark.abstract_move(spot)

/// Its target moved in the crouch: the reticle follows to where it would land now
/datum/bounty_chrome_move/piledriver/proc/on_tracked_moved(atom/movable/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	place_aim_mark(landing_for(source))

/// Stops following its target. Safe at any time.
/datum/bounty_chrome_move/piledriver/proc/stop_tracking()
	SIGNAL_HANDLER
	if(tracked)
		UnregisterSignal(tracked, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	tracked = null

#undef BOUNTY_PILEDRIVER_MIN_RANGE
#undef BOUNTY_PILEDRIVER_MAX_RANGE
#undef BOUNTY_PILEDRIVER_REACH
#undef BOUNTY_PILEDRIVER_IMPACT
#undef BOUNTY_PILEDRIVER_CROUCH
#undef BOUNTY_PILEDRIVER_DIP
#undef BOUNTY_PILEDRIVER_COLOR
#undef BOUNTY_PILEDRIVER_SOURCE
