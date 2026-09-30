/**
 * # World population: the dancer at the Undertow's pole (owner request)
 *
 * A woman who dances on the Undertow's "strip pole" (a suplexed rod, /obj/structure/festivus/anchored,
 * standing on a /obj/structure/platform beside the kingpin's sofa) for the crowd, on PA's outpost
 * base (outpost_patrons.dm). Built on the same seams as outpost_workers.dm: settle_in() finds her
 * mid-dance, shift_times() covers her own activity's timers, and she costs nothing while the outpost
 * is frozen.
 *
 * She dances up on the pole's own tile. It is dense (the platform) and in the kingpin's lounge, so
 * PA's standable() keeps her and everyone else off it; the dance checks that one tile itself
 * (dancer/pole_free()). She walks up beside it and climbs on with a short forceMove; settle_in()
 * finds her already up there. On it she dances round the pole's west, south and east sides (never
 * behind it, where she would hide it), facing away from it or into it, held against it by small
 * pixel_w/pixel_z offsets on top of the platform's own elevation, with spins, hops and leans that
 * end where they began. Her mob layer draws over the platform and the rod (both BELOW_OBJ_LAYER).
 *
 * Her hold on the pole follows her tile, whatever moves her (a shove, a mob swap, her own climb):
 * off it she lets go at once and climbs back up in a moment. Every ending of the dance (a break, a
 * fight, a shootout, death, fading) stops any spin and steps her down to a free tile beside it.
 *
 * Now and then she takes a short break at the bar or a nearby seat. If the kingpin's crew starts
 * shooting she screams and runs for the lounge's refuge (take_cover, shootout_over()). Any other
 * fight at the outpost, or a hit on her, she runs a few steps clear of it and keeps her head down
 * (dancer_hide), screaming if it is by his seat or at her. Either way she stays at the outpost, and
 * once it has been quiet a while she goes straight back up on her pole (back_to_pole).
 *
 * She wears a bikini and performer's boots. The bikini is an underwear accessory set on the dummy
 * her look is built on (outpost_npc_looks.dm), so it is drawn on her body and cached per outfit
 * like every other look; she carries nothing drawn over her. That same pre_equip() fixes the rest
 * of her look too: always a woman, fair-skinned, blonde and blue-eyed (owner request).
 *
 * Her lines are in strings/outpost_dancer.json, section "dancer".
 */

/// add_offsets()/remove_offsets() source key for her place against the pole
#define DANCE_POLE_OFFSET_SOURCE "dance_pole"
/// How far from the pole's middle she stands against it, in pixels
#define DANCE_POLE_HUG 5
/// Climbs in a row that find someone else on the pole before she gives the dance up for now
#define DANCE_CLIMB_TRIES 5
/// How near the kingpin's seat counts as "near him" for her scream-and-run reaction
#define DANCER_KINGPIN_ALARM_RADIUS 3
/// How long it has to stay quiet before she comes out of hiding and goes back to her pole
#define DANCER_CALM_TIME (30 SECONDS)
/// The longest she stays hidden from one fight
#define DANCER_HIDE_MAX (5 MINUTES)
/// How far from where she was she runs to get clear of a fight
#define DANCER_HIDE_RANGE 5

// =========================================================================
// OUTFIT
// =========================================================================

/// A red bikini and blue performer's boots
/datum/outfit/ambient_dancer
	name = "Outpost dancer (red)"
	/// Her bikini: an underwear accessory, by name (SSaccessories.underwear_list)
	var/bikini = "Neko Bikini (Black)"

/**
 * No uniform: the bikini is underwear on the body, drawn by the update_body() that ends equip().
 */
/datum/outfit/ambient_dancer/pre_equip(mob/living/carbon/human/user, visuals_only = FALSE)
	user.underwear = bikini
	user.undershirt = "Nude"
	user.socks = "Thigh-high (Fishnet)"
	user.gender = FEMALE
	user.physique = FEMALE
	user.skin_tone = "caucasian2"
	user.set_hairstyle("Ponytail 7", update = FALSE)
	user.set_haircolor("#CC0000", update = FALSE)
	user.set_facial_hairstyle("Shaved", update = FALSE)
	user.set_eye_color("#663300")
	user.update_lips("lipstick", "#000000", update = FALSE)
	// The update_body() that ends equip() isn't is_creating, so it won't pick up the skin tone above on its own
	user.update_body(is_creating = TRUE)

// =========================================================================
// THE DANCER
// =========================================================================

/// Dances on the pole for the crowd, and screams and runs if the kingpin's crew starts trouble
/mob/living/basic/ambient_npc/outpost/dancer
	desc = "Dances on the pole for the crowd."
	dialogue_file = "outpost_dancer.json"
	dialogue_section = "dancer"
	gender = FEMALE
	random_gender = FALSE
	outfit_choices = list(
		/datum/outfit/ambient_dancer
	)
	routine = list(
		/datum/ambient_activity/dance_pole = 6,
		/datum/ambient_activity/sit = 1,
	)
	/// Set when trouble sends her off the pole: the first thing she does once it is over is climb back on
	var/back_to_pole = FALSE

/// Dances at the pole, with the odd break at the bar or a nearby seat. Straight back to the pole after trouble.
/mob/living/basic/ambient_npc/outpost/dancer/pick_activity()
	if(back_to_pole)
		back_to_pole = FALSE
		if(start_activity(new /datum/ambient_activity/dance_pole(src)))
			return activity
	var/list/bar = ambient_outpost_bar(place)
	var/atom/bar_spot = length(bar) ? bar[1] : null
	return pick_anchored(routine, bar_spot, list(/datum/ambient_activity/sit))

/// Found mid-dance, up on the pole
/mob/living/basic/ambient_npc/outpost/dancer/settle_in()
	if(settle_at(/datum/ambient_activity/dance_pole))
		return TRUE
	return ..()

/// The Undertow's suplexed rod, if there is one
/mob/living/basic/ambient_npc/outpost/dancer/proc/find_pole()
	return ambient_outpost_find(get_outpost(), /obj/structure/festivus/anchored)

/**
 * Whether she could get up on the pole's `tile` now. PA's standable() keeps everyone off it (it is
 * dense, and in the kingpin's lounge), and still keeps her off it for everything else she does; this
 * is the dance's own check for that one tile: open ground on her leash, not in `avoid`, and nobody
 * else on it, standing or lying.
 */
/mob/living/basic/ambient_npc/outpost/dancer/proc/pole_free(turf/tile, list/avoid)
	if(!isturf(tile) || LAZYACCESS(avoid, tile))
		return FALSE
	if(!isopenturf(tile) || isspaceturf(tile) || isgroundlessturf(tile) || islava(tile) || ischasm(tile))
		return FALSE
	for(var/mob/living/other in tile)
		if(other != src)
			return FALSE
	return leash_ok(tile)

/// A fight at the outpost: she gets clear of it and keeps her head down until it has been quiet a while, screaming if it is right by the kingpin. She never leaves over it.
/mob/living/basic/ambient_npc/outpost/dancer/react_violence(mob/living/offender)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave) || istype(activity, /datum/ambient_activity/take_cover))
		return
	// Already hiding: it is still going on
	if(still_hiding())
		return
	if(!reaction_ready("violence"))
		return
	if(!hide_from(offender))
		return
	if(ambient_in_kingpin_lounge(offender, DANCER_KINGPIN_ALARM_RADIUS))
		scream()
	else if(prob(50))
		speak_context(AMBIENT_LINE_VIOLENCE, offender, force = TRUE)

/// Hit herself: she screams and gets clear, and goes back to her pole once it is quiet
/mob/living/basic/ambient_npc/outpost/dancer/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave))
		return
	if(still_hiding())
		return
	if(!reaction_ready("attacked"))
		return
	if(hide_from(attacker))
		scream()

/// The kingpin's crew is shooting: she screams and runs for cover, and goes back to her pole once it is over (shootout_over(), inherited)
/mob/living/basic/ambient_npc/outpost/dancer/react_shootout(turf/refuge)
	if(stat != CONSCIOUS || fading || istype(activity, /datum/ambient_activity/leave) || istype(activity, /datum/ambient_activity/take_cover))
		return
	if(start_activity(new /datum/ambient_activity/take_cover(src, refuge)))
		back_to_pole = TRUE
		scream()

/// Starts her hiding from `threat`. TRUE if she is.
/mob/living/basic/ambient_npc/outpost/dancer/proc/hide_from(atom/threat)
	if(!start_activity(new /datum/ambient_activity/dancer_hide(src, threat)))
		return FALSE
	back_to_pole = TRUE
	return TRUE

/// If she is hiding, more trouble means it is not quiet yet, so she stays hidden longer. TRUE if she is hiding.
/mob/living/basic/ambient_npc/outpost/dancer/proc/still_hiding()
	var/datum/ambient_activity/dancer_hide/hiding = activity
	if(!istype(hiding))
		return FALSE
	hiding.calm_at = world.time + DANCER_CALM_TIME
	return TRUE

/// A free tile within DANCER_HIDE_RANGE of her, further from `threat` than she is and as far as she can find; null to stay put
/mob/living/basic/ambient_npc/outpost/dancer/proc/hiding_spot(atom/threat, list/avoid)
	var/turf/here = get_turf(src)
	var/turf/danger = get_turf(threat)
	if(!here || !danger || danger.z != here.z)
		return null
	var/datum/ambient_place/outpost/outpost_place = istype(place, /datum/ambient_place/outpost) ? place : null
	var/turf/best
	var/best_distance = get_dist(danger, here)
	for(var/turf/tile as anything in RANGE_TURFS(DANCER_HIDE_RANGE, here))
		var/distance = get_dist(danger, tile)
		if(distance <= best_distance || !standable(tile, avoid, TRUE))
			continue
		// Somebody is on it or heading there
		if(outpost_place && outpost_place.crowd_count(tile, src) == INFINITY)
			continue
		best = tile
		best_distance = distance
	return best

/// A woman's scream. Never sleeps.
/mob/living/basic/ambient_npc/outpost/dancer/proc/scream()
	var/static/list/screams = list(
		'sound/mobs/humanoids/human/scream/femalescream_1.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_2.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_3.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_4.ogg',
		'sound/mobs/humanoids/human/scream/femalescream_5.ogg',
	)
	manual_emote("screams!")
	playsound(src, pick(screams), 50, TRUE)

/**
 * Keeping clear of a fight: she runs a few steps away from it and crouches, until nothing has
 * happened for DANCER_CALM_TIME (every fight or hit she hears of meanwhile starts that over) and
 * no shootout is on. Then she goes back up on her pole (dancer/back_to_pole).
 */
/datum/ambient_activity/dancer_hide
	name = "hiding"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = DANCER_HIDE_MAX
	duration_high = DANCER_HIDE_MAX
	/// world.time it will have been quiet long enough to come out
	var/calm_at = 0

/datum/ambient_activity/dancer_hide/setup()
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = doer
	if(!istype(dancer))
		return FALSE
	set_duration()
	calm_at = world.time + DANCER_CALM_TIME
	go_to(dancer.hiding_spot(anchor(), failed_spots))
	return TRUE

/datum/ambient_activity/dancer_hide/arrive()
	doer.crouch()

/datum/ambient_activity/dancer_hide/act(seconds)
	var/datum/ambient_place/outpost/outpost_place = doer.place
	// Nobody comes out while the kingpin's crew is still shooting
	if(istype(outpost_place) && outpost_place.shootout_refuge)
		return AMBIENT_STEP_CONTINUE
	return world.time >= calm_at ? AMBIENT_STEP_DONE : AMBIENT_STEP_CONTINUE

/datum/ambient_activity/dancer_hide/shift_times(delay)
	. = ..()
	calm_at = ambient_shifted(calm_at, delay)

// =========================================================================
// THE DANCE
// =========================================================================

/**
 * Dancing on the pole for the crowd: up on its own tile (climbing on from beside it), round its
 * sides, spins, small hops, leans back against it, and a word to the crowd. Now and then she takes
 * a break instead (routine picks /datum/ambient_activity/sit).
 */
/datum/ambient_activity/dance_pole
	name = "dancing"
	// On the job: nobody pulls her off the pole for a chat
	accepts_company = FALSE
	duration_low = 3 MINUTES
	duration_high = 6 MINUTES
	/// The pole she dances on
	var/datum/weakref/pole_ref
	/// Its tile, where she dances. Kept if the pole goes, so she can still step down.
	var/turf/pole_turf
	/// Whether she is up on the pole's tile, against it
	var/on_pole = FALSE
	/// world.time she climbs up, while she is beside it
	var/climb_at = 0
	/// Climbs in a row that found someone else up there
	var/climb_tries = 0
	/// world.time of her next dance move
	var/next_move = 0
	/// The side of the pole she dances on: WEST, SOUTH or EAST
	var/side = SOUTH

/datum/ambient_activity/dance_pole/setup()
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = doer
	if(!istype(dancer))
		return FALSE
	var/obj/structure/festivus/anchored/pole = dancer.find_pole()
	var/turf/tile = get_turf(pole)
	if(!dancer.pole_free(tile))
		return FALSE
	pole_ref = WEAKREF(pole)
	pole_turf = tile
	// Walks up beside it: the platform is dense, so she climbs the last step herself (try_climb())
	go_to(tile, 1)
	set_duration()
	RegisterSignal(doer, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	return TRUE

/datum/ambient_activity/dance_pole/Destroy()
	pole_ref = null
	pole_turf = null
	return ..()

/// The pole, if it is still there
/datum/ambient_activity/dance_pole/proc/pole()
	var/obj/structure/festivus/anchored/pole = pole_ref?.resolve()
	return QDELETED(pole) ? null : pole

/datum/ambient_activity/dance_pole/arrive()
	side = pick(WEST, SOUTH, EAST)
	if(doer.loc == pole_turf)
		// Found already up there (settle_in()): straight into the dance
		hold_pole()
	else
		climb_at = world.time + rand(0.5 SECONDS, 1.5 SECONDS)
		if(!doer.buckled)
			doer.face_atom(pole_turf)
	next_move = world.time + rand(3 SECONDS, 6 SECONDS)
	next_line = world.time + rand(15 SECONDS, 35 SECONDS)

// Found mid-dance: up on the pole, not beside it about to climb
/datum/ambient_activity/dance_pole/settle()
	. = ..()
	try_climb()

/datum/ambient_activity/dance_pole/act(seconds)
	if(!pole())
		return AMBIENT_STEP_DONE
	if(!on_pole)
		if(world.time < climb_at)
			return AMBIENT_STEP_CONTINUE
		if(!try_climb())
			// Someone else is up there: she tries again shortly, then gives it up for now
			if(++climb_tries >= DANCE_CLIMB_TRIES)
				return AMBIENT_STEP_DONE
			climb_at = world.time + rand(2 SECONDS, 4 SECONDS)
			return AMBIENT_STEP_CONTINUE
	if(world.time >= next_move)
		next_move = world.time + rand(3 SECONDS, 6 SECONDS)
		dance_step()
	chatter("dance", 20 SECONDS, 45 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// The short climb up onto the pole's tile from beside it. The platform stays dense to everyone else: she is put up there. TRUE if she is up.
/datum/ambient_activity/dance_pole/proc/try_climb()
	if(on_pole)
		return TRUE
	var/mob/living/basic/ambient_npc/outpost/dancer/dancer = doer
	if(!pole() || doer.buckled || get_dist(doer, pole_turf) > 1 || !dancer.pole_free(pole_turf))
		return FALSE
	if(doer.loc != pole_turf)
		doer.forceMove(pole_turf)
	hold_pole()
	return on_pole

/**
 * Keeps her hold on the pole true to where she stands, whatever moved her. Off its tile (a shove, a
 * mob swap) she lets go at once and climbs back up in a moment; put back on it (a swap that failed
 * half way) she takes hold again.
 */
/datum/ambient_activity/dance_pole/proc/on_moved(datum/source, atom/old_loc)
	SIGNAL_HANDLER
	if(!arrived)
		return
	if(doer.loc == pole_turf)
		hold_pole()
	else if(on_pole)
		let_go()
		climb_at = world.time + rand(2 SECONDS, 4 SECONDS)

/// Up against the pole, on her side of it, facing away from it
/datum/ambient_activity/dance_pole/proc/hold_pole()
	if(on_pole)
		return
	on_pole = TRUE
	climb_tries = 0
	take_side(side)

/// Lets go of the pole: her place against it goes at once
/datum/ambient_activity/dance_pole/proc/let_go()
	on_pole = FALSE
	doer.remove_offsets(DANCE_POLE_OFFSET_SOURCE, animate = FALSE)

/// Her pixel_w and pixel_z against `pole_side` of the pole, as list(w, z)
/datum/ambient_activity/dance_pole/proc/side_offset(pole_side)
	switch(pole_side)
		if(WEST)
			return list(-DANCE_POLE_HUG, 0)
		if(EAST)
			return list(DANCE_POLE_HUG, 0)
	// In front of it, a little lower down the platform
	return list(0, 1 - DANCE_POLE_HUG)

/**
 * Round to `new_side` of the pole (WEST, SOUTH or EAST), facing away from it, or into it if
 * `facing_in` (west and east only: in front, she faces the crowd). `sway` shifts her a pixel or two
 * along it.
 */
/datum/ambient_activity/dance_pole/proc/take_side(new_side, facing_in = FALSE, sway = 0)
	side = new_side
	doer.setDir((facing_in && side != SOUTH) ? REVERSE_DIR(side) : side)
	var/list/offset = side_offset(side)
	doer.add_offsets(DANCE_POLE_OFFSET_SOURCE, w_add = offset[1] + sway, z_add = offset[2])

/// One dance move: a spin, a small hop, round to another side, a turn, a lean back against the pole or a sway
/datum/ambient_activity/dance_pole/proc/dance_step()
	if(!on_pole || doer.buckled)
		return
	var/facing_in = doer.dir != side
	switch(rand(1, 10))
		if(1, 2)
			// A spin, back to the pole once it's done
			doer.SpinAnimation(speed = rand(6, 9), loops = 1)
		if(3)
			hop()
		if(4, 5)
			take_side(pick(list(WEST, SOUTH, EAST) - side), facing_in = prob(30))
		if(6)
			// Turns into the pole, or away from it again. In front, a hop instead.
			if(side == SOUTH)
				hop()
			else
				take_side(side, facing_in = !facing_in)
		if(7)
			lean()
		if(8)
			take_side(side, facing_in, sway = pick(-2, 2))
		else
			if(prob(40))
				doer.manual_emote(pick("sways to the beat.", "gives a little twirl."))

/// A small hop. The resting transform is kept first: animate() sets the var to each step's end at once, so reading it after would leave her floating higher with every hop.
/datum/ambient_activity/dance_pole/proc/hop()
	var/matrix/rest = matrix(doer.transform)
	var/matrix/up = matrix(doer.transform)
	up.Translate(0, 3)
	animate(doer, transform = up, time = 0.3 SECONDS, easing = SINE_EASING)
	animate(transform = rest, time = 0.3 SECONDS)

/// Leans back against the pole a moment (her top tilted toward it), then straightens up. Ends on her resting transform, like the hop.
/datum/ambient_activity/dance_pole/proc/lean()
	var/angle
	switch(side)
		if(WEST)
			angle = 12
		if(EAST)
			angle = -12
		else
			angle = pick(-8, 8)
	var/matrix/rest = matrix(doer.transform)
	var/matrix/tilted = matrix(doer.transform)
	tilted.Turn(angle)
	animate(doer, transform = tilted, time = 0.4 SECONDS, easing = SINE_EASING)
	animate(transform = tilted, time = 1.2 SECONDS)
	animate(transform = rest, time = 0.4 SECONDS, easing = SINE_EASING)
	if(side != SOUTH && doer.dir == side && prob(50))
		doer.manual_emote("leans back against the pole.")

/// However the dance ended: any spin, hop or lean stops, she lets go and steps down beside the pole
/datum/ambient_activity/dance_pole/finish()
	if(!QDELETED(doer))
		UnregisterSignal(doer, COMSIG_MOVABLE_MOVED)
		animate(doer)
		let_go()
		if(pole_turf && doer.loc == pole_turf)
			step_off_pole()
	return ..()

/// Down off the platform to a free tile beside the pole: clear of the goons' posts if she can, anywhere open if she must. With none free she stays up and walks off.
/datum/ambient_activity/dance_pole/proc/step_off_pole()
	var/turf/stand = doer.free_tile_beside(pole_turf, 1, spots_to_avoid()) || doer.free_tile_beside(pole_turf, 1) || doer.free_tile_beside(pole_turf, 1, null, TRUE)
	if(stand)
		doer.forceMove(stand)

/// Spots given up on, and the kingpin's goons' posts: they walk back to them
/datum/ambient_activity/dance_pole/proc/spots_to_avoid()
	var/list/avoid = failed_spots ? failed_spots.Copy() : list()
	for(var/obj/effect/landmark/bounty_kingpin/goon/post in GLOB.bounty_kingpin_marks)
		var/turf/post_turf = get_turf(post)
		if(post_turf)
			avoid[post_turf] = TRUE
	return avoid

/datum/ambient_activity/dance_pole/spot_unreachable()
	. = ..()
	pole_ref = null

/datum/ambient_activity/dance_pole/shift_times(delay)
	. = ..()
	next_move = ambient_shifted(next_move, delay)
	climb_at = ambient_shifted(climb_at, delay)

// =========================================================================
// WHO COMES WHERE
// =========================================================================

/// One dancer at the Undertow
/datum/ambient_outpost_role/dancer
	name = "dancer"
	npc_type = /mob/living/basic/ambient_npc/outpost/dancer
	outpost_types = list(/obj/structure/overmap/trader_outpost/black_market)
	max_count = 1
	weight = 3
	gap_low = 1 MINUTES
	gap_high = 2 MINUTES

#undef DANCE_POLE_OFFSET_SOURCE
#undef DANCE_POLE_HUG
#undef DANCE_CLIMB_TRIES
#undef DANCER_KINGPIN_ALARM_RADIUS
#undef DANCER_CALM_TIME
#undef DANCER_HIDE_MAX
#undef DANCER_HIDE_RANGE
